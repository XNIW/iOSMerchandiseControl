import SwiftUI
import Combine
import xlsxwriter

nonisolated func normalizedImportNamedEntityName(_ rawName: String?) -> String? {
    ProductImportCore.normalizedDisplayName(rawName)
}

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
    var oldPurchasePrice: Double? = nil
    var oldRetailPrice: Double? = nil
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

    nonisolated static func computeChangedFields(old: ProductDraft, new: ProductDraft) -> [ChangedField] {
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
                return ProductImportCore.normalizedRelationKey(old.supplierName)
                    != ProductImportCore.normalizedRelationKey(new.supplierName)
            case .categoryName:
                return ProductImportCore.normalizedRelationKey(old.categoryName)
                    != ProductImportCore.normalizedRelationKey(new.categoryName)
            }
        }
    }

    nonisolated private static func doublesEqual(_ lhs: Double?, _ rhs: Double?, epsilon: Double = 0.0001) -> Bool {
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
    let reasonKeys: [String]
    let rowContent: [String: String]

    var reason: String {
        reasonKeys
            .map { L($0) }
            .joined(separator: " ")
    }

    nonisolated init(rowNumber: Int, reasonKey: String, rowContent: [String: String]) {
        self.rowNumber = rowNumber
        self.reasonKeys = [reasonKey]
        self.rowContent = rowContent
    }

    nonisolated init(rowNumber: Int, reasonKeys: [String], rowContent: [String: String]) {
        self.rowNumber = rowNumber
        self.reasonKeys = reasonKeys
        self.rowContent = rowContent
    }
}

/// Warning per barcode duplicati nello stesso file
struct ProductDuplicateWarning: Identifiable, Sendable {
    var id: String { barcode }
    let barcode: String
    let rowNumbers: [Int]

    var totalOccurrences: Int {
        rowNumbers.count
    }
}

/// Risultato complessivo dell'analisi
struct ProductImportAnalysisResult: Identifiable, Sendable {
    let id = UUID()
    var newProducts: [ProductDraft]
    var updatedProducts: [ProductUpdateDraft]
    var errors: [ProductImportRowError]
    var warnings: [ProductDuplicateWarning]
    var totalInputRows: Int = 0

    var hasChanges: Bool {
        !newProducts.isEmpty || !updatedProducts.isEmpty
    }
}

struct NonProductDeltaSummary: Sendable {
    let suppliersToAdd: Int
    let categoriesToAdd: Int
    let priceHistoryToInsert: Int
    let priceHistoryAlreadyPresent: Int
    let priceHistoryUnresolved: Int
}

@MainActor
final class ImportAnalysisSession: ObservableObject, Identifiable {
    let id: UUID

    @Published var newProducts: [ProductDraft]
    @Published var updatedProducts: [ProductUpdateDraft]
    @Published var errors: [ProductImportRowError]
    @Published var warnings: [ProductDuplicateWarning]
    @Published var nonProductSummary: NonProductDeltaSummary?

    private let pendingSupplierNames: [String]
    private let pendingCategoryNames: [String]
    private let existingSupplierKeys: Set<String>
    private let existingCategoryKeys: Set<String>
    let totalInputRows: Int
    private let priceHistoryToInsert: Int
    private let priceHistoryAlreadyPresent: Int
    private let priceHistoryUnresolved: Int

    init(
        analysis: ProductImportAnalysisResult,
        nonProductSummary: NonProductDeltaSummary? = nil,
        pendingSupplierNames: [String] = [],
        pendingCategoryNames: [String] = [],
        existingSupplierNames: Set<String> = [],
        existingCategoryNames: Set<String> = []
    ) {
        id = analysis.id
        newProducts = analysis.newProducts
        updatedProducts = analysis.updatedProducts
        errors = analysis.errors
        warnings = analysis.warnings
        totalInputRows = analysis.totalInputRows
        self.nonProductSummary = nonProductSummary
        self.pendingSupplierNames = pendingSupplierNames
        self.pendingCategoryNames = pendingCategoryNames
        existingSupplierKeys = Set(existingSupplierNames.compactMap(ProductImportCore.normalizedRelationKey))
        existingCategoryKeys = Set(existingCategoryNames.compactMap(ProductImportCore.normalizedRelationKey))
        priceHistoryToInsert = nonProductSummary?.priceHistoryToInsert ?? 0
        priceHistoryAlreadyPresent = nonProductSummary?.priceHistoryAlreadyPresent ?? 0
        priceHistoryUnresolved = nonProductSummary?.priceHistoryUnresolved ?? 0
        refreshNonProductSummary()
    }

