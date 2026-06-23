import CryptoKit
import Foundation
import SwiftData

nonisolated enum SyncEventOutboxProducerTerminalStatus: Sendable, Equatable {
    case completed
    case partial
    case completedBaselineRefreshFailed
    case noOp
    case dryRun
    case failedPreflight
}

nonisolated struct SyncEventOutboxProducerResult: Sendable, Equatable {
    nonisolated enum Kind: String, Sendable, Equatable, CaseIterable {
        case enqueued
        case skippedNoOp
        case skippedDryRun
        case skippedFailedPreflight
        case blockedContract
        case blockedAuth
        case blockedSchema
        case duplicateNoOp
        case enqueueFailedLocal
        case skippedUnsupported
    }

    let kind: Kind
    let entryID: String?
    let entryStatus: SyncEventOutboxStatus?
    let errorCode: String?

    init(
        kind: Kind,
        entryID: String? = nil,
        entryStatus: SyncEventOutboxStatus? = nil,
        errorCode: String? = nil
    ) {
        self.kind = kind
        self.entryID = entryID
        self.entryStatus = entryStatus
        self.errorCode = errorCode
    }
}

nonisolated enum SyncEventOutboxProducerOutcome: Sendable, Equatable {
    case catalogManualPush(CatalogManualPush)
    case productPriceManualPush(ProductPriceManualPush)
    case catalogGeneratedProductPrices(CatalogGeneratedProductPrices)
    case unsupported(source: String)

    nonisolated struct CatalogManualPush: Sendable, Equatable {
        let ownerUserID: String?
        let currentOwnerUserID: String?
        let terminalStatus: SyncEventOutboxProducerTerminalStatus
        let suppliersConfirmed: Int
        let categoriesConfirmed: Int
        let productsConfirmed: Int
        let skippedCount: Int
        let failedCount: Int
        let clientEventID: String?
        let sourceDeviceID: String?
        let batchID: UUID?
        let validationEntityIDs: SyncEventJSONValue?
        let validationMetadata: SyncEventJSONValue?

        init(
            ownerUserID: String?,
            currentOwnerUserID: String? = nil,
            terminalStatus: SyncEventOutboxProducerTerminalStatus,
            suppliersConfirmed: Int,
            categoriesConfirmed: Int,
            productsConfirmed: Int,
            skippedCount: Int = 0,
            failedCount: Int = 0,
            clientEventID: String? = nil,
            sourceDeviceID: String? = nil,
            batchID: UUID? = nil,
            validationEntityIDs: SyncEventJSONValue? = nil,
            validationMetadata: SyncEventJSONValue? = nil
        ) {
            self.ownerUserID = ownerUserID
            self.currentOwnerUserID = currentOwnerUserID
            self.terminalStatus = terminalStatus
            self.suppliersConfirmed = max(0, suppliersConfirmed)
            self.categoriesConfirmed = max(0, categoriesConfirmed)
            self.productsConfirmed = max(0, productsConfirmed)
            self.skippedCount = max(0, skippedCount)
            self.failedCount = max(0, failedCount)
            self.clientEventID = clientEventID
            self.sourceDeviceID = sourceDeviceID
            self.batchID = batchID
            self.validationEntityIDs = validationEntityIDs
            self.validationMetadata = validationMetadata
        }
    }

    nonisolated struct ProductPriceManualPush: Sendable, Equatable {
        let ownerUserID: String?
        let currentOwnerUserID: String?
        let terminalStatus: SyncEventOutboxProducerTerminalStatus
        let confirmedPriceRows: Int
        let skippedCount: Int
        let failedCount: Int
        let clientEventID: String?
        let sourceDeviceID: String?
        let batchID: UUID?
        let validationEntityIDs: SyncEventJSONValue?
        let validationMetadata: SyncEventJSONValue?

        init(
            ownerUserID: String?,
            currentOwnerUserID: String? = nil,
            terminalStatus: SyncEventOutboxProducerTerminalStatus,
            confirmedPriceRows: Int,
            skippedCount: Int = 0,
            failedCount: Int = 0,
            clientEventID: String? = nil,
            sourceDeviceID: String? = nil,
            batchID: UUID? = nil,
            validationEntityIDs: SyncEventJSONValue? = nil,
            validationMetadata: SyncEventJSONValue? = nil
        ) {
            self.ownerUserID = ownerUserID
            self.currentOwnerUserID = currentOwnerUserID
            self.terminalStatus = terminalStatus
            self.confirmedPriceRows = max(0, confirmedPriceRows)
            self.skippedCount = max(0, skippedCount)
            self.failedCount = max(0, failedCount)
            self.clientEventID = clientEventID
            self.sourceDeviceID = sourceDeviceID
            self.batchID = batchID
            self.validationEntityIDs = validationEntityIDs
            self.validationMetadata = validationMetadata
        }
    }

    nonisolated struct CatalogGeneratedProductPrices: Sendable, Equatable {
        let ownerUserID: String?
        let currentOwnerUserID: String?
        let terminalStatus: SyncEventOutboxProducerTerminalStatus
        let confirmedPriceRows: Int
        let productCount: Int
        let skippedCount: Int
        let failedCount: Int
        let clientEventID: String?
        let sourceDeviceID: String?
        let batchID: UUID?
        let validationEntityIDs: SyncEventJSONValue?
        let validationMetadata: SyncEventJSONValue?

        init(
            ownerUserID: String?,
            currentOwnerUserID: String? = nil,
            terminalStatus: SyncEventOutboxProducerTerminalStatus,
            confirmedPriceRows: Int,
            productCount: Int,
            skippedCount: Int = 0,
            failedCount: Int = 0,
            clientEventID: String? = nil,
            sourceDeviceID: String? = nil,
            batchID: UUID? = nil,
            validationEntityIDs: SyncEventJSONValue? = nil,
            validationMetadata: SyncEventJSONValue? = nil
        ) {
            self.ownerUserID = ownerUserID
            self.currentOwnerUserID = currentOwnerUserID
            self.terminalStatus = terminalStatus
            self.confirmedPriceRows = max(0, confirmedPriceRows)
            self.productCount = max(0, productCount)
            self.skippedCount = max(0, skippedCount)
            self.failedCount = max(0, failedCount)
            self.clientEventID = clientEventID
            self.sourceDeviceID = sourceDeviceID
            self.batchID = batchID
            self.validationEntityIDs = validationEntityIDs
            self.validationMetadata = validationMetadata
        }
    }
}

