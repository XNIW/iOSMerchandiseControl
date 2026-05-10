import Foundation
import SwiftData
import Combine

@MainActor
final class ProductImportViewModel: ObservableObject {
    @Published var analysis: ProductImportAnalysisResult?
    @Published var lastError: String?

    private let context: ModelContext
    private let ownerUserID: UUID?

    init(context: ModelContext, ownerUserID: UUID? = nil) {
        self.context = context
        self.ownerUserID = ownerUserID
    }

    // MARK: - API pubblica

    /// Versione “da Excel”: header + righe
    func analyzeExcelGrid(header: [String], dataRows: [[String]]) {
        do {
            let existingProducts = try context.fetch(FetchDescriptor<Product>())
            let result = try analyzeImport(
                header: header,
                dataRows: dataRows,
                existingProducts: existingProducts
            )
            self.analysis = result
            self.lastError = nil
        } catch {
            self.analysis = nil
            self.lastError = error.localizedDescription
        }
    }

    /// Versione “generica”: lista di dizionari [colonna: valore]
    func analyzeMappedRows(_ rows: [[String: String]]) {
        do {
            let header = inferHeader(from: rows)
            let dataRows = rows.map { row in
                header.map { key in row[key] ?? "" }
            }
            let existingProducts = try context.fetch(FetchDescriptor<Product>())
            let result = try analyzeImport(
                header: header,
                dataRows: dataRows,
                existingProducts: existingProducts
            )
            self.analysis = result
            self.lastError = nil
        } catch {
            self.analysis = nil
            self.lastError = error.localizedDescription
        }
    }

    /// Applica l’analisi al DB SwiftData
    func applyImport() {
        guard let analysis else { return }
        do {
            try applyImportAnalysis(analysis)
            try context.save()
            lastError = nil
        } catch {
            context.rollback()
            lastError = "Errore durante l'applicazione dell'import: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers interni (core import condiviso)

    private func analyzeImport(
        header: [String],
        dataRows: [[String]],
        existingProducts: [Product]
    ) throws -> ProductImportAnalysisResult {
        guard header.contains("barcode") else {
            throw ExcelLoadError.invalidFormat("Impossibile trovare la colonna 'barcode' nel file.")
        }

        let existingProductsByBarcode: [String: ProductDraft] = Dictionary(
            uniqueKeysWithValues: existingProducts.map { product in
                (
                    product.barcode,
                    ProductDraft(
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
                )
            }
        )

        return ProductImportCore.analyzeImport(
            header: header,
            dataRows: dataRows,
            existingProductsByBarcode: existingProductsByBarcode
        )
    }

    private func applyImportAnalysis(_ analysis: ProductImportAnalysisResult) throws {
        let resolver = try ProductImportNamedEntityResolver(context: context)
        let accumulator = LocalPendingChangeAccumulator(
            context: context,
            ownerUserID: ownerUserID
        )

        for draft in analysis.newProducts {
            var priceChanges: [ProductPrice] = []
            let product = ProductImportCore.insertProduct(
                from: draft,
                in: context,
                resolver: resolver,
                recordPriceHistory: true,
                onPriceHistoryCreated: { priceChanges.append($0) }
            )
            try accumulator.recordProductChange(
                product: product,
                operation: .create,
                origin: .confirmedImport,
                changedFields: Self.createChangedFields
            )
            try priceChanges.forEach {
                try accumulator.recordProductPriceChange(price: $0, origin: .confirmedImport)
            }
        }

        for update in analysis.updatedProducts {
            let targetBarcode = update.barcode

            let descriptor = FetchDescriptor<Product>(
                predicate: #Predicate<Product> { product in
                    product.barcode == targetBarcode
                }
            )

            guard let product = try context.fetch(descriptor).first else {
                continue
            }

            let baselineHash = LocalPendingChangeLogicalKey.productFingerprintHash(update.old)
            let priceChanges = ProductImportCore.applyUpdate(
                update,
                to: product,
                in: context,
                resolver: resolver,
                recordPriceHistory: true
            )
            try accumulator.recordProductChange(
                product: product,
                operation: .update,
                origin: .confirmedImport,
                changedFields: update.changedFields.map(\.rawValue),
                baselineFingerprintHash: baselineHash
            )
            try priceChanges.forEach {
                try accumulator.recordProductPriceChange(price: $0, origin: .confirmedImport)
            }
        }

        try resolver.createdSuppliers.forEach {
            try accumulator.recordSupplierChange(
                supplier: $0,
                operation: .create,
                origin: .confirmedImport
            )
        }
        try resolver.createdCategories.forEach {
            try accumulator.recordCategoryChange(
                category: $0,
                operation: .create,
                origin: .confirmedImport
            )
        }
    }

    /// header = unione ordinata di tutte le chiavi viste nelle righe
    private func inferHeader(from rows: [[String: String]]) -> [String] {
        var ordered = [String]()
        var seen = Set<String>()

        for row in rows {
            for key in row.keys where !seen.contains(key) {
                ordered.append(key)
                seen.insert(key)
            }
        }

        return ordered
    }

    private static let createChangedFields = [
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
}
