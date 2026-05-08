import XCTest
@testable import iOSMerchandiseControl

#if DEBUG
@MainActor
final class SyncEventOutboxDrainDebugViewModelTests: XCTestCase {
    private let ownerA = "00000000-0000-4000-8000-000000000061"
    private let ownerB = "00000000-0000-4000-8000-000000000062"
    private let now = Date(timeIntervalSince1970: 1_778_700_000)

    func testRefreshCountsSuccessReadsCountsAndDoesNotDrain() async {
        let fake = FakeDrainDebugDependencies(
            fetchResults: [.success(counts(pending: 2, retryable: 1))]
        )
        let viewModel = makeViewModel(fake)

        await viewModel.refreshCounts(isAuthenticated: true, ownerUserID: ownerA)

        XCTAssertEqual(fake.fetchCalls.map(\.ownerUserID), [ownerA])
        XCTAssertEqual(viewModel.counts, counts(pending: 2, retryable: 1))
        XCTAssertEqual(viewModel.lastCountsRefreshAt, now)
        XCTAssertEqual(fake.drainCalls.count, 0)
        XCTAssertFalse(viewModel.didFailRefreshingCounts)
    }

    func testRefreshCountsFailureKeepsPreviousCountsAndTimestamp() async {
        let validCounts = counts(pending: 1, retryable: 1, sent: 2)
        let fake = FakeDrainDebugDependencies(
            fetchResults: [
                .success(validCounts),
                .failure(TestError.fetchFailed)
            ]
        )
        let viewModel = makeViewModel(fake)

        await viewModel.refreshCounts(isAuthenticated: true, ownerUserID: ownerA)
        await viewModel.refreshCounts(isAuthenticated: true, ownerUserID: ownerA)

        XCTAssertEqual(fake.fetchCalls.count, 2)
        XCTAssertEqual(viewModel.counts, validCounts)
        XCTAssertEqual(viewModel.lastCountsRefreshAt, now)
        XCTAssertTrue(viewModel.didFailRefreshingCounts)
        XCTAssertNil(viewModel.lastDrainMessage)
        XCTAssertEqual(fake.drainCalls.count, 0)
    }

    func testInvalidSessionOrOwnerDoesNotFetchOrDrain() async {
        let fake = FakeDrainDebugDependencies(
            fetchResults: [.success(counts(retryable: 1))],
            drainResults: [.success(outcome(.drained, sent: 1))]
        )
        let viewModel = makeViewModel(fake)

        await viewModel.refreshCounts(isAuthenticated: false, ownerUserID: ownerA)
        viewModel.requestDrainConfirmation(isAuthenticated: false, ownerUserID: ownerA)
        await viewModel.confirmDrain(isAuthenticated: false, ownerUserID: ownerA)
        await viewModel.refreshCounts(isAuthenticated: true, ownerUserID: "not-a-uuid")
        viewModel.requestDrainConfirmation(isAuthenticated: true, ownerUserID: "not-a-uuid")
        await viewModel.confirmDrain(isAuthenticated: true, ownerUserID: "not-a-uuid")

        XCTAssertEqual(fake.fetchCalls.count, 0)
        XCTAssertEqual(fake.drainCalls.count, 0)
        XCTAssertNil(viewModel.counts)
        XCTAssertEqual(viewModel.accessIssue(isAuthenticated: false, ownerUserID: ownerA), .missingSession)
        XCTAssertEqual(viewModel.accessIssue(isAuthenticated: true, ownerUserID: "not-a-uuid"), .invalidOwner)
    }

    func testSelectedLimitAllowsOnlyPresetsAndPassesSelectedLimitToDrain() async {
        let fake = FakeDrainDebugDependencies(
            fetchResults: [
                .success(counts(retryable: 5)),
                .success(counts(retryable: 0))
            ],
            drainResults: [.success(outcome(.drained, sent: 5))]
        )
        let viewModel = makeViewModel(fake)

        XCTAssertEqual(viewModel.selectedLimit, 10)
        viewModel.selectLimit(25)
        viewModel.selectLimit(7)
        await viewModel.refreshCounts(isAuthenticated: true, ownerUserID: ownerA)
        await requestAndConfirmDrain(viewModel)

        XCTAssertEqual(viewModel.selectedLimit, 25)
        XCTAssertEqual(fake.drainCalls.map(\.limit), [25])
        XCTAssertEqual(fake.drainCalls.map(\.fetchScanLimit), [nil])
    }

