#if DEBUG
import Auth
import Combine
import Foundation
import Supabase
import SwiftData
import SwiftUI
import UIKit

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
    private var task: Task<Void, Never>?
    private var preparationTask: Task<Void, Never>?
    private var hasPreparationStarted = false
    private var hasStarted = false
    private var heldGenerationID: UUID?
    private let provesShopCallbackOrder = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_CALLBACK_ORDER"] == "1"
    private let provesIndependentPending = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_INDEPENDENT_PENDING"] == "1"
    private var independentPendingInserted = false
    private let provesRelatedSave = ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_RELATED_SAVE"] == "1"
    private var lastAutomaticResult = "not-observed"
    private var lastAutomaticPresentationID: String?
    private var lastAutomaticInvocationID: UUID?
    private var lastAutomaticCallbackUptime: TimeInterval?
    private var lastObservationPayload = ""
    private var observationSequence = 0
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
        transport.onHeld = { [weak self] in self?.facts.insert("task144.controlled.held") }
        transport.checkpointBoundary = { [weak self] in await self?.releasePreviousShopCallbackAtCheckpoint() }
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
                    guard await controller.awaitLocalBodyQualification(), try terminalReadback() else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
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
                transport.holdsProducts = true
                heldGenerationID = controller.activeManifest?.generationID
                stateStore.updatePhase(.checking)
                setupStage = .heldRecovery
                let recovery = Task {
                    do {
                        return try await self.recoveryService().recoverFromRemoteSnapshot(ownerUserID: self.owner)
                    } catch {
                        self.recordSetupFailure(error, stage: .heldRecovery)
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
                let summary = try await recovery.value
                guard summary.completedRecoveryJournal, controller.activeManifest != nil else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
                facts.insert("task144.controlled.activated")
                setupStage = .automaticTerminal
                // No direct push or synthetic ACK here. The real root observes
                // the resolved shop/local mutation and runs its normal facade.
                for _ in 0..<300 {
                    refreshAutomaticObservation()
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
        await withCheckedContinuation { callbackHeartbeatContinuation = $0 }
        facts.insert("task144.controlled.previous-shop-callback-released")
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

    func runtime(modelContainer: ModelContainer, stateStore: SyncStateStore) -> any SyncAutomaticRuntimeProviding {
        let lease = controller.captureLease(for: modelContainer)
        let invocationID = UUID()
        let runtime = AutomaticSyncRuntimeFacade(authViewModel: authViewModel,
            catalogPushProvider: CatalogPushService(modelContainer: modelContainer, remote: catalogRemote),
            productPriceProvider: nil, historySessionProvider: nil,
            incrementalPullProvider: SyncEventIncrementalPullService(modelContainer: modelContainer,
                remote: catalogRemote, storeGenerationController: controller),
            recoverySnapshotPullProvider: nil,
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
        publishAutomaticObservation(diagnostic)
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
            && catalogRemote.attemptCount == 1
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
    private func terminalReadback() throws -> Bool {
        let context = ModelContext(controller.modelContainer)
        let products = try context.fetch(FetchDescriptor<Product>())
        let pending = try context.fetch(FetchDescriptor<LocalPendingChange>())
        let outbox = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>())
        let prices = try context.fetchCount(FetchDescriptor<ProductPrice>())
        let history = try context.fetchCount(FetchDescriptor<HistoryEntry>())
        return products.count == 1 && products[0].productName == "Saved before network release"
            && pending.count == 1 && pending.allSatisfy { $0.status == .acknowledged }
            && outbox.filter { $0.status == .sent }.count == 1
            && outbox.allSatisfy { $0.status == .localOnly || $0.status == .sent }
            && prices == 0 && history == 0
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
        _ = try verifiedScope()
        guard !isEmpty, id == current.id else { throw Fault.unexpectedCall }
        attemptCount += 1
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
