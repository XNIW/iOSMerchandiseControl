import Foundation
import Supabase
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class ScopedReconciliationRemoteCountTests: XCTestCase {
    func testAuthorizedShopAndMappedLegacyUseExactPredicatesAndRetainPublicFilters() async throws {
        let fixture = try ScopedReconciliationSDKFixture()
        defer { fixture.close() }
        let counts = try await fixture.read()
        XCTAssertEqual(counts, .init(products: 3, suppliers: 3, categories: 3,
            productPrices: 2, historySessions: 2))
        let requests = fixture.recorder.requests
        XCTAssertEqual(requests.count, 6)
        let metadata = try XCTUnwrap(requests.first { $0.url?.lastPathComponent == "shop_inventory_sources" })
        XCTAssertEqual(try fixture.query(metadata)["shop_id"], "eq.\(fixture.shopID.uuidString)")
        XCTAssertEqual(try fixture.query(metadata)["owner_user_id"], "not.is.null")
        XCTAssertEqual(try fixture.query(metadata)["verified_at"], "not.is.null")
        XCTAssertEqual(try fixture.query(metadata)["limit"], "1")
        for request in requests where request.url?.lastPathComponent != "shop_inventory_sources" {
            let query = try fixture.query(request)
            XCTAssertNil(query["owner_user_id"], "A shop may contain rows owned by another authorized writer")
            XCTAssertNil(query["shop_id"], "Legacy NULL rows must not be eliminated by an AND shop filter")
            XCTAssertEqual(query["or"], "(\(fixture.predicate))")
            if request.url?.lastPathComponent == "inventory_product_prices" {
                XCTAssertEqual(query["select"], "id,inventory_products!inner(id)")
                XCTAssertEqual(query["inventory_products.deleted_at"], "is.NULL")
            } else { XCTAssertEqual(query["deleted_at"], "is.NULL") }
        }
    }

    func testMappedOwnerMustMatchQualifiedCheckpointBeforeCountDispatch() async throws {
        let fixture = try ScopedReconciliationSDKFixture()
        defer { fixture.close() }
        let other = ShopSyncRecoveryScope(kind: fixture.recoveryScope.kind,
            historyKind: fixture.recoveryScope.historyKind, key: fixture.recoveryScope.key,
            legacyOwnerKey: ShopSyncRecoveryCanonical.sha256(UUID().uuidString.lowercased()),
            accountKey: fixture.recoveryScope.accountKey, deviceKey: fixture.recoveryScope.deviceKey)
        do { _ = try await fixture.read(recoveryScope: other); XCTFail("Foreign legacy mapping accepted") }
        catch { XCTAssertEqual(error as? Task126OwnerStoreGateError, .scopeChanged) }
        XCTAssertEqual(fixture.recorder.requests.map { $0.url?.lastPathComponent }, ["shop_inventory_sources"])
    }
}

/// Controlled SDK HTTP transport. It evaluates row scope independently from the
/// product predicate; no remote count or ACK is installed in application state.
@MainActor
final class ScopedReconciliationSDKFixture {
    let ownerID: UUID
    let shopID: UUID
    let mappedOwnerID: UUID
    let deviceID: String
    let defaults: UserDefaults
    let scope: Task126VerifiedOwnerStoreScope
    let recoveryScope: ShopSyncRecoveryScope
    let recorder: ScopedReconciliationRecorder
    let adapter: SyncEventRemoteSupabaseAdapter
    let predicate: String
    private let session: URLSession
    private let host: String
    private let suiteName: String

