import SwiftUI
import xlsxwriter

// MARK: - Modelli per ImportAnalysis (Excel → Database)

/// Snapshot "puro" di un prodotto letto da Excel (non e` ancora SwiftData)
struct ProductDraft: Identifiable, Hashable, Sendable {
    var id: String { barcode }

    var barcode: String
    var itemNumber: String?
    var productName: String?
    var secondProductName: String?
    var purchasePrice: Double?
    var retailPrice: Double?
    var stockQuantity: Double?
    var supplierName: String?
    var categoryName: String?
}

/// Descrive un aggiornamento di un prodotto esistente
struct ProductUpdateDraft: Identifiable, Sendable {
    enum ChangedField: String, CaseIterable, Sendable {
        case itemNumber
        case productName
        case secondProductName
        case purchasePrice
        case retailPrice
        case stockQuantity
        case supplierName
        case categoryName
    }

    let id = UUID()
    let barcode: String
    let old: ProductDraft
    var new: ProductDraft
    var changedFields: [ChangedField]

    static func computeChangedFields(old: ProductDraft, new: ProductDraft) -> [ChangedField] {
        ChangedField.allCases.filter { field in
            switch field {
            case .itemNumber:
                return (old.itemNumber ?? "") != (new.itemNumber ?? "")
            case .productName:
                return (old.productName ?? "") != (new.productName ?? "")
            case .secondProductName:
                return (old.secondProductName ?? "") != (new.secondProductName ?? "")
            case .purchasePrice:
                return !doublesEqual(old.purchasePrice, new.purchasePrice)
            case .retailPrice:
                return !doublesEqual(old.retailPrice, new.retailPrice)
            case .stockQuantity:
                return !doublesEqual(old.stockQuantity, new.stockQuantity)
            case .supplierName:
                return (old.supplierName ?? "") != (new.supplierName ?? "")
            case .categoryName:
                return (old.categoryName ?? "") != (new.categoryName ?? "")
            }
        }
    }

    private static func doublesEqual(_ lhs: Double?, _ rhs: Double?, epsilon: Double = 0.0001) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (l?, r?):
            return abs(l - r) < epsilon
        default:
            return false
        }
    }
}

/// Errore di import su una singola riga
struct ProductImportRowError: Identifiable, Sendable {
    let id = UUID()
    let rowNumber: Int
    let reason: String
    let rowContent: [String: String]
}

/// Warning per barcode duplicati nello stesso file
struct ProductDuplicateWarning: Identifiable, Sendable {
    var id: String { barcode }
    let barcode: String
    let rowNumbers: [Int]
}

/// Risultato complessivo dell'analisi
struct ProductImportAnalysisResult: Identifiable, Sendable {
    let id = UUID()
    var newProducts: [ProductDraft]
    var updatedProducts: [ProductUpdateDraft]
    var errors: [ProductImportRowError]
    var warnings: [ProductDuplicateWarning]

    var hasChanges: Bool {
        !newProducts.isEmpty || !updatedProducts.isEmpty
    }
}

// MARK: - Vista di riepilogo e conferma Import

struct ImportAnalysisView: View {
    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    private struct EditingItem: Identifiable {
        let id = UUID()
        let productID: String
        let isUpdate: Bool
    }

