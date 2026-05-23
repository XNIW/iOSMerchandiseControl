import Combine
import Foundation
import SwiftUI

@MainActor
final class SyncOrchestrator: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    let manualSyncViewModel: SupabaseManualSyncViewModel

    private let authViewModel: SupabaseAuthViewModel
    private let activityCenter: ForegroundCloudWorkflowActivityCenter
    private let syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?
    private var viewModelCancellable: AnyCancellable?

    private var currentScenePhase: ScenePhase = .inactive
    private var foregroundTask: Task<Void, Never>?
    private var didReachInteractiveUI = false
    private var hasDeferredForegroundCheck = false
    private var deferredForegroundSource: SupabaseManualSyncSemiAutomaticTriggerSource?
    private var deferredForegroundForceIncremental = false
    private var syncEventSafetyLoopTask: Task<Void, Never>?
    private var reconnectScheduler: AutomaticSyncReconnectScheduler?
    private var reconnectObserver: AutomaticSyncNetworkReachabilityObserver?

    init(
        manualSyncViewModel: SupabaseManualSyncViewModel,
        authViewModel: SupabaseAuthViewModel,
        activityCenter: ForegroundCloudWorkflowActivityCenter,
        syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?
    ) {
        self.manualSyncViewModel = manualSyncViewModel
        self.authViewModel = authViewModel
        self.activityCenter = activityCenter
        self.syncEventSignalWatcher = syncEventSignalWatcher
        self.viewModelCancellable = manualSyncViewModel.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.objectWillChange.send()
            }
        }
    }

    var rootPresentationState: SupabaseManualSyncRootPresentationState {
        manualSyncViewModel.rootPresentationState
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
        _ state: SupabaseManualSyncRootPresentationState,
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
        guard foregroundTask == nil,
              let mode = manualSyncViewModel.runMode(for: .retry) else { return }
        foregroundTask = Task { @MainActor in
            await manualSyncViewModel.start(with: mode)
            foregroundTask = nil
        }
    }

    func submitForegroundTrigger(
        source: SupabaseManualSyncSemiAutomaticTriggerSource = .rootForeground,
        forceIncremental: Bool = false
    ) {
        recordRuntimeDiagnostic("foreground.requestedAt", Date().timeIntervalSince1970)
        recordRuntimeDiagnostic("foreground.source", source.diagnosticsName)
        recordRuntimeDiagnostic("foreground.forceIncremental", forceIncremental)
        guard !isFullPullHarnessRunning else {
            recordRuntimeDiagnostic("foreground.outcome", "blocked_full_pull_harness")
            return
        }
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
            manualSyncViewModel.markForegroundCheckSkippedBecauseBusy()
            recordRuntimeDiagnostic("foreground.outcome", "deferred_busy")
            return
        }

        recordRuntimeDiagnostic("foreground.outcome", forceIncremental ? "scheduled_incremental" : "scheduled_policy")
        foregroundTask = Task { @MainActor in
            let didRun: Bool
            if forceIncremental {
                didRun = await manualSyncViewModel.startForegroundIncrementalCheckNow(source: source)
            } else {
                didRun = await manualSyncViewModel.startForegroundSemiAutomaticCheckIfAllowed(source: source)
            }
            foregroundTask = nil
            if forceIncremental,
               !didRun,
               currentScenePhase != .background,
               !activityCenter.isBusy,
               !hasDeferredForegroundCheck {
                recordRuntimeDiagnostic("foreground.outcome", "retry_after_sync_busy")
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                submitForegroundTrigger(source: source, forceIncremental: true)
                return
            }
            runDeferredForegroundCheckIfNeeded()
        }
    }

    func cancelForegroundCheck() {
        hasDeferredForegroundCheck = false
        deferredForegroundSource = nil
        deferredForegroundForceIncremental = false
        manualSyncViewModel.requestLifecycleInterruptionForBackground()
        foregroundTask?.cancel()
        foregroundTask = nil
    }

    private func syncAuthPresentationContext() {
        authViewModel.refreshCurrentSessionSnapshot()
        recordRuntimeDiagnostic("auth.isSignedIn", authViewModel.isSignedIn)
        recordRuntimeDiagnostic("auth.canSignIn", authViewModel.canSignIn)
        recordRuntimeDiagnostic("auth.isTransitioning", authViewModel.isTransitioning)
        recordRuntimeDiagnostic("auth.userIDPresent", authViewModel.sessionInfo?.userID != nil)
        manualSyncViewModel.applyAuthPresentationContext(
            SupabaseManualSyncAuthPresentationContext(
                isSignedIn: authViewModel.isSignedIn,
                canSignIn: authViewModel.canSignIn,
                isTransitioning: authViewModel.isTransitioning
            )
        )
    }

    private func startReconnectObserverIfNeeded() {
        guard reconnectScheduler == nil,
              reconnectObserver == nil else { return }
        let scheduler = AutomaticSyncReconnectScheduler { [weak self] in
            self?.submitForegroundTrigger(source: .networkReconnect, forceIncremental: true)
        }
        scheduler.setForeground(currentScenePhase == .active)
        let observer = AutomaticSyncNetworkReachabilityObserver(scheduler: scheduler)
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
            self?.submitForegroundTrigger(source: .remoteSyncEvent, forceIncremental: true)
        }
    }

    private func deferForegroundCheck(
        source: SupabaseManualSyncSemiAutomaticTriggerSource,
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

    private func recordRuntimeDiagnostic(_ key: String, _ value: String) {
        #if DEBUG
        UserDefaults.standard.set(value, forKey: "task115.runtime.\(key)")
        #endif
    }

    private func recordRuntimeDiagnostic(_ key: String, _ value: Bool) {
        #if DEBUG
        UserDefaults.standard.set(value, forKey: "task115.runtime.\(key)")
        #endif
    }

    private func recordRuntimeDiagnostic(_ key: String, _ value: Int) {
        #if DEBUG
        UserDefaults.standard.set(value, forKey: "task115.runtime.\(key)")
        #endif
    }

    private func recordRuntimeDiagnostic(_ key: String, _ value: TimeInterval) {
        #if DEBUG
        UserDefaults.standard.set(value, forKey: "task115.runtime.\(key)")
        #endif
    }

    private var isFullPullHarnessRunning: Bool {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let value = environment["TASK115_IOS_FULL_PULL"]
            ?? environment["TEST_RUNNER_TASK115_IOS_FULL_PULL"]
            ?? environment["TASK114_IOS_FULL_PULL"]
            ?? environment["TEST_RUNNER_TASK114_IOS_FULL_PULL"]
        return value == "1" || value?.lowercased() == "true"
        #else
        return false
        #endif
    }

}
