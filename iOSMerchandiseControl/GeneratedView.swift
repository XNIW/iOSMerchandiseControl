import SwiftUI
import SwiftData
import UIKit

// Struttura per il pannello dettagli riga
private struct RowDetailData: Identifiable {
    let id = UUID()

    let rowIndex: Int               // ✅ nuovo
    let barcode: String
    let productName: String?
    let supplierQuantity: String?
    let countedQuantity: String?
    let oldPurchasePrice: String?
    let oldRetailPrice: String?
    let newRetailPrice: String?
    let syncError: String?
    let isComplete: Bool
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
    let autoOpenScanner: Bool
    let onDone: (() -> Void)?
    
    @State private var isSaving: Bool = false
    @State private var isSyncing: Bool = false

    // Init custom con default, così gli altri punti del codice possono continuare a chiamare
    // GeneratedView(entry: entry) senza rompersi.
    init(entry: HistoryEntry, autoOpenScanner: Bool = false, onDone: (() -> Void)? = nil) {
        self.entry = entry
        self.autoOpenScanner = autoOpenScanner
        self.onDone = onDone
    }

    /// Copie locali dei dati, per lavorare in modo SwiftUI-friendly
    @State private var data: [[String]] = []
    @State private var editable: [[String]] = []
    @State private var complete: [Bool] = []
    
    @Environment(\.scenePhase) private var scenePhase

    @State private var hasUnsavedChanges: Bool = false
    @State private var autosaveTask: Task<Void, Never>? = nil
    @State private var lastSavedAt: Date? = nil

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
    
    @State private var flashRowIndex: Int? = nil
    
    @FocusState private var scannerFocused: Bool
    
    @State private var scrollToRowIndex: Int? = nil
    
    @State private var visibleRowSet: Set<Int> = []
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var showSearch: Bool = false
    @State private var showingEntryInfo = false
    
    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    @State private var shareItem: ShareItem?
    
