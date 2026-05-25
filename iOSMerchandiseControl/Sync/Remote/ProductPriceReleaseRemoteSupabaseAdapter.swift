import Foundation

struct ProductPriceReleaseRemoteSupabaseAdapter:
    SupabaseProductPriceKeysetFetching,
    SupabaseProductPriceDeletedProductFetching,
    SupabaseProductPriceManualPushRemoteAccessing,
    SupabaseProductPricePushDryRunRemoteFetching {
    private let preview: ProductPricePreviewRemoteSupabaseAdapter
    private let manualPush: ProductPriceManualPushRemoteSupabaseAdapter

    init(remote: SupabaseTransportClient) {
        self.preview = ProductPricePreviewRemoteSupabaseAdapter(remote: remote)
        self.manualPush = ProductPriceManualPushRemoteSupabaseAdapter(remote: remote)
    }

    func fetchProductPricesPreviewPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        try await preview.fetchProductPricesPreviewPage(from: from, to: to)
    }

    func fetchProductPricesPreviewPage(afterID: UUID?, limit: Int) async throws -> [RemoteInventoryProductPriceRow] {
        try await preview.fetchProductPricesPreviewPage(afterID: afterID, limit: limit)
    }

    func fetchProductPriceCount() async throws -> Int? {
        try await preview.fetchProductPriceCount()
    }

    func fetchDeletedProductIDs(pageSize: Int) async throws -> Set<UUID> {
        try await preview.fetchDeletedProductIDs(pageSize: pageSize)
    }

    func fetchProductPricesForPushDryRunDedupePage(
        ownerUserID: UUID,
        productIDs: [UUID],
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow] {
        try await preview.fetchProductPricesForPushDryRunDedupePage(
            ownerUserID: ownerUserID,
            productIDs: productIDs,
            from: from,
            to: to
        )
    }

    func insertProductPriceManualPushPayloads(_ payloads: [ProductPriceManualPushPayload]) async throws -> [RemoteInventoryProductPriceRow] {
        try await manualPush.insertProductPriceManualPushPayloads(payloads)
    }

    func fetchProductPricesForManualPushVerificationPage(
        ownerUserID: UUID,
        productIDs: [UUID],
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow] {
        try await manualPush.fetchProductPricesForManualPushVerificationPage(
            ownerUserID: ownerUserID,
            productIDs: productIDs,
            from: from,
            to: to
        )
    }

    func updateProduct(id: UUID, payload: SupabaseManualPushProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        try await manualPush.updateProduct(id: id, payload: payload)
    }
}
