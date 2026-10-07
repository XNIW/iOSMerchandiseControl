#if DEBUG
import Auth
import Combine
import Foundation
import Supabase
import SwiftData
import SwiftUI
import UIKit

/// Temporary observations scoped to the unchanged original empty/callback fixture. This buffer is not ObservableObject and never
/// publishes, reads a model/store, submits work or changes an admission result.
nonisolated final class Task144RootObservation: @unchecked Sendable {
    static let enabled = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_FIXTURE"].flatMap(UUID.init(uuidString:)) != nil
        && ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_EMPTY_BOOTSTRAP"] == "1"
        && ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_CALLBACK_ORDER"] == "1"
    private static let shared = Task144RootObservation()
    private let lock = NSLock()
    private var sequence = 0
    private var events: [String] = []
    private var lastByKind: [String: String] = [:]
    private var dropped = 0

    static func record(_ kind: String, _ closedFacts: String, callsite: String = #function) {
        guard enabled else { return }
        let buffer = shared
        buffer.lock.lock()
        let key = kind + ":" + callsite
        guard kind.hasPrefix("qualification-") || buffer.lastByKind[key] != closedFacts else { buffer.lock.unlock(); return }
        buffer.lastByKind[key] = closedFacts
        buffer.sequence += 1
        let event = "seq.\(buffer.sequence).uptime.\(ProcessInfo.processInfo.systemUptime).pid.\(ProcessInfo.processInfo.processIdentifier).source.\(callsite).\(kind).\(closedFacts)"
        if buffer.events.count < 128 { buffer.events.append(event) } else { buffer.dropped += 1 }
        let shouldPrint = buffer.sequence <= 128
        let firstDrop = buffer.sequence == 129
        buffer.lock.unlock()
        // Closed synthetic facts only. Whether app stdout reaches the runner's
        // raw log is a runtime observation, never an assumed export guarantee.
        if shouldPrint { print("TASK144_RAM_OBSERVATION \(event)") }
        else if firstDrop { print("TASK144_RAM_OBSERVATION CAP128;later.NOT_RETAINED") }
    }

    static func snapshotAtRealRender() -> String {
        guard enabled else { return "" }
        let buffer = shared
        buffer.lock.lock(); defer { buffer.lock.unlock() }
        return ";task144.observation.cached-at-real-render;dropped.\(buffer.dropped);"
            + buffer.events.joined(separator: ";")
    }

    static func errorCategory(_ error: Error) -> String {
        if let error = error as? Task126OwnerStoreGateError {
            switch error {
            case .cancelled: return "Task126OwnerStoreGateError.cancelled"
            case .activeAccountMismatch: return "Task126OwnerStoreGateError.activeAccountMismatch"
            case .shopContextUnavailable: return "Task126OwnerStoreGateError.shopContextUnavailable"
            case .bindingMismatch: return "Task126OwnerStoreGateError.bindingMismatch"
            case .replacementInterrupted: return "Task126OwnerStoreGateError.replacementInterrupted"
            case .scopeChanged: return "Task126OwnerStoreGateError.scopeChanged"
            case .retiredStoreGeneration: return "Task126OwnerStoreGateError.retiredStoreGeneration"
            case .localModelUnavailable: return "Task126OwnerStoreGateError.localModelUnavailable"
            case .localRemoteConflictRequiresReview: return "Task126OwnerStoreGateError.localRemoteConflictRequiresReview"
            }
        }
        if error is CancellationError { return "CancellationError" }
        if let error = error as? SyncStoreGenerationError {
            switch error {
            case .baseDirectoryUnavailable: return "SyncStoreGenerationError.baseDirectoryUnavailable"
            case .invalidManifest: return "SyncStoreGenerationError.invalidManifest"
            case .activeStoreMissing: return "SyncStoreGenerationError.activeStoreMissing"
            case .stagingAlreadyOpen: return "SyncStoreGenerationError.stagingAlreadyOpen"
            case .stagingScopeChanged: return "SyncStoreGenerationError.stagingScopeChanged"
            case .stagingStoreMissing: return "SyncStoreGenerationError.stagingStoreMissing"
            case .activationReadBackFailed: return "SyncStoreGenerationError.activationReadBackFailed"
            case .cleanupRequiresRelaunch: return "SyncStoreGenerationError.cleanupRequiresRelaunch"
            case .unavailable: return "SyncStoreGenerationError.unavailable"
            case .staleGenerationLease: return "SyncStoreGenerationError.staleGenerationLease"
            case .generationResourceBudgetExceeded: return "SyncStoreGenerationError.generationResourceBudgetExceeded"
            case .insufficientRecoveryDiskCapacity: return "SyncStoreGenerationError.insufficientRecoveryDiskCapacity"
            case .defaultsConfigurationMismatch: return "SyncStoreGenerationError.defaultsConfigurationMismatch"
            case .stagingChangedAfterVerification: return "SyncStoreGenerationError.stagingChangedAfterVerification"
            }
        }
        if let error = error as? ShopSyncRecoveryContractError {
            switch error {
            case .checkpointChanged: return "ShopSyncRecoveryContractError.checkpointChanged"
            case .authenticationChanged: return "ShopSyncRecoveryContractError.authenticationChanged"
            case .invalidCheckpoint: return "ShopSyncRecoveryContractError.invalidCheckpoint"
            case .invalidPage: return "ShopSyncRecoveryContractError.invalidPage"
            case .nonCanonicalTimestamp: return "ShopSyncRecoveryContractError.nonCanonicalTimestamp"
            case .nonMonotonicOrDuplicateID: return "ShopSyncRecoveryContractError.nonMonotonicOrDuplicateID"
            case .rowOutsideScope: return "ShopSyncRecoveryContractError.rowOutsideScope"
            case .digestMismatch: return "ShopSyncRecoveryContractError.digestMismatch"
            case .countMismatch: return "ShopSyncRecoveryContractError.countMismatch"
            case .invalidCursor: return "ShopSyncRecoveryContractError.invalidCursor"
            case .scopeFenceMissing: return "ShopSyncRecoveryContractError.scopeFenceMissing"
            case .markerNotVerified: return "ShopSyncRecoveryContractError.markerNotVerified"
            case .fullRecoveryRequired: return "ShopSyncRecoveryContractError.fullRecoveryRequired"
            case .relationViolation: return "ShopSyncRecoveryContractError.relationViolation"
            case .pageBudgetExceeded: return "ShopSyncRecoveryContractError.pageBudgetExceeded"
            case .invalidImageMetadata: return "ShopSyncRecoveryContractError.invalidImageMetadata"
            case .persistedLedgerInvalid: return "ShopSyncRecoveryContractError.persistedLedgerInvalid"
            case .resourceBudgetExceeded: return "ShopSyncRecoveryContractError.resourceBudgetExceeded"
            case .totalResourceBudgetExceeded: return "ShopSyncRecoveryContractError.totalResourceBudgetExceeded"
            }
        }
        if let error = error as? DeviceInstallIDStoreError {
            switch error {
            case .durableStorageUnavailable: return "DeviceInstallIDStoreError.durableStorageUnavailable"
            case .invalidDurableIdentity: return "DeviceInstallIDStoreError.invalidDurableIdentity"
            }
        }
        if let error = error as? URLError {
            return error.code == .timedOut ? "URLError.timedOut" : "URLError.other"
        }
        return "other"
    }

    final class Evaluation {
        private let kind: String
        private let callsite: String
        private var operands: [String] = []
        private var firstFailed = "none"
        init(_ kind: String, callsite: String) { self.kind = kind; self.callsite = callsite }
        func check(_ value: Bool, _ name: String) -> Bool {
            operands.append("\(name).\(value)")
            if !value && firstFailed == "none" { firstFailed = name }
            return value
        }
        func optional<T>(_ value: T?, _ name: String) -> T? {
            _ = check(value != nil, name)
            return value
        }
        func attempt<T>(_ name: String, _ operation: () throws -> T) -> T? {
            do { return optional(try operation(), name) }
            catch {
                _ = check(false, name)
                operands.append("\(name)-error.\(Task144RootObservation.errorCategory(error))")
                return nil
            }
        }
        func required<T>(_ name: String, _ operation: () throws -> T) throws -> T {
            do { let value = try operation(); _ = check(true, name); return value }
            catch {
                _ = check(false, name)
                operands.append("\(name)-error.\(Task144RootObservation.errorCategory(error))")
                throw error
            }
        }
        func note(_ name: String, _ value: Bool) { operands.append("\(name).\(value)") }
        func finish(_ result: Bool, branch: String = "guard", firstFalseLabel: String = "first-failed") {
            Task144RootObservation.record(kind, "result.\(result).branch.\(branch).\(firstFalseLabel).\(firstFailed).later.NOT_EVALUATED;"
                + operands.joined(separator: ";"), callsite: callsite)
        }
    }
}

/// An explicitly requested, isolated UI-test dependency boundary. The App,
/// ContentView, editor, recovery service and automatic queue remain production
/// implementations. No default/private Supabase configuration is loaded.
@MainActor
final class Task144LocalAvailabilityRootFixture: ObservableObject {
    static let current: Task144LocalAvailabilityRootFixture? = {
        guard let raw = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_FIXTURE"] else { return nil }
        guard let runID = UUID(uuidString: raw) else { preconditionFailure("Invalid controlled fixture namespace") }
        do { return try Task144LocalAvailabilityRootFixture(runID: runID) }
        catch { preconditionFailure("Controlled root fixture could not establish its isolated store") }
    }()

    @Published private(set) var facts: Set<String> = []
    @Published private(set) var automaticReadback = ""
    @Published private(set) var isPreparedForRoot = false
    let authViewModel: SupabaseAuthViewModel
    let controller: SyncStoreGenerationController
    let shopContextStore: ShopContextStore
    let stateStore: SyncStateStore
    private let owner = UUID(uuidString: "14400000-0000-4000-8000-000000000001")!
    private let shop = UUID(uuidString: "14400000-0000-4000-8000-000000000002")!
    private let transport: Task144ControlledRecoveryTransport
    private let catalogRemote: Task144ControlledCatalogRemote
    private let shopFetcher: Task144ControlledShopFetcher
    private let session: URLSession
    private let emptyBootstrap: Bool
    let provesEmptyFenceRequalification = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_EMPTY_FENCE_REQUALIFICATION"] == "1"
    private let ownedRepository: SyncStoreGenerationRepository
    private let ownedLegacyStoreURL: URL
    private var emptyFenceQualificationSubscription: AnyCancellable?
    private var task: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var hasPreparationStarted = false
    private var hasStarted = false
    private var heldGenerationID: UUID?
    private var heldRecoveryScope: Task126VerifiedOwnerStoreScope?
    private var awaitingAutomaticResumeManifest: SyncStoreGenerationManifest?
    private var completedAutomaticRecoverySummary: SyncRecoverySnapshotPullSummary?
    private let provesShopCallbackOrder = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_CALLBACK_ORDER"] == "1"
    private let provesIndependentPending = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_INDEPENDENT_PENDING"] == "1"
    private let observesReplayScopeComponents = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_LOSE_FIRST_PRODUCT_RESPONSE"] == "1"
    private var independentPendingInserted = false
    private let provesRelatedSave = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_RELATED_SAVE"] == "1"
    private var lastAutomaticResult = "not-observed"
    private var lastAutomaticPresentationID: String?
    private var lastAutomaticInvocationID: UUID?
    private var lastAutomaticCallbackUptime: TimeInterval?
    private var lastObservationPayload = ""
    private var observationSequence = 0
    // Bounded value-only evidence for the existing independent-pending control.
    // These observations do not grant scope, submit work or alter its oracle.
    private struct ProductHTTPObservation {
        let id: UUID
        let payloadHash: String
        let scope: Task126VerifiedOwnerStoreScope
        let sealedToken: LocalPendingChangeCASToken?
        let sealedHash: String?
        let sealedBodyCorresponds: Bool
        let precedingACK: String
        let precedingCASMatches: String
        var providerReturned = false
    }
    private var productHTTPObservations: [ProductHTTPObservation] = []
    private var automaticCompletionObservations: [String] = []
    private var productHTTPObservationCapped = false
    private let namespace: UUID
    private var callbackHeartbeatEntered = false
    private var callbackHeartbeatCompleted = false
    private var callbackHeartbeatContinuation: CheckedContinuation<Void, Never>?
    private var callbackCompletionContinuation: CheckedContinuation<Void, Never>?