    @State private var isExportingShare: Bool = false
    private var isBusy: Bool { isSaving || isSyncing || isExportingShare }
    
    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                Form {
                    // Sezione principale: griglia inventario
                    Section("Inventario") {
                        if data.isEmpty {
                            Text("Nessun dato di inventario disponibile.")
                                .foregroundStyle(.secondary)
                        } else {
                            let headerRow = data[0]
                            let errorCount = countSyncErrors()
                            let allRowIndices = 1..<data.count
                            let visibleRowIndices: [Int] = showOnlyErrorRows
                            ? allRowIndices.filter { rowHasError(rowIndex: $0, headerRow: headerRow) }
                            : Array(allRowIndices)
                            
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
                            
                            let checked = complete.dropFirst().filter { $0 }.count
                            let total = max(0, data.count - 1)
                            
                            ProgressView(value: Double(checked), total: Double(max(total, 1))) {
                                Text("Completati \(checked)/\(total)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            
                            // ✅ UN SOLO scroll orizzontale per header + righe (niente scroll per-riga)
                            let columns = Array(headerRow.indices)
                            
                            if showOnlyErrorRows && visibleRowIndices.isEmpty {
                                if #available(iOS 17.0, *) {
                                    ContentUnavailableView(
                                        "Nessuna riga con errore",
                                        systemImage: "checkmark.seal",
                                        description: Text("Tutte le righe risultano sincronizzabili.")
                                    )
                                    .padding(.vertical, 8)
                                } else {
                                    Text("Nessuna riga con errore")
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                ScrollView(.horizontal) {
                                    LazyVStack(alignment: .leading, spacing: 0) {
                                        
                                        // HEADER
                                        HStack(alignment: .center, spacing: 6) {
                                            ForEach(columns, id: \.self) { col in
                                                let key = headerRow[col]
                                                Text(columnTitle(for: key))
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                                    .frame(width: columnWidth(for: key), alignment: columnAlignment(for: key))
                                            }
                                        }
                                        .padding(.vertical, 6)
                                        .background(.thinMaterial)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        
                                        Divider().padding(.vertical, 4)
                                        
                                        // RIGHE
                                        ForEach(visibleRowIndices, id: \.self) { rowIndex in
                                            let hasError = rowHasError(rowIndex: rowIndex, headerRow: headerRow)
                                            let isDone = complete.indices.contains(rowIndex) ? complete[rowIndex] : false
                                            
                                            HStack(alignment: .center, spacing: 6) {
                                                ForEach(columns, id: \.self) { col in
                                                    cellView(
                                                        rowIndex: rowIndex,
                                                        columnIndex: col,
                                                        headerRow: headerRow,
                                                        isDone: isDone
                                                    )
                                                    .frame(
                                                        width: columnWidth(for: headerRow[col]),
                                                        alignment: columnAlignment(for: headerRow[col])
                                                    )
                                                }
                                            }
                                            .id("row-\(rowIndex)")
                                            .onAppear { visibleRowSet.insert(rowIndex) }
                                            .onDisappear { visibleRowSet.remove(rowIndex) }
                                            .padding(.vertical, 6)
                                            .contentShape(Rectangle())
                                            .onTapGesture { flashAndOpenRow(rowIndex, headerRow: headerRow) }
                                            .background(rowBackground(hasError: hasError, isDone: isDone, rowIndex: rowIndex))
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .contextMenu {
                                                Button {
                                                    let newValue = !isDone
                                                    bindingForComplete(rowIndex).wrappedValue = newValue
                                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                } label: {
                                                    Label(isDone ? "Segna non completato" : "Segna completato",
                                                          systemImage: isDone ? "circle" : "checkmark.circle.fill")
                                                }
                                                
                                                Button {
                                                    showRowDetail(for: rowIndex, headerRow: headerRow)
                                                } label: {
                                                    Label("Dettagli riga", systemImage: "info.circle")
                                                }
                                                
                                                if let bIndex = headerRow.firstIndex(of: "barcode"),
                                                   data[rowIndex].indices.contains(bIndex) {
                                                    let barcode = data[rowIndex][bIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                                                    if !barcode.isEmpty {
                                                        Button {
                                                            UIPasteboard.general.string = barcode
                                                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                                                        } label: {
                                                            Label("Copia barcode", systemImage: "doc.on.doc")
                                                        }
                                                    }
                                                }
                                            }
                                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                                Button {
                                                    let newValue = !isDone
                                                    bindingForComplete(rowIndex).wrappedValue = newValue
                                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                                } label: {
                                                    Label(isDone ? "Non completato" : "Completato",
                                                          systemImage: isDone ? "circle" : "checkmark.circle.fill")
                                                }
                                                .tint(isDone ? .gray : .green)
                                            }
                                            
                                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                                Button {
                                                    showRowDetail(for: rowIndex, headerRow: headerRow)
                                                } label: {
                                                    Label("Dettagli", systemImage: "info.circle")
                                                }
                                                .tint(.blue)
                                                
                                                if let bIndex = headerRow.firstIndex(of: "barcode"),
                                                   data[rowIndex].indices.contains(bIndex) {
                                                    let barcode = data[rowIndex][bIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                                                    if !barcode.isEmpty {
                                                        Button {
                                                            UIPasteboard.general.string = barcode
                                                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                                                        } label: {
                                                            Label("Copia", systemImage: "doc.on.doc")
                                                        }
                                                        .tint(.gray)
                                                    }
                                                }
                                            }
                                        }
                                    } // ✅ QUESTA era la parentesi mancante (chiude LazyVStack)
                                    .padding(.vertical, 4)
                                }
                                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
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
                        if !entry.isManualEntry {
                            Button {
                                startProductImportAnalysis()
                            } label: {
                                Text("Aggiorna anagrafica prodotti")
                            }
                            .disabled(isSaving || isSyncing)
                            
                            Button {
                                syncWithDatabase()
                            } label: {
                                if isSyncing {
                                    HStack {
                                        ProgressView()
                                        Text("Sincronizzazione in corso…")
                                    }
                                } else {
                                    Text("Applica inventario al DB")
                                }
                            }
                            .disabled(isSaving || isSyncing)
                        } else {
                            // entry manuale: nessuna azione DB, ma autosave resta attivo
                            Text("Salvataggio automatico attivo.")
                                .foregroundStyle(.secondary)
                        }
                    } footer: {
                        if isSaving {
                            Text("Salvataggio…")
                        } else if hasUnsavedChanges {
                            Text("Modifiche non salvate. Salvataggio automatico tra poco…")
                        } else if let lastSavedAt {
                            Text("Salvato alle \(lastSavedAt.formatted(date: .omitted, time: .shortened))")
                        } else {
                            Text("Salvataggio automatico attivo.")
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 140)
            }
            
            floatingActions
                .padding(.trailing, 16)
                .safeAreaPadding(.bottom, 12)
            }
            .onChange(of: scrollToRowIndex) { _, newValue in
                guard let rowIndex = newValue else { return }

                DispatchQueue.main.async {
                    if visibleRowSet.contains(rowIndex) {
                        // ✅ già visibile: niente scroll, solo pulse
                        pulseHighlightRow(rowIndex)
                    } else {
                        // ✅ non visibile: scroll + pulse
                        withAnimation(.snappy) {
                            proxy.scrollTo("row-\(rowIndex)", anchor: .center)
                        }
                        pulseHighlightRow(rowIndex)
                    }

                    scrollToRowIndex = nil
                }
            }
            .id(entry.id)
            .navigationTitle(entryTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showingEntryInfo = true
                        } label: {
                            Label("Modifica dettagli", systemImage: "pencil")
                        }

                        Button {
                            shareAsXLSX()
                        } label: {
                            Label("Condividi…", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(isBusy)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Fine") {
                        Task { @MainActor in
                            flushAutosaveNow()
                            if let onDone { onDone() } else { dismiss() }
                        }
                    }
                    .disabled(isBusy)
                }
            }
            .onAppear {
                // inizializza i dati dalla HistoryEntry (come facevi già)
                initializeFromEntryIfNeeded()
                
                // se è un inventario manuale e siamo arrivati dal
                // bottone "Scanner inventario veloce", apri lo scanner subito
                if entry.isManualEntry && autoOpenScanner {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showScanner = true
                    }
                }
            }
            .onDisappear {
                Task { @MainActor in
                    flushAutosaveNow()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase != .active {
                    Task { @MainActor in
                        flushAutosaveNow()
                    }
                }
            }
            .alert(alertTitle, isPresented: isAlertPresented) {
                Button("OK", role: .cancel) {
                    saveError = nil
                    syncSummaryMessage = nil
                }
            } message: {
                Text(alertMessageText)
            }
            // Sheet per edit prodotto (da pannello dettagli)
            .sheet(item: $productToEdit) { product in
                NavigationStack {
                    EditProductView(product: product)
                }
            }
            .sheet(isPresented: $showScanner) {
                ScannerView(title: "Scanner barcode") { code in
                    handleScannedBarcode(code)
                    showScanner = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        scannerFocused = true
                    }
                }
            }
            
            // Sheet per storico prezzi (da pannello dettagli)
            .sheet(item: $productForHistory) { product in
                NavigationStack {
                    ProductPriceHistoryView(product: product)
                }
            }
            // Sheet scanner barcode (camera)
            .sheet(item: $rowDetail) { detail in
                rowDetailSheet(detail)
            }
            // 🔹 NUOVO: sheet per l’analisi di import prodotti
            .sheet(item: $importAnalysis) { analysis in
                NavigationStack {
                    ImportAnalysisView(
                        analysis: analysis,
                        onApply: { applyImportAnalysis(analysis) }
                    )
                }
            }
            .sheet(isPresented: $showSearch) {
                NavigationStack {
                    InventorySearchSheet(
                        data: data,
                        onJumpToRow: { rowIndex in
                            showSearch = false
                                if showOnlyErrorRows {
                                    withAnimation(.snappy) { showOnlyErrorRows = false }
                                }
                                scrollToRowIndex = rowIndex   // usa la tua logica già esistente (scroll/pulse)
                        },
                        onApplyBarcode: { code in
                            showSearch = false
                            handleScannedBarcode(code)    // riusa la tua logica (incrementa/aggiunge)
                        }
                    )
                }
            }
            .sheet(isPresented: $showingEntryInfo) {
                EntryInfoEditor(entry: entry)
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
        }
    }
    
    private var floatingActions: some View {
        VStack(spacing: 12) {

            // Search (secondario)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .background(.thinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))
                    .shadow(radius: 8, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .opacity(isBusy ? 0.35 : 1)
            .accessibilityLabel("Cerca riga")

            // Scanner (primario)
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                showScanner = true
            } label: {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.accentColor))
                    .shadow(radius: 10, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
            .opacity(isBusy ? 0.35 : 1)
            .accessibilityLabel("Scansiona barcode")
        }
        .padding(.trailing, 16)
    }
    
    private var entryTitle: String {
        let t = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? entry.id : t
    }
    
    private func markDirtyAndScheduleAutosave() {
        hasUnsavedChanges = true

        autosaveTask?.cancel()
        autosaveTask = Task {
            // debounce leggero: evita di salvare ad ogni tasto
            try? await Task.sleep(nanoseconds: 800_000_000) // 0.8s
            await MainActor.run {
                autosaveIfNeeded()
            }
        }
    }

    @MainActor
    private func autosaveIfNeeded() {
        guard hasUnsavedChanges, !isSaving, !isSyncing else { return }
        saveChanges() // se va bene, dentro saveChanges azzeriamo hasUnsavedChanges
    }

    @MainActor
    private func flushAutosaveNow() {
        autosaveTask?.cancel()
        autosaveTask = nil
        autosaveIfNeeded()
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
    
    private var toolbarStatusSymbol: String? {
        if isSaving { return nil }                 // quando salva mostriamo solo ProgressView
        if hasUnsavedChanges { return "clock" }
        if lastSavedAt != nil { return "checkmark.circle" }
        return nil
    }

    // MARK: - Celle

    /// Ritorna la vista per una cella della griglia.
    @ViewBuilder
    private func cellView(
        rowIndex: Int,
        columnIndex: Int,
        headerRow: [String],
        isDone: Bool
    ) -> some View {
        let key = headerRow[columnIndex]

        // Qui decidiamo quali colonne rendere editabili:
        // - "realQuantity" → editable[row][0]
        // - "RetailPrice"  → editable[row][1]
        if key == "realQuantity" {
            TextField("", text: bindingForEditable(row: rowIndex, slot: 0))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)   // ✅ QUI
                .textFieldStyle(.roundedBorder)
                .font(.caption2)

        } else if key == "RetailPrice" {
            TextField("", text: bindingForEditable(row: rowIndex, slot: 1))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)   // ✅ QUI
                .textFieldStyle(.roundedBorder)
                .font(.caption2)
        } else if key == "SyncError" {
            let value = valueForCell(rowIndex: rowIndex, columnIndex: columnIndex)
            Text(value)
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(1)
        } else if key == "complete" {
            let binding = bindingForComplete(rowIndex)
            let isDone = binding.wrappedValue

            Button {
                let newValue = !isDone
                binding.wrappedValue = newValue

                // (opzionale ma utile) tieni subito coerente anche data[row][complete]
                if data.indices.contains(rowIndex) {
                    var row = data[rowIndex]
                    ensureRow(&row, hasIndex: columnIndex)
                    row[columnIndex] = newValue ? "1" : ""
                    data[rowIndex] = row
                }
            } label: {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isDone ? Color(uiColor: .systemGreen) : Color.secondary)
                    .symbolEffect(.bounce, value: isDone)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .contentShape(Rectangle())      // tap area più grande
                    .padding(.vertical, 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Completato")
            .accessibilityValue(isDone ? "Sì" : "No")
        } else {
            let raw = valueForCell(rowIndex: rowIndex, columnIndex: columnIndex)
            let shown = displayValue(for: key, raw: raw)
            
            Text(shown)
                .font(.caption2)
                .monospacedDigit()
                .lineLimit(1)
            // ✅ dim SOLO dei testi read-only quando completato
                .foregroundStyle(isDone ? .secondary : .primary)
                .opacity(isDone ? 0.65 : 1)
        }
    }
    
    private static let moneyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = .current
        return f
    }()

