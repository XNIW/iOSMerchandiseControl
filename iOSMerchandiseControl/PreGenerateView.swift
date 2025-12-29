import SwiftUI
import SwiftData

/// Schermata equivalente a PreGenerateScreen su Android:
/// - mostra anteprima header + qualche riga
/// - permette di abilitare/disabilitare colonne
/// - chiede fornitore e categoria con suggerimenti da SwiftData
struct PreGenerateView: View {
    var onExitToHome: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    
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
    
    private enum FocusField { case supplier, category }
    @FocusState private var focusedField: FocusField?

    @State private var showAllSuppliersSheet = false
    @State private var showAllCategoriesSheet = false
    
    @State private var debouncedSupplierQuery = ""
    @State private var debouncedCategoryQuery = ""
    
    @State private var showLowConfidenceConfirm = false

    private let suggestionDebounceMs: UInt64 = 220
    
    var body: some View {
        ZStack {
            // ✅ tap “dietro” al Form: non ruba i tap ai Button
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                }
            
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
                                    ForEach(Array(excelSession.normalizedHeader.enumerated()), id: \.offset) { index, key in
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
                                        ForEach(excelSession.normalizedHeader.indices, id: \.self) { colIdx in
                                            if excelSession.selectedColumns.indices.contains(colIdx),
                                               excelSession.selectedColumns[colIdx] {
                                                let key = excelSession.normalizedHeader[colIdx]
                                                let width = columnWidth(for: key)
                                                let value = colIdx < row.count ? row[colIdx] : ""
                                                
                                                let shown = previewDisplayValue(for: key, raw: value)

                                                Text(shown)
                                                    .font(
                                                        isNumericColumn(key)
                                                        ? .system(.caption2, design: .monospaced)
                                                        : .caption2
                                                    )
                                                    .lineLimit(1)
                                                    .truncationMode(.tail)
                                                    .frame(width: width, alignment: .leading)
                                                    .monospacedDigit()
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
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                        }
                    }
                }
                
                // SELEZIONE COLONNE
                Section("Colonne da usare") {
                    if excelSession.normalizedHeader.isEmpty {
                        Text("Nessuna colonna disponibile.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(excelSession.sortedColumnIndices, id: \.self) { index in
                            ColumnSelectionRow(index: index)
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
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Nome fornitore", text: $excelSession.supplierName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .supplier)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                        
                        let live = excelSession.supplierName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let q = debouncedSupplierQuery
                        
                        if focusedField == .supplier, !q.isEmpty, q == live {
                            InlineSuggestionsBox(
                                query: q,
                                suggestions: rankedSuggestions(all: suppliers.map(\.name), query: q),
                                onPick: { picked in
                                    excelSession.supplierName = picked
                                    focusedField = nil
                                }
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.15), value: debouncedSupplierQuery)
                    
                    Button {
                        focusedField = nil
                        showAllSuppliersSheet = true
                    } label: {
                        Label("Mostra tutti…", systemImage: "magnifyingglass")
                    }
                }
                
                Section("Categoria") {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Nome categoria", text: $excelSession.categoryName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .category)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                        
                        let live = excelSession.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let q = debouncedCategoryQuery
                        
                        if focusedField == .category, !q.isEmpty, q == live {
                            InlineSuggestionsBox(
                                query: q,
                                suggestions: rankedSuggestions(all: categories.map(\.name), query: q),
                                onPick: { picked in
                                    excelSession.categoryName = picked
                                    focusedField = nil
                                }
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.15), value: debouncedCategoryQuery)
                    
                    Button {
                        focusedField = nil
                        showAllCategoriesSheet = true
                    } label: {
                        Label("Mostra tutti…", systemImage: "magnifyingglass")
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
                        focusedField = nil

                        let confidence = excelSession.analysisConfidence ?? 1.0
                        if confidence < 0.4 && !ignoreWarnings {
                            showLowConfidenceConfirm = true
                        } else {
                            generateInventory()
                        }
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
        }
        .navigationTitle("Pre-elaborazione")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Analisi poco affidabile",
            isPresented: $showLowConfidenceConfirm,
            titleVisibility: .visible
        ) {
            Button("Procedi comunque", role: .destructive) {
                // se vuoi: ricordati la scelta per questa sessione
                ignoreWarnings = true
                generateInventory()
            }
            Button("Annulla", role: .cancel) { }
        } message: {
            Text("L’analisi del file sembra poco affidabile. Vuoi generare l’inventario lo stesso?")
        }
        // lascia qui TUTTI i tuoi modifier: alert, navigationDestination, sheet, toolbar, task, ecc.
        .alert("Errore durante la generazione", isPresented: Binding(
            get: { generationError != nil },
            set: { newValue in if !newValue { generationError = nil } }
        )) {
            Button("OK", role: .cancel) { generationError = nil }
        } message: {
            Text(generationError ?? "Errore sconosciuto.")
        }
        .navigationDestination(isPresented: $navigateToGenerated) {
            Group {
                if let entry = excelSession.currentHistoryEntry {
                    GeneratedView(entry: entry, onDone: {
                        navigateToGenerated = false

                        if let onExitToHome {
                            onExitToHome()          // <-- torna davvero a InventoryHomeView
                        } else {
                            dismiss()               // <-- fallback (es. se in futuro lo presenti in altro modo)
                        }
                    })
                } else {
                    Text("Nessun inventario disponibile.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showAllSuppliersSheet) {
            NamePickerSheet(
                title: "Fornitori",
                allItems: suppliers.map(\.name),
                selection: $excelSession.supplierName
            )
        }
        .sheet(isPresented: $showAllCategoriesSheet) {
            NamePickerSheet(
                title: "Categorie",
                allItems: categories.map(\.name),
                selection: $excelSession.categoryName
            )
        }
        .scrollDismissesKeyboard(.interactively)   // scroll = chiude tastiera (super iOS)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                // pulsante “cancella” contestuale (optional ma molto iOS)
                if focusedField == .supplier, !excelSession.supplierName.isEmpty {
                    Button("Cancella") {
                        excelSession.supplierName = ""
                        debouncedSupplierQuery = ""
                    }
                } else if focusedField == .category, !excelSession.categoryName.isEmpty {
                    Button("Cancella") {
                        excelSession.categoryName = ""
                        debouncedCategoryQuery = ""
                    }
                }

                Spacer()

                Button("Fine") { focusedField = nil }
                    .fontWeight(.semibold)
            }
        }
        .task(id: excelSession.supplierName) {
            guard focusedField == .supplier else { debouncedSupplierQuery = ""; return }
            let q = excelSession.supplierName.trimmingCharacters(in: .whitespacesAndNewlines)
            try? await Task.sleep(nanoseconds: suggestionDebounceMs * 1_000_000)
            guard !Task.isCancelled else { return }
            debouncedSupplierQuery = q
        }
        .task(id: excelSession.categoryName) {
            guard focusedField == .category else { debouncedCategoryQuery = ""; return }
            let q = excelSession.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
            try? await Task.sleep(nanoseconds: suggestionDebounceMs * 1_000_000)
            guard !Task.isCancelled else { return }
            debouncedCategoryQuery = q
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
        !excelSession.normalizedHeader.isEmpty &&
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
                let s = excelSession.supplierName.trimmingCharacters(in: .whitespacesAndNewlines)
                if let existing = suppliers.first(where: { $0.name.compare(s, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
                    excelSession.supplierName = existing.name
                }

                let c = excelSession.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                if let existing = categories.first(where: { $0.name.compare(c, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
                    excelSession.categoryName = existing.name
                }
                
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
    
    private static let previewNumberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = .current
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    private func previewDisplayValue(for key: String, raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }

        // ⚠️ NON includere "barcode" qui, per non perdere zeri iniziali
        let numericKeys: Set<String> = [
            "quantity", "purchasePrice", "totalPrice",
            "retailPrice", "discountedPrice",
            "realQuantity", "oldPurchasePrice", "oldRetailPrice",
            "RetailPrice"
        ]
        guard numericKeys.contains(key) else { return t }

        let normalized = t.replacingOccurrences(of: ",", with: ".")
        guard let d = Double(normalized) else { return t }

        return Self.previewNumberFormatter.string(from: NSNumber(value: d)) ?? t
    }
}

struct ColumnRecognitionBadge: View {
    let status: ColumnStatus
    let confidence: Double?

    var body: some View {
        HStack(spacing: 2) {
            switch status {
            case .exactMatch:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .aliasMatch:
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.blue)
            case .normalized:
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(.purple)
            case .generated, .emptyOriginal:
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.orange)
            }

            if let confidence {
                Text("\(Int(confidence * 100))%")
                    .font(.caption2)
            }
        }
    }
}

/// Riga singola nella sezione "Colonne da usare"
struct ColumnSelectionRow: View {
    @EnvironmentObject var excelSession: ExcelSessionViewModel
    let index: Int

    var body: some View {
        let normalized = excelSession.normalizedHeader[index]

        let original: String = {
            if excelSession.originalHeader.indices.contains(index) {
                return excelSession.originalHeader[index]
            } else {
                return ""
            }
        }()

        let isEssential = excelSession.isColumnEssential(at: index)
        let status = excelSession.columnStatus(at: index)
        let sample = excelSession.sampleValuesForColumn(index)

        // ✅ Titolo = nome nel file (originale). Se vuoto → Colonna N
        let fileHeader = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayHeader = fileHeader.isEmpty ? "Colonna \(index + 1)" : fileHeader

        // ✅ Ruolo assegnato (se è un ruolo noto)
        let roleKey = excelSession.roleKeyForColumn(index)               // es: "rowNumber" oppure nil
        let roleTitle = roleKey.map { ExcelSessionViewModel.titleForRole($0) } ?? "Non riconosciuta"

        HStack(alignment: .top, spacing: 12) {

            // SINISTRA: info + menu tipo (sempre attivo)
            VStack(alignment: .leading, spacing: 4) {

                // ✅ TITOLO GRANDE = ruolo assegnato (quello che guida l’app)
                HStack(spacing: 8) {
                    ColumnRecognitionBadge(status: status, confidence: nil)

                    Text(roleTitle)
                        .font(.headline)
                        .fontWeight(.semibold)

                    if isEssential {
                        Text("Obbligatoria")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(.secondarySystemBackground)))
                            .foregroundStyle(.secondary)
                    }

                    // ✅ Icona per cambiare tipo (al posto della riga “Tipo: …”)
                    Menu {
                        let essential = Array(ExcelSessionViewModel.essentialColumnKeys)
                        let otherRoles = ExcelSessionViewModel.overridableRoles
                            .filter { !ExcelSessionViewModel.essentialColumnKeys.contains($0) }
                        let roles = essential + otherRoles

                        ForEach(roles, id: \.self) { roleKey in
                            Button {
                                excelSession.setColumnRole(at: index, to: roleKey)
                            } label: {
                                if excelSession.roleKeyForColumn(index) == roleKey {
                                    Label(ExcelSessionViewModel.titleForRole(roleKey), systemImage: "checkmark")
                                } else {
                                    Text(ExcelSessionViewModel.titleForRole(roleKey))
                                }
                            }
                        }

                        Divider()

                        if !excelSession.isColumnEssential(at: index) {
                            Button(role: .destructive) {
                                excelSession.clearColumnRole(at: index)
                            } label: {
                                Label("Nessun tipo", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Label("Cambia tipo", systemImage: "slider.horizontal.3")
                            .labelStyle(.iconOnly)
                            .imageScale(.medium)
                    }
                }

                // ✅ SOTTO = nome originale della colonna nel file
                Text("Colonna nel file: \(displayHeader)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Se vuoi, puoi comunque mostrare “chiave normalizzata” quando non è un ruolo noto:
                if roleKey == nil && !normalized.isEmpty && normalized != fileHeader {
                    Text("Identificatore: \(normalized)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Esempi di valori
                if !sample.isEmpty {
                    Text("Esempi: \(sample)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // DESTRA: SOLO lo switch, disabilitato se essenziale
            Toggle("", isOn: excelSession.bindingForColumnSelection(at: index))
                .labelsHidden()
                .disabled(isEssential)
        }
        .padding(.vertical, 6)
    }
}



#Preview {
    // Preview minimale: non serve avere dati reali
    NavigationStack {
        PreGenerateView()
            .environmentObject(ExcelSessionViewModel())
    }
}

private func rankedSuggestions(all: [String], query: String, limit: Int = 6) -> [String] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return [] }

    let nq = q.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

    var prefix: [String] = []
    var contains: [String] = []
    prefix.reserveCapacity(limit)
    contains.reserveCapacity(limit)

    for name in all {
        let nn = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if nn == nq { continue } // evita duplicato identico

        if nn.hasPrefix(nq) {
            prefix.append(name)
            if prefix.count == limit { return prefix }
            continue
        }

        if nn.contains(nq) {
            contains.append(name)
            if prefix.count + contains.count == limit { break }
        }
    }

    return prefix + contains
}

private func highlighted(_ text: String, query: String) -> AttributedString {
    var a = AttributedString(text)
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !q.isEmpty else { return a }

    if let r = a.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) {
        a[r].font = .body.bold()
    }
    return a
}

private struct InlineSuggestionsBox: View {
    let query: String
    let suggestions: [String]
    let onPick: (String) -> Void

    var body: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(suggestions, id: \.self) { s in
                    Button {
                        onPick(s)
                    } label: {
                        HStack {
                            Text(highlighted(s, query: query))
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                    }
                    .buttonStyle(.plain)

                    if s != suggestions.last {
                        Divider().padding(.leading, 12)
                    }
                }
            }
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.quaternary, lineWidth: 1)
            )
        }
    }
}

private struct NamePickerSheet: View {
    let title: String
    let allItems: [String]
    @Binding var selection: String

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    @State private var debouncedSearchText = ""
    private let sheetDebounceMs: UInt64 = 180

    private var filtered: [String] {
        let q = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return allItems }
        return rankedSuggestions(all: allItems, query: q, limit: 200)
    }

    private var canCreateNew: Bool {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return false }
        return !allItems.contains(where: { $0.compare(q, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame })
    }

    var body: some View {
        NavigationStack {
            List {
                if canCreateNew {
                    Button {
                        selection = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    } label: {
                        Label("Usa “\(searchText.trimmingCharacters(in: .whitespacesAndNewlines))”", systemImage: "plus")
                    }
                }

                ForEach(filtered, id: \.self) { item in
                    Button {
                        selection = item
                        dismiss()
                    } label: {
                        Text(highlighted(item, query: searchText))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Cerca")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
            .task(id: searchText) {
                let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
                try? await Task.sleep(nanoseconds: sheetDebounceMs * 1_000_000)
                guard !Task.isCancelled else { return }
                debouncedSearchText = q
            }
        }
    }
}
