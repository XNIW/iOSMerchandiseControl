import Combine
import SwiftUI
import SwiftData

private struct RootRecoveryReplacementPreflight: Equatable {
    let userID: UUID
    let storeIdentity: LocalStoreIdentity
}

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

    func isExclusivelyActive(
        _ reason: ForegroundCloudWorkflowActivityReason,
        token: UUID
    ) -> Bool {
        activeTokens.count == 1 && activeTokens[token.uuidString] == reason
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

    func isExclusivelyActive(
        _ reason: ForegroundCloudWorkflowActivityReason,
        token: UUID
    ) -> Bool {
        store.isExclusivelyActive(reason, token: token)
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
    private let shopDeviceRegistrationService: ShopDeviceRegistrationService?

    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("appLanguage") private var appLanguage: String = "system"
    @AppStorage(SelectedShopStore.localAuthorizationRevisionKey) private var localAuthorizationRevision = 0
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    @EnvironmentObject private var syncStoreGenerationController: SyncStoreGenerationController
    @EnvironmentObject private var productImageStore: ProductImageStore
    @Environment(\.localRootPresentationState) private var localPresentation
    @Environment(\.localModelGenerationIsCurrent) private var modelGenerationIsCurrent
    @StateObject private var excelSession = ExcelSessionViewModel()
    @StateObject private var foregroundActivityCenter = ForegroundCloudWorkflowActivityCenter()
    @StateObject private var syncStateStore: SyncStateStore
    @StateObject private var shopContextStore: ShopContextStore
    @State private var selectedTab = Self.initialSelectedTab()
    @State private var mountedPresentationID: String?
    @State private var isCorruptJournalReviewPresented = false
    @State private var corruptJournalReplacementTask: Task<Void, Never>?
    @State private var corruptJournalReplacementError: String?

    init(
        supabaseTransportClient: SupabaseTransportClient? = nil,
        supabasePullPreviewService: SupabasePullPreviewService? = nil,
        syncEventOutboxDrainRecorder: (any SyncEventRecording)? = nil,
        syncEventSignalWatcher: SupabaseSyncEventSignalWatcher? = nil,
        shopDeviceRegistrationService: ShopDeviceRegistrationService? = nil,
        shopContextOverride: ShopContextStore? = nil,
        syncStateOverride: SyncStateStore? = nil
    ) {
        self.supabaseTransportClient = supabaseTransportClient
        self.supabasePullPreviewService = supabasePullPreviewService
        self.syncEventOutboxDrainRecorder = syncEventOutboxDrainRecorder
        self.syncEventSignalWatcher = syncEventSignalWatcher
        self.shopDeviceRegistrationService = shopDeviceRegistrationService
        _syncStateStore = StateObject(wrappedValue: syncStateOverride ?? SyncStateStore())
        _shopContextStore = StateObject(
            wrappedValue: shopContextOverride ?? ShopContextStore(
                fetcher: supabaseTransportClient.map { MobileLinkedShopService(remote: $0) } ?? EmptyLinkedShopFetcher()
            )
        )
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
        if value == "database" {
            return 1
        }
        #endif
        return 0
    }

    var body: some View {
        Group {
            if isCurrentModelGeneration {
                activeRoot
            }
        }
    }

    private var activeRoot: some View {
        AppSyncRootHost(
            context: modelContext,
            authViewModel: supabaseAuthViewModel,
            supabaseTransportClient: supabaseTransportClient,
            activityRecorder: syncEventOutboxDrainRecorder,
            syncEventSignalWatcher: syncEventSignalWatcher,
            syncStateStore: syncStateStore,
            selectedTab: $selectedTab,
            activityCenter: foregroundActivityCenter,
            shopContextStore: shopContextStore,
            syncStoreGenerationController: syncStoreGenerationController,
            shopDeviceRegistrationService: shopDeviceRegistrationService
        ) { syncOrchestrator in
            let hidesBusinessData = hidesBusinessDataForPendingRecovery
            Group {
                if hidesBusinessData {
                    SyncReplacementPrivacyGate(
                        state: syncStateStore.state,
                        isSignedIn: supabaseAuthViewModel.isSignedIn,
                        canSignIn: supabaseAuthViewModel.canSignIn,
                        isBusy: supabaseAuthViewModel.isTransitioning
                            || syncOrchestrator.rootPresentationState.kind == .checking
                            || corruptJournalReplacementTask != nil,
                        requiresManualReview: requiresManualRecoveryReview,
                        signIn: supabaseAuthViewModel.signInWithGoogle,
                        retry: syncOrchestrator.retryPendingRecoveryRootAction,
                        review: { isCorruptJournalReviewPresented = true }
                    )
                    .accountSyncDecisionDialog(
                        isPresented: $isCorruptJournalReviewPresented,
                        decision: Self.interruptedRecoveryDecision,
                        isCloudReplacementEnabled: isCorruptJournalReplacementEnabled,
                        onChoose: { choice in
                            switch choice {
                            case .discardLocalAndBind:
                                beginCorruptJournalReplacement(using: syncOrchestrator)
                            default:
                                // Cancel/back/keep-local deliberately leave the raw
                                // latch, database, binding and network untouched.
                                isCorruptJournalReviewPresented = false
                            }
                        }
                    )
                    .alert(
                        L("options.accountDecision.error.title"),
                        isPresented: Binding(
                            get: { corruptJournalReplacementError != nil },
                            set: { if !$0 { corruptJournalReplacementError = nil } }
                        )
                    ) {
                        Button(L("common.ok"), role: .cancel) {}
                    } message: {
                        Text(corruptJournalReplacementError ?? "")
                    }
                } else {
                    tabContent(syncOrchestrator: syncOrchestrator)
                }
            }
            .onChange(of: hidesBusinessData) { _, hidden in
                if hidden, syncStoreGenerationController.activeManifest == nil {
                    syncStoreGenerationController.startLocalBodyQualification(ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID)
                }
            }
        }
        .environment(\.foregroundCloudWorkflowActivityCenter, foregroundActivityCenter)
        .environmentObject(shopContextStore)
        .foregroundCloudWorkflowActivity(.importExcel, isActive: excelSession.isLoading)
        .localeOverride(for: appLanguage)
        .preferredColorScheme(resolvedColorScheme)
        .onAppear { restoreLocalPresentation() }
        .onChange(of: selectedTab) { _, value in
            localPresentation?.update(presentationID: mountedPresentationID) { $0.selectedTab = value }
        }
        .onChange(of: supabaseAuthViewModel.localMutationOwnerUserID) { _, _ in
            restoreLocalPresentation()
            syncStoreGenerationController.startLocalBodyQualification(ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID)
        }
        .onChange(of: localAuthorizationRevision) { _, _ in restoreLocalPresentation() }
        .task { syncStoreGenerationController.startLocalBodyQualification(ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID) }
        .onChange(of: syncStateStore.state.phase) { _, _ in
            syncStoreGenerationController.startLocalBodyQualification(ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID)
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

    private var isCurrentModelGeneration: Bool {
        modelGenerationIsCurrent() && (localPresentation?.isCurrent(presentationID: mountedPresentationID) ?? true)
    }

    private func restoreLocalPresentation() {
        guard isCurrentModelGeneration else { return }
        mountedPresentationID = syncStoreGenerationController.presentationID
        let values = localPresentation?.admit(
            manifest: syncStoreGenerationController.activeManifest,
            ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID,
            presentationID: syncStoreGenerationController.presentationID,
            localAccessPermitted: Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                modelContainer: modelContext.container,
                ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID
            )
        )
        if let selected = values?.selectedTab { selectedTab = selected }
    }

    private var hidesBusinessDataForPendingRecovery: Bool {
        #if DEBUG
        if Task144RootObservation.enabled { return observeTask144RootPrivacyChoice() }
        #endif
        _ = localAuthorizationRevision
        if let owner = supabaseAuthViewModel.sessionInfo?.userID,
           let shop = SelectedShopStore().selectedShop(accountHash: AccountBindingStore.accountHash(for: owner)),
           let device = try? DeviceInstallIDStore().requireDeviceInstallID(),
           SelectedShopStore().hasConfirmedDeviceDenial(accountHash: AccountBindingStore.accountHash(for: owner),
             shopID: shop.shopID, deviceIdentityHash: DeviceInstallIDStore.identityHash(for: device)) {
            return true
        }
        if syncStoreGenerationController.activeManifest != nil {
            return !Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                modelContainer: modelContext.container,
                ownerUserID: supabaseAuthViewModel.sessionInfo?.userID
            )
        }
        if syncStoreGenerationController.permitsScopedEmptyRoot(ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID) {
            return false
        }
        return AccountBindingStore().hasPendingReplacementJournal
            && !Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                modelContainer: modelContext.container,
                ownerUserID: supabaseAuthViewModel.sessionInfo?.userID
            )
    }

    #if DEBUG
    private func observeTask144RootPrivacyChoice() -> Bool {
        let observation = Task144RootObservation.Evaluation("root-privacy", callsite: "ContentView.hidesBusinessDataForPendingRecovery")
        var hidden = false
        var branch = "NOT_SELECTED"
        defer { observation.finish(hidden, branch: branch, firstFalseLabel: "first-false-branch-condition") }
        _ = localAuthorizationRevision
        if let owner = observation.optional(supabaseAuthViewModel.sessionInfo?.userID, "owner"),
           let shop = observation.optional(SelectedShopStore().selectedShop(accountHash: AccountBindingStore.accountHash(for: owner)), "selected-shop"),
           let device = observation.attempt("device", { try DeviceInstallIDStore().requireDeviceInstallID() }),
           observation.check(SelectedShopStore().hasConfirmedDeviceDenial(accountHash: AccountBindingStore.accountHash(for: owner),
             shopID: shop.shopID, deviceIdentityHash: DeviceInstallIDStore.identityHash(for: device)), "confirmed-denial") {
            branch = "confirmed-device-denial"; hidden = true
            return true
        }
        if observation.check(syncStoreGenerationController.activeManifest != nil, "active-manifest-present") {
            branch = "active-local-access"
            hidden = !observation.check(Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                modelContainer: modelContext.container,
                ownerUserID: supabaseAuthViewModel.sessionInfo?.userID), "existing-local-access")
            return hidden
        }
        if observation.check(syncStoreGenerationController.permitsScopedEmptyRoot(
            ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID), "scoped-empty-admitted") {
            branch = "scoped-empty"; hidden = false
            return false
        }
        if observation.check(AccountBindingStore().hasPendingReplacementJournal, "pending-journal") {
            branch = "pending-local-access"
            hidden = !observation.check(Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                modelContainer: modelContext.container,
                ownerUserID: supabaseAuthViewModel.sessionInfo?.userID), "fallback-local-access")
            return hidden
        }
        branch = "no-pending-journal"; hidden = false
        return false
    }
    #endif

    private var hasUndecodableRecoveryJournal: Bool {
        let store = AccountBindingStore()
        return store.hasPendingReplacementJournal && store.pendingRecoveryJournal == nil
    }

    private var requiresManualRecoveryReview: Bool {
        if hasUndecodableRecoveryJournal { return true }
        let bindingStore = AccountBindingStore()
        guard let journal = bindingStore.pendingRecoveryJournal,
              journal.mode == .sameScopeRecovery,
              journal.phase == .prepared else { return false }
        guard let ownerUserID = authenticatedUserIDForCorruptJournal else { return false }
        guard let scope = try? Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: ownerUserID,
            allowsPendingSameScopeRecovery: true
        ) else {
            // Keep the safe Review entry point visible. Its destructive button
            // remains disabled until authenticated shop discovery is verified.
            return true
        }
        guard let work = try? SameScopeRecoveryActiveWorkInspector.snapshot(
            container: syncStoreGenerationController.modelContainer,
            scope: scope
        ) else { return true }
        return !work.isDrained
    }

    private static let interruptedRecoveryDecision = AccountSyncDecision(
        action: .promptOwnerStoreReview(.replacementInterrupted),
        defaultSafeAction: .cancel,
        remoteMutation: .blockedUntilUserDecision,
        pendingHandling: .keepPendingWithOriginalOwner,
        conflictPolicy: .noCrossAccountMerge,
        rollback: .cancelLeavesRemoteUntouched,
        testID: "OWNER-STORE-replacementInterrupted"
    )

    private var authenticatedUserIDForCorruptJournal: UUID? {
        AccountSyncDecisionDialogPolicy.authenticatedUserID(
            isSignedIn: supabaseAuthViewModel.isSignedIn,
            isTransitioning: supabaseAuthViewModel.isTransitioning,
            sessionInfo: supabaseAuthViewModel.sessionInfo
        )
    }

    private var corruptJournalReplacementPreflight: RootRecoveryReplacementPreflight? {
        guard requiresManualRecoveryReview,
              let userID = authenticatedUserIDForCorruptJournal else { return nil }
        let accountHash = AccountBindingStore.accountHash(for: userID)
        let selectedShopStore = SelectedShopStore()
        guard shopContextStore.context.accountHash == accountHash,
              shopContextStore.context.syncAllowed,
              let resolvedShop = shopContextStore.context.selectedShop,
              selectedShopStore.isResolutionReady(accountHash: accountHash),
              let persistedShop = selectedShopStore.selectedShop(accountHash: accountHash),
              resolvedShop.shopID == persistedShop.shopID,
              resolvedShop.localStoreIdentity == persistedShop.localStoreIdentity,
              persistedShop.localStoreIdentity != .anonymous else { return nil }
        return RootRecoveryReplacementPreflight(
            userID: userID,
            storeIdentity: persistedShop.localStoreIdentity
        )
    }

    private var isCorruptJournalReplacementEnabled: Bool {
        corruptJournalReplacementPreflight != nil
            && corruptJournalReplacementTask == nil
            && !foregroundActivityCenter.isBusy
            && productImageStore.canBeginAccountStoreReplacement
    }

    private func beginCorruptJournalReplacement(using runtime: SyncOrchestrator) {
        isCorruptJournalReviewPresented = false
        guard corruptJournalReplacementTask == nil,
              let initialPreflight = corruptJournalReplacementPreflight,
              !foregroundActivityCenter.isBusy,
              productImageStore.beginAccountStoreReplacementLease() else {
            corruptJournalReplacementError = L("options.accountDecision.error.busy")
            return
        }
        let bindingStore = AccountBindingStore()
        let coordinator = AccountStoreReplacementCoordinator(
            context: modelContext,
            bindingStore: bindingStore
        )
        let activityToken = UUID()
        foregroundActivityCenter.setActive(.cloudReview, true, token: activityToken)
        corruptJournalReplacementTask = Task { @MainActor in
            defer {
                productImageStore.endAccountStoreReplacementLease()
                foregroundActivityCenter.setActive(.cloudReview, false, token: activityToken)
                corruptJournalReplacementTask = nil
            }
            do {
                _ = try await runtime.performAccountStoreReplacement {
                    guard let currentPreflight = corruptJournalReplacementPreflight,
                          currentPreflight == initialPreflight,
                          foregroundActivityCenter.isExclusivelyActive(
                            .cloudReview,
                            token: activityToken
                          ) else {
                        throw AccountStoreReplacementError.replacementJournalUnavailable
                    }
                    return try coordinator.discardLocalDataAndBind(
                        userID: initialPreflight.userID,
                        storeIdentity: initialPreflight.storeIdentity
                    )
                }
            } catch {
                corruptJournalReplacementError = error.localizedDescription
            }
        }
    }

    @ViewBuilder
    private func tabContent(syncOrchestrator: SyncOrchestrator) -> some View {
        TabView(selection: $selectedTab) {
            // TAB 1: Inventario
            NavigationStack {
                InventoryHomeView()
                    .environmentObject(excelSession)
                    .environmentObject(shopContextStore)
            }
            .tabItem {
                Label(L("tab.inventory"), systemImage: "doc.on.doc")
            }
            .tag(0)

            // TAB 2: Database
            NavigationStack {
                DatabaseView(isFirstSnapshotPreparing: syncStoreGenerationController.permitsScopedEmptyRoot(
                    ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID))
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
                    syncEventOutboxDrainRecorder: syncEventOutboxDrainRecorder,
                    deviceAuthorization: shopDeviceRegistrationService,
                    accountStoreReplacementRuntime: syncOrchestrator
                )
            }
            .tabItem {
                Label(L("tab.options"), systemImage: "gearshape")
            }
            .tag(3)
        }
    }
}

