import Foundation

nonisolated enum SyncAutomaticRunStatus: String, CaseIterable, Equatable, Sendable, Hashable {
    case success
    case noWork
    case recoveryRequired
    case blocked
    case busy
    case failed
    case cancelled
    case scheduledRetry
}

nonisolated struct SyncAutomaticRunResult: Equatable, Sendable {
    var status: SyncAutomaticRunStatus
    var didWork: Bool
    var blockReason: SyncBlockReason?
    var errorCode: String?
    var scheduledRetryAfter: TimeInterval?
    var verifiedConvergence: Bool

    init(
        status: SyncAutomaticRunStatus,
        didWork: Bool,
        blockReason: SyncBlockReason? = nil,
        errorCode: String? = nil,
        scheduledRetryAfter: TimeInterval? = nil,
        verifiedConvergence: Bool = false
    ) {
        self.status = status
        self.didWork = didWork
        self.blockReason = blockReason
        self.errorCode = errorCode
        self.scheduledRetryAfter = scheduledRetryAfter
        self.verifiedConvergence = verifiedConvergence
    }

    static func success(
        didWork: Bool,
        verifiedConvergence: Bool = false
    ) -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(
            status: .success,
            didWork: didWork,
            verifiedConvergence: verifiedConvergence
        )
    }

    static func noWork(
        verifiedConvergence: Bool = false
    ) -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(
            status: .noWork,
            didWork: false,
            verifiedConvergence: verifiedConvergence
        )
    }

    static func recoveryRequired(didWork: Bool = false) -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(status: .recoveryRequired, didWork: didWork)
    }

    static func blocked(_ reason: SyncBlockReason) -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(status: .blocked, didWork: false, blockReason: reason)
    }

    static func busy() -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(status: .busy, didWork: false)
    }

    static func failed(errorCode: String?) -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(status: .failed, didWork: false, errorCode: errorCode)
    }

    static func cancelled() -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(status: .cancelled, didWork: false)
    }

    static func scheduledRetry(after delay: TimeInterval? = nil) -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(status: .scheduledRetry, didWork: false, scheduledRetryAfter: delay)
    }
}
