import Combine
import SwiftUI
import SwiftData

nonisolated enum ForegroundCloudWorkflowActivityReason: String, Hashable, Sendable {
    case importExcel
    case exportShare
    case scanner
    case editing
    case cloudReview
    case confirmationDialog
    case manualSyncSheet
    case localProgress
}

nonisolated struct ForegroundCloudWorkflowActivityStore: Equatable {
    private var activeTokens: [String: ForegroundCloudWorkflowActivityReason] = [:]

    var activeReasons: Set<ForegroundCloudWorkflowActivityReason> {
        Set(activeTokens.values)
    }

    var isBusy: Bool {
        !activeTokens.isEmpty
    }

    mutating func setActive(_ reason: ForegroundCloudWorkflowActivityReason, _ isActive: Bool, token: UUID) {
        let tokenKey = token.uuidString
        if isActive {
            activeTokens[tokenKey] = reason
        } else {
            activeTokens.removeValue(forKey: tokenKey)
        }
    }
}

final class ForegroundCloudWorkflowActivityCenter: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    private var store = ForegroundCloudWorkflowActivityStore()

    var activeReasons: Set<ForegroundCloudWorkflowActivityReason> {
        store.activeReasons
    }

    var isBusy: Bool {
        store.isBusy
    }

    func setActive(_ reason: ForegroundCloudWorkflowActivityReason, _ isActive: Bool, token: UUID) {
        let previousStore = store
        store.setActive(reason, isActive, token: token)
        if store != previousStore {
            objectWillChange.send()
        }
    }
}

private struct ForegroundCloudWorkflowActivityCenterKey: EnvironmentKey {
    static let defaultValue = ForegroundCloudWorkflowActivityCenter()
}

extension EnvironmentValues {
    var foregroundCloudWorkflowActivityCenter: ForegroundCloudWorkflowActivityCenter {
        get { self[ForegroundCloudWorkflowActivityCenterKey.self] }
        set { self[ForegroundCloudWorkflowActivityCenterKey.self] = newValue }
    }
}

private struct ForegroundCloudWorkflowActivityModifier: ViewModifier {
    @Environment(\.foregroundCloudWorkflowActivityCenter) private var activityCenter
    @State private var token = UUID()

    let reason: ForegroundCloudWorkflowActivityReason
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .onAppear {
                activityCenter.setActive(reason, isActive, token: token)
            }
            .onChange(of: isActive) { _, newValue in
                activityCenter.setActive(reason, newValue, token: token)
            }
            .onDisappear {
                activityCenter.setActive(reason, false, token: token)
            }
    }
}

extension View {
    func foregroundCloudWorkflowActivity(
        _ reason: ForegroundCloudWorkflowActivityReason,
        isActive: Bool
    ) -> some View {
        modifier(ForegroundCloudWorkflowActivityModifier(reason: reason, isActive: isActive))
    }
}

struct ContentView: View {
    private let supabaseInventoryService: SupabaseInventoryService?
    private let supabasePullPreviewService: SupabasePullPreviewService?
    private let supabaseManualPushService: SupabaseManualPushService?
    private let syncEventOutboxDrainRecorder: (any SyncEventRecording)?
    private let syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?
    private let historySessionSyncService: HistorySessionSyncService?

    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("appLanguage") private var appLanguage: String = "system"
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    @StateObject private var excelSession = ExcelSessionViewModel()
    @StateObject private var foregroundActivityCenter = ForegroundCloudWorkflowActivityCenter()
    @State private var selectedTab = 0

    init(
        supabaseInventoryService: SupabaseInventoryService? = nil,
        supabasePullPreviewService: SupabasePullPreviewService? = nil,
        supabaseManualPushService: SupabaseManualPushService? = nil,
        syncEventOutboxDrainRecorder: (any SyncEventRecording)? = nil,
        syncEventSignalWatcher: SupabaseSyncEventSignalWatcher? = nil
    ) {
        self.supabaseInventoryService = supabaseInventoryService
        self.supabasePullPreviewService = supabasePullPreviewService
        self.supabaseManualPushService = supabaseManualPushService
        self.syncEventOutboxDrainRecorder = syncEventOutboxDrainRecorder
        self.syncEventSignalWatcher = syncEventSignalWatcher
        self.historySessionSyncService = supabaseInventoryService.map {
            HistorySessionSyncService(remote: $0)
        }
    }

