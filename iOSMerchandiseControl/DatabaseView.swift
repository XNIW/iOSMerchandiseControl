import SwiftUI
import SwiftData
import Combine
import UniformTypeIdentifiers
import xlsxwriter

private struct DatabaseImportProgressSnapshot: Sendable {
    let stageText: String
    let processedCount: Int
    let totalCount: Int
}

private struct ImportProductDraftSnapshot: Sendable {
    let barcode: String
    let itemNumber: String?
    let productName: String?
    let secondProductName: String?
    let purchasePrice: Double?
    let retailPrice: Double?
    let stockQuantity: Double?
    let supplierName: String?
    let categoryName: String?

    init(_ draft: ProductDraft) {
        barcode = draft.barcode
        itemNumber = draft.itemNumber
        productName = draft.productName
        secondProductName = draft.secondProductName
        purchasePrice = draft.purchasePrice
        retailPrice = draft.retailPrice
        stockQuantity = draft.stockQuantity
        supplierName = draft.supplierName
        categoryName = draft.categoryName
    }
}

private struct ImportProductUpdateSnapshot: Sendable {
    let barcode: String
    let newDraft: ImportProductDraftSnapshot
    let changedFields: [ProductUpdateDraft.ChangedField]

    init(_ update: ProductUpdateDraft) {
        barcode = update.barcode
        newDraft = ImportProductDraftSnapshot(update.new)
        changedFields = Array(update.changedFields)
    }
}

private struct ImportPendingPriceHistoryEntrySnapshot: Sendable {
    let barcode: String
    let type: PriceType
    let price: Double
    let effectiveAt: Date
    let source: String
}

private struct ImportApplyPayload: Sendable {
    let newProducts: [ImportProductDraftSnapshot]
    let updatedProducts: [ImportProductUpdateSnapshot]
    let pendingPriceHistoryEntries: [ImportPendingPriceHistoryEntrySnapshot]
    let recordPriceHistory: Bool

    var productsTotalCount: Int {
        newProducts.count + updatedProducts.count
    }
}

@MainActor
private final class DatabaseImportProgressState: ObservableObject, @unchecked Sendable {
    @Published var isRunning = false
    @Published var stageText = ""
    @Published var processedCount = 0
    @Published var totalCount = 0
    @Published var resultMessage: String?
    @Published var resultIsError = false

    var progressFraction: Double? {
        guard totalCount > 0 else { return nil }
        return Double(processedCount) / Double(totalCount)
    }

    var resultTitle: String {
        resultIsError ? "Errore import" : "Import completato"
    }

    func startPreparation() {
        isRunning = true
        stageText = "Preparazione import..."
        processedCount = 0
        totalCount = 0
        resultMessage = nil
        resultIsError = false
    }

    func apply(_ snapshot: DatabaseImportProgressSnapshot) {
        isRunning = true
        stageText = snapshot.stageText
        processedCount = snapshot.processedCount
        totalCount = snapshot.totalCount
    }

    func finishSuccess(message: String) {
        isRunning = false
        resultMessage = message
        resultIsError = false
    }

    func finishError(message: String) {
        isRunning = false
        resultMessage = message
        resultIsError = true
    }

    func clearResult() {
        resultMessage = nil
    }
}

struct DatabaseView: View {
    @Environment(\.modelContext) private var context

    // Tutti i prodotti dal database, ordinati per barcode
    @Query(sort: \Product.barcode, order: .forward)
    private var products: [Product]

    @State private var barcodeFilter: String = ""
    @State private var showAddSheet = false
    @State private var productToEdit: Product?
    @State private var productForHistory: Product?
    
    @State private var showScanner = false
    @State private var pendingBarcodeForNewProduct: String? = nil

    // Export / import
    @State private var exportURL: URL?
    @State private var showingExportSheet = false
    @State private var showingExportOptions = false

    // Import prodotti (CSV semplice + Excel con analisi)
    @State private var showingImportOptions = false
    @State private var showingCSVImportPicker = false
    @State private var showingExcelImportPicker = false
    @State private var showingFullExcelImportPicker = false

    @State private var importError: String?
    
    // Risultato analisi import da Excel
    @State private var importAnalysisResult: ProductImportAnalysisResult?
    @State private var pendingFullImportContext: PendingFullImportContext?
    @StateObject private var importProgress = DatabaseImportProgressState()

    private struct PendingPriceHistoryImportEntry: Sendable {
        let barcode: String
        let type: PriceType
        let price: Double
        let effectiveAt: Date
        let source: String
    }

    private struct PendingFullImportContext: Sendable {
        let priceHistoryEntries: [PendingPriceHistoryImportEntry]
        let suppressAutomaticProductPriceHistory: Bool
    }

    private struct ExportedProductRow {
        let barcode: String
        let itemNumber: String
        let productName: String
        let secondProductName: String
        let purchasePrice: Double?
        let retailPrice: Double?
        let stockQuantity: Double?
        let supplierName: String
        let categoryName: String
    }

    private static let importSaveBatchSize = 250
    private static let importProgressBatchSize = 25
    
    // filtro in memoria sui prodotti, come facevi in Compose
    private var filteredProducts: [Product] {
        let trimmed = barcodeFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return products }

