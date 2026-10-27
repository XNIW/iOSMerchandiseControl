import Foundation
import Supabase

struct SupabaseRemoteQueryExecutor: Sendable {
    let transport: SupabaseTransportClient

    func client() async -> SupabaseClient {
        await transport.client()
    }

    @discardableResult
    func requireOwner() async throws -> UUID {
        try await transport.authenticatedUserID()
    }

    func fetchRows<Row: Decodable & Sendable>(
        table: String,
        columns: String,
        limit: Int
    ) async throws -> [Row] {
        let ownerUserID = try await requireOwner()
        let client = await client()
        let clampedLimit = max(1, min(limit, 1_000))

        do {
            var request = client
                .from(table)
                .select(columns)
                .eq("owner_user_id", value: ownerUserID.uuidString)
            if let selectedShopID = try selectedShopID(ownerUserID: ownerUserID) {
                request = request.eq("shop_id", value: selectedShopID.uuidString)
            }
            return try await request
                .order(SupabaseTransportClient.stablePageOrderColumn, ascending: true)
                .limit(clampedLimit)
                .execute()
                .value
        } catch let error as DecodingError {
            throw await transport.mapDecodingError(error)
        } catch let error as PostgrestError {
            throw await transport.mapPostgrestError(error)
        } catch let error as URLError {
            throw await transport.networkError(error)
        } catch {
            throw SupabaseTransportClientError.unknown(message: String(describing: error))
        }
    }

    func fetchRowsPage<Row: Decodable & Sendable>(
        table: String,
        columns: String,
        from: Int,
        to: Int
    ) async throws -> [Row] {
        let ownerUserID = try await requireOwner()
        let client = await client()
        let start = max(0, from)
        let end = max(start, min(to, start + 999))

        do {
            var request = client
                .from(table)
                .select(columns)
                .eq("owner_user_id", value: ownerUserID.uuidString)
            if let selectedShopID = try selectedShopID(ownerUserID: ownerUserID) {
                request = request.eq("shop_id", value: selectedShopID.uuidString)
            }
            return try await request
                .order(SupabaseTransportClient.stablePageOrderColumn, ascending: true)
                .range(from: start, to: end)
                .execute()
                .value
        } catch let error as DecodingError {
            throw await transport.mapDecodingError(error)
        } catch let error as PostgrestError {
            throw await transport.mapPostgrestError(error)
        } catch let error as URLError {
            throw await transport.networkError(error)
        } catch {
            throw SupabaseTransportClientError.unknown(message: String(describing: error))
        }
    }

    func fetchRowsByIDs<Row: Decodable & Sendable>(
        table: String,
        columns: String,
        ids: Set<UUID>,
        allowLegacyNullShopRows: Bool = false
    ) async throws -> [Row] {
        guard !ids.isEmpty else { return [] }
        let ownerUserID = try await requireOwner()
        let client = await client()
        do {
            var request = client
                .from(table)
                .select(columns)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .in("id", values: ids.sorted { $0.uuidString < $1.uuidString }.map(\.uuidString))
            if let selectedShopID = try selectedShopID(ownerUserID: ownerUserID) {
                request = allowLegacyNullShopRows
                    ? request.or("shop_id.eq.\(selectedShopID.uuidString),shop_id.is.null")
                    : request.eq("shop_id", value: selectedShopID.uuidString)
            }
            return try await request
                .execute()
                .value
        } catch let error as DecodingError {
            throw await transport.mapDecodingError(error)
        } catch let error as PostgrestError {
            throw await transport.mapPostgrestError(error)
        } catch let error as URLError {
            throw await transport.networkError(error)
        } catch {
            throw SupabaseTransportClientError.unknown(message: String(describing: error))
        }
    }

    func insertRows<Row: Decodable & Sendable>(
        _ payloads: some Encodable,
        table: String,
        columns: String
    ) async throws -> [Row] {
        let client = await client()
        do {
            return try await client
                .from(table)
                .insert(payloads)
                .select(columns)
                .execute()
                .value
        } catch let error as DecodingError {
            throw await transport.mapDecodingError(error)
        } catch let error as PostgrestError {
            throw await transport.mapPostgrestError(error)
        } catch let error as URLError {
            throw await transport.networkError(error)
        } catch {
            throw SupabaseTransportClientError.unknown(message: String(describing: error))
        }
    }

