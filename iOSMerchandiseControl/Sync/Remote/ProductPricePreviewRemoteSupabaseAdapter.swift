import Foundation
import Supabase

struct ProductPricePreviewRemoteSupabaseAdapter:
    SupabaseProductPriceKeysetFetching,
    SupabaseProductPriceDeletedProductFetching,
    SupabaseProductPricePushDryRunRemoteFetching {
    let remote: SupabaseTransportClient

    private var query: SupabaseRemoteQueryExecutor {
        SupabaseRemoteQueryExecutor(transport: remote)
    }

    static let stablePageOrderColumns = ["id"]

    func fetchProductPricesPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        let automaticScope = try currentAutomaticScopeIfPresent()
        let rows: [RemoteInventoryProductPriceRow] = try await query.fetchRowsPage(
            table: "inventory_product_prices",
            columns: ProductPriceRemoteSupabaseAdapter.productPriceColumns,
            from: from,
            to: to
        )
        try validateAutomaticRows(rows, scope: automaticScope)
        return rows
    }

    func fetchProductPricesPreviewPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        try await fetchProductPricesPage(from: from, to: to)
    }

    func fetchProductPricesPreviewPage(afterID: UUID?, limit: Int) async throws -> [RemoteInventoryProductPriceRow] {
        let ownerUserID = try await query.requireOwner()
        let client = await query.client()
        let automaticScope = try currentAutomaticScope(ownerUserID: ownerUserID)
        let pageLimit = max(1, min(limit, 1_000))

        do {
            var request = client
                .from("inventory_product_prices")
                .select("id,owner_user_id,shop_id,product_id,type,price,effective_at,created_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
            if let selectedShopID = automaticScope?.shopID
                ?? ShopContextSelection.selectedShopID(ownerUserID: ownerUserID) {
                request = request.eq("shop_id", value: selectedShopID.uuidString)
            }
            if let afterID {
                request = request.gt("id", value: afterID.uuidString)
            }
            let rows: [RemoteInventoryProductPriceRow] = try await request
                .order("id", ascending: true)
                .limit(pageLimit)
                .execute()
                .value
            try validateAutomaticRows(rows, scope: automaticScope)
            return rows
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as Task126OwnerStoreGateError {
            throw error
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

    func fetchProductPriceCount() async throws -> Int? {
        try await query.exactRowCount(table: "inventory_product_prices", ownerUserID: nil, activeOnly: false)
    }

    func fetchDeletedProductIDs(pageSize: Int = 1_000) async throws -> Set<UUID> {
        try await CatalogRemoteSupabaseAdapter(remote: remote).fetchDeletedProductIDs(pageSize: pageSize)
    }

    func fetchProductPricesForPushDryRunDedupePage(
        ownerUserID: UUID,
        productIDs: [UUID],
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow] {
        try await fetchProductPricesForProducts(ownerUserID: ownerUserID, productIDs: productIDs, from: from, to: to)
    }

    private func fetchProductPricesForProducts(
        ownerUserID: UUID,
        productIDs: [UUID],
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow] {
        let authenticatedUserID = try await query.requireOwner()
        guard ownerUserID == authenticatedUserID else {
            throw SupabaseTransportClientError.permissionDeniedOrRLS(statusCode: nil, code: nil, message: "owner mismatch")
        }
        let sortedProductIDs = productIDs
            .sorted { $0.uuidString < $1.uuidString }
            .map(\.uuidString)
        guard !sortedProductIDs.isEmpty else { return [] }

        let client = await query.client()
        let automaticScope = try currentAutomaticScope(ownerUserID: ownerUserID)
        let start = max(0, from)
        let end = max(start, min(to, start + 999))
        do {
            var request = client
                .from("inventory_product_prices")
                .select(ProductPriceRemoteSupabaseAdapter.productPriceColumns)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .in("product_id", values: sortedProductIDs)
            if let selectedShopID = automaticScope?.shopID
                ?? ShopContextSelection.selectedShopID(ownerUserID: ownerUserID) {
                request = request.eq("shop_id", value: selectedShopID.uuidString)
            }
            let rows: [RemoteInventoryProductPriceRow] = try await request
                .order("product_id", ascending: true)
                .order("type", ascending: true)
                .order("effective_at", ascending: true)
                .order("id", ascending: true)
                .range(from: start, to: end)
                .execute()
                .value
            try validateAutomaticRows(rows, scope: automaticScope)
            return rows
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as Task126OwnerStoreGateError {
            throw error
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

    private func currentAutomaticScope(
        ownerUserID: UUID
    ) throws -> Task126VerifiedOwnerStoreScope? {
        guard let scope = try currentAutomaticScopeIfPresent() else { return nil }
        guard scope.ownerUserID == ownerUserID else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
        return scope
    }

    private func currentAutomaticScopeIfPresent() throws -> Task126VerifiedOwnerStoreScope? {
        guard let scope = Task126OwnerStoreGate.currentAutomaticScope else { return nil }
        try Task126OwnerStoreGate.revalidateCurrentAutomaticScopeLeaseIfPresent()
        return scope
    }

    private func validateAutomaticRows(
        _ rows: [RemoteInventoryProductPriceRow],
        scope: Task126VerifiedOwnerStoreScope?
    ) throws {
        guard let scope else { return }
        try Task126OwnerStoreGate.revalidateCurrentAutomaticScopeLeaseIfPresent()
        for row in rows {
            try Task126OwnerStoreGate.validateRemoteIdentity(
                ownerUserID: row.ownerUserID,
                shopID: row.shopID,
                scope: scope
            )
        }
    }
}
