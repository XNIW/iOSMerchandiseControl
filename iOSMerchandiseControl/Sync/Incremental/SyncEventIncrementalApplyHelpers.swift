import Foundation
import SwiftData

nonisolated struct IncrementalApplyProtectedRemoteIDs: Sendable {
    var suppliers: Set<UUID> = []
    var categories: Set<UUID> = []
    var products: Set<UUID> = []
    var prices: Set<UUID> = []
    var history: Set<UUID> = []
}

nonisolated struct TargetedCatalogApplyResult: Sendable {
    var productsInserted = 0
    var productsUpdated = 0
    var productsTombstoned = 0
    var suppliersCreated = 0
    var categoriesCreated = 0

    var totalMutations: Int {
        productsInserted + productsUpdated + productsTombstoned + suppliersCreated + categoriesCreated
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
    ownerUserID: UUID
) throws -> IncrementalApplyProtectedRemoteIDs {
    let owner = ownerUserID.uuidString.lowercased()
    let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
    var protected = IncrementalApplyProtectedRemoteIDs()
    for change in changes where !change.status.isTerminal && (change.ownerUserID == nil || change.ownerUserID == owner) {
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
    context: ModelContext
) throws -> (supplier: Supplier?, created: Bool) {
    let deletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    let updatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
    guard let name = SupabasePullPreviewNormalizer.semanticString(row.name) else {
        return (nil, false)
    }
    if let supplier = try fetchSupplier(remoteID: row.id, context: context)
        ?? fetchSupplier(name: name, context: context) {
        supplier.remoteID = row.id
        supplier.remoteUpdatedAt = updatedAt
        supplier.remoteDeletedAt = deletedAt
        return (deletedAt == nil ? supplier : nil, false)
    }
    guard deletedAt == nil else { return (nil, false) }
    let supplier = Supplier(name: name, remoteID: row.id, remoteUpdatedAt: updatedAt)
    context.insert(supplier)
    return (supplier, true)
}

nonisolated func applyTargetedCategory(
    _ row: RemoteInventoryCategoryRow,
    context: ModelContext
) throws -> (category: ProductCategory?, created: Bool) {
    let deletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    let updatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
    guard let name = SupabasePullPreviewNormalizer.semanticString(row.name) else {
        return (nil, false)
    }
    if let category = try fetchCategory(remoteID: row.id, context: context)
        ?? fetchCategory(name: name, context: context) {
        category.remoteID = row.id
        category.remoteUpdatedAt = updatedAt
        category.remoteDeletedAt = deletedAt
        return (deletedAt == nil ? category : nil, false)
    }
    guard deletedAt == nil else { return (nil, false) }
    let category = ProductCategory(name: name, remoteID: row.id, remoteUpdatedAt: updatedAt)
    context.insert(category)
    return (category, true)
}

nonisolated func applyTargetedProduct(
    _ row: RemoteInventoryProductRow,
    supplier: Supplier?,
    category: ProductCategory?,
    context: ModelContext
) throws -> (inserted: Bool, updated: Bool, tombstoned: Bool) {
    guard let barcode = SupabasePullPreviewNormalizer.semanticString(row.barcode) else {
        return (false, false, false)
    }
    let updatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
    let deletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    let existing = try fetchProduct(remoteID: row.id, context: context)
        ?? fetchProduct(barcode: barcode, context: context)
    if let deletedAt {
        guard let product = existing else { return (false, false, false) }
        product.remoteID = row.id
        product.remoteUpdatedAt = updatedAt
        product.remoteDeletedAt = deletedAt
        product.supplier = nil
        product.category = nil
        return (false, false, true)
    }

    if let product = existing {
        product.remoteID = row.id
        product.remoteUpdatedAt = updatedAt
        product.remoteDeletedAt = nil
        product.itemNumber = SupabasePullPreviewNormalizer.semanticString(row.itemNumber)
        product.productName = SupabasePullPreviewNormalizer.semanticString(row.productName)
        product.secondProductName = SupabasePullPreviewNormalizer.semanticString(row.secondProductName)
        product.purchasePrice = row.purchasePrice
        product.retailPrice = row.retailPrice
        product.stockQuantity = row.stockQuantity
        product.supplier = supplier
        product.category = category
        return (false, true, false)
    }

    context.insert(Product(
        barcode: barcode,
        remoteID: row.id,
        remoteUpdatedAt: updatedAt,
        itemNumber: SupabasePullPreviewNormalizer.semanticString(row.itemNumber),
        productName: SupabasePullPreviewNormalizer.semanticString(row.productName),
        secondProductName: SupabasePullPreviewNormalizer.semanticString(row.secondProductName),
        purchasePrice: row.purchasePrice,
        retailPrice: row.retailPrice,
        stockQuantity: row.stockQuantity,
        supplier: supplier,
        category: category
    ))
    return (true, false, false)
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
    let products = try context.fetch(FetchDescriptor<Product>())
    for product in products where product.supplier?.remoteID == remoteID {
        product.supplier = nil
    }
}

nonisolated func detachCategory(remoteID: UUID, context: ModelContext) throws {
    let products = try context.fetch(FetchDescriptor<Product>())
    for product in products where product.category?.remoteID == remoteID {
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

    init() {}

    init(json: SyncEventJSONValue?) {
        guard case .object(let object) = json else { return }
        supplierIDs = Self.ids(from: object["supplier_ids"])
        categoryIDs = Self.ids(from: object["category_ids"])
        productIDs = Self.ids(from: object["product_ids"])
        priceIDs = Self.ids(from: object["price_ids"])
        sessionIDs = Self.ids(from: object["session_ids"])
    }

    var isEmpty: Bool {
        supplierIDs.isEmpty && categoryIDs.isEmpty && productIDs.isEmpty && priceIDs.isEmpty && sessionIDs.isEmpty
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

    private static func ids(from value: SyncEventJSONValue?) -> Set<UUID> {
        guard case .array(let values) = value else { return [] }
        return Set(values.compactMap { element in
            guard case .string(let raw) = element else { return nil }
            return UUID(uuidString: raw)
        })
    }
}
