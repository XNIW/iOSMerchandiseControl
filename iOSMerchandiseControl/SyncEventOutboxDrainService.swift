import Foundation
import SwiftData

nonisolated enum SyncEventOutboxDrainStatus: String, Sendable, Equatable {
    case noWork
    case alreadyRunning
    case drained
    case partiallyDrained
    case blockedPayloadReplay
    case blocked
    case networkFailed
}

nonisolated struct SyncEventOutboxDrainOutcome: Sendable, Equatable {
    let status: SyncEventOutboxDrainStatus
    let attempted: Int
    let sent: Int
    let retryScheduled: Int
    let blocked: Int
    let dead: Int
    let skippedIneligible: Int
    let remainingRetryable: Int?

    init(
        status: SyncEventOutboxDrainStatus,
        attempted: Int = 0,
        sent: Int = 0,
        retryScheduled: Int = 0,
        blocked: Int = 0,
        dead: Int = 0,
        skippedIneligible: Int = 0,
        remainingRetryable: Int? = nil
    ) {
        self.status = status
        self.attempted = attempted
        self.sent = sent
        self.retryScheduled = retryScheduled
        self.blocked = blocked
        self.dead = dead
        self.skippedIneligible = skippedIneligible
        self.remainingRetryable = remainingRetryable
    }
}

nonisolated enum SyncEventOutboxDrainError: Error, Sendable, Equatable {
    case invalidOwnerUserID
    case localSaveFailed(operation: String)
}

@MainActor
struct SyncEventOutboxDrainService {
    typealias Clock = () -> Date

    static let hardLimit = 50
    static let hardFetchScanLimit = 200
    static let defaultRetryDelay: TimeInterval = 60

    private let validator: SyncEventRecordValidator
    private let recorder: any SyncEventRecording
    private let retryDelay: TimeInterval
    private let clock: Clock
    private let fetchRetryable: (String, Date, Int?) throws -> [SyncEventOutboxEntry]
    private let saveChanges: () throws -> Void
    private let rollbackChanges: () -> Void

    init(
        context: ModelContext,
        recorder: any SyncEventRecording,
        validator: SyncEventRecordValidator = SyncEventRecordValidator(),
        retryDelay: TimeInterval = Self.defaultRetryDelay,
        clock: @escaping Clock = Date.init
    ) {
        let store = SyncEventOutboxLocalStore(context: context)
        self.init(
            recorder: recorder,
            validator: validator,
            retryDelay: retryDelay,
            clock: clock,
            fetchRetryable: { ownerUserID, now, limit in
                try store.fetchRetryable(ownerUserID: ownerUserID, now: now, limit: limit)
            },
            saveChanges: {
                try context.save()
            },
            rollbackChanges: {
                context.rollback()
            }
        )
    }

    init(
        recorder: any SyncEventRecording,
        validator: SyncEventRecordValidator = SyncEventRecordValidator(),
        retryDelay: TimeInterval = Self.defaultRetryDelay,
        clock: @escaping Clock = Date.init,
        fetchRetryable: @escaping (String, Date, Int?) throws -> [SyncEventOutboxEntry],
        saveChanges: @escaping () throws -> Void,
        rollbackChanges: @escaping () -> Void = {}
    ) {
        self.validator = validator
        self.recorder = recorder
        self.retryDelay = retryDelay
        self.clock = clock
        self.fetchRetryable = fetchRetryable
        self.saveChanges = saveChanges
        self.rollbackChanges = rollbackChanges
    }

