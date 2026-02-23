import SwiftUI
import SwiftData
import UIKit

// Struttura per il pannello dettagli riga
private struct RowDetailData: Identifiable {
    let id = UUID()

    let rowIndex: Int
    let barcode: String
    let productName: String?
    let supplierQuantity: String?
    let oldPurchasePrice: String?
    let oldRetailPrice: String?
    let syncError: String?
    let isComplete: Bool
    let autoFocusCounted: Bool
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

    /// errori da scanner / aggiunta manuale
    @State private var scanError: String?

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
    @State private var productToEdit: Product?
    @State private var productForHistory: Product?
    @State private var showScanner: Bool = false
    
    @State private var flashRowIndex: Int? = nil
    
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
    
    @State private var reopenRowDetailAfterScan: Bool = false
    
    @State private var focusCountedOnNextDetail: Bool = false
    @State private var pendingReopenRowIndexAfterScannerDismiss: Int? = nil

    private var shortageDialogTitle: String {
        if let p = pendingForceComplete {
            return "Mancano \(p.missing)"
        }
        return "Mancano merce"
    }
    
    private struct PendingForceComplete: Identifiable {
        let id = UUID()
        let rowIndex: Int
        let headerRow: [String]
        let missing: Int            // ✅ quanti pezzi mancano (positivo)
        let supplier: String
        let counted: String
    }