extension SyncEventOutboxProducerOutcome {
    static func clientEventID(prefix: String, fingerprint: String?) -> String? {
        guard let fingerprint else { return nil }
        let trimmed = fingerprint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return "\(prefix):\(sha256Hex(trimmed))"
    }

    private static func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
struct SyncEventOutboxEnqueueService {
    typealias ClientEventIDGenerator = () -> String
    typealias EntryIDGenerator = () -> String
    typealias Clock = () -> Date

    private let validator: SyncEventRecordValidator
    private let clientEventIDGenerator: ClientEventIDGenerator
    private let entryIDGenerator: EntryIDGenerator
    private let clock: Clock
    private let fetchExistingEntry: (String, String) throws -> SyncEventOutboxEntry?
    private let addEntry: (SyncEventOutboxEntry) throws -> Void
    private let saveChanges: () throws -> Void

    init(
        context: ModelContext,
        validator: SyncEventRecordValidator = SyncEventRecordValidator(),
        clientEventIDGenerator: @escaping ClientEventIDGenerator = { UUID().uuidString.lowercased() },
        entryIDGenerator: @escaping EntryIDGenerator = { UUID().uuidString.lowercased() },
        clock: @escaping Clock = Date.init
    ) {
        self.validator = validator
        self.clientEventIDGenerator = clientEventIDGenerator
        self.entryIDGenerator = entryIDGenerator
        self.clock = clock
        self.fetchExistingEntry = { ownerUserID, clientEventID in
            var descriptor = FetchDescriptor<SyncEventOutboxEntry>(
                predicate: #Predicate { entry in
                    entry.ownerUserID == ownerUserID && entry.clientEventID == clientEventID
                },
                sortBy: [
                    SortDescriptor(\SyncEventOutboxEntry.createdAt, order: .forward),
                    SortDescriptor(\SyncEventOutboxEntry.id, order: .forward)
                ]
            )
            descriptor.fetchLimit = 1
            return try context.fetch(descriptor).first
        }
        self.addEntry = { entry in
            SyncEventOutboxLocalStore(context: context).add(entry)
        }
        self.saveChanges = {
            do {
                try context.save()
            } catch {
                context.rollback()
                throw error
            }
        }
    }

    init(
        validator: SyncEventRecordValidator = SyncEventRecordValidator(),
        clientEventIDGenerator: @escaping ClientEventIDGenerator = { UUID().uuidString.lowercased() },
        entryIDGenerator: @escaping EntryIDGenerator = { UUID().uuidString.lowercased() },
        clock: @escaping Clock = Date.init,
        fetchExistingEntry: @escaping (String, String) throws -> SyncEventOutboxEntry?,
        addEntry: @escaping (SyncEventOutboxEntry) throws -> Void,
        saveChanges: @escaping () throws -> Void
    ) {
        self.validator = validator
        self.clientEventIDGenerator = clientEventIDGenerator
        self.entryIDGenerator = entryIDGenerator
        self.clock = clock
        self.fetchExistingEntry = fetchExistingEntry
        self.addEntry = addEntry
        self.saveChanges = saveChanges
    }

