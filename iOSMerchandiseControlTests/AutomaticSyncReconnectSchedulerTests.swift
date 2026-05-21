import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class AutomaticSyncReconnectSchedulerTests: XCTestCase {
    func testOfflineToOnlineSchedulesOneForegroundReconnectIntent() async throws {
        var triggerCount = 0
        let scheduler = AutomaticSyncReconnectScheduler(debounce: 0.01) {
            triggerCount += 1
        }

        scheduler.setForeground(true)
        scheduler.receive(.unsatisfied)
        scheduler.receive(.satisfied)
        scheduler.receive(.satisfied)

        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(triggerCount, 1)
    }

    func testNetworkFlappingCoalescesToSingleReconnectIntent() async throws {
        var triggerCount = 0
        let scheduler = AutomaticSyncReconnectScheduler(debounce: 0.03) {
            triggerCount += 1
        }

        scheduler.setForeground(true)
        scheduler.receive(.unsatisfied)
        scheduler.receive(.satisfied)
        try await Task.sleep(nanoseconds: 10_000_000)
        scheduler.receive(.unsatisfied)
        scheduler.receive(.satisfied)

        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(triggerCount, 1)
    }

    func testBackgroundCancelsPendingReconnectIntent() async throws {
        var triggerCount = 0
        let scheduler = AutomaticSyncReconnectScheduler(debounce: 0.03) {
            triggerCount += 1
        }

        scheduler.setForeground(true)
        scheduler.receive(.unsatisfied)
        scheduler.receive(.satisfied)
        scheduler.setForeground(false)

        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(triggerCount, 0)
    }
}