    private static let numericFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = .current
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()
    
    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
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
                markDirtyAndScheduleAutosave()
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
                markDirtyAndScheduleAutosave()
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
        scannerFocused = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
            
            markDirtyAndScheduleAutosave()
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
            if complete.indices.contains(existingIndex) { complete[existingIndex] = true } // opzionale: scan = completato

            scanError = nil

            if showOnlyErrorRows && !rowHasError(rowIndex: existingIndex, headerRow: headerRow) {
                withAnimation(.snappy) { showOnlyErrorRows = false }
            }

            markDirtyAndScheduleAutosave()
            scrollToRowIndex = existingIndex
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
        
        if showOnlyErrorRows {
            withAnimation(.snappy) { showOnlyErrorRows = false }
        }
        scrollToRowIndex = newIndex

        // Slot 0 = quantità reale, slot 1 = prezzo vendita
        editable[newIndex][0] = "1"
        if let priceIndex = header.firstIndex(of: "RetailPrice") {
            editable[newIndex][1] = newRow[priceIndex]
        }

        // ✅ QUI (subito dopo editable)
        ensureCompleteCapacity()
        if complete.indices.contains(newIndex) { complete[newIndex] = true } // opzionale: scan = completato
        markDirtyAndScheduleAutosave()

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
        markDirtyAndScheduleAutosave()
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

