import Foundation

nonisolated struct SyncAutomaticSupplierCreatePayload: Encodable, Equatable, Sendable {
    let ownerUserID: UUID
    let name: String

    enum CodingKeys: String, CodingKey {
        case ownerUserID = "owner_user_id"
        case name
    }
}

nonisolated struct SyncAutomaticSupplierUpdatePayload: Encodable, Equatable, Sendable {
    let name: String
}

nonisolated struct SyncAutomaticCategoryCreatePayload: Encodable, Equatable, Sendable {
    let ownerUserID: UUID
    let name: String

    enum CodingKeys: String, CodingKey {
        case ownerUserID = "owner_user_id"
        case name
    }
}

nonisolated struct SyncAutomaticCategoryUpdatePayload: Encodable, Equatable, Sendable {
    let name: String
}

nonisolated struct SyncAutomaticProductCreatePayload: Encodable, Equatable, Sendable {
    let ownerUserID: UUID
    let barcode: String
    let itemNumber: String?
    let productName: String?
    let secondProductName: String?
    let purchasePrice: Double?
    let retailPrice: Double?
    let supplierID: UUID?
    let categoryID: UUID?
    let stockQuantity: Double?

    enum CodingKeys: String, CodingKey {
        case ownerUserID = "owner_user_id"
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
