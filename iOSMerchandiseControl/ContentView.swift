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

private actor PriceHistoryBackfillRunner {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func runIfNeeded() async throws -> Int {
        let modelContainer = self.modelContainer
        return try await MainActor.run {
            let backgroundContext = ModelContext(modelContainer)
            return try PriceHistoryBackfillService.backfillIfNeeded(context: backgroundContext)
        }
    }
}

struct ContentView: View {
    private let supabaseInventoryService: SupabaseInventoryService?
    private let supabasePullPreviewService: SupabasePullPreviewService?
    private let supabaseSyncEventPreviewService: SupabaseSyncEventPreviewService?
    private let supabaseManualPushService: SupabaseManualPushService?
    private let syncEventOutboxDrainRecorder: (any SyncEventRecording)?

    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("appLanguage") private var appLanguage: String = "system"
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    @StateObject private var excelSession = ExcelSessionViewModel()
    @StateObject private var foregroundActivityCenter = ForegroundCloudWorkflowActivityCenter()
    @State private var selectedTab = 0
    @State private var didSchedulePriceHistoryBackfillThisLaunch = false
#if DEBUG
    @State private var didRunTask088ProductPriceSmoke = false
#endif

    init(
        supabaseInventoryService: SupabaseInventoryService? = nil,
        supabasePullPreviewService: SupabasePullPreviewService? = nil,
        supabaseSyncEventPreviewService: SupabaseSyncEventPreviewService? = nil,
        supabaseManualPushService: SupabaseManualPushService? = nil,
        syncEventOutboxDrainRecorder: (any SyncEventRecording)? = nil
    ) {
        self.supabaseInventoryService = supabaseInventoryService
        self.supabasePullPreviewService = supabasePullPreviewService
        self.supabaseSyncEventPreviewService = supabaseSyncEventPreviewService
        self.supabaseManualPushService = supabaseManualPushService
        self.syncEventOutboxDrainRecorder = syncEventOutboxDrainRecorder
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
        .task {
            schedulePriceHistoryBackfillIfNeeded()
#if DEBUG
            if isTask087SmokeLaunchRequested {
                selectedTab = 3
            }
            if isTask088ProductPriceSmokeLaunchRequested {
                selectedTab = 3
                runTask088ProductPriceSmokeIfRequested()
            }
#endif
        }
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
                HistoryView()
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
                    supabaseSyncEventPreviewService: supabaseSyncEventPreviewService,
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

    @MainActor
    private func schedulePriceHistoryBackfillIfNeeded() {
        guard !didSchedulePriceHistoryBackfillThisLaunch else { return }
        didSchedulePriceHistoryBackfillThisLaunch = true

        let runner = PriceHistoryBackfillRunner(modelContainer: modelContext.container)
        Task(priority: .utility) {
            do {
                let inserted = try await runner.runIfNeeded()
                #if DEBUG
                if inserted > 0 {
                    debugPrint("[Backfill] Inseriti \(inserted) record ProductPrice legacy.")
                }
                #endif
            } catch {
                #if DEBUG
                debugPrint("[Backfill] Errore durante il backfill prezzi: \(error)")
                #endif
            }
        }
    }

#if DEBUG
    private var isTask087SmokeLaunchRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("--task087-smoke")
            || ProcessInfo.processInfo.arguments.contains("--task087-smoke-run")
            || ProcessInfo.processInfo.environment["TASK087_SMOKE"] == "1"
            || ProcessInfo.processInfo.environment["TASK087_SMOKE_RUN"] == "1"
    }

    private var isTask088ProductPriceSmokeLaunchRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("--task088-price-smoke-run")
            || ProcessInfo.processInfo.environment["TASK088_PRICE_SMOKE_RUN"] == "1"
    }

    @MainActor
    private func runTask088ProductPriceSmokeIfRequested() {
        guard isTask088ProductPriceSmokeLaunchRequested,
              !didRunTask088ProductPriceSmoke else {
            return
        }
        didRunTask088ProductPriceSmoke = true

        guard let supabaseInventoryService else {
            debugPrint("[Task088Smoke] outcome=blocked reason=inventory_service_missing")
            return
        }

        Task { @MainActor in
            do {
                let result = try await SupabaseTask088ProductPriceSmokeService(
                    inventoryService: supabaseInventoryService
                ).run()
                debugPrint("[Task088Smoke] outcome=ok \(result.privacySafeSummary)")
            } catch let error as SupabaseTask088ProductPriceSmokeError {
                debugPrint("[Task088Smoke] outcome=blocked \(error.safeMessage)")
            } catch SupabaseInventoryServiceError.sessionMissing {
                debugPrint("[Task088Smoke] outcome=blocked reason=session_missing")
            } catch let error as SupabaseInventoryServiceError {
                debugPrint("[Task088Smoke] outcome=blocked reason=\(error.safeDiagnosticDetail ?? "inventory_service_error")")
            } catch {
                debugPrint("[Task088Smoke] outcome=blocked reason=unexpected_error")
            }
        }
    }
#endif
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
                guard !didReachInteractiveUI else { return }
                await Task.yield()
                didReachInteractiveUI = true
                startRootForegroundCheckIfAllowed()
            }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    guard didReachInteractiveUI else { return }
                    startRootForegroundCheckIfAllowed()
                case .background:
                    cancelRootForegroundCheck()
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
            .onChange(of: activityCenter.activeReasons) { _, _ in
                guard didReachInteractiveUI,
                      hasDeferredForegroundCheck,
                      !activityCenter.isBusy else { return }
                hasDeferredForegroundCheck = false
                startRootForegroundCheckIfAllowed()
            }
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
        guard state.primaryActionID != nil else { return false }
        guard selectedTab != 3 else { return false }
        guard !activityCenter.isBusy else { return false }
        return true
    }

    private func startRootForegroundCheckIfAllowed() {
        guard scenePhase == .active else { return }
        guard foregroundTask == nil else { return }
        guard !activityCenter.isBusy else {
            hasDeferredForegroundCheck = true
            viewModel.markForegroundCheckSkippedBecauseBusy()
            return
        }

        foregroundTask = Task { @MainActor in
            _ = await viewModel.startForegroundSemiAutomaticCheckIfAllowed(source: .rootForeground)
            foregroundTask = nil
        }
    }

    private func cancelRootForegroundCheck() {
        hasDeferredForegroundCheck = false
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
        case .checkCloud:
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

                if let detail = state.detail,
                   !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if let actionTitle = state.primaryActionTitle {
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
