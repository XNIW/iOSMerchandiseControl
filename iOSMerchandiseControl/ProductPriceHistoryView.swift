import SwiftUI
import SwiftData

/// Storico prezzi per singolo prodotto.
struct ProductPriceHistoryView: View {
    @Environment(\.dismiss) private var dismiss

    let product: Product

    /// Tipo di prezzo attualmente selezionato (come i tab Android)
    @State private var selectedType: PriceType = .purchase
    @AppStorage("appLanguage") private var appLanguage: String = "system"

    /// Storico completo, ordinato dal più recente
    private var prices: [ProductPrice] {
        product.priceHistory.sorted { $0.effectiveAt > $1.effectiveAt }
    }

    private var purchasePrices: [ProductPrice] {
        prices.filter { $0.type == .purchase }
    }

    private var retailPrices: [ProductPrice] {
        prices.filter { $0.type == .retail }
    }

    var body: some View {
        let resolvedLanguageCode = Bundle.resolvedLanguageCode(for: appLanguage)

        List {
            if prices.isEmpty {
                Section {
                    ContentUnavailableView(L("product.history.empty"), systemImage: "clock.badge.questionmark")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                // Picker in stile tab “Acquisto / Vendita”
                Section {
                    Picker(L("product.history.price_type"), selection: $selectedType) {
                        Text(L("product.history.purchase")).tag(PriceType.purchase)
                        Text(L("product.history.retail")).tag(PriceType.retail)
                    }
                    .pickerStyle(.segmented)
                }

                let currentList = selectedType == .purchase ? purchasePrices : retailPrices

                if currentList.isEmpty {
                    Section {
                        ContentUnavailableView(
                            L("product.history.empty_type", label(for: selectedType).lowercased()),
                            systemImage: "clock"
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
}
