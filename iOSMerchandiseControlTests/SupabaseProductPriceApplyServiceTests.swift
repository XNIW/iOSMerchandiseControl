import XCTest
import SwiftData
@testable import iOSMerchandiseControl

@MainActor
final class SupabaseProductPriceApplyServiceTests: XCTestCase {
    private let service = SupabaseProductPriceApplyService()
    private let session = ProductPriceApplySessionSnapshot(
        userID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    )
    private static var retainedContainers: [ModelContainer] = []
    private static var retainedContexts: [ModelContext] = []

    func testPriceCanonicalizerDoesNotUseRawDoubleEqualityForSkippedExisting() throws {
        let productID = uuid(201)
        let plan = makePlan(
            remoteRows: [
                remotePrice(productID: productID, price: 12.3404)
            ],
            localProducts: [
                localProduct(remoteID: productID, barcode: "100")
            ],
            localPrices: [
                localPrice(barcode: "100", price: 12.3400)
            ]
        )

        XCTAssertEqual(plan.summary.remoteRead, 1)
        XCTAssertEqual(plan.summary.included, 0)
        XCTAssertEqual(plan.summary.skippedExisting, 1)
        XCTAssertEqual(plan.summary.remoteIdentityLinks, 1)
        XCTAssertEqual(plan.summary.conflicts, 0)
        XCTAssertTrue(plan.isApplyAllowed)
    }

    func testSameLogicalKeyWithDifferentCanonicalPriceIsConflict() throws {
        let productID = uuid(202)
        let plan = makePlan(
            remoteRows: [
                remotePrice(productID: productID, price: 12.349)
            ],
            localProducts: [
                localProduct(remoteID: productID, barcode: "100")
            ],
            localPrices: [
                localPrice(barcode: "100", price: 12.340)
            ]
        )

        XCTAssertEqual(plan.summary.included, 0)
        XCTAssertEqual(plan.summary.conflicts, 1)
        XCTAssertTrue(plan.blockReasons.contains(.conflicts))
        XCTAssertFalse(plan.isApplyAllowed)
    }

    func testDuplicateLocalProductPricesSameKeySamePriceAreConflict() throws {
        let productID = uuid(215)
        let plan = makePlan(
            remoteRows: [
                remotePrice(productID: productID, price: 12.34)
            ],
            localProducts: [
                localProduct(remoteID: productID, barcode: "100")
            ],
            localPrices: [
                localPrice(barcode: "100", price: 12.34),
                localPrice(barcode: "100", price: 12.34)
            ]
        )

        XCTAssertEqual(plan.summary.included, 0)
        XCTAssertEqual(plan.summary.conflicts, 1)
        XCTAssertTrue(plan.blockReasons.contains(.conflicts))
        XCTAssertFalse(plan.isApplyAllowed)
    }

    func testInvalidPricesAreClassifiedInvalid() {
        for price in [Double.nan, Double.infinity, -1] {
            let plan = makePlan(remoteRows: [remotePrice(price: price)])

            XCTAssertEqual(plan.summary.invalid, 1)
            XCTAssertTrue(plan.blockReasons.contains(.invalidRows))
            XCTAssertFalse(plan.isApplyAllowed)
        }
    }

    func testInvalidTypeIsClassifiedInvalid() {
        let plan = makePlan(remoteRows: [remotePrice(type: "WHOLESALE")])

        XCTAssertEqual(plan.summary.invalid, 1)
        XCTAssertTrue(plan.blockReasons.contains(.invalidRows))
        XCTAssertFalse(plan.isApplyAllowed)
    }

    func testEffectiveAtRawDifferentButCanonicalEqualDedupes() throws {
        let productID = uuid(203)
        let plan = makePlan(
            remoteRows: [
                remotePrice(productID: productID, effectiveAt: "2026-05-01T10:30:00Z")
            ],
            localProducts: [
                localProduct(remoteID: productID, barcode: "100")
            ],
            localPrices: [
                localPrice(
                    barcode: "100",
                    price: 2.5,
                    effectiveAt: try date("2026-05-01 10:30:00")
                )
            ]
        )

        XCTAssertEqual(plan.summary.included, 0)
        XCTAssertEqual(plan.summary.skippedExisting, 1)
        XCTAssertEqual(plan.summary.remoteIdentityLinks, 1)
        XCTAssertEqual(plan.summary.invalid, 0)
        XCTAssertTrue(plan.isApplyAllowed)
    }

    func testInvalidEffectiveAtIsInvalid() {
        let plan = makePlan(remoteRows: [remotePrice(effectiveAt: "not-a-date")])

        XCTAssertEqual(plan.summary.invalid, 1)
        XCTAssertTrue(plan.blockReasons.contains(.invalidRows))
        XCTAssertFalse(plan.isApplyAllowed)
    }

