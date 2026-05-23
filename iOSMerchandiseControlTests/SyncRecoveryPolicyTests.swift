import XCTest
@testable import iOSMerchandiseControl

final class SyncRecoveryPolicyTests: XCTestCase {
    func testNormalForegroundDoesNotAllowFullRecovery() {
        let decision = SyncRecoveryPolicy.decide(
            SyncRecoveryPolicy.Input(
                trigger: .appForeground,
                reason: .canonicalDrift,
                context: .normalForeground
            )
        )

        XCTAssertEqual(decision, .requestLightReconcile)
    }

    func testRecoveryContextAllowsFullRecovery() {
        let decision = SyncRecoveryPolicy.decide(
            SyncRecoveryPolicy.Input(
                trigger: .recoveryRequested,
                reason: .syncEventGap,
                context: .recovery
            )
        )

        XCTAssertEqual(decision, .runFullRecovery)
    }

    func testRecentRecoveryAttemptBacksOff() {
        let now = Date(timeIntervalSince1970: 100)
        let decision = SyncRecoveryPolicy.decide(
            SyncRecoveryPolicy.Input(
                trigger: .recoveryRequested,
                reason: .syncEventGap,
                context: .recovery,
                now: now,
                lastRecoveryAttemptAt: Date(timeIntervalSince1970: 95),
                recoveryBackoffSeconds: 30
            )
        )

        XCTAssertEqual(decision, .blockedBackoff)
    }

    func testBootstrapContextChoosesBootstrapPull() {
        let decision = SyncRecoveryPolicy.decide(
            SyncRecoveryPolicy.Input(
                trigger: .bootstrapRequested,
                reason: .emptyLocalStore,
                context: .bootstrap
            )
        )

        XCTAssertEqual(decision, .runBootstrapPull)
    }
}
