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

        XCTAssertEqual(action, .pushPending)
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

    func testSameAccountReconnectPushesPendingThenDrainsAndLightReconciles() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .networkAvailable,
                isAuthenticated: true,
                isNetworkAvailable: true,
                hasPendingLocalChanges: true,
                hasRemoteSyncEvent: true,
                hasRemoteVerificationDrift: true
            )
        )

        XCTAssertEqual(action, .sequence([.pushPending, .drainEvents, .lightReconcile]))
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
    func testSameAccountBindingDoesNotForceBootstrapWhenBaselineIsAbsent() async throws {
        let originalBinding = UserDefaults.standard.data(forKey: "sync.accountBinding.v1")
        defer {
            if let originalBinding {
                UserDefaults.standard.set(originalBinding, forKey: "sync.accountBinding.v1")
            } else {
                UserDefaults.standard.removeObject(forKey: "sync.accountBinding.v1")
            }
        }

        let ownerUserID = UUID()
        AccountBindingStore().saveBinding(
            accountHash: AccountBindingStore.accountHash(for: ownerUserID),
            storeIdentity: .anonymous
        )
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Product(barcode: "TASK123_BASELINE_ABSENT", productName: "Task 123"))
        try context.save()

        let provider = SyncDecisionInputProvider(
            modelContainer: container,
            initialNetworkStatus: .satisfied
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
    func testAnonymousLocalDataStillRequiresBootstrapWhenBaselineIsAbsent() async throws {
        let originalBinding = UserDefaults.standard.data(forKey: "sync.accountBinding.v1")
        UserDefaults.standard.removeObject(forKey: "sync.accountBinding.v1")
        defer {
            if let originalBinding {
                UserDefaults.standard.set(originalBinding, forKey: "sync.accountBinding.v1")
            } else {
                UserDefaults.standard.removeObject(forKey: "sync.accountBinding.v1")
            }
        }

        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Product(barcode: "TASK123_ANON_BASELINE_ABSENT", productName: "Task 123"))
        try context.save()

        let provider = SyncDecisionInputProvider(
            modelContainer: container,
            initialNetworkStatus: .satisfied
        )
        let snapshot = await provider.makeSnapshot(
            triggerSource: .rootForeground,
            isAuthenticated: true,
            ownerUserID: UUID(),
            isSyncBusy: false
        )

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
}
