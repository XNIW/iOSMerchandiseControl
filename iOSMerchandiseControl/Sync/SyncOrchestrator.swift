import Combine
import Foundation
import SwiftUI

nonisolated enum SyncRootPresentationKind: Equatable, Sendable {
    case hidden
    case checking
    case blockedAuth
    case deviceBlocked
    case recoverableError
}

nonisolated enum SyncRootPresentationActionID: Equatable, Sendable {
    case reviewChanges
    case signIn
    case retry
}

nonisolated struct SyncRootPresentationState: Equatable, Sendable {
    var kind: SyncRootPresentationKind
    var titleKey: String
    var detailKey: String?
    var primaryActionTitleKey: String?
    var primaryActionID: SyncRootPresentationActionID?
    var systemImage: String

    static let hidden = SyncRootPresentationState(
        kind: .hidden,
        titleKey: "",
        detailKey: nil,
        primaryActionTitleKey: nil,
        primaryActionID: nil,
        systemImage: "icloud"
    )

    static let checking = SyncRootPresentationState(
        kind: .checking,
        titleKey: "sync.local.significantWork.title",
        detailKey: "options.supabase.automaticSync.root.checking.detail",
        primaryActionTitleKey: nil,
        primaryActionID: nil,
        systemImage: "arrow.triangle.2.circlepath.icloud"
    )

    static let blockedAuth = SyncRootPresentationState(
        kind: .blockedAuth,
        titleKey: "options.supabase.automaticSync.root.auth.title",
        detailKey: "options.supabase.automaticSync.root.auth.detail",
        primaryActionTitleKey: "options.supabase.automaticSync.root.action.signIn",
        primaryActionID: .signIn,
        systemImage: "person.crop.circle.badge.exclamationmark"
    )

    static let recoverableError = SyncRootPresentationState(
        kind: .recoverableError,
        titleKey: "options.supabase.automaticSync.root.error.title",
        detailKey: "options.supabase.automaticSync.root.error.detail",
        primaryActionTitleKey: "options.supabase.automaticSync.root.action.retry",
        primaryActionID: .retry,
        systemImage: "exclamationmark.icloud"
    )

    static let deviceBlocked = SyncRootPresentationState(
        kind: .deviceBlocked,
        titleKey: "options.supabase.automaticSync.root.deviceBlocked.title",
        detailKey: "options.supabase.automaticSync.root.deviceBlocked.detail",
        primaryActionTitleKey: "options.supabase.automaticSync.root.action.retry",
        primaryActionID: .retry,
        systemImage: "iphone.slash"
    )
}

nonisolated enum SyncBootstrapReadiness {
    static func shouldStart(isSignedIn: Bool, isShopSyncAllowed: Bool) -> Bool {
        isSignedIn && isShopSyncAllowed
    }
}

nonisolated enum AccountStoreReplacementRuntimeError: Error, Equatable {
    case alreadyInProgress
}

@MainActor
private final class ForegroundRecoveryInvocation {
    var claim: SyncAutomaticRecoveryAttemptClaim?
    nonisolated deinit {}
}