    var hasChanges: Bool {
        !newProducts.isEmpty || !updatedProducts.isEmpty
    }

    func refreshNonProductSummary() {
        guard nonProductSummary != nil else { return }

        let suppliersToAdd = relationKeys(from: pendingSupplierNames).subtracting(existingSupplierKeys)
            .union(referencedRelationKeys(from: newProducts, keyPath: \.supplierName).subtracting(existingSupplierKeys))
            .union(referencedRelationKeys(from: updatedProducts, changedField: .supplierName).subtracting(existingSupplierKeys))
        let categoriesToAdd = relationKeys(from: pendingCategoryNames).subtracting(existingCategoryKeys)
            .union(referencedRelationKeys(from: newProducts, keyPath: \.categoryName).subtracting(existingCategoryKeys))
            .union(referencedRelationKeys(from: updatedProducts, changedField: .categoryName).subtracting(existingCategoryKeys))

        nonProductSummary = NonProductDeltaSummary(
            suppliersToAdd: suppliersToAdd.count,
            categoriesToAdd: categoriesToAdd.count,
            priceHistoryToInsert: priceHistoryToInsert,
            priceHistoryAlreadyPresent: priceHistoryAlreadyPresent,
            priceHistoryUnresolved: priceHistoryUnresolved
        )
    }

    private func relationKeys(from names: [String]) -> Set<String> {
        Set(names.compactMap(ProductImportCore.normalizedRelationKey))
    }

    private func referencedRelationKeys(
        from drafts: [ProductDraft],
        keyPath: KeyPath<ProductDraft, String?>
    ) -> Set<String> {
        Set(drafts.compactMap { ProductImportCore.normalizedRelationKey($0[keyPath: keyPath]) })
    }

    private func referencedRelationKeys(
        from updates: [ProductUpdateDraft],
        changedField: ProductUpdateDraft.ChangedField
    ) -> Set<String> {
        Set(
            updates.compactMap { update in
                guard update.changedFields.contains(changedField) else { return nil }
                switch changedField {
                case .supplierName:
                    return ProductImportCore.normalizedRelationKey(update.new.supplierName)
                case .categoryName:
                    return ProductImportCore.normalizedRelationKey(update.new.categoryName)
                default:
                    return nil
                }
            }
        )
    }
}

// MARK: - Vista di riepilogo e conferma Import

struct ImportAnalysisView: View {
    private static let previewItemLimit = 500
    private static let previewErrorLimit = 200

    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    private struct EditingItem: Identifiable {
        let id = UUID()
        let productID: String
        let isUpdate: Bool
    }

    private enum AnalysisFilter: String, CaseIterable, Identifiable {
        case all
        case valid
        case warnings
        case errors
        case newProducts
        case updatedProducts

        var id: String { rawValue }
    }

