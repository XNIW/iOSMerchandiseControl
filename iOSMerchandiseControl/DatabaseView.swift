import SwiftUI
import SwiftData
import Combine
import UniformTypeIdentifiers
import xlsxwriter

nonisolated private struct DatabaseImportProgressSnapshot: Sendable {
    let stage: DatabaseImportProgressStage
    let processedCount: Int
    let totalCount: Int
}

nonisolated private struct ImportApplyPayload: Sendable {
    let newProducts: [ProductDraft]
    let updatedProducts: [ProductUpdateDraft]
    let pendingPriceHistoryEntries: [PendingPriceHistoryImportEntry]
    let alreadyPresentPriceHistoryCount: Int
    let unresolvedPriceHistoryCount: Int
    let pendingSupplierNames: [String]
    let pendingCategoryNames: [String]
    let recordPriceHistory: Bool

    var productsTotalCount: Int {
        newProducts.count + updatedProducts.count
    }
}

nonisolated private struct ImportExistingProductSnapshot: Sendable {
    let barcode: String
    let itemNumber: String?
    let productName: String?
    let secondProductName: String?
    let purchasePrice: Double?
    let retailPrice: Double?
    let stockQuantity: Double?
    let supplierName: String?
    let categoryName: String?

    init(_ product: Product) {
        barcode = product.barcode
        itemNumber = product.itemNumber
        productName = product.productName
        secondProductName = product.secondProductName
        purchasePrice = product.purchasePrice
        retailPrice = product.retailPrice
        stockQuantity = product.stockQuantity
        supplierName = product.supplier?.name
        categoryName = product.category?.name
    }

    var draft: ProductDraft {
        ProductDraft(
            barcode: barcode,
            itemNumber: itemNumber,
            productName: productName,
            secondProductName: secondProductName,
            purchasePrice: purchasePrice,
            retailPrice: retailPrice,
            stockQuantity: stockQuantity,
            supplierName: supplierName,
            categoryName: categoryName
        )
    }
}

nonisolated private struct ImportApplyProductsResult: Sendable {
    let productsInserted: Int
    let productsUpdated: Int
    let suppliersCreated: Int
    let categoriesCreated: Int
}

nonisolated private struct ImportApplyResult: Sendable {
    let productsInserted: Int
    let productsUpdated: Int
    let suppliersCreated: Int
    let categoriesCreated: Int
    let priceHistoryInserted: Int
    let priceHistoryAlreadyPresent: Int
    let priceHistoryUnresolved: Int
    let priceHistoryError: String?

    var priceHistoryProcessedCount: Int {
        priceHistoryInserted + priceHistoryAlreadyPresent + priceHistoryUnresolved
    }
}

nonisolated private enum FullImportResultKind: Sendable {
    case success
    case error
    case cancelled
}

nonisolated private struct FullImportResultMetric: Identifiable, Sendable {
    let id = UUID()
    let label: String
    let value: String
}

nonisolated private struct FullImportResultPayload: Identifiable, Sendable {
    let id = UUID()
    let kind: FullImportResultKind
    let title: String
    let summary: String
    let metrics: [FullImportResultMetric]
    let notes: [String]
}

nonisolated private struct ImportApplyPriceHistoryResult: Sendable {
    let insertedCount: Int
    let alreadyPresentCount: Int
    let unresolvedCount: Int

    var totalCount: Int {
        insertedCount + alreadyPresentCount + unresolvedCount
    }
}

nonisolated private struct PriceHistoryApplyFailure: LocalizedError, Sendable {
    let insertedCount: Int
    let alreadyPresentCount: Int
    let unresolvedCount: Int
    let message: String

    var errorDescription: String? {
        message
    }
}

nonisolated private enum DatabaseImportProgressStage: Sendable {
    case parsingExcel
    case parsingSheet(String)
    case analyzing
    case applyingProducts
    case applyingPriceHistory
}

nonisolated private enum DatabaseImportJobKind: Sendable {
    case analysisImport
    case fullDatabaseImport
}

nonisolated private enum DatabaseImportOperationPhase: Sendable {
    case idle
    case preparing
    case awaitingConfirmation
    case applying
}

nonisolated private struct PendingPriceHistoryImportEntry: Sendable {
    let barcode: String
    let type: PriceType
    let price: Double
    let effectiveAt: Date
    let source: String
}

nonisolated private struct PendingFullImportContext: Sendable {
    let priceHistoryEntries: [PendingPriceHistoryImportEntry]
    let alreadyPresentPriceHistoryCount: Int
    let unresolvedPriceHistoryCount: Int
    let pendingSupplierNames: [String]
    let pendingCategoryNames: [String]
    let suppressAutomaticProductPriceHistory: Bool

    var hasWorkToApply: Bool {
        !priceHistoryEntries.isEmpty || !pendingSupplierNames.isEmpty || !pendingCategoryNames.isEmpty
    }
}

nonisolated private enum DatabaseImportPreparationError: Error, Sendable {
    case invalidWorkbook
    case missingProductsSheet
    case barcodeColumnMissing
}

nonisolated private enum DatabaseImportRowErrorReason: Sendable {
    case barcodeMissing
}

nonisolated private struct DatabaseImportRowErrorPayload: Sendable {
    let rowNumber: Int
    let reason: DatabaseImportRowErrorReason
    let rowContent: [String: String]
}

nonisolated private struct DatabaseImportAnalysisPayload: Sendable {
    let newProducts: [ProductDraft]
    let updatedProducts: [ProductUpdateDraft]
    let errors: [DatabaseImportRowErrorPayload]
    let warnings: [ProductDuplicateWarning]
}

nonisolated private struct PreparedImportAnalysis: Sendable {
    let analysis: DatabaseImportAnalysisPayload
    let pendingFullImportContext: PendingFullImportContext?
    let nonProductSummary: NonProductDeltaSummary?
}

nonisolated private struct PriceHistoryFingerprint: Hashable, Sendable {
    let barcode: String
    let type: PriceType
    let effectiveAtEpochSeconds: Int64
    let priceFixed4: Int64
    let source: String
}

@MainActor
private enum DatabaseImportUILocalizer {
    static func progressText(for snapshot: DatabaseImportProgressSnapshot) -> String {
        let prefix: String
        switch snapshot.stage {
        case .parsingExcel:
            prefix = L("database.progress.parsing_excel")
        case .parsingSheet(let sheetName):
            prefix = L("database.progress.parsing_sheet", sheetName)
        case .analyzing:
            prefix = L("database.progress.analyzing")
        case .applyingProducts:
            prefix = L("database.progress.applying_products")
        case .applyingPriceHistory:
            prefix = L("database.progress.applying_price_history")
        }

        guard snapshot.totalCount > 0 else {
            return prefix
        }

        return "\(prefix) \(snapshot.processedCount) / \(snapshot.totalCount)"
    }

    static func analysisResult(from payload: DatabaseImportAnalysisPayload) -> ProductImportAnalysisResult {
        ProductImportAnalysisResult(
            newProducts: payload.newProducts,
            updatedProducts: payload.updatedProducts,
            errors: payload.errors.map { error in
                ProductImportRowError(
                    rowNumber: error.rowNumber,
                    reason: rowErrorReason(for: error.reason),
                    rowContent: error.rowContent
                )
            },
            warnings: payload.warnings
        )
    }

    static func importErrorMessage(for error: Error) -> String {
        if let importError = error as? DatabaseImportPreparationError {
            switch importError {
            case .invalidWorkbook:
                return L("database.progress.invalid_workbook")
            case .missingProductsSheet:
                return L("database.progress.missing_products_sheet")
            case .barcodeColumnMissing:
                return L("database.error.barcode_column_missing")
            }
        }

        if let localizedError = error as? LocalizedError {
            return localizedError.errorDescription ?? localizedError.localizedDescription
        }

        return L("database.error.import_excel", error.localizedDescription)
    }

    static func fullImportSuccessResult(from result: ImportApplyResult) -> FullImportResultPayload {
        var metrics: [FullImportResultMetric] = [
            FullImportResultMetric(
                label: L("database.full_import.result.products_inserted"),
                value: String(result.productsInserted)
            ),
            FullImportResultMetric(
                label: L("database.full_import.result.products_updated"),
                value: String(result.productsUpdated)
            )
        ]

        if result.priceHistoryInserted > 0 {
            metrics.append(
                FullImportResultMetric(
                    label: L("database.full_import.result.price_history_saved"),
                    value: String(result.priceHistoryInserted)
                )
            )
        }

        if result.suppliersCreated > 0 {
            metrics.append(
                FullImportResultMetric(
                    label: L("database.full_import.result.suppliers_created"),
                    value: String(result.suppliersCreated)
                )
            )
        }

        if result.categoriesCreated > 0 {
            metrics.append(
                FullImportResultMetric(
                    label: L("database.full_import.result.categories_created"),
                    value: String(result.categoriesCreated)
                )
            )
        }

        if result.priceHistoryUnresolved > 0 {
            metrics.append(
                FullImportResultMetric(
                    label: L("database.full_import.result.price_history_unresolved"),
                    value: String(result.priceHistoryUnresolved)
                )
            )
        }

        var notes: [String] = []
        if let priceHistoryError = result.priceHistoryError {
            notes.append(L("database.full_import.result.price_history_error_note", priceHistoryError))
        }

        return FullImportResultPayload(
            kind: .success,
            title: L("database.progress.completed_title"),
            summary: result.priceHistoryError == nil
                ? L("database.full_import.result.success_summary")
                : L("database.full_import.result.partial_summary"),
            metrics: metrics,
            notes: notes
        )
    }

    static func fullImportErrorResult(message: String) -> FullImportResultPayload {
        FullImportResultPayload(
            kind: .error,
            title: L("database.error.import_title"),
            summary: L("database.full_import.result.error_summary"),
            metrics: [],
            notes: [message]
        )
    }

    static func fullImportCancelledResult() -> FullImportResultPayload {
        FullImportResultPayload(
            kind: .cancelled,
            title: L("database.full_import.result.cancelled_title"),
            summary: L("database.full_import.result.cancelled_summary"),
            metrics: [],
            notes: []
        )
    }

    private static func rowErrorReason(for reason: DatabaseImportRowErrorReason) -> String {
        switch reason {
        case .barcodeMissing:
            return L("database.error.barcode_missing")
        }
    }
}

