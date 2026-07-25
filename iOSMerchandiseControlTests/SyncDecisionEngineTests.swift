import XCTest
import SwiftData
@testable import iOSMerchandiseControl

final class SyncDecisionEngineTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testLocalMutationWithPendingChoosesPushWithoutFullPull() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .localMutation,
                isAuthenticated: true,
                isNetworkAvailable: true,
                hasPendingLocalChanges: true
            )
        )

        XCTAssertEqual(action, .sequence([.pushPending, .drainEvents]))
        XCTAssertFalse(action.containsFullRecovery)
    }

    func testRemoteSyncEventChoosesIncrementalDrain() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .remoteSyncEvent,
                isAuthenticated: true,
                isNetworkAvailable: true,
                hasRemoteSyncEvent: true
            )
        )

        XCTAssertEqual(action, .drainEvents)
        XCTAssertFalse(action.containsFullRecovery)
    }

    func testRemoteEventWithPendingDrainsBeforeAnyPush() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .networkAvailable,
                isAuthenticated: true,
                isNetworkAvailable: true,
                hasPendingLocalChanges: true,
                hasRemoteSyncEvent: true
            )
        )

        XCTAssertEqual(action, .sequence([.drainEvents, .pushPending, .drainEvents]))
    }

    func testRemoteVerificationDriftBlocksPendingPush() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .networkAvailable,
                isAuthenticated: true,
                isNetworkAvailable: true,
                hasPendingLocalChanges: true,
                hasRemoteVerificationDrift: true
            )
        )

        XCTAssertEqual(action, .sequence([.lightReconcile, .pushPending, .drainEvents]))
    }

    func testPendingWithRequestedLightReconcileDoesNotPushBeforeReconcile() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .networkAvailable,
                isAuthenticated: true,
                isNetworkAvailable: true,
                hasPendingLocalChanges: true,
                requestsLightReconcile: true
            )
        )

        XCTAssertEqual(action, .sequence([.lightReconcile, .pushPending, .drainEvents]))
    }

    func testTask132DRequestedLightReconcileWithoutPendingDoesNotNoOp() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .appForeground,
                isAuthenticated: true,
                isNetworkAvailable: true,
                requestsLightReconcile: true
            )
        )

        XCTAssertEqual(action, .lightReconcile)
    }

    func testForegroundPollDoesNotForceRemoteDrainOrLightReconcile() {
        let source = SyncAutomaticTriggerSource.foregroundPoll
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: source.syncTrigger,
                isAuthenticated: true,
                isNetworkAvailable: true,
                requestsLightReconcile: source.requestsLightReconcile
            )
        )

        XCTAssertEqual(source.syncTrigger, .appForeground)
        XCTAssertFalse(source.requestsLightReconcile)
        XCTAssertEqual(action, .noOp)
    }

    func testTask132DBaselineAbsentWithPendingBootstrapsBeforePush() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .networkAvailable,
                isAuthenticated: true,
                isNetworkAvailable: true,
                hasPendingLocalChanges: true,
                requiresBootstrap: true
            )
        )

        XCTAssertEqual(action, .bootstrap)
    }

    func testAccountDecisionBlocksBeforePushOrDrain() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .authChanged,
                isAuthenticated: true,
                isNetworkAvailable: true,
                requiresAccountDecision: true,
                hasPendingLocalChanges: true,
                hasRemoteSyncEvent: true
            )
        )

        XCTAssertEqual(action, .blocked(.accountDecisionRequired))
    }

    func testSyncBusySchedulesRetry() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .remoteSyncEvent,
                isAuthenticated: true,
                isNetworkAvailable: true,
                hasRemoteSyncEvent: true,
                isSyncBusy: true
            )
        )

        XCTAssertEqual(action, .retryAfterBusy)
    }

    func testForegroundRecoveryRequestDoesNotStartFullRecoveryDirectly() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .appForeground,
                isAuthenticated: true,
                isNetworkAvailable: true,
                requiresFullRecovery: true,
                fullRecoveryContext: .normalForeground
            )
        )

        XCTAssertEqual(action, .requestRecovery)
        XCTAssertFalse(action.containsFullRecovery)
    }

    func testManualRecoveryContextCanChooseFullRecovery() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .manualRefresh,
                isAuthenticated: true,
                isNetworkAvailable: true,
                requiresFullRecovery: true,
                fullRecoveryContext: .manual
            )
        )

        XCTAssertEqual(action, .fullRecovery)
    }

    @MainActor
    func testSameAccountDirtyStoreUsesLightReconcileWhenBaselineIsAbsent() async throws {
        let defaults = UserDefaults(suiteName: "SyncDecisionEngineTests.\(UUID().uuidString)")!
        let bindingStore = AccountBindingStore(defaults: defaults, key: "binding")
        let ownerUserID = UUID()
        let selectedShopStore = SelectedShopStore(defaults: defaults)
        let selectedShop = makeSelectedShop()
        XCTAssertTrue(selectedShopStore.save(
            selectedShop,
            accountHash: AccountBindingStore.accountHash(for: ownerUserID)
        ))
        bindingStore.saveBinding(
            accountHash: AccountBindingStore.accountHash(for: ownerUserID),
            storeIdentity: selectedShop.localStoreIdentity
        )
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Product(barcode: "TASK132_BASELINE_ABSENT", productName: "Task 132"))
        try context.save()

        let provider = SyncDecisionInputProvider(
            modelContainer: container,
            initialNetworkStatus: .satisfied,
            bindingStore: bindingStore,
            selectedShopStore: selectedShopStore
        )
        let snapshot = await provider.makeSnapshot(
            triggerSource: .rootForeground,
            isAuthenticated: true,
            ownerUserID: ownerUserID,
            isSyncBusy: false
        )

        XCTAssertTrue(snapshot.accountBindingMatches)
        XCTAssertFalse(snapshot.requiresBootstrap)
        XCTAssertEqual(SyncDecisionEngine.decide(snapshot.input), .lightReconcile)
    }

    @MainActor
    func testUnboundDirtyLocalDataBlocksBootstrapWhenBaselineIsAbsent() async throws {
        let defaults = UserDefaults(suiteName: "SyncDecisionEngineTests.\(UUID().uuidString)")!
        let ownerUserID = UUID()
        let selectedShopStore = SelectedShopStore(defaults: defaults)
        XCTAssertTrue(selectedShopStore.save(
            makeSelectedShop(),
            accountHash: AccountBindingStore.accountHash(for: ownerUserID)
        ))
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Product(barcode: "TASK132_ANON_BASELINE_ABSENT", productName: "Task 132"))
        try context.save()

        let provider = SyncDecisionInputProvider(
            modelContainer: container,
            initialNetworkStatus: .satisfied,
            bindingStore: AccountBindingStore(defaults: defaults, key: "binding"),
            selectedShopStore: selectedShopStore
        )
        let snapshot = await provider.makeSnapshot(
            triggerSource: .rootForeground,
            isAuthenticated: true,
            ownerUserID: ownerUserID,
            isSyncBusy: false
        )

        XCTAssertEqual(snapshot.ownerStoreBindingResolution, .reviewRequired(.unboundDirty))
        XCTAssertFalse(snapshot.requiresBootstrap)
        XCTAssertEqual(SyncDecisionEngine.decide(snapshot.input), .blocked(.accountDecisionRequired))
    }

    @MainActor
    func testTask132DEmptyCatalogStillRequiresBootstrapWhenBaselineIsAbsent() async throws {
        let defaults = UserDefaults(suiteName: "SyncDecisionEngineTests.\(UUID().uuidString)")!
        let ownerUserID = UUID()
        let selectedShopStore = SelectedShopStore(defaults: defaults)
        XCTAssertTrue(selectedShopStore.save(
            makeSelectedShop(),
            accountHash: AccountBindingStore.accountHash(for: ownerUserID)
        ))
        let provider = SyncDecisionInputProvider(
            modelContainer: try makeContainer(),
            initialNetworkStatus: .satisfied,
            bindingStore: AccountBindingStore(defaults: defaults, key: "binding"),
            selectedShopStore: selectedShopStore
        )
        let snapshot = await provider.makeSnapshot(
            triggerSource: .rootForeground,
            isAuthenticated: true,
            ownerUserID: ownerUserID,
            isSyncBusy: false
        )

        XCTAssertEqual(snapshot.ownerStoreBindingResolution, .autoBound)
        XCTAssertTrue(snapshot.requiresBootstrap)
        XCTAssertEqual(SyncDecisionEngine.decide(snapshot.input), .bootstrap)
    }

    func testZeroOfZeroProgressIsHiddenAtStateLevel() {
        let state = SyncState(
            phase: .pushing,
            progress: SyncProgress(current: 0, total: 0)
        )

        XCTAssertFalse(state.isProgressVisible)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return container
    }

    private func makeSelectedShop() -> SelectedShop {
        SelectedShop(
            shopID: UUID(),
            code: "TASK139",
            name: "Task 139 Shop",
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true
        )
    }
}
