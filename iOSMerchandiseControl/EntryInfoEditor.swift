import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct EntryInfoEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var supabaseAuthViewModel: SupabaseAuthViewModel

    @Bindable var entry: HistoryEntry

    // Elenchi dal DB (come in PreGenerate)
    @Query(sort: \Supplier.name) private var suppliers: [Supplier]
    @Query(sort: \ProductCategory.name) private var categories: [ProductCategory]

    @State private var draftTitle: String = ""
    @State private var draftSupplier: String = ""
    @State private var draftCategory: String = ""
    @State private var initialTitle: String = ""
    @State private var initialSupplier: String = ""
    @State private var initialCategory: String = ""
    @State private var validationMessage: String?

    @State private var showAllSuppliersSheet = false
    @State private var showAllCategoriesSheet = false

    @FocusState private var focusedField: Field?
    private enum Field { case title, supplier, category }

    private var supplierSuggestions: [String] {
        Self.rankedSuggestions(all: suppliers.map(\.name), query: draftSupplier, limit: 6)
    }
    private var categorySuggestions: [String] {
        Self.rankedSuggestions(all: categories.map(\.name), query: draftCategory, limit: 6)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section {
                    HStack {
                        Text(L("common.file_id"))
                        Spacer()
                        Text(entry.id)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        #if canImport(UIKit)
                        Button {
                            UIPasteboard.general.string = entry.id
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: "doc.on.doc")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(L("entry.info.copy_id"))
                        #endif
                    }
                } header: {
                    Text(L("common.identity"))
                } footer: {
                    Text(L("entry.info.identity_footer"))
                }

                Section {
                    TextField(L("entry.info.display_name_optional"), text: $draftTitle)
                        .focused($focusedField, equals: .title)

                    TextField(L("common.supplier"), text: $draftSupplier)
                        .focused($focusedField, equals: .supplier)

                    InlineSuggestionsBox(
                        query: draftSupplier,
                        suggestions: supplierSuggestions,
                        onPick: { picked in
                            draftSupplier = picked
                            focusedField = nil
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                    Button(L("entry.info.show_all_suppliers")) { showAllSuppliersSheet = true }
                        .foregroundStyle(.secondary)

                    TextField(L("common.category"), text: $draftCategory)
                        .focused($focusedField, equals: .category)

                    InlineSuggestionsBox(
                        query: draftCategory,
                        suggestions: categorySuggestions,
                        onPick: { picked in
                            draftCategory = picked
                            focusedField = nil
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))

                    Button(L("entry.info.show_all_categories")) { showAllCategoriesSheet = true }
                        .foregroundStyle(.secondary)
                } header: {
                    Text(L("entry.info.details"))
                }
            }
            .navigationTitle(L("entry.info.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L("common.save")) { saveAndDismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField == .supplier, !draftSupplier.isEmpty {
                        Button(L("common.clear")) { draftSupplier = "" }
                    } else if focusedField == .category, !draftCategory.isEmpty {
                        Button(L("common.clear")) { draftCategory = "" }
                    } else if focusedField == .title, !draftTitle.isEmpty {
                        Button(L("common.clear")) { draftTitle = "" }
                    }
                    Spacer()
                    Button(L("common.done")) { focusedField = nil }
                }
            }
            .onAppear {
                // Importante: NON riempire il titolo con entry.id.
                // Lascia vuoto se non c’è title: così è chiarissimo che l’ID è separato.
                draftTitle = entry.title
                draftSupplier = entry.supplier
                draftCategory = entry.category
                initialTitle = entry.title
                initialSupplier = entry.supplier
                initialCategory = entry.category
            }
            .sheet(isPresented: $showAllSuppliersSheet) {
                NamePickerSheet(
                    title: L("entry.info.suppliers_title"),
                    allItems: suppliers.map(\.name),
                    selection: $draftSupplier
                )
            }
            .sheet(isPresented: $showAllCategoriesSheet) {
                NamePickerSheet(
                    title: L("entry.info.categories_title"),
                    allItems: categories.map(\.name),
                    selection: $draftCategory
                )
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func saveAndDismiss() {
        let newTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let newSupplier: String
        let newCategory: String
        do {
            newSupplier = try canonicalLookupText(
                draftSupplier,
                field: .supplierName
            )
            newCategory = try canonicalLookupText(
                draftCategory,
                field: .categoryName
            )
        } catch let error as CatalogTextValidationError {
            validationMessage = L(error.reason.localizationKey)
            return
        } catch {
            validationMessage = L("catalog.text.error.invalid_input")
            return
        }
        let pendingOwnerUserID = supabaseAuthViewModel.isSignedIn
            ? supabaseAuthViewModel.sessionInfo?.userID
            : nil
        let entryID = entry.persistentModelID
        let userChangedFields = historyChangedFields(
            oldTitle: initialTitle,
            oldSupplier: initialSupplier,
            oldCategory: initialCategory,
            newTitle: newTitle,
            newSupplier: newSupplier,
            newCategory: newCategory
        )
        do {
            try Task126OwnerStoreGate.withLocalMutationFence(
                modelContainer: modelContext.container,
                ownerUserID: pendingOwnerUserID
            ) { freshContext in
                let freshEntry = try Task126OwnerStoreGate.requireLocalModel(
                    HistoryEntry.self,
                    id: entryID,
                    in: freshContext
                )
                let remoteChangedFields = historyChangedFields(
                    oldTitle: initialTitle,
                    oldSupplier: initialSupplier,
                    oldCategory: initialCategory,
                    newTitle: freshEntry.title,
                    newSupplier: freshEntry.supplier,
                    newCategory: freshEntry.category
                )
                guard Task126ConflictResolver.resolve(
                    localChangedFields: userChangedFields,
                    remoteChangedFields: remoteChangedFields,
                    remoteDeleted: freshEntry.remoteDeletedAt != nil
                ) == .autoMerge else {
                    throw Task126OwnerStoreGateError.localRemoteConflictRequiresReview
                }

                if userChangedFields.contains("title") { freshEntry.title = newTitle }
                if userChangedFields.contains("supplier") { freshEntry.supplier = newSupplier }
                if userChangedFields.contains("category") { freshEntry.category = newCategory }

                let accumulator = LocalPendingChangeAccumulator(
                    context: freshContext,
                    ownerUserID: pendingOwnerUserID
                )

                // Se l’utente inserisce un nuovo fornitore/categoria qui,
                // lo “promuoviamo” anche nelle tabelle Supplier/ProductCategory (per i suggerimenti futuri).
                // La creazione e il relativo pending devono far parte dello stesso commit della sessione.
                if userChangedFields.contains("supplier"), !newSupplier.isEmpty {
                    let resolved = try findOrCreateSupplier(named: newSupplier, context: freshContext)
                    if resolved.created {
                        try accumulator.recordSupplierChange(
                            supplier: resolved.entity,
                            operation: .create,
                            origin: .manualCatalogSave
                        )
                    }
                }
                if userChangedFields.contains("category"), !newCategory.isEmpty {
                    let resolved = try findOrCreateCategory(named: newCategory, context: freshContext)
                    if resolved.created {
                        try accumulator.recordCategoryChange(
                            category: resolved.entity,
                            operation: .create,
                            origin: .manualCatalogSave
                        )
                    }
                }

                if !userChangedFields.isEmpty {
                    try recordHistorySessionPending(
                        entry: freshEntry,
                        accumulator: accumulator,
                        changedFields: userChangedFields
                    )
                }

                try freshContext.save()
            }
            _ = try Task126OwnerStoreGate.requireLocalModel(
                HistoryEntry.self,
                id: entryID,
                in: modelContext
            )
            dismiss()
        } catch {
            validationMessage = L("catalog.text.error.save_failed")
        }
    }

    private func canonicalLookupText(
        _ value: String,
        field: CatalogTextField
    ) throws -> String {
        let outcome = CatalogTextPolicy.display(
            value,
            required: false,
            maximumUTF16Length: field.maximumUTF16Length
        )
        switch outcome {
        case let .unchanged(canonical), let .normalized(canonical, _):
            return canonical
        case let .rejected(reason):
            throw CatalogTextValidationError(field: field, reason: reason)
        }
    }

    private func historyChangedFields(
        oldTitle: String,
        oldSupplier: String,
        oldCategory: String,
        newTitle: String,
        newSupplier: String,
        newCategory: String
    ) -> [String] {
        var fields: [String] = []
        if oldTitle != newTitle { fields.append("title") }
        if oldSupplier != newSupplier { fields.append("supplier") }
        if oldCategory != newCategory { fields.append("category") }
        return fields
    }

    private func recordHistorySessionPending(
        entry: HistoryEntry,
        accumulator: LocalPendingChangeAccumulator,
        changedFields: [String]
    ) throws {
        entry.markHistorySessionLocalMutation()
        _ = try accumulator.recordHistorySessionChange(
            entry: entry,
            operation: .upsert,
            changedFields: changedFields
        )
    }

    // MARK: - DB helpers (replica la logica di ExcelSessionViewModel)
    private func findOrCreateSupplier(
        named name: String,
        context: ModelContext
    ) throws -> (entity: Supplier, created: Bool) {
        let key = ProductImportCore.normalizedRelationKey(name)
        let matches = try context.fetch(FetchDescriptor<Supplier>()).filter {
            ProductImportCore.normalizedRelationKey($0.name) == key
        }
        guard !matches.contains(where: { $0.remoteDeletedAt != nil }) else {
            throw Task126OwnerStoreGateError.localRemoteConflictRequiresReview
        }
        if let existing = matches.first {
            return (existing, false)
        }
        let supplier = Supplier(name: name)
        context.insert(supplier)
        return (supplier, true)
    }

    private func findOrCreateCategory(
        named name: String,
        context: ModelContext
    ) throws -> (entity: ProductCategory, created: Bool) {
        let key = ProductImportCore.normalizedRelationKey(name)
        let matches = try context.fetch(FetchDescriptor<ProductCategory>()).filter {
            ProductImportCore.normalizedRelationKey($0.name) == key
        }
        guard !matches.contains(where: { $0.remoteDeletedAt != nil }) else {
            throw Task126OwnerStoreGateError.localRemoteConflictRequiresReview
        }
        if let existing = matches.first {
            return (existing, false)
        }
        let category = ProductCategory(name: name)
        context.insert(category)
        return (category, true)
    }

    // MARK: - “autocomplete” (stile PreGenerate)
    private static func rankedSuggestions(all: [String], query: String, limit: Int = 6) -> [String] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }

        let nq = q.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        var prefix: [String] = []
        var contains: [String] = []
        prefix.reserveCapacity(limit)
        contains.reserveCapacity(limit)

        for name in all {
            let nn = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            if nn == nq { continue }
            if nn.hasPrefix(nq) {
                prefix.append(name)
            } else if nn.contains(nq) {
                contains.append(name)
            }
            if prefix.count >= limit { break }
        }

        if prefix.count < limit {
            for name in contains {
                prefix.append(name)
                if prefix.count >= limit { break }
            }
        }
        return prefix
    }

    private static func highlighted(_ text: String, query: String) -> AttributedString {
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
                                Text(EntryInfoEditor.highlighted(s, query: query))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)

                        if s != suggestions.last {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private struct NamePickerSheet: View {
        @Environment(\.dismiss) private var dismiss

        let title: String
        let allItems: [String]
        @Binding var selection: String

        @State private var searchText: String = ""
        @State private var debouncedSearchText: String = ""
        private let debounceMs: UInt64 = 220

        private var filtered: [String] {
            let q = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { return allItems }
            return allItems.filter { $0.localizedCaseInsensitiveContains(q) }
        }

        var body: some View {
            NavigationStack {
                List {
                    ForEach(filtered, id: \.self) { item in
                        Button {
                            selection = item
                            dismiss()
                        } label: {
                            HStack {
                                Text(item)
                                Spacer()
                                if item == selection {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
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
                    let q = searchText
                    try? await Task.sleep(nanoseconds: debounceMs * 1_000_000)
                    guard !Task.isCancelled else { return }
                    debouncedSearchText = q
                }
            }
        }
    }
}
