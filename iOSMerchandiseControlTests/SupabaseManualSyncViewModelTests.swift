import XCTest
@testable import iOSMerchandiseControl

// MARK: - Test doubles

@MainActor
final class SupabaseManualSyncCoordinatingInvocationCounter: SupabaseManualSyncCoordinating {
    private let inner: SupabaseManualSyncCoordinator
    private(set) var runInvocationCount = 0

    init(inner: SupabaseManualSyncCoordinator) {
        self.inner = inner
    }

    func run(mode: SupabaseManualSyncRunMode, sessionID: UUID) async -> SupabaseManualSyncRunSummary {
        runInvocationCount += 1
        return await inner.run(mode: mode, sessionID: sessionID)
    }
}

@MainActor
final class ClosureSupabaseManualSyncCoordinatorFake: SupabaseManualSyncCoordinating {
    var handler: (@MainActor (_ mode: SupabaseManualSyncRunMode, _ sessionID: UUID) async -> SupabaseManualSyncRunSummary)?

    func run(mode: SupabaseManualSyncRunMode, sessionID: UUID) async -> SupabaseManualSyncRunSummary {
        guard let handler else {
            preconditionFailure("ClosureSupabaseManualSyncCoordinatorFake: handler not wired")
        }
        return await handler(mode, sessionID)
    }
}

@MainActor
final class SupabaseManualSyncViewModelTests: XCTestCase {
    private func repoRootURL() -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func assertNoForbiddenUserFacingJargon(_ vm: SupabaseManualSyncViewModel, file: StaticString = #filePath, line: UInt = #line) {
        let blob = [vm.title, vm.subtitle, vm.primaryActionTitle, vm.lastUserMessage]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        let forbidden = ["outbox", "drain", "sync_events", "rpc", "record_sync_event", "payload", "retryable"]
        for word in forbidden {
            XCTAssertFalse(blob.contains(word), "Unexpected jargon fragment \(word)", file: file, line: line)
        }
    }