        let isDone = complete.indices.contains(rowIndex) ? complete[rowIndex] : false

        rowDetail = RowDetailData(
            rowIndex: rowIndex,
            barcode: barcode,
            productName: finalName,
            supplierQuantity: supplierQty,
            countedQuantity: countedQty,   // ✅ qui
            oldPurchasePrice: oldPurchase,
            oldRetailPrice: oldRetail,
            newRetailPrice: newRetail,
            syncError: syncError,
            isComplete: isDone             // ✅ qui
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
        
        if let cIdx = headerRow.firstIndex(of: "complete") {
            for rowIndex in 1..<newData.count {
                ensureRow(&newData[rowIndex], hasIndex: cIdx)
                let isDone = complete.indices.contains(rowIndex) ? complete[rowIndex] : false
                newData[rowIndex][cIdx] = isDone ? "1" : ""
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
        
        if saveError == nil {
            hasUnsavedChanges = false
            lastSavedAt = Date()
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
        Self.moneyFormatter.string(from: value as NSNumber) ?? String(value)
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

    private func columnWidth(for key: String) -> CGFloat {
        switch key {
        case "productName", "secondProductName":
            return 220
        case "barcode":
            return 140
        case "itemNumber":
            return 90
        case "SyncError":
            return 240

        // ✅ numeriche più compatte
        case "quantity", "realQuantity":
            return 70
        case "complete":
                return 44
        case "purchasePrice", "totalPrice",
             "RetailPrice", "oldPurchasePrice", "oldRetailPrice",
             "retailPrice", "discountedPrice":
            return 90

        default:
            return 100
        }
    }

    private func columnAlignment(for key: String) -> Alignment {
        // numeri a destra, testo a sinistra (stile “table” iOS)
        switch key {
        case "quantity", "realQuantity",
             "purchasePrice", "totalPrice",
             "RetailPrice", "oldPurchasePrice", "oldRetailPrice",
             "retailPrice", "discountedPrice":
            return .trailing
        case "complete":
                return .center
        default:
            return .leading
        }
    }

    private func columnTitle(for key: String) -> String {
        // etichette più umane (Apple-like)
        switch key {
        case "barcode": return "Barcode"
        case "productName": return "Nome"
        case "secondProductName": return "Nome 2"
        case "itemNumber": return "Codice"
        case "quantity": return "Qtà"
        case "realQuantity": return "Qtà reale"
        case "purchasePrice": return "Acquisto"
        case "totalPrice": return "Totale"
        case "oldPurchasePrice": return "Acq. vecchio"
        case "oldRetailPrice": return "Vend. vecchio"
        case "RetailPrice": return "Vendita"
        case "SyncError": return "Errore"
        case "complete": return "✓"
        default: return key
        }
    }

    private func displayValue(for key: String, raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }

        // formatta SOLO colonne numeriche (così eviti di “rompere” barcode/codici)
        let numericKeys: Set<String> = [
            "quantity","realQuantity",
            "purchasePrice","totalPrice",
            "RetailPrice","oldPurchasePrice","oldRetailPrice",
            "retailPrice","discountedPrice"
        ]
        guard numericKeys.contains(key) else { return t }

        let normalized = t.replacingOccurrences(of: ",", with: ".")
        guard let d = Double(normalized) else { return t }

        return Self.numericFormatter.string(from: NSNumber(value: d)) ?? t
    }
    
    private func pulseHighlightRow(_ rowIndex: Int) {
        withAnimation(.easeOut(duration: 0.10)) {
            flashRowIndex = rowIndex
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.easeOut(duration: 0.15)) {
                if flashRowIndex == rowIndex { flashRowIndex = nil }
            }
        }
    }
    
    private func flashAndOpenRow(_ rowIndex: Int, headerRow: [String]) {
        // accendo highlight
        withAnimation(.easeOut(duration: 0.10)) {
            flashRowIndex = rowIndex
        }

        // apro dettagli subito dopo (delay piccolo ma visibile)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            showRowDetail(for: rowIndex, headerRow: headerRow)
        }

        // spengo highlight
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.easeOut(duration: 0.15)) {
                if flashRowIndex == rowIndex {
                    flashRowIndex = nil
                }
            }
        }
    }

    @ViewBuilder
    private func rowBackground(hasError: Bool, isDone: Bool, rowIndex: Int) -> some View {
        if hasError {
            Color.red.opacity(0.06)
        } else if flashRowIndex == rowIndex {
            Color(uiColor: .quaternarySystemFill)
        } else if isDone {
            Color(uiColor: .systemGreen).opacity(0.10)
        } else {
            Color.clear
        }
    }
    
    @ViewBuilder
    private func rowDetailSheet(_ detail: RowDetailData) -> some View {
        let header = data.first ?? []
        let allRowIndices = Array(1..<data.count)

        let order = showOnlyErrorRows
            ? allRowIndices.filter { rowHasError(rowIndex: $0, headerRow: header) }
            : allRowIndices

        let rowOrder = order.isEmpty ? [detail.rowIndex] : order

        RowDetailSheetView(
            detail: detail,
            rowOrder: rowOrder,
            onNavigateToRow: { newRow in
                showRowDetail(for: newRow, headerRow: header)
            },
            onClose: { rowDetail = nil },
            onEditProduct: { openProductEditor(for: detail.barcode) },
            onShowHistory: { openPriceHistory(for: detail.barcode) },
            isComplete: bindingForComplete(detail.rowIndex),
            countedText: bindingForEditable(row: detail.rowIndex, slot: 0),
            newRetailText: bindingForEditable(row: detail.rowIndex, slot: 1)
        )
    }
    
    private func applyImportAnalysis(_ analysis: ProductImportAnalysisResult) {
        if let vm = productImportVM {
            vm.analysis = analysis
            vm.applyImport()
            if let error = vm.lastError {
                saveError = error
            }
        }
        importAnalysis = nil
    }
    
    private var isAlertPresented: Binding<Bool> {
        Binding(
            get: { saveError != nil || syncSummaryMessage != nil },
            set: { presented in
                if !presented {
                    saveError = nil
                    syncSummaryMessage = nil
                }
            }
        )
    }

    private var alertTitle: String {
        syncSummaryMessage == nil
            ? "Errore durante il salvataggio"
            : "Sincronizzazione completata"
    }

    private var alertMessageText: String {
        saveError ?? syncSummaryMessage ?? ""
    }

    @MainActor
    private func shareAsXLSX() {
        flushAutosaveNow() // esporta la versione aggiornata

        guard !isExportingShare else { return }
        isExportingShare = true

        let grid = data
        let name = entryTitle

        Task {
            defer { isExportingShare = false }

            do {
                let url = try InventoryXLSXExporter.export(grid: grid, preferredName: name)
                shareItem = ShareItem(url: url)
                entry.wasExported = true
                try? context.save()
            } catch {
                saveError = "Impossibile esportare XLSX: \(error.localizedDescription)"
            }
        }
    }
}