    @ObservedObject private var session: ImportAnalysisSession
    @State private var shareItem: ShareItem?
    @State private var exportError: String?
    @State private var applyError: String?
    @State private var editingDraftItem: EditingItem?
    @State private var isApplying = false
    @State private var selectedFilter: AnalysisFilter = .all
    @AppStorage("appLanguage") private var appLanguage: String = "system"
    let hasWorkToApply: () -> Bool
    let onApply: () async throws -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        session: ImportAnalysisSession,
        hasWorkToApply: @escaping () -> Bool,
        onApply: @escaping () async throws -> Void
    ) {
        _session = ObservedObject(wrappedValue: session)
        self.hasWorkToApply = hasWorkToApply
        self.onApply = onApply
    }

    private var visibleWarnings: [ProductDuplicateWarning] {
        Array(session.warnings.prefix(Self.previewItemLimit))
    }

    private var visibleNewProducts: [ProductDraft] {
        Array(session.newProducts.prefix(Self.previewItemLimit))
    }

    private var visibleUpdatedProducts: [ProductUpdateDraft] {
        Array(session.updatedProducts.prefix(Self.previewItemLimit))
    }

    private var visibleErrors: [ProductImportRowError] {
        Array(session.errors.prefix(Self.previewErrorLimit))
    }

    private var validProductCount: Int {
        session.newProducts.count + session.updatedProducts.count
    }

    private var canApply: Bool {
        !isApplying && hasWorkToApply()
    }

    private var showsWarnings: Bool {
        !session.warnings.isEmpty && (selectedFilter == .all || selectedFilter == .warnings)
    }

    private var showsNewProducts: Bool {
        !session.newProducts.isEmpty
            && (selectedFilter == .all || selectedFilter == .valid || selectedFilter == .newProducts)
    }

    private var showsUpdatedProducts: Bool {
        !session.updatedProducts.isEmpty
            && (selectedFilter == .all || selectedFilter == .valid || selectedFilter == .updatedProducts)
    }

    private var showsErrors: Bool {
        !session.errors.isEmpty && (selectedFilter == .all || selectedFilter == .errors)
    }

    var body: some View {
        let resolvedLanguageCode = Bundle.resolvedLanguageCode(for: appLanguage)

        List {
            summarySection
            filterSection

            if showsWarnings {
                warningsSection
            }

            if showsNewProducts {
                newProductsSection
            }

            if showsUpdatedProducts {
                updatedProductsSection
            }

            if showsErrors {
                errorsSection
            }
        }
        .id("import-analysis-list-\(resolvedLanguageCode)")
        .disabled(isApplying)
        .overlay {
            if isApplying {
                GeometryReader { geo in
                    let cardW = min(max(geo.size.width - 64, 280), 440)
                    ZStack {
                        Color.black.opacity(0.16)
                            .ignoresSafeArea()

                        applyingNotice
                            .frame(width: cardW)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .allowsHitTesting(true)
            }
        }
        .interactiveDismissDisabled(isApplying)
        .navigationTitle(L("import.analysis.title"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            applyBar
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("common.cancel")) {
                    dismiss()
                }
                .disabled(isApplying)
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

    private var applyingNotice: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.regular)

            Text(L("import.analysis.processing.title"))
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)

            Text(L("import.analysis.processing.body"))
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private var applyBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("import.analysis.apply.ready_count", validProductCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if !session.errors.isEmpty {
                    Text(L("import.analysis.apply.errors_excluded", session.errors.count))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            Button {
                applyConfirmedImport()
            } label: {
                Label(L("import.analysis.apply"), systemImage: "checkmark.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canApply)
            .accessibilityHint(L("import.analysis.apply.accessibility_hint"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - Sezioni

    private var summarySection: some View {
        Section(L("import.analysis.summary")) {
            row(label: L("import.analysis.summary.total_rows"), systemImage: "tablecells", value: session.totalInputRows)
            row(label: L("import.analysis.summary.valid_rows"), systemImage: "checkmark.circle", value: validProductCount)
            row(label: L("import.analysis.summary.new_products"), systemImage: "plus.circle", value: session.newProducts.count)
            row(label: L("import.analysis.summary.updates"), systemImage: "arrow.triangle.2.circlepath", value: session.updatedProducts.count)
            row(label: L("import.analysis.summary.warnings"), systemImage: "exclamationmark.triangle", value: session.warnings.count)
            row(label: L("import.analysis.summary.errors"), systemImage: "xmark.octagon", value: session.errors.count)

            if let nonProductSummary = session.nonProductSummary {
                if nonProductSummary.suppliersToAdd > 0 {
                    row(
                        label: L("import.analysis.summary.suppliers_to_add"),
                        systemImage: "building.2",
                        value: nonProductSummary.suppliersToAdd
                    )
                }

                if nonProductSummary.categoriesToAdd > 0 {
                    row(
                        label: L("import.analysis.summary.categories_to_add"),
                        systemImage: "tag",
                        value: nonProductSummary.categoriesToAdd
                    )
                }

                row(
                    label: L("import.analysis.summary.price_history_to_insert"),
                    systemImage: "clock.badge.plus",
                    value: nonProductSummary.priceHistoryToInsert
                )
                row(
                    label: L("import.analysis.summary.price_history_already_present"),
                    systemImage: "checkmark.circle",
                    value: nonProductSummary.priceHistoryAlreadyPresent
                )
                row(
                    label: L("import.analysis.summary.price_history_unresolved"),
                    systemImage: "questionmark.circle",
                    value: nonProductSummary.priceHistoryUnresolved
                )
            }

            if shouldShowNoWorkNotice {
                noWorkNotice
            }
        }
    }

    private var filterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AnalysisFilter.allCases) { filter in
                        Button {
                            selectedFilter = filter
                        } label: {
                            Label(filterTitle(filter), systemImage: filterIcon(filter))
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(selectedFilter == filter ? .accentColor : .secondary)
                        .accessibilityAddTraits(selectedFilter == filter ? .isSelected : AccessibilityTraits())
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 0))
        }
    }

    private var shouldShowNoWorkNotice: Bool {
        guard !isApplying, !hasWorkToApply(), session.errors.isEmpty else {
            return false
        }

        if let nonProductSummary = session.nonProductSummary,
           nonProductSummary.priceHistoryUnresolved > 0 {
            return false
        }

        return true
    }

    private var noWorkNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal")
                .foregroundStyle(.green)
                .imageScale(.large)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(L("import.analysis.no_work.title"))
                    .font(.subheadline.weight(.semibold))
                Text(L("import.analysis.no_work.body"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 6)
    }

    private var warningsSection: some View {
        Section {
            if visibleWarnings.count < session.warnings.count {
                previewBanner(
                    text: L(
                        "import.analysis.preview_notice",
                        Self.previewItemLimit,
                        session.warnings.count
                    )
                )
            }

            ForEach(visibleWarnings) { warning in
                VStack(alignment: .leading, spacing: 4) {
                    Text(warning.barcode)
                        .font(.headline)

                    Text(L("common.rows", warning.rowNumbers.map(String.init).joined(separator: ", ")))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(L("import.analysis.warning.duplicate_policy", warning.totalOccurrences))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        } header: {
            HStack {
                Text(L("import.analysis.duplicate_barcodes"))
                Spacer()
                Button(L("import.analysis.export_warnings")) {
                    exportWarnings()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
            }
        }
    }

    private var newProductsSection: some View {
        Section(L("import.analysis.new_products_count", session.newProducts.count)) {
            if visibleNewProducts.count < session.newProducts.count {
                previewBanner(
                    text: L(
                        "import.analysis.preview_notice",
                        Self.previewItemLimit,
                        session.newProducts.count
                    )
                )
            }

            ForEach(visibleNewProducts) { draft in
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
        Section(L("import.analysis.updated_products_count", session.updatedProducts.count)) {
            if visibleUpdatedProducts.count < session.updatedProducts.count {
                previewBanner(
                    text: L(
                        "import.analysis.preview_notice",
                        Self.previewItemLimit,
                        session.updatedProducts.count
                    )
                )
            }

            ForEach(visibleUpdatedProducts) { update in
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
            if visibleErrors.count < session.errors.count {
                previewBanner(
                    text: L(
                        "import.analysis.preview_notice_errors",
                        Self.previewErrorLimit,
                        session.errors.count
                    )
                )
            }

            ForEach(visibleErrors) { err in
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

    private func previewBanner(text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
    }

    // MARK: - Editing

    @ViewBuilder
    private func editDraftSheet(for item: EditingItem) -> some View {
        if item.isUpdate {
            if let index = session.updatedProducts.firstIndex(where: { $0.id.uuidString == item.productID }) {
                EditProductDraftView(
                    draft: session.updatedProducts[index].new,
                    barcodeEditable: false,
                    forbiddenBarcodes: [],
                    onSave: { editedDraft in
                        let newChangedFields = ProductUpdateDraft.computeChangedFields(
                            old: session.updatedProducts[index].old,
                            new: editedDraft
                        )
                        if newChangedFields.isEmpty {
                            session.updatedProducts.remove(at: index)
                        } else {
                            session.updatedProducts[index].new = editedDraft
                            session.updatedProducts[index].changedFields = newChangedFields
                        }
                        session.refreshNonProductSummary()
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
        } else if let index = session.newProducts.firstIndex(where: { $0.barcode == item.productID }) {
            EditProductDraftView(
                draft: session.newProducts[index],
                barcodeEditable: true,
                forbiddenBarcodes: Set(
                    session.newProducts
                        .map(\.barcode)
                        .filter { $0 != item.productID }
                ),
                onSave: { editedDraft in
                    session.newProducts[index] = editedDraft
                    session.refreshNonProductSummary()
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

    private func applyConfirmedImport() {
        guard !isApplying, hasWorkToApply() else { return }
        isApplying = true

        Task {
            defer { isApplying = false }

            do {
                try await onApply()
                dismiss()
            } catch {
                applyError = error.localizedDescription
            }
        }
    }

    private func exportErrors() {
        Task { @MainActor in
            do {
                let url = try Self.exportErrorsToXLSX(session.errors)
                shareItem = ShareItem(url: url)
            } catch {
                exportError = L("import.analysis.export_impossible", error.localizedDescription)
            }
        }
    }

    private func exportWarnings() {
        Task { @MainActor in
            do {
                let url = try Self.exportWarningsToXLSX(session.warnings)
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

    private static func exportWarningsToXLSX(_ warnings: [ProductDuplicateWarning]) throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("exports", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())

        let url = dir.appendingPathComponent("warning_import_\(timestamp).xlsx")
        let workbook = xlsxwriter.Workbook(name: url.path)
        defer { workbook.close() }

        let sheet = workbook.addWorksheet(name: L("import.analysis.warning_sheet_name"))
        sheet.write(.string(L("product.field.barcode")), [0, 0])
        sheet.write(.string(L("import.analysis.warning.occurrences")), [0, 1])
        sheet.write(.string(L("common.rows_header")), [0, 2])

        for (index, warning) in warnings.enumerated() {
            let row = index + 1
            sheet.write(.string(warning.barcode), [row, 0])
            sheet.write(.number(Double(warning.totalOccurrences)), [row, 1])
            sheet.write(.string(warning.rowNumbers.map(String.init).joined(separator: ", ")), [row, 2])
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

    private func filterTitle(_ filter: AnalysisFilter) -> String {
        switch filter {
        case .all:
            return L("import.analysis.filter.all")
        case .valid:
            return L("import.analysis.filter.valid")
        case .warnings:
            return L("import.analysis.filter.warnings")
        case .errors:
            return L("import.analysis.filter.errors")
        case .newProducts:
            return L("import.analysis.filter.new")
        case .updatedProducts:
            return L("import.analysis.filter.updated")
        }
    }

    private func filterIcon(_ filter: AnalysisFilter) -> String {
        switch filter {
        case .all:
            return "line.3.horizontal.decrease.circle"
        case .valid:
            return "checkmark.circle"
        case .warnings:
            return "exclamationmark.triangle"
        case .errors:
            return "xmark.octagon"
        case .newProducts:
            return "plus.circle"
        case .updatedProducts:
            return "arrow.triangle.2.circlepath"
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
        return formatCLPMoney(value)
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

    private let oldPurchasePrice: Double?
    private let oldRetailPrice: Double?
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
        self.oldPurchasePrice = draft.oldPurchasePrice
        self.oldRetailPrice = draft.oldRetailPrice
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
            oldPurchasePrice: oldPurchasePrice,
            oldRetailPrice: oldRetailPrice,
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
        normalizedImportNamedEntityName(text)
    }

    private nonisolated static func parseDouble(from text: String) -> Double? {
        ProductImportCore.parseDouble(from: text)
    }
}