    func testRequestDrainConfirmationDoesNotDrainUntilConfirm() async {
        let fake = FakeDrainDebugDependencies(
            fetchResults: [
                .success(counts(retryable: 1)),
                .success(counts(retryable: 0))
            ],
            drainResults: [.success(outcome(.drained, sent: 1))]
        )
        let viewModel = makeViewModel(fake)

        await viewModel.refreshCounts(isAuthenticated: true, ownerUserID: ownerA)
        viewModel.requestDrainConfirmation(isAuthenticated: true, ownerUserID: ownerA)

        XCTAssertTrue(viewModel.isShowingDrainConfirmation)
        XCTAssertEqual(fake.drainCalls.count, 0)

        await viewModel.confirmDrain(isAuthenticated: true, ownerUserID: ownerA)

        XCTAssertFalse(viewModel.isShowingDrainConfirmation)
        XCTAssertEqual(fake.drainCalls.count, 1)
    }

    func testConfirmDrainWithoutPendingConfirmationDoesNotDrain() async {
        let fake = FakeDrainDebugDependencies(
            fetchResults: [.success(counts(retryable: 1))],
            drainResults: [.success(outcome(.drained, sent: 1))]
        )
        let viewModel = makeViewModel(fake)

        await viewModel.refreshCounts(isAuthenticated: true, ownerUserID: ownerA)
        await viewModel.confirmDrain(isAuthenticated: true, ownerUserID: ownerA)

        XCTAssertEqual(fake.drainCalls.count, 0)
        XCTAssertNil(viewModel.lastDrainMessage)
    }

    func testDrainOutcomeMapping() async {
        let cases: [(SyncEventOutboxDrainOutcome, SyncEventOutboxDrainDebugViewModel.DrainMessage)] = [
            (outcome(.noWork), .noWork),
            (outcome(.drained, sent: 2), .drained(sent: 2)),
            (outcome(.partiallyDrained, sent: 2, retryScheduled: 1, blocked: 3, dead: 4), .partial(sent: 2, retryScheduled: 1, blocked: 3, dead: 4)),
            (outcome(.blockedPayloadReplay, blocked: 1), .blocked),
            (outcome(.blocked, blocked: 1), .blocked),
            (outcome(.alreadyRunning), .alreadyRunning),
            (outcome(.networkFailed, retryScheduled: 1), .network)
        ]

        for (drainOutcome, expectedMessage) in cases {
            let fake = FakeDrainDebugDependencies(
                fetchResults: [
                    .success(counts(retryable: 1)),
                    .success(counts(retryable: 0))
                ],
                drainResults: [.success(drainOutcome)]
            )
            let viewModel = makeViewModel(fake)

            await viewModel.refreshCounts(isAuthenticated: true, ownerUserID: ownerA)
            await requestAndConfirmDrain(viewModel)

            XCTAssertEqual(viewModel.lastDrainMessage, expectedMessage)
        }
    }

    func testDrainErrorMapping() async {
        let cases: [(Error, SyncEventOutboxDrainDebugViewModel.DrainMessage)] = [
            (CancellationError(), .cancelled),
            (SyncEventOutboxDrainError.invalidOwnerUserID, .invalidOwner),
            (SyncEventOutboxDrainError.localSaveFailed(operation: "save"), .localSaveFailed),
            (TestError.drainFailed, .network)
        ]

        for (error, expectedMessage) in cases {
            let fake = FakeDrainDebugDependencies(
                fetchResults: [.success(counts(retryable: 1))],
                drainResults: [.failure(error)]
            )
            let viewModel = makeViewModel(fake)

            await viewModel.refreshCounts(isAuthenticated: true, ownerUserID: ownerA)
            await requestAndConfirmDrain(viewModel)

            XCTAssertEqual(viewModel.lastDrainMessage, expectedMessage)
        }
    }

