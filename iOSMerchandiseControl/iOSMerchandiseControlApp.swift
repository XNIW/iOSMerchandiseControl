import SwiftUI
import SwiftData

@main
struct iOSMerchandiseControlApp: App {
    @StateObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    private let supabaseInventoryService: SupabaseInventoryService?
    private let supabasePullPreviewService: SupabasePullPreviewService?
    private let supabaseManualPushService: SupabaseManualPushService?
    private let syncEventOutboxDrainRecorder: (any SyncEventRecording)?

    init() {
        let dependencies = Self.makeSupabaseDependencies()
        _supabaseAuthViewModel = StateObject(wrappedValue: dependencies.authViewModel)
        supabaseInventoryService = dependencies.inventoryService
        supabasePullPreviewService = dependencies.pullPreviewService
        supabaseManualPushService = dependencies.manualPushService
        syncEventOutboxDrainRecorder = dependencies.syncEventOutboxDrainRecorder
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                supabaseInventoryService: supabaseInventoryService,
                supabasePullPreviewService: supabasePullPreviewService,
                supabaseManualPushService: supabaseManualPushService,
                syncEventOutboxDrainRecorder: syncEventOutboxDrainRecorder
            )
            .environmentObject(supabaseAuthViewModel)
            .onOpenURL { url in
                _ = supabaseAuthViewModel.handleOpenURL(url)
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

    private static func makeSupabaseDependencies() -> SupabaseAppDependencies {
        do {
            let config = try SupabaseConfig.load()
            let provider = SupabaseClientProvider(config: config)
            let authService = SupabaseAuthService(provider: provider)
            let inventoryService = SupabaseInventoryService(clientProvider: provider)
            let previewService = SupabasePullPreviewService(
                inventoryService: inventoryService,
                pageSize: 1_000,
                catalogRowBudget: nil,
                productPricePreviewSampleLimit: 1_000
            )
            let manualPushService = SupabaseManualPushService(clientProvider: provider)
            let syncEventOutboxDrainRecorder: (any SyncEventRecording)? = SupabaseSyncEventLiveRecorder(
                configProvider: SupabaseSyncEventLiveRecorderConfigurationProvider(),
                sessionProvider: authService,
                transport: SupabaseSyncEventRPCTransport(clientProvider: provider)
            )
            return SupabaseAppDependencies(
                authViewModel: SupabaseAuthViewModel(authService: authService),
                inventoryService: inventoryService,
                pullPreviewService: previewService,
                manualPushService: manualPushService,
                syncEventOutboxDrainRecorder: syncEventOutboxDrainRecorder
            )
        } catch SupabaseConfigError.configMissing {
            return SupabaseAppDependencies(
                authViewModel: SupabaseAuthViewModel(authService: nil, initialError: .configMissing),
                inventoryService: nil,
                pullPreviewService: nil,
                manualPushService: nil,
                syncEventOutboxDrainRecorder: nil
            )
        } catch SupabaseConfigError.invalidConfig {
            return SupabaseAppDependencies(
                authViewModel: SupabaseAuthViewModel(authService: nil, initialError: .invalidConfig),
                inventoryService: nil,
                pullPreviewService: nil,
                manualPushService: nil,
                syncEventOutboxDrainRecorder: nil
            )
        } catch {
            return SupabaseAppDependencies(
                authViewModel: SupabaseAuthViewModel(authService: nil, initialError: .unknown(message: String(describing: error))),
                inventoryService: nil,
                pullPreviewService: nil,
                manualPushService: nil,
                syncEventOutboxDrainRecorder: nil
            )
        }
    }
}

private struct SupabaseAppDependencies {
    let authViewModel: SupabaseAuthViewModel
    let inventoryService: SupabaseInventoryService?
    let pullPreviewService: SupabasePullPreviewService?
    let manualPushService: SupabaseManualPushService?
    let syncEventOutboxDrainRecorder: (any SyncEventRecording)?
}
