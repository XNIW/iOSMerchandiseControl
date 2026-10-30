import Foundation
import Supabase


/// Only the incremental continuation supplies this server-qualified scope.
/// The ordinary Options owner-scoped read keeps its existing contract.
nonisolated protocol ShopScopedReconciliationRemoteCountFetching: Sendable {
    func fetchReconciliationRemoteCounts(
        scope: Task126VerifiedOwnerStoreScope, recoveryScope: ShopSyncRecoveryScope,
        defaults: UserDefaults
    ) async throws -> SyncInventoryCountSnapshot
}

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


    func fetchReconciliationRemoteCounts(
        scope: Task126VerifiedOwnerStoreScope, recoveryScope: ShopSyncRecoveryScope,
        defaults: UserDefaults
    ) async throws -> SyncInventoryCountSnapshot {
        let ownerUserID = try await query.requireOwner()
        guard ownerUserID == scope.ownerUserID,
              try Task126OwnerStoreGate.requireCurrentAutomaticScope(
                ownerUserID: ownerUserID, defaults: defaults) == scope else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
        try recoveryScope.validate(expectedShopID: scope.shopID,
            expectedDeviceIdentifier: scope.deviceInstallID, expectedOwnerUserID: ownerUserID)
        do {
            let client = await query.client()
            let mappedOwnerID: UUID?
            if let legacyOwnerKey = recoveryScope.legacyOwnerKey {
                // This metadata read is protected by the existing member RLS.
                // Its UUID is accepted only when bound to the qualified C.scope.
                let mappings: [ReconciliationInventorySourceRow] = try await client
                    .from("shop_inventory_sources")
                    .select("owner_user_id,created_at,verified_at")
                    .eq("shop_id", value: scope.shopID.uuidString)
                    .eq("mapping_state", value: "mapped")
                    .not("owner_user_id", operator: .is, value: "null")
                    .not("verified_at", operator: .is, value: "null")
                    .is("disabled_at", value: nil)
                    .order("created_at", ascending: false).limit(1).execute().value
                guard let mapping = mappings.first, let mapped = mapping.ownerUserID,
                      let verifiedAt = mapping.verifiedAt,
                      !["infinity", "-infinity"].contains(mapping.createdAt.lowercased()),
                      !["infinity", "-infinity"].contains(verifiedAt.lowercased()),
                      ShopSyncRecoveryCanonical.sha256(mapped.uuidString.lowercased()) == legacyOwnerKey else {
                    throw Task126OwnerStoreGateError.scopeChanged
                }
                mappedOwnerID = mapped
            } else {
                mappedOwnerID = nil
            }
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
            let catalogPredicate = try Self.reconciliationPredicate(kind: recoveryScope.kind,
                shopID: scope.shopID, mappedOwnerID: mappedOwnerID)
            let historyPredicate = try Self.reconciliationPredicate(kind: recoveryScope.historyKind,
                shopID: scope.shopID, mappedOwnerID: mappedOwnerID)
            async let products = scopedActiveCount(table: "inventory_products", predicate: catalogPredicate)
            async let suppliers = scopedActiveCount(table: "inventory_suppliers", predicate: catalogPredicate)
            async let categories = scopedActiveCount(table: "inventory_categories", predicate: catalogPredicate)
            async let prices = client.from("inventory_product_prices")
                .select("id,inventory_products!inner(id)", head: true, count: .exact)
                .or(catalogPredicate).is("inventory_products.deleted_at", value: nil).execute().count
            async let history = scopedUserVisibleHistoryCount(predicate: historyPredicate)
            let values = try await (products, suppliers, categories, prices, history)
            let counts = SyncInventoryCountSnapshot(products: values.0, suppliers: values.1,
                categories: values.2, productPrices: values.3 ?? 0, historySessions: values.4)
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
            return counts
        } catch let error as DecodingError {
            throw await remote.mapDecodingError(error)
        } catch let error as PostgrestError {
            throw await remote.mapPostgrestError(error)
        } catch let error as URLError {
            throw await remote.networkError(error)
        } catch { throw error }
    }

    private static func reconciliationPredicate(kind: String, shopID: UUID, mappedOwnerID: UUID?) throws -> String {
        let shop = "shop_id.eq.\(shopID.uuidString)"
        switch kind {
        case "shop_scoped": return shop
        case "legacy_owner_bridge", "authorized_shop_plus_legacy":
            guard let mappedOwnerID else { throw ShopSyncRecoveryContractError.invalidCheckpoint }
            let legacy = "and(shop_id.is.null,owner_user_id.eq.\(mappedOwnerID.uuidString))"
            return kind == "legacy_owner_bridge" ? legacy : "\(shop),\(legacy)"
        default: throw ShopSyncRecoveryContractError.invalidCheckpoint
        }
    }

    private func scopedActiveCount(table: String, predicate: String) async throws -> Int {
        let client = await query.client()
        return try await client.from(table).select("id", head: true, count: .exact)
            .or(predicate).is("deleted_at", value: nil).execute().count ?? 0
    }

    private func scopedUserVisibleHistoryCount(predicate: String) async throws -> Int {
        let client = await query.client()
        let pageSize = 500
        var start = 0
        var count = 0
        while true {
            let rows: [RemoteHistorySessionCountRow] = try await client.from("shared_sheet_sessions")
                .select("remote_id,display_name,deleted_at")
                .or(predicate).is("deleted_at", value: nil)
                .order("remote_id", ascending: true).range(from: start, to: start + pageSize - 1)
                .execute().value
            count += rows.filter {
                LocalHistorySessionCounting.isUserVisibleSession(id: $0.remoteID.uuidString.lowercased(),
                    title: $0.displayName, remoteDeletedAt: nil)
            }.count
            guard rows.count == pageSize else { return count }
            start += pageSize
        }
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

private struct ReconciliationInventorySourceRow: Decodable {
    let ownerUserID: UUID?
    let createdAt: String
    let verifiedAt: String?
    enum CodingKeys: String, CodingKey {
        case ownerUserID = "owner_user_id"
        case createdAt = "created_at"
        case verifiedAt = "verified_at"
    }
}
