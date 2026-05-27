import XCTest
@testable import iOSMerchandiseControl

final class Task126AccountSwitchReviewUITests: XCTestCase {
    func testDirtyAccountSwitchShowsRecoveryChoicesAndBlocksCrossAccountPush() {
        let state = Task126ReviewInteractionFixtures.accountSwitchDirty()

        XCTAssertEqual(state.surface, .accountSwitchRecovery)
        XCTAssertEqual(state.visibleChoiceIDs, [
            .cancel,
            .keepCurrentAccount,
            .exportBackup,
            .discardPendingAndSwitch
        ])
        XCTAssertTrue(state.isDialogVisible)
        XCTAssertFalse(state.isApplying)
        XCTAssertEqual(state.pendingBefore, 3)

        let cancel = Task126ReviewInteractionReducer.apply(.cancel, to: state)
        XCTAssertEqual(cancel.observedLocalResult, "account=A;pending=3")
        XCTAssertEqual(cancel.observedSyncResult, "blockedCrossAccountPush=true")
        XCTAssertEqual(cancel.pendingAfter, 3)

        let keepCurrent = Task126ReviewInteractionReducer.apply(.keepCurrentAccount, to: state)
        XCTAssertEqual(keepCurrent.observedLocalResult, "account=A;pending=3")
        XCTAssertEqual(keepCurrent.observedSyncResult, "blockedCrossAccountPush=true")
        XCTAssertEqual(keepCurrent.pendingAfter, 3)

        let discard = Task126ReviewInteractionReducer.apply(.discardPendingAndSwitch, to: state)
        XCTAssertEqual(discard.observedLocalResult, "account=B;pending=0")
        XCTAssertEqual(discard.observedSyncResult, "blockedCrossAccountPush=true;discardConfirmed=true")
        XCTAssertEqual(discard.pendingAfter, 0)
        XCTAssertGreaterThanOrEqual(discard.timeToFinalStateMs, discard.timeToApplyChoiceMs)
    }

    func testCleanAccountSwitchToPopulatedAccountUsesLightConfirmation() {
        let state = Task126ReviewInteractionFixtures.accountSwitchCleanRemotePopulated()

        XCTAssertEqual(state.pendingBefore, 0)
        XCTAssertEqual(state.visibleChoiceIDs, [.cancel, .switchAccount])

        let cancel = Task126ReviewInteractionReducer.apply(.cancel, to: state)
        XCTAssertEqual(cancel.observedLocalResult, "account=A;pending=0")
        XCTAssertEqual(cancel.observedSyncResult, "cancelled=true;reseed=not-started")

        let outcome = Task126ReviewInteractionReducer.apply(.switchAccount, to: state)

        XCTAssertEqual(outcome.observedLocalResult, "account=B;cache=verified")
        XCTAssertEqual(outcome.observedSyncResult, "pending=0;reseed=remote-populated")
        XCTAssertEqual(outcome.pendingAfter, 0)
        XCTAssertEqual(outcome.conflictCountAfter, 0)
    }

    func testExportBackupKeepsAccountAndPendingUntilUserConfirmsDiscard() {
        let state = Task126ReviewInteractionFixtures.accountSwitchDirty()

        let outcome = Task126ReviewInteractionReducer.apply(.exportBackup, to: state)

        XCTAssertEqual(outcome.observedLocalResult, "account=A;backupExported=true;pending=3")
        XCTAssertEqual(outcome.observedSyncResult, "blockedCrossAccountPush=true")
        XCTAssertEqual(outcome.pendingAfter, 3)
    }
}
