import Foundation

nonisolated enum SyncPreviewClassification: String, Sendable {
    case newProduct
    case linkOnly
    case updateCandidate
    case conflict
    case unchanged
    case remoteTombstone
    case warning
}

nonisolated enum SyncPreviewOutcome: String, Sendable {
    case success
    case partial
}

nonisolated enum SyncPreviewFieldKey: String, Sendable {
    case barcode
    case itemNumber
    case productName
    case secondProductName
    case purchasePrice
    case retailPrice
    case stockQuantity
    case supplierName
    case categoryName
    case priceHistory
}

nonisolated enum SyncPreviewConflictKind: String, Sendable {
    case remoteDuplicateBarcode
    case remoteEmptyBarcode
    case remoteIDConflict = "remoteIdConflict"
    case missingRemoteReference
    case missingRemoteSupplier
    case missingRemoteCategory
    case localDuplicateBarcode
}

nonisolated enum SyncPreviewWarningCode: String, Sendable {
    case sourceError
    case remoteEmptyBarcode
    case remoteDuplicateName
    case localDuplicateName
    case priceHistoryIncomplete
    case priceHistoryPagedApplyRequired
    case priceHistoryUnmatchedProduct
    case priceHistoryInvalidType
    case priceHistoryInvalidEffectiveAt
}

nonisolated struct SyncPreview: Sendable {
    let generatedAt: Date
    let outcome: SyncPreviewOutcome
    let remoteCounts: RemoteInventorySnapshotCounts
    let localCounts: LocalInventorySnapshotCounts
    let newProducts: [SyncPreviewProductSummary]
    let updateCandidates: [SyncPreviewProductSummary]
    let remoteSupplierLookups: [SyncPreviewLookupSummary]
    let remoteCategoryLookups: [SyncPreviewLookupSummary]
    let conflicts: [SyncPreviewConflict]
    let unchangedProducts: [SyncPreviewProductSummary]
    let remoteTombstones: [SyncPreviewProductSummary]
    let supplierDiffs: [SyncPreviewFieldChange]
    let categoryDiffs: [SyncPreviewFieldChange]
    let priceHistoryDiffs: [SyncPreviewFieldChange]
    let warnings: [SyncPreviewWarning]
    let metrics: [SyncPreviewMetric]
    let sourceErrors: [SyncPreviewWarning]
    let remoteProductIDs: Set<UUID>
    let remoteSupplierIDs: Set<UUID>
    let remoteCategoryIDs: Set<UUID>

    init(
        generatedAt: Date,
        outcome: SyncPreviewOutcome,
        remoteCounts: RemoteInventorySnapshotCounts,
        localCounts: LocalInventorySnapshotCounts,
        newProducts: [SyncPreviewProductSummary],
        updateCandidates: [SyncPreviewProductSummary],
        remoteSupplierLookups: [SyncPreviewLookupSummary] = [],
        remoteCategoryLookups: [SyncPreviewLookupSummary] = [],
        conflicts: [SyncPreviewConflict],
        unchangedProducts: [SyncPreviewProductSummary],
        remoteTombstones: [SyncPreviewProductSummary],
        supplierDiffs: [SyncPreviewFieldChange],
        categoryDiffs: [SyncPreviewFieldChange],
        priceHistoryDiffs: [SyncPreviewFieldChange],
        warnings: [SyncPreviewWarning],
        metrics: [SyncPreviewMetric],
        sourceErrors: [SyncPreviewWarning],
        remoteProductIDs: Set<UUID>? = nil,
        remoteSupplierIDs: Set<UUID> = [],
        remoteCategoryIDs: Set<UUID> = []
    ) {
        self.generatedAt = generatedAt
        self.outcome = outcome
        self.remoteCounts = remoteCounts
        self.localCounts = localCounts
        self.newProducts = newProducts
        self.updateCandidates = updateCandidates
        self.remoteSupplierLookups = remoteSupplierLookups
        self.remoteCategoryLookups = remoteCategoryLookups
        self.conflicts = conflicts
        self.unchangedProducts = unchangedProducts
        self.remoteTombstones = remoteTombstones
        self.supplierDiffs = supplierDiffs
        self.categoryDiffs = categoryDiffs
        self.priceHistoryDiffs = priceHistoryDiffs
        self.warnings = warnings
        self.metrics = metrics
        self.sourceErrors = sourceErrors
        self.remoteProductIDs = remoteProductIDs ?? Set(
            (newProducts + updateCandidates + unchangedProducts + remoteTombstones)
                .compactMap(\.remoteID)
        )
        self.remoteSupplierIDs = remoteSupplierIDs
        self.remoteCategoryIDs = remoteCategoryIDs
    }
}

