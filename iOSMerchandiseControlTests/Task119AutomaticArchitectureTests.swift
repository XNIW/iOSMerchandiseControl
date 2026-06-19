import XCTest
@testable import iOSMerchandiseControl

final class Task119AutomaticArchitectureTests: XCTestCase {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ relativePath: String) throws -> String {
        let url = repositoryRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    func testAutomaticCoreSourcesDoNotReferenceManualBoundaryTypes() throws {
        let files = [
            "iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRuntimeFacade.swift",
            "iOSMerchandiseControl/Sync/Automatic/Composition/AutomaticSyncRuntimeFactory.swift",
            "iOSMerchandiseControl/Sync/SyncOrchestrator.swift",
            "iOSMerchandiseControl/Sync/Automatic/Core/SyncAutomaticRunResult.swift",
            "iOSMerchandiseControl/Sync/Automatic/Decision/SyncDecisionEngine.swift",
            "iOSMerchandiseControl/Sync/Automatic/Decision/SyncDecisionInputProvider.swift",
            "iOSMerchandiseControl/Sync/Automatic/Decision/SyncTrigger.swift",
            "iOSMerchandiseControl/Sync/Automatic/Catalog/SyncCatalogPushModels.swift",
            "iOSMerchandiseControl/Sync/Automatic/ProductPrice/SyncProductPricePushModels.swift",
            "iOSMerchandiseControl/Sync/Automatic/History/SyncHistorySessionPushModels.swift",
            "iOSMerchandiseControl/Sync/Automatic/Outbox/SyncActivityRegistrationModels.swift",
            "iOSMerchandiseControl/Sync/Automatic/Pull/SyncEventIncrementalContracts.swift",
        ]
        let forbiddenPatterns = [
            "SupabaseManual",
            "ManualPush",
            "CompatibilityAdapter",
            "ManualSyncReleaseFactory",
        ]

        for file in files {
            let content = try source(file)
            for pattern in forbiddenPatterns {
                XCTAssertFalse(
                    content.contains(pattern),
                    "\(file) must not reference manual-only boundary symbol \(pattern)"
                )
            }
        }
    }

    func testOptionsAndRootDoNotHardcodeIdleSyncState() throws {
        let files = [
            "iOSMerchandiseControl/ContentView.swift",
            "iOSMerchandiseControl/OptionsView.swift",
        ]

        for file in files {
            let content = try source(file)
            XCTAssertFalse(
                content.contains("CloudSyncProgressState.idle()"),
                "\(file) should observe real SyncStateStore state instead of hardcoding idle progress"
            )
        }
    }

    func testTask119UsesDedicatedScannerOwnershipFiles() throws {
        let sharedScanner = repositoryRoot.appendingPathComponent("tools/agent/lib/sync_architecture_scans.py")
        let taskScanner = repositoryRoot.appendingPathComponent("tools/agent/lib/task119_scans.py")

        XCTAssertTrue(FileManager.default.fileExists(atPath: sharedScanner.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: taskScanner.path))
    }

    func testAutomaticRuntimeUsesDedicatedEngineSingleFlightAndCancellationPolicy() throws {
        let engineURL = repositoryRoot.appendingPathComponent("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift")
        let singleFlightURL = repositoryRoot.appendingPathComponent("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncSingleFlight.swift")
        let cancellationURL = repositoryRoot.appendingPathComponent("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncCancellationPolicy.swift")

        XCTAssertTrue(FileManager.default.fileExists(atPath: engineURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: singleFlightURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: cancellationURL.path))

        let engine = try String(contentsOf: engineURL, encoding: .utf8)
        let runtime = try source("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRuntimeFacade.swift")

        XCTAssertFalse(engine.contains("@MainActor"), "AutomaticSyncEngine must keep non-UI work off MainActor")
        XCTAssertFalse(runtime.contains("activeTask"), "SyncAutomaticRuntime facade must not own placeholder single-flight state")
        XCTAssertTrue(engine.contains("AutomaticSyncSingleFlight"))
        XCTAssertTrue(engine.contains("AutomaticSyncCancellationPolicy"))
    }

    func testTask072DeviceAuthorizationGateCoversAutomaticManualAndBackgroundSync() throws {
        let registration = try source("iOSMerchandiseControl/ShopDeviceRegistrationService.swift")
        let runtime = try source("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRuntimeFacade.swift")
        let factory = try source("iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncReleaseFactory.swift")
        let background = try source("iOSMerchandiseControl/Sync/Automatic/Background/SyncBackgroundTaskScheduler.swift")
        let orchestrator = try source("iOSMerchandiseControl/Sync/SyncOrchestrator.swift")

        XCTAssertTrue(registration.contains("shop_device_status_current_owner"))
        XCTAssertTrue(registration.contains("ensureActiveForCloudWrite"))
        XCTAssertTrue(registration.contains("network_error"))
        XCTAssertTrue(runtime.contains("deviceAuthorization"))
        XCTAssertTrue(runtime.contains(".blocked(.deviceNotActive)"))
        XCTAssertTrue(factory.contains("DeviceGuardedManualCatalogPushProvider"))
        XCTAssertTrue(factory.contains("DeviceGuardedManualHistorySessionProvider"))
        XCTAssertTrue(background.contains("blocked_device_status"))
        XCTAssertTrue(orchestrator.contains("deviceBlocked"))
    }

