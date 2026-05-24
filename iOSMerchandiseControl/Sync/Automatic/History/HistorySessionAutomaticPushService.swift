import Foundation
import SwiftData

final class HistorySessionPushService: SyncHistorySessionPushProviding {
    private let modelContainer: ModelContainer
    private let remote: SupabaseInventoryService
    private let recorder: (any SyncEventRecording)?

    init(
        modelContainer: ModelContainer,
        remote: SupabaseInventoryService,
        recorder: (any SyncEventRecording)?
    ) {
        self.modelContainer = modelContainer
        self.remote = remote
        self.recorder = recorder
    }

    func syncHistorySessions(
        ownerUserID: UUID,
        mode: SyncHistorySessionMode,
        onProgress: @escaping @MainActor @Sendable (HistorySessionSyncProgress) -> Void
    ) async throws -> SyncHistorySessionSummary {
        guard mode == .incremental else {
            return SyncHistorySessionSummary()
        }
        let modelContainer = self.modelContainer
        let remote = self.remote
        let recorder = self.recorder
        return try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            let entries = try context.fetch(
                FetchDescriptor<HistoryEntry>(
                    sortBy: [SortDescriptor(\HistoryEntry.timestamp, order: .reverse)]
                )
            )
            let service = HistorySessionSyncService(remote: remote)
            let push = try await service.pushPendingHistorySessions(
                entries: entries,
                ownerUserID: ownerUserID,
                context: context,
                includeSynced: false,
                onProgress: onProgress
            )
            try context.save()
            if push.uploadedCount > 0,
               let recorder {
                try await Self.recordHistorySyncEvent(
                    recorder: recorder,
                    ownerUserID: ownerUserID,
                    remoteIDs: Array(push.pushedRemoteIDs)
                )
            }
            return SyncHistorySessionSummary(
                uploaded: push.uploadedCount,
                skippedClean: push.skippedCleanCount,
                skippedOversized: push.skippedOversizedCount
            )
        }.value
    }

    private static func recordHistorySyncEvent(
        recorder: any SyncEventRecording,
        ownerUserID: UUID,
        remoteIDs: [UUID]
    ) async throws {
        let request = SyncEventRecordRequest(
            domain: "history",
            eventType: "upsert",
            changedCount: remoteIDs.count,
            entityIDs: .object([
                "history_session_ids": .array(
                    remoteIDs
                        .sorted { $0.uuidString < $1.uuidString }
                        .map { .string($0.uuidString.lowercased()) }
                )
            ]),
            metadata: .object([
                "source": .string("automatic_history_session_push"),
                "owner_user_id": .string(ownerUserID.uuidString.lowercased())
            ]),
            source: "ios_automatic_runtime",
            clientEventID: "history-automatic-push:\(UUID().uuidString.lowercased())"
        )
        _ = try await recorder.record(request)
    }
}
