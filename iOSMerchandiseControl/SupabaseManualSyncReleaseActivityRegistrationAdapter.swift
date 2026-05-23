import Foundation
import SwiftData

@MainActor
final class SyncActivityRegistrationAdapter: SyncActivityRegistrationProviding, SupabaseManualSyncActivityRegistrationProviding {
    private let context: ModelContext
    private let recorder: any SyncEventRecording
    private let now: () -> Date
    private let limit: Int

    init(
        context: ModelContext,
        recorder: any SyncEventRecording,
        now: @escaping () -> Date = Date.init,
        limit: Int = SyncEventOutboxDrainService.hardLimit
    ) {
        self.context = context
        self.recorder = recorder
        self.now = now
        self.limit = min(max(0, limit), SyncEventOutboxDrainService.hardLimit)
    }

    func loadActivityRegistrationSnapshot(ownerUserID: UUID) async throws -> SupabaseManualSyncActivityRegistrationSnapshot {
        try Task.checkCancellation()
        return try snapshot(ownerUserID: ownerUserID)
    }

    func loadSyncActivityRegistrationSnapshot(ownerUserID: UUID) async throws -> SyncActivityRegistrationSnapshot {
        let snapshot = try await loadActivityRegistrationSnapshot(ownerUserID: ownerUserID)
        return SyncActivityRegistrationSnapshot(
            readyToRegister: snapshot.readyToRegister,
            waiting: snapshot.waiting,
            notRegisterable: snapshot.notRegisterable
        )
    }

    func registerActivities(ownerUserID: UUID) async throws -> SupabaseManualSyncActivityRegistrationResult {
        try Task.checkCancellation()
        let before = try snapshot(ownerUserID: ownerUserID)
        guard before.readyToRegister > 0, limit > 0 else {
            let status: SupabaseManualSyncActivityRegistrationStatus = {
                if before.notRegisterable > 0 {
                    return .blocked
                }
                if before.waiting > 0 {
                    return .retryableFailure
                }
                return .empty
            }()
            return SupabaseManualSyncActivityRegistrationResult(
                status: status,
                summary: SupabaseManualSyncActivityRegistrationSummary(
                    registered: 0,
                    waiting: before.waiting,
                    notRegisterable: before.notRegisterable
                )
            )
        }

        let drainer = SyncEventOutboxDrainer(context: context, recorder: recorder, now: now)
        let outcome = try await drainer.drainOnce(
            ownerUserID: ownerUserID,
            limit: min(limit, before.readyToRegister)
        )
        try Task.checkCancellation()

        let after = try snapshot(ownerUserID: ownerUserID)
        let summary = SupabaseManualSyncActivityRegistrationSummary(
            registered: outcome.sent,
            waiting: after.waiting,
            notRegisterable: after.notRegisterable
        )

        return SupabaseManualSyncActivityRegistrationResult(
            status: status(outcome: outcome, after: after),
            summary: summary
        )
    }

    func registerSyncActivities(ownerUserID: UUID) async throws -> SyncActivityRegistrationResult {
        let result = try await registerActivities(ownerUserID: ownerUserID)
        return SyncActivityRegistrationResult(
            status: SyncActivityRegistrationStatus(result.status),
            summary: SyncActivityRegistrationSummary(
                registered: result.summary.registered,
                waiting: result.summary.waiting,
                notRegisterable: result.summary.notRegisterable
            )
        )
    }

    private func snapshot(ownerUserID: UUID) throws -> SupabaseManualSyncActivityRegistrationSnapshot {
        let counts = try LocalOutboxStore(context: context).fetchCounts(
            ownerUserID: ownerUserID,
            now: now()
        )
        let waiting = counts.pending + counts.failedRetryable
        let notRegisterable = counts.blocked + counts.dead
        return SupabaseManualSyncActivityRegistrationSnapshot(
            readyToRegister: counts.retryable,
            waiting: waiting,
            notRegisterable: notRegisterable
        )
    }

    private func status(
        outcome: SyncEventOutboxDrainOutcome,
        after: SupabaseManualSyncActivityRegistrationSnapshot
    ) -> SupabaseManualSyncActivityRegistrationStatus {
        switch outcome.status {
        case .drained:
            if after.waiting > 0 {
                return .partialRetryable
            }
            return after.notRegisterable > 0 ? .blocked : .success
        case .partiallyDrained:
            return after.waiting > 0 ? .partialRetryable : (after.notRegisterable > 0 ? .blocked : .success)
        case .noWork:
            return after.notRegisterable > 0 ? .blocked : .empty
        case .alreadyRunning, .networkFailed:
            return outcome.sent > 0 ? .partialRetryable : .retryableFailure
        case .blockedPayloadReplay, .blocked:
            return outcome.sent > 0 ? .partialRetryable : .blocked
        }
    }
}

private extension SyncActivityRegistrationStatus {
    init(_ status: SupabaseManualSyncActivityRegistrationStatus) {
        switch status {
        case .success:
            self = .success
        case .empty:
            self = .empty
        case .partialRetryable:
            self = .partialRetryable
        case .authRequired:
            self = .authRequired
        case .retryableFailure:
            self = .retryableFailure
        case .blocked:
            self = .blocked
        case .cancelled:
            self = .cancelled
        }
    }
}
