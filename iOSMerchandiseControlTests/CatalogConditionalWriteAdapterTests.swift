import Foundation
import Supabase
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class CatalogConditionalWriteAdapterTests: XCTestCase {
    func testConditionalPatchPreservesMicrosecondsNullPredicateAndExplicitNullField() async throws {
        let fixture = try ConditionalCatalogFixture(response: Data("[]".utf8))
        defer { fixture.close() }
        let version = SyncCatalogConditionalVersion(
            expectedUpdatedAt: "2026-10-23T12:34:56.123456+00:00", expectedDeletedAt: nil)
        let rows = try await fixture.patch(version: version)
        XCTAssertTrue(rows.isEmpty)
        let request = try XCTUnwrap(fixture.recorder.requests.only)
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.url?.path, "/rest/v1/inventory_products")
        let query = try queryItems(request)
        XCTAssertEqual(query["id"], "eq.\(fixture.productID.uuidString)")
        XCTAssertEqual(query["owner_user_id"], "eq.\(fixture.ownerID.uuidString)")
        XCTAssertEqual(query["shop_id"], "eq.\(fixture.shopID.uuidString)")
        XCTAssertEqual(query["updated_at"], "eq.2026-10-23T12:34:56.123456+00:00")
        // Pinned Supabase Swift 2.46 encodes Optional.nil as the SQL literal NULL.
        XCTAssertEqual(query["deleted_at"], "is.NULL")
        XCTAssertEqual(query["select"], CatalogRemoteSupabaseAdapter.productColumns)
        XCTAssertTrue(request.value(forHTTPHeaderField: "Prefer")?.contains("return=representation") == true)
        XCTAssertFalse(request.value(forHTTPHeaderField: "Accept")?.contains("vnd.pgrst.object") == true)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBody(request)) as? [String: Any])
        XCTAssertEqual(Set(body.keys), ["product_name", "second_product_name"])
        XCTAssertEqual(body["product_name"] as? String, "Chosen name")
        XCTAssertTrue(body["second_product_name"] is NSNull)
        XCTAssertEqual(fixture.recorder.requests.count, 1, "Zero rows must not trigger upsert or a second write")
    }

    func testConditionalPatchReturnsOneQualifiedRowAndPreservesNonNullPredicateSeparately() async throws {
        let fixture = try ConditionalCatalogFixture()
        defer { fixture.close() }
        fixture.recorder.response = try JSONEncoder().encode([fixture.row()])
        let rows = try await fixture.patch(version: .init(
            expectedUpdatedAt: "2026-10-23T12:34:56.123456Z",
            expectedDeletedAt: nil))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.updatedAt, "2026-10-23T12:34:57.987654+00:00")
        fixture.recorder.response = Data("[]".utf8)
        let noRows = try await fixture.patch(version: .init(
            expectedUpdatedAt: "2026-10-23T12:34:56.123456Z",
            expectedDeletedAt: "2026-10-23T12:34:55.654321Z"))
        XCTAssertTrue(noRows.isEmpty)
        let query = try queryItems(XCTUnwrap(fixture.recorder.requests.last))
        XCTAssertEqual(query["deleted_at"], "eq.2026-10-23T12:34:55.654321Z")
        XCTAssertEqual(fixture.recorder.requests.count, 2)
    }

    func testConditionalPatchRejectsMultipleRowsAndForeignIdentity() async throws {
        let fixture = try ConditionalCatalogFixture()
        defer { fixture.close() }
        for rows in [[fixture.row(), fixture.row()], [fixture.row(id: UUID())],
                     [fixture.row(owner: UUID())], [fixture.row(shop: UUID())],
                     [fixture.row(updatedAt: "")], [fixture.row(deletedAt: "2026-10-23T12:34:55.654321Z")]] {
            fixture.recorder.response = try JSONEncoder().encode(rows)
            do { _ = try await fixture.patch(); XCTFail("Unqualified CAS response accepted") }
            catch let error as SupabaseTransportClientError {
                guard case .schemaDrift = error else { return XCTFail("Unexpected classification: \(error)") }
            }
        }
        XCTAssertEqual(fixture.recorder.requests.count, 6)
    }

    func testConditionalPatchRejectsOwnerMismatchBeforeDispatch() async throws {
        let fixture = try ConditionalCatalogFixture()
        defer { fixture.close() }
        do { _ = try await fixture.patch(owner: UUID()); XCTFail("Foreign owner was admitted") }
        catch let error as SupabaseTransportClientError {
            guard case .permissionDeniedOrRLS = error else { return XCTFail("Unexpected classification") }
        }
        XCTAssertTrue(fixture.recorder.requests.isEmpty)
    }

    func testConditionalPatchRevalidatesScopeAfterAuthAwaitBeforeBusinessDispatch() async throws {
        let fixture = try ConditionalCatalogFixture(expiredSession: true, holdAuthResponse: true)
        defer { fixture.close() }
        let suiteName = "CatalogConditionalWriteAdapterTests.scope.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let scopeDefaults = ConditionalScopeDefaults(defaults)
        let recorder = fixture.recorder
        let accountHash = AccountBindingStore.accountHash(for: fixture.ownerID)
        let selected = SelectedShop(shopID: fixture.shopID, code: "R4", name: "R4 isolated scope",
            role: "owner", status: "active", selectable: true, canWrite: true)
        let store = SelectedShopStore(defaults: defaults)
        store.noteActiveAccount(accountHash)
        XCTAssertTrue(store.save(selected, accountHash: accountHash))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(accountHash: accountHash,
            storeIdentity: selected.localStoreIdentity))
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: fixture.ownerID, defaults: defaults)
        fixture.recorder.authResponseHook = {
            scopeDefaults.value.set("different-account", forKey: "mobile.shopContext.activeAccountHash.v1")
            recorder.scopeMutationObserved = scopeDefaults.value.string(forKey: "mobile.shopContext.activeAccountHash.v1") == "different-account"
        }
        let wire = try SyncCatalogConditionalProductWirePayload(payload: ConditionalCatalogFixture.payload,
            changedFields: ["productName", "secondProductName"])
        try await Task126OwnerStoreGate.withAutomaticScope(scope) {
            XCTAssertEqual(try Task126OwnerStoreGate.requireCurrentAutomaticScope(defaults: defaults), scope)
            let pending = Task { @MainActor in
                recorder.queryInvocationObserved = true
                return try await fixture.query.updateProductConditionally(wire,
                    columns: CatalogRemoteSupabaseAdapter.productColumns, id: fixture.productID,
                    ownerUserID: fixture.ownerID, shopID: fixture.shopID,
                    expectedVersion: .init(expectedUpdatedAt: "2026-10-23T12:34:56.123456Z", expectedDeletedAt: nil),
                    beforeDispatch: {
                        recorder.beforeDispatchObserved = true
                        guard try Task126OwnerStoreGate.requireCurrentAutomaticScope(defaults: scopeDefaults.value) == scope else {
                            throw Task126OwnerStoreGateError.scopeChanged
                        }
                    })
            }
            defer { pending.cancel(); recorder.releaseAuthResponse() }
            let deadline = ContinuousClock.now.advanced(by: .seconds(5))
            while !(recorder.queryInvocationObserved && recorder.authResponseWaiting) && ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(1))
            }
            XCTAssertTrue(recorder.queryInvocationObserved)
            XCTAssertTrue(recorder.authResponseWaiting, "The real SDK refresh response must still be held")
            XCTAssertFalse(recorder.beforeDispatchObserved)
            XCTAssertFalse(recorder.scopeMutationObserved)
            recorder.releaseAuthResponse()
            do {
                _ = try await pending.value
                XCTFail("Scope invalidated while awaiting authentication was admitted")
            } catch let error as Task126OwnerStoreGateError {
                XCTAssertEqual(error, .activeAccountMismatch)
            }
        }
        XCTAssertTrue(fixture.recorder.scopeMutationObserved, "The held refresh must apply the scope change before returning")
        XCTAssertTrue(fixture.recorder.beforeDispatchObserved, "The refreshed SDK session must decode before the scope gate is exercised")
        XCTAssertEqual(fixture.recorder.requests.filter { $0.url?.path == "/auth/v1/token" }.count, 1)
        XCTAssertTrue(fixture.recorder.requests.filter { $0.url?.path.hasPrefix("/rest/v1/") == true }.isEmpty)
    }

    func testAdapterRejectsOneRowResponseAfterScopeInvalidationWithoutReturningAcknowledgement() async throws {
        let fixture = try ConditionalCatalogFixture()
        defer { fixture.close() }
        let suiteName = "CatalogConditionalWriteAdapterTests.response-scope.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let scopeDefaults = ConditionalScopeDefaults(defaults)
        let accountHash = AccountBindingStore.accountHash(for: fixture.ownerID)
        let selected = SelectedShop(shopID: fixture.shopID, code: "R4", name: "R4 isolated response scope",
            role: "owner", status: "active", selectable: true, canWrite: true)
        let store = SelectedShopStore(defaults: defaults)
        store.noteActiveAccount(accountHash)
        XCTAssertTrue(store.save(selected, accountHash: accountHash))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(accountHash: accountHash,
            storeIdentity: selected.localStoreIdentity))
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: fixture.ownerID, defaults: defaults)
        let adapter = CatalogRemoteSupabaseAdapter(remote: fixture.transport, conditionalScope: {
            try Task126OwnerStoreGate.requireCurrentAutomaticScope(defaults: scopeDefaults.value)
        })
        fixture.recorder.response = try JSONEncoder().encode([fixture.row()])
        fixture.recorder.businessResponseHook = {
            scopeDefaults.value.set("different-account", forKey: "mobile.shopContext.activeAccountHash.v1")
        }
        try await Task126OwnerStoreGate.withAutomaticScope(scope) {
            do {
                _ = try await adapter.updateProductConditionally(id: fixture.productID,
                    payload: ConditionalCatalogFixture.payload,
                    expectedVersion: .init(expectedUpdatedAt: "2026-10-23T12:34:56.123456Z", expectedDeletedAt: nil),
                    changedFields: ["productName", "secondProductName"])
                XCTFail("The real adapter returned an acknowledgement after its scope changed")
            } catch let error as Task126OwnerStoreGateError {
                XCTAssertEqual(error, .activeAccountMismatch)
            }
        }
        let request = try XCTUnwrap(fixture.recorder.requests.only)
        XCTAssertEqual(request.httpMethod, "PATCH")
        XCTAssertEqual(request.url?.path, "/rest/v1/inventory_products")
        let predicates = try queryItems(request)
        XCTAssertEqual(predicates["owner_user_id"], "eq.\(fixture.ownerID.uuidString)")
        XCTAssertEqual(predicates["shop_id"], "eq.\(fixture.shopID.uuidString)")
    }

    func testOnlyTypedAtomicConstraintRejectionProducesNoCommitProof() async throws {
        let fixture = try ConditionalCatalogFixture()
        defer { fixture.close() }
        for code in ["23503", "23505"] {
            fixture.recorder.status = 409
            fixture.recorder.response = try JSONSerialization.data(withJSONObject: [
                "code": code, "message": "synthetic atomic constraint rejection", "details": NSNull(), "hint": NSNull()
            ])
            do { _ = try await fixture.patch(); XCTFail("Atomic rejection was accepted") }
            catch let error as SyncCatalogWriteRejectedWithoutCommit { XCTAssertEqual(error.sqlstate, code) }
        }
        fixture.recorder.status = 500
        fixture.recorder.response = try JSONSerialization.data(withJSONObject: [
            "code": "XX000", "message": "text mentioning 23505 is not proof", "details": NSNull(), "hint": NSNull()
        ])
        do { _ = try await fixture.patch(); XCTFail("Server failure was accepted") }
        catch is SyncCatalogWriteRejectedWithoutCommit { XCTFail("Text classified as no-commit proof") }
        catch { }
        fixture.recorder.status = 200
        fixture.recorder.response = Data("invalid JSON after possibly committed write".utf8)
        do { _ = try await fixture.patch(); XCTFail("Invalid response was accepted") }
        catch is SyncCatalogWriteRejectedWithoutCommit { XCTFail("Decode failure classified as no-commit proof") }
        catch { }
        fixture.recorder.transportError = URLError(.networkConnectionLost)
        do { _ = try await fixture.patch(); XCTFail("Lost response was accepted") }
        catch is SyncCatalogWriteRejectedWithoutCommit { XCTFail("Transport failure classified as no-commit proof") }
        catch { }
    }

    func testConditionalWireMaskRejectsUnknownEmptyDuplicateAndNullBarcode() throws {
        for fields in [[], ["unknown"], ["productName", "productName"], ["deletedAt"], ["barcode"]] {
            XCTAssertThrowsError(try SyncCatalogConditionalProductWirePayload(
                payload: ConditionalCatalogFixture.payload, changedFields: fields))
        }
    }

    func testMalformedConditionalVersionFailsBeforeDispatch() async throws {
        let fixture = try ConditionalCatalogFixture()
        defer { fixture.close() }
        for version in [
            SyncCatalogConditionalVersion(expectedUpdatedAt: "", expectedDeletedAt: nil),
            .init(expectedUpdatedAt: "2026-10-23T12:34:56.1234567Z", expectedDeletedAt: nil),
            .init(expectedUpdatedAt: "2026-10-23T12:34:56.123456Z", expectedDeletedAt: "invalid")
        ] {
            do { _ = try await fixture.patch(version: version); XCTFail("Invalid version admitted") }
            catch let error as SupabaseTransportClientError {
                guard case .schemaDrift = error else { return XCTFail("Unexpected classification") }
            }
        }
        XCTAssertTrue(fixture.recorder.requests.isEmpty)
    }

    func testTypedCatalogRejectionRequiresExplicitLegacyQueryOptIn() async throws {
        let fixture = try ConditionalCatalogFixture()
        defer { fixture.close() }
        fixture.recorder.status = 409
        fixture.recorder.response = Data(#"{"code":"23505","message":"synthetic conflict","details":null,"hint":null}"#.utf8)
        do {
            let _: RemoteInventoryProductRow = try await fixture.query.updateRow(
                ConditionalCatalogFixture.payload, table: "inventory_products",
                columns: CatalogRemoteSupabaseAdapter.productColumns, id: fixture.productID)
            XCTFail("Constraint failure accepted")
        } catch is SyncCatalogWriteRejectedWithoutCommit {
            XCTFail("Legacy generic behavior changed without opt-in")
        } catch let error as SupabaseTransportClientError {
            guard case .unknown = error else { return XCTFail("Unexpected legacy classification") }
        }
        do {
            let _: RemoteInventoryProductRow = try await fixture.query.updateRow(
                ConditionalCatalogFixture.payload, table: "inventory_products",
                columns: CatalogRemoteSupabaseAdapter.productColumns, id: fixture.productID,
                preserveCatalogWriteRejection: true)
            XCTFail("Constraint failure accepted")
        } catch let error as SyncCatalogWriteRejectedWithoutCommit {
            XCTAssertEqual(error.sqlstate, "23505")
        }
        XCTAssertEqual(fixture.recorder.requests.count, 2)
    }

    private func queryItems(_ request: URLRequest) throws -> [String: String] {
        let components = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        return Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }

    private func requestBody(_ request: URLRequest) throws -> Data {
        if let data = request.httpBody { return data }
        let stream = try XCTUnwrap(request.httpBodyStream)
        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count == 0 { break }
            guard count > 0 else { throw stream.streamError ?? URLError(.cannotDecodeRawData) }
            result.append(contentsOf: buffer.prefix(count))
        }
        return result
    }
}