    @State private var pendingForceComplete: PendingForceComplete?

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
                                            let hasShortage = rowHasShortage(rowIndex: rowIndex, headerRow: headerRow)

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
                                            .background(rowBackground(hasError: hasError, hasShortage: hasShortage, isDone: isDone, rowIndex: rowIndex))
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .contextMenu {
                                                Button {
                                                    requestSetComplete(rowIndex: rowIndex, headerRow: headerRow, value: !isDone)
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
                                                    requestSetComplete(rowIndex: rowIndex, headerRow: headerRow, value: !isDone)
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
            .onChange(of: showScanner) { _, isShown in
                guard !isShown else { return }

                // se lo scanner si chiude senza aver scansionato (cancel),
                // riapri il dettaglio originale
                if reopenRowDetailAfterScan,
                   let rowIndex = pendingReopenRowIndexAfterScannerDismiss,
                   rowDetail == nil
                {
                    pendingReopenRowIndexAfterScannerDismiss = nil
                    reopenRowDetailAfterScan = false

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                        let header = data.first ?? []
                        showRowDetail(for: rowIndex, headerRow: header)
                    }
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
            .confirmationDialog(
                shortageDialogTitle,
                isPresented: Binding(
                    get: { pendingForceComplete != nil },
                    set: { if !$0 { pendingForceComplete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Segna completata comunque") {
                    guard let p = pendingForceComplete else { return }
                    setComplete(rowIndex: p.rowIndex, headerRow: p.headerRow, value: true)
                    pendingForceComplete = nil
                }
                Button("Annulla", role: .cancel) {
                    pendingForceComplete = nil
                }
            } message: {
                if let p = pendingForceComplete {
                    Text("Da file: \(p.supplier)\nContata: \(p.counted)")
                }
            }
            // Sheet per edit prodotto (da pannello dettagli)
            .sheet(item: $productToEdit) { product in
                NavigationStack {
                    EditProductView(product: product)
                }
            }
            .sheet(isPresented: $showScanner) {
                ScannerView(title: "Scanner barcode") { code in
                    let touchedRow = handleScannedBarcode(
                        code,
                        incrementExistingRow: !reopenRowDetailAfterScan
                    )

                    // ✅ Se ho scansionato davvero (touchedRow != nil) non voglio riaprire la vecchia riga
                    if reopenRowDetailAfterScan, touchedRow != nil {
                        pendingReopenRowIndexAfterScannerDismiss = nil
                    }

                    let shouldReopenDetail = reopenRowDetailAfterScan
                    reopenRowDetailAfterScan = false

                    showScanner = false

                    if shouldReopenDetail,
                       let touchedRow,
                       let header = data.first
                    {
                        // ✅ micro-polish: feedback “success” quando troviamo/agganciamo una riga
                        UINotificationFeedbackGenerator().notificationOccurred(.success)

                        // ✅ garantisce focus su “Contata” quando si riapre il dettaglio
                        focusCountedOnNextDetail = true

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            showRowDetail(for: touchedRow, headerRow: header)
                        }
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
                            if showOnlyErrorRows {
                                withAnimation(.snappy) { showOnlyErrorRows = false }
                            }
                            scrollToRowIndex = rowIndex
                        },
                        onOpenDetail: { rowIndex in
                            if showOnlyErrorRows {
                                withAnimation(.snappy) { showOnlyErrorRows = false }
                            }
                            // evita “present while dismissing”
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                let headerRow = data.first ?? []
                                showRowDetail(for: rowIndex, headerRow: headerRow)
                            }
                        },
                        onApplyBarcode: { code in
                            handleScannedBarcode(code)
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
    
    private func requestScanFromRowDetail() {
        // vogliamo tornare al dettaglio dopo lo scan (o dopo cancel)
        reopenRowDetailAfterScan = true
        focusCountedOnNextDetail = true

        // se l’utente cancella lo scanner, riapriamo la stessa riga
        pendingReopenRowIndexAfterScannerDismiss = rowDetail?.rowIndex

        // chiudi prima il dettaglio (evita present-while-dismissing)
        rowDetail = nil

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showScanner = true
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

    @ViewBuilder
    private func completeIndicator(isDone: Bool, delta: Int?) -> some View {
        if isDone {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color(uiColor: .systemGreen))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)

        } else if let delta, delta < 0 {
            VStack(spacing: 1) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("\(delta)") // negativo, es. -3
                    .font(.caption2)
                    .monospacedDigit()
            }
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 2)
            .accessibilityLabel("Mancano \(abs(delta))")

        } else {
            Image(systemName: "circle")
                .font(.system(size: 18, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 2)
        }
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
            let qtyBinding = bindingForEditable(row: rowIndex, slot: 0)

            TextField("", text: qtyBinding)
                .keyboardType(.numberPad)                 // ✅ era decimalPad
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .font(.caption2)
                .onChange(of: qtyBinding.wrappedValue) { _, newValue in
                    let filtered = newValue.filter(\.isNumber)
                    if filtered != newValue { qtyBinding.wrappedValue = filtered }

                    // vedi punto 2: auto-sync stato anche dalla griglia
                    syncCompletionForRow(rowIndex: rowIndex, headerRow: headerRow, haptic: false)
                }
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
            let delta = rowQuantityDelta(rowIndex: rowIndex, headerRow: headerRow)

            Button {
                requestSetComplete(rowIndex: rowIndex, headerRow: headerRow, value: !isDone)
            } label: {
                completeIndicator(isDone: isDone, delta: delta)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stato riga")
            .accessibilityValue(isDone ? "Completata" : "Non completata")
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

    private func numberValue(_ raw: String?) -> Double? {
        guard let raw else { return nil }
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        let normalized = t.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func intValue(_ raw: String?) -> Int? {
        guard let d = numberValue(raw) else { return nil }
        return Int(d.rounded())
    }

    private func supplierQty(rowIndex: Int, headerRow: [String]) -> Int? {
        guard let idx = headerRow.firstIndex(of: "quantity"),
              data.indices.contains(rowIndex),
              data[rowIndex].indices.contains(idx)
        else { return nil }
        return intValue(data[rowIndex][idx])
    }

    private func countedQty(rowIndex: Int, headerRow: [String]) -> Int? {
        // preferisci editable[row][0]
        if editable.indices.contains(rowIndex), editable[rowIndex].indices.contains(0) {
            let v = editable[rowIndex][0].trimmingCharacters(in: .whitespacesAndNewlines)
            if let i = intValue(v), !v.isEmpty { return i }
        }
        // fallback realQuantity colonna (se esiste)
        if let idx = headerRow.firstIndex(of: "realQuantity"),
           data.indices.contains(rowIndex),
           data[rowIndex].indices.contains(idx) {
            let v = data[rowIndex][idx].trimmingCharacters(in: .whitespacesAndNewlines)
            if v.isEmpty { return nil }
            return intValue(v)
        }
        return nil
    }

    /// delta = contata - da file
    private func rowQuantityDelta(rowIndex: Int, headerRow: [String]) -> Int? {
        guard let s = supplierQty(rowIndex: rowIndex, headerRow: headerRow),
              let c = countedQty(rowIndex: rowIndex, headerRow: headerRow)
        else { return nil }
        return c - s
    }

    private func rowHasShortage(rowIndex: Int, headerRow: [String]) -> Bool {
        guard let d = rowQuantityDelta(rowIndex: rowIndex, headerRow: headerRow) else { return false }
        return d < 0
    }

    
    private func countedTextForRow(rowIndex: Int, headerRow: [String]) -> String {
        if editable.indices.contains(rowIndex), editable[rowIndex].indices.contains(0) {
            let v = editable[rowIndex][0].trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { return v }
        }
        if let idx = headerRow.firstIndex(of: "realQuantity"),
           data.indices.contains(rowIndex),
           data[rowIndex].indices.contains(idx) {
            let v = data[rowIndex][idx].trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { return v }
        }
        return "—"
    }

    private func supplierQtyForRow(rowIndex: Int, headerRow: [String]) -> String {
        if let idx = headerRow.firstIndex(of: "quantity"),
           data.indices.contains(rowIndex),
           data[rowIndex].indices.contains(idx) {
            let v = data[rowIndex][idx].trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? "—" : v
        }
        return "—"
    }

    private func setComplete(rowIndex: Int, headerRow: [String], value: Bool, haptic: Bool = true) {
        bindingForComplete(rowIndex).wrappedValue = value

        if let cIdx = headerRow.firstIndex(of: "complete"),
           data.indices.contains(rowIndex) {
            var row = data[rowIndex]
            ensureRow(&row, hasIndex: cIdx)
            row[cIdx] = value ? "1" : ""
            data[rowIndex] = row
        }

        if haptic {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func requestSetComplete(rowIndex: Int, headerRow: [String], value: Bool) {
        // dialog SOLO se sto provando a segnare ✅ e c'è shortage (delta < 0)
        if value == true,
           let delta = rowQuantityDelta(rowIndex: rowIndex, headerRow: headerRow),
           delta < 0
        {
            pendingForceComplete = PendingForceComplete(
                rowIndex: rowIndex,
                headerRow: headerRow,
                missing: abs(delta),
                supplier: supplierQtyForRow(rowIndex: rowIndex, headerRow: headerRow),
                counted: countedTextForRow(rowIndex: rowIndex, headerRow: headerRow)
            )
            return
        }

        setComplete(rowIndex: rowIndex, headerRow: headerRow, value: value)
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
    
    // MARK: - Binding per celle "data" (non editable[qty/price])

    private func bindingForCell(rowIndex: Int, columnKey: String) -> Binding<String>? {
        guard
            !data.isEmpty,
            let col = data[0].firstIndex(of: columnKey),
            data.indices.contains(rowIndex)
        else { return nil }

        return Binding(
            get: {
                guard data.indices.contains(rowIndex),
                      data[rowIndex].indices.contains(col) else { return "" }
                return data[rowIndex][col]
            },
            set: { newValue in
                guard data.indices.contains(rowIndex) else { return }
                ensureRow(&data[rowIndex], hasIndex: col)
                data[rowIndex][col] = newValue
                markDirtyAndScheduleAutosave()
            }
        )
    }

    private func snapshotValue(rowIndex: Int, columnKey: String) -> String? {
        guard
            !data.isEmpty,
            let col = data[0].firstIndex(of: columnKey),
            data.indices.contains(rowIndex),
            data[rowIndex].indices.contains(col)
        else { return nil }

        let v = data[rowIndex][col].trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : v
    }

    // MARK: - Scanner & righe manuali

    /// Logica principale di "scan": aggiorna o aggiunge una riga partendo dal barcode.
    @discardableResult
    private func handleScannedBarcode(_ code: String, incrementExistingRow: Bool = true) -> Int? {
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

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
            return nil
        }

        let headerRow = data[0]

        guard let barcodeIndex = headerRow.firstIndex(of: "barcode") else {
            scanError = "La griglia non ha una colonna \"barcode\"."
            return nil
        }

        // 1) Cerco una riga esistente con lo stesso barcode
        if let existingIndex = data.indices.dropFirst().first(where: { index in
            let row = data[index]
            guard row.indices.contains(barcodeIndex) else { return false }
            return row[barcodeIndex].trimmingCharacters(in: .whitespacesAndNewlines) == cleaned
        }) {
            if incrementExistingRow {
                
                // Se esiste: incremento realQuantity
                guard let realQuantityIndex = headerRow.firstIndex(of: "realQuantity") else {
                    scanError = "La griglia non ha una colonna \"realQuantity\"."
                    return nil
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
                syncCompletionForRow(rowIndex: existingIndex, headerRow: headerRow, haptic: true)

                scanError = nil

                if showOnlyErrorRows && !rowHasError(rowIndex: existingIndex, headerRow: headerRow) {
                    withAnimation(.snappy) { showOnlyErrorRows = false }
                }

                markDirtyAndScheduleAutosave()
            } else {
                // scan “di navigazione”: non tocca Contata
                scanError = nil
            }
            scrollToRowIndex = existingIndex
            return existingIndex
        }

        // 2) Nessuna riga esistente: per entry manuali creo una nuova riga
        guard entry.isManualEntry else {
            scanError = "Nessuna riga trovata per il barcode \(cleaned)."
            return nil
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

        return newIndex
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

    private func makeRowDetailData(for rowIndex: Int, headerRow: [String], isComplete: Bool, autoFocusCounted: Bool, skipProductNameLookup: Bool = false) -> RowDetailData {
        guard data.indices.contains(rowIndex) else {
            fatalError("makeRowDetailData: rowIndex out of range")
        }
        let row = data[rowIndex]

        func value(for column: String) -> String {
            guard let index = headerRow.firstIndex(of: column),
                  row.indices.contains(index)
            else { return "" }
            return row[index]
        }

        let barcode = value(for: "barcode").trimmingCharacters(in: .whitespacesAndNewlines)

        var rowName = value(for: "productName")
        if rowName.isEmpty {
            rowName = value(for: "secondProductName")
        }

        let supplierQty = value(for: "quantity")
        let oldPurchase = value(for: "oldPurchasePrice")
        let oldRetail = value(for: "oldRetailPrice")

        let syncError: String? = {
            guard let errorIndex = headerRow.firstIndex(of: "SyncError"),
                  row.indices.contains(errorIndex)
            else { return nil }
            let v = row[errorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? nil : v
        }()

        var finalName: String? = rowName.isEmpty ? nil : rowName

        // Lookup nome da DB solo alla prima apertura; in navigazione prev/next si usa solo il dato della riga per risposta istantanea
        if !skipProductNameLookup, finalName == nil, !barcode.isEmpty {
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

        return RowDetailData(
            rowIndex: rowIndex,
            barcode: barcode,
            productName: finalName,
            supplierQuantity: supplierQty,
            oldPurchasePrice: oldPurchase,
            oldRetailPrice: oldRetail,
            syncError: syncError,
            isComplete: isComplete,
            autoFocusCounted: autoFocusCounted
        )
    }

    private func showRowDetail(for rowIndex: Int, headerRow: [String], animated: Bool = true) {
        guard data.indices.contains(rowIndex) else { return }
        let isDone = complete.indices.contains(rowIndex) ? complete[rowIndex] : false
        let shouldFocus = focusCountedOnNextDetail
        focusCountedOnNextDetail = false
        let skipLookup = !animated
        let detail = makeRowDetailData(for: rowIndex, headerRow: headerRow, isComplete: isDone, autoFocusCounted: shouldFocus, skipProductNameLookup: skipLookup)
        if animated {
            rowDetail = detail
        } else {
            var tx = Transaction(animation: nil)
            tx.disablesAnimations = true
            withTransaction(tx) { rowDetail = detail }
        }
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

    private func syncCompletionForRow(rowIndex: Int, headerRow: [String], haptic: Bool) {
        guard complete.indices.contains(rowIndex) else { return }
        guard let s = supplierQty(rowIndex: rowIndex, headerRow: headerRow) else { return }

        let c = countedQty(rowIndex: rowIndex, headerRow: headerRow) // usa editable[row][0] se presente
        let shouldBeComplete = (c != nil && c! >= s)

        if shouldBeComplete != complete[rowIndex] {
            withAnimation(.snappy) {
                setComplete(rowIndex: rowIndex, headerRow: headerRow, value: shouldBeComplete, haptic: haptic)
            }
        } else if c == nil, complete[rowIndex] {
            withAnimation(.snappy) {
                setComplete(rowIndex: rowIndex, headerRow: headerRow, value: false, haptic: haptic)
            }
        }
    }

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
    private func rowBackground(hasError: Bool, hasShortage: Bool, isDone: Bool, rowIndex: Int) -> some View {
        if hasError {
            Color.red.opacity(0.06)
        } else if flashRowIndex == rowIndex {
            Color(uiColor: .quaternarySystemFill)
        } else if isDone {
            Color(uiColor: .systemGreen).opacity(0.10)
        } else if hasShortage {
            Color(uiColor: .systemYellow).opacity(0.16)
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

        let editBindings = RowEditBindings(
            barcode: bindingForCell(rowIndex: detail.rowIndex, columnKey: "barcode"),
            itemNumber: bindingForCell(rowIndex: detail.rowIndex, columnKey: "itemNumber"),
            productName: bindingForCell(rowIndex: detail.rowIndex, columnKey: "productName"),
            secondProductName: bindingForCell(rowIndex: detail.rowIndex, columnKey: "secondProductName"),
            quantity: bindingForCell(rowIndex: detail.rowIndex, columnKey: "quantity"),
            purchasePrice: bindingForCell(rowIndex: detail.rowIndex, columnKey: "purchasePrice"),
            totalPrice: bindingForCell(rowIndex: detail.rowIndex, columnKey: "totalPrice"),
            retailPrice: bindingForCell(rowIndex: detail.rowIndex, columnKey: "retailPrice"),
            discountedPrice: bindingForCell(rowIndex: detail.rowIndex, columnKey: "discountedPrice"),
            supplier: bindingForCell(rowIndex: detail.rowIndex, columnKey: "supplier"),
            category: bindingForCell(rowIndex: detail.rowIndex, columnKey: "category")
        )

        let editSnapshot = RowEditSnapshot(
            barcode: snapshotValue(rowIndex: detail.rowIndex, columnKey: "barcode"),
            itemNumber: snapshotValue(rowIndex: detail.rowIndex, columnKey: "itemNumber"),
            productName: snapshotValue(rowIndex: detail.rowIndex, columnKey: "productName"),
            secondProductName: snapshotValue(rowIndex: detail.rowIndex, columnKey: "secondProductName"),
            quantity: snapshotValue(rowIndex: detail.rowIndex, columnKey: "quantity"),
            purchasePrice: snapshotValue(rowIndex: detail.rowIndex, columnKey: "purchasePrice"),
            totalPrice: snapshotValue(rowIndex: detail.rowIndex, columnKey: "totalPrice"),
            retailPrice: snapshotValue(rowIndex: detail.rowIndex, columnKey: "retailPrice"),
            discountedPrice: snapshotValue(rowIndex: detail.rowIndex, columnKey: "discountedPrice"),
            supplier: snapshotValue(rowIndex: detail.rowIndex, columnKey: "supplier"),
            category: snapshotValue(rowIndex: detail.rowIndex, columnKey: "category")
        )

        RowDetailSheetView(
            detail: detail,
            rowOrder: rowOrder,
            onNavigateToRow: { newRow in
                showRowDetail(for: newRow, headerRow: header, animated: false)
            },
            onRefreshRow: { row in
                showRowDetail(for: row, headerRow: header, animated: false)
            },
            onClose: { rowDetail = nil },
            onEditProduct: { openProductEditor(for: detail.barcode) },
            onShowHistory: { openPriceHistory(for: detail.barcode) },
            editBindings: editBindings,
            editSnapshot: editSnapshot,
            onScanNext: { requestScanFromRowDetail() },
            isComplete: bindingForComplete(detail.rowIndex),
            countedText: bindingForEditable(row: detail.rowIndex, slot: 0),
            newRetailText: bindingForEditable(row: detail.rowIndex, slot: 1),
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

        Task { @MainActor in
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
    let onRefreshRow: (Int) -> Void
    let onClose: () -> Void
    let onEditProduct: () -> Void
    let onShowHistory: () -> Void

    let editBindings: RowEditBindings
    let editSnapshot: RowEditSnapshot
    let onScanNext: () -> Void

    @Binding var isComplete: Bool
    @Binding var countedText: String
    @Binding var newRetailText: String

    @FocusState private var focusedField: Field?
    private enum Field { case counted, retail }

    @State private var showPriceCalculator = false
    @State private var showGenericCalculator = false
    @State private var showEditRow = false

    private var currentIndex: Int { rowOrder.firstIndex(of: detail.rowIndex) ?? 0 }
    private var canGoPrev: Bool { currentIndex > 0 }
    private var canGoNext: Bool { currentIndex < (rowOrder.count - 1) }

    private var supplierQtyInt: Int? { parseIntLike(detail.supplierQuantity) }
    private var countedQtyInt: Int? {
        let t = countedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        return Int(t)
    }

    private var qtyDelta: Int? {
        guard let s = supplierQtyInt, let c = countedQtyInt else { return nil }
        return c - s
    }

    private var isShortage: Bool { (qtyDelta ?? 0) < 0 }
    private var isSurplus: Bool { (qtyDelta ?? 0) > 0 }

    @State private var showForceCompleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                // Stato / warning (riga Stato tappabile per toggle, comodo oltre al pulsante in basso)
                Section {
                    Button {
                        if !isComplete, isShortage {
                            showForceCompleteConfirm = true
                        } else {
                            withAnimation(.snappy) { isComplete.toggle() }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        LabeledContent("Stato") {
                            HStack(spacing: 6) {
                                Text(isComplete ? "Completata" : "Incompleta")
                                    .foregroundStyle(isComplete ? .green : .secondary)
                                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                                    .font(.subheadline)
                                    .foregroundStyle(isComplete ? .green : .secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if isShortage, let d = qtyDelta {
                        Label("Mancano \(abs(d))", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)

                        if isComplete {
                            Button {
                                withAnimation(.snappy) { isComplete = false }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Label("Segna incompleta", systemImage: "circle")
                            }
                            .foregroundStyle(.orange)
                        }
                    } else if isSurplus, let d = qtyDelta {
                        Label("In più: +\(d)", systemImage: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                }

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
                    LabeledContent("Da file") {
                        Text(formatIntLike(detail.supplierQuantity) ?? "—")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Contata") {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("—", text: $countedText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .focused($focusedField, equals: .counted)
                                .onChange(of: countedText) { _, _ in
                                    syncCompletionFromCountedText(haptic: true)
                                }

                            if supplierQtyInt != nil,
                               focusedField == .counted,
                               countedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            {
                                Text("✅ automatica quando Contata ≥ Da file")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .transition(.opacity)
                            }
                        }
                        .animation(.snappy, value: focusedField == .counted)
                        .animation(.snappy, value: countedText)
                    }

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
                        HStack(spacing: 8) {
                            TextField("—", text: $newRetailText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .focused($focusedField, equals: .retail)
                                .onChange(of: newRetailText) { _, newValue in
                                    let allowed = Set("0123456789.,")
                                    let filtered = String(newValue.filter { allowed.contains($0) })
                                    if filtered != newValue { newRetailText = filtered }
                                }

                            Button {
                                focusedField = nil
                                showPriceCalculator = true
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                Image(systemName: "calculator")
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Apri calcolatrice prezzo")
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

                Section("Azioni") {
                    Button {
                        focusedField = nil
                        showEditRow = true
                    } label: {
                        Label("Modifica riga", systemImage: "square.and.pencil")
                    }

                    Button {
                        focusedField = nil
                        showGenericCalculator = true
                    } label: {
                        Label("Calcolatrice", systemImage: "calculator")
                    }

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
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Chiudi") {
                        focusedField = nil
                        syncCompletionFromCountedText(haptic: false) // ✅ ricalcolo finale, niente haptic
                        onClose()
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Dettagli riga")
                        .font(.headline)
                        .lineLimit(1)
                }

                // Navigazione riga + Completata in bottom bar
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        goPrev()
                    } label: {
                        Image(systemName: "chevron.up.circle").font(.title3)
                    }
                    .disabled(!canGoPrev)
                    .accessibilityLabel("Riga precedente")

                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onScanNext()
                    } label: {
                        Image(systemName: "barcode.viewfinder").font(.title3)
                    }
                    .accessibilityLabel("Scansiona prossimo prodotto")

                    Spacer(minLength: 0)

                    ViewThatFits(in: .horizontal) {
                        Text("Riga \(displayIndex) di \(totalRows)")
                        Text("\(displayIndex)/\(totalRows)")
                    }
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .layoutPriority(1)

                    Spacer(minLength: 0)

                    Button {
                        if !isComplete, isShortage {
                            showForceCompleteConfirm = true
                        } else {
                            withAnimation(.snappy) { isComplete.toggle() }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    } label: {
                        Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(isComplete ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isComplete ? "Completata" : "Incompleta")
                    .accessibilityHint("Tocca per cambiare stato")

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        goNext()
                    } label: {
                        Image(systemName: "chevron.down.circle").font(.title3)
                    }
                    .disabled(!canGoNext)
                    .accessibilityLabel("Riga successiva")
                }
            }
            .toolbar {
                // Toolbar sopra tastiera (Apple-like)
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
            .confirmationDialog(
                qtyDelta == nil ? "Mancano merce" : "Mancano \(abs(qtyDelta!))",
                isPresented: $showForceCompleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Segna completata comunque") {
                    withAnimation(.snappy) { isComplete = true }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                Button("Annulla", role: .cancel) { }
            } message: {
                Text("Da file: \(formatIntLike(detail.supplierQuantity) ?? "—")\nContata: \(countedText.isEmpty ? "—" : countedText)")
            }
            // Calcolatrici
            .sheet(isPresented: $showPriceCalculator) {
                CalculatorSheetView(
                    title: "Calcolatrice prezzo",
                    initialExpression: newRetailText,
                    applyActions: [
                        .init(title: "Applica a Vendita (nuovo)") { value in
                            newRetailText = formatResult(value, maxFractionDigits: 2)
                        }
                    ],
                    showsCopyButton: true
                )
            }
            .sheet(isPresented: $showGenericCalculator) {
                CalculatorSheetView(
                    title: "Calcolatrice",
                    initialExpression: "",
                    applyActions: [
                        .init(title: "Usa per Contata") { value in
                            countedText = String(Int(value.rounded()))
                        },
                        .init(title: "Usa per Vendita (nuovo)") { value in
                            newRetailText = formatResult(value, maxFractionDigits: 2)
                        }
                    ],
                    showsCopyButton: true
                )
            }
            // Modifica riga (griglia)
            .sheet(isPresented: $showEditRow) {
                NavigationStack {
                    RowEditSheetView(
                        bindings: editBindings,
                        snapshot: editSnapshot,
                        onSaved: {
                            onRefreshRow(detail.rowIndex)
                        }
                    )
                }
            }
            .onAppear {
                if detail.autoFocusCounted {
                    DispatchQueue.main.async {
                        focusedField = .counted
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var totalRows: Int { rowOrder.count }
    private var displayIndex: Int { currentIndex + 1 } // 1-based

    private func goPrev() {
        guard canGoPrev else { return }
        onNavigateToRow(rowOrder[currentIndex - 1])
    }

    private func goNext() {
        guard canGoNext else { return }
        onNavigateToRow(rowOrder[currentIndex + 1])
    }

    private func syncCompletionFromCountedText(haptic: Bool) {
        // 1) solo numeri
        let filtered = countedText.filter(\.isNumber)
        if filtered != countedText { countedText = filtered }

        // 2) serve “Da file”
        guard let s = supplierQtyInt else { return }

        let t = countedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let c = Int(t) else {
            // se svuota/non valido -> incompleta
            if isComplete {
                withAnimation(.snappy) { isComplete = false }
            }
            return
        }

        let shouldBeComplete = (c >= s)
        if shouldBeComplete != isComplete {
            withAnimation(.snappy) { isComplete = shouldBeComplete }
            if haptic {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
    
    private func parseIntLike(_ raw: String?) -> Int? {
        guard let s = formatIntLike(raw), let i = Int(s) else { return nil }
        return i
    }

    private func formatResult(_ value: Double, maxFractionDigits: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale.current
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = maxFractionDigits
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }

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
        if d.rounded() == d { return String(Int(d)) }
        return String(d)
    }
}

// MARK: - Row edit (modifica valori nella griglia)

private struct RowEditBindings {
    var barcode: Binding<String>?
    var itemNumber: Binding<String>?
    var productName: Binding<String>?
    var secondProductName: Binding<String>?
    var quantity: Binding<String>?
    var purchasePrice: Binding<String>?
    var totalPrice: Binding<String>?
    var retailPrice: Binding<String>?
    var discountedPrice: Binding<String>?
    var supplier: Binding<String>?
    var category: Binding<String>?
}

private struct RowEditSnapshot {
    var barcode: String?
    var itemNumber: String?
    var productName: String?
    var secondProductName: String?
    var quantity: String?
    var purchasePrice: String?
    var totalPrice: String?
    var retailPrice: String?
    var discountedPrice: String?
    var supplier: String?
    var category: String?
}

private struct RowEditSheetView: View {
    let bindings: RowEditBindings
    let snapshot: RowEditSnapshot
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var barcode: String
    @State private var itemNumber: String
    @State private var productName: String
    @State private var secondProductName: String

    @State private var quantity: String
    @State private var purchasePrice: String
    @State private var totalPrice: String
    @State private var retailPrice: String
    @State private var discountedPrice: String

    @State private var supplier: String
    @State private var category: String

    init(bindings: RowEditBindings, snapshot: RowEditSnapshot, onSaved: @escaping () -> Void) {
        self.bindings = bindings
        self.snapshot = snapshot
        self.onSaved = onSaved

        _barcode = State(initialValue: snapshot.barcode ?? bindings.barcode?.wrappedValue ?? "")
        _itemNumber = State(initialValue: snapshot.itemNumber ?? bindings.itemNumber?.wrappedValue ?? "")
        _productName = State(initialValue: snapshot.productName ?? bindings.productName?.wrappedValue ?? "")
        _secondProductName = State(initialValue: snapshot.secondProductName ?? bindings.secondProductName?.wrappedValue ?? "")

        _quantity = State(initialValue: snapshot.quantity ?? bindings.quantity?.wrappedValue ?? "")
        _purchasePrice = State(initialValue: snapshot.purchasePrice ?? bindings.purchasePrice?.wrappedValue ?? "")
        _totalPrice = State(initialValue: snapshot.totalPrice ?? bindings.totalPrice?.wrappedValue ?? "")
        _retailPrice = State(initialValue: snapshot.retailPrice ?? bindings.retailPrice?.wrappedValue ?? "")
        _discountedPrice = State(initialValue: snapshot.discountedPrice ?? bindings.discountedPrice?.wrappedValue ?? "")

        _supplier = State(initialValue: snapshot.supplier ?? bindings.supplier?.wrappedValue ?? "")
        _category = State(initialValue: snapshot.category ?? bindings.category?.wrappedValue ?? "")
    }

    var body: some View {
        Form {
            Section {
                Text("Modifica i valori *della riga nella griglia*. Non aggiorna il database prodotti.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if anyIdentifiers {
                Section("Identificativi") {
                    if bindings.barcode != nil {
                        TextField("Barcode", text: $barcode)
                            .keyboardType(.numberPad)
                    }
                    if bindings.itemNumber != nil {
                        TextField("Numero articolo", text: $itemNumber)
                    }
                }
            }

            if anyNames {
                Section("Nomi") {
                    if bindings.productName != nil {
                        TextField("Nome prodotto", text: $productName)
                    }
                    if bindings.secondProductName != nil {
                        TextField("Secondo nome", text: $secondProductName)
                    }
                }
            }

            if anyNumbers {
                Section("Dati") {
                    if bindings.quantity != nil {
                        TextField("Quantità (da file)", text: $quantity)
                            .keyboardType(.numberPad)
                    }
                    if bindings.purchasePrice != nil {
                        TextField("Prezzo acquisto", text: $purchasePrice)
                            .keyboardType(.decimalPad)
                    }
                    if bindings.totalPrice != nil {
                        TextField("Prezzo totale", text: $totalPrice)
                            .keyboardType(.decimalPad)
                    }
                    if bindings.retailPrice != nil {
                        TextField("Prezzo vendita (file)", text: $retailPrice)
                            .keyboardType(.decimalPad)
                    }
                    if bindings.discountedPrice != nil {
                        TextField("Prezzo scontato", text: $discountedPrice)
                            .keyboardType(.decimalPad)
                    }
                }
            }

            if anyMeta {
                Section("Meta") {
                    if bindings.supplier != nil {
                        TextField("Fornitore", text: $supplier)
                    }
                    if bindings.category != nil {
                        TextField("Categoria", text: $category)
                    }
                }
            }
        }
        .navigationTitle("Modifica riga")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Annulla") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Salva") {
                    apply()
                    onSaved()
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
    }

    private var anyIdentifiers: Bool { bindings.barcode != nil || bindings.itemNumber != nil }
    private var anyNames: Bool { bindings.productName != nil || bindings.secondProductName != nil }
    private var anyNumbers: Bool {
        bindings.quantity != nil || bindings.purchasePrice != nil || bindings.totalPrice != nil ||
        bindings.retailPrice != nil || bindings.discountedPrice != nil
    }
    private var anyMeta: Bool { bindings.supplier != nil || bindings.category != nil }

    private func apply() {
        // Nota: qui potresti normalizzare (trim, virgole, ecc). Per ora trim leggero.
        if let b = bindings.barcode { b.wrappedValue = barcode.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let b = bindings.itemNumber { b.wrappedValue = itemNumber.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let b = bindings.productName { b.wrappedValue = productName.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let b = bindings.secondProductName { b.wrappedValue = secondProductName.trimmingCharacters(in: .whitespacesAndNewlines) }

        if let b = bindings.quantity { b.wrappedValue = quantity.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let b = bindings.purchasePrice { b.wrappedValue = purchasePrice.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let b = bindings.totalPrice { b.wrappedValue = totalPrice.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let b = bindings.retailPrice { b.wrappedValue = retailPrice.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let b = bindings.discountedPrice { b.wrappedValue = discountedPrice.trimmingCharacters(in: .whitespacesAndNewlines) }

        if let b = bindings.supplier { b.wrappedValue = supplier.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let b = bindings.category { b.wrappedValue = category.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}

// MARK: - Calculator (sheet)

private struct CalculatorSheetView: View {
    struct ApplyAction: Identifiable {
        let id = UUID()
        let title: String
        let apply: (Double) -> Void
    }

    let title: String
    let initialExpression: String
    let applyActions: [ApplyAction]
    let showsCopyButton: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var expression: String
    @State private var result: Double? = nil

    init(title: String, initialExpression: String, applyActions: [ApplyAction], showsCopyButton: Bool) {
        self.title = title
        self.initialExpression = initialExpression
        self.applyActions = applyActions
        self.showsCopyButton = showsCopyButton
        _expression = State(initialValue: initialExpression)
    }

    private let grid = [
        ["7","8","9","÷"],
        ["4","5","6","×"],
        ["1","2","3","−"],
        ["0",".","⌫","+"],
        ["(",")","C","="]
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Espressione", text: $expression)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.title3, design: .monospaced))
                        .onChange(of: expression) { _, _ in
                            evaluatePreview()
                        }

                    HStack {
                        Text("Risultato")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(resultText)
                            .font(.system(.title3, design: .monospaced))
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(grid.flatMap { $0 }, id: \.self) { key in
                        Button {
                            handleKey(key)
                        } label: {
                            Text(key)
                                .font(.system(.title3, design: .monospaced))
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal)

                if showsCopyButton || !applyActions.isEmpty {
                    Divider().padding(.top, 4)

                    VStack(spacing: 10) {
                        if showsCopyButton {
                            Button {
                                guard let r = result else { return }
                                UIPasteboard.general.string = format(r, maxFractionDigits: 6)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                            } label: {
                                Label("Copia risultato", systemImage: "doc.on.doc")
                            }
                            .disabled(result == nil)
                        }

                        ForEach(applyActions) { action in
                            Button(action.title) {
                                guard let r = result else { return }
                                action.apply(r)
                                UINotificationFeedbackGenerator().notificationOccurred(.success)
                                dismiss()
                            }
                            .disabled(result == nil)
                            .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                }

                Spacer(minLength: 0)
            }
            .navigationTitle(title)
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .onAppear { evaluatePreview() }
        }
    }

    private var resultText: String {
        guard let r = result else { return "—" }
        return format(r, maxFractionDigits: 6)
    }

    private func handleKey(_ key: String) {
        switch key {
        case "C":
            expression = ""
            result = nil
        case "⌫":
            if !expression.isEmpty { expression.removeLast() }
            evaluatePreview()
        case "=":
            evaluatePreview()
            if let r = result {
                expression = format(r, maxFractionDigits: 6)
            }
        case "×":
            expression.append("*")
        case "÷":
            expression.append("/")
        case "−":
            expression.append("-")
        default:
            expression.append(key)
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func evaluatePreview() {
        result = ExpressionEvaluator.evaluate(expression)
    }

    private func format(_ value: Double, maxFractionDigits: Int) -> String {
        let f = NumberFormatter()
        f.locale = Locale.current
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = maxFractionDigits
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }
}

// MARK: - Expression evaluator ( + - * / e parentesi )

private enum ExpressionEvaluator {
    private enum Token {
        case number(Double)
        case op(Character)
        case lparen
        case rparen
        case unaryMinus
    }

    static func evaluate(_ raw: String) -> Double? {
        let s = raw
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: " ", with: "")
        let tokens = tokenize(s)
        guard !tokens.isEmpty else { return nil }
        let rpn = toRPN(tokens)
        return evalRPN(rpn)
    }

    private static func tokenize(_ s: String) -> [Token] {
        var out: [Token] = []
        var i = s.startIndex
        var prevWasValue = false

        func peekPrevIsValue() -> Bool { prevWasValue }

        while i < s.endIndex {
            let ch = s[i]

            if ch.isNumber || ch == "." {
                var j = i
                while j < s.endIndex, (s[j].isNumber || s[j] == ".") { j = s.index(after: j) }
                let numStr = String(s[i..<j])
                if let v = Double(numStr) {
                    out.append(.number(v))
                    prevWasValue = true
                }
                i = j
                continue
            }

            if ch == "(" {
                out.append(.lparen)
                prevWasValue = false
                i = s.index(after: i)
                continue
            }

            if ch == ")" {
                out.append(.rparen)
                prevWasValue = true
                i = s.index(after: i)
                continue
            }

            if "+-*/".contains(ch) {
                if ch == "-" && !peekPrevIsValue() {
                    out.append(.unaryMinus)
                } else {
                    out.append(.op(ch))
                }
                prevWasValue = false
                i = s.index(after: i)
                continue
            }

            // ignora caratteri non validi
            i = s.index(after: i)
        }

        return out
    }

    private static func precedence(_ t: Token) -> Int {
        switch t {
        case .unaryMinus: return 3
        case .op(let c):
            switch c {
            case "*", "/": return 2
            case "+", "-": return 1
            default: return 0
            }
        default:
            return 0
        }
    }

    private static func isLeftAssociative(_ t: Token) -> Bool {
        switch t {
        case .unaryMinus: return false
        case .op: return true
        default: return true
        }
    }

    private static func toRPN(_ tokens: [Token]) -> [Token] {
        var output: [Token] = []
        var stack: [Token] = []

        for t in tokens {
            switch t {
            case .number:
                output.append(t)

            case .unaryMinus, .op:
                while let top = stack.last {
                    if case .op = top, (precedence(top) > precedence(t) || (precedence(top) == precedence(t) && isLeftAssociative(t))) {
                        output.append(stack.removeLast())
                    } else if case .unaryMinus = top, (precedence(top) > precedence(t) || (precedence(top) == precedence(t) && isLeftAssociative(t))) {
                        output.append(stack.removeLast())
                    } else {
                        break
                    }
                }
                stack.append(t)

            case .lparen:
                stack.append(t)

            case .rparen:
                while let top = stack.last {
                    stack.removeLast()
                    if case .lparen = top { break }
                    output.append(top)
                }
            }
        }

        while let top = stack.popLast() {
            if case .lparen = top { continue }
            output.append(top)
        }
        return output
    }

    private static func evalRPN(_ tokens: [Token]) -> Double? {
        var stack: [Double] = []

        for t in tokens {
            switch t {
            case .number(let v):
                stack.append(v)

            case .unaryMinus:
                guard let a = stack.popLast() else { return nil }
                stack.append(-a)

            case .op(let c):
                guard let b = stack.popLast(), let a = stack.popLast() else { return nil }
                switch c {
                case "+": stack.append(a + b)
                case "-": stack.append(a - b)
                case "*": stack.append(a * b)
                case "/":
                    if b == 0 { return nil }
                    stack.append(a / b)
                default:
                    return nil
                }

            default:
                return nil
            }
        }

        return stack.count == 1 ? stack[0] : nil
    }
}


private struct InventorySearchSheet: View {
    let data: [[String]]
    let onJumpToRow: (Int) -> Void
    let onOpenDetail: (Int) -> Void
    let onApplyBarcode: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @State private var showScanner: Bool = false
    @FocusState private var isSearchFocused: Bool

    private var header: [String] { data.first ?? [] }

    private var idxBarcode: Int? { header.firstIndex(of: "barcode") }
    private var idxCode: Int? { header.firstIndex(of: "itemNumber") }
    private var idxName: Int? { header.firstIndex(of: "productName") ?? header.firstIndex(of: "secondProductName") }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func cell(_ row: [String], _ idx: Int?) -> String {
        guard let idx, row.indices.contains(idx) else { return "" }
        return row[idx].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matches(row: [String], query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return false }

        return cell(row, idxBarcode).localizedCaseInsensitiveContains(q)
            || cell(row, idxCode).localizedCaseInsensitiveContains(q)
            || cell(row, idxName).localizedCaseInsensitiveContains(q)
    }

    private var results: [Int] {
        guard data.count > 1 else { return [] }
        let q = trimmedQuery
        guard !q.isEmpty else { return [] }

        return (1..<data.count)
            .filter { matches(row: data[$0], query: q) }
            .prefix(200)
            .map { $0 }
    }

    private var canApplyBarcode: Bool {
        let q = trimmedQuery
        guard !q.isEmpty else { return false }
        // “probabile barcode”: solo cifre e un minimo di lunghezza (tweak libero)
        return q.range(of: #"^\d{4,}$"#, options: .regularExpression) != nil
    }
    
    private func submitSearch() {
        if results.isEmpty, canApplyBarcode {
            onApplyBarcode(trimmedQuery)
            dismiss()
        }
    }
    
    private var resultsList: some View {
        ForEach(results, id: \.self) { rowIndex in
            let row = data[rowIndex]
            let name = cell(row, idxName)
            let barcode = cell(row, idxBarcode)

            Button {
                // 1) porta la griglia sulla riga (UX molto utile)
                onJumpToRow(rowIndex)

                // 2) apri dettagli (azione primaria attesa su iOS)
                onOpenDetail(rowIndex)

                // 3) chiudi sheet ricerca
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        highlightedName(name.isEmpty ? "—" : name, query: trimmedQuery)
                            .lineLimit(1)

                        let code = cell(row, idxCode)

                        HStack(spacing: 8) {
                            if !barcode.isEmpty { highlightedMono(barcode, query: trimmedQuery).foregroundStyle(.secondary) }
                            if !barcode.isEmpty && !code.isEmpty { Text("•").foregroundStyle(.tertiary) }
                            if !code.isEmpty { highlightedMono(code, query: trimmedQuery).foregroundStyle(.secondary) }

                            Spacer()
                            Text("#\(rowIndex)")
                        }
                        .font(.footnote)
                    }

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowSeparator(.visible)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
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
    
    @ViewBuilder
    private var resultsHeaderRow: some View {
        if results.count > 0 {
            HStack {
                Text("Risultati (\(results.count))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 6, trailing: 16))
            .listRowSeparator(.hidden)                 // 👈 via la linea sopra/sotto
            .listRowBackground(Color.clear)
            .overlay(alignment: .bottom) { Divider() } // 👈 una sola linea sotto (pulita)
            .allowsHitTesting(false)
        }
    }
    
    private func highlightedName(_ name: String, query: String) -> Text {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return Text(name) }

        var attr = AttributedString(name)
        attr.font = .body

        var searchRange = name.startIndex..<name.endIndex
        while let r = name.range(
            of: q,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchRange
        ) {
            if let start = AttributedString.Index(r.lowerBound, within: attr),
               let end = AttributedString.Index(r.upperBound, within: attr) {
                attr[start..<end].font = .body.weight(.semibold)
            }
            searchRange = r.upperBound..<name.endIndex
        }

        return Text(attr)
    }
    
    private func highlightedMono(_ value: String, query: String) -> Text {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var attr = AttributedString(value)
        attr.font = .system(.footnote, design: .monospaced)

        guard !q.isEmpty else { return Text(attr) }

        var searchRange = value.startIndex..<value.endIndex
        while let r = value.range(of: q, options: [.caseInsensitive, .diacriticInsensitive], range: searchRange) {
            if let s = AttributedString.Index(r.lowerBound, within: attr),
               let e = AttributedString.Index(r.upperBound, within: attr) {
                attr[s..<e].font = .system(.footnote, design: .monospaced).weight(.semibold)
            }
            searchRange = r.upperBound..<value.endIndex
        }
        return Text(attr)
    }

    var body: some View {
        List {
            if trimmedQuery.isEmpty {
                emptyState
            } else {
                resultsHeaderRow

                if results.isEmpty {
                    noResultsState
                } else {
                    resultsList
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Cerca")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Chiudi") { dismiss() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                AppleLikeSearchField(
                    placeholder: "Barcode, codice, nome…",
                    text: $searchText,
                    showScanner: $showScanner,
                    onSubmit: submitSearch,
                    focused: $isSearchFocused
                )
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color(uiColor: .separator).opacity(0.25), lineWidth: 0.5)
            )
            .padding(.horizontal)
            .shadow(radius: 12, x: 0, y: 6)
        }
        .onAppear { isSearchFocused = true }
        .sheet(isPresented: $showScanner) {
            ScannerView(title: "Scanner barcode") { code in
                searchText = code
                showScanner = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isSearchFocused = true
                }
            }
        }
        .modifier(TopGapFix())
    }
    
    @ViewBuilder
    private var emptyState: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(
                "Cerca un prodotto",
                systemImage: "magnifyingglass",
                description: Text("Digita barcode, codice o nome.")
            )
            .frame(maxWidth: .infinity, minHeight: 260)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } else {
            Text("Digita barcode, codice o nome.")
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var noResultsState: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView(
                "Nessun risultato",
                systemImage: "magnifyingglass",
                description: Text("Prova con un barcode/codice/nome diverso.")
            )
            .frame(maxWidth: .infinity, minHeight: 220)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        } else {
            Text("Nessun risultato")
                .foregroundStyle(.secondary)
                .listRowBackground(Color.clear)
        }

        if canApplyBarcode {
            Button {
                onApplyBarcode(trimmedQuery)
                dismiss()
            } label: {
                Label("Applica barcode \(trimmedQuery)", systemImage: "plus.circle.fill")
            }
        }
    }
}

private struct TopGapFix: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.contentMargins(.top, 0, for: .scrollContent) // da -2 → 0
        } else {
            content
        }
    }
}

private struct AppleLikeSearchField: View {
    let placeholder: String
    @Binding var text: String
    @Binding var showScanner: Bool
    var onSubmit: () -> Void

    @FocusState.Binding var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .focused($focused)
                .textInputAutocapitalization(.never)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit {
                        onSubmit()
                        focused = false
                    }

            if !text.isEmpty {
                Button {
                    text = ""
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Svuota ricerca")
            }

            Divider()
                .frame(height: 20)

            Button {
                focused = false
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                showScanner = true
            } label: {
                Image(systemName: "barcode.viewfinder")
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scanner")
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
        )
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
