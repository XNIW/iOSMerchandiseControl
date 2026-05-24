import Foundation

struct ProductPriceRemoteSupabaseAdapter: SyncAutomaticProductPriceRemoteWriting {
    let remote: SupabaseTransportClient

    func insertProductPrices(_ payloads: [SyncAutomaticProductPricePayload]) async throws -> [RemoteInventoryProductPriceRow] {
        try await remote.insertProductPrices(payloads)
    }
}
