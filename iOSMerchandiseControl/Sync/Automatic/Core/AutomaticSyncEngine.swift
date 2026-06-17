import Foundation

actor AutomaticSyncEngine {
    private let catalogPushProvider: (any SyncCatalogPushProviding)?
    private let productPriceProvider: (any SyncProductPriceSyncProviding)?
    private let historySessionProvider: (any SyncHistorySessionPushProviding)?
    private let incrementalPullProvider: (any SyncIncrementalPullProviding)?
    private let recoverySnapshotPullProvider: (any SyncRecoverySnapshotPullProviding)?
    private let activityRegistrationProvider: (any SyncActivityRegistrationProviding)?
    private let defaults: UserDefaults
    private let singleFlight: AutomaticSyncSingleFlight
    private let cancellationPolicy: AutomaticSyncCancellationPolicy
    private let retryPolicy: AutomaticSyncRetryPolicy

    init(
        catalogPushProvider: (any SyncCatalogPushProviding)?,
        productPriceProvider: (any SyncProductPriceSyncProviding)?,
        historySessionProvider: (any SyncHistorySessionPushProviding)?,
        incrementalPullProvider: (any SyncIncrementalPullProviding)?,
        recoverySnapshotPullProvider: (any SyncRecoverySnapshotPullProviding)? = nil,
        activityRegistrationProvider: (any SyncActivityRegistrationProviding)?,
        defaults: UserDefaults = .standard,
        singleFlight: AutomaticSyncSingleFlight = AutomaticSyncSingleFlight(),
        cancellationPolicy: AutomaticSyncCancellationPolicy = AutomaticSyncCancellationPolicy(),
        retryPolicy: AutomaticSyncRetryPolicy = AutomaticSyncRetryPolicy()
    ) {
        self.catalogPushProvider = catalogPushProvider
        self.productPriceProvider = productPriceProvider
        self.historySessionProvider = historySessionProvider
        self.incrementalPullProvider = incrementalPullProvider
        self.recoverySnapshotPullProvider = recoverySnapshotPullProvider
        self.activityRegistrationProvider = activityRegistrationProvider
        self.defaults = defaults
        self.singleFlight = singleFlight
        self.cancellationPolicy = cancellationPolicy
        self.retryPolicy = retryPolicy
    }

    func isRunning() async -> Bool {
        await singleFlight.isRunning
    }

    func recordAuthBlocked() {
        recordDiagnostic("lastOutcome", "blocked_auth")
    }

    func run(
        action: SyncAction,
        source: SyncAutomaticTriggerSource,
        ownerUserID: UUID
    ) async -> SyncAutomaticRunResult {
        guard await singleFlight.begin() else { return .busy() }
        let cancellationToken = await cancellationPolicy.makeToken()
        recordAttempt(source: source)
        var didRun = false

        do {
            for step in action.flattenedAutomaticSteps {
                try await cancellationPolicy.checkCancellation(token: cancellationToken)
                switch step {
                case .blocked(let reason):
                    recordDiagnostic("lastOutcome", "blocked_\(reason)")
                    return await complete(.blocked(reason))
                case .pushPending:
                    didRun = try await pushPending(ownerUserID: ownerUserID, cancellationToken: cancellationToken) || didRun
                case .drainEvents, .lightReconcile:
                    didRun = try await drainRemoteEvents(
                        ownerUserID: ownerUserID,
                        source: source,
                        cancellationToken: cancellationToken
                    ) || didRun
                case .bootstrap, .fullRecovery, .requestRecovery:
                    didRun = try await recoverRemoteSnapshot(
                        ownerUserID: ownerUserID,
                        cancellationToken: cancellationToken
                    ) || didRun
                case .retryAfterBusy:
                    let decision = retryPolicy.decisionForBusy(attempt: 0, isBackground: false)
                    switch decision.action {
                    case .none:
                        recordDiagnostic("lastOutcome", "retry_suppressed_\(decision.reason)")
                        return await complete(.busy())
                    case .retryAfter(let delay):
                        recordDiagnostic("lastOutcome", "scheduled_retry")
                        return await complete(.scheduledRetry(after: delay))
                    }
                case .noOp, .sequence:
                    break
                }
            }
            recordDiagnostic("lastOutcome", didRun ? "completed" : "no_work")
            return await complete(didRun ? .success(didWork: true) : .noWork())
        } catch is CancellationError {
            recordDiagnostic("lastOutcome", "cancelled")
            return await complete(.cancelled())
        } catch {
            let safeError = safeErrorDescription(error)
            recordDiagnostic("lastOutcome", "failed")
            recordDiagnostic("lastError", safeError)
            return await complete(.failed(errorCode: safeError))
        }
    }

    func cancel() async {
        await cancellationPolicy.requestCancellation()
        await singleFlight.cancel()
    }

    private func complete(_ result: SyncAutomaticRunResult) async -> SyncAutomaticRunResult {
        await singleFlight.finish()
        recordDiagnostic("lastCompletedAt", Date().timeIntervalSince1970)
        return result
    }

    private func pushPending(ownerUserID: UUID, cancellationToken: Int) async throws -> Bool {
        var didWork = false

        if let catalogPushProvider {
            let result = try await catalogPushProvider.pushPendingCatalog(ownerUserID: ownerUserID)
            try await cancellationPolicy.checkCancellation(token: cancellationToken)
            didWork = didWork || result.totalChanged > 0
            recordDiagnostic("catalogPush.lastChanged", result.totalChanged)
        }

        if let productPriceProvider {
            let result = try await productPriceProvider.pushPendingProductPrices(ownerUserID: ownerUserID)
            try await cancellationPolicy.checkCancellation(token: cancellationToken)
            didWork = didWork || result.insertedCount > 0
            recordDiagnostic("productPricePush.lastInserted", result.insertedCount)
        }

        if let historySessionProvider {
            let summary = try await historySessionProvider.syncHistorySessions(
                ownerUserID: ownerUserID,
                mode: .incremental
            )
            try await cancellationPolicy.checkCancellation(token: cancellationToken)
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
        source: SyncAutomaticTriggerSource,
        cancellationToken: Int
    ) async throws -> Bool {
        guard let incrementalPullProvider else {
            recordDiagnostic("incremental.lastOutcome", "blocked_missing_provider")
            return false
        }
        let summary = try await incrementalPullProvider.applyIncrementalRemoteChanges(ownerUserID: ownerUserID)
        try await cancellationPolicy.checkCancellation(token: cancellationToken)
        recordIncrementalSummary(summary, source: source)
        if summary.requiresFullRecovery {
            return try await recoverRemoteSnapshot(
                ownerUserID: ownerUserID,
                cancellationToken: cancellationToken
            )
        }
        return summary.eventsFetched > 0 || summary.totalApplied > 0 || summary.requiresFullRecovery
    }

    private func recoverRemoteSnapshot(
        ownerUserID: UUID,
        cancellationToken: Int
    ) async throws -> Bool {
        guard let recoverySnapshotPullProvider else {
            recordDiagnostic("recovery.lastOutcome", "blocked_missing_provider")
            throw AutomaticRecoverySnapshotPullError.providerMissing
        }
        recordDiagnostic("recovery.lastStartedAt", Date().timeIntervalSince1970)
        let summary = try await recoverySnapshotPullProvider.recoverFromRemoteSnapshot(ownerUserID: ownerUserID)
        try await cancellationPolicy.checkCancellation(token: cancellationToken)
        recordRecoverySummary(summary)
        return summary.didWork
    }

    private func recordAttempt(source: SyncAutomaticTriggerSource) {
        #if DEBUG
        let startKey = "sync.runtime.incremental.attemptWindow.startAt"
        let countKey = "sync.runtime.incremental.attemptWindow.count"
        let now = Date().timeIntervalSince1970
        if let start = defaults.object(forKey: startKey) as? Double,
           now - start <= 60 {
            defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
        } else {
            defaults.set(now, forKey: startKey)
            defaults.set(1, forKey: countKey)
        }
        defaults.set(now, forKey: "sync.runtime.incremental.lastAttemptAt")
        defaults.set(source.rawValue, forKey: "sync.runtime.incremental.lastSource")
        #endif
    }

    private func recordIncrementalSummary(
        _ summary: SyncIncrementalPullSummary,
        source: SyncAutomaticTriggerSource
    ) {
        #if DEBUG
        defaults.set(summary.syncType.rawValue, forKey: "sync.runtime.incremental.lastSyncType")
        defaults.set(summary.eventsFetched, forKey: "sync.runtime.incremental.lastEventsFetched")
        defaults.set(summary.eventsProcessed, forKey: "sync.runtime.incremental.lastEventsProcessed")
        defaults.set(summary.totalApplied, forKey: "sync.runtime.incremental.lastApplied")
        defaults.set(summary.totalElapsedMs, forKey: "sync.runtime.incremental.lastPage.totalElapsedMs")
        defaults.set(summary.totalElapsedMs, forKey: "sync.runtime.incremental.lastTotalElapsedMs")
        defaults.set(summary.requiresFullRecovery, forKey: "sync.runtime.incremental.requiresFullRecovery")
        defaults.set(source.rawValue, forKey: "sync.runtime.incremental.lastCompletedSource")
        #endif
    }

    private func recordRecoverySummary(_ summary: SyncRecoverySnapshotPullSummary) {
        #if DEBUG
        defaults.set("completed", forKey: "sync.runtime.automatic.recovery.lastOutcome")
        defaults.set(summary.catalog.inserted, forKey: "sync.runtime.automatic.recovery.catalog.inserted")
        defaults.set(summary.catalog.updated, forKey: "sync.runtime.automatic.recovery.catalog.updated")
        defaults.set(summary.catalog.productPruned, forKey: "sync.runtime.automatic.recovery.catalog.pruned")
        defaults.set(summary.history.insertedCount, forKey: "sync.runtime.automatic.recovery.history.inserted")
        defaults.set(summary.history.updatedCount, forKey: "sync.runtime.automatic.recovery.history.updated")
        defaults.set(summary.history.prunedMissingRemoteCount, forKey: "sync.runtime.automatic.recovery.history.pruned")
        defaults.set(summary.productPrices.inserted, forKey: "sync.runtime.automatic.recovery.productPrices.inserted")
        defaults.set(summary.productPrices.remoteIdentityLinked, forKey: "sync.runtime.automatic.recovery.productPrices.linked")
        defaults.set(summary.productPrices.prunedLocal, forKey: "sync.runtime.automatic.recovery.productPrices.pruned")
        defaults.set(Int(summary.watermarkAfter), forKey: "sync.runtime.automatic.recovery.watermarkAfter")
        defaults.set(Date().timeIntervalSince1970, forKey: "sync.runtime.automatic.recovery.lastCompletedAt")
        #endif
    }

    private func recordDiagnostic(_ key: String, _ value: String) {
        #if DEBUG
        defaults.set(value, forKey: "sync.runtime.automatic.\(key)")
        #endif
    }

    private func recordDiagnostic(_ key: String, _ value: Int) {
        #if DEBUG
        defaults.set(value, forKey: "sync.runtime.automatic.\(key)")
        #endif
    }

    private func recordDiagnostic(_ key: String, _ value: TimeInterval) {
        #if DEBUG
        defaults.set(value, forKey: "sync.runtime.automatic.\(key)")
        #endif
    }

    private func safeErrorDescription(_ error: Error) -> String {
        SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage(String(describing: error))
            ?? "automatic_sync_error"
    }
}

private extension SyncAction {
    nonisolated var flattenedAutomaticSteps: [SyncAction] {
        switch self {
        case .sequence(let actions):
            return actions.flatMap(\.flattenedAutomaticSteps)
        default:
            return [self]
        }
    }
}
