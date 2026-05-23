import Foundation

struct HistoryIncrementalApplyService {
    struct Summary: Equatable, Sendable {
        var targetedHistoryFetched: Int = 0
        var inserted: Int = 0
        var updated: Int = 0
        var missingRemoteTombstoned: Int = 0
        var hiddenDebugEntries: Int = 0
    }
}
