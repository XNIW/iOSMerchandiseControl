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
            simulatedChangedCount: 100_001
        )

        XCTAssertEqual(plan.futureEventChangedCount, 100_001)
        XCTAssertTrue(plan.warnings.contains(.futureEventSplitRequired))
        XCTAssertEqual(PushWarning.futureEventSplitRequired.severity, .futureOnly)
        XCTAssertFalse(plan.isSendable)
    }

    func testManualPushPlanIsDryRunAndSendableWhenSafe() {
        let plan = makePlan(
            baseline: baseline(),
            products: [
                product(remoteID: nil, barcode: "new")
            ]
        )
        let preview = ManualPushPreview(generatedAt: generatedAt, plan: plan)

        XCTAssertTrue(plan.isDryRun)
        XCTAssertTrue(plan.isSendable)
        XCTAssertTrue(preview.isDryRun)
        XCTAssertTrue(preview.isSendable)
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

    func testLocalOnlyProductWithUniqueRemoteBarcodeMatchBecomesControlledLink() {
        let remoteID = UUID()
        let plan = makePlan(
            baseline: baseline(remoteProductIDsByBarcode: ["100": remoteID]),
            products: [
                product(remoteID: nil, barcode: " 100 ")
            ]
        )

        XCTAssertEqual(plan.candidates.first?.action, .dryRunLinkCandidate)
        XCTAssertEqual(plan.candidates.first?.remoteID, remoteID)
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

        XCTAssertEqual(plan.candidates.first?.action, .dryRunLinkCandidate)
        XCTAssertEqual(plan.candidates.first?.remoteID, remoteID)
        XCTAssertFalse(plan.blockedReasons.contains(.blockedNoRemoteID))
    }

    func testAmbiguousRemoteBarcodeBlocksNaturalKeyLink() {
        let plan = makePlan(
            baseline: baseline(remoteProductAmbiguousBarcodes: ["100"]),
            products: [
                product(remoteID: nil, barcode: "100")
            ]
        )

        XCTAssertTrue(plan.blockedReasons.contains(.blockedRemoteConflict))
        XCTAssertFalse(plan.candidates.contains { $0.action == .dryRunCreateCandidate })
    }

    func testSupplierAndCategoryCreateCandidatesAreIncluded() {
        let plan = makePlan(
            baseline: baseline(),
            suppliers: [lookup(.supplier, name: "Acme")],
            categories: [lookup(.productCategory, name: "Shelf")],
            products: []
        )

        XCTAssertEqual(plan.count(entityKind: .supplier, action: .dryRunCreateCandidate), 1)
        XCTAssertEqual(plan.count(entityKind: .productCategory, action: .dryRunCreateCandidate), 1)
        XCTAssertTrue(plan.isSendable)
    }

    func testSupplierUniqueNaturalKeyMatchBecomesControlledLink() {
        let remoteID = UUID()
        let plan = makePlan(
            baseline: baseline(remoteSupplierIDsByName: ["Acme": remoteID]),
            suppliers: [lookup(.supplier, name: " acme ")],
            products: []
        )

        XCTAssertEqual(plan.candidates.first?.action, .dryRunLinkCandidate)
        XCTAssertEqual(plan.candidates.first?.remoteID, remoteID)
    }

    func testSupplierAmbiguousNaturalKeyBlocks() {
        let plan = makePlan(
            baseline: baseline(remoteSupplierAmbiguousNames: ["Acme"]),
            suppliers: [lookup(.supplier, name: "Acme")],
            products: []
        )

        XCTAssertTrue(plan.blockedReasons.contains(.blockedRemoteConflict))
        XCTAssertFalse(plan.isSendable)
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

    func testLinkedProductMissingFromBaselineRequiresControlledVerifyLinkWhenRemoteMetadataExists() {
        let remoteID = UUID()
        let local = product(
            remoteID: remoteID,
            remoteUpdatedAt: Date(timeIntervalSince1970: 1_778_000_000),
            barcode: "100"
        )

        let plan = makePlan(
            baseline: baseline(),
            products: [local]
        )

        XCTAssertEqual(plan.candidates.first?.action, .dryRunLinkCandidate)
        XCTAssertEqual(plan.candidates.first?.remoteID, remoteID)
        XCTAssertTrue(plan.warnings.contains(.warningStaleRemote))
        XCTAssertTrue(plan.isSendable)
    }

    func testLinkedSupplierMissingFromBaselineRequiresControlledVerifyLinkWhenRemoteMetadataExists() {
        let remoteID = UUID()
        let plan = makePlan(
            baseline: baseline(),
            suppliers: [
                lookup(
                    .supplier,
                    name: "Acme",
                    remoteID: remoteID,
                    remoteUpdatedAt: Date(timeIntervalSince1970: 1_778_000_000)
                )
            ],
            products: []
        )

        XCTAssertEqual(plan.candidates.first?.action, .dryRunLinkCandidate)
        XCTAssertEqual(plan.candidates.first?.remoteID, remoteID)
        XCTAssertTrue(plan.warnings.contains(.warningStaleRemote))
        XCTAssertTrue(plan.isSendable)
    }

    func testTask045ScopeRecognizesSupplierCategoryAndProduct() {
        XCTAssertTrue(ManualPushTask045Scope.contains(lookup(.supplier, name: " task045_supplier_test ")))
        XCTAssertTrue(ManualPushTask045Scope.contains(lookup(.productCategory, name: "TASK045_CATEGORY_TEST")))
        XCTAssertTrue(ManualPushTask045Scope.contains(product(remoteID: nil, barcode: " TASK045_BARCODE_TEST ")))
        XCTAssertTrue(ManualPushTask045Scope.contains(product(remoteID: nil, barcode: nil, productName: "TASK045_PRODUCT_NAME")))
    }

    func testTask045ScopeRejectsSimilarButInvalidStrings() {
        XCTAssertFalse(ManualPushTask045Scope.contains(lookup(.supplier, name: "PRE_TASK045_SUPPLIER")))
        XCTAssertFalse(ManualPushTask045Scope.contains(lookup(.productCategory, name: "TASK044_CATEGORY")))
        XCTAssertFalse(ManualPushTask045Scope.contains(product(remoteID: nil, barcode: "task045_lowercase_barcode")))
        XCTAssertFalse(ManualPushTask045Scope.contains(product(remoteID: nil, barcode: "NOISE_BARCODE", productName: "TASK045_PRODUCT_NAME")))
    }

    func testScopedTask045MixedDatasetIncludesOnlyTask045RecordsAndCountsOutsideScope() {
        let plan = makePlan(
            scope: .scopedTask045,
            baseline: baseline(),
            suppliers: [
                lookup(.supplier, name: "TASK045_SUPPLIER_TEST"),
                lookup(.supplier, name: "Noise Supplier")
            ],
            categories: [
                lookup(.productCategory, name: "TASK045_CATEGORY_TEST"),
                lookup(.productCategory, name: "Noise Category")
            ],
            products: [
                product(
                    remoteID: nil,
                    barcode: "TASK045_PRODUCT_BARCODE",
                    hasSupplierReference: true,
                    supplierName: "TASK045_SUPPLIER_TEST",
                    hasCategoryReference: true,
                    categoryName: "TASK045_CATEGORY_TEST"
                ),
                product(remoteID: nil, barcode: "NOISE_PRODUCT")
            ]
        )

        XCTAssertEqual(plan.scopeSummary.mode, .scopedTask045)
        XCTAssertEqual(plan.scopeSummary.included, 3)
        XCTAssertEqual(plan.scopeSummary.excludedOutsideScope, 3)
        XCTAssertEqual(plan.count(entityKind: .supplier, action: .dryRunCreateCandidate), 1)
        XCTAssertEqual(plan.count(entityKind: .productCategory, action: .dryRunCreateCandidate), 1)
        XCTAssertEqual(plan.count(entityKind: .product, action: .dryRunCreateCandidate), 1)
        XCTAssertFalse(plan.candidates.contains { $0.localID == "NOISE_PRODUCT" })
        XCTAssertFalse(plan.blockedReasons.contains(.blockedOutsideScope))
        XCTAssertTrue(plan.isSendable)
    }

    func testScopedTask045ProductWithOutsideLookupWithoutRemoteIDBlocksDependency() {
        let plan = makePlan(
            scope: .scopedTask045,
            baseline: baseline(),
            suppliers: [lookup(.supplier, name: "Outside Supplier")],
            products: [
                product(
                    remoteID: nil,
                    barcode: "TASK045_PRODUCT_BARCODE",
                    hasSupplierReference: true,
                    supplierName: "Outside Supplier"
                )
            ]
        )

        XCTAssertEqual(plan.scopeSummary.blockedDependencies, 1)
        XCTAssertTrue(plan.blockedReasons.contains(.blockedScopedDependency))
        XCTAssertFalse(plan.candidates.contains { $0.entityKind == .product && $0.action == .dryRunCreateCandidate })
    }

    func testScopedTask045ProductWithOutsideLookupRemoteIDDoesNotWriteLookup() {
        let supplierRemoteID = UUID()
        let plan = makePlan(
            scope: .scopedTask045,
            baseline: baseline(),
            suppliers: [
                lookup(
                    .supplier,
                    name: "Outside Supplier",
                    remoteID: supplierRemoteID,
                    remoteUpdatedAt: Date(timeIntervalSince1970: 1_778_000_000)
                )
            ],
            products: [
                product(
                    remoteID: nil,
                    barcode: "TASK045_PRODUCT_BARCODE",
                    hasSupplierReference: true,
                    supplierRemoteID: supplierRemoteID,
                    supplierName: "Outside Supplier"
                )
            ]
        )

        XCTAssertEqual(plan.scopeSummary.blockedDependencies, 0)
        XCTAssertEqual(plan.count(entityKind: .product, action: .dryRunCreateCandidate), 1)
        XCTAssertFalse(plan.candidates.contains { $0.entityKind == .supplier })
        XCTAssertFalse(plan.blockedReasons.contains(.blockedOutsideScope))
        XCTAssertTrue(plan.isSendable)
    }

    func testScopedTask045ProductWithOutsideLookupNameAndTask045LocalIDStillBlocksDependency() {
        let product = ManualPushProductState(
            localID: "TASK045_PRODUCT_BARCODE",
            barcode: "TASK045_PRODUCT_BARCODE",
            productName: "Scoped",
            hasSupplierReference: true,
            supplierLocalID: "TASK045_FAKE_LOCAL_ID",
            supplierName: "Outside Supplier",
            supplierRemoteID: nil
        )
        let plan = makePlan(
            scope: .scopedTask045,
            baseline: baseline(),
            products: [product]
        )

        XCTAssertEqual(plan.scopeSummary.blockedDependencies, 1)
        XCTAssertTrue(plan.blockedReasons.contains(.blockedScopedDependency))
        XCTAssertFalse(plan.isSendable)
    }

    func testGlobalModeStillIncludesMixedDataset() {
        let plan = makePlan(
            scope: .global,
            baseline: baseline(),
            suppliers: [
                lookup(.supplier, name: "TASK045_SUPPLIER_TEST"),
                lookup(.supplier, name: "Noise Supplier")
            ],
            categories: [
                lookup(.productCategory, name: "TASK045_CATEGORY_TEST"),
                lookup(.productCategory, name: "Noise Category")
            ],
            products: [
                product(remoteID: nil, barcode: "TASK045_PRODUCT_BARCODE"),
                product(remoteID: nil, barcode: "NOISE_PRODUCT")
            ]
        )

        XCTAssertEqual(plan.scopeSummary.mode, .global)
        XCTAssertEqual(plan.scopeSummary.excludedOutsideScope, 0)
        XCTAssertEqual(plan.count(entityKind: .supplier, action: .dryRunCreateCandidate), 2)
        XCTAssertEqual(plan.count(entityKind: .productCategory, action: .dryRunCreateCandidate), 2)
        XCTAssertEqual(plan.count(entityKind: .product, action: .dryRunCreateCandidate), 2)
        XCTAssertFalse(plan.blockedReasons.contains(.blockedOutsideScope))
    }

    func testScopedTask045DoesNotAddProductPriceFutureOnlyCandidate() {
        let plan = makePlan(
            scope: .scopedTask045,
            baseline: baseline(),
            products: [
                product(
                    remoteID: nil,
                    barcode: "TASK045_PRODUCT_BARCODE",
                    hasLocalPriceChanges: true
                )
            ]
        )

        XCTAssertFalse(plan.candidates.contains { $0.entityKind == .productPrice })
        XCTAssertEqual(plan.count(entityKind: .product, action: .dryRunCreateCandidate), 1)
    }

    private func makePlan(
        scope: ManualPushPreflightScope = .global,
        pullState: ManualPushPullState = ManualPushPullState(isComplete: true),
        accountState: ManualPushAccountState? = nil,
        baseline: ManualPushBaseline?,
        suppliers: [ManualPushLookupState] = [],
        categories: [ManualPushLookupState] = [],
        products: [ManualPushProductState],
        simulatedChangedCount: Int? = nil
    ) -> ManualPushPlan {
        service.makePlan(input: ManualPushPreflightInput(
            generatedAt: generatedAt,
            scope: scope,
            pullState: pullState,
            accountState: accountState ?? ManualPushAccountState(currentUserID: userID, lastLinkedUserID: userID),
            baseline: baseline,
            suppliers: suppliers,
            categories: categories,
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
        supplierName: String = "supplier",
        hasCategoryReference: Bool = false,
        categoryRemoteID: UUID? = nil,
        categoryName: String = "category",
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
            supplierLocalID: hasSupplierReference && supplierRemoteID == nil ? supplierName : nil,
            supplierName: hasSupplierReference ? supplierName : nil,
            supplierRemoteID: supplierRemoteID,
            hasCategoryReference: hasCategoryReference,
            categoryLocalID: hasCategoryReference && categoryRemoteID == nil ? categoryName : nil,
            categoryName: hasCategoryReference ? categoryName : nil,
            categoryRemoteID: categoryRemoteID,
            hasLocalPriceChanges: hasLocalPriceChanges
        )
    }

    private func lookup(
        _ kind: PushEntityKind,
        name: String,
        remoteID: UUID? = nil,
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil
    ) -> ManualPushLookupState {
        ManualPushLookupState(
            entityKind: kind,
            localID: name,
            remoteID: remoteID,
            remoteUpdatedAt: remoteUpdatedAt,
            remoteDeletedAt: remoteDeletedAt,
            name: name
        )
    }

    private func baseline(
        fingerprints: [UUID: ManualPushFingerprint] = [:],
        supplierFingerprintsByRemoteID: [UUID: ManualPushFingerprint] = [:],
        categoryFingerprintsByRemoteID: [UUID: ManualPushFingerprint] = [:],
        remoteSupplierIDsByName: [String: UUID] = [:],
        remoteCategoryIDsByName: [String: UUID] = [:],
        remoteProductIDsByBarcode: [String: UUID] = [:],
        remoteSupplierAmbiguousNames: Set<String> = [],
        remoteCategoryAmbiguousNames: Set<String> = [],
        remoteProductAmbiguousBarcodes: Set<String> = [],
        remoteUpdatedAtByProductID: [UUID: Date] = [:],
        remoteDeletedAtByProductID: [UUID: Date] = [:],
        invalidationReasons: Set<ManualPushBaselineInvalidationReason> = []
    ) -> ManualPushBaseline {
        ManualPushBaseline(
            supplierFingerprintsByRemoteID: supplierFingerprintsByRemoteID,
            categoryFingerprintsByRemoteID: categoryFingerprintsByRemoteID,
            productFingerprintsByRemoteID: fingerprints,
            remoteSupplierIDsByName: remoteSupplierIDsByName,
            remoteCategoryIDsByName: remoteCategoryIDsByName,
            remoteProductIDsByBarcode: remoteProductIDsByBarcode,
            remoteSupplierAmbiguousNames: remoteSupplierAmbiguousNames,
            remoteCategoryAmbiguousNames: remoteCategoryAmbiguousNames,
            remoteProductAmbiguousBarcodes: remoteProductAmbiguousBarcodes,
            remoteUpdatedAtByProductID: remoteUpdatedAtByProductID,
            remoteDeletedAtByProductID: remoteDeletedAtByProductID,
            invalidationReasons: invalidationReasons
        )
    }
}
