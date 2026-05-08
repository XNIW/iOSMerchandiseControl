import XCTest
import Foundation
import SwiftData
@testable import iOSMerchandiseControl

@MainActor
final class SupabasePullApplyServiceTests: XCTestCase {
    private let service = SupabasePullApplyService()
    private static var retainedContainers: [ModelContainer] = []
    private static var retainedContexts: [ModelContext] = []

    func testPrepareApplyPlanBlocksPartialPreview() throws {
        let context = try makeContext()
        let preview = makePreview(outcome: .partial, newProducts: [
            makeSummary(payload: makePayload(barcode: "100", productName: "Remote"))
        ])

        try assertPrepareThrows(.partialPreview, preview: preview, context: context)
    }

    func testPrepareApplyPlanBlocksSourceErrors() throws {
        let context = try makeContext()
        let preview = makePreview(
            newProducts: [makeSummary(payload: makePayload(barcode: "100", productName: "Remote"))],
            sourceErrors: [
                SyncPreviewWarning(code: .sourceError, detail: "inventory_products", relatedKey: "inventory_products")
            ]
        )

        try assertPrepareThrows(.sourceErrorsPresent, preview: preview, context: context)
    }

    func testPrepareApplyPlanBlocksPriceHistoryIncomplete() throws {
        let context = try makeContext()
        let preview = makePreview(
            newProducts: [makeSummary(payload: makePayload(barcode: "100", productName: "Remote"))],
            sourceErrors: [
                SyncPreviewWarning(code: .priceHistoryIncomplete, detail: "inventory_product_prices", relatedKey: "inventory_product_prices")
            ]
        )

        try assertPrepareThrows(.priceHistoryIncomplete, preview: preview, context: context)
    }

    func testPrepareApplyPlanBlocksConflicts() throws {
        let context = try makeContext()
        let preview = makePreview(
            newProducts: [makeSummary(payload: makePayload(barcode: "100", productName: "Remote"))],
            conflicts: [
                SyncPreviewConflict(kind: .remoteDuplicateBarcode, barcodeOrKey: "100")
            ]
        )

        try assertPrepareThrows(.conflictsPresent, preview: preview, context: context)
    }

    func testPrepareApplyPlanBlocksSessionMissing() throws {
        let context = try makeContext()
        let preview = makePreview(newProducts: [
            makeSummary(payload: makePayload(barcode: "100", productName: "Remote"))
        ])

        XCTAssertThrowsError(
            try service.prepareApplyPlan(
                preview: preview,
                context: context,
                isAuthenticated: false
            )
        ) { error in
            XCTAssertEqual(error as? SupabasePullApplyError, .sessionMissing)
        }
    }

    func testPrepareApplyPlanBlocksMissingApplicablePayloadForNewProducts() throws {
        let context = try makeContext()
        let preview = makePreview(newProducts: [
            makeSummary(barcode: "100", productName: "Remote", payload: nil)
        ])

        XCTAssertThrowsError(try prepare(preview, context: context)) { error in
            guard case .missingApplicablePayload(let barcode) = error as? SupabasePullApplyError else {
                return XCTFail("Expected missingApplicablePayload, got \(error)")
            }
            XCTAssertEqual(barcode, "100")
        }
    }

    func testPrepareApplyPlanBlocksMissingApplicablePayloadForUpdateCandidates() throws {
        let context = try makeContext()
        try insertProduct(context: context, barcode: "100", productName: "Local")

        let preview = makePreview(updateCandidates: [
            makeSummary(classification: .updateCandidate, barcode: "100", productName: "Remote", payload: nil)
        ])

        XCTAssertThrowsError(try prepare(preview, context: context)) { error in
            guard case .missingApplicablePayload(let barcode) = error as? SupabasePullApplyError else {
                return XCTFail("Expected missingApplicablePayload, got \(error)")
            }
            XCTAssertEqual(barcode, "100")
        }
    }

    func testMissingRequiredFieldWhenNewProductHasNoProductNameNorSecondProductName() throws {
        let context = try makeContext()
        let preview = makePreview(newProducts: [
            makeSummary(payload: makePayload(barcode: "100", productName: " ", secondProductName: nil))
        ])

        XCTAssertThrowsError(try prepare(preview, context: context)) { error in
            guard case .missingRequiredField(let barcode, let field) = error as? SupabasePullApplyError else {
                return XCTFail("Expected missingRequiredField, got \(error)")
            }
            XCTAssertEqual(barcode, "100")
            XCTAssertEqual(field, "productName")
        }
    }

