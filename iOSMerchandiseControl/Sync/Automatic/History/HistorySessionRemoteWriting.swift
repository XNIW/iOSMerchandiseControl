import Foundation

protocol HistorySessionRemoteWriting: HistorySessionRemoteSyncing {
    func fetchSharedSheetSessionsByIDs(
        ownerUserID: UUID,
        sessionIDs: Set<UUID>
    ) async throws -> [RemoteSharedSheetSessionRow]
}