    func testSingleFlightStaysClosedDuringCooperativeCancellation() async {
        let singleFlight = AutomaticSyncSingleFlight()

        let didBeginFirstRun = await singleFlight.begin()
        XCTAssertTrue(didBeginFirstRun)
        await singleFlight.cancel()
        let isRunningAfterCancel = await singleFlight.isRunning
        XCTAssertTrue(isRunningAfterCancel)
        let didBeginSecondRunDuringCancel = await singleFlight.begin()
        XCTAssertFalse(didBeginSecondRunDuringCancel)

        await singleFlight.finish()
        let isRunningAfterFinish = await singleFlight.isRunning
        XCTAssertFalse(isRunningAfterFinish)
        let didBeginAfterFinish = await singleFlight.begin()
        XCTAssertTrue(didBeginAfterFinish)
        await singleFlight.finish()
    }

    func testCancellationPolicyInvalidatesExistingToken() async throws {
        let policy = AutomaticSyncCancellationPolicy()
        let token = await policy.makeToken()

        do {
            try await policy.checkCancellation(token: token)
        } catch {
            XCTFail("Unexpected cancellation before token invalidation: \(error)")
        }
        await policy.requestCancellation()

        do {
            try await policy.checkCancellation(token: token)
            XCTFail("Expected cancellation after token invalidation")
        } catch is CancellationError {
            // Expected.
        }
    }

    func testAutomaticEngineCancelDoesNotOpenSecondFlightBeforeFirstSettles() async {
        let provider = Task119BlockingCatalogProvider()
        let engine = AutomaticSyncEngine(
            catalogPushProvider: provider,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            activityRegistrationProvider: nil,
            defaults: UserDefaults(suiteName: "Task119-\(UUID().uuidString)")!
        )
        let owner = UUID()

        let firstRun = Task {
            await engine.run(action: .pushPending, source: .localMutation, ownerUserID: owner)
        }
        await provider.waitUntilFirstRunStarted()

        await engine.cancel()
        let secondRun = await engine.run(action: .pushPending, source: .localMutation, ownerUserID: owner)
        XCTAssertEqual(secondRun.status, .busy)
        let providerCallCount = await provider.callCount()
        XCTAssertEqual(providerCallCount, 1)

        await provider.releaseFirstRun()
        let firstResult = await firstRun.value
        XCTAssertEqual(firstResult.status, .cancelled)
        let engineIsRunning = await engine.isRunning()
        XCTAssertFalse(engineIsRunning)
    }

    func testAutomaticEngineRunsSnapshotRecoveryWhenIncrementalRequiresFullRecovery() async {
        let incrementalProvider = Task132RecoveryRequiredIncrementalProvider()
        let recoveryProvider = Task132SnapshotRecoveryProvider()
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: incrementalProvider,
            recoverySnapshotPullProvider: recoveryProvider,
            activityRegistrationProvider: nil,
            defaults: UserDefaults(suiteName: "Task132-\(UUID().uuidString)")!
        )

