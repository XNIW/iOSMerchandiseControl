import Foundation

nonisolated enum SyncHistorySessionMode: Sendable, Equatable {
    case fullReconciliation
    case incremental
}

nonisolated struct SyncHistorySessionSummary: Equatable, Sendable {
    var uploaded: Int = 0
    var inserted: Int = 0
    var updated: Int = 0
    var skippedClean: Int = 0
    var skippedDirtyLocal: Int = 0
    var skippedOversized: Int = 0

    var totalChanged: Int {
        uploaded + inserted + updated
    }

    var hasWarnings: Bool {
        skippedDirtyLocal > 0 || skippedOversized > 0
    }
}

nonisolated struct SyncHistorySessionPushPlan: Equatable, Sendable {
    var ownerUserID: UUID
    var pendingChangeCount: Int
    var generatedAt: Date
    var idempotencyKey: String

    init(
        ownerUserID: UUID,
        pendingChangeCount: Int,
        generatedAt: Date = Date(),
        idempotencyKey: String = UUID().uuidString.lowercased()
    ) {
        self.ownerUserID = ownerUserID
        self.pendingChangeCount = max(0, pendingChangeCount)
        self.generatedAt = generatedAt
        self.idempotencyKey = idempotencyKey
    }
}

nonisolated struct SyncHistorySessionPushResult: Equatable, Sendable {
    var plan: SyncHistorySessionPushPlan?
    var summary: SyncHistorySessionSummary

    init(plan: SyncHistorySessionPushPlan? = nil, summary: SyncHistorySessionSummary = SyncHistorySessionSummary()) {
        self.plan = plan
        self.summary = summary
    }

    var totalChanged: Int {
        summary.totalChanged
    }
}

protocol SyncHistorySessionPushProviding: AnyObject {
    func syncHistorySessions(
        ownerUserID: UUID,
        mode: SyncHistorySessionMode
    ) async throws -> SyncHistorySessionSummary
}