nonisolated private enum DatabaseImportPipeline {
    private static let importSaveBatchSize = 250
    private static let importProgressBatchSize = 25
    private static let fullDatabaseTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let priceHistoryHeaderAliases: [String: [String]] = [
        "productBarcode": ["productbarcode", "barcode", "product_barcode"],
        "timestamp": ["timestamp", "date", "data"],
        "type": ["type", "tipo", "pricetype"],
        "oldPrice": ["oldprice", "old_price", "prevprice", "priceold"],
        "newPrice": ["newprice", "new_price", "price"],
        "source": ["source", "sorgente"]
    ]
    private static let fullDatabasePriceHistorySource = "IMPORT_DB_FULL"

    static func prepareProductsImport(
        from url: URL,
        modelContainer: ModelContainer,
        onProgress: @escaping @Sendable (DatabaseImportProgressSnapshot) async -> Void
    ) async throws -> PreparedImportAnalysis {
        try await Task.detached(priority: .userInitiated) {
            await onProgress(DatabaseImportProgressSnapshot(stage: .parsingExcel, processedCount: 0, totalCount: 0))
            let parsingStartedAt = Date()
            let (_, normalizedHeader, dataRows) = try ExcelAnalyzer.readAndAnalyzeExcel(from: url)
            logTiming(
                phase: "parsing",
                sheet: nil,
                elapsed: Date().timeIntervalSince(parsingStartedAt),
                rows: dataRows.count
            )

            await onProgress(DatabaseImportProgressSnapshot(stage: .analyzing, processedCount: 0, totalCount: 0))
            let analyzeStartedAt = Date()
            let backgroundContext = ModelContext(modelContainer)
            let existingProducts = try fetchExistingProductSnapshots(in: backgroundContext)
            let analysis = try analyzeImport(
                header: normalizedHeader,
                dataRows: dataRows,
                existingProducts: existingProducts
            )
            logTiming(
                phase: "analyze",
                sheet: "Products",
                elapsed: Date().timeIntervalSince(analyzeStartedAt),
                rows: dataRows.count
            )

            return PreparedImportAnalysis(
                analysis: analysis,
                pendingFullImportContext: nil,
                nonProductSummary: nil
            )
        }.value
    }

    static func prepareFullDatabaseImport(
        from url: URL,
        modelContainer: ModelContainer,
        onProgress: @escaping @Sendable (DatabaseImportProgressSnapshot) async -> Void
    ) async throws -> PreparedImportAnalysis {
        try Task.checkCancellation()

        let sheetNames: [String]
        do {
            sheetNames = try ExcelAnalyzer.listSheetNames(at: url)
        } catch {
            throw DatabaseImportPreparationError.invalidWorkbook
        }

        try Task.checkCancellation()

        let sheetNameMap = Dictionary(
            uniqueKeysWithValues: sheetNames.map { (normalizedSheetName($0), $0) }
        )
        let backgroundContext = ModelContext(modelContainer)
        let supplierSheetNames: [String]
        let categorySheetNames: [String]

        if let suppliersSheetName = sheetNameMap[normalizedSheetName("Suppliers")] {
            await onProgress(DatabaseImportProgressSnapshot(stage: .parsingSheet(suppliersSheetName), processedCount: 0, totalCount: 0))
            try Task.checkCancellation()
            let parsingStartedAt = Date()
            supplierSheetNames = readNamedEntitiesSheet(at: url, sheetName: suppliersSheetName)
            logTiming(
                phase: "parsing",
                sheet: suppliersSheetName,
                elapsed: Date().timeIntervalSince(parsingStartedAt),
                rows: supplierSheetNames.count
            )
            try Task.checkCancellation()
        } else {
            supplierSheetNames = []
        }

        if let categoriesSheetName = sheetNameMap[normalizedSheetName("Categories")] {
            await onProgress(DatabaseImportProgressSnapshot(stage: .parsingSheet(categoriesSheetName), processedCount: 0, totalCount: 0))
            try Task.checkCancellation()
            let parsingStartedAt = Date()
            categorySheetNames = readNamedEntitiesSheet(at: url, sheetName: categoriesSheetName)
            logTiming(
                phase: "parsing",
                sheet: categoriesSheetName,
                elapsed: Date().timeIntervalSince(parsingStartedAt),
                rows: categorySheetNames.count
            )
            try Task.checkCancellation()
        } else {
            categorySheetNames = []
        }

        guard let productsSheetName = sheetNameMap[normalizedSheetName("Products")] else {
            throw DatabaseImportPreparationError.missingProductsSheet
        }

        await onProgress(DatabaseImportProgressSnapshot(stage: .parsingSheet(productsSheetName), processedCount: 0, totalCount: 0))
        try Task.checkCancellation()
        let productsParsingStartedAt = Date()
        let productsRows: [[String]]
        do {
            productsRows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: productsSheetName)
        } catch {
            throw DatabaseImportPreparationError.invalidWorkbook
        }

        try Task.checkCancellation()

        let (_, normalizedHeader, dataRows) = ExcelAnalyzer.analyzeSheetRows(productsRows)
        logTiming(
            phase: "parsing",
            sheet: productsSheetName,
            elapsed: Date().timeIntervalSince(productsParsingStartedAt),
            rows: dataRows.count
        )

        await onProgress(DatabaseImportProgressSnapshot(stage: .analyzing, processedCount: 0, totalCount: 0))
        try Task.checkCancellation()
        let analyzeStartedAt = Date()
        let existingProducts = try fetchExistingProductSnapshots(in: backgroundContext)
        let analysis = try analyzeImport(
            header: normalizedHeader,
            dataRows: dataRows,
            existingProducts: existingProducts
        )
        logTiming(
            phase: "analyze",
            sheet: productsSheetName,
            elapsed: Date().timeIntervalSince(analyzeStartedAt),
            rows: dataRows.count
        )

        try Task.checkCancellation()

        let parsedPriceHistoryEntries: [PendingPriceHistoryImportEntry]
        if let priceHistorySheetName = sheetNameMap[normalizedSheetName("PriceHistory")] {
            await onProgress(DatabaseImportProgressSnapshot(stage: .parsingSheet(priceHistorySheetName), processedCount: 0, totalCount: 0))
            try Task.checkCancellation()
            let parsingStartedAt = Date()
            parsedPriceHistoryEntries = parsePendingPriceHistoryEntries(
                at: url,
                sheetNameMap: sheetNameMap
            ) ?? []
            logTiming(
                phase: "parsing",
                sheet: priceHistorySheetName,
                elapsed: Date().timeIntervalSince(parsingStartedAt),
                rows: parsedPriceHistoryEntries.count
            )
            try Task.checkCancellation()
        } else {
            parsedPriceHistoryEntries = []
        }

        let classifiedPriceHistory = try classifyParsedPriceHistoryForFullImport(
            parsedPriceHistoryEntries,
            existingProducts: existingProducts,
            newProducts: analysis.newProducts,
            updatedProducts: analysis.updatedProducts,
            in: backgroundContext
        )
        try Task.checkCancellation()
        let namedEntities = try buildPendingSuppliersCategoriesAndNonProductSummary(
            supplierSheetNames: supplierSheetNames,
            categorySheetNames: categorySheetNames,
            analysis: analysis,
            priceHistoryToInsertCount: classifiedPriceHistory.toInsert.count,
            priceHistoryAlreadyPresentCount: classifiedPriceHistory.alreadyPresentCount,
            priceHistoryUnresolvedCount: classifiedPriceHistory.unresolvedCount,
            in: backgroundContext
        )
        try Task.checkCancellation()
        let hasPriceHistorySheet = sheetNameMap[normalizedSheetName("PriceHistory")] != nil
        let pendingContext: PendingFullImportContext?
        if hasPriceHistorySheet || !namedEntities.pendingSupplierNames.isEmpty || !namedEntities.pendingCategoryNames.isEmpty {
            pendingContext = PendingFullImportContext(
                priceHistoryEntries: classifiedPriceHistory.toInsert,
                alreadyPresentPriceHistoryCount: classifiedPriceHistory.alreadyPresentCount,
                unresolvedPriceHistoryCount: classifiedPriceHistory.unresolvedCount,
                pendingSupplierNames: namedEntities.pendingSupplierNames,
                pendingCategoryNames: namedEntities.pendingCategoryNames,
                suppressAutomaticProductPriceHistory: hasPriceHistorySheet
            )
        } else {
            pendingContext = nil
        }

        return PreparedImportAnalysis(
            analysis: analysis,
            pendingFullImportContext: pendingContext,
            nonProductSummary: namedEntities.summary
        )
    }

    static func applyImportAnalysisInBackground(
        _ payload: ImportApplyPayload,
        modelContainer: ModelContainer,
        onProgress: @escaping @Sendable (DatabaseImportProgressSnapshot) async -> Void
    ) async throws -> ImportApplyResult {
        try await Task.detached(priority: .userInitiated) {
            let context = ModelContext(modelContainer)
            let productsStartedAt = Date()
            let productsResult = try await applyImportAnalysis(
                payload,
                in: context,
                onProgress: onProgress
            )
            logTiming(
                phase: "apply_products",
                sheet: nil,
                elapsed: Date().timeIntervalSince(productsStartedAt),
                rows: productsResult.productsInserted + productsResult.productsUpdated,
                extraFields: [
                    "productsInserted=\(productsResult.productsInserted)",
                    "productsUpdated=\(productsResult.productsUpdated)",
                    "suppliersCreated=\(productsResult.suppliersCreated)",
                    "categoriesCreated=\(productsResult.categoriesCreated)"
                ]
            )

            let priceHistoryStartedAt = Date()
            var priceHistoryResult = ImportApplyPriceHistoryResult(
                insertedCount: 0,
                alreadyPresentCount: payload.alreadyPresentPriceHistoryCount,
                unresolvedCount: payload.unresolvedPriceHistoryCount
            )
            var priceHistoryError: String?

            do {
                priceHistoryResult = try await applyPendingPriceHistoryImport(
                    payload.pendingPriceHistoryEntries,
                    alreadyPresentCount: payload.alreadyPresentPriceHistoryCount,
                    unresolvedCount: payload.unresolvedPriceHistoryCount,
                    in: context,
                    onProgress: onProgress
                )
                logTiming(
                    phase: "apply_price_history",
                    sheet: nil,
                    elapsed: Date().timeIntervalSince(priceHistoryStartedAt),
                    rows: priceHistoryResult.totalCount,
                    extraFields: [
                        "inserted=\(priceHistoryResult.insertedCount)",
                        "alreadyPresent=\(priceHistoryResult.alreadyPresentCount)",
                        "unresolved=\(priceHistoryResult.unresolvedCount)"
                    ]
                )
            } catch let error as PriceHistoryApplyFailure {
                priceHistoryResult = ImportApplyPriceHistoryResult(
                    insertedCount: error.insertedCount,
                    alreadyPresentCount: error.alreadyPresentCount,
                    unresolvedCount: error.unresolvedCount
                )
                priceHistoryError = error.message
                logTiming(
                    phase: "apply_price_history",
                    sheet: nil,
                    elapsed: Date().timeIntervalSince(priceHistoryStartedAt),
                    rows: priceHistoryResult.totalCount,
                    extraFields: [
                        "inserted=\(priceHistoryResult.insertedCount)",
                        "alreadyPresent=\(priceHistoryResult.alreadyPresentCount)",
                        "unresolved=\(priceHistoryResult.unresolvedCount)",
                        "error=\(error.message)"
                    ]
                )
            } catch {
                priceHistoryError = error.localizedDescription
                logTiming(
                    phase: "apply_price_history",
                    sheet: nil,
                    elapsed: Date().timeIntervalSince(priceHistoryStartedAt),
                    rows: priceHistoryResult.totalCount,
                    extraFields: ["error=\(error.localizedDescription)"]
                )
            }

            let result = ImportApplyResult(
                productsInserted: productsResult.productsInserted,
                productsUpdated: productsResult.productsUpdated,
                suppliersCreated: productsResult.suppliersCreated,
                categoriesCreated: productsResult.categoriesCreated,
                priceHistoryInserted: priceHistoryResult.insertedCount,
                priceHistoryAlreadyPresent: priceHistoryResult.alreadyPresentCount,
                priceHistoryUnresolved: priceHistoryResult.unresolvedCount,
                priceHistoryError: priceHistoryError
            )
            logApplyResult(result)
            return result
        }.value
    }

    static func cellValue(in row: [String], at index: Int) -> String {
        guard index >= 0, index < row.count else { return "" }
        return row[index]
    }

    static func parseDouble(from text: String) -> Double? {
        ProductImportCore.parseDouble(from: text)
    }

    private static func analyzeImport(
        header: [String],
        dataRows: [[String]],
        existingProducts: [ImportExistingProductSnapshot]
    ) throws -> DatabaseImportAnalysisPayload {
        guard header.contains("barcode") else {
            throw DatabaseImportPreparationError.barcodeColumnMissing
        }

        let existingProductsByBarcode: [String: ProductDraft] = Dictionary(
            uniqueKeysWithValues: existingProducts.map { ($0.barcode, $0.draft) }
        )
        let analysis = ProductImportCore.analyzeImport(
            header: header,
            dataRows: dataRows,
            existingProductsByBarcode: existingProductsByBarcode
        )

        return DatabaseImportAnalysisPayload(
            newProducts: analysis.newProducts,
            updatedProducts: analysis.updatedProducts,
            errors: analysis.errors.map { error in
                DatabaseImportRowErrorPayload(
                    rowNumber: error.rowNumber,
                    reason: .barcodeMissing,
                    rowContent: error.rowContent
                )
            },
            warnings: analysis.warnings
        )
    }

    private static func fetchExistingProductSnapshots(
        in context: ModelContext
    ) throws -> [ImportExistingProductSnapshot] {
        try context.fetch(FetchDescriptor<Product>()).map(ImportExistingProductSnapshot.init)
    }

    private static func readNamedEntitiesSheet(at url: URL, sheetName: String) -> [String] {
        let rows: [[String]]
        do {
            rows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: sheetName)
        } catch {
            debugPrint("Full import: impossibile leggere il foglio \(sheetName), skip.")
            return []
        }

        guard !rows.isEmpty else {
            debugPrint("Full import: foglio \(sheetName) vuoto, skip.")
            return []
        }

        let header = rows[0].map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        guard let nameIndex = header.firstIndex(of: "name") else {
            debugPrint("Full import: foglio \(sheetName) senza colonna name, skip.")
            return []
        }

        guard rows.count > 1 else {
            debugPrint("Full import: foglio \(sheetName) con soli header, skip.")
            return []
        }

        return normalizedUniqueSortedNames(
            rows.dropFirst().compactMap { row in
                normalizeNamedEntityName(cellValue(in: row, at: nameIndex))
            }
        )
    }

    private static func normalizeNamedEntityName(_ rawName: String?) -> String? {
        normalizedImportNamedEntityName(rawName)
    }

    private static func normalizedUniqueSortedNames<S: Sequence>(_ names: S) -> [String] where S.Element == String {
        Array(Set(names.compactMap(normalizeNamedEntityName))).sorted()
    }

    private static func normalizedFullDatabasePriceHistorySource(_ rawSource: String?) -> String {
        normalizeNamedEntityName(rawSource) ?? fullDatabasePriceHistorySource
    }

    private static func makePriceHistoryFingerprint(
        barcode: String,
        type: PriceType,
        effectiveAt: Date,
        price: Double,
        source: String?
    ) -> PriceHistoryFingerprint {
        PriceHistoryFingerprint(
            barcode: barcode,
            type: type,
            effectiveAtEpochSeconds: Int64(floor(effectiveAt.timeIntervalSince1970)),
            priceFixed4: Int64((price * 10_000).rounded()),
            source: normalizedFullDatabasePriceHistorySource(source)
        )
    }

    private static func referencedSupplierNames(
        from analysis: DatabaseImportAnalysisPayload
    ) -> Set<String> {
        var names = Set(analysis.newProducts.compactMap { normalizeNamedEntityName($0.supplierName) })
        for update in analysis.updatedProducts where update.changedFields.contains(.supplierName) {
            if let name = normalizeNamedEntityName(update.new.supplierName) {
                names.insert(name)
            }
        }
        return names
    }

    private static func referencedCategoryNames(
        from analysis: DatabaseImportAnalysisPayload
    ) -> Set<String> {
        var names = Set(analysis.newProducts.compactMap { normalizeNamedEntityName($0.categoryName) })
        for update in analysis.updatedProducts where update.changedFields.contains(.categoryName) {
            if let name = normalizeNamedEntityName(update.new.categoryName) {
                names.insert(name)
            }
        }
        return names
    }

    private static func buildPendingSuppliersCategoriesAndNonProductSummary(
        supplierSheetNames: [String],
        categorySheetNames: [String],
        analysis: DatabaseImportAnalysisPayload,
        priceHistoryToInsertCount: Int,
        priceHistoryAlreadyPresentCount: Int,
        priceHistoryUnresolvedCount: Int,
        in context: ModelContext
    ) throws -> (
        pendingSupplierNames: [String],
        pendingCategoryNames: [String],
        summary: NonProductDeltaSummary
    ) {
        let existingSupplierNames = Set(
            try context.fetch(FetchDescriptor<Supplier>()).compactMap { normalizeNamedEntityName($0.name) }
        )
        let existingCategoryNames = Set(
            try context.fetch(FetchDescriptor<ProductCategory>()).compactMap { normalizeNamedEntityName($0.name) }
        )

        let pendingSupplierNames = normalizedUniqueSortedNames(supplierSheetNames)
            .filter { !existingSupplierNames.contains($0) }
        let pendingCategoryNames = normalizedUniqueSortedNames(categorySheetNames)
            .filter { !existingCategoryNames.contains($0) }

        let suppliersToAdd = Set(pendingSupplierNames)
            .union(referencedSupplierNames(from: analysis).filter { !existingSupplierNames.contains($0) })
        let categoriesToAdd = Set(pendingCategoryNames)
            .union(referencedCategoryNames(from: analysis).filter { !existingCategoryNames.contains($0) })

        return (
            pendingSupplierNames: pendingSupplierNames,
            pendingCategoryNames: pendingCategoryNames,
            summary: NonProductDeltaSummary(
                suppliersToAdd: suppliersToAdd.count,
                categoriesToAdd: categoriesToAdd.count,
                priceHistoryToInsert: priceHistoryToInsertCount,
                priceHistoryAlreadyPresent: priceHistoryAlreadyPresentCount,
                priceHistoryUnresolved: priceHistoryUnresolvedCount
            )
        )
    }

    private static func logTiming(
        phase: String,
        sheet: String?,
        elapsed: TimeInterval,
        rows: Int,
        extraFields: [String] = []
    ) {
        let formattedElapsed = String(format: "%.2f", elapsed)
        var fields = ["phase=\(phase)", "elapsed=\(formattedElapsed)s", "rows=\(rows)"]
        if let sheet {
            fields.insert("sheet=\(sheet)", at: 1)
        }
        fields.append(contentsOf: extraFields)
        print("[TASK-011] \(fields.joined(separator: " "))")
    }

    private static func logApplyResult(_ result: ImportApplyResult) {
        var fields = [
            "phase=apply_result",
            "productsInserted=\(result.productsInserted)",
            "productsUpdated=\(result.productsUpdated)",
            "suppliersCreated=\(result.suppliersCreated)",
            "categoriesCreated=\(result.categoriesCreated)",
            "priceHistoryInserted=\(result.priceHistoryInserted)",
            "priceHistoryAlreadyPresent=\(result.priceHistoryAlreadyPresent)",
            "priceHistoryUnresolved=\(result.priceHistoryUnresolved)"
        ]
        fields.append("priceHistoryError=\(result.priceHistoryError ?? "nil")")
        print("[TASK-011] \(fields.joined(separator: " "))")
    }

    private static func applyImportAnalysis(
        _ payload: ImportApplyPayload,
        in context: ModelContext,
        onProgress: @escaping @Sendable (DatabaseImportProgressSnapshot) async -> Void
    ) async throws -> ImportApplyProductsResult {
        let existingProducts = try context.fetch(FetchDescriptor<Product>())
        var productsByBarcode = Dictionary(
            uniqueKeysWithValues: existingProducts.map { ($0.barcode, $0) }
        )

        let existingSuppliers = try context.fetch(FetchDescriptor<Supplier>())
        let existingCategories = try context.fetch(FetchDescriptor<ProductCategory>())
        let resolver = try ProductImportNamedEntityResolver(
            context: context,
            existingSuppliers: existingSuppliers,
            existingCategories: existingCategories
        )

        var processedCount = 0
        var insertedCount = 0
        var updatedCount = 0
        let totalCount = payload.productsTotalCount
        await reportImportProgress(
            stage: .applyingProducts,
            processedCount: 0,
            totalCount: totalCount,
            onProgress: onProgress,
            force: true
        )

        resolver.preloadSuppliers(named: payload.pendingSupplierNames)
        resolver.preloadCategories(named: payload.pendingCategoryNames)

        for draft in payload.newProducts {
            autoreleasepool {
                let product = ProductImportCore.insertProduct(
                    from: draft,
                    in: context,
                    resolver: resolver,
                    recordPriceHistory: payload.recordPriceHistory
                )
                productsByBarcode[draft.barcode] = product
            }

            processedCount += 1
            insertedCount += 1
            await reportImportProgress(
                stage: .applyingProducts,
                processedCount: processedCount,
                totalCount: totalCount,
                onProgress: onProgress
            )
            _ = try await saveImportProgressIfNeeded(after: processedCount, in: context)
        }

        for update in payload.updatedProducts {
            guard let product = productsByBarcode[update.barcode] else {
                continue
            }

            autoreleasepool {
                ProductImportCore.applyUpdate(
                    update,
                    to: product,
                    in: context,
                    resolver: resolver,
                    recordPriceHistory: payload.recordPriceHistory
                )
            }

            processedCount += 1
            updatedCount += 1
            await reportImportProgress(
                stage: .applyingProducts,
                processedCount: processedCount,
                totalCount: totalCount,
                onProgress: onProgress
            )
            _ = try await saveImportProgressIfNeeded(after: processedCount, in: context)
        }

        try context.save()
        await reportImportProgress(
            stage: .applyingProducts,
            processedCount: processedCount,
            totalCount: totalCount,
            onProgress: onProgress,
            force: true
        )
        await Task.yield()
        return ImportApplyProductsResult(
            productsInserted: insertedCount,
            productsUpdated: updatedCount,
            suppliersCreated: resolver.suppliersCreatedCount,
            categoriesCreated: resolver.categoriesCreatedCount
        )
    }

    private static func parsePendingPriceHistoryEntries(
        at url: URL,
        sheetNameMap: [String: String]
    ) -> [PendingPriceHistoryImportEntry]? {
        guard let sheetName = sheetNameMap[normalizedSheetName("PriceHistory")] else {
            return nil
        }

        let entries: [PendingPriceHistoryImportEntry]
        do {
            let rows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: sheetName)
            guard !rows.isEmpty else {
                debugPrint("Full import: foglio \(sheetName) vuoto, skip.")
                return nil
            }

            let header = rows[0].map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            guard let barcodeIndex = indexForPriceHistoryColumn("productBarcode", in: header),
                  let timestampIndex = indexForPriceHistoryColumn("timestamp", in: header),
                  let typeIndex = indexForPriceHistoryColumn("type", in: header),
                  let newPriceIndex = indexForPriceHistoryColumn("newPrice", in: header) else {
                debugPrint("Full import: foglio \(sheetName) con header non valido, skip.")
                return nil
            }

            let sourceIndex = indexForPriceHistoryColumn("source", in: header)
            var parsedEntries: [PendingPriceHistoryImportEntry] = []

            if rows.count > 1 {
                for row in rows.dropFirst() {
                    let barcode = cellValue(in: row, at: barcodeIndex)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !barcode.isEmpty else { continue }

                    let typeRaw = cellValue(in: row, at: typeIndex)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()
                    guard let type = parsePriceType(typeRaw) else { continue }

                    let priceRaw = cellValue(in: row, at: newPriceIndex)
                    guard let price = parseDouble(from: priceRaw) else { continue }

                    let timestampRaw = cellValue(in: row, at: timestampIndex)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let effectiveAt = parseFullDatabaseTimestamp(timestampRaw) ?? Date()

                    parsedEntries.append(
                        PendingPriceHistoryImportEntry(
                            barcode: barcode,
                            type: type,
                            price: price,
                            effectiveAt: effectiveAt,
                            source: normalizedFullDatabasePriceHistorySource(
                                sourceIndex.map { cellValue(in: row, at: $0) }
                            )
                        )
                    )
                }
            }

            entries = parsedEntries
        } catch {
            debugPrint("Full import: impossibile leggere il foglio \(sheetName), skip.")
            return nil
        }

        return entries
    }

    private static func classifyParsedPriceHistoryForFullImport(
        _ entries: [PendingPriceHistoryImportEntry],
        existingProducts: [ImportExistingProductSnapshot],
        newProducts: [ProductDraft],
        updatedProducts: [ProductUpdateDraft],
        in context: ModelContext
    ) throws -> (
        toInsert: [PendingPriceHistoryImportEntry],
        alreadyPresentCount: Int,
        unresolvedCount: Int
    ) {
        guard !entries.isEmpty else {
            return (toInsert: [], alreadyPresentCount: 0, unresolvedCount: 0)
        }

        let existingPriceHistory = try context.fetch(FetchDescriptor<ProductPrice>())
        var knownFingerprints = Set(
            existingPriceHistory.compactMap { entry -> PriceHistoryFingerprint? in
                guard let barcode = entry.product?.barcode.trimmingCharacters(in: .whitespacesAndNewlines),
                      !barcode.isEmpty else {
                    return nil
                }

                return makePriceHistoryFingerprint(
                    barcode: barcode,
                    type: entry.type,
                    effectiveAt: entry.effectiveAt,
                    price: entry.price,
                    source: entry.source
                )
            }
        )
        var resolvableBarcodes = Set(existingProducts.map(\.barcode))
        resolvableBarcodes.formUnion(newProducts.map(\.barcode))
        resolvableBarcodes.formUnion(updatedProducts.map(\.barcode))

        var toInsert: [PendingPriceHistoryImportEntry] = []
        var alreadyPresentCount = 0
        var unresolvedCount = 0

        for entry in entries {
            guard resolvableBarcodes.contains(entry.barcode) else {
                unresolvedCount += 1
                continue
            }

            let fingerprint = makePriceHistoryFingerprint(
                barcode: entry.barcode,
                type: entry.type,
                effectiveAt: entry.effectiveAt,
                price: entry.price,
                source: entry.source
            )
            if knownFingerprints.contains(fingerprint) {
                alreadyPresentCount += 1
                continue
            }

            knownFingerprints.insert(fingerprint)
            toInsert.append(entry)
        }

        return (
            toInsert: toInsert,
            alreadyPresentCount: alreadyPresentCount,
            unresolvedCount: unresolvedCount
        )
    }

    private static func applyPendingPriceHistoryImport(
        _ entries: [PendingPriceHistoryImportEntry],
        alreadyPresentCount: Int,
        unresolvedCount: Int,
        in context: ModelContext,
        onProgress: @escaping @Sendable (DatabaseImportProgressSnapshot) async -> Void
    ) async throws -> ImportApplyPriceHistoryResult {
        guard !entries.isEmpty else {
            return ImportApplyPriceHistoryResult(
                insertedCount: 0,
                alreadyPresentCount: alreadyPresentCount,
                unresolvedCount: unresolvedCount
            )
        }

        var persistedCount = 0
        var finalUnresolvedCount = unresolvedCount

        do {
            let existingProducts = try context.fetch(FetchDescriptor<Product>())
            let productsByBarcode = Dictionary(
                uniqueKeysWithValues: existingProducts.map { ($0.barcode, $0) }
            )

            let now = Date()
            var processedCount = 0
            var insertedCount = 0
            let totalCount = entries.count
            await reportImportProgress(
                stage: .applyingPriceHistory,
                processedCount: 0,
                totalCount: totalCount,
                onProgress: onProgress,
                force: true
            )

            for entry in entries {
                processedCount += 1

                guard let product = productsByBarcode[entry.barcode] else {
                    finalUnresolvedCount += 1
                    await reportImportProgress(
                        stage: .applyingPriceHistory,
                        processedCount: processedCount,
                        totalCount: totalCount,
                        onProgress: onProgress
                    )
                    continue
                }

                autoreleasepool {
                    let history = ProductPrice(
                        type: entry.type,
                        price: entry.price,
                        effectiveAt: entry.effectiveAt,
                        source: normalizedFullDatabasePriceHistorySource(entry.source),
                        note: nil,
                        createdAt: now,
                        product: product
                    )
                    context.insert(history)
                }

                insertedCount += 1
                await reportImportProgress(
                    stage: .applyingPriceHistory,
                    processedCount: processedCount,
                    totalCount: totalCount,
                    onProgress: onProgress
                )
                if try await saveImportProgressIfNeeded(after: processedCount, in: context) {
                    persistedCount = insertedCount
                }
            }

            try context.save()
            persistedCount = insertedCount
            await reportImportProgress(
                stage: .applyingPriceHistory,
                processedCount: processedCount,
                totalCount: totalCount,
                onProgress: onProgress,
                force: true
            )
            await Task.yield()
            return ImportApplyPriceHistoryResult(
                insertedCount: persistedCount,
                alreadyPresentCount: alreadyPresentCount,
                unresolvedCount: finalUnresolvedCount
            )
        } catch {
            throw PriceHistoryApplyFailure(
                insertedCount: persistedCount,
                alreadyPresentCount: alreadyPresentCount,
                unresolvedCount: finalUnresolvedCount,
                message: error.localizedDescription
            )
        }
    }

    private static func reportImportProgress(
        stage: DatabaseImportProgressStage,
        processedCount: Int,
        totalCount: Int,
        onProgress: @escaping @Sendable (DatabaseImportProgressSnapshot) async -> Void,
        force: Bool = false
    ) async {
        guard totalCount > 0 else { return }
        guard force ||
                processedCount == totalCount ||
                processedCount.isMultiple(of: importProgressBatchSize) else {
            return
        }

        await onProgress(
            DatabaseImportProgressSnapshot(
                stage: stage,
                processedCount: processedCount,
                totalCount: totalCount
            )
        )
    }

    private static func saveImportProgressIfNeeded(
        after processedCount: Int,
        in context: ModelContext
    ) async throws -> Bool {
        guard processedCount > 0,
              processedCount.isMultiple(of: importSaveBatchSize) else {
            return false
        }

        try context.save()
        await Task.yield()
        return true
    }

    private static func createPriceHistoryForImport(
        product: Product,
        oldPurchase: Double?,
        newPurchase: Double?,
        oldRetail: Double?,
        newRetail: Double?,
        in context: ModelContext
    ) {
        ProductImportCore.createPriceHistoryForImport(
            product: product,
            oldPurchase: oldPurchase,
            newPurchase: newPurchase,
            oldRetail: oldRetail,
            newRetail: newRetail,
            in: context
        )
    }

    private static func normalizedSheetName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func indexForPriceHistoryColumn(
        _ logicalName: String,
        in header: [String]
    ) -> Int? {
        guard let aliases = priceHistoryHeaderAliases[logicalName] else {
            return nil
        }

        return header.firstIndex { aliases.contains($0) }
    }

    private static func parsePriceType(_ value: String) -> PriceType? {
        PriceType(rawValue: value)
    }

    private static func parseFullDatabaseTimestamp(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        return fullDatabaseTimestampFormatter.date(from: value)
    }
}

