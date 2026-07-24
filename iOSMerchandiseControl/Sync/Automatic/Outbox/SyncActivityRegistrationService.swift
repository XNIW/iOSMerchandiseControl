import Foundation
import SwiftData

final class SyncActivityRegistrationService: SyncActivityRegistrationProviding {
    private let modelContainer: ModelContainer
    private let recorder: (any SyncEventRecording)?
    private let now: () -> Date
    private let defaults: UserDefaults

    init(
        modelContainer: ModelContainer,
        recorder: (any SyncEventRecording)?,
        defaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.modelContainer = modelContainer
        self.recorder = recorder
        self.defaults = defaults
        self.now = now
    }

    func loadSyncActivityRegistrationSnapshot(ownerUserID: UUID) async throws -> SyncActivityRegistrationSnapshot {
        let modelContainer = self.modelContainer
        let now = self.now
        let defaults = self.defaults
        return try await Task.detached(priority: .utility) {
            let scope = try Task126OwnerStoreGate.captureAutomaticScope(
                ownerUserID: ownerUserID,
                defaults: defaults,
                allowsPendingSameScopeRecovery: true
            )
            let context = ModelContext(modelContainer)
            let counts = try SyncEventOutboxLocalStore(context: context).fetchCounts(
                ownerUserID: ownerUserID.uuidString.lowercased(),
                storeId: scope.storeIdentity.storeId,
                now: now()
            )
            return SyncActivityRegistrationSnapshot(
                readyToRegister: counts.retryable,
                waiting: counts.pending + counts.failedRetryable,
                notRegisterable: counts.blocked + counts.dead
            )
        }.value
    }

    func registerSyncActivities(ownerUserID: UUID) async throws -> SyncActivityRegistrationResult {
        guard let recorder else {
            return SyncActivityRegistrationResult(
                status: .empty,
                summary: SyncActivityRegistrationSummary(registered: 0, waiting: 0, notRegisterable: 0)
            )
        }
        let modelContainer = self.modelContainer
        let now = self.now
        let defaults = self.defaults
        return try await Task.detached(priority: .utility) {
            let scope = try Task126OwnerStoreGate.captureAutomaticScope(
                ownerUserID: ownerUserID,
                defaults: defaults,
                allowsPendingSameScopeRecovery: true
            )
            let context = ModelContext(modelContainer)
            let before = try SyncEventOutboxLocalStore(context: context).fetchCounts(
                ownerUserID: ownerUserID.uuidString.lowercased(),
                storeId: scope.storeIdentity.storeId,
                now: now()
            )
            guard before.retryable > 0 else {
                return SyncActivityRegistrationResult(
                    status: before.blocked + before.dead > 0 ? .blocked : .empty,
                    summary: SyncActivityRegistrationSummary(
                        registered: 0,
                        waiting: before.pending + before.failedRetryable,
                        notRegisterable: before.blocked + before.dead
                    )
                )
            }
            let outcome = try await SyncEventOutboxDrainer(
                context: context,
                recorder: recorder,
                automaticScope: scope,
                defaults: defaults,
                now: now
            ).drainOnce(ownerUserID: ownerUserID)
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
            let after = try SyncEventOutboxLocalStore(context: context).fetchCounts(
                ownerUserID: ownerUserID.uuidString.lowercased(),
                storeId: scope.storeIdentity.storeId,
                now: now()
            )
            return SyncActivityRegistrationResult(
                status: Self.status(outcome: outcome, after: after),
                summary: SyncActivityRegistrationSummary(
                    registered: outcome.sent,
                    waiting: after.pending + after.failedRetryable,
                    notRegisterable: after.blocked + after.dead
                )
            )
        }.value
    }

    nonisolated private static func status(
        outcome: SyncEventOutboxDrainOutcome,
        after: SyncEventOutboxCounts
    ) -> SyncActivityRegistrationStatus {
        switch outcome.status {
        case .drained:
            return after.pending + after.failedRetryable > 0 ? .partialRetryable : .success
        case .partiallyDrained:
            return .partialRetryable
        case .noWork:
            return after.blocked + after.dead > 0 ? .blocked : .empty
        case .alreadyRunning, .networkFailed:
            return .retryableFailure
        case .blockedPayloadReplay, .blocked:
            return .blocked
        }
    }

}
