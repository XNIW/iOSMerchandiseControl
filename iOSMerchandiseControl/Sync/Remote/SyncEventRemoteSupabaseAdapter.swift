import Foundation

struct SyncEventRemoteSupabaseAdapter: SyncAutomaticIncrementalRemote {
    let remote: SupabaseTransportClient

    func fetchSyncEventsAfter(ownerUserID: UUID, afterID: Int64, limit: Int) async throws -> [RemoteSyncEventRow] {
        try await remote.fetchSyncEventsAfter(ownerUserID: ownerUserID, afterID: afterID, limit: limit)
    }

    func fetchCatalogByIDs(
        supplierIDs: Set<UUID>,
        categoryIDs: Set<UUID>,
        productIDs: Set<UUID>
    ) async throws -> (
        suppliers: [RemoteInventorySupplierRow],
        categories: [RemoteInventoryCategoryRow],
        products: [RemoteInventoryProductRow]
    ) {
        try await remote.fetchCatalogByIDs(
            supplierIDs: supplierIDs,
            categoryIDs: categoryIDs,
            productIDs: productIDs
        )
    }

    func fetchProductPricesByIDs(
        ownerUserID: UUID,
        priceIDs: Set<UUID>
    ) async throws -> [RemoteInventoryProductPriceRow] {
        try await remote.fetchProductPricesByIDs(ownerUserID: ownerUserID, priceIDs: priceIDs)
    }

    func upsertSharedSheetSessions(
        _ rows: [SharedSheetSessionUpsertRow],
        ownerUserID: UUID
    ) async throws -> [RemoteSharedSheetSessionRow] {
        try await remote.upsertSharedSheetSessions(rows, ownerUserID: ownerUserID)
    }

    func fetchSharedSheetSessionsPage(
        ownerUserID: UUID,
        from: Int,
        to: Int
    ) async throws -> [RemoteSharedSheetSessionRow] {
        try await remote.fetchSharedSheetSessionsPage(ownerUserID: ownerUserID, from: from, to: to)
    }

    func fetchSharedSheetSessionsByIDs(
        ownerUserID: UUID,
        sessionIDs: Set<UUID>
    ) async throws -> [RemoteSharedSheetSessionRow] {
        try await remote.fetchSharedSheetSessionsByIDs(ownerUserID: ownerUserID, sessionIDs: sessionIDs)
    }

    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot {
        try await remote.fetchReconciliationRemoteCounts()
    }
}
