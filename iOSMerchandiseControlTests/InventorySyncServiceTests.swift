import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class InventorySyncServiceTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private static var retainedContexts: [ModelContext] = []

    override func tearDownWithError() throws {
        Self.retainedContexts.removeAll()
        Self.retainedContainers.removeAll()
        try super.tearDownWithError()
    }

    func testGeneratedInventorySyncRecordsPendingAndAvoidsDuplicatePriceOnRetry() throws {
        let context = try makeContext()
        let ownerID = UUID(uuidString: "10800000-0000-4000-8000-000000000001")!
        let product = Product(
            barcode: "TASK108-BARCODE-1",
            retailPrice: 10,
            stockQuantity: nil
        )
        let entry = HistoryEntry(
            id: "TASK108-GENERATED",
            data: [
                ["barcode", "quantity", "realQuantity", "RetailPrice"],
                ["TASK108-BARCODE-1", "", "5", "12"]
            ],
            editable: [],
            complete: [false]
        )
        context.insert(product)
        context.insert(entry)
        try context.save()

        let firstResult = try InventorySyncService(context: context).sync(
            entry: entry,
            ownerUserID: ownerID
        )

        XCTAssertEqual(firstResult.succeeded, 1)
        XCTAssertEqual(firstResult.priceRowsInserted, 1)
        XCTAssertEqual(firstResult.pendingCloudChanges, 2)
        XCTAssertEqual(product.stockQuantity, 5)
        XCTAssertEqual(product.retailPrice, 12)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<LocalPendingChange>()).count, 2)

        let retryResult = try InventorySyncService(context: context).sync(
            entry: entry,
            ownerUserID: ownerID
        )

        XCTAssertEqual(retryResult.succeeded, 1)
        XCTAssertEqual(retryResult.priceRowsInserted, 0)
        XCTAssertEqual(retryResult.pendingCloudChanges, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<LocalPendingChange>()).count, 2)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            HistoryEntry.self,
            ProductPrice.self,
            LocalPendingChange.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        Self.retainedContainers.append(container)
        Self.retainedContexts.append(context)
        return context
    }
}
