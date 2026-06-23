import Foundation

nonisolated struct SyncAutomaticProductPricePayload: Encodable, Equatable, Sendable {
    let id: UUID
    let ownerUserID: UUID
    let shopID: UUID?
    let productID: UUID
    let type: String
    let price: Double
    let effectiveAt: String
    let source: String?
    let note: String?
    let createdAt: String

    init(
        id: UUID,
        ownerUserID: UUID,
        shopID: UUID? = nil,
        productID: UUID,
        type: String,
        price: Double,
        effectiveAt: String,
        source: String?,
        note: String?,
        createdAt: String
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.shopID = shopID
        self.productID = productID
        self.type = type
        self.price = price
        self.effectiveAt = effectiveAt
        self.source = source
        self.note = note
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case shopID = "shop_id"
        case productID = "product_id"
        case type
        case price
        case effectiveAt = "effective_at"
        case source
        case note
        case createdAt = "created_at"
    }
}
