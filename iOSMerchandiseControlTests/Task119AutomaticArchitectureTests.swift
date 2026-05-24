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
            "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift",
            "iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift",
            "iOSMerchandiseControl/Sync/AutomaticPushServices.swift",
            "iOSMerchandiseControl/Sync/SyncOrchestrator.swift",
            "iOSMerchandiseControl/Sync/SyncDecisionEngine.swift",
            "iOSMerchandiseControl/Sync/SyncDecisionInputProvider.swift",
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
        let runtime = try source("iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift")

        XCTAssertFalse(engine.contains("@MainActor"), "AutomaticSyncEngine must keep non-UI work off MainActor")
        XCTAssertFalse(runtime.contains("activeTask"), "SyncAutomaticRuntime facade must not own placeholder single-flight state")
        XCTAssertTrue(engine.contains("AutomaticSyncSingleFlight"))
        XCTAssertTrue(engine.contains("AutomaticSyncCancellationPolicy"))
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