    private var resolvedColorScheme: ColorScheme? {
        switch appTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    var body: some View {
        SupabaseManualSyncForegroundRootHost(
            context: modelContext,
            authViewModel: supabaseAuthViewModel,
            inventoryService: supabaseInventoryService,
            pullPreviewService: supabasePullPreviewService,
            manualPushService: supabaseManualPushService,
            activityRecorder: syncEventOutboxDrainRecorder,
            syncEventSignalWatcher: syncEventSignalWatcher,
            selectedTab: $selectedTab,
            activityCenter: foregroundActivityCenter
        ) { manualSyncViewModel, cancelForegroundCheck in
            tabContent(
                manualSyncViewModel: manualSyncViewModel,
                cancelForegroundCheck: cancelForegroundCheck
            )
        }
        .environment(\.foregroundCloudWorkflowActivityCenter, foregroundActivityCenter)
        .foregroundCloudWorkflowActivity(.importExcel, isActive: excelSession.isLoading)
        .localeOverride(for: appLanguage)
        .preferredColorScheme(resolvedColorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .openDatabaseTabRequested)) { _ in
            selectedTab = 1
        }
        .onOpenURL { url in
            guard url.isFileURL else { return }
            // Policy URL singolo: se c'è già un URL pendente o un import in corso, scarta
            guard excelSession.pendingOpenURL == nil, !excelSession.isLoading else {
                // L'errore verrà mostrato da loadExternalFile quando consuma il pendingOpenURL,
                // oppure qui se isLoading è true. Per semplicità, ignoriamo silenziosamente
                // il secondo URL a livello di ContentView — il blocco con errore user-friendly
                // è già gestito in loadExternalFile per il caso isLoading.
                return
            }
            selectedTab = 0
            excelSession.pendingOpenURL = url
        }
    }

    @ViewBuilder
    private func tabContent(
        manualSyncViewModel: SupabaseManualSyncViewModel,
        cancelForegroundCheck: @escaping () -> Void
    ) -> some View {
        TabView(selection: $selectedTab) {
            // TAB 1: Inventario
            NavigationStack {
                InventoryHomeView()
                    .environmentObject(excelSession)
            }
            .tabItem {
                Label(L("tab.inventory"), systemImage: "doc.on.doc")
            }
            .tag(0)

            // TAB 2: Database
            NavigationStack {
                DatabaseView()
            }
            .tabItem {
                Label(L("tab.database"), systemImage: "shippingbox")
            }
            .tag(1)

            // TAB 3: Cronologia
            NavigationStack {
                HistoryView(historySessionSyncService: historySessionSyncService)
            }
            .tabItem {
                Label(L("tab.history"), systemImage: "clock.arrow.circlepath")
            }
            .tag(2)

            // TAB 4: Opzioni
            NavigationStack {
                OptionsView(
                    supabaseInventoryService: supabaseInventoryService,
                    supabasePullPreviewService: supabasePullPreviewService,
                    supabaseManualPushService: supabaseManualPushService,
                    syncEventOutboxDrainRecorder: syncEventOutboxDrainRecorder,
                    manualSyncViewModel: manualSyncViewModel,
                    manualSyncCancelHandler: cancelForegroundCheck
                )
            }
            .tabItem {
                Label(L("tab.options"), systemImage: "gearshape")
            }
            .tag(3)
        }
    }
}

