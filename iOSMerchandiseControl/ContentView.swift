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

    var blocksAutomaticSync: Bool {
        activeTokens.values.contains { $0 != .editing }
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

    var blocksAutomaticSync: Bool { store.blocksAutomaticSync }

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
    private let catalogConflictResolutionService: CatalogConflictResolutionService?

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
    @State private var currentSyncOrchestrator: SyncOrchestrator?
    @State private var runtimePresentationID: String?
    @State private var rootIndicatorState: SyncRootPresentationState = .hidden
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
        syncStateOverride: SyncStateStore? = nil,
        catalogConflictResolutionServiceOverride: CatalogConflictResolutionService? = nil
    ) {
        #if DEBUG
        Task145StoreLoadFailureObservation.record(.businessRootConstructed)
        #endif
        self.supabaseTransportClient = supabaseTransportClient
        self.supabasePullPreviewService = supabasePullPreviewService
        self.syncEventOutboxDrainRecorder = syncEventOutboxDrainRecorder
        self.syncEventSignalWatcher = syncEventSignalWatcher
        self.shopDeviceRegistrationService = shopDeviceRegistrationService
        self.catalogConflictResolutionService = catalogConflictResolutionServiceOverride ?? supabaseTransportClient.map {
            CatalogConflictResolutionService(remote: CatalogRemoteSupabaseAdapter(remote: $0))
        }
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

    var body: some View { activeRoot }

    private var scopedSyncOrchestrator: SyncOrchestrator? {
        runtimePresentationID == syncStoreGenerationController.presentationID ? currentSyncOrchestrator : nil
    }

    private var scopedRootIndicator: SyncRootPresentationState {
        runtimePresentationID == syncStoreGenerationController.presentationID ? rootIndicatorState : .hidden
    }

    private var activeRoot: some View {
        let presentationID = syncStoreGenerationController.presentationID
        let runtimeModelContainer = syncStoreGenerationController.modelContainer
        let hidesBusinessData = hidesBusinessDataForPendingRecovery
        return ZStack {
            tabContent(syncOrchestrator: scopedSyncOrchestrator, hidesBusinessData: hidesBusinessData)
            AppSyncRootHost(
            modelContainer: runtimeModelContainer,
            presentationID: presentationID,
            authViewModel: supabaseAuthViewModel,
            supabaseTransportClient: supabaseTransportClient,
            activityRecorder: syncEventOutboxDrainRecorder,
            syncEventSignalWatcher: syncEventSignalWatcher,
            syncStateStore: syncStateStore,
            selectedTab: $selectedTab,
            activityCenter: foregroundActivityCenter,
            shopContextStore: shopContextStore,
            syncStoreGenerationController: syncStoreGenerationController,
            shopDeviceRegistrationService: shopDeviceRegistrationService,
            publishPresentation: { orchestrator, state in
                guard syncStoreGenerationController.presentationID == presentationID else { return }
                currentSyncOrchestrator = orchestrator
                runtimePresentationID = presentationID
                rootIndicatorState = state
            }
        ) { _ in Color.clear }
        .id(presentationID)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
        }
        .accountSyncDecisionDialog(
            isPresented: $isCorruptJournalReviewPresented,
            decision: Self.interruptedRecoveryDecision,
            isCloudReplacementEnabled: isCorruptJournalReplacementEnabled,
            onChoose: { choice in
                if case .discardLocalAndBind = choice, let orchestrator = scopedSyncOrchestrator {
                    beginCorruptJournalReplacement(using: orchestrator)
                } else { isCorruptJournalReviewPresented = false }
            }
        )
        .alert(L("options.accountDecision.error.title"), isPresented: Binding(
            get: { corruptJournalReplacementError != nil },
            set: { if !$0 { corruptJournalReplacementError = nil } }
        )) { Button(L("common.ok"), role: .cancel) {} }
        message: { Text(corruptJournalReplacementError ?? "") }
        .onChange(of: hidesBusinessData) { _, hidden in
            restoreLocalPresentation()
            if hidden, syncStoreGenerationController.activeManifest == nil {
                syncStoreGenerationController.startLocalBodyQualification(ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID)
            }
        }
        .environment(\.foregroundCloudWorkflowActivityCenter, foregroundActivityCenter)
        .environment(\.catalogConflictResolutionService, catalogConflictResolutionService)
        .environmentObject(shopContextStore)
        .foregroundCloudWorkflowActivity(.importExcel, isActive: excelSession.isLoading)
        .localeOverride(for: appLanguage)
        .preferredColorScheme(resolvedColorScheme)
        .onAppear { restoreLocalPresentation() }
        .onChange(of: syncStoreGenerationController.presentationID) { _, _ in restoreLocalPresentation() }
        .onChange(of: selectedTab) { _, value in
            guard isCurrentModelGeneration, !hidesBusinessDataForPendingRecovery else { return }
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
        modelGenerationIsCurrent()
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
        if let owner = supabaseAuthViewModel.localMutationOwnerUserID,
           let shop = SelectedShopStore().selectedShop(accountHash: AccountBindingStore.accountHash(for: owner)),
           let device = try? DeviceInstallIDStore().requireDeviceInstallID(),
           SelectedShopStore().hasConfirmedDeviceDenial(accountHash: AccountBindingStore.accountHash(for: owner),
             shopID: shop.shopID, deviceIdentityHash: DeviceInstallIDStore.identityHash(for: device)) {
            return true
        }
        if syncStoreGenerationController.activeManifest != nil {
            return !Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                modelContainer: modelContext.container,
                ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID
            )
        }
        if syncStoreGenerationController.permitsScopedEmptyRoot(ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID) {
            return false
        }
        return !Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                modelContainer: modelContext.container,
                ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID
            )
    }

    #if DEBUG
    private func observeTask144RootPrivacyChoice() -> Bool {
        let observation = Task144RootObservation.Evaluation("root-privacy", callsite: "ContentView.hidesBusinessDataForPendingRecovery")
        var hidden = false
        var branch = "NOT_SELECTED"
        defer { observation.finish(hidden, branch: branch, firstFalseLabel: "first-false-branch-condition") }
        _ = localAuthorizationRevision
        if let owner = observation.optional(supabaseAuthViewModel.localMutationOwnerUserID, "owner"),
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
                ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID), "existing-local-access")
            return hidden
        }
        if observation.check(syncStoreGenerationController.permitsScopedEmptyRoot(
            ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID), "scoped-empty-admitted") {
            branch = "scoped-empty"; hidden = false
            return false
        }
        branch = "unqualified-local-access"
        hidden = !observation.check(Task126OwnerStoreGate.permitsSameScopeLocalAccess(
            modelContainer: modelContext.container,
            ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID), "fallback-local-access")
        return hidden
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
        guard Task126OwnerStoreGate.permitsSameScopeLocalAccess(
            modelContainer: syncStoreGenerationController.modelContainer,
            ownerUserID: ownerUserID
        ) else { return true }
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

    private var unavailableReason: LocalCatalogUnavailableReason {
        if case .blocked(.deviceNotActive) = syncStateStore.state.phase { return .restricted }
        if let owner = supabaseAuthViewModel.localMutationOwnerUserID,
           let manifest = syncStoreGenerationController.activeManifest,
           AccountBindingStore.accountHash(for: owner) != manifest.accountHash { return .restricted }
        return syncStoreGenerationController.activeManifest == nil ? .firstDownload : .qualifying
    }

    private func businessPrivacyGate(syncOrchestrator: SyncOrchestrator?) -> some View {
        SyncReplacementPrivacyGate(
            reason: unavailableReason,
            state: syncStateStore.state,
            isBusy: syncOrchestrator?.hasCurrentPresentationInvocation == true
                && syncStateStore.state.phase.isSignificantAutomaticWork,
            requiresManualReview: requiresManualRecoveryReview,
            openOptions: { selectedTab = 3 },
            review: { isCorruptJournalReviewPresented = true }
        )
    }

    @ToolbarContentBuilder
    private var syncToolbar: some ToolbarContent {
        if scopedRootIndicator.kind != .hidden {
            ToolbarItem(placement: .topBarTrailing) {
                Button { selectedTab = 3 } label: {
                    ProgressView().controlSize(.small)
                }
                .accessibilityLabel(L(scopedRootIndicator.titleKey))
                .accessibilityHint(L("sync.local.openOptions"))
                .accessibilityIdentifier("sync-root-significant-work")
            }
        }
    }

    @ViewBuilder
    private func tabContent(syncOrchestrator: SyncOrchestrator?, hidesBusinessData: Bool) -> some View {
        let presentationID = syncStoreGenerationController.presentationID
        TabView(selection: $selectedTab) {
            NavigationStack {
                InventoryHomeView(isBusinessContentAvailable: !hidesBusinessData,
                    businessContentIsCurrent: { isCurrentModelGeneration && !hidesBusinessDataForPendingRecovery },
                    unavailableTitleKey: unavailableReason.titleKey, unavailableDetailKey: unavailableReason.detailKey,
                    openOptions: { selectedTab = 3 })
                    .environmentObject(excelSession)
                    .environmentObject(shopContextStore)
                    .id(presentationID)
                    .toolbar { syncToolbar }
            }
            .tabItem { Label(L("tab.inventory"), systemImage: "doc.on.doc") }
            .tag(0)

            NavigationStack {
                Group {
                    if hidesBusinessData {
                        businessPrivacyGate(syncOrchestrator: syncOrchestrator)
                            .navigationTitle(L("tab.database"))
                    } else {
                        DatabaseView(isFirstSnapshotPreparing: syncStoreGenerationController.permitsScopedEmptyRoot(
                            ownerUserID: supabaseAuthViewModel.localMutationOwnerUserID))
                    }
                }
                .id(presentationID)
                .toolbar { syncToolbar }
            }
            .tabItem { Label(L("tab.database"), systemImage: "shippingbox") }
            .tag(1)

            NavigationStack {
                Group {
                    if hidesBusinessData {
                        businessPrivacyGate(syncOrchestrator: syncOrchestrator)
                            .navigationTitle(L("tab.history"))
                    } else {
                        HistoryView(historySessionSyncService: historySessionSyncService)
                    }
                }
                .id(presentationID)
                .toolbar { syncToolbar }
            }
            .tabItem { Label(L("tab.history"), systemImage: "clock.arrow.circlepath") }
            .tag(2)

            NavigationStack {
                OptionsView(remoteCountFetcher: remoteCountFetcher,
                    supabasePullPreviewService: supabasePullPreviewService, syncStateStore: syncStateStore,
                    syncEventOutboxDrainRecorder: syncEventOutboxDrainRecorder,
                    deviceAuthorization: shopDeviceRegistrationService,
                    accountStoreReplacementRuntime: syncOrchestrator)
            }
            .tabItem { Label(L("tab.options"), systemImage: "gearshape") }
            .tag(3)
            .task145PerformanceRender("optionsRender")
        }
        .task145PerformanceRender("tabsRender")
    }
}

