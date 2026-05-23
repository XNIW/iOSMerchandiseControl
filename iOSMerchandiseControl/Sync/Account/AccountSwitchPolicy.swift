import Foundation

enum AccountSwitchPolicy {
    static func decide(_ input: AccountSyncPolicyInput) -> AccountSyncDecision {
        switch input.trigger {
        case .login:
            return decideLogin(input)
        case .reconnect:
            return sameAccountReconnect(testID: "AP-C-01")
        case .sessionRestored:
            return sameAccountReconnect(testID: "AP-E-01")
        case .switchAccount:
            return AccountSyncDecision(
                action: .promptSwitchStoreOrCreateStore,
                defaultSafeAction: .cancel,
                remoteMutation: .blockedUntilUserDecision,
                pendingHandling: .keepPendingWithOriginalOwner,
                conflictPolicy: .noCrossAccountMerge,
                rollback: .switchBackToOriginalStore,
                testID: "AP-D-01"
            )
        case .remoteTombstone:
            if input.hasNewerLocalPending {
                return conflict(
                    policy: .noSilentResurrect,
                    pending: .preserveAsConflict,
                    testID: "AP-I-02"
                )
            }
            return AccountSyncDecision(
                action: .applyRemoteTombstone,
                defaultSafeAction: .proceed,
                remoteMutation: .blocked,
                pendingHandling: .none,
                conflictPolicy: .none,
                rollback: .none,
                testID: "AP-I-01"
            )
        case .productPriceConflict:
            return conflict(
                policy: .sameEffectiveAtPriceConflict,
                pending: .preserveAsConflict,
                testID: "AP-F-01"
            )
        case .historyDuplicateFingerprint:
            return AccountSyncDecision(
                action: .dedupeHistoryFingerprint,
                defaultSafeAction: .proceed,
                remoteMutation: .allowed,
                pendingHandling: .none,
                conflictPolicy: .hideTaskDebugHistoryEntries,
                rollback: .none,
                testID: "AP-G-01"
            )
        case .remoteDeletedWhileLocalEditedOffline:
            return conflict(
                policy: .noSilentResurrect,
                pending: .preserveAsConflict,
                testID: "AP-H-01"
            )
        case .clockSkewDetected:
            return AccountSyncDecision(
                action: .useRemoteOrdering,
                defaultSafeAction: .proceed,
                remoteMutation: .blocked,
                pendingHandling: .none,
                conflictPolicy: .preferRemoteTimestampsAndEventIDs,
                rollback: .none,
                testID: "AP-J-01"
            )
        case .multiDeviceEvent:
            return AccountSyncDecision(
                action: .drainEventsLightReconcile,
                defaultSafeAction: .proceed,
                remoteMutation: .allowed,
                pendingHandling: .pushOwnerBoundPending,
                conflictPolicy: .remoteSourceOfTruth,
                rollback: .none,
                testID: "AP-K-01"
            )
        case .logout:
            return AccountSyncDecision(
                action: .keepAnonymousOrPreviousOwnerBound,
                defaultSafeAction: .proceed,
                remoteMutation: .blocked,
                pendingHandling: .keepLocalOnly,
                conflictPolicy: .none,
                rollback: .none,
                testID: "AP-L-01"
            )
        }
    }

    private static func decideLogin(_ input: AccountSyncPolicyInput) -> AccountSyncDecision {
        switch (input.localStore, input.remoteDataset) {
        case (.anonymous(let hasData), .empty) where hasData:
            return AccountSyncDecision(
                action: .promptBootstrapUpload,
                defaultSafeAction: .cancel,
                remoteMutation: .allowedAfterUserConfirmation,
                pendingHandling: .keepUnboundUntilDecision,
                conflictPolicy: .none,
                rollback: .cancelLeavesLocalUnbound,
                testID: "AP-A-01"
            )
        case (.anonymous(let hasData), .nonEmpty) where hasData:
            return AccountSyncDecision(
                action: .promptMergeReplaceUploadExportCancel,
                defaultSafeAction: .cancel,
                remoteMutation: .blockedUntilUserDecision,
                pendingHandling: .keepUnboundUntilDecision,
                conflictPolicy: .noSilentMerge,
                rollback: .cancelLeavesRemoteUntouched,
                testID: "AP-B-01"
            )
        case (.anonymous(let hasData), .unknown) where hasData:
            return AccountSyncDecision(
                action: .promptRemoteVerification,
                defaultSafeAction: .cancel,
                remoteMutation: .blockedUntilUserDecision,
                pendingHandling: .keepUnboundUntilDecision,
                conflictPolicy: .noSilentMerge,
                rollback: .cancelLeavesRemoteUntouched,
                testID: "AP-B-00"
            )
        default:
            return AccountSyncDecision(
                action: .noOp,
                defaultSafeAction: .proceed,
                remoteMutation: .blocked,
                pendingHandling: .none,
                conflictPolicy: .none,
                rollback: .none,
                testID: "AP-DEFAULT"
            )
        }
    }

    private static func sameAccountReconnect(testID: String) -> AccountSyncDecision {
        AccountSyncDecision(
            action: .pushPendingDrainEventsLightReconcile,
            defaultSafeAction: .proceed,
            remoteMutation: .allowed,
            pendingHandling: .pushOwnerBoundPending,
            conflictPolicy: .none,
            rollback: .none,
            testID: testID
        )
    }

    private static func conflict(
        policy: AccountConflictPolicy,
        pending: AccountPendingHandling,
        testID: String
    ) -> AccountSyncDecision {
        AccountSyncDecision(
            action: .markConflictStale,
            defaultSafeAction: .cancel,
            remoteMutation: .blocked,
            pendingHandling: pending,
            conflictPolicy: policy,
            rollback: .preservePendingConflict,
            testID: testID
        )
    }
}
