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
        try await query.fetchRowsPage(
            table: "inventory_product_prices",
            columns: ProductPriceRemoteSupabaseAdapter.productPriceColumns,
            from: from,
            to: to
        )
    }

    func fetchProductPricesPreviewPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        try await fetchProductPricesPage(from: from, to: to)
    }

    func fetchProductPricesPreviewPage(afterID: UUID?, limit: Int) async throws -> [RemoteInventoryProductPriceRow] {
        let ownerUserID = try await query.requireOwner()
        let client = await query.client()
        let pageLimit = max(1, min(limit, 1_000))

        do {
            var request = client
                .from("inventory_product_prices")
                .select("id,owner_user_id,product_id,type,price,effective_at,created_at")
                .eq("owner_user_id", value: ownerUserID.uuidString)
            if let afterID {
                request = request.gt("id", value: afterID.uuidString)
            }
            return try await request
                .order("id", ascending: true)
                .limit(pageLimit)
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
        let start = max(0, from)
        let end = max(start, min(to, start + 999))
        do {
            return try await client
                .from("inventory_product_prices")
                .select(ProductPriceRemoteSupabaseAdapter.productPriceColumns)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .in("product_id", values: sortedProductIDs)
                .order("product_id", ascending: true)
                .order("type", ascending: true)
                .order("effective_at", ascending: true)
                .order("id", ascending: true)
                .range(from: start, to: end)
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
}
