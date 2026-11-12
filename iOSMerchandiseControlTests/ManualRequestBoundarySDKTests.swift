import Foundation
import Supabase
import XCTest
@testable import iOSMerchandiseControl

/// Same SDK auth session + same URLSession. All HTTP is synthetic and contained
/// by URLProtocol; these tests do not establish native TEST acceptance.
@MainActor
final class ManualRequestBoundarySDKTests: XCTestCase {
    func testActualPriceSDKBodyIsPersistableByteForByteImmediatelyBeforeSingleHTTP() async throws {
        let f = try ManualBoundaryFixture(); defer { f.close() }
        let payload = f.payload(); f.recorder.response = try f.priceResponse(payload)
        let witness = ManualBoundaryWitness()
        let rows = try await invoke(f, payload: payload) { request in
            witness.calls += 1
            witness.body = request.httpBody
            witness.path = request.url?.path
            XCTAssertEqual(f.recorder.requests.count, 0, "CAS callback precedes actual HTTP ingress")
        }
        XCTAssertEqual(rows.map(\.id), [payload.id])
        XCTAssertEqual(witness.calls, 1)
        XCTAssertEqual(f.recorder.requests.count, 1)
        let request = try XCTUnwrap(f.recorder.requests.first)
        XCTAssertEqual(request.url?.path, "/rest/v1/inventory_product_prices")
        XCTAssertEqual(witness.path, request.url?.path)
        XCTAssertEqual(try body(request), try XCTUnwrap(witness.body), "Persist exact SDK bytes, do not re-encode an equivalent object")
        let objects = try XCTUnwrap(JSONSerialization.jsonObject(with: body(request)) as? [[String: Any]])
        XCTAssertEqual(objects.count, 1)
        XCTAssertEqual(objects[0]["id"] as? String, payload.id.uuidString)
        XCTAssertEqual(objects[0]["shop_id"] as? String, f.shopID.uuidString)
        XCTAssertEqual(objects[0]["price"] as? Double, payload.price)
        XCTAssertFalse(try XCTUnwrap(witness.body).isEmpty)
    }

    func testFinalAuthOwnerMismatchDoesNotReachCASOrBusinessHTTP() async throws {
        let f = try ManualBoundaryFixture(sdkOwner: UUID()); defer { f.close() }
        let witness = ManualBoundaryWitness()
        do { _ = try await invoke(f, payload: f.payload()) { _ in witness.calls += 1 }; XCTFail("Wrong owner admitted") }
        catch let error as LocalPendingManualDispatchError {
            guard case .staleBatch = error else { return XCTFail("Unexpected denial") }
        }
        XCTAssertEqual(witness.calls, 0)
        XCTAssertEqual(f.recorder.requests.count, 0)
    }

    func testFinalHeldRefreshShopChangeRejectsBeforeCASAndBusinessHTTP() async throws {
        let f = try ManualBoundaryFixture(expiredSession: true); defer { f.close() }
        let stores = f.stores, recorder = f.recorder, witness = ManualBoundaryWitness()
        let next = SelectedShop(shopID: UUID(), code: "NEXT", name: "Next", role: "owner", status: "active", selectable: true, canWrite: true)
        recorder.authResponseHook = {
            recorder.authHookObserved = stores.selected.save(next, accountHash: stores.accountHash) &&
                stores.binding.saveBinding(accountHash: stores.accountHash, storeIdentity: next.localStoreIdentity)
        }
        let pending = Task { @MainActor in
            recorder.queryInvocationObserved = true
            return try await invokeBoundaryDirect(f, witness: witness) { _ in witness.calls += 1 }
        }
        defer { pending.cancel(); recorder.releaseAuthResponse() }
        try await awaitHeld(recorder, witness: witness)
        XCTAssertEqual(witness.calls, 0)
        recorder.releaseAuthResponse()
        do { _ = try await pending.value; XCTFail("Changed shop admitted") }
        catch let error as Task126OwnerStoreGateError { XCTAssertEqual(error, .scopeChanged) }
        XCTAssertTrue(recorder.authHookObserved)
        XCTAssertEqual(witness.calls, 0)
        XCTAssertEqual(recorder.requests.filter { $0.url?.path == "/auth/v1/token" }.count, 1)
        XCTAssertEqual(recorder.requests.filter { $0.url?.path.hasPrefix("/rest/v1/") == true }.count, 0)
    }

