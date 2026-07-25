import Foundation

nonisolated indirect enum SyncEventJSONValue: Codable, Sendable, Equatable {
    case object([String: SyncEventJSONValue])
    case array([SyncEventJSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let object = try? container.decode([String: SyncEventJSONValue].self) {
            self = .object(object)
        } else if let array = try? container.decode([SyncEventJSONValue].self) {
            self = .array(array)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value in sync event payload."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case .object(let object):
            try container.encode(object)
        case .array(let array):
            try container.encode(array)
        case .string(let string):
            try container.encode(string)
        case .number(let number):
            try container.encode(number)
        case .bool(let bool):
            try container.encode(bool)
        case .null:
            try container.encodeNil()
        }
    }
}

nonisolated struct RemoteSyncEventRow: Codable, Sendable, Identifiable, Equatable {
    let id: Int64
    let ownerUserID: UUID
    let shopID: UUID?
    let storeID: UUID?
    let domain: String
    let eventType: String
    let source: String?
    let sourceDeviceID: String?
    let sourceDeviceKey: String?
    let batchID: UUID?
    let clientEventID: String?
    let clientEventKey: String?
    let changedCount: Int
    let entityIDs: SyncEventJSONValue?
    let requiresFullRecovery: Bool
    let createdAt: Date
    let expiresAt: Date?
    let metadata: SyncEventJSONValue

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case shopID = "shop_id"
        case storeID = "store_id"
        case domain
        case eventType = "event_type"
        case source
        case sourceDeviceID = "source_device_id"
        case sourceDeviceKey = "source_device_key"
        case batchID = "batch_id"
        case clientEventID = "client_event_id"
        case clientEventKey = "client_event_key"
        case changedCount = "changed_count"
        case entityIDs = "entity_ids"
        case requiresFullRecovery = "requires_full_recovery"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // V6 transports every bigint cursor as canonical decimal text.  Do
        // not accept a JSON number here: JavaScript/PostgREST callers can
        // otherwise round values above 2^53 before this bounded Int64 bridge.
        let wireID = try container.decode(String.self, forKey: .id)
        do {
            id = try ShopSyncRecoveryCanonical.eventID(wireID)
        } catch {
            throw DecodingError.dataCorruptedError(
                forKey: .id,
                in: container,
                debugDescription: "Sync event id must be a canonical decimal string."
            )
        }
        ownerUserID = try container.decode(UUID.self, forKey: .ownerUserID)
        shopID = try container.decodeIfPresent(UUID.self, forKey: .shopID)
        storeID = try container.decodeIfPresent(UUID.self, forKey: .storeID)
        domain = try container.decode(String.self, forKey: .domain)
        eventType = try container.decode(String.self, forKey: .eventType)
        source = try container.decodeIfPresent(String.self, forKey: .source)
        sourceDeviceID = try container.decodeIfPresent(String.self, forKey: .sourceDeviceID)
        sourceDeviceKey = try container.decodeIfPresent(String.self, forKey: .sourceDeviceKey)
        batchID = try container.decodeIfPresent(UUID.self, forKey: .batchID)
        clientEventID = try container.decodeIfPresent(String.self, forKey: .clientEventID)
        clientEventKey = try container.decodeIfPresent(String.self, forKey: .clientEventKey)
        changedCount = try container.decode(Int.self, forKey: .changedCount)
        entityIDs = try container.decodeIfPresent(SyncEventJSONValue.self, forKey: .entityIDs)
        requiresFullRecovery = try container.decodeIfPresent(
            Bool.self,
            forKey: .requiresFullRecovery
        ) ?? false
        createdAt = try Self.decodeDate(container, key: .createdAt)
        expiresAt = try Self.decodeOptionalDate(container, key: .expiresAt)
        metadata = try container.decodeIfPresent(SyncEventJSONValue.self, forKey: .metadata) ?? .object([:])
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(String(id), forKey: .id)
        try container.encode(ownerUserID, forKey: .ownerUserID)
        try container.encodeIfPresent(shopID, forKey: .shopID)
        try container.encodeIfPresent(storeID, forKey: .storeID)
        try container.encode(domain, forKey: .domain)
        try container.encode(eventType, forKey: .eventType)
        try container.encodeIfPresent(source, forKey: .source)
        try container.encodeIfPresent(sourceDeviceID, forKey: .sourceDeviceID)
        try container.encodeIfPresent(sourceDeviceKey, forKey: .sourceDeviceKey)
        try container.encodeIfPresent(batchID, forKey: .batchID)
        try container.encodeIfPresent(clientEventID, forKey: .clientEventID)
        try container.encodeIfPresent(clientEventKey, forKey: .clientEventKey)
        try container.encode(changedCount, forKey: .changedCount)
        try container.encodeIfPresent(entityIDs, forKey: .entityIDs)
        try container.encode(requiresFullRecovery, forKey: .requiresFullRecovery)
        try container.encode(Self.v6DateString(createdAt), forKey: .createdAt)
        try container.encodeIfPresent(expiresAt.map(Self.v6DateString), forKey: .expiresAt)
        try container.encode(metadata, forKey: .metadata)
    }

    private static func v6DateString(_ value: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: value)
    }

    private static func decodeDate(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> Date {
        let value = try container.decode(String.self, forKey: key)
        guard let date = SyncEventDateParser.date(from: value) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Invalid sync event timestamp."
            )
        }
        return date
    }

    private static func decodeOptionalDate(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) throws -> Date? {
        guard let value = try container.decodeIfPresent(String.self, forKey: key) else {
            return nil
        }
        guard let date = SyncEventDateParser.date(from: value) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Invalid sync event timestamp."
            )
        }
        return date
    }
}

