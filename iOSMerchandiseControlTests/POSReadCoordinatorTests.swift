import Foundation
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class POSReadCoordinatorTests: XCTestCase {
    func testAuthorizedEnvelopeRequiredBeforeRenderingAndOfflineHidesImmediately() async throws {
        let x = try Fixture(); defer { x.stop() }
        XCTAssertNil(x.model.overview)
        try await x.completeFirst()
        XCTAssertEqual(x.model.overview?.summaryDays.first?.netRevenueClp.value, 100)
        x.model.update(scope: x.scope.value, network: .unsatisfied)
        XCTAssertNil(x.model.overview); XCTAssertFalse(x.model.salesReadAuthorized)
        XCTAssertFalse(x.model.salesReadNavigationPriority); XCTAssertEqual(x.model.notice, .offline)
    }
    func testOverviewSingleflightMinimumTwoSecondsAndForegroundVisibilityOnly() async throws {
        let x = try Fixture(); defer { x.stop() }; try await x.completeFirst()
        x.time.advance(to: 1.999); await settle()
        XCTAssertEqual(x.transport.calls.count, 1)
        x.time.advance(to: 2); await until { x.transport.calls.count == 2 }
        XCTAssertEqual(x.transport.calls[1].request.action, .summary)
        x.model.setForeground(false)
        XCTAssertEqual(x.transport.calls[1].flight.cancelCount, 1)
        x.transport.calls[1].flight.finish(.failure(CancellationError())); await settle()
        x.time.advance(to: 100); await settle(); XCTAssertEqual(x.transport.calls.count, 2)
        XCTAssertNil(x.model.overview)
    }
    func testCancelledOldScopeCannotPublishAndNoSuccessorBeforeQuiescence() async throws {
        let x = try Fixture(); defer { x.stop() }
        await until { x.transport.calls.first?.flight.waiting == true }
        let old = x.transport.calls[0].flight
        let next = try POSReadFixtures.scope(ownerID: UUID())
        x.scope.value = next; x.model.update(scope: next, network: .satisfied)
        XCTAssertEqual(old.cancelCount, 1); XCTAssertEqual(x.transport.calls.count, 1)
        old.finish(.success(try POSReadFixtures.reply(action: .summary)))
        await until { x.transport.calls.count == 2 }
        XCTAssertNil(x.model.overview); XCTAssertEqual(x.transport.calls[1].scope, next)
    }
    func testDeadlineRejectsLateSuccessAndBackoffKeepsOriginalTimeBudget() async throws {
        let x = try Fixture(); defer { x.stop() }
        await until { x.transport.calls.first?.flight.waiting == true }
        XCTAssertEqual(x.transport.calls[0].deadline, 2)
        x.time.advance(to: 2); await until { x.transport.calls[0].flight.cancelCount == 1 }
        XCTAssertEqual(x.model.notice, .timeout)
        x.time.advance(to: 2.1)
        x.transport.calls[0].flight.finish(.success(try POSReadFixtures.reply(action: .summary)))
        await until { !x.model.isBusy }
        XCTAssertNil(x.model.overview)
        x.time.advance(to: 5.999); await settle(); XCTAssertEqual(x.transport.calls.count, 1)
        x.time.advance(to: 6); await until { x.transport.calls.count == 2 }
    }
    func testTransportStillHeldOneSecondAfterCancelBecomesStalledForever() async throws {
        let x = try Fixture(); defer { x.stop() }
        await until { x.transport.calls.first?.flight.waiting == true }
        x.time.advance(to: 2); await until { x.transport.calls[0].flight.cancelCount == 1 }
        x.time.advance(to: 3); await until { x.model.isStalled }
        x.transport.calls[0].flight.finish(.success(try POSReadFixtures.reply(action: .summary)))
        x.model.retry(); x.time.advance(to: 100); await settle()
        XCTAssertTrue(x.model.isStalled); XCTAssertEqual(x.model.notice, .stalled)
        XCTAssertEqual(x.transport.calls.count, 1); XCTAssertNil(x.model.overview)
    }
    func testRevocationWithdrawsFinancialCapabilityAndStopsPoll() async throws {
        let x = try Fixture(); defer { x.stop() }; try await x.completeFirst()
        x.time.advance(to: 2); await until { x.transport.calls.count == 2 }
        x.transport.calls[1].flight.finish(.failure(POSReadError.denied("device_not_authorized")))
        await until { !x.model.isBusy }
        XCTAssertNil(x.model.overview); XCTAssertFalse(x.model.salesReadNavigationPriority)
        x.time.advance(to: 100); await settle(); XCTAssertEqual(x.transport.calls.count, 2)
    }
    func testHTTP500KeepsAuthorizedSnapshotWithoutRenewingFetchedAt() async throws {
        let x = try Fixture(); defer { x.stop() }; try await x.completeFirst()
        let fetched = x.model.overview?.fetchedAt
        x.time.advance(to: 2); await until { x.transport.calls.count == 2 }
        x.transport.calls[1].flight.finish(.failure(POSReadError.http(500, retryAfter: 20)))
        await until { !x.model.isBusy }
        XCTAssertEqual(x.model.overview?.fetchedAt, fetched)
        x.time.advance(to: 21.999); await settle(); XCTAssertEqual(x.transport.calls.count, 2)
        x.time.advance(to: 22); await until { x.transport.calls.count == 3 }
    }
    func testHistoryReconnectStagesNewDataAndPreservesDeepAnchorSelectionAndRows() async throws {
        let x = try Fixture(); defer { x.stop() }; try await x.completeFirst()
        x.model.showHistory(try POSReadFixtures.period())
        await until { x.transport.calls.count == 2 }
        XCTAssertEqual(x.transport.calls[1].deadline, 8)
        x.transport.calls[1].flight.finish(.success(try POSReadFixtures.reply(action: .summary, indices: [0, 1])))
        await until { !x.model.isBusy }
        x.model.anchorID = POSReadFixtures.id(1); x.model.selectedSaleID = POSReadFixtures.id(1)
        let original = x.model.history?.sales.map(\.id)
        x.model.update(scope: x.scope.value, network: .unsatisfied)
        x.model.update(scope: x.scope.value, network: .satisfied)
        await until { x.transport.calls.count == 3 }
        x.transport.calls[2].flight.finish(.success(try POSReadFixtures.reply(action: .summary, indices: [2], total: "150")))
        await until { !x.model.isBusy }
        XCTAssertTrue(x.model.hasNewHistory); XCTAssertEqual(x.model.history?.sales.map(\.id), original)
        XCTAssertEqual(x.model.anchorID, POSReadFixtures.id(1)); XCTAssertEqual(x.model.selectedSaleID, POSReadFixtures.id(1))
    }
    func testViewerDowngradeCannotReauthorizeCachedOwnerMetadataDuringHistoryStage() async throws {
        let x = try Fixture(); defer { x.stop() }
        var envelope = POSReadFixtures.envelope(action: .summary)
        envelope["capability"] = ["sales_read": true, "operational_metadata_read": true, "access_policy": "online_only"]
        var data = envelope["data"] as! [String: Any]; var rows = data["sales"] as! [[String: Any]]
        rows[0]["staff_name"] = "Owner-only staff"; rows[0]["device_name"] = "Owner-only device"
        data["sales"] = rows; envelope["data"] = data
        let owner = try POSReadDecoder.decode(POSReadFixtures.bytes(envelope), request: POSReadRequest(action: .summary), scope: POSReadFixtures.scope())
        await until { x.transport.calls.first?.flight.waiting == true }
        x.transport.calls[0].flight.finish(.success(owner)); await until { !x.model.isBusy }
        x.model.showHistory(try POSReadFixtures.period()); await until { x.transport.calls.count == 2 }
        x.transport.calls[1].flight.finish(.success(owner)); await until { !x.model.isBusy }
        XCTAssertEqual(x.model.history?.sales[0].staffName, "Owner-only staff")
        x.model.update(scope: x.scope.value, network: .unsatisfied); x.model.update(scope: x.scope.value, network: .satisfied)
        await until { x.transport.calls.count == 3 }
        x.transport.calls[2].flight.finish(.success(try POSReadFixtures.reply(action: .summary)))
        await until { !x.model.isBusy }
        XCTAssertNotNil(x.model.history); XCTAssertNil(x.model.history?.sales[0].staffName)
        XCTAssertNil(x.model.history?.sales[0].deviceName); XCTAssertFalse(x.model.canReadMetadata)
    }
    func testPaginationCommitsOnlyAcceptedCursorAndFilterEpochRejectsLatePage() async throws {
        let x = try Fixture(); defer { x.stop() }; try await x.completeFirst()
        x.model.showHistory(try POSReadFixtures.period()); await until { x.transport.calls.count == 2 }
        x.transport.calls[1].flight.finish(.success(try POSReadFixtures.reply(action: .summary, indices: [0])))
        await until { !x.model.isBusy }
        x.model.loadMore(); await until { x.transport.calls.count == 3 }
        let old = x.transport.calls[2]
        XCTAssertEqual(old.request.cursor?.beforeSaleId, POSReadFixtures.id(0))
        x.model.showOverview()
        old.flight.finish(.success(try POSReadFixtures.reply(action: .page, indices: [1], cursor: old.request.cursor)))
        await settle()
        XCTAssertEqual(x.model.history?.sales.map(\.id), [POSReadFixtures.id(0)])
        XCTAssertEqual(x.model.history?.cursor?.beforeSaleId, POSReadFixtures.id(0))
    }

    private func settle() async { for _ in 0..<12 { await Task.yield() } }
    private func until(_ ready: @MainActor () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<512 { if ready() { return }; await Task.yield() }
        XCTFail("Deterministic event did not arrive", file: file, line: line)
    }
    private final class ScopeBox { var value: POSReadScope?; init(_ value: POSReadScope) { self.value = value } }
    @MainActor
    private final class Fixture {
        let time = POSManualTime()
        let transport = POSControlledTransport()
        let scope: ScopeBox
        let model: POSReadViewModel
        init() throws {
            let scope = ScopeBox(try POSReadFixtures.scope()); self.scope = scope
            model = POSReadViewModel(transport: transport, clock: time.clock, currentAuthority: { $0 == scope.value }, jitter: { 0 })
            model.update(scope: scope.value, network: .satisfied); model.setForeground(true); model.setVisible(true)
        }
        func completeFirst() async throws {
            for _ in 0..<512 { if transport.calls.first?.flight.waiting == true { break }; await Task.yield() }
            try XCTUnwrap(transport.calls.first).flight.finish(.success(POSReadFixtures.reply(action: .summary)))
            for _ in 0..<512 { if !model.isBusy { break }; await Task.yield() }
            XCTAssertFalse(model.isBusy)
        }
        func stop() { model.shutdown(); transport.calls.forEach { $0.flight.finish(.failure(CancellationError())) } }
    }
}

