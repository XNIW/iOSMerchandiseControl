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
    private let remote: any HistorySessionRemoteWriting

    init(remote: any HistorySessionRemoteWriting) {
        self.remote = remote
    }

    func apply(
        sessionIDs: Set<UUID>,
        ownerUserID: UUID,
        modelContainer: ModelContainer
    ) async throws -> HistoryIncrementalApplyResult {
        let historyFetchStarted = mcNowMillis()
        let historyRows = try await remote.fetchSharedSheetSessionsByIDs(
            ownerUserID: ownerUserID,
            sessionIDs: sessionIDs
        )
        let fetchMs = mcNowMillis() - historyFetchStarted

        let historyApplyStarted = mcNowMillis()
        let historyResult = try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            let result = try Self.applyRemoteSharedSheetSessions(
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

    private static func applyRemoteSharedSheetSessions(
        _ rows: [RemoteSharedSheetSessionRow],
        ownerUserID: UUID,
        context: ModelContext
    ) throws -> HistoryIncrementalApplyRowsResult {
        var result = HistoryIncrementalApplyRowsResult()
        guard !rows.isEmpty else { return result }

        let entries = try context.fetch(FetchDescriptor<HistoryEntry>())
        var byRemoteID: [UUID: HistoryEntry] = [:]
        var byUID: [UUID: HistoryEntry] = [:]
        for entry in entries {
            if let remoteID = entry.remoteID {
                byRemoteID[remoteID] = entry
            }
            byUID[entry.uid] = entry
        }

        for row in rows {
            guard row.ownerUserID == ownerUserID else {
                throw HistorySessionSyncError.ownerMismatch
            }

            let remoteFingerprint = HistorySessionPayloadCodec.fingerprintHash(for: row)
            let remoteDeletedAt = HistorySessionPayloadCodec.parseUpdatedAt(row.deletedAt)
            if let existing = byRemoteID[row.remoteID] ?? byUID[row.remoteID] {
                if remoteDeletedAt != nil {
                    if shouldProtectDirtyLocalEntryFromRemoteTombstone(existing) {
                        result.skippedDirtyLocalCount += 1
                    } else {
                        applyRemoteTombstone(row: row, to: existing, fingerprint: remoteFingerprint)
                        result.updatedCount += 1
                    }
                    continue
                }

                if existing.remotePayloadFingerprint == remoteFingerprint {
                    result.skippedCleanCount += 1
                    continue
                }

                if existing.localChangeRevision > existing.lastSyncedLocalRevision {
                    result.skippedDirtyLocalCount += 1
                    continue
                }

                apply(row: row, to: existing, fingerprint: remoteFingerprint)
                result.updatedCount += 1
            } else {
                if remoteDeletedAt != nil {
                    result.skippedCleanCount += 1
                    continue
                }

                let inserted = makeEntry(from: row, fingerprint: remoteFingerprint)
                context.insert(inserted)
                byRemoteID[row.remoteID] = inserted
                byUID[inserted.uid] = inserted
                result.insertedCount += 1
            }
        }

        return result
    }

    private static func shouldProtectDirtyLocalEntryFromRemoteTombstone(_ entry: HistoryEntry) -> Bool {
        entry.remoteDeletedAt == nil && entry.localChangeRevision > entry.lastSyncedLocalRevision
    }

    private static func apply(
        row: RemoteSharedSheetSessionRow,
        to entry: HistoryEntry,
        fingerprint: String
    ) {
        entry.id = row.remoteID.uuidString.lowercased()
        entry.title = row.displayName
        entry.timestamp = HistorySessionPayloadCodec.parseTimestamp(row.timestamp)
        entry.supplier = row.supplier
        entry.category = row.category
        entry.isManualEntry = row.isManualEntry
        entry.data = row.data
        if entry.originalDataJSON == nil {
            entry.originalDataJSON = try? JSONEncoder().encode(row.data)
        }
        entry.editable = row.sessionOverlay?.editable ?? []
        entry.complete = row.sessionOverlay?.complete ?? []
        let initialSummary = HistoryImportedGridSupport.initialSummary(forGrid: row.data)
        let summary = HistoryEntryRuntimeSummary.compute(from: row.data, complete: entry.complete)
        entry.totalItems = summary.totalItems
        entry.orderTotal = initialSummary.orderTotal
        entry.paymentTotal = summary.paymentTotal
        entry.missingItems = summary.missingItems
        entry.remoteID = row.remoteID
        entry.remoteUpdatedAt = HistorySessionPayloadCodec.parseUpdatedAt(row.updatedAt)
        entry.remotePayloadFingerprint = fingerprint
        entry.remoteDeletedAt = HistorySessionPayloadCodec.parseUpdatedAt(row.deletedAt)
        entry.lastSyncedLocalRevision = entry.localChangeRevision
        entry.syncStatus = .syncedSuccessfully
    }

    private static func applyRemoteTombstone(
        row: RemoteSharedSheetSessionRow,
        to entry: HistoryEntry,
        fingerprint: String
    ) {
        entry.remoteID = row.remoteID
        entry.remoteUpdatedAt = HistorySessionPayloadCodec.parseUpdatedAt(row.updatedAt)
        entry.remoteDeletedAt = HistorySessionPayloadCodec.parseUpdatedAt(row.deletedAt) ?? Date()
        entry.remotePayloadFingerprint = fingerprint
        entry.lastSyncedLocalRevision = entry.localChangeRevision
        entry.syncStatus = .syncedSuccessfully
    }

    private static func makeEntry(
        from row: RemoteSharedSheetSessionRow,
        fingerprint: String
    ) -> HistoryEntry {
        let complete = row.sessionOverlay?.complete ?? []
        let initialSummary = HistoryImportedGridSupport.initialSummary(forGrid: row.data)
        let summary = HistoryEntryRuntimeSummary.compute(from: row.data, complete: complete)
        let entry = HistoryEntry(
            id: row.remoteID.uuidString.lowercased(),
            timestamp: HistorySessionPayloadCodec.parseTimestamp(row.timestamp),
            isManualEntry: row.isManualEntry,
            data: row.data,
            originalDataJSON: try? JSONEncoder().encode(row.data),
            editable: row.sessionOverlay?.editable ?? [],
            complete: complete,
            supplier: row.supplier,
            category: row.category,
            totalItems: summary.totalItems,
            orderTotal: initialSummary.orderTotal,
            paymentTotal: summary.paymentTotal,
            missingItems: summary.missingItems,
            syncStatus: .syncedSuccessfully,
            wasExported: false,
            uid: row.remoteID,
            remoteID: row.remoteID,
            remoteUpdatedAt: HistorySessionPayloadCodec.parseUpdatedAt(row.updatedAt),
            remoteDeletedAt: HistorySessionPayloadCodec.parseUpdatedAt(row.deletedAt),
            remotePayloadFingerprint: fingerprint,
            lastSyncedLocalRevision: 0
        )
        entry.title = row.displayName
        return entry
    }
}

private nonisolated struct HistoryIncrementalApplyRowsResult {
    var insertedCount = 0
    var updatedCount = 0
    var skippedCleanCount = 0
    var skippedDirtyLocalCount = 0
}
