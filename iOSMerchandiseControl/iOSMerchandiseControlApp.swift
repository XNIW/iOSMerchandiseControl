import SwiftUI
import SwiftData

@main
struct iOSMerchandiseControlApp: App {
    @StateObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    private let supabaseTransportClient: SupabaseTransportClient?
    private let supabasePullPreviewService: SupabasePullPreviewService?
    private let syncEventOutboxDrainRecorder: (any SyncEventRecording)?
    private let syncEventSignalWatcher: SupabaseSyncEventSignalWatcher?

    init() {
        let dependencies = Self.isRunningHostedXCTest
            ? Self.makeHostedXCTestDependencies()
            : Self.makeSupabaseDependencies()
        _supabaseAuthViewModel = StateObject(wrappedValue: dependencies.authViewModel)
        supabaseTransportClient = dependencies.supabaseTransportClient
        supabasePullPreviewService = dependencies.pullPreviewService
        syncEventOutboxDrainRecorder = dependencies.syncEventOutboxDrainRecorder
        syncEventSignalWatcher = dependencies.syncEventSignalWatcher
        SyncBackgroundTaskScheduler.shared.register()
        SyncBackgroundTaskScheduler.shared.schedule(reason: .appLaunch)
    }

    var body: some Scene {
        WindowGroup {
            if Self.isRunningHostedXCTest {
                HostedXCTestRootView()
            } else {
                ContentView(
                    supabaseTransportClient: supabaseTransportClient,
                    supabasePullPreviewService: supabasePullPreviewService,
                    syncEventOutboxDrainRecorder: syncEventOutboxDrainRecorder,
                    syncEventSignalWatcher: syncEventSignalWatcher
                )
                .environmentObject(supabaseAuthViewModel)
                .onOpenURL { url in
                    _ = supabaseAuthViewModel.handleOpenURL(url)
                }
            }
        }
        .modelContainer(for: [
            Product.self,
            Supplier.self,
            ProductCategory.self,
            HistoryEntry.self,
            ProductPrice.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self,
            SyncEventOutboxEntry.self,
            LocalPendingChange.self
        ])
    }

    private static var isRunningHostedXCTest: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            && ProcessInfo.processInfo.environment["TASK115_REAL_ROOT_LIFECYCLE_TEST"] != "1"
    }

    private static func makeHostedXCTestDependencies() -> SupabaseAppDependencies {
        SupabaseAppDependencies(
            authViewModel: SupabaseAuthViewModel(authService: nil, initialError: .configMissing),
            supabaseTransportClient: nil,
            pullPreviewService: nil,
            syncEventOutboxDrainRecorder: nil,
            syncEventSignalWatcher: nil
        )
    }

    private static func makeSupabaseDependencies() -> SupabaseAppDependencies {
        do {
            let config = try SupabaseConfig.load()
            let provider = SupabaseClientProvider(config: config)
            let authService = SupabaseAuthService(provider: provider)
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
            return SupabaseAppDependencies(
                authViewModel: SupabaseAuthViewModel(authService: authService),
                supabaseTransportClient: supabaseTransportClient,
                pullPreviewService: previewService,
                syncEventOutboxDrainRecorder: syncEventOutboxDrainRecorder,
                syncEventSignalWatcher: syncEventSignalWatcher
            )
        } catch SupabaseConfigError.configMissing {
            return SupabaseAppDependencies(
                authViewModel: SupabaseAuthViewModel(authService: nil, initialError: .configMissing),
                supabaseTransportClient: nil,
                pullPreviewService: nil,
                syncEventOutboxDrainRecorder: nil,
                syncEventSignalWatcher: nil
            )
        } catch SupabaseConfigError.invalidConfig {
            return SupabaseAppDependencies(
                authViewModel: SupabaseAuthViewModel(authService: nil, initialError: .invalidConfig),
                supabaseTransportClient: nil,
                pullPreviewService: nil,
                syncEventOutboxDrainRecorder: nil,
                syncEventSignalWatcher: nil
            )
        } catch {
            return SupabaseAppDependencies(
                authViewModel: SupabaseAuthViewModel(authService: nil, initialError: .unknown(message: String(describing: error))),
                supabaseTransportClient: nil,
                pullPreviewService: nil,
                syncEventOutboxDrainRecorder: nil,
                syncEventSignalWatcher: nil
            )
        }
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
}
