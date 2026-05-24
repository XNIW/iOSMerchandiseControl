import Foundation

protocol SyncAutomaticProductPriceRemoteWriting: Sendable {
    func insertProductPrices(_ payloads: [SyncAutomaticProductPricePayload]) async throws -> [RemoteInventoryProductPriceRow]
}

extension SupabaseInventoryService: SyncAutomaticProductPriceRemoteWriting {}
