import SwiftUI
import SwiftData

struct EditProductView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let existingProduct: Product?
    let pendingOwnerUserID: UUID?

    @Query(sort: \Supplier.name, order: .forward)
    private var suppliers: [Supplier]

    @Query(sort: \ProductCategory.name, order: .forward)
    private var categories: [ProductCategory]

    @State private var barcode: String
    @State private var name: String
    @State private var secondName: String
    @State private var itemNumber: String
    @State private var purchasePrice: String
    @State private var retailPrice: String
    @State private var stockQuantity: String
    @State private var supplierName: String
    @State private var categoryName: String
    @State private var validationMessage: String?

    init(product: Product? = nil, initialBarcode: String? = nil, pendingOwnerUserID: UUID? = nil) {
        self.existingProduct = product
        self.pendingOwnerUserID = pendingOwnerUserID

        let initialCode = product?.barcode ?? initialBarcode ?? ""

        _barcode = State(initialValue: initialCode)
        _name = State(initialValue: product?.productName ?? "")
        _secondName = State(initialValue: product?.secondProductName ?? "")
        _itemNumber = State(initialValue: product?.itemNumber ?? "")
        _purchasePrice = State(initialValue: product?.purchasePrice.map { Self.format(number: $0) } ?? "")
        _retailPrice = State(initialValue: product?.retailPrice.map { Self.format(number: $0) } ?? "")
        _stockQuantity = State(initialValue: product?.stockQuantity.map { Self.format(number: $0) } ?? "")
        _supplierName = State(initialValue: product?.supplier?.name ?? "")
        _categoryName = State(initialValue: product?.category?.name ?? "")
    }

    private static func format(number: Double) -> String {
        let intPart = floor(number)
        if number == intPart {
            return String(Int(intPart))
        } else {
            return String(number)
        }
    }

    private var trimmedBarcode: String {
        barcode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Form {
            if let validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section(L("product.section.main")) {
                TextField(L("product.field.barcode"), text: $barcode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .submitLabel(.next)

                TextField(L("product.field.item_number"), text: $itemNumber)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)

                TextField(L("product.field.name"), text: $name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)

                TextField(L("product.field.second_name"), text: $secondName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
            }

            Section(L("product.section.warehouse")) {
                TextField(L("product.field.stock_quantity"), text: $stockQuantity)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
            }

            Section(L("product.section.prices")) {
                TextField(L("product.field.purchase_price"), text: $purchasePrice)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()

                TextField(L("product.field.retail_price"), text: $retailPrice)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
            }

            Section(L("product.section.supplier")) {
                TextField(L("product.field.supplier_name"), text: $supplierName)
                    .textInputAutocapitalization(.words)

                if !suppliers.isEmpty {
                    Menu {
                        ForEach(suppliers) { supplier in
                            Button(supplier.name) {
                                supplierName = supplier.name
                            }
                        }
                    } label: {
                        Label(L("product.action.select_existing"), systemImage: "building.2")
                    }
                }
            }

            Section(L("product.section.category")) {
                TextField(L("product.field.category_name"), text: $categoryName)
                    .textInputAutocapitalization(.words)

                if !categories.isEmpty {
                    Menu {
                        ForEach(categories) { category in
                            Button(category.name) {
                                categoryName = category.name
                            }
                        }
                    } label: {
                        Label(L("product.action.select_existing"), systemImage: "tag")
                    }
                }
            }
        }
        .navigationTitle(existingProduct == nil ? L("product.title.new") : L("product.title.edit"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("common.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L("common.save")) { save() }
                    .fontWeight(.semibold)
            }
        }
        .onChange(of: barcode) { _, _ in
            if !trimmedBarcode.isEmpty {
                validationMessage = nil
            }
        }
    }

    private func save() {
        guard !trimmedBarcode.isEmpty else {
            validationMessage = L("product.validation.barcode_required")
            return
        }

        let purchase = Self.parseDouble(from: purchasePrice)
        let retail = Self.parseDouble(from: retailPrice)
        let stock = Self.parseDouble(from: stockQuantity)

        // prezzi precedenti per storico
        let oldPurchase = existingProduct?.purchasePrice
        let oldRetail = existingProduct?.retailPrice
        let oldDraft = existingProduct.map(Self.makeDraft)

        let target: Product
        let operation: LocalPendingChangeOperation
        if let existingProduct {
            target = existingProduct
            operation = .update
        } else {
            target = Product(barcode: barcode)
            context.insert(target)
            operation = .create
        }

        target.barcode = trimmedBarcode
        target.itemNumber = itemNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : itemNumber
        target.productName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name
        target.secondProductName = secondName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : secondName
        target.purchasePrice = purchase
        target.retailPrice = retail
        target.stockQuantity = stock

        let trimmedSupplier = supplierName.trimmingCharacters(in: .whitespacesAndNewlines)
        var createdSupplier: Supplier?
        if trimmedSupplier.isEmpty {
            target.supplier = nil
        } else if let existing = suppliers.first(where: {
            $0.name.compare(trimmedSupplier, options: [.caseInsensitive]) == .orderedSame
        }) {
            target.supplier = existing
        } else {
            let newSupplier = Supplier(name: trimmedSupplier)
            context.insert(newSupplier)
            target.supplier = newSupplier
            createdSupplier = newSupplier
        }

        let trimmedCategory = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        var createdCategory: ProductCategory?
        if trimmedCategory.isEmpty {
            target.category = nil
        } else if let existing = categories.first(where: {
            $0.name.compare(trimmedCategory, options: [.caseInsensitive]) == .orderedSame
        }) {
            target.category = existing
        } else {
            let newCategory = ProductCategory(name: trimmedCategory)
            context.insert(newCategory)
            target.category = newCategory
            createdCategory = newCategory
        }

        // storico prezzi automatico
        let priceChanges = createPriceHistoryIfNeeded(
            for: target,
            oldPurchase: oldPurchase,
            newPurchase: purchase,
            oldRetail: oldRetail,
            newRetail: retail
        )

        do {
            let accumulator = LocalPendingChangeAccumulator(
                context: context,
                ownerUserID: pendingOwnerUserID
            )
            if let createdSupplier {
                try accumulator.recordSupplierChange(
                    supplier: createdSupplier,
                    operation: .create,
                    origin: .manualCatalogSave
                )
            }
            if let createdCategory {
                try accumulator.recordCategoryChange(
                    category: createdCategory,
                    operation: .create,
                    origin: .manualCatalogSave
                )
            }
            let changedFields = operation == .create
                ? Self.createChangedFields
                : ProductUpdateDraft.computeChangedFields(
                    old: oldDraft ?? Self.makeDraft(target),
                    new: Self.makeDraft(target)
                ).map(\.rawValue)
            try accumulator.recordProductChange(
                product: target,
                operation: operation,
                origin: .manualCatalogSave,
                changedFields: changedFields,
                baselineFingerprintHash: oldDraft.map(LocalPendingChangeLogicalKey.productFingerprintHash)
            )
            try priceChanges.forEach {
                try accumulator.recordProductPriceChange(price: $0, origin: .productPriceSave)
            }
            try context.save()
            dismiss()
        } catch {
            context.rollback()
            validationMessage = L("product.validation.save_failed")
            #if DEBUG
            print("Errore durante il salvataggio locale.")
            #endif
        }
    }

    private func createPriceHistoryIfNeeded(
        for product: Product,
        oldPurchase: Double?,
        newPurchase: Double?,
        oldRetail: Double?,
        newRetail: Double?
    ) -> [ProductPrice] {
        let now = Date()
        var created: [ProductPrice] = []

        if let newPurchase, newPurchase != oldPurchase {
            let history = ProductPrice(
                type: .purchase,
                price: newPurchase,
                effectiveAt: now,
                source: "EDIT_PRODUCT",
                product: product
            )
            context.insert(history)
            created.append(history)
        }

        if let newRetail, newRetail != oldRetail {
            let history = ProductPrice(
                type: .retail,
                price: newRetail,
                effectiveAt: now,
                source: "EDIT_PRODUCT",
                product: product
            )
            context.insert(history)
            created.append(history)
        }
        return created
    }

    private static func parseDouble(from text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }

    nonisolated private static func makeDraft(_ product: Product) -> ProductDraft {
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