        let result = await engine.run(action: .lightReconcile, source: .rootForeground, ownerUserID: UUID())
        let recoveryCallCount = await recoveryProvider.callCount

        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.didWork)
        XCTAssertEqual(recoveryCallCount, 1)
    }

    func testTask132DAutomaticEngineRunsSnapshotRecoveryForBootstrapAction() async {
        let recoveryProvider = Task132SnapshotRecoveryProvider()
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            recoverySnapshotPullProvider: recoveryProvider,
            activityRegistrationProvider: nil,
            defaults: UserDefaults(suiteName: "Task132D-\(UUID().uuidString)")!
        )

        let result = await engine.run(action: .bootstrap, source: .rootForeground, ownerUserID: UUID())
        let recoveryCallCount = await recoveryProvider.callCount

        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.didWork)
        XCTAssertEqual(recoveryCallCount, 1)
    }

    func testTask132DAutomaticEngineRunsSnapshotRecoveryForFullRecoveryAction() async {
        let recoveryProvider = Task132SnapshotRecoveryProvider()
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            recoverySnapshotPullProvider: recoveryProvider,
            activityRegistrationProvider: nil,
            defaults: UserDefaults(suiteName: "Task132D-\(UUID().uuidString)")!
        )

        let result = await engine.run(action: .fullRecovery, source: .rootForeground, ownerUserID: UUID())
        let recoveryCallCount = await recoveryProvider.callCount

        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.didWork)
        XCTAssertEqual(recoveryCallCount, 1)
    }

    func testTask132DOrchestratorSchedulesRecoveryActionsThroughRuntime() throws {
        let orchestrator = try source("iOSMerchandiseControl/Sync/SyncOrchestrator.swift")

        XCTAssertTrue(orchestrator.contains("scheduled_bootstrap_recovery_via_sync_runtime"))
        XCTAssertTrue(orchestrator.contains("scheduled_full_recovery_via_sync_runtime"))
        XCTAssertFalse(orchestrator.contains("blocked_bootstrap_requires_explicit_context"))
        XCTAssertFalse(orchestrator.contains("blocked_full_recovery_requires_explicit_context"))
    }

    func testAutomaticEngineDoesNotTreatRecoveryRequestAsNoWorkWhenProviderIsMissing() async {
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            recoverySnapshotPullProvider: nil,
            activityRegistrationProvider: nil,
            defaults: UserDefaults(suiteName: "Task132-\(UUID().uuidString)")!
        )

        let result = await engine.run(action: .requestRecovery, source: .rootForeground, ownerUserID: UUID())

        XCTAssertEqual(result.status, .failed)
        XCTAssertFalse(result.didWork)
    }

    func testTask134CatalogUpdatePayloadOnlyIncludesChangedFields() {
        let product = Product(
            barcode: "TASK134-FIELD-MASK",
            itemNumber: "STALE-ITEM",
            productName: "STALE-NAME",
            purchasePrice: 50,
            retailPrice: 120,
            stockQuantity: 7
        )

        let payload = CatalogPushService.makeProductUpdatePayload(
            product,
            changedFields: ["retailPrice"]
        )

        XCTAssertNil(payload.barcode)
        XCTAssertNil(payload.itemNumber)
        XCTAssertNil(payload.productName)
        XCTAssertNil(payload.secondProductName)
        XCTAssertNil(payload.purchasePrice)
        XCTAssertEqual(payload.retailPrice, 120)
        XCTAssertNil(payload.supplierID)
        XCTAssertNil(payload.categoryID)
        XCTAssertNil(payload.stockQuantity)
        XCTAssertNil(payload.deletedAt)
    }

    func testTask069CatalogUpdatePayloadAcceptsRelationNameAliases() {
        let supplierID = UUID()
        let categoryID = UUID()
        let product = Product(
            barcode: "TASK069-FIELD-ALIASES",
            productName: "Alias Product",
            supplier: Supplier(name: "Alias Supplier", remoteID: supplierID),
            category: ProductCategory(name: "Alias Category", remoteID: categoryID)
        )

        let payload = CatalogPushService.makeProductUpdatePayload(
            product,
            changedFields: ["supplierName", "categoryName"]
        )

        XCTAssertEqual(payload.supplierID, supplierID)
        XCTAssertEqual(payload.categoryID, categoryID)
        XCTAssertNil(payload.productName)
        XCTAssertNil(payload.deletedAt)
    }
}

private final class Task119BlockingCatalogProvider: SyncCatalogPushProviding {
    private let started = Task119AsyncGate()
    private let release = Task119AsyncGate()
    private let counter = Task119AsyncCounter()

    func pushPendingCatalog(ownerUserID: UUID) async throws -> SyncCatalogPushResult {
        let call = await counter.increment()
        if call == 1 {
            await started.open()
            await release.wait()
        }
        var result = SyncCatalogPushResult()
        result.productCreates = 1
        return result
    }

    func waitUntilFirstRunStarted() async {
        await started.wait()
    }

    func releaseFirstRun() async {
        await release.open()
    }

    func callCount() async -> Int {
        await counter.value
    }
}

private final class Task132RecoveryRequiredIncrementalProvider: SyncIncrementalPullProviding {
    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SyncIncrementalPullSummary {
        var summary = SyncIncrementalPullSummary(
            syncType: .lightReconcile,
            watermarkBefore: 10,
            watermarkAfter: 12
        )
        summary.requiresFullRecoveryReason = "canonical_drift_detected"
        return summary
    }
}

private actor Task132SnapshotRecoveryProvider: SyncRecoverySnapshotPullProviding {
    private(set) var callCount = 0

    func recoverFromRemoteSnapshot(ownerUserID: UUID) async throws -> SyncRecoverySnapshotPullSummary {
        callCount += 1
        return SyncRecoverySnapshotPullSummary(
            catalog: SupabasePullApplyResult(
                inserted: 1,
                updated: 0,
                suppliersCreated: 1,
                categoriesCreated: 1
            ),
            history: HistorySessionPullResult(),
            productPrices: ProductPriceApplyResult(
                inserted: 1,
                skippedExisting: 0,
                totalConsidered: 1
            ),
            watermarkAfter: 12
        )
    }
}

private actor Task119AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func open() {
        guard !isOpen else { return }
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.resume()
        }
    }

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}

private actor Task119AsyncCounter {
    private var count = 0

    var value: Int {
        count
    }

    func increment() -> Int {
        count += 1
        return count
    }
}
