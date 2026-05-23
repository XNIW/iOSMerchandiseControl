import XCTest
@testable import iOSMerchandiseControl

final class SyncDecisionEngineTests: XCTestCase {
    func testLocalMutationWithPendingChoosesPushWithoutFullPull() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .localMutation,
                isAuthenticated: true,
                isNetworkAvailable: true,
                hasPendingLocalChanges: true
            )
        )

        XCTAssertEqual(action, .pushPending)
        XCTAssertFalse(action.containsFullRecovery)
    }

    func testRemoteSyncEventChoosesIncrementalDrain() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .remoteSyncEvent,
                isAuthenticated: true,
                isNetworkAvailable: true,
                hasRemoteSyncEvent: true
            )
        )

        XCTAssertEqual(action, .drainEvents)
        XCTAssertFalse(action.containsFullRecovery)
    }

    func testSameAccountReconnectPushesPendingThenDrainsAndLightReconciles() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .networkAvailable,
                isAuthenticated: true,
                isNetworkAvailable: true,
                hasPendingLocalChanges: true,
                hasRemoteSyncEvent: true,
                hasRemoteVerificationDrift: true
            )
        )

        XCTAssertEqual(action, .sequence([.pushPending, .drainEvents, .lightReconcile]))
    }

    func testAccountDecisionBlocksBeforePushOrDrain() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .authChanged,
                isAuthenticated: true,
                isNetworkAvailable: true,
                requiresAccountDecision: true,
                hasPendingLocalChanges: true,
                hasRemoteSyncEvent: true
            )
        )

        XCTAssertEqual(action, .blocked(.accountDecisionRequired))
    }

    func testSyncBusySchedulesRetry() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .remoteSyncEvent,
                isAuthenticated: true,
                isNetworkAvailable: true,
                hasRemoteSyncEvent: true,
                isSyncBusy: true
            )
        )

        XCTAssertEqual(action, .retryAfterBusy)
    }

    func testForegroundRecoveryRequestDoesNotStartFullRecoveryDirectly() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .appForeground,
                isAuthenticated: true,
                isNetworkAvailable: true,
                requiresFullRecovery: true,
                fullRecoveryContext: .normalForeground
            )
        )

        XCTAssertEqual(action, .requestRecovery)
        XCTAssertFalse(action.containsFullRecovery)
    }

    func testManualRecoveryContextCanChooseFullRecovery() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .manualRefresh,
                isAuthenticated: true,
                isNetworkAvailable: true,
                requiresFullRecovery: true,
                fullRecoveryContext: .manual
            )
        )

        XCTAssertEqual(action, .fullRecovery)
    }

    func testZeroOfZeroProgressIsHiddenAtStateLevel() {
        let state = SyncState(
            phase: .pushing,
            progress: SyncProgress(current: 0, total: 0)
        )

        XCTAssertFalse(state.isProgressVisible)
    }
}
