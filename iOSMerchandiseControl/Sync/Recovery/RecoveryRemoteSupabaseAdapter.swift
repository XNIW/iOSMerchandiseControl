import Foundation

protocol RecoveryCatalogRemoteFetching: SupabaseInventoryLookupByIDFetching {
    func fetchProductsPage(from: Int, to: Int) async throws -> [RemoteInventoryProductRow]
    func fetchSuppliersPage(from: Int, to: Int) async throws -> [RemoteInventorySupplierRow]
    func fetchCategoriesPage(from: Int, to: Int) async throws -> [RemoteInventoryCategoryRow]
}

extension CatalogRemoteSupabaseAdapter: RecoveryCatalogRemoteFetching {}

protocol RecoveryProductPriceRemoteFetching: Sendable {
    func fetchProductPricesPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow]
}

extension ProductPricePreviewRemoteSupabaseAdapter: RecoveryProductPriceRemoteFetching {}

nonisolated enum Task126AutomaticRemoteRowValidator {
    static func validate<Row: Sendable>(
        _ rows: [Row],
        ownerUserID: KeyPath<Row, UUID>,
        shopID: KeyPath<Row, UUID?>
    ) throws -> [Row] {
        guard let scope = Task126OwnerStoreGate.currentAutomaticScope else {
            return rows
        }

        try Task126OwnerStoreGate.revalidateCurrentAutomaticScopeLeaseIfPresent()
        for row in rows {
            try Task126OwnerStoreGate.validateRemoteIdentity(
                ownerUserID: row[keyPath: ownerUserID],
                shopID: row[keyPath: shopID],
                scope: scope
            )
        }
        return rows
    }
}

struct RecoveryRemoteSupabaseAdapter: SupabaseInventoryFetching {
    let catalog: any RecoveryCatalogRemoteFetching
    let productPrice: any RecoveryProductPriceRemoteFetching

    init(remote: SupabaseTransportClient) {
        self.catalog = CatalogRemoteSupabaseAdapter(remote: remote)
        self.productPrice = ProductPricePreviewRemoteSupabaseAdapter(remote: remote)
    }

    init(
        catalog: any RecoveryCatalogRemoteFetching,
        productPrice: any RecoveryProductPriceRemoteFetching
    ) {
        self.catalog = catalog
        self.productPrice = productPrice
    }

    func fetchProductsPage(from: Int, to: Int) async throws -> [RemoteInventoryProductRow] {
        let rows = try await catalog.fetchProductsPage(from: from, to: to)
        return try Task126AutomaticRemoteRowValidator.validate(
            rows,
            ownerUserID: \.ownerUserID,
            shopID: \.shopID
        )
    }

    func fetchSuppliersPage(from: Int, to: Int) async throws -> [RemoteInventorySupplierRow] {
        let rows = try await catalog.fetchSuppliersPage(from: from, to: to)
        return try Task126AutomaticRemoteRowValidator.validate(
            rows,
            ownerUserID: \.ownerUserID,
            shopID: \.shopID
        )
    }

    func fetchCategoriesPage(from: Int, to: Int) async throws -> [RemoteInventoryCategoryRow] {
        let rows = try await catalog.fetchCategoriesPage(from: from, to: to)
        return try Task126AutomaticRemoteRowValidator.validate(
            rows,
            ownerUserID: \.ownerUserID,
            shopID: \.shopID
        )
    }

    func fetchProductPricesPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        let rows = try await productPrice.fetchProductPricesPage(from: from, to: to)
        return try Task126AutomaticRemoteRowValidator.validate(
            rows,
            ownerUserID: \.ownerUserID,
            shopID: \.shopID
        )
    }
}

extension RecoveryRemoteSupabaseAdapter: SupabaseInventoryLookupByIDFetching {
    func fetchSuppliersByIDs(_ ids: Set<UUID>) async throws -> [RemoteInventorySupplierRow] {
        let rows = try await catalog.fetchSuppliersByIDs(ids)
        return try Task126AutomaticRemoteRowValidator.validate(
            rows,
            ownerUserID: \.ownerUserID,
            shopID: \.shopID
        )
    }

    func fetchCategoriesByIDs(_ ids: Set<UUID>) async throws -> [RemoteInventoryCategoryRow] {
        let rows = try await catalog.fetchCategoriesByIDs(ids)
        return try Task126AutomaticRemoteRowValidator.validate(
            rows,
            ownerUserID: \.ownerUserID,
            shopID: \.shopID
        )
    }
}