private struct SupabaseManualSyncForegroundRootHost<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var activityCenter: ForegroundCloudWorkflowActivityCenter
    @ObservedObject private var authViewModel: SupabaseAuthViewModel
    @StateObject private var viewModel: SupabaseManualSyncViewModel
    @Binding private var selectedTab: Int
    @State private var foregroundTask: Task<Void, Never>?
    @State private var didReachInteractiveUI = false
    @State private var hasDeferredForegroundCheck = false
    @State private var deferredForegroundSource: SupabaseManualSyncSemiAutomaticTriggerSource?
    @State private var deferredForegroundForceIncremental = false
    @State private var syncEventSafetyLoopTask: Task<Void, Never>?
    @State private var reconnectScheduler: AutomaticSyncReconnectScheduler?
    @State private var reconnectObserver: AutomaticSyncNetworkReachabilityObserver?

    private let content: (SupabaseManualSyncViewModel, @escaping () -> Void) -> Content
    private let syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?

    init(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        inventoryService: SupabaseInventoryService?,
        pullPreviewService: SupabasePullPreviewService?,
        manualPushService: SupabaseManualPushService?,
        activityRecorder: (any SyncEventRecording)?,
        syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?,
        selectedTab: Binding<Int>,
        activityCenter: ForegroundCloudWorkflowActivityCenter,
        @ViewBuilder content: @escaping (SupabaseManualSyncViewModel, @escaping () -> Void) -> Content
    ) {
        _viewModel = StateObject(
            wrappedValue: SupabaseManualSyncReleaseFactory.makeViewModel(
                context: context,
                authViewModel: authViewModel,
                inventoryService: inventoryService,
                pullPreviewService: pullPreviewService,
                manualPushService: manualPushService,
                activityRecorder: activityRecorder
            )
        )
        _selectedTab = selectedTab
        _activityCenter = ObservedObject(wrappedValue: activityCenter)
        _authViewModel = ObservedObject(wrappedValue: authViewModel)
        self.content = content
        self.syncEventSignalWatcher = syncEventSignalWatcher
    }

    var body: some View {
        content(viewModel, cancelRootForegroundCheck)
            .safeAreaInset(edge: .top, spacing: 0) {
                rootBanner
            }
            .task {
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
                startRootForegroundCheckIfAllowed(forceIncremental: true)
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    reconnectScheduler?.setForeground(true)
                    syncAuthPresentationContext()
                    guard didReachInteractiveUI else { return }
                    updateSyncEventSignalWatcher()
                    startSyncEventSafetyLoopIfNeeded()
                    startRootForegroundCheckIfAllowed(forceIncremental: true)
                case .background:
                    reconnectScheduler?.setForeground(false)
                    syncEventSignalWatcher?.stop()
                    stopSyncEventSafetyLoop()
                    cancelRootForegroundCheck()
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
            .onChange(of: authViewModel.isTransitioning) { _, _ in
                handleAuthPresentationChanged()
            }
            .onChange(of: authViewModel.canSignIn) { _, _ in
                handleAuthPresentationChanged()
            }
            .onChange(of: authViewModel.sessionInfo?.userID) { _, _ in
                handleAuthPresentationChanged()
            }
            .onChange(of: authViewModel.isSignedIn) { _, _ in
                handleAuthPresentationChanged()
            }
            .onChange(of: activityCenter.activeReasons) { _, _ in
                guard didReachInteractiveUI,
                      hasDeferredForegroundCheck,
                      !activityCenter.isBusy else { return }
                let source = deferredForegroundSource ?? .rootForeground
                hasDeferredForegroundCheck = false
                deferredForegroundSource = nil
                let forceIncremental = deferredForegroundForceIncremental
                deferredForegroundForceIncremental = false
                startRootForegroundCheckIfAllowed(source: source, forceIncremental: forceIncremental)
            }
            .onReceive(NotificationCenter.default.publisher(for: .localPendingChangesDidChange)) { _ in
                guard didReachInteractiveUI,
                      scenePhase == .active else { return }
                startRootForegroundCheckIfAllowed(source: .localMutation, forceIncremental: true)
            }
            .onDisappear {
                stopSyncEventSafetyLoop()
                reconnectObserver?.cancel()
                reconnectObserver = nil
                reconnectScheduler = nil
                syncEventSignalWatcher?.stop()
            }
    }

    private func handleAuthPresentationChanged() {
        syncAuthPresentationContext()
        updateSyncEventSignalWatcher()
        guard didReachInteractiveUI,
              scenePhase == .active else { return }
        startRootForegroundCheckIfAllowed(forceIncremental: true)
    }

    private func syncAuthPresentationContext() {
        authViewModel.refreshCurrentSessionSnapshot()
        recordRuntimeDiagnostic("auth.isSignedIn", authViewModel.isSignedIn)
        recordRuntimeDiagnostic("auth.canSignIn", authViewModel.canSignIn)
        recordRuntimeDiagnostic("auth.isTransitioning", authViewModel.isTransitioning)
        recordRuntimeDiagnostic("auth.userIDPresent", authViewModel.sessionInfo?.userID != nil)
        viewModel.applyAuthPresentationContext(
            SupabaseManualSyncAuthPresentationContext(
                isSignedIn: authViewModel.isSignedIn,
                canSignIn: authViewModel.canSignIn,
                isTransitioning: authViewModel.isTransitioning
            )
        )
    }

    @ViewBuilder
    private var rootBanner: some View {
        let state = viewModel.rootPresentationState
        if shouldShowRootBanner(state) {
            SupabaseManualSyncRootForegroundBanner(
                state: state,
                reduceMotion: reduceMotion,
                action: { handleRootAction(state.primaryActionID) }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func shouldShowRootBanner(_ state: SupabaseManualSyncRootPresentationState) -> Bool {
        guard state.kind != .hidden else { return false }
        guard state.kind != .blockedAuth else { return false }
        guard state.primaryActionID != nil || state.kind == .checking else { return false }
        guard selectedTab != 3 else { return false }
        guard !activityCenter.isBusy else { return false }
        return true
    }

    private func startReconnectObserverIfNeeded() {
        guard reconnectScheduler == nil,
              reconnectObserver == nil else { return }
        let scheduler = AutomaticSyncReconnectScheduler {
            startRootForegroundCheckIfAllowed(source: .networkReconnect, forceIncremental: true)
        }
        scheduler.setForeground(scenePhase == .active)
        let observer = AutomaticSyncNetworkReachabilityObserver(scheduler: scheduler)
        observer.start()
        reconnectScheduler = scheduler
        reconnectObserver = observer
    }

    private func startSyncEventSafetyLoopIfNeeded() {
        guard syncEventSafetyLoopTask == nil else { return }
        syncEventSafetyLoopTask = Task { @MainActor in
            let intervalNanoseconds: UInt64 = 5_000_000_000
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
                guard !Task.isCancelled else { break }
                recordRuntimeDiagnostic("timer.intervalSeconds", 5)
                recordRuntimeDiagnostic("timer.lastTickAt", Date().timeIntervalSince1970)
                recordRuntimeDiagnostic("timer.didReachInteractiveUI", didReachInteractiveUI)
                recordRuntimeDiagnostic("timer.sceneActive", scenePhase == .active)
                recordRuntimeDiagnostic("timer.sceneBackground", scenePhase == .background)
                guard didReachInteractiveUI,
                      scenePhase != .background else { continue }
                syncAuthPresentationContext()
                updateSyncEventSignalWatcher()
                recordRuntimeDiagnostic("timer.isSignedIn", authViewModel.isSignedIn)
                guard authViewModel.isSignedIn else { continue }
                startRootForegroundCheckIfAllowed(source: .remoteSyncEvent, forceIncremental: true)
            }
            syncEventSafetyLoopTask = nil
        }
    }

    private func stopSyncEventSafetyLoop() {
        syncEventSafetyLoopTask?.cancel()
        syncEventSafetyLoopTask = nil
    }

    private func updateSyncEventSignalWatcher() {
        recordRuntimeDiagnostic("watcher.updateAt", Date().timeIntervalSince1970)
        guard didReachInteractiveUI,
              scenePhase != .background,
              authViewModel.isSignedIn,
              let ownerUserID = authViewModel.sessionInfo?.userID else {
            recordRuntimeDiagnostic("watcher.state", "stopped")
            syncEventSignalWatcher?.stop()
            return
        }
        recordRuntimeDiagnostic("watcher.state", "started")
        syncEventSignalWatcher?.start(ownerUserID: ownerUserID) {
            recordRuntimeDiagnostic("watcher.signalAt", Date().timeIntervalSince1970)
            startRootForegroundCheckIfAllowed(source: .remoteSyncEvent, forceIncremental: true)
        }
    }

    private func startRootForegroundCheckIfAllowed(
        source: SupabaseManualSyncSemiAutomaticTriggerSource = .rootForeground,
        forceIncremental: Bool = false
    ) {
        recordRuntimeDiagnostic("foreground.requestedAt", Date().timeIntervalSince1970)
        recordRuntimeDiagnostic("foreground.source", source.diagnosticsName)
        recordRuntimeDiagnostic("foreground.forceIncremental", forceIncremental)
        guard !isTask114FullPullHarnessRunning else {
            recordRuntimeDiagnostic("foreground.outcome", "blocked_full_pull_harness")
            return
        }
        let canRunForCurrentScene = scenePhase == .active || (forceIncremental && scenePhase != .background)
        guard canRunForCurrentScene else {
            recordRuntimeDiagnostic("foreground.outcome", "blocked_scene")
            return
        }
        guard foregroundTask == nil else {
            hasDeferredForegroundCheck = true
            deferredForegroundSource = source
            deferredForegroundForceIncremental = deferredForegroundForceIncremental || forceIncremental
            recordRuntimeDiagnostic("foreground.outcome", "deferred_existing_task")
            return
        }
        guard !activityCenter.isBusy else {
            hasDeferredForegroundCheck = true
            deferredForegroundSource = source
            deferredForegroundForceIncremental = deferredForegroundForceIncremental || forceIncremental
            viewModel.markForegroundCheckSkippedBecauseBusy()
            recordRuntimeDiagnostic("foreground.outcome", "deferred_busy")
            return
        }

        recordRuntimeDiagnostic("foreground.outcome", forceIncremental ? "scheduled_incremental" : "scheduled_policy")
        foregroundTask = Task { @MainActor in
            let didRun: Bool
            if forceIncremental {
                didRun = await viewModel.startForegroundIncrementalCheckNow(source: source)
            } else {
                didRun = await viewModel.startForegroundSemiAutomaticCheckIfAllowed(source: source)
            }
            foregroundTask = nil
            if forceIncremental,
               !didRun,
               scenePhase != .background,
               !activityCenter.isBusy,
               !hasDeferredForegroundCheck {
                recordRuntimeDiagnostic("foreground.outcome", "retry_after_sync_busy")
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                startRootForegroundCheckIfAllowed(source: source, forceIncremental: true)
                return
            }
            if hasDeferredForegroundCheck {
                let source = deferredForegroundSource ?? .rootForeground
                let forceIncremental = deferredForegroundForceIncremental
                hasDeferredForegroundCheck = false
                deferredForegroundSource = nil
                deferredForegroundForceIncremental = false
                startRootForegroundCheckIfAllowed(source: source, forceIncremental: forceIncremental)
            }
        }
    }

    private func recordRuntimeDiagnostic(_ key: String, _ value: String) {
        UserDefaults.standard.set(value, forKey: "task114.runtime.\(key)")
    }

    private func recordRuntimeDiagnostic(_ key: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: "task114.runtime.\(key)")
    }

    private func recordRuntimeDiagnostic(_ key: String, _ value: TimeInterval) {
        UserDefaults.standard.set(value, forKey: "task114.runtime.\(key)")
    }

    private var isTask114FullPullHarnessRunning: Bool {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let value = environment["TASK114_IOS_FULL_PULL"] ?? environment["TEST_RUNNER_TASK114_IOS_FULL_PULL"]
        return value == "1" || value?.lowercased() == "true"
        #else
        return false
        #endif
    }

    private func cancelRootForegroundCheck() {
        hasDeferredForegroundCheck = false
        deferredForegroundSource = nil
        deferredForegroundForceIncremental = false
        viewModel.requestLifecycleInterruptionForBackground()
        foregroundTask?.cancel()
        foregroundTask = nil
    }

    private func handleRootAction(_ actionID: SupabaseManualSyncPresentationActionID?) {
        switch actionID {
        case .reviewChanges:
            selectedTab = 3
        case .signIn:
            if authViewModel.canSignIn {
                authViewModel.signInWithGoogle()
            } else {
                selectedTab = 3
            }
        case .retry:
            guard foregroundTask == nil,
                  let mode = viewModel.runMode(for: .retry) else { return }
            foregroundTask = Task { @MainActor in
                await viewModel.start(with: mode)
                foregroundTask = nil
            }
        case .checkCloud, .downloadCloudDatabase:
            startRootForegroundCheckIfAllowed()
        case .realignData, .syncNow, .sendCloudChanges, .cancel, .none:
            selectedTab = 3
        }
    }
}

private struct SupabaseManualSyncRootForegroundBanner: View {
    let state: SupabaseManualSyncRootPresentationState
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: state.systemImage)
                .imageScale(.medium)
                .foregroundStyle(iconTint)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)

                if let progress = state.progressState {
                    Text(progress.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let countText = progress.countText {
                        Text(countText)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    if let percentage = progress.percentage {
                        ProgressView(value: percentage)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 180)
                    } else if progress.isActive {
                        ProgressView()
                            .controlSize(.small)
                    }
                } else if let detail = state.detail,
                   !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if let actionTitle = publicRemediationActionTitle {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilityLabel)
        .transition(reduceMotion ? .identity : .move(edge: .top).combined(with: .opacity))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: state.kind)
    }

    private var publicRemediationActionTitle: String? {
        switch state.primaryActionID {
        case .signIn, .retry:
            return state.primaryActionTitle
        case .checkCloud, .downloadCloudDatabase, .realignData, .reviewChanges, .sendCloudChanges, .syncNow, .cancel, .none:
            return nil
        }
    }

    private var iconTint: Color {
        switch state.kind {
        case .hidden:
            return .secondary
        case .checking:
            return .accentColor
        case .changesFound:
            return .accentColor
        case .blockedAuth, .recoverableError:
            return .orange
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SupabaseAuthViewModel(authService: nil))
        .modelContainer(
            for: [
                Product.self,
                Supplier.self,
                ProductCategory.self,
                HistoryEntry.self,
                ProductPrice.self,
                LocalPendingChange.self
            ],
            inMemory: true
        )
}
