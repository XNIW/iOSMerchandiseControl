import Combine
import Foundation
import SwiftData

nonisolated struct OptionsSyncAuthSnapshot: Equatable, Sendable {
    var isSignedIn: Bool
    var userID: UUID?
}

protocol OptionsSyncRemoteCountFetching: Sendable {
    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot
}

nonisolated struct OptionsCatalogConflictAttention: Identifiable, Equatable, Sendable {
    let changeID: String
    let remoteID: UUID
    let title: String
    var id: String { changeID }
}

@MainActor
final class OptionsSyncSummaryProvider: ObservableObject {
    @Published private(set) var supabaseBaselineSummary: SupabaseCatalogBaselineDebugSummary = .absent
    @Published private(set) var localDatabaseSummary: LocalDatabasePublicSummary = .empty
    @Published private(set) var syncCountDriftReport: SyncCountDriftReport?
    @Published private(set) var syncCountDriftCheckFailed = false
    @Published private(set) var isCheckingRemoteCounts = false
    @Published private(set) var lastSyncCountDriftCheckedAt: Date?
    @Published private(set) var accountSyncDecision: AccountSyncDecision?
    @Published private(set) var localPendingAttentionCount = 0
    @Published private(set) var catalogConflictAttention: [OptionsCatalogConflictAttention] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isStale = false
    @Published private(set) var lastRefreshedAt: Date?
    @Published private(set) var source = "local"
    @Published private(set) var refreshReason: String?
    @Published private(set) var coalescedEvents = 0
    @Published private(set) var isBusinessSummaryAvailable = false

    #if DEBUG
    // Observation only: this counter never grants permission or replaces the real gate.
    private(set) var businessReadCountForTesting = 0
    private(set) var settledRemoteCountCallbacksForTesting = 0
    private(set) var outstandingRemoteCountCallbacksForTesting = 0
    #endif

    private static let freshRemoteCountVerificationInterval: TimeInterval = 60
    private static let refreshDebounceNanoseconds: UInt64 = 120_000_000
    private let now: () -> Date
    private let defaults: UserDefaults
    private let bindingStore: AccountBindingStore
    private let selectedShopStore: SelectedShopStore
    private var summaryTask: Task<Void, Never>?
    private var driftTask: Task<Void, Never>?
    private var driftTaskID: UUID?
    private var requestID: UUID?
    private var currentScope: OptionsSummaryScope?
    private var publishedBusinessScope: OptionsBusinessSummaryScope?
    private var publishedDecisionScope: OptionsSummaryScope?
    private var publishedDecisionRequestID: UUID?
    private var isRefreshInFlight = false
    private var pendingSummaryRefresh: SummaryRefreshRequest?
    private var isRemoteCountVerificationInFlight = false
    private var lastRemoteCountSnapshot: SyncInventoryCountSnapshot?
    private var authSnapshot = OptionsSyncAuthSnapshot(isSignedIn: false, userID: nil)
    private var localOwnerUserID: UUID?
    private var liveAuthInput: (() -> (OptionsSyncAuthSnapshot, UUID?))?
    private var localStateReadFailed = false
    var hasLocalStateReadFailure: Bool { localStateReadFailed }

    init(
        now: @escaping () -> Date = Date.init,
        defaults: UserDefaults = .standard,
        bindingStore: AccountBindingStore? = nil,
        selectedShopStore: SelectedShopStore? = nil
    ) {
        self.now = now
        self.defaults = defaults
        self.bindingStore = bindingStore ?? AccountBindingStore(defaults: defaults)
        self.selectedShopStore = selectedShopStore ?? SelectedShopStore(defaults: defaults)
    }

    deinit {
        summaryTask?.cancel()
        driftTask?.cancel()
    }

    var hasSyncCountDrift: Bool {
        syncCountDriftReport?.isAligned == false
    }

    var needsRemoteCountVerification: Bool {
        guard authSnapshot.isSignedIn else { return false }
        if syncCountDriftCheckFailed { return true }
        guard syncCountDriftReport != nil else { return true }
        guard let lastSyncCountDriftCheckedAt else { return true }
        return now().timeIntervalSince(lastSyncCountDriftCheckedAt) > Self.freshRemoteCountVerificationInterval
    }

