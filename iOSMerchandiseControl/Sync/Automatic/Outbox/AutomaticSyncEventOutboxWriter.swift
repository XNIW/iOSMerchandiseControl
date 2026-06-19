import CryptoKit
import Foundation
import SwiftData

nonisolated enum AutomaticSyncEventOutboxWriter {
    private static let maxEntityIDsPerKey = 250

    static func entityIDs(_ idsByKey: [String: [UUID]]) -> SyncEventJSONValue {
        var object: [String: SyncEventJSONValue] = [:]
        for (key, ids) in idsByKey {
            let uniqueIDs = Array(Set(ids)).sorted { $0.uuidString < $1.uuidString }
            guard !uniqueIDs.isEmpty,
                  uniqueIDs.count <= maxEntityIDsPerKey else {
                continue
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
        clientEventFingerprint: String
    ) throws {
        guard changedCount > 0 else { return }
        let owner = ownerUserID.uuidString.lowercased()
        let clientEventID = clientEventID(prefix: source, fingerprint: "\(owner):\(clientEventFingerprint):\(changedCount)")
        if try existingEntry(context: context, ownerUserID: owner, clientEventID: clientEventID) != nil {
            return
        }
        let request = SyncEventRecordRequest(
            domain: domain,
            eventType: eventType,
            changedCount: changedCount,
            entityIDs: entityIDs,
            metadata: metadata,
            source: source,
            sourceDeviceID: DeviceInstallIDStore().deviceInstallID,
            clientEventID: clientEventID
        )
        let payloadJSON = try? SyncEventOutboxPayloadCodec.makePayloadJSON(
            for: request,
            validator: SyncEventRecordValidator()
        )
        let entry = try SyncEventOutboxFactory.makeEntry(
            ownerUserID: owner,
            domain: domain,
            eventType: eventType,
            changedCount: changedCount,
            entityIDsShape: entityIDsShape,
            metadataShape: metadataShape,
            entityIDsPayloadJSON: payloadJSON?.entityIDsPayloadJSON,
            metadataPayloadJSON: payloadJSON?.metadataPayloadJSON,
            sourceDeviceID: DeviceInstallIDStore().deviceInstallID,
            batchID: nil,
            clientEventID: clientEventID
        )
        SyncEventOutboxLocalStore(context: context).add(entry)
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
