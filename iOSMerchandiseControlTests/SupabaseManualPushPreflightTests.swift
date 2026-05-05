import XCTest
@testable import iOSMerchandiseControl

final class SupabaseManualPushPreflightTests: XCTestCase {
    private let service = SupabaseManualPushPreflightService()
    private let generatedAt = Date(timeIntervalSince1970: 1_778_000_000)
    private let userID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    func testNoBaselineBlocksMissingBaseline() {
        let plan = makePlan(
            baseline: nil,
            products: [
                product(remoteID: UUID(), barcode: "100")
            ]
        )

        XCTAssertTrue(plan.blockedReasons.contains(.blockedMissingBaseline))
        XCTAssertFalse(plan.candidates.contains { $0.action == .noOpAlreadySynced })
        XCTAssertFalse(plan.candidates.contains { $0.action == .dryRunUpdateCandidate })
    }

    func testBaselinePresentAndEqualFingerprintIsNoOpAlreadySynced() {
        let remoteID = UUID()
        let local = product(remoteID: remoteID, barcode: "100", productName: "Same")
        let plan = makePlan(
            baseline: baseline(fingerprints: [remoteID: local.catalogFingerprint]),
            products: [local]
        )

        XCTAssertEqual(plan.candidates.count, 1)
        XCTAssertEqual(plan.candidates.first?.action, .noOpAlreadySynced)
        XCTAssertEqual(plan.categoryCounts[.noOpAlreadySynced], 1)
        XCTAssertTrue(plan.blockedReasons.isEmpty)
    }

    func testBaselinePresentAndDifferentFingerprintIsDryRunUpdateCandidate() {
        let remoteID = UUID()
        let supplierID = UUID()
        let categoryID = UUID()
        let local = product(
            remoteID: remoteID,
            barcode: "100",
            productName: "Local",
            supplierRemoteID: supplierID,
            categoryRemoteID: categoryID
        )
        let remoteFingerprint = ManualPushFingerprintNormalizer.product(
            barcode: "100",
            itemNumber: nil,
            productName: "Remote",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            stockQuantity: nil,
            supplierRemoteID: supplierID,
            categoryRemoteID: categoryID
        )

        let plan = makePlan(
            baseline: baseline(fingerprints: [remoteID: remoteFingerprint]),
            products: [local]
        )

        XCTAssertEqual(plan.candidates.count, 1)
        XCTAssertEqual(plan.candidates.first?.action, .dryRunUpdateCandidate)
        XCTAssertEqual(plan.categoryCounts[.dryRunUpdateCandidate], 1)
        XCTAssertTrue(plan.blockedReasons.isEmpty)
    }

    func testLocalEntityWithoutRemoteIDAndWithoutBaselineUsesMissingBaseline() {
        let plan = makePlan(
            baseline: nil,
            products: [
                product(remoteID: nil, barcode: "local-only")
            ]
        )

        XCTAssertTrue(plan.blockedReasons.contains(.blockedMissingBaseline))
        XCTAssertFalse(plan.blockedReasons.contains(.blockedNoRemoteID))
        XCTAssertTrue(plan.candidates.isEmpty)
    }

    func testAccountMismatchBlocksPreflight() {
        let remoteID = UUID()
        let local = product(remoteID: remoteID, barcode: "100")
        let plan = makePlan(
            accountState: ManualPushAccountState(currentUserID: UUID(), lastLinkedUserID: userID),
            baseline: baseline(fingerprints: [remoteID: local.catalogFingerprint]),
            products: [local]
        )

        XCTAssertTrue(plan.blockedReasons.contains(.blockedAccountMismatch))
        XCTAssertFalse(plan.candidates.contains { $0.entityKind == .product })
    }

    func testMissingLinkedAccountBlocksPreflight() {
        let remoteID = UUID()
        let local = product(remoteID: remoteID, barcode: "100")
        let plan = makePlan(
            accountState: ManualPushAccountState(currentUserID: userID, lastLinkedUserID: nil),
            baseline: baseline(fingerprints: [remoteID: local.catalogFingerprint]),
            products: [local]
        )

        XCTAssertTrue(plan.blockedReasons.contains(.blockedAccountMismatch))
        XCTAssertFalse(plan.candidates.contains { $0.entityKind == .product })
    }

    func testPartialPullBlocksPreflight() {
        let remoteID = UUID()
        let local = product(remoteID: remoteID, barcode: "100")
        let plan = makePlan(
            pullState: ManualPushPullState(isComplete: false),
            baseline: baseline(fingerprints: [remoteID: local.catalogFingerprint]),
            products: [local]
        )

        XCTAssertTrue(plan.blockedReasons.contains(.blockedPartialPull))
        XCTAssertFalse(plan.candidates.contains { $0.entityKind == .product })
    }

