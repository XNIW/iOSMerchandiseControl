import CryptoKit
import Foundation
import SwiftData

nonisolated enum AutomaticSyncEventOutboxWriter {
    private static let maxEntityIDsPerKey = 250

    static func entityIDs(_ idsByKey: [String: [UUID]]) throws -> SyncEventJSONValue {
        var object: [String: SyncEventJSONValue] = [:]
        for (key, ids) in idsByKey {
            let uniqueIDs = Array(Set(ids)).sorted { $0.uuidString < $1.uuidString }
            guard !uniqueIDs.isEmpty else { continue }
            guard uniqueIDs.count <= maxEntityIDsPerKey else {
                throw SyncEventRecordError.contract(
                    SyncEventRecordFailure(
                        code: "entity_ids_array_budget",
                        message: "entity_ids exceeds array element budget."
                    )
                )
            }
            object[key] = .array(uniqueIDs.map { .string($0.uuidString.lowercased()) })
        }
        return object.isEmpty ? .null : .object(object)
    }

    static func enqueue(
        context: ModelContext,
        ownerUserID: UUID,
        domain: String,
        eventType: String,
        changedCount: Int,
        entityIDs: SyncEventJSONValue,
        metadata: SyncEventJSONValue,
        source: String,
        entityIDsShape: String,
        metadataShape: String,
        clientEventFingerprint: String,
        scope: Task126VerifiedOwnerStoreScope,
        defaults: UserDefaults = .standard
    ) throws {
        guard changedCount > 0 else { return }
        guard scope.ownerUserID == ownerUserID else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        try enqueueWithValidatedScopeLeaseHeld(
            context: context,
            ownerUserID: ownerUserID,
            domain: domain,
            eventType: eventType,
            changedCount: changedCount,
            entityIDs: entityIDs,
            metadata: metadata,
            source: source,
            entityIDsShape: entityIDsShape,
            metadataShape: metadataShape,
            clientEventFingerprint: clientEventFingerprint,
            scope: scope
        )
    }

    /// Caller already owns the validated Task126 lease. Keeping the local
    /// metadata merge, pending CAS and outbox insert in one SwiftData commit
    /// avoids a crash window without recursively acquiring the non-recursive
    /// owner/shop lease.
    static func enqueueWithValidatedScopeLeaseHeld(
        context: ModelContext,
        ownerUserID: UUID,
        domain: String,
        eventType: String,
        changedCount: Int,
        entityIDs: SyncEventJSONValue,
        metadata: SyncEventJSONValue,
        source: String,
        entityIDsShape: String,
        metadataShape: String,
        clientEventFingerprint: String,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        guard changedCount > 0 else { return }
        guard scope.ownerUserID == ownerUserID else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
        let owner = ownerUserID.uuidString.lowercased()
        let shopFingerprint = scope.shopID.uuidString.lowercased()
        let clientEventID = clientEventID(prefix: source, fingerprint: "\(owner):\(shopFingerprint):\(clientEventFingerprint):\(changedCount)")
        let request = SyncEventRecordRequest(
            domain: domain,
            eventType: eventType,
            changedCount: changedCount,
            entityIDs: entityIDs,
            metadata: metadata,
            shopID: scope.shopID,
            source: source,
            sourceDeviceID: scope.deviceInstallID,
            clientEventID: clientEventID
        )
        try validateCompleteEntityIDs(
            entityIDs,
            domain: domain,
            changedCount: changedCount
        )
        let payloadJSON = try SyncEventOutboxPayloadCodec.makePayloadJSON(
            for: request,
            validator: SyncEventRecordValidator()
        )
        if try existingEntry(context: context, ownerUserID: owner, clientEventID: clientEventID) != nil {
            return
        }
        let entry = try SyncEventOutboxFactory.makeEntry(
            ownerUserID: owner,
            storeId: scope.storeIdentity.storeId,
            localStoreId: scope.storeIdentity.localStoreId,
            syncProtocolVersion: scope.storeIdentity.syncProtocolVersion,
            schemaVersion: scope.storeIdentity.schemaVersion,
            storeEpoch: scope.storeIdentity.storeEpoch,
            domain: domain,
            eventType: eventType,
            changedCount: changedCount,
            entityIDsShape: entityIDsShape,
            metadataShape: metadataShape,
            entityIDsPayloadJSON: payloadJSON.entityIDsPayloadJSON,
            metadataPayloadJSON: payloadJSON.metadataPayloadJSON,
            sourceDeviceID: scope.deviceInstallID,
            batchID: nil,
            clientEventID: clientEventID
        )
        SyncEventOutboxLocalStore(context: context).add(entry)
    }

    private static func validateCompleteEntityIDs(
        _ entityIDs: SyncEventJSONValue,
        domain: String,
        changedCount: Int
    ) throws {
        let ids = SyncEventEntityIDSet(json: entityIDs)
        let complete: Bool
        switch domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "catalog":
            complete = ids.isCompleteCatalog(changedCount: changedCount)
        case "prices":
            complete = ids.isCompletePrices(changedCount: changedCount)
        case "history":
            complete = ids.isCompleteHistory(changedCount: changedCount)
        default:
            complete = false
        }
        guard complete else {
            throw SyncEventRecordError.contract(
                SyncEventRecordFailure(
                    code: "entity_ids_incomplete",
                    message: "entity_ids do not match changed_count and domain."
                )
            )
        }
    }

    private static func existingEntry(
        context: ModelContext,
        ownerUserID: String,
        clientEventID: String
    ) throws -> SyncEventOutboxEntry? {
        var descriptor = FetchDescriptor<SyncEventOutboxEntry>(
            predicate: #Predicate<SyncEventOutboxEntry> { entry in
                entry.ownerUserID == ownerUserID && entry.clientEventID == clientEventID
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func clientEventID(prefix: String, fingerprint: String) -> String {
        let digest = SHA256.hash(data: Data(fingerprint.utf8))
        let suffix = digest.map { String(format: "%02x", $0) }.joined()
        return "\(prefix):\(suffix)"
    }
}
