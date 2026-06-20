import Foundation

protocol SyncAutomaticRuntimeProviding: AnyObject {
    @MainActor
    var isRunning: Bool { get }

    @MainActor
    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> SyncAutomaticRunResult
    @MainActor
    func cancel()
}

@MainActor
final class SyncNoopAutomaticRuntime: SyncAutomaticRuntimeProviding {
    var isRunning: Bool { false }

    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> SyncAutomaticRunResult {
        .noWork()
    }

    func cancel() {}
}

@MainActor
final class AutomaticSyncRuntimeFacade: SyncAutomaticRuntimeProviding {
    private let authViewModel: SupabaseAuthViewModel
    private let engine: AutomaticSyncEngine
    private let deviceAuthorization: (any ShopDeviceAuthorizationChecking)?
    private let retryPolicy: AutomaticSyncRetryPolicy
    private let defaults: UserDefaults
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
        retryPolicy: AutomaticSyncRetryPolicy = AutomaticSyncRetryPolicy()
    ) {
        self.authViewModel = authViewModel
        self.deviceAuthorization = deviceAuthorization
        self.retryPolicy = retryPolicy
        self.defaults = defaults
        self.engine = AutomaticSyncEngine(
            catalogPushProvider: catalogPushProvider,
            productPriceProvider: productPriceProvider,
            historySessionProvider: historySessionProvider,
            incrementalPullProvider: incrementalPullProvider,
            recoverySnapshotPullProvider: recoverySnapshotPullProvider,
            activityRegistrationProvider: activityRegistrationProvider,
            defaults: defaults,
            retryPolicy: retryPolicy
        )
    }

    var isRunning: Bool {
        facadeIsRunning
    }

    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> SyncAutomaticRunResult {
        guard authViewModel.isSignedIn,
              let ownerUserID = authViewModel.sessionInfo?.userID else {
            await engine.recordAuthBlocked()
            _ = retryPolicy.decisionForAuthBlocked()
            return .blocked(.authRequired)
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
        facadeIsRunning = true
        defer {
            facadeIsRunning = false
        }
        return await engine.run(action: action, source: source, ownerUserID: ownerUserID)
    }

    func cancel() {
        Task {
            await engine.cancel()
        }
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
