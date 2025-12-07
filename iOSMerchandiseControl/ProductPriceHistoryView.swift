import SwiftUI
import SwiftData

/// Storico prezzi per singolo prodotto.
struct ProductPriceHistoryView: View {
    let product: Product

    /// Prendiamo lo storico direttamente dalla relazione del modello
    private var prices: [ProductPrice] {
        product.priceHistory.sorted { $0.effectiveAt > $1.effectiveAt }
    }

    var body: some View {
        List {
            if prices.isEmpty {
                Section {
                    Text("Nessuno storico prezzi disponibile.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(prices) { price in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label(for: price.type))
                                    .font(.subheadline)

                                Text(formatDate(price.effectiveAt))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
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
