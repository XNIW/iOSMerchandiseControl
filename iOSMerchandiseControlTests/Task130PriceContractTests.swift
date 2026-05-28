import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class Task130PriceContractTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testCurrentPriceUsesProductFieldsWhileLastAndPreviousUseHistory() throws {
        let product = Product(
            barcode: "TASK130_PRICE_CURRENT",
            productName: "Task 130 current",
            purchasePrice: 14,
            retailPrice: 24
        )
        let purchasePrevious = ProductPrice(
            type: .purchase,
            price: 10,
            effectiveAt: Date(timeIntervalSince1970: 10),
            source: "IMPORT_PREV",
            createdAt: Date(timeIntervalSince1970: 10),
            product: product
        )
        let purchaseLast = ProductPrice(
            type: .purchase,
            price: 12,
            effectiveAt: Date(timeIntervalSince1970: 20),
            source: "IMPORT_EXCEL",
            createdAt: Date(timeIntervalSince1970: 20),
            product: product
        )
        let retailPrevious = ProductPrice(
            type: .retail,
            price: 20,
            effectiveAt: Date(timeIntervalSince1970: 10),
            source: "IMPORT_PREV",
            createdAt: Date(timeIntervalSince1970: 10),
            product: product
        )
        let retailLast = ProductPrice(
            type: .retail,
            price: 22,
            effectiveAt: Date(timeIntervalSince1970: 20),
            source: "IMPORT_EXCEL",
            createdAt: Date(timeIntervalSince1970: 20),
            product: product
        )
        let history = [purchasePrevious, purchaseLast, retailPrevious, retailLast]

        XCTAssertEqual(ProductPriceContract.currentPrice(for: product, type: .purchase), 14)
        XCTAssertEqual(ProductPriceContract.currentPrice(for: product, type: .retail), 24)
        XCTAssertEqual(ProductPriceContract.lastPrice(in: history, type: .purchase)?.price, 12)
        XCTAssertEqual(ProductPriceContract.previousPrice(in: history, type: .purchase)?.price, 10)
        XCTAssertEqual(ProductPriceContract.lastPrice(in: history, type: .retail)?.price, 22)
        XCTAssertEqual(ProductPriceContract.previousPrice(in: history, type: .retail)?.price, 20)
    }

    func testImportOldFieldsBecomePreviousHistoryNotCurrent() throws {
        let context = try makeContext()
        let resolver = try ProductImportNamedEntityResolver(context: context)
        let draft = ProductDraft(
            barcode: "TASK130_IMPORT_OLD",
            productName: "Task 130 import",
            purchasePrice: 11,
            retailPrice: 17,
            stockQuantity: 2,
            oldPurchasePrice: 9,
            oldRetailPrice: 15
        )

        let product = ProductImportCore.insertProduct(
            from: draft,
            in: context,
            resolver: resolver,
            recordPriceHistory: true
        )
        try context.save()

        let histories = try context.fetch(FetchDescriptor<ProductPrice>())
        XCTAssertEqual(product.purchasePrice, 11)
        XCTAssertEqual(product.retailPrice, 17)
        XCTAssertEqual(ProductPriceContract.lastPrice(in: histories, type: .purchase)?.price, 11)
        XCTAssertEqual(ProductPriceContract.previousPrice(in: histories, type: .purchase)?.price, 9)
        XCTAssertEqual(ProductPriceContract.lastPrice(in: histories, type: .retail)?.price, 17)
        XCTAssertEqual(ProductPriceContract.previousPrice(in: histories, type: .retail)?.price, 15)
        XCTAssertEqual(histories.filter { $0.source == "IMPORT_PREV" }.count, 2)
        XCTAssertEqual(histories.filter { $0.source == "IMPORT_EXCEL" }.count, 2)
    }

    func testPreGenerateOldPricesAreCurrentDbSnapshot() throws {
        let context = try makeContext()
        let product = Product(
            barcode: "TASK130_PREGEN",
            productName: "Task 130 pregenerate",
            purchasePrice: 15,
            retailPrice: 25
        )
        context.insert(product)
        try context.save()

        let header = ["barcode", "productName", "purchasePrice"]
        let viewModel = ExcelSessionViewModel()
        viewModel.originalHeader = ["Barcode", "Product name", "Purchase price"]
        viewModel.normalizedHeader = header
        viewModel.initialNormalizedHeader = header
        viewModel.rows = [
            header,
            ["TASK130_PREGEN", "Task 130 pregenerate", "16"]
        ]
        viewModel.selectedColumns = ExcelSessionViewModel.defaultColumnSelections(for: header)

        let entry = try viewModel.generateHistoryEntry(in: context)
        let generatedHeader = try XCTUnwrap(entry.data.first)
        let generatedRow = try XCTUnwrap(entry.data.dropFirst().first)
        let oldPurchaseIndex = try XCTUnwrap(generatedHeader.firstIndex(of: "oldPurchasePrice"))
        let oldRetailIndex = try XCTUnwrap(generatedHeader.firstIndex(of: "oldRetailPrice"))

        XCTAssertEqual(generatedRow[oldPurchaseIndex], "15")
        XCTAssertEqual(generatedRow[oldRetailIndex], "25")
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            HistoryEntry.self,
            ProductPrice.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return ModelContext(container)
    }
}
