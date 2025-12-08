import SwiftUI
import SwiftData

/// Schermata equivalente a PreGenerateScreen su Android:
/// - mostra anteprima header + qualche riga
/// - permette di abilitare/disabilitare colonne
/// - chiede fornitore e categoria con suggerimenti da SwiftData
struct PreGenerateView: View {
    @EnvironmentObject var excelSession: ExcelSessionViewModel
    @Environment(\.modelContext) private var context

    @Query(sort: \Supplier.name, order: .forward)
    private var suppliers: [Supplier]

    @Query(sort: \ProductCategory.name, order: .forward)
    private var categories: [ProductCategory]

    private let maxPreviewRows = 20

    @State private var isGenerating = false
    @State private var generationError: String?
    @State private var lastGeneratedEntryID: String?
    
    @State private var navigateToGenerated = false
    @State private var ignoreWarnings = false
    
    var body: some View {
        Form {
            // ANTEPRIMA FILE
            Section("Anteprima") {
                if excelSession.rows.isEmpty {
                    Text("Nessun file caricato.")
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 4) {
                            // Header
                            HStack(alignment: .bottom, spacing: 4) {
                                ForEach(Array(excelSession.header.enumerated()), id: \.offset) { index, key in
                                    if excelSession.selectedColumns.indices.contains(index),
                                       excelSession.selectedColumns[index] {
                                        let width = columnWidth(for: key)
                                        Text(key)
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .lineLimit(1)
                                            .frame(width: width, alignment: .leading)
                                    }
                                }
                            }

                            Divider()

                            // Prime righe dati
                            ForEach(Array(previewRows.enumerated()), id: \.offset) { _, row in
                                HStack(alignment: .top, spacing: 4) {
                                    ForEach(excelSession.header.indices, id: \.self) { colIdx in
                                        if excelSession.selectedColumns.indices.contains(colIdx),
                                           excelSession.selectedColumns[colIdx] {
                                            let key = excelSession.header[colIdx]
                                            let width = columnWidth(for: key)
                                            let value = colIdx < row.count ? row[colIdx] : ""
                                            
                                            Text(value)
                                                .font(
                                                    isNumericColumn(key)
                                                    ? .system(.caption2, design: .monospaced)
                                                    : .caption2
                                                )
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                                .frame(width: width, alignment: .leading)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Text("Mostrate \(previewRows.count) righe su \(max(excelSession.rows.count - 1, 0)).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    
                    // 🔎 Badge affidabilità analisi
                    if let confidence = excelSession.analysisConfidence {
                        HStack {
                            Label("Affidabilità analisi", systemImage: "chart.bar.fill")
                            Spacer()
                            Text(String(format: "%.0f%%", confidence * 100))
                                .font(.caption)
                                .foregroundStyle(
                                    confidence > 0.7 ? .green :
                                    confidence > 0.4 ? .orange : .red
                                )

                            if confidence < 0.5 {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(.secondarySystemBackground))
                        )
                    }

                    // 💡 Suggerimenti per bassa confidenza
                    if let confidence = excelSession.analysisConfidence,
                       confidence < 0.5 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Suggerimenti per migliorare l'analisi:")
                                .font(.caption)
                                .fontWeight(.medium)

                            if let metrics = excelSession.analysisMetrics {
                                if metrics.essentialColumnsFound < metrics.essentialColumnsTotal {
                                    Text("• Verifica le colonne obbligatorie (barcode, nome prodotto, prezzo acquisto).")
                                        .font(.caption2)
                                }

                                if metrics.totalRows > 0 &&
                                   Double(metrics.rowsWithValidBarcode) / Double(metrics.totalRows) < 0.3 {
                                    Text("• Controlla la colonna barcode: molti valori potrebbero essere mancanti.")
                                        .font(.caption2)
                                }

                                if !metrics.issues.isEmpty {
                                    Text("• Risolvi, se possibile, i problemi elencati qui sopra.")
                                        .font(.caption2)
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange.opacity(0.1))
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
            }

            // SELEZIONE COLONNE
            Section("Colonne da usare") {
                if excelSession.header.isEmpty {
                    Text("Nessuna colonna disponibile.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(excelSession.header.indices), id: \.self) { index in
                        let key = excelSession.header[index]
                        let isEssential = excelSession.isColumnEssential(at: index)
                        let isAutoGenerated = key.hasPrefix("col") // es. col1, col2...

                        Toggle(
                            isOn: excelSession.bindingForColumnSelection(at: index)
                        ) {
                            HStack {
                                Text(key)
                                    .foregroundColor(isAutoGenerated ? .orange : .primary)

                                if isEssential {
                                    Text("obbligatoria")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                if isAutoGenerated {
                                    Text("(non riconosciuta)")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .disabled(isEssential) // le obbligatorie non si spengono
                    }

                    HStack {
                        Button("Seleziona tutte") {
                            excelSession.setAllColumns(selected: true, keepEssential: false)
                        }
                        Button("Deseleziona tutte (tranne obbligatorie)") {
                            excelSession.setAllColumns(selected: false, keepEssential: true)
                        }
                    }
                    .buttonStyle(.borderless)

                    Text("Le colonne obbligatorie non possono essere disattivate.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // FORNITORE & CATEGORIA (come in EditProductView)
            Section("Fornitore") {
                TextField("Nome fornitore", text: $excelSession.supplierName)

                if !suppliers.isEmpty {
                    Menu("Seleziona esistente") {
                        ForEach(suppliers) { supplier in
                            Button(supplier.name) {
                                excelSession.supplierName = supplier.name
                            }
                        }
                    }
                }
            }

            Section("Categoria") {
                TextField("Nome categoria", text: $excelSession.categoryName)

                if !categories.isEmpty {
                    Menu("Seleziona esistente") {
                        ForEach(categories) { category in
                            Button(category.name) {
                                excelSession.categoryName = category.name
                            }
                        }
                    }
                }
            }

            // Step successivi: qui comparirà il pulsante "Genera inventario"
            
            // GENERAZIONE INVENTARIO (HistoryEntry)
            Section {
                // Mostra il toggle solo se la confidenza è molto bassa
                if let confidence = excelSession.analysisConfidence,
                   confidence < 0.4 {
                    Toggle("Ignora avvisi e procedi comunque", isOn: $ignoreWarnings)
                        .font(.caption)
                        .padding(.vertical, 4)
                }

                Button {
                    generateInventory()
                } label: {
                    if isGenerating {
                        HStack {
                            ProgressView()
                            Text("Generazione in corso…")
                        }
                    } else {
                        Text("Genera inventario")
                            .fontWeight(.semibold)
                    }
                }
                .disabled(
                    !canGenerate ||
                    isGenerating ||
                    (
                        (excelSession.analysisConfidence ?? 1.0) < 0.4 &&
                        !ignoreWarnings
                    )
                )

                if let lastID = lastGeneratedEntryID {
                    Text("Ultimo inventario generato: \(lastID)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    Text("L’inventario generato comparirà nella scheda \"Cronologia\".")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Pre-elaborazione")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Errore durante la generazione", isPresented: Binding(
            get: { generationError != nil },
            set: { newValue in
                if !newValue { generationError = nil }
            }
        )) {
            Button("OK", role: .cancel) {
                generationError = nil
            }
        } message: {
            Text(generationError ?? "Errore sconosciuto.")
        }
        // 👇 Navigation "nascosta" verso GeneratedView
        .navigationDestination(isPresented: $navigateToGenerated) {
            Group {
                if let entry = excelSession.currentHistoryEntry {
                    GeneratedView(entry: entry)
                } else {
                    Text("Nessun inventario disponibile.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    /// Righe di anteprima (esclude la riga 0 = header)
    private var previewRows: [[String]] {
        guard !excelSession.rows.isEmpty else { return [] }
        let dataRows = excelSession.rows.dropFirst()
        return Array(dataRows.prefix(maxPreviewRows))
    }

    /// Possiamo generare solo se c'è un file caricato e supplier/category non sono vuoti
    private var canGenerate: Bool {
        !excelSession.header.isEmpty &&
        !excelSession.rows.isEmpty &&
        !excelSession.supplierName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !excelSession.categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // Larghezza consigliata per ogni colonna
    private func columnWidth(for key: String) -> CGFloat {
        switch key {
        case "barcode":
            return 130
        case "productName", "secondProductName":
            return 220
        case "purchasePrice", "retailPrice", "discountedPrice", "totalPrice", "quantity":
            return 80
        case "supplier", "category":
            return 140
        default:
            return 100
        }
    }

    // Facoltativo: colonne numeriche (per eventuale font monospaced)
    private func isNumericColumn(_ key: String) -> Bool {
        [
            "barcode",
            "quantity",
            "purchasePrice",
            "totalPrice",
            "retailPrice",
            "discountedPrice",
            "rowNumber"
        ].contains(key)
    }
    
    private func generateInventory() {
        guard canGenerate else { return }
        isGenerating = true

        Task {
            do {
                let entry = try excelSession.generateHistoryEntry(in: context)

                await MainActor.run {
                    // (generateHistoryEntry mette già currentHistoryEntry,
                    // ma lo riallineiamo esplicitamente)
                    excelSession.currentHistoryEntry = entry
                    lastGeneratedEntryID = entry.id
                    isGenerating = false
                    // → Vai alla schermata GeneratedView
                    navigateToGenerated = true
                }
            } catch {
                await MainActor.run {
                    generationError = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
}

#Preview {
    // Preview minimale: non serve avere dati reali
    NavigationStack {
        PreGenerateView()
            .environmentObject(ExcelSessionViewModel())
    }
}
