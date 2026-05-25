import Foundation
import Supabase

struct OptionsRemoteCountSupabaseAdapter: OptionsSyncRemoteCountFetching {
    let remote: SupabaseTransportClient

    private var query: SupabaseRemoteQueryExecutor {
        SupabaseRemoteQueryExecutor(transport: remote)
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
