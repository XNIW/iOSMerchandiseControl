import PhotosUI
import SwiftUI
import SwiftData
import UIKit

struct EditProductView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    @EnvironmentObject private var shopContextStore: ShopContextStore
    @EnvironmentObject private var productImageStore: ProductImageStore

    let existingProduct: Product?
    let pendingOwnerUserID: UUID?

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
    @State private var imageOperationTask: Task<Void, Never>?

    init(product: Product? = nil, initialBarcode: String? = nil, pendingOwnerUserID: UUID? = nil) {
        self.existingProduct = product
        self.pendingOwnerUserID = pendingOwnerUserID

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
        barcode.trimmingCharacters(in: .whitespacesAndNewlines)
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
            startImageOperation {
                do {
                    guard let transfer = try await item.loadTransferable(type: ProductImageTransferFile.self) else {
                        imageMessage = L("product.image.error.input")
                        return
                    }
                    replacePendingImageURL(with: transfer.fileURL)
                    await uploadPendingImage()
                } catch is CancellationError {
                    imageMessage = L("product.image.cancelled")
                } catch {
                    imageMessage = L("product.image.error.input")
                }
                selectedImageItem = nil
            }
        }
        .task(id: imageScope) {
            productImageStore.activate(scope: imageScope)
        }
        .onAppear { isViewActive = true }
        .onDisappear {
            isViewActive = false
            cancelImageOperation()
            clearPendingImageURL()
        }
        .sheet(isPresented: $showingCamera) {
            ProductImageCameraPicker(
                onCapture: { url in
                    showingCamera = false
                    replacePendingImageURL(with: url)
                    startImageOperation { await uploadPendingImage() }
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
                startImageOperation { await removeCurrentImage() }
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
                ProductImageRemoteView(
                    scope: imageScope,
                    productID: productID,
                    versionID: product.primaryImageVersionID,
                    variant: .main
                )
                .frame(maxWidth: .infinity)
                .frame(height: 220)

                if isImageBusy {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(imageProgressLabel)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L("product.image.cancel"), role: .cancel) {
                            cancelImageOperation()
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
                    HStack {
                        PhotosPicker(selection: $selectedImageItem, matching: .images) {
                            Label(L("product.image.library"), systemImage: "photo.on.rectangle")
                        }
                        .disabled(isImageBusy)

                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button {
                                showingCamera = true
                            } label: {
                                Label(L("product.image.camera"), systemImage: "camera")
                            }
                            .disabled(isImageBusy)
                        }
                    }

                    if product.primaryImageVersionID != nil {
                        Button(L("product.image.remove"), role: .destructive) {
                            showingRemoveImageConfirmation = true
                        }
                        .disabled(isImageBusy)
                    }

                    if pendingImageURL != nil,
                       productImageStore.operationStage(productID: productID) == .failed {
                        HStack {
                            Button(L("product.image.retry")) {
                                startImageOperation { await uploadPendingImage() }
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

    private var imageScope: ProductImageScope? {
        guard supabaseAuthViewModel.isSignedIn,
              let accountID = supabaseAuthViewModel.sessionInfo?.userID,
              let selectedShop = shopContextStore.context.selectedShop,
              selectedShop.isValidProductImageSelection else {
            return nil
        }
        return ProductImageScope(accountID: accountID, shopID: selectedShop.shopID)
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
        guard let productID = existingProduct?.remoteID else { return false }
        switch productImageStore.operationStage(productID: productID) {
        case .processing, .uploadingMain, .uploadingThumb, .finalizing, .removing:
            return true
        case .idle, .completed, .cancelled, .failed:
            return false
        }
    }

    private var imageProgressLabel: String {
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

    private func uploadPendingImage() async {
        guard canWriteProductImage,
              let fileURL = pendingImageURL,
              let scope = imageScope,
              let product = existingProduct,
              let productID = product.remoteID else {
            imageMessage = L("product.image.error.context")
            return
        }
        imageMessage = nil
        do {
            let result = try await productImageStore.upload(
                fileURL: fileURL,
                scope: scope,
                productID: productID,
                previousVersionID: product.primaryImageVersionID
            )
            product.primaryImageVersionID = result.versionID
            if let imageUpdatedAt = result.imageUpdatedAt {
                product.primaryImageUpdatedAt = imageUpdatedAt
            }
            do {
                try context.save()
                imageMessage = String(
                    format: L("product.image.success.metrics"),
                    result.metrics.mainBytes / 1_024,
                    result.metrics.thumbBytes / 1_024,
                    result.metrics.elapsedMilliseconds
                )
            } catch {
                context.rollback()
                imageMessage = L("product.image.error.local_refresh")
            }
            clearPendingImageURL()
        } catch is CancellationError {
            imageMessage = L("product.image.cancelled")
            clearPendingImageURL()
        } catch {
            imageMessage = L("product.image.error.upload")
            if !isViewActive {
                clearPendingImageURL()
            }
        }
    }

    private func removeCurrentImage() async {
        guard canWriteProductImage,
              let scope = imageScope,
              let product = existingProduct,
              let productID = product.remoteID,
              let versionID = product.primaryImageVersionID else {
            return
        }
        imageMessage = nil
        do {
            let result = try await productImageStore.remove(
                scope: scope,
                productID: productID,
                versionID: versionID
            )
            product.primaryImageVersionID = nil
            product.primaryImageUpdatedAt = result.imageUpdatedAt
            do {
                try context.save()
                imageMessage = L("product.image.remove.success")
            } catch {
                context.rollback()
                imageMessage = L("product.image.error.local_refresh")
            }
        } catch is CancellationError {
            imageMessage = L("product.image.cancelled")
        } catch {
            imageMessage = L("product.image.error.remove")
        }
    }

    private func startImageOperation(_ operation: @escaping @MainActor () async -> Void) {
        imageOperationTask?.cancel()
        imageOperationTask = Task { @MainActor in
            await operation()
            imageOperationTask = nil
        }
    }

    private func cancelImageOperation() {
        guard let imageOperationTask else { return }
        imageOperationTask.cancel()
        self.imageOperationTask = nil
        if let productID = existingProduct?.remoteID {
            productImageStore.cancelOperation(productID: productID)
        }
        imageMessage = L("product.image.cancelled")
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
        guard !trimmedBarcode.isEmpty else {
            validationMessage = L("product.validation.barcode_required")
            return
        }

        let purchase = Self.parseDouble(from: purchasePrice)
        let retail = Self.parseDouble(from: retailPrice)
        let stock = Self.parseDouble(from: stockQuantity)

        // prezzi precedenti per storico
        let oldPurchase = existingProduct?.purchasePrice
        let oldRetail = existingProduct?.retailPrice
        let oldDraft = existingProduct.map(Self.makeDraft)

        let target: Product
        let operation: LocalPendingChangeOperation
        if let existingProduct {
            target = existingProduct
            operation = .update
        } else {
            target = Product(barcode: barcode)
            context.insert(target)
            operation = .create
        }

        target.barcode = trimmedBarcode
        target.itemNumber = itemNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : itemNumber
        target.productName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name
        target.secondProductName = secondName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : secondName
        target.purchasePrice = purchase
        target.retailPrice = retail
        target.stockQuantity = stock

        let trimmedSupplier = supplierName.trimmingCharacters(in: .whitespacesAndNewlines)
        var createdSupplier: Supplier?
        if trimmedSupplier.isEmpty {
            target.supplier = nil
        } else if let existing = suppliers.first(where: {
            $0.name.compare(trimmedSupplier, options: [.caseInsensitive]) == .orderedSame
        }) {
            target.supplier = existing
        } else {
            let newSupplier = Supplier(name: trimmedSupplier)
            context.insert(newSupplier)
            target.supplier = newSupplier
            createdSupplier = newSupplier
        }

        let trimmedCategory = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        var createdCategory: ProductCategory?
        if trimmedCategory.isEmpty {
            target.category = nil
        } else if let existing = categories.first(where: {
            $0.name.compare(trimmedCategory, options: [.caseInsensitive]) == .orderedSame
        }) {
            target.category = existing
        } else {
            let newCategory = ProductCategory(name: trimmedCategory)
            context.insert(newCategory)
            target.category = newCategory
            createdCategory = newCategory
        }

        // storico prezzi automatico
        let priceChanges = createPriceHistoryIfNeeded(
            for: target,
            oldPurchase: oldPurchase,
            newPurchase: purchase,
            oldRetail: oldRetail,
            newRetail: retail
        )

        do {
            let accumulator = LocalPendingChangeAccumulator(
                context: context,
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
            let changedFields = operation == .create
                ? Self.createChangedFields
                : ProductUpdateDraft.computeChangedFields(
                    old: oldDraft ?? Self.makeDraft(target),
                    new: Self.makeDraft(target)
                ).map(\.rawValue)
            try accumulator.recordProductChange(
                product: target,
                operation: operation,
                origin: .manualCatalogSave,
                changedFields: changedFields,
                baselineFingerprintHash: oldDraft.map(LocalPendingChangeLogicalKey.productFingerprintHash)
            )
            try priceChanges.forEach {
                try accumulator.recordProductPriceChange(price: $0, origin: .productPriceSave)
            }
            try context.save()
            dismiss()
        } catch {
            context.rollback()
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
        newRetail: Double?
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
