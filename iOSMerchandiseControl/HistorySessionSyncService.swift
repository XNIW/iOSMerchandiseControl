import CryptoKit
import Foundation
import SwiftData

nonisolated struct HistorySessionOverlayPayload: Codable, Equatable, Sendable {
    let overlaySchema: Int
    let editable: [[String]]
    let complete: [Bool]

    enum CodingKeys: String, CodingKey {
        case overlaySchema = "overlay_schema"
        case editable
        case complete
    }
}

nonisolated struct SharedSheetSessionUpsertRow: Encodable, Equatable, Sendable {
    let remoteID: UUID
    let payloadVersion: Int
    let displayName: String
    let timestamp: String
    let supplier: String
    let category: String
    let isManualEntry: Bool
    let data: [[String]]
    let sessionOverlay: HistorySessionOverlayPayload?
    let ownerUserID: UUID
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case remoteID = "remote_id"
        case payloadVersion = "payload_version"
        case displayName = "display_name"
        case timestamp
        case supplier
        case category
        case isManualEntry = "is_manual_entry"
        case data
        case sessionOverlay = "session_overlay"
        case ownerUserID = "owner_user_id"
        case deletedAt = "deleted_at"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(remoteID.uuidString.lowercased(), forKey: .remoteID)
        try container.encode(payloadVersion, forKey: .payloadVersion)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(supplier, forKey: .supplier)
        try container.encode(category, forKey: .category)
        try container.encode(isManualEntry, forKey: .isManualEntry)
        try container.encode(data, forKey: .data)
        try container.encodeIfPresent(sessionOverlay, forKey: .sessionOverlay)
        try container.encode(ownerUserID.uuidString.lowercased(), forKey: .ownerUserID)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }
}

nonisolated struct RemoteSharedSheetSessionRow: Decodable, Equatable, Sendable {
    let remoteID: UUID
    let payloadVersion: Int
    let displayName: String
    let timestamp: String
    let supplier: String
    let category: String
    let isManualEntry: Bool
    let data: [[String]]
    let sessionOverlay: HistorySessionOverlayPayload?
    let ownerUserID: UUID
    let updatedAt: String?
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case remoteID = "remote_id"
        case payloadVersion = "payload_version"
        case displayName = "display_name"
        case timestamp
        case supplier
        case category
        case isManualEntry = "is_manual_entry"
        case data
        case sessionOverlay = "session_overlay"
        case ownerUserID = "owner_user_id"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}

nonisolated enum HistorySessionPayloadCodec {
    static let payloadVersion = 2
    static let overlaySchema = 1
    static let maxOverlayBytes = 512 * 1_024

    static func upsertRow(
        for entry: HistoryEntry,
        ownerUserID: UUID
    ) throws -> SharedSheetSessionUpsertRow {
        let remoteID = entry.ensureHistorySessionRemoteID()
        let overlay = HistorySessionOverlayPayload(
            overlaySchema: overlaySchema,
            editable: entry.editable,
            complete: entry.complete
        )
        let overlayData = try JSONEncoder().encode(overlay)
        guard overlayData.count <= maxOverlayBytes else {
            throw HistorySessionSyncError.overlayTooLarge
        }

        return SharedSheetSessionUpsertRow(
            remoteID: remoteID,
            payloadVersion: payloadVersion,
            displayName: entry.title,
            timestamp: formatTimestamp(entry.timestamp),
            supplier: entry.supplier,
            category: entry.category,
            isManualEntry: entry.isManualEntry,
            data: entry.data,
            sessionOverlay: overlay,
            ownerUserID: ownerUserID,
            deletedAt: entry.remoteDeletedAt.map(formatTimestamp)
        )
    }

    static func fingerprintHash(for entry: HistoryEntry) -> String {
        let canonical = [
            entry.remoteID?.uuidString.lowercased() ?? entry.uid.uuidString.lowercased(),
            "\(payloadVersion)",
            normalize(entry.title),
            formatTimestamp(entry.timestamp),
            normalize(entry.supplier),
            normalize(entry.category),
            entry.isManualEntry ? "1" : "0",
            canonicalJSONString(entry.data),
            canonicalJSONString(entry.editable),
            canonicalJSONString(entry.complete)
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func fingerprintHash(for row: RemoteSharedSheetSessionRow) -> String {
        let canonical = [
            row.remoteID.uuidString.lowercased(),
            "\(row.payloadVersion)",
            normalize(row.displayName),
            normalizedTimestamp(row.timestamp),
            normalize(row.supplier),
            normalize(row.category),
            row.isManualEntry ? "1" : "0",
            canonicalJSONString(row.data),
            canonicalJSONString(row.sessionOverlay?.editable ?? []),
            canonicalJSONString(row.sessionOverlay?.complete ?? []),
            row.deletedAt.map(normalizedTimestamp) ?? ""
        ].joined(separator: "|")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

    static func parseTimestamp(_ rawValue: String) -> Date {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let androidFormatter = DateFormatter()
        androidFormatter.calendar = Calendar(identifier: .gregorian)
        androidFormatter.locale = Locale(identifier: "en_US_POSIX")
        androidFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        androidFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = androidFormatter.date(from: trimmed) {
            return date
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: trimmed) {
            return date
        }
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: trimmed) ?? Date(timeIntervalSince1970: 0)
    }

    static func parseUpdatedAt(_ rawValue: String?) -> Date? {
        guard let rawValue else { return nil }
        return parseTimestamp(rawValue)
    }

    private static func normalizedTimestamp(_ rawValue: String) -> String {
        formatTimestamp(parseTimestamp(rawValue))
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func canonicalJSONString<Value: Encodable>(_ value: Value) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }
}

nonisolated enum HistorySessionSyncError: Error, Equatable, Sendable {
    case ownerMismatch
    case overlayTooLarge
    case readBackMismatch
}

nonisolated struct HistorySessionPushResult: Equatable, Sendable {
    var uploadedCount: Int = 0
    var skippedCleanCount: Int = 0
    var skippedOversizedCount: Int = 0
}

nonisolated struct HistorySessionPullResult: Equatable, Sendable {
    var insertedCount: Int = 0
    var updatedCount: Int = 0
    var skippedCleanCount: Int = 0
    var skippedDirtyLocalCount: Int = 0
}

nonisolated struct HistorySessionSyncProgress: Equatable, Sendable {
    enum Stage: String, Equatable, Sendable {
        case pushing
        case fetching
        case applying
        case saving
        case completed
    }

    let stage: Stage
    let current: Int
    let total: Int?

    init(stage: Stage, current: Int, total: Int? = nil) {
        self.stage = stage
        self.current = max(0, current)
        self.total = total.map { max(0, $0) }
    }
}

protocol HistorySessionRemoteSyncing: Sendable {
    func upsertSharedSheetSessions(
        _ rows: [SharedSheetSessionUpsertRow],
        ownerUserID: UUID
    ) async throws -> [RemoteSharedSheetSessionRow]

    func fetchSharedSheetSessionsPage(
        ownerUserID: UUID,
        from: Int,
        to: Int
    ) async throws -> [RemoteSharedSheetSessionRow]
}

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
                let row = try HistorySessionPayloadCodec.upsertRow(for: entry, ownerUserID: ownerUserID)
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
            let fingerprint = HistorySessionPayloadCodec.fingerprintHash(for: readBack)
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
        let totalRows = allRows.count
        await publishProgress(HistorySessionSyncProgress(stage: .completed, current: totalRows, total: totalRows), onProgress: onProgress)
        return result
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
