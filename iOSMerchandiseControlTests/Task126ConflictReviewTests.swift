import XCTest
@testable import iOSMerchandiseControl

final class Task126ConflictReviewTests: XCTestCase {
    func testUpdateWithoutChangedFieldsIsRejectedByContract() {
        XCTAssertFalse(Task126ChangedFieldsContract.isValid(operation: .update, changedFields: []))
        XCTAssertTrue(Task126ChangedFieldsContract.isValid(operation: .update, changedFields: ["productName"]))
    }

    func testDeleteVsEditRoutesToReview() {
        let decision = Task126ConflictResolver.resolve(
            localChangedFields: ["delete"],
            remoteChangedFields: ["productName"],
            remoteDeleted: true
        )

        XCTAssertEqual(decision, .review(reason: .deleteVsEdit))
    }

    func testBatchReviewSeparatesMergeableRowsFromReviewRows() {
        let summary = Task126ConflictBatchReview.summarize([
            .init(localChangedFields: ["name"], remoteChangedFields: ["price"]),
            .init(localChangedFields: ["barcode"], remoteChangedFields: ["barcode"]),
            .init(localChangedFields: ["delete"], remoteChangedFields: ["name"], remoteDeleted: true)
        ])

        XCTAssertEqual(summary.autoMergeCount, 1)
        XCTAssertEqual(summary.reviewCount, 2)
        XCTAssertEqual(summary.reasons, [.sameField, .deleteVsEdit])
    }

    func testProductPriceAppendDedupeAndSameSlotDifferentValuePolicy() {
        XCTAssertEqual(
            Task126ProductPriceHistoryPolicy.resolve(
                existingCanonicalPrice: nil,
                incomingCanonicalPrice: "12.50"
            ),
            .append
        )
        XCTAssertEqual(
            Task126ProductPriceHistoryPolicy.resolve(
                existingCanonicalPrice: "12.50",
                incomingCanonicalPrice: "12.50"
            ),
            .dedupe
        )
        XCTAssertEqual(
            Task126ProductPriceHistoryPolicy.resolve(
                existingCanonicalPrice: "12.50",
                incomingCanonicalPrice: "13.00"
            ),
            .reviewStale
        )
    }
}
