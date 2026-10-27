import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class ProductEditorConflictReviewTests: XCTestCase {
    func testMixedPeerChangeRebaseKeepsDisjointPeerFieldOutsideIntent() throws {
        let base = draft(name: "Before", item: "Original")
        var desired = base
        desired.productName = "My name"
        var current = base
        current.productName = "Peer name"
        current.itemNumber = "Peer item"
        let review = ProductEditorConflictReview(base: base, desired: desired, current: current, remoteDeleted: false)
        XCTAssertEqual(review.contestedFields, ["productName"])
        let prepared = try XCTUnwrap(review.preparingDraft(selectedFields: ["productName"]))
        XCTAssertEqual(prepared.productName, "My name")
        XCTAssertEqual(prepared.itemNumber, "Peer item")
        XCTAssertEqual(ProductDraftReviewFields.changed(from: current, to: prepared), ["productName"])
    }

    func testExplicitUseCurrentDoesNotRetainUnselectedLocalFields() throws {
        let base = draft(name: "Before", item: "Original")
        var desired = base
        desired.productName = "My name"
        desired.purchasePrice = 40
        var current = base
        current.productName = "Peer name"
        current.retailPrice = 70
        let review = ProductEditorConflictReview(base: base, desired: desired, current: current, remoteDeleted: false)
        XCTAssertEqual(try XCTUnwrap(review.preparingDraft(selectedFields: [])), current)
        let prepared = try XCTUnwrap(review.preparingDraft(selectedFields: ["productName"]))
        XCTAssertEqual(prepared.purchasePrice, base.purchasePrice)
        XCTAssertEqual(prepared.retailPrice, 70)
        XCTAssertEqual(ProductDraftReviewFields.changed(from: current, to: prepared), ["productName"])
    }

    func testConvergentFieldIsNotContestedAndFurtherDriftRequiresReview() throws {
        let base = draft(name: "Before", item: "Original")
        var desired = base
        desired.productName = "Same"
        var current = base
        current.productName = "Same"
        let converged = ProductEditorConflictReview(base: base, desired: desired, current: current, remoteDeleted: false)
        XCTAssertTrue(converged.contestedFields.isEmpty)
        var next = current
        next.productName = "Another peer value"
        let secondReview = ProductEditorConflictReview(base: current, desired: desired, current: next, remoteDeleted: false)
        // A user must actually choose a different value after rebasing before
        // a future Save has intent; merely retaining an equal current is no-op.
        XCTAssertTrue(secondReview.intendedFields.isEmpty)
        desired.productName = "Explicit new choice"
        let changedAgain = ProductEditorConflictReview(base: current, desired: desired, current: next, remoteDeleted: false)
        XCTAssertEqual(changedAgain.contestedFields, ["productName"])
    }

    func testMissingTombstonedAndUnselectedFieldCannotPrepareResurrection() {
        let base = draft(name: "Before", item: "Original")
        var desired = base
        desired.productName = "My name"
        XCTAssertNil(ProductEditorConflictReview(base: base, desired: desired, current: nil,
            remoteDeleted: false).preparingDraft(selectedFields: ["productName"]))
        XCTAssertNil(ProductEditorConflictReview(base: base, desired: desired, current: base,
            remoteDeleted: true).preparingDraft(selectedFields: ["productName"]))
        XCTAssertNil(ProductEditorConflictReview(base: base, desired: desired, current: base,
            remoteDeleted: false).preparingDraft(selectedFields: ["retailPrice"]))
    }

    private func draft(name: String, item: String) -> ProductDraft {
        ProductDraft(barcode: "R23_EDITOR_PRODUCT", itemNumber: item, productName: name,
                     secondProductName: nil, purchasePrice: 10, retailPrice: 20,
                     stockQuantity: 1, supplierName: "Supplier", categoryName: "Category")
    }
}
