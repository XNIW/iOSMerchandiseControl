import Combine
import Foundation
import SwiftData

// MARK: - Presentation

nonisolated enum SupabaseManualSyncUserPresentationKind: Equatable, Sendable {
    case idleReady
    case running
    case successFullyUpToDate
    case partialSync
    case blockedNeedsSignIn
    case blockedNeedsCloudRealignment
    case connectivityIssue
    case cancelledRun
    case technicalFollowUpNeeded
    case auxiliaryBusyConcurrent
    case auxiliaryModeUnavailable
    case localApplyCompleted
    case localApplyFailed
    case catalogPushReady
    case catalogPushNoChanges
    case catalogPushBlocked
    case catalogPushFailed
    case catalogPushStale
    case catalogPushSending
    case catalogPushSucceeded
    case catalogPushPartiallySucceeded
    case activityRegistrationReady
    case activityRegistrationSucceeded
    case activityRegistrationEmpty
    case activityRegistrationPartiallySucceeded
    case activityRegistrationAuthRequired
    case activityRegistrationRetryableFailure
    case activityRegistrationBlocked
    case activityRegistrationCancelled
}

nonisolated struct SupabaseManualSyncCapabilitySet: Equatable, Sendable {
    var supportsRemoteCloudCheck: Bool
    var supportsForegroundCloudCheck: Bool
    var supportsGuidedManualSync: Bool
    var supportsCatalogPush: Bool
    var supportsProductPriceSync: Bool
    var supportsActivityRegistration: Bool

    init(
        supportsRemoteCloudCheck: Bool,
        supportsForegroundCloudCheck: Bool? = nil,
        supportsGuidedManualSync: Bool,
        supportsCatalogPush: Bool = false,
        supportsProductPriceSync: Bool = false,
        supportsActivityRegistration: Bool = false
    ) {
        self.supportsRemoteCloudCheck = supportsRemoteCloudCheck
        self.supportsForegroundCloudCheck = supportsForegroundCloudCheck ?? false
        self.supportsGuidedManualSync = supportsGuidedManualSync
        self.supportsCatalogPush = supportsCatalogPush
        self.supportsProductPriceSync = supportsProductPriceSync
        self.supportsActivityRegistration = supportsActivityRegistration
    }

    static let releaseCurrent = SupabaseManualSyncCapabilitySet(
        supportsRemoteCloudCheck: false,
        supportsForegroundCloudCheck: false,
        supportsGuidedManualSync: false,
        supportsCatalogPush: false,
        supportsProductPriceSync: false,
        supportsActivityRegistration: false
    )

    static func releaseCurrent(
        remotePreviewProvider: (any SupabaseManualSyncRemotePreviewProviding)?,
        catalogPushProvider: (any SupabaseManualSyncCatalogPushProviding)? = nil,
        productPriceProvider: (any SupabaseManualSyncProductPriceSyncProviding)? = nil,
        activityRegistrationProvider: (any SupabaseManualSyncActivityRegistrationProviding)? = nil
    ) -> SupabaseManualSyncCapabilitySet {
        SupabaseManualSyncCapabilitySet(
            supportsRemoteCloudCheck: remotePreviewProvider != nil,
            supportsForegroundCloudCheck: remotePreviewProvider != nil,
            supportsGuidedManualSync: false,
            supportsCatalogPush: catalogPushProvider != nil,
            supportsProductPriceSync: productPriceProvider != nil,
            supportsActivityRegistration: activityRegistrationProvider != nil
        )
    }
}

nonisolated enum SupabaseManualSyncSemiAutomaticTriggerSource: Equatable, Sendable {
    case releaseCard
    case rootForeground
}

nonisolated enum SupabaseManualSyncRootPresentationKind: Equatable, Sendable {
    case hidden
    case checking
    case changesFound
    case blockedAuth
    case recoverableError
}

nonisolated enum SupabaseManualSyncForegroundObservationEvent: String, Equatable, Sendable {
    case foreground_check_suggested
    case foreground_check_skipped_busy
    case foreground_check_throttled
    case foreground_check_completed_no_changes
    case foreground_check_completed_changes
}

@MainActor
private enum SupabaseManualSyncForegroundAutomaticGate {
    private static var isRunning = false
    private static var lastAttemptAt: Date?
    private static var lastRecoverableErrorAt: Date?

    static func reset() {
        isRunning = false
        lastAttemptAt = nil
        lastRecoverableErrorAt = nil
    }

    static func clearRecoverableError() {
        lastRecoverableErrorAt = nil
    }

    static func markAttempt(at date: Date) {
        lastAttemptAt = date
        isRunning = true
    }

    static func finish(lastRecoverableErrorAt recoverableErrorAt: Date?) {
        isRunning = false
        lastRecoverableErrorAt = recoverableErrorAt
    }

    static func decision(
        policy: SupabaseManualSyncSemiAutomaticPolicy,
        now: Date,
        lastCheckAt: Date?,
        instanceLastAttemptAt: Date?,
        instanceLastRecoverableErrorAt: Date?,
        supportsCloudCheck: Bool,
        isInstanceRunning: Bool,
        isAuthenticated: Bool,
        ownerUserID: UUID?,
        hasUnresolvedStagedPlan: Bool
    ) -> SupabaseManualSyncSemiAutomaticDecision {
        policy.foregroundCheckDecision(
            now: now,
            lastCheckAt: lastCheckAt,
            lastAttemptAt: latest(instanceLastAttemptAt, lastAttemptAt),
            lastRecoverableErrorAt: latest(instanceLastRecoverableErrorAt, lastRecoverableErrorAt),
            supportsCloudCheck: supportsCloudCheck,
            isRunning: isInstanceRunning || isRunning,
            isAuthenticated: isAuthenticated,
            ownerUserID: ownerUserID,
            hasUnresolvedStagedPlan: hasUnresolvedStagedPlan
        )
    }

    private static func latest(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case (.some(let lhs), .some(let rhs)):
            return max(lhs, rhs)
        case (.some(let lhs), .none):
            return lhs
        case (.none, .some(let rhs)):
            return rhs
        case (.none, .none):
            return nil
        }
    }
}

nonisolated struct SupabaseManualSyncRootPresentationState: Equatable, Sendable {
    var kind: SupabaseManualSyncRootPresentationKind
    var title: String
    var detail: String?
    var progressState: CloudSyncProgressState?
    var primaryActionTitle: String?
    var primaryActionID: SupabaseManualSyncPresentationActionID?
    var systemImage: String
    var accessibilityLabel: String

    static let hidden = SupabaseManualSyncRootPresentationState(
        kind: .hidden,
        title: "",
        detail: nil,
        progressState: nil,
        primaryActionTitle: nil,
        primaryActionID: nil,
        systemImage: "icloud",
        accessibilityLabel: ""
    )
}

nonisolated struct SupabaseManualSyncAuthPresentationContext: Equatable, Sendable {
    var isSignedIn: Bool
    var canSignIn: Bool
    var isTransitioning: Bool

    static let signedInReady = SupabaseManualSyncAuthPresentationContext(
        isSignedIn: true,
        canSignIn: true,
        isTransitioning: false
    )
}

nonisolated enum SupabaseManualSyncPresentationActionID: Equatable, Sendable {
    case signIn
    case realignData
    case checkCloud
    case downloadCloudDatabase
    case reviewChanges
    case syncNow
    case sendCloudChanges
    case retry
    case cancel
}

nonisolated struct SupabaseManualSyncPresentationAction: Equatable, Sendable {
    var id: SupabaseManualSyncPresentationActionID
    var title: String
    var systemImage: String?
    var isEnabled: Bool
    var accessibilityLabel: String
    var accessibilityHint: String?
}

nonisolated enum SupabaseManualSyncUserFacingSummaryKind: Equatable, Sendable {
    case cloudCheckCompleted
    case cloudCheckCompletedNoAction
    case remoteReviewNeeded
    case noLocalChangesToSend
    case cloudCheckIncomplete
    case networkIssue
    case cloudAccessIssue
    case genericIssue
    case cancelled
    case localApplyCompleted
    case localApplyFailed
    case catalogPushNoChanges
    case catalogPushSucceeded
    case catalogPushSucceededNeedsCheck
    case catalogPushPartial
    case catalogPushBlocked
    case catalogPushFailedBeforeWrite
    case catalogPushInterrupted
    case catalogPushStale
    case activityRegistrationSucceeded
    case activityRegistrationEmpty
    case activityRegistrationPartial
    case activityRegistrationAuthRequired
    case activityRegistrationRetryableFailure
    case activityRegistrationBlocked
    case activityRegistrationCancelled
}

nonisolated struct SupabaseManualSyncUserFacingSummary: Equatable, Sendable {
    var kind: SupabaseManualSyncUserFacingSummaryKind
    var message: String
}

nonisolated struct SupabaseManualSyncLocalApplySummary: Equatable, Sendable {
    var productsAdded: Int
    var productsUpdated: Int
    var suppliersCreated: Int
    var categoriesCreated: Int
    var priceSummary: SupabaseManualSyncProductPriceSummary = .empty
    var baselineCommitted: Bool = false
    var baselineCommitFailed: Bool = false
}

nonisolated enum SupabaseManualSyncReviewSectionTone: Equatable, Sendable {
    case neutral
    case success
    case attention
    case blocked
}

nonisolated enum SupabaseManualSyncReviewSectionID: String, Equatable, Sendable {
    case cloudToDevice
    case deviceToCloud
    case prices
    case attention
    case readyToSend
    case sendAttention
    case sendBlocked
    case activityRegistration
    case finalSummary
}

nonisolated struct SupabaseManualSyncReviewSectionState: Equatable, Identifiable, Sendable {
    var id: SupabaseManualSyncReviewSectionID
    var title: String
    var message: String
    var systemImage: String
    var tone: SupabaseManualSyncReviewSectionTone
}

nonisolated enum SupabaseManualSyncReviewPrimaryActionID: Equatable, Sendable {
    case none
    case updateDevice
    case sendCloudChanges
    case registerCloudActivity
    case recheck
    case signInAgain
    case openDatabase
}

nonisolated struct SupabaseManualSyncReviewSheetState: Equatable, Sendable {
    var title: String
    var subtitle: String
    var summaryTitle: String = ""
    var summaryMessage: String = ""
    var summarySystemImage: String = "checkmark.circle.fill"
    var summaryTone: SupabaseManualSyncReviewSectionTone = .neutral
    var progressState: CloudSyncProgressState? = nil
    var sections: [SupabaseManualSyncReviewSectionState]
    var footerMessage: String
    var primaryActionID: SupabaseManualSyncReviewPrimaryActionID
    var primaryActionTitle: String
    var primaryActionSystemImage: String
    var primaryActionIsEnabled: Bool
    var primaryActionIsLoading: Bool
    var secondaryActionTitle: String
    var accessibilityLabel: String
}

nonisolated struct SupabaseManualSyncPresentationState: Equatable, Sendable {
    var title: String
    var subtitle: String?
    var statusDetailText: String?
    var userFacingSummary: SupabaseManualSyncUserFacingSummary?
    var reviewSheet: SupabaseManualSyncReviewSheetState?
    var progressState: CloudSyncProgressState
    var statusBadgeText: String
    var statusBadgeSystemImage: String?
    var primaryAction: SupabaseManualSyncPresentationAction?
    var secondaryAction: SupabaseManualSyncPresentationAction?
    var isRunning: Bool
    var isLoading: Bool
    var accessibilityLabel: String
    var accessibilityHint: String?
}

nonisolated struct SupabaseManualSyncCatalogPushSummary: Equatable, Sendable {
    var readyCount: Int
    var createCount: Int
    var updateCount: Int
    var linkCount: Int
    var blockerCount: Int
    var warningCount: Int
    var futureOnlyCount: Int
    var planFingerprint: String?
    var resultStatus: SupabaseManualPushTerminalStatus?
    var resultMessage: String?

    var hasReadyChanges: Bool { readyCount > 0 }
    var hasBlockers: Bool { blockerCount > 0 }
    var hasWarnings: Bool { warningCount > 0 || futureOnlyCount > 0 }
}

nonisolated struct SupabaseManualSyncProductPriceSummary: Equatable, Sendable {
    var remoteFound: Int
    var localFound: Int
    var readyToApply: Int
    var readyToPush: Int
    var applied: Int
    var pushed: Int
    var skippedDuplicate: Int
    var skippedConflict: Int
    var failed: Int
    var blocked: Int

    static let empty = SupabaseManualSyncProductPriceSummary(
        remoteFound: 0,
        localFound: 0,
        readyToApply: 0,
        readyToPush: 0,
        applied: 0,
        pushed: 0,
        skippedDuplicate: 0,
        skippedConflict: 0,
        failed: 0,
        blocked: 0
    )

    var hasReviewSignals: Bool {
        remoteFound > 0
            || localFound > 0
            || readyToApply > 0
            || readyToPush > 0
            || applied > 0
            || pushed > 0
            || skippedDuplicate > 0
            || skippedConflict > 0
            || failed > 0
            || blocked > 0
    }

    var hasReadyToApply: Bool { readyToApply > 0 }
    var hasReadyToPush: Bool { readyToPush > 0 }
    var hasProblems: Bool { skippedConflict > 0 || failed > 0 || blocked > 0 }
}

nonisolated enum SupabaseManualSyncProductPricePushPhase: Equatable, Sendable {
    case idle
    case checking
    case ready(SupabaseManualSyncProductPriceSummary)
    case noChanges(SupabaseManualSyncProductPriceSummary)
    case blocked(SupabaseManualSyncProductPriceSummary)
    case failed(SupabaseManualSyncProductPriceSummary)
    case stale(SupabaseManualSyncProductPriceSummary)
    case sending(SupabaseManualSyncProductPriceSummary)
    case succeeded(SupabaseManualSyncProductPriceSummary)
    case partial(SupabaseManualSyncProductPriceSummary)
    case sendFailed(SupabaseManualSyncProductPriceSummary)
}

nonisolated enum SupabaseManualSyncCatalogPushPhase: Equatable, Sendable {
    case idle
    case checking
    case ready(SupabaseManualSyncCatalogPushSummary)
    case noChanges(SupabaseManualSyncCatalogPushSummary)
    case blocked(SupabaseManualSyncCatalogPushSummary)
    case failed(String?)
    case stale
    case sending(SupabaseManualSyncCatalogPushSummary)
    case succeeded(SupabaseManualSyncCatalogPushSummary)
    case succeededNeedsCheck(SupabaseManualSyncCatalogPushSummary)
    case partial(SupabaseManualSyncCatalogPushSummary)
    case sendBlocked(SupabaseManualSyncCatalogPushSummary)
    case sendFailed(SupabaseManualSyncCatalogPushSummary)
}

nonisolated enum SupabaseManualSyncActivityRegistrationStatus: Equatable, Sendable {
    case success
    case empty
    case partialRetryable
    case authRequired
    case retryableFailure
    case blocked
    case cancelled
}

nonisolated struct SupabaseManualSyncActivityRegistrationSnapshot: Equatable, Sendable {
    var readyToRegister: Int
    var waiting: Int
    var notRegisterable: Int

    static let empty = SupabaseManualSyncActivityRegistrationSnapshot(
        readyToRegister: 0,
        waiting: 0,
        notRegisterable: 0
    )

    var hasAnyActivity: Bool {
        readyToRegister > 0 || waiting > 0 || notRegisterable > 0
    }
}

nonisolated struct SupabaseManualSyncActivityRegistrationSummary: Equatable, Sendable {
    var registered: Int
    var waiting: Int
    var notRegisterable: Int

    static let empty = SupabaseManualSyncActivityRegistrationSummary(
        registered: 0,
        waiting: 0,
        notRegisterable: 0
    )
}

nonisolated struct SupabaseManualSyncActivityRegistrationResult: Equatable, Sendable {
    var status: SupabaseManualSyncActivityRegistrationStatus
    var summary: SupabaseManualSyncActivityRegistrationSummary
}

nonisolated enum SupabaseManualSyncActivityRegistrationPhase: Equatable, Sendable {
    case idle
    case ready(SupabaseManualSyncActivityRegistrationSnapshot)
    case registering(SupabaseManualSyncActivityRegistrationSnapshot)
    case finished(SupabaseManualSyncActivityRegistrationStatus, SupabaseManualSyncActivityRegistrationSummary)
}

@MainActor
protocol SupabaseManualSyncCatalogPushProviding: AnyObject {
    func makePushPlan(ownerUserID: UUID) async throws -> ManualPushPlan
    func execute(plan: ManualPushPlan, ownerUserID: UUID) async -> SupabaseManualPushResult
}

