import Foundation

// MARK: - Dry-run dependencies

@MainActor
protocol SupabaseManualSyncAuthGateProviding: AnyObject {
    func evaluateAuthGate() async throws -> SupabaseManualSyncAuthGateResult
}

@MainActor
protocol SupabaseManualSyncBaselineGateProviding: AnyObject {
    func evaluateBaselineGate() async throws -> SupabaseManualSyncBaselineGateResult
}

@MainActor
protocol SupabaseManualSyncLocalPendingProviding: AnyObject {
    func loadLocalPendingSnapshot() async throws -> SupabaseManualSyncPrivacyCounts
}

@MainActor
protocol SupabaseManualSyncDryRunPhaseSimulating: AnyObject {
    func simulateRemotePreview(counts: SupabaseManualSyncPrivacyCounts) async throws -> SupabaseManualSyncPhaseOutcome
    func simulateCatalogPushPhase() async throws -> SupabaseManualSyncPhaseOutcome
    func simulateProductPricePushPhase() async throws -> SupabaseManualSyncPhaseOutcome
    func simulateQueuedCloudOperationsFlushPhase() async throws -> SupabaseManualSyncPhaseOutcome
    func simulateFinalRefreshPhase() async throws -> SupabaseManualSyncPhaseOutcome
}

// MARK: - Coordinator

/// Dry-run / mock coordinator: sequences conceptual sync phases without live Supabase or SwiftData.
@MainActor
final class SupabaseManualSyncCoordinator {
    struct Dependencies {
        let authGate: any SupabaseManualSyncAuthGateProviding
        let baselineGate: any SupabaseManualSyncBaselineGateProviding
        let pendingSnapshot: any SupabaseManualSyncLocalPendingProviding
        let phaseSimulation: any SupabaseManualSyncDryRunPhaseSimulating
        let remotePreviewProvider: (any SupabaseManualSyncRemotePreviewProviding)?

        init(
            authGate: any SupabaseManualSyncAuthGateProviding,
            baselineGate: any SupabaseManualSyncBaselineGateProviding,
            pendingSnapshot: any SupabaseManualSyncLocalPendingProviding,
            phaseSimulation: any SupabaseManualSyncDryRunPhaseSimulating,
            remotePreviewProvider: (any SupabaseManualSyncRemotePreviewProviding)? = nil
        ) {
            self.authGate = authGate
            self.baselineGate = baselineGate
            self.pendingSnapshot = pendingSnapshot
            self.phaseSimulation = phaseSimulation
            self.remotePreviewProvider = remotePreviewProvider
        }
    }

