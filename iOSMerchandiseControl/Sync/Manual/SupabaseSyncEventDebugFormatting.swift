#if DEBUG
import Foundation

nonisolated enum SyncEventDebugValueShape: String, Sendable, Equatable {
    case object
    case array
    case string
    case number
    case boolean
    case empty
    case notAvailable

    var localizationKey: String {
        "options.supabase.syncEvents.shape.\(rawValue)"
    }
}

nonisolated struct SyncEventDebugValueSummary: Sendable, Equatable {
    let shape: SyncEventDebugValueShape
    let countText: String
    let preview: String?

    static let notAvailable = SyncEventDebugValueSummary(
        shape: .notAvailable,
        countText: "N/A",
        preview: nil
    )
}

nonisolated struct SyncEventDebugDisplaySummary: Sendable, Equatable {
    static let displayLimit = 20

    let loadedCount: Int
    let latestEventDescription: String?
    let latestCreatedAtFormatted: String?
    let effectiveLimit: Int
    let isLimitClamped: Bool
    let displayedCount: Int

    init(summary: SyncEventPreviewSummary) {
        loadedCount = summary.events.count
        effectiveLimit = summary.effectiveLimit
        isLimitClamped = summary.isLimitClamped
        displayedCount = Self.displayedCount(forTotal: summary.events.count)

        if let latest = summary.events.first {
            latestEventDescription = [
                SyncEventDebugFormatter.safeLabel(latest.domain),
                SyncEventDebugFormatter.safeLabel(latest.eventType),
                "\(latest.changedCount)"
            ].joined(separator: " • ")
            latestCreatedAtFormatted = latest.createdAt.formatted(date: .abbreviated, time: .shortened)
        } else {
            latestEventDescription = nil
            latestCreatedAtFormatted = nil
        }
    }

    static func displayedCount(forTotal total: Int) -> Int {
        min(displayLimit, max(0, total))
    }
}

nonisolated struct SyncEventDebugDisplayRow: Identifiable, Sendable, Equatable {
    let id: Int64
    let domain: String
    let eventType: String
    let changedCount: Int
    let source: String?
    let createdAtFormatted: String
    let entities: SyncEventDebugValueSummary
    let payload: SyncEventDebugValueSummary
    let sanitizedPreview: String?

    init(row: RemoteSyncEventRow) {
        let entities = SyncEventDebugFormatter.summary(for: row.entityIDs)
        let payload = SyncEventDebugFormatter.summary(for: row.metadata)

        id = row.id
        domain = SyncEventDebugFormatter.safeLabel(row.domain)
        eventType = SyncEventDebugFormatter.safeLabel(row.eventType)
        changedCount = row.changedCount
        source = SyncEventDebugFormatter.safeSource(row.source)
        createdAtFormatted = row.createdAt.formatted(date: .abbreviated, time: .shortened)
        self.entities = entities
        self.payload = payload
        sanitizedPreview = entities.preview ?? payload.preview
    }

    static func rows(from remoteRows: [RemoteSyncEventRow], limit: Int = SyncEventDebugDisplaySummary.displayLimit) -> [SyncEventDebugDisplayRow] {
        remoteRows
            .prefix(max(0, limit))
            .map(SyncEventDebugDisplayRow.init(row:))
    }
}

nonisolated enum SyncEventDebugFormatter {
    static func summary(for value: SyncEventJSONValue?) -> SyncEventDebugValueSummary {
        guard let value else {
            return .notAvailable
        }
        return summary(for: value)
    }

    static func summary(for value: SyncEventJSONValue) -> SyncEventDebugValueSummary {
        switch value {
        case .object(let object):
            return SyncEventDebugValueSummary(
                shape: .object,
                countText: "\(object.count)",
                preview: nil
            )
        case .array(let array):
            return SyncEventDebugValueSummary(
                shape: .array,
                countText: "\(array.count)",
                preview: nil
            )
        case .string(let string):
            return SyncEventDebugValueSummary(
                shape: .string,
                countText: "N/A",
                preview: sanitizedPreview(from: string)
            )
        case .number:
            return SyncEventDebugValueSummary(
                shape: .number,
                countText: "N/A",
                preview: nil
            )
        case .bool:
            return SyncEventDebugValueSummary(
                shape: .boolean,
                countText: "N/A",
                preview: nil
            )
        case .null:
            return SyncEventDebugValueSummary(
                shape: .empty,
                countText: "0",
                preview: nil
            )
        }
    }

    static func sanitizedPreview(from value: String, maxLength: Int = 48) -> String? {
        let trimmed = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else { return nil }
        guard !containsSensitiveToken(trimmed) else { return nil }
        guard !containsQueryString(trimmed) else { return nil }
        guard !containsUUID(trimmed) else { return nil }
        guard !containsBarcodeLikeNumber(trimmed) else { return nil }

        let safeMaxLength = max(1, maxLength)
        if trimmed.count <= safeMaxLength {
            return trimmed
        }

        if safeMaxLength <= 3 {
            return String(trimmed.prefix(safeMaxLength))
        }

        return String(trimmed.prefix(safeMaxLength - 3)) + "..."
    }

    static func safeLabel(_ value: String, maxLength: Int = 40) -> String {
        sanitizedPreview(from: value, maxLength: maxLength) ?? "N/A"
    }

    static func safeSource(_ value: String?) -> String? {
        guard let value else { return nil }
        return sanitizedPreview(from: value, maxLength: 24)
    }

    private static func containsSensitiveToken(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        return lowercased.contains("authorization")
            || lowercased.contains("bearer")
            || lowercased.contains("apikey")
            || lowercased.contains("jwt")
            || lowercased.contains("token")
            || lowercased.contains("session")
            || lowercased.contains("access_token")
            || lowercased.contains("refresh_token")
    }

    private static func containsQueryString(_ value: String) -> Bool {
        value.contains("?") || value.range(of: #"[?&][A-Za-z0-9_.~-]+="#, options: .regularExpression) != nil
    }

    private static func containsUUID(_ value: String) -> Bool {
        value.range(
            of: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#,
            options: .regularExpression
        ) != nil
    }

    private static func containsBarcodeLikeNumber(_ value: String) -> Bool {
        value.range(of: #"\b\d{8,}\b"#, options: .regularExpression) != nil
    }
}
#endif