    private enum SetupStage: String {
        case shopDiscovery = "shop-discovery"
        case reopen = "reopen"
        case initialRecovery = "initial-recovery"
        case postInitialScope = "post-initial-scope"
        case heldJournal = "held-journal"
        case heldRecovery = "held-recovery"
        case automaticTerminal = "automatic-terminal"
    }

    private init(runID: UUID) throws {
        namespace = runID
        emptyBootstrap = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_EMPTY_BOOTSTRAP"] == "1"
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw URLError(.cannotCreateFile)
        }
        let root = support.appendingPathComponent("task144-root-fixtures", isDirectory: true)
            .appendingPathComponent(runID.uuidString.lowercased(), isDirectory: true)
        // Configure the owned journal path before establishing this TEST scope.
        // Existing stores and persistent domains are neither reset nor removed.
        let repository = try SyncStoreGenerationRepository(
            baseDirectory: root.appendingPathComponent("generation-root", isDirectory: true),
            legacyDefaultStoreURL: root.appendingPathComponent("legacy.store"))
        ownedRepository = repository
        ownedLegacyStoreURL = root.appendingPathComponent("legacy.store")
        let linkedShop = LinkedShop(shopID: shop, code: "TASK144", name: "Controlled local root",
            role: "owner", status: "active", selectable: true, canWrite: true)
        let hash = AccountBindingStore.accountHash(for: owner)
        let selected = SelectedShopStore()
        selected.noteActiveAccount(hash)
        guard selected.save(SelectedShop(linkedShop: linkedShop), accountHash: hash),
              AccountBindingStore().saveBinding(accountHash: hash,
                storeIdentity: LocalStoreIdentity(rawValue: shop.uuidString.lowercased())) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let device = try DeviceInstallIDStore().requireDeviceInstallID()
        controller = try SyncStoreGenerationController(repository: repository)
        let product = RemoteInventoryProductRow(
            id: UUID(uuidString: "14400000-0000-4000-8000-000000000003")!,
            ownerUserID: owner, shopID: shop, barcode: "LOCAL-ROOT", itemNumber: "root fixture",
            productName: "Safe local baseline", secondProductName: nil, purchasePrice: nil,
            retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil,
            updatedAt: "2026-07-21T12:00:00.000000Z", deletedAt: nil)
        transport = try Task144ControlledRecoveryTransport(owner: owner, shop: shop, device: device,
            product: emptyBootstrap ? nil : product)
        catalogRemote = Task144ControlledCatalogRemote(initial: product,
            authoritativeScope: transport.baseline.scope, isEmpty: emptyBootstrap, allowsRelatedSave: provesRelatedSave)
        shopFetcher = Task144ControlledShopFetcher(shop: linkedShop)
        shopContextStore = ShopContextStore(fetcher: shopFetcher)
        stateStore = SyncStateStore(keyPrefix: "task144.controlled.\(runID.uuidString.lowercased())")

