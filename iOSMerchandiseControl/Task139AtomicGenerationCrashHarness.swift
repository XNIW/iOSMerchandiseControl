#if DEBUG
import Darwin
import Foundation
import SwiftData

/// Isolated, opt-in process-crash fixture used only by the host-side TASK-139
/// gate. It never opens the app's normal store and never constructs auth,
/// network or image services. The host creates a fresh Simulator, waits for a
/// fsynced boundary marker, delivers SIGKILL, then relaunches in verify mode.
@MainActor
enum Task139AtomicGenerationCrashHarness {
    private enum Action: String {
        case seed
        case crash
        case verify
    }

    private enum Scenario: String, Codable {
        case pre
        case post

        var boundary: SyncStoreActivationBoundary {
            switch self {
            case .pre: return .beforeManifestRename
            case .post: return .afterManifestRename
            }
        }

        var expectedSupplierAfterCrash: String {
            switch self {
            case .pre: return "TASK139-G1"
            case .post: return "TASK139-G2"
            }
        }
    }

    private struct State: Codable {
        let schemaVersion: Int
        let scenario: Scenario
        let ownerUserID: UUID
        let shopID: UUID
        let accountHash: String
        let storeIdentityRaw: String
        let deviceIdentityHash: String
        let oldGenerationID: UUID
        var candidateGenerationID: UUID?
    }

    private struct BoundaryMarker: Codable {
        let schemaVersion: Int
        let scenario: Scenario
        let boundary: String
        let pid: Int32
        let oldGenerationID: UUID
        let candidateGenerationID: UUID
        let manifestGenerationID: UUID?
        let storeBytes: Int
        let walBytes: Int
        let ledgerBytes: Int
    }

    private struct Result: Codable {
        let schemaVersion: Int
        let action: String
        let scenario: String
        let passed: Bool
        let activeGenerationID: UUID?
        let expectedGenerationID: UUID?
        let supplierNames: [String]
        let storeBytes: Int
        let walBytes: Int
        let ledgerBytes: Int
        let journalPhase: String?
        let errorCode: String?
    }

    private struct PreparedGeneration {
        let handle: SyncStoreGenerationHandle
        let checkpoint: ShopSyncRecoveryCheckpoint
        let receipt: ShopSyncRecoveryLocalVerificationReceipt
        let baselineRunID: UUID
        let journal: AccountRecoveryJournalSnapshot
    }

    private enum HarnessError: String, Error {
        case invalidMode
        case unavailableDirectory
        case fixtureAlreadyExists
        case missingState
        case invalidState
        case identitySetupFailed
        case journalWriteFailed
        case invalidTimestamp
        case activationReturnedDuringCrashMode
        case verificationFailed
    }

    static func runIfRequested() -> Bool {
        guard let rawMode = ProcessInfo.processInfo.environment["TASK139_ATOMIC_CRASH_MODE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawMode.isEmpty else {
            return false
        }
        do {
            let (action, scenario) = try parse(rawMode)
            switch action {
            case .seed:
                try seed(scenario: scenario)
            case .crash:
                try crash(scenario: scenario)
            case .verify:
                try verify(scenario: scenario)
            }
        } catch {
            writeFailureBestEffort(mode: rawMode, error: error)
        }
        return true
    }

    private static func parse(_ value: String) throws -> (Action, Scenario) {
        let components = value.split(separator: "-", omittingEmptySubsequences: false)
        guard components.count == 2,
              let action = Action(rawValue: String(components[0])),
              let scenario = Scenario(rawValue: String(components[1])) else {
            throw HarnessError.invalidMode
        }
        return (action, scenario)
    }

