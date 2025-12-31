import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct EntryInfoEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var entry: HistoryEntry

    // Elenchi dal DB (come in PreGenerate)
    @Query(sort: \Supplier.name) private var suppliers: [Supplier]
    @Query(sort: \ProductCategory.name) private var categories: [ProductCategory]

    @State private var draftTitle: String = ""
    @State private var draftSupplier: String = ""
    @State private var draftCategory: String = ""

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
                Section {
                    HStack {
                        Text("ID file")
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
                        .accessibilityLabel("Copia ID")
                        #endif
                    }
                } header: {
                    Text("Identità")
                } footer: {
                    Text("L’ID è la chiave univoca dell’inventario. Il nome qui sotto è solo un’etichetta.")
                }

                Section {
                    TextField("Nome visualizzato (opzionale)", text: $draftTitle)
                        .focused($focusedField, equals: .title)

                    TextField("Fornitore", text: $draftSupplier)
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

                    Button("Mostra tutti i fornitori…") { showAllSuppliersSheet = true }
                        .foregroundStyle(.secondary)

                    TextField("Categoria", text: $draftCategory)
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

                    Button("Mostra tutte le categorie…") { showAllCategoriesSheet = true }
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Dettagli")
                }
            }
            .navigationTitle("Dettagli entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { saveAndDismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if focusedField == .supplier, !draftSupplier.isEmpty {
                        Button("Cancella") { draftSupplier = "" }
                    } else if focusedField == .category, !draftCategory.isEmpty {
                        Button("Cancella") { draftCategory = "" }
                    } else if focusedField == .title, !draftTitle.isEmpty {
                        Button("Cancella") { draftTitle = "" }
                    }
                    Spacer()
                    Button("Fine") { focusedField = nil }
                }
            }
            .onAppear {
                // Importante: NON riempire il titolo con entry.id.
                // Lascia vuoto se non c’è title: così è chiarissimo che l’ID è separato.
                draftTitle = entry.title
                draftSupplier = entry.supplier
                draftCategory = entry.category
            }
            .sheet(isPresented: $showAllSuppliersSheet) {
                NamePickerSheet(
                    title: "Fornitori",
                    allItems: suppliers.map(\.name),
                    selection: $draftSupplier
                )
            }
            .sheet(isPresented: $showAllCategoriesSheet) {
                NamePickerSheet(
                    title: "Categorie",
                    allItems: categories.map(\.name),
                    selection: $draftCategory
                )
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func saveAndDismiss() {
        let newTitle = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let newSupplier = draftSupplier.trimmingCharacters(in: .whitespacesAndNewlines)
        let newCategory = draftCategory.trimmingCharacters(in: .whitespacesAndNewlines)

        entry.title = newTitle
        entry.supplier = newSupplier
        entry.category = newCategory

        // Se l’utente inserisce un nuovo fornitore/categoria qui,
        // lo “promuoviamo” anche nelle tabelle Supplier/ProductCategory (per i suggerimenti futuri)
        if !newSupplier.isEmpty { _ = findOrCreateSupplier(named: newSupplier) }
        if !newCategory.isEmpty { _ = findOrCreateCategory(named: newCategory) }

        try? modelContext.save()
        dismiss()
    }

    // MARK: - DB helpers (replica la logica di ExcelSessionViewModel)
    private func findOrCreateSupplier(named name: String) -> Supplier {
        let descriptor = FetchDescriptor<Supplier>(predicate: #Predicate { $0.name == name })
        if let existing = try? modelContext.fetch(descriptor).first { return existing }
        let supplier = Supplier(name: name)
        modelContext.insert(supplier)
        return supplier
    }

    private func findOrCreateCategory(named name: String) -> ProductCategory {
        let descriptor = FetchDescriptor<ProductCategory>(predicate: #Predicate { $0.name == name })
        if let existing = try? modelContext.fetch(descriptor).first { return existing }
        let category = ProductCategory(name: name)
        modelContext.insert(category)
        return category
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
                .searchable(text: $searchText, prompt: "Cerca…")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Chiudi") { dismiss() }
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
