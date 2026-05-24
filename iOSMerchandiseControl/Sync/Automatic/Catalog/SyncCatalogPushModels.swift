import Foundation

nonisolated struct SyncCatalogPushPlan: Equatable, Sendable {
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

nonisolated struct SyncCatalogPushResult: Equatable, Sendable {
    var plan: SyncCatalogPushPlan? = nil
    var supplierCreates: Int = 0
    var supplierUpdates: Int = 0
    var supplierLinks: Int = 0
    var categoryCreates: Int = 0
    var categoryUpdates: Int = 0
    var categoryLinks: Int = 0
    var productCreates: Int = 0
    var productUpdates: Int = 0
    var productLinks: Int = 0

    var totalChanged: Int {
        supplierCreates + supplierUpdates + supplierLinks
            + categoryCreates + categoryUpdates + categoryLinks
            + productCreates + productUpdates + productLinks
    }
}

protocol SyncCatalogPushProviding: AnyObject {
    func pushPendingCatalog(ownerUserID: UUID) async throws -> SyncCatalogPushResult
}
