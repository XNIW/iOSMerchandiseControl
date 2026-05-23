import Foundation
import SwiftData

@MainActor
protocol SyncAutomaticRuntimeProviding: AnyObject {
    var isRunning: Bool { get }

    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> Bool
    func cancel()
}

@MainActor
final class SyncNoopAutomaticRuntime: SyncAutomaticRuntimeProviding {
    var isRunning: Bool { false }

    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> Bool {
        false
    }

    func cancel() {}
}

@MainActor
final class SyncAutomaticRuntime: SyncAutomaticRuntimeProviding {
    private let authViewModel: SupabaseAuthViewModel
    private let catalogPushProvider: (any SyncCatalogPushProviding)?
    private let productPriceProvider: (any SyncProductPriceSyncProviding)?
    private let historySessionProvider: (any SyncHistorySessionPushProviding)?
    private let incrementalPullProvider: (any SyncIncrementalPullProviding)?
    private let activityRegistrationProvider: (any SyncActivityRegistrationProviding)?
    private let defaults: UserDefaults

    private var activeTask: Task<Void, Never>?

    init(
        authViewModel: SupabaseAuthViewModel,
        catalogPushProvider: (any SyncCatalogPushProviding)?,
        productPriceProvider: (any SyncProductPriceSyncProviding)?,
        historySessionProvider: (any SyncHistorySessionPushProviding)?,
        incrementalPullProvider: (any SyncIncrementalPullProviding)?,
        activityRegistrationProvider: (any SyncActivityRegistrationProviding)?,
        defaults: UserDefaults = .standard
    ) {
        self.authViewModel = authViewModel
        self.catalogPushProvider = catalogPushProvider
        self.productPriceProvider = productPriceProvider
        self.historySessionProvider = historySessionProvider
        self.incrementalPullProvider = incrementalPullProvider
        self.activityRegistrationProvider = activityRegistrationProvider
        self.defaults = defaults
    }

    var isRunning: Bool {
        activeTask != nil
    }

    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> Bool {
        guard activeTask == nil else { return false }
        guard authViewModel.isSignedIn,
              let ownerUserID = authViewModel.sessionInfo?.userID else {
            recordDiagnostic("lastOutcome", "blocked_auth")
            return false
        }
        recordAttempt(source: source)
        var didRun = false
        activeTask = Task { }
        defer {
            activeTask = nil
            recordDiagnostic("lastCompletedAt", Date().timeIntervalSince1970)
        }

        do {
            for step in action.flattenedAutomaticSteps {
                try Task.checkCancellation()
                switch step {
                case .pushPending:
                    didRun = try await pushPending(ownerUserID: ownerUserID) || didRun
                case .drainEvents, .lightReconcile, .requestRecovery:
                    didRun = try await drainRemoteEvents(ownerUserID: ownerUserID, source: source) || didRun
                case .bootstrap, .fullRecovery:
                    recordDiagnostic("lastOutcome", "blocked_full_pull_requires_explicit_context")
                case .noOp, .retryAfterBusy, .blocked, .sequence:
                    break
                }
            }
            recordDiagnostic("lastOutcome", didRun ? "completed" : "no_work")
            return true
        } catch is CancellationError {
            recordDiagnostic("lastOutcome", "cancelled")
            return false
        } catch {
            recordDiagnostic("lastOutcome", "failed")
            recordDiagnostic("lastError", safeErrorDescription(error))
            return true
        }
    }

    func cancel() {
        activeTask?.cancel()
        activeTask = nil
    }

    private func pushPending(ownerUserID: UUID) async throws -> Bool {
        var didWork = false

        if let catalogPushProvider {
            let result = try await catalogPushProvider.pushPendingCatalog(ownerUserID: ownerUserID)
            didWork = didWork || result.totalChanged > 0
            recordDiagnostic("catalogPush.lastChanged", result.totalChanged)
        }

        if let productPriceProvider {
            let result = try await productPriceProvider.pushPendingProductPrices(ownerUserID: ownerUserID)
            didWork = didWork || result.insertedCount > 0
            recordDiagnostic("productPricePush.lastInserted", result.insertedCount)
        }

        if let historySessionProvider {
            let summary = try await historySessionProvider.syncHistorySessions(
                ownerUserID: ownerUserID,
                mode: .incremental,
                onProgress: { _ in }
            )
            didWork = didWork || summary.totalChanged > 0
            recordDiagnostic("historyPush.lastChanged", summary.totalChanged)
        }

        if didWork, let activityRegistrationProvider {
            _ = try await activityRegistrationProvider.registerSyncActivities(ownerUserID: ownerUserID)
        }

        return didWork
    }

