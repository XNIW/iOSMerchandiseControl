import Foundation
import SwiftData

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

    init(
        syncType: RuntimeSyncExecutionType,
        eventsFetched: Int = 0,
        eventsProcessed: Int = 0,
        watermarkBefore: Int64 = 0,
        watermarkAfter: Int64 = 0,
        targetedSuppliersFetched: Int = 0,
        targetedCategoriesFetched: Int = 0,
        targetedProductsFetched: Int = 0,
        targetedProductPricesFetched: Int = 0,
        targetedHistoryFetched: Int = 0,
        productsInserted: Int = 0,
        productsUpdated: Int = 0,
        productsTombstoned: Int = 0,
        suppliersCreated: Int = 0,
        categoriesCreated: Int = 0,
        productPricesInserted: Int = 0,
        productPriceIdentityLinked: Int = 0,
        productPricesMissingRemotePruned: Int = 0,
        historyInserted: Int = 0,
        historyUpdated: Int = 0,
        historyMissingRemoteTombstoned: Int = 0,
        suppliersMissingRemoteTombstoned: Int = 0,
        categoriesMissingRemoteTombstoned: Int = 0,
        requiresFullRecoveryReason: String? = nil,
        eventPageFetchMs: Int = 0,
        catalogFetchMs: Int = 0,
        catalogApplyMs: Int = 0,
        productPriceFetchMs: Int = 0,
        productPriceApplyMs: Int = 0,
        historyFetchMs: Int = 0,
        historyApplyMs: Int = 0,
        totalElapsedMs: Int = 0
    ) {
        self.syncType = syncType
        self.eventsFetched = eventsFetched
        self.eventsProcessed = eventsProcessed
        self.watermarkBefore = watermarkBefore
        self.watermarkAfter = watermarkAfter
        self.targetedSuppliersFetched = targetedSuppliersFetched
        self.targetedCategoriesFetched = targetedCategoriesFetched
        self.targetedProductsFetched = targetedProductsFetched
        self.targetedProductPricesFetched = targetedProductPricesFetched
        self.targetedHistoryFetched = targetedHistoryFetched
        self.productsInserted = productsInserted
        self.productsUpdated = productsUpdated
        self.productsTombstoned = productsTombstoned
        self.suppliersCreated = suppliersCreated
        self.categoriesCreated = categoriesCreated
        self.productPricesInserted = productPricesInserted
        self.productPriceIdentityLinked = productPriceIdentityLinked
        self.productPricesMissingRemotePruned = productPricesMissingRemotePruned
        self.historyInserted = historyInserted
        self.historyUpdated = historyUpdated
        self.historyMissingRemoteTombstoned = historyMissingRemoteTombstoned
        self.suppliersMissingRemoteTombstoned = suppliersMissingRemoteTombstoned
        self.categoriesMissingRemoteTombstoned = categoriesMissingRemoteTombstoned
        self.requiresFullRecoveryReason = requiresFullRecoveryReason
        self.eventPageFetchMs = eventPageFetchMs
        self.catalogFetchMs = catalogFetchMs
        self.catalogApplyMs = catalogApplyMs
        self.productPriceFetchMs = productPriceFetchMs
        self.productPriceApplyMs = productPriceApplyMs
        self.historyFetchMs = historyFetchMs
        self.historyApplyMs = historyApplyMs
        self.totalElapsedMs = totalElapsedMs
    }

    init(_ summary: SyncIncrementalPullSummary) {
        self.init(
            syncType: summary.syncType,
            eventsFetched: summary.eventsFetched,
            eventsProcessed: summary.eventsProcessed,
            watermarkBefore: summary.watermarkBefore,
            watermarkAfter: summary.watermarkAfter,
            targetedSuppliersFetched: summary.targetedSuppliersFetched,
            targetedCategoriesFetched: summary.targetedCategoriesFetched,
            targetedProductsFetched: summary.targetedProductsFetched,
            targetedProductPricesFetched: summary.targetedProductPricesFetched,
            targetedHistoryFetched: summary.targetedHistoryFetched,
            productsInserted: summary.productsInserted,
            productsUpdated: summary.productsUpdated,
            productsTombstoned: summary.productsTombstoned,
            suppliersCreated: summary.suppliersCreated,
            categoriesCreated: summary.categoriesCreated,
            productPricesInserted: summary.productPricesInserted,
            productPriceIdentityLinked: summary.productPriceIdentityLinked,
            productPricesMissingRemotePruned: summary.productPricesMissingRemotePruned,
            historyInserted: summary.historyInserted,
            historyUpdated: summary.historyUpdated,
            historyMissingRemoteTombstoned: summary.historyMissingRemoteTombstoned,
            suppliersMissingRemoteTombstoned: summary.suppliersMissingRemoteTombstoned,
            categoriesMissingRemoteTombstoned: summary.categoriesMissingRemoteTombstoned,
            requiresFullRecoveryReason: summary.requiresFullRecoveryReason,
            eventPageFetchMs: summary.eventPageFetchMs,
            catalogFetchMs: summary.catalogFetchMs,
            catalogApplyMs: summary.catalogApplyMs,
            productPriceFetchMs: summary.productPriceFetchMs,
            productPriceApplyMs: summary.productPriceApplyMs,
            historyFetchMs: summary.historyFetchMs,
            historyApplyMs: summary.historyApplyMs,
            totalElapsedMs: summary.totalElapsedMs
        )
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
        let remoteAdapter = SyncEventRemoteSupabaseAdapter(remote: inventoryService)
        self.domainService = SyncEventIncrementalDomainApplyService(
            eventFetcher: eventFetcher,
            remote: remoteAdapter,
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
        let summary = try await domainService.applyNextEvents(
            ownerUserID: ownerUserID,
            modelContainer: modelContainer,
            isAuthenticated: isAuthenticated
        )
        return SupabaseSyncEventIncrementalApplySummary(summary)
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
