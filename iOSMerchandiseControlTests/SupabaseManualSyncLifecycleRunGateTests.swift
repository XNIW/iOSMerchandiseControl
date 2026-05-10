import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class SupabaseManualSyncLifecycleRunGateTests: XCTestCase {
    private let ownerID = UUID(uuidString: "09500000-0000-4095-8095-000000000095")!

    func testTask095ForegroundMultiplesDoNotCreateDuplicateRun() {
        var now = Date(timeIntervalSince1970: 1_779_000_000)
        let gate = makeGate(now: { now })

        let first = gate.begin(kind: .previewReadOnly, source: .rootForeground)
        now = now.addingTimeInterval(1)
        let second = gate.begin(kind: .previewReadOnly, source: .rootForeground)

        guard case .started(let firstSnapshot) = first else {
            XCTFail("Expected first foreground run to start")
            return
        }
        guard case .ignored(let reason, let secondSnapshot) = second else {
            XCTFail("Expected second foreground run to be ignored")
            return
        }
        XCTAssertEqual(reason, .runAlreadyActive)
        XCTAssertEqual(secondSnapshot.runID, firstSnapshot.runID)
        XCTAssertEqual(secondSnapshot.state, .running)
    }

    func testTask095RootOptionsAndReleaseSheetDoNotCompeteForMutatingRun() {
        let gate = makeGate()

        let root = gate.begin(kind: .previewReadOnly, source: .rootForeground)
        let options = gate.begin(kind: .pullPreview, source: .optionsCard)
        let releaseSheet = gate.begin(kind: .pushAggregated, source: .releaseSheet)

        guard case .started = root else {
            XCTFail("Expected root preview to start")
            return
        }
        guard case .ignored(let optionsReason, _) = options else {
            XCTFail("Expected options preview to dedupe")
            return
        }
        guard case .ignored(let sheetReason, _) = releaseSheet else {
            XCTFail("Expected sheet mutation to wait for active run")
            return
        }
        XCTAssertEqual(optionsReason, .runAlreadyActive)
        XCTAssertEqual(sheetReason, .mutatingRunAlreadyActive)
    }

    func testTask095InterruptedMutationHasPriorityOverReadOnlyForegroundCheck() {
        let gate = makeGate()
        let started = gate.begin(kind: .pushAggregated, source: .releaseSheet)
        guard case .started(let snapshot) = started, let runID = snapshot.runID else {
            XCTFail("Expected mutating run to start")
            return
        }

        gate.markInterrupted(runID: runID, reason: .remoteWriteUnverified)
        let foreground = gate.begin(kind: .previewReadOnly, source: .rootForeground)

        guard case .ignored(let reason, let foregroundSnapshot) = foreground else {
            XCTFail("Expected foreground read-only run to be ignored")
            return
        }
        XCTAssertEqual(reason, .interruptedMutationNeedsReview)
        XCTAssertEqual(foregroundSnapshot.state, .interrupted)
        XCTAssertEqual(foregroundSnapshot.interruptReason, .remoteWriteUnverified)
    }

    func testTask095PreflightBlocksRetryWhenAuthOwnerNetworkOrContextAreUnsafe() {
        let authBlocked = makeGate(isSignedIn: false)
        assertBlocked(authBlocked.begin(kind: .pushAggregated, source: .releaseSheet), .authMissing)

        let ownerBlocked = makeGate(ownerUserID: nil)
        assertBlocked(ownerBlocked.begin(kind: .pushAggregated, source: .releaseSheet), .ownerMissing)

        let networkBlocked = makeGate(isNetworkAvailable: false)
        assertBlocked(networkBlocked.begin(kind: .pushAggregated, source: .releaseSheet), .networkUnavailable)

        let contextBlocked = makeGate(isAppContextSafe: false)
        assertBlocked(contextBlocked.begin(kind: .pushAggregated, source: .releaseSheet), .unsafeAppContext)

        let appInactiveBlocked = makeGate(isAppLifecycleCompatible: false)
        assertBlocked(appInactiveBlocked.begin(kind: .pushAggregated, source: .releaseSheet), .appNotActive)
    }

    func testTask095TimeBudgetMovesRunToReadyToRetryWithoutCompleting() {
        var now = Date(timeIntervalSince1970: 1_779_000_000)
        let gate = makeGate(now: { now }, timeBudget: 5)
        let started = gate.begin(kind: .pullPreview, source: .optionsCard)
        guard case .started(let snapshot) = started, let runID = snapshot.runID else {
            XCTFail("Expected run to start")
            return
        }

        now = now.addingTimeInterval(6)
        let expired = gate.expireBudgetIfNeeded()
        let completed = gate.markCompletedVerified(runID: runID)

        XCTAssertEqual(expired.state, .readyToRetry)
        XCTAssertEqual(expired.interruptReason, .timeBudgetExceeded)
        XCTAssertEqual(completed.state, .readyToRetry)
    }

    func testTask095RemoteWriteUnverifiedNeverBecomesCompletedVerified() {
        let gate = makeGate()
        let started = gate.begin(kind: .pushAggregated, source: .releaseSheet)
        guard case .started(let snapshot) = started, let runID = snapshot.runID else {
            XCTFail("Expected mutating run to start")
            return
        }

        let interrupted = gate.markInterrupted(runID: runID, reason: .remoteWriteUnverified)
        let completed = gate.markCompletedVerified(runID: runID)

        XCTAssertEqual(interrupted.state, .interrupted)
        XCTAssertEqual(completed.state, .interrupted)
    }

    private func makeGate(
        now: @escaping () -> Date = { Date(timeIntervalSince1970: 1_779_000_000) },
        isSignedIn: Bool = true,
        ownerUserID: UUID? = UUID(uuidString: "09500000-0000-4095-8095-000000000095")!,
        isNetworkAvailable: Bool = true,
        isAppContextSafe: Bool = true,
        isAppLifecycleCompatible: Bool = true,
        timeBudget: TimeInterval = 45
    ) -> SupabaseManualSyncLifecycleRunGate {
        SupabaseManualSyncLifecycleRunGate(
            now: now,
            preflight: SupabaseManualSyncLifecyclePreflight(
                isSignedIn: { isSignedIn },
                ownerUserID: { ownerUserID },
                isNetworkAvailable: { isNetworkAvailable },
                isAppContextSafe: { isAppContextSafe },
                isAppLifecycleCompatible: { isAppLifecycleCompatible }
            ),
            timeBudget: timeBudget
        )
    }

    private func assertBlocked(
        _ decision: SupabaseManualSyncLifecycleRunGateDecision,
        _ expectedReason: SupabaseManualSyncLifecycleBlockReason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .blocked(let reason, let snapshot) = decision else {
            XCTFail("Expected blocked decision", file: file, line: line)
            return
        }
        XCTAssertEqual(reason, expectedReason, file: file, line: line)
        XCTAssertEqual(snapshot.state, .blocked, file: file, line: line)
    }
}
