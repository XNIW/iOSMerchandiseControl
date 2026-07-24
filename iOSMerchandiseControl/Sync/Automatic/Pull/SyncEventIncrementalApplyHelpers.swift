import Foundation
import SwiftData

nonisolated enum SyncEventIncrementalApplyError: Error, Equatable, Sendable {
    case dynamicPreflightRequired
}

nonisolated struct IncrementalApplyProtectedRemoteIDs: Sendable {
    var suppliers: Set<UUID> = []
    var categories: Set<UUID> = []
    var products: Set<UUID> = []
    var prices: Set<UUID> = []
    var history: Set<UUID> = []
    var logicalKeys: Set<String> = []
    var hasCappedImportMarker = false
}

nonisolated struct TargetedCatalogApplyResult: Sendable {
    var productsInserted = 0
    var productsUpdated = 0
    var productsTombstoned = 0
    var suppliersCreated = 0
    var suppliersUpdated = 0
    var categoriesCreated = 0
    var categoriesUpdated = 0

    var totalMutations: Int {
        productsInserted
            + productsUpdated
            + productsTombstoned
            + suppliersCreated
            + suppliersUpdated
            + categoriesCreated
            + categoriesUpdated
    }
}

/// Bounded, canonical index used by the incremental catalog preflight and the
/// mutation itself. Supplier/category identity is case-insensitive in the
/// backend (`lower(name)`) and whitespace is normalized at the API boundary;
/// exact SwiftData predicates therefore are not sufficient for legacy local
/// rows. Building the index once also avoids an O(remote rows x local rows)
/// scan while the account/shop lease is held.
nonisolated struct IncrementalLocalCatalogIdentityIndex {
    private(set) var suppliersByRemoteID: [UUID: [Supplier]] = [:]
    private(set) var suppliersByCanonicalName: [String: [Supplier]] = [:]
    private(set) var categoriesByRemoteID: [UUID: [ProductCategory]] = [:]
    private(set) var categoriesByCanonicalName: [String: [ProductCategory]] = [:]
    private(set) var productsByRemoteID: [UUID: [Product]] = [:]
    private(set) var productsByCanonicalBarcode: [String: [Product]] = [:]
    private var productsBySupplierRemoteID: [UUID: [Product]] = [:]
    private var productsByCategoryRemoteID: [UUID: [Product]] = [:]

    init(
        context: ModelContext,
        includeSuppliers: Bool,
        includeCategories: Bool,
        includeProducts: Bool
    ) throws {
        if includeSuppliers {
            var descriptor = FetchDescriptor<Supplier>()
            descriptor.fetchLimit = ShopSyncRecoveryLimits.maximumRows(for: .suppliers) + 1
            let suppliers = try context.fetch(descriptor)
            guard suppliers.count <= ShopSyncRecoveryLimits.maximumRows(for: .suppliers) else {
                throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: .suppliers)
            }
            for (index, supplier) in suppliers.enumerated() {
                if index.isMultiple(of: 64) { try Task.checkCancellation() }
                addSupplier(supplier)
            }
        }

        if includeCategories {
            var descriptor = FetchDescriptor<ProductCategory>()
            descriptor.fetchLimit = ShopSyncRecoveryLimits.maximumRows(for: .categories) + 1
            let categories = try context.fetch(descriptor)
            guard categories.count <= ShopSyncRecoveryLimits.maximumRows(for: .categories) else {
                throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: .categories)
            }
            for (index, category) in categories.enumerated() {
                if index.isMultiple(of: 64) { try Task.checkCancellation() }
                addCategory(category)
            }
        }

        if includeProducts {
            var descriptor = FetchDescriptor<Product>()
            descriptor.fetchLimit = ShopSyncRecoveryLimits.maximumRows(for: .products) + 1
            let products = try context.fetch(descriptor)
            guard products.count <= ShopSyncRecoveryLimits.maximumRows(for: .products) else {
                throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: .products)
            }
            for (index, product) in products.enumerated() {
                if index.isMultiple(of: 64) { try Task.checkCancellation() }
                addProduct(product)
            }
        }
    }

    func suppliers(remoteID: UUID) -> [Supplier] {
        suppliersByRemoteID[remoteID] ?? []
    }

    func suppliers(canonicalName: String) -> [Supplier] {
        suppliersByCanonicalName[canonicalName] ?? []
    }

    func categories(remoteID: UUID) -> [ProductCategory] {
        categoriesByRemoteID[remoteID] ?? []
    }

    func categories(canonicalName: String) -> [ProductCategory] {
        categoriesByCanonicalName[canonicalName] ?? []
    }

    func products(remoteID: UUID) -> [Product] {
        productsByRemoteID[remoteID] ?? []
    }

    func products(canonicalBarcode: String) -> [Product] {
        productsByCanonicalBarcode[canonicalBarcode] ?? []
    }

    func products(supplierRemoteID: UUID) -> [Product] {
        productsBySupplierRemoteID[supplierRemoteID] ?? []
    }

    func products(categoryRemoteID: UUID) -> [Product] {
        productsByCategoryRemoteID[categoryRemoteID] ?? []
    }

    mutating func detachProducts(supplierRemoteID: UUID) throws -> Int {
        let products = productsBySupplierRemoteID.removeValue(forKey: supplierRemoteID) ?? []
        for (index, product) in products.enumerated() {
            if index.isMultiple(of: 64) { try Task.checkCancellation() }
            product.supplier = nil
        }
        return products.count
    }

    mutating func detachProducts(categoryRemoteID: UUID) throws -> Int {
        let products = productsByCategoryRemoteID.removeValue(forKey: categoryRemoteID) ?? []
        for (index, product) in products.enumerated() {
            if index.isMultiple(of: 64) { try Task.checkCancellation() }
            product.category = nil
        }
        return products.count
    }

    mutating func reindexSupplier(
        _ supplier: Supplier,
        previousRemoteID: UUID?,
        previousName: String?
    ) {
        if let previousRemoteID {
            suppliersByRemoteID[previousRemoteID]?.removeAll { $0 === supplier }
            if suppliersByRemoteID[previousRemoteID]?.isEmpty == true {
                suppliersByRemoteID.removeValue(forKey: previousRemoteID)
            }
        }
        if let key = SupabasePullPreviewNormalizer.normalizedLookupName(previousName) {
            suppliersByCanonicalName[key]?.removeAll { $0 === supplier }
            if suppliersByCanonicalName[key]?.isEmpty == true {
                suppliersByCanonicalName.removeValue(forKey: key)
            }
        }
        addSupplier(supplier)
    }

    mutating func reindexCategory(
        _ category: ProductCategory,
        previousRemoteID: UUID?,
        previousName: String?
    ) {
        if let previousRemoteID {
            categoriesByRemoteID[previousRemoteID]?.removeAll { $0 === category }
            if categoriesByRemoteID[previousRemoteID]?.isEmpty == true {
                categoriesByRemoteID.removeValue(forKey: previousRemoteID)
            }
        }
        if let key = SupabasePullPreviewNormalizer.normalizedLookupName(previousName) {
            categoriesByCanonicalName[key]?.removeAll { $0 === category }
            if categoriesByCanonicalName[key]?.isEmpty == true {
                categoriesByCanonicalName.removeValue(forKey: key)
            }
        }
        addCategory(category)
    }

    mutating func reindexProduct(
        _ product: Product,
        previousRemoteID: UUID?,
        previousBarcode: String?
    ) {
        if let previousRemoteID {
            productsByRemoteID[previousRemoteID]?.removeAll { $0 === product }
            if productsByRemoteID[previousRemoteID]?.isEmpty == true {
                productsByRemoteID.removeValue(forKey: previousRemoteID)
            }
        }
        if let key = SupabasePullPreviewNormalizer.normalizedBarcode(previousBarcode) {
            productsByCanonicalBarcode[key]?.removeAll { $0 === product }
            if productsByCanonicalBarcode[key]?.isEmpty == true {
                productsByCanonicalBarcode.removeValue(forKey: key)
            }
        }
        addProduct(product)
    }

    private mutating func addSupplier(_ supplier: Supplier) {
        if let remoteID = supplier.remoteID,
           suppliersByRemoteID[remoteID]?.contains(where: { $0 === supplier }) != true {
            suppliersByRemoteID[remoteID, default: []].append(supplier)
        }
        if let key = SupabasePullPreviewNormalizer.normalizedLookupName(supplier.name),
           suppliersByCanonicalName[key]?.contains(where: { $0 === supplier }) != true {
            suppliersByCanonicalName[key, default: []].append(supplier)
        }
    }

    private mutating func addCategory(_ category: ProductCategory) {
        if let remoteID = category.remoteID,
           categoriesByRemoteID[remoteID]?.contains(where: { $0 === category }) != true {
            categoriesByRemoteID[remoteID, default: []].append(category)
        }
        if let key = SupabasePullPreviewNormalizer.normalizedLookupName(category.name),
           categoriesByCanonicalName[key]?.contains(where: { $0 === category }) != true {
            categoriesByCanonicalName[key, default: []].append(category)
        }
    }

    private mutating func addProduct(_ product: Product) {
        if let remoteID = product.remoteID,
           productsByRemoteID[remoteID]?.contains(where: { $0 === product }) != true {
            productsByRemoteID[remoteID, default: []].append(product)
        }
        if let key = SupabasePullPreviewNormalizer.normalizedBarcode(product.barcode),
           productsByCanonicalBarcode[key]?.contains(where: { $0 === product }) != true {
            productsByCanonicalBarcode[key, default: []].append(product)
        }
        if let remoteID = product.supplier?.remoteID,
           productsBySupplierRemoteID[remoteID]?.contains(where: { $0 === product }) != true {
            productsBySupplierRemoteID[remoteID, default: []].append(product)
        }
        if let remoteID = product.category?.remoteID,
           productsByCategoryRemoteID[remoteID]?.contains(where: { $0 === product }) != true {
            productsByCategoryRemoteID[remoteID, default: []].append(product)
        }
    }
}

