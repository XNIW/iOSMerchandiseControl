import Foundation

struct DriftReconciliationService {
    func decision(
        hasDrift: Bool,
        context: SyncFullRecoveryContext,
        lastRecoveryAttemptAt: Date? = nil,
        now: Date = Date()
    ) -> SyncRecoveryPolicy.Decision {
        guard hasDrift else { return .noOp }
        return SyncRecoveryPolicy.decide(
            SyncRecoveryPolicy.Input(
                trigger: .recoveryRequested,
                reason: .canonicalDrift,
                context: context,
                now: now,
                lastRecoveryAttemptAt: lastRecoveryAttemptAt
            )
        )
    }
}
