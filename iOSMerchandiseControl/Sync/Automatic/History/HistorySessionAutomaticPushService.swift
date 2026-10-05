import Foundation
import SwiftData

final class HistorySessionPushService: SyncHistorySessionPushProviding {
    // The backend history RPC is deliberately kept in very small requests.
    // A run may make several bounded requests so a recovery can drain normal
    // backlogs without ever constructing an unbounded body in memory.
    nonisolated static let maximumRowsPerRequest = 3
    nonisolated static let maximumRequestsPerRun = 64
    nonisolated static let maximumHistoryRowBytes = 512 * 1_024
    nonisolated static let maximumHistoryRequestBytes = 1_500 * 1_024
    nonisolated static let maximumCandidateScan = 64

    private let modelContainer: ModelContainer
    private let remote: any HistorySessionRemoteWriting
    private let defaults: UserDefaults

    init(
        modelContainer: ModelContainer,
        remote: any HistorySessionRemoteWriting,
        recorder: (any SyncEventRecording)?,
        defaults: UserDefaults = .standard
    ) {
        self.modelContainer = modelContainer
        self.remote = remote
        _ = recorder
        self.defaults = defaults
    }

    /// Recovery may explain C with our original attempted body, but it must
    /// leave that immutable attempt pending until its actual response is ACKed.
    nonisolated static func sealedAttemptExplainsHistoryFingerprint(
        _ fingerprint: String, entry: SyncEventOutboxEntry, change: LocalPendingChange,
        localHistory: HistoryEntry, scope: Task126VerifiedOwnerStoreScope
    ) throws -> Bool {
        let data = try LocalPendingBusinessAttemptStore.validate(entry, kind: "history", scope: scope)
        let envelope = try JSONDecoder().decode(LocalPendingBusinessAttemptStore.Envelope<StoredHistoryUpload>.self, from: data)
        let upload = envelope.payload
        guard envelope.pending.matches(change), change.entityKind == .historySession,
              upload.localUID == localHistory.uid,
              upload.row.remoteID == change.entityRemoteID,
              upload.row.remoteID == localHistory.remoteID,
              upload.row.ownerUserID == scope.ownerUserID, upload.row.shopID == scope.shopID,
              upload.revision > localHistory.lastSyncedLocalRevision,
              upload.revision <= localHistory.localChangeRevision,
              HistorySessionPayloadCodec.fingerprintHash(for: upload.row) == upload.payloadFingerprint else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        return upload.payloadFingerprint == fingerprint
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
        let defaults = self.defaults
        return try await Task.detached(priority: .utility) {
            let scope = try Task126OwnerStoreGate.captureAutomaticScope(
                ownerUserID: ownerUserID,
                defaults: defaults,
                allowsPendingSameScopeRecovery: true
            )
            var total = SyncHistorySessionSummary()
            for _ in 0..<Self.maximumRequestsPerRun {
                let prepared = try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                    scope,
                    defaults: defaults
                ) {
                    try Task126OwnerStoreGate.validateLocalMutationContainerWithLeaseHeld(
                        modelContainer
                    )
                    let result = try Self.preparePendingHistorySessions(
                        modelContainer: modelContainer,
                        ownerUserID: ownerUserID,
                        scope: scope
                    )
                    Task126OwnerStoreGate.finishAcceptedLocalWriteWithLeaseHeld(modelContainer)
                    return result
                }
                total.skippedClean += prepared.skippedCleanCount
                total.skippedOversized += prepared.skippedOversizedCount
                guard !prepared.uploads.isEmpty else { return total }

                try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
                let readBackRows = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                    try await remote.upsertSharedSheetSessions(
                        prepared.uploads.map(\.row),
                        ownerUserID: ownerUserID
                    )
                }
                try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
                for row in readBackRows {
                    try Task126OwnerStoreGate.validateRemoteIdentity(
                        ownerUserID: row.ownerUserID,
                        shopID: row.shopID,
                        scope: scope
                    )
                }
                let expectedIDs = Set(prepared.uploads.map(\.row.remoteID))
                let readBackIDs = Set(readBackRows.map(\.remoteID))
                guard readBackRows.count == expectedIDs.count,
                      readBackIDs == expectedIDs else {
                    throw HistorySessionSyncError.readBackMismatch
                }
                let readBackByRemoteID = Dictionary(
                    uniqueKeysWithValues: readBackRows.map { ($0.remoteID, $0) }
                )
                let push = try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                    scope,
                    defaults: defaults
                ) {
                    try Task126OwnerStoreGate.validateLocalMutationContainerWithLeaseHeld(
                        modelContainer
                    )
                    let result = try Self.applyReadBacksIfCurrent(
                        prepared: prepared,
                        readBackByRemoteID: readBackByRemoteID,
                        modelContainer: modelContainer,
                        ownerUserID: ownerUserID,
                        scope: scope
                    )
                    Task126OwnerStoreGate.finishAcceptedLocalWriteWithLeaseHeld(modelContainer)
                    return result
                }
                total.uploaded += push.uploadedCount
            }
            return total
        }.value
    }

    private nonisolated static func preparePendingHistorySessions(
        modelContainer: ModelContainer,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) throws -> HistorySessionAutomaticPreparation {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        let owner = ownerUserID.uuidString.lowercased()
        let storeID = scope.storeIdentity.storeId
        let history = LocalPendingChangeEntityKind.historySession.rawValue
        let pending = LocalPendingChangeStatus.pending.rawValue
        var descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.ownerUserID == owner
                    && change.storeId == storeID
                    && change.entityKindRaw == history
                    && change.statusRaw == pending
            },
            sortBy: [
                SortDescriptor(\LocalPendingChange.updatedAt, order: .forward),
                SortDescriptor(\LocalPendingChange.changeID, order: .forward)
            ]
        )
        descriptor.fetchLimit = maximumCandidateScan
        let pendingChanges = try context.fetch(descriptor)
        var prepared = HistorySessionAutomaticPreparation()
        guard !pendingChanges.isEmpty else { return prepared }

        prepared.uploads.reserveCapacity(min(maximumRowsPerRequest, pendingChanges.count))
        var requestBytes = 2 // JSON array delimiters.
        var selectedRemoteIDs = Set<UUID>()

        for change in pendingChanges {
            guard prepared.uploads.count < maximumRowsPerRequest else { break }
            guard let remoteID = change.entityRemoteID else {
                change.status = .blocked
                change.updatedAt = Date()
                continue
            }
            // A predecessor and its later local revision must be acknowledged
            // in order, never submitted twice for one UID in the same batch.
            guard !selectedRemoteIDs.contains(remoteID) else { continue }
            if let stored = try LocalPendingBusinessAttemptStore.load(StoredHistoryUpload.self,
                change: change, kind: "history", context: context, scope: scope) {
                let bytes = try JSONEncoder().encode(stored.row).count
                guard bytes <= maximumHistoryRowBytes,
                      requestBytes + (prepared.uploads.isEmpty ? 0 : 1) + bytes <= maximumHistoryRequestBytes,
                      stored.row.ownerUserID == ownerUserID, stored.row.shopID == scope.shopID,
                      stored.row.remoteID == remoteID,
                      HistorySessionPayloadCodec.fingerprintHash(for: stored.row) == stored.payloadFingerprint else {
                    throw HistorySessionSyncError.readBackMismatch
                }
                prepared.uploads.append(HistorySessionAutomaticPreparedUpload(localUID: stored.localUID,
                    row: stored.row, revision: stored.revision, payloadFingerprint: stored.payloadFingerprint,
                    pending: LocalPendingChangeCASToken(change)))
                requestBytes += bytes + (prepared.uploads.count == 1 ? 0 : 1)
                selectedRemoteIDs.insert(remoteID)
                continue
            }
            var entryDescriptor = FetchDescriptor<HistoryEntry>(
                predicate: #Predicate<HistoryEntry> { entry in
                    entry.remoteID == remoteID || entry.uid == remoteID
                }
            )
            entryDescriptor.fetchLimit = 2
            let matches = try context.fetch(entryDescriptor)
            guard matches.count == 1,
                  let entry = matches.first,
                  entry.isCompatibleWithHistoryScope(
                    ownerUserID: ownerUserID,
                    selectedShopID: scope.shopID,
                    storeIdentity: scope.storeIdentity
                  ) else {
                change.status = .blocked
                change.updatedAt = Date()
                continue
            }
            do {
                let snapshot = HistorySessionPayloadSnapshotFactory.snapshot(for: entry, ensureRemoteID: true)
                let row = try HistorySessionPayloadCodec.upsertRow(
                    for: snapshot,
                    ownerUserID: ownerUserID,
                    shopID: scope.shopID
                )
                let rowBytes = try JSONEncoder().encode(row).count
                guard rowBytes <= maximumHistoryRowBytes else {
                    throw HistorySessionSyncError.payloadTooLarge
                }
                let separatorBytes = prepared.uploads.isEmpty ? 0 : 1
                guard requestBytes + separatorBytes + rowBytes <= maximumHistoryRequestBytes else {
                    break
                }
                change.lastAttemptAt = Date()
                let token = LocalPendingChangeCASToken(change)
                let fingerprint = HistorySessionPayloadCodec.fingerprintHash(for: row)
                try LocalPendingBusinessAttemptStore.seal(StoredHistoryUpload(localUID: entry.uid,
                    row: row, revision: entry.localChangeRevision, payloadFingerprint: fingerprint),
                    pending: token, kind: "history", context: context, scope: scope)
                prepared.uploads.append(HistorySessionAutomaticPreparedUpload(
                    localUID: entry.uid,
                    row: row,
                    revision: entry.localChangeRevision,
                    payloadFingerprint: fingerprint,
                    pending: token
                ))
                requestBytes += separatorBytes + rowBytes
                selectedRemoteIDs.insert(remoteID)
            } catch HistorySessionSyncError.overlayTooLarge,
                    HistorySessionSyncError.payloadTooLarge {
                prepared.skippedOversizedCount += 1
                entry.syncStatus = .attemptedWithErrors
                change.status = .blocked
                change.updatedAt = Date()
            }
        }
        // Persist generated remote identities and oversized blockers before the
        // async RPC. A crash or concurrent local edit can then retry the same
        // remote identity without creating a duplicate session.
        try context.save()
        return prepared
    }

    private nonisolated static func applyReadBacksIfCurrent(
        prepared: HistorySessionAutomaticPreparation,
        readBackByRemoteID: [UUID: RemoteSharedSheetSessionRow],
        modelContainer: ModelContainer,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) throws -> HistorySessionAutomaticPushResult {
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        var result = HistorySessionAutomaticPushResult()
        for upload in prepared.uploads {
            guard let readBack = readBackByRemoteID[upload.row.remoteID],
                  readBack.ownerUserID == ownerUserID,
                  readBack.shopID == scope.shopID else {
                throw HistorySessionSyncError.readBackMismatch
            }
            let remoteUpdatedAt = try HistorySessionPayloadCodec.parseUpdatedAtStrict(
                readBack.updatedAt
            )
            let remoteDeletedAt = try HistorySessionPayloadCodec.parseUpdatedAtStrict(
                readBack.deletedAt
            )
            let uploadedDeletedAt = try HistorySessionPayloadCodec.parseUpdatedAtStrict(
                upload.row.deletedAt
            )
            guard remoteDeletedAt == uploadedDeletedAt else {
                throw HistorySessionSyncError.readBackMismatch
            }
            let fingerprint = HistorySessionPayloadCodec.fingerprintHash(for: readBack)
            guard fingerprint == upload.payloadFingerprint else {
                throw HistorySessionSyncError.readBackMismatch
            }
            result.uploadedCount += 1
            result.pushedRemoteIDs.insert(readBack.remoteID)
            if uploadedDeletedAt != nil {
                result.pushedTombstoneRemoteIDs.insert(readBack.remoteID)
            }

            let uid = upload.localUID
            let descriptor = FetchDescriptor<HistoryEntry>(
                predicate: #Predicate<HistoryEntry> { $0.uid == uid }
            )
            guard let entry = try context.fetch(descriptor).first,
                  entry.remoteID == upload.row.remoteID,
                  entry.localChangeRevision >= upload.revision,
                  entry.isCompatibleWithHistoryScope(
                    ownerUserID: ownerUserID,
                    selectedShopID: scope.shopID,
                    storeIdentity: scope.storeIdentity
                  ),
                  entry.remoteUpdatedAt.map({ current in
                    guard let remoteUpdatedAt else { return false }
                    return current <= remoteUpdatedAt
                  }) ?? true else {
                // The upload succeeded, but a newer local or incremental commit
                // won the race. Keep its pending row untouched for the next push.
                continue
            }
            let currentSnapshot = HistorySessionPayloadSnapshotFactory.snapshot(
                for: entry,
                ensureRemoteID: false
            )
            let currentRow = try HistorySessionPayloadCodec.upsertRow(
                for: currentSnapshot,
                ownerUserID: ownerUserID,
                shopID: scope.shopID
            )
            let changeID = upload.pending.changeID
            var pendingDescriptor = FetchDescriptor<LocalPendingChange>(predicate: #Predicate { $0.changeID == changeID })
            pendingDescriptor.fetchLimit = 1
            guard let pending = try context.fetch(pendingDescriptor).first,
                  upload.pending.matches(pending) else { continue }
            let logicalKey = upload.pending.logicalKey
            let owner = ownerUserID.uuidString.lowercased()
            let store = scope.storeIdentity.storeId
            var dependentDescriptor = FetchDescriptor<LocalPendingChange>(predicate: #Predicate<LocalPendingChange> {
                $0.logicalKey == logicalKey && $0.entityKindRaw == "historySession" && $0.statusRaw == "pending"
            })
            dependentDescriptor.fetchLimit = LocalPendingChangeAccumulator.defaultMaxActiveChanges + 1
            let candidates = try context.fetch(dependentDescriptor)
            guard candidates.count <= LocalPendingChangeAccumulator.defaultMaxActiveChanges else {
                throw HistorySessionSyncError.readBackMismatch
            }
            let dependents = candidates.filter {
                $0.changeID != changeID && $0.ownerUserID == owner && $0.storeId == store
                    && $0.lastAttemptAt == nil
                    && LocalPendingChangeScopeMatcher.matches($0, ownerUserID: ownerUserID,
                        accountHash: scope.accountHash, storeIdentity: scope.storeIdentity)
            }
            guard dependents.count <= 1 else { throw HistorySessionSyncError.readBackMismatch }
            let currentBodyMatches = HistorySessionPayloadCodec.fingerprintHash(for: currentRow) == upload.payloadFingerprint
            guard currentBodyMatches || (entry.localChangeRevision > upload.revision && !dependents.isEmpty) else { continue }
            entry.assignHistoryScope(
                ownerUserID: ownerUserID,
                selectedShopID: scope.shopID,
                storeIdentity: scope.storeIdentity
            )
            entry.markHistorySessionRemoteApplied(
                remoteID: readBack.remoteID,
                remoteUpdatedAt: remoteUpdatedAt,
                remoteDeletedAt: remoteDeletedAt,
                fingerprint: fingerprint,
                syncedRevision: upload.revision
            )
            try LocalCatalogBodyProofStore.record(readBack, context: context, scope: scope)
            if entry.localChangeRevision == upload.revision { entry.syncStatus = .syncedSuccessfully }
            pending.status = .acknowledged
            pending.updatedAt = Date()
            for dependent in dependents {
                dependent.baselineFingerprintHash = upload.payloadFingerprint
                dependent.baseRemoteUpdatedAt = remoteUpdatedAt
            }
            try LocalPendingBusinessAttemptStore.remove(changeID: changeID, context: context)
        }
        try enqueueHistorySyncEventWithLeaseHeld(
            context: context,
            ownerUserID: ownerUserID,
            pushedRemoteIDs: Array(result.pushedRemoteIDs),
            tombstoneRemoteIDs: Array(result.pushedTombstoneRemoteIDs),
            scope: scope
        )
        try context.save()
        return result
    }

    private nonisolated static func enqueueHistorySyncEventWithLeaseHeld(
        context: ModelContext,
        ownerUserID: UUID,
        pushedRemoteIDs: [UUID],
        tombstoneRemoteIDs: [UUID],
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        guard !pushedRemoteIDs.isEmpty else { return }
        let allIDs = Set(pushedRemoteIDs)
        let tombstones = allIDs.intersection(tombstoneRemoteIDs)
        let changed = allIDs.subtracting(tombstones)
        let groups: [(eventType: String, ids: [UUID])] = [
            ("history_changed", changed.sorted { $0.uuidString < $1.uuidString }),
            ("history_tombstone", tombstones.sorted { $0.uuidString < $1.uuidString })
        ]

        for group in groups where !group.ids.isEmpty {
            try AutomaticSyncEventOutboxWriter.enqueueWithValidatedScopeLeaseHeld(
                context: context,
                ownerUserID: ownerUserID,
                domain: "history",
                eventType: group.eventType,
                changedCount: group.ids.count,
                entityIDs: try AutomaticSyncEventOutboxWriter.entityIDs([
                    "session_ids": group.ids
                ]),
                metadata: .object([
                    "source": .string("ios"),
                    "uploaded_count": .number(Double(group.ids.count))
                ]),
                source: "ios_history_automatic_push",
                entityIDsShape: "session_ids:count=\(group.ids.count)",
                metadataShape: "source=ios_history_automatic_push;eventType=\(group.eventType);sessions=\(group.ids.count)",
                clientEventFingerprint: [
                    group.eventType,
                    group.ids.map { $0.uuidString.lowercased() }.joined(separator: ",")
                ].joined(separator: "|"),
                scope: scope
            )
        }
    }

}

private nonisolated struct HistorySessionAutomaticPushResult {
    var uploadedCount = 0
    var pushedRemoteIDs = Set<UUID>()
    var pushedTombstoneRemoteIDs = Set<UUID>()
    var skippedCleanCount = 0
    var skippedOversizedCount = 0
}

private nonisolated struct HistorySessionAutomaticPreparedUpload {
    let localUID: UUID
    let row: SharedSheetSessionUpsertRow
    let revision: Int
    let payloadFingerprint: String
    let pending: LocalPendingChangeCASToken
}

private nonisolated struct StoredHistoryUpload: Codable {
    let localUID: UUID
    let row: SharedSheetSessionUpsertRow
    let revision: Int
    let payloadFingerprint: String
}

private nonisolated struct HistorySessionAutomaticPreparation {
    var uploads: [HistorySessionAutomaticPreparedUpload] = []
    var skippedCleanCount = 0
    var skippedOversizedCount = 0
}