        let storage = Task144ControlledAuthStorage()
        let host = "task144-\(runID.uuidString.lowercased()).example.invalid"
        let user = User(id: owner, appMetadata: [:], userMetadata: [:], aud: "authenticated",
            email: "local-availability-fixture@long-account-domain.example.invalid", createdAt: Date(timeIntervalSince1970: 1_700_000_000), updatedAt: Date(timeIntervalSince1970: 1_700_000_000))
        let authSession = Session(accessToken: "task144-controlled-access", tokenType: "bearer",
            expiresIn: 3600, expiresAt: Date().timeIntervalSince1970 + 3600,
            refreshToken: "task144-controlled-refresh", user: user)
        try storage.store(key: "sb-\(host.split(separator: ".")[0])-auth-token",
            value: JSONEncoder().encode(authSession))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Task144ControlledNetworkBlocker.self]
        session = URLSession(configuration: configuration)
        let provider = SupabaseClientProvider(config: .init(projectURL: URL(string: "https://\(host)")!,
            publishableKey: "task144-controlled-public", productImageAPIBaseURL: nil),
            authStorage: storage, session: session, autoRefreshToken: false,
            authRegistry: SupabaseAuthClientRegistry())
        authViewModel = SupabaseAuthViewModel(authService: SupabaseAuthService(provider: provider))
        transport.onHeld = { [weak self] in
            self?.facts.insert("task144.controlled.held")
            Task144RootObservation.record("fixture-boundary", "branch.existing-transport-on-held", callsite: "Task144.onHeld")
        }
        transport.checkpointBoundary = { [weak self] in await self?.releasePreviousShopCallbackAtCheckpoint() }
        if provesIndependentPending {
            // Explicit opt-in controlled counterexample: commit the first
            // typed Product body, lose only its response, then let the normal
            // runtime retry the durable sealed attempt. The oracle is unchanged.
            catalogRemote.losesFirstCommittedProductResponse = ProcessInfo.processInfo.environment[
                "TASK144_LOCAL_AVAILABILITY_LOSE_FIRST_PRODUCT_RESPONSE"] == "1"
            catalogRemote.observeProductAttempt = { [weak self] id, payload, scope, providerReturning in
                self?.observeProductHTTP(id: id, payload: payload, scope: scope, providerReturning: providerReturning)
            }
        }
    }

    func noteOptionsAccountLayout(dynamicTypeSize: DynamicTypeSize, usesAccessibilityStack: Bool) {
        let typePrefix = "task144.controlled.swiftui-type."
        let layoutPrefix = "task144.controlled.account-layout."
        facts = facts.filter { !$0.hasPrefix(typePrefix) && !$0.hasPrefix(layoutPrefix) }
        facts.insert(typePrefix + (dynamicTypeSize == .accessibility5 ? "accessibility5" : "other"))
        facts.insert(layoutPrefix + (usesAccessibilityStack ? "accessibility-stack" : "ordinary-fit"))
    }

    func prepareIfNeeded() {
        guard !hasPreparationStarted else { return }
        let actualCategory = UIApplication.shared.preferredContentSizeCategory
        facts.insert(actualCategory == .accessibilityExtraExtraExtraLarge
            ? "task144.controlled.content-size.accessibility-xxxl"
            : "task144.controlled.content-size.other")
        hasPreparationStarted = true
        // Establish the fixture's real persisted baseline before mounting the
        // business root. Its normal startup must not race this setup recovery.
        preparationTask = Task { [weak self] in
            guard let self else { return }
            var setupStage = SetupStage.shopDiscovery
            do {
                for _ in 0..<200 {
                    if authViewModel.isSignedIn,
                       authViewModel.localMutationOwnerUserID == owner { break }
                    try await Task.sleep(for: .milliseconds(50))
                }
                guard authViewModel.isSignedIn,
                      authViewModel.localMutationOwnerUserID == owner else { throw URLError(.timedOut) }
                await shopContextStore.refresh(ownerUserID: owner)
                guard shopContextStore.context.syncAllowed else { throw URLError(.timedOut) }
                if controller.activeManifest != nil {
                    setupStage = .reopen
                    controller.startLocalBodyQualification(ownerUserID: owner)
                    let qualified = await controller.awaitLocalBodyQualification()
                    facts.insert("task144.controlled.reopen-qualification.\(qualified)")
                    guard qualified else {
                        facts.insert("task144.controlled.reopen-terminal.not-run")
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    let terminal: Bool
                    do {
                        terminal = try terminalReadback(observesReopenFailure: true)
                    } catch {
                        facts.insert("task144.controlled.reopen-terminal.throws")
                        throw error
                    }
                    facts.insert("task144.controlled.reopen-terminal.\(terminal)")
                    guard terminal else { throw SyncStoreGenerationError.activationReadBackFailed }
                    facts.formUnion(["task144.controlled.reopened", "task144.controlled.queue-empty-no-duplicates"])
                    hasStarted = true
                    isPreparedForRoot = true
                    return
                }
                if !emptyBootstrap {
                    setupStage = .initialRecovery
                    _ = try await recoveryService().recoverFromRemoteSnapshot(ownerUserID: owner)
                    setupStage = .postInitialScope
                    guard await controller.awaitLocalBodyQualification() else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                }
                isPreparedForRoot = true
            } catch {
                recordSetupFailure(error, stage: setupStage)
            }
        }
    }

    /// Called after the real root has completed its ordinary shop refresh and
    /// bootstrap. This fixture never manually submits or drains a business run.
    func startIfNeeded() {
        guard isPreparedForRoot, !hasStarted else { return }
        hasStarted = true
        // Owned above the App's generation .id; activation must not cancel it.
        task = Task { [weak self] in
            guard let self else { return }
            var setupStage = SetupStage.heldJournal
            do {
                guard authViewModel.isSignedIn,
                      authViewModel.localMutationOwnerUserID == owner,
                      shopContextStore.context.syncAllowed else { throw URLError(.timedOut) }
                setupStage = .heldJournal
                if let binding = AccountBindingStore().currentBinding {
                    guard AccountBindingStore().beginSameScopeRecovery(accountHash: binding.accountHash,
                        storeIdentity: binding.storeIdentity, reason: "TASK144_CONTROLLED_ROOT_HELD",
                        deviceIdentityHash: DeviceInstallIDStore.identityHash(for: try DeviceInstallIDStore().requireDeviceInstallID())) else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                }
                heldRecoveryScope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                    allowsPendingSameScopeRecovery: true)
                transport.holdsProducts = true
                heldGenerationID = controller.activeManifest?.generationID
                stateStore.updatePhase(.checking)
                setupStage = .heldRecovery
                let recovery = Task {
                    do {
                        return try await self.recoveryService().recoverFromRemoteSnapshot(ownerUserID: self.owner)
                    } catch {
                        if !self.rememberPublishedShopUnavailability(error) {
                            self.recordSetupFailure(error, stage: .heldRecovery)
                        }
                        throw error
                    }
                }
                defer { recovery.cancel() }
                while !transport.isReleased {
                    if try durableSaveReadback() {
                        facts.insert("task144.controlled.local-save-durable")
                        if provesIndependentPending, !independentPendingInserted {
                            try insertIndependentPendingHistory()
                        }
                    }
                    try await Task.sleep(for: .milliseconds(100))
                }
                let summary: SyncRecoverySnapshotPullSummary?
                do { summary = try await recovery.value }
                catch {
                    // Only the first actual throw's verified published boundary
                    // may wait for the ordinary automatic runtime to resume.
                    guard error as? Task126OwnerStoreGateError == .shopContextUnavailable,
                          awaitingAutomaticResumeManifest != nil else { throw error }
                    summary = nil
                }
                if let summary {
                    guard summary.completedRecoveryJournal, controller.activeManifest != nil else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    facts.insert("task144.controlled.activated")
                }
                setupStage = .automaticTerminal
                // No direct push or synthetic ACK here. The real root observes
                // the resolved shop/local mutation and runs its normal facade.
                for _ in 0..<300 {
                    refreshAutomaticObservation()
                    let activated: Bool
                    if summary != nil { activated = true }
                    else if let returned = completedAutomaticRecoverySummary,
                            let published = awaitingAutomaticResumeManifest {
                        activated = automaticRecoveryCompletionIsCurrent(returned, manifest: published)
                        if activated { facts.insert("task144.controlled.activated") }
                    } else { activated = false }
                    if activated {
                        if summary == nil, emptyBootstrap { return }
                        if provesRelatedSave, try relatedMappingPendingReadback() {
                            facts.insert("task144.controlled.related-mapped-product-pending")
                        }
                        if provesRelatedSave, try relatedProductACKReadback() {
                            facts.insert("task144.controlled.related-save-ack")
                            return
                        }
                        if provesIndependentPending, try productACKWithIndependentPendingReadback() {
                            facts.insert("task144.controlled.product-ack-other-pending")
                            return
                        }
                        if try terminalReadback(), catalogRemote.attemptCount == 1, catalogRemote.eventCount == 1 {
                            facts.formUnion(["task144.controlled.activated-and-drained", "task144.controlled.queue-empty-no-duplicates"])
                            return
                        }
                    }
                    try await Task.sleep(for: .milliseconds(100))
                }
                throw SyncStoreGenerationError.activationReadBackFailed
            } catch {
                recordSetupFailure(error, stage: setupStage)
            }
        }
    }

    /// TEST-only scheduling of the existing async heartbeat callback. It grants
    /// no scope or readiness and is inactive outside its explicit namespace.
    func awaitControlledShopHeartbeatForOrderingProof() async -> Bool {
        guard provesShopCallbackOrder, !callbackHeartbeatEntered else { return false }
        callbackHeartbeatEntered = true
        facts.insert("task144.controlled.previous-shop-callback-entered")
        Task144RootObservation.record("fixture-boundary", "branch.existing-previous-callback-entered", callsite: "Task144.awaitControlledShopHeartbeatForOrderingProof")
        await withCheckedContinuation { callbackHeartbeatContinuation = $0 }
        facts.insert("task144.controlled.previous-shop-callback-released")
        Task144RootObservation.record("fixture-boundary", "branch.existing-previous-callback-released", callsite: "Task144.awaitControlledShopHeartbeatForOrderingProof")
        return true
    }

    func noteControlledShopHeartbeatCompleted() {
        guard provesShopCallbackOrder, callbackHeartbeatEntered else { return }
        callbackHeartbeatCompleted = true
        callbackCompletionContinuation?.resume(); callbackCompletionContinuation = nil
    }

    private func releasePreviousShopCallbackAtCheckpoint() async {
        guard provesShopCallbackOrder, transport.holdsProducts, !transport.isReleased else { return }
        guard callbackHeartbeatEntered else { return }
        callbackHeartbeatContinuation?.resume(); callbackHeartbeatContinuation = nil
        if !callbackHeartbeatCompleted {
            await withCheckedContinuation { callbackCompletionContinuation = $0 }
        }
    }

    /// TEST-only value observation. This does not authorize, trigger or retry recovery.
    private func rememberPublishedShopUnavailability(_ error: Error) -> Bool {
        guard error as? Task126OwnerStoreGateError == .shopContextUnavailable,
              let scope = heldRecoveryScope, scope.ownerUserID == owner,
              authViewModel.isSignedIn, authViewModel.localMutationOwnerUserID == scope.ownerUserID,
              UserDefaults.standard.string(forKey: "mobile.shopContext.activeAccountHash.v1") == scope.accountHash,
              let selected = SelectedShopStore().selectedShop(accountHash: scope.accountHash),
              selected.shopID == scope.shopID, selected.localStoreIdentity == scope.storeIdentity,
              selected.selectable, selected.status == "active",
              let device = try? DeviceInstallIDStore().requireDeviceInstallID(),
              device == scope.deviceInstallID, DeviceInstallIDStore.identityHash(for: device) == scope.deviceIdentityHash,
              !SelectedShopStore().hasConfirmedDeviceDenial(accountHash: scope.accountHash,
                shopID: scope.shopID, deviceIdentityHash: scope.deviceIdentityHash),
              let binding = AccountBindingStore().currentBinding,
              binding.accountHash == scope.accountHash, binding.storeIdentity == scope.storeIdentity,
              let manifest = controller.activeManifest,
              manifest.accountHash == scope.accountHash, manifest.shopID == scope.shopID,
              manifest.storeIdentity == scope.storeIdentity, manifest.deviceIdentityHash == scope.deviceIdentityHash,
              let journal = AccountBindingStore().pendingRecoveryJournal,
              journal.mode == .sameScopeRecovery, journal.phase == .activated,
              journal.replacement == scope.pendingReplacement, journal.deviceIdentityHash == scope.deviceIdentityHash,
              journal.generationID == manifest.generationID, journal.checkpointDigest == manifest.checkpoint.checkpointDigest,
              journal.watermark == manifest.checkpoint.maxEventID, journal.baselineRunID == manifest.baselineRunID else { return false }
        // Preserve the first throw's actual publication before a future real
        // automatic completion may clear its journal. No readiness fact is made.
        awaitingAutomaticResumeManifest = manifest
        return true
    }

    private func automaticRecoveryCompletionIsCurrent(
        _ summary: SyncRecoverySnapshotPullSummary, manifest: SyncStoreGenerationManifest
    ) -> Bool {
        guard transport.isReleased, let initial = heldRecoveryScope,
              summary.completedRecoveryJournal, summary.activatedGenerationID == manifest.generationID,
              summary.watermarkAfter == manifest.checkpoint.maxEventID,
              controller.activeManifest == manifest, !AccountBindingStore().hasPendingReplacementJournal,
              authViewModel.isSignedIn, authViewModel.localMutationOwnerUserID == initial.ownerUserID,
              let current = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: initial.ownerUserID),
              current.ownerUserID == initial.ownerUserID, current.accountHash == initial.accountHash,
              current.shopID == initial.shopID, current.storeIdentity == initial.storeIdentity,
              current.deviceInstallID == initial.deviceInstallID, current.deviceIdentityHash == initial.deviceIdentityHash,
              current.pendingReplacement == nil,
              manifest.accountHash == current.accountHash, manifest.shopID == current.shopID,
              manifest.storeIdentity == current.storeIdentity, manifest.deviceIdentityHash == current.deviceIdentityHash,
              (try? Task126OwnerStoreGate.revalidateAutomaticScope(current)) != nil,
              (try? controller.isActiveRecoveryFinalized(scope: current)) == true,
              Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: controller.modelContainer,
                ownerUserID: current.ownerUserID) else { return false }
        return true
    }

    private func observeAutomaticRecoverySummary(ownerUserID: UUID, summary: SyncRecoverySnapshotPullSummary) {
        guard ownerUserID == owner, summary.completedRecoveryJournal,
              let manifest = awaitingAutomaticResumeManifest ?? controller.activeManifest,
              controller.activeManifest == manifest,
              summary.activatedGenerationID == manifest.generationID,
              summary.watermarkAfter == manifest.checkpoint.maxEventID else { return }
        // Retain only the real returned value here. The existing wait loop must
        // independently admit current scope/body/finalization before any fact.
        completedAutomaticRecoverySummary = summary
    }

    private func recordSetupFailure(_ error: Error, stage: SetupStage) {
        facts.formUnion([
            "task144.controlled.failure",
            "task144.controlled.failure-stage.\(stage.rawValue)",
            "task144.controlled.failure-kind.\(Self.failureKind(error))",
            "task144.controlled.auth-signed-in.\(authViewModel.isSignedIn)",
            "task144.controlled.auth-owner-present.\(authViewModel.localMutationOwnerUserID != nil)",
            "task144.controlled.shop-resolved.\(shopContextStore.context.syncAllowed)",
            "task144.controlled.active-manifest.\(controller.activeManifest != nil)",
            "task144.controlled.recovery-journal.\(AccountBindingStore().hasPendingReplacementJournal)"
        ])
        if stage == .heldRecovery || stage == .automaticTerminal {
            facts.insert("task144.controlled.failure-new-generation.\(controller.activeManifest?.generationID != heldGenerationID)")
            if let journal = AccountBindingStore().pendingRecoveryJournal {
                facts.insert("task144.controlled.failure-journal-phase.\(journal.phase.rawValue)")
            }
        }
        do {
            _ = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                allowsPendingSameScopeRecovery: true)
            facts.insert("task144.controlled.failure-scope.accepted")
        } catch {
            facts.insert("task144.controlled.failure-scope.\(Self.failureKind(error))")
        }
    }

    /// Closed categories only: neither error descriptions nor scope values
    /// become UI-test attachments or console metadata.
    private static func failureKind(_ error: Error) -> String {
        if let error = error as? Task126OwnerStoreGateError {
            switch error {
            case .cancelled: return "scope-cancelled"
            case .activeAccountMismatch: return "scope-account-mismatch"
            case .shopContextUnavailable: return "scope-shop-unavailable"
            case .bindingMismatch: return "scope-binding-mismatch"
            case .replacementInterrupted: return "scope-replacement-interrupted"
            case .scopeChanged: return "scope-changed"
            case .retiredStoreGeneration: return "scope-retired-generation"
            case .localModelUnavailable: return "scope-local-model-unavailable"
            case .localRemoteConflictRequiresReview: return "scope-local-remote-conflict"
            }
        }
        if let error = error as? AtomicGenerationRecoveryError {
            switch error {
            case .journalTransitionRejected: return "journal-transition-rejected"
            case .journalCompletionRejected: return "journal-completion-rejected"
            case .pendingLocalWorkRequiresDrain: return "pending-local-work"
            }
        }
        if let error = error as? SyncStoreGenerationError {
            switch error {
            case .activationReadBackFailed: return "generation-readback-failed"
            case .staleGenerationLease: return "generation-stale-lease"
            case .stagingScopeChanged: return "generation-staging-scope-changed"
            case .stagingChangedAfterVerification: return "generation-staging-changed"
            default: return "generation-other"
            }
        }
        if let error = error as? URLError {
            switch error.code {
            case .timedOut: return "transport-timeout"
            case .cancelled: return "transport-cancelled"
            default: return "transport-other"
            }
        }
        if error is CancellationError { return "task-cancelled" }
        if let error = error as? ShopSyncRecoveryContractError {
            switch error {
            case .authenticationChanged: return "contract-authentication-changed"
            case .checkpointChanged: return "contract-checkpoint-changed"
            case .scopeFenceMissing: return "contract-scope-fence-missing"
            case .markerNotVerified: return "contract-marker-not-verified"
            case .fullRecoveryRequired: return "contract-full-recovery-required"
            default: return "recovery-contract-other"
            }
        }
        return "other"
    }

    func release() {
        facts.remove("task144.controlled.held")
        facts.insert("task144.controlled.released")
        transport.release()
        catalogRemote.releaseHeldProduct()
    }
    func publishCheckingUpdate() {
        stateStore.updatePhase(.failed, outcome: .failed)
        stateStore.updatePhase(.checking)
        facts.insert("task144.controlled.state-updated")
    }

    /// Opt-in file metadata drift in this run's synthetic empty store. The
    /// production view must schedule its own successor qualification.
    func invalidateEmptyRootPhysicalFence() {
        guard provesEmptyFenceRequalification, emptyBootstrap,
              !facts.contains("task144.controlled.empty-fence.invalidated") else { return }
        var stage = "capture-scope"
        var firstFailedPrerequisite: String?
        func prerequisite(_ value: Bool, _ name: String) -> Bool {
            if !value, firstFailedPrerequisite == nil { firstFailedPrerequisite = name }
            return value
        }
        do {
            let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                allowsPendingReplacement: true)
            let phase = stateStore.state.phase
            let container = controller.modelContainer
            let revision = controller.localBodyQualificationRevision
            stage = "initial-prerequisites"
            guard prerequisite(facts.contains("task144.controlled.held"), "held"),
                  prerequisite(!transport.isReleased, "transport-held"),
                  prerequisite(authViewModel.localMutationOwnerUserID == owner, "owner"),
                  prerequisite(controller.activeManifest == nil, "no-manifest"),
                  prerequisite(revision > 0, "qualification-revision"),
                  prerequisite(controller.permitsScopedEmptyRoot(ownerUserID: owner), "empty-admission"),
                  prerequisite(!Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: container, ownerUserID: owner), "no-local-mutation-grant"),
                  prerequisite(AccountBindingStore().hasPendingReplacementJournal, "pending-journal") else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            stage = "capture-initial-fence"
            let before = try ownedRepository.captureActiveMutationFence(for: controller.active)
            stage = "initial-file-metadata"
            let values = try ownedLegacyStoreURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey,
                .contentModificationDateKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true,
                  let modificationDate = values.contentModificationDate else {
                throw SyncStoreGenerationError.activeStoreMissing
            }
            facts.insert("task144.controlled.empty-fence.initially-admitted")
            stage = "physical-fence-invalidation"
            try FileManager.default.setAttributes([.modificationDate: modificationDate.addingTimeInterval(-60)],
                ofItemAtPath: ownedLegacyStoreURL.path)
            stage = "invalidated-fence-readback"
            let after = try ownedRepository.captureActiveMutationFence(for: controller.active)
            guard before != after,
                  let beforeFile = before.files.first(where: { $0.relativePath == ownedLegacyStoreURL.lastPathComponent }),
                  let afterFile = after.files.first(where: { $0.relativePath == ownedLegacyStoreURL.lastPathComponent }),
                  beforeFile.modificationTimeBits != afterFile.modificationTimeBits,
                  controller.modelContainer === container,
                  try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                    allowsPendingReplacement: true) == scope,
                  stateStore.state.phase == phase,
                  !controller.permitsScopedEmptyRoot(ownerUserID: owner) else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            // @Published emits from willSet. Hop to MainActor asynchronously so
            // both the revision and its proof have completed publication.
            emptyFenceQualificationSubscription = controller.$localBodyQualificationRevision.dropFirst().sink { [weak self] published in
                Task { @MainActor [weak self] in
                    guard let self, published != revision,
                          self.controller.localBodyQualificationRevision == published,
                          self.controller.modelContainer === container,
                          self.controller.activeManifest == nil,
                          self.authViewModel.localMutationOwnerUserID == self.owner,
                          self.stateStore.state.phase == phase,
                          !self.transport.isReleased,
                          (try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: self.owner,
                            allowsPendingReplacement: true)) == scope,
                          self.controller.permitsScopedEmptyRoot(ownerUserID: self.owner),
                          !Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: container, ownerUserID: self.owner),
                          AccountBindingStore().hasPendingReplacementJournal else { return }
                    self.facts.insert("task144.controlled.empty-fence.requalified")
                    self.emptyFenceQualificationSubscription = nil
                }
            }
            facts.insert("task144.controlled.empty-fence.invalidated")
            controller.objectWillChange.send()
        } catch {
            var failureFacts: Set<String> = ["task144.controlled.empty-fence.failure",
                "task144.controlled.empty-fence.failure-stage.\(stage)",
                "task144.controlled.empty-fence.failure-kind.\(Self.failureKind(error))"]
            if let firstFailedPrerequisite {
                failureFacts.insert("task144.controlled.empty-fence.failure-prerequisite.\(firstFailedPrerequisite)")
            }
            facts.formUnion(failureFacts)
        }
    }

    func runtime(modelContainer: ModelContainer, stateStore: SyncStateStore) -> any SyncAutomaticRuntimeProviding {
        let lease = controller.captureLease(for: modelContainer)
        let invocationID = UUID()
        let recoveryProvider: (any SyncRecoverySnapshotPullProviding)?
        if hasStarted, transport.isReleased, let published = controller.activeManifest,
           published.generationID != heldGenerationID {
            // A fresh remounted runtime can resume only after the direct held
            // recovery published. Preparation and the pre-cutover root keep nil.
            recoveryProvider = Task144ObservedAtomicRecoveryProvider(base: recoveryService(),
                observe: { [weak self] ownerUserID, summary in
                    self?.observeAutomaticRecoverySummary(ownerUserID: ownerUserID, summary: summary)
                })
        } else { recoveryProvider = nil }
        let runtime = AutomaticSyncRuntimeFacade(authViewModel: authViewModel,
            catalogPushProvider: CatalogPushService(modelContainer: modelContainer, remote: catalogRemote),
            productPriceProvider: nil, historySessionProvider: nil,
            incrementalPullProvider: SyncEventIncrementalPullService(modelContainer: modelContainer,
                remote: catalogRemote, storeGenerationController: controller),
            recoverySnapshotPullProvider: recoveryProvider,
            activityRegistrationProvider: SyncActivityRegistrationService(modelContainer: modelContainer, recorder: catalogRemote),
            runAdmissionValidator: { [controller, transport] in
                guard let lease else { throw SyncStoreGenerationError.staleGenerationLease }
                try await MainActor.run {
                    guard transport.isReleased else { throw URLError(.timedOut) }
                    try controller.validateLease(lease)
                }
            })
        return Task144ObservedAutomaticRuntime(runtime: runtime) { [weak self] action, result in
            self?.recordAutomaticReadback(action: action, result: result, presentationID: lease?.presentationID, invocationID: invocationID)
        }
    }

    /// Observes the result of the real facade; it never submits work or changes
    /// admission. Only closed categories and bounded TEST-row counts are exposed.
    private func recordAutomaticReadback(action: SyncAction, result: SyncAutomaticRunResult, presentationID: String?, invocationID: UUID) {
        let prefix = "task144.controlled.auto."
        let error: String
        switch result.errorCode {
        case nil: error = "none"
        case "providerMissing": error = "recovery-provider-missing"
        case "incrementalProviderMissing": error = "incremental-provider-missing"
        case "atomicProviderRequired": error = "atomic-provider-required"
        case "scopeChanged": error = "scope-changed"
        case "staleGenerationLease": error = "stale-generation-lease"
        case "retiredStoreGeneration": error = "retired-store-generation"
        case "responseMismatch": error = "response-mismatch"
        case "unexpectedCall": error = "fixture-unexpected-call"
        default: error = "other"
        }
        lastAutomaticResult = "\(prefix)result.\(Self.actionKind(action)).\(result.status.rawValue).\(error)"
        lastAutomaticPresentationID = presentationID
        lastAutomaticInvocationID = invocationID
        lastAutomaticCallbackUptime = ProcessInfo.processInfo.systemUptime
        if provesIndependentPending, automaticCompletionObservations.count < 8 {
            automaticCompletionObservations.append(lastAutomaticResult + ".http-entries.\(catalogRemote.attemptCount)")
        }
        refreshAutomaticObservation()
    }

    /// Observational only: no runtime trigger, scope grant or queue action.
    private func refreshAutomaticObservation() {
        let prefix = "task144.controlled.auto."
        var diagnostic = [lastAutomaticResult, "\(prefix)source-current.\(lastAutomaticPresentationID == controller.presentationID)",
            "\(prefix)namespace.\(namespace.uuidString.lowercased())",
            "\(prefix)invocation.\(lastAutomaticInvocationID?.uuidString.lowercased() ?? "none")",
            "\(prefix)callback-uptime.\(lastAutomaticCallbackUptime ?? 0)",
            "\(prefix)source-presentation.\(lastAutomaticPresentationID ?? "none")",
            "\(prefix)current-presentation.\(controller.presentationID)",
            "\(prefix)calls.\(catalogRemote.attemptCount).events.\(catalogRemote.eventCount)",
            "\(prefix)new-generation.\(controller.activeManifest?.generationID != heldGenerationID)",
            "\(prefix)body-proof.\(Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer))",
            "\(prefix)phase.\(Self.phaseKind(stateStore.state.phase))"]
        do {
            let context = ModelContext(controller.modelContainer)
            var pendingDescriptor = FetchDescriptor<LocalPendingChange>()
            pendingDescriptor.fetchLimit = 101
            var outboxDescriptor = FetchDescriptor<SyncEventOutboxEntry>()
            outboxDescriptor.fetchLimit = 101
            let pending = try context.fetch(pendingDescriptor)
            let outbox = try context.fetch(outboxDescriptor)
            guard pending.count <= 100, outbox.count <= 100 else {
                diagnostic.append("\(prefix)rows.capped")
                publishAutomaticObservation(diagnostic)
                return
            }
            let pendingReady = pending.filter { $0.statusRaw == LocalPendingChangeStatus.pending.rawValue }.count
            let pendingAck = pending.filter { $0.statusRaw == LocalPendingChangeStatus.acknowledged.rawValue }.count
            let sent = outbox.filter { $0.statusRaw == SyncEventOutboxStatus.sent.rawValue }.count
            let localOnly = outbox.filter { $0.statusRaw == SyncEventOutboxStatus.localOnly.rawValue }.count
            diagnostic.append("\(prefix)rows.pending.\(pendingReady).ack.\(pendingAck).outbox.\(outbox.count).sent.\(sent).local.\(localOnly)")
        } catch {
            diagnostic.append("\(prefix)rows.read-failed")
        }
        if provesIndependentPending { diagnostic.append(contentsOf: independentProductObservation()) }
        publishAutomaticObservation(diagnostic)
    }

    // The private Catalog mutation is decoded only for observation, after the
    // real immutable-attempt validator has checked its complete envelope.
    private func observeProductHTTP(id: UUID, payload: SyncAutomaticProductUpdatePayload,
        scope: Task126VerifiedOwnerStoreScope, providerReturning: Bool) {
        guard provesIndependentPending else { return }
        do {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            let payloadData = try encoder.encode(payload)
            let payloadHash = ShopSyncRecoveryCanonical.sha256(String(decoding: payloadData, as: UTF8.self))
            if providerReturning {
                guard let index = productHTTPObservations.indices.last,
                      productHTTPObservations[index].id == id,
                      productHTTPObservations[index].payloadHash == payloadHash,
                      productHTTPObservations[index].scope == scope else { return }
                productHTTPObservations[index].providerReturned = true
                return
            }
            guard productHTTPObservations.count < 8 else { productHTTPObservationCapped = true; return }
            let context = ModelContext(controller.modelContainer)
            var changesRequest = FetchDescriptor<LocalPendingChange>(); changesRequest.fetchLimit = 101
            var outboxRequest = FetchDescriptor<SyncEventOutboxEntry>(); outboxRequest.fetchLimit = 101
            let changes = try context.fetch(changesRequest)
            let outbox = try context.fetch(outboxRequest)
            guard changes.count <= 100, outbox.count <= 100 else { productHTTPObservationCapped = true; return }
            var precedingACK = "not-observed"
            var precedingCASMatches = "not-observed"
            if let previous = productHTTPObservations.last?.sealedToken {
                let sameID = changes.filter { $0.changeID == previous.changeID }
                if sameID.count == 1 {
                    precedingACK = String(sameID[0].status == .acknowledged)
                    precedingCASMatches = String(previous.matches(sameID[0]))
                }
            }
            let products = changes.filter { $0.entityKind == .product && $0.status == .pending }
            var token: LocalPendingChangeCASToken?
            var sealedHash: String?
            var corresponds = false
            if products.count == 1 {
                let sealed = outbox.filter { $0.id == products[0].changeID && LocalPendingBusinessAttemptStore.isSealed($0) }
                if sealed.count == 1 {
                    let data = try LocalPendingBusinessAttemptStore.validate(sealed[0], kind: "catalog", scope: scope)
                    let envelope = try JSONDecoder().decode(
                        LocalPendingBusinessAttemptStore.Envelope<Task144ObservedStoredProductMutation>.self, from: data)
                    token = envelope.pending
                    sealedHash = sealed[0].entityIDsShape
                    let incoming = envelope.payload.call.updateProduct
                    corresponds = envelope.pending.matches(products[0]) && incoming.id == id && incoming.payload == payload
                }
            }
            productHTTPObservations.append(.init(id: id, payloadHash: payloadHash, scope: scope,
                sealedToken: token, sealedHash: sealedHash, sealedBodyCorresponds: corresponds,
                precedingACK: precedingACK, precedingCASMatches: precedingCASMatches))
        } catch {
            // Never change the incoming HTTP request or propagate a diagnostic failure.
            productHTTPObservationCapped = true
        }
    }

    private func independentProductObservation() -> [String] {
        let prefix = "task144.controlled.independent."
        var result = ["\(prefix)attempt-observation-capped.\(productHTTPObservationCapped)",
            "\(prefix)caller-cas-result.not-directly-observed",
            "\(prefix)first-product-commit-response-lost.\(catalogRemote.firstProductResponseWasLost)"]
        let first = productHTTPObservations.first
        for (index, observation) in productHTTPObservations.enumerated() {
            let token = observation.sealedToken
            let scope = observation.scope
            let scopeHash = LocalPendingChangeLogicalKey.privacyHash([
                scope.ownerUserID.uuidString.lowercased(), scope.shopID.uuidString.lowercased(),
                scope.deviceIdentityHash, scope.storeIdentity.storeId, scope.storeIdentity.localStoreId,
                String(scope.storeIdentity.syncProtocolVersion), String(scope.storeIdentity.schemaVersion),
                String(scope.storeIdentity.storeEpoch), String(scope.leaseGeneration)].joined(separator: "|"))
            let values: [String] = ["\(prefix)http.\(index + 1)",
                "id.\(LocalPendingChangeLogicalKey.privacyHash(observation.id.uuidString.lowercased()))",
                "body.\(observation.payloadHash)", "scope.\(scopeHash)",
                "sealed-key.\(token.map { LocalPendingChangeLogicalKey.privacyHash($0.idempotencyKey) } ?? "absent")",
                "sealed-revision.\(token?.eventFingerprint ?? "absent")", "sealed-body.\(observation.sealedHash ?? "absent")",
                "incoming-scope-verified.true", "sealed-owner-store-schema-device-valid.\(token != nil)",
                "sealed-corresponds.\(observation.sealedBodyCorresponds)",
                "provider-returned.\(observation.providerReturned)", "preceding-ack.\(observation.precedingACK)",
                "preceding-cas-matches.\(observation.precedingCASMatches)",
                "same-first-id.\(observation.id == first?.id)", "same-first-body.\(observation.payloadHash == first?.payloadHash)",
                "same-first-scope.\(Self.sameStableProductScope(scope, first?.scope))", "same-first-sealed-revision.\(token != nil && token == first?.sealedToken)",
                "same-first-full-scope.\(scope == first?.scope)"]
            result.append(values.joined(separator: "."))
            if observesReplayScopeComponents {
                let components: [String] = ["\(prefix)scope-components.\(index + 1)",
                    "same-first-owner.\(scope.ownerUserID == first?.scope.ownerUserID)",
                    "same-first-account.\(scope.accountHash == first?.scope.accountHash)",
                    "same-first-shop.\(scope.shopID == first?.scope.shopID)",
                    "same-first-full-store.\(scope.storeIdentity == first?.scope.storeIdentity)",
                    "same-first-device-install.\(scope.deviceInstallID == first?.scope.deviceInstallID)",
                    "same-first-device-hash.\(scope.deviceIdentityHash == first?.scope.deviceIdentityHash)",
                    "same-first-full-pending.\(scope.pendingReplacement == first?.scope.pendingReplacement)",
                    "same-first-lease.\(scope.leaseGeneration == first?.scope.leaseGeneration)"]
                result.append(components.joined(separator: "."))
            }
        }
        result.append(contentsOf: automaticCompletionObservations.enumerated().map { "\(prefix)completion.\($0.offset + 1).\($0.element)" })
        result.append(contentsOf: catalogRemote.eventRequestObservations.map { "\(prefix)event.\($0)" })
        do {
            let context = ModelContext(controller.modelContainer)
            var productRequest = FetchDescriptor<Product>(); productRequest.fetchLimit = 2
            var pendingRequest = FetchDescriptor<LocalPendingChange>(); pendingRequest.fetchLimit = 101
            let products = try context.fetch(productRequest)
            let pending = try context.fetch(pendingRequest)
            guard pending.count <= 100 else { result.append("\(prefix)predicates.capped"); return result }
            let productChanges = pending.filter { $0.entityKind == .product }
            let historyChanges = pending.filter { $0.entityKind == .historySession }
            let oneProduct = products.count == 1 && productChanges.count == 1
            let oneHistory = historyChanges.count == 1
            let historyCount = try context.fetchCount(FetchDescriptor<HistoryEntry>())
            let productACK = oneProduct && productChanges[0].status == .acknowledged
            let productFingerprint = oneProduct && productChanges[0].intendedFingerprintHash
                == LocalPendingChangeLogicalKey.productFingerprintHash(products[0])
            let historyNonterminal = oneHistory && !historyChanges[0].status.isTerminal
            let historyOwner = oneHistory && historyChanges[0].ownerUserID == owner.uuidString.lowercased()
            let historyScope = oneHistory && first.map { LocalPendingChangeScopeMatcher.matches(historyChanges[0],
                ownerUserID: $0.scope.ownerUserID, accountHash: $0.scope.accountHash, storeIdentity: $0.scope.storeIdentity) } == true
            let productScope = oneProduct && first.map { LocalPendingChangeScopeMatcher.matches(productChanges[0],
                ownerUserID: $0.scope.ownerUserID, accountHash: $0.scope.accountHash, storeIdentity: $0.scope.storeIdentity) } == true
            let predicates: [(String, Bool)] = [("product-unique", products.count == 1), ("product-intent-unique", productChanges.count == 1),
                ("history-intent-unique", oneHistory), ("product-name", oneProduct && products[0].productName == "Saved before network release"),
                ("product-ack", productACK), ("product-fingerprint", productFingerprint), ("history-nonterminal", historyNonterminal),
                ("history-owner", historyOwner), ("history-count-one", historyCount == 1), ("http-count-one", catalogRemote.attemptCount == 1),
                ("product-exact-scope", productScope), ("history-exact-scope", historyScope),
                ("history-status-pending", oneHistory && historyChanges[0].status == .pending),
                ("single-immutable-product-ack-and-event", oneProduct && oneHistory
                    && hasOneImmutableProductAttemptACK(product: products[0], change: productChanges[0],
                        historyChange: historyChanges[0], context: context))]
            result.append(contentsOf: predicates.map { "\(prefix)predicate.\($0.0).\($0.1)" })
        } catch { result.append("\(prefix)predicates.read-failed") }
        return result
    }

    private func publishAutomaticObservation(_ diagnostic: [String]) {
        let payload = diagnostic.joined(separator: ";")
        guard payload != lastObservationPayload else { return }
        lastObservationPayload = payload
        observationSequence += 1
        automaticReadback = payload + ";sequence=\(observationSequence);captured-uptime=\(ProcessInfo.processInfo.systemUptime)"
    }

    private static func phaseKind(_ phase: SyncPhase) -> String {
        switch phase {
        case .idle: return "idle"
        case .checking: return "checking"
        case .pushing: return "pushing"
        case .pullingEvents: return "pulling-events"
        case .reconciling: return "reconciling"
        case .recoveryRequired: return "recovery-required"
        case .blocked: return "blocked"
        case .failed: return "failed"
        }
    }

    private static func actionKind(_ action: SyncAction) -> String {
        switch action {
        case .noOp: return "noop"
        case .pushPending: return "push"
        case .drainEvents: return "drain"
        case .lightReconcile: return "reconcile"
        case .bootstrap: return "bootstrap"
        case .fullRecovery: return "recovery"
        case .requestRecovery: return "request-recovery"
        case .retryAfterBusy: return "retry-busy"
        case .blocked: return "blocked"
        case .sequence(let actions): return actions.map(actionKind).joined(separator: "-")
        }
    }

    private func recoveryService() -> AtomicGenerationRecoverySnapshotPullService {
        AtomicGenerationRecoverySnapshotPullService(storeGenerationController: controller,
            recoveryRemote: ShopSyncRecoveryRemoteAdapter(transport: transport), pageLimit: 25,
            progressReporter: { [weak stateStore] event in stateStore?.recordRecoveryProgress(event) })
    }

    private func insertIndependentPendingHistory() throws {
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: controller.modelContainer,
            ownerUserID: owner) { context in
            let entry = HistoryEntry(id: "TASK144_INDEPENDENT_PENDING", timestamp: Date(timeIntervalSince1970: 1_784_635_200),
                data: [["Item", "Quantity"], ["Independent pending history", "1"]], uid: UUID())
            context.insert(entry)
            try LocalPendingChangeAccumulator(context: context, ownerUserID: owner)
                .recordHistorySessionChange(entry: entry, operation: .create, changedFields: ["data"])
            try context.save()
        }
        independentPendingInserted = true
        facts.insert("task144.controlled.independent-history-pending")
    }

    private func productACKWithIndependentPendingReadback() throws -> Bool {
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let pending = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let productChanges = pending.filter { $0.entityKind == .product }
        let historyChanges = pending.filter { $0.entityKind == .historySession }
        guard products.count == 1, productChanges.count == 1, historyChanges.count == 1 else { return false }
        let historyCount = try context.fetchCount(FetchDescriptor<HistoryEntry>())
        return products[0].productName == "Saved before network release"
            && productChanges[0].status == .acknowledged
            && productChanges[0].intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(products[0])
            && !historyChanges[0].status.isTerminal
            && historyChanges[0].ownerUserID == owner.uuidString.lowercased()
            && historyCount == 1
            && hasOneImmutableProductAttemptACK(product: products[0], change: productChanges[0],
                historyChange: historyChanges[0], context: context)
    }

    // Compare immutable business identity; each request and the current readback
    // separately validate their own current automatic writer lease.
    private static func sameStableProductScope(_ scope: Task126VerifiedOwnerStoreScope,
        _ reference: Task126VerifiedOwnerStoreScope?) -> Bool {
        guard let reference else { return false }
        return scope.ownerUserID == reference.ownerUserID
            && scope.accountHash == reference.accountHash
            && scope.shopID == reference.shopID
            && scope.storeIdentity == reference.storeIdentity
            && scope.deviceInstallID == reference.deviceInstallID
            && scope.deviceIdentityHash == reference.deviceIdentityHash
            && scope.pendingReplacement == reference.pendingReplacement
    }

    private func hasOneImmutableProductAttemptACK(product: Product, change: LocalPendingChange,
        historyChange: LocalPendingChange, context: ModelContext) -> Bool {
        guard change.status == .acknowledged,
              change.intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(product),
              !historyChange.status.isTerminal,
              !productHTTPObservationCapped, !catalogRemote.eventObservationCapped,
              !productHTTPObservations.isEmpty,
              productHTTPObservations.count == catalogRemote.attemptCount,
              let first = productHTTPObservations.first, let token = first.sealedToken,
              first.sealedHash != nil, first.id == product.remoteID,
              first.scope.ownerUserID == owner, first.scope.shopID == shop,
              token.changeID == change.changeID, token.idempotencyKey == change.idempotencyKey,
              token.intendedFingerprintHash == change.intendedFingerprintHash,
              productHTTPObservations.last?.providerReturned == true,
              LocalPendingChangeScopeMatcher.matches(change, ownerUserID: first.scope.ownerUserID,
                accountHash: first.scope.accountHash, storeIdentity: first.scope.storeIdentity),
              LocalPendingChangeScopeMatcher.matches(historyChange, ownerUserID: first.scope.ownerUserID,
                accountHash: first.scope.accountHash, storeIdentity: first.scope.storeIdentity),
              productHTTPObservations.enumerated().allSatisfy({ entry in
                let observation = entry.element
                return observation.sealedBodyCorresponds && observation.id == first.id
                    && observation.payloadHash == first.payloadHash && Self.sameStableProductScope(observation.scope, first.scope)
                    && observation.sealedToken == token && observation.sealedHash == first.sealedHash
                    && (entry.offset == 0 || (observation.precedingACK == "false"
                        && observation.precedingCASMatches == "true"))
              }) else { return false }
        do {
            // Historical request evidence is immutable. Its retired lease does
            // not authorize this readback: admit and revalidate current authority.
            let current = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner)
            guard current.ownerUserID == first.scope.ownerUserID,
                  current.accountHash == first.scope.accountHash,
                  current.shopID == first.scope.shopID,
                  current.storeIdentity == first.scope.storeIdentity,
                  current.deviceInstallID == first.scope.deviceInstallID,
                  current.deviceIdentityHash == first.scope.deviceIdentityHash,
                  context.container === controller.modelContainer,
                  Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                    modelContainer: context.container, ownerUserID: current.ownerUserID) else { return false }
            var descriptor = FetchDescriptor<SyncEventOutboxEntry>(); descriptor.fetchLimit = 101
            let outbox = try context.fetch(descriptor)
            guard outbox.count <= 100 else { return false }
            let events = outbox.filter { $0.domain == "catalog" }
            guard events.count == 1, let event = events.first,
                  event.status == .sent, event.eventType == "catalog_changed", event.changedCount == 1,
                  event.ownerUserID == first.scope.ownerUserID.uuidString.lowercased(),
                  event.storeId == first.scope.storeIdentity.storeId,
                  event.localStoreId == first.scope.storeIdentity.localStoreId,
                  event.syncProtocolVersion == first.scope.storeIdentity.syncProtocolVersion,
                  event.schemaVersion == first.scope.storeIdentity.schemaVersion,
                  event.storeEpoch == first.scope.storeIdentity.storeEpoch,
                  event.sourceDeviceID == first.scope.deviceInstallID,
                  catalogRemote.eventCount == 1, !catalogRemote.eventRequestKeys.isEmpty,
                  Set(catalogRemote.eventRequestKeys) == Set([event.clientEventID]) else { return false }
            let storedRequest = try SyncEventOutboxPayloadCodec.makeRecordRequestForReplay(from: event)
            let expectedIDs = try AutomaticSyncEventOutboxWriter.entityIDs([
                "supplier_ids": [], "category_ids": [], "product_ids": [first.id]])
            guard storedRequest.entityIDs == expectedIDs,
                  !catalogRemote.eventRequests.isEmpty,
                  catalogRemote.eventRequests.allSatisfy({ $0 == storedRequest }) else { return false }
            try Task126OwnerStoreGate.revalidateAutomaticScope(current)
            return true
        } catch { return false }
    }

    private func relatedProductACKReadback() throws -> Bool {
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let suppliers = try context.fetch(FetchDescriptor<Supplier>())
        let categories = try context.fetch(FetchDescriptor<ProductCategory>())
        guard products.count == 1, suppliers.count == 1, categories.count == 1,
              changes.count == 3, changes.allSatisfy({ $0.status == .acknowledged && $0.ownerUserID == owner.uuidString.lowercased() }) else { return false }
        return products[0].productName == "Saved before network release"
            && products[0].supplier?.name == "New related supplier"
            && products[0].category?.name == "New related category"
            && suppliers[0].remoteID != nil && categories[0].remoteID != nil
            && products[0].supplier?.remoteID == catalogRemote.currentSupplierID
            && products[0].category?.remoteID == catalogRemote.currentCategoryID
            && catalogRemote.attemptCount == 1 && catalogRemote.eventCount == 3
    }

    private func relatedMappingPendingReadback() throws -> Bool {
        guard catalogRemote.isProductHeld else { return false }
        let context = ModelContext(controller.modelContainer)
        var productRequest = FetchDescriptor<Product>(); productRequest.fetchLimit = 2
        var changeRequest = FetchDescriptor<LocalPendingChange>(); changeRequest.fetchLimit = 4
        let products = try context.fetch(productRequest)
        let changes = try context.fetch(changeRequest)
        guard products.count == 1, changes.count == 3,
              changes.allSatisfy({ $0.ownerUserID == owner.uuidString.lowercased() }),
              changes.filter({ $0.entityKind == .supplier || $0.entityKind == .productCategory })
                .allSatisfy({ $0.status == .acknowledged }),
              changes.filter({ $0.entityKind == .product }).count == 1,
              changes.first(where: { $0.entityKind == .product })?.status != .acknowledged else { return false }
        return products[0].supplier?.remoteID == catalogRemote.currentSupplierID
            && products[0].category?.remoteID == catalogRemote.currentCategoryID
            && catalogRemote.currentSupplierID != nil && catalogRemote.currentCategoryID != nil
    }

    private func durableSaveReadback() throws -> Bool {
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let pending = try context.fetch(FetchDescriptor<LocalPendingChange>())
        return products.count == 1 && products[0].productName == "Saved before network release"
            && pending.contains { $0.status == .pending && $0.ownerUserID == owner.uuidString.lowercased() }
    }
    private func terminalReadback(observesReopenFailure: Bool = false) throws -> Bool {
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let pending = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let outbox = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>())
        let prices = try context.fetchCount(FetchDescriptor<ProductPrice>())
        let history = try context.fetchCount(FetchDescriptor<HistoryEntry>())
        let checks: [(String, Bool)] = [
            ("product-unique", products.count == 1),
            ("product-name", products.count == 1 && products[0].productName == "Saved before network release"),
            ("intent-unique", pending.count == 1),
            ("intent-acknowledged", pending.allSatisfy { $0.status == .acknowledged }),
            ("sent-unique", outbox.filter { $0.status == .sent }.count == 1),
            ("outbox-allowed", outbox.allSatisfy { $0.status == .localOnly || $0.status == .sent }),
            ("price-empty", prices == 0),
            ("history-empty", history == 0)
        ]
        let valid = checks.allSatisfy { $0.1 }
        if observesReopenFailure && !valid {
            for (name, passed) in checks {
                facts.insert("task144.controlled.terminal-\(name).\(passed)")
            }
        }
        return valid
    }
}

