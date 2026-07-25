import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class AccountOwnerStoreSafetyTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testNativeDecisionDialogPolicyExposesReplacementOnlyForVerifiedOwnerReviewReasons() {
        for reason in [
            OwnerStoreBindingReviewReason.unboundDirty,
            .accountMismatch,
            .shopMismatch,
            .bindingMetadataMismatch,
            .replacementInterrupted
        ] {
            XCTAssertTrue(AccountSyncDecisionDialogPolicy.allowsCloudReplacement(
                for: ownerReviewDecision(reason)
            ))
        }

        for reason in [
            OwnerStoreBindingReviewReason.localStateUnavailable,
            .shopContextUnavailable
        ] {
            XCTAssertFalse(AccountSyncDecisionDialogPolicy.allowsCloudReplacement(
                for: ownerReviewDecision(reason)
            ))
        }
    }

    func testAuthenticatedReplacementUserRejectsStaleExpiredAndTransitioningSessions() {
        let userID = UUID()
        let valid = SupabaseAuthSessionInfo(
            userID: userID,
            email: nil,
            provider: "google",
            isExpired: false
        )
        let expired = SupabaseAuthSessionInfo(
            userID: userID,
            email: nil,
            provider: "google",
            isExpired: true
        )

        XCTAssertNil(AccountSyncDecisionDialogPolicy.authenticatedUserID(
            isSignedIn: false,
            isTransitioning: false,
            sessionInfo: valid
        ))
        XCTAssertNil(AccountSyncDecisionDialogPolicy.authenticatedUserID(
            isSignedIn: true,
            isTransitioning: true,
            sessionInfo: valid
        ))
        XCTAssertNil(AccountSyncDecisionDialogPolicy.authenticatedUserID(
            isSignedIn: true,
            isTransitioning: false,
            sessionInfo: expired
        ))
        XCTAssertEqual(AccountSyncDecisionDialogPolicy.authenticatedUserID(
            isSignedIn: true,
            isTransitioning: false,
            sessionInfo: valid
        ), userID)
    }

    func testNativeDecisionDialogPresentsOncePerOwnerShopIdentityAndCanReopenManually() {
        let decision = ownerReviewDecision(.accountMismatch)
        let accountA = AccountBindingStore.redactedAccountHash(for: "account-a")
        let accountB = AccountBindingStore.redactedAccountHash(for: "account-b")
        let storeA = LocalStoreIdentity(rawValue: "shop-a")
        let storeB = LocalStoreIdentity(rawValue: "shop-b")
        let identityA = AccountSyncDecisionDialogPolicy.presentationIdentity(
            decision: decision,
            currentAccountHash: accountA,
            activeStoreIdentity: storeA,
            currentBinding: nil,
            pendingReplacement: nil
        )
        let accountChanged = AccountSyncDecisionDialogPolicy.presentationIdentity(
            decision: decision,
            currentAccountHash: accountB,
            activeStoreIdentity: storeA,
            currentBinding: nil,
            pendingReplacement: nil
        )
        let shopChanged = AccountSyncDecisionDialogPolicy.presentationIdentity(
            decision: decision,
            currentAccountHash: accountA,
            activeStoreIdentity: storeB,
            currentBinding: nil,
            pendingReplacement: nil
        )

        var presented: Set<String> = []
        XCTAssertTrue(AccountSyncDecisionDialogPolicy.shouldPresentAutomatically(
            identity: identityA,
            alreadyPresented: presented
        ))
        presented.insert(identityA)
        XCTAssertFalse(AccountSyncDecisionDialogPolicy.shouldPresentAutomatically(
            identity: identityA,
            alreadyPresented: presented
        ))
        XCTAssertTrue(AccountSyncDecisionDialogPolicy.canPresentManually(identity: identityA))
        XCTAssertNotEqual(identityA, accountChanged)
        XCTAssertNotEqual(identityA, shopChanged)
    }

    func testAutomaticPresentationIdentityPersistsAcrossRelaunchAndRemainsBounded() {
        let suiteName = "AccountOwnerStoreSafetyTests.presentation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let firstLaunch = AccountBindingStore(defaults: defaults, key: "fixture.binding")
        let secondLaunch = AccountBindingStore(defaults: defaults, key: "fixture.binding")
        let identity = AccountBindingStore.redactedAccountHash(for: "mismatch-a")

        XCTAssertTrue(firstLaunch.markDecisionIdentityAutomaticallyPresented(identity))
        XCTAssertFalse(secondLaunch.markDecisionIdentityAutomaticallyPresented(identity))
        XCTAssertTrue(AccountSyncDecisionDialogPolicy.canPresentManually(identity: identity))

        for index in 0..<63 {
            XCTAssertTrue(firstLaunch.markDecisionIdentityAutomaticallyPresented(
                AccountBindingStore.redactedAccountHash(for: "mismatch-\(index)")
            ))
        }
        XCTAssertEqual(secondLaunch.automaticallyPresentedDecisionIdentities.count, 64)
        let overflowIdentity = AccountBindingStore.redactedAccountHash(for: "mismatch-overflow")
        XCTAssertFalse(firstLaunch.markDecisionIdentityAutomaticallyPresented(overflowIdentity))
        XCTAssertTrue(secondLaunch.isAutomaticDecisionPresentationDisabled)
        XCTAssertFalse(secondLaunch.automaticallyPresentedDecisionIdentities.contains(overflowIdentity))
        XCTAssertTrue(secondLaunch.automaticallyPresentedDecisionIdentities.contains(identity))
        XCTAssertTrue(AccountSyncDecisionDialogPolicy.canPresentManually(identity: overflowIdentity))
    }

    func testReplacementTargetFailsClosedWithoutResolvedCurrentShop() {
        let decision = ownerReviewDecision(.accountMismatch)
        let store = LocalStoreIdentity(rawValue: "shop-current")

        XCTAssertNil(AccountSyncDecisionDialogPolicy.replacementTarget(
            for: decision,
            isShopResolutionReady: false,
            selectedStoreIdentity: store
        ))
        XCTAssertNil(AccountSyncDecisionDialogPolicy.replacementTarget(
            for: decision,
            isShopResolutionReady: true,
            selectedStoreIdentity: nil
        ))
        XCTAssertEqual(AccountSyncDecisionDialogPolicy.replacementTarget(
            for: decision,
            isShopResolutionReady: true,
            selectedStoreIdentity: store
        ), store)
    }

    func testDestructiveDialogActionIsDisabledUntilAccountAndShopAreVerified() {
        let decision = ownerReviewDecision(.accountMismatch)
        let store = LocalStoreIdentity(rawValue: "shop-current")

        XCTAssertFalse(AccountSyncDecisionDialogPolicy.isCloudReplacementEnabled(
            for: decision,
            hasAuthenticatedAccount: false,
            isShopResolutionReady: true,
            selectedStoreIdentity: store
        ))
        XCTAssertFalse(AccountSyncDecisionDialogPolicy.isCloudReplacementEnabled(
            for: decision,
            hasAuthenticatedAccount: true,
            isShopResolutionReady: false,
            selectedStoreIdentity: store
        ))
        XCTAssertFalse(AccountSyncDecisionDialogPolicy.isCloudReplacementEnabled(
            for: decision,
            hasAuthenticatedAccount: true,
            isShopResolutionReady: true,
            selectedStoreIdentity: nil
        ))
        XCTAssertFalse(AccountSyncDecisionDialogPolicy.isCloudReplacementEnabled(
            for: ownerReviewDecision(.localStateUnavailable),
            hasAuthenticatedAccount: true,
            isShopResolutionReady: true,
            selectedStoreIdentity: store
        ))
        XCTAssertTrue(AccountSyncDecisionDialogPolicy.isCloudReplacementEnabled(
            for: decision,
            hasAuthenticatedAccount: true,
            isShopResolutionReady: true,
            selectedStoreIdentity: store
        ))
    }

    func testShopUnavailableReasonCannotBeOverriddenByStaleBaselineAccountMismatch() {
        XCTAssertEqual(
            OptionsSyncSummaryProvider.applyingBaselineAccountMismatch(
                to: .reviewRequired(.shopContextUnavailable),
                baselineStatus: .accountMismatch
            ),
            .reviewRequired(.shopContextUnavailable)
        )
        XCTAssertEqual(
            OptionsSyncSummaryProvider.applyingBaselineAccountMismatch(
                to: .matched,
                baselineStatus: .accountMismatch
            ),
            .reviewRequired(.accountMismatch)
        )
    }

    func testSuccessfulReplacementAutomaticallySchedulesBootstrapThroughOrchestrator() async throws {
        let suiteName = "Task139ReplacementBootstrap-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let runtime = RecordingReplacementRuntime()
        let orchestrator = SyncOrchestrator(
            automaticRuntime: runtime,
            authViewModel: SupabaseAuthViewModel(authService: nil),
            activityCenter: ForegroundCloudWorkflowActivityCenter(),
            syncEventSignalWatcher: nil,
            stateStore: SyncStateStore(
                defaults: defaults,
                keyPrefix: "task139.replacementBootstrap"
            ),
            decisionInputProvider: BootstrapDecisionInputProvider(ownerUserID: UUID()),
            backgroundScheduler: SyncNoopBackgroundTaskScheduler()
        )

        _ = try await orchestrator.performAccountStoreReplacement {
            return AccountStoreReplacementResult(
                deletedProducts: 1,
                deletedSuppliers: 0,
                deletedCategories: 0,
                deletedProductPrices: 0,
                deletedHistorySessions: 0,
                deletedOutboxEntries: 0,
                deletedBaselineRows: 0
            )
        }
        for _ in 0..<100 where runtime.actions.isEmpty {
            await Task.yield()
        }

        XCTAssertEqual(runtime.cancelAndWaitCount, 1)
        XCTAssertEqual(runtime.resumeAfterReplacementCount, 1)
        XCTAssertEqual(runtime.actions.first, .bootstrap)
    }

    func testReplacementStartedFromRecoveryRequiredStillSchedulesBootstrap() async throws {
        let suiteName = "Task139ReplacementRecovery-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        let bindingStore = AccountBindingStore(defaults: defaults)
        let stateStore = SyncStateStore(
            defaults: defaults,
            keyPrefix: "task139.replacementRecovery"
        )
        stateStore.recordRunResult(.recoveryRequired())
        let runtime = RecordingReplacementRuntime()
        let orchestrator = SyncOrchestrator(
            automaticRuntime: runtime,
            authViewModel: SupabaseAuthViewModel(authService: nil),
            activityCenter: ForegroundCloudWorkflowActivityCenter(),
            syncEventSignalWatcher: nil,
            stateStore: stateStore,
            decisionInputProvider: BootstrapDecisionInputProvider(ownerUserID: owner),
            backgroundScheduler: SyncNoopBackgroundTaskScheduler()
        )

        _ = try await orchestrator.performAccountStoreReplacement {
            XCTAssertTrue(bindingStore.beginReplacement(
                accountHash: AccountBindingStore.accountHash(for: owner),
                storeIdentity: shop.localStoreIdentity
            ))
            return AccountStoreReplacementResult(
                deletedProducts: 0,
                deletedSuppliers: 0,
                deletedCategories: 0,
                deletedProductPrices: 0,
                deletedHistorySessions: 0,
                deletedOutboxEntries: 0,
                deletedBaselineRows: 0
            )
        }
        for _ in 0..<100 where runtime.actions.isEmpty {
            await Task.yield()
        }

        XCTAssertEqual(runtime.cancelAndWaitCount, 1)
        XCTAssertEqual(runtime.resumeAfterReplacementCount, 1)
        XCTAssertEqual(runtime.actions.first, .bootstrap)
        XCTAssertEqual(stateStore.state.phase, .recoveryRequired)
        XCTAssertEqual(stateStore.state.lastOutcome, .succeeded)
        XCTAssertTrue(bindingStore.hasPendingReplacementJournal)
    }

    func testDecisionUIUsesOneNativeAlertWithExactlyTwoChoices() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("iOSMerchandiseControl/Sync/Account/AccountSyncDecisionView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("content.alert("))
        XCTAssertEqual(source.components(separatedBy: "Button(L(\"options.accountDecision.choice.").count - 1, 2)
        XCTAssertTrue(source.contains("Button(L(\"options.accountDecision.choice.keepLocal\"), role: .cancel)"))
        XCTAssertTrue(source.contains("Button(L(\"options.accountDecision.choice.replaceWithCloud\"), role: .destructive)"))
        XCTAssertFalse(source.contains(".sheet("))
        XCTAssertFalse(source.contains("confirmationDialog"))
        XCTAssertFalse(source.contains("NavigationStack"))
        XCTAssertFalse(source.contains("List {"))

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let optionsSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("iOSMerchandiseControl/OptionsView.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(optionsSource.contains("@EnvironmentObject private var shopContextStore: ShopContextStore"))
        XCTAssertTrue(optionsSource.contains(".onChange(of: shopContextStore.context)"))
        XCTAssertTrue(optionsSource.contains("performAccountStoreReplacement"))
        XCTAssertTrue(optionsSource.contains("beginAccountStoreReplacementLease"))
        XCTAssertTrue(optionsSource.contains("authenticatedUserID"))
        XCTAssertTrue(optionsSource.contains("discardLocalDataAndBind("))
        XCTAssertFalse(optionsSource.contains("prepareReplacement("))

        let runtimeSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRuntimeFacade.swift"
            ),
            encoding: .utf8
        )
        let backgroundSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "iOSMerchandiseControl/Sync/Automatic/Background/SyncBackgroundTaskScheduler.swift"
            ),
            encoding: .utf8
        )
        XCTAssertTrue(runtimeSource.contains("singleFlight: .processShared"))
        XCTAssertTrue(runtimeSource.contains("cancellationPolicy: .processShared"))
        XCTAssertTrue(backgroundSource.contains("singleFlight: .processShared"))
        XCTAssertTrue(backgroundSource.contains("cancellationPolicy: .processShared"))

        let editProductSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent("iOSMerchandiseControl/EditProductView.swift"),
            encoding: .utf8
        )
        XCTAssertEqual(
            editProductSource.components(separatedBy: "finishMutationLease").count - 1,
            2
        )
    }

    func testConfirmedReplacementNeverMutatesTheActiveStoreBeforeAtomicActivation() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("iOSMerchandiseControl/Sync/Account/AccountStoreReplacementCoordinator.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(source.contains("No active SwiftData row, binding, watermark, outbox or"))
        XCTAssertTrue(source.contains("bindingStore.beginReplacement("))
        XCTAssertFalse(source.contains("context.delete("))
        XCTAssertFalse(source.contains("context.enumerate("))
        XCTAssertFalse(source.contains("saveBinding("))
        XCTAssertFalse(source.contains("resetForReplacement"))
        XCTAssertFalse(source.contains("markPendingReplacementWipeCommitted"))

        let engineSource = try String(
            contentsOf: sourceURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Automatic/Core/AutomaticSyncEngine.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(engineSource.contains(
            "recoverySnapshotPullProvider.publicationMode == .atomicGeneration"
        ))
        XCTAssertTrue(engineSource.contains("summary.completedRecoveryJournal"))
        XCTAssertTrue(engineSource.contains("summary.activatedGenerationID != nil"))
        XCTAssertTrue(engineSource.contains("!bindingStore.hasPendingReplacementJournal"))
        XCTAssertFalse(engineSource.contains("drainReplacementRemoteTail"))
        XCTAssertFalse(engineSource.contains("watermarkStore.saveAuthoritativeRecoveryCheckpoint"))

        let runtimeSource = try String(
            contentsOf: sourceURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appendingPathComponent("Automatic/Composition/AutomaticSyncRuntimeFactory.swift"),
            encoding: .utf8
        )
        XCTAssertTrue(runtimeSource.contains("AtomicGenerationRecoverySnapshotPullService("))
        XCTAssertFalse(runtimeSource.contains("AutomaticRecoverySnapshotPullService("))
    }

    func testUnresolvedShopContextFailsClosedBeforeAnyBindingOrBootstrap() async throws {
        let fixture = makeFixture()
        let owner = UUID()
        let provider = SyncDecisionInputProvider(
            modelContainer: fixture.container,
            initialNetworkStatus: .satisfied,
            bindingStore: fixture.bindingStore,
            selectedShopStore: fixture.selectedShopStore
        )

        let snapshot = await provider.makeSnapshot(
            triggerSource: .rootForeground,
            isAuthenticated: true,
            ownerUserID: owner,
            isSyncBusy: false
        )

        XCTAssertEqual(snapshot.ownerStoreBindingResolution, .reviewRequired(.shopContextUnavailable))
        XCTAssertFalse(snapshot.accountBindingMatches)
        XCTAssertFalse(snapshot.requiresBootstrap)
        XCTAssertEqual(SyncDecisionEngine.decide(snapshot.input), .blocked(.accountDecisionRequired))
        XCTAssertNil(fixture.bindingStore.currentBinding)
    }

    func testReadyMarkerWithoutSelectedShopFailsClosedWithoutDefaultFallback() async throws {
        let fixture = makeFixture()
        let owner = UUID()
        let accountHash = AccountBindingStore.accountHash(for: owner)
        XCTAssertTrue(fixture.selectedShopStore.markResolutionReady(accountHash: accountHash))
        let provider = SyncDecisionInputProvider(
            modelContainer: fixture.container,
            initialNetworkStatus: .satisfied,
            bindingStore: fixture.bindingStore,
            selectedShopStore: fixture.selectedShopStore
        )

        let snapshot = await provider.makeSnapshot(
            triggerSource: .rootForeground,
            isAuthenticated: true,
            ownerUserID: owner,
            isSyncBusy: false
        )

        XCTAssertEqual(snapshot.ownerStoreBindingResolution, .reviewRequired(.shopContextUnavailable))
        XCTAssertFalse(snapshot.requiresBootstrap)
        XCTAssertEqual(SyncDecisionEngine.decide(snapshot.input), .blocked(.accountDecisionRequired))
        XCTAssertNil(fixture.bindingStore.currentBinding)
    }

    func testUnauthenticatedSnapshotPreservesStaleOwnerJournalAndRealtimeSignal() async throws {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        let accountHash = AccountBindingStore.accountHash(for: owner)
        XCTAssertTrue(fixture.selectedShopStore.save(shop, accountHash: accountHash))
        XCTAssertTrue(fixture.bindingStore.beginReplacement(
            accountHash: accountHash,
            storeIdentity: shop.localStoreIdentity
        ))
        let provider = SyncDecisionInputProvider(
            modelContainer: fixture.container,
            initialNetworkStatus: .satisfied,
            bindingStore: fixture.bindingStore,
            selectedShopStore: fixture.selectedShopStore
        )
        await provider.recordRealtimeEvent()

        let blocked = await provider.makeSnapshot(
            triggerSource: .rootForeground,
            isAuthenticated: false,
            ownerUserID: owner,
            isSyncBusy: false
        )

        XCTAssertFalse(blocked.isAuthenticated)
        XCTAssertNil(blocked.ownerUserID)
        XCTAssertFalse(blocked.requiresBootstrap)
        XCTAssertFalse(blocked.hasRealtimeEvent)
        XCTAssertNil(fixture.bindingStore.currentBinding)
        XCTAssertEqual(fixture.bindingStore.pendingReplacement?.storeIdentity, shop.localStoreIdentity)

        let authenticated = await provider.makeSnapshot(
            triggerSource: .rootForeground,
            isAuthenticated: true,
            ownerUserID: owner,
            isSyncBusy: false
        )
        XCTAssertTrue(authenticated.hasRealtimeEvent)
        XCTAssertEqual(
            authenticated.ownerStoreBindingResolution,
            .matched
        )
        XCTAssertTrue(authenticated.requiresBootstrap)
        XCTAssertEqual(
            SyncDecisionEngine.decide(authenticated.input),
            .bootstrap
        )
        XCTAssertEqual(fixture.bindingStore.pendingReplacement?.accountHash, accountHash)
        XCTAssertEqual(fixture.bindingStore.pendingReplacement?.storeIdentity, shop.localStoreIdentity)
        XCTAssertEqual(fixture.bindingStore.pendingRecoveryJournal?.phase, .prepared)
        XCTAssertFalse(fixture.bindingStore.pendingReplacementWipeCommitted)
        XCTAssertNil(fixture.bindingStore.currentBinding)
    }

    func testUndecodableReplacementJournalBlocksSyncAndIsPreserved() async throws {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        let accountHash = AccountBindingStore.accountHash(for: owner)
        XCTAssertTrue(fixture.selectedShopStore.save(shop, accountHash: accountHash))
        fixture.defaults.set(Data([0xFF, 0x00]), forKey: "sync.accountBinding.v1.pendingReplacement")
        let provider = SyncDecisionInputProvider(
            modelContainer: fixture.container,
            initialNetworkStatus: .satisfied,
            bindingStore: fixture.bindingStore,
            selectedShopStore: fixture.selectedShopStore
        )

        let snapshot = await provider.makeSnapshot(
            triggerSource: .networkReconnect,
            isAuthenticated: true,
            ownerUserID: owner,
            isSyncBusy: false
        )

        XCTAssertEqual(snapshot.ownerStoreBindingResolution, .reviewRequired(.replacementInterrupted))
        XCTAssertFalse(snapshot.requiresBootstrap)
        XCTAssertNil(fixture.bindingStore.currentBinding)
        XCTAssertNil(fixture.bindingStore.pendingReplacement)
        XCTAssertTrue(fixture.bindingStore.hasPendingReplacementJournal)
    }

    func testOwnerStoreReviewReasonsProduceZeroBusinessProviderCalls() async {
        let recorder = BusinessOutboundRecorder()
        let engine = AutomaticSyncEngine(
            catalogPushProvider: recorder,
            productPriceProvider: recorder,
            historySessionProvider: recorder,
            incrementalPullProvider: recorder,
            activityRegistrationProvider: recorder
        )
        let owner = UUID()

        for reason in [
            OwnerStoreBindingReviewReason.unboundDirty,
            .accountMismatch,
            .shopMismatch
        ] {
            let resolution = OwnerStoreBindingResolution.reviewRequired(reason)
            let snapshot = SyncDecisionInputSnapshot(
                triggerSource: .networkReconnect,
                isAuthenticated: true,
                ownerUserID: owner,
                ownerStoreBindingResolution: resolution,
                accountBindingMatches: resolution.allowsAutomaticSync,
                networkStatus: .satisfied,
                pendingLocalChanges: .empty,
                pendingOutboxCount: reason == .unboundDirty ? 1 : 0,
                requiresBootstrap: false,
                requiresFullRecovery: false,
                hasRecoveryDrift: false,
                hasRealtimeEvent: true,
                isSyncBusy: false,
                hasStateReadFailure: false,
                requestsLightReconcile: true
            )
            let action = SyncDecisionEngine.decide(snapshot.input)

            XCTAssertEqual(action, .blocked(.accountDecisionRequired), "Unexpected action for \(reason)")
            let result = await engine.run(
                action: action,
                source: .networkReconnect,
                ownerUserID: owner
            )
            XCTAssertEqual(result.status, .blocked)
            XCTAssertEqual(result.blockReason, .accountDecisionRequired)
            XCTAssertFalse(result.didWork)
        }

        let outboundCalls = await recorder.totalCalls()
        XCTAssertEqual(outboundCalls, 0)
    }

    func testUnboundEmptyStoreAutoBindsCurrentAccountAndShopBeforeBootstrap() async throws {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        fixture.selectedShopStore.save(shop, accountHash: AccountBindingStore.accountHash(for: owner))
        let provider = SyncDecisionInputProvider(
            modelContainer: fixture.container,
            initialNetworkStatus: .satisfied,
            bindingStore: fixture.bindingStore,
            selectedShopStore: fixture.selectedShopStore
        )

        let snapshot = await provider.makeSnapshot(
            triggerSource: .rootForeground,
            isAuthenticated: true,
            ownerUserID: owner,
            isSyncBusy: false
        )

        XCTAssertEqual(snapshot.ownerStoreBindingResolution, .autoBound)
        XCTAssertTrue(snapshot.accountBindingMatches)
        XCTAssertTrue(snapshot.requiresBootstrap)
        XCTAssertEqual(fixture.bindingStore.currentBinding?.accountHash, AccountBindingStore.accountHash(for: owner))
        XCTAssertEqual(fixture.bindingStore.currentBinding?.storeIdentity.storeId, shop.shopID.uuidString.lowercased())
    }

    func testUnboundDirtyStoreRequiresReviewAndNeverBootstrapsOrPushes() async throws {
        let fixture = makeFixture()
        let owner = UUID()
        XCTAssertTrue(fixture.selectedShopStore.save(
            selectedShop(id: UUID()),
            accountHash: AccountBindingStore.accountHash(for: owner)
        ))
        let context = ModelContext(fixture.container)
        context.insert(Product(barcode: "TASK139_UNBOUND_DIRTY"))
        try context.save()
        let provider = SyncDecisionInputProvider(
            modelContainer: fixture.container,
            initialNetworkStatus: .satisfied,
            bindingStore: fixture.bindingStore,
            selectedShopStore: fixture.selectedShopStore
        )

        let snapshot = await provider.makeSnapshot(
            triggerSource: .rootForeground,
            isAuthenticated: true,
            ownerUserID: owner,
            isSyncBusy: false
        )

        XCTAssertEqual(snapshot.ownerStoreBindingResolution, .reviewRequired(.unboundDirty))
        XCTAssertFalse(snapshot.accountBindingMatches)
        XCTAssertFalse(snapshot.requiresBootstrap)
        XCTAssertEqual(SyncDecisionEngine.decide(snapshot.input), .blocked(.accountDecisionRequired))
        XCTAssertNil(fixture.bindingStore.currentBinding)
    }

    func testUnboundOutboxOnlyStoreIsDirtyAndNeverAutoBinds() async throws {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        XCTAssertTrue(fixture.selectedShopStore.save(
            shop,
            accountHash: AccountBindingStore.accountHash(for: owner)
        ))
        let context = ModelContext(fixture.container)
        context.insert(SyncEventOutboxEntry(
            ownerUserID: owner.uuidString.lowercased(),
            storeId: shop.localStoreIdentity.storeId,
            localStoreId: shop.localStoreIdentity.localStoreId,
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 1,
            entityIDsShape: "products:count=1",
            metadataShape: "source=fixture",
            nextRetryAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        ))
        try context.save()
        let provider = SyncDecisionInputProvider(
            modelContainer: fixture.container,
            initialNetworkStatus: .satisfied,
            bindingStore: fixture.bindingStore,
            selectedShopStore: fixture.selectedShopStore
        )

        let snapshot = await provider.makeSnapshot(
            triggerSource: .networkReconnect,
            isAuthenticated: true,
            ownerUserID: owner,
            isSyncBusy: false
        )

        XCTAssertEqual(snapshot.pendingOutboxCount, 1)
        XCTAssertEqual(snapshot.ownerStoreBindingResolution, .reviewRequired(.unboundDirty))
        XCTAssertEqual(SyncDecisionEngine.decide(snapshot.input), .blocked(.accountDecisionRequired))
        XCTAssertNil(fixture.bindingStore.currentBinding)
    }

    func testDifferentAccountFailsClosedWithoutRebinding() async throws {
        let fixture = makeFixture()
        let previousOwner = UUID()
        let currentOwner = UUID()
        let original = LocalStoreIdentity(rawValue: "shop-a")
        XCTAssertTrue(fixture.bindingStore.saveBinding(
            accountHash: AccountBindingStore.accountHash(for: previousOwner),
            storeIdentity: original
        ))
        let provider = SyncDecisionInputProvider(
            modelContainer: fixture.container,
            initialNetworkStatus: .satisfied,
            bindingStore: fixture.bindingStore,
            selectedShopStore: fixture.selectedShopStore
        )

        let snapshot = await provider.makeSnapshot(
            triggerSource: .networkReconnect,
            isAuthenticated: true,
            ownerUserID: currentOwner,
            isSyncBusy: false
        )

        XCTAssertEqual(snapshot.ownerStoreBindingResolution, .reviewRequired(.accountMismatch))
        XCTAssertEqual(SyncDecisionEngine.decide(snapshot.input), .blocked(.accountDecisionRequired))
        XCTAssertEqual(fixture.bindingStore.currentBinding?.accountHash, AccountBindingStore.accountHash(for: previousOwner))
        XCTAssertEqual(fixture.bindingStore.currentBinding?.storeIdentity, original)
    }

    func testSameAccountDifferentShopFailsClosedWithoutRebinding() async throws {
        let fixture = makeFixture()
        let owner = UUID()
        let oldShop = selectedShop(id: UUID())
        let newShop = selectedShop(id: UUID())
        let accountHash = AccountBindingStore.accountHash(for: owner)
        XCTAssertTrue(fixture.bindingStore.saveBinding(
            accountHash: accountHash,
            storeIdentity: oldShop.localStoreIdentity
        ))
        fixture.selectedShopStore.save(newShop, accountHash: accountHash)
        let provider = SyncDecisionInputProvider(
            modelContainer: fixture.container,
            initialNetworkStatus: .satisfied,
            bindingStore: fixture.bindingStore,
            selectedShopStore: fixture.selectedShopStore
        )

        let snapshot = await provider.makeSnapshot(
            triggerSource: .networkReconnect,
            isAuthenticated: true,
            ownerUserID: owner,
            isSyncBusy: false
        )

        XCTAssertEqual(snapshot.ownerStoreBindingResolution, .reviewRequired(.shopMismatch))
        XCTAssertEqual(SyncDecisionEngine.decide(snapshot.input), .blocked(.accountDecisionRequired))
        XCTAssertEqual(fixture.bindingStore.currentBinding?.storeIdentity, oldShop.localStoreIdentity)
    }

    func testSameScopeDirtyStoreNeverUsesDestructiveBootstrapRecovery() async throws {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        XCTAssertTrue(fixture.selectedShopStore.save(
            shop,
            accountHash: AccountBindingStore.accountHash(for: owner)
        ))
        let identity = shop.localStoreIdentity
        XCTAssertTrue(fixture.bindingStore.saveBinding(
            accountHash: AccountBindingStore.accountHash(for: owner),
            storeIdentity: identity
        ))
        let context = ModelContext(fixture.container)
        context.insert(Product(barcode: "TASK139_SAME_SCOPE"))
        try context.save()
        let provider = SyncDecisionInputProvider(
            modelContainer: fixture.container,
            initialNetworkStatus: .satisfied,
            bindingStore: fixture.bindingStore,
            selectedShopStore: fixture.selectedShopStore
        )

        let snapshot = await provider.makeSnapshot(
            triggerSource: .rootForeground,
            isAuthenticated: true,
            ownerUserID: owner,
            isSyncBusy: false
        )

        XCTAssertEqual(snapshot.ownerStoreBindingResolution, .matched)
        XCTAssertFalse(snapshot.requiresBootstrap)
        XCTAssertEqual(SyncDecisionEngine.decide(snapshot.input), .lightReconcile)
    }

    func testConfirmedDiscardOnlyPreparesJournalAndLeavesActiveStateUntouched() async throws {
        let fixture = makeFixture()
        let oldOwner = UUID()
        let newOwner = UUID()
        let targetShop = selectedShop(id: UUID())
        let targetIdentity = targetShop.localStoreIdentity
        let watermarkStore = WatermarkStore(defaults: fixture.defaults)
        let targetWatermarkScope = WatermarkStore.Scope(
            ownerUserID: newOwner,
            storeIdentity: targetIdentity
        )
        let unrelatedWatermarkScope = WatermarkStore.Scope(
            ownerUserID: oldOwner,
            storeIdentity: LocalStoreIdentity(rawValue: "fixture-shop-unrelated")
        )
        watermarkStore.save(900, for: targetWatermarkScope)
        watermarkStore.save(700, for: unrelatedWatermarkScope)
        fixture.defaults.set(
            600,
            forKey: WatermarkStore.legacyOwnerWatermarkKey(ownerUserID: oldOwner)
        )
        XCTAssertTrue(fixture.selectedShopStore.save(
            targetShop,
            accountHash: AccountBindingStore.accountHash(for: newOwner)
        ))
        XCTAssertTrue(fixture.bindingStore.saveBinding(
            accountHash: AccountBindingStore.accountHash(for: oldOwner),
            storeIdentity: LocalStoreIdentity(rawValue: "fixture-shop-a")
        ))
        let context = ModelContext(fixture.container)
        let supplier = Supplier(name: "TASK139_SUPPLIER")
        let category = ProductCategory(name: "TASK139_CATEGORY")
        let product = Product(
            barcode: "TASK139_DISCARD_FIXTURE",
            supplier: supplier,
            category: category
        )
        context.insert(supplier)
        context.insert(category)
        context.insert(product)
        context.insert(ProductPrice(type: .retail, price: 12, product: product))
        context.insert(ProductPrice(type: .purchase, price: 6))
        context.insert(HistoryEntry(id: "TASK139_HISTORY"))
        context.insert(LocalPendingChange(
            ownerUserID: oldOwner,
            entityKind: .product,
            operation: .update,
            status: .pending,
            origin: .manualCatalogSave,
            logicalKey: "product:TASK139_DISCARD_FIXTURE"
        ))
        context.insert(SyncEventOutboxEntry(
            ownerUserID: oldOwner.uuidString.lowercased(),
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 1,
            entityIDsShape: "products:count=1",
            metadataShape: "source=fixture",
            nextRetryAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        ))
        context.insert(SupabaseCatalogBaselineRun(
            ownerUserUUID: oldOwner,
            status: .valid,
            appliedAt: Date()
        ))
        try context.save()

        let result = try AccountStoreReplacementCoordinator(
            context: context,
            bindingStore: fixture.bindingStore
        ).discardLocalDataAndBind(
            userID: newOwner,
            storeIdentity: targetIdentity
        )

        XCTAssertEqual(result.deletedProducts, 0)
        XCTAssertEqual(result.deletedSuppliers, 0)
        XCTAssertEqual(result.deletedCategories, 0)
        XCTAssertEqual(result.deletedProductPrices, 0)
        XCTAssertEqual(result.deletedHistorySessions, 0)
        XCTAssertEqual(result.deletedOutboxEntries, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProductPrice>()), 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Supplier>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProductCategory>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HistoryEntry>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LocalPendingChange>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SyncEventOutboxEntry>()), 1)
        XCTAssertEqual(fixture.bindingStore.currentBinding?.accountHash, AccountBindingStore.accountHash(for: oldOwner))
        XCTAssertEqual(
            fixture.bindingStore.currentBinding?.storeIdentity,
            LocalStoreIdentity(rawValue: "fixture-shop-a")
        )
        XCTAssertEqual(
            fixture.bindingStore.pendingReplacement?.accountHash,
            AccountBindingStore.accountHash(for: newOwner)
        )
        XCTAssertEqual(fixture.bindingStore.pendingReplacement?.storeIdentity, targetIdentity)
        XCTAssertEqual(fixture.bindingStore.pendingRecoveryJournal?.phase, .prepared)
        XCTAssertFalse(fixture.bindingStore.pendingReplacementWipeCommitted)
        XCTAssertEqual(watermarkStore.watermark(for: targetWatermarkScope), 900)
        XCTAssertEqual(watermarkStore.watermark(for: unrelatedWatermarkScope), 700)
        XCTAssertEqual(
            fixture.defaults.integer(
                forKey: WatermarkStore.legacyOwnerWatermarkKey(ownerUserID: oldOwner)
            ),
            600
        )

        let provider = SyncDecisionInputProvider(
            modelContainer: fixture.container,
            initialNetworkStatus: .satisfied,
            bindingStore: fixture.bindingStore,
            selectedShopStore: fixture.selectedShopStore
        )
        let postReplacement = await provider.makeSnapshot(
            triggerSource: .rootForeground,
            isAuthenticated: true,
            ownerUserID: newOwner,
            isSyncBusy: false
        )
        XCTAssertEqual(postReplacement.ownerStoreBindingResolution, .matched)
        XCTAssertTrue(postReplacement.requiresBootstrap)
        XCTAssertEqual(SyncDecisionEngine.decide(postReplacement.input), .bootstrap)
    }

    func testPendingExactJournalForcesBootstrapAcrossPartialDataAndRelaunch() async throws {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        _ = prepareExactPendingReplacement(
            fixture: fixture,
            owner: owner,
            shop: shop,
            initialWatermark: 0
        )
        let context = ModelContext(fixture.container)
        context.insert(Product(barcode: "TASK139_PARTIAL_RECOVERY"))
        context.insert(SupabaseCatalogBaselineRun(
            ownerUserUUID: owner,
            status: .valid,
            appliedAt: Date()
        ))
        try context.save()

        for trigger in [
            SyncAutomaticTriggerSource.rootForeground,
            .networkReconnect
        ] {
            let relaunchedProvider = SyncDecisionInputProvider(
                modelContainer: fixture.container,
                initialNetworkStatus: .satisfied,
                bindingStore: fixture.bindingStore,
                selectedShopStore: fixture.selectedShopStore
            )
            let snapshot = await relaunchedProvider.makeSnapshot(
                triggerSource: trigger,
                isAuthenticated: true,
                ownerUserID: owner,
                isSyncBusy: false
            )

            XCTAssertEqual(snapshot.ownerStoreBindingResolution, .matched)
            XCTAssertTrue(snapshot.requiresBootstrap)
            XCTAssertFalse(snapshot.requiresFullRecovery)
            XCTAssertFalse(snapshot.hasRecoveryDrift)
            XCTAssertEqual(SyncDecisionEngine.decide(snapshot.input), .bootstrap)
            XCTAssertTrue(fixture.bindingStore.hasPendingReplacementJournal)
        }
    }

    func testBindingMutationAndPreparedJournalCompletionRemainFailClosedAndInvalidateLease() throws {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        _ = prepareExactPendingReplacement(
            fixture: fixture,
            owner: owner,
            shop: shop,
            initialWatermark: 0
        )
        let accountHash = AccountBindingStore.accountHash(for: owner)

        let beforeBindingWrite = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: owner,
            defaults: fixture.defaults,
            allowsPendingReplacement: true
        )
        XCTAssertTrue(fixture.bindingStore.saveBinding(
            accountHash: accountHash,
            storeIdentity: shop.localStoreIdentity
        ))
        XCTAssertThrowsError(try Task126OwnerStoreGate.revalidateAutomaticScope(
            beforeBindingWrite,
            defaults: fixture.defaults
        )) { error in
            XCTAssertEqual(error as? Task126OwnerStoreGateError, .scopeChanged)
        }
        XCTAssertThrowsError(try fixture.bindingStore.completePendingReplacementRecovery(
            accountHash: accountHash,
            storeIdentity: shop.localStoreIdentity,
            expectedLeaseGeneration: beforeBindingWrite.leaseGeneration
        )) { error in
            XCTAssertEqual(error as? Task126OwnerStoreGateError, .scopeChanged)
        }
        XCTAssertTrue(fixture.bindingStore.hasPendingReplacementJournal)

        let acceptedScope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: owner,
            defaults: fixture.defaults,
            allowsPendingReplacement: true
        )
        XCTAssertFalse(try fixture.bindingStore.completePendingReplacementRecovery(
            accountHash: accountHash,
            storeIdentity: shop.localStoreIdentity,
            expectedLeaseGeneration: acceptedScope.leaseGeneration
        ))
        XCTAssertTrue(fixture.bindingStore.hasPendingReplacementJournal)
        XCTAssertThrowsError(try Task126OwnerStoreGate.revalidateAutomaticScope(
            acceptedScope,
            defaults: fixture.defaults
        )) { error in
            XCTAssertEqual(error as? Task126OwnerStoreGateError, .scopeChanged)
        }
    }

    func testLegacyReplacementProviderIsRejectedBeforeProviderTailOrWatermarkMutation() async {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        let watermarkScope = prepareExactPendingReplacement(
            fixture: fixture,
            owner: owner,
            shop: shop,
            initialWatermark: 900
        )
        let operationRecorder = ReplacementOperationRecorder()
        let recovery = ReplacementRecoveryProvider(
            mode: .success(watermark: 42),
            operationRecorder: operationRecorder
        )
        var incrementalPage = SyncIncrementalPullSummary(
            syncType: .eventIncremental,
            eventsFetched: 1,
            watermarkBefore: 42,
            watermarkAfter: 50
        )
        incrementalPage.eventsProcessed = 1
        let reconcile = SyncIncrementalPullSummary(
            syncType: .lightReconcile,
            watermarkBefore: 50,
            watermarkAfter: 50
        )
        let tail = ReplacementTailProvider(
            mode: .success([incrementalPage, reconcile]),
            bindingStore: fixture.bindingStore,
            watermarkStore: WatermarkStore(defaults: fixture.defaults),
            watermarkScope: watermarkScope,
            operationRecorder: operationRecorder
        )
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: tail,
            recoverySnapshotPullProvider: recovery,
            activityRegistrationProvider: nil,
            defaults: fixture.defaults,
            bindingStore: fixture.bindingStore,
            watermarkStore: WatermarkStore(defaults: fixture.defaults)
        )

        let result = await engine.run(
            action: .noOp,
            source: .networkReconnect,
            ownerUserID: owner
        )
        let recoveryCallCount = await recovery.callCount
        let operations = await operationRecorder.operations()
        let forcedReconcileFlags = await tail.forceLightReconcileFlags()
        let journalVisibility = await tail.journalVisibilityDuringCalls()

        XCTAssertEqual(result.status, .failed)
        XCTAssertFalse(result.didWork)
        XCTAssertEqual(recoveryCallCount, 0)
        XCTAssertEqual(operations, [])
        XCTAssertEqual(forcedReconcileFlags, [])
        XCTAssertEqual(journalVisibility, [])
        XCTAssertTrue(fixture.bindingStore.hasPendingReplacementJournal)
        XCTAssertEqual(
            WatermarkStore(defaults: fixture.defaults).watermark(for: watermarkScope),
            900
        )
    }

    func testLegacyReplacementProviderCannotTriggerSnapshotRetryFromTail() async {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        let watermarkScope = prepareExactPendingReplacement(
            fixture: fixture,
            owner: owner,
            shop: shop,
            initialWatermark: 900
        )
        let operationRecorder = ReplacementOperationRecorder()
        let recovery = ReplacementRecoveryProvider(
            mode: .successSequence(watermarks: [42, 55]),
            operationRecorder: operationRecorder
        )
        var gap = SyncIncrementalPullSummary(
            syncType: .eventIncremental,
            eventsFetched: 1,
            watermarkBefore: 42,
            watermarkAfter: 42
        )
        gap.requiresFullRecoveryReason = "sync_event_missing_entity_ids"
        let reconcile = SyncIncrementalPullSummary(
            syncType: .lightReconcile,
            watermarkBefore: 55,
            watermarkAfter: 55
        )
        let tail = ReplacementTailProvider(
            mode: .success([gap, reconcile]),
            bindingStore: fixture.bindingStore,
            watermarkStore: WatermarkStore(defaults: fixture.defaults),
            watermarkScope: watermarkScope,
            operationRecorder: operationRecorder
        )
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: tail,
            recoverySnapshotPullProvider: recovery,
            activityRegistrationProvider: nil,
            defaults: fixture.defaults,
            bindingStore: fixture.bindingStore,
            watermarkStore: WatermarkStore(defaults: fixture.defaults)
        )

        let result = await engine.run(
            action: .noOp,
            source: .networkReconnect,
            ownerUserID: owner
        )
        let recoveryCallCount = await recovery.callCount
        let tailCallCount = await tail.callCount
        let operations = await operationRecorder.operations()
        let observedWatermarks = await tail.observedWatermarks()
        let forcedReconcileFlags = await tail.forceLightReconcileFlags()

        XCTAssertEqual(result.status, .failed)
        XCTAssertFalse(result.didWork)
        XCTAssertEqual(recoveryCallCount, 0)
        XCTAssertEqual(tailCallCount, 0)
        XCTAssertEqual(operations, [])
        XCTAssertEqual(observedWatermarks, [])
        XCTAssertEqual(forcedReconcileFlags, [])
        XCTAssertTrue(fixture.bindingStore.hasPendingReplacementJournal)
        XCTAssertEqual(
            WatermarkStore(defaults: fixture.defaults).watermark(for: watermarkScope),
            900
        )
        XCTAssertNil(
            fixture.defaults.string(forKey: "sync.runtime.automatic.recovery.requestedReason")
        )
    }

    func testLegacyReplacementProviderCannotEnterRepeatedTailGapLoop() async {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        let watermarkScope = prepareExactPendingReplacement(
            fixture: fixture,
            owner: owner,
            shop: shop,
            initialWatermark: 900
        )
        let recovery = ReplacementRecoveryProvider(
            mode: .successSequence(watermarks: [42, 55, 70])
        )
        var firstGap = SyncIncrementalPullSummary(
            syncType: .eventIncremental,
            eventsFetched: 1,
            watermarkBefore: 42,
            watermarkAfter: 42
        )
        firstGap.requiresFullRecoveryReason = "sync_event_missing_entity_ids"
        var secondGap = SyncIncrementalPullSummary(
            syncType: .eventIncremental,
            eventsFetched: 1,
            watermarkBefore: 55,
            watermarkAfter: 55
        )
        secondGap.requiresFullRecoveryReason = "sync_event_missing_entity_ids"
        let tail = ReplacementTailProvider(
            mode: .success([firstGap, secondGap]),
            bindingStore: fixture.bindingStore,
            watermarkStore: WatermarkStore(defaults: fixture.defaults),
            watermarkScope: watermarkScope
        )
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: tail,
            recoverySnapshotPullProvider: recovery,
            activityRegistrationProvider: nil,
            defaults: fixture.defaults,
            bindingStore: fixture.bindingStore,
            watermarkStore: WatermarkStore(defaults: fixture.defaults)
        )

        let result = await engine.run(
            action: .noOp,
            source: .networkReconnect,
            ownerUserID: owner
        )
        let recoveryCallCount = await recovery.callCount
        let tailCallCount = await tail.callCount
        let observedWatermarks = await tail.observedWatermarks()

        XCTAssertEqual(result.status, .failed)
        XCTAssertNotEqual(result.status, .success)
        XCTAssertNotEqual(result.status, .noWork)
        XCTAssertEqual(recoveryCallCount, 0)
        XCTAssertEqual(tailCallCount, 0)
        XCTAssertEqual(observedWatermarks, [])
        XCTAssertTrue(fixture.bindingStore.hasPendingReplacementJournal)
        XCTAssertEqual(
            WatermarkStore(defaults: fixture.defaults).watermark(for: watermarkScope),
            900
        )
        XCTAssertNil(fixture.defaults.string(
            forKey: "sync.runtime.automatic.recovery.requestedReason"
        ))
        XCTAssertNotNil(fixture.defaults.string(forKey: "sync.runtime.automatic.lastError"))
    }

    func testLegacyReplacementProviderCannotEnterAlwaysAdvancingTailLoop() async {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        let watermarkScope = prepareExactPendingReplacement(
            fixture: fixture,
            owner: owner,
            shop: shop,
            initialWatermark: 900
        )
        let recovery = ReplacementRecoveryProvider(mode: .success(watermark: 42))
        let tail = ReplacementTailProvider(
            mode: .alwaysAdvancing,
            bindingStore: fixture.bindingStore,
            watermarkStore: WatermarkStore(defaults: fixture.defaults),
            watermarkScope: watermarkScope
        )
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: tail,
            recoverySnapshotPullProvider: recovery,
            activityRegistrationProvider: nil,
            defaults: fixture.defaults,
            bindingStore: fixture.bindingStore,
            watermarkStore: WatermarkStore(defaults: fixture.defaults)
        )

        let result = await engine.run(
            action: .noOp,
            source: .networkReconnect,
            ownerUserID: owner
        )
        let recoveryCallCount = await recovery.callCount
        let tailCallCount = await tail.callCount
        let observedWatermarks = await tail.observedWatermarks()
        let forcedReconcileFlags = await tail.forceLightReconcileFlags()

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(recoveryCallCount, 0)
        XCTAssertEqual(tailCallCount, 0)
        XCTAssertEqual(observedWatermarks, [])
        XCTAssertEqual(forcedReconcileFlags, [])
        XCTAssertTrue(fixture.bindingStore.hasPendingReplacementJournal)
        XCTAssertEqual(
            WatermarkStore(defaults: fixture.defaults).watermark(for: watermarkScope),
            900
        )
    }

    func testRecoveryCapturesWatermarkBeforeCatalogSnapshotSoConcurrentEventRemainsIncremental() async throws {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        _ = prepareExactPendingReplacement(
            fixture: fixture,
            owner: owner,
            shop: shop,
            initialWatermark: 0
        )
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: owner,
            defaults: fixture.defaults,
            allowsPendingReplacement: true
        )
        let boundaryEvent = try recoverySyncEventRow(
            id: 10,
            ownerUserID: owner,
            shopID: shop.shopID
        )
        let eventCreatedDuringCatalogFetch = try recoverySyncEventRow(
            id: 20,
            ownerUserID: owner,
            shopID: shop.shopID
        )
        let remote = AutomaticRecoveryW0RemoteFake(
            initialEvents: [boundaryEvent],
            eventInsertedDuringCatalogFetch: eventCreatedDuringCatalogFetch
        )
        let service = AutomaticRecoverySnapshotPullService(
            modelContainer: fixture.container,
            previewService: SupabasePullPreviewService(
                inventoryService: remote,
                pageSize: 2
            ),
            productPriceApplyService: SupabaseProductPriceApplyService(
                fetcher: remote,
                fetchOptions: ProductPriceApplyFetchOptions(
                    pageSize: 2,
                    maxRows: 2,
                    maxPages: 1,
                    fullPullSafetyLimit: 100
                )
            ),
            historyRemote: remote,
            syncEventFetcher: remote,
            defaults: fixture.defaults
        )

        let summary = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
            try await service.recoverFromRemoteSnapshot(ownerUserID: owner)
        }

        let operationLog = await remote.operations()
        let didInsertCatalogEvent = await remote.didInsertCatalogEvent()
        XCTAssertEqual(summary.watermarkAfter, 10)
        XCTAssertTrue(didInsertCatalogEvent)
        XCTAssertEqual(Array(operationLog.prefix(2)), ["events.after.0", "catalog.products"])

        let remainingEvents = try await remote.fetchSyncEventsAfter(
            ownerUserID: owner,
            afterID: summary.watermarkAfter,
            limit: SupabaseSyncEventIncrementalLimits.maximumLimit
        )
        XCTAssertEqual(remainingEvents.map(\.id), [20])
    }

    func testFailedAtomicReplacementRecoveryKeepsJournalAndActiveWatermarkForRetry() async {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        let watermarkScope = prepareExactPendingReplacement(
            fixture: fixture,
            owner: owner,
            shop: shop,
            initialWatermark: 900
        )
        let recovery = ReplacementRecoveryProvider(
            mode: .failure,
            publicationMode: .atomicGeneration
        )
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            recoverySnapshotPullProvider: recovery,
            activityRegistrationProvider: nil,
            defaults: fixture.defaults,
            bindingStore: fixture.bindingStore,
            watermarkStore: WatermarkStore(defaults: fixture.defaults)
        )

        let result = await engine.run(
            action: .noOp,
            source: .networkReconnect,
            ownerUserID: owner
        )
        let recoveryCallCount = await recovery.callCount

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(recoveryCallCount, 1)
        XCTAssertTrue(fixture.bindingStore.hasPendingReplacementJournal)
        XCTAssertEqual(
            WatermarkStore(defaults: fixture.defaults).watermark(for: watermarkScope),
            900
        )
    }

    func testLegacyReplacementSummaryCannotReachIncrementalTail() async {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        let watermarkScope = prepareExactPendingReplacement(
            fixture: fixture,
            owner: owner,
            shop: shop,
            initialWatermark: 900
        )
        let recovery = ReplacementRecoveryProvider(mode: .success(watermark: 42))
        let tail = ReplacementTailProvider(
            mode: .failure,
            bindingStore: fixture.bindingStore,
            watermarkStore: WatermarkStore(defaults: fixture.defaults),
            watermarkScope: watermarkScope
        )
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: tail,
            recoverySnapshotPullProvider: recovery,
            activityRegistrationProvider: nil,
            defaults: fixture.defaults,
            bindingStore: fixture.bindingStore,
            watermarkStore: WatermarkStore(defaults: fixture.defaults)
        )

        let result = await engine.run(
            action: .noOp,
            source: .networkReconnect,
            ownerUserID: owner
        )
        let tailCallCount = await tail.callCount
        let observedWatermarks = await tail.observedWatermarks()

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(tailCallCount, 0)
        XCTAssertEqual(observedWatermarks, [])
        XCTAssertTrue(fixture.bindingStore.hasPendingReplacementJournal)
        XCTAssertEqual(
            WatermarkStore(defaults: fixture.defaults).watermark(for: watermarkScope),
            900
        )
    }

    func testLegacyReplacementProviderFailsBeforeJournalOrCheckpointMutation() async {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        let watermarkScope = prepareExactPendingReplacement(
            fixture: fixture,
            owner: owner,
            shop: shop,
            initialWatermark: 900
        )
        let recovery = ReplacementRecoveryProvider(mode: .success(watermark: 42))
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            recoverySnapshotPullProvider: recovery,
            activityRegistrationProvider: nil,
            defaults: fixture.defaults,
            bindingStore: fixture.bindingStore,
            watermarkStore: WatermarkStore(defaults: fixture.defaults)
        )

        let result = await engine.run(
            action: .noOp,
            source: .networkReconnect,
            ownerUserID: owner
        )

        XCTAssertEqual(result.status, .failed)
        XCTAssertTrue(fixture.bindingStore.hasPendingReplacementJournal)
        XCTAssertEqual(
            WatermarkStore(defaults: fixture.defaults).watermark(for: watermarkScope),
            900
        )
    }

    func testCancelledAtomicReplacementRecoveryKeepsJournalAndActiveWatermarkForRetry() async {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        let watermarkScope = prepareExactPendingReplacement(
            fixture: fixture,
            owner: owner,
            shop: shop,
            initialWatermark: 900
        )
        let recovery = ReplacementRecoveryProvider(
            mode: .blockedSuccess(watermark: 42),
            publicationMode: .atomicGeneration
        )
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            recoverySnapshotPullProvider: recovery,
            activityRegistrationProvider: nil,
            defaults: fixture.defaults,
            bindingStore: fixture.bindingStore,
            watermarkStore: WatermarkStore(defaults: fixture.defaults)
        )
        let run = Task {
            await engine.run(
                action: .noOp,
                source: .networkReconnect,
                ownerUserID: owner
            )
        }
        await recovery.waitUntilStarted()

        await engine.cancel()
        await recovery.release()
        let result = await run.value

        XCTAssertEqual(result.status, .cancelled)
        XCTAssertTrue(fixture.bindingStore.hasPendingReplacementJournal)
        XCTAssertEqual(
            WatermarkStore(defaults: fixture.defaults).watermark(for: watermarkScope),
            900
        )
    }

    func testReplacementRecoveryScopeDriftFailsBeforeJournalCompletion() async {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        let watermarkScope = prepareExactPendingReplacement(
            fixture: fixture,
            owner: owner,
            shop: shop,
            initialWatermark: 900
        )
        let recovery = ReplacementRecoveryProvider(
            mode: .blockedSuccess(watermark: 42),
            publicationMode: .atomicGeneration
        )
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            recoverySnapshotPullProvider: recovery,
            activityRegistrationProvider: nil,
            defaults: fixture.defaults,
            bindingStore: fixture.bindingStore,
            watermarkStore: WatermarkStore(defaults: fixture.defaults)
        )
        let run = Task {
            await engine.run(
                action: .noOp,
                source: .networkReconnect,
                ownerUserID: owner
            )
        }
        await recovery.waitUntilStarted()

        XCTAssertTrue(fixture.selectedShopStore.save(
            selectedShop(id: UUID()),
            accountHash: AccountBindingStore.accountHash(for: owner)
        ))
        await recovery.release()
        let result = await run.value

        XCTAssertEqual(result.status, .failed)
        XCTAssertTrue(fixture.bindingStore.hasPendingReplacementJournal)
        XCTAssertEqual(
            WatermarkStore(defaults: fixture.defaults).watermark(for: watermarkScope),
            900
        )
    }

    func testConfirmedDiscardCannotMutatePersistentStoreBindingOrWatermarkBeforeActivation() async throws {
        let fixture = makeFixture(persistent: true)
        let oldOwner = UUID()
        let newOwner = UUID()
        let targetShop = selectedShop(id: UUID())
        let targetIdentity = targetShop.localStoreIdentity
        let targetWatermarkScope = WatermarkStore.Scope(
            ownerUserID: newOwner,
            storeIdentity: targetIdentity
        )
        let watermarkStore = WatermarkStore(defaults: fixture.defaults)
        watermarkStore.save(900, for: targetWatermarkScope)
        XCTAssertTrue(fixture.bindingStore.saveBinding(
            accountHash: AccountBindingStore.accountHash(for: newOwner),
            storeIdentity: targetIdentity
        ))
        XCTAssertTrue(fixture.selectedShopStore.save(
            targetShop,
            accountHash: AccountBindingStore.accountHash(for: newOwner)
        ))
        let context = ModelContext(fixture.container)
        let supplier = Supplier(name: "TASK139_ROLLBACK_SUPPLIER")
        let category = ProductCategory(name: "TASK139_ROLLBACK_CATEGORY")
        let product = Product(
            barcode: "TASK139_ROLLBACK_FIXTURE",
            supplier: supplier,
            category: category
        )
        let baselineRunID = UUID()
        context.insert(supplier)
        context.insert(category)
        context.insert(product)
        context.insert(ProductPrice(type: .retail, price: 12, product: product))
        context.insert(HistoryEntry(id: "TASK139_ROLLBACK_HISTORY"))
        context.insert(LocalPendingChange(
            ownerUserID: oldOwner,
            entityKind: .product,
            operation: .update,
            status: .pending,
            origin: .manualCatalogSave,
            logicalKey: "product:TASK139_ROLLBACK_FIXTURE"
        ))
        context.insert(SyncEventOutboxEntry(
            ownerUserID: oldOwner.uuidString.lowercased(),
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 1,
            entityIDsShape: "products:count=1",
            metadataShape: "source=rollback-fixture",
            nextRetryAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        ))
        context.insert(SupabaseCatalogBaselineRun(
            baselineRunID: baselineRunID,
            ownerUserUUID: oldOwner,
            status: .valid,
            appliedAt: Date()
        ))
        context.insert(SupabaseCatalogBaselineRecord(
            baselineRunID: baselineRunID,
            ownerUserUUID: oldOwner,
            entityType: .product,
            remoteID: UUID(),
            fingerprintCanonical: "v1|product|barcode=string:TASK139_ROLLBACK_FIXTURE"
        ))
        try context.save()

        let result = try AccountStoreReplacementCoordinator(
            context: context,
            bindingStore: fixture.bindingStore
        ).discardLocalDataAndBind(
            userID: newOwner,
            storeIdentity: targetIdentity
        )
        XCTAssertEqual(result.deletedProducts, 0)
        XCTAssertEqual(result.deletedOutboxEntries, 0)

        let reopenedContainer = try reopenPersistentContainer(
            at: try XCTUnwrap(fixture.storeURL)
        )
        let verificationContext = ModelContext(reopenedContainer)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<Product>()), 1)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<Supplier>()), 1)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<ProductCategory>()), 1)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<ProductPrice>()), 1)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<HistoryEntry>()), 1)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<LocalPendingChange>()), 1)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<SyncEventOutboxEntry>()), 1)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<SupabaseCatalogBaselineRun>()), 1)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<SupabaseCatalogBaselineRecord>()), 1)
        XCTAssertEqual(fixture.bindingStore.currentBinding?.accountHash, AccountBindingStore.accountHash(for: newOwner))
        XCTAssertEqual(fixture.bindingStore.currentBinding?.storeIdentity, targetIdentity)
        XCTAssertEqual(
            fixture.bindingStore.pendingReplacement?.accountHash,
            AccountBindingStore.accountHash(for: newOwner)
        )
        XCTAssertEqual(fixture.bindingStore.pendingReplacement?.storeIdentity, targetIdentity)
        XCTAssertEqual(fixture.bindingStore.pendingRecoveryJournal?.phase, .prepared)
        XCTAssertFalse(fixture.bindingStore.pendingReplacementWipeCommitted)
        XCTAssertEqual(watermarkStore.watermark(for: targetWatermarkScope), 900)

        let provider = SyncDecisionInputProvider(
            modelContainer: reopenedContainer,
            initialNetworkStatus: .satisfied,
            bindingStore: fixture.bindingStore,
            selectedShopStore: fixture.selectedShopStore
        )
        let snapshot = await provider.makeSnapshot(
            triggerSource: .rootForeground,
            isAuthenticated: true,
            ownerUserID: newOwner,
            isSyncBusy: false
        )
        XCTAssertEqual(snapshot.ownerStoreBindingResolution, .matched)
        XCTAssertEqual(SyncDecisionEngine.decide(snapshot.input), .bootstrap)
    }

    func testStoreReplacementWaitsForAutomaticRuntimeQuiescenceBeforeTransaction() async throws {
        let fixture = makeFixture()
        let runtime = BlockingReplacementRuntime()
        let orchestrator = SyncOrchestrator(
            automaticRuntime: runtime,
            authViewModel: SupabaseAuthViewModel(authService: nil),
            activityCenter: ForegroundCloudWorkflowActivityCenter(),
            syncEventSignalWatcher: nil,
            decisionInputProvider: SyncDecisionInputProvider(modelContainer: fixture.container)
        )
        var operationCalls = 0
        let replacement = Task { @MainActor in
            try await orchestrator.performAccountStoreReplacement {
                operationCalls += 1
                return AccountStoreReplacementResult(
                    deletedProducts: 0,
                    deletedSuppliers: 0,
                    deletedCategories: 0,
                    deletedProductPrices: 0,
                    deletedHistorySessions: 0,
                    deletedOutboxEntries: 0,
                    deletedBaselineRows: 0
                )
            }
        }

        for _ in 0..<50 where !runtime.cancelAndWaitStarted {
            await Task.yield()
        }
        XCTAssertTrue(runtime.cancelAndWaitStarted)
        XCTAssertEqual(operationCalls, 0)

        runtime.release()
        _ = try await replacement.value
        XCTAssertEqual(operationCalls, 1)
    }

    func testStoreReplacementBarrierWaitsForSecondContextSaveAndBlocksNewAdmission() async throws {
        let fixture = makeFixture()
        let flight = AutomaticSyncSingleFlight()
        let writerContext = ModelContext(fixture.container)
        let replacementContext = ModelContext(fixture.container)

        let initialAdmission = await flight.begin()
        XCTAssertTrue(initialAdmission)
        let barrier = Task {
            await flight.suspendForStoreReplacementAndWait()
        }
        var observedSuspension = false
        for _ in 0..<100 {
            if await flight.isSuspendedForStoreReplacement {
                observedSuspension = true
                break
            }
            await Task.yield()
        }
        XCTAssertTrue(observedSuspension)

        writerContext.insert(Product(barcode: "TASK139_SECOND_CONTEXT"))
        try writerContext.save()
        await flight.finish()
        await barrier.value

        let admissionDuringReplacement = await flight.begin()
        XCTAssertFalse(admissionDuringReplacement)
        XCTAssertEqual(try replacementContext.fetchCount(FetchDescriptor<Product>()), 1)
        try replacementContext.enumerate(
            FetchDescriptor<Product>(),
            allowEscapingMutations: true
        ) { replacementContext.delete($0) }
        try replacementContext.save()
        XCTAssertEqual(try replacementContext.fetchCount(FetchDescriptor<Product>()), 0)

        await flight.resumeAfterStoreReplacement()
        let admissionAfterReplacement = await flight.begin()
        XCTAssertTrue(admissionAfterReplacement)
        await flight.finish()
    }

    func testStoreReplacementCancelsAlreadyAdmittedBackgroundEngineThroughSharedPolicy() async {
        let flight = AutomaticSyncSingleFlight()
        let cancellationPolicy = AutomaticSyncCancellationPolicy()
        let provider = ReplacementBlockingCatalogProvider()
        let defaults = UserDefaults(suiteName: "TASK139.SharedCancellation.\(UUID().uuidString)")!
        let backgroundEngine = AutomaticSyncEngine(
            catalogPushProvider: provider,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            activityRegistrationProvider: nil,
            defaults: defaults,
            singleFlight: flight,
            cancellationPolicy: cancellationPolicy
        )
        let foregroundEngine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            activityRegistrationProvider: nil,
            defaults: defaults,
            singleFlight: flight,
            cancellationPolicy: cancellationPolicy
        )

        let run = Task {
            await backgroundEngine.run(
                action: .pushPending,
                source: .backgroundRefresh,
                ownerUserID: UUID()
            )
        }
        await provider.waitUntilStarted()

        let barrier = Task {
            await foregroundEngine.cancelAndWait()
        }
        var observedSuspension = false
        for _ in 0..<100 {
            if await flight.isSuspendedForStoreReplacement {
                observedSuspension = true
                break
            }
            await Task.yield()
        }
        XCTAssertTrue(observedSuspension)

        await provider.releaseRun()
        let result = await run.value
        await barrier.value

        XCTAssertEqual(result.status, .cancelled)
        let admissionDuringReplacement = await flight.begin()
        XCTAssertFalse(admissionDuringReplacement)
        await foregroundEngine.resumeAfterStoreReplacement()
        let admissionAfterReplacement = await flight.begin()
        XCTAssertTrue(admissionAfterReplacement)
        await flight.finish()
    }

    func testPreparedReplacementWithExactBindingResumesAtomicallyAndCannotBeRetargeted() async throws {
        let fixture = makeFixture()
        let owner = UUID()
        let targetShop = selectedShop(id: UUID())
        let accountHash = AccountBindingStore.accountHash(for: owner)
        fixture.selectedShopStore.noteActiveAccount(accountHash)
        XCTAssertTrue(fixture.selectedShopStore.save(targetShop, accountHash: accountHash))
        XCTAssertTrue(fixture.bindingStore.saveBinding(
            accountHash: accountHash,
            storeIdentity: targetShop.localStoreIdentity
        ))
        let context = ModelContext(fixture.container)
        context.insert(Product(barcode: "TASK139_PREPARED_JOURNAL"))
        try context.save()

        let coordinator = AccountStoreReplacementCoordinator(
            context: context,
            bindingStore: fixture.bindingStore
        )
        let intent = try coordinator.prepareReplacement(
            userID: owner,
            storeIdentity: targetShop.localStoreIdentity
        )
        XCTAssertEqual(intent.accountHash, accountHash)
        XCTAssertFalse(fixture.bindingStore.beginReplacement(
            accountHash: AccountBindingStore.accountHash(for: UUID()),
            storeIdentity: LocalStoreIdentity(rawValue: "other-shop")
        ))

        let provider = SyncDecisionInputProvider(
            modelContainer: fixture.container,
            initialNetworkStatus: .satisfied,
            bindingStore: fixture.bindingStore,
            selectedShopStore: fixture.selectedShopStore
        )
        let snapshot = await provider.makeSnapshot(
            triggerSource: .backgroundRefresh,
            isAuthenticated: true,
            ownerUserID: owner,
            isSyncBusy: false
        )

        XCTAssertEqual(snapshot.ownerStoreBindingResolution, .matched)
        XCTAssertTrue(snapshot.requiresBootstrap)
        XCTAssertEqual(SyncDecisionEngine.decide(snapshot.input), .bootstrap)
        XCTAssertEqual(fixture.bindingStore.currentBinding?.accountHash, accountHash)
        XCTAssertEqual(
            fixture.bindingStore.currentBinding?.storeIdentity,
            targetShop.localStoreIdentity
        )
        XCTAssertEqual(fixture.bindingStore.pendingReplacement?.storeIdentity, targetShop.localStoreIdentity)
        XCTAssertEqual(fixture.bindingStore.pendingRecoveryJournal?.phase, .prepared)
        XCTAssertFalse(fixture.bindingStore.pendingReplacementWipeCommitted)
        XCTAssertFalse(fixture.bindingStore.completePendingReplacementRecovery(
            accountHash: accountHash,
            storeIdentity: targetShop.localStoreIdentity
        ))
        XCTAssertNoThrow(try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: owner,
            defaults: fixture.defaults,
            allowsPendingReplacement: true
        ))
    }

    func testPreparedReplacementEmptyStoreNeverAutoBindsBeforeActivation() async throws {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        let accountHash = AccountBindingStore.accountHash(for: owner)
        XCTAssertTrue(fixture.selectedShopStore.save(shop, accountHash: accountHash))
        let context = ModelContext(fixture.container)
        let coordinator = AccountStoreReplacementCoordinator(
            context: context,
            bindingStore: fixture.bindingStore
        )
        let intent = try coordinator.prepareReplacement(
            userID: owner,
            storeIdentity: shop.localStoreIdentity
        )

        let reviewResolution = fixture.bindingStore.resolveOwnerStoreBinding(
            userID: owner,
            activeStoreIdentity: shop.localStoreIdentity,
            isLocalStoreCompletelyEmpty: true,
            allowAutoBind: false
        )
        XCTAssertEqual(reviewResolution, .matched)
        XCTAssertFalse(fixture.bindingStore.pendingReplacementWipeCommitted)
        XCTAssertNil(fixture.bindingStore.currentBinding)

        let provider = SyncDecisionInputProvider(
            modelContainer: fixture.container,
            initialNetworkStatus: .satisfied,
            bindingStore: fixture.bindingStore,
            selectedShopStore: fixture.selectedShopStore
        )
        let recovered = await provider.makeSnapshot(
            triggerSource: .backgroundRefresh,
            isAuthenticated: true,
            ownerUserID: owner,
            isSyncBusy: false
        )
        XCTAssertEqual(recovered.ownerStoreBindingResolution, .matched)
        XCTAssertTrue(recovered.requiresBootstrap)
        XCTAssertEqual(SyncDecisionEngine.decide(recovered.input), .bootstrap)
        XCTAssertEqual(fixture.bindingStore.pendingReplacement?.accountHash, accountHash)
        XCTAssertEqual(fixture.bindingStore.pendingReplacement?.storeIdentity, shop.localStoreIdentity)
        XCTAssertEqual(fixture.bindingStore.pendingRecoveryJournal?.phase, .prepared)
        XCTAssertFalse(fixture.bindingStore.pendingReplacementWipeCommitted)
        XCTAssertNil(fixture.bindingStore.currentBinding)

        let result = try coordinator.discardPreparedLocalDataAndBind(intent)

        XCTAssertEqual(result.deletedProducts, 0)
        XCTAssertEqual(result.deletedOutboxEntries, 0)
        XCTAssertNil(fixture.bindingStore.currentBinding)
        XCTAssertEqual(fixture.bindingStore.pendingRecoveryJournal?.phase, .prepared)
        XCTAssertFalse(fixture.bindingStore.pendingReplacementWipeCommitted)

        let committed = await provider.makeSnapshot(
            triggerSource: .backgroundRefresh,
            isAuthenticated: true,
            ownerUserID: owner,
            isSyncBusy: false
        )
        XCTAssertEqual(committed.ownerStoreBindingResolution, .matched)
        XCTAssertTrue(committed.requiresBootstrap)
        XCTAssertEqual(SyncDecisionEngine.decide(committed.input), .bootstrap)
    }

    func testPreparedJournalAllowsOnlySameTargetRecoveryWithoutAutoBinding() async throws {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        XCTAssertTrue(fixture.selectedShopStore.save(
            shop,
            accountHash: AccountBindingStore.accountHash(for: owner)
        ))
        let target = shop.localStoreIdentity
        XCTAssertTrue(fixture.bindingStore.beginReplacement(
            accountHash: AccountBindingStore.accountHash(for: owner),
            storeIdentity: target
        ))
        let provider = SyncDecisionInputProvider(
            modelContainer: fixture.container,
            initialNetworkStatus: .satisfied,
            bindingStore: fixture.bindingStore,
            selectedShopStore: fixture.selectedShopStore
        )

        let snapshot = await provider.makeSnapshot(
            triggerSource: .rootForeground,
            isAuthenticated: true,
            ownerUserID: owner,
            isSyncBusy: false
        )

        XCTAssertEqual(snapshot.ownerStoreBindingResolution, .matched)
        XCTAssertTrue(snapshot.requiresBootstrap)
        XCTAssertEqual(SyncDecisionEngine.decide(snapshot.input), .bootstrap)
        XCTAssertEqual(
            fixture.bindingStore.pendingReplacement?.accountHash,
            AccountBindingStore.accountHash(for: owner)
        )
        XCTAssertEqual(fixture.bindingStore.pendingReplacement?.storeIdentity, target)
        XCTAssertEqual(fixture.bindingStore.pendingRecoveryJournal?.phase, .prepared)
        XCTAssertFalse(fixture.bindingStore.pendingReplacementWipeCommitted)
        XCTAssertNil(fixture.bindingStore.currentBinding)
    }

    func testRegisteredActiveGenerationAllowsSameScopeWriteWhileShopDiscoveryIsUnresolved() throws {
        let fixture = makeFixture()
        let owner = UUID()
        let shop = selectedShop(id: UUID())
        let accountHash = AccountBindingStore.accountHash(for: owner)
        fixture.selectedShopStore.noteActiveAccount(accountHash)
        XCTAssertTrue(fixture.selectedShopStore.save(shop, accountHash: accountHash))
        XCTAssertTrue(fixture.bindingStore.saveBinding(
            accountHash: accountHash,
            storeIdentity: shop.localStoreIdentity
        ))
        fixture.selectedShopStore.markResolutionUnresolved(accountHash: accountHash)
        XCTAssertFalse(fixture.selectedShopStore.isResolutionReady(accountHash: accountHash))
        Task126OwnerStoreGate.registerActiveGenerationContainer(fixture.container)

        try Task126OwnerStoreGate.withLocalMutationFence(
            modelContainer: fixture.container,
            ownerUserID: owner,
            defaults: fixture.defaults
        ) { context in
            context.insert(Product(barcode: "TASK139_OFFLINE_SAME_SCOPE"))
            try context.save()
        }

        let verificationContext = ModelContext(fixture.container)
        XCTAssertEqual(try verificationContext.fetchCount(FetchDescriptor<Product>()), 1)
    }

    func testRegisteredActiveGenerationRejectsWrongOwnerAndPendingJournalBeforeMutation() throws {
        let fixture = makeFixture()
        let owner = UUID()
        let wrongOwner = UUID()
        let shop = selectedShop(id: UUID())
        let accountHash = AccountBindingStore.accountHash(for: owner)
        fixture.selectedShopStore.noteActiveAccount(accountHash)
        XCTAssertTrue(fixture.selectedShopStore.save(shop, accountHash: accountHash))
        XCTAssertTrue(fixture.bindingStore.saveBinding(
            accountHash: accountHash,
            storeIdentity: shop.localStoreIdentity
        ))
        Task126OwnerStoreGate.registerActiveGenerationContainer(fixture.container)
        var mutationCalls = 0

        XCTAssertThrowsError(try Task126OwnerStoreGate.withLocalMutationFence(
            modelContainer: fixture.container,
            ownerUserID: wrongOwner,
            defaults: fixture.defaults
        ) { _ in
            mutationCalls += 1
        }) { error in
            XCTAssertEqual(error as? Task126OwnerStoreGateError, .bindingMismatch)
        }
        XCTAssertEqual(mutationCalls, 0)

        let verifiedScope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: owner,
            defaults: fixture.defaults
        )
        XCTAssertTrue(fixture.bindingStore.beginSameScopeRecovery(
            accountHash: accountHash,
            storeIdentity: shop.localStoreIdentity,
            reason: "TASK139_TEST",
            deviceIdentityHash: verifiedScope.deviceIdentityHash
        ))
        XCTAssertThrowsError(try Task126OwnerStoreGate.withLocalMutationFence(
            modelContainer: fixture.container,
            ownerUserID: owner,
            defaults: fixture.defaults
        ) { _ in
            mutationCalls += 1
        }) { error in
            XCTAssertEqual(error as? Task126OwnerStoreGateError, .replacementInterrupted)
        }
        XCTAssertEqual(mutationCalls, 0)
        XCTAssertEqual(
            try ModelContext(fixture.container).fetchCount(FetchDescriptor<Product>()),
            0
        )
    }

    func testRetiredGenerationRejectsWriterThatQueuedBeforeActivation() async throws {
        let oldFixture = makeFixture()
        let newFixture = makeFixture()
        Task126OwnerStoreGate.registerActiveGenerationContainer(oldFixture.container)

        let activationEntered = expectation(description: "activation owns lease")
        let allowActivation = DispatchSemaphore(value: 0)
        let activation = Task.detached {
            Task126OwnerStoreGate.withAutomaticScopeLeaseInvalidated {
                activationEntered.fulfill()
                allowActivation.wait()
                Task126OwnerStoreGate.replaceActiveGenerationContainerWithLeaseHeld(
                    old: oldFixture.container,
                    new: newFixture.container
                )
            }
        }
        await fulfillment(of: [activationEntered], timeout: 2)

        let writerEntered = expectation(description: "queued old writer starts")
        let writer = Task.detached { () -> Error? in
            writerEntered.fulfill()
            do {
                try Task126OwnerStoreGate.withLocalMutationFence(
                    modelContainer: oldFixture.container,
                    ownerUserID: nil,
                    defaults: oldFixture.defaults
                ) { context in
                    context.insert(Product(barcode: "TASK139_RETIRED_WRITE"))
                    try context.save()
                }
                return nil
            } catch {
                return error
            }
        }
        await fulfillment(of: [writerEntered], timeout: 2)
        await Task.yield()
        allowActivation.signal()
        await activation.value

        let writerError = await writer.value
        XCTAssertEqual(writerError as? Task126OwnerStoreGateError, .retiredStoreGeneration)
        XCTAssertEqual(
            try ModelContext(oldFixture.container).fetchCount(FetchDescriptor<Product>()),
            0
        )
    }

    func testRequireLocalModelThrowsForDeletedAndForeignIdentifiersWithoutFaultTrap() throws {
        let fixture = makeFixture()
        let foreignFixture = makeFixture()
        let context = ModelContext(fixture.container)
        let deleted = Product(barcode: "TASK139_DELETED_ID")
        context.insert(deleted)
        try context.save()
        let deletedID = deleted.persistentModelID
        context.delete(deleted)
        try context.save()

        let readContext = ModelContext(fixture.container)
        XCTAssertThrowsError(try Task126OwnerStoreGate.requireLocalModel(
            Product.self,
            id: deletedID,
            in: readContext
        )) { error in
            XCTAssertEqual(error as? Task126OwnerStoreGateError, .localModelUnavailable)
        }

        let foreignContext = ModelContext(foreignFixture.container)
        let foreign = Product(barcode: "TASK139_FOREIGN_ID")
        foreignContext.insert(foreign)
        try foreignContext.save()
        XCTAssertThrowsError(try Task126OwnerStoreGate.requireLocalModel(
            Product.self,
            id: foreign.persistentModelID,
            in: readContext
        ))
    }

    private func makeFixture(persistent: Bool = false) -> Fixture {
        let suiteName = "AccountOwnerStoreSafetyTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let schema = modelSchema
        let storeURL: URL?
        let configuration: ModelConfiguration
        if persistent {
            let persistentStoreURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("TASK139-rollback-\(UUID().uuidString)")
                .appendingPathExtension("store")
            storeURL = persistentStoreURL
            configuration = ModelConfiguration(
                "TASK139RollbackFixture",
                schema: schema,
                url: persistentStoreURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
        } else {
            storeURL = nil
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        }
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return Fixture(
            container: container,
            defaults: defaults,
            bindingStore: AccountBindingStore(defaults: defaults),
            selectedShopStore: SelectedShopStore(defaults: defaults),
            storeURL: storeURL
        )
    }

    private func reopenPersistentContainer(at storeURL: URL) throws -> ModelContainer {
        let schema = modelSchema
        let configuration = ModelConfiguration(
            "TASK139RollbackFixture",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return container
    }

    private var modelSchema: Schema {
        Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            HistoryEntry.self,
            ProductPrice.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self,
            SyncEventOutboxEntry.self,
            LocalPendingChange.self
        ])
    }

    private func prepareExactPendingReplacement(
        fixture: Fixture,
        owner: UUID,
        shop: SelectedShop,
        initialWatermark: Int64
    ) -> WatermarkStore.Scope {
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let storeIdentity = shop.localStoreIdentity
        fixture.selectedShopStore.noteActiveAccount(accountHash)
        XCTAssertTrue(fixture.selectedShopStore.save(shop, accountHash: accountHash))
        XCTAssertTrue(fixture.bindingStore.beginReplacement(
            accountHash: accountHash,
            storeIdentity: storeIdentity
        ))
        XCTAssertEqual(fixture.bindingStore.pendingRecoveryJournal?.phase, .prepared)
        XCTAssertFalse(fixture.bindingStore.pendingReplacementWipeCommitted)
        XCTAssertNil(fixture.bindingStore.currentBinding)
        let scope = WatermarkStore.Scope(
            accountHash: accountHash,
            storeIdentity: storeIdentity
        )
        WatermarkStore(defaults: fixture.defaults).save(initialWatermark, for: scope)
        return scope
    }

    private func selectedShop(id: UUID) -> SelectedShop {
        SelectedShop(
            shopID: id,
            code: nil,
            name: "Fixture shop",
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true
        )
    }

    private func recoverySyncEventRow(
        id: Int64,
        ownerUserID: UUID,
        shopID: UUID
    ) throws -> RemoteSyncEventRow {
        let json = """
        {
          "id": "\(id)",
          "owner_user_id": "\(ownerUserID.uuidString)",
          "shop_id": "\(shopID.uuidString)",
          "store_id": null,
          "domain": "catalog",
          "event_type": "catalog_changed",
          "source": "TASK139_TEST",
          "source_device_id": "TASK139_W0_FIXTURE",
          "batch_id": null,
          "client_event_id": "TASK139-W0-\(id)",
          "changed_count": 1,
          "entity_ids": {"products": []},
          "created_at": "2026-07-21T00:00:00Z",
          "expires_at": null,
          "metadata": {}
        }
        """
        return try JSONDecoder().decode(
            RemoteSyncEventRow.self,
            from: Data(json.utf8)
        )
    }

    private func ownerReviewDecision(_ reason: OwnerStoreBindingReviewReason) -> AccountSyncDecision {
        AccountSyncDecision(
            action: .promptOwnerStoreReview(reason),
            defaultSafeAction: .cancel,
            remoteMutation: .blockedUntilUserDecision,
            pendingHandling: .keepPendingWithOriginalOwner,
            conflictPolicy: .noCrossAccountMerge,
            rollback: .cancelLeavesRemoteUntouched,
            testID: "OWNER-STORE-\(reason.rawValue)"
        )
    }

    private struct Fixture {
        let container: ModelContainer
        let defaults: UserDefaults
        let bindingStore: AccountBindingStore
        let selectedShopStore: SelectedShopStore
        let storeURL: URL?
    }
}

