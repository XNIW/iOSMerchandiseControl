import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class Task111ExcelImportParityTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testLocaleNumbersDiscountAndScientificBarcodeAreCanonicalized() throws {
        let header = [
            "barcode",
            "productName",
            "purchasePrice",
            "discount",
            "retailPrice",
            "stockQuantity"
        ]
        let dataRows = [
            ["8.71101E+12", "TASK111 Locale", "EUR 1.234,50", "0.15", "$ 2,345.60", "1 234"]
        ]

        let analysis = ProductImportCore.analyzeImport(
            header: header,
            dataRows: dataRows,
            existingProductsByBarcode: [:]
        )

        XCTAssertTrue(analysis.errors.isEmpty)
        let draft = try XCTUnwrap(analysis.newProducts.first)
        XCTAssertEqual(draft.barcode, "8711010000000")
        XCTAssertEqual(try XCTUnwrap(draft.purchasePrice), 1049.325, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(draft.retailPrice), 2345.6, accuracy: 0.0001)
        XCTAssertEqual(draft.stockQuantity, 1234)
        XCTAssertEqual(analysis.totalInputRows, 1)
    }

    func testDuplicateBarcodeUsesLastRowAndAggregatesRealQuantity() throws {
        let header = [
            "barcode",
            "productName",
            "purchasePrice",
            "discountedPrice",
            "retailPrice",
            "quantity",
            "realQuantity"
        ]
        let dataRows = [
            ["TASK111_DUP_001", "First", "10", "", "15", "2", ""],
            ["TASK111_DUP_001", "Last", "11", "8.50", "16", "4", "3"]
        ]

        let analysis = ProductImportCore.analyzeImport(
            header: header,
            dataRows: dataRows,
            existingProductsByBarcode: [:]
        )

        XCTAssertTrue(analysis.errors.isEmpty)
        XCTAssertEqual(analysis.warnings.count, 1)
        XCTAssertEqual(analysis.warnings.first?.totalOccurrences, 2)

        let draft = try XCTUnwrap(analysis.newProducts.first)
        XCTAssertEqual(draft.productName, "Last")
        XCTAssertEqual(draft.purchasePrice, 8.5)
        XCTAssertEqual(draft.retailPrice, 16)
        XCTAssertEqual(draft.stockQuantity, 5)
    }

    func testValidationRejectsDirtyRowsWithoutBlockingValidRows() throws {
        let header = [
            "barcode",
            "productName",
            "secondProductName",
            "purchasePrice",
            "retailPrice",
            "stockQuantity",
            "discount"
        ]
        let dataRows = [
            ["", "Missing barcode", "", "1", "2", "1", "0"],
            ["TASK111_BAD_NAME", "", "", "1", "2", "1", "0"],
            ["TASK111_BAD_PURCHASE", "Bad purchase", "", "-1", "2", "1", "0"],
            ["TASK111_BAD_RETAIL", "Bad retail", "", "1", "0", "1", "0"],
            ["TASK111_BAD_QTY", "Bad quantity", "", "1", "2", "-1", "0"],
            ["TASK111_BAD_DISCOUNT", "Bad discount", "", "1", "2", "1", "150"],
            ["TASK111_OK", "Valid", "", "1", "2", "3", "10"]
        ]

        let analysis = ProductImportCore.analyzeImport(
            header: header,
            dataRows: dataRows,
            existingProductsByBarcode: [:]
        )

        XCTAssertEqual(analysis.errors.count, 6)
        XCTAssertEqual(analysis.newProducts.map(\.barcode), ["TASK111_OK"])
        XCTAssertEqual(analysis.newProducts.first?.purchasePrice, 0.9)
        XCTAssertTrue(analysis.errors.contains { $0.reasonKeys == ["import.analysis.row_error.barcode_missing"] })
        XCTAssertTrue(analysis.errors.contains { $0.reasonKeys == ["import.analysis.row_error.purchase_negative"] })
        XCTAssertTrue(analysis.errors.contains { $0.reasonKeys == ["import.analysis.row_error.retail_required"] })
        XCTAssertFalse(analysis.errors.dropFirst().allSatisfy { $0.reasonKeys == ["import.analysis.row_error.barcode_missing"] })
    }

    func testExistingProductPreviewMergesSparseUpdatesWithoutSideEffects() throws {
        let context = try makeContext()
        let supplier = Supplier(name: "TASK111 Supplier")
        let category = ProductCategory(name: "TASK111 Category")
        let product = Product(
            barcode: "TASK111_EXISTING",
            itemNumber: "OLD",
            productName: "Existing",
            secondProductName: "Existing second",
            purchasePrice: 4,
            retailPrice: 6,
            stockQuantity: 10,
            supplier: supplier,
            category: category
        )
        context.insert(supplier)
        context.insert(category)
        context.insert(product)
        try context.save()

        let existing = ProductDraft(
            barcode: product.barcode,
            itemNumber: product.itemNumber,
            productName: product.productName,
            secondProductName: product.secondProductName,
            purchasePrice: product.purchasePrice,
            retailPrice: product.retailPrice,
            stockQuantity: product.stockQuantity,
            supplierName: product.supplier?.name,
            categoryName: product.category?.name
        )
        let analysis = ProductImportCore.analyzeImport(
            header: ["barcode", "productName", "purchasePrice"],
            dataRows: [["TASK111_EXISTING", "Existing updated", "5"]],
            existingProductsByBarcode: [existing.barcode: existing]
        )

        XCTAssertEqual(analysis.updatedProducts.count, 1)
        let update = try XCTUnwrap(analysis.updatedProducts.first)
        XCTAssertEqual(update.new.productName, "Existing updated")
        XCTAssertEqual(update.new.retailPrice, 6)
        XCTAssertEqual(update.new.stockQuantity, 10)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Product>()).first?.productName, "Existing")
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductPrice>()).count, 0)
    }

    func testSupplierAndCategoryResolverIsCaseAndWhitespaceInsensitive() throws {
        let context = try makeContext()
        let supplier = Supplier(name: "TASK111 Supplier")
        let category = ProductCategory(name: "TASK111 Category")
        context.insert(supplier)
        context.insert(category)
        try context.save()

        let resolver = try ProductImportNamedEntityResolver(context: context)
        let resolvedSupplier = resolver.resolveSupplier(named: " task111 supplier ")
        let resolvedCategory = resolver.resolveCategory(named: "TASK111 CATEGORY")

        XCTAssertTrue(resolvedSupplier === supplier)
        XCTAssertTrue(resolvedCategory === category)
        XCTAssertEqual(resolver.suppliersCreatedCount, 0)
        XCTAssertEqual(resolver.categoriesCreatedCount, 0)
    }

    func testPreGenerateRelationInputStateRecognizesExistingAndPendingCreate() throws {
        let supplier = Supplier(name: "Prova Fornitore")
        let category = ProductCategory(name: "Prova Categoria")

        XCTAssertEqual(
            ExcelSessionViewModel.resolvePendingSupplierState(input: "", suppliers: [supplier]),
            .empty
        )
        XCTAssertEqual(
            ExcelSessionViewModel.resolvePendingSupplierState(input: " prova fornitore ", suppliers: [supplier]),
            .existing(name: "Prova Fornitore")
        )
        XCTAssertEqual(
            ExcelSessionViewModel.resolvePendingCategoryState(input: "PROVA CATEGORIA", categories: [category]),
            .existing(name: "Prova Categoria")
        )

        let newSupplier = ExcelSessionViewModel.resolvePendingSupplierState(
            input: " prova fornitore nuovo ",
            suppliers: [supplier]
        )
        let newCategory = ExcelSessionViewModel.resolvePendingCategoryState(
            input: " prova categoria nuova ",
            categories: [category]
        )

        XCTAssertEqual(newSupplier, .pendingCreate(name: "prova fornitore nuovo"))
        XCTAssertEqual(newCategory, .pendingCreate(name: "prova categoria nuova"))
        XCTAssertTrue(newSupplier.isValid)
        XCTAssertTrue(newCategory.isValid)
        XCTAssertTrue(newSupplier.isPendingCreate)
        XCTAssertTrue(newCategory.isPendingCreate)
    }

    func testPreGeneratePendingCreatePersistsOnlyWhenGenerating() throws {
        let context = try makeContext()
        let viewModel = makeMinimalPreGenerateSession()
        viewModel.supplierName = " prova fornitore "
        viewModel.categoryName = " prova categoria "

        XCTAssertEqual(
            ExcelSessionViewModel.resolvePendingSupplierState(input: viewModel.supplierName, suppliers: []),
            .pendingCreate(name: "prova fornitore")
        )
        XCTAssertEqual(
            ExcelSessionViewModel.resolvePendingCategoryState(input: viewModel.categoryName, categories: []),
            .pendingCreate(name: "prova categoria")
        )
        XCTAssertTrue(viewModel.preGenerateValidationSnapshot.missingEssentialCanonicalKeys.isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Supplier>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductCategory>()).count, 0)

        let entry = try viewModel.generateHistoryEntry(in: context)

        XCTAssertEqual(entry.supplier, "prova fornitore")
        XCTAssertEqual(entry.category, "prova categoria")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Supplier>()).map(\.name), ["prova fornitore"])
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductCategory>()).map(\.name), ["prova categoria"])
    }

    func testPreGenerateGenerationReusesEquivalentSupplierAndCategory() throws {
        let context = try makeContext()
        let supplier = Supplier(name: "Prova Fornitore")
        let category = ProductCategory(name: "Prova Categoria")
        context.insert(supplier)
        context.insert(category)
        try context.save()

        let viewModel = makeMinimalPreGenerateSession()
        viewModel.supplierName = " prova fornitore "
        viewModel.categoryName = "PROVA CATEGORIA"

        let entry = try viewModel.generateHistoryEntry(in: context)

        XCTAssertEqual(entry.supplier, "Prova Fornitore")
        XCTAssertEqual(entry.category, "Prova Categoria")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Supplier>()).count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ProductCategory>()).count, 1)
    }

    func testImportAnalysisSummaryUsesCaseInsensitiveRelationKeys() {
        let analysis = ProductImportAnalysisResult(
            newProducts: [
                ProductDraft(
                    barcode: "TASK111_SUMMARY",
                    productName: "Summary",
                    retailPrice: 1,
                    supplierName: " task111 supplier ",
                    categoryName: "task111 category"
                )
            ],
            updatedProducts: [],
            errors: [],
            warnings: [],
            totalInputRows: 1
        )

        let session = ImportAnalysisSession(
            analysis: analysis,
            nonProductSummary: NonProductDeltaSummary(
                suppliersToAdd: 1,
                categoriesToAdd: 1,
                priceHistoryToInsert: 0,
                priceHistoryAlreadyPresent: 0,
                priceHistoryUnresolved: 0
            ),
            existingSupplierNames: ["TASK111 Supplier"],
            existingCategoryNames: ["TASK111 Category"]
        )

        XCTAssertEqual(session.nonProductSummary?.suppliersToAdd, 0)
        XCTAssertEqual(session.nonProductSummary?.categoriesToAdd, 0)
    }

    func testPreGenerateDefaultsKeepUnrecognizedColumnsOffButVisibleAndManuallyRecoverable() async throws {
        let context = try makeContext()
        let normalizedHeader = [
            "barcode",
            "productName",
            "purchasePrice",
            "quantity",
            "discount",
            "realQuantity",
            "oldPurchasePrice",
            "oldRetailPrice",
            "internalnote"
        ]
        let viewModel = ExcelSessionViewModel()
        viewModel.originalHeader = [
            "Barcode",
            "Product name",
            "Purchase Price",
            "Quantity",
            "Discount",
            "Counted quantity",
            "Old purchase price",
            "Old retail price",
            "Internal note"
        ]
        viewModel.normalizedHeader = normalizedHeader
        viewModel.initialNormalizedHeader = normalizedHeader
        viewModel.rows = [
            normalizedHeader,
            ["TASK111_DEFAULTS", "Defaults", "10", "2", "5", "1", "9", "14", "Do not import by default"]
        ]
        viewModel.selectedColumns = ExcelSessionViewModel.defaultColumnSelections(for: normalizedHeader)

        let barcodeIndex = try XCTUnwrap(viewModel.normalizedHeader.firstIndex(of: "barcode"))
        let productNameIndex = try XCTUnwrap(viewModel.normalizedHeader.firstIndex(of: "productName"))
        let purchasePriceIndex = try XCTUnwrap(viewModel.normalizedHeader.firstIndex(of: "purchasePrice"))
        let quantityIndex = try XCTUnwrap(viewModel.normalizedHeader.firstIndex(of: "quantity"))
        let discountIndex = try XCTUnwrap(viewModel.normalizedHeader.firstIndex(of: "discount"))
        let realQuantityIndex = try XCTUnwrap(viewModel.normalizedHeader.firstIndex(of: "realQuantity"))
        let oldPurchasePriceIndex = try XCTUnwrap(viewModel.normalizedHeader.firstIndex(of: "oldPurchasePrice"))
        let oldRetailPriceIndex = try XCTUnwrap(viewModel.normalizedHeader.firstIndex(of: "oldRetailPrice"))
        let unknownIndex = try XCTUnwrap(viewModel.normalizedHeader.firstIndex(of: "internalnote"))

        XCTAssertTrue(viewModel.selectedColumns[barcodeIndex])
        XCTAssertTrue(viewModel.selectedColumns[productNameIndex])
        XCTAssertTrue(viewModel.selectedColumns[purchasePriceIndex])
        XCTAssertTrue(viewModel.selectedColumns[quantityIndex])
        XCTAssertTrue(viewModel.selectedColumns[discountIndex])
        XCTAssertTrue(viewModel.selectedColumns[realQuantityIndex])
        XCTAssertTrue(viewModel.selectedColumns[oldPurchasePriceIndex])
        XCTAssertTrue(viewModel.selectedColumns[oldRetailPriceIndex])
        XCTAssertEqual(viewModel.roleKeyForColumn(discountIndex), "discount")
        XCTAssertEqual(viewModel.roleKeyForColumn(realQuantityIndex), "realQuantity")
        XCTAssertEqual(viewModel.roleKeyForColumn(oldPurchasePriceIndex), "oldPurchasePrice")
        XCTAssertEqual(viewModel.roleKeyForColumn(oldRetailPriceIndex), "oldRetailPrice")
        XCTAssertFalse(viewModel.selectedColumns[unknownIndex])
        XCTAssertNil(viewModel.roleKeyForColumn(unknownIndex))
        XCTAssertTrue(viewModel.preGeneratePreviewColumnIndices.contains(unknownIndex))

        viewModel.updateColumnSelection(index: unknownIndex, isSelected: true)
        XCTAssertTrue(viewModel.selectedColumns[unknownIndex])

        viewModel.setColumnRole(at: unknownIndex, to: "retailPrice")
        XCTAssertTrue(viewModel.selectedColumns[unknownIndex])

        viewModel.clearColumnRole(at: unknownIndex)
        XCTAssertFalse(viewModel.selectedColumns[unknownIndex])
        XCTAssertTrue(viewModel.preGeneratePreviewColumnIndices.contains(unknownIndex))

        viewModel.supplierName = "TASK111 Supplier"
        viewModel.categoryName = "TASK111 Category"

        let entry = try viewModel.generateHistoryEntry(in: context)
        let generatedHeader = entry.data.first ?? []
        XCTAssertTrue(generatedHeader.contains("barcode"))
        XCTAssertTrue(generatedHeader.contains("productName"))
        XCTAssertTrue(generatedHeader.contains("purchasePrice"))
        XCTAssertTrue(generatedHeader.contains("discount"))
        XCTAssertFalse(generatedHeader.contains("internalnote"))
        XCTAssertFalse(generatedHeader.contains("Internal note"))
    }

    func testProductPriceHistoryRecordsPreviousAndCurrentImportPricesIdempotently() throws {
        let context = try makeContext()
        let resolver = try ProductImportNamedEntityResolver(context: context)
        let draft = ProductDraft(
            barcode: "TASK111_HISTORY",
            productName: "History",
            purchasePrice: 10,
            retailPrice: 15,
            stockQuantity: 1,
            oldPurchasePrice: 8,
            oldRetailPrice: 12
        )

        let product = ProductImportCore.insertProduct(
            from: draft,
            in: context,
            resolver: resolver,
            recordPriceHistory: true
        )
        _ = ProductImportCore.createPriceHistoryForImport(
            product: product,
            oldPurchase: nil,
            newPurchase: draft.purchasePrice,
            oldRetail: nil,
            newRetail: draft.retailPrice,
            previousPurchase: draft.oldPurchasePrice,
            previousRetail: draft.oldRetailPrice,
            in: context
        )
        try context.save()

        let histories = try context.fetch(FetchDescriptor<ProductPrice>())
        XCTAssertEqual(histories.count, 4)
        XCTAssertEqual(histories.filter { $0.source == "IMPORT_PREV" }.count, 2)
        XCTAssertEqual(histories.filter { $0.source == "IMPORT_EXCEL" }.count, 2)
    }

    func testHtmlColspanRowspanFixtureImportsWithDuplicatePolicy() throws {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(
            forResource: "html-colspan-rowspan-import",
            withExtension: "html",
            subdirectory: "Fixtures/TASK-111"
        ) ?? URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/TASK-111/html-colspan-rowspan-import.html")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let (_, normalizedHeader, dataRows) = try ExcelAnalyzer.readAndAnalyzeExcel(from: url)
        XCTAssertTrue(normalizedHeader.contains("barcode"))
        XCTAssertGreaterThanOrEqual(dataRows.count, 1)

        let analysis = ProductImportCore.analyzeImport(
            header: normalizedHeader,
            dataRows: dataRows,
            existingProductsByBarcode: [:]
        )

        XCTAssertTrue(analysis.errors.isEmpty)
        let draft = try XCTUnwrap(analysis.newProducts.first)
        XCTAssertEqual(draft.barcode, "TASK111_HTML_001")
        XCTAssertNotNil(draft.stockQuantity)
        XCTAssertEqual(ProductImportCore.normalizedRelationKey(draft.supplierName), "task111 supplier")
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

    private func makeMinimalPreGenerateSession() -> ExcelSessionViewModel {
        let header = ["barcode", "productName", "purchasePrice"]
        let viewModel = ExcelSessionViewModel()
        viewModel.originalHeader = ["Barcode", "Product name", "Purchase price"]
        viewModel.normalizedHeader = header
        viewModel.initialNormalizedHeader = header
        viewModel.rows = [
            header,
            ["TASK111_PENDING_CREATE", "Pending create product", "10"]
        ]
        viewModel.selectedColumns = ExcelSessionViewModel.defaultColumnSelections(for: header)
        return viewModel
    }
}
