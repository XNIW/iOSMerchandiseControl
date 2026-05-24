import Foundation

nonisolated struct SyncAutomaticProductPricePayload: Encodable, Equatable, Sendable {
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