@MainActor
final class SyncOrchestrator: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    private let automaticRuntime: any SyncAutomaticRuntimeProviding
    private let authViewModel: SupabaseAuthViewModel
    private let activityCenter: ForegroundCloudWorkflowActivityCenter
    private let syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?
    private let stateStore: SyncStateStore
    private let storeGenerationController: SyncStoreGenerationController?
    private let storeGenerationLease: SyncStoreGenerationLease?
    private let defaults: UserDefaults
    private let decisionInputProvider: any SyncDecisionInputProviding
    private let backgroundScheduler: any SyncBackgroundTaskScheduling

    private var currentScenePhase: ScenePhase = .inactive
    private var foregroundTask: Task<Void, Never>?
    private var foregroundInvocationID: UUID?
    private var foregroundObservationSource: SyncAutomaticRunObservationSource?
    private var foregroundOwnerStoreScope: Task126VerifiedOwnerStoreScope?
    private var didReachInteractiveUI = false
    private var hasDeferredForegroundCheck = false
    private var deferredForegroundSource: SyncAutomaticTriggerSource?
    private var deferredForegroundForceIncremental = false
    private var deferredStartsNewRetryWindow = false
    private var syncEventSafetyLoopTask: Task<Void, Never>?
    private var reconnectScheduler: AutomaticSyncReconnectScheduler?
    private var reconnectObserver: AutomaticSyncNetworkReachabilityObserver?
    private var scheduledForegroundRetryTask: Task<Void, Never>?
    private var scheduledForegroundRetryIdentity: String?
    private var scheduledForegroundRetryToken: UUID?
    private var foregroundBusyRetryAttempt = 0
    private var isAccountStoreReplacementInProgress = false
    private var foregroundStartedFromRecoveryRequired = false
    private var isStopped = false
    private var localQualificationSubscription: AnyCancellable?
    private var localQualificationEventTask: Task<Void, Never>?
    private var lastResumedLocalQualificationRevision = 0
    private var pendingPopulatedQualificationScope: Task126VerifiedOwnerStoreScope?
    private let foregroundRetryDelay: @Sendable (TimeInterval) async -> Void
    private let maximumForegroundBusyRetryAttempts: Int
    private let now: @Sendable () -> Date
    private let monotonicNow: @Sendable () -> TimeInterval

    init(
        automaticRuntime: any SyncAutomaticRuntimeProviding,
        authViewModel: SupabaseAuthViewModel,
        activityCenter: ForegroundCloudWorkflowActivityCenter,
        syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?,
        stateStore: SyncStateStore? = nil,
        storeGenerationController: SyncStoreGenerationController? = nil,
        storeGenerationLease: SyncStoreGenerationLease? = nil,
        defaults: UserDefaults = .standard,
        decisionInputProvider: any SyncDecisionInputProviding,
        backgroundScheduler: (any SyncBackgroundTaskScheduling)? = nil,
        maximumForegroundBusyRetryAttempts: Int = 3,
        now: @escaping @Sendable () -> Date = { Date() },
        monotonicNow: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        foregroundRetryDelay: @escaping @Sendable (TimeInterval) async -> Void = { delay in
            let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.automaticRuntime = automaticRuntime
        self.authViewModel = authViewModel
        self.activityCenter = activityCenter
        self.syncEventSignalWatcher = syncEventSignalWatcher
        self.stateStore = stateStore ?? SyncStateStore(defaults: defaults)
        self.storeGenerationController = storeGenerationController
        self.storeGenerationLease = storeGenerationLease
        self.defaults = defaults
        self.decisionInputProvider = decisionInputProvider
        self.backgroundScheduler = backgroundScheduler ?? SyncBackgroundTaskScheduler.shared
        self.maximumForegroundBusyRetryAttempts = max(0, maximumForegroundBusyRetryAttempts)
        self.foregroundRetryDelay = foregroundRetryDelay
        self.now = now
        self.monotonicNow = monotonicNow
        lastResumedLocalQualificationRevision = storeGenerationController?.localBodyQualificationRevision ?? 0
        localQualificationSubscription = storeGenerationController?.objectWillChange.sink { [weak self] _ in
            self?.scheduleLocalQualificationReadback()
        }
    }

    private func scheduleLocalQualificationReadback() {
        guard !isStopped, localQualificationEventTask == nil else { return }
        // @Published sends before mutation. Coalesce the actual publication
        // and later invalidation events, then inspect only current authority.
        localQualificationEventTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.localQualificationEventTask = nil
            guard !Task.isCancelled, !self.isStopped, self.didReachInteractiveUI,
                  self.currentScenePhase == .active, self.authViewModel.isSignedIn,
                  let controller = self.storeGenerationController,
                  let lease = self.storeGenerationLease,
                  (try? controller.validateLease(lease)) != nil,
                  let owner = self.authViewModel.localMutationOwnerUserID else { return }
            controller.requestEmptyRootQualificationAfterPublication(ownerUserID: owner)
            // A populated readback is asynchronous too. Resume only a new,
            // physically current proof for this mounted owner/shop generation.
            // This is an ordinary trigger, not explicit Retry authority.
            guard let scope = self.currentPopulatedRecoveryScope(),
                  self.pendingPopulatedQualificationScope == nil || self.pendingPopulatedQualificationScope == scope else {
                self.discardPopulatedQualificationWait()
                return
            }
            guard self.pendingPopulatedQualificationScope != nil
                    || controller.localBodyQualificationRevision != self.lastResumedLocalQualificationRevision,
                  Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                    modelContainer: controller.modelContainer, ownerUserID: owner, defaults: self.defaults
                  ) else { return }
            if self.pendingPopulatedQualificationScope != nil {
                self.deferForegroundCheck(source: .rootForeground, forceIncremental: true)
                guard self.foregroundTask == nil, !self.activityCenter.blocksAutomaticSync else { return }
                self.pendingPopulatedQualificationScope = nil
            }
            self.lastResumedLocalQualificationRevision = controller.localBodyQualificationRevision
            self.deferForegroundCheck(source: .rootForeground, forceIncremental: true)
            // Editing or an existing run retains the coalesced ordinary request.
            self.resumeDeferredForegroundCheckIfReady()
        }
    }

    #if DEBUG
    var localQualificationEventTaskForTesting: Task<Void, Never>? { localQualificationEventTask }

    // Observe completion of the already scheduled consumer without issuing an event.
    func awaitLocalQualificationEventForTesting() async {
        await localQualificationEventTask?.value
    }
    #endif

    var rootPresentationState: SyncRootPresentationState {
        Self.makeRootPresentationState(
            isTransitioning: authViewModel.isTransitioning,
            isSignedIn: authViewModel.isSignedIn,
            isAutomaticRuntimeRunning: automaticRuntime.isRunning,
            phase: stateStore.state.phase
        )
    }

    var hasCurrentPresentationInvocation: Bool {
        guard automaticRuntime.isRunning, let foregroundInvocationID else { return false }
        return stateStore.ownsPresentationInvocation(foregroundInvocationID)
    }

    var visibleWorkInvocationID: UUID? {
        guard hasCurrentPresentationInvocation,
              stateStore.state.phase.isSignificantAutomaticWork else { return nil }
        return foregroundInvocationID
    }

    static func makeRootPresentationState(
        isTransitioning: Bool,
        isSignedIn: Bool,
        isAutomaticRuntimeRunning: Bool,
        phase: SyncPhase
    ) -> SyncRootPresentationState {
        if case .blocked(.deviceNotActive) = phase { return .deviceBlocked }
        if isTransitioning { return .hidden }
        if !isSignedIn { return .blockedAuth }
        if isAutomaticRuntimeRunning && phase.isSignificantAutomaticWork { return .checking }
        switch phase {
        case .recoveryRequired, .failed: return .recoverableError
        case .blocked(.authRequired): return .blockedAuth
        default: return .hidden
        }
    }

    func bootstrap(scenePhase: ScenePhase) async {
        guard !isStopped else { return }
        currentScenePhase = scenePhase
        recordRuntimeDiagnostic("rootHost.taskStartedAt", Date().timeIntervalSince1970)
        startReconnectObserverIfNeeded()
        syncAuthPresentationContext()
        if !didReachInteractiveUI {
            await Task.yield()
            didReachInteractiveUI = true
            recordRuntimeDiagnostic("rootHost.didReachInteractiveUI", true)
        }
        reconnectScheduler?.setForeground(scenePhase == .active)
        updateSyncEventSignalWatcher()
        startSyncEventSafetyLoopIfNeeded()
        submitForegroundTrigger(forceIncremental: true)
    }

    func handleScenePhaseChanged(_ phase: ScenePhase) {
        currentScenePhase = phase
        switch phase {
        case .active:
            reconnectScheduler?.setForeground(true)
            syncAuthPresentationContext()
            guard didReachInteractiveUI else { return }
            scheduleLocalQualificationReadback()
            updateSyncEventSignalWatcher()
            startSyncEventSafetyLoopIfNeeded()
            submitForegroundTrigger(forceIncremental: true)
        case .background:
            backgroundScheduler.schedule(reason: .periodicOpportunity)
            reconnectScheduler?.setForeground(false)
            syncEventSignalWatcher?.stop()
            stopSyncEventSafetyLoop()
            cancelForegroundCheck()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    func handleAuthPresentationChanged() {
        Task126OwnerStoreGate.invalidateAutomaticScopeLease()
        cancelForegroundCheck()
        syncAuthPresentationContext()
        updateSyncEventSignalWatcher()
    }

    func handleShopContextChanged() {
        Task126OwnerStoreGate.invalidateAutomaticScopeLease()
        cancelForegroundCheck()
        updateSyncEventSignalWatcher()
        if let controller = storeGenerationController, let lease = storeGenerationLease,
           (try? controller.validateLease(lease)) != nil,
           let owner = authViewModel.localMutationOwnerUserID {
            controller.requestLocalBodyQualificationAfterShopContextChange(ownerUserID: owner)
        }
        guard didReachInteractiveUI,
              currentScenePhase == .active,
              authViewModel.isSignedIn else { return }
        submitForegroundTrigger(source: .rootForeground, forceIncremental: true)
    }

    func resumeDeferredForegroundCheckIfReady() {
        guard didReachInteractiveUI,
              hasDeferredForegroundCheck,
              !activityCenter.blocksAutomaticSync else { return }
        if pendingPopulatedQualificationScope != nil {
            scheduleLocalQualificationReadback()
            return
        }
        runDeferredForegroundCheckIfNeeded()
    }

    func handleLocalPendingChanges() {
        backgroundScheduler.schedule(reason: .localPendingWrite)
        // The notification can be synchronous inside the local writer lease.
        // Submit after its atomic save returns, before capturing sync authority.
        Task { @MainActor [weak self] in
            guard let self, !self.isStopped, self.didReachInteractiveUI,
                  self.currentScenePhase == .active else { return }
            self.submitForegroundTrigger(source: .localMutation, forceIncremental: true)
        }
    }

    func stop() {
        isStopped = true
        localQualificationSubscription?.cancel()
        localQualificationSubscription = nil
        localQualificationEventTask?.cancel()
        localQualificationEventTask = nil
        cancelForegroundCheck()
        stopSyncEventSafetyLoop()
        reconnectObserver?.cancel()
        reconnectObserver = nil
        reconnectScheduler = nil
        syncEventSignalWatcher?.stop()
    }

    func shouldShowRootBanner(
        _ state: SyncRootPresentationState,
        selectedTab: Int
    ) -> Bool {
        // Ordinary checking and waiting stay quiet. Persistent problems remain
        // on their contextual surface and in Options; no repeated global alert.
        state.kind == .checking && visibleWorkInvocationID != nil
            && selectedTab != 3 && !activityCenter.blocksAutomaticSync
    }

    func retryRootActionIfPossible() {
        submitForegroundTrigger(
            source: Self.retryTriggerSource(for: stateStore.state.phase),
            forceIncremental: true
        )
    }

    func retryPendingRecoveryRootAction() {
        stateStore.reconcilePendingRecoveryJournal()
        submitForegroundTrigger(source: .releaseCard, forceIncremental: true)
    }

    func submitForegroundTrigger(
        source: SyncAutomaticTriggerSource = .rootForeground,
        forceIncremental: Bool = false
    ) {
        requestForegroundTrigger(source: source, forceIncremental: forceIncremental, isDeferredReplay: false)
    }

    private func requestForegroundTrigger(source: SyncAutomaticTriggerSource,
        forceIncremental: Bool, isDeferredReplay: Bool) {
        #if DEBUG
        observeT10ForegroundAdmission("entry", source: source)
        #endif
        guard !isStopped else { return }
        // A retired root cannot start new work or retire another generation's
        // retry bookkeeping. In-flight publication completion keeps its own
        // qualified completion path; never recapture authority here.
        if let controller = storeGenerationController {
            guard let lease = storeGenerationLease,
                  (try? controller.validateLease(lease)) != nil else {
                recordRuntimeDiagnostic("foreground.outcome", "foreground_generation_unavailable")
                return
            }
        }
        let startsNewRetryWindow = source == .releaseCard && !isDeferredReplay
        recordRuntimeDiagnostic("foreground.requestedAt", Date().timeIntervalSince1970)
        recordRuntimeDiagnostic("foreground.source", source.diagnosticsName)
        recordRuntimeDiagnostic("foreground.forceIncremental", forceIncremental)
        let canRunForCurrentScene = currentScenePhase == .active || (forceIncremental && currentScenePhase != .background)
        guard canRunForCurrentScene else {
            recordRuntimeDiagnostic("foreground.outcome", "blocked_scene")
            return
        }
        guard !isAccountStoreReplacementInProgress else {
            deferForegroundCheck(source: source, forceIncremental: forceIncremental, startsNewRetryWindow: startsNewRetryWindow)
            recordRuntimeDiagnostic("foreground.outcome", "deferred_store_replacement")
            return
        }
        if (source == .rootForeground || source == .networkReconnect || source == .releaseCard),
           let waitingScope = pendingPopulatedQualificationScope {
            #if DEBUG
            // Every existing branch below returns; do not re-read the scope.
            observeT10ForegroundAdmission("waiting-scope-return", source: source)
            #endif
            guard currentPopulatedRecoveryScope() == waitingScope else {
                discardPopulatedQualificationWait()
                return
            }
            deferForegroundCheck(source: .rootForeground, forceIncremental: forceIncremental)
            scheduleLocalQualificationReadback()
            return
        }
        guard foregroundTask == nil else {
            deferForegroundCheck(source: source, forceIncremental: forceIncremental, startsNewRetryWindow: startsNewRetryWindow)
            recordRuntimeDiagnostic("foreground.outcome", "deferred_existing_task")
            return
        }
        guard !activityCenter.blocksAutomaticSync else {
            deferForegroundCheck(source: source, forceIncremental: forceIncremental, startsNewRetryWindow: startsNewRetryWindow)
            recordRuntimeDiagnostic("foreground.outcome", "deferred_busy")
            return
        }

        let capturedPopulatedScope: Task126VerifiedOwnerStoreScope?
        let beganWithoutBodyProof: Bool
        if (source == .rootForeground || source == .networkReconnect || source == .releaseCard),
           stateStore.state.phase == .recoveryRequired,
           storeGenerationController?.activeManifest != nil,
           stateStore.pendingRecoveryJournal?.mode == .sameScopeRecovery {
            guard let scope = currentPopulatedRecoveryScope(),
                  let controller = storeGenerationController else {
                #if DEBUG
                observeT10ForegroundAdmission("captured-scope-unavailable-return", source: source)
                #endif
                discardPopulatedQualificationWait(includingUnstartedRequest: true)
                return
            }
            capturedPopulatedScope = scope
            beganWithoutBodyProof = !Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer)
            guard !beganWithoutBodyProof || currentScenePhase == .active else {
                #if DEBUG
                observeT10ForegroundAdmission("captured-scope-scene-return", source: source)
                #endif
                discardPopulatedQualificationWait(includingUnstartedRequest: true)
                return
            }
        } else {
            capturedPopulatedScope = nil
            beganWithoutBodyProof = false
        }

        let isExplicitRecoveryRetry = source == .releaseCard
        let automaticRecoveryIdentity = automaticRecoveryResumeIdentityIfAllowed(source: source)
        if isExplicitRecoveryRetry, automaticRecoveryIdentity == nil {
            cancelScheduledForegroundRetry(resetBusyBudget: startsNewRetryWindow)
        }
        let legacyContinuation: SyncLegacyRecoveryContinuation?
        let reconciliation: SyncRecoveryReconciliation?
        let automaticRecoveryScope: Task126VerifiedOwnerStoreScope?
        let publishedFinalization: SyncPublishedRecoveryFinalization?
        let isAutomaticRecoveryResume: Bool
        if let automaticRecoveryIdentity {
            guard let owner = authViewModel.sessionInfo?.userID, authViewModel.isSignedIn,
                  let scope = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                    defaults: defaults, allowsPendingReplacement: true),
                  isRecoveryTimerScopeCurrent(scope) else {
                recordRuntimeDiagnostic("foreground.outcome", "recovery_scope_unavailable")
                return
            }
            automaticRecoveryScope = scope
            publishedFinalization = publishedRecoveryFinalization(identity: automaticRecoveryIdentity, scope: scope)
                .flatMap { stateStore.publishedRecoveryAttemptEligibility($0, now: now()) == .exhausted ? nil : $0 }
            let eligibility: SyncAutomaticRecoveryAttemptEligibility
            if let publishedFinalization {
                reconciliation = nil
                legacyContinuation = nil
                eligibility = stateStore.publishedRecoveryAttemptEligibility(publishedFinalization, now: now())
            } else {
                switch stateStore.recoveryReconciliationOpportunity(identity: automaticRecoveryIdentity, now: now()) {
                case .ready(let descriptor):
                    reconciliation = descriptor
                    legacyContinuation = nil
                    eligibility = .ready
                case .cooldown(let remaining):
                    reconciliation = nil
                    legacyContinuation = nil
                    eligibility = .cooldown(remaining)
                case .blocked:
                    recordRuntimeDiagnostic("foreground.outcome", "recovery_reconciliation_blocked")
                    recordRuntimeDiagnostic("foreground.reconciliationReason",
                        stateStore.recoveryReconciliationBlockReason ?? "unavailable")
                    return
                case .none:
                    reconciliation = nil
                    legacyContinuation = stateStore.legacyRecoveryContinuation(identity: automaticRecoveryIdentity, now: now())
                    eligibility = stateStore.automaticRecoveryAttemptEligibility(identity: automaticRecoveryIdentity, now: now())
                }
            }
            switch eligibility {
            case .ready:
                isAutomaticRecoveryResume = true
            case .cooldown(let remaining):
                deferForegroundCheck(source: source, forceIncremental: forceIncremental)
                if scheduleDeferredForegroundRetry(after: remaining, recoveryIdentity: automaticRecoveryIdentity) {
                    recordRuntimeDiagnostic("foreground.outcome", "recovery_resume_backoff")
                } else {
                    clearDeferredForegroundCheck()
                    recordRuntimeDiagnostic("foreground.outcome", "recovery_resume_backoff_exhausted")
                }
                return
            case .exhausted:
                guard legacyContinuation != nil else {
                    recordRuntimeDiagnostic("foreground.outcome", "recovery_resume_exhausted")
                    return
                }
                isAutomaticRecoveryResume = true
            }
        } else {
            automaticRecoveryScope = nil
            publishedFinalization = nil
            reconciliation = nil
            legacyContinuation = nil
            isAutomaticRecoveryResume = false
        }
        let isRecoveryRetry = isExplicitRecoveryRetry || isAutomaticRecoveryResume
        let completedRecoveryScope = completedRecoveryForegroundScopeIfAllowed()
        guard !Self.shouldPreserveRecoveryRequired(
            phase: stateStore.state.phase,
            source: source
        ) || isAutomaticRecoveryResume || completedRecoveryScope != nil else {
            recordRuntimeDiagnostic("foreground.outcome", "recovery_required_preserved")
            return
        }

        foregroundStartedFromRecoveryRequired = isRecoveryRetry
        let preserveRecoveryRequired = isRecoveryRetry
        let invocationID = UUID()
        let ownerScope = (authViewModel.sessionInfo?.userID).flatMap {
            try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: $0, defaults: defaults,
                allowsPendingReplacement: true, allowsPendingSameScopeRecovery: true)
        }
        let observationSource = ownerScope.flatMap {
            SyncAutomaticRunObservationSource.capture(scope: $0, defaults: defaults)
        }
        foregroundInvocationID = invocationID
        foregroundObservationSource = observationSource
        foregroundOwnerStoreScope = ownerScope
        // Install before the decision's first await. A later owner B must
        // never be replaced by A merely because A's decision finishes late.
        stateStore.beginPresentationInvocation(invocationID)
        foregroundTask = Task { @MainActor in
            let (decidedAction, hasPendingLocalChanges) = await decideAction(
                source: source,
                forceLightReconcile: forceIncremental
            )
            guard foregroundInvocationID == invocationID,
                  stateStore.ownsPresentationInvocation(invocationID) else {
                completeForegroundTask(invocationID: invocationID)
                return
            }
            guard !Task.isCancelled else {
                completeForegroundTask(invocationID: invocationID)
                return
            }
            if let automaticRecoveryScope, !isRecoveryTimerScopeCurrent(automaticRecoveryScope) {
                recordRuntimeDiagnostic("foreground.outcome", "recovery_scope_changed_before_runtime")
                completeForegroundTask(invocationID: invocationID, runDeferred: false)
                return
            }
            if let completedRecoveryScope,
               !isCompletedRecoveryForegroundScopeCurrent(completedRecoveryScope) {
                recordRuntimeDiagnostic("foreground.outcome", "completed_recovery_scope_changed")
                completeForegroundTask(invocationID: invocationID)
                return
            }
            if let capturedPopulatedScope {
                // The snapshot can finish after an account, scene or activity
                // change. Reject stale authority before recording any attempt.
                guard currentPopulatedRecoveryScope() == capturedPopulatedScope,
                      let controller = storeGenerationController else {
                    discardPopulatedQualificationWait(includingUnstartedRequest: true)
                    completeForegroundTask(invocationID: invocationID, runDeferred: false)
                    if deferredForegroundSource == .releaseCard { runDeferredForegroundCheckIfNeeded() }
                    return
                }
                if deferredForegroundSource == .releaseCard {
                    pendingPopulatedQualificationScope = nil
                    completeForegroundTask(invocationID: invocationID, runDeferred: false)
                    runDeferredForegroundCheckIfNeeded()
                    return
                }
                // Pending work still needs qualification when the decision is
                // temporarily blocked/busy. Pure bootstrap remains independent.
                if hasPendingLocalChanges,
                   beganWithoutBodyProof || !Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer) {
                    pendingPopulatedQualificationScope = capturedPopulatedScope
                    deferForegroundCheck(source: .rootForeground, forceIncremental: forceIncremental)
                    controller.requestLocalBodyQualificationAfterShopContextChange(ownerUserID: capturedPopulatedScope.ownerUserID)
                    completeForegroundTask(invocationID: invocationID, runDeferred: false)
                    scheduleLocalQualificationReadback()
                    return
                }
                guard !beganWithoutBodyProof || currentScenePhase == .active else {
                    completeForegroundTask(invocationID: invocationID, runDeferred: false)
                    return
                }
                if activityCenter.blocksAutomaticSync || automaticRuntime.isRunning || decidedAction == .retryAfterBusy {
                    deferForegroundCheck(source: source, forceIncremental: forceIncremental)
                    completeForegroundTask(invocationID: invocationID, runDeferred: false)
                    if !activityCenter.blocksAutomaticSync, !automaticRuntime.isRunning {
                        resumeDeferredForegroundCheckIfReady()
                    }
                    return
                }
            }
            // Every admitted recovery source retains the same gated plan.
            // Phase reconciliation and terminal finalization own fullRecovery.
            let action: SyncAction
            if legacyContinuation != nil || reconciliation != nil || publishedFinalization != nil {
                switch decidedAction {
                case .blocked, .retryAfterBusy: action = decidedAction
                default: action = .fullRecovery
                }
            } else {
                action = isExplicitRecoveryRetry && !isAutomaticRecoveryResume
                    ? Self.explicitRecoveryAction(afterGates: decidedAction) : decidedAction
            }
            stateStore.recordDecision(trigger: source.syncTrigger, action: action,
                presentationInvocationID: invocationID)
            switch action {
            case .blocked(let reason):
                stateStore.recordRunResult(
                    observationSource?.completed(.blocked(reason), now: now()) ?? .blocked(reason),
                    preserveRecoveryRequired: preserveRecoveryRequired,
                    presentationInvocationID: invocationID
                )
                recordRuntimeDiagnostic("foreground.outcome", "blocked_\(reason)")
                completeForegroundTask(invocationID: invocationID)
                return
            case .retryAfterBusy:
                deferForegroundCheck(source: source, forceIncremental: forceIncremental)
                let retryDelay: TimeInterval = 2
                completeBusyForegroundAttempt(
                    source: source,
                    preserveRecoveryRequired: preserveRecoveryRequired,
                    requestedDelay: retryDelay, invocationID: invocationID,
                    diagnostic: "deferred_decision_busy"
                )
                return
            case .noOp:
                stateStore.recordRunResult(
                    observationSource?.completed(.noWork(), now: now()) ?? .noWork(),
                    preserveRecoveryRequired: preserveRecoveryRequired,
                    presentationInvocationID: invocationID
                )
                recordRuntimeDiagnostic("foreground.outcome", "decision_noop")
                completeForegroundTask(invocationID: invocationID)
                return
            case .pushPending, .drainEvents, .lightReconcile, .bootstrap, .fullRecovery, .requestRecovery, .sequence:
                stateStore.updatePhase(action.runningPhase, presentationInvocationID: invocationID)
            }
            recordRuntimeDiagnostic("foreground.outcome", action.diagnosticsScheduleName)
            let progressInvocationID = stateStore.beginRecoveryProgressReporting(presentationInvocationID: invocationID)
            let recoveryInvocation = ForegroundRecoveryInvocation()
            let beginPublishedFinalization: (@Sendable () async -> SyncPublishedRecoveryAdmission)?
            if let terminal = publishedFinalization, let automaticRecoveryScope {
                beginPublishedFinalization = { @Sendable [weak orchestrator = self] in
                    await MainActor.run { [weak orchestrator] in
                        guard let orchestrator, !orchestrator.isStopped,
                              orchestrator.foregroundInvocationID == invocationID,
                              orchestrator.stateStore.ownsPresentationInvocation(invocationID),
                              orchestrator.isRecoveryTimerScopeCurrent(automaticRecoveryScope),
                              orchestrator.publishedRecoveryFinalization(identity: terminal.identity,
                                scope: automaticRecoveryScope) == terminal else { return .rejected }
                        let admission = orchestrator.stateStore.admitPublishedRecoveryAttempt(terminal, now: orchestrator.now())
                        recoveryInvocation.claim = admission.claim
                        return admission.admission
                    }
                }
            } else { beginPublishedFinalization = nil }
            let beginAttempt: (@Sendable () async -> Bool)?
            if publishedFinalization == nil, let identity = automaticRecoveryIdentity {
                beginAttempt = { @Sendable [weak orchestrator = self] in
                    await MainActor.run { [weak orchestrator] in
                        guard let orchestrator, !orchestrator.isStopped, orchestrator.foregroundInvocationID == invocationID,
                              orchestrator.stateStore.ownsPresentationInvocation(invocationID),
                              let automaticRecoveryScope else { return false }
                        if orchestrator.stateStore.pendingRecoveryJournal == nil {
                            // A same-entity finalizer may retire the journal
                            // after the decision and before engine admission.
                            // This is ordinary current-generation work, never
                            // a new claim or reset of the retired journal.
                            guard orchestrator.isRecoveryCompletionEntityCurrent(automaticRecoveryScope, verifiedConvergence: true),
                                  let fresh = try? Task126OwnerStoreGate.captureAutomaticScope(
                                    ownerUserID: automaticRecoveryScope.ownerUserID, defaults: orchestrator.defaults),
                                  orchestrator.isCompletedRecoveryForegroundScopeCurrent(fresh) else { return false }
                            return true
                        }
                        guard orchestrator.isRecoveryTimerScopeCurrent(automaticRecoveryScope),
                              orchestrator.stateStore.pendingRecoveryJournal.map(Self.automaticRecoveryResumeIdentity(for:)) == identity else { return false }
                        recoveryInvocation.claim = orchestrator.stateStore.claimAutomaticRecoveryAttempt(identity: identity,
                            now: orchestrator.now(), legacyContinuation: legacyContinuation, reconciliation: reconciliation)
                        return recoveryInvocation.claim != nil
                    }
                }
            } else {
                beginAttempt = nil
            }
            guard foregroundInvocationID == invocationID,
                  stateStore.ownsPresentationInvocation(invocationID) else {
                completeForegroundTask(invocationID: invocationID)
                return
            }
            let result = await AutomaticSyncAttemptContext.$publishedFinalization.withValue(publishedFinalization) {
                await AutomaticSyncAttemptContext.$beginPublishedFinalization.withValue(beginPublishedFinalization) {
                    await AutomaticSyncAttemptContext.$legacyContinuation.withValue(legacyContinuation) {
                        await AutomaticSyncAttemptContext.$reconciliation.withValue(reconciliation) {
                            await AutomaticSyncAttemptContext.$begin.withValue(beginAttempt) {
                                await SyncRecoveryProgressContext.$invocationID.withValue(progressInvocationID) {
                                    await automaticRuntime.run(action: action, source: source)
                                }
                            }
                        }
                    }
                }
            }
            var recoveryCompletionAccepted = false
            defer {
                // Settled stale work releases its live claim, never another entity's retry metadata.
                let mayPersistMetadata = recoveryCompletionAccepted
                    && (automaticRecoveryScope.map {
                        isRecoveryCompletionEntityCurrent($0, verifiedConvergence: result.verifiedConvergence)
                    } ?? false)
                if let claim = recoveryInvocation.claim {
                    stateStore.releaseAutomaticRecoveryAttempt(claim, now: now(),
                        allowsPersistentMetadata: mayPersistMetadata)
                }
                if mayPersistMetadata, let automaticRecoveryIdentity {
                    stateStore.completeRecoveryReconciliationIfJournalRetired(identity: automaticRecoveryIdentity,
                        finalization: result.verifiedFinalization, now: now())
                }
            }
            guard foregroundInvocationID == invocationID,
                  stateStore.ownsPresentationInvocation(invocationID) else {
                completeForegroundTask(invocationID: invocationID)
                return
            }
            let completionAuthority: (@MainActor @Sendable () -> Bool)?
            if let scope = automaticRecoveryScope {
                completionAuthority = { @MainActor @Sendable [weak orchestrator = self] in
                    orchestrator?.isRecoveryCompletionEntityCurrent(scope, verifiedConvergence: result.verifiedConvergence) ?? false
                }
            } else {
                completionAuthority = nil
            }
            guard completionAuthority?() != false else {
                recordRuntimeDiagnostic("foreground.outcome", "recovery_completion_entity_changed")
                completeForegroundTask(invocationID: invocationID)
                return
            }
            if let claim = recoveryInvocation.claim, !stateStore.ownsAutomaticRecoveryAttempt(claim) {
                recordRuntimeDiagnostic("foreground.outcome", "stale_recovery_completion_ignored")
                completeForegroundTask(invocationID: invocationID)
                return
            }
            recoveryCompletionAccepted = true
            if result.status == .cancelled, let claim = recoveryInvocation.claim,
               let identity = automaticRecoveryIdentity, let scope = automaticRecoveryScope,
               let terminal = publishedRecoveryFinalization(identity: identity, scope: scope),
               let origin = observationSource?.origin,
               (origin.generationID != terminal.generationID || publishedFinalization == terminal) {
                // Actual cancellation is bookkeeping only. Publication has
                // invalidated the old physical lease, never the new authority.
                // Do not pass its old-origin observation into presentation.
                let recorded = stateStore.recordPublishedRecoveryCancellation(claim, now: now())
                if recorded, origin.generationID == terminal.generationID {
                    // A terminal retry did not change generation. Its actual
                    // current-origin cancellation may retain the recovery UI
                    // latch; no old-origin observation is admitted above.
                    stateStore.recordRunResult(result, preserveRecoveryRequired: true,
                        presentationInvocationID: invocationID, automaticRecoveryAuthority: completionAuthority, now: now())
                    if !Task.isCancelled,
                       case .cooldown(let remaining) = stateStore.publishedRecoveryAttemptEligibility(terminal, now: now()) {
                        deferForegroundCheck(source: source, forceIncremental: forceIncremental)
                        if !scheduleDeferredForegroundRetry(after: remaining, recoveryIdentity: identity) {
                            clearDeferredForegroundCheck()
                        }
                    }
                }
                completeForegroundTask(invocationID: invocationID, runDeferred: false)
                return
            }
            guard !Task.isCancelled || result.verifiedConvergence else {
                completeForegroundTask(invocationID: invocationID)
                return
            }
            stateStore.recordRunResult(
                result,
                preserveRecoveryRequired: preserveRecoveryRequired,
                presentationInvocationID: invocationID,
                automaticRecoveryClaim: recoveryInvocation.claim,
                automaticRecoveryAuthority: completionAuthority, now: now()
            )
            guard completionAuthority?() != false else {
                completeForegroundTask(invocationID: invocationID)
                return
            }
            guard foregroundInvocationID == invocationID else { return }
            if result.status == .busy || result.status == .scheduledRetry {
                stateStore.abandonPresentationInvocation(invocationID)
                deferForegroundCheck(source: source, forceIncremental: forceIncremental)
                var requestedDelay = result.scheduledRetryAfter ?? 2
                if publishedFinalization == nil, let automaticRecoveryIdentity, stateStore.recoveryJournalIsPending {
                    requestedDelay = stateStore.extendAutomaticRecoveryAttemptCooldown(
                        identity: automaticRecoveryIdentity,
                        requestedDelay: requestedDelay, now: now()
                    )
                }
                if scheduleDeferredForegroundRetry(after: requestedDelay,
                    recoveryIdentity: publishedFinalization != nil || reconciliation != nil ? automaticRecoveryIdentity : nil) {
                    recordRuntimeDiagnostic("foreground.outcome", "deferred_runtime_busy")
                } else {
                    clearDeferredForegroundCheck()
                    stateStore.recordRunResult(
                        observationSource?.completed(.failed(errorCode: "sync_busy_retry_exhausted"), now: now())
                            ?? .failed(errorCode: "sync_busy_retry_exhausted"),
                        preserveRecoveryRequired: preserveRecoveryRequired
                    )
                    recordRuntimeDiagnostic("foreground.outcome", "busy_retry_exhausted")
                }
                completeForegroundTask(invocationID: invocationID, runDeferred: false)
                return
            }
            resetForegroundBusyRetryBudget()
            if let automaticRecoveryIdentity, stateStore.recoveryJournalIsPending,
               case .cooldown(let remaining) = recoveryRetryEligibility(identity: automaticRecoveryIdentity,
                    publishedFinalization: publishedFinalization) {
                deferForegroundCheck(source: source, forceIncremental: forceIncremental)
                if scheduleDeferredForegroundRetry(after: remaining, recoveryIdentity: automaticRecoveryIdentity) {
                    recordRuntimeDiagnostic("foreground.outcome", "recovery_transient_retry_scheduled")
                } else {
                    clearDeferredForegroundCheck()
                }
                completeForegroundTask(invocationID: invocationID, runDeferred: false)
                return
            }
            completeForegroundTask(invocationID: invocationID)
        }
    }

    func cancelForegroundCheck() {
        pendingPopulatedQualificationScope = nil
        let preserveRecoveryRequired = foregroundStartedFromRecoveryRequired
            && !isAccountStoreReplacementInProgress
        clearDeferredForegroundCheck()
        cancelScheduledForegroundRetry()
        automaticRuntime.cancel()
        foregroundTask?.cancel()
        if stateStore.state.phase.isAutomaticWorkActive {
            stateStore.recordCancellationRequest(presentationInvocationID: foregroundInvocationID,
                preserveRecoveryRequired: preserveRecoveryRequired, now: now())
        }
        if let scope = foregroundOwnerStoreScope,
           !isRecoveryCompletionEntityCurrent(scope, verifiedConvergence: false),
           let invocationID = foregroundInvocationID {
            // A different entity revokes A. A same-entity durable generation
            // change alone does not surrender its held operation claim.
            stateStore.abandonPresentationInvocation(invocationID)
        }
        foregroundStartedFromRecoveryRequired = false
        objectWillChange.send()
    }

    /// Closes automatic-sync admission, waits for every already-started
    /// provider (including detached ModelContext work), performs the local
    /// transaction, then resumes with one fresh owner/shop decision.
    func performAccountStoreReplacement(
        _ operation: @MainActor () throws -> AccountStoreReplacementResult
    ) async throws -> AccountStoreReplacementResult {
        guard !isAccountStoreReplacementInProgress else {
            throw AccountStoreReplacementRuntimeError.alreadyInProgress
        }
        isAccountStoreReplacementInProgress = true
        pendingPopulatedQualificationScope = nil
        foregroundStartedFromRecoveryRequired = false
        stateStore.reconcilePendingRecoveryJournal()
        objectWillChange.send()

        let runningTask = foregroundTask
        runningTask?.cancel()
        await automaticRuntime.cancelAndWait()
        if let runningTask {
            await runningTask.value
        }
        if let invocationID = foregroundInvocationID {
            stateStore.abandonPresentationInvocation(invocationID)
        }
        foregroundTask = nil
        foregroundInvocationID = nil
        foregroundOwnerStoreScope = nil

        do {
            let result = try operation()
            await finishAccountStoreReplacementAndResumeSync()
            return result
        } catch {
            await finishAccountStoreReplacementAndResumeSync()
            throw error
        }
    }

    private func finishAccountStoreReplacementAndResumeSync() async {
        await automaticRuntime.resumeAfterStoreReplacement()
        isAccountStoreReplacementInProgress = false
        stateStore.reconcilePendingRecoveryJournal()
        deferForegroundCheck(
            source: stateStore.recoveryJournalIsPending
                ? .releaseCard
                : .rootForeground,
            forceIncremental: true
        )
        objectWillChange.send()
        runDeferredForegroundCheckIfNeeded()
    }

    private func syncAuthPresentationContext() {
        authViewModel.refreshCurrentSessionSnapshot()
        recordRuntimeDiagnostic("auth.isSignedIn", authViewModel.isSignedIn)
        recordRuntimeDiagnostic("auth.canSignIn", authViewModel.canSignIn)
        recordRuntimeDiagnostic("auth.isTransitioning", authViewModel.isTransitioning)
        recordRuntimeDiagnostic("auth.userIDPresent", authViewModel.sessionInfo?.userID != nil)
        objectWillChange.send()
    }

    private func startReconnectObserverIfNeeded() {
        guard reconnectScheduler == nil,
              reconnectObserver == nil else { return }
        let scheduler = AutomaticSyncReconnectScheduler { [weak self] in
            self?.backgroundScheduler.schedule(reason: .networkReconnect)
            self?.submitForegroundTrigger(source: .networkReconnect, forceIncremental: true)
        }
        scheduler.setForeground(currentScenePhase == .active)
        let decisionInputProvider = decisionInputProvider
        let observer = AutomaticSyncNetworkReachabilityObserver(
            scheduler: scheduler,
            statusHandler: { status in
                Task {
                    await decisionInputProvider.updateNetworkStatus(status)
                }
            }
        )
        observer.start()
        reconnectScheduler = scheduler
        reconnectObserver = observer
    }

    private func startSyncEventSafetyLoopIfNeeded() {
        guard syncEventSafetyLoopTask == nil else { return }
        syncEventSafetyLoopTask = Task { @MainActor [weak self] in
            let intervalSeconds = 30
            let intervalNanoseconds = UInt64(intervalSeconds) * 1_000_000_000
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                guard !Task.isCancelled,
                      let self else { break }
                self.stateStore.recordSafetyLoopTick()
                self.recordRuntimeDiagnostic("timer.intervalSeconds", intervalSeconds)
                self.recordRuntimeDiagnostic("timer.lastTickAt", Date().timeIntervalSince1970)
                self.recordRuntimeDiagnostic("timer.didReachInteractiveUI", self.didReachInteractiveUI)
                self.recordRuntimeDiagnostic("timer.sceneActive", self.currentScenePhase == .active)
                self.recordRuntimeDiagnostic("timer.sceneBackground", self.currentScenePhase == .background)
                guard self.didReachInteractiveUI,
                      self.currentScenePhase != .background else { continue }
                self.syncAuthPresentationContext()
                self.updateSyncEventSignalWatcher()
                self.recordRuntimeDiagnostic("timer.isSignedIn", self.authViewModel.isSignedIn)
                guard self.authViewModel.isSignedIn else { continue }
                self.submitForegroundTrigger(source: .foregroundPoll, forceIncremental: true)
            }
            self?.syncEventSafetyLoopTask = nil
        }
    }

    private func stopSyncEventSafetyLoop() {
        syncEventSafetyLoopTask?.cancel()
        syncEventSafetyLoopTask = nil
    }

    private func updateSyncEventSignalWatcher() {
        recordRuntimeDiagnostic("watcher.updateAt", Date().timeIntervalSince1970)
        guard didReachInteractiveUI,
              currentScenePhase != .background,
              authViewModel.isSignedIn,
              let ownerUserID = authViewModel.sessionInfo?.userID,
              let scope = try? Task126OwnerStoreGate.captureAutomaticScope(
                ownerUserID: ownerUserID
              ) else {
            recordRuntimeDiagnostic("watcher.state", "stopped")
            syncEventSignalWatcher?.stop()
            return
        }
        recordRuntimeDiagnostic("watcher.state", "started")
        syncEventSignalWatcher?.start(
            ownerUserID: ownerUserID,
            selectedShopID: scope.shopID
        ) { [weak self] in
            self?.recordRuntimeDiagnostic("watcher.signalAt", Date().timeIntervalSince1970)
            if let provider = self?.decisionInputProvider {
                Task {
                    await provider.recordRealtimeEvent()
                }
            }
            self?.submitForegroundTrigger(source: .remoteSyncEvent, forceIncremental: true)
        }
    }

    private func deferForegroundCheck(
        source: SyncAutomaticTriggerSource,
        forceIncremental: Bool,
        startsNewRetryWindow: Bool = false
    ) {
        var preferredSource = Self.preferredDeferredSource(
            current: deferredForegroundSource,
            incoming: source
        )
        // A Save or safety poll during editing must not demote an already
        // qualified ordinary recovery request to a source that cannot resume it.
        // Retain it only while the complete mounted authority remains current.
        if source == .localMutation || source == .foregroundPoll, hasDeferredForegroundCheck,
           let pendingSource = deferredForegroundSource,
           pendingSource == .rootForeground || pendingSource == .networkReconnect,
           !isStopped, authViewModel.isSignedIn, !authViewModel.isTransitioning,
           let owner = authViewModel.sessionInfo?.userID,
           authViewModel.localMutationOwnerUserID == owner,
           let controller = storeGenerationController, let lease = storeGenerationLease,
           (try? controller.validateLease(lease)) != nil,
           let manifest = controller.activeManifest,
           let journal = stateStore.pendingRecoveryJournal,
           journal.mode == .sameScopeRecovery,
           let scope = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
             defaults: defaults, allowsPendingSameScopeRecovery: true),
           scope.accountHash == manifest.accountHash,
           scope.shopID == manifest.shopID,
           scope.storeIdentity == manifest.storeIdentity,
           scope.deviceIdentityHash == manifest.deviceIdentityHash,
           scope.pendingReplacement == journal.replacement,
           Task126OwnerStoreGate.permitsSameScopeLocalAccess(
             modelContainer: controller.modelContainer, ownerUserID: owner, defaults: defaults
           ) {
            preferredSource = pendingSource
        }
        hasDeferredForegroundCheck = true
        deferredForegroundSource = preferredSource
        deferredForegroundForceIncremental = deferredForegroundForceIncremental || forceIncremental
        deferredStartsNewRetryWindow = deferredStartsNewRetryWindow || startsNewRetryWindow
    }

    static func preferredDeferredSource(
        current: SyncAutomaticTriggerSource?,
        incoming: SyncAutomaticTriggerSource
    ) -> SyncAutomaticTriggerSource {
        if current == .releaseCard || incoming == .releaseCard {
            return .releaseCard
        }
        return incoming
    }

    private func clearDeferredForegroundCheck() {
        hasDeferredForegroundCheck = false
        deferredForegroundSource = nil
        deferredForegroundForceIncremental = false
        deferredStartsNewRetryWindow = false
    }

    private func completeBusyForegroundAttempt(
        source: SyncAutomaticTriggerSource,
        preserveRecoveryRequired: Bool,
        requestedDelay: TimeInterval,
        invocationID: UUID,
        diagnostic: String
    ) {
        guard foregroundInvocationID == invocationID else { return }
        let scheduled = scheduleDeferredForegroundRetry(after: requestedDelay)
        stateStore.recordRunResult(
            foregroundObservationSource?.completed(scheduled
                ? .scheduledRetry(after: requestedDelay)
                : .failed(errorCode: "sync_busy_retry_exhausted"), now: now())
                ?? (scheduled ? .scheduledRetry(after: requestedDelay) : .failed(errorCode: "sync_busy_retry_exhausted")),
            preserveRecoveryRequired: preserveRecoveryRequired,
            presentationInvocationID: invocationID
        )
        recordRuntimeDiagnostic(
            "foreground.outcome",
            scheduled ? diagnostic : "busy_retry_exhausted"
        )
        if !scheduled {
            clearDeferredForegroundCheck()
        }
        completeForegroundTask(invocationID: invocationID, runDeferred: false)
    }

    private func scheduleDeferredForegroundRetry(after requestedDelay: TimeInterval,
        recoveryIdentity: String? = nil) -> Bool {
        guard requestedDelay.isFinite, requestedDelay >= 0 else { return false }
        if scheduledForegroundRetryTask != nil {
            // Repeated foreground/reconnect signals share the existing timer
            // and must not erase the deferred request that it will execute.
            return recoveryIdentity != nil && scheduledForegroundRetryIdentity == recoveryIdentity
        }
        let capturedScope: Task126VerifiedOwnerStoreScope?
        if let recoveryIdentity {
            guard let owner = authViewModel.sessionInfo?.userID, authViewModel.isSignedIn,
                  let scope = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                    defaults: defaults, allowsPendingReplacement: true),
                  automaticRecoveryResumeIdentityIfAllowed(source: .rootForeground) == recoveryIdentity,
                  isRecoveryTimerScopeCurrent(scope) else { return false }
            capturedScope = scope
        } else {
            guard foregroundBusyRetryAttempt < maximumForegroundBusyRetryAttempts else { return false }
            capturedScope = nil
        }
        let delaySeconds: TimeInterval
        if recoveryIdentity != nil {
            delaySeconds = requestedDelay
        } else {
            delaySeconds = min(requestedDelay * pow(2, Double(foregroundBusyRetryAttempt)), 30)
            foregroundBusyRetryAttempt += 1
        }
        let token = UUID()
        scheduledForegroundRetryToken = token
        scheduledForegroundRetryIdentity = recoveryIdentity
        let delay = foregroundRetryDelay
        let recoveryDeadline = recoveryIdentity == nil ? nil : now().addingTimeInterval(delaySeconds)
        let monotonicDeadline = recoveryIdentity == nil ? nil : monotonicNow() + delaySeconds
        guard monotonicDeadline?.isFinite ?? true else {
            scheduledForegroundRetryToken = nil
            scheduledForegroundRetryIdentity = nil
            return false
        }
        scheduledForegroundRetryTask = Task { @MainActor [weak self] in
            if let recoveryDeadline {
                while true {
                    guard !Task.isCancelled, let self, self.scheduledForegroundRetryToken == token else { return }
                    guard let capturedScope, let recoveryIdentity,
                          self.automaticRecoveryResumeIdentityIfAllowed(source: .rootForeground) == recoveryIdentity,
                          self.currentScenePhase != .background,
                          self.isRecoveryTimerScopeCurrent(capturedScope) else {
                        self.cancelScheduledForegroundRetry()
                        self.clearDeferredForegroundCheck()
                        return
                    }
                    guard let monotonicDeadline else { return }
                    let monotonicTime = self.monotonicNow()
                    guard monotonicTime.isFinite else {
                        self.cancelScheduledForegroundRetry()
                        self.clearDeferredForegroundCheck()
                        return
                    }
                    let remaining = max(recoveryDeadline.timeIntervalSince(self.now()), monotonicDeadline - monotonicTime)
                    guard remaining > 0 else { break }
                    // The persisted UTC/server due remains unchanged. The
                    // active monotonic floor is captured once, so a wall-clock
                    // jump cannot shorten it and each sleep stays bounded.
                    await delay(min(remaining, 300))
                }
            } else {
                await delay(delaySeconds)
            }
            guard !Task.isCancelled, let self, self.scheduledForegroundRetryToken == token else { return }
            self.scheduledForegroundRetryTask = nil
            self.scheduledForegroundRetryToken = nil
            self.scheduledForegroundRetryIdentity = nil
            if let capturedScope, let recoveryIdentity {
                guard self.automaticRecoveryResumeIdentityIfAllowed(source: .rootForeground) == recoveryIdentity,
                      self.currentScenePhase != .background,
                      self.isRecoveryTimerScopeCurrent(capturedScope) else {
                    self.clearDeferredForegroundCheck()
                    return
                }
            }
            self.runDeferredForegroundCheckIfNeeded()
        }
        return true
    }

    private func recoveryRetryEligibility(identity: String,
        publishedFinalization: SyncPublishedRecoveryFinalization?) -> SyncAutomaticRecoveryAttemptEligibility {
        if let publishedFinalization {
            return stateStore.publishedRecoveryAttemptEligibility(publishedFinalization, now: now())
        }
        switch stateStore.recoveryReconciliationOpportunity(identity: identity, now: now()) {
        case .ready: return .ready
        case .cooldown(let remaining): return .cooldown(remaining)
        case .blocked: return .exhausted
        case .none: return stateStore.automaticRecoveryAttemptEligibility(identity: identity, now: now())
        }
    }

    /// Read-only current publication qualification. In the cancelled callback
    /// the old physical lease is intentionally NOT resurrected; the mounted
    /// controller's current body and logical authority must qualify instead.
    private func publishedRecoveryFinalization(identity: String,
        scope: Task126VerifiedOwnerStoreScope) -> SyncPublishedRecoveryFinalization? {
        guard isRecoveryCompletionEntityCurrent(scope, verifiedConvergence: false),
              let controller = storeGenerationController, controller.loadFailureCode == nil,
              let manifest = controller.activeManifest, let journal = stateStore.pendingRecoveryJournal,
              Self.automaticRecoveryResumeIdentity(for: journal) == identity,
              manifest.accountHash == scope.accountHash, manifest.shopID == scope.shopID,
              manifest.storeIdentity.hasSameProvenance(as: scope.storeIdentity),
              manifest.deviceIdentityHash == scope.deviceIdentityHash,
              Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: controller.modelContainer,
                ownerUserID: scope.ownerUserID, defaults: defaults) else { return nil }
        let descriptor = SyncPublishedRecoveryFinalization(identity: identity, generationID: manifest.generationID,
            checkpointDigest: manifest.checkpoint.checkpointDigest, baselineRunID: manifest.baselineRunID)
        return descriptor.matches(manifest: manifest, journal: journal) ? descriptor : nil
    }

    private func isRecoveryTimerScopeCurrent(_ scope: Task126VerifiedOwnerStoreScope) -> Bool {
        guard !isStopped, authViewModel.isSignedIn, authViewModel.sessionInfo?.userID == scope.ownerUserID,
              let current = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: scope.ownerUserID,
                defaults: defaults, allowsPendingReplacement: true), current == scope,
              !SelectedShopStore(defaults: defaults).hasConfirmedDeviceDenial(accountHash: scope.accountHash,
                shopID: scope.shopID, deviceIdentityHash: scope.deviceIdentityHash) else { return false }
        if let storeGenerationController {
            guard let storeGenerationLease,
                  (try? storeGenerationController.validateLease(storeGenerationLease)) != nil else { return false }
        }
        return true
    }

    /// A committed recovery replaces its physical lease and clears its
    /// journal. Verify the current entity, not the retired pre-run lease, and
    /// do not turn cancellation into loss of a legitimate durable completion.
    private func isRecoveryCompletionEntityCurrent(_ scope: Task126VerifiedOwnerStoreScope,
        verifiedConvergence: Bool) -> Bool {
        let selection = SelectedShopStore(defaults: defaults)
        let binding = AccountBindingStore(defaults: defaults)
        guard !isStopped, authViewModel.isSignedIn, !authViewModel.isTransitioning,
              authViewModel.sessionInfo?.userID == scope.ownerUserID,
              authViewModel.localMutationOwnerUserID == scope.ownerUserID,
              defaults.string(forKey: "mobile.shopContext.activeAccountHash.v1") == scope.accountHash,
              selection.isResolutionReady(accountHash: scope.accountHash),
              let shop = selection.selectedShop(accountHash: scope.accountHash),
              shop.shopID == scope.shopID, shop.localStoreIdentity.hasSameProvenance(as: scope.storeIdentity),
              LinkedShop(shopID: shop.shopID, code: shop.code, name: shop.name, role: shop.role,
                status: shop.status, selectable: shop.selectable, canWrite: shop.canWrite).isValidSelection,
              let currentBinding = binding.currentBinding,
              currentBinding.accountHash == scope.accountHash,
              currentBinding.storeIdentity.hasSameProvenance(as: scope.storeIdentity),
              let device = try? DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID(),
              device == scope.deviceInstallID, DeviceInstallIDStore.identityHash(for: device) == scope.deviceIdentityHash,
              !selection.hasConfirmedDeviceDenial(accountHash: scope.accountHash,
                shopID: scope.shopID, deviceIdentityHash: scope.deviceIdentityHash) else { return false }
        guard verifiedConvergence else { return true }
        guard !binding.hasPendingReplacementJournal,
              let controller = storeGenerationController, let manifest = controller.activeManifest,
              manifest.accountHash == scope.accountHash, manifest.shopID == scope.shopID,
              manifest.storeIdentity.hasSameProvenance(as: scope.storeIdentity),
              manifest.deviceIdentityHash == scope.deviceIdentityHash,
              (try? controller.isActiveRecoveryFinalized(scope: scope)) == true,
              Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: controller.modelContainer,
                ownerUserID: scope.ownerUserID, defaults: defaults) else { return false }
        return true
    }

    private func cancelScheduledForegroundRetry(resetBusyBudget: Bool = true) {
        scheduledForegroundRetryTask?.cancel()
        scheduledForegroundRetryTask = nil
        scheduledForegroundRetryToken = nil
        scheduledForegroundRetryIdentity = nil
        if resetBusyBudget { foregroundBusyRetryAttempt = 0 }
    }

    private func resetForegroundBusyRetryBudget() {
        cancelScheduledForegroundRetry()
    }

    private func runDeferredForegroundCheckIfNeeded() {
        guard !isStopped, hasDeferredForegroundCheck else { return }
        if pendingPopulatedQualificationScope != nil {
            scheduleLocalQualificationReadback()
            return
        }
        let source = deferredForegroundSource ?? .rootForeground
        let forceIncremental = deferredForegroundForceIncremental
        let startsNewRetryWindow = deferredStartsNewRetryWindow
        clearDeferredForegroundCheck()
        requestForegroundTrigger(source: source, forceIncremental: forceIncremental,
            isDeferredReplay: !startsNewRetryWindow)
    }

    private func completeForegroundTask(invocationID: UUID, runDeferred: Bool = true) {
        guard foregroundInvocationID == invocationID else { return }
        backgroundScheduler.schedule(reason: .foregroundCompletion)
        stateStore.abandonPresentationInvocation(invocationID)
        foregroundTask = nil
        foregroundInvocationID = nil
        foregroundObservationSource = nil
        foregroundOwnerStoreScope = nil
        foregroundStartedFromRecoveryRequired = false
        objectWillChange.send()
        if runDeferred, !isStopped {
            runDeferredForegroundCheckIfNeeded()
        }
    }

    private func decideAction(
        source: SyncAutomaticTriggerSource,
        forceLightReconcile: Bool
    ) async -> (action: SyncAction, hasPendingLocalChanges: Bool) {
        let snapshot = await decisionInputProvider.makeSnapshot(
            triggerSource: source,
            isAuthenticated: authViewModel.isSignedIn,
            ownerUserID: authViewModel.sessionInfo?.userID,
            isSyncBusy: activityCenter.blocksAutomaticSync || automaticRuntime.isRunning
        )
        let action = SyncDecisionEngine.decide(snapshot.input)
        // A foreground safety/reconnect request must reach the server-side
        // checkpoint even when the local decision snapshot looks idle. Gates,
        // bootstrap and pending work retain precedence; only a local no-op is
        // upgraded to the bounded reconciliation path.
        if forceLightReconcile, action == .noOp {
            return (.lightReconcile, snapshot.hasPendingLocalChanges)
        }
        return (action, snapshot.hasPendingLocalChanges)
    }

    private func currentPopulatedRecoveryScope() -> Task126VerifiedOwnerStoreScope? {
        guard !isStopped, !isAccountStoreReplacementInProgress,
              authViewModel.isSignedIn, !authViewModel.isTransitioning,
              let owner = authViewModel.sessionInfo?.userID,
              authViewModel.localMutationOwnerUserID == owner,
              let controller = storeGenerationController, let lease = storeGenerationLease,
              (try? controller.validateLease(lease)) != nil,
              let manifest = controller.activeManifest,
              let journal = stateStore.pendingRecoveryJournal,
              journal.mode == .sameScopeRecovery,
              let scope = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner,
                defaults: defaults, allowsPendingSameScopeRecovery: true),
              scope.accountHash == manifest.accountHash,
              scope.shopID == manifest.shopID,
              scope.storeIdentity == manifest.storeIdentity,
              scope.deviceIdentityHash == manifest.deviceIdentityHash,
              scope.pendingReplacement == journal.replacement else { return nil }
        return scope
    }

    private func discardPopulatedQualificationWait(includingUnstartedRequest: Bool = false) {
        guard pendingPopulatedQualificationScope != nil || includingUnstartedRequest else { return }
        pendingPopulatedQualificationScope = nil
        if deferredForegroundSource != .releaseCard {
            clearDeferredForegroundCheck()
        }
    }

    static func retryTriggerSource(for phase: SyncPhase) -> SyncAutomaticTriggerSource {
        phase == .recoveryRequired ? .releaseCard : .rootForeground
    }

    static func shouldPreserveRecoveryRequired(
        phase: SyncPhase,
        source: SyncAutomaticTriggerSource
    ) -> Bool {
        phase == .recoveryRequired && source != .releaseCard
    }

    static func allowsAutomaticRecoveryResume(
        source: SyncAutomaticTriggerSource,
        hasDecodableJournal: Bool
    ) -> Bool {
        hasDecodableJournal && (source == .rootForeground || source == .networkReconnect || source == .releaseCard)
    }

    private func automaticRecoveryResumeIdentityIfAllowed(
        source: SyncAutomaticTriggerSource
    ) -> String? {
        guard !isStopped,
              stateStore.state.phase == .recoveryRequired,
              let journal = stateStore.pendingRecoveryJournal,
              Self.allowsAutomaticRecoveryResume(
                source: source,
                hasDecodableJournal: true
              ) else { return nil }
        return Self.automaticRecoveryResumeIdentity(for: journal)
    }

    /// A remounted root may inherit recoveryRequired after the previous root's
    /// run was cancelled. Only its own finalized, physically qualified current
    /// generation may enter the ordinary decision path without another journal.
    private func completedRecoveryForegroundScopeIfAllowed() -> Task126VerifiedOwnerStoreScope? {
        guard !isStopped, !stateStore.recoveryJournalIsPending,
              stateStore.state.phase == .recoveryRequired,
              let ownerUserID = authViewModel.sessionInfo?.userID,
              let scope = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: ownerUserID, defaults: defaults),
              isCompletedRecoveryForegroundScopeCurrent(scope) else { return nil }
        return scope
    }

    private func isCompletedRecoveryForegroundScopeCurrent(
        _ scope: Task126VerifiedOwnerStoreScope
    ) -> Bool {
        guard !Task.isCancelled, authViewModel.isSignedIn, !authViewModel.isTransitioning,
              authViewModel.sessionInfo?.userID == scope.ownerUserID,
              scope.pendingReplacement == nil, !stateStore.recoveryJournalIsPending,
              let storeGenerationController, let storeGenerationLease else { return false }
        do {
            try storeGenerationController.validateLease(storeGenerationLease)
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
            guard try storeGenerationController.isActiveRecoveryFinalized(scope: scope),
                  Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                    modelContainer: storeGenerationController.modelContainer,
                    ownerUserID: scope.ownerUserID, defaults: defaults
                  ) else { return false }
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
            try storeGenerationController.validateLease(storeGenerationLease)
            return !Task.isCancelled && !stateStore.recoveryJournalIsPending
        } catch {
            return false
        }
    }

    static func automaticRecoveryResumeIdentity(
        for journal: AccountRecoveryJournalSnapshot
    ) -> String {
        AccountBindingStore.redactedAccountHash(for: [
            journal.replacement.accountHash,
            journal.replacement.storeIdentity.rawValue,
            journal.replacement.storeIdentity.defaultStoreId,
            journal.replacement.storeIdentity.localStoreId,
            String(journal.replacement.storeIdentity.schemaVersion),
            String(journal.replacement.storeIdentity.syncProtocolVersion),
            String(journal.replacement.storeIdentity.storeEpoch),
            journal.deviceIdentityHash,
            journal.mode.rawValue,
            String(
                journal.replacement.boundAt.timeIntervalSinceReferenceDate.bitPattern,
                radix: 16
            )
        ].joined(separator: "|"))
    }

    static func explicitRecoveryAction(afterGates action: SyncAction) -> SyncAction {
        switch action {
        case .blocked, .retryAfterBusy:
            return action
        case .bootstrap, .fullRecovery:
            return action
        case .pushPending:
            return .sequence([.pushPending, .requestRecovery])
        case .sequence:
            return action.containsPushPending
                ? .sequence([.pushPending, .requestRecovery])
                : .requestRecovery
        case .noOp, .drainEvents, .lightReconcile, .requestRecovery:
            return .requestRecovery
        }
    }

    #if DEBUG
    private func observeT10ForegroundAdmission(_ stage: String,
        source: SyncAutomaticTriggerSource? = nil, outcome: String? = nil) {
        let environment = ProcessInfo.processInfo.environment
        guard environment["TASK145_SAVE_BEFORE_ACTIVATION_UI"] == "name-price",
              let runID = environment["TASK144_LOCAL_AVAILABILITY_FIXTURE"].flatMap(UUID.init(uuidString:)) else { return }
        let generationID = storeGenerationLease.flatMap { UUID(uuidString: $0.presentationID) }?.uuidString.lowercased() ?? "none"
        let sourceName = source?.diagnosticsName ?? "none"
        let closedOutcome = outcome ?? "none"
        // Admission or dispatch selection only; never successful completion.
        NSLog("%@", "TASK145_UI03_FOREGROUND schema=1 runID=\(runID.uuidString.lowercased()) pid=\(ProcessInfo.processInfo.processIdentifier) generationID=\(generationID) source=\(sourceName) isStopped=\(isStopped) stage=\(stage) outcome=\(closedOutcome)")
    }
    #endif

    private func recordRuntimeDiagnostic(_ key: String, _ value: String) {
        #if DEBUG
        UserDefaults.standard.set(value, forKey: "sync.runtime.\(key)")
        if key == "foreground.outcome" {
            observeT10ForegroundAdmission("outcome", outcome: value)
        }
        #endif
    }

    private func recordRuntimeDiagnostic(_ key: String, _ value: Bool) {
        #if DEBUG
        UserDefaults.standard.set(value, forKey: "sync.runtime.\(key)")
        #endif
    }

    private func recordRuntimeDiagnostic(_ key: String, _ value: Int) {
        #if DEBUG
        UserDefaults.standard.set(value, forKey: "sync.runtime.\(key)")
        #endif
    }

    private func recordRuntimeDiagnostic(_ key: String, _ value: TimeInterval) {
        #if DEBUG
        UserDefaults.standard.set(value, forKey: "sync.runtime.\(key)")
        #endif
    }

}

