import Foundation
import SwiftData

@MainActor
struct SyncEventOutboxDrainer {
    private let service: SyncEventOutboxDrainService

    init(
        context: ModelContext,
        recorder: any SyncEventRecording,
        automaticScope: Task126VerifiedOwnerStoreScope? = nil,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.service = SyncEventOutboxDrainService(
            context: context,
            recorder: recorder,
            automaticScope: automaticScope,
            defaults: defaults,
            clock: now
        )
    }

    func drainOnce(
        ownerUserID: UUID,
        limit: Int = SyncEventOutboxDrainService.hardLimit
    ) async throws -> SyncEventOutboxDrainOutcome {
        try await service.drainOnce(
            ownerUserID: ownerUserID.uuidString.lowercased(),
            limit: limit
        )
    }
}
