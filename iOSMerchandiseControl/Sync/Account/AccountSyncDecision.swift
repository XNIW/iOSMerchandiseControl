import Foundation

nonisolated enum AccountSyncTrigger: Equatable, Sendable {
    case login(accountHash: String)
    case reconnect(accountHash: String)
    case switchAccount(from: String, to: String)
    case switchShop(from: String, to: String)
    case sessionRestored(accountHash: String)
    case remoteTombstone
    case productPriceConflict
    case historyDuplicateFingerprint
    case remoteDeletedWhileLocalEditedOffline
    case clockSkewDetected
    case multiDeviceEvent(accountHash: String)
    case logout
}

nonisolated enum LocalStoreAccountState: Equatable, Sendable {
    case empty
    case anonymous(hasData: Bool)
    case bound(accountHash: String, hasData: Bool)
}

nonisolated enum RemoteDatasetState: Equatable, Sendable {
    case empty
    case nonEmpty
    case unknown
}

nonisolated enum PendingOwnerState: Equatable, Sendable {
    case none
    case anonymous
    case sameAccount
    case differentAccount
}

nonisolated struct AccountSyncPolicyInput: Equatable, Sendable {
    var trigger: AccountSyncTrigger
    var localStore: LocalStoreAccountState
    var remoteDataset: RemoteDatasetState
    var pendingOwner: PendingOwnerState
    var hasNewerLocalPending: Bool

    init(
        trigger: AccountSyncTrigger,
        localStore: LocalStoreAccountState,
        remoteDataset: RemoteDatasetState,
        pendingOwner: PendingOwnerState = .none,
        hasNewerLocalPending: Bool = false
    ) {
        self.trigger = trigger
        self.localStore = localStore
        self.remoteDataset = remoteDataset
        self.pendingOwner = pendingOwner
        self.hasNewerLocalPending = hasNewerLocalPending
    }
}

nonisolated struct AccountSyncDecision: Equatable, Sendable {
    var action: AccountSyncDecisionAction
    var defaultSafeAction: AccountSyncSafeAction
    var remoteMutation: AccountRemoteMutationPolicy
    var pendingHandling: AccountPendingHandling
    var conflictPolicy: AccountConflictPolicy
    var rollback: AccountRollbackPolicy
    var testID: String

    var requiresUserDecision: Bool {
        switch action {
        case .promptBootstrapUpload,
             .promptMergeReplaceUploadExportCancel,
             .promptRemoteVerification,
             .promptSwitchStoreOrCreateStore,
             .promptOwnerStoreReview,
             .markConflictStale:
            return true
        case .noOp,
             .pushPendingDrainEventsLightReconcile,
             .applyRemoteTombstone,
             .dedupeHistoryFingerprint,
             .useRemoteOrdering,
             .drainEventsLightReconcile,
             .keepAnonymousOrPreviousOwnerBound:
            return false
        }
    }
}

nonisolated enum AccountSyncDecisionAction: Equatable, Sendable {
    case noOp
    case promptBootstrapUpload
    case promptMergeReplaceUploadExportCancel
    case promptRemoteVerification
    case pushPendingDrainEventsLightReconcile
    case promptSwitchStoreOrCreateStore
    case promptOwnerStoreReview(OwnerStoreBindingReviewReason)
    case markConflictStale
    case applyRemoteTombstone
    case dedupeHistoryFingerprint
    case useRemoteOrdering
    case drainEventsLightReconcile
    case keepAnonymousOrPreviousOwnerBound
}

nonisolated enum AccountSyncSafeAction: Equatable, Sendable {
    case proceed
    case cancel
}

nonisolated enum AccountRemoteMutationPolicy: Equatable, Sendable {
    case allowed
    case allowedAfterUserConfirmation
    case blockedUntilUserDecision
    case blocked
}

nonisolated enum AccountPendingHandling: Equatable, Sendable {
    case none
    case keepUnboundUntilDecision
    case pushOwnerBoundPending
    case keepPendingWithOriginalOwner
    case preserveAsConflict
    case keepLocalOnly
}

nonisolated enum AccountConflictPolicy: Equatable, Sendable {
    case none
    case noSilentMerge
    case noCrossAccountMerge
    case noSilentResurrect
    case sameEffectiveAtPriceConflict
    case hideTaskDebugHistoryEntries
    case preferRemoteTimestampsAndEventIDs
    case remoteSourceOfTruth
}

nonisolated enum AccountRollbackPolicy: Equatable, Sendable {
    case none
    case cancelLeavesLocalUnbound
    case cancelLeavesRemoteUntouched
    case switchBackToOriginalStore
    case preservePendingConflict
}
