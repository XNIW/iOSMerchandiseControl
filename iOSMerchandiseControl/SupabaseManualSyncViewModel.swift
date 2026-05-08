import Combine
import Foundation
import SwiftData

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
    case localApplyCompleted
    case localApplyFailed
    case catalogPushReady
    case catalogPushNoChanges
    case catalogPushBlocked
    case catalogPushFailed
    case catalogPushStale
    case catalogPushSending
    case catalogPushSucceeded
    case catalogPushPartiallySucceeded
}

nonisolated struct SupabaseManualSyncCapabilitySet: Equatable, Sendable {
    var supportsRemoteCloudCheck: Bool
    var supportsGuidedManualSync: Bool
    var supportsCatalogPush: Bool

    init(
        supportsRemoteCloudCheck: Bool,
        supportsGuidedManualSync: Bool,
        supportsCatalogPush: Bool = false
    ) {
        self.supportsRemoteCloudCheck = supportsRemoteCloudCheck
        self.supportsGuidedManualSync = supportsGuidedManualSync
        self.supportsCatalogPush = supportsCatalogPush
    }

    static let releaseCurrent = SupabaseManualSyncCapabilitySet(
        supportsRemoteCloudCheck: false,
        supportsGuidedManualSync: false,
        supportsCatalogPush: false
    )

    static func releaseCurrent(
        remotePreviewProvider: (any SupabaseManualSyncRemotePreviewProviding)?,
        catalogPushProvider: (any SupabaseManualSyncCatalogPushProviding)? = nil
    ) -> SupabaseManualSyncCapabilitySet {
        SupabaseManualSyncCapabilitySet(
            supportsRemoteCloudCheck: remotePreviewProvider != nil,
            supportsGuidedManualSync: false,
            supportsCatalogPush: catalogPushProvider != nil
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
    case sendCloudChanges
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
    case localApplyCompleted
    case localApplyFailed
    case catalogPushNoChanges
    case catalogPushSucceeded
    case catalogPushSucceededNeedsCheck
    case catalogPushPartial
    case catalogPushBlocked
    case catalogPushFailedBeforeWrite
    case catalogPushInterrupted
    case catalogPushStale
}

nonisolated struct SupabaseManualSyncUserFacingSummary: Equatable, Sendable {
    var kind: SupabaseManualSyncUserFacingSummaryKind
    var message: String
}

nonisolated struct SupabaseManualSyncLocalApplySummary: Equatable, Sendable {
    var productsAdded: Int
    var productsUpdated: Int
    var suppliersCreated: Int
    var categoriesCreated: Int
}

nonisolated enum SupabaseManualSyncReviewSectionTone: Equatable, Sendable {
    case neutral
    case success
    case attention
    case blocked
}

nonisolated enum SupabaseManualSyncReviewSectionID: String, Equatable, Sendable {
    case cloudToDevice
    case deviceToCloud
    case prices
    case attention
    case readyToSend
    case sendAttention
    case sendBlocked
    case finalSummary
}

nonisolated struct SupabaseManualSyncReviewSectionState: Equatable, Identifiable, Sendable {
    var id: SupabaseManualSyncReviewSectionID
    var title: String
    var message: String
    var systemImage: String
    var tone: SupabaseManualSyncReviewSectionTone
}

nonisolated enum SupabaseManualSyncReviewPrimaryActionID: Equatable, Sendable {
    case none
    case updateDevice
    case sendCloudChanges
}

nonisolated struct SupabaseManualSyncReviewSheetState: Equatable, Sendable {
    var title: String
    var subtitle: String
    var sections: [SupabaseManualSyncReviewSectionState]
    var footerMessage: String
    var primaryActionID: SupabaseManualSyncReviewPrimaryActionID
    var primaryActionTitle: String
    var primaryActionSystemImage: String
    var primaryActionIsEnabled: Bool
    var primaryActionIsLoading: Bool
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

nonisolated struct SupabaseManualSyncCatalogPushSummary: Equatable, Sendable {
    var readyCount: Int
    var createCount: Int
    var updateCount: Int
    var linkCount: Int
    var blockerCount: Int
    var warningCount: Int
    var futureOnlyCount: Int
    var planFingerprint: String?
    var resultStatus: SupabaseManualPushTerminalStatus?
    var resultMessage: String?

    var hasReadyChanges: Bool { readyCount > 0 }
    var hasBlockers: Bool { blockerCount > 0 }
    var hasWarnings: Bool { warningCount > 0 || futureOnlyCount > 0 }
}

nonisolated enum SupabaseManualSyncCatalogPushPhase: Equatable, Sendable {
    case idle
    case checking
    case ready(SupabaseManualSyncCatalogPushSummary)
    case noChanges(SupabaseManualSyncCatalogPushSummary)
    case blocked(SupabaseManualSyncCatalogPushSummary)
    case failed(String?)
    case stale
    case sending(SupabaseManualSyncCatalogPushSummary)
    case succeeded(SupabaseManualSyncCatalogPushSummary)
    case succeededNeedsCheck(SupabaseManualSyncCatalogPushSummary)
    case partial(SupabaseManualSyncCatalogPushSummary)
    case sendBlocked(SupabaseManualSyncCatalogPushSummary)
    case sendFailed(SupabaseManualSyncCatalogPushSummary)
}

@MainActor
protocol SupabaseManualSyncCatalogPushProviding: AnyObject {
    func makePushPlan(ownerUserID: UUID) async throws -> ManualPushPlan
    func execute(plan: ManualPushPlan, ownerUserID: UUID) async -> SupabaseManualPushResult
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
    private let remotePreviewStaging: (any SupabaseManualSyncRemotePreviewStaging)?
    private let localApplyService: SupabasePullApplyService?
    private let localApplyContext: ModelContext?
    private let isLocalApplyAuthenticated: (@MainActor () -> Bool)?
    private let catalogPushProvider: (any SupabaseManualSyncCatalogPushProviding)?
    private let currentCatalogPushOwnerID: (@MainActor () -> UUID?)?
    private var lastStartedMode: SupabaseManualSyncRunMode?
    private var stagedCatalogPushPlan: ManualPushPlan?

    @Published private(set) var presentationKind: SupabaseManualSyncUserPresentationKind = .idleReady
    @Published private(set) var title: String = Copy.idleTitle
    @Published private(set) var subtitle: String? = Copy.idleSubtitle
    @Published private(set) var primaryActionTitle: String = Copy.startAction
    @Published private(set) var isRunning = false
    @Published private(set) var cannotStartConcurrently = false
    @Published private(set) var lastSummary: SupabaseManualSyncRunSummary?
    @Published private(set) var authPresentationContext: SupabaseManualSyncAuthPresentationContext
    @Published private(set) var canApplyLocalChanges = false
    @Published private(set) var applyBlockedReason: String?
    @Published private(set) var isApplyingLocalChanges = false
    @Published private(set) var lastLocalApplySummary: SupabaseManualSyncLocalApplySummary?
    @Published private(set) var catalogPushPhase: SupabaseManualSyncCatalogPushPhase = .idle

    init(
        coordinator: any SupabaseManualSyncCoordinating,
        capabilities: SupabaseManualSyncCapabilitySet = .releaseCurrent,
        initialAuthPresentationContext: SupabaseManualSyncAuthPresentationContext = .signedInReady,
        remotePreviewStaging: (any SupabaseManualSyncRemotePreviewStaging)? = nil,
        localApplyService: SupabasePullApplyService? = nil,
        localApplyContext: ModelContext? = nil,
        isLocalApplyAuthenticated: (@MainActor () -> Bool)? = nil,
        catalogPushProvider: (any SupabaseManualSyncCatalogPushProviding)? = nil,
        currentCatalogPushOwnerID: (@MainActor () -> UUID?)? = nil
    ) {
        self.coordinator = coordinator
        self.capabilities = capabilities
        self.authPresentationContext = initialAuthPresentationContext
        self.remotePreviewStaging = remotePreviewStaging
        self.localApplyService = localApplyService
        self.localApplyContext = localApplyContext
        self.isLocalApplyAuthenticated = isLocalApplyAuthenticated
        self.catalogPushProvider = catalogPushProvider
        self.currentCatalogPushOwnerID = currentCatalogPushOwnerID
    }

    var presentationState: SupabaseManualSyncPresentationState {
        makePresentationState()
    }

    var canStart: Bool {
        !isRunning && !isApplyingLocalChanges && !isSendingCatalogChanges
    }

    /// Future guided flow gate (confirmation before mutations). Stubbed false until guided UX exists.
    var pendingConfirmation: Bool { false }

    var shouldShowConfirmation: Bool { false }

    var isSendingCatalogChanges: Bool {
        if case .sending = catalogPushPhase {
            return true
        }
        return false
    }

    var hasTerminalCatalogPushSummary: Bool {
        switch catalogPushPhase {
        case .succeeded, .succeededNeedsCheck, .partial, .sendBlocked, .sendFailed, .stale, .failed, .noChanges:
            return true
        case .idle, .checking, .ready, .blocked, .sending:
            return false
        }
    }

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
        invalidateLocalApplyStaging(clearSummary: true)
        invalidateCatalogPushPlan(clearSummary: true)
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
        await prepareCatalogPushPlanIfNeeded(after: summary)
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
        canApplyLocalChanges = false
        applyBlockedReason = nil
        lastLocalApplySummary = nil

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

        refreshLocalApplyEligibility(from: summary)
    }

    func cancelLocalApplyReview() {
        guard !isApplyingLocalChanges else { return }
        guard canApplyLocalChanges || remotePreviewStaging?.stagedPreviewForLocalApply != nil else { return }
        invalidateLocalApplyStaging(reason: L("options.supabase.manualSync.apply.blocked.refreshRequired"))
    }

    func cancelReviewFlow() {
        guard !isApplyingLocalChanges && !isSendingCatalogChanges else { return }
        cancelLocalApplyReview()
        switch catalogPushPhase {
        case .ready, .blocked, .checking:
            invalidateCatalogPushPlan()
        case .idle, .noChanges, .failed, .stale, .sending, .succeeded, .succeededNeedsCheck, .partial, .sendBlocked, .sendFailed:
            break
        }
    }

    func applyStagedLocalChanges() async {
        guard !isApplyingLocalChanges else { return }

        guard let preview = remotePreviewStaging?.stagedPreviewForLocalApply else {
            invalidateLocalApplyStaging(reason: L("options.supabase.manualSync.apply.blocked.refreshRequired"))
            return
        }

        isApplyingLocalChanges = true
        canApplyLocalChanges = false
        applyBlockedReason = nil
        await Task.yield()

        guard !Task.isCancelled else {
            isApplyingLocalChanges = false
            invalidateLocalApplyStaging(clearSummary: true)
            return
        }

        do {
            let plan = try prepareLocalApplyPlan(from: preview)
            guard let context = localApplyContext,
                  let service = localApplyService else {
                throw LocalApplyInternalError.dependenciesUnavailable
            }
            let result = try service.apply(plan: plan, context: context)
            let summary = SupabaseManualSyncLocalApplySummary(
                productsAdded: result.inserted,
                productsUpdated: result.updated,
                suppliersCreated: result.suppliersCreated,
                categoriesCreated: result.categoriesCreated
            )

            invalidateLocalApplyStaging(clearSummary: false)
            invalidateCatalogPushPlan(clearSummary: true)
            isApplyingLocalChanges = false
            lastSummary = nil
            lastLocalApplySummary = summary
            presentationKind = .localApplyCompleted
            title = L("options.supabase.manualSync.state.applied.title")
            subtitle = L("options.supabase.manualSync.state.applied.subtitle")
            primaryActionTitle = Copy.startAction
        } catch {
            let reason = localApplyBlockedMessage(for: error, failureContext: true)
            invalidateLocalApplyStaging(reason: reason, clearSummary: true)
            isApplyingLocalChanges = false
            lastSummary = nil
            presentationKind = .localApplyFailed
            title = L("options.supabase.manualSync.state.applyFailed.title")
            subtitle = reason
            primaryActionTitle = Copy.dismissOrRetryAction
        }
    }

    private enum LocalApplyInternalError: Error {
        case dependenciesUnavailable
    }

    private func refreshLocalApplyEligibility(from summary: SupabaseManualSyncRunSummary) {
        guard let remotePreviewSummary = summary.remotePreviewSummary else {
            invalidateLocalApplyStaging()
            return
        }

        guard !remotePreviewSummary.wasCancelled,
              remotePreviewSummary.failureCategory == nil else {
            invalidateLocalApplyStaging()
            return
        }

        guard remotePreviewSummary.isComplete,
              !remotePreviewSummary.isPartial else {
            invalidateLocalApplyStaging(reason: L("options.supabase.manualSync.apply.blocked.incompleteCheck"))
            return
        }

        guard let preview = remotePreviewStaging?.stagedPreviewForLocalApply else {
            let reasonKey = remotePreviewSummary.hasRemoteSignals
                ? "options.supabase.manualSync.apply.blocked.refreshRequired"
                : "options.supabase.manualSync.apply.blocked.noChanges"
            invalidateLocalApplyStaging(reason: L(reasonKey))
            return
        }

        do {
            _ = try prepareLocalApplyPlan(from: preview)
            canApplyLocalChanges = true
            applyBlockedReason = nil
        } catch {
            invalidateLocalApplyStaging(reason: localApplyBlockedMessage(for: error))
        }
    }

    private func prepareLocalApplyPlan(from preview: SyncPreview) throws -> SupabasePullApplyPlan {
        guard let context = localApplyContext,
              let service = localApplyService else {
            throw LocalApplyInternalError.dependenciesUnavailable
        }

        return try service.prepareApplyPlan(
            preview: preview,
            context: context,
            options: SupabasePullApplyOptions(),
            isAuthenticated: isLocalApplyAuthenticated?() ?? authPresentationContext.isSignedIn
        )
    }

    private func invalidateLocalApplyStaging(
        reason: String? = nil,
        clearSummary: Bool = false
    ) {
        remotePreviewStaging?.clearStagedPreviewForLocalApply()
        canApplyLocalChanges = false
        applyBlockedReason = reason
        if clearSummary {
            lastLocalApplySummary = nil
        }
    }

    func prepareCatalogPushPlanForReview() async {
        guard let lastSummary else { return }
        await prepareCatalogPushPlanIfNeeded(after: lastSummary, force: true)
    }

    private func prepareCatalogPushPlanIfNeeded(
        after summary: SupabaseManualSyncRunSummary,
        force: Bool = false
    ) async {
        guard capabilities.supportsCatalogPush,
              let catalogPushProvider else {
            invalidateCatalogPushPlan()
            return
        }

        guard force || shouldPrepareCatalogPushPlan(after: summary) else {
            invalidateCatalogPushPlan()
            return
        }

        guard let ownerUserID = currentCatalogPushOwnerID?(),
              authPresentationContext.isSignedIn else {
            stagedCatalogPushPlan = nil
            catalogPushPhase = .failed(L("options.supabase.manualSync.push.blocked.session"))
            if !canApplyLocalChanges {
                presentationKind = .catalogPushFailed
            }
            return
        }

        catalogPushPhase = .checking
        if !canApplyLocalChanges {
            presentationKind = .catalogPushReady
        }

        do {
            let plan = try await catalogPushProvider.makePushPlan(ownerUserID: ownerUserID)
            guard !Task.isCancelled else { return }
            applyCatalogPushPlan(plan)
        } catch {
            guard !Task.isCancelled else { return }
            stagedCatalogPushPlan = nil
            catalogPushPhase = .failed(L("options.supabase.manualSync.push.summary.failedBeforeWrite"))
            if !canApplyLocalChanges {
                presentationKind = .catalogPushFailed
            }
        }
    }

    private func shouldPrepareCatalogPushPlan(after summary: SupabaseManualSyncRunSummary) -> Bool {
        guard let remotePreviewSummary = summary.remotePreviewSummary else {
            return false
        }
        guard remotePreviewSummary.isComplete,
              !remotePreviewSummary.isPartial,
              !remotePreviewSummary.wasCancelled,
              remotePreviewSummary.failureCategory == nil else {
            return false
        }
        return true
    }

    private func applyCatalogPushPlan(_ plan: ManualPushPlan) {
        let summary = makeCatalogPushSummary(from: plan)
        if plan.hasWriteOrLinkCandidates,
           plan.isSendable,
           !plan.hasBlockers {
            stagedCatalogPushPlan = plan
            catalogPushPhase = .ready(summary)
            if !canApplyLocalChanges {
                presentationKind = .catalogPushReady
            }
        } else if plan.hasBlockers {
            stagedCatalogPushPlan = nil
            catalogPushPhase = .blocked(summary)
            if !canApplyLocalChanges {
                presentationKind = .catalogPushBlocked
            }
        } else {
            stagedCatalogPushPlan = nil
            catalogPushPhase = .noChanges(summary)
            if !canApplyLocalChanges {
                presentationKind = .catalogPushNoChanges
            }
        }
    }

    func sendConfirmedCatalogChanges() async {
        guard !isSendingCatalogChanges else { return }
        guard capabilities.supportsCatalogPush,
              let catalogPushProvider else {
            stagedCatalogPushPlan = nil
            catalogPushPhase = .sendFailed(makeCatalogPushSummary(
                from: stagedCatalogPushPlan,
                result: .blocked(message: L("options.supabase.manualSync.push.summary.failedBeforeWrite"))
            ))
            presentationKind = .catalogPushFailed
            return
        }
        guard let stagedPlan = stagedCatalogPushPlan,
              stagedPlan.isSendable,
              !stagedPlan.hasBlockers else {
            stagedCatalogPushPlan = nil
            catalogPushPhase = .stale
            presentationKind = .catalogPushStale
            return
        }
        guard let ownerUserID = currentCatalogPushOwnerID?(),
              authPresentationContext.isSignedIn,
              stagedPlan.ownerUserID == ownerUserID else {
            let result = SupabaseManualPushResult.blocked(
                message: L("options.supabase.manualSync.push.blocked.session")
            )
            stagedCatalogPushPlan = nil
            catalogPushPhase = .sendFailed(makeCatalogPushSummary(from: stagedPlan, result: result))
            presentationKind = .catalogPushFailed
            return
        }

        let sendingSummary = makeCatalogPushSummary(from: stagedPlan)
        catalogPushPhase = .sending(sendingSummary)
        presentationKind = .catalogPushSending
        await Task.yield()

        do {
            let currentPlan = try await catalogPushProvider.makePushPlan(ownerUserID: ownerUserID)
            guard !Task.isCancelled else { return }
            guard currentPlan.planFingerprint == stagedPlan.planFingerprint,
                  currentPlan.isSendable,
                  !currentPlan.hasBlockers else {
                stagedCatalogPushPlan = nil
                catalogPushPhase = .stale
                presentationKind = .catalogPushStale
                return
            }
            guard let latestOwnerUserID = currentCatalogPushOwnerID?(),
                  authPresentationContext.isSignedIn,
                  latestOwnerUserID == ownerUserID,
                  currentPlan.ownerUserID == ownerUserID else {
                let result = SupabaseManualPushResult.blocked(
                    message: L("options.supabase.manualSync.push.blocked.session")
                )
                stagedCatalogPushPlan = nil
                catalogPushPhase = .sendFailed(makeCatalogPushSummary(from: currentPlan, result: result))
                presentationKind = .catalogPushFailed
                return
            }

            let result = await catalogPushProvider.execute(plan: currentPlan, ownerUserID: ownerUserID)
            guard !Task.isCancelled else { return }
            stagedCatalogPushPlan = nil
            applyCatalogPushResult(result, plan: currentPlan)
        } catch {
            guard !Task.isCancelled else { return }
            let result = SupabaseManualPushResult.blocked(
                message: L("options.supabase.manualSync.push.summary.failedBeforeWrite")
            )
            stagedCatalogPushPlan = nil
            catalogPushPhase = .sendFailed(makeCatalogPushSummary(from: stagedPlan, result: result))
            presentationKind = .catalogPushFailed
        }
    }

    private func applyCatalogPushResult(
        _ result: SupabaseManualPushResult,
        plan: ManualPushPlan
    ) {
        let summary = makeCatalogPushSummary(from: plan, result: result)
        switch result.status {
        case .completed:
            catalogPushPhase = .succeeded(summary)
            presentationKind = .catalogPushSucceeded
        case .completedBaselineRefreshFailed:
            catalogPushPhase = .succeededNeedsCheck(summary)
            presentationKind = .catalogPushSucceeded
        case .partial:
            catalogPushPhase = .partial(summary)
            presentationKind = .catalogPushPartiallySucceeded
        case .blockedBeforeWrite:
            catalogPushPhase = .sendBlocked(summary)
            presentationKind = .catalogPushBlocked
        case .failedBeforeWrite:
            catalogPushPhase = .sendFailed(summary)
            presentationKind = .catalogPushFailed
        }
    }

    private func invalidateCatalogPushPlan(clearSummary: Bool = false) {
        stagedCatalogPushPlan = nil
        if clearSummary || !hasTerminalCatalogPushSummary {
            catalogPushPhase = .idle
        }
    }

    private func makeCatalogPushSummary(
        from plan: ManualPushPlan?,
        result: SupabaseManualPushResult? = nil
    ) -> SupabaseManualSyncCatalogPushSummary {
        guard let plan else {
            return SupabaseManualSyncCatalogPushSummary(
                readyCount: 0,
                createCount: 0,
                updateCount: 0,
                linkCount: 0,
                blockerCount: 0,
                warningCount: 0,
                futureOnlyCount: 0,
                planFingerprint: nil,
                resultStatus: result?.status,
                resultMessage: result?.message
            )
        }
        return makeCatalogPushSummary(from: plan, result: result)
    }

    private func makeCatalogPushSummary(
        from plan: ManualPushPlan,
        result: SupabaseManualPushResult? = nil
    ) -> SupabaseManualSyncCatalogPushSummary {
        let createCount = plan.writeCandidates.filter { $0.action == .dryRunCreateCandidate }.count
        let updateCount = plan.writeCandidates.filter { $0.action == .dryRunUpdateCandidate }.count
        let linkCount = plan.writeCandidates.filter { $0.action == .dryRunLinkCandidate }.count
        return SupabaseManualSyncCatalogPushSummary(
            readyCount: plan.writeCandidates.count,
            createCount: createCount,
            updateCount: updateCount,
            linkCount: linkCount,
            blockerCount: plan.blockedReasons.count,
            warningCount: plan.warnings.filter { $0.severity == .warning }.count,
            futureOnlyCount: plan.candidates.filter { $0.severity == .futureOnly }.count
                + plan.warnings.filter { $0.severity == .futureOnly }.count,
            planFingerprint: plan.planFingerprint,
            resultStatus: result?.status,
            resultMessage: result?.message
        )
    }

    private func localApplyBlockedMessage(
        for error: Error,
        failureContext: Bool = false
    ) -> String {
        guard let applyError = error as? SupabasePullApplyError else {
            return failureContext
                ? L("options.supabase.manualSync.apply.blocked.saveFailed")
                : L("options.supabase.manualSync.apply.blocked.refreshRequired")
        }

        if case .saveFailed = applyError {
            return L("options.supabase.manualSync.apply.blocked.saveFailed")
        }

        switch applyError.disabledReason {
        case .sessionMissing, .accountMismatch:
            return L("options.supabase.manualSync.apply.blocked.session")
        case .partialPreview, .sourceErrorsPresent, .priceHistoryIncomplete:
            return L("options.supabase.manualSync.apply.blocked.incompleteCheck")
        case .conflictsPresent, .localDuplicateBarcode:
            return L("options.supabase.manualSync.apply.blocked.needsAttention")
        case .missingApplicablePayload, .missingRequiredField, .invalidPrice, .invalidStockQuantity:
            return L("options.supabase.manualSync.apply.blocked.invalidData")
        case .previewStale:
            return L("options.supabase.manualSync.apply.blocked.stale")
        case .noApplicableChanges:
            return L("options.supabase.manualSync.apply.blocked.noChanges")
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
        invalidateLocalApplyStaging(clearSummary: true)
        invalidateCatalogPushPlan(clearSummary: true)
        presentationKind = .idleReady
        title = Copy.idleTitle
        subtitle = Copy.idleSubtitle
        primaryActionTitle = Copy.startAction
    }

    func applyAuthPresentationContext(_ context: SupabaseManualSyncAuthPresentationContext) {
        guard authPresentationContext != context else { return }
        authPresentationContext = context
        if !context.isSignedIn {
            invalidateLocalApplyStaging(clearSummary: true)
            invalidateCatalogPushPlan(clearSummary: true)
        }
    }

    func runMode(for actionID: SupabaseManualSyncPresentationActionID) -> SupabaseManualSyncRunMode? {
        switch actionID {
        case .checkCloud:
            return capabilities.supportsRemoteCloudCheck ? .dryRun : nil
        case .reviewChanges:
            return nil
        case .syncNow:
            return capabilities.supportsGuidedManualSync ? .guidedManual : nil
        case .sendCloudChanges:
            return nil
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

        if let catalogPushState = catalogPushPresentationState() {
            return catalogPushState
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

        case .localApplyCompleted:
            return state(
                titleKey: "options.supabase.manualSync.state.applied.title",
                subtitleKey: "options.supabase.manualSync.state.applied.subtitle",
                summary: userFacingSummaryForCurrentState(),
                badgeKey: "options.supabase.manualSync.badge.localUpdated",
                badgeSystemImage: "checkmark.circle.fill",
                primaryAction: capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )

        case .localApplyFailed:
            return state(
                titleKey: "options.supabase.manualSync.state.applyFailed.title",
                subtitleKey: "options.supabase.manualSync.state.applyFailed.subtitle",
                summary: userFacingSummaryForCurrentState(),
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "exclamationmark.triangle.fill",
                primaryAction: capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )

        case .catalogPushReady,
             .catalogPushNoChanges,
             .catalogPushBlocked,
             .catalogPushFailed,
             .catalogPushStale,
             .catalogPushSending,
             .catalogPushSucceeded,
             .catalogPushPartiallySucceeded:
            return state(
                titleKey: "options.supabase.manualSync.state.idle.title",
                subtitleKey: "options.supabase.manualSync.state.idle.subtitle",
                badgeKey: "options.supabase.manualSync.badge.manual",
                badgeSystemImage: "hand.tap.fill",
                primaryAction: capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        }
    }

    private func catalogPushPresentationState() -> SupabaseManualSyncPresentationState? {
        guard !canApplyLocalChanges else {
            return nil
        }

        switch catalogPushPhase {
        case .idle:
            return nil
        case .checking:
            return state(
                titleKey: "options.supabase.manualSync.push.state.checking.title",
                subtitleKey: "options.supabase.manualSync.push.state.checking.subtitle",
                badgeKey: "options.supabase.manualSync.badge.running",
                badgeSystemImage: "arrow.triangle.2.circlepath",
                primaryAction: nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: true
            )
        case .ready(let summary):
            return state(
                titleKey: "options.supabase.manualSync.push.state.ready.title",
                subtitleKey: "options.supabase.manualSync.push.state.ready.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                reviewSheet: makeCatalogPushReviewSheetState(phase: catalogPushPhase, summary: summary),
                badgeKey: "options.supabase.manualSync.badge.readyToSend",
                badgeSystemImage: "icloud.and.arrow.up",
                primaryAction: action(.reviewChanges),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .noChanges:
            return state(
                titleKey: "options.supabase.manualSync.push.state.noChanges.title",
                subtitleKey: "options.supabase.manualSync.push.state.noChanges.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                reviewSheet: nil,
                badgeKey: "options.supabase.manualSync.badge.noChanges",
                badgeSystemImage: "checkmark.circle.fill",
                primaryAction: capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .blocked(let summary):
            return state(
                titleKey: "options.supabase.manualSync.push.state.blocked.title",
                subtitleKey: "options.supabase.manualSync.push.state.blocked.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                reviewSheet: makeCatalogPushReviewSheetState(phase: catalogPushPhase, summary: summary),
                badgeKey: "options.supabase.manualSync.badge.needsFix",
                badgeSystemImage: "xmark.octagon.fill",
                primaryAction: action(.reviewChanges),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .failed:
            return retryState(
                titleKey: "options.supabase.manualSync.push.state.failed.title",
                subtitleKey: "options.supabase.manualSync.push.state.failed.subtitle",
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "exclamationmark.triangle.fill"
            )
        case .stale:
            return state(
                titleKey: "options.supabase.manualSync.push.state.stale.title",
                subtitleKey: "options.supabase.manualSync.push.state.stale.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "arrow.clockwise.circle.fill",
                primaryAction: capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .sending(let summary):
            return state(
                titleKey: "options.supabase.manualSync.push.state.sending.title",
                subtitleKey: "options.supabase.manualSync.push.state.sending.subtitle",
                reviewSheet: makeCatalogPushReviewSheetState(phase: catalogPushPhase, summary: summary),
                badgeKey: "options.supabase.manualSync.badge.running",
                badgeSystemImage: "arrow.triangle.2.circlepath",
                primaryAction: nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: true
            )
        case .succeeded(let summary), .succeededNeedsCheck(let summary):
            return state(
                titleKey: "options.supabase.manualSync.push.state.succeeded.title",
                subtitleKey: "options.supabase.manualSync.push.state.succeeded.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                reviewSheet: makeCatalogPushReviewSheetState(phase: catalogPushPhase, summary: summary),
                badgeKey: "options.supabase.manualSync.badge.sent",
                badgeSystemImage: "checkmark.circle.fill",
                primaryAction: capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .partial(let summary):
            return state(
                titleKey: "options.supabase.manualSync.push.state.partial.title",
                subtitleKey: "options.supabase.manualSync.push.state.partial.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                reviewSheet: makeCatalogPushReviewSheetState(phase: catalogPushPhase, summary: summary),
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "exclamationmark.triangle.fill",
                primaryAction: action(.retry),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .sendBlocked(let summary):
            return state(
                titleKey: "options.supabase.manualSync.push.state.blocked.title",
                subtitleKey: "options.supabase.manualSync.push.state.blocked.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                reviewSheet: makeCatalogPushReviewSheetState(phase: catalogPushPhase, summary: summary),
                badgeKey: "options.supabase.manualSync.badge.needsFix",
                badgeSystemImage: "xmark.octagon.fill",
                primaryAction: action(.reviewChanges),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .sendFailed(let summary):
            return state(
                titleKey: "options.supabase.manualSync.push.state.failed.title",
                subtitleKey: "options.supabase.manualSync.push.state.failed.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                reviewSheet: makeCatalogPushReviewSheetState(phase: catalogPushPhase, summary: summary),
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "exclamationmark.triangle.fill",
                primaryAction: action(.retry),
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
        switch presentationKind {
        case .localApplyCompleted:
            guard let lastLocalApplySummary else { return nil }
            return SupabaseManualSyncUserFacingSummary(
                kind: .localApplyCompleted,
                message: makeLocalApplyCompletedMessage(from: lastLocalApplySummary)
            )
        case .localApplyFailed:
            return userFacingSummary(.localApplyFailed, key: "options.supabase.manualSync.summary.localApply.failed")
        case .successFullyUpToDate, .partialSync, .connectivityIssue, .cancelledRun, .technicalFollowUpNeeded:
            guard let lastSummary else { return nil }
            return makeUserFacingSummary(from: lastSummary)
        case .catalogPushNoChanges,
             .catalogPushBlocked,
             .catalogPushFailed,
             .catalogPushStale,
             .catalogPushSucceeded,
             .catalogPushPartiallySucceeded:
            return catalogPushUserFacingSummary(for: catalogPushPhase)
        case .idleReady,
             .running,
             .blockedNeedsSignIn,
             .blockedNeedsCloudRealignment,
             .auxiliaryBusyConcurrent,
             .auxiliaryModeUnavailable,
             .catalogPushReady,
             .catalogPushSending:
            return nil
        }
    }

    private func catalogPushUserFacingSummary(
        for phase: SupabaseManualSyncCatalogPushPhase
    ) -> SupabaseManualSyncUserFacingSummary? {
        switch phase {
        case .noChanges:
            return userFacingSummary(.catalogPushNoChanges, key: "options.supabase.manualSync.push.summary.noChanges")
        case .blocked, .sendBlocked:
            return userFacingSummary(.catalogPushBlocked, key: "options.supabase.manualSync.push.summary.blocked")
        case .failed:
            return userFacingSummary(.catalogPushFailedBeforeWrite, key: "options.supabase.manualSync.push.summary.failedBeforeWrite")
        case .stale:
            return userFacingSummary(.catalogPushStale, key: "options.supabase.manualSync.push.summary.stale")
        case .succeeded:
            return userFacingSummary(.catalogPushSucceeded, key: "options.supabase.manualSync.push.summary.succeeded")
        case .succeededNeedsCheck:
            return userFacingSummary(.catalogPushSucceededNeedsCheck, key: "options.supabase.manualSync.push.summary.succeededNeedsCheck")
        case .partial:
            return userFacingSummary(.catalogPushPartial, key: "options.supabase.manualSync.push.summary.partial")
        case .sendFailed:
            return userFacingSummary(.catalogPushFailedBeforeWrite, key: "options.supabase.manualSync.push.summary.failedBeforeWrite")
        case .idle, .checking, .ready, .sending:
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

    private func makeLocalApplyCompletedMessage(
        from summary: SupabaseManualSyncLocalApplySummary
    ) -> String {
        var details: [String] = []
        if summary.productsAdded > 0 {
            details.append(L("options.supabase.manualSync.summary.localApply.productsAdded", summary.productsAdded))
        }
        if summary.productsUpdated > 0 {
            details.append(L("options.supabase.manualSync.summary.localApply.productsUpdated", summary.productsUpdated))
        }
        if summary.suppliersCreated > 0 {
            details.append(L("options.supabase.manualSync.summary.localApply.suppliersCreated", summary.suppliersCreated))
        }
        if summary.categoriesCreated > 0 {
            details.append(L("options.supabase.manualSync.summary.localApply.categoriesCreated", summary.categoriesCreated))
        }

        guard !details.isEmpty else {
            return L("options.supabase.manualSync.summary.localApply.completed")
        }
        return L("options.supabase.manualSync.summary.localApply.completedWithCounts", details.joined(separator: ", "))
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
             .cancelled,
             .localApplyCompleted,
             .localApplyFailed,
             .catalogPushNoChanges,
             .catalogPushSucceeded,
             .catalogPushSucceededNeedsCheck,
             .catalogPushPartial,
             .catalogPushBlocked,
             .catalogPushFailedBeforeWrite,
             .catalogPushInterrupted,
             .catalogPushStale:
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
        let footerMessage = reviewFooterMessage(remotePreviewSummary: remotePreviewSummary)
        let primaryActionTitle = isApplyingLocalChanges
            ? L("options.supabase.manualSync.review.action.updatingDevice")
            : L("options.supabase.manualSync.review.action.updateDevice")
        let secondaryActionTitle = L("options.supabase.manualSync.review.action.cancel")
        let accessibilityLabel = ([title, subtitle] + sections.map(\.title) + [footerMessage])
            .joined(separator: ". ")

        return SupabaseManualSyncReviewSheetState(
            title: title,
            subtitle: subtitle,
            sections: sections,
            footerMessage: footerMessage,
            primaryActionID: .updateDevice,
            primaryActionTitle: primaryActionTitle,
            primaryActionSystemImage: "arrow.down.circle",
            primaryActionIsEnabled: canApplyLocalChanges && !isApplyingLocalChanges,
            primaryActionIsLoading: isApplyingLocalChanges,
            secondaryActionTitle: secondaryActionTitle,
            accessibilityLabel: accessibilityLabel
        )
    }

    private func makeCatalogPushReviewSheetState(
        phase: SupabaseManualSyncCatalogPushPhase,
        summary: SupabaseManualSyncCatalogPushSummary
    ) -> SupabaseManualSyncReviewSheetState {
        let title = L("options.supabase.manualSync.push.review.title")
        let subtitle = catalogPushReviewSubtitle(phase: phase)
        let sections = catalogPushReviewSections(phase: phase, summary: summary)
        let footerMessage = catalogPushReviewFooter(phase: phase)
        let primaryID = catalogPushReviewPrimaryActionID(phase: phase)
        let primaryTitle: String
        let primarySystemImage: String
        switch primaryID {
        case .sendCloudChanges:
            primaryTitle = isSendingCatalogChanges
                ? L("options.supabase.manualSync.push.review.action.sending")
                : L("options.supabase.manualSync.push.review.action.send")
            primarySystemImage = "icloud.and.arrow.up"
        case .updateDevice:
            primaryTitle = L("options.supabase.manualSync.review.action.updateDevice")
            primarySystemImage = "arrow.down.circle"
        case .none:
            primaryTitle = ""
            primarySystemImage = "icloud.and.arrow.up"
        }
        let accessibilityLabel = ([title, subtitle] + sections.flatMap { [$0.title, $0.message] } + [footerMessage])
            .joined(separator: ". ")

        return SupabaseManualSyncReviewSheetState(
            title: title,
            subtitle: subtitle,
            sections: sections,
            footerMessage: footerMessage,
            primaryActionID: primaryID,
            primaryActionTitle: primaryTitle,
            primaryActionSystemImage: primarySystemImage,
            primaryActionIsEnabled: primaryID == .sendCloudChanges && !isSendingCatalogChanges,
            primaryActionIsLoading: isSendingCatalogChanges,
            secondaryActionTitle: L(hasTerminalCatalogPushSummary ? "common.close" : "common.cancel"),
            accessibilityLabel: accessibilityLabel
        )
    }

    private func catalogPushReviewSubtitle(phase: SupabaseManualSyncCatalogPushPhase) -> String {
        switch phase {
        case .succeeded, .succeededNeedsCheck, .partial, .sendBlocked, .sendFailed:
            return L("options.supabase.manualSync.push.review.subtitle.final")
        case .sending:
            return L("options.supabase.manualSync.push.review.subtitle.sending")
        case .blocked:
            return L("options.supabase.manualSync.push.review.subtitle.blocked")
        case .ready, .checking, .noChanges, .failed, .stale, .idle:
            return L("options.supabase.manualSync.push.review.subtitle")
        }
    }

    private func catalogPushReviewSections(
        phase: SupabaseManualSyncCatalogPushPhase,
        summary: SupabaseManualSyncCatalogPushSummary
    ) -> [SupabaseManualSyncReviewSectionState] {
        var sections: [SupabaseManualSyncReviewSectionState] = []
        if summary.hasReadyChanges {
            sections.append(reviewSection(
                id: .readyToSend,
                titleKey: "options.supabase.manualSync.push.review.ready.title",
                message: L(
                    "options.supabase.manualSync.push.review.ready.message",
                    summary.readyCount,
                    summary.createCount,
                    summary.updateCount,
                    summary.linkCount
                ),
                systemImage: "checkmark.circle.fill",
                tone: .success
            ))
        }
        if summary.hasWarnings {
            sections.append(reviewSection(
                id: .sendAttention,
                titleKey: "options.supabase.manualSync.push.review.attention.title",
                message: L("options.supabase.manualSync.push.review.attention.message"),
                systemImage: "exclamationmark.triangle.fill",
                tone: .attention
            ))
        }
        if summary.hasBlockers {
            sections.append(reviewSection(
                id: .sendBlocked,
                titleKey: "options.supabase.manualSync.push.review.blocked.title",
                message: L("options.supabase.manualSync.push.review.blocked.message", summary.blockerCount),
                systemImage: "xmark.octagon.fill",
                tone: .blocked
            ))
        }
        if case .succeeded = phase {
            sections.append(finalSummarySection(key: "options.supabase.manualSync.push.summary.succeeded"))
        } else if case .succeededNeedsCheck = phase {
            sections.append(finalSummarySection(key: "options.supabase.manualSync.push.summary.succeededNeedsCheck"))
        } else if case .partial = phase {
            sections.append(finalSummarySection(key: "options.supabase.manualSync.push.summary.partial"))
        } else if case .sendFailed = phase {
            sections.append(finalSummarySection(key: "options.supabase.manualSync.push.summary.failedBeforeWrite"))
        } else if case .sendBlocked = phase {
            sections.append(finalSummarySection(key: "options.supabase.manualSync.push.summary.blocked"))
        }
        if sections.isEmpty {
            sections.append(reviewSection(
                id: .finalSummary,
                titleKey: "options.supabase.manualSync.push.review.final.title",
                message: L("options.supabase.manualSync.push.summary.noChanges"),
                systemImage: "checkmark.circle.fill",
                tone: .neutral
            ))
        }
        return sections
    }

    private func finalSummarySection(key: String) -> SupabaseManualSyncReviewSectionState {
        reviewSection(
            id: .finalSummary,
            titleKey: "options.supabase.manualSync.push.review.final.title",
            message: L(key),
            systemImage: "list.bullet.clipboard",
            tone: .neutral
        )
    }

    private func catalogPushReviewFooter(phase: SupabaseManualSyncCatalogPushPhase) -> String {
        switch phase {
        case .ready:
            if canApplyLocalChanges {
                return L("options.supabase.manualSync.push.review.footer.updateFirst")
            }
            return L("options.supabase.manualSync.push.review.footer.ready")
        case .blocked, .sendBlocked:
            return L("options.supabase.manualSync.push.review.footer.blocked")
        case .sending:
            return L("options.supabase.manualSync.push.review.footer.sending")
        case .succeeded, .succeededNeedsCheck, .partial, .sendFailed:
            return L("options.supabase.manualSync.push.review.footer.final")
        case .stale:
            return L("options.supabase.manualSync.push.summary.stale")
        case .idle, .checking, .noChanges, .failed:
            return L("options.supabase.manualSync.push.review.footer.ready")
        }
    }

    private func catalogPushReviewPrimaryActionID(
        phase: SupabaseManualSyncCatalogPushPhase
    ) -> SupabaseManualSyncReviewPrimaryActionID {
        switch phase {
        case .ready:
            return canApplyLocalChanges ? .none : .sendCloudChanges
        case .sending:
            return .sendCloudChanges
        case .idle, .checking, .noChanges, .blocked, .failed, .stale, .succeeded, .succeededNeedsCheck, .partial, .sendBlocked, .sendFailed:
            return .none
        }
    }

    private func reviewFooterMessage(
        remotePreviewSummary: SupabaseManualSyncRemotePreviewSummary
    ) -> String {
        if isApplyingLocalChanges {
            return L("options.supabase.manualSync.review.footer.updatingDevice")
        }
        if canApplyLocalChanges {
            return L("options.supabase.manualSync.review.footer.readyToUpdateDevice")
        }
        if let applyBlockedReason {
            return applyBlockedReason
        }
        return remotePreviewSummary.hasRemoteSignals
            ? L("options.supabase.manualSync.apply.blocked.refreshRequired")
            : L("options.supabase.manualSync.apply.blocked.noChanges")
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

    private func reviewSection(
        id: SupabaseManualSyncReviewSectionID,
        titleKey: String,
        message: String,
        systemImage: String,
        tone: SupabaseManualSyncReviewSectionTone
    ) -> SupabaseManualSyncReviewSectionState {
        SupabaseManualSyncReviewSectionState(
            id: id,
            title: L(titleKey),
            message: message,
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
        case .sendCloudChanges:
            key = "sendToCloud"
            systemImage = "icloud.and.arrow.up"
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
        if summary.kind.isCatalogPushTerminal {
            return summary
        }
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

private extension SupabaseManualSyncUserFacingSummaryKind {
    var isCatalogPushTerminal: Bool {
        switch self {
        case .catalogPushNoChanges,
             .catalogPushSucceeded,
             .catalogPushSucceededNeedsCheck,
             .catalogPushPartial,
             .catalogPushBlocked,
             .catalogPushFailedBeforeWrite,
             .catalogPushInterrupted,
             .catalogPushStale:
            return true
        default:
            return false
        }
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
