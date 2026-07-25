import Foundation

actor AutomaticSyncSingleFlight {
    static let processShared = AutomaticSyncSingleFlight()

    private var running = false
    private var isStoreReplacementSuspended = false
    private var idleWaiters: [CheckedContinuation<Void, Never>] = []

    var isRunning: Bool {
        running
    }

    var isSuspendedForStoreReplacement: Bool {
        isStoreReplacementSuspended
    }

    func begin() -> Bool {
        guard !running, !isStoreReplacementSuspended else { return false }
        running = true
        return true
    }

    func finish() {
        running = false
        let waiters = idleWaiters
        idleWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }

    func cancel() {
        // Cancellation is cooperative: keep the flight closed until the
        // running operation observes cancellation and finishes.
    }

    func waitUntilIdle() async {
        guard running else { return }
        await withCheckedContinuation { continuation in
            idleWaiters.append(continuation)
        }
    }

    /// Atomically closes admission for every process-local automatic engine,
    /// then waits for an already-admitted run to finish its ModelContext work.
    func suspendForStoreReplacementAndWait() async {
        isStoreReplacementSuspended = true
        await waitUntilIdle()
    }

    func resumeAfterStoreReplacement() {
        isStoreReplacementSuspended = false
    }
}