private struct SyncReplacementPrivacyGate: View {
    let state: SyncState
    let isSignedIn: Bool
    let canSignIn: Bool
    let isBusy: Bool
    let requiresManualReview: Bool
    let signIn: () -> Void
    let retry: () -> Void
    let review: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            if isBusy { ProgressView() }
            Text(L("options.supabase.automaticSync.phase.recoveryRequired"))
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(L(SyncRecoveryGatePresentation.statusKey(state: state, isBusy: isBusy)))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("sync-recovery-phase")
            if isBusy, let progress = state.recoveryProgress, let domain = progress.domain {
                Text(String(format: L("options.supabase.automaticSync.recovery.counts"),
                    L(SyncRecoveryGatePresentation.domainKey(domain)),
                    progress.pages, progress.persistedRows))
                    .font(.subheadline.monospacedDigit())
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("sync-recovery-counts")
            }
            if isBusy, let startedAt = state.startedAt {
                HStack {
                    Text(L("options.supabase.automaticSync.recovery.elapsed"))
                    Text(startedAt, style: .timer).monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("sync-recovery-elapsed")
            }
            if !isBusy, isSignedIn {
                Button(
                    L(requiresManualReview
                        ? "options.accountDecision.review"
                        : "options.supabase.automaticSync.action.retry"),
                    action: requiresManualReview ? review : retry
                )
                    .buttonStyle(.borderedProminent)
            } else if !isBusy {
                Button(L("options.supabase.automaticSync.root.action.signIn"), action: signIn)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSignIn)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .accessibilityIdentifier("sync-replacement-business-data-gate")
    }
}

