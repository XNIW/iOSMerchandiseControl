import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class OptionsLocalSummaryServiceTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testReconciliationAwareSummaryCountsActiveProductPricesWithoutMaterializingAllPendingRows() throws {
        let context = try makeContext()
        let activeProduct = Product(barcode: "TASK127_ACTIVE")
        let tombstonedProduct = Product(
            barcode: "TASK127_DELETED",
            remoteID: UUID(),
            remoteDeletedAt: Date()
        )
        context.insert(activeProduct)
        context.insert(tombstonedProduct)
        context.insert(ProductPrice(type: .purchase, price: 1, product: activeProduct))
        context.insert(ProductPrice(type: .purchase, price: 2, product: tombstonedProduct))
        context.insert(ProductPrice(type: .purchase, price: 3))
        try context.save()

        let summary = try LocalDatabasePublicSummary.makeReconciliationAware(context: context)

        XCTAssertEqual(summary.products, 1)
        XCTAssertEqual(summary.productPrices, 1)
    }

    func testPendingAttentionCounterIsOwnerAndStoreScopedAndExcludesTerminalStatuses() throws {
        let context = try makeContext()
        let owner = UUID()
        let activeStore = LocalStoreIdentity(rawValue: "store-a")
        context.insert(makePending(owner: owner, status: .pending, storeId: "store-a"))
        context.insert(makePending(owner: owner, status: .blocked, storeId: "store-a"))
        context.insert(makePending(owner: owner, status: .superseded, storeId: "store-a"))
        context.insert(makePending(owner: owner, status: .pending, storeId: "store-b"))
        context.insert(makePending(owner: UUID(), status: .pending, storeId: "store-a"))
        context.insert(makePending(owner: nil, status: .pending, storeId: "store-a"))
        try context.save()

        XCTAssertEqual(
            try OptionsPendingAttentionCounter.count(
                context: context,
                ownerUserID: owner,
                storeIdentity: activeStore
            ),
            2
        )
        XCTAssertEqual(
            try OptionsPendingAttentionCounter.count(
                context: context,
                ownerUserID: nil,
                storeIdentity: activeStore
            ),
            1
        )
    }

    func testLargeSyntheticSummaryStaysInsideLocalBudget() throws {
        let context = try makeContext()
        let productCount = 1_000
        let priceCountPerProduct = 2
        for index in 0..<productCount {
            let product = Product(barcode: "TASK127_PERF_\(index)")
            context.insert(product)
            for priceIndex in 0..<priceCountPerProduct {
                context.insert(ProductPrice(type: .purchase, price: Double(priceIndex + 1), product: product))
            }
        }
        try context.save()

        let started = CFAbsoluteTimeGetCurrent()
        let summary = try LocalDatabasePublicSummary.makeReconciliationAware(context: context)
        let elapsedMs = (CFAbsoluteTimeGetCurrent() - started) * 1_000

        XCTAssertEqual(summary.products, productCount)
        XCTAssertEqual(summary.productPrices, productCount * priceCountPerProduct)
        XCTAssertLessThan(elapsedMs, 200, "summaryMs=\(elapsedMs)")
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

    private func makePending(
        owner: UUID?,
        status: LocalPendingChangeStatus,
        storeId: String
    ) -> LocalPendingChange {
        LocalPendingChange(
            ownerUserID: owner,
            storeId: storeId,
            entityKind: .product,
            operation: .update,
            status: status,
            origin: .manualCatalogSave,
            logicalKey: UUID().uuidString
        )
    }
}
