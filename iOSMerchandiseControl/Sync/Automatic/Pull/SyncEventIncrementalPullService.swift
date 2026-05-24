import Foundation
import SwiftData

final class SyncEventIncrementalPullService: SyncIncrementalPullProviding {
    private let modelContainer: ModelContainer
    private let remote: any SyncAutomaticIncrementalRemote
    private let defaults: UserDefaults
    private let domainApplyServiceFactory: (
        _ remote: any SyncAutomaticIncrementalRemote,
        _ defaults: UserDefaults
    ) -> SyncEventIncrementalDomainApplyService

    init(
        modelContainer: ModelContainer,
        remote: any SyncAutomaticIncrementalRemote,
        defaults: UserDefaults = .standard,
        domainApplyServiceFactory: @escaping (
            _ remote: any SyncAutomaticIncrementalRemote,
            _ defaults: UserDefaults
        ) -> SyncEventIncrementalDomainApplyService = { remote, defaults in
            SyncEventIncrementalDomainApplyService(
                eventFetcher: remote,
                remote: remote,
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
