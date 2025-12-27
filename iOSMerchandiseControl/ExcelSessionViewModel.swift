import Foundation
import SwiftUI
import SwiftData
import Combine
import ZIPFoundation

#if canImport(SwiftSoup)
import SwiftSoup
#endif

enum ColumnStatus {
    case exactMatch      // header = "barcode" → normalized = "barcode"
    case aliasMatch      // header = "codice a barre" → normalized = "barcode"
    case normalized      // header = "Product name" → normalized = "productname"
    case generated       // normalized = "col1", "col2"...
    case emptyOriginal   // header originale vuoto
}

/// ViewModel globale per il flusso Excel
/// (equivalente concettuale di ExcelViewModel su Android)
@MainActor
final class ExcelSessionViewModel: ObservableObject {
    // 🔹 Header originale (dopo rimozione colonne completamente vuote)
    @Published var originalHeader: [String] = []

    // 🔹 Header normalizzato (es. ["barcode", "productName", "purchasePrice", ...])
    @Published var normalizedHeader: [String] = []

    // Tutte le righe dell'Excel (riga 0 = header normalizzato)
    @Published var rows: [[String]] = []

    // Selezione colonne (stessa lunghezza di `normalizedHeader`)
    @Published var selectedColumns: [Bool] = []

    // Parametri "globali" per il file corrente
    @Published var supplierName: String = ""
    @Published var categoryName: String = ""

    // HistoryEntry generata a partire da questo Excel
    @Published var currentHistoryEntry: HistoryEntry?

    // Stato di caricamento (per mostrare eventuale progress)
    @Published var isLoading: Bool = false
    @Published var progress: Double? = nil   // 0.0 ... 1.0
    @Published var lastError: String? = nil

    // Metriche di analisi del file corrente
    @Published var analysisConfidence: Double?
    @Published var analysisMetrics: AnalysisMetrics?

    var hasData: Bool { !rows.isEmpty }

    // Colonne essenziali (come su Android: barcode, productName, purchasePrice)
    static let essentialColumnKeys: Set<String> = [
        "barcode", "productName", "purchasePrice"
    ]

    /// Ordine “logico” delle colonne (obbligatorie prima, poi le altre conosciute)
    private static let columnPriority: [String] = [
        "rowNumber",
        "itemNumber",
        "barcode",
        "productName",
        "secondProductName",
        "quantity",
        "purchasePrice",
        "totalPrice",
        "retailPrice",
        "discountedPrice",
        "discount",
        "supplier",
        "category"
    ]

    /// Indici di colonna ordinati per priorità logica
    var sortedColumnIndices: [Int] {
        return normalizedHeader.indices.sorted { a, b in
            let nameA = normalizedHeader[a]
            let nameB = normalizedHeader[b]

            let priorityA = Self.columnPriority.firstIndex(of: nameA) ?? Int.max
            let priorityB = Self.columnPriority.firstIndex(of: nameB) ?? Int.max

            if priorityA != priorityB {
                return priorityA < priorityB
            }
            // in caso di pari priorità, manteniamo l'ordine originale
            return a < b
        }
    }

    // MARK: - Gestione stato

    func resetState() {
        originalHeader = []
        normalizedHeader = []
        rows = []
        selectedColumns = []
        supplierName = ""
        categoryName = ""
        isLoading = false
        progress = nil
        lastError = nil

        // resetta anche le metriche
        analysisConfidence = nil
        analysisMetrics = nil
    }

    // MARK: - Selezione colonne (equivalente di isColumnEssential)

    func isColumnEssential(at index: Int) -> Bool {
        guard normalizedHeader.indices.contains(index) else { return false }
        return Self.essentialColumnKeys.contains(normalizedHeader[index])
    }

    func updateColumnSelection(index: Int, isSelected: Bool) {
        guard selectedColumns.indices.contains(index) else { return }

        if isColumnEssential(at: index) {
            // Le colonne essenziali non si possono spegnere
            selectedColumns[index] = true
        } else {
            selectedColumns[index] = isSelected
        }
    }

    func setAllColumns(selected: Bool, keepEssential: Bool = true) {
        for idx in selectedColumns.indices {
            if keepEssential && isColumnEssential(at: idx) {
                selectedColumns[idx] = true
            } else {
                selectedColumns[idx] = selected
            }
        }
    }

    /// Binding comodo da usare nei Toggle in SwiftUI
    func bindingForColumnSelection(at index: Int) -> Binding<Bool> {
        Binding(
            get: {
                guard self.selectedColumns.indices.contains(index) else { return true }
                return self.selectedColumns[index]
            },
            set: { newValue in
                self.updateColumnSelection(index: index, isSelected: newValue)
            }
        )
    }
    
/// Stato “qualitativo” di una colonna per la UI
    func columnStatus(at index: Int) -> ColumnStatus {
        // Se l'indice non esiste sull'header normalizzato: fallback neutro
        guard normalizedHeader.indices.contains(index) else {
            return .normalized
        }

        let normalized = normalizedHeader[index]

        // Colonne inserite artificialmente da ensureMandatoryColumns:
        // non esistono in originalHeader → le trattiamo come "generate"
        if !originalHeader.indices.contains(index) {
            return normalized.hasPrefix("col") ? .generated : .normalized
        }

        let original = originalHeader[index]

        if original.isEmpty {
            return .emptyOriginal
        }

        if normalized.hasPrefix("col") {
            return .generated
        }

        if original == normalized {
            return .exactMatch
        }

        if ExcelAnalyzer.isAliasMatch(original: original, normalized: normalized) {
            return .aliasMatch
        }

        return .normalized
    }


    // MARK: - Caricamento file Excel/HTML (Step 1)

    /// Carica e analizza uno o più file (Excel HTML-export) e popola header/rows.
    /// È l'equivalente iOS di loadFromMultipleUris + readAndAnalyzeExcel su Android.
    func load(from urls: [URL], in context: ModelContext) async throws {
        guard !urls.isEmpty else { return }

        resetState()
        isLoading = true
        progress = 0

        do {
            // 🔹 NUOVO: ricevi anche l'header originale
            let (originalHeader, normalizedHeader, allRows) =
                try ExcelAnalyzer.loadFromMultipleURLs(urls)

            // Torniamo sul MainActor
            self.originalHeader = originalHeader
            self.normalizedHeader = normalizedHeader
            self.rows = allRows
            self.selectedColumns = Array(repeating: true, count: normalizedHeader.count)

            // 🔹 calcolo metriche di analisi (usa l'header normalizzato)
            if let metrics = ExcelAnalyzer.computeAnalysisMetrics(
                header: normalizedHeader,
                rows: allRows
            ) {
                self.analysisMetrics = metrics
                self.analysisConfidence = metrics.confidenceScore
            } else {
                self.analysisMetrics = nil
                self.analysisConfidence = nil
            }

            progress = 1
        } catch {
            let message: String
            if let le = error as? LocalizedError, let desc = le.errorDescription {
                message = desc
            } else {
                message = error.localizedDescription
            }
            lastError = message
            isLoading = false
            progress = nil
            throw error
        }

        isLoading = false
        progress = nil
    }
}

// MARK: - Step 2: generateFilteredWithOldPrices → HistoryEntry

extension ExcelSessionViewModel {

    enum GenerateHistoryError: Error {
        case emptySession
    }

    enum ManualHistoryError: Error {
        case unableToCreate
    }

    /// Crea una HistoryEntry “vuota” per un inventario manuale
    func createManualHistoryEntry(in context: ModelContext) throws -> HistoryEntry {
        let now = Date()
        let id = "manual_\(Int(now.timeIntervalSince1970))"

        let entry = HistoryEntry(
            id: id,
            timestamp: now,
            isManualEntry: true,
            supplier: "Inventario manuale",
            category: "",
            syncStatus: .notAttempted
        )

        context.insert(entry)
        try context.save()

        currentHistoryEntry = entry
        return entry
    }

