import Foundation

struct ProductPriceRemoteSupabaseAdapter: SyncAutomaticProductPriceRemoteWriting {
    let remote: SupabaseInventoryService

    func insertProductPrices(_ payloads: [SyncAutomaticProductPricePayload]) async throws -> [RemoteInventoryProductPriceRow] {
        try await remote.insertProductPrices(payloads)
    }
}