@MainActor
private final class DatabaseImportProgressState: ObservableObject, @unchecked Sendable {
    @Published var isRunning = false
    @Published var showsOverlay = false
    @Published var stageText = ""
    @Published var processedCount = 0
    @Published var totalCount = 0
    @Published var resultMessage: String?
    @Published var resultIsError = false
    @Published private(set) var jobKind: DatabaseImportJobKind?
    @Published private(set) var phase: DatabaseImportOperationPhase = .idle
    @Published private(set) var isCancellationPending = false

    var progressFraction: Double? {
        guard totalCount > 0 else { return nil }
        return Double(processedCount) / Double(totalCount)
    }

    var isFullDatabaseFlow: Bool {
        jobKind == .fullDatabaseImport
    }

    var canCancelPreparation: Bool {
        jobKind == .fullDatabaseImport
        && phase == .preparing
        && showsOverlay
        && !isCancellationPending
    }

    var resultTitle: String {
        resultIsError ? L("database.error.import_title") : L("database.progress.completed_title")
    }

    func startPreparation(
        jobKind: DatabaseImportJobKind,
        stageText: String? = nil
    ) {
        isRunning = true
        showsOverlay = true
        self.jobKind = jobKind
        phase = .preparing
        isCancellationPending = false
        self.stageText = stageText ?? L("database.progress.preparing")
        processedCount = 0
        totalCount = 0
        resultMessage = nil
        resultIsError = false
    }

