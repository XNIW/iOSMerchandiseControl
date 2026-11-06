import Foundation

protocol SupabaseSyncEventIncrementalFetching: Sendable {
    func fetchSyncEventsAfter(ownerUserID: UUID, afterID: Int64, limit: Int) async throws -> [RemoteSyncEventRow]
}

/// Implemented only by the V6 server-authorized event adapter.  It keeps the
/// durable opaque scope fence in lockstep with a locally committed watermark;
/// it is deliberately a narrow persistence boundary, not another sync state
/// machine or policy path.
protocol ShopScopedIncrementalFencePersisting: Sendable {
    func advanceDurableFence(
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        from watermark: Int64,
        through newWatermark: Int64
    ) async throws
}

/// Production V6 binds a local material receipt to the opaque authorization
/// of the page that was applied, including when its previous cursor was zero.
protocol ShopScopedMaterialFencePersisting: ShopScopedIncrementalFencePersisting {
    func verifiedScopeKey(scope: Task126VerifiedOwnerStoreScope, baseline: Int64, through: Int64) async throws -> String
    func advanceDurableFence(ownerUserID: UUID, scope: Task126VerifiedOwnerStoreScope,
                             from: Int64, through: Int64, expectedScopeKey: String) async throws
}

nonisolated enum SupabaseSyncEventIncrementalLimits {
    // Frozen V6 event-page contract: 150 rows maximum.
    static let maximumLimit = 150
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
