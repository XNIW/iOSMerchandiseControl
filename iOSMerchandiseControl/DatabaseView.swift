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

    // Export / import
    @State private var exportURL: URL?
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var importError: String?

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
            HStack {
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
            // bottone per aprire Cronologia
            ToolbarItem(placement: .navigationBarLeading) {
                NavigationLink {
                    HistoryView()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
            }

            // import / export + nuovo prodotto
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        showingImportPicker = true
                    } label: {
                        Image(systemName: "tray.and.arrow.down")
                    }

                    Button {
                        exportProducts()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Button {
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
                EditProductView()
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
        // Sheet per condividere il CSV export
        .sheet(isPresented: $showingExportSheet) {
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
        // Import CSV
        .fileImporter(
            isPresented: $showingImportPicker,
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
        .alert(
            "Errore import",
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
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

    private func makeProductsCSV() throws -> URL {
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

        var lines: [String] = []
        lines.append(headers.joined(separator: ";"))

        let numberFormatter = NumberFormatter()
        numberFormatter.locale = Locale(identifier: "en_US_POSIX")
        numberFormatter.minimumFractionDigits = 0
        numberFormatter.maximumFractionDigits = 4

        for product in products {
            let row: [String] = [
                product.barcode,
                product.itemNumber ?? "",
                product.productName ?? "",
                product.secondProductName ?? "",
                product.purchasePrice.flatMap { numberFormatter.string(from: $0 as NSNumber) } ?? "",
                product.retailPrice.flatMap { numberFormatter.string(from: $0 as NSNumber) } ?? "",
                product.stockQuantity.flatMap { numberFormatter.string(from: $0 as NSNumber) } ?? "",
                product.supplier?.name ?? "",
                product.category?.name ?? ""
            ]
            lines.append(row.map(escapeCSVField).joined(separator: ";"))
        }

        let csvString = lines.joined(separator: "\n")
        let data = Data(csvString.utf8)

        let tmpDir = FileManager.default.temporaryDirectory
        let filename = "products_\(Int(Date().timeIntervalSince1970)).csv"
        let url = tmpDir.appendingPathComponent(filename)

        try data.write(to: url, options: .atomic)
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
