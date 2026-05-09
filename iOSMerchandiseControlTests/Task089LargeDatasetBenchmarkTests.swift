import XCTest
import SwiftData
@testable import iOSMerchandiseControl

@MainActor
final class Task089LargeDatasetBenchmarkTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testLG1PreviewMediumSyntheticReadMostlyBenchmark() async throws {
        let spec = Task089DatasetSpec()
        let dataset = Task089SyntheticDataset(spec: spec)
        let fetcher = Task089InventoryFetcherFake(dataset: dataset)
        let service = SupabasePullPreviewService(
            inventoryService: fetcher,
            pageSize: spec.pageSize
        )

        let started = DispatchTime.now().uptimeNanoseconds
        let state = await service.generatePreview(context: try makeContext())
        let durationMS = milliseconds(since: started)

        guard case .success(let preview) = state else {
            return XCTFail("Expected synthetic read-mostly preview success, got \(state)")
        }

        XCTAssertEqual(preview.remoteCounts.products, spec.productCount)
        XCTAssertEqual(preview.remoteCounts.suppliers, spec.supplierCount)
        XCTAssertEqual(preview.remoteCounts.categories, spec.categoryCount)
        XCTAssertEqual(preview.remoteCounts.productPrices, spec.priceHistoryCount)
        XCTAssertEqual(preview.newProducts.count, spec.productCount)
        XCTAssertEqual(preview.priceHistoryDiffs.count, spec.priceHistoryCount)
        XCTAssertTrue(preview.conflicts.isEmpty)
        XCTAssertTrue(preview.sourceErrors.isEmpty)

        let ranges = await fetcher.rangeSummary()
        XCTAssertEqual(ranges.productPages, expectedPagedFetchCalls(rowCount: spec.productCount, pageSize: spec.pageSize))
        XCTAssertEqual(ranges.supplierPages, expectedPagedFetchCalls(rowCount: spec.supplierCount, pageSize: spec.pageSize))
        XCTAssertEqual(ranges.categoryPages, expectedPagedFetchCalls(rowCount: spec.categoryCount, pageSize: spec.pageSize))
        XCTAssertEqual(ranges.pricePages, expectedPagedFetchCalls(rowCount: spec.priceHistoryCount, pageSize: spec.pageSize))

        let firstProduct = try XCTUnwrap(preview.newProducts.first)
        XCTAssertEqual(firstProduct.barcode, "TASK089_BAR_00000")
        XCTAssertEqual(firstProduct.productName, "TASK089_PRODUCT_00000")
        XCTAssertEqual(firstProduct.applyPayload?.supplierName, "TASK089_SUPPLIER_000")
        XCTAssertEqual(firstProduct.applyPayload?.categoryName, "TASK089_CATEGORY_000")

