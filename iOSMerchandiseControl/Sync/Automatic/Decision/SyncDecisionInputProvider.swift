import Foundation
import SwiftData

nonisolated struct SyncDecisionInputSnapshot: Equatable, Sendable {
    var triggerSource: SyncAutomaticTriggerSource
    var isAuthenticated: Bool
    var ownerUserID: UUID?
    var accountBindingMatches: Bool
    var networkStatus: AutomaticSyncNetworkStatus
    var pendingLocalChanges: LocalPendingChangeSnapshot
    var pendingOutboxCount: Int
    var requiresBootstrap: Bool
    var requiresFullRecovery: Bool
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
    private var networkStatus: AutomaticSyncNetworkStatus
    private var pendingRealtimeEvent = false

    init(
        modelContainer: ModelContainer,
        initialNetworkStatus: AutomaticSyncNetworkStatus = .unknown
    ) {
        self.modelContainer = modelContainer
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
        let context = ModelContext(modelContainer)
        let pendingChanges = loadPendingChanges(context: context, ownerUserID: ownerUserID)
        let outboxCount = loadPendingOutboxCount(context: context, ownerUserID: ownerUserID)
        let baselineSummary = loadBaselineSummary(context: context, ownerUserID: ownerUserID)
        let localCatalogIsEmpty = loadLocalCatalogIsEmpty(context: context)
        let stateReadFailed = pendingChanges.failed
            || outboxCount.failed
            || baselineSummary.failed
            || localCatalogIsEmpty.failed
        let bindingState = accountBindingState(ownerUserID: ownerUserID)
        let realtimeEvent = pendingRealtimeEvent || triggerSource == .remoteSyncEvent
        if realtimeEvent {
            pendingRealtimeEvent = false
        }

        return SyncDecisionInputSnapshot(
            triggerSource: triggerSource,
            isAuthenticated: isAuthenticated,
            ownerUserID: ownerUserID,
            accountBindingMatches: bindingState.matches,
            networkStatus: networkStatus,
            pendingLocalChanges: pendingChanges.value,
            pendingOutboxCount: outboxCount.value,
            requiresBootstrap: requiresBootstrap(
                baselineSummary: baselineSummary.value,
                isAuthenticated: isAuthenticated
            ),
            requiresFullRecovery: requiresFullRecovery(baselineSummary: baselineSummary.value),
            hasRecoveryDrift: hasRecoveryDrift(baselineSummary: baselineSummary.value),
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
            return .success(try LocalPendingChangeSnapshotProvider(context: context)
                .loadSnapshot(ownerUserID: ownerUserID)
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
            let counts = try SyncEventOutboxLocalStore(context: context).fetchCounts(
                ownerUserID: ownerUserID.uuidString.lowercased(),
                now: Date()
            )
            return .success(counts.pending + counts.failedRetryable + counts.retryable)
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

    private func loadLocalCatalogIsEmpty(context: ModelContext) -> ReadResult<Bool> {
        do {
            let productCount = try context.fetchCount(FetchDescriptor<Product>())
            let supplierCount = try context.fetchCount(FetchDescriptor<Supplier>())
            let categoryCount = try context.fetchCount(FetchDescriptor<ProductCategory>())
            return .success(productCount == 0 && supplierCount == 0 && categoryCount == 0)
        } catch {
            return .failure(false)
        }
    }

    private struct AccountBindingState {
        var matches: Bool
    }

    private func accountBindingState(ownerUserID: UUID?) -> AccountBindingState {
        guard let ownerUserID,
              let binding = AccountBindingStore().currentBinding else {
            return AccountBindingState(
                matches: true
            )
        }
        let matchesCurrentAccount = binding.accountHash == AccountBindingStore.accountHash(for: ownerUserID)
        return AccountBindingState(
            matches: matchesCurrentAccount
        )
    }

    private func requiresBootstrap(
        baselineSummary: SupabaseCatalogBaselineDebugSummary,
        isAuthenticated: Bool
    ) -> Bool {
        isAuthenticated
            && baselineSummary.status == .absent
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
        case .localMutation, .remoteSyncEvent, .backgroundRefresh:
            return false
        }
    }
}
