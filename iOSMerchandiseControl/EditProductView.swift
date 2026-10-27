import PhotosUI
import SwiftUI
import SwiftData
import UIKit

struct EditProductView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.localRootPresentationState) private var localPresentation
    @Environment(\.localModelGenerationIsCurrent) private var modelGenerationIsCurrent
    @Environment(\.catalogConflictResolutionService) private var conflictResolutionService
    @EnvironmentObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    @EnvironmentObject private var shopContextStore: ShopContextStore
    @EnvironmentObject private var productImageStore: ProductImageStore

    let existingProduct: Product?
    let pendingOwnerUserID: UUID?
    let isCameraAvailable: Bool
    let persistedConflictChangeID: String?
    @State private var initialDraft: ProductDraft?
    private let logicalRemoteID: UUID?
    private let originalBarcode: String

    @Query(sort: \Supplier.name, order: .forward)
    private var suppliers: [Supplier]

    @Query(sort: \ProductCategory.name, order: .forward)
    private var categories: [ProductCategory]

    @State private var barcode: String
    @State private var name: String
    @State private var secondName: String
    @State private var itemNumber: String
    @State private var purchasePrice: String
    @State private var retailPrice: String
    @State private var stockQuantity: String
    @State private var supplierName: String
    @State private var categoryName: String
    @State private var validationMessage: String?
    @State private var purchasePriceError: String?
    @State private var retailPriceError: String?
    @State private var stockQuantityError: String?
    @State private var productForHistory: Product?
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var pendingImageURL: URL?
    @State private var imageMessage: String?
    @State private var showingCamera = false
    @State private var showingRemoveImageConfirmation = false
    @State private var isViewActive = false
    @State private var isImportingSelectedImage = false
    @State private var imageOperationID: UUID?
    @State private var imageOperationTask: Task<Void, Never>?
    @State private var currentImageVersionID: UUID?
    @State private var currentImageUpdatedAt: Date?
    @State private var mountedPresentationID: String?
    @State private var retainsLocalDraft = true
    @State private var persistedConflictReview: PersistedCatalogConflictReview?
    @State private var persistedSelectedFields = Set<String>()
    @State private var persistedReviewIsLoading = false
    @State private var persistedPreparationID: UUID?
    @State private var persistedPreparingChangeID: String?
    @State private var persistedResolutionIsRunning = false
    @State private var persistedResolutionMessage: String?
    @State private var persistedResolutionError: String?
    @State private var persistedResolutionOperationID: UUID?
    @State private var persistedResolvedChangeID: String?
    @State private var draftConflictReview: ProductEditorConflictReview?
    @State private var draftReviewSelectedFields = Set<String>()
    @State private var draftReviewRequired = false
    @State private var reviewReturnFocus: DraftField?
    @State private var textSelections: [DraftField: TextSelection] = [:]
    @FocusState private var focusedField: DraftField?

    private enum DraftField: String {
        case barcode, name, secondName, itemNumber, purchasePrice, retailPrice, stockQuantity, supplierName, categoryName
    }

    init(
        product: Product? = nil,
        initialBarcode: String? = nil,
        pendingOwnerUserID: UUID? = nil,
        persistedConflictChangeID: String? = nil,
        isCameraAvailable: Bool = UIImagePickerController.isSourceTypeAvailable(.camera)
    ) {
        self.existingProduct = product
        self.pendingOwnerUserID = pendingOwnerUserID
        self.isCameraAvailable = isCameraAvailable
        self.persistedConflictChangeID = persistedConflictChangeID
        _initialDraft = State(initialValue: product.map(Self.makeDraft))
        self.logicalRemoteID = product?.remoteID
        self.originalBarcode = product?.barcode ?? initialBarcode ?? ""

        let initialCode = product?.barcode ?? initialBarcode ?? ""

        _barcode = State(initialValue: initialCode)
        _name = State(initialValue: product?.productName ?? "")
        _secondName = State(initialValue: product?.secondProductName ?? "")
        _itemNumber = State(initialValue: product?.itemNumber ?? "")
        _purchasePrice = State(initialValue: product?.purchasePrice.map { Self.format(number: $0) } ?? "")
        _retailPrice = State(initialValue: product?.retailPrice.map { Self.format(number: $0) } ?? "")
        _stockQuantity = State(initialValue: product?.stockQuantity.map { Self.format(number: $0) } ?? "")
        _supplierName = State(initialValue: product?.supplier?.name ?? "")
        _categoryName = State(initialValue: product?.category?.name ?? "")
        _purchasePriceError = State(initialValue: nil)
        _retailPriceError = State(initialValue: nil)
        _stockQuantityError = State(initialValue: nil)
        _currentImageVersionID = State(initialValue: product?.primaryImageVersionID)
        _currentImageUpdatedAt = State(initialValue: product?.primaryImageUpdatedAt)
    }

    private static func format(number: Double) -> String {
        let intPart = floor(number)
        if number == intPart {
            return String(Int(intPart))
        } else {
            return String(number)
        }
    }

    private var trimmedBarcode: String {
        CatalogTextPolicy.strict(
            barcode,
            required: true,
            maximumUTF16Length: CatalogTextField.barcode.maximumUTF16Length
        ).value ?? ""
    }

    var body: some View {
        Group {
            if isCurrentModelGeneration {
                activeEditor
            }
        }
    }

    private var activeEditor: some View {
        Form {
            if persistedConflictChangeID != nil {
                Section {
                    if persistedReviewIsLoading { ProgressView(L("product.resolution.loading")) }
                    if let persistedResolutionMessage { Text(persistedResolutionMessage) }
                    if let persistedResolutionError { Text(persistedResolutionError).foregroundStyle(.red) }
                    if persistedResolvedChangeID != persistedConflictChangeID {
                        Button(L("product.resolution.action")) {
                            Task { await preparePersistedConflictReview() }
                        }
                        .disabled(persistedReviewIsLoading || persistedResolutionIsRunning || conflictResolutionService == nil)
                        .accessibilityIdentifier("task145.product.resolution.open")
                    }
                }
            }
            if draftReviewRequired || currentProductHasChanged {
                Section {
                    Label(L(draftReviewRequired ? "product.review.conflict" : "product.review.updated"),
                          systemImage: "arrow.triangle.2.circlepath")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button(L("product.review.action"), action: beginDraftReview)
                        .accessibilityIdentifier("task145.product.review.open")
                }
            }
            if let validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            productImageSection

            Section(L("product.section.main")) {
                TextField(L("product.field.barcode"), text: $barcode, selection: selectionBinding(for: .barcode))
                    .focused($focusedField, equals: .barcode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .submitLabel(.next)
                    .accessibilityLabel(Text(L("product.field.barcode")))
                    .accessibilityIdentifier("task141.product.barcode")

                TextField(L("product.field.item_number"), text: $itemNumber, selection: selectionBinding(for: .itemNumber))
                    .focused($focusedField, equals: .itemNumber)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .accessibilityLabel(Text(L("product.field.item_number")))

                TextField(L("product.field.name"), text: $name, selection: selectionBinding(for: .name))
                    .focused($focusedField, equals: .name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .accessibilityLabel(Text(L("product.field.name")))
                    .accessibilityIdentifier("task144.product.name")
                    .task145PerformanceRender("editorRender", qualifies: task145PerformanceEditorMatches(name, barcode: barcode), facts: name)

                TextField(L("product.field.second_name"), text: $secondName, selection: selectionBinding(for: .secondName))
                    .focused($focusedField, equals: .secondName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .accessibilityLabel(Text(L("product.field.second_name")))
            }

            Section(L("product.section.warehouse")) {
                TextField(L("product.field.stock_quantity"), text: $stockQuantity, selection: selectionBinding(for: .stockQuantity))
                    .focused($focusedField, equals: .stockQuantity)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                    .accessibilityLabel(Text(L("product.field.stock_quantity")))
                    .accessibilityIdentifier("task141.product.stock-quantity")
                    .onChange(of: stockQuantity) { _, value in
                        guard stockQuantityError != nil else { return }
                        stockQuantityError = numericInputError(
                            parseOptionalCLQuantityInput(value),
                            kind: .quantity
                        )
                    }

                numericFieldError(
                    stockQuantityError,
                    fieldKey: "product.field.stock_quantity",
                    identifier: "task141.product.stock-quantity-error"
                )
            }

            Section(L("product.section.prices")) {
                TextField(L("product.field.purchase_price"), text: $purchasePrice, selection: selectionBinding(for: .purchasePrice))
                    .focused($focusedField, equals: .purchasePrice)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                    .accessibilityLabel(Text(L("product.field.purchase_price")))
                    .accessibilityIdentifier("task141.product.purchase-price")
                    .onChange(of: purchasePrice) { _, value in
                        guard purchasePriceError != nil else { return }
                        purchasePriceError = numericInputError(
                            parseOptionalCLPriceInput(value),
                            kind: .price
                        )
                    }

                numericFieldError(
                    purchasePriceError,
                    fieldKey: "product.field.purchase_price",
                    identifier: "task141.product.purchase-price-error"
                )

                TextField(L("product.field.retail_price"), text: $retailPrice, selection: selectionBinding(for: .retailPrice))
                    .focused($focusedField, equals: .retailPrice)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                    .accessibilityLabel(Text(L("product.field.retail_price")))
                    .accessibilityIdentifier("task141.product.retail-price")
                    .onChange(of: retailPrice) { _, value in
                        guard retailPriceError != nil else { return }
                        retailPriceError = numericInputError(
                            parseOptionalCLPriceInput(value),
                            kind: .price
                        )
                    }

                numericFieldError(
                    retailPriceError,
                    fieldKey: "product.field.retail_price",
                    identifier: "task141.product.retail-price-error"
                )

                if let product = currentProduct {
                    Button {
                        productForHistory = product
                    } label: {
                        Label(L("product.history.action.open"), systemImage: "clock.arrow.circlepath")
                    }
                }
            }

            Section(L("product.section.supplier")) {
#if DEBUG
                observedSupplierNameField
#else
                TextField(L("product.field.supplier_name"), text: $supplierName, selection: selectionBinding(for: .supplierName))
                    .focused($focusedField, equals: .supplierName)
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel(Text(L("product.field.supplier_name")))
#endif

                if !suppliers.isEmpty {
                    Menu {
                        ForEach(suppliers) { supplier in
                            Button(supplier.name) {
                                supplierName = supplier.name
                            }
                        }
                    } label: {
                        Label(L("product.action.select_existing"), systemImage: "building.2")
                    }
                }
            }

            Section(L("product.section.category")) {
                TextField(L("product.field.category_name"), text: $categoryName, selection: selectionBinding(for: .categoryName))
                    .focused($focusedField, equals: .categoryName)
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel(Text(L("product.field.category_name")))

                if !categories.isEmpty {
                    Menu {
                        ForEach(categories) { category in
                            Button(category.name) {
                                categoryName = category.name
                            }
                        }
                    } label: {
                        Label(L("product.action.select_existing"), systemImage: "tag")
                    }
                }
            }

            if let product = currentProduct {
                StorefrontEditorSection(
                    product: product,
                    operationalName: name,
                    operationalRetailPrice: parseOperationalRetailPrice,
                    operationalCategoryRemoteID: existingProduct?.category?.remoteID,
                    presentationID: mountedPresentationID ?? localPresentation?.currentPresentationID
                )
            }
        }
        .navigationTitle(existingProduct == nil ? L("product.title.new") : L("product.title.edit"))
        #if DEBUG
        .task144ControlledRootControls(inEditor: true)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("common.cancel")) { clearRetainedDraft(); dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L("common.save")) { save() }
                    .fontWeight(.semibold)
            }
        }
        .task(id: persistedConflictChangeID) {
            if persistedConflictChangeID != nil, persistedResolvedChangeID != persistedConflictChangeID {
                persistedResolutionMessage = nil
                await preparePersistedConflictReview()
            }
        }
        .sheet(item: $draftConflictReview, onDismiss: restoreReviewFocus) { review in
            ProductConflictReviewSheet(review: review, selectedFields: $draftReviewSelectedFields) { choice in
                applyDraftReviewChoice(choice, review: review)
            }
        }
        .sheet(item: $persistedConflictReview, onDismiss: restoreReviewFocus) { review in
            PersistedProductConflictReviewSheet(review: review,
                isResolving: persistedResolutionIsRunning,
                includesNewerRevision: review.changeID != persistedConflictChangeID,
                errorMessage: persistedResolutionError,
                selectedFields: $persistedSelectedFields,
                onChoice: { choice in resolvePersistedConflict(review, choice: choice) },
                onCancel: { persistedConflictReview = nil },
                onRefresh: { Task { await preparePersistedConflictReview(preservingSelection: true) } })
        }
        .onChange(of: barcode) { _, _ in
            if !trimmedBarcode.isEmpty {
                validationMessage = nil
            }
        }
        .onChange(of: selectedImageItem) { _, item in
            guard let item else { return }
            isImportingSelectedImage = true
            startImageOperation { operationID in
                defer {
                    if imageOperationID == operationID {
                        isImportingSelectedImage = false
                        selectedImageItem = nil
                    }
                }
                do {
                    guard let transfer = try await item.loadTransferable(type: ProductImageTransferFile.self) else {
                        imageMessage = L("product.image.error.input")
                        return
                    }
                    replacePendingImageURL(with: transfer.fileURL)
                    if imageOperationID == operationID {
                        isImportingSelectedImage = false
                    }
                    await uploadPendingImage(operationID: operationID)
                } catch is CancellationError {
                    imageMessage = L("product.image.cancelled")
                } catch {
                    imageMessage = L("product.image.error.input")
                }
            }
        }
        .onChange(of: imageScope) { previousScope, nextScope in
            guard previousScope != nextScope else { return }
            showingCamera = false
            showingRemoveImageConfirmation = false
            productForHistory = nil
            cancelImageOperation(
                scope: previousScope,
                cancelStoreOperation: previousScope != nil
            )
        }
        .task(id: imageScope) {
            productImageStore.activate(scope: imageScope)
        }
        .onAppear {
            isViewActive = true
            restoreRetainedDraft()
        }
        .onChange(of: retainedDraft) { _, draft in
            guard isViewActive, retainsLocalDraft, isCurrentModelGeneration else { return }
#if DEBUG
            updateObservedRetainedDraft(draft)
#else
            localPresentation?.update(presentationID: mountedPresentationID) { $0.editor = draft }
#endif
        }
        .onDisappear {
            isViewActive = false
            _ = cancelImageOperation()
        }
        .sheet(isPresented: $showingCamera) {
            ProductImageCameraPicker(
                onCapture: { url in
                    showingCamera = false
                    replacePendingImageURL(with: url)
                    startImageOperation { operationID in
                        await uploadPendingImage(operationID: operationID)
                    }
                },
                onCancel: {
                    showingCamera = false
                }
            )
            .ignoresSafeArea()
        }
        .confirmationDialog(
            L("product.image.remove.confirm.title"),
            isPresented: $showingRemoveImageConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("product.image.remove"), role: .destructive) {
                startImageOperation { operationID in
                    await removeCurrentImage(operationID: operationID)
                }
            }
            Button(L("common.cancel"), role: .cancel) {}
        }
        .sheet(item: $productForHistory) { product in
            NavigationStack {
                ProductPriceHistoryView(
                    product: product,
                    pendingOwnerUserID: pendingOwnerUserID,
                    onCurrentPriceUpdated: { type, value in
                        switch type {
                        case .purchase:
                            purchasePrice = Self.format(number: value)
                        case .retail:
                            retailPrice = Self.format(number: value)
                        }
                    }
                )
            }
        }
    }

    private var isCurrentModelGeneration: Bool {
        modelGenerationIsCurrent() && (localPresentation?.isCurrent(presentationID: mountedPresentationID) ?? true)
    }

