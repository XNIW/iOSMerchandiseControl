import Foundation
import SwiftData

nonisolated struct SyncDecisionInputSnapshot: Equatable, Sendable {
    var triggerSource: SyncAutomaticTriggerSource
    var isAuthenticated: Bool
    var ownerUserID: UUID?
    var ownerStoreBindingResolution: OwnerStoreBindingResolution
    var accountBindingMatches: Bool
    var networkStatus: AutomaticSyncNetworkStatus
    var pendingLocalChanges: LocalPendingChangeSnapshot
    var pendingOutboxCount: Int
    var requiresBootstrap: Bool
    var requiresFullRecovery: Bool
    var preservesPendingBeforeRecovery: Bool = false
    var hasRecoveryDrift: Bool
    var hasRealtimeEvent: Bool
    var isSyncBusy: Bool
    var hasStateReadFailure: Bool
    var requestsLightReconcile: Bool

    var isNetworkAvailable: Bool {
        networkStatus == .satisfied
    }

    var hasPendingLocalChanges: Bool {
        pendingLocalChanges.pendingCatalogChangeCount > 0
            || pendingLocalChanges.pendingProductPriceChangeCount > 0
            || pendingLocalChanges.pendingHistorySessionChangeCount > 0
            || pendingOutboxCount > 0
    }

    var input: SyncDecisionInput {
        SyncDecisionInput(
            trigger: triggerSource.syncTrigger,
            isAuthenticated: isAuthenticated,
            isNetworkAvailable: isNetworkAvailable,
            requiresAccountDecision: !accountBindingMatches,
            hasPendingLocalChanges: hasPendingLocalChanges,
            hasRemoteSyncEvent: hasRealtimeEvent,
            hasRemoteVerificationDrift: hasRecoveryDrift,
            requestsLightReconcile: requestsLightReconcile,
            requiresBootstrap: requiresBootstrap,
            requiresFullRecovery: requiresFullRecovery,
            preservesPendingBeforeRecovery: preservesPendingBeforeRecovery,
            fullRecoveryContext: .normalForeground,
            isSyncBusy: isSyncBusy,
            hasStateReadFailure: hasStateReadFailure
        )
    }
}

protocol SyncDecisionInputProviding: AnyObject {
    func updateNetworkStatus(_ status: AutomaticSyncNetworkStatus) async
    func recordRealtimeEvent() async
    func makeSnapshot(
        triggerSource: SyncAutomaticTriggerSource,
        isAuthenticated: Bool,
        ownerUserID: UUID?,
        isSyncBusy: Bool
    ) async -> SyncDecisionInputSnapshot
}

