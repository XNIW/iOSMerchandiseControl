import SwiftUI
import SwiftData

/// Schermata di editing inventario (equivalente base di GeneratedScreen su Android).
/// - Mostra la griglia salvata in HistoryEntry.data
/// - Permette di:
///   - togglare complete[row]
///   - modificare editable[row][0] (quantità) e editable[row][1] (prezzo)
///   - salvare su SwiftData aggiornando la HistoryEntry
struct GeneratedView: View {
    @Environment(\.modelContext) private var context

    /// Entry da modificare (passata dal chiamante, es. PreGenerateView o HistoryView)
    let entry: HistoryEntry

    /// Copie locali dei dati, per lavorare in modo SwiftUI-friendly
    @State private var data: [[String]] = []
    @State private var editable: [[String]] = []
    @State private var complete: [Bool] = []

    @State private var isSaving: Bool = false
    @State private var isSyncing: Bool = false

    /// errori (salvataggio o sync)
    @State private var saveError: String?

    /// riepilogo di una sincronizzazione andata a buon fine
    @State private var syncSummaryMessage: String?
    
    @State private var showOnlyErrorRows: Bool = false

    // MARK: - Body

    var body: some View {
        Form {
            // Sezione principale: griglia inventario
            Section("Inventario") {
                if data.isEmpty {
                    Text("Nessun dato di inventario disponibile.")
                        .foregroundStyle(.secondary)
                } else {
                    let headerRow = data[0]
                    let rowCount = max(data.count - 1, 0)
                    let errorCount = countSyncErrors()

                    // Barra con filtro errori + conteggio
                    HStack {
                        Toggle("Mostra solo errori", isOn: $showOnlyErrorRows)
                            .font(.footnote)

                        Spacer()

                        if errorCount > 0 {
                            Text("\(errorCount) righe in errore")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        } else {
                            Text("Nessun errore")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 4) {
                            // HEADER
                            HStack(alignment: .bottom, spacing: 8) {
                                // Colonna per il toggle "completato"
                                Text("✓")
                                    .font(.caption2)
                                    .frame(width: 28, alignment: .center)

                                ForEach(Array(headerRow.enumerated()), id: \.offset) { index, key in
                                    Text(key)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .frame(minWidth: key == "SyncError" ? 140 : 90,
                                               alignment: .leading)
                                }
                            }

                            Divider()

                            // Indici di riga visibili: tutti o solo quelli con SyncError
                            let allRowIndices = Array(1..<data.count)
                            let visibleRowIndices: [Int] = showOnlyErrorRows
                                ? allRowIndices.filter { rowHasError(rowIndex: $0, headerRow: headerRow) }
                                : allRowIndices

                            // RIGHE DATI
                            ForEach(visibleRowIndices, id: \.self) { rowIndex in
                                HStack(alignment: .center, spacing: 8) {
                                    // Toggle "completa"
                                    Toggle("", isOn: bindingForComplete(rowIndex))
                                        .labelsHidden()
                                        .frame(width: 28)

                                    ForEach(headerRow.indices, id: \.self) { colIndex in
                                        cellView(
                                            rowIndex: rowIndex,
                                            columnIndex: colIndex,
                                            headerRow: headerRow
                                        )
                                    }
                                }
                                // Evidenzia riga con errore
                                .background(
                                    rowHasError(rowIndex: rowIndex, headerRow: headerRow)
                                        ? Color.red.opacity(0.08)
                                        : Color.clear
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    Text("Righe dati: \(rowCount)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            // Sezione riassunto base (per ora non ricalcoliamo il totale ordine)
            Section("Riassunto") {
                let checked = complete.dropFirst().filter { $0 }.count
                let missing = max(0, entry.totalItems - checked)
                let errorCount = countSyncErrors()

                LabeledContent("Articoli totali") {
                    Text("\(entry.totalItems)")
                }
                LabeledContent("Articoli da completare") {
                    Text("\(missing)")
                }
                LabeledContent("Righe in errore") {
                    Text("\(errorCount)")
                        .foregroundStyle(errorCount > 0 ? .red : .secondary)
                }
                LabeledContent("Totale ordine (iniziale)") {
                    Text(formatMoney(entry.orderTotal))
                }
            }

            // Bottone Salva
            Section {
                // Bottone Salva modifiche
                Button {
                    saveChanges()
                } label: {
                    if isSaving {
                        HStack {
                            ProgressView()
                            Text("Salvataggio…")
                        }
                    } else {
                        Text("Salva modifiche")
                    }
                }
                .disabled(isSaving || isSyncing)

                // Bottone Sincronizza con database (solo per entry non manuali)
                if !entry.isManualEntry {
                    Button {
                        syncWithDatabase()
                    } label: {
                        if isSyncing {
                            HStack {
                                ProgressView()
                                Text("Sincronizzazione in corso…")
                            }
                        } else {
                            Text("Sincronizza con database")
                        }
                    }
                    .disabled(isSaving || isSyncing)
                }
            }
        }
        .id(entry.id)
        .navigationTitle(entry.id)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            initializeFromEntryIfNeeded()
        }
        .alert(
            // Titolo dinamico a seconda che sia errore o riepilogo
            syncSummaryMessage == nil
                ? "Errore durante il salvataggio"
                : "Sincronizzazione completata",
            isPresented: Binding(
                get: { saveError != nil || syncSummaryMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        saveError = nil
                        syncSummaryMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                saveError = nil
                syncSummaryMessage = nil
            }
        } message: {
            Text(saveError ?? syncSummaryMessage ?? "")
        }
    }

    // MARK: - Inizializzazione dati

    /// Copia i dati dalla HistoryEntry solo la prima volta.
    private func initializeFromEntryIfNeeded() {
        // data = griglia completa (header + righe)
        if data.isEmpty {
            data = entry.data
        }

        // editable: coppie [qty, price] con stessa lunghezza di data
        if editable.isEmpty {
            editable = entry.editable

            // sicurezza: riallinea la lunghezza se serve
            if editable.count != data.count {
                var corrected = Array(repeating: ["", ""], count: data.count)
                for i in 0..<min(editable.count, corrected.count) {
                    corrected[i] = editable[i]
                }
                editable = corrected
            }
        }

        // complete: una flag per ogni riga (inclusa riga header, normalmente false)
        if complete.isEmpty {
            complete = entry.complete

            if complete.count != data.count {
                complete = Array(repeating: false, count: data.count)
            }
        }
    }

    // MARK: - Celle

    /// Ritorna la vista per una cella della griglia.
    @ViewBuilder
    private func cellView(
        rowIndex: Int,
        columnIndex: Int,
        headerRow: [String]
    ) -> some View {
        let key = headerRow[columnIndex]

        // Qui decidiamo quali colonne rendere editabili:
        // - "realQuantity" → editable[row][0]
        // - "RetailPrice"  → editable[row][1]
        if key == "realQuantity" {
            TextField(
                "",
                text: bindingForEditable(row: rowIndex, slot: 0)
            )
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .font(.caption2)
            .frame(minWidth: 90)
        } else if key == "RetailPrice" {
            TextField(
                "",
                text: bindingForEditable(row: rowIndex, slot: 1)
            )
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .font(.caption2)
            .frame(minWidth: 90)
        } else if key == "SyncError" {
            // La colonna degli errori: testo rosso, un po' più larga
            let value = valueForCell(rowIndex: rowIndex, columnIndex: columnIndex)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(1)
                .frame(minWidth: 140, alignment: .leading)
        } else {
            // Tutto il resto è solo testo
            let value = valueForCell(rowIndex: rowIndex, columnIndex: columnIndex)
            Text(value)
                .font(.caption2)
                .lineLimit(1)
                .frame(minWidth: 90, alignment: .leading)
        }
    }

    /// Valore testuale di una cella (solo lettura).
    private func valueForCell(rowIndex: Int, columnIndex: Int) -> String {
        guard data.indices.contains(rowIndex),
              data[rowIndex].indices.contains(columnIndex) else {
            return ""
        }
        return data[rowIndex][columnIndex]
    }
    
    /// Ritorna true se la riga ha un messaggio di errore nella colonna "SyncError".
    private func rowHasError(rowIndex: Int, headerRow: [String]) -> Bool {
        guard
            !data.isEmpty,
            headerRow.contains("SyncError"),
            let errorIndex = headerRow.firstIndex(of: "SyncError"),
            data.indices.contains(rowIndex),
            data[rowIndex].indices.contains(errorIndex)
        else {
            return false
        }

        let value = data[rowIndex][errorIndex]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return !value.isEmpty
    }
    
    /// Conta quante righe hanno un messaggio nella colonna "SyncError".
    private func countSyncErrors() -> Int {
        guard !data.isEmpty else { return 0 }
        let header = data[0]

        guard let errorIndex = header.firstIndex(of: "SyncError") else {
            return 0
        }

        return data.dropFirst().reduce(0) { partial, row in
            guard row.indices.contains(errorIndex) else { return partial }
            let value = row[errorIndex]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return partial + (value.isEmpty ? 0 : 1)
        }
    }

    /// Binding per complete[row]
    private func bindingForComplete(_ rowIndex: Int) -> Binding<Bool> {
        Binding(
            get: {
                guard complete.indices.contains(rowIndex) else { return false }
                return complete[rowIndex]
            },
            set: { newValue in
                if !complete.indices.contains(rowIndex) {
                    let needed = rowIndex - complete.count + 1
                    complete.append(contentsOf: Array(repeating: false, count: max(needed, 0)))
                }
                complete[rowIndex] = newValue
            }
        )
    }

    /// Binding per editable[row][slot] (slot 0 = qty, slot 1 = price)
    private func bindingForEditable(row: Int, slot: Int) -> Binding<String> {
        Binding(
            get: {
                guard editable.indices.contains(row),
                      editable[row].indices.contains(slot) else {
                    return ""
                }
                return editable[row][slot]
            },
            set: { newValue in
                // garantisce che editable abbia abbastanza righe
                if !editable.indices.contains(row) {
                    let needed = row - editable.count + 1
                    editable.append(contentsOf: Array(repeating: ["", ""], count: max(needed, 0)))
                }
                // garantisce 2 colonne [qty, price]
                if editable[row].count < 2 {
                    editable[row] = Array(editable[row].prefix(2)) + Array(
                        repeating: "",
                        count: 2 - editable[row].count
                    )
                }
                editable[row][slot] = newValue
            }
        )
    }

    // MARK: - Salvataggio

    private func saveChanges() {
        guard !data.isEmpty else { return }

        isSaving = true
        saveError = nil

        // Copia mutabile dei dati griglia
        var newData = data

        let headerRow = newData[0]
        let qtyIndex = headerRow.firstIndex(of: "realQuantity")
        let priceIndex = headerRow.firstIndex(of: "RetailPrice")

        // Aggiorna le colonne "realQuantity" e "RetailPrice" in base a editable[row][0/1]
        if let qIdx = qtyIndex {
            for rowIndex in 1..<newData.count {
                let qtyText: String = {
                    guard editable.indices.contains(rowIndex),
                          editable[rowIndex].indices.contains(0) else {
                        return ""
                    }
                    return editable[rowIndex][0]
                }()

                ensureRow(&newData[rowIndex], hasIndex: qIdx)
                newData[rowIndex][qIdx] = qtyText
            }
        }

        if let pIdx = priceIndex {
            for rowIndex in 1..<newData.count {
                let priceText: String = {
                    guard editable.indices.contains(rowIndex),
                          editable[rowIndex].indices.contains(1) else {
                        return ""
                    }
                    return editable[rowIndex][1]
                }()

                ensureRow(&newData[rowIndex], hasIndex: pIdx)
                newData[rowIndex][pIdx] = priceText
            }
        }

        // Aggiorna missingItems in base al numero di righe completate
        let checked = complete.dropFirst().filter { $0 }.count
        let missing = max(0, entry.totalItems - checked)

        // Scrive nella HistoryEntry
        entry.data = newData
        entry.editable = editable
        entry.complete = complete
        entry.missingItems = missing

        do {
            try context.save()
        } catch {
            saveError = error.localizedDescription
        }

        isSaving = false
        // aggiorna anche il buffer locale, così rimane in sync
        data = newData
    }
    
    /// Applica i dati dell'inventario al database prodotti e aggiorna la griglia con gli errori.
    private func syncWithDatabase() {
        guard !isSyncing else { return }

        isSyncing = true
        // Puliamo eventuali messaggi precedenti
        saveError = nil
        syncSummaryMessage = nil

        // 1) Prima cosa: salvare la griglia in HistoryEntry
        saveChanges()

        // Se il salvataggio ha fallito (saveError impostato), non partiamo con la sync
        if saveError != nil {
            isSyncing = false
            return
        }

        // 2) Esegui la sincronizzazione vera e propria
        do {
            let service = InventorySyncService(context: context)
            let result = try service.sync(entry: entry)

            // Ricarichiamo la griglia dall'entry,
            // così la nuova colonna "SyncError" e i messaggi vengono mostrati
            data = entry.data

            // Prepariamo il riepilogo da mostrare all'utente
            syncSummaryMessage = result.summaryMessage
        } catch {
            saveError = error.localizedDescription
        }

        isSyncing = false
    }

    /// Allunga la riga se necessario per avere almeno `index + 1` elementi
    private func ensureRow(_ row: inout [String], hasIndex index: Int) {
        if index >= row.count {
            row.append(contentsOf: Array(repeating: "", count: index - row.count + 1))
        }
    }

    // MARK: - Helpers

    private func formatMoney(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        return formatter.string(from: value as NSNumber) ?? String(value)
    }
}

#Preview {
    // Piccola entry di esempio per il preview
    let sampleData: [[String]] = [
        ["barcode", "productName", "purchasePrice", "quantity",
         "oldPurchasePrice", "oldRetailPrice", "realQuantity", "RetailPrice", "complete"],
        ["1234567890123", "Prodotto di test", "10", "1", "9", "11", "", "", ""]
    ]
    let sampleEditable: [[String]] = [
        ["", ""],
        ["", ""]
    ]
    let sampleComplete: [Bool] = Array(repeating: false, count: sampleData.count)

    let entry = HistoryEntry(
        id: "2025-01-01_Prova.xlsx",
        timestamp: Date(),
        isManualEntry: false,
        data: sampleData,
        editable: sampleEditable,
        complete: sampleComplete,
        supplier: "Fornitore demo",
        category: "Categoria demo",
        totalItems: 1,
        orderTotal: 10,
        paymentTotal: 10,
        missingItems: 1,
        syncStatus: .notAttempted,
        wasExported: false
    )

    return NavigationStack {
        GeneratedView(entry: entry)
    }
    .modelContainer(
        for: [Product.self, Supplier.self, ProductCategory.self, HistoryEntry.self, ProductPrice.self],
        inMemory: true
    )
}
