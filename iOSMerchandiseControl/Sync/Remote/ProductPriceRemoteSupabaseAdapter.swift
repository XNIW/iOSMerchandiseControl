import Foundation
import Supabase

struct ProductPriceRemoteSupabaseAdapter: SyncAutomaticProductPriceRemoteWriting {
    let remote: SupabaseTransportClient

    private var query: SupabaseRemoteQueryExecutor {
        SupabaseRemoteQueryExecutor(transport: remote)
    }

    func insertProductPrices(_ payloads: [SyncAutomaticProductPricePayload]) async throws -> [RemoteInventoryProductPriceRow] {
        let ownerUserID = try await query.requireOwner()
        guard payloads.allSatisfy({ $0.ownerUserID == ownerUserID }) else {
            throw SupabaseTransportClientError.permissionDeniedOrRLS(statusCode: nil, code: nil, message: "Owner mismatch.")
        }
        let client = await query.client()
        do {
            return try await client
                .from("inventory_product_prices")
                .upsert(payloads, onConflict: "id")
                .select(Self.productPriceColumns)
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

extension ProductPriceRemoteSupabaseAdapter:
    SyncAutomaticProductPriceIncrementalReading,
    SupabaseProductPriceKeysetFetching,
    SupabaseProductPriceDeletedProductFetching,
    SupabaseProductPriceManualPushRemoteAccessing,
    SupabaseProductPricePushDryRunRemoteFetching {
    static let productPriceColumns = "id,owner_user_id,product_id,type,price,effective_at,source,note,created_at"
    static let stablePageOrderColumns = ["id"]

    func fetchProductPrices(limit: Int = 100) async throws -> [RemoteInventoryProductPriceRow] {
        try await query.fetchRows(
            table: "inventory_product_prices",
            columns: Self.productPriceColumns,
            limit: limit
        )
    }

    func fetchProductPricesByIDs(
        ownerUserID: UUID,
        priceIDs: Set<UUID>
    ) async throws -> [RemoteInventoryProductPriceRow] {
        guard !priceIDs.isEmpty else { return [] }
        let authenticatedUserID = try await query.requireOwner()
        guard authenticatedUserID == ownerUserID else {
            throw SupabaseTransportClientError.permissionDeniedOrRLS(
                statusCode: nil,
                code: nil,
                message: "ProductPrice owner mismatch"
            )
        }
        return try await query.fetchRowsByIDs(
            table: "inventory_product_prices",
            columns: Self.productPriceColumns,
            ids: priceIDs
        )
    }

    func fetchProductPricesPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        try await query.fetchRowsPage(
            table: "inventory_product_prices",
            columns: Self.productPriceColumns,
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

    func insertProductPriceManualPushPayloads(_ payloads: [ProductPriceManualPushPayload]) async throws -> [RemoteInventoryProductPriceRow] {
        let authenticatedUserID = try await query.requireOwner()
        guard !payloads.isEmpty else { return [] }
        guard payloads.allSatisfy({ $0.ownerUserID == authenticatedUserID }) else {
            throw ProductPriceManualPushError.invalidPayload
        }
        let client = await query.client()
        do {
            return try await client
                .from("inventory_product_prices")
                .insert(payloads)
                .select(Self.productPriceColumns)
                .execute()
                .value
        } catch let error as PostgrestError {
            throw await mapProductPriceManualPushPostgrestError(error)
        } catch let error as DecodingError {
            throw await remote.mapDecodingError(error)
        } catch let error as URLError {
            throw await remote.networkError(error)
        } catch {
            throw SupabaseTransportClientError.unknown(message: String(describing: error))
        }
    }

    func updateProduct(id: UUID, payload: SupabaseManualPushProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        let ownerUserID = try await query.requireOwner()
        let client = await query.client()
        do {
            let row: RemoteInventoryProductRow = try await client
                .from("inventory_products")
                .update(payload)
                .eq("id", value: id.uuidString)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .select(CatalogRemoteSupabaseAdapter.productColumns)
                .single()
                .execute()
                .value
            guard row.id == id, row.ownerUserID == ownerUserID else {
                throw SupabaseTransportClientError.schemaDrift(message: "Product update read-back mismatch.")
            }
            return row
        } catch let error as SupabaseTransportClientError {
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

    func fetchProductPricesForManualPushVerificationPage(
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
                .select(Self.productPriceColumns)
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

    private func mapProductPriceManualPushPostgrestError(_ error: PostgrestError) async -> Error {
        let code = error.code
        let message = error.message
        let normalized = [code, message, error.detail, error.hint]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if code == "23505"
            || normalized.contains("duplicate key")
            || normalized.contains("unique constraint") {
            return ProductPriceManualPushError.uniqueConflict(
                message: SupabaseTransportClientError.sanitizedDiagnosticDetail(message)
            )
        }

        if normalized.contains("permission denied")
            || normalized.contains("row-level security")
            || normalized.contains("rls")
            || normalized.contains("unauthorized")
            || normalized.contains("authenticated")
            || code == "42501" {
            return SupabaseTransportClientError.permissionDeniedOrRLS(statusCode: nil, code: code, message: message)
        }

        if code == "42P01" || code == "42703" || code == "PGRST204" {
            return SupabaseTransportClientError.schemaDrift(message: message)
        }

        return await remote.mapPostgrestError(error)
    }
}