    func startApplying(jobKind: DatabaseImportJobKind) {
        startPreparation(jobKind: jobKind)
        phase = .applying
    }

    func apply(_ snapshot: DatabaseImportProgressSnapshot) {
        isRunning = true
        showsOverlay = true
        isCancellationPending = false
        stageText = DatabaseImportUILocalizer.progressText(for: snapshot)
        processedCount = snapshot.processedCount
        totalCount = snapshot.totalCount
    }

    func awaitingConfirmation() {
        isRunning = true
        showsOverlay = false
        phase = .awaitingConfirmation
        isCancellationPending = false
        stageText = ""
        processedCount = 0
        totalCount = 0
    }

    func beginCancellation() {
        showsOverlay = true
        isCancellationPending = true
        stageText = L("database.progress.cancelling")
        processedCount = 0
        totalCount = 0
    }

    func resetRunningState() {
        isRunning = false
        showsOverlay = false
        jobKind = nil
        phase = .idle
        isCancellationPending = false
        stageText = ""
        processedCount = 0
        totalCount = 0
    }

    func finishSuccess(message: String) {
        resetRunningState()
        resultMessage = message
        resultIsError = false
    }

    func finishError(message: String) {
        resetRunningState()
        resultMessage = message
        resultIsError = true
    }

    func clearResult() {
        resultMessage = nil
    }
}

