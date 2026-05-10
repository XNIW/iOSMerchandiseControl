import Foundation

nonisolated enum SupabaseManualSyncLifecycleRunKind: String, Equatable, Sendable {
    case previewReadOnly
    case pullPreview
    case pullApplyLocal
    case pushCatalog
    case pushProductPrice
    case pushAggregated
    case drainOutbox

    var isMutating: Bool {
        switch self {
        case .previewReadOnly, .pullPreview:
            return false
        case .pullApplyLocal, .pushCatalog, .pushProductPrice, .pushAggregated, .drainOutbox:
            return true
        }
    }
}

nonisolated enum SupabaseManualSyncLifecycleRunSource: String, Equatable, Sendable {
    case rootForeground
    case optionsCard
    case releaseSheet
}

nonisolated enum SupabaseManualSyncLifecycleProcessState: String, Equatable, Sendable {
    case idle
    case running
    case cancelling
    case interrupted
    case readyToRetry
    case blocked
    case completedVerified
}

nonisolated enum SupabaseManualSyncLifecycleBlockReason: String, Equatable, Sendable {
    case authMissing
    case ownerMissing
    case networkUnavailable
    case unsafeAppContext
    case appNotActive
    case readOnlyIgnoredForMutatingRun
    case mutatingRunAlreadyActive
    case runAlreadyActive
    case interruptedMutationNeedsReview
}

nonisolated enum SupabaseManualSyncLifecycleInterruptReason: String, Equatable, Sendable {
    case userCancelled
    case appBackgrounded
    case timeBudgetExceeded
    case remoteWriteUnverified
    case cancelledBeforeWrite
}

nonisolated struct SupabaseManualSyncLifecycleRunSnapshot: Equatable, Sendable {
    var state: SupabaseManualSyncLifecycleProcessState
    var runID: UUID?
    var kind: SupabaseManualSyncLifecycleRunKind?
    var source: SupabaseManualSyncLifecycleRunSource?
    var startedAt: Date?
    var updatedAt: Date?
    var blockReason: SupabaseManualSyncLifecycleBlockReason?
    var interruptReason: SupabaseManualSyncLifecycleInterruptReason?

    static let idle = SupabaseManualSyncLifecycleRunSnapshot(
        state: .idle,
        runID: nil,
        kind: nil,
        source: nil,
        startedAt: nil,
        updatedAt: nil,
        blockReason: nil,
        interruptReason: nil
    )

    var isRunning: Bool {
        state == .running || state == .cancelling
    }

    var isMutating: Bool {
        kind?.isMutating == true
    }

    var hasInterruptedMutationPriority: Bool {
        isMutating && (state == .interrupted || state == .readyToRetry || state == .blocked)
    }
}

nonisolated enum SupabaseManualSyncLifecyclePreflightResult: Equatable, Sendable {
    case allowed
    case blocked(SupabaseManualSyncLifecycleBlockReason)
}

@MainActor
protocol SupabaseManualSyncLifecyclePreflightProviding: AnyObject {
    func evaluate(
        kind: SupabaseManualSyncLifecycleRunKind,
        source: SupabaseManualSyncLifecycleRunSource
    ) -> SupabaseManualSyncLifecyclePreflightResult
}

@MainActor
final class SupabaseManualSyncLifecyclePreflight: SupabaseManualSyncLifecyclePreflightProviding {
    var isSignedIn: @MainActor () -> Bool
    var ownerUserID: @MainActor () -> UUID?
    var isNetworkAvailable: @MainActor () -> Bool
    var isAppContextSafe: @MainActor () -> Bool
    var isAppLifecycleCompatible: @MainActor () -> Bool

    init(
        isSignedIn: @escaping @MainActor () -> Bool,
        ownerUserID: @escaping @MainActor () -> UUID?,
        isNetworkAvailable: @escaping @MainActor () -> Bool = { true },
        isAppContextSafe: @escaping @MainActor () -> Bool = { true },
        isAppLifecycleCompatible: @escaping @MainActor () -> Bool = { true }
    ) {
        self.isSignedIn = isSignedIn
        self.ownerUserID = ownerUserID
        self.isNetworkAvailable = isNetworkAvailable
        self.isAppContextSafe = isAppContextSafe
        self.isAppLifecycleCompatible = isAppLifecycleCompatible
    }

    func evaluate(
        kind: SupabaseManualSyncLifecycleRunKind,
        source: SupabaseManualSyncLifecycleRunSource
    ) -> SupabaseManualSyncLifecyclePreflightResult {
        _ = source
        guard isSignedIn() else {
            return .blocked(.authMissing)
        }
        guard ownerUserID() != nil else {
            return .blocked(.ownerMissing)
        }
        guard isAppLifecycleCompatible() else {
            return .blocked(.appNotActive)
        }
        guard isAppContextSafe() else {
            return .blocked(.unsafeAppContext)
        }
        if kind.isMutating, !isNetworkAvailable() {
            return .blocked(.networkUnavailable)
        }
        return .allowed
    }
}

