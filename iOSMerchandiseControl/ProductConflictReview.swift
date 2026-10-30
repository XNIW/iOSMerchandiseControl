import SwiftUI

/// Value-only comparison for the currently open editor. Choosing here changes
/// the draft; the guarded Save must still compare against the then-current row.
nonisolated struct ProductEditorConflictReview: Identifiable, Sendable {
    let id: UUID
    let base: ProductDraft
    let desired: ProductDraft
    let current: ProductDraft?
    let remoteDeleted: Bool

    init(base: ProductDraft, desired: ProductDraft, current: ProductDraft?, remoteDeleted: Bool) {
        id = UUID()
        self.base = base
        self.desired = desired
        self.current = current
        self.remoteDeleted = remoteDeleted
    }

    var intendedFields: [String] { ProductDraftReviewFields.changed(from: base, to: desired) }
    var contestedFields: Set<String> {
        guard let current else { return Set(intendedFields) }
        return Set(intendedFields)
            .intersection(ProductDraftReviewFields.changed(from: base, to: current))
            .intersection(ProductDraftReviewFields.changed(from: current, to: desired))
    }
    var displayedFields: [String] {
        let changed = Set(intendedFields)
            .union(current.map { ProductDraftReviewFields.changed(from: base, to: $0) } ?? [])
        return ProductDraftReviewFields.all.filter(changed.contains)
    }
    var canPrepareDraft: Bool { current != nil && !remoteDeleted }

    /// Start with current and overlay only fields the user explicitly selected.
    /// This prevents a disjoint peer change from becoming dirty in the next Save.
    func preparingDraft(selectedFields: Set<String>) -> ProductDraft? {
        guard canPrepareDraft, var result = current,
              selectedFields.isSubset(of: Set(intendedFields)) else { return nil }
        for field in selectedFields {
            ProductDraftReviewFields.copy(field, from: desired, to: &result)
        }
        return result
    }
}

nonisolated enum ProductDraftReviewFields {
    static let all = ["barcode", "itemNumber", "productName", "secondProductName", "purchasePrice",
                      "retailPrice", "stockQuantity", "supplierName", "categoryName"]

    static func changed(from old: ProductDraft, to new: ProductDraft) -> [String] {
        var result = ProductUpdateDraft.computeChangedFields(old: old, new: new).map(\.rawValue)
        if old.barcode != new.barcode { result.insert("barcode", at: 0) }
        return result
    }

    static func copy(_ field: String, from source: ProductDraft, to target: inout ProductDraft) {
        switch field {
        case "barcode": target.barcode = source.barcode
        case "itemNumber": target.itemNumber = source.itemNumber
        case "productName": target.productName = source.productName
        case "secondProductName": target.secondProductName = source.secondProductName
        case "purchasePrice": target.purchasePrice = source.purchasePrice
        case "retailPrice": target.retailPrice = source.retailPrice
        case "stockQuantity": target.stockQuantity = source.stockQuantity
        case "supplierName": target.supplierName = source.supplierName
        case "categoryName": target.categoryName = source.categoryName
        default: break
        }
    }

    static func labelKey(_ field: String) -> String {
        switch field {
        case "barcode": "product.field.barcode"
        case "itemNumber": "product.field.item_number"
        case "productName": "product.field.name"
        case "secondProductName": "product.field.second_name"
        case "purchasePrice": "product.field.purchase_price"
        case "retailPrice": "product.field.retail_price"
        case "stockQuantity": "product.field.stock_quantity"
        case "supplierName": "product.field.supplier_name"
        case "categoryName": "product.field.category_name"
        default: "product.review.field_unknown"
        }
    }

    static func value(_ field: String, in draft: ProductDraft?) -> String {
        guard let draft else { return "—" }
        switch field {
        case "barcode": return draft.barcode
        case "itemNumber": return draft.itemNumber ?? "—"
        case "productName": return draft.productName ?? "—"
        case "secondProductName": return draft.secondProductName ?? "—"
        case "purchasePrice": return draft.purchasePrice.map { String($0) } ?? "—"
        case "retailPrice": return draft.retailPrice.map { String($0) } ?? "—"
        case "stockQuantity": return draft.stockQuantity.map { String($0) } ?? "—"
        case "supplierName": return draft.supplierName ?? "—"
        case "categoryName": return draft.categoryName ?? "—"
        default: return "—"
        }
    }
}

