import Foundation
import SwiftData

protocol SupabaseSyncEventIncrementalFetching: Sendable {
    func fetchSyncEventsAfter(ownerUserID: UUID, afterID: Int64, limit: Int) async throws -> [RemoteSyncEventRow]
}

nonisolated enum SupabaseSyncEventIncrementalLimits {
    static let maximumLimit = 200
}

nonisolated enum RuntimeSyncExecutionType: String, Sendable, Equatable {
    case eventIncremental = "EVENT_INCREMENTAL"
    case checkpointIncremental = "CHECKPOINT_INCREMENTAL"
    case lightReconcile = "LIGHT_RECONCILE"
    case fullPullBootstrap = "FULL_PULL_BOOTSTRAP"
    case fullPullRecovery = "FULL_PULL_RECOVERY"
}

nonisolated struct SupabaseSyncEventIncrementalApplySummary: Sendable, Equatable {
    var syncType: RuntimeSyncExecutionType
    var eventsFetched: Int = 0
    var eventsProcessed: Int = 0
    var watermarkBefore: Int64 = 0
    var watermarkAfter: Int64 = 0
    var targetedSuppliersFetched: Int = 0
    var targetedCategoriesFetched: Int = 0
    var targetedProductsFetched: Int = 0
    var targetedProductPricesFetched: Int = 0
    var targetedHistoryFetched: Int = 0
    var productsInserted: Int = 0
    var productsUpdated: Int = 0
    var productsTombstoned: Int = 0
    var suppliersCreated: Int = 0
    var categoriesCreated: Int = 0
    var productPricesInserted: Int = 0
    var productPriceIdentityLinked: Int = 0
    var productPricesMissingRemotePruned: Int = 0
    var historyInserted: Int = 0
    var historyUpdated: Int = 0
    var historyMissingRemoteTombstoned: Int = 0
    var suppliersMissingRemoteTombstoned: Int = 0
    var categoriesMissingRemoteTombstoned: Int = 0
    var requiresFullRecoveryReason: String?
    var eventPageFetchMs: Int = 0
    var catalogFetchMs: Int = 0
    var catalogApplyMs: Int = 0
    var productPriceFetchMs: Int = 0
    var productPriceApplyMs: Int = 0
    var historyFetchMs: Int = 0
    var historyApplyMs: Int = 0
    var totalElapsedMs: Int = 0

    static func noWork(watermark: Int64) -> Self {
        SupabaseSyncEventIncrementalApplySummary(
            syncType: .checkpointIncremental,
            watermarkBefore: watermark,
            watermarkAfter: watermark
        )
    }

    var requiresFullRecovery: Bool {
        requiresFullRecoveryReason != nil
    }

    var totalApplied: Int {
        productsInserted
            + productsUpdated
            + productsTombstoned
            + suppliersCreated
            + categoriesCreated
            + productPricesInserted
            + productPriceIdentityLinked
            + productPricesMissingRemotePruned
            + historyInserted
            + historyUpdated
            + historyMissingRemoteTombstoned
            + suppliersMissingRemoteTombstoned
            + categoriesMissingRemoteTombstoned
    }
}

nonisolated struct SupabaseSyncEventIncrementalApplyService {
    private let domainService: SyncEventIncrementalDomainApplyService

    init(
        eventFetcher: any SupabaseSyncEventIncrementalFetching,
        inventoryService: SupabaseInventoryService,
        defaults: UserDefaults = .standard,
        watermarkStore: WatermarkStore? = nil,
        limit: Int = 50
    ) {
        self.domainService = SyncEventIncrementalDomainApplyService(
            eventFetcher: eventFetcher,
            inventoryService: inventoryService,
            defaults: defaults,
            watermarkStore: watermarkStore,
            limit: limit
        )
    }

    func applyNextEvents(
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        isAuthenticated: Bool
    ) async throws -> SupabaseSyncEventIncrementalApplySummary {
        try await domainService.applyNextEvents(
            ownerUserID: ownerUserID,
            modelContainer: modelContainer,
            isAuthenticated: isAuthenticated
        )
    }

    static func watermarkKey(ownerUserID: UUID) -> String {
        SyncEventIncrementalDomainApplyService.watermarkKey(ownerUserID: ownerUserID)
    }

    static func markWatermarkAfterFullRecovery(
        ownerUserID: UUID,
        watermark: Int64,
        defaults: UserDefaults = .standard
    ) {
        SyncEventIncrementalDomainApplyService.markWatermarkAfterFullRecovery(
            ownerUserID: ownerUserID,
            watermark: watermark,
            defaults: defaults
        )
    }
}
