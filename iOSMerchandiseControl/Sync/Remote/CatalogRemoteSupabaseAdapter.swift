import Foundation
import Supabase

struct CatalogRemoteSupabaseAdapter: SyncAutomaticCatalogRemoteWriting {
    let remote: SupabaseTransportClient

    private var query: SupabaseRemoteQueryExecutor {
        SupabaseRemoteQueryExecutor(transport: remote)
    }

    func createSuppliers(_ payloads: [SyncAutomaticSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow] {
        let ownerUserID = try await query.requireOwner()
        guard payloads.allSatisfy({ $0.ownerUserID == ownerUserID }) else {
            throw SupabaseTransportClientError.permissionDeniedOrRLS(statusCode: nil, code: nil, message: "Owner mismatch.")
        }
        return try await query.insertRows(
            payloads,
            table: "inventory_suppliers",
            columns: Self.supplierColumns
        )
    }

    func updateSupplier(id: UUID, payload: SyncAutomaticSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow {
        try await query.updateRow(payload, table: "inventory_suppliers", columns: Self.supplierColumns, id: id)
    }

    func createCategories(_ payloads: [SyncAutomaticCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow] {
        let ownerUserID = try await query.requireOwner()
        guard payloads.allSatisfy({ $0.ownerUserID == ownerUserID }) else {
            throw SupabaseTransportClientError.permissionDeniedOrRLS(statusCode: nil, code: nil, message: "Owner mismatch.")
        }
        return try await query.insertRows(
            payloads,
            table: "inventory_categories",
            columns: Self.categoryColumns
        )
    }

    func updateCategory(id: UUID, payload: SyncAutomaticCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow {
        try await query.updateRow(payload, table: "inventory_categories", columns: Self.categoryColumns, id: id)
    }

    func createProducts(_ payloads: [SyncAutomaticProductCreatePayload]) async throws -> [RemoteInventoryProductRow] {
        let ownerUserID = try await query.requireOwner()
        guard payloads.allSatisfy({ $0.ownerUserID == ownerUserID }) else {
            throw SupabaseTransportClientError.permissionDeniedOrRLS(statusCode: nil, code: nil, message: "Owner mismatch.")
        }
        return try await query.insertRows(
            payloads,
            table: "inventory_products",
            columns: SupabaseTransportClient.productColumns
        )
    }

    func updateProduct(id: UUID, payload: SyncAutomaticProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        try await query.updateRow(
            payload,
            table: "inventory_products",
            columns: SupabaseTransportClient.productColumns,
            id: id
        )
    }
}

extension CatalogRemoteSupabaseAdapter: SyncAutomaticCatalogIncrementalReading {
    func fetchCatalogByIDs(
        supplierIDs: Set<UUID>,
        categoryIDs: Set<UUID>,
        productIDs: Set<UUID>
    ) async throws -> (
        suppliers: [RemoteInventorySupplierRow],
        categories: [RemoteInventoryCategoryRow],
        products: [RemoteInventoryProductRow]
    ) {
        async let suppliers = query.fetchRowsByIDs(
            table: "inventory_suppliers",
            columns: Self.supplierColumns,
            ids: supplierIDs
        ) as [RemoteInventorySupplierRow]
        async let categories = query.fetchRowsByIDs(
            table: "inventory_categories",
            columns: Self.categoryColumns,
            ids: categoryIDs
        ) as [RemoteInventoryCategoryRow]
        async let products = query.fetchRowsByIDs(
            table: "inventory_products",
            columns: SupabaseTransportClient.productColumns,
            ids: productIDs
        ) as [RemoteInventoryProductRow]
        return try await (suppliers, categories, products)
    }
}

extension CatalogRemoteSupabaseAdapter {
    static let supplierColumns = "id,owner_user_id,name,updated_at,deleted_at"
    static let categoryColumns = "id,owner_user_id,name,updated_at,deleted_at"

    func fetchProducts(limit: Int = 100) async throws -> [RemoteInventoryProductRow] {
        try await query.fetchRows(
            table: "inventory_products",
            columns: SupabaseTransportClient.productColumns,
            limit: limit
        )
    }

    func fetchProductsPage(from: Int, to: Int) async throws -> [RemoteInventoryProductRow] {
        try await query.fetchRowsPage(
            table: "inventory_products",
            columns: SupabaseTransportClient.productColumns,
            from: from,
            to: to
        )
    }

    func fetchDeletedProductIDs(pageSize: Int = 1_000) async throws -> Set<UUID> {
        let limit = max(1, min(pageSize, 1_000))
        var offset = 0
        var deletedProductIDs = Set<UUID>()

        while true {
            try Task.checkCancellation()
            let page = try await fetchProductsPage(from: offset, to: offset + limit - 1)
            for product in page where SupabasePullPreviewNormalizer.semanticString(product.deletedAt) != nil {
                deletedProductIDs.insert(product.id)
            }
            guard page.count == limit else { break }
            offset += limit
        }

        return deletedProductIDs
    }

    func fetchSuppliers(limit: Int = 100) async throws -> [RemoteInventorySupplierRow] {
        try await query.fetchRows(table: "inventory_suppliers", columns: Self.supplierColumns, limit: limit)
    }

    func fetchSuppliersPage(from: Int, to: Int) async throws -> [RemoteInventorySupplierRow] {
        try await query.fetchRowsPage(
            table: "inventory_suppliers",
            columns: Self.supplierColumns,
            from: from,
            to: to
        )
    }

    func fetchCategories(limit: Int = 100) async throws -> [RemoteInventoryCategoryRow] {
        try await query.fetchRows(table: "inventory_categories", columns: Self.categoryColumns, limit: limit)
    }

    func fetchCategoriesPage(from: Int, to: Int) async throws -> [RemoteInventoryCategoryRow] {
        try await query.fetchRowsPage(
            table: "inventory_categories",
            columns: Self.categoryColumns,
            from: from,
            to: to
        )
    }
}