enum ProductEditorReviewChoice {
    case returnToEditing
    case useCurrent
    case selectedFields(Set<String>)
}

struct ProductConflictReviewSheet: View {
    let review: ProductEditorConflictReview
    @Binding var selectedFields: Set<String>
    let onChoice: (ProductEditorReviewChoice) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L(review.canPrepareDraft ? "product.review.explanation" : "product.review.unavailable"))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("task145.product.review.explanation")
                }
                ForEach(review.displayedFields, id: \.self) { field in
                    Section(L(ProductDraftReviewFields.labelKey(field))) {
                        valueRow("product.review.base", value: ProductDraftReviewFields.value(field, in: review.base))
                        valueRow("product.review.yours", value: ProductDraftReviewFields.value(field, in: review.desired))
                        valueRow("product.review.current", value: ProductDraftReviewFields.value(field, in: review.current))
                        if review.contestedFields.contains(field) {
                            Label(L("product.review.contested"), systemImage: "exclamationmark.triangle")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        if review.canPrepareDraft, review.intendedFields.contains(field) {
                            Toggle(L("product.review.keep_field"), isOn: Binding(
                                get: { selectedFields.contains(field) },
                                set: { if $0 { selectedFields.insert(field) } else { selectedFields.remove(field) } }
                            ))
                            .accessibilityIdentifier("task145.product.review.keep.\(field)")
                        }
                    }
                }
                if review.canPrepareDraft {
                    Section {
                        Button(L("product.review.use_current")) { onChoice(.useCurrent) }
                            .accessibilityIdentifier("task145.product.review.use-current")
                        Button(L("product.review.edit_selected")) { onChoice(.selectedFields(selectedFields)) }
                            .accessibilityIdentifier("task145.product.review.edit-selected")
                    }
                }
            }
            .navigationTitle(L("product.review.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("product.review.return")) { onChoice(.returnToEditing) }
                }
            }
        }
        .accessibilityIdentifier("task145.product.review")
    }

    private func valueRow(_ title: String, value: String) -> some View {
        LabeledContent(L(title)) { Text(value).textSelection(.enabled) }
    }
}

/// A missing/ambiguous mapping after cutover cannot mount an old Product or turn
/// an edit into a create. Keep its value draft readable in the admitted scope.
struct UnresolvedProductDraftView: View {
    let draft: LocalRootPresentationState.EditorDraft
    let onDiscard: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section { Text(L("product.review.unavailable")) }
                Section(L("product.review.yours")) {
                    LabeledContent(L("product.field.barcode"), value: draft.barcode)
                    LabeledContent(L("product.field.name"), value: draft.name)
                    LabeledContent(L("product.field.second_name"), value: draft.secondName)
                    LabeledContent(L("product.field.item_number"), value: draft.itemNumber)
                    LabeledContent(L("product.field.purchase_price"), value: draft.purchasePrice)
                    LabeledContent(L("product.field.retail_price"), value: draft.retailPrice)
                    LabeledContent(L("product.field.stock_quantity"), value: draft.stockQuantity)
                    LabeledContent(L("product.field.supplier_name"), value: draft.supplierName)
                    LabeledContent(L("product.field.category_name"), value: draft.categoryName)
                }
                Section {
                    Button(L("product.review.discard_draft"), role: .destructive) { onDiscard(); dismiss() }
                        .accessibilityIdentifier("task145.product.unresolved.discard")
                }
            }
            .navigationTitle(L("product.review.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("common.close")) { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("task145.product.unresolved")
    }
}

private struct CatalogConflictResolutionServiceKey: EnvironmentKey {
    static let defaultValue: CatalogConflictResolutionService? = nil
}

extension EnvironmentValues {
    var catalogConflictResolutionService: CatalogConflictResolutionService? {
        get { self[CatalogConflictResolutionServiceKey.self] }
        set { self[CatalogConflictResolutionServiceKey.self] = newValue }
    }
}