    /// The view checks this at render time, before its change handlers run.
    /// Session refresh is not the authority for otherwise qualified local access.
    func isBusinessSummaryCurrent(context: ModelContext, localOwnerUserID: UUID?) -> Bool {
        guard isBusinessSummaryAvailable, let publishedBusinessScope else { return false }
        let actual = businessScope(context: context, localOwnerUserID: localOwnerUserID)
        return actual.permitsLocalAccess && actual == publishedBusinessScope
            && actual.generation == Task126OwnerStoreGate.localBodyProofAdmissionGeneration()
    }

    /// Administrative decisions have their own metadata/auth snapshot. They do
    /// not require access to the old business body during a store replacement.
    func isAccountDecisionCurrent(
        context: ModelContext,
        localOwnerUserID: UUID?,
        authSnapshot: OptionsSyncAuthSnapshot
    ) -> Bool {
        guard accountSyncDecision != nil,
              publishedDecisionRequestID == requestID,
              let publishedDecisionScope else { return false }
        let actual = scope(context: context, authSnapshot: authSnapshot, localOwnerUserID: localOwnerUserID)
        return publishedDecisionScope == actual
            && actual.business.generation == Task126OwnerStoreGate.localBodyProofAdmissionGeneration()
    }

    func refreshAll(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?,
        pendingChanges: [LocalPendingChange]
    ) {
        refreshAll(context: context, authViewModel: authViewModel,
                   remoteCountFetcher: remoteCountFetcher, refreshReason: "auth-view-model")
    }

    func refreshAll(
        context: ModelContext,
        authSnapshot: OptionsSyncAuthSnapshot,
        localOwnerUserID: UUID? = nil,
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?,
        pendingChanges: [LocalPendingChange]
    ) {
        refreshAll(context: context, authSnapshot: authSnapshot, localOwnerUserID: localOwnerUserID,
                   remoteCountFetcher: remoteCountFetcher, refreshReason: "legacy-pending-array")
    }

    func refreshAll(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?,
        refreshReason: String
    ) {
        liveAuthInput = { [weak authViewModel] in
            guard let authViewModel else {
                return (OptionsSyncAuthSnapshot(isSignedIn: false, userID: nil), nil)
            }
            return (OptionsSyncAuthSnapshot(isSignedIn: authViewModel.isSignedIn,
                                           userID: authViewModel.sessionInfo?.userID),
                    authViewModel.localMutationOwnerUserID)
        }
        receiveRefresh(context: context,
                       authSnapshot: OptionsSyncAuthSnapshot(isSignedIn: authViewModel.isSignedIn,
                                                            userID: authViewModel.sessionInfo?.userID),
                       localOwnerUserID: authViewModel.localMutationOwnerUserID,
                       remoteCountFetcher: remoteCountFetcher, refreshReason: refreshReason)
    }

    func refreshAll(
        context: ModelContext,
        authSnapshot: OptionsSyncAuthSnapshot,
        localOwnerUserID: UUID? = nil,
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?,
        refreshReason: String
    ) {
        liveAuthInput = nil
        receiveRefresh(context: context, authSnapshot: authSnapshot, localOwnerUserID: localOwnerUserID,
                       remoteCountFetcher: remoteCountFetcher, refreshReason: refreshReason)
    }

    func handleAuthChanged(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?,
        pendingChanges: [LocalPendingChange]
    ) {
        refreshAll(context: context, authViewModel: authViewModel,
                   remoteCountFetcher: remoteCountFetcher, refreshReason: "auth-changed")
    }

    func handleLocalDataChanged(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?,
        pendingChanges: [LocalPendingChange]
    ) {
        refreshAll(context: context, authViewModel: authViewModel,
                   remoteCountFetcher: remoteCountFetcher, refreshReason: "local-data-changed")
    }

    func dismissAccountDecision() {
        accountSyncDecision = nil
        publishedDecisionScope = nil
        publishedDecisionRequestID = nil
    }

