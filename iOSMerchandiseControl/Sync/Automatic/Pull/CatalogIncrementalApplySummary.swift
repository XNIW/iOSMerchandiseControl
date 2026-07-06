import Foundation

struct CatalogIncrementalApplySummary: Equatable, Sendable {
    var targetedSuppliersFetched: Int = 0
    var targetedCategoriesFetched: Int = 0
    var targetedProductsFetched: Int = 0
    var productsInserted: Int = 0
    var productsUpdated: Int = 0
    var productsTombstoned: Int = 0
    var suppliersCreated: Int = 0
    var suppliersUpdated: Int = 0
    var categoriesCreated: Int = 0
    var categoriesUpdated: Int = 0
    var suppliersMissingRemoteTombstoned: Int = 0
    var categoriesMissingRemoteTombstoned: Int = 0

    init() {}

    init(_ summary: SyncIncrementalPullSummary) {
        targetedSuppliersFetched = summary.targetedSuppliersFetched
        targetedCategoriesFetched = summary.targetedCategoriesFetched
        targetedProductsFetched = summary.targetedProductsFetched
        productsInserted = summary.productsInserted
        productsUpdated = summary.productsUpdated
        productsTombstoned = summary.productsTombstoned
        suppliersCreated = summary.suppliersCreated
        suppliersUpdated = summary.suppliersUpdated
        categoriesCreated = summary.categoriesCreated
        categoriesUpdated = summary.categoriesUpdated
        suppliersMissingRemoteTombstoned = summary.suppliersMissingRemoteTombstoned
        categoriesMissingRemoteTombstoned = summary.categoriesMissingRemoteTombstoned
    }
}

extension SyncIncrementalPullSummary {
    var catalogSummary: CatalogIncrementalApplySummary {
        CatalogIncrementalApplySummary(self)
    }
}