private nonisolated struct Task144ObservedAtomicRecoveryProvider: SyncRecoverySnapshotPullProviding {
    let base: AtomicGenerationRecoverySnapshotPullService
    let observe: @MainActor @Sendable (UUID, SyncRecoverySnapshotPullSummary) -> Void
    nonisolated var publicationMode: SyncRecoverySnapshotPublicationMode { base.publicationMode }

    func recoverFromRemoteSnapshot(ownerUserID: UUID) async throws -> SyncRecoverySnapshotPullSummary {
        let summary = try await base.recoverFromRemoteSnapshot(ownerUserID: ownerUserID)
        observe(ownerUserID, summary)
        return summary
    }
}

@MainActor
private final class Task144ObservedAutomaticRuntime: SyncAutomaticRuntimeProviding {
    private let runtime: any SyncAutomaticRuntimeProviding
    private let observe: (SyncAction, SyncAutomaticRunResult) -> Void

    init(runtime: any SyncAutomaticRuntimeProviding,
         observe: @escaping (SyncAction, SyncAutomaticRunResult) -> Void) {
        self.runtime = runtime
        self.observe = observe
    }
    var isRunning: Bool { runtime.isRunning }
    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> SyncAutomaticRunResult {
        let result = await runtime.run(action: action, source: source)
        observe(action, result)
        return result
    }
    func cancel() { runtime.cancel() }
    func cancelAndWait() async { await runtime.cancelAndWait() }
    func resumeAfterStoreReplacement() async { await runtime.resumeAfterStoreReplacement() }
}