    func testRetiredGenerationDuringFinalHeldRefreshNeverDispatches() async throws {
        let f = try ManualBoundaryFixture(expiredSession: true); defer { f.close() }
        let recorder = f.recorder, witness = ManualBoundaryWitness()
        let pending = Task { @MainActor in
            recorder.queryInvocationObserved = true
            return try await invokeBoundaryDirect(f, witness: witness) { _ in witness.calls += 1 }
        }
        defer { pending.cancel(); recorder.releaseAuthResponse() }
        try await awaitHeld(recorder, witness: witness)
        let old = f.provider.authSnapshot.generation
        _ = try await f.provider.prepareInteractiveSignIn()
        XCTAssertNotEqual(f.provider.authSnapshot.generation, old)
        recorder.releaseAuthResponse()
        do { _ = try await pending.value; XCTFail("Retired generation admitted") }
        catch is CancellationError { }
        catch let error as LocalPendingManualDispatchError {
            guard case .staleBatch = error else { return XCTFail("Unexpected denial") }
        }
        XCTAssertEqual(witness.calls, 0)
        XCTAssertEqual(recorder.requests.filter { $0.url?.path.hasPrefix("/rest/v1/") == true }.count, 0)
    }

    func testDurableCASCallbackFailurePreventsHTTP() async throws {
        let f = try ManualBoundaryFixture(); defer { f.close() }
        let witness = ManualBoundaryWitness()
        do { _ = try await invoke(f, payload: f.payload()) { request in
            witness.calls += 1; witness.body = request.httpBody
            throw ManualBoundarySentinel.casRejected
        }; XCTFail("CAS failure was ignored") }
        catch ManualBoundarySentinel.casRejected { }
        XCTAssertEqual(witness.calls, 1)
        XCTAssertNotNil(witness.body)
        XCTAssertEqual(f.recorder.requests.count, 0)
    }

    func testAmbiguousTransportFailureDoesNotReplayOrProduceRows() async throws {
        let f = try ManualBoundaryFixture(); defer { f.close() }
        f.recorder.transportError = URLError(.timedOut)
        let witness = ManualBoundaryWitness()
        do { _ = try await invoke(f, payload: f.payload()) { _ in witness.calls += 1 }; XCTFail("Ambiguous failure produced rows") }
        catch let error as SupabaseTransportClientError {
            guard case .networkError = error else { return XCTFail("Network classification changed") }
        }
        XCTAssertEqual(witness.calls, 1)
        XCTAssertEqual(f.recorder.requests.count, 1)
    }

    func testWrongShopReturnedPriceDoesNotBecomeAcknowledgement() async throws {
        let f = try ManualBoundaryFixture(); defer { f.close() }
        let payload = f.payload(); f.recorder.response = try f.priceResponse(payload, shop: UUID())
        let witness = ManualBoundaryWitness()
        do { _ = try await invoke(f, payload: payload) { _ in witness.calls += 1 }; XCTFail("Wrong shop row acknowledged") }
        catch let error as LocalPendingManualDispatchError {
            guard case .staleBatch = error else { return XCTFail("Unexpected denial") }
        }
        XCTAssertEqual(witness.calls, 1)
        XCTAssertEqual(f.recorder.requests.count, 1)
    }

