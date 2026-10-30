import XCTest
import CryptoKit
import Supabase
#if DEBUG
import Darwin
#endif
@testable import iOSMerchandiseControl

final class SupabaseConfigSecurityTests: XCTestCase {
    @MainActor
    func testTask103IOSAuthPreflightWhenEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        let task103Enabled = isEnabled(environment["TASK103_IOS_AUTH_PREFLIGHT"])
            || isEnabled(environment["TEST_RUNNER_TASK103_IOS_AUTH_PREFLIGHT"])
        let task104Enabled = isEnabled(environment["TASK104_PASS2_IOS_AUTH_PREFLIGHT"])
            || isEnabled(environment["TEST_RUNNER_TASK104_PASS2_IOS_AUTH_PREFLIGHT"])
        let task112Enabled = isEnabled(environment["TASK112_IOS_AUTH_PREFLIGHT"])
            || isEnabled(environment["TEST_RUNNER_TASK112_IOS_AUTH_PREFLIGHT"])
        try XCTSkipUnless(
            task103Enabled || task104Enabled || task112Enabled,
            "Live auth preflight is gated."
        )
        guard Bundle.main.bundleIdentifier == "com.niwcyber.iOSMerchandiseControl" else {
            return XCTFail("Ordinary app test host required for device-session preflight.")
        }
#if DEBUG
        guard Task144LocalAvailabilityRootFixture.current == nil else {
            return XCTFail("Controlled root cannot qualify the ordinary app session.")
        }
#endif

        let config = try SupabaseConfig.load(bundle: .main)
        XCTAssertFalse(config.publishableKey.lowercased().contains("service_role"))
        XCTAssertFalse(config.publishableKey.lowercased().contains("secret_key"))
        XCTAssertFalse(config.publishableKey.lowercased().contains("sb_secret"))

        let authService = SupabaseAuthService(provider: SupabaseClientProvider(config: config))
        try await Task.sleep(nanoseconds: 2_000_000_000)

        guard let session = authService.currentSession, !session.isExpired else {
            XCTFail("TASK-103 iOS auth preflight requires an existing non-expired device session.")
            return
        }

        let label: String
        if task112Enabled {
            label = "TASK112_IOS_AUTH_PREFLIGHT"
        } else if task104Enabled {
            label = "TASK104_PASS2_IOS_AUTH_PREFLIGHT"
        } else {
            label = "TASK103_IOS_AUTH_PREFLIGHT"
        }
        print(
            "\(label) project_hash=\(task103Hash(config.projectURL.absoluteString)) " +
            "owner_hash=\(task103Hash(session.userID.uuidString.lowercased())) " +
            "provider=\(session.provider ?? "unknown") signed_in=true"
        )
        if isEnabled(environment["TEST_RUNNER_TASK145_CAS_PREFLIGHT_RECEIPT"]) {
            var proof: [String: Any] = ["kind": "task145_native_session_preflight", "signed_in": true,
                "host_bundle": Bundle.main.bundleIdentifier ?? "UNKNOWN",
                "project_sha256": Self.liveHash(Data(config.projectURL.absoluteString.utf8)),
                "owner_sha256": Self.liveHash(Data(session.userID.uuidString.lowercased().utf8)),
                "scope_qualification": "NOT_READY"]
            if let executable = Bundle.main.executableURL, let bytes = try? Data(contentsOf: executable) {
                proof["artifact_sha256"] = Self.liveHash(bytes)
            }
            if let scope = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: session.userID) {
                proof["scope_qualification"] = "LOCAL_SCOPE_CAPTURED_REMOTE_DEVICE_NOT_CHECKED"
                proof["shop_sha256"] = Self.liveHash(Data(scope.shopID.uuidString.lowercased().utf8))
                proof["device_sha256"] = Self.liveHash(Data(scope.deviceInstallID.utf8))
#if DEBUG
                if let persistent = PilotCommitTrace.b6PersistentScopeIdentity(scope) {
                    proof["persistent_scope_identity_raw"] = persistent.raw
                    proof["persistent_scope_sha256"] = persistent.sha256
                }
#endif
            }
            let data = try JSONSerialization.data(withJSONObject: proof, options: [.sortedKeys])
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = "task145-native-session-preflight"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testAuthSessionInfoPrivacySafeDisplayRedactsAccountIdentifiers() {
        let sessionInfo = SupabaseAuthSessionInfo(
            userID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            email: "user@example.test",
            provider: "google",
            isExpired: false
        )

        XCTAssertEqual(sessionInfo.privacySafeUserID, "00000000-redacted")
        XCTAssertEqual(sessionInfo.privacySafeDisplayEmail, "u***@example.test")
        XCTAssertFalse(sessionInfo.privacySafeDisplayEmail?.contains("user@example.test") ?? true)
    }

    /// Live TEST qualification within the existing campaign. Default runs skip before loading auth.
    /// The coordinator supplies a final, artifact/scope-pinned copy of the planned fixture manifest.
    @MainActor
    func testTask145LiveCatalogCasWhenEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["TEST_RUNNER_TASK145_LIVE_CAS"] == "1", "Live CAS is explicitly gated.")
        guard Bundle.main.bundleIdentifier == "com.niwcyber.iOSMerchandiseControl" else {
            return XCTFail("Ordinary app test host required for live CAS.")
        }
#if DEBUG
        guard Task144LocalAvailabilityRootFixture.current == nil else {
            return XCTFail("Controlled root cannot qualify the ordinary app session.")
        }
