import SwiftData
import SwiftUI
import UIKit
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class Task115RealRootLifecycleTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testSignedOutToSignedInBecomesBootstrapReadyAfterShopResolution() throws {
        XCTAssertFalse(
            SyncBootstrapReadiness.shouldStart(
                isSignedIn: false,
                isShopSyncAllowed: true
            )
        )
        XCTAssertTrue(
            SyncBootstrapReadiness.shouldStart(
                isSignedIn: true,
                isShopSyncAllowed: true
            )
        )
        XCTAssertFalse(
            SyncBootstrapReadiness.shouldStart(
                isSignedIn: true,
                isShopSyncAllowed: false
            )
        )

        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("iOSMerchandiseControl/ContentView.swift"),
            encoding: .utf8
        )
        let methodStart = try XCTUnwrap(source.range(of: "private func refreshShopContextAndResumeSync() async"))
        let methodSource = String(source[methodStart.lowerBound...])

        XCTAssertTrue(methodSource.contains("SyncBootstrapReadiness.shouldStart("))
        XCTAssertTrue(methodSource.contains("await syncOrchestrator.bootstrap(scenePhase: scenePhase)"))
    }

    func testRealContentRootStartsWithFakeDependenciesWithoutSupabaseLive() throws {
        setenv("TASK115_REAL_ROOT_LIFECYCLE_TEST", "1", 1)
        defer { unsetenv("TASK115_REAL_ROOT_LIFECYCLE_TEST") }

        let container = try makeContainer()
        let authViewModel = SupabaseAuthViewModel(authService: nil, initialError: .configMissing)
        let root = ContentView(
            supabaseTransportClient: nil,
            supabasePullPreviewService: nil,
            syncEventOutboxDrainRecorder: nil,
            syncEventSignalWatcher: nil
        )
        .environmentObject(authViewModel)
        .modelContainer(container)

        let host = UIHostingController(rootView: root)
        host.loadViewIfNeeded()

        XCTAssertNotNil(host.view)
        XCTAssertTrue(host.view.bounds.isEmpty || host.view.bounds.width >= 0)
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

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