struct Task144ControlledRootAdmission<Content: View>: View {
    @ObservedObject var fixture: Task144LocalAvailabilityRootFixture
    @ViewBuilder let content: () -> Content

    var body: some View {
        if fixture.isPreparedForRoot {
            content()
        } else {
            ProgressView("Preparing controlled local baseline")
                .accessibilityValue(fixture.facts.sorted().joined(separator: ";"))
        }
    }
}

private struct Task144ControlledRootControls: View {
    @ObservedObject var fixture: Task144LocalAvailabilityRootFixture
    let controlPrefix: String
    var body: some View {
        VStack(spacing: 1) {
            ForEach(fixture.facts.sorted(), id: \.self) { fact in
                Text(fact).font(.system(size: 8)).accessibilityIdentifier(fact)
            }
            HStack {
                if fixture.provesEmptyFenceRequalification {
                    Text("Change controlled empty store fence")
                        .padding(8).contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1) { fixture.invalidateEmptyRootPhysicalFence() }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityIdentifier("\(controlPrefix).empty-fence.invalidate")
                }
                Text("Controlled state update")
                    .padding(8).contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 1) { fixture.publishCheckingUpdate() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("\(controlPrefix).state-update")
                Text("Release controlled transport")
                    .padding(8).contentShape(Rectangle())
                    .onLongPressGesture(minimumDuration: 1) { fixture.release() }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityValue(fixture.automaticReadback)
                    .accessibilityIdentifier("\(controlPrefix).release")
            }.font(.caption2)
        }.padding(2).background(.ultraThinMaterial)
            // Observation controls must not consume the product's viewport
            // when the real root is exercised at accessibility text sizes.
            .dynamicTypeSize(.medium ... .large)
    }
}
private struct Task144ControlledRootModifier: ViewModifier {
    let inEditor: Bool
    func body(content: Content) -> some View {
        if let fixture = Task144LocalAvailabilityRootFixture.current {
            content.safeAreaInset(edge: .top, spacing: 0) {
                Task144ControlledRootControls(fixture: fixture,
                    controlPrefix: inEditor ? "task144.controlled.editor" : "task144.controlled")
            }
        } else { content }
    }
}
extension View {
    func task144ControlledRootControls(inEditor: Bool = false) -> some View {
        modifier(Task144ControlledRootModifier(inEditor: inEditor))
    }
}

