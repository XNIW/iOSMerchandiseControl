import Foundation
import SwiftData

@MainActor
final class SyncEventIncrementalPullService: SupabaseManualSyncIncrementalPullProviding {
    private let modelContainer: ModelContainer
    private let remote: SupabaseInventoryService
    private let defaults: UserDefaults

    init(
        modelContainer: ModelContainer,
        remote: SupabaseInventoryService,
        defaults: UserDefaults = .standard
    ) {
        self.modelContainer = modelContainer
        self.remote = remote
        self.defaults = defaults
    }

    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SupabaseSyncEventIncrementalApplySummary {
        try await SupabaseSyncEventIncrementalApplyService(
            eventFetcher: remote,
            inventoryService: remote,
            defaults: defaults
        ).applyNextEvents(
            ownerUserID: ownerUserID,
            modelContainer: modelContainer,
            isAuthenticated: true
        )
    }
}
