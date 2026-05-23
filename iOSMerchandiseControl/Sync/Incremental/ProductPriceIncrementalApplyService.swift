import Foundation

struct ProductPriceIncrementalApplyService {
    struct Summary: Equatable, Sendable {
        var targetedProductPricesFetched: Int = 0
        var inserted: Int = 0
        var remoteIdentityLinked: Int = 0
        var missingRemotePruned: Int = 0
        var skippedExisting: Int = 0
        var conflictCount: Int = 0
    }
}
