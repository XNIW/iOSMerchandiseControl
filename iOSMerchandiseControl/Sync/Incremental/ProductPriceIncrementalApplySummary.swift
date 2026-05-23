import Foundation

struct ProductPriceIncrementalApplySummary: Equatable, Sendable {
    var targetedProductPricesFetched: Int = 0
    var inserted: Int = 0
    var remoteIdentityLinked: Int = 0
    var missingRemotePruned: Int = 0
    var skippedExisting: Int = 0
    var conflictCount: Int = 0

    init() {}

    init(_ summary: SupabaseSyncEventIncrementalApplySummary) {
        targetedProductPricesFetched = summary.targetedProductPricesFetched
        inserted = summary.productPricesInserted
        remoteIdentityLinked = summary.productPriceIdentityLinked
        missingRemotePruned = summary.productPricesMissingRemotePruned
    }
}

extension SupabaseSyncEventIncrementalApplySummary {
    var productPriceSummary: ProductPriceIncrementalApplySummary {
        ProductPriceIncrementalApplySummary(self)
    }
}