@MainActor
private final class ConditionalCatalogFixture {
    let ownerID = UUID()
    let shopID = UUID()
    let productID = UUID()
    let recorder: ConditionalCatalogRecorder
    let query: SupabaseRemoteQueryExecutor
    let transport: SupabaseTransportClient
    private let host: String
    private let session: URLSession

    static var payload: SyncAutomaticProductUpdatePayload {
        .init(barcode: nil, itemNumber: nil, productName: "Chosen name", secondProductName: nil,
              purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil, deletedAt: nil)
    }

    init(response: Data = Data("[]".utf8), expiredSession: Bool = false, holdAuthResponse: Bool = false) throws {
        host = "conditional-\(UUID().uuidString.lowercased()).example.invalid"
        recorder = ConditionalCatalogRecorder(response: response, holdAuthResponse: holdAuthResponse)
        ConditionalCatalogURLProtocol.registry.register(host, recorder: recorder)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ConditionalCatalogURLProtocol.self]
        session = URLSession(configuration: configuration)
        let storage = ConditionalCatalogMemoryStorage()
        let user = User(id: ownerID, appMetadata: [:], userMetadata: [:], aud: "authenticated",
                        createdAt: Date(), updatedAt: Date())
        let storedSession = Session(accessToken: "conditional-synthetic-access", tokenType: "bearer",
                                    expiresIn: 3600, expiresAt: Date().timeIntervalSince1970 + (expiredSession ? -3600 : 3600),
                                    refreshToken: "conditional-synthetic-refresh", user: user)
        if expiredSession {
            let refreshed = Session(accessToken: "conditional-synthetic-refreshed", tokenType: "bearer",
                expiresIn: 3600, expiresAt: Date().timeIntervalSince1970 + 3600,
                refreshToken: "conditional-synthetic-refresh", user: user)
            // HTTP auth responses use the SDK network codec; persisted sessions use plain JSONEncoder below.
            recorder.authResponse = try AuthClient.Configuration.jsonEncoder.encode(refreshed)
        }
        try storage.store(key: "sb-\(host.split(separator: ".")[0])-auth-token", value: JSONEncoder().encode(storedSession))
        let provider = SupabaseClientProvider(
            config: .init(projectURL: URL(string: "https://\(host)")!,
                          publishableKey: "conditional-synthetic-publishable", productImageAPIBaseURL: nil),
            authStorage: storage, session: session, autoRefreshToken: false, authRegistry: SupabaseAuthClientRegistry())
        transport = SupabaseTransportClient(clientProvider: provider)
        query = SupabaseRemoteQueryExecutor(transport: transport)
    }

    func patch(version: SyncCatalogConditionalVersion = .init(
        expectedUpdatedAt: "2026-10-23T12:34:56.123456Z", expectedDeletedAt: nil), owner: UUID? = nil
    ) async throws -> [RemoteInventoryProductRow] {
        let wire = try SyncCatalogConditionalProductWirePayload(
            payload: Self.payload, changedFields: ["productName", "secondProductName"])
        return try await query.updateProductConditionally(
            wire, columns: CatalogRemoteSupabaseAdapter.productColumns, id: productID,
            ownerUserID: owner ?? ownerID, shopID: shopID, expectedVersion: version)
    }

    func row(id: UUID? = nil, owner: UUID? = nil, shop: UUID? = nil,
             updatedAt: String = "2026-10-23T12:34:57.987654+00:00", deletedAt: String? = nil
    ) -> RemoteInventoryProductRow {
        .init(id: id ?? productID, ownerUserID: owner ?? ownerID, shopID: shop ?? shopID,
              barcode: "R4_SYNTHETIC", itemNumber: nil, productName: "Chosen name", secondProductName: nil,
              purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil,
              updatedAt: updatedAt, deletedAt: deletedAt)
    }

    func close() {
        recorder.releaseAuthResponse()
        session.invalidateAndCancel()
        ConditionalCatalogURLProtocol.registry.remove(host)
    }
}

nonisolated private final class ConditionalCatalogMemoryStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}

nonisolated private final class ConditionalScopeDefaults: @unchecked Sendable {
    let value: UserDefaults
    init(_ value: UserDefaults) { self.value = value }
}

nonisolated private final class ConditionalCatalogRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    private var responseValue: Data
    private var statusValue = 200
    private var errorValue: URLError?
    private var authResponseValue: Data?
    private var authHookValue: (@Sendable () -> Void)?
    private var businessHookValue: (@Sendable () -> Void)?
    private var beforeDispatchValue = false
    private var queryInvocationValue = false
    private var scopeMutationValue = false
    private let authGate: ConditionalAuthResponseGate
    var requests: [URLRequest] { lock.withLock { recorded } }
    var queryInvocationObserved: Bool { get { lock.withLock { queryInvocationValue } } set { lock.withLock { queryInvocationValue = newValue } } }
    var scopeMutationObserved: Bool { get { lock.withLock { scopeMutationValue } } set { lock.withLock { scopeMutationValue = newValue } } }
    var authResponseWaiting: Bool { authGate.isWaiting }
    func releaseAuthResponse() { authGate.release() }
    var beforeDispatchObserved: Bool { get { lock.withLock { beforeDispatchValue } } set { lock.withLock { beforeDispatchValue = newValue } } }
    var response: Data { get { lock.withLock { responseValue } } set { lock.withLock { responseValue = newValue } } }
    var status: Int { get { lock.withLock { statusValue } } set { lock.withLock { statusValue = newValue } } }
    var transportError: URLError? { get { lock.withLock { errorValue } } set { lock.withLock { errorValue = newValue } } }
    var authResponse: Data? { get { lock.withLock { authResponseValue } } set { lock.withLock { authResponseValue = newValue } } }
    var authResponseHook: (@Sendable () -> Void)? { get { lock.withLock { authHookValue } } set { lock.withLock { authHookValue = newValue } } }
    var businessResponseHook: (@Sendable () -> Void)? { get { lock.withLock { businessHookValue } } set { lock.withLock { businessHookValue = newValue } } }
    init(response: Data, holdAuthResponse: Bool = false) {
        responseValue = response
        authGate = ConditionalAuthResponseGate(held: holdAuthResponse)
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

/// Owned test transport only: bounded hold, released by test or fixture cleanup.
nonisolated private final class ConditionalAuthResponseGate: @unchecked Sendable {
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

nonisolated private final class ConditionalCatalogRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: ConditionalCatalogRecorder] = [:]
    func register(_ host: String, recorder: ConditionalCatalogRecorder) { lock.withLock { values[host] = recorder } }
    func remove(_ host: String) { _ = lock.withLock { values.removeValue(forKey: host) } }
    func get(_ host: String) -> ConditionalCatalogRecorder? { lock.withLock { values[host] } }
}

nonisolated private final class ConditionalCatalogURLProtocol: URLProtocol, @unchecked Sendable {
    static let registry = ConditionalCatalogRegistry()
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

private extension Array {
    var only: Element? { count == 1 ? first : nil }
}
