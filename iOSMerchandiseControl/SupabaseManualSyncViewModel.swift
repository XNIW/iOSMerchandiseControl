import Combine
import Foundation

// MARK: - Presentation

nonisolated enum SupabaseManualSyncUserPresentationKind: Equatable, Sendable {
    case idleReady
    case running
    case successFullyUpToDate
    case partialSync
    case blockedNeedsSignIn
    case blockedNeedsCloudRealignment
    case connectivityIssue
    case cancelledRun
    case technicalFollowUpNeeded
    case auxiliaryBusyConcurrent
    case auxiliaryModeUnavailable
}

@MainActor
final class SupabaseManualSyncViewModel: ObservableObject {
    private enum Copy {
        static let idleTitle = "Sincronizzazione cloud guidata"
        static let idleSubtitle = "Puoi avviare la sincronizzazione quando sei pronto."
        static let runningTitle = "Sincronizzazione in corso…"
        static let startAction = "Avvia sincronizzazione"
        static let dismissOrRetryAction = "Riprova"
        static let signInAction = "Accedi"
        static let realignAction = "Riallinea dati"
        static let signInSubtitle = "Accedi di nuovo per continuare."
        static let realignSubtitle = "Prima aggiorna i dati dal cloud, poi riprova."
        static let busySubtitle = "Attendi che termini prima di riprovare."
    }

    private let coordinator: any SupabaseManualSyncCoordinating

    @Published private(set) var presentationKind: SupabaseManualSyncUserPresentationKind = .idleReady
    @Published private(set) var title: String = Copy.idleTitle
    @Published private(set) var subtitle: String? = Copy.idleSubtitle
    @Published private(set) var primaryActionTitle: String = Copy.startAction
    @Published private(set) var isRunning = false
    @Published private(set) var cannotStartConcurrently = false
    @Published private(set) var lastSummary: SupabaseManualSyncRunSummary?

    init(coordinator: any SupabaseManualSyncCoordinating) {
        self.coordinator = coordinator
    }

    var canStart: Bool {
        !isRunning
    }

    /// Future guided flow gate (confirmation before mutations). Stubbed false until guided UX exists.
    var pendingConfirmation: Bool { false }

    var shouldShowConfirmation: Bool { false }

    var lastUserMessage: String {
        var parts = [title]
        if let s = subtitle, !s.isEmpty { parts.append(s) }
        return parts.joined(separator: " ")
    }

    var privacySafeAggregatesSnapshot: SupabaseManualSyncPrivacyCounts? {
        lastSummary?.countsSnapshot
    }

    /// Dry-run rehearsal path wired to TASK-065 coordinator until guided manual mode is executable.
    func startDryRunVerification() async {
        await start(with: .dryRun)
    }

    func start(with mode: SupabaseManualSyncRunMode) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        transitionToRunning()

        let summary = await coordinator.run(mode: mode, sessionID: UUID())

        guard !Task.isCancelled else {
            // Coordinator should already surface cancellation; fallback keeps UI truthful.
            if summary.finalState == .cancelled {
                apply(summary: summary)
            } else {
                apply(summary: cancelledFallbackSummary(previous: summary))
            }
            return
        }

