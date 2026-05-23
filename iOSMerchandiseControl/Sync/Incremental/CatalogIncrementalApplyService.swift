import Foundation
import SwiftData

nonisolated struct CatalogIncrementalApplyResult {
    var targetedSuppliersFetched = 0
    var targetedCategoriesFetched = 0
    var targetedProductsFetched = 0
    var productsInserted = 0
    var productsUpdated = 0
    var productsTombstoned = 0
    var suppliersCreated = 0
    var categoriesCreated = 0
    var productsMissingRemoteTombstoned = 0
    var suppliersMissingRemoteTombstoned = 0
    var categoriesMissingRemoteTombstoned = 0
    var remoteActiveProductIDs = Set<UUID>()
    var catalogFetchMs = 0
    var catalogApplyMs = 0
}

nonisolated struct CatalogIncrementalApplyService {
    private let inventoryService: SupabaseInventoryService

    init(inventoryService: SupabaseInventoryService) {
        self.inventoryService = inventoryService
    }

    func apply(
        eventIDs: SyncEventEntityIDSet,
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        isAuthenticated: Bool
    ) async throws -> CatalogIncrementalApplyResult {
        let catalogFetchStarted = mcNowMillis()
        let firstFetch = try await inventoryService.fetchCatalogByIDs(
            supplierIDs: eventIDs.supplierIDs,
            categoryIDs: eventIDs.categoryIDs,
            productIDs: eventIDs.productIDs
        )
        let relatedSupplierIDs = Set(firstFetch.products.compactMap(\.supplierID))
            .subtracting(Set(firstFetch.suppliers.map(\.id)))
        let relatedCategoryIDs = Set(firstFetch.products.compactMap(\.categoryID))
            .subtracting(Set(firstFetch.categories.map(\.id)))
        let relatedFetch = try await inventoryService.fetchCatalogByIDs(
            supplierIDs: relatedSupplierIDs,
            categoryIDs: relatedCategoryIDs,
            productIDs: []
        )
        let catalogFetchMs = mcNowMillis() - catalogFetchStarted

        let suppliers = mergeRows(firstFetch.suppliers, relatedFetch.suppliers)
        let categories = mergeRows(firstFetch.categories, relatedFetch.categories)
        let products = firstFetch.products
        let missingTargetSupplierIDs = eventIDs.supplierIDs.subtracting(Set(suppliers.map(\.id)))
        let missingTargetCategoryIDs = eventIDs.categoryIDs.subtracting(Set(categories.map(\.id)))
        let missingTargetProductIDs = eventIDs.productIDs.subtracting(Set(products.map(\.id)))

        let catalogApplyStarted = mcNowMillis()
        let result = try await applyTargetedCatalogRows(
            suppliers: suppliers,
            categories: categories,
            products: products,
            ownerUserID: ownerUserID,
            modelContainer: modelContainer
        )
        let catalogApplyMs = mcNowMillis() - catalogApplyStarted
        let missingResult = try await tombstoneMissingRemoteCatalog(
            supplierIDs: missingTargetSupplierIDs,
            categoryIDs: missingTargetCategoryIDs,
            productIDs: missingTargetProductIDs,
            ownerUserID: ownerUserID,
            modelContainer: modelContainer
        )

        return CatalogIncrementalApplyResult(
            targetedSuppliersFetched: suppliers.count,
            targetedCategoriesFetched: categories.count,
            targetedProductsFetched: products.count,
            productsInserted: result.productsInserted,
            productsUpdated: result.productsUpdated,
            productsTombstoned: result.productsTombstoned,
            suppliersCreated: result.suppliersCreated,
            categoriesCreated: result.categoriesCreated,
            productsMissingRemoteTombstoned: missingResult.products,
            suppliersMissingRemoteTombstoned: missingResult.suppliers,
            categoriesMissingRemoteTombstoned: missingResult.categories,
            remoteActiveProductIDs: Set(products
                .filter { SupabasePullPreviewNormalizer.semanticString($0.deletedAt) == nil }
                .map(\.id)),
            catalogFetchMs: catalogFetchMs,
            catalogApplyMs: catalogApplyMs
        )
    }

    private func applyTargetedCatalogRows(
        suppliers: [RemoteInventorySupplierRow],
        categories: [RemoteInventoryCategoryRow],
        products: [RemoteInventoryProductRow],
        ownerUserID: UUID,
        modelContainer: ModelContainer
    ) async throws -> TargetedCatalogApplyResult {
        try await Task.detached(priority: .userInitiated) {
            let context = ModelContext(modelContainer)
            let protected = try pendingRemoteIDs(context: context, ownerUserID: ownerUserID)
            var result = TargetedCatalogApplyResult()
            var supplierCache: [UUID: Supplier] = [:]
            var categoryCache: [UUID: ProductCategory] = [:]

            for row in suppliers where !protected.suppliers.contains(row.id) {
                let applied = try applyTargetedSupplier(row, context: context)
                if let supplier = applied.supplier {
                    supplierCache[row.id] = supplier
                }
                result.suppliersCreated += applied.created ? 1 : 0
            }
            for row in categories where !protected.categories.contains(row.id) {
                let applied = try applyTargetedCategory(row, context: context)
                if let category = applied.category {
                    categoryCache[row.id] = category
                }
                result.categoriesCreated += applied.created ? 1 : 0
            }

            for row in products where !protected.products.contains(row.id) {
                let supplier = try row.supplierID.flatMap { remoteID -> Supplier? in
                    if let cached = supplierCache[remoteID] { return cached }
                    if let existing = try fetchSupplier(remoteID: remoteID, context: context) {
                        supplierCache[remoteID] = existing
                        return existing
                    }
                    return nil
                }
                let category = try row.categoryID.flatMap { remoteID -> ProductCategory? in
                    if let cached = categoryCache[remoteID] { return cached }
                    if let existing = try fetchCategory(remoteID: remoteID, context: context) {
                        categoryCache[remoteID] = existing
                        return existing
                    }
                    return nil
                }
                let applied = try applyTargetedProduct(
                    row,
                    supplier: supplier,
                    category: category,
                    context: context
                )
                result.productsInserted += applied.inserted ? 1 : 0
                result.productsUpdated += applied.updated ? 1 : 0
                result.productsTombstoned += applied.tombstoned ? 1 : 0
            }

            if result.totalMutations > 0 {
                try context.save()
            }
            return result
        }.value
    }

    private func tombstoneMissingRemoteCatalog(
        supplierIDs: Set<UUID>,
        categoryIDs: Set<UUID>,
        productIDs: Set<UUID>,
        ownerUserID: UUID,
        modelContainer: ModelContainer
    ) async throws -> (suppliers: Int, categories: Int, products: Int) {
        guard !supplierIDs.isEmpty || !categoryIDs.isEmpty || !productIDs.isEmpty else {
            return (0, 0, 0)
        }
        return try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            let protected = try pendingRemoteIDs(context: context, ownerUserID: ownerUserID)
            let now = Date()
            var suppliers = 0
            var categories = 0
            var products = 0

            for remoteID in supplierIDs where !protected.suppliers.contains(remoteID) {
                guard let supplier = try fetchSupplier(remoteID: remoteID, context: context),
                      supplier.remoteDeletedAt == nil else { continue }
                supplier.remoteDeletedAt = now
                try detachSupplier(remoteID: remoteID, context: context)
                suppliers += 1
            }
            for remoteID in categoryIDs where !protected.categories.contains(remoteID) {
                guard let category = try fetchCategory(remoteID: remoteID, context: context),
                      category.remoteDeletedAt == nil else { continue }
                category.remoteDeletedAt = now
                try detachCategory(remoteID: remoteID, context: context)
                categories += 1
            }
            for remoteID in productIDs where !protected.products.contains(remoteID) {
                guard let product = try fetchProduct(remoteID: remoteID, context: context),
                      product.remoteDeletedAt == nil else { continue }
                product.remoteDeletedAt = now
                product.supplier = nil
                product.category = nil
                products += 1
            }
            if suppliers + categories + products > 0 {
                try context.save()
            }
            return (suppliers, categories, products)
        }.value
    }

    private func mergeRows<Row: Identifiable>(_ lhs: [Row], _ rhs: [Row]) -> [Row] where Row.ID == UUID {
        Array(Dictionary(uniqueKeysWithValues: (lhs + rhs).map { ($0.id, $0) }).values)
    }
}
