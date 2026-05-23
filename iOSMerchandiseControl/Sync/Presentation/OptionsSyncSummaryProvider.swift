import Combine
import Foundation
import SwiftData

@MainActor
final class OptionsSyncSummaryProvider: ObservableObject {
    @Published private(set) var supabaseBaselineSummary: SupabaseCatalogBaselineDebugSummary = .absent
    @Published private(set) var localDatabaseSummary: LocalDatabasePublicSummary = .empty
    @Published private(set) var syncCountDriftReport: SyncCountDriftReport?
    @Published private(set) var syncCountDriftCheckFailed = false
    @Published private(set) var lastSyncCountDriftCheckedAt: Date?
    @Published private(set) var accountSyncDecision: AccountSyncDecision?
    @Published private(set) var localPendingAttentionCount = 0

    private static let freshRemoteCountVerificationInterval: TimeInterval = 60
    private var driftTask: Task<Void, Never>?
    private var isSignedIn = false
    private var currentUserID: UUID?

    var hasSyncCountDrift: Bool {
        syncCountDriftReport?.isAligned == false
    }

    var needsRemoteCountVerification: Bool {
        guard isSignedIn else { return false }
        if syncCountDriftCheckFailed { return true }
        guard syncCountDriftReport != nil else { return true }
        guard let lastSyncCountDriftCheckedAt else { return true }
        return Date().timeIntervalSince(lastSyncCountDriftCheckedAt) > Self.freshRemoteCountVerificationInterval
    }

    func refreshAll(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        inventoryService: SupabaseInventoryService?,
        pendingChanges: [LocalPendingChange]
    ) {
        updateAuthSnapshot(authViewModel)
        refreshLocalDatabaseSummary(context: context)
        refreshSupabaseBaselineSummary(context: context)
        refreshLocalPendingAttentionCount(pendingChanges)
        refreshSyncCountDriftIfNeeded(context: context, inventoryService: inventoryService)
        refreshAccountSyncDecision()
    }

    func handleAuthChanged(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        inventoryService: SupabaseInventoryService?,
        pendingChanges: [LocalPendingChange]
    ) {
        refreshAll(
            context: context,
            authViewModel: authViewModel,
            inventoryService: inventoryService,
            pendingChanges: pendingChanges
        )
    }

    func handleLocalDataChanged(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        inventoryService: SupabaseInventoryService?,
        pendingChanges: [LocalPendingChange]
    ) {
        refreshAll(
            context: context,
            authViewModel: authViewModel,
            inventoryService: inventoryService,
            pendingChanges: pendingChanges
        )
    }

    func dismissAccountDecision() {
        accountSyncDecision = nil
    }

    private func updateAuthSnapshot(_ authViewModel: SupabaseAuthViewModel) {
        isSignedIn = authViewModel.isSignedIn
        currentUserID = authViewModel.sessionInfo?.userID
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

    private func refreshLocalPendingAttentionCount(_ pendingChanges: [LocalPendingChange]) {
        localPendingAttentionCount = pendingChanges.filter(isRelevantToCurrentAccount).count
    }

    private func refreshSyncCountDriftIfNeeded(
        context: ModelContext,
        inventoryService: SupabaseInventoryService?
    ) {
        guard isSignedIn else {
            driftTask?.cancel()
            syncCountDriftReport = nil
            syncCountDriftCheckFailed = false
            lastSyncCountDriftCheckedAt = nil
            refreshAccountSyncDecision()
            return
        }
        guard let service = inventoryService else {
            driftTask?.cancel()
            syncCountDriftReport = nil
            syncCountDriftCheckFailed = true
            lastSyncCountDriftCheckedAt = nil
            refreshAccountSyncDecision()
            return
        }

        driftTask?.cancel()
        driftTask = Task { @MainActor [weak self] in
            do {
                let remote = try await service.fetchReconciliationRemoteCounts()
                try Task.checkCancellation()
                let local = try LocalDatabasePublicSummary.makeReconciliationAware(context: context)
                let report = SyncCountDriftReport.compare(local: local, remote: remote)
                self?.syncCountDriftReport = report
                self?.syncCountDriftCheckFailed = false
                self?.lastSyncCountDriftCheckedAt = Date()
                self?.refreshAccountSyncDecision()
            } catch is CancellationError {
                return
            } catch {
                self?.syncCountDriftReport = nil
                self?.syncCountDriftCheckFailed = true
                self?.lastSyncCountDriftCheckedAt = Date()
                self?.refreshAccountSyncDecision()
            }
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

    private func isRelevantToCurrentAccount(_ change: LocalPendingChange) -> Bool {
        guard !change.status.isTerminal else { return false }
        guard let owner = currentUserID?.uuidString.lowercased() else {
            return change.ownerUserID == nil
        }
        return change.ownerUserID == owner
    }
}
