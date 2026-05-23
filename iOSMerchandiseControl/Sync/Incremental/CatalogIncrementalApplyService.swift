import Foundation

struct CatalogIncrementalApplyService {
    struct Summary: Equatable, Sendable {
        var targetedSuppliersFetched: Int = 0
        var targetedCategoriesFetched: Int = 0
        var targetedProductsFetched: Int = 0
        var productsInserted: Int = 0
        var productsUpdated: Int = 0
        var productsTombstoned: Int = 0
        var suppliersCreated: Int = 0
        var categoriesCreated: Int = 0
    }
}
