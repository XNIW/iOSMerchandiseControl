import SwiftUI
import SwiftData

// Struttura per il pannello dettagli riga
private struct RowDetailData {
    let barcode: String
    let productName: String?
    let supplierQuantity: String
    let countedQuantity: String
    let oldPurchasePrice: String?
    let oldRetailPrice: String?
    let newRetailPrice: String
    let syncError: String?
}

/// Schermata di editing inventario (equivalente base di GeneratedScreen su Android).
/// - Mostra la griglia salvata in HistoryEntry.data
/// - Permette di:
///   - togglare complete[row]
///   - modificare editable[row][0] (quantità) e editable[row][1] (prezzo)
///   - salvare su SwiftData aggiornando la HistoryEntry
///   - fare entry manuali e usare uno pseudo-scanner barcode
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
    
    /// Motore per l'import prodotti (Excel → DB)
    @State private var productImportVM: ProductImportViewModel?
    @State private var importAnalysis: ProductImportAnalysisResult?

    /// filtro righe solo con errori
    @State private var showOnlyErrorRows: Bool = false

    /// Dettagli riga (sheet stile dialog Android)
    @State private var rowDetail: RowDetailData?

    /// Hook per scanner / input barcode
    @State private var scanInput: String = ""
    @State private var scanError: String?
    @State private var productToEdit: Product?
    @State private var productForHistory: Product?
    @State private var showScanner: Bool = false

    // MARK: - Body

    var body: some View {
        Form {
            // Sezione scanner / input barcode
            Section("Scanner") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("Scansiona o inserisci barcode", text: $scanInput)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        // pulsante per usare l'input testuale
                        Button {
                            handleScanInput()
                        } label: {
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .disabled(scanInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        // pulsante per aprire lo scanner camera
                        Button {
                            showScanner = true
                        } label: {
                            Image(systemName: "camera.viewfinder")
                        }
                        .buttonStyle(.borderless)
                    }

                    Text("Scansiona con la camera oppure digita un barcode per aggiornare/aggiungere la riga corrispondente.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let scanError {
                        Text(scanError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }

            // Sezione principale: griglia inventario
            Section("Inventario") {
                if data.isEmpty {
                    Text("Nessun dato di inventario disponibile.")
                        .foregroundStyle(.secondary)
                } else {
                    let headerRow = data[0]
                    let errorCount = countSyncErrors()
                    let allRowIndices = Array(1..<data.count)
                    let visibleRowIndices: [Int] = showOnlyErrorRows
                        ? allRowIndices.filter { rowHasError(rowIndex: $0, headerRow: headerRow) }
                        : allRowIndices

                    // Piccolo riepilogo righe + errori
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Righe dati: \(max(0, data.count - 1))")
                            Spacer()
                            if errorCount > 0 {
                                Text("\(errorCount) righe con errore")
                                    .foregroundStyle(.red)
                            } else {
                                Text("Nessun errore")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.footnote)

                        Toggle("Mostra solo righe con errore", isOn: $showOnlyErrorRows)
                            .font(.footnote)
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
                                        .frame(
                                            minWidth: key == "SyncError" ? 140 : 90,
                                            alignment: .leading
                                        )
                                }
                            }

                            Divider()

                            // RIGHE DATI
                            ForEach(visibleRowIndices, id: \.self) { rowIndex in
                                HStack(alignment: .top, spacing: 8) {
                                    Toggle(isOn: bindingForComplete(rowIndex)) {
                                        EmptyView()
                                    }
                                    .labelsHidden()
                                    .frame(width: 40, alignment: .leading)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(alignment: .top, spacing: 8) {
                                            ForEach(Array(headerRow.enumerated()), id: \.offset) { columnIndex, _ in
                                                cellView(
                                                    rowIndex: rowIndex,
                                                    columnIndex: columnIndex,
                                                    headerRow: headerRow
                                                )
                                            }
                                        }
                                    }

                                    Button {
                                        showRowDetail(for: rowIndex, headerRow: headerRow)
                                    } label: {
                                        Image(systemName: "info.circle")
                                            .imageScale(.small)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    if entry.isManualEntry {
                        Button {
                            addManualRow()
                        } label: {
                            Label("Aggiungi riga", systemImage: "plus")
                        }
                    }
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

            /// Bottone Salva / Sincronizza
            Section {
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

                // Azioni collegate al database: solo per entry non manuali
                if !entry.isManualEntry {
                    // 🔹 NUOVO: flusso ImportAnalysis (crea/aggiorna Product)
                    Button {
                        startProductImportAnalysis()
                    } label: {
                        Text("Importa/aggiorna prodotti nel DB")
                    }
                    .disabled(isSaving || isSyncing)

                    // 🔹 ESISTENTE: sync inventario (InventorySyncService)
                    Button {
                        syncWithDatabase()
                    } label: {
                        if isSyncing {
                            HStack {
                                ProgressView()
                                Text("Sincronizzazione in corso…")
                            }
                        } else {
                            Text("Sincronizza inventario")
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
        .sheet(
            isPresented: Binding(
                get: { rowDetail != nil },
                set: { if !$0 { rowDetail = nil } }
            )
        ) {
            if let detail = rowDetail {
                NavigationStack {
                    Form {
                        Section("Prodotto") {
                            LabeledContent("Barcode") {
                                Text(detail.barcode.isEmpty ? "—" : detail.barcode)
                            }
                            LabeledContent("Nome") {
                                Text(detail.productName ?? "Non presente in database")
                            }
                        }

                        Section("Quantità") {
                            LabeledContent("Fornitore") {
                                Text(detail.supplierQuantity.isEmpty ? "—" : detail.supplierQuantity)
                            }
                            LabeledContent("Contata") {
                                Text(detail.countedQuantity.isEmpty ? "—" : detail.countedQuantity)
                            }
                        }

                        Section("Prezzi") {
                            if let oldPurchase = detail.oldPurchasePrice {
                                LabeledContent("Acquisto (vecchio)") { Text(oldPurchase) }
                            }
                            if let oldRetail = detail.oldRetailPrice {
                                LabeledContent("Vendita (vecchio)") { Text(oldRetail) }
                            }
                            LabeledContent("Vendita (nuovo)") {
                                Text(detail.newRetailPrice.isEmpty ? "—" : detail.newRetailPrice)
                            }
                        }
                        
                        Section("Azioni") {
                            Button {
                                openProductEditor(for: detail.barcode)
                            } label: {
                                Label("Modifica prodotto", systemImage: "pencil")
                            }

                            Button {
                                openPriceHistory(for: detail.barcode)
                            } label: {
                                Label("Storico prezzi", systemImage: "clock.arrow.circlepath")
                            }
                        }

                        if let syncError = detail.syncError, !syncError.isEmpty {
                            Section("Errore di sincronizzazione") {
                                Text(syncError)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                    .navigationTitle("Dettagli riga")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Chiudi") { rowDetail = nil }
                        }
                    }
                }
            } else {
                Text("Nessuna riga selezionata")
            }
        }
        // Sheet per edit prodotto (da pannello dettagli)
        .sheet(item: $productToEdit) { product in
            NavigationStack {
                EditProductView(product: product)
            }
        }
        // Sheet per storico prezzi (da pannello dettagli)
        .sheet(item: $productForHistory) { product in
            NavigationStack {
                ProductPriceHistoryView(product: product)
            }
        }
        // Sheet scanner barcode (camera)
        .sheet(isPresented: $showScanner) {
            ScannerView(title: "Scanner inventario") { code in
                // usa la stessa logica di input manuale
                scanError = nil
                handleScannedBarcode(code)
                scanInput = ""
            }
        }
        // 🔹 NUOVO: sheet per l’analisi di import prodotti
        .sheet(item: $importAnalysis) { analysis in
            NavigationStack {
                ImportAnalysisView(
                    analysis: analysis,
                    onApply: {
                        if let vm = productImportVM {
                            // teniamo il view model in sync con l'analisi mostrata
                            vm.analysis = analysis
                            vm.applyImport()
                            if let error = vm.lastError {
                                // riuso l'alert esistente di GeneratedView
                                saveError = error
                            }
                        }
                        // chiude il foglio anche lato stato
                        importAnalysis = nil
                    }
                )
            }
        }
    }

    // MARK: - Inizializzazione dati

    /// Copia i dati dalla HistoryEntry solo la prima volta.
    private func initializeFromEntryIfNeeded() {
        // DATA
        if data.isEmpty {
            if entry.isManualEntry && entry.data.isEmpty {
                // Header minimale per entry manuali
                data = [
                    ["barcode", "productName", "realQuantity", "RetailPrice"]
                ]
            } else {
                data = entry.data
            }
        }

        // EDITABLE
        if editable.isEmpty {
            if entry.isManualEntry && entry.editable.isEmpty {
                // Per ogni riga (header compreso) due “slot”: quantità reale e prezzo vendita
                editable = Array(repeating: ["", ""], count: data.count)
            } else {
                editable = entry.editable

                // Allinea lunghezza a data
                if editable.count != data.count {
                    var corrected: [[String]] = []
                    for index in data.indices {
                        if index < editable.count {
                            var row = editable[index]
                            while row.count < 2 {
                                row.append("")
                            }
                            corrected.append(Array(row.prefix(2)))
                        } else {
                            corrected.append(["", ""])
                        }
                    }
                    editable = corrected
                }
            }
        }

        // COMPLETE
        if complete.isEmpty {
            if entry.isManualEntry && entry.complete.isEmpty {
                complete = Array(repeating: false, count: data.count)
            } else {
                complete = entry.complete
            }

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

    // MARK: - Scanner & righe manuali

    private func handleScanInput() {
        let code = scanInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }

        scanError = nil
        handleScannedBarcode(code)
        scanInput = ""
    }

    /// Logica principale di "scan": aggiorna o aggiunge una riga partendo dal barcode.
    private func handleScannedBarcode(_ code: String) {
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        // Se non c'è ancora header ma siamo in entry manuale, crealo ora
        if data.isEmpty && entry.isManualEntry {
            data = [
                ["barcode", "productName", "realQuantity", "RetailPrice"]
            ]
            editable = Array(repeating: ["", ""], count: data.count)
            complete = Array(repeating: false, count: data.count)
        }

        guard !data.isEmpty else {
            scanError = "Nessuna griglia caricata."
            return
        }

        let headerRow = data[0]

        guard let barcodeIndex = headerRow.firstIndex(of: "barcode") else {
            scanError = "La griglia non ha una colonna \"barcode\"."
            return
        }

        // 1) Cerco una riga esistente con lo stesso barcode
        if let existingIndex = data.indices.dropFirst().first(where: { index in
            let row = data[index]
            guard row.indices.contains(barcodeIndex) else { return false }
            return row[barcodeIndex].trimmingCharacters(in: .whitespacesAndNewlines) == cleaned
        }) {
            // Se esiste: incremento realQuantity
            guard let realQuantityIndex = headerRow.firstIndex(of: "realQuantity") else {
                scanError = "La griglia non ha una colonna \"realQuantity\"."
                return
            }

            let baseFromEditable: String? = {
                guard editable.indices.contains(existingIndex),
                      editable[existingIndex].indices.contains(0)
                else { return nil }
                let value = editable[existingIndex][0].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }()

            let baseFromData: String = {
                guard data[existingIndex].indices.contains(realQuantityIndex) else { return "" }
                return data[existingIndex][realQuantityIndex]
            }()

            let normalized = (baseFromEditable ?? baseFromData)
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let current = Double(normalized) ?? 0
            let newValue = current + 1

            ensureEditableCapacity(for: existingIndex)

            if newValue.rounded() == newValue {
                editable[existingIndex][0] = String(Int(newValue))
            } else {
                editable[existingIndex][0] = String(format: "%.2f", newValue)
            }

            ensureCompleteCapacity()
            if complete.indices.contains(existingIndex) {
                complete[existingIndex] = true
            }

            scanError = nil
            return
        }

        // 2) Nessuna riga esistente: per entry manuali creo una nuova riga
        guard entry.isManualEntry else {
            scanError = "Nessuna riga trovata per il barcode \(cleaned)."
            return
        }

        // Assicuriamoci che l'header minimale ci sia
        if data.isEmpty {
            data = [
                ["barcode", "productName", "realQuantity", "RetailPrice"]
            ]
        }

        let header = data[0]
        var newRow = Array(repeating: "", count: header.count)

        if let idx = header.firstIndex(of: "barcode") {
            newRow[idx] = cleaned
        }

        // Cerco il Product nel DB per riempire nome e prezzo
        var product: Product?
        do {
            let descriptor = FetchDescriptor<Product>(
                predicate: #Predicate { $0.barcode == cleaned }
            )
            product = try context.fetch(descriptor).first
        } catch {
            product = nil
        }

        if let nameIndex = header.firstIndex(of: "productName"),
           let product
        {
            let primaryName = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let secondaryName = product.secondProductName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = (primaryName?.isEmpty == false ? primaryName : secondaryName) ?? ""
            newRow[nameIndex] = displayName
        }

        if let qtyIndex = header.firstIndex(of: "realQuantity") {
            newRow[qtyIndex] = "1"
        }

        if let priceIndex = header.firstIndex(of: "RetailPrice"),
           let product,
           let retail = product.retailPrice,
           retail > 0
        {
            newRow[priceIndex] = formatDoubleAsPrice(retail)
        }

        data.append(newRow)

        let newIndex = data.count - 1
        ensureEditableCapacity(for: newIndex)

        // Slot 0 = quantità reale, slot 1 = prezzo vendita
        editable[newIndex][0] = "1"
        if let priceIndex = header.firstIndex(of: "RetailPrice") {
            editable[newIndex][1] = newRow[priceIndex]
        }

        ensureCompleteCapacity()

        scanError = product == nil
            ? "Prodotto non trovato in database, riga aggiunta solo con barcode."
            : nil
    }

    /// Aggiunge una nuova riga vuota per entry manuali.
    private func addManualRow() {
        // Se per qualche motivo non c'è ancora header (entry manuale nuova), crealo
        if data.isEmpty {
            data = [
                ["barcode", "productName", "realQuantity", "RetailPrice"]
            ]
        }

        let header = data[0]
        let emptyRow = Array(repeating: "", count: header.count)
        data.append(emptyRow)

        let newIndex = data.count - 1
        ensureEditableCapacity(for: newIndex)
        ensureCompleteCapacity()
    }

    /// Garantisce che editable abbia abbastanza righe e almeno 2 colonne per la riga indicata.
    private func ensureEditableCapacity(for rowIndex: Int) {
        if editable.count <= rowIndex {
            let needed = rowIndex + 1 - editable.count
            editable.append(contentsOf: Array(repeating: ["", ""], count: max(needed, 0)))
        }

        var row = editable[rowIndex]
        while row.count < 2 {
            row.append("")
        }
        editable[rowIndex] = Array(row.prefix(2))
    }

    /// Garantisce che complete abbia stessa lunghezza di data.
    private func ensureCompleteCapacity() {
        if complete.count != data.count {
            if complete.isEmpty {
                complete = Array(repeating: false, count: data.count)
            } else if complete.count < data.count {
                complete.append(contentsOf: Array(repeating: false, count: data.count - complete.count))
            } else {
                complete = Array(complete.prefix(data.count))
            }
        }
    }

    // MARK: - Pannello dettagli riga

    private func showRowDetail(for rowIndex: Int, headerRow: [String]) {
        guard data.indices.contains(rowIndex) else { return }
        let row = data[rowIndex]

        func value(for column: String) -> String {
            guard let index = headerRow.firstIndex(of: column),
                  row.indices.contains(index)
            else { return "" }
            return row[index]
        }

        let barcode = value(for: "barcode").trimmingCharacters(in: .whitespacesAndNewlines)

        // Nome prodotto dalla riga (productName / secondProductName)
        var rowName = value(for: "productName")
        if rowName.isEmpty {
            rowName = value(for: "secondProductName")
        }

        // Quantità fornitore (colonna "quantity" se presente)
        let supplierQty = value(for: "quantity")

        // Quantità contata: preferisco l'editable (slot 0) se presente
        let countedQty: String = {
            if editable.indices.contains(rowIndex),
               editable[rowIndex].indices.contains(0) {
                let v = editable[rowIndex][0].trimmingCharacters(in: .whitespacesAndNewlines)
                if !v.isEmpty { return v }
            }
            return value(for: "realQuantity")
        }()

        let oldPurchase = value(for: "oldPurchasePrice")
        let oldRetail = value(for: "oldRetailPrice")

        // Prezzo nuovo: preferisco l'editable (slot 1)
        let newRetail: String = {
            if editable.indices.contains(rowIndex),
               editable[rowIndex].indices.contains(1) {
                let v = editable[rowIndex][1].trimmingCharacters(in: .whitespacesAndNewlines)
                if !v.isEmpty { return v }
            }
            return value(for: "RetailPrice")
        }()

        let syncError: String? = {
            guard let errorIndex = headerRow.firstIndex(of: "SyncError"),
                  row.indices.contains(errorIndex)
            else { return nil }
            let v = row[errorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? nil : v
        }()

        // Se non ho nome sulla riga, provo a leggerlo dal DB
        var finalName: String? = rowName.isEmpty ? nil : rowName

        if finalName == nil, !barcode.isEmpty {
            do {
                let descriptor = FetchDescriptor<Product>(
                    predicate: #Predicate { $0.barcode == barcode }
                )
                if let product = try context.fetch(descriptor).first {
                    let primaryName = product.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let secondaryName = product.secondProductName?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let name = (primaryName?.isEmpty == false ? primaryName : secondaryName) ?? ""
                    if !name.isEmpty {
                        finalName = name
                    }
                }
            } catch {
                // ignoro errori DB nel pannello informativo
            }
        }

        rowDetail = RowDetailData(
            barcode: barcode,
            productName: finalName,
            supplierQuantity: supplierQty,
            countedQuantity: countedQty,
            oldPurchasePrice: oldPurchase.isEmpty ? nil : oldPurchase,
            oldRetailPrice: oldRetail.isEmpty ? nil : oldRetail,
            newRetailPrice: newRetail,
            syncError: syncError
        )
    }

    // MARK: - Salvataggio & sync

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
    
    // MARK: - Import prodotti (via ProductImportViewModel)

    /// Crea l'analisi di import partendo dalla griglia corrente.
    private func startProductImportAnalysis() {
        guard !data.isEmpty else {
            saveError = "Nessun dato di inventario da analizzare."
            return
        }

        // Prima riga = header, le altre = dati
        let headerRow = data[0]
        let rows = Array(data.dropFirst())

        // Mappiamo ogni riga in [colonna: valore]
        var mapped: [[String: String]] = []

        for row in rows {
            var dict: [String: String] = [:]

            for (index, key) in headerRow.enumerated() {
                guard index < row.count else { continue }
                let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    dict[key] = value
                }
            }

            // Consideriamo solo righe con barcode non vuoto
            let barcode = (dict["barcode"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !barcode.isEmpty {
                mapped.append(dict)
            }
        }

        guard !mapped.isEmpty else {
            saveError = "Nessuna riga valida (con barcode) trovata per l'import."
            return
        }

        // Usa il motore di import (stesso che potresti usare da DatabaseView)
        let vm = ProductImportViewModel(context: context)
        vm.analyzeMappedRows(mapped)

        if let analysis = vm.analysis {
            // Salviamo sia il risultato che il view model da usare su "Applica"
            self.productImportVM = vm
            self.importAnalysis = analysis
        } else if let error = vm.lastError {
            self.saveError = error
        }
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

    private func formatDoubleAsPrice(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        } else {
            return String(format: "%.2f", value)
        }
    }

    // MARK: - Azioni pannello dettagli

    private func openProductEditor(for barcode: String) {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let descriptor = FetchDescriptor<Product>(
            predicate: #Predicate { $0.barcode == trimmed }
        )

        if let product = try? context.fetch(descriptor).first {
            productToEdit = product
        }
    }

    private func openPriceHistory(for barcode: String) {
        let trimmed = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let descriptor = FetchDescriptor<Product>(
            predicate: #Predicate { $0.barcode == trimmed }
        )

        if let product = try? context.fetch(descriptor).first {
            productForHistory = product
        }
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
