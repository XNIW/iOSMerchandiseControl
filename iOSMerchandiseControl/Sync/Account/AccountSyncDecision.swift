import Foundation

enum AccountSyncTrigger: Equatable {
    case login(accountHash: String)
    case reconnect(accountHash: String)
    case switchAccount(from: String, to: String)
    case sessionRestored(accountHash: String)
    case remoteTombstone
    case productPriceConflict
    case historyDuplicateFingerprint
    case remoteDeletedWhileLocalEditedOffline
    case clockSkewDetected
    case multiDeviceEvent(accountHash: String)
    case logout
}

enum LocalStoreAccountState: Equatable {
    case empty
    case anonymous(hasData: Bool)
    case bound(accountHash: String, hasData: Bool)
}

enum RemoteDatasetState: Equatable {
    case empty
    case nonEmpty
    case unknown
}

enum PendingOwnerState: Equatable {
    case none
    case anonymous
    case sameAccount
    case differentAccount
}

struct AccountSyncPolicyInput: Equatable {
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

struct AccountSyncDecision: Equatable {
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

enum AccountSyncDecisionAction: Equatable {
    case noOp
    case promptBootstrapUpload
    case promptMergeReplaceUploadExportCancel
    case promptRemoteVerification
    case pushPendingDrainEventsLightReconcile
    case promptSwitchStoreOrCreateStore
    case markConflictStale
    case applyRemoteTombstone
    case dedupeHistoryFingerprint
    case useRemoteOrdering
    case drainEventsLightReconcile
    case keepAnonymousOrPreviousOwnerBound
}

enum AccountSyncSafeAction: Equatable {
    case proceed
    case cancel
}

enum AccountRemoteMutationPolicy: Equatable {
    case allowed
    case allowedAfterUserConfirmation
    case blockedUntilUserDecision
    case blocked
}

enum AccountPendingHandling: Equatable {
    case none
    case keepUnboundUntilDecision
    case pushOwnerBoundPending
    case keepPendingWithOriginalOwner
    case preserveAsConflict
    case keepLocalOnly
}

enum AccountConflictPolicy: Equatable {
    case none
    case noSilentMerge
    case noCrossAccountMerge
    case noSilentResurrect
    case sameEffectiveAtPriceConflict
    case hideTaskDebugHistoryEntries
    case preferRemoteTimestampsAndEventIDs
    case remoteSourceOfTruth
}

enum AccountRollbackPolicy: Equatable {
    case none
    case cancelLeavesLocalUnbound
    case cancelLeavesRemoteUntouched
    case switchBackToOriginalStore
    case preservePendingConflict
}
