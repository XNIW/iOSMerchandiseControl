import SwiftUI
import SwiftData

struct EditProductView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Se non è nil stai modificando, altrimenti stai creando
    let existingProduct: Product?

    @State private var barcode: String
    @State private var name: String
    @State private var purchasePrice: String
    @State private var retailPrice: String

    // In Compose useresti remember { mutableStateOf(...) } con product param.
    // Qui facciamo la stessa cosa nel costruttore.
    init(product: Product? = nil) {
        self.existingProduct = product
        _barcode = State(initialValue: product?.barcode ?? "")
        _name = State(initialValue: product?.productName ?? "")
        _purchasePrice = State(
            initialValue: product?.purchasePrice.map { String($0) } ?? ""
        )
        _retailPrice = State(
            initialValue: product?.retailPrice.map { String($0) } ?? ""
        )
    }

    var body: some View {
        Form {
            Section("Dati principali") {
                TextField("Barcode", text: $barcode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Nome prodotto", text: $name)
            }

            Section("Prezzi") {
                TextField("Prezzo acquisto", text: $purchasePrice)
                    .keyboardType(.decimalPad)

                TextField("Prezzo vendita", text: $retailPrice)
                    .keyboardType(.decimalPad)
            }
        }
        .navigationTitle(existingProduct == nil ? "Nuovo prodotto" : "Modifica prodotto")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annulla") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Salva") { save() }
            }
        }
    }

    private func save() {
        guard !barcode.isEmpty else { return }

        // Converte stringhe in Double (semplice, poi possiamo migliorare formattazione)
        let purchase = Double(purchasePrice.replacingOccurrences(of: ",", with: "."))
        let retail = Double(retailPrice.replacingOccurrences(of: ",", with: "."))

        let target: Product
        if let existingProduct {
            // MODIFICA: usiamo l'oggetto già in SwiftData
            target = existingProduct
        } else {
            // CREAZIONE: nuovo oggetto inserito nel ModelContext
            target = Product(barcode: barcode)
            context.insert(target)
        }

        target.barcode = barcode
        target.productName = name.isEmpty ? nil : name
        target.purchasePrice = purchase
        target.retailPrice = retail

        try? context.save()
        dismiss()
    }
}
