import Foundation
import Combine

nonisolated enum SyncAutomaticRecoveryAttemptEligibility: Equatable, Sendable {
    case ready
    case cooldown(TimeInterval)
    case exhausted
}

private nonisolated struct SyncAutomaticRecoveryAttemptRecord: Codable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let identity: String
    let attemptCount: Int
    let nextAllowedAt: TimeInterval
}

@MainActor
final class SyncStateStore: ObservableObject {
    private static let convergenceProofVersion = 1
    let objectWillChange = ObservableObjectPublisher()
    private var storedState = SyncState()
    private var continuedGeneration: SyncIncrementalContinuationReceipt?

    private(set) var state: SyncState {
        get {
            guard storedState.phase == .idle, let receipt = continuedGeneration else { return storedState }
            do {
                return try receipt.withValidatedAuthority(defaults: defaults, checkLocalCounts: false) { storedState }
            } catch {
                var invalidated = storedState
                invalidated.phase = .recoveryRequired
                return invalidated
            }
        }
        set {
            // Notify outside Task126's non-recursive lease. A synchronous
            // observer may read state or invalidate identity safely here.
            objectWillChange.send()
            continuedGeneration = nil
            storedState = newValue
        }
    }
    private let defaults: UserDefaults
    private let keyPrefix: String

    var recoveryJournalIsPending: Bool {
        // Do not retain a second journal-store object in this presentation
        // model.  The journal is a UserDefaults-backed durable latch, so a
        // fresh read is both authoritative and avoids extending the lifetime
        // of replacement-coordinator state across test/app teardown.
        AccountBindingStore(defaults: defaults).hasPendingReplacementJournal
    }

    var pendingRecoveryJournal: AccountRecoveryJournalSnapshot? {
        AccountBindingStore(defaults: defaults).pendingRecoveryJournal
    }

    private var automaticRecoveryAttemptKey: String {
        "\(keyPrefix).automaticRecoveryAttempt.v1"
    }

