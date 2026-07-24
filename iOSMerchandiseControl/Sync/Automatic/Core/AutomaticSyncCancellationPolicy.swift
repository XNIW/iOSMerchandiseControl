import Foundation

actor AutomaticSyncCancellationPolicy {
    static let processShared = AutomaticSyncCancellationPolicy()

    private var generation = 0

    func makeToken() -> Int {
        generation
    }

    func requestCancellation() {
        generation += 1
    }

    func checkCancellation(token: Int) throws {
        if Task.isCancelled || token != generation {
            throw CancellationError()
        }
    }
}
