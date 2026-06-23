import Foundation

nonisolated struct SyncAutomaticSupplierCreatePayload: Encodable, Equatable, Sendable {
    let ownerUserID: UUID
    let shopID: UUID?
    let name: String

    init(ownerUserID: UUID, shopID: UUID? = nil, name: String) {
        self.ownerUserID = ownerUserID
        self.shopID = shopID
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case ownerUserID = "owner_user_id"
        case shopID = "shop_id"
        case name
    }
}

nonisolated struct SyncAutomaticSupplierUpdatePayload: Encodable, Equatable, Sendable {
    let name: String?
    let deletedAt: String?

    init(name: String? = nil, deletedAt: String? = nil) {
        self.name = name
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case name
        case deletedAt = "deleted_at"
    }
}

nonisolated struct SyncAutomaticCategoryCreatePayload: Encodable, Equatable, Sendable {
    let ownerUserID: UUID
    let shopID: UUID?
    let name: String

    init(ownerUserID: UUID, shopID: UUID? = nil, name: String) {
        self.ownerUserID = ownerUserID
        self.shopID = shopID
        self.name = name
    }

    enum CodingKeys: String, CodingKey {
        case ownerUserID = "owner_user_id"
        case shopID = "shop_id"
        case name
    }
}

nonisolated struct SyncAutomaticCategoryUpdatePayload: Encodable, Equatable, Sendable {
    let name: String?
    let deletedAt: String?

    init(name: String? = nil, deletedAt: String? = nil) {
        self.name = name
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case name
        case deletedAt = "deleted_at"
    }
}

nonisolated struct SyncAutomaticProductCreatePayload: Encodable, Equatable, Sendable {
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

    init(
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
        stockQuantity: Double?
    ) {
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
    }

    enum CodingKeys: String, CodingKey {
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
    }
}

nonisolated struct SyncAutomaticProductUpdatePayload: Encodable, Equatable, Sendable {
    let barcode: String?
    let itemNumber: String?
    let productName: String?
    let secondProductName: String?
    let purchasePrice: Double?
    let retailPrice: Double?
    let supplierID: UUID?
    let categoryID: UUID?
    let stockQuantity: Double?
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case barcode
        case itemNumber = "item_number"
        case productName = "product_name"
        case secondProductName = "second_product_name"
        case purchasePrice = "purchase_price"
        case retailPrice = "retail_price"
        case supplierID = "supplier_id"
        case categoryID = "category_id"
        case stockQuantity = "stock_quantity"
        case deletedAt = "deleted_at"
    }
}
