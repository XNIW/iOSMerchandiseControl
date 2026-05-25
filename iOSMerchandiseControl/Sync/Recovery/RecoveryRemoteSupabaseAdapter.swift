import Foundation

struct RecoveryRemoteSupabaseAdapter: SupabaseInventoryFetching {
    let catalog: CatalogRemoteSupabaseAdapter
    let productPrice: ProductPriceRemoteSupabaseAdapter

    init(remote: SupabaseTransportClient) {
        self.catalog = CatalogRemoteSupabaseAdapter(remote: remote)
        self.productPrice = ProductPriceRemoteSupabaseAdapter(remote: remote)
    }

    func fetchProductsPage(from: Int, to: Int) async throws -> [RemoteInventoryProductRow] {
        try await catalog.fetchProductsPage(from: from, to: to)
    }

    func fetchSuppliersPage(from: Int, to: Int) async throws -> [RemoteInventorySupplierRow] {
        try await catalog.fetchSuppliersPage(from: from, to: to)
    }

    func fetchCategoriesPage(from: Int, to: Int) async throws -> [RemoteInventoryCategoryRow] {
        try await catalog.fetchCategoriesPage(from: from, to: to)
    }

    func fetchProductPricesPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        try await productPrice.fetchProductPricesPage(from: from, to: to)
    }
}