/// Review of an already durable catalog revision. Buttons call the repository
/// command; dismissing this sheet never retires or acknowledges an intent.
struct PersistedProductConflictReviewSheet: View {
    let review: PersistedCatalogConflictReview
    let isResolving: Bool
    let includesNewerRevision: Bool
    let errorMessage: String?
    @Binding var selectedFields: Set<String>
    let onChoice: (PersistedCatalogConflictChoice) -> Void
    let onCancel: () -> Void
    let onRefresh: () -> Void

    private static let fields = ["barcode", "itemNumber", "productName", "secondProductName",
                                 "purchasePrice", "retailPrice", "stockQuantity", "supplierID", "categoryID"]
    private var intendedFields: Set<String> {
        Set(review.originalChangedFields.map { field in
            switch field.lowercased() {
            case "supplier", "suppliername", "supplierid": return "supplierID"
            case "category", "categoryname", "categoryid": return "categoryID"
            default: return Self.fields.first { $0.lowercased() == field.lowercased() } ?? field
            }
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(L("product.resolution.explanation"))
                    if includesNewerRevision {
                        Text(L("product.resolution.newer_revision")).foregroundStyle(.secondary)
                    }
                    if !review.canResolve {
                        Label(L("product.resolution.unconfirmed"), systemImage: "exclamationmark.triangle")
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                        Button(L("product.resolution.refresh"), action: onRefresh).disabled(isResolving)
                            .accessibilityIdentifier("task145.product.resolution.refresh")
                    }
                    if isResolving { ProgressView(L("product.resolution.loading")) }
                }
                ForEach(Self.fields, id: \.self) { field in
                    Section(L(ProductDraftReviewFields.labelKey(editorField(field)))) {
                        LabeledContent(L("product.review.yours")) {
                            Text(value(field, in: review.desired)).textSelection(.enabled)
                        }
                        LabeledContent(L("product.review.current")) {
                            Text(value(field, in: review.remote)).textSelection(.enabled)
                        }
                        if review.canResolve, review.remoteDeletedAt == nil, intendedFields.contains(field) {
                            Toggle(L("product.review.keep_field"), isOn: Binding(
                                get: { selectedFields.contains(field) },
                                set: { if $0 { selectedFields.insert(field) } else { selectedFields.remove(field) } }
                            ))
                            .accessibilityIdentifier("task145.product.resolution.keep.\(field)")
                        }
                    }
                }
                if review.canResolve {
                    Section {
                        if review.remoteDeletedAt != nil {
                            Button(L("product.resolution.adopt_tombstone")) { onChoice(.adoptRemoteTombstone) }
                                .accessibilityIdentifier("task145.product.resolution.adopt-tombstone")
                        } else {
                            Button(L("product.resolution.adopt_remote")) { onChoice(.adoptRemote) }
                                .accessibilityIdentifier("task145.product.resolution.adopt-remote")
                            Button(L("product.resolution.apply_selected")) {
                                onChoice(.selectedFields(values: review.desired, fields: selectedFields.intersection(intendedFields).sorted()))
                            }
                            .disabled(selectedFields.intersection(intendedFields).isEmpty)
                            .accessibilityIdentifier("task145.product.resolution.selected")
                        }
                    }
                    .disabled(isResolving)
                }
            }
            .navigationTitle(L("product.resolution.title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L("product.review.return"), action: onCancel).disabled(isResolving)
                }
            }
        }
        .interactiveDismissDisabled(isResolving)
        .accessibilityIdentifier("task145.product.resolution")
    }

    private func editorField(_ field: String) -> String {
        field == "supplierID" ? "supplierName" : field == "categoryID" ? "categoryName" : field
    }

    private func value(_ field: String, in values: CatalogConflictProductValues) -> String {
        switch field {
        case "barcode": return values.barcode
        case "itemNumber": return values.itemNumber ?? "—"
        case "productName": return values.productName ?? "—"
        case "secondProductName": return values.secondProductName ?? "—"
        case "purchasePrice": return values.purchasePrice.map { String($0) } ?? "—"
        case "retailPrice": return values.retailPrice.map { String($0) } ?? "—"
        case "stockQuantity": return values.stockQuantity.map { String($0) } ?? "—"
        case "supplierID": return values.supplierName ?? "—"
        case "categoryID": return values.categoryName ?? "—"
        default: return "—"
        }
    }
}
