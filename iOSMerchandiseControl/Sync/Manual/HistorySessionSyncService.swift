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
        let selectedShopID = ShopContextSelection.selectedShopID(ownerUserID: ownerUserID)
        let storeIdentity = selectedShopID == nil ? LocalStoreIdentity.anonymous : ShopContextSelection.localStoreIdentity(ownerUserID: ownerUserID)
        let scopedEntries = entries.filter {
            $0.isCompatibleWithHistoryScope(
                ownerUserID: ownerUserID,
                selectedShopID: selectedShopID,
                storeIdentity: storeIdentity
            )
        }
        let uploadEntries = includeSynced ? scopedEntries : scopedEntries.filter(\.isHistorySessionDirtyForCloud)
        result.skippedCleanCount = includeSynced ? 0 : max(0, entries.count - uploadEntries.count)
        let uploadEntryCount = uploadEntries.count
        await publishProgress(HistorySessionSyncProgress(stage: .pushing, current: 0, total: uploadEntryCount), onProgress: onProgress)
        guard !uploadEntries.isEmpty else { return result }

        let accumulator = LocalPendingChangeAccumulator(
            context: context,
            ownerUserID: ownerUserID,
            storeIdentity: storeIdentity
        )
        var uploadPairs: [(entry: HistoryEntry, row: SharedSheetSessionUpsertRow, revision: Int)] = []
        uploadPairs.reserveCapacity(uploadEntries.count)

        for entry in uploadEntries {
            do {
                let snapshot = HistorySessionPayloadSnapshotFactory.snapshot(for: entry, ensureRemoteID: true)
                let row = try HistorySessionPayloadCodec.upsertRow(
                    for: snapshot,
                    ownerUserID: ownerUserID,
                    shopID: selectedShopID
                )
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
        for row in readBackRows {
            guard row.ownerUserID == ownerUserID else {
                throw HistorySessionSyncError.ownerMismatch
            }
            try validateRemotePayloadDates(row)
        }
        await publishProgress(HistorySessionSyncProgress(stage: .pushing, current: uploadPairs.count, total: uploadEntryCount), onProgress: onProgress)
        let readBackByRemoteID = Dictionary(uniqueKeysWithValues: readBackRows.map { ($0.remoteID, $0) })

        for (index, pair) in uploadPairs.enumerated() {
            try Task.checkCancellation()
            guard let readBack = readBackByRemoteID[pair.row.remoteID],
                  readBack.ownerUserID == ownerUserID else {
                throw HistorySessionSyncError.readBackMismatch
            }
            pair.entry.assignHistoryScope(
                ownerUserID: ownerUserID,
                selectedShopID: selectedShopID,
                storeIdentity: storeIdentity
            )
            let expectedFingerprint = HistorySessionPayloadCodec.fingerprintHash(for: pair.row)
            let fingerprint = HistorySessionPayloadCodec.fingerprintHash(for: readBack)
            guard fingerprint == expectedFingerprint else {
                throw HistorySessionSyncError.readBackMismatch
            }
            pair.entry.markHistorySessionRemoteApplied(
                remoteID: readBack.remoteID,
                remoteUpdatedAt: try HistorySessionPayloadCodec.parseUpdatedAtStrict(
                    readBack.updatedAt
                ),
                remoteDeletedAt: try HistorySessionPayloadCodec.parseUpdatedAtStrict(
                    readBack.deletedAt
                ),
                fingerprint: fingerprint,
                syncedRevision: pair.revision
            )
            pair.entry.syncStatus = .syncedSuccessfully
            try accumulator.acknowledgeHistorySessionChange(entry: pair.entry)
            result.uploadedCount += 1
            result.pushedRemoteIDs.insert(readBack.remoteID)
            if pair.row.deletedAt != nil {
                result.pushedTombstoneRemoteIDs.insert(readBack.remoteID)
            }
            await publishProgress(HistorySessionSyncProgress(stage: .pushing, current: index + 1, total: uploadEntryCount), onProgress: onProgress)
        }

        return result
    }

    func pullHistorySessionsFromCloud(
        ownerUserID: UUID,
        context: ModelContext,
        automaticScope: Task126VerifiedOwnerStoreScope? = nil,
        automaticScopeValidator: @escaping @Sendable (Task126VerifiedOwnerStoreScope) throws -> Void = {
            try Task126OwnerStoreGate.revalidateAutomaticScope($0)
        },
        onProgress: @escaping @MainActor @Sendable (HistorySessionSyncProgress) -> Void = { _ in }
    ) async throws -> HistorySessionPullResult {
        let pullScope = try resolvePullScope(
            ownerUserID: ownerUserID,
            automaticScope: automaticScope,
            automaticScopeValidator: automaticScopeValidator
        )
        var allRows: [RemoteSharedSheetSessionRow] = []
        var start = 0
        await publishProgress(HistorySessionSyncProgress(stage: .fetching, current: 0), onProgress: onProgress)
        while true {
            try revalidate(pullScope, ownerUserID: ownerUserID)
            let end = start + pageSize - 1
            let page = try await remote.fetchSharedSheetSessionsPage(
                ownerUserID: ownerUserID,
                from: start,
                to: end
            )
            try Task.checkCancellation()
            try revalidate(pullScope, ownerUserID: ownerUserID)
            try validateRemoteRows(page, ownerUserID: ownerUserID, pullScope: pullScope)
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
            pullScope: pullScope,
            onProgress: onProgress
        )
        var finalResult = result
        try revalidateOrRollback(pullScope, ownerUserID: ownerUserID, context: context)
        let pruned = try pruneCleanRemoteLinkedEntriesMissingFromFullSnapshot(
            remoteIDs: Set(allRows.map(\.remoteID)),
            ownerUserID: ownerUserID,
            context: context,
            selectedShopID: pullScope.selectedShopID,
            storeIdentity: pullScope.storeIdentity
        )
        if pruned > 0 {
            try saveOrRollback(
                context: context,
                pullScope: pullScope,
                ownerUserID: ownerUserID
            )
            finalResult.prunedMissingRemoteCount = pruned
        }
        try revalidateOrRollback(pullScope, ownerUserID: ownerUserID, context: context)
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
        for row in rows {
            guard row.ownerUserID == ownerUserID else {
                throw HistorySessionSyncError.ownerMismatch
            }
            try validateRemotePayloadDates(row)
        }

        let selectedShopID = ShopContextSelection.selectedShopID(ownerUserID: ownerUserID)
        let storeIdentity = selectedShopID == nil ? LocalStoreIdentity.anonymous : ShopContextSelection.localStoreIdentity(ownerUserID: ownerUserID)
        let adoptableRemoteIDs = remoteHistoryIDsEligibleForScopeAdoption(rows, selectedShopID: selectedShopID)
        let entries = try context.fetch(FetchDescriptor<HistoryEntry>()).filter {
            $0.isCompatibleWithHistoryScope(
                ownerUserID: ownerUserID,
                selectedShopID: selectedShopID,
                storeIdentity: storeIdentity
            ) || $0.isAdoptableByRemoteHistoryIdentity(
                ownerUserID: ownerUserID,
                selectedShopID: selectedShopID,
                remoteIDs: adoptableRemoteIDs
            )
        }
        var byRemoteID: [UUID: HistoryEntry] = [:]
        var byUID: [UUID: HistoryEntry] = [:]
        for entry in entries {
            if let remoteID = entry.remoteID {
                byRemoteID[remoteID] = entry
            }
            byUID[entry.uid] = entry
        }
        var byLogicalFingerprint = logicalFingerprintMap(for: entries)
        let accumulator = LocalPendingChangeAccumulator(
            context: context,
            ownerUserID: ownerUserID,
            storeIdentity: storeIdentity
        )

        for row in rows {
            guard row.ownerUserID == ownerUserID else {
                throw HistorySessionSyncError.ownerMismatch
            }

            let remoteFingerprint = HistorySessionPayloadCodec.fingerprintHash(for: row)
            let logicalFingerprint = HistorySessionPayloadCodec.logicalFingerprintHash(for: row)
            let remoteDeletedAt = try HistorySessionPayloadCodec.parseUpdatedAtStrict(row.deletedAt)
            let identityMatch = byRemoteID[row.remoteID] ?? byUID[row.remoteID]
            let logicalMatch = identityMatch == nil ? byLogicalFingerprint[logicalFingerprint] : nil
            if let existing = identityMatch ?? logicalMatch {
                if remoteDeletedAt != nil {
                    if shouldProtectDirtyLocalEntryFromRemoteTombstone(existing) {
                        result.skippedDirtyLocalCount += 1
                    } else {
                        existing.assignHistoryScope(ownerUserID: ownerUserID, selectedShopID: row.shopID, storeIdentity: storeIdentity)
                        try applyRemoteTombstone(row: row, to: existing, fingerprint: remoteFingerprint)
                        result.updatedCount += 1
                    }
                    continue
                }

                if logicalMatch != nil {
                    let previousRemoteID = existing.remoteID
                    existing.assignHistoryScope(ownerUserID: ownerUserID, selectedShopID: row.shopID, storeIdentity: storeIdentity)
                    try apply(row: row, to: existing, fingerprint: remoteFingerprint)
                    try accumulator.acknowledgeHistorySessionChange(
                        entry: existing,
                        previousRemoteID: previousRemoteID
                    )
                    byRemoteID[row.remoteID] = existing
                    byUID[existing.uid] = existing
                    byLogicalFingerprint[logicalFingerprint] = existing
                    result.updatedCount += 1
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

                existing.assignHistoryScope(ownerUserID: ownerUserID, selectedShopID: row.shopID, storeIdentity: storeIdentity)
                try apply(row: row, to: existing, fingerprint: remoteFingerprint)
                result.updatedCount += 1
            } else {
                if remoteDeletedAt != nil {
                    result.skippedCleanCount += 1
                    continue
                }

                let inserted = try makeEntry(from: row, fingerprint: remoteFingerprint)
                inserted.assignHistoryScope(ownerUserID: ownerUserID, selectedShopID: row.shopID, storeIdentity: storeIdentity)
                context.insert(inserted)
                byRemoteID[row.remoteID] = inserted
                byUID[inserted.uid] = inserted
                byLogicalFingerprint[logicalFingerprint] = inserted
                result.insertedCount += 1
            }
        }

        return result
    }

    private func applyRemoteSharedSheetSessionsAsync(
        _ rows: [RemoteSharedSheetSessionRow],
        ownerUserID: UUID,
        context: ModelContext,
        pullScope: HistorySessionResolvedPullScope,
        onProgress: @escaping @MainActor @Sendable (HistorySessionSyncProgress) -> Void
    ) async throws -> HistorySessionPullResult {
        var result = HistorySessionPullResult()
        guard !rows.isEmpty else { return result }

        let selectedShopID = pullScope.selectedShopID
        let storeIdentity = pullScope.storeIdentity
        let adoptableRemoteIDs = remoteHistoryIDsEligibleForScopeAdoption(rows, selectedShopID: selectedShopID)
        let entries = try context.fetch(FetchDescriptor<HistoryEntry>()).filter {
            $0.isCompatibleWithHistoryScope(
                ownerUserID: ownerUserID,
                selectedShopID: selectedShopID,
                storeIdentity: storeIdentity
            ) || $0.isAdoptableByRemoteHistoryIdentity(
                ownerUserID: ownerUserID,
                selectedShopID: selectedShopID,
                remoteIDs: adoptableRemoteIDs
            )
        }
        var byRemoteID: [UUID: HistoryEntry] = [:]
        var byUID: [UUID: HistoryEntry] = [:]
        for entry in entries {
            if let remoteID = entry.remoteID {
                byRemoteID[remoteID] = entry
            }
            byUID[entry.uid] = entry
        }
        var byLogicalFingerprint = logicalFingerprintMap(for: entries)
        let accumulator = LocalPendingChangeAccumulator(
            context: context,
            ownerUserID: ownerUserID,
            storeIdentity: storeIdentity
        )

        var mutationsSinceSave = 0
        let batchSize = max(1, pageSize)
        let rowCount = rows.count
        await publishProgress(HistorySessionSyncProgress(stage: .applying, current: 0, total: rowCount), onProgress: onProgress)
        try revalidateOrRollback(pullScope, ownerUserID: ownerUserID, context: context)

        for (index, row) in rows.enumerated() {
            try Task.checkCancellation()
            guard row.ownerUserID == ownerUserID else {
                throw HistorySessionSyncError.ownerMismatch
            }

            let remoteFingerprint = HistorySessionPayloadCodec.fingerprintHash(for: row)
            let logicalFingerprint = HistorySessionPayloadCodec.logicalFingerprintHash(for: row)
            let remoteDeletedAt = try HistorySessionPayloadCodec.parseUpdatedAtStrict(row.deletedAt)
            let identityMatch = byRemoteID[row.remoteID] ?? byUID[row.remoteID]
            let logicalMatch = identityMatch == nil ? byLogicalFingerprint[logicalFingerprint] : nil
            if let existing = identityMatch ?? logicalMatch {
                if remoteDeletedAt != nil {
                    if shouldProtectDirtyLocalEntryFromRemoteTombstone(existing) {
                        result.skippedDirtyLocalCount += 1
                    } else {
                        existing.assignHistoryScope(ownerUserID: ownerUserID, selectedShopID: row.shopID, storeIdentity: storeIdentity)
                        try applyRemoteTombstone(row: row, to: existing, fingerprint: remoteFingerprint)
                        result.updatedCount += 1
                        mutationsSinceSave += 1
                    }
                } else if logicalMatch != nil {
                    let previousRemoteID = existing.remoteID
                    existing.assignHistoryScope(ownerUserID: ownerUserID, selectedShopID: row.shopID, storeIdentity: storeIdentity)
                    try apply(row: row, to: existing, fingerprint: remoteFingerprint)
                    try accumulator.acknowledgeHistorySessionChange(
                        entry: existing,
                        previousRemoteID: previousRemoteID
                    )
                    byRemoteID[row.remoteID] = existing
                    byUID[existing.uid] = existing
                    byLogicalFingerprint[logicalFingerprint] = existing
                    result.updatedCount += 1
                    mutationsSinceSave += 1
                } else if existing.remotePayloadFingerprint == remoteFingerprint {
                    result.skippedCleanCount += 1
                } else if existing.localChangeRevision > existing.lastSyncedLocalRevision {
                    result.skippedDirtyLocalCount += 1
                } else {
                    existing.assignHistoryScope(ownerUserID: ownerUserID, selectedShopID: row.shopID, storeIdentity: storeIdentity)
                    try apply(row: row, to: existing, fingerprint: remoteFingerprint)
                    result.updatedCount += 1
                    mutationsSinceSave += 1
                }
            } else {
                if remoteDeletedAt != nil {
                    result.skippedCleanCount += 1
                    await publishProgress(HistorySessionSyncProgress(stage: .applying, current: index + 1, total: rowCount), onProgress: onProgress)
                    continue
                }

                let inserted = try makeEntry(from: row, fingerprint: remoteFingerprint)
                inserted.assignHistoryScope(ownerUserID: ownerUserID, selectedShopID: row.shopID, storeIdentity: storeIdentity)
                context.insert(inserted)
                byRemoteID[row.remoteID] = inserted
                byUID[inserted.uid] = inserted
                byLogicalFingerprint[logicalFingerprint] = inserted
                result.insertedCount += 1
                mutationsSinceSave += 1
            }

            await publishProgress(HistorySessionSyncProgress(stage: .applying, current: index + 1, total: rowCount), onProgress: onProgress)
            if mutationsSinceSave >= batchSize {
                await publishProgress(HistorySessionSyncProgress(stage: .saving, current: index + 1, total: rowCount), onProgress: onProgress)
                try saveOrRollback(
                    context: context,
                    pullScope: pullScope,
                    ownerUserID: ownerUserID
                )
                mutationsSinceSave = 0
                await Task.yield()
            } else if (index + 1).isMultiple(of: batchSize) {
                await Task.yield()
            }
        }

        if mutationsSinceSave > 0 {
            await publishProgress(HistorySessionSyncProgress(stage: .saving, current: rowCount, total: rowCount), onProgress: onProgress)
            try saveOrRollback(
                context: context,
                pullScope: pullScope,
                ownerUserID: ownerUserID
            )
            await Task.yield()
        }

        return result
    }

    private func shouldProtectDirtyLocalEntryFromRemoteTombstone(_ entry: HistoryEntry) -> Bool {
        entry.remoteDeletedAt == nil && entry.localChangeRevision > entry.lastSyncedLocalRevision
    }

    private func logicalFingerprintMap(for entries: [HistoryEntry]) -> [String: HistoryEntry] {
        var result: [String: HistoryEntry] = [:]
        for entry in entries where entry.remoteDeletedAt == nil {
            let snapshot = HistorySessionPayloadSnapshotFactory.snapshot(for: entry, ensureRemoteID: false)
            let fingerprint = HistorySessionPayloadCodec.logicalFingerprintHash(for: snapshot)
            result[fingerprint] = result[fingerprint] ?? entry
        }
        return result
    }

    private func remoteHistoryIDsEligibleForScopeAdoption(
        _ rows: [RemoteSharedSheetSessionRow],
        selectedShopID: UUID?
    ) -> Set<UUID> {
        guard let selectedShopID else { return [] }
        return Set(rows.compactMap { $0.shopID == selectedShopID ? $0.remoteID : nil })
    }

    private func pruneCleanRemoteLinkedEntriesMissingFromFullSnapshot(
        remoteIDs: Set<UUID>,
        ownerUserID: UUID,
        context: ModelContext,
        selectedShopID: UUID?,
        storeIdentity: LocalStoreIdentity
    ) throws -> Int {
        let pendingKeys = try fetchActiveHistoryPendingKeys(context: context)
        let entries = try context.fetch(FetchDescriptor<HistoryEntry>())
        var pruned = 0
        for entry in entries {
            guard let remoteID = entry.remoteID,
                  entry.isCompatibleWithHistoryScope(ownerUserID: ownerUserID, selectedShopID: selectedShopID, storeIdentity: storeIdentity),
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

    private func resolvePullScope(
        ownerUserID: UUID,
        automaticScope: Task126VerifiedOwnerStoreScope?,
        automaticScopeValidator: @escaping @Sendable (Task126VerifiedOwnerStoreScope) throws -> Void
    ) throws -> HistorySessionResolvedPullScope {
        if let automaticScope {
            guard automaticScope.ownerUserID == ownerUserID else {
                throw Task126OwnerStoreGateError.scopeChanged
            }
            try automaticScopeValidator(automaticScope)
            return HistorySessionResolvedPullScope(
                selectedShopID: automaticScope.shopID,
                storeIdentity: automaticScope.storeIdentity,
                automaticScope: automaticScope,
                automaticScopeValidator: automaticScopeValidator
            )
        }

        let selectedShopID = ShopContextSelection.selectedShopID(ownerUserID: ownerUserID)
        let storeIdentity = selectedShopID == nil
            ? LocalStoreIdentity.anonymous
            : ShopContextSelection.localStoreIdentity(ownerUserID: ownerUserID)
        return HistorySessionResolvedPullScope(
            selectedShopID: selectedShopID,
            storeIdentity: storeIdentity,
            automaticScope: nil,
            automaticScopeValidator: automaticScopeValidator
        )
    }

    private func validateRemoteRows(
        _ rows: [RemoteSharedSheetSessionRow],
        ownerUserID: UUID,
        pullScope: HistorySessionResolvedPullScope
    ) throws {
        for row in rows {
            guard row.ownerUserID == ownerUserID else {
                throw HistorySessionSyncError.ownerMismatch
            }
            if let automaticScope = pullScope.automaticScope {
                try Task126OwnerStoreGate.validateRemoteIdentity(
                    ownerUserID: row.ownerUserID,
                    shopID: row.shopID,
                    scope: automaticScope
                )
            }
            try validateRemotePayloadDates(row)
        }
    }

    private func validateRemotePayloadDates(
        _ row: RemoteSharedSheetSessionRow
    ) throws {
        guard try HistorySessionPayloadCodec.parseUpdatedAtStrict(row.updatedAt) != nil else {
            throw HistorySessionSyncError.invalidTimestamp
        }
        let deletedAt = try HistorySessionPayloadCodec.parseUpdatedAtStrict(row.deletedAt)
        if deletedAt == nil {
            _ = try HistorySessionPayloadCodec.parseTimestampStrict(row.timestamp)
        }
    }

    private func revalidate(
        _ pullScope: HistorySessionResolvedPullScope,
        ownerUserID: UUID
    ) throws {
        guard let automaticScope = pullScope.automaticScope else { return }
        guard automaticScope.ownerUserID == ownerUserID else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
        try pullScope.automaticScopeValidator(automaticScope)
    }

    private func revalidateOrRollback(
        _ pullScope: HistorySessionResolvedPullScope,
        ownerUserID: UUID,
        context: ModelContext
    ) throws {
        do {
            try revalidate(pullScope, ownerUserID: ownerUserID)
        } catch {
            if pullScope.automaticScope != nil {
                context.rollback()
            }
            throw error
        }
    }

    private func saveOrRollback(
        context: ModelContext,
        pullScope: HistorySessionResolvedPullScope,
        ownerUserID: UUID
    ) throws {
        guard pullScope.automaticScope != nil else {
            try context.save()
            return
        }
        do {
            try revalidate(pullScope, ownerUserID: ownerUserID)
            try Task126OwnerStoreGate.withCurrentAutomaticScopeLeaseIfPresent {
                try context.save()
            }
        } catch {
            context.rollback()
            throw error
        }
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
    ) throws {
        entry.id = row.remoteID.uuidString.lowercased()
        entry.title = row.displayName
        entry.timestamp = try HistorySessionPayloadCodec.parseTimestampStrict(row.timestamp)
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
        entry.remoteUpdatedAt = try HistorySessionPayloadCodec.parseUpdatedAtStrict(row.updatedAt)
        entry.remotePayloadFingerprint = fingerprint
        entry.remoteDeletedAt = try HistorySessionPayloadCodec.parseUpdatedAtStrict(row.deletedAt)
        entry.lastSyncedLocalRevision = entry.localChangeRevision
        entry.syncStatus = .syncedSuccessfully
    }

    private func applyRemoteTombstone(
        row: RemoteSharedSheetSessionRow,
        to entry: HistoryEntry,
        fingerprint: String
    ) throws {
        entry.remoteID = row.remoteID
        guard let remoteUpdatedAt = try HistorySessionPayloadCodec.parseUpdatedAtStrict(
            row.updatedAt
        ),
            let remoteDeletedAt = try HistorySessionPayloadCodec.parseUpdatedAtStrict(
                row.deletedAt
            ) else {
            throw HistorySessionSyncError.invalidTimestamp
        }
        entry.remoteUpdatedAt = remoteUpdatedAt
        entry.remoteDeletedAt = remoteDeletedAt
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
    ) throws -> HistoryEntry {
        let complete = row.sessionOverlay?.complete ?? []
        let initialSummary = HistoryImportedGridSupport.initialSummary(forGrid: row.data)
        let summary = HistoryEntryRuntimeSummary.compute(from: row.data, complete: complete)
        let entry = HistoryEntry(
            id: row.remoteID.uuidString.lowercased(),
            timestamp: try HistorySessionPayloadCodec.parseTimestampStrict(row.timestamp),
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
            remoteUpdatedAt: try HistorySessionPayloadCodec.parseUpdatedAtStrict(row.updatedAt),
            remoteDeletedAt: try HistorySessionPayloadCodec.parseUpdatedAtStrict(row.deletedAt),
            remotePayloadFingerprint: fingerprint,
            lastSyncedLocalRevision: 0
        )
        entry.title = row.displayName
        return entry
    }
}

private nonisolated struct HistorySessionResolvedPullScope: Sendable {
    let selectedShopID: UUID?
    let storeIdentity: LocalStoreIdentity
    let automaticScope: Task126VerifiedOwnerStoreScope?
    let automaticScopeValidator: @Sendable (Task126VerifiedOwnerStoreScope) throws -> Void
}
