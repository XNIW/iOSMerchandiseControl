import Foundation
import SwiftData

final class HistorySessionPushService: SyncHistorySessionPushProviding {
    private let modelContainer: ModelContainer
    private let remote: any HistorySessionRemoteWriting
    private let recorder: (any SyncEventRecording)?

    init(
        modelContainer: ModelContainer,
        remote: any HistorySessionRemoteWriting,
        recorder: (any SyncEventRecording)?
    ) {
        self.modelContainer = modelContainer
        self.remote = remote
        self.recorder = recorder
    }

    func syncHistorySessions(
        ownerUserID: UUID,
        mode: SyncHistorySessionMode
    ) async throws -> SyncHistorySessionSummary {
        guard mode == .incremental else {
            return SyncHistorySessionSummary()
        }
        let modelContainer = self.modelContainer
        let remote = self.remote
        let recorder = self.recorder
        return try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            let entries = try context.fetch(
                FetchDescriptor<HistoryEntry>(
                    sortBy: [SortDescriptor(\HistoryEntry.timestamp, order: .reverse)]
                )
            )
            let push = try await Self.pushPendingHistorySessions(
                entries: entries,
                remote: remote,
                ownerUserID: ownerUserID,
                context: context
            )
            try context.save()
            if push.uploadedCount > 0,
               let recorder {
                try await Self.recordHistorySyncEvent(
                    recorder: recorder,
                    ownerUserID: ownerUserID,
                    remoteIDs: Array(push.pushedRemoteIDs)
                )
            }
            return SyncHistorySessionSummary(
                uploaded: push.uploadedCount,
                skippedClean: push.skippedCleanCount,
                skippedOversized: push.skippedOversizedCount
            )
        }.value
    }

    private static func pushPendingHistorySessions(
        entries: [HistoryEntry],
        remote: any HistorySessionRemoteWriting,
        ownerUserID: UUID,
        context: ModelContext
    ) async throws -> HistorySessionAutomaticPushResult {
        var result = HistorySessionAutomaticPushResult()
        let selectedShopID = ShopContextSelection.selectedShopID(ownerUserID: ownerUserID)
        let storeIdentity = ShopContextSelection.localStoreIdentity(ownerUserID: ownerUserID)
        let scopedEntries = entries.filter {
            $0.isCompatibleWithHistoryScope(
                ownerUserID: ownerUserID,
                selectedShopID: selectedShopID,
                storeIdentity: selectedShopID == nil ? .anonymous : storeIdentity
            )
        }
        let uploadEntries = scopedEntries.filter(\.isHistorySessionDirtyForCloud)
        result.skippedCleanCount = max(0, entries.count - uploadEntries.count)
        guard !uploadEntries.isEmpty else { return result }

        let accumulator = LocalPendingChangeAccumulator(
            context: context,
            ownerUserID: ownerUserID,
            storeIdentity: selectedShopID == nil ? .anonymous : storeIdentity
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
        let readBackByRemoteID = Dictionary(uniqueKeysWithValues: readBackRows.map { ($0.remoteID, $0) })

        for pair in uploadPairs {
            try Task.checkCancellation()
            guard let readBack = readBackByRemoteID[pair.row.remoteID],
                  readBack.ownerUserID == ownerUserID else {
                throw HistorySessionSyncError.readBackMismatch
            }
            pair.entry.assignHistoryScope(
                ownerUserID: ownerUserID,
                selectedShopID: selectedShopID,
                storeIdentity: selectedShopID == nil ? .anonymous : storeIdentity
            )
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
        }

        return result
    }

    private static func recordHistorySyncEvent(
        recorder: any SyncEventRecording,
        ownerUserID: UUID,
        remoteIDs: [UUID]
    ) async throws {
        let request = SyncEventRecordRequest(
            domain: "history",
            eventType: "history_changed",
            changedCount: remoteIDs.count,
            entityIDs: .object([
                "session_ids": .array(
                    remoteIDs
                        .sorted { $0.uuidString < $1.uuidString }
                        .map { .string($0.uuidString.lowercased()) }
                )
            ]),
            metadata: .object([
                "source": .string("automatic_history_session_push"),
                "owner_user_id": .string(ownerUserID.uuidString.lowercased())
            ]),
            shopID: ShopContextSelection.selectedShopID(ownerUserID: ownerUserID),
            source: "ios_automatic_runtime",
            clientEventID: "history-automatic-push:\(UUID().uuidString.lowercased())"
        )
        _ = try await recorder.record(request)
    }
}

private struct HistorySessionAutomaticPushResult {
    var uploadedCount = 0
    var pushedRemoteIDs = Set<UUID>()
    var skippedCleanCount = 0
    var skippedOversizedCount = 0
}
