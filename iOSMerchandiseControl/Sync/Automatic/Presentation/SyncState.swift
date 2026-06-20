import Foundation

enum SyncPhase: Equatable {
    case idle
    case checking
    case pushing
    case pullingEvents
    case reconciling
    case recoveryRequired
    case blocked(SyncBlockReason)
    case failed
}

struct SyncProgress: Equatable {
    var current: Int
    var total: Int

    var isVisible: Bool {
        total > 0
    }
}

struct SyncState: Equatable {
    var phase: SyncPhase
    var progress: SyncProgress?
    var lastVerifiedAt: Date?
    var lastOutcome: SyncOutcome?
    var startedAt: Date?
    var lastProgressAt: Date?

    init(
        phase: SyncPhase = .idle,
        progress: SyncProgress? = nil,
        lastVerifiedAt: Date? = nil,
        lastOutcome: SyncOutcome? = nil,
        startedAt: Date? = nil,
        lastProgressAt: Date? = nil
    ) {
        self.phase = phase
        self.progress = progress
        self.lastVerifiedAt = lastVerifiedAt
        self.lastOutcome = lastOutcome
        self.startedAt = startedAt
        self.lastProgressAt = lastProgressAt
    }

    var isProgressVisible: Bool {
        progress?.isVisible == true
    }
}

enum SyncOutcome: Equatable {
    case succeeded
    case noWork
    case failed
    case blocked(SyncBlockReason)
    case busy
    case cancelled
    case scheduledRetry
}