    func testDoubleTapDuringDrainStartsOnlyOneRun() async throws {
        let fake = BlockingDrainDebugDependencies(
            fetchResults: [
                .success(counts(retryable: 2)),
                .success(counts(retryable: 0))
            ],
            drainOutcome: outcome(.drained, sent: 1)
        )
        let viewModel = SyncEventOutboxDrainDebugViewModel(
            clock: { self.now },
            fetchCounts: fake.fetchCounts(ownerUserID:now:),
            drainOnce: fake.drainOnce(ownerUserID:limit:fetchScanLimit:)
        )

        await viewModel.refreshCounts(isAuthenticated: true, ownerUserID: ownerA)

        viewModel.requestDrainConfirmation(isAuthenticated: true, ownerUserID: ownerA)
        let firstDrain = Task { await viewModel.confirmDrain(isAuthenticated: true, ownerUserID: ownerA) }
        try await fake.waitForDrainCallCount(1)
        let secondDrain = Task { await viewModel.confirmDrain(isAuthenticated: true, ownerUserID: ownerA) }
        await secondDrain.value

        XCTAssertEqual(fake.drainCalls.count, 1)

        fake.finishDrain()
        await firstDrain.value
        XCTAssertEqual(fake.drainCalls.count, 1)
    }

    func testOwnerChangeResetsOldCountsAndResult() async {
        let fake = FakeDrainDebugDependencies(
            fetchResults: [
                .success(counts(retryable: 1)),
                .success(counts(retryable: 0))
            ],
            drainResults: [.success(outcome(.noWork))]
        )
        let viewModel = makeViewModel(fake)

        await viewModel.refreshCounts(isAuthenticated: true, ownerUserID: ownerA)
        await requestAndConfirmDrain(viewModel)
        XCTAssertNotNil(viewModel.counts)
        XCTAssertNotNil(viewModel.lastDrainMessage)

        viewModel.updateSession(isAuthenticated: true, ownerUserID: ownerB)

        XCTAssertNil(viewModel.counts)
        XCTAssertNil(viewModel.lastCountsRefreshAt)
        XCTAssertNil(viewModel.lastDrainMessage)
        XCTAssertFalse(viewModel.didFailRefreshingCounts)
    }

    func testRepeatedAppearDoesNotLoopAndDrainRefreshesCountsAtMostOnce() async {
        let fake = FakeDrainDebugDependencies(
            fetchResults: [
                .success(counts(retryable: 2)),
                .success(counts(retryable: 1))
            ],
            drainResults: [.success(outcome(.drained, sent: 1))]
        )
        let viewModel = makeViewModel(fake)

        await viewModel.refreshCountsIfNeeded(isAuthenticated: true, ownerUserID: ownerA)
        await viewModel.refreshCountsIfNeeded(isAuthenticated: true, ownerUserID: ownerA)
        await requestAndConfirmDrain(viewModel)

        XCTAssertEqual(fake.fetchCalls.count, 2)
        XCTAssertEqual(fake.drainCalls.count, 1)
    }

    func testDrainIsNotRequestedWhenRetryableCountIsZero() async {
        let fake = FakeDrainDebugDependencies(
            fetchResults: [.success(counts(retryable: 0))],
            drainResults: [.success(outcome(.drained, sent: 1))]
        )
        let viewModel = makeViewModel(fake)

        await viewModel.refreshCounts(isAuthenticated: true, ownerUserID: ownerA)
        viewModel.requestDrainConfirmation(isAuthenticated: true, ownerUserID: ownerA)
        await viewModel.confirmDrain(isAuthenticated: true, ownerUserID: ownerA)

        XCTAssertFalse(viewModel.isShowingDrainConfirmation)
        XCTAssertEqual(fake.drainCalls.count, 0)
        XCTAssertFalse(viewModel.canDrain)
    }

    func testProductionViewModelKeepsAntiScopeBoundaries() throws {
        let source = try productionSource(named: "SyncEventOutboxDrainDebugViewModel.swift")
        let forbiddenTokens = [
            joined("Supabase", "Client"),
            joined(".", "rpc", "("),
            joined(".", "channel"),
            "Realtime",
            joined("BG", "Task"),
            "Timer",
            "cleanup",
            "truncate",
            joined(".", "delete", "("),
            "record_sync_event"
        ]

        for token in forbiddenTokens {
            XCTAssertFalse(source.contains(token), "Unexpected token in drain debug ViewModel: \(token)")
        }
    }

    private enum TestError: Error {
        case fetchFailed
        case drainFailed
    }

    private func makeViewModel(_ fake: FakeDrainDebugDependencies) -> SyncEventOutboxDrainDebugViewModel {
        SyncEventOutboxDrainDebugViewModel(
            clock: { self.now },
            fetchCounts: fake.fetchCounts(ownerUserID:now:),
            drainOnce: fake.drainOnce(ownerUserID:limit:fetchScanLimit:)
        )
    }

