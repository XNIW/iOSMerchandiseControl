import XCTest
@testable import iOSMerchandiseControl

final class SyncStatusPresenterTests: XCTestCase {
    func testZeroOfZeroActiveProgressIsHidden() {
        let progress = CloudSyncProgressState.running(
            phase: .drainingSyncEvents,
            domain: .catalog,
            current: 0,
            total: 0,
            message: "Checking"
        )

        XCTAssertNil(SyncStatusPresenter.visibleProgress(from: progress))
        XCTAssertFalse(SyncStatusPresenter.shouldShowFallbackSpinner(isRunning: true, progress: progress))
    }

    func testIndeterminateActiveProgressWithoutZeroTotalStillShowsSpinner() {
        let progress = CloudSyncProgressState.running(
            phase: .checkingCloud,
            domain: .catalog,
            current: nil,
            total: nil,
            message: "Checking"
        )

        XCTAssertEqual(SyncStatusPresenter.visibleProgress(from: progress), progress)
        XCTAssertFalse(SyncStatusPresenter.shouldShowFallbackSpinner(isRunning: true, progress: progress))
    }

    func testRunningWithoutProgressShowsFallbackSpinner() {
        XCTAssertTrue(SyncStatusPresenter.shouldShowFallbackSpinner(isRunning: true, progress: .idle()))
    }
}
