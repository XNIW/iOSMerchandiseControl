import XCTest

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
}
