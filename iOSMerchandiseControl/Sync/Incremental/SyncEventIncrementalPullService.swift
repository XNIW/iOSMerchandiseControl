import Foundation
import SwiftData

@MainActor
final class SyncEventIncrementalPullService: SupabaseManualSyncIncrementalPullProviding {
    private let modelContainer: ModelContainer
    private let remote: SupabaseInventoryService
    private let defaults: UserDefaults
    private let legacyApplyServiceFactory: (
        _ remote: SupabaseInventoryService,
        _ defaults: UserDefaults
    ) -> SupabaseSyncEventIncrementalApplyService

    init(
        modelContainer: ModelContainer,
        remote: SupabaseInventoryService,
        defaults: UserDefaults = .standard,
        legacyApplyServiceFactory: @escaping (
            _ remote: SupabaseInventoryService,
            _ defaults: UserDefaults
        ) -> SupabaseSyncEventIncrementalApplyService = { remote, defaults in
            SupabaseSyncEventIncrementalApplyService(
                eventFetcher: remote,
                inventoryService: remote,
                defaults: defaults
            )
        }
    ) {
        self.modelContainer = modelContainer
        self.remote = remote
        self.defaults = defaults
        self.legacyApplyServiceFactory = legacyApplyServiceFactory
    }

    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SupabaseSyncEventIncrementalApplySummary {
        try await legacyApplyServiceFactory(remote, defaults).applyNextEvents(
            ownerUserID: ownerUserID,
            modelContainer: modelContainer,
            isAuthenticated: true
        )
    }
}