nonisolated enum LocalCatalogUnavailableReason {
    case qualifying, firstDownload, restricted
    var titleKey: String {
        switch self {
        case .qualifying: "sync.local.qualifying.title"
        case .firstDownload: "sync.local.firstDownload.title"
        case .restricted: "sync.local.restricted.title"
        }
    }
    var detailKey: String {
        switch self {
        case .qualifying: "sync.local.qualifying.detail"
        case .firstDownload: "sync.local.firstDownload.waiting"
        case .restricted: "sync.local.restricted.detail"
        }
    }
}

private struct SyncReplacementPrivacyGate: View {
    let reason: LocalCatalogUnavailableReason
    let state: SyncState
    let isBusy: Bool
    let requiresManualReview: Bool
    let openOptions: () -> Void
    let review: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(L(reason.titleKey)).font(.headline).multilineTextAlignment(.center)
            Text(L(reason.detailKey)).multilineTextAlignment(.center)
                .accessibilityIdentifier("sync-recovery-phase")
            if isBusy, let progress = state.recoveryProgress, let domain = progress.domain {
                Text(String(format: L("options.supabase.automaticSync.recovery.counts"),
                    L(SyncRecoveryGatePresentation.domainKey(domain)), progress.pages, progress.persistedRows))
                    .font(.subheadline.monospacedDigit()).multilineTextAlignment(.center)
                    .accessibilityIdentifier("sync-recovery-counts")
            }
            Button(L(requiresManualReview ? "options.accountDecision.review" : "sync.local.openOptions"),
                   action: requiresManualReview ? review : openOptions)
                .buttonStyle(.borderedProminent)
        }
        .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
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
    private let publishPresentation: (SyncOrchestrator, SyncRootPresentationState) -> Void
    #if DEBUG
    private let t10PresentationGenerationID: UUID?
    #endif
    @State private var significantWorkVisible = false

    init(
        modelContainer: ModelContainer,
        presentationID: String,
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
        publishPresentation: @escaping (SyncOrchestrator, SyncRootPresentationState) -> Void,
        @ViewBuilder content: @escaping (SyncOrchestrator) -> Content
    ) {
        _syncOrchestrator = StateObject(
            wrappedValue: SyncOrchestrator(
                automaticRuntime: SyncAutomaticRuntimeFactory.make(
                    modelContainer: modelContainer,
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
                storeGenerationLease: syncStoreGenerationController.captureLease(for: modelContainer),
                decisionInputProvider: SyncDecisionInputProvider(modelContainer: modelContainer)
            )
        )
        _selectedTab = selectedTab
        _activityCenter = ObservedObject(wrappedValue: activityCenter)
        _authViewModel = ObservedObject(wrappedValue: authViewModel)
        _shopContextStore = ObservedObject(wrappedValue: shopContextStore)
        self.shopDeviceRegistrationService = shopDeviceRegistrationService
        self.content = content
        self.publishPresentation = publishPresentation
        #if DEBUG
        t10PresentationGenerationID = UUID(uuidString: presentationID)
        #endif
    }

    var body: some View {
        let rootBannerState = syncOrchestrator.rootPresentationState
        let showsRootBanner = syncOrchestrator.shouldShowRootBanner(rootBannerState, selectedTab: selectedTab)

        let published = showsRootBanner && significantWorkVisible ? rootBannerState : .hidden
        content(syncOrchestrator)
            .onChange(of: published, initial: true) { _, state in publishPresentation(syncOrchestrator, state) }
            .task(id: syncOrchestrator.visibleWorkInvocationID) {
                significantWorkVisible = false
                guard syncOrchestrator.visibleWorkInvocationID != nil else { return }
                do { try await Task.sleep(for: .milliseconds(700)) } catch { return }
                guard !Task.isCancelled, syncOrchestrator.visibleWorkInvocationID != nil else { return }
                significantWorkVisible = true
            }
            .task {
                #if DEBUG
                observeT10Lifecycle("host-task-start")
                #endif
                await refreshShopContextAndResumeSync()
                #if DEBUG
                Task144LocalAvailabilityRootFixture.current?.startIfNeeded()
                #endif
            }
            .onChange(of: scenePhase) { _, phase in
                #if DEBUG
                if phase == .background { Task144RootObservation.performanceBackground() }
                if phase == .active {
                    Task144RootObservation.performanceActivate()
                    Task144LocalAvailabilityRootFixture.current?.beginPerformanceWarmRecoveryIfArmed()
                }
                #endif
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
                #if DEBUG
                observeT10Lifecycle("host-disappear-stop-enter")
                #endif
                syncOrchestrator.stop()
                #if DEBUG
                observeT10Lifecycle("host-stop-return")
                #endif
            }
    }

    #if DEBUG
    private func observeT10Lifecycle(_ stage: String) {
        let environment = ProcessInfo.processInfo.environment
        guard environment["TASK145_SAVE_BEFORE_ACTIVATION_UI"] == "name-price",
              let runID = environment["TASK144_LOCAL_AVAILABILITY_FIXTURE"].flatMap(UUID.init(uuidString:)) else { return }
        let generationID = t10PresentationGenerationID?.uuidString.lowercased() ?? "none"
        NSLog("%@", "TASK145_UI03_LIFECYCLE schema=1 runID=\(runID.uuidString.lowercased()) pid=\(ProcessInfo.processInfo.processIdentifier) stage=\(stage) cancelled=\(Task.isCancelled) generationID=\(generationID)")
    }
    #endif
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
        #if DEBUG
        observeT10Lifecycle("bootstrap-enter")
        #endif
        await syncOrchestrator.bootstrap(scenePhase: scenePhase)
        #if DEBUG
        observeT10Lifecycle("bootstrap-return")
        #endif
        await shopContextStore.refresh(
            ownerUserID: authViewModel.localMutationOwnerUserID
        )
        if SyncBootstrapReadiness.shouldStart(
            isSignedIn: authViewModel.isSignedIn,
            isShopSyncAllowed: shopContextStore.context.syncAllowed
        ) {
            await shopDeviceRegistrationService?.registerHeartbeatAndCheck(reason: "app_sync_bootstrap")
        }
        // Discovery may have become ready after the first gated attempt.
        syncOrchestrator.submitForegroundTrigger(source: .rootForeground, forceIncremental: true)
    }
}