    func enqueue(_ outcome: SyncEventOutboxProducerOutcome) -> SyncEventOutboxProducerResult {
        guard let mapped = SyncEventOutboxProducerMapper.map(outcome) else {
            return SyncEventOutboxProducerResult(kind: .skippedUnsupported)
        }

        switch mapped.terminalStatus {
        case .dryRun:
            return SyncEventOutboxProducerResult(kind: .skippedDryRun)
        case .failedPreflight:
            return SyncEventOutboxProducerResult(kind: .skippedFailedPreflight)
        case .noOp:
            return SyncEventOutboxProducerResult(kind: .skippedNoOp)
        case .completed, .partial, .completedBaselineRefreshFailed:
            break
        }

        guard mapped.changedCount > 0 else {
            return SyncEventOutboxProducerResult(kind: .skippedNoOp)
        }

        guard let ownerUserID = normalizedOwner(mapped.ownerUserID) else {
            return SyncEventOutboxProducerResult(kind: .blockedAuth, errorCode: "missing_owner_user_id")
        }

        if let currentOwnerUserID = mapped.currentOwnerUserID,
           normalizedOwner(currentOwnerUserID) != ownerUserID {
            return SyncEventOutboxProducerResult(kind: .blockedAuth, errorCode: "owner_mismatch")
        }

        let clientEventID = normalizedClientEventID(mapped.clientEventID)
            ?? normalizedClientEventID(clientEventIDGenerator())
        guard let clientEventID else {
            return SyncEventOutboxProducerResult(kind: .blockedContract, errorCode: "missing_client_event_id")
        }

        do {
            if let existing = try fetchExistingEntry(ownerUserID, clientEventID) {
                return SyncEventOutboxProducerResult(
                    kind: .duplicateNoOp,
                    entryID: existing.id,
                    entryStatus: existing.status
                )
            }
        } catch {
            return SyncEventOutboxProducerResult(kind: .enqueueFailedLocal, errorCode: "dedupe_fetch_failed")
        }

        let selectedShopID = ShopContextSelection.selectedShopID(ownerUserIDString: ownerUserID)
        let storeIdentity = ShopContextSelection.localStoreIdentity(ownerUserIDString: ownerUserID)
        let request = mapped.request(clientEventID: clientEventID, shopID: selectedShopID)
        var validationFailure: SyncEventRecordError?
        var payloadJSON: SyncEventOutboxStoredPayloadJSON?
        do {
            payloadJSON = try SyncEventOutboxPayloadCodec.makePayloadJSON(
                for: request,
                validator: validator
            )
        } catch {
            validationFailure = payloadValidationFailure(from: error)
        }

        do {
            let now = clock()
            let entry = try SyncEventOutboxFactory.makeEntry(
                ownerUserID: ownerUserID,
                storeId: selectedShopID == nil ? nil : storeIdentity.storeId,
                localStoreId: selectedShopID == nil ? nil : storeIdentity.localStoreId,
                syncProtocolVersion: storeIdentity.syncProtocolVersion,
                schemaVersion: storeIdentity.schemaVersion,
                storeEpoch: storeIdentity.storeEpoch,
                domain: mapped.domain,
                eventType: mapped.eventType,
                changedCount: mapped.changedCount,
                entityIDsShape: mapped.entityIDsShape,
                metadataShape: mapped.metadataShape,
                entityIDsPayloadJSON: payloadJSON?.entityIDsPayloadJSON,
                metadataPayloadJSON: payloadJSON?.metadataPayloadJSON,
                sourceDeviceID: mapped.sourceDeviceID,
                batchID: mapped.batchID?.uuidString.lowercased(),
                now: now,
                id: entryIDGenerator(),
                clientEventID: clientEventID
            )

            if let validationFailure {
                applyValidationFailure(validationFailure, to: entry, now: now)
            }

            try addEntry(entry)
            try saveChanges()

            return result(for: entry)
        } catch {
            return SyncEventOutboxProducerResult(kind: .enqueueFailedLocal, errorCode: "local_save_failed")
        }
    }