        let lower = trimmed.lowercased()
        return products.filter { product in
            if product.barcode.lowercased().contains(lower) { return true }
            if let item = product.itemNumber?.lowercased(), item.contains(lower) { return true }
            if let name = product.productName?.lowercased(), name.contains(lower) { return true }
            if let second = product.secondProductName?.lowercased(), second.contains(lower) { return true }
            return false
        }
    }

    var body: some View {
        VStack {
            // campo filtro barcode / nome / codice
            HStack(spacing: 8) {
                TextField("Cerca per barcode, nome o codice", text: $barcodeFilter)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !barcodeFilter.isEmpty {
                    Button {
                        barcodeFilter = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    showScanner = true
                } label: {
                    Image(systemName: "camera.viewfinder")
                }
            }
            .padding(.horizontal)
            .padding(.top)

            // lista prodotti
            List {
                ForEach(filteredProducts) { (product: Product) in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.productName ?? "Senza nome")
                                    .font(.headline)

                                if let second = product.secondProductName,
                                   !second.isEmpty {
                                    Text(second)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                Text("Barcode: \(product.barcode)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if let item = product.itemNumber,
                                   !item.isEmpty {
                                    Text("Codice: \(item)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                if let purchase = product.purchasePrice {
                                    Text("Acq: \(formatMoney(purchase))")
                                        .font(.caption)
                                }
                                if let retail = product.retailPrice {
                                    Text("Vend: \(formatMoney(retail))")
                                        .font(.caption)
                                }
                                if let qty = product.stockQuantity {
                                    Text("Stock: \(formatQuantity(qty))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        HStack {
                            if let supplierName = product.supplier?.name,
                               !supplierName.isEmpty {
                                Text("Fornitore: \(supplierName)")
                            }
                            if let categoryName = product.category?.name,
                               !categoryName.isEmpty {
                                if product.supplier != nil {
                                    Text("·")
                                }
                                Text("Categoria: \(categoryName)")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                        HStack {
                            Button {
                                productToEdit = product
                            } label: {
                                Label("Modifica", systemImage: "pencil")
                            }

                            Spacer()

                            Button {
                                productForHistory = product
                            } label: {
                                Label("Storico prezzi", systemImage: "clock.arrow.circlepath")
                            }
                            .buttonStyle(.borderless)
                        }
                        .font(.footnote)
                        .padding(.top, 2)
                    }
                    .contentShape(Rectangle()) // tutta la riga tappabile
                    .onTapGesture {
                        productToEdit = product
                    }
                }
                .onDelete(perform: deleteProducts)
            }
            .listStyle(.plain)
        }
        .disabled(importProgress.isRunning)
        .overlay {
            if importProgress.isRunning {
                importProgressOverlay
            }
        }
        .navigationTitle("Database")
        .toolbar {
            // import / export + nuovo prodotto
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        // Mostra dialog per scegliere Excel vs CSV
                        showingImportOptions = true
                    } label: {
                        Image(systemName: "tray.and.arrow.down")
                    }

                    Button {
                        showingExportOptions = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Button {
                        pendingBarcodeForNewProduct = nil
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }

        }
        // Sheet per NUOVO prodotto
        .sheet(isPresented: $showAddSheet) {
            NavigationStack {
                EditProductView(initialBarcode: pendingBarcodeForNewProduct)
            }
        }
        // Sheet per MODIFICA prodotto esistente
        .sheet(item: $productToEdit) { (product: Product) in
            NavigationStack {
                EditProductView(product: product)
            }
        }
        // Sheet per storico prezzi
        .sheet(item: $productForHistory) { (product: Product) in
            NavigationStack {
                ProductPriceHistoryView(product: product)
            }
        }
        // Sheet per condividere il CSV/XLSX export
        .sheet(isPresented: $showingExportSheet) {
            if let exportURL {
                ShareSheet(items: [exportURL])
            } else {
                Text("Nessun file da condividere.")
                    .padding()
            }
        }

        // Sheet per l’analisi di import da Excel
        .sheet(item: $importAnalysisResult) { analysis in
            NavigationStack {
                ImportAnalysisView(
                    analysis: analysis,
                    allowsApplyWithoutChanges: pendingFullImportContext != nil,
                    onApply: { editedAnalysis in
                        try await applyConfirmedImportAnalysis(editedAnalysis)
                        importAnalysisResult = nil
                    }
                )
            }
        }
        // Sheet per scanner barcode
        .sheet(isPresented: $showScanner) {
            ScannerView(title: "Scanner prodotti") { code in
                handleDatabaseScan(code)
            }
        }

        .confirmationDialog(
            "Esporta prodotti",
            isPresented: $showingExportOptions,
            titleVisibility: .visible
        ) {
            Button("Esporta prodotti") {
                exportProducts()
            }
            Button("Esporta database completo") {
                exportFullDatabase()
            }
            Button("Annulla", role: .cancel) { }
        }

        // Dialog per scegliere il tipo di import
        .confirmationDialog(
            "Importa prodotti",
            isPresented: $showingImportOptions,
            titleVisibility: .visible
        ) {
            Button("Importa da Excel (analisi)") {
                showingExcelImportPicker = true
            }
            Button("Importa database completo") {
                showingFullExcelImportPicker = true
            }
            Button("Importa da CSV (semplice)") {
                showingCSVImportPicker = true
            }
            Button("Annulla", role: .cancel) { }
        }

        // Import CSV (flow semplice esistente)
        .fileImporter(
            isPresented: $showingCSVImportPicker,
            allowedContentTypes: [UTType.commaSeparatedText, UTType.plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importProducts(from: url)
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }

        // Import Excel con analisi
        .fileImporter(
            isPresented: $showingExcelImportPicker,
            allowedContentTypes: [.spreadsheet, .html],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importProductsFromExcel(url: url)
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }

        .fileImporter(
            isPresented: $showingFullExcelImportPicker,
            allowedContentTypes: [.spreadsheet],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importFullDatabaseFromExcel(url: url)
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }

        .alert(
            "Errore import",
            isPresented: Binding(
                get: { importError != nil },
                set: { newValue in
                    if !newValue { importError = nil }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                importError = nil
            }
        } message: {
            Text(importError ?? "")
        }
        .alert(
            importProgress.resultTitle,
            isPresented: Binding(
                get: { importProgress.resultMessage != nil },
                set: { newValue in
                    if !newValue {
                        importProgress.clearResult()
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                importProgress.clearResult()
            }
        } message: {
            Text(importProgress.resultMessage ?? "")
        }
    }

    private var importProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text(importProgress.stageText.isEmpty ? "Preparazione import..." : importProgress.stageText)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let progressFraction = importProgress.progressFraction {
                    ProgressView(value: progressFraction)
                        .progressViewStyle(.linear)

                    Text("\(importProgress.processedCount) / \(importProgress.totalCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(radius: 16, x: 0, y: 8)
            .padding(.horizontal, 24)
        }
    }



    // MARK: - Azioni base

    private func handleDatabaseScan(_ code: String) {
        let cleaned = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }

        // Aggiorna filtro come feedback visivo
        barcodeFilter = cleaned

        if let existing = products.first(where: { $0.barcode == cleaned }) {
            // Prodotto già presente → apri edit
            productToEdit = existing
        } else {
            // Nessun prodotto → crea nuovo con barcode precompilato
            pendingBarcodeForNewProduct = cleaned
            showAddSheet = true
        }
    }
    
    private func deleteProducts(at offsets: IndexSet) {
        for index in offsets {
            let product = filteredProducts[index]
            context.delete(product)
        }
        do {
            try context.save()
        } catch {
            print("Errore durante l'eliminazione: \(error)")
        }
    }

    private enum FullDatabaseImportError: LocalizedError {
        case invalidWorkbook
        case missingProductsSheet

        var errorDescription: String? {
            switch self {
            case .invalidWorkbook:
                return "Impossibile leggere il file. Assicurarsi che sia un file Excel (.xlsx) valido con più fogli."
            case .missingProductsSheet:
                return "Il file non contiene un foglio 'Products'. L'importazione completa richiede almeno questo foglio."
            }
        }
    }

    // MARK: - Export prodotti (XLSX di default)

    private func exportProducts() {
        do {
            // Ora esportiamo direttamente in XLSX
            let url = try makeProductsXLSX()
            exportURL = url
            showingExportSheet = true
        } catch {
            importError = "Errore durante l'export: \(error.localizedDescription)"
        }
    }

    private func exportFullDatabase() {
        do {
            let url = try makeFullDatabaseXLSX()
            exportURL = url
            showingExportSheet = true
        } catch {
            importError = "Errore durante l'export: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Export XLSX (writer reale tramite xlsxwriter.swift)

    /// Genera un file XLSX con la stessa struttura del CSV attuale
    private func makeProductsXLSX() throws -> URL {
        let exportRows = try exportedProductRows()

        // Stesse colonne del CSV esistente
        let headers = [
            "barcode",
            "itemNumber",
            "productName",
            "secondProductName",
            "purchasePrice",
            "retailPrice",
            "stockQuantity",
            "supplierName",
            "categoryName"
        ]

        // Path nel temporaryDirectory (così ShareLink funziona tranquillo)
        let tmpDir = FileManager.default.temporaryDirectory
        let filename = "products_\(Int(Date().timeIntervalSince1970)).xlsx"
        let url = tmpDir.appendingPathComponent(filename)

        // Crea il workbook puntando al path completo
        // Nota: usiamo il nome completo del file, esattamente come negli esempi di xlsxwriter.swift
        // e libxlsxwriter: Workbook(name: filePath) :contentReference[oaicite:5]{index=5}
        let workbook = xlsxwriter.Workbook(name: url.path)

        // Un solo worksheet per ora
        let worksheet = workbook.addWorksheet(name: "Products")

        // Riga 0: header
        for (columnIndex, header) in headers.enumerated() {
            worksheet.write(.string(header), [0, columnIndex])
        }

        // Righe dati: dalla riga 1 in avanti
        for (rowIndex, product) in exportRows.enumerated() {
            let row = rowIndex + 1   // 0 = header, 1..n = dati

            // 0: barcode (obbligatorio)
            worksheet.write(.string(product.barcode), [row, 0])

            // 1: itemNumber
            worksheet.write(.string(product.itemNumber), [row, 1])

            // 2: nome prodotto principale
            worksheet.write(.string(product.productName), [row, 2])

            // 3: secondo nome
            worksheet.write(.string(product.secondProductName), [row, 3])

            // 4: purchasePrice (numero, non stringa)
            if let purchase = product.purchasePrice {
                worksheet.write(.number(purchase), [row, 4])
            }

            // 5: retailPrice (numero)
            if let retail = product.retailPrice {
                worksheet.write(.number(retail), [row, 5])
            }

            // 6: stockQuantity (numero)
            if let stock = product.stockQuantity {
                worksheet.write(.number(stock), [row, 6])
            }

            // 7: supplierName
            worksheet.write(.string(product.supplierName), [row, 7])

            // 8: categoryName
            worksheet.write(.string(product.categoryName), [row, 8])
        }

        workbook.close()
        try validateExportedProductsSheet(at: url, expectedRows: exportRows)
        return url
    }

    private func makeFullDatabaseXLSX() throws -> URL {
        struct ExportedPriceHistoryRow {
            let productBarcode: String
            let timestamp: Date
            let type: String
            let newPrice: Double
            let source: String
        }

        let productRows = try exportedProductRows()

        let supplierDescriptor = FetchDescriptor<Supplier>()
        let categoryDescriptor = FetchDescriptor<ProductCategory>()
        let priceHistoryDescriptor = FetchDescriptor<ProductPrice>()

        let suppliers = try context.fetch(supplierDescriptor)
            .sorted { $0.name < $1.name }
        let categories = try context.fetch(categoryDescriptor)
            .sorted { $0.name < $1.name }
        let priceHistoryRows = try context.fetch(priceHistoryDescriptor)
            .compactMap { entry -> ExportedPriceHistoryRow? in
                guard let barcode = entry.product?.barcode else {
                    return nil
                }

                return ExportedPriceHistoryRow(
                    productBarcode: barcode,
                    timestamp: entry.effectiveAt,
                    type: entry.type.rawValue,
                    newPrice: entry.price,
                    source: entry.source ?? ""
                )
            }
            .sorted {
                if $0.productBarcode != $1.productBarcode {
                    return $0.productBarcode < $1.productBarcode
                }
                if $0.type != $1.type {
                    return $0.type < $1.type
                }
                return $0.timestamp < $1.timestamp
            }

        let tmpDir = FileManager.default.temporaryDirectory
        let filename = "database_full_\(Int(Date().timeIntervalSince1970)).xlsx"
        let url = tmpDir.appendingPathComponent(filename)
        let workbook = xlsxwriter.Workbook(name: url.path)

        let productsSheet = workbook.addWorksheet(name: "Products")
        let productsHeaders = [
            "barcode",
            "itemNumber",
            "productName",
            "secondProductName",
            "purchasePrice",
            "retailPrice",
            "stockQuantity",
            "supplierName",
            "categoryName"
        ]

        for (columnIndex, header) in productsHeaders.enumerated() {
            productsSheet.write(.string(header), [0, columnIndex])
        }

        for (rowIndex, product) in productRows.enumerated() {
            let row = rowIndex + 1
            productsSheet.write(.string(product.barcode), [row, 0])
            productsSheet.write(.string(product.itemNumber), [row, 1])
            productsSheet.write(.string(product.productName), [row, 2])
            productsSheet.write(.string(product.secondProductName), [row, 3])

            if let purchase = product.purchasePrice {
                productsSheet.write(.number(purchase), [row, 4])
            }
            if let retail = product.retailPrice {
                productsSheet.write(.number(retail), [row, 5])
            }
            if let stock = product.stockQuantity {
                productsSheet.write(.number(stock), [row, 6])
            }

            productsSheet.write(.string(product.supplierName), [row, 7])
            productsSheet.write(.string(product.categoryName), [row, 8])
        }

        let suppliersSheet = workbook.addWorksheet(name: "Suppliers")
        suppliersSheet.write(.string("name"), [0, 0])
        for (rowIndex, supplier) in suppliers.enumerated() {
            suppliersSheet.write(.string(supplier.name), [rowIndex + 1, 0])
        }

        let categoriesSheet = workbook.addWorksheet(name: "Categories")
        categoriesSheet.write(.string("name"), [0, 0])
        for (rowIndex, category) in categories.enumerated() {
            categoriesSheet.write(.string(category.name), [rowIndex + 1, 0])
        }

        let priceHistorySheet = workbook.addWorksheet(name: "PriceHistory")
        let priceHistoryHeaders = [
            "productBarcode",
            "timestamp",
            "type",
            "oldPrice",
            "newPrice",
            "source"
        ]

        for (columnIndex, header) in priceHistoryHeaders.enumerated() {
            priceHistorySheet.write(.string(header), [0, columnIndex])
        }

        var previousPriceByGroup: [String: Double] = [:]
        for (rowIndex, rowData) in priceHistoryRows.enumerated() {
            let row = rowIndex + 1
            let groupKey = "\(rowData.productBarcode)|\(rowData.type)"
            let oldPrice = previousPriceByGroup[groupKey]

            priceHistorySheet.write(.string(rowData.productBarcode), [row, 0])
            priceHistorySheet.write(
                .string(Self.fullDatabaseTimestampFormatter.string(from: rowData.timestamp)),
                [row, 1]
            )
            priceHistorySheet.write(.string(rowData.type), [row, 2])
            if let oldPrice {
                priceHistorySheet.write(.number(oldPrice), [row, 3])
            }
            priceHistorySheet.write(.number(rowData.newPrice), [row, 4])
            priceHistorySheet.write(.string(rowData.source), [row, 5])

            previousPriceByGroup[groupKey] = rowData.newPrice
        }

        workbook.close()
        try validateExportedProductsSheet(at: url, expectedRows: productRows)
        return url
    }

    private func exportedProductRows() throws -> [ExportedProductRow] {
        let descriptor = FetchDescriptor<Product>(
            sortBy: [SortDescriptor(\Product.barcode, order: .forward)]
        )

        return try context.fetch(descriptor).map { product in
            ExportedProductRow(
                barcode: product.barcode,
                itemNumber: product.itemNumber ?? "",
                productName: product.productName ?? "",
                secondProductName: product.secondProductName ?? "",
                purchasePrice: product.purchasePrice,
                retailPrice: product.retailPrice,
                stockQuantity: product.stockQuantity,
                supplierName: resolvedSupplierName(for: product),
                categoryName: resolvedCategoryName(for: product)
            )
        }
    }

    private func resolvedSupplierName(for product: Product) -> String {
        resolvedCurrentProduct(for: product)?.supplier?.name
            ?? product.supplier?.name
            ?? products.first(where: { $0.barcode == product.barcode })?.supplier?.name
            ?? ""
    }

    private func resolvedCategoryName(for product: Product) -> String {
        resolvedCurrentProduct(for: product)?.category?.name
            ?? product.category?.name
            ?? products.first(where: { $0.barcode == product.barcode })?.category?.name
            ?? ""
    }

    private func resolvedCurrentProduct(for product: Product) -> Product? {
        context.model(for: product.persistentModelID) as? Product
    }

    private func validateExportedProductsSheet(
        at url: URL,
        expectedRows: [ExportedProductRow]
    ) throws {
        let rows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: "Products")
        guard let header = rows.first else {
            throw NSError(
                domain: "ExportExcel",
                code: 20,
                userInfo: [NSLocalizedDescriptionKey: "Il file esportato non contiene il foglio Products."]
            )
        }

        guard let barcodeIndex = header.firstIndex(of: "barcode"),
              let supplierIndex = header.firstIndex(of: "supplierName"),
              let categoryIndex = header.firstIndex(of: "categoryName") else {
            throw NSError(
                domain: "ExportExcel",
                code: 21,
                userInfo: [NSLocalizedDescriptionKey: "Il foglio Products esportato non contiene le colonne attese."]
            )
        }

        let actualByBarcode = Dictionary(
            uniqueKeysWithValues: rows.dropFirst().compactMap { row -> (String, (String, String))? in
                let barcode = Self.cellValue(in: row, at: barcodeIndex)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !barcode.isEmpty else { return nil }

                return (
                    barcode,
                    (
                        Self.cellValue(in: row, at: supplierIndex)
                            .trimmingCharacters(in: .whitespacesAndNewlines),
                        Self.cellValue(in: row, at: categoryIndex)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                )
            }
        )

        for expected in expectedRows {
            guard let actual = actualByBarcode[expected.barcode] else {
                throw NSError(
                    domain: "ExportExcel",
                    code: 22,
                    userInfo: [NSLocalizedDescriptionKey: "Manca la riga del prodotto \(expected.barcode) nel file esportato."]
                )
            }

            let expectedSupplier = expected.supplierName.trimmingCharacters(in: .whitespacesAndNewlines)
            let expectedCategory = expected.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)

            if actual.0 != expectedSupplier || actual.1 != expectedCategory {
                throw NSError(
                    domain: "ExportExcel",
                    code: 23,
                    userInfo: [
                        NSLocalizedDescriptionKey: "I valori supplier/category del prodotto \(expected.barcode) non sono stati esportati correttamente."
                    ]
                )
            }
        }
    }

    private func escapeCSVField(_ field: String) -> String {
        if field.contains(";") || field.contains("\"") || field.contains("\n") {
            var escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            escaped = "\"\(escaped)\""
            return escaped
        } else {
            return field
        }
    }

    // MARK: - Import Excel con analisi (stile Android)

    private func importProductsFromExcel(url: URL) {
        do {
            pendingFullImportContext = nil
            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(
                    domain: "ImportExcel",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Permessi file negati"]
                )
            }
            defer { url.stopAccessingSecurityScopedResource() }

            // Usa lo stesso motore dell’inventario per leggere Excel/HTML
            let (_, normalizedHeader, dataRows) = try ExcelAnalyzer.readAndAnalyzeExcel(from: url)

            // Carichiamo i prodotti esistenti una sola volta
            let descriptor = FetchDescriptor<Product>()
            let existingProducts = try context.fetch(descriptor)

            let analysis = try analyzeImport(
                header: normalizedHeader,   // <-- usiamo l'header normalizzato
                dataRows: dataRows,
                existingProducts: existingProducts
            )

            importAnalysisResult = analysis
        } catch {
            if let error = error as? LocalizedError, let description = error.errorDescription {
                importError = description
            } else {
                importError = "Errore durante l'import Excel: \(error.localizedDescription)"
            }
        }
    }

    private func importFullDatabaseFromExcel(url: URL) {
        do {
            pendingFullImportContext = nil

            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(
                    domain: "ImportExcelFull",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Permessi file negati"]
                )
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let sheetNames: [String]
            do {
                sheetNames = try ExcelAnalyzer.listSheetNames(at: url)
            } catch {
                throw FullDatabaseImportError.invalidWorkbook
            }

            let sheetNameMap = Dictionary(
                uniqueKeysWithValues: sheetNames.map { (Self.normalizedSheetName($0), $0) }
            )

            if let suppliersSheetName = sheetNameMap[Self.normalizedSheetName("Suppliers")] {
                try importNamedEntitiesSheet(
                    at: url,
                    sheetName: suppliersSheetName,
                    entityLabel: "Suppliers",
                    createEntity: { name in
                        _ = findOrCreateSupplier(named: name)
                    }
                )
            }

            if let categoriesSheetName = sheetNameMap[Self.normalizedSheetName("Categories")] {
                try importNamedEntitiesSheet(
                    at: url,
                    sheetName: categoriesSheetName,
                    entityLabel: "Categories",
                    createEntity: { name in
                        _ = findOrCreateCategory(named: name)
                    }
                )
            }

            guard let productsSheetName = sheetNameMap[Self.normalizedSheetName("Products")] else {
                throw FullDatabaseImportError.missingProductsSheet
            }

            let productsRows: [[String]]
            do {
                productsRows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: productsSheetName)
            } catch {
                throw FullDatabaseImportError.invalidWorkbook
            }

            let (_, normalizedHeader, dataRows) = ExcelAnalyzer.analyzeSheetRows(productsRows)
            let existingProducts = try context.fetch(FetchDescriptor<Product>())
            let analysis = try analyzeImport(
                header: normalizedHeader,
                dataRows: dataRows,
                existingProducts: existingProducts
            )

            pendingFullImportContext = parsePendingPriceHistoryContext(
                at: url,
                sheetNameMap: sheetNameMap
            )
            importAnalysisResult = analysis
        } catch let error as LocalizedError {
            importError = error.errorDescription ?? error.localizedDescription
        } catch {
            importError = "Errore durante l'import Excel: \(error.localizedDescription)"
        }
    }

    private func analyzeImport(
        header: [String],
        dataRows: [[String]],
        existingProducts: [Product]
    ) throws -> ProductImportAnalysisResult {
        guard header.contains("barcode") else {
            throw ExcelLoadError.invalidFormat("Impossibile trovare la colonna 'barcode' nel file.")
        }

        // Mappa prodotti esistenti per barcode
        let existingByBarcode: [String: Product] = Dictionary(
            uniqueKeysWithValues: existingProducts.map { ($0.barcode, $0) }
        )

        struct PendingRow {
            var lastRow: [String: String]
            var rowNumbers: [Int]
            var quantitySum: Double
        }

        var errors: [ProductImportRowError] = []
        var pendingByBarcode: [String: PendingRow] = [:]

        // 1) Normalizza righe e raggruppa per barcode
        for (index, row) in dataRows.enumerated() {
            let rowNumber = index + 1 // 1-based

            var map: [String: String] = [:]
            for (colIndex, key) in header.enumerated() {
                let raw = colIndex < row.count ? row[colIndex] : ""
                map[key] = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let barcode = (map["barcode"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if barcode.isEmpty {
                errors.append(
                    ProductImportRowError(
                        rowNumber: rowNumber,
                        reason: "Manca il barcode.",
                        rowContent: map
                    )
                )
                continue
            }

            // quantity / stockQuantity (supporta entrambi i nomi)
            let quantity = Self.parseDouble(from: map["stockQuantity"] ?? "")
                ?? Self.parseDouble(from: map["quantity"] ?? "")
                ?? 0

            if var pending = pendingByBarcode[barcode] {
                pending.lastRow = map
                pending.rowNumbers.append(rowNumber)
                pending.quantitySum += quantity
                pendingByBarcode[barcode] = pending
            } else {
                pendingByBarcode[barcode] = PendingRow(
                    lastRow: map,
                    rowNumbers: [rowNumber],
                    quantitySum: quantity
                )
            }
        }

        // 2) Converte PendingRow → ProductDraft / ProductUpdateDraft
        var newProducts: [ProductDraft] = []
        var updates: [ProductUpdateDraft] = []
        var warnings: [ProductDuplicateWarning] = []

        func trimmedOrNil(_ text: String?) -> String? {
            guard let value = text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty else { return nil }
            return value
        }

        func doublesEqual(_ lhs: Double?, _ rhs: Double?, epsilon: Double = 0.0001) -> Bool {
            switch (lhs, rhs) {
            case (nil, nil):
                return true
            case let (l?, r?):
                return abs(l - r) < epsilon
            default:
                return false
            }
        }

        for (barcode, pending) in pendingByBarcode.sorted(by: { $0.key < $1.key }) {
            var row = pending.lastRow
            if pending.quantitySum > 0 {
                row["stockQuantity"] = String(pending.quantitySum)
            }

            let draft = ProductDraft(
                barcode: barcode,
                itemNumber: trimmedOrNil(row["itemNumber"]),
                productName: trimmedOrNil(row["productName"]),
                secondProductName: trimmedOrNil(row["secondProductName"]),
                purchasePrice: Self.parseDouble(from: row["purchasePrice"] ?? ""),
                retailPrice: Self.parseDouble(from: row["retailPrice"] ?? ""),
                stockQuantity: {
                    if let text = row["stockQuantity"] ?? row["quantity"],
                       let value = Self.parseDouble(from: text) {
                        return value
                    } else {
                        return nil
                    }
                }(),
                supplierName: trimmedOrNil(row["supplier"]),
                categoryName: trimmedOrNil(row["category"])
            )

            if let existing = existingByBarcode[barcode] {
                let oldDraft = ProductDraft(
                    barcode: existing.barcode,
                    itemNumber: existing.itemNumber,
                    productName: existing.productName,
                    secondProductName: existing.secondProductName,
                    purchasePrice: existing.purchasePrice,
                    retailPrice: existing.retailPrice,
                    stockQuantity: existing.stockQuantity,
                    supplierName: existing.supplier?.name,
                    categoryName: existing.category?.name
                )

                let changedFields = ProductUpdateDraft.ChangedField.allCases.filter { field in
                    switch field {
                    case .itemNumber:
                        return (oldDraft.itemNumber ?? "") != (draft.itemNumber ?? "")
                    case .productName:
                        return (oldDraft.productName ?? "") != (draft.productName ?? "")
                    case .secondProductName:
                        return (oldDraft.secondProductName ?? "") != (draft.secondProductName ?? "")
                    case .purchasePrice:
                        return !doublesEqual(oldDraft.purchasePrice, draft.purchasePrice)
                    case .retailPrice:
                        return !doublesEqual(oldDraft.retailPrice, draft.retailPrice)
                    case .stockQuantity:
                        return !doublesEqual(oldDraft.stockQuantity, draft.stockQuantity)
                    case .supplierName:
                        return (oldDraft.supplierName ?? "") != (draft.supplierName ?? "")
                    case .categoryName:
                        return (oldDraft.categoryName ?? "") != (draft.categoryName ?? "")
                    }
                }

                if !changedFields.isEmpty {
                    updates.append(
                        ProductUpdateDraft(
                            barcode: barcode,
                            old: oldDraft,
                            new: draft,
                            changedFields: changedFields
                        )
                    )
                }
            } else {
                newProducts.append(draft)
            }

            if pending.rowNumbers.count > 1 {
                warnings.append(
                    ProductDuplicateWarning(
                        barcode: barcode,
                        rowNumbers: pending.rowNumbers
                    )
                )
            }
        }

        return ProductImportAnalysisResult(
            newProducts: newProducts,
            updatedProducts: updates,
            errors: errors,
            warnings: warnings
        )
    }

    @MainActor
    private func applyConfirmedImportAnalysis(_ analysis: ProductImportAnalysisResult) async throws {
        guard !importProgress.isRunning else {
            throw NSError(
                domain: "ImportExcelApply",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "E' gia' in corso un'importazione. Attendere il completamento prima di avviarne un'altra."
                ]
            )
        }

        let pendingContext = pendingFullImportContext
        let recordAutomaticPriceHistory = !(pendingContext?.suppressAutomaticProductPriceHistory ?? false)
        let payload = Self.makeImportApplyPayload(
            analysis: analysis,
            recordPriceHistory: recordAutomaticPriceHistory,
            pendingPriceHistoryEntries: pendingContext?.priceHistoryEntries ?? []
        )
        let modelContainer = context.container
        let progressState = importProgress

        importProgress.startPreparation()
        pendingFullImportContext = nil

        Task {
            do {
                try await Self.applyImportAnalysisInBackground(
                    payload,
                    modelContainer: modelContainer,
                    onProgress: { snapshot in
                        await progressState.apply(snapshot)
                    }
                )
                progressState.finishSuccess(message: "Import completato con successo.")
            } catch {
                progressState.finishError(
                    message: "Errore durante l'applicazione dell'import: \(error.localizedDescription)"
                )
            }
        }
    }

    @MainActor
    private static func makeImportApplyPayload(
        analysis: ProductImportAnalysisResult,
        recordPriceHistory: Bool,
        pendingPriceHistoryEntries: [PendingPriceHistoryImportEntry]
    ) -> ImportApplyPayload {
        ImportApplyPayload(
            newProducts: analysis.newProducts.map(ImportProductDraftSnapshot.init),
            updatedProducts: analysis.updatedProducts.map(ImportProductUpdateSnapshot.init),
            pendingPriceHistoryEntries: pendingPriceHistoryEntries.map { entry in
                ImportPendingPriceHistoryEntrySnapshot(
                    barcode: entry.barcode,
                    type: entry.type,
                    price: entry.price,
                    effectiveAt: entry.effectiveAt,
                    source: entry.source
                )
            },
            recordPriceHistory: recordPriceHistory
        )
    }

    private static func applyImportAnalysisInBackground(
        _ payload: ImportApplyPayload,
        modelContainer: ModelContainer,
        onProgress: @escaping @Sendable (DatabaseImportProgressSnapshot) async -> Void
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            let context = ModelContext(modelContainer)
            try await Self.applyImportAnalysis(
                payload,
                in: context,
                onProgress: onProgress
            )
            try await Self.applyPendingPriceHistoryImport(
                payload.pendingPriceHistoryEntries,
                in: context,
                onProgress: onProgress
            )
        }.value
    }

    private static func applyImportAnalysis(
        _ payload: ImportApplyPayload,
        in context: ModelContext,
        onProgress: @escaping @Sendable (DatabaseImportProgressSnapshot) async -> Void
    ) async throws {
            let existingProducts = try context.fetch(FetchDescriptor<Product>())
            var productsByBarcode = Dictionary(
                uniqueKeysWithValues: existingProducts.map { ($0.barcode, $0) }
            )

            let existingSuppliers = try context.fetch(FetchDescriptor<Supplier>())
            var suppliersByName = Dictionary(
                uniqueKeysWithValues: existingSuppliers.map { ($0.name, $0) }
            )

            let existingCategories = try context.fetch(FetchDescriptor<ProductCategory>())
            var categoriesByName = Dictionary(
                uniqueKeysWithValues: existingCategories.map { ($0.name, $0) }
            )

            func resolveSupplier(named rawName: String?) -> Supplier? {
                guard let rawName else { return nil }
                let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }

                if let existing = suppliersByName[trimmed] {
                    return existing
                }

                let supplier = Supplier(name: trimmed)
                context.insert(supplier)
                suppliersByName[trimmed] = supplier
                return supplier
            }

            func resolveCategory(named rawName: String?) -> ProductCategory? {
                guard let rawName else { return nil }
                let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }

                if let existing = categoriesByName[trimmed] {
                    return existing
                }

                let category = ProductCategory(name: trimmed)
                context.insert(category)
                categoriesByName[trimmed] = category
                return category
            }

            var processedCount = 0
            let totalCount = payload.productsTotalCount
            await Self.reportImportProgress(
                stagePrefix: "Applicazione prodotti",
                processedCount: 0,
                totalCount: totalCount,
                onProgress: onProgress,
                force: true
            )

            // Nuovi prodotti
            for draft in payload.newProducts {
                let product = Product(
                    barcode: draft.barcode,
                    itemNumber: draft.itemNumber,
                    productName: draft.productName,
                    secondProductName: draft.secondProductName,
                    purchasePrice: draft.purchasePrice,
                    retailPrice: draft.retailPrice,
                    stockQuantity: draft.stockQuantity,
                    supplier: resolveSupplier(named: draft.supplierName),
                    category: resolveCategory(named: draft.categoryName)
                )
                context.insert(product)
                productsByBarcode[draft.barcode] = product

                if payload.recordPriceHistory {
                    Self.createPriceHistoryForImport(
                        product: product,
                        oldPurchase: nil,
                        newPurchase: draft.purchasePrice,
                        oldRetail: nil,
                        newRetail: draft.retailPrice,
                        in: context
                    )
                }

                processedCount += 1
                await Self.reportImportProgress(
                    stagePrefix: "Applicazione prodotti",
                    processedCount: processedCount,
                    totalCount: totalCount,
                    onProgress: onProgress
                )
                try await Self.saveImportProgressIfNeeded(after: processedCount, in: context)
            }

            // Aggiornamenti
            for update in payload.updatedProducts {
                guard let product = productsByBarcode[update.barcode] else {
                    continue
                }

                let newDraft = update.newDraft
                let oldPurchase = product.purchasePrice
                let oldRetail = product.retailPrice

                if update.changedFields.contains(.itemNumber) {
                    product.itemNumber = newDraft.itemNumber
                }
                if update.changedFields.contains(.productName) {
                    product.productName = newDraft.productName
                }
                if update.changedFields.contains(.secondProductName) {
                    product.secondProductName = newDraft.secondProductName
                }
                if update.changedFields.contains(.purchasePrice) {
                    product.purchasePrice = newDraft.purchasePrice
                }
                if update.changedFields.contains(.retailPrice) {
                    product.retailPrice = newDraft.retailPrice
                }
                if update.changedFields.contains(.stockQuantity) {
                    product.stockQuantity = newDraft.stockQuantity
                }
                if update.changedFields.contains(.supplierName) {
                    product.supplier = resolveSupplier(named: newDraft.supplierName)
                }
                if update.changedFields.contains(.categoryName) {
                    product.category = resolveCategory(named: newDraft.categoryName)
                }

                if payload.recordPriceHistory {
                    Self.createPriceHistoryForImport(
                        product: product,
                        oldPurchase: oldPurchase,
                        newPurchase: newDraft.purchasePrice,
                        oldRetail: oldRetail,
                        newRetail: newDraft.retailPrice,
                        in: context
                    )
                }

                processedCount += 1
                await Self.reportImportProgress(
                    stagePrefix: "Applicazione prodotti",
                    processedCount: processedCount,
                    totalCount: totalCount,
                    onProgress: onProgress
                )
                try await Self.saveImportProgressIfNeeded(after: processedCount, in: context)
            }

            try context.save()
            await Self.reportImportProgress(
                stagePrefix: "Applicazione prodotti",
                processedCount: processedCount,
                totalCount: totalCount,
                onProgress: onProgress,
                force: true
            )
            await Task.yield()
    }

    private func importNamedEntitiesSheet(
        at url: URL,
        sheetName: String,
        entityLabel: String,
        createEntity: (String) -> Void
    ) throws {
        let rows: [[String]]
        do {
            rows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: sheetName)
        } catch {
            debugPrint("Full import: impossibile leggere il foglio \(sheetName), skip.")
            return
        }

        guard !rows.isEmpty else {
            debugPrint("Full import: foglio \(sheetName) vuoto, skip.")
            return
        }

        let header = rows[0].map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        guard let nameIndex = header.firstIndex(of: "name") else {
            debugPrint("Full import: foglio \(sheetName) senza colonna name, skip.")
            return
        }

        guard rows.count > 1 else {
            debugPrint("Full import: foglio \(sheetName) con soli header, skip.")
            return
        }

        for row in rows.dropFirst() {
            let name = Self.cellValue(in: row, at: nameIndex)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            createEntity(name)
        }

        do {
            try context.save()
        } catch {
            throw NSError(
                domain: "ImportExcelFull",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "Errore durante il salvataggio del foglio \(entityLabel): \(error.localizedDescription)"
                ]
            )
        }
    }

    private func parsePendingPriceHistoryContext(
        at url: URL,
        sheetNameMap: [String: String]
    ) -> PendingFullImportContext? {
        guard let sheetName = sheetNameMap[Self.normalizedSheetName("PriceHistory")] else {
            return nil
        }

        let rows: [[String]]
        do {
            rows = try ExcelAnalyzer.readSheetByName(at: url, sheetName: sheetName)
        } catch {
            debugPrint("Full import: impossibile leggere il foglio \(sheetName), skip.")
            return nil
        }

        guard !rows.isEmpty else {
            debugPrint("Full import: foglio \(sheetName) vuoto, skip.")
            return nil
        }

        let header = rows[0].map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        guard let barcodeIndex = Self.indexForPriceHistoryColumn("productBarcode", in: header),
              let timestampIndex = Self.indexForPriceHistoryColumn("timestamp", in: header),
              let typeIndex = Self.indexForPriceHistoryColumn("type", in: header),
              let newPriceIndex = Self.indexForPriceHistoryColumn("newPrice", in: header) else {
            debugPrint("Full import: foglio \(sheetName) con header non valido, skip.")
            return nil
        }

        let sourceIndex = Self.indexForPriceHistoryColumn("source", in: header)
        var entries: [PendingPriceHistoryImportEntry] = []

        if rows.count > 1 {
            for row in rows.dropFirst() {
                let barcode = Self.cellValue(in: row, at: barcodeIndex)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !barcode.isEmpty else { continue }

                let typeRaw = Self.cellValue(in: row, at: typeIndex)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                guard let type = Self.parsePriceType(typeRaw) else { continue }

                let priceRaw = Self.cellValue(in: row, at: newPriceIndex)
                guard let price = Self.parseDouble(from: priceRaw) else { continue }

                let timestampRaw = Self.cellValue(in: row, at: timestampIndex)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let effectiveAt = Self.parseFullDatabaseTimestamp(timestampRaw) ?? Date()

                let sourceRaw = sourceIndex.map { Self.cellValue(in: row, at: $0) } ?? ""
                let source = sourceRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedSource = source.isEmpty ? "IMPORT_DB_FULL" : source

                entries.append(
                    PendingPriceHistoryImportEntry(
                        barcode: barcode,
                        type: type,
                        price: price,
                        effectiveAt: effectiveAt,
                        source: normalizedSource
                    )
                )
            }
        }

        return PendingFullImportContext(
            priceHistoryEntries: entries,
            suppressAutomaticProductPriceHistory: true
        )
    }

    private static func applyPendingPriceHistoryImport(
        _ entries: [ImportPendingPriceHistoryEntrySnapshot],
        in context: ModelContext,
        onProgress: @escaping @Sendable (DatabaseImportProgressSnapshot) async -> Void
    ) async throws {
        guard !entries.isEmpty else { return }

        let existingProducts = try context.fetch(FetchDescriptor<Product>())
        let productsByBarcode = Dictionary(
            uniqueKeysWithValues: existingProducts.map { ($0.barcode, $0) }
        )

        let now = Date()
        var processedCount = 0
        let totalCount = entries.count
        await Self.reportImportProgress(
            stagePrefix: "Applicazione storico prezzi",
            processedCount: 0,
            totalCount: totalCount,
            onProgress: onProgress,
            force: true
        )
        for entry in entries {
            guard let product = productsByBarcode[entry.barcode] else { continue }

            let history = ProductPrice(
                type: entry.type,
                price: entry.price,
                effectiveAt: entry.effectiveAt,
                source: entry.source,
                note: nil,
                createdAt: now,
                product: product
            )
            context.insert(history)

            processedCount += 1
            await Self.reportImportProgress(
                stagePrefix: "Applicazione storico prezzi",
                processedCount: processedCount,
                totalCount: totalCount,
                onProgress: onProgress
            )
            try await Self.saveImportProgressIfNeeded(after: processedCount, in: context)
        }

        try context.save()
        await Self.reportImportProgress(
            stagePrefix: "Applicazione storico prezzi",
            processedCount: processedCount,
            totalCount: totalCount,
            onProgress: onProgress,
            force: true
        )
        await Task.yield()
    }

    private static func reportImportProgress(
        stagePrefix: String,
        processedCount: Int,
        totalCount: Int,
        onProgress: @escaping @Sendable (DatabaseImportProgressSnapshot) async -> Void,
        force: Bool = false
    ) async {
        guard totalCount > 0 else { return }
        guard force ||
                processedCount == totalCount ||
                processedCount.isMultiple(of: Self.importProgressBatchSize) else {
            return
        }

        await onProgress(
            DatabaseImportProgressSnapshot(
                stageText: "\(stagePrefix) \(processedCount) / \(totalCount)",
                processedCount: processedCount,
                totalCount: totalCount
            )
        )
    }

    private static func saveImportProgressIfNeeded(
        after processedCount: Int,
        in context: ModelContext
    ) async throws {
        guard processedCount > 0,
              processedCount.isMultiple(of: Self.importSaveBatchSize) else {
            return
        }

        try context.save()
        await Task.yield()
    }

    private static func createPriceHistoryForImport(
        product: Product,
        oldPurchase: Double?,
        newPurchase: Double?,
        oldRetail: Double?,
        newRetail: Double?,
        in context: ModelContext
    ) {
        let now = Date()

        if let newPurchase, newPurchase != oldPurchase {
            let history = ProductPrice(
                type: .purchase,
                price: newPurchase,
                effectiveAt: now,
                source: "IMPORT_EXCEL",
                note: nil,
                createdAt: now,
                product: product
            )
            context.insert(history)
        }

        if let newRetail, newRetail != oldRetail {
            let history = ProductPrice(
                type: .retail,
                price: newRetail,
                effectiveAt: now,
                source: "IMPORT_EXCEL",
                note: nil,
                createdAt: now,
                product: product
            )
            context.insert(history)
        }
    }

    // MARK: - Import CSV

    private func importProducts(from url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                throw NSError(domain: "Import", code: 1, userInfo: [NSLocalizedDescriptionKey: "Permessi file negati"])
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            guard let content = String(data: data, encoding: .utf8) else {
                throw NSError(domain: "Import", code: 2, userInfo: [NSLocalizedDescriptionKey: "File non in UTF-8"])
            }

            try parseProductsCSV(content)
            try context.save()
        } catch {
            importError = "Errore durante l'import: \(error.localizedDescription)"
        }
    }

    private func parseProductsCSV(_ content: String) throws {
        let lines = content.split(whereSeparator: \.isNewline)
        guard !lines.isEmpty else { return }

        // salta l'header
        let dataLines = lines.dropFirst()

        for rawLine in dataLines {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }

            let cols = splitCSVRow(line)
            if cols.isEmpty { continue }

            func col(_ index: Int) -> String {
                guard index < cols.count else { return "" }
                return cols[index]
            }

            let barcode = col(0).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !barcode.isEmpty else { continue }

            let itemNumber = col(1).trimmingCharacters(in: .whitespacesAndNewlines)
            let productName = col(2).trimmingCharacters(in: .whitespacesAndNewlines)
            let secondName = col(3).trimmingCharacters(in: .whitespacesAndNewlines)
            let purchase = Self.parseDouble(from: col(4))
            let retail = Self.parseDouble(from: col(5))
            let stock = Self.parseDouble(from: col(6))
            let supplierName = col(7).trimmingCharacters(in: .whitespacesAndNewlines)
            let categoryName = col(8).trimmingCharacters(in: .whitespacesAndNewlines)

            let supplier = supplierName.isEmpty ? nil : findOrCreateSupplier(named: supplierName)
            let category = categoryName.isEmpty ? nil : findOrCreateCategory(named: categoryName)

            // Cerca prodotto esistente per barcode
            let descriptor = FetchDescriptor<Product>(predicate: #Predicate { $0.barcode == barcode })
            let existing = try context.fetch(descriptor).first

            let product: Product
            if let existing {
                product = existing
            } else {
                product = Product(
                    barcode: barcode,
                    itemNumber: itemNumber.isEmpty ? nil : itemNumber,
                    productName: productName.isEmpty ? nil : productName,
                    secondProductName: secondName.isEmpty ? nil : secondName,
                    purchasePrice: purchase,
                    retailPrice: retail,
                    stockQuantity: stock,
                    supplier: supplier,
                    category: category
                )
                context.insert(product)
            }

            product.itemNumber = itemNumber.isEmpty ? nil : itemNumber
            product.productName = productName.isEmpty ? nil : productName
            product.secondProductName = secondName.isEmpty ? nil : secondName
            product.purchasePrice = purchase
            product.retailPrice = retail
            product.stockQuantity = stock
            product.supplier = supplier
            product.category = category
        }
    }

    private func splitCSVRow(_ line: String) -> [String] {
        // parsing molto semplice: separatore ';', gestisce i campi tra doppi apici
        var result: [String] = []
        var current = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
                current.append(char)
            } else if char == ";" && !insideQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        if !current.isEmpty {
            result.append(current.trimmingCharacters(in: .whitespaces))
        }

        // rimuovi doppi apici esterni e rimpiazza "" con "
        return result.map { field in
            var f = field
            if f.hasPrefix("\""), f.hasSuffix("\""), f.count >= 2 {
                f.removeFirst()
                f.removeLast()
            }
            f = f.replacingOccurrences(of: "\"\"", with: "\"")
            return f
        }
    }

    private func findOrCreateSupplier(named name: String) -> Supplier {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return Supplier(name: "") }

        let descriptor = FetchDescriptor<Supplier>(predicate: #Predicate { $0.name == trimmed })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        } else {
            let supplier = Supplier(name: trimmed)
            context.insert(supplier)
            return supplier
        }
    }

    private func findOrCreateCategory(named name: String) -> ProductCategory {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ProductCategory(name: "") }

        let descriptor = FetchDescriptor<ProductCategory>(predicate: #Predicate { $0.name == trimmed })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        } else {
            let category = ProductCategory(name: trimmed)
            context.insert(category)
            return category
        }
    }

    // MARK: - Formattazione / parsing numeri

    private func formatMoney(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = .current
        return formatter.string(from: value as NSNumber) ?? String(value)
    }

    private func formatQuantity(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        } else {
            return String(value)
        }
    }

    private static let fullDatabaseTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let priceHistoryHeaderAliases: [String: [String]] = [
        "productBarcode": ["productbarcode", "barcode", "product_barcode"],
        "timestamp": ["timestamp", "date", "data"],
        "type": ["type", "tipo", "pricetype"],
        "oldPrice": ["oldprice", "old_price", "prevprice", "priceold"],
        "newPrice": ["newprice", "new_price", "price"],
        "source": ["source", "sorgente"]
    ]

    private static func normalizedSheetName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizedHeaderValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func cellValue(in row: [String], at index: Int) -> String {
        guard index >= 0, index < row.count else { return "" }
        return row[index]
    }

    private static func indexForPriceHistoryColumn(
        _ logicalName: String,
        in header: [String]
    ) -> Int? {
        guard let aliases = priceHistoryHeaderAliases[logicalName] else {
            return nil
        }

        return header.firstIndex { aliases.contains($0) }
    }

    private static func parsePriceType(_ value: String) -> PriceType? {
        PriceType(rawValue: value)
    }

    private static func parseFullDatabaseTimestamp(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        return fullDatabaseTimestampFormatter.date(from: value)
    }

    private static func parseDouble(from text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }
}
