import Foundation
import SwiftData

nonisolated struct HistoryIncrementalApplyResult {
    var targetedHistoryFetched = 0
    var inserted = 0
    var updated = 0
    var missingRemoteTombstoned = 0
    var missingRemoteCount = 0
    var fetchMs = 0
    var applyMs = 0
}

nonisolated struct HistoryIncrementalFetchResult: Sendable {
    var rows: [RemoteSharedSheetSessionRow] = []
    var fetchMs = 0
}

nonisolated struct HistoryIncrementalApplyService {
    private let remote: any HistorySessionRemoteWriting
    private let scope: Task126VerifiedOwnerStoreScope
    private let defaults: UserDefaults

    init(
        remote: any HistorySessionRemoteWriting,
        scope: Task126VerifiedOwnerStoreScope,
        defaults: UserDefaults = .standard
    ) {
        self.remote = remote
        self.scope = scope
        self.defaults = defaults
    }

    func fetch(
        sessionIDs: Set<UUID>,
        ownerUserID: UUID
    ) async throws -> HistoryIncrementalFetchResult {
        guard !sessionIDs.isEmpty else { return HistoryIncrementalFetchResult() }
        let historyFetchStarted = mcNowMillis()
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        let historyRows = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
            try await remote.fetchSharedSheetSessionsByIDs(
                ownerUserID: ownerUserID,
                sessionIDs: sessionIDs
            )
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        for row in historyRows {
            try validateIncrementalReadIdentity(ownerUserID: row.ownerUserID, shopID: row.shopID, scope: scope, remote: remote)
        }
        return HistoryIncrementalFetchResult(
            rows: historyRows,
            fetchMs: mcNowMillis() - historyFetchStarted
        )
    }

    func apply(
        fetched: HistoryIncrementalFetchResult,
        sessionIDs: Set<UUID>,
        ownerUserID: UUID,
        modelContainer: ModelContainer
    ) async throws -> HistoryIncrementalApplyResult {
        let historyRows = fetched.rows.filter { sessionIDs.contains($0.remoteID) }
        guard sessionIDs.isSubset(of: Set(historyRows.map(\.remoteID))) else {
            throw SyncEventIncrementalApplyError.dynamicPreflightRequired
        }

        let historyApplyStarted = mcNowMillis()
        let historyResult = try await Task.detached(priority: .utility) {
            try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                scope,
                defaults: defaults
            ) {
                try Task126OwnerStoreGate.validateLocalMutationContainerWithLeaseHeld(
                    modelContainer
                )
                let context = ModelContext(modelContainer)
                context.autosaveEnabled = false
                let result = try Self.applyRemoteSharedSheetSessions(
                    historyRows,
                    ownerUserID: ownerUserID,
                    context: context,
                    scope: scope
                )
                if result.insertedCount + result.updatedCount > 0 {
                    try context.save()
                }
                return result
            }
        }.value
        let applyMs = mcNowMillis() - historyApplyStarted

        return HistoryIncrementalApplyResult(
            targetedHistoryFetched: historyRows.count,
            inserted: historyResult.insertedCount,
            updated: historyResult.updatedCount,
            missingRemoteTombstoned: 0,
            missingRemoteCount: 0,
            fetchMs: fetched.fetchMs,
            applyMs: applyMs
        )
    }

    private func tombstoneMissingRemoteHistory(
        sessionIDs: Set<UUID>,
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        scope: Task126VerifiedOwnerStoreScope,
        defaults: UserDefaults
    ) async throws -> Int {
        guard !sessionIDs.isEmpty else { return 0 }
        return try await Task.detached(priority: .utility) {
            try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                scope,
                defaults: defaults
            ) {
                try Task126OwnerStoreGate.validateLocalMutationContainerWithLeaseHeld(
                    modelContainer
                )
                let context = ModelContext(modelContainer)
                context.autosaveEnabled = false
                let protected = try pendingRemoteIDs(
                    context: context,
                    ownerUserID: ownerUserID,
                    storeIdentity: scope.storeIdentity
                )
                let now = Date()
                var tombstoned = 0
                for remoteID in sessionIDs where !protected.history.contains(remoteID) {
                    guard let entry = try fetchHistory(remoteID: remoteID, context: context),
                          entry.isCompatibleWithHistoryScope(ownerUserID: ownerUserID, selectedShopID: scope.shopID, storeIdentity: scope.storeIdentity),
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
            }
        }.value
    }

    static func applyRemoteSharedSheetSessions(
        _ rows: [RemoteSharedSheetSessionRow],
        ownerUserID: UUID,
        context: ModelContext,
        scope: Task126VerifiedOwnerStoreScope
    ) throws -> HistoryIncrementalApplyRowsResult {
        var result = HistoryIncrementalApplyRowsResult()
        guard !rows.isEmpty else { return result }

        let entries = try localEntriesEligibleForIncrementalApply(
            rows,
            ownerUserID: ownerUserID,
            context: context,
            scope: scope
        )
        var byRemoteID: [UUID: HistoryEntry] = [:]
        var byUID: [UUID: HistoryEntry] = [:]
        for entry in entries {
            if let remoteID = entry.remoteID {
                guard byRemoteID[remoteID] == nil else {
                    throw SyncEventIncrementalApplyError.dynamicPreflightRequired
                }
                byRemoteID[remoteID] = entry
            }
            guard byUID[entry.uid] == nil else {
                throw SyncEventIncrementalApplyError.dynamicPreflightRequired
            }
            byUID[entry.uid] = entry
        }
        var byLogicalFingerprint = logicalFingerprintMap(for: entries)
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: ownerUserID, storeIdentity: scope.storeIdentity)

        for row in rows {
            guard let remoteUpdatedAt = try HistorySessionPayloadCodec.parseUpdatedAtStrict(
                row.updatedAt
            ) else {
                throw HistorySessionSyncError.invalidTimestamp
            }
            let remoteDeletedAt = try HistorySessionPayloadCodec.parseUpdatedAtStrict(row.deletedAt)
            let timestamp: Date?
            if remoteDeletedAt == nil {
                guard row.payloadVersion > 0 else {
                    throw HistorySessionSyncError.readBackMismatch
                }
                if let overlay = row.sessionOverlay {
                    guard let data = try? JSONEncoder().encode(overlay),
                          data.count <= HistorySessionPayloadCodec.maxOverlayBytes else {
                        throw HistorySessionSyncError.overlayTooLarge
                    }
                }
                timestamp = try HistorySessionPayloadCodec.parseTimestampStrict(row.timestamp)
            } else {
                timestamp = nil
            }

            let remoteFingerprint = HistorySessionPayloadCodec.fingerprintHash(for: row)
            let logicalFingerprint = HistorySessionPayloadCodec.logicalFingerprintHash(for: row)
            let identityMatch = byRemoteID[row.remoteID] ?? byUID[row.remoteID]
            // Tombstones may resolve only by explicit remote identity. Reusing
            // a payload fingerprint would let an unrelated remote deletion
            // adopt and delete a legacy/local session with identical content.
            let logicalMatch = remoteDeletedAt == nil && identityMatch == nil
                ? byLogicalFingerprint[logicalFingerprint]
                : nil
            if let existing = identityMatch ?? logicalMatch {
                if remoteDeletedAt != nil {
                    if shouldProtectDirtyLocalEntryFromRemoteTombstone(existing) {
                        result.skippedDirtyLocalCount += 1
                        result.skippedDirtyRemoteIDs.insert(row.remoteID)
                    } else {
                        existing.assignHistoryScope(ownerUserID: ownerUserID, selectedShopID: scope.shopID, storeIdentity: scope.storeIdentity)
                        applyRemoteTombstone(
                            row: row,
                            to: existing,
                            fingerprint: remoteFingerprint,
                            remoteUpdatedAt: remoteUpdatedAt,
                            remoteDeletedAt: remoteDeletedAt!
                        )
                        result.updatedCount += 1
                    }
                    continue
                }

                if logicalMatch != nil {
                    let previousRemoteID = existing.remoteID
                    existing.assignHistoryScope(ownerUserID: ownerUserID, selectedShopID: scope.shopID, storeIdentity: scope.storeIdentity)
                    apply(
                        row: row,
                        to: existing,
                        fingerprint: remoteFingerprint,
                        timestamp: timestamp!,
                        remoteUpdatedAt: remoteUpdatedAt
                    )
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
                    result.skippedDirtyRemoteIDs.insert(row.remoteID)
                    continue
                }

                existing.assignHistoryScope(ownerUserID: ownerUserID, selectedShopID: scope.shopID, storeIdentity: scope.storeIdentity)
                apply(
                    row: row,
                    to: existing,
                    fingerprint: remoteFingerprint,
                    timestamp: timestamp!,
                    remoteUpdatedAt: remoteUpdatedAt
                )
                result.updatedCount += 1
            } else {
                if remoteDeletedAt != nil {
                    result.skippedCleanCount += 1
                    continue
                }

                let inserted = makeEntry(
                    from: row,
                    fingerprint: remoteFingerprint,
                    timestamp: timestamp!,
                    remoteUpdatedAt: remoteUpdatedAt
                )
                inserted.assignHistoryScope(ownerUserID: ownerUserID, selectedShopID: scope.shopID, storeIdentity: scope.storeIdentity)
                context.insert(inserted)
                byRemoteID[row.remoteID] = inserted
                byUID[inserted.uid] = inserted
                byLogicalFingerprint[logicalFingerprint] = inserted
                result.insertedCount += 1
            }
        }

        return result
    }

    /// Returns only rows visible to the selected automatic scope, plus
    /// unscoped legacy rows whose remote identity is explicitly present in the
    /// authorized response. Each physical query and the final union are
    /// bounded by the recovery contract so a foreign-shop cache cannot turn a
    /// small incremental event into an unbounded lease hold.
    static func localEntriesEligibleForIncrementalApply(
        _ rows: [RemoteSharedSheetSessionRow],
        ownerUserID: UUID,
        context: ModelContext,
        scope: Task126VerifiedOwnerStoreScope
    ) throws -> [HistoryEntry] {
        let maximumRows = ShopSyncRecoveryLimits.maximumRows(for: .history)
        let selectedShopID = scope.shopID
        let selectedStoreID = scope.storeIdentity.storeId
        let adoptableRemoteIDs = remoteHistoryIDsEligibleForScopeAdoption(
            rows,
            selectedShopID: selectedShopID
        )
        var candidates: [HistoryEntry] = []

        var shopDescriptor = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate<HistoryEntry> { entry in
                entry.shopID == selectedShopID
            }
        )
        shopDescriptor.fetchLimit = maximumRows + 1
        let shopEntries = try context.fetch(shopDescriptor)
        guard shopEntries.count <= maximumRows else {
            throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: .history)
        }
        candidates.append(contentsOf: shopEntries)

        var storeDescriptor = FetchDescriptor<HistoryEntry>(
            predicate: #Predicate<HistoryEntry> { entry in
                entry.shopID == nil && entry.storeID == selectedStoreID
            }
        )
        storeDescriptor.fetchLimit = maximumRows + 1
        let storeEntries = try context.fetch(storeDescriptor)
        guard storeEntries.count <= maximumRows else {
            throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: .history)
        }
        candidates.append(contentsOf: storeEntries)

        if !adoptableRemoteIDs.isEmpty {
            var unscopedDescriptor = FetchDescriptor<HistoryEntry>(
                predicate: #Predicate<HistoryEntry> { entry in
                    entry.shopID == nil && entry.storeID == nil
                }
            )
            unscopedDescriptor.fetchLimit = maximumRows + 1
            let unscopedEntries = try context.fetch(unscopedDescriptor)
            guard unscopedEntries.count <= maximumRows else {
                throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: .history)
            }
            candidates.append(contentsOf: unscopedEntries)
        }

        var seen = Set<ObjectIdentifier>()
        var eligible: [HistoryEntry] = []
        eligible.reserveCapacity(min(candidates.count, maximumRows))
        for (index, entry) in candidates.enumerated() {
            if index.isMultiple(of: 64) { try Task.checkCancellation() }
            guard seen.insert(ObjectIdentifier(entry)).inserted else { continue }
            guard entry.isCompatibleWithHistoryScope(
                ownerUserID: ownerUserID,
                selectedShopID: selectedShopID,
                storeIdentity: scope.storeIdentity
            ) || entry.isAdoptableByRemoteHistoryIdentity(
                ownerUserID: ownerUserID,
                selectedShopID: selectedShopID,
                remoteIDs: adoptableRemoteIDs
            ) else {
                continue
            }
            eligible.append(entry)
            guard eligible.count <= maximumRows else {
                throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: .history)
            }
        }
        return eligible
    }

    private static func shouldProtectDirtyLocalEntryFromRemoteTombstone(_ entry: HistoryEntry) -> Bool {
        entry.remoteDeletedAt == nil && entry.localChangeRevision > entry.lastSyncedLocalRevision
    }

    private static func logicalFingerprintMap(for entries: [HistoryEntry]) -> [String: HistoryEntry] {
        var result: [String: HistoryEntry] = [:]
        for entry in entries where entry.remoteDeletedAt == nil {
            let snapshot = HistorySessionPayloadSnapshotFactory.snapshot(for: entry, ensureRemoteID: false)
            let fingerprint = HistorySessionPayloadCodec.logicalFingerprintHash(for: snapshot)
            result[fingerprint] = result[fingerprint] ?? entry
        }
        return result
    }

    private static func remoteHistoryIDsEligibleForScopeAdoption(
        _ rows: [RemoteSharedSheetSessionRow],
        selectedShopID: UUID?
    ) -> Set<UUID> {
        guard let selectedShopID else { return [] }
        return Set(rows.compactMap { $0.shopID == selectedShopID ? $0.remoteID : nil })
    }

    private static func apply(
        row: RemoteSharedSheetSessionRow,
        to entry: HistoryEntry,
        fingerprint: String,
        timestamp: Date,
        remoteUpdatedAt: Date
    ) {
        entry.id = row.remoteID.uuidString.lowercased()
        entry.title = row.displayName
        entry.timestamp = timestamp
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
        entry.remoteUpdatedAt = remoteUpdatedAt
        entry.remotePayloadFingerprint = fingerprint
        entry.remoteDeletedAt = HistorySessionPayloadCodec.parseUpdatedAt(row.deletedAt)
        entry.lastSyncedLocalRevision = entry.localChangeRevision
        entry.syncStatus = .syncedSuccessfully
    }

    private static func applyRemoteTombstone(
        row: RemoteSharedSheetSessionRow,
        to entry: HistoryEntry,
        fingerprint: String,
        remoteUpdatedAt: Date,
        remoteDeletedAt: Date
    ) {
        entry.remoteID = row.remoteID
        entry.remoteUpdatedAt = remoteUpdatedAt
        entry.remoteDeletedAt = remoteDeletedAt
        entry.remotePayloadFingerprint = fingerprint
        entry.lastSyncedLocalRevision = entry.localChangeRevision
        entry.syncStatus = .syncedSuccessfully
    }

    private static func makeEntry(
        from row: RemoteSharedSheetSessionRow,
        fingerprint: String,
        timestamp: Date,
        remoteUpdatedAt: Date
    ) -> HistoryEntry {
        let complete = row.sessionOverlay?.complete ?? []
        let initialSummary = HistoryImportedGridSupport.initialSummary(forGrid: row.data)
        let summary = HistoryEntryRuntimeSummary.compute(from: row.data, complete: complete)
        let entry = HistoryEntry(
            id: row.remoteID.uuidString.lowercased(),
            timestamp: timestamp,
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
            remoteUpdatedAt: remoteUpdatedAt,
            remoteDeletedAt: nil,
            remotePayloadFingerprint: fingerprint,
            lastSyncedLocalRevision: 0
        )
        entry.title = row.displayName
        return entry
    }
}

nonisolated struct HistoryIncrementalApplyRowsResult: Sendable {
    var insertedCount = 0
    var updatedCount = 0
    var skippedCleanCount = 0
    var skippedDirtyLocalCount = 0
    var skippedDirtyRemoteIDs = Set<UUID>()
}
