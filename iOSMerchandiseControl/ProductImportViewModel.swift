import Foundation
import SwiftData
import Combine

@MainActor
final class ProductImportViewModel: ObservableObject {
    @Published var analysis: ProductImportAnalysisResult?
    @Published var lastError: String?

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
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
            lastError = "Errore durante l'applicazione dell'import: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers interni (logica di analisi)

    /// Copiata da DatabaseView.analyzeImport(...)
    private func analyzeImport(
        header: [String],
        dataRows: [[String]],
        existingProducts: [Product]
    ) throws -> ProductImportAnalysisResult {
        guard header.contains("barcode") else {
            throw ExcelLoadError.invalidFormat("Impossibile trovare la colonna 'barcode' nel file.")
        }

        // Mappa prodotti esistenti per barcode
        let existingByBarcode: [String: Product] = Dictionary(
            uniqueKeysWithValues: existingProducts.map { ($0.barcode, $0) }
        )

        struct PendingRow {
            var lastRow: [String: String]
            var rowNumbers: [Int]
            var quantitySum: Double
        }

        var errors: [ProductImportRowError] = []
        var pendingByBarcode: [String: PendingRow] = [:]

        // 1) Normalizza righe e raggruppa per barcode
        for (index, row) in dataRows.enumerated() {
            let rowNumber = index + 1 // 1-based

            var map: [String: String] = [:]
            for (colIndex, key) in header.enumerated() {
                let raw = colIndex < row.count ? row[colIndex] : ""
                map[key] = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let barcode = (map["barcode"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if barcode.isEmpty {
                errors.append(
                    ProductImportRowError(
                        rowNumber: rowNumber,
                        reason: "Manca il barcode.",
                        rowContent: map
                    )
                )
                continue
            }

            // quantity / stockQuantity (supporta entrambi i nomi)
            let quantity = Self.parseDouble(from: map["stockQuantity"] ?? "")
                ?? Self.parseDouble(from: map["quantity"] ?? "")
                ?? 0

            if var pending = pendingByBarcode[barcode] {
                pending.lastRow = map
                pending.rowNumbers.append(rowNumber)
                pending.quantitySum += quantity
                pendingByBarcode[barcode] = pending
            } else {
                pendingByBarcode[barcode] = PendingRow(
                    lastRow: map,
                    rowNumbers: [rowNumber],
                    quantitySum: quantity
                )
            }
        }

        // 2) Converte PendingRow → ProductDraft / ProductUpdateDraft
        var newProducts: [ProductDraft] = []
        var updates: [ProductUpdateDraft] = []
        var warnings: [ProductDuplicateWarning] = []

        func trimmedOrNil(_ text: String?) -> String? {
            guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return nil }
            return value
        }

        func doublesEqual(_ lhs: Double?, _ rhs: Double?, epsilon: Double = 0.0001) -> Bool {
            switch (lhs, rhs) {
            case (nil, nil):
                return true
            case let (l?, r?):
                return abs(l - r) < epsilon
            default:
                return false
            }
        }

        for (barcode, pending) in pendingByBarcode.sorted(by: { $0.key < $1.key }) {
            var row = pending.lastRow
            if pending.quantitySum > 0 {
                row["stockQuantity"] = String(pending.quantitySum)
            }

            let draft = ProductDraft(
                barcode: barcode,
                itemNumber: trimmedOrNil(row["itemNumber"]),
                productName: trimmedOrNil(row["productName"]),
                secondProductName: trimmedOrNil(row["secondProductName"]),
                purchasePrice: Self.parseDouble(from: row["purchasePrice"] ?? ""),
                retailPrice: Self.parseDouble(from: row["retailPrice"] ?? ""),
                stockQuantity: {
                    if let text = row["stockQuantity"] ?? row["quantity"],
                       let value = Self.parseDouble(from: text) {
                        return value
                    } else {
                        return nil
                    }
                }(),
                supplierName: trimmedOrNil(row["supplier"]),
                categoryName: trimmedOrNil(row["category"])
            )

            if let existing = existingByBarcode[barcode] {
                let oldDraft = ProductDraft(
                    barcode: existing.barcode,
                    itemNumber: existing.itemNumber,
                    productName: existing.productName,
                    secondProductName: existing.secondProductName,
                    purchasePrice: existing.purchasePrice,
                    retailPrice: existing.retailPrice,
                    stockQuantity: existing.stockQuantity,
                    supplierName: existing.supplier?.name,
                    categoryName: existing.category?.name
                )

                let changedFields = ProductUpdateDraft.ChangedField.allCases.filter { field in
                    switch field {
                    case .itemNumber:
                        return (oldDraft.itemNumber ?? "") != (draft.itemNumber ?? "")
                    case .productName:
                        return (oldDraft.productName ?? "") != (draft.productName ?? "")
                    case .secondProductName:
                        return (oldDraft.secondProductName ?? "") != (draft.secondProductName ?? "")
                    case .purchasePrice:
                        return !doublesEqual(oldDraft.purchasePrice, draft.purchasePrice)
                    case .retailPrice:
                        return !doublesEqual(oldDraft.retailPrice, draft.retailPrice)
                    case .stockQuantity:
                        return !doublesEqual(oldDraft.stockQuantity, draft.stockQuantity)
                    case .supplierName:
                        return (oldDraft.supplierName ?? "") != (draft.supplierName ?? "")
                    case .categoryName:
                        return (oldDraft.categoryName ?? "") != (draft.categoryName ?? "")
                    }
                }

                if !changedFields.isEmpty {
                    updates.append(
                        ProductUpdateDraft(
                            barcode: barcode,
                            old: oldDraft,
                            new: draft,
                            changedFields: changedFields
                        )
                    )
                }
            } else {
                newProducts.append(draft)
            }

            if pending.rowNumbers.count > 1 {
                warnings.append(
                    ProductDuplicateWarning(
                        barcode: barcode,
                        rowNumbers: pending.rowNumbers
                    )
                )
            }
        }

        return ProductImportAnalysisResult(
            newProducts: newProducts,
            updatedProducts: updates,
            errors: errors,
            warnings: warnings
        )
    }

    /// Copiata da DatabaseView.applyImportAnalysis(...)
    private func applyImportAnalysis(_ analysis: ProductImportAnalysisResult) throws {
        // Nuovi prodotti
        for draft in analysis.newProducts {
            let supplier: Supplier? = draft.supplierName.flatMap { name in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : findOrCreateSupplier(named: trimmed)
            }

            let category: ProductCategory? = draft.categoryName.flatMap { name in
                let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : findOrCreateCategory(named: trimmed)
            }

            let product = Product(
                barcode: draft.barcode,
                itemNumber: draft.itemNumber,
                productName: draft.productName,
                secondProductName: draft.secondProductName,
                purchasePrice: draft.purchasePrice,
                retailPrice: draft.retailPrice,
                stockQuantity: draft.stockQuantity,
                supplier: supplier,
                category: category
            )
            context.insert(product)

            createPriceHistoryForImport(
                product: product,
                oldPurchase: nil,
                newPurchase: draft.purchasePrice,
                oldRetail: nil,
                newRetail: draft.retailPrice
            )
        }

        // Aggiornamenti
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

            let newDraft = update.new
            let oldPurchase = product.purchasePrice
            let oldRetail = product.retailPrice

            if update.changedFields.contains(.itemNumber) {
                product.itemNumber = newDraft.itemNumber
            }
            if update.changedFields.contains(.productName) {
                product.productName = newDraft.productName
            }
            if update.changedFields.contains(.secondProductName) {
                product.secondProductName = newDraft.secondProductName
            }
            if update.changedFields.contains(.purchasePrice) {
                product.purchasePrice = newDraft.purchasePrice
            }
            if update.changedFields.contains(.retailPrice) {
                product.retailPrice = newDraft.retailPrice
            }
            if update.changedFields.contains(.stockQuantity) {
                product.stockQuantity = newDraft.stockQuantity
            }
            if update.changedFields.contains(.supplierName) {
                if let name = newDraft.supplierName,
                   !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    product.supplier = findOrCreateSupplier(named: name)
                } else {
                    product.supplier = nil
                }
            }
            if update.changedFields.contains(.categoryName) {
                if let name = newDraft.categoryName,
                   !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    product.category = findOrCreateCategory(named: name)
                } else {
                    product.category = nil
                }
            }

            createPriceHistoryForImport(
                product: product,
                oldPurchase: oldPurchase,
                newPurchase: newDraft.purchasePrice,
                oldRetail: oldRetail,
                newRetail: newDraft.retailPrice
            )
        }
    }

    // MARK: - Helpers DB (copiati da DatabaseView)

    private func createPriceHistoryForImport(
        product: Product,
        oldPurchase: Double?,
        newPurchase: Double?,
        oldRetail: Double?,
        newRetail: Double?
    ) {
        let now = Date()

        if let newPurchase, newPurchase != oldPurchase {
            let history = ProductPrice(
                type: .purchase,
                price: newPurchase,
                effectiveAt: now,
                source: "IMPORT_EXCEL",
                note: nil,
                createdAt: now,
                product: product
            )
            context.insert(history)
        }

        if let newRetail, newRetail != oldRetail {
            let history = ProductPrice(
                type: .retail,
                price: newRetail,
                effectiveAt: now,
                source: "IMPORT_EXCEL",
                note: nil,
                createdAt: now,
                product: product
            )
            context.insert(history)
        }
    }

    private func findOrCreateSupplier(named name: String) -> Supplier {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Supplier(name: "")
        }

        let descriptor = FetchDescriptor<Supplier>(
            predicate: #Predicate { $0.name == trimmed }
        )
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
        guard !trimmed.isEmpty else {
            return ProductCategory(name: "")
        }

        let descriptor = FetchDescriptor<ProductCategory>(
            predicate: #Predicate { $0.name == trimmed }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        } else {
            let category = ProductCategory(name: trimmed)
            context.insert(category)
            return category
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

    private static func parseDouble(from text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }
}