    func updateRow<Row: Decodable & Sendable>(
        _ payload: some Encodable,
        table: String,
        columns: String,
        id: UUID,
        preserveCatalogWriteRejection: Bool = false
    ) async throws -> Row {
        let ownerUserID = try await requireOwner()
        let client = await client()
        do {
            var request = try client
                .from(table)
                .update(payload)
                .eq("id", value: id.uuidString)
                .eq("owner_user_id", value: ownerUserID.uuidString)
            if let selectedShopID = try selectedShopID(ownerUserID: ownerUserID) {
                request = request.eq("shop_id", value: selectedShopID.uuidString)
            }
            return try await request
                .select(columns)
                .single()
                .execute()
                .value
        } catch let error as DecodingError {
            throw await transport.mapDecodingError(error)
        } catch let error as PostgrestError {
            if preserveCatalogWriteRejection,
               ["inventory_suppliers", "inventory_categories", "inventory_products"].contains(table),
               let rejection = SyncCatalogWriteRejectedWithoutCommit.classify(error.code) { throw rejection }
            throw await transport.mapPostgrestError(error)
        } catch let error as URLError {
            throw await transport.networkError(error)
        } catch {
            throw SupabaseTransportClientError.unknown(message: String(describing: error))
        }
    }

    /// One immutable conditional execution. A zero-row reply is deliberately not an ACK.
    func updateProductConditionally(
        _ payload: some Encodable, columns: String, id: UUID, ownerUserID: UUID, shopID: UUID,
        expectedVersion: SyncCatalogConditionalVersion,
        beforeDispatch: @Sendable () throws -> Void = {}
    ) async throws -> [RemoteInventoryProductRow] {
        try expectedVersion.validate()
        guard try await requireOwner() == ownerUserID else {
            throw SupabaseTransportClientError.permissionDeniedOrRLS(
                statusCode: nil, code: nil, message: "Owner mismatch.")
        }
        let client = await client()
        // Authentication/client acquisition can suspend across account or shop invalidation.
        // The adapter supplies its captured lease; generic wire fixtures have no automatic scope.
        try beforeDispatch()
        do {
            var request = try client.from("inventory_products").update(payload)
                .eq("id", value: id.uuidString)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .eq("shop_id", value: shopID.uuidString)
                .eq("updated_at", value: expectedVersion.expectedUpdatedAt)
            if let deletedAt = expectedVersion.expectedDeletedAt {
                request = request.eq("deleted_at", value: deletedAt)
            } else {
                request = request.is("deleted_at", value: nil)
            }
            let rows: [RemoteInventoryProductRow] = try await request.select(columns).execute().value
            guard rows.count <= 1, rows.allSatisfy({ row in
                row.id == id && row.ownerUserID == ownerUserID && row.shopID == shopID
                    && SyncCatalogConditionalVersion.isValidTimestamp(row.updatedAt)
                    && (row.deletedAt.map(SyncCatalogConditionalVersion.isValidTimestamp) ?? true)
                    && (row.deletedAt == nil) == (expectedVersion.expectedDeletedAt == nil)
            }) else {
                throw SupabaseTransportClientError.schemaDrift(message: "Unqualified conditional catalog response.")
            }
            return rows
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as SupabaseTransportClientError {
            throw error
        } catch let error as DecodingError {
            throw await transport.mapDecodingError(error)
        } catch let error as PostgrestError {
            if let rejection = SyncCatalogWriteRejectedWithoutCommit.classify(error.code) { throw rejection }
            throw await transport.mapPostgrestError(error)
        } catch let error as URLError {
            throw await transport.networkError(error)
        } catch {
            throw SupabaseTransportClientError.unknown(message: String(describing: error))
        }
    }

    func exactRowCount(table: String, ownerUserID: UUID?, activeOnly: Bool) async throws -> Int? {
        let resolvedOwner: UUID
        if let ownerUserID {
            resolvedOwner = ownerUserID
        } else {
            resolvedOwner = try await requireOwner()
        }
        let client = await client()
        do {
            var query = client
                .from(table)
                .select("*", head: true, count: .exact)
                .eq("owner_user_id", value: resolvedOwner.uuidString)
            if let selectedShopID = try selectedShopID(ownerUserID: resolvedOwner) {
                query = query.eq("shop_id", value: selectedShopID.uuidString)
            }
            if activeOnly {
                query = query.is("deleted_at", value: nil)
            }
            return try await query.execute().count
        } catch let error as DecodingError {
            throw await transport.mapDecodingError(error)
        } catch let error as PostgrestError {
            throw await transport.mapPostgrestError(error)
        } catch let error as URLError {
            throw await transport.networkError(error)
        } catch {
            throw SupabaseTransportClientError.unknown(message: String(describing: error))
        }
    }

    private func selectedShopID(ownerUserID: UUID) throws -> UUID? {
        if Task126OwnerStoreGate.currentAutomaticScope != nil {
            return try Task126OwnerStoreGate.requireCurrentAutomaticScope(
                ownerUserID: ownerUserID
            ).shopID
        }
        return ShopContextSelection.selectedShopID(ownerUserID: ownerUserID)
    }
}
