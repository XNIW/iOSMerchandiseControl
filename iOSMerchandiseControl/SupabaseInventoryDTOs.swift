import Foundation

nonisolated struct RemoteInventorySupplierRow: Codable, Sendable, Identifiable {
    let id: UUID
    let ownerUserID: UUID
    let name: String
    let updatedAt: String
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case name
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

nonisolated struct RemoteInventoryCategoryRow: Codable, Sendable, Identifiable {
    let id: UUID
    let ownerUserID: UUID
    let name: String
    let updatedAt: String
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case name
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

nonisolated struct RemoteInventoryProductRow: Codable, Sendable, Identifiable {
    let id: UUID
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
    let updatedAt: String
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
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
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
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
    let productID: UUID
    let type: String
    let price: Double
    let effectiveAt: String
    let source: String?
    let note: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case productID = "product_id"
        case type
        case price
        case effectiveAt = "effective_at"
        case source
        case note
        case createdAt = "created_at"
    }
}