private extension SyncAutomaticTriggerSource {
    var diagnosticsName: String { rawValue }
}

private extension SyncAction {
    var containsPushPending: Bool {
        switch self {
        case .pushPending:
            return true
        case .sequence(let actions):
            return actions.contains(where: \.containsPushPending)
        case .noOp, .drainEvents, .lightReconcile, .bootstrap, .fullRecovery,
             .requestRecovery, .retryAfterBusy, .blocked:
            return false
        }
    }

    var diagnosticsScheduleName: String {
        switch self {
        case .pushPending:
            return "scheduled_push_pending_via_sync_runtime"
        case .drainEvents:
            return "scheduled_drain_events_via_sync_runtime"
        case .lightReconcile:
            return "scheduled_light_reconcile_via_sync_runtime"
        case .sequence:
            return "scheduled_sequence_via_sync_runtime"
        case .bootstrap:
            return "scheduled_bootstrap_recovery_via_sync_runtime"
        case .requestRecovery:
            return "scheduled_recovery_request_via_sync_runtime"
        case .noOp:
            return "decision_noop"
        case .fullRecovery:
            return "scheduled_full_recovery_via_sync_runtime"
        case .retryAfterBusy:
            return "deferred_decision_busy"
        case .blocked(let reason):
            return "blocked_\(reason)"
        }
    }

    var runningPhase: SyncPhase {
        switch self {
        case .pushPending:
            return .pushing
        case .drainEvents:
            return .pullingEvents
        case .lightReconcile, .bootstrap, .fullRecovery, .requestRecovery:
            return .reconciling
        case .sequence(let actions):
            return actions.first?.runningPhase ?? .checking
        case .noOp, .retryAfterBusy, .blocked:
            return .checking
        }
    }
}