    init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "sync.runtime.orchestrator"
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
        state = Self.hydratedState(
            defaults: defaults,
            keyPrefix: keyPrefix,
            hasPendingRecoveryJournal: AccountBindingStore(defaults: defaults)
                .hasPendingReplacementJournal
        )
    }

    // This type owns only synchronous Foundation/Combine values.  Keeping
    // destruction nonisolated avoids asking the Swift runtime to enqueue an
    // otherwise empty actor-isolated deinit during XCTest/app teardown.
    nonisolated deinit {}

    func recordDecision(trigger: SyncTrigger, action: SyncAction, now: Date = Date()) {
        defaults.set(trigger.diagnosticsName, forKey: "\(keyPrefix).lastTrigger")
        defaults.set(action.diagnosticsName, forKey: "\(keyPrefix).lastAction")
        defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).lastDecisionAt")
        if action.containsFullRecovery {
            defaults.set(true, forKey: "\(keyPrefix).lastDecisionContainedFullRecovery")
        }
    }

    func recordSafetyLoopTick(now: Date = Date()) {
        let key = "\(keyPrefix).safetyLoopTickCount"
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
        defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).safetyLoopLastTickAt")
    }

    func updatePhase(_ phase: SyncPhase, outcome: SyncOutcome? = nil, now: Date = Date()) {
        let resolvedPhase = recoveryJournalIsPending && !phase.isAutomaticWorkActive
            ? .recoveryRequired
            : phase
        let isActive = resolvedPhase.isAutomaticWorkActive
        let startedAt = isActive ? (state.startedAt ?? now) : nil
        let lastProgressAt = isActive ? now : state.lastProgressAt
        state = SyncState(
            phase: resolvedPhase,
            progress: state.progress,
            lastVerifiedAt: state.lastVerifiedAt,
            lastOutcome: outcome ?? state.lastOutcome,
            startedAt: startedAt,
            lastProgressAt: lastProgressAt
        )
        defaults.set(resolvedPhase.diagnosticsName, forKey: "\(keyPrefix).phase")
        if let startedAt {
            defaults.set(startedAt.timeIntervalSince1970, forKey: "\(keyPrefix).activeStartedAt")
            defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).lastProgressAt")
        } else {
            defaults.removeObject(forKey: "\(keyPrefix).activeStartedAt")
            defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).lastProgressAt")
        }
    }

    func recordRunResult(
        _ result: SyncAutomaticRunResult,
        preserveRecoveryRequired: Bool = false,
        now: Date = Date()
    ) {
        let isOrdinaryCompletion = !result.verifiedConvergence
            && (result.status == .success || result.status == .noWork)
            && result.blockReason == nil && result.errorCode == nil
        if isOrdinaryCompletion, !preserveRecoveryRequired,
           let receipt = result.continuationReceipt {
            // Subscribers run before the guard and cannot observe an idle
            // candidate computed from authority they have just invalidated.
            objectWillChange.send()
            do {
                try receipt.withValidatedAuthority(defaults: defaults) {
                    guard storedState.phase != .recoveryRequired else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    applyRunResult(result, preserveRecoveryRequired: false, continued: true, now: now)
                    continuedGeneration = receipt
                }
                return
            } catch {
                // The sealed proof is stale, cancelled or locally dirty.
                // Apply exactly the generic fail-closed result policy below.
            }
        }
        objectWillChange.send()
        applyRunResult(result, preserveRecoveryRequired: preserveRecoveryRequired, continued: false, now: now)
        continuedGeneration = nil
    }

    private func applyRunResult(
        _ result: SyncAutomaticRunResult,
        preserveRecoveryRequired: Bool,
        continued: Bool,
        now: Date
    ) {
        // This helper is also called with the lease held. It uses plain
        // storage only: no publisher, computed getter or nested scope capture.
        if storedState.phase == .recoveryRequired, result.status == .noWork { return }

        var phase: SyncPhase
        let outcome: SyncOutcome
        let verifiedAt: Date?

        switch result.status {
        case .success:
            outcome = .succeeded
            if result.verifiedConvergence || continued {
                phase = .idle
                verifiedAt = result.verifiedConvergence ? now : storedState.lastVerifiedAt
            } else {
                phase = .recoveryRequired
                verifiedAt = storedState.lastVerifiedAt
            }
        case .noWork:
            if let reason = result.blockReason {
                phase = .blocked(reason)
                outcome = .blocked(reason)
            } else if result.errorCode != nil {
                phase = .failed
                outcome = .failed
            } else if result.verifiedConvergence || continued {
                phase = .idle
                outcome = .noWork
            } else {
                phase = .recoveryRequired
                outcome = .noWork
            }
            verifiedAt = storedState.lastVerifiedAt
        case .recoveryRequired:
            phase = .recoveryRequired
            outcome = .noWork
            verifiedAt = storedState.lastVerifiedAt
        case .blocked:
            let reason = result.blockReason ?? .accountDecisionRequired
            phase = .blocked(reason)
            outcome = .blocked(reason)
            verifiedAt = storedState.lastVerifiedAt
        case .busy:
            phase = .checking
            outcome = .busy
            verifiedAt = storedState.lastVerifiedAt
        case .failed:
            phase = .failed
            outcome = .failed
            verifiedAt = storedState.lastVerifiedAt
        case .cancelled:
            phase = .idle
            outcome = .cancelled
            verifiedAt = storedState.lastVerifiedAt
        case .scheduledRetry:
            phase = .checking
            outcome = .scheduledRetry
            verifiedAt = storedState.lastVerifiedAt
        }

        if recoveryJournalIsPending {
            // A run cannot clear the durable latch merely by returning
            // success/noWork. The atomic recovery coordinator clears the
            // journal only after checkpoint C, baseline and watermark commit.
            phase = .recoveryRequired
        } else if preserveRecoveryRequired, !result.verifiedConvergence {
            phase = .recoveryRequired
        }

        storedState = SyncState(
            phase: phase,
            progress: nil,
            lastVerifiedAt: verifiedAt,
            lastOutcome: outcome,
            startedAt: nil,
            lastProgressAt: now
        )
        defaults.set(phase.diagnosticsName, forKey: "\(keyPrefix).phase")
        defaults.set(result.status.rawValue, forKey: "\(keyPrefix).lastRunStatus")
        defaults.set(result.didWork, forKey: "\(keyPrefix).lastRunDidWork")
        defaults.set(
            result.verifiedConvergence,
            forKey: "\(keyPrefix).lastRunVerifiedConvergence"
        )
        defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).lastRunCompletedAt")
        if let verifiedAt {
            defaults.set(verifiedAt.timeIntervalSince1970, forKey: "\(keyPrefix).lastVerifiedAt")
        }
        if result.verifiedConvergence {
            defaults.set(
                Self.convergenceProofVersion,
                forKey: "\(keyPrefix).lastVerifiedProofVersion"
            )
        }
        defaults.removeObject(forKey: "\(keyPrefix).activeStartedAt")
        defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).lastProgressAt")
        if let errorCode = result.errorCode {
            defaults.set(errorCode, forKey: "\(keyPrefix).lastRunErrorCode")
        } else {
            defaults.removeObject(forKey: "\(keyPrefix).lastRunErrorCode")
        }
        if let blockReason = result.blockReason {
            defaults.set(blockReason.diagnosticsName, forKey: "\(keyPrefix).lastRunBlockReason")
        } else {
            defaults.removeObject(forKey: "\(keyPrefix).lastRunBlockReason")
        }
    }

    func reconcilePendingRecoveryJournal(now: Date = Date()) {
        guard recoveryJournalIsPending, state.phase != .recoveryRequired else { return }
        updatePhase(.recoveryRequired, now: now)
    }

    func automaticRecoveryAttemptEligibility(
        identity: String,
        now: Date = Date()
    ) -> SyncAutomaticRecoveryAttemptEligibility {
        guard Self.isRedactedIdentity(identity) else { return .exhausted }
        guard defaults.object(forKey: automaticRecoveryAttemptKey) != nil else {
            return .ready
        }
        guard let record = automaticRecoveryAttemptRecord() else {
            // Corrupt retry metadata must not turn into an unbounded relaunch
            // loop. The explicit Review/Retry action can clear it safely.
            return .exhausted
        }
        guard record.identity == identity else { return .ready }
        guard record.attemptCount < 3 else { return .exhausted }
        let remaining = record.nextAllowedAt - now.timeIntervalSince1970
        return remaining > 0 ? .cooldown(remaining) : .ready
    }

    @discardableResult
    func beginAutomaticRecoveryAttempt(
        identity: String,
        now: Date = Date()
    ) -> Int? {
        guard automaticRecoveryAttemptEligibility(identity: identity, now: now) == .ready else {
            return nil
        }
        let prior = automaticRecoveryAttemptRecord()
        let priorCount = prior?.identity == identity ? prior?.attemptCount ?? 0 : 0
        let nextCount = priorCount + 1
        guard nextCount <= 3 else { return nil }
        let delay = min(2 * pow(2, Double(nextCount - 1)), 30)
        let record = SyncAutomaticRecoveryAttemptRecord(
            schemaVersion: SyncAutomaticRecoveryAttemptRecord.schemaVersion,
            identity: identity,
            attemptCount: nextCount,
            nextAllowedAt: now.timeIntervalSince1970 + delay
        )
        guard persistAutomaticRecoveryAttemptRecord(record) else { return nil }
        return nextCount
    }

    func extendAutomaticRecoveryAttemptCooldown(
        identity: String,
        requestedDelay: TimeInterval,
        now: Date = Date()
    ) -> TimeInterval {
        guard let record = automaticRecoveryAttemptRecord(),
              record.identity == identity else {
            return max(0, requestedDelay)
        }
        let target = max(
            record.nextAllowedAt,
            now.timeIntervalSince1970 + min(max(0, requestedDelay), 30)
        )
        let updated = SyncAutomaticRecoveryAttemptRecord(
            schemaVersion: record.schemaVersion,
            identity: record.identity,
            attemptCount: record.attemptCount,
            nextAllowedAt: target
        )
        guard persistAutomaticRecoveryAttemptRecord(updated) else { return 30 }
        return max(0, target - now.timeIntervalSince1970)
    }

    func resetAutomaticRecoveryAttemptBudget() {
        defaults.removeObject(forKey: automaticRecoveryAttemptKey)
    }

    private func automaticRecoveryAttemptRecord() -> SyncAutomaticRecoveryAttemptRecord? {
        guard let data = defaults.data(forKey: automaticRecoveryAttemptKey),
              let record = try? JSONDecoder().decode(
                SyncAutomaticRecoveryAttemptRecord.self,
                from: data
              ),
              record.schemaVersion == SyncAutomaticRecoveryAttemptRecord.schemaVersion,
              Self.isRedactedIdentity(record.identity),
              (1...3).contains(record.attemptCount),
              record.nextAllowedAt.isFinite,
              record.nextAllowedAt > 0 else {
            return nil
        }
        return record
    }

    private func persistAutomaticRecoveryAttemptRecord(
        _ record: SyncAutomaticRecoveryAttemptRecord
    ) -> Bool {
        guard let data = try? JSONEncoder().encode(record) else { return false }
        defaults.set(data, forKey: automaticRecoveryAttemptKey)
        return defaults.data(forKey: automaticRecoveryAttemptKey) == data
    }

    private static func isRedactedIdentity(_ value: String) -> Bool {
        value.count == 64
            && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private static func hydratedState(
        defaults: UserDefaults,
        keyPrefix: String,
        hasPendingRecoveryJournal: Bool,
        now: Date = Date()
    ) -> SyncState {
        let lastVerifiedAt = defaults.integer(forKey: "\(keyPrefix).lastVerifiedProofVersion")
            == convergenceProofVersion
            ? date(defaults, key: "\(keyPrefix).lastVerifiedAt")
            : nil
        let lastProgressAt = date(defaults, key: "\(keyPrefix).lastProgressAt")
        let activeStartedAt = date(defaults, key: "\(keyPrefix).activeStartedAt")
        let storedPhase = phase(from: defaults.string(forKey: "\(keyPrefix).phase"))
        let storedStatus = defaults.string(forKey: "\(keyPrefix).lastRunStatus")
            .flatMap(SyncAutomaticRunStatus.init(rawValue:))
        let blockReason = blockReason(from: defaults.string(forKey: "\(keyPrefix).lastRunBlockReason"))
        let errorCode = defaults.string(forKey: "\(keyPrefix).lastRunErrorCode")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasError = errorCode.map { !$0.isEmpty } ?? false

        var phase = storedPhase ?? phase(for: storedStatus, blockReason: blockReason) ?? .idle
        var outcome = outcome(for: storedStatus, blockReason: blockReason)

        if phase.isAutomaticWorkActive {
            if storedStatus == .scheduledRetry {
                phase = .idle
                outcome = .scheduledRetry
            } else if storedStatus == .busy {
                phase = .idle
                outcome = .busy
            } else if let blockReason {
                phase = .blocked(blockReason)
                outcome = .blocked(blockReason)
            } else {
                phase = .failed
                outcome = .failed
            }
        }

        if hasError, storedStatus == .noWork || storedStatus == .success {
            if let blockReason {
                phase = .blocked(blockReason)
                outcome = .blocked(blockReason)
            } else {
                phase = .failed
                outcome = .failed
            }
        }

        if phase.isAutomaticWorkActive,
           let lastProgressAt,
           now.timeIntervalSince(lastProgressAt) >= 60 {
            if let blockReason {
                phase = .blocked(blockReason)
                outcome = .blocked(blockReason)
            } else {
                phase = .failed
                outcome = .failed
            }
        }

        if hasPendingRecoveryJournal {
            phase = .recoveryRequired
        } else if lastVerifiedAt == nil,
                  blockReason == nil,
                  !hasError,
                  storedStatus == .success || storedStatus == .noWork {
            // Legacy and unverified successful/no-work runs are not evidence of
            // convergence. Relaunch must not turn them into a fresh idle proof.
            phase = .recoveryRequired
        }

        return SyncState(
            phase: phase,
            lastVerifiedAt: lastVerifiedAt,
            lastOutcome: outcome,
            startedAt: phase.isAutomaticWorkActive ? activeStartedAt : nil,
            lastProgressAt: lastProgressAt
        )
    }

    private static func date(_ defaults: UserDefaults, key: String) -> Date? {
        let value = defaults.double(forKey: key)
        guard value > 0 else { return nil }
        return Date(timeIntervalSince1970: value)
    }

    private static func phase(from value: String?) -> SyncPhase? {
        guard let value else { return nil }
        switch value {
        case "idle": return .idle
        case "checking": return .checking
        case "pushing": return .pushing
        case "pullingEvents": return .pullingEvents
        case "reconciling": return .reconciling
        case "recoveryRequired": return .recoveryRequired
        case "failed": return .failed
        default:
            if let reasonValue = value.split(separator: ".").last,
               value.hasPrefix("blocked."),
               let reason = blockReason(from: String(reasonValue)) {
                return .blocked(reason)
            }
            return nil
        }
    }

    private static func phase(
        for status: SyncAutomaticRunStatus?,
        blockReason: SyncBlockReason?
    ) -> SyncPhase? {
        switch status {
        case .success, .noWork, .cancelled:
            return .idle
        case .recoveryRequired:
            return .recoveryRequired
        case .blocked:
            return .blocked(blockReason ?? .accountDecisionRequired)
        case .busy, .scheduledRetry:
            return .idle
        case .failed:
            return .failed
        case .none:
            return nil
        }
    }

    private static func outcome(
        for status: SyncAutomaticRunStatus?,
        blockReason: SyncBlockReason?
    ) -> SyncOutcome? {
        switch status {
        case .success:
            return .succeeded
        case .noWork:
            return .noWork
        case .recoveryRequired:
            return .noWork
        case .blocked:
            return .blocked(blockReason ?? .accountDecisionRequired)
        case .busy:
            return .busy
        case .failed:
            return .failed
        case .cancelled:
            return .cancelled
        case .scheduledRetry:
            return .scheduledRetry
        case .none:
            return nil
        }
    }

    private static func blockReason(from value: String?) -> SyncBlockReason? {
        switch value {
        case "authRequired": return .authRequired
        case "networkUnavailable": return .networkUnavailable
        case "accountDecisionRequired": return .accountDecisionRequired
        case "localStateUnavailable": return .localStateUnavailable
        case "deviceNotActive": return .deviceNotActive
        default: return nil
        }
    }
}