    private func businessScope(context: ModelContext, localOwnerUserID: UUID?) -> OptionsBusinessSummaryScope {
        OptionsBusinessSummaryScope(
            container: ObjectIdentifier(context.container),
            generation: Task126OwnerStoreGate.localBodyProofAdmissionGeneration(),
            localOwnerUserID: localOwnerUserID,
            selectedShop: localOwnerUserID.flatMap {
                selectedShopStore.selectedShop(accountHash: AccountBindingStore.accountHash(for: $0))
            },
            binding: bindingStore.currentBinding,
            hasPendingJournal: bindingStore.hasPendingReplacementJournal,
            journal: bindingStore.pendingRecoveryJournal,
            permitsLocalAccess: Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                modelContainer: context.container, ownerUserID: localOwnerUserID, defaults: defaults)
        )
    }

    private func scope(
        context: ModelContext, authSnapshot: OptionsSyncAuthSnapshot, localOwnerUserID: UUID?
    ) -> OptionsSummaryScope {
        let accountHash = authSnapshot.userID.map { AccountBindingStore.accountHash(for: $0) }
        return OptionsSummaryScope(
            business: businessScope(context: context, localOwnerUserID: localOwnerUserID),
            auth: authSnapshot,
            decisionShop: accountHash.flatMap { selectedShopStore.selectedShop(accountHash: $0) },
            decisionShopReady: accountHash.map { selectedShopStore.isResolutionReady(accountHash: $0) } ?? false
        )
    }

    private func isCurrent(_ request: SummaryRefreshRequest) -> Bool {
        let (actualAuth, actualOwner) = liveAuthInput?() ?? (authSnapshot, localOwnerUserID)
        return requestID == request.id && currentScope == request.scope
            && request.scope == scope(context: request.context, authSnapshot: actualAuth, localOwnerUserID: actualOwner)
            && request.scope.business.generation == Task126OwnerStoreGate.localBodyProofAdmissionGeneration()
    }

    private func permitsBusinessRead(_ request: SummaryRefreshRequest) -> Bool {
        isCurrent(request) && request.scope.business.permitsLocalAccess
            && Task126OwnerStoreGate.permitsSameScopeLocalAccess(
                modelContainer: request.context.container,
                ownerUserID: request.scope.business.localOwnerUserID, defaults: defaults)
    }

    private func requireBusinessRead(_ request: SummaryRefreshRequest) throws {
        guard permitsBusinessRead(request) else { throw SummaryReadError.scopeChanged }
    }

    private func recordBusinessReadForTesting() {
        #if DEBUG
        businessReadCountForTesting += 1
        Task145StoreLoadFailureObservation.record(.optionsBusinessRead)
        #endif
    }

    private func recordRemoteCountDispatchForTesting() {
        #if DEBUG
        outstandingRemoteCountCallbacksForTesting += 1
        #endif
    }

    private func recordRemoteCountCompletionForTesting() {
        #if DEBUG
        settledRemoteCountCallbacksForTesting += 1
        outstandingRemoteCountCallbacksForTesting -= 1
        #endif
    }

    private func receiveRefresh(
        context: ModelContext, authSnapshot: OptionsSyncAuthSnapshot, localOwnerUserID: UUID?,
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?, refreshReason: String
    ) {
        self.authSnapshot = authSnapshot
        self.localOwnerUserID = localOwnerUserID
        let nextScope = scope(context: context, authSnapshot: authSnapshot, localOwnerUserID: localOwnerUserID)
        dismissAccountDecision()
        if currentScope != nextScope {
            // Invalidation precedes cancellation: noncooperative old callbacks
            // cannot clear new work, publish, or dispatch a pending request.
            requestID = nil
            summaryTask?.cancel()
            summaryTask = nil
            isRefreshInFlight = false
            pendingSummaryRefresh = nil
            resetRemoteCountVerification(clearCache: true)
        }
        if publishedBusinessScope != nextScope.business || !nextScope.business.permitsLocalAccess {
            isBusinessSummaryAvailable = false
            catalogConflictAttention = []
            publishedBusinessScope = nil
        }
        currentScope = nextScope
        scheduleSummaryRefresh(SummaryRefreshRequest(
            id: UUID(), scope: nextScope, context: context,
            remoteCountFetcher: remoteCountFetcher, refreshReason: refreshReason))
    }

    private func scheduleSummaryRefresh(_ request: SummaryRefreshRequest) {
        refreshReason = request.refreshReason
        source = "local"
        if isRefreshInFlight {
            coalescedEvents += 1
            isStale = true
            pendingSummaryRefresh = request
            return
        }
        requestID = request.id
        resetRemoteCountVerification(clearCache: false)
        isRefreshInFlight = true
        isLoading = true
        isStale = lastRefreshedAt != nil
        localStateReadFailed = false
        summaryTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.refreshDebounceNanoseconds)
                guard let self, self.isCurrent(request) else { return }
                try Task.checkCancellation()
                if request.scope.business.permitsLocalAccess {
                    try self.refreshBusinessSummary(request)
                } else {
                    self.isBusinessSummaryAvailable = false
                    self.catalogConflictAttention = []
                }
                guard self.isCurrent(request) else { return }
                self.isLoading = false
                self.isStale = false
                self.isRefreshInFlight = false
                self.summaryTask = nil
                self.refreshAccountSyncDecision(request)
                if !self.runPendingSummaryRefreshIfNeeded(after: request) {
                    self.refreshSyncCountDriftIfNeeded(request)
                }
            } catch is CancellationError {
                guard let self, self.isCurrent(request) else { return }
                self.isRefreshInFlight = false
                self.isLoading = false
                self.summaryTask = nil
                _ = self.runPendingSummaryRefreshIfNeeded(after: request)
            } catch {
                guard let self, self.isCurrent(request) else { return }
                self.localStateReadFailed = true
                self.isBusinessSummaryAvailable = false
                self.catalogConflictAttention = []
                self.publishedBusinessScope = nil
                self.isLoading = false
                self.isStale = true
                self.isRefreshInFlight = false
                self.summaryTask = nil
                self.refreshAccountSyncDecision(request)
                _ = self.runPendingSummaryRefreshIfNeeded(after: request)
            }
        }
    }

    private func refreshBusinessSummary(_ request: SummaryRefreshRequest) throws {
        try requireBusinessRead(request)
        recordBusinessReadForTesting()
        let local = try LocalDatabasePublicSummary.makeReconciliationAware(context: request.context)
        try requireBusinessRead(request)
        recordBusinessReadForTesting()
        let baseline = try SupabaseCatalogBaselineReader().debugSummary(
            context: request.context, currentUserUUID: request.scope.business.localOwnerUserID)
        try requireBusinessRead(request)
        recordBusinessReadForTesting()
        let pending = try OptionsPendingAttentionCounter.countAll(context: request.context)
        try requireBusinessRead(request)
        let attention = try catalogAttention(request)
        try requireBusinessRead(request)
        catalogConflictAttention = attention
        localDatabaseSummary = LocalDatabasePublicSummary(
            products: local.products, suppliers: local.suppliers, categories: local.categories,
            productPrices: local.productPrices, historySessions: local.historySessions,
            pendingOutbox: pending, lastSuccessfulSync: baseline.appliedAt)
        supabaseBaselineSummary = baseline
        localPendingAttentionCount = pending
        publishedBusinessScope = request.scope.business
        isBusinessSummaryAvailable = true
        lastRefreshedAt = now()
    }

    private func catalogAttention(_ request: SummaryRefreshRequest) throws -> [OptionsCatalogConflictAttention] {
        guard let owner = request.scope.business.localOwnerUserID,
              let store = request.scope.business.selectedShop?.localStoreIdentity else { return [] }
        let ids = try LocalCatalogConflictResolutionStore.attentionProductChangeIDs(
            context: request.context, ownerUserID: owner, storeIdentity: store)
        guard !ids.isEmpty else { return [] }
        try requireBusinessRead(request)
        let changes = try request.context.fetch(FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate { ids.contains($0.changeID) }))
        var seen: Set<UUID> = []
        return try changes.compactMap { change in
            guard let remoteID = change.entityRemoteID, seen.insert(remoteID).inserted else { return nil }
            try requireBusinessRead(request)
            var descriptor = FetchDescriptor<Product>(predicate: #Predicate { $0.remoteID == remoteID })
            descriptor.fetchLimit = 2
            let products = try request.context.fetch(descriptor)
            let product = products.count == 1 ? products.first : nil
            return OptionsCatalogConflictAttention(changeID: change.changeID, remoteID: remoteID,
                title: product?.productName ?? product?.barcode ?? L("product.resolution.action"))
        }
    }

    @discardableResult
    private func runPendingSummaryRefreshIfNeeded(after request: SummaryRefreshRequest) -> Bool {
        guard isCurrent(request), let pending = pendingSummaryRefresh,
              pending.scope == request.scope else { return false }
        pendingSummaryRefresh = nil
        scheduleSummaryRefresh(pending)
        return true
    }

    private func refreshSyncCountDriftIfNeeded(_ request: SummaryRefreshRequest) {
        guard permitsBusinessRead(request), isBusinessSummaryAvailable else { return }
        guard request.scope.auth.isSignedIn,
              let remoteOwner = request.scope.auth.userID,
              remoteOwner == request.scope.business.localOwnerUserID else {
            resetRemoteCountVerification(clearCache: true)
            return
        }
        guard let service = request.remoteCountFetcher else {
            resetRemoteCountVerification(clearCache: true)
            syncCountDriftCheckFailed = true
            return
        }
        if !needsRemoteCountVerification, let lastRemoteCountSnapshot {
            updateDriftReport(request, remote: lastRemoteCountSnapshot, checkedAt: lastSyncCountDriftCheckedAt)
            return
        }
        guard !isRemoteCountVerificationInFlight else { return }
        let taskID = UUID()
        driftTaskID = taskID
        isRemoteCountVerificationInFlight = true
        isCheckingRemoteCounts = true
        recordRemoteCountDispatchForTesting()
        driftTask = Task { @MainActor [weak self] in
            defer { self?.recordRemoteCountCompletionForTesting() }
            do {
                // Scheduling can outlive the request's scope or cancellation.
                guard !Task.isCancelled,
                      self?.driftTaskID == taskID,
                      self?.permitsBusinessRead(request) == true else { return }
                let remote = try await service.fetchReconciliationRemoteCounts()
                guard let self, self.driftTaskID == taskID, self.permitsBusinessRead(request) else { return }
                try Task.checkCancellation()
                try self.requireBusinessRead(request)
                self.recordBusinessReadForTesting()
                let local = try LocalDatabasePublicSummary.makeReconciliationAware(context: request.context)
                guard self.driftTaskID == taskID, self.permitsBusinessRead(request) else { return }
                self.lastRemoteCountSnapshot = remote
                self.syncCountDriftReport = SyncCountDriftReport.compare(local: local, remote: remote)
                self.syncCountDriftCheckFailed = false
                self.lastSyncCountDriftCheckedAt = self.now()
                self.finishDrift(taskID: taskID, request: request)
                self.refreshAccountSyncDecision(request)
            } catch is CancellationError {
                guard let self, self.driftTaskID == taskID, self.permitsBusinessRead(request) else { return }
                self.finishDrift(taskID: taskID, request: request)
            } catch {
                guard let self, self.driftTaskID == taskID, self.permitsBusinessRead(request) else { return }
                self.lastRemoteCountSnapshot = nil
                self.syncCountDriftReport = nil
                self.syncCountDriftCheckFailed = true
                self.lastSyncCountDriftCheckedAt = self.now()
                self.finishDrift(taskID: taskID, request: request)
                self.refreshAccountSyncDecision(request)
            }
        }
    }

    private func finishDrift(taskID: UUID, request: SummaryRefreshRequest) {
        guard driftTaskID == taskID, permitsBusinessRead(request) else { return }
        isRemoteCountVerificationInFlight = false
        isCheckingRemoteCounts = false
        driftTask = nil
        driftTaskID = nil
    }

    private func updateDriftReport(
        _ request: SummaryRefreshRequest, remote: SyncInventoryCountSnapshot, checkedAt: Date?
    ) {
        guard permitsBusinessRead(request) else { return }
        do {
            try requireBusinessRead(request)
            recordBusinessReadForTesting()
            let local = try LocalDatabasePublicSummary.makeReconciliationAware(context: request.context)
            guard permitsBusinessRead(request) else { return }
            syncCountDriftReport = SyncCountDriftReport.compare(local: local, remote: remote)
            syncCountDriftCheckFailed = false
            lastSyncCountDriftCheckedAt = checkedAt
        } catch {
            guard permitsBusinessRead(request) else { return }
            syncCountDriftReport = nil
            syncCountDriftCheckFailed = true
            lastSyncCountDriftCheckedAt = now()
        }
        refreshAccountSyncDecision(request)
    }

    private func resetRemoteCountVerification(clearCache: Bool) {
        driftTaskID = nil
        driftTask?.cancel()
        driftTask = nil
        isRemoteCountVerificationInFlight = false
        isCheckingRemoteCounts = false
        if clearCache {
            lastRemoteCountSnapshot = nil
            lastSyncCountDriftCheckedAt = nil
            syncCountDriftReport = nil
            syncCountDriftCheckFailed = false
        }
    }

    private func refreshAccountSyncDecision(_ request: SummaryRefreshRequest) {
        guard isCurrent(request) else { return }
        guard request.scope.auth.isSignedIn, let userID = request.scope.auth.userID else {
            dismissAccountDecision()
            return
        }
        let hasBusinessSummary = isBusinessSummaryCurrent(
            context: request.context, localOwnerUserID: request.scope.business.localOwnerUserID)
        var resolution: OwnerStoreBindingResolution
        if request.scope.decisionShopReady,
           let activeStoreIdentity = request.scope.decisionShop?.localStoreIdentity {
            if bindingStore.hasPendingReplacementJournal, bindingStore.pendingRecoveryJournal == nil {
                resolution = .reviewRequired(.replacementInterrupted)
            } else if localStateReadFailed {
                resolution = .reviewRequired(.localStateUnavailable)
            } else if hasBusinessSummary {
                let hasLocalData = localDatabaseSummary.products > 0
                    || localDatabaseSummary.suppliers > 0
                    || localDatabaseSummary.categories > 0
                    || localDatabaseSummary.productPrices > 0
                    || localDatabaseSummary.historySessions > 0
                    || localPendingAttentionCount > 0
                    || supabaseBaselineSummary.status != .absent
                resolution = bindingStore.resolveOwnerStoreBinding(
                    userID: userID, activeStoreIdentity: activeStoreIdentity,
                    isLocalStoreCompletelyEmpty: !hasLocalData,
                    stateReadFailed: localStateReadFailed, allowAutoBind: false)
            } else if let localOwner = request.scope.business.localOwnerUserID,
                      let binding = bindingStore.currentBinding,
                      binding.accountHash == AccountBindingStore.accountHash(for: localOwner),
                      !binding.storeIdentity.isEmpty, binding.storeIdentity != .anonymous {
                // A real binding makes the unbound/emptiness branch unreachable.
                // False grants no emptiness proof and performs no business read.
                let metadataResolution = bindingStore.resolveOwnerStoreBinding(
                    userID: userID, activeStoreIdentity: activeStoreIdentity,
                    isLocalStoreCompletelyEmpty: false, allowAutoBind: false)
                // Metadata may explain a mismatch; it cannot establish that an
                // unreadable same-scope body is ready or authorize a replacement.
                resolution = metadataResolution.allowsAutomaticSync
                    ? .reviewRequired(.localStateUnavailable) : metadataResolution
            } else {
                resolution = .reviewRequired(.localStateUnavailable)
            }
        } else {
            resolution = .reviewRequired(.shopContextUnavailable)
        }
        if hasBusinessSummary {
            resolution = Self.applyingBaselineAccountMismatch(
                to: resolution, baselineStatus: supabaseBaselineSummary.status)
        }
        guard isCurrent(request) else { return }
        publishedDecisionScope = request.scope
        publishedDecisionRequestID = request.id
        guard case .reviewRequired(let reason) = resolution else {
            accountSyncDecision = nil
            return
        }
        accountSyncDecision = AccountSyncDecision(
            action: .promptOwnerStoreReview(reason),
            defaultSafeAction: .cancel,
            remoteMutation: .blockedUntilUserDecision,
            pendingHandling: reason == .unboundDirty
                ? .keepUnboundUntilDecision : .keepPendingWithOriginalOwner,
            conflictPolicy: reason == .unboundDirty ? .noSilentMerge : .noCrossAccountMerge,
            rollback: .cancelLeavesRemoteUntouched,
            testID: "OWNER-STORE-\(reason.rawValue)"
        )
    }

    static func applyingBaselineAccountMismatch(
        to resolution: OwnerStoreBindingResolution,
        baselineStatus: SupabaseCatalogBaselineDebugStatus
    ) -> OwnerStoreBindingResolution {
        guard resolution.allowsAutomaticSync,
              baselineStatus == .accountMismatch else {
            return resolution
        }
        return .reviewRequired(.accountMismatch)
    }

    private var remoteDatasetState: RemoteDatasetState {
        guard !syncCountDriftCheckFailed,
              let syncCountDriftReport else {
            return .unknown
        }
        let remote = syncCountDriftReport.remote
        return remote.products > 0
            || remote.suppliers > 0
            || remote.categories > 0
            || remote.productPrices > 0
            || remote.historySessions > 0 ? .nonEmpty : .empty
    }

    private func pendingOwnerState(
        currentAccountHash: String,
        binding: AccountBinding?
    ) -> PendingOwnerState {
        guard localPendingAttentionCount > 0 else { return .none }
        guard let binding else { return .anonymous }
        return binding.accountHash == currentAccountHash ? .sameAccount : .differentAccount
    }

}