nonisolated struct SyncPreviewLookupSummary: Identifiable, Sendable, Equatable {
    let id: UUID
    let remoteID: UUID
    let displayName: String
    let remoteUpdatedAt: Date?
    let remoteDeletedAt: Date?

    init(
        id: UUID = UUID(),
        remoteID: UUID,
        displayName: String,
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil
    ) {
        self.id = id
        self.remoteID = remoteID
        self.displayName = displayName
        self.remoteUpdatedAt = remoteUpdatedAt
        self.remoteDeletedAt = remoteDeletedAt
    }
}

nonisolated struct SyncPreviewMetric: Identifiable, Sendable {
    let id: String
    let labelKey: String
    let value: String
}

nonisolated struct SyncPreviewConflict: Identifiable, Sendable {
    let id: UUID
    let kind: SyncPreviewConflictKind
    let barcodeOrKey: String?
    let detail: String?
    let relatedRemoteIDs: [UUID]
    let hintKey: String?

    init(
        id: UUID = UUID(),
        kind: SyncPreviewConflictKind,
        barcodeOrKey: String?,
        detail: String? = nil,
        relatedRemoteIDs: [UUID] = [],
        hintKey: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.barcodeOrKey = barcodeOrKey
        self.detail = detail
        self.relatedRemoteIDs = relatedRemoteIDs
        self.hintKey = hintKey
    }
}

nonisolated struct SyncPreviewFieldChange: Identifiable, Sendable {
    let id: UUID
    let fieldKey: SyncPreviewFieldKey
    let barcodeOrKey: String?
    let remoteDisplay: String?
    let localDisplay: String?
    let normalizedEqual: Bool

    init(
        id: UUID = UUID(),
        fieldKey: SyncPreviewFieldKey,
        barcodeOrKey: String?,
        remoteDisplay: String?,
        localDisplay: String?,
        normalizedEqual: Bool = false
    ) {
        self.id = id
        self.fieldKey = fieldKey
        self.barcodeOrKey = barcodeOrKey
        self.remoteDisplay = remoteDisplay
        self.localDisplay = localDisplay
        self.normalizedEqual = normalizedEqual
    }
}

nonisolated struct SyncPreviewWarning: Identifiable, Sendable {
    let id: UUID
    let code: SyncPreviewWarningCode
    let barcodeOrKey: String?
    let detail: String?
    let relatedKey: String?

    init(
        id: UUID = UUID(),
        code: SyncPreviewWarningCode,
        barcodeOrKey: String? = nil,
        detail: String? = nil,
        relatedKey: String? = nil
    ) {
        self.id = id
        self.code = code
        self.barcodeOrKey = barcodeOrKey
        self.detail = detail
        self.relatedKey = relatedKey
    }

    var messageKey: String {
        "options.supabase.preview.warning.\(code.rawValue)"
    }
}

nonisolated struct SyncPreviewProductSummary: Identifiable, Sendable {
    let id: UUID
    let classification: SyncPreviewClassification
    let remoteID: UUID?
    let barcode: String?
    let productName: String?
    let detail: String?
    let fieldChanges: [SyncPreviewFieldChange]
    let applyPayload: SyncPreviewProductApplyPayload?

    init(
        id: UUID = UUID(),
        classification: SyncPreviewClassification,
        remoteID: UUID?,
        barcode: String?,
        productName: String?,
        detail: String? = nil,
        fieldChanges: [SyncPreviewFieldChange] = [],
        applyPayload: SyncPreviewProductApplyPayload? = nil
    ) {
        self.id = id
        self.classification = classification
        self.remoteID = remoteID
        self.barcode = barcode
        self.productName = productName
        self.detail = detail
        self.fieldChanges = fieldChanges
        self.applyPayload = applyPayload
    }

    var sortKey: String {
        SupabasePullPreviewNormalizer.normalizedBarcode(barcode)
            ?? SupabasePullPreviewNormalizer.normalizedLookupName(productName)
            ?? remoteID?.uuidString.lowercased()
            ?? id.uuidString.lowercased()
    }
}

