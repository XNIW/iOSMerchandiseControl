import Auth
import Supabase
import SwiftUI
import SwiftData

@main
struct iOSMerchandiseControlApp: App {
    @StateObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    @StateObject private var productImageStore: ProductImageStore
    @StateObject private var syncStoreGenerationController: SyncStoreGenerationController
    private let supabaseTransportClient: SupabaseTransportClient?
    private let supabasePullPreviewService: SupabasePullPreviewService?
    private let syncEventOutboxDrainRecorder: (any SyncEventRecording)?
    private let syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?
    private let shopDeviceRegistrationService: ShopDeviceRegistrationService?

    init() {
        #if DEBUG
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
        let dependencies = Self.isRunningHostedXCTest
            || isTask138VisualHarness
            || isTask139AtomicCrashHarness
            || isTask139PreboundHarness
            || isTask140UITest
            ? Self.makeHostedXCTestDependencies()
            : Self.makeSupabaseDependencies()
        let generationController = Self.isRunningHostedXCTest
            || isTask138VisualHarness
            || isTask139AtomicCrashHarness
            || isTask139PreboundHarness
            || isTask140UITest
            ? SyncStoreGenerationController.ephemeral()
            : SyncStoreGenerationController.shared
        let productImageStore = dependencies.productImageStore
        _supabaseAuthViewModel = StateObject(wrappedValue: dependencies.authViewModel)
        _productImageStore = StateObject(wrappedValue: productImageStore)
        _syncStoreGenerationController = StateObject(wrappedValue: generationController)
        generationController.setPresentationBoundaryObserver { [weak productImageStore] presentationID in
            productImageStore?.advanceStoreGeneration(presentationID: presentationID)
        }
        supabaseTransportClient = dependencies.supabaseTransportClient
        supabasePullPreviewService = dependencies.pullPreviewService
        syncEventOutboxDrainRecorder = dependencies.syncEventOutboxDrainRecorder
        syncEventSignalWatcher = dependencies.syncEventSignalWatcher
        shopDeviceRegistrationService = dependencies.shopDeviceRegistrationService
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
                if let task138VisualState = Self.task138ProductImageVisualState {
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
        }
    }

    @ViewBuilder
    private var standardRootView: some View {
        if syncStoreGenerationController.loadFailureCode != nil {
            SyncStoreGenerationFailureView()
        } else if let task126SmokeKind = Self.task126UISmokeKind {
            Task126ReviewInteractionSmokeView(kind: task126SmokeKind)
        } else if Self.isRunningHostedXCTest {
            HostedXCTestRootView()
        } else {
            ContentView(
                supabaseTransportClient: supabaseTransportClient,
                supabasePullPreviewService: supabasePullPreviewService,
                syncEventOutboxDrainRecorder: syncEventOutboxDrainRecorder,
                syncEventSignalWatcher: syncEventSignalWatcher,
                shopDeviceRegistrationService: shopDeviceRegistrationService
            )
            .environmentObject(supabaseAuthViewModel)
            .environmentObject(productImageStore)
            .onOpenURL { url in
                _ = supabaseAuthViewModel.handleOpenURL(url)
            }
        }
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
    #endif

    private static func makeHostedXCTestDependencies() -> SupabaseAppDependencies {
        SupabaseAppDependencies(
            authViewModel: SupabaseAuthViewModel(authService: nil, initialError: .configMissing),
            supabaseTransportClient: nil,
            pullPreviewService: nil,
            syncEventOutboxDrainRecorder: nil,
            syncEventSignalWatcher: nil,
            shopDeviceRegistrationService: nil,
            productImageStore: ProductImageStore(service: nil)
        )
    }

    private static func makeSupabaseDependencies() -> SupabaseAppDependencies {
        do {
            let config = try SupabaseConfig.load()
            let provider = SupabaseClientProvider(config: config)
            let authService = SupabaseAuthService(provider: provider)
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
                productImageStore: productImageStore
            )
        } catch SupabaseConfigError.configMissing {
            return SupabaseAppDependencies(
                authViewModel: SupabaseAuthViewModel(authService: nil, initialError: .configMissing),
                supabaseTransportClient: nil,
                pullPreviewService: nil,
                syncEventOutboxDrainRecorder: nil,
                syncEventSignalWatcher: nil,
                shopDeviceRegistrationService: nil,
                productImageStore: ProductImageStore(service: nil)
            )
        } catch SupabaseConfigError.invalidConfig {
            return SupabaseAppDependencies(
                authViewModel: SupabaseAuthViewModel(authService: nil, initialError: .invalidConfig),
                supabaseTransportClient: nil,
                pullPreviewService: nil,
                syncEventOutboxDrainRecorder: nil,
                syncEventSignalWatcher: nil,
                shopDeviceRegistrationService: nil,
                productImageStore: ProductImageStore(service: nil)
            )
        } catch {
            return SupabaseAppDependencies(
                authViewModel: SupabaseAuthViewModel(authService: nil, initialError: .unknown(message: String(describing: error))),
                supabaseTransportClient: nil,
                pullPreviewService: nil,
                syncEventOutboxDrainRecorder: nil,
                syncEventSignalWatcher: nil,
                shopDeviceRegistrationService: nil,
                productImageStore: ProductImageStore(service: nil)
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

private struct SupabaseAppDependencies {
    let authViewModel: SupabaseAuthViewModel
    let supabaseTransportClient: SupabaseTransportClient?
    let pullPreviewService: SupabasePullPreviewService?
    let syncEventOutboxDrainRecorder: (any SyncEventRecording)?
    let syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?
    let shopDeviceRegistrationService: ShopDeviceRegistrationService?
    let productImageStore: ProductImageStore
}