    func testRemoteTombstoneBlocksProduct() {
        let remoteID = UUID()
        let local = product(
            remoteID: remoteID,
            remoteDeletedAt: Date(timeIntervalSince1970: 1_778_000_100),
            barcode: "100"
        )
        let plan = makePlan(
            baseline: baseline(fingerprints: [remoteID: local.catalogFingerprint]),
            products: [local]
        )

        XCTAssertTrue(plan.blockedReasons.contains(.blockedTombstoneConflict))
        XCTAssertFalse(plan.candidates.contains { $0.entityKind == .product })
    }

    func testMissingSupplierOrCategoryRemoteIDBlocksProductAndWarns() {
        let remoteID = UUID()
        let local = product(
            remoteID: remoteID,
            barcode: "100",
            hasSupplierReference: true,
            supplierRemoteID: nil,
            hasCategoryReference: true,
            categoryRemoteID: nil
        )
        let plan = makePlan(
            baseline: baseline(fingerprints: [remoteID: local.catalogFingerprint]),
            products: [local]
        )

        XCTAssertTrue(plan.blockedReasons.contains(.blockedMissingSupplierCategoryRemoteID))
        XCTAssertTrue(plan.warnings.contains(.warningLocalOnlySupplierCategory))
        XCTAssertFalse(plan.candidates.contains { $0.action == .dryRunUpdateCandidate })
    }

    func testProductPriceLocalChangeIsFutureOnlyAndNotCatalogPayload() {
        let remoteID = UUID()
        let local = product(
            remoteID: remoteID,
            barcode: "100",
            hasLocalPriceChanges: true
        )
        let plan = makePlan(
            baseline: baseline(fingerprints: [remoteID: local.catalogFingerprint]),
            products: [local]
        )

        XCTAssertTrue(plan.candidates.contains {
            $0.entityKind == .productPrice && $0.action == .futurePricePushCandidate
        })
        XCTAssertFalse(plan.candidates.contains {
            $0.entityKind == .product && ($0.action == .dryRunCreateCandidate || $0.action == .dryRunUpdateCandidate)
        })
        XCTAssertEqual(PushCandidateAction.futurePricePushCandidate.severity, .futureOnly)
    }

    func testChangedCountAboveThresholdAddsFutureEventSplitWarningOnly() {
        let remoteID = UUID()
        let local = product(remoteID: remoteID, barcode: "100")
        let plan = makePlan(
            baseline: baseline(fingerprints: [remoteID: local.catalogFingerprint]),
            products: [local],
            simulatedChangedCount: 1_001
        )

        XCTAssertEqual(plan.futureEventChangedCount, 1_001)
        XCTAssertTrue(plan.warnings.contains(.futureEventSplitRequired))
        XCTAssertEqual(PushWarning.futureEventSplitRequired.severity, .futureOnly)
        XCTAssertFalse(plan.isSendable)
    }

    func testManualPushPlanIsAlwaysDryRunAndNotSendable() {
        let plan = makePlan(
            baseline: baseline(),
            products: [
                product(remoteID: nil, barcode: "new")
            ]
        )
        let preview = ManualPushPreview(generatedAt: generatedAt, plan: plan)

        XCTAssertTrue(plan.isDryRun)
        XCTAssertFalse(plan.isSendable)
        XCTAssertTrue(preview.isDryRun)
        XCTAssertFalse(preview.isSendable)
    }

    func testLocalOnlyProductWithValidBaselineIsDryRunCreateCandidate() {
        let plan = makePlan(
            baseline: baseline(),
            products: [
                product(
                    remoteID: nil,
                    barcode: "new",
                    hasSupplierReference: true,
                    supplierRemoteID: UUID(),
                    hasCategoryReference: true,
                    categoryRemoteID: UUID()
                )
            ]
        )

        XCTAssertEqual(plan.candidates.count, 1)
        XCTAssertEqual(plan.candidates.first?.action, .dryRunCreateCandidate)
        XCTAssertEqual(plan.categoryCounts[.dryRunCreateCandidate], 1)
        XCTAssertTrue(plan.blockedReasons.isEmpty)
    }

    func testLocalOnlyProductWithRemoteBarcodeCollisionBlocksNoRemoteID() {
        let remoteID = UUID()
        let plan = makePlan(
            baseline: baseline(remoteProductIDsByBarcode: ["100": remoteID]),
            products: [
                product(remoteID: nil, barcode: " 100 ")
            ]
        )

        XCTAssertTrue(plan.blockedReasons.contains(.blockedNoRemoteID))
        XCTAssertFalse(plan.candidates.contains { $0.action == .dryRunCreateCandidate })
    }

