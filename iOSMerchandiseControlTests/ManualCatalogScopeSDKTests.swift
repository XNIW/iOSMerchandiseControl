import Foundation
import Supabase
import XCTest
@testable import iOSMerchandiseControl

/// Actual pinned SDK requests with synthetic URLProtocol transport; no native TEST/auth acceptance.
@MainActor
final class ManualCatalogScopeSDKTests: XCTestCase {
    func testCapturedOwnerDifferentFromSDKOwnerRejectsBeforeBusinessIngress() async throws {
        let f = try ManualScopeFixture(sdkOwner: UUID())
        defer { f.close() }
        try await Task126OwnerStoreGate.withAutomaticScope(f.scope) {
            do { _ = try await f.gateway.createSuppliers([.init(ownerUserID: f.ownerID, name: "Expected")]); XCTFail("Foreign SDK owner admitted") }
            catch let error as LocalPendingManualDispatchError {
                guard case .staleBatch = error else { return XCTFail("Unexpected local denial") }
            }
        }
        XCTAssertTrue(f.recorder.requests.isEmpty)
    }

    func testShopChangesDuringActualSDKRefreshRejectBeforeBusinessIngress() async throws {
        let f = try ManualScopeFixture(expiredSession: true)
        defer { f.close() }
        let stores = f.stores, recorder = f.recorder
        let next = SelectedShop(shopID: UUID(), code: "NEXT", name: "Next", role: "owner", status: "active", selectable: true, canWrite: true)
        recorder.authResponseHook = {
            recorder.authHookObserved = stores.selected.save(next, accountHash: stores.accountHash) &&
                stores.binding.saveBinding(accountHash: stores.accountHash, storeIdentity: next.localStoreIdentity)
        }
        try await Task126OwnerStoreGate.withAutomaticScope(f.scope) {
            let pending = Task { @MainActor in
                recorder.queryInvocationObserved = true
                return try await f.gateway.updateSupplier(id: f.rowID, payload: .init(name: "Expected"))
            }
            defer { pending.cancel(); recorder.releaseAuthResponse() }
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            while !(recorder.queryInvocationObserved && recorder.authResponseWaiting) && ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(1))
            }
            XCTAssertTrue(recorder.queryInvocationObserved)
            XCTAssertTrue(recorder.authResponseWaiting)
            XCTAssertFalse(recorder.authHookObserved)
            recorder.releaseAuthResponse()
            do { _ = try await pending.value; XCTFail("Changed shop admitted") }
            catch let error as Task126OwnerStoreGateError { XCTAssertEqual(error, .scopeChanged) }
        }
        XCTAssertTrue(recorder.authHookObserved)
        XCTAssertEqual(recorder.requests.filter { $0.url?.path == "/auth/v1/token" }.count, 1)
        XCTAssertTrue(recorder.requests.filter { $0.url?.path.hasPrefix("/rest/v1/") == true }.isEmpty)
    }

    func testSupplierAndCategoryCreateEncodeCapturedShopAndSelectReturnedScope() async throws {
        let f = try ManualScopeFixture()
        defer { f.close() }
        for category in [false, true] {
            f.recorder.response = try f.response(single: false)
            try await Task126OwnerStoreGate.withAutomaticScope(f.scope) {
                if category { _ = try await f.gateway.createCategories([.init(ownerUserID: f.ownerID, name: "Expected")]) }
                else { _ = try await f.gateway.createSuppliers([.init(ownerUserID: f.ownerID, name: "Expected")]) }
            }
            let request = try XCTUnwrap(f.recorder.requests.last)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, category ? "/rest/v1/inventory_categories" : "/rest/v1/inventory_suppliers")
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBody(request)) as? [[String: Any]])
            XCTAssertEqual(body.count, 1)
            XCTAssertEqual(Set(body[0].keys), ["owner_user_id", "shop_id", "name"])
            XCTAssertEqual(body[0]["owner_user_id"] as? String, f.ownerID.uuidString)
            XCTAssertEqual(body[0]["shop_id"] as? String, f.shopID.uuidString)
            XCTAssertEqual(body[0]["name"] as? String, "Expected")
            XCTAssertTrue(try query(request)["select"]?.split(separator: ",").contains("shop_id") == true)
        }
        XCTAssertEqual(f.recorder.requests.count, 2)
    }

    func testSupplierAndCategoryUpdateUseExactIDOwnerAndShopPredicates() async throws {
        let f = try ManualScopeFixture()
        defer { f.close() }
        for category in [false, true] {
            f.recorder.response = try f.response(single: true)
            try await Task126OwnerStoreGate.withAutomaticScope(f.scope) {
                if category { _ = try await f.gateway.updateCategory(id: f.rowID, payload: .init(name: "Expected")) }
                else { _ = try await f.gateway.updateSupplier(id: f.rowID, payload: .init(name: "Expected")) }
            }
            let request = try XCTUnwrap(f.recorder.requests.last)
            XCTAssertEqual(request.httpMethod, "PATCH")
            let items = try query(request)
            XCTAssertEqual(items["id"], "eq.\(f.rowID.uuidString)")
            XCTAssertEqual(items["owner_user_id"], "eq.\(f.ownerID.uuidString)")
            XCTAssertEqual(items["shop_id"], "eq.\(f.shopID.uuidString)")
            XCTAssertTrue(items["select"]?.split(separator: ",").contains("shop_id") == true)
        }
        XCTAssertEqual(f.recorder.requests.count, 2)
    }

    func testSupplierAndCategoryReadbackUseExactIDOwnerAndShopPredicates() async throws {
        let f = try ManualScopeFixture()
        defer { f.close() }
        for category in [false, true] {
            f.recorder.response = try f.response(single: true)
            try await Task126OwnerStoreGate.withAutomaticScope(f.scope) {
                if category { _ = try await f.gateway.verifyCategory(id: f.rowID, normalizedName: "expected") }
                else { _ = try await f.gateway.verifySupplier(id: f.rowID, normalizedName: "expected") }
            }
            let request = try XCTUnwrap(f.recorder.requests.last)
            XCTAssertEqual(request.httpMethod, "GET")
            let items = try query(request)
            XCTAssertEqual(items["id"], "eq.\(f.rowID.uuidString)")
            XCTAssertEqual(items["owner_user_id"], "eq.\(f.ownerID.uuidString)")
            XCTAssertEqual(items["shop_id"], "eq.\(f.shopID.uuidString)")
        }
        XCTAssertEqual(f.recorder.requests.count, 2)
    }

    func testWrongShopCreateAndUpdateResponsesAreNotAcknowledgements() async throws {
        let f = try ManualScopeFixture()
        defer { f.close() }
        for category in [false, true] {
            for create in [false, true] {
                f.recorder.response = try f.response(single: !create, shop: UUID())
                try await Task126OwnerStoreGate.withAutomaticScope(f.scope) {
                    do {
                        if category && create { _ = try await f.gateway.createCategories([.init(ownerUserID: f.ownerID, name: "Expected")]) }
                        else if category { _ = try await f.gateway.updateCategory(id: f.rowID, payload: .init(name: "Expected")) }
                        else if create { _ = try await f.gateway.createSuppliers([.init(ownerUserID: f.ownerID, name: "Expected")]) }
                        else { _ = try await f.gateway.updateSupplier(id: f.rowID, payload: .init(name: "Expected")) }
                        XCTFail("Wrong-shop returned row was acknowledged")
                    } catch let error as LocalPendingManualDispatchError {
                        guard case .staleBatch = error else { return XCTFail("Unexpected local denial") }
                    }
                }
            }
        }
        XCTAssertEqual(f.recorder.requests.count, 4, "Each rejected response must not cause fallback write/retry")
    }

    private func query(_ request: URLRequest) throws -> [String: String] {
        let url = try XCTUnwrap(request.url)
        return Dictionary(uniqueKeysWithValues: try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
            .map { ($0.name, $0.value ?? "") })
    }
    private func requestBody(_ request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
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

@MainActor
private final class ManualScopeFixture {
    let ownerID = UUID(), shopID = UUID(), rowID = UUID()
    let recorder: ManualScopeRecorder
    let gateway: SupabaseManualPushRemoteClient
    let scope: Task126VerifiedOwnerStoreScope
    let stores: ManualScopeStores
    private let suiteName: String
    private let defaults: UserDefaults
    private let host: String
    private let session: URLSession
    init(sdkOwner: UUID? = nil, expiredSession: Bool = false) throws {
        recorder = ManualScopeRecorder(response: Data("[]".utf8), holdAuthResponse: expiredSession)
        suiteName = "ManualCatalogScopeSDKTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let selected = SelectedShop(shopID: shopID, code: "R4", name: "Dedicated test shop", role: "owner", status: "active", selectable: true, canWrite: true)
        let accountHash = AccountBindingStore.accountHash(for: ownerID)
        stores = ManualScopeStores(selected: SelectedShopStore(defaults: defaults), binding: AccountBindingStore(defaults: defaults), accountHash: accountHash)
        stores.selected.noteActiveAccount(accountHash)
        guard stores.selected.save(selected, accountHash: accountHash), stores.binding.saveBinding(accountHash: accountHash, storeIdentity: selected.localStoreIdentity) else { throw URLError(.cannotCreateFile) }
        _ = try DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID()
        scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: ownerID, defaults: defaults)
        host = "manual-scope-\(UUID().uuidString.lowercased()).example.invalid"
        ManualScopeURLProtocol.registry.register(host, recorder: recorder)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ManualScopeURLProtocol.self]
        session = URLSession(configuration: configuration)
        let storage = ManualScopeMemoryStorage()
        let user = User(id: sdkOwner ?? ownerID, appMetadata: [:], userMetadata: [:], aud: "authenticated", createdAt: Date(), updatedAt: Date())
        let stored = Session(accessToken: "manual-synthetic-access", tokenType: "bearer", expiresIn: 3600,
            expiresAt: Date().timeIntervalSince1970 + (expiredSession ? -3600 : 3600), refreshToken: "manual-synthetic-refresh", user: user)
        try storage.store(key: "sb-\(host.split(separator: ".")[0])-auth-token", value: JSONEncoder().encode(stored))
        if expiredSession {
            let refreshed = Session(accessToken: "manual-synthetic-refreshed", tokenType: "bearer", expiresIn: 3600,
                expiresAt: Date().timeIntervalSince1970 + 3600, refreshToken: "manual-synthetic-refresh", user: user)
            recorder.authResponse = try AuthClient.Configuration.jsonEncoder.encode(refreshed)
        }
        let provider = SupabaseClientProvider(config: .init(projectURL: URL(string: "https://\(host)")!, publishableKey: "manual-synthetic-publishable", productImageAPIBaseURL: nil), authStorage: storage, session: session, autoRefreshToken: false, authRegistry: SupabaseAuthClientRegistry())
        gateway = SupabaseManualPushRemoteClient(clientProvider: provider, defaults: defaults)
    }
    func response(single: Bool, shop: UUID? = nil) throws -> Data {
        let row: [String: Any] = ["id": rowID.uuidString, "owner_user_id": ownerID.uuidString,
            "shop_id": (shop ?? shopID).uuidString, "name": "Expected", "updated_at": "2026-10-23T12:34:56.123456Z", "deleted_at": NSNull()]
        if single { return try JSONSerialization.data(withJSONObject: row) }
        return try JSONSerialization.data(withJSONObject: [row])
    }
    func close() { recorder.releaseAuthResponse(); session.invalidateAndCancel(); ManualScopeURLProtocol.registry.remove(host); defaults.removePersistentDomain(forName: suiteName) }
}
nonisolated private struct ManualScopeStores: Sendable {
    let selected: SelectedShopStore
    let binding: AccountBindingStore
    let accountHash: String
}

nonisolated private final class ManualScopeMemoryStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}

nonisolated private final class ManualScopeRecorder: @unchecked Sendable {
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
    private let authGate: ManualScopeAuthResponseGate
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
        authGate = ManualScopeAuthResponseGate(held: holdAuthResponse)
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

nonisolated private final class ManualScopeRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: ManualScopeRecorder] = [:]
    func register(_ host: String, recorder: ManualScopeRecorder) { lock.withLock { values[host] = recorder } }
    func remove(_ host: String) { _ = lock.withLock { values.removeValue(forKey: host) } }
    func get(_ host: String) -> ManualScopeRecorder? { lock.withLock { values[host] } }
}

nonisolated private final class ManualScopeURLProtocol: URLProtocol, @unchecked Sendable {
    static let registry = ManualScopeRegistry()
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

nonisolated private final class ManualScopeAuthResponseGate: @unchecked Sendable {
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