        apply(summary: summary)
    }

    private func cancelledFallbackSummary(previous: SupabaseManualSyncRunSummary) -> SupabaseManualSyncRunSummary {
        SupabaseManualSyncRunSummary(
            finalState: .cancelled,
            userFacingHeadline: SupabaseManualSyncUserFacingCopy.cancelled,
            executedPhases: previous.executedPhases,
            skippedPhases: previous.skippedPhases,
            countsSnapshot: previous.countsSnapshot,
            suggestedNextStep: nil,
            detailMessage: nil
        )
    }

    private func transitionToRunning() {
        presentationKind = .running
        title = Copy.runningTitle
        subtitle = nil
        primaryActionTitle = Copy.startAction
    }

    func apply(summary: SupabaseManualSyncRunSummary) {
        cannotStartConcurrently = false
        lastSummary = summary

        switch summary.finalState {
        case .allUpToDate, .completedSuccessfully:
            presentationKind = .successFullyUpToDate
            title = SupabaseManualSyncUserFacingCopy.allUpToDate
            subtitle = summarySummarySubtitle(from: summary)
            primaryActionTitle = Copy.startAction

        case .partialSync:
            presentationKind = .partialSync
            title = SupabaseManualSyncUserFacingCopy.partialSync
            subtitle = nonEmpty(summary.suggestedNextStep) ?? nonEmpty(summary.userFacingHeadline)
            primaryActionTitle = Copy.dismissOrRetryAction

        case .blocked:
            let blockedPresentation = interpretBlocked(summary: summary)
            presentationKind = blockedPresentation.kind
            title = blockedPresentation.title
            subtitle = blockedPresentation.subtitle
            primaryActionTitle = blockedPresentation.primaryActionTitle

        case .connectivityIssue:
            presentationKind = .connectivityIssue
            title = SupabaseManualSyncUserFacingCopy.connectivityRetry
            subtitle = nonEmpty(summary.suggestedNextStep)
            primaryActionTitle = Copy.dismissOrRetryAction

        case .cancelled:
            presentationKind = .cancelledRun
            title = SupabaseManualSyncUserFacingCopy.cancelled
            subtitle = nil
            primaryActionTitle = Copy.startAction

        case .technicalReviewNeeded:
            presentationKind = .technicalFollowUpNeeded
            title = SupabaseManualSyncUserFacingCopy.technicalFollowUp
            subtitle = nonEmpty(summary.suggestedNextStep)
            primaryActionTitle = Copy.dismissOrRetryAction

        case .concurrentRunNotAllowed:
            presentationKind = .auxiliaryBusyConcurrent
            cannotStartConcurrently = true
            title = summary.userFacingHeadline
            subtitle = subtitleCandidate(summary.suggestedNextStep, fallback: Copy.busySubtitle, title: title)
            primaryActionTitle = Copy.dismissOrRetryAction

        case .modeNotSupportedInThisSlice:
            presentationKind = .auxiliaryModeUnavailable
            title = summary.userFacingHeadline
            subtitle = nil
            primaryActionTitle = Copy.startAction
        }
    }

    private func summarySummarySubtitle(from summary: SupabaseManualSyncRunSummary) -> String? {
        if summary.finalState == .completedSuccessfully {
            return nonEmpty(summary.userFacingHeadline) ?? SupabaseManualSyncUserFacingCopy.syncFinishedSuccessfully
        }
        return nil
    }

    private struct BlockedInterpretation {
        let kind: SupabaseManualSyncUserPresentationKind
        let title: String
        let subtitle: String?
        let primaryActionTitle: String
    }

    private func interpretBlocked(summary: SupabaseManualSyncRunSummary) -> BlockedInterpretation {
        if summary.userFacingHeadline == SupabaseManualSyncUserFacingCopy.signInAgain {
            return BlockedInterpretation(
                kind: .blockedNeedsSignIn,
                title: SupabaseManualSyncUserFacingCopy.signInAgain,
                subtitle: subtitleCandidate(
                    summary.suggestedNextStep,
                    fallback: Copy.signInSubtitle,
                    title: SupabaseManualSyncUserFacingCopy.signInAgain
                ),
                primaryActionTitle: Copy.signInAction
            )
        }
        if summary.userFacingHeadline == SupabaseManualSyncUserFacingCopy.realignFromCloud {
            return BlockedInterpretation(
                kind: .blockedNeedsCloudRealignment,
                title: SupabaseManualSyncUserFacingCopy.realignFromCloud,
                subtitle: subtitleCandidate(
                    summary.suggestedNextStep,
                    fallback: Copy.realignSubtitle,
                    title: SupabaseManualSyncUserFacingCopy.realignFromCloud
                ),
                primaryActionTitle: Copy.realignAction
            )
        }
        return BlockedInterpretation(
            kind: .technicalFollowUpNeeded,
            title: SupabaseManualSyncUserFacingCopy.technicalFollowUp,
            subtitle: subtitleCandidate(
                summary.suggestedNextStep,
                fallback: summary.userFacingHeadline,
                title: SupabaseManualSyncUserFacingCopy.technicalFollowUp
            ),
            primaryActionTitle: Copy.dismissOrRetryAction
        )
    }

    private func nonEmpty(_ s: String?) -> String? {
        guard let t = s, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return t
    }

    private func subtitleCandidate(_ candidate: String?, fallback: String?, title: String) -> String? {
        let chosen = nonEmpty(candidate)
        if let chosen, chosen != title {
            return chosen
        }
        return nonEmpty(fallback)
    }

    func resetPresentationToIdleReady() {
        cannotStartConcurrently = false
        lastSummary = nil
        presentationKind = .idleReady
        title = Copy.idleTitle
        subtitle = Copy.idleSubtitle
        primaryActionTitle = Copy.startAction
    }
}
