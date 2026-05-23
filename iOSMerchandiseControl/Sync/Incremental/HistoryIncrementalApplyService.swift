import Foundation
import SwiftData

nonisolated struct HistoryIncrementalApplyResult {
    var targetedHistoryFetched = 0
    var inserted = 0
    var updated = 0
    var missingRemoteTombstoned = 0
    var fetchMs = 0
    var applyMs = 0
}

nonisolated struct HistoryIncrementalApplyService {
    private let inventoryService: SupabaseInventoryService

    init(inventoryService: SupabaseInventoryService) {
        self.inventoryService = inventoryService
    }

    func apply(
        sessionIDs: Set<UUID>,
        ownerUserID: UUID,
        modelContainer: ModelContainer
    ) async throws -> HistoryIncrementalApplyResult {
        let historyFetchStarted = mcNowMillis()
        let historyRows = try await inventoryService.fetchSharedSheetSessionsByIDs(
            ownerUserID: ownerUserID,
            sessionIDs: sessionIDs
        )
        let fetchMs = mcNowMillis() - historyFetchStarted

        let historyApplyStarted = mcNowMillis()
        let historyResult = try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            let service = HistorySessionSyncService(remote: inventoryService)
            let result = try service.applyRemoteSharedSheetSessions(
                historyRows,
                ownerUserID: ownerUserID,
                context: context
            )
            if result.insertedCount + result.updatedCount > 0 {
                try context.save()
            }
            return result
        }.value
        let applyMs = mcNowMillis() - historyApplyStarted

        let missingSessionIDs = sessionIDs.subtracting(Set(historyRows.map(\.remoteID)))
        let tombstoned = try await tombstoneMissingRemoteHistory(
            sessionIDs: missingSessionIDs,
            ownerUserID: ownerUserID,
            modelContainer: modelContainer
        )

        return HistoryIncrementalApplyResult(
            targetedHistoryFetched: historyRows.count,
            inserted: historyResult.insertedCount,
            updated: historyResult.updatedCount,
            missingRemoteTombstoned: tombstoned,
            fetchMs: fetchMs,
            applyMs: applyMs
        )
    }

    private func tombstoneMissingRemoteHistory(
        sessionIDs: Set<UUID>,
        ownerUserID: UUID,
        modelContainer: ModelContainer
    ) async throws -> Int {
        guard !sessionIDs.isEmpty else { return 0 }
        return try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            let protected = try pendingRemoteIDs(context: context, ownerUserID: ownerUserID)
            let now = Date()
            var tombstoned = 0
            for remoteID in sessionIDs where !protected.history.contains(remoteID) {
                guard let entry = try fetchHistory(remoteID: remoteID, context: context),
                      entry.remoteDeletedAt == nil else { continue }
                entry.remoteDeletedAt = now
                entry.remoteUpdatedAt = entry.remoteUpdatedAt ?? now
                entry.syncStatus = .syncedSuccessfully
                entry.lastSyncedLocalRevision = entry.localChangeRevision
                tombstoned += 1
            }
            if tombstoned > 0 {
                try context.save()
            }
            return tombstoned
        }.value
    }
}
