import Foundation
import SwiftData

nonisolated enum SyncEventOutboxFactoryError: Error, Sendable, Equatable {
    case missingOwnerUserID
    case missingClientEventID
    case missingDomain
    case missingEventType
    case negativeChangedCount
}

nonisolated struct SyncEventOutboxCounts: Sendable, Equatable {
    var pending: Int = 0
    var retryable: Int = 0
    var blocked: Int = 0
    var dead: Int = 0
    var sent: Int = 0
    var localOnly: Int = 0
}

@Model
final class SyncEventOutboxEntry {
    var id: String
    var ownerUserID: String
    var clientEventID: String
    var batchID: String?
    var domain: String
    var eventType: String
    var changedCount: Int
    var entityIDsShape: String
    var metadataShape: String
    var statusRaw: String
    var attemptCount: Int
    var maxAttempts: Int
    var nextRetryAt: Date
    var lastAttemptAt: Date?
    var lastErrorCode: String?
    var lastErrorKindRaw: String
    var lastErrorMessageSanitized: String?
    var createdAt: Date
    var updatedAt: Date
    var sentAt: Date?
    var sourceDeviceID: String?

    init(
        id: String = UUID().uuidString.lowercased(),
        ownerUserID: String,
        clientEventID: String = UUID().uuidString.lowercased(),
        batchID: String? = nil,
        domain: String,
        eventType: String,
        changedCount: Int,
        entityIDsShape: String,
        metadataShape: String,
        status: SyncEventOutboxStatus = .pending,
        attemptCount: Int = 0,
        maxAttempts: Int = 3,
        nextRetryAt: Date,
        lastAttemptAt: Date? = nil,
        lastErrorCode: String? = nil,
        lastErrorKind: SyncEventOutboxErrorKind = .none,
        lastErrorMessageSanitized: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        sentAt: Date? = nil,
        sourceDeviceID: String? = nil
    ) {
        self.id = id
        self.ownerUserID = ownerUserID
        self.clientEventID = clientEventID
        self.batchID = batchID
        self.domain = domain
        self.eventType = eventType
        self.changedCount = changedCount
        self.entityIDsShape = entityIDsShape
        self.metadataShape = metadataShape
        self.statusRaw = status.rawValue
        self.attemptCount = attemptCount
        self.maxAttempts = max(1, maxAttempts)
        self.nextRetryAt = nextRetryAt
        self.lastAttemptAt = lastAttemptAt
        self.lastErrorCode = lastErrorCode
        self.lastErrorKindRaw = lastErrorKind.rawValue
        self.lastErrorMessageSanitized = lastErrorMessageSanitized
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sentAt = sentAt
        self.sourceDeviceID = sourceDeviceID
    }

    var status: SyncEventOutboxStatus {
        get { SyncEventOutboxStatus(rawValue: statusRaw) ?? .dead }
        set { statusRaw = newValue.rawValue }
    }

    var lastErrorKind: SyncEventOutboxErrorKind {
        get { SyncEventOutboxErrorKind(rawValue: lastErrorKindRaw) ?? .unknown }
        set { lastErrorKindRaw = newValue.rawValue }
    }

    var state: SyncEventOutboxState {
        SyncEventOutboxState(
            status: status,
            attemptCount: attemptCount,
            maxAttempts: maxAttempts,
            nextRetryAt: nextRetryAt,
            lastAttemptAt: lastAttemptAt,
            lastErrorCode: lastErrorCode,
            lastErrorKind: lastErrorKind,
            lastErrorMessageSanitized: lastErrorMessageSanitized,
            updatedAt: updatedAt,
            sentAt: sentAt
        )
    }

    func apply(_ state: SyncEventOutboxState) {
        status = state.status
        attemptCount = state.attemptCount
        maxAttempts = state.maxAttempts
        nextRetryAt = state.nextRetryAt
        lastAttemptAt = state.lastAttemptAt
        lastErrorCode = state.lastErrorCode
        lastErrorKind = state.lastErrorKind
        lastErrorMessageSanitized = state.lastErrorMessageSanitized
        updatedAt = state.updatedAt
        sentAt = state.sentAt
    }

    func isRetryable(now: Date, currentOwnerUserID: String) -> Bool {
        SyncEventOutboxStateMachine.isRetryable(
            state: state,
            entryOwnerUserID: ownerUserID,
            currentOwnerUserID: currentOwnerUserID,
            now: now
        )
    }
}

