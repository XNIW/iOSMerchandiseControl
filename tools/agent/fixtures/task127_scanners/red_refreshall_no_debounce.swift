import SwiftData

@MainActor
final class OptionsSyncSummaryProvider {
    func refreshAll(context: ModelContext) {
        refreshLocalDatabaseSummary(context: context)
    }

    private func refreshLocalDatabaseSummary(context: ModelContext) {}
}