    func testInitialStateIdleReadyPrivacySafeTitles() async {
        await Task.yield()
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        let vm = SupabaseManualSyncViewModel(coordinator: fake)

        XCTAssertEqual(vm.presentationKind, .idleReady)
        XCTAssertFalse(vm.isRunning)
        XCTAssertTrue(vm.canStart)
        XCTAssertNil(vm.lastSummary)
        XCTAssertFalse(vm.pendingConfirmation)
        XCTAssertFalse(vm.shouldShowConfirmation)

        XCTAssertEqual(vm.primaryActionTitle, "Avvia sincronizzazione")
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testStartWhileRunningIgnoresDuplicateCoordinatorRuns() async throws {
        let dryFake = SupabaseManualSyncCoordinatorDryRunFake()
        dryFake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)
        dryFake.holdAtPreviewUntilSignaled = true

        let inner = SupabaseManualSyncCoordinator(
            dependencies: .init(
                authGate: dryFake,
                baselineGate: dryFake,
                pendingSnapshot: dryFake,
                phaseSimulation: dryFake
            )
        )

        let counter = SupabaseManualSyncCoordinatingInvocationCounter(inner: inner)
        let vm = SupabaseManualSyncViewModel(coordinator: counter)

        let finished = XCTestExpectation(description: "first-run")

        Task {
            await vm.startDryRunVerification()
            finished.fulfill()
        }

        try await dryFake.waitUntilPreviewHoldEngaged()

        XCTAssertFalse(vm.canStart)

        await vm.startDryRunVerification()

        XCTAssertEqual(counter.runInvocationCount, 1)

        dryFake.releasePreviewHold()

        await fulfillment(of: [finished], timeout: 15)

        XCTAssertEqual(counter.runInvocationCount, 1)
        XCTAssertEqual(vm.presentationKind, .successFullyUpToDate)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.allUpToDate)
        XCTAssertEqual(vm.subtitle, SupabaseManualSyncUserFacingCopy.syncFinishedSuccessfully)
        XCTAssertTrue(vm.canStart)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testDryRunCompletesShowsAllUpToDateHeadlineIncludingCompletedSuccessfullySubtitle() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 2, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)

        let coordinator = SupabaseManualSyncCoordinator(
            dependencies: .init(
                authGate: fake,
                baselineGate: fake,
                pendingSnapshot: fake,
                phaseSimulation: fake
            )
        )

        let vm = SupabaseManualSyncViewModel(coordinator: coordinator)
        await vm.startDryRunVerification()

        XCTAssertEqual(vm.presentationKind, .successFullyUpToDate)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.allUpToDate)
        XCTAssertEqual(vm.lastSummary?.finalState, .completedSuccessfully)
        XCTAssertEqual(vm.subtitle, SupabaseManualSyncUserFacingCopy.syncFinishedSuccessfully)
        XCTAssertFalse(vm.presentationKind == .cancelledRun)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testPartialOutcomeDoesNotAppearAsSuccessPresentation() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            SupabaseManualSyncRunSummary(
                finalState: .partialSync,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.partialSync,
                executedPhases: [],
                skippedPhases: [],
                countsSnapshot: .init(),
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.partialSuggestion,
                detailMessage: nil
            )
        }

        let vm = SupabaseManualSyncViewModel(coordinator: fake)
        await vm.start(with: .dryRun)

        XCTAssertEqual(vm.presentationKind, .partialSync)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.partialSync)
        XCTAssertNotEqual(vm.presentationKind, .successFullyUpToDate)
        XCTAssertEqual(vm.primaryActionTitle, "Riprova")
        XCTAssertEqual(vm.lastSummary?.finalState, .partialSync)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testAuthBlockedMessaging() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            SupabaseManualSyncRunSummary(
                finalState: .blocked,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.signInAgain,
                executedPhases: [.authCheck],
                skippedPhases: [],
                countsSnapshot: .init(),
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.signInAgain,
                detailMessage: nil
            )
        }

        let vm = SupabaseManualSyncViewModel(coordinator: fake)
        await vm.start(with: .dryRun)

        XCTAssertEqual(vm.presentationKind, .blockedNeedsSignIn)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.signInAgain)
        XCTAssertEqual(vm.subtitle, "Accedi di nuovo per continuare.")
        XCTAssertEqual(vm.primaryActionTitle, "Accedi")
        XCTAssertNotEqual(vm.presentationKind, .successFullyUpToDate)
        XCTAssertEqual(vm.lastSummary?.finalState, .blocked)
        XCTAssertFalse(vm.lastUserMessage.contains("\(SupabaseManualSyncUserFacingCopy.signInAgain) \(SupabaseManualSyncUserFacingCopy.signInAgain)"))
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testBaselineBlockedMessaging() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            SupabaseManualSyncRunSummary(
                finalState: .blocked,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.realignFromCloud,
                executedPhases: [.baselineCheck],
                skippedPhases: [],
                countsSnapshot: .init(),
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.realignFromCloud,
                detailMessage: nil
            )
        }

        let vm = SupabaseManualSyncViewModel(coordinator: fake)
        await vm.start(with: .dryRun)

        XCTAssertEqual(vm.presentationKind, .blockedNeedsCloudRealignment)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.realignFromCloud)
        XCTAssertEqual(vm.subtitle, "Prima aggiorna i dati dal cloud, poi riprova.")
        XCTAssertEqual(vm.primaryActionTitle, "Riallinea dati")
        XCTAssertNotEqual(vm.presentationKind, .successFullyUpToDate)
        XCTAssertFalse(vm.lastUserMessage.contains("\(SupabaseManualSyncUserFacingCopy.realignFromCloud) \(SupabaseManualSyncUserFacingCopy.realignFromCloud)"))
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testCoordinatorBusyStateAllowsRetryAndAvoidsDuplicateCopy() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            SupabaseManualSyncRunSummary(
                finalState: .concurrentRunNotAllowed,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.alreadyRunning,
                executedPhases: [],
                skippedPhases: SupabaseManualSyncPhase.allCases,
                countsSnapshot: .init(),
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.alreadyRunning,
                detailMessage: nil
            )
        }

        let vm = SupabaseManualSyncViewModel(coordinator: fake)
        await vm.start(with: .dryRun)

        XCTAssertEqual(vm.presentationKind, .auxiliaryBusyConcurrent)
        XCTAssertTrue(vm.cannotStartConcurrently)
        XCTAssertFalse(vm.isRunning)
        XCTAssertTrue(vm.canStart)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.alreadyRunning)
        XCTAssertEqual(vm.subtitle, "Attendi che termini prima di riprovare.")
        XCTAssertEqual(vm.primaryActionTitle, "Riprova")
        XCTAssertFalse(vm.lastUserMessage.contains("\(SupabaseManualSyncUserFacingCopy.alreadyRunning) \(SupabaseManualSyncUserFacingCopy.alreadyRunning)"))
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testConnectivityMessaging() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            SupabaseManualSyncRunSummary(
                finalState: .connectivityIssue,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.connectivityRetry,
                executedPhases: [],
                skippedPhases: [],
                countsSnapshot: .init(),
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.retryConnectivitySuggestion,
                detailMessage: nil
            )
        }

        let vm = SupabaseManualSyncViewModel(coordinator: fake)
        await vm.start(with: .dryRun)

        XCTAssertEqual(vm.presentationKind, .connectivityIssue)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.connectivityRetry)
        XCTAssertNotEqual(vm.presentationKind, .partialSync)
        XCTAssertFalse(vm.presentationKind == .successFullyUpToDate)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testCancellationMessagingNeverSuccessPresentation() async throws {
        let coordinatorFake = SupabaseManualSyncCoordinatorDryRunFake()
        coordinatorFake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)
        coordinatorFake.delayPreviewNanoseconds = 200_000_000

        let coordinator = SupabaseManualSyncCoordinator(
            dependencies: .init(
                authGate: coordinatorFake,
                baselineGate: coordinatorFake,
                pendingSnapshot: coordinatorFake,
                phaseSimulation: coordinatorFake
            )
        )

        let vm = SupabaseManualSyncViewModel(coordinator: coordinator)

        let run = Task { await vm.startDryRunVerification() }
        try await Task.sleep(for: .milliseconds(25))
        run.cancel()

        await run.value

        XCTAssertEqual(vm.presentationKind, .cancelledRun)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.cancelled)
        XCTAssertFalse(vm.presentationKind == .successFullyUpToDate)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testTechnicalReviewSoftCopyOverridesUnexpectedCoordinatorHeadline() async {
        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            SupabaseManualSyncRunSummary(
                finalState: .technicalReviewNeeded,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.unexpected,
                executedPhases: [],
                skippedPhases: [],
                countsSnapshot: .init(),
                suggestedNextStep: nil,
                detailMessage: nil
            )
        }

        let vm = SupabaseManualSyncViewModel(coordinator: fake)
        await vm.start(with: .dryRun)

        XCTAssertEqual(vm.presentationKind, .technicalFollowUpNeeded)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.technicalFollowUp)
        XCTAssertNotEqual(vm.title, SupabaseManualSyncUserFacingCopy.unexpected)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testZeroPendingDryRunLeavesAllUpToDateHeadlineWithoutPartialMasking() async {
        let dryFake = SupabaseManualSyncCoordinatorDryRunFake()
        dryFake.snapshot = SupabaseManualSyncPrivacyCounts()

        let coordinator = SupabaseManualSyncCoordinator(
            dependencies: .init(
                authGate: dryFake,
                baselineGate: dryFake,
                pendingSnapshot: dryFake,
                phaseSimulation: dryFake
            )
        )

        let vm = SupabaseManualSyncViewModel(coordinator: coordinator)
        await vm.startDryRunVerification()

        XCTAssertEqual(vm.presentationKind, .successFullyUpToDate)
        XCTAssertEqual(vm.title, SupabaseManualSyncUserFacingCopy.allUpToDate)
        XCTAssertFalse(vm.presentationKind == .partialSync)
        XCTAssertEqual(vm.lastSummary?.finalState, .allUpToDate)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testPrivacySafeAggregateSnapshotCopiedFromSummary() async {
        let counts = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 2, pendingPriceChangeCount: 1, pendingQueuedCloudOperationCount: 4)

        let fake = ClosureSupabaseManualSyncCoordinatorFake()
        fake.handler = { _, _ in
            SupabaseManualSyncRunSummary(
                finalState: .connectivityIssue,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.connectivityRetry,
                executedPhases: [.authCheck],
                skippedPhases: [],
                countsSnapshot: counts,
                suggestedNextStep: SupabaseManualSyncUserFacingCopy.retryConnectivitySuggestion,
                detailMessage: nil
            )
        }

        let vm = SupabaseManualSyncViewModel(coordinator: fake)
        await vm.start(with: .dryRun)

        XCTAssertEqual(vm.privacySafeAggregatesSnapshot, counts)
        assertNoForbiddenUserFacingJargon(vm)
    }

    func testViewModelSourcesAvoidForbiddenScopeTerms() throws {
        let root = repoRootURL()
        let urls = [
            root.appendingPathComponent("iOSMerchandiseControl/SupabaseManualSyncViewModel.swift"),
            root.appendingPathComponent("iOSMerchandiseControl/SupabaseManualSyncCoordinating.swift"),
        ]
        for url in urls {
            let text = try String(contentsOf: url, encoding: .utf8).lowercased()
            XCTAssertFalse(text.contains("supabaseclient"))
            XCTAssertFalse(text.contains("bgtask"))
            XCTAssertFalse(text.contains("timer("))
            XCTAssertFalse(text.contains("realtime"))
            XCTAssertFalse(text.contains(".rpc"))
            XCTAssertFalse(text.contains(".channel"))
            XCTAssertFalse(text.contains("optionsview"))
            XCTAssertFalse(text.contains("task-067"))
        }
    }
}
