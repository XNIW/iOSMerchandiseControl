import Foundation
import SwiftData

@MainActor
enum SyncAutomaticRuntimeFactory {
    static func make(
        modelContainer: ModelContainer,
        authViewModel: SupabaseAuthViewModel,
        supabaseTransportClient: SupabaseTransportClient?,
        activityRecorder: (any SyncEventRecording)?,
        storeGenerationController: SyncStoreGenerationController,
        deviceAuthorization: (any ShopDeviceAuthorizationChecking)? = nil
    ) -> any SyncAutomaticRuntimeProviding {
        let generationLease = storeGenerationController.captureLease(for: modelContainer)
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
            AtomicGenerationRecoverySnapshotPullService(
                storeGenerationController: storeGenerationController,
                recoveryRemote: ShopSyncRecoveryRemoteAdapter(
                    transport: SupabaseShopSyncRecoveryRPCTransport(remote: $0)
                )
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
            activityRegistrationProvider: activityRegistrationProvider,
            deviceAuthorization: deviceAuthorization,
            runAdmissionValidator: {
                guard let generationLease else {
                    throw SyncStoreGenerationError.staleGenerationLease
                }
                try await MainActor.run {
                    try storeGenerationController.validateLease(generationLease)
                }
            }
        )
    }
}