#if DEBUG
    private var observedSupplierNameField: some View {
        TextField(L("product.field.supplier_name"), text: observedSupplierNameBinding, selection: selectionBinding(for: .supplierName))
            .focused($focusedField, equals: .supplierName)
            .textInputAutocapitalization(.words)
            .accessibilityLabel(Text(L("product.field.supplier_name")))
    }

    private func updateObservedRetainedDraft(_ draft: LocalRootPresentationState.EditorDraft) {
        localPresentation?.update(presentationID: mountedPresentationID) {
            $0.editor = draft
            Task144RootObservation.recordRelatedSupplierInput("retained-update", value: draft.supplierName,
                focusedField: draft.focusedField)
        }
    }

    private var observedSupplierNameBinding: Binding<String> {
        let original = $supplierName
        guard Task144RootObservation.observesRelatedInput else { return original }
        return Binding(get: { original.wrappedValue }, set: { (value: String, transaction: Transaction) in
            original.transaction(transaction).wrappedValue = value
            Task144RootObservation.recordRelatedSupplierInput("binding-set-returned", value: value,
                focusedField: focusedField?.rawValue)
        }).transaction(original.transaction)
    }
#endif

    private var retainedDraft: LocalRootPresentationState.EditorDraft {
        .init(remoteID: logicalRemoteID, originalBarcode: originalBarcode, baseline: initialDraft,
            barcode: barcode, name: name, secondName: secondName, itemNumber: itemNumber,
            purchasePrice: purchasePrice, retailPrice: retailPrice, stockQuantity: stockQuantity,
            supplierName: supplierName, categoryName: categoryName, focusedField: retainedFocusedField?.rawValue,
            selectionLowerBound: retainedSelectionOffsets?.lowerBound,
            selectionUpperBound: retainedSelectionOffsets?.upperBound)
    }

    private func restoreRetainedDraft() {
        guard isCurrentModelGeneration else { return }
        retainsLocalDraft = true
        mountedPresentationID = localPresentation?.currentPresentationID
        if let draft = localPresentation?.editor(presentationID: mountedPresentationID,
            remoteID: logicalRemoteID, barcode: originalBarcode) {
            initialDraft = draft.baseline
            barcode = draft.barcode
            name = draft.name
            secondName = draft.secondName
            itemNumber = draft.itemNumber
            purchasePrice = draft.purchasePrice
            retailPrice = draft.retailPrice
            stockQuantity = draft.stockQuantity
            supplierName = draft.supplierName
            categoryName = draft.categoryName
            focusedField = draft.focusedField.flatMap(DraftField.init(rawValue:))
            if let field = focusedField, let lower = draft.selectionLowerBound, let upper = draft.selectionUpperBound {
                restoreSelection(field: field, lower: lower, upper: upper)
            }
#if DEBUG
            Task144RootObservation.recordRelatedSupplierInput("restore-applied", value: draft.supplierName,
                focusedField: draft.focusedField)
#endif
        }
        localPresentation?.update(presentationID: mountedPresentationID) {
            $0.editor = retainedDraft
#if DEBUG
            if let draft = $0.editor {
                Task144RootObservation.recordRelatedSupplierInput("retained-from-restore", value: draft.supplierName,
                    focusedField: draft.focusedField)
            }
#endif
        }
    }

    private func clearRetainedDraft() {
        guard isCurrentModelGeneration else { return }
        retainsLocalDraft = false
        localPresentation?.update(presentationID: mountedPresentationID) { $0.editor = nil }
    }

    private var currentProduct: Product? {
        guard isCurrentModelGeneration, let product = existingProduct,
              !product.isDeleted, product.modelContext != nil else { return nil }
        return product
    }

    @ViewBuilder
    private var productImageSection: some View {
        Section(L("product.image.section")) {
            if let product = currentProduct,
               let productID = product.remoteID {
                ZStack {
                    ProductImageRemoteView(
                        scope: imageScope,
                        productID: productID,
                        versionID: currentImageVersionID,
                        variant: .main
                    )

                    if let pendingPreviewImage {
                        Image(uiImage: pendingPreviewImage)
                            .resizable()
                            .scaledToFit()
                            .transition(.opacity)
                            .accessibilityLabel(Text(L("product.image.pending_preview")))
                            .accessibilityIdentifier("product.image.pending-preview")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.18),
                    value: pendingPreviewImage != nil
                )

                if isImageBusy {
                    HStack(spacing: 10) {
                        ProgressView()
                            .accessibilityIdentifier("product.image.operation.progress")
                        Text(imageProgressLabel)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if isImageOperationCancellable {
                            Button(L("product.image.cancel"), role: .cancel) {
                                cancelImageOperation()
                            }
                            .accessibilityIdentifier("product.image.operation.cancel")
                        }
                    }
                }

                if let imageMessage {
                    Text(imageMessage)
                        .font(.footnote)
                        .foregroundStyle(productImageStore.operationStage(productID: productID) == .failed ? .red : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if canWriteProductImage {
                    productImageSourceActions

                    if currentImageVersionID != nil {
                        Button(L("product.image.remove"), role: .destructive) {
                            showingRemoveImageConfirmation = true
                        }
                        .disabled(isImageBusy)
                        .accessibilityIdentifier("product.image.editor.remove")
                    }

                    if pendingImageURL != nil,
                       productImageStore.operationStage(productID: productID) == .failed {
                        HStack {
                            Button(L("product.image.retry")) {
                                startImageOperation { operationID in
                                    await uploadPendingImage(operationID: operationID)
                                }
                            }
                            Button(L("common.cancel"), role: .cancel) {
                                clearPendingImageURL()
                                imageMessage = nil
                            }
                        }
                    }
                } else {
                    Text(productImageStore.isAvailable
                         ? L("product.image.read_only")
                         : L("product.image.unavailable"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(L("product.image.save_first"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var productImageSourceActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                if isCameraAvailable {
                    productImageCameraButton(expands: false)
                }
                productImageLibraryPicker(expands: false)
            }

            VStack(spacing: 10) {
                if isCameraAvailable {
                    productImageCameraButton(expands: true)
                }
                productImageLibraryPicker(expands: true)
            }
        }
    }

    private func productImageCameraButton(expands: Bool) -> some View {
        Button {
            showingCamera = true
        } label: {
            Label(L("product.image.camera"), systemImage: "camera")
                .fixedSize(horizontal: !expands, vertical: false)
                .frame(maxWidth: expands ? .infinity : nil, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isImageBusy)
        .accessibilityIdentifier("product.image.editor.camera")
    }

    private func productImageLibraryPicker(expands: Bool) -> some View {
        PhotosPicker(selection: $selectedImageItem, matching: .images) {
            Label(L("product.image.library"), systemImage: "photo.on.rectangle")
                .fixedSize(horizontal: !expands, vertical: false)
                .frame(maxWidth: expands ? .infinity : nil, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(isImageBusy)
        .accessibilityIdentifier("product.image.editor.library")
    }

    private var imageScope: ProductImageScope? {
        guard isCurrentModelGeneration, supabaseAuthViewModel.isSignedIn,
              let accountID = supabaseAuthViewModel.sessionInfo?.userID,
              shopContextStore.context.accountHash == AccountBindingStore.accountHash(for: accountID),
              let selectedShop = shopContextStore.context.selectedShop else {
            return nil
        }
        let bindingStore = AccountBindingStore()
        return ProductImageOwnerStoreGate.scope(
            accountID: accountID,
            selectedShop: selectedShop,
            binding: bindingStore.currentBinding,
            hasPendingReplacement: bindingStore.hasPendingReplacementJournal
        )
    }

    private var parseOperationalRetailPrice: Double? {
        switch parseOptionalCLPriceInput(retailPrice) {
        case .value(let value): value
        case .empty, .invalid, .negative: nil
        }
    }

    private var canWriteProductImage: Bool {
        guard productImageStore.isAvailable,
              currentProduct?.remoteID != nil,
              imageScope != nil,
              shopContextStore.context.syncAllowed,
              let selectedShop = shopContextStore.context.selectedShop else {
            return false
        }
        return selectedShop.canWrite && selectedShop.isValidProductImageSelection
    }

    private var isImageBusy: Bool {
        if isImportingSelectedImage { return true }
        guard let productID = currentProduct?.remoteID else { return false }
        switch productImageStore.operationStage(productID: productID) {
        case .processing, .uploadingMain, .uploadingThumb, .finalizing, .removing:
            return true
        case .idle, .completed, .cancelled, .failed:
            return false
        }
    }

    private var isImageOperationCancellable: Bool {
        if isImportingSelectedImage { return true }
        guard let productID = currentProduct?.remoteID else { return false }
        return productImageStore.operationStage(productID: productID).allowsCancellation
    }

    private var imageProgressLabel: String {
        if isImportingSelectedImage { return L("product.image.importing") }
        guard let productID = currentProduct?.remoteID else { return L("product.image.processing") }
        switch productImageStore.operationStage(productID: productID) {
        case .processing: return L("product.image.processing")
        case .uploadingMain: return L("product.image.uploading_main")
        case .uploadingThumb: return L("product.image.uploading_thumb")
        case .finalizing: return L("product.image.finalizing")
        case .removing: return L("product.image.removing")
        case .idle, .completed, .cancelled, .failed: return ""
        }
    }

    private var pendingPreviewImage: UIImage? {
        productImageStore.pendingPreview(
            scope: imageScope,
            productID: currentProduct?.remoteID
        )
    }

    private func uploadPendingImage(operationID: UUID) async {
        guard imageOperationID == operationID,
              canWriteProductImage,
              let fileURL = pendingImageURL,
              let scope = imageScope,
              let product = currentProduct,
              let productID = product.remoteID else {
            imageMessage = L("product.image.error.context")
            return
        }
        imageMessage = nil
        let previousVersionID = currentImageVersionID
        do {
            let result = try await productImageStore.upload(
                fileURL: fileURL,
                scope: scope,
                productID: productID,
                previousVersionID: previousVersionID,
                retainMutationLeaseAfterResponse: true
            )
            defer {
                productImageStore.finishMutationLease(scope: scope, productID: productID)
            }
            guard imageOperationID == operationID,
                  imageScope == scope,
                  canWriteProductImage,
                  currentProduct?.remoteID == productID else { return }
            do {
                let productPersistentID = product.persistentModelID
                try Task126OwnerStoreGate.withLocalMutationFence(
                    modelContainer: context.container,
                    ownerUserID: pendingOwnerUserID
                ) { freshContext in
                    let freshProduct = try Task126OwnerStoreGate.requireLocalModel(
                        Product.self,
                        id: productPersistentID,
                        in: freshContext
                    )
                    guard freshProduct.remoteID == productID,
                          freshProduct.remoteDeletedAt == nil,
                          freshProduct.primaryImageVersionID == previousVersionID
                            || freshProduct.primaryImageVersionID == result.versionID else {
                        throw Task126OwnerStoreGateError.localRemoteConflictRequiresReview
                    }
                    freshProduct.primaryImageVersionID = result.versionID
                    if let imageUpdatedAt = result.imageUpdatedAt {
                        freshProduct.primaryImageUpdatedAt = imageUpdatedAt
                    }
                    try freshContext.save()
                }
                currentImageVersionID = result.versionID
                currentImageUpdatedAt = result.imageUpdatedAt ?? currentImageUpdatedAt
                imageMessage = String(
                    format: L("product.image.success.metrics"),
                    result.metrics.mainBytes / 1_024,
                    result.metrics.thumbBytes / 1_024,
                    result.metrics.elapsedMilliseconds
                )
            } catch {
                imageMessage = L("product.image.error.local_refresh")
            }
            clearPendingImageURL()
        } catch is CancellationError {
            guard imageOperationID == operationID else { return }
            imageMessage = L("product.image.cancelled")
            clearPendingImageURL()
        } catch {
            guard imageOperationID == operationID else { return }
            imageMessage = L("product.image.error.upload")
            if !isViewActive {
                clearPendingImageURL()
            }
        }
    }

    private func removeCurrentImage(operationID: UUID) async {
        guard imageOperationID == operationID,
              canWriteProductImage,
              let scope = imageScope,
              let product = currentProduct,
              let productID = product.remoteID,
              let versionID = currentImageVersionID else {
            return
        }
        imageMessage = nil
        do {
            let result = try await productImageStore.remove(
                scope: scope,
                productID: productID,
                versionID: versionID,
                retainMutationLeaseAfterResponse: true
            )
            defer {
                productImageStore.finishMutationLease(scope: scope, productID: productID)
            }
            guard imageOperationID == operationID,
                  imageScope == scope,
                  canWriteProductImage,
                  currentProduct?.remoteID == productID else { return }
            do {
                let productPersistentID = product.persistentModelID
                try Task126OwnerStoreGate.withLocalMutationFence(
                    modelContainer: context.container,
                    ownerUserID: pendingOwnerUserID
                ) { freshContext in
                    let freshProduct = try Task126OwnerStoreGate.requireLocalModel(
                        Product.self,
                        id: productPersistentID,
                        in: freshContext
                    )
                    guard freshProduct.remoteID == productID,
                          freshProduct.remoteDeletedAt == nil,
                          freshProduct.primaryImageVersionID == versionID
                            || freshProduct.primaryImageVersionID == nil else {
                        throw Task126OwnerStoreGateError.localRemoteConflictRequiresReview
                    }
                    freshProduct.primaryImageVersionID = nil
                    freshProduct.primaryImageUpdatedAt = result.imageUpdatedAt
                    try freshContext.save()
                }
                currentImageVersionID = nil
                currentImageUpdatedAt = result.imageUpdatedAt
                imageMessage = L("product.image.remove.success")
            } catch {
                imageMessage = L("product.image.error.local_refresh")
            }
        } catch is CancellationError {
            guard imageOperationID == operationID else { return }
            imageMessage = L("product.image.cancelled")
        } catch {
            guard imageOperationID == operationID else { return }
            imageMessage = L("product.image.error.remove")
        }
    }

    private func startImageOperation(
        _ operation: @escaping @MainActor (_ operationID: UUID) async -> Void
    ) {
        let operationID = UUID()
        imageOperationTask?.cancel()
        self.imageOperationID = operationID
        imageOperationTask = Task { @MainActor in
            await operation(operationID)
            guard imageOperationID == operationID else { return }
            imageOperationID = nil
            imageOperationTask = nil
        }
    }

    @discardableResult
    private func cancelImageOperation(
        scope: ProductImageScope? = nil,
        cancelStoreOperation: Bool = true
    ) -> Bool {
        if let productID = currentProduct?.remoteID {
            let stage = productImageStore.operationStage(productID: productID)
            guard stage != .finalizing, stage != .removing else { return false }
        }
        let hadOperation = imageOperationTask != nil
            || pendingImageURL != nil
            || isImportingSelectedImage
        imageOperationID = nil
        imageOperationTask?.cancel()
        self.imageOperationTask = nil
        isImportingSelectedImage = false
        selectedImageItem = nil
        if hadOperation, cancelStoreOperation,
           let productID = currentProduct?.remoteID {
            productImageStore.cancelOperation(
                productID: productID,
                scope: scope ?? imageScope
            )
        }
        clearPendingImageURL()
        if hadOperation {
            imageMessage = L("product.image.cancelled")
        }
        return true
    }

    private func replacePendingImageURL(with url: URL) {
        clearPendingImageURL()
        pendingImageURL = url
    }

    private func clearPendingImageURL() {
        guard let pendingImageURL else { return }
        try? FileManager.default.removeItem(at: pendingImageURL)
        self.pendingImageURL = nil
    }

    private func save() {
        #if DEBUG
        PilotCommitTrace.b6SourceMutationBegin(categories: ["create", "update", "price"])
        #endif
        #if DEBUG
        Task144RootObservation.performanceAction("save")
        #endif
        guard isCurrentModelGeneration else {
            validationMessage = L("product.validation.save_failed")
            return
        }
        guard !barcode.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = L("product.validation.barcode_required")
            return
        }

        let purchaseResult = parseOptionalCLPriceInput(purchasePrice)
        let retailResult = parseOptionalCLPriceInput(retailPrice)
        let stockResult = parseOptionalCLQuantityInput(stockQuantity)
        purchasePriceError = numericInputError(purchaseResult, kind: .price)
        retailPriceError = numericInputError(retailResult, kind: .price)
        stockQuantityError = numericInputError(stockResult, kind: .quantity)
        guard purchaseResult.isAccepted,
              retailResult.isAccepted,
              stockResult.isAccepted else {
            validationMessage = nil
            return
        }

        let purchase = purchaseResult.value
        let retail = retailResult.value
        let stock = stockResult.value
        let formDraft: ProductDraft
        do {
            formDraft = try ProductImportCore.validatedDraft(
                ProductDraft(
                    barcode: barcode,
                    itemNumber: Self.optionalRaw(itemNumber),
                    productName: Self.optionalRaw(name),
                    secondProductName: Self.optionalRaw(secondName),
                    purchasePrice: purchase,
                    retailPrice: retail,
                    stockQuantity: stock,
                    supplierName: Self.optionalRaw(supplierName),
                    categoryName: Self.optionalRaw(categoryName)
                )
            )
        } catch let error as CatalogTextValidationError {
            validationMessage = L(error.reason.localizationKey)
            return
        } catch {
            validationMessage = L("catalog.text.error.invalid_input")
            return
        }
        let existingID = existingProduct?.persistentModelID

        var savedProductReceipt: LocalProductSaveReceipt?
        var rejectedReview: ProductEditorConflictReview?
        #if DEBUG
        // Capture outside the nonrecursive local mutation lease. The observer
        // compares the actual lease generation already held by the writer.
        let b6Scope = PilotCommitTrace.b6ObservationEnabled ? pendingOwnerUserID.flatMap {
            try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: $0)
        } : nil
        #endif
        do {
            try Task126OwnerStoreGate.withLocalMutationFence(
                modelContainer: context.container,
                ownerUserID: pendingOwnerUserID
            ) { freshContext in
                let currentSuppliers = try freshContext.fetch(FetchDescriptor<Supplier>())
                let currentCategories = try freshContext.fetch(FetchDescriptor<ProductCategory>())
                let target: Product
                let operation: LocalPendingChangeOperation
                let baselineDraft: ProductDraft?
                let baselineFingerprintHash: String?
                let userChangedFields: [String]
                if let existingID {
                    target = try Task126OwnerStoreGate.requireLocalModel(
                        Product.self,
                        id: existingID,
                        in: freshContext
                    )
                    guard let initialDraft else {
                        throw Task126OwnerStoreGateError.localModelUnavailable
                    }
                    let freshDraft = Self.makeDraft(target)
                    rejectedReview = ProductEditorConflictReview(base: initialDraft, desired: formDraft,
                        current: freshDraft, remoteDeleted: target.remoteDeletedAt != nil)
                    let requestedUserChangedFields = Self.changedFieldNames(
                        old: initialDraft,
                        new: formDraft
                    )
                    userChangedFields = Self.changedFieldNames(
                        old: freshDraft,
                        new: formDraft
                    ).filter { requestedUserChangedFields.contains($0) }
                    let remoteChangedFields = Self.changedFieldNames(
                        old: initialDraft,
                        new: freshDraft
                    )
                    guard Task126ConflictResolver.resolve(
                        localChangedFields: userChangedFields,
                        remoteChangedFields: remoteChangedFields,
                        remoteDeleted: target.remoteDeletedAt != nil
                    ) == .autoMerge else {
                        throw Task126OwnerStoreGateError.localRemoteConflictRequiresReview
                    }
                    baselineDraft = freshDraft
                    baselineFingerprintHash = LocalPendingChangeLogicalKey
                        .productFingerprintHash(target)
                    operation = .update
                } else {
                    target = Product(barcode: formDraft.barcode)
                    freshContext.insert(target)
                    baselineDraft = nil
                    baselineFingerprintHash = nil
                    userChangedFields = Self.createChangedFields
                    operation = .create
                }
                let hasBarcodeConflict = try freshContext.fetch(
                    FetchDescriptor<Product>()
                ).contains(where: {
                    let canonicalBarcode = CatalogTextPolicy.strict(
                        $0.barcode,
                        required: true,
                        maximumUTF16Length:
                            CatalogTextField.barcode.maximumUTF16Length
                    ).value
                    return $0.persistentModelID != target.persistentModelID
                        && canonicalBarcode.map(
                            ProductImportCore.strictIdentityKey
                        ) == ProductImportCore.strictIdentityKey(
                            formDraft.barcode
                        )
                })
                guard !hasBarcodeConflict else {
                    throw Task126OwnerStoreGateError.localRemoteConflictRequiresReview
                }

                if userChangedFields.contains("barcode") { target.barcode = formDraft.barcode }
                if userChangedFields.contains("itemNumber") { target.itemNumber = formDraft.itemNumber }
                if userChangedFields.contains("productName") { target.productName = formDraft.productName }
                if userChangedFields.contains("secondProductName") {
                    target.secondProductName = formDraft.secondProductName
                }
                if userChangedFields.contains("purchasePrice") {
                    target.purchasePrice = formDraft.purchasePrice
                }
                if userChangedFields.contains("retailPrice") {
                    target.retailPrice = formDraft.retailPrice
                }
                if userChangedFields.contains("stockQuantity") {
                    target.stockQuantity = formDraft.stockQuantity
                }

                var createdSupplier: Supplier?
                if userChangedFields.contains("supplierName") {
                    if let supplierName = formDraft.supplierName {
                        let relationKey = ProductImportCore.normalizedRelationKey(supplierName)
                        let matches = currentSuppliers.filter {
                            ProductImportCore.normalizedRelationKey($0.name) == relationKey
                        }
                        guard !matches.contains(where: { $0.remoteDeletedAt != nil }) else {
                            throw Task126OwnerStoreGateError.localRemoteConflictRequiresReview
                        }
                        if let existing = matches.first {
                            target.supplier = existing
                        } else {
                            let newSupplier = Supplier(name: supplierName)
                            freshContext.insert(newSupplier)
                            target.supplier = newSupplier
                            createdSupplier = newSupplier
                        }
                    } else {
                        target.supplier = nil
                    }
                }

                var createdCategory: ProductCategory?
                if userChangedFields.contains("categoryName") {
                    if let categoryName = formDraft.categoryName {
                        let relationKey = ProductImportCore.normalizedRelationKey(categoryName)
                        let matches = currentCategories.filter {
                            ProductImportCore.normalizedRelationKey($0.name) == relationKey
                        }
                        guard !matches.contains(where: { $0.remoteDeletedAt != nil }) else {
                            throw Task126OwnerStoreGateError.localRemoteConflictRequiresReview
                        }
                        if let existing = matches.first {
                            target.category = existing
                        } else {
                            let newCategory = ProductCategory(name: categoryName)
                            freshContext.insert(newCategory)
                            target.category = newCategory
                            createdCategory = newCategory
                        }
                    } else {
                        target.category = nil
                    }
                }

                let oldPurchase = baselineDraft?.purchasePrice
                let oldRetail = baselineDraft?.retailPrice
                let priceChanges = createPriceHistoryIfNeeded(
                    for: target,
                    oldPurchase: oldPurchase,
                    newPurchase: userChangedFields.contains("purchasePrice") ? purchase : oldPurchase,
                    oldRetail: oldRetail,
                    newRetail: userChangedFields.contains("retailPrice") ? retail : oldRetail,
                    context: freshContext
                )

                let accumulator = LocalPendingChangeAccumulator(
                    context: freshContext,
                    ownerUserID: pendingOwnerUserID
                )
                var savedIntents: [LocalPendingChangeCASToken] = []
                if let createdSupplier {
                    if let change = try accumulator.recordSupplierChange(
                        supplier: createdSupplier,
                        operation: .create,
                        origin: .manualCatalogSave
                    ) { savedIntents.append(LocalPendingChangeCASToken(change)) }
                }
                if let createdCategory {
                    if let change = try accumulator.recordCategoryChange(
                        category: createdCategory,
                        operation: .create,
                        origin: .manualCatalogSave
                    ) { savedIntents.append(LocalPendingChangeCASToken(change)) }
                }
                if operation == .create || !userChangedFields.isEmpty {
                    if let change = try accumulator.recordProductChange(
                        product: target,
                        operation: operation,
                        origin: .manualCatalogSave,
                        changedFields: userChangedFields,
                        baselineFingerprintHash: baselineFingerprintHash
                    ) { savedIntents.append(LocalPendingChangeCASToken(change)) }
                }
                try priceChanges.forEach {
                    if let change = try accumulator.recordProductPriceChange(price: $0, origin: .productPriceSave) {
                        savedIntents.append(LocalPendingChangeCASToken(change))
                    }
                }
                #if DEBUG
                let b6Ticket = PilotCommitTrace.b6LocalBegin(product: target, prices: priceChanges,
                    intents: savedIntents, scope: b6Scope)
                do {
                    try freshContext.save()
                    PilotCommitTrace.b6LocalEnd(b6Ticket, returned: true, ns: PilotCommitTrace.b6Now())
                } catch {
                    PilotCommitTrace.b6LocalEnd(b6Ticket, returned: false, ns: PilotCommitTrace.b6Now())
                    throw error
                }
                #else
                try freshContext.save()
                #endif
                #if DEBUG
                Task144RootObservation.performanceMark("saveCommit", facts: "business-and-intent-save-returned")
                #endif
                if !savedIntents.isEmpty, let manifest = Task126OwnerStoreGate.activeManifestWithLeaseHeld(freshContext.container) {
                    savedProductReceipt = LocalProductSaveReceipt(product: target, manifest: manifest, intents: savedIntents)
                }
            }
            if let savedProductReceipt {
                localPresentation?.recordSavedProduct(savedProductReceipt, presentationID: mountedPresentationID)
                #if DEBUG
                Task144LocalAvailabilityRootFixture.current?.performanceRecordSaveReceipt(savedProductReceipt)
                #endif
            }
            clearRetainedDraft()
            dismiss()
        } catch let error as Task126OwnerStoreGateError {
            switch error {
            case .localRemoteConflictRequiresReview:
                draftReviewRequired = true
                validationMessage = L(rejectedReview?.remoteDeleted == true
                    ? "product.review.unavailable" : "product.review.conflict")
            case .localModelUnavailable, .retiredStoreGeneration:
                draftReviewRequired = true
                validationMessage = L("product.review.unavailable")
            default:
                validationMessage = L("product.review.save_retry")
            }
        } catch {
            validationMessage = L("product.review.save_retry")
        }
    }

    private var currentProductHasChanged: Bool {
        guard isCurrentModelGeneration, let initialDraft else { return false }
        guard let product = currentProduct else { return true }
        return product.remoteDeletedAt != nil || !ProductDraftReviewFields.changed(from: initialDraft,
            to: Self.makeDraft(product)).isEmpty
    }

    private func currentFormDraftForReview() -> ProductDraft? {
        let purchase = parseOptionalCLPriceInput(purchasePrice)
        let retail = parseOptionalCLPriceInput(retailPrice)
        let quantity = parseOptionalCLQuantityInput(stockQuantity)
        purchasePriceError = numericInputError(purchase, kind: .price)
        retailPriceError = numericInputError(retail, kind: .price)
        stockQuantityError = numericInputError(quantity, kind: .quantity)
        guard purchase.isAccepted, retail.isAccepted, quantity.isAccepted else { return nil }
        do {
            return try ProductImportCore.validatedDraft(ProductDraft(barcode: barcode,
                itemNumber: Self.optionalRaw(itemNumber), productName: Self.optionalRaw(name),
                secondProductName: Self.optionalRaw(secondName), purchasePrice: purchase.value,
                retailPrice: retail.value, stockQuantity: quantity.value,
                supplierName: Self.optionalRaw(supplierName), categoryName: Self.optionalRaw(categoryName)))
        } catch let error as CatalogTextValidationError {
            validationMessage = L(error.reason.localizationKey)
        } catch { validationMessage = L("catalog.text.error.invalid_input") }
        return nil
    }

    private func captureDraftReview(desired: ProductDraft) throws -> ProductEditorConflictReview {
        guard isCurrentModelGeneration, let initialDraft,
              Task126OwnerStoreGate.permitsSameScopeLocalAccess(modelContainer: context.container,
                ownerUserID: pendingOwnerUserID) else { throw Task126OwnerStoreGateError.localModelUnavailable }
        let freshContext = ModelContext(context.container)
        freshContext.autosaveEnabled = false
        let current = try currentProduct.map {
            try Task126OwnerStoreGate.requireLocalModel(Product.self, id: $0.persistentModelID, in: freshContext)
        }
        guard isCurrentModelGeneration else { throw Task126OwnerStoreGateError.retiredStoreGeneration }
        return ProductEditorConflictReview(base: initialDraft, desired: desired,
            current: current.map(Self.makeDraft), remoteDeleted: current?.remoteDeletedAt != nil)
    }

    private func beginDraftReview() {
        guard let desired = currentFormDraftForReview() else { return }
        do {
            let review = try captureDraftReview(desired: desired)
            draftReviewSelectedFields = []
            reviewReturnFocus = focusedField ?? reviewReturnFocus
            draftConflictReview = review
        } catch { validationMessage = L("product.review.unavailable") }
    }

    private func applyDraftReviewChoice(_ choice: ProductEditorReviewChoice,
                                       review: ProductEditorConflictReview) {
        if case .returnToEditing = choice { draftConflictReview = nil; return }
        do {
            let fresh = try captureDraftReview(desired: review.desired)
            guard fresh.current == review.current, fresh.remoteDeleted == review.remoteDeleted else {
                draftConflictReview = fresh
                validationMessage = L("product.resolution.changed_again")
                return
            }
            let selected: Set<String>
            switch choice {
            case .returnToEditing: return
            case .useCurrent: selected = []
            case .selectedFields(let fields): selected = fields
            }
            guard let prepared = review.preparingDraft(selectedFields: selected), let current = review.current else {
                validationMessage = L("product.review.unavailable")
                return
            }
            let selection = retainedSelectionOffsets
            initialDraft = current
            barcode = prepared.barcode; name = prepared.productName ?? ""
            secondName = prepared.secondProductName ?? ""; itemNumber = prepared.itemNumber ?? ""
            purchasePrice = prepared.purchasePrice.map { Self.format(number: $0) } ?? ""
            retailPrice = prepared.retailPrice.map { Self.format(number: $0) } ?? ""
            stockQuantity = prepared.stockQuantity.map { Self.format(number: $0) } ?? ""
            supplierName = prepared.supplierName ?? ""; categoryName = prepared.categoryName ?? ""
            textSelections = [:]
            if let field = reviewReturnFocus, let selection {
                let count = fieldText(field).count
                restoreSelection(field: field, lower: min(selection.lowerBound, count),
                    upper: min(selection.upperBound, count))
            }
            validationMessage = nil; draftReviewRequired = false
            draftConflictReview = nil
        } catch { validationMessage = L("product.review.unavailable") }
    }

    private func restoreReviewFocus() {
        let field = reviewReturnFocus
        Task { @MainActor in
            await Task.yield()
            guard isViewActive, isCurrentModelGeneration else { return }
            focusedField = field
        }
    }

    private var retainedFocusedField: DraftField? {
        focusedField ?? ((draftConflictReview != nil || persistedConflictReview != nil) ? reviewReturnFocus : nil)
    }

    private func fieldText(_ field: DraftField) -> String {
        switch field {
        case .barcode: barcode
        case .name: name
        case .secondName: secondName
        case .itemNumber: itemNumber
        case .purchasePrice: purchasePrice
        case .retailPrice: retailPrice
        case .stockQuantity: stockQuantity
        case .supplierName: supplierName
        case .categoryName: categoryName
        }
    }

    private func selectionBinding(for field: DraftField) -> Binding<TextSelection?> {
        Binding(get: { textSelections[field] }, set: { textSelections[field] = $0 })
    }

    private var retainedSelectionOffsets: Range<Int>? {
        guard let field = retainedFocusedField, let selection = textSelections[field],
              case .selection(let range) = selection.indices else { return nil }
        let text = fieldText(field)
        let boundaries = Set(text.indices).union([text.endIndex])
        guard boundaries.contains(range.lowerBound), boundaries.contains(range.upperBound) else { return nil }
        return text.distance(from: text.startIndex, to: range.lowerBound)..<text.distance(from: text.startIndex, to: range.upperBound)
    }

    private func restoreSelection(field: DraftField, lower: Int, upper: Int) {
        let text = fieldText(field)
        guard lower >= 0, upper >= lower,
              let lowerIndex = text.index(text.startIndex, offsetBy: lower, limitedBy: text.endIndex),
              let upperIndex = text.index(text.startIndex, offsetBy: upper, limitedBy: text.endIndex) else { return }
        textSelections[field] = lowerIndex == upperIndex
            ? TextSelection(insertionPoint: lowerIndex) : TextSelection(range: lowerIndex..<upperIndex)
    }

    private func preparePersistedConflictReview(preservingSelection: Bool = false) async {
        guard !persistedResolutionIsRunning,
              isCurrentModelGeneration, let owner = pendingOwnerUserID,
              let remoteID = logicalRemoteID, let changeID = persistedConflictChangeID,
              let service = conflictResolutionService else { return }
        guard !persistedReviewIsLoading || persistedPreparingChangeID != changeID else { return }
        let preparationID = UUID()
        persistedPreparationID = preparationID
        persistedPreparingChangeID = changeID
        persistedReviewIsLoading = true
        persistedResolutionError = nil
        defer {
            if persistedPreparationID == preparationID {
                persistedReviewIsLoading = false
                persistedPreparationID = nil
                persistedPreparingChangeID = nil
            }
        }
        do {
            let review = try await service.prepare(modelContainer: context.container,
                ownerUserID: owner, remoteID: remoteID, changeID: changeID)
            guard !Task.isCancelled, persistedPreparationID == preparationID,
                  persistedConflictChangeID == changeID, isViewActive, isCurrentModelGeneration else { return }
            if !preservingSelection { persistedSelectedFields = [] }
            reviewReturnFocus = focusedField ?? reviewReturnFocus
            persistedConflictReview = review
        } catch is CancellationError {
            // Dismissal does not change the already durable intent.
        } catch {
            guard persistedPreparationID == preparationID, persistedConflictChangeID == changeID,
                  isViewActive, isCurrentModelGeneration else { return }
            persistedResolutionError = persistedConflictErrorMessage(error)
        }
    }

    private func resolvePersistedConflict(_ review: PersistedCatalogConflictReview,
                                          choice: PersistedCatalogConflictChoice) {
        guard !persistedResolutionIsRunning, isCurrentModelGeneration,
              let service = conflictResolutionService else { return }
        let operationID = UUID()
        let requestedChangeID = persistedConflictChangeID
        persistedResolutionOperationID = operationID
        persistedResolutionIsRunning = true
        persistedResolutionError = nil
        let container = context.container
        Task { @MainActor in
            defer {
                if persistedResolutionOperationID == operationID {
                    persistedResolutionIsRunning = false
                    persistedResolutionOperationID = nil
                    if persistedConflictChangeID != requestedChangeID, persistedConflictChangeID != nil,
                       isViewActive, isCurrentModelGeneration {
                        Task { await preparePersistedConflictReview() }
                    }
                }
            }
            do {
                let outcome = try await service.resolve(review: review, choice: choice, modelContainer: container)
                guard persistedResolutionOperationID == operationID, persistedConflictChangeID == requestedChangeID,
                      isViewActive, isCurrentModelGeneration else { return }
                switch outcome {
                case .adoptedRemote: persistedResolutionMessage = L("product.resolution.adopted_remote")
                case .adoptedRemoteTombstone: persistedResolutionMessage = L("product.resolution.adopted_tombstone")
                case .successorPending: persistedResolutionMessage = L("product.resolution.successor_pending")
                }
                persistedResolvedChangeID = requestedChangeID
                persistedConflictReview = nil
                // The saved revision's decision does not overwrite an unsaved draft.
            } catch {
                guard persistedResolutionOperationID == operationID, persistedConflictChangeID == requestedChangeID,
                      isViewActive, isCurrentModelGeneration else { return }
                persistedResolutionError = persistedConflictErrorMessage(error)
            }
        }
    }

    private func persistedConflictErrorMessage(_ error: Error) -> String {
        guard let error = error as? CatalogConflictResolutionError else {
            return L("product.resolution.error")
        }
        switch error {
        case .destructiveDependencies: return L("product.resolution.linked_history")
        case .relationshipUnavailable: return L("product.resolution.relationship_unavailable")
        case .ownerBusy: return L("product.resolution.owner_busy")
        case .reconciliationRequired: return L("product.resolution.unconfirmed")
        case .generationChanged: return L("product.resolution.invalidated")
        case .remoteChanged, .localChanged: return L("product.resolution.changed_again")
        default: return L("product.resolution.error")
        }
    }

    private func createPriceHistoryIfNeeded(
        for product: Product,
        oldPurchase: Double?,
        newPurchase: Double?,
        oldRetail: Double?,
        newRetail: Double?,
        context: ModelContext
    ) -> [ProductPrice] {
        let now = Date()
        var created: [ProductPrice] = []

        if let newPurchase, newPurchase != oldPurchase {
            let history = ProductPrice(
                type: .purchase,
                price: newPurchase,
                effectiveAt: now,
                source: "EDIT_PRODUCT",
                product: product
            )
            context.insert(history)
            created.append(history)
        }

        if let newRetail, newRetail != oldRetail {
            let history = ProductPrice(
                type: .retail,
                price: newRetail,
                effectiveAt: now,
                source: "EDIT_PRODUCT",
                product: product
            )
            context.insert(history)
            created.append(history)
        }
        return created
    }

    private enum NumericInputKind {
        case price
        case quantity
    }

    private func numericInputError(
        _ result: CLNumericInputResult,
        kind: NumericInputKind
    ) -> String? {
        switch result {
        case .empty, .value:
            return nil
        case .invalid:
            return L(
                kind == .price
                    ? "product.validation.price_invalid"
                    : "product.validation.quantity_invalid"
            )
        case .negative:
            return L(
                kind == .price
                    ? "product.validation.price_negative"
                    : "product.validation.quantity_negative"
            )
        }
    }

    @ViewBuilder
    private func numericFieldError(
        _ message: String?,
        fieldKey: String,
        identifier: String
    ) -> some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(Text("\(L(fieldKey)): \(message)"))
                .accessibilityIdentifier(identifier)
        }
    }

    nonisolated private static func optionalRaw(_ text: String) -> String? {
        text.isEmpty ? nil : text
    }

    nonisolated private static func makeDraft(_ product: Product) -> ProductDraft {
        ProductDraft(
            barcode: product.barcode,
            itemNumber: product.itemNumber,
            productName: product.productName,
            secondProductName: product.secondProductName,
            purchasePrice: product.purchasePrice,
            retailPrice: product.retailPrice,
            stockQuantity: product.stockQuantity,
            supplierName: product.supplier?.name,
            categoryName: product.category?.name
        )
    }

    nonisolated private static func changedFieldNames(
        old: ProductDraft,
        new: ProductDraft
    ) -> [String] {
        ProductDraftReviewFields.changed(from: old, to: new)
    }

    private static let createChangedFields = [
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
}
