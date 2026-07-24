import Foundation

protocol SyncAutomaticRuntimeProviding: AnyObject {
    @MainActor
    var isRunning: Bool { get }

    @MainActor
    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> SyncAutomaticRunResult
    @MainActor
    func cancel()

    @MainActor
    func cancelAndWait() async

    @MainActor
    func resumeAfterStoreReplacement() async
}

@MainActor
final class SyncNoopAutomaticRuntime: SyncAutomaticRuntimeProviding {
    var isRunning: Bool { false }

    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> SyncAutomaticRunResult {
        .noWork()
    }

    func cancel() {}

    func cancelAndWait() async {}

    func resumeAfterStoreReplacement() async {}
}

@MainActor
final class AutomaticSyncRuntimeFacade: SyncAutomaticRuntimeProviding {
    private let authViewModel: SupabaseAuthViewModel
    private let engine: AutomaticSyncEngine
    private let deviceAuthorization: (any ShopDeviceAuthorizationChecking)?
    private let retryPolicy: AutomaticSyncRetryPolicy
    private let defaults: UserDefaults
    private let authenticatedOwnerProvider: @MainActor () -> UUID?
    private var facadeIsRunning = false

    init(
        authViewModel: SupabaseAuthViewModel,
        catalogPushProvider: (any SyncCatalogPushProviding)?,
        productPriceProvider: (any SyncProductPriceSyncProviding)?,
        historySessionProvider: (any SyncHistorySessionPushProviding)?,
        incrementalPullProvider: (any SyncIncrementalPullProviding)?,
        recoverySnapshotPullProvider: (any SyncRecoverySnapshotPullProviding)? = nil,
        activityRegistrationProvider: (any SyncActivityRegistrationProviding)?,
        deviceAuthorization: (any ShopDeviceAuthorizationChecking)? = nil,
        defaults: UserDefaults = .standard,
        retryPolicy: AutomaticSyncRetryPolicy = AutomaticSyncRetryPolicy(),
        runAdmissionValidator: (@Sendable () async throws -> Void)? = nil,
        authenticatedOwnerProvider: (@MainActor () -> UUID?)? = nil
    ) {
        self.authViewModel = authViewModel
        self.deviceAuthorization = deviceAuthorization
        self.retryPolicy = retryPolicy
        self.defaults = defaults
        self.authenticatedOwnerProvider = authenticatedOwnerProvider ?? {
            guard authViewModel.isSignedIn else { return nil }
            return authViewModel.sessionInfo?.userID
        }
        self.engine = AutomaticSyncEngine(
            catalogPushProvider: catalogPushProvider,
            productPriceProvider: productPriceProvider,
            historySessionProvider: historySessionProvider,
            incrementalPullProvider: incrementalPullProvider,
            recoverySnapshotPullProvider: recoverySnapshotPullProvider,
            activityRegistrationProvider: activityRegistrationProvider,
            defaults: defaults,
            singleFlight: .processShared,
            cancellationPolicy: .processShared,
            retryPolicy: retryPolicy,
            runAdmissionValidator: runAdmissionValidator
        )
    }

    var isRunning: Bool {
        facadeIsRunning
    }

    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> SyncAutomaticRunResult {
        guard let ownerUserID = authenticatedOwnerProvider() else {
            await engine.recordAuthBlocked()
            _ = retryPolicy.decisionForAuthBlocked()
            return .blocked(.authRequired)
        }
        let pendingRecovery = AccountBindingStore(defaults: defaults).pendingRecoveryJournal
        if let pendingRecovery,
           !action.allowsPendingRecoveryAdmission(mode: pendingRecovery.mode) {
            return .recoveryRequired(didWork: false)
        }
        let scope: Task126VerifiedOwnerStoreScope
        do {
            scope = try Task126OwnerStoreGate.captureAutomaticScope(
                ownerUserID: ownerUserID,
                defaults: defaults,
                allowsPendingReplacement: pendingRecovery?.mode == .accountOrShopReplacement,
                allowsPendingSameScopeRecovery: pendingRecovery?.mode == .sameScopeRecovery
            )
        } catch {
            return .blocked(.accountDecisionRequired)
        }
        if let deviceAuthorization {
            do {
                let snapshot = try await deviceAuthorization.ensureActiveForCloudWrite(
                    reason: "automatic_\(source.rawValue)"
                )
                recordDeviceAuthorization(snapshot, reason: source.rawValue)
            } catch {
                if let blocked = error as? ShopDeviceAuthorizationBlockedError {
                    recordDeviceAuthorization(blocked.snapshot, reason: source.rawValue)
                }
                return .blocked(.deviceNotActive)
            }
        }
        guard authenticatedOwnerProvider() == ownerUserID else {
            return .blocked(.authRequired)
        }
        do {
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        } catch {
            return .blocked(.accountDecisionRequired)
        }
        facadeIsRunning = true
        defer {
            facadeIsRunning = false
        }
        return await Task126OwnerStoreGate.withAutomaticScope(scope) {
            await engine.run(action: action, source: source, ownerUserID: ownerUserID)
        }
    }

    func cancel() {
        Task {
            await engine.cancel()
        }
    }

    func cancelAndWait() async {
        await engine.cancelAndWait()
    }

    func resumeAfterStoreReplacement() async {
        await engine.resumeAfterStoreReplacement()
    }

    private func recordDeviceAuthorization(
        _ snapshot: ShopDeviceAuthorizationSnapshot,
        reason: String
    ) {
        #if DEBUG
        defaults.set(snapshot.status, forKey: "sync.runtime.device.status")
        defaults.set(snapshot.code, forKey: "sync.runtime.device.code")
        defaults.set(snapshot.canWrite, forKey: "sync.runtime.device.canWrite")
        defaults.set(snapshot.reasonCode, forKey: "sync.runtime.device.reasonCode")
        defaults.set(reason, forKey: "sync.runtime.device.lastReason")
        defaults.set(snapshot.checkedAt.timeIntervalSince1970, forKey: "sync.runtime.device.lastCheckedAt")
        if let lastSeenAt = snapshot.lastSeenAt {
            defaults.set(lastSeenAt, forKey: "sync.runtime.device.lastSeenAt")
        }
        if snapshot.status == "active", snapshot.canWrite {
            let blockReasonKey = "sync.runtime.orchestrator.lastRunBlockReason"
            if defaults.string(forKey: blockReasonKey) == "deviceNotActive" {
                defaults.removeObject(forKey: blockReasonKey)
            }
        }
        #endif
    }
}

private extension SyncAction {
    nonisolated var isRecoveryOnlyAdmission: Bool {
        switch self {
        case .bootstrap, .fullRecovery, .requestRecovery:
            return true
        case .sequence(let actions):
            return !actions.isEmpty && actions.allSatisfy(\.isRecoveryOnlyAdmission)
        case .noOp, .pushPending, .drainEvents, .lightReconcile,
             .retryAfterBusy, .blocked:
            return false
        }
    }

    /// A destructive account/shop replacement may only execute recovery work.
    /// A same-scope journal may first drain its own pending writes, but only in
    /// the coordinator's exact push-then-recover sequence. This keeps the
    /// durable latch fail-closed without creating a retry deadlock.
    nonisolated func allowsPendingRecoveryAdmission(
        mode: AccountRecoveryJournalMode
    ) -> Bool {
        switch mode {
        case .accountOrShopReplacement:
            return isRecoveryOnlyAdmission
        case .sameScopeRecovery:
            if isRecoveryOnlyAdmission { return true }
            return self == .sequence([.pushPending, .requestRecovery])
        }
    }
}
