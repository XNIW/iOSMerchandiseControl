/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControl/Sync/Account/AccountBindingStore.swift:67:34: warning: main actor-isolated property 'confirmsAccountRelationship' can not be referenced from a nonisolated context
        guard let userID, choice.confirmsAccountRelationship else {
                                 ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControl/Sync/Account/AccountBindingStore.swift:79:9: note: property declared here
    var confirmsAccountRelationship: Bool {
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/Task103CrossPlatformAcceptanceTests.swift:2650:13: warning: call to main actor-isolated initializer 'init(remote:)' in a synchronous nonisolated context
            RecoveryRemoteSupabaseAdapter(remote: inventory)
            ^
iOSMerchandiseControl.RecoveryRemoteSupabaseAdapter.init:2:21: note: calls to initializer 'init(remote:)' from outside of its actor context are implicitly asynchronous
@MainActor internal init(remote: iOSMerchandiseControl.SupabaseTransportClient)}
                    ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/SyncRecoveryPolicyTests.swift:14:9: warning: main actor-isolated conformance of 'SyncRecoveryPolicy.Decision' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision, .requestLightReconcile)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/SyncRecoveryPolicyTests.swift:26:9: warning: main actor-isolated conformance of 'SyncRecoveryPolicy.Decision' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision, .runFullRecovery)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/SyncRecoveryPolicyTests.swift:42:9: warning: main actor-isolated conformance of 'SyncRecoveryPolicy.Decision' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision, .blockedBackoff)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/SyncRecoveryPolicyTests.swift:54:9: warning: main actor-isolated conformance of 'SyncRecoveryPolicy.Decision' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision, .runBootstrapPull)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/Task097RuntimeSmokeTests.swift:16:29: warning: main actor-isolated initializer 'init(config:redirectURL:)' cannot be called from outside of the actor; this is an error in the Swift 6 language mode
            clientProvider: SupabaseClientProvider(config: config)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~^~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:16:9: warning: main actor-isolated conformance of 'AccountSyncDecisionAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.action, .promptBootstrapUpload)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:17:9: warning: main actor-isolated conformance of 'AccountSyncSafeAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.defaultSafeAction, .cancel)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:18:9: warning: main actor-isolated conformance of 'AccountRemoteMutationPolicy' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.remoteMutation, .allowedAfterUserConfirmation)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:19:9: warning: main actor-isolated conformance of 'AccountPendingHandling' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.pendingHandling, .keepUnboundUntilDecision)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:32:9: warning: main actor-isolated conformance of 'AccountSyncDecisionAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.action, .promptMergeReplaceUploadExportCancel)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:33:9: warning: main actor-isolated conformance of 'AccountSyncSafeAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.defaultSafeAction, .cancel)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:34:9: warning: main actor-isolated conformance of 'AccountRemoteMutationPolicy' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.remoteMutation, .blockedUntilUserDecision)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:35:9: warning: main actor-isolated conformance of 'AccountConflictPolicy' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.conflictPolicy, .noSilentMerge)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:48:9: warning: main actor-isolated conformance of 'AccountSyncDecisionAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.action, .promptRemoteVerification)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:49:9: warning: main actor-isolated conformance of 'AccountSyncSafeAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.defaultSafeAction, .cancel)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:50:9: warning: main actor-isolated conformance of 'AccountRemoteMutationPolicy' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.remoteMutation, .blockedUntilUserDecision)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:64:9: warning: main actor-isolated conformance of 'AccountSyncDecisionAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.action, .pushPendingDrainEventsLightReconcile)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:65:9: warning: main actor-isolated conformance of 'AccountRemoteMutationPolicy' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.remoteMutation, .allowed)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:66:9: warning: main actor-isolated conformance of 'AccountPendingHandling' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.pendingHandling, .pushOwnerBoundPending)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:81:9: warning: main actor-isolated conformance of 'AccountSyncDecisionAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.action, .pushPendingDrainEventsLightReconcile)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:82:9: warning: main actor-isolated conformance of 'AccountPendingHandling' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.pendingHandling, .pushOwnerBoundPending)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:96:9: warning: main actor-isolated conformance of 'AccountSyncDecisionAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.action, .promptSwitchStoreOrCreateStore)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:97:9: warning: main actor-isolated conformance of 'AccountSyncSafeAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.defaultSafeAction, .cancel)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:98:9: warning: main actor-isolated conformance of 'AccountPendingHandling' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.pendingHandling, .keepPendingWithOriginalOwner)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:99:9: warning: main actor-isolated conformance of 'AccountConflictPolicy' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.conflictPolicy, .noCrossAccountMerge)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:114:9: warning: main actor-isolated conformance of 'AccountSyncDecisionAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.action, .markConflictStale)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:115:9: warning: main actor-isolated conformance of 'AccountPendingHandling' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.pendingHandling, .preserveAsConflict)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:116:9: warning: main actor-isolated conformance of 'AccountConflictPolicy' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.conflictPolicy, .noSilentResurrect)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:130:9: warning: main actor-isolated conformance of 'AccountSyncDecisionAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.action, .markConflictStale)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:131:9: warning: main actor-isolated conformance of 'AccountConflictPolicy' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.conflictPolicy, .sameEffectiveAtPriceConflict)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:145:9: warning: main actor-isolated conformance of 'AccountSyncDecisionAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.action, .dedupeHistoryFingerprint)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:146:9: warning: main actor-isolated conformance of 'AccountConflictPolicy' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.conflictPolicy, .hideTaskDebugHistoryEntries)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:161:9: warning: main actor-isolated conformance of 'AccountSyncDecisionAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.action, .markConflictStale)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:162:9: warning: main actor-isolated conformance of 'AccountConflictPolicy' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.conflictPolicy, .noSilentResurrect)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:176:9: warning: main actor-isolated conformance of 'AccountSyncDecisionAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.action, .useRemoteOrdering)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:177:9: warning: main actor-isolated conformance of 'AccountConflictPolicy' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.conflictPolicy, .preferRemoteTimestampsAndEventIDs)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:191:9: warning: main actor-isolated conformance of 'AccountSyncDecisionAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.action, .drainEventsLightReconcile)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:192:9: warning: main actor-isolated conformance of 'AccountConflictPolicy' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.conflictPolicy, .remoteSourceOfTruth)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:206:9: warning: main actor-isolated conformance of 'AccountSyncDecisionAction' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.action, .keepAnonymousOrPreviousOwnerBound)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:207:9: warning: main actor-isolated conformance of 'AccountRemoteMutationPolicy' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.remoteMutation, .blocked)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/AccountSyncPolicyTests.swift:208:9: warning: main actor-isolated conformance of 'AccountPendingHandling' to 'Equatable' cannot be used in nonisolated context; this is an error in the Swift 6 language mode
        XCTAssertEqual(decision.pendingHandling, .keepLocalOnly)
        ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/SyncEventOutboxDrainDebugViewModelTests.swift:185:31: warning: converting non-Sendable function value to '@MainActor @Sendable (String, Date) async throws -> SyncEventOutboxCounts' may introduce data races
            fetchCounts: fake.fetchCounts(ownerUserID:now:),
                              ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/SyncEventOutboxDrainDebugViewModelTests.swift:186:29: warning: converting non-Sendable function value to '@MainActor @Sendable (String, Int, Int?) async throws -> SyncEventOutboxDrainOutcome' may introduce data races
            drainOnce: fake.drainOnce(ownerUserID:limit:fetchScanLimit:)
                            ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/SyncEventOutboxDrainDebugViewModelTests.swift:289:31: warning: converting non-Sendable function value to '@MainActor @Sendable (String, Date) async throws -> SyncEventOutboxCounts' may introduce data races
            fetchCounts: fake.fetchCounts(ownerUserID:now:),
                              ^
/Users/minxiang/Desktop/iOSMerchandiseControl/iOSMerchandiseControlTests/SyncEventOutboxDrainDebugViewModelTests.swift:290:29: warning: converting non-Sendable function value to '@MainActor @Sendable (String, Int, Int?) async throws -> SyncEventOutboxDrainOutcome' may introduce data races
            drainOnce: fake.drainOnce(ownerUserID:limit:fetchScanLimit:)
                            ^
note: Disabling hardened runtime with ad-hoc codesigning. (in target 'iOSMerchandiseControl' from project 'iOSMerchandiseControl')
2026-05-24 22:21:44.996 xcodebuild[73362:21158901] [MT] IDETestOperationsObserverDebug: 2.584 elapsed -- Testing started completed.
2026-05-24 22:21:44.996 xcodebuild[73362:21158901] [MT] IDETestOperationsObserverDebug: 0.000 sec, +0.000 sec -- start
2026-05-24 22:21:44.996 xcodebuild[73362:21158901] [MT] IDETestOperationsObserverDebug: 2.584 sec, +2.584 sec -- end
Testing started

EXIT_CODE 0
