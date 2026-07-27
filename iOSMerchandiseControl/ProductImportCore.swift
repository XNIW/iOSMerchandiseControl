import Foundation
import SwiftData

nonisolated enum AndroidImportKey {
    static let barcode = "barcode"
    static let productName = "productName"
    static let itemNumber = "itemNumber"
    static let purchasePrice = "purchasePrice"
    static let retailPrice = "retailPrice"
    static let quantity = "quantity"
    static let supplier = "supplier"
    static let category = "category"
    static let secondProductName = "secondProductName"
    static let totalPrice = "totalPrice"
    static let rowNumber = "rowNumber"
    static let discount = "discount"
    static let discountedPrice = "discountedPrice"
    static let oldPurchasePrice = "oldPurchasePrice"
    static let oldRetailPrice = "oldRetailPrice"
    static let realQuantity = "realQuantity"
    static let complete = "complete"

    static let allKeys: Set<String> = [
        barcode,
        productName,
        itemNumber,
        purchasePrice,
        retailPrice,
        quantity,
        supplier,
        category,
        secondProductName,
        totalPrice,
        rowNumber,
        discount,
        discountedPrice,
        oldPurchasePrice,
        oldRetailPrice,
        realQuantity,
        complete
    ]
}

nonisolated enum ProductImportCore {
    private static let currentImportSource = "IMPORT_EXCEL"
    private static let previousImportSource = "IMPORT_PREV"

    private struct PendingRow {
        var barcode: String
        var rawBarcodeIdentity: String
        var lastRow: [String: String]
        var rowNumbers: [Int]
    }

    private struct CanonicalImportRow {
        let values: [String: String]
        let normalizationFields: [ProductImportFieldNormalization]
        let rejectionKeys: [String]
    }

    private struct ParsedDraft {
        let draft: ProductDraft
        let errorKeys: [String]
        let recoverableErrorKeys: [String]
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

    static func calculatedRetailPrice(
        purchasePrice: Double?,
        markupPercent: Double,
        roundingStep: Double
    ) -> Double? {
        guard let purchasePrice, purchasePrice > 0 else { return nil }

        let unrounded = purchasePrice * (1 + markupPercent / 100)
        guard roundingStep > 0 else {
            return unrounded
        }

        return (unrounded / roundingStep).rounded() * roundingStep
    }

    @discardableResult
    static func applyRetailMarkup(
        to drafts: inout [ProductDraft],
        markupPercent: Double,
        roundingStep: Double,
        onlyEmptyRetailPrice: Bool
    ) -> Int {
        var changedCount = 0

        for index in drafts.indices {
            if onlyEmptyRetailPrice, drafts[index].retailPrice != nil {
                continue
            }

            guard let retailPrice = calculatedRetailPrice(
                purchasePrice: drafts[index].purchasePrice,
                markupPercent: markupPercent,
                roundingStep: roundingStep
            ) else {
                continue
            }

            drafts[index].retailPrice = retailPrice
            changedCount += 1
        }

        return changedCount
    }

    @discardableResult
    static func applyRetailMarkup(
        to updates: inout [ProductUpdateDraft],
        markupPercent: Double,
        roundingStep: Double,
        onlyEmptyRetailPrice: Bool
    ) -> Int {
        var changedCount = 0

        for index in updates.indices {
            if onlyEmptyRetailPrice, updates[index].new.retailPrice != nil {
                continue
            }

            guard let retailPrice = calculatedRetailPrice(
                purchasePrice: updates[index].new.purchasePrice,
                markupPercent: markupPercent,
                roundingStep: roundingStep
            ) else {
                continue
            }

            updates[index].new.retailPrice = retailPrice
            updates[index].changedFields = ProductUpdateDraft.computeChangedFields(
                old: updates[index].old,
                new: updates[index].new
            )
            changedCount += 1
        }

        return changedCount
    }

    static func analyzeImport(
        header: [String],
        dataRows: [[String]],
        existingProductsByBarcode: [String: ProductDraft]
    ) -> ProductImportAnalysisResult {
        var errors: [ProductImportRowError] = []
        var pendingByBarcode: [String: PendingRow] = [:]
        var normalizationWarnings: [ProductImportNormalizationWarning] = []
        var collidedBarcodeKeys: Set<String> = []
        let existingByBarcode = normalizedExistingProducts(existingProductsByBarcode)

        for (index, row) in dataRows.enumerated() {
            let rawMap = mappedRow(header: header, row: row)
            let rowNumber = importRowNumber(
                from: rawMap[AndroidImportKey.rowNumber],
                fallback: index + 1
            )
            let canonicalRow = canonicalizeCatalogFields(in: rawMap)
            var map = canonicalRow.values

            if !canonicalRow.normalizationFields.isEmpty {
                normalizationWarnings.append(
                    ProductImportNormalizationWarning(
                        rowNumber: rowNumber,
                        fields: canonicalRow.normalizationFields
                    )
                )
            }

            if !canonicalRow.rejectionKeys.isEmpty {
                errors.append(
                    ProductImportRowError(
                        rowNumber: rowNumber,
                        reasonKeys: canonicalRow.rejectionKeys,
                        rowContent: map,
                        blocksApply: true
                    )
                )
                continue
            }

            guard let strictBarcode = optionalNonEmpty(map[AndroidImportKey.barcode]) else {
                errors.append(
                    ProductImportRowError(
                        rowNumber: rowNumber,
                        reasonKey: "import.analysis.row_error.barcode_missing",
                        rowContent: map,
                        blocksApply: true
                    )
                )
                continue
            }
            let barcode: String
            switch spreadsheetDecodedBarcode(strictBarcode) {
            case let .value(decodedBarcode):
                barcode = decodedBarcode
                map[AndroidImportKey.barcode] = decodedBarcode
            case let .rejected(reason):
                map[AndroidImportKey.barcode] =
                    "[catalog-text:\(reason.rawValue)]"
                errors.append(
                    ProductImportRowError(
                        rowNumber: rowNumber,
                        reasonKeys: [reason.localizationKey],
                        rowContent: map,
                        blocksApply: true
                    )
                )
                continue
            }

            let barcodeKey = strictIdentityKey(barcode)
            guard !collidedBarcodeKeys.contains(barcodeKey) else {
                errors.append(
                    ProductImportRowError(
                        rowNumber: rowNumber,
                        reasonKey: CatalogTextRejectionReason
                            .identityCollisionAfterTrim.localizationKey,
                        rowContent: map,
                        blocksApply: true
                    )
                )
                continue
            }

            let rawBarcodeIdentity = strictIdentityKey(
                rawMap[AndroidImportKey.barcode] ?? ""
            )
            if var pending = pendingByBarcode[barcodeKey] {
                if pending.rawBarcodeIdentity != rawBarcodeIdentity {
                    collidedBarcodeKeys.insert(barcodeKey)
                    pendingByBarcode.removeValue(forKey: barcodeKey)
                    errors.append(
                        ProductImportRowError(
                            rowNumber: rowNumber,
                            reasonKey: CatalogTextRejectionReason
                                .identityCollisionAfterTrim.localizationKey,
                            rowContent: map,
                            blocksApply: true
                        )
                    )
                    continue
                }
                pending.lastRow = map
                pending.rowNumbers.append(rowNumber)
                pendingByBarcode[barcodeKey] = pending
            } else {
                pendingByBarcode[barcodeKey] = PendingRow(
                    barcode: barcode,
                    rawBarcodeIdentity: rawBarcodeIdentity,
                    lastRow: map,
                    rowNumbers: [rowNumber]
                )
            }
        }

        var newProducts: [ProductDraft] = []
        var updates: [ProductUpdateDraft] = []
        var warnings: [ProductDuplicateWarning] = []

        for (_, pending) in pendingByBarcode.sorted(by: { $0.key < $1.key }) {
            let barcode = pending.barcode
            let row = pending.lastRow

            if pending.rowNumbers.count > 1 {
                warnings.append(
                    ProductDuplicateWarning(
                        barcode: barcode,
                        rowNumbers: pending.rowNumbers
                    )
                )
            }

            let oldDraft = existingByBarcode[strictIdentityKey(barcode)]
            let parsed = parseProductDraft(
                barcode: barcode,
                row: row,
                existingDraft: oldDraft
            )
            let recoverableErrorKeys = Set(parsed.recoverableErrorKeys)
            let blockingErrorKeys = parsed.errorKeys.filter {
                !recoverableErrorKeys.contains($0)
            }

            if !parsed.errorKeys.isEmpty {
                errors.append(
                    ProductImportRowError(
                        rowNumber: pending.rowNumbers.last ?? pending.rowNumbers[0],
                        reasonKeys: parsed.errorKeys,
                        rowContent: row
                    )
                )
                if !blockingErrorKeys.isEmpty {
                    continue
                }
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
            normalizationWarnings: normalizationWarnings,
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
    ) throws -> Product {
        let draft = try validatedDraft(draft)
        let product = Product(
            barcode: draft.barcode,
            itemNumber: draft.itemNumber,
            productName: draft.productName,
            secondProductName: draft.secondProductName,
            purchasePrice: draft.purchasePrice,
            retailPrice: draft.retailPrice,
            stockQuantity: draft.stockQuantity,
            supplier: try resolver.resolveSupplier(named: draft.supplierName),
            category: try resolver.resolveCategory(named: draft.categoryName)
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
    ) throws -> [ProductPrice] {
        let newDraft = try validatedDraft(update.new)
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
            product.supplier = try resolver.resolveSupplier(named: newDraft.supplierName)
        }
        if update.changedFields.contains(.categoryName) {
            product.category = try resolver.resolveCategory(named: newDraft.categoryName)
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
        guard let rawName else { return nil }
        return CatalogTextPolicy.display(
            rawName,
            required: false,
            maximumUTF16Length: CatalogTextField.productName.maximumUTF16Length
        ).value.flatMap(optionalNonEmpty)
    }

    private static func parseProductDraft(
        barcode: String,
        row: [String: String],
        existingDraft: ProductDraft?
    ) -> ParsedDraft {
        var rowErrorKeys: [String] = []
        var recoverableErrorKeys: [String] = []

        let itemNumber = optionalNonEmpty(row[AndroidImportKey.itemNumber])
        let productName = optionalNonEmpty(row[AndroidImportKey.productName])
        let secondProductName = optionalNonEmpty(row[AndroidImportKey.secondProductName])
        let supplierName = optionalNonEmpty(row[AndroidImportKey.supplier])
        let categoryName = optionalNonEmpty(row[AndroidImportKey.category])
        let hasExistingDraft: Bool
        switch existingDraft {
        case .some:
            hasExistingDraft = true
        case .none:
            hasExistingDraft = false
        }

        if productName == nil && itemNumber == nil && secondProductName == nil && !hasExistingDraft {
            rowErrorKeys.append("import.analysis.row_error.product_name_missing")
        }

        let purchase = numeric(row[AndroidImportKey.purchasePrice])
        let retail = numeric(row[AndroidImportKey.retailPrice])
        let discountedPrice = numeric(row[AndroidImportKey.discountedPrice])
        let discount = discountPercent(row[AndroidImportKey.discount])
        let quantity = quantityValue(in: row)
        let oldPurchase = numeric(row[AndroidImportKey.oldPurchasePrice])
        let oldRetail = numeric(row[AndroidImportKey.oldRetailPrice])

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
                let key = "import.analysis.row_error.retail_required"
                rowErrorKeys.append(key)
                if !retail.hasInput {
                    recoverableErrorKeys.append(key)
                }
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

        return ParsedDraft(
            draft: draft,
            errorKeys: rowErrorKeys,
            recoverableErrorKeys: recoverableErrorKeys
        )
    }

    private static let catalogFieldKeys: Set<String> = [
        AndroidImportKey.barcode,
        AndroidImportKey.itemNumber,
        AndroidImportKey.productName,
        AndroidImportKey.secondProductName,
        AndroidImportKey.supplier,
        AndroidImportKey.category
    ]

    private static func canonicalizeCatalogFields(
        in rawValues: [String: String]
    ) -> CanonicalImportRow {
        var values = rawValues
        var normalizationFields: [ProductImportFieldNormalization] = []
        var rejectionKeys: [String] = []

        let specifications: [
            (key: String, display: Bool, required: Bool, maximumUTF16Length: Int)
        ] = [
            (
                AndroidImportKey.barcode,
                false,
                true,
                CatalogTextField.barcode.maximumUTF16Length
            ),
            (
                AndroidImportKey.itemNumber,
                false,
                false,
                CatalogTextField.itemNumber.maximumUTF16Length
            ),
            (
                AndroidImportKey.productName,
                true,
                false,
                CatalogTextField.productName.maximumUTF16Length
            ),
            (
                AndroidImportKey.secondProductName,
                true,
                false,
                CatalogTextField.secondProductName.maximumUTF16Length
            ),
            (
                AndroidImportKey.supplier,
                true,
                false,
                CatalogTextField.supplierName.maximumUTF16Length
            ),
            (
                AndroidImportKey.category,
                true,
                false,
                CatalogTextField.categoryName.maximumUTF16Length
            )
        ]

        for specification in specifications {
            let rawValue = rawValues[specification.key] ?? ""
            let outcome = specification.display
                ? CatalogTextPolicy.display(
                    rawValue,
                    required: specification.required,
                    maximumUTF16Length: specification.maximumUTF16Length
                )
                : CatalogTextPolicy.strict(
                    rawValue,
                    required: specification.required,
                    maximumUTF16Length: specification.maximumUTF16Length
                )

            switch outcome {
            case let .unchanged(value):
                values[specification.key] = value
            case let .normalized(value, changes):
                values[specification.key] = value
                normalizationFields.append(
                    ProductImportFieldNormalization(
                        fieldKey: specification.key,
                        changes: changes
                    )
                )
            case let .rejected(reason):
                values[specification.key] = "[catalog-text:\(reason.rawValue)]"
                if specification.key == AndroidImportKey.barcode,
                   reason == .emptyRequired {
                    rejectionKeys.append("import.analysis.row_error.barcode_missing")
                } else {
                    rejectionKeys.append(reason.localizationKey)
                }
            }
        }

        return CanonicalImportRow(
            values: values,
            normalizationFields: normalizationFields,
            rejectionKeys: rejectionKeys
        )
    }

    static func validatedDraft(_ draft: ProductDraft) throws -> ProductDraft {
        let barcode = try CatalogTextPolicy.validate(draft.barcode, for: .barcode).value
        let itemNumber = try validateOptional(
            draft.itemNumber,
            display: false,
            maximumUTF16Length: CatalogTextField.itemNumber.maximumUTF16Length,
            field: .itemNumber
        )
        let productName = try validateOptional(
            draft.productName,
            display: true,
            maximumUTF16Length: CatalogTextField.productName.maximumUTF16Length,
            field: .productName
        )
        let secondProductName = try validateOptional(
            draft.secondProductName,
            display: true,
            maximumUTF16Length: CatalogTextField.secondProductName.maximumUTF16Length,
            field: .secondProductName
        )
        let supplierName = try validateOptional(
            draft.supplierName,
            display: true,
            maximumUTF16Length: CatalogTextField.supplierName.maximumUTF16Length,
            field: .supplierName
        )
        let categoryName = try validateOptional(
            draft.categoryName,
            display: true,
            maximumUTF16Length: CatalogTextField.categoryName.maximumUTF16Length,
            field: .categoryName
        )

        return ProductDraft(
            barcode: barcode,
            itemNumber: itemNumber,
            productName: productName,
            secondProductName: secondProductName,
            purchasePrice: draft.purchasePrice,
            retailPrice: draft.retailPrice,
            stockQuantity: draft.stockQuantity,
            oldPurchasePrice: draft.oldPurchasePrice,
            oldRetailPrice: draft.oldRetailPrice,
            supplierName: supplierName,
            categoryName: categoryName
        )
    }

    private static func validateOptional(
        _ rawValue: String?,
        display: Bool,
        maximumUTF16Length: Int,
        field: CatalogTextField
    ) throws -> String? {
        guard let rawValue else { return nil }
        let outcome = display
            ? CatalogTextPolicy.display(
                rawValue,
                required: false,
                maximumUTF16Length: maximumUTF16Length
            )
            : CatalogTextPolicy.strict(
                rawValue,
                required: false,
                maximumUTF16Length: maximumUTF16Length
            )

        switch outcome {
        case let .unchanged(value), let .normalized(value, _):
            return optionalNonEmpty(value)
        case let .rejected(reason):
            throw CatalogTextValidationError(field: field, reason: reason)
        }
    }

    private static func optionalNonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    static func strictIdentityKey(_ value: String) -> String {
        value.unicodeScalars
            .map { String($0.value, radix: 16, uppercase: true) }
            .joined(separator: ".")
    }

    private static func mappedRow(header: [String], row: [String]) -> [String: String] {
        var map: [String: String] = [:]

        for (colIndex, rawKey) in header.enumerated() {
            let key = canonicalColumnKey(rawKey)
            guard !key.isEmpty else { continue }

            let raw = colIndex < row.count ? row[colIndex] : ""
            let value = catalogFieldKeys.contains(key) ? raw : trimImportText(raw)
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

    private static func importRowNumber(from rawValue: String?, fallback: Int) -> Int {
        guard let rawValue,
              let parsed = parseDouble(from: rawValue),
              parsed.isFinite else {
            return fallback
        }

        return Int(parsed.rounded())
    }

    private static func canonicalColumnKey(_ rawKey: String) -> String {
        let trimmed = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if AndroidImportKey.allKeys.contains(trimmed) {
            return trimmed
        }

        let key = aliasKey(rawKey)
        if let canonical = columnAliases[key] {
            return canonical
        }
        return ""
    }

    private static let columnAliases: [String: String] = [
        "barcode": AndroidImportKey.barcode,
        "barcod": AndroidImportKey.barcode,
        "codiceabarre": AndroidImportKey.barcode,
        "codigobarra": AndroidImportKey.barcode,
        "codigodebarras": AndroidImportKey.barcode,
        "ean": AndroidImportKey.barcode,
        "upc": AndroidImportKey.barcode,
        "条形码": AndroidImportKey.barcode,
        "條碼": AndroidImportKey.barcode,
        "商品条码": AndroidImportKey.barcode,
        "itemnumber": AndroidImportKey.itemNumber,
        "articolo": AndroidImportKey.itemNumber,
        "codicearticolo": AndroidImportKey.itemNumber,
        "sku": AndroidImportKey.itemNumber,
        "ref": AndroidImportKey.itemNumber,
        "codigo": AndroidImportKey.itemNumber,
        "productname": AndroidImportKey.productName,
        "nomeprodotto": AndroidImportKey.productName,
        "nombreproducto": AndroidImportKey.productName,
        "name": AndroidImportKey.productName,
        "nome": AndroidImportKey.productName,
        "商品名称": AndroidImportKey.productName,
        "名称": AndroidImportKey.productName,
        "secondproductname": AndroidImportKey.secondProductName,
        "secondname": AndroidImportKey.secondProductName,
        "nomealternativo": AndroidImportKey.secondProductName,
        "nombrealternativo": AndroidImportKey.secondProductName,
        "purchaseprice": AndroidImportKey.purchasePrice,
        "prezzoacquisto": AndroidImportKey.purchasePrice,
        "cost": AndroidImportKey.purchasePrice,
        "costo": AndroidImportKey.purchasePrice,
        "价格": AndroidImportKey.purchasePrice,
        "retailprice": AndroidImportKey.retailPrice,
        "prezzovendita": AndroidImportKey.retailPrice,
        "sellingprice": AndroidImportKey.retailPrice,
        "price": AndroidImportKey.retailPrice,
        "precio": AndroidImportKey.retailPrice,
        "stockquantity": AndroidImportKey.quantity,
        "quantity": AndroidImportKey.quantity,
        "quantita": AndroidImportKey.quantity,
        "cantidad": AndroidImportKey.quantity,
        "qty": AndroidImportKey.quantity,
        "realquantity": AndroidImportKey.realQuantity,
        "quantitareale": AndroidImportKey.realQuantity,
        "cantidadreal": AndroidImportKey.realQuantity,
        "supplier": AndroidImportKey.supplier,
        "suppliername": AndroidImportKey.supplier,
        "fornitore": AndroidImportKey.supplier,
        "proveedor": AndroidImportKey.supplier,
        "供应商": AndroidImportKey.supplier,
        "category": AndroidImportKey.category,
        "categoryname": AndroidImportKey.category,
        "categoria": AndroidImportKey.category,
        "分类": AndroidImportKey.category,
        "discount": AndroidImportKey.discount,
        "sconto": AndroidImportKey.discount,
        "descuento": AndroidImportKey.discount,
        "discountedprice": AndroidImportKey.discountedPrice,
        "prezzoscontato": AndroidImportKey.discountedPrice,
        "preciocondescuento": AndroidImportKey.discountedPrice,
        "oldpurchaseprice": AndroidImportKey.oldPurchasePrice,
        "prevpurchase": AndroidImportKey.oldPurchasePrice,
        "previouspurchaseprice": AndroidImportKey.oldPurchasePrice,
        "prezzoacquistoprecedente": AndroidImportKey.oldPurchasePrice,
        "oldretailprice": AndroidImportKey.oldRetailPrice,
        "prevretail": AndroidImportKey.oldRetailPrice,
        "previousretailprice": AndroidImportKey.oldRetailPrice,
        "prezzovenditaprecedente": AndroidImportKey.oldRetailPrice
    ]

    private static func normalizedExistingProducts(
        _ existingProductsByBarcode: [String: ProductDraft]
    ) -> [String: ProductDraft] {
        var result: [String: ProductDraft] = [:]
        for (barcode, draft) in existingProductsByBarcode {
            guard let canonical = CatalogTextPolicy.strict(
                barcode,
                required: true,
                maximumUTF16Length: CatalogTextField.barcode.maximumUTF16Length
            ).value else {
                continue
            }
            result[strictIdentityKey(canonical)] = draft
        }
        return result
    }

    // Excel può consegnare una cella barcode numerica in notazione scientifica
    // o con una sola coda decimale ".0". Questo è decoding del tipo cella,
    // eseguito esclusivamente dopo la validazione strict del testo: control,
    // whitespace interno, zero-width, BOM e bidi non vengono mai rimossi.
    private enum SpreadsheetBarcodeDecodeResult {
        case value(String)
        case rejected(CatalogTextRejectionReason)
    }

    private enum ScientificBarcodeExpansionResult {
        case notScientific
        case expanded(String)
        case rejected(CatalogTextRejectionReason)
    }

    private enum BoundedUnsignedInteger {
        case value(Int)
        case exceedsLimit
        case invalid
    }

    private static func spreadsheetDecodedBarcode(
        _ value: String
    ) -> SpreadsheetBarcodeDecodeResult {
        let decoded: String
        switch expandScientificSpreadsheetBarcode(value) {
        case let .expanded(expanded):
            decoded = expanded
        case let .rejected(reason):
            return .rejected(reason)
        case .notScientific:
            if value.hasSuffix(".0") || value.hasSuffix(",0") {
                decoded = String(value.dropLast(2))
            } else {
                decoded = value
            }
        }

        switch CatalogTextPolicy.strict(
            decoded,
            required: true,
            maximumUTF16Length: CatalogTextField.barcode.maximumUTF16Length
        ) {
        case let .unchanged(canonical), let .normalized(canonical, _):
            return .value(canonical)
        case let .rejected(reason):
            return .rejected(reason)
        }
    }

    private static func expandScientificSpreadsheetBarcode(
        _ raw: String
    ) -> ScientificBarcodeExpansionResult {
        guard let exponentIndex = raw.firstIndex(where: { $0 == "e" || $0 == "E" }) else {
            return .notScientific
        }

        let mantissa = String(raw[..<exponentIndex])
        var exponentText = raw[raw.index(after: exponentIndex)...]
        let isNegativeExponent = exponentText.first == "-"
        if exponentText.first == "+" || isNegativeExponent {
            exponentText = exponentText.dropFirst()
        }
        guard !exponentText.isEmpty else { return .notScientific }

        var digits = ""
        digits.reserveCapacity(mantissa.utf8.count)
        var digitsBeforeSeparator = 0
        var sawSeparator = false
        for scalar in mantissa.unicodeScalars {
            switch scalar.value {
            case 0x30...0x39:
                digits.unicodeScalars.append(scalar)
                if !sawSeparator {
                    digitsBeforeSeparator += 1
                }
            case 0x2E, 0x2C:
                guard !sawSeparator else { return .notScientific }
                sawSeparator = true
            default:
                return .notScientific
            }
        }
        guard !digits.isEmpty else { return .notScientific }

        let maximumLength = CatalogTextField.barcode.maximumUTF16Length
        let exponentLimit = isNegativeExponent
            ? digitsBeforeSeparator
            : max(0, maximumLength - digitsBeforeSeparator)
        let exponentMagnitude: Int
        switch boundedUnsignedInteger(exponentText, limit: exponentLimit) {
        case let .value(value):
            exponentMagnitude = value
        case .exceedsLimit:
            return isNegativeExponent ? .notScientific : .rejected(.tooLong)
        case .invalid:
            return .notScientific
        }

        if isNegativeExponent {
            let decimalIndex = digitsBeforeSeparator - exponentMagnitude
            guard decimalIndex > 0 else { return .notScientific }
            let split = digits.index(digits.startIndex, offsetBy: decimalIndex)
            let fractional = digits[split...]
            guard fractional.allSatisfy({ $0 == "0" }) else {
                return .notScientific
            }
            return .expanded(String(digits[..<split]))
        }

        let decimalIndex = digitsBeforeSeparator + exponentMagnitude
        if decimalIndex >= digits.count {
            let zeroCount = decimalIndex - digits.count
            guard digits.count + zeroCount <= maximumLength else {
                return .rejected(.tooLong)
            }
            return .expanded(
                digits + String(repeating: "0", count: zeroCount)
            )
        }

        let split = digits.index(digits.startIndex, offsetBy: decimalIndex)
        let fractional = digits[split...]
        guard fractional.allSatisfy({ $0 == "0" }) else {
            return .notScientific
        }
        return .expanded(String(digits[..<split]))
    }

    private static func boundedUnsignedInteger(
        _ raw: Substring,
        limit: Int
    ) -> BoundedUnsignedInteger {
        var value = 0
        for scalar in raw.unicodeScalars {
            guard scalar.value >= 0x30, scalar.value <= 0x39 else {
                return .invalid
            }
            let digit = Int(scalar.value - 0x30)
            guard value < limit / 10
                    || (value == limit / 10 && digit <= limit % 10) else {
                return .exceedsLimit
            }
            value = value * 10 + digit
        }
        return .value(value)
    }

    private static func quantityValue(in row: [String: String]) -> NumericValue {
        let realQuantity = numeric(row[AndroidImportKey.realQuantity])
        if realQuantity.hasInput {
            return realQuantity
        }
        return numeric(row[AndroidImportKey.quantity])
    }

    private static func numeric(_ raw: String?) -> NumericValue {
        let text = trimImportText(raw ?? "")
        return NumericValue(raw: text, value: parseDouble(from: text))
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
    private var tombstonedSupplierNames: Set<String> = []
    private var tombstonedCategoryNames: Set<String> = []

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

        tombstonedSupplierNames = Set(suppliers.compactMap { supplier in
            guard supplier.remoteDeletedAt != nil else { return nil }
            return ProductImportCore.normalizedRelationKey(supplier.name)
        })
        tombstonedCategoryNames = Set(categories.compactMap { category in
            guard category.remoteDeletedAt != nil else { return nil }
            return ProductImportCore.normalizedRelationKey(category.name)
        })

        suppliersByName = Dictionary(
            suppliers.compactMap { supplier in
                guard supplier.remoteDeletedAt == nil else { return nil }
                guard let key = ProductImportCore.normalizedRelationKey(supplier.name) else {
                    return nil
                }
                return (key, supplier)
            },
            uniquingKeysWith: { first, _ in first }
        )

        categoriesByName = Dictionary(
            categories.compactMap { category in
                guard category.remoteDeletedAt == nil else { return nil }
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

    func preloadSuppliers(named names: [String]) throws {
        for name in names {
            _ = try resolveSupplier(named: name)
        }
    }

    func preloadCategories(named names: [String]) throws {
        for name in names {
            _ = try resolveCategory(named: name)
        }
    }

    func resolveSupplier(named rawName: String?) throws -> Supplier? {
        guard let normalizedName = try CatalogTextPersistenceBoundary.validatedOptionalDisplay(
            rawName,
            field: .supplierName
        ),
              let key = ProductImportCore.normalizedRelationKey(normalizedName) else {
            return nil
        }

        if let existing = suppliersByName[key] {
            return existing
        }
        guard !tombstonedSupplierNames.contains(key) else {
            throw ProductImportNamedEntityResolverError.tombstonedRelation
        }

        let supplier = Supplier(name: normalizedName)
        context.insert(supplier)
        suppliersByName[key] = supplier
        createdSupplierNames.insert(key)
        createdSuppliersByName[key] = supplier
        return supplier
    }

    func resolveCategory(named rawName: String?) throws -> ProductCategory? {
        guard let normalizedName = try CatalogTextPersistenceBoundary.validatedOptionalDisplay(
            rawName,
            field: .categoryName
        ),
              let key = ProductImportCore.normalizedRelationKey(normalizedName) else {
            return nil
        }

        if let existing = categoriesByName[key] {
            return existing
        }
        guard !tombstonedCategoryNames.contains(key) else {
            throw ProductImportNamedEntityResolverError.tombstonedRelation
        }

        let category = ProductCategory(name: normalizedName)
        context.insert(category)
        categoriesByName[key] = category
        createdCategoryNames.insert(key)
        createdCategoriesByName[key] = category
        return category
    }
}

nonisolated enum ProductImportNamedEntityResolverError: Error, Equatable, Sendable {
    case tombstonedRelation
}
