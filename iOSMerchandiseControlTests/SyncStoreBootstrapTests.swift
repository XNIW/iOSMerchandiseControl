import Foundation
import SwiftData
import SwiftUI
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class SyncStoreBootstrapTests: XCTestCase {
    private enum Fault: Error { case opening }
    /// Every test uses an isolated explicit physical URL and defaults suite, never the ordinary store.
    /// Fixture files are retained for the eventual native test owner to clean after quiescence proof.
    private func repository() throws -> SyncStoreGenerationRepository {
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
            .appendingPathComponent("task146-bootstrap-tests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "task146.bootstrap." + UUID().uuidString))
        return try SyncStoreGenerationRepository(baseDirectory: root.appendingPathComponent("generations-root"),
            legacyDefaultStoreURL: root.appendingPathComponent("business.store"), defaults: defaults)
    }
    private func releaseAndJoin(_ gate: BootstrapHeldLoader, bootstrap: SyncStoreBootstrap,
                                waiters: [Task<SyncStoreGenerationController, Error>]) async {
        await gate.release()
        if bootstrap.hasPhysicalFlight {
            // This cleanup join is independent of a cancelled test/waiter; it never cancels the worker.
            let terminal = Task.detached { @MainActor in _ = try? await bootstrap.waitUntilOpened() }
            await terminal.value
        }
        for waiter in waiters { _ = await waiter.result }
    }
    func testHeldPhysicalOpenerBuildsNoBusinessChildAndCoalescesAllWaiters() async throws {
        let repository = try repository(); let gate = BootstrapHeldLoader()
        let bootstrap = SyncStoreBootstrap(loader: {
            await gate.enter()
            return try SyncStoreOpenedGeneration.load(repository: repository, defaults: repository.defaults)
        })
        var businessChildren = 0; var shells = 0
        let boundary = SyncStoreBootstrapGate(bootstrap: bootstrap,
            opened: { _ in businessChildren += 1; return EmptyView() }, pending: { shells += 1; return EmptyView() })
        _ = boundary.body
        let foreground = Task { try await bootstrap.waitUntilOpened() }
        let background = Task { try await bootstrap.waitUntilOpened() }
        do {
            bootstrap.startIfNeeded(); bootstrap.startIfNeeded()
            await gate.waitUntilEntered()
            _ = boundary.body
            let calls = await gate.calls
            XCTAssertEqual(calls, 1); XCTAssertNil(bootstrap.controller)
            XCTAssertEqual(businessChildren, 0); XCTAssertEqual(shells, 2)
            await gate.release()
            let first = try await foreground.value; let second = try await background.value
            XCTAssertTrue(first === second); XCTAssertTrue(bootstrap.controller === first)
            let finalCalls = await gate.calls; XCTAssertEqual(finalCalls, 1)
            _ = boundary.body
            XCTAssertEqual(businessChildren, 1); XCTAssertEqual(bootstrap.phase, .opened)
        } catch {
            await releaseAndJoin(gate, bootstrap: bootstrap, waiters: [foreground, background]); throw error
        }
        await releaseAndJoin(gate, bootstrap: bootstrap, waiters: [foreground, background])
    }
    func testFailedOpeningConstructsNeitherFallbackContainerNorBusinessChild() async throws {
        let bootstrap = SyncStoreBootstrap(loader: { throw Fault.opening })
        do { _ = try await bootstrap.waitUntilOpened(); XCTFail("opening must fail") } catch { }
        var consumers = 0
        let boundary = SyncStoreBootstrapGate(bootstrap: bootstrap,
            opened: { _ in consumers += 1; return EmptyView() }, pending: { EmptyView() })
        _ = boundary.body
        XCTAssertNil(bootstrap.controller); XCTAssertEqual(consumers, 0)
        XCTAssertEqual(bootstrap.phase, .failed); XCTAssertTrue(bootstrap.canRetry)
        XCTAssertEqual(bootstrap.failureCode, "sync_store_generation_load_failed")
    }
    func testCancellingOneBackgroundWaiterDoesNotCancelSharedPhysicalOpenerOrForeground() async throws {
        let repository = try repository(); let gate = BootstrapHeldLoader()
        let bootstrap = SyncStoreBootstrap(loader: {
            await gate.enter()
            return try SyncStoreOpenedGeneration.load(repository: repository, defaults: repository.defaults)
        })
        let foreground = Task { try await bootstrap.waitUntilOpened() }
        await gate.waitUntilEntered()
        let registered = BootstrapWaiterRegistration()
        let background = Task {
            try await bootstrap.waitUntilOpened(onWaiterRegistered: { registered.signal() })
        }
        do {
            // Signal comes after continuation insertion; the held physical worker cannot complete it.
            await registered.wait()
            background.cancel()
            do { _ = try await background.value; XCTFail("cancelled registered waiter") } catch is CancellationError { }
            XCTAssertTrue(bootstrap.hasPhysicalFlight); XCTAssertNil(bootstrap.controller)
            let calls = await gate.calls; XCTAssertEqual(calls, 1)
            await gate.release()
            let opened = try await foreground.value
            XCTAssertTrue(bootstrap.controller === opened)
        } catch {
            await releaseAndJoin(gate, bootstrap: bootstrap, waiters: [foreground, background]); throw error
        }
        await releaseAndJoin(gate, bootstrap: bootstrap, waiters: [foreground, background])
    }
    func testWithdrawnAttemptCannotAdoptOrRetryBeforeTheWorkerTerminates() async throws {
        let repository = try repository(); let gate = BootstrapHeldLoader()
        let bootstrap = SyncStoreBootstrap(loader: {
            await gate.enter()
            return try SyncStoreOpenedGeneration.load(repository: repository, defaults: repository.defaults)
        })
        let first = Task { try await bootstrap.waitUntilOpened() }
        var terminal: Task<SyncStoreGenerationController, Error>?
        do {
            await gate.waitUntilEntered(); bootstrap.withdrawOpeningPublication()
            do { _ = try await first.value; XCTFail("withdrawn attempt") } catch is CancellationError { }
            XCTAssertTrue(bootstrap.hasPhysicalFlight); XCTAssertFalse(bootstrap.canRetry)
            bootstrap.retry(); bootstrap.startIfNeeded()
            let calls = await gate.calls; XCTAssertEqual(calls, 1)
            let last = Task { try await bootstrap.waitUntilOpened() }; terminal = last
            await gate.release()
            do { _ = try await last.value; XCTFail("stale result must not adopt") } catch { }
            XCTAssertNil(bootstrap.controller); XCTAssertEqual(bootstrap.phase, .failed)
            XCTAssertFalse(bootstrap.hasPhysicalFlight); XCTAssertTrue(bootstrap.canRetry)
        } catch {
            await releaseAndJoin(gate, bootstrap: bootstrap, waiters: [first] + (terminal.map { [$0] } ?? [])); throw error
        }
        await releaseAndJoin(gate, bootstrap: bootstrap, waiters: [first] + (terminal.map { [$0] } ?? []))
    }
    func testFailureDoesNotAutomaticallyRetryButExplicitRetryUsesOneSuccessor() async throws {
        let repository = try repository(); let counter = BootstrapAttemptCounter()
        let bootstrap = SyncStoreBootstrap(loader: {
            if await counter.next() == 1 { throw Fault.opening }
            return try SyncStoreOpenedGeneration.load(repository: repository, defaults: repository.defaults)
        })
        do { _ = try await bootstrap.waitUntilOpened(); XCTFail("first attempt") } catch { }
        bootstrap.startIfNeeded()
        let once = await counter.count; XCTAssertEqual(once, 1)
        bootstrap.retry()
        _ = try await bootstrap.waitUntilOpened()
        let twice = await counter.count; XCTAssertEqual(twice, 2)
        XCTAssertEqual(bootstrap.phase, .opened)
    }
    func testPreloadedContainerIsAdoptedExactlyOnceWithoutAnotherPhysicalOpen() async throws {
        let repository = try repository()
        let loaded = try await Task.detached {
            try SyncStoreOpenedGeneration.load(repository: repository, defaults: repository.defaults)
        }.value
        let controller = try SyncStoreGenerationController(adopting: loaded)
        XCTAssertEqual(ObjectIdentifier(controller.modelContainer), loaded.openedContainerIdentity)
        XCTAssertThrowsError(try SyncStoreGenerationController(adopting: loaded))
    }
    func testChangedManifestAndDefaultsMismatchFailBeforeAdoption() async throws {
        let repository = try repository()
        let foreign = try XCTUnwrap(UserDefaults(suiteName: "task146.bootstrap.foreign." + UUID().uuidString))
        XCTAssertThrowsError(try SyncStoreOpenedGeneration.load(repository: repository, defaults: foreign))
        let loaded = try await Task.detached {
            try SyncStoreOpenedGeneration.load(repository: repository, defaults: repository.defaults)
        }.value
        try Data("{".utf8).write(to: repository.manifestURL)
        XCTAssertThrowsError(try SyncStoreGenerationController(adopting: loaded))
    }
    func testRAMWorkbookParsingAndMappingRemainUsableWhilePhysicalOpeningIsHeld() async throws {
        let repository = try repository(); let gate = BootstrapHeldLoader()
        let bootstrap = SyncStoreBootstrap(loader: {
            await gate.enter()
            return try SyncStoreOpenedGeneration.load(repository: repository, defaults: repository.defaults)
        })
        let waiter = Task { try await bootstrap.waitUntilOpened() }; await gate.waitUntilEntered()
        do {
            let session = ExcelSessionViewModel()
            let file = repository.baseDirectory.deletingLastPathComponent().appendingPathComponent("workbook.html")
            try Data("<html><table><tr><th>Barcode</th><th>Product name</th><th>Purchase price</th><th>Quantity</th></tr><tr><td>8050000000001</td><td>Private fixture</td><td>12.50</td><td>2</td></tr></table></html>".utf8).write(to: file)
            try await session.load(from: [file])
            XCTAssertTrue(session.hasData); XCTAssertNil(session.currentHistoryEntry)
            XCTAssertTrue(session.rows.dropFirst().contains { $0.contains("8050000000001") })
            let nameColumn = try XCTUnwrap(session.normalizedHeader.firstIndex(of: "productName"))
            session.setColumnRole(at: nameColumn, to: "secondProductName")
            XCTAssertEqual(session.normalizedHeader[nameColumn], "secondProductName")
            session.supplierName = "RAM supplier"; session.categoryName = "RAM category"
            let rows = session.rows; let header = session.normalizedHeader; let selections = session.selectedColumns
            XCTAssertNil(bootstrap.controller)
            await gate.release(); _ = try await waiter.value
            XCTAssertEqual(session.rows, rows); XCTAssertEqual(session.normalizedHeader, header)
            XCTAssertEqual(session.selectedColumns, selections); XCTAssertEqual(session.supplierName, "RAM supplier")
            XCTAssertEqual(session.categoryName, "RAM category"); XCTAssertNil(session.currentHistoryEntry)
        } catch {
            await releaseAndJoin(gate, bootstrap: bootstrap, waiters: [waiter]); throw error
        }
        await releaseAndJoin(gate, bootstrap: bootstrap, waiters: [waiter])
    }
}

private actor BootstrapHeldLoader {
    private(set) var calls = 0
    private var entered: [CheckedContinuation<Void, Never>] = []
    private var held: [CheckedContinuation<Void, Never>] = []
    private var released = false
    func enter() async {
        calls += 1
        let pending = entered; entered.removeAll(); pending.forEach { $0.resume() }
        if !released { await withCheckedContinuation { held.append($0) } }
    }
    func waitUntilEntered() async {
        if calls > 0 { return }
        await withCheckedContinuation { entered.append($0) }
    }
    func release() { released = true; let pending = held; held.removeAll(); pending.forEach { $0.resume() } }
}
private actor BootstrapAttemptCounter {
    private(set) var count = 0
    func next() -> Int { count += 1; return count }
}

@MainActor
private final class BootstrapWaiterRegistration {
    private var registered = false
    private var continuation: CheckedContinuation<Void, Never>?
    func signal() { registered = true; continuation?.resume(); continuation = nil }
    func wait() async {
        if registered { return }
        await withCheckedContinuation { continuation = $0 }
    }
}
