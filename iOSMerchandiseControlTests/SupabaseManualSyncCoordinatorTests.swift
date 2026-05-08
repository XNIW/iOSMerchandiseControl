import XCTest
@testable import iOSMerchandiseControl

enum SupabaseManualSyncCoordinatorFakeCall: Equatable {
    case authGate
    case baselineGate
    case pendingSnapshot
    case remotePreview
    case catalogPush
    case productPricePush
    case queuedCloudOperationsFlush
    case finalRefresh
}

@MainActor
final class SupabaseManualSyncCoordinatorTests: XCTestCase {
    private func repoRootURL() -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func assertNoForbiddenUserFacingJargon(_ summary: SupabaseManualSyncRunSummary, file: StaticString = #filePath, line: UInt = #line) {
        let blob = [summary.userFacingHeadline, summary.suggestedNextStep, summary.detailMessage]
            .compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
        let forbidden = ["outbox", "drain", "sync_events", "rpc", "record_sync_event", "payload", "retryable"]
        for word in forbidden {
            XCTAssertFalse(blob.contains(word), "Unexpected jargon fragment \(word)", file: file, line: line)
        }
        XCTAssertFalse(blob.contains("barcode"), file: file, line: line)
        XCTAssertFalse(blob.contains("entity_ids"), file: file, line: line)
        XCTAssertFalse(blob.contains("token"), file: file, line: line)
        XCTAssertFalse(blob.contains("email"), file: file, line: line)
        XCTAssertFalse(blob.contains("http://"), file: file, line: line)
        XCTAssertFalse(blob.contains("https://"), file: file, line: line)
    }

    private func makeCoordinator(fake: SupabaseManualSyncCoordinatorDryRunFake) -> SupabaseManualSyncCoordinator {
        SupabaseManualSyncCoordinator(
            dependencies: .init(
                authGate: fake,
                baselineGate: fake,
                pendingSnapshot: fake,
                phaseSimulation: fake
            )
        )
    }

