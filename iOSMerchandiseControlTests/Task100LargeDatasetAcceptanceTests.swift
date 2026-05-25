import SwiftData
import Supabase
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class Task100LargeDatasetAcceptanceTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private static var retainedContexts: [ModelContext] = []
    private static var didResetMetricCapture = false
    private static let metricCaptureURL = URL(fileURLWithPath: "/tmp/TASK100Metrics.jsonl")

    override func setUp() {
        super.setUp()

        if !Self.didResetMetricCapture {
            try? FileManager.default.removeItem(at: Self.metricCaptureURL)
            Self.didResetMetricCapture = true
        }
    }

    func testS100BDatasetManifestSmallAndMedium() throws {
        let small = Task100SyntheticDataset(spec: .small)
        let medium = Task100SyntheticDataset(spec: .medium)

        assertDataset(small, spec: .small)
        assertDataset(medium, spec: .medium)

        recordMetric(
            scenarioID: "S100-B-D100-S",
            datasetClass: "D100-S",
            deviceTarget: "XCTest_synthetic",
            rowCounts: small.rowCountsDescription,
            fileSizeMB: nil,
            firstFeedbackSeconds: 0,
            totalDurationSeconds: 0,
            resultState: "PASS",
            failureMode: "none",
            notes: "synthetic manifest generated; privacy OK"
        )
        recordMetric(
            scenarioID: "S100-B-D100-M",
            datasetClass: "D100-M",
            deviceTarget: "XCTest_synthetic",
            rowCounts: medium.rowCountsDescription,
            fileSizeMB: nil,
            firstFeedbackSeconds: 0,
            totalDurationSeconds: 0,
            resultState: "PASS",
            failureMode: "none",
            notes: "synthetic manifest generated; privacy OK"
        )
    }

    func testS100BDatasetManifestLargeWhenEnabled() throws {
        try requireD100LEnabled()
        let large = Task100SyntheticDataset(spec: .large)

        assertDataset(large, spec: .large)

        recordMetric(
            scenarioID: "S100-B-D100-L",
            datasetClass: "D100-L",
            deviceTarget: "XCTest_synthetic",
            rowCounts: large.rowCountsDescription,
            fileSizeMB: nil,
            firstFeedbackSeconds: 0,
            totalDurationSeconds: 0,
            resultState: "PASS",
            failureMode: "none",
            notes: "synthetic manifest generated; privacy OK"
        )
    }

    func testTask108RealExcelCleanSeedImportCountsWhenEnabled() throws {
        let url = try task108RealExcelURL()
        let context = try makeContext()
        let started = DispatchTime.now().uptimeNanoseconds

        let productRows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: "Products")
        let (_, normalizedHeader, dataRows) = ExcelAnalyzer.analyzeSheetRows(productRows)
        let analysis = ProductImportCore.analyzeImport(
            header: normalizedHeader,
            dataRows: dataRows,
            existingProductsByBarcode: [:]
        )

        XCTAssertEqual(analysis.newProducts.count, 19_695)
        XCTAssertTrue(analysis.updatedProducts.isEmpty)
        XCTAssertTrue(analysis.errors.isEmpty)

        let resolver = try ProductImportNamedEntityResolver(context: context)
        var insertedProducts = 0
        for draft in analysis.newProducts {
            ProductImportCore.insertProduct(
                from: draft,
                in: context,
                resolver: resolver,
                recordPriceHistory: false
            )
            insertedProducts += 1
            try saveIfNeeded(context, after: insertedProducts)
        }
        try context.save()

        let priceRows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: "PriceHistory")
        let parsedPrices = try parsePriceHistoryRows(priceRows)
        XCTAssertEqual(parsedPrices.count, 41_108)

        let productsByBarcode = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Product>()).map { ($0.barcode, $0) }
        )

        var insertedPrices = 0
        for entry in parsedPrices {
            let product = try XCTUnwrap(productsByBarcode[entry.barcode])
            context.insert(
                ProductPrice(
                    type: entry.type,
                    price: entry.price,
                    effectiveAt: entry.effectiveAt,
                    source: entry.source,
                    createdAt: entry.effectiveAt,
                    product: product
                )
            )
            insertedPrices += 1
            try saveIfNeeded(context, after: insertedPrices)
        }
        try context.save()

        let products = try context.fetch(FetchDescriptor<Product>())
        let suppliers = try context.fetch(FetchDescriptor<Supplier>())
        let categories = try context.fetch(FetchDescriptor<ProductCategory>())
        let prices = try context.fetch(FetchDescriptor<ProductPrice>())

        XCTAssertEqual(products.count, 19_695)
        XCTAssertEqual(suppliers.count, 57)
        XCTAssertEqual(categories.count, 27)
        XCTAssertEqual(prices.count, 41_108)

        let logicalKeys = Set(prices.compactMap { price -> String? in
            guard let barcode = price.product?.barcode else { return nil }
            return [
                barcode,
                price.type.rawValue,
                Self.fullDatabaseFormatter.string(from: price.effectiveAt)
            ].joined(separator: "|")
        })
        XCTAssertEqual(logicalKeys.count, prices.count)

        let elapsed = seconds(since: started)
        print(
            "[Task108ExcelImport] elapsedSeconds=\(String(format: "%.3f", elapsed)) " +
            "products=\(products.count) suppliers=\(suppliers.count) categories=\(categories.count) " +
            "productPricesRaw=\(prices.count) productPricesLogical=\(logicalKeys.count) duplicates=\(prices.count - logicalKeys.count)"
        )
    }

    func testTask108RealExcelProductPricePagedFullPullNoopWhenEnabled() async throws {
        let url = try task108RealExcelURL()
        let context = try makeContext()
        let session = ProductPriceApplySessionSnapshot(userID: task108UUID(base: 0x300000000000, index: 1))

        let productRows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: "Products")
        let (_, normalizedHeader, dataRows) = ExcelAnalyzer.analyzeSheetRows(productRows)
        let analysis = ProductImportCore.analyzeImport(
            header: normalizedHeader,
            dataRows: dataRows,
            existingProductsByBarcode: [:]
        )
        XCTAssertEqual(analysis.newProducts.count, 19_695)

        let resolver = try ProductImportNamedEntityResolver(context: context)
        var productIDByBarcode: [String: UUID] = [:]
        var insertedProducts = 0
        for (index, draft) in analysis.newProducts.enumerated() {
            let product = ProductImportCore.insertProduct(
                from: draft,
                in: context,
                resolver: resolver,
                recordPriceHistory: false
            )
            let remoteID = task108UUID(base: 0x100000000000, index: index + 1)
            product.remoteID = remoteID
            productIDByBarcode[draft.barcode] = remoteID
            insertedProducts += 1
            try saveIfNeeded(context, after: insertedProducts)
        }
        try context.save()

        let priceRows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: "PriceHistory")
        let parsedPrices = try parsePriceHistoryRows(priceRows)
        XCTAssertEqual(parsedPrices.count, 41_108)

        let remoteRows = try parsedPrices.enumerated().map { index, entry -> RemoteInventoryProductPriceRow in
            let productID = try XCTUnwrap(productIDByBarcode[entry.barcode])
            let canonicalEffectiveAt = Self.fullDatabaseFormatter.string(from: entry.effectiveAt)
            return RemoteInventoryProductPriceRow(
                id: task108UUID(base: 0x200000000000, index: index + 1),
                ownerUserID: session.userID,
                productID: productID,
                type: entry.type.rawValue.uppercased(),
                price: entry.price,
                effectiveAt: canonicalEffectiveAt,
                source: entry.source,
                note: nil,
                createdAt: canonicalEffectiveAt
            )
        }

        let fetcher = Task108ArrayProductPriceFetcher(rows: remoteRows)
        let service = SupabaseProductPriceApplyService(
            fetcher: fetcher,
            fetchOptions: ProductPriceApplyFetchOptions(pageSize: 900, maxRows: 900, maxPages: 1)
        )

        let firstStarted = DispatchTime.now().uptimeNanoseconds
        let firstPlan = try await service.loadBootstrapPreviewSample(context: context, sessionSnapshot: session)
        let firstResult = try await service.applyPagedFullPull(
            plan: firstPlan,
            context: context,
            currentSessionSnapshot: session
        )
        let firstElapsed = seconds(since: firstStarted)
        XCTAssertEqual(firstResult.inserted, 41_108)
        XCTAssertEqual(firstResult.remoteIdentityLinked, 0)
        XCTAssertEqual(firstResult.totalConsidered, 41_108)

        let pricesAfterFirstPull = try context.fetch(FetchDescriptor<ProductPrice>())
        XCTAssertEqual(pricesAfterFirstPull.count, 41_108)
        XCTAssertEqual(task108LogicalPriceCount(pricesAfterFirstPull), 41_108)

        let secondStarted = DispatchTime.now().uptimeNanoseconds
        let secondPlan = try await service.loadBootstrapPreviewSample(context: context, sessionSnapshot: session)
        let secondResult = try await service.applyPagedFullPull(
            plan: secondPlan,
            context: context,
            currentSessionSnapshot: session
        )
        let secondElapsed = seconds(since: secondStarted)
        XCTAssertEqual(secondResult.inserted, 0)
        XCTAssertEqual(secondResult.remoteIdentityLinked, 0)
        XCTAssertEqual(secondResult.totalConsidered, 41_108)

        let pricesAfterSecondPull = try context.fetch(FetchDescriptor<ProductPrice>())
        XCTAssertEqual(pricesAfterSecondPull.count, 41_108)
        XCTAssertEqual(task108LogicalPriceCount(pricesAfterSecondPull), 41_108)

        print(
            "[Task108ProductPriceFullPullHarness] " +
            "firstElapsedSeconds=\(String(format: "%.3f", firstElapsed)) firstInserted=\(firstResult.inserted) " +
            "secondElapsedSeconds=\(String(format: "%.3f", secondElapsed)) secondInserted=\(secondResult.inserted) " +
            "rows=\(pricesAfterSecondPull.count) logical=\(task108LogicalPriceCount(pricesAfterSecondPull)) " +
            "pageSize=900 pages=46"
        )
    }

    func testS100CImportExcelLargeDatasetMediumCoreBenchmark() throws {
        let spec = Task100DatasetSpec.medium
        let dataset = Task100SyntheticDataset(spec: spec)
        let context = try makeContext()

        let exportURL = try Task089SyntheticBenchmarkHarness.exportFullDatabase(input: dataset.fullDatabaseExportInput)
        defer { try? FileManager.default.removeItem(at: exportURL) }
        let fileSize = try fileSizeMB(exportURL)

        let started = DispatchTime.now().uptimeNanoseconds
        let firstFeedbackSeconds = seconds(since: started)

        let productRows = try ExcelAnalyzer.readSheetByName(at: exportURL, sheetName: "Products")
        let (_, normalizedHeader, dataRows) = ExcelAnalyzer.analyzeSheetRows(productRows)
        let analysis = ProductImportCore.analyzeImport(
            header: normalizedHeader,
            dataRows: dataRows,
            existingProductsByBarcode: [:]
        )

        XCTAssertEqual(analysis.newProducts.count, spec.productCount)
        XCTAssertTrue(analysis.updatedProducts.isEmpty)
        XCTAssertTrue(analysis.errors.isEmpty)

        let resolver = try ProductImportNamedEntityResolver(context: context)
        var insertedProducts = 0
        for draft in analysis.newProducts {
            ProductImportCore.insertProduct(
                from: draft,
                in: context,
                resolver: resolver,
                recordPriceHistory: false
            )
            insertedProducts += 1
            try saveIfNeeded(context, after: insertedProducts)
        }
        try context.save()

        let priceRows = try ExcelAnalyzer.readSheetByName(at: exportURL, sheetName: "PriceHistory")
        let parsedPrices = try parsePriceHistoryRows(priceRows)
        XCTAssertEqual(parsedPrices.count, spec.priceHistoryCount)
        let productsByBarcode = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Product>()).map { ($0.barcode, $0) }
        )

        var insertedPrices = 0
        for entry in parsedPrices {
            let product = try XCTUnwrap(productsByBarcode[entry.barcode])
            context.insert(
                ProductPrice(
                    type: entry.type,
                    price: entry.price,
                    effectiveAt: entry.effectiveAt,
                    source: entry.source,
                    createdAt: entry.effectiveAt,
                    product: product
                )
            )
            insertedPrices += 1
            try saveIfNeeded(context, after: insertedPrices)
        }
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Product>()).count, spec.productCount)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Supplier>()).count, spec.supplierCount)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductCategory>()).count, spec.categoryCount)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, spec.priceHistoryCount)
        try assertCurrentPreviousPrices(
            context: context,
            dataset: dataset,
            productIndex: spec.productCount - 1
        )

        recordMetric(
            scenarioID: "S100-C",
            datasetClass: spec.datasetClass,
            deviceTarget: "XCTest_SwiftData_in_memory",
            rowCounts: dataset.rowCountsDescription,
            fileSizeMB: fileSize,
            firstFeedbackSeconds: firstFeedbackSeconds,
            totalDurationSeconds: seconds(since: started),
            resultState: "PASS",
            failureMode: "none",
            notes: "Excel parsed and import core applied to SwiftData in-memory store"
        )
    }

    func testS100CImportExcelLargeDatasetLargeCoreBenchmarkWhenEnabled() throws {
        try requireD100LEnabled()
        let spec = Task100DatasetSpec.large
        let dataset = Task100SyntheticDataset(spec: spec)
        let context = try makeContext()

        let exportStarted = DispatchTime.now().uptimeNanoseconds
        let exportURL = try Task089SyntheticBenchmarkHarness.exportFullDatabase(input: dataset.fullDatabaseExportInput)
        defer { try? FileManager.default.removeItem(at: exportURL) }
        let fileSize = try fileSizeMB(exportURL)
        let exportDuration = seconds(since: exportStarted)

        recordMetric(
            scenarioID: "S100-D-full-db-export-D100-L",
            datasetClass: spec.datasetClass,
            deviceTarget: "XCTest_DEBUG_export_harness",
            rowCounts: dataset.rowCountsDescription,
            fileSizeMB: fileSize,
            firstFeedbackSeconds: 0,
            totalDurationSeconds: exportDuration,
            resultState: "PASS",
            failureMode: "none",
            notes: "D100-L full database XLSX generated for import path"
        )

        let started = DispatchTime.now().uptimeNanoseconds
        let firstFeedbackSeconds = seconds(since: started)

        let productRows = try ExcelAnalyzer.readSheetByName(at: exportURL, sheetName: "Products")
        let (_, normalizedHeader, dataRows) = ExcelAnalyzer.analyzeSheetRows(productRows)
        let analysis = ProductImportCore.analyzeImport(
            header: normalizedHeader,
            dataRows: dataRows,
            existingProductsByBarcode: [:]
        )

        XCTAssertEqual(analysis.newProducts.count, spec.productCount)
        XCTAssertTrue(analysis.updatedProducts.isEmpty)
        XCTAssertTrue(analysis.errors.isEmpty)

        let resolver = try ProductImportNamedEntityResolver(context: context)
        var insertedProducts = 0
        for draft in analysis.newProducts {
            ProductImportCore.insertProduct(
                from: draft,
                in: context,
                resolver: resolver,
                recordPriceHistory: false
            )
            insertedProducts += 1
            try saveIfNeeded(context, after: insertedProducts)
        }
        try context.save()

        let priceRows = try ExcelAnalyzer.readSheetByName(at: exportURL, sheetName: "PriceHistory")
        let parsedPrices = try parsePriceHistoryRows(priceRows)
        XCTAssertEqual(parsedPrices.count, spec.priceHistoryCount)
        let productsByBarcode = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Product>()).map { ($0.barcode, $0) }
        )

        var insertedPrices = 0
        for entry in parsedPrices {
            let product = try XCTUnwrap(productsByBarcode[entry.barcode])
            context.insert(
                ProductPrice(
                    type: entry.type,
                    price: entry.price,
                    effectiveAt: entry.effectiveAt,
                    source: entry.source,
                    createdAt: entry.effectiveAt,
                    product: product
                )
            )
            insertedPrices += 1
            try saveIfNeeded(context, after: insertedPrices)
        }
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Product>()).count, spec.productCount)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Supplier>()).count, spec.supplierCount)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductCategory>()).count, spec.categoryCount)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, spec.priceHistoryCount)
        try assertCurrentPreviousPrices(context: context, dataset: dataset, productIndex: 0)
        try assertCurrentPreviousPrices(context: context, dataset: dataset, productIndex: spec.productCount / 2)
        try assertCurrentPreviousPrices(context: context, dataset: dataset, productIndex: spec.productCount - 1)

        recordMetric(
            scenarioID: "S100-C-D100-L",
            datasetClass: spec.datasetClass,
            deviceTarget: "XCTest_SwiftData_in_memory",
            rowCounts: dataset.rowCountsDescription,
            fileSizeMB: fileSize,
            firstFeedbackSeconds: firstFeedbackSeconds,
            totalDurationSeconds: seconds(since: started),
            resultState: "PASS",
            failureMode: "none",
            notes: "D100-L Excel parsed and import core applied to SwiftData in-memory store"
        )
    }

    func testS100DExportProductsAndFullDatabaseMediumSyntheticBenchmark() throws {
        let spec = Task100DatasetSpec.medium
        let dataset = Task100SyntheticDataset(spec: spec)

        let productsStarted = DispatchTime.now().uptimeNanoseconds
        let productsURL = try Task089SyntheticBenchmarkHarness.exportProducts(rows: dataset.productExportRows)
        defer { try? FileManager.default.removeItem(at: productsURL) }
        let productsDuration = seconds(since: productsStarted)
        let productsSize = try fileSizeMB(productsURL)
        let productsSheet = try ExcelAnalyzer.readSheetByName(at: productsURL, sheetName: "Products")
        XCTAssertEqual(productsSheet.count, spec.productCount + 1)
        XCTAssertEqual(productsSheet.first?[safe: 0], "barcode")
        XCTAssertEqual(productsSheet.dropFirst().first?[safe: 0], "TASK100_BAR_000000")
        XCTAssertEqual(productsSheet.last?[safe: 0], String(format: "TASK100_BAR_%06d", spec.productCount - 1))

        recordMetric(
            scenarioID: "S100-D-products-export",
            datasetClass: spec.datasetClass,
            deviceTarget: "XCTest_DEBUG_export_harness",
            rowCounts: "products=\(spec.productCount)",
            fileSizeMB: productsSize,
            firstFeedbackSeconds: 0,
            totalDurationSeconds: productsDuration,
            resultState: "PASS",
            failureMode: "none",
            notes: "Products XLSX generated and re-read"
        )

        let fullStarted = DispatchTime.now().uptimeNanoseconds
        let fullURL = try Task089SyntheticBenchmarkHarness.exportFullDatabase(input: dataset.fullDatabaseExportInput)
        defer { try? FileManager.default.removeItem(at: fullURL) }
        let fullDuration = seconds(since: fullStarted)
        let fullSize = try fileSizeMB(fullURL)
        let fullProductRows = try ExcelAnalyzer.readSheetByName(at: fullURL, sheetName: "Products")
        let supplierRows = try ExcelAnalyzer.readSheetByName(at: fullURL, sheetName: "Suppliers")
        let categoryRows = try ExcelAnalyzer.readSheetByName(at: fullURL, sheetName: "Categories")
        let priceRows = try ExcelAnalyzer.readSheetByName(at: fullURL, sheetName: "PriceHistory")

        XCTAssertEqual(fullProductRows.count, spec.productCount + 1)
        XCTAssertEqual(supplierRows.count, spec.supplierCount + 1)
        XCTAssertEqual(categoryRows.count, spec.categoryCount + 1)
        XCTAssertEqual(priceRows.count, spec.priceHistoryCount + 1)

        recordMetric(
            scenarioID: "S100-D-full-db-export",
            datasetClass: spec.datasetClass,
            deviceTarget: "XCTest_DEBUG_export_harness",
            rowCounts: dataset.rowCountsDescription,
            fileSizeMB: fullSize,
            firstFeedbackSeconds: 0,
            totalDurationSeconds: fullDuration,
            resultState: "PASS",
            failureMode: "none",
            notes: "Full database XLSX generated and all sheets re-read"
        )
    }

    func testS100ESyncPreviewMediumSyntheticPagingBenchmark() async throws {
        let spec = Task100DatasetSpec.medium
        let dataset = Task100SyntheticDataset(spec: spec)
        let fetcher = Task100InventoryFetcherFake(dataset: dataset)
        let service = SupabasePullPreviewService(
            inventoryService: fetcher,
            pageSize: spec.pageSize,
            catalogRowBudget: nil,
            productPricePreviewSampleLimit: nil
        )

        let started = DispatchTime.now().uptimeNanoseconds
        let previewState = await service.generatePreview(context: try makeContext())
        let duration = seconds(since: started)

        guard case .success(let preview) = previewState else {
            return XCTFail("Expected successful synthetic preview, got \(previewState)")
        }
        XCTAssertEqual(preview.remoteCounts.products, spec.productCount)
        XCTAssertEqual(preview.remoteCounts.suppliers, spec.supplierCount)
        XCTAssertEqual(preview.remoteCounts.categories, spec.categoryCount)
        XCTAssertEqual(preview.remoteCounts.productPrices, spec.priceHistoryCount)
        XCTAssertEqual(preview.newProducts.count, spec.productCount)
        XCTAssertEqual(preview.priceHistoryDiffs.count, spec.priceHistoryCount)
        XCTAssertTrue(preview.conflicts.isEmpty)

        let ranges = await fetcher.rangeSummary()
        XCTAssertEqual(ranges.productPages, expectedPagedFetchCalls(rowCount: spec.productCount, pageSize: spec.pageSize))
        XCTAssertEqual(ranges.pricePages, expectedPagedFetchCalls(rowCount: spec.priceHistoryCount, pageSize: spec.pageSize))

        recordMetric(
            scenarioID: "S100-E-preview",
            datasetClass: spec.datasetClass,
            deviceTarget: "XCTest_fake_SupabasePullPreviewService",
            rowCounts: "\(dataset.rowCountsDescription);product_pages=\(ranges.productPages);price_pages=\(ranges.pricePages)",
            fileSizeMB: nil,
            firstFeedbackSeconds: 0,
            totalDurationSeconds: duration,
            resultState: "PASS",
            failureMode: "none",
            notes: "Paged preview uses bounded page size and synthetic remote rows"
        )
    }

    func testS100ESyncPreviewLargeSyntheticPagingBenchmarkWhenEnabled() async throws {
        try requireD100LEnabled()
        let spec = Task100DatasetSpec.large
        let dataset = Task100SyntheticDataset(spec: spec)
        let fetcher = Task100InventoryFetcherFake(dataset: dataset)
        let service = SupabasePullPreviewService(
            inventoryService: fetcher,
            pageSize: spec.pageSize,
            catalogRowBudget: nil,
            productPricePreviewSampleLimit: nil
        )

        let started = DispatchTime.now().uptimeNanoseconds
        let previewState = await service.generatePreview(context: try makeContext())
        let duration = seconds(since: started)

        guard case .success(let preview) = previewState else {
            return XCTFail("Expected successful synthetic preview, got \(previewState)")
        }
        XCTAssertEqual(preview.remoteCounts.products, spec.productCount)
        XCTAssertEqual(preview.remoteCounts.suppliers, spec.supplierCount)
        XCTAssertEqual(preview.remoteCounts.categories, spec.categoryCount)
        XCTAssertEqual(preview.remoteCounts.productPrices, spec.priceHistoryCount)
        XCTAssertEqual(preview.newProducts.count, spec.productCount)
        XCTAssertEqual(preview.priceHistoryDiffs.count, spec.priceHistoryCount)
        XCTAssertTrue(preview.conflicts.isEmpty)

        let ranges = await fetcher.rangeSummary()
        XCTAssertEqual(ranges.productPages, expectedPagedFetchCalls(rowCount: spec.productCount, pageSize: spec.pageSize))
        XCTAssertEqual(ranges.pricePages, expectedPagedFetchCalls(rowCount: spec.priceHistoryCount, pageSize: spec.pageSize))

        recordMetric(
            scenarioID: "S100-E-preview-D100-L",
            datasetClass: spec.datasetClass,
            deviceTarget: "XCTest_fake_SupabasePullPreviewService",
            rowCounts: "\(dataset.rowCountsDescription);product_pages=\(ranges.productPages);price_pages=\(ranges.pricePages)",
            fileSizeMB: nil,
            firstFeedbackSeconds: 0,
            totalDurationSeconds: duration,
            resultState: "PASS",
            failureMode: "none",
            notes: "D100-L paged preview uses bounded page size and synthetic remote rows"
        )
    }

    func testS100FProductPriceCurrentPreviousMediumBenchmark() throws {
        let spec = Task100DatasetSpec.medium
        let dataset = Task100SyntheticDataset(spec: spec)
        let context = try makeContext()
        try seedLocalCatalogForPriceApply(dataset: dataset, context: context)

        let service = SupabaseProductPriceApplyService()
        let started = DispatchTime.now().uptimeNanoseconds
        let plan = try service.prepareApplyPlan(
            remoteRows: dataset.productPrices,
            context: context,
            sessionSnapshot: ProductPriceApplySessionSnapshot(userID: dataset.ownerID)
        )

        XCTAssertTrue(plan.isApplyAllowed)
        XCTAssertEqual(plan.summary.included, spec.priceHistoryCount)
        let result = try service.apply(
            plan: plan,
            context: context,
            currentSessionSnapshot: ProductPriceApplySessionSnapshot(userID: dataset.ownerID)
        )

        XCTAssertEqual(result.inserted, spec.priceHistoryCount)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, spec.priceHistoryCount)
        try assertCurrentPreviousPrices(context: context, dataset: dataset, productIndex: 0)
        try assertCurrentPreviousPrices(context: context, dataset: dataset, productIndex: spec.productCount / 2)
        try assertCurrentPreviousPrices(context: context, dataset: dataset, productIndex: spec.productCount - 1)

        recordMetric(
            scenarioID: "S100-F",
            datasetClass: spec.datasetClass,
            deviceTarget: "XCTest_SupabaseProductPriceApplyService",
            rowCounts: "products=\(spec.productCount);product_prices=\(spec.priceHistoryCount)",
            fileSizeMB: nil,
            firstFeedbackSeconds: 0,
            totalDurationSeconds: seconds(since: started),
            resultState: "PASS",
            failureMode: "none",
            notes: "ProductPrice apply inserted current/previous purchase+retail and sample audit passed"
        )
    }

    func testS100FProductPriceCurrentPreviousLargeBenchmarkWhenEnabled() throws {
        try requireD100LEnabled()
        let spec = Task100DatasetSpec.large
        let dataset = Task100SyntheticDataset(spec: spec)
        let context = try makeContext()
        try seedLocalCatalogForPriceApply(dataset: dataset, context: context)

        let service = SupabaseProductPriceApplyService()
        let started = DispatchTime.now().uptimeNanoseconds
        let plan = try service.prepareApplyPlan(
            remoteRows: dataset.productPrices,
            context: context,
            sessionSnapshot: ProductPriceApplySessionSnapshot(userID: dataset.ownerID)
        )

        XCTAssertTrue(plan.isApplyAllowed)
        XCTAssertEqual(plan.summary.included, spec.priceHistoryCount)
        let result = try service.apply(
            plan: plan,
            context: context,
            currentSessionSnapshot: ProductPriceApplySessionSnapshot(userID: dataset.ownerID)
        )

        XCTAssertEqual(result.inserted, spec.priceHistoryCount)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, spec.priceHistoryCount)
        try assertCurrentPreviousPrices(context: context, dataset: dataset, productIndex: 0)
        try assertCurrentPreviousPrices(context: context, dataset: dataset, productIndex: spec.productCount / 2)
        try assertCurrentPreviousPrices(context: context, dataset: dataset, productIndex: spec.productCount - 1)

        recordMetric(
            scenarioID: "S100-F-D100-L",
            datasetClass: spec.datasetClass,
            deviceTarget: "XCTest_SupabaseProductPriceApplyService",
            rowCounts: "products=\(spec.productCount);product_prices=\(spec.priceHistoryCount)",
            fileSizeMB: nil,
            firstFeedbackSeconds: 0,
            totalDurationSeconds: seconds(since: started),
            resultState: "PASS",
            failureMode: "none",
            notes: "D100-L ProductPrice apply inserted current/previous purchase+retail and sample audit passed"
        )
    }

    func testS100GManualSyncFirstFeedbackCancelRetryRecoveryBenchmark() async throws {
        let coordinator = Task100DelayedCoordinator(delayNanoseconds: 500_000_000)
        let viewModel = SupabaseManualSyncViewModel(coordinator: coordinator)

        let started = DispatchTime.now().uptimeNanoseconds
        let run = Task { await viewModel.start(with: .dryRun) }

        while !viewModel.presentationState.isRunning && seconds(since: started) < 1 {
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        let firstFeedback = seconds(since: started)

        XCTAssertTrue(viewModel.presentationState.isRunning)
        XCTAssertTrue(viewModel.presentationState.isLoading)
        XCTAssertNil(viewModel.presentationState.primaryAction)
        XCTAssertEqual(viewModel.presentationState.secondaryAction?.id, .cancel)

        let cancelStarted = DispatchTime.now().uptimeNanoseconds
        run.cancel()
        await run.value
        let cancelRecovery = seconds(since: cancelStarted)

        XCTAssertEqual(viewModel.presentationKind, .cancelledRun)
        XCTAssertEqual(viewModel.presentationState.primaryAction?.id, .retry)
        XCTAssertNil(viewModel.presentationState.secondaryAction)

        recordMetric(
            scenarioID: "S100-G-cancel-retry",
            datasetClass: "D100-M",
            deviceTarget: "XCTest_SupabaseManualSyncViewModel_fake",
            rowCounts: "not_applicable",
            fileSizeMB: nil,
            firstFeedbackSeconds: firstFeedback,
            totalDurationSeconds: firstFeedback + cancelRecovery,
            resultState: "PASS",
            failureMode: "none",
            notes: "running state exposes cancel; cancelled state exposes retry without success"
        )
    }

    func testS100ILiveSupabaseLargeWritePreviewAndCleanupWhenEnabled() async throws {
        try requireLiveSupabaseEnabled()
        let runtime = try await makeLiveRuntime()
        let runID = task100LiveRunID()
        let prefix = "TASK100_LIVE_\(runID)_"
        let productCount = 120
        let priceRowsPerProduct = 4
        let expectedPriceRows = productCount * priceRowsPerProduct
        let rowCounts = "products=\(productCount);suppliers=1;categories=1;product_prices=\(expectedPriceRows)"

        XCTAssertFalse(runtime.config.publishableKey.lowercased().contains("service_role"))
        XCTAssertFalse(runtime.session.isExpired)

        do {
            let collision = try await fetchLiveCollision(runtime: runtime, prefix: prefix)
            guard collision.totalCount == 0 else {
                recordMetric(
                    scenarioID: "S100-I-live-collision-scan",
                    datasetClass: "TASK100-LIVE",
                    deviceTarget: "Live_Supabase_authenticated",
                    rowCounts: collision.description,
                    fileSizeMB: nil,
                    firstFeedbackSeconds: 0,
                    totalDurationSeconds: 0,
                    resultState: "BLOCKED",
                    failureMode: "prefix_collision",
                    notes: "run=\(runID); pre-write collision scan found existing TASK100_* rows"
                )
                throw Task100LiveValidationError.blocked("Live prefix collision found before write: \(collision.description).")
            }

            let context = try makeLiveSyncContext()
            _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
                context: context,
                ownerUserUUID: runtime.session.userID
            )
            let localProducts = try seedLiveCatalog(
                context: context,
                ownerUserID: runtime.session.userID,
                prefix: prefix,
                productCount: productCount
            )

            let catalogStarted = DispatchTime.now().uptimeNanoseconds
            let catalogFirstFeedback = seconds(since: catalogStarted)
            let catalogAggregated = try await LocalPendingAggregatedPushPlanner(
                context: context,
                includesCatalog: true,
                includesProductPrice: false
            ).makePlan(ownerUserID: runtime.session.userID)
            guard catalogAggregated.blockers.isEmpty else {
                recordMetric(
                    scenarioID: "S100-I-live-catalog-push",
                    datasetClass: "TASK100-LIVE",
                    deviceTarget: "Live_Supabase_authenticated",
                    rowCounts: rowCounts,
                    fileSizeMB: nil,
                    firstFeedbackSeconds: catalogFirstFeedback,
                    totalDurationSeconds: seconds(since: catalogStarted),
                    resultState: "BLOCKED",
                    failureMode: "catalog_preflight_blocked",
                    notes: "run=\(runID); blockers=\(joinedRawValues(catalogAggregated.blockers))"
                )
                throw Task100LiveValidationError.blocked("Catalog preflight blocked: \(catalogAggregated.blockers)")
            }
            guard let catalogBatch = catalogAggregated.catalogBatch else {
                throw Task100LiveValidationError.blocked("Catalog preflight produced no sendable batch.")
            }
            try LocalPendingAggregatedPushStateStore(context: context).markSent(
                changeIDs: catalogBatch.changeIDs,
                ownerUserID: runtime.session.userID,
                planFingerprint: catalogBatch.plan.planFingerprint
            )
            let catalogPush = await SupabaseManualPushService(clientProvider: runtime.provider).execute(
                plan: catalogBatch.plan,
                context: context,
                ownerUserID: runtime.session.userID
            )
            guard catalogPush.status == .completed else {
                recordMetric(
                    scenarioID: "S100-I-live-catalog-push",
                    datasetClass: "TASK100-LIVE",
                    deviceTarget: "Live_Supabase_authenticated",
                    rowCounts: rowCounts,
                    fileSizeMB: nil,
                    firstFeedbackSeconds: catalogFirstFeedback,
                    totalDurationSeconds: seconds(since: catalogStarted),
                    resultState: "BLOCKED",
                    failureMode: "catalog_push_\(catalogPush.status.rawValue)",
                    notes: "run=\(runID); message=\(catalogPush.message ?? "none")"
                )
                throw Task100LiveValidationError.blocked("Catalog push ended with \(catalogPush.status.rawValue).")
            }
            try LocalPendingAggregatedPushStateStore(context: context).markAcknowledged(
                changeIDs: catalogBatch.changeIDs,
                ownerUserID: runtime.session.userID
            )
            guard localProducts.allSatisfy({ $0.remoteID != nil }) else {
                throw Task100LiveValidationError.blocked("Catalog push completed without linking every local product.")
            }

            recordMetric(
                scenarioID: "S100-I-live-catalog-push",
                datasetClass: "TASK100-LIVE",
                deviceTarget: "Live_Supabase_authenticated",
                rowCounts: rowCounts,
                fileSizeMB: nil,
                firstFeedbackSeconds: catalogFirstFeedback,
                totalDurationSeconds: seconds(since: catalogStarted),
                resultState: "PASS",
                failureMode: "none",
                notes: "run=\(runID); collision scan clear; catalog pushed with release service"
            )

            try seedLiveProductPrices(
                context: context,
                products: localProducts,
                ownerUserID: runtime.session.userID,
                runID: runID
            )

            let priceStarted = DispatchTime.now().uptimeNanoseconds
            let priceFirstFeedback = seconds(since: priceStarted)
            var pushedPriceRows = 0
            var priceBatches = 0
            var remoteDedupePages = 0
            var duplicateRecovery = "not_run"
            let priceOptions = ProductPriceManualPushOptions(readBackPageSize: 50, readBackMaxPages: 20)
            let pricePushService = SupabaseProductPriceManualPushService(
                remote: runtime.productPriceRemote,
                options: priceOptions
            )

            while pushedPriceRows < expectedPriceRows {
                let aggregated = try await LocalPendingAggregatedPushPlanner(
                    context: context,
                    priceRemoteFetcher: runtime.productPriceRemote,
                    softBatchLimit: 250,
                    priceFetchOptions: ProductPricePushDryRunFetchOptions(
                        batchSize: 60,
                        pageSize: 50,
                        maxPagesPerBatch: 20,
                        maxRemoteRows: 50_000
                    ),
                    includesCatalog: false,
                    includesProductPrice: true
                ).makePlan(ownerUserID: runtime.session.userID)
                guard aggregated.blockers.isEmpty else {
                    recordMetric(
                        scenarioID: "S100-I-live-price-push",
                        datasetClass: "TASK100-LIVE",
                        deviceTarget: "Live_Supabase_authenticated",
                        rowCounts: "\(rowCounts);price_batches=\(priceBatches);dedupe_pages=\(remoteDedupePages)",
                        fileSizeMB: nil,
                        firstFeedbackSeconds: priceFirstFeedback,
                        totalDurationSeconds: seconds(since: priceStarted),
                        resultState: "BLOCKED",
                        failureMode: "price_preflight_blocked",
                        notes: "run=\(runID); blockers=\(joinedRawValues(aggregated.blockers))"
                    )
                    throw Task100LiveValidationError.blocked("ProductPrice preflight blocked: \(aggregated.blockers)")
                }
                guard let priceBatch = aggregated.productPriceBatch else {
                    throw Task100LiveValidationError.blocked("ProductPrice preflight produced no sendable batch.")
                }
                guard priceBatch.plan.summary.readyCandidates <= ProductPriceManualPushOptions.defaultBatchLimit,
                      priceBatch.plan.summary.readyCandidates > 0 else {
                    throw Task100LiveValidationError.blocked(
                        "ProductPrice ready candidates outside expected batch bounds: \(priceBatch.plan.summary.readyCandidates)."
                    )
                }
                remoteDedupePages += priceBatch.plan.summary.remotePagesRead

                let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(
                    from: priceBatch.plan,
                    options: priceOptions
                )
                try LocalPendingAggregatedPushStateStore(context: context).markSent(
                    changeIDs: priceBatch.changeIDs,
                    ownerUserID: runtime.session.userID,
                    planFingerprint: productPricePushFingerprint(priceBatch.plan)
                )
                let push = try await pricePushService.push(snapshot: snapshot)
                guard push.isVerifiedSuccess, push.insertedCount == snapshot.payloads.count else {
                    throw Task100LiveValidationError.blocked(
                        "ProductPrice push verification failed; inserted=\(push.insertedCount), expected=\(snapshot.payloads.count)."
                    )
                }

                if priceBatches == 0 {
                    let duplicatePush = try await pricePushService.push(snapshot: snapshot)
                    guard duplicatePush.isVerifiedSuccess, duplicatePush.insertedCount == 0 else {
                        throw Task100LiveValidationError.blocked(
                            "ProductPrice duplicate recovery failed; inserted=\(duplicatePush.insertedCount)."
                        )
                    }
                    duplicateRecovery = "unique_conflict_exact_match"
                }

                XCTAssertEqual(
                    try ProductPriceManualPushIdentityReconciler().linkVerifiedPayloads(
                        snapshot.payloads,
                        context: context
                    ),
                    snapshot.payloads.count
                )
                try LocalPendingAggregatedPushStateStore(context: context).markAcknowledged(
                    changeIDs: priceBatch.changeIDs,
                    ownerUserID: runtime.session.userID
                )

                pushedPriceRows += push.insertedCount
                priceBatches += 1
            }

            XCTAssertEqual(pushedPriceRows, expectedPriceRows)
            recordMetric(
                scenarioID: "S100-I-live-price-push",
                datasetClass: "TASK100-LIVE",
                deviceTarget: "Live_Supabase_authenticated",
                rowCounts: "\(rowCounts);price_batches=\(priceBatches);dedupe_pages=\(remoteDedupePages)",
                fileSizeMB: nil,
                firstFeedbackSeconds: priceFirstFeedback,
                totalDurationSeconds: seconds(since: priceStarted),
                resultState: "PASS",
                failureMode: "none",
                notes: "run=\(runID); ProductPrice batch cap respected; duplicate recovery=\(duplicateRecovery)"
            )

            let readBackStarted = DispatchTime.now().uptimeNanoseconds
            let remoteSuppliers = try await fetchLiveSuppliers(runtime: runtime, prefix: prefix)
            let remoteCategories = try await fetchLiveCategories(runtime: runtime, prefix: prefix)
            let remoteProducts = try await fetchLiveProducts(runtime: runtime, prefix: prefix)
            guard remoteSuppliers.count == 1,
                  remoteCategories.count == 1,
                  remoteProducts.count == productCount else {
                throw Task100LiveValidationError.blocked(
                    "Live read-back count mismatch: suppliers=\(remoteSuppliers.count), categories=\(remoteCategories.count), products=\(remoteProducts.count)."
                )
            }
            let remotePrices = try await fetchLivePrices(
                inventory: runtime.productPriceRemote,
                ownerUserID: runtime.session.userID,
                productIDs: remoteProducts.map(\.id)
            )
            guard remotePrices.count == expectedPriceRows else {
                throw Task100LiveValidationError.blocked(
                    "Live ProductPrice read-back count mismatch: prices=\(remotePrices.count), expected=\(expectedPriceRows)."
                )
            }

            let previewStarted = DispatchTime.now().uptimeNanoseconds
            let scopedPreviewFetcher = Task100InventoryRowsFetcher(
                products: remoteProducts,
                suppliers: remoteSuppliers,
                categories: remoteCategories,
                productPrices: remotePrices
            )
            let previewState = await SupabasePullPreviewService(
                inventoryService: scopedPreviewFetcher,
                pageSize: 50,
                catalogRowBudget: nil,
                productPricePreviewSampleLimit: nil
            ).generatePreview(context: try makeContext())
            guard case .success(let preview) = previewState else {
                throw Task100LiveValidationError.blocked("Expected successful scoped live preview, got \(previewState).")
            }
            XCTAssertEqual(preview.remoteCounts.products, productCount)
            XCTAssertEqual(preview.remoteCounts.productPrices, expectedPriceRows)
            XCTAssertEqual(preview.newProducts.count, productCount)
            XCTAssertEqual(preview.priceHistoryDiffs.count, expectedPriceRows)
            let previewRanges = await scopedPreviewFetcher.rangeSummary()

            recordMetric(
                scenarioID: "S100-I-live-preview",
                datasetClass: "TASK100-LIVE",
                deviceTarget: "Live_Supabase_authenticated_scoped_TASK100",
                rowCounts: "\(rowCounts);product_pages=\(previewRanges.productPages);price_pages=\(previewRanges.pricePages);page_size=50",
                fileSizeMB: nil,
                firstFeedbackSeconds: 0,
                totalDurationSeconds: seconds(since: previewStarted),
                resultState: "PASS",
                failureMode: "none",
                notes: "run=\(runID); live TASK100_* rows read back and previewed through paged diff engine"
            )

            let readBackContext = try makeContext()
            try seedRemoteProductsForApply(
                remoteProducts,
                context: readBackContext
            )
            let applyPlan = try SupabaseProductPriceApplyService().prepareApplyPlan(
                remoteRows: remotePrices,
                context: readBackContext,
                sessionSnapshot: ProductPriceApplySessionSnapshot(userID: runtime.session.userID)
            )
            guard applyPlan.isApplyAllowed else {
                throw Task100LiveValidationError.blocked(
                    "Live ProductPrice read-back apply plan was not allowed: \(applyPlan.blockReasons)."
                )
            }
            let applyResult = try SupabaseProductPriceApplyService().apply(
                plan: applyPlan,
                context: readBackContext,
                currentSessionSnapshot: ProductPriceApplySessionSnapshot(userID: runtime.session.userID)
            )
            XCTAssertEqual(applyResult.inserted, expectedPriceRows)
            try assertLiveCurrentPreviousPrices(context: readBackContext, prefix: prefix, productIndex: 0)
            try assertLiveCurrentPreviousPrices(context: readBackContext, prefix: prefix, productIndex: productCount / 2)
            try assertLiveCurrentPreviousPrices(context: readBackContext, prefix: prefix, productIndex: productCount - 1)

            recordMetric(
                scenarioID: "S100-I-live-readback-apply",
                datasetClass: "TASK100-LIVE",
                deviceTarget: "Live_Supabase_authenticated",
                rowCounts: rowCounts,
                fileSizeMB: nil,
                firstFeedbackSeconds: 0,
                totalDurationSeconds: seconds(since: readBackStarted),
                resultState: "PASS",
                failureMode: "none",
                notes: "run=\(runID); live read-back applied locally and current/previous audit passed"
            )

            let cleanupStarted = DispatchTime.now().uptimeNanoseconds
            let cleanup = try await cleanupLiveRows(runtime: runtime, prefix: prefix)
            let postCleanup = try await fetchLiveCollision(runtime: runtime, prefix: prefix)
            guard postCleanup.totalCount == 0 else {
                throw Task100LiveValidationError.blocked("Cleanup left remote TASK100_* rows: \(postCleanup.description).")
            }
            recordMetric(
                scenarioID: "S100-I-live-cleanup",
                datasetClass: "TASK100-LIVE",
                deviceTarget: "Live_Supabase_authenticated",
                rowCounts: cleanup.description,
                fileSizeMB: nil,
                firstFeedbackSeconds: 0,
                totalDurationSeconds: seconds(since: cleanupStarted),
                resultState: "PASS",
                failureMode: "none",
                notes: "run=\(runID); cleanup completed and collision scan returned zero"
            )
        } catch {
            let cleanup = try? await cleanupLiveRows(runtime: runtime, prefix: prefix)
            recordMetric(
                scenarioID: "S100-I-live-failure-cleanup",
                datasetClass: "TASK100-LIVE",
                deviceTarget: "Live_Supabase_authenticated",
                rowCounts: cleanup?.description ?? "cleanup_not_confirmed",
                fileSizeMB: nil,
                firstFeedbackSeconds: 0,
                totalDurationSeconds: 0,
                resultState: "BLOCKED",
                failureMode: "live_supabase_error",
                notes: "run=\(runID); attempted cleanup after failure"
            )
            throw error
        }
    }

    func testS100JLiveSupabaseCleanupPrefixWhenEnabled() async throws {
        try requireLiveSupabaseEnabled()
        let environment = ProcessInfo.processInfo.environment
        guard let prefix = environment["TASK100_LIVE_CLEANUP_PREFIX"],
              prefix.hasPrefix("TASK100_LIVE_"),
              prefix.hasSuffix("_") else {
            throw XCTSkip("Set TASK100_LIVE_CLEANUP_PREFIX to an exact TASK100_LIVE_*_ prefix for targeted cleanup.")
        }

        let runtime = try await makeLiveRuntime()
        let before = try await fetchLiveCollision(runtime: runtime, prefix: prefix)
        let started = DispatchTime.now().uptimeNanoseconds
        do {
            let cleanup = try await cleanupLiveRows(runtime: runtime, prefix: prefix)
            let after = try await fetchLiveCollision(runtime: runtime, prefix: prefix)
            XCTAssertEqual(after.totalCount, 0)
            recordMetric(
                scenarioID: "S100-I-live-targeted-cleanup",
                datasetClass: "TASK100-LIVE",
                deviceTarget: "Live_Supabase_authenticated",
                rowCounts: "before=\(before.description);\(cleanup.description);after=\(after.description)",
                fileSizeMB: nil,
                firstFeedbackSeconds: 0,
                totalDurationSeconds: seconds(since: started),
                resultState: after.totalCount == 0 ? "PASS" : "BLOCKED",
                failureMode: after.totalCount == 0 ? "none" : "cleanup_residue",
                notes: "prefix=\(prefix); targeted cleanup for interrupted TASK-100 live run"
            )
        } catch {
            recordMetric(
                scenarioID: "S100-I-live-targeted-cleanup",
                datasetClass: "TASK100-LIVE",
                deviceTarget: "Live_Supabase_authenticated",
                rowCounts: "before=\(before.description);cleanup_not_confirmed",
                fileSizeMB: nil,
                firstFeedbackSeconds: 0,
                totalDurationSeconds: seconds(since: started),
                resultState: "BLOCKED",
                failureMode: "cleanup_permission_denied_or_failed",
                notes: "prefix=\(prefix); cleanup failed with sanitized error"
            )
            throw error
        }
    }

    func testS100KLiveSupabaseReadOnlyVerificationForExistingPrefixWhenEnabled() async throws {
        try requireLiveSupabaseEnabled()
        let environment = ProcessInfo.processInfo.environment
        guard let prefix = environment["TASK100_LIVE_READONLY_PREFIX"],
              prefix.hasPrefix("TASK100_LIVE_"),
              prefix.hasSuffix("_") else {
            throw XCTSkip("Set TASK100_LIVE_READONLY_PREFIX to an exact TASK100_LIVE_*_ prefix for read-only verification.")
        }

        let runtime = try await makeLiveRuntime()
        let started = DispatchTime.now().uptimeNanoseconds
        let remoteSuppliers = try await fetchLiveSuppliers(runtime: runtime, prefix: prefix)
        let remoteCategories = try await fetchLiveCategories(runtime: runtime, prefix: prefix)
        let remoteProducts = try await fetchLiveProducts(runtime: runtime, prefix: prefix)
        let remotePrices = try await fetchLivePrices(
            inventory: runtime.productPriceRemote,
            ownerUserID: runtime.session.userID,
            productIDs: remoteProducts.map(\.id)
        )
        let rowCounts = "products=\(remoteProducts.count);suppliers=\(remoteSuppliers.count);categories=\(remoteCategories.count);product_prices=\(remotePrices.count)"
        guard remoteSuppliers.count == 1,
              remoteCategories.count == 1,
              remoteProducts.count >= 3,
              remotePrices.count == remoteProducts.count * 4 else {
            recordMetric(
                scenarioID: "S100-I-live-readonly-verify",
                datasetClass: "TASK100-LIVE",
                deviceTarget: "Live_Supabase_authenticated_readonly_TASK100",
                rowCounts: rowCounts,
                fileSizeMB: nil,
                firstFeedbackSeconds: 0,
                totalDurationSeconds: seconds(since: started),
                resultState: "BLOCKED",
                failureMode: "readonly_count_mismatch",
                notes: "prefix=\(prefix); read-only verification found unexpected live row counts"
            )
            throw Task100LiveValidationError.blocked("Live read-only count mismatch: \(rowCounts).")
        }

        let scopedPreviewFetcher = Task100InventoryRowsFetcher(
            products: remoteProducts,
            suppliers: remoteSuppliers,
            categories: remoteCategories,
            productPrices: remotePrices
        )
        let previewState = await SupabasePullPreviewService(
            inventoryService: scopedPreviewFetcher,
            pageSize: 50,
            catalogRowBudget: nil,
            productPricePreviewSampleLimit: nil
        ).generatePreview(context: try makeContext())
        guard case .success(let preview) = previewState else {
            throw Task100LiveValidationError.blocked("Expected successful read-only live preview, got \(previewState).")
        }
        XCTAssertEqual(preview.remoteCounts.products, remoteProducts.count)
        XCTAssertEqual(preview.remoteCounts.productPrices, remotePrices.count)
        XCTAssertEqual(preview.newProducts.count, remoteProducts.count)
        XCTAssertEqual(preview.priceHistoryDiffs.count, remotePrices.count)

        let readBackContext = try makeContext()
        try seedRemoteProductsForApply(remoteProducts, context: readBackContext)
        let applyPlan = try SupabaseProductPriceApplyService().prepareApplyPlan(
            remoteRows: remotePrices,
            context: readBackContext,
            sessionSnapshot: ProductPriceApplySessionSnapshot(userID: runtime.session.userID)
        )
        guard applyPlan.isApplyAllowed else {
            throw Task100LiveValidationError.blocked(
                "Live read-only ProductPrice apply plan was not allowed: \(applyPlan.blockReasons)."
            )
        }
        let applyResult = try SupabaseProductPriceApplyService().apply(
            plan: applyPlan,
            context: readBackContext,
            currentSessionSnapshot: ProductPriceApplySessionSnapshot(userID: runtime.session.userID)
        )
        XCTAssertEqual(applyResult.inserted, remotePrices.count)
        try assertLiveCurrentPreviousPrices(context: readBackContext, prefix: prefix, productIndex: 0)
        try assertLiveCurrentPreviousPrices(context: readBackContext, prefix: prefix, productIndex: remoteProducts.count / 2)
        try assertLiveCurrentPreviousPrices(context: readBackContext, prefix: prefix, productIndex: remoteProducts.count - 1)

        let previewRanges = await scopedPreviewFetcher.rangeSummary()
        recordMetric(
            scenarioID: "S100-I-live-readonly-verify",
            datasetClass: "TASK100-LIVE",
            deviceTarget: "Live_Supabase_authenticated_readonly_TASK100",
            rowCounts: "\(rowCounts);product_pages=\(previewRanges.productPages);price_pages=\(previewRanges.pricePages);page_size=50",
            fileSizeMB: nil,
            firstFeedbackSeconds: 0,
            totalDurationSeconds: seconds(since: started),
            resultState: "PASS",
            failureMode: "none",
            notes: "prefix=\(prefix); existing live TASK100_* rows previewed and applied locally without remote mutation"
        )
    }

    private func assertDataset(_ dataset: Task100SyntheticDataset, spec: Task100DatasetSpec) {
        XCTAssertEqual(dataset.suppliers.count, spec.supplierCount)
        XCTAssertEqual(dataset.categories.count, spec.categoryCount)
        XCTAssertEqual(dataset.products.count, spec.productCount)
        XCTAssertEqual(dataset.productPrices.count, spec.priceHistoryCount)
        XCTAssertTrue(dataset.products.allSatisfy { $0.barcode.hasPrefix("TASK100_BAR_") })
        XCTAssertTrue(dataset.productPrices.allSatisfy { $0.source == "TASK100_SYNTHETIC" })
    }

    private func requireD100LEnabled() throws {
        let environment = ProcessInfo.processInfo.environment
        let value = (environment["TASK100_D100L"] ?? environment["SIMCTL_CHILD_TASK100_D100L"])?.lowercased()
        let sentinelPath = "/tmp/TASK100_D100L"
        guard value == "1" || value == "true" || FileManager.default.fileExists(atPath: sentinelPath) else {
            throw XCTSkip("Set TASK100_D100L=1 in the XCTest environment, or create \(sentinelPath), to run the expensive D100-L acceptance scenarios.")
        }
    }

    private func requireLiveSupabaseEnabled() throws {
        let environment = ProcessInfo.processInfo.environment
        let value = (environment["TASK100_LIVE_SUPABASE"] ?? environment["SIMCTL_CHILD_TASK100_LIVE_SUPABASE"])?.lowercased()
        let sentinelPath = "/tmp/TASK100_LIVE_SUPABASE"
        guard value == "1" || value == "true" || FileManager.default.fileExists(atPath: sentinelPath) else {
            throw XCTSkip("Set TASK100_LIVE_SUPABASE=1 in the XCTest environment, or create \(sentinelPath), to run the live TASK-100 Supabase write/sync acceptance scenario.")
        }
    }

    private func makeLiveRuntime() async throws -> Task100LiveRuntime {
        let config = try SupabaseConfig.load()
        let provider = SupabaseClientProvider(config: config)
        let session = try await provider.client.auth.session
        return Task100LiveRuntime(
            config: config,
            provider: provider,
            inventory: SupabaseTransportClient(clientProvider: provider),
            session: Task100LiveSession(userID: session.user.id, isExpired: session.isExpired)
        )
    }

    private func task100LiveRunID() -> String {
        let environment = ProcessInfo.processInfo.environment
        let raw = environment["TASK100_LIVE_RUN_ID"]
            ?? environment["SIMCTL_CHILD_TASK100_LIVE_RUN_ID"]
            ?? String(Int(Date().timeIntervalSince1970))
        let normalized = raw.uppercased().unicodeScalars.compactMap { scalar -> String? in
            switch scalar.value {
            case 48...57, 65...90:
                return String(scalar)
            default:
                return nil
            }
        }.joined()
        return String((normalized.isEmpty ? "RUN\(Int(Date().timeIntervalSince1970))" : normalized).prefix(18))
    }

    private func makeLiveSyncContext() throws -> ModelContext {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            ProductPrice.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self,
            LocalPendingChange.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        let context = ModelContext(container)
        Self.retainedContexts.append(context)
        return context
    }

    private func seedLiveCatalog(
        context: ModelContext,
        ownerUserID: UUID,
        prefix: String,
        productCount: Int
    ) throws -> [Product] {
        let supplier = Supplier(name: "\(prefix)SUPPLIER")
        let category = ProductCategory(name: "\(prefix)CATEGORY")
        context.insert(supplier)
        context.insert(category)

        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: ownerUserID)
        try accumulator.recordSupplierChange(
            supplier: supplier,
            operation: .create,
            origin: .manualCatalogSave
        )
        try accumulator.recordCategoryChange(
            category: category,
            operation: .create,
            origin: .manualCatalogSave
        )

        var products: [Product] = []
        for index in 0..<productCount {
            let expected = Task100SyntheticDataset.expectedPrices(forProductIndex: index)
            let product = Product(
                barcode: liveBarcode(prefix: prefix, index: index),
                itemNumber: String(format: "\(prefix)ITEM_%04d", index),
                productName: String(format: "\(prefix)PRODUCT_%04d", index),
                secondProductName: String(format: "\(prefix)SECOND_%04d", index),
                purchasePrice: expected.purchaseCurrent,
                retailPrice: expected.retailCurrent,
                stockQuantity: Double(index % 150),
                supplier: supplier,
                category: category
            )
            context.insert(product)
            try accumulator.recordProductChange(
                product: product,
                operation: .create,
                origin: .manualCatalogSave,
                changedFields: [
                    "barcode",
                    "itemNumber",
                    "productName",
                    "secondProductName",
                    "purchasePrice",
                    "retailPrice",
                    "stockQuantity",
                    "supplier",
                    "category"
                ]
            )
            products.append(product)
        }
        try context.save()
        return products
    }

    private func seedLiveProductPrices(
        context: ModelContext,
        products: [Product],
        ownerUserID: UUID,
        runID: String
    ) throws {
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: ownerUserID)
        let sortedProducts = products.sorted { $0.barcode < $1.barcode }
        var inserted = 0

        for (index, product) in sortedProducts.enumerated() {
            let expected = Task100SyntheticDataset.expectedPrices(forProductIndex: index)
            let points: [(PriceType, Double, TimeInterval)] = [
                (.purchase, expected.purchasePrevious, 0),
                (.purchase, expected.purchaseCurrent, 60),
                (.retail, expected.retailPrevious, 120),
                (.retail, expected.retailCurrent, 180)
            ]

            for (type, price, offset) in points {
                let effectiveAt = livePriceDate(productIndex: index, offset: offset)
                let row = ProductPrice(
                    type: type,
                    price: price,
                    effectiveAt: effectiveAt,
                    source: "TASK100_LIVE",
                    note: runID,
                    createdAt: effectiveAt,
                    product: product
                )
                context.insert(row)
                try accumulator.recordProductPriceChange(price: row, origin: .productPriceSave)
                inserted += 1
                try saveIfNeeded(context, after: inserted)
            }
        }
        try context.save()
    }

    private func seedRemoteProductsForApply(
        _ products: [RemoteInventoryProductRow],
        context: ModelContext
    ) throws {
        let supplier = Supplier(name: "TASK100_LIVE_READBACK_SUPPLIER")
        let category = ProductCategory(name: "TASK100_LIVE_READBACK_CATEGORY")
        context.insert(supplier)
        context.insert(category)

        for row in products {
            context.insert(
                Product(
                    barcode: row.barcode,
                    remoteID: row.id,
                    remoteUpdatedAt: SupabaseRemoteDateParser.parse(row.updatedAt),
                    remoteDeletedAt: SupabaseRemoteDateParser.parse(row.deletedAt),
                    itemNumber: row.itemNumber,
                    productName: row.productName,
                    secondProductName: row.secondProductName,
                    purchasePrice: row.purchasePrice,
                    retailPrice: row.retailPrice,
                    stockQuantity: row.stockQuantity,
                    supplier: supplier,
                    category: category
                )
            )
        }
        try context.save()
    }

    private func assertLiveCurrentPreviousPrices(
        context: ModelContext,
        prefix: String,
        productIndex: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let barcode = liveBarcode(prefix: prefix, index: productIndex)
        let descriptor = FetchDescriptor<Product>(
            predicate: #Predicate { $0.barcode == barcode }
        )
        let product = try XCTUnwrap(context.fetch(descriptor).first, file: file, line: line)
        let expected = Task100SyntheticDataset.expectedPrices(forProductIndex: productIndex)
        try assertPricePair(
            product: product,
            type: .purchase,
            previous: expected.purchasePrevious,
            current: expected.purchaseCurrent,
            file: file,
            line: line
        )
        try assertPricePair(
            product: product,
            type: .retail,
            previous: expected.retailPrevious,
            current: expected.retailCurrent,
            file: file,
            line: line
        )
    }

    private func fetchLiveCollision(
        runtime: Task100LiveRuntime,
        prefix: String
    ) async throws -> Task100LiveCollision {
        async let suppliers = fetchLiveSuppliers(runtime: runtime, prefix: prefix)
        async let categories = fetchLiveCategories(runtime: runtime, prefix: prefix)
        async let products = fetchLiveProducts(runtime: runtime, prefix: prefix)
        let resolvedProducts = try await products
        let prices = try await fetchLivePrices(
            inventory: runtime.productPriceRemote,
            ownerUserID: runtime.session.userID,
            productIDs: resolvedProducts.map(\.id)
        )
        return try await Task100LiveCollision(
            supplierCount: suppliers.count,
            categoryCount: categories.count,
            productCount: resolvedProducts.count,
            productPriceCount: prices.count
        )
    }

    private func fetchLiveSuppliers(
        runtime: Task100LiveRuntime,
        prefix: String
    ) async throws -> [RemoteInventorySupplierRow] {
        try await runtime.provider.client
            .from("inventory_suppliers")
            .select("id,owner_user_id,name,updated_at,deleted_at")
            .eq("owner_user_id", value: runtime.session.userID.uuidString)
            .like("name", pattern: "\(prefix)%")
            .order(SupabaseTransportClient.stablePageOrderColumn, ascending: true)
            .limit(1_000)
            .execute()
            .value
    }

    private func fetchLiveCategories(
        runtime: Task100LiveRuntime,
        prefix: String
    ) async throws -> [RemoteInventoryCategoryRow] {
        try await runtime.provider.client
            .from("inventory_categories")
            .select("id,owner_user_id,name,updated_at,deleted_at")
            .eq("owner_user_id", value: runtime.session.userID.uuidString)
            .like("name", pattern: "\(prefix)%")
            .order(SupabaseTransportClient.stablePageOrderColumn, ascending: true)
            .limit(1_000)
            .execute()
            .value
    }

    private func fetchLiveProducts(
        runtime: Task100LiveRuntime,
        prefix: String
    ) async throws -> [RemoteInventoryProductRow] {
        try await runtime.provider.client
            .from("inventory_products")
            .select("id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at")
            .eq("owner_user_id", value: runtime.session.userID.uuidString)
            .like("barcode", pattern: "\(prefix)%")
            .order("barcode", ascending: true)
            .limit(1_000)
            .execute()
            .value
    }

    private func fetchLivePrices(
        inventory: ProductPriceReleaseRemoteSupabaseAdapter,
        ownerUserID: UUID,
        productIDs: [UUID]
    ) async throws -> [RemoteInventoryProductPriceRow] {
        guard !productIDs.isEmpty else { return [] }
        var rows: [RemoteInventoryProductPriceRow] = []
        for productIDBatch in productIDs.chunked(into: 100) {
            var offset = 0
            for _ in 0..<20 {
                let page = try await inventory.fetchProductPricesForManualPushVerificationPage(
                    ownerUserID: ownerUserID,
                    productIDs: productIDBatch,
                    from: offset,
                    to: offset + 999
                )
                rows.append(contentsOf: page)
                if page.count < 1_000 { break }
                offset += 1_000
            }
        }
        return rows
    }

    private func cleanupLiveRows(
        runtime: Task100LiveRuntime,
        prefix: String
    ) async throws -> Task100LiveCleanupSummary {
        let products = try await fetchLiveProducts(runtime: runtime, prefix: prefix)
        let productIDs = products.map(\.id)
        let prices = try await fetchLivePrices(
            inventory: runtime.productPriceRemote,
            ownerUserID: runtime.session.userID,
            productIDs: productIDs
        )

        for batch in productIDs.map(\.uuidString).chunked(into: 100) {
            try await runtime.provider.client
                .from("inventory_product_prices")
                .delete()
                .eq("owner_user_id", value: runtime.session.userID.uuidString)
                .in("product_id", values: batch)
                .execute()
        }

        if !products.isEmpty {
            try await runtime.provider.client
                .from("inventory_products")
                .delete()
                .eq("owner_user_id", value: runtime.session.userID.uuidString)
                .like("barcode", pattern: "\(prefix)%")
                .execute()
        }

        let suppliers = try await fetchLiveSuppliers(runtime: runtime, prefix: prefix)
        if !suppliers.isEmpty {
            try await runtime.provider.client
                .from("inventory_suppliers")
                .delete()
                .eq("owner_user_id", value: runtime.session.userID.uuidString)
                .like("name", pattern: "\(prefix)%")
                .execute()
        }

        let categories = try await fetchLiveCategories(runtime: runtime, prefix: prefix)
        if !categories.isEmpty {
            try await runtime.provider.client
                .from("inventory_categories")
                .delete()
                .eq("owner_user_id", value: runtime.session.userID.uuidString)
                .like("name", pattern: "\(prefix)%")
                .execute()
        }

        return Task100LiveCleanupSummary(
            supplierCount: suppliers.count,
            categoryCount: categories.count,
            productCount: products.count,
            productPriceCount: prices.count
        )
    }

    private func productPricePushFingerprint(_ plan: ProductPricePushDryRunPlan) -> String {
        let candidates = plan.candidates.map { line -> String in
            [
                line.key?.stableID ?? "",
                line.canonicalPrice?.value ?? "",
                line.createdAtCanonical ?? "",
                line.source ?? "",
                line.note ?? ""
            ].joined(separator: "|")
        }
        let summary = [
            "local:\(plan.summary.localPriceCount)",
            "ready:\(plan.summary.readyCandidates)",
            "present:\(plan.summary.alreadyPresentRemote)",
            "remoteConflict:\(plan.summary.conflictSameKeyDifferentPrice)",
            "localDuplicate:\(plan.summary.localDuplicateSameKey)",
            "localConflict:\(plan.summary.localConflictSameKeyDifferentPrice)",
            "blockedNoRemote:\(plan.summary.blockedNoRemoteID)",
            "blockedTotal:\(plan.summary.blockedTotal)",
            "invalid:\(plan.summary.excludedInvalidLocal)",
            "dedupe:\(dedupeFingerprintComponent(plan.remoteDedupeStatus))"
        ]
        return (candidates + summary).joined(separator: "\n")
    }

    private func dedupeFingerprintComponent(_ status: ProductPricePushRemoteDedupeStatus) -> String {
        switch status {
        case .notNeeded:
            return "notNeeded"
        case .complete:
            return "complete"
        case .unsafePartialRemoteDedupe(let reason):
            return "unsafe:\(reason.rawValue)"
        }
    }

    private func liveBarcode(prefix: String, index: Int) -> String {
        String(format: "\(prefix)BAR_%04d", index)
    }

    private func livePriceDate(productIndex: Int, offset: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_778_200_000)
            .addingTimeInterval(Double(productIndex) * 240 + offset)
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

    private func seedLocalCatalogForPriceApply(
        dataset: Task100SyntheticDataset,
        context: ModelContext
    ) throws {
        let supplier = Supplier(name: "TASK100_PRICE_SUPPLIER")
        let category = ProductCategory(name: "TASK100_PRICE_CATEGORY")
        context.insert(supplier)
        context.insert(category)

        for row in dataset.products {
            context.insert(
                Product(
                    barcode: row.barcode,
                    remoteID: row.id,
                    remoteUpdatedAt: SupabaseRemoteDateParser.parse(row.updatedAt),
                    itemNumber: row.itemNumber,
                    productName: row.productName,
                    secondProductName: row.secondProductName,
                    purchasePrice: row.purchasePrice,
                    retailPrice: row.retailPrice,
                    stockQuantity: row.stockQuantity,
                    supplier: supplier,
                    category: category
                )
            )
        }
        try context.save()
    }

    private func assertCurrentPreviousPrices(
        context: ModelContext,
        dataset: Task100SyntheticDataset,
        productIndex: Int,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let expected = dataset.expectedPrices(forProductIndex: productIndex)
        let barcode = Task100SyntheticDataset.barcode(productIndex)
        let descriptor = FetchDescriptor<Product>(
            predicate: #Predicate { $0.barcode == barcode }
        )
        let product = try XCTUnwrap(context.fetch(descriptor).first, file: file, line: line)

        try assertPricePair(
            product: product,
            type: .purchase,
            previous: expected.purchasePrevious,
            current: expected.purchaseCurrent,
            file: file,
            line: line
        )
        try assertPricePair(
            product: product,
            type: .retail,
            previous: expected.retailPrevious,
            current: expected.retailCurrent,
            file: file,
            line: line
        )
    }

    private func assertPricePair(
        product: Product,
        type: PriceType,
        previous: Double,
        current: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let rows = product.priceHistory
            .filter { $0.type == type }
            .sorted {
                if $0.effectiveAt != $1.effectiveAt {
                    return $0.effectiveAt > $1.effectiveAt
                }
                return $0.createdAt > $1.createdAt
            }

        XCTAssertEqual(rows.count, 2, file: file, line: line)
        XCTAssertLessThanOrEqual(abs((rows.first?.price ?? -1) - current), 0.005, file: file, line: line)
        XCTAssertLessThanOrEqual(abs((rows.dropFirst().first?.price ?? -1) - previous), 0.005, file: file, line: line)
    }

    private func parsePriceHistoryRows(_ rows: [[String]]) throws -> [Task100ParsedPriceHistoryEntry] {
        guard let header = rows.first else { return [] }
        let normalizedHeader = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let barcodeIndex = normalizedHeader.firstIndex(of: "productBarcode"),
              let timestampIndex = normalizedHeader.firstIndex(of: "timestamp"),
              let typeIndex = normalizedHeader.firstIndex(of: "type"),
              let priceIndex = normalizedHeader.firstIndex(of: "newPrice") else {
            return []
        }
        let sourceIndex = normalizedHeader.firstIndex(of: "source")

        return rows.dropFirst().compactMap { row in
            let barcode = row[safe: barcodeIndex]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !barcode.isEmpty else { return nil }
            guard let typeRaw = row[safe: typeIndex]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let type = PriceType(rawValue: typeRaw),
                  let priceRaw = row[safe: priceIndex],
                  let price = ProductImportCore.parseDouble(from: priceRaw),
                  let timestampRaw = row[safe: timestampIndex],
                  let effectiveAt = Self.fullDatabaseFormatter.date(from: timestampRaw) else {
                return nil
            }
            return Task100ParsedPriceHistoryEntry(
                barcode: barcode,
                type: type,
                price: price,
                effectiveAt: effectiveAt,
                source: sourceIndex.flatMap { row[safe: $0] } ?? "TASK100_SYNTHETIC"
            )
        }
    }

    private func saveIfNeeded(_ context: ModelContext, after count: Int) throws {
        guard count > 0, count.isMultiple(of: 250) else { return }
        try context.save()
    }

    private func fileSizeMB(_ url: URL) throws -> Double {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let bytes = (attributes[.size] as? NSNumber)?.doubleValue ?? 0
        return bytes / 1_000_000.0
    }

    private func seconds(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000.0
    }

    private func task108UUID(base: UInt64, index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012llX", base + UInt64(index)))!
    }

    private func task108RealExcelURL() throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        let configuredExcelPath = environment["TASK108_EXCEL_PATH"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let excelPath = configuredExcelPath,
              !excelPath.isEmpty else {
            throw XCTSkip("Set TASK108_EXCEL_PATH to run the TASK-108 real Excel harness.")
        }
        guard FileManager.default.fileExists(atPath: excelPath) else {
            throw XCTSkip("TASK108_EXCEL_PATH does not point to an existing file.")
        }
        return URL(fileURLWithPath: excelPath)
    }

    private func task108LogicalPriceCount(_ prices: [ProductPrice]) -> Int {
        Set(prices.compactMap { price -> String? in
            guard let barcode = price.product?.barcode else { return nil }
            return [
                barcode,
                price.type.rawValue,
                Self.fullDatabaseFormatter.string(from: price.effectiveAt)
            ].joined(separator: "|")
        }).count
    }

    private func expectedPagedFetchCalls(rowCount: Int, pageSize: Int) -> Int {
        rowCount / pageSize + 1
    }

    private func recordMetric(
        scenarioID: String,
        datasetClass: String,
        deviceTarget: String,
        rowCounts: String,
        fileSizeMB: Double?,
        firstFeedbackSeconds: Double,
        totalDurationSeconds: Double,
        resultState: String,
        failureMode: String,
        notes: String
    ) {
        let pairs: [(String, String)] = [
            ("scenario_id", scenarioID),
            ("dataset_class", datasetClass),
            ("device_target", deviceTarget),
            ("row_counts", rowCounts),
            ("file_size_mb", fileSizeMB.map { String(format: "%.3f", $0) } ?? "n/a"),
            ("time_to_first_feedback_s", String(format: "%.3f", firstFeedbackSeconds)),
            ("total_duration_s", String(format: "%.3f", totalDurationSeconds)),
            ("result_state", resultState),
            ("failure_mode", failureMode),
            ("notes_redacted", notes)
        ]
        print("TASK100_METRIC|\(pairs.map { "\($0.0)=\($0.1)" }.joined(separator: "|"))")
        writeMetricJSONLine(Dictionary(uniqueKeysWithValues: pairs))
    }

    private func writeMetricJSONLine(_ metric: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: metric.sorted { $0.key < $1.key }.reduce(into: [String: String]()) { $0[$1.key] = $1.value }),
              var line = String(data: data, encoding: .utf8) else {
            return
        }
        line.append("\n")

        guard let lineData = line.data(using: .utf8) else { return }

        if FileManager.default.fileExists(atPath: Self.metricCaptureURL.path),
           let handle = try? FileHandle(forWritingTo: Self.metricCaptureURL) {
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: lineData)
            } catch {
                return
            }
        } else {
            try? lineData.write(to: Self.metricCaptureURL, options: .atomic)
        }
    }

    private static let fullDatabaseFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private struct Task108ArrayProductPriceFetcher: SupabaseProductPricePreviewFetching, SupabaseProductPriceDeletedProductFetching {
    let rows: [RemoteInventoryProductPriceRow]

    func fetchProductPricesPreviewPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        guard from < rows.count, to >= from else { return [] }
        let lowerBound = max(0, from)
        let upperBound = min(rows.count - 1, to)
        guard lowerBound <= upperBound else { return [] }
        return Array(rows[lowerBound...upperBound])
    }

    func fetchProductPriceCount() async throws -> Int? {
        rows.count
    }

    func fetchDeletedProductIDs(pageSize: Int) async throws -> Set<UUID> {
        []
    }
}