    @State private var analysis: ProductImportAnalysisResult
    @State private var shareItem: ShareItem?
    @State private var exportError: String?
    @State private var applyError: String?
    @State private var editingDraftItem: EditingItem?
    @State private var isApplying = false
    let allowsApplyWithoutChanges: Bool
    let onApply: (ProductImportAnalysisResult) async throws -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        analysis: ProductImportAnalysisResult,
        allowsApplyWithoutChanges: Bool = false,
        onApply: @escaping (ProductImportAnalysisResult) async throws -> Void
    ) {
        _analysis = State(initialValue: analysis)
        self.allowsApplyWithoutChanges = allowsApplyWithoutChanges
        self.onApply = onApply
    }

    var body: some View {
        ZStack {
            List {
                summarySection

                if !analysis.warnings.isEmpty {
                    warningsSection
                }

                if !analysis.newProducts.isEmpty {
                    newProductsSection
                }

                if !analysis.updatedProducts.isEmpty {
                    updatedProductsSection
                }

                if !analysis.errors.isEmpty {
                    errorsSection
                }
            }
            .disabled(isApplying)

            if isApplying {
                processingOverlay
            }
        }
        .interactiveDismissDisabled(isApplying)
        .navigationTitle(L("import.analysis.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("common.cancel")) {
                    dismiss()
                }
                .disabled(isApplying)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L("import.analysis.apply")) {
                    guard !isApplying else { return }
                    isApplying = true

                    Task {
                        defer { isApplying = false }

                        do {
                            try await onApply(analysis)
                            dismiss()
                        } catch {
                            applyError = error.localizedDescription
                        }
                    }
                }
                .disabled(isApplying || (!analysis.hasChanges && !allowsApplyWithoutChanges))
            }
        }
        .sheet(item: $shareItem) { shareItem in
            ShareSheet(items: [shareItem.url])
        }
        .sheet(item: $editingDraftItem) { item in
            editDraftSheet(for: item)
        }
        .alert(
            L("import.analysis.error.export_title"),
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )
        ) {
            Button(L("common.ok"), role: .cancel) {
                exportError = nil
            }
        } message: {
            Text(exportError ?? "")
        }
        .alert(
            L("import.analysis.error.apply_title"),
            isPresented: Binding(
                get: { applyError != nil },
                set: { if !$0 { applyError = nil } }
            )
        ) {
            Button(L("common.ok"), role: .cancel) {
                applyError = nil
            }
        } message: {
            Text(applyError ?? "")
        }
    }

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)

                Text(L("import.analysis.processing.title"))
                    .font(.headline)

                Text(L("import.analysis.processing.body"))
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(radius: 16, x: 0, y: 8)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Sezioni

    private var summarySection: some View {
        Section(L("import.analysis.summary")) {
            row(label: L("import.analysis.summary.new_products"), systemImage: "plus.circle", value: analysis.newProducts.count)
            row(label: L("import.analysis.summary.updates"), systemImage: "arrow.triangle.2.circlepath", value: analysis.updatedProducts.count)
            row(label: L("import.analysis.summary.warnings"), systemImage: "exclamationmark.triangle", value: analysis.warnings.count)
            row(label: L("import.analysis.summary.errors"), systemImage: "xmark.octagon", value: analysis.errors.count)
        }
    }

    private var warningsSection: some View {
        Section(L("import.analysis.duplicate_barcodes")) {
            ForEach(analysis.warnings) { warning in
                VStack(alignment: .leading, spacing: 4) {
                    Text(warning.barcode)
                        .font(.headline)

                    Text(L("common.rows", warning.rowNumbers.map(String.init).joined(separator: ", ")))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var newProductsSection: some View {
        Section(L("import.analysis.new_products_count", analysis.newProducts.count)) {
            ForEach(analysis.newProducts) { draft in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(draft.productName ?? L("product.no_name"))
                            .font(.headline)

                        Text(L("import.analysis.barcode", draft.barcode))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            if let purchase = draft.purchasePrice {
                                Text(L("import.analysis.purchase", formatPrice(purchase)))
                            }
                            if let retail = draft.retailPrice {
                                Text(L("import.analysis.retail", formatPrice(retail)))
                            }
                            if let qty = draft.stockQuantity {
                                Text(L("import.analysis.stock", formatQuantity(qty)))
                            }
                        }
                        .font(.caption)

                        HStack(spacing: 8) {
                            if let supplier = draft.supplierName, !supplier.isEmpty {
                                Text(supplier)
                            }
                            if let category = draft.categoryName, !category.isEmpty {
                                if draft.supplierName != nil {
                                    Text("·")
                                }
                                Text(category)
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    Button {
                        editingDraftItem = EditingItem(productID: draft.barcode, isUpdate: false)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var updatedProductsSection: some View {
        Section(L("import.analysis.updated_products_count", analysis.updatedProducts.count)) {
            ForEach(analysis.updatedProducts) { update in
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        let name = update.new.productName
                            ?? update.old.productName
                            ?? L("product.no_name")

                        Text(name)
                            .font(.headline)

                        Text(L("import.analysis.barcode", update.barcode))
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(update.changedFields, id: \.self) { field in
                            HStack(alignment: .top, spacing: 8) {
                                Text(label(for: field))
                                    .font(.caption)
                                    .frame(width: 80, alignment: .leading)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(value(for: field, in: update.old))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    Image(systemName: "arrow.down")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)

                                    Text(value(for: field, in: update.new))
                                        .font(.caption2)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 0)

                    Button {
                        editingDraftItem = EditingItem(
                            productID: update.id.uuidString,
                            isUpdate: true
                        )
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var errorsSection: some View {
        Section {
            ForEach(analysis.errors) { err in
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("common.row_number", err.rowNumber))
                        .font(.headline)

                    Text(err.reason)
                        .font(.caption)

                    if let name = err.rowContent["productName"], !name.isEmpty {
                        Text(name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            HStack {
                Text(L("import.analysis.errors_ignored"))
                Spacer()
                Button(L("import.analysis.export_errors")) {
                    exportErrors()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
            }
        }
    }

    // MARK: - Editing

    @ViewBuilder
    private func editDraftSheet(for item: EditingItem) -> some View {
        if item.isUpdate {
            if let index = analysis.updatedProducts.firstIndex(where: { $0.id.uuidString == item.productID }) {
                EditProductDraftView(
                    draft: analysis.updatedProducts[index].new,
                    barcodeEditable: false,
                    forbiddenBarcodes: [],
                    onSave: { editedDraft in
                        let newChangedFields = ProductUpdateDraft.computeChangedFields(
                            old: analysis.updatedProducts[index].old,
                            new: editedDraft
                        )
                        if newChangedFields.isEmpty {
                            analysis.updatedProducts.remove(at: index)
                        } else {
                            analysis.updatedProducts[index].new = editedDraft
                            analysis.updatedProducts[index].changedFields = newChangedFields
                        }
                        editingDraftItem = nil
                    },
                    onCancel: {
                        editingDraftItem = nil
                    }
                )
            } else {
                Color.clear
                    .onAppear {
                        editingDraftItem = nil
                    }
            }
        } else if let index = analysis.newProducts.firstIndex(where: { $0.barcode == item.productID }) {
            EditProductDraftView(
                draft: analysis.newProducts[index],
                barcodeEditable: true,
                forbiddenBarcodes: Set(
                    analysis.newProducts
                        .map(\.barcode)
                        .filter { $0 != item.productID }
                ),
                onSave: { editedDraft in
                    analysis.newProducts[index] = editedDraft
                    editingDraftItem = nil
                },
                onCancel: {
                    editingDraftItem = nil
                }
            )
        } else {
            Color.clear
                .onAppear {
                    editingDraftItem = nil
                }
        }
    }

    private func exportErrors() {
        Task { @MainActor in
            do {
                let url = try Self.exportErrorsToXLSX(analysis.errors)
                shareItem = ShareItem(url: url)
            } catch {
                exportError = L("import.analysis.export_impossible", error.localizedDescription)
            }
        }
    }

    private static func exportErrorsToXLSX(_ errors: [ProductImportRowError]) throws -> URL {
        let allKeys = Array(Set(errors.flatMap { $0.rowContent.keys })).sorted()
        let headers = allKeys + [L("import.analysis.error_column")]

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("exports", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())

        let url = dir.appendingPathComponent("errori_import_\(timestamp).xlsx")
        let workbook = xlsxwriter.Workbook(name: url.path)
        defer { workbook.close() }

        let sheet = workbook.addWorksheet(name: L("import.analysis.error_sheet_name"))

        for (column, header) in headers.enumerated() {
            sheet.write(.string(header), [0, column])
        }

        for (row, error) in errors.enumerated() {
            for (column, key) in allKeys.enumerated() {
                sheet.write(.string(error.rowContent[key] ?? ""), [row + 1, column])
            }
            sheet.write(.string(error.reason), [row + 1, allKeys.count])
        }

        return url
    }

    // MARK: - Helper UI

    private func row(label: String, systemImage: String, value: Int) -> some View {
        HStack {
            Label(label, systemImage: systemImage)
            Spacer()
            Text("\(value)")
        }
    }

    private func label(for field: ProductUpdateDraft.ChangedField) -> String {
        switch field {
        case .itemNumber: return L("import.analysis.field.item_number")
        case .productName: return L("import.analysis.field.product_name")
        case .secondProductName: return L("import.analysis.field.second_name")
        case .purchasePrice: return L("import.analysis.field.purchase")
        case .retailPrice: return L("import.analysis.field.retail")
        case .stockQuantity: return L("import.analysis.field.stock")
        case .supplierName: return L("import.analysis.field.supplier")
        case .categoryName: return L("import.analysis.field.category")
        }
    }

    private func value(for field: ProductUpdateDraft.ChangedField, in draft: ProductDraft) -> String {
        switch field {
        case .itemNumber:
            return draft.itemNumber ?? "—"
        case .productName:
            return draft.productName ?? "—"
        case .secondProductName:
            return draft.secondProductName ?? "—"
        case .purchasePrice:
            return formatPrice(draft.purchasePrice)
        case .retailPrice:
            return formatPrice(draft.retailPrice)
        case .stockQuantity:
            return formatQuantity(draft.stockQuantity)
        case .supplierName:
            return draft.supplierName ?? "—"
        case .categoryName:
            return draft.categoryName ?? "—"
        }
    }

    private func formatPrice(_ value: Double?) -> String {
        guard let value else { return "—" }
        let formatter = NumberFormatter()
        formatter.locale = appLocale()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 3
        formatter.usesGroupingSeparator = false
        return formatter.string(from: value as NSNumber) ?? String(value)
    }

    private func formatQuantity(_ value: Double?) -> String {
        guard let value else { return "—" }
        if value.rounded() == value {
            return String(Int(value))
        } else {
            let formatter = NumberFormatter()
            formatter.locale = appLocale()
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 3
            formatter.usesGroupingSeparator = false
            return formatter.string(from: value as NSNumber) ?? String(value)
        }
    }
}

private struct EditProductDraftView: View {
    @State private var barcode: String
    @State private var itemNumber: String
    @State private var productName: String
    @State private var secondProductName: String
    @State private var purchasePrice: String
    @State private var retailPrice: String
    @State private var stockQuantity: String
    @State private var supplierName: String
    @State private var categoryName: String

    let barcodeEditable: Bool
    let forbiddenBarcodes: Set<String>
    let onSave: (ProductDraft) -> Void
    let onCancel: () -> Void

    init(
        draft: ProductDraft,
        barcodeEditable: Bool,
        forbiddenBarcodes: Set<String>,
        onSave: @escaping (ProductDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _barcode = State(initialValue: draft.barcode)
        _itemNumber = State(initialValue: draft.itemNumber ?? "")
        _productName = State(initialValue: draft.productName ?? "")
        _secondProductName = State(initialValue: draft.secondProductName ?? "")
        _purchasePrice = State(initialValue: draft.purchasePrice.map(Self.format(number:)) ?? "")
        _retailPrice = State(initialValue: draft.retailPrice.map(Self.format(number:)) ?? "")
        _stockQuantity = State(initialValue: draft.stockQuantity.map(Self.format(number:)) ?? "")
        _supplierName = State(initialValue: draft.supplierName ?? "")
        _categoryName = State(initialValue: draft.categoryName ?? "")
        self.barcodeEditable = barcodeEditable
        self.forbiddenBarcodes = forbiddenBarcodes
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var trimmedBarcode: String {
        barcode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedProductName: String {
        productName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var saveDisabled: Bool {
        trimmedBarcode.isEmpty
            || trimmedProductName.isEmpty
            || forbiddenBarcodes.contains(trimmedBarcode)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L("product.section.main")) {
                    TextField(L("product.field.barcode"), text: $barcode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .disabled(!barcodeEditable)

                    TextField(L("product.field.item_number"), text: $itemNumber)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField(L("product.field.name"), text: $productName)
                    TextField(L("product.field.second_name"), text: $secondProductName)
                }

                Section(L("product.section.warehouse")) {
                    TextField(L("product.field.stock_quantity"), text: $stockQuantity)
                        .keyboardType(.decimalPad)
                }

                Section(L("product.section.prices")) {
                    TextField(L("product.field.purchase_price"), text: $purchasePrice)
                        .keyboardType(.decimalPad)

                    TextField(L("product.field.retail_price"), text: $retailPrice)
                        .keyboardType(.decimalPad)
                }

                Section(L("product.section.profile")) {
                    TextField(L("product.field.supplier_name"), text: $supplierName)
                    TextField(L("product.field.category_name"), text: $categoryName)
                }
            }
            .navigationTitle(L("product.title.edit"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.save")) {
                        save()
                    }
                    .disabled(saveDisabled)
                }
            }
        }
    }

    private func save() {
        let draft = ProductDraft(
            barcode: trimmedBarcode,
            itemNumber: Self.trimmedOrNil(itemNumber),
            productName: Self.trimmedOrNil(productName),
            secondProductName: Self.trimmedOrNil(secondProductName),
            purchasePrice: Self.parseDouble(from: purchasePrice),
            retailPrice: Self.parseDouble(from: retailPrice),
            stockQuantity: Self.parseDouble(from: stockQuantity),
            supplierName: Self.trimmedOrNil(supplierName),
            categoryName: Self.trimmedOrNil(categoryName)
        )
        onSave(draft)
    }

    private nonisolated static func format(number: Double) -> String {
        let intPart = floor(number)
        if number == intPart {
            return String(Int(intPart))
        } else {
            return String(number)
        }
    }

    private nonisolated static func trimmedOrNil(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private nonisolated static func parseDouble(from text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
    }
}