    func testPostgresTimezoneEffectiveAtIsAccepted() throws {
        let productID = uuid(216)
        let plan = makePlan(
            remoteRows: [
                remotePrice(productID: productID, effectiveAt: "2026-05-01 10:00:00+00")
            ],
            localProducts: [
                localProduct(remoteID: productID, barcode: "100")
            ]
        )

        XCTAssertEqual(plan.summary.invalid, 0)
        XCTAssertEqual(plan.summary.included, 1)
        XCTAssertEqual(plan.linesToInsert.first?.effectiveAtCanonical, "2026-05-01 10:00:00")
        XCTAssertTrue(plan.isApplyAllowed)
    }

    func testPostgresFractionalCreatedAtIsAccepted() throws {
        let productID = uuid(217)
        let plan = makePlan(
            remoteRows: [
                remotePrice(
                    productID: productID,
                    effectiveAt: "2026-05-01 10:00:00+00",
                    createdAt: "2026-05-09 03:02:17.696948"
                )
            ],
            localProducts: [
                localProduct(remoteID: productID, barcode: "100")
            ]
        )

        XCTAssertEqual(plan.summary.invalid, 0)
        XCTAssertNotNil(plan.linesToInsert.first?.createdAt)
        XCTAssertTrue(plan.isApplyAllowed)
    }

    func testWrongOwnerRemoteRowsAreInvalidAccessData() {
        let plan = makePlan(remoteRows: [
            remotePrice(ownerUserID: uuid(888))
        ])

        XCTAssertEqual(plan.summary.invalid, 1)
        XCTAssertEqual(plan.summary.sourceError, "owner mismatch")
        XCTAssertTrue(plan.blockReasons.contains(.sourceError))
        XCTAssertTrue(plan.blockReasons.contains(.invalidRows))
        XCTAssertFalse(plan.isApplyAllowed)
    }

    func testRemoteProductWithoutLocalProductIsUnmapped() {
        let plan = makePlan(
            remoteRows: [remotePrice(productID: uuid(404))],
            localProducts: []
        )

        XCTAssertEqual(plan.summary.unmapped, 1)
        XCTAssertTrue(plan.blockReasons.contains(.unmappedProducts))
        XCTAssertFalse(plan.isApplyAllowed)
    }

    func testSampledNoApplicablePlanDoesNotReportConcreteApplyWork() {
        let plan = ProductPriceApplyPlan(
            generatedAt: Date(timeIntervalSince1970: 1_778_500_000),
            sessionSnapshot: session,
            sourceState: ProductPriceApplySourceState(sampled: true),
            summary: ProductPriceApplySummary(
                remoteRead: 900,
                included: 0,
                skippedExisting: 900,
                unmapped: 0,
                invalid: 0,
                conflicts: 0,
                mappingConflicts: 0,
                partial: false,
                truncated: false,
                sourceError: nil
            ),
            blockReasons: [.noApplicableRows],
            linesToInsert: [],
            issues: [],
            remoteRows: []
        )

        XCTAssertTrue(plan.isApplyAllowed)
        XCTAssertFalse(plan.hasConcreteApplyWork)
    }

    func testBootstrapPreviewSampleComparesLocalPricesBeforeReportingNewWork() async throws {
        let context = try makeContext()
        let productIDs = (0..<30).map { uuid(990_000 + $0) }
        let products = try productIDs.enumerated().map { index, productID in
            try insertProduct(context: context, barcode: "TASK110-SAMPLE-\(index)", remoteID: productID)
        }
        let rows = makeRemotePriceRows(count: 900, productIDs: productIDs)
        for row in rows {
            let productIndex = try XCTUnwrap(productIDs.firstIndex(of: row.productID))
            context.insert(
                ProductPrice(
                    remoteID: row.id,
                    type: .purchase,
                    price: row.price,
                    effectiveAt: try XCTUnwrap(ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.effectiveAt)),
                    product: products[productIndex]
                )
            )
        }
        try context.save()
        let pagedService = SupabaseProductPriceApplyService(fetcher: ProductPricePagedFetcherFake(rows: rows))

        let samplePlan = try await pagedService.loadBootstrapPreviewSample(
            context: context,
            sessionSnapshot: session
        )