nonisolated enum SupabaseManualSyncLifecycleRunGateDecision: Equatable, Sendable {
    case started(SupabaseManualSyncLifecycleRunSnapshot)
    case ignored(SupabaseManualSyncLifecycleBlockReason, SupabaseManualSyncLifecycleRunSnapshot)
    case blocked(SupabaseManualSyncLifecycleBlockReason, SupabaseManualSyncLifecycleRunSnapshot)
}

@MainActor
final class SupabaseManualSyncLifecycleRunGate {
    private let now: () -> Date
    private let preflight: any SupabaseManualSyncLifecyclePreflightProviding
    private let timeBudget: TimeInterval
    private(set) var snapshot: SupabaseManualSyncLifecycleRunSnapshot = .idle

    init(
        now: @escaping () -> Date = Date.init,
        preflight: any SupabaseManualSyncLifecyclePreflightProviding,
        timeBudget: TimeInterval = 45
    ) {
        self.now = now
        self.preflight = preflight
        self.timeBudget = max(1, timeBudget)
    }

    func begin(
        kind: SupabaseManualSyncLifecycleRunKind,
        source: SupabaseManualSyncLifecycleRunSource,
        runID: UUID = UUID()
    ) -> SupabaseManualSyncLifecycleRunGateDecision {
        let timestamp = now()
        _ = expireBudgetIfNeeded(at: timestamp)

        if snapshot.hasInterruptedMutationPriority, !kind.isMutating, source == .rootForeground {
            return .ignored(.interruptedMutationNeedsReview, snapshot)
        }

        if snapshot.isRunning {
            let reason: SupabaseManualSyncLifecycleBlockReason
            if snapshot.isMutating || kind.isMutating {
                reason = .mutatingRunAlreadyActive
            } else {
                reason = .runAlreadyActive
            }
            return .ignored(reason, snapshot)
        }

        switch preflight.evaluate(kind: kind, source: source) {
        case .allowed:
            snapshot = SupabaseManualSyncLifecycleRunSnapshot(
                state: .running,
                runID: runID,
                kind: kind,
                source: source,
                startedAt: timestamp,
                updatedAt: timestamp,
                blockReason: nil,
                interruptReason: nil
            )
            return .started(snapshot)
        case .blocked(let reason):
            snapshot = SupabaseManualSyncLifecycleRunSnapshot(
                state: .blocked,
                runID: runID,
                kind: kind,
                source: source,
                startedAt: nil,
                updatedAt: timestamp,
                blockReason: reason,
                interruptReason: nil
            )
            return .blocked(reason, snapshot)
        }
    }

    func markCancelling(runID: UUID, reason: SupabaseManualSyncLifecycleInterruptReason) {
        guard snapshot.runID == runID, snapshot.state == .running else { return }
        snapshot.state = .cancelling
        snapshot.interruptReason = reason
        snapshot.updatedAt = now()
    }

    @discardableResult
    func markInterrupted(
        runID: UUID,
        reason: SupabaseManualSyncLifecycleInterruptReason
    ) -> SupabaseManualSyncLifecycleRunSnapshot {
        guard snapshot.runID == runID || snapshot.runID == nil else { return snapshot }
        let state: SupabaseManualSyncLifecycleProcessState = reason == .remoteWriteUnverified ? .interrupted : .readyToRetry
        snapshot.state = state
        snapshot.interruptReason = reason
        snapshot.blockReason = nil
        snapshot.updatedAt = now()
        return snapshot
    }

    @discardableResult
    func markBlocked(
        runID: UUID?,
        kind: SupabaseManualSyncLifecycleRunKind,
        source: SupabaseManualSyncLifecycleRunSource,
        reason: SupabaseManualSyncLifecycleBlockReason
    ) -> SupabaseManualSyncLifecycleRunSnapshot {
        let timestamp = now()
        snapshot = SupabaseManualSyncLifecycleRunSnapshot(
            state: .blocked,
            runID: runID,
            kind: kind,
            source: source,
            startedAt: nil,
            updatedAt: timestamp,
            blockReason: reason,
            interruptReason: nil
        )
        return snapshot
    }

    @discardableResult
    func markCompletedVerified(runID: UUID) -> SupabaseManualSyncLifecycleRunSnapshot {
        guard snapshot.runID == runID,
              snapshot.state == .running || snapshot.state == .cancelling else {
            return snapshot
        }
        snapshot.state = .completedVerified
        snapshot.blockReason = nil
        snapshot.interruptReason = nil
        snapshot.updatedAt = now()
        return snapshot
    }

    @discardableResult
    func expireBudgetIfNeeded() -> SupabaseManualSyncLifecycleRunSnapshot {
        expireBudgetIfNeeded(at: now())
    }

    @discardableResult
    private func expireBudgetIfNeeded(at timestamp: Date) -> SupabaseManualSyncLifecycleRunSnapshot {
        guard snapshot.state == .running,
              let startedAt = snapshot.startedAt,
              timestamp.timeIntervalSince(startedAt) >= timeBudget else {
            return snapshot
        }
        snapshot.state = .readyToRetry
        snapshot.interruptReason = .timeBudgetExceeded
        snapshot.updatedAt = timestamp
        return snapshot
    }
}