#endif
        var receipt: [String: Any] = ["kind": "task145_live_catalog_cas", "status": "STARTED",
                                      "cleanup": "NOT_RUN", "physical_residue": "NOT_ASSESSED"]
        var operations: [[String: Any]] = []
        func observed<T>(_ operation: String, phase: String, _ body: () async throws -> T) async throws -> T {
            let started = ProcessInfo.processInfo.systemUptime
            var row: [String: Any] = ["operation": operation, "phase": phase, "attempt": operations.count + 1,
                "started_at_epoch_ms": Int64(Date().timeIntervalSince1970 * 1_000)]
            do {
                let value = try await body()
                row["outcome"] = "returned"
                row["ended_at_epoch_ms"] = Int64(Date().timeIntervalSince1970 * 1_000)
                row["duration_ms"] = (ProcessInfo.processInfo.systemUptime - started) * 1_000
                operations.append(row)
                receipt["operations"] = operations
                return value
            } catch {
                row.merge(Self.liveErrorFields(error)) { _, new in new }
                row["outcome"] = "failed"
                row["ended_at_epoch_ms"] = Int64(Date().timeIntervalSince1970 * 1_000)
                row["duration_ms"] = (ProcessInfo.processInfo.systemUptime - started) * 1_000
                operations.append(row)
                receipt["operations"] = operations
                throw error
            }
        }
        defer {
            if let data = try? JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys]) {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = "task145-live-cas-receipt"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
        do {
            let path = try XCTUnwrap(environment["TEST_RUNNER_TASK145_CAS_MANIFEST_PATH"])
            let expectedHash = try XCTUnwrap(environment["TEST_RUNNER_TASK145_CAS_MANIFEST_SHA256"])
            let bytes = try Data(contentsOf: URL(fileURLWithPath: path))
            guard bytes.count <= 64 * 1_024, Self.liveHash(bytes) == expectedHash else { throw LiveCasFailure.manifest }
            let manifest = try JSONDecoder().decode(LiveCasManifest.self, from: bytes)
            guard manifest.status == "AUTHORIZED_FOR_NATIVE_CAS",
                  manifest.target.projectRef == "jpgoimipbothfgkokyvm",
                  manifest.target.exactProjectUrlSha256 == Self.liveTestProjectHash,
                  let fixture = manifest.fixtures.first(where: { $0.platform == "ios" }),
                  manifest.fixtures.filter({ $0.platform == "ios" }).count == 1,
                  fixture.barcode.hasPrefix("TASK145_R4_CAS_"), fixture.barcode.count < 100,
                  fixture.barcode.range(of: "^[A-Z0-9_a-f]+$", options: .regularExpression) != nil,
                  fixture.parents.isEmpty, fixture.prices.isEmpty, fixture.history.isEmpty, !fixture.created,
                  fixture.initial.secondProductName?.isEmpty == false,
                  fixture.chosen.secondProductName == nil,
                  fixture.initial.productName != fixture.chosen.productName,
                  fixture.staleRejectedName != fixture.chosen.productName else { throw LiveCasFailure.manifest }
            let productID = try XCTUnwrap(UUID(uuidString: fixture.productId))
            let config = try SupabaseConfig.load(bundle: .main)
            guard Self.liveHash(Data(config.projectURL.absoluteString.utf8)) == Self.liveTestProjectHash,
                  Self.liveHash(try Data(contentsOf: XCTUnwrap(Bundle.main.executableURL))) == manifest.target.nativeArtifactHash
            else { throw LiveCasFailure.artifact }
            let provider = SupabaseClientProvider(config: config)
            let session = try await provider.client.auth.session
            guard !session.isExpired else { throw LiveCasFailure.authority }
            let authGeneration = provider.authSnapshot.generation
            let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: session.user.id)
            guard Self.liveHash(Data(scope.ownerUserID.uuidString.lowercased().utf8)) == manifest.target.ownerHash,
                  Self.liveHash(Data(scope.shopID.uuidString.lowercased().utf8)) == manifest.target.shopHash,
                  Self.liveHash(Data(scope.deviceInstallID.utf8)) == manifest.target.deviceHash else { throw LiveCasFailure.authority }
            let remote = CatalogRemoteSupabaseAdapter(remote: SupabaseTransportClient(clientProvider: provider))
            let device = ShopDeviceRegistrationService(clientProvider: provider)
            func requireCurrent() throws {
                guard provider.authSnapshot.generation == authGeneration,
                      provider.client.auth.currentSession?.user.id == scope.ownerUserID,
                      provider.client.auth.currentSession?.isExpired == false,
                      try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: scope.ownerUserID) == scope
                else { throw LiveCasFailure.authority }
            }
            func read(collision: Bool = false) async throws -> [RemoteInventoryProductRow] {
                try requireCurrent()
                var query = provider.client.from("inventory_products").select(CatalogRemoteSupabaseAdapter.productColumns)
                    .eq("owner_user_id", value: scope.ownerUserID.uuidString).eq("shop_id", value: scope.shopID.uuidString)
                query = collision ? query.or("id.eq.\(productID.uuidString),barcode.eq.\(fixture.barcode)")
                    : query.eq("id", value: productID.uuidString)
                let rows: [RemoteInventoryProductRow] = try await observed(
                    collision ? "inventory_products_collision_select" : "inventory_products_id_select", phase: "readback") {
                        try await query.limit(3).execute().value
                    }
                try requireCurrent()
                return rows
            }
            func payload(_ name: String) -> SyncAutomaticProductUpdatePayload {
                .init(barcode: nil, itemNumber: nil, productName: name, secondProductName: nil,
                      purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil, deletedAt: nil)
            }
            receipt["manifest_sha256"] = expectedHash
            receipt["artifact_sha256"] = manifest.target.nativeArtifactHash
            receipt["project_sha256"] = Self.liveTestProjectHash
            receipt["owner_sha256"] = manifest.target.ownerHash
            receipt["shop_sha256"] = manifest.target.shopHash
            receipt["device_sha256"] = manifest.target.deviceHash
            receipt["fixture_id"] = fixture.productId
            receipt["stage"] = "collision_read"
            guard try await read(collision: true).isEmpty else { throw LiveCasFailure.collision }
            try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                _ = try await observed("device_authorization", phase: "pre_create") {
                    try await device.ensureActiveForCloudWrite(reason: "task145_live_cas")
                }
                try requireCurrent()
                receipt["stage"] = "create_dispatched"
                receipt["owned_remote_row_may_remain"] = true
                let created = try await observed("inventory_products_upsert", phase: "fixture_create") {
                    try await remote.createProducts([.init(
                    id: productID, ownerUserID: scope.ownerUserID, shopID: scope.shopID, barcode: fixture.barcode,
                    itemNumber: nil, productName: fixture.initial.productName, secondProductName: fixture.initial.secondProductName,
                    purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil)])
                }
                try requireCurrent()
                guard created.count == 1, let initial = created.first, initial.id == productID,
                      initial.ownerUserID == scope.ownerUserID, initial.shopID == scope.shopID,
                      initial.barcode == fixture.barcode, initial.deletedAt == nil,
                      initial.productName == fixture.initial.productName,
                      initial.secondProductName == fixture.initial.secondProductName else { throw LiveCasFailure.response }
                let version = SyncCatalogConditionalVersion(expectedUpdatedAt: initial.updatedAt, expectedDeletedAt: nil)
                try version.validate()
                receipt["v0"] = initial.updatedAt
                receipt["stage"] = "cas_one_dispatched"
                _ = try await observed("device_authorization", phase: "pre_cas_one") {
                    try await device.ensureActiveForCloudWrite(reason: "task145_live_cas_one")
                }
                try requireCurrent()
                let chosen = try await observed("inventory_products_conditional_patch", phase: "cas_one") {
                    try await remote.updateProductConditionally(id: productID,
                    payload: payload(fixture.chosen.productName), expectedVersion: version,
                    changedFields: ["productName", "secondProductName"])
                }
                try requireCurrent()
                guard chosen.count == 1, let accepted = chosen.first,
                      accepted.productName == fixture.chosen.productName, accepted.secondProductName == nil,
                      accepted.updatedAt != initial.updatedAt else { throw LiveCasFailure.response }
                receipt["cas_one_rows"] = chosen.count
                receipt["v1"] = accepted.updatedAt
                receipt["stage"] = "cas_stale_dispatched"
                _ = try await observed("device_authorization", phase: "pre_cas_stale") {
                    try await device.ensureActiveForCloudWrite(reason: "task145_live_cas_stale")
                }
                try requireCurrent()
                let stale = try await observed("inventory_products_conditional_patch", phase: "cas_stale") {
                    try await remote.updateProductConditionally(id: productID,
                        payload: payload(fixture.staleRejectedName), expectedVersion: version, changedFields: ["productName"])
                }
                try requireCurrent()
                guard stale.isEmpty else { throw LiveCasFailure.response }
                receipt["cas_stale_rows"] = stale.count
                let after = try await read()
                guard after.count == 1, let row = after.first, row.id == productID,
                      row.updatedAt == accepted.updatedAt, row.deletedAt == nil,
                      row.productName == fixture.chosen.productName, row.secondProductName == nil else { throw LiveCasFailure.response }
                receipt["readback_selected_fields_match"] = true
            }
            // Deliberately stale TaskLocal scope: no persisted account/shop preference is changed.
            let foreign = Task126VerifiedOwnerStoreScope(ownerUserID: UUID(), accountHash: scope.accountHash,
                shopID: scope.shopID, storeIdentity: scope.storeIdentity, deviceInstallID: scope.deviceInstallID,
                deviceIdentityHash: scope.deviceIdentityHash, pendingReplacement: scope.pendingReplacement,
                leaseGeneration: scope.leaseGeneration)
            var scopeDenied = false
            do {
                _ = try await Task126OwnerStoreGate.withAutomaticScope(foreign) {
                    try await remote.updateProductConditionally(id: productID, payload: payload(fixture.staleRejectedName),
                        expectedVersion: .init(expectedUpdatedAt: "2000-01-01T00:00:00Z", expectedDeletedAt: nil),
                        changedFields: ["productName"])
                }
            } catch let error as Task126OwnerStoreGateError { scopeDenied = error == .activeAccountMismatch }
            guard scopeDenied else { throw LiveCasFailure.authority }
            try requireCurrent()
            let final = try await read()
            guard final.count == 1, final.first?.updatedAt == (receipt["v1"] as? String),
                  final.first?.productName == fixture.chosen.productName,
                  final.first?.secondProductName == nil, final.first?.deletedAt == nil else { throw LiveCasFailure.response }
            receipt["client_scope_fence_negative"] = true
            receipt["rls_foreign_scope_acceptance"] = "NOT_RUN"
            receipt["status"] = "PASS_CAS_BOUNDARY_ONLY"
            receipt["stage"] = "completed_retained_for_peer_readback"
        } catch {
            receipt["status"] = "FAIL"
            receipt.merge(Self.liveErrorFields(error)) { _, new in new }
            XCTFail("TASK145 live CAS failed; sanitized stage/error type are in its receipt. No automatic cleanup or retry.")
        }
    }