        XCTAssertEqual(samplePlan.summary.remoteRead, 900)
        XCTAssertEqual(samplePlan.summary.skippedExisting, 900)
        XCTAssertEqual(samplePlan.linesToInsert.count, 0)
        XCTAssertEqual(samplePlan.remoteIdentityLinks.count, 0)
        XCTAssertFalse(samplePlan.hasConcreteApplyWork)
    }

    func testDuplicateLocalProductRemoteIDIsMappingConflict() {
        let productID = uuid(205)
        let plan = makePlan(
            remoteRows: [remotePrice(productID: productID)],
            localProducts: [
                localProduct(remoteID: productID, barcode: "100"),
                localProduct(remoteID: productID, barcode: "101")
            ]
        )

        XCTAssertEqual(plan.summary.mappingConflicts, 1)
        XCTAssertEqual(plan.summary.conflicts, 1)
        XCTAssertTrue(plan.blockReasons.contains(.conflicts))
        XCTAssertFalse(plan.isApplyAllowed)
    }

    func testDuplicateRemoteLogicalRowsWithDifferentCanonicalPriceConflict() {
        let productID = uuid(210)
        let plan = makePlan(
            remoteRows: [
                remotePrice(id: uuid(301), productID: productID, price: 2.5),
                remotePrice(id: uuid(302), productID: productID, price: 2.6)
            ],
            localProducts: [
                localProduct(remoteID: productID, barcode: "100")
            ]
        )

        XCTAssertEqual(plan.summary.included, 1)
        XCTAssertEqual(plan.summary.conflicts, 1)
        XCTAssertTrue(plan.blockReasons.contains(.conflicts))
        XCTAssertFalse(plan.isApplyAllowed)
    }

    func testDuplicateRemoteLogicalRowsWithSameCanonicalPriceConflict() {
        let productID = uuid(216)
        let plan = makePlan(
            remoteRows: [
                remotePrice(id: uuid(501), productID: productID, price: 2.5),
                remotePrice(id: uuid(502), productID: productID, price: 2.5)
            ],
            localProducts: [
                localProduct(remoteID: productID, barcode: "100")
            ]
        )

        XCTAssertEqual(plan.summary.included, 1)
        XCTAssertEqual(plan.summary.conflicts, 1)
        XCTAssertTrue(plan.blockReasons.contains(.conflicts))
        XCTAssertFalse(plan.isApplyAllowed)
    }

    func testPartialTruncatedAndSourceErrorBlockApply() {
        let sourceStates: [ProductPriceApplySourceState] = [
            ProductPriceApplySourceState(partial: true),
            ProductPriceApplySourceState(truncated: true),
            ProductPriceApplySourceState(sourceError: "network")
        ]

        for sourceState in sourceStates {
            let plan = makePlan(sourceState: sourceState)

            XCTAssertFalse(plan.isApplyAllowed)
            XCTAssertFalse(plan.blockReasons.isEmpty)
        }
    }

    func testSessionMismatchRefusesApply() throws {
        let context = try makeContext()
        let productID = uuid(206)
        try insertProduct(context: context, barcode: "100", remoteID: productID)
        let plan = try service.prepareApplyPlan(
            remoteRows: [remotePrice(productID: productID)],
            context: context,
            sessionSnapshot: session
        )

        XCTAssertThrowsError(
            try service.apply(
                plan: plan,
                context: context,
                currentSessionSnapshot: ProductPriceApplySessionSnapshot(userID: uuid(999))
            )
        ) { error in
            XCTAssertEqual(error as? ProductPriceApplyError, .sessionMismatch)
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, 0)
    }

    func testDoubleApplyDoesNotDuplicateProductPrice() throws {
        let context = try makeContext()
        let productID = uuid(207)
        try insertProduct(context: context, barcode: "TASK049-DOUBLE-207", remoteID: productID)
        let plan = try service.prepareApplyPlan(
            remoteRows: [remotePrice(productID: productID)],
            context: context,
            sessionSnapshot: session
        )

        let first = try service.apply(plan: plan, context: context, currentSessionSnapshot: session)
        let second = try service.apply(plan: plan, context: context, currentSessionSnapshot: session)

        XCTAssertEqual(first.inserted, 1)
        XCTAssertEqual(first.skippedExisting, 0)
        XCTAssertEqual(second.inserted, 0)
        XCTAssertEqual(second.skippedExisting, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, 1)
    }

    func testApplyPersistsRemoteRowIDOnInsertedProductPrice() throws {
        let context = try makeContext()
        let productID = uuid(213)
        let remoteRowID = uuid(413)
        try insertProduct(context: context, barcode: "TASK085-REMOTE-213", remoteID: productID)
        let plan = try service.prepareApplyPlan(
            remoteRows: [remotePrice(id: remoteRowID, productID: productID)],
            context: context,
            sessionSnapshot: session
        )

        let result = try service.apply(plan: plan, context: context, currentSessionSnapshot: session)
        let prices = try context.fetch(FetchDescriptor<ProductPrice>())

        XCTAssertEqual(result.inserted, 1)
        XCTAssertEqual(result.remoteIdentityLinked, 0)
        XCTAssertEqual(prices.count, 1)
        XCTAssertEqual(prices.first?.remoteID, remoteRowID)
    }

    func testApplyLinksExistingProductPriceRemoteIDWithoutDuplicate() throws {
        let context = try makeContext()
        let productID = uuid(214)
        let remoteRowID = uuid(414)
        let product = try insertProduct(context: context, barcode: "TASK085-LINK-214", remoteID: productID)
        let existing = ProductPrice(
            type: .purchase,
            price: 2.5,
            effectiveAt: try date("2026-05-01 10:30:00"),
            product: product
        )
        context.insert(existing)
        try context.save()

        let plan = try service.prepareApplyPlan(
            remoteRows: [remotePrice(id: remoteRowID, productID: productID)],
            context: context,
            sessionSnapshot: session
        )

        XCTAssertEqual(plan.summary.included, 0)
        XCTAssertEqual(plan.summary.remoteIdentityLinks, 1)
        XCTAssertTrue(plan.isApplyAllowed)

        let result = try service.apply(plan: plan, context: context, currentSessionSnapshot: session)

        XCTAssertEqual(result.inserted, 0)
        XCTAssertEqual(result.remoteIdentityLinked, 1)
        XCTAssertEqual(result.skippedExisting, 1)
        XCTAssertEqual(existing.remoteID, remoteRowID)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, 1)
    }

    func testApplyUsesRemoteProductIdentityIfBarcodeChangesAfterDryRun() throws {
        let context = try makeContext()
        let productID = uuid(211)
        let product = try insertProduct(context: context, barcode: "TASK049-OLD-211", remoteID: productID)
        let plan = try service.prepareApplyPlan(
            remoteRows: [remotePrice(productID: productID)],
            context: context,
            sessionSnapshot: session
        )

        product.barcode = "TASK049-NEW-211"
        context.insert(
            ProductPrice(
                type: .purchase,
                price: 2.5,
                effectiveAt: try date("2026-05-01 10:30:00"),
                product: product
            )
        )
        try context.save()

        let result = try service.apply(plan: plan, context: context, currentSessionSnapshot: session)

        XCTAssertEqual(result.inserted, 0)
        XCTAssertEqual(result.skippedExisting, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, 1)
    }

    func testExistingProductPriceSameKeyDifferentPriceIsConflictAndNotUpdated() throws {
        let context = try makeContext()
        let productID = uuid(208)
        let product = try insertProduct(context: context, barcode: "100", remoteID: productID)
        let existing = ProductPrice(
            type: .purchase,
            price: 2.0,
            effectiveAt: try date("2026-05-01 10:30:00"),
            product: product
        )
        context.insert(existing)
        try context.save()

        let plan = try service.prepareApplyPlan(
            remoteRows: [remotePrice(productID: productID, price: 3.0)],
            context: context,
            sessionSnapshot: session
        )

        XCTAssertEqual(plan.summary.conflicts, 1)
        XCTAssertFalse(plan.isApplyAllowed)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, 1)
        XCTAssertEqual(existing.price, 2.0)
    }

    func testApplyDoesNotModifyProductCurrentPrices() throws {
        let context = try makeContext()
        let productID = uuid(209)
        let product = try insertProduct(
            context: context,
            barcode: "100",
            remoteID: productID,
            purchasePrice: 8.0,
            retailPrice: 10.0
        )
        let plan = try service.prepareApplyPlan(
            remoteRows: [remotePrice(productID: productID, type: "PURCHASE", price: 12.0)],
            context: context,
            sessionSnapshot: session
        )

        _ = try service.apply(plan: plan, context: context, currentSessionSnapshot: session)

        XCTAssertEqual(product.purchasePrice, 8.0)
        XCTAssertEqual(product.retailPrice, 10.0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, 1)
    }

    func testPostSaveVerificationFailureThrowsVerificationFailed() throws {
        let context = try makeContext()
        let productID = uuid(212)
        try insertProduct(context: context, barcode: "TASK049-VERIFY-212", remoteID: productID)
        let insertedRemote = remotePrice(id: uuid(401), productID: productID, type: "PURCHASE", price: 2.5)
        let omittedRemote = remotePrice(id: uuid(402), productID: productID, type: "RETAIL", price: 3.5)
        let basePlan = try service.prepareApplyPlan(
            remoteRows: [insertedRemote],
            context: context,
            sessionSnapshot: session
        )
        let line = try XCTUnwrap(basePlan.linesToInsert.first)
        let inconsistentPlan = ProductPriceApplyPlan(
            generatedAt: Date(),
            sessionSnapshot: session,
            sourceState: ProductPriceApplySourceState(),
            summary: ProductPriceApplySummary(
                remoteRead: 2,
                included: 1,
                skippedExisting: 0,
                unmapped: 0,
                invalid: 0,
                conflicts: 0,
                mappingConflicts: 0,
                partial: false,
                truncated: false,
                sourceError: nil
            ),
            blockReasons: [],
            linesToInsert: [line],
            issues: [],
            remoteRows: [insertedRemote, omittedRemote]
        )

        XCTAssertThrowsError(
            try service.apply(plan: inconsistentPlan, context: context, currentSessionSnapshot: session)
        ) { error in
            XCTAssertEqual(error as? ProductPriceApplyError, .verificationFailed)
        }
    }

    func testPagedFullPullAppliesLargeProductPriceHistoryWithoutFixedTotalLimit() async throws {
        let context = try makeContext()
        let productIDs = (0..<300).map { uuid(901_000 + $0) }
        for (index, productID) in productIDs.enumerated() {
            context.insert(Product(barcode: "TASK108-PAGED-\(index)", remoteID: productID, productName: "Local"))
        }
        try context.save()
        let rows = makeRemotePriceRows(count: 30_000, productIDs: productIDs)
        let fetcher = ProductPricePagedFetcherFake(rows: rows)
        let pagedService = SupabaseProductPriceApplyService(fetcher: fetcher)
        let samplePlan = try await pagedService.loadBootstrapPreviewSample(
            context: context,
            sessionSnapshot: session
        )
        var progress: [ProductPricePagedApplyProgress] = []

        let first = try await pagedService.applyPagedFullPull(
            plan: samplePlan,
            context: context,
            currentSessionSnapshot: session,
            onProgress: { progress.append($0) }
        )
        let second = try await pagedService.applyPagedFullPull(
            plan: samplePlan,
            context: context,
            currentSessionSnapshot: session
        )

        XCTAssertEqual(first.inserted, 30_000)
        XCTAssertEqual(first.totalConsidered, 30_000)
        XCTAssertEqual(second.inserted, 0)
        XCTAssertEqual(second.skippedExisting, 30_000)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, 30_000)
        XCTAssertTrue(progress.contains { $0.stage == .completed && $0.processedRows == 30_000 && $0.totalRows == 30_000 })
        let ranges = fetcher.rangeLog()
        XCTAssertTrue(ranges.contains("0...899"))
        XCTAssertTrue(ranges.contains("29700...30599"))
    }

    func testKeysetPagedFullPullCompletesThreePagesAndPublishesProgress() async throws {
        let context = try makeContext()
        let productIDs = (0..<30).map { uuid(970_000 + $0) }
        for (index, productID) in productIDs.enumerated() {
            context.insert(Product(barcode: "TASK108-KEYSET-\(index)", remoteID: productID, productName: "Local"))
        }
        try context.save()
        let rows = makeRemotePriceRows(count: 2_700, productIDs: productIDs)
        let fetcher = ProductPriceKeysetFetcherFake(rows: rows)
        let pagedService = SupabaseProductPriceApplyService(fetcher: fetcher)
        let samplePlan = try await pagedService.loadBootstrapPreviewSample(
            context: context,
            sessionSnapshot: session
        )
        var progress: [ProductPricePagedApplyProgress] = []

        let result = try await pagedService.applyPagedFullPull(
            plan: samplePlan,
            context: context,
            currentSessionSnapshot: session,
            onProgress: { progress.append($0) }
        )

        XCTAssertEqual(result.inserted, 2_700)
        XCTAssertEqual(result.totalConsidered, 2_700)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, 2_700)
        XCTAssertTrue(progress.contains { $0.stage == .applying && $0.processedRows == 900 && $0.totalRows == 2_700 })
        XCTAssertTrue(progress.contains { $0.stage == .applying && $0.processedRows == 1_800 && $0.totalRows == 2_700 })
        XCTAssertTrue(progress.contains { $0.stage == .completed && $0.processedRows == 2_700 && $0.totalRows == 2_700 })
        let afterIDLog = fetcher.afterIDLog()
        XCTAssertEqual(afterIDLog.count, 4)
        XCTAssertEqual(afterIDLog.first!, "nil")
        XCTAssertTrue(afterIDLog[1].hasPrefix("00000000"))
    }

    func testKeysetPagedFullPullSkipsTombstonedProductPrices() async throws {
        let context = try makeContext()
        let activeProductID = uuid(975_000)
        let deletedProductID = uuid(975_001)
        context.insert(Product(barcode: "TASK108-KEYSET-ACTIVE", remoteID: activeProductID, productName: "Local"))
        try context.save()
        let rows = [
            remotePrice(id: uuid(975_100), productID: activeProductID),
            remotePrice(id: uuid(975_101), productID: deletedProductID)
        ]
        let fetcher = ProductPriceKeysetFetcherFake(
            rows: rows,
            deletedProductIDs: [deletedProductID]
        )
        let pagedService = SupabaseProductPriceApplyService(fetcher: fetcher)
        let samplePlan = try await pagedService.loadBootstrapPreviewSample(
            context: context,
            sessionSnapshot: session
        )

        let result = try await pagedService.applyPagedFullPull(
            plan: samplePlan,
            context: context,
            currentSessionSnapshot: session
        )

        XCTAssertEqual(result.inserted, 1)
        XCTAssertEqual(result.skippedExisting, 1)
        XCTAssertEqual(result.totalConsidered, 2)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, 1)
    }

    func testPagedFullPullPrunesRemoteLinkedPricesMissingFromCompleteSnapshot() async throws {
        let context = try makeContext()
        let productID = uuid(976_000)
        let product = try insertProduct(
            context: context,
            barcode: "TASK114-PRICE-PRUNE",
            remoteID: productID
        )
        let keptRemoteID = uuid(976_100)
        let staleRemoteID = uuid(976_101)
        let keptPrice = ProductPrice(
            remoteID: keptRemoteID,
            type: .purchase,
            price: 2.5,
            effectiveAt: try date("2026-05-01 10:30:00"),
            product: product
        )
        let stalePrice = ProductPrice(
            remoteID: staleRemoteID,
            type: .retail,
            price: 9.9,
            effectiveAt: try date("2026-05-02 10:30:00"),
            product: product
        )
        context.insert(keptPrice)
        context.insert(stalePrice)
        try context.save()

        let rows = [
            remotePrice(
                id: keptRemoteID,
                productID: productID,
                type: "PURCHASE",
                price: 2.5,
                effectiveAt: "2026-05-01 10:30:00"
            )
        ]
        let fetcher = ProductPricePagedFetcherFake(rows: rows)
        let pagedService = SupabaseProductPriceApplyService(fetcher: fetcher)
        let samplePlan = try await pagedService.loadBootstrapPreviewSample(
            context: context,
            sessionSnapshot: session
        )

        let result = try await pagedService.applyPagedFullPull(
            plan: samplePlan,
            context: context,
            currentSessionSnapshot: session
        )

        XCTAssertEqual(result.prunedLocal, 1)
        let verifyContext = ModelContext(context.container)
        let prices = try verifyContext.fetch(FetchDescriptor<ProductPrice>())
        XCTAssertEqual(prices.count, 1)
        XCTAssertEqual(prices.first?.remoteID, keptRemoteID)
    }

    func testPagedFullPullReplacementPrunesLocalOnlyPricesMissingFromCompleteSnapshot() async throws {
        let context = try makeContext()
        let productID = uuid(977_000)
        let product = try insertProduct(
            context: context,
            barcode: "TASK125-PRICE-REPLACE",
            remoteID: productID
        )
        context.insert(
            ProductPrice(
                type: .retail,
                price: 9.9,
                effectiveAt: try date("2026-05-02 10:30:00"),
                product: product
            )
        )
        try context.save()

        let keptRemoteID = uuid(977_100)
        let rows = [
            remotePrice(
                id: keptRemoteID,
                productID: productID,
                type: "PURCHASE",
                price: 2.5,
                effectiveAt: "2026-05-01 10:30:00"
            )
        ]
        let fetcher = ProductPricePagedFetcherFake(rows: rows)
        let pagedService = SupabaseProductPriceApplyService(
            fetcher: fetcher,
            fetchOptions: ProductPriceApplyFetchOptions(
                fullPullSafetyLimit: nil,
                replaceLocalSnapshot: true
            )
        )
        let samplePlan = try await pagedService.loadBootstrapPreviewSample(
            context: context,
            sessionSnapshot: session
        )

        let result = try await pagedService.applyPagedFullPull(
            plan: samplePlan,
            context: context,
            currentSessionSnapshot: session
        )

        XCTAssertEqual(result.inserted, 1)
        XCTAssertEqual(result.prunedLocal, 1)
        let prices = try ModelContext(context.container).fetch(FetchDescriptor<ProductPrice>())
        XCTAssertEqual(prices.count, 1)
        XCTAssertEqual(prices.first?.remoteID, keptRemoteID)
    }

    func testPagedFullPullCanCancelLargeProductPriceHistoryWithoutFixedTotalLimit() async throws {
        let context = try makeContext()
        let productIDs = (0..<400).map { uuid(902_000 + $0) }
        for (index, productID) in productIDs.enumerated() {
            context.insert(Product(barcode: "TASK108-CANCEL-\(index)", remoteID: productID, productName: "Local"))
        }
        try context.save()
        let rows = makeRemotePriceRows(count: 120_000, productIDs: productIDs)
        let fetcher = ProductPricePagedFetcherFake(rows: rows, throwCancellationAtFrom: 3_000)
        let pagedService = SupabaseProductPriceApplyService(
            fetcher: fetcher,
            fetchOptions: ProductPriceApplyFetchOptions(fullPullSafetyLimit: nil)
        )
        let samplePlan = try await pagedService.loadBootstrapPreviewSample(
            context: context,
            sessionSnapshot: session
        )

        do {
            _ = try await pagedService.applyPagedFullPull(
                plan: samplePlan,
                context: context,
                currentSessionSnapshot: session
            )
            XCTFail("Expected paged full pull cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        let appliedCount = try context.fetch(FetchDescriptor<ProductPrice>()).count
        XCTAssertGreaterThan(appliedCount, 0)
        XCTAssertLessThan(appliedCount, 120_000)
        let ranges = fetcher.rangeLog()
        XCTAssertTrue(ranges.contains("0...899"))
        XCTAssertTrue(ranges.contains("3600...4499"))
    }

    func testPagedFullPullBlocksRemoteAboveDefaultSafetyLimit() async throws {
        let context = try makeContext()
        let productID = uuid(903_000)
        context.insert(Product(barcode: "TASK108-SAFETY", remoteID: productID, productName: "Local"))
        try context.save()
        let rows = makeRemotePriceRows(count: 75_001, productIDs: [productID])
        let fetcher = ProductPricePagedFetcherFake(rows: rows)
        let pagedService = SupabaseProductPriceApplyService(fetcher: fetcher)
        let samplePlan = try await pagedService.loadBootstrapPreviewSample(
            context: context,
            sessionSnapshot: session
        )
        let rangesBeforeApply = fetcher.rangeLog()

        do {
            _ = try await pagedService.applyPagedFullPull(
                plan: samplePlan,
                context: context,
                currentSessionSnapshot: session
            )
            XCTFail("Expected safety gate to block suspicious remote product price count")
        } catch let error as ProductPriceApplyError {
            guard case .remoteFetchFailed(let message) = error else {
                return XCTFail("Expected remoteFetchFailed, got \(error)")
            }
            let detail = try XCTUnwrap(message)
            XCTAssertTrue(detail.contains("75.001") || detail.contains("75001"))
            XCTAssertTrue(detail.contains("75.000") || detail.contains("75000"))
        }

        XCTAssertEqual(fetcher.rangeLog(), rangesBeforeApply)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, 0)
    }

    func testPagedFullPullFailsWhenRemoteEndsBeforeReportedCount() async throws {
        let context = try makeContext()
        let productIDs = (0..<30).map { uuid(980_000 + $0) }
        for (index, productID) in productIDs.enumerated() {
            context.insert(Product(barcode: "TASK108-PAGED-TRUNCATED-\(index)", remoteID: productID, productName: "Local"))
        }
        try context.save()
        let rows = makeRemotePriceRows(count: 1_800, productIDs: productIDs)
        let fetcher = ProductPricePagedFetcherFake(rows: rows, reportedCount: 2_700)
        let pagedService = SupabaseProductPriceApplyService(fetcher: fetcher)
        let samplePlan = try await pagedService.loadBootstrapPreviewSample(
            context: context,
            sessionSnapshot: session
        )

        do {
            _ = try await pagedService.applyPagedFullPull(
                plan: samplePlan,
                context: context,
                currentSessionSnapshot: session
            )
            XCTFail("Expected remoteFetchFailed when the remote page stream ends before count")
        } catch let error as ProductPriceApplyError {
            XCTAssertEqual(
                error,
                .remoteFetchFailed(message: "inventory_product_prices ended before reported count")
            )
        }
    }

    private func makePlan(
        remoteRows: [RemoteInventoryProductPriceRow]? = nil,
        localProducts: [ProductPriceApplyLocalProduct]? = nil,
        localPrices: [ProductPriceApplyLocalPrice] = [],
        sourceState: ProductPriceApplySourceState = ProductPriceApplySourceState()
    ) -> ProductPriceApplyPlan {
        let rows = remoteRows ?? [remotePrice()]
        let productID = rows.first?.productID ?? uuid(201)
        return service.prepareApplyPlan(
            remoteRows: rows,
            localSnapshot: ProductPriceApplyLocalSnapshot(
                products: localProducts ?? [localProduct(remoteID: productID, barcode: "100")],
                prices: localPrices
            ),
            sourceState: sourceState,
            sessionSnapshot: session
        )
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            ProductPrice.self,
            LocalPendingChange.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        let context = ModelContext(container)
        Self.retainedContexts.append(context)
        return context
    }

    @discardableResult
    private func insertProduct(
        context: ModelContext,
        barcode: String,
        remoteID: UUID?,
        purchasePrice: Double? = nil,
        retailPrice: Double? = nil
    ) throws -> Product {
        let product = Product(
            barcode: barcode,
            remoteID: remoteID,
            productName: "Local",
            purchasePrice: purchasePrice,
            retailPrice: retailPrice
        )
        context.insert(product)
        try context.save()
        return product
    }

    private func localProduct(
        remoteID: UUID?,
        barcode: String
    ) -> ProductPriceApplyLocalProduct {
        ProductPriceApplyLocalProduct(
            remoteID: remoteID,
            barcode: barcode,
            productName: "Local",
            purchasePrice: 8,
            retailPrice: 10
        )
    }

    private func localPrice(
        barcode: String,
        type: String = "purchase",
        price: Double,
        effectiveAt: Date? = nil
    ) -> ProductPriceApplyLocalPrice {
        ProductPriceApplyLocalPrice(
            productBarcode: barcode,
            type: type,
            price: price,
            effectiveAt: effectiveAt ?? ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: "2026-05-01 10:30:00")!
        )
    }

    private func remotePrice(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
        ownerUserID: UUID? = nil,
        productID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
        type: String = "PURCHASE",
        price: Double = 2.5,
        effectiveAt: String = "2026-05-01 10:30:00",
        createdAt: String = "2026-05-01 10:31:00"
    ) -> RemoteInventoryProductPriceRow {
        RemoteInventoryProductPriceRow(
            id: id,
            ownerUserID: ownerUserID ?? session.userID,
            productID: productID,
            type: type,
            price: price,
            effectiveAt: effectiveAt,
            source: "TEST",
            note: "private note",
            createdAt: createdAt
        )
    }

    private func makeRemotePriceRows(count: Int, productIDs: [UUID]) -> [RemoteInventoryProductPriceRow] {
        let baseDate = Date(timeIntervalSince1970: 1_779_000_000)
        precondition(!productIDs.isEmpty)
        return (0..<count).map { index in
            let productID = productIDs[index % productIDs.count]
            return remotePrice(
                id: uuid(1_000_000 + index),
                productID: productID,
                price: 2.5 + Double(index % 100) / 100,
                effectiveAt: ProductPriceEffectiveAtCanonicalizer.canonicalString(
                    from: baseDate.addingTimeInterval(TimeInterval(index))
                ),
                createdAt: ProductPriceEffectiveAtCanonicalizer.canonicalString(
                    from: baseDate.addingTimeInterval(TimeInterval(index + 1))
                )
            )
        }
    }

    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: value))
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", value))")!
    }
}