    init(ownerID: UUID = UUID(), shopID: UUID = UUID(), mappedOwnerID: UUID = UUID(),
         deviceID: String = UUID().uuidString.lowercased(), defaults externalDefaults: UserDefaults? = nil,
         enabledTables: Set<String>? = nil) throws {
        self.ownerID = ownerID; self.shopID = shopID; self.mappedOwnerID = mappedOwnerID; self.deviceID = deviceID
        suiteName = "ScopedReconciliationRemoteCountTests.\(UUID().uuidString)"
        defaults = externalDefaults ?? UserDefaults(suiteName: suiteName)!
        if externalDefaults == nil {
            defaults.set(deviceID, forKey: "shop.device.install.id")
            let account = AccountBindingStore.accountHash(for: ownerID)
            let selected = SelectedShop(shopID: shopID, code: "COUNT", name: "Count scope", role: "owner",
                status: "active", selectable: true, canWrite: true)
            let selectedStore = SelectedShopStore(defaults: defaults)
            selectedStore.noteActiveAccount(account)
            _ = selectedStore.save(selected, accountHash: account)
            _ = AccountBindingStore(defaults: defaults).saveBinding(accountHash: account,
                storeIdentity: selected.localStoreIdentity)
        }
        scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: ownerID, defaults: defaults)
        recoveryScope = Self.recoveryScope(ownerID: ownerID, shopID: shopID,
            mappedOwnerID: mappedOwnerID, deviceID: deviceID)
        predicate = "shop_id.eq.\(shopID.uuidString),and(shop_id.is.null,owner_user_id.eq.\(mappedOwnerID.uuidString))"
        host = "scope-count-\(UUID().uuidString.lowercased()).example.invalid"
        recorder = ScopedReconciliationRecorder(shopID: shopID, ownerID: ownerID,
            mappedOwnerID: mappedOwnerID, enabledTables: enabledTables)
        ScopedReconciliationURLProtocol.registry.register(host, recorder)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ScopedReconciliationURLProtocol.self]
        session = URLSession(configuration: configuration)
        let storage = ScopedReconciliationMemoryStorage()
        let user = User(id: ownerID, appMetadata: [:], userMetadata: [:], aud: "authenticated", createdAt: Date(), updatedAt: Date())
        let stored = Session(accessToken: "scope-count-synthetic-access", tokenType: "bearer",
            expiresIn: 3600, expiresAt: Date().timeIntervalSince1970 + 3600,
            refreshToken: "scope-count-synthetic-refresh", user: user)
        try storage.store(key: "sb-\(host.split(separator: ".")[0])-auth-token", value: JSONEncoder().encode(stored))
        let provider = SupabaseClientProvider(config: .init(projectURL: URL(string: "https://\(host)")!,
            publishableKey: "scope-count-synthetic-publishable", productImageAPIBaseURL: nil), authStorage: storage,
            session: session, autoRefreshToken: false, authRegistry: SupabaseAuthClientRegistry())
        adapter = SyncEventRemoteSupabaseAdapter(remote: SupabaseTransportClient(clientProvider: provider), defaults: defaults)
    }

    static func recoveryScope(ownerID: UUID, shopID: UUID, mappedOwnerID: UUID, deviceID: String) -> ShopSyncRecoveryScope {
        .init(kind: "authorized_shop_plus_legacy", historyKind: "authorized_shop_plus_legacy",
            key: ShopSyncRecoveryCanonical.sha256("scoped-count-fixture:\(shopID.uuidString)"),
            legacyOwnerKey: ShopSyncRecoveryCanonical.sha256(mappedOwnerID.uuidString.lowercased()),
            accountKey: ShopSyncRecoveryCanonical.sha256(ownerID.uuidString.lowercased()),
            deviceKey: ShopSyncRecoveryCanonical.sha256(deviceID))
    }

    func read(recoveryScope override: ShopSyncRecoveryScope? = nil) async throws -> SyncInventoryCountSnapshot {
        try await Task126OwnerStoreGate.withAutomaticScope(scope) {
            try await adapter.fetchReconciliationRemoteCounts(scope: scope,
                recoveryScope: override ?? recoveryScope, defaults: defaults)
        }
    }
    func query(_ request: URLRequest) throws -> [String: String] {
        let url = try XCTUnwrap(request.url)
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        return Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    }
    func close() {
        session.invalidateAndCancel(); ScopedReconciliationURLProtocol.registry.remove(host)
        defaults.removePersistentDomain(forName: suiteName)
    }
}