#if DEBUG
    /// Passive admission/export in the existing ordinary app host. It never
    /// writes business data, drives UI, starts sync, or manufactures a session.
    @MainActor
    func testTask145B6ObserveOrdinaryWindowWhenEnabled() async throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["TEST_RUNNER_TASK145_B6_OBSERVE"] == "1", "B6 observation is explicitly gated.")
        var b6LastStage = "ordinary-host-guard"
        var b6PrimaryFailureStage: String?
        defer {
            // Closed stage names only: no binding, payload, session or error values.
            NSLog("%@", "TASK145_B6_TERMINAL_STAGE last=\(b6LastStage) primary=\(b6PrimaryFailureStage ?? "none")")
        }
        guard Bundle.main.bundleIdentifier == "com.niwcyber.iOSMerchandiseControl",
              Task144LocalAvailabilityRootFixture.current == nil else { throw B6HarnessFailure.ordinaryHost }
        b6LastStage = "binding-input-read"
        let bindingInput = try Self.b6ReadCacheInput(try XCTUnwrap(environment["TEST_RUNNER_TASK145_B6_BINDING_PATH"]),
            basename: "peer-binding.json", maximumBytes: 16_384)
        let bindingData = bindingInput.data
        guard !bindingData.isEmpty, bindingData.count <= 16_384 else { throw B6HarnessFailure.binding }
        b6LastStage = "binding-decode"
        let binding = try JSONDecoder().decode(PilotCommitTrace.B6Binding.self, from: bindingData)
        guard UUID(uuidString: binding.operationID) == bindingInput.operationID else {
            throw B6HarnessFailure.binding
        }
        let bindingObject = try XCTUnwrap(JSONSerialization.jsonObject(with: bindingData) as? [String: Any])
        let causalMode = binding.timingMethod == PilotCommitTrace.b6CausalTimingMethod
        let runtimeScopeMode = binding.scopeBindingMethod == PilotCommitTrace.b6ScopeBindingMethod
        guard binding.scopeBindingMethod == nil || runtimeScopeMode,
              runtimeScopeMode ? causalMode && binding.scopeHash == nil && !bindingObject.keys.contains("scopeHash") &&
                    ["runtime_scope_proof_raw", "runtime_scope_proof_sha256", "lease_generation", "harness_auth_generation"]
                        .allSatisfy({ bindingObject[$0] == nil }) &&
                    binding.persistentScopeHash.map(Self.b6IsHash) == true
                : binding.persistentScopeHash == nil && binding.scopeHash.map(Self.b6IsHash) == true &&
                    bindingObject["scopeBindingMethod"] == nil && bindingObject["persistentScopeHash"] == nil else {
            throw B6HarnessFailure.scopeBinding
        }
        b6LastStage = "manifest-input-read"
        let manifestData = try Self.b6ReadCacheInput(try XCTUnwrap(environment["TEST_RUNNER_TASK145_B6_MANIFEST_PATH"]),
            basename: "manifest.json", operationID: binding.operationID, maximumBytes: 256 * 1_024).data
        guard manifestData.count <= 256 * 1_024, Self.liveHash(manifestData) == binding.manifestHash,
              let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [String: Any],
              manifest["status"] as? String == "AUTHORIZED_FOR_B6_EVIDENCE",
              manifest["campaign"] as? String == "mobile-sync-execution-20261016-resume",
              manifest["schedule_sha256"] as? String == "218ea245ce109ce90b154a0778e2b91de951a964d410750bbea459ba40c5056e",
              let cas = manifest["cas_prerequisite"] as? [String: Any],
              cas["planned_manifest_sha256"] as? String == "94ecbf580936f36a0aae569e85a3a5eb5508cdbc4d99a796185d3c18e37678c0",
              let iosCAS = cas["ios_native_receipt_sha256"] as? String, Self.b6IsHash(iosCAS),
              let androidCAS = cas["android_native_receipt_sha256"] as? String, Self.b6IsHash(androidCAS),
              Self.liveHash(Data((iosCAS + "\n" + androidCAS).utf8)) == binding.twoCASReceiptHash,
              let admission = manifest["coordinator_admission_sha256"] as? String, Self.b6IsHash(admission),
              let conditions = manifest["runtime_conditions_sha256"] as? String, Self.b6IsHash(conditions),
              let directions = manifest["directions"] as? [String: [String: Any]],
              let pins = directions[binding.role == "source" ? "ios_to_android" : "android_to_ios"],
              pins["ordinary_preflight_sha256"] as? String == binding.authPreflightHash,
              let slots = manifest["slots"] as? [[String: Any]] else { throw B6HarnessFailure.manifest }
        guard binding.timingMethod == nil || causalMode,
              causalMode ? manifest["timing_method"] as? String == PilotCommitTrace.b6CausalTimingMethod
                && manifest["timing_method_review_sha256"] as? String == "eaa91da232992c7c27f0a3eb635c867cb0a8e40300c65ca56dec005b2f92ea80"
                : manifest["timing_method"] as? String != PilotCommitTrace.b6CausalTimingMethod else {
            throw B6HarnessFailure.causalMethod
        }
        let selected = slots.filter { $0["sample_id"] as? String == binding.sampleID }
        guard selected.count == 1, let slot = selected.first, slot["category"] as? String == binding.category,
              let fixture = slot["fixture"] as? [String: Any], fixture["status"] as? String == "READY_FOR_SAMPLE",
              fixture["ios_\(binding.role)_expected_local_body_sha256"] as? String == binding.expectedLocalBodyHash,
              fixture["ios_expected_visible_fields"] as? [String: String] == binding.expectedVisibleFields,
              fixture["ios_baseline_visible_fields"] as? [String: String] == binding.baselineVisibleFields,
              let collision = fixture["collision_read_sha256"] as? String, Self.b6IsHash(collision),
              let readback = fixture["prerequisite_readback_sha256"] as? String, Self.b6IsHash(readback) else { throw B6HarnessFailure.manifest }
        if runtimeScopeMode {
            guard fixture["ios_\(binding.role)_scope_binding_method"] as? String == PilotCommitTrace.b6ScopeBindingMethod,
                  fixture["ios_\(binding.role)_persistent_scope_sha256"] as? String == binding.persistentScopeHash else {
                throw B6HarnessFailure.scopeBinding
            }
        } else if fixture["ios_\(binding.role)_scope_binding_method"] != nil || fixture["ios_\(binding.role)_persistent_scope_sha256"] != nil {
            throw B6HarnessFailure.scopeBinding
        }
        let identityKey = binding.category == "price" ? "price_id" : binding.category == "history" ? "history_id" : "product_id"
        if let rawID = fixture[identityKey] as? String, UUID(uuidString: rawID) == nil { throw B6HarnessFailure.manifest }
        let fixtureID = (fixture[identityKey] as? String).flatMap(UUID.init(uuidString:))
        guard fixtureID == binding.entityRemoteID,
              fixtureID != nil || ["create", "price"].contains(binding.category),
              binding.expectedBarcode == nil || fixture["barcode"] as? String == binding.expectedBarcode,
              binding.parentRemoteID == nil || (fixture["product_id"] as? String).flatMap(UUID.init(uuidString:)) == binding.parentRemoteID,
              binding.expectedParentBodyHash == nil || fixture["ios_expected_parent_body_sha256"] as? String == binding.expectedParentBodyHash,
              binding.baselineLocalBodyHash == nil || fixture["ios_baseline_local_body_sha256"] as? String == binding.baselineLocalBodyHash else { throw B6HarnessFailure.manifest }
        let config = try SupabaseConfig.load(bundle: .main)
        let artifact = Self.liveHash(try Data(contentsOf: XCTUnwrap(Bundle.main.executableURL)))
        guard Self.liveHash(Data(config.projectURL.absoluteString.utf8)) == Self.liveTestProjectHash,
              artifact == binding.artifactHash, pins["\(binding.role)_artifact_sha256"] as? String == artifact else { throw B6HarnessFailure.artifact }
        let provider = SupabaseClientProvider(config: config)
        b6LastStage = "ordinary-session"
        let session = try await provider.client.auth.session
        guard !session.isExpired else { throw B6HarnessFailure.authority }
        let generation = provider.authSnapshot.generation
        // Ordinary restoration may still be resolving the persisted shop when XCTest starts.
        // Wait only for real scope/body admission; never select a shop or manufacture readiness.
        func captureOrdinaryScopeWhenReady() async throws -> Task126VerifiedOwnerStoreScope {
            let setupStarted = PilotCommitTrace.b6Now()
            let setupDeadline = setupStarted + 30_000_000_000
            var firstCondition: String?
            var terminal = "failed"
            defer {
                NSLog("%@", "TASK145_B6_SCOPE_SETUP first.\(firstCondition ?? "not-observed") elapsed-ns.\(PilotCommitTrace.b6Now() - setupStarted) terminal.\(Task.isCancelled ? "cancelled" : terminal)")
            }
            while true {
                try Task.checkCancellation()
                guard PilotCommitTrace.b6Now() < setupDeadline else {
                    terminal = "setup-timeout"
                    throw B6HarnessFailure.authority
                }
                guard provider.authSnapshot.generation == generation,
                      provider.client.auth.currentSession?.user.id == session.user.id,
                      provider.client.auth.currentSession?.isExpired == false,
                      !session.isExpired else {
                    if firstCondition == nil { firstCondition = "authority-denied" }
                    throw B6HarnessFailure.authority
                }
                let scope: Task126VerifiedOwnerStoreScope
                do {
                    scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: session.user.id)
                } catch let error as Task126OwnerStoreGateError {
                    // A resolved-but-invalid shop and every other denial remain immediate failures.
                    guard error == .shopContextUnavailable else {
                        if firstCondition == nil { firstCondition = "scope-denied" }
                        throw error
                    }
                    let resolutionReady = SelectedShopStore().isResolutionReady(accountHash:
                        AccountBindingStore.accountHash(for: session.user.id))
                    if firstCondition == nil {
                        firstCondition = resolutionReady ? "shop-ready-denied" : "shop-unresolved"
                    }
                    guard !resolutionReady else {
                        terminal = "shop-ready-denied"
                        throw error
                    }
                    try await Task.sleep(nanoseconds: 20_000_000)
                    continue
                }
                if firstCondition == nil { firstCondition = "scope-captured" }
                guard (runtimeScopeMode ? PilotCommitTrace.b6PersistentScopeIdentity(scope)?.sha256 == binding.persistentScopeHash
                        : PilotCommitTrace.b6ScopeHash(scope) == binding.scopeHash),
                      Self.liveHash(Data(scope.ownerUserID.uuidString.lowercased().utf8)) == pins["owner_sha256"] as? String,
                      Self.liveHash(Data(scope.shopID.uuidString.lowercased().utf8)) == pins["shop_sha256"] as? String,
                      Self.liveHash(Data(scope.deviceInstallID.utf8)) == pins["\(binding.role)_device_sha256"] as? String else { throw B6HarnessFailure.authority }
                if Task126OwnerStoreGate.localBodyProofAdmissionGeneration() == scope.leaseGeneration {
                    guard PilotCommitTrace.b6Now() < setupDeadline else {
                        terminal = "setup-timeout"
                        throw B6HarnessFailure.authority
                    }
                    terminal = "admitted"
                    return scope
                }
                try await Task.sleep(nanoseconds: 20_000_000)
            }
        }
        b6LastStage = "ordinary-scope-setup"
        let scope = try await captureOrdinaryScopeWhenReady()
        func requireCurrent() throws {
            b6LastStage = "require-current-auth"
            guard provider.authSnapshot.generation == generation,
                  provider.client.auth.currentSession?.user.id == scope.ownerUserID,
                  provider.client.auth.currentSession?.isExpired == false else { throw B6HarnessFailure.authority }
            b6LastStage = "require-current-capture-scope"
            let current = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: scope.ownerUserID)
            b6LastStage = "require-current-full-scope-guard"
            guard current == scope,
                  !runtimeScopeMode || PilotCommitTrace.b6RuntimeScopeMatches(current: current, frozen: scope) else {
                throw B6HarnessFailure.authority
            }
        }
        // These existing guards read only captured expiry and two in-memory
        // generation locks. Full SDK/storage/scope validation stays at admission,
        // after terminal observation and at export; real writer/mapper/render
        // boundaries retain their own production scope validation throughout.
        func requireValueEpoch() throws {
            b6LastStage = "require-value-epoch"
            guard provider.acceptsAuthGeneration(generation), !session.isExpired,
                  Task126OwnerStoreGate.localBodyProofAdmissionGeneration() == scope.leaseGeneration else { throw B6HarnessFailure.authority }
        }
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CodexPilotTrace", isDirectory: true).appendingPathComponent("b6", isDirectory: true)
            .appendingPathComponent(binding.operationID, isDirectory: true)
        guard UUID(uuidString: binding.operationID) != nil, !FileManager.default.fileExists(atPath: directory.path) else { throw B6HarnessFailure.output }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        func write(_ object: [String: Any], name: String) throws {
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            guard data.count <= 256 * 1_024 else { throw B6HarnessFailure.output }
            let destination = directory.appendingPathComponent(name)
            guard !FileManager.default.fileExists(atPath: destination.path) else { throw B6HarnessFailure.output }
            try data.write(to: destination, options: .atomic)
        }
        func attach(_ object: [String: Any], name: String) throws {
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        func nonce(_ name: String, deadline: UInt64) async throws -> String {
            let url = directory.appendingPathComponent(name)
            while !FileManager.default.fileExists(atPath: url.path) {
                b6LastStage = "nonce-before-value-epoch"
                try requireValueEpoch()
                b6LastStage = "nonce-after-value-epoch"
                b6LastStage = "nonce-before-cancellation-check"
                try Task.checkCancellation()
                b6LastStage = "nonce-after-cancellation-check"
                guard PilotCommitTrace.b6Now() < deadline else { throw B6HarnessFailure.clockTimeout }
                b6LastStage = "nonce-before-sleep"
                do {
                    try await Task.sleep(nanoseconds: 20_000_000)
                } catch {
                    b6LastStage = "nonce-sleep-threw"
                    let failure = error as NSError
                    NSLog("%@", "TASK145_B6_NONCE_SLEEP_ERROR type.\(String(reflecting: type(of: error))) domain.\(failure.domain) code.\(failure.code)")
                    // This is the catch-site stack, not the original throw stack.
                    for frame in Thread.callStackSymbols {
                        NSLog("%@", "TASK145_B6_NONCE_SLEEP_CATCH_STACK \(frame)")
                    }
                    throw error
                }
                b6LastStage = "nonce-after-sleep"
            }
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
            guard values.isSymbolicLink != true, let size = values.fileSize, (1...64).contains(size),
                  let value = String(data: try Data(contentsOf: url), encoding: .utf8), UUID(uuidString: value) != nil else { throw B6HarnessFailure.clockNonce }
            return value
        }
        // New replies are immutable files owned by this one participant. No
        // exported witness/preview is ever written while a writer lock is held.
        func writeCausal(_ object: [String: Any], name: String) throws -> String {
            let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            guard data.count <= 512 * 1_024 else { throw B6HarnessFailure.output }
            let destination = directory.appendingPathComponent(name)
            try data.write(to: destination, options: .withoutOverwriting)
            let file = try FileHandle(forWritingTo: destination)
            try file.synchronize(); try file.close()
            return Self.liveHash(data)
        }
        let sourceAdmission = directory.appendingPathComponent("source-admission-nonce.txt")
        let causalPreviewURL = directory.appendingPathComponent("causal-trace-preview.json")
        if causalMode {
            guard !FileManager.default.fileExists(atPath: sourceAdmission.path),
                  !FileManager.default.fileExists(atPath: causalPreviewURL.path) else { throw B6HarnessFailure.causalNonce }
        }
        if environment["TEST_RUNNER_TASK145_B6_PREPARATION_ONLY"] == "1" {
            let exitNonce = try XCTUnwrap(environment["TEST_RUNNER_TASK145_B6_PREPARATION_EXIT_NONCE"])
            guard UUID(uuidString: exitNonce) != nil, exitNonce != binding.sourceAdmissionNonce else { throw B6HarnessFailure.binding }
            try requireCurrent(); try requireValueEpoch()
            let storeIdentityData=try JSONEncoder().encode(scope.storeIdentity)
            let decodedStoreIdentity=try JSONDecoder().decode(LocalStoreIdentity.self,from:storeIdentityData)
            let storeIdentityShape=try JSONSerialization.jsonObject(with:storeIdentityData)
            guard decodedStoreIdentity==scope.storeIdentity,storeIdentityShape is [String:Any] else { throw B6HarnessFailure.binding }
            let ready: [String: Any] = ["stage":"PREPARATION_HOST_READY", "operation_id":binding.operationID,
                "manifest_sha256":binding.manifestHash,"participant_pid":ProcessInfo.processInfo.processIdentifier,
                "artifact_sha256":binding.artifactHash,"directory":directory.path,"nativeAcceptance":false,
                "exit_path":directory.appendingPathComponent("preparation-exit-nonce.txt").path,"store_identity_keyed_roundtrip":true]
            try write(ready,name:"preparation-host-ready.json")
            let observed = try await nonce("preparation-exit-nonce.txt",deadline:PilotCommitTrace.b6Now()+30_000_000_000)
            guard observed == exitNonce else { throw B6HarnessFailure.clockNonce }
            try requireCurrent(); try requireValueEpoch()
            let terminal: [String: Any] = ["stage":"PREPARATION_HOST_TERMINAL", "operation_id":binding.operationID,
                "manifest_sha256":binding.manifestHash,"status":"NOT_B6_ACCEPTANCE","nativeAcceptance":false]
            try write(terminal,name:"preparation-host-terminal.json"); try attach(terminal,name:"preparation-host-terminal")
            return
        }
        var ready: [String: Any] = ["stage": "READY_FOR_NONCE", "operation_id": binding.operationID,
            "directory": directory.path, "request_path": directory.appendingPathComponent("calibration-nonce.txt").path,
            "native_acceptance": false]
        if causalMode {
            ready["timing_method"] = PilotCommitTrace.b6CausalTimingMethod
            ready["causal_trace_preview_path"] = causalPreviewURL.path
            if binding.role == "source" {
                ready["source_admission_request_path"] = sourceAdmission.path
                ready["source_idle_witness_path"] = directory.appendingPathComponent("source-idle-witness.json").path
            }
        }
        try requireCurrent()
        try requireValueEpoch()
        b6LastStage = "ready-write"
        try write(ready, name: "ready.json"); try attach(ready, name: "b6-ready-\(binding.operationID)")
        // Same existing host-file nonce exchange. The host records send/receive;
        // these native reads never invent the host interval or wall-clock offset.
        b6LastStage = "first-clock-nonce"
        let firstNonce = try await nonce("calibration-nonce.txt", deadline: PilotCommitTrace.b6Now() + 30_000_000_000)
        if causalMode, binding.role == "source", binding.sourceAdmissionNonce == firstNonce {
            throw B6HarnessFailure.causalNonce
        }
        try requireCurrent()
        b6LastStage = "trace-arm"
        let armed = runtimeScopeMode
            ? PilotCommitTrace.b6Arm(binding, runtimeScope: scope, harnessAuthGeneration: generation,
                predeclaredBindingSHA256: Self.liveHash(bindingData))
            : PilotCommitTrace.b6Arm(binding)
        guard armed else { throw B6HarnessFailure.binding }
        var primaryFailure: Error?
        var secondaryTypes: [String] = []
        var finalReceipt: PilotCommitTrace.B6Receipt?
        var postClockObserved = false
        var causalWitnessSHA256: String?
        var causalPreviewSHA256: String?
        var coexistenceReplied = false
        var runtimeScopeProof: (raw: String, sha256: String)?
        do {
            try requireCurrent()
            if runtimeScopeMode {
                b6LastStage = "runtime-scope-proof"
                guard let proof = PilotCommitTrace.b6RuntimeScopeProof() else { throw B6HarnessFailure.scopeBinding }
                runtimeScopeProof = proof
            }
            b6LastStage = "first-calibration"
            let first = try XCTUnwrap(PilotCommitTrace.b6Calibration(nonce: firstNonce))
            var firstReply: [String: Any] = ["stage": "CALIBRATION_REPLY", "operation_id": binding.operationID,
                "nonce": first.nonce, "clock_id": first.clockID, "native_ns": String(first.nativeNS),
                "participant_pid": first.participantPID, "participant_boot_sha256": first.bootHash,
                "artifact_sha256": artifact, "device_sha256": Self.liveHash(Data(scope.deviceInstallID.utf8)),
                "ordinary_preflight_sha256": binding.authPreflightHash, "manifest_sha256": binding.manifestHash]
            if let proof = runtimeScopeProof {
                firstReply["runtime_scope_proof_raw"] = proof.raw
                firstReply["runtime_scope_proof_sha256"] = proof.sha256
            }
            try requireCurrent()
            b6LastStage = "first-calibration-write"
            try write(firstReply, name: "calibration-before.json")
            // A host may consume the immutable file after this last local check.
            // Later revocation invalidates qualification, never grants authority.
            try requireCurrent()
            let causalIdentity: [String: Any] = ["clock_id": first.clockID,
                "participant_pid": first.participantPID, "participant_boot_sha256": first.bootHash,
                "artifact_sha256": artifact, "device_sha256": Self.liveHash(Data(scope.deviceInstallID.utf8)),
                "ordinary_preflight_sha256": binding.authPreflightHash]
            // The existing observation deadline includes admission/challenge work;
            // a new nonce never starts a fresh business observation window.
            let deadline = PilotCommitTrace.b6Now() + 40_000_000_000
            while true {
                try requireValueEpoch(); try Task.checkCancellation()
                if causalMode, PilotCommitTrace.b6Now() >= deadline { throw B6HarnessFailure.observationTimeout }
                b6LastStage = "observation-state"
                let state = PilotCommitTrace.b6ObservationState()
                guard state.invalidReason == nil else { throw B6HarnessFailure.observerInvalid }
                // A testmanager liveness diagnostic only: no business mutation, trace event or UI-ready claim.
                if environment["TEST_RUNNER_TASK145_B6_COEXISTENCE_PROBE"] == "1", !coexistenceReplied,
                   FileManager.default.fileExists(atPath: directory.appendingPathComponent("coexistence-liveness-nonce.txt").path) {
                    guard causalMode, binding.role == "peer", !state.terminal else { throw B6HarnessFailure.binding }
                    let challenge = try await nonce("coexistence-liveness-nonce.txt", deadline: deadline)
                    guard challenge != firstNonce, challenge != binding.sourceAdmissionNonce else { throw B6HarnessFailure.clockNonce }
                    try requireCurrent(); try requireValueEpoch(); try Task.checkCancellation()
                    guard PilotCommitTrace.b6Now() < deadline,
                          PilotCommitTrace.b6ObservationState().invalidReason == nil else { throw B6HarnessFailure.observerInvalid }
                    try write(["kind":"SAME_MAIN_HOSTED_UNIT_LIVENESS", "operation_id":binding.operationID,
                        "nonce":challenge,"participant_pid":ProcessInfo.processInfo.processIdentifier,
                        "participant_boot_sha256":first.bootHash,"artifact_sha256":artifact,
                        "native_ns":PilotCommitTrace.b6Now(),"within_original_observation_deadline":true], name:"coexistence-liveness.json")
                    coexistenceReplied = true
                }
                if causalMode, binding.role == "source", causalWitnessSHA256 == nil,
                   FileManager.default.fileExists(atPath: sourceAdmission.path) {
                    let admissionNonce = try await nonce("source-admission-nonce.txt", deadline: deadline)
                    guard admissionNonce == binding.sourceAdmissionNonce, admissionNonce != firstNonce else {
                        throw B6HarnessFailure.causalNonce
                    }
                    try requireCurrent()
                    guard let witness = PilotCommitTrace.b6CausalSourceIdleWitness(nonce: admissionNonce) else {
                        throw B6HarnessFailure.causalWitness
                    }
                    try requireValueEpoch()
                    var witnessObject: [String: Any] = ["kind": "B6_SOURCE_IDLE_WITNESS",
                        "timing_method": PilotCommitTrace.b6CausalTimingMethod,
                        "operation_id": binding.operationID, "manifest_sha256": binding.manifestHash,
                        "nonce": admissionNonce, "identity": causalIdentity,
                        "native_ns": witness.nativeNS, "trace_prefix_raw": witness.tracePrefixRaw,
                        "trace_prefix_sha256": witness.tracePrefixSHA256,
                        "trace_event_count": witness.traceEventCount,
                        "source_idle_state": witness.sourceIdleState]
                    if let proof = runtimeScopeProof { witnessObject["runtime_scope_proof_sha256"] = proof.sha256 }
                    causalWitnessSHA256 = try writeCausal(witnessObject, name: "source-idle-witness.json")
                }
                if state.terminal {
                    if causalMode {
                        try requireCurrent()
                        guard binding.role != "source" || causalWitnessSHA256 != nil,
                              let preview = PilotCommitTrace.b6CausalTracePreview(),
                              !runtimeScopeMode || preview.receipt.runtime_scope_proof_sha256 == runtimeScopeProof?.sha256 else {
                            throw B6HarnessFailure.causalPreview
                        }
                        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                        let encoded = try encoder.encode(preview.receipt)
                        var snapshot = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
                        snapshot["status"] = "OBSERVATIONS_ONLY_CAUSAL_PREVIEW"
                        snapshot["authority_current_at_preview"] = true
                        let snapshotData = try JSONSerialization.data(withJSONObject: snapshot, options: [.sortedKeys])
                        let receiptRaw = try XCTUnwrap(String(data: snapshotData, encoding: .utf8))
                        try requireCurrent()
                        var previewObject: [String: Any] = ["kind": "B6_CAUSAL_TRACE_PREVIEW",
                            "timing_method": PilotCommitTrace.b6CausalTimingMethod,
                            "operation_id": binding.operationID, "manifest_sha256": binding.manifestHash,
                            "role": binding.role, "identity": causalIdentity,
                            "receipt_raw": receiptRaw, "receipt_sha256": Self.liveHash(snapshotData),
                            "trace_prefix_raw": preview.traceRaw,
                            "trace_prefix_sha256": Self.liveHash(Data(preview.traceRaw.utf8)),
                            "trace_event_count": preview.receipt.events.count]
                        if let proof = runtimeScopeProof { previewObject["runtime_scope_proof_sha256"] = proof.sha256 }
                        causalPreviewSHA256 = try writeCausal(previewObject, name: "causal-trace-preview.json")
                    }
                    if causalMode, PilotCommitTrace.b6Now() >= deadline { throw B6HarnessFailure.observationTimeout }
                    break
                }
                guard PilotCommitTrace.b6Now() < deadline else { throw B6HarnessFailure.observationTimeout }
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            try requireCurrent()
            // A second host nonce must be sent after the terminal observation,
            // not pre-provisioned alongside the first calibration.
            guard !FileManager.default.fileExists(atPath: directory.appendingPathComponent("calibration-after-nonce.txt").path) else { throw B6HarnessFailure.clockNonce }
            b6LastStage = "post-calibration-ready"
            try write(["stage": "READY_FOR_POST_CALIBRATION", "operation_id": binding.operationID], name: "ready-after.json")
            b6LastStage = "second-clock-nonce"
            let secondNonce = try await nonce("calibration-after-nonce.txt", deadline: PilotCommitTrace.b6Now() + 10_000_000_000)
            guard secondNonce != firstNonce,
                  !causalMode || binding.role != "source" || secondNonce != binding.sourceAdmissionNonce else {
                throw B6HarnessFailure.clockNonce
            }
            try requireCurrent()
            b6LastStage = "second-calibration"
            let second = try XCTUnwrap(PilotCommitTrace.b6Calibration(nonce: secondNonce))
            var secondReply: [String: Any] = ["stage": "CALIBRATION_REPLY", "operation_id": binding.operationID,
                "nonce": second.nonce, "clock_id": second.clockID, "native_ns": String(second.nativeNS),
                "participant_pid": second.participantPID, "participant_boot_sha256": second.bootHash,
                "artifact_sha256": artifact, "device_sha256": Self.liveHash(Data(scope.deviceInstallID.utf8)),
                "ordinary_preflight_sha256": binding.authPreflightHash, "manifest_sha256": binding.manifestHash]
            if let proof = runtimeScopeProof { secondReply["runtime_scope_proof_sha256"] = proof.sha256 }
            try requireCurrent()
            b6LastStage = "second-calibration-write"
            try write(secondReply, name: "calibration-after.json")
            try requireCurrent()
            postClockObserved = true
        } catch { b6PrimaryFailureStage = b6LastStage; primaryFailure = error }
        b6LastStage = "receipt-disarm"
        finalReceipt = PilotCommitTrace.b6ReceiptAndDisarm()
        do {
            b6LastStage = "receipt-unwrap"
            let receipt = try XCTUnwrap(finalReceipt)
            b6LastStage = "receipt-encode"
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(receipt)) as? [String: Any])
            let current = (try? requireCurrent()) != nil
            let causalComplete = !causalMode || (causalPreviewSHA256 != nil &&
                (binding.role != "source" || causalWitnessSHA256 != nil))
            let scopeProofComplete = !runtimeScopeMode || (runtimeScopeProof != nil &&
                receipt.runtime_scope_proof_sha256 == runtimeScopeProof?.sha256)
            let complete = primaryFailure == nil && current && postClockObserved && receipt.observationComplete && causalComplete && scopeProofComplete
            if causalMode {
                object["timing_method"] = PilotCommitTrace.b6CausalTimingMethod
                object["causal_trace_preview_sha256"] = causalPreviewSHA256 as Any? ?? NSNull()
                if binding.role == "source" { object["causal_source_witness_sha256"] = causalWitnessSHA256 as Any? ?? NSNull() }
            }
            object["status"] = complete ? "OBSERVATIONS_ONLY_EXTERNAL_VISIBILITY_AND_JOIN_REQUIRED" : "FAIL_OBSERVATION_INCOMPLETE"
            object["authority_current_at_end"] = current; object["post_clock_observed"] = postClockObserved
            object["primary_error_type"] = primaryFailure.map { String(reflecting: type(of: $0)) as Any } ?? NSNull()
            object["primary_error_code"] = (primaryFailure as? B6HarnessFailure).map { $0.rawValue as Any } ?? NSNull()
            object["external_ax_and_screenshot"] = "REQUIRED_NOT_CAPTURED_BY_APP_HOST"
            object["native_acceptance"] = false
            b6LastStage = "receipt-write"
            try write(object, name: "receipt.json"); try attach(object, name: "b6-observations-\(binding.operationID)")
            if !complete && primaryFailure == nil { primaryFailure = B6HarnessFailure.incomplete }
        } catch {
            secondaryTypes.append(String(reflecting: type(of: error)))
            if primaryFailure == nil { b6PrimaryFailureStage = b6LastStage; primaryFailure = error }
            // An export failure is additional evidence; the primary cause is retained.
            try? attach(["stage": "B6_EXPORT_FAILURE", "operation_id": binding.operationID,
                "primary_error_type": String(reflecting: type(of: primaryFailure!)),
                "secondary_error_types": secondaryTypes, "native_acceptance": false], name: "b6-export-failure")
        }
        if let primaryFailure { throw primaryFailure }
        b6LastStage = "completed"
    }
    @MainActor
    func testTask145B6NativeCacheInputReaderPreservesBytesAndRejectsUnsafeInputs() async throws {
        let manager = FileManager.default
        let cache = try XCTUnwrap(manager.urls(for: .cachesDirectory, in: .userDomainMask).first)
        let operationID = UUID()
        let relative = "CodexPilotB6Inputs/\(operationID.uuidString.lowercased())/peer-binding.json"
        let directory = cache.appendingPathComponent("CodexPilotB6Inputs", isDirectory: true)
            .appendingPathComponent(operationID.uuidString.lowercased(), isDirectory: true)
        try manager.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Only an exclusive mkdir success grants ownership for later cleanup.
        guard Darwin.mkdir(directory.path, mode_t(0o700)) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        defer { try? manager.removeItem(at: directory) }
        let input = directory.appendingPathComponent("peer-binding.json")
        let bytes = Data((0..<8_193).map { UInt8(truncatingIfNeeded: $0) })
        try bytes.write(to: input)
        let actual = try Self.b6ReadCacheInput(relative, basename: "peer-binding.json",
            maximumBytes: 16_384)
        XCTAssertEqual(actual.data, bytes)
        XCTAssertEqual(actual.operationID, operationID)

        XCTAssertThrowsError(try Self.b6ReadCacheInput(
            "CodexPilotB6Inputs/\(operationID.uuidString.lowercased())/../peer-binding.json",
            basename: "peer-binding.json", maximumBytes: 16_384))

        let alias = directory.appendingPathComponent("hard-link-alias")
        try manager.linkItem(at: input, to: alias)
        XCTAssertThrowsError(try Self.b6ReadCacheInput(relative, basename: "peer-binding.json",
            maximumBytes: 16_384))
        try manager.removeItem(at: alias)

        let payload = directory.appendingPathComponent("owned-payload")
        try manager.moveItem(at: input, to: payload)
        try manager.createSymbolicLink(at: input, withDestinationURL: payload)
        XCTAssertThrowsError(try Self.b6ReadCacheInput(relative, basename: "peer-binding.json",
            maximumBytes: 16_384))
        try manager.removeItem(at: input)

        try Data(repeating: 0xA5, count: 16_385).write(to: input)
        XCTAssertThrowsError(try Self.b6ReadCacheInput(relative, basename: "peer-binding.json",
            maximumBytes: 16_384))
        try manager.removeItem(at: directory)
        XCTAssertFalse(manager.fileExists(atPath: directory.path))
    }

    /// Resolve only the declared B6 input namespace inside this process's cache.
    private static func b6ReadCacheInput(_ path: String, basename: String,
        operationID: String? = nil, maximumBytes: Int) throws -> (data: Data, operationID: UUID) {
        let parts = path.components(separatedBy: "/")
        guard parts.count == 3, parts[0] == "CodexPilotB6Inputs",
              let inputOperation = UUID(uuidString: parts[1]),
              parts[1] == inputOperation.uuidString.lowercased(), parts[2] == basename,
              basename == "peer-binding.json" || basename == "manifest.json",
              operationID == nil || operationID.flatMap(UUID.init(uuidString:)) == inputOperation,
              maximumBytes > 0, maximumBytes <= 262_144,
              let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw B6HarnessFailure.binding
        }
        func sameObject(_ a: stat, _ b: stat) -> Bool {
            a.st_dev == b.st_dev && a.st_ino == b.st_ino && a.st_mode == b.st_mode &&
                a.st_uid == b.st_uid && a.st_gid == b.st_gid
        }
        func sameFile(_ a: stat, _ b: stat) -> Bool {
            sameObject(a, b) && a.st_nlink == b.st_nlink && a.st_size == b.st_size &&
                a.st_mtimespec.tv_sec == b.st_mtimespec.tv_sec && a.st_mtimespec.tv_nsec == b.st_mtimespec.tv_nsec &&
                a.st_ctimespec.tv_sec == b.st_ctimespec.tv_sec && a.st_ctimespec.tv_nsec == b.st_ctimespec.tv_nsec
        }
        let directoryFlags = O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        var directories: [Int32] = []
        defer { for descriptor in directories.reversed() { _ = Darwin.close(descriptor) } }
        let root = Darwin.open(cache.path, directoryFlags)
        guard root >= 0 else { throw B6HarnessFailure.binding }
        directories.append(root)
        for component in parts.prefix(2) {
            let child = Darwin.openat(directories[directories.count - 1], component, directoryFlags)
            guard child >= 0 else { throw B6HarnessFailure.binding }
            directories.append(child)
        }
        // NONBLOCK also makes a nonregular input fail without waiting on a FIFO.
        let file = Darwin.openat(directories[2], parts[2], O_RDONLY | O_NOFOLLOW | O_CLOEXEC | O_NONBLOCK)
        guard file >= 0 else { throw B6HarnessFailure.binding }
        defer { _ = Darwin.close(file) }
        var before = stat()
        guard Darwin.fstat(file, &before) == 0, (before.st_mode & S_IFMT) == S_IFREG,
              before.st_uid == Darwin.geteuid(), before.st_nlink == 1,
              before.st_size > 0, before.st_size <= off_t(maximumBytes) else { throw B6HarnessFailure.binding }
        let expectedCount = Int(before.st_size)
        var data = Data(); data.reserveCapacity(expectedCount)
        var buffer = [UInt8](repeating: 0, count: min(4_096, expectedCount))
        while data.count < expectedCount {
            let requested = min(buffer.count, expectedCount - data.count)
            let count = buffer.withUnsafeMutableBytes { Darwin.read(file, $0.baseAddress!, requested) }
            guard count > 0 else { throw B6HarnessFailure.binding }
            data.append(contentsOf: buffer.prefix(count))
        }
        var extra: UInt8 = 0
        guard Darwin.read(file, &extra, 1) == 0 else { throw B6HarnessFailure.binding }
        var after = stat(), linkedFile = stat()
        guard Darwin.fstat(file, &after) == 0, sameFile(before, after),
              Darwin.fstatat(directories[2], parts[2], &linkedFile, AT_SYMLINK_NOFOLLOW) == 0,
              sameFile(after, linkedFile) else { throw B6HarnessFailure.binding }
        // An opened old directory is insufficient if its named entry was swapped.
        for (index, component) in parts.prefix(2).enumerated() {
            var opened = stat(), linked = stat()
            guard Darwin.fstat(directories[index + 1], &opened) == 0,
                  Darwin.fstatat(directories[index], component, &linked, AT_SYMLINK_NOFOLLOW) == 0,
                  sameObject(opened, linked), (linked.st_mode & S_IFMT) == S_IFDIR else { throw B6HarnessFailure.binding }
        }
        var openedRoot = stat(), linkedRoot = stat()
        guard Darwin.fstat(root, &openedRoot) == 0, Darwin.lstat(cache.path, &linkedRoot) == 0,
              sameObject(openedRoot, linkedRoot), (linkedRoot.st_mode & S_IFMT) == S_IFDIR else { throw B6HarnessFailure.binding }
        return (data, inputOperation)
    }

    private static func b6IsHash(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) }
    }
    private enum B6HarnessFailure: String, Error {
        case ordinaryHost, binding, manifest, artifact, authority, output
        case clockTimeout, clockNonce, observerInvalid, observationTimeout, incomplete
        case causalMethod, causalNonce, causalWitness, causalPreview, scopeBinding
    }