nonisolated struct SyncEventRowsResponse: Decodable, Sendable, Equatable {
    let rows: [RemoteSyncEventRow]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let rows = try? container.decode([RemoteSyncEventRow].self) {
            self.rows = rows
        } else if let row = try? container.decode(RemoteSyncEventRow.self) {
            self.rows = [row]
        } else {
            throw DecodingError.typeMismatch(
                SyncEventRowsResponse.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Expected a sync event object or array."
                )
            )
        }
    }
}

nonisolated enum SyncEventDateParser {
    static func date(from value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let candidates = timestampCandidates(from: trimmed)
        for candidate in candidates {
            if let date = isoFormatter(fractionalSeconds: true).date(from: candidate) {
                return date
            }
            if let date = isoFormatter(fractionalSeconds: false).date(from: candidate) {
                return date
            }
        }

        for format in [
            "yyyy-MM-dd HH:mm:ss.SSSSSSXXXXX",
            "yyyy-MM-dd HH:mm:ss.SSSXXXXX",
            "yyyy-MM-dd HH:mm:ssXXXXX",
            "yyyy-MM-dd HH:mm:ss.SSSSSSXX",
            "yyyy-MM-dd HH:mm:ss.SSSXX",
            "yyyy-MM-dd HH:mm:ssXX",
            "yyyy-MM-dd HH:mm:ss"
        ] {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            formatter.isLenient = false

            if let date = formatter.date(from: trimmed) {
                return date
            }
        }

        return nil
    }

    private static func isoFormatter(fractionalSeconds: Bool) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = fractionalSeconds
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return formatter
    }

    private static func timestampCandidates(from value: String) -> [String] {
        let isoLike = value.replacingOccurrences(of: " ", with: "T")
        var candidates = [value, isoLike]

        if let expanded = expandShortTimezone(isoLike) {
            candidates.append(expanded)
        }

        return candidates
    }

    private static func expandShortTimezone(_ value: String) -> String? {
        guard value.count >= 3 else {
            return nil
        }

        let suffix = value.suffix(3)
        guard let sign = suffix.first, sign == "+" || sign == "-" else {
            return nil
        }

        let digits = suffix.dropFirst()
        guard digits.allSatisfy(\.isNumber) else {
            return nil
        }

        return String(value.dropLast(3)) + "\(suffix):00"
    }
}