nonisolated struct IncrementalLocalProductPriceIdentityIndex {
    nonisolated struct LogicalKey: Hashable {
        let productObjectID: ObjectIdentifier
        let type: String
        let effectiveAt: String
    }

    private var byRemoteID: [UUID: [ProductPrice]] = [:]
    private var byLogicalKey: [LogicalKey: [ProductPrice]] = [:]
    private var byProductObjectID: [ObjectIdentifier: [ProductPrice]] = [:]

    init(context: ModelContext, includePrices: Bool) throws {
        guard includePrices else { return }
        var descriptor = FetchDescriptor<ProductPrice>()
        descriptor.fetchLimit = ShopSyncRecoveryLimits.maximumRows(for: .prices) + 1
        let prices = try context.fetch(descriptor)
        guard prices.count <= ShopSyncRecoveryLimits.maximumRows(for: .prices) else {
            throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: .prices)
        }
        for (index, price) in prices.enumerated() {
            if index.isMultiple(of: 64) { try Task.checkCancellation() }
            if let remoteID = price.remoteID {
                byRemoteID[remoteID, default: []].append(price)
            }
            guard let product = price.product else { continue }
            byProductObjectID[ObjectIdentifier(product), default: []].append(price)
            let key = LogicalKey(
                productObjectID: ObjectIdentifier(product),
                type: price.type.rawValue,
                effectiveAt: ProductPriceEffectiveAtCanonicalizer.canonicalString(
                    from: price.effectiveAt
                )
            )
            byLogicalKey[key, default: []].append(price)
        }
    }

    func prices(remoteID: UUID) -> [ProductPrice] {
        byRemoteID[remoteID] ?? []
    }

    func prices(product: Product, type: String, effectiveAt: String) -> [ProductPrice] {
        byLogicalKey[
            LogicalKey(
                productObjectID: ObjectIdentifier(product),
                type: type,
                effectiveAt: effectiveAt
            )
        ] ?? []
    }

    func prices(product: Product) -> [ProductPrice] {
        byProductObjectID[ObjectIdentifier(product)] ?? []
    }
}

nonisolated struct TargetedProductPriceLogicalKey: Hashable {
    let productID: UUID
    let type: String
    let effectiveAt: String
}