    private let dependencies: Dependencies
    private var activeRunSessionID: UUID?

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    /// Runs the conceptual pipeline for `dryRun` only. Other modes return a blocked summary without mutation.
    func run(mode: SupabaseManualSyncRunMode, sessionID: UUID = UUID()) async -> SupabaseManualSyncRunSummary {
        switch mode {
        case .guidedManual, .debugDiagnostics:
            return Self.summarySliceModeUnavailable()
        case .automatic:
            return Self.summaryAutomaticUnavailable()
        case .dryRun:
            break
        }

        guard activeRunSessionID == nil else {
            return Self.summaryConcurrentBusy()
        }

        activeRunSessionID = sessionID
        defer { activeRunSessionID = nil }

        var executed: [SupabaseManualSyncPhase] = []
        var skipped: [SupabaseManualSyncPhase] = []
        var counts = SupabaseManualSyncPrivacyCounts()
        var ledger: [SupabaseManualSyncPhase: SupabaseManualSyncPhaseOutcome] = [:]
        var remotePreviewSummary: SupabaseManualSyncRemotePreviewSummary?

        do {
            try Task.checkCancellation()

            // authCheck
            try await runPhase(.authCheck, executed: &executed, ledger: &ledger) {
                switch try await dependencies.authGate.evaluateAuthGate() {
                case .authenticated:
                    return .completed
                case .sessionExpiredOrSignedOut:
                    return .blocked
                }
            }
            if ledger[.authCheck] == .blocked {
                Self.appendSkippedAfterBlocked(startingAt: .baselineCheck, skipped: &skipped)
                return Self.finalizeBlockedAuth(
                    executed: executed,
                    skipped: skipped,
                    counts: counts,
                    ledger: ledger
                )
            }

            // baselineCheck — single read per run
            try Task.checkCancellation()
            try await runPhase(.baselineCheck, executed: &executed, ledger: &ledger) {
                switch try await dependencies.baselineGate.evaluateBaselineGate() {
                case .valid:
                    return .completed
                case .missingOrInvalid:
                    return .blocked
                }
            }
            if ledger[.baselineCheck] == .blocked {
                Self.appendSkippedAfterBlocked(startingAt: .localPendingCheck, skipped: &skipped)
                return Self.finalizeBlockedBaseline(
                    executed: executed,
                    skipped: skipped,
                    counts: counts,
                    ledger: ledger
                )
            }

            // localPendingCheck
            try Task.checkCancellation()
            try await runPhase(.localPendingCheck, executed: &executed, ledger: &ledger) {
                counts = try await dependencies.pendingSnapshot.loadLocalPendingSnapshot()
                return .completed
            }

            if !counts.hasAnyPendingWork, dependencies.remotePreviewProvider == nil {
                Self.markNoWorkSkips(skipped: &skipped)
                try Task.checkCancellation()
                try await runPhase(.summary, executed: &executed, ledger: &ledger) {
                    .completed
                }
                return Self.finalizeAllUpToDate(
                    executed: executed,
                    skipped: skipped,
                    counts: counts,
                    ledger: ledger
                )
            }

            // remotePreview
            try Task.checkCancellation()
            try await runPhase(.remotePreview, executed: &executed, ledger: &ledger) {
                if let provider = dependencies.remotePreviewProvider {
                    let summary = await provider.loadRemotePreviewSummary()
                    remotePreviewSummary = summary
                    return SupabaseManualSyncRemotePreviewOutcomeMapper.phaseOutcome(for: summary)
                }
                return try await dependencies.phaseSimulation.simulateRemotePreview(counts: counts)
            }
            if let stop = Self.shouldAbortAfterOutcome(ledger[.remotePreview]) {
                Self.appendSkippedAfterAbort(from: .userConfirmation, skipped: &skipped)
                if stop == .cancelled {
                    return Self.finalizeCancelled(
                        executed: executed,
                        skipped: skipped,
                        counts: counts,
                        ledger: ledger,
                        remotePreviewSummary: remotePreviewSummary
                    )
                }
                try Task.checkCancellation()
                try await runPhase(.summary, executed: &executed, ledger: &ledger) { .completed }
                return Self.finalizeEarlyFailure(
                    executed: executed,
                    skipped: skipped,
                    counts: counts,
                    ledger: ledger,
                    abortKind: stop,
                    remotePreviewSummary: remotePreviewSummary
                )
            }

            if let remotePreviewSummary {
                Self.appendSkippedAfterAbort(from: .userConfirmation, skipped: &skipped)
                try Task.checkCancellation()
                try await runPhase(.summary, executed: &executed, ledger: &ledger) { .completed }
                return Self.finalizeRemotePreviewOnly(
                    executed: executed,
                    skipped: skipped,
                    counts: counts,
                    remotePreviewSummary: remotePreviewSummary
                )
            }

            // userConfirmation — dry-run assumes confirmation without UI.
            try Task.checkCancellation()
            try await runPhase(.userConfirmation, executed: &executed, ledger: &ledger) {
                .completed
            }

            // catalogPush
            try Task.checkCancellation()
            if counts.pendingCatalogChangeCount > 0 {
                try await runPhase(.catalogPush, executed: &executed, ledger: &ledger) {
                    try await dependencies.phaseSimulation.simulateCatalogPushPhase()
                }
            } else {
                skipped.append(.catalogPush)
                ledger[.catalogPush] = .skippedNoWork
            }

            // productPricePush
            try Task.checkCancellation()
            if counts.pendingPriceChangeCount > 0 {
                try await runPhase(.productPricePush, executed: &executed, ledger: &ledger) {
                    try await dependencies.phaseSimulation.simulateProductPricePushPhase()
                }
            } else {
                skipped.append(.productPricePush)
                ledger[.productPricePush] = .skippedNoWork
            }

            // pendingEventsFlush (conceptual flush — simulated only)
            try Task.checkCancellation()
            if counts.pendingQueuedCloudOperationCount > 0 {
                try await runPhase(.pendingEventsFlush, executed: &executed, ledger: &ledger) {
                    try await dependencies.phaseSimulation.simulateQueuedCloudOperationsFlushPhase()
                }
            } else {
                skipped.append(.pendingEventsFlush)
                ledger[.pendingEventsFlush] = .skippedNoWork
            }

            // finalRefresh
            try Task.checkCancellation()
            try await runPhase(.finalRefresh, executed: &executed, ledger: &ledger) {
                try await dependencies.phaseSimulation.simulateFinalRefreshPhase()
            }

            try Task.checkCancellation()
            try await runPhase(.summary, executed: &executed, ledger: &ledger) {
                .completed
            }

            return Self.finalizeSuccessfulRun(
                executed: executed,
                skipped: skipped,
                counts: counts,
                ledger: ledger
            )
        } catch is CancellationError {
            if !executed.contains(.summary) {
                skipped.append(.summary)
            }
            return Self.finalizeCancelled(
                executed: executed,
                skipped: skipped,
                counts: counts,
                ledger: ledger
            )
        } catch {
            if !executed.contains(.summary) {
                executed.append(.summary)
                ledger[.summary] = .completed
            }
            return SupabaseManualSyncRunSummary(
                finalState: .technicalReviewNeeded,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.unexpected,
                executedPhases: executed,
                skippedPhases: skipped,
                countsSnapshot: counts,
                suggestedNextStep: nil,
                detailMessage: nil
            )
        }
    }

