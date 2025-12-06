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
                            HStack(alignment: .bottom, spacing: 8) {
                                ForEach(Array(excelSession.header.enumerated()), id: \.offset) { index, key in
                                    if excelSession.selectedColumns.indices.contains(index),
                                       excelSession.selectedColumns[index] {
                                        Text(key)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .frame(minWidth: 80, alignment: .leading)
                                    }
                                }
                            }

                            Divider()

                            // Prime righe dati
                            ForEach(Array(previewRows.enumerated()), id: \.offset) { _, row in
                                HStack(alignment: .top, spacing: 8) {
                                    ForEach(excelSession.header.indices, id: \.self) { colIdx in
                                        if excelSession.selectedColumns.indices.contains(colIdx),
                                           excelSession.selectedColumns[colIdx] {
                                            let value = row.indices.contains(colIdx) ? row[colIdx] : ""
                                            Text(value)
                                                .font(.caption2)
                                                .lineLimit(1)
                                                .frame(minWidth: 80, alignment: .leading)
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
                }
            }

            // SELEZIONE COLONNE
            Section("Colonne da usare") {
                if excelSession.header.isEmpty {
                    Text("Nessuna colonna disponibile.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(excelSession.header.enumerated()), id: \.offset) { index, key in
                        let isEssential = excelSession.isColumnEssential(at: index)
                        Toggle(
                            isOn: excelSession.bindingForColumnSelection(at: index)
                        ) {
                            HStack {
                                Text(key)
                                if isEssential {
                                    Text("obbligatoria")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(isEssential)
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
                .disabled(!canGenerate || isGenerating)

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
        .background(
            NavigationLink(
                destination: Group {
                    if let entry = excelSession.currentHistoryEntry {
                        GeneratedView(entry: entry)
                    } else {
                        Text("Nessun inventario disponibile.")
                            .foregroundStyle(.secondary)
                    }
                },
                isActive: $navigateToGenerated,
                label: { EmptyView() }
            )
            .hidden()
        )
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
