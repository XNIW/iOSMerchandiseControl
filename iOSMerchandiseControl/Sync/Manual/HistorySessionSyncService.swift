import Foundation
import SwiftData

nonisolated final class HistorySessionSyncService {
    private let remote: any HistorySessionRemoteSyncing
    private let pageSize: Int

    init(remote: any HistorySessionRemoteSyncing, pageSize: Int = 500) {
        self.remote = remote
        self.pageSize = max(1, pageSize)
    }

    func pushPendingHistorySessions(
        entries: [HistoryEntry],
        ownerUserID: UUID,
        context: ModelContext,
        includeSynced: Bool = false,
        onProgress: @escaping @MainActor @Sendable (HistorySessionSyncProgress) -> Void = { _ in }
    ) async throws -> HistorySessionPushResult {
        var result = HistorySessionPushResult()
        let uploadEntries = includeSynced ? entries : entries.filter(\.isHistorySessionDirtyForCloud)
        result.skippedCleanCount = includeSynced ? 0 : max(0, entries.count - uploadEntries.count)
        let uploadEntryCount = uploadEntries.count
        await publishProgress(HistorySessionSyncProgress(stage: .pushing, current: 0, total: uploadEntryCount), onProgress: onProgress)
        guard !uploadEntries.isEmpty else { return result }

        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: ownerUserID)
        var uploadPairs: [(entry: HistoryEntry, row: SharedSheetSessionUpsertRow, revision: Int)] = []
        uploadPairs.reserveCapacity(uploadEntries.count)

        for entry in uploadEntries {
            do {
                let snapshot = HistorySessionPayloadSnapshotFactory.snapshot(for: entry, ensureRemoteID: true)
                let row = try HistorySessionPayloadCodec.upsertRow(for: snapshot, ownerUserID: ownerUserID)
                uploadPairs.append((entry, row, entry.localChangeRevision))
            } catch HistorySessionSyncError.overlayTooLarge {
                result.skippedOversizedCount += 1
                entry.syncStatus = .attemptedWithErrors
                _ = try accumulator.recordHistorySessionChange(
                    entry: entry,
                    operation: .upsert,
                    changedFields: ["overlay"]
                )
            }
        }

        guard !uploadPairs.isEmpty else { return result }

        let readBackRows = try await remote.upsertSharedSheetSessions(
            uploadPairs.map(\.row),
            ownerUserID: ownerUserID
        )
        try Task.checkCancellation()
        await publishProgress(HistorySessionSyncProgress(stage: .pushing, current: uploadPairs.count, total: uploadEntryCount), onProgress: onProgress)
        let readBackByRemoteID = Dictionary(uniqueKeysWithValues: readBackRows.map { ($0.remoteID, $0) })

        for (index, pair) in uploadPairs.enumerated() {
            try Task.checkCancellation()
            guard let readBack = readBackByRemoteID[pair.row.remoteID],
                  readBack.ownerUserID == ownerUserID else {
                throw HistorySessionSyncError.readBackMismatch
            }
            let expectedFingerprint = HistorySessionPayloadCodec.fingerprintHash(for: pair.row)
            let fingerprint = HistorySessionPayloadCodec.fingerprintHash(for: readBack)
            guard fingerprint == expectedFingerprint else {
                throw HistorySessionSyncError.readBackMismatch
            }
            pair.entry.markHistorySessionRemoteApplied(
                remoteID: readBack.remoteID,
                remoteUpdatedAt: HistorySessionPayloadCodec.parseUpdatedAt(readBack.updatedAt),
                remoteDeletedAt: HistorySessionPayloadCodec.parseUpdatedAt(readBack.deletedAt),
                fingerprint: fingerprint,
                syncedRevision: pair.revision
            )
            pair.entry.syncStatus = .syncedSuccessfully
            try accumulator.acknowledgeHistorySessionChange(entry: pair.entry)
            result.uploadedCount += 1
            result.pushedRemoteIDs.insert(readBack.remoteID)
            await publishProgress(HistorySessionSyncProgress(stage: .pushing, current: index + 1, total: uploadEntryCount), onProgress: onProgress)
        }

        return result
    }

    func pullHistorySessionsFromCloud(
        ownerUserID: UUID,
        context: ModelContext,
        onProgress: @escaping @MainActor @Sendable (HistorySessionSyncProgress) -> Void = { _ in }
    ) async throws -> HistorySessionPullResult {
        var allRows: [RemoteSharedSheetSessionRow] = []
        var start = 0
        await publishProgress(HistorySessionSyncProgress(stage: .fetching, current: 0), onProgress: onProgress)
        while true {
            let end = start + pageSize - 1
            let page = try await remote.fetchSharedSheetSessionsPage(
                ownerUserID: ownerUserID,
                from: start,
                to: end
            )
            try Task.checkCancellation()
            allRows.append(contentsOf: page)
            let fetchedCount = allRows.count
            await publishProgress(HistorySessionSyncProgress(stage: .fetching, current: fetchedCount), onProgress: onProgress)
            guard page.count == pageSize else { break }
            start += pageSize
            await Task.yield()
        }

        let result = try await applyRemoteSharedSheetSessionsAsync(
            allRows,
            ownerUserID: ownerUserID,
            context: context,
            onProgress: onProgress
        )
        var finalResult = result
        let pruned = try pruneCleanRemoteLinkedEntriesMissingFromFullSnapshot(
            remoteIDs: Set(allRows.map(\.remoteID)),
            context: context
        )
        if pruned > 0 {
            try context.save()
            finalResult.prunedMissingRemoteCount = pruned
        }
        let totalRows = allRows.count
        await publishProgress(HistorySessionSyncProgress(stage: .completed, current: totalRows, total: totalRows), onProgress: onProgress)
        return finalResult
    }

    func applyRemoteSharedSheetSessions(
        _ rows: [RemoteSharedSheetSessionRow],
        ownerUserID: UUID,
        context: ModelContext
    ) throws -> HistorySessionPullResult {
        var result = HistorySessionPullResult()
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

    private func applyRemoteSharedSheetSessionsAsync(
        _ rows: [RemoteSharedSheetSessionRow],
        ownerUserID: UUID,
        context: ModelContext,
        onProgress: @escaping @MainActor @Sendable (HistorySessionSyncProgress) -> Void
    ) async throws -> HistorySessionPullResult {
        var result = HistorySessionPullResult()
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

        var mutationsSinceSave = 0
        let batchSize = max(1, pageSize)
        let rowCount = rows.count
        await publishProgress(HistorySessionSyncProgress(stage: .applying, current: 0, total: rowCount), onProgress: onProgress)

        for (index, row) in rows.enumerated() {
            try Task.checkCancellation()
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
                        mutationsSinceSave += 1
                    }
                } else if existing.remotePayloadFingerprint == remoteFingerprint {
                    result.skippedCleanCount += 1
                } else if existing.localChangeRevision > existing.lastSyncedLocalRevision {
                    result.skippedDirtyLocalCount += 1
                } else {
                    apply(row: row, to: existing, fingerprint: remoteFingerprint)
                    result.updatedCount += 1
                    mutationsSinceSave += 1
                }
            } else {
                if remoteDeletedAt != nil {
                    result.skippedCleanCount += 1
                    await publishProgress(HistorySessionSyncProgress(stage: .applying, current: index + 1, total: rowCount), onProgress: onProgress)
                    continue
                }

                let inserted = makeEntry(from: row, fingerprint: remoteFingerprint)
                context.insert(inserted)
                byRemoteID[row.remoteID] = inserted
                byUID[inserted.uid] = inserted
                result.insertedCount += 1
                mutationsSinceSave += 1
            }

            await publishProgress(HistorySessionSyncProgress(stage: .applying, current: index + 1, total: rowCount), onProgress: onProgress)
            if mutationsSinceSave >= batchSize {
                await publishProgress(HistorySessionSyncProgress(stage: .saving, current: index + 1, total: rowCount), onProgress: onProgress)
                try context.save()
                mutationsSinceSave = 0
                await Task.yield()
            } else if (index + 1).isMultiple(of: batchSize) {
                await Task.yield()
            }
        }

        if mutationsSinceSave > 0 {
            await publishProgress(HistorySessionSyncProgress(stage: .saving, current: rowCount, total: rowCount), onProgress: onProgress)
            try context.save()
            await Task.yield()
        }

        return result
    }

    private func shouldProtectDirtyLocalEntryFromRemoteTombstone(_ entry: HistoryEntry) -> Bool {
        entry.remoteDeletedAt == nil && entry.localChangeRevision > entry.lastSyncedLocalRevision
    }

    private func pruneCleanRemoteLinkedEntriesMissingFromFullSnapshot(
        remoteIDs: Set<UUID>,
        context: ModelContext
    ) throws -> Int {
        let pendingKeys = try fetchActiveHistoryPendingKeys(context: context)
        let entries = try context.fetch(FetchDescriptor<HistoryEntry>())
        var pruned = 0
        for entry in entries {
            guard let remoteID = entry.remoteID,
                  !remoteIDs.contains(remoteID),
                  entry.remoteDeletedAt == nil,
                  entry.localChangeRevision <= entry.lastSyncedLocalRevision,
                  !pendingKeys.contains(LocalPendingChangeLogicalKey.historySession(remoteID: remoteID, uid: entry.uid)) else {
                continue
            }
            context.delete(entry)
            pruned += 1
        }
        return pruned
    }

    private func fetchActiveHistoryPendingKeys(context: ModelContext) throws -> Set<String> {
        let descriptor = FetchDescriptor<LocalPendingChange>()
        let historyKind = LocalPendingChangeEntityKind.historySession.rawValue
        return Set(
            try context.fetch(descriptor)
                .filter { $0.entityKindRaw == historyKind && !$0.status.isTerminal }
                .map(\.logicalKey)
        )
    }

    private func apply(
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

    private func applyRemoteTombstone(
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

    private func publishProgress(
        _ progress: HistorySessionSyncProgress,
        onProgress: @escaping @MainActor @Sendable (HistorySessionSyncProgress) -> Void
    ) async {
        await MainActor.run {
            onProgress(progress)
        }
    }

    private func makeEntry(
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
