import Auth
import Supabase
import SwiftUI
import SwiftData

@main
struct iOSMerchandiseControlApp: App {
    @StateObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    @StateObject private var productImageStore: ProductImageStore
    @StateObject private var storefrontAuthoringStore: StorefrontAuthoringStore
    @StateObject private var syncStoreGenerationController: SyncStoreGenerationController
    @StateObject private var localRootPresentationState: LocalRootPresentationState
    private let supabaseTransportClient: SupabaseTransportClient?
    private let supabasePullPreviewService: SupabasePullPreviewService?
    private let syncEventOutboxDrainRecorder: (any SyncEventRecording)?
    private let syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?
    private let shopDeviceRegistrationService: ShopDeviceRegistrationService?

    init() {
        #if DEBUG
        let controlledRoot = Task144LocalAvailabilityRootFixture.current
        if Self.task141ResetUIStateRequested {
            Self.resetTask141UIState()
        }
        let isTask138VisualHarness = Self.task138ProductImageVisualState != nil
        let isTask139AtomicCrashHarness = Self.task139AtomicCrashHarnessRequested
        let isTask139PreboundHarness = Self.task139PreboundHarnessRequested
        let isTask140UITest = Self.task140UITestRequested
        #else
        let isTask138VisualHarness = false
        let isTask139AtomicCrashHarness = false
        let isTask139PreboundHarness = false
        let isTask140UITest = false
        #endif
        let dependencies: SupabaseAppDependencies
        let generationController: SyncStoreGenerationController
        let normalDependencies = { () -> (SupabaseAppDependencies, SyncStoreGenerationController) in
            let hosted = Self.isRunningHostedXCTest || isTask138VisualHarness
                || isTask139AtomicCrashHarness || isTask139PreboundHarness || isTask140UITest
            return (hosted ? Self.makeHostedXCTestDependencies() : Self.makeSupabaseDependencies(),
                    hosted ? SyncStoreGenerationController.ephemeral() : SyncStoreGenerationController.shared)
        }
        #if DEBUG
        if let controlledRoot {
            dependencies = SupabaseAppDependencies(authViewModel: controlledRoot.authViewModel,
                supabaseTransportClient: nil, pullPreviewService: nil, syncEventOutboxDrainRecorder: nil,
                syncEventSignalWatcher: nil, shopDeviceRegistrationService: nil,
                productImageStore: ProductImageStore(service: nil),
                storefrontAuthoringStore: StorefrontAuthoringStore(service: nil))
            generationController = controlledRoot.controller
        } else {
            (dependencies, generationController) = normalDependencies()
        }
        #else
        (dependencies, generationController) = normalDependencies()
        #endif
        let productImageStore = dependencies.productImageStore
        let localPresentation = LocalRootPresentationState()
        localPresentation.advanceStoreGeneration(presentationID: generationController.presentationID)
        _localRootPresentationState = StateObject(wrappedValue: localPresentation)
        _supabaseAuthViewModel = StateObject(wrappedValue: dependencies.authViewModel)
        _productImageStore = StateObject(wrappedValue: productImageStore)
        _storefrontAuthoringStore = StateObject(wrappedValue: dependencies.storefrontAuthoringStore)
        _syncStoreGenerationController = StateObject(wrappedValue: generationController)
        generationController.setPresentationBoundaryObserver { [weak productImageStore, weak localPresentation] presentationID in
            localPresentation?.advanceStoreGeneration(presentationID: presentationID)
            productImageStore?.advanceStoreGeneration(presentationID: presentationID)
        }
        supabaseTransportClient = dependencies.supabaseTransportClient
        supabasePullPreviewService = dependencies.pullPreviewService
        syncEventOutboxDrainRecorder = dependencies.syncEventOutboxDrainRecorder
        syncEventSignalWatcher = dependencies.syncEventSignalWatcher
        shopDeviceRegistrationService = dependencies.shopDeviceRegistrationService
        #if DEBUG
        if controlledRoot != nil { return }
        #endif
        if !Self.isRunningHostedXCTest,
           !isTask138VisualHarness,
           !isTask139AtomicCrashHarness,
           !isTask139PreboundHarness,
           !isTask140UITest,
           generationController.loadFailureCode == nil {
            SyncBackgroundTaskScheduler.shared.register()
            SyncBackgroundTaskScheduler.shared.schedule(reason: .appLaunch)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if let controlledRoot = Task144LocalAvailabilityRootFixture.current {
                    Task144ControlledRootAdmission(fixture: controlledRoot) {
                        standardRootView
                    }
                } else if let task138VisualState = Self.task138ProductImageVisualState {
                    Task138ProductImageVisualHarness(state: task138VisualState)
                } else if Self.task139AtomicCrashHarnessRequested
                            || Self.task139PreboundHarnessRequested {
                    HostedXCTestRootView()
                } else {
                    standardRootView
                }
                #else
                standardRootView
                #endif
            }
            .environmentObject(syncStoreGenerationController)
            .modelContainer(syncStoreGenerationController.modelContainer)
            .id(syncStoreGenerationController.presentationID)
            #if DEBUG
            .task144ControlledRootControls()
            .task { Task144LocalAvailabilityRootFixture.current?.prepareIfNeeded() }
            #endif
        }
    }

    @ViewBuilder
    private var standardRootView: some View {
        if syncStoreGenerationController.loadFailureCode != nil {
            SyncStoreGenerationFailureView()
        } else if let task126SmokeKind = Self.task126UISmokeKind {
            Task126ReviewInteractionSmokeView(kind: task126SmokeKind)
        } else {
            storefrontHarnessOrStandardRoot
        }
    }

    @ViewBuilder
    private var storefrontHarnessOrStandardRoot: some View {
        #if DEBUG
        if Self.task143StorefrontUITestRequested {
            Task143StorefrontUITestHarness()
                .environmentObject(supabaseAuthViewModel)
                .environmentObject(productImageStore)
                .environmentObject(storefrontAuthoringStore)
        } else {
            hostedXCTestOrContentRoot
        }
        #else
        hostedXCTestOrContentRoot
        #endif
    }

    @ViewBuilder
    private var hostedXCTestOrContentRoot: some View {
        if Self.isRunningHostedXCTest {
            HostedXCTestRootView()
        } else {
            ContentView(
                supabaseTransportClient: supabaseTransportClient,
                supabasePullPreviewService: supabasePullPreviewService,
                syncEventOutboxDrainRecorder: syncEventOutboxDrainRecorder,
                syncEventSignalWatcher: syncEventSignalWatcher,
                shopDeviceRegistrationService: shopDeviceRegistrationService,
                shopContextOverride: controlledShopContext,
                syncStateOverride: controlledSyncState
            )
            .environment(\.localRootPresentationState, localRootPresentationState)
            .environment(\.localModelGenerationIsCurrent, currentRootGenerationFence)
            .environmentObject(supabaseAuthViewModel)
            .environmentObject(productImageStore)
            .environmentObject(storefrontAuthoringStore)
            .onOpenURL { url in
                _ = supabaseAuthViewModel.handleOpenURL(url)
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                _ = supabaseAuthViewModel.handleUniversalLink(userActivity)
            }
        }
    }

    private var currentRootGenerationFence: () -> Bool {
        let displayedContainer = syncStoreGenerationController.modelContainer
        return { [weak controller = syncStoreGenerationController, weak displayedContainer] in
            guard let controller, let displayedContainer else { return false }
            return controller.modelContainer === displayedContainer
        }
    }

    private var controlledShopContext: ShopContextStore? {
        #if DEBUG
        Task144LocalAvailabilityRootFixture.current?.shopContextStore
        #else
        nil
        #endif
    }
    private var controlledSyncState: SyncStateStore? {
        #if DEBUG
        Task144LocalAvailabilityRootFixture.current?.stateStore
        #else
        nil
        #endif
    }

    private static var isRunningHostedXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            && ProcessInfo.processInfo.environment["TASK115_REAL_ROOT_LIFECYCLE_TEST"] != "1"
    }

    private static var task126UISmokeKind: String? {
        #if DEBUG
        let value = ProcessInfo.processInfo.environment["TASK126_UI_SMOKE_KIND"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
        #else
        return nil
        #endif
    }

    private static var task143StorefrontUITestRequested: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["TASK143_STOREFRONT_UI_TEST"] == "1"
        #else
        false
        #endif
    }

    #if DEBUG
    /// Lazy so the harness runs before any normal generation controller,
    /// Supabase dependency or background task can touch app state.
    private static let task139AtomicCrashHarnessRequested =
        Task139AtomicGenerationCrashHarness.runIfRequested()

    private static let task139PreboundHarnessRequested =
        Task139PreboundResourceRuntimeHarness.runIfRequested()

    private static var task138ProductImageVisualState: Task138ProductImageVisualState? {
        Task138ProductImageVisualState(
            environmentValue: ProcessInfo.processInfo.environment["TASK138_PRODUCT_IMAGE_VISUAL_STATE"]
        )
    }

    private static var task140UITestRequested: Bool {
        ProcessInfo.processInfo.environment["TASK140_UI_TEST"] == "1"
    }

    private static var task141ResetUIStateRequested: Bool {
        ProcessInfo.processInfo.environment["TASK141_RESET_UI_STATE"] == "1"
    }

    private static func resetTask141UIState() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
    }
    #endif

    private static func makeHostedXCTestDependencies() -> SupabaseAppDependencies {
        SupabaseAppDependencies(
            authViewModel: SupabaseAuthViewModel(authService: nil, initialError: .configMissing),
            supabaseTransportClient: nil,
            pullPreviewService: nil,
            syncEventOutboxDrainRecorder: nil,
            syncEventSignalWatcher: nil,
            shopDeviceRegistrationService: nil,
            productImageStore: ProductImageStore(service: nil),
            storefrontAuthoringStore: StorefrontAuthoringStore(service: nil)
        )
    }

    private static func makeSupabaseDependencies() -> SupabaseAppDependencies {
        do {
            let config = try SupabaseConfig.load()
            let provider = SupabaseClientProvider(config: config)
            let weChatConfiguration = WeChatAuthConfiguration.load()
            let weChatGateway: any WeChatAuthGateway = weChatConfiguration.gatewayBaseURL.map {
                HTTPWeChatAuthGateway(baseURL: $0)
            } ?? UnconfiguredWeChatAuthGateway()
            let weChatDeviceIDStore = WeChatDeviceIDStore()
            #if os(iOS)
            let weChatCodeProvider: any WeChatAuthorizationCodeProviding =
                OpenSDKWeChatAuthorizationCodeProvider(configuration: weChatConfiguration)
            #else
            let weChatCodeProvider: any WeChatAuthorizationCodeProviding =
                UnconfiguredWeChatAuthorizationCodeProvider()
            #endif
            let weChatCoordinator = WeChatAuthCoordinator(
                configuration: weChatConfiguration,
                codeProvider: weChatCodeProvider,
                deviceID: { weChatDeviceIDStore.getOrCreate() },
                gateway: weChatGateway
            )
            let authService = SupabaseAuthService(
                provider: provider,
                weChatCoordinator: weChatCoordinator
            )
            let shopDeviceRegistrationService = ShopDeviceRegistrationService(clientProvider: provider)
            let supabaseTransportClient = SupabaseTransportClient(clientProvider: provider)
            let previewService = SupabasePullPreviewService(
                inventoryService: RecoveryRemoteSupabaseAdapter(remote: supabaseTransportClient),
                pageSize: 1_000,
                catalogRowBudget: nil,
                productPricePreviewSampleLimit: 1_000
            )
            let syncEventOutboxDrainRecorder: (any SyncEventRecording)? = SupabaseSyncEventLiveRecorder(
                configProvider: SupabaseSyncEventLiveRecorderConfigurationProvider(),
                sessionProvider: authService,
                transport: SupabaseSyncEventRPCTransport(clientProvider: provider)
            )
            let syncEventSignalWatcher = SupabaseSyncEventSignalWatcher(clientProvider: provider)
            let productImageScopeAuthorization: ProductImageScopeAuthorizationProvider = { scope in
                guard provider.client.auth.currentSession?.user.id == scope.accountID else {
                    return false
                }
                let bindingStore = AccountBindingStore()
                let accountHash = AccountBindingStore.accountHash(for: scope.accountID)
                let selectedShop = SelectedShopStore().selectedShop(accountHash: accountHash)
                return ProductImageOwnerStoreGate.allows(
                    scope: scope,
                    selectedShop: selectedShop,
                    binding: bindingStore.currentBinding,
                    hasPendingReplacement: bindingStore.hasPendingReplacementJournal
                )
            }
            let productImageStore = ProductImageStore(
                service: config.productImageAPIBaseURL.map { apiBaseURL in
                    ProductImageService(
                        apiBaseURL: apiBaseURL,
                        storageBaseURL: config.projectURL,
                        scopeAuthorizationProvider: productImageScopeAuthorization
                    ) {
                        guard let session = provider.client.auth.currentSession,
                              !session.isExpired else {
                            return nil
                        }
                        return ProductImageSessionSnapshot(
                            accountID: session.user.id,
                            accessToken: session.accessToken
                        )
                    }
                },
                scopeAuthorizationProvider: productImageScopeAuthorization
            )
            let storefrontAuthoringStore = StorefrontAuthoringStore(
                service: SupabaseStorefrontAuthoringService(transport: supabaseTransportClient)
            )
            return SupabaseAppDependencies(
                authViewModel: SupabaseAuthViewModel(
                    authService: authService,
                    shopDeviceRegistrationService: shopDeviceRegistrationService
                ),
                supabaseTransportClient: supabaseTransportClient,
                pullPreviewService: previewService,
                syncEventOutboxDrainRecorder: syncEventOutboxDrainRecorder,
                syncEventSignalWatcher: syncEventSignalWatcher,
                shopDeviceRegistrationService: shopDeviceRegistrationService,
                productImageStore: productImageStore,
                storefrontAuthoringStore: storefrontAuthoringStore
            )
        } catch SupabaseConfigError.configMissing {
            return SupabaseAppDependencies(
                authViewModel: SupabaseAuthViewModel(authService: nil, initialError: .configMissing),
                supabaseTransportClient: nil,
                pullPreviewService: nil,
                syncEventOutboxDrainRecorder: nil,
                syncEventSignalWatcher: nil,
                shopDeviceRegistrationService: nil,
                productImageStore: ProductImageStore(service: nil),
                storefrontAuthoringStore: StorefrontAuthoringStore(service: nil)
            )
        } catch SupabaseConfigError.invalidConfig {
            return SupabaseAppDependencies(
                authViewModel: SupabaseAuthViewModel(authService: nil, initialError: .invalidConfig),
                supabaseTransportClient: nil,
                pullPreviewService: nil,
                syncEventOutboxDrainRecorder: nil,
                syncEventSignalWatcher: nil,
                shopDeviceRegistrationService: nil,
                productImageStore: ProductImageStore(service: nil),
                storefrontAuthoringStore: StorefrontAuthoringStore(service: nil)
            )
        } catch {
            return SupabaseAppDependencies(
                authViewModel: SupabaseAuthViewModel(authService: nil, initialError: .unknown(message: String(describing: error))),
                supabaseTransportClient: nil,
                pullPreviewService: nil,
                syncEventOutboxDrainRecorder: nil,
                syncEventSignalWatcher: nil,
                shopDeviceRegistrationService: nil,
                productImageStore: ProductImageStore(service: nil),
                storefrontAuthoringStore: StorefrontAuthoringStore(service: nil)
            )
        }
    }
}