        recordMetric([
            ("scenario", "LG1"),
            ("dataset", "D89-M"),
            ("target", "XCTest_fake_readmostly"),
            ("products", "\(spec.productCount)"),
            ("suppliers", "\(spec.supplierCount)"),
            ("categories", "\(spec.categoryCount)"),
            ("priceHistoryRows", "\(spec.priceHistoryCount)"),
            ("pageSize", "\(spec.pageSize)"),
            ("productPageCalls", "\(ranges.productPages)"),
            ("pricePageCalls", "\(ranges.pricePages)"),
            ("durationMS", format(durationMS)),
            ("outcome", "PASS"),
            ("privacy", "OK_TASK089_SYNTHETIC")
        ])
    }

    func testLG2ProductsExportMediumSyntheticBenchmark() throws {
        let spec = Task089DatasetSpec()
        let dataset = Task089SyntheticDataset(spec: spec)

        let started = DispatchTime.now().uptimeNanoseconds
        let url = try Task089SyntheticBenchmarkHarness.exportProducts(rows: dataset.productExportRows)
        defer { try? FileManager.default.removeItem(at: url) }
        let durationMS = milliseconds(since: started)
        let sizeBytes = try fileSizeBytes(url)
        let rows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: "Products")

        XCTAssertEqual(rows.count, spec.productCount + 1)
        XCTAssertGreaterThan(sizeBytes, 0)
        assertProductsSheet(rows, expectedProductCount: spec.productCount)

        recordMetric([
            ("scenario", "LG2"),
            ("dataset", "D89-M"),
            ("target", "XCTest_DEBUG_harness"),
            ("products", "\(spec.productCount)"),
            ("durationMS", format(durationMS)),
            ("fileSizeBytes", "\(sizeBytes)"),
            ("sheetRowsIncludingHeader", "\(rows.count)"),
            ("outcome", "PASS"),
            ("privacy", "OK_TASK089_SYNTHETIC")
        ])
    }

    func testLG3FullDatabaseExportMediumSyntheticBenchmark() throws {
        let spec = Task089DatasetSpec()
        let dataset = Task089SyntheticDataset(spec: spec)

        let started = DispatchTime.now().uptimeNanoseconds
        let url = try Task089SyntheticBenchmarkHarness.exportFullDatabase(input: dataset.fullDatabaseExportInput)
        defer { try? FileManager.default.removeItem(at: url) }
        let durationMS = milliseconds(since: started)
        let sizeBytes = try fileSizeBytes(url)
        let productRows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: "Products")
        let supplierRows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: "Suppliers")
        let categoryRows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: "Categories")
        let priceRows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: "PriceHistory")

        XCTAssertEqual(productRows.count, spec.productCount + 1)
        XCTAssertEqual(supplierRows.count, spec.supplierCount + 1)
        XCTAssertEqual(categoryRows.count, spec.categoryCount + 1)
        XCTAssertEqual(priceRows.count, spec.priceHistoryCount + 1)
        XCTAssertGreaterThan(sizeBytes, 0)
        assertProductsSheet(productRows, expectedProductCount: spec.productCount)
        assertSingleColumnSheet(supplierRows, expectedHeader: "name", firstValue: "TASK089_SUPPLIER_000")
        assertSingleColumnSheet(categoryRows, expectedHeader: "name", firstValue: "TASK089_CATEGORY_000")
        assertPriceHistorySheet(priceRows)

        recordMetric([
            ("scenario", "LG3"),
            ("dataset", "D89-M"),
            ("target", "XCTest_DEBUG_harness"),
            ("products", "\(spec.productCount)"),
            ("suppliers", "\(spec.supplierCount)"),
            ("categories", "\(spec.categoryCount)"),
            ("priceHistoryRows", "\(spec.priceHistoryCount)"),
            ("durationMS", format(durationMS)),
            ("fileSizeBytes", "\(sizeBytes)"),
            ("productRowsIncludingHeader", "\(productRows.count)"),
            ("priceRowsIncludingHeader", "\(priceRows.count)"),
            ("outcome", "PASS"),
            ("privacy", "OK_TASK089_SYNTHETIC")
        ])
    }

    func testLG4ManualSyncFirstFeedbackCancelRecoveryBenchmark() async throws {
        let coordinator = Task089DelayedCoordinator(delayNanoseconds: 500_000_000)
        let viewModel = SupabaseManualSyncViewModel(coordinator: coordinator)

        let started = DispatchTime.now().uptimeNanoseconds
        let run = Task { await viewModel.start(with: .dryRun) }

        while !viewModel.presentationState.isRunning && milliseconds(since: started) < 1_000 {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let firstFeedbackMS = milliseconds(since: started)

        XCTAssertTrue(viewModel.presentationState.isRunning)
        XCTAssertTrue(viewModel.presentationState.isLoading)
        XCTAssertNil(viewModel.presentationState.primaryAction)
        XCTAssertEqual(viewModel.presentationState.secondaryAction?.id, .cancel)

        let cancelStarted = DispatchTime.now().uptimeNanoseconds
        run.cancel()
        await run.value
        let cancelRecoveryMS = milliseconds(since: cancelStarted)

        XCTAssertEqual(viewModel.presentationKind, .cancelledRun)
        XCTAssertEqual(viewModel.presentationState.primaryAction?.id, .retry)
        XCTAssertNil(viewModel.presentationState.secondaryAction)

        recordMetric([
            ("scenario", "LG4"),
            ("dataset", "D89-M"),
            ("target", "XCTest_ViewModel_fake"),
            ("firstFeedbackMS", format(firstFeedbackMS)),
            ("cancelRecoveryMS", format(cancelRecoveryMS)),
            ("runningShowsCancel", "true"),
            ("postCancelRetry", "true"),
            ("outcome", "PASS"),
            ("privacy", "OK_TASK089_SYNTHETIC")
        ])
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
        return ModelContext(container)
    }

    private func fileSizeBytes(_ url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let size = attributes[.size] as? NSNumber {
            return size.uint64Value
        }
        return 0
    }

    private func milliseconds(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000.0
    }

    private func format(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func expectedPagedFetchCalls(rowCount: Int, pageSize: Int) -> Int {
        rowCount / pageSize + 1
    }

    private func assertProductsSheet(
        _ rows: [[String]],
        expectedProductCount: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(rows.first, [
            "barcode",
            "itemNumber",
            "productName",
            "secondProductName",
            "purchasePrice",
            "retailPrice",
            "oldPurchasePrice",
            "oldRetailPrice",
            "stockQuantity",
            "supplierName",
            "categoryName"
        ], file: file, line: line)
        XCTAssertEqual(rows.dropFirst().count, expectedProductCount, file: file, line: line)
        XCTAssertEqual(rows.dropFirst().first?[safe: 0], "TASK089_BAR_00000", file: file, line: line)
        XCTAssertEqual(rows.dropFirst().first?[safe: 2], "TASK089_PRODUCT_00000", file: file, line: line)
        XCTAssertEqual(rows.dropFirst().first?[safe: 9], "TASK089_SUPPLIER_000", file: file, line: line)
        XCTAssertEqual(rows.dropFirst().first?[safe: 10], "TASK089_CATEGORY_000", file: file, line: line)
        XCTAssertEqual(rows.last?[safe: 0], String(format: "TASK089_BAR_%05d", expectedProductCount - 1), file: file, line: line)
    }

    private func assertSingleColumnSheet(
        _ rows: [[String]],
        expectedHeader: String,
        firstValue: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(rows.first, [expectedHeader], file: file, line: line)
        XCTAssertEqual(rows.dropFirst().first?[safe: 0], firstValue, file: file, line: line)
    }

    private func assertPriceHistorySheet(
        _ rows: [[String]],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(rows.first, [
            "productBarcode",
            "timestamp",
            "type",
            "oldPrice",
            "newPrice",
            "source"
        ], file: file, line: line)
        XCTAssertEqual(rows.dropFirst().first?[safe: 0], "TASK089_BAR_00000", file: file, line: line)
        XCTAssertEqual(rows.dropFirst().first?[safe: 2], "purchase", file: file, line: line)
        XCTAssertEqual(rows.dropFirst().first?[safe: 5], "TASK089_SYNTHETIC", file: file, line: line)
    }

    private func recordMetric(_ pairs: [(String, String)]) {
        let payload = pairs.map { "\($0.0)=\($0.1)" }.joined(separator: "|")
        print("TASK089_METRIC|\(payload)")
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct Task089DatasetSpec {
    let productCount = 2_500
    let supplierCount = 100
    let categoryCount = 60
    let priceRowsPerProduct = 2
    let pageSize = 500

    var priceHistoryCount: Int {
        productCount * priceRowsPerProduct
    }
}

private struct Task089SyntheticDataset {
    let suppliers: [RemoteInventorySupplierRow]
    let categories: [RemoteInventoryCategoryRow]
    let products: [RemoteInventoryProductRow]
    let productPrices: [RemoteInventoryProductPriceRow]
    let productExportRows: [Task089SyntheticBenchmarkHarness.ProductExportRow]
    let fullDatabaseExportInput: Task089SyntheticBenchmarkHarness.FullDatabaseExportInput

    init(spec: Task089DatasetSpec) {
        let ownerID = UUID()
        let timestamp = "2026-05-09T12:00:00Z"
        let supplierRows = (0..<spec.supplierCount).map { index in
            RemoteInventorySupplierRow(
                id: UUID(),
                ownerUserID: ownerID,
                name: Self.supplierName(index),
                updatedAt: timestamp,
                deletedAt: nil
            )
        }
        let categoryRows = (0..<spec.categoryCount).map { index in
            RemoteInventoryCategoryRow(
                id: UUID(),
                ownerUserID: ownerID,
                name: Self.categoryName(index),
                updatedAt: timestamp,
                deletedAt: nil
            )
        }

        var productRows: [RemoteInventoryProductRow] = []
        var priceRows: [RemoteInventoryProductPriceRow] = []
        var exportRows: [Task089SyntheticBenchmarkHarness.ProductExportRow] = []
        var fullPriceRows: [Task089SyntheticBenchmarkHarness.PriceHistoryExportRow] = []
        let baseDate = Date(timeIntervalSince1970: 1_777_680_000)

        for index in 0..<spec.productCount {
            let supplier = supplierRows[index % supplierRows.count]
            let category = categoryRows[index % categoryRows.count]
            let productID = UUID()
            let barcode = Self.barcode(index)
            let purchase = Double(100 + (index % 700)) / 10.0
            let retail = purchase * 1.35

            productRows.append(
                RemoteInventoryProductRow(
                    id: productID,
                    ownerUserID: ownerID,
                    barcode: barcode,
                    itemNumber: Self.itemNumber(index),
                    productName: Self.productName(index),
                    secondProductName: Self.secondProductName(index),
                    purchasePrice: purchase,
                    retailPrice: retail,
                    supplierID: supplier.id,
                    categoryID: category.id,
                    stockQuantity: Double(index % 90),
                    updatedAt: timestamp,
                    deletedAt: nil
                )
            )

            exportRows.append(
                Task089SyntheticBenchmarkHarness.ProductExportRow(
                    barcode: barcode,
                    itemNumber: Self.itemNumber(index),
                    productName: Self.productName(index),
                    secondProductName: Self.secondProductName(index),
                    purchasePrice: purchase,
                    retailPrice: retail,
                    oldPurchasePrice: purchase - 0.5,
                    oldRetailPrice: retail - 0.5,
                    stockQuantity: Double(index % 90),
                    supplierName: supplier.name,
                    categoryName: category.name
                )
            )

            for priceIndex in 0..<spec.priceRowsPerProduct {
                let type = priceIndex % 2 == 0 ? "purchase" : "retail"
                let price = type == "purchase" ? purchase : retail
                let effectiveDate = baseDate.addingTimeInterval(Double(index + priceIndex) * 60)
                let effectiveAt = Self.iso8601(effectiveDate)
                priceRows.append(
                    RemoteInventoryProductPriceRow(
                        id: UUID(),
                        ownerUserID: ownerID,
                        productID: productID,
                        type: type,
                        price: price,
                        effectiveAt: effectiveAt,
                        source: "TASK089_SYNTHETIC",
                        note: nil,
                        createdAt: effectiveAt
                    )
                )
                fullPriceRows.append(
                    Task089SyntheticBenchmarkHarness.PriceHistoryExportRow(
                        productBarcode: barcode,
                        timestamp: effectiveDate,
                        type: type,
                        newPrice: price,
                        source: "TASK089_SYNTHETIC"
                    )
                )
            }
        }

        suppliers = supplierRows
        categories = categoryRows
        products = productRows
        productPrices = priceRows
        productExportRows = exportRows
        fullDatabaseExportInput = Task089SyntheticBenchmarkHarness.FullDatabaseExportInput(
            products: exportRows,
            suppliers: supplierRows.map(\.name),
            categories: categoryRows.map(\.name),
            priceHistory: fullPriceRows.sorted {
                if $0.productBarcode != $1.productBarcode {
                    return $0.productBarcode < $1.productBarcode
                }
                if $0.type != $1.type {
                    return $0.type < $1.type
                }
                return $0.timestamp < $1.timestamp
            }
        )
    }

    private static func barcode(_ index: Int) -> String {
        String(format: "TASK089_BAR_%05d", index)
    }

    private static func itemNumber(_ index: Int) -> String {
        String(format: "TASK089_ITEM_%05d", index)
    }

    private static func productName(_ index: Int) -> String {
        String(format: "TASK089_PRODUCT_%05d", index)
    }

    private static func secondProductName(_ index: Int) -> String {
        String(format: "TASK089_SECOND_%05d", index)
    }

    private static func supplierName(_ index: Int) -> String {
        String(format: "TASK089_SUPPLIER_%03d", index)
    }

    private static func categoryName(_ index: Int) -> String {
        String(format: "TASK089_CATEGORY_%03d", index)
    }

    private static func iso8601(_ date: Date) -> String {
        formatter.string(from: date)
    }

    private static let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

private actor Task089InventoryFetcherFake: SupabaseInventoryFetching {
    private let dataset: Task089SyntheticDataset
    private var productRanges: [String] = []
    private var supplierRanges: [String] = []
    private var categoryRanges: [String] = []
    private var priceRanges: [String] = []

    init(dataset: Task089SyntheticDataset) {
        self.dataset = dataset
    }

    func fetchProductsPage(from: Int, to: Int) async throws -> [RemoteInventoryProductRow] {
        productRanges.append("\(from)...\(to)")
        return page(dataset.products, from: from, to: to)
    }

    func fetchSuppliersPage(from: Int, to: Int) async throws -> [RemoteInventorySupplierRow] {
        supplierRanges.append("\(from)...\(to)")
        return page(dataset.suppliers, from: from, to: to)
    }

    func fetchCategoriesPage(from: Int, to: Int) async throws -> [RemoteInventoryCategoryRow] {
        categoryRanges.append("\(from)...\(to)")
        return page(dataset.categories, from: from, to: to)
    }

    func fetchProductPricesPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        priceRanges.append("\(from)...\(to)")
        return page(dataset.productPrices, from: from, to: to)
    }

    func rangeSummary() -> Task089RangeSummary {
        Task089RangeSummary(
            productPages: productRanges.count,
            supplierPages: supplierRanges.count,
            categoryPages: categoryRanges.count,
            pricePages: priceRanges.count
        )
    }

    private func page<Row>(_ rows: [Row], from: Int, to: Int) -> [Row] {
        guard from < rows.count else { return [] }
        let upperBound = min(to + 1, rows.count)
        return Array(rows[from..<upperBound])
    }
}

private struct Task089RangeSummary: Sendable {
    let productPages: Int
    let supplierPages: Int
    let categoryPages: Int
    let pricePages: Int
}

@MainActor
private final class Task089DelayedCoordinator: SupabaseManualSyncCoordinating {
    private let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64) {
        self.delayNanoseconds = delayNanoseconds
    }

    func run(mode: SupabaseManualSyncRunMode, sessionID: UUID) async -> SupabaseManualSyncRunSummary {
        do {
            try await Task.sleep(nanoseconds: delayNanoseconds)
            try Task.checkCancellation()
            return SupabaseManualSyncRunSummary(
                finalState: .completedSuccessfully,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.cloudCheckNoAction,
                executedPhases: [.remotePreview, .summary],
                skippedPhases: [],
                countsSnapshot: SupabaseManualSyncPrivacyCounts(),
                suggestedNextStep: nil,
                detailMessage: nil
            )
        } catch {
            return SupabaseManualSyncRunSummary(
                finalState: .cancelled,
                userFacingHeadline: SupabaseManualSyncUserFacingCopy.cancelled,
                executedPhases: [.remotePreview],
                skippedPhases: [.summary],
                countsSnapshot: SupabaseManualSyncPrivacyCounts(),
                suggestedNextStep: nil,
                detailMessage: nil
            )
        }
    }
}
