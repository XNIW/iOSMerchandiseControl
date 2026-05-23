import Foundation
import SwiftData

final class SyncEventIncrementalPullService: SyncIncrementalPullProviding {
    private let modelContainer: ModelContainer
    private let remote: SupabaseInventoryService
    private let defaults: UserDefaults
    private let domainApplyServiceFactory: (
        _ remote: SupabaseInventoryService,
        _ defaults: UserDefaults
    ) -> SyncEventIncrementalDomainApplyService

    init(
        modelContainer: ModelContainer,
        remote: SupabaseInventoryService,
        defaults: UserDefaults = .standard,
        domainApplyServiceFactory: @escaping (
            _ remote: SupabaseInventoryService,
            _ defaults: UserDefaults
        ) -> SyncEventIncrementalDomainApplyService = { remote, defaults in
            SyncEventIncrementalDomainApplyService(
                eventFetcher: remote,
                inventoryService: remote,
                defaults: defaults
            )
        }
    ) {
        self.modelContainer = modelContainer
        self.remote = remote
        self.defaults = defaults
        self.domainApplyServiceFactory = domainApplyServiceFactory
    }

    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SyncIncrementalPullSummary {
        try await domainApplyServiceFactory(remote, defaults).applyNextEvents(
            ownerUserID: ownerUserID,
            modelContainer: modelContainer,
            isAuthenticated: true
        )
    }
}
