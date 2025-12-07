import SwiftUI
import SwiftData

/// Storico prezzi per singolo prodotto.
struct ProductPriceHistoryView: View {
    let product: Product

    /// Tipo di prezzo attualmente selezionato (come i tab Android)
    @State private var selectedType: PriceType = .purchase

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
        List {
            if prices.isEmpty {
                Section {
                    Text("Nessuno storico prezzi disponibile.")
                        .foregroundStyle(.secondary)
                }
            } else {
                // Picker in stile tab “Acquisto / Vendita”
                Section {
                    Picker("Tipo prezzo", selection: $selectedType) {
                        Text("Acquisto").tag(PriceType.purchase)
                        Text("Vendita").tag(PriceType.retail)
                    }
                    .pickerStyle(.segmented)
                }

                let currentList = selectedType == .purchase ? purchasePrices : retailPrices

                if currentList.isEmpty {
                    Section {
                        Text("Nessuno storico \(label(for: selectedType).lowercased()) disponibile.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section(header: Text(label(for: selectedType))) {
                        ForEach(currentList) { price in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(formatDate(price.effectiveAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if let source = price.source, !source.isEmpty {
                                        Text(source)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Text(formatMoney(price.price))
                                    .font(.headline)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Storico prezzi")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func label(for type: PriceType) -> String {
        switch type {
        case .purchase:
            return "Acquisto"
        case .retail:
            return "Vendita"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatMoney(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        return formatter.string(from: value as NSNumber) ?? String(value)
    }
}