private struct SyncRootForegroundBanner: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let state: SyncRootPresentationState
    let reduceMotion: Bool
    let action: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: state.systemImage)
                            .font(.system(size: 14))
                            .imageScale(.small)
                            .foregroundStyle(iconTint)
                            .frame(width: 22, height: 22)
                            .background(iconTint.opacity(0.14), in: Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L(state.titleKey))
                                .font(.footnote)
                                .fontWeight(.semibold)

                            if let detailKey = visibleDetailKey {
                                Text(L(detailKey))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let actionTitle = publicRemediationActionTitle {
                        Button(L(actionTitle), action: action)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .fixedSize(horizontal: true, vertical: true)
                    }
                }
            } else {
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

                        if let detailKey = visibleDetailKey {
                            Text(L(detailKey))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let actionTitle = publicRemediationActionTitle {
                        Button(L(actionTitle), action: action)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .fixedSize(horizontal: true, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : maxBannerWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            if dynamicTypeSize.isAccessibilitySize {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            } else {
                Capsule(style: .continuous).fill(.regularMaterial)
            }
        }
        .overlay {
            if dynamicTypeSize.isAccessibilitySize {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            } else {
                Capsule(style: .continuous)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
            }
        }
        .shadow(color: Color.black.opacity(0.08), radius: 7, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier("sync.root.foreground.banner")
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
            visibleDetailKey.map { L($0) }
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