nonisolated struct SyncPreviewProductApplyPayload: Sendable, Equatable {
    let remoteID: UUID
    let remoteUpdatedAt: Date?
    let remoteDeletedAt: Date?
    let barcode: String?
    let itemNumber: String?
    let productName: String?
    let secondProductName: String?
    let purchasePrice: Double?
    let retailPrice: Double?
    let stockQuantity: Double?
    let supplierName: String?
    let supplierRemoteID: UUID?
    let supplierRemoteUpdatedAt: Date?
    let supplierRemoteDeletedAt: Date?
    let categoryName: String?
    let categoryRemoteID: UUID?
    let categoryRemoteUpdatedAt: Date?
    let categoryRemoteDeletedAt: Date?

    init(
        remoteID: UUID,
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil,
        barcode: String?,
        itemNumber: String? = nil,
        productName: String? = nil,
        secondProductName: String? = nil,
        purchasePrice: Double? = nil,
        retailPrice: Double? = nil,
        stockQuantity: Double? = nil,
        supplierName: String? = nil,
        supplierRemoteID: UUID? = nil,
        supplierRemoteUpdatedAt: Date? = nil,
        supplierRemoteDeletedAt: Date? = nil,
        categoryName: String? = nil,
        categoryRemoteID: UUID? = nil,
        categoryRemoteUpdatedAt: Date? = nil,
        categoryRemoteDeletedAt: Date? = nil
    ) {
        self.remoteID = remoteID
        self.remoteUpdatedAt = remoteUpdatedAt
        self.remoteDeletedAt = remoteDeletedAt
        self.barcode = barcode
        self.itemNumber = itemNumber
        self.productName = productName
        self.secondProductName = secondProductName
        self.purchasePrice = purchasePrice
        self.retailPrice = retailPrice
        self.stockQuantity = stockQuantity
        self.supplierName = supplierName
        self.supplierRemoteID = supplierRemoteID
        self.supplierRemoteUpdatedAt = supplierRemoteUpdatedAt
        self.supplierRemoteDeletedAt = supplierRemoteDeletedAt
        self.categoryName = categoryName
        self.categoryRemoteID = categoryRemoteID
        self.categoryRemoteUpdatedAt = categoryRemoteUpdatedAt
        self.categoryRemoteDeletedAt = categoryRemoteDeletedAt
    }
}

nonisolated struct RemoteInventorySnapshotCounts: Sendable {
    let products: Int
    let activeProducts: Int
    let tombstonedProducts: Int
    let suppliers: Int
    let categories: Int
    let productPrices: Int
}

nonisolated struct LocalInventorySnapshotCounts: Sendable {
    let products: Int
    let suppliers: Int
    let categories: Int
    let productPrices: Int
    let linkedProducts: Int
    let linkedSuppliers: Int
    let linkedCategories: Int

    init(
        products: Int,
        suppliers: Int,
        categories: Int,
        productPrices: Int,
        linkedProducts: Int = 0,
        linkedSuppliers: Int = 0,
        linkedCategories: Int = 0
    ) {
        self.products = products
        self.suppliers = suppliers
        self.categories = categories
        self.productPrices = productPrices
        self.linkedProducts = linkedProducts
        self.linkedSuppliers = linkedSuppliers
        self.linkedCategories = linkedCategories
    }
}

