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
}