    private static func seed(scenario: Scenario) throws {
        let root = try scenarioRoot(scenario)
        guard !FileManager.default.fileExists(atPath: root.path) else {
            throw HarnessError.fixtureAlreadyExists
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let defaults = try scenarioDefaults(scenario)
        let identity = try makeIdentity(scenario: scenario, defaults: defaults)
        let repository = try SyncStoreGenerationRepository(
            baseDirectory: generationRoot(root),
            defaults: defaults
        )
        let bindingStore = AccountBindingStore(defaults: defaults)
        guard bindingStore.beginSameScopeRecovery(
            accountHash: identity.accountHash,
            storeIdentity: identity.storeIdentity,
            reason: "task139-atomic-crash-seed",
            deviceIdentityHash: identity.deviceIdentityHash
        ) else {
            throw HarnessError.journalWriteFailed
        }
        let prepared = try prepareGeneration(
            repository: repository,
            bindingStore: bindingStore,
            ownerUserID: identity.ownerUserID,
            shopID: identity.shopID,
            accountHash: identity.accountHash,
            storeIdentity: identity.storeIdentity,
            deviceInstallID: identity.deviceInstallID,
            deviceIdentityHash: identity.deviceIdentityHash,
            supplierName: "TASK139-G1",
            eventID: 101
        )
        let seededFence = try repository.captureMutationFence(for: prepared.handle)
        let seededActive = try repository.activate(
            prepared.handle,
            mutationFence: seededFence,
            checkpointBeforeDownload: prepared.checkpoint,
            checkpoint: prepared.checkpoint,
            localVerification: prepared.receipt,
            baselineRunID: prepared.baselineRunID,
            journal: prepared.journal
        )
        guard let activeManifest = seededActive.manifest else {
            throw HarnessError.verificationFailed
        }
        try repository.markRecoveryFinalized(activeManifest)
        bindingStore.clearPendingReplacement()
        guard defaults.synchronize() else { throw HarnessError.journalWriteFailed }
        let state = State(
            schemaVersion: 1,
            scenario: scenario,
            ownerUserID: identity.ownerUserID,
            shopID: identity.shopID,
            accountHash: identity.accountHash,
            storeIdentityRaw: identity.storeIdentity.rawValue,
            deviceIdentityHash: identity.deviceIdentityHash,
            oldGenerationID: prepared.handle.generationID,
            candidateGenerationID: nil
        )
        try writeJSON(state, to: stateURL(root))
        let sizes = generationSizes(
            root: root,
            generationID: prepared.handle.generationID
        )
        try writeJSON(
            Result(
                schemaVersion: 1,
                action: Action.seed.rawValue,
                scenario: scenario.rawValue,
                passed: sizes.store > 0 && sizes.ledger > 0,
                activeGenerationID: prepared.handle.generationID,
                expectedGenerationID: prepared.handle.generationID,
                supplierNames: ["TASK139-G1"],
                storeBytes: sizes.store,
                walBytes: sizes.wal,
                ledgerBytes: sizes.ledger,
                journalPhase: nil,
                errorCode: nil
            ),
            to: resultURL(root, action: .seed)
        )
    }

    private static func crash(scenario: Scenario) throws {
        let root = try scenarioRoot(scenario)
        var state: State = try readJSON(State.self, from: stateURL(root))
        guard state.schemaVersion == 1,
              state.scenario == scenario,
              state.candidateGenerationID == nil else {
            throw HarnessError.invalidState
        }
        let defaults = try scenarioDefaults(scenario)
        let boundaryBlocker = Task139CrashBoundaryBlocker(
            root: root,
            scenario: scenario.rawValue,
            targetBoundary: scenario.boundary
        )
        let repository = try SyncStoreGenerationRepository(
            baseDirectory: generationRoot(root),
            defaults: defaults,
            activationBoundaryProbe: { boundary in
                boundaryBlocker.handle(boundary)
            }
        )
        // Keep G1's container strongly alive while G2 is staged and while the
        // host kills this process at the chosen publication boundary.
        let oldActive = try repository.loadActive()
        guard oldActive.manifest?.generationID == state.oldGenerationID else {
            throw HarnessError.invalidState
        }
        let bindingStore = AccountBindingStore(defaults: defaults)
        let storeIdentity = LocalStoreIdentity(rawValue: state.storeIdentityRaw)
        let deviceInstallID = DeviceInstallIDStore(defaults: defaults).deviceInstallID
        guard DeviceInstallIDStore.identityHash(for: deviceInstallID)
                == state.deviceIdentityHash,
              bindingStore.beginSameScopeRecovery(
                accountHash: state.accountHash,
                storeIdentity: storeIdentity,
                reason: "task139-atomic-crash-candidate",
                deviceIdentityHash: state.deviceIdentityHash
              ) else {
            throw HarnessError.journalWriteFailed
        }
        let prepared = try prepareGeneration(
            repository: repository,
            bindingStore: bindingStore,
            ownerUserID: state.ownerUserID,
            shopID: state.shopID,
            accountHash: state.accountHash,
            storeIdentity: storeIdentity,
            deviceInstallID: deviceInstallID,
            deviceIdentityHash: state.deviceIdentityHash,
            supplierName: "TASK139-G2",
            eventID: 202
        )
        state.candidateGenerationID = prepared.handle.generationID
        try writeJSON(state, to: stateURL(root))

        let candidateFence = try repository.captureMutationFence(for: prepared.handle)
        _ = try repository.activate(
            prepared.handle,
            mutationFence: candidateFence,
            checkpointBeforeDownload: prepared.checkpoint,
            checkpoint: prepared.checkpoint,
            localVerification: prepared.receipt,
            baselineRunID: prepared.baselineRunID,
            journal: prepared.journal
        )
        withExtendedLifetime(oldActive) {}
        withExtendedLifetime(prepared.handle.container) {}
        throw HarnessError.activationReturnedDuringCrashMode
    }

    private static func verify(scenario: Scenario) throws {
        let root = try scenarioRoot(scenario)
        let state: State = try readJSON(State.self, from: stateURL(root))
        let candidateID = try state.candidateGenerationID
            .unwrap(or: HarnessError.missingState)
        let defaults = try scenarioDefaults(scenario)
        let repository = try SyncStoreGenerationRepository(
            baseDirectory: generationRoot(root),
            defaults: defaults
        )
        let active = try repository.loadActive()
        let expectedID = scenario == .pre ? state.oldGenerationID : candidateID
        let context = ModelContext(active.container)
        let suppliers = try context.fetch(
            FetchDescriptor<Supplier>(sortBy: [SortDescriptor(\Supplier.name)])
        )
        let names = suppliers.map(\.name)
        let bindingStore = AccountBindingStore(defaults: defaults)

        if scenario == .post {
            let scope = try Task126OwnerStoreGate.captureAutomaticScope(
                ownerUserID: state.ownerUserID,
                defaults: defaults,
                allowsPendingReplacement: true
            )
            guard let manifest = active.manifest,
                  try bindingStore.commitActivatedGeneration(
                    manifest,
                    expectedLeaseGeneration: scope.leaseGeneration
                  ) else {
                throw HarnessError.verificationFailed
            }
            let secondScope = try Task126OwnerStoreGate.captureAutomaticScope(
                ownerUserID: state.ownerUserID,
                defaults: defaults,
                allowsPendingReplacement: true
            )
            guard try bindingStore.commitActivatedGeneration(
                manifest,
                expectedLeaseGeneration: secondScope.leaseGeneration
            ) else {
                throw HarnessError.verificationFailed
            }
        }

        let manifestID = active.manifest?.generationID
        let journal = bindingStore.pendingRecoveryJournal
        let passed = manifestID == expectedID
            && names == [scenario.expectedSupplierAfterCrash]
            && bindingStore.currentBinding?.accountHash == state.accountHash
            && bindingStore.currentBinding?.storeIdentity
                == LocalStoreIdentity(rawValue: state.storeIdentityRaw)
            && journal?.generationID == candidateID
            && (scenario == .pre ? journal?.phase == .verified : journal?.phase == .activated)
        let sizes = generationSizes(root: root, generationID: expectedID)
        let marker: BoundaryMarker = try readJSON(
            BoundaryMarker.self,
            from: boundaryMarkerURL(root)
        )
        let markerPassed = marker.pid > 0
            && marker.oldGenerationID == state.oldGenerationID
            && marker.candidateGenerationID == candidateID
            && marker.storeBytes > 0
            && marker.walBytes > 0
            && marker.ledgerBytes > 0
        let finalPassed = passed && markerPassed && sizes.store > 0 && sizes.ledger > 0
        try writeJSON(
            Result(
                schemaVersion: 1,
                action: Action.verify.rawValue,
                scenario: scenario.rawValue,
                passed: finalPassed,
                activeGenerationID: manifestID,
                expectedGenerationID: expectedID,
                supplierNames: names,
                storeBytes: sizes.store,
                walBytes: sizes.wal,
                ledgerBytes: sizes.ledger,
                journalPhase: journal?.phase.rawValue,
                errorCode: finalPassed ? nil : HarnessError.verificationFailed.rawValue
            ),
            to: resultURL(root, action: .verify)
        )
        guard finalPassed else { throw HarnessError.verificationFailed }
    }

    private struct Identity {
        let ownerUserID: UUID
        let shopID: UUID
        let accountHash: String
        let storeIdentity: LocalStoreIdentity
        let deviceInstallID: String
        let deviceIdentityHash: String
    }

    private static func makeIdentity(
        scenario: Scenario,
        defaults: UserDefaults
    ) throws -> Identity {
        let ownerUserID = scenario == .pre
            ? UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
            : UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let shopID = scenario == .pre
            ? UUID(uuidString: "00000000-0000-4000-8000-000000000140")!
            : UUID(uuidString: "00000000-0000-4000-8000-000000000141")!
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        let selectedShop = SelectedShop(
            shopID: shopID,
            code: "TASK139",
            name: "Atomic crash fixture",
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true
        )
        let selectedShopStore = SelectedShopStore(defaults: defaults)
        selectedShopStore.noteActiveAccount(accountHash)
        guard selectedShopStore.save(selectedShop, accountHash: accountHash),
              AccountBindingStore(defaults: defaults).saveBinding(
                accountHash: accountHash,
                storeIdentity: selectedShop.localStoreIdentity
              ) else {
            throw HarnessError.identitySetupFailed
        }
        let deviceInstallID = DeviceInstallIDStore(defaults: defaults).deviceInstallID
        return Identity(
            ownerUserID: ownerUserID,
            shopID: shopID,
            accountHash: accountHash,
            storeIdentity: selectedShop.localStoreIdentity,
            deviceInstallID: deviceInstallID,
            deviceIdentityHash: DeviceInstallIDStore.identityHash(for: deviceInstallID)
        )
    }

    private static func prepareGeneration(
        repository: SyncStoreGenerationRepository,
        bindingStore: AccountBindingStore,
        ownerUserID: UUID,
        shopID: UUID,
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        deviceInstallID: String,
        deviceIdentityHash: String,
        supplierName: String,
        eventID: Int64
    ) throws -> PreparedGeneration {
        let handle = try repository.prepareStaging(
            accountHash: accountHash,
            shopID: shopID,
            storeIdentity: storeIdentity,
            deviceIdentityHash: deviceIdentityHash
        )
        guard bindingStore.recordPendingRecoveryStaging(
            accountHash: accountHash,
            storeIdentity: storeIdentity,
            deviceIdentityHash: deviceIdentityHash,
            generationID: handle.generationID
        ) else {
            throw HarnessError.journalWriteFailed
        }
        let supplierID = supplierName.hasSuffix("G1")
            ? UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
            : UUID(uuidString: "20000000-0000-4000-8000-000000000002")!
        let timestampString = "2026-07-21T12:00:00.000000Z"
        guard let timestamp = canonicalDate(timestampString) else {
            throw HarnessError.invalidTimestamp
        }
        let emptyHash = ShopSyncRecoveryCanonical.checkpointChainInitialDigest
        let supplierIDLine = supplierID.uuidString.lowercased()
        let supplierVersionLine = ShopSyncRecoveryCanonical.joined(
            supplierIDLine,
            timestampString,
            ShopSyncRecoveryCanonical.null
        )
        let supplierDigest = ShopSyncRecoveryEntityDigest(
            activeCount: 1,
            tombstoneCount: 0,
            idSetDigest: ShopSyncRecoveryCanonical.checkpointChainDigest([supplierIDLine]),
            versionDigest: ShopSyncRecoveryCanonical.checkpointChainDigest([supplierVersionLine])
        )
        let empty = ShopSyncRecoveryEntityDigest(
            activeCount: 0,
            tombstoneCount: 0,
            idSetDigest: emptyHash,
            versionDigest: emptyHash
        )
        let emptyProducts = ShopSyncRecoveryEntityDigest(
            activeCount: 0,
            tombstoneCount: 0,
            idSetDigest: emptyHash,
            versionDigest: emptyHash,
            identityDigest: emptyHash
        )
        let deviceKey = ShopSyncRecoveryCanonical.sha256(deviceInstallID)
        let scope = ShopSyncRecoveryScope(
            kind: "shop_scoped",
            key: ShopSyncRecoveryCanonical.sha256(
                shopID.uuidString.lowercased() + ":shop_scoped:-:" + deviceKey
            ),
            legacyOwnerKey: nil,
            accountKey: AccountBindingStore.accountHash(for: ownerUserID),
            deviceKey: deviceKey
        )
        let checkpoint = ShopSyncRecoveryCheckpoint(
            schemaVersion: "shop-sync-recovery-checkpoint-v1",
            shopId: shopID,
            scope: scope,
            syncEvents: ShopSyncRecoveryEventCheckpoint(maxId: String(eventID)),
            catalog: ShopSyncRecoveryCatalogDigest(
                suppliers: supplierDigest,
                categories: empty,
                products: emptyProducts,
                digest: ShopSyncRecoveryCanonical.sha256(
                    supplierDigest.versionDigest + "\n"
                        + empty.versionDigest + "\n"
                        + emptyProducts.versionDigest
                )
            ),
            prices: empty,
            history: empty,
            images: empty,
            integrity: ShopSyncRecoveryIntegrity(
                productCategoryViolationCount: 0,
                productSupplierViolationCount: 0,
                priceProductViolationCount: 0,
                primaryImageViolationCount: 0,
                historyIdViolationCount: 0,
                totalViolationCount: 0
            ),
            checkpointDigest: ShopSyncRecoveryCanonical.sha256(
                "task139-atomic-crash-\(supplierName)"
            )
        )
        let baselineRunID = UUID()
        let context = ModelContext(handle.container)
        context.autosaveEnabled = false
        let supplier = Supplier(
            name: "TASK139-WAL-SEED",
            remoteID: supplierID,
            remoteUpdatedAt: timestamp
        )
        context.insert(supplier)
        context.insert(SupabaseCatalogBaselineRun(
            baselineRunID: baselineRunID,
            ownerUserUUID: ownerUserID,
            status: .valid,
            appliedAt: Date(),
            productCount: 0,
            supplierCount: 1,
            categoryCount: 0,
            tombstoneCount: 0
        ))
        try context.save()
        supplier.name = supplierName
        context.insert(SupabaseCatalogBaselineRecord(
            baselineRunID: baselineRunID,
            ownerUserUUID: ownerUserID,
            entityType: .supplier,
            remoteID: supplierID,
            remoteUpdatedAt: timestamp,
            fingerprintCanonical: ManualPushFingerprintNormalizer.supplier(
                remoteID: supplierID,
                name: supplierName
            ).canonicalString,
            lookupNameCanonical: SupabasePullPreviewNormalizer.normalizedLookupName(
                supplierName
            )
        ))
        try context.save()

        let ledger = try ShopSyncRecoveryLedger(generationStoreURL: handle.storeURL)
        try ledger.append(
            ShopSyncRecoveryLedgerRecord(
                orderingID: supplierIDLine,
                idLine: supplierIDLine,
                versionLine: supplierVersionLine,
                identityLine: nil,
                isTombstone: false
            ),
            domain: .suppliers
        )
        try ledger.closeWrites()
        let receipt = try ledger.receipt(
            relationshipViolationCount: 0,
            pendingLocalCount: 0,
            outboxCount: 0
        )
        guard receipt.matches(checkpoint),
              bindingStore.recordPendingRecoveryVerified(
                accountHash: accountHash,
                storeIdentity: storeIdentity,
                deviceIdentityHash: deviceIdentityHash,
                generationID: handle.generationID,
                checkpointDigest: checkpoint.checkpointDigest,
                watermark: eventID,
                baselineRunID: baselineRunID
              ),
              let journal = bindingStore.pendingRecoveryJournal else {
            throw HarnessError.journalWriteFailed
        }
        return PreparedGeneration(
            handle: handle,
            checkpoint: checkpoint,
            receipt: receipt,
            baselineRunID: baselineRunID,
            journal: journal
        )
    }

    private static func canonicalDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    private static func scenarioDefaults(_ scenario: Scenario) throws -> UserDefaults {
        guard let defaults = UserDefaults(
            suiteName: "Task139AtomicGenerationCrashHarness.\(scenario.rawValue)"
        ) else {
            throw HarnessError.identitySetupFailed
        }
        return defaults
    }

    private static func harnessRoot() throws -> URL {
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw HarnessError.unavailableDirectory
        }
        return support.appendingPathComponent(
            "Task139AtomicGenerationCrashHarness",
            isDirectory: true
        )
    }