/// Larghezza card coerente per overlay full import (margini laterali, max su iPad).
private func importSurfaceCardWidth(for geometry: GeometryProxy) -> CGFloat {
    let raw = geometry.size.width - 64
    return min(max(raw, 280), 440)
}

struct DatabaseView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("appLanguage") private var appLanguage: String = "system"

    // Tutti i prodotti dal database, ordinati per barcode
    @Query(sort: \Product.barcode, order: .forward)
    private var products: [Product]

    @State private var barcodeFilter: String = ""
    @State private var showAddSheet = false
    @State private var productToEdit: Product?
    @State private var productForHistory: Product?
    
    @State private var showScanner = false
    @State private var pendingBarcodeForNewProduct: String? = nil

    // Export / import
    @State private var exportURL: URL?
    @State private var showingExportSheet = false
    @State private var showingExportOptions = false

    // Import prodotti (CSV semplice + Excel con analisi)
    @State private var showingImportOptions = false
    @State private var showingCSVImportPicker = false
    @State private var showingExcelImportPicker = false
    @State private var showingFullExcelImportPicker = false

    @State private var importError: String?
    
    // Risultato analisi import da Excel
    @State private var importAnalysisSession: ImportAnalysisSession?
    @State private var pendingFullImportContext: PendingFullImportContext?
    @StateObject private var importProgress = DatabaseImportProgressState()
    @State private var fullImportPrepareTask: Task<Void, Never>?
    @State private var fullImportPrepareTaskID: UUID?
    @State private var cancelledFullImportPrepareTaskID: UUID?
    @State private var fullImportResultPayload: FullImportResultPayload?
    @State private var deferredFullImportResultPayload: FullImportResultPayload?

    private struct FullImportResultView: View {
        let payload: FullImportResultPayload
        let onClose: () -> Void

        private var symbolName: String {
            switch payload.kind {
            case .success:
                return "checkmark.circle.fill"
            case .error:
                return "xmark.octagon.fill"
            case .cancelled:
                return "slash.circle.fill"
            }
        }

        private var tint: SwiftUI.Color {
            switch payload.kind {
            case .success:
                return .green
            case .error:
                return .red
            case .cancelled:
                return .orange
            }
        }

        var body: some View {
            VStack(spacing: 20) {
                Image(systemName: symbolName)
                    .font(.system(size: 44))
                    .foregroundStyle(tint)
                    .padding(.top, 8)

                Text(payload.title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                if !payload.summary.isEmpty {
                    Text(payload.summary)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                if !payload.metrics.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(payload.metrics.enumerated()), id: \.element.id) { index, metric in
                            if index > 0 {
                                Divider()
                            }
                            HStack {
                                Text(metric.label)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(metric.value)
                                    .fontWeight(.semibold)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }
                    .font(.body)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 4)
                }

                if !payload.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(payload.notes.enumerated()), id: \.offset) { _, note in
                            Text(note)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }

                Button(action: onClose) {
                    Text(L("common.ok"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    /// Sotto-vista per alleggerire il type-checking di `importProgressOverlay` (Swift 6.2).
    private struct ImportProgressMaterialCard: View {
        @ObservedObject var importProgress: DatabaseImportProgressState
        var cardWidth: CGFloat
        var onCancel: () -> Void

        var body: some View {
            VStack(spacing: 14) {
                Text(importProgress.stageText.isEmpty ? L("database.progress.preparing") : importProgress.stageText)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                progressSection
                    .frame(maxWidth: .infinity)

                if importProgress.canCancelPreparation {
                    cancelSection
                }
            }
            .frame(width: cardWidth)
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
        }

        @ViewBuilder
        private var progressSection: some View {
            if let progressFraction = importProgress.progressFraction {
                VStack(spacing: 6) {
                    ProgressView(value: progressFraction)
                        .progressViewStyle(.linear)
                    Text("\(importProgress.processedCount) / \(importProgress.totalCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            } else {
                ProgressView()
                    .controlSize(.regular)
            }
        }

        private var cancelSection: some View {
            Button(L("common.cancel"), action: onCancel)
                .buttonStyle(.bordered)
                .controlSize(.regular)
        }
    }

    private struct ExportedProductRow {
        let barcode: String
        let itemNumber: String
        let productName: String
        let secondProductName: String
        let purchasePrice: Double?
        let retailPrice: Double?
        let stockQuantity: Double?
        let supplierName: String
        let categoryName: String
    }

    // filtro in memoria sui prodotti, come facevi in Compose
    private var filteredProducts: [Product] {
        let trimmed = barcodeFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return products }

        let lower = trimmed.lowercased()
        return products.filter { product in
            if product.barcode.lowercased().contains(lower) { return true }
            if let item = product.itemNumber?.lowercased(), item.contains(lower) { return true }
            if let name = product.productName?.lowercased(), name.contains(lower) { return true }
            if let second = product.secondProductName?.lowercased(), second.contains(lower) { return true }
            return false
        }
    }

    var body: some View {
        let resolvedLanguageCode = Bundle.resolvedLanguageCode(for: appLanguage)

        ZStack {
            VStack {
                // campo filtro barcode / nome / codice
                HStack(spacing: 8) {
                    TextField(L("database.search_placeholder"), text: $barcodeFilter)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if !barcodeFilter.isEmpty {
                        Button {
                            barcodeFilter = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "camera.viewfinder")
                    }
                }
                .padding(.horizontal)
                .padding(.top)

                // lista prodotti
                List {
                    ForEach(filteredProducts) { (product: Product) in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(product.productName ?? L("product.no_name"))
                                        .font(.headline)

                                    if let second = product.secondProductName,
                                       !second.isEmpty {
                                        Text(second)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(L("database.row.barcode", product.barcode))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if let item = product.itemNumber,
                                       !item.isEmpty {
                                        Text(L("database.row.code", item))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    if let purchase = product.purchasePrice {
                                        Text(L("database.row.purchase", formatMoney(purchase)))
                                            .font(.caption)
                                    }
                                    if let retail = product.retailPrice {
                                        Text(L("database.row.retail", formatMoney(retail)))
                                            .font(.caption)
                                    }
                                    if let qty = product.stockQuantity {
                                        Text(L("database.row.stock", formatQuantity(qty)))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            HStack {
                                if let supplierName = product.supplier?.name,
                                   !supplierName.isEmpty {
                                    Text(L("database.row.supplier", supplierName))
                                }
                                if let categoryName = product.category?.name,
                                   !categoryName.isEmpty {
                                    if product.supplier != nil {
                                        Text("·")
                                    }
                                    Text(L("database.row.category", categoryName))
                                }
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                            HStack {
                                Button {
                                    productToEdit = product
                                } label: {
                                    Label(L("common.edit"), systemImage: "pencil")
                                }

                                Spacer()

                                Button {
                                    productForHistory = product
                                } label: {
                                    Label(L("product.history.title"), systemImage: "clock.arrow.circlepath")
                                }
                                .buttonStyle(.borderless)
                            }
                            .font(.footnote)
                            .padding(.top, 2)
                        }
                        .contentShape(Rectangle()) // tutta la riga tappabile
                        .onTapGesture {
                            productToEdit = product
                        }
                    }
                    .onDelete(perform: deleteProducts)
                }
                .id("database-list-\(resolvedLanguageCode)")
                .listStyle(.plain)
            }
            .disabled(importProgress.isRunning)

            if importProgress.showsOverlay {
                importProgressOverlay
            }

        }
        .navigationTitle(L("database.title"))
        .toolbar {
            // import / export + nuovo prodotto
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        // Mostra dialog per scegliere Excel vs CSV
                        showingImportOptions = true
                    } label: {
                        Image(systemName: "tray.and.arrow.down")
                    }
                    .disabled(importProgress.isRunning)

                    Button {
                        showingExportOptions = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(importProgress.isRunning)

                    Button {
                        pendingBarcodeForNewProduct = nil
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(importProgress.isRunning)
                }
            }
        }
        // Sheet per NUOVO prodotto
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                EditProductView(initialBarcode: pendingBarcodeForNewProduct)
            }
        }
        // Sheet per MODIFICA prodotto esistente
        .sheet(item: $productToEdit) { (product: Product) in
            NavigationStack {
                EditProductView(product: product)
            }
        }
        // Sheet per storico prezzi
        .sheet(item: $productForHistory) { (product: Product) in
            NavigationStack {
                ProductPriceHistoryView(product: product)
            }
        }
        // Sheet per condividere il CSV/XLSX export
        .sheet(isPresented: $showingExportSheet) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            } else {
                Text(L("database.no_file_to_share"))
                    .padding()
            }
        }

        // Sheet per l’analisi di import da Excel
        .sheet(item: $importAnalysisSession, onDismiss: handleImportAnalysisDismissed) { session in
            NavigationStack {
                ImportAnalysisView(
                    session: session,
                    hasWorkToApply: {
                        Self.hasWorkToApply(
                            session: session,
                            pendingFullImportContext: pendingFullImportContext
                        )
                    },
                    onApply: {
                        try await applyConfirmedImportAnalysis()
                    }
                )
            }
        }
        // Sheet per scanner barcode
        .sheet(isPresented: $showScanner) {
            ScannerView(title: L("database.scanner_title")) { code in
                handleDatabaseScan(code)
            }
        }
        .sheet(item: $fullImportResultPayload) { payload in
            FullImportResultView(
                payload: payload,
                onClose: clearPresentedFullImportResult
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
        }

        .confirmationDialog(
            L("database.export.title"),
            isPresented: $showingExportOptions,
            titleVisibility: .visible
        ) {
            Button(L("database.export.products")) {
                exportProducts()
            }
            Button(L("database.export.full")) {
                exportFullDatabase()
            }
            Button(L("common.cancel"), role: .cancel) { }
        }

        // Dialog per scegliere il tipo di import
        .confirmationDialog(
            L("database.import.title"),
            isPresented: $showingImportOptions,
            titleVisibility: .visible
        ) {
            Button(L("database.import.excel_analysis")) {
                showingExcelImportPicker = true
            }
            Button(L("database.import.full")) {
                showingFullExcelImportPicker = true
            }
            Button(L("database.import.csv_simple")) {
                showingCSVImportPicker = true
            }
            Button(L("common.cancel"), role: .cancel) { }
        }

        // Import CSV (flow semplice esistente)
        .fileImporter(
            isPresented: $showingCSVImportPicker,
            allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importProducts(from: url)
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }

        // Import Excel con analisi
        .fileImporter(
            isPresented: $showingExcelImportPicker,
            allowedContentTypes: [.spreadsheet, .html],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importProductsFromExcel(url: url)
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }

        .fileImporter(
            isPresented: $showingFullExcelImportPicker,
            allowedContentTypes: [.spreadsheet],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importFullDatabaseFromExcel(url: url)
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }

        .alert(
            L("database.error.import_title"),
            isPresented: Binding(
                get: { importError != nil },
                set: { newValue in
                    if !newValue { importError = nil }
                }
            )
        ) {
            Button(L("common.ok"), role: .cancel) {
                importError = nil
            }
        } message: {
            Text(importError ?? "")
        }
        .alert(
            importProgress.resultTitle,
            isPresented: Binding(
                get: { importProgress.resultMessage != nil },
                set: { newValue in
                    if !newValue {
                        importProgress.clearResult()
                    }
                }
            )
        ) {
            Button(L("common.ok"), role: .cancel) {
                importProgress.clearResult()
            }
        } message: {
            Text(importProgress.resultMessage ?? "")
        }
    }

    private var importProgressOverlay: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()

                ImportProgressMaterialCard(
                    importProgress: importProgress,
                    cardWidth: importSurfaceCardWidth(for: geo),
                    onCancel: cancelFullImportPreparation
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }



    // MARK: - Azioni base

    private func handleDatabaseScan(_ code: String) {
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        // Aggiorna filtro come feedback visivo
        barcodeFilter = cleaned

        if let existing = products.first(where: { $0.barcode == cleaned }) {
            // Prodotto già presente → apri edit
            productToEdit = existing
        } else {
            // Nessun prodotto → crea nuovo con barcode precompilato
            pendingBarcodeForNewProduct = cleaned
            showAddSheet = true
        }
    }
    
    private func deleteProducts(at offsets: IndexSet) {
        for index in offsets {
            let product = filteredProducts[index]
            context.delete(product)
        }
        do {
            try context.save()
        } catch {
            print("Errore durante l'eliminazione: \(error)")
        }
    }

    // MARK: - Export prodotti (XLSX di default)

    private func exportProducts() {
        do {
            // Ora esportiamo direttamente in XLSX
            let url = try makeProductsXLSX()
            exportURL = url
            showingExportSheet = true
        } catch {
            importError = L("database.error.export", error.localizedDescription)
        }
    }

    private func exportFullDatabase() {
        do {
            let url = try makeFullDatabaseXLSX()
            exportURL = url
            showingExportSheet = true
        } catch {
            importError = L("database.error.export", error.localizedDescription)
        }
    }
    
    // MARK: - Export XLSX (writer reale tramite xlsxwriter.swift)

    /// Genera un file XLSX con la stessa struttura del CSV attuale
    private func makeProductsXLSX() throws -> URL {
        let exportRows = try exportedProductRows()

        // Stesse colonne del CSV esistente
        let headers = [
            "barcode",
            "itemNumber",
            "productName",
            "secondProductName",
            "purchasePrice",
            "retailPrice",
            "stockQuantity",
            "supplierName",
            "categoryName"
        ]

        // Path nel temporaryDirectory (così ShareLink funziona tranquillo)
        let tmpDir = FileManager.default.temporaryDirectory
        let filename = "products_\(Int(Date().timeIntervalSince1970)).xlsx"
        let url = tmpDir.appendingPathComponent(filename)

        // Crea il workbook puntando al path completo
        // Nota: usiamo il nome completo del file, esattamente come negli esempi di xlsxwriter.swift
        // e libxlsxwriter: Workbook(name: filePath) :contentReference[oaicite:5]{index=5}
        let workbook = xlsxwriter.Workbook(name: url.path)

        // Un solo worksheet per ora
        let worksheet = workbook.addWorksheet(name: "Products")

        // Riga 0: header
        for (columnIndex, header) in headers.enumerated() {
            worksheet.write(.string(header), [0, columnIndex])
        }

        // Righe dati: dalla riga 1 in avanti
        for (rowIndex, product) in exportRows.enumerated() {
            let row = rowIndex + 1   // 0 = header, 1..n = dati

            // 0: barcode (obbligatorio)
            worksheet.write(.string(product.barcode), [row, 0])

            // 1: itemNumber
            worksheet.write(.string(product.itemNumber), [row, 1])

            // 2: nome prodotto principale
            worksheet.write(.string(product.productName), [row, 2])

            // 3: secondo nome
            worksheet.write(.string(product.secondProductName), [row, 3])

            // 4: purchasePrice (numero, non stringa)
            if let purchase = product.purchasePrice {
                worksheet.write(.number(purchase), [row, 4])
            }

            // 5: retailPrice (numero)
            if let retail = product.retailPrice {
                worksheet.write(.number(retail), [row, 5])
            }

            // 6: stockQuantity (numero)
            if let stock = product.stockQuantity {
                worksheet.write(.number(stock), [row, 6])
            }

            // 7: supplierName
            worksheet.write(.string(product.supplierName), [row, 7])

            // 8: categoryName
            worksheet.write(.string(product.categoryName), [row, 8])
        }

        workbook.close()
        try validateExportedProductsSheet(at: url, expectedRows: exportRows)
        return url
    }

    private func makeFullDatabaseXLSX() throws -> URL {
        struct ExportedPriceHistoryRow {
            let productBarcode: String
            let timestamp: Date
            let type: String
            let newPrice: Double
            let source: String
        }

        let productRows = try exportedProductRows()

        let supplierDescriptor = FetchDescriptor<Supplier>()
        let categoryDescriptor = FetchDescriptor<ProductCategory>()
        let priceHistoryDescriptor = FetchDescriptor<ProductPrice>()

        let suppliers = try context.fetch(supplierDescriptor)
            .sorted { $0.name < $1.name }
        let categories = try context.fetch(categoryDescriptor)
            .sorted { $0.name < $1.name }
        let priceHistoryRows = try context.fetch(priceHistoryDescriptor)
            .compactMap { entry -> ExportedPriceHistoryRow? in
                guard let barcode = entry.product?.barcode else {
                    return nil
                }

                return ExportedPriceHistoryRow(
                    productBarcode: barcode,
                    timestamp: entry.effectiveAt,
                    type: entry.type.rawValue,
                    newPrice: entry.price,
                    source: entry.source ?? ""
                )
            }
            .sorted {
                if $0.productBarcode != $1.productBarcode {
                    return $0.productBarcode < $1.productBarcode
                }
                if $0.type != $1.type {
                    return $0.type < $1.type
                }
                return $0.timestamp < $1.timestamp
            }

        let tmpDir = FileManager.default.temporaryDirectory
        let filename = "database_full_\(Int(Date().timeIntervalSince1970)).xlsx"
        let url = tmpDir.appendingPathComponent(filename)
        let workbook = xlsxwriter.Workbook(name: url.path)

        let productsSheet = workbook.addWorksheet(name: "Products")
        let productsHeaders = [
            "barcode",
            "itemNumber",
            "productName",
            "secondProductName",
            "purchasePrice",
            "retailPrice",
            "stockQuantity",
            "supplierName",
            "categoryName"
        ]

        for (columnIndex, header) in productsHeaders.enumerated() {
            productsSheet.write(.string(header), [0, columnIndex])
        }

        for (rowIndex, product) in productRows.enumerated() {
            let row = rowIndex + 1
            productsSheet.write(.string(product.barcode), [row, 0])
            productsSheet.write(.string(product.itemNumber), [row, 1])
            productsSheet.write(.string(product.productName), [row, 2])
            productsSheet.write(.string(product.secondProductName), [row, 3])

            if let purchase = product.purchasePrice {
                productsSheet.write(.number(purchase), [row, 4])
            }
            if let retail = product.retailPrice {
                productsSheet.write(.number(retail), [row, 5])
            }
            if let stock = product.stockQuantity {
                productsSheet.write(.number(stock), [row, 6])
            }

            productsSheet.write(.string(product.supplierName), [row, 7])
            productsSheet.write(.string(product.categoryName), [row, 8])
        }

        let suppliersSheet = workbook.addWorksheet(name: "Suppliers")
        suppliersSheet.write(.string("name"), [0, 0])
        for (rowIndex, supplier) in suppliers.enumerated() {
            suppliersSheet.write(.string(supplier.name), [rowIndex + 1, 0])
        }

        let categoriesSheet = workbook.addWorksheet(name: "Categories")
        categoriesSheet.write(.string("name"), [0, 0])
        for (rowIndex, category) in categories.enumerated() {
            categoriesSheet.write(.string(category.name), [rowIndex + 1, 0])
        }

        let priceHistorySheet = workbook.addWorksheet(name: "PriceHistory")
        let priceHistoryHeaders = [
            "productBarcode",
            "timestamp",
            "type",
            "oldPrice",
            "newPrice",
            "source"
        ]

        for (columnIndex, header) in priceHistoryHeaders.enumerated() {
            priceHistorySheet.write(.string(header), [0, columnIndex])
        }

        let timestampFormatter = DateFormatter()
        timestampFormatter.locale = Locale(identifier: "en_US_POSIX")
        timestampFormatter.timeZone = TimeZone(identifier: "UTC")
        timestampFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var previousPriceByGroup: [String: Double] = [:]
        for (rowIndex, rowData) in priceHistoryRows.enumerated() {
            let row = rowIndex + 1
            let groupKey = "\(rowData.productBarcode)|\(rowData.type)"
            let oldPrice = previousPriceByGroup[groupKey]

            priceHistorySheet.write(.string(rowData.productBarcode), [row, 0])
            priceHistorySheet.write(
                .string(timestampFormatter.string(from: rowData.timestamp)),
                [row, 1]
            )
            priceHistorySheet.write(.string(rowData.type), [row, 2])
            if let oldPrice {
                priceHistorySheet.write(.number(oldPrice), [row, 3])
            }
            priceHistorySheet.write(.number(rowData.newPrice), [row, 4])
            priceHistorySheet.write(.string(rowData.source), [row, 5])

            previousPriceByGroup[groupKey] = rowData.newPrice
        }

        workbook.close()
        try validateExportedProductsSheet(at: url, expectedRows: productRows)
        return url
    }

    private func exportedProductRows() throws -> [ExportedProductRow] {
        let descriptor = FetchDescriptor<Product>(
            sortBy: [SortDescriptor(\Product.barcode, order: .forward)]
        )

        return try context.fetch(descriptor).map { product in
            ExportedProductRow(
                barcode: product.barcode,
                itemNumber: product.itemNumber ?? "",
                productName: product.productName ?? "",
                secondProductName: product.secondProductName ?? "",
                purchasePrice: product.purchasePrice,
                retailPrice: product.retailPrice,
                stockQuantity: product.stockQuantity,
                supplierName: resolvedSupplierName(for: product),
                categoryName: resolvedCategoryName(for: product)
            )
        }
    }

    private func resolvedSupplierName(for product: Product) -> String {
        resolvedCurrentProduct(for: product)?.supplier?.name
            ?? product.supplier?.name
            ?? products.first(where: { $0.barcode == product.barcode })?.supplier?.name
            ?? ""
    }

    private func resolvedCategoryName(for product: Product) -> String {
        resolvedCurrentProduct(for: product)?.category?.name
            ?? product.category?.name
            ?? products.first(where: { $0.barcode == product.barcode })?.category?.name
            ?? ""
    }

    private func resolvedCurrentProduct(for product: Product) -> Product? {
        context.model(for: product.persistentModelID) as? Product
    }

    private func validateExportedProductsSheet(
        at url: URL,
        expectedRows: [ExportedProductRow]
    ) throws {
        let rows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: "Products")
        guard let header = rows.first else {
            throw NSError(
                domain: "ExportExcel",
                code: 20,
                userInfo: [NSLocalizedDescriptionKey: L("database.validation.products_sheet_missing")]
            )
        }

        guard let barcodeIndex = header.firstIndex(of: "barcode"),
              let supplierIndex = header.firstIndex(of: "supplierName"),
              let categoryIndex = header.firstIndex(of: "categoryName") else {
            throw NSError(
                domain: "ExportExcel",
                code: 21,
                userInfo: [NSLocalizedDescriptionKey: L("database.validation.products_columns_missing")]
            )
        }

        let actualByBarcode = Dictionary(
            uniqueKeysWithValues: rows.dropFirst().compactMap { row -> (String, (String, String))? in
                let barcode = DatabaseImportPipeline.cellValue(in: row, at: barcodeIndex)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !barcode.isEmpty else { return nil }

                return (
                    barcode,
                    (
                        DatabaseImportPipeline.cellValue(in: row, at: supplierIndex)
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                        DatabaseImportPipeline.cellValue(in: row, at: categoryIndex)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                )
            }
        )

        for expected in expectedRows {
            guard let actual = actualByBarcode[expected.barcode] else {
                throw NSError(
                    domain: "ExportExcel",
                    code: 22,
                    userInfo: [NSLocalizedDescriptionKey: L("database.validation.missing_exported_row", expected.barcode)]
                )
            }

            let expectedSupplier = expected.supplierName.trimmingCharacters(in: .whitespacesAndNewlines)
            let expectedCategory = expected.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)

            if actual.0 != expectedSupplier || actual.1 != expectedCategory {
                throw NSError(
                    domain: "ExportExcel",
                    code: 23,
                    userInfo: [
                        NSLocalizedDescriptionKey: L("database.validation.exported_values_mismatch", expected.barcode)
                    ]
                )
            }
        }
    }

    private func escapeCSVField(_ field: String) -> String {
        if field.contains(";") || field.contains("\"") || field.contains("\n") {
            var escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            escaped = "\"\(escaped)\""
            return escaped
        } else {
            return field
        }
    }

    // MARK: - Import Excel con analisi (stile Android)

    private func importProductsFromExcel(url: URL) {
        guard !importProgress.isRunning else {
            importError = L("database.error.import_in_progress")
            return
        }

        clearAllFullImportResultState()
        importError = nil
        importAnalysisSession = nil
        pendingFullImportContext = nil
        importProgress.startPreparation(jobKind: .analysisImport)

        do {
            let tempURL = try copySecurityScopedImportFileToTemporaryLocation(from: url)
            let modelContainer = context.container
            let progressState = importProgress

            Task {
                defer { try? FileManager.default.removeItem(at: tempURL) }

                do {
                    let prepared = try await DatabaseImportPipeline.prepareProductsImport(
                        from: tempURL,
                        modelContainer: modelContainer,
                        onProgress: { snapshot in
                            await MainActor.run {
                                progressState.apply(snapshot)
                            }
                        }
                    )

                    await MainActor.run {
                        pendingFullImportContext = nil
                        importAnalysisSession = ImportAnalysisSession(
                            analysis: DatabaseImportUILocalizer.analysisResult(from: prepared.analysis)
                        )
                        progressState.awaitingConfirmation()
                    }
                } catch {
                    await MainActor.run {
                        finalizeImportPreparationFailure(error)
                    }
                }
            }
        } catch {
            finalizeImportPreparationFailure(error)
        }
    }

    private func importFullDatabaseFromExcel(url: URL) {
        guard !importProgress.isRunning else {
            importError = L("database.error.import_in_progress")
            return
        }

        clearAllFullImportResultState()
        importError = nil
        importAnalysisSession = nil
        pendingFullImportContext = nil
        fullImportPrepareTask?.cancel()
        fullImportPrepareTask = nil
        fullImportPrepareTaskID = nil
        cancelledFullImportPrepareTaskID = nil
        importProgress.startPreparation(jobKind: .fullDatabaseImport)

        do {
            let tempURL = try copySecurityScopedImportFileToTemporaryLocation(from: url)
            let modelContainer = context.container
            let progressState = importProgress
            let runID = UUID()
            let task = Task {
                defer { try? FileManager.default.removeItem(at: tempURL) }

                do {
                    let prepared = try await DatabaseImportPipeline.prepareFullDatabaseImport(
                        from: tempURL,
                        modelContainer: modelContainer,
                        onProgress: { snapshot in
                            await MainActor.run {
                                progressState.apply(snapshot)
                            }
                        }
                    )

                    handlePreparedFullImportSuccess(prepared, runID: runID)
                } catch is CancellationError {
                    handlePreparedFullImportCancellation(runID: runID)
                } catch {
                    handlePreparedFullImportFailure(error, runID: runID)
                }
            }
            fullImportPrepareTask = task
            fullImportPrepareTaskID = runID
        } catch let error as LocalizedError {
            finalizeFullImportPreparationFailure(error)
        } catch {
            finalizeFullImportPreparationFailure(error)
        }
    }

    private func handleImportAnalysisDismissed() {
        importAnalysisSession = nil
        pendingFullImportContext = nil
        if importProgress.isRunning {
            importProgress.resetRunningState()
        }
        presentDeferredFullImportResultIfNeeded()
    }

    private func finalizeImportPreparationFailure(_ error: Error) {
        pendingFullImportContext = nil
        importAnalysisSession = nil
        importProgress.resetRunningState()
        importError = DatabaseImportUILocalizer.importErrorMessage(for: error)
    }

    private func finalizeFullImportPreparationFailure(_ error: Error) {
        pendingFullImportContext = nil
        importAnalysisSession = nil
        importProgress.resetRunningState()
        fullImportResultPayload = DatabaseImportUILocalizer.fullImportErrorResult(
            message: DatabaseImportUILocalizer.importErrorMessage(for: error)
        )
    }

    private func finalizeFullImportPreparationCancellation() {
        pendingFullImportContext = nil
        importAnalysisSession = nil
        importProgress.resetRunningState()
        fullImportResultPayload = DatabaseImportUILocalizer.fullImportCancelledResult()
    }

    private func handlePreparedFullImportSuccess(
        _ prepared: PreparedImportAnalysis,
        runID: UUID
    ) {
        guard fullImportPrepareTaskID == runID else {
            if cancelledFullImportPrepareTaskID == runID {
                cancelledFullImportPrepareTaskID = nil
                finalizeFullImportPreparationCancellation()
            }
            return
        }

        fullImportPrepareTask = nil
        fullImportPrepareTaskID = nil
        let existingSupplierNames = Set(
            (try? context.fetch(FetchDescriptor<Supplier>()))?
                .compactMap { normalizedImportNamedEntityName($0.name) }
            ?? []
        )
        let existingCategoryNames = Set(
            (try? context.fetch(FetchDescriptor<ProductCategory>()))?
                .compactMap { normalizedImportNamedEntityName($0.name) }
            ?? []
        )
        pendingFullImportContext = prepared.pendingFullImportContext
        importAnalysisSession = ImportAnalysisSession(
            analysis: DatabaseImportUILocalizer.analysisResult(from: prepared.analysis),
            nonProductSummary: prepared.nonProductSummary,
            pendingSupplierNames: prepared.pendingFullImportContext?.pendingSupplierNames ?? [],
            pendingCategoryNames: prepared.pendingFullImportContext?.pendingCategoryNames ?? [],
            existingSupplierNames: existingSupplierNames,
            existingCategoryNames: existingCategoryNames
        )
        importProgress.awaitingConfirmation()
    }

    private func handlePreparedFullImportCancellation(runID: UUID) {
        let isActiveRun = fullImportPrepareTaskID == runID

        if isActiveRun {
            fullImportPrepareTask = nil
            fullImportPrepareTaskID = nil
        }
        guard isActiveRun || cancelledFullImportPrepareTaskID == runID else {
            return
        }
        cancelledFullImportPrepareTaskID = nil
        finalizeFullImportPreparationCancellation()
    }

    private func handlePreparedFullImportFailure(
        _ error: Error,
        runID: UUID
    ) {
        let isActiveRun = fullImportPrepareTaskID == runID

        if isActiveRun {
            fullImportPrepareTask = nil
            fullImportPrepareTaskID = nil
        }
        guard isActiveRun || cancelledFullImportPrepareTaskID == runID else {
            return
        }
        guard cancelledFullImportPrepareTaskID != runID else {
            cancelledFullImportPrepareTaskID = nil
            finalizeFullImportPreparationCancellation()
            return
        }
        finalizeFullImportPreparationFailure(error)
    }

    private func cancelFullImportPreparation() {
        guard importProgress.canCancelPreparation,
              let runID = fullImportPrepareTaskID else {
            return
        }

        cancelledFullImportPrepareTaskID = runID
        importProgress.beginCancellation()
        fullImportPrepareTask?.cancel()
        fullImportPrepareTask = nil
        fullImportPrepareTaskID = nil
    }

    private func clearPresentedFullImportResult() {
        fullImportResultPayload = nil
    }

    private func clearAllFullImportResultState() {
        deferredFullImportResultPayload = nil
        fullImportResultPayload = nil
    }

    private func deferFullImportResultUntilAnalysisDismiss(_ payload: FullImportResultPayload) {
        deferredFullImportResultPayload = payload
    }

    private func presentDeferredFullImportResultIfNeeded() {
        guard importAnalysisSession == nil,
              let payload = deferredFullImportResultPayload else {
            return
        }

        deferredFullImportResultPayload = nil
        fullImportResultPayload = payload
    }

    private func copySecurityScopedImportFileToTemporaryLocation(from url: URL) throws -> URL {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(
                domain: "ImportExcel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: L("database.error.file_permission_denied")]
            )
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("import-cache", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let fileName = "\(UUID().uuidString)-\(url.lastPathComponent)"
        let tempURL = tempDirectory.appendingPathComponent(fileName)
        try FileManager.default.copyItem(at: url, to: tempURL)
        return tempURL
    }

    @MainActor
    private static func userMessage(for result: ImportApplyResult) -> String {
        let baseMessage: String
        if let priceHistoryError = result.priceHistoryError {
            if result.priceHistoryInserted > 0 {
                baseMessage = L(
                    "database.progress.partial_success",
                    result.productsInserted,
                    result.productsUpdated,
                    priceHistoryError,
                    result.priceHistoryInserted,
                    result.priceHistoryProcessedCount
                )
            } else {
                baseMessage = L(
                    "database.progress.price_history_total_failure",
                    result.productsInserted,
                    result.productsUpdated,
                    priceHistoryError,
                    result.priceHistoryProcessedCount
                )
            }
        } else if result.priceHistoryInserted > 0 {
            baseMessage = L(
                "database.progress.success_with_price_history",
                result.productsInserted,
                result.productsUpdated,
                result.priceHistoryInserted
            )
        } else {
            baseMessage = L(
                "database.progress.success_products_only",
                result.productsInserted,
                result.productsUpdated
            )
        }

        var suffixes: [String] = []
        if result.suppliersCreated > 0 {
            suffixes.append(L("database.progress.suppliers_created_suffix", result.suppliersCreated))
        }
        if result.categoriesCreated > 0 {
            suffixes.append(L("database.progress.categories_created_suffix", result.categoriesCreated))
        }
        if result.priceHistoryUnresolved > 0 {
            suffixes.append(L("database.progress.price_history_unresolved_suffix", result.priceHistoryUnresolved))
        }

        guard !suffixes.isEmpty else { return baseMessage }
        return ([baseMessage] + suffixes).joined(separator: " ")
    }

    @MainActor
    private func applyConfirmedImportAnalysis() async throws {
        guard !importProgress.isRunning || importAnalysisSession != nil else {
            throw NSError(
                domain: "ImportExcelApply",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: L("database.error.import_in_progress")
                ]
            )
        }

        guard let confirmedSession = importAnalysisSession else {
            throw NSError(
                domain: "ImportExcelApply",
                code: 6,
                userInfo: [
                    NSLocalizedDescriptionKey: L("inventory.home.error.unknown")
                ]
            )
        }

        let modelContainer = context.container
        let progressState = importProgress
        let confirmedPendingContext = pendingFullImportContext
        let isFullDatabaseFlow = progressState.isFullDatabaseFlow
        let payload: ImportApplyPayload

        do {
            payload = try Self.makeImportApplyPayload(
                session: confirmedSession,
                pendingFullImportContext: confirmedPendingContext
            )
        } catch {
            progressState.resetRunningState()
            let applyMessage = L("database.error.apply_import", error.localizedDescription)
            if isFullDatabaseFlow {
                pendingFullImportContext = nil
                deferFullImportResultUntilAnalysisDismiss(
                    DatabaseImportUILocalizer.fullImportErrorResult(message: applyMessage)
                )
                importAnalysisSession = nil
                return
            }

            throw NSError(
                domain: "ImportExcelApply",
                code: 4,
                userInfo: [
                    NSLocalizedDescriptionKey: applyMessage
                ]
            )
        }

        importProgress.startApplying(
            jobKind: isFullDatabaseFlow ? .fullDatabaseImport : .analysisImport
        )

        do {
            let result = try await DatabaseImportPipeline.applyImportAnalysisInBackground(
                payload,
                modelContainer: modelContainer,
                onProgress: { snapshot in
                    await progressState.apply(snapshot)
                }
            )
            pendingFullImportContext = nil
            if isFullDatabaseFlow {
                progressState.resetRunningState()
                deferFullImportResultUntilAnalysisDismiss(
                    DatabaseImportUILocalizer.fullImportSuccessResult(from: result)
                )
                importAnalysisSession = nil
                return
            }

            progressState.finishSuccess(message: Self.userMessage(for: result))
        } catch {
            let applyMessage = L("database.error.apply_import", error.localizedDescription)
            pendingFullImportContext = nil
            if isFullDatabaseFlow {
                progressState.resetRunningState()
                deferFullImportResultUntilAnalysisDismiss(
                    DatabaseImportUILocalizer.fullImportErrorResult(message: applyMessage)
                )
                importAnalysisSession = nil
                return
            }

            importAnalysisSession = nil
            progressState.finishError(message: applyMessage)
            throw NSError(
                domain: "ImportExcelApply",
                code: 3,
                userInfo: [
                    NSLocalizedDescriptionKey: applyMessage
                ]
            )
        }
    }

    @MainActor
    private static func makeImportApplyPayload(
        session: ImportAnalysisSession,
        pendingFullImportContext: PendingFullImportContext?
    ) throws -> ImportApplyPayload {
        guard hasWorkToApply(session: session, pendingFullImportContext: pendingFullImportContext) else {
            throw NSError(
                domain: "ImportExcelApply",
                code: 5,
                userInfo: [
                    NSLocalizedDescriptionKey: L("inventory.home.error.unknown")
                ]
            )
        }

        return ImportApplyPayload(
            newProducts: session.newProducts,
            updatedProducts: session.updatedProducts,
            pendingPriceHistoryEntries: pendingFullImportContext?.priceHistoryEntries ?? [],
            alreadyPresentPriceHistoryCount: pendingFullImportContext?.alreadyPresentPriceHistoryCount ?? 0,
            unresolvedPriceHistoryCount: pendingFullImportContext?.unresolvedPriceHistoryCount ?? 0,
            pendingSupplierNames: pendingFullImportContext?.pendingSupplierNames ?? [],
            pendingCategoryNames: pendingFullImportContext?.pendingCategoryNames ?? [],
            recordPriceHistory: !(pendingFullImportContext?.suppressAutomaticProductPriceHistory ?? false)
        )
    }

    @MainActor
    private static func hasWorkToApply(
        session: ImportAnalysisSession,
        pendingFullImportContext: PendingFullImportContext?
    ) -> Bool {
        !session.newProducts.isEmpty
        || !session.updatedProducts.isEmpty
        || (pendingFullImportContext?.hasWorkToApply ?? false)
    }

    // MARK: - Import CSV

    private func importProducts(from url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "Import", code: 1, userInfo: [NSLocalizedDescriptionKey: L("database.error.file_permission_denied")])
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            guard let content = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "Import", code: 2, userInfo: [NSLocalizedDescriptionKey: L("database.error.file_not_utf8")])
            }

            try parseProductsCSV(content)
            try context.save()
        } catch {
            importError = L("database.error.import", error.localizedDescription)
        }
    }

    private func parseProductsCSV(_ content: String) throws {
        let lines = content.split(whereSeparator: \.isNewline)
        guard !lines.isEmpty else { return }

        // salta l'header
        let dataLines = lines.dropFirst()

        for rawLine in dataLines {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }

            let cols = splitCSVRow(line)
            if cols.isEmpty { continue }

            func col(_ index: Int) -> String {
                guard index < cols.count else { return "" }
                return cols[index]
            }

            let barcode = col(0).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !barcode.isEmpty else { continue }

            let itemNumber = col(1).trimmingCharacters(in: .whitespacesAndNewlines)
            let productName = col(2).trimmingCharacters(in: .whitespacesAndNewlines)
            let secondName = col(3).trimmingCharacters(in: .whitespacesAndNewlines)
            let purchase = DatabaseImportPipeline.parseDouble(from: col(4))
            let retail = DatabaseImportPipeline.parseDouble(from: col(5))
            let stock = DatabaseImportPipeline.parseDouble(from: col(6))
            let supplierName = col(7).trimmingCharacters(in: .whitespacesAndNewlines)
            let categoryName = col(8).trimmingCharacters(in: .whitespacesAndNewlines)

            let supplier = supplierName.isEmpty ? nil : findOrCreateSupplier(named: supplierName)
            let category = categoryName.isEmpty ? nil : findOrCreateCategory(named: categoryName)

            // Cerca prodotto esistente per barcode
            let descriptor = FetchDescriptor<Product>(predicate: #Predicate { $0.barcode == barcode })
            let existing = try context.fetch(descriptor).first

            let product: Product
            if let existing {
                product = existing
            } else {
                product = Product(
                    barcode: barcode,
                    itemNumber: itemNumber.isEmpty ? nil : itemNumber,
                    productName: productName.isEmpty ? nil : productName,
                    secondProductName: secondName.isEmpty ? nil : secondName,
                    purchasePrice: purchase,
                    retailPrice: retail,
                    stockQuantity: stock,
                    supplier: supplier,
                    category: category
                )
                context.insert(product)
            }

            product.itemNumber = itemNumber.isEmpty ? nil : itemNumber
            product.productName = productName.isEmpty ? nil : productName
            product.secondProductName = secondName.isEmpty ? nil : secondName
            product.purchasePrice = purchase
            product.retailPrice = retail
            product.stockQuantity = stock
            product.supplier = supplier
            product.category = category
        }
    }

    private func splitCSVRow(_ line: String) -> [String] {
        // parsing molto semplice: separatore ';', gestisce i campi tra doppi apici
        var result: [String] = []
        var current = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
                current.append(char)
            } else if char == ";" && !insideQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            result.append(current.trimmingCharacters(in: .whitespaces))
        }

        // rimuovi doppi apici esterni e rimpiazza "" con "
        return result.map { field in
            var f = field
            if f.hasPrefix("\""), f.hasSuffix("\""), f.count >= 2 {
                f.removeFirst()
                f.removeLast()
            }
            f = f.replacingOccurrences(of: "\"\"", with: "\"")
            return f
        }
    }

    private func findOrCreateSupplier(named name: String) -> Supplier {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Supplier(name: "") }

        let descriptor = FetchDescriptor<Supplier>(predicate: #Predicate { $0.name == trimmed })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        } else {
            let supplier = Supplier(name: trimmed)
            context.insert(supplier)
            return supplier
        }
    }

    private func findOrCreateCategory(named name: String) -> ProductCategory {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ProductCategory(name: "") }

        let descriptor = FetchDescriptor<ProductCategory>(predicate: #Predicate { $0.name == trimmed })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        } else {
            let category = ProductCategory(name: trimmed)
            context.insert(category)
            return category
        }
    }

    // MARK: - Formattazione / parsing numeri

    private func formatMoney(_ value: Double) -> String {
        formatCLPMoney(value)
    }

    private func formatQuantity(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        } else {
            let formatter = NumberFormatter()
            formatter.locale = appLocale()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 3
            formatter.usesGroupingSeparator = false
            return formatter.string(from: value as NSNumber) ?? String(value)
        }
    }

}