    private func runPhase(
        _ phase: SupabaseManualSyncPhase,
        executed: inout [SupabaseManualSyncPhase],
        ledger: inout [SupabaseManualSyncPhase: SupabaseManualSyncPhaseOutcome],
        _ work: () async throws -> SupabaseManualSyncPhaseOutcome
    ) async throws {
        try Task.checkCancellation()
        let outcome = try await work()
        executed.append(phase)
        ledger[phase] = outcome
    }

    private enum AbortKind {
        case connectivity
        case technical
        case cancelled
    }

    private static func shouldAbortAfterOutcome(_ outcome: SupabaseManualSyncPhaseOutcome?) -> AbortKind? {
        switch outcome {
        case .some(.failedRetryable):
            return .connectivity
        case .some(.failedNonRetryable), .some(.blocked):
            return .technical
        case .some(.cancelled):
            return .cancelled
        default:
            return nil
        }
    }

    private static func appendSkippedAfterBlocked(startingAt first: SupabaseManualSyncPhase, skipped: inout [SupabaseManualSyncPhase]) {
        guard let idx = SupabaseManualSyncPhase.allCases.firstIndex(of: first) else { return }
        for p in SupabaseManualSyncPhase.allCases[idx...] where p != .summary {
            skipped.append(p)
        }
    }

    private static func appendSkippedAfterAbort(from first: SupabaseManualSyncPhase, skipped: inout [SupabaseManualSyncPhase]) {
        guard let idx = SupabaseManualSyncPhase.allCases.firstIndex(of: first) else { return }
        for p in SupabaseManualSyncPhase.allCases[idx...] where p != .summary {
            if !skipped.contains(p) {
                skipped.append(p)
            }
        }
    }

    private static func markNoWorkSkips(skipped: inout [SupabaseManualSyncPhase]) {
        skipped.append(contentsOf: [
            .remotePreview,
            .userConfirmation,
            .catalogPush,
            .productPricePush,
            .pendingEventsFlush,
            .finalRefresh,
        ])
    }

    // MARK: Final summaries