    func drainOnce(
        ownerUserID: String,
        limit: Int,
        fetchScanLimit: Int? = nil
    ) async throws -> SyncEventOutboxDrainOutcome {
        guard let ownerUserID = normalizedOwner(ownerUserID) else {
            throw SyncEventOutboxDrainError.invalidOwnerUserID
        }

        let batchLimit = min(max(0, limit), Self.hardLimit)
        guard batchLimit > 0 else {
            return SyncEventOutboxDrainOutcome(status: .noWork)
        }

        guard SyncEventOutboxDrainCoordinator.acquire(ownerUserID) else {
            return SyncEventOutboxDrainOutcome(status: .alreadyRunning)
        }
        defer {
            SyncEventOutboxDrainCoordinator.release(ownerUserID)
        }

        let scanLimit = resolvedFetchScanLimit(batchLimit: batchLimit, fetchScanLimit: fetchScanLimit)
        let candidates = try fetchRetryable(ownerUserID, clock(), scanLimit)
        guard !candidates.isEmpty else {
            return SyncEventOutboxDrainOutcome(status: .noWork)
        }

        var summary = DrainSummary()

        for entry in candidates {
            guard summary.attempted < batchLimit else {
                break
            }

            let now = clock()
            guard entry.isRetryable(now: now, currentOwnerUserID: ownerUserID) else {
                summary.skippedIneligible += 1
                continue
            }

            let snapshot = entry.state
            let request: SyncEventRecordRequest
            do {
                request = try entry.makeRecordRequestForReplay(validator: validator)
            } catch {
                let failure = payloadReplayFailure(from: error)
                entry.apply(
                    SyncEventOutboxStateMachine.transitionAfterFailure(
                        snapshot,
                        failure: failure,
                        now: clock(),
                        retryDelay: retryDelay
                    )
                )
                try save(operation: "payload_replay_block")
                summary.payloadReplayBlocked += 1
                summary.blocked += 1
                continue
            }

            let sending = SyncEventOutboxStateMachine.toSending(snapshot, now: clock())
            entry.apply(sending)
            summary.attempted += 1

            do {
                _ = try await recorder.record(request)
            } catch is CancellationError {
                entry.apply(snapshot)
                try save(operation: "cancel_restore")
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled {
                entry.apply(snapshot)
                try save(operation: "cancel_restore")
                throw CancellationError()
            } catch let error as SyncEventRecordError {
                applyRecordFailure(error, to: entry, summary: &summary)
                try save(operation: "record_failure_transition")
                continue
            } catch {
                let failure = SyncEventOutboxFailure(
                    kind: .unknown,
                    code: "record_unknown",
                    message: String(describing: error)
                )
                entry.apply(
                    SyncEventOutboxStateMachine.transitionAfterFailure(
                        entry.state,
                        failure: failure,
                        now: clock(),
                        retryDelay: retryDelay
                    )
                )
                summary.recordTransition(entry.status)
                try save(operation: "record_unknown_transition")
                continue
            }

            entry.apply(SyncEventOutboxStateMachine.toSent(entry.state, now: clock()))
            try save(operation: "remote_success_to_sent")
            summary.sent += 1
        }

        return summary.outcome()
    }

    private func applyRecordFailure(
        _ error: SyncEventRecordError,
        to entry: SyncEventOutboxEntry,
        summary: inout DrainSummary
    ) {
        let failure = SyncEventOutboxFailure(
            kind: error.plannedOutboxErrorKind,
            code: privacySafeCode(error.failure.code),
            message: error.failure.message
        )
        entry.apply(
            SyncEventOutboxStateMachine.transitionAfterFailure(
                entry.state,
                failure: failure,
                now: clock(),
                retryDelay: retryDelay
            )
        )
        summary.recordTransition(entry.status)
    }

    private func payloadReplayFailure(from error: Error) -> SyncEventOutboxFailure {
        guard let payloadError = error as? SyncEventOutboxPayloadError else {
            return SyncEventOutboxFailure(
                kind: .contract,
                code: "payload_replay_failed",
                message: "Outbox payload replay failed."
            )
        }

        switch payloadError {
        case .missingPayload(let field):
            return SyncEventOutboxFailure(
                kind: .contract,
                code: "payload_replay_missing_\(field.rawValue)",
                message: "Outbox payload replay is missing required payload."
            )
        case .invalidPayloadJSON(let field):
            return SyncEventOutboxFailure(
                kind: .contract,
                code: "payload_replay_invalid_\(field.rawValue)",
                message: "Outbox payload replay contains invalid JSON."
            )
        case .encodingFailed(let field):
            return SyncEventOutboxFailure(
                kind: .contract,
                code: "payload_replay_encoding_\(field.rawValue)",
                message: "Outbox payload replay could not be encoded."
            )
        case .invalidBatchID:
            return SyncEventOutboxFailure(
                kind: .contract,
                code: "payload_replay_invalid_batch_id",
                message: "Outbox payload replay contains an invalid batch id."
            )
        case .invalidEntryField(let field):
            return SyncEventOutboxFailure(
                kind: .contract,
                code: "payload_replay_invalid_\(field)",
                message: "Outbox payload replay contains an invalid entry field."
            )
        case .validationFailed(let recordError):
            let kind = recordError.plannedOutboxErrorKind
            return SyncEventOutboxFailure(
                kind: kind == .network || kind == .unknown ? .contract : kind,
                code: privacySafeCode(recordError.failure.code) ?? "payload_replay_validation",
                message: recordError.failure.message
            )
        }
    }

    private func save(operation: String) throws {
        do {
            try saveChanges()
        } catch {
            rollbackChanges()
            throw SyncEventOutboxDrainError.localSaveFailed(operation: operation)
        }
    }

    private func resolvedFetchScanLimit(batchLimit: Int, fetchScanLimit: Int?) -> Int {
        let defaultLimit = max(batchLimit * 4, 32)
        let requestedLimit = max(batchLimit, fetchScanLimit ?? defaultLimit)
        return min(requestedLimit, Self.hardFetchScanLimit)
    }

    private func normalizedOwner(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let uuid = UUID(uuidString: trimmed) else {
            return nil
        }
        return uuid.uuidString.lowercased()
    }

    private func privacySafeCode(_ code: String?) -> String? {
        guard let code else { return nil }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !SyncEventOutboxPrivacySanitizer.containsSuspiciousRawPayload(trimmed) else {
            return "redacted_error_code"
        }

        let filtered = trimmed.filter { character in
            character.isLetter || character.isNumber || character == "_" || character == "-" || character == "."
        }
        guard !filtered.isEmpty else { return nil }
        return String(filtered.prefix(80))
    }
}

private struct DrainSummary {
    var attempted = 0
    var sent = 0
    var retryScheduled = 0
    var blocked = 0
    var dead = 0
    var skippedIneligible = 0
    var payloadReplayBlocked = 0

