import Foundation
import Supabase

struct SyncEventRemoteSupabaseAdapter: SyncAutomaticIncrementalRemote {
    let remote: SupabaseTransportClient

    private var query: SupabaseRemoteQueryExecutor {
        SupabaseRemoteQueryExecutor(transport: remote)
    }

    private var catalog: CatalogRemoteSupabaseAdapter {
        CatalogRemoteSupabaseAdapter(remote: remote)
    }

    private var productPrices: ProductPriceRemoteSupabaseAdapter {
        ProductPriceRemoteSupabaseAdapter(remote: remote)
    }

    private var history: HistorySessionRemoteSupabaseAdapter {
        HistorySessionRemoteSupabaseAdapter(remote: remote)
    }

    func fetchSyncEventsAfter(ownerUserID: UUID, afterID: Int64, limit: Int) async throws -> [RemoteSyncEventRow] {
        let authenticatedUserID = try await query.requireOwner()
        guard authenticatedUserID == ownerUserID else {
            throw SupabaseTransportClientError.permissionDeniedOrRLS(
                statusCode: nil,
                code: nil,
                message: "sync event owner mismatch"
            )
        }

        let client = await query.client()
        let effectiveLimit = max(1, min(limit, SupabaseSyncEventIncrementalLimits.maximumLimit))
        do {
            var request = client
                .from("sync_events")
                .select("id,owner_user_id,shop_id,store_id,domain,event_type,source,source_device_id,batch_id,client_event_id,changed_count,entity_ids,created_at,expires_at,metadata")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .gt("id", value: Int(afterID))
            if let selectedShopID = ShopContextSelection.selectedShopID(ownerUserID: ownerUserID) {
                request = request.eq("shop_id", value: selectedShopID.uuidString)
            }
            return try await request
                .order("id", ascending: true)
                .limit(effectiveLimit)
                .execute()
                .value
        } catch let error as DecodingError {
            throw await remote.mapDecodingError(error)
        } catch let error as PostgrestError {
            throw await remote.mapPostgrestError(error)
        } catch let error as URLError {
            throw await remote.networkError(error)
        } catch {
            throw SupabaseTransportClientError.unknown(message: String(describing: error))
        }
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
        try await catalog.fetchCatalogByIDs(
            supplierIDs: supplierIDs,
            categoryIDs: categoryIDs,
            productIDs: productIDs
        )
    }

    func fetchProductPricesByIDs(
        ownerUserID: UUID,
        priceIDs: Set<UUID>
    ) async throws -> [RemoteInventoryProductPriceRow] {
        try await productPrices.fetchProductPricesByIDs(ownerUserID: ownerUserID, priceIDs: priceIDs)
    }

    func upsertSharedSheetSessions(
        _ rows: [SharedSheetSessionUpsertRow],
        ownerUserID: UUID
    ) async throws -> [RemoteSharedSheetSessionRow] {
        try await history.upsertSharedSheetSessions(rows, ownerUserID: ownerUserID)
    }

    func fetchSharedSheetSessionsPage(
        ownerUserID: UUID,
        from: Int,
        to: Int
    ) async throws -> [RemoteSharedSheetSessionRow] {
        try await history.fetchSharedSheetSessionsPage(ownerUserID: ownerUserID, from: from, to: to)
    }

    func fetchSharedSheetSessionsByIDs(
        ownerUserID: UUID,
        sessionIDs: Set<UUID>
    ) async throws -> [RemoteSharedSheetSessionRow] {
        try await history.fetchSharedSheetSessionsByIDs(ownerUserID: ownerUserID, sessionIDs: sessionIDs)
    }

    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot {
        try await OptionsRemoteCountSupabaseAdapter(remote: remote).fetchReconciliationRemoteCounts()
    }
}