    private static func finalizeBlockedAuth(
        executed: [SupabaseManualSyncPhase],
        skipped: [SupabaseManualSyncPhase],
        counts: SupabaseManualSyncPrivacyCounts,
        ledger: [SupabaseManualSyncPhase: SupabaseManualSyncPhaseOutcome]
    ) -> SupabaseManualSyncRunSummary {
        var ex = executed
        if !ex.contains(.summary) {
            ex.append(.summary)
        }
        _ = ledger
        return SupabaseManualSyncRunSummary(
            finalState: .blocked,
            userFacingHeadline: SupabaseManualSyncUserFacingCopy.signInAgain,
            executedPhases: ex,
            skippedPhases: skipped,
            countsSnapshot: counts,
            suggestedNextStep: SupabaseManualSyncUserFacingCopy.signInAgain,
            detailMessage: nil
        )
    }

    private static func finalizeBlockedBaseline(
        executed: [SupabaseManualSyncPhase],
        skipped: [SupabaseManualSyncPhase],
        counts: SupabaseManualSyncPrivacyCounts,
        ledger: [SupabaseManualSyncPhase: SupabaseManualSyncPhaseOutcome]
    ) -> SupabaseManualSyncRunSummary {
        var ex = executed
        if !ex.contains(.summary) {
            ex.append(.summary)
        }
        _ = ledger
        return SupabaseManualSyncRunSummary(
            finalState: .blocked,
            userFacingHeadline: SupabaseManualSyncUserFacingCopy.realignFromCloud,
            executedPhases: ex,
            skippedPhases: skipped,
            countsSnapshot: counts,
            suggestedNextStep: SupabaseManualSyncUserFacingCopy.realignFromCloud,
            detailMessage: nil
        )
    }

    private static func finalizeAllUpToDate(
        executed: [SupabaseManualSyncPhase],
        skipped: [SupabaseManualSyncPhase],
        counts: SupabaseManualSyncPrivacyCounts,
        ledger: [SupabaseManualSyncPhase: SupabaseManualSyncPhaseOutcome]
    ) -> SupabaseManualSyncRunSummary {
        var ex = executed
        if !ex.contains(.summary) {
            ex.append(.summary)
        }
        _ = ledger
        return SupabaseManualSyncRunSummary(
            finalState: .allUpToDate,
            userFacingHeadline: SupabaseManualSyncUserFacingCopy.allUpToDate,
            executedPhases: ex,
            skippedPhases: skipped,
            countsSnapshot: counts,
            suggestedNextStep: nil,
            detailMessage: nil
        )
    }

    private static func finalizeEarlyFailure(
        executed: [SupabaseManualSyncPhase],
        skipped: [SupabaseManualSyncPhase],
        counts: SupabaseManualSyncPrivacyCounts,
        ledger: [SupabaseManualSyncPhase: SupabaseManualSyncPhaseOutcome],
        abortKind: AbortKind,
        remotePreviewSummary: SupabaseManualSyncRemotePreviewSummary? = nil
    ) -> SupabaseManualSyncRunSummary {
        switch abortKind {
        case .connectivity:
            return SupabaseManualSyncRunSummary(
                finalState: .connectivityIssue,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.connectivityRetry,
                executedPhases: executed,
                skippedPhases: skipped,
                countsSnapshot: counts,
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.retryConnectivitySuggestion,
                detailMessage: nil,
                remotePreviewSummary: remotePreviewSummary
            )
        case .technical:
            if let remotePreviewSummary {
                return finalizeRemotePreviewOnly(
                    executed: executed,
                    skipped: skipped,
                    counts: counts,
                    remotePreviewSummary: remotePreviewSummary
                )
            }
            return SupabaseManualSyncRunSummary(
                finalState: .technicalReviewNeeded,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.technicalFollowUp,
                executedPhases: executed,
                skippedPhases: skipped,
                countsSnapshot: counts,
                suggestedNextStep: nil,
                detailMessage: nil,
                remotePreviewSummary: remotePreviewSummary
            )
        case .cancelled:
            return finalizeCancelled(
                executed: executed,
                skipped: skipped,
                counts: counts,
                ledger: ledger,
                remotePreviewSummary: remotePreviewSummary
            )
        }
    }

