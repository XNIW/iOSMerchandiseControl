import Combine
import Foundation
import SwiftUI

nonisolated enum SyncRootPresentationKind: Equatable, Sendable {
    case hidden
    case checking
    case blockedAuth
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

    init(
        automaticRuntime: any SyncAutomaticRuntimeProviding,
        authViewModel: SupabaseAuthViewModel,
        activityCenter: ForegroundCloudWorkflowActivityCenter,
        syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?,
        stateStore: SyncStateStore? = nil,
        decisionInputProvider: any SyncDecisionInputProviding,
        backgroundScheduler: (any SyncBackgroundTaskScheduling)? = nil
    ) {
        self.automaticRuntime = automaticRuntime
        self.authViewModel = authViewModel
        self.activityCenter = activityCenter
        self.syncEventSignalWatcher = syncEventSignalWatcher
        self.stateStore = stateStore ?? SyncStateStore()
        self.decisionInputProvider = decisionInputProvider
        self.backgroundScheduler = backgroundScheduler ?? SyncBackgroundTaskScheduler.shared
    }

    var rootPresentationState: SyncRootPresentationState {
        if authViewModel.isTransitioning || foregroundTask != nil || automaticRuntime.isRunning {
            return .checking
        }
        if !authViewModel.isSignedIn {
            return .blockedAuth
        }
        switch stateStore.state.phase {
        case .recoveryRequired, .failed:
            return .recoverableError
        case .blocked(.authRequired):
            return .blockedAuth
        case .checking, .pushing, .pullingEvents, .reconciling:
            return .checking
        case .idle, .blocked:
            return .hidden
        }
    }

    func bootstrap(scenePhase: ScenePhase) async {
        currentScenePhase = scenePhase
        recordRuntimeDiagnostic("rootHost.taskStartedAt", Date().timeIntervalSince1970)
        startReconnectObserverIfNeeded()
        guard !didReachInteractiveUI else { return }
        syncAuthPresentationContext()
        await Task.yield()
        didReachInteractiveUI = true
        recordRuntimeDiagnostic("rootHost.didReachInteractiveUI", true)
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
        syncAuthPresentationContext()
        updateSyncEventSignalWatcher()
        guard didReachInteractiveUI,
              currentScenePhase == .active else { return }
        submitForegroundTrigger(forceIncremental: true)
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
        submitForegroundTrigger(source: .rootForeground, forceIncremental: true)
    }

    func submitForegroundTrigger(
        source: SyncAutomaticTriggerSource = .rootForeground,
        forceIncremental: Bool = false
    ) {
        recordRuntimeDiagnostic("foreground.requestedAt", Date().timeIntervalSince1970)
        recordRuntimeDiagnostic("foreground.source", source.diagnosticsName)
        recordRuntimeDiagnostic("foreground.forceIncremental", forceIncremental)
        let canRunForCurrentScene = currentScenePhase == .active || (forceIncremental && currentScenePhase != .background)
        guard canRunForCurrentScene else {
            recordRuntimeDiagnostic("foreground.outcome", "blocked_scene")
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

        foregroundTask = Task { @MainActor in
            let action = await decideAction(source: source)
            stateStore.recordDecision(trigger: source.syncTrigger, action: action)
            switch action {
            case .blocked(let reason):
                stateStore.recordRunResult(.blocked(reason))
                recordRuntimeDiagnostic("foreground.outcome", "blocked_\(reason)")
                completeForegroundTask()
                return
            case .retryAfterBusy:
                deferForegroundCheck(source: source, forceIncremental: forceIncremental)
                stateStore.recordRunResult(.scheduledRetry(after: 2))
                recordRuntimeDiagnostic("foreground.outcome", "deferred_decision_busy")
                completeForegroundTask(runDeferred: false)
                return
            case .fullRecovery, .bootstrap:
                recordRuntimeDiagnostic("foreground.outcome", "blocked_full_recovery_requires_explicit_context")
                stateStore.updatePhase(.recoveryRequired)
                stateStore.recordRunResult(.blocked(.accountDecisionRequired))
                completeForegroundTask()
                return
            case .noOp:
                stateStore.recordRunResult(.noWork())
                recordRuntimeDiagnostic("foreground.outcome", "decision_noop")
                completeForegroundTask()
                return
            case .pushPending, .drainEvents, .lightReconcile, .requestRecovery, .sequence:
                stateStore.updatePhase(action.runningPhase)
            }
            recordRuntimeDiagnostic("foreground.outcome", action.diagnosticsScheduleName)
            let result = await automaticRuntime.run(action: action, source: source)
            stateStore.recordRunResult(result)
            foregroundTask = nil
            objectWillChange.send()
            runDeferredForegroundCheckIfNeeded()
        }
    }

    func cancelForegroundCheck() {
        hasDeferredForegroundCheck = false
        deferredForegroundSource = nil
        deferredForegroundForceIncremental = false
        automaticRuntime.cancel()
        foregroundTask?.cancel()
        foregroundTask = nil
        objectWillChange.send()
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
                self.submitForegroundTrigger(source: .remoteSyncEvent, forceIncremental: true)
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
              let ownerUserID = authViewModel.sessionInfo?.userID else {
            recordRuntimeDiagnostic("watcher.state", "stopped")
            syncEventSignalWatcher?.stop()
            return
        }
        recordRuntimeDiagnostic("watcher.state", "started")
        syncEventSignalWatcher?.start(ownerUserID: ownerUserID) { [weak self] in
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
        deferredForegroundSource = source
        deferredForegroundForceIncremental = deferredForegroundForceIncremental || forceIncremental
    }

    private func runDeferredForegroundCheckIfNeeded() {
        guard hasDeferredForegroundCheck else { return }
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
        objectWillChange.send()
        if runDeferred {
            runDeferredForegroundCheckIfNeeded()
        }
    }

    private func decideAction(source: SyncAutomaticTriggerSource) async -> SyncAction {
        let snapshot = await decisionInputProvider.makeSnapshot(
            triggerSource: source,
            isAuthenticated: authViewModel.isSignedIn,
            ownerUserID: authViewModel.sessionInfo?.userID,
            isSyncBusy: activityCenter.isBusy || automaticRuntime.isRunning
        )
        return SyncDecisionEngine.decide(
            snapshot.input
        )
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
            return "blocked_bootstrap_requires_explicit_context"
        case .requestRecovery:
            return "scheduled_recovery_request_via_sync_runtime"
        case .noOp:
            return "decision_noop"
        case .fullRecovery:
            return "blocked_full_recovery_requires_explicit_context"
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
        case .lightReconcile, .requestRecovery:
            return .reconciling
        case .sequence(let actions):
            return actions.first?.runningPhase ?? .checking
        case .bootstrap, .fullRecovery:
            return .recoveryRequired
        case .noOp, .retryAfterBusy, .blocked:
            return .checking
        }
    }
}
