import Foundation

struct HistorySessionRemoteSupabaseAdapter: HistorySessionRemoteWriting {
    let remote: SupabaseInventoryService

    func upsertSharedSheetSessions(
        _ rows: [SharedSheetSessionUpsertRow],
        ownerUserID: UUID
    ) async throws -> [RemoteSharedSheetSessionRow] {
        try await remote.upsertSharedSheetSessions(rows, ownerUserID: ownerUserID)
    }

    func fetchSharedSheetSessionsPage(
        ownerUserID: UUID,
        from: Int,
        to: Int
    ) async throws -> [RemoteSharedSheetSessionRow] {
        try await remote.fetchSharedSheetSessionsPage(ownerUserID: ownerUserID, from: from, to: to)
    }

    func fetchSharedSheetSessionsByIDs(
        ownerUserID: UUID,
        sessionIDs: Set<UUID>
    ) async throws -> [RemoteSharedSheetSessionRow] {
        try await remote.fetchSharedSheetSessionsByIDs(ownerUserID: ownerUserID, sessionIDs: sessionIDs)
    }
}
