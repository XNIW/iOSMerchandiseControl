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
            if let selectedShopID = selectedShopID(ownerUserID: ownerUserID) {
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
            if let selectedShopID = selectedShopID(ownerUserID: ownerUserID) {
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
        ids: Set<UUID>
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
            if let selectedShopID = selectedShopID(ownerUserID: ownerUserID) {
                request = request.eq("shop_id", value: selectedShopID.uuidString)
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
        id: UUID
    ) async throws -> Row {
        let ownerUserID = try await requireOwner()
        let client = await client()
        do {
            return try await client
                .from(table)
                .update(payload)
                .eq("id", value: id.uuidString)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .select(columns)
                .single()
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
            if let selectedShopID = selectedShopID(ownerUserID: resolvedOwner) {
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

    private func selectedShopID(ownerUserID: UUID) -> UUID? {
        ShopContextSelection.selectedShopID(ownerUserID: ownerUserID)
    }
}
