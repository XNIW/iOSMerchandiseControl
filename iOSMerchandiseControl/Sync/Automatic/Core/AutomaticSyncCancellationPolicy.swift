import Foundation

private nonisolated final class AutomaticSyncCancellationState: @unchecked Sendable {
    private let lock = NSLock()
    private var generation = 0

    func currentToken() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return generation
    }

    func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        generation += 1
    }

    func withCurrentToken<Result>(_ token: Int, operation: () throws -> Result) throws -> Result {
        lock.lock()
        defer { lock.unlock() }
        try Task.checkCancellation()
        guard generation == token else { throw CancellationError() }
        return try operation()
    }
}

actor AutomaticSyncCancellationPolicy {
    static let processShared = AutomaticSyncCancellationPolicy()

    private let state = AutomaticSyncCancellationState()

    func makeToken() -> Int {
        state.currentToken()
    }

    func requestCancellation() {
        state.invalidate()
    }

    func checkCancellation(token: Int) throws {
        if Task.isCancelled || !isCurrent(token: token) {
            throw CancellationError()
        }
    }

    /// A presentation consumer must check the originating run's cancellation,
    /// even when it executes in a different task from the provider/engine.
    nonisolated func isCurrent(token: Int) -> Bool {
        token == state.currentToken()
    }

    /// Task126 is the outer lock. Cancellation never acquires that lease, and
    /// the operation must not publish callbacks or enter this lock recursively.
    nonisolated func withCurrentToken<Result>(
        _ token: Int, operation: () throws -> Result
    ) throws -> Result {
        try state.withCurrentToken(token, operation: operation)
    }
}
