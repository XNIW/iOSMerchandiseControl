import Foundation

actor AutomaticSyncSingleFlight {
    private var running = false

    var isRunning: Bool {
        running
    }

    func begin() -> Bool {
        guard !running else { return false }
        running = true
        return true
    }

    func finish() {
        running = false
    }

    func cancel() {
        running = false
    }
}
