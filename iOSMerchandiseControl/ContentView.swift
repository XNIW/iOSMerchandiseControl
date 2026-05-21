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
        syncEventOutboxDrainRecorder: (any SyncEventRecording)? = nil
    ) {
        self.supabaseInventoryService = supabaseInventoryService
        self.supabasePullPreviewService = supabasePullPreviewService
        self.supabaseManualPushService = supabaseManualPushService
        self.syncEventOutboxDrainRecorder = syncEventOutboxDrainRecorder
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
    @State private var reconnectScheduler: AutomaticSyncReconnectScheduler?
    @State private var reconnectObserver: AutomaticSyncNetworkReachabilityObserver?

    private let content: (SupabaseManualSyncViewModel, @escaping () -> Void) -> Content

    init(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        inventoryService: SupabaseInventoryService?,
        pullPreviewService: SupabasePullPreviewService?,
        manualPushService: SupabaseManualPushService?,
        activityRecorder: (any SyncEventRecording)?,
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
    }

    var body: some View {
        content(viewModel, cancelRootForegroundCheck)
            .safeAreaInset(edge: .top, spacing: 0) {
                rootBanner
            }
            .task {
                startReconnectObserverIfNeeded()
                guard !didReachInteractiveUI else { return }
                syncAuthPresentationContext()
                await Task.yield()
                didReachInteractiveUI = true
                reconnectScheduler?.setForeground(scenePhase == .active)
                startRootForegroundCheckIfAllowed()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    reconnectScheduler?.setForeground(true)
                    syncAuthPresentationContext()
                    guard didReachInteractiveUI else { return }
                    startRootForegroundCheckIfAllowed()
                case .background:
                    reconnectScheduler?.setForeground(false)
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
                hasDeferredForegroundCheck = false
                startRootForegroundCheckIfAllowed()
            }
            .onDisappear {
                reconnectObserver?.cancel()
                reconnectObserver = nil
                reconnectScheduler = nil
            }
    }

    private func handleAuthPresentationChanged() {
        syncAuthPresentationContext()
        guard didReachInteractiveUI,
              scenePhase == .active else { return }
        startRootForegroundCheckIfAllowed()
    }

    private func syncAuthPresentationContext() {
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
            startRootForegroundCheckIfAllowed(source: .networkReconnect)
        }
        scheduler.setForeground(scenePhase == .active)
        let observer = AutomaticSyncNetworkReachabilityObserver(scheduler: scheduler)
        observer.start()
        reconnectScheduler = scheduler
        reconnectObserver = observer
    }

    private func startRootForegroundCheckIfAllowed(
        source: SupabaseManualSyncSemiAutomaticTriggerSource = .rootForeground
    ) {
        guard scenePhase == .active else { return }
        guard foregroundTask == nil else { return }
        guard !activityCenter.isBusy else {
            hasDeferredForegroundCheck = true
            viewModel.markForegroundCheckSkippedBecauseBusy()
            return
        }

        foregroundTask = Task { @MainActor in
            _ = await viewModel.startForegroundSemiAutomaticCheckIfAllowed(source: source)
            foregroundTask = nil
        }
    }

    private func cancelRootForegroundCheck() {
        hasDeferredForegroundCheck = false
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
