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

nonisolated struct SyncCatalogPushPlan: Equatable, Sendable {
    var ownerUserID: UUID
    var pendingChangeCount: Int
    var generatedAt: Date
    var idempotencyKey: String
    var blockers: [String]

    init(
        ownerUserID: UUID,
        pendingChangeCount: Int,
        generatedAt: Date = Date(),
        idempotencyKey: String = UUID().uuidString.lowercased(),
        blockers: [String] = []
    ) {
        self.ownerUserID = ownerUserID
        self.pendingChangeCount = max(0, pendingChangeCount)
        self.generatedAt = generatedAt
        self.idempotencyKey = idempotencyKey
        self.blockers = blockers
    }

    var hasWork: Bool {
        pendingChangeCount > 0 && blockers.isEmpty
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
}

nonisolated struct SyncHistorySessionPushPlan: Equatable, Sendable {
    var ownerUserID: UUID
    var pendingChangeCount: Int
    var generatedAt: Date
    var idempotencyKey: String

    init(
        ownerUserID: UUID,
        pendingChangeCount: Int,
        generatedAt: Date = Date(),
        idempotencyKey: String = UUID().uuidString.lowercased()
    ) {
        self.ownerUserID = ownerUserID
        self.pendingChangeCount = max(0, pendingChangeCount)
        self.generatedAt = generatedAt
        self.idempotencyKey = idempotencyKey
    }
}

nonisolated struct SyncHistorySessionPushResult: Equatable, Sendable {
    var plan: SyncHistorySessionPushPlan?
    var summary: SyncHistorySessionSummary

    init(plan: SyncHistorySessionPushPlan? = nil, summary: SyncHistorySessionSummary = SyncHistorySessionSummary()) {
        self.plan = plan
        self.summary = summary
    }

    var totalChanged: Int {
        summary.totalChanged
    }
}

nonisolated struct SyncCatalogPushResult: Equatable, Sendable {
    var plan: SyncCatalogPushPlan? = nil
    var supplierCreates: Int = 0
    var supplierUpdates: Int = 0
    var supplierLinks: Int = 0
    var categoryCreates: Int = 0
    var categoryUpdates: Int = 0
    var categoryLinks: Int = 0
    var productCreates: Int = 0
    var productUpdates: Int = 0
    var productLinks: Int = 0

    var totalChanged: Int {
        supplierCreates + supplierUpdates + supplierLinks
            + categoryCreates + categoryUpdates + categoryLinks
            + productCreates + productUpdates + productLinks
    }
}

nonisolated struct SyncProductPricePushPlan: Equatable, Sendable {
    var ownerUserID: UUID
    var pendingChangeCount: Int
    var generatedAt: Date
    var idempotencyKey: String
    var blockers: [String]

    init(
        ownerUserID: UUID,
        pendingChangeCount: Int,
        generatedAt: Date = Date(),
        idempotencyKey: String = UUID().uuidString.lowercased(),
        blockers: [String] = []
    ) {
        self.ownerUserID = ownerUserID
        self.pendingChangeCount = max(0, pendingChangeCount)
        self.generatedAt = generatedAt
        self.idempotencyKey = idempotencyKey
        self.blockers = blockers
    }

    var hasWork: Bool {
        pendingChangeCount > 0 && blockers.isEmpty
    }
}

nonisolated struct SyncProductPricePushResult: Equatable, Sendable {
    var plan: SyncProductPricePushPlan? = nil
    var insertedCount: Int = 0
    var orphanedCount: Int = 0
    var tombstonedCount: Int = 0
}

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

nonisolated struct SyncIncrementalPullSummary: Sendable, Equatable {
    var syncType: RuntimeSyncExecutionType
    var eventsFetched: Int = 0
    var eventsProcessed: Int = 0
    var watermarkBefore: Int64 = 0
    var watermarkAfter: Int64 = 0
    var targetedSuppliersFetched: Int = 0
    var targetedCategoriesFetched: Int = 0
    var targetedProductsFetched: Int = 0
    var targetedProductPricesFetched: Int = 0
    var targetedHistoryFetched: Int = 0
    var productsInserted: Int = 0
    var productsUpdated: Int = 0
    var productsTombstoned: Int = 0
    var suppliersCreated: Int = 0
    var categoriesCreated: Int = 0
    var productPricesInserted: Int = 0
    var productPriceIdentityLinked: Int = 0
    var productPricesMissingRemotePruned: Int = 0
    var historyInserted: Int = 0
    var historyUpdated: Int = 0
    var historyMissingRemoteTombstoned: Int = 0
    var suppliersMissingRemoteTombstoned: Int = 0
    var categoriesMissingRemoteTombstoned: Int = 0
    var requiresFullRecoveryReason: String?
    var eventPageFetchMs: Int = 0
    var catalogFetchMs: Int = 0
    var catalogApplyMs: Int = 0
    var productPriceFetchMs: Int = 0
    var productPriceApplyMs: Int = 0
    var historyFetchMs: Int = 0
    var historyApplyMs: Int = 0
    var totalElapsedMs: Int = 0

    static func noWork(watermark: Int64) -> Self {
        SyncIncrementalPullSummary(
            syncType: .checkpointIncremental,
            watermarkBefore: watermark,
            watermarkAfter: watermark
        )
    }

    var requiresFullRecovery: Bool {
        requiresFullRecoveryReason != nil
    }

    var totalApplied: Int {
        productsInserted
            + productsUpdated
            + productsTombstoned
            + suppliersCreated
            + categoriesCreated
            + productPricesInserted
            + productPriceIdentityLinked
            + productPricesMissingRemotePruned
            + historyInserted
            + historyUpdated
            + historyMissingRemoteTombstoned
            + suppliersMissingRemoteTombstoned
            + categoriesMissingRemoteTombstoned
    }
}

protocol SyncCatalogPushProviding: AnyObject {
    func pushPendingCatalog(ownerUserID: UUID) async throws -> SyncCatalogPushResult
}

protocol SyncProductPriceSyncProviding: AnyObject {
    func pushPendingProductPrices(ownerUserID: UUID) async throws -> SyncProductPricePushResult
}

protocol SyncActivityRegistrationProviding: AnyObject {
    func loadSyncActivityRegistrationSnapshot(ownerUserID: UUID) async throws -> SyncActivityRegistrationSnapshot
    func registerSyncActivities(ownerUserID: UUID) async throws -> SyncActivityRegistrationResult
}

protocol SyncHistorySessionPushProviding: AnyObject {
    func syncHistorySessions(
        ownerUserID: UUID,
        mode: SyncHistorySessionMode,
        onProgress: @escaping @MainActor @Sendable (HistorySessionSyncProgress) -> Void
    ) async throws -> SyncHistorySessionSummary
}

protocol SyncIncrementalPullProviding: AnyObject {
    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SyncIncrementalPullSummary
}
