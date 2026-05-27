import XCTest
@testable import iOSMerchandiseControl

final class Task126SyncPolicyTests: XCTestCase {
    func testPolicyDefaultsUseLocalDefaultStoreOnlyAndLogicalScope() {
        XCTAssertEqual(Task126SyncPolicy.storeScopeMode, .localDefaultStoreOnly)
        XCTAssertEqual(Task126SyncPolicy.cacheMode, .logicalScope)
        XCTAssertEqual(Task126SyncPolicy.syncProtocolVersion, 126)
        XCTAssertTrue(Task126SyncPolicy.featureFlags.strictOwnerStoreGate)
        XCTAssertFalse(Task126SyncPolicy.featureFlags.physicalMultiStoreCache)
    }

    func testConflictMatrixCoversC12600ThroughC12660() {
        let ids = Set(Task126ConflictMatrix.allCases.map(\.id))
        XCTAssertEqual(ids.count, 61)

        for index in 0...60 {
            XCTAssertTrue(ids.contains(String(format: "C126-%02d", index)))
        }
    }

    func testDifferentFieldsCanMergeButSameFieldRequiresReview() {
        let differentFields = Task126ConflictResolver.resolve(
            localChangedFields: ["productName"],
            remoteChangedFields: ["retailPrice"]
        )
        XCTAssertEqual(differentFields, .autoMerge)

        let sameField = Task126ConflictResolver.resolve(
            localChangedFields: ["productName"],
            remoteChangedFields: ["productName"]
        )
        XCTAssertEqual(sameField, .review(reason: .sameField))
    }

    func testDomainInvariantViolationRequiresReviewEvenWithDifferentFields() {
        let decision = Task126ConflictResolver.resolve(
            localChangedFields: ["supplierName"],
            remoteChangedFields: ["productBarcode"],
            domainInvariantViolated: true
        )

        XCTAssertEqual(decision, .review(reason: .domainInvariant))
    }
}
