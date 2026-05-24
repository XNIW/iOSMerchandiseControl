import Foundation

nonisolated struct SyncIncrementalPullSummary: Sendable, Equatable {
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
        SyncIncrementalPullSummary(
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

protocol SyncIncrementalPullProviding: AnyObject {
    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SyncIncrementalPullSummary
}