private struct SyncStoreGenerationFailureView: View {
    var body: some View {
        ContentUnavailableView(
            L("options.supabase.automaticSync.phase.recoveryRequired"),
            systemImage: "externaldrive.badge.exclamationmark",
            description: Text(L("options.accountDecision.localStateUnavailable.detail"))
        )
        .accessibilityIdentifier("sync-store-generation-fail-closed")
    }
}

private struct HostedXCTestRootView: View {
    var body: some View {
        Color.clear
            .accessibilityHidden(true)
    }
}

#if DEBUG
private struct Task143StorefrontUITestHarness: View {
    @StateObject private var shopContext = ShopContextStore()
    @StateObject private var storefrontStore: StorefrontAuthoringStore
    @State private var filter = StorefrontListFilter.all
    private let scope: StorefrontScope
    private let product: Product

    init() {
        let accountID = UUID(uuidString: "14300000-0000-4000-8000-000000000001")!
        let shopID = UUID(uuidString: "14300000-0000-4000-8000-000000000002")!
        let productID = UUID(uuidString: "14300000-0000-4000-8000-000000000003")!
        scope = StorefrontScope(accountID: accountID, shopID: shopID)
        product = Product(
            barcode: "TASK143-UI",
            remoteID: productID,
            productName: "Prodotto interno sintetico",
            retailPrice: 1_000
        )
        _storefrontStore = StateObject(
            wrappedValue: StorefrontAuthoringStore(
                service: Task143StorefrontUITestService(productID: productID),
                defaults: UserDefaults(suiteName: "Task143UI.\(UUID())")!,
                pendingStorage: StorefrontPendingFileStorage(directory:
                    FileManager.default.temporaryDirectory.appendingPathComponent("Task143UI.\(UUID())"))
            )
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                StorefrontFilterBar(selection: $filter)
                    .padding(.vertical, 8)
                Text(storefrontStore.isFilterLoading ? "loading" : "\(filter.rawValue):\(storefrontStore.filteredProductIDs.count)")
                    .accessibilityIdentifier("storefront.filter.result")
                Form {
                    StorefrontEditorSection(
                        product: product,
                        operationalName: "Synthetic product",
                        operationalRetailPrice: 1_000,
                        operationalCategoryRemoteID: nil
                    )
                }
            }
            .navigationTitle("Storefront UI Test")
        }
        .task { storefrontStore.activate(scope: scope) }
        .onChange(of: filter) { _, value in
            storefrontStore.resetFilter(value, query: nil, scope: scope)
        }
        .environmentObject(shopContext)
        .environmentObject(storefrontStore)
        .environment(\.task143StorefrontScopeOverride, scope)
        .environment(\.task143StorefrontCanMutateOverride, true)
    }
}