    func testRemoteBarcodeBaselineKeysAreNormalizedForCollisionCheck() {
        let remoteID = UUID()
        let plan = makePlan(
            baseline: baseline(remoteProductIDsByBarcode: ["\n100 ": remoteID]),
            products: [
                product(remoteID: nil, barcode: "100")
            ]
        )

        XCTAssertTrue(plan.blockedReasons.contains(.blockedNoRemoteID))
        XCTAssertFalse(plan.candidates.contains { $0.action == .dryRunCreateCandidate })
    }

    func testInvalidBaselineIsHandledAsStaleOrPartialBaseline() {
        let remoteID = UUID()
        let local = product(remoteID: remoteID, barcode: "100")
        let plan = makePlan(
            baseline: baseline(
                fingerprints: [remoteID: local.catalogFingerprint],
                invalidationReasons: [.partialPull]
            ),
            products: [local]
        )

        XCTAssertTrue(plan.blockedReasons.contains(.blockedStaleOrPartialBaseline))
        XCTAssertTrue(plan.candidates.isEmpty)
    }

    func testRemoteUpdatedAtNewerThanLocalBlocksRemoteConflict() {
        let remoteID = UUID()
        let localUpdatedAt = Date(timeIntervalSince1970: 1_778_000_000)
        let baselineUpdatedAt = Date(timeIntervalSince1970: 1_778_000_100)
        let local = product(
            remoteID: remoteID,
            remoteUpdatedAt: localUpdatedAt,
            barcode: "100"
        )
        let plan = makePlan(
            baseline: baseline(
                fingerprints: [remoteID: local.catalogFingerprint],
                remoteUpdatedAtByProductID: [remoteID: baselineUpdatedAt]
            ),
            products: [local]
        )

        XCTAssertTrue(plan.blockedReasons.contains(.blockedRemoteConflict))
        XCTAssertFalse(plan.candidates.contains { $0.action == .dryRunUpdateCandidate })
    }

    private func makePlan(
        pullState: ManualPushPullState = ManualPushPullState(isComplete: true),
        accountState: ManualPushAccountState? = nil,
        baseline: ManualPushBaseline?,
        products: [ManualPushProductState],
        simulatedChangedCount: Int? = nil
    ) -> ManualPushPlan {
        service.makePlan(input: ManualPushPreflightInput(
            generatedAt: generatedAt,
            pullState: pullState,
            accountState: accountState ?? ManualPushAccountState(currentUserID: userID, lastLinkedUserID: userID),
            baseline: baseline,
            products: products,
            simulatedChangedCount: simulatedChangedCount
        ))
    }

    private func product(
        remoteID: UUID?,
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil,
        barcode: String?,
        productName: String? = "Product",
        hasSupplierReference: Bool = false,
        supplierRemoteID: UUID? = nil,
        hasCategoryReference: Bool = false,
        categoryRemoteID: UUID? = nil,
        hasLocalPriceChanges: Bool = false
    ) -> ManualPushProductState {
        ManualPushProductState(
            localID: barcode ?? UUID().uuidString,
            remoteID: remoteID,
            remoteUpdatedAt: remoteUpdatedAt,
            remoteDeletedAt: remoteDeletedAt,
            barcode: barcode,
            productName: productName,
            hasSupplierReference: hasSupplierReference,
            supplierRemoteID: supplierRemoteID,
            hasCategoryReference: hasCategoryReference,
            categoryRemoteID: categoryRemoteID,
            hasLocalPriceChanges: hasLocalPriceChanges
        )
    }

    private func baseline(
        fingerprints: [UUID: ManualPushFingerprint] = [:],
        remoteProductIDsByBarcode: [String: UUID] = [:],
        remoteUpdatedAtByProductID: [UUID: Date] = [:],
        remoteDeletedAtByProductID: [UUID: Date] = [:],
        invalidationReasons: Set<ManualPushBaselineInvalidationReason> = []
    ) -> ManualPushBaseline {
        ManualPushBaseline(
            productFingerprintsByRemoteID: fingerprints,
            remoteProductIDsByBarcode: remoteProductIDsByBarcode,
            remoteUpdatedAtByProductID: remoteUpdatedAtByProductID,
            remoteDeletedAtByProductID: remoteDeletedAtByProductID,
            invalidationReasons: invalidationReasons
        )
    }
}