nonisolated struct TargetedProductPriceCurrentInfo {
    var canonicalPrice: ProductPriceCanonicalAmount
    var remoteID: UUID?
    var productPriceIDToLink: PersistentIdentifier?

    init(
        canonicalPrice: ProductPriceCanonicalAmount,
        remoteID: UUID?,
        productPriceIDToLink: PersistentIdentifier? = nil
    ) {
        self.canonicalPrice = canonicalPrice
        self.remoteID = remoteID
        self.productPriceIDToLink = productPriceIDToLink
    }
}

nonisolated func pendingRemoteIDs(
    context: ModelContext,
    ownerUserID: UUID,
    storeIdentity: LocalStoreIdentity
) throws -> IncrementalApplyProtectedRemoteIDs {
    let owner = ownerUserID.uuidString.lowercased()
    let storeID = storeIdentity.storeId
    let defaultStoreID = Task126SyncPolicy.defaultStoreId
    let superseded = LocalPendingChangeStatus.superseded.rawValue
    let acknowledged = LocalPendingChangeStatus.acknowledged.rawValue
    let maximumRows = LocalPendingChangeAccumulator.defaultMaxActiveChanges + 1
    var changes: [LocalPendingChange] = []
    var seenChanges: Set<ObjectIdentifier> = []

    func append(_ descriptor: FetchDescriptor<LocalPendingChange>) throws {
        var boundedDescriptor = descriptor
        boundedDescriptor.fetchLimit = maximumRows + 1
        for change in try context.fetch(boundedDescriptor) {
            guard seenChanges.insert(ObjectIdentifier(change)).inserted else { continue }
            changes.append(change)
            guard changes.count <= maximumRows else {
                throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: .products)
            }
        }
    }

    try append(FetchDescriptor<LocalPendingChange>(
        predicate: #Predicate<LocalPendingChange> { change in
            change.ownerUserID == owner
                && change.storeId == storeID
                && change.statusRaw != superseded
                && change.statusRaw != acknowledged
        }
    ))
    try append(FetchDescriptor<LocalPendingChange>(
        predicate: #Predicate<LocalPendingChange> { change in
            change.ownerUserID == owner
                && change.storeId == defaultStoreID
                && change.statusRaw != superseded
                && change.statusRaw != acknowledged
        }
    ))
    try append(FetchDescriptor<LocalPendingChange>(
        predicate: #Predicate<LocalPendingChange> { change in
            change.ownerUserID == owner
                && change.storeId == nil
                && change.statusRaw != superseded
                && change.statusRaw != acknowledged
        }
    ))
    try append(FetchDescriptor<LocalPendingChange>(
        predicate: #Predicate<LocalPendingChange> { change in
            change.ownerUserID == nil
                && change.storeId == storeID
                && change.statusRaw != superseded
                && change.statusRaw != acknowledged
        }
    ))
    try append(FetchDescriptor<LocalPendingChange>(
        predicate: #Predicate<LocalPendingChange> { change in
            change.ownerUserID == nil
                && change.storeId == defaultStoreID
                && change.statusRaw != superseded
                && change.statusRaw != acknowledged
        }
    ))
    try append(FetchDescriptor<LocalPendingChange>(
        predicate: #Predicate<LocalPendingChange> { change in
            change.ownerUserID == nil
                && change.storeId == nil
                && change.statusRaw != superseded
                && change.statusRaw != acknowledged
        }
    ))
    var protected = IncrementalApplyProtectedRemoteIDs()
    for (index, change) in changes.enumerated() {
        if index.isMultiple(of: 64) { try Task.checkCancellation() }
        protected.logicalKeys.insert(change.logicalKey)
        if change.entityKind == .importBatch,
           change.logicalKey.hasPrefix("import:cap:") {
            // The cap marker means at least one committed import mutation has
            // no row-level pending identity. Treat the whole catalog as dirty
            // until the marker is explicitly resolved; a targeted pull cannot
            // prove that an arbitrary remote row is unrelated.
            protected.hasCappedImportMarker = true
        }
        let remoteID = change.entityRemoteID ?? remoteIDFromLogicalKey(change.logicalKey)
        guard let remoteID else { continue }
        switch change.entityKind {
        case .supplier:
            protected.suppliers.insert(remoteID)
        case .productCategory:
            protected.categories.insert(remoteID)
        case .product:
            protected.products.insert(remoteID)
        case .productPrice:
            protected.prices.insert(remoteID)
        case .historySession:
            protected.history.insert(remoteID)
        case .importBatch:
            break
        }
    }
    return protected
}

nonisolated func remoteIDFromLogicalKey(_ key: String) -> UUID? {
    let parts = key.split(separator: ":")
    guard parts.count == 3, parts[1] == "remote" else { return nil }
    return UUID(uuidString: String(parts[2]))
}