    private static func scenarioRoot(_ scenario: Scenario) throws -> URL {
        try harnessRoot().appendingPathComponent(scenario.rawValue, isDirectory: true)
    }

    private static func generationRoot(_ root: URL) -> URL {
        root.appendingPathComponent("generation-root", isDirectory: true)
    }

    private static func stateURL(_ root: URL) -> URL {
        root.appendingPathComponent("state.json")
    }

    private static func boundaryMarkerURL(_ root: URL) -> URL {
        root.appendingPathComponent("boundary-marker.json")
    }

    private static func resultURL(_ root: URL, action: Action) -> URL {
        root.appendingPathComponent("\(action.rawValue)-result.json")
    }

    private static func generationSizes(
        root: URL,
        generationID: UUID
    ) -> (store: Int, wal: Int, ledger: Int) {
        let generation = generationRoot(root)
            .appendingPathComponent("generations", isDirectory: true)
            .appendingPathComponent(generationID.uuidString.lowercased(), isDirectory: true)
        let store = generation.appendingPathComponent("store.store")
        let wal = URL(fileURLWithPath: store.path + "-wal")
        let ledger = generation
            .appendingPathComponent("recovery-ledger-v1", isDirectory: true)
            .appendingPathComponent("suppliers.ndjson")
        return (fileSize(store), fileSize(wal), fileSize(ledger))
    }