    private func payloadValidationFailure(from error: Error) -> SyncEventRecordError {
        if let payloadError = error as? SyncEventOutboxPayloadError {
            switch payloadError {
            case .validationFailed(let recordError):
                return recordError
            case .encodingFailed(let field):
                return .contract(
                    SyncEventRecordFailure(
                        code: "\(field.rawValue)_encoding_failed",
                        message: "Outbox payload could not be encoded for replay."
                    )
                )
            case .missingPayload, .invalidPayloadJSON, .invalidBatchID, .invalidEntryField:
                return .contract(
                    SyncEventRecordFailure(
                        code: "payload_persistence_failed",
                        message: "Outbox payload could not be prepared for replay."
                    )
                )
            }
        }

        if let recordError = error as? SyncEventRecordError {
            return recordError
        }

        return .unknown(SyncEventRecordFailure(code: "payload_unknown", message: String(describing: error)))
    }

    private func applyValidationFailure(
        _ failure: SyncEventRecordError,
        to entry: SyncEventOutboxEntry,
        now: Date
    ) {
        entry.updatedAt = now
        entry.lastAttemptAt = nil
        entry.lastErrorCode = failure.failure.code
        entry.lastErrorKind = failure.plannedOutboxErrorKind
        entry.lastErrorMessageSanitized = failure.failure.message

        switch failure.kind {
        case .contract:
            entry.status = .blockedContract
        case .auth:
            entry.status = .blockedAuth
        case .schema:
            entry.status = .blockedSchema
        case .network, .unknown:
            entry.status = .blockedSchema
            entry.lastErrorKind = .schema
        }
    }

    private func result(for entry: SyncEventOutboxEntry) -> SyncEventOutboxProducerResult {
        switch entry.status {
        case .pending:
            return SyncEventOutboxProducerResult(kind: .enqueued, entryID: entry.id, entryStatus: entry.status)
        case .blockedContract:
            return SyncEventOutboxProducerResult(
                kind: .blockedContract,
                entryID: entry.id,
                entryStatus: entry.status,
                errorCode: entry.lastErrorCode
            )
        case .blockedAuth:
            return SyncEventOutboxProducerResult(
                kind: .blockedAuth,
                entryID: entry.id,
                entryStatus: entry.status,
                errorCode: entry.lastErrorCode
            )
        case .blockedSchema:
            return SyncEventOutboxProducerResult(
                kind: .blockedSchema,
                entryID: entry.id,
                entryStatus: entry.status,
                errorCode: entry.lastErrorCode
            )
        case .localOnly:
            return SyncEventOutboxProducerResult(kind: .enqueued, entryID: entry.id, entryStatus: entry.status)
        case .sending, .sent, .failedRetryable, .dead:
            return SyncEventOutboxProducerResult(kind: .enqueued, entryID: entry.id, entryStatus: entry.status)
        }
    }