    private static func finalizeRemotePreviewOnly(
        executed: [SupabaseManualSyncPhase],
        skipped: [SupabaseManualSyncPhase],
        counts: SupabaseManualSyncPrivacyCounts,
        remotePreviewSummary: SupabaseManualSyncRemotePreviewSummary
    ) -> SupabaseManualSyncRunSummary {
        let finalState = SupabaseManualSyncRemotePreviewOutcomeMapper.finalUserState(for: remotePreviewSummary)
        let headline: String
        switch remotePreviewSummary.recommendedUserMessageKey {
        case .cloudCheckCompleteNoAction:
            headline = SupabaseManualSyncUserFacingCopy.cloudCheckNoAction
        case .cloudCheckFailedRetry:
            headline = SupabaseManualSyncUserFacingCopy.connectivityRetry
        case .cloudCheckCancelled:
            headline = SupabaseManualSyncUserFacingCopy.cancelled
        case .cloudCheckFailedPermission:
            headline = remotePreviewSummary.failureCategory == .auth
                ? SupabaseManualSyncUserFacingCopy.signInAgain
                : SupabaseManualSyncUserFacingCopy.technicalFollowUp
        case .cloudDataNeedsReview, .cloudCheckIncomplete, .cloudCheckFailedTechnical:
            headline = SupabaseManualSyncUserFacingCopy.technicalFollowUp
        }

        return SupabaseManualSyncRunSummary(
            finalState: finalState,
            userFacingHeadline: headline,
            executedPhases: executed,
            skippedPhases: skipped,
            countsSnapshot: counts,
            suggestedNextStep: nil,
            detailMessage: nil,
            remotePreviewSummary: remotePreviewSummary
        )
    }

    private static func finalizeSuccessfulRun(
        executed: [SupabaseManualSyncPhase],
        skipped: [SupabaseManualSyncPhase],
        counts: SupabaseManualSyncPrivacyCounts,
        ledger: [SupabaseManualSyncPhase: SupabaseManualSyncPhaseOutcome]
    ) -> SupabaseManualSyncRunSummary {
        let mutationPhases: [SupabaseManualSyncPhase] = [.catalogPush, .productPricePush, .pendingEventsFlush]
        let mutationOutcomes = mutationPhases.filter { executed.contains($0) }.compactMap { ledger[$0] }

        let hadCompletedMutation = mutationOutcomes.contains(.completed)
        let hadPartialMutation = mutationOutcomes.contains(.partial)
        let hadRetryableFailure = mutationOutcomes.contains(.failedRetryable)
        let hadHardFailure = mutationOutcomes.contains(.failedNonRetryable) || mutationOutcomes.contains(.blocked)

        let refreshOutcome = ledger[.finalRefresh] ?? .skippedNoWork

        if hadHardFailure {
            return SupabaseManualSyncRunSummary(
                finalState: .technicalReviewNeeded,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.technicalFollowUp,
                executedPhases: executed,
                skippedPhases: skipped,
                countsSnapshot: counts,
                suggestedNextStep: nil,
                detailMessage: nil
            )
        }

        if refreshOutcome == .failedRetryable {
            if hadCompletedMutation || hadPartialMutation {
                return SupabaseManualSyncRunSummary(
                    finalState: .partialSync,
                    userFacingHeadline: SupabaseManualSyncUserFacingCopy.partialSync,
                    executedPhases: executed,
                    skippedPhases: skipped,
                    countsSnapshot: counts,
                    suggestedNextStep: SupabaseManualSyncUserFacingCopy.partialSuggestion,
                    detailMessage: nil
                )
            }
            return SupabaseManualSyncRunSummary(
                finalState: .connectivityIssue,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.connectivityRetry,
                executedPhases: executed,
                skippedPhases: skipped,
                countsSnapshot: counts,
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.retryConnectivitySuggestion,
                detailMessage: nil
            )
        }

        if hadRetryableFailure {
            if hadCompletedMutation || hadPartialMutation {
                return SupabaseManualSyncRunSummary(
                    finalState: .partialSync,
                    userFacingHeadline: SupabaseManualSyncUserFacingCopy.partialSync,
                    executedPhases: executed,
                    skippedPhases: skipped,
                    countsSnapshot: counts,
                    suggestedNextStep: SupabaseManualSyncUserFacingCopy.partialSuggestion,
                    detailMessage: nil
                )
            }
            return SupabaseManualSyncRunSummary(
                finalState: .connectivityIssue,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.connectivityRetry,
                executedPhases: executed,
                skippedPhases: skipped,
                countsSnapshot: counts,
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.retryConnectivitySuggestion,
                detailMessage: nil
            )
        }

        if hadPartialMutation || refreshOutcome == .partial {
            return SupabaseManualSyncRunSummary(
                finalState: .partialSync,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.partialSync,
                executedPhases: executed,
                skippedPhases: skipped,
                countsSnapshot: counts,
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.partialSuggestion,
                detailMessage: nil
            )
        }

        return SupabaseManualSyncRunSummary(
            finalState: .completedSuccessfully,
            userFacingHeadline: SupabaseManualSyncUserFacingCopy.syncFinishedSuccessfully,
            executedPhases: executed,
            skippedPhases: skipped,
            countsSnapshot: counts,
            suggestedNextStep: nil,
            detailMessage: nil
        )
    }

