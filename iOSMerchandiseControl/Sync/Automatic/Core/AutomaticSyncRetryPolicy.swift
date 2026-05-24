import Foundation

nonisolated struct AutomaticSyncRetryDecision: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        case none
        case retryAfter(TimeInterval)
    }

    let action: Action
    let reason: String

    static func none(_ reason: String) -> AutomaticSyncRetryDecision {
        AutomaticSyncRetryDecision(action: .none, reason: reason)
    }

    static func retry(after delay: TimeInterval, reason: String) -> AutomaticSyncRetryDecision {
        AutomaticSyncRetryDecision(action: .retryAfter(delay), reason: reason)
    }
}

nonisolated struct AutomaticSyncRetryPolicy: Sendable {
    typealias Sleeper = @Sendable (UInt64) async throws -> Void

    let maxBusyAttempts: Int
    let busyDelay: TimeInterval
    let sleeper: Sleeper

    init(
        maxBusyAttempts: Int = 1,
        busyDelay: TimeInterval = 2,
        sleeper: @escaping Sleeper = { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.maxBusyAttempts = maxBusyAttempts
        self.busyDelay = busyDelay
        self.sleeper = sleeper
    }

    func decisionForBusy(attempt: Int, isBackground: Bool) -> AutomaticSyncRetryDecision {
        guard !isBackground else { return .none("background") }
        guard attempt < maxBusyAttempts else { return .none("max_busy_attempts") }
        return .retry(after: busyDelay, reason: "busy")
    }

    func decisionForAuthBlocked() -> AutomaticSyncRetryDecision {
        .none("auth_blocked")
    }

    func sleep(for decision: AutomaticSyncRetryDecision) async throws {
        guard case .retryAfter(let delay) = decision.action else { return }
        let nanoseconds = UInt64(delay * 1_000_000_000)
        try await sleeper(nanoseconds)
    }
}