@MainActor
private final class ProductPricePagedFetcherFake: SupabaseProductPricePreviewFetching {
    private let rows: [RemoteInventoryProductPriceRow]
    private let reportedCount: Int?
    private let throwCancellationAtFrom: Int?
    private var ranges: [String] = []

    init(rows: [RemoteInventoryProductPriceRow], reportedCount: Int? = nil, throwCancellationAtFrom: Int? = nil) {
        self.rows = rows
        self.reportedCount = reportedCount
        self.throwCancellationAtFrom = throwCancellationAtFrom
    }

    func rangeLog() -> [String] {
        ranges
    }

    func fetchProductPriceCount() async throws -> Int? {
        reportedCount ?? rows.count
    }

    func fetchProductPricesPreviewPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        ranges.append("\(from)...\(to)")
        if let throwCancellationAtFrom, from >= throwCancellationAtFrom {
            throw CancellationError()
        }
        guard from < rows.count else { return [] }
        return Array(rows[from..<min(rows.count, to + 1)])
    }
}

@MainActor
private final class ProductPriceKeysetFetcherFake: SupabaseProductPriceKeysetFetching, SupabaseProductPriceDeletedProductFetching {
    private let rows: [RemoteInventoryProductPriceRow]
    private let deletedProductIDs: Set<UUID>
    private var afterIDs: [String] = []

    init(rows: [RemoteInventoryProductPriceRow], deletedProductIDs: Set<UUID> = []) {
        self.rows = rows
        self.deletedProductIDs = deletedProductIDs
    }

    func afterIDLog() -> [String] {
        afterIDs
    }

    func fetchProductPriceCount() async throws -> Int? {
        rows.count
    }

    func fetchDeletedProductIDs(pageSize: Int) async throws -> Set<UUID> {
        deletedProductIDs
    }

    func fetchProductPricesPreviewPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        guard from < rows.count else { return [] }
        return Array(rows[from..<min(rows.count, to + 1)])
    }

    func fetchProductPricesPreviewPage(afterID: UUID?, limit: Int) async throws -> [RemoteInventoryProductPriceRow] {
        afterIDs.append(afterID?.uuidString ?? "nil")
        let startIndex: Int
        if let afterID,
           let index = rows.firstIndex(where: { $0.id == afterID }) {
            startIndex = index + 1
        } else {
            startIndex = 0
        }
        guard startIndex < rows.count else { return [] }
        return Array(rows[startIndex..<min(rows.count, startIndex + limit)])
    }
}