    private func drainRemoteEvents(
        ownerUserID: UUID,
        source: SyncAutomaticTriggerSource
    ) async throws -> Bool {
        guard let incrementalPullProvider else {
            recordDiagnostic("incremental.lastOutcome", "blocked_missing_provider")
            return false
        }
        let summary = try await incrementalPullProvider.applyIncrementalRemoteChanges(ownerUserID: ownerUserID)
        recordIncrementalSummary(summary, source: source)
        return summary.eventsFetched > 0 || summary.totalApplied > 0 || summary.requiresFullRecovery
    }

    private func recordAttempt(source: SyncAutomaticTriggerSource) {
        #if DEBUG
        let startKey = "task115.runtime.incremental.attemptWindow.startAt"
        let countKey = "task115.runtime.incremental.attemptWindow.count"
        let now = Date().timeIntervalSince1970
        if let start = defaults.object(forKey: startKey) as? Double,
           now - start <= 60 {
            defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
        } else {
            defaults.set(now, forKey: startKey)
            defaults.set(1, forKey: countKey)
        }
        defaults.set(now, forKey: "task115.runtime.incremental.lastAttemptAt")
        defaults.set(source.rawValue, forKey: "task115.runtime.incremental.lastSource")
        #endif
    }

    private func recordIncrementalSummary(
        _ summary: SyncIncrementalPullSummary,
        source: SyncAutomaticTriggerSource
    ) {
        #if DEBUG
        defaults.set(summary.syncType.rawValue, forKey: "task115.runtime.incremental.lastSyncType")
        defaults.set(summary.eventsFetched, forKey: "task115.runtime.incremental.lastEventsFetched")
        defaults.set(summary.eventsProcessed, forKey: "task115.runtime.incremental.lastEventsProcessed")
        defaults.set(summary.totalApplied, forKey: "task115.runtime.incremental.lastApplied")
        defaults.set(summary.totalElapsedMs, forKey: "task115.runtime.incremental.lastPage.totalElapsedMs")
        defaults.set(summary.totalElapsedMs, forKey: "task115.runtime.incremental.lastTotalElapsedMs")
        defaults.set(summary.requiresFullRecovery, forKey: "task115.runtime.incremental.requiresFullRecovery")
        defaults.set(source.rawValue, forKey: "task115.runtime.incremental.lastCompletedSource")
        #endif
    }

    private func recordDiagnostic(_ key: String, _ value: String) {
        #if DEBUG
        defaults.set(value, forKey: "task115.runtime.automatic.\(key)")
        #endif
    }

    private func recordDiagnostic(_ key: String, _ value: Int) {
        #if DEBUG
        defaults.set(value, forKey: "task115.runtime.automatic.\(key)")
        #endif
    }

    private func recordDiagnostic(_ key: String, _ value: TimeInterval) {
        #if DEBUG
        defaults.set(value, forKey: "task115.runtime.automatic.\(key)")
        #endif
    }

    private func safeErrorDescription(_ error: Error) -> String {
        String(describing: error)
            .replacingOccurrences(of: #"[A-Fa-f0-9]{8}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{4}-[A-Fa-f0-9]{12}"#, with: "<UUID>", options: .regularExpression)
    }
}

@MainActor
enum SyncAutomaticRuntimeFactory {
    static func make(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        inventoryService: SupabaseInventoryService?,
        manualPushService: SupabaseManualPushService?,
        activityRecorder: (any SyncEventRecording)?
    ) -> any SyncAutomaticRuntimeProviding {
        let modelContainer = context.container
        let catalogPushProvider: (any SyncCatalogPushProviding)? = manualPushService.map {
            SyncCatalogPushAdapter(
                context: context,
                manualPushService: $0
            )
        }
        let productPriceProvider: (any SyncProductPriceSyncProviding)? = inventoryService.map {
            SyncProductPriceAdapter(
                modelContainer: modelContainer,
                remote: $0
            )
        }
        let historySessionProvider: (any SyncHistorySessionPushProviding)? = inventoryService.map {
            SyncHistorySessionPushAdapter(
                modelContainer: modelContainer,
                remote: $0,
                recorder: activityRecorder
            )
        }
        let incrementalPullProvider: (any SyncIncrementalPullProviding)? = inventoryService.map {
            SyncEventIncrementalPullService(
                modelContainer: modelContainer,
                remote: $0
            )
        }
        let activityRegistrationProvider: (any SyncActivityRegistrationProviding)? = activityRecorder.map {
            SyncActivityRegistrationAdapter(context: context, recorder: $0)
        }
        return SyncAutomaticRuntime(
            authViewModel: authViewModel,
            catalogPushProvider: catalogPushProvider,
            productPriceProvider: productPriceProvider,
            historySessionProvider: historySessionProvider,
            incrementalPullProvider: incrementalPullProvider,
            activityRegistrationProvider: activityRegistrationProvider
        )
    }
}

private extension SyncAction {
    var flattenedAutomaticSteps: [SyncAction] {
        switch self {
        case .sequence(let actions):
            return actions.flatMap(\.flattenedAutomaticSteps)
        default:
            return [self]
        }
    }
}
