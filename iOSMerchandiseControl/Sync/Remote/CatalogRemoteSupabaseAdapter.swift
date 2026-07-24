import Foundation
import Supabase

struct CatalogRemoteSupabaseAdapter: SyncAutomaticCatalogRemoteWriting {
    let remote: SupabaseTransportClient

    private var query: SupabaseRemoteQueryExecutor {
        SupabaseRemoteQueryExecutor(transport: remote)
    }

    func createSuppliers(_ payloads: [SyncAutomaticSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow] {
        let scope = try Task126OwnerStoreGate.requireCurrentAutomaticScope()
        let ownerUserID = try await query.requireOwner()
        guard ownerUserID == scope.ownerUserID,
              payloads.allSatisfy({ $0.ownerUserID == ownerUserID && $0.shopID == scope.shopID }) else {
            throw SupabaseTransportClientError.permissionDeniedOrRLS(statusCode: nil, code: nil, message: "Owner mismatch.")
        }
        let client = await query.client()
        do {
            return try await client
                .from("inventory_suppliers")
                .upsert(payloads, onConflict: "id")
                .select(Self.supplierColumns)
                .execute()
                .value
        } catch {
            throw await mappedCreateError(error)
        }
    }

    func updateSupplier(id: UUID, payload: SyncAutomaticSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow {
        _ = try Task126OwnerStoreGate.requireCurrentAutomaticScope()
        let row: RemoteInventorySupplierRow = try await query.updateRow(
            payload,
            table: "inventory_suppliers",
            columns: Self.supplierColumns,
            id: id
        )
        return row
    }

    func createCategories(_ payloads: [SyncAutomaticCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow] {
        let scope = try Task126OwnerStoreGate.requireCurrentAutomaticScope()
        let ownerUserID = try await query.requireOwner()
        guard ownerUserID == scope.ownerUserID,
              payloads.allSatisfy({ $0.ownerUserID == ownerUserID && $0.shopID == scope.shopID }) else {
            throw SupabaseTransportClientError.permissionDeniedOrRLS(statusCode: nil, code: nil, message: "Owner mismatch.")
        }
        let client = await query.client()
        do {
            return try await client
                .from("inventory_categories")
                .upsert(payloads, onConflict: "id")
                .select(Self.categoryColumns)
                .execute()
                .value
        } catch {
            throw await mappedCreateError(error)
        }
    }

    func updateCategory(id: UUID, payload: SyncAutomaticCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow {
        _ = try Task126OwnerStoreGate.requireCurrentAutomaticScope()
        let row: RemoteInventoryCategoryRow = try await query.updateRow(
            payload,
            table: "inventory_categories",
            columns: Self.categoryColumns,
            id: id
        )
        return row
    }

    func createProducts(_ payloads: [SyncAutomaticProductCreatePayload]) async throws -> [RemoteInventoryProductRow] {
        let scope = try Task126OwnerStoreGate.requireCurrentAutomaticScope()
        let ownerUserID = try await query.requireOwner()
        guard ownerUserID == scope.ownerUserID,
              payloads.allSatisfy({ $0.ownerUserID == ownerUserID && $0.shopID == scope.shopID }) else {
            throw SupabaseTransportClientError.permissionDeniedOrRLS(statusCode: nil, code: nil, message: "Owner mismatch.")
        }
        let client = await query.client()
        do {
            return try await client
                .from("inventory_products")
                .upsert(payloads, onConflict: "id")
                .select(Self.productColumns)
                .execute()
                .value
        } catch {
            throw await mappedCreateError(error)
        }
    }

    func updateProduct(id: UUID, payload: SyncAutomaticProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        _ = try Task126OwnerStoreGate.requireCurrentAutomaticScope()
        let row: RemoteInventoryProductRow = try await query.updateRow(
            payload,
            table: "inventory_products",
            columns: Self.productColumns,
            id: id
        )
        return row
    }

    private func mappedCreateError(_ error: Error) async -> Error {
        if let error = error as? DecodingError {
            return await remote.mapDecodingError(error)
        }
        if let error = error as? PostgrestError {
            return await remote.mapPostgrestError(error)
        }
        if let error = error as? URLError {
            return await remote.networkError(error)
        }
        return SupabaseTransportClientError.unknown(message: String(describing: error))
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
        _ = try Task126OwnerStoreGate.requireCurrentAutomaticScope()
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
            columns: Self.productColumns,
            ids: productIDs
        ) as [RemoteInventoryProductRow]
        return try await (suppliers, categories, products)
    }
}

extension CatalogRemoteSupabaseAdapter: SupabaseInventoryLookupByIDFetching {
    func fetchSuppliersByIDs(_ ids: Set<UUID>) async throws -> [RemoteInventorySupplierRow] {
        try await query.fetchRowsByIDs(
            table: "inventory_suppliers",
            columns: Self.supplierColumns,
            ids: ids,
            allowLegacyNullShopRows: true
        )
    }

    func fetchCategoriesByIDs(_ ids: Set<UUID>) async throws -> [RemoteInventoryCategoryRow] {
        try await query.fetchRowsByIDs(
            table: "inventory_categories",
            columns: Self.categoryColumns,
            ids: ids,
            allowLegacyNullShopRows: true
        )
    }
}

extension CatalogRemoteSupabaseAdapter {
    static let supplierColumns = "id,owner_user_id,shop_id,name,updated_at,deleted_at"
    static let categoryColumns = "id,owner_user_id,shop_id,name,updated_at,deleted_at"
    static let productColumns = "id,owner_user_id,shop_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at,primary_image_version_id,primary_image_updated_at"

    func fetchProducts(limit: Int = 100) async throws -> [RemoteInventoryProductRow] {
        try await query.fetchRows(
            table: "inventory_products",
            columns: Self.productColumns,
            limit: limit
        )
    }

    func fetchProductsPage(from: Int, to: Int) async throws -> [RemoteInventoryProductRow] {
        let rows: [RemoteInventoryProductRow] = try await query.fetchRowsPage(
            table: "inventory_products",
            columns: Self.productColumns,
            from: from,
            to: to
        )
        return try Task126AutomaticRemoteRowValidator.validate(
            rows,
            ownerUserID: \.ownerUserID,
            shopID: \.shopID
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
