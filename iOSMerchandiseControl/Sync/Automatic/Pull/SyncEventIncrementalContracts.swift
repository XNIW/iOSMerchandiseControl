import Foundation

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

protocol SyncAutomaticCatalogIncrementalReading: Sendable {
    func fetchCatalogByIDs(
        supplierIDs: Set<UUID>,
        categoryIDs: Set<UUID>,
        productIDs: Set<UUID>
    ) async throws -> (
        suppliers: [RemoteInventorySupplierRow],
        categories: [RemoteInventoryCategoryRow],
        products: [RemoteInventoryProductRow]
    )
}

protocol SyncAutomaticProductPriceIncrementalReading: Sendable {
    func fetchProductPricesByIDs(
        ownerUserID: UUID,
        priceIDs: Set<UUID>
    ) async throws -> [RemoteInventoryProductPriceRow]
}

protocol SyncAutomaticReconciliationReading: Sendable {
    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot
}

protocol SyncAutomaticIncrementalRemote:
    SupabaseSyncEventIncrementalFetching,
    SyncAutomaticCatalogIncrementalReading,
    SyncAutomaticProductPriceIncrementalReading,
    HistorySessionRemoteWriting,
    SyncAutomaticReconciliationReading
{}