    func testManualPriceUniqueConflictKeepsExistingClassifierAndDoesNotRetry() async throws {
        let f = try ManualBoundaryFixture(); defer { f.close() }
        f.recorder.status = 409
        f.recorder.response = Data(#"{"code":"23505","message":"duplicate key","details":null,"hint":null}"#.utf8)
        let witness = ManualBoundaryWitness()
        do { _ = try await invoke(f, payload: f.payload()) { _ in witness.calls += 1 }; XCTFail("Duplicate unexpectedly succeeded") }
        catch let error as ProductPriceManualPushError {
            guard case .uniqueConflict = error else { return XCTFail("Manual classifier changed") }
        }
        XCTAssertEqual(witness.calls, 1)
        XCTAssertEqual(f.recorder.requests.count, 1)
    }

    func testCancellationDuringFinalHeldAuthNeverRunsCASOrBusinessHTTP() async throws {
        let f = try ManualBoundaryFixture(expiredSession: true); defer { f.close() }
        let recorder = f.recorder, witness = ManualBoundaryWitness()
        let pending = Task { @MainActor in
            try await invokeBoundaryDirect(f, witness: witness) { _ in witness.calls += 1 }
        }
        defer { pending.cancel(); recorder.releaseAuthResponse() }
        try await awaitHeld(recorder, witness: witness)
        pending.cancel()
        recorder.releaseAuthResponse()
        do { _ = try await pending.value; XCTFail("Cancelled request dispatched") }
        catch is CancellationError { }
        XCTAssertEqual(witness.calls, 0)
        XCTAssertEqual(recorder.requests.filter { $0.url?.path.hasPrefix("/rest/v1/") == true }.count, 0)
    }

    private func invokeBoundaryDirect(_ f: ManualBoundaryFixture, witness: ManualBoundaryWitness,
        callback: @escaping @MainActor @Sendable (URLRequest) throws -> Void) async throws -> Data {
        let snapshot = f.provider.authSnapshot
        var request = URLRequest(url: snapshot.client.schema("public").configuration.url.appendingPathComponent("inventory_product_prices"))
        request.httpMethod = "POST"
        request.httpBody = try PostgrestClient.Configuration.jsonEncoder.encode([f.payload()])
        return try await Task126OwnerStoreGate.withAutomaticScope(f.scope) {
            let (data, _) = try await f.provider.performManualRequest(request, snapshot: snapshot, scope: f.scope,
                validateScope: {
                    try f.validateScope()
                    witness.initialValidations += 1
                }, beforeDispatch: callback)
            return data
        }
    }

    private func invoke(_ f: ManualBoundaryFixture, payload: ProductPriceManualPushPayload,
        callback: @escaping @MainActor @Sendable (URLRequest) throws -> Void) async throws -> [RemoteInventoryProductPriceRow] {
        let adapter = f.adapter()
        return try await Task126OwnerStoreGate.withAutomaticScope(f.scope) {
            try await ManualPendingAtomicDispatchContext.$beforeDispatch.withValue(callback) {
                try await adapter.insertProductPriceManualPushPayloads([payload])
            }
        }
    }
    private func awaitHeld(_ recorder: ManualBoundaryRecorder, witness: ManualBoundaryWitness) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !(witness.initialValidations == 1 && recorder.authResponseWaiting) && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertEqual(witness.initialValidations, 1, "Actual provider pre-auth validation must have completed before changing scope")
        XCTAssertTrue(recorder.authResponseWaiting)
    }
    private func body(_ request: URLRequest) throws -> Data {
        if let data = request.httpBody { return data }
        let stream = try XCTUnwrap(request.httpBodyStream); stream.open(); defer { stream.close() }
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let n = stream.read(&buffer, maxLength: buffer.count)
            if n == 0 { return data }
            guard n > 0 else { throw stream.streamError ?? URLError(.cannotDecodeRawData) }
            data.append(contentsOf: buffer.prefix(n))
        }
    }
}
@MainActor private final class ManualBoundaryWitness { var calls = 0; var initialValidations = 0; var body: Data?; var path: String? }
nonisolated private enum ManualBoundarySentinel: Error { case casRejected }

