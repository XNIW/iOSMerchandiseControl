import Foundation
import Supabase

struct OptionsRemoteCountSupabaseAdapter: OptionsSyncRemoteCountFetching {
    let remote: SupabaseTransportClient

    private var query: SupabaseRemoteQueryExecutor {
        SupabaseRemoteQueryExecutor(transport: remote)
    }

    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot {
        let ownerUserID = try await query.requireOwner()
        if Task126OwnerStoreGate.currentAutomaticScope != nil {
            _ = try Task126OwnerStoreGate.requireCurrentAutomaticScope(ownerUserID: ownerUserID)
        }
        async let products = query.exactRowCount(table: "inventory_products", ownerUserID: ownerUserID, activeOnly: true)
        async let suppliers = query.exactRowCount(table: "inventory_suppliers", ownerUserID: ownerUserID, activeOnly: true)
        async let categories = query.exactRowCount(table: "inventory_categories", ownerUserID: ownerUserID, activeOnly: true)
        async let prices = fetchActiveProductPriceCount(ownerUserID: ownerUserID)
        async let history = fetchActiveUserVisibleHistorySessionCount(ownerUserID: ownerUserID)
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
        let selectedShopID = try selectedShopID(ownerUserID: ownerUserID)
        do {
            var request = client
                .from("inventory_product_prices")
                .select("id,inventory_products!inner(id)", head: true, count: .exact)
                .eq("owner_user_id", value: ownerUserID.uuidString)
                .is("inventory_products.deleted_at", value: nil)
            if let selectedShopID {
                request = request.eq("shop_id", value: selectedShopID.uuidString)
            }
            return try await request.execute().count
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

    private func fetchActiveUserVisibleHistorySessionCount(ownerUserID: UUID) async throws -> Int? {
        let client = await query.client()
        let pageSize = 500
        let selectedShopID = try selectedShopID(ownerUserID: ownerUserID)
        var start = 0
        var count = 0

        while true {
            let end = start + pageSize - 1
            do {
                var request = client
                    .from("shared_sheet_sessions")
                    .select("remote_id,display_name,deleted_at")
                    .eq("owner_user_id", value: ownerUserID.uuidString)
                    .is("deleted_at", value: nil)
                if let selectedShopID {
                    request = request.eq("shop_id", value: selectedShopID.uuidString)
                }
                let rows: [RemoteHistorySessionCountRow] = try await request
                    .order("remote_id", ascending: true)
                    .range(from: start, to: end)
                    .execute()
                    .value
                count += rows.filter {
                    LocalHistorySessionCounting.isUserVisibleSession(
                        id: $0.remoteID.uuidString.lowercased(),
                        title: $0.displayName,
                        remoteDeletedAt: nil
                    )
                }.count
                guard rows.count == pageSize else { return count }
                start += pageSize
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

    private func selectedShopID(ownerUserID: UUID) throws -> UUID? {
        if Task126OwnerStoreGate.currentAutomaticScope != nil {
            return try Task126OwnerStoreGate.requireCurrentAutomaticScope(
                ownerUserID: ownerUserID
            ).shopID
        }
        return ShopContextSelection.selectedShopID(ownerUserID: ownerUserID)
    }
}

private struct RemoteHistorySessionCountRow: Decodable {
    let remoteID: UUID
    let displayName: String
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case remoteID = "remote_id"
        case displayName = "display_name"
        case deletedAt = "deleted_at"
    }
}
