import Foundation
import Supabase

struct SyncEventRemoteSupabaseAdapter: SyncAutomaticIncrementalRemote, OptionsSyncRemoteCountFetching {
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
            return try await client
                .from("sync_events")
                .select("id,owner_user_id,store_id,domain,event_type,source,source_device_id,batch_id,client_event_id,changed_count,entity_ids,created_at,expires_at,metadata")
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .gt("id", value: Int(afterID))
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
        let ownerUserID = try await query.requireOwner()
        async let products = query.exactRowCount(table: "inventory_products", ownerUserID: ownerUserID, activeOnly: true)
        async let suppliers = query.exactRowCount(table: "inventory_suppliers", ownerUserID: ownerUserID, activeOnly: true)
        async let categories = query.exactRowCount(table: "inventory_categories", ownerUserID: ownerUserID, activeOnly: true)
        async let prices = fetchActiveProductPriceCount(ownerUserID: ownerUserID)
        async let history = query.exactRowCount(table: "shared_sheet_sessions", ownerUserID: ownerUserID, activeOnly: true)
        return SyncInventoryCountSnapshot(
            products: try await products ?? 0,
            suppliers: try await suppliers ?? 0,
            categories: try await categories ?? 0,
            productPrices: try await prices ?? 0,
            historySessions: try await history ?? 0
        )
    }

    private func fetchActiveProductPriceCount(ownerUserID: UUID) async throws -> Int? {
        let client = await query.client()
        do {
            return try await client
                .from("inventory_product_prices")
                .select("id,inventory_products!inner(id)", head: true, count: .exact)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .is("inventory_products.deleted_at", value: nil)
                .execute()
                .count
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
}
