import CryptoKit
import Foundation

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

    static func fingerprintHash(for row: SharedSheetSessionUpsertRow) -> String {
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
    var pushedRemoteIDs: Set<UUID> = []
    var skippedCleanCount: Int = 0
    var skippedOversizedCount: Int = 0
}

nonisolated struct HistorySessionPullResult: Equatable, Sendable {
    var insertedCount: Int = 0
    var updatedCount: Int = 0
    var skippedCleanCount: Int = 0
    var skippedDirtyLocalCount: Int = 0
    var prunedMissingRemoteCount: Int = 0
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
