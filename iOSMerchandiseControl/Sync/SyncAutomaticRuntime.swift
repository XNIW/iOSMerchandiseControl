import Foundation
import SwiftData

protocol SyncAutomaticRuntimeProviding: AnyObject {
    @MainActor
    var isRunning: Bool { get }

    @MainActor
    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> SyncAutomaticRunResult
    @MainActor
    func cancel()
}

@MainActor
final class SyncNoopAutomaticRuntime: SyncAutomaticRuntimeProviding {
    var isRunning: Bool { false }

    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> SyncAutomaticRunResult {
        .noWork()
    }

    func cancel() {}
}

@MainActor
final class SyncAutomaticRuntime: SyncAutomaticRuntimeProviding {
    private let authViewModel: SupabaseAuthViewModel
    private let engine: AutomaticSyncEngine
    private var facadeIsRunning = false

    init(
        authViewModel: SupabaseAuthViewModel,
        catalogPushProvider: (any SyncCatalogPushProviding)?,
        productPriceProvider: (any SyncProductPriceSyncProviding)?,
        historySessionProvider: (any SyncHistorySessionPushProviding)?,
        incrementalPullProvider: (any SyncIncrementalPullProviding)?,
        activityRegistrationProvider: (any SyncActivityRegistrationProviding)?,
        defaults: UserDefaults = .standard
    ) {
        self.authViewModel = authViewModel
        self.engine = AutomaticSyncEngine(
            catalogPushProvider: catalogPushProvider,
            productPriceProvider: productPriceProvider,
            historySessionProvider: historySessionProvider,
            incrementalPullProvider: incrementalPullProvider,
            activityRegistrationProvider: activityRegistrationProvider,
            defaults: defaults
        )
    }

    var isRunning: Bool {
        facadeIsRunning
    }

    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> SyncAutomaticRunResult {
        guard authViewModel.isSignedIn,
              let ownerUserID = authViewModel.sessionInfo?.userID else {
            await engine.recordAuthBlocked()
            return .blocked(.authRequired)
        }
        facadeIsRunning = true
        defer {
            facadeIsRunning = false
        }
        return await engine.run(action: action, source: source, ownerUserID: ownerUserID)
    }

    func cancel() {
        Task {
            await engine.cancel()
        }
    }
}

@MainActor
enum SyncAutomaticRuntimeFactory {
    static func make(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        inventoryService: SupabaseInventoryService?,
        activityRecorder: (any SyncEventRecording)?
    ) -> any SyncAutomaticRuntimeProviding {
        let modelContainer = context.container
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
        return SyncAutomaticRuntime(
            authViewModel: authViewModel,
            catalogPushProvider: catalogPushProvider,
            productPriceProvider: productPriceProvider,
            historySessionProvider: historySessionProvider,
            incrementalPullProvider: incrementalPullProvider,
            activityRegistrationProvider: activityRegistrationProvider
        )
    }
}
