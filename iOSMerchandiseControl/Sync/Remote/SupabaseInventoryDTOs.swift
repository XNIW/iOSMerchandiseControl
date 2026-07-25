import Foundation

nonisolated struct RemoteInventorySupplierRow: Codable, Sendable, Identifiable {
    let id: UUID
    let ownerUserID: UUID
    let shopID: UUID?
    let name: String
    let updatedAt: String
    let deletedAt: String?

    init(
        id: UUID,
        ownerUserID: UUID,
        shopID: UUID? = nil,
        name: String,
        updatedAt: String,
        deletedAt: String?
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.shopID = shopID
        self.name = name
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case shopID = "shop_id"
        case name
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

nonisolated struct RemoteInventoryCategoryRow: Codable, Sendable, Identifiable {
    let id: UUID
    let ownerUserID: UUID
    let shopID: UUID?
    let name: String
    let updatedAt: String
    let deletedAt: String?

    init(
        id: UUID,
        ownerUserID: UUID,
        shopID: UUID? = nil,
        name: String,
        updatedAt: String,
        deletedAt: String?
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.shopID = shopID
        self.name = name
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case shopID = "shop_id"
        case name
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

nonisolated struct RemoteInventoryProductRow: Codable, Sendable, Identifiable {
    let id: UUID
    let ownerUserID: UUID
    let shopID: UUID?
    let barcode: String
    let itemNumber: String?
    let productName: String?
    let secondProductName: String?
    let purchasePrice: Double?
    let retailPrice: Double?
    let supplierID: UUID?
    let categoryID: UUID?
    let stockQuantity: Double?
    let updatedAt: String
    let deletedAt: String?
    let primaryImageVersionID: UUID?
    let primaryImageUpdatedAt: String?

    init(
        id: UUID,
        ownerUserID: UUID,
        shopID: UUID? = nil,
        barcode: String,
        itemNumber: String?,
        productName: String?,
        secondProductName: String?,
        purchasePrice: Double?,
        retailPrice: Double?,
        supplierID: UUID?,
        categoryID: UUID?,
        stockQuantity: Double?,
        updatedAt: String,
        deletedAt: String?,
        primaryImageVersionID: UUID? = nil,
        primaryImageUpdatedAt: String? = nil
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.shopID = shopID
        self.barcode = barcode
        self.itemNumber = itemNumber
        self.productName = productName
        self.secondProductName = secondProductName
        self.purchasePrice = purchasePrice
        self.retailPrice = retailPrice
        self.supplierID = supplierID
        self.categoryID = categoryID
        self.stockQuantity = stockQuantity
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.primaryImageVersionID = primaryImageVersionID
        self.primaryImageUpdatedAt = primaryImageUpdatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case shopID = "shop_id"
        case barcode
        case itemNumber = "item_number"
        case productName = "product_name"
        case secondProductName = "second_product_name"
        case purchasePrice = "purchase_price"
        case retailPrice = "retail_price"
        case supplierID = "supplier_id"
        case categoryID = "category_id"
        case stockQuantity = "stock_quantity"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case primaryImageVersionID = "primary_image_version_id"
        case primaryImageUpdatedAt = "primary_image_updated_at"
    }
}

nonisolated struct SupabaseTask088RemoteSeed: Sendable {
    let ownerUserID: UUID
    let supplier: RemoteInventorySupplierRow
    let category: RemoteInventoryCategoryRow
    let product: RemoteInventoryProductRow
}

nonisolated struct RemoteInventoryProductPriceRow: Codable, Sendable, Identifiable {
    let id: UUID
    let ownerUserID: UUID
    let shopID: UUID?
    let productID: UUID
    let type: String
    let price: Double
    /// Server-canonical decimal used by the recovery checkpoint digest. This
    /// must not be reconstructed from the binary `Double` at the recovery
    /// boundary.
    let priceCanonical: String?
    let effectiveAt: String
    let source: String?
    let note: String?
    let createdAt: String
    let updatedAt: String?

    init(
        id: UUID,
        ownerUserID: UUID,
        shopID: UUID? = nil,
        productID: UUID,
        type: String,
        price: Double,
        priceCanonical: String? = nil,
        effectiveAt: String,
        source: String?,
        note: String?,
        createdAt: String,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.shopID = shopID
        self.productID = productID
        self.type = type
        self.price = price
        self.priceCanonical = priceCanonical
        self.effectiveAt = effectiveAt
        self.source = source
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case shopID = "shop_id"
        case productID = "product_id"
        case type
        case price
        case priceCanonical = "price_canonical"
        case effectiveAt = "effective_at"
        case source
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
