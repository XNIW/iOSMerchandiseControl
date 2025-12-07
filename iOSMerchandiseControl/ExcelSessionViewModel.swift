import Foundation
import SwiftUI
import SwiftData
import Combine

#if canImport(CoreXLSX)
import CoreXLSX
#endif

#if canImport(SwiftSoup)
import SwiftSoup
#endif

/// ViewModel globale per il flusso Excel
/// (equivalente concettuale di ExcelViewModel su Android)
@MainActor
final class ExcelSessionViewModel: ObservableObject {

    // Header normalizzato (es. ["barcode", "productName", "purchasePrice", ...])
    @Published var header: [String] = []

    // Tutte le righe dell'Excel (riga 0 = header normalizzato)
    @Published var rows: [[String]] = []

    // Selezione colonne (stessa lunghezza di `header`)
    @Published var selectedColumns: [Bool] = []

    // Parametri "globali" per il file corrente
    @Published var supplierName: String = ""
    @Published var categoryName: String = ""

    // HistoryEntry generata a partire da questo Excel
    @Published var currentHistoryEntry: HistoryEntry?
    
    // Stato di caricamento (per mostrare eventuale progress)
    @Published var isLoading: Bool = false
    @Published var progress: Double? = nil    // 0.0 ... 1.0
    @Published var lastError: String? = nil

    var hasData: Bool {
        !rows.isEmpty
    }

    // Colonne essenziali (come su Android: barcode, productName, purchasePrice)
    private static let essentialColumnKeys: Set<String> = [
        "barcode",
        "productName",
        "purchasePrice"
    ]

    // MARK: - Gestione stato

    func resetState() {
        header = []
        rows = []
        selectedColumns = []
        supplierName = ""
        categoryName = ""
        isLoading = false
        progress = nil
        lastError = nil
    }

    // MARK: - Selezione colonne (equivalente di isColumnEssential / toggleColumnSelection)

