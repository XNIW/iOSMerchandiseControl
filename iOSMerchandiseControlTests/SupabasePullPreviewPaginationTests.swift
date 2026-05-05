import XCTest
import SwiftData
@testable import iOSMerchandiseControl

@MainActor
final class SupabasePullPreviewPaginationTests: XCTestCase {
    private let ownerID = UUID()
    private static var retainedContainers: [ModelContainer] = []
    private static var retainedContexts: [ModelContext] = []

    func testGeneratePreviewFetchesCompletePagedCatalog() async throws {
        let mock = MockSupabaseInventoryFetching(
            products: [
                remoteProduct(barcode: "100", name: "One"),
                remoteProduct(barcode: "200", name: "Two"),
                remoteProduct(barcode: "300", name: "Three")
            ]
        )
        let service = SupabasePullPreviewService(inventoryService: mock, pageSize: 2)
        let state = await service.generatePreview(context: try makeContext())

        guard case .success(let preview) = state else {
            return XCTFail("Expected success preview, got \(state)")
        }

        XCTAssertEqual(preview.outcome, .success)
        XCTAssertEqual(preview.remoteCounts.products, 3)
        XCTAssertEqual(preview.newProducts.count, 3)
        let productRanges = await mock.productRangeLog()
        XCTAssertEqual(productRanges, ["0...1", "2...3"])
    }

    func testGeneratePreviewMarksCatalogPartialWhenBudgetStopsPaging() async throws {
        let mock = MockSupabaseInventoryFetching(
            products: [
                remoteProduct(barcode: "100", name: "One"),
                remoteProduct(barcode: "200", name: "Two"),
                remoteProduct(barcode: "300", name: "Three")
            ]
        )
        let service = SupabasePullPreviewService(
            inventoryService: mock,
            pageSize: 2,
            catalogRowBudget: 2
        )
        let state = await service.generatePreview(context: try makeContext())

        guard case .partial(let preview, _, let sourceErrors) = state else {
            return XCTFail("Expected partial preview, got \(state)")
        }

        XCTAssertEqual(preview.outcome, .partial)
        XCTAssertEqual(preview.remoteCounts.products, 2)
        XCTAssertTrue(sourceErrors.contains { $0.relatedKey == "inventory_products" })
    }

    func testPagerUsesContiguousInclusiveRangesAndStableServiceOrderColumn() async throws {
        var ranges: [String] = []
        let result = try await SupabasePullPreviewPager.fetchAll(pageSize: 2, rowBudget: nil) { from, to in
            ranges.append("\(from)...\(to)")
            switch from {
            case 0:
                return [1, 2]
            case 2:
                return [3]
            default:
                return []
            }
        }

        XCTAssertEqual(result.rows, [1, 2, 3])
        XCTAssertFalse(result.isPartial)
        XCTAssertEqual(ranges, ["0...1", "2...3"])
        XCTAssertEqual(SupabaseInventoryService.stablePageOrderColumn, "id")
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

    private func remoteProduct(
        id: UUID = UUID(),
        barcode: String,
        name: String
    ) -> RemoteInventoryProductRow {
        RemoteInventoryProductRow(
            id: id,
            ownerUserID: ownerID,
            barcode: barcode,
            itemNumber: nil,
            productName: name,
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            updatedAt: "2026-05-05T00:00:00Z",
            deletedAt: nil
        )
    }
}

private actor MockSupabaseInventoryFetching: SupabaseInventoryFetching {
    private let products: [RemoteInventoryProductRow]
    private var productRanges: [String] = []

    init(products: [RemoteInventoryProductRow]) {
        self.products = products
    }

    func productRangeLog() -> [String] {
        productRanges
    }

    func fetchProductsPage(from: Int, to: Int) async throws -> [RemoteInventoryProductRow] {
        productRanges.append("\(from)...\(to)")
        return page(products, from: from, to: to)
    }

    func fetchSuppliersPage(from: Int, to: Int) async throws -> [RemoteInventorySupplierRow] {
        []
    }

    func fetchCategoriesPage(from: Int, to: Int) async throws -> [RemoteInventoryCategoryRow] {
        []
    }

    func fetchProductPricesPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        []
    }

    private func page<Row>(_ rows: [Row], from: Int, to: Int) -> [Row] {
        guard from < rows.count else { return [] }
        let upperBound = min(to + 1, rows.count)
        return Array(rows[from..<upperBound])
    }
}