    mutating func recordTransition(_ status: SyncEventOutboxStatus) {
        switch status {
        case .failedRetryable:
            retryScheduled += 1
        case .blockedContract, .blockedAuth, .blockedSchema:
            blocked += 1
        case .dead:
            dead += 1
        case .pending, .sending, .sent, .localOnly:
            break
        }
    }

    func outcome() -> SyncEventOutboxDrainOutcome {
        SyncEventOutboxDrainOutcome(
            status: status(),
            attempted: attempted,
            sent: sent,
            retryScheduled: retryScheduled,
            blocked: blocked,
            dead: dead,
            skippedIneligible: skippedIneligible,
            remainingRetryable: nil
        )
    }

    private func status() -> SyncEventOutboxDrainStatus {
        let nonSuccess = retryScheduled + blocked + dead + skippedIneligible
        if sent > 0 && nonSuccess == 0 {
            return .drained
        }
        if sent > 0 {
            return .partiallyDrained
        }
        if payloadReplayBlocked > 0 && attempted == 0 {
            return .blockedPayloadReplay
        }
        if retryScheduled > 0 || dead > 0 {
            return .networkFailed
        }
        if blocked > 0 {
            return .blocked
        }
        return .noWork
    }
}

@MainActor
private enum SyncEventOutboxDrainCoordinator {
    private static var activeOwnerUserIDs: Set<String> = []

    static func acquire(_ ownerUserID: String) -> Bool {
        guard !activeOwnerUserIDs.contains(ownerUserID) else {
            return false
        }
        activeOwnerUserIDs.insert(ownerUserID)
        return true
    }

    static func release(_ ownerUserID: String) {
        activeOwnerUserIDs.remove(ownerUserID)
    }
}