    private func normalizedOwner(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    private func normalizedClientEventID(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum SyncEventOutboxProducerMapper {
    private static let catalogDomain = "catalog"
    private static let pricesDomain = "prices"
    private static let catalogEventType = "catalog_changed"
    private static let pricesEventType = "prices_changed"
    private static let catalogSource = "ios_catalog_manual_push"
    private static let pricesSource = "ios_prices_manual_push"
    private static let catalogGeneratedPricesSource = "ios_catalog_generated_prices"

    static func map(_ outcome: SyncEventOutboxProducerOutcome) -> MappedEvent? {
        switch outcome {
        case .catalogManualPush(let catalog):
            return mapCatalog(catalog)
        case .productPriceManualPush(let prices):
            return mapPrices(prices)
        case .catalogGeneratedProductPrices(let prices):
            return mapCatalogGeneratedPrices(prices)
        case .unsupported:
            return nil
        }
    }

    private static func mapCatalog(_ outcome: SyncEventOutboxProducerOutcome.CatalogManualPush) -> MappedEvent {
        let changedCount = outcome.suppliersConfirmed + outcome.categoriesConfirmed + outcome.productsConfirmed
        let isPartial = outcome.terminalStatus == .partial
        let baselineRefreshFailed = outcome.terminalStatus == .completedBaselineRefreshFailed
        let entityIDs = outcome.validationEntityIDs ?? .null
        let metadata = outcome.validationMetadata ?? .object([
            "source": .string(catalogSource),
            "partial": .bool(isPartial),
            "baseline_refresh_failed": .bool(baselineRefreshFailed),
            "skipped_count": .number(Double(outcome.skippedCount)),
            "failed_count": .number(Double(outcome.failedCount))
        ])

        return MappedEvent(
            ownerUserID: outcome.ownerUserID,
            currentOwnerUserID: outcome.currentOwnerUserID,
            clientEventID: outcome.clientEventID,
            terminalStatus: outcome.terminalStatus,
            domain: catalogDomain,
            eventType: catalogEventType,
            changedCount: changedCount,
            entityIDs: entityIDs,
            metadata: metadata,
            entityIDsShape: "suppliers:count=\(outcome.suppliersConfirmed);categories:count=\(outcome.categoriesConfirmed);products:count=\(outcome.productsConfirmed)",
            metadataShape: "source=\(catalogSource);partial=\(isPartial);baselineRefreshFailed=\(baselineRefreshFailed);skipped=\(outcome.skippedCount);failed=\(outcome.failedCount)",
            source: catalogSource,
            sourceDeviceID: outcome.sourceDeviceID,
            batchID: outcome.batchID
        )
    }

    private static func mapPrices(_ outcome: SyncEventOutboxProducerOutcome.ProductPriceManualPush) -> MappedEvent {
        let isPartial = outcome.terminalStatus == .partial
        let entityIDs = outcome.validationEntityIDs ?? .null
        let metadata = outcome.validationMetadata ?? .object([
            "source": .string(pricesSource),
            "partial": .bool(isPartial),
            "skipped_count": .number(Double(outcome.skippedCount)),
            "failed_count": .number(Double(outcome.failedCount))
        ])

        return MappedEvent(
            ownerUserID: outcome.ownerUserID,
            currentOwnerUserID: outcome.currentOwnerUserID,
            clientEventID: outcome.clientEventID,
            terminalStatus: outcome.terminalStatus,
            domain: pricesDomain,
            eventType: pricesEventType,
            changedCount: outcome.confirmedPriceRows,
            entityIDs: entityIDs,
            metadata: metadata,
            entityIDsShape: "price_rows:count=\(outcome.confirmedPriceRows)",
            metadataShape: "source=\(pricesSource);partial=\(isPartial);skipped=\(outcome.skippedCount);failed=\(outcome.failedCount)",
            source: pricesSource,
            sourceDeviceID: outcome.sourceDeviceID,
            batchID: outcome.batchID
        )
    }

    private static func mapCatalogGeneratedPrices(
        _ outcome: SyncEventOutboxProducerOutcome.CatalogGeneratedProductPrices
    ) -> MappedEvent {
        let isPartial = outcome.terminalStatus == .partial
        let entityIDs = outcome.validationEntityIDs ?? .null
        let metadata = outcome.validationMetadata ?? .object([
            "source": .string(catalogGeneratedPricesSource),
            "partial": .bool(isPartial),
            "product_count": .number(Double(outcome.productCount)),
            "skipped_count": .number(Double(outcome.skippedCount)),
            "failed_count": .number(Double(outcome.failedCount))
        ])

        return MappedEvent(
            ownerUserID: outcome.ownerUserID,
            currentOwnerUserID: outcome.currentOwnerUserID,
            clientEventID: outcome.clientEventID,
            terminalStatus: outcome.terminalStatus,
            domain: pricesDomain,
            eventType: pricesEventType,
            changedCount: outcome.confirmedPriceRows,
            entityIDs: entityIDs,
            metadata: metadata,
            entityIDsShape: "price_rows:count=\(outcome.confirmedPriceRows);products:count=\(outcome.productCount)",
            metadataShape: "source=\(catalogGeneratedPricesSource);partial=\(isPartial);products=\(outcome.productCount);skipped=\(outcome.skippedCount);failed=\(outcome.failedCount)",
            source: catalogGeneratedPricesSource,
            sourceDeviceID: outcome.sourceDeviceID,
            batchID: outcome.batchID
        )
    }

    struct MappedEvent: Sendable, Equatable {
        let ownerUserID: String?
        let currentOwnerUserID: String?
        let clientEventID: String?
        let terminalStatus: SyncEventOutboxProducerTerminalStatus
        let domain: String
        let eventType: String
        let changedCount: Int
        let entityIDs: SyncEventJSONValue
        let metadata: SyncEventJSONValue
        let entityIDsShape: String
        let metadataShape: String
        let source: String
        let sourceDeviceID: String?
        let batchID: UUID?

        func request(clientEventID: String, shopID: UUID?) -> SyncEventRecordRequest {
            SyncEventRecordRequest(
                domain: domain,
                eventType: eventType,
                changedCount: changedCount,
                entityIDs: entityIDs,
                metadata: metadata,
                shopID: shopID,
                source: source,
                sourceDeviceID: sourceDeviceID,
                batchID: batchID,
                clientEventID: clientEventID
            )
        }
    }
}