private struct RowDetailSheetView: View {
    let detail: RowDetailData
    let rowOrder: [Int]
    let onNavigateToRow: (Int) -> Void
    let onClose: () -> Void
    let onEditProduct: () -> Void
    let onShowHistory: () -> Void

    @Binding var isComplete: Bool
    @Binding var countedText: String
    @Binding var newRetailText: String

    @FocusState private var focusedField: Field?
    private enum Field { case counted, retail }

    var body: some View {

        NavigationStack {
            Form {
                Section("Prodotto") {
                    LabeledContent("Barcode") {
                        HStack(spacing: 12) {
                            Text(detail.barcode)
                                .monospacedDigit()
                                .textSelection(.enabled)

                            Button {
                                UIPasteboard.general.string = detail.barcode
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.borderless)

                            ShareLink(item: detail.barcode) {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }

                    LabeledContent("Nome") {
                        Text(detail.productName ?? "—")
                            .textSelection(.enabled)
                            .foregroundStyle((detail.productName == nil) ? .secondary : .primary)
                    }
                }

                Section("Quantità") {
                    // ✅ rinomina “Fornitore” -> “Da file” (più chiaro)
                    LabeledContent("Da file") {
                        Text(formatIntLike(detail.supplierQuantity) ?? "—")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Contata") {
                        TextField("—", text: $countedText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .counted)
                            .onChange(of: countedText) { _, newValue in
                                // tieni solo cifre (quantità intera)
                                let filtered = newValue.filter(\.isNumber)
                                if filtered != newValue { countedText = filtered }
                            }
                    }

                    // ✅ pulsante rapido “usa fornitore”
                    Button {
                        if let v = formatIntLike(detail.supplierQuantity) {
                            countedText = v
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        Label("Usa quantità da file", systemImage: "arrow.down.circle")
                    }
                    .disabled(formatIntLike(detail.supplierQuantity) == nil)
                }

                Section("Prezzi") {
                    LabeledContent("Acquisto (vecchio)") {
                        Text(formatNumber(detail.oldPurchasePrice) ?? "—")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Vendita (nuovo)") {
                        TextField("—", text: $newRetailText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .retail)
                            .onChange(of: newRetailText) { _, newValue in
                                // accetta cifre + separatore decimale
                                let allowed = Set("0123456789.,")
                                let filtered = String(newValue.filter { allowed.contains($0) })
                                if filtered != newValue { newRetailText = filtered }
                            }
                    }

                    Button {
                        if let v = formatNumber(detail.oldRetailPrice) {
                            newRetailText = v
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        Label("Usa vendita vecchia", systemImage: "arrow.down.circle")
                    }
                    .disabled(formatNumber(detail.oldRetailPrice) == nil)
                }

                if let err = detail.syncError, !err.isEmpty {
                    Section("Errori") {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                // ✅ tieni le tue azioni attuali (edit prodotto, storico prezzi)
                Section("Azioni") {
                    Button(action: onEditProduct) {
                        Label("Modifica prodotto", systemImage: "pencil")
                    }
                    .disabled(detail.barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button(action: onShowHistory) {
                        Label("Storico prezzi", systemImage: "clock")
                    }
                    .disabled(detail.barcode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Chiudi") { onClose() }
                }

                ToolbarItem(placement: .principal) {
                    Text("Dettagli riga")
                        .font(.headline)
                        .lineLimit(1)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation(.snappy) { isComplete.toggle() }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(isComplete ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .toolbarTitleDisplayMode(.inline)
            // ✅ toolbar sopra tastiera (molto “Apple”)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField == .counted {
                        Button("Usa da file") {
                            if let v = formatIntLike(detail.supplierQuantity) { countedText = v }
                        }
                        .disabled(formatIntLike(detail.supplierQuantity) == nil)
                    } else if focusedField == .retail {
                        Button("Usa vendita vecchia") {
                            if let v = formatNumber(detail.oldRetailPrice) { newRetailText = v }
                        }
                        .disabled(formatNumber(detail.oldRetailPrice) == nil)
                    }
                    Spacer()
                    Button("Fine") { focusedField = nil }
                }
            }
        }
    }

    // MARK: - Formatting helpers
    private func formatIntLike(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        guard let d = Double(normalized) else { return nil }
        return String(Int(d.rounded()))
    }

    private func formatNumber(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let normalized = raw.replacingOccurrences(of: ",", with: ".")
        guard let d = Double(normalized) else { return nil }
        // niente trailing inutili
        if d.rounded() == d { return String(Int(d)) }
        return String(d)
    }
}

private struct InventorySearchSheet: View {
    let data: [[String]]
    let onJumpToRow: (Int) -> Void
    let onApplyBarcode: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var barcodeText: String = ""

    private var header: [String] { data.first ?? [] }

    private var idxBarcode: Int? { header.firstIndex(of: "barcode") }
    private var idxCode: Int? { header.firstIndex(of: "itemNumber") }
    private var idxName: Int? { header.firstIndex(of: "productName") ?? header.firstIndex(of: "secondProductName") }

    private func cell(_ row: [String], _ idx: Int?) -> String {
        guard let idx, row.indices.contains(idx) else { return "" }
        return row[idx].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matches(row: [String], query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return false }

        // match “mirato” (più efficiente che scansionare tutte le colonne)
        return cell(row, idxBarcode).localizedCaseInsensitiveContains(q)
            || cell(row, idxCode).localizedCaseInsensitiveContains(q)
            || cell(row, idxName).localizedCaseInsensitiveContains(q)
    }

    private var results: [Int] {
        guard data.count > 1 else { return [] }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }

        return (1..<data.count).filter { i in
            matches(row: data[i], query: q)
        }
        .prefix(200) // evita liste enormi (UX migliore)
        .map { $0 }
    }

    var body: some View {
        List {
            Section("Barcode rapido") {
                HStack(spacing: 12) {
                    TextField("Inserisci barcode", text: $barcodeText)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Applica") {
                        let code = barcodeText.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !code.isEmpty else { return }
                        onApplyBarcode(code)
                        dismiss()
                    }
                    .disabled(barcodeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Text("Usa questo per incrementare/aggiungere una riga senza aprire la camera.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Risultati") {
                if results.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            "Nessun risultato",
                            systemImage: "magnifyingglass",
                            description: Text("Cerca per barcode, codice o nome prodotto.")
                        )
                    } else {
                        Text("Nessun risultato")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(results, id: \.self) { rowIndex in
                        let row = data[rowIndex]
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cell(row, idxName).isEmpty ? "—" : cell(row, idxName))
                                .lineLimit(1)
                            HStack {
                                Text(cell(row, idxBarcode))
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("#\(rowIndex)")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.footnote)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onJumpToRow(rowIndex)
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationTitle("Cerca")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Chiudi") { dismiss() }
            }
        }
        .searchable(text: $searchText, prompt: "Barcode, codice, nome…")
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