private final class ReplacementBlockingCatalogProvider: SyncCatalogPushProviding {
    private let started = ReplacementAsyncGate()
    private let release = ReplacementAsyncGate()

    func pushPendingCatalog(ownerUserID: UUID) async throws -> SyncCatalogPushResult {
        await started.open()
        await release.wait()
        var result = SyncCatalogPushResult()
        result.productCreates = 1
        return result
    }

    func waitUntilStarted() async {
        await started.wait()
    }

    func releaseRun() async {
        await release.open()
    }
}

private actor AutomaticRecoveryW0RemoteFake:
    SupabaseInventoryFetching,
    SupabaseProductPricePreviewFetching,
    HistorySessionRemoteSyncing,
    SupabaseSyncEventIncrementalFetching {
    private var events: [RemoteSyncEventRow]
    private let eventInsertedDuringCatalogFetch: RemoteSyncEventRow
    private var insertedCatalogEvent = false
    private var operationLog: [String] = []

    init(
        initialEvents: [RemoteSyncEventRow],
        eventInsertedDuringCatalogFetch: RemoteSyncEventRow
    ) {
        self.events = initialEvents
        self.eventInsertedDuringCatalogFetch = eventInsertedDuringCatalogFetch
    }

    func fetchSyncEventsAfter(
        ownerUserID: UUID,
        afterID: Int64,
        limit: Int
    ) async throws -> [RemoteSyncEventRow] {
        operationLog.append("events.after.\(afterID)")
        return Array(
            events
                .filter { $0.ownerUserID == ownerUserID && $0.id > afterID }
                .sorted { $0.id < $1.id }
                .prefix(max(0, limit))
        )
    }

    func fetchProductsPage(from: Int, to: Int) async throws -> [RemoteInventoryProductRow] {
        operationLog.append("catalog.products")
        if !insertedCatalogEvent {
            events.append(eventInsertedDuringCatalogFetch)
            insertedCatalogEvent = true
        }
        return []
    }

    func fetchSuppliersPage(from: Int, to: Int) async throws -> [RemoteInventorySupplierRow] {
        []
    }

    func fetchCategoriesPage(from: Int, to: Int) async throws -> [RemoteInventoryCategoryRow] {
        []
    }

    func fetchProductPricesPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        []
    }

    func fetchProductPricesPreviewPage(
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow] {
        []
    }

    func fetchProductPriceCount() async throws -> Int? {
        0
    }

    func upsertSharedSheetSessions(
        _ rows: [SharedSheetSessionUpsertRow],
        ownerUserID: UUID
    ) async throws -> [RemoteSharedSheetSessionRow] {
        []
    }

    func fetchSharedSheetSessionsPage(
        ownerUserID: UUID,
        from: Int,
        to: Int
    ) async throws -> [RemoteSharedSheetSessionRow] {
        []
    }

    func operations() -> [String] {
        operationLog
    }

    func didInsertCatalogEvent() -> Bool {
        insertedCatalogEvent
    }
}