    private static func fileSize(_ url: URL) -> Int {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let number = attributes[.size] as? NSNumber else {
            return 0
        }
        return max(0, number.intValue)
    }

    private static func writeJSON<Value: Encodable>(_ value: Value, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(value).write(to: url, options: [.atomic])
        let handle = try FileHandle(forReadingFrom: url)
        try handle.synchronize()
        try handle.close()
        let descriptor = Darwin.open(url.deletingLastPathComponent().path, O_RDONLY)
        guard descriptor >= 0 else { throw HarnessError.unavailableDirectory }
        defer { _ = Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0 else {
            throw HarnessError.unavailableDirectory
        }
    }

    private static func readJSON<Value: Decodable>(
        _ type: Value.Type,
        from url: URL
    ) throws -> Value {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw HarnessError.missingState
        }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    private static func writeFailureBestEffort(mode: String, error: Error) {
        guard let root = try? harnessRoot() else { return }
        let components = mode.split(separator: "-")
        let scenario = components.last.map(String.init) ?? "unknown"
        let action = components.first.map(String.init) ?? "unknown"
        let code = (error as? HarnessError)?.rawValue ?? String(describing: type(of: error))
        try? writeJSON(
            Result(
                schemaVersion: 1,
                action: action,
                scenario: scenario,
                passed: false,
                activeGenerationID: nil,
                expectedGenerationID: nil,
                supplierNames: [],
                storeBytes: 0,
                walBytes: 0,
                ledgerBytes: 0,
                journalPhase: nil,
                errorCode: code
            ),
            to: root.appendingPathComponent("failure-\(mode).json")
        )
    }
}

private nonisolated final class Task139CrashBoundaryBlocker: @unchecked Sendable {
    private struct StateSnapshot: Decodable {
        let oldGenerationID: UUID
        let candidateGenerationID: UUID?
    }

    private struct ManifestPointer: Decodable {
        let generationID: UUID
    }

    private struct Marker: Encodable {
        let schemaVersion: Int
        let scenario: String
        let boundary: String
        let pid: Int32
        let oldGenerationID: UUID
        let candidateGenerationID: UUID
        let manifestGenerationID: UUID?
        let storeBytes: Int
        let walBytes: Int
        let ledgerBytes: Int
    }

    private struct Failure: Encodable {
        let schemaVersion: Int
        let errorCode: String
    }

    private let root: URL
    private let scenario: String
    private let targetBoundary: SyncStoreActivationBoundary

    init(
        root: URL,
        scenario: String,
        targetBoundary: SyncStoreActivationBoundary
    ) {
        self.root = root
        self.scenario = scenario
        self.targetBoundary = targetBoundary
    }

    func handle(_ boundary: SyncStoreActivationBoundary) {
        guard boundary == targetBoundary else { return }
        do {
            let state = try read(StateSnapshot.self, from: root.appendingPathComponent("state.json"))
            guard let candidateID = state.candidateGenerationID else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let generationRoot = root.appendingPathComponent("generation-root", isDirectory: true)
            let manifestURL = generationRoot.appendingPathComponent("active-generation.json")
            let manifestID = try? read(ManifestPointer.self, from: manifestURL).generationID
            let generation = generationRoot
                .appendingPathComponent("generations", isDirectory: true)
                .appendingPathComponent(candidateID.uuidString.lowercased(), isDirectory: true)
            let store = generation.appendingPathComponent("store.store")
            let marker = Marker(
                schemaVersion: 1,
                scenario: scenario,
                boundary: boundary == .beforeManifestRename ? "before" : "after",
                pid: getpid(),
                oldGenerationID: state.oldGenerationID,
                candidateGenerationID: candidateID,
                manifestGenerationID: manifestID,
                storeBytes: fileSize(store),
                walBytes: fileSize(URL(fileURLWithPath: store.path + "-wal")),
                ledgerBytes: fileSize(
                    generation
                        .appendingPathComponent("recovery-ledger-v1", isDirectory: true)
                        .appendingPathComponent("suppliers.ndjson")
                )
            )
            try write(marker, to: root.appendingPathComponent("boundary-marker.json"))
        } catch {
            try? write(
                Failure(
                    schemaVersion: 1,
                    errorCode: String(describing: type(of: error))
                ),
                to: root.appendingPathComponent("boundary-marker-error.json")
            )
        }
        // The host must be the process delivering SIGKILL. No timeout or
        // graceful fallback is allowed, otherwise this would cease to be a
        // process-crash test of the publication boundary.
        DispatchSemaphore(value: 0).wait()
    }

    private func read<Value: Decodable>(_ type: Value.Type, from url: URL) throws -> Value {
        try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    private func write<Value: Encodable>(_ value: Value, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(value).write(to: url, options: [.atomic])
        let handle = try FileHandle(forReadingFrom: url)
        try handle.synchronize()
        try handle.close()
        let descriptor = Darwin.open(url.deletingLastPathComponent().path, O_RDONLY)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { _ = Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0 else { throw CocoaError(.fileWriteUnknown) }
    }

    private func fileSize(_ url: URL) -> Int {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let number = attributes[.size] as? NSNumber else {
            return 0
        }
        return max(0, number.intValue)
    }
}

private extension Optional {
    func unwrap(or error: @autoclosure () -> Error) throws -> Wrapped {
        guard let self else { throw error() }
        return self
    }
}
#endif