@MainActor
private final class POSControlledTransport: POSReadTransport {
    struct Call { let request: POSReadRequest; let scope: POSReadScope; let deadline: TimeInterval; let flight: POSControlledFlight }
    var calls: [Call] = []
    func start(_ request: POSReadRequest, scope: POSReadScope, deadline: TimeInterval) throws -> any POSReadFlight {
        let flight = POSControlledFlight(); calls.append(Call(request: request, scope: scope, deadline: deadline, flight: flight)); return flight
    }
}
@MainActor
private final class POSControlledFlight: POSReadFlight {
    var isQuiescent = false
    var cancelCount = 0
    var waiting = false
    private var result: Result<POSReadReply, Error>?
    private var continuation: CheckedContinuation<POSReadReply, Error>?
    func response() async throws -> POSReadReply {
        if let result { return try result.get() }
        return try await withCheckedThrowingContinuation { continuation = $0; waiting = true }
    }
    func cancel() { cancelCount += 1 } // Deliberately held until finish: cancellation is not release.
    func finish(_ result: Result<POSReadReply, Error>) {
        guard self.result == nil else { return }
        isQuiescent = true; self.result = result; continuation?.resume(with: result); continuation = nil
    }
}
nonisolated private final class POSManualTime: @unchecked Sendable {
    private let lock = NSLock()
    private var value: TimeInterval = 0
    private var waits: [UUID: (TimeInterval, CheckedContinuation<Void, Error>)] = [:]
    private var cancelled = Set<UUID>()
    var clock: POSReadClock {
        POSReadClock(now: { self.lock.withLock { self.value } }, sleepUntil: { deadline in
            let id = UUID()
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in self.install(id, at: deadline, continuation: continuation) }
            } onCancel: { self.cancel(id) }
        })
    }
    func advance(to now: TimeInterval) {
        let ready = lock.withLock { () -> [CheckedContinuation<Void, Error>] in
            precondition(now >= value); value = now
            let ids = waits.filter { $0.value.0 <= now }.map(\.key)
            return ids.compactMap { waits.removeValue(forKey: $0)?.1 }
        }
        ready.forEach { $0.resume() }
    }
    private func install(_ id: UUID, at deadline: TimeInterval, continuation: CheckedContinuation<Void, Error>) {
        let immediate = lock.withLock { () -> Result<Void, Error>? in
            if cancelled.remove(id) != nil { return .failure(CancellationError()) }
            if deadline <= value { return .success(()) }
            waits[id] = (deadline, continuation); return nil
        }
        if let immediate { continuation.resume(with: immediate) }
    }
    private func cancel(_ id: UUID) {
        let continuation = lock.withLock { () -> CheckedContinuation<Void, Error>? in
            if let wait = waits.removeValue(forKey: id) { return wait.1 }
            cancelled.insert(id); return nil
        }
        continuation?.resume(throwing: CancellationError())
    }
}
