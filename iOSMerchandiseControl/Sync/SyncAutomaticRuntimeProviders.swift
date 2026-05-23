import Foundation

nonisolated enum SyncAutomaticTriggerSource: String, Sendable, Equatable {
    case releaseCard
    case rootForeground
    case networkReconnect
    case localMutation
    case remoteSyncEvent
}

nonisolated enum SyncHistorySessionMode: Sendable, Equatable {
    case fullReconciliation
    case incremental
}

nonisolated enum SyncActivityRegistrationStatus: Equatable, Sendable {
    case success
    case empty
    case partialRetryable
    case authRequired
    case retryableFailure
    case blocked
    case cancelled

    init(_ legacy: SupabaseManualSyncActivityRegistrationStatus) {
        switch legacy {
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

nonisolated struct SyncActivityRegistrationSnapshot: Equatable, Sendable {
    var readyToRegister: Int
    var waiting: Int
    var notRegisterable: Int

    init(readyToRegister: Int, waiting: Int, notRegisterable: Int) {
        self.readyToRegister = readyToRegister
        self.waiting = waiting
        self.notRegisterable = notRegisterable
    }

    init(_ legacy: SupabaseManualSyncActivityRegistrationSnapshot) {
        self.init(
            readyToRegister: legacy.readyToRegister,
            waiting: legacy.waiting,
            notRegisterable: legacy.notRegisterable
        )
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

    init(_ legacy: SupabaseManualSyncActivityRegistrationSummary) {
        self.init(
            registered: legacy.registered,
            waiting: legacy.waiting,
            notRegisterable: legacy.notRegisterable
        )
    }
}

nonisolated struct SyncActivityRegistrationResult: Equatable, Sendable {
    var status: SyncActivityRegistrationStatus
    var summary: SyncActivityRegistrationSummary

    init(status: SyncActivityRegistrationStatus, summary: SyncActivityRegistrationSummary) {
        self.status = status
        self.summary = summary
    }

    init(_ legacy: SupabaseManualSyncActivityRegistrationResult) {
        self.init(
            status: SyncActivityRegistrationStatus(legacy.status),
            summary: SyncActivityRegistrationSummary(legacy.summary)
        )
    }
}

nonisolated struct SyncHistorySessionSummary: Equatable, Sendable {
    var uploaded: Int = 0
    var inserted: Int = 0
    var updated: Int = 0
    var skippedClean: Int = 0
    var skippedDirtyLocal: Int = 0
    var skippedOversized: Int = 0

    var totalChanged: Int {
        uploaded + inserted + updated
    }

    var hasWarnings: Bool {
        skippedDirtyLocal > 0 || skippedOversized > 0
    }

    var legacySummary: SupabaseManualSyncHistorySessionSummary {
        SupabaseManualSyncHistorySessionSummary(
            uploaded: uploaded,
            inserted: inserted,
            updated: updated,
            skippedClean: skippedClean,
            skippedDirtyLocal: skippedDirtyLocal,
            skippedOversized: skippedOversized
        )
    }
}

@MainActor
protocol SyncCatalogPushProviding: AnyObject {
    func makePushPlan(ownerUserID: UUID) async throws -> ManualPushPlan
    func execute(plan: ManualPushPlan, ownerUserID: UUID) async -> SupabaseManualPushResult
}

@MainActor
protocol SyncProductPriceSyncProviding: AnyObject {
    func makeApplyPlan(ownerUserID: UUID) async throws -> ProductPriceApplyPlan
    func apply(plan: ProductPriceApplyPlan, ownerUserID: UUID) async throws -> ProductPriceApplyResult
    func apply(
        plan: ProductPriceApplyPlan,
        ownerUserID: UUID,
        onProgress: @escaping @MainActor @Sendable (ProductPricePagedApplyProgress) -> Void
    ) async throws -> ProductPriceApplyResult
    func makePushPlan(ownerUserID: UUID) async throws -> ProductPricePushDryRunPlan
    func push(plan: ProductPricePushDryRunPlan, ownerUserID: UUID) async throws -> ProductPriceManualPushResult
}

extension SyncProductPriceSyncProviding {
    func apply(
        plan: ProductPriceApplyPlan,
        ownerUserID: UUID,
        onProgress: @escaping @MainActor @Sendable (ProductPricePagedApplyProgress) -> Void
    ) async throws -> ProductPriceApplyResult {
        try await apply(plan: plan, ownerUserID: ownerUserID)
    }
}

@MainActor
protocol SyncActivityRegistrationProviding: AnyObject {
    func loadSyncActivityRegistrationSnapshot(ownerUserID: UUID) async throws -> SyncActivityRegistrationSnapshot
    func registerSyncActivities(ownerUserID: UUID) async throws -> SyncActivityRegistrationResult
}

@MainActor
protocol SyncHistorySessionPushProviding: AnyObject {
    func syncHistorySessions(
        ownerUserID: UUID,
        mode: SyncHistorySessionMode,
        onProgress: @escaping @MainActor @Sendable (HistorySessionSyncProgress) -> Void
    ) async throws -> SyncHistorySessionSummary
}

@MainActor
protocol SyncIncrementalPullProviding: AnyObject {
    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SupabaseSyncEventIncrementalApplySummary
}
