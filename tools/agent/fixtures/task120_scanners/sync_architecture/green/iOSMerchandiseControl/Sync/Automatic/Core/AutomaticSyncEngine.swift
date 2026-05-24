actor AutomaticSyncEngine {
    private let singleFlight = AutomaticSyncSingleFlight()
    private let cancellation = AutomaticSyncCancellationPolicy()
    private let retry = AutomaticSyncRetryPolicy()
}
