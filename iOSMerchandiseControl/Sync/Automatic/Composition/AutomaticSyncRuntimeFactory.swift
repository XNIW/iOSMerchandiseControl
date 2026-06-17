import Foundation
import SwiftData

@MainActor
enum SyncAutomaticRuntimeFactory {
    static func make(
        modelContainer: ModelContainer,
        authViewModel: SupabaseAuthViewModel,
        supabaseTransportClient: SupabaseTransportClient?,
        activityRecorder: (any SyncEventRecording)?
    ) -> any SyncAutomaticRuntimeProviding {
        let catalogPushProvider: (any SyncCatalogPushProviding)? = supabaseTransportClient.map {
            CatalogPushService(
                modelContainer: modelContainer,
                remote: CatalogRemoteSupabaseAdapter(remote: $0)
            )
        }
        let productPriceProvider: (any SyncProductPriceSyncProviding)? = supabaseTransportClient.map {
            ProductPricePushService(
                modelContainer: modelContainer,
                remote: ProductPriceRemoteSupabaseAdapter(remote: $0)
            )
        }
        let historySessionProvider: (any SyncHistorySessionPushProviding)? = supabaseTransportClient.map {
            HistorySessionPushService(
                modelContainer: modelContainer,
                remote: HistorySessionRemoteSupabaseAdapter(remote: $0),
                recorder: activityRecorder
            )
        }
        let incrementalPullProvider: (any SyncIncrementalPullProviding)? = supabaseTransportClient.map {
            SyncEventIncrementalPullService(
                modelContainer: modelContainer,
                remote: SyncEventRemoteSupabaseAdapter(remote: $0)
            )
        }
        let recoverySnapshotPullProvider: (any SyncRecoverySnapshotPullProviding)? = supabaseTransportClient.map {
            AutomaticRecoverySnapshotPullService(
                modelContainer: modelContainer,
                previewService: SupabasePullPreviewService(
                    inventoryService: RecoveryRemoteSupabaseAdapter(remote: $0),
                    pageSize: 1_000,
                    catalogRowBudget: nil,
                    productPricePreviewSampleLimit: 1_000
                ),
                productPriceApplyService: SupabaseProductPriceApplyService(
                    fetcher: ProductPriceReleaseRemoteSupabaseAdapter(remote: $0),
                    fetchOptions: ProductPriceApplyFetchOptions(replaceLocalSnapshot: true)
                ),
                historyRemote: HistorySessionRemoteSupabaseAdapter(remote: $0),
                syncEventFetcher: SyncEventRemoteSupabaseAdapter(remote: $0)
            )
        }
        let activityRegistrationProvider: (any SyncActivityRegistrationProviding)? = SyncActivityRegistrationService(
            modelContainer: modelContainer,
            recorder: activityRecorder
        )
        return AutomaticSyncRuntimeFacade(
            authViewModel: authViewModel,
            catalogPushProvider: catalogPushProvider,
            productPriceProvider: productPriceProvider,
            historySessionProvider: historySessionProvider,
            incrementalPullProvider: incrementalPullProvider,
            recoverySnapshotPullProvider: recoverySnapshotPullProvider,
            activityRegistrationProvider: activityRegistrationProvider
        )
    }
}
