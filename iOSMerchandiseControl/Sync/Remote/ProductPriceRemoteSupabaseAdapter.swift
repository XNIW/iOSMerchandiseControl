import Foundation
import Supabase

struct ProductPriceRemoteSupabaseAdapter: SyncAutomaticProductPriceRemoteWriting, SyncAutomaticProductPriceIncrementalReading {
    let remote: SupabaseTransportClient

    private var query: SupabaseRemoteQueryExecutor {
        SupabaseRemoteQueryExecutor(transport: remote)
    }

    static let productPriceColumns = "id,owner_user_id,product_id,type,price,effective_at,source,note,created_at"

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
}
