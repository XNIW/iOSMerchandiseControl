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

nonisolated struct SupabaseManualSyncCapabilitySet: Equatable, Sendable {
    var supportsRemoteCloudCheck: Bool
    var supportsGuidedManualSync: Bool

    static let releaseCurrent = SupabaseManualSyncCapabilitySet(
        supportsRemoteCloudCheck: false,
        supportsGuidedManualSync: false
    )

    static func releaseCurrent(
        remotePreviewProvider: (any SupabaseManualSyncRemotePreviewProviding)?
    ) -> SupabaseManualSyncCapabilitySet {
        SupabaseManualSyncCapabilitySet(
            supportsRemoteCloudCheck: remotePreviewProvider != nil,
            supportsGuidedManualSync: false
        )
    }
}

nonisolated struct SupabaseManualSyncAuthPresentationContext: Equatable, Sendable {
    var isSignedIn: Bool
    var canSignIn: Bool
    var isTransitioning: Bool

    static let signedInReady = SupabaseManualSyncAuthPresentationContext(
        isSignedIn: true,
        canSignIn: true,
        isTransitioning: false
    )
}

nonisolated enum SupabaseManualSyncPresentationActionID: Equatable, Sendable {
    case signIn
    case realignData
    case checkCloud
    case reviewChanges
    case syncNow
    case retry
    case cancel
}

nonisolated struct SupabaseManualSyncPresentationAction: Equatable, Sendable {
    var id: SupabaseManualSyncPresentationActionID
    var title: String
    var systemImage: String?
    var isEnabled: Bool
    var accessibilityLabel: String
    var accessibilityHint: String?
}

nonisolated enum SupabaseManualSyncUserFacingSummaryKind: Equatable, Sendable {
    case cloudCheckCompleted
    case cloudCheckCompletedNoAction
    case remoteReviewNeeded
    case noLocalChangesToSend
    case cloudCheckIncomplete
    case networkIssue
    case cloudAccessIssue
    case genericIssue
    case cancelled
}

nonisolated struct SupabaseManualSyncUserFacingSummary: Equatable, Sendable {
    var kind: SupabaseManualSyncUserFacingSummaryKind
    var message: String
}

nonisolated enum SupabaseManualSyncReviewSectionTone: Equatable, Sendable {
    case neutral
    case attention
}

nonisolated enum SupabaseManualSyncReviewSectionID: String, Equatable, Sendable {
    case cloudToDevice
    case deviceToCloud
    case prices
    case attention
}

nonisolated struct SupabaseManualSyncReviewSectionState: Equatable, Identifiable, Sendable {
    var id: SupabaseManualSyncReviewSectionID
    var title: String
    var message: String
    var systemImage: String
    var tone: SupabaseManualSyncReviewSectionTone
}

nonisolated struct SupabaseManualSyncReviewSheetState: Equatable, Sendable {
    var title: String
    var subtitle: String
    var sections: [SupabaseManualSyncReviewSectionState]
    var footerMessage: String
    var primaryActionTitle: String
    var primaryActionSystemImage: String
    var primaryActionIsEnabled: Bool
    var secondaryActionTitle: String
    var accessibilityLabel: String
}