private struct AppSyncRootHost<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var activityCenter: ForegroundCloudWorkflowActivityCenter
    @ObservedObject private var authViewModel: SupabaseAuthViewModel
    @ObservedObject private var shopContextStore: ShopContextStore
    @StateObject private var syncOrchestrator: SyncOrchestrator
    @Binding private var selectedTab: Int

    private let shopDeviceRegistrationService: ShopDeviceRegistrationService?
    private let content: (SyncOrchestrator) -> Content

    init(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        supabaseTransportClient: SupabaseTransportClient?,
        activityRecorder: (any SyncEventRecording)?,
        syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?,
        syncStateStore: SyncStateStore,
        selectedTab: Binding<Int>,
        activityCenter: ForegroundCloudWorkflowActivityCenter,
        shopContextStore: ShopContextStore,
        syncStoreGenerationController: SyncStoreGenerationController,
        shopDeviceRegistrationService: ShopDeviceRegistrationService?,
        @ViewBuilder content: @escaping (SyncOrchestrator) -> Content
    ) {
        _syncOrchestrator = StateObject(
            wrappedValue: SyncOrchestrator(
                automaticRuntime: SyncAutomaticRuntimeFactory.make(
                    modelContainer: context.container,
                    authViewModel: authViewModel,
                    supabaseTransportClient: supabaseTransportClient,
                    activityRecorder: activityRecorder,
                    storeGenerationController: syncStoreGenerationController,
                    stateStore: syncStateStore,
                    deviceAuthorization: shopDeviceRegistrationService
                ),
                authViewModel: authViewModel,
                activityCenter: activityCenter,
                syncEventSignalWatcher: syncEventSignalWatcher,
                stateStore: syncStateStore,
                storeGenerationController: syncStoreGenerationController,
                storeGenerationLease: syncStoreGenerationController.captureLease(for: context.container),
                decisionInputProvider: SyncDecisionInputProvider(modelContainer: context.container)
            )
        )
        _selectedTab = selectedTab
        _activityCenter = ObservedObject(wrappedValue: activityCenter)
        _authViewModel = ObservedObject(wrappedValue: authViewModel)
        _shopContextStore = ObservedObject(wrappedValue: shopContextStore)
        self.shopDeviceRegistrationService = shopDeviceRegistrationService
        self.content = content
    }

    var body: some View {
        let rootBannerState = syncOrchestrator.rootPresentationState
        let showsRootBanner = syncOrchestrator.shouldShowRootBanner(rootBannerState, selectedTab: selectedTab)

        content(syncOrchestrator)
            .padding(.top, showsRootBanner ? rootBannerReservedTopPadding(for: rootBannerState) : 0)
            .safeAreaInset(edge: .top, spacing: 0) {
                rootBanner(state: rootBannerState, isVisible: showsRootBanner)
            }
            .task {
                await refreshShopContextAndResumeSync()
                #if DEBUG
                Task144LocalAvailabilityRootFixture.current?.startIfNeeded()
                #endif
            }
            .onChange(of: scenePhase) { _, phase in
                syncOrchestrator.handleScenePhaseChanged(phase)
                if phase == .active {
                    registerShopDevice(reason: "foreground")
                }
            }
            .onChange(of: authViewModel.isTransitioning) { _, _ in
                syncOrchestrator.handleAuthPresentationChanged()
            }
            .onChange(of: authViewModel.canSignIn) { _, _ in
                syncOrchestrator.handleAuthPresentationChanged()
            }
            .onChange(of: authViewModel.sessionInfo?.userID) { _, _ in
                Task { @MainActor in
                    await refreshShopContextAndResumeSync()
                }
                syncOrchestrator.handleAuthPresentationChanged()
            }
            .onChange(of: authViewModel.isSignedIn) { _, _ in
                Task { @MainActor in
                    await refreshShopContextAndResumeSync()
                }
                syncOrchestrator.handleAuthPresentationChanged()
            }
            .onChange(of: shopContextStore.context) { _, context in
                // Revoke the previous callback's authority synchronously.
                // A suspended heartbeat must not invalidate a fresh run later.
                syncOrchestrator.handleShopContextChanged()
                Task { @MainActor in
                    #if DEBUG
                    let heldPreviousHeartbeat = await Task144LocalAvailabilityRootFixture.current?.awaitControlledShopHeartbeatForOrderingProof() ?? false
                    #endif
                    if authViewModel.isSignedIn, context.syncAllowed,
                       shopContextStore.context == context {
                        await shopDeviceRegistrationService?.registerHeartbeatAndCheck(reason: "shop_context_changed")
                    }
                    #if DEBUG
                    if heldPreviousHeartbeat { Task144LocalAvailabilityRootFixture.current?.noteControlledShopHeartbeatCompleted() }
                    #endif
                }
            }
            .onChange(of: activityCenter.activeReasons) { _, _ in
                syncOrchestrator.resumeDeferredForegroundCheckIfReady()
            }
            .onReceive(NotificationCenter.default.publisher(for: .localPendingChangesDidChange)) { _ in
                syncOrchestrator.handleLocalPendingChanges()
            }
            .onReceive(NotificationCenter.default.publisher(for: .automaticCloudCheckRequested)) { _ in
                Task { @MainActor in
                    if authViewModel.isSignedIn {
                        await shopDeviceRegistrationService?.registerCurrentOwnerDevice(
                            reason: "automatic_sync",
                            force: true
                        )
                        _ = await shopDeviceRegistrationService?.currentOwnerDeviceStatus(
                            reason: "automatic_sync",
                            force: true
                        )
                    }
                    syncOrchestrator.submitForegroundTrigger(
                        source: .rootForeground,
                        forceIncremental: true
                    )
                }
            }
            .onDisappear {
                syncOrchestrator.stop()
            }
    }

    @ViewBuilder
    private func rootBanner(state: SyncRootPresentationState, isVisible: Bool) -> some View {
        if isVisible {
            SyncRootForegroundBanner(
                state: state,
                reduceMotion: reduceMotion,
                action: { handleRootAction(state.primaryActionID) }
            )
            .padding(.horizontal, 12)
            .padding(.top, 4)
            .padding(.bottom, 2)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func rootBannerReservedTopPadding(for state: SyncRootPresentationState) -> CGFloat {
        state.kind == .checking ? 38 : 52
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

    private func registerShopDevice(reason: String) {
        guard authViewModel.isSignedIn,
              shopContextStore.context.syncAllowed,
              let shopDeviceRegistrationService else { return }
        Task {
            await shopDeviceRegistrationService.registerHeartbeatAndCheck(reason: reason)
        }
    }

    private func refreshShopContextAndResumeSync() async {
        await shopContextStore.refresh(
            ownerUserID: authViewModel.localMutationOwnerUserID
        )
        if SyncBootstrapReadiness.shouldStart(
            isSignedIn: authViewModel.isSignedIn,
            isShopSyncAllowed: shopContextStore.context.syncAllowed
        ) {
            await shopDeviceRegistrationService?.registerHeartbeatAndCheck(reason: "app_sync_bootstrap")
        }
        // Bootstrap also owns reachability and lifecycle observation. It must
        // start while auth/shop discovery is blocked; the decision/runtime
        // gates still prevent every business call until the exact scope is
        // authenticated and resolved.
        await syncOrchestrator.bootstrap(scenePhase: scenePhase)
    }
}

private struct SyncRootForegroundBanner: View {
    let state: SyncRootPresentationState
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: state.systemImage)
                .imageScale(.small)
                .foregroundStyle(iconTint)
                .frame(width: 22, height: 22)
                .background(iconTint.opacity(0.14), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(L(state.titleKey))
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)

                if let detailKey = visibleDetailKey {
                    Text(L(detailKey))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                }
            }

            if let actionTitle = publicRemediationActionTitle {
                Button(L(actionTitle), action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: maxBannerWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(.regularMaterial, in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 7, y: 3)
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

    private var visibleDetailKey: String? {
        state.kind == .checking ? nil : state.detailKey
    }

    private var maxBannerWidth: CGFloat {
        state.kind == .checking ? 280 : 340
    }

    private var accessibilityLabel: String {
        [
            L(state.titleKey),
            visibleDetailKey.map { L($0) },
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
        case .blockedAuth, .deviceBlocked, .recoverableError:
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