nonisolated final class ScopedReconciliationRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [URLRequest] = []
    let shopID: UUID; let ownerID: UUID; let mappedOwnerID: UUID
    let enabledTables: Set<String>?
    var requests: [URLRequest] { lock.withLock { recorded } }
    init(shopID: UUID, ownerID: UUID, mappedOwnerID: UUID, enabledTables: Set<String>?) {
        self.shopID = shopID; self.ownerID = ownerID; self.mappedOwnerID = mappedOwnerID; self.enabledTables = enabledTables
    }
    func reply(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        lock.withLock { recorded.append(request) }
        let url = try XCTUnwrap(request.url)
        let table = url.lastPathComponent
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let q = Dictionary(uniqueKeysWithValues: (parts.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        if table == "shop_inventory_sources" {
            // Newer unmapped identities must be filtered before LIMIT, not selected
            // and rejected while hiding the qualified older mapping.
            var mappings: [[String: Any]] = [
                ["owner_user_id": NSNull(), "created_at": "2026-07-23T12:00:00Z", "verified_at": "2026-07-23T12:00:00Z"],
                ["owner_user_id": UUID().uuidString, "created_at": "2026-07-22T12:00:00Z", "verified_at": NSNull()],
                ["owner_user_id": mappedOwnerID.uuidString, "created_at": "2026-07-21T12:00:00Z", "verified_at": "2026-07-21T12:00:00Z"]]
            if q["owner_user_id"] == "not.is.null" { mappings = mappings.filter { !($0["owner_user_id"] is NSNull) } }
            if q["verified_at"] == "not.is.null" { mappings = mappings.filter { !($0["verified_at"] is NSNull) } }
            let body = try JSONSerialization.data(withJSONObject: Array(mappings.prefix(Int(q["limit"] ?? "0") ?? 0)))
            return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, body)
        }
        let foreignShop = UUID(); let foreignOwner = UUID()
        let rows: [(UUID?, UUID, Bool)] = [(shopID, ownerID, false), (shopID, foreignOwner, false),
            (nil, mappedOwnerID, false), (nil, foreignOwner, false), (foreignShop, ownerID, false),
            (shopID, ownerID, true)]
        let expectedOR = "(shop_id.eq.\(shopID.uuidString),and(shop_id.is.null,owner_user_id.eq.\(mappedOwnerID.uuidString)))"
        // Reject a malformed wire predicate rather than silently returning the desired vector.
        guard q["or"] == expectedOR, q["owner_user_id"] == nil, q["shop_id"] == nil else {
            throw URLError(.badURL)
        }
        let active = rows.filter { ($0.0 == shopID || ($0.0 == nil && $0.1 == mappedOwnerID)) && !$0.2 }
        let enabled = enabledTables?.contains(table) ?? true
        var headers = ["Content-Type": "application/json"]
        var body = Data("[]".utf8)
        if table == "shared_sheet_sessions" {
            if enabled {
                let names = ["First visible", "Second visible", "APPLY_IMPORT_TECHNICAL_COUNT_FIXTURE"]
                body = try JSONSerialization.data(withJSONObject: names.map {
                    ["remote_id": UUID().uuidString, "display_name": $0, "deleted_at": NSNull()] as [String: Any]
                })
            }
        } else {
            // For price fixtures the legacy price references a tombstoned parent.
            let visibleRows = table == "inventory_product_prices" ? active.filter { $0.0 != nil } : active
            let count = enabled ? visibleRows.count : 0
            headers["Content-Range"] = count == 0 ? "*/0" : "0-\(count-1)/\(count)"
        }
        return (HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)!, body)
    }
}

nonisolated private final class ScopedReconciliationMemoryStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock(); private var values: [String: Data] = [:]
    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { _ = lock.withLock { values.removeValue(forKey: key) } }
}
nonisolated private final class ScopedReconciliationRegistry: @unchecked Sendable {
    private let lock = NSLock(); private var values: [String: ScopedReconciliationRecorder] = [:]
    func register(_ host: String, _ recorder: ScopedReconciliationRecorder) { lock.withLock { values[host] = recorder } }
    func remove(_ host: String) { _ = lock.withLock { values.removeValue(forKey: host) } }
    func get(_ host: String) -> ScopedReconciliationRecorder? { lock.withLock { values[host] } }
}
nonisolated private final class ScopedReconciliationURLProtocol: URLProtocol, @unchecked Sendable {
    static let registry = ScopedReconciliationRegistry()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let recorder = Self.registry.get(request.url?.host ?? "") else { throw URLError(.unsupportedURL) }
            let (response, data) = try recorder.reply(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
