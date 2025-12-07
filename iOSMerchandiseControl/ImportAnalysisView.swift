import SwiftUI

// MARK: - Modelli per ImportAnalysis (Excel → Database)

/// Snapshot “puro” di un prodotto letto da Excel (non è ancora SwiftData)
struct ProductDraft: Identifiable, Hashable {
    var id: String { barcode }

    var barcode: String
    var itemNumber: String?
    var productName: String?
    var secondProductName: String?
    var purchasePrice: Double?
    var retailPrice: Double?
    var stockQuantity: Double?
    var supplierName: String?
    var categoryName: String?
}

/// Descrive un aggiornamento di un prodotto esistente
struct ProductUpdateDraft: Identifiable {
    enum ChangedField: String, CaseIterable {
        case itemNumber
        case productName
        case secondProductName
        case purchasePrice
        case retailPrice
        case stockQuantity
        case supplierName
        case categoryName
    }

    let id = UUID()
    let barcode: String
    let old: ProductDraft
    let new: ProductDraft
    let changedFields: [ChangedField]
}

/// Errore di import su una singola riga
struct ProductImportRowError: Identifiable {
    let id = UUID()
    let rowNumber: Int
    let reason: String
    let rowContent: [String: String]
}

/// Warning per barcode duplicati nello stesso file
struct ProductDuplicateWarning: Identifiable {
    var id: String { barcode }
    let barcode: String
    let rowNumbers: [Int]
}

/// Risultato complessivo dell’analisi
struct ProductImportAnalysisResult: Identifiable {
    let id = UUID()
    var newProducts: [ProductDraft]
    var updatedProducts: [ProductUpdateDraft]
    var errors: [ProductImportRowError]
    var warnings: [ProductDuplicateWarning]

    var hasChanges: Bool {
        !newProducts.isEmpty || !updatedProducts.isEmpty
    }
}

// MARK: - Vista di riepilogo e conferma Import

struct ImportAnalysisView: View {
    let analysis: ProductImportAnalysisResult
    let onApply: () -> Void    // chiamato quando l’utente preme "Applica"

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            summarySection

            if !analysis.warnings.isEmpty {
                warningsSection
            }

            if !analysis.newProducts.isEmpty {
                newProductsSection
            }

            if !analysis.updatedProducts.isEmpty {
                updatedProductsSection
            }

            if !analysis.errors.isEmpty {
                errorsSection
            }
        }
        .navigationTitle("Import da Excel")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annulla") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Applica") {
                    onApply()
                    dismiss()
                }
                .disabled(!analysis.hasChanges)
            }
        }
    }

    // MARK: - Sezioni

    private var summarySection: some View {
        Section("Riepilogo") {
            row(label: "Nuovi prodotti", systemImage: "plus.circle", value: analysis.newProducts.count)
            row(label: "Aggiornamenti", systemImage: "arrow.triangle.2.circlepath", value: analysis.updatedProducts.count)
            row(label: "Warning", systemImage: "exclamationmark.triangle", value: analysis.warnings.count)
            row(label: "Errori", systemImage: "xmark.octagon", value: analysis.errors.count)
        }
    }

    private var warningsSection: some View {
        Section("Barcode duplicati nel file") {
            ForEach(analysis.warnings) { warning in
                VStack(alignment: .leading, spacing: 4) {
                    Text(warning.barcode)
                        .font(.headline)

                    Text("Righe: \(warning.rowNumbers.map(String.init).joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var newProductsSection: some View {
        Section("Nuovi prodotti (\(analysis.newProducts.count))") {
            ForEach(analysis.newProducts) { draft in
                VStack(alignment: .leading, spacing: 4) {
                    Text(draft.productName ?? "Senza nome")
                        .font(.headline)

                    Text("Barcode: \(draft.barcode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        if let purchase = draft.purchasePrice {
                            Text("Acquisto: \(formatPrice(purchase))")
                        }
                        if let retail = draft.retailPrice {
                            Text("Vendita: \(formatPrice(retail))")
                        }
                        if let qty = draft.stockQuantity {
                            Text("Stock: \(formatQuantity(qty))")
                        }
                    }
                    .font(.caption)

                    HStack(spacing: 8) {
                        if let supplier = draft.supplierName, !supplier.isEmpty {
                            Text(supplier)
                        }
                        if let category = draft.categoryName, !category.isEmpty {
                            if draft.supplierName != nil {
                                Text("·")
                            }
                            Text(category)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var updatedProductsSection: some View {
        Section("Prodotti aggiornati (\(analysis.updatedProducts.count))") {
            ForEach(analysis.updatedProducts) { update in
                VStack(alignment: .leading, spacing: 6) {
                    let name = update.new.productName
                        ?? update.old.productName
                        ?? "Senza nome"

                    Text(name)
                        .font(.headline)

                    Text("Barcode: \(update.barcode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    ForEach(update.changedFields, id: \.self) { field in
                        HStack(alignment: .top, spacing: 8) {
                            Text(label(for: field))
                                .font(.caption)
                                .frame(width: 80, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(value(for: field, in: update.old))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Image(systemName: "arrow.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)

                                Text(value(for: field, in: update.new))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var errorsSection: some View {
        Section("Errori (righe ignorate)") {
            ForEach(analysis.errors) { err in
                VStack(alignment: .leading, spacing: 4) {
                    Text("Riga \(err.rowNumber)")
                        .font(.headline)

                    Text(err.reason)
                        .font(.caption)

                    if let name = err.rowContent["productName"], !name.isEmpty {
                        Text(name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Helper UI

    private func row(label: String, systemImage: String, value: Int) -> some View {
        HStack {
            Label(label, systemImage: systemImage)
            Spacer()
            Text("\(value)")
        }
    }

    private func label(for field: ProductUpdateDraft.ChangedField) -> String {
        switch field {
        case .itemNumber: return "Codice"
        case .productName: return "Nome"
        case .secondProductName: return "Secondo nome"
        case .purchasePrice: return "Acquisto"
        case .retailPrice: return "Vendita"
        case .stockQuantity: return "Stock"
        case .supplierName: return "Fornitore"
        case .categoryName: return "Categoria"
        }
    }

    private func value(for field: ProductUpdateDraft.ChangedField, in draft: ProductDraft) -> String {
        switch field {
        case .itemNumber:
            return draft.itemNumber ?? "—"
        case .productName:
            return draft.productName ?? "—"
        case .secondProductName:
            return draft.secondProductName ?? "—"
        case .purchasePrice:
            return formatPrice(draft.purchasePrice)
        case .retailPrice:
            return formatPrice(draft.retailPrice)
        case .stockQuantity:
            return formatQuantity(draft.stockQuantity)
        case .supplierName:
            return draft.supplierName ?? "—"
        case .categoryName:
            return draft.categoryName ?? "—"
        }
    }

    private func formatPrice(_ value: Double?) -> String {
        guard let value else { return "—" }
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.usesGroupingSeparator = false
        return formatter.string(from: value as NSNumber) ?? String(value)
    }

    private func formatQuantity(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value.rounded() == value {
            return String(Int(value))
        } else {
            return String(value)
        }
    }
}
