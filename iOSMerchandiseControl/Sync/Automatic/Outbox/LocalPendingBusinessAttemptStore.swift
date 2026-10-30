import Foundation
import SwiftData

/// The existing local outbox also owns the immutable business request until
/// its response is acknowledged. These local-only entries never reach the
/// sync-event RPC; the original domain service replays its own typed request.
nonisolated enum LocalPendingBusinessAttemptStore {
    static let domain = "local_business_attempt"
    private static let format = "sealed_business_attempt_v1"
    private static let maximumBytes = HistorySessionPushService.maximumHistoryRequestBytes

    struct Envelope<Payload: Codable>: Codable {
        let schemaVersion: Int
        let pending: LocalPendingChangeCASToken
        let payload: Payload
    }

    private struct Header: Decodable {
        let schemaVersion: Int
        let pending: LocalPendingChangeCASToken
    }

    /// A server rejection is useful only while it still names the complete
    /// immutable request. It is cleared durably before each later dispatch.
    struct RejectedWithoutCommitProof: Codable, Equatable, Sendable {
        let schemaVersion: Int
        let sqlstate: String
        let changeID: String
        let idempotencyKey: String
        let sealSHA256: String
        let pending: LocalPendingChangeCASToken
        let dispatchJournalVersion: Int
        let dispatchOrdinal: Int
        let hadPriorUnknown: Bool
        let receivedAt: Date
    }

    struct CatalogDispatchWitness: Sendable {
        let pending: LocalPendingChangeCASToken
        let sealSHA256: String
        let ordinal: Int
        let hadPriorUnknown: Bool
    }

    /// Only a new, versioned preparation can prove there was no earlier HTTP
    /// dispatch. A legacy count of zero is not such proof. Persisting in-flight
    /// before HTTP makes a crash conservative at every subsequent invocation.
    static func beginCatalogDispatch(pending: LocalPendingChangeCASToken, context: ModelContext,
                                     scope: Task126VerifiedOwnerStoreScope) throws -> CatalogDispatchWitness {
        guard let sealed = try entry(changeID: pending.changeID, context: context) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let sealedData = try validate(sealed, kind: "catalog", scope: scope)
        let header = try JSONDecoder().decode(Header.self, from: sealedData)
        let id = pending.changeID
        var query = FetchDescriptor<LocalPendingChange>(predicate: #Predicate { $0.changeID == id }); query.fetchLimit = 2
        let rows = try context.fetch(query)
        guard rows.count == 1, let row = rows.first, pending.matches(row), header.pending == pending,
              try !LocalCatalogConflictResolutionStore.resolvedChangeIDs(context: context).contains(id) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let hadPriorUnknown = sealed.lastErrorKindRaw != "catalog_prepared_not_dispatched_v2" || sealed.attemptCount != 0
        guard sealed.attemptCount >= 0, sealed.attemptCount < Int.max else { throw SyncStoreGenerationError.activationReadBackFailed }
        let ordinal = sealed.attemptCount + 1
        sealed.attemptCount = ordinal
        sealed.lastErrorKindRaw = "catalog_dispatch_in_flight_v2"
        sealed.lastErrorCode = nil; sealed.lastErrorMessageSanitized = nil
        try context.save()
        let persisted = try entry(changeID: pending.changeID, context: ModelContext(context.container))
        guard persisted?.attemptCount == ordinal, persisted?.lastErrorKindRaw == "catalog_dispatch_in_flight_v2",
              persisted?.entityIDsShape == sealed.entityIDsShape else { throw SyncStoreGenerationError.activationReadBackFailed }
        return CatalogDispatchWitness(pending: pending, sealSHA256: sealed.entityIDsShape,
                                      ordinal: ordinal, hadPriorUnknown: hadPriorUnknown)
    }

    static func rejectionProof(change: LocalPendingChange, context: ModelContext,
                               scope: Task126VerifiedOwnerStoreScope) throws -> RejectedWithoutCommitProof? {
        guard let sealed = try entry(changeID: change.changeID, context: context) else { return nil }
        _ = try validate(sealed, kind: "catalog", scope: scope)
        guard sealed.lastErrorKindRaw == "catalog_atomic_rejection_v1" else { return nil }
        guard let raw = sealed.lastErrorMessageSanitized, let data = raw.data(using: .utf8) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let proof = try JSONDecoder().decode(RejectedWithoutCommitProof.self, from: data)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard try encoder.encode(proof) == data, proof.schemaVersion == 1,
              proof.dispatchJournalVersion == 2, proof.dispatchOrdinal == 1, !proof.hadPriorUnknown,
              sealed.attemptCount == proof.dispatchOrdinal,
              ["23503", "23505"].contains(proof.sqlstate), sealed.lastErrorCode == proof.sqlstate,
              proof.changeID == change.changeID, proof.idempotencyKey == change.idempotencyKey,
              proof.sealSHA256 == sealed.entityIDsShape, proof.pending.matches(change) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        return proof
    }

    @discardableResult
    static func recordRejectedWithoutCommit(_ rejection: SyncCatalogWriteRejectedWithoutCommit,
        pending: LocalPendingChangeCASToken, dispatch: CatalogDispatchWitness, context: ModelContext,
        scope: Task126VerifiedOwnerStoreScope) throws -> Bool {
        guard ["23503", "23505"].contains(rejection.sqlstate),
              let sealed = try entry(changeID: pending.changeID, context: context),
              let change = try context.fetch(FetchDescriptor<LocalPendingChange>()).first(where: {
                  $0.changeID == pending.changeID
              }), pending.matches(change) else { throw SyncStoreGenerationError.activationReadBackFailed }
        _ = try validate(sealed, kind: "catalog", scope: scope)
        guard dispatch.pending == pending, dispatch.sealSHA256 == sealed.entityIDsShape,
              dispatch.ordinal == sealed.attemptCount,
              sealed.lastErrorKindRaw == "catalog_dispatch_in_flight_v2" else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        guard !dispatch.hadPriorUnknown else {
            try recordUnconfirmed(pending: pending, context: context, scope: scope)
            return false
        }
        let proof = RejectedWithoutCommitProof(schemaVersion: 1, sqlstate: rejection.sqlstate,
            changeID: pending.changeID, idempotencyKey: pending.idempotencyKey,
            sealSHA256: sealed.entityIDsShape, pending: pending, dispatchJournalVersion: 2,
            dispatchOrdinal: dispatch.ordinal, hadPriorUnknown: dispatch.hadPriorUnknown, receivedAt: Date())
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        sealed.lastErrorCode = rejection.sqlstate
        sealed.lastErrorKindRaw = "catalog_atomic_rejection_v1"
        sealed.lastErrorMessageSanitized = String(decoding: try encoder.encode(proof), as: UTF8.self)
        try context.save()
        let fresh = ModelContext(context.container)
        guard let persisted = try fresh.fetch(FetchDescriptor<LocalPendingChange>()).first(where: {
            $0.changeID == pending.changeID
        }), try rejectionProof(change: persisted, context: fresh, scope: scope) == proof else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        return true
    }

    static func clearRejectionBeforeDispatch(changeID: String, context: ModelContext) throws {
        guard let sealed = try entry(changeID: changeID, context: context),
              sealed.lastErrorKindRaw == "catalog_atomic_rejection_v1" else { return }
        sealed.lastErrorCode = "catalog_unconfirmed"; sealed.lastErrorKindRaw = "catalog_outcome_unconfirmed_v1"
        sealed.lastErrorMessageSanitized = nil
        try context.save()
    }

    static func recordUnconfirmed(pending: LocalPendingChangeCASToken, context: ModelContext,
                                  scope: Task126VerifiedOwnerStoreScope) throws {
        guard let sealed = try entry(changeID: pending.changeID, context: context) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        _ = try validate(sealed, kind: "catalog", scope: scope)
        sealed.lastErrorCode = "catalog_unconfirmed"
        sealed.lastErrorKindRaw = "catalog_outcome_unconfirmed_v1"
        sealed.lastErrorMessageSanitized = nil
        try context.save()
    }

    static func load<Payload: Codable>(
        _ type: Payload.Type, change: LocalPendingChange, kind: String,
        context: ModelContext, scope: Task126VerifiedOwnerStoreScope
    ) throws -> Payload? {
        guard let entry = try entry(changeID: change.changeID, context: context) else { return nil }
        let data = try validate(entry, kind: kind, scope: scope)
        let envelope = try JSONDecoder().decode(Envelope<Payload>.self, from: data)
        guard envelope.pending.matches(change) else { throw SyncStoreGenerationError.activationReadBackFailed }
        return envelope.payload
    }

    static func seal<Payload: Codable>(
        _ payload: Payload, pending: LocalPendingChangeCASToken, kind: String,
        context: ModelContext, scope: Task126VerifiedOwnerStoreScope,
        priorCatalogAttemptIsKnownAbsent: Bool = false
    ) throws {
        guard try entry(changeID: pending.changeID, context: context) == nil else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(Envelope(schemaVersion: 1, pending: pending, payload: payload))
        guard data.count <= maximumBytes, let json = String(data: data, encoding: .utf8) else {
            throw SyncStoreGenerationError.generationResourceBudgetExceeded
        }
        let now = Date()
        let sealedEntry = SyncEventOutboxEntry(
            id: pending.changeID, ownerUserID: scope.ownerUserID.uuidString.lowercased(),
            storeId: scope.storeIdentity.storeId, localStoreId: scope.storeIdentity.localStoreId,
            syncProtocolVersion: scope.storeIdentity.syncProtocolVersion,
            schemaVersion: scope.storeIdentity.schemaVersion, storeEpoch: scope.storeIdentity.storeEpoch,
            clientEventID: pending.idempotencyKey, batchID: pending.changeID,
            domain: domain, eventType: kind, changedCount: 1,
            entityIDsShape: ShopSyncRecoveryCanonical.sha256(json), metadataShape: format,
            metadataPayloadJSON: json, status: .localOnly, nextRetryAt: now,
            createdAt: now, updatedAt: now, sourceDeviceID: scope.deviceInstallID
        )
        if kind == "catalog" {
            // The caller captures this before assigning the preparation time.
            // A new automatic envelope cannot erase an earlier unsealed manual
            // attempt. Unknown history remains sticky across replay and reopen.
            sealedEntry.lastErrorKindRaw = priorCatalogAttemptIsKnownAbsent
                ? "catalog_prepared_not_dispatched_v2" : "catalog_outcome_unconfirmed_v1"
            if !priorCatalogAttemptIsKnownAbsent { sealedEntry.lastErrorCode = "catalog_unconfirmed" }
        }
        context.insert(sealedEntry)
        // Seal and attempted marker are one durable SwiftData save, before HTTP.
        try context.save()
        guard let saved = try entry(changeID: pending.changeID, context: ModelContext(context.container)),
              try validate(saved, kind: kind, scope: scope) == data else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
    }

    static func remove(changeID: String, context: ModelContext) throws {
        if let saved = try entry(changeID: changeID, context: context) { context.delete(saved) }
    }

    static func isSealed(_ entry: SyncEventOutboxEntry) -> Bool {
        entry.domain == domain && entry.status == .localOnly
    }

    @discardableResult
    static func validate(
        _ entry: SyncEventOutboxEntry, kind: String? = nil,
        scope: Task126VerifiedOwnerStoreScope
    ) throws -> Data {
        guard isSealed(entry), entry.metadataShape == format,
              kind == nil || entry.eventType == kind,
              entry.eventType == "catalog" || entry.eventType == "history",
              entry.ownerUserID == scope.ownerUserID.uuidString.lowercased(),
              entry.storeId == scope.storeIdentity.storeId,
              entry.localStoreId == scope.storeIdentity.localStoreId,
              entry.syncProtocolVersion == scope.storeIdentity.syncProtocolVersion,
              entry.schemaVersion == scope.storeIdentity.schemaVersion,
              entry.storeEpoch == scope.storeIdentity.storeEpoch,
              entry.sourceDeviceID == scope.deviceInstallID,
              let json = entry.metadataPayloadJSON, json.utf8.count <= maximumBytes,
              ShopSyncRecoveryCanonical.sha256(json) == entry.entityIDsShape,
              let data = json.data(using: .utf8) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let header = try JSONDecoder().decode(Header.self, from: data)
        let token = header.pending
        guard header.schemaVersion == 1, token.changeID == entry.id,
              token.changeID == entry.batchID, token.idempotencyKey == entry.clientEventID,
              token.ownerUserID == entry.ownerUserID, token.storeId == entry.storeId,
              token.localStoreId == entry.localStoreId, token.schemaVersion == entry.schemaVersion,
              token.syncProtocolVersion == entry.syncProtocolVersion, token.storeEpoch == entry.storeEpoch,
              token.lastAttemptAt != nil else { throw SyncStoreGenerationError.activationReadBackFailed }
        return data
    }

    static func entry(changeID: String, context: ModelContext) throws -> SyncEventOutboxEntry? {
        let attemptedDomain = domain
        var descriptor = FetchDescriptor<SyncEventOutboxEntry>(predicate: #Predicate {
            $0.id == changeID && $0.domain == attemptedDomain
        })
        descriptor.fetchLimit = 2
        let rows = try context.fetch(descriptor)
        guard rows.count <= 1 else { throw SyncStoreGenerationError.activationReadBackFailed }
        return rows.first
    }
}
