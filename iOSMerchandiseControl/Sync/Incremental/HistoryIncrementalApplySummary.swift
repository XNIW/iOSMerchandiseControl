import Foundation

struct HistoryIncrementalApplySummary: Equatable, Sendable {
    var targetedHistoryFetched: Int = 0
    var inserted: Int = 0
    var updated: Int = 0
    var missingRemoteTombstoned: Int = 0
    var hiddenDebugEntries: Int = 0

    init() {}

    init(_ summary: SupabaseSyncEventIncrementalApplySummary) {
        targetedHistoryFetched = summary.targetedHistoryFetched
        inserted = summary.historyInserted
        updated = summary.historyUpdated
        missingRemoteTombstoned = summary.historyMissingRemoteTombstoned
    }
}

extension SupabaseSyncEventIncrementalApplySummary {
    var historySummary: HistoryIncrementalApplySummary {
        HistoryIncrementalApplySummary(self)
    }
}