private actor ReplacementAsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        let continuations = waiters
        waiters.removeAll()
        continuations.forEach { $0.resume() }
    }
}

@MainActor
private final class BlockingReplacementRuntime: SyncAutomaticRuntimeProviding {
    private(set) var isRunning = true
    private(set) var cancelAndWaitStarted = false
    private var continuation: CheckedContinuation<Void, Never>?

    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> SyncAutomaticRunResult {
        .noWork()
    }

    func cancel() {}

    func cancelAndWait() async {
        cancelAndWaitStarted = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        isRunning = false
    }

    func resumeAfterStoreReplacement() async {}

    func release() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class RecordingReplacementRuntime: SyncAutomaticRuntimeProviding {
    private(set) var actions: [SyncAction] = []
    private(set) var cancelAndWaitCount = 0
    private(set) var resumeAfterReplacementCount = 0

    var isRunning: Bool { false }

    func run(action: SyncAction, source: SyncAutomaticTriggerSource) async -> SyncAutomaticRunResult {
        actions.append(action)
        return .success(didWork: true)
    }

    func cancel() {}

    func cancelAndWait() async {
        cancelAndWaitCount += 1
    }

    func resumeAfterStoreReplacement() async {
        resumeAfterReplacementCount += 1
    }
}

private actor BootstrapDecisionInputProvider: SyncDecisionInputProviding {
    let ownerUserID: UUID

    init(ownerUserID: UUID) {
        self.ownerUserID = ownerUserID
    }

    func updateNetworkStatus(_ status: AutomaticSyncNetworkStatus) async {}

    func recordRealtimeEvent() async {}

    func makeSnapshot(
        triggerSource: SyncAutomaticTriggerSource,
        isAuthenticated: Bool,
        ownerUserID: UUID?,
        isSyncBusy: Bool
    ) async -> SyncDecisionInputSnapshot {
        SyncDecisionInputSnapshot(
            triggerSource: triggerSource,
            isAuthenticated: true,
            ownerUserID: self.ownerUserID,
            ownerStoreBindingResolution: .matched,
            accountBindingMatches: true,
            networkStatus: .satisfied,
            pendingLocalChanges: .empty,
            pendingOutboxCount: 0,
            requiresBootstrap: true,
            requiresFullRecovery: false,
            hasRecoveryDrift: false,
            hasRealtimeEvent: false,
            isSyncBusy: false,
            hasStateReadFailure: false,
            requestsLightReconcile: false
        )
    }
}

private actor ReplacementRecoveryProvider: SyncRecoverySnapshotPullProviding {
    enum Mode: Sendable {
        case success(watermark: Int64)
        case successSequence(watermarks: [Int64])
        case failure
        case blockedSuccess(watermark: Int64)
    }

    private let mode: Mode
    nonisolated let publicationMode: SyncRecoverySnapshotPublicationMode
    private let operationRecorder: ReplacementOperationRecorder?
    private let started = ReplacementAsyncGate()
    private let releaseGate = ReplacementAsyncGate()
    private(set) var callCount = 0

    init(
        mode: Mode,
        publicationMode: SyncRecoverySnapshotPublicationMode = .activeStoreLegacy,
        operationRecorder: ReplacementOperationRecorder? = nil
    ) {
        self.mode = mode
        self.publicationMode = publicationMode
        self.operationRecorder = operationRecorder
    }

    func recoverFromRemoteSnapshot(ownerUserID: UUID) async throws -> SyncRecoverySnapshotPullSummary {
        callCount += 1
        await started.open()
        switch mode {
        case .success(let watermark):
            await operationRecorder?.record("snapshot.w0.\(watermark)")
            return summary(watermark: watermark)
        case .successSequence(let watermarks):
            guard watermarks.indices.contains(callCount - 1) else {
                throw ReplacementRecoveryFixtureError.failed
            }
            let watermark = watermarks[callCount - 1]
            await operationRecorder?.record("snapshot.w0.\(watermark)")
            return summary(watermark: watermark)
        case .failure:
            throw ReplacementRecoveryFixtureError.failed
        case .blockedSuccess(let watermark):
            await releaseGate.wait()
            await operationRecorder?.record("snapshot.w0.\(watermark)")
            return summary(watermark: watermark)
        }
    }

    func waitUntilStarted() async {
        await started.wait()
    }

    func release() async {
        await releaseGate.open()
    }

    private func summary(watermark: Int64) -> SyncRecoverySnapshotPullSummary {
        SyncRecoverySnapshotPullSummary(
            catalog: SupabasePullApplyResult(
                inserted: 1,
                updated: 0,
                suppliersCreated: 0,
                categoriesCreated: 0
            ),
            history: HistorySessionPullResult(),
            productPrices: ProductPriceApplyResult(
                inserted: 0,
                skippedExisting: 0,
                totalConsidered: 0
            ),
            watermarkAfter: watermark
        )
    }
}

private actor ReplacementOperationRecorder {
    private var values: [String] = []

    func record(_ value: String) {
        values.append(value)
    }

    func operations() -> [String] {
        values
    }
}

private actor ReplacementTailProvider: SyncIncrementalPullProviding {
    enum Mode: Sendable {
        case success([SyncIncrementalPullSummary])
        case alwaysAdvancing
        case failure
    }

    private let mode: Mode
    private let bindingStore: AccountBindingStore
    private let watermarkStore: WatermarkStore
    private let watermarkScope: WatermarkStore.Scope
    private let operationRecorder: ReplacementOperationRecorder?
    private var nextSummaryIndex = 0
    private var forcedFlags: [Bool] = []
    private var journalVisibility: [Bool] = []
    private var watermarks: [Int64] = []
    private(set) var callCount = 0

    init(
        mode: Mode,
        bindingStore: AccountBindingStore,
        watermarkStore: WatermarkStore,
        watermarkScope: WatermarkStore.Scope,
        operationRecorder: ReplacementOperationRecorder? = nil
    ) {
        self.mode = mode
        self.bindingStore = bindingStore
        self.watermarkStore = watermarkStore
        self.watermarkScope = watermarkScope
        self.operationRecorder = operationRecorder
    }

    func applyIncrementalRemoteChanges(
        ownerUserID: UUID
    ) async throws -> SyncIncrementalPullSummary {
        try await applyIncrementalRemoteChanges(
            ownerUserID: ownerUserID,
            forceLightReconcile: false
        )
    }

    func applyIncrementalRemoteChanges(
        ownerUserID: UUID,
        forceLightReconcile: Bool
    ) async throws -> SyncIncrementalPullSummary {
        callCount += 1
        forcedFlags.append(forceLightReconcile)
        journalVisibility.append(bindingStore.hasPendingReplacementJournal)
        let observedWatermark = watermarkStore.watermark(for: watermarkScope)
        watermarks.append(observedWatermark)

        switch mode {
        case .failure:
            throw ReplacementRecoveryFixtureError.failed
        case .alwaysAdvancing:
            var summary = SyncIncrementalPullSummary(
                syncType: .eventIncremental,
                eventsFetched: 1,
                watermarkBefore: observedWatermark,
                watermarkAfter: observedWatermark + 1
            )
            summary.eventsProcessed = 1
            await operationRecorder?.record("tail.after.\(observedWatermark)")
            watermarkStore.save(summary.watermarkAfter, for: watermarkScope)
            return summary
        case .success(let summaries):
            guard nextSummaryIndex < summaries.count else {
                throw ReplacementRecoveryFixtureError.failed
            }
            let summary = summaries[nextSummaryIndex]
            nextSummaryIndex += 1
            if summary.eventsFetched > 0 {
                await operationRecorder?.record("tail.after.\(observedWatermark)")
                watermarkStore.save(summary.watermarkAfter, for: watermarkScope)
            } else {
                await operationRecorder?.record("reconcile.after.\(observedWatermark)")
            }
            return summary
        }
    }

    func forceLightReconcileFlags() -> [Bool] {
        forcedFlags
    }

    func journalVisibilityDuringCalls() -> [Bool] {
        journalVisibility
    }

    func observedWatermarks() -> [Int64] {
        watermarks
    }
}

private enum ReplacementRecoveryFixtureError: Error {
    case failed
}

private actor BusinessOutboundRecorder:
    SyncCatalogPushProviding,
    SyncProductPriceSyncProviding,
    SyncHistorySessionPushProviding,
    SyncIncrementalPullProviding,
    SyncActivityRegistrationProviding {
    private var calls = 0

    func totalCalls() -> Int { calls }

    func pushPendingCatalog(ownerUserID: UUID) async throws -> SyncCatalogPushResult {
        calls += 1
        return SyncCatalogPushResult()
    }

    func pushPendingProductPrices(ownerUserID: UUID) async throws -> SyncProductPricePushResult {
        calls += 1
        return SyncProductPricePushResult()
    }

    func syncHistorySessions(
        ownerUserID: UUID,
        mode: SyncHistorySessionMode
    ) async throws -> SyncHistorySessionSummary {
        calls += 1
        return SyncHistorySessionSummary()
    }

    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SyncIncrementalPullSummary {
        calls += 1
        return .noWork(watermark: 0)
    }

    func loadSyncActivityRegistrationSnapshot(
        ownerUserID: UUID
    ) async throws -> SyncActivityRegistrationSnapshot {
        calls += 1
        return SyncActivityRegistrationSnapshot(readyToRegister: 0, waiting: 0, notRegisterable: 0)
    }

    func registerSyncActivities(ownerUserID: UUID) async throws -> SyncActivityRegistrationResult {
        calls += 1
        return SyncActivityRegistrationResult(
            status: .empty,
            summary: SyncActivityRegistrationSummary(registered: 0, waiting: 0, notRegisterable: 0)
        )
    }
}