@MainActor
private final class Task143StorefrontUITestService: StorefrontAuthoringServicing {
    let productID: UUID
    private var suspendedMutation: CheckedContinuation<StorefrontAuthoringMutationResponse, any Error>?
    private var suspendedPublished: CheckedContinuation<StorefrontAuthoringSummaryResponse, any Error>?

    init(productID: UUID) {
        self.productID = productID
    }

    func read(
        scope: StorefrontScope,
        productIDs: [UUID]
    ) async throws -> StorefrontAuthoringReadResponse {
        let publication = try fixture(version: 7, name: "Nome pubblico sintetico")
        return StorefrontAuthoringReadResponse(
            ok: true,
            code: "ok",
            shopId: scope.shopID,
            rows: productIDs.contains(productID) ? [publication] : [],
            categories: [
                StorefrontCategory(
                    categoryId: UUID(uuidString: "14300000-0000-4000-8000-000000000004")!,
                    sourceCategoryId: nil,
                    publicName: "Categoria sintetica",
                    status: "active",
                    updatedAt: "2026-08-21T12:00:00Z"
                )
            ],
            pagination: StorefrontPagination(total: 1)
        )
    }

    func readSummary(
        scope: StorefrontScope,
        filter: StorefrontListFilter,
        query: String?,
        productIDs: [UUID]?,
        page: Int
    ) async throws -> StorefrontAuthoringSummaryResponse {
        suspendedMutation?.resume(throwing: StorefrontAuthoringError.conflict(try fixture(version: 8, name: "Changed by Admin")))
        suspendedMutation = nil
        if filter == .published {
            return try await withCheckedThrowingContinuation { suspendedPublished = $0 }
        }
        suspendedPublished?.resume(throwing: StorefrontAuthoringError.offline)
        suspendedPublished = nil
        let row = StorefrontPublicationSummary(
            sourceProductId: productID, status: "draft", publicName: "Synthetic draft",
            publicPrice: 1_000, storefrontCategoryId: nil, publicImageId: nil,
            version: 7, updatedAt: nil, differsFromOperational: false
        )
        return StorefrontAuthoringSummaryResponse(
            ok: true, code: "ok", shopId: scope.shopID, rows: [row],
            pagination: StorefrontPagination(page: page, total: 1)
        )
    }

