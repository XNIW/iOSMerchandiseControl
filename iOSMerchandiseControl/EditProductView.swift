import PhotosUI
import SwiftUI
import SwiftData
import UIKit

struct EditProductView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    @EnvironmentObject private var shopContextStore: ShopContextStore
    @EnvironmentObject private var productImageStore: ProductImageStore

    let existingProduct: Product?
    let pendingOwnerUserID: UUID?
    let isCameraAvailable: Bool
    private let initialDraft: ProductDraft?

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

    init(
        product: Product? = nil,
        initialBarcode: String? = nil,
        pendingOwnerUserID: UUID? = nil,
        isCameraAvailable: Bool = UIImagePickerController.isSourceTypeAvailable(.camera)
    ) {
        self.existingProduct = product
        self.pendingOwnerUserID = pendingOwnerUserID
        self.isCameraAvailable = isCameraAvailable
        self.initialDraft = product.map(Self.makeDraft)

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
        Form {
            if let validationMessage {
                Section {
                    Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            productImageSection

            Section(L("product.section.main")) {
                TextField(L("product.field.barcode"), text: $barcode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .submitLabel(.next)
                    .accessibilityLabel(Text(L("product.field.barcode")))

                TextField(L("product.field.item_number"), text: $itemNumber)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .accessibilityLabel(Text(L("product.field.item_number")))

                TextField(L("product.field.name"), text: $name)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .accessibilityLabel(Text(L("product.field.name")))

                TextField(L("product.field.second_name"), text: $secondName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .accessibilityLabel(Text(L("product.field.second_name")))
            }

            Section(L("product.section.warehouse")) {
                TextField(L("product.field.stock_quantity"), text: $stockQuantity)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                    .accessibilityLabel(Text(L("product.field.stock_quantity")))
            }

            Section(L("product.section.prices")) {
                TextField(L("product.field.purchase_price"), text: $purchasePrice)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                    .accessibilityLabel(Text(L("product.field.purchase_price")))

                TextField(L("product.field.retail_price"), text: $retailPrice)
                    .keyboardType(.decimalPad)
                    .monospacedDigit()
                    .accessibilityLabel(Text(L("product.field.retail_price")))

                if let existingProduct {
                    Button {
                        productForHistory = existingProduct
                    } label: {
                        Label(L("product.history.action.open"), systemImage: "clock.arrow.circlepath")
                    }
                }
            }

            Section(L("product.section.supplier")) {
                TextField(L("product.field.supplier_name"), text: $supplierName)
                    .textInputAutocapitalization(.words)
                    .accessibilityLabel(Text(L("product.field.supplier_name")))

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
                TextField(L("product.field.category_name"), text: $categoryName)
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
        }
        .navigationTitle(existingProduct == nil ? L("product.title.new") : L("product.title.edit"))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L("common.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L("common.save")) { save() }
                    .fontWeight(.semibold)
            }
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
        .onAppear { isViewActive = true }
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

    @ViewBuilder
    private var productImageSection: some View {
        Section(L("product.image.section")) {
            if let product = existingProduct,
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
        guard supabaseAuthViewModel.isSignedIn,
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

    private var canWriteProductImage: Bool {
        guard productImageStore.isAvailable,
              existingProduct?.remoteID != nil,
              imageScope != nil,
              shopContextStore.context.syncAllowed,
              let selectedShop = shopContextStore.context.selectedShop else {
            return false
        }
        return selectedShop.canWrite && selectedShop.isValidProductImageSelection
    }

    private var isImageBusy: Bool {
        if isImportingSelectedImage { return true }
        guard let productID = existingProduct?.remoteID else { return false }
        switch productImageStore.operationStage(productID: productID) {
        case .processing, .uploadingMain, .uploadingThumb, .finalizing, .removing:
            return true
        case .idle, .completed, .cancelled, .failed:
            return false
        }
    }

    private var isImageOperationCancellable: Bool {
        if isImportingSelectedImage { return true }
        guard let productID = existingProduct?.remoteID else { return false }
        return productImageStore.operationStage(productID: productID).allowsCancellation
    }

    private var imageProgressLabel: String {
        if isImportingSelectedImage { return L("product.image.importing") }
        guard let productID = existingProduct?.remoteID else { return L("product.image.processing") }
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
            productID: existingProduct?.remoteID
        )
    }

    private func uploadPendingImage(operationID: UUID) async {
        guard imageOperationID == operationID,
              canWriteProductImage,
              let fileURL = pendingImageURL,
              let scope = imageScope,
              let product = existingProduct,
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
                  existingProduct?.remoteID == productID else { return }
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
              let product = existingProduct,
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
                  existingProduct?.remoteID == productID else { return }
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
        if let productID = existingProduct?.remoteID {
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
           let productID = existingProduct?.remoteID {
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
        guard !barcode.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = L("product.validation.barcode_required")
            return
        }

        let purchase = Self.parseDouble(from: purchasePrice)
        let retail = Self.parseDouble(from: retailPrice)
        let stock = Self.parseDouble(from: stockQuantity)
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
                if let createdSupplier {
                    try accumulator.recordSupplierChange(
                        supplier: createdSupplier,
                        operation: .create,
                        origin: .manualCatalogSave
                    )
                }
                if let createdCategory {
                    try accumulator.recordCategoryChange(
                        category: createdCategory,
                        operation: .create,
                        origin: .manualCatalogSave
                    )
                }
                if operation == .create || !userChangedFields.isEmpty {
                    try accumulator.recordProductChange(
                        product: target,
                        operation: operation,
                        origin: .manualCatalogSave,
                        changedFields: userChangedFields,
                        baselineFingerprintHash: baselineFingerprintHash
                    )
                }
                try priceChanges.forEach {
                    try accumulator.recordProductPriceChange(price: $0, origin: .productPriceSave)
                }
                try freshContext.save()
            }
            dismiss()
        } catch {
            validationMessage = L("product.validation.save_failed")
            #if DEBUG
            print("Errore durante il salvataggio locale.")
            #endif
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

    private static func parseDouble(from text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else { return nil }
        return Double(normalized)
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
        var fields = ProductUpdateDraft.computeChangedFields(old: old, new: new).map(\.rawValue)
        if old.barcode != new.barcode {
            fields.insert("barcode", at: 0)
        }
        return fields
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