@MainActor
private final class ManualBoundaryFixture {
    let ownerID = UUID(), shopID = UUID(), rowID = UUID()
    let recorder: ManualBoundaryRecorder
    let provider: SupabaseClientProvider
    let scope: Task126VerifiedOwnerStoreScope
    let stores: ManualBoundaryStores
    private let suiteName: String
    private let defaults: UserDefaults
    private let host: String
    private let session: URLSession
    init(sdkOwner: UUID? = nil, expiredSession: Bool = false) throws {
        recorder = ManualBoundaryRecorder(response: Data("[]".utf8), holdAuthResponse: expiredSession)
        suiteName = "ManualCatalogScopeSDKTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let selected = SelectedShop(shopID: shopID, code: "R4", name: "Dedicated test shop", role: "owner", status: "active", selectable: true, canWrite: true)
        let accountHash = AccountBindingStore.accountHash(for: ownerID)
        stores = ManualBoundaryStores(selected: SelectedShopStore(defaults: defaults), binding: AccountBindingStore(defaults: defaults), accountHash: accountHash)
        stores.selected.noteActiveAccount(accountHash)
        guard stores.selected.save(selected, accountHash: accountHash), stores.binding.saveBinding(accountHash: accountHash, storeIdentity: selected.localStoreIdentity) else { throw URLError(.cannotCreateFile) }
        _ = try DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID()
        scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: ownerID, defaults: defaults)
        host = "manual-scope-\(UUID().uuidString.lowercased()).example.invalid"
        ManualBoundaryURLProtocol.registry.register(host, recorder: recorder)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ManualBoundaryURLProtocol.self]
        session = URLSession(configuration: configuration)
        let storage = ManualBoundaryMemoryStorage()
        let user = User(id: sdkOwner ?? ownerID, appMetadata: [:], userMetadata: [:], aud: "authenticated", createdAt: Date(), updatedAt: Date())
        let stored = Session(accessToken: "manual-synthetic-access", tokenType: "bearer", expiresIn: 3600,
            expiresAt: Date().timeIntervalSince1970 + (expiredSession ? -3600 : 3600), refreshToken: "manual-synthetic-refresh", user: user)
        try storage.store(key: "sb-\(host.split(separator: ".")[0])-auth-token", value: JSONEncoder().encode(stored))
        if expiredSession {
            let refreshed = Session(accessToken: "manual-synthetic-refreshed", tokenType: "bearer", expiresIn: 3600,
                expiresAt: Date().timeIntervalSince1970 + 3600, refreshToken: "manual-synthetic-refresh", user: user)
            recorder.authResponse = try AuthClient.Configuration.jsonEncoder.encode(refreshed)
        }
        provider = SupabaseClientProvider(config: .init(projectURL: URL(string: "https://\(host)")!, publishableKey: "manual-synthetic-publishable", productImageAPIBaseURL: nil), authStorage: storage, session: session, autoRefreshToken: false, authRegistry: SupabaseAuthClientRegistry())
    }
    func validateScope() throws { try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults) }
    func adapter() -> ProductPriceManualPushRemoteSupabaseAdapter {
        let box = ManualBoundaryDefaults(value: defaults)
        return ProductPriceManualPushRemoteSupabaseAdapter(remote: SupabaseTransportClient(clientProvider: provider),
            manualScope: { try Task126OwnerStoreGate.requireCurrentAutomaticScope(defaults: box.value) })
    }
    func payload() -> ProductPriceManualPushPayload {
        .init(id: rowID, ownerUserID: ownerID, shopID: shopID, productID: UUID(), type: "retail",
            price: 12.25, priceCanonical: "12.25", effectiveAt: "2026-10-23T12:34:56.123Z", source: "manual", note: nil,
            createdAt: "2026-10-23T12:34:56.123Z")
    }
    func priceResponse(_ payload: ProductPriceManualPushPayload, shop: UUID? = nil) throws -> Data {
        let row: [String: Any] = ["id": payload.id.uuidString, "owner_user_id": ownerID.uuidString,
            "shop_id": (shop ?? shopID).uuidString, "product_id": payload.productID.uuidString,
            "type": payload.type, "price": payload.price, "effective_at": payload.effectiveAt,
            "source": payload.source.map { $0 as Any } ?? NSNull(), "note": NSNull(), "created_at": payload.createdAt,
            "updated_at": "2026-10-23T12:34:57.123456Z"]
        return try JSONSerialization.data(withJSONObject: [row])
    }
    func close() { recorder.releaseAuthResponse(); session.invalidateAndCancel(); ManualBoundaryURLProtocol.registry.remove(host); defaults.removePersistentDomain(forName: suiteName) }
}
nonisolated private struct ManualBoundaryStores: Sendable {
    let selected: SelectedShopStore
    let binding: AccountBindingStore
    let accountHash: String
}

nonisolated private final class ManualBoundaryMemoryStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}