    private static func finalizeCancelled(
        executed: [SupabaseManualSyncPhase],
        skipped: [SupabaseManualSyncPhase],
        counts: SupabaseManualSyncPrivacyCounts,
        ledger: [SupabaseManualSyncPhase: SupabaseManualSyncPhaseOutcome],
        remotePreviewSummary: SupabaseManualSyncRemotePreviewSummary? = nil
    ) -> SupabaseManualSyncRunSummary {
        _ = ledger
        var sk = skipped
        for p in SupabaseManualSyncPhase.allCases where p != .summary && !executed.contains(p) && !sk.contains(p) {
            sk.append(p)
        }
        if !executed.contains(.summary), !sk.contains(.summary) {
            sk.append(.summary)
        }
        return SupabaseManualSyncRunSummary(
            finalState: .cancelled,
            userFacingHeadline: SupabaseManualSyncUserFacingCopy.cancelled,
            executedPhases: executed,
            skippedPhases: sk,
            countsSnapshot: counts,
            suggestedNextStep: nil,
            detailMessage: nil,
            remotePreviewSummary: remotePreviewSummary
        )
    }

    private static func summaryConcurrentBusy() -> SupabaseManualSyncRunSummary {
        SupabaseManualSyncRunSummary(
            finalState: .concurrentRunNotAllowed,
            userFacingHeadline: SupabaseManualSyncUserFacingCopy.alreadyRunning,
            executedPhases: [],
            skippedPhases: Array(SupabaseManualSyncPhase.allCases),
            countsSnapshot: SupabaseManualSyncPrivacyCounts(),
            suggestedNextStep: SupabaseManualSyncUserFacingCopy.alreadyRunning,
            detailMessage: nil
        )
    }

    private static func summarySliceModeUnavailable() -> SupabaseManualSyncRunSummary {
        SupabaseManualSyncRunSummary(
            finalState: .modeNotSupportedInThisSlice,
            userFacingHeadline: SupabaseManualSyncUserFacingCopy.sliceModeUnavailable,
            executedPhases: [],
            skippedPhases: Array(SupabaseManualSyncPhase.allCases),
            countsSnapshot: SupabaseManualSyncPrivacyCounts(),
            suggestedNextStep: nil,
            detailMessage: nil
        )
    }

    private static func summaryAutomaticUnavailable() -> SupabaseManualSyncRunSummary {
        SupabaseManualSyncRunSummary(
            finalState: .modeNotSupportedInThisSlice,
            userFacingHeadline: SupabaseManualSyncUserFacingCopy.automaticUnavailable,
            executedPhases: [],
            skippedPhases: Array(SupabaseManualSyncPhase.allCases),
            countsSnapshot: SupabaseManualSyncPrivacyCounts(),
            suggestedNextStep: nil,
            detailMessage: nil
        )
    }
}
