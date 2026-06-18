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
    private let supabaseTransportClient: SupabaseTransportClient?
    private let supabasePullPreviewService: SupabasePullPreviewService?
    private let syncEventOutboxDrainRecorder: (any SyncEventRecording)?
    private let syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?
    private let historySessionSyncService: HistorySessionSyncService?
    private let remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?

    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("appLanguage") private var appLanguage: String = "system"
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    @StateObject private var excelSession = ExcelSessionViewModel()
    @StateObject private var foregroundActivityCenter = ForegroundCloudWorkflowActivityCenter()
    @StateObject private var syncStateStore = SyncStateStore()
    @State private var selectedTab = Self.initialSelectedTab()

    init(
        supabaseTransportClient: SupabaseTransportClient? = nil,
        supabasePullPreviewService: SupabasePullPreviewService? = nil,
        syncEventOutboxDrainRecorder: (any SyncEventRecording)? = nil,
        syncEventSignalWatcher: SupabaseSyncEventSignalWatcher? = nil
    ) {
        self.supabaseTransportClient = supabaseTransportClient
        self.supabasePullPreviewService = supabasePullPreviewService
        self.syncEventOutboxDrainRecorder = syncEventOutboxDrainRecorder
        self.syncEventSignalWatcher = syncEventSignalWatcher
        self.historySessionSyncService = supabaseTransportClient.map {
            HistorySessionSyncService(remote: HistorySessionRemoteSupabaseAdapter(remote: $0))
        }
        if let supabaseTransportClient {
            self.remoteCountFetcher = OptionsRemoteCountSupabaseAdapter(remote: supabaseTransportClient)
        } else {
            self.remoteCountFetcher = nil
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

    private static func initialSelectedTab() -> Int {
        #if DEBUG
        let value = ProcessInfo.processInfo.environment["TASK131_INITIAL_TAB"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if value == "options" {
            return 3
        }
        #endif
        return 0
    }

    var body: some View {
        AppSyncRootHost(
            context: modelContext,
            authViewModel: supabaseAuthViewModel,
            supabaseTransportClient: supabaseTransportClient,
            activityRecorder: syncEventOutboxDrainRecorder,
            syncEventSignalWatcher: syncEventSignalWatcher,
            syncStateStore: syncStateStore,
            selectedTab: $selectedTab,
            activityCenter: foregroundActivityCenter
        ) {
            tabContent()
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
    private func tabContent() -> some View {
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
                    remoteCountFetcher: remoteCountFetcher,
                    supabasePullPreviewService: supabasePullPreviewService,
                    syncStateStore: syncStateStore,
                    syncEventOutboxDrainRecorder: syncEventOutboxDrainRecorder
                )
            }
            .tabItem {
                Label(L("tab.options"), systemImage: "gearshape")
            }
            .tag(3)
        }
    }
}

private struct AppSyncRootHost<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var activityCenter: ForegroundCloudWorkflowActivityCenter
    @ObservedObject private var authViewModel: SupabaseAuthViewModel
    @StateObject private var syncOrchestrator: SyncOrchestrator
    @Binding private var selectedTab: Int

    private let content: () -> Content

    init(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        supabaseTransportClient: SupabaseTransportClient?,
        activityRecorder: (any SyncEventRecording)?,
        syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?,
        syncStateStore: SyncStateStore,
        selectedTab: Binding<Int>,
        activityCenter: ForegroundCloudWorkflowActivityCenter,
        @ViewBuilder content: @escaping () -> Content
    ) {
        _syncOrchestrator = StateObject(
            wrappedValue: SyncOrchestrator(
                automaticRuntime: SyncAutomaticRuntimeFactory.make(
                    modelContainer: context.container,
                    authViewModel: authViewModel,
                    supabaseTransportClient: supabaseTransportClient,
                    activityRecorder: activityRecorder
                ),
                authViewModel: authViewModel,
                activityCenter: activityCenter,
                syncEventSignalWatcher: syncEventSignalWatcher,
                stateStore: syncStateStore,
                decisionInputProvider: SyncDecisionInputProvider(modelContainer: context.container)
            )
        )
        _selectedTab = selectedTab
        _activityCenter = ObservedObject(wrappedValue: activityCenter)
        _authViewModel = ObservedObject(wrappedValue: authViewModel)
        self.content = content
    }

    var body: some View {
        content()
            .safeAreaInset(edge: .top, spacing: 0) {
                rootBanner
            }
            .task {
                await syncOrchestrator.bootstrap(scenePhase: scenePhase)
            }
            .onChange(of: scenePhase) { _, phase in
                syncOrchestrator.handleScenePhaseChanged(phase)
            }
            .onChange(of: authViewModel.isTransitioning) { _, _ in
                syncOrchestrator.handleAuthPresentationChanged()
            }
            .onChange(of: authViewModel.canSignIn) { _, _ in
                syncOrchestrator.handleAuthPresentationChanged()
            }
            .onChange(of: authViewModel.sessionInfo?.userID) { _, _ in
                syncOrchestrator.handleAuthPresentationChanged()
            }
            .onChange(of: authViewModel.isSignedIn) { _, _ in
                syncOrchestrator.handleAuthPresentationChanged()
            }
            .onChange(of: activityCenter.activeReasons) { _, _ in
                syncOrchestrator.resumeDeferredForegroundCheckIfReady()
            }
            .onReceive(NotificationCenter.default.publisher(for: .localPendingChangesDidChange)) { _ in
                syncOrchestrator.handleLocalPendingChanges()
            }
            .onReceive(NotificationCenter.default.publisher(for: .automaticCloudCheckRequested)) { _ in
                syncOrchestrator.submitForegroundTrigger(
                    source: .rootForeground,
                    forceIncremental: true
                )
            }
            .onDisappear {
                syncOrchestrator.stop()
            }
    }

    @ViewBuilder
    private var rootBanner: some View {
        let state = syncOrchestrator.rootPresentationState
        if syncOrchestrator.shouldShowRootBanner(state, selectedTab: selectedTab) {
            SyncRootForegroundBanner(
                state: state,
                reduceMotion: reduceMotion,
                action: { handleRootAction(state.primaryActionID) }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func handleRootAction(_ actionID: SyncRootPresentationActionID?) {
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
            syncOrchestrator.retryRootActionIfPossible()
        case .none:
            break
        }
    }
}

private struct SyncRootForegroundBanner: View {
    let state: SyncRootPresentationState
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
                Text(L(state.titleKey))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)

                if let detailKey = state.detailKey {
                    Text(L(detailKey))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if let actionTitle = publicRemediationActionTitle {
                Button(L(actionTitle), action: action)
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
        .accessibilityLabel(accessibilityLabel)
        .transition(reduceMotion ? .identity : .move(edge: .top).combined(with: .opacity))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: state.kind)
    }

    private var publicRemediationActionTitle: String? {
        switch state.primaryActionID {
        case .signIn, .retry:
            return state.primaryActionTitleKey
        case .reviewChanges, .none:
            return nil
        }
    }

    private var accessibilityLabel: String {
        [
            L(state.titleKey),
            state.detailKey.map { L($0) },
            state.primaryActionTitleKey.map { L($0) }
        ]
        .compactMap { $0 }
        .joined(separator: ". ")
    }

    private var iconTint: Color {
        switch state.kind {
        case .hidden:
            return .secondary
        case .checking:
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