nonisolated private final class ManualBoundaryRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    private var responseValue: Data
    private var statusValue = 200
    private var errorValue: URLError?
    private var authResponseValue: Data?
    private var authHookValue: (@Sendable () -> Void)?
    private var businessHookValue: (@Sendable () -> Void)?
    private var authHookValueObserved = false
    private var queryInvocationValue = false
    private let authGate: ManualBoundaryAuthResponseGate
    var requests: [URLRequest] { lock.withLock { recorded } }
    var queryInvocationObserved: Bool { get { lock.withLock { queryInvocationValue } } set { lock.withLock { queryInvocationValue = newValue } } }
    var authResponseWaiting: Bool { authGate.isWaiting }
    func releaseAuthResponse() { authGate.release() }
    var authHookObserved: Bool { get { lock.withLock { authHookValueObserved } } set { lock.withLock { authHookValueObserved = newValue } } }
    var response: Data { get { lock.withLock { responseValue } } set { lock.withLock { responseValue = newValue } } }
    var status: Int { get { lock.withLock { statusValue } } set { lock.withLock { statusValue = newValue } } }
    var transportError: URLError? { get { lock.withLock { errorValue } } set { lock.withLock { errorValue = newValue } } }
    var authResponse: Data? { get { lock.withLock { authResponseValue } } set { lock.withLock { authResponseValue = newValue } } }
    var authResponseHook: (@Sendable () -> Void)? { get { lock.withLock { authHookValue } } set { lock.withLock { authHookValue = newValue } } }
    var businessResponseHook: (@Sendable () -> Void)? { get { lock.withLock { businessHookValue } } set { lock.withLock { businessHookValue = newValue } } }
    init(response: Data, holdAuthResponse: Bool = false) {
        responseValue = response
        authGate = ManualBoundaryAuthResponseGate(held: holdAuthResponse)
    }
    func reply(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let values = lock.withLock { () -> (Data?, Data, Int, URLError?) in
            recorded.append(request)
            return (authResponseValue, responseValue, statusValue, errorValue)
        }
        if request.url?.path == "/auth/v1/token", let authBody = values.0 {
            try authGate.waitForRelease()
            // Read the installed hook after the hold: the SDK may enter during provider construction.
            let hook = lock.withLock { authHookValue }
            hook?() // Never call a witness setter while holding this recorder's lock.
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                headerFields: ["Content-Type": "application/json"])!, authBody)
        }
        if let error = values.3 { throw error }
        let hook = lock.withLock { businessHookValue }; hook?()
        return (HTTPURLResponse(url: request.url!, statusCode: values.2, httpVersion: nil,
            headerFields: ["Content-Type": "application/json"])!, values.1)
    }
}

nonisolated private final class ManualBoundaryRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: ManualBoundaryRecorder] = [:]
    func register(_ host: String, recorder: ManualBoundaryRecorder) { lock.withLock { values[host] = recorder } }
    func remove(_ host: String) { _ = lock.withLock { values.removeValue(forKey: host) } }
    func get(_ host: String) -> ManualBoundaryRecorder? { lock.withLock { values[host] } }
}

nonisolated private final class ManualBoundaryURLProtocol: URLProtocol, @unchecked Sendable {
    static let registry = ManualBoundaryRegistry()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let recorder = Self.registry.get(request.url?.host ?? "") else { throw URLError(.unsupportedURL) }
            let (response, data) = try recorder.reply(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

nonisolated private final class ManualBoundaryAuthResponseGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var released: Bool
    private var waiting = false
    init(held: Bool) { released = !held }
    var isWaiting: Bool { condition.lock(); defer { condition.unlock() }; return waiting && !released }
    func release() { condition.lock(); released = true; condition.broadcast(); condition.unlock() }
    func waitForRelease() throws {
        condition.lock(); defer { waiting = false; condition.unlock() }
        guard !released else { return }
        waiting = true
        let deadline = Date().addingTimeInterval(5)
        while !released {
            guard condition.wait(until: deadline) else { throw URLError(.timedOut) }
        }
    }
}


nonisolated private struct ManualBoundaryDefaults: @unchecked Sendable { let value: UserDefaults }
