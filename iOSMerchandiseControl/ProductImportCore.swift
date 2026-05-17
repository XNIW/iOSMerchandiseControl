import Foundation
import SwiftData

nonisolated enum ProductImportCore {
    private static let currentImportSource = "IMPORT_EXCEL"
    private static let previousImportSource = "IMPORT_PREV"

    private struct PendingRow {
        var lastRow: [String: String]
        var rowNumbers: [Int]
        var quantitySum: Double
        var hasQuantity: Bool
    }

    private struct ParsedDraft {
        let draft: ProductDraft
        let errorKeys: [String]
    }

    private struct NumericValue {
        let raw: String
        let value: Double?

        var hasInput: Bool {
            !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var isInvalid: Bool {
            hasInput && value == nil
        }
    }

    static func parseDouble(from text: String) -> Double? {
        let raw = trimImportText(text)
        guard !raw.isEmpty else { return nil }

        var working = raw
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
            .replacingOccurrences(of: "\u{2007}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{2212}", with: "-")

        var isNegative = false
        if working.hasPrefix("("), working.hasSuffix(")") {
            isNegative = true
            working.removeFirst()
            working.removeLast()
        }

        let scientificPattern = #"\d+[.,]?\d*[eE][-+]?\d+"#
        let keepsExponent = working.range(
            of: scientificPattern,
            options: .regularExpression
        ) != nil
        let allowedScalars = CharacterSet(charactersIn: keepsExponent ? "0123456789.,+-eE" : "0123456789.,+-")
        let filtered = String(working.unicodeScalars.filter { allowedScalars.contains($0) })
        guard filtered.contains(where: { $0.isNumber }) else { return nil }

        let normalized = normalizeNumberString(filtered)
        guard let parsed = Double(normalized), parsed.isFinite else { return nil }
        return isNegative ? -parsed : parsed
    }

    static func analyzeImport(
        header: [String],
        dataRows: [[String]],
        existingProductsByBarcode: [String: ProductDraft]
    ) -> ProductImportAnalysisResult {
        var errors: [ProductImportRowError] = []
        var pendingByBarcode: [String: PendingRow] = [:]
        let existingByBarcode = normalizedExistingProducts(existingProductsByBarcode)

        for (index, row) in dataRows.enumerated() {
            let rowNumber = index + 1
            let map = mappedRow(header: header, row: row)

            guard let barcode = normalizedBarcode(from: map["barcode"]) else {
                errors.append(
                    ProductImportRowError(
                        rowNumber: rowNumber,
                        reasonKey: "import.analysis.row_error.barcode_missing",
                        rowContent: map
                    )
                )
                continue
            }

            let quantityForMerge = quantityValue(in: map)
            if var pending = pendingByBarcode[barcode] {
                pending.lastRow = map
                pending.rowNumbers.append(rowNumber)
                pending.quantitySum += quantityForMerge.value ?? 0
                pending.hasQuantity = pending.hasQuantity || quantityForMerge.hasInput
                pendingByBarcode[barcode] = pending
            } else {
                pendingByBarcode[barcode] = PendingRow(
                    lastRow: map,
                    rowNumbers: [rowNumber],
                    quantitySum: quantityForMerge.value ?? 0,
                    hasQuantity: quantityForMerge.hasInput
                )
            }
        }

        var newProducts: [ProductDraft] = []
        var updates: [ProductUpdateDraft] = []
        var warnings: [ProductDuplicateWarning] = []

        for (barcode, pending) in pendingByBarcode.sorted(by: { $0.key < $1.key }) {
            var row = pending.lastRow
            if pending.hasQuantity {
                row["stockQuantity"] = decimalString(pending.quantitySum)
                row["quantity"] = ""
                row["realQuantity"] = ""
            }

            if pending.rowNumbers.count > 1 {
                warnings.append(
                    ProductDuplicateWarning(
                        barcode: barcode,
                        rowNumbers: pending.rowNumbers
                    )
                )
            }

            let oldDraft = existingByBarcode[barcode]
            let parsed = parseProductDraft(
                barcode: barcode,
                row: row,
                existingDraft: oldDraft
            )

            if !parsed.errorKeys.isEmpty {
                errors.append(
                    ProductImportRowError(
                        rowNumber: pending.rowNumbers.last ?? pending.rowNumbers[0],
                        reasonKeys: parsed.errorKeys,
                        rowContent: row
                    )
                )
                continue
            }

            if let oldDraft {
                let changedFields = ProductUpdateDraft.computeChangedFields(
                    old: oldDraft,
                    new: parsed.draft
                )
                if !changedFields.isEmpty {
                    updates.append(
                        ProductUpdateDraft(
                            barcode: barcode,
                            old: oldDraft,
                            new: parsed.draft,
                            changedFields: changedFields
                        )
                    )
                }
            } else {
                newProducts.append(parsed.draft)
            }
        }

        return ProductImportAnalysisResult(
            newProducts: newProducts,
            updatedProducts: updates,
            errors: errors,
            warnings: warnings,
            totalInputRows: dataRows.count
        )
    }

    @discardableResult
    static func insertProduct(
        from draft: ProductDraft,
        in context: ModelContext,
        resolver: ProductImportNamedEntityResolver,
        recordPriceHistory: Bool,
        onPriceHistoryCreated: (ProductPrice) -> Void = { _ in }
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
                previousPurchase: draft.oldPurchasePrice,
                previousRetail: draft.oldRetailPrice,
                in: context,
                onPriceHistoryCreated: onPriceHistoryCreated
            )
        }

        return product
    }

    @discardableResult
    static func applyUpdate(
        _ update: ProductUpdateDraft,
        to product: Product,
        in context: ModelContext,
        resolver: ProductImportNamedEntityResolver,
        recordPriceHistory: Bool,
        onPriceHistoryCreated: (ProductPrice) -> Void = { _ in }
    ) -> [ProductPrice] {
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
            return createPriceHistoryForImport(
                product: product,
                oldPurchase: oldPurchase,
                newPurchase: newDraft.purchasePrice,
                oldRetail: oldRetail,
                newRetail: newDraft.retailPrice,
                previousPurchase: newDraft.oldPurchasePrice,
                previousRetail: newDraft.oldRetailPrice,
                in: context,
                onPriceHistoryCreated: onPriceHistoryCreated
            )
        }
        return []
    }

    @discardableResult
    static func createPriceHistoryForImport(
        product: Product,
        oldPurchase: Double?,
        newPurchase: Double?,
        oldRetail: Double?,
        newRetail: Double?,
        previousPurchase: Double? = nil,
        previousRetail: Double? = nil,
        in context: ModelContext,
        onPriceHistoryCreated: (ProductPrice) -> Void = { _ in }
    ) -> [ProductPrice] {
        let now = Date()
        let previousDate = now.addingTimeInterval(-1)
        var created: [ProductPrice] = []

        if let previousPurchase,
           !doublesEqual(previousPurchase, newPurchase),
           !hasPriceHistory(product: product, type: .purchase, price: previousPurchase, source: previousImportSource) {
            created.append(
                insertPriceHistory(
                    type: .purchase,
                    price: previousPurchase,
                    effectiveAt: previousDate,
                    source: previousImportSource,
                    product: product,
                    in: context,
                    onPriceHistoryCreated: onPriceHistoryCreated
                )
            )
        }

        if let newPurchase,
           !doublesEqual(newPurchase, oldPurchase),
           !hasPriceHistory(product: product, type: .purchase, price: newPurchase, source: currentImportSource) {
            created.append(
                insertPriceHistory(
                    type: .purchase,
                    price: newPurchase,
                    effectiveAt: now,
                    source: currentImportSource,
                    product: product,
                    in: context,
                    onPriceHistoryCreated: onPriceHistoryCreated
                )
            )
        }

        if let previousRetail,
           !doublesEqual(previousRetail, newRetail),
           !hasPriceHistory(product: product, type: .retail, price: previousRetail, source: previousImportSource) {
            created.append(
                insertPriceHistory(
                    type: .retail,
                    price: previousRetail,
                    effectiveAt: previousDate,
                    source: previousImportSource,
                    product: product,
                    in: context,
                    onPriceHistoryCreated: onPriceHistoryCreated
                )
            )
        }

        if let newRetail,
           !doublesEqual(newRetail, oldRetail),
           !hasPriceHistory(product: product, type: .retail, price: newRetail, source: currentImportSource) {
            created.append(
                insertPriceHistory(
                    type: .retail,
                    price: newRetail,
                    effectiveAt: now,
                    source: currentImportSource,
                    product: product,
                    in: context,
                    onPriceHistoryCreated: onPriceHistoryCreated
                )
            )
        }
        return created
    }

    static func normalizedRelationKey(_ rawName: String?) -> String? {
        guard let name = normalizedDisplayName(rawName) else { return nil }
        return name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
    }

    static func normalizedDisplayName(_ rawName: String?) -> String? {
        let trimmed = trimImportText(rawName ?? "")
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func parseProductDraft(
        barcode: String,
        row: [String: String],
        existingDraft: ProductDraft?
    ) -> ParsedDraft {
        var rowErrorKeys: [String] = []

        let itemNumber = normalizedDisplayName(row["itemNumber"])
        let productName = normalizedDisplayName(row["productName"])
        let secondProductName = normalizedDisplayName(row["secondProductName"])
        let supplierName = normalizedDisplayName(row["supplier"])
        let categoryName = normalizedDisplayName(row["category"])
        let hasExistingDraft: Bool
        switch existingDraft {
        case .some:
            hasExistingDraft = true
        case .none:
            hasExistingDraft = false
        }

        if productName == nil && secondProductName == nil && !hasExistingDraft {
            rowErrorKeys.append("import.analysis.row_error.product_name_missing")
        } else if productName == nil && secondProductName == nil && hasExistingDraft {
            rowErrorKeys.append("import.analysis.row_error.update_name_missing")
        }

        let purchase = numeric(row["purchasePrice"])
        let retail = numeric(row["retailPrice"])
        let discountedPrice = numeric(row["discountedPrice"])
        let discount = discountPercent(row["discount"])
        let quantity = quantityValue(in: row)
        let oldPurchase = numeric(firstNonEmpty(row["oldPurchasePrice"], row["prevPurchase"]))
        let oldRetail = numeric(firstNonEmpty(row["oldRetailPrice"], row["prevRetail"]))

        appendInvalidNumericErrors(
            [
                ("import.analysis.row_error.purchase_invalid", purchase),
                ("import.analysis.row_error.retail_invalid", retail),
                ("import.analysis.row_error.discounted_invalid", discountedPrice),
                ("import.analysis.row_error.quantity_invalid", quantity),
                ("import.analysis.row_error.old_purchase_invalid", oldPurchase),
                ("import.analysis.row_error.old_retail_invalid", oldRetail)
            ],
            to: &rowErrorKeys
        )

        if discount.isInvalid {
            rowErrorKeys.append("import.analysis.row_error.discount_invalid")
        }

        if let discountValue = discount.value,
           discountValue < 0 || discountValue > 100 {
            rowErrorKeys.append("import.analysis.row_error.discount_range")
        }

        if let purchaseValue = purchase.value, purchaseValue < 0 {
            rowErrorKeys.append("import.analysis.row_error.purchase_negative")
        }
        if let discountedValue = discountedPrice.value, discountedValue < 0 {
            rowErrorKeys.append("import.analysis.row_error.discounted_negative")
        }
        if let quantityValue = quantity.value, quantityValue < 0 {
            rowErrorKeys.append("import.analysis.row_error.quantity_negative")
        }

        let finalPurchase: Double?
        if let discountedValue = discountedPrice.value {
            finalPurchase = roundPrice(discountedValue)
        } else if let purchaseValue = purchase.value,
                  let discountValue = discount.value {
            finalPurchase = roundPrice(purchaseValue * (1 - discountValue / 100))
        } else {
            finalPurchase = purchase.value.map(roundPrice)
        }

        let finalRetail = retail.value.map(roundPrice)
        if !hasExistingDraft {
            if finalRetail == nil || (finalRetail ?? 0) <= 0 {
                rowErrorKeys.append("import.analysis.row_error.retail_required")
            }
        } else if retail.hasInput, let finalRetail, finalRetail <= 0 {
            rowErrorKeys.append("import.analysis.row_error.retail_positive")
        }

        let draft: ProductDraft
        if let existingDraft {
            draft = ProductDraft(
                barcode: barcode,
                itemNumber: itemNumber ?? existingDraft.itemNumber,
                productName: productName ?? existingDraft.productName,
                secondProductName: secondProductName ?? existingDraft.secondProductName,
                purchasePrice: finalPurchase ?? existingDraft.purchasePrice,
                retailPrice: finalRetail ?? existingDraft.retailPrice,
                stockQuantity: quantity.value ?? existingDraft.stockQuantity,
                oldPurchasePrice: oldPurchase.value,
                oldRetailPrice: oldRetail.value,
                supplierName: supplierName ?? existingDraft.supplierName,
                categoryName: categoryName ?? existingDraft.categoryName
            )
        } else {
            draft = ProductDraft(
                barcode: barcode,
                itemNumber: itemNumber,
                productName: productName ?? secondProductName,
                secondProductName: secondProductName,
                purchasePrice: finalPurchase,
                retailPrice: finalRetail,
                stockQuantity: quantity.value,
                oldPurchasePrice: oldPurchase.value,
                oldRetailPrice: oldRetail.value,
                supplierName: supplierName,
                categoryName: categoryName
            )
        }

        return ParsedDraft(draft: draft, errorKeys: rowErrorKeys)
    }

    private static func mappedRow(header: [String], row: [String]) -> [String: String] {
        var map: [String: String] = [:]

        for (colIndex, rawKey) in header.enumerated() {
            let key = canonicalColumnKey(rawKey)
            guard !key.isEmpty else { continue }

            let raw = colIndex < row.count ? row[colIndex] : ""
            let value = trimImportText(raw)
            guard !value.isEmpty else {
                if map[key] == nil {
                    map[key] = ""
                }
                continue
            }

            if map[key]?.isEmpty ?? true {
                map[key] = value
            }
        }

        return map
    }

    private static func canonicalColumnKey(_ rawKey: String) -> String {
        let key = aliasKey(rawKey)
        if let canonical = columnAliases[key] {
            return canonical
        }
        return rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let columnAliases: [String: String] = [
        "barcode": "barcode",
        "barcod": "barcode",
        "codiceabarre": "barcode",
        "codigobarra": "barcode",
        "codigodebarras": "barcode",
        "ean": "barcode",
        "upc": "barcode",
        "条形码": "barcode",
        "條碼": "barcode",
        "商品条码": "barcode",
        "itemnumber": "itemNumber",
        "articolo": "itemNumber",
        "codicearticolo": "itemNumber",
        "sku": "itemNumber",
        "codigo": "itemNumber",
        "productname": "productName",
        "nomeprodotto": "productName",
        "nombreproducto": "productName",
        "name": "productName",
        "nome": "productName",
        "商品名称": "productName",
        "名称": "productName",
        "secondproductname": "secondProductName",
        "secondname": "secondProductName",
        "nomealternativo": "secondProductName",
        "nombrealternativo": "secondProductName",
        "purchaseprice": "purchasePrice",
        "prezzoacquisto": "purchasePrice",
        "cost": "purchasePrice",
        "costo": "purchasePrice",
        "价格": "purchasePrice",
        "retailprice": "retailPrice",
        "prezzovendita": "retailPrice",
        "sellingprice": "retailPrice",
        "price": "retailPrice",
        "precio": "retailPrice",
        "stockquantity": "stockQuantity",
        "quantity": "quantity",
        "quantita": "quantity",
        "cantidad": "quantity",
        "qty": "quantity",
        "realquantity": "realQuantity",
        "quantitareale": "realQuantity",
        "cantidadreal": "realQuantity",
        "supplier": "supplier",
        "fornitore": "supplier",
        "proveedor": "supplier",
        "供应商": "supplier",
        "category": "category",
        "categoria": "category",
        "分类": "category",
        "discount": "discount",
        "sconto": "discount",
        "descuento": "discount",
        "discountedprice": "discountedPrice",
        "prezzoscontato": "discountedPrice",
        "preciocondescuento": "discountedPrice",
        "oldpurchaseprice": "oldPurchasePrice",
        "prevpurchase": "prevPurchase",
        "previouspurchaseprice": "prevPurchase",
        "prezzoacquistoprecedente": "oldPurchasePrice",
        "oldretailprice": "oldRetailPrice",
        "prevretail": "prevRetail",
        "previousretailprice": "prevRetail",
        "prezzovenditaprecedente": "oldRetailPrice"
    ]

    private static func normalizedExistingProducts(
        _ existingProductsByBarcode: [String: ProductDraft]
    ) -> [String: ProductDraft] {
        var result: [String: ProductDraft] = [:]
        for (barcode, draft) in existingProductsByBarcode {
            let key = normalizedBarcode(from: barcode) ?? barcode
            result[key] = draft
        }
        return result
    }

    private static func quantityValue(in row: [String: String]) -> NumericValue {
        let realQuantity = numeric(row["realQuantity"])
        if let value = realQuantity.value, value > 0 {
            return realQuantity
        }

        let stockQuantity = numeric(row["stockQuantity"])
        if stockQuantity.hasInput || stockQuantity.value != nil {
            return stockQuantity
        }
        return numeric(row["quantity"])
    }

    private static func numeric(_ raw: String?) -> NumericValue {
        let text = trimImportText(raw ?? "")
        return NumericValue(raw: text, value: parseDouble(from: text))
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            if !trimImportText(value ?? "").isEmpty {
                return value
            }
        }
        return nil
    }

    private static func discountPercent(_ raw: String?) -> NumericValue {
        let text = trimImportText(raw ?? "")
        guard let value = parseDouble(from: text) else {
            return NumericValue(raw: text, value: nil)
        }

        let converted: Double
        if !text.contains("%"), value > 0, value < 1 {
            converted = value * 100
        } else {
            converted = value
        }
        return NumericValue(raw: text, value: converted)
    }

    private static func appendInvalidNumericErrors(
        _ validations: [(String, NumericValue)],
        to rowErrorKeys: inout [String]
    ) {
        for (key, value) in validations where value.isInvalid {
            rowErrorKeys.append(key)
        }
    }

    private static func normalizedBarcode(from raw: String?) -> String? {
        var barcode = trimImportText(raw ?? "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
            .replacingOccurrences(of: "\u{2007}", with: "")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard !barcode.isEmpty else { return nil }

        if let expanded = expandScientificBarcode(barcode) {
            return expanded
        }

        if barcode.hasSuffix(".0") || barcode.hasSuffix(",0") {
            barcode.removeLast(2)
        }

        return barcode.isEmpty ? nil : barcode
    }

    private static func expandScientificBarcode(_ raw: String) -> String? {
        guard let exponentIndex = raw.firstIndex(where: { $0 == "e" || $0 == "E" }) else {
            return nil
        }

        let mantissa = String(raw[..<exponentIndex])
        let exponentText = String(raw[raw.index(after: exponentIndex)...])
        guard let exponent = Int(exponentText) else { return nil }

        let separatorIndex = mantissa.lastIndex(where: { $0 == "." || $0 == "," })
        let digitsBeforeSeparator: Int
        let digits: String
        if let separatorIndex {
            digitsBeforeSeparator = mantissa[..<separatorIndex].filter(\.isNumber).count
            digits = mantissa.filter(\.isNumber).map(String.init).joined()
        } else {
            digitsBeforeSeparator = mantissa.filter(\.isNumber).count
            digits = mantissa.filter(\.isNumber).map(String.init).joined()
        }

        guard !digits.isEmpty else { return nil }
        let decimalIndex = digitsBeforeSeparator + exponent
        if decimalIndex >= digits.count {
            return digits + String(repeating: "0", count: decimalIndex - digits.count)
        }
        if decimalIndex > 0 {
            let split = digits.index(digits.startIndex, offsetBy: decimalIndex)
            let fractional = digits[split...]
            guard fractional.allSatisfy({ $0 == "0" }) else { return nil }
            return String(digits[..<split])
        }
        return nil
    }

    private static func normalizeNumberString(_ raw: String) -> String {
        if let exponentIndex = raw.firstIndex(where: { $0 == "e" || $0 == "E" }) {
            let mantissa = String(raw[..<exponentIndex])
            let exponent = raw[exponentIndex...]
            return normalizeDecimalMantissa(mantissa) + exponent
        }
        return normalizeDecimalMantissa(raw)
    }

    private static func normalizeDecimalMantissa(_ raw: String) -> String {
        let commaCount = raw.count(where: { $0 == "," })
        let dotCount = raw.count(where: { $0 == "." })

        guard commaCount > 0 || dotCount > 0 else { return raw }

        if commaCount > 0, dotCount > 0 {
            let decimalSeparator: Character = (raw.lastIndex(of: ",") ?? raw.startIndex) > (raw.lastIndex(of: ".") ?? raw.startIndex) ? "," : "."
            let groupingSeparator: Character = decimalSeparator == "," ? "." : ","
            return raw
                .filter { $0 != groupingSeparator }
                .map { $0 == decimalSeparator ? "." : String($0) }
                .joined()
        }

        let separator: Character = commaCount > 0 ? "," : "."
        let separatorCount = commaCount > 0 ? commaCount : dotCount
        let parts = raw.split(separator: separator, omittingEmptySubsequences: false)
        guard separatorCount == 1 else {
            guard let last = parts.last else { return raw.filter { $0 != separator } }
            if last.count == 3 {
                return raw.filter { $0 != separator }
            }
            return parts.dropLast().joined() + "." + last
        }

        guard parts.count == 2 else { return raw }
        let integerPart = parts[0]
        let fractionalPart = parts[1]
        if fractionalPart.count == 3, integerPart.count > 3 {
            return raw.filter { $0 != separator }
        }
        return String(integerPart) + "." + String(fractionalPart)
    }

    private static func aliasKey(_ raw: String) -> String {
        trimImportText(raw)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .filter { $0.isLetter || $0.isNumber || isCJKScalar($0) }
    }

    private static func isCJKScalar(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }

    private static func trimImportText(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\u{200B}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{2007}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    private static func decimalString(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value)
    }

    private static func roundPrice(_ value: Double) -> Double {
        (value * 1000).rounded() / 1000
    }

    private static func doublesEqual(_ lhs: Double?, _ rhs: Double?, epsilon: Double = 0.0001) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (left?, right?):
            return abs(left - right) < epsilon
        default:
            return false
        }
    }

    private static func hasPriceHistory(
        product: Product,
        type: PriceType,
        price: Double,
        source: String
    ) -> Bool {
        product.priceHistory.contains { history in
            history.type == type
                && abs(history.price - price) < 0.0001
                && history.source == source
        }
    }

    private static func insertPriceHistory(
        type: PriceType,
        price: Double,
        effectiveAt: Date,
        source: String,
        product: Product,
        in context: ModelContext,
        onPriceHistoryCreated: (ProductPrice) -> Void
    ) -> ProductPrice {
        let history = ProductPrice(
            type: type,
            price: price,
            effectiveAt: effectiveAt,
            source: source,
            note: nil,
            createdAt: Date(),
            product: product
        )
        context.insert(history)
        onPriceHistoryCreated(history)
        return history
    }
}