@MainActor
private final class Task144ControlledShopFetcher: LinkedShopFetching {
    let shop: LinkedShop
    init(shop: LinkedShop) { self.shop = shop }
    func fetchLinkedShops() async throws -> [LinkedShop] {
        return [shop]
    }
}

@MainActor
private final class Task144ControlledRecoveryTransport: ShopSyncRecoveryRPCTransporting {
    let owner: UUID
    let product: RemoteInventoryProductRow?
    let baseline: ShopSyncRecoveryCheckpoint
    var holdsProducts = false
    private(set) var isReleased = false
    var onHeld: (() -> Void)?
    var checkpointBoundary: (() async -> Void)?
    private var continuation: CheckedContinuation<Void, Never>?
    init(owner: UUID, shop: UUID, device: String, product: RemoteInventoryProductRow?) throws {
        self.owner = owner; self.product = product
        let hash = ShopSyncRecoveryCanonical.checkpointChainInitialDigest
        let empty = ShopSyncRecoveryEntityDigest(activeCount: 0, tombstoneCount: 0, idSetDigest: hash, versionDigest: hash)
        let scope = ShopSyncRecoveryScope(kind: "shop_scoped",
            key: ShopSyncRecoveryCanonical.sha256(shop.uuidString.lowercased() + ":shop_scoped:-:" + ShopSyncRecoveryCanonical.sha256(device)),
            legacyOwnerKey: nil, accountKey: AccountBindingStore.accountHash(for: owner),
            deviceKey: ShopSyncRecoveryCanonical.sha256(device))
        let events = ShopSyncRecoveryEventCheckpoint(maxId: "41", verifiedBaselineId: "0", requiresFullRecovery: true,
            domainMaxIds: .init(catalog: "41", prices: "41", history: "41"))
        let integrity = ShopSyncRecoveryIntegrity(productCategoryViolationCount: 0, productSupplierViolationCount: 0,
            priceProductViolationCount: 0, primaryImageViolationCount: 0, historyIdViolationCount: 0, totalViolationCount: 0)
        let initial = ShopSyncRecoveryCheckpoint(schemaVersion: "shop-sync-recovery-checkpoint-v1", shopId: shop,
            scope: scope, syncEvents: events, catalog: .init(suppliers: empty, categories: empty,
                products: .init(activeCount: 0, tombstoneCount: 0, idSetDigest: hash, versionDigest: hash, identityDigest: hash),
                digest: ShopSyncRecoveryCanonical.sha256(hash + "\n" + hash + "\n" + hash)),
            prices: empty, history: empty, images: empty, integrity: integrity,
            checkpointDigest: ShopSyncRecoveryCanonical.sha256("task144-controlled-root"))
        var accumulator = ShopSyncRecoveryDigestAccumulator(hasIdentity: true)
        if let product {
            let row = try ShopSyncRecoveryRowContract.product(product, checkpoint: initial)
            try accumulator.append(orderingID: row.orderingID, idLine: row.idLine, versionLine: row.versionLine,
                identityLine: row.identityLine, isTombstone: row.isTombstone)
        }
        let products = accumulator.finalize()
        baseline = ShopSyncRecoveryCheckpoint(schemaVersion: initial.schemaVersion, shopId: shop, scope: scope,
            syncEvents: events, catalog: .init(suppliers: empty, categories: empty, products: products,
                digest: ShopSyncRecoveryCanonical.sha256(hash + "\n" + hash + "\n" + products.versionDigest)),
            prices: empty, history: empty, images: empty, integrity: integrity, checkpointDigest: initial.checkpointDigest)
    }
    func release() { isReleased = true; continuation?.resume(); continuation = nil }
    func authenticatedUserID() async throws -> UUID { owner }
    func checkpoint(_ parameters: ShopSyncRecoveryCheckpointParameters) async throws -> Data {
        await checkpointBoundary?()
        return try JSONEncoder().encode(ShopSyncRecoveryCheckpoint(schemaVersion: baseline.schemaVersion, shopId: baseline.shopId,
            scope: baseline.scope, syncEvents: .init(maxId: "41", verifiedBaselineId: parameters.verifiedBaselineID,
                requiresFullRecovery: true, domainMaxIds: baseline.syncEvents.domainMaxIds), catalog: baseline.catalog,
            prices: baseline.prices, history: baseline.history, images: baseline.images, integrity: baseline.integrity,
            checkpointDigest: baseline.checkpointDigest))
    }
    func page(_ parameters: ShopSyncRecoveryPageParameters) async throws -> Data {
        guard let domain = ShopSyncRecoveryDomain(rawValue: parameters.domain) else { throw ShopSyncRecoveryContractError.invalidCheckpoint }
        if holdsProducts && domain == .products && !isReleased {
            onHeld?()
            await withCheckedContinuation { continuation = $0 }
            try Task.checkCancellation()
        }
        return try JSONEncoder().encode(Task144ControlledPage(schemaVersion: "shop-sync-recovery-page-v1",
            shopId: parameters.shopID, scope: baseline.scope, domain: domain,
            snapshotEventMaxId: parameters.expectedEventMaxID, currentScopeEventMaxId: parameters.expectedEventMaxID,
            baselineDomainEventMaxId: parameters.expectedDomainEventMaxID, pageDomainEventMaxId: parameters.expectedDomainEventMaxID,
            domainScope: domain == .history ? baseline.scope.historyKind : baseline.scope.kind,
            pageLimit: parameters.limit, rows: domain == .products ? product.map { [$0] } ?? [] : [], nextAfterId: nil, hasMore: false))
    }
    func marker(_ parameters: ShopSyncConvergenceMarkerParameters) async throws -> Data {
        try JSONEncoder().encode(ShopSyncRecoveryConvergenceMarker(schemaVersion: "shop-sync-convergence-marker-v1",
            status: "ready", shopId: baseline.shopId, scope: baseline.scope,
            syncEvents: .init(maxId: "41", verifiedBaselineId: parameters.verifiedBaselineID, requiresFullRecovery: false,
                domainMaxIds: baseline.syncEvents.domainMaxIds), catalog: baseline.catalog, prices: baseline.prices,
            history: baseline.history, images: baseline.images, integrity: .init(totalViolationCount: 0),
            checkpointDigest: baseline.checkpointDigest, serverNoWorkEligible: true,
            markerDigest: ShopSyncRecoveryCanonical.sha256("task144-controlled-marker")))
    }
    func eventPage(_ parameters: ShopSyncEventPageParameters) async throws -> Data { throw ShopSyncRecoveryContractError.fullRecoveryRequired }
}
private nonisolated struct Task144ControlledPage: Encodable {
    let schemaVersion: String; let shopId: UUID; let scope: ShopSyncRecoveryScope; let domain: ShopSyncRecoveryDomain
    let snapshotEventMaxId: String; let currentScopeEventMaxId: String
    let baselineDomainEventMaxId: String; let pageDomainEventMaxId: String; let domainScope: String
    let pageLimit: Int; let rows: [RemoteInventoryProductRow]; let nextAfterId: String?; let hasMore: Bool
}