    private func requestAndConfirmDrain(_ viewModel: SyncEventOutboxDrainDebugViewModel) async {
        viewModel.requestDrainConfirmation(isAuthenticated: true, ownerUserID: ownerA)
        await viewModel.confirmDrain(isAuthenticated: true, ownerUserID: ownerA)
    }

    private func counts(
        pending: Int = 0,
        retryable: Int = 0,
        blocked: Int = 0,
        dead: Int = 0,
        sent: Int = 0,
        localOnly: Int = 0
    ) -> SyncEventOutboxCounts {
        SyncEventOutboxCounts(
            pending: pending,
            retryable: retryable,
            blocked: blocked,
            dead: dead,
            sent: sent,
            localOnly: localOnly
        )
    }

    private func outcome(
        _ status: SyncEventOutboxDrainStatus,
        sent: Int = 0,
        retryScheduled: Int = 0,
        blocked: Int = 0,
        dead: Int = 0
    ) -> SyncEventOutboxDrainOutcome {
        SyncEventOutboxDrainOutcome(
            status: status,
            attempted: sent + retryScheduled + blocked + dead,
            sent: sent,
            retryScheduled: retryScheduled,
            blocked: blocked,
            dead: dead
        )
    }

    private func productionSource(named fileName: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = testsDirectory
            .appendingPathComponent("iOSMerchandiseControl")
            .appendingPathComponent(fileName)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func joined(_ parts: String...) -> String {
        parts.joined()
    }
}

@MainActor
private final class FakeDrainDebugDependencies {
    private var fetchResults: [Result<SyncEventOutboxCounts, Error>]
    private var drainResults: [Result<SyncEventOutboxDrainOutcome, Error>]
    private(set) var fetchCalls: [(ownerUserID: String, now: Date)] = []
    private(set) var drainCalls: [(ownerUserID: String, limit: Int, fetchScanLimit: Int?)] = []

    init(
        fetchResults: [Result<SyncEventOutboxCounts, Error>] = [],
        drainResults: [Result<SyncEventOutboxDrainOutcome, Error>] = []
    ) {
        self.fetchResults = fetchResults
        self.drainResults = drainResults
    }

    func fetchCounts(ownerUserID: String, now: Date) async throws -> SyncEventOutboxCounts {
        fetchCalls.append((ownerUserID, now))
        guard !fetchResults.isEmpty else { return SyncEventOutboxCounts() }
        return try fetchResults.removeFirst().get()
    }

    func drainOnce(
        ownerUserID: String,
        limit: Int,
        fetchScanLimit: Int?
    ) async throws -> SyncEventOutboxDrainOutcome {
        drainCalls.append((ownerUserID, limit, fetchScanLimit))
        guard !drainResults.isEmpty else {
            return SyncEventOutboxDrainOutcome(status: .noWork)
        }
        return try drainResults.removeFirst().get()
    }
}

@MainActor
private final class BlockingDrainDebugDependencies {
    private var fetchResults: [Result<SyncEventOutboxCounts, Error>]
    private let drainOutcome: SyncEventOutboxDrainOutcome
    private var drainContinuation: CheckedContinuation<SyncEventOutboxDrainOutcome, Error>?
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private(set) var drainCalls: [(ownerUserID: String, limit: Int, fetchScanLimit: Int?)] = []

    init(
        fetchResults: [Result<SyncEventOutboxCounts, Error>],
        drainOutcome: SyncEventOutboxDrainOutcome
    ) {
        self.fetchResults = fetchResults
        self.drainOutcome = drainOutcome
    }

    func fetchCounts(ownerUserID: String, now: Date) async throws -> SyncEventOutboxCounts {
        guard !fetchResults.isEmpty else { return SyncEventOutboxCounts() }
        return try fetchResults.removeFirst().get()
    }

    func drainOnce(
        ownerUserID: String,
        limit: Int,
        fetchScanLimit: Int?
    ) async throws -> SyncEventOutboxDrainOutcome {
        drainCalls.append((ownerUserID, limit, fetchScanLimit))
        waiters.forEach { $0.resume() }
        waiters.removeAll()

        return try await withCheckedThrowingContinuation { continuation in
            drainContinuation = continuation
        }
    }

    func waitForDrainCallCount(_ expectedCount: Int) async throws {
        guard drainCalls.count < expectedCount else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func finishDrain() {
        drainContinuation?.resume(returning: drainOutcome)
        drainContinuation = nil
    }
}
#endif