actor SyncDecisionInputProvider: SyncDecisionInputProviding {
    private let modelContainer: ModelContainer
    private let bindingStore: AccountBindingStore
    private let selectedShopStore: SelectedShopStore
    private var networkStatus: AutomaticSyncNetworkStatus
    private var pendingRealtimeEvent = false

    init(
        modelContainer: ModelContainer,
        initialNetworkStatus: AutomaticSyncNetworkStatus = .unknown,
        bindingStore: AccountBindingStore = AccountBindingStore(),
        selectedShopStore: SelectedShopStore = SelectedShopStore()
    ) {
        self.modelContainer = modelContainer
        self.bindingStore = bindingStore
        self.selectedShopStore = selectedShopStore
        self.networkStatus = initialNetworkStatus
    }

    func updateNetworkStatus(_ status: AutomaticSyncNetworkStatus) async {
        networkStatus = status
    }

    func recordRealtimeEvent() async {
        pendingRealtimeEvent = true
    }

    func makeSnapshot(
        triggerSource: SyncAutomaticTriggerSource,
        isAuthenticated: Bool,
        ownerUserID: UUID?,
        isSyncBusy: Bool
    ) async -> SyncDecisionInputSnapshot {
        guard isAuthenticated, let ownerUserID else {
            return SyncDecisionInputSnapshot(
                triggerSource: triggerSource,
                isAuthenticated: false,
                ownerUserID: nil,
                ownerStoreBindingResolution: .reviewRequired(.accountMismatch),
                accountBindingMatches: false,
                networkStatus: networkStatus,
                pendingLocalChanges: .empty,
                pendingOutboxCount: 0,
                requiresBootstrap: false,
                requiresFullRecovery: false,
                hasRecoveryDrift: false,
                hasRealtimeEvent: false,
                isSyncBusy: isSyncBusy,
                hasStateReadFailure: false,
                requestsLightReconcile: triggerSource.requestsLightReconcile
            )
        }
        let context = ModelContext(modelContainer)
        let pendingChanges = loadPendingChanges(context: context, ownerUserID: ownerUserID)
        let outboxCount = loadPendingOutboxCount(context: context, ownerUserID: ownerUserID)
        let baselineSummary = loadBaselineSummary(context: context, ownerUserID: ownerUserID)
        let localStoreIsCompletelyEmpty = loadLocalStoreIsCompletelyEmpty(context: context)
        let stateReadFailed = pendingChanges.failed
            || outboxCount.failed
            || baselineSummary.failed
            || localStoreIsCompletelyEmpty.failed
        var bindingResolution = ownerStoreBindingResolution(
            ownerUserID: ownerUserID,
            localStoreIsCompletelyEmpty: localStoreIsCompletelyEmpty.value,
            stateReadFailed: stateReadFailed
        )
        if baselineSummary.value.status == .accountMismatch,
           !bindingStore.hasPendingReplacementJournal {
            bindingResolution = .reviewRequired(.accountMismatch)
        }
        let pendingRecoveryMode = exactPendingRecoveryMode(
            ownerUserID: ownerUserID,
            bindingResolution: bindingResolution
        )
        let requiresReplacementRecovery = pendingRecoveryMode != nil
        let realtimeEvent = pendingRealtimeEvent || triggerSource == .remoteSyncEvent
        if realtimeEvent {
            pendingRealtimeEvent = false
        }

        return SyncDecisionInputSnapshot(
            triggerSource: triggerSource,
            isAuthenticated: isAuthenticated,
            ownerUserID: ownerUserID,
            ownerStoreBindingResolution: bindingResolution,
            accountBindingMatches: bindingResolution.allowsAutomaticSync,
            networkStatus: networkStatus,
            pendingLocalChanges: pendingChanges.value,
            pendingOutboxCount: outboxCount.value,
            requiresBootstrap: requiresReplacementRecovery || requiresBootstrap(
                baselineSummary: baselineSummary.value,
                isAuthenticated: isAuthenticated,
                localStoreIsCompletelyEmpty: localStoreIsCompletelyEmpty.value,
                bindingResolution: bindingResolution
            ),
            requiresFullRecovery: !requiresReplacementRecovery
                && bindingResolution.allowsAutomaticSync
                && requiresFullRecovery(baselineSummary: baselineSummary.value),
            preservesPendingBeforeRecovery: pendingRecoveryMode == .sameScopeRecovery,
            hasRecoveryDrift: !requiresReplacementRecovery
                && bindingResolution.allowsAutomaticSync
                && hasRecoveryDrift(baselineSummary: baselineSummary.value),
            hasRealtimeEvent: realtimeEvent,
            isSyncBusy: isSyncBusy,
            hasStateReadFailure: stateReadFailed,
            requestsLightReconcile: triggerSource.requestsLightReconcile
        )
    }

    private nonisolated static func hasPendingLocalChanges(
        pendingChanges: LocalPendingChangeSnapshot,
        pendingOutboxCount: Int
    ) -> Bool {
        pendingChanges.pendingCatalogChangeCount > 0
            || pendingChanges.pendingProductPriceChangeCount > 0
            || pendingChanges.pendingHistorySessionChangeCount > 0
            || pendingOutboxCount > 0
    }

    private struct ReadResult<Value> {
        var value: Value
        var failed: Bool

        static func success(_ value: Value) -> ReadResult<Value> {
            ReadResult(value: value, failed: false)
        }

        static func failure(_ fallback: Value) -> ReadResult<Value> {
            ReadResult(value: fallback, failed: true)
        }
    }

    private func loadPendingChanges(
        context: ModelContext,
        ownerUserID: UUID?
    ) -> ReadResult<LocalPendingChangeSnapshot> {
        do {
            let storeIdentity = ownerUserID.flatMap { owner in
                let accountHash = AccountBindingStore.accountHash(for: owner)
                return selectedShopStore.selectedShop(accountHash: accountHash)?.localStoreIdentity
            }
            return .success(try LocalPendingChangeSnapshotProvider(context: context)
                .loadSnapshot(ownerUserID: ownerUserID, storeIdentity: storeIdentity)
            )
        } catch {
            return .failure(.empty)
        }
    }

    private func loadPendingOutboxCount(
        context: ModelContext,
        ownerUserID: UUID?
    ) -> ReadResult<Int> {
        guard let ownerUserID else { return .success(0) }
        do {
            let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
            let storeId = selectedShopStore.selectedShop(accountHash: accountHash)?.localStoreIdentity.storeId
            let counts = try SyncEventOutboxLocalStore(context: context).fetchCounts(
                ownerUserID: ownerUserID.uuidString.lowercased(),
                storeId: storeId,
                now: Date()
            )
            // `retryable` is a time/ownership subset of pending + failedRetryable,
            // not an additional queue. Counting it again would duplicate work.
            return .success(counts.pending + counts.failedRetryable)
        } catch {
            return .failure(0)
        }
    }

    private func loadBaselineSummary(
        context: ModelContext,
        ownerUserID: UUID?
    ) -> ReadResult<SupabaseCatalogBaselineDebugSummary> {
        do {
            return .success(try SupabaseCatalogBaselineReader().debugSummary(
                context: context,
                currentUserUUID: ownerUserID
            ))
        } catch {
            return .failure(.absent)
        }
    }

    private func loadLocalStoreIsCompletelyEmpty(context: ModelContext) -> ReadResult<Bool> {
        do {
            let productCount = try context.fetchCount(FetchDescriptor<Product>())
            let supplierCount = try context.fetchCount(FetchDescriptor<Supplier>())
            let categoryCount = try context.fetchCount(FetchDescriptor<ProductCategory>())
            let productPriceCount = try context.fetchCount(FetchDescriptor<ProductPrice>())
            let historyCount = try context.fetchCount(FetchDescriptor<HistoryEntry>())
            let pendingChangeCount = try context.fetchCount(FetchDescriptor<LocalPendingChange>())
            let outboxCount = try context.fetchCount(FetchDescriptor<SyncEventOutboxEntry>())
            let baselineRunCount = try context.fetchCount(FetchDescriptor<SupabaseCatalogBaselineRun>())
            let baselineRecordCount = try context.fetchCount(FetchDescriptor<SupabaseCatalogBaselineRecord>())
            return .success(
                productCount == 0
                    && supplierCount == 0
                    && categoryCount == 0
                    && productPriceCount == 0
                    && historyCount == 0
                    && pendingChangeCount == 0
                    && outboxCount == 0
                    && baselineRunCount == 0
                    && baselineRecordCount == 0
            )
        } catch {
            return .failure(false)
        }
    }

    private func ownerStoreBindingResolution(
        ownerUserID: UUID,
        localStoreIsCompletelyEmpty: Bool,
        stateReadFailed: Bool
    ) -> OwnerStoreBindingResolution {
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        if !bindingStore.hasPendingReplacementJournal,
           let binding = bindingStore.currentBinding,
           binding.accountHash != accountHash {
            return .reviewRequired(.accountMismatch)
        }
        guard selectedShopStore.isResolutionReady(accountHash: accountHash) else {
            return .reviewRequired(.shopContextUnavailable)
        }
        guard let activeStoreIdentity = selectedShopStore
            .selectedShop(accountHash: accountHash)?.localStoreIdentity else {
            return .reviewRequired(.shopContextUnavailable)
        }
        return bindingStore.resolveOwnerStoreBinding(
            userID: ownerUserID,
            activeStoreIdentity: activeStoreIdentity,
            isLocalStoreCompletelyEmpty: localStoreIsCompletelyEmpty,
            stateReadFailed: stateReadFailed
        )
    }

    private func requiresBootstrap(
        baselineSummary: SupabaseCatalogBaselineDebugSummary,
        isAuthenticated: Bool,
        localStoreIsCompletelyEmpty: Bool,
        bindingResolution: OwnerStoreBindingResolution
    ) -> Bool {
        isAuthenticated
            && baselineSummary.status == .absent
            && localStoreIsCompletelyEmpty
            && bindingResolution.allowsAutomaticSync
    }

    private func exactPendingRecoveryMode(
        ownerUserID: UUID,
        bindingResolution: OwnerStoreBindingResolution
    ) -> AccountRecoveryJournalMode? {
        guard bindingResolution.allowsAutomaticSync else { return nil }
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        guard let pending = bindingStore.pendingReplacement,
              pending.accountHash == accountHash,
              let recovery = bindingStore.pendingRecoveryJournal,
              recovery.replacement == pending,
              selectedShopStore.isResolutionReady(accountHash: accountHash),
              let selectedIdentity = selectedShopStore
                .selectedShop(accountHash: accountHash)?.localStoreIdentity else {
            return nil
        }
        guard selectedIdentity == pending.storeIdentity else { return nil }
        if recovery.mode == .sameScopeRecovery {
            guard bindingStore.currentBinding?.accountHash == accountHash,
                  bindingStore.currentBinding?.storeIdentity == pending.storeIdentity else {
                return nil
            }
        }
        return recovery.mode
    }

    private func requiresFullRecovery(
        baselineSummary: SupabaseCatalogBaselineDebugSummary
    ) -> Bool {
        switch baselineSummary.status {
        case .stale, .incomplete, .accountMismatch:
            return true
        case .absent, .valid:
            return false
        }
    }

    private func hasRecoveryDrift(
        baselineSummary: SupabaseCatalogBaselineDebugSummary
    ) -> Bool {
        switch baselineSummary.status {
        case .stale, .incomplete, .accountMismatch:
            return true
        case .absent, .valid:
            return false
        }
    }
}

extension SyncAutomaticTriggerSource {
    nonisolated var syncTrigger: SyncTrigger {
        switch self {
        case .releaseCard:
            return .manualRefresh
        case .rootForeground:
            return .appForeground
        case .foregroundPoll:
            return .appForeground
        case .networkReconnect:
            return .networkAvailable
        case .localMutation:
            return .localMutation
        case .remoteSyncEvent:
            return .remoteSyncEvent
        case .backgroundRefresh:
            return .networkAvailable
        }
    }

    nonisolated var requestsLightReconcile: Bool {
        switch self {
        case .releaseCard, .rootForeground, .networkReconnect:
            return true
        case .foregroundPoll, .localMutation, .remoteSyncEvent, .backgroundRefresh:
            return false
        }
    }
}