    func isColumnEssential(at index: Int) -> Bool {
        guard header.indices.contains(index) else { return false }
        return Self.essentialColumnKeys.contains(header[index])
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

    func toggleColumnSelection(index: Int) {
        guard selectedColumns.indices.contains(index) else { return }
        updateColumnSelection(index: index, isSelected: !selectedColumns[index])
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

    // MARK: - Caricamento file Excel/HTML (Step 1)

    /// Carica e analizza uno o più file (Excel HTML-export) e popola header/rows.
    /// È l'equivalente iOS di loadFromMultipleUris + readAndAnalyzeExcel su Android.
    func load(from urls: [URL], in context: ModelContext) async throws {
        guard !urls.isEmpty else { return }

        resetState()
        isLoading = true
        progress = 0

        do {
            let (newHeader, allRows) = try ExcelAnalyzer.loadFromMultipleURLs(urls)

            // Torniamo sul MainActor
            header = newHeader
            rows = allRows
            selectedColumns = Array(repeating: true, count: newHeader.count)
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
        guard !header.isEmpty, !rows.isEmpty else {
            throw GenerateHistoryError.emptySession
        }

        // Selezione colonne coerente (fallback: tutte selezionate)
        if selectedColumns.count != header.count {
            selectedColumns = Array(repeating: true, count: header.count)
        }

        let selectedIndices: [Int] = header.indices.filter { idx in
            guard selectedColumns.indices.contains(idx) else { return true }
            return selectedColumns[idx]
        }

        // Indice colonna barcode nell'header normalizzato ("barcode", come da normalizeHeaderCell)
        let barcodeIndex = header.firstIndex(of: "barcode")

        // 2. Mappa barcode → (oldPurchase, oldRetail) dal DB (Product)
        let priceMap = try fetchOldPricesByBarcode(
            barcodeIndex: barcodeIndex,
            context: context
        )

        // 3. Costruzione matrice dati "filtrata"
        var filteredData: [[String]] = []

        // Header filtrato + colonne extra
        var filteredHeader = selectedIndices.map { header[$0] }
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
}

// MARK: - Analisi file Excel/HTML (equivalente di ExcelUtils.kt su Android)

struct ExcelAnalyzer {

    /// Porta la logica di loadFromMultipleUris(context, uris)
    static func loadFromMultipleURLs(_ urls: [URL]) throws -> ([String], [[String]]) {
        guard let firstURL = urls.first else {
            throw ExcelLoadError.invalidFormat("Nessun file selezionato.")
        }

        let (goldenHeader, firstDataRows) = try readAndAnalyzeExcel(from: firstURL)
        var allValidRows = firstDataRows

        if urls.count > 1 {
            for url in urls.dropFirst() {
                let (header, dataRows) = try readAndAnalyzeExcel(from: url)
                // Per ora richiediamo che gli header normalizzati siano identici
                if header != goldenHeader {
                    throw ExcelLoadError.incompatibleHeader
                }
                allValidRows.append(contentsOf: dataRows)
            }
        }

        let rowsWithHeader = [goldenHeader] + allValidRows
        return (goldenHeader, rowsWithHeader)
    }

    /// Porta la logica di readAndAnalyzeExcel(context, uri)
    static func readAndAnalyzeExcel(from url: URL) throws -> ([String], [[String]]) {
        let data = try Data(contentsOf: url)
        let ext = url.pathExtension.lowercased()

        let rows: [[String]]

        if ext == "html" || ext == "htm" || looksLikeHtml(data: data) {
            rows = try rowsFromHTML(data: data)
        } else if ext == "xlsx" || ext == "xls" || ext.isEmpty {
            #if canImport(CoreXLSX)
            rows = try rowsFromXLSX(at: url)
            #else
            throw ExcelLoadError.xlsxNotSupported
            #endif
        } else {
            throw ExcelLoadError.unsupportedExtension(ext)
        }

        return analyzeRows(rows)
    }

    private static func looksLikeHtml(data: Data) -> Bool {
        guard let snippet = String(data: data.prefix(512), encoding: .utf8)?.lowercased() else {
            return false
        }
        return snippet.contains("<html") ||
               snippet.contains("<table") ||
               snippet.contains("<!doctype html")
    }

    // MARK: HTML → righe

    #if canImport(SwiftSoup)
    private static func rowsFromHTML(data: Data) throws -> [[String]] {
        guard let html = String(data: data, encoding: .utf8) ??
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

    // MARK: XLSX → righe

    #if canImport(CoreXLSX)
    private static func rowsFromXLSX(at url: URL) throws -> [[String]] {
        guard let file = XLSXFile(filepath: url.path) else {
            throw ExcelLoadError.invalidFormat("Impossibile aprire il file Excel.")
        }

        let sharedStrings = try? file.parseSharedStrings()
        var result: [[String]] = []

        for workbook in try file.parseWorkbooks() {
            for (_, path) in try file.parseWorksheetPathsAndNames(workbook: workbook) {
                let worksheet = try file.parseWorksheet(at: path)
                let sheetRows = worksheet.data?.rows ?? []

                for row in sheetRows {
                    var cells: [String] = []

                    for cell in row.cells {
                        var raw: String?

                        if let sharedStrings = sharedStrings,
                           let v = cell.stringValue(sharedStrings) {
                            raw = v
                        } else if let inline = cell.inlineString?.text {
                            raw = inline
                        } else {
                            raw = cell.value
                        }

                        let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        cells.append(value)
                    }

                    // togli trailing vuoti
                    while let last = cells.last, last.isEmpty {
                        cells.removeLast()
                    }

                    if cells.contains(where: { !$0.isEmpty }) {
                        result.append(cells)
                    }
                }

                // Usa solo il primo sheet non vuoto
                if !result.isEmpty {
                    return result
                }
            }
        }

        return result
    }
    #else
    private static func rowsFromXLSX(at url: URL) throws -> [[String]] {
        throw ExcelLoadError.xlsxNotSupported
    }
    #endif

    // MARK: Heuristics per header / righe dati

    private static func analyzeRows(_ rows: [[String]]) -> ([String], [[String]]) {
        guard !rows.isEmpty else {
            return ([], [])
        }

        // Trova la prima riga che "sembra" dati (>=3 numeri e >=1 testo)
        let dataRowIndex: Int? = rows.firstIndex { row in
            var numericCount = 0
            var textCount = 0

            for cell in row {
                let trimmed = cell.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }

                let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
                if Double(normalized) != nil {
                    numericCount += 1
                } else {
                    textCount += 1
                }
            }

            return numericCount >= 3 && textCount >= 1
        }

        let headerRow: [String]
        let firstDataRowIndex: Int

        if let idx = dataRowIndex, idx > 0, idx < rows.count {
            // header = riga subito prima dei dati (come su Android)
            headerRow = rows[idx - 1]
            firstDataRowIndex = idx
        } else {
            // fallback: prima riga come header
            headerRow = rows[0]
            firstDataRowIndex = 1
        }

        let maxDataCols = rows[firstDataRowIndex..<rows.count].map { $0.count }.max() ?? 0
        let colCount = max(headerRow.count, maxDataCols)

        // Normalizza header in chiavi tipo "barcode", "productName", ...
        var normalizedHeader: [String] = []
        normalizedHeader.reserveCapacity(colCount)

        for index in 0..<colCount {
            let raw = index < headerRow.count ? headerRow[index] : ""
            normalizedHeader.append(normalizeHeaderCell(raw, index: index))
        }

        // Righe dati (tutte con la stessa lunghezza di colCount)
        var dataRows: [[String]] = []

        if firstDataRowIndex < rows.count {
            for row in rows[firstDataRowIndex..<rows.count] {
                var r = row
                if r.count < colCount {
                    r.append(contentsOf: Array(repeating: "", count: colCount - r.count))
                } else if r.count > colCount {
                    r = Array(r.prefix(colCount))
                }

                if r.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    dataRows.append(r)
                }
            }
        }

        return (normalizedHeader, dataRows)
    }

    /// Normalizza un header "umano" in una chiave tecnica (simile a ExcelUtils.kt)
    private static func normalizeHeaderCell(_ raw: String, index: Int) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "col\(index + 1)"
        }

        let folded = trimmed.folding(options: .diacriticInsensitive, locale: .current)
        let lower = folded.lowercased()
        let collapsed = lower.replacingOccurrences(of: "[^a-z0-9]+",
                                                   with: "",
                                                   options: .regularExpression)

        let aliasTable: [(key: String, patterns: [String])] = [
            ("barcode", ["barcode", "条码", "tiaoma", "ean", "codbarra", "codbarras", "codigodebarras", "codebarre", "codigo", "codprod"]),
            ("quantity", ["quantity", "qty", "quantita", "quantità", "数量", "cant", "cantidad", "qta", "qt"]),
            ("purchasePrice", ["purchaseprice", "prezzoacquisto", "costo", "cost", "采购价", "precio_compra", "preciocompra"]),
            ("retailPrice", ["retailprice", "prezzovendita", "售价", "venta", "precio", "pvp"]),
            ("totalPrice", ["totalprice", "totale", "importe", "总价", "合计", "subtotal", "subtotale"]),
            ("productName", ["productname", "品名", "nome", "descrizione", "descripcion", "descripción", "nombre", "商品"]),
            ("secondProductName", ["secondproductname", "productname2", "nome2", "nombre2"]),
            ("itemNumber", ["itemnumber", "货号", "articolo", "codicearticolo", "sku", "ref", "referencia"]),
            ("supplier", ["supplier", "供应商", "fornitore", "vendor", "proveedor"]),
            ("category", ["category", "categoria", "分类", "familia", "grupo"])
        ]

        for (key, patterns) in aliasTable {
            for pattern in patterns {
                let normPattern = pattern
                    .folding(options: .diacriticInsensitive, locale: .current)
                    .lowercased()
                    .replacingOccurrences(of: "[^a-z0-9]+",
                                          with: "",
                                          options: .regularExpression)

                if !normPattern.isEmpty && collapsed.contains(normPattern) {
                    return key
                }
            }
        }

        // fallback: usa la versione "pulita"
        return collapsed.isEmpty ? "col\(index + 1)" : collapsed
    }
}

// MARK: - Errori specifici per il caricamento Excel

enum ExcelLoadError: LocalizedError {
    case unsupportedExtension(String)
    case xlsxNotSupported
    case htmlNotSupported
    case invalidFormat(String)
    case incompatibleHeader

    var errorDescription: String? {
        switch self {
        case .unsupportedExtension(let ext):
            return "Tipo di file non supportato (\(ext)). Usa un file Excel (.xlsx) o l’esportazione HTML."
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
