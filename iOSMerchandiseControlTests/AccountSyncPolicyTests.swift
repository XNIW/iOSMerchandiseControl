import XCTest
@testable import iOSMerchandiseControl

final class AccountSyncPolicyTests: XCTestCase {
    private static var retainedBindingStores: [AccountBindingStore] = []

    func testAnonymousLocalDataRemoteEmptyRequiresConfirmedBootstrap() {
        let decision = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: .login(accountHash: "account-a"),
                localStore: .anonymous(hasData: true),
                remoteDataset: .empty
            )
        )

        XCTAssertEqual(decision.action, .promptBootstrapUpload)
        XCTAssertEqual(decision.defaultSafeAction, .cancel)
        XCTAssertEqual(decision.remoteMutation, .allowedAfterUserConfirmation)
        XCTAssertEqual(decision.pendingHandling, .keepUnboundUntilDecision)
        XCTAssertEqual(decision.testID, "AP-A-01")
    }

    func testAnonymousLocalDataRemoteNonEmptyBlocksSilentMerge() {
        let decision = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: .login(accountHash: "account-a"),
                localStore: .anonymous(hasData: true),
                remoteDataset: .nonEmpty
            )
        )

        XCTAssertEqual(decision.action, .promptMergeReplaceUploadExportCancel)
        XCTAssertEqual(decision.defaultSafeAction, .cancel)
        XCTAssertEqual(decision.remoteMutation, .blockedUntilUserDecision)
        XCTAssertEqual(decision.conflictPolicy, .noSilentMerge)
        XCTAssertEqual(decision.testID, "AP-B-01")
    }

    func testAnonymousLocalDataUnknownRemoteRequiresVerificationBeforeMutation() {
        let decision = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: .login(accountHash: "account-a"),
                localStore: .anonymous(hasData: true),
                remoteDataset: .unknown
            )
        )

        XCTAssertEqual(decision.action, .promptRemoteVerification)
        XCTAssertEqual(decision.defaultSafeAction, .cancel)
        XCTAssertEqual(decision.remoteMutation, .blockedUntilUserDecision)
        XCTAssertEqual(decision.testID, "AP-B-00")
    }

    func testSameAccountReconnectPushesPendingDrainsAndLightReconciles() {
        let decision = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: .reconnect(accountHash: "account-a"),
                localStore: .bound(accountHash: "account-a", hasData: true),
                remoteDataset: .nonEmpty,
                pendingOwner: .sameAccount
            )
        )

        XCTAssertEqual(decision.action, .pushPendingDrainEventsLightReconcile)
        XCTAssertEqual(decision.remoteMutation, .allowed)
        XCTAssertEqual(decision.pendingHandling, .pushOwnerBoundPending)
        XCTAssertEqual(decision.testID, "AP-C-01")
        XCTAssertFalse(decision.requiresUserDecision)
    }

    func testSessionRestoreForSameAccountKeepsOwnerBoundPending() {
        let decision = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: .sessionRestored(accountHash: "account-a"),
                localStore: .bound(accountHash: "account-a", hasData: true),
                remoteDataset: .nonEmpty,
                pendingOwner: .sameAccount
            )
        )

        XCTAssertEqual(decision.action, .pushPendingDrainEventsLightReconcile)
        XCTAssertEqual(decision.pendingHandling, .pushOwnerBoundPending)
        XCTAssertEqual(decision.testID, "AP-E-01")
    }

    func testSwitchAccountKeepsPendingWithOriginalOwner() {
        let decision = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: .switchAccount(from: "account-a", to: "account-b"),
                localStore: .bound(accountHash: "account-a", hasData: true),
                remoteDataset: .nonEmpty,
                pendingOwner: .differentAccount
            )
        )

        XCTAssertEqual(decision.action, .promptSwitchStoreOrCreateStore)
        XCTAssertEqual(decision.defaultSafeAction, .cancel)
        XCTAssertEqual(decision.pendingHandling, .keepPendingWithOriginalOwner)
        XCTAssertEqual(decision.conflictPolicy, .noCrossAccountMerge)
        XCTAssertEqual(decision.testID, "AP-D-01")
    }

    func testRemoteTombstoneWithNewerLocalPendingBecomesConflict() {
        let decision = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: .remoteTombstone,
                localStore: .bound(accountHash: "account-a", hasData: true),
                remoteDataset: .nonEmpty,
                pendingOwner: .sameAccount,
                hasNewerLocalPending: true
            )
        )

        XCTAssertEqual(decision.action, .markConflictStale)
        XCTAssertEqual(decision.pendingHandling, .preserveAsConflict)
        XCTAssertEqual(decision.conflictPolicy, .noSilentResurrect)
        XCTAssertEqual(decision.testID, "AP-I-02")
    }

    func testSameBarcodeSameEffectiveAtDifferentPriceIsConflict() {
        let decision = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: .productPriceConflict,
                localStore: .bound(accountHash: "account-a", hasData: true),
                remoteDataset: .nonEmpty,
                pendingOwner: .sameAccount
            )
        )

        XCTAssertEqual(decision.action, .markConflictStale)
        XCTAssertEqual(decision.conflictPolicy, .sameEffectiveAtPriceConflict)
        XCTAssertEqual(decision.testID, "AP-F-01")
    }

    func testHistoryDuplicateFingerprintDedupesWithoutUserVisibleDebugEntries() {
        let decision = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: .historyDuplicateFingerprint,
                localStore: .bound(accountHash: "account-a", hasData: true),
                remoteDataset: .nonEmpty,
                pendingOwner: .sameAccount
            )
        )

        XCTAssertEqual(decision.action, .dedupeHistoryFingerprint)
        XCTAssertEqual(decision.conflictPolicy, .hideTaskDebugHistoryEntries)
        XCTAssertEqual(decision.testID, "AP-G-01")
    }

    func testRemoteDeletedWhileLocalEditedOfflineDoesNotResurrectSilently() {
        let decision = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: .remoteDeletedWhileLocalEditedOffline,
                localStore: .bound(accountHash: "account-a", hasData: true),
                remoteDataset: .nonEmpty,
                pendingOwner: .sameAccount,
                hasNewerLocalPending: true
            )
        )

        XCTAssertEqual(decision.action, .markConflictStale)
        XCTAssertEqual(decision.conflictPolicy, .noSilentResurrect)
        XCTAssertEqual(decision.testID, "AP-H-01")
    }

    func testClockSkewUsesRemoteOrdering() {
        let decision = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: .clockSkewDetected,
                localStore: .bound(accountHash: "account-a", hasData: true),
                remoteDataset: .nonEmpty,
                pendingOwner: .sameAccount
            )
        )

        XCTAssertEqual(decision.action, .useRemoteOrdering)
        XCTAssertEqual(decision.conflictPolicy, .preferRemoteTimestampsAndEventIDs)
        XCTAssertEqual(decision.testID, "AP-J-01")
    }

    func testMultiDeviceSameAccountUsesRemoteAsSourceOfTruth() {
        let decision = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: .multiDeviceEvent(accountHash: "account-a"),
                localStore: .bound(accountHash: "account-a", hasData: true),
                remoteDataset: .nonEmpty,
                pendingOwner: .sameAccount
            )
        )

        XCTAssertEqual(decision.action, .drainEventsLightReconcile)
        XCTAssertEqual(decision.conflictPolicy, .remoteSourceOfTruth)
        XCTAssertEqual(decision.testID, "AP-K-01")
    }

    func testAnonymousStoreAfterLogoutNeverUploadsToNewAccountAutomatically() {
        let decision = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: .logout,
                localStore: .anonymous(hasData: true),
                remoteDataset: .unknown,
                pendingOwner: .anonymous
            )
        )

        XCTAssertEqual(decision.action, .keepAnonymousOrPreviousOwnerBound)
        XCTAssertEqual(decision.remoteMutation, .blocked)
        XCTAssertEqual(decision.pendingHandling, .keepLocalOnly)
        XCTAssertEqual(decision.testID, "AP-L-01")
    }

    func testBindingStorePersistsAccountHashAndStoreIdentity() {
        let key = "AccountSyncPolicyTests.\(UUID().uuidString).binding"
        let store = AccountBindingStore(defaults: .standard, key: key)
        let identity = LocalStoreIdentity(rawValue: "store-physical-a")

        store.saveBinding(accountHash: "account-a", storeIdentity: identity)
        Self.retainedBindingStores.append(store)

        XCTAssertEqual(store.currentBinding?.accountHash, "account-a")
        XCTAssertEqual(store.currentBinding?.storeIdentity, identity)
    }

    func testConfirmedAccountDecisionChoiceBindsLocalStoreToSignedInAccount() {
        let key = "AccountSyncPolicyTests.\(UUID().uuidString).confirmed-choice"
        let store = AccountBindingStore(defaults: .standard, key: key)
        let userID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let applier = AccountSyncChoiceBindingApplier(bindingStore: store)

        applier.applyConfirmedRelationship(choice: .merge, userID: userID)
        Self.retainedBindingStores.append(store)

        XCTAssertEqual(store.currentBinding?.accountHash, AccountBindingStore.accountHash(for: userID))
        XCTAssertEqual(store.currentBinding?.storeIdentity, .anonymous)
    }

    func testCancelledAccountDecisionChoiceLeavesBindingUnchanged() {
        let key = "AccountSyncPolicyTests.\(UUID().uuidString).cancelled-choice"
        let store = AccountBindingStore(defaults: .standard, key: key)
        let userID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let applier = AccountSyncChoiceBindingApplier(bindingStore: store)

        applier.applyConfirmedRelationship(choice: .cancel, userID: userID)
        Self.retainedBindingStores.append(store)

        XCTAssertNil(store.currentBinding)
    }

    func testAccountHashRedactsRawUserID() {
        let userID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let hash = AccountBindingStore.accountHash(for: userID)

        XCTAssertNotEqual(hash, userID.uuidString.lowercased())
        XCTAssertEqual(hash.count, 64)
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit })
    }

    func testOnlyBlockingAccountActionsRequireUserDecision() {
        let bootstrap = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: .login(accountHash: "account-a"),
                localStore: .anonymous(hasData: true),
                remoteDataset: .empty
            )
        )
        let reconnect = AccountSwitchPolicy.decide(
            AccountSyncPolicyInput(
                trigger: .reconnect(accountHash: "account-a"),
                localStore: .bound(accountHash: "account-a", hasData: true),
                remoteDataset: .nonEmpty,
                pendingOwner: .sameAccount
            )
        )

        XCTAssertTrue(bootstrap.requiresUserDecision)
        XCTAssertFalse(reconnect.requiresUserDecision)
    }
}
