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
        XCTAssertEqual(plan.summary.conflicts, 0)
        XCTAssertFalse(plan.isApplyAllowed)
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
        XCTAssertEqual(plan.summary.invalid, 0)
        XCTAssertFalse(plan.isApplyAllowed)
    }

    func testInvalidEffectiveAtIsInvalid() {
        let plan = makePlan(remoteRows: [remotePrice(effectiveAt: "not-a-date")])

        XCTAssertEqual(plan.summary.invalid, 1)
        XCTAssertTrue(plan.blockReasons.contains(.invalidRows))
        XCTAssertFalse(plan.isApplyAllowed)
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
            ProductPrice.self
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

    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: value))
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", value))")!
    }
}