#endif

    private static let liveTestProjectHash = "42a5d0119a30cb5f291bff1912a46e1092c77b483bbfed663785ef165260c842"
    private static func liveHash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    private static func liveErrorFields(_ error: Error) -> [String: Any] {
        var fields: [String: Any] = ["error_type": String(reflecting: type(of: error)),
            "http_status": "UNKNOWN_NOT_EXPOSED", "sqlstate": "UNKNOWN_NOT_EXPOSED"]
        func sqlstate(_ code: String?) {
            if let code, code.range(of: "^[0-9A-Z]{5}$", options: .regularExpression) != nil { fields["sqlstate"] = code }
        }
        if let error = error as? PostgrestError { sqlstate(error.code) }
        if let error = error as? SyncCatalogWriteRejectedWithoutCommit { sqlstate(error.sqlstate) }
        if let error = error as? URLError { fields["transport_code"] = error.code.rawValue }
        if let error = error as? SupabaseTransportClientError {
            switch error {
            case .networkError(let status, _): if let status { fields["http_status"] = status }
            case .permissionDeniedOrRLS(let status, let code, _):
                if let status { fields["http_status"] = status }; sqlstate(code)
            default: break
            }
        }
        return fields
    }
    private enum LiveCasFailure: Error { case manifest, artifact, authority, collision, response }
    nonisolated private struct LiveCasManifest: Decodable {
        nonisolated struct Target: Decodable {
            let projectRef, exactProjectUrlSha256, ownerHash, shopHash, deviceHash, nativeArtifactHash: String
        }
        nonisolated struct Values: Decodable { let productName: String; let secondProductName: String? }
        nonisolated struct Fixture: Decodable {
            let platform, productId, barcode, staleRejectedName: String
            let initial, chosen: Values
            let parents, prices, history: [String]
            let created: Bool
        }
        let status: String
        let target: Target
        let fixtures: [Fixture]
    }

    func testRejectsLegacyServiceRoleJWTButAllowsAnonJWTShape() throws {
        let anonKey = makeJWT(role: "anon")
        let anonConfig = try SupabaseConfig.load(bundle: makeConfigBundle(publishableKey: anonKey))
        XCTAssertEqual(anonConfig.publishableKey, anonKey)

        let serviceRoleKey = makeJWT(role: ["service", "role"].joined(separator: "_"))
        XCTAssertThrowsError(
            try SupabaseConfig.load(bundle: makeConfigBundle(publishableKey: serviceRoleKey))
        ) { error in
            guard case SupabaseConfigError.invalidConfig = error else {
                return XCTFail("Expected invalidConfig, got \(error)")
            }
        }
    }

    private func makeConfigBundle(publishableKey: String) throws -> Bundle {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        let config: [String: String] = [
            "SUPABASE_PROJECT_URL": "https://example.supabase.co",
            "SUPABASE_PUBLISHABLE_KEY": publishableKey
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: config,
            format: .xml,
            options: 0
        )
        try data.write(to: bundleURL.appendingPathComponent("SupabaseConfig.plist"))

        guard let bundle = Bundle(url: bundleURL) else {
            throw NSError(domain: "SupabaseConfigSecurityTests", code: 1)
        }
        return bundle
    }

    private func makeJWT(role: String) -> String {
        let header = base64URLString(["alg": "HS256", "typ": "JWT"])
        let payload = base64URLString(["iss": "supabase", "role": role])
        return "\(header).\(payload).signature"
    }

    private func base64URLString(_ object: [String: String]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func task103Hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
            .prefix(12)
            .description
    }

    private func isEnabled(_ value: String?) -> Bool {
        guard let normalized = value?.lowercased() else { return false }
        return normalized == "1" || normalized == "true"
    }
}
