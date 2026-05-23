import Foundation

enum SyncRecoveryPolicy {
    enum Reason: Equatable, Sendable {
        case emptyLocalStore
        case canonicalDrift
        case syncEventGap
        case manualUserRequest
        case harnessRequest
    }

    enum Decision: Equatable, Sendable {
        case noOp
        case requestLightReconcile
        case runBootstrapPull
        case runFullRecovery
        case blockedBackoff
        case blockedAccountDecision
    }

    struct Input: Equatable, Sendable {
        var trigger: SyncTrigger
        var reason: Reason
        var context: SyncFullRecoveryContext
        var requiresAccountDecision: Bool
        var now: Date
        var lastRecoveryAttemptAt: Date?
        var recoveryBackoffSeconds: TimeInterval

        init(
            trigger: SyncTrigger,
            reason: Reason,
            context: SyncFullRecoveryContext,
            requiresAccountDecision: Bool = false,
            now: Date = Date(),
            lastRecoveryAttemptAt: Date? = nil,
            recoveryBackoffSeconds: TimeInterval = 60
        ) {
            self.trigger = trigger
            self.reason = reason
            self.context = context
            self.requiresAccountDecision = requiresAccountDecision
            self.now = now
            self.lastRecoveryAttemptAt = lastRecoveryAttemptAt
            self.recoveryBackoffSeconds = max(0, recoveryBackoffSeconds)
        }
    }

    static func decide(_ input: Input) -> Decision {
        if input.requiresAccountDecision {
            return .blockedAccountDecision
        }

        if let lastRecoveryAttemptAt = input.lastRecoveryAttemptAt,
           input.now.timeIntervalSince(lastRecoveryAttemptAt) < input.recoveryBackoffSeconds {
            return .blockedBackoff
        }

        switch input.context {
        case .bootstrap:
            return .runBootstrapPull
        case .recovery, .manual, .harness:
            return .runFullRecovery
        case .normalForeground:
            return input.reason == .emptyLocalStore ? .noOp : .requestLightReconcile
        }
    }
}
