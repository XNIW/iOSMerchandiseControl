import XCTest
import SwiftData
@testable import iOSMerchandiseControl

@MainActor
final class SupabaseCatalogBaselineWriterReaderTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private static var retainedContexts: [ModelContext] = []

    func testSuccessfulCommitMakesLatestValidBaselineAvailable() throws {
        let context = try makeContext()
        let ownerID = UUID()
        let productID = UUID()
        let supplierID = UUID()
        let categoryID = UUID()
        try insertCatalog(
            context: context,
            productRemoteID: productID,
            supplierRemoteID: supplierID,
            categoryRemoteID: categoryID,
            productName: "Remote"
        )

        let result = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        let read = try SupabaseCatalogBaselineReader().readManualPushBaseline(
            context: context,
            ownerUserUUID: ownerID
        )

        XCTAssertEqual(result.productCount, 1)
        XCTAssertEqual(result.supplierCount, 1)
        XCTAssertEqual(result.categoryCount, 1)
        guard case .available(let snapshot) = read else {
            return XCTFail("Expected available baseline, got \(read)")
        }
        XCTAssertEqual(snapshot.runID, result.baselineRunID)
        XCTAssertEqual(
            snapshot.baseline.productFingerprintsByRemoteID[productID]?.canonicalString,
            try localProductFingerprint(context: context).canonicalString
        )
    }

    func testFailedCommitDoesNotCreateLatestValidBaseline() throws {
        let context = try makeContext()
        let ownerID = UUID()
        let duplicatedRemoteID = UUID()
        context.insert(Product(barcode: "100", remoteID: duplicatedRemoteID, productName: "First"))
        context.insert(Product(barcode: "101", remoteID: duplicatedRemoteID, productName: "Second"))
        try context.save()

        XCTAssertThrowsError(
            try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(
                context: context,
                ownerUserUUID: ownerID
            )
        )

        let read = try SupabaseCatalogBaselineReader().readManualPushBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        XCTAssertEqual(read, .incomplete)
    }

    func testPreviousValidRunRemainsSelectedWhenNewRunFails() throws {
        let context = try makeContext()
        let ownerID = UUID()
        let firstRemoteID = UUID()
        try insertCatalog(context: context, productRemoteID: firstRemoteID, productName: "First")
        let first = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )

        context.insert(Product(barcode: "duplicate", remoteID: firstRemoteID, productName: "Duplicate"))
        try context.save()
        XCTAssertThrowsError(
            try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(
                context: context,
                ownerUserUUID: ownerID
            )
        )

        let read = try SupabaseCatalogBaselineReader().readManualPushBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        guard case .available(let snapshot) = read else {
            return XCTFail("Expected previous valid baseline, got \(read)")
        }
        XCTAssertEqual(snapshot.runID, first.baselineRunID)
    }

    func testBuildingAndPartialRejectedRunsAreIgnoredByReader() throws {
        let context = try makeContext()
        let ownerID = UUID()
        context.insert(SupabaseCatalogBaselineRun(ownerUserUUID: ownerID, status: .building))
        context.insert(SupabaseCatalogBaselineRun(ownerUserUUID: ownerID, status: .partialRejected))
        try context.save()

        let read = try SupabaseCatalogBaselineReader().readManualPushBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        XCTAssertEqual(read, .incomplete)
    }

    func testStaleStatusBlocksAsStaleSchema() throws {
        let context = try makeContext()
        let ownerID = UUID()
        context.insert(SupabaseCatalogBaselineRun(ownerUserUUID: ownerID, status: .stale))
        try context.save()

        let read = try SupabaseCatalogBaselineReader().readManualPushBaseline(
            context: context,
            ownerUserUUID: ownerID
        )

        XCTAssertEqual(read, .staleSchema)
    }

    func testTwoHistoricalRunsCanContainSameRemoteID() throws {
        let context = try makeContext()
        let ownerID = UUID()
        let remoteID = UUID()
        try insertCatalog(context: context, productRemoteID: remoteID, productName: "First")
        let first = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )

        let product = try XCTUnwrap(try context.fetch(FetchDescriptor<Product>()).first)
        product.productName = "Second"
        try context.save()
        let second = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )

        let records = try context.fetch(FetchDescriptor<SupabaseCatalogBaselineRecord>())
            .filter { $0.entityType == SupabaseCatalogBaselineEntityType.product.rawValue && $0.remoteID == remoteID }
        XCTAssertEqual(records.count, 2)
        XCTAssertNotEqual(first.baselineRunID, second.baselineRunID)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            ProductPrice.self,
            HistoryEntry.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        let context = ModelContext(container)
        Self.retainedContexts.append(context)
        return context
    }

    private func insertCatalog(
        context: ModelContext,
        productRemoteID: UUID,
        supplierRemoteID: UUID? = nil,
        categoryRemoteID: UUID? = nil,
        productName: String
    ) throws {
        let supplier = supplierRemoteID.map { Supplier(name: "Acme", remoteID: $0) }
        let category = categoryRemoteID.map { ProductCategory(name: "Shelf", remoteID: $0) }
        if let supplier {
            context.insert(supplier)
        }
        if let category {
            context.insert(category)
        }
        context.insert(Product(
            barcode: "100",
            remoteID: productRemoteID,
            itemNumber: "SKU",
            productName: productName,
            purchasePrice: 1,
            retailPrice: 2,
            stockQuantity: 3,
            supplier: supplier,
            category: category
        ))
        try context.save()
    }

    private func localProductFingerprint(context: ModelContext) throws -> ManualPushFingerprint {
        let product = try XCTUnwrap(try context.fetch(FetchDescriptor<Product>()).first)
        return ManualPushFingerprintNormalizer.product(
            barcode: product.barcode,
            itemNumber: product.itemNumber,
            productName: product.productName,
            secondProductName: product.secondProductName,
            purchasePrice: product.purchasePrice,
            retailPrice: product.retailPrice,
            stockQuantity: product.stockQuantity,
            supplierRemoteID: product.supplier?.remoteID,
            categoryRemoteID: product.category?.remoteID
        )
    }

    private func clock() -> () -> Date {
        var offset: TimeInterval = 0
        return {
            offset += 1
            return Date(timeIntervalSince1970: 1_778_200_000 + offset)
        }
    }
}
