import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    @State private var filePickerMode: FilePickerMode = .append
    @State private var isFileImporterPresented = false
    @State private var filePickerError: String?

    private let suggestionDebounceMs: UInt64 = 220

    private enum FilePickerMode {
        case append
        case reload
    }

    private var errorAlertTitle: String {
        generationError != nil ? L("pregenerate.error.generation_title") : L("pregenerate.error.title")
    }

    private var errorAlertMessage: String {
        generationError ?? filePickerError ?? L("pregenerate.error.unknown")
    }

    private var isErrorAlertPresented: Binding<Bool> {
        Binding(
            get: { generationError != nil || filePickerError != nil },
            set: { newValue in
                if !newValue {
                    generationError = nil
                    filePickerError = nil
                }
            }
        )
    }
    
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
                Section(L("pregenerate.preview.title")) {
                    if excelSession.rows.isEmpty {
                        Text(L("pregenerate.preview.no_file"))
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
                        
                        Text(L("pregenerate.preview.rows_shown", previewRows.count, max(excelSession.rows.count - 1, 0)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        
                        // 🔎 Badge affidabilità analisi
                        if let confidence = excelSession.analysisConfidence {
                            HStack {
                                Label(L("pregenerate.preview.analysis_reliability"), systemImage: "chart.bar.fill")
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
                                Text(L("pregenerate.preview.tips_title"))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                
                                if let metrics = excelSession.analysisMetrics {
                                    if metrics.essentialColumnsFound < metrics.essentialColumnsTotal {
                                        Text(L("pregenerate.preview.tip_required_columns"))
                                            .font(.caption2)
                                    }
                                    
                                    if metrics.totalRows > 0 &&
                                        Double(metrics.rowsWithValidBarcode) / Double(metrics.totalRows) < 0.3 {
                                        Text(L("pregenerate.preview.tip_barcode"))
                                            .font(.caption2)
                                    }
                                    
                                    if !metrics.issues.isEmpty {
                                        Text(L("pregenerate.preview.tip_resolve_issues"))
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
                Section(L("pregenerate.columns.title")) {
                    if excelSession.normalizedHeader.isEmpty {
                        Text(L("pregenerate.columns.none"))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(excelSession.sortedColumnIndices, id: \.self) { index in
                            ColumnSelectionRow(index: index)
                        }
                        
                        
                        HStack {
                            Button(L("pregenerate.columns.select_all")) {
                                excelSession.setAllColumns(selected: true, keepEssential: false)
                            }
                            Button(L("pregenerate.columns.deselect_all")) {
                                excelSession.setAllColumns(selected: false, keepEssential: true)
                            }
                        }
                        .buttonStyle(.borderless)
                        
                        Text(L("pregenerate.columns.required_footer"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // FORNITORE & CATEGORIA (come in EditProductView)
                Section(L("pregenerate.supplier.title")) {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField(L("product.field.supplier_name"), text: $excelSession.supplierName)
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
                        Label(L("pregenerate.show_all"), systemImage: "magnifyingglass")
                    }
                }
                
                Section(L("pregenerate.category.title")) {
                    VStack(alignment: .leading, spacing: 6) {
                        TextField(L("product.field.category_name"), text: $excelSession.categoryName)
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
                        Label(L("pregenerate.show_all"), systemImage: "magnifyingglass")
                    }
                }
                
                // Step successivi: qui comparirà il pulsante "Genera inventario"
                
                // GENERAZIONE INVENTARIO (HistoryEntry)
                Section {
                    // Mostra il toggle solo se la confidenza è molto bassa
                    if let confidence = excelSession.analysisConfidence,
                       confidence < 0.4 {
                        Toggle(L("pregenerate.ignore_warnings"), isOn: $ignoreWarnings)
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
                                Text(L("pregenerate.generating"))
                            }
                        } else {
                            Text(L("pregenerate.generate"))
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canGenerate || isGenerating)
                    
                    if let lastID = lastGeneratedEntryID {
                        Text(L("pregenerate.last_generated", lastID))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(L("pregenerate.generated_will_appear"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(L("pregenerate.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog(
            L("pregenerate.low_confidence.title"),
            isPresented: $showLowConfidenceConfirm,
            titleVisibility: .visible
        ) {
            Button(L("pregenerate.low_confidence.proceed"), role: .destructive) {
                // se vuoi: ricordati la scelta per questa sessione
                ignoreWarnings = true
                generateInventory()
            }
            Button(L("common.cancel"), role: .cancel) { }
        } message: {
            Text(L("pregenerate.low_confidence.message"))
        }
        // lascia qui TUTTI i tuoi modifier: alert, navigationDestination, sheet, toolbar, task, ecc.
        .alert(errorAlertTitle, isPresented: isErrorAlertPresented) {
            Button(L("common.ok"), role: .cancel) {
                generationError = nil
                filePickerError = nil
            }
        } message: {
            Text(errorAlertMessage)
        }
        .navigationDestination(isPresented: $navigateToGenerated) {
            Group {
                if let entry = excelSession.currentHistoryEntry {
                    GeneratedView(entry: entry, onDone: {
                        if let onExitToHome {
                            onExitToHome()      // chiude PreGenerate (e quindi anche Generated) direttamente
                        } else {
                            navigateToGenerated = false
                            dismiss()
                        }
                    })
                } else {
                    Text(L("inventory.home.no_inventory"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .sheet(isPresented: $showAllSuppliersSheet) {
            NamePickerSheet(
                title: L("entry.info.suppliers_title"),
                allItems: suppliers.map(\.name),
                selection: $excelSession.supplierName
            )
        }
        .sheet(isPresented: $showAllCategoriesSheet) {
            NamePickerSheet(
                title: L("entry.info.categories_title"),
                allItems: categories.map(\.name),
                selection: $excelSession.categoryName
            )
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.spreadsheet, .html],
            allowsMultipleSelection: true
        ) { result in
            let mode = filePickerMode

            switch result {
            case .success(let urls):
                guard !urls.isEmpty else { return }

                Task {
                    let accessFlags = urls.map { $0.startAccessingSecurityScopedResource() }
                    defer {
                        for (url, accessing) in zip(urls, accessFlags) where accessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }

                    do {
                        switch mode {
                        case .append:
                            try await excelSession.appendRows(from: urls)
                        case .reload:
                            try await excelSession.load(from: urls, in: context)
                            ignoreWarnings = false
                        }
                    } catch {
                        filePickerError = excelSession.lastError ?? error.localizedDescription
                    }
                }

            case .failure(let error):
                filePickerError = error.localizedDescription
            }
        }
        .scrollDismissesKeyboard(.interactively)   // scroll = chiude tastiera (super iOS)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    filePickerMode = .append
                    isFileImporterPresented = true
                } label: {
                    Label(L("pregenerate.add_file"), systemImage: "doc.badge.plus")
                }
                .disabled(excelSession.isLoading || excelSession.rows.isEmpty)

                Button {
                    filePickerMode = .reload
                    isFileImporterPresented = true
                } label: {
                    Label(L("pregenerate.reload_file"), systemImage: "arrow.clockwise")
                }
                .disabled(excelSession.isLoading)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                // pulsante “cancella” contestuale (optional ma molto iOS)
                if focusedField == .supplier, !excelSession.supplierName.isEmpty {
                    Button(L("common.clear")) {
                        excelSession.supplierName = ""
                        debouncedSupplierQuery = ""
                    }
                } else if focusedField == .category, !excelSession.categoryName.isEmpty {
                    Button(L("common.clear")) {
                        excelSession.categoryName = ""
                        debouncedCategoryQuery = ""
                    }
                }

                Spacer()

                Button(L("common.done")) { focusedField = nil }
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
    
    private func previewDisplayValue(for key: String, raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return "" }

        let cleaned = t.normalizedExcelNumberString()

        let numericKeys: Set<String> = [
            "quantity", "purchasePrice", "totalPrice",
            "retailPrice", "discountedPrice",
            "realQuantity", "oldPurchasePrice", "oldRetailPrice",
            "RetailPrice"
        ]
        guard numericKeys.contains(key) else { return cleaned }

        let normalized = cleaned.replacingOccurrences(of: ",", with: ".")
        guard let d = Double(normalized) else { return cleaned }

        let formatter = NumberFormatter()
        formatter.locale = appLocale()
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: d)) ?? cleaned
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

    private func localizedRoleTitle(_ role: String) -> String {
        switch role {
        case "barcode":
            return L("pregenerate.role.barcode")
        case "productName":
            return L("pregenerate.role.product_name")
        case "secondProductName":
            return L("pregenerate.role.second_product_name")
        case "itemNumber":
            return L("pregenerate.role.item_number")
        case "rowNumber":
            return L("pregenerate.role.row_number")
        case "quantity":
            return L("pregenerate.role.quantity")
        case "purchasePrice":
            return L("pregenerate.role.purchase_price")
        case "totalPrice":
            return L("pregenerate.role.total_price")
        case "retailPrice":
            return L("pregenerate.role.retail_price")
        case "discountedPrice":
            return L("pregenerate.role.discounted_price")
        case "supplier":
            return L("pregenerate.role.supplier")
        case "category":
            return L("pregenerate.role.category")
        default:
            return role
        }
    }

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
        let displayHeader = fileHeader.isEmpty ? L("pregenerate.column.numbered", index + 1) : fileHeader

        // ✅ Ruolo assegnato (se è un ruolo noto)
        let roleKey = excelSession.roleKeyForColumn(index)               // es: "rowNumber" oppure nil
        let roleTitle = roleKey.map(localizedRoleTitle) ?? L("pregenerate.column.unknown")

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
                        Text(L("pregenerate.column.required"))
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
                                    Label(localizedRoleTitle(roleKey), systemImage: "checkmark")
                                } else {
                                    Text(localizedRoleTitle(roleKey))
                                }
                            }
                        }

                        Divider()

                        if !excelSession.isColumnEssential(at: index) {
                            Button(role: .destructive) {
                                excelSession.clearColumnRole(at: index)
                            } label: {
                                Label(L("pregenerate.column.no_type"), systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        Label(L("pregenerate.column.change_type"), systemImage: "slider.horizontal.3")
                            .labelStyle(.iconOnly)
                            .imageScale(.medium)
                    }
                }

                // ✅ SOTTO = nome originale della colonna nel file
                Text(L("common.file_column", displayHeader))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Se vuoi, puoi comunque mostrare “chiave normalizzata” quando non è un ruolo noto:
                if roleKey == nil && !normalized.isEmpty && normalized != fileHeader {
                    Text(L("common.identifier", normalized))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Esempi di valori
                if !sample.isEmpty {
                    Text(L("common.examples", sample))
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
                        Label(L("pregenerate.name_picker.use_value", searchText.trimmingCharacters(in: .whitespacesAndNewlines)), systemImage: "plus")
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
            .searchable(text: $searchText, prompt: L("common.search"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.close")) { dismiss() }
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
