import SwiftUI
import SwiftData

struct EditProductView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let existingProduct: Product?

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

    init(product: Product? = nil, initialBarcode: String? = nil) {
        self.existingProduct = product

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

    var body: some View {
        Form {
            Section(L("product.section.main")) {
                TextField(L("product.field.barcode"), text: $barcode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField(L("product.field.item_number"), text: $itemNumber)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField(L("product.field.name"), text: $name)

                TextField(L("product.field.second_name"), text: $secondName)
            }

            Section(L("product.section.warehouse")) {
                TextField(L("product.field.stock_quantity"), text: $stockQuantity)
                    .keyboardType(.decimalPad)
            }

            Section(L("product.section.prices")) {
                TextField(L("product.field.purchase_price"), text: $purchasePrice)
                    .keyboardType(.decimalPad)

                TextField(L("product.field.retail_price"), text: $retailPrice)
                    .keyboardType(.decimalPad)
            }

            Section(L("product.section.supplier")) {
                TextField(L("product.field.supplier_name"), text: $supplierName)

                if !suppliers.isEmpty {
                    Menu(L("product.action.select_existing")) {
                        ForEach(suppliers) { supplier in
                            Button(supplier.name) {
                                supplierName = supplier.name
                            }
                        }
                    }
                }
            }

            Section(L("product.section.category")) {
                TextField(L("product.field.category_name"), text: $categoryName)

                if !categories.isEmpty {
                    Menu(L("product.action.select_existing")) {
                        ForEach(categories) { category in
                            Button(category.name) {
                                categoryName = category.name
                            }
                        }
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
            }
        }
    }

    private func save() {
        guard !barcode.isEmpty else { return }

        let purchase = Self.parseDouble(from: purchasePrice)
        let retail = Self.parseDouble(from: retailPrice)
        let stock = Self.parseDouble(from: stockQuantity)

        // prezzi precedenti per storico
        let oldPurchase = existingProduct?.purchasePrice
        let oldRetail = existingProduct?.retailPrice

        let target: Product
        if let existingProduct {
            target = existingProduct
        } else {
            target = Product(barcode: barcode)
            context.insert(target)
        }

        target.barcode = barcode
        target.itemNumber = itemNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : itemNumber
        target.productName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name
        target.secondProductName = secondName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : secondName
        target.purchasePrice = purchase
        target.retailPrice = retail
        target.stockQuantity = stock

        let trimmedSupplier = supplierName.trimmingCharacters(in: .whitespacesAndNewlines)
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
        }

        let trimmedCategory = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
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
        }

        // storico prezzi automatico
        createPriceHistoryIfNeeded(
            for: target,
            oldPurchase: oldPurchase,
            newPurchase: purchase,
            oldRetail: oldRetail,
            newRetail: retail
        )

        try? context.save()
        dismiss()
    }

    private func createPriceHistoryIfNeeded(
        for product: Product,
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
                source: "EDIT_PRODUCT",
                product: product
            )
            context.insert(history)
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
        }
    }

    private static func parseDouble(from text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }
}
