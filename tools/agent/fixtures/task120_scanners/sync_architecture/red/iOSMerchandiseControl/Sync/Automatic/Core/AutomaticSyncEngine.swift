actor AutomaticSyncEngine {
    private let singleFlight = AutomaticSyncSingleFlight()
    private let cancellation = AutomaticSyncCancellationPolicy()
}
