import Foundation

struct BootstrapPullService {
    func decision(
        requiresAccountDecision: Bool,
        lastRecoveryAttemptAt: Date? = nil,
        now: Date = Date()
    ) -> SyncRecoveryPolicy.Decision {
        SyncRecoveryPolicy.decide(
            SyncRecoveryPolicy.Input(
                trigger: .bootstrapRequested,
                reason: .emptyLocalStore,
                context: .bootstrap,
                requiresAccountDecision: requiresAccountDecision,
                now: now,
                lastRecoveryAttemptAt: lastRecoveryAttemptAt
            )
        )
    }
}