nonisolated enum SyncEventOutboxFactory {
    static let changedCountContractLimit = 1_000

    static func makeEntry(
        ownerUserID: String,
        domain: String,
        eventType: String,
        changedCount: Int,
        entityIDsShape: String,
        metadataShape: String,
        sourceDeviceID: String? = nil,
        batchID: String? = nil,
        maxAttempts: Int = 3,
        now: Date = Date(),
        id: String = UUID().uuidString.lowercased(),
        clientEventID: String = UUID().uuidString.lowercased()
    ) throws -> SyncEventOutboxEntry {
        let safeOwnerUserID = trimmed(ownerUserID)
        guard !safeOwnerUserID.isEmpty else { throw SyncEventOutboxFactoryError.missingOwnerUserID }

        let safeClientEventID = trimmed(clientEventID)
        guard !safeClientEventID.isEmpty else { throw SyncEventOutboxFactoryError.missingClientEventID }

        let safeDomain = trimmed(domain)
        guard !safeDomain.isEmpty else { throw SyncEventOutboxFactoryError.missingDomain }

        let safeEventType = trimmed(eventType)
        guard !safeEventType.isEmpty else { throw SyncEventOutboxFactoryError.missingEventType }

        guard changedCount >= 0 else { throw SyncEventOutboxFactoryError.negativeChangedCount }

        let safeEntityShape = SyncEventOutboxPrivacySanitizer.sanitizedShape(
            entityIDsShape,
            fallback: "redacted:entity_ids_shape"
        )
        let safeMetadataShape = SyncEventOutboxPrivacySanitizer.sanitizedShape(
            metadataShape,
            fallback: "redacted:metadata_shape"
        )

        var status = SyncEventOutboxStatus.pending
        var lastErrorCode: String?
        var lastErrorKind = SyncEventOutboxErrorKind.none
        var lastErrorMessage: String?

        if changedCount > changedCountContractLimit {
            status = .blockedContract
            lastErrorCode = "changed_count_limit"
            lastErrorKind = .contract
            lastErrorMessage = SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage(
                "changed_count exceeds local contract limit \(changedCountContractLimit)."
            )
        } else if safeEntityShape.wasRedacted || safeMetadataShape.wasRedacted {
            status = .blockedContract
            lastErrorCode = "payload_shape_redacted"
            lastErrorKind = .contract
            lastErrorMessage = SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage(
                "Outbox payload shape looked like raw business data and was redacted."
            )
        }

        return SyncEventOutboxEntry(
            id: trimmed(id),
            ownerUserID: safeOwnerUserID,
            clientEventID: safeClientEventID,
            batchID: trimmedOptional(batchID),
            domain: safeDomain,
            eventType: safeEventType,
            changedCount: changedCount,
            entityIDsShape: safeEntityShape.shape,
            metadataShape: safeMetadataShape.shape,
            status: status,
            attemptCount: 0,
            maxAttempts: maxAttempts,
            nextRetryAt: now,
            lastAttemptAt: nil,
            lastErrorCode: lastErrorCode,
            lastErrorKind: lastErrorKind,
            lastErrorMessageSanitized: lastErrorMessage,
            createdAt: now,
            updatedAt: now,
            sentAt: nil,
            sourceDeviceID: trimmedOptional(sourceDeviceID)
        )
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func trimmedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = trimmed(value)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct SyncEventOutboxLocalStore {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(_ entry: SyncEventOutboxEntry) {
        context.insert(entry)
    }

    func fetchRetryable(
        ownerUserID: String,
        now: Date,
        limit: Int? = nil
    ) throws -> [SyncEventOutboxEntry] {
        let ownerUserID = ownerUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        let pending = SyncEventOutboxStatus.pending.rawValue
        let failedRetryable = SyncEventOutboxStatus.failedRetryable.rawValue
        var descriptor = FetchDescriptor<SyncEventOutboxEntry>(
            predicate: #Predicate { entry in
                entry.ownerUserID == ownerUserID
                    && (entry.statusRaw == pending || entry.statusRaw == failedRetryable)
                    && entry.attemptCount < entry.maxAttempts
                    && entry.nextRetryAt <= now
            },
            sortBy: [
                SortDescriptor(\SyncEventOutboxEntry.nextRetryAt, order: .forward),
                SortDescriptor(\SyncEventOutboxEntry.createdAt, order: .forward),
                SortDescriptor(\SyncEventOutboxEntry.id, order: .forward)
            ]
        )
        if let limit {
            descriptor.fetchLimit = max(0, limit)
        }

        return try context.fetch(descriptor)
    }

    func fetchCounts(ownerUserID: String, now: Date) throws -> SyncEventOutboxCounts {
        let ownerUserID = ownerUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<SyncEventOutboxEntry>(
            predicate: #Predicate { entry in
                entry.ownerUserID == ownerUserID
            }
        )
        let entries = try context.fetch(descriptor)

        return entries.reduce(into: SyncEventOutboxCounts()) { counts, entry in
            switch entry.status {
            case .pending:
                counts.pending += 1
            case .failedRetryable:
                break
            case .blockedContract, .blockedAuth, .blockedSchema:
                counts.blocked += 1
            case .dead:
                counts.dead += 1
            case .sent:
                counts.sent += 1
            case .localOnly:
                counts.localOnly += 1
            case .sending:
                break
            }

            if entry.isRetryable(now: now, currentOwnerUserID: ownerUserID) {
                counts.retryable += 1
            }
        }
    }
}
