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

@MainActor
final class OptionsSyncSummaryProvider: ObservableObject {
    @Published private(set) var supabaseBaselineSummary: SupabaseCatalogBaselineDebugSummary = .absent
    @Published private(set) var localDatabaseSummary: LocalDatabasePublicSummary = .empty
    @Published private(set) var syncCountDriftReport: SyncCountDriftReport?
    @Published private(set) var syncCountDriftCheckFailed = false
    @Published private(set) var lastSyncCountDriftCheckedAt: Date?
    @Published private(set) var accountSyncDecision: AccountSyncDecision?
    @Published private(set) var localPendingAttentionCount = 0
    @Published private(set) var isLoading = false
    @Published private(set) var isStale = false
    @Published private(set) var lastRefreshedAt: Date?
    @Published private(set) var source = "local"
    @Published private(set) var refreshReason: String?
    @Published private(set) var coalescedEvents = 0

    private static let freshRemoteCountVerificationInterval: TimeInterval = 60
    private static let refreshDebounceNanoseconds: UInt64 = 120_000_000
    private let now: () -> Date
    private var summaryTask: Task<Void, Never>?
    private var driftTask: Task<Void, Never>?
    private var driftTaskID: UUID?
    private var isRefreshInFlight = false
    private var pendingSummaryRefresh: SummaryRefreshRequest?
    private var isRemoteCountVerificationInFlight = false
    private var lastRemoteCountSnapshot: SyncInventoryCountSnapshot?
    private var isSignedIn = false
    private var currentUserID: UUID?

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
    }

    deinit {
        summaryTask?.cancel()
        driftTask?.cancel()
    }

    var hasSyncCountDrift: Bool {
        syncCountDriftReport?.isAligned == false
    }

    var needsRemoteCountVerification: Bool {
        guard isSignedIn else { return false }
        if syncCountDriftCheckFailed { return true }
        guard syncCountDriftReport != nil else { return true }
        guard let lastSyncCountDriftCheckedAt else { return true }
        return now().timeIntervalSince(lastSyncCountDriftCheckedAt) > Self.freshRemoteCountVerificationInterval
    }

    func refreshAll(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?,
        pendingChanges: [LocalPendingChange]
    ) {
        refreshAll(
            context: context,
            authSnapshot: OptionsSyncAuthSnapshot(
                isSignedIn: authViewModel.isSignedIn,
                userID: authViewModel.sessionInfo?.userID
            ),
            remoteCountFetcher: remoteCountFetcher,
            refreshReason: "auth-view-model"
        )
    }

    func refreshAll(
        context: ModelContext,
        authSnapshot: OptionsSyncAuthSnapshot,
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?,
        pendingChanges: [LocalPendingChange]
    ) {
        refreshAll(
            context: context,
            authSnapshot: authSnapshot,
            remoteCountFetcher: remoteCountFetcher,
            refreshReason: "legacy-pending-array"
        )
    }

    func refreshAll(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?,
        refreshReason: String
    ) {
        refreshAll(
            context: context,
            authSnapshot: OptionsSyncAuthSnapshot(
                isSignedIn: authViewModel.isSignedIn,
                userID: authViewModel.sessionInfo?.userID
            ),
            remoteCountFetcher: remoteCountFetcher,
            refreshReason: refreshReason
        )
    }

    func refreshAll(
        context: ModelContext,
        authSnapshot: OptionsSyncAuthSnapshot,
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?,
        refreshReason: String
    ) {
        updateAuthSnapshot(authSnapshot)
        scheduleSummaryRefresh(
            context: context,
            remoteCountFetcher: remoteCountFetcher,
            refreshReason: refreshReason
        )
    }

    func handleAuthChanged(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?,
        pendingChanges: [LocalPendingChange]
    ) {
        refreshAll(
            context: context,
            authViewModel: authViewModel,
            remoteCountFetcher: remoteCountFetcher,
            refreshReason: "auth-changed"
        )
    }

    func handleLocalDataChanged(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?,
        pendingChanges: [LocalPendingChange]
    ) {
        refreshAll(
            context: context,
            authViewModel: authViewModel,
            remoteCountFetcher: remoteCountFetcher,
            refreshReason: "local-data-changed"
        )
    }

    func dismissAccountDecision() {
        accountSyncDecision = nil
    }

    private func updateAuthSnapshot(_ authSnapshot: OptionsSyncAuthSnapshot) {
        let previousUserID = currentUserID
        isSignedIn = authSnapshot.isSignedIn
        currentUserID = authSnapshot.userID

        if previousUserID != currentUserID {
            resetRemoteCountVerification(clearFailure: true)
        }
    }

    private func refreshSupabaseBaselineSummary(context: ModelContext) {
        do {
            supabaseBaselineSummary = try SupabaseCatalogBaselineReader().debugSummary(
                context: context,
                currentUserUUID: currentUserID
            )
        } catch {
            supabaseBaselineSummary = .absent
        }
    }

    private func refreshLocalDatabaseSummary(context: ModelContext) {
        do {
            let snapshot = try LocalDatabasePublicSummary.makeReconciliationAware(context: context)
            localDatabaseSummary = LocalDatabasePublicSummary(
                products: snapshot.products,
                suppliers: snapshot.suppliers,
                categories: snapshot.categories,
                productPrices: snapshot.productPrices,
                historySessions: snapshot.historySessions
            )
        } catch {
            localDatabaseSummary = .empty
        }
    }

    private func scheduleSummaryRefresh(
        context: ModelContext,
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?,
        refreshReason: String
    ) {
        self.refreshReason = refreshReason
        source = "local"
        if isRefreshInFlight {
            coalescedEvents += 1
            isStale = true
            pendingSummaryRefresh = SummaryRefreshRequest(
                context: context,
                remoteCountFetcher: remoteCountFetcher,
                refreshReason: refreshReason
            )
            return
        }
        isRefreshInFlight = true
        isLoading = true
        isStale = lastRefreshedAt != nil
        summaryTask?.cancel()
        summaryTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: Self.refreshDebounceNanoseconds)
                try Task.checkCancellation()
                guard let self else { return }
                self.refreshLocalDatabaseSummary(context: context)
                self.refreshSupabaseBaselineSummary(context: context)
                self.refreshLocalPendingAttentionCount(context: context)
                self.isLoading = false
                self.isStale = false
                self.lastRefreshedAt = self.now()
                self.isRefreshInFlight = false
                self.summaryTask = nil
                self.refreshSyncCountDriftIfNeeded(context: context, remoteCountFetcher: remoteCountFetcher)
                self.refreshAccountSyncDecision()
                self.runPendingSummaryRefreshIfNeeded()
            } catch is CancellationError {
                guard let self else { return }
                self.isRefreshInFlight = false
                self.isLoading = false
                self.summaryTask = nil
                self.runPendingSummaryRefreshIfNeeded()
            } catch {
                guard let self else { return }
                self.localDatabaseSummary = .empty
                self.localPendingAttentionCount = 0
                self.isLoading = false
                self.isStale = true
                self.isRefreshInFlight = false
                self.summaryTask = nil
                self.refreshAccountSyncDecision()
                self.runPendingSummaryRefreshIfNeeded()
            }
        }
    }

    private func runPendingSummaryRefreshIfNeeded() {
        guard let pendingSummaryRefresh else { return }
        self.pendingSummaryRefresh = nil
        scheduleSummaryRefresh(
            context: pendingSummaryRefresh.context,
            remoteCountFetcher: pendingSummaryRefresh.remoteCountFetcher,
            refreshReason: pendingSummaryRefresh.refreshReason
        )
    }

    private func refreshLocalPendingAttentionCount(context: ModelContext) {
        do {
            localPendingAttentionCount = try OptionsPendingAttentionCounter.count(
                context: context,
                ownerUserID: currentUserID,
                storeIdentity: AccountBindingStore().currentBinding?.storeIdentity
                    ?? LocalStoreIdentity(rawValue: Task126SyncPolicy.defaultStoreId)
            )
        } catch {
            localPendingAttentionCount = 0
            isStale = true
        }
    }

    private func refreshSyncCountDriftIfNeeded(
        context: ModelContext,
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?
    ) {
        guard isSignedIn else {
            resetRemoteCountVerification(clearFailure: true)
            syncCountDriftReport = nil
            refreshAccountSyncDecision()
            return
        }
        guard let service = remoteCountFetcher else {
            resetRemoteCountVerification(clearFailure: false)
            syncCountDriftReport = nil
            syncCountDriftCheckFailed = true
            refreshAccountSyncDecision()
            return
        }

        if !needsRemoteCountVerification,
           let lastRemoteCountSnapshot {
            updateDriftReport(context: context, remote: lastRemoteCountSnapshot, checkedAt: lastSyncCountDriftCheckedAt)
            return
        }

        guard !isRemoteCountVerificationInFlight else {
            if let lastRemoteCountSnapshot {
                updateDriftReport(context: context, remote: lastRemoteCountSnapshot, checkedAt: lastSyncCountDriftCheckedAt)
            }
            return
        }

        let requestedUserID = currentUserID
        let taskID = UUID()
        driftTaskID = taskID
        isRemoteCountVerificationInFlight = true
        driftTask = Task { @MainActor [weak self] in
            do {
                let remote = try await service.fetchReconciliationRemoteCounts()
                try Task.checkCancellation()
                let local = try LocalDatabasePublicSummary.makeReconciliationAware(context: context)
                let report = SyncCountDriftReport.compare(local: local, remote: remote)
                guard self?.driftTaskID == taskID,
                      self?.currentUserID == requestedUserID else {
                    return
                }
                self?.lastRemoteCountSnapshot = remote
                self?.syncCountDriftReport = report
                self?.syncCountDriftCheckFailed = false
                self?.lastSyncCountDriftCheckedAt = self?.now()
                self?.isRemoteCountVerificationInFlight = false
                self?.driftTask = nil
                self?.driftTaskID = nil
                self?.refreshAccountSyncDecision()
            } catch is CancellationError {
                if self?.driftTaskID == taskID {
                    self?.isRemoteCountVerificationInFlight = false
                    self?.driftTask = nil
                    self?.driftTaskID = nil
                }
                return
            } catch {
                guard self?.driftTaskID == taskID,
                      self?.currentUserID == requestedUserID else {
                    return
                }
                self?.lastRemoteCountSnapshot = nil
                self?.syncCountDriftReport = nil
                self?.syncCountDriftCheckFailed = true
                self?.lastSyncCountDriftCheckedAt = self?.now()
                self?.isRemoteCountVerificationInFlight = false
                self?.driftTask = nil
                self?.driftTaskID = nil
                self?.refreshAccountSyncDecision()
            }
        }
    }

    private func updateDriftReport(
        context: ModelContext,
        remote: SyncInventoryCountSnapshot,
        checkedAt: Date?
    ) {
        do {
            let local = try LocalDatabasePublicSummary.makeReconciliationAware(context: context)
            syncCountDriftReport = SyncCountDriftReport.compare(local: local, remote: remote)
            syncCountDriftCheckFailed = false
            lastSyncCountDriftCheckedAt = checkedAt
        } catch {
            syncCountDriftReport = nil
            syncCountDriftCheckFailed = true
            lastSyncCountDriftCheckedAt = now()
        }
        refreshAccountSyncDecision()
    }

    private func resetRemoteCountVerification(clearFailure: Bool) {
        driftTask?.cancel()
        driftTask = nil
        driftTaskID = nil
        isRemoteCountVerificationInFlight = false
        lastRemoteCountSnapshot = nil
        lastSyncCountDriftCheckedAt = nil
        if clearFailure {
            syncCountDriftCheckFailed = false
        }
    }

    private func refreshAccountSyncDecision() {
        guard isSignedIn, let userID = currentUserID else {
            accountSyncDecision = nil
            return
        }

        let accountHash = AccountBindingStore.accountHash(for: userID)
        let hasLocalData = localDatabaseSummary.products > 0
            || localDatabaseSummary.suppliers > 0
            || localDatabaseSummary.categories > 0
            || localDatabaseSummary.productPrices > 0
            || localDatabaseSummary.historySessions > 0
        let binding = AccountBindingStore().currentBinding
        let localStore: LocalStoreAccountState
        let trigger: AccountSyncTrigger

        if let binding, binding.accountHash != accountHash {
            localStore = .bound(accountHash: binding.accountHash, hasData: hasLocalData)
            trigger = .switchAccount(from: binding.accountHash, to: accountHash)
        } else if let binding {
            localStore = .bound(accountHash: binding.accountHash, hasData: hasLocalData)
            trigger = .reconnect(accountHash: accountHash)
        } else {
            localStore = .anonymous(hasData: hasLocalData)
            trigger = .login(accountHash: accountHash)
        }

        let decision = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: trigger,
                localStore: localStore,
                remoteDataset: remoteDatasetState,
                pendingOwner: pendingOwnerState(currentAccountHash: accountHash, binding: binding)
            )
        )
        accountSyncDecision = decision.requiresUserDecision ? decision : nil
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

@MainActor
private struct SummaryRefreshRequest {
    let context: ModelContext
    let remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?
    let refreshReason: String
}

nonisolated enum OptionsPendingAttentionCounter {
    static func count(
        context: ModelContext,
        ownerUserID: UUID?,
        storeIdentity: LocalStoreIdentity = LocalStoreIdentity(rawValue: Task126SyncPolicy.defaultStoreId)
    ) throws -> Int {
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
            }
        ))
    }
}
