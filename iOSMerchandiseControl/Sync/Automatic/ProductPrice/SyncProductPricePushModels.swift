import Foundation

nonisolated struct SyncProductPricePushPlan: Equatable, Sendable {
    var ownerUserID: UUID
    var pendingChangeCount: Int
    var generatedAt: Date
    var idempotencyKey: String
    var blockers: [String]

    init(
        ownerUserID: UUID,
        pendingChangeCount: Int,
        generatedAt: Date = Date(),
        idempotencyKey: String = UUID().uuidString.lowercased(),
        blockers: [String] = []
    ) {
        self.ownerUserID = ownerUserID
        self.pendingChangeCount = max(0, pendingChangeCount)
        self.generatedAt = generatedAt
        self.idempotencyKey = idempotencyKey
        self.blockers = blockers
    }

    var hasWork: Bool {
        pendingChangeCount > 0 && blockers.isEmpty
    }
}

nonisolated struct SyncProductPricePushResult: Equatable, Sendable {
    var plan: SyncProductPricePushPlan? = nil
    var insertedCount: Int = 0
    var orphanedCount: Int = 0
    var tombstonedCount: Int = 0
}

protocol SyncProductPriceSyncProviding: AnyObject {
    func pushPendingProductPrices(ownerUserID: UUID) async throws -> SyncProductPricePushResult
}
