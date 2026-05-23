import Foundation
import SwiftData

@MainActor
protocol SyncAutomaticRuntimeProviding: AnyObject {
    var isRunning: Bool { get }

    func run(action: SyncAction, source: SupabaseManualSyncSemiAutomaticTriggerSource) async -> Bool
    func cancel()
}

@MainActor
final class SyncNoopAutomaticRuntime: SyncAutomaticRuntimeProviding {
    var isRunning: Bool { false }

    func run(action: SyncAction, source: SupabaseManualSyncSemiAutomaticTriggerSource) async -> Bool {
        false
    }

    func cancel() {}
}

@MainActor
final class SyncAutomaticRuntime: SyncAutomaticRuntimeProviding {
    private let authViewModel: SupabaseAuthViewModel
    private let catalogPushProvider: (any SupabaseManualSyncCatalogPushProviding)?
    private let productPriceProvider: (any SupabaseManualSyncProductPriceSyncProviding)?
    private let historySessionProvider: (any SupabaseManualSyncHistorySessionSyncProviding)?
    private let incrementalPullProvider: (any SupabaseManualSyncIncrementalPullProviding)?
    private let activityRegistrationProvider: (any SupabaseManualSyncActivityRegistrationProviding)?
    private let defaults: UserDefaults

    private var activeTask: Task<Void, Never>?

    init(
        authViewModel: SupabaseAuthViewModel,
        catalogPushProvider: (any SupabaseManualSyncCatalogPushProviding)?,
        productPriceProvider: (any SupabaseManualSyncProductPriceSyncProviding)?,
        historySessionProvider: (any SupabaseManualSyncHistorySessionSyncProviding)?,
        incrementalPullProvider: (any SupabaseManualSyncIncrementalPullProviding)?,
        activityRegistrationProvider: (any SupabaseManualSyncActivityRegistrationProviding)?,
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

    func run(action: SyncAction, source: SupabaseManualSyncSemiAutomaticTriggerSource) async -> Bool {
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
            let plan = try await catalogPushProvider.makePushPlan(ownerUserID: ownerUserID)
            if plan.isSendable {
                let result = await catalogPushProvider.execute(plan: plan, ownerUserID: ownerUserID)
                let changed = result.supplierCreates + result.supplierUpdates + result.supplierLinks
                    + result.categoryCreates + result.categoryUpdates + result.categoryLinks
                    + result.productCreates + result.productUpdates + result.productLinks
                didWork = didWork || changed > 0
                recordDiagnostic("catalogPush.lastChanged", changed)
            }
        }

        if let productPriceProvider {
            let plan = try await productPriceProvider.makePushPlan(ownerUserID: ownerUserID)
            if plan.isAutomaticPushSafe {
                let result = try await productPriceProvider.push(plan: plan, ownerUserID: ownerUserID)
                didWork = didWork || result.insertedCount > 0
                recordDiagnostic("productPricePush.lastInserted", result.insertedCount)
            }
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
            _ = try await activityRegistrationProvider.registerActivities(ownerUserID: ownerUserID)
        }

        return didWork
    }

    private func drainRemoteEvents(
        ownerUserID: UUID,
        source: SupabaseManualSyncSemiAutomaticTriggerSource
    ) async throws -> Bool {
        guard let incrementalPullProvider else {
            recordDiagnostic("incremental.lastOutcome", "blocked_missing_provider")
            return false
        }
        let summary = try await incrementalPullProvider.applyIncrementalRemoteChanges(ownerUserID: ownerUserID)
        recordIncrementalSummary(summary, source: source)
        return summary.eventsFetched > 0 || summary.totalApplied > 0 || summary.requiresFullRecovery
    }

    private func recordAttempt(source: SupabaseManualSyncSemiAutomaticTriggerSource) {
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
        defaults.set(source.diagnosticsName, forKey: "task115.runtime.incremental.lastSource")
        #endif
    }

    private func recordIncrementalSummary(
        _ summary: SupabaseSyncEventIncrementalApplySummary,
        source: SupabaseManualSyncSemiAutomaticTriggerSource
    ) {
        #if DEBUG
        defaults.set(summary.syncType.rawValue, forKey: "task115.runtime.incremental.lastSyncType")
        defaults.set(summary.eventsFetched, forKey: "task115.runtime.incremental.lastEventsFetched")
        defaults.set(summary.eventsProcessed, forKey: "task115.runtime.incremental.lastEventsProcessed")
        defaults.set(summary.totalApplied, forKey: "task115.runtime.incremental.lastApplied")
        defaults.set(summary.totalElapsedMs, forKey: "task115.runtime.incremental.lastPage.totalElapsedMs")
        defaults.set(summary.totalElapsedMs, forKey: "task115.runtime.incremental.lastTotalElapsedMs")
        defaults.set(summary.requiresFullRecovery, forKey: "task115.runtime.incremental.requiresFullRecovery")
        defaults.set(source.diagnosticsName, forKey: "task115.runtime.incremental.lastCompletedSource")
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
        let catalogPushProvider: (any SupabaseManualSyncCatalogPushProviding)? = manualPushService.map {
            SupabaseManualSyncReleasePushAdapter(
                context: context,
                manualPushService: $0
            )
        }
        let productPriceProvider: (any SupabaseManualSyncProductPriceSyncProviding)? = inventoryService.map {
            SupabaseManualSyncReleaseProductPriceAdapter(
                modelContainer: modelContainer,
                remote: $0
            )
        }
        let historySessionProvider: (any SupabaseManualSyncHistorySessionSyncProviding)? = inventoryService.map {
            SupabaseManualSyncReleaseHistorySessionAdapter(
                modelContainer: modelContainer,
                remote: $0,
                recorder: activityRecorder
            )
        }
        let incrementalPullProvider: (any SupabaseManualSyncIncrementalPullProviding)? = inventoryService.map {
            SyncEventIncrementalPullService(
                modelContainer: modelContainer,
                remote: $0
            )
        }
        let activityRegistrationProvider: (any SupabaseManualSyncActivityRegistrationProviding)? = activityRecorder.map {
            SupabaseManualSyncReleaseActivityRegistrationAdapter(context: context, recorder: $0)
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

private extension ProductPricePushDryRunPlan {
    var isAutomaticPushSafe: Bool {
        isRemoteDedupeSafe
            && summary.readyCandidates > 0
            && summary.blockedTotal == 0
            && summary.conflictSameKeyDifferentPrice == 0
            && summary.localConflictSameKeyDifferentPrice == 0
            && summary.excludedInvalidLocal == 0
            && summary.readyCandidates <= ProductPriceManualPushOptions.defaultBatchLimit
    }
}
