import Foundation
import XCTest
@testable import iOSMerchandiseControl

// Actual URLSession callbacks with session-local URLProtocol interception.
// No real network, credentials, Supabase or SDK execution is used by these tests.
final class POSReadHTTPTests: XCTestCase {
    func testCancelWaitsForTaskCompletionAndSessionInvalidationWithinOneSecond() async throws {
        let started = expectation(description: "protocol entered")
        let stopped = expectation(description: "actual protocol stopped")
        let invalidated = expectation(description: "actual session invalidated")
        let fixture = POSHTTPFixture.register(mode: .held, started: { started.fulfill() }, stopped: { stopped.fulfill() })
        defer { POSHTTPFixture.remove(fixture) }
        let exchange = POSHTTPExchange(request: POSHTTPFixture.request(fixture), maximumBytes: 64,
                                       configuration: POSHTTPFixture.configuration(), onInvalidation: { invalidated.fulfill() })
        let operation = Task { try await exchange.load() }
        await fulfillment(of: [started], timeout: 1)
        operation.cancel()
        await fulfillment(of: [stopped, invalidated], timeout: 1)
        let proof = exchange.releaseProof
        XCTAssertNotNil(proof.cancelledAt); XCTAssertNotNil(proof.completedAt); XCTAssertNotNil(proof.invalidatedAt)
        if let cancelled = proof.cancelledAt, let completed = proof.completedAt, let invalidated = proof.invalidatedAt {
            XCTAssertGreaterThanOrEqual(completed, cancelled)
            XCTAssertGreaterThanOrEqual(invalidated, completed)
            XCTAssertLessThanOrEqual(invalidated - cancelled, 1)
            do { _ = try await operation.value; XCTFail("cancelled read succeeded") } catch { XCTAssertTrue(error is CancellationError) }
        } else { operation.cancel() } // Never await a held operation after a failed release oracle.
    }
    func testHTTP401RemainsHTTPFailureAfterRealSessionRelease() async throws {
        let invalidated = expectation(description: "401 invalidated")
        let fixture = POSHTTPFixture.register(mode: .reply(status: 401, bytes: Data()), started: {}, stopped: {})
        defer { POSHTTPFixture.remove(fixture) }
        let exchange = POSHTTPExchange(request: POSHTTPFixture.request(fixture), maximumBytes: 64,
                                       configuration: POSHTTPFixture.configuration(), onInvalidation: { invalidated.fulfill() })
        let operation = Task { try await exchange.load() }
        await fulfillment(of: [invalidated], timeout: 1)
        guard exchange.releaseProof.invalidatedAt != nil else { operation.cancel(); return }
        do { _ = try await operation.value; XCTFail("401 succeeded") }
        catch { guard let failure = error as? POSReadError, case .http(401, _) = failure else { return XCTFail("401 classification lost") } }
        XCTAssertNotNil(exchange.releaseProof.completedAt)
    }
    func testChunkedOversizeBodyFailsClosedAndReleasesActualSession() async throws {
        let invalidated = expectation(description: "oversize invalidated")
        let fixture = POSHTTPFixture.register(mode: .reply(status: 200, bytes: Data(repeating: 65, count: 65)), started: {}, stopped: {})
        defer { POSHTTPFixture.remove(fixture) }
        let exchange = POSHTTPExchange(request: POSHTTPFixture.request(fixture), maximumBytes: 64,
                                       configuration: POSHTTPFixture.configuration(), onInvalidation: { invalidated.fulfill() })
        let operation = Task { try await exchange.load() }
        await fulfillment(of: [invalidated], timeout: 1)
        guard exchange.releaseProof.invalidatedAt != nil else { operation.cancel(); return }
        do { _ = try await operation.value; XCTFail("oversize succeeded") }
        catch { XCTAssertEqual(error as? POSReadError, .invalidPayload) }
        XCTAssertNotNil(exchange.releaseProof.completedAt)
    }
}

nonisolated private enum POSHTTPFixture {
    enum Mode: Sendable { case held, reply(status: Int, bytes: Data) }
    struct Entry: Sendable { let mode: Mode; let started: @Sendable () -> Void; let stopped: @Sendable () -> Void }
    final class Registry: @unchecked Sendable {
        let lock = NSLock()
        var entries: [UUID: Entry] = [:]
    }
    static let registry = Registry()
    static func register(mode: Mode, started: @escaping @Sendable () -> Void, stopped: @escaping @Sendable () -> Void) -> UUID {
        let id = UUID(); registry.lock.withLock { registry.entries[id] = Entry(mode: mode, started: started, stopped: stopped) }; return id
    }
    static func remove(_ id: UUID) { _ = registry.lock.withLock { registry.entries.removeValue(forKey: id) } }
    static func entry(_ url: URL?) -> Entry? {
        guard let url, let id = UUID(uuidString: url.lastPathComponent) else { return nil }
        return registry.lock.withLock { registry.entries[id] }
    }
    static func request(_ id: UUID) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://task146-pos.invalid/\(id.uuidString)")!); request.timeoutInterval = 8; return request
    }
    static func configuration() -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [POSFixtureURLProtocol.self]; return config
    }
}
nonisolated private final class POSFixtureURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "task146-pos.invalid" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        guard let entry = POSHTTPFixture.entry(request.url), let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL)); return
        }
        entry.started()
        switch entry.mode {
        case .held: break
        case let .reply(status, bytes):
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if !bytes.isEmpty { client?.urlProtocol(self, didLoad: bytes) }
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() { POSHTTPFixture.entry(request.url)?.stopped() }
}