    /// Genera una HistoryEntry a partire dallo stato corrente (header/rows + supplier/category).
    /// È l'equivalente di generateFilteredWithOldPrices su Android.
    func generateHistoryEntry(in context: ModelContext) throws -> HistoryEntry {
        // 1. Validazioni base
        guard !normalizedHeader.isEmpty, !rows.isEmpty else {
            throw GenerateHistoryError.emptySession
        }

        // Selezione colonne coerente (fallback: tutte selezionate)
        if selectedColumns.count != normalizedHeader.count {
            selectedColumns = Array(repeating: true, count: normalizedHeader.count)
        }

        let selectedIndices: [Int] = normalizedHeader.indices.filter { idx in
            guard selectedColumns.indices.contains(idx) else { return true }
            return selectedColumns[idx]
        }

        // Indice colonna barcode nell'header normalizzato
        let barcodeIndex = normalizedHeader.firstIndex(of: "barcode")

        // 2. Mappa barcode → (oldPurchase, oldRetail) dal DB (Product)
        let priceMap = try fetchOldPricesByBarcode(
            barcodeIndex: barcodeIndex,
            context: context
        )

        // 3. Costruzione matrice dati "filtrata"
        var filteredData: [[String]] = []

        // Header filtrato + colonne extra
        var filteredHeader = selectedIndices.map { normalizedHeader[$0] }
        filteredHeader.append(contentsOf: [
            "oldPurchasePrice",
            "oldRetailPrice",
            "realQuantity",
            "RetailPrice",
            "complete"
        ])
        filteredData.append(filteredHeader)

        // Righe dati (rows[0] è l'header originale)
        for row in rows.dropFirst() {
            var newRow: [String] = []

            // Colonne selezionate dall'utente
            for idx in selectedIndices {
                let value = (idx < row.count) ? row[idx] : ""
                newRow.append(value)
            }

            // Barcode della riga corrente
            let barcode: String
            if let bIndex = barcodeIndex, bIndex < row.count {
                barcode = row[bIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                barcode = ""
            }

            let (oldPurchase, oldRetail) = priceMap[barcode] ?? (nil, nil)

            // Colonne extra
            newRow.append(formatPriceForInput(oldPurchase))  // oldPurchasePrice
            newRow.append(formatPriceForInput(oldRetail))   // oldRetailPrice
            newRow.append("")                               // realQuantity (vuota)
            newRow.append("")                               // RetailPrice (vuota)
            newRow.append("")                               // complete (vuota)

            filteredData.append(newRow)
        }

        // 4. editable/complete (come editableValues/completeStates su Android)
        let editable = createEditableValues(for: filteredData)
        let complete = Array(repeating: false, count: filteredData.count)

        // 5. Riassunto iniziale (numero articoli + totale ordine)
        let (totalItems, orderTotal) = calculateInitialSummary(from: filteredData)

        let now = Date()
        let fileId = makeHistoryEntryId(supplier: supplierName, date: now)

        // ✅ salva (se necessario) fornitore/categoria nel DB per autocomplete futuro
        persistSupplierAndCategoryIfNeeded(in: context)
        
        let entry = HistoryEntry(
            id: fileId,
            timestamp: now,
            isManualEntry: false,
            data: filteredData,
            editable: editable,
            complete: complete,
            supplier: supplierName,
            category: categoryName,
            totalItems: totalItems,
            orderTotal: orderTotal,
            paymentTotal: orderTotal,
            missingItems: totalItems,
            syncStatus: .notAttempted,
            wasExported: false
        )

        context.insert(entry)
        try context.save()

        self.currentHistoryEntry = entry
        return entry
    }
    
    private func persistSupplierAndCategoryIfNeeded(in context: ModelContext) {
        let s = supplierName.trimmingCharacters(in: .whitespacesAndNewlines)
        if s != supplierName { supplierName = s }
        if !s.isEmpty {
            _ = findOrCreateSupplier(named: s, in: context)
        }

        let c = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        if c != categoryName { categoryName = c }
        if !c.isEmpty {
            _ = findOrCreateCategory(named: c, in: context)
        }
    }

    private func findOrCreateSupplier(named name: String, in context: ModelContext) -> Supplier {
        let descriptor = FetchDescriptor<Supplier>(predicate: #Predicate { $0.name == name })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let supplier = Supplier(name: name)
        context.insert(supplier)
        return supplier
    }

    private func findOrCreateCategory(named name: String, in context: ModelContext) -> ProductCategory {
        let descriptor = FetchDescriptor<ProductCategory>(predicate: #Predicate { $0.name == name })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let category = ProductCategory(name: name)
        context.insert(category)
        return category
    }

    /// barcode → (purchasePrice, retailPrice) dal database.
    /// Per ora usiamo direttamente i campi del Product, non ancora lo storico ProductPrice.
    private func fetchOldPricesByBarcode(
        barcodeIndex: Int?,
        context: ModelContext
    ) throws -> [String: (Double?, Double?)] {
        guard let barcodeIndex else { return [:] }

        // Tutti i barcode presenti nel file (solo righe dati)
        let allBarcodes: Set<String> = Set(
            rows.dropFirst().compactMap { row in
                guard barcodeIndex < row.count else { return nil }
                let code = row[barcodeIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                return code.isEmpty ? nil : code
            }
        )

        guard !allBarcodes.isEmpty else { return [:] }

        // Fetch di tutti i Product, filtro in memoria (più semplice che fare un "IN" dinamico in SwiftData)
        let products = try context.fetch(FetchDescriptor<Product>())

        var map: [String: (Double?, Double?)] = [:]
        for product in products where allBarcodes.contains(product.barcode) {
            map[product.barcode] = (product.purchasePrice, product.retailPrice)
        }
        return map
    }

    /// editable: una coppia [qty, price] per ogni riga (più header dummy)
    private func createEditableValues(for data: [[String]]) -> [[String]] {
        guard !data.isEmpty else { return [] }

        var result: [[String]] = []
        result.append(["", ""]) // header

        for _ in data.dropFirst() {
            result.append(["", ""])
        }
        return result
    }

    /// Port di calculateInitialSummary:
    /// cerca "purchasePrice" e "quantity" nell'header e somma purchase*quantity per le righe con qty>0.
    private func calculateInitialSummary(from data: [[String]]) -> (Int, Double) {
        guard let headerRow = data.first else { return (0, 0) }

        let purchaseIndex = headerRow.firstIndex(of: "purchasePrice")
        let quantityIndex = headerRow.firstIndex(of: "quantity")

        guard let pIndex = purchaseIndex, let qIndex = quantityIndex else {
            return (0, 0)
        }

        var totalItems = 0
        var orderTotal = 0.0

        for row in data.dropFirst() {
            guard qIndex < row.count else { continue }

            let quantityString = row[qIndex]
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let quantity = Double(quantityString), quantity > 0 else {
                continue
            }

            totalItems += 1

            let priceString = (pIndex < row.count ? row[pIndex] : "")
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let price = Double(priceString) ?? 0.0
            orderTotal += price * quantity
        }

        return (totalItems, orderTotal)
    }

    /// Formattazione semplice tipo formatNumberAsRoundedStringForInput su Android.
    private func formatPriceForInput(_ value: Double?) -> String {
        guard let value, value != 0 else { return "" }

        // Se è intero, niente decimali
        if value.rounded(.towardZero) == value {
            return String(Int(value))
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false

        return formatter.string(from: NSNumber(value: value)) ?? String(value)
    }

    /// Nome file stile Android: `yyyy-MM-dd_HH-mm-ss-SSS_SUPPLIER.xlsx`
    private func makeHistoryEntryId(supplier: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let ts = formatter.string(from: date)

        let trimmed = supplier.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseSupplier = trimmed.isEmpty ? "Inventory" : trimmed

        let safeSupplier = baseSupplier.replacingOccurrences(
            of: "[^A-Za-z0-9_]+",
            with: "_",
            options: .regularExpression
        )

        return "\(ts)_\(safeSupplier).xlsx"
    }
    
    /// Tutti i "ruoli" che possono essere assegnati manualmente alle colonne
        static let overridableRoles: [String] = [
            "barcode",
            "productName",
            "secondProductName",
            "itemNumber",
            "rowNumber",
            "quantity",
            "purchasePrice",
            "totalPrice",
            "retailPrice",
            "discountedPrice",
            "supplier",
            "category"
        ]

        /// Tutti i ruoli sono unici: una sola colonna per ruolo
        private static let uniqueRoles = Set(overridableRoles)

        /// Nome umano da mostrare nella UI per ciascun ruolo
        static func titleForRole(_ role: String) -> String {
            switch role {
            case "barcode": return "Barcode"
            case "productName": return "Nome prodotto"
            case "secondProductName": return "Secondo nome"
            case "itemNumber": return "Numero articolo"
            case "rowNumber": return "Numero riga"
            case "quantity": return "Quantità"
            case "purchasePrice": return "Prezzo d’acquisto"
            case "totalPrice": return "Totale riga"
            case "retailPrice": return "Prezzo di vendita"
            case "discountedPrice": return "Prezzo scontato"
            case "supplier": return "Fornitore"
            case "category": return "Categoria"
            default: return role
            }
        }

    private func fallbackHeader(for idx: Int) -> String {
            if originalHeader.indices.contains(idx) {
                let orig = originalHeader[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                if !orig.isEmpty { return orig }
            }
            return "col\(idx + 1)"
        }

        /// “Nessun tipo”: torna al nome originale (o colN). Non consentire su essenziali.
        func clearColumnRole(at index: Int) {
            guard normalizedHeader.indices.contains(index) else { return }
            if isColumnEssential(at: index) { return } // evita di “perdere” un essenziale con un tap
            normalizedHeader[index] = fallbackHeader(for: index)

            // refresh metriche
            if let metrics = ExcelAnalyzer.computeAnalysisMetrics(header: normalizedHeader, rows: rows) {
                analysisMetrics = metrics
                analysisConfidence = metrics.confidenceScore
            }
        }

        /// ✅ Ruoli unici + sposta o scambia (swap)
        func setColumnRole(at index: Int, to newRole: String) {
            guard normalizedHeader.indices.contains(index) else { return }

            let currentAtTarget = normalizedHeader[index]
            let targetHadRole = Self.uniqueRoles.contains(currentAtTarget) ? currentAtTarget : nil

            // dov’era già assegnato newRole?
            let oldIndexForNewRole: Int? = {
                guard Self.uniqueRoles.contains(newRole) else { return nil }
                let idx = normalizedHeader.firstIndex(of: newRole)
                return (idx == index) ? nil : idx
            }()

            if let oldIndex = oldIndexForNewRole {
                // Caso A: target aveva già un altro ruolo → SWAP
                if let oldRoleOnTarget = targetHadRole, oldRoleOnTarget != newRole {
                    normalizedHeader[oldIndex] = oldRoleOnTarget

                    // se quello che “finisce” su oldIndex è essenziale, deve stare selezionato
                    if Self.essentialColumnKeys.contains(oldRoleOnTarget),
                       selectedColumns.indices.contains(oldIndex) {
                        selectedColumns[oldIndex] = true
                    }
                } else {
                    // Caso B: target non aveva ruolo → “sposto”: la vecchia colonna torna fallback
                    normalizedHeader[oldIndex] = fallbackHeader(for: oldIndex)
                    // ⚠️ NON forzo selectedColumns[oldIndex] a false: lasciamo decidere all’utente
                }
            } else {
                // newRole non era assegnato altrove: attenzione se sto sovrascrivendo un essenziale
                // (qui lasciamo fare, ma la UI/metriche avviseranno; lo swap copre il caso più comune)
            }

            // assegna il ruolo al target
            normalizedHeader[index] = newRole

            // essenziali sempre selezionate
            if Self.essentialColumnKeys.contains(newRole),
               selectedColumns.indices.contains(index) {
                selectedColumns[index] = true
            }

            // refresh metriche
            if let metrics = ExcelAnalyzer.computeAnalysisMetrics(header: normalizedHeader, rows: rows) {
                analysisMetrics = metrics
                analysisConfidence = metrics.confidenceScore
            }
        }

        /// Helper UI: se la colonna ha un ruolo noto ritorna la key, altrimenti nil
        func roleKeyForColumn(_ index: Int) -> String? {
            guard normalizedHeader.indices.contains(index) else { return nil }
            let key = normalizedHeader[index]
            return Self.uniqueRoles.contains(key) ? key : nil
        }

        /// Restituisce alcuni valori di esempio per una colonna (escluse le intestazioni)
        func sampleValuesForColumn(_ index: Int, maxSamples: Int = 3) -> String {
            guard rows.count > 1 else { return "" }

            var samples: [String] = []

            for row in rows.dropFirst() { // salta header
                guard index < row.count else { continue }
                let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty {
                    samples.append(value)
                }
                if samples.count >= maxSamples { break }
            }

            return samples.joined(separator: ", ")
        }
}

// MARK: - Metriche di analisi

struct AnalysisMetrics {
    let essentialColumnsFound: Int
    let essentialColumnsTotal: Int
    let rowsWithValidBarcode: Int
    let totalRows: Int
    let extraColumnsFound: Int
    let extraColumnsTotal: Int
    let confidenceScore: Double
    let issues: [String]
}

// MARK: - Analisi file Excel/HTML (equivalente di ExcelUtils.kt su Android)

struct ExcelAnalyzer {

    // MARK: - XML Parser Delegates

    /// Parser per sharedStrings.xml
    private final class SharedStringsDelegate: NSObject, XMLParserDelegate {
        var currentText = ""
        var inT = false
        var values: [String] = []

        func parser(_ parser: XMLParser, didStartElement name: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String : String] = [:]) {
            if name == "t" {
                inT = true
                currentText = ""
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if inT {
                currentText.append(string)
            }
        }

        func parser(_ parser: XMLParser, didEndElement name: String,
                    namespaceURI: String?, qualifiedName qName: String?) {
            if name == "t" && inT {
                let trimmed = currentText
                    .replacingOccurrences(of: "\u{00A0}", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                values.append(trimmed)
                inT = false
                currentText = ""
            }
        }
    }

    /// Parser per sheetX.xml (righe + celle)
    private final class SheetDelegate: NSObject, XMLParserDelegate {
        let sharedStrings: [String]

        // output
        var rows: [[String]] = []

        // stato corrente
        var currentRow: [String] = []
        var currentColIndex: Int = 0
        var currentCellType: String? = nil   // "s" per shared string
        var currentCellRef: String? = nil
        var collectingValue = false
        var currentValue: String = ""

        init(sharedStrings: [String]) {
            self.sharedStrings = sharedStrings
        }

        func parser(_ parser: XMLParser, didStartElement name: String,
                    namespaceURI: String?, qualifiedName qName: String?,
                    attributes attributeDict: [String : String] = [:]) {

            switch name {
            case "row":
                currentRow = []
                currentColIndex = 0

            case "c": // cell
                currentCellType = attributeDict["t"]
                currentCellRef = attributeDict["r"]
                currentValue = ""
                collectingValue = false

                if let ref = currentCellRef {
                    currentColIndex = ExcelAnalyzer.columnIndex(from: ref)
                }

            case "v", "t":
                // <v> oppure <is><t> per inline string
                collectingValue = true
                currentValue = ""

            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            if collectingValue {
                currentValue.append(string)
            }
        }

        func parser(_ parser: XMLParser, didEndElement name: String,
                    namespaceURI: String?, qualifiedName qName: String?) {

            switch name {
            case "v", "t":
                collectingValue = false

                // Interpreta il valore in base al tipo cella
                var text = currentValue
                text = text
                    .replacingOccurrences(of: "\u{00A0}", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if currentCellType == "s" { // shared string
                    if let idx = Int(text), idx >= 0, idx < sharedStrings.count {
                        text = sharedStrings[idx]
                    }
                }

                // Assicuriamo capacità della riga
                if currentColIndex >= 0 {
                    while currentRow.count <= currentColIndex {
                        currentRow.append("")
                    }
                    currentRow[currentColIndex] = text
                }

            case "c":
                break

            case "row":
                // togliamo celle vuote in coda
                var trimmedRow = currentRow
                while let last = trimmedRow.last, last.isEmpty {
                    trimmedRow.removeLast()
                }

                if !trimmedRow.isEmpty {
                    rows.append(trimmedRow)
                }

                currentRow = []
                currentColIndex = 0

            default:
                break
            }
        }
    }
    
    // MARK: - Alias colonne / tipi conosciuti (versione estesa stile Android)

    /// key = nome canonico colonna, patterns = varianti possibili (IT / CN / ES / EN, ecc.)
    private static let standardAliases: [(key: String, patterns: [String])] = [
        ("barcode", [
            "barcode", "条码", "ean", "bar code",
            "codice a barre", "código de barras", "codigo de barras",
            "código barras", "codigo barras", "co.barra", "条形码",
            "Código de barras", "cod.barra", "cod barra", "codbarra",
            "cod.barras", "codbarras"
        ]),
        ("quantity", [
            "quantity", "数量", "qty", "quantità", "amount",
            "cantidad", "número", "numero", "número de unidades",
            "numero de unidades", "unds.", "总数量", "stock",
            "stockquantity", "giacenza", "scorte", "库存", "库存数量",
            "Existencias", "Stock Quantity", "cantid"
        ]),
        ("purchasePrice", [
            "purchaseprice", "new purchase price", "purchase_price",
            "进价", "buy price", "prezzo acquisto", "cost",
            "unit price", "prezzo", "precio de compra", "precio compra",
            "costo", "precio unitario", "precio adquisición", "precio",
            "v. unit. bruto", "单价", "价格", "原价", "售价",
            "新进价", "nuovo prezzo acquisto", "nuevo precio de compra",
            "折前单价(含税)", "pre/u"
        ]),
        ("totalPrice", [
            "totalprice", "total_price", "总价", "totale", "importo",
            "price total", "precio total", "importe", "total",
            "importe total", "importe final", "subtotal",
            "subtotal bruto", "合计", "金额", "总计"
        ]),
        ("productName", [
            "productname", "product_name", "品名", "descrizione",
            "name", "nome", "description", "nombre del producto",
            "nombre producto", "producto", "descripción", "descripcion",
            "nombre", "产品名1", "产品品名", "商品名1",
            "nome prodotto", "nombre del producto",
            "product name", "商品名称", "外文描述", "articulo", "artículo"
        ]),
        ("secondProductName", [
            "productname2", "product_name2", "品名2", "descrizione2",
            "name2", "nome2", "description2", "nombre del producto2",
            "nombre producto2", "producto2", "descripción2", "descripcion2",
            "nombre2", "产品名2", "产品品名2", "商品名2",
            "secondo nome prodotto", "segundo nombre del producto",
            "second product name", "西语名称", "物料描述",
            "second name", "secondname", "nombre 2", "nome 2"
        ]),
        ("itemNumber", [
            "itemnumber", "item_number", "货号", "codice",
            "code", "articolo", "número de artículo",
            "numero de artículo", "número de producto",
            "numero de producto", "código", "referencia",
            "产品货号", "编号", "codice articolo",
            "código del artículo", "item code", "编码", "短码",
            "ref.cajas", "codice prodotto", "codiceprodotto",
            "product code", "productcode", "código de producto",
            "codigodeproducto"
        ]),
        ("supplier", [
            "supplier", "供应商", "fornitore", "vendor", "provider",
            "fornitore/azienda", "proveedor", "empresa proveedora",
            "vendedor", "distribuidor", "fabricante"
        ]),
        ("rowNumber", [
            "no", "n.", "№", "row", "rowno", "rownumber",
            "serial", "serialnumber", "progressivo", "numeroriga",
            "num. riga", "número de fila", "número", "numero",
            "序号", "编号序号", "序列号", "行号", "#"
        ]),
        ("discount", [
            "discount", "sconto", "折扣", "descuento", "rabatt",
            "sc.", "dcto", "scnto", "scnt.", "rebaja",
            "remise", "d%", "d.%", "dto%"
        ]),
        ("discountedPrice", [
            "discountedprice", "prezzoscontato", "precio con descuento",
            "precio descontado", "折后价", "prezzo scontato",
            "precio rebajado", "rebate price", "after discount price",
            "final price", "prezzo finale", "pre.-d%",
            "折后单价(含税)"
        ]),
        ("retailPrice", [
            "retailprice", "retail_price", "零售价", "prezzo vendita",
            "prezzo retail", "sale price", "listino", "precio de venta",
            "precio venta", "precio al público", "precio retail",
            "precio al por menor", "nuovo prezzo vendita",
            "新零售价", "nuevo precio de venta", "new retail price"
        ]),
        ("realQuantity", [
            "实点数量", "counted quantity", "quantità contata",
            "cantidad contada"
        ]),
        ("category", [
            "category", "categoria", "reparto", "department",
            "分类", "类别", "categoría"
        ]),
        ("oldPurchasePrice", [
            "oldpurchaseprice", "prezzovecchioacquisto",
            "prezzoprecedenteacquisto", "acquistoprec",
            "previouspurchaseprice", "prezzo vecchio acquisto",
            "旧进价", "precio de compra anterior",
            "old purchase price"
        ]),
        ("oldRetailPrice", [
            "oldretailprice", "prezzovecchiovendita",
            "prezzoprecedentevendita", "venditaprec",
            "previousretailprice", "prezzo vecchio vendita",
            "旧零售价", "precio de venta anterior",
            "old retail price"
        ])
    ]
    
    /// Ritorna true se `original` è un alias conosciuto per la key `normalized`
    static func isAliasMatch(original: String, normalized: String) -> Bool {
        // se il testo è già identico, non è un "alias", è un match diretto
        if original == normalized { return false }

        let collapsed = normalizeToken(original)

        // Cerchiamo solo tra gli alias della key corrispondente
        for (key, patterns) in standardAliases where key == normalized {
            for pattern in patterns {
                let normPattern = normalizeToken(pattern)
                if !normPattern.isEmpty && normPattern == collapsed {
                    return true
                }
            }
        }

        return false
    }

    /// Token che identificano righe di riepilogo ("totale", "subtotal", ecc.)
    private static let summaryTokens = [
        "合计", "总计", "小计", "汇总", "合計", "總計",
        "小計", "總結", "总额",
        "subtotal", "total", "totale", "tot.", "sommario",
        "resumen", "sum"
    ].map { $0.lowercased() }

    // MARK: - API principale

    /// Porta la logica di loadFromMultipleUris(context, uris)
    static func loadFromMultipleURLs(_ urls: [URL])
        throws -> (originalHeader: [String], normalizedHeader: [String], rows: [[String]]) {
        guard let firstURL = urls.first else {
            throw ExcelLoadError.invalidFormat("Nessun file selezionato.")
        }

        // 🔹 Manteniamo l'header originale solo del primo file
        let (originalHeader, goldenHeader, firstDataRows) = try readAndAnalyzeExcel(from: firstURL)
        var allValidRows = firstDataRows

        if urls.count > 1 {
            for url in urls.dropFirst() {
                let (_, header, dataRows) = try readAndAnalyzeExcel(from: url)

                // Richiediamo che gli header normalizzati siano identici
                if header != goldenHeader {
                    throw ExcelLoadError.incompatibleHeader
                }
                allValidRows.append(contentsOf: dataRows)
            }
        }

        // rows: prima riga = header normalizzato
        let rowsWithHeader = [goldenHeader] + allValidRows
        return (originalHeader, goldenHeader, rowsWithHeader)
    }

    /// Porta la logica di readAndAnalyzeExcel(context, uri) con analisi avanzata stile Android
    static func readAndAnalyzeExcel(from url: URL)
        throws -> (originalHeader: [String], normalizedHeader: [String], dataRows: [[String]]) {

        let data = try Data(contentsOf: url)
        let ext = url.pathExtension.lowercased()

        debugLog("Caricamento \(url.lastPathComponent) (ext=\(ext))", level: .info)

        // 1) HTML first (anche DreamDIY.xls)
        if looksLikeHtml(data: data) {
            debugLog("Rilevato HTML (anche con estensione .\(ext))", level: .info)
            let rows = try rowsFromHTML(data: data)
            return analyzeRows(rows)
        }

        // 2) Prova come XLSX (ZIP), basato sul contenuto
        if isZipXlsx(data: data) {
            do {
                debugLog("Firma ZIP rilevata, provo come XLSX", level: .info)
                let rows = try rowsFromXLSX(at: url)
                return analyzeRows(rows)
            } catch {
                debugLog("Errore lettura XLSX: \(error.localizedDescription)", level: .warning)

                // Se l'estensione è .xls, potrebbe essere un vero .xls binario
                if ext == "xls" {
                    debugLog("Ext .xls: fallback su parser legacy .xls (libxls)", level: .info)
                    // continua al punto 3
                } else {
                    throw error
                }
            }
        }

        // 3) Legacy .xls (BIFF) → libxls
        if ext == "xls" || ext == "xlsx" {
            debugLog("Provo parser legacy .xls per \(url.lastPathComponent)", level: .info)
            let rows = try rowsFromLegacyXLS(data: data)
            return analyzeRows(rows)
        }

        // 4) Estensione non supportata
        throw ExcelLoadError.unsupportedExtension(ext)
    }

    private static func looksLikeHtml(data: Data) -> Bool {
        let headLength = min(4096, data.count)
        let headData = data.prefix(headLength)

        // Prima provo ISO-8859-1 (come Android), poi UTF-8 / ASCII
        let headString =
            String(data: headData, encoding: .isoLatin1) ??
            String(data: headData, encoding: .utf8) ??
            String(data: headData, encoding: .ascii) ??
            ""

        let lower = headString.lowercased()

        return lower.contains("<html") ||
               lower.contains("mso-application") ||
               lower.contains("office:excel") ||
               lower.contains("<table")
    }
    
    /// Rileva rapidamente se il file è un archivio ZIP (tipico degli .xlsx)
    private static func isZipXlsx(data: Data) -> Bool {
        // Firma ZIP: 50 4B 03 04
        let magic: [UInt8] = [0x50, 0x4B, 0x03, 0x04]
        guard data.count >= magic.count else { return false }
        return data.prefix(magic.count).elementsEqual(magic)
    }

    // MARK: HTML → righe

    #if canImport(SwiftSoup)
    private static func rowsFromHTML(data: Data) throws -> [[String]] {
        guard let html =
                String(data: data, encoding: .utf8) ??
                String(data: data, encoding: .isoLatin1) ??
                String(data: data, encoding: .unicode) else {
            throw ExcelLoadError.invalidFormat("Impossibile leggere il file HTML.")
        }

        let doc = try SwiftSoup.parse(html)
        let trs = try doc.select("tr")

        var result: [[String]] = []

        for tr in trs.array() {
            let cells = try tr.select("th,td")
            var row: [String] = []

            for cell in cells.array() {
                let raw = try cell.text()
                    .replacingOccurrences(of: "\u{00A0}", with: " ")
                let text = raw
                    .replacingOccurrences(of: "\\s*\\n\\s*",
                                          with: " ",
                                          options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                row.append(text)
            }

            // togliamo eventuali celle vuote in coda
            while let last = row.last, last.isEmpty {
                row.removeLast()
            }

            if row.contains(where: { !$0.isEmpty }) {
                result.append(row)
            }
        }

        return result
    }
    #else
    private static func rowsFromHTML(data: Data) throws -> [[String]] {
        // Se SwiftSoup non è disponibile, falliamo esplicitamente
        throw ExcelLoadError.htmlNotSupported
    }
    #endif
    
    // MARK: XLSX → righe (parser ZIP/XML senza CoreXLSX)

    /// Parser legacy .xls basato su libxls tramite wrapper Objective-C
    private static func rowsFromLegacyXLS(data: Data) throws -> [[String]] {
        do {
            // ✅ Nuovo nome Swift + niente guard/optional
            let rows = try ExcelLegacyReader.rows(fromXLSData: data)
            return rows
        } catch {
            // Qui arrivano gli NSError generati in Objective-C
            let nsError = error as NSError
            throw ExcelLoadError.invalidFormat(
                "Impossibile leggere il file .xls. Dettagli: \(nsError.localizedDescription)"
            )
        }
    }
    
    private static func rowsFromXLSX(at url: URL) throws -> [[String]] {
        let archive: Archive
        do {
            // nuovo init throwing consigliato da ZIPFoundation
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            // convertiamo l'errore ZIP in un messaggio user-friendly
            throw ExcelLoadError.invalidFormat("Impossibile aprire il file Excel (zip non valido).")
        }

        // 1) sharedStrings.xml (può anche non esserci)
        let sharedStrings: [String]
        if let ssData = try? dataFromArchive(archive, path: "xl/sharedStrings.xml") {
            sharedStrings = parseSharedStringsXML(ssData)
        } else {
            sharedStrings = []
        }


        // 2) Trova il primo sheet
        //   - prima proviamo "xl/worksheets/sheet1.xml"
        //   - se non esiste, prendiamo il primo "xl/worksheets/sheet*.xml"
        let sheetPath: String
        if archive["xl/worksheets/sheet1.xml"] != nil {
            sheetPath = "xl/worksheets/sheet1.xml"
        } else if let entry = archive.first(where: { $0.path.hasPrefix("xl/worksheets/sheet") && $0.path.hasSuffix(".xml") }) {
            sheetPath = entry.path
        } else {
            throw ExcelLoadError.invalidFormat("Nessun foglio di lavoro trovato nel file Excel.")
        }

        let sheetData = try dataFromArchive(archive, path: sheetPath)
        return parseSheetXML(sheetData, sharedStrings: sharedStrings)
    }
    
    // MARK: - Parser sharedStrings.xml

    private static func parseSharedStringsXML(_ data: Data) -> [String] {
        let delegate = SharedStringsDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.values
    }
    
    // MARK: - Parser sheet.xml → righe

    private static func parseSheetXML(_ data: Data, sharedStrings: [String]) -> [[String]] {
        let delegate = SheetDelegate(sharedStrings: sharedStrings)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.rows
    }

    /// Converte un riferimento tipo "C5" in indice di colonna 0-based (C=2)
    private static func columnIndex(from cellRef: String) -> Int {
        // prendi solo le lettere iniziali (A, B, AA, AB, ...)
        let letters = cellRef.prefix { ($0 >= "A" && $0 <= "Z") || ($0 >= "a" && $0 <= "z") }
        var result = 0
        for ch in letters {
            let scalar = ch.uppercased().unicodeScalars.first!.value
            let value = Int(scalar) - 65 + 1 // 'A' = 65 → 1
            result = result * 26 + value
        }
        return max(result - 1, 0)
    }

    /// Estrae i dati di un entry ZIP in memoria
    private static func dataFromArchive(_ archive: Archive, path: String) throws -> Data {
        guard let entry = archive[path] else {
            throw ExcelLoadError.invalidFormat("Componente mancante nel file Excel: \(path)")
        }

        var result = Data()
        _ = try archive.extract(entry) { chunk in
            result.append(chunk)
        }
        return result
    }

    // MARK: - Analisi avanzata (replica di ExcelUtils.kt)

    /// Funzione principale di analisi che replica la logica Android:
    /// - trova header e riga di inizio dati
    /// - normalizza header con alias estesi
    /// - rimuove colonne vuote
    /// - applica euristiche per identificare barcode/qty/prezzi
    /// - elimina righe di riepilogo (totali)
    private static func analyzeRows(_ rows: [[String]])
        -> (originalHeader: [String], normalizedHeader: [String], dataRows: [[String]]) {
        guard !rows.isEmpty else { return ([], [], []) }

        // 1. Trova la riga di intestazione dati
        let (headerRow, dataStartIndex, hasHeader) = findDataHeaderRow(in: rows)

        // 2. Costruisci righe dati grezze (tutte quelle dopo dataStartIndex)
        let rawDataRows = buildDataRows(from: rows, startingAt: dataStartIndex)

        // 2b. Come su Android: se abbiamo riconosciuto un header,
        //      filtriamo le righe per eliminare totali / righe inutili.
        let dataRows: [[String]]
        if hasHeader {
            dataRows = filterDataRows(rawDataRows)
        } else {
            dataRows = rawDataRows
        }

        // 3. Rimuovi colonne completamente vuote
        let (filteredHeader, filteredDataRows, _) = removeEmptyColumns(
            header: headerRow,
            dataRows: dataRows
        )

        // 4. Normalizza intestazioni
        var normalizedHeader = filteredHeader.enumerated().map { index, rawHeader in
            normalizeHeaderCell(rawHeader, index: index)
        }

        // 5. Mappatura iniziale basata sugli header normalizzati
        var headerMap = identifyColumns(
            normalizedHeader: normalizedHeader,
            dataRows: filteredDataRows,
            hasHeader: hasHeader
        )

        // 6. Euristiche sui dati per colonne mancanti
        headerMap = applyHeuristics(
            headerMap: headerMap,
            dataRows: filteredDataRows,
            normalizedHeader: normalizedHeader
        )

        // 7. Assicura che le colonne obbligatorie (barcode, productName, purchasePrice)
        // esistano e siano in ordine logico
        let ensured = ensureMandatoryColumns(
            normalizedHeader: normalizedHeader,
            dataRows: filteredDataRows,
            headerMap: headerMap
        )
        normalizedHeader = ensured.newHeader
        let ensuredDataRows = ensured.newDataRows
        headerMap = ensured.newHeaderMap

        // 8. Filtra righe di riepilogo ...
        let finalDataRows = filterSummaryRows(
            dataRows: ensuredDataRows,
            headerMap: headerMap,
            normalizedHeader: normalizedHeader
        )
        
        // 9. Validazione finale (solo per debug)
        let mandatoryColumns = ["barcode", "productName", "purchasePrice"]
        for mandatory in mandatoryColumns {
            if !normalizedHeader.contains(mandatory) {
                debugLog("ATTENZIONE: colonna obbligatoria '\(mandatory)' non trovata nell'header finale!", level: .warning)
            }
        }

        // Conta quante righe hanno un barcode valorizzato (righe davvero "utili")
        let validRows = finalDataRows.count(where: { row in
            guard let idx = headerMap["barcode"], idx < row.count else {
                return false
            }
            return !row[idx].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })
        debugLog("Analisi completata: \(validRows) righe con barcode su \(finalDataRows.count) righe totali.", level: .info)

        let confidence = calculateAnalysisConfidence(
            header: normalizedHeader,
            headerMap: headerMap,
            dataRows: finalDataRows
        )
        debugLog(String(format: "Confidence analisi: %.0f%%", confidence * 100), level: .info)
        
        #if DEBUG
        debugLog("HEADER ORIG: \(filteredHeader)", level: .info)
        debugLog("HEADER NORM: \(normalizedHeader)", level: .info)
        #endif
        
        // 🔹 Ritorniamo sia header originale (filtrato) che normalizzato
        return (filteredHeader, normalizedHeader, finalDataRows)
    }

    // MARK: - Normalizzazione Header (Compatibile con Android)

    /// Helper comune per header e alias (equivalente a normalizeHeader di Kotlin)
    private static func normalizeToken(_ s: String) -> String {
        // 1. Rimuove accenti / normalizza (simile a NFD + remove diacritics)
        let folded = s.folding(options: .diacriticInsensitive, locale: .current)

        // 2. Trim e rimozione di spazi / underscore
        let trimmed = folded.trimmingCharacters(in: .whitespacesAndNewlines)
        let noSpaces = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")

        // 3. Mantiene SOLO lettere e numeri Unicode (come \p{L}\p{Nd} in Kotlin)
        let filteredScalars = noSpaces.unicodeScalars.filter { scalar in
            CharacterSet.letters.contains(scalar) ||
            CharacterSet.decimalDigits.contains(scalar)
        }

        let result = String(String.UnicodeScalarView(filteredScalars)).lowercased()
        
        #if DEBUG
        if s != result && !result.isEmpty {
            debugLog("normalizeToken: '\(s)' → '\(result)'", level: .info)
        }
        #endif
        
        return result
    }

    /// Normalizzazione header: usa normalizeToken e mappa agli alias standard
    private static func normalizeHeaderCell(_ raw: String, index: Int) -> String {
        let collapsed = normalizeToken(raw)

        #if DEBUG
        debugLog("Header[\(index)]: raw='\(raw)' → collapsed='\(collapsed)'", level: .info)
        #endif

        // Se vuoto dopo normalizzazione → colonna generica
        if collapsed.isEmpty {
            let generated = "col\(index + 1)"
            debugLog("→ Header vuoto, generato: '\(generated)'", level: .warning)
            return generated
        }

        // Match ESATTO con gli alias (come in Kotlin: normCol == normalizeHeader(alias))
        for (key, patterns) in standardAliases {
            for pattern in patterns {
                let normPattern = normalizeToken(pattern)

                if !normPattern.isEmpty && collapsed == normPattern {
                    #if DEBUG
                    debugLog("→ Match trovato: '\(collapsed)' → '\(key)' (pattern: '\(pattern)')", level: .success)
                    #endif
                    return key
                }
            }
        }

        // Nessun alias trovato → uso la versione normalizzata (può essere cinese tipo "条码")
        #if DEBUG
        debugLog("→ Nessun alias trovato per '\(collapsed)', mantengo come header", level: .info)
        #endif
        return collapsed
    }
    
    // MARK: - Helper di analisi

    /// Trova la riga di header e l'indice da cui iniziano i dati
    private static func findDataHeaderRow(in rows: [[String]]) -> (headerRow: [String], dataStartIndex: Int, hasHeader: Bool) {
        // Heuristica: prima riga che sembra "dati": >=3 numeri e >=1 testo
        var dataRowIdx = -1
        for (idx, row) in rows.enumerated() {
            var numericCount = 0
            var textCount = 0

            for cell in row {
                let trimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }

                if trimmed.replacingOccurrences(of: ",", with: ".").toDouble() != nil {
                    numericCount += 1
                } else {
                    textCount += 1
                }
            }

            if numericCount >= 3 && textCount >= 1 {
                dataRowIdx = idx
                break
            }
        }

        let hasHeader = (dataRowIdx > 0 && dataRowIdx < rows.count)

        if hasHeader {
            debugLog("Header individuato alla riga \(dataRowIdx - 1), dati da riga \(dataRowIdx).")
            return (rows[dataRowIdx - 1], dataRowIdx, true)
        } else {
            debugLog("Header non trovato: uso header generato e dati da riga 0.")
            // Se non troviamo un header evidente, generiamo header fittizio
            let colCount = rows.first?.count ?? 0
            let generatedHeader = (0..<colCount).map { "col\($0 + 1)" }
            return (generatedHeader, 0, false)
        }
    }
    
    /// Filtra le righe "valide", come in Android:
    /// almeno 3 valori numerici e almeno 1 testo non vuoto.
    private static func filterDataRows(_ rows: [[String]]) -> [[String]] {
        return rows.filter { row in
            var numericCount = 0
            var textCount = 0

            for cell in row {
                let trimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }

                if trimmed
                    .replacingOccurrences(of: ",", with: ".")
                    .toDouble() != nil {
                    numericCount += 1
                } else {
                    textCount += 1
                }
            }

            return numericCount >= 3 && textCount >= 1
        }
    }

    /// Padding righe dati per avere tutte lo stesso numero di colonne
    private static func buildDataRows(from rows: [[String]], startingAt startIndex: Int) -> [[String]] {
        guard startIndex < rows.count else { return [] }

        let dataRows = Array(rows[startIndex...])
        let maxCols = dataRows.map { $0.count }.max() ?? 0

        return dataRows.map { row in
            var paddedRow = row
            if paddedRow.count < maxCols {
                paddedRow.append(contentsOf: Array(repeating: "", count: maxCols - paddedRow.count))
            }
            return paddedRow
        }
    }

    /// Rimuove colonne interamente vuote
    private static func removeEmptyColumns(
        header: [String],
        dataRows: [[String]]
    ) -> (filteredHeader: [String], filteredDataRows: [[String]], columnMapping: [Int: Int]) {

        let colCount = header.count
        var nonEmptyCols: [Int] = []
        var columnMapping: [Int: Int] = [:]

        for col in 0..<colCount {
            let hasData = dataRows.contains { row in
                col < row.count &&
                !row[col].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            if hasData {
                columnMapping[col] = nonEmptyCols.count
                nonEmptyCols.append(col)
            }
        }

        let filteredHeader = nonEmptyCols.map { header[$0] }
        let filteredDataRows = dataRows.map { row in
            nonEmptyCols.map { row[$0] }
        }

        return (filteredHeader, filteredDataRows, columnMapping)
    }

    /// Mappa le colonne in base al solo header normalizzato (senza guardare i dati)
    private static func identifyColumns(
        normalizedHeader: [String],
        dataRows: [[String]],
        hasHeader: Bool
    ) -> [String: Int] {
        var headerMap: [String: Int] = [:]
        var usedCols: Set<Int> = []

        // Priorità come in Android: retailPrice e purchasePrice prima
        let prioritizedKeys = ["retailPrice", "purchasePrice"] +
            standardAliases
            .map { $0.key }
            .filter { $0 != "retailPrice" && $0 != "purchasePrice" }

        for key in prioritizedKeys {
            if let foundIdx = normalizedHeader.firstIndex(of: key),
               !usedCols.contains(foundIdx) {
                headerMap[key] = foundIdx
                usedCols.insert(foundIdx)
            }
        }

        return headerMap
    }

    /// Euristiche sui dati per trovare colonne mancanti
    private static func applyHeuristics(
        headerMap: [String: Int],
        dataRows: [[String]],
        normalizedHeader: [String]
    ) -> [String: Int] {

        var result = headerMap
        let colCount = normalizedHeader.count
        let halfThreshold = Int(Double(dataRows.count) * 0.5)

        func unusedColumns() -> [Int] {
            return (0..<colCount).filter { !result.values.contains($0) }
        }

        // 1) Barcode: molte celle con 8/12/13 cifre
        if result["barcode"] == nil {
            for col in unusedColumns() {
                let matches = dataRows.count(where: { row in
                    guard col < row.count else { return false }
                    let value = row[col].trimmingCharacters(in: .whitespacesAndNewlines)
                    return [8, 12, 13].contains(value.count) &&
                           value.allSatisfy { $0.isNumber }
                })
                if matches >= halfThreshold {
                    result["barcode"] = col
                    debugLog("Colonna \(col) identificata come barcode tramite euristica (lunghezza 8/12/13).")
                    break
                }
            }
        }

        // 2) Quantity: numeri positivi nella maggior parte delle righe
        if result["quantity"] == nil {
            for col in unusedColumns() {
                let nums = dataRows.compactMap { row -> Double? in
                    guard col < row.count else { return nil }
                    return row[col].toDouble()
                }
                if !nums.isEmpty &&
                   Double(nums.count) >= 0.7 * Double(dataRows.count) &&
                   nums.allSatisfy({ $0 > 0 }) {
                    result["quantity"] = col
                    debugLog("Colonna \(col) identificata come quantity tramite euristica (molti numeri > 0).")
                    break
                }
            }
        }

        // 3) purchasePrice: colonna numerica positiva simile a quantity
        if result["purchasePrice"] == nil {
            for col in unusedColumns() {
                let nums = dataRows.compactMap { row -> Double? in
                    guard col < row.count else { return nil }
                    return row[col].toDouble()
                }
                if !nums.isEmpty &&
                   Double(nums.count) >= 0.7 * Double(dataRows.count) &&
                   nums.allSatisfy({ $0 > 0 }) {
                    result["purchasePrice"] = col
                    debugLog("Colonna \(col) identificata come purchasePrice tramite euristica (molti numeri > 0).")
                    break
                }
            }
        }

        // 4) totalPrice ≈ quantity * purchasePrice
        if result["totalPrice"] == nil,
           let qtyCol = result["quantity"],
           let purchCol = result["purchasePrice"] {

            for col in unusedColumns() {
                let matches = dataRows.count(where: { row in
                    guard qtyCol < row.count,
                          purchCol < row.count,
                          col < row.count else { return false }

                    guard let quantity = row[qtyCol].toDouble(),
                          let purchase = row[purchCol].toDouble(),
                          let total = row[col].toDouble() else {
                        return false
                    }

                    let expected = quantity * purchase
                    let epsilon = 0.10 * max(expected, 1.0)
                    return abs(total - expected) <= epsilon
                })

                if Double(matches) >= 0.7 * Double(dataRows.count) {
                    result["totalPrice"] = col
                    debugLog("Colonna \(col) identificata come totalPrice (≈ qty × purchasePrice).")
                    break
                }
            }
        }

        // 5) productName: stringhe di testo con lunghezza >= 3
        if result["productName"] == nil {
            for col in unusedColumns() {
                let matches = dataRows.count(where: { row in
                    guard col < row.count else { return false }
                    let value = row[col].trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.count >= 3 && value.toDouble() == nil
                })
                if matches >= halfThreshold {
                    result["productName"] = col
                    debugLog("Colonna \(col) identificata come productName tramite euristica (testo lungo).")
                    break
                }
            }
        }

        // 6) discount: percentuali o 0,xx
        if result["discount"] == nil {
            for col in unusedColumns() {
                let matches = dataRows.count(where: { row in
                    guard col < row.count else { return false }
                    let value = row[col].trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.matches("^(0[.,]\\d{1,2})$") ||
                           value.matches("^\\d{1,2}%$")
                })
                if matches >= halfThreshold {
                    result["discount"] = col
                    debugLog("Colonna \(col) identificata come discount tramite euristica (0,xx o xx%).")
                    break
                }
            }
        }

        // 7) rowNumber: numeri progressivi (max 6 cifre)
        if result["rowNumber"] == nil {
            for col in unusedColumns() {
                let matches = dataRows.count(where: { row in
                    guard col < row.count else { return false }
                    let value = row[col].trimmingCharacters(in: .whitespacesAndNewlines)
                    return value.matches("^\\d+$") && value.count <= 6
                })
                if matches >= halfThreshold {
                    result["rowNumber"] = col
                    debugLog("Colonna \(col) identificata come rowNumber tramite euristica (interi piccoli).")
                    break
                }
            }
        }

        // 8) retailPrice / discountedPrice: un'altra colonna numerica positiva
        if result["retailPrice"] == nil && result["discountedPrice"] == nil {
            for col in unusedColumns() {
                let nums = dataRows.compactMap { row -> Double? in
                    guard col < row.count else { return nil }
                    return row[col].toDouble()
                }
                if !nums.isEmpty &&
                   Double(nums.count) >= 0.7 * Double(dataRows.count) &&
                   nums.allSatisfy({ $0 > 0 }) {

                    let headerLower = normalizedHeader[col].lowercased()

                    // Priorità al nome della colonna
                    if headerLower.contains("discount") ||
                       headerLower.contains("scont") ||
                       headerLower.contains("rebaj") ||
                       headerLower.contains("折后") {
                        result["discountedPrice"] = col
                        debugLog("Colonna \(col) identificata come discountedPrice (nome colonna + valori numerici).", level: .success)
                    } else if headerLower.contains("retail") ||
                              headerLower.contains("vendita") ||
                              headerLower.contains("venta") ||
                              headerLower.contains("售价") ||
                              headerLower.contains("零售") {
                        result["retailPrice"] = col
                        debugLog("Colonna \(col) identificata come retailPrice (nome colonna + valori numerici).", level: .success)
                    } else {
                        // Default: retailPrice
                        result["retailPrice"] = col
                        debugLog("Colonna \(col) identificata come retailPrice (valori numerici, nome neutro).", level: .info)
                    }
                    break
                }
            }
        }

        // 9) supplier / secondProductName / category: colonne di testo con pattern specifici
        if result["supplier"] == nil ||
           result["secondProductName"] == nil ||
           result["category"] == nil {

            let remainingTextColumns = unusedColumns().filter { col in
                let textCount = dataRows.count(where: { row in
                    guard col < row.count else { return false }
                    let val = row[col].trimmingCharacters(in: .whitespacesAndNewlines)
                    return val.toDouble() == nil && !val.isEmpty
                })
                return Double(textCount) >= 0.5 * Double(dataRows.count)
            }

            for col in remainingTextColumns {
                let sampleValues = dataRows
                    .prefix(10)
                    .compactMap { row -> String? in
                        guard col < row.count else { return nil }
                        let val = row[col].trimmingCharacters(in: .whitespacesAndNewlines)
                        return val.isEmpty ? nil : val
                    }

                if sampleValues.isEmpty { continue }

                let totalLen = sampleValues.reduce(0) { $0 + $1.count }
                let avgLength = Double(totalLen) / Double(sampleValues.count)
                let maxLength = sampleValues.max(by: { $0.count < $1.count })?.count ?? 0

                // Decisione basata su pattern comuni di lunghezza
                if result["secondProductName"] == nil &&
                   avgLength >= 8 && maxLength <= 100 {
                    // Nomi di prodotto secondari tendono ad essere più lunghi
                    result["secondProductName"] = col
                    debugLog("Colonna \(col) identificata come secondProductName (avgLen: \(avgLength), maxLen: \(maxLength)).", level: .success)
                } else if result["supplier"] == nil &&
                          avgLength <= 50 && maxLength <= 60 {
                    // Nomi fornitori di solito non lunghissimi
                    result["supplier"] = col
                    debugLog("Colonna \(col) identificata come supplier (avgLen: \(avgLength), maxLen: \(maxLength)).", level: .success)
                } else if result["category"] == nil &&
                          avgLength <= 30 && maxLength <= 40 {
                    // Categorie molto corte
                    result["category"] = col
                    debugLog("Colonna \(col) identificata come category (avgLen: \(avgLength), maxLen: \(maxLength)).", level: .success)
                }

                if result["secondProductName"] != nil &&
                   result["supplier"] != nil &&
                   result["category"] != nil {
                    break
                }
            }
        }

        return result
    }

    /// Inserisce le colonne obbligatorie mancanti (barcode, productName, purchasePrice)
    private static func ensureMandatoryColumns(
        normalizedHeader: [String],
        dataRows: [[String]],
        headerMap: [String: Int]
    ) -> (newHeader: [String], newDataRows: [[String]], newHeaderMap: [String: Int]) {

        var newHeader = normalizedHeader
        var newDataRows = dataRows
        var newHeaderMap = headerMap

        func insertColumn(at index: Int, key: String) {
            newHeader.insert(key, at: index)
            for i in 0..<newDataRows.count {
                newDataRows[i].insert("", at: index)
            }

            // Aggiorna indice delle colonne successive
            for (k, v) in newHeaderMap {
                if v >= index {
                    newHeaderMap[k] = v + 1
                }
            }
            newHeaderMap[key] = index
        }

        // barcode subito dopo itemNumber (se esiste), altrimenti in testa
        if newHeaderMap["barcode"] == nil {
            let insertIndex = (newHeaderMap["itemNumber"] ?? -1) + 1
            let idx = max(insertIndex, 0)
            insertColumn(at: idx, key: "barcode")
        }

        // productName dopo barcode / itemNumber
        if newHeaderMap["productName"] == nil {
            let barcodeIndex = newHeaderMap["barcode"] ?? -1
            let itemNumberIndex = newHeaderMap["itemNumber"] ?? -1
            let insertIndex = max(barcodeIndex, itemNumberIndex) + 1
            let idx = max(insertIndex, 0)
            insertColumn(at: idx, key: "productName")
        }

        // purchasePrice dopo quantity / productName
        if newHeaderMap["purchasePrice"] == nil {
            let quantityIndex = newHeaderMap["quantity"] ?? -1
            let productNameIndex = newHeaderMap["productName"] ?? -1
            let insertIndex = max(quantityIndex, productNameIndex) + 1
            let idx = max(insertIndex, 0)
            insertColumn(at: idx, key: "purchasePrice")
        }

        return (newHeader, newDataRows, newHeaderMap)
    }

    /// Elimina righe di riepilogo (totali) basandosi su token e mancanza di identità
    private static func filterSummaryRows(
        dataRows: [[String]],
        headerMap: [String: Int],
        normalizedHeader: [String]
    ) -> [[String]] {

        return dataRows.filter { row in
            let productName = headerMap["productName"].flatMap { idx in
                idx < row.count ? row[idx] : ""
            } ?? ""
            let itemNumber = headerMap["itemNumber"].flatMap { idx in
                idx < row.count ? row[idx] : ""
            } ?? ""
            let barcode = headerMap["barcode"].flatMap { idx in
                idx < row.count ? row[idx] : ""
            } ?? ""

            // primo testo non numerico nella riga
            let firstText = row.first(where: { cell in
                let trimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.isEmpty && trimmed.toDouble() == nil
            })?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""

            // token di riepilogo?
            let looksLikeToken = summaryTokens.contains { token in
                firstText.hasPrefix(token) ||
                productName.lowercased().hasPrefix(token)
            }

            // quante celle numeriche ci sono nella riga?
            let numberCount = row.filter { cell in
                !cell.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                cell.toDouble() != nil
            }.count

            // riga senza identità (nessun barcode/item/productName significativo)
            let lacksIdentity = barcode.isEmpty &&
                                itemNumber.isEmpty &&
                                productName.count < 3

            // Filtra via solo se sembra davvero un riepilogo
            return !(looksLikeToken && numberCount >= 2 && lacksIdentity)
        }
    }
    
    private enum DebugLevel {
        case info, warning, error, success
    }

    private static func debugLog(_ message: String, level: DebugLevel = .info) {
        #if DEBUG
        let prefix: String
        switch level {
        case .info:    prefix = "ℹ️"
        case .warning: prefix = "⚠️"
        case .error:   prefix = "❌"
        case .success: prefix = "✅"
        }
        print("\(prefix) [ExcelAnalyzer] \(message)")
        #endif
    }
    
    /// Valuta "quanto bene" è andata l'analisi, da 0.0 a 1.0.
    /// Puoi usarla per logging, UI o per decidere se mostrare un warning.
    private static func calculateAnalysisConfidence(
        header: [String],
        headerMap: [String: Int],
        dataRows: [[String]]
    ) -> Double {
        // 1) Colonne essenziali trovate
        let essential = ["barcode", "productName", "purchasePrice"]
        let foundEssential = essential.filter { headerMap[$0] != nil }.count
        let essentialScore = Double(foundEssential) / Double(essential.count)

        // 2) Righe con barcode valido
        let totalRows = dataRows.count
        var barcodeScore = 0.0
        if let bIndex = headerMap["barcode"], totalRows > 0 {
            let validBarcodeRows = dataRows.count(where: { row in
                guard bIndex < row.count else { return false }
                let v = row[bIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                return !v.isEmpty
            })
            barcodeScore = Double(validBarcodeRows) / Double(totalRows)
        }

        // 3) Colonne "extra" riconosciute (qty, totalPrice, retailPrice, discountedPrice, supplier, category...)
        let extraKeys = [
            "quantity", "totalPrice",
            "retailPrice", "discountedPrice",
            "discount", "rowNumber",
            "supplier", "secondProductName", "category"
        ]
        let foundExtra = extraKeys.filter { headerMap[$0] != nil }.count
        let extraScore = extraKeys.isEmpty ? 0.0 : Double(foundExtra) / Double(extraKeys.count)

        // Pesi: le essenziali contano di più
        let finalScore = (essentialScore * 0.6) + (barcodeScore * 0.25) + (extraScore * 0.15)

        return min(1.0, max(0.0, finalScore))
    }
    
    /// Calcola metriche complete di analisi partendo da header + righe (con header in riga 0)
    static func computeAnalysisMetrics(
        header: [String],
        rows: [[String]]
    ) -> AnalysisMetrics? {
        guard !header.isEmpty, !rows.isEmpty else { return nil }
        
        // rows è [header] + righe dati → rimuoviamo la riga 0
        let dataRows = Array(rows.dropFirst())
        guard !dataRows.isEmpty else { return nil }
        
        // Ricostruiamo la mappatura colonne usando le stesse euristiche di analyzeRows
        var headerMap = identifyColumns(
            normalizedHeader: header,
            dataRows: dataRows,
            hasHeader: true
        )
        headerMap = applyHeuristics(
            headerMap: headerMap,
            dataRows: dataRows,
            normalizedHeader: header
        )
        
        let confidence = calculateAnalysisConfidence(
            header: header,
            headerMap: headerMap,
            dataRows: dataRows
        )
        
        let essentialColumns = ["barcode", "productName", "purchasePrice"]
        let foundEssential = essentialColumns.filter { headerMap[$0] != nil }.count
        
        let totalRows = dataRows.count
        
        var rowsWithValidBarcode = 0
        if let bIndex = headerMap["barcode"] {
            rowsWithValidBarcode = dataRows.count(where: { row in
                guard bIndex < row.count else { return false }
                let v = row[bIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                return !v.isEmpty
            })
        }
        
        let extraKeys = [
            "quantity", "totalPrice",
            "retailPrice", "discountedPrice",
            "discount", "rowNumber",
            "supplier", "secondProductName", "category"
        ]
        let foundExtra = extraKeys.filter { headerMap[$0] != nil }.count
        
        let issues = detectIssues(
            header: header,
            headerMap: headerMap,
            dataRows: dataRows
        )
        
        return AnalysisMetrics(
            essentialColumnsFound: foundEssential,
            essentialColumnsTotal: essentialColumns.count,
            rowsWithValidBarcode: rowsWithValidBarcode,
            totalRows: totalRows,
            extraColumnsFound: foundExtra,
            extraColumnsTotal: extraKeys.count,
            confidenceScore: confidence,
            issues: issues
        )
    }
    
    /// Analizza problemi tipici (barcode duplicati, colonne vuote, ecc.)
    private static func detectIssues(
        header: [String],
        headerMap: [String: Int],
        dataRows: [[String]]
    ) -> [String] {
        var issues: [String] = []
        
        // 1) Barcode duplicati
        if let barcodeIdx = headerMap["barcode"] {
            var barcodeCounts: [String: Int] = [:]
            
            for row in dataRows {
                if barcodeIdx < row.count {
                    let barcode = row[barcodeIdx]
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !barcode.isEmpty {
                        barcodeCounts[barcode, default: 0] += 1
                    }
                }
            }
            
            let duplicates = barcodeCounts.filter { $0.value > 1 }
            if !duplicates.isEmpty {
                issues.append("Trovati \(duplicates.count) barcode duplicati nel file.")
            }
        }
        
        // 2) Colonne completamente vuote (escludendo quelle auto-generate tipo col1, col2)
        for (idx, colName) in header.enumerated() {
            let allEmpty = dataRows.allSatisfy { row in
                idx >= row.count ||
                row[idx].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            
            if allEmpty && !colName.hasPrefix("col") {
                issues.append("Colonna '\(colName)' completamente vuota.")
            }
        }
        
        // 3) Colonne obbligatorie mancanti
        let mandatory = ["barcode", "productName", "purchasePrice"]
        let missing = mandatory.filter { headerMap[$0] == nil }
        if !missing.isEmpty {
            let names = missing.joined(separator: ", ")
            issues.append("Colonne obbligatorie mancanti o non riconosciute: \(names).")
        }
        
        // 4) Percentuale bassa di righe con barcode valido
        if let barcodeIdx = headerMap["barcode"], !dataRows.isEmpty {
            let rowsWithBarcode = dataRows.count(where: { row in
                guard barcodeIdx < row.count else { return false }
                let v = row[barcodeIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                return !v.isEmpty
            })
            let ratio = Double(rowsWithBarcode) / Double(dataRows.count)
            if ratio < 0.3 {
                issues.append("Meno del 30% delle righe ha un barcode valido.")
            }
        }
        
        return issues
    }
}

// MARK: - Errori Excel

enum ExcelLoadError: LocalizedError {
    case unsupportedExtension(String)
    case xlsxNotSupported
    case htmlNotSupported
    case invalidFormat(String)
    case incompatibleHeader

    var errorDescription: String? {
        switch self {
        case .unsupportedExtension(let ext):
            return "Tipo di file non supportato (\(ext)). Usa un file Excel (.xlsx) o l'esportazione HTML."
        case .xlsxNotSupported:
            return "Il supporto per i file Excel (.xlsx) non è compilato: aggiungi la libreria CoreXLSX al progetto."
        case .htmlNotSupported:
            return "Il supporto per i file HTML non è compilato: aggiungi la libreria SwiftSoup al progetto."
        case .invalidFormat(let message):
            return message
        case .incompatibleHeader:
            return "I file selezionati non hanno la stessa intestazione di colonne."
        }
    }
}

// MARK: - Estensioni di supporto per l'analizzatore

extension String {
    /// Replica esatta di parseNumber() di Android
    func toDouble() -> Double? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // 1. Formato europeo: 1.234,56
        if trimmed.matches("^\\d{1,3}(\\.\\d{3})*,\\d+$") {
            let withoutSeparators = trimmed.replacingOccurrences(of: ".", with: "")
            let withPoint = withoutSeparators.replacingOccurrences(of: ",", with: ".")
            return Double(withPoint)
        }
        
        // 2. Formato inglese: 1,234.56
        if trimmed.matches("^\\d{1,3}(,\\d{3})*\\.\\d+$") {
            let withoutSeparators = trimmed.replacingOccurrences(of: ",", with: "")
            return Double(withoutSeparators)
        }
        
        // 3. Formato semplice: 1234.56 o 1234,56
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
    
    func matches(_ pattern: String) -> Bool {
        return range(of: pattern, options: .regularExpression) != nil
    }
    
    var columnDescription: String {
        switch self {
        case "barcode":
            return "Codice a barre (EAN/ISBN)."
        case "productName":
            return "Nome principale del prodotto."
        case "secondProductName":
            return "Secondo nome / traduzione del prodotto."
        case "itemNumber":
            return "Codice articolo interno / del fornitore."
        case "quantity":
            return "Quantità indicata dal fornitore."
        case "purchasePrice":
            return "Prezzo di acquisto unitario dal fornitore."
        case "retailPrice":
            return "Prezzo di vendita al cliente."
        case "discountedPrice":
            return "Prezzo di vendita scontato."
        case "totalPrice":
            return "Totale riga (quantità × prezzo unitario)."
        case "supplier":
            return "Nome del fornitore del prodotto."
        case "category":
            return "Categoria / reparto del prodotto."
        default:
            return "Colonna standard."
        }
    }
}

extension Sequence {
    /// Conta gli elementi che soddisfano il predicato (comodo per le euristiche).
    func count(where predicate: (Element) -> Bool) -> Int {
        var result = 0
        for element in self where predicate(element) {
            result += 1
        }
        return result
    }
}
