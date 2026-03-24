import Foundation
import SwiftData

enum ProductImportCore {
    static func parseDouble(from text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    static func analyzeImport(
        header: [String],
        dataRows: [[String]],
        existingProductsByBarcode: [String: ProductDraft]
    ) -> ProductImportAnalysisResult {
        struct PendingRow {
            var lastRow: [String: String]
            var rowNumbers: [Int]
            var quantitySum: Double
        }

        var errors: [ProductImportRowError] = []
        var pendingByBarcode: [String: PendingRow] = [:]

        for (index, row) in dataRows.enumerated() {
            let rowNumber = index + 1

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

            let quantity = parseDouble(from: map["stockQuantity"] ?? "")
                ?? parseDouble(from: map["quantity"] ?? "")
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

        var newProducts: [ProductDraft] = []
        var updates: [ProductUpdateDraft] = []
        var warnings: [ProductDuplicateWarning] = []

        for (barcode, pending) in pendingByBarcode.sorted(by: { $0.key < $1.key }) {
            var row = pending.lastRow
            if pending.quantitySum > 0 {
                row["stockQuantity"] = String(pending.quantitySum)
            }

            let draft = ProductDraft(
                barcode: barcode,
                itemNumber: normalizedImportNamedEntityName(row["itemNumber"]),
                productName: normalizedImportNamedEntityName(row["productName"]),
                secondProductName: normalizedImportNamedEntityName(row["secondProductName"]),
                purchasePrice: parseDouble(from: row["purchasePrice"] ?? ""),
                retailPrice: parseDouble(from: row["retailPrice"] ?? ""),
                stockQuantity: {
                    if let text = row["stockQuantity"] ?? row["quantity"],
                       let value = parseDouble(from: text) {
                        return value
                    }
                    return nil
                }(),
                supplierName: normalizedImportNamedEntityName(row["supplier"]),
                categoryName: normalizedImportNamedEntityName(row["category"])
            )

            if let oldDraft = existingProductsByBarcode[barcode] {
                let changedFields = ProductUpdateDraft.computeChangedFields(old: oldDraft, new: draft)
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

    @discardableResult
    static func insertProduct(
        from draft: ProductDraft,
        in context: ModelContext,
        resolver: ProductImportNamedEntityResolver,
        recordPriceHistory: Bool
    ) -> Product {
        let product = Product(
            barcode: draft.barcode,
            itemNumber: draft.itemNumber,
            productName: draft.productName,
            secondProductName: draft.secondProductName,
            purchasePrice: draft.purchasePrice,
            retailPrice: draft.retailPrice,
            stockQuantity: draft.stockQuantity,
            supplier: resolver.resolveSupplier(named: draft.supplierName),
            category: resolver.resolveCategory(named: draft.categoryName)
        )
        context.insert(product)

        if recordPriceHistory {
            createPriceHistoryForImport(
                product: product,
                oldPurchase: nil,
                newPurchase: draft.purchasePrice,
                oldRetail: nil,
                newRetail: draft.retailPrice,
                in: context
            )
        }

        return product
    }

    static func applyUpdate(
        _ update: ProductUpdateDraft,
        to product: Product,
        in context: ModelContext,
        resolver: ProductImportNamedEntityResolver,
        recordPriceHistory: Bool
    ) {
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
            product.supplier = resolver.resolveSupplier(named: newDraft.supplierName)
        }
        if update.changedFields.contains(.categoryName) {
            product.category = resolver.resolveCategory(named: newDraft.categoryName)
        }

        if recordPriceHistory {
            createPriceHistoryForImport(
                product: product,
                oldPurchase: oldPurchase,
                newPurchase: newDraft.purchasePrice,
                oldRetail: oldRetail,
                newRetail: newDraft.retailPrice,
                in: context
            )
        }
    }

    static func createPriceHistoryForImport(
        product: Product,
        oldPurchase: Double?,
        newPurchase: Double?,
        oldRetail: Double?,
        newRetail: Double?,
        in context: ModelContext
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
}

final class ProductImportNamedEntityResolver {
    private let context: ModelContext
    private var suppliersByName: [String: Supplier]
    private var categoriesByName: [String: ProductCategory]
    private var createdSupplierNames: Set<String> = []
    private var createdCategoryNames: Set<String> = []

    init(
        context: ModelContext,
        existingSuppliers: [Supplier]? = nil,
        existingCategories: [ProductCategory]? = nil
    ) throws {
        self.context = context

        let suppliers: [Supplier]
        if let existingSuppliers {
            suppliers = existingSuppliers
        } else {
            suppliers = try context.fetch(FetchDescriptor<Supplier>())
        }

        let categories: [ProductCategory]
        if let existingCategories {
            categories = existingCategories
        } else {
            categories = try context.fetch(FetchDescriptor<ProductCategory>())
        }

        suppliersByName = Dictionary(
            uniqueKeysWithValues: suppliers.compactMap { supplier in
                guard let normalizedName = normalizedImportNamedEntityName(supplier.name) else {
                    return nil
                }
                return (normalizedName, supplier)
            }
        )

        categoriesByName = Dictionary(
            uniqueKeysWithValues: categories.compactMap { category in
                guard let normalizedName = normalizedImportNamedEntityName(category.name) else {
                    return nil
                }
                return (normalizedName, category)
            }
        )
    }

    var suppliersCreatedCount: Int {
        createdSupplierNames.count
    }

    var categoriesCreatedCount: Int {
        createdCategoryNames.count
    }

    func preloadSuppliers(named names: [String]) {
        for name in names {
            _ = resolveSupplier(named: name)
        }
    }

    func preloadCategories(named names: [String]) {
        for name in names {
            _ = resolveCategory(named: name)
        }
    }

    func resolveSupplier(named rawName: String?) -> Supplier? {
        guard let normalizedName = normalizedImportNamedEntityName(rawName) else {
            return nil
        }

        if let existing = suppliersByName[normalizedName] {
            return existing
        }

        let supplier = Supplier(name: normalizedName)
        context.insert(supplier)
        suppliersByName[normalizedName] = supplier
        createdSupplierNames.insert(normalizedName)
        return supplier
    }

    func resolveCategory(named rawName: String?) -> ProductCategory? {
        guard let normalizedName = normalizedImportNamedEntityName(rawName) else {
            return nil
        }

        if let existing = categoriesByName[normalizedName] {
            return existing
        }

        let category = ProductCategory(name: normalizedName)
        context.insert(category)
        categoriesByName[normalizedName] = category
        createdCategoryNames.insert(normalizedName)
        return category
    }
}