@MainActor
protocol SupabaseManualSyncProductPriceSyncProviding: AnyObject {
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

extension SupabaseManualSyncProductPriceSyncProviding {
    func apply(
        plan: ProductPriceApplyPlan,
        ownerUserID: UUID,
        onProgress: @escaping @MainActor @Sendable (ProductPricePagedApplyProgress) -> Void
    ) async throws -> ProductPriceApplyResult {
        try await apply(plan: plan, ownerUserID: ownerUserID)
    }
}

@MainActor
protocol SupabaseManualSyncActivityRegistrationProviding: AnyObject {
    func loadActivityRegistrationSnapshot(ownerUserID: UUID) async throws -> SupabaseManualSyncActivityRegistrationSnapshot
    func registerActivities(ownerUserID: UUID) async throws -> SupabaseManualSyncActivityRegistrationResult
}

nonisolated struct SupabaseManualSyncHistorySessionSummary: Equatable, Sendable {
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

@MainActor
protocol SupabaseManualSyncHistorySessionSyncProviding: AnyObject {
    func syncHistorySessions(
        ownerUserID: UUID,
        onProgress: @escaping @MainActor @Sendable (HistorySessionSyncProgress) -> Void
    ) async throws -> SupabaseManualSyncHistorySessionSummary
}

@MainActor
final class SupabaseManualSyncViewModel: ObservableObject {
    private enum Copy {
        static let idleTitle = "Sincronizzazione cloud guidata"
        static let idleSubtitle = "Puoi avviare la sincronizzazione quando sei pronto."
        static let runningTitle = "Sincronizzazione in corso…"
        static let startAction = "Avvia sincronizzazione"
        static let dismissOrRetryAction = "Riprova"
        static let signInAction = "Accedi"
        static let realignAction = "Riallinea dati"
        static let signInSubtitle = "Accedi di nuovo per continuare."
        static let realignSubtitle = "Prima aggiorna i dati dal cloud, poi riprova."
        static let busySubtitle = "Attendi che termini prima di riprovare."
        static let localPendingNeedsReviewTitle = "Ci sono modifiche da controllare"
        static let localPendingNeedsReviewSubtitle = "Nessun invio automatico."
    }

    private let coordinator: any SupabaseManualSyncCoordinating
    private let capabilities: SupabaseManualSyncCapabilitySet
    private let remotePreviewStaging: (any SupabaseManualSyncRemotePreviewStaging)?
    private let localApplyService: SupabasePullApplyService?
    private let localApplyContext: ModelContext?
    private let localApplyBaselineCommitter: any SupabaseManualSyncLocalApplyBaselineCommitting
    private let isLocalApplyAuthenticated: (@MainActor () -> Bool)?
    private let currentLocalApplyOwnerID: (@MainActor () -> UUID?)?
    private let catalogPushProvider: (any SupabaseManualSyncCatalogPushProviding)?
    private let currentCatalogPushOwnerID: (@MainActor () -> UUID?)?
    private let productPriceProvider: (any SupabaseManualSyncProductPriceSyncProviding)?
    private let currentProductPriceOwnerID: (@MainActor () -> UUID?)?
    private let activityRegistrationProvider: (any SupabaseManualSyncActivityRegistrationProviding)?
    private let currentActivityRegistrationOwnerID: (@MainActor () -> UUID?)?
    private let historySessionProvider: (any SupabaseManualSyncHistorySessionSyncProviding)?
    private let currentHistorySessionOwnerID: (@MainActor () -> UUID?)?
    private let baselineStatusProvider: (@MainActor () -> SupabaseCatalogBaselineDebugSummary?)?
    private let semiAutomaticPolicy: SupabaseManualSyncSemiAutomaticPolicy
    private let lifecycleRunGate: SupabaseManualSyncLifecycleRunGate
    private let defaultLifecyclePreflight: SupabaseManualSyncLifecyclePreflight?
    private let lifecycleNetworkIsAvailable: @MainActor () -> Bool
    private let lifecycleAppContextIsSafe: @MainActor () -> Bool
    private let lifecycleAppIsActive: @MainActor () -> Bool
    private var lastSemiAutomaticForegroundAttemptAt: Date?
    private var lastRecoverableForegroundErrorAt: Date?
    private var lastStartedMode: SupabaseManualSyncRunMode?
    private var stagedCatalogPushPlan: ManualPushPlan?
    private var stagedLocalApplyOwnerID: UUID?
    private var hasStagedLocalApplyOwnerID = false
    private var canApplyCatalogChanges = false
    private var canApplyProductPriceChanges = false
    private var stagedProductPriceApplyPlan: ProductPriceApplyPlan?
    private var stagedProductPriceApplyFingerprint: String?
    private var stagedProductPricePushPlan: ProductPricePushDryRunPlan?
    private var stagedProductPricePushFingerprint: String?

    @Published private(set) var presentationKind: SupabaseManualSyncUserPresentationKind = .idleReady
    @Published private(set) var title: String = Copy.idleTitle
    @Published private(set) var subtitle: String? = Copy.idleSubtitle
    @Published private(set) var primaryActionTitle: String = Copy.startAction
    @Published private(set) var isRunning = false
    @Published private(set) var cannotStartConcurrently = false
    @Published private(set) var lastSummary: SupabaseManualSyncRunSummary?
    @Published private(set) var authPresentationContext: SupabaseManualSyncAuthPresentationContext
    @Published private(set) var canApplyLocalChanges = false
    @Published private(set) var applyBlockedReason: String?
    @Published private(set) var isApplyingLocalChanges = false
    @Published private(set) var localApplyProgressMessage: String?
    @Published private(set) var lastLocalApplySummary: SupabaseManualSyncLocalApplySummary?
    @Published private(set) var catalogPushPhase: SupabaseManualSyncCatalogPushPhase = .idle
    @Published private(set) var productPricePushPhase: SupabaseManualSyncProductPricePushPhase = .idle
    @Published private(set) var productPriceSummary: SupabaseManualSyncProductPriceSummary = .empty
    @Published private(set) var activityRegistrationPhase: SupabaseManualSyncActivityRegistrationPhase = .idle
    @Published private(set) var isRegisteringActivities = false
    @Published private(set) var historySessionSummary: SupabaseManualSyncHistorySessionSummary?
    @Published private(set) var progressState: CloudSyncProgressState = .idle()
    @Published private(set) var semiAutomaticState: SupabaseManualSyncSemiAutomaticState = .idle
    @Published private(set) var lastCloudCheckAt: Date?
    @Published private(set) var lastForegroundObservationEvent: SupabaseManualSyncForegroundObservationEvent?
    @Published private(set) var lifecycleProcessState: SupabaseManualSyncLifecycleRunSnapshot = .idle

    init(
        coordinator: any SupabaseManualSyncCoordinating,
        capabilities: SupabaseManualSyncCapabilitySet = .releaseCurrent,
        initialAuthPresentationContext: SupabaseManualSyncAuthPresentationContext = .signedInReady,
        remotePreviewStaging: (any SupabaseManualSyncRemotePreviewStaging)? = nil,
        localApplyService: SupabasePullApplyService? = nil,
        localApplyContext: ModelContext? = nil,
        localApplyBaselineCommitter: (any SupabaseManualSyncLocalApplyBaselineCommitting)? = nil,
        isLocalApplyAuthenticated: (@MainActor () -> Bool)? = nil,
        currentLocalApplyOwnerID: (@MainActor () -> UUID?)? = nil,
        catalogPushProvider: (any SupabaseManualSyncCatalogPushProviding)? = nil,
        currentCatalogPushOwnerID: (@MainActor () -> UUID?)? = nil,
        productPriceProvider: (any SupabaseManualSyncProductPriceSyncProviding)? = nil,
        currentProductPriceOwnerID: (@MainActor () -> UUID?)? = nil,
        activityRegistrationProvider: (any SupabaseManualSyncActivityRegistrationProviding)? = nil,
        currentActivityRegistrationOwnerID: (@MainActor () -> UUID?)? = nil,
        historySessionProvider: (any SupabaseManualSyncHistorySessionSyncProviding)? = nil,
        currentHistorySessionOwnerID: (@MainActor () -> UUID?)? = nil,
        baselineStatusProvider: (@MainActor () -> SupabaseCatalogBaselineDebugSummary?)? = nil,
        semiAutomaticPolicy: SupabaseManualSyncSemiAutomaticPolicy = SupabaseManualSyncSemiAutomaticPolicy(),
        lifecycleRunGate: SupabaseManualSyncLifecycleRunGate? = nil,
        lifecycleNetworkIsAvailable: @escaping @MainActor () -> Bool = { true },
        lifecycleAppContextIsSafe: @escaping @MainActor () -> Bool = { true },
        lifecycleAppIsActive: @escaping @MainActor () -> Bool = { true },
        lifecycleTimeBudget: TimeInterval = 45
    ) {
        self.coordinator = coordinator
        self.capabilities = capabilities
        self.authPresentationContext = initialAuthPresentationContext
        self.remotePreviewStaging = remotePreviewStaging
        self.localApplyService = localApplyService
        self.localApplyContext = localApplyContext
        self.localApplyBaselineCommitter = localApplyBaselineCommitter ?? SupabaseManualSyncLocalApplyBaselineCommitter()
        self.isLocalApplyAuthenticated = isLocalApplyAuthenticated
        self.currentLocalApplyOwnerID = currentLocalApplyOwnerID
        self.catalogPushProvider = catalogPushProvider
        self.currentCatalogPushOwnerID = currentCatalogPushOwnerID
        self.productPriceProvider = productPriceProvider
        self.currentProductPriceOwnerID = currentProductPriceOwnerID
        self.activityRegistrationProvider = activityRegistrationProvider
        self.currentActivityRegistrationOwnerID = currentActivityRegistrationOwnerID
        self.historySessionProvider = historySessionProvider
        self.currentHistorySessionOwnerID = currentHistorySessionOwnerID
        self.baselineStatusProvider = baselineStatusProvider
        self.semiAutomaticPolicy = semiAutomaticPolicy
        self.lifecycleNetworkIsAvailable = lifecycleNetworkIsAvailable
        self.lifecycleAppContextIsSafe = lifecycleAppContextIsSafe
        self.lifecycleAppIsActive = lifecycleAppIsActive
        if let lifecycleRunGate {
            self.lifecycleRunGate = lifecycleRunGate
            self.defaultLifecyclePreflight = nil
        } else {
            let preflight = SupabaseManualSyncLifecyclePreflight(
                isSignedIn: { true },
                ownerUserID: { UUID() },
                isNetworkAvailable: lifecycleNetworkIsAvailable,
                isAppContextSafe: lifecycleAppContextIsSafe,
                isAppLifecycleCompatible: lifecycleAppIsActive
            )
            self.lifecycleRunGate = SupabaseManualSyncLifecycleRunGate(
                preflight: preflight,
                timeBudget: lifecycleTimeBudget
            )
            self.defaultLifecyclePreflight = preflight
        }
    }

    var presentationState: SupabaseManualSyncPresentationState {
        makePresentationState()
    }

    var rootPresentationState: SupabaseManualSyncRootPresentationState {
        makeRootPresentationState()
    }

    static func resetForegroundAutomaticGateForTests() {
        SupabaseManualSyncForegroundAutomaticGate.reset()
    }

    var canStart: Bool {
        !isRunning && !isApplyingLocalChanges && !isSendingCatalogChanges && !isRegisteringActivities
    }

    var requiresReviewDiscardConfirmation: Bool {
        hasUnresolvedStagedPlan
    }

    /// Future guided flow gate (confirmation before mutations). Stubbed false until guided UX exists.
    var pendingConfirmation: Bool { false }

    var shouldShowConfirmation: Bool { false }

    var isSendingCatalogChanges: Bool {
        if case .sending = catalogPushPhase {
            return true
        }
        if case .sending = productPricePushPhase {
            return true
        }
        return false
    }

    var isReviewMutationInProgress: Bool {
        isApplyingLocalChanges || isSendingCatalogChanges || isRegisteringActivities
    }

    var hasTerminalCatalogPushSummary: Bool {
        switch catalogPushPhase {
        case .succeeded, .succeededNeedsCheck, .partial, .sendBlocked, .sendFailed, .stale, .failed, .noChanges:
            return true
        case .idle, .checking, .ready, .blocked, .sending:
            return false
        }
    }

    var lastUserMessage: String {
        var parts = [title]
        if let s = subtitle, !s.isEmpty { parts.append(s) }
        return parts.joined(separator: " ")
    }

    var privacySafeAggregatesSnapshot: SupabaseManualSyncPrivacyCounts? {
        lastSummary?.countsSnapshot
    }

    private var currentSemiAutomaticOwnerID: UUID? {
        currentLocalApplyOwnerID?()
            ?? currentCatalogPushOwnerID?()
            ?? currentProductPriceOwnerID?()
            ?? currentActivityRegistrationOwnerID?()
            ?? currentHistorySessionOwnerID?()
    }

    private var hasLifecycleOwnerProvider: Bool {
        currentLocalApplyOwnerID != nil
            || currentCatalogPushOwnerID != nil
            || currentProductPriceOwnerID != nil
            || currentActivityRegistrationOwnerID != nil
            || currentHistorySessionOwnerID != nil
    }

    private var currentLifecycleOwnerID: UUID? {
        if hasLifecycleOwnerProvider {
            return currentSemiAutomaticOwnerID
        }
        return UUID(uuidString: "09500000-0000-4095-8095-000000000001")
    }

    private func configureDefaultLifecyclePreflight() {
        guard let defaultLifecyclePreflight else { return }
        defaultLifecyclePreflight.isSignedIn = { [weak self] in
            self?.authPresentationContext.isSignedIn == true
        }
        defaultLifecyclePreflight.ownerUserID = { [weak self] in
            self?.currentLifecycleOwnerID
        }
        defaultLifecyclePreflight.isNetworkAvailable = lifecycleNetworkIsAvailable
        defaultLifecyclePreflight.isAppContextSafe = lifecycleAppContextIsSafe
        defaultLifecyclePreflight.isAppLifecycleCompatible = lifecycleAppIsActive
    }

    private func beginLifecycleRun(
        kind: SupabaseManualSyncLifecycleRunKind,
        source: SupabaseManualSyncLifecycleRunSource
    ) -> UUID? {
        configureDefaultLifecyclePreflight()
        switch lifecycleRunGate.begin(kind: kind, source: source) {
        case .started(let snapshot):
            lifecycleProcessState = snapshot
            return snapshot.runID
        case .ignored(let reason, let snapshot):
            lifecycleProcessState = snapshot
            if reason == .interruptedMutationNeedsReview {
                semiAutomaticState = .changesFound
            }
            return nil
        case .blocked(let reason, let snapshot):
            lifecycleProcessState = snapshot
            applyLifecycleBlock(reason: reason, kind: kind)
            return nil
        }
    }

    private func lifecycleSource(
        for source: SupabaseManualSyncSemiAutomaticTriggerSource
    ) -> SupabaseManualSyncLifecycleRunSource {
        switch source {
        case .rootForeground:
            return .rootForeground
        case .releaseCard:
            return .optionsCard
        }
    }

    private func applyLifecycleBlock(
        reason: SupabaseManualSyncLifecycleBlockReason,
        kind: SupabaseManualSyncLifecycleRunKind
    ) {
        switch reason {
        case .authMissing, .ownerMissing:
            semiAutomaticState = .blockedAuth
            presentationKind = .blockedNeedsSignIn
            title = SupabaseManualSyncUserFacingCopy.signInAgain
            subtitle = Copy.signInSubtitle
            primaryActionTitle = Copy.signInAction
        case .networkUnavailable, .unsafeAppContext, .appNotActive:
            semiAutomaticState = .recoverableError
            presentationKind = .technicalFollowUpNeeded
            title = L("options.supabase.manualSync.lifecycle.blocked.title")
            subtitle = L("options.supabase.manualSync.lifecycle.blocked.subtitle")
            primaryActionTitle = Copy.dismissOrRetryAction
        case .readOnlyIgnoredForMutatingRun,
             .mutatingRunAlreadyActive,
             .runAlreadyActive,
             .interruptedMutationNeedsReview:
            if kind.isMutating {
                semiAutomaticState = .recoverableError
                presentationKind = .auxiliaryBusyConcurrent
            }
        }
    }

    private func markLifecycleInterrupted(
        runID: UUID?,
        reason: SupabaseManualSyncLifecycleInterruptReason
    ) {
        guard let runID else { return }
        lifecycleRunGate.markCancelling(runID: runID, reason: reason)
        lifecycleProcessState = lifecycleRunGate.markInterrupted(runID: runID, reason: reason)
        applyLifecycleInterruptedPresentationIfNeeded()
    }

    private func completeLifecycleRunIfVerified(_ runID: UUID?) {
        guard let runID else { return }
        lifecycleProcessState = lifecycleRunGate.markCompletedVerified(runID: runID)
    }

    private func interruptLifecycleRunIfBudgetExpired(_ runID: UUID?) -> Bool {
        guard let runID else { return false }
        let snapshot = lifecycleRunGate.expireBudgetIfNeeded()
        lifecycleProcessState = snapshot
        guard snapshot.runID == runID,
              snapshot.state == .readyToRetry,
              snapshot.interruptReason == .timeBudgetExceeded else {
            return false
        }
        applyLifecycleInterruptedPresentationIfNeeded()
        return true
    }

    private func applyLifecycleInterruptedPresentationIfNeeded() {
        guard lifecycleProcessState.hasInterruptedMutationPriority else { return }
        if lifecycleShouldShowPriorityAttention {
            semiAutomaticState = .recoverableError
        }
    }

    func requestLifecycleInterruptionForBackground() {
        let snapshot = lifecycleRunGate.snapshot
        guard let runID = snapshot.runID,
              snapshot.state == .running || snapshot.state == .cancelling else { return }
        markLifecycleInterrupted(runID: runID, reason: .appBackgrounded)
    }

    private var hasUnresolvedStagedPlan: Bool {
        if canApplyLocalChanges || stagedCatalogPushPlan != nil {
            return true
        }
        if stagedProductPriceApplyPlan != nil || stagedProductPricePushPlan != nil {
            return true
        }
        if activityRegistrationPhase.hasRegisterAction {
            return true
        }
        if let remotePreviewSummary = lastSummary?.remotePreviewSummary,
           remotePreviewSummary.hasRemoteSignals,
           remotePreviewSummary.isComplete,
           !remotePreviewSummary.isPartial,
           !remotePreviewSummary.wasCancelled,
           remotePreviewSummary.failureCategory == nil {
            return true
        }
        return false
    }

    private func semiAutomaticForegroundDecision(
        now: Date,
        source: SupabaseManualSyncSemiAutomaticTriggerSource
    ) -> SupabaseManualSyncSemiAutomaticDecision {
        let supportsCloudCheck = source == .rootForeground
            ? capabilities.supportsForegroundCloudCheck
            : capabilities.supportsRemoteCloudCheck
        return SupabaseManualSyncForegroundAutomaticGate.decision(
            policy: semiAutomaticPolicy,
            now: now,
            lastCheckAt: lastCloudCheckAt,
            instanceLastAttemptAt: lastSemiAutomaticForegroundAttemptAt,
            instanceLastRecoverableErrorAt: lastRecoverableForegroundErrorAt,
            supportsCloudCheck: supportsCloudCheck,
            isInstanceRunning: isRunning || !canStart,
            isAuthenticated: authPresentationContext.isSignedIn,
            ownerUserID: currentSemiAutomaticOwnerID,
            hasUnresolvedStagedPlan: hasUnresolvedStagedPlan
        )
    }

    private func recordCloudCheckResult(_ summary: SupabaseManualSyncRunSummary, at date: Date) {
        lastCloudCheckAt = date

        let setRecoverableError: () -> Void = {
            self.lastRecoverableForegroundErrorAt = date
        }
        let clearRecoverableError: () -> Void = {
            self.lastRecoverableForegroundErrorAt = nil
        }

        guard let remotePreviewSummary = summary.remotePreviewSummary else {
            switch summary.finalState {
            case .blocked:
                semiAutomaticState = .blockedAuth
            case .connectivityIssue, .technicalReviewNeeded:
                semiAutomaticState = .recoverableError
                setRecoverableError()
            case .partialSync:
                semiAutomaticState = .changesFound
                clearRecoverableError()
                lastForegroundObservationEvent = .foreground_check_completed_changes
            case .cancelled:
                semiAutomaticState = .idle
            case .allUpToDate, .completedSuccessfully, .concurrentRunNotAllowed, .modeNotSupportedInThisSlice:
                semiAutomaticState = .noChanges
                clearRecoverableError()
                lastForegroundObservationEvent = .foreground_check_completed_no_changes
            }
            return
        }

        if remotePreviewSummary.wasCancelled {
            semiAutomaticState = .idle
        } else if remotePreviewSummary.failureCategory == .auth {
            semiAutomaticState = .blockedAuth
            clearRecoverableError()
        } else if remotePreviewSummary.failureCategory != nil || remotePreviewSummary.isPartial || !remotePreviewSummary.isComplete {
            semiAutomaticState = .recoverableError
            setRecoverableError()
        } else if remotePreviewSummary.safeAggregateCounts.conflictCount > 0
            || remotePreviewSummary.safeAggregateCounts.tombstoneCount > 0
            || remotePreviewSummary.safeAggregateCounts.sourceErrorCount > 0 {
            semiAutomaticState = .staleOrConflict
            presentationKind = .partialSync
            clearRecoverableError()
            lastForegroundObservationEvent = .foreground_check_completed_changes
        } else if remotePreviewSummary.hasRemoteSignals || summary.countsSnapshot.hasAnyPendingWork || hasUnresolvedStagedPlan {
            semiAutomaticState = .changesFound
            presentationKind = .partialSync
            clearRecoverableError()
            lastForegroundObservationEvent = .foreground_check_completed_changes
        } else {
            semiAutomaticState = .noChanges
            clearRecoverableError()
            lastForegroundObservationEvent = .foreground_check_completed_no_changes
        }
    }

    func suggestSemiAutomaticCheckIfAllowed(
        now: Date = Date(),
        source: SupabaseManualSyncSemiAutomaticTriggerSource = .releaseCard
    ) {
        switch semiAutomaticForegroundDecision(now: now, source: source) {
        case .allowed:
            guard semiAutomaticState == .idle || semiAutomaticState == .noChanges else { return }
            semiAutomaticState = .suggestedCheck
            if source == .rootForeground {
                lastForegroundObservationEvent = .foreground_check_suggested
            }
        case .blocked(.authOrOwnerMissing):
            semiAutomaticState = .blockedAuth
        case .blocked(.stagedPlanUnresolved):
            if semiAutomaticState != .reviewing {
                semiAutomaticState = .changesFound
            }
        case .blocked(.debounce), .blocked(.cooldown), .blocked(.recoverableErrorBackoff):
            if source == .rootForeground {
                lastForegroundObservationEvent = .foreground_check_throttled
            }
        case .blocked:
            break
        }
    }

    @discardableResult
    func startForegroundSemiAutomaticCheckIfAllowed(
        now: Date = Date(),
        source: SupabaseManualSyncSemiAutomaticTriggerSource = .releaseCard
    ) async -> Bool {
        switch semiAutomaticForegroundDecision(now: now, source: source) {
        case .allowed:
            guard let lifecycleRunID = beginLifecycleRun(
                kind: .previewReadOnly,
                source: lifecycleSource(for: source)
            ) else {
                return false
            }
            lastSemiAutomaticForegroundAttemptAt = now
            SupabaseManualSyncForegroundAutomaticGate.markAttempt(at: now)
            if source == .rootForeground {
                lastForegroundObservationEvent = .foreground_check_suggested
            }
            defer {
                SupabaseManualSyncForegroundAutomaticGate.finish(
                    lastRecoverableErrorAt: lastRecoverableForegroundErrorAt
                )
            }
            await start(with: .dryRun, checkStartedAt: now, lifecycleRunID: lifecycleRunID)
            if source == .rootForeground, shouldAutoApplyForegroundPreviewAfterLastCheck {
                await applyStagedLocalChanges()
            }
            return true
        case .blocked(.authOrOwnerMissing):
            semiAutomaticState = .blockedAuth
        case .blocked(.stagedPlanUnresolved):
            if semiAutomaticState != .reviewing {
                semiAutomaticState = .changesFound
            }
        case .blocked(.debounce), .blocked(.cooldown), .blocked(.recoverableErrorBackoff):
            if source == .rootForeground {
                lastForegroundObservationEvent = .foreground_check_throttled
            }
        case .blocked:
            break
        }
        return false
    }

    func markForegroundCheckSkippedBecauseBusy() {
        lastForegroundObservationEvent = .foreground_check_skipped_busy
    }

    func markReviewingSemiAutomaticPlan() {
        guard presentationState.reviewSheet != nil else { return }
        semiAutomaticState = .reviewing
    }

    func markReviewDismissedWithoutDiscard() {
        if hasUnresolvedStagedPlan {
            semiAutomaticState = .changesFound
        } else if semiAutomaticState == .reviewing {
            semiAutomaticState = lastCloudCheckAt == nil ? .idle : .noChanges
        }
    }

    /// Dry-run rehearsal path wired to TASK-065 coordinator until guided manual mode is executable.
    func startDryRunVerification() async {
        await start(with: .dryRun)
    }

    func start(
        with mode: SupabaseManualSyncRunMode,
        checkStartedAt: Date = Date(),
        lifecycleRunID: UUID? = nil
    ) async {
        guard !isRunning else { return }
        let activeLifecycleRunID: UUID?
        if let lifecycleRunID {
            activeLifecycleRunID = lifecycleRunID
        } else if mode == .dryRun {
            guard let runID = beginLifecycleRun(kind: .pullPreview, source: .optionsCard) else { return }
            activeLifecycleRunID = runID
        } else {
            activeLifecycleRunID = nil
        }
        invalidateLocalApplyStaging(clearSummary: true)
        invalidateCatalogPushPlan(clearSummary: true)
        invalidateProductPricePlans(clearSummary: true)
        invalidateActivityRegistration(clearSummary: true)
        lastStartedMode = mode
        if mode == .dryRun {
            semiAutomaticState = .checking
        }
        isRunning = true
        defer { isRunning = false }

        transitionToRunning()

        updateProgress(
            phase: .fetchingRemoteCounts,
            domain: .catalog,
            message: L("options.supabase.manualSync.progress.fetchingRemoteCounts"),
            detailMessage: L("options.supabase.manualSync.progress.allowsLocalWork")
        )
        let summary = await coordinator.run(mode: mode, sessionID: UUID())

        guard !Task.isCancelled else {
            // Coordinator should already surface cancellation; fallback keeps UI truthful.
            let cancelledSummary = summary.finalState == .cancelled
                ? summary
                : cancelledFallbackSummary(previous: summary)
            apply(summary: cancelledSummary)
            cancelProgress()
            markLifecycleInterrupted(runID: activeLifecycleRunID, reason: .cancelledBeforeWrite)
            if mode == .dryRun {
                semiAutomaticState = .idle
            }
            return
        }

        if interruptLifecycleRunIfBudgetExpired(activeLifecycleRunID) {
            apply(summary: cancelledFallbackSummary(previous: summary))
            return
        }

        apply(summary: summary)
        updateProgress(
            phase: .reviewingChanges,
            domain: .catalog,
            message: L("options.supabase.manualSync.progress.reviewingChanges"),
            detailMessage: progressDetail(after: summary)
        )
        await prepareCatalogPushPlanIfNeeded(after: summary)
        await prepareProductPricePlansIfNeeded(after: summary)
        await prepareActivityRegistrationIfNeeded(after: summary)
        if mode == .dryRun {
            recordCloudCheckResult(summary, at: checkStartedAt)
        }
        finishProgress(
            warnings: shouldFinishProgressWithWarnings(summary),
            message: progressCompletionMessage(after: summary),
            detailMessage: progressDetail(after: summary)
        )
        switch summary.finalState {
        case .allUpToDate, .completedSuccessfully:
            completeLifecycleRunIfVerified(activeLifecycleRunID)
        case .blocked:
            lifecycleProcessState = lifecycleRunGate.markBlocked(
                runID: activeLifecycleRunID,
                kind: mode == .dryRun ? .pullPreview : .previewReadOnly,
                source: .optionsCard,
                reason: .unsafeAppContext
            )
        case .cancelled:
            markLifecycleInterrupted(runID: activeLifecycleRunID, reason: .cancelledBeforeWrite)
        case .partialSync, .connectivityIssue, .technicalReviewNeeded, .concurrentRunNotAllowed, .modeNotSupportedInThisSlice:
            completeLifecycleRunIfVerified(activeLifecycleRunID)
        }
    }

    private func shouldFinishProgressWithWarnings(_ summary: SupabaseManualSyncRunSummary) -> Bool {
        switch summary.finalState {
        case .allUpToDate, .completedSuccessfully:
            return summary.hasIncompleteRemotePreview
                || summary.countsSnapshot.hasAnyPendingWork
                || summary.remotePreviewSummary?.hasRemoteSignals == true
        case .partialSync,
             .blocked,
             .connectivityIssue,
             .technicalReviewNeeded,
             .concurrentRunNotAllowed,
             .modeNotSupportedInThisSlice,
             .cancelled:
            return true
        }
    }

    private func progressCompletionMessage(after summary: SupabaseManualSyncRunSummary) -> String {
        if summary.finalState == .cancelled {
            return L("options.supabase.manualSync.progress.cancelled")
        }
        if summary.remotePreviewSummary?.hasRemoteSignals == true
            || summary.countsSnapshot.hasAnyPendingWork
            || hasUnresolvedStagedPlan {
            return L("options.supabase.manualSync.progress.readyToReview")
        }
        if shouldFinishProgressWithWarnings(summary) {
            return L("options.supabase.manualSync.progress.completedWithWarnings")
        }
        return L("options.supabase.manualSync.progress.completed")
    }

    private func progressDetail(after summary: SupabaseManualSyncRunSummary) -> String? {
        guard let remotePreviewSummary = summary.remotePreviewSummary else {
            return nonEmpty(summary.suggestedNextStep)
        }
        let counts = remotePreviewSummary.safeAggregateCounts
        let pieces = [
            counts.newProductCount > 0 ? L("options.supabase.manualSync.progress.detail.products", counts.newProductCount) : nil,
            counts.priceHistorySignalCount > 0 ? L("options.supabase.manualSync.progress.detail.prices", counts.priceHistorySignalCount) : nil,
            summary.countsSnapshot.pendingQueuedCloudOperationCount > 0 ? L("options.supabase.manualSync.progress.detail.pending", summary.countsSnapshot.pendingQueuedCloudOperationCount) : nil
        ].compactMap { $0 }
        return pieces.isEmpty ? nil : pieces.joined(separator: " · ")
    }

    private func cancelledFallbackSummary(previous: SupabaseManualSyncRunSummary) -> SupabaseManualSyncRunSummary {
        SupabaseManualSyncRunSummary(
            finalState: .cancelled,
            userFacingHeadline: SupabaseManualSyncUserFacingCopy.cancelled,
            executedPhases: previous.executedPhases,
            skippedPhases: previous.skippedPhases,
            countsSnapshot: previous.countsSnapshot,
            suggestedNextStep: nil,
            detailMessage: nil
        )
    }

    private func transitionToRunning() {
        presentationKind = .running
        title = Copy.runningTitle
        subtitle = nil
        primaryActionTitle = Copy.startAction
        updateProgress(
            phase: .checkingCloud,
            domain: .catalog,
            message: L("options.supabase.manualSync.progress.checkingCloud"),
            detailMessage: L("options.supabase.manualSync.progress.allowsLocalWork"),
            canCancel: true,
            isBlockingApply: false,
            allowsLocalWork: true
        )
    }

    private func updateProgress(
        phase: CloudSyncProgressPhase,
        domain: CloudSyncProgressDomain?,
        current: Int? = nil,
        total: Int? = nil,
        message: String,
        detailMessage: String? = nil,
        canCancel: Bool = true,
        isBlockingApply: Bool = false,
        allowsLocalWork: Bool = true
    ) {
        let startedAt = progressState.isActive ? progressState.startedAt : nil
        progressState = CloudSyncProgressState.running(
            phase: phase,
            domain: domain,
            current: current,
            total: total,
            message: message,
            detailMessage: detailMessage,
            startedAt: startedAt,
            canCancel: canCancel,
            isBlockingApply: isBlockingApply,
            allowsLocalWork: allowsLocalWork
        )
    }

    private func finishProgress(
        warnings: Bool = false,
        message: String? = nil,
        detailMessage: String? = nil
    ) {
        let now = Date()
        progressState = CloudSyncProgressState(
            phase: warnings ? .completedWithWarnings : .completed,
            domain: nil,
            current: nil,
            total: nil,
            message: message ?? L(warnings
                ? "options.supabase.manualSync.progress.completedWithWarnings"
                : "options.supabase.manualSync.progress.completed"
            ),
            detailMessage: detailMessage,
            startedAt: progressState.startedAt,
            lastUpdatedAt: now,
            canCancel: false,
            isBlockingApply: false,
            allowsLocalWork: true
        )
    }

    private func failProgress(message: String? = nil) {
        let now = Date()
        progressState = CloudSyncProgressState(
            phase: .failed,
            domain: progressState.domain,
            current: progressState.current,
            total: progressState.total,
            message: message ?? L("options.supabase.manualSync.progress.failed"),
            detailMessage: progressState.detailMessage,
            startedAt: progressState.startedAt,
            lastUpdatedAt: now,
            canCancel: false,
            isBlockingApply: false,
            allowsLocalWork: true
        )
    }

    private func cancelProgress() {
        let now = Date()
        progressState = CloudSyncProgressState(
            phase: .cancelled,
            domain: progressState.domain,
            current: progressState.current,
            total: progressState.total,
            message: L("options.supabase.manualSync.progress.cancelled"),
            detailMessage: nil,
            startedAt: progressState.startedAt,
            lastUpdatedAt: now,
            canCancel: false,
            isBlockingApply: false,
            allowsLocalWork: true
        )
    }

    func apply(summary: SupabaseManualSyncRunSummary) {
        cannotStartConcurrently = false
        lastSummary = summary
        canApplyLocalChanges = false
        canApplyCatalogChanges = false
        canApplyProductPriceChanges = false
        applyBlockedReason = nil
        lastLocalApplySummary = nil

        switch summary.finalState {
        case .completedSuccessfully where summary.hasIncompleteRemotePreview:
            presentationKind = .technicalFollowUpNeeded
            title = SupabaseManualSyncUserFacingCopy.technicalFollowUp
            subtitle = nonEmpty(summary.suggestedNextStep)
            primaryActionTitle = Copy.dismissOrRetryAction

        case .completedSuccessfully where summary.countsSnapshot.hasAnyPendingWork:
            presentationKind = .partialSync
            title = Copy.localPendingNeedsReviewTitle
            subtitle = Copy.localPendingNeedsReviewSubtitle
            primaryActionTitle = Copy.startAction

        case .allUpToDate, .completedSuccessfully:
            presentationKind = .successFullyUpToDate
            title = SupabaseManualSyncUserFacingCopy.allUpToDate
            subtitle = summarySummarySubtitle(from: summary)
            primaryActionTitle = Copy.startAction

        case .partialSync:
            presentationKind = .partialSync
            title = SupabaseManualSyncUserFacingCopy.partialSync
            subtitle = nonEmpty(summary.suggestedNextStep) ?? nonEmpty(summary.userFacingHeadline)
            primaryActionTitle = Copy.dismissOrRetryAction

        case .technicalReviewNeeded where summary.hasCompletedRemotePreviewSignals:
            presentationKind = .partialSync
            title = Copy.localPendingNeedsReviewTitle
            subtitle = Copy.localPendingNeedsReviewSubtitle
            primaryActionTitle = Copy.startAction

        case .blocked:
            let blockedPresentation = interpretBlocked(summary: summary)
            presentationKind = blockedPresentation.kind
            title = blockedPresentation.title
            subtitle = blockedPresentation.subtitle
            primaryActionTitle = blockedPresentation.primaryActionTitle

        case .connectivityIssue:
            presentationKind = .connectivityIssue
            title = SupabaseManualSyncUserFacingCopy.connectivityRetry
            subtitle = nonEmpty(summary.suggestedNextStep)
            primaryActionTitle = Copy.dismissOrRetryAction

        case .cancelled:
            presentationKind = .cancelledRun
            title = SupabaseManualSyncUserFacingCopy.cancelled
            subtitle = nil
            primaryActionTitle = Copy.startAction

        case .technicalReviewNeeded:
            presentationKind = .technicalFollowUpNeeded
            title = SupabaseManualSyncUserFacingCopy.technicalFollowUp
            subtitle = nonEmpty(summary.suggestedNextStep)
            primaryActionTitle = Copy.dismissOrRetryAction

        case .concurrentRunNotAllowed:
            presentationKind = .auxiliaryBusyConcurrent
            cannotStartConcurrently = true
            title = summary.userFacingHeadline
            subtitle = subtitleCandidate(summary.suggestedNextStep, fallback: Copy.busySubtitle, title: title)
            primaryActionTitle = Copy.dismissOrRetryAction

        case .modeNotSupportedInThisSlice:
            presentationKind = .auxiliaryModeUnavailable
            title = summary.userFacingHeadline
            subtitle = nil
            primaryActionTitle = Copy.startAction
        }

        refreshLocalApplyEligibility(from: summary)
    }

    func cancelLocalApplyReview() {
        guard !isApplyingLocalChanges else { return }
        guard canApplyLocalChanges
            || remotePreviewStaging?.stagedPreviewForLocalApply != nil
            || stagedProductPriceApplyPlan != nil else { return }
        invalidateLocalApplyStaging(reason: L("options.supabase.manualSync.apply.blocked.refreshRequired"))
        invalidateProductPriceApplyPlan(clearSummary: false)
    }

    func cancelReviewFlow() {
        guard !isReviewMutationInProgress else { return }
        cancelLocalApplyReview()
        switch catalogPushPhase {
        case .ready, .blocked, .checking:
            invalidateCatalogPushPlan()
        case .idle, .noChanges, .failed, .stale, .sending, .succeeded, .succeededNeedsCheck, .partial, .sendBlocked, .sendFailed:
            break
        }
        switch productPricePushPhase {
        case .ready, .blocked, .checking:
            invalidateProductPricePushPlan()
        case .idle, .noChanges, .failed, .stale, .sending, .succeeded, .partial, .sendFailed:
            break
        }
        switch activityRegistrationPhase {
        case .ready:
            invalidateActivityRegistration(clearSummary: false)
        case .idle, .registering, .finished:
            break
        }
        lastSummary = nil
        lastLocalApplySummary = nil
        progressState = .idle()
        cannotStartConcurrently = false
        presentationKind = .idleReady
        title = Copy.idleTitle
        subtitle = Copy.idleSubtitle
        primaryActionTitle = Copy.startAction
        semiAutomaticState = lastCloudCheckAt == nil ? .idle : .noChanges
    }

    func applyStagedLocalChanges() async {
        guard !isApplyingLocalChanges else { return }
        guard let lifecycleRunID = beginLifecycleRun(kind: .pullApplyLocal, source: .releaseSheet) else { return }

        let preview = remotePreviewStaging?.stagedPreviewForLocalApply
        guard canApplyCatalogChanges || canApplyProductPriceChanges else {
            invalidateLocalApplyStaging(reason: L("options.supabase.manualSync.apply.blocked.refreshRequired"))
            markLifecycleInterrupted(runID: lifecycleRunID, reason: .cancelledBeforeWrite)
            return
        }

        isApplyingLocalChanges = true
        localApplyProgressMessage = L("options.supabase.manualSync.progress.preparing")
        updateProgress(
            phase: .applyingLocalDatabase,
            domain: .catalog,
            message: L("options.supabase.manualSync.progress.preparing"),
            detailMessage: L("options.supabase.manualSync.progress.allowsLocalWork"),
            isBlockingApply: true,
            allowsLocalWork: true
        )
        canApplyLocalChanges = false
        canApplyCatalogChanges = false
        canApplyProductPriceChanges = false
        applyBlockedReason = nil
        await Task.yield()

        guard !Task.isCancelled else {
            isApplyingLocalChanges = false
            localApplyProgressMessage = nil
            cancelProgress()
            invalidateLocalApplyStaging(clearSummary: true)
            markLifecycleInterrupted(runID: lifecycleRunID, reason: .cancelledBeforeWrite)
            return
        }

        do {
            var catalogResult = SupabasePullApplyResult(
                inserted: 0,
                updated: 0,
                suppliersCreated: 0,
                categoriesCreated: 0
            )
            if let preview, remotePreviewStaging?.stagedPreviewForLocalApply != nil {
                do {
                    try validateLocalApplyOwnerStillCurrent()
                    localApplyProgressMessage = L("options.supabase.manualSync.progress.applyingCatalog")
                    let plan = try prepareLocalApplyPlan(from: preview)
                    guard let context = localApplyContext,
                          let service = localApplyService else {
                        throw LocalApplyInternalError.dependenciesUnavailable
                    }
                    catalogResult = try await service.applyBatched(
                        plan: plan,
                        context: context,
                        onProgress: { [weak self] progress in
                            self?.applyCatalogProgress(progress)
                        }
                    )
                } catch let error as SupabasePullApplyError where error.disabledReason == .noApplicableChanges {
                    catalogResult = SupabasePullApplyResult(
                        inserted: 0,
                        updated: 0,
                        suppliersCreated: 0,
                        categoriesCreated: 0
                    )
                }
            }

            localApplyProgressMessage = L("options.supabase.manualSync.progress.downloadingPrices")
            updateProgress(
                phase: .downloadingPriceHistory,
                domain: .prices,
                message: L("options.supabase.manualSync.progress.downloadingPrices"),
                detailMessage: nil,
                isBlockingApply: true,
                allowsLocalWork: true
            )
            let priceSummary = try await applyProductPricesIfNeeded()
            let historySummary = await syncHistorySessionsIfAvailable()
            var baselineCommitted = false
            var baselineCommitFailed = false
            if let preview,
               let context = localApplyContext,
               let ownerID = currentLocalApplyOwnerID?() {
                do {
                    updateProgress(
                        phase: .applyingLocalDatabase,
                        domain: .catalog,
                        message: L("options.supabase.manualSync.progress.savingBaseline"),
                        detailMessage: nil,
                        canCancel: false,
                        isBlockingApply: true,
                        allowsLocalWork: true
                    )
                    try localApplyBaselineCommitter.commitSuccessfulFullPullApply(
                        preview: preview,
                        context: context,
                        ownerUserID: ownerID
                    )
                    baselineCommitted = true
                } catch {
                    baselineCommitFailed = true
                }
            }
            let summary = SupabaseManualSyncLocalApplySummary(
                productsAdded: catalogResult.inserted,
                productsUpdated: catalogResult.updated,
                suppliersCreated: catalogResult.suppliersCreated,
                categoriesCreated: catalogResult.categoriesCreated,
                priceSummary: priceSummary,
                baselineCommitted: baselineCommitted,
                baselineCommitFailed: baselineCommitFailed
            )

            invalidateLocalApplyStaging(clearSummary: false)
            invalidateCatalogPushPlan(clearSummary: true)
            invalidateProductPriceApplyPlan(clearSummary: false)
            invalidateProductPricePushPlan(clearSummary: false)
            isApplyingLocalChanges = false
            localApplyProgressMessage = nil
            finishProgress(
                warnings: baselineCommitFailed || historySummary.hasWarnings,
                detailMessage: historySummary.totalChanged > 0
                    ? L("options.supabase.manualSync.progress.detail.historyChanged", historySummary.totalChanged)
                    : nil
            )
            lastSummary = nil
            lastLocalApplySummary = summary
            presentationKind = .localApplyCompleted
            title = L("options.supabase.manualSync.state.applied.title")
            subtitle = L("options.supabase.manualSync.state.applied.subtitle")
            primaryActionTitle = Copy.startAction
            semiAutomaticState = .noChanges
            completeLifecycleRunIfVerified(lifecycleRunID)
            await prepareActivityRegistrationAfterDataStep()
        } catch is CancellationError {
            invalidateLocalApplyStaging(reason: L("options.supabase.manualSync.lifecycle.interrupted.subtitle"), clearSummary: true)
            isApplyingLocalChanges = false
            localApplyProgressMessage = nil
            cancelProgress()
            lastSummary = nil
            markLifecycleInterrupted(runID: lifecycleRunID, reason: .cancelledBeforeWrite)
        } catch {
            let reason = localApplyBlockedMessage(for: error, failureContext: true)
            invalidateLocalApplyStaging(reason: reason, clearSummary: true)
            isApplyingLocalChanges = false
            localApplyProgressMessage = nil
            failProgress(message: reason)
            lastSummary = nil
            presentationKind = .localApplyFailed
            title = L("options.supabase.manualSync.state.applyFailed.title")
            subtitle = reason
            primaryActionTitle = Copy.dismissOrRetryAction
            semiAutomaticState = .recoverableError
            markLifecycleInterrupted(runID: lifecycleRunID, reason: .cancelledBeforeWrite)
        }
    }

    private enum LocalApplyInternalError: Error {
        case dependenciesUnavailable
    }

    private func refreshLocalApplyEligibility(from summary: SupabaseManualSyncRunSummary) {
        guard let remotePreviewSummary = summary.remotePreviewSummary else {
            invalidateLocalApplyStaging()
            refreshCombinedLocalApplyEligibility()
            return
        }

        guard !remotePreviewSummary.wasCancelled,
              remotePreviewSummary.failureCategory == nil else {
            invalidateLocalApplyStaging()
            refreshCombinedLocalApplyEligibility()
            return
        }

        guard remotePreviewSummary.isComplete,
              !remotePreviewSummary.isPartial else {
            invalidateLocalApplyStaging(reason: L("options.supabase.manualSync.apply.blocked.incompleteCheck"))
            refreshCombinedLocalApplyEligibility()
            return
        }

        guard let preview = remotePreviewStaging?.stagedPreviewForLocalApply else {
            let reasonKey = remotePreviewSummary.hasRemoteSignals
                ? "options.supabase.manualSync.apply.blocked.refreshRequired"
                : "options.supabase.manualSync.apply.blocked.noChanges"
            invalidateLocalApplyStaging(reason: L(reasonKey))
            refreshCombinedLocalApplyEligibility()
            return
        }

        do {
            _ = try prepareLocalApplyPlan(from: preview)
            stagedLocalApplyOwnerID = currentLocalApplyOwnerID?()
            hasStagedLocalApplyOwnerID = true
            canApplyCatalogChanges = true
            applyBlockedReason = nil
        } catch {
            canApplyCatalogChanges = false
            invalidateLocalApplyStaging(reason: localApplyBlockedMessage(for: error))
        }
        refreshCombinedLocalApplyEligibility()
    }

    private func prepareLocalApplyPlan(from preview: SyncPreview) throws -> SupabasePullApplyPlan {
        guard let context = localApplyContext,
              let service = localApplyService else {
            throw LocalApplyInternalError.dependenciesUnavailable
        }

        return try service.prepareApplyPlan(
            preview: preview,
            context: context,
            options: SupabasePullApplyOptions(),
            isAuthenticated: isLocalApplyAuthenticated?() ?? authPresentationContext.isSignedIn,
            accountGuard: SupabasePullApplyAccountGuard(
                currentUserID: currentLocalApplyOwnerID?(),
                lastLinkedUserID: stagedLocalApplyOwnerID ?? currentLocalApplyOwnerID?()
            )
        )
    }

    private func validateLocalApplyOwnerStillCurrent() throws {
        guard hasStagedLocalApplyOwnerID else { return }
        guard currentLocalApplyOwnerID?() == stagedLocalApplyOwnerID else {
            throw SupabasePullApplyError.previewStale
        }
    }

    private func invalidateLocalApplyStaging(
        reason: String? = nil,
        clearSummary: Bool = false
    ) {
        remotePreviewStaging?.clearStagedPreviewForLocalApply()
        stagedLocalApplyOwnerID = nil
        hasStagedLocalApplyOwnerID = false
        canApplyCatalogChanges = false
        applyBlockedReason = reason
        if clearSummary {
            lastLocalApplySummary = nil
        }
        refreshCombinedLocalApplyEligibility(fallbackReason: reason)
    }

    private func refreshCombinedLocalApplyEligibility(fallbackReason: String? = nil) {
        canApplyLocalChanges = canApplyCatalogChanges || canApplyProductPriceChanges
        if canApplyLocalChanges {
            applyBlockedReason = nil
        } else if let fallbackReason {
            applyBlockedReason = fallbackReason
        }
    }

    private func prepareActivityRegistrationIfNeeded(after summary: SupabaseManualSyncRunSummary) async {
        guard shouldPrepareActivityRegistration(after: summary) else {
            invalidateActivityRegistration(clearSummary: false)
            return
        }
        await loadActivityRegistrationSnapshot()
    }

    private func prepareActivityRegistrationAfterDataStep() async {
        guard capabilities.supportsActivityRegistration else {
            invalidateActivityRegistration(clearSummary: false)
            return
        }
        await loadActivityRegistrationSnapshot()
    }

    private func shouldPrepareActivityRegistration(after summary: SupabaseManualSyncRunSummary) -> Bool {
        guard capabilities.supportsActivityRegistration else {
            return false
        }
        guard summary.countsSnapshot.pendingQueuedCloudOperationCount > 0 else {
            return false
        }
        guard let remotePreviewSummary = summary.remotePreviewSummary else {
            return false
        }
        guard remotePreviewSummary.isComplete,
              !remotePreviewSummary.isPartial,
              !remotePreviewSummary.wasCancelled,
              remotePreviewSummary.failureCategory == nil else {
            return false
        }
        return true
    }

    private func loadActivityRegistrationSnapshot() async {
        guard capabilities.supportsActivityRegistration,
              let activityRegistrationProvider else {
            invalidateActivityRegistration(clearSummary: false)
            return
        }
        guard authPresentationContext.isSignedIn,
              let ownerUserID = currentActivityRegistrationOwnerID?() else {
            applyActivityRegistrationResult(SupabaseManualSyncActivityRegistrationResult(
                status: .authRequired,
                summary: .empty
            ))
            return
        }

        do {
            let snapshot = try await activityRegistrationProvider.loadActivityRegistrationSnapshot(ownerUserID: ownerUserID)
            guard !Task.isCancelled else { return }
            applyActivityRegistrationSnapshot(snapshot)
        } catch {
            guard !Task.isCancelled else { return }
            applyActivityRegistrationResult(SupabaseManualSyncActivityRegistrationResult(
                status: .retryableFailure,
                summary: activityRegistrationSummaryForCurrentPhase()
            ))
        }
    }

    private func applyActivityRegistrationSnapshot(_ snapshot: SupabaseManualSyncActivityRegistrationSnapshot) {
        guard snapshot.hasAnyActivity else {
            activityRegistrationPhase = .idle
            return
        }

        if snapshot.readyToRegister > 0 {
            activityRegistrationPhase = .ready(snapshot)
            promoteActivityRegistrationIfNoDataAction()
            return
        }

        let summary = SupabaseManualSyncActivityRegistrationSummary(
            registered: 0,
            waiting: snapshot.waiting,
            notRegisterable: snapshot.notRegisterable
        )
        let status: SupabaseManualSyncActivityRegistrationStatus = {
            if snapshot.notRegisterable > 0 {
                return .blocked
            }
            if snapshot.waiting > 0 {
                return .retryableFailure
            }
            return .empty
        }()
        applyActivityRegistrationResult(SupabaseManualSyncActivityRegistrationResult(
            status: status,
            summary: summary
        ))
    }

    private func promoteActivityRegistrationIfNoDataAction() {
        guard !hasPendingDataActionBeforeActivityRegistration else { return }
        presentationKind = .activityRegistrationReady
        title = L("options.supabase.manualSync.activity.state.ready.title")
        subtitle = L("options.supabase.manualSync.activity.state.ready.subtitle")
        primaryActionTitle = L("options.supabase.manualSync.action.review")
    }

    private var hasPendingDataActionBeforeActivityRegistration: Bool {
        if canApplyLocalChanges {
            return true
        }
        switch catalogPushPhase {
        case .checking, .ready, .blocked, .sending:
            return true
        case .idle, .noChanges, .failed, .stale, .succeeded, .succeededNeedsCheck, .partial, .sendBlocked, .sendFailed:
            break
        }
        switch productPricePushPhase {
        case .checking, .ready, .blocked, .sending:
            return true
        case .idle, .noChanges, .failed, .stale, .succeeded, .partial, .sendFailed:
            break
        }
        return false
    }

    func confirmActivityRegistration() async {
        await registerActivitiesIfNeeded()
    }

    func retryActivityRegistration() async {
        await registerActivitiesIfNeeded()
    }

    private func registerActivitiesIfNeeded() async {
        guard !isRegisteringActivities else { return }
        guard activityRegistrationPhase.hasRegisterAction else { return }
        guard let lifecycleRunID = beginLifecycleRun(kind: .drainOutbox, source: .releaseSheet) else { return }
        guard capabilities.supportsActivityRegistration,
              let activityRegistrationProvider else {
            applyActivityRegistrationResult(SupabaseManualSyncActivityRegistrationResult(
                status: .retryableFailure,
                summary: activityRegistrationSummaryForCurrentPhase()
            ))
            markLifecycleInterrupted(runID: lifecycleRunID, reason: .cancelledBeforeWrite)
            return
        }
        guard authPresentationContext.isSignedIn,
              let ownerUserID = currentActivityRegistrationOwnerID?() else {
            applyActivityRegistrationResult(SupabaseManualSyncActivityRegistrationResult(
                status: .authRequired,
                summary: activityRegistrationSummaryForCurrentPhase()
            ))
            lifecycleProcessState = lifecycleRunGate.markBlocked(
                runID: lifecycleRunID,
                kind: .drainOutbox,
                source: .releaseSheet,
                reason: .authMissing
            )
            return
        }

        isRegisteringActivities = true
        let snapshot = activityRegistrationSnapshotForCurrentPhase()
        activityRegistrationPhase = .registering(snapshot)
        updateProgress(
            phase: .drainingSyncEvents,
            domain: .outbox,
            current: 0,
            total: snapshot.readyToRegister,
            message: L("options.supabase.manualSync.progress.drainingSyncEvents"),
            detailMessage: nil,
            isBlockingApply: false,
            allowsLocalWork: true
        )
        await Task.yield()

        do {
            let result = try await activityRegistrationProvider.registerActivities(ownerUserID: ownerUserID)
            guard !Task.isCancelled else { throw CancellationError() }
            isRegisteringActivities = false
            applyActivityRegistrationResult(result)
            finishProgress(
                warnings: result.status != .success && result.status != .empty,
                message: L("options.supabase.manualSync.progress.completed")
            )
            if result.status == .success || result.status == .empty {
                completeLifecycleRunIfVerified(lifecycleRunID)
            } else {
                markLifecycleInterrupted(runID: lifecycleRunID, reason: .remoteWriteUnverified)
            }
        } catch is CancellationError {
            isRegisteringActivities = false
            cancelProgress()
            applyActivityRegistrationResult(SupabaseManualSyncActivityRegistrationResult(
                status: .cancelled,
                summary: activityRegistrationSummaryForCurrentPhase()
            ))
            markLifecycleInterrupted(runID: lifecycleRunID, reason: .remoteWriteUnverified)
        } catch {
            isRegisteringActivities = false
            failProgress()
            applyActivityRegistrationResult(SupabaseManualSyncActivityRegistrationResult(
                status: .retryableFailure,
                summary: activityRegistrationSummaryForCurrentPhase()
            ))
            markLifecycleInterrupted(runID: lifecycleRunID, reason: .remoteWriteUnverified)
        }
    }

    private func applyActivityRegistrationResult(_ result: SupabaseManualSyncActivityRegistrationResult) {
        activityRegistrationPhase = .finished(result.status, result.summary)
        updateLastSummaryActivityCount(result.summary.waiting + result.summary.notRegisterable)

        switch result.status {
        case .success:
            presentationKind = .activityRegistrationSucceeded
            semiAutomaticState = .noChanges
        case .empty:
            presentationKind = .activityRegistrationEmpty
            semiAutomaticState = .noChanges
        case .partialRetryable:
            presentationKind = .activityRegistrationPartiallySucceeded
            semiAutomaticState = .recoverableError
        case .authRequired:
            presentationKind = .activityRegistrationAuthRequired
            semiAutomaticState = .blockedAuth
        case .retryableFailure:
            presentationKind = .activityRegistrationRetryableFailure
            semiAutomaticState = .recoverableError
        case .blocked:
            presentationKind = .activityRegistrationBlocked
            semiAutomaticState = .recoverableError
        case .cancelled:
            presentationKind = .activityRegistrationCancelled
            semiAutomaticState = .idle
        }
        title = activityRegistrationTitle(for: result.status)
        subtitle = activityRegistrationSubtitle(for: result.status)
        primaryActionTitle = result.status == .partialRetryable || result.status == .retryableFailure
            ? L("options.supabase.manualSync.action.retry")
            : Copy.startAction
    }

    private func updateLastSummaryActivityCount(_ count: Int) {
        guard var summary = lastSummary else { return }
        summary.countsSnapshot.pendingQueuedCloudOperationCount = max(0, count)
        lastSummary = summary
    }

    private func activityRegistrationTitle(
        for status: SupabaseManualSyncActivityRegistrationStatus
    ) -> String {
        L(activityRegistrationStateTitleKey(for: status))
    }

    private func activityRegistrationSubtitle(
        for status: SupabaseManualSyncActivityRegistrationStatus
    ) -> String {
        L(activityRegistrationStateSubtitleKey(for: status))
    }

    private func activityRegistrationStateTitleKey(
        for status: SupabaseManualSyncActivityRegistrationStatus
    ) -> String {
        switch status {
        case .success:
            return "options.supabase.manualSync.activity.state.success.title"
        case .empty:
            return "options.supabase.manualSync.activity.state.empty.title"
        case .partialRetryable:
            return "options.supabase.manualSync.activity.state.partial.title"
        case .authRequired:
            return "options.supabase.manualSync.activity.state.auth.title"
        case .retryableFailure:
            return "options.supabase.manualSync.activity.state.failed.title"
        case .blocked:
            return "options.supabase.manualSync.activity.state.blocked.title"
        case .cancelled:
            return "options.supabase.manualSync.activity.state.cancelled.title"
        }
    }

    private func activityRegistrationStateSubtitleKey(
        for status: SupabaseManualSyncActivityRegistrationStatus
    ) -> String {
        switch status {
        case .success:
            return "options.supabase.manualSync.activity.state.success.subtitle"
        case .empty:
            return "options.supabase.manualSync.activity.state.empty.subtitle"
        case .partialRetryable:
            return "options.supabase.manualSync.activity.state.partial.subtitle"
        case .authRequired:
            return "options.supabase.manualSync.activity.state.auth.subtitle"
        case .retryableFailure:
            return "options.supabase.manualSync.activity.state.failed.subtitle"
        case .blocked:
            return "options.supabase.manualSync.activity.state.blocked.subtitle"
        case .cancelled:
            return "options.supabase.manualSync.activity.state.cancelled.subtitle"
        }
    }

    private func activityRegistrationBadgeKey(
        for status: SupabaseManualSyncActivityRegistrationStatus
    ) -> String {
        switch status {
        case .success:
            return "options.supabase.manualSync.badge.sent"
        case .empty:
            return "options.supabase.manualSync.badge.noChanges"
        case .partialRetryable, .retryableFailure, .cancelled:
            return "options.supabase.manualSync.badge.retry"
        case .authRequired:
            return "options.supabase.manualSync.badge.needsAccess"
        case .blocked:
            return "options.supabase.manualSync.badge.needsFix"
        }
    }

    private func activityRegistrationBadgeSystemImage(
        for status: SupabaseManualSyncActivityRegistrationStatus
    ) -> String {
        switch status {
        case .success:
            return "checkmark.circle.fill"
        case .empty:
            return "tray"
        case .partialRetryable, .retryableFailure:
            return "exclamationmark.triangle.fill"
        case .authRequired:
            return "lock.fill"
        case .blocked:
            return "xmark.octagon.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    private func invalidateActivityRegistration(clearSummary: Bool = false) {
        activityRegistrationPhase = .idle
        isRegisteringActivities = false
        if clearSummary {
            updateLastSummaryActivityCount(0)
        }
    }

    private func activityRegistrationSnapshotForCurrentPhase() -> SupabaseManualSyncActivityRegistrationSnapshot {
        switch activityRegistrationPhase {
        case .ready(let snapshot), .registering(let snapshot):
            return snapshot
        case .finished(_, let summary):
            return SupabaseManualSyncActivityRegistrationSnapshot(
                readyToRegister: summary.waiting,
                waiting: summary.waiting,
                notRegisterable: summary.notRegisterable
            )
        case .idle:
            return .empty
        }
    }

    private func activityRegistrationSummaryForCurrentPhase() -> SupabaseManualSyncActivityRegistrationSummary {
        switch activityRegistrationPhase {
        case .finished(_, let summary):
            return summary
        case .ready(let snapshot), .registering(let snapshot):
            return SupabaseManualSyncActivityRegistrationSummary(
                registered: 0,
                waiting: snapshot.waiting,
                notRegisterable: snapshot.notRegisterable
            )
        case .idle:
            return .empty
        }
    }

    private func prepareProductPricePlansIfNeeded(after summary: SupabaseManualSyncRunSummary) async {
        stagedProductPriceApplyPlan = nil
        stagedProductPriceApplyFingerprint = nil
        stagedProductPricePushPlan = nil
        stagedProductPricePushFingerprint = nil
        canApplyProductPriceChanges = false
        productPriceSummary = .empty
        productPricePushPhase = .idle
        refreshCombinedLocalApplyEligibility()

        await prepareProductPriceApplyPlanIfNeeded(after: summary)
        await prepareProductPricePushPlanIfNeeded(after: summary)
    }

    private func prepareProductPriceApplyPlanIfNeeded(after summary: SupabaseManualSyncRunSummary) async {
        guard capabilities.supportsProductPriceSync,
              let productPriceProvider,
              shouldPrepareProductPricePlan(after: summary) else {
            invalidateProductPriceApplyPlan(clearSummary: false)
            return
        }
        guard let ownerUserID = currentProductPriceOwnerID?(),
              authPresentationContext.isSignedIn else {
            productPriceSummary.blocked += 1
            invalidateProductPriceApplyPlan(clearSummary: false)
            return
        }

        do {
            let plan = try await productPriceProvider.makeApplyPlan(ownerUserID: ownerUserID)
            guard !Task.isCancelled else { return }
            stagedProductPriceApplyPlan = plan
            stagedProductPriceApplyFingerprint = productPriceApplyFingerprint(plan)
            let canDeferUnmappedPrices = canDeferUnmappedProductPricesUntilCatalogApply(
                plan,
                after: summary
            )
            let applySummary = makeProductPriceSummary(
                applyPlan: plan,
                deferUnmappedProductsUntilCatalogApply: canDeferUnmappedPrices
            )
            productPriceSummary = productPriceSummary.merging(applySummary)
            canApplyProductPriceChanges = plan.isApplyAllowed || canDeferUnmappedPrices
            refreshCombinedLocalApplyEligibility()
            if canApplyProductPriceChanges {
                presentationKind = .partialSync
                title = Copy.localPendingNeedsReviewTitle
                subtitle = Copy.localPendingNeedsReviewSubtitle
                primaryActionTitle = Copy.startAction
            }
        } catch {
            guard !Task.isCancelled else { return }
            productPriceSummary.failed += 1
            invalidateProductPriceApplyPlan(clearSummary: false)
        }
    }

    private func prepareProductPricePushPlanIfNeeded(after summary: SupabaseManualSyncRunSummary) async {
        guard capabilities.supportsProductPriceSync,
              let productPriceProvider,
              shouldPrepareProductPricePlan(after: summary) else {
            invalidateProductPricePushPlan(clearSummary: false)
            return
        }
        guard let ownerUserID = currentProductPriceOwnerID?(),
              authPresentationContext.isSignedIn else {
            productPriceSummary.blocked += 1
            invalidateProductPricePushPlan(clearSummary: false)
            return
        }

        productPricePushPhase = .checking
        do {
            let plan = try await productPriceProvider.makePushPlan(ownerUserID: ownerUserID)
            guard !Task.isCancelled else { return }
            applyProductPricePushPlan(plan)
        } catch {
            guard !Task.isCancelled else { return }
            productPriceSummary.failed += 1
            productPricePushPhase = .failed(productPriceSummary)
            stagedProductPricePushPlan = nil
            stagedProductPricePushFingerprint = nil
        }
    }

    private func shouldPrepareProductPricePlan(after summary: SupabaseManualSyncRunSummary) -> Bool {
        guard let remotePreviewSummary = summary.remotePreviewSummary else {
            return false
        }
        guard remotePreviewSummary.isComplete,
              !remotePreviewSummary.isPartial,
              !remotePreviewSummary.wasCancelled,
              remotePreviewSummary.failureCategory == nil else {
            return false
        }
        return true
    }

    private func applyProductPricePushPlan(_ plan: ProductPricePushDryRunPlan) {
        let pushSummary = makeProductPriceSummary(pushPlan: plan)
        productPriceSummary = productPriceSummary.merging(pushSummary)
        stagedProductPricePushPlan = plan
        stagedProductPricePushFingerprint = productPricePushFingerprint(plan)

        if plan.summary.readyCandidates > 0, plan.isSafeForReleasePush {
            productPricePushPhase = .ready(productPriceSummary)
            if !canApplyLocalChanges, !catalogPushPhase.hasReadyCatalogChanges {
                presentationKind = .catalogPushReady
            }
        } else if pushSummary.blocked > 0 || pushSummary.skippedConflict > 0 || !plan.isRemoteDedupeSafe {
            stagedProductPricePushPlan = nil
            stagedProductPricePushFingerprint = nil
            productPricePushPhase = .blocked(productPriceSummary)
            if !canApplyLocalChanges, !catalogPushPhase.hasReadyCatalogChanges {
                presentationKind = .catalogPushBlocked
            }
        } else {
            stagedProductPricePushPlan = nil
            stagedProductPricePushFingerprint = nil
            productPricePushPhase = .noChanges(productPriceSummary)
        }
    }

    private func applyProductPricesIfNeeded() async throws -> SupabaseManualSyncProductPriceSummary {
        guard capabilities.supportsProductPriceSync,
              let productPriceProvider,
              let stagedPlan = stagedProductPriceApplyPlan else {
            return productPriceSummary
        }
        guard let ownerUserID = currentProductPriceOwnerID?(),
              authPresentationContext.isSignedIn else {
            var summary = productPriceSummary
            summary.blocked += 1
            productPriceSummary = summary
            return summary
        }

        let currentPlan = try await productPriceProvider.makeApplyPlan(ownerUserID: ownerUserID)
        let stagedFingerprint = stagedProductPriceApplyFingerprint ?? productPriceApplyFingerprint(stagedPlan)
        let currentFingerprint = productPriceApplyFingerprint(currentPlan)
        let canRefreshAfterCatalogApply = stagedPlan.blockReasons.contains(.unmappedProducts)
            && currentPlan.isApplyAllowed
        guard (currentFingerprint == stagedFingerprint || canRefreshAfterCatalogApply),
              currentPlan.isApplyAllowed else {
            var summary = productPriceSummary
            summary.readyToApply = 0
            summary.blocked += max(1, currentPlan.summary.included)
            productPriceSummary = summary
            return summary
        }

        productPriceSummary = makeProductPriceSummary(applyPlan: currentPlan)
        let result = try await productPriceProvider.apply(
            plan: currentPlan,
            ownerUserID: ownerUserID,
            onProgress: { [weak self] progress in
                self?.applyProductPriceProgress(progress)
            }
        )
        var summary = productPriceSummary.merging(makeProductPriceSummary(applyResult: result))
        summary.readyToApply = 0
        productPriceSummary = summary
        return summary
    }

    private func invalidateProductPricePlans(clearSummary: Bool = false) {
        invalidateProductPriceApplyPlan(clearSummary: clearSummary)
        invalidateProductPricePushPlan(clearSummary: clearSummary)
    }

    private func invalidateProductPriceApplyPlan(clearSummary: Bool = false) {
        stagedProductPriceApplyPlan = nil
        stagedProductPriceApplyFingerprint = nil
        canApplyProductPriceChanges = false
        if clearSummary {
            productPriceSummary = .empty
        }
        refreshCombinedLocalApplyEligibility()
    }

    private func invalidateProductPricePushPlan(clearSummary: Bool = false) {
        stagedProductPricePushPlan = nil
        stagedProductPricePushFingerprint = nil
        if clearSummary {
            productPriceSummary = .empty
        }
        if clearSummary || !productPricePushPhase.hasTerminalSummary {
            productPricePushPhase = .idle
        }
    }

    func prepareCatalogPushPlanForReview() async {
        guard let lastSummary else { return }
        await prepareCatalogPushPlanIfNeeded(after: lastSummary, force: true)
    }

    func prepareProductPricePlansForReview() async {
        guard let lastSummary else { return }
        await prepareProductPricePlansIfNeeded(after: lastSummary)
    }

    func prepareActivityRegistrationForReview() async {
        if let lastSummary {
            await prepareActivityRegistrationIfNeeded(after: lastSummary)
        } else {
            await prepareActivityRegistrationAfterDataStep()
        }
    }

    private func prepareCatalogPushPlanIfNeeded(
        after summary: SupabaseManualSyncRunSummary,
        force: Bool = false
    ) async {
        guard capabilities.supportsCatalogPush,
              let catalogPushProvider else {
            invalidateCatalogPushPlan()
            return
        }

        guard force || shouldPrepareCatalogPushPlan(after: summary) else {
            invalidateCatalogPushPlan()
            return
        }

        guard let ownerUserID = currentCatalogPushOwnerID?(),
              authPresentationContext.isSignedIn else {
            stagedCatalogPushPlan = nil
            catalogPushPhase = .failed(L("options.supabase.manualSync.push.blocked.session"))
            if !canApplyLocalChanges {
                presentationKind = .catalogPushFailed
            }
            return
        }

        catalogPushPhase = .checking
        if !canApplyLocalChanges {
            presentationKind = .catalogPushReady
        }

        do {
            let plan = try await catalogPushProvider.makePushPlan(ownerUserID: ownerUserID)
            guard !Task.isCancelled else { return }
            applyCatalogPushPlan(plan)
        } catch {
            guard !Task.isCancelled else { return }
            stagedCatalogPushPlan = nil
            catalogPushPhase = .failed(L("options.supabase.manualSync.push.summary.failedBeforeWrite"))
            if !canApplyLocalChanges {
                presentationKind = .catalogPushFailed
            }
        }
    }

    private func shouldPrepareCatalogPushPlan(after summary: SupabaseManualSyncRunSummary) -> Bool {
        guard let remotePreviewSummary = summary.remotePreviewSummary else {
            return false
        }
        guard remotePreviewSummary.isComplete,
              !remotePreviewSummary.isPartial,
              !remotePreviewSummary.wasCancelled,
              remotePreviewSummary.failureCategory == nil else {
            return false
        }
        return true
    }

    private func applyCatalogPushPlan(_ plan: ManualPushPlan) {
        let summary = makeCatalogPushSummary(from: plan)
        if plan.hasWriteOrLinkCandidates,
           plan.isSendable,
           !plan.hasBlockers {
            stagedCatalogPushPlan = plan
            catalogPushPhase = .ready(summary)
            if !canApplyLocalChanges {
                presentationKind = .catalogPushReady
            }
        } else if plan.hasBlockers {
            stagedCatalogPushPlan = nil
            catalogPushPhase = .blocked(summary)
            if !canApplyLocalChanges {
                presentationKind = .catalogPushBlocked
            }
        } else {
            stagedCatalogPushPlan = nil
            catalogPushPhase = .noChanges(summary)
            if !canApplyLocalChanges,
               lastSummary?.hasCompletedRemotePreviewSignals != true {
                presentationKind = .catalogPushNoChanges
            }
        }
    }

    func sendConfirmedCatalogChanges() async {
        guard !isSendingCatalogChanges else { return }
        guard let lifecycleRunID = beginLifecycleRun(kind: .pushAggregated, source: .releaseSheet) else { return }
        guard capabilities.supportsCatalogPush || capabilities.supportsProductPriceSync else {
            stagedCatalogPushPlan = nil
            catalogPushPhase = .sendFailed(makeCatalogPushSummary(
                from: stagedCatalogPushPlan,
                result: .blocked(message: L("options.supabase.manualSync.push.summary.failedBeforeWrite"))
            ))
            presentationKind = .catalogPushFailed
            markLifecycleInterrupted(runID: lifecycleRunID, reason: .cancelledBeforeWrite)
            return
        }
        let hasCatalogWork = stagedCatalogPushPlan?.isSendable == true
            && stagedCatalogPushPlan?.hasBlockers == false
        let hasProductPriceWork = stagedProductPricePushPlan?.isSafeForReleasePush == true
        guard hasCatalogWork || hasProductPriceWork else {
            stagedCatalogPushPlan = nil
            stagedProductPricePushPlan = nil
            stagedProductPricePushFingerprint = nil
            catalogPushPhase = .stale
            productPricePushPhase = .stale(productPriceSummary)
            presentationKind = .catalogPushStale
            markLifecycleInterrupted(runID: lifecycleRunID, reason: .cancelledBeforeWrite)
            return
        }
        guard let ownerUserID = currentCatalogPushOwnerID?(),
              authPresentationContext.isSignedIn,
              stagedCatalogPushPlan.map({ $0.ownerUserID == ownerUserID }) ?? true else {
            let result = SupabaseManualPushResult.blocked(
                message: L("options.supabase.manualSync.push.blocked.session")
            )
            stagedCatalogPushPlan = nil
            stagedProductPricePushPlan = nil
            stagedProductPricePushFingerprint = nil
            catalogPushPhase = .sendFailed(makeCatalogPushSummary(from: stagedCatalogPushPlan, result: result))
            productPricePushPhase = .sendFailed(productPriceSummary.withBlockedIncrement())
            presentationKind = .catalogPushFailed
            lifecycleProcessState = lifecycleRunGate.markBlocked(
                runID: lifecycleRunID,
                kind: .pushAggregated,
                source: .releaseSheet,
                reason: .authMissing
            )
            return
        }

        let stagedPlan = stagedCatalogPushPlan
        let sendingSummary = makeCatalogPushSummary(from: stagedPlan)
        catalogPushPhase = .sending(sendingSummary)
        if hasProductPriceWork {
            productPricePushPhase = .sending(productPriceSummary)
        }
        presentationKind = .catalogPushSending
        updateProgress(
            phase: .sendingLocalChanges,
            domain: .pending,
            current: 0,
            total: sendingSummary.readyCount + productPriceSummary.readyToPush,
            message: L("options.supabase.manualSync.progress.sendingLocalChanges"),
            detailMessage: nil,
            isBlockingApply: false,
            allowsLocalWork: true
        )
        await Task.yield()

        do {
            let catalogResult = try await executeCatalogPushIfNeeded(
                stagedPlan: stagedPlan,
                ownerUserID: ownerUserID
            )
            guard !Task.isCancelled else {
                markLifecycleInterrupted(runID: lifecycleRunID, reason: .remoteWriteUnverified)
                return
            }
            if interruptLifecycleRunIfBudgetExpired(lifecycleRunID) {
                return
            }
            let canContinueWithPrices = catalogResult.map(\.status.allowsProductPricePushAfterCatalog) ?? true
            if canContinueWithPrices {
                try await executeProductPricePushIfNeeded(ownerUserID: ownerUserID)
            } else if hasProductPriceWork {
                productPricePushPhase = .sendFailed(productPriceSummary.withBlockedIncrement())
            }
            guard !Task.isCancelled else {
                markLifecycleInterrupted(runID: lifecycleRunID, reason: .remoteWriteUnverified)
                return
            }
            if interruptLifecycleRunIfBudgetExpired(lifecycleRunID) {
                return
            }
            if let catalogResult, let currentPlan = stagedPlan {
                applyCatalogPushResult(catalogResult, plan: currentPlan)
                if productPricePushPhase.needsAttentionAfterSend {
                    catalogPushPhase = .partial(makeCatalogPushSummary(from: currentPlan, result: catalogResult))
                    presentationKind = .catalogPushPartiallySucceeded
                    semiAutomaticState = .recoverableError
                }
            } else {
                applyPriceOnlyPushPresentationAfterSend()
            }
            finishProgress(
                warnings: productPricePushPhase.needsAttentionAfterSend || catalogPushPhase.needsAttentionAfterSend,
                message: L("options.supabase.manualSync.progress.completed")
            )
            completeLifecycleAfterSendIfVerified(lifecycleRunID)
            await prepareActivityRegistrationAfterDataStep()
        } catch CatalogPushInternalError.stale {
            stagedProductPricePushPlan = nil
            stagedProductPricePushFingerprint = nil
            productPricePushPhase = .stale(productPriceSummary)
            presentationKind = .catalogPushStale
            markLifecycleInterrupted(runID: lifecycleRunID, reason: .cancelledBeforeWrite)
        } catch is CancellationError {
            cancelProgress()
            markLifecycleInterrupted(runID: lifecycleRunID, reason: .remoteWriteUnverified)
        } catch {
            guard !Task.isCancelled else {
                markLifecycleInterrupted(runID: lifecycleRunID, reason: .remoteWriteUnverified)
                return
            }
            let result = SupabaseManualPushResult.blocked(
                message: L("options.supabase.manualSync.push.summary.failedBeforeWrite")
            )
            stagedCatalogPushPlan = nil
            stagedProductPricePushPlan = nil
            stagedProductPricePushFingerprint = nil
            catalogPushPhase = .sendFailed(makeCatalogPushSummary(from: stagedPlan, result: result))
            productPricePushPhase = .sendFailed(productPriceSummary.withFailedIncrement())
            presentationKind = .catalogPushFailed
            failProgress(message: L("options.supabase.manualSync.progress.failed"))
            markLifecycleInterrupted(runID: lifecycleRunID, reason: .remoteWriteUnverified)
        }
    }

    private func completeLifecycleAfterSendIfVerified(_ runID: UUID) {
        switch catalogPushPhase {
        case .succeeded, .succeededNeedsCheck:
            if productPricePushPhase.needsAttentionAfterSend {
                markLifecycleInterrupted(runID: runID, reason: .remoteWriteUnverified)
            } else {
                completeLifecycleRunIfVerified(runID)
            }
        case .noChanges:
            switch productPricePushPhase {
            case .succeeded:
                completeLifecycleRunIfVerified(runID)
            default:
                markLifecycleInterrupted(runID: runID, reason: .remoteWriteUnverified)
            }
        case .idle, .checking, .ready, .blocked, .failed, .stale, .sending, .partial, .sendBlocked, .sendFailed:
            markLifecycleInterrupted(runID: runID, reason: .remoteWriteUnverified)
        }
    }

    private func executeCatalogPushIfNeeded(
        stagedPlan: ManualPushPlan?,
        ownerUserID: UUID
    ) async throws -> SupabaseManualPushResult? {
        guard let stagedPlan else { return nil }
        guard let catalogPushProvider else {
            return .blocked(message: L("options.supabase.manualSync.push.summary.failedBeforeWrite"))
        }

        let currentPlan = try await catalogPushProvider.makePushPlan(ownerUserID: ownerUserID)
        guard currentPlan.planFingerprint == stagedPlan.planFingerprint,
              currentPlan.isSendable,
              !currentPlan.hasBlockers else {
            stagedCatalogPushPlan = nil
            catalogPushPhase = .stale
            presentationKind = .catalogPushStale
            throw CatalogPushInternalError.stale
        }
        guard let latestOwnerUserID = currentCatalogPushOwnerID?(),
              authPresentationContext.isSignedIn,
              latestOwnerUserID == ownerUserID,
              currentPlan.ownerUserID == ownerUserID else {
            stagedCatalogPushPlan = nil
            return .failedBeforeWrite(message: L("options.supabase.manualSync.push.blocked.session"))
        }

        let result = await catalogPushProvider.execute(plan: currentPlan, ownerUserID: ownerUserID)
        stagedCatalogPushPlan = nil
        return result
    }

    private enum CatalogPushInternalError: Error {
        case stale
    }

    private func executeProductPricePushIfNeeded(ownerUserID: UUID) async throws {
        guard let stagedPlan = stagedProductPricePushPlan,
              let stagedFingerprint = stagedProductPricePushFingerprint,
              let productPriceProvider else {
            return
        }
        guard currentProductPriceOwnerID?() == ownerUserID,
              authPresentationContext.isSignedIn else {
            stagedProductPricePushPlan = nil
            stagedProductPricePushFingerprint = nil
            productPricePushPhase = .sendFailed(productPriceSummary.withBlockedIncrement())
            return
        }

        let currentPlan = try await productPriceProvider.makePushPlan(ownerUserID: ownerUserID)
        guard productPricePushFingerprint(currentPlan) == stagedFingerprint,
              currentPlan.isSafeForReleasePush else {
            stagedProductPricePushPlan = nil
            stagedProductPricePushFingerprint = nil
            productPricePushPhase = .stale(productPriceSummary)
            presentationKind = .catalogPushStale
            return
        }

        let result = try await productPriceProvider.push(plan: currentPlan, ownerUserID: ownerUserID)
        stagedProductPricePushPlan = nil
        stagedProductPricePushFingerprint = nil
        applyProductPricePushResult(result, candidateCount: stagedPlan.summary.readyCandidates)
    }

    private func applyProductPricePushResult(_ result: ProductPriceManualPushResult, candidateCount: Int) {
        var summary = productPriceSummary
        summary.readyToPush = 0
        summary.pushed += result.insertedCount
        switch result.verification {
        case .exactMatch:
            if result.needsTechnicalFollowUp {
                summary.failed += 1
                productPriceSummary = summary
                productPricePushPhase = .partial(summary)
            } else {
                productPriceSummary = summary
                productPricePushPhase = .succeeded(summary)
            }
        case .unknown, .missingRows, .mismatchedRows:
            summary.failed += max(1, candidateCount - result.insertedCount)
            productPriceSummary = summary
            productPricePushPhase = .partial(summary)
        }
    }

    private func applyPriceOnlyPushPresentationAfterSend() {
        switch productPricePushPhase {
        case .succeeded:
            catalogPushPhase = .succeeded(makeCatalogPushSummary(from: Optional<ManualPushPlan>.none))
            presentationKind = .catalogPushSucceeded
        case .partial:
            catalogPushPhase = .partial(makeCatalogPushSummary(from: Optional<ManualPushPlan>.none))
            presentationKind = .catalogPushPartiallySucceeded
        case .stale:
            catalogPushPhase = .stale
            presentationKind = .catalogPushStale
        case .sendFailed:
            catalogPushPhase = .sendFailed(makeCatalogPushSummary(from: Optional<ManualPushPlan>.none))
            presentationKind = .catalogPushFailed
        case .idle, .checking, .ready, .noChanges, .blocked, .failed, .sending:
            break
        }
    }

    private func applyCatalogPushResult(
        _ result: SupabaseManualPushResult,
        plan: ManualPushPlan
    ) {
        let summary = makeCatalogPushSummary(from: plan, result: result)
        switch result.status {
        case .completed:
            catalogPushPhase = .succeeded(summary)
            presentationKind = .catalogPushSucceeded
            semiAutomaticState = .noChanges
        case .completedBaselineRefreshFailed:
            catalogPushPhase = .succeededNeedsCheck(summary)
            presentationKind = .catalogPushSucceeded
            semiAutomaticState = .noChanges
        case .partial:
            catalogPushPhase = .partial(summary)
            presentationKind = .catalogPushPartiallySucceeded
            semiAutomaticState = .recoverableError
        case .blockedBeforeWrite:
            catalogPushPhase = .sendBlocked(summary)
            presentationKind = .catalogPushBlocked
            semiAutomaticState = .recoverableError
        case .failedBeforeWrite:
            catalogPushPhase = .sendFailed(summary)
            presentationKind = .catalogPushFailed
            semiAutomaticState = .recoverableError
        }
    }

    private func invalidateCatalogPushPlan(clearSummary: Bool = false) {
        stagedCatalogPushPlan = nil
        if clearSummary || !hasTerminalCatalogPushSummary {
            catalogPushPhase = .idle
        }
    }

    private func makeCatalogPushSummary(
        from plan: ManualPushPlan?,
        result: SupabaseManualPushResult? = nil
    ) -> SupabaseManualSyncCatalogPushSummary {
        guard let plan else {
            return SupabaseManualSyncCatalogPushSummary(
                readyCount: 0,
                createCount: 0,
                updateCount: 0,
                linkCount: 0,
                blockerCount: 0,
                warningCount: 0,
                futureOnlyCount: 0,
                planFingerprint: nil,
                resultStatus: result?.status,
                resultMessage: result?.message
            )
        }
        return makeCatalogPushSummary(from: plan, result: result)
    }

    private func makeCatalogPushSummary(
        from plan: ManualPushPlan,
        result: SupabaseManualPushResult? = nil
    ) -> SupabaseManualSyncCatalogPushSummary {
        let createCount = plan.writeCandidates.filter { $0.action == .dryRunCreateCandidate }.count
        let updateCount = plan.writeCandidates.filter { $0.action == .dryRunUpdateCandidate }.count
        let linkCount = plan.writeCandidates.filter { $0.action == .dryRunLinkCandidate }.count
        return SupabaseManualSyncCatalogPushSummary(
            readyCount: plan.writeCandidates.count,
            createCount: createCount,
            updateCount: updateCount,
            linkCount: linkCount,
            blockerCount: plan.blockedReasons.count,
            warningCount: plan.warnings.filter { $0.severity == .warning }.count,
            futureOnlyCount: plan.candidates.filter { $0.severity == .futureOnly }.count
                + plan.warnings.filter { $0.severity == .futureOnly }.count,
            planFingerprint: plan.planFingerprint,
            resultStatus: result?.status,
            resultMessage: result?.message
        )
    }

    private func canDeferUnmappedProductPricesUntilCatalogApply(
        _ plan: ProductPriceApplyPlan,
        after summary: SupabaseManualSyncRunSummary
    ) -> Bool {
        guard plan.sourceState.sampled,
              let aggregateCounts = summary.remotePreviewSummary?.safeAggregateCounts,
              aggregateCounts.newProductCount + aggregateCounts.updateCandidateCount > 0 else {
            return false
        }
        let blockingReasons = Set(plan.blockReasons.filter { $0 != .noApplicableRows })
        return blockingReasons == [.unmappedProducts]
    }

    private func makeProductPriceSummary(
        applyPlan plan: ProductPriceApplyPlan,
        deferUnmappedProductsUntilCatalogApply: Bool = false
    ) -> SupabaseManualSyncProductPriceSummary {
        let sourceBlocked = (plan.summary.partial ? 1 : 0)
            + (plan.summary.truncated ? 1 : 0)
        let accessOrSyncFailed = plan.summary.sourceError == nil ? 0 : 1
        let readyToApply = (plan.isApplyAllowed || deferUnmappedProductsUntilCatalogApply)
            ? max(plan.linesToInsert.count + plan.remoteIdentityLinks.count, plan.sourceState.sampled ? 1 : 0)
            : 0
        let unmappedBlocked = deferUnmappedProductsUntilCatalogApply ? 0 : plan.summary.unmapped
        return SupabaseManualSyncProductPriceSummary(
            remoteFound: plan.summary.remoteRead,
            localFound: productPriceSummary.localFound,
            readyToApply: readyToApply,
            readyToPush: productPriceSummary.readyToPush,
            applied: 0,
            pushed: 0,
            skippedDuplicate: plan.summary.skippedExisting,
            skippedConflict: plan.summary.conflicts,
            failed: accessOrSyncFailed,
            blocked: unmappedBlocked + plan.summary.invalid + sourceBlocked
        )
    }

    private func makeProductPriceSummary(applyResult result: ProductPriceApplyResult) -> SupabaseManualSyncProductPriceSummary {
        SupabaseManualSyncProductPriceSummary(
            remoteFound: productPriceSummary.remoteFound,
            localFound: productPriceSummary.localFound,
            readyToApply: 0,
            readyToPush: productPriceSummary.readyToPush,
            applied: result.inserted,
            pushed: 0,
            skippedDuplicate: result.skippedExisting,
            skippedConflict: 0,
            failed: 0,
            blocked: 0
        )
    }

    private func makeProductPriceSummary(pushPlan plan: ProductPricePushDryRunPlan) -> SupabaseManualSyncProductPriceSummary {
        let unsafeRemoteDedupeBlock = plan.isRemoteDedupeSafe ? 0 : max(1, plan.summary.localPriceCount)
        let accessOrSyncFailed = plan.remoteDedupeStatus.accessOrSyncFailureCount
        return SupabaseManualSyncProductPriceSummary(
            remoteFound: productPriceSummary.remoteFound,
            localFound: plan.summary.localPriceCount,
            readyToApply: productPriceSummary.readyToApply,
            readyToPush: plan.isSafeForReleasePush ? plan.summary.readyCandidates : 0,
            applied: 0,
            pushed: 0,
            skippedDuplicate: plan.summary.alreadyPresentRemote + plan.summary.localDuplicateSameKey,
            skippedConflict: plan.summary.conflictSameKeyDifferentPrice + plan.summary.localConflictSameKeyDifferentPrice,
            failed: accessOrSyncFailed,
            blocked: plan.summary.blockedTotal + plan.summary.excludedInvalidLocal + unsafeRemoteDedupeBlock
        )
    }

    private func productPriceApplyFingerprint(_ plan: ProductPriceApplyPlan) -> String {
        let lines = plan.linesToInsert.map {
            [
                $0.productID.uuidString.lowercased(),
                $0.type,
                $0.effectiveAtCanonical,
                $0.canonicalPrice.value
            ].joined(separator: "|")
        }
        let blockReasons = plan.blockReasons.map(\.rawValue).sorted()
        let summary = [
            "remote:\(plan.summary.remoteRead)",
            "included:\(plan.summary.included)",
            "skipped:\(plan.summary.skippedExisting)",
            "unmapped:\(plan.summary.unmapped)",
            "invalid:\(plan.summary.invalid)",
            "conflicts:\(plan.summary.conflicts)",
            "mapping:\(plan.summary.mappingConflicts)",
            "partial:\(plan.summary.partial)",
            "truncated:\(plan.summary.truncated)",
            "sampled:\(plan.sourceState.sampled)",
            "source:\(plan.summary.sourceError ?? "")"
        ]
        return (lines + blockReasons + summary).joined(separator: "\n")
    }

    private func productPriceProgressMessage(_ progress: ProductPricePagedApplyProgress) -> String {
        switch progress.stage {
        case .preparing:
            return L("options.supabase.manualSync.progress.preparing")
        case .fetching:
            if let totalRows = progress.totalRows {
                return L("options.supabase.manualSync.progress.fetchingPricesWithTotal", progress.processedRows, totalRows)
            }
            return L("options.supabase.manualSync.progress.fetchingPrices", progress.processedRows)
        case .applying:
            if let totalRows = progress.totalRows {
                return L("options.supabase.manualSync.progress.applyingPricesWithTotal", progress.processedRows, totalRows)
            }
            return L("options.supabase.manualSync.progress.applyingPrices", progress.processedRows)
        case .saving:
            if let totalRows = progress.totalRows {
                return L("options.supabase.manualSync.progress.savingPricesWithTotal", progress.processedRows, totalRows)
            }
            return L("options.supabase.manualSync.progress.savingPrices", progress.processedRows)
        case .completed:
            if let totalRows = progress.totalRows {
                return L("options.supabase.manualSync.progress.completedPricesWithTotal", progress.processedRows, totalRows)
            }
            return L("options.supabase.manualSync.progress.completedPrices", progress.processedRows)
        }
    }

    private func applyCatalogProgress(_ progress: SupabasePullApplyProgress) {
        let phase: CloudSyncProgressPhase
        let message: String
        switch progress.stage {
        case .suppliers:
            phase = .downloadingSuppliers
            message = L("options.supabase.manualSync.progress.catalogSuppliers")
        case .categories:
            phase = .downloadingCategories
            message = L("options.supabase.manualSync.progress.catalogCategories")
        case .products:
            phase = .downloadingProducts
            message = L("options.supabase.manualSync.progress.catalogProducts")
        case .saving:
            phase = .applyingLocalDatabase
            message = L("options.supabase.manualSync.progress.savingCatalog")
        case .completed:
            phase = .applyingLocalDatabase
            message = L("options.supabase.manualSync.progress.catalogCompleted")
        }
        localApplyProgressMessage = progress.total > 0
            ? L("options.supabase.manualSync.progress.catalogCount", message, progress.current, progress.total)
            : message
        updateProgress(
            phase: phase,
            domain: .catalog,
            current: progress.current,
            total: progress.total > 0 ? progress.total : nil,
            message: message,
            detailMessage: progress.total > 0
                ? L("options.supabase.manualSync.progress.countDetail", progress.current, progress.total)
                : nil,
            isBlockingApply: true,
            allowsLocalWork: true
        )
    }

    private func applyProductPriceProgress(_ progress: ProductPricePagedApplyProgress) {
        let message = productPriceProgressMessage(progress)
        localApplyProgressMessage = message
        updateProgress(
            phase: .downloadingPriceHistory,
            domain: .prices,
            current: progress.processedRows,
            total: progress.totalRows,
            message: message,
            detailMessage: progress.totalRows.map {
                L("options.supabase.manualSync.progress.countDetail", progress.processedRows, $0)
            },
            isBlockingApply: true,
            allowsLocalWork: true
        )
    }

    private func syncHistorySessionsIfAvailable() async -> SupabaseManualSyncHistorySessionSummary {
        guard let historySessionProvider else {
            return SupabaseManualSyncHistorySessionSummary()
        }
        guard authPresentationContext.isSignedIn,
              let ownerUserID = currentHistorySessionOwnerID?() else {
            return SupabaseManualSyncHistorySessionSummary(skippedDirtyLocal: 1)
        }

        updateProgress(
            phase: .syncingHistorySessions,
            domain: .history,
            message: L("options.supabase.manualSync.progress.syncingHistory"),
            detailMessage: nil,
            isBlockingApply: true,
            allowsLocalWork: true
        )
        do {
            let summary = try await historySessionProvider.syncHistorySessions(
                ownerUserID: ownerUserID,
                onProgress: { [weak self] progress in
                    self?.applyHistoryProgress(progress)
                }
            )
            historySessionSummary = summary
            return summary
        } catch {
            var summary = SupabaseManualSyncHistorySessionSummary()
            summary.skippedDirtyLocal = 1
            historySessionSummary = summary
            updateProgress(
                phase: .completedWithWarnings,
                domain: .history,
                message: L("options.supabase.manualSync.progress.historyWarning"),
                detailMessage: nil,
                canCancel: false,
                isBlockingApply: false,
                allowsLocalWork: true
            )
            return summary
        }
    }

    private func applyHistoryProgress(_ progress: HistorySessionSyncProgress) {
        let message: String
        switch progress.stage {
        case .pushing:
            message = L("options.supabase.manualSync.progress.historyPushing")
        case .fetching:
            message = L("options.supabase.manualSync.progress.historyFetching")
        case .applying:
            message = L("options.supabase.manualSync.progress.historyApplying")
        case .saving:
            message = L("options.supabase.manualSync.progress.historySaving")
        case .completed:
            message = L("options.supabase.manualSync.progress.historyCompleted")
        }
        localApplyProgressMessage = progress.total.map {
            L("options.supabase.manualSync.progress.catalogCount", message, progress.current, $0)
        } ?? L("options.supabase.manualSync.progress.currentOnly", message, progress.current)
        updateProgress(
            phase: .syncingHistorySessions,
            domain: .history,
            current: progress.current,
            total: progress.total,
            message: message,
            detailMessage: progress.total.map {
                L("options.supabase.manualSync.progress.countDetail", progress.current, $0)
            },
            isBlockingApply: true,
            allowsLocalWork: true
        )
    }

    private func productPricePushFingerprint(_ plan: ProductPricePushDryRunPlan) -> String {
        let candidates = plan.candidates.map { line -> String in
            [
                line.key?.stableID ?? "",
                line.canonicalPrice?.value ?? "",
                line.createdAtCanonical ?? "",
                line.source ?? "",
                line.note ?? ""
            ].joined(separator: "|")
        }
        let summary = [
            "local:\(plan.summary.localPriceCount)",
            "ready:\(plan.summary.readyCandidates)",
            "present:\(plan.summary.alreadyPresentRemote)",
            "remoteConflict:\(plan.summary.conflictSameKeyDifferentPrice)",
            "localDuplicate:\(plan.summary.localDuplicateSameKey)",
            "localConflict:\(plan.summary.localConflictSameKeyDifferentPrice)",
            "blockedNoRemote:\(plan.summary.blockedNoRemoteID)",
            "blockedTotal:\(plan.summary.blockedTotal)",
            "invalid:\(plan.summary.excludedInvalidLocal)",
            "dedupe:\(plan.remoteDedupeStatus.stableFingerprintComponent)"
        ]
        return (candidates + summary).joined(separator: "\n")
    }

    private func localApplyBlockedMessage(
        for error: Error,
        failureContext: Bool = false
    ) -> String {
        guard let applyError = error as? SupabasePullApplyError else {
            return failureContext
                ? L("options.supabase.manualSync.apply.blocked.saveFailed")
                : L("options.supabase.manualSync.apply.blocked.refreshRequired")
        }

        if case .saveFailed = applyError {
            return L("options.supabase.manualSync.apply.blocked.saveFailed")
        }

        switch applyError.disabledReason {
        case .sessionMissing, .accountMismatch:
            return L("options.supabase.manualSync.apply.blocked.session")
        case .partialPreview, .sourceErrorsPresent, .priceHistoryIncomplete:
            return L("options.supabase.manualSync.apply.blocked.incompleteCheck")
        case .conflictsPresent, .localDuplicateBarcode:
            return L("options.supabase.manualSync.apply.blocked.needsAttention")
        case .missingApplicablePayload, .missingRequiredField, .invalidLocalData, .invalidPrice, .invalidStockQuantity:
            return L("options.supabase.manualSync.apply.blocked.invalidData")
        case .previewStale:
            return L("options.supabase.manualSync.apply.blocked.stale")
        case .noApplicableChanges:
            return L("options.supabase.manualSync.apply.blocked.noChanges")
        }
    }

    private func summarySummarySubtitle(from summary: SupabaseManualSyncRunSummary) -> String? {
        if summary.finalState == .completedSuccessfully {
            return nonEmpty(summary.userFacingHeadline) ?? SupabaseManualSyncUserFacingCopy.syncFinishedSuccessfully
        }
        return nil
    }

    private struct BlockedInterpretation {
        let kind: SupabaseManualSyncUserPresentationKind
        let title: String
        let subtitle: String?
        let primaryActionTitle: String
    }

    private func interpretBlocked(summary: SupabaseManualSyncRunSummary) -> BlockedInterpretation {
        if summary.userFacingHeadline == SupabaseManualSyncUserFacingCopy.signInAgain {
            return BlockedInterpretation(
                kind: .blockedNeedsSignIn,
                title: SupabaseManualSyncUserFacingCopy.signInAgain,
                subtitle: subtitleCandidate(
                    summary.suggestedNextStep,
                    fallback: Copy.signInSubtitle,
                    title: SupabaseManualSyncUserFacingCopy.signInAgain
                ),
                primaryActionTitle: Copy.signInAction
            )
        }
        if summary.userFacingHeadline == SupabaseManualSyncUserFacingCopy.realignFromCloud {
            return BlockedInterpretation(
                kind: .blockedNeedsCloudRealignment,
                title: SupabaseManualSyncUserFacingCopy.realignFromCloud,
                subtitle: subtitleCandidate(
                    summary.suggestedNextStep,
                    fallback: Copy.realignSubtitle,
                    title: SupabaseManualSyncUserFacingCopy.realignFromCloud
                ),
                primaryActionTitle: Copy.realignAction
            )
        }
        return BlockedInterpretation(
            kind: .technicalFollowUpNeeded,
            title: SupabaseManualSyncUserFacingCopy.technicalFollowUp,
            subtitle: subtitleCandidate(
                summary.suggestedNextStep,
                fallback: summary.userFacingHeadline,
                title: SupabaseManualSyncUserFacingCopy.technicalFollowUp
            ),
            primaryActionTitle: Copy.dismissOrRetryAction
        )
    }

    private func nonEmpty(_ s: String?) -> String? {
        guard let t = s, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return t
    }

    private func subtitleCandidate(_ candidate: String?, fallback: String?, title: String) -> String? {
        let chosen = nonEmpty(candidate)
        if let chosen, chosen != title {
            return chosen
        }
        return nonEmpty(fallback)
    }

    func resetPresentationToIdleReady() {
        cannotStartConcurrently = false
        lastSummary = nil
        lastStartedMode = nil
        invalidateLocalApplyStaging(clearSummary: true)
        invalidateCatalogPushPlan(clearSummary: true)
        invalidateProductPricePlans(clearSummary: true)
        invalidateActivityRegistration(clearSummary: true)
        historySessionSummary = nil
        progressState = .idle()
        presentationKind = .idleReady
        semiAutomaticState = .idle
        title = Copy.idleTitle
        subtitle = Copy.idleSubtitle
        primaryActionTitle = Copy.startAction
    }

    func applyAuthPresentationContext(_ context: SupabaseManualSyncAuthPresentationContext) {
        guard authPresentationContext != context else { return }
        authPresentationContext = context
        if !context.isSignedIn {
            lastSummary = nil
            invalidateLocalApplyStaging(clearSummary: true)
            invalidateCatalogPushPlan(clearSummary: true)
            invalidateProductPricePlans(clearSummary: true)
            invalidateActivityRegistration(clearSummary: true)
            historySessionSummary = nil
            progressState = .idle()
            lastRecoverableForegroundErrorAt = nil
            SupabaseManualSyncForegroundAutomaticGate.clearRecoverableError()
            semiAutomaticState = .blockedAuth
        } else if semiAutomaticState == .blockedAuth {
            semiAutomaticState = .idle
            lastRecoverableForegroundErrorAt = nil
            SupabaseManualSyncForegroundAutomaticGate.clearRecoverableError()
        }
    }

    func runMode(for actionID: SupabaseManualSyncPresentationActionID) -> SupabaseManualSyncRunMode? {
        switch actionID {
        case .checkCloud, .downloadCloudDatabase, .syncNow:
            return capabilities.supportsRemoteCloudCheck ? .dryRun : nil
        case .reviewChanges:
            return nil
        case .sendCloudChanges:
            return nil
        case .retry, .realignData:
            return lastStartedMode ?? preferredCapabilityRunMode()
        case .signIn, .cancel:
            return nil
        }
    }

    private var shouldRecoverPermissionFailureWithCloudCheck: Bool {
        lastSummary?.remotePreviewSummary?.failureCategory == .permission
            && capabilities.supportsRemoteCloudCheck
    }

    private var currentCloudOverviewBaselineStatus: CloudSyncBaselineStatus {
        CloudSyncOverviewReducer.baselineStatus(from: baselineStatusProvider?())
    }

    private var shouldAutoApplyForegroundPreviewAfterLastCheck: Bool {
        guard currentCloudOverviewBaselineStatus == .valid else { return false }
        guard let summary = lastSummary,
              summary.countsSnapshot.hasAnyPendingWork == false,
              let remotePreviewSummary = summary.remotePreviewSummary,
              remotePreviewSummary.failureCategory == nil,
              remotePreviewSummary.isComplete,
              !remotePreviewSummary.isPartial,
              !remotePreviewSummary.wasCancelled,
              remotePreviewSummary.hasRemoteSignals,
              canApplyLocalChanges else {
            return false
        }
        return true
    }

    private func makeRootPresentationState() -> SupabaseManualSyncRootPresentationState {
        if isRunning || semiAutomaticState == .checking {
            return rootState(
                kind: .checking,
                titleKey: "options.supabase.manualSync.root.checking.title",
                detailKey: "options.supabase.manualSync.root.checking.detail",
                actionID: nil,
                systemImage: "arrow.triangle.2.circlepath",
                progressState: progressState.isActive ? progressState : nil
            )
        }

        if lifecycleShouldShowPriorityAttention {
            return rootState(
                kind: .recoverableError,
                titleKey: "options.supabase.manualSync.root.interrupted.title",
                detailKey: "options.supabase.manualSync.root.interrupted.detail",
                actionID: .reviewChanges,
                systemImage: "exclamationmark.arrow.triangle.2.circlepath"
            )
        }

        switch semiAutomaticState {
        case .changesFound, .staleOrConflict:
            return rootState(
                kind: .changesFound,
                titleKey: "options.supabase.manualSync.root.changes.title",
                detailKey: "options.supabase.manualSync.root.changes.detail",
                actionID: .reviewChanges,
                systemImage: "icloud.and.arrow.down",
                progressState: progressState.phase == .completedWithWarnings ? progressState : nil
            )
        case .blockedAuth:
            if authPresentationContext.isSignedIn {
                return rootState(
                    kind: .recoverableError,
                    titleKey: "options.supabase.manualSync.root.accountCheck.title",
                    detailKey: "options.supabase.manualSync.root.accountCheck.detail",
                    actionID: capabilities.supportsRemoteCloudCheck ? .checkCloud : nil,
                    systemImage: "person.crop.circle.badge.exclamationmark"
                )
            }
            return rootState(
                kind: .blockedAuth,
                titleKey: "options.supabase.manualSync.root.auth.title",
                detailKey: "options.supabase.manualSync.root.auth.detail",
                actionID: .signIn,
                systemImage: "lock.fill"
            )
        case .recoverableError:
            let recoverWithCloudCheck = shouldRecoverPermissionFailureWithCloudCheck
            return rootState(
                kind: .recoverableError,
                titleKey: "options.supabase.manualSync.root.error.title",
                detailKey: "options.supabase.manualSync.root.error.detail",
                actionID: recoverWithCloudCheck ? .checkCloud : .retry,
                systemImage: recoverWithCloudCheck ? "exclamationmark.icloud" : "wifi.exclamationmark"
            )
        case .idle, .suggestedCheck, .noChanges, .reviewing:
            return .hidden
        case .checking:
            return rootState(
                kind: .checking,
                titleKey: "options.supabase.manualSync.root.checking.title",
                detailKey: "options.supabase.manualSync.root.checking.detail",
                actionID: nil,
                systemImage: "arrow.triangle.2.circlepath",
                progressState: progressState.isActive ? progressState : nil
            )
        }
    }

    private func rootState(
        kind: SupabaseManualSyncRootPresentationKind,
        titleKey: String,
        detailKey: String?,
        actionID: SupabaseManualSyncPresentationActionID?,
        systemImage: String,
        progressState: CloudSyncProgressState? = nil
    ) -> SupabaseManualSyncRootPresentationState {
        let title = L(titleKey)
        let detail = detailKey.map { L($0) }
        let actionTitle = actionID.map { rootActionTitle(for: $0) }
        let progressLabel = progressState.map { [$0.message, $0.countText].compactMap { $0 }.joined(separator: " ") }
        let accessibilityLabel = [title, detail, progressLabel, actionTitle]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ". ")
        return SupabaseManualSyncRootPresentationState(
            kind: kind,
            title: title,
            detail: detail,
            progressState: progressState,
            primaryActionTitle: actionTitle,
            primaryActionID: actionID,
            systemImage: systemImage,
            accessibilityLabel: accessibilityLabel
        )
    }

    private func rootActionTitle(for actionID: SupabaseManualSyncPresentationActionID) -> String {
        switch actionID {
        case .reviewChanges:
            return L("options.supabase.manualSync.root.action.review")
        case .signIn:
            return L("options.supabase.manualSync.root.action.signIn")
        case .retry:
            return L("options.supabase.manualSync.root.action.retry")
        case .checkCloud:
            return L("options.supabase.manualSync.action.syncNow")
        case .downloadCloudDatabase:
            return L("options.supabase.manualSync.action.downloadCloudDatabase")
        case .realignData:
            return L("options.supabase.manualSync.action.realign")
        case .syncNow:
            return L("options.supabase.manualSync.action.syncNow")
        case .sendCloudChanges:
            return L("options.supabase.manualSync.action.sendToCloud")
        case .cancel:
            return L("options.supabase.manualSync.action.cancel")
        }
    }

    private func makePresentationState() -> SupabaseManualSyncPresentationState {
        if isRunning {
            return state(
                titleKey: "options.supabase.manualSync.state.running.title",
                subtitleKey: "options.supabase.manualSync.state.running.subtitle",
                badgeKey: "options.supabase.manualSync.badge.running",
                badgeSystemImage: "arrow.triangle.2.circlepath",
                primaryAction: nil,
                secondaryAction: action(.cancel),
                isRunning: true,
                isLoading: true
            )
        }

        if !authPresentationContext.isSignedIn {
            let hintKey: String?
            if authPresentationContext.isTransitioning {
                hintKey = "options.supabase.manualSync.disabled.authChanging"
            } else if !authPresentationContext.canSignIn {
                hintKey = "options.supabase.manualSync.disabled.accessUnavailable"
            } else {
                hintKey = nil
            }
            let summary: SupabaseManualSyncUserFacingSummary?
            if case .finished(.authRequired, _) = activityRegistrationPhase {
                summary = activityRegistrationUserFacingSummary(for: activityRegistrationPhase)
            } else {
                summary = nil
            }

            return state(
                titleKey: "options.supabase.manualSync.state.auth.title",
                subtitleKey: "options.supabase.manualSync.state.auth.subtitle",
                summary: summary,
                badgeKey: "options.supabase.manualSync.badge.needsAccess",
                badgeSystemImage: "lock.fill",
                primaryAction: action(
                    .signIn,
                    isEnabled: authPresentationContext.canSignIn && !authPresentationContext.isTransitioning,
                    hintKey: hintKey
                ),
                secondaryAction: nil,
                isRunning: false,
                isLoading: authPresentationContext.isTransitioning,
                hintKey: hintKey
            )
        }

        if let lifecycleState = lifecycleInterruptedPresentationState() {
            return lifecycleState
        }

        if let catalogPushState = catalogPushPresentationState() {
            return catalogPushState
        }

        if let activityState = activityRegistrationPresentationState() {
            return activityState
        }

        if semiAutomaticState == .blockedAuth {
            if authPresentationContext.isSignedIn {
                return signedInCloudAccessIssueState()
            }
            return state(
                titleKey: "options.supabase.manualSync.state.auth.title",
                subtitleKey: "options.supabase.manualSync.state.auth.subtitle",
                badgeKey: "options.supabase.manualSync.badge.needsAccess",
                badgeSystemImage: "lock.fill",
                primaryAction: action(.signIn, isEnabled: authPresentationContext.canSignIn),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        }

        switch presentationKind {
        case .idleReady:
            if let baselineState = baselinePresentationStateIfNeeded() {
                return baselineState
            }
            if semiAutomaticState == .suggestedCheck {
                return state(
                    titleKey: "options.supabase.manualSync.state.suggested.title",
                    subtitleKey: "options.supabase.manualSync.state.suggested.subtitle",
                    badgeKey: "options.supabase.manualSync.badge.suggested",
                    badgeSystemImage: "icloud",
                    primaryAction: action(.syncNow),
                    secondaryAction: nil,
                    isRunning: false,
                    isLoading: false
                )
            }
            let actions = capabilityActionsForWork()
            return state(
                titleKey: "options.supabase.manualSync.state.idle.title",
                subtitleKey: "options.supabase.manualSync.state.idle.subtitle",
                badgeKey: "options.supabase.manualSync.badge.manual",
                badgeSystemImage: "hand.tap.fill",
                primaryAction: actions.primary,
                secondaryAction: actions.secondary,
                isRunning: false,
                isLoading: false
            )

        case .running:
            return state(
                titleKey: "options.supabase.manualSync.state.running.title",
                subtitleKey: "options.supabase.manualSync.state.running.subtitle",
                badgeKey: "options.supabase.manualSync.badge.running",
                badgeSystemImage: "arrow.triangle.2.circlepath",
                primaryAction: nil,
                secondaryAction: action(.cancel),
                isRunning: true,
                isLoading: true
            )

        case .successFullyUpToDate:
            let reviewSheet = reviewSheetForCurrentState()
            return state(
                titleKey: "options.supabase.manualSync.state.success.title",
                subtitleKey: "options.supabase.manualSync.state.success.subtitle",
                summary: userFacingSummaryForCurrentState(),
                reviewSheet: reviewSheet,
                badgeKey: "options.supabase.manualSync.badge.noChanges",
                badgeSystemImage: "checkmark.circle.fill",
                primaryAction: reviewSheet == nil
                    ? (capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil)
                    : action(.reviewChanges),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )

        case .partialSync:
            let reviewSheet = reviewSheetForCurrentState()
            let actions = capabilityActionsForWork()
            let reviewAction = action(
                .reviewChanges,
                titleKey: "options.supabase.manualSync.action.syncNow"
            )
            return state(
                titleKey: "options.supabase.manualSync.state.partial.title",
                subtitleKey: "options.supabase.manualSync.state.partial.subtitle",
                summary: userFacingSummaryForCurrentState(),
                reviewSheet: reviewSheet,
                badgeKey: "options.supabase.manualSync.badge.localChanges",
                badgeSystemImage: "exclamationmark.circle.fill",
                primaryAction: reviewSheet == nil ? actions.primary : reviewAction,
                secondaryAction: reviewSheet == nil ? actions.secondary : nil,
                isRunning: false,
                isLoading: false
            )

        case .blockedNeedsSignIn:
            if authPresentationContext.isSignedIn {
                return signedInCloudAccessIssueState()
            }
            return state(
                titleKey: "options.supabase.manualSync.state.auth.title",
                subtitleKey: "options.supabase.manualSync.state.auth.subtitle",
                badgeKey: "options.supabase.manualSync.badge.needsAccess",
                badgeSystemImage: "lock.fill",
                primaryAction: action(.signIn, isEnabled: authPresentationContext.canSignIn),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )

        case .blockedNeedsCloudRealignment:
            let canRetryRealign = runMode(for: .realignData) != nil
            return state(
                titleKey: "options.supabase.manualSync.state.realign.title",
                subtitleKey: "options.supabase.manualSync.state.realign.subtitle",
                badgeKey: "options.supabase.manualSync.badge.needsAction",
                badgeSystemImage: "arrow.down.circle.fill",
                primaryAction: action(.realignData, isEnabled: canRetryRealign),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )

        case .connectivityIssue:
            return retryState(
                titleKey: "options.supabase.manualSync.state.connectivity.title",
                subtitleKey: "options.supabase.manualSync.state.connectivity.subtitle",
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "wifi.exclamationmark"
            )

        case .cancelledRun:
            return retryState(
                titleKey: "options.supabase.manualSync.state.cancelled.title",
                subtitleKey: "options.supabase.manualSync.state.cancelled.subtitle",
                badgeKey: "options.supabase.manualSync.badge.cancelled",
                badgeSystemImage: "xmark.circle.fill"
            )

        case .technicalFollowUpNeeded:
            if shouldRecoverPermissionFailureWithCloudCheck {
                return state(
                    titleKey: "options.supabase.manualSync.state.cloudPermission.title",
                    subtitleKey: "options.supabase.manualSync.state.cloudPermission.subtitle",
                    summary: userFacingSummaryForCurrentState(),
                    badgeKey: "options.supabase.manualSync.badge.retry",
                    badgeSystemImage: "exclamationmark.triangle.fill",
                    primaryAction: action(.checkCloud),
                    secondaryAction: nil,
                    isRunning: false,
                    isLoading: false
                )
            }
            return retryState(
                titleKey: "options.supabase.manualSync.state.technical.title",
                subtitleKey: "options.supabase.manualSync.state.technical.subtitle",
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "exclamationmark.triangle.fill"
            )

        case .auxiliaryBusyConcurrent:
            return retryState(
                titleKey: "options.supabase.manualSync.state.busy.title",
                subtitleKey: "options.supabase.manualSync.state.busy.subtitle",
                badgeKey: "options.supabase.manualSync.badge.running",
                badgeSystemImage: "hourglass"
            )

        case .auxiliaryModeUnavailable:
            return state(
                titleKey: "options.supabase.manualSync.state.unavailable.title",
                subtitleKey: "options.supabase.manualSync.state.unavailable.subtitle",
                badgeKey: "options.supabase.manualSync.badge.unavailable",
                badgeSystemImage: "slash.circle.fill",
                primaryAction: nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )

        case .localApplyCompleted:
            return state(
                titleKey: "options.supabase.manualSync.state.applied.title",
                subtitleKey: "options.supabase.manualSync.state.applied.subtitle",
                summary: userFacingSummaryForCurrentState(),
                badgeKey: "options.supabase.manualSync.badge.localUpdated",
                badgeSystemImage: "checkmark.circle.fill",
                primaryAction: capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )

        case .localApplyFailed:
            return state(
                titleKey: "options.supabase.manualSync.state.applyFailed.title",
                subtitleKey: "options.supabase.manualSync.state.applyFailed.subtitle",
                summary: userFacingSummaryForCurrentState(),
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "exclamationmark.triangle.fill",
                primaryAction: capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )

        case .catalogPushReady,
             .catalogPushNoChanges,
             .catalogPushBlocked,
             .catalogPushFailed,
             .catalogPushStale,
             .catalogPushSending,
             .catalogPushSucceeded,
             .catalogPushPartiallySucceeded,
             .activityRegistrationReady,
             .activityRegistrationSucceeded,
             .activityRegistrationEmpty,
             .activityRegistrationPartiallySucceeded,
             .activityRegistrationAuthRequired,
             .activityRegistrationRetryableFailure,
             .activityRegistrationBlocked,
             .activityRegistrationCancelled:
            return state(
                titleKey: "options.supabase.manualSync.state.idle.title",
                subtitleKey: "options.supabase.manualSync.state.idle.subtitle",
                badgeKey: "options.supabase.manualSync.badge.manual",
                badgeSystemImage: "hand.tap.fill",
                primaryAction: capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        }
    }

    private func lifecycleInterruptedPresentationState() -> SupabaseManualSyncPresentationState? {
        guard lifecycleShouldShowPriorityAttention else { return nil }
        let reviewSheet = activityRegistrationPhase.shouldShowReviewSection
            ? makeActivityRegistrationReviewSheetState()
            : reviewSheetForCurrentState()
        let actionID: SupabaseManualSyncPresentationActionID = reviewSheet != nil ? .reviewChanges : .checkCloud
        let titleKey = lifecycleProcessState.state == .blocked
            ? "options.supabase.manualSync.lifecycle.blocked.title"
            : "options.supabase.manualSync.lifecycle.interrupted.title"
        let subtitleKey = lifecycleProcessState.state == .blocked
            ? "options.supabase.manualSync.lifecycle.blocked.subtitle"
            : "options.supabase.manualSync.lifecycle.interrupted.subtitle"
        return state(
            titleKey: titleKey,
            subtitleKey: subtitleKey,
            summary: userFacingSummaryForCurrentState(),
            reviewSheet: reviewSheet,
            badgeKey: "options.supabase.manualSync.badge.retry",
            badgeSystemImage: "exclamationmark.triangle.fill",
            primaryAction: action(actionID),
            secondaryAction: nil,
            isRunning: false,
            isLoading: false
        )
    }

    private var lifecycleShouldShowPriorityAttention: Bool {
        guard lifecycleProcessState.hasInterruptedMutationPriority else { return false }
        switch lifecycleProcessState.state {
        case .interrupted:
            return lifecycleProcessState.interruptReason == .remoteWriteUnverified
                || lifecycleProcessState.interruptReason == .appBackgrounded
        case .readyToRetry:
            return lifecycleProcessState.interruptReason == .timeBudgetExceeded
                || lifecycleProcessState.interruptReason == .appBackgrounded
        case .blocked:
            return lifecycleProcessState.blockReason == .networkUnavailable
                || lifecycleProcessState.blockReason == .unsafeAppContext
                || lifecycleProcessState.blockReason == .appNotActive
        case .idle, .running, .cancelling, .completedVerified:
            return false
        }
    }

    private func catalogPushPresentationState() -> SupabaseManualSyncPresentationState? {
        guard !canApplyLocalChanges else {
            return nil
        }

        switch catalogPushPhase {
        case .idle:
            if let priceOnlyState = productPriceOnlyPushPresentationState() {
                return priceOnlyState
            }
            return nil
        case .checking:
            return state(
                titleKey: "options.supabase.manualSync.push.state.checking.title",
                subtitleKey: "options.supabase.manualSync.push.state.checking.subtitle",
                badgeKey: "options.supabase.manualSync.badge.running",
                badgeSystemImage: "arrow.triangle.2.circlepath",
                primaryAction: nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: true
            )
        case .ready(let summary):
            return state(
                titleKey: "options.supabase.manualSync.push.state.ready.title",
                subtitleKey: "options.supabase.manualSync.push.state.ready.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                reviewSheet: makeCatalogPushReviewSheetState(phase: catalogPushPhase, summary: summary),
                badgeKey: "options.supabase.manualSync.badge.readyToSend",
                badgeSystemImage: "icloud.and.arrow.up",
                primaryAction: action(.reviewChanges),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .noChanges:
            if lastSummary?.hasCompletedRemotePreviewSignals == true {
                return nil
            }
            if let priceOnlyState = productPriceOnlyPushPresentationState() {
                return priceOnlyState
            }
            if activityRegistrationPhase.shouldShowReviewSection {
                return nil
            }
            return state(
                titleKey: "options.supabase.manualSync.push.state.noChanges.title",
                subtitleKey: "options.supabase.manualSync.push.state.noChanges.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                reviewSheet: nil,
                badgeKey: "options.supabase.manualSync.badge.noChanges",
                badgeSystemImage: "checkmark.circle.fill",
                primaryAction: capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .blocked(let summary):
            return state(
                titleKey: "options.supabase.manualSync.push.state.blocked.title",
                subtitleKey: "options.supabase.manualSync.push.state.blocked.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                reviewSheet: makeCatalogPushReviewSheetState(phase: catalogPushPhase, summary: summary),
                badgeKey: "options.supabase.manualSync.badge.needsFix",
                badgeSystemImage: "xmark.octagon.fill",
                primaryAction: action(.reviewChanges),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .failed:
            return retryState(
                titleKey: "options.supabase.manualSync.push.state.failed.title",
                subtitleKey: "options.supabase.manualSync.push.state.failed.subtitle",
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "exclamationmark.triangle.fill"
            )
        case .stale:
            return state(
                titleKey: "options.supabase.manualSync.push.state.stale.title",
                subtitleKey: "options.supabase.manualSync.push.state.stale.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "arrow.clockwise.circle.fill",
                primaryAction: capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .sending(let summary):
            return state(
                titleKey: "options.supabase.manualSync.push.state.sending.title",
                subtitleKey: "options.supabase.manualSync.push.state.sending.subtitle",
                reviewSheet: makeCatalogPushReviewSheetState(phase: catalogPushPhase, summary: summary),
                badgeKey: "options.supabase.manualSync.badge.running",
                badgeSystemImage: "arrow.triangle.2.circlepath",
                primaryAction: nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: true
            )
        case .succeeded(let summary), .succeededNeedsCheck(let summary):
            return state(
                titleKey: "options.supabase.manualSync.push.state.succeeded.title",
                subtitleKey: "options.supabase.manualSync.push.state.succeeded.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                reviewSheet: makeCatalogPushReviewSheetState(phase: catalogPushPhase, summary: summary),
                badgeKey: "options.supabase.manualSync.badge.sent",
                badgeSystemImage: "checkmark.circle.fill",
                primaryAction: activityRegistrationPhase.hasPrimaryReviewAction
                    ? action(.reviewChanges)
                    : (capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .partial(let summary):
            return state(
                titleKey: "options.supabase.manualSync.push.state.partial.title",
                subtitleKey: "options.supabase.manualSync.push.state.partial.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                reviewSheet: makeCatalogPushReviewSheetState(phase: catalogPushPhase, summary: summary),
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "exclamationmark.triangle.fill",
                primaryAction: action(.retry),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .sendBlocked(let summary):
            return state(
                titleKey: "options.supabase.manualSync.push.state.blocked.title",
                subtitleKey: "options.supabase.manualSync.push.state.blocked.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                reviewSheet: makeCatalogPushReviewSheetState(phase: catalogPushPhase, summary: summary),
                badgeKey: "options.supabase.manualSync.badge.needsFix",
                badgeSystemImage: "xmark.octagon.fill",
                primaryAction: action(.reviewChanges),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .sendFailed(let summary):
            return state(
                titleKey: "options.supabase.manualSync.push.state.failed.title",
                subtitleKey: "options.supabase.manualSync.push.state.failed.subtitle",
                summary: catalogPushUserFacingSummary(for: catalogPushPhase),
                reviewSheet: makeCatalogPushReviewSheetState(phase: catalogPushPhase, summary: summary),
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "exclamationmark.triangle.fill",
                primaryAction: action(.retry),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        }
    }

    private func productPriceOnlyPushPresentationState() -> SupabaseManualSyncPresentationState? {
        switch productPricePushPhase {
        case .ready(let summary):
            return state(
                titleKey: "options.supabase.manualSync.push.state.ready.title",
                subtitleKey: "options.supabase.manualSync.push.state.ready.subtitle",
                summary: nil,
                reviewSheet: makeCatalogPushReviewSheetState(
                    phase: .ready(makeCatalogPushSummary(from: Optional<ManualPushPlan>.none)),
                    summary: makeCatalogPushSummary(from: Optional<ManualPushPlan>.none)
                ),
                badgeKey: "options.supabase.manualSync.badge.readyToSend",
                badgeSystemImage: "icloud.and.arrow.up",
                primaryAction: summary.hasReadyToPush ? action(.reviewChanges) : nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .blocked:
            return state(
                titleKey: "options.supabase.manualSync.push.state.blocked.title",
                subtitleKey: "options.supabase.manualSync.push.state.blocked.subtitle",
                summary: nil,
                reviewSheet: makeCatalogPushReviewSheetState(
                    phase: .blocked(makeCatalogPushSummary(from: Optional<ManualPushPlan>.none)),
                    summary: makeCatalogPushSummary(from: Optional<ManualPushPlan>.none)
                ),
                badgeKey: "options.supabase.manualSync.badge.needsFix",
                badgeSystemImage: "xmark.octagon.fill",
                primaryAction: action(.reviewChanges),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .checking:
            return state(
                titleKey: "options.supabase.manualSync.push.state.checking.title",
                subtitleKey: "options.supabase.manualSync.push.state.checking.subtitle",
                badgeKey: "options.supabase.manualSync.badge.running",
                badgeSystemImage: "arrow.triangle.2.circlepath",
                primaryAction: nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: true
            )
        case .failed, .sendFailed:
            return retryState(
                titleKey: "options.supabase.manualSync.push.state.failed.title",
                subtitleKey: "options.supabase.manualSync.push.state.failed.subtitle",
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "exclamationmark.triangle.fill"
            )
        case .stale:
            return state(
                titleKey: "options.supabase.manualSync.push.state.stale.title",
                subtitleKey: "options.supabase.manualSync.push.state.stale.subtitle",
                summary: nil,
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "arrow.clockwise.circle.fill",
                primaryAction: capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .sending:
            return state(
                titleKey: "options.supabase.manualSync.push.state.sending.title",
                subtitleKey: "options.supabase.manualSync.push.state.sending.subtitle",
                reviewSheet: makeCatalogPushReviewSheetState(
                    phase: .sending(makeCatalogPushSummary(from: Optional<ManualPushPlan>.none)),
                    summary: makeCatalogPushSummary(from: Optional<ManualPushPlan>.none)
                ),
                badgeKey: "options.supabase.manualSync.badge.running",
                badgeSystemImage: "arrow.triangle.2.circlepath",
                primaryAction: nil,
                secondaryAction: nil,
                isRunning: false,
                isLoading: true
            )
        case .succeeded:
            return state(
                titleKey: "options.supabase.manualSync.push.state.succeeded.title",
                subtitleKey: "options.supabase.manualSync.push.state.succeeded.subtitle",
                summary: catalogPushUserFacingSummary(for: .succeeded(makeCatalogPushSummary(from: Optional<ManualPushPlan>.none))),
                reviewSheet: makeCatalogPushReviewSheetState(
                    phase: .succeeded(makeCatalogPushSummary(from: Optional<ManualPushPlan>.none)),
                    summary: makeCatalogPushSummary(from: Optional<ManualPushPlan>.none)
                ),
                badgeKey: "options.supabase.manualSync.badge.sent",
                badgeSystemImage: "checkmark.circle.fill",
                primaryAction: activityRegistrationPhase.hasPrimaryReviewAction
                    ? action(.reviewChanges)
                    : (capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .partial:
            return state(
                titleKey: "options.supabase.manualSync.push.state.partial.title",
                subtitleKey: "options.supabase.manualSync.push.state.partial.subtitle",
                summary: catalogPushUserFacingSummary(for: .partial(makeCatalogPushSummary(from: Optional<ManualPushPlan>.none))),
                reviewSheet: makeCatalogPushReviewSheetState(
                    phase: .partial(makeCatalogPushSummary(from: Optional<ManualPushPlan>.none)),
                    summary: makeCatalogPushSummary(from: Optional<ManualPushPlan>.none)
                ),
                badgeKey: "options.supabase.manualSync.badge.retry",
                badgeSystemImage: "exclamationmark.triangle.fill",
                primaryAction: action(.retry),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .idle, .noChanges:
            return nil
        }
    }

    private func activityRegistrationPresentationState() -> SupabaseManualSyncPresentationState? {
        guard activityRegistrationPhase.shouldShowReviewSection else {
            return nil
        }

        let status = activityRegistrationPhase.statusForPresentation
        let titleKey: String
        let subtitleKey: String
        let badgeKey: String
        let badgeSystemImage: String
        switch activityRegistrationPhase {
        case .ready, .registering:
            titleKey = "options.supabase.manualSync.activity.state.ready.title"
            subtitleKey = "options.supabase.manualSync.activity.state.ready.subtitle"
            badgeKey = "options.supabase.manualSync.badge.readyToSend"
            badgeSystemImage = "checkmark.icloud"
        case .idle, .finished:
            titleKey = activityRegistrationStateTitleKey(for: status)
            subtitleKey = activityRegistrationStateSubtitleKey(for: status)
            badgeKey = activityRegistrationBadgeKey(for: status)
            badgeSystemImage = activityRegistrationBadgeSystemImage(for: status)
        }
        let primaryAction: SupabaseManualSyncPresentationAction?
        switch status {
        case .success, .empty:
            primaryAction = capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil
        case .partialRetryable, .retryableFailure, .cancelled, .blocked, .authRequired:
            primaryAction = action(.reviewChanges)
        }

        return state(
            titleKey: titleKey,
            subtitleKey: subtitleKey,
            summary: activityRegistrationUserFacingSummary(for: activityRegistrationPhase),
            reviewSheet: makeActivityRegistrationReviewSheetState(),
            badgeKey: badgeKey,
            badgeSystemImage: badgeSystemImage,
            primaryAction: primaryAction,
            secondaryAction: nil,
            isRunning: false,
            isLoading: isRegisteringActivities
        )
    }

    private func retryState(
        titleKey: String,
        subtitleKey: String,
        badgeKey: String,
        badgeSystemImage: String
    ) -> SupabaseManualSyncPresentationState {
        state(
            titleKey: titleKey,
            subtitleKey: subtitleKey,
            summary: userFacingSummaryForCurrentState(),
            badgeKey: badgeKey,
            badgeSystemImage: badgeSystemImage,
            primaryAction: runMode(for: .retry) == nil ? nil : action(.retry),
            secondaryAction: nil,
            isRunning: false,
            isLoading: false
        )
    }

    private func baselinePresentationStateIfNeeded() -> SupabaseManualSyncPresentationState? {
        guard authPresentationContext.isSignedIn else { return nil }
        guard semiAutomaticState == .idle || semiAutomaticState == .noChanges else { return nil }

        let overview = CloudSyncOverviewReducer.reduce(
            CloudSyncOverviewInput(
                oauthStatus: .signedIn,
                remoteAccessStatus: lastSummary.map {
                    CloudSyncOverviewReducer.remoteAccessStatus(
                        from: $0.remotePreviewSummary?.failureCategory
                    )
                } ?? .unknown,
                baselineStatus: currentCloudOverviewBaselineStatus,
                hasLocalPending: false,
                reviewItemCount: 0,
                isRunning: false
            )
        )

        switch overview.category {
        case .localNeedsDownload:
            return state(
                titleKey: "options.supabase.manualSync.state.download.title",
                subtitleKey: "options.supabase.manualSync.state.download.subtitle",
                badgeKey: "options.supabase.manualSync.badge.download",
                badgeSystemImage: "icloud.and.arrow.down",
                primaryAction: action(.syncNow),
                secondaryAction: nil,
                isRunning: false,
                isLoading: false
            )
        case .accountNeedsCheck:
            return signedInCloudAccessIssueState()
        case .accountRequired, .cloudPermission, .networkOffline, .localPending, .needsReview, .ready:
            return nil
        }
    }

    private func signedInCloudAccessIssueState() -> SupabaseManualSyncPresentationState {
        let failureCategory = lastSummary?.remotePreviewSummary?.failureCategory
        let titleKey: String
        let subtitleKey: String
        let badgeSystemImage: String
        if failureCategory == .permission || failureCategory == .schemaOrDecode {
            titleKey = "options.supabase.manualSync.state.cloudPermission.title"
            subtitleKey = "options.supabase.manualSync.state.cloudPermission.subtitle"
            badgeSystemImage = "exclamationmark.icloud"
        } else {
            titleKey = "options.supabase.manualSync.state.accountCheck.title"
            subtitleKey = "options.supabase.manualSync.state.accountCheck.subtitle"
            badgeSystemImage = "person.crop.circle.badge.exclamationmark"
        }
        return state(
            titleKey: titleKey,
            subtitleKey: subtitleKey,
            summary: userFacingSummaryForCurrentState(),
            badgeKey: "options.supabase.manualSync.badge.needsAction",
            badgeSystemImage: badgeSystemImage,
            primaryAction: capabilities.supportsRemoteCloudCheck ? action(.checkCloud) : nil,
            secondaryAction: nil,
            isRunning: false,
            isLoading: false
        )
    }

    private func capabilityActionsForWork() -> (
        primary: SupabaseManualSyncPresentationAction?,
        secondary: SupabaseManualSyncPresentationAction?
    ) {
        if capabilities.supportsGuidedManualSync {
            return (primary: action(.syncNow), secondary: nil)
        }
        if capabilities.supportsRemoteCloudCheck {
            return (primary: action(.syncNow), secondary: nil)
        }
        return (primary: nil, secondary: nil)
    }

    private func preferredCapabilityRunMode() -> SupabaseManualSyncRunMode? {
        if capabilities.supportsGuidedManualSync {
            return .guidedManual
        }
        if capabilities.supportsRemoteCloudCheck {
            return .dryRun
        }
        return nil
    }

    private func userFacingSummaryForCurrentState() -> SupabaseManualSyncUserFacingSummary? {
        switch presentationKind {
        case .localApplyCompleted:
            guard let lastLocalApplySummary else { return nil }
            return SupabaseManualSyncUserFacingSummary(
                kind: .localApplyCompleted,
                message: makeLocalApplyCompletedMessage(from: lastLocalApplySummary)
            )
        case .localApplyFailed:
            return userFacingSummary(.localApplyFailed, key: "options.supabase.manualSync.summary.localApply.failed")
        case .successFullyUpToDate, .partialSync, .connectivityIssue, .cancelledRun, .technicalFollowUpNeeded:
            guard let lastSummary else { return nil }
            return makeUserFacingSummary(from: lastSummary)
        case .catalogPushNoChanges,
             .catalogPushBlocked,
             .catalogPushFailed,
             .catalogPushStale,
             .catalogPushSucceeded,
             .catalogPushPartiallySucceeded:
            return catalogPushUserFacingSummary(for: catalogPushPhase)
        case .activityRegistrationReady,
             .activityRegistrationSucceeded,
             .activityRegistrationEmpty,
             .activityRegistrationPartiallySucceeded,
             .activityRegistrationAuthRequired,
             .activityRegistrationRetryableFailure,
             .activityRegistrationBlocked,
             .activityRegistrationCancelled:
            return activityRegistrationUserFacingSummary(for: activityRegistrationPhase)
        case .idleReady,
             .running,
             .blockedNeedsSignIn,
             .blockedNeedsCloudRealignment,
             .auxiliaryBusyConcurrent,
             .auxiliaryModeUnavailable,
             .catalogPushReady,
             .catalogPushSending:
            return nil
        }
    }

    private func catalogPushUserFacingSummary(
        for phase: SupabaseManualSyncCatalogPushPhase
    ) -> SupabaseManualSyncUserFacingSummary? {
        switch phase {
        case .noChanges:
            return userFacingSummary(.catalogPushNoChanges, key: "options.supabase.manualSync.push.summary.noChanges")
        case .blocked, .sendBlocked:
            return userFacingSummary(.catalogPushBlocked, key: "options.supabase.manualSync.push.summary.blocked")
        case .failed:
            return userFacingSummary(.catalogPushFailedBeforeWrite, key: "options.supabase.manualSync.push.summary.failedBeforeWrite")
        case .stale:
            return userFacingSummary(.catalogPushStale, key: "options.supabase.manualSync.push.summary.stale")
        case .succeeded:
            return userFacingSummary(.catalogPushSucceeded, key: "options.supabase.manualSync.push.summary.succeeded")
        case .succeededNeedsCheck:
            return userFacingSummary(.catalogPushSucceededNeedsCheck, key: "options.supabase.manualSync.push.summary.succeededNeedsCheck")
        case .partial:
            return userFacingSummary(.catalogPushPartial, key: "options.supabase.manualSync.push.summary.partial")
        case .sendFailed:
            return userFacingSummary(.catalogPushFailedBeforeWrite, key: "options.supabase.manualSync.push.summary.failedBeforeWrite")
        case .idle, .checking, .ready, .sending:
            return nil
        }
    }

    private func activityRegistrationUserFacingSummary(
        for phase: SupabaseManualSyncActivityRegistrationPhase
    ) -> SupabaseManualSyncUserFacingSummary? {
        guard case .finished(let status, let summary) = phase else {
            return nil
        }
        return SupabaseManualSyncUserFacingSummary(
            kind: activityRegistrationSummaryKind(for: status),
            message: activityRegistrationSummaryMessage(status: status, summary: summary)
        )
    }

    private func activityRegistrationSummaryKind(
        for status: SupabaseManualSyncActivityRegistrationStatus
    ) -> SupabaseManualSyncUserFacingSummaryKind {
        switch status {
        case .success:
            return .activityRegistrationSucceeded
        case .empty:
            return .activityRegistrationEmpty
        case .partialRetryable:
            return .activityRegistrationPartial
        case .authRequired:
            return .activityRegistrationAuthRequired
        case .retryableFailure:
            return .activityRegistrationRetryableFailure
        case .blocked:
            return .activityRegistrationBlocked
        case .cancelled:
            return .activityRegistrationCancelled
        }
    }

    private func activityRegistrationSummaryKey(
        for status: SupabaseManualSyncActivityRegistrationStatus
    ) -> String {
        switch status {
        case .success:
            return "options.supabase.manualSync.activity.summary.success"
        case .empty:
            return "options.supabase.manualSync.activity.summary.empty"
        case .partialRetryable:
            return "options.supabase.manualSync.activity.summary.partialRetryable"
        case .authRequired:
            return "options.supabase.manualSync.activity.summary.authRequired"
        case .retryableFailure:
            return "options.supabase.manualSync.activity.summary.retryableFailure"
        case .blocked:
            return "options.supabase.manualSync.activity.summary.blocked"
        case .cancelled:
            return "options.supabase.manualSync.activity.summary.cancelled"
        }
    }

    private func makeUserFacingSummary(from summary: SupabaseManualSyncRunSummary) -> SupabaseManualSyncUserFacingSummary? {
        if let remotePreviewSummary = summary.remotePreviewSummary {
            return makeUserFacingSummary(
                from: remotePreviewSummary,
                counts: summary.countsSnapshot
            )
        }

        switch summary.finalState {
        case .allUpToDate:
            return userFacingSummary(.noLocalChangesToSend, key: "options.supabase.manualSync.summary.local.noPending")
        case .completedSuccessfully where !summary.countsSnapshot.hasAnyPendingWork:
            return userFacingSummary(.noLocalChangesToSend, key: "options.supabase.manualSync.summary.local.noPending")
        case .connectivityIssue:
            return userFacingSummary(.networkIssue, key: "options.supabase.manualSync.summary.network")
        case .technicalReviewNeeded:
            return userFacingSummary(.genericIssue, key: "options.supabase.manualSync.summary.generic")
        case .cancelled:
            return userFacingSummary(.cancelled, key: "options.supabase.manualSync.summary.cancelled")
        case .completedSuccessfully,
             .partialSync,
             .blocked,
             .concurrentRunNotAllowed,
             .modeNotSupportedInThisSlice:
            return nil
        }
    }

    private func makeUserFacingSummary(
        from remotePreviewSummary: SupabaseManualSyncRemotePreviewSummary,
        counts: SupabaseManualSyncPrivacyCounts
    ) -> SupabaseManualSyncUserFacingSummary? {
        if remotePreviewSummary.wasCancelled {
            return userFacingSummary(.cancelled, key: "options.supabase.manualSync.summary.cancelled")
        }

        if let failureCategory = remotePreviewSummary.failureCategory {
            switch failureCategory {
            case .network:
                return userFacingSummary(.networkIssue, key: "options.supabase.manualSync.summary.network")
            case .auth:
                return userFacingSummary(.cloudAccessIssue, key: "options.supabase.manualSync.summary.session")
            case .permission:
                return userFacingSummary(.cloudAccessIssue, key: "options.supabase.manualSync.summary.permission")
            case .schemaOrDecode, .localSnapshot, .unknown:
                return userFacingSummary(.genericIssue, key: "options.supabase.manualSync.summary.generic")
            }
        }

        if remotePreviewSummary.isPartial || !remotePreviewSummary.isComplete {
            return userFacingSummary(.cloudCheckIncomplete, key: "options.supabase.manualSync.summary.cloudCheck.incomplete")
        }

        if remotePreviewSummary.hasRemoteSignals {
            return userFacingSummary(.remoteReviewNeeded, key: "options.supabase.manualSync.summary.cloudCheck.differences")
        }

        if counts.hasAnyPendingWork {
            return userFacingSummary(.cloudCheckCompleted, key: "options.supabase.manualSync.summary.cloudCheck.completed.ok")
        }

        return userFacingSummary(.cloudCheckCompletedNoAction, key: "options.supabase.manualSync.summary.cloudCheck.completed.noAction")
    }

    private func userFacingSummary(
        _ kind: SupabaseManualSyncUserFacingSummaryKind,
        key: String
    ) -> SupabaseManualSyncUserFacingSummary {
        SupabaseManualSyncUserFacingSummary(kind: kind, message: L(key))
    }

    private func makeLocalApplyCompletedMessage(
        from summary: SupabaseManualSyncLocalApplySummary
    ) -> String {
        var details: [String] = []
        if summary.productsAdded > 0 {
            details.append(L("options.supabase.manualSync.summary.localApply.productsAdded", summary.productsAdded))
        }
        if summary.productsUpdated > 0 {
            details.append(L("options.supabase.manualSync.summary.localApply.productsUpdated", summary.productsUpdated))
        }
        if summary.suppliersCreated > 0 {
            details.append(L("options.supabase.manualSync.summary.localApply.suppliersCreated", summary.suppliersCreated))
        }
        if summary.categoriesCreated > 0 {
            details.append(L("options.supabase.manualSync.summary.localApply.categoriesCreated", summary.categoriesCreated))
        }
        details.append(contentsOf: productPriceSummaryLines(summary.priceSummary))

        guard !details.isEmpty else {
            return L("options.supabase.manualSync.summary.localApply.completed")
        }
        return L("options.supabase.manualSync.summary.localApply.completedWithCounts", details.joined(separator: ", "))
    }

    private func reviewSheetForCurrentState() -> SupabaseManualSyncReviewSheetState? {
        guard let lastSummary,
              let remotePreviewSummary = lastSummary.remotePreviewSummary,
              let summary = makeUserFacingSummary(from: lastSummary) else {
            return nil
        }

        switch summary.kind {
        case .cloudCheckCompleted, .cloudCheckCompletedNoAction, .remoteReviewNeeded:
            return makeReviewSheetState(from: lastSummary, remotePreviewSummary: remotePreviewSummary)
        case .noLocalChangesToSend,
             .cloudCheckIncomplete,
             .networkIssue,
             .cloudAccessIssue,
             .genericIssue,
             .cancelled,
             .localApplyCompleted,
             .localApplyFailed,
             .catalogPushNoChanges,
             .catalogPushSucceeded,
             .catalogPushSucceededNeedsCheck,
             .catalogPushPartial,
             .catalogPushBlocked,
             .catalogPushFailedBeforeWrite,
             .catalogPushInterrupted,
             .catalogPushStale,
             .activityRegistrationSucceeded,
             .activityRegistrationEmpty,
             .activityRegistrationPartial,
             .activityRegistrationAuthRequired,
             .activityRegistrationRetryableFailure,
             .activityRegistrationBlocked,
             .activityRegistrationCancelled:
            return nil
        }
    }

    private func makeReviewSheetState(
        from summary: SupabaseManualSyncRunSummary,
        remotePreviewSummary: SupabaseManualSyncRemotePreviewSummary
    ) -> SupabaseManualSyncReviewSheetState {
        let counts = summary.countsSnapshot
        let aggregateCounts = remotePreviewSummary.safeAggregateCounts
        let plan = makeCloudReviewPlan(
            counts: counts,
            aggregateCounts: aggregateCounts,
            remotePreviewSummary: remotePreviewSummary
        )
        var sections: [SupabaseManualSyncReviewSectionState] = [
            reviewSection(
                id: .cloudToDevice,
                titleKey: "options.supabase.manualSync.review.cloudToDevice.title",
                messageKey: remotePreviewSummary.hasRemoteSignals
                    ? "options.supabase.manualSync.review.cloudToDevice.needsReview"
                    : "options.supabase.manualSync.review.cloudToDevice.noChanges",
                systemImage: "icloud.and.arrow.down",
                tone: .neutral
            ),
            reviewSection(
                id: .deviceToCloud,
                titleKey: "options.supabase.manualSync.review.deviceToCloud.title",
                messageKey: counts.hasAnyPendingWork
                    ? "options.supabase.manualSync.review.deviceToCloud.localChanges"
                    : "options.supabase.manualSync.review.deviceToCloud.noChanges",
                systemImage: "iphone.and.arrow.forward",
                tone: .neutral
            ),
            reviewSection(
                id: .prices,
                titleKey: "options.supabase.manualSync.review.prices.title",
                message: productPriceReviewMessage(
                    fallbackHasPriceSignals: hasPriceSignals(counts: counts, aggregateCounts: aggregateCounts)
                ),
                systemImage: "tag",
                tone: productPriceSummary.hasProblems ? .attention : .neutral
            )
        ]

        if plan.state != .ready || hasAttentionSignals(aggregateCounts) {
            sections.append(
                reviewSection(
                    id: .attention,
                    titleKey: "options.supabase.manualSync.review.attention.title",
                    message: syncPlanAttentionMessage(plan),
                    systemImage: "exclamationmark.triangle.fill",
                    tone: plan.state == .blocked || plan.state == .failed ? .blocked : .attention
                )
            )
        }
        appendActivityRegistrationSectionIfNeeded(to: &sections)
        sections = orderReviewSections(sections, plan: plan)

        let title = L("options.supabase.manualSync.review.title")
        let subtitle = L("options.supabase.manualSync.review.subtitle")
        let footerMessage = isApplyingLocalChanges
            ? (localApplyProgressMessage ?? L("options.supabase.manualSync.progress.preparing"))
            : reviewFooterMessage(remotePreviewSummary: remotePreviewSummary)
        let preferredPrimaryActionID: SupabaseManualSyncReviewPrimaryActionID
        if canApplyLocalChanges || isApplyingLocalChanges {
            preferredPrimaryActionID = .updateDevice
        } else if activityRegistrationPhase.hasRegisterAction {
            preferredPrimaryActionID = .registerCloudActivity
        } else {
            preferredPrimaryActionID = .none
        }
        let primaryActionID = reviewPrimaryActionID(plan: plan, readyAction: preferredPrimaryActionID)
        let primaryActionTitle = reviewPrimaryActionTitle(for: primaryActionID, plan: plan)
        let primaryActionSystemImage = reviewPrimaryActionSystemImage(for: primaryActionID, plan: plan)
        let secondaryActionTitle = L("options.supabase.manualSync.review.action.cancel")
        let accessibilityLabel = ([title, subtitle] + sections.flatMap { [$0.title, $0.message] } + [footerMessage])
            .joined(separator: ". ")

        return SupabaseManualSyncReviewSheetState(
            title: title,
            subtitle: subtitle,
            summaryTitle: syncPlanSummaryTitle(plan),
            summaryMessage: syncPlanSummaryMessage(plan),
            summarySystemImage: syncPlanSummarySystemImage(plan),
            summaryTone: syncPlanSummaryTone(plan),
            progressState: progressState.isActive ? progressState : nil,
            sections: sections,
            footerMessage: footerMessage,
            primaryActionID: primaryActionID,
            primaryActionTitle: primaryActionTitle,
            primaryActionSystemImage: primaryActionSystemImage,
            primaryActionIsEnabled: reviewPrimaryActionIsEnabled(primaryActionID),
            primaryActionIsLoading: reviewPrimaryActionIsLoading(primaryActionID),
            secondaryActionTitle: secondaryActionTitle,
            accessibilityLabel: accessibilityLabel
        )
    }

    private func makeCatalogPushReviewSheetState(
        phase: SupabaseManualSyncCatalogPushPhase,
        summary: SupabaseManualSyncCatalogPushSummary
    ) -> SupabaseManualSyncReviewSheetState {
        let title = L("options.supabase.manualSync.push.review.title")
        let subtitle = catalogPushReviewSubtitle(phase: phase)
        let plan = makeCatalogPushReviewPlan(phase: phase, summary: summary)
        let sections = orderReviewSections(
            catalogPushReviewSections(phase: phase, summary: summary, plan: plan),
            plan: plan
        )
        let footerMessage = catalogPushReviewFooter(phase: phase)
        let readyPrimaryID = catalogPushReviewPrimaryActionID(phase: phase)
        let primaryID = reviewPrimaryActionID(plan: plan, readyAction: readyPrimaryID)
        let primaryTitle = reviewPrimaryActionTitle(for: primaryID, plan: plan)
        let primarySystemImage = reviewPrimaryActionSystemImage(for: primaryID, plan: plan)
        let accessibilityLabel = ([title, subtitle] + sections.flatMap { [$0.title, $0.message] } + [footerMessage])
            .joined(separator: ". ")

        return SupabaseManualSyncReviewSheetState(
            title: title,
            subtitle: subtitle,
            summaryTitle: syncPlanSummaryTitle(plan),
            summaryMessage: syncPlanSummaryMessage(plan),
            summarySystemImage: syncPlanSummarySystemImage(plan),
            summaryTone: syncPlanSummaryTone(plan),
            progressState: progressState.isActive ? progressState : nil,
            sections: sections,
            footerMessage: footerMessage,
            primaryActionID: primaryID,
            primaryActionTitle: primaryTitle,
            primaryActionSystemImage: primarySystemImage,
            primaryActionIsEnabled: reviewPrimaryActionIsEnabled(primaryID),
            primaryActionIsLoading: reviewPrimaryActionIsLoading(primaryID),
            secondaryActionTitle: L(hasTerminalCatalogPushSummary ? "common.close" : "common.cancel"),
            accessibilityLabel: accessibilityLabel
        )
    }

    private func catalogPushReviewSubtitle(phase: SupabaseManualSyncCatalogPushPhase) -> String {
        switch phase {
        case .succeeded, .succeededNeedsCheck, .partial, .sendBlocked, .sendFailed:
            return L("options.supabase.manualSync.push.review.subtitle.final")
        case .sending:
            return L("options.supabase.manualSync.push.review.subtitle.sending")
        case .blocked:
            return L("options.supabase.manualSync.push.review.subtitle.blocked")
        case .ready, .checking, .noChanges, .failed, .stale, .idle:
            return L("options.supabase.manualSync.push.review.subtitle")
        }
    }

    private func catalogPushReviewSections(
        phase: SupabaseManualSyncCatalogPushPhase,
        summary: SupabaseManualSyncCatalogPushSummary,
        plan: SupabaseSyncPlan
    ) -> [SupabaseManualSyncReviewSectionState] {
        var sections: [SupabaseManualSyncReviewSectionState] = []
        if plan.state != .ready {
            sections.append(reviewSection(
                id: .attention,
                titleKey: "options.supabase.manualSync.review.attention.title",
                message: syncPlanAttentionMessage(plan),
                systemImage: "exclamationmark.triangle.fill",
                tone: plan.state == .blocked || plan.state == .failed ? .blocked : .attention
            ))
        }
        if summary.hasReadyChanges {
            sections.append(reviewSection(
                id: .readyToSend,
                titleKey: "options.supabase.manualSync.push.review.ready.title",
                message: L(
                    "options.supabase.manualSync.push.review.ready.message",
                    summary.readyCount,
                    summary.createCount,
                    summary.updateCount,
                    summary.linkCount
                ),
                systemImage: "checkmark.circle.fill",
                tone: .success
            ))
        }
        if summary.hasWarnings {
            sections.append(reviewSection(
                id: .sendAttention,
                titleKey: "options.supabase.manualSync.push.review.attention.title",
                message: L("options.supabase.manualSync.push.review.attention.message"),
                systemImage: "exclamationmark.triangle.fill",
                tone: .attention
            ))
        }
        if summary.hasBlockers {
            sections.append(reviewSection(
                id: .sendBlocked,
                titleKey: "options.supabase.manualSync.push.review.blocked.title",
                message: L("options.supabase.manualSync.push.review.blocked.message", summary.blockerCount),
                systemImage: "xmark.octagon.fill",
                tone: .blocked
            ))
        }
        if productPriceSummary.hasReviewSignals {
            sections.append(reviewSection(
                id: .prices,
                titleKey: "options.supabase.manualSync.review.prices.title",
                message: productPriceReviewMessage(fallbackHasPriceSignals: false),
                systemImage: "tag",
                tone: productPriceSummary.hasProblems ? .attention : .neutral
            ))
        }
        appendActivityRegistrationSectionIfNeeded(to: &sections)
        if case .succeeded = phase {
            sections.append(finalSummarySection(key: "options.supabase.manualSync.push.summary.succeeded"))
        } else if case .succeededNeedsCheck = phase {
            sections.append(finalSummarySection(key: "options.supabase.manualSync.push.summary.succeededNeedsCheck"))
        } else if case .partial = phase {
            sections.append(finalSummarySection(key: "options.supabase.manualSync.push.summary.partial"))
        } else if case .sendFailed = phase {
            sections.append(finalSummarySection(key: "options.supabase.manualSync.push.summary.failedBeforeWrite"))
        } else if case .sendBlocked = phase {
            sections.append(finalSummarySection(key: "options.supabase.manualSync.push.summary.blocked"))
        }
        if sections.isEmpty {
            sections.append(reviewSection(
                id: .finalSummary,
                titleKey: "options.supabase.manualSync.push.review.final.title",
                message: L("options.supabase.manualSync.push.summary.noChanges"),
                systemImage: "checkmark.circle.fill",
                tone: .neutral
            ))
        }
        return sections
    }

    private func finalSummarySection(key: String) -> SupabaseManualSyncReviewSectionState {
        reviewSection(
            id: .finalSummary,
            titleKey: "options.supabase.manualSync.push.review.final.title",
            message: L(key),
            systemImage: "list.bullet.clipboard",
            tone: .neutral
        )
    }

    private func catalogPushReviewFooter(phase: SupabaseManualSyncCatalogPushPhase) -> String {
        if isRegisteringActivities {
            return L("options.supabase.manualSync.activity.review.footer.registering")
        }
        switch phase {
        case .ready:
            if canApplyLocalChanges {
                return L("options.supabase.manualSync.push.review.footer.updateFirst")
            }
            if activityRegistrationPhase.hasRegisterAction {
                return L("options.supabase.manualSync.push.review.footer.ready")
            }
            return L("options.supabase.manualSync.push.review.footer.ready")
        case .blocked, .sendBlocked:
            return L("options.supabase.manualSync.push.review.footer.blocked")
        case .sending:
            return L("options.supabase.manualSync.push.review.footer.sending")
        case .succeeded, .succeededNeedsCheck:
            if activityRegistrationPhase.hasRegisterAction {
                return L("options.supabase.manualSync.activity.review.footer.ready")
            }
            return L("options.supabase.manualSync.push.review.footer.final")
        case .partial, .sendFailed:
            return L("options.supabase.manualSync.push.review.footer.final")
        case .stale:
            return L("options.supabase.manualSync.push.summary.stale")
        case .idle, .checking, .noChanges, .failed:
            return L("options.supabase.manualSync.push.review.footer.ready")
        }
    }

    private func catalogPushReviewPrimaryActionID(
        phase: SupabaseManualSyncCatalogPushPhase
    ) -> SupabaseManualSyncReviewPrimaryActionID {
        switch phase {
        case .ready:
            return canApplyLocalChanges ? .none : .sendCloudChanges
        case .noChanges:
            if productPriceSummary.hasReadyToPush {
                return .sendCloudChanges
            }
            return activityRegistrationPhase.hasRegisterAction ? .registerCloudActivity : .none
        case .sending:
            return .sendCloudChanges
        case .succeeded, .succeededNeedsCheck:
            return activityRegistrationPhase.hasRegisterAction ? .registerCloudActivity : .none
        case .idle, .checking, .blocked, .failed, .stale, .partial, .sendBlocked, .sendFailed:
            return .none
        }
    }

    private func reviewFooterMessage(
        remotePreviewSummary: SupabaseManualSyncRemotePreviewSummary
    ) -> String {
        if isApplyingLocalChanges {
            return L("options.supabase.manualSync.review.footer.updatingDevice")
        }
        if canApplyLocalChanges {
            return L("options.supabase.manualSync.review.footer.readyToUpdateDevice")
        }
        if isRegisteringActivities {
            return L("options.supabase.manualSync.activity.review.footer.registering")
        }
        if activityRegistrationPhase.hasRegisterAction {
            return L("options.supabase.manualSync.activity.review.footer.ready")
        }
        if let activityMessage = activityRegistrationFooterMessageForTerminalPhase() {
            return activityMessage
        }
        if let applyBlockedReason {
            return applyBlockedReason
        }
        return remotePreviewSummary.hasRemoteSignals
            ? L("options.supabase.manualSync.apply.blocked.refreshRequired")
            : L("options.supabase.manualSync.apply.blocked.noChanges")
    }

    private func makeActivityRegistrationReviewSheetState() -> SupabaseManualSyncReviewSheetState? {
        guard activityRegistrationPhase.shouldShowReviewSection else { return nil }
        let plan = makeActivityRegistrationReviewPlan()
        let title = L("options.supabase.manualSync.activity.review.title")
        let subtitle = L("options.supabase.manualSync.activity.review.subtitle")
        let sections = orderReviewSections([activityRegistrationSection()], plan: plan)
        let footerMessage = activityRegistrationFooterMessage()
        let readyPrimaryID: SupabaseManualSyncReviewPrimaryActionID = activityRegistrationPhase.hasRegisterAction
            ? .registerCloudActivity
            : .none
        let primaryID: SupabaseManualSyncReviewPrimaryActionID = activityRegistrationPhase.prefersRetryTitle
            ? .recheck
            : reviewPrimaryActionID(plan: plan, readyAction: readyPrimaryID)
        let accessibilityLabel = ([title, subtitle] + sections.flatMap { [$0.title, $0.message] } + [footerMessage])
            .joined(separator: ". ")

        return SupabaseManualSyncReviewSheetState(
            title: title,
            subtitle: subtitle,
            summaryTitle: syncPlanSummaryTitle(plan),
            summaryMessage: syncPlanSummaryMessage(plan),
            summarySystemImage: syncPlanSummarySystemImage(plan),
            summaryTone: syncPlanSummaryTone(plan),
            progressState: progressState.isActive ? progressState : nil,
            sections: sections,
            footerMessage: footerMessage,
            primaryActionID: primaryID,
            primaryActionTitle: reviewPrimaryActionTitle(for: primaryID, plan: plan),
            primaryActionSystemImage: reviewPrimaryActionSystemImage(for: primaryID, plan: plan),
            primaryActionIsEnabled: reviewPrimaryActionIsEnabled(primaryID),
            primaryActionIsLoading: reviewPrimaryActionIsLoading(primaryID),
            secondaryActionTitle: L(activityRegistrationPhase.isTerminal ? "common.close" : "common.cancel"),
            accessibilityLabel: accessibilityLabel
        )
    }

    private func appendActivityRegistrationSectionIfNeeded(
        to sections: inout [SupabaseManualSyncReviewSectionState]
    ) {
        guard activityRegistrationPhase.shouldShowReviewSection else { return }
        sections.append(activityRegistrationSection())
    }

    private func activityRegistrationSection() -> SupabaseManualSyncReviewSectionState {
        reviewSection(
            id: .activityRegistration,
            titleKey: "options.supabase.manualSync.activity.review.section.title",
            message: activityRegistrationSectionMessage(),
            systemImage: activityRegistrationPhase.systemImage,
            tone: activityRegistrationPhase.reviewTone
        )
    }

    private func activityRegistrationSectionMessage() -> String {
        switch activityRegistrationPhase {
        case .ready(let snapshot):
            return activityRegistrationReadyMessage(snapshot)
        case .registering:
            return L("options.supabase.manualSync.activity.review.registering")
        case .finished(let status, let summary):
            return activityRegistrationSummaryMessage(status: status, summary: summary)
        case .idle:
            return L("options.supabase.manualSync.activity.summary.empty")
        }
    }

    private func activityRegistrationReadyMessage(
        _ snapshot: SupabaseManualSyncActivityRegistrationSnapshot
    ) -> String {
        var lines = [L("options.supabase.manualSync.activity.review.ready", snapshot.readyToRegister)]
        let waitingAfterReady = max(0, snapshot.waiting - snapshot.readyToRegister)
        if waitingAfterReady > 0 {
            lines.append(L("options.supabase.manualSync.activity.summary.waiting", waitingAfterReady))
        }
        if snapshot.notRegisterable > 0 {
            lines.append(L("options.supabase.manualSync.activity.summary.notRegisterable", snapshot.notRegisterable))
        }
        return lines.joined(separator: "\n")
    }

    private func activityRegistrationSummaryMessage(
        status: SupabaseManualSyncActivityRegistrationStatus,
        summary: SupabaseManualSyncActivityRegistrationSummary
    ) -> String {
        let headline = L(activityRegistrationSummaryKey(for: status))
        let details = [
            L("options.supabase.manualSync.activity.summary.registered", summary.registered),
            L("options.supabase.manualSync.activity.summary.waiting", summary.waiting),
            L("options.supabase.manualSync.activity.summary.notRegisterable", summary.notRegisterable)
        ]
        return ([headline] + details).joined(separator: "\n")
    }

    private func activityRegistrationFooterMessage() -> String {
        if isRegisteringActivities {
            return L("options.supabase.manualSync.activity.review.footer.registering")
        }
        if activityRegistrationPhase.hasRegisterAction {
            return L("options.supabase.manualSync.activity.review.footer.ready")
        }
        return activityRegistrationFooterMessageForTerminalPhase()
            ?? L("options.supabase.manualSync.activity.review.footer.final")
    }

    private func activityRegistrationFooterMessageForTerminalPhase() -> String? {
        guard case .finished(let status, _) = activityRegistrationPhase else { return nil }
        switch status {
        case .success, .empty:
            return L("options.supabase.manualSync.activity.review.footer.final")
        case .partialRetryable, .retryableFailure, .cancelled:
            return L("options.supabase.manualSync.activity.review.footer.retry")
        case .authRequired:
            return L("options.supabase.manualSync.activity.summary.authRequired")
        case .blocked:
            return L("options.supabase.manualSync.activity.summary.blocked")
        }
    }

    private func makeCloudReviewPlan(
        counts: SupabaseManualSyncPrivacyCounts,
        aggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts,
        remotePreviewSummary: SupabaseManualSyncRemotePreviewSummary
    ) -> SupabaseSyncPlan {
        var counters = SupabaseSyncPlanCounters(
            toApply: canApplyLocalChanges
                ? aggregateCounts.newProductCount
                    + aggregateCounts.updateCandidateCount
                    + productPriceSummary.readyToApply
                : 0,
            skipped: productPriceSummary.skippedDuplicate,
            reviewNeeded: aggregateCounts.conflictCount
                + aggregateCounts.sourceErrorCount,
            blocked: productPriceSummary.blocked,
            failed: productPriceSummary.failed
        )
        if remotePreviewSummary.hasRemoteSignals,
           !canApplyLocalChanges,
           counters.reviewNeeded == 0,
           counters.blocked == 0,
           counters.failed == 0 {
            counters.reviewNeeded = 1
        }
        let reasons = syncPlanBlockingReasons(
            counters: counters,
            hasInvalidData: applyBlockedReason == L("options.supabase.manualSync.apply.blocked.invalidData"),
            hasAccessIssue: applyBlockedReason == L("options.supabase.manualSync.apply.blocked.session"),
            hasCloudPermissionIssue: remotePreviewSummary.failureCategory == .permission
        )
        return SupabaseSyncPlanResolver.makePlan(
            counters: counters,
            requestedSections: [
                .cloud,
                .device,
                .prices
            ] + (activityRegistrationPhase.shouldShowReviewSection ? [.activity] : []),
            blockingReasons: reasons,
            planFingerprint: [
                "\(remotePreviewSummary.safeAggregateCounts.reviewSignalCount)",
                "\(counts.pendingQueuedCloudOperationCount)",
                "\(productPriceSummary.readyToApply)",
                "\(productPriceSummary.readyToPush)"
            ].joined(separator: "|")
        )
    }

    private func makeCatalogPushReviewPlan(
        phase: SupabaseManualSyncCatalogPushPhase,
        summary: SupabaseManualSyncCatalogPushSummary
    ) -> SupabaseSyncPlan {
        var explicitState: SupabaseSyncPlanState?
        switch phase {
        case .failed, .sendFailed:
            explicitState = .failed
        case .partial:
            explicitState = .partial
        case .stale:
            explicitState = .stale
        case .blocked, .sendBlocked:
            explicitState = .blocked
        case .ready, .sending, .succeeded, .succeededNeedsCheck, .noChanges, .idle, .checking:
            explicitState = nil
        }
        let counters = SupabaseSyncPlanCounters(
            toApply: summary.readyCount + productPriceSummary.readyToPush,
            applied: summary.resultStatus == .completed || summary.resultStatus == .completedBaselineRefreshFailed
                ? summary.readyCount
                : 0,
            skipped: productPriceSummary.skippedDuplicate,
            reviewNeeded: summary.warningCount + summary.futureOnlyCount + productPriceSummary.skippedConflict,
            blocked: summary.blockerCount + productPriceSummary.blocked,
            failed: productPriceSummary.failed
        )
        return SupabaseSyncPlanResolver.makePlan(
            counters: counters,
            requestedSections: [
                .device,
                .prices
            ] + (activityRegistrationPhase.shouldShowReviewSection ? [.activity] : []),
            blockingReasons: syncPlanBlockingReasons(
                counters: counters,
                hasInvalidData: summary.hasBlockers,
                hasAccessIssue: false
            ),
            explicitState: explicitState,
            planFingerprint: summary.planFingerprint
        )
    }

    private func makeActivityRegistrationReviewPlan() -> SupabaseSyncPlan {
        let snapshot = activityRegistrationSnapshotForCurrentPhase()
        let explicitState: SupabaseSyncPlanState?
        if case .finished(let status, _) = activityRegistrationPhase {
            switch status {
            case .success, .empty:
                explicitState = nil
            case .partialRetryable:
                explicitState = .partial
            case .authRequired:
                explicitState = .failed
            case .retryableFailure, .cancelled:
                explicitState = .stale
            case .blocked:
                explicitState = .blocked
            }
        } else {
            explicitState = nil
        }
        let counters = SupabaseSyncPlanCounters(
            toApply: snapshot.readyToRegister,
            applied: activityRegistrationSummaryForCurrentPhase().registered,
            blocked: snapshot.notRegisterable,
            stale: snapshot.waiting > 0 && snapshot.readyToRegister == 0 ? 1 : 0
        )
        return SupabaseSyncPlanResolver.makePlan(
            counters: counters,
            requestedSections: [.activity],
            blockingReasons: syncPlanBlockingReasons(
                counters: counters,
                hasInvalidData: snapshot.notRegisterable > 0,
                hasAccessIssue: explicitState == .failed
            ),
            explicitState: explicitState
        )
    }

    private func syncPlanBlockingReasons(
        counters: SupabaseSyncPlanCounters,
        hasInvalidData: Bool,
        hasAccessIssue: Bool,
        hasCloudPermissionIssue: Bool = false
    ) -> [SupabaseSyncPlanBlockingReason] {
        var reasons: [SupabaseSyncPlanBlockingReason] = []
        if hasInvalidData {
            reasons.append(.invalidLocalData)
        }
        if hasAccessIssue {
            reasons.append(.authRequired)
        }
        if hasCloudPermissionIssue {
            reasons.append(.cloudPermission)
        }
        if counters.failed > 0 {
            reasons.append(.accessOrSync)
        }
        if counters.reviewNeeded > 0 {
            reasons.append(.cloudConflict)
        }
        if counters.stale > 0 {
            reasons.append(.changedData)
        }
        if reasons.isEmpty, counters.blocked > 0 {
            reasons.append(.cloudConflict)
        }
        return reasons
    }

    private func orderReviewSections(
        _ sections: [SupabaseManualSyncReviewSectionState],
        plan: SupabaseSyncPlan
    ) -> [SupabaseManualSyncReviewSectionState] {
        let ranks = Dictionary(
            uniqueKeysWithValues: plan.sections.enumerated().map { ($0.element.id, $0.offset) }
        )
        return sections.sorted {
            rank(for: $0.id, ranks: ranks) < rank(for: $1.id, ranks: ranks)
        }
    }

    private func rank(
        for id: SupabaseManualSyncReviewSectionID,
        ranks: [SupabaseSyncPlanSectionID: Int]
    ) -> Int {
        switch id {
        case .attention, .sendAttention, .sendBlocked:
            return ranks[.attention] ?? 45
        case .cloudToDevice:
            return ranks[.cloud] ?? 10
        case .deviceToCloud, .readyToSend:
            return ranks[.device] ?? 20
        case .prices:
            return ranks[.prices] ?? 30
        case .activityRegistration:
            return ranks[.activity] ?? 40
        case .finalSummary:
            return 50
        }
    }

    private func reviewPrimaryActionID(
        plan: SupabaseSyncPlan,
        readyAction: SupabaseManualSyncReviewPrimaryActionID
    ) -> SupabaseManualSyncReviewPrimaryActionID {
        switch plan.primaryAction {
        case .apply:
            return readyAction
        case .recheck:
            return .recheck
        case .openDatabase:
            return .openDatabase
        case .signInAgain:
            return authPresentationContext.canSignIn ? .signInAgain : .recheck
        case .none:
            return .none
        }
    }

    private func syncPlanSummaryTitle(_ plan: SupabaseSyncPlan) -> String {
        if plan.blockingReasons.contains(.authRequired) {
            return L("options.supabase.manualSync.plan.summary.blocked.title")
        }
        if plan.blockingReasons.contains(.cloudPermission) {
            return L("options.supabase.manualSync.plan.summary.permission.title")
        }
        return L("options.supabase.manualSync.plan.summary.\(plan.state.rawValue).title")
    }

    private func syncPlanSummaryMessage(_ plan: SupabaseSyncPlan) -> String {
        if plan.blockingReasons.contains(.authRequired) {
            return L("options.supabase.manualSync.plan.summary.access.message")
        }
        if plan.blockingReasons.contains(.cloudPermission) {
            return L("options.supabase.manualSync.plan.summary.permission.message")
        }
        if plan.blockingReasons.contains(.invalidLocalData) {
            return L("options.supabase.manualSync.plan.summary.invalidData.message")
        }
        return L("options.supabase.manualSync.plan.summary.\(plan.state.rawValue).message")
    }

    private func syncPlanAttentionMessage(_ plan: SupabaseSyncPlan) -> String {
        if plan.blockingReasons.contains(.authRequired) {
            return L("options.supabase.manualSync.plan.attention.access")
        }
        if plan.blockingReasons.contains(.cloudPermission) {
            return L("options.supabase.manualSync.plan.attention.permission")
        }
        if plan.blockingReasons.contains(.invalidLocalData) {
            return L("options.supabase.manualSync.plan.attention.invalidData")
        }
        return L("options.supabase.manualSync.plan.attention.\(plan.state.rawValue)")
    }

    private func syncPlanSummarySystemImage(_ plan: SupabaseSyncPlan) -> String {
        if plan.blockingReasons.contains(.authRequired) {
            return "lock.fill"
        }
        if plan.blockingReasons.contains(.cloudPermission) {
            return "exclamationmark.icloud"
        }
        switch plan.state {
        case .ready:
            return "checkmark.circle.fill"
        case .needsReview:
            return "exclamationmark.triangle.fill"
        case .blocked:
            return "xmark.octagon.fill"
        case .stale:
            return "arrow.clockwise.circle.fill"
        case .partial:
            return "exclamationmark.triangle.fill"
        case .failed:
            return "wifi.exclamationmark"
        }
    }

    private func syncPlanSummaryTone(_ plan: SupabaseSyncPlan) -> SupabaseManualSyncReviewSectionTone {
        switch plan.state {
        case .ready:
            return .success
        case .needsReview, .stale, .partial:
            return .attention
        case .blocked, .failed:
            return .blocked
        }
    }

    private func reviewPrimaryActionTitle(
        for primaryID: SupabaseManualSyncReviewPrimaryActionID,
        plan: SupabaseSyncPlan? = nil
    ) -> String {
        switch primaryID {
        case .updateDevice:
            return isApplyingLocalChanges
                ? L("options.supabase.manualSync.review.action.updatingDevice")
                : L("options.supabase.manualSync.review.action.updateDevice")
        case .sendCloudChanges:
            return isSendingCatalogChanges
                ? L("options.supabase.manualSync.push.review.action.sending")
                : L("options.supabase.manualSync.push.review.action.send")
        case .registerCloudActivity:
            if isRegisteringActivities {
                return L("options.supabase.manualSync.activity.review.action.registering")
            }
            if activityRegistrationPhase.prefersRetryTitle {
                return L("options.supabase.manualSync.action.retry")
            }
            return L("options.supabase.manualSync.activity.review.action.register")
        case .recheck:
            if plan?.blockingReasons.contains(.cloudPermission) == true {
                return L("options.supabase.manualSync.action.checkCloud")
            }
            return L("options.supabase.manualSync.action.recheck")
        case .signInAgain:
            return L("options.supabase.manualSync.action.signInAgain")
        case .openDatabase:
            return L("options.supabase.manualSync.action.openDatabase")
        case .none:
            return ""
        }
    }

    private func reviewPrimaryActionSystemImage(
        for primaryID: SupabaseManualSyncReviewPrimaryActionID,
        plan: SupabaseSyncPlan? = nil
    ) -> String {
        switch primaryID {
        case .updateDevice:
            return "arrow.down.circle"
        case .sendCloudChanges:
            return "icloud.and.arrow.up"
        case .registerCloudActivity:
            return activityRegistrationPhase.prefersRetryTitle ? "arrow.clockwise.circle.fill" : "checkmark.icloud"
        case .recheck:
            if plan?.blockingReasons.contains(.cloudPermission) == true {
                return "icloud"
            }
            return "arrow.clockwise.circle.fill"
        case .signInAgain:
            return "person.crop.circle.badge.plus"
        case .openDatabase:
            return "shippingbox"
        case .none:
            return "icloud"
        }
    }

    private func reviewPrimaryActionIsEnabled(
        _ primaryID: SupabaseManualSyncReviewPrimaryActionID
    ) -> Bool {
        switch primaryID {
        case .updateDevice:
            return canApplyLocalChanges && !isReviewMutationInProgress
        case .sendCloudChanges:
            return !isReviewMutationInProgress
        case .registerCloudActivity:
            return activityRegistrationPhase.hasRegisterAction && !isReviewMutationInProgress
        case .recheck:
            return !isReviewMutationInProgress && capabilities.supportsRemoteCloudCheck
        case .signInAgain:
            return !isReviewMutationInProgress && authPresentationContext.canSignIn
        case .openDatabase:
            return !isReviewMutationInProgress
        case .none:
            return false
        }
    }

    private func reviewPrimaryActionIsLoading(
        _ primaryID: SupabaseManualSyncReviewPrimaryActionID
    ) -> Bool {
        switch primaryID {
        case .updateDevice:
            return isApplyingLocalChanges
        case .sendCloudChanges:
            return isSendingCatalogChanges
        case .registerCloudActivity:
            return isRegisteringActivities
        case .recheck, .signInAgain, .openDatabase:
            return false
        case .none:
            return false
        }
    }

    private func reviewSection(
        id: SupabaseManualSyncReviewSectionID,
        titleKey: String,
        messageKey: String,
        systemImage: String,
        tone: SupabaseManualSyncReviewSectionTone
    ) -> SupabaseManualSyncReviewSectionState {
        SupabaseManualSyncReviewSectionState(
            id: id,
            title: L(titleKey),
            message: L(messageKey),
            systemImage: systemImage,
            tone: tone
        )
    }

    private func reviewSection(
        id: SupabaseManualSyncReviewSectionID,
        titleKey: String,
        message: String,
        systemImage: String,
        tone: SupabaseManualSyncReviewSectionTone
    ) -> SupabaseManualSyncReviewSectionState {
        SupabaseManualSyncReviewSectionState(
            id: id,
            title: L(titleKey),
            message: message,
            systemImage: systemImage,
            tone: tone
        )
    }

    private func hasPriceSignals(
        counts: SupabaseManualSyncPrivacyCounts,
        aggregateCounts: SupabaseManualSyncRemotePreviewAggregateCounts
    ) -> Bool {
        counts.pendingPriceChangeCount > 0
            || aggregateCounts.remoteProductPriceCount > 0
            || aggregateCounts.priceHistorySignalCount > 0
    }

    private func productPriceReviewMessage(fallbackHasPriceSignals: Bool) -> String {
        let lines = productPriceSummaryLines(productPriceSummary)
        if !lines.isEmpty {
            return lines.joined(separator: "\n")
        }
        return L(fallbackHasPriceSignals
            ? "options.supabase.manualSync.review.prices.needsUpdate"
            : "options.supabase.manualSync.review.prices.noAction")
    }

    private func productPriceSummaryLines(_ summary: SupabaseManualSyncProductPriceSummary) -> [String] {
        var lines: [String] = []
        let newFound = summary.readyToApply
        if newFound > 0 {
            lines.append(L("options.supabase.manualSync.review.prices.newFound", newFound))
        } else if summary.remoteFound > 0 {
            lines.append(L("options.supabase.manualSync.review.prices.needsUpdate"))
        }
        if summary.applied > 0 {
            lines.append(L("options.supabase.manualSync.review.prices.applied", summary.applied))
        }
        if summary.readyToPush > 0 {
            lines.append(L("options.supabase.manualSync.review.prices.readyToSend", summary.readyToPush))
        }
        if summary.pushed > 0 {
            lines.append(L("options.supabase.manualSync.review.prices.sent", summary.pushed))
        }
        if summary.skippedDuplicate > 0 {
            lines.append(L("options.supabase.manualSync.review.prices.alreadyPresent", summary.skippedDuplicate))
        }
        if summary.skippedConflict > 0 || summary.blocked > 0 {
            lines.append(L("options.supabase.manualSync.review.prices.needsCheck", summary.skippedConflict + summary.blocked))
        }
        if summary.failed > 0 {
            lines.append(L("options.supabase.manualSync.review.prices.notUpdated", summary.failed))
        }
        return lines
    }

    private func hasAttentionSignals(_ counts: SupabaseManualSyncRemotePreviewAggregateCounts) -> Bool {
        counts.conflictCount > 0
            || counts.tombstoneCount > 0
            || counts.warningCount > 0
            || counts.sourceErrorCount > 0
    }

    private func action(
        _ id: SupabaseManualSyncPresentationActionID,
        isEnabled: Bool = true,
        hintKey: String? = nil,
        titleKey: String? = nil
    ) -> SupabaseManualSyncPresentationAction {
        let key: String
        let systemImage: String

        switch id {
        case .signIn:
            key = "signIn"
            systemImage = "person.crop.circle.badge.plus"
        case .realignData:
            key = "realign"
            systemImage = "arrow.down.circle.fill"
        case .checkCloud:
            key = "syncNow"
            systemImage = "icloud"
        case .downloadCloudDatabase:
            key = "downloadCloudDatabase"
            systemImage = "icloud.and.arrow.down"
        case .reviewChanges:
            key = "review"
            systemImage = "doc.text.magnifyingglass"
        case .syncNow:
            key = "syncNow"
            systemImage = "arrow.triangle.2.circlepath.circle.fill"
        case .sendCloudChanges:
            key = "sendToCloud"
            systemImage = "icloud.and.arrow.up"
        case .retry:
            key = "retry"
            systemImage = "arrow.clockwise.circle.fill"
        case .cancel:
            key = "cancel"
            systemImage = "xmark.circle.fill"
        }

        let title = L(titleKey ?? "options.supabase.manualSync.action.\(key)")
        return SupabaseManualSyncPresentationAction(
            id: id,
            title: title,
            systemImage: systemImage,
            isEnabled: isEnabled,
            accessibilityLabel: title,
            accessibilityHint: hintKey.map { L($0) }
        )
    }

    private func state(
        titleKey: String,
        subtitleKey: String?,
        summary: SupabaseManualSyncUserFacingSummary? = nil,
        reviewSheet: SupabaseManualSyncReviewSheetState? = nil,
        badgeKey: String,
        badgeSystemImage: String?,
        primaryAction: SupabaseManualSyncPresentationAction?,
        secondaryAction: SupabaseManualSyncPresentationAction?,
        isRunning: Bool,
        isLoading: Bool,
        hintKey: String? = nil
    ) -> SupabaseManualSyncPresentationState {
        let title = L(titleKey)
        let subtitle = subtitleKey.map { L($0) }
        let statusDetailText = makeStatusDetailText(isRunning: isRunning)
        let userFacingSummary = nonRedundantSummary(summary, title: title, subtitle: subtitle)
        let badgeText = L(badgeKey)
        let hint = hintKey.map { L($0) }
        let accessibilityLabel = [title, subtitle, statusDetailText, userFacingSummary?.message, badgeText]
            .compactMap { $0 }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: ". ")

        return SupabaseManualSyncPresentationState(
            title: title,
            subtitle: subtitle,
            statusDetailText: statusDetailText,
            userFacingSummary: userFacingSummary,
            reviewSheet: reviewSheet,
            progressState: progressState,
            statusBadgeText: badgeText,
            statusBadgeSystemImage: badgeSystemImage,
            primaryAction: primaryAction,
            secondaryAction: secondaryAction,
            isRunning: isRunning,
            isLoading: isLoading,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: hint
        )
    }

    private func makeStatusDetailText(isRunning: Bool) -> String? {
        if progressState.isActive || progressState.phase == .completedWithWarnings {
            return progressState.message
        }
        if isRunning || semiAutomaticState == .checking {
            return L("options.supabase.manualSync.semiAuto.checking")
        }
        if semiAutomaticState == .suggestedCheck {
            return L("options.supabase.manualSync.semiAuto.suggested")
        }
        guard let lastCloudCheckAt else {
            return nil
        }
        let formattedTime = DateFormatter.localizedString(
            from: lastCloudCheckAt,
            dateStyle: .none,
            timeStyle: .short
        )
        return L("options.supabase.manualSync.lastCheck", formattedTime)
    }

    private func nonRedundantSummary(
        _ summary: SupabaseManualSyncUserFacingSummary?,
        title: String,
        subtitle: String?
    ) -> SupabaseManualSyncUserFacingSummary? {
        guard let summary else { return nil }
        if summary.kind.shouldAlwaysShowSummary {
            return summary
        }
        let normalizedMessage = normalizedCopy(summary.message)
        guard normalizedMessage != normalizedCopy(title) else { return nil }
        if let subtitle, normalizedMessage == normalizedCopy(subtitle) {
            return nil
        }
        return summary
    }

    private func normalizedCopy(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".…"))
            .lowercased()
    }
}

private extension SupabaseManualSyncUserFacingSummaryKind {
    var shouldAlwaysShowSummary: Bool {
        switch self {
        case .catalogPushNoChanges,
             .catalogPushSucceeded,
             .catalogPushSucceededNeedsCheck,
             .catalogPushPartial,
             .catalogPushBlocked,
             .catalogPushFailedBeforeWrite,
             .catalogPushInterrupted,
             .catalogPushStale,
             .activityRegistrationSucceeded,
             .activityRegistrationEmpty,
             .activityRegistrationPartial,
             .activityRegistrationAuthRequired,
             .activityRegistrationRetryableFailure,
             .activityRegistrationBlocked,
             .activityRegistrationCancelled:
            return true
        default:
            return false
        }
    }
}

private extension SupabaseManualSyncProductPriceSummary {
    func merging(_ other: SupabaseManualSyncProductPriceSummary) -> SupabaseManualSyncProductPriceSummary {
        SupabaseManualSyncProductPriceSummary(
            remoteFound: max(remoteFound, other.remoteFound),
            localFound: max(localFound, other.localFound),
            readyToApply: max(readyToApply, other.readyToApply),
            readyToPush: max(readyToPush, other.readyToPush),
            applied: applied + other.applied,
            pushed: pushed + other.pushed,
            skippedDuplicate: skippedDuplicate + other.skippedDuplicate,
            skippedConflict: skippedConflict + other.skippedConflict,
            failed: failed + other.failed,
            blocked: blocked + other.blocked
        )
    }

    func withBlockedIncrement(_ amount: Int = 1) -> SupabaseManualSyncProductPriceSummary {
        var copy = self
        copy.blocked += amount
        return copy
    }

    func withFailedIncrement(_ amount: Int = 1) -> SupabaseManualSyncProductPriceSummary {
        var copy = self
        copy.failed += amount
        return copy
    }
}

private extension SupabaseManualSyncCatalogPushPhase {
    var hasReadyCatalogChanges: Bool {
        if case .ready(let summary) = self {
            return summary.hasReadyChanges
        }
        return false
    }

    var needsAttentionAfterSend: Bool {
        switch self {
        case .partial, .sendBlocked, .sendFailed, .stale:
            return true
        case .idle, .checking, .ready, .noChanges, .blocked, .failed, .sending, .succeeded, .succeededNeedsCheck:
            return false
        }
    }
}

private extension SupabaseManualSyncProductPricePushPhase {
    var hasTerminalSummary: Bool {
        switch self {
        case .noChanges, .blocked, .failed, .stale, .succeeded, .partial, .sendFailed:
            return true
        case .idle, .checking, .ready, .sending:
            return false
        }
    }

    var needsAttentionAfterSend: Bool {
        switch self {
        case .partial, .sendFailed, .stale:
            return true
        case .idle, .checking, .ready, .noChanges, .blocked, .failed, .sending, .succeeded:
            return false
        }
    }
}

private extension SupabaseManualSyncActivityRegistrationPhase {
    var shouldShowReviewSection: Bool {
        switch self {
        case .idle:
            return false
        case .ready(let snapshot), .registering(let snapshot):
            return snapshot.hasAnyActivity
        case .finished:
            return true
        }
    }

    var hasRegisterAction: Bool {
        switch self {
        case .ready(let snapshot):
            return snapshot.readyToRegister > 0
        case .finished(let status, let summary):
            switch status {
            case .partialRetryable, .retryableFailure, .cancelled:
                return summary.waiting > 0
            case .success, .empty, .authRequired, .blocked:
                return false
            }
        case .idle, .registering:
            return false
        }
    }

    var hasPrimaryReviewAction: Bool {
        switch self {
        case .ready, .registering, .finished:
            return shouldShowReviewSection
        case .idle:
            return false
        }
    }

    var isTerminal: Bool {
        if case .finished = self {
            return true
        }
        return false
    }

    var prefersRetryTitle: Bool {
        guard case .finished(let status, _) = self else { return false }
        switch status {
        case .partialRetryable, .retryableFailure, .cancelled:
            return true
        case .success, .empty, .authRequired, .blocked:
            return false
        }
    }

    var statusForPresentation: SupabaseManualSyncActivityRegistrationStatus {
        switch self {
        case .idle, .ready:
            return .partialRetryable
        case .registering:
            return .partialRetryable
        case .finished(let status, _):
            return status
        }
    }

    var systemImage: String {
        switch self {
        case .idle, .ready:
            return "checkmark.icloud"
        case .registering:
            return "arrow.triangle.2.circlepath"
        case .finished(let status, _):
            switch status {
            case .success:
                return "checkmark.circle.fill"
            case .empty:
                return "tray"
            case .partialRetryable, .retryableFailure:
                return "exclamationmark.triangle.fill"
            case .authRequired:
                return "lock.fill"
            case .blocked:
                return "xmark.octagon.fill"
            case .cancelled:
                return "xmark.circle.fill"
            }
        }
    }

    var reviewTone: SupabaseManualSyncReviewSectionTone {
        switch self {
        case .idle, .ready, .registering:
            return .neutral
        case .finished(let status, _):
            switch status {
            case .success, .empty:
                return .success
            case .partialRetryable, .retryableFailure, .cancelled:
                return .attention
            case .authRequired, .blocked:
                return .blocked
            }
        }
    }
}

private extension ProductPricePushDryRunPlan {
    var isSafeForReleasePush: Bool {
        isRemoteDedupeSafe
            && summary.readyCandidates > 0
            && summary.blockedTotal == 0
            && summary.conflictSameKeyDifferentPrice == 0
            && summary.localConflictSameKeyDifferentPrice == 0
            && summary.excludedInvalidLocal == 0
            && summary.readyCandidates <= ProductPriceManualPushOptions.defaultBatchLimit
    }
}

private extension ProductPricePushRemoteDedupeStatus {
    var stableFingerprintComponent: String {
        switch self {
        case .notNeeded:
            return "notNeeded"
        case .complete:
            return "complete"
        case .unsafePartialRemoteDedupe(let reason):
            return "unsafe:\(reason.rawValue)"
        }
    }

    var accessOrSyncFailureCount: Int {
        switch self {
        case .notNeeded, .complete:
            return 0
        case .unsafePartialRemoteDedupe(let reason):
            switch reason {
            case .networkOrPermission, .invalidRemoteRows:
                return 1
            case .notNeeded, .complete, .pageBudgetExceeded, .rowBudgetExceeded, .cancelled:
                return 0
            }
        }
    }
}

private extension SupabaseManualPushResult {
    static func failedBeforeWrite(message: String? = nil) -> SupabaseManualPushResult {
        SupabaseManualPushResult(
            status: .failedBeforeWrite,
            supplierCreates: 0,
            supplierUpdates: 0,
            supplierLinks: 0,
            categoryCreates: 0,
            categoryUpdates: 0,
            categoryLinks: 0,
            productCreates: 0,
            productUpdates: 0,
            productLinks: 0,
            baselineRunID: nil,
            message: message
        )
    }
}

private extension SupabaseManualPushTerminalStatus {
    var allowsProductPricePushAfterCatalog: Bool {
        switch self {
        case .completed, .completedBaselineRefreshFailed:
            return true
        case .partial, .blockedBeforeWrite, .failedBeforeWrite:
            return false
        }
    }
}

private extension SupabaseManualSyncRunSummary {
    var hasCompletedRemotePreviewSignals: Bool {
        guard let remotePreviewSummary else { return false }
        return remotePreviewSummary.hasRemoteSignals
            && remotePreviewSummary.isComplete
            && !remotePreviewSummary.isPartial
            && !remotePreviewSummary.wasCancelled
            && remotePreviewSummary.failureCategory == nil
    }

    var hasIncompleteRemotePreview: Bool {
        guard let remotePreviewSummary else { return false }
        return remotePreviewSummary.isPartial || !remotePreviewSummary.isComplete
    }
}
