import Foundation
import SwiftData

@MainActor
enum SyncAutomaticRuntimeFactory {
    static func make(
        modelContainer: ModelContainer,
        authViewModel: SupabaseAuthViewModel,
        inventoryService: SupabaseInventoryService?,
        activityRecorder: (any SyncEventRecording)?
    ) -> any SyncAutomaticRuntimeProviding {
        let catalogPushProvider: (any SyncCatalogPushProviding)? = inventoryService.map {
            CatalogPushService(modelContainer: modelContainer, remote: $0)
        }
        let productPriceProvider: (any SyncProductPriceSyncProviding)? = inventoryService.map {
            ProductPricePushService(modelContainer: modelContainer, remote: $0)
        }
        let historySessionProvider: (any SyncHistorySessionPushProviding)? = inventoryService.map {
            HistorySessionPushService(
                modelContainer: modelContainer,
                remote: $0,
                recorder: activityRecorder
            )
        }
        let incrementalPullProvider: (any SyncIncrementalPullProviding)? = inventoryService.map {
            SyncEventIncrementalPullService(
                modelContainer: modelContainer,
                remote: $0
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
            activityRegistrationProvider: activityRegistrationProvider
        )
    }
}
