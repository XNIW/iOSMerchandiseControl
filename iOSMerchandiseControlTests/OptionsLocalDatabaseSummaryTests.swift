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