    func testDryRunWithoutAuthBlocksWithoutPushOrFlush() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.authResult = .sessionExpiredOrSignedOut
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 5, pendingPriceChangeCount: 3, pendingQueuedCloudOperationCount: 2)
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertEqual(summary.finalState, .blocked)
        XCTAssertEqual(summary.userFacingHeadline, SupabaseManualSyncUserFacingCopy.signInAgain)
        XCTAssertFalse(summary.executedPhases.contains(.catalogPush))
        XCTAssertFalse(summary.executedPhases.contains(.productPricePush))
        XCTAssertFalse(summary.executedPhases.contains(.pendingEventsFlush))
        XCTAssertEqual(fake.calls, [.authGate])
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testDryRunBaselineMissingBlocks() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.baselineResult = .missingOrInvalid
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertEqual(summary.finalState, .blocked)
        XCTAssertEqual(summary.userFacingHeadline, SupabaseManualSyncUserFacingCopy.realignFromCloud)
        XCTAssertFalse(summary.executedPhases.contains(.catalogPush))
        XCTAssertEqual(fake.calls, [.authGate, .baselineGate])
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testDryRunZeroPendingAllUpToDateSkipsPushConfirmationFlushPath() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts()
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertEqual(summary.finalState, .allUpToDate)
        XCTAssertEqual(summary.userFacingHeadline, SupabaseManualSyncUserFacingCopy.allUpToDate)
        XCTAssertTrue(summary.skippedPhases.contains(.userConfirmation))
        XCTAssertTrue(summary.skippedPhases.contains(.catalogPush))
        XCTAssertTrue(summary.skippedPhases.contains(.productPricePush))
        XCTAssertTrue(summary.skippedPhases.contains(.pendingEventsFlush))
        XCTAssertEqual(summary.executedPhases, [.authCheck, .baselineCheck, .localPendingCheck, .summary])
        XCTAssertEqual(fake.calls, [.authGate, .baselineGate, .pendingSnapshot])
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testDryRunCatalogPendingOnlyPlansCatalogPush() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 2, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertTrue(summary.executedPhases.contains(.catalogPush))
        XCTAssertTrue(summary.skippedPhases.contains(.productPricePush))
        XCTAssertTrue(summary.skippedPhases.contains(.pendingEventsFlush))
        XCTAssertEqual(summary.finalState, .completedSuccessfully)
        XCTAssertEqual(fake.calls, [.authGate, .baselineGate, .pendingSnapshot, .remotePreview, .catalogPush, .finalRefresh])
        XCTAssertNil(summary.remotePreviewSummary)
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testTask071RemotePreviewProviderNilPreservesTask069DryRunPath() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertEqual(summary.finalState, .completedSuccessfully)
        XCTAssertEqual(summary.executedPhases, [.authCheck, .baselineCheck, .localPendingCheck, .remotePreview, .userConfirmation, .catalogPush, .finalRefresh, .summary])
        XCTAssertEqual(fake.calls, [.authGate, .baselineGate, .pendingSnapshot, .remotePreview, .catalogPush, .finalRefresh])
        XCTAssertNil(summary.remotePreviewSummary)
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testTask071FakeRemotePreviewProviderRunsPreviewOnlyWithoutDownstreamPhases() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 1, pendingQueuedCloudOperationCount: 1)
        fake.remotePreviewSummary = SupabaseManualSyncRemotePreviewSummary(
            hasRemoteSignals: true,
            isComplete: true,
            isPartial: false,
            wasCancelled: false,
            safeAggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts(newProductCount: 2),
            recommendedUserMessageKey: .cloudDataNeedsReview,
            failureCategory: nil
        )
        let coordinator = SupabaseManualSyncCoordinator(
            dependencies: .init(
                authGate: fake,
                baselineGate: fake,
                pendingSnapshot: fake,
                phaseSimulation: fake,
                remotePreviewProvider: fake
            )
        )

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertEqual(summary.remotePreviewSummary, fake.remotePreviewSummary)
        XCTAssertEqual(summary.executedPhases, [.authCheck, .baselineCheck, .localPendingCheck, .remotePreview, .summary])
        XCTAssertTrue(summary.skippedPhases.contains(.userConfirmation))
        XCTAssertTrue(summary.skippedPhases.contains(.catalogPush))
        XCTAssertTrue(summary.skippedPhases.contains(.productPricePush))
        XCTAssertTrue(summary.skippedPhases.contains(.pendingEventsFlush))
        XCTAssertTrue(summary.skippedPhases.contains(.finalRefresh))
        XCTAssertEqual(fake.calls, [.authGate, .baselineGate, .pendingSnapshot, .remotePreview])
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testTask071CompleteRemotePreviewWithoutSignalsDoesNotPromiseCloudIsUpdated() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)
        fake.remotePreviewSummary = SupabaseManualSyncRemotePreviewSummary(
            hasRemoteSignals: false,
            isComplete: true,
            isPartial: false,
            wasCancelled: false,
            safeAggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts(),
            recommendedUserMessageKey: .cloudCheckCompleteNoAction,
            failureCategory: nil
        )
        let coordinator = SupabaseManualSyncCoordinator(
            dependencies: .init(
                authGate: fake,
                baselineGate: fake,
                pendingSnapshot: fake,
                phaseSimulation: fake,
                remotePreviewProvider: fake
            )
        )

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertEqual(summary.finalState, .completedSuccessfully)
        XCTAssertEqual(summary.userFacingHeadline, SupabaseManualSyncUserFacingCopy.cloudCheckNoAction)
        XCTAssertNotEqual(summary.userFacingHeadline, SupabaseManualSyncUserFacingCopy.allUpToDate)
        XCTAssertEqual(summary.executedPhases, [.authCheck, .baselineCheck, .localPendingCheck, .remotePreview, .summary])
        XCTAssertEqual(fake.calls, [.authGate, .baselineGate, .pendingSnapshot, .remotePreview])
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testTask071PartialRemotePreviewProviderDoesNotBecomeSyncCompleted() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)
        fake.remotePreviewSummary = SupabaseManualSyncRemotePreviewSummary(
            hasRemoteSignals: false,
            isComplete: false,
            isPartial: true,
            wasCancelled: false,
            safeAggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts(sourceErrorCount: 1),
            recommendedUserMessageKey: .cloudCheckIncomplete,
            failureCategory: nil
        )
        let coordinator = SupabaseManualSyncCoordinator(
            dependencies: .init(
                authGate: fake,
                baselineGate: fake,
                pendingSnapshot: fake,
                phaseSimulation: fake,
                remotePreviewProvider: fake
            )
        )

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertEqual(summary.remotePreviewSummary?.recommendedUserMessageKey, .cloudCheckIncomplete)
        XCTAssertNotEqual(summary.finalState, .completedSuccessfully)
        XCTAssertNotEqual(summary.finalState, .allUpToDate)
        XCTAssertFalse(summary.executedPhases.contains(.catalogPush))
        XCTAssertFalse(summary.executedPhases.contains(.productPricePush))
        XCTAssertFalse(summary.executedPhases.contains(.pendingEventsFlush))
        XCTAssertEqual(fake.calls, [.authGate, .baselineGate, .pendingSnapshot, .remotePreview])
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testTask071CancelledRemotePreviewProviderNeverMapsToSuccess() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)
        fake.remotePreviewSummary = SupabaseManualSyncRemotePreviewOutcomeMapper.cancelledSummary()
        let coordinator = SupabaseManualSyncCoordinator(
            dependencies: .init(
                authGate: fake,
                baselineGate: fake,
                pendingSnapshot: fake,
                phaseSimulation: fake,
                remotePreviewProvider: fake
            )
        )

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertEqual(summary.finalState, .cancelled)
        XCTAssertEqual(summary.remotePreviewSummary?.recommendedUserMessageKey, .cloudCheckCancelled)
        XCTAssertNotEqual(summary.finalState, .completedSuccessfully)
        XCTAssertNotEqual(summary.finalState, .allUpToDate)
        XCTAssertEqual(fake.calls, [.authGate, .baselineGate, .pendingSnapshot, .remotePreview])
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testDryRunProductPricePendingOnlyPlansPricePush() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 0, pendingPriceChangeCount: 4, pendingQueuedCloudOperationCount: 0)
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertTrue(summary.skippedPhases.contains(.catalogPush))
        XCTAssertTrue(summary.executedPhases.contains(.productPricePush))
        XCTAssertTrue(summary.skippedPhases.contains(.pendingEventsFlush))
        XCTAssertEqual(fake.calls, [.authGate, .baselineGate, .pendingSnapshot, .remotePreview, .productPricePush, .finalRefresh])
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testDryRunQueuedCloudOperationsOnlyPlansFlushPhase() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 0, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 3)
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertTrue(summary.skippedPhases.contains(.catalogPush))
        XCTAssertTrue(summary.skippedPhases.contains(.productPricePush))
        XCTAssertTrue(summary.executedPhases.contains(.pendingEventsFlush))
        XCTAssertEqual(fake.calls, [.authGate, .baselineGate, .pendingSnapshot, .remotePreview, .queuedCloudOperationsFlush, .finalRefresh])
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testDryRunFullPendingPreservesPhaseOrdering() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 1, pendingQueuedCloudOperationCount: 1)
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .dryRun)

        let expectedPrefix: [SupabaseManualSyncPhase] = [
            .authCheck,
            .baselineCheck,
            .localPendingCheck,
            .remotePreview,
            .userConfirmation,
            .catalogPush,
            .productPricePush,
            .pendingEventsFlush,
            .finalRefresh,
            .summary,
        ]
        XCTAssertEqual(summary.executedPhases, expectedPrefix)
        XCTAssertEqual(fake.calls.filter { $0 == .baselineGate }.count, 1)
        XCTAssertEqual(fake.calls.filter { $0 == .pendingSnapshot }.count, 1)
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testRemotePreviewRetryableStopsBeforeConfirmationOrMutationPhases() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 1, pendingQueuedCloudOperationCount: 1)
        fake.previewOutcome = .failedRetryable
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertEqual(summary.finalState, .connectivityIssue)
        XCTAssertFalse(summary.executedPhases.contains(.userConfirmation))
        XCTAssertFalse(summary.executedPhases.contains(.catalogPush))
        XCTAssertFalse(summary.executedPhases.contains(.productPricePush))
        XCTAssertFalse(summary.executedPhases.contains(.pendingEventsFlush))
        XCTAssertFalse(summary.executedPhases.contains(.finalRefresh))
        XCTAssertEqual(fake.calls, [.authGate, .baselineGate, .pendingSnapshot, .remotePreview])
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testPartialCatalogOkProductPriceRetryable() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 1, pendingQueuedCloudOperationCount: 0)
        fake.catalogOutcome = .completed
        fake.priceOutcome = .failedRetryable
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertEqual(summary.finalState, .partialSync)
        XCTAssertEqual(summary.userFacingHeadline, SupabaseManualSyncUserFacingCopy.partialSync)
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testPartialMutationsOkFlushFailsRetryable() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 2)
        fake.catalogOutcome = .completed
        fake.flushOutcome = .failedRetryable
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertEqual(summary.finalState, .partialSync)
        XCTAssertEqual(summary.userFacingHeadline, SupabaseManualSyncUserFacingCopy.partialSync)
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testCatalogRetryableWithoutPriorSuccessIsConnectivityNotPartial() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)
        fake.catalogOutcome = .failedRetryable
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertEqual(summary.finalState, .connectivityIssue)
        XCTAssertEqual(summary.userFacingHeadline, SupabaseManualSyncUserFacingCopy.connectivityRetry)
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testFlushRetryableWithoutPriorMutationSuccessIsConnectivityNotPartial() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 0, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 2)
        fake.flushOutcome = .failedRetryable
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertEqual(summary.finalState, .connectivityIssue)
        XCTAssertEqual(summary.userFacingHeadline, SupabaseManualSyncUserFacingCopy.connectivityRetry)
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testNonRetryableMutationFailureUsesSoftTechnicalCopyWithoutJargon() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)
        fake.catalogOutcome = .failedNonRetryable
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertEqual(summary.finalState, .technicalReviewNeeded)
        XCTAssertEqual(summary.userFacingHeadline, SupabaseManualSyncUserFacingCopy.technicalFollowUp)
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testCancellationBeforeFirstCheckpointReturnsCancelled() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        let coordinator = makeCoordinator(fake: fake)

        let task = Task {
            await coordinator.run(mode: .dryRun)
        }
        task.cancel()

        let summary = await task.value

        XCTAssertEqual(summary.finalState, .cancelled)
        XCTAssertEqual(summary.userFacingHeadline, SupabaseManualSyncUserFacingCopy.cancelled)
        XCTAssertFalse(summary.finalState == .completedSuccessfully)
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testCancellationDuringIntermediatePhase() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)
        fake.delayPreviewNanoseconds = 200_000_000
        let coordinator = makeCoordinator(fake: fake)

        let task = Task {
            await coordinator.run(mode: .dryRun)
        }

        try? await Task.sleep(nanoseconds: 20_000_000)
        task.cancel()

        let summary = await task.value

        XCTAssertEqual(summary.finalState, .cancelled)
        XCTAssertNotEqual(summary.finalState, .completedSuccessfully)
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testConcurrentRunsSecondIsBlockedBusy() async throws {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 1, pendingPriceChangeCount: 0, pendingQueuedCloudOperationCount: 0)
        fake.holdAtPreviewUntilSignaled = true
        let coordinator = makeCoordinator(fake: fake)

        let sessionA = UUID()
        let sessionB = UUID()

        let first = Task {
            await coordinator.run(mode: .dryRun, sessionID: sessionA)
        }

        try await fake.waitUntilPreviewHoldEngaged()

        let second = await coordinator.run(mode: .dryRun, sessionID: sessionB)

        XCTAssertEqual(second.finalState, .concurrentRunNotAllowed)
        XCTAssertEqual(second.userFacingHeadline, SupabaseManualSyncUserFacingCopy.alreadyRunning)

        fake.releasePreviewHold()

        let firstSummary = await first.value
        XCTAssertEqual(firstSummary.finalState, .completedSuccessfully)

        assertNoForbiddenUserFacingJargon(second)
        assertNoForbiddenUserFacingJargon(firstSummary)
    }

    func testAutomaticModeBlockedOutOfScope() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .automatic)

        XCTAssertEqual(summary.finalState, .modeNotSupportedInThisSlice)
        XCTAssertEqual(summary.userFacingHeadline, SupabaseManualSyncUserFacingCopy.automaticUnavailable)
        XCTAssertTrue(summary.executedPhases.isEmpty)
        XCTAssertTrue(fake.calls.isEmpty)
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testGuidedManualAndDebugDiagnosticsAreBlockedWithoutDependencyCalls() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        let coordinator = makeCoordinator(fake: fake)

        let guidedSummary = await coordinator.run(mode: .guidedManual)
        let debugSummary = await coordinator.run(mode: .debugDiagnostics)

        XCTAssertEqual(guidedSummary.finalState, .modeNotSupportedInThisSlice)
        XCTAssertEqual(debugSummary.finalState, .modeNotSupportedInThisSlice)
        XCTAssertTrue(guidedSummary.executedPhases.isEmpty)
        XCTAssertTrue(debugSummary.executedPhases.isEmpty)
        XCTAssertTrue(fake.calls.isEmpty)
        assertNoForbiddenUserFacingJargon(guidedSummary)
        assertNoForbiddenUserFacingJargon(debugSummary)
    }

    func testPrivacySummaryContainsOnlyAggregateCountsAndNoDetailStrings() async {
        let fake = SupabaseManualSyncCoordinatorDryRunFake()
        fake.snapshot = SupabaseManualSyncPrivacyCounts(pendingCatalogChangeCount: 12, pendingPriceChangeCount: 7, pendingQueuedCloudOperationCount: 3)
        let coordinator = makeCoordinator(fake: fake)

        let summary = await coordinator.run(mode: .dryRun)

        XCTAssertEqual(summary.countsSnapshot, fake.snapshot)
        XCTAssertNil(summary.detailMessage)
        assertNoForbiddenUserFacingJargon(summary)
    }

    func testCoordinatorSwiftSourcesAvoidDirectSupabaseClientAndRpc() throws {
        let root = repoRootURL()
        let paths = [
            root.appendingPathComponent("iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift"),
            root.appendingPathComponent("iOSMerchandiseControl/SupabaseManualSyncCoordinatorModels.swift"),
            root.appendingPathComponent("iOSMerchandiseControl/SupabaseManualSyncCoordinating.swift"),
        ]
        for url in paths {
            let text = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(text.contains("SupabaseClient"))
            XCTAssertFalse(text.contains(".rpc"))
            XCTAssertFalse(text.contains(".from"))
            XCTAssertFalse(text.contains(".upsert"))
            XCTAssertFalse(text.contains(".channel"))
            XCTAssertFalse(text.contains("Realtime"))
            XCTAssertFalse(text.contains("BGTask"))
            XCTAssertFalse(text.contains("Timer"))
            XCTAssertFalse(text.contains("OptionsView"))
        }
    }
}