nonisolated private struct Task144ObservedStoredProductMutation: Codable {
    struct Call: Codable {
        struct Arguments: Codable {
            let id: UUID
            let payload: SyncAutomaticProductUpdatePayload
            enum CodingKeys: String, CodingKey { case id = "_0"; case payload = "_1" }
        }
        let updateProduct: Arguments
    }
    let call: Call
}

@MainActor
private final class Task144ControlledCatalogRemote: SyncAutomaticCatalogRemoteWriting, SyncEventRecording,
    SyncAutomaticIncrementalRemote, ShopScopedIncrementalRPCAuthorizing,
    ShopScopedIncrementalFencePersisting, @unchecked Sendable {
    nonisolated let usesServerAuthorizedShopScope = true
    enum Fault: Error { case unexpectedCall }
    private var current: RemoteInventoryProductRow
    private let authoritativeScope: ShopSyncRecoveryScope
    private let isEmpty: Bool
    private var events: [RemoteSyncEventRow] = []
    private var eventClientIDs: [String: RemoteSyncEventRow] = [:]
    private let allowsRelatedSave: Bool
    private var supplier: RemoteInventorySupplierRow?
    private var category: RemoteInventoryCategoryRow?
    private var productContinuation: CheckedContinuation<Void, Never>?
    private(set) var isProductHeld = false
    var currentSupplierID: UUID? { supplier?.id }
    var currentCategoryID: UUID? { category?.id }
    private(set) var attemptCount = 0
    private(set) var eventCount = 0
    var observeProductAttempt: ((UUID, SyncAutomaticProductUpdatePayload, Task126VerifiedOwnerStoreScope, Bool) -> Void)?
    private(set) var eventRequestObservations: [String] = []
    private(set) var eventRequestKeys: [String] = []
    private(set) var eventRequests: [SyncEventRecordRequest] = []
    private(set) var eventObservationCapped = false
    var losesFirstCommittedProductResponse = false
    private(set) var firstProductResponseWasLost = false
    init(initial: RemoteInventoryProductRow, authoritativeScope: ShopSyncRecoveryScope, isEmpty: Bool, allowsRelatedSave: Bool) {
        current = initial; self.authoritativeScope = authoritativeScope; self.isEmpty = isEmpty
        self.allowsRelatedSave = allowsRelatedSave
    }
    func createSuppliers(_ payloads: [SyncAutomaticSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow] {
        _ = try verifiedScope()
        guard allowsRelatedSave, payloads.count == 1, let payload = payloads.first,
              payload.ownerUserID == current.ownerUserID, payload.shopID == current.shopID,
              payload.name == "New related supplier", supplier == nil || supplier?.id == payload.id else { throw Fault.unexpectedCall }
        let row = RemoteInventorySupplierRow(id: payload.id, ownerUserID: payload.ownerUserID, shopID: payload.shopID,
            name: payload.name, updatedAt: "2026-07-21T12:01:00.000000Z", deletedAt: nil)
        supplier = row
        return [row]
    }
    func updateSupplier(id: UUID, payload: SyncAutomaticSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow { throw Fault.unexpectedCall }
    func createCategories(_ payloads: [SyncAutomaticCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow] {
        _ = try verifiedScope()
        guard allowsRelatedSave, payloads.count == 1, let payload = payloads.first,
              payload.ownerUserID == current.ownerUserID, payload.shopID == current.shopID,
              payload.name == "New related category", category == nil || category?.id == payload.id else { throw Fault.unexpectedCall }
        let row = RemoteInventoryCategoryRow(id: payload.id, ownerUserID: payload.ownerUserID, shopID: payload.shopID,
            name: payload.name, updatedAt: "2026-07-21T12:01:00.000000Z", deletedAt: nil)
        category = row
        return [row]
    }
    func updateCategory(id: UUID, payload: SyncAutomaticCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow { throw Fault.unexpectedCall }
    func createProducts(_ payloads: [SyncAutomaticProductCreatePayload]) async throws -> [RemoteInventoryProductRow] { throw Fault.unexpectedCall }
    func updateProduct(id: UUID, payload: SyncAutomaticProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        let scope = try verifiedScope()
        guard !isEmpty, id == current.id else { throw Fault.unexpectedCall }
        attemptCount += 1
        observeProductAttempt?(id, payload, scope, false)
        if allowsRelatedSave {
            isProductHeld = true
            await withCheckedContinuation { productContinuation = $0 }
            isProductHeld = false
            try Task.checkCancellation()
            _ = try verifiedScope()
        }
        current = RemoteInventoryProductRow(id: id, ownerUserID: current.ownerUserID, shopID: current.shopID,
            barcode: payload.barcode ?? current.barcode, itemNumber: payload.itemNumber ?? current.itemNumber,
            productName: payload.productName ?? current.productName, secondProductName: payload.secondProductName ?? current.secondProductName,
            purchasePrice: payload.purchasePrice ?? current.purchasePrice, retailPrice: payload.retailPrice ?? current.retailPrice,
            supplierID: payload.supplierID ?? current.supplierID, categoryID: payload.categoryID ?? current.categoryID,
            stockQuantity: payload.stockQuantity ?? current.stockQuantity, updatedAt: "2026-07-21T12:01:00.000000Z", deletedAt: payload.deletedAt)
        if losesFirstCommittedProductResponse, attemptCount == 1 {
            firstProductResponseWasLost = true
            throw URLError(.networkConnectionLost)
        }
        observeProductAttempt?(id, payload, scope, true)
        return current
    }
    func releaseHeldProduct() {
        productContinuation?.resume()
        productContinuation = nil
    }
    func record(_ request: SyncEventRecordRequest) async throws -> SyncEventRecordResult {
        _ = try verifiedScope()
        try SyncEventRecordValidator().validate(request)
        guard !isEmpty, request.domain == "catalog", request.eventType == "catalog_changed", request.changedCount == 1,
              request.shopID == current.shopID, let device = request.sourceDeviceID,
              device == DeviceInstallIDStore().deviceInstallID else { throw Fault.unexpectedCall }
        if observeProductAttempt != nil, eventRequestObservations.count >= 8 { eventObservationCapped = true }
        if observeProductAttempt != nil, eventRequestObservations.count < 8 {
            eventRequestKeys.append(request.clientEventID)
            eventRequests.append(request)
            eventRequestObservations.append("key.\(LocalPendingChangeLogicalKey.privacyHash(request.clientEventID)).replayed.\(eventClientIDs[request.clientEventID] != nil)")
        }
        if let event = eventClientIDs[request.clientEventID] { return .recorded(event) }
        guard events.count < (allowsRelatedSave ? 3 : 1) else { throw Fault.unexpectedCall }
        eventCount += 1
        let payload: [String: Any] = ["id": String(41 + eventCount), "owner_user_id": current.ownerUserID.uuidString,
            "shop_id": current.shopID!.uuidString, "domain": request.domain, "event_type": request.eventType,
            "source": request.source ?? "ios", "source_device_key": ShopSyncRecoveryCanonical.sha256(device),
            "client_event_key": ShopSyncRecoveryCanonical.sha256(request.clientEventID), "changed_count": request.changedCount,
            "entity_ids": try JSONSerialization.jsonObject(with: JSONEncoder().encode(request.entityIDs)),
            "metadata": try JSONSerialization.jsonObject(with: JSONEncoder().encode(request.metadata)),
            "requires_full_recovery": false, "created_at": "2026-07-21T12:01:00Z"]
        let recorded = try JSONDecoder().decode(RemoteSyncEventRow.self,
            from: JSONSerialization.data(withJSONObject: payload))
        events.append(recorded); eventClientIDs[request.clientEventID] = recorded
        return .recorded(recorded)
    }

    private func verifiedScope() throws -> Task126VerifiedOwnerStoreScope {
        let scope = try Task126OwnerStoreGate.requireCurrentAutomaticScope(ownerUserID: current.ownerUserID)
        guard scope.shopID == current.shopID else { throw Task126OwnerStoreGateError.scopeChanged }
        try authoritativeScope.validate(expectedShopID: scope.shopID,
            expectedDeviceIdentifier: scope.deviceInstallID, expectedOwnerUserID: scope.ownerUserID)
        let watermark = WatermarkStore().watermark(for: .init(ownerUserID: scope.ownerUserID,
            storeIdentity: scope.storeIdentity))
        guard ShopSyncRecoveryFenceStore().scopeKey(accountHash: scope.accountHash,
            storeIdentity: scope.storeIdentity, deviceIdentityHash: scope.deviceIdentityHash,
            watermark: watermark) == authoritativeScope.key else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
        return scope
    }

    func fetchSyncEventsAfter(ownerUserID: UUID, afterID: Int64, limit: Int) async throws -> [RemoteSyncEventRow] {
        _ = try verifiedScope()
        guard ownerUserID == current.ownerUserID, afterID >= 41, limit > 0 else {
            throw ShopSyncRecoveryContractError.invalidCursor
        }
        return Array(events.filter { $0.id > afterID }.prefix(limit))
    }
    func fetchCatalogByIDs(supplierIDs: Set<UUID>, categoryIDs: Set<UUID>, productIDs: Set<UUID>) async throws -> (
        suppliers: [RemoteInventorySupplierRow], categories: [RemoteInventoryCategoryRow], products: [RemoteInventoryProductRow]
    ) {
        _ = try verifiedScope()
        guard (supplierIDs.isEmpty || (allowsRelatedSave && supplierIDs == Set(supplier.map { [$0.id] } ?? []))),
              (categoryIDs.isEmpty || (allowsRelatedSave && categoryIDs == Set(category.map { [$0.id] } ?? []))),
              productIDs.isEmpty || (!isEmpty && productIDs == Set([current.id])) else {
            throw Fault.unexpectedCall
        }
        return (supplierIDs.isEmpty ? [] : supplier.map { [$0] } ?? [],
                categoryIDs.isEmpty ? [] : category.map { [$0] } ?? [], productIDs.isEmpty ? [] : [current])
    }
    func advanceDurableFence(ownerUserID: UUID, scope: Task126VerifiedOwnerStoreScope,
        from watermark: Int64, through newWatermark: Int64) async throws {
        let captured = try verifiedScope()
        guard scope == captured, ownerUserID == current.ownerUserID,
              newWatermark > watermark, newWatermark <= 44,
              events.filter({ $0.id > watermark && $0.id <= newWatermark }).map(\.id)
                == Array((watermark + 1)...newWatermark) else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
        guard ShopSyncRecoveryFenceStore().saveAuthoritative(scope: authoritativeScope,
            watermark: newWatermark, accountHash: scope.accountHash, storeIdentity: scope.storeIdentity,
            deviceIdentityHash: scope.deviceIdentityHash) else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
    }
    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot {
        _ = try verifiedScope()
        return .init(products: isEmpty ? 0 : 1, suppliers: supplier == nil ? 0 : 1,
            categories: category == nil ? 0 : 1, productPrices: 0, historySessions: 0)
    }
    func fetchProductPricesByIDs(ownerUserID: UUID, priceIDs: Set<UUID>) async throws -> [RemoteInventoryProductPriceRow] {
        _ = try verifiedScope()
        guard ownerUserID == current.ownerUserID, priceIDs.isEmpty else { throw Fault.unexpectedCall }
        return []
    }
    func upsertSharedSheetSessions(_ rows: [SharedSheetSessionUpsertRow], ownerUserID: UUID) async throws -> [RemoteSharedSheetSessionRow] {
        throw Fault.unexpectedCall
    }
    func fetchSharedSheetSessionsPage(ownerUserID: UUID, from: Int, to: Int) async throws -> [RemoteSharedSheetSessionRow] {
        _ = try verifiedScope()
        guard ownerUserID == current.ownerUserID else { throw Fault.unexpectedCall }
        return []
    }
    func fetchSharedSheetSessionsByIDs(ownerUserID: UUID, sessionIDs: Set<UUID>) async throws -> [RemoteSharedSheetSessionRow] {
        _ = try verifiedScope()
        guard ownerUserID == current.ownerUserID, sessionIDs.isEmpty else { throw Fault.unexpectedCall }
        return []
    }
}
private nonisolated final class Task144ControlledAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock(); private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}
private nonisolated final class Task144ControlledNetworkBlocker: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet)) }
    override func stopLoading() {}
}
#endif
