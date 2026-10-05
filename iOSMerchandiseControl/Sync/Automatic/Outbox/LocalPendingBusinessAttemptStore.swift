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
        context: ModelContext, scope: Task126VerifiedOwnerStoreScope
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
        context.insert(SyncEventOutboxEntry(
            id: pending.changeID, ownerUserID: scope.ownerUserID.uuidString.lowercased(),
            storeId: scope.storeIdentity.storeId, localStoreId: scope.storeIdentity.localStoreId,
            syncProtocolVersion: scope.storeIdentity.syncProtocolVersion,
            schemaVersion: scope.storeIdentity.schemaVersion, storeEpoch: scope.storeIdentity.storeEpoch,
            clientEventID: pending.idempotencyKey, batchID: pending.changeID,
            domain: domain, eventType: kind, changedCount: 1,
            entityIDsShape: ShopSyncRecoveryCanonical.sha256(json), metadataShape: format,
            metadataPayloadJSON: json, status: .localOnly, nextRetryAt: now,
            createdAt: now, updatedAt: now, sourceDeviceID: scope.deviceInstallID
        ))
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

    private static func entry(changeID: String, context: ModelContext) throws -> SyncEventOutboxEntry? {
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
