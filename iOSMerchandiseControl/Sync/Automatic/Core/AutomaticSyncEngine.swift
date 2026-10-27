import Foundation

actor AutomaticSyncEngine {
    private let catalogPushProvider: (any SyncCatalogPushProviding)?
    private let productPriceProvider: (any SyncProductPriceSyncProviding)?
    private let historySessionProvider: (any SyncHistorySessionPushProviding)?
    private let incrementalPullProvider: (any SyncIncrementalPullProviding)?
    private let recoverySnapshotPullProvider: (any SyncRecoverySnapshotPullProviding)?
    private let activityRegistrationProvider: (any SyncActivityRegistrationProviding)?
    private let defaults: UserDefaults
    private let bindingStore: AccountBindingStore
    private let watermarkStore: WatermarkStore
    private let singleFlight: AutomaticSyncSingleFlight
    private let cancellationPolicy: AutomaticSyncCancellationPolicy
    private let retryPolicy: AutomaticSyncRetryPolicy
    private let now: @Sendable () -> Date
    private let runAdmissionValidator: (@Sendable () async throws -> Void)?

    init(
        catalogPushProvider: (any SyncCatalogPushProviding)?,
        productPriceProvider: (any SyncProductPriceSyncProviding)?,
        historySessionProvider: (any SyncHistorySessionPushProviding)?,
        incrementalPullProvider: (any SyncIncrementalPullProviding)?,
        recoverySnapshotPullProvider: (any SyncRecoverySnapshotPullProviding)? = nil,
        activityRegistrationProvider: (any SyncActivityRegistrationProviding)?,
        defaults: UserDefaults = .standard,
        bindingStore: AccountBindingStore? = nil,
        watermarkStore: WatermarkStore? = nil,
        singleFlight: AutomaticSyncSingleFlight = AutomaticSyncSingleFlight(),
        cancellationPolicy: AutomaticSyncCancellationPolicy = AutomaticSyncCancellationPolicy(),
        retryPolicy: AutomaticSyncRetryPolicy = AutomaticSyncRetryPolicy(),
        now: @escaping @Sendable () -> Date = { Date() },
        runAdmissionValidator: (@Sendable () async throws -> Void)? = nil
    ) {
        self.catalogPushProvider = catalogPushProvider
        self.productPriceProvider = productPriceProvider
        self.historySessionProvider = historySessionProvider
        self.incrementalPullProvider = incrementalPullProvider
        self.recoverySnapshotPullProvider = recoverySnapshotPullProvider
        self.activityRegistrationProvider = activityRegistrationProvider
        self.defaults = defaults
        self.bindingStore = bindingStore ?? AccountBindingStore(defaults: defaults)
        self.watermarkStore = watermarkStore ?? WatermarkStore(defaults: defaults)
        self.singleFlight = singleFlight
        self.cancellationPolicy = cancellationPolicy
        self.retryPolicy = retryPolicy
        self.now = now
        self.runAdmissionValidator = runAdmissionValidator
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
        let inheritedScope = Task126OwnerStoreGate.currentAutomaticScope
        let inheritedObservationSource = inheritedScope.flatMap {
            SyncAutomaticRunObservationSource.capture(scope: $0, defaults: defaults)
        }
        guard await singleFlight.begin() else { return .busy() }
        let admissionScope = inheritedScope ?? (try? Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: ownerUserID, defaults: defaults,
            allowsPendingReplacement: true, allowsPendingSameScopeRecovery: true
        ))
        let observationSource = inheritedScope == nil ? admissionScope.flatMap {
            SyncAutomaticRunObservationSource.capture(scope: $0, defaults: defaults)
        } : inheritedObservationSource
        let cancellationToken = await cancellationPolicy.makeToken()
        recordAttempt(source: source)
        var didRun = false
        var hasRejectedCatalogChanges = false
        let isAutomaticRecoveryResumePlan = (source == .rootForeground || source == .networkReconnect)
            && action == .sequence([.pushPending, .bootstrap])
        var verifiedConvergence = false
        var verifiedFinalization: SyncStoreRecoveryFinalization?
        var continuationReceipt: SyncIncrementalContinuationReceipt?
        var compatibleDrains = true
        var pendingWorkDeferral: SyncIncrementalLocalWorkDeferral?
        do {
            // Validate only after acquiring the process-wide flight. If an
            // atomic activation happened between runtime construction and
            // admission, no provider or watermark from the stale generation
            // is allowed to run.
            if let admissionScope {
                guard admissionScope.ownerUserID == ownerUserID else {
                    throw Task126OwnerStoreGateError.activeAccountMismatch
                }
                try Task126OwnerStoreGate.revalidateAutomaticScope(admissionScope, defaults: defaults)
            }
            if let observationSource, !observationSource.origin.isCurrent(defaults: defaults, ownerUserID: ownerUserID) {
                throw Task126OwnerStoreGateError.scopeChanged
            }
            try await runAdmissionValidator?()
            if let admissionScope {
                try Task126OwnerStoreGate.revalidateAutomaticScope(admissionScope, defaults: defaults)
            }
            if let observationSource, !observationSource.origin.isCurrent(defaults: defaults, ownerUserID: ownerUserID) {
                throw Task126OwnerStoreGateError.scopeChanged
            }
            let replacementTarget = try replacementRecoveryTarget(ownerUserID: ownerUserID)
            let shouldRecoverReplacement = replacementTarget?.mode == .accountOrShopReplacement
                && action.allowsReplacementRecoveryOverride
            let steps: [SyncAction]
            if isAutomaticRecoveryResumePlan, !bindingStore.hasPendingReplacementJournal {
                // The facade captured fresh same-entity authority after a
                // finalizer retired this journal. Preserve the pending push
                // and current-generation drain; its old bootstrap is obsolete.
                steps = [.pushPending, .drainEvents]
            } else {
                steps = shouldRecoverReplacement ? [.bootstrap] : action.flattenedAutomaticSteps
            }
            if AutomaticSyncAttemptContext.legacyContinuation != nil {
                guard action == .fullRecovery, steps == [.fullRecovery],
                      bindingStore.pendingRecoveryJournal?.mode == .sameScopeRecovery else {
                    throw Task126OwnerStoreGateError.scopeChanged
                }
            }
            let hasRemotePlan = steps.contains { step in
                switch step {
                case .pushPending, .drainEvents, .lightReconcile, .bootstrap, .fullRecovery, .requestRecovery: true
                default: false
                }
            }
            if hasRemotePlan, AutomaticSyncAttemptContext.legacyContinuation == nil,
               AutomaticSyncAttemptContext.reconciliation == nil,
               let begin = AutomaticSyncAttemptContext.begin, !((await begin())) {
                return await complete(.failed(errorCode: "automatic_recovery_attempt_budget_unavailable"),
                    observationSource: observationSource)
            }
            syncPlan: for (stepIndex, step) in steps.enumerated() {
                try await cancellationPolicy.checkCancellation(token: cancellationToken)
                let remaining = Array(steps.dropFirst(stepIndex + 1))
                let mayDeferUntilPushAndFreshDrain = compatibleDrains
                    && (remaining == [.pushPending, .drainEvents] || remaining == [.pushPending, .lightReconcile])
                switch step {
                case .blocked(let reason):
                    recordDiagnostic("lastOutcome", "blocked_\(reason)")
                    return await complete(.blocked(reason), observationSource: observationSource)
                case .pushPending:
                    let resumesDeferredLocalWork = pendingWorkDeferral != nil
                    if let pendingWorkDeferral {
                        try await MainActor.run { try pendingWorkDeferral.validateForPush() }
                        try await cancellationPolicy.checkCancellation(token: cancellationToken)
                        try await runAdmissionValidator?()
                    }
                    let push = try await pushPending(ownerUserID: ownerUserID, cancellationToken: cancellationToken)
                    didRun = push.didWork || didRun
                    hasRejectedCatalogChanges = push.hasRejectedCatalogChanges || hasRejectedCatalogChanges
                    // Discard all pre-push authority. Only a later fresh full
                    // domain pipeline can close the specifically deferred plan.
                    continuationReceipt = nil
                    pendingWorkDeferral = nil
                    if resumesDeferredLocalWork { compatibleDrains = true }
                case .drainEvents:
                    let drain = try await drainRemoteEvents(
                        ownerUserID: ownerUserID,
                        source: source,
                        cancellationToken: cancellationToken,
                        forceLightReconcile: false,
                        allowsExplicitRecovery: false,
                        allowsLocalWorkDeferral: mayDeferUntilPushAndFreshDrain
                    )
                    didRun = drain.didWork || didRun
                    pendingWorkDeferral = drain.localWorkDeferral
                    if let receipt = drain.continuationReceipt,
                       continuationReceipt.map({ receipt.canFollow($0) }) ?? true {
                        continuationReceipt = receipt
                    } else {
                        continuationReceipt = nil
                        compatibleDrains = false
                    }
                    if drain.didRecoverSnapshot {
                        verifiedConvergence = drain.verifiedRecoveryConvergence
                        verifiedFinalization = drain.verifiedFinalization
                        hasRejectedCatalogChanges = false // Published runtime must recompute its own local diagnosis.
                        break syncPlan
                    }
                case .lightReconcile:
                    let drain = try await drainRemoteEvents(
                        ownerUserID: ownerUserID,
                        source: source,
                        cancellationToken: cancellationToken,
                        forceLightReconcile: true,
                        allowsExplicitRecovery: false,
                        allowsLocalWorkDeferral: mayDeferUntilPushAndFreshDrain
                    )
                    didRun = drain.didWork || didRun
                    pendingWorkDeferral = drain.localWorkDeferral
                    if let receipt = drain.continuationReceipt,
                       continuationReceipt.map({ receipt.canFollow($0) }) ?? true {
                        continuationReceipt = receipt
                    } else {
                        continuationReceipt = nil
                        compatibleDrains = false
                    }
                    if drain.didRecoverSnapshot {
                        verifiedConvergence = drain.verifiedRecoveryConvergence
                        verifiedFinalization = drain.verifiedFinalization
                        hasRejectedCatalogChanges = false
                        break syncPlan
                    }
                case .requestRecovery:
                    guard source == .releaseCard else {
                        recordRecoveryRequest(reason: "automatic_recovery_request")
                        throw AutomaticIncrementalRecoveryError.recoveryRequired(didWork: false)
                    }
                    let drain = try await drainRemoteEvents(
                        ownerUserID: ownerUserID,
                        source: source,
                        cancellationToken: cancellationToken,
                        forceLightReconcile: true,
                        allowsExplicitRecovery: true
                    )
                    didRun = drain.didWork || didRun
                    if let receipt = drain.continuationReceipt,
                       continuationReceipt.map({ receipt.canFollow($0) }) ?? true {
                        continuationReceipt = receipt
                    } else {
                        continuationReceipt = nil
                        compatibleDrains = false
                    }
                    if drain.didRecoverSnapshot {
                        verifiedConvergence = drain.verifiedRecoveryConvergence
                        verifiedFinalization = drain.verifiedFinalization
                        hasRejectedCatalogChanges = false
                        break syncPlan
                    }
                case .bootstrap, .fullRecovery:
                    let recovery = try await recoverRemoteSnapshot(
                        ownerUserID: ownerUserID,
                        source: source,
                        cancellationToken: cancellationToken,
                        replacementTarget: replacementTarget,
                        requiresPendingSameScopeRecovery: isAutomaticRecoveryResumePlan && step == .bootstrap
                    )
                    didRun = recovery.didWork || didRun
                    verifiedConvergence = recovery.verifiedConvergence
                    verifiedFinalization = recovery.verifiedFinalization
                    hasRejectedCatalogChanges = false
                    // Atomic recovery may have replaced the active container.
                    // Providers owned by this engine were built for the prior
                    // generation and must never execute after publication.
                    break syncPlan
                case .retryAfterBusy:
                    let decision = retryPolicy.decisionForBusy(attempt: 0, isBackground: false)
                    switch decision.action {
                    case .none:
                        recordDiagnostic("lastOutcome", "retry_suppressed_\(decision.reason)")
                        return await complete(.busy(), observationSource: observationSource)
                    case .retryAfter(let delay):
                        recordDiagnostic("lastOutcome", "scheduled_retry")
                        return await complete(.scheduledRetry(after: delay), observationSource: observationSource)
                    }
                case .noOp, .sequence:
                    break
                }
            }
            if hasRejectedCatalogChanges {
                // Independent push/notification/drain steps have already run.
                // Partial catalog progress is not an all-clear or a new proof.
                let code = "catalog_local_changes_blocked"
                recordDiagnostic("lastOutcome", "failed")
                recordDiagnostic("lastError", code)
                var result = SyncAutomaticRunResult.failed(errorCode: code,
                    failure: AutomaticSyncFailure(disposition: .stable, category: .payload))
                result.didWork = didRun
                return await complete(result, observationSource: observationSource)
            }
            recordDiagnostic(
                "lastOutcome",
                verifiedConvergence ? "verified" : (didRun ? "completed_unverified" : "no_work")
            )
            var result = didRun || verifiedConvergence
                ? SyncAutomaticRunResult.success(didWork: didRun, verifiedConvergence: verifiedConvergence)
                : SyncAutomaticRunResult.noWork()
            if !verifiedConvergence, compatibleDrains, let continuationReceipt {
                result.continuationReceipt = continuationReceipt
            }
            // A committed generation may still have pending local work. Its
            // original receipt identifies the completion without granting a
            // new canonical date (which still requires verifiedConvergence).
            result.verifiedFinalization = verifiedFinalization
            return await complete(result, observationSource: observationSource, cancellationToken: cancellationToken)
        } catch AutomaticIncrementalRecoveryError.recoveryRequired(let recoveryDidWork) {
            recordDiagnostic("lastOutcome", "recovery_required")
            return await complete(.recoveryRequired(didWork: didRun || recoveryDidWork), observationSource: observationSource)
        } catch is CancellationError {
            recordDiagnostic("lastOutcome", "cancelled")
            return await complete(.cancelled(), observationSource: observationSource)
        } catch Task126OwnerStoreGateError.cancelled {
            recordDiagnostic("lastOutcome", "cancelled")
            return await complete(.cancelled(), observationSource: observationSource)
        } catch {
            // A completed journal retires this resume plan. Re-enter the
            // existing bounded scheduler so the next decision uses current
            // pending work and continuation proof; never start a fresh full.
            if isAutomaticRecoveryResumePlan, !bindingStore.hasPendingReplacementJournal,
               error as? Task126OwnerStoreGateError == .scopeChanged
                || error as? AtomicGenerationRecoveryError == .journalTransitionRejected {
                do { try await cancellationPolicy.checkCancellation(token: cancellationToken) }
                catch { return await complete(.cancelled(), observationSource: observationSource) }
                recordDiagnostic("lastOutcome", "stale_recovery_resume_replan")
                return await complete(SyncAutomaticRunResult(status: .scheduledRetry, didWork: didRun,
                    scheduledRetryAfter: 0), observationSource: observationSource)
            }
            let safeError = safeErrorDescription(error)
            recordDiagnostic("lastOutcome", "failed")
            recordDiagnostic("lastError", safeError)
            return await complete(.failed(errorCode: safeError, failure: .classify(error)), observationSource: observationSource)
        }
    }

    func cancel() async {
        await cancellationPolicy.requestCancellation()
        await singleFlight.cancel()
    }

    func cancelAndWait() async {
        await cancellationPolicy.requestCancellation()
        await singleFlight.cancel()
        await singleFlight.suspendForStoreReplacementAndWait()
    }

    func resumeAfterStoreReplacement() async {
        await singleFlight.resumeAfterStoreReplacement()
    }

    private func complete(
        _ result: SyncAutomaticRunResult, observationSource: SyncAutomaticRunObservationSource?,
        cancellationToken: Int? = nil
    ) async -> SyncAutomaticRunResult {
        let completedAt = now()
        await singleFlight.finish()
        var finalResult = result
        if let receipt = result.continuationReceipt {
            if let cancellationToken {
                do {
                    try await cancellationPolicy.checkCancellation(token: cancellationToken)
                    finalResult.continuationReceipt = receipt.guardedForRun(policy: cancellationPolicy, token: cancellationToken)
                } catch {
                    finalResult = .cancelled()
                }
            } else {
                finalResult.continuationReceipt = nil
            }
        }
        recordDiagnostic("lastCompletedAt", completedAt.timeIntervalSince1970)
        if finalResult.observation == nil, let observationSource {
            finalResult = observationSource.completed(finalResult, now: completedAt)
        }
        return finalResult
    }

    private func pushPending(ownerUserID: UUID, cancellationToken: Int) async throws -> (didWork: Bool, hasRejectedCatalogChanges: Bool) {
        var didWork = false
        var hasRejectedCatalogChanges = false

        if let catalogPushProvider {
            let result = try await catalogPushProvider.pushPendingCatalog(ownerUserID: ownerUserID)
            try await cancellationPolicy.checkCancellation(token: cancellationToken)
            didWork = didWork || result.totalChanged > 0
            recordDiagnostic("catalogPush.lastChanged", result.totalChanged)
            hasRejectedCatalogChanges = result.plan?.blockers.contains {
                $0.hasPrefix("invalidCatalogText:") || $0.hasPrefix("unresolvedCatalogReference:")
            } == true
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

        if let activityRegistrationProvider {
            let registration = try await activityRegistrationProvider.registerSyncActivities(
                ownerUserID: ownerUserID
            )
            try await cancellationPolicy.checkCancellation(token: cancellationToken)
            didWork = didWork || registration.summary.registered > 0
            recordDiagnostic("outbox.lastRegistered", registration.summary.registered)
            recordDiagnostic("outbox.lastWaiting", registration.summary.waiting)
            recordDiagnostic("outbox.lastNotRegisterable", registration.summary.notRegisterable)
        }

        return (didWork, hasRejectedCatalogChanges)
    }

    private func drainRemoteEvents(
        ownerUserID: UUID,
        source: SyncAutomaticTriggerSource,
        cancellationToken: Int,
        forceLightReconcile: Bool,
        allowsExplicitRecovery: Bool,
        allowsLocalWorkDeferral: Bool = false
    ) async throws -> (didWork: Bool, didRecoverSnapshot: Bool, continuationReceipt: SyncIncrementalContinuationReceipt?, verifiedRecoveryConvergence: Bool, localWorkDeferral: SyncIncrementalLocalWorkDeferral?, verifiedFinalization: SyncStoreRecoveryFinalization?) {
        guard let incrementalPullProvider else {
            recordDiagnostic("incremental.lastOutcome", "blocked_missing_provider")
            throw ReplacementRecoveryJournalError.incrementalProviderMissing
        }
        let summary: SyncIncrementalPullSummary
        if forceLightReconcile {
            summary = try await incrementalPullProvider.applyIncrementalRemoteChanges(
                ownerUserID: ownerUserID,
                forceLightReconcile: true
            )
        } else {
            #if DEBUG
            let b6Cycle = PilotCommitTrace.b6ReceiverAdmission(
                scope: Task126OwnerStoreGate.currentAutomaticScope, source: source.rawValue)
            summary = try await PilotCommitTrace.B6Context.$cycle.withValue(b6Cycle) {
                try await incrementalPullProvider.applyIncrementalRemoteChanges(ownerUserID: ownerUserID)
            }
            #else
            summary = try await incrementalPullProvider.applyIncrementalRemoteChanges(
                ownerUserID: ownerUserID
            )
            #endif
        }
        try await cancellationPolicy.checkCancellation(token: cancellationToken)
        recordIncrementalSummary(summary, source: source)
        if summary.requiresFullRecovery {
            if allowsLocalWorkDeferral, let deferral = summary.localWorkDeferral,
               deferral.isBound(to: defaults), deferral.matches(summary) {
                try await MainActor.run { try deferral.validateForPush() }
                // No receipt, watermark change, recovery or readiness grant.
                return (false, false, nil, false, deferral, nil)
            }
            let reason = summary.requiresFullRecoveryReason
            recordRecoveryRequest(reason: reason)
            let incrementalDidWork = summary.eventsFetched > 0 || summary.totalApplied > 0
            guard allowsExplicitRecovery else {
                throw AutomaticIncrementalRecoveryError.recoveryRequired(
                    didWork: incrementalDidWork
                )
            }
            let decision = await recoveryDecision(for: reason)
            guard case .runFullRecovery = decision else {
                throw AutomaticIncrementalRecoveryError.policyRejected
            }
            let recoveryDidWork = try await recoverRemoteSnapshot(
                ownerUserID: ownerUserID,
                source: source,
                cancellationToken: cancellationToken,
                replacementTarget: nil
            )
            return (
                recoveryDidWork.didWork || incrementalDidWork,
                true,
                nil,
                recoveryDidWork.verifiedConvergence,
                nil,
                recoveryDidWork.verifiedFinalization
            )
        }
        if allowsExplicitRecovery, !summary.verifiedConvergence {
            let reason = "canonical_verification_required"
            recordRecoveryRequest(reason: reason)
            let decision = await recoveryDecision(for: reason)
            guard case .runFullRecovery = decision else {
                throw AutomaticIncrementalRecoveryError.policyRejected
            }
            let recoveryDidWork = try await recoverRemoteSnapshot(
                ownerUserID: ownerUserID,
                source: source,
                cancellationToken: cancellationToken,
                replacementTarget: nil
            )
            return (
                recoveryDidWork.didWork || summary.eventsFetched > 0 || summary.totalApplied > 0,
                true,
                nil,
                recoveryDidWork.verifiedConvergence,
                nil,
                recoveryDidWork.verifiedFinalization
            )
        }
        if allowsExplicitRecovery {
            recordVerifiedRecoveryDiagnostics(outcome: "verified_not_required")
        }
        let receipt = summary.continuationReceipt.flatMap { $0.matches(summary) ? $0 : nil }
        return (summary.eventsFetched > 0 || summary.totalApplied > 0, false, receipt, false, nil, nil)
    }

    private func recoverRemoteSnapshot(
        ownerUserID: UUID,
        source _: SyncAutomaticTriggerSource,
        cancellationToken: Int,
        replacementTarget: ReplacementRecoveryTarget?,
        requiresPendingSameScopeRecovery: Bool = false
    ) async throws -> (didWork: Bool, verifiedConvergence: Bool, verifiedFinalization: SyncStoreRecoveryFinalization?) {
        guard let recoverySnapshotPullProvider else {
            recordDiagnostic("recovery.lastOutcome", "blocked_missing_provider")
            throw AutomaticRecoverySnapshotPullError.providerMissing
        }
        guard recoverySnapshotPullProvider.publicationMode == .atomicGeneration else {
            recordDiagnostic("recovery.lastOutcome", "blocked_non_atomic_provider")
            throw ReplacementRecoveryJournalError.atomicProviderRequired
        }
        recordDiagnostic("recovery.lastStartedAt", Date().timeIntervalSince1970)
        let recoveryScope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: ownerUserID,
            defaults: defaults,
            allowsPendingReplacement: replacementTarget != nil
                || bindingStore.hasPendingReplacementJournal
        )
        guard !requiresPendingSameScopeRecovery
            || (recoveryScope.pendingReplacement != nil
                && bindingStore.pendingRecoveryJournal?.mode == .sameScopeRecovery) else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
        let recoveryWatermarkScope = WatermarkStore.Scope(
            accountHash: recoveryScope.accountHash,
            storeIdentity: recoveryScope.storeIdentity
        )
        try await cancellationPolicy.checkCancellation(token: cancellationToken)
        try Task126OwnerStoreGate.revalidateAutomaticScope(recoveryScope, defaults: defaults)
        let summary = try await Task126OwnerStoreGate.withAutomaticScope(recoveryScope) {
            try await recoverySnapshotPullProvider.recoverFromRemoteSnapshot(ownerUserID: ownerUserID)
        }

        // Full recovery is allowed to finish only through the generation-scoped
        // atomic service. A legacy provider that mutates the active store and
        // returns only a watermark must never be allowed to clear the durable
        // journal or publish a partially replaced cross-domain database.
        let activeBinding = bindingStore.currentBinding
        let hasAtomicActivationProof = summary.completedRecoveryJournal
            && summary.activatedGenerationID != nil
            && summary.watermarkAfter >= 0
            && !bindingStore.hasPendingReplacementJournal
            && activeBinding?.accountHash == recoveryScope.accountHash
            && activeBinding?.storeIdentity == recoveryScope.storeIdentity
            && watermarkStore.watermark(for: recoveryWatermarkScope) == summary.watermarkAfter
        guard hasAtomicActivationProof else {
            // A provider is expected to propagate cancellation while it is
            // still pre-terminal. Defensively re-check the engine token before
            // classifying a returned but uncommitted summary as a provider
            // failure. Once the complete terminal proof exists, cancellation
            // deliberately loses to the durable commit below.
            try await cancellationPolicy.checkCancellation(token: cancellationToken)
            throw ReplacementRecoveryJournalError.atomicActivationProofUnavailable
        }
        // The provider has crossed the durable terminal boundary: generation,
        // finalization receipt, binding, generation-scoped watermark and
        // journal clear all read back coherently. A cancellation arriving
        // after that commit must not relatch recovery or misreport rollback.
        // Cancellation remains checked before and throughout the provider.
        if let replacementTarget {
            guard recoveryScope.accountHash == replacementTarget.accountHash,
                  recoveryScope.storeIdentity == replacementTarget.storeIdentity else {
                throw ReplacementRecoveryJournalError.completionRejected
            }
        }
        recordRecoverySummary(summary)
        // Preserve the original finalization across awaits. A current binding
        // can reject it, but can never relabel another invocation's proof.
        let finalization = summary.verifiedFinalization.flatMap { proof in
            proof.generationID == summary.activatedGenerationID
                && proof.accountHash == recoveryScope.accountHash
                && proof.shopID == recoveryScope.shopID
                && proof.storeIdentity == recoveryScope.storeIdentity
                && proof.deviceIdentityHash == recoveryScope.deviceIdentityHash
                && proof.watermark == summary.watermarkAfter ? proof : nil
        }
        return (summary.didWork, !summary.hasPendingLocalWork, finalization)
    }

    private func replacementRecoveryTarget(
        ownerUserID: UUID
    ) throws -> ReplacementRecoveryTarget? {
        guard bindingStore.hasPendingReplacementJournal else { return nil }
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: ownerUserID,
            defaults: defaults,
            allowsPendingReplacement: true
        )
        guard let pending = scope.pendingReplacement,
              let storedPending = bindingStore.pendingReplacement,
              storedPending.accountHash == pending.accountHash,
              storedPending.storeIdentity == pending.storeIdentity else {
            throw ReplacementRecoveryJournalError.scopeUnavailable
        }
        return ReplacementRecoveryTarget(
            accountHash: scope.accountHash,
            storeIdentity: scope.storeIdentity,
            mode: bindingStore.pendingRecoveryJournal?.mode ?? .accountOrShopReplacement
        )
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

    private func recordRecoveryRequest(reason: String?) {
        recordDiagnostic("recovery.lastOutcome", "requested")
        recordDiagnostic("recovery.requestedAt", Date().timeIntervalSince1970)
        recordDiagnostic("recovery.requestedReason", reason ?? "unspecified")
    }

    private func recoveryDecision(
        for rawReason: String?
    ) async -> SyncRecoveryPolicy.Decision {
        await MainActor.run {
            let reason: SyncRecoveryPolicy.Reason = rawReason == "canonical_drift_detected"
                ? .canonicalDrift
                : .syncEventGap
            return SyncRecoveryPolicy.decide(
                SyncRecoveryPolicy.Input(
                    trigger: .recoveryRequested,
                    reason: reason,
                    context: .recovery
                )
            )
        }
    }

    private func recordRecoverySummary(_ summary: SyncRecoverySnapshotPullSummary) {
        recordVerifiedRecoveryDiagnostics(outcome: "completed")
        #if DEBUG
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

    private func recordVerifiedRecoveryDiagnostics(outcome: String) {
        #if DEBUG
        defaults.set(outcome, forKey: "sync.runtime.automatic.recovery.lastOutcome")
        defaults.removeObject(forKey: "sync.runtime.automatic.recovery.requestedAt")
        defaults.removeObject(forKey: "sync.runtime.automatic.recovery.requestedReason")
        defaults.removeObject(forKey: "sync.runtime.automatic.lastError")
        defaults.set(false, forKey: "sync.runtime.incremental.requiresFullRecovery")
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

nonisolated private struct ReplacementRecoveryTarget: Equatable, Sendable {
    let accountHash: String
    let storeIdentity: LocalStoreIdentity
    let mode: AccountRecoveryJournalMode
}

private enum ReplacementRecoveryJournalError: Error {
    case scopeUnavailable
    case incrementalProviderMissing
    case atomicProviderRequired
    case atomicActivationProofUnavailable
    case completionRejected
}

private enum AutomaticIncrementalRecoveryError: Error {
    case policyRejected
    case recoveryRequired(didWork: Bool)
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

    nonisolated var allowsReplacementRecoveryOverride: Bool {
        switch self {
        case .blocked, .retryAfterBusy:
            return false
        case .sequence(let actions):
            return actions.allSatisfy(\.allowsReplacementRecoveryOverride)
        case .noOp, .pushPending, .drainEvents, .lightReconcile, .bootstrap,
             .fullRecovery, .requestRecovery:
            return true
        }
    }
}