    func testApplyFailsPreviewStaleIfLocalDatabaseChangesBetweenPrepareAndApply() throws {
        let context = try makeContext()
        let product = try insertProduct(context: context, barcode: "100", productName: "Local", retailPrice: 1)
        let preview = makePreview(updateCandidates: [
            makeSummary(
                classification: .updateCandidate,
                payload: makePayload(barcode: "100", productName: "Remote", retailPrice: 2)
            )
        ])
        let plan = try prepare(preview, context: context)

        product.productName = "Changed locally"
        try context.save()

        XCTAssertThrowsError(try service.apply(plan: plan, context: context)) { error in
            XCTAssertEqual(error as? SupabasePullApplyError, .previewStale)
        }
        XCTAssertEqual(product.productName, "Changed locally")
    }

    func testExistingProductBarcodeNeverChanges() throws {
        let context = try makeContext()
        let product = try insertProduct(context: context, barcode: "100", productName: "Local", retailPrice: 1)
        let remoteID = UUID()
        let remoteUpdatedAt = Date(timeIntervalSince1970: 1_777_500_001)
        let preview = makePreview(updateCandidates: [
            makeSummary(
                classification: .updateCandidate,
                payload: makePayload(
                    remoteID: remoteID,
                    remoteUpdatedAt: remoteUpdatedAt,
                    barcode: "100",
                    productName: "Remote",
                    retailPrice: 2
                )
            )
        ])

        let result = try service.apply(plan: try prepare(preview, context: context), context: context)

        XCTAssertEqual(result.updated, 1)
        XCTAssertEqual(product.barcode, "100")
        XCTAssertEqual(product.productName, "Remote")
        XCTAssertEqual(product.remoteID, remoteID)
        XCTAssertEqual(product.remoteUpdatedAt, remoteUpdatedAt)
    }