nonisolated struct RemoteInventorySnapshot: Sendable {
    let products: [RemoteInventoryProductRow]
    let suppliersByID: [UUID: RemoteInventorySupplierRow]
    let categoriesByID: [UUID: RemoteInventoryCategoryRow]
    let productPrices: [RemoteInventoryProductPriceRow]
    let activeProducts: [RemoteInventoryProductRow]
    let tombstonedProducts: [RemoteInventoryProductRow]
    let duplicateBarcodeGroups: [String: [RemoteInventoryProductRow]]
    let sourceErrors: [SyncPreviewWarning]
    let previewWarnings: [SyncPreviewWarning]
    let counts: RemoteInventorySnapshotCounts

    init(
        products: [RemoteInventoryProductRow],
        suppliers: [RemoteInventorySupplierRow],
        categories: [RemoteInventoryCategoryRow],
        productPrices: [RemoteInventoryProductPriceRow],
        sourceErrors: [SyncPreviewWarning] = [],
        previewWarnings: [SyncPreviewWarning] = []
    ) {
        self.products = products
        self.suppliersByID = Dictionary(uniqueKeysWithValues: suppliers.map { ($0.id, $0) })
        self.categoriesByID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        self.productPrices = productPrices
        self.activeProducts = products.filter { SupabasePullPreviewNormalizer.semanticString($0.deletedAt) == nil }
        self.tombstonedProducts = products.filter { SupabasePullPreviewNormalizer.semanticString($0.deletedAt) != nil }

        var groups: [String: [RemoteInventoryProductRow]] = [:]
        for product in activeProducts {
            guard let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(product.barcode) else {
                continue
            }
            groups[barcode, default: []].append(product)
        }
        self.duplicateBarcodeGroups = groups.filter { $0.value.count > 1 }
        self.sourceErrors = sourceErrors
        self.previewWarnings = previewWarnings
        self.counts = RemoteInventorySnapshotCounts(
            products: products.count,
            activeProducts: activeProducts.count,
            tombstonedProducts: tombstonedProducts.count,
            suppliers: suppliers.count,
            categories: categories.count,
            productPrices: productPrices.count
        )
    }

    func hasSourceError(for relatedKey: String) -> Bool {
        sourceErrors.contains { $0.relatedKey == relatedKey }
    }
}

nonisolated struct LocalInventorySnapshot: Sendable {
    let productsByBarcode: [String: LocalProductSnapshot]
    let productsByRemoteID: [UUID: LocalProductSnapshot]
    let suppliersByNormalizedName: [String: String]
    let supplierRemoteIDByNormalizedName: [String: UUID]
    let suppliersByRemoteID: [UUID: LocalLookupSnapshot]
    let categoriesByNormalizedName: [String: String]
    let categoryRemoteIDByNormalizedName: [String: UUID]
    let categoriesByRemoteID: [UUID: LocalLookupSnapshot]
    let priceHistoryByLogicalKey: [PriceHistoryLogicalKey: LocalPriceSnapshot]
    let counts: LocalInventorySnapshotCounts
    let duplicateProductBarcodes: [String]
    let duplicateProductRemoteIDs: [UUID]
    let duplicateSupplierNames: [String]
    let duplicateSupplierRemoteIDs: [UUID]
    let duplicateCategoryNames: [String]
    let duplicateCategoryRemoteIDs: [UUID]
    let invalidProductBarcodes: Int
    let invalidSupplierNames: Int
    let invalidCategoryNames: Int

    init(
        productsByBarcode: [String: LocalProductSnapshot],
        productsByRemoteID: [UUID: LocalProductSnapshot] = [:],
        suppliersByNormalizedName: [String: String],
        supplierRemoteIDByNormalizedName: [String: UUID] = [:],
        suppliersByRemoteID: [UUID: LocalLookupSnapshot] = [:],
        categoriesByNormalizedName: [String: String],
        categoryRemoteIDByNormalizedName: [String: UUID] = [:],
        categoriesByRemoteID: [UUID: LocalLookupSnapshot] = [:],
        priceHistoryByLogicalKey: [PriceHistoryLogicalKey: LocalPriceSnapshot],
        counts: LocalInventorySnapshotCounts,
        duplicateProductBarcodes: [String],
        duplicateProductRemoteIDs: [UUID] = [],
        duplicateSupplierNames: [String],
        duplicateSupplierRemoteIDs: [UUID] = [],
        duplicateCategoryNames: [String],
        duplicateCategoryRemoteIDs: [UUID] = [],
        invalidProductBarcodes: Int = 0,
        invalidSupplierNames: Int = 0,
        invalidCategoryNames: Int = 0
    ) {
        self.productsByBarcode = productsByBarcode
        self.productsByRemoteID = productsByRemoteID
        self.suppliersByNormalizedName = suppliersByNormalizedName
        self.supplierRemoteIDByNormalizedName = supplierRemoteIDByNormalizedName
        self.suppliersByRemoteID = suppliersByRemoteID
        self.categoriesByNormalizedName = categoriesByNormalizedName
        self.categoryRemoteIDByNormalizedName = categoryRemoteIDByNormalizedName
        self.categoriesByRemoteID = categoriesByRemoteID
        self.priceHistoryByLogicalKey = priceHistoryByLogicalKey
        self.counts = counts
        self.duplicateProductBarcodes = duplicateProductBarcodes
        self.duplicateProductRemoteIDs = duplicateProductRemoteIDs
        self.duplicateSupplierNames = duplicateSupplierNames
        self.duplicateSupplierRemoteIDs = duplicateSupplierRemoteIDs
        self.duplicateCategoryNames = duplicateCategoryNames
        self.duplicateCategoryRemoteIDs = duplicateCategoryRemoteIDs
        self.invalidProductBarcodes = invalidProductBarcodes
        self.invalidSupplierNames = invalidSupplierNames
        self.invalidCategoryNames = invalidCategoryNames
    }
}