nonisolated final class ProductImportNamedEntityResolver {
    private let context: ModelContext
    private var suppliersByName: [String: Supplier]
    private var categoriesByName: [String: ProductCategory]
    private var createdSupplierNames: Set<String> = []
    private var createdCategoryNames: Set<String> = []
    private var createdSuppliersByName: [String: Supplier] = [:]
    private var createdCategoriesByName: [String: ProductCategory] = [:]

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
            suppliers.compactMap { supplier in
                guard let key = ProductImportCore.normalizedRelationKey(supplier.name) else {
                    return nil
                }
                return (key, supplier)
            },
            uniquingKeysWith: { first, _ in first }
        )

        categoriesByName = Dictionary(
            categories.compactMap { category in
                guard let key = ProductImportCore.normalizedRelationKey(category.name) else {
                    return nil
                }
                return (key, category)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var suppliersCreatedCount: Int {
        createdSupplierNames.count
    }

    var categoriesCreatedCount: Int {
        createdCategoryNames.count
    }

    var createdSuppliers: [Supplier] {
        createdSuppliersByName.values.sorted { $0.name < $1.name }
    }

    var createdCategories: [ProductCategory] {
        createdCategoriesByName.values.sorted { $0.name < $1.name }
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
        guard let normalizedName = ProductImportCore.normalizedDisplayName(rawName),
              let key = ProductImportCore.normalizedRelationKey(normalizedName) else {
            return nil
        }

        if let existing = suppliersByName[key] {
            return existing
        }

        let supplier = Supplier(name: normalizedName)
        context.insert(supplier)
        suppliersByName[key] = supplier
        createdSupplierNames.insert(key)
        createdSuppliersByName[key] = supplier
        return supplier
    }

    func resolveCategory(named rawName: String?) -> ProductCategory? {
        guard let normalizedName = ProductImportCore.normalizedDisplayName(rawName),
              let key = ProductImportCore.normalizedRelationKey(normalizedName) else {
            return nil
        }

        if let existing = categoriesByName[key] {
            return existing
        }

        let category = ProductCategory(name: normalizedName)
        context.insert(category)
        categoriesByName[key] = category
        createdCategoryNames.insert(key)
        createdCategoriesByName[key] = category
        return category
    }
}