    func mutate(
        scope: StorefrontScope,
        productID: UUID,
        operation: StorefrontMutationOperation,
        draft: StorefrontEditorDraft,
        expectedVersion: Int64,
        idempotencyKey: UUID
    ) async throws -> StorefrontAuthoringMutationResponse {
        if ProcessInfo.processInfo.environment["TASK144_MUTATION_UI_TEST"] == "1" {
            return try await withCheckedThrowingContinuation { suspendedMutation = $0 }
        }
        throw StorefrontAuthoringError.conflict(
            try fixture(version: 8, name: "Aggiornato da Admin")
        )
    }

    private func fixture(version: Int64, name: String) throws -> StorefrontPublication {
        let json: [String: Any] = [
            "publicationId": "14300000-0000-4000-8000-000000000005",
            "sourceProductId": productID.uuidString.lowercased(),
            "status": "draft",
            "publicName": name,
            "publicDescription": "Descrizione pubblica sintetica",
            "storefrontCategoryId": "14300000-0000-4000-8000-000000000004",
            "publicPrice": 1_000,
            "priceSourceMode": "override",
            "featured": false,
            "homeOrder": 0,
            "pickupEnabled": true,
            "deliveryEnabled": false,
            "reservationEnabled": false,
            "availability": "available",
            "version": version,
            "updatedAt": "2026-08-21T12:00:00Z",
            "mutationSource": "admin",
            "changedFields": ["publicName"]
        ]
        return try JSONDecoder().decode(
            StorefrontPublication.self,
            from: JSONSerialization.data(withJSONObject: json)
        )
    }
}
#endif

private struct SupabaseAppDependencies {
    let authViewModel: SupabaseAuthViewModel
    let supabaseTransportClient: SupabaseTransportClient?
    let pullPreviewService: SupabasePullPreviewService?
    let syncEventOutboxDrainRecorder: (any SyncEventRecording)?
    let syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?
    let shopDeviceRegistrationService: ShopDeviceRegistrationService?
    let productImageStore: ProductImageStore
    let storefrontAuthoringStore: StorefrontAuthoringStore
}
