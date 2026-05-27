import XCTest
@testable import iOSMerchandiseControl

final class Task126ConflictReviewUITests: XCTestCase {
    func testSameFieldReviewShowsAllUserChoicesAndKeepsOnlyConflictInReview() {
        let state = Task126ReviewInteractionFixtures.conflictReviewSameField()

        XCTAssertEqual(state.surface, .conflictReview)
        XCTAssertEqual(state.visibleChoiceIDs, [
            .useLocal,
            .useRemote,
            .editManually,
            .applyToSimilar,
            .postponeReview
        ])
        XCTAssertTrue(state.isDialogVisible)
        XCTAssertFalse(state.isApplying)

        let outcome = Task126ReviewInteractionReducer.apply(.useLocal, to: state)

        XCTAssertEqual(outcome.observedLocalResult, "productName=MX")
        XCTAssertEqual(outcome.observedSyncResult, "pending=0;review=0;synced=local")
        XCTAssertEqual(outcome.pendingAfter, 0)
        XCTAssertEqual(outcome.conflictCountAfter, 0)
        XCTAssertEqual(outcome.reviewRemainingCount, 0)
        XCTAssertGreaterThanOrEqual(outcome.timeToReviewShownMs, 1)
        XCTAssertGreaterThanOrEqual(outcome.timeToApplyChoiceMs, 1)
        XCTAssertGreaterThanOrEqual(outcome.timeToFinalStateMs, outcome.timeToApplyChoiceMs)
    }

    func testSameFieldChoiceOutcomesCoverEveryReviewButton() {
        let state = Task126ReviewInteractionFixtures.conflictReviewSameFieldReverse()
        let expectations: [(Task126UserChoice, String, String, Int, Int)] = [
            (.useLocal, "productName=MX", "pending=0;review=0;synced=local", 0, 0),
            (.useRemote, "productName=X", "pending=0;review=0;synced=remote", 0, 0),
            (.editManually, "productName=manual-review", "pending=0;review=0;synced=manual", 0, 0),
            (.applyToSimilar, "productName=MX;appliedSimilar=true", "pending=0;review=0;synced=bulk-local", 0, 0),
            (.postponeReview, "productName unresolved", "pending=1;review=1;synced=pending", 1, 1)
        ]

        for (choice, local, sync, pendingAfter, reviewAfter) in expectations {
            let outcome = Task126ReviewInteractionReducer.apply(choice, to: state)

            XCTAssertEqual(outcome.observedLocalResult, local)
            XCTAssertEqual(outcome.observedSyncResult, sync)
            XCTAssertEqual(outcome.pendingAfter, pendingAfter)
            XCTAssertEqual(outcome.reviewRemainingCount, reviewAfter)
            XCTAssertGreaterThanOrEqual(outcome.timeToReviewShownMs, 1)
            XCTAssertGreaterThanOrEqual(outcome.timeToApplyChoiceMs, 1)
        }
    }

    func testDifferentFieldDirectionsAutoMergeWithoutReviewPopup() {
        for state in [
            Task126ReviewInteractionFixtures.conflictReviewDifferentFieldsIOSOffline(),
            Task126ReviewInteractionFixtures.conflictReviewDifferentFieldsAndroidOffline()
        ] {
            XCTAssertFalse(state.isDialogVisible)
            XCTAssertTrue(state.visibleChoiceIDs.isEmpty)

            let outcome = Task126ReviewInteractionReducer.apply(.postponeReview, to: state)

            XCTAssertEqual(outcome.observedLocalResult, "fieldA=local;fieldB=remote;merged=1")
            XCTAssertEqual(outcome.observedSyncResult, "pending=0;review=0;synced=merged")
            XCTAssertEqual(outcome.pendingAfter, 0)
            XCTAssertEqual(outcome.conflictCountAfter, 0)
            XCTAssertEqual(outcome.reviewRemainingCount, 0)
        }
    }

    func testDifferentFieldsMergeWithoutPopupAndSameBatchLeavesOnlyConflictForReview() {
        let state = Task126ReviewInteractionFixtures.conflictReviewMixedBatch()

        XCTAssertEqual(state.mergedCount, 1)
        XCTAssertEqual(state.conflictCountBefore, 1)
        XCTAssertEqual(state.reviewRemainingCount, 1)

        let outcome = Task126ReviewInteractionReducer.apply(.postponeReview, to: state)

        XCTAssertEqual(outcome.observedLocalResult, "stock=12 auto-merged; productName unresolved")
        XCTAssertEqual(outcome.pendingAfter, 1)
        XCTAssertEqual(outcome.conflictCountAfter, 1)
        XCTAssertEqual(outcome.reviewRemainingCount, 1)
        XCTAssertEqual(outcome.mergedCount, 1)
    }

    func testDeleteVsEditAndProductPriceStaleRequireReviewChoices() {
        for state in [
            Task126ReviewInteractionFixtures.conflictReviewDeleteVsEdit(),
            Task126ReviewInteractionFixtures.conflictReviewProductPriceStale()
        ] {
            XCTAssertTrue(state.isDialogVisible)
            XCTAssertTrue(state.visibleChoiceIDs.contains(.useLocal))
            XCTAssertTrue(state.visibleChoiceIDs.contains(.useRemote))
            XCTAssertTrue(state.visibleChoiceIDs.contains(.postponeReview))
            XCTAssertGreaterThan(state.conflictCountBefore, 0)
        }
    }
}