nonisolated struct SupabaseManualSyncPresentationState: Equatable, Sendable {
    var title: String
    var subtitle: String?
    var userFacingSummary: SupabaseManualSyncUserFacingSummary?
    var reviewSheet: SupabaseManualSyncReviewSheetState?
    var statusBadgeText: String
    var statusBadgeSystemImage: String?
    var primaryAction: SupabaseManualSyncPresentationAction?
    var secondaryAction: SupabaseManualSyncPresentationAction?
    var isRunning: Bool
    var isLoading: Bool
    var accessibilityLabel: String
    var accessibilityHint: String?
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
        static let localPendingNeedsReviewTitle = "Ci sono modifiche da controllare"
        static let localPendingNeedsReviewSubtitle = "Nessun invio automatico."
    }

    private let coordinator: any SupabaseManualSyncCoordinating
    private let capabilities: SupabaseManualSyncCapabilitySet
    private var lastStartedMode: SupabaseManualSyncRunMode?

    @Published private(set) var presentationKind: SupabaseManualSyncUserPresentationKind = .idleReady
    @Published private(set) var title: String = Copy.idleTitle
    @Published private(set) var subtitle: String? = Copy.idleSubtitle
    @Published private(set) var primaryActionTitle: String = Copy.startAction
    @Published private(set) var isRunning = false
    @Published private(set) var cannotStartConcurrently = false
    @Published private(set) var lastSummary: SupabaseManualSyncRunSummary?
    @Published private(set) var authPresentationContext: SupabaseManualSyncAuthPresentationContext

    init(
        coordinator: any SupabaseManualSyncCoordinating,
        capabilities: SupabaseManualSyncCapabilitySet = .releaseCurrent,
        initialAuthPresentationContext: SupabaseManualSyncAuthPresentationContext = .signedInReady
    ) {
        self.coordinator = coordinator
        self.capabilities = capabilities
        self.authPresentationContext = initialAuthPresentationContext
    }

    var presentationState: SupabaseManualSyncPresentationState {
        makePresentationState()
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
        lastStartedMode = mode
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
        case .completedSuccessfully where summary.hasIncompleteRemotePreview:
            presentationKind = .technicalFollowUpNeeded
            title = SupabaseManualSyncUserFacingCopy.technicalFollowUp
            subtitle = nonEmpty(summary.suggestedNextStep)
            primaryActionTitle = Copy.dismissOrRetryAction

        case .completedSuccessfully where summary.countsSnapshot.hasAnyPendingWork:
            presentationKind = .partialSync
            title = Copy.localPendingNeedsReviewTitle
            subtitle = Copy.localPendingNeedsReviewSubtitle
            primaryActionTitle = Copy.startAction

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

        case .technicalReviewNeeded where summary.hasCompletedRemotePreviewSignals:
            presentationKind = .partialSync
            title = Copy.localPendingNeedsReviewTitle
            subtitle = Copy.localPendingNeedsReviewSubtitle
            primaryActionTitle = Copy.startAction

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
        lastStartedMode = nil
        presentationKind = .idleReady
        title = Copy.idleTitle
        subtitle = Copy.idleSubtitle
        primaryActionTitle = Copy.startAction
    }

    func applyAuthPresentationContext(_ context: SupabaseManualSyncAuthPresentationContext) {
        guard authPresentationContext != context else { return }
        authPresentationContext = context
    }

    func runMode(for actionID: SupabaseManualSyncPresentationActionID) -> SupabaseManualSyncRunMode? {
        switch actionID {
        case .checkCloud:
            return capabilities.supportsRemoteCloudCheck ? .dryRun : nil
        case .reviewChanges:
            return nil
        case .syncNow:
            return capabilities.supportsGuidedManualSync ? .guidedManual : nil
        case .retry, .realignData:
            return lastStartedMode ?? preferredCapabilityRunMode()
        case .signIn, .cancel:
            return nil
        }
    }

    private func makePresentationState() -> SupabaseManualSyncPresentationState {
        if isRunning {
            return state(
                titleKey: "options.supabase.manualSync.state.running.title",
                subtitleKey: "options.supabase.manualSync.state.running.subtitle",
                badgeKey: "options.supabase.manualSync.badge.running",
                badgeSystemImage: "arrow.triangle.2.circlepath",
                primaryAction: nil,
                secondaryAction: action(.cancel),
                isRunning: true,
                isLoading: true
            )
        }

        if !authPresentationContext.isSignedIn {
            let hintKey: String?
            if authPresentationContext.isTransitioning {
                hintKey = "options.supabase.manualSync.disabled.authChanging"
            } else if !authPresentationContext.canSignIn {
                hintKey = "options.supabase.manualSync.disabled.accessUnavailable"
            } else {
                hintKey = nil
            }

            return state(
                titleKey: "options.supabase.manualSync.state.auth.title",
                subtitleKey: "options.supabase.manualSync.state.auth.subtitle",
                badgeKey: "options.supabase.manualSync.badge.needsAccess",
                badgeSystemImage: "lock.fill",
                primaryAction: action(
                    .signIn,
                    isEnabled: authPresentationContext.canSignIn && !authPresentationContext.isTransitioning,
                    hintKey: hintKey
                ),
                secondaryAction: nil,
                isRunning: false,
                isLoading: authPresentationContext.isTransitioning,
                hintKey: hintKey
            )
        }

        switch presentationKind {
        case .idleReady:
            let actions = capabilityActionsForWork()
            return state(
                titleKey: "options.supabase.manualSync.state.idle.title",
                subtitleKey: "options.supabase.manualSync.state.idle.subtitle",
                badgeKey: "options.supabase.manualSync.badge.manual",
                badgeSystemImage: "hand.tap.fill",
                primaryAction: actions.primary,
                secondaryAction: actions.secondary,
                isRunning: false,
                isLoading: false
            )

        case .running:
            return state(
                titleKey: "options.supabase.manualSync.state.running.title",
                subtitleKey: "options.supabase.manualSync.state.running.subtitle",
                badgeKey: "options.supabase.manualSync.badge.running",
                badgeSystemImage: "arrow.triangle.2.circlepath",
                primaryAction: nil,
                secondaryAction: action(.cancel),
                isRunning: true,
                isLoading: true
            )

        case .successFullyUpToDate:
            let reviewSheet = reviewSheetForCurrentState()
            return state(
                titleKey: "options.supabase.manualSync.state.success.title",
                subtitleKey: "options.supabase.manualSync.state.success.subtitle",
                summary: userFacingSummaryForCurrentState(),
                reviewSheet: reviewSheet,
                badgeKey: "options.supabase.manualSync.badge.noChanges",
                badgeSystemImage: "checkmark.circle.fill",
                primaryAction: reviewSheet == nil
                    ? (capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil)
                    : action(.reviewChanges),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )

        case .partialSync:
            let reviewSheet = reviewSheetForCurrentState()
            let actions = capabilityActionsForWork()
            return state(
                titleKey: "options.supabase.manualSync.state.partial.title",
                subtitleKey: "options.supabase.manualSync.state.partial.subtitle",
                summary: userFacingSummaryForCurrentState(),
                reviewSheet: reviewSheet,
                badgeKey: "options.supabase.manualSync.badge.localChanges",
                badgeSystemImage: "exclamationmark.circle.fill",
                primaryAction: reviewSheet == nil ? actions.primary : action(.reviewChanges),
                secondaryAction: reviewSheet == nil ? actions.secondary : nil,
                isRunning: false,
                isLoading: false
            )

        case .blockedNeedsSignIn:
            return state(
                titleKey: "options.supabase.manualSync.state.auth.title",
                subtitleKey: "options.supabase.manualSync.state.auth.subtitle",
                badgeKey: "options.supabase.manualSync.badge.needsAccess",
                badgeSystemImage: "lock.fill",
                primaryAction: action(.signIn, isEnabled: authPresentationContext.canSignIn),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )

        case .blockedNeedsCloudRealignment:
            let canRetryRealign = runMode(for: .realignData) != nil
            return state(
                titleKey: "options.supabase.manualSync.state.realign.title",
                subtitleKey: "options.supabase.manualSync.state.realign.subtitle",
                badgeKey: "options.supabase.manualSync.badge.needsAction",
                badgeSystemImage: "arrow.down.circle.fill",
                primaryAction: action(.realignData, isEnabled: canRetryRealign),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )

        case .connectivityIssue:
            return retryState(
                titleKey: "options.supabase.manualSync.state.connectivity.title",
                subtitleKey: "options.supabase.manualSync.state.connectivity.subtitle",
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "wifi.exclamationmark"
            )

        case .cancelledRun:
            return retryState(
                titleKey: "options.supabase.manualSync.state.cancelled.title",
                subtitleKey: "options.supabase.manualSync.state.cancelled.subtitle",
                badgeKey: "options.supabase.manualSync.badge.cancelled",
                badgeSystemImage: "xmark.circle.fill"
            )

        case .technicalFollowUpNeeded:
            return retryState(
                titleKey: "options.supabase.manualSync.state.technical.title",
                subtitleKey: "options.supabase.manualSync.state.technical.subtitle",
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "exclamationmark.triangle.fill"
            )

        case .auxiliaryBusyConcurrent:
            return retryState(
                titleKey: "options.supabase.manualSync.state.busy.title",
                subtitleKey: "options.supabase.manualSync.state.busy.subtitle",
                badgeKey: "options.supabase.manualSync.badge.running",
                badgeSystemImage: "hourglass"
            )

        case .auxiliaryModeUnavailable:
            return state(
                titleKey: "options.supabase.manualSync.state.unavailable.title",
                subtitleKey: "options.supabase.manualSync.state.unavailable.subtitle",
                badgeKey: "options.supabase.manualSync.badge.unavailable",
                badgeSystemImage: "slash.circle.fill",
                primaryAction: nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        }
    }

    private func retryState(
        titleKey: String,
        subtitleKey: String,
        badgeKey: String,
        badgeSystemImage: String
    ) -> SupabaseManualSyncPresentationState {
        state(
            titleKey: titleKey,
            subtitleKey: subtitleKey,
            summary: userFacingSummaryForCurrentState(),
            badgeKey: badgeKey,
            badgeSystemImage: badgeSystemImage,
            primaryAction: runMode(for: .retry) == nil ? nil : action(.retry),
            secondaryAction: nil,
            isRunning: false,
            isLoading: false
        )
    }

    private func capabilityActionsForWork() -> (
        primary: SupabaseManualSyncPresentationAction?,
        secondary: SupabaseManualSyncPresentationAction?
    ) {
        if capabilities.supportsGuidedManualSync {
            return (
                primary: action(.syncNow),
                secondary: capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil
            )
        }
        if capabilities.supportsRemoteCloudCheck {
            return (primary: action(.checkCloud), secondary: nil)
        }
        return (primary: nil, secondary: nil)
    }

    private func preferredCapabilityRunMode() -> SupabaseManualSyncRunMode? {
        if capabilities.supportsGuidedManualSync {
            return .guidedManual
        }
        if capabilities.supportsRemoteCloudCheck {
            return .dryRun
        }
        return nil
    }

    private func userFacingSummaryForCurrentState() -> SupabaseManualSyncUserFacingSummary? {
        guard let lastSummary else { return nil }

        switch presentationKind {
        case .successFullyUpToDate, .partialSync, .connectivityIssue, .cancelledRun, .technicalFollowUpNeeded:
            return makeUserFacingSummary(from: lastSummary)
        case .idleReady,
             .running,
             .blockedNeedsSignIn,
             .blockedNeedsCloudRealignment,
             .auxiliaryBusyConcurrent,
             .auxiliaryModeUnavailable:
            return nil
        }
    }

    private func makeUserFacingSummary(from summary: SupabaseManualSyncRunSummary) -> SupabaseManualSyncUserFacingSummary? {
        if let remotePreviewSummary = summary.remotePreviewSummary {
            return makeUserFacingSummary(
                from: remotePreviewSummary,
                counts: summary.countsSnapshot
            )
        }

        switch summary.finalState {
        case .allUpToDate:
            return userFacingSummary(.noLocalChangesToSend, key: "options.supabase.manualSync.summary.local.noPending")
        case .completedSuccessfully where !summary.countsSnapshot.hasAnyPendingWork:
            return userFacingSummary(.noLocalChangesToSend, key: "options.supabase.manualSync.summary.local.noPending")
        case .connectivityIssue:
            return userFacingSummary(.networkIssue, key: "options.supabase.manualSync.summary.network")
        case .technicalReviewNeeded:
            return userFacingSummary(.genericIssue, key: "options.supabase.manualSync.summary.generic")
        case .cancelled:
            return userFacingSummary(.cancelled, key: "options.supabase.manualSync.summary.cancelled")
        case .completedSuccessfully,
             .partialSync,
             .blocked,
             .concurrentRunNotAllowed,
             .modeNotSupportedInThisSlice:
            return nil
        }
    }

    private func makeUserFacingSummary(
        from remotePreviewSummary: SupabaseManualSyncRemotePreviewSummary,
        counts: SupabaseManualSyncPrivacyCounts
    ) -> SupabaseManualSyncUserFacingSummary? {
        if remotePreviewSummary.wasCancelled {
            return userFacingSummary(.cancelled, key: "options.supabase.manualSync.summary.cancelled")
        }

        if let failureCategory = remotePreviewSummary.failureCategory {
            switch failureCategory {
            case .network:
                return userFacingSummary(.networkIssue, key: "options.supabase.manualSync.summary.network")
            case .permission:
                return userFacingSummary(.cloudAccessIssue, key: "options.supabase.manualSync.summary.session")
            case .schemaOrDecode, .localSnapshot, .unknown:
                return userFacingSummary(.genericIssue, key: "options.supabase.manualSync.summary.generic")
            }
        }

        if remotePreviewSummary.isPartial || !remotePreviewSummary.isComplete {
            return userFacingSummary(.cloudCheckIncomplete, key: "options.supabase.manualSync.summary.cloudCheck.incomplete")
        }

        if remotePreviewSummary.hasRemoteSignals {
            return userFacingSummary(.remoteReviewNeeded, key: "options.supabase.manualSync.summary.cloudCheck.differences")
        }

        if counts.hasAnyPendingWork {
            return userFacingSummary(.cloudCheckCompleted, key: "options.supabase.manualSync.summary.cloudCheck.completed.ok")
        }

        return userFacingSummary(.cloudCheckCompletedNoAction, key: "options.supabase.manualSync.summary.cloudCheck.completed.noAction")
    }

    private func userFacingSummary(
        _ kind: SupabaseManualSyncUserFacingSummaryKind,
        key: String
    ) -> SupabaseManualSyncUserFacingSummary {
        SupabaseManualSyncUserFacingSummary(kind: kind, message: L(key))
    }

    private func reviewSheetForCurrentState() -> SupabaseManualSyncReviewSheetState? {
        guard let lastSummary,
              let remotePreviewSummary = lastSummary.remotePreviewSummary,
              let summary = makeUserFacingSummary(from: lastSummary) else {
            return nil
        }

        switch summary.kind {
        case .cloudCheckCompleted, .cloudCheckCompletedNoAction, .remoteReviewNeeded:
            return makeReviewSheetState(from: lastSummary, remotePreviewSummary: remotePreviewSummary)
        case .noLocalChangesToSend,
             .cloudCheckIncomplete,
             .networkIssue,
             .cloudAccessIssue,
             .genericIssue,
             .cancelled:
            return nil
        }
    }

    private func makeReviewSheetState(
        from summary: SupabaseManualSyncRunSummary,
        remotePreviewSummary: SupabaseManualSyncRemotePreviewSummary
    ) -> SupabaseManualSyncReviewSheetState {
        let counts = summary.countsSnapshot
        let aggregateCounts = remotePreviewSummary.safeAggregateCounts
        var sections: [SupabaseManualSyncReviewSectionState] = [
            reviewSection(
                id: .cloudToDevice,
                titleKey: "options.supabase.manualSync.review.cloudToDevice.title",
                messageKey: remotePreviewSummary.hasRemoteSignals
                    ? "options.supabase.manualSync.review.cloudToDevice.needsReview"
                    : "options.supabase.manualSync.review.cloudToDevice.noChanges",
                systemImage: "icloud.and.arrow.down",
                tone: .neutral
            ),
            reviewSection(
                id: .deviceToCloud,
                titleKey: "options.supabase.manualSync.review.deviceToCloud.title",
                messageKey: counts.hasAnyPendingWork
                    ? "options.supabase.manualSync.review.deviceToCloud.localChanges"
                    : "options.supabase.manualSync.review.deviceToCloud.noChanges",
                systemImage: "iphone.and.arrow.forward",
                tone: .neutral
            ),
            reviewSection(
                id: .prices,
                titleKey: "options.supabase.manualSync.review.prices.title",
                messageKey: hasPriceSignals(counts: counts, aggregateCounts: aggregateCounts)
                    ? "options.supabase.manualSync.review.prices.needsDedicatedStep"
                    : "options.supabase.manualSync.review.prices.noAction",
                systemImage: "tag",
                tone: .neutral
            )
        ]

        if hasAttentionSignals(aggregateCounts) {
            sections.append(
                reviewSection(
                    id: .attention,
                    titleKey: "options.supabase.manualSync.review.attention.title",
                    messageKey: "options.supabase.manualSync.review.attention.message",
                    systemImage: "exclamationmark.triangle.fill",
                    tone: .attention
                )
            )
        }

        let title = L("options.supabase.manualSync.review.title")
        let subtitle = L("options.supabase.manualSync.review.subtitle")
        let footerMessage = L("options.supabase.manualSync.review.footer.futureStep")
        let primaryActionTitle = L("options.supabase.manualSync.review.action.applyFuture")
        let secondaryActionTitle = L("options.supabase.manualSync.review.action.cancel")
        let accessibilityLabel = ([title, subtitle] + sections.map(\.title) + [footerMessage])
            .joined(separator: ". ")

        return SupabaseManualSyncReviewSheetState(
            title: title,
            subtitle: subtitle,
            sections: sections,
            footerMessage: footerMessage,
            primaryActionTitle: primaryActionTitle,
            primaryActionSystemImage: "checkmark.circle",
            primaryActionIsEnabled: false,
            secondaryActionTitle: secondaryActionTitle,
            accessibilityLabel: accessibilityLabel
        )
    }

    private func reviewSection(
        id: SupabaseManualSyncReviewSectionID,
        titleKey: String,
        messageKey: String,
        systemImage: String,
        tone: SupabaseManualSyncReviewSectionTone
    ) -> SupabaseManualSyncReviewSectionState {
        SupabaseManualSyncReviewSectionState(
            id: id,
            title: L(titleKey),
            message: L(messageKey),
            systemImage: systemImage,
            tone: tone
        )
    }

    private func hasPriceSignals(
        counts: SupabaseManualSyncPrivacyCounts,
        aggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts
    ) -> Bool {
        counts.pendingPriceChangeCount > 0
            || aggregateCounts.remoteProductPriceCount > 0
            || aggregateCounts.priceHistorySignalCount > 0
    }

    private func hasAttentionSignals(_ counts: SupabaseManualSyncRemotePreviewAggregateCounts) -> Bool {
        counts.conflictCount > 0
            || counts.tombstoneCount > 0
            || counts.warningCount > 0
            || counts.sourceErrorCount > 0
    }

    private func action(
        _ id: SupabaseManualSyncPresentationActionID,
        isEnabled: Bool = true,
        hintKey: String? = nil
    ) -> SupabaseManualSyncPresentationAction {
        let key: String
        let systemImage: String

        switch id {
        case .signIn:
            key = "signIn"
            systemImage = "person.crop.circle.badge.plus"
        case .realignData:
            key = "realign"
            systemImage = "arrow.down.circle.fill"
        case .checkCloud:
            key = "checkCloud"
            systemImage = "icloud"
        case .reviewChanges:
            key = "review"
            systemImage = "doc.text.magnifyingglass"
        case .syncNow:
            key = "syncNow"
            systemImage = "arrow.triangle.2.circlepath.circle.fill"
        case .retry:
            key = "retry"
            systemImage = "arrow.clockwise.circle.fill"
        case .cancel:
            key = "cancel"
            systemImage = "xmark.circle.fill"
        }

        let title = L("options.supabase.manualSync.action.\(key)")
        return SupabaseManualSyncPresentationAction(
            id: id,
            title: title,
            systemImage: systemImage,
            isEnabled: isEnabled,
            accessibilityLabel: title,
            accessibilityHint: hintKey.map { L($0) }
        )
    }

    private func state(
        titleKey: String,
        subtitleKey: String?,
        summary: SupabaseManualSyncUserFacingSummary? = nil,
        reviewSheet: SupabaseManualSyncReviewSheetState? = nil,
        badgeKey: String,
        badgeSystemImage: String?,
        primaryAction: SupabaseManualSyncPresentationAction?,
        secondaryAction: SupabaseManualSyncPresentationAction?,
        isRunning: Bool,
        isLoading: Bool,
        hintKey: String? = nil
    ) -> SupabaseManualSyncPresentationState {
        let title = L(titleKey)
        let subtitle = subtitleKey.map { L($0) }
        let userFacingSummary = nonRedundantSummary(summary, title: title, subtitle: subtitle)
        let badgeText = L(badgeKey)
        let hint = hintKey.map { L($0) }
        let accessibilityLabel = [title, subtitle, userFacingSummary?.message, badgeText]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ". ")

        return SupabaseManualSyncPresentationState(
            title: title,
            subtitle: subtitle,
            userFacingSummary: userFacingSummary,
            reviewSheet: reviewSheet,
            statusBadgeText: badgeText,
            statusBadgeSystemImage: badgeSystemImage,
            primaryAction: primaryAction,
            secondaryAction: secondaryAction,
            isRunning: isRunning,
            isLoading: isLoading,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: hint
        )
    }

    private func nonRedundantSummary(
        _ summary: SupabaseManualSyncUserFacingSummary?,
        title: String,
        subtitle: String?
    ) -> SupabaseManualSyncUserFacingSummary? {
        guard let summary else { return nil }
        let normalizedMessage = normalizedCopy(summary.message)
        guard normalizedMessage != normalizedCopy(title) else { return nil }
        if let subtitle, normalizedMessage == normalizedCopy(subtitle) {
            return nil
        }
        return summary
    }

    private func normalizedCopy(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".…"))
            .lowercased()
    }
}

private extension SupabaseManualSyncRunSummary {
    var hasCompletedRemotePreviewSignals: Bool {
        guard let remotePreviewSummary else { return false }
        return remotePreviewSummary.hasRemoteSignals
            && remotePreviewSummary.isComplete
            && !remotePreviewSummary.isPartial
            && !remotePreviewSummary.wasCancelled
            && remotePreviewSummary.failureCategory == nil
    }

    var hasIncompleteRemotePreview: Bool {
        guard let remotePreviewSummary else { return false }
        return remotePreviewSummary.isPartial || !remotePreviewSummary.isComplete
    }
}
