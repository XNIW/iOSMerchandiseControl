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
    var failedRetryable: Int = 0
    var blocked: Int = 0
    var dead: Int = 0
    var sent: Int = 0
    var localOnly: Int = 0
}

nonisolated enum SyncEventOutboxPayloadField: String, Sendable, Equatable {
    case entityIDs = "entity_ids"
    case metadata
}

nonisolated struct SyncEventOutboxStoredPayloadJSON: Sendable, Equatable {
    let entityIDsPayloadJSON: String
    let metadataPayloadJSON: String
}

nonisolated enum SyncEventOutboxPayloadError: Error, Sendable, Equatable {
    case missingPayload(SyncEventOutboxPayloadField)
    case invalidPayloadJSON(SyncEventOutboxPayloadField)
    case encodingFailed(SyncEventOutboxPayloadField)
    case invalidBatchID
    case invalidEntryField(String)
    case validationFailed(SyncEventRecordError)
}

nonisolated enum SyncEventOutboxPayloadCodec {
    static func makePayloadJSON(
        for request: SyncEventRecordRequest,
        validator: SyncEventRecordValidator = SyncEventRecordValidator()
    ) throws -> SyncEventOutboxStoredPayloadJSON {
        do {
            try validator.validate(request)
        } catch let error as SyncEventRecordError {
            throw SyncEventOutboxPayloadError.validationFailed(error)
        } catch {
            throw SyncEventOutboxPayloadError.validationFailed(
                .unknown(SyncEventRecordFailure(code: "validator_unknown", message: String(describing: error)))
            )
        }

        return SyncEventOutboxStoredPayloadJSON(
            entityIDsPayloadJSON: try encode(request.entityIDs, field: .entityIDs),
            metadataPayloadJSON: try encode(request.metadata, field: .metadata)
        )
    }

    static func makeRecordRequestForReplay(
        from entry: SyncEventOutboxEntry,
        validator: SyncEventRecordValidator = SyncEventRecordValidator()
    ) throws -> SyncEventRecordRequest {
        guard !trimmed(entry.ownerUserID).isEmpty else {
            throw SyncEventOutboxPayloadError.invalidEntryField("owner_user_id")
        }

        let entityIDs = try decodeRequired(entry.entityIDsPayloadJSON, field: .entityIDs)
        let metadata = try decodeRequired(entry.metadataPayloadJSON, field: .metadata)
        let request = SyncEventRecordRequest(
            domain: entry.domain,
            eventType: entry.eventType,
            changedCount: entry.changedCount,
            entityIDs: entityIDs,
            metadata: metadata,
            shopID: shopID(from: entry.storeId),
            source: source(from: metadata),
            sourceDeviceID: entry.sourceDeviceID,
            batchID: try batchID(from: entry.batchID),
            clientEventID: entry.clientEventID
        )

        do {
            try validator.validate(request)
        } catch let error as SyncEventRecordError {
            throw SyncEventOutboxPayloadError.validationFailed(error)
        } catch {
            throw SyncEventOutboxPayloadError.validationFailed(
                .unknown(SyncEventRecordFailure(code: "validator_unknown", message: String(describing: error)))
            )
        }

        return request
    }

    private static func encode(
        _ value: SyncEventJSONValue,
        field: SyncEventOutboxPayloadField
    ) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            throw SyncEventOutboxPayloadError.encodingFailed(field)
        }

        guard let json = String(data: data, encoding: .utf8) else {
            throw SyncEventOutboxPayloadError.encodingFailed(field)
        }
        return json
    }

    private static func decodeRequired(
        _ json: String?,
        field: SyncEventOutboxPayloadField
    ) throws -> SyncEventJSONValue {
        guard let json = trimmedOptional(json) else {
            throw SyncEventOutboxPayloadError.missingPayload(field)
        }

        guard let data = json.data(using: .utf8) else {
            throw SyncEventOutboxPayloadError.invalidPayloadJSON(field)
        }

        do {
            return try JSONDecoder().decode(SyncEventJSONValue.self, from: data)
        } catch {
            throw SyncEventOutboxPayloadError.invalidPayloadJSON(field)
        }
    }

    private static func source(from metadata: SyncEventJSONValue) -> String? {
        guard case .object(let object) = metadata,
              case .string(let source)? = object["source"] else {
            return nil
        }
        return trimmedOptional(source)
    }

    private static func batchID(from value: String?) throws -> UUID? {
        guard let value = trimmedOptional(value) else {
            return nil
        }
        guard let uuid = UUID(uuidString: value) else {
            throw SyncEventOutboxPayloadError.invalidBatchID
        }
        return uuid
    }

    private static func shopID(from value: String?) -> UUID? {
        guard let value = trimmedOptional(value) else {
            return nil
        }
        return UUID(uuidString: value)
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

@Model
final class SyncEventOutboxEntry {
    var id: String
    var ownerUserID: String
    var storeId: String?
    var localStoreId: String?
    var syncProtocolVersion: Int = Task126SyncPolicy.syncProtocolVersion
    var schemaVersion: Int = Task126SyncPolicy.localSchemaVersion
    var storeEpoch: Int = Task126SyncPolicy.defaultStoreEpoch
    var clientEventID: String
    var batchID: String?
    var domain: String
    var eventType: String
    var changedCount: Int
    var entityIDsShape: String
    var metadataShape: String
    var entityIDsPayloadJSON: String?
    var metadataPayloadJSON: String?
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
        storeId: String? = nil,
        localStoreId: String? = nil,
        syncProtocolVersion: Int = Task126SyncPolicy.syncProtocolVersion,
        schemaVersion: Int = Task126SyncPolicy.localSchemaVersion,
        storeEpoch: Int = Task126SyncPolicy.defaultStoreEpoch,
        clientEventID: String = UUID().uuidString.lowercased(),
        batchID: String? = nil,
        domain: String,
        eventType: String,
        changedCount: Int,
        entityIDsShape: String,
        metadataShape: String,
        entityIDsPayloadJSON: String? = nil,
        metadataPayloadJSON: String? = nil,
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
        let normalizedStoreId = Task126OwnerStoreScope.normalizedStoreId(storeId)
        self.id = id
        self.ownerUserID = ownerUserID
        self.storeId = normalizedStoreId
        self.localStoreId = Task126OwnerStoreScope.normalizedLocalStoreId(
            localStoreId,
            storeId: normalizedStoreId
        )
        self.syncProtocolVersion = syncProtocolVersion
        self.schemaVersion = schemaVersion
        self.storeEpoch = storeEpoch
        self.clientEventID = clientEventID
        self.batchID = batchID
        self.domain = domain
        self.eventType = eventType
        self.changedCount = changedCount
        self.entityIDsShape = entityIDsShape
        self.metadataShape = metadataShape
        self.entityIDsPayloadJSON = Self.trimmedOptional(entityIDsPayloadJSON)
        self.metadataPayloadJSON = Self.trimmedOptional(metadataPayloadJSON)
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

    func isRetryable(
        now: Date,
        currentOwnerUserID: String,
        currentStoreId: String? = nil
    ) -> Bool {
        if let currentStoreId,
           Task126OwnerStoreGate.validate(
               entry: self,
               activeOwnerUserID: currentOwnerUserID,
               activeStoreId: currentStoreId
           ) != .allowed {
            return false
        }
        return SyncEventOutboxStateMachine.isRetryable(
            state: state,
            entryOwnerUserID: ownerUserID,
            currentOwnerUserID: currentOwnerUserID,
            now: now
        )
    }

    func makeRecordRequestForReplay(
        validator: SyncEventRecordValidator = SyncEventRecordValidator()
    ) throws -> SyncEventRecordRequest {
        try SyncEventOutboxPayloadCodec.makeRecordRequestForReplay(from: self, validator: validator)
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

nonisolated enum SyncEventOutboxFactory {
    static let changedCountContractLimit = 100_000

    static func makeEntry(
        ownerUserID: String,
        storeId: String? = nil,
        localStoreId: String? = nil,
        syncProtocolVersion: Int = Task126SyncPolicy.syncProtocolVersion,
        schemaVersion: Int = Task126SyncPolicy.localSchemaVersion,
        storeEpoch: Int = Task126SyncPolicy.defaultStoreEpoch,
        domain: String,
        eventType: String,
        changedCount: Int,
        entityIDsShape: String,
        metadataShape: String,
        entityIDsPayloadJSON: String? = nil,
        metadataPayloadJSON: String? = nil,
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
        let canPersistPayload = status == .pending

        return SyncEventOutboxEntry(
            id: trimmed(id),
            ownerUserID: safeOwnerUserID,
            storeId: storeId,
            localStoreId: localStoreId,
            syncProtocolVersion: syncProtocolVersion,
            schemaVersion: schemaVersion,
            storeEpoch: storeEpoch,
            clientEventID: safeClientEventID,
            batchID: trimmedOptional(batchID),
            domain: safeDomain,
            eventType: safeEventType,
            changedCount: changedCount,
            entityIDsShape: safeEntityShape.shape,
            metadataShape: safeMetadataShape.shape,
            entityIDsPayloadJSON: canPersistPayload ? entityIDsPayloadJSON : nil,
            metadataPayloadJSON: canPersistPayload ? metadataPayloadJSON : nil,
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

nonisolated struct SyncEventOutboxLocalStore {
    nonisolated static let defaultSendingRecoveryScanLimit = 50
    nonisolated static let hardSendingRecoveryScanLimit = 200

    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func add(_ entry: SyncEventOutboxEntry) {
        context.insert(entry)
    }

    func fetchRetryable(
        ownerUserID: String,
        storeId: String? = nil,
        now: Date,
        limit: Int? = nil
    ) throws -> [SyncEventOutboxEntry] {
        let ownerUserID = ownerUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        let pending = SyncEventOutboxStatus.pending.rawValue
        let failedRetryable = SyncEventOutboxStatus.failedRetryable.rawValue
        let normalizedStoreId = storeId.map(Task126OwnerStoreScope.normalizedStoreId)
        var descriptor: FetchDescriptor<SyncEventOutboxEntry>
        if let normalizedStoreId {
            descriptor = FetchDescriptor<SyncEventOutboxEntry>(
                predicate: #Predicate { entry in
                    entry.ownerUserID == ownerUserID
                        && entry.storeId == normalizedStoreId
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
        } else {
            descriptor = FetchDescriptor<SyncEventOutboxEntry>(
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
        }
        if let limit {
            descriptor.fetchLimit = max(0, limit)
        }

        return try context.fetch(descriptor).filter { entry in
            guard let normalizedStoreId else { return true }
            return entry.isRetryable(now: now, currentOwnerUserID: ownerUserID, currentStoreId: normalizedStoreId)
        }
    }

    func recoverStaleSending(
        ownerUserID: String,
        storeId: String? = nil,
        now: Date,
        staleInterval: TimeInterval = SyncEventOutboxStateMachine.defaultSendingStaleInterval,
        scanLimit: Int = defaultSendingRecoveryScanLimit
    ) throws -> SyncEventOutboxSendingRecoveryResult {
        let ownerUserID = ownerUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStoreId = storeId.map(Task126OwnerStoreScope.normalizedStoreId)
        let sending = SyncEventOutboxStatus.sending.rawValue
        var descriptor: FetchDescriptor<SyncEventOutboxEntry>
        if let normalizedStoreId {
            descriptor = FetchDescriptor<SyncEventOutboxEntry>(
                predicate: #Predicate { entry in
                    entry.ownerUserID == ownerUserID
                        && entry.storeId == normalizedStoreId
                        && entry.statusRaw == sending
                },
                sortBy: [
                    SortDescriptor(\SyncEventOutboxEntry.updatedAt, order: .forward),
                    SortDescriptor(\SyncEventOutboxEntry.createdAt, order: .forward),
                    SortDescriptor(\SyncEventOutboxEntry.id, order: .forward)
                ]
            )
        } else {
            descriptor = FetchDescriptor<SyncEventOutboxEntry>(
                predicate: #Predicate { entry in
                    entry.ownerUserID == ownerUserID && entry.statusRaw == sending
                },
                sortBy: [
                    SortDescriptor(\SyncEventOutboxEntry.updatedAt, order: .forward),
                    SortDescriptor(\SyncEventOutboxEntry.createdAt, order: .forward),
                    SortDescriptor(\SyncEventOutboxEntry.id, order: .forward)
                ]
            )
        }

        let boundedLimit = min(
            max(0, scanLimit),
            Self.hardSendingRecoveryScanLimit
        )
        guard boundedLimit > 0 else {
            return SyncEventOutboxSendingRecoveryResult()
        }
        descriptor.fetchLimit = boundedLimit

        let entries = try context.fetch(descriptor)
        var recoveredCount = 0
        var exhaustedCount = 0
        var skippedFreshSendingCount = 0

        for entry in entries {
            let state = entry.state
            guard SyncEventOutboxStateMachine.isSendingStale(
                state,
                now: now,
                staleInterval: staleInterval
            ) else {
                skippedFreshSendingCount += 1
                continue
            }

            let recovered = SyncEventOutboxStateMachine.recoverStaleSending(state, now: now)
            entry.apply(recovered)

            switch recovered.status {
            case .failedRetryable:
                recoveredCount += 1
            case .dead:
                exhaustedCount += 1
            case .pending, .sending, .sent, .blockedContract, .blockedAuth, .blockedSchema, .localOnly:
                break
            }
        }

        return SyncEventOutboxSendingRecoveryResult(
            scannedCount: entries.count,
            recoveredCount: recoveredCount,
            exhaustedCount: exhaustedCount,
            skippedFreshSendingCount: skippedFreshSendingCount
        )
    }

    func fetchCounts(ownerUserID: String, storeId: String? = nil, now: Date) throws -> SyncEventOutboxCounts {
        let ownerUserID = ownerUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedStoreId = storeId.map(Task126OwnerStoreScope.normalizedStoreId)
        let descriptor: FetchDescriptor<SyncEventOutboxEntry>
        if let normalizedStoreId {
            descriptor = FetchDescriptor<SyncEventOutboxEntry>(
                predicate: #Predicate { entry in
                    entry.ownerUserID == ownerUserID && entry.storeId == normalizedStoreId
                }
            )
        } else {
            descriptor = FetchDescriptor<SyncEventOutboxEntry>(
                predicate: #Predicate { entry in
                    entry.ownerUserID == ownerUserID
                }
            )
        }
        let entries = try context.fetch(descriptor)

        return entries.reduce(into: SyncEventOutboxCounts()) { counts, entry in
            switch entry.status {
            case .pending:
                counts.pending += 1
            case .failedRetryable:
                counts.failedRetryable += 1
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

            if entry.isRetryable(now: now, currentOwnerUserID: ownerUserID, currentStoreId: normalizedStoreId) {
                counts.retryable += 1
            }
        }
    }
}