private extension SyncTrigger {
    var diagnosticsName: String {
        switch self {
        case .appForeground: "appForeground"
        case .networkAvailable: "networkAvailable"
        case .authChanged: "authChanged"
        case .localMutation: "localMutation"
        case .remoteSyncEvent: "remoteSyncEvent"
        case .manualRefresh: "manualRefresh"
        case .harness: "harness"
        case .recoveryRequested: "recoveryRequested"
        case .bootstrapRequested: "bootstrapRequested"
        }
    }
}

private extension SyncAction {
    var diagnosticsName: String {
        switch self {
        case .noOp: "noOp"
        case .pushPending: "pushPending"
        case .drainEvents: "drainEvents"
        case .lightReconcile: "lightReconcile"
        case .bootstrap: "bootstrap"
        case .fullRecovery: "fullRecovery"
        case .requestRecovery: "requestRecovery"
        case .retryAfterBusy: "retryAfterBusy"
        case .blocked(let reason): "blocked.\(reason.diagnosticsName)"
        case .sequence(let actions): "sequence.\(actions.map(\.diagnosticsName).joined(separator: "+"))"
        }
    }
}

private extension SyncBlockReason {
    var diagnosticsName: String {
        switch self {
        case .authRequired: "authRequired"
        case .networkUnavailable: "networkUnavailable"
        case .accountDecisionRequired: "accountDecisionRequired"
        case .localStateUnavailable: "localStateUnavailable"
        case .deviceNotActive: "deviceNotActive"
        }
    }
}

private extension SyncPhase {
    var diagnosticsName: String {
        switch self {
        case .idle: "idle"
        case .checking: "checking"
        case .pushing: "pushing"
        case .pullingEvents: "pullingEvents"
        case .reconciling: "reconciling"
        case .recoveryRequired: "recoveryRequired"
        case .blocked(let reason): "blocked.\(reason.diagnosticsName)"
        case .failed: "failed"
        }
    }
}
