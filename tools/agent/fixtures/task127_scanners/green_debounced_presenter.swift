import SwiftData

@MainActor
final class OptionsSyncSummaryProvider {
    private var summaryTask: Task<Void, Never>?
    private var isRefreshInFlight = false
    private var coalescedEvents = 0

    func refreshAll(context: ModelContext, refreshReason: String) {
        guard !isRefreshInFlight else {
            coalescedEvents += 1
            return
        }
        summaryTask?.cancel()
        summaryTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
    }
}