private struct Task100DatasetSpec: Sendable {
    let datasetClass: String
    let productCount: Int
    let supplierCount: Int
    let categoryCount: Int
    let priceRowsPerProduct: Int
    let pageSize: Int

    var priceHistoryCount: Int {
        productCount * priceRowsPerProduct
    }

    static let small = Task100DatasetSpec(
        datasetClass: "D100-S",
        productCount: 1_000,
        supplierCount: 80,
        categoryCount: 50,
        priceRowsPerProduct: 4,
        pageSize: 500
    )

    static let medium = Task100DatasetSpec(
        datasetClass: "D100-M",
        productCount: 6_000,
        supplierCount: 240,
        categoryCount: 160,
        priceRowsPerProduct: 4,
        pageSize: 750
    )

    static let large = Task100DatasetSpec(
        datasetClass: "D100-L",
        productCount: 12_000,
        supplierCount: 480,
        categoryCount: 320,
        priceRowsPerProduct: 4,
        pageSize: 1_000
    )
}

private struct Task100SyntheticDataset {
    let spec: Task100DatasetSpec
    let ownerID: UUID
    let suppliers: [RemoteInventorySupplierRow]
    let categories: [RemoteInventoryCategoryRow]
    let products: [RemoteInventoryProductRow]
    let productPrices: [RemoteInventoryProductPriceRow]
    let productExportRows: [Task089SyntheticBenchmarkHarness.ProductExportRow]
    let fullDatabaseExportInput: Task089SyntheticBenchmarkHarness.FullDatabaseExportInput