// MARK: - Test fake

@MainActor
final class SupabaseManualSyncCoordinatorDryRunFake: SupabaseManualSyncAuthGateProviding,
    SupabaseManualSyncBaselineGateProviding,
    SupabaseManualSyncLocalPendingProviding,
    SupabaseManualSyncDryRunPhaseSimulating,
    SupabaseManualSyncRemotePreviewProviding
{
    var authResult: SupabaseManualSyncAuthGateResult = .authenticated
    var baselineResult: SupabaseManualSyncBaselineGateResult = .valid
    var snapshot: SupabaseManualSyncPrivacyCounts = .init()

    var previewOutcome: SupabaseManualSyncPhaseOutcome = .completed
    var catalogOutcome: SupabaseManualSyncPhaseOutcome = .completed
    var priceOutcome: SupabaseManualSyncPhaseOutcome = .completed
    var flushOutcome: SupabaseManualSyncPhaseOutcome = .completed
    var refreshOutcome: SupabaseManualSyncPhaseOutcome = .completed
    var remotePreviewSummary: SupabaseManualSyncRemotePreviewSummary?

    var delayPreviewNanoseconds: UInt64 = 0
    var holdAtPreviewUntilSignaled = false
    private(set) var calls: [SupabaseManualSyncCoordinatorFakeCall] = []
    private var previewHold: CheckedContinuation<Void, Never>?
    private var previewHoldEngaged = false

    func evaluateAuthGate() async throws -> SupabaseManualSyncAuthGateResult {
        calls.append(.authGate)
        return authResult
    }

    func evaluateBaselineGate() async throws -> SupabaseManualSyncBaselineGateResult {
        calls.append(.baselineGate)
        return baselineResult
    }

    func loadLocalPendingSnapshot() async throws -> SupabaseManualSyncPrivacyCounts {
        calls.append(.pendingSnapshot)
        return snapshot
    }

    func simulateRemotePreview(counts: SupabaseManualSyncPrivacyCounts) async throws -> SupabaseManualSyncPhaseOutcome {
        calls.append(.remotePreview)
        _ = counts
        try await waitOrDelayRemotePreviewIfNeeded()
        return previewOutcome
    }

    func loadRemotePreviewSummary() async -> SupabaseManualSyncRemotePreviewSummary {
        calls.append(.remotePreview)
        do {
            try await waitOrDelayRemotePreviewIfNeeded()
        } catch is CancellationError {
            return SupabaseManualSyncRemotePreviewOutcomeMapper.cancelledSummary()
        } catch {
            return SupabaseManualSyncRemotePreviewSummary(
                hasRemoteSignals: false,
                isComplete: false,
                isPartial: false,
                wasCancelled: false,
                safeAggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts(),
                recommendedUserMessageKey: .cloudCheckFailedTechnical,
                failureCategory: .unknown
            )
        }
        if let remotePreviewSummary {
            return remotePreviewSummary
        }
        switch previewOutcome {
        case .completed:
            return SupabaseManualSyncRemotePreviewSummary(
                hasRemoteSignals: false,
                isComplete: true,
                isPartial: false,
                wasCancelled: false,
                safeAggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts(),
                recommendedUserMessageKey: .cloudCheckCompleteNoAction,
                failureCategory: nil
            )
        case .partial:
            return SupabaseManualSyncRemotePreviewSummary(
                hasRemoteSignals: false,
                isComplete: false,
                isPartial: true,
                wasCancelled: false,
                safeAggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts(sourceErrorCount: 1),
                recommendedUserMessageKey: .cloudCheckIncomplete,
                failureCategory: nil
            )
        case .failedRetryable:
            return SupabaseManualSyncRemotePreviewSummary(
                hasRemoteSignals: false,
                isComplete: false,
                isPartial: false,
                wasCancelled: false,
                safeAggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts(),
                recommendedUserMessageKey: .cloudCheckFailedRetry,
                failureCategory: .network
            )
        case .blocked:
            return SupabaseManualSyncRemotePreviewSummary(
                hasRemoteSignals: false,
                isComplete: false,
                isPartial: false,
                wasCancelled: false,
                safeAggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts(),
                recommendedUserMessageKey: .cloudCheckFailedPermission,
                failureCategory: .permission
            )
        case .failedNonRetryable:
            return SupabaseManualSyncRemotePreviewSummary(
                hasRemoteSignals: false,
                isComplete: false,
                isPartial: false,
                wasCancelled: false,
                safeAggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts(),
                recommendedUserMessageKey: .cloudCheckFailedTechnical,
                failureCategory: .unknown
            )
        case .cancelled:
            return SupabaseManualSyncRemotePreviewOutcomeMapper.cancelledSummary()
        case .skippedNoWork:
            return SupabaseManualSyncRemotePreviewSummary(
                hasRemoteSignals: false,
                isComplete: true,
                isPartial: false,
                wasCancelled: false,
                safeAggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts(),
                recommendedUserMessageKey: .cloudCheckCompleteNoAction,
                failureCategory: nil
            )
        }
    }

    private func waitOrDelayRemotePreviewIfNeeded() async throws {
        if holdAtPreviewUntilSignaled {
            previewHoldEngaged = true
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                self.previewHold = continuation
            }
        }
        if delayPreviewNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayPreviewNanoseconds)
        }
        try Task.checkCancellation()
    }

    func waitUntilPreviewHoldEngaged() async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !previewHoldEngaged {
            guard ContinuousClock.now < deadline else {
                throw NSError(domain: "SupabaseManualSyncCoordinatorTests", code: 1)
            }
            await Task.yield()
        }
    }

    func releasePreviewHold() {
        previewHold?.resume()
        previewHold = nil
    }

    func simulateCatalogPushPhase() async throws -> SupabaseManualSyncPhaseOutcome {
        calls.append(.catalogPush)
        return catalogOutcome
    }

    func simulateProductPricePushPhase() async throws -> SupabaseManualSyncPhaseOutcome {
        calls.append(.productPricePush)
        return priceOutcome
    }

    func simulateQueuedCloudOperationsFlushPhase() async throws -> SupabaseManualSyncPhaseOutcome {
        calls.append(.queuedCloudOperationsFlush)
        return flushOutcome
    }

    func simulateFinalRefreshPhase() async throws -> SupabaseManualSyncPhaseOutcome {
        calls.append(.finalRefresh)
        return refreshOutcome
    }
}