nonisolated func applyTargetedSupplier(
    _ row: RemoteInventorySupplierRow,
    context: ModelContext,
    localIdentityIndex: inout IncrementalLocalCatalogIdentityIndex
) throws -> (supplier: Supplier?, created: Bool, updated: Bool) {
    let deletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    guard let updatedAt = SupabaseRemoteDateParser.parse(row.updatedAt),
          row.deletedAt == nil || deletedAt != nil else {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    if let deletedAt {
        guard let supplier = try fetchSupplier(remoteID: row.id, context: context) else {
            return (nil, false, false)
        }
        let updated = supplier.remoteUpdatedAt != updatedAt
            || supplier.remoteDeletedAt != deletedAt
        supplier.remoteUpdatedAt = updatedAt
        supplier.remoteDeletedAt = deletedAt
        let detachedCount = try localIdentityIndex.detachProducts(supplierRemoteID: row.id)
        return (nil, false, updated || detachedCount > 0)
    }
    guard let name = SupabasePullPreviewNormalizer.semanticString(row.name) else {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    guard let canonicalName = SupabasePullPreviewNormalizer.normalizedLookupName(name) else {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    let remoteMatches = localIdentityIndex.suppliers(remoteID: row.id)
    let nameMatches = localIdentityIndex.suppliers(canonicalName: canonicalName)
    guard remoteMatches.count <= 1, nameMatches.count <= 1 else {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    let byRemoteID = remoteMatches.first
    let byName = nameMatches.first
    if let byRemoteID, let byName, byRemoteID !== byName {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    if let byName, let existingRemoteID = byName.remoteID, existingRemoteID != row.id {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    if let supplier = byRemoteID ?? byName {
        let wasName = supplier.name
        let wasRemoteID = supplier.remoteID
        let wasUpdatedAt = supplier.remoteUpdatedAt
        let wasDeletedAt = supplier.remoteDeletedAt
        supplier.name = name
        supplier.remoteID = row.id
        supplier.remoteUpdatedAt = updatedAt
        supplier.remoteDeletedAt = nil
        localIdentityIndex.reindexSupplier(
            supplier,
            previousRemoteID: wasRemoteID,
            previousName: wasName
        )
        let updated = wasName != supplier.name
            || wasRemoteID != supplier.remoteID
            || wasUpdatedAt != supplier.remoteUpdatedAt
            || wasDeletedAt != supplier.remoteDeletedAt
        return (supplier, false, updated)
    }
    let supplier = Supplier(name: name, remoteID: row.id, remoteUpdatedAt: updatedAt)
    context.insert(supplier)
    localIdentityIndex.reindexSupplier(
        supplier,
        previousRemoteID: nil,
        previousName: nil
    )
    return (supplier, true, false)
}

nonisolated func applyTargetedSupplier(
    _ row: RemoteInventorySupplierRow,
    context: ModelContext
) throws -> (supplier: Supplier?, created: Bool, updated: Bool) {
    var index = try IncrementalLocalCatalogIdentityIndex(
        context: context,
        includeSuppliers: true,
        includeCategories: false,
        includeProducts: true
    )
    return try applyTargetedSupplier(row, context: context, localIdentityIndex: &index)
}

nonisolated func applyTargetedCategory(
    _ row: RemoteInventoryCategoryRow,
    context: ModelContext,
    localIdentityIndex: inout IncrementalLocalCatalogIdentityIndex
) throws -> (category: ProductCategory?, created: Bool, updated: Bool) {
    let deletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    guard let updatedAt = SupabaseRemoteDateParser.parse(row.updatedAt),
          row.deletedAt == nil || deletedAt != nil else {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    if let deletedAt {
        guard let category = try fetchCategory(remoteID: row.id, context: context) else {
            return (nil, false, false)
        }
        let updated = category.remoteUpdatedAt != updatedAt
            || category.remoteDeletedAt != deletedAt
        category.remoteUpdatedAt = updatedAt
        category.remoteDeletedAt = deletedAt
        let detachedCount = try localIdentityIndex.detachProducts(categoryRemoteID: row.id)
        return (nil, false, updated || detachedCount > 0)
    }
    guard let name = SupabasePullPreviewNormalizer.semanticString(row.name) else {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    guard let canonicalName = SupabasePullPreviewNormalizer.normalizedLookupName(name) else {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    let remoteMatches = localIdentityIndex.categories(remoteID: row.id)
    let nameMatches = localIdentityIndex.categories(canonicalName: canonicalName)
    guard remoteMatches.count <= 1, nameMatches.count <= 1 else {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    let byRemoteID = remoteMatches.first
    let byName = nameMatches.first
    if let byRemoteID, let byName, byRemoteID !== byName {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    if let byName, let existingRemoteID = byName.remoteID, existingRemoteID != row.id {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    if let category = byRemoteID ?? byName {
        let wasName = category.name
        let wasRemoteID = category.remoteID
        let wasUpdatedAt = category.remoteUpdatedAt
        let wasDeletedAt = category.remoteDeletedAt
        category.name = name
        category.remoteID = row.id
        category.remoteUpdatedAt = updatedAt
        category.remoteDeletedAt = nil
        localIdentityIndex.reindexCategory(
            category,
            previousRemoteID: wasRemoteID,
            previousName: wasName
        )
        let updated = wasName != category.name
            || wasRemoteID != category.remoteID
            || wasUpdatedAt != category.remoteUpdatedAt
            || wasDeletedAt != category.remoteDeletedAt
        return (category, false, updated)
    }
    let category = ProductCategory(name: name, remoteID: row.id, remoteUpdatedAt: updatedAt)
    context.insert(category)
    localIdentityIndex.reindexCategory(
        category,
        previousRemoteID: nil,
        previousName: nil
    )
    return (category, true, false)
}

nonisolated func applyTargetedCategory(
    _ row: RemoteInventoryCategoryRow,
    context: ModelContext
) throws -> (category: ProductCategory?, created: Bool, updated: Bool) {
    var index = try IncrementalLocalCatalogIdentityIndex(
        context: context,
        includeSuppliers: false,
        includeCategories: true,
        includeProducts: true
    )
    return try applyTargetedCategory(row, context: context, localIdentityIndex: &index)
}

nonisolated func applyTargetedProduct(
    _ row: RemoteInventoryProductRow,
    supplier: Supplier?,
    category: ProductCategory?,
    context: ModelContext,
    localIdentityIndex: inout IncrementalLocalCatalogIdentityIndex
) throws -> (inserted: Bool, updated: Bool, tombstoned: Bool) {
    guard let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(row.barcode) else {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    let deletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    let primaryImageUpdatedAt = SupabaseRemoteDateParser.parse(row.primaryImageUpdatedAt)
    guard let updatedAt = SupabaseRemoteDateParser.parse(row.updatedAt),
          row.deletedAt == nil || deletedAt != nil,
          row.primaryImageUpdatedAt == nil || primaryImageUpdatedAt != nil else {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    if let deletedAt {
        let remoteMatches = localIdentityIndex.products(remoteID: row.id)
        guard remoteMatches.count <= 1 else {
            throw SyncEventIncrementalApplyError.dynamicPreflightRequired
        }
        guard let product = remoteMatches.first else {
            return (false, false, false)
        }
        product.remoteUpdatedAt = updatedAt
        product.remoteDeletedAt = deletedAt
        product.primaryImageVersionID = row.primaryImageVersionID
        product.primaryImageUpdatedAt = primaryImageUpdatedAt
        product.supplier = nil
        product.category = nil
        return (false, false, true)
    }

    let remoteMatches = localIdentityIndex.products(remoteID: row.id)
    let barcodeMatches = localIdentityIndex.products(canonicalBarcode: barcode)
    guard remoteMatches.count <= 1, barcodeMatches.count <= 1 else {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    let byRemoteID = remoteMatches.first
    let byBarcode = barcodeMatches.first
    if let byRemoteID, let byBarcode, byRemoteID !== byBarcode {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    if let byBarcode, let existingRemoteID = byBarcode.remoteID, existingRemoteID != row.id {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    let existing = byRemoteID ?? byBarcode
    if let product = existing {
        let wasBarcode = product.barcode
        let wasRemoteID = product.remoteID
        product.barcode = barcode
        product.remoteID = row.id
        product.remoteUpdatedAt = updatedAt
        product.remoteDeletedAt = nil
        product.primaryImageVersionID = row.primaryImageVersionID
        product.primaryImageUpdatedAt = primaryImageUpdatedAt
        product.itemNumber = SupabasePullPreviewNormalizer.semanticString(row.itemNumber)
        product.productName = SupabasePullPreviewNormalizer.semanticString(row.productName)
        product.secondProductName = SupabasePullPreviewNormalizer.semanticString(row.secondProductName)
        product.purchasePrice = row.purchasePrice
        product.retailPrice = row.retailPrice
        product.stockQuantity = row.stockQuantity
        product.supplier = supplier
        product.category = category
        localIdentityIndex.reindexProduct(
            product,
            previousRemoteID: wasRemoteID,
            previousBarcode: wasBarcode
        )
        return (false, true, false)
    }

    let product = Product(
        barcode: barcode,
        remoteID: row.id,
        remoteUpdatedAt: updatedAt,
        primaryImageVersionID: row.primaryImageVersionID,
        primaryImageUpdatedAt: primaryImageUpdatedAt,
        itemNumber: SupabasePullPreviewNormalizer.semanticString(row.itemNumber),
        productName: SupabasePullPreviewNormalizer.semanticString(row.productName),
        secondProductName: SupabasePullPreviewNormalizer.semanticString(row.secondProductName),
        purchasePrice: row.purchasePrice,
        retailPrice: row.retailPrice,
        stockQuantity: row.stockQuantity,
        supplier: supplier,
        category: category
    )
    context.insert(product)
    localIdentityIndex.reindexProduct(
        product,
        previousRemoteID: nil,
        previousBarcode: nil
    )
    return (true, false, false)
}

nonisolated func applyTargetedProduct(
    _ row: RemoteInventoryProductRow,
    supplier: Supplier?,
    category: ProductCategory?,
    context: ModelContext
) throws -> (inserted: Bool, updated: Bool, tombstoned: Bool) {
    var index = try IncrementalLocalCatalogIdentityIndex(
        context: context,
        includeSuppliers: false,
        includeCategories: false,
        includeProducts: true
    )
    return try applyTargetedProduct(
        row,
        supplier: supplier,
        category: category,
        context: context,
        localIdentityIndex: &index
    )
}

nonisolated func applyTargetedProductImageReference(
    _ row: RemoteInventoryProductRow,
    context: ModelContext
) throws -> Bool {
    guard let product = try fetchProduct(remoteID: row.id, context: context) else {
        return false
    }
    let updatedAt = SupabaseRemoteDateParser.parse(row.primaryImageUpdatedAt)
    guard product.primaryImageVersionID != row.primaryImageVersionID
            || product.primaryImageUpdatedAt != updatedAt else {
        return false
    }
    product.primaryImageVersionID = row.primaryImageVersionID
    product.primaryImageUpdatedAt = updatedAt
    return true
}

nonisolated func applyTargetedProductPriceRow(
    _ row: RemoteInventoryProductPriceRow,
    product: Product,
    currentPricesByKey: inout [TargetedProductPriceLogicalKey: [TargetedProductPriceCurrentInfo]],
    context: ModelContext
) throws -> ProductPriceApplyResult {
    guard let type = SupabasePullPreviewNormalizer.normalizedPriceType(row.type) else {
        throw ProductPriceApplyError.invalidRemoteRow(reason: "invalid_type")
    }
    guard let canonicalPrice = PriceCanonicalizer.canonicalAmount(from: row.price) else {
        throw ProductPriceApplyError.invalidRemoteRow(reason: "invalid_price")
    }
    guard let effectiveAt = ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.effectiveAt) else {
        throw ProductPriceApplyError.invalidRemoteRow(reason: "invalid_effective_at")
    }
    let effectiveAtCanonical = ProductPriceEffectiveAtCanonicalizer.canonicalString(from: effectiveAt)
    let key = TargetedProductPriceLogicalKey(
        productID: row.productID,
        type: type,
        effectiveAt: effectiveAtCanonical
    )

    if let existingRemote = try fetchProductPrice(remoteID: row.id, context: context) {
        existingRemote.type = priceType(from: type)
        existingRemote.price = canonicalPrice.doubleValue
        existingRemote.effectiveAt = effectiveAt
        existingRemote.source = SupabasePullPreviewNormalizer.semanticString(row.source) ?? "SUPABASE_PULL"
        existingRemote.note = SupabasePullPreviewNormalizer.semanticString(row.note)
        existingRemote.createdAt = ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.createdAt) ?? existingRemote.createdAt
        existingRemote.product = product
        return ProductPriceApplyResult(inserted: 0, skippedExisting: 1, totalConsidered: 1)
    }

    if let existingPrices = currentPricesByKey[key] {
        guard existingPrices.count == 1,
              var existing = existingPrices.first else {
            throw ProductPriceApplyError.policyBlocked([.conflicts])
        }
        guard existing.canonicalPrice == canonicalPrice else {
            throw ProductPriceApplyError.policyBlocked([.conflicts])
        }
        if let existingRemoteID = existing.remoteID {
            guard existingRemoteID == row.id else {
                throw ProductPriceApplyError.policyBlocked([.conflicts])
            }
            return ProductPriceApplyResult(inserted: 0, skippedExisting: 1, totalConsidered: 1)
        }
        guard let productPriceID = existing.productPriceIDToLink,
              let productPrice = context.model(for: productPriceID) as? ProductPrice else {
            throw ProductPriceApplyError.verificationFailed
        }
        productPrice.remoteID = row.id
        productPrice.source = SupabasePullPreviewNormalizer.semanticString(row.source) ?? productPrice.source
        productPrice.note = SupabasePullPreviewNormalizer.semanticString(row.note)
        existing.remoteID = row.id
        existing.productPriceIDToLink = nil
        currentPricesByKey[key] = [existing]
        return ProductPriceApplyResult(
            inserted: 0,
            remoteIdentityLinked: 1,
            skippedExisting: 1,
            totalConsidered: 1
        )
    }

    let newPrice = ProductPrice(
        remoteID: row.id,
        type: priceType(from: type),
        price: canonicalPrice.doubleValue,
        effectiveAt: effectiveAt,
        source: SupabasePullPreviewNormalizer.semanticString(row.source) ?? "SUPABASE_PULL",
        note: SupabasePullPreviewNormalizer.semanticString(row.note),
        createdAt: ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.createdAt) ?? Date(),
        product: product
    )
    context.insert(newPrice)
    currentPricesByKey[key] = [
        TargetedProductPriceCurrentInfo(
            canonicalPrice: canonicalPrice,
            remoteID: row.id
        )
    ]
    return ProductPriceApplyResult(inserted: 1, skippedExisting: 0, totalConsidered: 1)
}

nonisolated func priceType(from normalizedType: String) -> PriceType {
    normalizedType == PriceType.retail.rawValue ? .retail : .purchase
}

nonisolated func fetchSupplier(remoteID: UUID, context: ModelContext) throws -> Supplier? {
    var descriptor = FetchDescriptor<Supplier>(
        predicate: #Predicate<Supplier> { supplier in
            supplier.remoteID == remoteID
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated func fetchSupplier(name: String, context: ModelContext) throws -> Supplier? {
    var descriptor = FetchDescriptor<Supplier>(
        predicate: #Predicate<Supplier> { supplier in
            supplier.name == name
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated func fetchCategory(remoteID: UUID, context: ModelContext) throws -> ProductCategory? {
    var descriptor = FetchDescriptor<ProductCategory>(
        predicate: #Predicate<ProductCategory> { category in
            category.remoteID == remoteID
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated func fetchCategory(name: String, context: ModelContext) throws -> ProductCategory? {
    var descriptor = FetchDescriptor<ProductCategory>(
        predicate: #Predicate<ProductCategory> { category in
            category.name == name
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated func fetchProduct(remoteID: UUID, context: ModelContext) throws -> Product? {
    var descriptor = FetchDescriptor<Product>(
        predicate: #Predicate<Product> { product in
            product.remoteID == remoteID
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated func fetchProduct(barcode: String, context: ModelContext) throws -> Product? {
    var descriptor = FetchDescriptor<Product>(
        predicate: #Predicate<Product> { product in
            product.barcode == barcode
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated func fetchProductPrice(remoteID: UUID, context: ModelContext) throws -> ProductPrice? {
    var descriptor = FetchDescriptor<ProductPrice>(
        predicate: #Predicate<ProductPrice> { price in
            price.remoteID == remoteID
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated func fetchHistory(remoteID: UUID, context: ModelContext) throws -> HistoryEntry? {
    var descriptor = FetchDescriptor<HistoryEntry>(
        predicate: #Predicate<HistoryEntry> { entry in
            entry.remoteID == remoteID
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated func detachSupplier(remoteID: UUID, context: ModelContext) throws {
    var descriptor = FetchDescriptor<Product>()
    descriptor.fetchLimit = ShopSyncRecoveryLimits.maximumRows(for: .products) + 1
    let products = try context.fetch(descriptor)
    guard products.count <= ShopSyncRecoveryLimits.maximumRows(for: .products) else {
        throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: .products)
    }
    for (index, product) in products.enumerated() {
        if index.isMultiple(of: 64) { try Task.checkCancellation() }
        guard product.supplier?.remoteID == remoteID else { continue }
        product.supplier = nil
    }
}

nonisolated func detachCategory(remoteID: UUID, context: ModelContext) throws {
    var descriptor = FetchDescriptor<Product>()
    descriptor.fetchLimit = ShopSyncRecoveryLimits.maximumRows(for: .products) + 1
    let products = try context.fetch(descriptor)
    guard products.count <= ShopSyncRecoveryLimits.maximumRows(for: .products) else {
        throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: .products)
    }
    for (index, product) in products.enumerated() {
        if index.isMultiple(of: 64) { try Task.checkCancellation() }
        guard product.category?.remoteID == remoteID else { continue }
        product.category = nil
    }
}

nonisolated func mcNowMillis() -> Int {
    Int((Date().timeIntervalSince1970 * 1_000).rounded())
}

nonisolated struct SyncEventEntityIDSet: Sendable {
    var supplierIDs: Set<UUID> = []
    var categoryIDs: Set<UUID> = []
    var productIDs: Set<UUID> = []
    var priceIDs: Set<UUID> = []
    var sessionIDs: Set<UUID> = []
    var hasUnrecoverableCatalogGap = false
    var hasUnrecoverablePriceGap = false
    var hasUnrecoverableHistoryGap = false
    private(set) var hasMalformedPayload = false
    private(set) var supplierRawCount = 0
    private(set) var categoryRawCount = 0
    private(set) var productRawCount = 0
    private(set) var priceRawCount = 0
    private(set) var sessionRawCount = 0
    private(set) var payloadKeys: Set<String> = []

    init() {}

    init(json: SyncEventJSONValue?) {
        guard let json else { return }
        guard case .object(let object) = json else {
            hasMalformedPayload = true
            return
        }
        payloadKeys = Set(object.keys)
        let suppliers = Self.ids(from: object["supplier_ids"])
        let categories = Self.ids(from: object["category_ids"])
        let products = Self.ids(from: object["product_ids"])
        let prices = Self.ids(from: object["price_ids"])
        let sessions = Self.ids(from: object["session_ids"])
        supplierIDs = suppliers.ids
        categoryIDs = categories.ids
        productIDs = products.ids
        priceIDs = prices.ids
        sessionIDs = sessions.ids
        supplierRawCount = suppliers.rawCount
        categoryRawCount = categories.rawCount
        productRawCount = products.rawCount
        priceRawCount = prices.rawCount
        sessionRawCount = sessions.rawCount
        hasMalformedPayload = !suppliers.valid
            || !categories.valid
            || !products.valid
            || !prices.valid
            || !sessions.valid
            || !Set(object.keys).isSubset(of: [
                "supplier_ids",
                "category_ids",
                "product_ids",
                "price_ids",
                "session_ids"
            ])
    }

    var isEmpty: Bool {
        supplierIDs.isEmpty && categoryIDs.isEmpty && productIDs.isEmpty && priceIDs.isEmpty && sessionIDs.isEmpty
    }

    var totalIDs: Int {
        supplierIDs.count + categoryIDs.count + productIDs.count + priceIDs.count + sessionIDs.count
    }

    var isCatalogEmpty: Bool {
        supplierIDs.isEmpty && categoryIDs.isEmpty && productIDs.isEmpty
    }

    var hasCatalogWork: Bool {
        !isCatalogEmpty || hasUnrecoverableCatalogGap
    }

    var hasHistoryWork: Bool {
        !sessionIDs.isEmpty || hasUnrecoverableHistoryGap
    }

    var hasPriceWork: Bool {
        !priceIDs.isEmpty || hasUnrecoverablePriceGap
    }

    var hasWork: Bool {
        hasCatalogWork || hasPriceWork || hasHistoryWork
    }

    var hasUnrecoverableGap: Bool {
        hasUnrecoverableCatalogGap || hasUnrecoverablePriceGap || hasUnrecoverableHistoryGap
    }

    func isCompleteCatalog(changedCount: Int) -> Bool {
        !hasMalformedPayload
            && changedCount >= 0
            && payloadKeys.isSubset(of: ["supplier_ids", "category_ids", "product_ids"])
            && priceRawCount == 0
            && sessionRawCount == 0
            && supplierRawCount + categoryRawCount + productRawCount == changedCount
            && supplierRawCount == supplierIDs.count
            && categoryRawCount == categoryIDs.count
            && productRawCount == productIDs.count
    }

    func isCompletePrices(changedCount: Int) -> Bool {
        let hasValidProductReferences = changedCount == 0
            ? productRawCount == 0
            : productRawCount >= 1 && productRawCount <= priceRawCount
        return !hasMalformedPayload
            && changedCount >= 0
            && payloadKeys.isSubset(of: ["price_ids", "product_ids"])
            && supplierRawCount == 0
            && categoryRawCount == 0
            && sessionRawCount == 0
            && priceRawCount == changedCount
            && priceRawCount == priceIDs.count
            && productRawCount == productIDs.count
            && hasValidProductReferences
    }

    func isCompleteHistory(changedCount: Int) -> Bool {
        !hasMalformedPayload
            && changedCount >= 0
            && payloadKeys.isSubset(of: ["session_ids"])
            && supplierRawCount == 0
            && categoryRawCount == 0
            && productRawCount == 0
            && priceRawCount == 0
            && sessionRawCount == changedCount
            && sessionRawCount == sessionIDs.count
    }

    private static func ids(
        from value: SyncEventJSONValue?
    ) -> (ids: Set<UUID>, rawCount: Int, valid: Bool) {
        guard let value else { return ([], 0, true) }
        guard case .array(let values) = value else { return ([], 0, false) }
        var ids: Set<UUID> = []
        var valid = true
        for element in values {
            guard case .string(let raw) = element,
                  let id = UUID(uuidString: raw),
                  ids.insert(id).inserted else {
                valid = false
                continue
            }
        }
        return (ids, values.count, valid)
    }
}

nonisolated enum SyncEventApplyStatusValue: String, Codable, Sendable, Equatable {
    case applied
    case blocked
    case skipped
    case retrying
}

nonisolated enum SyncEventApplyStatusReason: String, Codable, Sendable, Equatable {
    case applied
    case selfOrigin = "self_origin"
    case dirtyLocal = "dirty_local"
    case missingEntityIDs = "missing_entity_ids"
    case entityIDsTooLarge = "entity_ids_too_large"
    case aggregateEntityIDsTooLarge = "aggregate_entity_ids_too_large"
    case missingRemote = "missing_remote"
    case remoteRowNotMaterializable = "remote_row_not_materializable"
    case priceParentNotMaterializable = "price_parent_not_materializable"
    case unsupportedDomain = "unsupported_domain"
}

nonisolated struct SyncEventApplyStatusEntityIDs: Codable, Sendable, Equatable {
    private static let maximumPersistedIDs = 32
    var supplierIDs: [UUID] = []
    var categoryIDs: [UUID] = []
    var productIDs: [UUID] = []
    var priceIDs: [UUID] = []
    var sessionIDs: [UUID] = []
    var totalIDCount: Int?
    var isTruncated: Bool?

    init(_ ids: SyncEventEntityIDSet = SyncEventEntityIDSet()) {
        var remaining = Self.maximumPersistedIDs
        func bounded(_ values: Set<UUID>) -> [UUID] {
            guard remaining > 0 else { return [] }
            let result = Array(values.sorted { $0.uuidString < $1.uuidString }.prefix(remaining))
            remaining -= result.count
            return result
        }
        supplierIDs = bounded(ids.supplierIDs)
        categoryIDs = bounded(ids.categoryIDs)
        productIDs = bounded(ids.productIDs)
        priceIDs = bounded(ids.priceIDs)
        sessionIDs = bounded(ids.sessionIDs)
        totalIDCount = ids.totalIDs
        isTruncated = ids.totalIDs > Self.maximumPersistedIDs
    }
}

nonisolated struct SyncEventApplyStatusRecord: Codable, Sendable, Equatable {
    var ownerUserID: UUID
    var eventID: Int64
    var shopID: UUID?
    var domain: String
    var entityType: String?
    var entityIDs: SyncEventApplyStatusEntityIDs
    var status: SyncEventApplyStatusValue
    var reason: SyncEventApplyStatusReason
    var attemptCount: Int
    var lastAttemptAtMs: Int
    var nextRetryAtMs: Int?
    var correlationID: String?
    var clientEventID: String?
    var remoteCreatedAt: String
}

nonisolated struct SyncEventApplyStatusStore {
    private static let retryDelayMs = 30_000
    private static let maximumRecords = 256
    private static let maximumEncodedBytes = 512 * 1_024
    private static let maximumDiagnosticStringLength = 128
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func record(
        event: RemoteSyncEventRow,
        ownerUserID: UUID,
        scopeShopID: UUID,
        ids: SyncEventEntityIDSet,
        status: SyncEventApplyStatusValue,
        reason: SyncEventApplyStatusReason,
        nowMs: Int = mcNowMillis()
    ) -> Bool {
        let key = storageKey(ownerUserID: ownerUserID, shopID: scopeShopID)
        var records = loadRecords(ownerUserID: ownerUserID, shopID: scopeShopID)
        let previous = records[String(event.id)]
        records[String(event.id)] = SyncEventApplyStatusRecord(
            ownerUserID: ownerUserID,
            eventID: event.id,
            shopID: event.shopID,
            domain: boundedDiagnosticString(event.domain) ?? "invalid",
            entityType: boundedDiagnosticString(entityType(from: event.metadata)),
            entityIDs: SyncEventApplyStatusEntityIDs(ids),
            status: status,
            reason: reason,
            attemptCount: (previous?.attemptCount ?? 0) + 1,
            lastAttemptAtMs: nowMs,
            nextRetryAtMs: status == .blocked || status == .retrying ? nowMs + Self.retryDelayMs : nil,
            correlationID: boundedDiagnosticString(event.clientEventID ?? event.batchID?.uuidString),
            clientEventID: boundedDiagnosticString(event.clientEventID),
            remoteCreatedAt: Self.remoteCreatedAtString(event.createdAt)
        )
        records = Self.pruned(records)
        guard let encoded = try? JSONEncoder().encode(records),
              encoded.count <= Self.maximumEncodedBytes else {
            defaults.set(true, forKey: overflowKey(ownerUserID: ownerUserID, shopID: scopeShopID))
            return false
        }
        defaults.set(encoded, forKey: key)
        return defaults.data(forKey: key) == encoded
    }

    func record(
        ownerUserID: UUID,
        shopID: UUID,
        eventID: Int64
    ) -> SyncEventApplyStatusRecord? {
        loadRecords(ownerUserID: ownerUserID, shopID: shopID)[String(eventID)]
    }

    func records(ownerUserID: UUID, shopID: UUID) -> [SyncEventApplyStatusRecord] {
        loadRecords(ownerUserID: ownerUserID, shopID: shopID)
            .values
            .sorted { $0.eventID < $1.eventID }
    }

    var maximumRecordsForTesting: Int { Self.maximumRecords }
    var maximumEncodedBytesForTesting: Int { Self.maximumEncodedBytes }

    func storageKeyForTesting(ownerUserID: UUID, shopID: UUID) -> String {
        storageKey(ownerUserID: ownerUserID, shopID: shopID)
    }

    func hasCorruptData(ownerUserID: UUID, shopID: UUID) -> Bool {
        defaults.bool(forKey: corruptKey(ownerUserID: ownerUserID, shopID: shopID))
    }

    func hasOverflow(ownerUserID: UUID, shopID: UUID) -> Bool {
        defaults.bool(forKey: overflowKey(ownerUserID: ownerUserID, shopID: shopID))
    }

    private func loadRecords(
        ownerUserID: UUID,
        shopID: UUID
    ) -> [String: SyncEventApplyStatusRecord] {
        let key = storageKey(ownerUserID: ownerUserID, shopID: shopID)
        guard let data = defaults.data(forKey: key) else { return [:] }
        guard data.count <= Self.maximumEncodedBytes,
              let records = try? JSONDecoder().decode([String: SyncEventApplyStatusRecord].self, from: data),
              records.count <= Self.maximumRecords,
              records.values.allSatisfy({ $0.ownerUserID == ownerUserID }) else {
            defaults.set(true, forKey: corruptKey(ownerUserID: ownerUserID, shopID: shopID))
            return [:]
        }
        return records
    }

    private func storageKey(ownerUserID: UUID, shopID: UUID) -> String {
        "sync.events.applyStatus.v2.\(scopeKey(ownerUserID: ownerUserID, shopID: shopID))"
    }

    private func corruptKey(ownerUserID: UUID, shopID: UUID) -> String {
        "sync.events.applyStatus.corrupt.v2.\(scopeKey(ownerUserID: ownerUserID, shopID: shopID))"
    }

    private func overflowKey(ownerUserID: UUID, shopID: UUID) -> String {
        "sync.events.applyStatus.overflow.v2.\(scopeKey(ownerUserID: ownerUserID, shopID: shopID))"
    }

    private func scopeKey(ownerUserID: UUID, shopID: UUID) -> String {
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        let shopHash = AccountBindingStore.redactedAccountHash(for: shopID.uuidString)
        return "\(accountHash).shop.\(shopHash)"
    }

    private static func pruned(
        _ records: [String: SyncEventApplyStatusRecord]
    ) -> [String: SyncEventApplyStatusRecord] {
        guard records.count > maximumRecords else { return records }
        let protected = records.values.filter { $0.status == .blocked || $0.status == .retrying }
        // The event fetch page is capped at 200. If this invariant is violated,
        // retain every blocker and let the byte cap reject the write rather than
        // silently forgetting an unresolved event.
        guard protected.count <= maximumRecords else { return records }
        let removable = records.values
            .filter { $0.status != .blocked && $0.status != .retrying }
            .sorted {
                if $0.lastAttemptAtMs == $1.lastAttemptAtMs { return $0.eventID > $1.eventID }
                return $0.lastAttemptAtMs > $1.lastAttemptAtMs
            }
        let retainedRemovableCount = maximumRecords - protected.count
        let retained = protected + removable.prefix(retainedRemovableCount)
        return Dictionary(uniqueKeysWithValues: retained.map { (String($0.eventID), $0) })
    }

    private func boundedDiagnosticString(_ value: String?) -> String? {
        guard let value else { return nil }
        return String(value.prefix(Self.maximumDiagnosticStringLength))
    }

    private func entityType(from metadata: SyncEventJSONValue) -> String? {
        guard case .object(let object) = metadata,
              case .string(let entityType) = object["entity_type"] else {
            return nil
        }
        return entityType
    }

    private static func remoteCreatedAtString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
