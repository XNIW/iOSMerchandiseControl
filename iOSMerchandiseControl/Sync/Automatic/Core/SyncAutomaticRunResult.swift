import Foundation

nonisolated enum SyncAutomaticRunStatus: String, CaseIterable, Equatable, Sendable, Hashable {
    case success
    case noWork
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

    init(
        status: SyncAutomaticRunStatus,
        didWork: Bool,
        blockReason: SyncBlockReason? = nil,
        errorCode: String? = nil,
        scheduledRetryAfter: TimeInterval? = nil
    ) {
        self.status = status
        self.didWork = didWork
        self.blockReason = blockReason
        self.errorCode = errorCode
        self.scheduledRetryAfter = scheduledRetryAfter
    }

    static func success(didWork: Bool) -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(status: .success, didWork: didWork)
    }

    static func noWork() -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(status: .noWork, didWork: false)
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
