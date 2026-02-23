import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import xlsxwriter

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

    // Import prodotti (CSV semplice + Excel con analisi)
    @State private var showingImportOptions = false
    @State private var showingCSVImportPicker = false
    @State private var showingExcelImportPicker = false

    @State private var importError: String?
    
    // Risultato analisi import da Excel
    @State private var importAnalysisResult: ProductImportAnalysisResult?
    
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
                        exportProducts()
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
            NavigationStack {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Condividi export prodotti", systemImage: "square.and.arrow.up")
                    }
                    .padding()
                } else {
                    Text("Nessun file da condividere.")
                        .padding()
                }
            }
        }

        // Sheet per l’analisi di import da Excel
        .sheet(item: $importAnalysisResult) { analysis in
            NavigationStack {
                ImportAnalysisView(
                    analysis: analysis,
                    onApply: {
                        applyImportAnalysis(analysis)
                        // chiudiamo il sheet azzerando il binding
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

        // Dialog per scegliere il tipo di import
        .confirmationDialog(
            "Importa prodotti",
            isPresented: $showingImportOptions,
            titleVisibility: .visible
        ) {
            Button("Importa da Excel (analisi)") {
                showingExcelImportPicker = true
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
    
    // MARK: - Export XLSX (writer reale tramite xlsxwriter.swift)

    /// Genera un file XLSX con la stessa struttura del CSV attuale
    private func makeProductsXLSX() throws -> URL {
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

        // Chiudiamo sempre il file alla fine, anche se ci sono errori dopo
        defer {
            workbook.close()
        }

        // Un solo worksheet per ora
        let worksheet = workbook.addWorksheet(name: "Products")

        // Riga 0: header
        for (columnIndex, header) in headers.enumerated() {
            worksheet.write(.string(header), [0, columnIndex])
        }

        // Righe dati: dalla riga 1 in avanti
        for (rowIndex, product) in products.enumerated() {
            let row = rowIndex + 1   // 0 = header, 1..n = dati

            // 0: barcode (obbligatorio)
            worksheet.write(.string(product.barcode), [row, 0])

            // 1: itemNumber
            worksheet.write(.string(product.itemNumber ?? ""), [row, 1])

            // 2: nome prodotto principale
            worksheet.write(.string(product.productName ?? ""), [row, 2])

            // 3: secondo nome
            worksheet.write(.string(product.secondProductName ?? ""), [row, 3])

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
            worksheet.write(.string(product.supplier?.name ?? ""), [row, 7])

            // 8: categoryName
            worksheet.write(.string(product.category?.name ?? ""), [row, 8])
        }

        return url
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

    private func applyImportAnalysis(_ analysis: ProductImportAnalysisResult) {
        do {
            // Nuovi prodotti
            for draft in analysis.newProducts {
                let supplier: Supplier? = draft.supplierName.flatMap { name in
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : findOrCreateSupplier(named: trimmed)
                }

           

                let category: ProductCategory? = draft.categoryName.flatMap { name in
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : findOrCreateCategory(named: trimmed)
                }

                let product = Product(
                    barcode: draft.barcode,
                    itemNumber: draft.itemNumber,
                    productName: draft.productName,
                    secondProductName: draft.secondProductName,
                    purchasePrice: draft.purchasePrice,
                    retailPrice: draft.retailPrice,
                    stockQuantity: draft.stockQuantity,
                    supplier: supplier,
                    category: category
                )
                context.insert(product)

                createPriceHistoryForImport(
                    product: product,
                    oldPurchase: nil,
                    newPurchase: draft.purchasePrice,
                    oldRetail: nil,
                    newRetail: draft.retailPrice
                )
            }

            // Aggiornamenti
            for update in analysis.updatedProducts {
                let targetBarcode = update.barcode

                let descriptor = FetchDescriptor<Product>(
                    predicate: #Predicate<Product> { product in
                        product.barcode == targetBarcode
                    }
                )

                guard let product = try context.fetch(descriptor).first else {
                    continue
                }

                let newDraft = update.new
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
                    if let name = newDraft.supplierName,
                       !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        product.supplier = findOrCreateSupplier(named: name)
                    } else {
                        product.supplier = nil
                    }
                }
                if update.changedFields.contains(.categoryName) {
                    if let name = newDraft.categoryName,
                       !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        product.category = findOrCreateCategory(named: name)
                    } else {
                        product.category = nil
                    }
                }

                createPriceHistoryForImport(
                    product: product,
                    oldPurchase: oldPurchase,
                    newPurchase: newDraft.purchasePrice,
                    oldRetail: oldRetail,
                    newRetail: newDraft.retailPrice
                )
            }

            try context.save()
        } catch {
            importError = "Errore durante l'applicazione dell'import: \(error.localizedDescription)"
        }
    }

    private func createPriceHistoryForImport(
        product: Product,
        oldPurchase: Double?,
        newPurchase: Double?,
        oldRetail: Double?,
        newRetail: Double?
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

    private static func parseDouble(from text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }
}
