import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class OptionsLocalDatabaseSummaryTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testLocalDatabaseSummaryUsesFetchCountForHistorySessions() throws {
        let context = try makeContext()
        context.insert(HistoryEntry(id: "history-1"))
        context.insert(HistoryEntry(id: "history-2"))
        try context.save()

        let summary = try LocalDatabasePublicSummary.make(context: context)

        XCTAssertEqual(summary.historySessions, 2)
        XCTAssertEqual(summary.products, 0)
        XCTAssertEqual(summary.suppliers, 0)
        XCTAssertEqual(summary.categories, 0)
        XCTAssertEqual(summary.productPrices, 0)
    }

    func testLocalDatabaseSummaryCountsOnlyPricesForActiveProducts() throws {
        let context = try makeContext()
        let activeProduct = Product(barcode: "active")
        let tombstonedProduct = Product(
            barcode: "deleted",
            remoteID: UUID(),
            remoteDeletedAt: Date()
        )
        context.insert(activeProduct)
        context.insert(tombstonedProduct)
        context.insert(ProductPrice(type: .purchase, price: 1, product: activeProduct))
        context.insert(ProductPrice(type: .purchase, price: 2, product: tombstonedProduct))
        context.insert(ProductPrice(type: .purchase, price: 3))
        try context.save()

        let summary = try LocalDatabasePublicSummary.make(context: context)

        XCTAssertEqual(summary.products, 1)
        XCTAssertEqual(summary.productPrices, 1)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            HistoryEntry.self,
            ProductPrice.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self,
            SyncEventOutboxEntry.self,
            LocalPendingChange.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return ModelContext(container)
    }
}
