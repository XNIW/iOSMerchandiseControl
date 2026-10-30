#if DEBUG
import Foundation
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class Task145SavedRecoveryControlTests: XCTestCase {
    private typealias Control = Task145SavedRecoveryControl
    private struct Context {
        var scope: Task126VerifiedOwnerStoreScope
        var manifest: SyncStoreGenerationManifest?
        var binding: AccountBinding?
        var replacement: AccountBinding?
        var wipeCommitted = false
        var journal: AccountRecoveryJournalSnapshot?
        var raw: Data?
    }
    private struct Sample {
        let control: Control
        let context: Context
        let payload: SyncAutomaticProductPricePayload
        let witness: Control.LocalPriceWitness
    }
    private struct RawJournal: Encodable {
        let replacement: AccountBinding
        let wipeCommitted: Bool
        let modeRaw: String
        let phaseRaw: String
        let deviceIdentityHash: String
        let generationID: UUID?
        let checkpointDigest: String?
        let watermark: Int64?
        let baselineRunID: UUID?
    }

    func testOriginalStagingRecoveryContextAcceptsExactSavedJournal() async throws {
        let sample = try sample()
        XCTAssertNotNil(sample.context.scope.pendingReplacement)
        XCTAssertNotNil(sample.context.journal)
        XCTAssertTrue(accepts(sample.control, sample.context))
        // This is the valid pre-bootstrap state rejected by the old nil guard.
        XCTAssertFalse(sample.context.scope.pendingReplacement == nil && sample.context.journal == nil)
        XCTAssertNil(sample.control.state.savedPriceID)
        XCTAssertTrue(sample.control.state.pricePayloads.isEmpty)
    }

    func testOriginalStagingRecoveryContextRejectsMissingCorruptOrChangedJournal() async throws {
        let sample = try sample()
        var context = sample.context
        context.journal = nil
        XCTAssertFalse(accepts(sample.control, context))
        context = sample.context; context.raw = nil
        XCTAssertFalse(accepts(sample.control, context))
        context = sample.context; context.raw = Data("{}".utf8)
        XCTAssertFalse(accepts(sample.control, context))
        // Even equal corrupt saved/current bytes cannot stand in for a journal.
        let original = sample.control.state.journalBytes
        sample.control.state.journalBytes = Data("{}".utf8)
        XCTAssertFalse(accepts(sample.control, context))
        sample.control.state.journalBytes = original
        let journal = try XCTUnwrap(sample.context.journal)
        for changed in [
            copied(journal, digest: "changed-checkpoint"),
            copied(journal, watermark: 42),
            copied(journal, baseline: UUID()),
            copied(journal, device: String(repeating: "f", count: 64)),
            copied(journal, replacement: AccountBinding(accountHash: journal.replacement.accountHash,
                storeIdentity: journal.replacement.storeIdentity,
                boundAt: journal.replacement.boundAt.addingTimeInterval(1)))
        ] {
            context = sample.context; context.journal = changed
            XCTAssertFalse(accepts(sample.control, context))
        }
        context = sample.context; context.wipeCommitted = true
        XCTAssertFalse(accepts(sample.control, context))
        let wiped = try raw(journal, wipeCommitted: true)
        sample.control.state.journalBytes = wiped; context = sample.context; context.raw = wiped
        XCTAssertFalse(accepts(sample.control, context))
        sample.control.state.journalBytes = original
        XCTAssertTrue(accepts(sample.control, sample.context))
    }

    func testOriginalStagingRecoveryContextRejectsReplacementModeAndOtherPhases() async throws {
        let sample = try sample(), journal = try XCTUnwrap(sample.context.journal)
        for changed in [copied(journal, mode: .accountOrShopReplacement),
                        copied(journal, phase: .prepared), copied(journal, phase: .verified),
                        copied(journal, phase: .activated)] {
            let bytes = try raw(changed)
            sample.control.state.journalBytes = bytes
            var context = sample.context; context.journal = changed; context.raw = bytes
            XCTAssertFalse(accepts(sample.control, context))
        }
    }

    func testOriginalStagingRecoveryContextRejectsSourceAndTargetGenerationDrift() async throws {
        let sample = try sample(), journal = try XCTUnwrap(sample.context.journal)
        var context = sample.context
        context.manifest = manifest(scope: context.scope, generation: UUID())
        XCTAssertFalse(accepts(sample.control, context))
        context = sample.context; context.manifest = nil
        XCTAssertFalse(accepts(sample.control, context))
        context = sample.context
        context.journal = AccountRecoveryJournalSnapshot(replacement: journal.replacement, mode: journal.mode,
            phase: journal.phase, deviceIdentityHash: journal.deviceIdentityHash, generationID: nil,
            checkpointDigest: journal.checkpointDigest, watermark: journal.watermark, baselineRunID: journal.baselineRunID)
        XCTAssertFalse(accepts(sample.control, context))
        context = sample.context; context.journal = copied(journal, target: UUID())
        XCTAssertFalse(accepts(sample.control, context)) // Typed target cannot differ from original bytes.
        let sameAsSource = copied(journal, target: try XCTUnwrap(sample.control.state.originalGeneration))
        let bytes = try raw(sameAsSource)
        sample.control.state.journalBytes = bytes
        context = sample.context; context.journal = sameAsSource; context.raw = bytes
        XCTAssertFalse(accepts(sample.control, context))
        sample.control.state.journalBytes = sample.context.raw
        sample.control.state.terminalGeneration = UUID()
        XCTAssertFalse(accepts(sample.control, sample.context))
    }

    func testOriginalStagingRecoveryContextRejectsForeignScopeAndAllStoreProvenanceDrift() async throws {
        let sample = try sample(), base = sample.context.scope
        for foreign in [scope(base, owner: UUID()), scope(base, account: "foreign-account"),
                        scope(base, shop: UUID()), scope(base, install: "foreign-install"),
                        scope(base, device: String(repeating: "f", count: 64))] {
            var context = sample.context; context.scope = foreign
            XCTAssertFalse(accepts(sample.control, context))
        }
        let binding = try XCTUnwrap(sample.context.binding)
        var context = sample.context
        context.binding = AccountBinding(accountHash: "foreign-account", storeIdentity: binding.storeIdentity)
        XCTAssertFalse(accepts(sample.control, context))
        context = sample.context; context.replacement = nil
        XCTAssertFalse(accepts(sample.control, context))
        context = sample.context; context.binding = nil
        XCTAssertFalse(accepts(sample.control, context))
        context = sample.context
        context.scope = Task126VerifiedOwnerStoreScope(ownerUserID: base.ownerUserID,
            accountHash: base.accountHash, shopID: base.shopID, storeIdentity: base.storeIdentity,
            deviceInstallID: base.deviceInstallID, deviceIdentityHash: base.deviceIdentityHash,
            pendingReplacement: nil, leaseGeneration: base.leaseGeneration)
        XCTAssertFalse(accepts(sample.control, context))
        for foreign in [scope(base, account: "foreign-account"), scope(base, shop: UUID()),
                        scope(base, device: String(repeating: "f", count: 64))] {
            context = sample.context
            context.manifest = manifest(scope: foreign, generation: try XCTUnwrap(sample.control.state.originalGeneration))
            XCTAssertFalse(accepts(sample.control, context))
        }
        let original = base.storeIdentity
        let variants = [
            store(original, raw: "foreign-store"), store(original, defaultID: "foreign-default"),
            store(original, local: "foreign-local"), store(original, schema: original.schemaVersion + 1),
            store(original, protocolVersion: original.syncProtocolVersion + 1),
            store(original, epoch: original.storeEpoch + 1)
        ]
        for identity in variants {
            let foreign = scope(base, store: identity)
            context = sample.context; context.scope = foreign
            XCTAssertFalse(accepts(sample.control, context))
            context = sample.context
            context.manifest = manifest(scope: foreign, generation: try XCTUnwrap(sample.control.state.originalGeneration))
            XCTAssertFalse(accepts(sample.control, context))
            context = sample.context
            context.binding = AccountBinding(accountHash: binding.accountHash, storeIdentity: identity, boundAt: binding.boundAt)
            XCTAssertFalse(accepts(sample.control, context))
            let replacement = try XCTUnwrap(sample.context.replacement)
            let changed = AccountBinding(accountHash: replacement.accountHash, storeIdentity: identity, boundAt: replacement.boundAt)
            context = sample.context; context.replacement = changed
            XCTAssertFalse(accepts(sample.control, context))
            context = sample.context
            context.journal = copied(try XCTUnwrap(context.journal), replacement: changed)
            XCTAssertFalse(accepts(sample.control, context))
        }
    }

    func testFailedPriceWitnessCaptureCannotAcquirePayloadIDOrResponse() async throws {
        let sample = try sample()
        var called = false
        sample.control.capturePrice = { _, _ in
            called = true
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        try sample.control.noteIngress("price")
        XCTAssertThrowsError(try sample.control.insertPrices([sample.payload], scope: sample.context.scope))
        XCTAssertTrue(called)
        XCTAssertEqual(sample.control.state.priceIngressCount, 1)
        XCTAssertNil(sample.control.state.savedPriceID)
        XCTAssertTrue(sample.control.state.pricePayloads.isEmpty)
        XCTAssertTrue(sample.control.state.prices.isEmpty)
        XCTAssertTrue(sample.control.state.events.isEmpty)
    }

    func testPriceWitnessRetainsExactTokenBodyAndPayloadJoin() async throws {
        let tokenSample = try sample()
        var token = try XCTUnwrap(JSONSerialization.jsonObject(
            with: JSONEncoder().encode(tokenSample.witness.originalToken)) as? [String: Any])
        token["idempotencyKey"] = tokenSample.witness.originalToken.idempotencyKey + "-changed"
        tokenSample.control.state.savedTokens[1] = try JSONDecoder().decode(LocalPendingChangeCASToken.self,
            from: JSONSerialization.data(withJSONObject: token))
        tokenSample.control.state.priceIngressCount = 1
        tokenSample.control.capturePrice = { _, _ in XCTFail("Invalid original token must reject before capture"); return tokenSample.witness }
        XCTAssertThrowsError(try tokenSample.control.insertPrices([tokenSample.payload], scope: tokenSample.context.scope))
        XCTAssertNil(tokenSample.control.state.savedPriceID)

        let payloadSample = try sample(), payload = payloadSample.payload
        let foreignPayload = SyncAutomaticProductPricePayload(id: payload.id, ownerUserID: payload.ownerUserID,
            shopID: payload.shopID, productID: payload.productID, type: payload.type, price: 38,
            effectiveAt: payload.effectiveAt, source: payload.source, note: payload.note, createdAt: payload.createdAt)
        try payloadSample.control.noteIngress("price")
        payloadSample.control.capturePrice = { _, _ in XCTFail("Foreign body must reject before capture"); return payloadSample.witness }
        XCTAssertThrowsError(try payloadSample.control.insertPrices([foreignPayload], scope: payloadSample.context.scope))
        XCTAssertNil(payloadSample.control.state.savedPriceID)

        let bodySample = try sample()
        let encoded = try JSONEncoder().encode(bodySample.witness)
        var body = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        body["localPriceBits"] = Double(38).bitPattern
        let changedWitness = try JSONDecoder().decode(Control.LocalPriceWitness.self,
            from: JSONSerialization.data(withJSONObject: body))
        bodySample.control.capturePrice = { _, _ in changedWitness }
        try bodySample.control.noteIngress("price")
        XCTAssertThrowsError(try bodySample.control.insertPrices([bodySample.payload], scope: bodySample.context.scope))
        XCTAssertNil(bodySample.control.state.savedPriceID)
        XCTAssertTrue(bodySample.control.state.prices.isEmpty)

        let linked = try sample()
        linked.control.state.savedPriceID = UUID()
        linked.control.state.priceIngressCount = 1
        linked.control.capturePrice = { _, _ in XCTFail("Prelinked state must reject before capture"); return linked.witness }
        XCTAssertThrowsError(try linked.control.insertPrices([linked.payload], scope: linked.context.scope))
        XCTAssertNotEqual(linked.control.state.savedPriceID, linked.payload.id)
        XCTAssertTrue(linked.control.state.prices.isEmpty)

        let exact = try sample(), exactContext = exact.context, exactWitness = exact.witness
        exact.control.capturePrice = { [weak control = exact.control] _, scope in
            XCTAssertTrue(self.accepts(try XCTUnwrap(control), exactContext))
            XCTAssertTrue(exactWitness.matchesScope(scope))
            return exactWitness
        }
        try exact.control.noteIngress("price")
        let rows = try exact.control.insertPrices([exact.payload], scope: exact.context.scope)
        XCTAssertEqual(rows.map(\.id), [exact.payload.id])
        XCTAssertEqual(exact.control.state.savedPriceID, exact.payload.id)
        XCTAssertTrue(try exact.control.observedPriceIsJoined())
        let response = try XCTUnwrap(rows.first)
        XCTAssertEqual(response.priceCanonical, exactWitness.amountCanonical)
        let checkpoint = try XCTUnwrap(exactContext.manifest).checkpoint
        let record = try ShopSyncRecoveryRowContract.price(response, checkpoint: checkpoint)
        XCTAssertEqual(record.orderingID, exact.payload.id.uuidString.lowercased())
        // Preserve the actual response fields; missing server metadata alone
        // must reproduce the strict recovery rejection seen in V23's record.
        let missingCanonical = RemoteInventoryProductPriceRow(id: response.id, ownerUserID: response.ownerUserID,
            shopID: response.shopID, productID: response.productID, type: response.type, price: response.price,
            priceCanonical: nil, effectiveAt: response.effectiveAt, source: response.source, note: response.note,
            createdAt: response.createdAt, updatedAt: response.updatedAt)
        XCTAssertThrowsError(try ShopSyncRecoveryRowContract.price(missingCanonical, checkpoint: checkpoint)) { error in
            XCTAssertEqual(error as? ShopSyncRecoveryContractError, .invalidPage(domain: .prices))
        }
        try exact.control.noteIngress("price")
        XCTAssertThrowsError(try exact.control.insertPrices([exact.payload], scope: exact.context.scope))
        XCTAssertEqual(exact.control.state.prices.count, 1)
        XCTAssertEqual(exact.control.state.savedPriceID, exact.payload.id)
    }

    func testT10EventPageUsesOnlyRecordedRowsWithoutMutatingControl() async throws {
        let sample = try sample(), checkpoint = tailCheckpoint(sample)
        sample.control.state.events = try tailEvents(sample)
        let before = try sample.control.bytes(), fileBefore = try Data(contentsOf: sample.control.url)
        let page = try JSONDecoder().decode(ShopSyncEventPageEnvelope.self,
            from: sample.control.eventPage(tailParameters(sample, checkpoint), checkpoint: checkpoint))
        XCTAssertEqual(page.schemaVersion, "shop-sync-event-page-v1")
        XCTAssertEqual(page.shopId, checkpoint.shopId)
        XCTAssertEqual(page.scope, checkpoint.scope)
        XCTAssertEqual(page.scopeEventMaxId, "43")
        XCTAssertEqual(page.asOfEventMaxId, "43")
        XCTAssertEqual(page.asOfDomainEventMaxIds, checkpoint.syncEvents.domainMaxIds)
        XCTAssertEqual(page.pageLimit, 150)
        XCTAssertEqual(page.rows.map(\.id), [42, 43])
        XCTAssertTrue(SyncEventEntityIDSet(json: page.rows[0].entityIDs).isCompleteCatalog(changedCount: page.rows[0].changedCount))
        XCTAssertTrue(SyncEventEntityIDSet(json: page.rows[1].entityIDs).isCompletePrices(changedCount: page.rows[1].changedCount))
        XCTAssertEqual(try encoded(page.rows), try encoded(sample.control.state.events))
        XCTAssertFalse(page.hasMore)
        XCTAssertNil(page.nextAfterId)
        XCTAssertEqual(try sample.control.bytes(), before)
        XCTAssertEqual(try Data(contentsOf: sample.control.url), fileBefore)
    }

    func testT10EventPageAsOf42DoesNotLeak43AndResumesFrom42() async throws {
        let sample = try sample(), checkpoint = tailCheckpoint(sample)
        sample.control.state.events = try tailEvents(sample)
        let before = try sample.control.bytes()
        let early = try JSONDecoder().decode(ShopSyncEventPageEnvelope.self,
            from: sample.control.eventPage(tailParameters(sample, checkpoint, through: "42"), checkpoint: checkpoint))
        XCTAssertEqual(early.rows.map(\.id), [42])
        XCTAssertEqual(early.scopeEventMaxId, "43")
        XCTAssertEqual(early.asOfEventMaxId, "42")
        XCTAssertEqual(early.asOfDomainEventMaxIds, .init(catalog: "42", prices: "42", history: "42"))
        XCTAssertFalse(early.hasMore)
        XCTAssertNil(early.nextAfterId)
        let later = try JSONDecoder().decode(ShopSyncEventPageEnvelope.self,
            from: sample.control.eventPage(tailParameters(sample, checkpoint, after: "42"), checkpoint: checkpoint))
        XCTAssertEqual(later.rows.map(\.id), [43])
        XCTAssertEqual(later.asOfEventMaxId, "43")
        XCTAssertFalse(later.hasMore)
        XCTAssertNil(later.nextAfterId)
        XCTAssertEqual(try sample.control.bytes(), before)
    }

    func testT10EventPageRejectsForeignFenceAndInvalidCursorOrLimit() async throws {
        let sample = try sample(), checkpoint = tailCheckpoint(sample)
        sample.control.state.events = try tailEvents(sample)
        let before = try sample.control.bytes(), fileBefore = try Data(contentsOf: sample.control.url)
        let requests: [ShopSyncEventPageParameters] = [
            tailParameters(sample, checkpoint, shop: UUID()),
            tailParameters(sample, checkpoint, device: "foreign-device"),
            tailParameters(sample, checkpoint, scopeKey: "foreign-scope"),
            tailParameters(sample, checkpoint, limit: 0),
            tailParameters(sample, checkpoint, limit: 149),
            tailParameters(sample, checkpoint, limit: 151),
            tailParameters(sample, checkpoint, after: ""),
            tailParameters(sample, checkpoint, after: "041"),
            tailParameters(sample, checkpoint, after: "-1"),
            tailParameters(sample, checkpoint, after: "9223372036854775808"),
            tailParameters(sample, checkpoint, after: "40"),
            tailParameters(sample, checkpoint, after: "44"),
            tailParameters(sample, checkpoint, after: "43", through: "42"),
            tailParameters(sample, checkpoint, through: "44"),
            tailParameters(sample, checkpoint, through: "40"),
            tailParameters(sample, checkpoint, through: "043")
        ]
        for request in requests {
            XCTAssertThrowsError(try sample.control.eventPage(request, checkpoint: checkpoint))
        }
        for foreign in [tailCheckpoint(sample, account: "foreign-account"),
                        tailCheckpoint(sample, device: "foreign-device-hash"),
                        tailCheckpoint(sample, domainMax: "42"), tailCheckpoint(sample, maxID: "44")] {
            XCTAssertThrowsError(try sample.control.eventPage(tailParameters(sample, foreign), checkpoint: foreign))
        }
        sample.control.state.savedLocalPriceWitness = nil
        XCTAssertThrowsError(try sample.control.eventPage(tailParameters(sample, checkpoint), checkpoint: checkpoint))
        sample.control.state.savedLocalPriceWitness = sample.witness
        XCTAssertEqual(try sample.control.bytes(), before)
        XCTAssertEqual(try Data(contentsOf: sample.control.url), fileBefore)
    }

    func testT10EventPageRejectsBrokenOrderAndDoesNotRepairEntityIDs() async throws {
        let sample = try sample(), checkpoint = tailCheckpoint(sample), events = try tailEvents(sample)
        for rows in [[events[1], events[0]], [events[1], events[1]], [events[0], events[1], events[1]]] {
            sample.control.state.events = rows
            let before = try sample.control.bytes()
            XCTAssertThrowsError(try sample.control.eventPage(tailParameters(sample, checkpoint), checkpoint: checkpoint))
            XCTAssertEqual(try sample.control.bytes(), before)
        }
        let payloads: [[String: [String]]] = [[:],
            ["product_ids": [sample.control.state.product.id.uuidString, sample.control.state.product.id.uuidString]],
            ["price_ids": [sample.payload.id.uuidString]]]
        for payload in payloads {
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded(events[0])) as? [String: Any])
            object["entity_ids"] = payload
            let malformed = try JSONDecoder().decode(RemoteSyncEventRow.self,
                from: JSONSerialization.data(withJSONObject: object))
            sample.control.state.events = [malformed, events[1]]
            let before = try sample.control.bytes()
            let page = try JSONDecoder().decode(ShopSyncEventPageEnvelope.self,
                from: sample.control.eventPage(tailParameters(sample, checkpoint), checkpoint: checkpoint))
            XCTAssertEqual(page.rows.count, 2)
            XCTAssertEqual(try encoded(page.rows), try encoded(sample.control.state.events))
            XCTAssertFalse(SyncEventEntityIDSet(json: page.rows[0].entityIDs)
                .isCompleteCatalog(changedCount: page.rows[0].changedCount))
            XCTAssertEqual(try sample.control.bytes(), before)
        }
    }

    // Unit event vectors model the recorded server rows; they grant no runtime ACK.
    private func tailEvents(_ sample: Sample) throws -> [RemoteSyncEventRow] {
        let owner = sample.context.scope.ownerUserID.uuidString, shop = sample.context.scope.shopID.uuidString
        let product = sample.control.state.product.id.uuidString
        let rows: [[String: Any]] = [
            ["id": "42", "owner_user_id": owner, "shop_id": shop, "domain": "catalog", "event_type": "catalog_changed",
             "source": "ios", "source_device_key": sample.context.scope.deviceIdentityHash,
             "client_event_key": ShopSyncRecoveryCanonical.sha256("unit-tail-42"),
             "changed_count": 1, "entity_ids": ["product_ids": [product]], "metadata": ["source": "ios"],
             "requires_full_recovery": false, "created_at": "2026-07-21T12:01:00Z"],
            ["id": "43", "owner_user_id": owner, "shop_id": shop, "domain": "prices", "event_type": "prices_changed",
             "source": "ios", "source_device_key": sample.context.scope.deviceIdentityHash,
             "client_event_key": ShopSyncRecoveryCanonical.sha256("unit-tail-43"),
             "changed_count": 1, "entity_ids": ["product_ids": [product], "price_ids": [sample.payload.id.uuidString]],
             "metadata": ["source": "ios", "price_count": 1, "product_count": 1] as [String: Any],
             "requires_full_recovery": false, "created_at": "2026-07-21T12:01:00Z"]
        ]
        return try JSONDecoder().decode([RemoteSyncEventRow].self, from: JSONSerialization.data(withJSONObject: rows))
    }
    private func tailCheckpoint(_ sample: Sample, account: String? = nil, device: String? = nil,
                                domainMax: String? = nil, maxID: String = "43") -> ShopSyncRecoveryCheckpoint {
        let scope = sample.context.scope, base = manifest(scope: scope, generation: UUID()).checkpoint
        let key = ShopSyncRecoveryCanonical.sha256(scope.shopID.uuidString.lowercased() + ":shop_scoped:-:" + scope.deviceIdentityHash)
        return ShopSyncRecoveryCheckpoint(schemaVersion: base.schemaVersion, shopId: scope.shopID,
            scope: .init(kind: "shop_scoped", key: key, legacyOwnerKey: nil,
                accountKey: account ?? scope.accountHash, deviceKey: device ?? scope.deviceIdentityHash),
            syncEvents: .init(maxId: maxID, verifiedBaselineId: "41", requiresFullRecovery: true,
                domainMaxIds: .init(catalog: domainMax ?? maxID, prices: domainMax ?? maxID, history: domainMax ?? maxID)),
            catalog: base.catalog, prices: base.prices, history: base.history, images: base.images,
            integrity: base.integrity, checkpointDigest: base.checkpointDigest)
    }
    private func tailParameters(_ sample: Sample, _ checkpoint: ShopSyncRecoveryCheckpoint,
                                after: String = "41", through: String = "43", shop: UUID? = nil,
                                device: String? = nil, scopeKey: String? = nil, limit: Int = 150) -> ShopSyncEventPageParameters {
        .init(shopID: shop ?? sample.context.scope.shopID, deviceIdentifier: device ?? sample.context.scope.deviceInstallID,
            afterID: after, limit: limit, expectedScopeKey: scopeKey ?? checkpoint.scope.key, expectedEventMaxID: through)
    }
    private func encoded<Value: Encodable>(_ value: Value) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private func accepts(_ control: Control, _ context: Context) -> Bool {
        control.matchesOriginalStagingRecoveryContext(scope: context.scope, activeManifest: context.manifest,
            binding: context.binding, pendingReplacement: context.replacement,
            pendingWipeCommitted: context.wipeCommitted, journal: context.journal, journalBytes: context.raw)
    }
    private func pending(kind: LocalPendingChangeEntityKind, key: String, fingerprint: String,
                         scope: Task126VerifiedOwnerStoreScope) -> LocalPendingChange {
        LocalPendingChange(ownerUserID: scope.ownerUserID, ownerHash: scope.accountHash,
            storeId: scope.storeIdentity.storeId, localStoreId: scope.storeIdentity.localStoreId,
            entityKind: kind, operation: .create, origin: kind == .productPrice ? .productPriceSave : .manualCatalogSave,
            logicalKey: key, intendedFingerprintHash: fingerprint)
    }
    private func sample() throws -> Sample {
        let owner = UUID(), shop = UUID(), source = UUID(), install = UUID().uuidString.lowercased()
        let account = AccountBindingStore.accountHash(for: owner)
        let identity = LocalStoreIdentity(rawValue: shop.uuidString.lowercased())
        let device = DeviceInstallIDStore.identityHash(for: install)
        let replacement = AccountBinding(accountHash: account, storeIdentity: identity,
            boundAt: Date(timeIntervalSince1970: 100))
        let scope = Task126VerifiedOwnerStoreScope(ownerUserID: owner, accountHash: account, shopID: shop,
            storeIdentity: identity, deviceInstallID: install, deviceIdentityHash: device,
            pendingReplacement: replacement, leaseGeneration: 7)
        let journal = AccountRecoveryJournalSnapshot(replacement: replacement, mode: .sameScopeRecovery,
            phase: .staging, deviceIdentityHash: device, generationID: UUID(), checkpointDigest: "saved-checkpoint",
            watermark: nil, baselineRunID: nil)
        let bytes = try raw(journal)
        let product = RemoteInventoryProductRow(id: UUID(), ownerUserID: owner, shopID: shop, barcode: "t10-unit",
            itemNumber: nil, productName: Control.savedName, secondProductName: nil, purchasePrice: 37,
            retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil,
            updatedAt: "2026-10-23T20:25:00.123456Z", deletedAt: nil)
        let priceChange = pending(kind: .productPrice, key: "price-logical-key", fingerprint: "original-body", scope: scope)
        let priceToken = LocalPendingChangeCASToken(priceChange)
        let when = Date(timeIntervalSince1970: 1_000)
        let canonicalWhen = ProductPriceEffectiveAtCanonicalizer.canonicalString(from: when)
        let witness = Control.LocalPriceWitness(ownerUserID: owner, shopID: shop, accountHash: account,
            storeRawValue: identity.rawValue, defaultStoreID: identity.defaultStoreId, localStoreID: identity.localStoreId,
            schemaVersion: identity.schemaVersion, syncProtocolVersion: identity.syncProtocolVersion,
            storeEpoch: identity.storeEpoch, deviceInstallID: install, deviceIdentityHash: device,
            productID: product.id, productBarcode: product.barcode, type: "PURCHASE", localPriceBits: Double(37).bitPattern,
            localEffectiveAt: when, localCreatedAt: when, price: 37, amountCanonical: "37",
            effectiveAt: canonicalWhen, source: nil, note: nil,
            createdAt: canonicalWhen, logicalKey: priceToken.logicalKey,
            intendedFingerprintHash: "original-body", originalToken: priceToken)
        var state = Control.State(schema: 2, runID: UUID(), product: product)
        state.originalGeneration = source; state.journalBytes = bytes; state.savedLocalPriceWitness = witness
        state.savedTokens = [LocalPendingChangeCASToken(pending(kind: .product, key: "product-key", fingerprint: "product-body", scope: scope)), priceToken]
        // A unit fixture file models the prior process; it grants no runtime authority.
        state.processIDs = [-1]
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("t10-control-unit-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("saved-recovery-v2.json")
        try JSONEncoder().encode(state).write(to: url)
        let control = try Control(url: url, runID: state.runID, initial: product, reopening: true)
        let context = Context(scope: scope, manifest: manifest(scope: scope, generation: source),
            binding: AccountBinding(accountHash: account, storeIdentity: identity), replacement: replacement,
            journal: journal, raw: bytes)
        let payload = SyncAutomaticProductPricePayload(id: UUID(), ownerUserID: owner, shopID: shop,
            productID: product.id, type: witness.type, price: witness.price, effectiveAt: witness.effectiveAt,
            source: witness.source, note: witness.note, createdAt: witness.createdAt)
        return Sample(control: control, context: context, payload: payload, witness: witness)
    }
    private func raw(_ journal: AccountRecoveryJournalSnapshot, wipeCommitted: Bool = false) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(RawJournal(replacement: journal.replacement, wipeCommitted: wipeCommitted,
            modeRaw: journal.mode.rawValue, phaseRaw: journal.phase.rawValue, deviceIdentityHash: journal.deviceIdentityHash,
            generationID: journal.generationID, checkpointDigest: journal.checkpointDigest,
            watermark: journal.watermark, baselineRunID: journal.baselineRunID))
    }
    private func copied(_ journal: AccountRecoveryJournalSnapshot, mode: AccountRecoveryJournalMode? = nil,
                        phase: AccountRecoveryJournalPhase? = nil, replacement: AccountBinding? = nil,
                        target: UUID? = nil, digest: String? = nil, watermark: Int64? = nil,
                        baseline: UUID? = nil, device: String? = nil) -> AccountRecoveryJournalSnapshot {
        AccountRecoveryJournalSnapshot(replacement: replacement ?? journal.replacement, mode: mode ?? journal.mode,
            phase: phase ?? journal.phase, deviceIdentityHash: device ?? journal.deviceIdentityHash,
            generationID: target ?? journal.generationID, checkpointDigest: digest ?? journal.checkpointDigest,
            watermark: watermark ?? journal.watermark, baselineRunID: baseline ?? journal.baselineRunID)
    }
    private func scope(_ old: Task126VerifiedOwnerStoreScope, owner: UUID? = nil, account: String? = nil,
                       shop: UUID? = nil, store: LocalStoreIdentity? = nil, install: String? = nil,
                       device: String? = nil) -> Task126VerifiedOwnerStoreScope {
        Task126VerifiedOwnerStoreScope(ownerUserID: owner ?? old.ownerUserID, accountHash: account ?? old.accountHash,
            shopID: shop ?? old.shopID, storeIdentity: store ?? old.storeIdentity, deviceInstallID: install ?? old.deviceInstallID,
            deviceIdentityHash: device ?? old.deviceIdentityHash, pendingReplacement: old.pendingReplacement,
            leaseGeneration: old.leaseGeneration)
    }
    private func store(_ old: LocalStoreIdentity, raw: String? = nil, defaultID: String? = nil, local: String? = nil,
                       schema: Int? = nil, protocolVersion: Int? = nil, epoch: Int? = nil) -> LocalStoreIdentity {
        LocalStoreIdentity(rawValue: raw ?? old.rawValue, defaultStoreId: defaultID ?? old.defaultStoreId,
            localStoreId: local ?? old.localStoreId, schemaVersion: schema ?? old.schemaVersion,
            syncProtocolVersion: protocolVersion ?? old.syncProtocolVersion, storeEpoch: epoch ?? old.storeEpoch)
    }
    private func manifest(scope: Task126VerifiedOwnerStoreScope, generation: UUID) -> SyncStoreGenerationManifest {
        let digest = ShopSyncRecoveryEntityDigest(activeCount: 0, tombstoneCount: 0,
            idSetDigest: String(repeating: "1", count: 64), versionDigest: String(repeating: "2", count: 64))
        let checkpoint = ShopSyncRecoveryCheckpoint(schemaVersion: "shop-sync-recovery-checkpoint-v1",
            shopId: scope.shopID, scope: .init(kind: "shop_scoped", key: "unit-scope", legacyOwnerKey: nil,
                accountKey: scope.accountHash, deviceKey: scope.deviceIdentityHash), syncEvents: .init(maxId: "0"),
            catalog: .init(suppliers: digest, categories: digest, products: digest, digest: "catalog"),
            prices: digest, history: digest, images: digest,
            integrity: .init(productCategoryViolationCount: 0, productSupplierViolationCount: 0,
                priceProductViolationCount: 0, primaryImageViolationCount: 0,
                historyIdViolationCount: 0, totalViolationCount: 0), checkpointDigest: "checkpoint")
        return SyncStoreGenerationManifest(generationID: generation, relativeStorePath: "unit-source.sqlite",
            accountHash: scope.accountHash, shopID: scope.shopID, storeIdentity: scope.storeIdentity,
            deviceIdentityHash: scope.deviceIdentityHash, recoveryMode: .sameScopeRecovery,
            checkpointBeforeDownload: checkpoint, checkpoint: checkpoint,
            localVerification: .init(suppliers: digest, categories: digest, products: digest, prices: digest,
                history: digest, images: digest, catalogDigest: "catalog", relationshipViolationCount: 0,
                pendingLocalCount: 0, outboxCount: 0), baselineRunID: UUID())
    }
}
#endif
