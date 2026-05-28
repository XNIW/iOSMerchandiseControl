import Foundation

nonisolated enum HistorySessionPayloadSnapshotFactory {
    static func snapshot(
        for entry: HistoryEntry,
        ensureRemoteID: Bool
    ) -> HistorySessionLocalPayloadSnapshot {
        let remoteID = ensureRemoteID
            ? entry.ensureHistorySessionRemoteID()
            : (entry.remoteID ?? entry.uid)
        return HistorySessionLocalPayloadSnapshot(
            remoteID: remoteID,
            localID: entry.uid,
            payloadVersion: HistorySessionPayloadCodec.payloadVersion,
            displayName: entry.title,
            timestamp: entry.timestamp,
            supplier: entry.supplier,
            category: entry.category,
            isManualEntry: entry.isManualEntry,
            data: entry.data,
            editable: entry.editable,
            complete: entry.complete,
            deletedAt: entry.remoteDeletedAt
        )
    }
}