    var rowCountsDescription: String {
        "products=\(spec.productCount);suppliers=\(spec.supplierCount);categories=\(spec.categoryCount);product_prices=\(spec.priceHistoryCount)"
    }

    init(spec: Task100DatasetSpec) {
        self.spec = spec
        let localOwnerID = UUID(uuidString: "00000000-0000-0000-0000-000000100100")!
        ownerID = localOwnerID
        let timestamp = "2026-05-10T20:00:00Z"

        let supplierRows = (0..<spec.supplierCount).map { index in
            RemoteInventorySupplierRow(
                id: UUID(),
                ownerUserID: localOwnerID,
                name: Self.supplierName(index),
                updatedAt: timestamp,
                deletedAt: nil
            )
        }
        let categoryRows = (0..<spec.categoryCount).map { index in
            RemoteInventoryCategoryRow(
                id: UUID(),
                ownerUserID: localOwnerID,
                name: Self.categoryName(index),
                updatedAt: timestamp,
                deletedAt: nil
            )
        }

        var productRows: [RemoteInventoryProductRow] = []
        var priceRows: [RemoteInventoryProductPriceRow] = []
        var exportRows: [Task089SyntheticBenchmarkHarness.ProductExportRow] = []
        var fullPriceRows: [Task089SyntheticBenchmarkHarness.PriceHistoryExportRow] = []
        let baseDate = Date(timeIntervalSince1970: 1_778_000_000)

        for index in 0..<spec.productCount {
            let supplier = supplierRows[index % supplierRows.count]
            let category = categoryRows[index % categoryRows.count]
            let productID = UUID()
            let expected = Self.expectedPrices(forProductIndex: index)
            let barcode = Self.barcode(index)

            productRows.append(
                RemoteInventoryProductRow(
                    id: productID,
                    ownerUserID: localOwnerID,
                    barcode: barcode,
                    itemNumber: Self.itemNumber(index),
                    productName: Self.productName(index),
                    secondProductName: Self.secondProductName(index),
                    purchasePrice: expected.purchaseCurrent,
                    retailPrice: expected.retailCurrent,
                    supplierID: supplier.id,
                    categoryID: category.id,
                    stockQuantity: Double(index % 150),
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
                    purchasePrice: expected.purchaseCurrent,
                    retailPrice: expected.retailCurrent,
                    oldPurchasePrice: expected.purchasePrevious,
                    oldRetailPrice: expected.retailPrevious,
                    stockQuantity: Double(index % 150),
                    supplierName: supplier.name,
                    categoryName: category.name
                )
            )

            let points: [(PriceType, Double, TimeInterval)] = [
                (.purchase, expected.purchasePrevious, 0),
                (.purchase, expected.purchaseCurrent, 60),
                (.retail, expected.retailPrevious, 120),
                (.retail, expected.retailCurrent, 180)
            ]

            for (type, price, offset) in points {
                let effectiveDate = baseDate.addingTimeInterval(Double(index) * 240 + offset)
                let effectiveAt = Self.iso8601(effectiveDate)
                priceRows.append(
                    RemoteInventoryProductPriceRow(
                        id: UUID(),
                        ownerUserID: localOwnerID,
                        productID: productID,
                        type: type.rawValue,
                        price: price,
                        effectiveAt: effectiveAt,
                        source: "TASK100_SYNTHETIC",
                        note: nil,
                        createdAt: effectiveAt
                    )
                )
                fullPriceRows.append(
                    Task089SyntheticBenchmarkHarness.PriceHistoryExportRow(
                        productBarcode: barcode,
                        timestamp: effectiveDate,
                        type: type.rawValue,
                        newPrice: price,
                        source: "TASK100_SYNTHETIC"
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

    func expectedPrices(forProductIndex index: Int) -> Task100ExpectedPrices {
        Self.expectedPrices(forProductIndex: index)
    }

    static func expectedPrices(forProductIndex index: Int) -> Task100ExpectedPrices {
        let purchaseCurrent = Double(1_000 + (index % 900)) / 10.0
        let purchasePrevious = purchaseCurrent - 0.25
        let retailCurrent = purchaseCurrent * 1.42
        let retailPrevious = retailCurrent - 0.35
        return Task100ExpectedPrices(
            purchasePrevious: purchasePrevious,
            purchaseCurrent: purchaseCurrent,
            retailPrevious: retailPrevious,
            retailCurrent: retailCurrent
        )
    }

    static func barcode(_ index: Int) -> String {
        String(format: "TASK100_BAR_%06d", index)
    }

    private static func itemNumber(_ index: Int) -> String {
        String(format: "TASK100_ITEM_%06d", index)
    }

    private static func productName(_ index: Int) -> String {
        String(format: "TASK100_PRODUCT_%06d", index)
    }

    private static func secondProductName(_ index: Int) -> String {
        String(format: "TASK100_SECOND_%06d", index)
    }

    private static func supplierName(_ index: Int) -> String {
        String(format: "TASK100_SUPPLIER_%04d", index)
    }

    private static func categoryName(_ index: Int) -> String {
        String(format: "TASK100_CATEGORY_%04d", index)
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

private struct Task100ExpectedPrices {
    let purchasePrevious: Double
    let purchaseCurrent: Double
    let retailPrevious: Double
    let retailCurrent: Double
}

private struct Task100ParsedPriceHistoryEntry {
    let barcode: String
    let type: PriceType
    let price: Double
    let effectiveAt: Date
    let source: String
}

private actor Task100InventoryFetcherFake: SupabaseInventoryFetching {
    private let dataset: Task100SyntheticDataset
    private var productRanges: [String] = []
    private var supplierRanges: [String] = []
    private var categoryRanges: [String] = []
    private var priceRanges: [String] = []

    init(dataset: Task100SyntheticDataset) {
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

    func rangeSummary() -> Task100RangeSummary {
        Task100RangeSummary(
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

private actor Task100InventoryRowsFetcher: SupabaseInventoryFetching {
    private let products: [RemoteInventoryProductRow]
    private let suppliers: [RemoteInventorySupplierRow]
    private let categories: [RemoteInventoryCategoryRow]
    private let productPrices: [RemoteInventoryProductPriceRow]
    private var productRanges: [String] = []
    private var supplierRanges: [String] = []
    private var categoryRanges: [String] = []
    private var priceRanges: [String] = []

    init(
        products: [RemoteInventoryProductRow],
        suppliers: [RemoteInventorySupplierRow],
        categories: [RemoteInventoryCategoryRow],
        productPrices: [RemoteInventoryProductPriceRow]
    ) {
        self.products = products
        self.suppliers = suppliers
        self.categories = categories
        self.productPrices = productPrices
    }

    func fetchProductsPage(from: Int, to: Int) async throws -> [RemoteInventoryProductRow] {
        productRanges.append("\(from)...\(to)")
        return page(products, from: from, to: to)
    }

    func fetchSuppliersPage(from: Int, to: Int) async throws -> [RemoteInventorySupplierRow] {
        supplierRanges.append("\(from)...\(to)")
        return page(suppliers, from: from, to: to)
    }

    func fetchCategoriesPage(from: Int, to: Int) async throws -> [RemoteInventoryCategoryRow] {
        categoryRanges.append("\(from)...\(to)")
        return page(categories, from: from, to: to)
    }

    func fetchProductPricesPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        priceRanges.append("\(from)...\(to)")
        return page(productPrices, from: from, to: to)
    }

    func rangeSummary() -> Task100RangeSummary {
        Task100RangeSummary(
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

private struct Task100RangeSummary: Sendable {
    let productPages: Int
    let supplierPages: Int
    let categoryPages: Int
    let pricePages: Int
}

private enum Task100LiveValidationError: Error, CustomStringConvertible {
    case blocked(String)

    var description: String {
        switch self {
        case .blocked(let message):
            message
        }
    }
}

private func joinedRawValues(_ values: [LocalPendingAggregatedPushBlocker]) -> String {
    values.map(\.rawValue).joined(separator: ",")
}

private struct Task100LiveRuntime {
    let config: SupabaseConfig
    let provider: SupabaseClientProvider
    let inventory: SupabaseTransportClient
    let session: Task100LiveSession

    var productPriceRemote: ProductPriceReleaseRemoteSupabaseAdapter {
        ProductPriceReleaseRemoteSupabaseAdapter(remote: inventory)
    }
}

private struct Task100LiveSession {
    let userID: UUID
    let isExpired: Bool
}

private struct Task100LiveCollision {
    let supplierCount: Int
    let categoryCount: Int
    let productCount: Int
    let productPriceCount: Int

    var totalCount: Int {
        supplierCount + categoryCount + productCount + productPriceCount
    }

    var description: String {
        "suppliers=\(supplierCount);categories=\(categoryCount);products=\(productCount);product_prices=\(productPriceCount)"
    }
}

private struct Task100LiveCleanupSummary {
    let supplierCount: Int
    let categoryCount: Int
    let productCount: Int
    let productPriceCount: Int

    var description: String {
        "deleted_suppliers=\(supplierCount);deleted_categories=\(categoryCount);deleted_products=\(productCount);deleted_product_prices=\(productPriceCount)"
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return [] }
        var chunks: [[Element]] = []
        var start = 0
        while start < count {
            let end = Swift.min(start + size, count)
            chunks.append(Array(self[start..<end]))
            start = end
        }
        return chunks
    }
}

@MainActor
private final class Task100DelayedCoordinator: SupabaseManualSyncCoordinating {
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