private enum SummaryReadError: Error {
    case scopeChanged
}

private struct OptionsBusinessSummaryScope: Equatable {
    let container: ObjectIdentifier
    let generation: UInt64
    let localOwnerUserID: UUID?
    let selectedShop: SelectedShop?
    let binding: AccountBinding?
    let hasPendingJournal: Bool
    let journal: AccountRecoveryJournalSnapshot?
    let permitsLocalAccess: Bool
}

private struct OptionsSummaryScope: Equatable {
    let business: OptionsBusinessSummaryScope
    let auth: OptionsSyncAuthSnapshot
    let decisionShop: SelectedShop?
    let decisionShopReady: Bool
}

@MainActor
private struct SummaryRefreshRequest {
    let id: UUID
    let scope: OptionsSummaryScope
    let context: ModelContext
    let remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?
    let refreshReason: String
}

nonisolated enum OptionsPendingAttentionCounter {
    static func countAll(context: ModelContext) throws -> Int {
        let resolved = Array(try LocalCatalogConflictResolutionStore.resolvedChangeIDs(context: context))
        let terminalSuperseded = LocalPendingChangeStatus.superseded.rawValue
        let terminalAcknowledged = LocalPendingChangeStatus.acknowledged.rawValue
        let sent = SyncEventOutboxStatus.sent.rawValue
        let localOnly = SyncEventOutboxStatus.localOnly.rawValue
        let pendingChanges = try context.fetchCount(FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.statusRaw != terminalSuperseded
                    && change.statusRaw != terminalAcknowledged
                    && !resolved.contains(change.changeID)
            }
        ))
        let eventOutbox = try context.fetchCount(FetchDescriptor<SyncEventOutboxEntry>(
            predicate: #Predicate<SyncEventOutboxEntry> { entry in
                entry.statusRaw != sent && entry.statusRaw != localOnly
            }
        ))
        return pendingChanges + eventOutbox
    }

    static func count(
        context: ModelContext,
        ownerUserID: UUID?,
        storeIdentity: LocalStoreIdentity = LocalStoreIdentity(rawValue: Task126SyncPolicy.defaultStoreId)
    ) throws -> Int {
        let resolved = Array(try LocalCatalogConflictResolutionStore.resolvedChangeIDs(context: context))
        let terminalSuperseded = LocalPendingChangeStatus.superseded.rawValue
        let terminalAcknowledged = LocalPendingChangeStatus.acknowledged.rawValue
        let activeStoreId = storeIdentity.storeId
        let activeLocalStoreId = storeIdentity.localStoreId
        if let owner = ownerUserID?.uuidString.lowercased() {
            return try context.fetchCount(FetchDescriptor<LocalPendingChange>(
                predicate: #Predicate<LocalPendingChange> { change in
                    change.ownerUserID == owner
                        && change.storeId == activeStoreId
                        && change.localStoreId == activeLocalStoreId
                        && change.statusRaw != terminalSuperseded
                        && change.statusRaw != terminalAcknowledged
                        && !resolved.contains(change.changeID)
                }
            ))
        }
        return try context.fetchCount(FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.ownerUserID == nil
                    && change.storeId == activeStoreId
                    && change.localStoreId == activeLocalStoreId
                    && change.statusRaw != terminalSuperseded
                    && change.statusRaw != terminalAcknowledged
                    && !resolved.contains(change.changeID)
            }
        ))
    }
}
