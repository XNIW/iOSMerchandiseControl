import SwiftUI
import SwiftData

/// Storico prezzi per singolo prodotto.
struct ProductPriceHistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let product: Product
    let pendingOwnerUserID: UUID?
    let onCurrentPriceUpdated: ((PriceType, Double) -> Void)?

    /// Tipo di prezzo attualmente selezionato (come i tab Android)
    @State private var selectedType: PriceType = .purchase
    @State private var addPricePresentation: AddPricePresentation?
    @AppStorage("appLanguage") private var appLanguage: String = "system"

    init(
        product: Product,
        pendingOwnerUserID: UUID? = nil,
        onCurrentPriceUpdated: ((PriceType, Double) -> Void)? = nil
    ) {
        self.product = product
        self.pendingOwnerUserID = pendingOwnerUserID
        self.onCurrentPriceUpdated = onCurrentPriceUpdated
    }

    private struct AddPricePresentation: Identifiable {
        let type: PriceType

        var id: String { type.rawValue }
    }

    /// Storico completo, ordinato dal più recente
    private var prices: [ProductPrice] {
        ProductPriceContract.sortedHistory(product.priceHistory)
    }

    private var purchasePrices: [ProductPrice] {
        prices.filter { $0.type == .purchase }
    }

    private var retailPrices: [ProductPrice] {
        prices.filter { $0.type == .retail }
    }

    var body: some View {
        let resolvedLanguageCode = Bundle.resolvedLanguageCode(for: appLanguage)
        let currentList = selectedType == .purchase ? purchasePrices : retailPrices

        List {
            Section {
                Picker(L("product.history.price_type"), selection: $selectedType) {
                    Text(L("product.history.purchase")).tag(PriceType.purchase)
                    Text(L("product.history.retail")).tag(PriceType.retail)
                }
                .pickerStyle(.segmented)
            }

            Section {
                HStack(alignment: .firstTextBaseline) {
                    Label(currentPriceLabel(for: selectedType), systemImage: selectedType == .purchase ? "cart" : "tag")
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(currentPriceText(for: selectedType))
                        .font(.headline)
                        .monospacedDigit()
                }

                Button {
                    addPricePresentation = AddPricePresentation(type: selectedType)
                } label: {
                    Label(L("product.history.action.update_current"), systemImage: "plus.circle")
                }
            }

            if currentList.isEmpty {
                Section {
                    ContentUnavailableView(
                        prices.isEmpty
                            ? L("product.history.empty")
                            : L("product.history.empty_type", label(for: selectedType).lowercased()),
                        systemImage: "clock.badge.questionmark"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
            } else {
                Section(header: Text(label(for: selectedType))) {
                    ForEach(currentList) { price in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formatDate(price.effectiveAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let source = price.source, !source.isEmpty {
                                    Label(displaySource(source), systemImage: "tag")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Text(formatMoney(price.price))
                                .font(.headline)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .id("product-price-history-list-\(resolvedLanguageCode)")
        .navigationTitle(L("product.history.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("common.close")) {
                    dismiss()
                }
            }
        }
        .sheet(item: $addPricePresentation) { presentation in
            NavigationStack {
                AddProductPriceView(
                    product: product,
                    initialType: presentation.type,
                    pendingOwnerUserID: pendingOwnerUserID,
                    onSaved: { type, value in
                        selectedType = type
                        onCurrentPriceUpdated?(type, value)
                    }
                )
            }
        }
    }

    private func currentPriceLabel(for type: PriceType) -> String {
        switch type {
        case .purchase:
            return L("product.history.current_purchase")
        case .retail:
            return L("product.history.current_retail")
        }
    }

    private func currentPriceText(for type: PriceType) -> String {
        guard let value = ProductPriceContract.currentPrice(for: product, type: type) else {
            return L("product.history.no_current_price")
        }
        return formatMoney(value)
    }

    private func label(for type: PriceType) -> String {
        switch type {
        case .purchase:
            return L("product.history.purchase")
        case .retail:
            return L("product.history.retail")
        }
    }

    private func displaySource(_ source: String) -> String {
        switch source {
        case "BACKFILL":
            return L("product.history.source.initial_price")
        case "IMPORT_EXCEL":
            return L("product.history.source.import_excel")
        case "IMPORT_PREV":
            return L("product.history.source.import_previous")
        case "INVENTORY_SYNC":
            return L("product.history.source.inventory_sync")
        case "EDIT_PRODUCT":
            return L("product.history.source.manual_edit")
        case "IMPORT_DB_FULL":
            return L("product.history.source.database_import")
        default:
            return source
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = appLocale()
        return formatter.string(from: date)
    }

    private func formatMoney(_ value: Double) -> String {
        formatCLPMoney(value)
    }

    private struct AddProductPriceView: View {
        @Environment(\.modelContext) private var context
        @Environment(\.dismiss) private var dismiss

        let product: Product
        let pendingOwnerUserID: UUID?
        let onSaved: (PriceType, Double) -> Void

        @State private var selectedType: PriceType
        @State private var priceText: String
        @State private var effectiveAt = Date()
        @State private var validationMessage: String?

        init(
            product: Product,
            initialType: PriceType,
            pendingOwnerUserID: UUID?,
            onSaved: @escaping (PriceType, Double) -> Void
        ) {
            self.product = product
            self.pendingOwnerUserID = pendingOwnerUserID
            self.onSaved = onSaved
            _selectedType = State(initialValue: initialType)

            let currentPrice: Double?
            switch initialType {
            case .purchase:
                currentPrice = product.purchasePrice
            case .retail:
                currentPrice = product.retailPrice
            }
            _priceText = State(initialValue: currentPrice.map(Self.format(number:)) ?? "")
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

                Section {
                    Picker(L("product.history.price_type"), selection: $selectedType) {
                        Text(L("product.history.purchase")).tag(PriceType.purchase)
                        Text(L("product.history.retail")).tag(PriceType.retail)
                    }
                    .pickerStyle(.segmented)

                    TextField(L("product.history.add.price"), text: $priceText)
                        .keyboardType(.decimalPad)
                        .monospacedDigit()
                        .accessibilityLabel(Text(L("product.history.add.price")))

                    DatePicker(
                        L("product.history.add.effective_at"),
                        selection: $effectiveAt,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                } footer: {
                    Text(L("product.history.add.footer"))
                }
            }
            .navigationTitle(L("product.history.add.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.save")) { save() }
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: priceText) { _, _ in
                validationMessage = nil
            }
        }

        private func save() {
            guard let value = Self.parseDouble(from: priceText), value >= 0 else {
                validationMessage = L("product.history.add.validation_invalid")
                return
            }

            let oldDraft = makeDraft(product)
            let history = ProductPrice(
                type: selectedType,
                price: value,
                effectiveAt: effectiveAt,
                source: "EDIT_PRODUCT",
                product: product
            )
            context.insert(history)

            let changedFields: [String]
            switch selectedType {
            case .purchase:
                let oldValue = product.purchasePrice
                product.purchasePrice = value
                changedFields = oldValue == value ? [] : ["purchasePrice"]
            case .retail:
                let oldValue = product.retailPrice
                product.retailPrice = value
                changedFields = oldValue == value ? [] : ["retailPrice"]
            }

            do {
                let accumulator = LocalPendingChangeAccumulator(
                    context: context,
                    ownerUserID: pendingOwnerUserID
                )
                if !changedFields.isEmpty {
                    try accumulator.recordProductChange(
                        product: product,
                        operation: .update,
                        origin: .manualCatalogSave,
                        changedFields: changedFields,
                        baselineFingerprintHash: LocalPendingChangeLogicalKey.productFingerprintHash(oldDraft)
                    )
                }
                try accumulator.recordProductPriceChange(price: history, origin: .productPriceSave)
                try context.save()
                onSaved(selectedType, value)
                dismiss()
            } catch {
                context.rollback()
                validationMessage = L("product.history.add.save_failed")
            }
        }

        nonisolated private static func parseDouble(from text: String) -> Double? {
            let normalized = text
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !normalized.isEmpty else { return nil }
            return Double(normalized)
        }

        nonisolated private static func format(number: Double) -> String {
            let intPart = floor(number)
            if number == intPart {
                return String(Int(intPart))
            } else {
                return String(number)
            }
        }

        private func makeDraft(_ product: Product) -> ProductDraft {
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
    }
}
