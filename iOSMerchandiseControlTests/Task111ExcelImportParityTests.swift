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
            "quantity"
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

    func testDuplicateBarcodeUsesLastRowWithoutSummingQuantity() throws {
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
        XCTAssertEqual(draft.stockQuantity, 3)
    }

    func testParseNumberMatchesAndroidSupplierCases() throws {
        XCTAssertEqual(try XCTUnwrap(ProductImportCore.parseDouble(from: "1.234,56")), 1234.56, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(ProductImportCore.parseDouble(from: "1,234.56")), 1234.56, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(ProductImportCore.parseDouble(from: "1234,56")), 1234.56, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(ProductImportCore.parseDouble(from: "1234")), 1234, accuracy: 0.0001)
    }

    func testGoldenSupplierImportFixtureMatchesAndroidContract() throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("tests/fixtures/supplier-import/android-canonical-sample.json")
        let fixtureData = try Data(contentsOf: fixtureURL)
        let fixture = try XCTUnwrap(
            JSONSerialization.jsonObject(with: fixtureData) as? [String: Any]
        )
        let sampleRows = try XCTUnwrap(fixture["sampleRows"] as? [[String]])
        let sheetRows = try XCTUnwrap(fixture["sheetRows"] as? [[String]])
        let metadataRowsBeforeHeader = try XCTUnwrap(fixture["metadataRowsBeforeHeader"] as? [[String]])
        let expectedHeader = try XCTUnwrap(fixture["normalizedHeader"] as? [String])
        let expectedHeaderSourceByKey = try XCTUnwrap(fixture["headerSource"] as? [String: String])
        let expectedDataRowsCount = try XCTUnwrap(fixture["dataRowsCount"] as? NSNumber).intValue
        let expectedDuplicateWarning = try XCTUnwrap(fixture["duplicateWarning"] as? [String: Any])
        let expectedDuplicateRows = try XCTUnwrap(expectedDuplicateWarning["rows"] as? [NSNumber]).map(\.intValue)
        let expectedErrors = try XCTUnwrap(fixture["errors"] as? [Any])
        let expectedParseNumber = try XCTUnwrap(fixture["parseNumberResults"] as? [String: NSNumber])

        let details = ExcelAnalyzer.analyzeSheetRowsDetailed(sampleRows)
        XCTAssertEqual(details.normalizedHeader, expectedHeader)
        XCTAssertEqual(
            details.headerSource,
            details.normalizedHeader.map { expectedHeaderSourceByKey[$0] ?? "" }
        )
        XCTAssertEqual(details.dataRows.count, expectedDataRowsCount)

        let sheetDetails = ExcelAnalyzer.analyzeSheetRowsDetailed(sheetRows)
        XCTAssertEqual(sheetDetails.normalizedHeader, expectedHeader)
        XCTAssertEqual(sheetDetails.dataRows.count, expectedDataRowsCount)
        XCTAssertGreaterThan(metadataRowsBeforeHeader.count, 0)

        let aliasSamples = try XCTUnwrap(fixture["aliasSamples"] as? [String: [[String]]])
        for (_, rows) in aliasSamples {
            let aliasDetails = ExcelAnalyzer.analyzeSheetRowsDetailed(rows)
            XCTAssertEqual(aliasDetails.normalizedHeader, expectedHeader)
        }

        let headerlessSample = try XCTUnwrap(fixture["headerlessSample"] as? [String: Any])
        let headerlessRows = try XCTUnwrap(headerlessSample["rows"] as? [[String]])
        let headerlessExpectedHeader = try XCTUnwrap(headerlessSample["normalizedHeader"] as? [String])
        let headerlessExpectedSource = try XCTUnwrap(headerlessSample["headerSource"] as? [String])
        let headerlessDetails = ExcelAnalyzer.analyzeSheetRowsDetailed(headerlessRows)
        XCTAssertEqual(headerlessDetails.normalizedHeader, headerlessExpectedHeader)
        XCTAssertEqual(headerlessDetails.headerSource, headerlessExpectedSource)

        for (raw, expected) in expectedParseNumber {
            XCTAssertEqual(
                try XCTUnwrap(ProductImportCore.parseDouble(from: raw)),
                expected.doubleValue,
                accuracy: 0.0001
            )
        }

        let importHeader = [AndroidImportKey.rowNumber] + details.normalizedHeader
        let importRows = details.dataRows.enumerated().map { item in
            [String(item.offset + 2)] + item.element
        }
        let analysis = ProductImportCore.analyzeImport(
            header: importHeader,
            dataRows: importRows,
            existingProductsByBarcode: [
                "9999999900001": ProductDraft(
                    barcode: "9999999900001",
                    itemNumber: "EX-001",
                    productName: "Existing old",
                    secondProductName: nil,
                    purchasePrice: 90,
                    retailPrice: 140,
                    stockQuantity: nil,
                    supplierName: "Fornitore A",
                    categoryName: "Categoria A"
                )
            ]
        )

        XCTAssertEqual(analysis.newProducts.count, try XCTUnwrap(fixture["newProducts"] as? NSNumber).intValue)
        XCTAssertEqual(analysis.updatedProducts.count, try XCTUnwrap(fixture["updatedProducts"] as? NSNumber).intValue)
        XCTAssertEqual(analysis.errors.count, expectedErrors.count)
        XCTAssertEqual(analysis.warnings.first?.barcode, expectedDuplicateWarning["barcode"] as? String)
        XCTAssertEqual(analysis.warnings.first?.rowNumbers, expectedDuplicateRows)
        XCTAssertTrue(analysis.newProducts.contains { $0.barcode == fixture["itemNumberOnlyAcceptedBarcode"] as? String })

        let forbiddenKeys = try XCTUnwrap(fixture["forbiddenPublicKeys"] as? [String])
        for key in forbiddenKeys {
            XCTAssertFalse(details.normalizedHeader.contains(key), "\(key) leaked into normalizedHeader")
        }
        let publicKeysAudit = try XCTUnwrap(fixture["publicKeysAudit"] as? [String: Any])
        let auditForbiddenKeys = try XCTUnwrap(publicKeysAudit["forbidden"] as? [String])
        let previewRows = try XCTUnwrap(fixture["previewRows"] as? [[String: Any]])
        for key in auditForbiddenKeys {
            XCTAssertFalse(previewRows.contains { $0.keys.contains(key) }, "\(key) leaked into previewRows")
        }
    }

    func testNewProductIdentityMatchesAndroidProductNameOrItemNumber() throws {
        let analysis = ProductImportCore.analyzeImport(
            header: ["barcode", "itemNumber", "secondProductName", "purchasePrice", "retailPrice"],
            dataRows: [
                ["TASK111_ITEM_ONLY", "ITEM-ONLY", "", "10", "20"],
                ["TASK111_SECOND_ONLY", "", "Only second name", "10", "20"]
            ],
            existingProductsByBarcode: [:]
        )

        XCTAssertEqual(analysis.newProducts.map(\.barcode), ["TASK111_ITEM_ONLY"])
        XCTAssertEqual(analysis.newProducts.first?.itemNumber, "ITEM-ONLY")
        XCTAssertTrue(analysis.errors.contains {
            $0.rowNumber == 2 &&
            $0.reasonKeys.contains("import.analysis.row_error.product_name_missing")
        })
    }

    func testNewProductMissingRetailPriceBlocksApplyEvenWithItemNumber() throws {
        let analysis = ProductImportCore.analyzeImport(
            header: ["barcode", "itemNumber", "purchasePrice", "quantity"],
            dataRows: [
                ["TASK111_NO_RETAIL", "ITEM-NO-RETAIL", "100", "1"]
            ],
            existingProductsByBarcode: [:]
        )

        XCTAssertTrue(analysis.newProducts.isEmpty)
        let error = try XCTUnwrap(analysis.errors.first)
        XCTAssertEqual(error.rowNumber, 1)
        XCTAssertEqual(error.reasonKeys, ["import.analysis.row_error.retail_required"])
        XCTAssertEqual(error.rowContent[AndroidImportKey.itemNumber], "ITEM-NO-RETAIL")
        XCTAssertNil(error.rowContent["stockQuantity"])
        XCTAssertNil(error.rowContent["prevPurchase"])
        XCTAssertNil(error.rowContent["prevRetail"])
    }

    func testRetailMarkupHelperFillsOnlyEmptyRetailPriceByDefault() throws {
        var drafts = [
            ProductDraft(
                barcode: "TASK111_BULK_EMPTY",
                productName: "Bulk empty",
                purchasePrice: 100,
                retailPrice: nil
            ),
            ProductDraft(
                barcode: "TASK111_BULK_FILLED",
                productName: "Bulk filled",
                purchasePrice: 100,
                retailPrice: 180
            ),
            ProductDraft(
                barcode: "TASK111_BULK_NO_PURCHASE",
                productName: "Bulk no purchase",
                purchasePrice: nil,
                retailPrice: nil
            )
        ]

        let changed = ProductImportCore.applyRetailMarkup(
            to: &drafts,
            markupPercent: 30,
            roundingStep: 50,
            onlyEmptyRetailPrice: true
        )

        XCTAssertEqual(changed, 1)
        XCTAssertEqual(drafts[0].retailPrice, 150)
        XCTAssertEqual(drafts[1].retailPrice, 180)
        XCTAssertNil(drafts[2].retailPrice)
    }

    func testLegacyImportAliasesNormalizeToAndroidCanonicalKeys() throws {
        let details = ExcelAnalyzer.analyzeSheetRowsDetailed([
            [
                "Codice a barre",
                "Nome",
                "Prezzo acquisto",
                "Prezzo vendita",
                "stockQuantity",
                "prevPurchase",
                "prevRetail"
            ],
            [
                "1234567890123",
                "Legacy alias",
                "1.234,56",
                "2,345.67",
                "4",
                "900",
                "1500"
            ]
        ])

        XCTAssertEqual(details.normalizedHeader, [
            "barcode",
            "productName",
            "purchasePrice",
            "retailPrice",
            "quantity",
            "oldPurchasePrice",
            "oldRetailPrice"
        ])
        XCTAssertEqual(details.headerSource, Array(repeating: "alias", count: details.normalizedHeader.count))
        XCTAssertFalse(details.normalizedHeader.contains("stockQuantity"))
        XCTAssertFalse(details.normalizedHeader.contains("prevPurchase"))
        XCTAssertFalse(details.normalizedHeader.contains("prevRetail"))

        let analysis = ProductImportCore.analyzeImport(
            header: details.normalizedHeader,
            dataRows: details.dataRows,
            existingProductsByBarcode: [:]
        )

        XCTAssertTrue(analysis.errors.isEmpty)
        let draft = try XCTUnwrap(analysis.newProducts.first)
        XCTAssertEqual(draft.stockQuantity, 4)
        XCTAssertEqual(draft.oldPurchasePrice, 900)
        XCTAssertEqual(draft.oldRetailPrice, 1500)
    }

    func testMappedRowsExposeOnlyAndroidCanonicalKeys() throws {
        let analysis = ProductImportCore.analyzeImport(
            header: [
                "barcode",
                "productName",
                "purchasePrice",
                "retailPrice",
                "articleCode",
                "stockQuantity",
                "prevPurchase",
                "unknownSupplierKey"
            ],
            dataRows: [
                ["", "Canonical only", "10", "20", "ART-LEAK", "5", "7", "ignored"]
            ],
            existingProductsByBarcode: [:]
        )

        let error = try XCTUnwrap(analysis.errors.first)
        XCTAssertFalse(error.rowContent.keys.contains("articleCode"))
        XCTAssertFalse(error.rowContent.keys.contains("unknownSupplierKey"))
        XCTAssertFalse(error.rowContent.keys.contains("stockQuantity"))
        XCTAssertFalse(error.rowContent.keys.contains("prevPurchase"))
        XCTAssertEqual(error.rowContent[AndroidImportKey.quantity], "5")
        XCTAssertEqual(error.rowContent[AndroidImportKey.oldPurchasePrice], "7")
    }

    func testHeaderlessSupplierRowsPromotePatternColumnsWithHeaderSource() throws {
        let details = ExcelAnalyzer.analyzeSheetRowsDetailed([
            ["1234567890123", "No header A", "2.50", "3", "7.50"],
            ["9876543210987", "No header B", "4.00", "2", "8.00"]
        ])

        XCTAssertEqual(details.normalizedHeader, [
            "barcode",
            "productName",
            "purchasePrice",
            "quantity",
            "totalPrice"
        ])
        XCTAssertEqual(details.headerSource, Array(repeating: "pattern", count: details.normalizedHeader.count))
        XCTAssertEqual(details.dataRows.count, 2)
    }

    func testValidationRejectsDirtyRowsWithoutBlockingValidRows() throws {
        let header = [
            "barcode",
            "productName",
            "secondProductName",
            "purchasePrice",
            "retailPrice",
            "quantity",
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
            header: ["barcode", "purchasePrice"],
            dataRows: [["TASK111_EXISTING", "5"]],
            existingProductsByBarcode: [existing.barcode: existing]
        )

        XCTAssertEqual(analysis.updatedProducts.count, 1)
        let update = try XCTUnwrap(analysis.updatedProducts.first)
        XCTAssertTrue(analysis.errors.isEmpty)
        XCTAssertEqual(update.new.productName, "Existing")
        XCTAssertEqual(update.new.itemNumber, "OLD")
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
