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

    func testHostedXCTestDoesNotRegisterOrScheduleProductionBackgroundSync() throws {
        let app = try source("iOSMerchandiseControl/iOSMerchandiseControlApp.swift")
        guard let registration = app.range(
            of: "SyncBackgroundTaskScheduler.shared.register()"
        ) else {
            return XCTFail("Production background registration was not found.")
        }
        let guardPrefix = app[..<registration.lowerBound].suffix(400)

        XCTAssertTrue(
            guardPrefix.contains("if !Self.isRunningHostedXCTest"),
            "Hosted XCTest must not inherit a pending production BGTask lifecycle."
        )
    }

    @MainActor
    func testBackgroundSchedulerFailsClosedBeforeRegistration() throws {
        let suiteName = "Task139BackgroundScheduler-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let scheduler = SyncBackgroundTaskScheduler(defaults: defaults)

        scheduler.schedule(reason: .foregroundCompletion)

        XCTAssertEqual(
            defaults.string(forKey: "sync.runtime.background.lastScheduleReason"),
            SyncBackgroundScheduleReason.foregroundCompletion.rawValue
        )
        XCTAssertEqual(
            defaults.string(forKey: "sync.runtime.background.lastScheduleError"),
            "background_not_registered"
        )
        XCTAssertFalse(defaults.bool(forKey: "sync.runtime.background.lastScheduleSucceeded"))
        XCTAssertNotNil(defaults.object(forKey: "sync.runtime.background.lastScheduleFailedAt"))
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

    func testStaleGenerationAdmissionRejectsAllProvidersBeforeMutation() async {
        let owner = UUID()
        let provider = Task119CountingCatalogProvider()
        let staleEngine = AutomaticSyncEngine(
            catalogPushProvider: provider,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            activityRegistrationProvider: nil,
            runAdmissionValidator: {
                throw SyncStoreGenerationError.staleGenerationLease
            }
        )

        let staleResult = await staleEngine.run(
            action: .pushPending,
            source: .rootForeground,
            ownerUserID: owner
        )
        let staleCallCount = await provider.callCount
        XCTAssertEqual(staleResult.status, .failed)
        XCTAssertEqual(staleCallCount, 0)

        let currentEngine = AutomaticSyncEngine(
            catalogPushProvider: provider,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            activityRegistrationProvider: nil,
            runAdmissionValidator: {}
        )
        let currentResult = await currentEngine.run(
            action: .pushPending,
            source: .rootForeground,
            ownerUserID: owner
        )
        let currentCallCount = await provider.callCount
        XCTAssertEqual(currentResult.status, .success)
        XCTAssertEqual(currentCallCount, 1)
    }

    func testOutboxOnlyPushDrainsWithoutFreshEntityMutation() async {
        let owner = UUID()
        let outbox = Task139OutboxOnlyRegistrationProvider()
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            activityRegistrationProvider: outbox,
            defaults: UserDefaults(suiteName: "Task139OutboxOnly-\(UUID().uuidString)")!
        )

        let result = await engine.run(
            action: .pushPending,
            source: .localMutation,
            ownerUserID: owner
        )

        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.didWork)
        let registerCallCount = await outbox.registerCallCount
        XCTAssertEqual(registerCallCount, 1)
    }

    func testAtomicRecoveryStopsPlanBeforeProvidersCapturedFromPriorGeneration() async {
        let owner = UUID()
        let defaults = makeVerifiedAutomaticDefaults(
            owner: owner,
            prefix: "Task139GenerationBoundary"
        )
        let recovery = Task132SnapshotRecoveryProvider(defaults: defaults)
        let catalog = Task119CountingCatalogProvider()
        let engine = AutomaticSyncEngine(
            catalogPushProvider: catalog,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            recoverySnapshotPullProvider: recovery,
            activityRegistrationProvider: nil,
            defaults: defaults
        )

        let result = await engine.run(
            action: .sequence([.fullRecovery, .pushPending]),
            source: .rootForeground,
            ownerUserID: owner
        )
        let recoveryCalls = await recovery.callCount
        let catalogCalls = await catalog.callCount
        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(recoveryCalls, 1)
        XCTAssertEqual(catalogCalls, 0)
    }

    func testAutomaticEngineExplicitRetryRunsVerifiedRecoveryWhenGapPersists() async {
        let owner = UUID()
        let defaults = makeVerifiedAutomaticDefaults(owner: owner, prefix: "Task132GapRecovery")
        defaults.set("stale_failure", forKey: "sync.runtime.automatic.lastError")
        let incrementalProvider = Task132RecoveryRequiredIncrementalProvider(
            reason: "sync_event_missing_entity_ids"
        )
        let recoveryProvider = Task132SnapshotRecoveryProvider(defaults: defaults)
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: incrementalProvider,
            recoverySnapshotPullProvider: recoveryProvider,
            activityRegistrationProvider: nil,
            defaults: defaults
        )

        let result = await engine.run(action: .requestRecovery, source: .releaseCard, ownerUserID: owner)
        let recoveryCallCount = await recoveryProvider.callCount
        let forcedReconcileFlags = await incrementalProvider.forceLightReconcileFlags()

        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.didWork)
        XCTAssertEqual(recoveryCallCount, 1)
        XCTAssertEqual(forcedReconcileFlags, [true])
        XCTAssertEqual(
            defaults.string(forKey: "sync.runtime.automatic.recovery.lastOutcome"),
            "completed"
        )
        XCTAssertNil(defaults.object(forKey: "sync.runtime.automatic.recovery.requestedAt"))
        XCTAssertNil(defaults.string(forKey: "sync.runtime.automatic.recovery.requestedReason"))
        XCTAssertNil(defaults.string(forKey: "sync.runtime.automatic.lastError"))
        XCTAssertFalse(defaults.bool(forKey: "sync.runtime.incremental.requiresFullRecovery"))
    }

    func testAutomaticEngineExplicitGapRecoveryFailsClosedWhenSnapshotProviderIsMissing() async {
        let owner = UUID()
        let defaults = makeVerifiedAutomaticDefaults(owner: owner, prefix: "Task132GapFailure")
        let incrementalProvider = Task132RecoveryRequiredIncrementalProvider(
            reason: "sync_event_missing_remote"
        )
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: incrementalProvider,
            recoverySnapshotPullProvider: nil,
            activityRegistrationProvider: nil,
            defaults: defaults
        )

        let result = await engine.run(
            action: .requestRecovery,
            source: .releaseCard,
            ownerUserID: owner
        )

        XCTAssertEqual(result.status, .failed)
        XCTAssertNotEqual(result.status, .success)
        XCTAssertNotEqual(result.status, .noWork)
        XCTAssertEqual(
            defaults.string(forKey: "sync.runtime.automatic.recovery.requestedReason"),
            "sync_event_missing_remote"
        )
        XCTAssertNotNil(defaults.string(forKey: "sync.runtime.automatic.lastError"))
    }

    func testAutomaticEngineTreatsCompletedNoChangeDrainAsUnverifiedNoWork() async {
        let incrementalProvider = Task136NoWorkIncrementalProvider()
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: incrementalProvider,
            activityRegistrationProvider: nil,
            defaults: UserDefaults(suiteName: "Task136-\(UUID().uuidString)")!
        )

        let result = await engine.run(action: .drainEvents, source: .rootForeground, ownerUserID: UUID())

        XCTAssertEqual(result.status, .noWork)
        XCTAssertFalse(result.didWork)
        XCTAssertFalse(result.verifiedConvergence)
    }

    func testTask132DAutomaticEngineRunsSnapshotRecoveryForBootstrapAction() async {
        let owner = UUID()
        let defaults = makeVerifiedAutomaticDefaults(owner: owner, prefix: "Task132DBootstrap")
        let recoveryProvider = Task132SnapshotRecoveryProvider(defaults: defaults)
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            recoverySnapshotPullProvider: recoveryProvider,
            activityRegistrationProvider: nil,
            defaults: defaults
        )

        let result = await engine.run(action: .bootstrap, source: .rootForeground, ownerUserID: owner)
        let recoveryCallCount = await recoveryProvider.callCount

        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.didWork)
        XCTAssertEqual(recoveryCallCount, 1)
    }

    func testTask132DAutomaticEngineRunsSnapshotRecoveryForFullRecoveryAction() async {
        let owner = UUID()
        let defaults = makeVerifiedAutomaticDefaults(owner: owner, prefix: "Task132DFullRecovery")
        let recoveryProvider = Task132SnapshotRecoveryProvider(defaults: defaults)
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            recoverySnapshotPullProvider: recoveryProvider,
            activityRegistrationProvider: nil,
            defaults: defaults
        )

        let result = await engine.run(action: .fullRecovery, source: .rootForeground, ownerUserID: owner)
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

    func testAutomaticEngineRequestRecoveryRunsAtomicSnapshotWhenReconcileIsUnverified() async {
        let owner = UUID()
        let defaults = makeVerifiedAutomaticDefaults(owner: owner, prefix: "Task132RequestRecovery")
        defaults.set("stale_failure", forKey: "sync.runtime.automatic.lastError")
        defaults.set("sync_event_missing_entity_ids", forKey: "sync.runtime.automatic.recovery.requestedReason")
        let incrementalProvider = Task119CleanForcedReconcileProvider(watermark: 12)
        let recoveryProvider = Task132SnapshotRecoveryProvider(defaults: defaults)
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: incrementalProvider,
            recoverySnapshotPullProvider: recoveryProvider,
            activityRegistrationProvider: nil,
            defaults: defaults
        )

        let result = await engine.run(action: .requestRecovery, source: .releaseCard, ownerUserID: owner)
        let forcedReconcileFlags = await incrementalProvider.forceLightReconcileFlags()
        let recoveryCallCount = await recoveryProvider.callCount

        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.didWork)
        XCTAssertTrue(result.verifiedConvergence)
        XCTAssertEqual(forcedReconcileFlags, [true])
        XCTAssertEqual(recoveryCallCount, 1)
        XCTAssertEqual(
            defaults.string(forKey: "sync.runtime.automatic.recovery.lastOutcome"),
            "completed"
        )
        XCTAssertNil(defaults.string(forKey: "sync.runtime.automatic.recovery.requestedReason"))
        XCTAssertNil(defaults.string(forKey: "sync.runtime.automatic.lastError"))
    }

    func testAutomaticRequestRecoveryWithoutUserTriggerStaysRecoveryRequired() async {
        let defaults = UserDefaults(suiteName: "Task132RequestMissing-\(UUID().uuidString)")!
        let recoveryProvider = Task132SnapshotRecoveryProvider(defaults: defaults)
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            recoverySnapshotPullProvider: recoveryProvider,
            activityRegistrationProvider: nil,
            defaults: defaults
        )

        let result = await engine.run(
            action: .requestRecovery,
            source: .rootForeground,
            ownerUserID: UUID()
        )
        let recoveryCallCount = await recoveryProvider.callCount

        XCTAssertEqual(result.status, .recoveryRequired)
        XCTAssertNotEqual(result.status, .success)
        XCTAssertNotEqual(result.status, .noWork)
        XCTAssertEqual(recoveryCallCount, 0)
        XCTAssertNil(defaults.string(forKey: "sync.runtime.automatic.lastError"))
    }

    func testAutomaticEngineExplicitRecoveryFailsClosedWithoutIncrementalProvider() async {
        let defaults = UserDefaults(suiteName: "Task132ExplicitMissing-\(UUID().uuidString)")!
        let recoveryProvider = Task132SnapshotRecoveryProvider(defaults: defaults)
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            recoverySnapshotPullProvider: recoveryProvider,
            activityRegistrationProvider: nil,
            defaults: defaults
        )

        let result = await engine.run(
            action: .requestRecovery,
            source: .releaseCard,
            ownerUserID: UUID()
        )
        let recoveryCallCount = await recoveryProvider.callCount

        XCTAssertEqual(result.status, .failed)
        XCTAssertEqual(recoveryCallCount, 0)
        XCTAssertNotNil(defaults.string(forKey: "sync.runtime.automatic.lastError"))
    }

    func testAutomaticEngineNormalGapStopsSnapshotAndPrecomputedPush() async {
        let owner = UUID()
        let defaults = makeVerifiedAutomaticDefaults(owner: owner, prefix: "Task132RecoveryPlanAbort")
        let incrementalProvider = Task132RecoveryRequiredIncrementalProvider(
            reason: "canonical_drift_detected"
        )
        let recoveryProvider = Task132SnapshotRecoveryProvider(defaults: defaults)
        let catalogProvider = Task119CountingCatalogProvider()
        let engine = AutomaticSyncEngine(
            catalogPushProvider: catalogProvider,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: incrementalProvider,
            recoverySnapshotPullProvider: recoveryProvider,
            activityRegistrationProvider: nil,
            defaults: defaults
        )

        let result = await engine.run(
            action: .sequence([.lightReconcile, .pushPending, .drainEvents]),
            source: .rootForeground,
            ownerUserID: owner
        )
        let catalogCallCount = await catalogProvider.callCount
        let recoveryCallCount = await recoveryProvider.callCount
        let forcedReconcileFlags = await incrementalProvider.forceLightReconcileFlags()

        XCTAssertEqual(result.status, .recoveryRequired)
        XCTAssertFalse(result.didWork)
        XCTAssertEqual(recoveryCallCount, 0)
        XCTAssertEqual(catalogCallCount, 0)
        XCTAssertEqual(forcedReconcileFlags, [true])
        XCTAssertEqual(
            defaults.string(forKey: "sync.runtime.automatic.recovery.requestedReason"),
            "canonical_drift_detected"
        )
    }

    func testExplicitRetryPushesPendingThenRunsVerifiedSnapshotWhenGapPersists() async {
        let owner = UUID()
        let defaults = makeVerifiedAutomaticDefaults(owner: owner, prefix: "Task139PendingRecoveryRetry")
        let incrementalProvider = Task132RecoveryRequiredIncrementalProvider(
            reason: "sync_event_missing_entity_ids"
        )
        let recoveryProvider = Task132SnapshotRecoveryProvider(defaults: defaults)
        let catalogProvider = Task119CountingCatalogProvider()
        let engine = AutomaticSyncEngine(
            catalogPushProvider: catalogProvider,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: incrementalProvider,
            recoverySnapshotPullProvider: recoveryProvider,
            activityRegistrationProvider: nil,
            defaults: defaults
        )

        let pendingPlan = SyncAction.sequence([.lightReconcile, .pushPending, .drainEvents])
        let retryAction = await MainActor.run {
            SyncOrchestrator.explicitRecoveryAction(afterGates: pendingPlan)
        }
        let result = await engine.run(
            action: retryAction,
            source: .releaseCard,
            ownerUserID: owner
        )
        let catalogCallCount = await catalogProvider.callCount
        let recoveryCallCount = await recoveryProvider.callCount

        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.didWork)
        XCTAssertEqual(catalogCallCount, 1)
        XCTAssertEqual(recoveryCallCount, 1)
    }

    @MainActor
    func testRecoveryRequiredUsesExplicitRetryAndBoundedSafeAutomaticResumeSources() {
        XCTAssertEqual(
            SyncOrchestrator.retryTriggerSource(for: .recoveryRequired),
            .releaseCard
        )
        XCTAssertEqual(
            SyncOrchestrator.retryTriggerSource(for: .failed),
            .rootForeground
        )
        XCTAssertTrue(SyncOrchestrator.shouldPreserveRecoveryRequired(
            phase: .recoveryRequired,
            source: .foregroundPoll
        ))
        XCTAssertFalse(SyncOrchestrator.shouldPreserveRecoveryRequired(
            phase: .recoveryRequired,
            source: .releaseCard
        ))
        XCTAssertTrue(SyncOrchestrator.allowsAutomaticRecoveryResume(
            source: .rootForeground,
            hasDecodableJournal: true
        ))
        XCTAssertTrue(SyncOrchestrator.allowsAutomaticRecoveryResume(
            source: .networkReconnect,
            hasDecodableJournal: true
        ))
        XCTAssertFalse(SyncOrchestrator.allowsAutomaticRecoveryResume(
            source: .foregroundPoll,
            hasDecodableJournal: true
        ))
        XCTAssertFalse(SyncOrchestrator.allowsAutomaticRecoveryResume(
            source: .rootForeground,
            hasDecodableJournal: false
        ))
        XCTAssertEqual(
            SyncOrchestrator.explicitRecoveryAction(afterGates: .noOp),
            .requestRecovery
        )
        XCTAssertEqual(
            SyncOrchestrator.explicitRecoveryAction(
                afterGates: .blocked(.networkUnavailable)
            ),
            .blocked(.networkUnavailable)
        )
        XCTAssertEqual(
            SyncOrchestrator.explicitRecoveryAction(afterGates: .retryAfterBusy),
            .retryAfterBusy
        )
        let pendingPlan = SyncAction.sequence([
            .lightReconcile,
            .pushPending,
            .drainEvents
        ])
        XCTAssertEqual(
            SyncOrchestrator.explicitRecoveryAction(afterGates: pendingPlan),
            .sequence([.pushPending, .requestRecovery])
        )
        XCTAssertEqual(
            SyncOrchestrator.explicitRecoveryAction(afterGates: .pushPending),
            .sequence([.pushPending, .requestRecovery])
        )
        XCTAssertEqual(
            SyncOrchestrator.preferredDeferredSource(
                current: .releaseCard,
                incoming: .networkReconnect
            ),
            .releaseCard
        )
        XCTAssertEqual(
            SyncOrchestrator.preferredDeferredSource(
                current: .foregroundPoll,
                incoming: .releaseCard
            ),
            .releaseCard
        )
    }

    func testExplicitPendingRetryRunsForcedReconcileBeforeSuccess() async {
        let owner = UUID()
        let defaults = makeVerifiedAutomaticDefaults(
            owner: owner,
            prefix: "Task139PendingRecoveryForcedReconcile"
        )
        let incrementalProvider = Task119CleanForcedReconcileProvider(watermark: 139)
        let catalogProvider = Task119CountingCatalogProvider()
        let engine = AutomaticSyncEngine(
            catalogPushProvider: catalogProvider,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: incrementalProvider,
            recoverySnapshotPullProvider: nil,
            activityRegistrationProvider: nil,
            defaults: defaults
        )

        let retryAction = await MainActor.run {
            SyncOrchestrator.explicitRecoveryAction(afterGates: .pushPending)
        }
        let result = await engine.run(
            action: retryAction,
            source: .releaseCard,
            ownerUserID: owner
        )
        let forcedFlags = await incrementalProvider.forceLightReconcileFlags()
        let catalogCallCount = await catalogProvider.callCount

        XCTAssertEqual(retryAction, .sequence([.pushPending, .requestRecovery]))
        XCTAssertEqual(result.status, .failed)
        XCTAssertFalse(result.didWork)
        XCTAssertEqual(catalogCallCount, 1)
        XCTAssertEqual(forcedFlags, [true])
    }

    func testCancellationAfterDurableRecoveryCompletionReturnsVerifiedSuccess() async throws {
        let owner = UUID()
        let defaults = makeVerifiedAutomaticDefaults(
            owner: owner,
            prefix: "Task139TerminalCancelEngine"
        )
        let provider = Task132SnapshotRecoveryProvider(
            defaults: defaults,
            pauseAfterCompletion: true
        )
        let engine = AutomaticSyncEngine(
            catalogPushProvider: nil,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: nil,
            recoverySnapshotPullProvider: provider,
            activityRegistrationProvider: nil,
            defaults: defaults
        )

        let run = Task {
            await engine.run(
                action: .fullRecovery,
                source: .releaseCard,
                ownerUserID: owner
            )
        }
        await provider.waitUntilDurablyCompleted()
        await engine.cancel()
        await provider.releaseAfterDurableCompletion()
        let result = await run.value

        XCTAssertEqual(result.status, .success)
        XCTAssertTrue(result.verifiedConvergence)
        XCTAssertFalse(AccountBindingStore(defaults: defaults).hasPendingReplacementJournal)
    }

    @MainActor
    func testSameScopeJournalAdmitsOnlyExactPushThenRecoveryThroughFacade() async throws {
        let owner = UUID()
        let defaults = makeVerifiedAutomaticDefaults(
            owner: owner,
            prefix: "Task139SameScopeFacade"
        )
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: owner,
            defaults: defaults
        )
        let bindingStore = AccountBindingStore(defaults: defaults)
        XCTAssertTrue(bindingStore.beginSameScopeRecovery(
            accountHash: scope.accountHash,
            storeIdentity: scope.storeIdentity,
            reason: "sync_event_missing_entity_ids",
            deviceIdentityHash: scope.deviceIdentityHash
        ))
        let catalog = Task119CountingCatalogProvider()
        let incremental = Task119CleanForcedReconcileProvider(watermark: 139)
        let facade = AutomaticSyncRuntimeFacade(
            authViewModel: SupabaseAuthViewModel(authService: nil),
            catalogPushProvider: catalog,
            productPriceProvider: nil,
            historySessionProvider: nil,
            incrementalPullProvider: incremental,
            recoverySnapshotPullProvider: nil,
            activityRegistrationProvider: nil,
            defaults: defaults,
            authenticatedOwnerProvider: { owner }
        )

        let rejected = await facade.run(
            action: .sequence([.requestRecovery, .pushPending]),
            source: .releaseCard
        )
        let callsAfterRejected = await catalog.callCount
        XCTAssertEqual(rejected.status, .recoveryRequired)
        XCTAssertEqual(callsAfterRejected, 0)

        let admitted = await facade.run(
            action: .sequence([.pushPending, .requestRecovery]),
            source: .releaseCard
        )
        let callsAfterAdmitted = await catalog.callCount
        XCTAssertEqual(admitted.status, .failed)
        XCTAssertEqual(callsAfterAdmitted, 1)
        XCTAssertTrue(bindingStore.hasPendingReplacementJournal)
    }

    @MainActor
    func testBusyRecoveryRetryIsBoundedAndKeepsRecoveryLatch() async {
        let suiteName = "Task139BusyRetryBounded-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let stateStore = SyncStateStore(defaults: defaults, keyPrefix: "task139.busyRetry")
        stateStore.recordRunResult(.recoveryRequired())
        let runtime = Task139AlwaysBusyRuntime()
        let orchestrator = SyncOrchestrator(
            automaticRuntime: runtime,
            authViewModel: SupabaseAuthViewModel(authService: nil),
            activityCenter: ForegroundCloudWorkflowActivityCenter(),
            syncEventSignalWatcher: nil,
            stateStore: stateStore,
            decisionInputProvider: Task119NoOpDecisionInputProvider(),
            backgroundScheduler: SyncNoopBackgroundTaskScheduler(),
            maximumForegroundBusyRetryAttempts: 2,
            foregroundRetryDelay: { _ in await Task.yield() }
        )

        orchestrator.retryRootActionIfPossible()
        for _ in 0..<200 where runtime.runCount < 3 || stateStore.state.lastOutcome != .failed {
            await Task.yield()
        }

        XCTAssertEqual(runtime.runCount, 3)
        XCTAssertEqual(stateStore.state.phase, .recoveryRequired)
        XCTAssertEqual(stateStore.state.lastOutcome, .failed)
        let relaunched = SyncStateStore(defaults: defaults, keyPrefix: "task139.busyRetry")
        XCTAssertEqual(relaunched.state.phase, .recoveryRequired)
        XCTAssertEqual(relaunched.state.lastOutcome, .failed)
    }

    @MainActor
    func testOrchestratorPreservesRecoveryPhaseUntilExplicitRetryCTA() async {
        let suiteName = "Task139OrchestratorRecovery-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let stateStore = SyncStateStore(defaults: defaults, keyPrefix: "task139.orchestrator")
        stateStore.recordRunResult(.recoveryRequired())
        let runtime = Task119RecordingRuntime()
        let decisionProvider = Task119NoOpDecisionInputProvider()
        let orchestrator = SyncOrchestrator(
            automaticRuntime: runtime,
            authViewModel: SupabaseAuthViewModel(authService: nil),
            activityCenter: ForegroundCloudWorkflowActivityCenter(),
            syncEventSignalWatcher: nil,
            stateStore: stateStore,
            decisionInputProvider: decisionProvider,
            backgroundScheduler: SyncNoopBackgroundTaskScheduler()
        )

        orchestrator.submitForegroundTrigger(
            source: .foregroundPoll,
            forceIncremental: true
        )
        let callCountBeforeRetry = await decisionProvider.callCount

        XCTAssertEqual(stateStore.state.phase, .recoveryRequired)
        XCTAssertTrue(runtime.actions.isEmpty)
        XCTAssertEqual(callCountBeforeRetry, 0)

        orchestrator.retryRootActionIfPossible()
        for _ in 0..<100 where runtime.actions.isEmpty {
            await Task.yield()
        }
        let callCountAfterRetry = await decisionProvider.callCount

        XCTAssertEqual(runtime.actions, [.requestRecovery])
        XCTAssertEqual(runtime.sources, [.releaseCard])
        XCTAssertEqual(callCountAfterRetry, 1)
        XCTAssertEqual(stateStore.state.phase, .idle)
    }

    @MainActor
    func testForcedForegroundSafetyCheckUpgradesOnlyNoOpToLightReconcile() async {
        let suiteName = "Task139ForcedForeground-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let stateStore = SyncStateStore(defaults: defaults, keyPrefix: "task139.forcedForeground")
        stateStore.recordRunResult(.success(didWork: false, verifiedConvergence: true))
        let runtime = Task119RecordingRuntime()
        let orchestrator = SyncOrchestrator(
            automaticRuntime: runtime,
            authViewModel: SupabaseAuthViewModel(authService: nil),
            activityCenter: ForegroundCloudWorkflowActivityCenter(),
            syncEventSignalWatcher: nil,
            stateStore: stateStore,
            decisionInputProvider: Task119NoOpDecisionInputProvider(),
            backgroundScheduler: SyncNoopBackgroundTaskScheduler()
        )

        orchestrator.submitForegroundTrigger(
            source: .foregroundPoll,
            forceIncremental: true
        )
        for _ in 0..<100 where runtime.actions.isEmpty {
            await Task.yield()
        }

        XCTAssertEqual(runtime.actions, [.lightReconcile])
        XCTAssertEqual(runtime.sources, [.foregroundPoll])
    }

    @MainActor
    func testExplicitRecoveryCancellationPreservesPhaseAcrossRelaunch() async {
        let suiteName = "Task139OrchestratorCancel-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let stateStore = SyncStateStore(defaults: defaults, keyPrefix: "task139.cancel")
        stateStore.recordRunResult(.recoveryRequired())
        let runtime = Task119BlockingRecoveryRuntime()
        let orchestrator = SyncOrchestrator(
            automaticRuntime: runtime,
            authViewModel: SupabaseAuthViewModel(authService: nil),
            activityCenter: ForegroundCloudWorkflowActivityCenter(),
            syncEventSignalWatcher: nil,
            stateStore: stateStore,
            decisionInputProvider: Task119NoOpDecisionInputProvider(),
            backgroundScheduler: SyncNoopBackgroundTaskScheduler()
        )

        orchestrator.retryRootActionIfPossible()
        for _ in 0..<100 where !runtime.hasStarted {
            await Task.yield()
        }
        XCTAssertTrue(runtime.hasStarted)
        XCTAssertEqual(stateStore.state.phase, .reconciling)

        orchestrator.cancelForegroundCheck()
        await Task.yield()

        XCTAssertEqual(stateStore.state.phase, .recoveryRequired)
        XCTAssertEqual(stateStore.state.lastOutcome, .cancelled)
        let relaunched = SyncStateStore(defaults: defaults, keyPrefix: "task139.cancel")
        XCTAssertEqual(relaunched.state.phase, .recoveryRequired)
        XCTAssertEqual(relaunched.state.lastOutcome, .cancelled)
    }

    @MainActor
    func testOrchestratorAcceptsVerifiedTerminalCommitAfterOuterCancellation() async {
        let suiteName = "Task139TerminalCancelOrchestrator-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let stateStore = SyncStateStore(
            defaults: defaults,
            keyPrefix: "task139.terminalCancel"
        )
        stateStore.recordRunResult(.recoveryRequired())
        let runtime = Task139CommittedAfterCancelRuntime()
        let orchestrator = SyncOrchestrator(
            automaticRuntime: runtime,
            authViewModel: SupabaseAuthViewModel(authService: nil),
            activityCenter: ForegroundCloudWorkflowActivityCenter(),
            syncEventSignalWatcher: nil,
            stateStore: stateStore,
            decisionInputProvider: Task119NoOpDecisionInputProvider(),
            backgroundScheduler: SyncNoopBackgroundTaskScheduler()
        )

        orchestrator.retryRootActionIfPossible()
        for _ in 0..<100 where !runtime.hasStarted {
            await Task.yield()
        }
        orchestrator.cancelForegroundCheck()
        XCTAssertEqual(stateStore.state.phase, .recoveryRequired)
        runtime.finishDurableCommit()
        for _ in 0..<100 where stateStore.state.phase != .idle {
            await Task.yield()
        }

        XCTAssertEqual(stateStore.state.phase, .idle)
        XCTAssertEqual(stateStore.state.lastOutcome, .succeeded)
        let relaunched = SyncStateStore(
            defaults: defaults,
            keyPrefix: "task139.terminalCancel"
        )
        XCTAssertEqual(relaunched.state.phase, .idle)
        XCTAssertEqual(relaunched.state.lastOutcome, .succeeded)
    }

    @MainActor
    func testImmediateRetryAfterCancellationRunsWhenCancelledFlightFinishes() async {
        let suiteName = "Task139OrchestratorCancelRetry-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let stateStore = SyncStateStore(defaults: defaults, keyPrefix: "task139.cancelRetry")
        stateStore.recordRunResult(.recoveryRequired())
        let runtime = Task119DelayedCancellationRecoveryRuntime()
        let decisionProvider = Task119NoOpDecisionInputProvider()
        let orchestrator = SyncOrchestrator(
            automaticRuntime: runtime,
            authViewModel: SupabaseAuthViewModel(authService: nil),
            activityCenter: ForegroundCloudWorkflowActivityCenter(),
            syncEventSignalWatcher: nil,
            stateStore: stateStore,
            decisionInputProvider: decisionProvider,
            backgroundScheduler: SyncNoopBackgroundTaskScheduler()
        )

        orchestrator.retryRootActionIfPossible()
        for _ in 0..<100 where runtime.runCount == 0 {
            await Task.yield()
        }
        XCTAssertEqual(runtime.runCount, 1)

        orchestrator.cancelForegroundCheck()
        orchestrator.retryRootActionIfPossible()
        let decisionCountWhileCancelling = await decisionProvider.callCount
        XCTAssertEqual(runtime.runCount, 1)
        XCTAssertEqual(decisionCountWhileCancelling, 1)
        XCTAssertEqual(stateStore.state.phase, .recoveryRequired)

        runtime.finishCancellation()
        for _ in 0..<100 where runtime.runCount < 2 || stateStore.state.phase != .idle {
            await Task.yield()
        }
        let finalDecisionCount = await decisionProvider.callCount

        XCTAssertEqual(runtime.actions, [.requestRecovery, .requestRecovery])
        XCTAssertEqual(runtime.runCount, 2)
        XCTAssertEqual(finalDecisionCount, 2)
        XCTAssertEqual(stateStore.state.phase, .idle)
        XCTAssertEqual(stateStore.state.lastOutcome, .succeeded)
    }

    func testOptionsRecoveryRetryAndCheckAgainUseSeparateCallbacks() throws {
        let options = try source("iOSMerchandiseControl/OptionsView.swift")

        XCTAssertTrue(options.contains("syncState.phase == .recoveryRequired"))
        XCTAssertTrue(options.contains("requestExplicitRecovery()"))
        XCTAssertTrue(options.contains("requestAutomaticCloudCheck()"))
        XCTAssertTrue(options.contains("requestExplicitRecovery: requestExplicitRecoveryNow"))
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

    func testRemoteProductUpdatesAreShopScopedAndReadBackChecked() throws {
        let executor = try source("iOSMerchandiseControl/Sync/Remote/SupabaseRemoteQueryExecutor.swift")
        let executorUpdateStart = try XCTUnwrap(executor.range(of: "func updateRow"))
        let executorUpdateEnd = try XCTUnwrap(
            executor.range(
                of: "func exactRowCount",
                range: executorUpdateStart.upperBound..<executor.endIndex
            )
        )
        let executorUpdate = String(executor[executorUpdateStart.lowerBound..<executorUpdateEnd.lowerBound])

        XCTAssertTrue(executorUpdate.contains("selectedShopID(ownerUserID: ownerUserID)"))
        XCTAssertTrue(executorUpdate.contains(#"request = request.eq("shop_id", value: selectedShopID.uuidString)"#))

        let priceAdapter = try source("iOSMerchandiseControl/Sync/Remote/ProductPriceManualPushRemoteSupabaseAdapter.swift")
        let priceUpdateStart = try XCTUnwrap(priceAdapter.range(of: "func updateProduct"))
        let priceUpdateEnd = try XCTUnwrap(
            priceAdapter.range(
                of: "private func mapProductPriceManualPushPostgrestError",
                range: priceUpdateStart.upperBound..<priceAdapter.endIndex
            )
        )
        let priceUpdate = String(priceAdapter[priceUpdateStart.lowerBound..<priceUpdateEnd.lowerBound])

        XCTAssertTrue(priceUpdate.contains("ShopContextSelection.selectedShopID(ownerUserID: ownerUserID)"))
        XCTAssertTrue(priceUpdate.contains(#"request = request.eq("shop_id", value: selectedShopID.uuidString)"#))
        XCTAssertTrue(priceUpdate.contains("row.shopID == selectedShopID"))
    }

    func testAutomaticCatalogCreatesUseDeterministicIDUpserts() throws {
        let adapter = try source(
            "iOSMerchandiseControl/Sync/Remote/CatalogRemoteSupabaseAdapter.swift"
        )
        let service = try source(
            "iOSMerchandiseControl/Sync/Automatic/Catalog/CatalogPushService.swift"
        )
        XCTAssertEqual(
            adapter.components(separatedBy: #".upsert(payloads, onConflict: "id")"#).count - 1,
            3
        )
        XCTAssertFalse(adapter.contains("query.insertRows("))
        XCTAssertTrue(service.contains("catalog-create-v1"))
        XCTAssertTrue(service.contains("token.idempotencyKey"))
        XCTAssertFalse(service.contains("catalog-create-v1|barcode"))
    }

    private func makeVerifiedAutomaticDefaults(owner: UUID, prefix: String) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "\(prefix)-\(UUID().uuidString)")!
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let shop = SelectedShop(
            shopID: UUID(),
            code: nil,
            name: "Task119 fixture shop",
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true
        )
        let selectedShopStore = SelectedShopStore(defaults: defaults)
        selectedShopStore.noteActiveAccount(accountHash)
        XCTAssertTrue(selectedShopStore.save(shop, accountHash: accountHash))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(
            accountHash: accountHash,
            storeIdentity: shop.localStoreIdentity
        ))
        return defaults
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

private actor Task132RecoveryRequiredIncrementalProvider: SyncIncrementalPullProviding {
    private let reason: String
    private var callCount = 0
    private var forcedFlags: [Bool] = []

    init(reason: String = "canonical_drift_detected") {
        self.reason = reason
    }

    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SyncIncrementalPullSummary {
        makeSummary(forceLightReconcile: false)
    }

    func applyIncrementalRemoteChanges(
        ownerUserID: UUID,
        forceLightReconcile: Bool
    ) async throws -> SyncIncrementalPullSummary {
        makeSummary(forceLightReconcile: forceLightReconcile)
    }

    func forceLightReconcileFlags() -> [Bool] {
        forcedFlags
    }

    private func makeSummary(forceLightReconcile: Bool) -> SyncIncrementalPullSummary {
        callCount += 1
        forcedFlags.append(forceLightReconcile)
        guard callCount == 1 else {
            return SyncIncrementalPullSummary(
                syncType: .lightReconcile,
                watermarkBefore: 12,
                watermarkAfter: 12
            )
        }
        var summary = SyncIncrementalPullSummary(
            syncType: .lightReconcile,
            watermarkBefore: 10,
            watermarkAfter: 12
        )
        summary.requiresFullRecoveryReason = reason
        return summary
    }
}

private actor Task119CleanForcedReconcileProvider: SyncIncrementalPullProviding {
    private let watermark: Int64
    private var forcedFlags: [Bool] = []

    init(watermark: Int64) {
        self.watermark = watermark
    }

    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SyncIncrementalPullSummary {
        makeSummary(forceLightReconcile: false)
    }

    func applyIncrementalRemoteChanges(
        ownerUserID: UUID,
        forceLightReconcile: Bool
    ) async throws -> SyncIncrementalPullSummary {
        makeSummary(forceLightReconcile: forceLightReconcile)
    }

    func forceLightReconcileFlags() -> [Bool] {
        forcedFlags
    }

    private func makeSummary(forceLightReconcile: Bool) -> SyncIncrementalPullSummary {
        forcedFlags.append(forceLightReconcile)
        return SyncIncrementalPullSummary(
            syncType: .lightReconcile,
            watermarkBefore: watermark,
            watermarkAfter: watermark
        )
    }
}

private actor Task119CountingCatalogProvider: SyncCatalogPushProviding {
    private(set) var callCount = 0

    func pushPendingCatalog(ownerUserID: UUID) async throws -> SyncCatalogPushResult {
        callCount += 1
        var result = SyncCatalogPushResult()
        result.productCreates = 1
        return result
    }
}

private actor Task139OutboxOnlyRegistrationProvider: SyncActivityRegistrationProviding {
    private(set) var registerCallCount = 0

    func loadSyncActivityRegistrationSnapshot(
        ownerUserID: UUID
    ) async throws -> SyncActivityRegistrationSnapshot {
        SyncActivityRegistrationSnapshot(readyToRegister: 1, waiting: 0, notRegisterable: 0)
    }

    func registerSyncActivities(
        ownerUserID: UUID
    ) async throws -> SyncActivityRegistrationResult {
        registerCallCount += 1
        return SyncActivityRegistrationResult(
            status: .success,
            summary: SyncActivityRegistrationSummary(
                registered: 1,
                waiting: 0,
                notRegisterable: 0
            )
        )
    }
}

@MainActor
private final class Task119RecordingRuntime: SyncAutomaticRuntimeProviding {
    private(set) var actions: [SyncAction] = []
    private(set) var sources: [SyncAutomaticTriggerSource] = []

    var isRunning: Bool { false }

    func run(
        action: SyncAction,
        source: SyncAutomaticTriggerSource
    ) async -> SyncAutomaticRunResult {
        actions.append(action)
        sources.append(source)
        return .success(
            didWork: false,
            verifiedConvergence: action == .requestRecovery
        )
    }

    func cancel() {}
    func cancelAndWait() async {}
    func resumeAfterStoreReplacement() async {}
}

@MainActor
private final class Task139AlwaysBusyRuntime: SyncAutomaticRuntimeProviding {
    private(set) var runCount = 0

    var isRunning: Bool { false }

    func run(
        action: SyncAction,
        source: SyncAutomaticTriggerSource
    ) async -> SyncAutomaticRunResult {
        runCount += 1
        return .busy()
    }

    func cancel() {}
    func cancelAndWait() async {}
    func resumeAfterStoreReplacement() async {}
}

@MainActor
private final class Task119BlockingRecoveryRuntime: SyncAutomaticRuntimeProviding {
    private var continuation: CheckedContinuation<SyncAutomaticRunResult, Never>?
    private(set) var hasStarted = false

    var isRunning: Bool { continuation != nil }

    func run(
        action: SyncAction,
        source: SyncAutomaticTriggerSource
    ) async -> SyncAutomaticRunResult {
        hasStarted = true
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func cancel() {
        continuation?.resume(returning: .cancelled())
        continuation = nil
    }

    func cancelAndWait() async {
        cancel()
    }

    func resumeAfterStoreReplacement() async {}
}

@MainActor
private final class Task139CommittedAfterCancelRuntime: SyncAutomaticRuntimeProviding {
    private var continuation: CheckedContinuation<SyncAutomaticRunResult, Never>?
    private(set) var hasStarted = false

    var isRunning: Bool { continuation != nil }

    func run(
        action: SyncAction,
        source: SyncAutomaticTriggerSource
    ) async -> SyncAutomaticRunResult {
        hasStarted = true
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func cancel() {
        // Simulates cancellation after the provider crossed its terminal
        // durable boundary but before the verified result reached the caller.
    }

    func cancelAndWait() async {}
    func resumeAfterStoreReplacement() async {}

    func finishDurableCommit() {
        continuation?.resume(returning: .success(
            didWork: true,
            verifiedConvergence: true
        ))
        continuation = nil
    }
}

@MainActor
private final class Task119DelayedCancellationRecoveryRuntime: SyncAutomaticRuntimeProviding {
    private var continuation: CheckedContinuation<SyncAutomaticRunResult, Never>?
    private(set) var actions: [SyncAction] = []
    private(set) var runCount = 0

    var isRunning: Bool { continuation != nil }

    func run(
        action: SyncAction,
        source: SyncAutomaticTriggerSource
    ) async -> SyncAutomaticRunResult {
        actions.append(action)
        runCount += 1
        guard runCount == 1 else {
            return .success(didWork: false, verifiedConvergence: true)
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func cancel() {}

    func cancelAndWait() async {}

    func resumeAfterStoreReplacement() async {}

    func finishCancellation() {
        continuation?.resume(returning: .cancelled())
        continuation = nil
    }
}

private actor Task119NoOpDecisionInputProvider: SyncDecisionInputProviding {
    private(set) var callCount = 0

    func updateNetworkStatus(_ status: AutomaticSyncNetworkStatus) async {}
    func recordRealtimeEvent() async {}

    func makeSnapshot(
        triggerSource: SyncAutomaticTriggerSource,
        isAuthenticated: Bool,
        ownerUserID: UUID?,
        isSyncBusy: Bool
    ) async -> SyncDecisionInputSnapshot {
        callCount += 1
        return SyncDecisionInputSnapshot(
            triggerSource: triggerSource,
            isAuthenticated: true,
            ownerUserID: UUID(),
            ownerStoreBindingResolution: .matched,
            accountBindingMatches: true,
            networkStatus: .satisfied,
            pendingLocalChanges: .empty,
            pendingOutboxCount: 0,
            requiresBootstrap: false,
            requiresFullRecovery: false,
            hasRecoveryDrift: false,
            hasRealtimeEvent: false,
            isSyncBusy: false,
            hasStateReadFailure: false,
            requestsLightReconcile: false
        )
    }
}

private final class Task136NoWorkIncrementalProvider: SyncIncrementalPullProviding {
    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SyncIncrementalPullSummary {
        .noWork(watermark: 136)
    }
}

private actor Task132SnapshotRecoveryProvider: SyncRecoverySnapshotPullProviding {
    nonisolated let publicationMode = SyncRecoverySnapshotPublicationMode.atomicGeneration
    private let defaults: UserDefaults?
    private let pauseAfterCompletion: Bool
    private let durableCompletionGate = Task119AsyncGate()
    private let durableCompletionRelease = Task119AsyncGate()
    private(set) var callCount = 0

    init(
        defaults: UserDefaults? = nil,
        pauseAfterCompletion: Bool = false
    ) {
        self.defaults = defaults
        self.pauseAfterCompletion = pauseAfterCompletion
    }

    func recoverFromRemoteSnapshot(ownerUserID: UUID) async throws -> SyncRecoverySnapshotPullSummary {
        callCount += 1
        guard let defaults else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
        let bindingStore = AccountBindingStore(defaults: defaults)
        let initialScope = try Task126OwnerStoreGate.requireCurrentAutomaticScope(
            ownerUserID: ownerUserID,
            defaults: defaults
        )
        if !bindingStore.hasPendingReplacementJournal {
            guard bindingStore.beginSameScopeRecovery(
                accountHash: initialScope.accountHash,
                storeIdentity: initialScope.storeIdentity,
                reason: "task132_atomic_fixture",
                deviceIdentityHash: initialScope.deviceIdentityHash
            ) else {
                throw Task126OwnerStoreGateError.replacementInterrupted
            }
        }
        var scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: ownerUserID,
            defaults: defaults,
            allowsPendingReplacement: true
        )
        let generationID = UUID()
        let baselineRunID = UUID()
        let checkpoint = makeCheckpoint(scope: scope, watermark: 12)
        guard bindingStore.recordPendingRecoveryStaging(
            accountHash: scope.accountHash,
            storeIdentity: scope.storeIdentity,
            deviceIdentityHash: scope.deviceIdentityHash,
            generationID: generationID,
            scope: scope
        ) else {
            throw Task126OwnerStoreGateError.replacementInterrupted
        }
        scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: ownerUserID,
            defaults: defaults,
            allowsPendingReplacement: true
        )
        guard bindingStore.recordPendingRecoveryVerified(
            accountHash: scope.accountHash,
            storeIdentity: scope.storeIdentity,
            deviceIdentityHash: scope.deviceIdentityHash,
            generationID: generationID,
            checkpointDigest: checkpoint.checkpointDigest,
            watermark: 12,
            baselineRunID: baselineRunID,
            scope: scope
        ) else {
            throw Task126OwnerStoreGateError.replacementInterrupted
        }
        scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: ownerUserID,
            defaults: defaults,
            allowsPendingReplacement: true
        )
        let manifest = SyncStoreGenerationManifest(
            generationID: generationID,
            relativeStorePath: "generations/\(generationID.uuidString.lowercased())/store.sqlite",
            accountHash: scope.accountHash,
            shopID: scope.shopID,
            storeIdentity: scope.storeIdentity,
            deviceIdentityHash: scope.deviceIdentityHash,
            recoveryMode: .sameScopeRecovery,
            checkpointBeforeDownload: checkpoint,
            checkpoint: checkpoint,
            localVerification: makeReceipt(checkpoint: checkpoint),
            baselineRunID: baselineRunID
        )
        guard try bindingStore.commitActivatedGeneration(
            manifest,
            expectedLeaseGeneration: scope.leaseGeneration
        ) else {
            throw Task126OwnerStoreGateError.replacementInterrupted
        }
        scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: ownerUserID,
            defaults: defaults,
            allowsPendingReplacement: true
        )
        guard try bindingStore.completePendingReplacementRecovery(
            accountHash: scope.accountHash,
            storeIdentity: scope.storeIdentity,
            expectedLeaseGeneration: scope.leaseGeneration
        ) else {
            throw Task126OwnerStoreGateError.replacementInterrupted
        }
        if pauseAfterCompletion {
            await durableCompletionGate.open()
            await durableCompletionRelease.wait()
        }
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
            watermarkAfter: 12,
            activatedGenerationID: generationID,
            completedRecoveryJournal: true
        )
    }

    func waitUntilDurablyCompleted() async {
        await durableCompletionGate.wait()
    }

    func releaseAfterDurableCompletion() async {
        await durableCompletionRelease.open()
    }

    private func makeCheckpoint(
        scope: Task126VerifiedOwnerStoreScope,
        watermark: Int64
    ) -> ShopSyncRecoveryCheckpoint {
        let emptyDigest = ShopSyncRecoveryEntityDigest(
            activeCount: 0,
            tombstoneCount: 0,
            idSetDigest: String(repeating: "1", count: 64),
            versionDigest: String(repeating: "2", count: 64)
        )
        let productDigest = ShopSyncRecoveryEntityDigest(
            activeCount: 0,
            tombstoneCount: 0,
            idSetDigest: String(repeating: "1", count: 64),
            versionDigest: String(repeating: "2", count: 64),
            identityDigest: String(repeating: "3", count: 64)
        )
        return ShopSyncRecoveryCheckpoint(
            schemaVersion: "shop-sync-recovery-checkpoint-v1",
            shopId: scope.shopID,
            scope: ShopSyncRecoveryScope(
                kind: "shop_scoped",
                key: ShopSyncRecoveryCanonical.sha256(
                    scope.shopID.uuidString.lowercased()
                        + ":shop_scoped:-:"
                        + scope.deviceIdentityHash
                ),
                legacyOwnerKey: nil,
                accountKey: scope.accountHash,
                deviceKey: scope.deviceIdentityHash
            ),
            syncEvents: ShopSyncRecoveryEventCheckpoint(maxId: String(watermark)),
            catalog: ShopSyncRecoveryCatalogDigest(
                suppliers: emptyDigest,
                categories: emptyDigest,
                products: productDigest,
                digest: String(repeating: "5", count: 64)
            ),
            prices: emptyDigest,
            history: emptyDigest,
            images: emptyDigest,
            integrity: ShopSyncRecoveryIntegrity(
                productCategoryViolationCount: 0,
                productSupplierViolationCount: 0,
                priceProductViolationCount: 0,
                primaryImageViolationCount: 0,
                historyIdViolationCount: 0,
                totalViolationCount: 0
            ),
            checkpointDigest: String(repeating: "6", count: 64)
        )
    }

    private func makeReceipt(
        checkpoint: ShopSyncRecoveryCheckpoint
    ) -> ShopSyncRecoveryLocalVerificationReceipt {
        ShopSyncRecoveryLocalVerificationReceipt(
            suppliers: checkpoint.catalog.suppliers,
            categories: checkpoint.catalog.categories,
            products: checkpoint.catalog.products,
            prices: checkpoint.prices,
            history: checkpoint.history,
            images: checkpoint.images,
            catalogDigest: checkpoint.catalog.digest,
            relationshipViolationCount: 0,
            pendingLocalCount: 0,
            outboxCount: 0
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
