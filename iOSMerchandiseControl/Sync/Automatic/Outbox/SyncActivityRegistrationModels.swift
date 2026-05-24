import Foundation

nonisolated enum SyncActivityRegistrationStatus: Equatable, Sendable {
    case success
    case empty
    case partialRetryable
    case authRequired
    case retryableFailure
    case blocked
    case cancelled
}

nonisolated struct SyncActivityRegistrationSnapshot: Equatable, Sendable {
    var readyToRegister: Int
    var waiting: Int
    var notRegisterable: Int

    init(readyToRegister: Int, waiting: Int, notRegisterable: Int) {
        self.readyToRegister = readyToRegister
        self.waiting = waiting
        self.notRegisterable = notRegisterable
    }

    var hasAnyActivity: Bool {
        readyToRegister > 0 || waiting > 0 || notRegisterable > 0
    }
}

nonisolated struct SyncActivityRegistrationSummary: Equatable, Sendable {
    var registered: Int
    var waiting: Int
    var notRegisterable: Int

    init(registered: Int, waiting: Int, notRegisterable: Int) {
        self.registered = registered
        self.waiting = waiting
        self.notRegisterable = notRegisterable
    }
}

nonisolated struct SyncActivityRegistrationResult: Equatable, Sendable {
    var status: SyncActivityRegistrationStatus
    var summary: SyncActivityRegistrationSummary

    init(status: SyncActivityRegistrationStatus, summary: SyncActivityRegistrationSummary) {
        self.status = status
        self.summary = summary
    }
}

protocol SyncActivityRegistrationProviding: AnyObject {
    func loadSyncActivityRegistrationSnapshot(ownerUserID: UUID) async throws -> SyncActivityRegistrationSnapshot
    func registerSyncActivities(ownerUserID: UUID) async throws -> SyncActivityRegistrationResult
}
