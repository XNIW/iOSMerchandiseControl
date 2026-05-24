import Foundation

struct CatalogRemoteSupabaseAdapter: SyncAutomaticCatalogRemoteWriting {
    let remote: SupabaseInventoryService

    func createSuppliers(_ payloads: [SyncAutomaticSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow] {
        try await remote.createSuppliers(payloads)
    }

    func updateSupplier(id: UUID, payload: SyncAutomaticSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow {
        try await remote.updateSupplier(id: id, payload: payload)
    }

    func createCategories(_ payloads: [SyncAutomaticCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow] {
        try await remote.createCategories(payloads)
    }

    func updateCategory(id: UUID, payload: SyncAutomaticCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow {
        try await remote.updateCategory(id: id, payload: payload)
    }

    func createProducts(_ payloads: [SyncAutomaticProductCreatePayload]) async throws -> [RemoteInventoryProductRow] {
        try await remote.createProducts(payloads)
    }

    func updateProduct(id: UUID, payload: SyncAutomaticProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        try await remote.updateProduct(id: id, payload: payload)
    }
}
