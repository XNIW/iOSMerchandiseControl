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
        state = Self.hydratedState(defaults: defaults, keyPrefix: keyPrefix)
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

    func updatePhase(_ phase: SyncPhase, outcome: SyncOutcome? = nil, now: Date = Date()) {
        let isActive = phase.isAutomaticWorkActive
        let startedAt = isActive ? (state.startedAt ?? now) : nil
        let lastProgressAt = isActive ? now : state.lastProgressAt
        state = SyncState(
            phase: phase,
            progress: state.progress,
            lastVerifiedAt: state.lastVerifiedAt,
            lastOutcome: outcome ?? state.lastOutcome,
            startedAt: startedAt,
            lastProgressAt: lastProgressAt
        )
        defaults.set(phase.diagnosticsName, forKey: "\(keyPrefix).phase")
        if let startedAt {
            defaults.set(startedAt.timeIntervalSince1970, forKey: "\(keyPrefix).activeStartedAt")
            defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).lastProgressAt")
        } else {
            defaults.removeObject(forKey: "\(keyPrefix).activeStartedAt")
            defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).lastProgressAt")
        }
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
            if let reason = result.blockReason {
                phase = .blocked(reason)
                outcome = .blocked(reason)
            } else if result.errorCode != nil {
                phase = .failed
                outcome = .failed
            } else {
                phase = .idle
                outcome = .noWork
            }
            verifiedAt = state.lastVerifiedAt
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
            lastOutcome: outcome,
            startedAt: nil,
            lastProgressAt: now
        )
        defaults.set(phase.diagnosticsName, forKey: "\(keyPrefix).phase")
        defaults.set(result.status.rawValue, forKey: "\(keyPrefix).lastRunStatus")
        defaults.set(result.didWork, forKey: "\(keyPrefix).lastRunDidWork")
        defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).lastRunCompletedAt")
        if let verifiedAt {
            defaults.set(verifiedAt.timeIntervalSince1970, forKey: "\(keyPrefix).lastVerifiedAt")
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

    private static func hydratedState(
        defaults: UserDefaults,
        keyPrefix: String,
        now: Date = Date()
    ) -> SyncState {
        let lastVerifiedAt = date(defaults, key: "\(keyPrefix).lastVerifiedAt")
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
