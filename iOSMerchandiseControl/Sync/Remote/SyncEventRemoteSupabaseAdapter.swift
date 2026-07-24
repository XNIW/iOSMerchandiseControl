import Foundation
import Supabase

struct SyncEventRemoteSupabaseAdapter: SyncAutomaticIncrementalRemote, ShopScopedIncrementalRPCAuthorizing, ShopScopedIncrementalFencePersisting {
    let remote: SupabaseTransportClient
    private let scopedRPC: ShopScopedIncrementalRPCClient

    init(
        remote: SupabaseTransportClient,
        defaults: UserDefaults = .standard
    ) {
        self.remote = remote
        self.scopedRPC = ShopScopedIncrementalRPCClient(remote: remote, defaults: defaults)
    }

    var usesServerAuthorizedShopScope: Bool { true }

    func advanceDurableFence(
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        from watermark: Int64,
        through newWatermark: Int64
    ) async throws {
        try await scopedRPC.advanceDurableFence(
            ownerUserID: ownerUserID,
            scope: scope,
            from: watermark,
            through: newWatermark
        )
    }

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
        let scope = try Task126OwnerStoreGate.requireCurrentAutomaticScope(ownerUserID: ownerUserID)
        return try await scopedRPC.events(
            ownerUserID: ownerUserID,
            scope: scope,
            afterID: afterID,
            limit: min(limit, SupabaseSyncEventIncrementalLimits.maximumLimit)
        )
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
        let scope = try Task126OwnerStoreGate.requireCurrentAutomaticScope()
        async let suppliers = scopedRows(
            RemoteInventorySupplierRow.self,
            domain: .suppliers,
            ids: supplierIDs,
            id: \.id,
            ownerUserID: scope.ownerUserID,
            scope: scope
        )
        async let categories = scopedRows(
            RemoteInventoryCategoryRow.self,
            domain: .categories,
            ids: categoryIDs,
            id: \.id,
            ownerUserID: scope.ownerUserID,
            scope: scope
        )
        async let products = scopedRows(
            RemoteInventoryProductRow.self,
            domain: .products,
            ids: productIDs,
            id: \.id,
            ownerUserID: scope.ownerUserID,
            scope: scope
        )
        return try await (suppliers, categories, products)
    }

    func fetchProductPricesByIDs(
        ownerUserID: UUID,
        priceIDs: Set<UUID>
    ) async throws -> [RemoteInventoryProductPriceRow] {
        let scope = try Task126OwnerStoreGate.requireCurrentAutomaticScope(ownerUserID: ownerUserID)
        return try await scopedRows(
            RemoteInventoryProductPriceRow.self,
            domain: .prices,
            ids: priceIDs,
            id: \.id,
            ownerUserID: ownerUserID,
            scope: scope
        )
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
        let scope = try Task126OwnerStoreGate.requireCurrentAutomaticScope(ownerUserID: ownerUserID)
        return try await scopedRows(
            RemoteSharedSheetSessionRow.self,
            domain: .history,
            ids: sessionIDs,
            id: \.remoteID,
            ownerUserID: ownerUserID,
            scope: scope
        )
    }

    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot {
        try await OptionsRemoteCountSupabaseAdapter(remote: remote).fetchReconciliationRemoteCounts()
    }

    private func scopedRows<Row: ShopSyncAuthorizedRow>(
        _ rowType: Row.Type,
        domain: ShopSyncRecoveryDomain,
        ids: Set<UUID>,
        id: KeyPath<Row, UUID>,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) async throws -> [Row] {
        guard !ids.isEmpty else { return [] }
        let limit = ShopSyncRecoveryLimits.maximumTargetedRows(for: domain)
        var rows: [Row] = []
        for chunk in ids.sorted(by: { $0.uuidString < $1.uuidString }).chunked(into: limit) {
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope)
            rows += try await scopedRPC.rows(
                rowType,
                domain: domain,
                ids: Set(chunk),
                id: id,
                ownerUserID: ownerUserID,
                scope: scope
            )
        }
        guard Set(rows.map { $0[keyPath: id] }).count == rows.count else {
            throw ShopSyncRecoveryContractError.nonMonotonicOrDuplicateID
        }
        return rows
    }
}

private extension Array {
    func chunked(into maximumCount: Int) -> [[Element]] {
        guard maximumCount > 0 else { return [] }
        return stride(from: 0, to: count, by: maximumCount).map {
            Array(self[$0..<Swift.min($0 + maximumCount, count)])
        }
    }
}
