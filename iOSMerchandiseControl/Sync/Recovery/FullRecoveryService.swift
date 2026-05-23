import Foundation

struct FullRecoveryService {
    func decision(
        reason: SyncRecoveryPolicy.Reason,
        context: SyncFullRecoveryContext,
        lastRecoveryAttemptAt: Date? = nil,
        now: Date = Date()
    ) -> SyncRecoveryPolicy.Decision {
        SyncRecoveryPolicy.decide(
            SyncRecoveryPolicy.Input(
                trigger: .recoveryRequested,
                reason: reason,
                context: context,
                now: now,
                lastRecoveryAttemptAt: lastRecoveryAttemptAt
            )
        )
    }
}
