import Foundation
import Combine

@MainActor
final class SyncStateStore: ObservableObject {
    @Published private(set) var state = SyncState()
    private let defaults: UserDefaults
    private let keyPrefix: String

    init(defaults: UserDefaults = .standard, keyPrefix: String = "sync.runtime.orchestrator") {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

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

    func updatePhase(_ phase: SyncPhase, outcome: SyncOutcome? = nil) {
        state = SyncState(
            phase: phase,
            progress: state.progress,
            lastVerifiedAt: state.lastVerifiedAt,
            lastOutcome: outcome ?? state.lastOutcome
        )
    }

    func recordRunResult(_ result: SyncAutomaticRunResult, now: Date = Date()) {
        let phase: SyncPhase
        let outcome: SyncOutcome
        let verifiedAt: Date?

        switch result.status {
        case .success:
            phase = .idle
            outcome = .succeeded
            verifiedAt = now
        case .noWork:
            phase = .idle
            outcome = .noWork
            verifiedAt = now
        case .blocked:
            let reason = result.blockReason ?? .accountDecisionRequired
            phase = .blocked(reason)
            outcome = .blocked(reason)
            verifiedAt = state.lastVerifiedAt
        case .busy:
            phase = .checking
            outcome = .busy
            verifiedAt = state.lastVerifiedAt
        case .failed:
            phase = .failed
            outcome = .failed
            verifiedAt = state.lastVerifiedAt
        case .cancelled:
            phase = .idle
            outcome = .cancelled
            verifiedAt = state.lastVerifiedAt
        case .scheduledRetry:
            phase = .checking
            outcome = .scheduledRetry
            verifiedAt = state.lastVerifiedAt
        }

        state = SyncState(
            phase: phase,
            progress: nil,
            lastVerifiedAt: verifiedAt,
            lastOutcome: outcome
        )
        defaults.set(result.status.rawValue, forKey: "\(keyPrefix).lastRunStatus")
        defaults.set(result.didWork, forKey: "\(keyPrefix).lastRunDidWork")
        defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).lastRunCompletedAt")
        if let errorCode = result.errorCode {
            defaults.set(errorCode, forKey: "\(keyPrefix).lastRunErrorCode")
        }
        if let blockReason = result.blockReason {
            defaults.set(blockReason.diagnosticsName, forKey: "\(keyPrefix).lastRunBlockReason")
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
