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
        titleKey: "options.supabase.automaticSync.root.checking.title",
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
final class SyncOrchestrator: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    private let automaticRuntime: any SyncAutomaticRuntimeProviding
    private let authViewModel: SupabaseAuthViewModel
    private let activityCenter: ForegroundCloudWorkflowActivityCenter
    private let syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?
    private let stateStore: SyncStateStore
    private let decisionInputProvider: any SyncDecisionInputProviding
    private let backgroundScheduler: any SyncBackgroundTaskScheduling

    private var currentScenePhase: ScenePhase = .inactive
    private var foregroundTask: Task<Void, Never>?
    private var didReachInteractiveUI = false
    private var hasDeferredForegroundCheck = false
    private var deferredForegroundSource: SyncAutomaticTriggerSource?
    private var deferredForegroundForceIncremental = false
    private var syncEventSafetyLoopTask: Task<Void, Never>?
    private var reconnectScheduler: AutomaticSyncReconnectScheduler?
    private var reconnectObserver: AutomaticSyncNetworkReachabilityObserver?
    private var scheduledForegroundRetryTask: Task<Void, Never>?
    private var foregroundBusyRetryAttempt = 0
    private var isAccountStoreReplacementInProgress = false
    private var foregroundStartedFromRecoveryRequired = false
    private var isStopped = false
    private let foregroundRetryDelay: @Sendable (TimeInterval) async -> Void
    private let maximumForegroundBusyRetryAttempts: Int

    init(
        automaticRuntime: any SyncAutomaticRuntimeProviding,
        authViewModel: SupabaseAuthViewModel,
        activityCenter: ForegroundCloudWorkflowActivityCenter,
        syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?,
        stateStore: SyncStateStore? = nil,
        decisionInputProvider: any SyncDecisionInputProviding,
        backgroundScheduler: (any SyncBackgroundTaskScheduling)? = nil,
        maximumForegroundBusyRetryAttempts: Int = 3,
        foregroundRetryDelay: @escaping @Sendable (TimeInterval) async -> Void = { delay in
            let nanoseconds = UInt64(max(0, delay) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.automaticRuntime = automaticRuntime
        self.authViewModel = authViewModel
        self.activityCenter = activityCenter
        self.syncEventSignalWatcher = syncEventSignalWatcher
        self.stateStore = stateStore ?? SyncStateStore()
        self.decisionInputProvider = decisionInputProvider
        self.backgroundScheduler = backgroundScheduler ?? SyncBackgroundTaskScheduler.shared
        self.maximumForegroundBusyRetryAttempts = max(0, maximumForegroundBusyRetryAttempts)
        self.foregroundRetryDelay = foregroundRetryDelay
    }

    var rootPresentationState: SyncRootPresentationState {
        Self.makeRootPresentationState(
            isTransitioning: authViewModel.isTransitioning,
            isSignedIn: authViewModel.isSignedIn,
            isAutomaticRuntimeRunning: automaticRuntime.isRunning,
            phase: stateStore.state.phase
        )
    }

    static func makeRootPresentationState(
        isTransitioning: Bool,
        isSignedIn: Bool,
        isAutomaticRuntimeRunning: Bool,
        phase: SyncPhase
    ) -> SyncRootPresentationState {
        if isTransitioning || isAutomaticRuntimeRunning {
            return .checking
        }
        if !isSignedIn {
            return .blockedAuth
        }
        switch phase {
        case .recoveryRequired, .failed:
            return .recoverableError
        case .blocked(.authRequired):
            return .blockedAuth
        case .blocked(.deviceNotActive):
            return .deviceBlocked
        case .checking, .pushing, .pullingEvents, .reconciling:
            return .checking
        case .idle, .blocked:
            return .hidden
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
        guard didReachInteractiveUI,
              currentScenePhase == .active,
              authViewModel.isSignedIn else { return }
        submitForegroundTrigger(source: .rootForeground, forceIncremental: true)
    }

    func resumeDeferredForegroundCheckIfReady() {
        guard didReachInteractiveUI,
              hasDeferredForegroundCheck,
              !activityCenter.isBusy else { return }
        let source = deferredForegroundSource ?? .rootForeground
        hasDeferredForegroundCheck = false
        deferredForegroundSource = nil
        let forceIncremental = deferredForegroundForceIncremental
        deferredForegroundForceIncremental = false
        submitForegroundTrigger(source: source, forceIncremental: forceIncremental)
    }

    func handleLocalPendingChanges() {
        backgroundScheduler.schedule(reason: .localPendingWrite)
        guard didReachInteractiveUI,
              currentScenePhase == .active else { return }
        submitForegroundTrigger(source: .localMutation, forceIncremental: true)
    }

    func stop() {
        isStopped = true
        clearDeferredForegroundCheck()
        cancelScheduledForegroundRetry()
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
        guard state.kind != .hidden else { return false }
        guard state.kind != .blockedAuth else { return false }
        guard state.primaryActionID != nil || state.kind == .checking else { return false }
        guard selectedTab != 3 else { return false }
        guard !activityCenter.isBusy else { return false }
        return true
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
        guard !isStopped else { return }
        recordRuntimeDiagnostic("foreground.requestedAt", Date().timeIntervalSince1970)
        recordRuntimeDiagnostic("foreground.source", source.diagnosticsName)
        recordRuntimeDiagnostic("foreground.forceIncremental", forceIncremental)
        let canRunForCurrentScene = currentScenePhase == .active || (forceIncremental && currentScenePhase != .background)
        guard canRunForCurrentScene else {
            recordRuntimeDiagnostic("foreground.outcome", "blocked_scene")
            return
        }
        guard !isAccountStoreReplacementInProgress else {
            deferForegroundCheck(source: source, forceIncremental: forceIncremental)
            recordRuntimeDiagnostic("foreground.outcome", "deferred_store_replacement")
            return
        }
        guard foregroundTask == nil else {
            deferForegroundCheck(source: source, forceIncremental: forceIncremental)
            recordRuntimeDiagnostic("foreground.outcome", "deferred_existing_task")
            return
        }
        guard !activityCenter.isBusy else {
            deferForegroundCheck(source: source, forceIncremental: forceIncremental)
            recordRuntimeDiagnostic("foreground.outcome", "deferred_busy")
            return
        }

        let isExplicitRecoveryRetry = source == .releaseCard
        if isExplicitRecoveryRetry {
            stateStore.resetAutomaticRecoveryAttemptBudget()
        }
        let automaticRecoveryIdentity = automaticRecoveryResumeIdentityIfAllowed(source: source)
        let isAutomaticRecoveryResume: Bool
        if let automaticRecoveryIdentity {
            switch stateStore.automaticRecoveryAttemptEligibility(
                identity: automaticRecoveryIdentity
            ) {
            case .ready:
                isAutomaticRecoveryResume = true
            case .cooldown(let remaining):
                deferForegroundCheck(source: source, forceIncremental: forceIncremental)
                if scheduleDeferredForegroundRetry(after: remaining) {
                    recordRuntimeDiagnostic("foreground.outcome", "recovery_resume_backoff")
                } else {
                    clearDeferredForegroundCheck()
                    recordRuntimeDiagnostic("foreground.outcome", "recovery_resume_backoff_exhausted")
                }
                return
            case .exhausted:
                recordRuntimeDiagnostic("foreground.outcome", "recovery_resume_exhausted")
                return
            }
        } else {
            isAutomaticRecoveryResume = false
        }
        let isRecoveryRetry = isExplicitRecoveryRetry || isAutomaticRecoveryResume
        guard !Self.shouldPreserveRecoveryRequired(
            phase: stateStore.state.phase,
            source: source
        ) || isAutomaticRecoveryResume else {
            recordRuntimeDiagnostic("foreground.outcome", "recovery_required_preserved")
            return
        }

        foregroundStartedFromRecoveryRequired = isRecoveryRetry
        let preserveRecoveryRequired = isRecoveryRetry
        foregroundTask = Task { @MainActor in
            let decidedAction = await decideAction(
                source: source,
                forceLightReconcile: forceIncremental
            )
            guard !Task.isCancelled else {
                completeForegroundTask()
                return
            }
            let action = isRecoveryRetry
                ? Self.explicitRecoveryAction(afterGates: decidedAction)
                : decidedAction
            stateStore.recordDecision(trigger: source.syncTrigger, action: action)
            switch action {
            case .blocked(let reason):
                stateStore.recordRunResult(
                    .blocked(reason),
                    preserveRecoveryRequired: preserveRecoveryRequired
                )
                recordRuntimeDiagnostic("foreground.outcome", "blocked_\(reason)")
                completeForegroundTask()
                return
            case .retryAfterBusy:
                deferForegroundCheck(source: source, forceIncremental: forceIncremental)
                var retryDelay: TimeInterval = 2
                if let automaticRecoveryIdentity {
                    guard stateStore.beginAutomaticRecoveryAttempt(
                        identity: automaticRecoveryIdentity
                    ) != nil else {
                        clearDeferredForegroundCheck()
                        stateStore.recordRunResult(
                            .failed(errorCode: "automatic_recovery_attempt_budget_unavailable"),
                            preserveRecoveryRequired: true
                        )
                        completeForegroundTask()
                        return
                    }
                    retryDelay = stateStore.extendAutomaticRecoveryAttemptCooldown(
                        identity: automaticRecoveryIdentity,
                        requestedDelay: retryDelay
                    )
                }
                completeBusyForegroundAttempt(
                    source: source,
                    preserveRecoveryRequired: preserveRecoveryRequired,
                    requestedDelay: retryDelay,
                    diagnostic: "deferred_decision_busy"
                )
                return
            case .noOp:
                stateStore.recordRunResult(
                    .noWork(),
                    preserveRecoveryRequired: preserveRecoveryRequired
                )
                recordRuntimeDiagnostic("foreground.outcome", "decision_noop")
                completeForegroundTask()
                return
            case .pushPending, .drainEvents, .lightReconcile, .bootstrap, .fullRecovery, .requestRecovery, .sequence:
                if let automaticRecoveryIdentity,
                   stateStore.beginAutomaticRecoveryAttempt(
                    identity: automaticRecoveryIdentity
                   ) == nil {
                    stateStore.recordRunResult(
                        .failed(errorCode: "automatic_recovery_attempt_budget_unavailable"),
                        preserveRecoveryRequired: true
                    )
                    recordRuntimeDiagnostic(
                        "foreground.outcome",
                        "recovery_resume_budget_unavailable"
                    )
                    completeForegroundTask()
                    return
                }
                stateStore.updatePhase(action.runningPhase)
            }
            recordRuntimeDiagnostic("foreground.outcome", action.diagnosticsScheduleName)
            let result = await automaticRuntime.run(action: action, source: source)
            guard !Task.isCancelled || result.verifiedConvergence else {
                completeForegroundTask()
                return
            }
            stateStore.recordRunResult(
                result,
                preserveRecoveryRequired: preserveRecoveryRequired
            )
            foregroundTask = nil
            foregroundStartedFromRecoveryRequired = false
            objectWillChange.send()
            if result.status == .busy || result.status == .scheduledRetry {
                deferForegroundCheck(source: source, forceIncremental: forceIncremental)
                var requestedDelay = result.scheduledRetryAfter ?? 2
                if let automaticRecoveryIdentity {
                    requestedDelay = stateStore.extendAutomaticRecoveryAttemptCooldown(
                        identity: automaticRecoveryIdentity,
                        requestedDelay: requestedDelay
                    )
                }
                if scheduleDeferredForegroundRetry(after: requestedDelay) {
                    recordRuntimeDiagnostic("foreground.outcome", "deferred_runtime_busy")
                } else {
                    clearDeferredForegroundCheck()
                    stateStore.recordRunResult(
                        .failed(errorCode: "sync_busy_retry_exhausted"),
                        preserveRecoveryRequired: preserveRecoveryRequired
                    )
                    recordRuntimeDiagnostic("foreground.outcome", "busy_retry_exhausted")
                }
                return
            }
            if !stateStore.recoveryJournalIsPending {
                stateStore.resetAutomaticRecoveryAttemptBudget()
            }
            resetForegroundBusyRetryBudget()
            runDeferredForegroundCheckIfNeeded()
        }
    }

    func cancelForegroundCheck() {
        let preserveRecoveryRequired = foregroundStartedFromRecoveryRequired
            && !isAccountStoreReplacementInProgress
        clearDeferredForegroundCheck()
        cancelScheduledForegroundRetry()
        automaticRuntime.cancel()
        foregroundTask?.cancel()
        if stateStore.state.phase.isAutomaticWorkActive {
            stateStore.recordRunResult(
                .cancelled(),
                preserveRecoveryRequired: preserveRecoveryRequired
            )
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
        foregroundStartedFromRecoveryRequired = false
        stateStore.reconcilePendingRecoveryJournal()
        objectWillChange.send()

        let runningTask = foregroundTask
        runningTask?.cancel()
        await automaticRuntime.cancelAndWait()
        if let runningTask {
            await runningTask.value
        }
        foregroundTask = nil

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
        forceIncremental: Bool
    ) {
        hasDeferredForegroundCheck = true
        deferredForegroundSource = Self.preferredDeferredSource(
            current: deferredForegroundSource,
            incoming: source
        )
        deferredForegroundForceIncremental = deferredForegroundForceIncremental || forceIncremental
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
    }

    private func completeBusyForegroundAttempt(
        source: SyncAutomaticTriggerSource,
        preserveRecoveryRequired: Bool,
        requestedDelay: TimeInterval,
        diagnostic: String
    ) {
        let scheduled = scheduleDeferredForegroundRetry(after: requestedDelay)
        stateStore.recordRunResult(
            scheduled
                ? .scheduledRetry(after: requestedDelay)
                : .failed(errorCode: "sync_busy_retry_exhausted"),
            preserveRecoveryRequired: preserveRecoveryRequired
        )
        recordRuntimeDiagnostic(
            "foreground.outcome",
            scheduled ? diagnostic : "busy_retry_exhausted"
        )
        if !scheduled {
            clearDeferredForegroundCheck()
        }
        completeForegroundTask(runDeferred: false)
    }

    private func scheduleDeferredForegroundRetry(after requestedDelay: TimeInterval) -> Bool {
        guard scheduledForegroundRetryTask == nil,
              foregroundBusyRetryAttempt < maximumForegroundBusyRetryAttempts else {
            return false
        }
        let attempt = foregroundBusyRetryAttempt
        foregroundBusyRetryAttempt += 1
        let boundedDelay = min(max(0, requestedDelay) * pow(2, Double(attempt)), 30)
        let delay = foregroundRetryDelay
        scheduledForegroundRetryTask = Task { @MainActor [weak self] in
            await delay(boundedDelay)
            guard !Task.isCancelled, let self else { return }
            self.scheduledForegroundRetryTask = nil
            self.runDeferredForegroundCheckIfNeeded()
        }
        return true
    }

    private func cancelScheduledForegroundRetry() {
        scheduledForegroundRetryTask?.cancel()
        scheduledForegroundRetryTask = nil
        foregroundBusyRetryAttempt = 0
    }

    private func resetForegroundBusyRetryBudget() {
        scheduledForegroundRetryTask?.cancel()
        scheduledForegroundRetryTask = nil
        foregroundBusyRetryAttempt = 0
    }

    private func runDeferredForegroundCheckIfNeeded() {
        guard !isStopped, hasDeferredForegroundCheck else { return }
        let source = deferredForegroundSource ?? .rootForeground
        let forceIncremental = deferredForegroundForceIncremental
        hasDeferredForegroundCheck = false
        deferredForegroundSource = nil
        deferredForegroundForceIncremental = false
        submitForegroundTrigger(source: source, forceIncremental: forceIncremental)
    }

    private func completeForegroundTask(runDeferred: Bool = true) {
        backgroundScheduler.schedule(reason: .foregroundCompletion)
        foregroundTask = nil
        foregroundStartedFromRecoveryRequired = false
        objectWillChange.send()
        if runDeferred, !isStopped {
            runDeferredForegroundCheckIfNeeded()
        }
    }

    private func decideAction(
        source: SyncAutomaticTriggerSource,
        forceLightReconcile: Bool
    ) async -> SyncAction {
        let snapshot = await decisionInputProvider.makeSnapshot(
            triggerSource: source,
            isAuthenticated: authViewModel.isSignedIn,
            ownerUserID: authViewModel.sessionInfo?.userID,
            isSyncBusy: activityCenter.isBusy || automaticRuntime.isRunning
        )
        let action = SyncDecisionEngine.decide(snapshot.input)
        // A foreground safety/reconnect request must reach the server-side
        // checkpoint even when the local decision snapshot looks idle. Gates,
        // bootstrap and pending work retain precedence; only a local no-op is
        // upgraded to the bounded reconciliation path.
        if forceLightReconcile, action == .noOp {
            return .lightReconcile
        }
        return action
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
        hasDecodableJournal && (source == .rootForeground || source == .networkReconnect)
    }

    private func automaticRecoveryResumeIdentityIfAllowed(
        source: SyncAutomaticTriggerSource
    ) -> String? {
        guard stateStore.state.phase == .recoveryRequired,
              let journal = stateStore.pendingRecoveryJournal,
              Self.allowsAutomaticRecoveryResume(
                source: source,
                hasDecodableJournal: true
              ) else { return nil }
        return Self.automaticRecoveryResumeIdentity(for: journal)
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

    private func recordRuntimeDiagnostic(_ key: String, _ value: String) {
        #if DEBUG
        UserDefaults.standard.set(value, forKey: "sync.runtime.\(key)")
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