    func testLinkOnlySetsRemoteIDWithoutDuplicatingProduct() throws {
        let context = try makeContext()
        let remoteID = UUID()
        let product = try insertProduct(context: context, barcode: "100", productName: "Remote")
        let preview = makePreview(updateCandidates: [
            makeSummary(
                classification: .linkOnly,
                payload: makePayload(remoteID: remoteID, barcode: "100", productName: "Remote")
            )
        ])

        let result = try service.apply(plan: try prepare(preview, context: context), context: context)

        XCTAssertEqual(result.updated, 1)
        XCTAssertEqual(product.remoteID, remoteID)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Product>()).count, 1)
    }

    func testCreateLocalSetsRemoteIDMetadata() throws {
        let context = try makeContext()
        let remoteID = UUID()
        let remoteUpdatedAt = Date(timeIntervalSince1970: 1_777_500_101)
        let preview = makePreview(newProducts: [
            makeSummary(payload: makePayload(
                remoteID: remoteID,
                remoteUpdatedAt: remoteUpdatedAt,
                barcode: "100",
                productName: "Remote"
            ))
        ])

        let result = try service.apply(plan: try prepare(preview, context: context), context: context)
        let product = try XCTUnwrap(try context.fetch(FetchDescriptor<Product>()).first)

        XCTAssertEqual(result.inserted, 1)
        XCTAssertEqual(product.remoteID, remoteID)
        XCTAssertEqual(product.remoteUpdatedAt, remoteUpdatedAt)
    }

    func testNilOrEmptyRemoteValuesDoNotClearLocalFields() throws {
        let context = try makeContext()
        let product = try insertProduct(
            context: context,
            barcode: "100",
            itemNumber: "ITEM-1",
            productName: "Local",
            secondProductName: "Second",
            retailPrice: 1
        )
        let preview = makePreview(updateCandidates: [
            makeSummary(
                classification: .updateCandidate,
                payload: makePayload(
                    barcode: "100",
                    itemNumber: " ",
                    productName: nil,
                    secondProductName: "",
                    retailPrice: 2
                )
            )
        ])

        _ = try service.apply(plan: try prepare(preview, context: context), context: context)

        XCTAssertEqual(product.itemNumber, "ITEM-1")
        XCTAssertEqual(product.productName, "Local")
        XCTAssertEqual(product.secondProductName, "Second")
        XCTAssertEqual(product.retailPrice, 2)
    }

    func testInvalidPricesAreBlocked() throws {
        let invalidPayloads = [
            makePayload(barcode: "100", productName: "Remote", purchasePrice: .nan),
            makePayload(barcode: "101", productName: "Remote", purchasePrice: .infinity),
            makePayload(barcode: "102", productName: "Remote", retailPrice: -1)
        ]

        for payload in invalidPayloads {
            let context = try makeContext()
            let preview = makePreview(newProducts: [makeSummary(payload: payload)])

            XCTAssertThrowsError(try prepare(preview, context: context)) { error in
                guard case .invalidPrice = error as? SupabasePullApplyError else {
                    return XCTFail("Expected invalidPrice, got \(error)")
                }
            }
        }
    }

    func testNegativeStockIsBlockedWhenApplyStockQuantityIsTrue() throws {
        let context = try makeContext()
        let preview = makePreview(newProducts: [
            makeSummary(payload: makePayload(barcode: "100", productName: "Remote", stockQuantity: -1))
        ])

        XCTAssertThrowsError(
            try service.prepareApplyPlan(
                preview: preview,
                context: context,
                options: SupabasePullApplyOptions(applyStockQuantity: true),
                isAuthenticated: true
            )
        ) { error in
            XCTAssertEqual(error as? SupabasePullApplyError, .invalidStockQuantity(barcode: "100"))
        }
    }

    func testStockIsIgnoredByDefaultWhenApplyStockQuantityIsFalse() throws {
        let context = try makeContext()
        let preview = makePreview(newProducts: [
            makeSummary(payload: makePayload(barcode: "100", productName: "Remote", stockQuantity: -1))
        ])

        let result = try service.apply(plan: try prepare(preview, context: context), context: context)
        let products = try context.fetch(FetchDescriptor<Product>())

        XCTAssertEqual(result.inserted, 1)
        XCTAssertEqual(products.first?.stockQuantity, nil)
    }

    func testSaveFailurePathRollsBackBeforeSurfacingError() throws {
        let source = try readSource("iOSMerchandiseControl/SupabasePullApplyService.swift")
        let saveRange = try XCTUnwrap(source.range(of: "try context.save()"))
        let rollbackRange = try XCTUnwrap(source.range(of: "context.rollback()", range: saveRange.upperBound..<source.endIndex))
        let saveFailedRange = try XCTUnwrap(source.range(of: "SupabasePullApplyError.saveFailed", range: rollbackRange.upperBound..<source.endIndex))

        XCTAssertLessThan(rollbackRange.lowerBound, saveFailedRange.lowerBound)
    }

    func testSupplierAndCategoryReuseCaseInsensitive() throws {
        let context = try makeContext()
        context.insert(Supplier(name: "Acme"))
        context.insert(ProductCategory(name: "Shelf"))
        try context.save()

        let preview = makePreview(newProducts: [
            makeSummary(payload: makePayload(
                barcode: "100",
                productName: "Remote",
                supplierName: "acme",
                categoryName: "SHELF"
            ))
        ])

        let result = try service.apply(plan: try prepare(preview, context: context), context: context)
        let products = try context.fetch(FetchDescriptor<Product>())

        XCTAssertEqual(result.suppliersCreated, 0)
        XCTAssertEqual(result.categoriesCreated, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Supplier>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductCategory>()).count, 1)
        XCTAssertEqual(products.first?.supplier?.name, "Acme")
        XCTAssertEqual(products.first?.category?.name, "Shelf")
    }

    func testApplyBlocksSupplierSameNameDifferentRemoteID() throws {
        let context = try makeContext()
        context.insert(Supplier(name: "Acme", remoteID: UUID()))
        try context.save()

        let preview = makePreview(newProducts: [
            makeSummary(payload: makePayload(
                barcode: "100",
                productName: "Remote",
                supplierName: "Acme",
                supplierRemoteID: UUID()
            ))
        ])

        XCTAssertThrowsError(try service.apply(plan: try prepare(preview, context: context), context: context)) { error in
            XCTAssertEqual(error as? SupabasePullApplyError, .previewStale)
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<Supplier>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Product>()).count, 0)
    }

    func testNoProductPriceRowsAreCreated() throws {
        let context = try makeContext()
        let preview = makePreview(newProducts: [
            makeSummary(payload: makePayload(
                barcode: "100",
                productName: "Remote",
                purchasePrice: 1,
                retailPrice: 2
            ))
        ])

        _ = try service.apply(plan: try prepare(preview, context: context), context: context)

        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, 0)
    }

    func testTombstonePreviewOnlyDoesNotDeleteLocalProduct() throws {
        let context = try makeContext()
        try insertProduct(context: context, barcode: "100", productName: "Local")
        let preview = makePreview()

        XCTAssertThrowsError(try prepare(preview, context: context)) { error in
            XCTAssertEqual(error as? SupabasePullApplyError, .noApplicableChanges)
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<Product>()).count, 1)
    }

    func testAccountMismatchBlocksApplyRelink() throws {
        let context = try makeContext()
        let preview = makePreview(newProducts: [
            makeSummary(payload: makePayload(barcode: "100", productName: "Remote"))
        ])

        XCTAssertThrowsError(
            try service.prepareApplyPlan(
                preview: preview,
                context: context,
                isAuthenticated: true,
                accountGuard: SupabasePullApplyAccountGuard(
                    currentUserID: UUID(),
                    lastLinkedUserID: UUID()
                )
            )
        ) { error in
            XCTAssertEqual(error as? SupabasePullApplyError, .accountMismatch)
        }
    }

    func testPartialPreviewDoesNotOverwriteExistingRemoteID() throws {
        let context = try makeContext()
        let existingRemoteID = UUID()
        let attemptedRemoteID = UUID()
        let product = try insertProduct(
            context: context,
            barcode: "100",
            productName: "Local",
            remoteID: existingRemoteID
        )
        let preview = makePreview(outcome: .partial, updateCandidates: [
            makeSummary(
                classification: .updateCandidate,
                payload: makePayload(remoteID: attemptedRemoteID, barcode: "100", productName: "Remote")
            )
        ])

        XCTAssertThrowsError(try prepare(preview, context: context)) { error in
            XCTAssertEqual(error as? SupabasePullApplyError, .partialPreview)
        }
        XCTAssertEqual(product.remoteID, existingRemoteID)
    }

    func testSamePlanSecondApplyDoesNotDuplicateAndDoesNotMutate() throws {
        let context = try makeContext()
        let preview = makePreview(newProducts: [
            makeSummary(payload: makePayload(
                barcode: "100",
                productName: "Remote",
                supplierName: "Acme",
                categoryName: "Shelf"
            ))
        ])
        let plan = try prepare(preview, context: context)

        let firstResult = try service.apply(plan: plan, context: context)
        let productsAfterFirstApply = try context.fetch(FetchDescriptor<Product>())
        XCTAssertEqual(firstResult.inserted, 1)
        XCTAssertEqual(productsAfterFirstApply.count, 1)

        XCTAssertThrowsError(try service.apply(plan: plan, context: context)) { error in
            XCTAssertEqual(error as? SupabasePullApplyError, .previewStale)
        }

        let productsAfterSecondApply = try context.fetch(FetchDescriptor<Product>())
        XCTAssertEqual(productsAfterSecondApply.count, 1)
        XCTAssertEqual(productsAfterSecondApply.first?.productName, "Remote")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Supplier>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductCategory>()).count, 1)
    }

    func testSameFullPullAfterApplyDoesNotCreateDuplicates() throws {
        let context = try makeContext()
        let remoteID = UUID()
        let firstPreview = makePreview(newProducts: [
            makeSummary(payload: makePayload(
                remoteID: remoteID,
                barcode: "100",
                productName: "Remote",
                supplierName: "Acme",
                categoryName: "Shelf"
            ))
        ])

        _ = try service.apply(plan: try prepare(firstPreview, context: context), context: context)

        let secondPreview = makePreview(updateCandidates: [
            makeSummary(
                classification: .updateCandidate,
                payload: makePayload(
                    remoteID: remoteID,
                    barcode: "100",
                    productName: "Remote",
                    supplierName: "Acme",
                    categoryName: "Shelf"
                )
            )
        ])

        XCTAssertThrowsError(try prepare(secondPreview, context: context)) { error in
            XCTAssertEqual(error as? SupabasePullApplyError, .noApplicableChanges)
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<Product>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Supplier>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductCategory>()).count, 1)
    }

    func testApplyServiceHasNoNetworkServiceDependency() {
        _ = SupabasePullApplyService()
    }

    private func prepare(
        _ preview: SyncPreview,
        context: ModelContext,
        options: SupabasePullApplyOptions = SupabasePullApplyOptions()
    ) throws -> SupabasePullApplyPlan {
        try service.prepareApplyPlan(
            preview: preview,
            context: context,
            options: options,
            isAuthenticated: true
        )
    }

    private func assertPrepareThrows(
        _ expected: SupabasePullApplyError,
        preview: SyncPreview,
        context: ModelContext
    ) throws {
        XCTAssertThrowsError(try prepare(preview, context: context)) { error in
            XCTAssertEqual(error as? SupabasePullApplyError, expected)
        }
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

    private func readSource(_ relativePath: String) throws -> String {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func makePreview(
        outcome: SyncPreviewOutcome = .success,
        newProducts: [SyncPreviewProductSummary] = [],
        updateCandidates: [SyncPreviewProductSummary] = [],
        conflicts: [SyncPreviewConflict] = [],
        warnings: [SyncPreviewWarning] = [],
        sourceErrors: [SyncPreviewWarning] = []
    ) -> SyncPreview {
        SyncPreview(
            generatedAt: Date(timeIntervalSince1970: 1_777_777_777),
            outcome: outcome,
            remoteCounts: RemoteInventorySnapshotCounts(
                products: newProducts.count + updateCandidates.count,
                activeProducts: newProducts.count + updateCandidates.count,
                tombstonedProducts: 0,
                suppliers: 0,
                categories: 0,
                productPrices: 0
            ),
            localCounts: LocalInventorySnapshotCounts(
                products: updateCandidates.count,
                suppliers: 0,
                categories: 0,
                productPrices: 0
            ),
            newProducts: newProducts,
            updateCandidates: updateCandidates,
            conflicts: conflicts,
            unchangedProducts: [],
            remoteTombstones: [],
            supplierDiffs: [],
            categoryDiffs: [],
            priceHistoryDiffs: [],
            warnings: warnings,
            metrics: [],
            sourceErrors: sourceErrors
        )
    }

    private func makeSummary(
        classification: SyncPreviewClassification = .newProduct,
        barcode: String? = nil,
        productName: String? = nil,
        payload: SyncPreviewProductApplyPayload?
    ) -> SyncPreviewProductSummary {
        SyncPreviewProductSummary(
            classification: classification,
            remoteID: payload?.remoteID,
            barcode: barcode ?? payload?.barcode,
            productName: productName ?? payload?.productName,
            applyPayload: payload
        )
    }

    private func makePayload(
        remoteID: UUID = UUID(),
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil,
        barcode: String?,
        itemNumber: String? = nil,
        productName: String? = "Remote",
        secondProductName: String? = nil,
        purchasePrice: Double? = nil,
        retailPrice: Double? = nil,
        stockQuantity: Double? = nil,
        supplierName: String? = nil,
        supplierRemoteID: UUID? = nil,
        categoryName: String? = nil
    ) -> SyncPreviewProductApplyPayload {
        SyncPreviewProductApplyPayload(
            remoteID: remoteID,
            remoteUpdatedAt: remoteUpdatedAt,
            remoteDeletedAt: remoteDeletedAt,
            barcode: barcode,
            itemNumber: itemNumber,
            productName: productName,
            secondProductName: secondProductName,
            purchasePrice: purchasePrice,
            retailPrice: retailPrice,
            stockQuantity: stockQuantity,
            supplierName: supplierName,
            supplierRemoteID: supplierRemoteID,
            categoryName: categoryName
        )
    }

    @discardableResult
    private func insertProduct(
        context: ModelContext,
        barcode: String,
        itemNumber: String? = nil,
        productName: String?,
        secondProductName: String? = nil,
        purchasePrice: Double? = nil,
        retailPrice: Double? = nil,
        stockQuantity: Double? = nil,
        supplierName: String? = nil,
        categoryName: String? = nil,
        remoteID: UUID? = nil,
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil
    ) throws -> Product {
        let supplier = supplierName.map { Supplier(name: $0) }
        let category = categoryName.map { ProductCategory(name: $0) }
        if let supplier {
            context.insert(supplier)
        }
        if let category {
            context.insert(category)
        }
        let product = Product(
            barcode: barcode,
            remoteID: remoteID,
            remoteUpdatedAt: remoteUpdatedAt,
            remoteDeletedAt: remoteDeletedAt,
            itemNumber: itemNumber,
            productName: productName,
            secondProductName: secondProductName,
            purchasePrice: purchasePrice,
            retailPrice: retailPrice,
            stockQuantity: stockQuantity,
            supplier: supplier,
            category: category
        )
        context.insert(product)
        try context.save()
        return product
    }
}
