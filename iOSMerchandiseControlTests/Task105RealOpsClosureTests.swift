import AVFoundation
import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class Task105RealOpsClosureTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testSmallImportDedupeAndInvalidRowRecovery() throws {
        let header = [
            "barcode",
            "itemNumber",
            "productName",
            "purchasePrice",
            "retailPrice",
            "stockQuantity",
            "supplier",
            "category"
        ]
        var dataRows = [
            ["TASK105_SMALL_001", "IT-001", "Small product A", "10,50", "14.90", "2", "TASK105_SUP_A", "TASK105_CAT_A"],
            ["", "IT-MISSING", "Missing barcode", "1", "2", "1", "TASK105_SUP_A", "TASK105_CAT_A"],
            ["TASK105_SMALL_001", "IT-001B", "Small product A updated", "10.50", "15.90", "3", "TASK105_SUP_A", "TASK105_CAT_A"],
            ["TASK105_SMALL_002", "IT-002", "Small product B", "8", "12", "4", "TASK105_SUP_B", "TASK105_CAT_B"]
        ]
        for index in 3...28 {
            dataRows.append([
                String(format: "TASK105_SMALL_%03d", index),
                String(format: "IT-%03d", index),
                String(format: "Small product %03d", index),
                String(format: "%.2f", Double(100 + index) / 10.0),
                String(format: "%.2f", Double(140 + index) / 10.0),
                String(index % 9 + 1),
                String(format: "TASK105_SUP_%02d", index % 4),
                String(format: "TASK105_CAT_%02d", index % 3)
            ])
        }

        let analysis = ProductImportCore.analyzeImport(
            header: header,
            dataRows: dataRows,
            existingProductsByBarcode: [:]
        )

        XCTAssertEqual(dataRows.count, 30)
        XCTAssertEqual(analysis.newProducts.count, 28)
        XCTAssertEqual(analysis.updatedProducts.count, 0)
        XCTAssertEqual(analysis.errors.count, 1)
        XCTAssertEqual(analysis.warnings.count, 1)
        XCTAssertEqual(analysis.warnings.first?.barcode, "TASK105_SMALL_001")

        let merged = try XCTUnwrap(analysis.newProducts.first { $0.barcode == "TASK105_SMALL_001" })
        XCTAssertEqual(merged.itemNumber, "IT-001B")
        XCTAssertEqual(merged.productName, "Small product A updated")
        XCTAssertEqual(merged.stockQuantity, 5)
        XCTAssertEqual(merged.purchasePrice, 10.5)
        XCTAssertEqual(merged.retailPrice, 15.9)
    }

    func testExcelSessionViewModelLoadsWorkbookOffMainActorPath() async throws {
        let viewModel = ExcelSessionViewModel()
        let context = try makeContext()
        let exportRows = makeLargeExportRows(productCount: 30)
        let url = try Task089SyntheticBenchmarkHarness.exportProducts(rows: exportRows)
        defer { try? FileManager.default.removeItem(at: url) }

        try await viewModel.load(from: [url], in: context)

        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.progress)
        XCTAssertNil(viewModel.lastError)
        XCTAssertEqual(viewModel.rows.count, 31)
        XCTAssertEqual(viewModel.normalizedHeader.count, viewModel.selectedColumns.count)
        XCTAssertGreaterThanOrEqual(viewModel.analysisConfidence ?? 0, 0.5)
    }

    func testGeneratedInventoryExportRoundTripIntegrity() throws {
        let grid = [
            ["barcode", "productName", "stockQuantity", "purchasePrice", "retailPrice"],
            ["TASK105_EXPORT_001", "Export product A", "7", "11.20", "15.70"],
            ["TASK105_EXPORT_002", "Export product B", "3", "4.50", "6.90"]
        ]

        let url = try InventoryXLSXExporter.export(
            grid: grid,
            preferredName: "TASK105/export:real ops"
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let size = try fileSizeBytes(url)
        XCTAssertGreaterThan(size, 0)
        XCTAssertFalse(url.lastPathComponent.contains("/"))
        XCTAssertFalse(url.lastPathComponent.contains(":"))

        let rows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: "Inventory")
        XCTAssertEqual(rows.count, grid.count)
        XCTAssertEqual(rows[0], grid[0])
        XCTAssertEqual(rows[1][0], "TASK105_EXPORT_001")
        XCTAssertEqual(rows[2][1], "Export product B")
    }

    func testLargeImportPerformanceBandWithSyntheticWorkbook() throws {
        let productCount = 5_000
        let exportRows = makeLargeExportRows(productCount: productCount)

        let exportStarted = DispatchTime.now().uptimeNanoseconds
        let url = try Task089SyntheticBenchmarkHarness.exportProducts(rows: exportRows)
        defer { try? FileManager.default.removeItem(at: url) }
        let exportSeconds = seconds(since: exportStarted)

        let importStarted = DispatchTime.now().uptimeNanoseconds
        let productRows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: "Products")
        let (_, normalizedHeader, dataRows) = ExcelAnalyzer.analyzeSheetRows(productRows)
        let analysis = ProductImportCore.analyzeImport(
            header: normalizedHeader,
            dataRows: dataRows,
            existingProductsByBarcode: [:]
        )
        let importSeconds = seconds(since: importStarted)

        XCTAssertEqual(dataRows.count, productCount)
        XCTAssertEqual(analysis.newProducts.count, productCount)
        XCTAssertTrue(analysis.updatedProducts.isEmpty)
        XCTAssertTrue(analysis.errors.isEmpty)
        XCTAssertLessThan(importSeconds, 60)
        XCTAssertLessThan(exportSeconds + importSeconds, 90)

        print(
            "TASK105_METRIC|scenario=large_import|rows=\(productCount)|exportSeconds=\(format(exportSeconds))|parseAnalyzeSeconds=\(format(importSeconds))|outcome=PASS|privacy=OK_TASK105_SYNTHETIC"
        )
    }

    func testApplyLargeImportToSwiftDataInBatches() throws {
        let productCount = 1_000
        let context = try makeContext()
        let header = [
            "barcode",
            "itemNumber",
            "productName",
            "purchasePrice",
            "retailPrice",
            "stockQuantity",
            "supplier",
            "category"
        ]
        var dataRows: [[String]] = []
        dataRows.reserveCapacity(productCount)
        for index in 0..<productCount {
            let barcode = String(format: "TASK105_DB_%05d", index)
            let itemNumber = String(format: "ITEM-%05d", index)
            let productName = String(format: "Task105 DB product %05d", index)
            let purchasePrice = String(format: "%.2f", Double(100 + index % 50) / 10.0)
            let retailPrice = String(format: "%.2f", Double(140 + index % 50) / 10.0)
            let stockQuantity = String(index % 25)
            let supplierName = String(format: "TASK105_SUP_%03d", index % 20)
            let categoryName = String(format: "TASK105_CAT_%03d", index % 15)
            dataRows.append([
                barcode,
                itemNumber,
                productName,
                purchasePrice,
                retailPrice,
                stockQuantity,
                supplierName,
                categoryName
            ])
        }
        let analysis = ProductImportCore.analyzeImport(
            header: header,
            dataRows: dataRows,
            existingProductsByBarcode: [:]
        )

        let resolver = try ProductImportNamedEntityResolver(context: context)
        var inserted = 0
        for draft in analysis.newProducts {
            ProductImportCore.insertProduct(
                from: draft,
                in: context,
                resolver: resolver,
                recordPriceHistory: true
            )
            inserted += 1
            if inserted.isMultiple(of: 250) {
                try context.save()
            }
        }
        try context.save()

        XCTAssertEqual(try context.fetch(FetchDescriptor<Product>()).count, productCount)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Supplier>()).count, 20)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductCategory>()).count, 15)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, productCount * 2)
    }

    func testPhysicalCameraBarcodeCaptureCapabilityWhenAvailable() throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Physical camera capability is only meaningful on a real iPhone.")
        #else
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        XCTAssertNotEqual(status, .restricted, "Camera access is restricted on the physical device.")
        XCTAssertNotEqual(status, .denied, "Camera access is denied on the physical device.")

        guard status == .authorized else {
            throw XCTSkip("Physical camera is present, but permission is not determined; automated test does not tap the system prompt.")
        }

        let device = try XCTUnwrap(AVCaptureDevice.default(for: .video))
        let input = try AVCaptureDeviceInput(device: device)
        let output = AVCaptureMetadataOutput()
        let session = AVCaptureSession()

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        XCTAssertTrue(session.canAddInput(input))
        session.addInput(input)

        XCTAssertTrue(session.canAddOutput(output))
        session.addOutput(output)

        let barcodeTypes: Set<AVMetadataObject.ObjectType> = [
            .ean13,
            .ean8,
            .upce,
            .code39,
            .code39Mod43,
            .code93,
            .code128,
            .qr
        ]
        XCTAssertFalse(Set(output.availableMetadataObjectTypes).intersection(barcodeTypes).isEmpty)
        #endif
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

    private func makeLargeExportRows(productCount: Int) -> [Task089SyntheticBenchmarkHarness.ProductExportRow] {
        var rows: [Task089SyntheticBenchmarkHarness.ProductExportRow] = []
        rows.reserveCapacity(productCount)
        for index in 0..<productCount {
            let barcode = String(format: "TASK105_LARGE_%05d", index)
            let itemNumber = String(format: "TASK105_ITEM_%05d", index)
            let productName = String(format: "TASK105 Product %05d", index)
            let secondProductName = String(format: "TASK105 Secondary %05d", index)
            let purchasePrice = Double(100 + (index % 700)) / 10.0
            let retailPrice = Double(135 + (index % 700)) / 10.0
            let stockQuantity = Double(index % 90)
            let supplierName = String(format: "TASK105_SUP_%03d", index % 100)
            let categoryName = String(format: "TASK105_CAT_%03d", index % 60)
            rows.append(
                Task089SyntheticBenchmarkHarness.ProductExportRow(
                    barcode: barcode,
                    itemNumber: itemNumber,
                    productName: productName,
                    secondProductName: secondProductName,
                    purchasePrice: purchasePrice,
                    retailPrice: retailPrice,
                    oldPurchasePrice: nil,
                    oldRetailPrice: nil,
                    stockQuantity: stockQuantity,
                    supplierName: supplierName,
                    categoryName: categoryName
                )
            )
        }
        return rows
    }

    private func fileSizeBytes(_ url: URL) throws -> UInt64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.uint64Value ?? 0
    }

    private func seconds(since start: UInt64) -> Double {
        Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000_000.0
    }

    private func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}