nonisolated struct LocalProductSnapshot: Sendable {
    let barcode: String
    let remoteID: UUID?
    let remoteUpdatedAt: Date?
    let remoteDeletedAt: Date?
    let itemNumber: String?
    let productName: String?
    let secondProductName: String?
    let purchasePrice: Double?
    let retailPrice: Double?
    let stockQuantity: Double?
    let supplierName: String?
    let categoryName: String?

    init(
        barcode: String,
        remoteID: UUID? = nil,
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil,
        itemNumber: String? = nil,
        productName: String? = nil,
        secondProductName: String? = nil,
        purchasePrice: Double? = nil,
        retailPrice: Double? = nil,
        stockQuantity: Double? = nil,
        supplierName: String? = nil,
        categoryName: String? = nil
    ) {
        self.barcode = barcode
        self.remoteID = remoteID
        self.remoteUpdatedAt = remoteUpdatedAt
        self.remoteDeletedAt = remoteDeletedAt
        self.itemNumber = itemNumber
        self.productName = productName
        self.secondProductName = secondProductName
        self.purchasePrice = purchasePrice
        self.retailPrice = retailPrice
        self.stockQuantity = stockQuantity
        self.supplierName = supplierName
        self.categoryName = categoryName
    }
}

nonisolated struct LocalLookupSnapshot: Sendable {
    let name: String
    let remoteID: UUID?
    let remoteUpdatedAt: Date?
    let remoteDeletedAt: Date?
}

nonisolated struct LocalPriceSnapshot: Sendable {
    let barcode: String
    let type: String
    let price: Double
    let effectiveAt: String
    let source: String?
    let note: String?
    let createdAt: String
}

nonisolated struct PriceHistoryLogicalKey: Hashable, Sendable {
    let barcode: String
    let type: String
    let effectiveAt: String
}

nonisolated enum SupabasePullPreviewError: Error, Sendable {
    case service(SupabaseInventoryServiceError)
    case localSnapshot(message: String?)
    case unknown(message: String?)

    var safeDiagnosticDetail: String? {
        switch self {
        case .service(let error):
            return error.safeDiagnosticDetail
        case .localSnapshot(let message), .unknown(let message):
            return SupabaseInventoryServiceError.sanitizedDiagnosticDetail(message)
        }
    }
}

nonisolated enum SupabasePullPreviewViewState: Sendable {
    case idle
    case loading(progressMessage: String?)
    case success(SyncPreview)
    case partial(SyncPreview, warnings: [SyncPreviewWarning], sourceErrors: [SyncPreviewWarning])
    case failed(SupabasePullPreviewError)
}

nonisolated enum SupabasePullPreviewNormalizer {
    static let doubleTolerance = 0.001

    static func semanticString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func normalizedBarcode(_ value: String?) -> String? {
        semanticString(value)
    }

    static func normalizedLookupName(_ value: String?) -> String? {
        semanticString(value)?.lowercased()
    }

    static func stringsEqual(_ lhs: String?, _ rhs: String?) -> Bool {
        semanticString(lhs) == semanticString(rhs)
    }

    static func lookupNamesEqual(_ lhs: String?, _ rhs: String?) -> Bool {
        normalizedLookupName(lhs) == normalizedLookupName(rhs)
    }

    static func doublesEqual(_ lhs: Double?, _ rhs: Double?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (.some(left), .some(right)):
            return abs(left - right) <= doubleTolerance
        default:
            return false
        }
    }

    static func normalizedPriceType(_ value: String?) -> String? {
        guard let normalized = semanticString(value)?.lowercased() else { return nil }

        switch normalized {
        case "purchase":
            return "purchase"
        case "retail":
            return "retail"
        default:
            return nil
        }
    }

    static func normalizedEffectiveAt(_ value: String?) -> String? {
        semanticString(value)
    }

    static func decimalDisplay(_ value: Double?) -> String? {
        guard let value else { return nil }
        return String(format: "%.3f", value)
    }
}
