#if DEBUG
import Foundation
import SwiftData
import XCTest
@testable import iOSMerchandiseControl

/// Value/oracle tests only. Synthetic scope and the explicit validation closure
/// never establish ordinary auth, native TEST, render scanout or latency acceptance.
@MainActor
final class PilotB6TraceTests: XCTestCase {
    override func tearDown() { _ = PilotCommitTrace.b6ReceiptAndDisarm(); super.tearDown() }

    func testOffDoesNotAdmitCycleOrProduceReceipt() {
        _ = PilotCommitTrace.b6ReceiptAndDisarm()
        XCTAssertFalse(PilotCommitTrace.b6ObservationEnabled)
        XCTAssertNil(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "foregroundPoll"))
        XCTAssertNil(PilotCommitTrace.b6ReceiptAndDisarm())
    }
    func testIncompleteCategoryBindingsAndMissingVisibleDeltaCannotArm() {
        for category in ["delete", "price", "history"] {
            XCTAssertFalse(PilotCommitTrace.b6Arm(binding(category: category)))
        }
        XCTAssertFalse(PilotCommitTrace.b6Arm(binding(fields: [:])))
        XCTAssertFalse(PilotCommitTrace.b6Arm(binding(baseline: ["productName": "Expected"])))
    }
    func testOnlyOrdinaryPollOrRemoteEventAdmissionMatchesScope() throws {
        XCTAssertTrue(PilotCommitTrace.b6Arm(binding()))
        XCTAssertNil(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "rootForeground"))
        XCTAssertNil(PilotCommitTrace.b6ReceiverAdmission(scope: scope(owner: UUID()), source: "foregroundPoll"))
        XCTAssertNotNil(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "foregroundPoll"))
    }
    func testUnrelatedIDsDoNotQualifyOrInvalidateTarget() throws {
        XCTAssertTrue(PilotCommitTrace.b6Arm(binding()))
        let cycle = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "foregroundPoll"))
        XCTAssertNil(PilotCommitTrace.b6BeginApply(cycle: cycle, productIDs: [UUID()]))
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertNil(receipt.invalidReason)
        XCTAssertEqual(receipt.events.map(\.stage), ["receiver_ordinary_admission"])
    }
    func testCommitWithoutExactMappedTargetIsUnconfirmed() throws {
        let ticket = try armAndBegin()
        PilotCommitTrace.b6ApplyEnd(ticket, returned: true, ns: PilotCommitTrace.b6Now())
        XCTAssertNil(witness())
        XCTAssertEqual(PilotCommitTrace.b6ReceiptAndDisarm()?.invalidReason, "PEER_COMMIT_OR_TARGET_BODY_UNCONFIRMED")
    }
    func testWrongBodyAndUnchangedBodyCannotQualifyUpdate() throws {
        let ticket = try armAndBegin()
        let wrong = product(name: "Wrong")
        PilotCommitTrace.b6MappedProduct(ticket, beforeBody: "old", product: wrong, rawVersion: version)
        PilotCommitTrace.b6ApplyEnd(ticket, returned: true, ns: PilotCommitTrace.b6Now())
        XCTAssertNil(witness())
        _ = PilotCommitTrace.b6ReceiptAndDisarm()
        let second = try armAndBegin()
        let expected = product()
        PilotCommitTrace.b6MappedProduct(second, beforeBody: PilotCommitTrace.b6ProductBody(expected), product: expected, rawVersion: version)
        PilotCommitTrace.b6ApplyEnd(second, returned: true, ns: PilotCommitTrace.b6Now())
        XCTAssertNil(witness())
    }
    func testComposeBeforeCommitCanQualifyAtLaterDisplayWithoutRecompose() throws {
        let fields = ["productName": "Expected", "barcode": "B6-unit"]
        let ticket = try armAndBegin()
        XCTAssertNil(witness(fields: fields))
        PilotCommitTrace.b6MappedProduct(ticket, beforeBody: "old", product: product(), rawVersion: version)
        PilotCommitTrace.b6ApplyEnd(ticket, returned: true, ns: PilotCommitTrace.b6Now())
        let draw = try XCTUnwrap(witness(fields: fields))
        PilotCommitTrace.b6Rendered(draw, ns: PilotCommitTrace.b6Now())
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertNil(receipt.invalidReason)
        XCTAssertFalse(receipt.nativeAcceptance)
        XCTAssertEqual(receipt.events.last?.stage, "peer_expected_visible_projection")
        XCTAssertEqual(receipt.events.last?.applyID, ticket.id)
        XCTAssertEqual(receipt.events.last?.cycleID, ticket.cycleID)
    }
    func testNewTargetApplyAfterValidDrawPermanentlyInvalidatesOldQualification() throws {
        let ticket = try armAndBegin(); commit(ticket)
        let old = try XCTUnwrap(witness()); PilotCommitTrace.b6Rendered(old, ns: PilotCommitTrace.b6Now())
        let next = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "foregroundPoll"))
        XCTAssertNotNil(PilotCommitTrace.b6BeginApply(cycle: next, productIDs: [id]))
        XCTAssertNil(witness())
        PilotCommitTrace.b6Rendered(old, ns: PilotCommitTrace.b6Now())
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertEqual(receipt.invalidReason, "TARGET_CHANGED_AFTER_DRAW")
        XCTAssertEqual(receipt.events.filter { $0.stage == "peer_expected_visible_projection" }.count, 1, "Raw earlier draw remains preserved")
    }
    func testWrongVisibleFieldOrRouteCannotUseDurableBodyAlone() throws {
        let ticket = try armAndBegin(); commit(ticket)
        XCTAssertNil(witness(fields: ["productName": "Wrong"]))
        XCTAssertNil(PilotCommitTrace.b6RenderWitness(entityRemoteID: id, kind: "update", route: "history.sessions",
            visibleFields: ["productName": "Expected"], validateScope: { _ in }))
        XCTAssertNotNil(witness())
    }
    func testScopeRevokedAtDisplayRejectsWitness() throws {
        let ticket = try armAndBegin(); commit(ticket)
        XCTAssertNil(PilotCommitTrace.b6RenderWitness(entityRemoteID: id, kind: "update", route: "database.products",
            visibleFields: ["productName": "Expected"], validateScope: { _ in throw Task126OwnerStoreGateError.scopeChanged }))
    }
    func testThrownTransactionCannotPublishMappedBody() throws {
        let ticket = try armAndBegin()
        PilotCommitTrace.b6MappedProduct(ticket, beforeBody: "old", product: product(), rawVersion: version)
        PilotCommitTrace.b6ApplyEnd(ticket, returned: false, ns: PilotCommitTrace.b6Now())
        XCTAssertNil(witness())
        XCTAssertEqual(PilotCommitTrace.b6ReceiptAndDisarm()?.events.last?.stage, "peer_commit_uncertain")
    }
    func testBothDirectionsMatchAll66CanonicalScheduleSlots() throws {
        let schedules = [
            ("G01", "source", "delete price history create update delete price history create update delete price history create update delete price history create update delete price history create update delete price history create update delete price history"),
            ("G02", "peer", "price history create update delete price history create update delete price history create update delete price history create update delete price history create update delete price history create update delete price history create")
        ]
        for (group,role,raw) in schedules {
            let categories = raw.split(separator: " ").map(String.init)
            XCTAssertEqual(categories.count, 33)
            for (index,category) in categories.enumerated() {
                var fields = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(binding())) as? [String:Any])
                fields["sampleID"] = String(format: "T20-%@-%02d", group, index + 1)
                fields["role"] = role; fields["category"] = category
                let correct = try JSONDecoder().decode(PilotCommitTrace.B6Binding.self, from: JSONSerialization.data(withJSONObject: fields))
                XCTAssertTrue(PilotCommitTrace.b6ScheduleMatches(correct))
                fields["category"] = category == "update" ? "create" : "update"
                let wrong = try JSONDecoder().decode(PilotCommitTrace.B6Binding.self, from: JSONSerialization.data(withJSONObject: fields))
                XCTAssertFalse(PilotCommitTrace.b6ScheduleMatches(wrong))
            }
        }
    }
    func testCalibrationIsActualBoundedNativeClockRead() throws {
        XCTAssertTrue(PilotCommitTrace.b6Arm(binding()))
        let begin = PilotCommitTrace.b6Now(), nonce = UUID().uuidString
        let reply = try XCTUnwrap(PilotCommitTrace.b6Calibration(nonce: nonce))
        let end = PilotCommitTrace.b6Now()
        XCTAssertEqual(reply.nonce, nonce)
        XCTAssertTrue((begin...end).contains(reply.nativeNS))
        XCTAssertTrue(reply.clockID.hasPrefix("ios-uptime-"))
        XCTAssertEqual(reply.participantPID, ProcessInfo.processInfo.processIdentifier)
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertEqual(reply.clockID, receipt.clockID)
        XCTAssertEqual(reply.participantPID, receipt.processID)
        XCTAssertEqual(reply.bootHash, PilotCommitTrace.b6Hash(receipt.bootID))
    }
    func testConsumedOperationCannotArmAgain() {
        let value = binding()
        XCTAssertTrue(PilotCommitTrace.b6Arm(value)); _ = PilotCommitTrace.b6ReceiptAndDisarm()
        XCTAssertFalse(PilotCommitTrace.b6Arm(value))
    }
    func testCreateRequiresAbsentPriorRowAndExactNewBody() throws {
        XCTAssertTrue(PilotCommitTrace.b6Arm(binding(category: "create")))
        let cycle = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "foregroundPoll"))
        let ticket = try XCTUnwrap(PilotCommitTrace.b6BeginApply(cycle: cycle, productIDs: [id]))
        PilotCommitTrace.b6MappedProduct(ticket, beforeBody: nil, product: product(), rawVersion: version)
        PilotCommitTrace.b6ApplyEnd(ticket, returned: true, ns: PilotCommitTrace.b6Now())
        XCTAssertNotNil(PilotCommitTrace.b6RenderWitness(entityRemoteID: id, kind: "create", route: "database.products",
            visibleFields: ["productName": "Expected"], validateScope: { _ in }))
    }

    func testPriceDynamicIdentityRequiresPinnedRequestedFieldsAndParentBody() throws {
        let parent = product(); parent.retailPrice = 12.25
        let date = try XCTUnwrap(SupabaseRemoteDateParser.parse(version))
        let priceID = UUID()
        let point = ProductPrice(remoteID: priceID, type: .retail, price: 12.25,
            effectiveAt: date, source: "EDIT_PRODUCT", createdAt: date, product: parent)
        let b = priceBinding(point, parent: parent)
        XCTAssertTrue(PilotCommitTrace.b6Arm(b))
        let cycle = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "foregroundPoll"))
        let row = RemoteInventoryProductPriceRow(id: priceID, ownerUserID: owner, shopID: shop, productID: id,
            type: "RETAIL", price: 12.25, effectiveAt: version, source: "EDIT_PRODUCT", note: nil,
            createdAt: version, updatedAt: version)
        let ticket = try XCTUnwrap(PilotCommitTrace.b6BeginApply(cycle: cycle, productIDs: [id],
            priceIDs: [priceID], prices: [row]))
        PilotCommitTrace.B6Context.$apply.withValue(ticket) {
            PilotCommitTrace.b6MappedPrice(point, beforeBody: nil, rawVersion: version)
        }
        PilotCommitTrace.b6ApplyEnd(ticket, returned: true, ns: PilotCommitTrace.b6Now())
        let draw = try XCTUnwrap(PilotCommitTrace.b6RenderWitness(entityRemoteID: priceID, kind: "price", route: b.route,
            visibleFields: ["amount": "12.25"], validateScope: { _ in }))
        PilotCommitTrace.b6Rendered(draw, ns: PilotCommitTrace.b6Now())
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertEqual(receipt.resolvedEntityRemoteID, priceID)
        XCTAssertNil(receipt.invalidReason)
        XCTAssertEqual(receipt.events.first(where: { $0.stage == "peer_commit_return" })?.bodyHash,
            PilotCommitTrace.b6PriceBody(point), "Full observed body includes actual generated timestamps")
        XCTAssertEqual(receipt.binding.expectedLocalBodyHash, PilotCommitTrace.b6PriceRequestedBody(point),
            "Manifest separately pins all requested semantic fields before Save")
    }
    func testPriceWrongParentStateCannotQualifyEvenWhenPriceRowMatches() throws {
        let parent = product(); parent.retailPrice = 12.25
        let date = try XCTUnwrap(SupabaseRemoteDateParser.parse(version)), priceID = UUID()
        let point = ProductPrice(remoteID: priceID, type: .retail, price: 12.25,
            effectiveAt: date, source: "EDIT_PRODUCT", createdAt: date, product: parent)
        XCTAssertTrue(PilotCommitTrace.b6Arm(priceBinding(point, parent: parent)))
        let cycle = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "foregroundPoll"))
        let row = RemoteInventoryProductPriceRow(id: priceID, ownerUserID: owner, shopID: shop, productID: id,
            type: "RETAIL", price: 12.25, effectiveAt: version, source: "EDIT_PRODUCT", note: nil,
            createdAt: version, updatedAt: version)
        let ticket = try XCTUnwrap(PilotCommitTrace.b6BeginApply(cycle: cycle, productIDs: [id], priceIDs: [priceID], prices: [row]))
        parent.retailPrice = 11.0
        PilotCommitTrace.B6Context.$apply.withValue(ticket) { PilotCommitTrace.b6MappedPrice(point, beforeBody: nil, rawVersion: version) }
        PilotCommitTrace.b6ApplyEnd(ticket, returned: true, ns: PilotCommitTrace.b6Now())
        XCTAssertEqual(PilotCommitTrace.b6ReceiptAndDisarm()?.invalidReason, "PEER_COMMIT_OR_TARGET_BODY_UNCONFIRMED")
    }
    func testDynamicCreateResolvesOnlyExactUniqueManifestBarcode() throws {
        let stamp = String(repeating: "a", count: 64)
        let b = PilotCommitTrace.B6Binding(operationID: UUID().uuidString, sampleID: "T20-G02-08", role: "peer", category: "create",
            scopeHash: PilotCommitTrace.b6ScopeHash(scope()), manifestHash: stamp, authPreflightHash: stamp,
            twoCASReceiptHash: stamp, artifactHash: stamp, entityRemoteID: nil,
            expectedLocalBodyHash: PilotCommitTrace.b6ProductBody(product()), expectedVisibleFields: ["productName": "Expected"],
            baselineVisibleFields: [:], route: "database.products", expectedBarcode: "B6-unit")
        XCTAssertTrue(PilotCommitTrace.b6Arm(b))
        let cycle = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "foregroundPoll"))
        let row = RemoteInventoryProductRow(id: id, ownerUserID: owner, shopID: shop, barcode: "B6-unit", itemNumber: nil, productName: "Expected", secondProductName: nil,
            purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil, updatedAt: version, deletedAt: nil)
        let ticket = try XCTUnwrap(PilotCommitTrace.b6BeginApply(cycle: cycle, productIDs: [id], catalogProducts: [row]))
        PilotCommitTrace.b6MappedProduct(ticket, beforeBody: nil, product: product(), rawVersion: version)
        PilotCommitTrace.b6ApplyEnd(ticket, returned: true, ns: PilotCommitTrace.b6Now())
        XCTAssertEqual(PilotCommitTrace.b6ReceiptAndDisarm()?.resolvedEntityRemoteID, id)
    }
    private func priceBinding(_ price: ProductPrice, parent: Product) -> PilotCommitTrace.B6Binding {
        let stamp = String(repeating: "a", count: 64)
        return .init(operationID: UUID().uuidString, sampleID: "T20-G02-06", role: "peer", category: "price",
            scopeHash: PilotCommitTrace.b6ScopeHash(scope()), manifestHash: stamp, authPreflightHash: stamp,
            twoCASReceiptHash: stamp, artifactHash: stamp, entityRemoteID: nil,
            expectedLocalBodyHash: PilotCommitTrace.b6PriceRequestedBody(price)!, expectedVisibleFields: ["amount": "12.25"],
            baselineVisibleFields: [:], route: "database.product-prices.\(id.uuidString.lowercased()).retail",
            parentRemoteID: id, expectedParentBodyHash: PilotCommitTrace.b6ProductBody(parent), bodySemantics: "price_requested_fields_v1")
    }

    func testActualLocalMutationFenceCanCallArmedSourceHookWithoutReacquiringLease() async throws {
        let suite = "B6-fence-unit-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let selected = SelectedShop(shopID: shop, code: "UNIT", name: "Unit", role: "owner", status: "active", selectable: true, canWrite: true)
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let store = SelectedShopStore(defaults: defaults); store.noteActiveAccount(accountHash)
        XCTAssertTrue(store.save(selected, accountHash: accountHash))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(accountHash: accountHash, storeIdentity: selected.localStoreIdentity))
        _ = try DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID()
        let captured = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let schema = Schema([Product.self, Supplier.self, ProductCategory.self, ProductPrice.self, LocalPendingChange.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let stamp = String(repeating: "a", count: 64)
        let b = PilotCommitTrace.B6Binding(operationID: UUID().uuidString, sampleID: "T20-G01-05", role: "source", category: "update",
            scopeHash: PilotCommitTrace.b6ScopeHash(captured), manifestHash: stamp, authPreflightHash: stamp,
            twoCASReceiptHash: stamp, artifactHash: stamp, entityRemoteID: id,
            expectedLocalBodyHash: PilotCommitTrace.b6ProductBody(product()), expectedVisibleFields: ["productName": "Expected"],
            baselineVisibleFields: ["productName": "Before"], route: "database.products")
        XCTAssertTrue(PilotCommitTrace.b6Arm(b))
        PilotCommitTrace.b6SourceMutationBegin(categories: ["update"])
        let finished = expectation(description: "actual nonrecursive fence returns")
        let result = PilotB6FenceResult(), productID = id, account = owner
        let box = PilotB6TestDefaults(value: defaults)
        Task.detached {
            defer { finished.fulfill() }
            do {
                try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container,
                    ownerUserID: account, defaults: box.value) { context in
                    let product = Product(barcode: "B6-unit", remoteID: productID, productName: "Expected")
                    context.insert(product)
                    let intent = LocalPendingChange(ownerUserID: account, ownerHash: captured.accountHash,
                        storeId: captured.storeIdentity.storeId, localStoreId: captured.storeIdentity.localStoreId,
                        syncProtocolVersion: captured.storeIdentity.syncProtocolVersion,
                        schemaVersion: captured.storeIdentity.schemaVersion, storeEpoch: captured.storeIdentity.storeEpoch,
                        entityKind: .product, operation: .update, origin: .manualCatalogSave,
                        logicalKey: LocalPendingChangeLogicalKey.remoteEntity(kind: .product, remoteID: productID),
                        changedFields: ["productName"], intendedFingerprintHash: LocalPendingChangeLogicalKey.productFingerprintHash(product),
                        entityRemoteID: productID)
                    context.insert(intent)
                    let ticket = PilotCommitTrace.b6LocalBegin(product: product,
                        intents: [LocalPendingChangeCASToken(intent)], scope: captured)
                    guard ticket != nil else { throw Task126OwnerStoreGateError.scopeChanged }
                    try context.save()
                    PilotCommitTrace.b6LocalEnd(ticket, returned: true, ns: PilotCommitTrace.b6Now())
                }
                result.value = PilotCommitTrace.b6ReceiptAndDisarm()
            } catch { result.failure = true }
        }
        await fulfillment(of: [finished], timeout: 5)
        XCTAssertFalse(result.failure)
        let receipt = try XCTUnwrap(result.value)
        XCTAssertNil(receipt.invalidReason)
        XCTAssertEqual(receipt.events.map(\.stage), ["source_local_mutation_begin", "local_commit_call_begin", "local_commit_return"])
        XCTAssertNotNil(receipt.events.dropFirst().first?.tokenHash)
        XCTAssertEqual(receipt.events.first?.applyID, receipt.events.dropFirst().first?.applyID)
    }

    func testDeleteRequiresPreviouslyLiveExactBodyAndExpectedAbsence() throws {
        let p = product(), baseline = PilotCommitTrace.b6ProductBody(product())
        let b = deleteBinding(baseline: baseline)
        XCTAssertTrue(PilotCommitTrace.b6Arm(b))
        let cycle = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "foregroundPoll"))
        let apply = try XCTUnwrap(PilotCommitTrace.b6BeginApply(cycle: cycle, productIDs: [id]))
        p.remoteDeletedAt = SupabaseRemoteDateParser.parse(version)
        let row = RemoteInventoryProductRow(id: id, ownerUserID: owner, shopID: shop, barcode: p.barcode,
            itemNumber: nil, productName: p.productName, secondProductName: nil, purchasePrice: nil, retailPrice: nil,
            supplierID: nil, categoryID: nil, stockQuantity: nil, updatedAt: version, deletedAt: version)
        PilotCommitTrace.b6MappedDeletion(apply, beforeBody: baseline, beforeWasLive: true, product: p, row: row)
        PilotCommitTrace.b6ApplyEnd(apply, returned: true, ns: PilotCommitTrace.b6Now())
        XCTAssertNil(PilotCommitTrace.b6DeletionCandidate(query: "B6-wrong"))
        XCTAssertEqual(PilotCommitTrace.b6DeletionCandidate(query: "B6-unit")?.entityRemoteID, id)
        let witness = try XCTUnwrap(PilotCommitTrace.b6RenderWitness(entityRemoteID: id, kind: "delete", route: b.route,
            visibleFields: ["barcodeQuery": "B6-unit", "resultCount": "0", "emptyMessage": "Empty"], validateScope: { _ in }))
        PilotCommitTrace.b6Rendered(witness, ns: PilotCommitTrace.b6Now())
        XCTAssertTrue(try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm()).observationComplete)
    }
    func testAlreadyTombstonedOrWrongBaselineCannotQualifyFreshDeletion() throws {
        for wasLive in [false, true] {
            let p = product(), baseline = PilotCommitTrace.b6ProductBody(product())
            XCTAssertTrue(PilotCommitTrace.b6Arm(deleteBinding(baseline: baseline)))
            let cycle = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "foregroundPoll"))
            let apply = try XCTUnwrap(PilotCommitTrace.b6BeginApply(cycle: cycle, productIDs: [id]))
            p.remoteDeletedAt = SupabaseRemoteDateParser.parse(version)
            let row = RemoteInventoryProductRow(id: id, ownerUserID: owner, shopID: shop, barcode: p.barcode,
                itemNumber: nil, productName: p.productName, secondProductName: nil, purchasePrice: nil, retailPrice: nil,
                supplierID: nil, categoryID: nil, stockQuantity: nil, updatedAt: version, deletedAt: version)
            PilotCommitTrace.b6MappedDeletion(apply, beforeBody: wasLive ? "wrong" : baseline, beforeWasLive: wasLive, product: p, row: row)
            PilotCommitTrace.b6ApplyEnd(apply, returned: true, ns: PilotCommitTrace.b6Now())
            XCTAssertNil(PilotCommitTrace.b6DeletionCandidate(query: "B6-unit"))
            XCTAssertFalse(try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm()).observationComplete)
        }
    }
    func testHistoryExactChangedFullPayloadQualifiesSummaryProjection() throws {
        let entry = HistoryEntry(id: "unit", timestamp: Date(timeIntervalSince1970: 1_787_000_000), data: [["barcode"], ["B6-unit"]],
            editable: [[""], [""]], complete: [false, true], remoteID: id)
        entry.title = "Expected"
        let body = try XCTUnwrap(PilotCommitTrace.b6HistoryBody(entry)), b = historyBinding(body: body)
        XCTAssertTrue(PilotCommitTrace.b6Arm(b))
        let cycle = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "foregroundPoll"))
        let apply = try XCTUnwrap(PilotCommitTrace.b6BeginApply(cycle: cycle, productIDs: [], historyIDs: [id]))
        PilotCommitTrace.B6Context.$apply.withValue(apply) { PilotCommitTrace.b6MappedHistory(entry: entry, beforeBody: "previous", rawVersion: version) }
        PilotCommitTrace.b6ApplyEnd(apply, returned: true, ns: PilotCommitTrace.b6Now())
        XCTAssertNotNil(PilotCommitTrace.b6RenderWitness(entityRemoteID: id, kind: "history", route: b.route,
            visibleFields: ["title": "Expected"], validateScope: { _ in }))
    }
    func testUnchangedHistoryOrTombstoneCannotQualifyNewHistorySummary() throws {
        for tombstone in [false, true] {
            let entry = HistoryEntry(id: "unit", remoteID: id); entry.title = "Expected"
            let body = try XCTUnwrap(PilotCommitTrace.b6HistoryBody(entry))
            XCTAssertTrue(PilotCommitTrace.b6Arm(historyBinding(body: body)))
            let cycle = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "foregroundPoll"))
            let apply = try XCTUnwrap(PilotCommitTrace.b6BeginApply(cycle: cycle, productIDs: [], historyIDs: [id]))
            if tombstone { entry.remoteDeletedAt = SupabaseRemoteDateParser.parse(version) }
            PilotCommitTrace.B6Context.$apply.withValue(apply) { PilotCommitTrace.b6MappedHistory(entry: entry, beforeBody: body, rawVersion: version) }
            PilotCommitTrace.b6ApplyEnd(apply, returned: true, ns: PilotCommitTrace.b6Now())
            XCTAssertFalse(try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm()).observationComplete)
        }
    }
    private func deleteBinding(baseline: String) -> PilotCommitTrace.B6Binding {
        let stamp = String(repeating: "a", count: 64)
        return .init(operationID: UUID().uuidString, sampleID: "T20-G02-05", role: "peer", category: "delete",
            scopeHash: PilotCommitTrace.b6ScopeHash(scope()), manifestHash: stamp, authPreflightHash: stamp,
            twoCASReceiptHash: stamp, artifactHash: stamp, entityRemoteID: id,
            expectedLocalBodyHash: PilotCommitTrace.b6DeletedProductBody(id),
            expectedVisibleFields: ["barcodeQuery": "B6-unit", "resultCount": "0"], baselineVisibleFields: [:],
            route: "database.products.exact-query", expectedBarcode: "B6-unit", bodySemantics: "product_absence_v1", baselineLocalBodyHash: baseline)
    }
    private func historyBinding(body: String) -> PilotCommitTrace.B6Binding {
        let stamp = String(repeating: "a", count: 64)
        return .init(operationID: UUID().uuidString, sampleID: "T20-G02-07", role: "peer", category: "history",
            scopeHash: PilotCommitTrace.b6ScopeHash(scope()), manifestHash: stamp, authPreflightHash: stamp,
            twoCASReceiptHash: stamp, artifactHash: stamp, entityRemoteID: id, expectedLocalBodyHash: body,
            expectedVisibleFields: ["title": "Expected"], baselineVisibleFields: ["title": "Before"], route: "history.sessions", bodySemantics: "history_payload_v1")
    }

    func testDuplicateSourceHandlerEntryCannotMoveTheAdmissionBoundary() throws {
        let stamp = String(repeating: "a", count: 64)
        let value = PilotCommitTrace.B6Binding(operationID: UUID().uuidString, sampleID: "T20-G01-05", role: "source", category: "update",
            scopeHash: PilotCommitTrace.b6ScopeHash(scope()), manifestHash: stamp, authPreflightHash: stamp,
            twoCASReceiptHash: stamp, artifactHash: stamp, entityRemoteID: id,
            expectedLocalBodyHash: PilotCommitTrace.b6ProductBody(product()), expectedVisibleFields: ["productName": "Expected"],
            baselineVisibleFields: ["productName": "Before"], route: "database.products")
        XCTAssertTrue(PilotCommitTrace.b6Arm(value))
        PilotCommitTrace.b6SourceMutationBegin(categories: ["update"])
        PilotCommitTrace.b6SourceMutationBegin(categories: ["update"])
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertEqual(receipt.events.map(\.stage), ["source_local_mutation_begin"])
        XCTAssertEqual(receipt.invalidReason, "MULTIPLE_OR_LATE_SOURCE_ACTIONS")
        XCTAssertFalse(receipt.observationComplete)
    }

    func testCausalSourceIdleWitnessUsesActualCountersAndImmutablePrefixWithoutDisarming() throws {
        let binding = causalBinding()
        XCTAssertTrue(PilotCommitTrace.b6Arm(binding))
        let witness = try XCTUnwrap(PilotCommitTrace.b6CausalSourceIdleWitness(nonce: try XCTUnwrap(binding.sourceAdmissionNonce)))
        XCTAssertEqual(witness.sourceIdleState, ["trigger_count": 0, "mutation_ticket_count": 0,
            "transaction_count": 0, "seal_count": 0, "source_result_count": 0])
        XCTAssertEqual(witness.traceEventCount, 1)
        XCTAssertEqual(witness.tracePrefixSHA256, PilotCommitTrace.b6Hash(witness.tracePrefixRaw))
        let values = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(witness.tracePrefixRaw.utf8)) as? [[String: Any]])
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values.first?["stage"] as? String, "causal_source_idle_witness")
        XCTAssertEqual(values.first?["causalSequence"] as? Int, 0)
        XCTAssertTrue(PilotCommitTrace.b6ObservationEnabled)
        XCTAssertNil(PilotCommitTrace.b6CausalTracePreview(), "An idle witness is not a business result or own ACK")
    }

    func testCausalRealUIEntryBeforeWitnessPermanentlyRejectsTheSample() throws {
        let binding = causalBinding()
        XCTAssertTrue(PilotCommitTrace.b6Arm(binding))
        PilotCommitTrace.b6SourceMutationBegin(categories: ["update"])
        XCTAssertNil(PilotCommitTrace.b6CausalSourceIdleWitness(nonce: try XCTUnwrap(binding.sourceAdmissionNonce)))
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertEqual(receipt.invalidReason, "SOURCE_HOOK_BEFORE_CAUSAL_WITNESS")
        XCTAssertFalse(receipt.observationComplete)
        XCTAssertEqual(receipt.events.filter { $0.stage == "causal_source_hook_rejected" }.count, 1)
        XCTAssertFalse(receipt.events.contains { $0.stage == "causal_source_idle_witness" })
    }

    func testCausalRealUIEntryAfterWitnessIsRecordedOnceAndDuplicateFailsClosed() throws {
        let binding = causalBinding()
        XCTAssertTrue(PilotCommitTrace.b6Arm(binding))
        let witness = try XCTUnwrap(PilotCommitTrace.b6CausalSourceIdleWitness(nonce: try XCTUnwrap(binding.sourceAdmissionNonce)))
        PilotCommitTrace.b6SourceMutationBegin(categories: ["update"])
        PilotCommitTrace.b6SourceMutationBegin(categories: ["update"])
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        let entries = receipt.events.filter { $0.stage == "source_ui_action_begin" }
        XCTAssertEqual(entries.count, 1)
        let entry = try XCTUnwrap(entries.first)
        XCTAssertEqual(entry.causalSequence, 1)
        XCTAssertEqual(entry.causalEarliestHookNS, entry.ns)
        XCTAssertGreaterThan(entry.ns, witness.nativeNS)
        XCTAssertEqual(receipt.invalidReason, "DUPLICATE_CAUSAL_SOURCE_HOOK")
        XCTAssertFalse(receipt.observationComplete)
        XCTAssertEqual(try causalRawEvents(Array(receipt.events.prefix(1))), witness.tracePrefixRaw)
    }

    func testCausalWrongNonceCannotBeRetriedAndConsumedNonceCannotArmAnotherOperation() throws {
        let nonce = UUID().uuidString
        let binding = causalBinding(nonce: nonce)
        XCTAssertTrue(PilotCommitTrace.b6Arm(binding))
        XCTAssertNil(PilotCommitTrace.b6CausalSourceIdleWitness(nonce: UUID().uuidString))
        XCTAssertNil(PilotCommitTrace.b6CausalSourceIdleWitness(nonce: nonce), "An invalid challenge cannot later become a witness")
        XCTAssertEqual(PilotCommitTrace.b6ReceiptAndDisarm()?.invalidReason, "CAUSAL_SOURCE_NONCE_MISMATCH")
        XCTAssertFalse(PilotCommitTrace.b6Arm(binding), "The operation remains consumed")
        XCTAssertFalse(PilotCommitTrace.b6Arm(causalBinding(nonce: nonce)), "A new operation cannot reuse its source challenge")
    }

    func testCausalDuplicateWitnessKeepsItsFirstPrefixAndRejectsTheRun() throws {
        let binding = causalBinding()
        XCTAssertTrue(PilotCommitTrace.b6Arm(binding))
        let nonce = try XCTUnwrap(binding.sourceAdmissionNonce)
        let first = try XCTUnwrap(PilotCommitTrace.b6CausalSourceIdleWitness(nonce: nonce))
        XCTAssertNil(PilotCommitTrace.b6CausalSourceIdleWitness(nonce: nonce))
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertEqual(receipt.invalidReason, "SOURCE_NOT_IDLE_AT_CAUSAL_WITNESS")
        XCTAssertEqual(try causalRawEvents(receipt.events), first.tracePrefixRaw)
        XCTAssertFalse(receipt.observationComplete)
    }

    func testCausalLiveValidatorRejectsHookCapturedBeforeWitnessEvenWhenAppendedAfterIt() throws {
        let (witness, events) = try actualCausalUIWitnessAndEntry()
        XCTAssertTrue(PilotCommitTrace.b6CausalSourceEventsFollowWitness(events,
            witnessNS: witness.nativeNS, witnessPrefixRaw: witness.tracePrefixRaw))
        for staleNS in [witness.nativeNS - 1, witness.nativeNS] {
            var changed = events
            changed[1].causalEarliestHookNS = staleNS
            XCTAssertFalse(PilotCommitTrace.b6CausalSourceEventsFollowWitness(changed,
                witnessNS: witness.nativeNS, witnessPrefixRaw: witness.tracePrefixRaw),
                "Appending after the witness cannot launder an earlier hook entry timestamp")
        }
        var impossible = events
        impossible[1].causalEarliestHookNS = events[1].ns + 1
        XCTAssertFalse(PilotCommitTrace.b6CausalSourceEventsFollowWitness(impossible,
            witnessNS: witness.nativeNS, witnessPrefixRaw: witness.tracePrefixRaw))
    }

    func testCausalLiveValidatorRejectsChangedPrefixOrSequenceAndDoesNotSupplyHostEndpoints() throws {
        let (witness, events) = try actualCausalUIWitnessAndEntry()
        XCTAssertFalse(PilotCommitTrace.b6CausalSourceEventsFollowWitness(events,
            witnessNS: witness.nativeNS, witnessPrefixRaw: witness.tracePrefixRaw + " "))
        var changed = events
        changed[1].causalSequence = 0
        XCTAssertFalse(PilotCommitTrace.b6CausalSourceEventsFollowWitness(changed,
            witnessNS: witness.nativeNS, witnessPrefixRaw: witness.tracePrefixRaw))
        XCTAssertFalse(PilotCommitTrace.b6CausalSourceEventsFollowWitness(Array(events.reversed()),
            witnessNS: witness.nativeNS, witnessPrefixRaw: witness.tracePrefixRaw))
    }

    func testCausalPeerPreviewRequiresActualMappedCommitAndQualifiedDisplayAndKeepsFinalPrefix() throws {
        XCTAssertTrue(PilotCommitTrace.b6Arm(causalBinding(role: "peer")))
        XCTAssertNil(PilotCommitTrace.b6CausalTracePreview())
        let cycle = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "foregroundPoll"))
        let ticket = try XCTUnwrap(PilotCommitTrace.b6BeginApply(cycle: cycle, productIDs: [id]))
        XCTAssertNil(PilotCommitTrace.b6CausalTracePreview(), "A generic admission or begun transaction is not a peer commit")
        commit(ticket)
        XCTAssertNil(PilotCommitTrace.b6CausalTracePreview(), "Commit alone cannot supply the separately qualified display")
        let draw = try XCTUnwrap(witness())
        PilotCommitTrace.b6Rendered(draw, ns: PilotCommitTrace.b6Now())
        let preview = try XCTUnwrap(PilotCommitTrace.b6CausalTracePreview())
        XCTAssertTrue(preview.receipt.observationComplete)
        XCTAssertTrue(PilotCommitTrace.b6ObservationEnabled, "Exporting a preview cannot disarm the final observer")
        XCTAssertEqual(preview.receipt.events.compactMap(\.causalSequence), Array(preview.receipt.events.indices))
        let final = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertEqual(try causalRawEvents(Array(final.events.prefix(preview.receipt.events.count))), preview.traceRaw)
    }

    func testCausalUnknownMethodAndMissingSourceNonceDoNotArmDefaultObservation() {
        var missing = causalBinding()
        missing.sourceAdmissionNonce = nil
        XCTAssertFalse(PilotCommitTrace.b6Arm(missing))
        var unknown = causalBinding()
        unknown.timingMethod = "UNKNOWN_CAUSAL_METHOD"
        XCTAssertFalse(PilotCommitTrace.b6Arm(unknown))
        XCTAssertFalse(PilotCommitTrace.b6ObservationEnabled)
    }

    private func causalBinding(role: String = "source", nonce: String = UUID().uuidString) -> PilotCommitTrace.B6Binding {
        .init(operationID: UUID().uuidString, sampleID: role == "source" ? "T20-G01-05" : "T20-G02-04",
            role: role, category: "update", scopeHash: PilotCommitTrace.b6ScopeHash(scope()),
            manifestHash: String(repeating: "c", count: 64), authPreflightHash: String(repeating: "d", count: 64),
            twoCASReceiptHash: String(repeating: "e", count: 64), artifactHash: String(repeating: "f", count: 64),
            entityRemoteID: id, expectedLocalBodyHash: PilotCommitTrace.b6ProductBody(product()),
            expectedVisibleFields: ["productName": "Expected"], baselineVisibleFields: ["productName": "Before"],
            route: "database.products", timingMethod: PilotCommitTrace.b6CausalTimingMethod,
            sourceAdmissionNonce: role == "source" ? nonce : nil)
    }
    private func actualCausalUIWitnessAndEntry() throws -> (PilotCommitTrace.B6CausalSourceWitness, [PilotCommitTrace.B6Event]) {
        let binding = causalBinding()
        XCTAssertTrue(PilotCommitTrace.b6Arm(binding))
        let witness = try XCTUnwrap(PilotCommitTrace.b6CausalSourceIdleWitness(nonce: try XCTUnwrap(binding.sourceAdmissionNonce)))
        PilotCommitTrace.b6SourceMutationBegin(categories: ["update"])
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        return (witness, receipt.events)
    }
    private func causalRawEvents(_ events: [PilotCommitTrace.B6Event]) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try XCTUnwrap(String(data: encoder.encode(events), encoding: .utf8))
    }

    private let id = UUID(uuidString: "10000000-0000-4000-8000-000000000010")!
    private let owner = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
    private let shop = UUID(uuidString: "10000000-0000-4000-8000-000000000002")!
    private let version = "2026-10-23T12:34:56.123456Z"
    private func scope(owner alternate: UUID? = nil) -> Task126VerifiedOwnerStoreScope {
        .init(ownerUserID: alternate ?? owner, accountHash: String(repeating: "a", count: 64), shopID: shop,
            storeIdentity: .init(rawValue: "shop-unit"), deviceInstallID: "unit-device",
            deviceIdentityHash: String(repeating: "b", count: 64), pendingReplacement: nil, leaseGeneration: 1)
    }
    private func product(name: String = "Expected") -> Product { Product(barcode: "B6-unit", remoteID: id, productName: name) }
    private func binding(category: String = "update", fields: [String:String] = ["productName": "Expected"],
        baseline: [String:String] = ["productName": "Before"]) -> PilotCommitTrace.B6Binding {
        let slot = ["create":"08", "update":"04", "delete":"05", "price":"06", "history":"07"][category]!
        return .init(operationID: UUID().uuidString, sampleID: "T20-G02-\(slot)", role: "peer", category: category,
            scopeHash: PilotCommitTrace.b6ScopeHash(scope()), manifestHash: String(repeating: "c", count: 64),
            authPreflightHash: String(repeating: "d", count: 64), twoCASReceiptHash: String(repeating: "e", count: 64),
            artifactHash: String(repeating: "f", count: 64), entityRemoteID: id,
            expectedLocalBodyHash: PilotCommitTrace.b6ProductBody(product()), expectedVisibleFields: fields,
            baselineVisibleFields: baseline, route: "database.products")
    }
    private func armAndBegin() throws -> PilotCommitTrace.B6Apply {
        XCTAssertTrue(PilotCommitTrace.b6Arm(binding()))
        let cycle = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "foregroundPoll"))
        return try XCTUnwrap(PilotCommitTrace.b6BeginApply(cycle: cycle, productIDs: [id]))
    }
    private func commit(_ ticket: PilotCommitTrace.B6Apply) {
        PilotCommitTrace.b6MappedProduct(ticket, beforeBody: "old", product: product(), rawVersion: version)
        PilotCommitTrace.b6ApplyEnd(ticket, returned: true, ns: PilotCommitTrace.b6Now())
    }
    private func witness(fields: [String:String] = ["productName": "Expected"]) -> PilotB6RenderWitness? {
        PilotCommitTrace.b6RenderWitness(entityRemoteID: id, kind: "update", route: "database.products",
            visibleFields: fields, validateScope: { _ in })
    }
}
/// Proposal02 contract tests exercise the real value/observer APIs with typed
/// unit scopes. They do not establish ordinary auth, a process restart or native acceptance.
extension PilotB6TraceTests {
    func testPersistentIdentityIsCanonicalAndPinsEveryDurableComponent() throws {
        let frozen = scopeV1(), identity = try XCTUnwrap(PilotCommitTrace.b6PersistentScopeIdentity(frozen))
        let fields = try scopeV1JSON(identity.raw)
        XCTAssertEqual(identity.sha256, PilotCommitTrace.b6Hash(identity.raw))
        XCTAssertEqual(Set(fields.keys), Set(["kind", "schema_version", "owner_sha256", "account_hash",
            "shop_sha256", "device_install_sha256", "device_identity_sha256", "store"]))
        XCTAssertEqual(fields["kind"] as? String, "IOS_PERSISTENT_SCOPE_IDENTITY")
        XCTAssertEqual(fields["schema_version"] as? Int, 1)
        XCTAssertEqual(fields["owner_sha256"] as? String, PilotCommitTrace.b6Hash(owner.uuidString.lowercased()))
        XCTAssertEqual(fields["account_hash"] as? String, frozen.accountHash)
        XCTAssertEqual(fields["shop_sha256"] as? String, PilotCommitTrace.b6Hash(shop.uuidString.lowercased()))
        XCTAssertEqual(fields["device_install_sha256"] as? String, PilotCommitTrace.b6Hash(frozen.deviceInstallID))
        XCTAssertEqual(fields["device_identity_sha256"] as? String, frozen.deviceIdentityHash)
        let store = try XCTUnwrap(fields["store"] as? [String: Any])
        XCTAssertEqual(Set(store.keys), Set(["raw_store_sha256", "default_store_sha256", "local_store_sha256",
            "store_epoch", "schema_version", "sync_protocol_version"]))
        XCTAssertEqual(store["raw_store_sha256"] as? String, PilotCommitTrace.b6Hash(frozen.storeIdentity.rawValue))
        XCTAssertEqual(store["default_store_sha256"] as? String, PilotCommitTrace.b6Hash(frozen.storeIdentity.defaultStoreId))
        XCTAssertEqual(store["local_store_sha256"] as? String, PilotCommitTrace.b6Hash(frozen.storeIdentity.localStoreId))
        XCTAssertEqual(store["store_epoch"] as? Int, frozen.storeIdentity.storeEpoch)
        XCTAssertEqual(store["schema_version"] as? Int, frozen.storeIdentity.schemaVersion)
        XCTAssertEqual(store["sync_protocol_version"] as? Int, frozen.storeIdentity.syncProtocolVersion)
        XCTAssertEqual(Data(identity.raw.utf8), try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]))
        XCTAssertFalse(identity.raw.contains("\n"))
        XCTAssertTrue(identity.raw.unicodeScalars.allSatisfy { $0.value < 128 })
        XCTAssertFalse(identity.raw.contains(frozen.deviceInstallID))
        XCTAssertFalse(identity.raw.contains(owner.uuidString.lowercased()))
        for (component, changed) in scopeV1IdentityChanges() {
            let other = try XCTUnwrap(PilotCommitTrace.b6PersistentScopeIdentity(changed), component)
            XCTAssertNotEqual(other.raw, identity.raw, component)
            XCTAssertNotEqual(other.sha256, identity.sha256, component)
        }
    }

    func testPersistentIdentityIgnoresLeaseWhileRuntimeComparisonKeepsItFrozen() throws {
        let before = scopeV1(lease: 0), current = scopeV1(lease: 27)
        let a = try XCTUnwrap(PilotCommitTrace.b6PersistentScopeIdentity(before))
        let b = try XCTUnwrap(PilotCommitTrace.b6PersistentScopeIdentity(current))
        XCTAssertEqual(a.raw, b.raw)
        XCTAssertEqual(a.sha256, b.sha256)
        XCTAssertNotEqual(PilotCommitTrace.b6ScopeHash(before), PilotCommitTrace.b6ScopeHash(current))
        XCTAssertFalse(PilotCommitTrace.b6RuntimeScopeMatches(current: current, frozen: before))
        XCTAssertTrue(PilotCommitTrace.b6RuntimeScopeMatches(current: current, frozen: current))
    }

    func testPersistentIdentityRejectsInvalidDigestsAndNegativeStoreVersions() {
        for invalid in ["", "not-a-digest", String(repeating: "A", count: 64), String(repeating: "a", count: 63)] {
            XCTAssertNil(PilotCommitTrace.b6PersistentScopeIdentity(scopeV1(account: invalid)))
            XCTAssertNil(PilotCommitTrace.b6PersistentScopeIdentity(scopeV1(deviceHash: invalid)))
        }
        for identity in [scopeV1Store(epoch: -1), scopeV1Store(schema: -1), scopeV1Store(protocolVersion: -1)] {
            XCTAssertNil(PilotCommitTrace.b6PersistentScopeIdentity(scopeV1(store: identity)))
        }
    }

    func testRuntimeComparisonRejectsEachStoreProvenanceFieldAndPendingReplacement() {
        let frozen = scopeV1()
        for (component, changed) in scopeV1IdentityChanges() {
            XCTAssertFalse(PilotCommitTrace.b6RuntimeScopeMatches(current: changed, frozen: frozen), component)
            XCTAssertFalse(PilotCommitTrace.b6RuntimeScopeMatches(current: frozen, frozen: changed), component)
        }
        let pending = AccountBinding(accountHash: frozen.accountHash, storeIdentity: frozen.storeIdentity,
            boundAt: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertFalse(PilotCommitTrace.b6RuntimeScopeMatches(current: scopeV1(pending: pending), frozen: frozen))
    }

    func testNewScopeMethodRequiresRuntimeOverloadAndRejectsMixedOrMalformedBindings() throws {
        let frozen = scopeV1(), correct = try scopeV1Binding(frozen)
        XCTAssertFalse(PilotCommitTrace.b6Arm(correct), "The old overload cannot infer a runtime scope")
        var mixed = correct; mixed.scopeHash = PilotCommitTrace.b6ScopeHash(frozen)
        var noMethod = correct; noMethod.scopeBindingMethod = nil
        var noPersistent = correct; noPersistent.persistentScopeHash = nil
        var unknown = correct; unknown.scopeBindingMethod = "UNKNOWN_SCOPE_BINDING_METHOD"
        var malformed = correct; malformed.persistentScopeHash = String(repeating: "A", count: 64)
        var noTiming = correct; noTiming.timingMethod = nil
        for value in [mixed, noMethod, noPersistent, unknown, malformed, noTiming] {
            XCTAssertFalse(PilotCommitTrace.b6Arm(value))
            XCTAssertFalse(scopeV1Arm(value, frozen: frozen))
            XCTAssertNil(PilotCommitTrace.b6RuntimeScopeProof())
        }
        XCTAssertFalse(PilotCommitTrace.b6Arm(correct, runtimeScope: frozen,
            harnessAuthGeneration: UUID(), predeclaredBindingSHA256: "invalid"))
        let encoded = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(correct)) as? [String: Any])
        XCTAssertNil(encoded["scopeHash"])
        XCTAssertEqual(encoded["scopeBindingMethod"] as? String, PilotCommitTrace.b6ScopeBindingMethod)
        XCTAssertEqual(encoded["persistentScopeHash"] as? String, correct.persistentScopeHash)
        XCTAssertFalse(PilotCommitTrace.b6ObservationEnabled)
    }

    func testLegacyNilMethodEncodingAndLeaseDependentScopeMeaningRemainUnchanged() throws {
        var legacy = causalBinding(role: "peer")
        let fields = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        XCTAssertNil(fields["scopeBindingMethod"])
        XCTAssertNil(fields["persistentScopeHash"])
        XCTAssertEqual(fields["scopeHash"] as? String, PilotCommitTrace.b6ScopeHash(scope()))
        legacy.scopeHash = try XCTUnwrap(PilotCommitTrace.b6PersistentScopeIdentity(scope())).sha256
        XCTAssertTrue(PilotCommitTrace.b6Arm(legacy), "Legacy shape remains accepted without reinterpreting its digest")
        XCTAssertNil(PilotCommitTrace.b6RuntimeScopeProof())
        XCTAssertNil(PilotCommitTrace.b6ReceiverAdmission(scope: scope(), source: "foregroundPoll"),
            "A persistent digest placed in legacy scopeHash cannot admit a different legacy hash")
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertNil(receipt.runtime_scope_proof_sha256)
        XCTAssertFalse(receipt.observationComplete)
    }

    func testNewScopeMethodRejectsEachPersistentMismatchAndPendingReplacementBeforeArm() throws {
        let frozen = scopeV1(), value = try scopeV1Binding(frozen)
        for (component, changed) in scopeV1IdentityChanges() {
            XCTAssertFalse(scopeV1Arm(value, frozen: changed), component)
            XCTAssertNil(PilotCommitTrace.b6RuntimeScopeProof(), component)
        }
        let pending = AccountBinding(accountHash: frozen.accountHash, storeIdentity: frozen.storeIdentity)
        XCTAssertFalse(scopeV1Arm(value, frozen: scopeV1(pending: pending)))
        XCTAssertFalse(PilotCommitTrace.b6ObservationEnabled)
    }

    func testNewScopeMethodCanBindCurrentLeaseWithoutGuessingPreflightCounter() throws {
        let preflight = scopeV1(lease: 0), current = scopeV1(lease: 27)
        let value = try scopeV1Binding(preflight)
        XCTAssertTrue(scopeV1Arm(value, frozen: current))
        let proof = try XCTUnwrap(PilotCommitTrace.b6RuntimeScopeProof())
        let fields = try scopeV1JSON(proof.raw)
        XCTAssertEqual(fields["persistent_scope_sha256"] as? String, value.persistentScopeHash)
        XCTAssertEqual((fields["lease_generation"] as? NSNumber)?.uint64Value, current.leaseGeneration)
        XCTAssertEqual(fields["legacy_scope_sha256"] as? String, PilotCommitTrace.b6ScopeHash(current))
        XCTAssertNotEqual(fields["legacy_scope_sha256"] as? String, PilotCommitTrace.b6ScopeHash(preflight))
        XCTAssertEqual(PilotCommitTrace.b6ReceiverAdmission(scope: current, source: "foregroundPoll")?.scope, current)
        XCTAssertFalse(try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm()).nativeAcceptance)
    }

    func testRuntimeProofUsesExactUnsignedLeaseCanonicalAuthUUIDAndCalibrationIdentity() throws {
        let frozen = scopeV1(lease: UInt64.max - 11), value = try scopeV1Binding(frozen)
        let auth = UUID(uuidString: "ABCDEF01-2345-4678-9ABC-DEF012345678")!
        XCTAssertTrue(scopeV1Arm(value, frozen: frozen, auth: auth))
        let proof = try XCTUnwrap(PilotCommitTrace.b6RuntimeScopeProof()), fields = try scopeV1JSON(proof.raw)
        let calibration = try XCTUnwrap(PilotCommitTrace.b6Calibration(nonce: UUID().uuidString))
        let nativeIdentity = try XCTUnwrap(fields["identity"] as? [String: Any])
        XCTAssertEqual(Set(fields.keys), Set(["kind", "schema_version", "scope_binding_method", "operation_id",
            "manifest_sha256", "predeclared_binding_sha256", "role", "identity", "persistent_scope_identity_raw",
            "persistent_scope_sha256", "legacy_scope_sha256", "lease_generation", "harness_auth_generation",
            "pending_replacement_present", "pending_replacement_sha256"]))
        XCTAssertEqual(fields["kind"] as? String, "B6_IOS_RUNTIME_SCOPE_PROOF")
        XCTAssertEqual(fields["schema_version"] as? Int, 1)
        XCTAssertEqual(fields["scope_binding_method"] as? String, PilotCommitTrace.b6ScopeBindingMethod)
        XCTAssertEqual(fields["operation_id"] as? String, value.operationID)
        XCTAssertEqual(fields["manifest_sha256"] as? String, value.manifestHash)
        XCTAssertEqual(fields["predeclared_binding_sha256"] as? String, scopeV1BindingHash)
        XCTAssertEqual(fields["role"] as? String, value.role)
        XCTAssertEqual(fields["persistent_scope_identity_raw"] as? String,
            try XCTUnwrap(PilotCommitTrace.b6PersistentScopeIdentity(frozen)).raw)
        XCTAssertEqual(fields["persistent_scope_sha256"] as? String, value.persistentScopeHash)
        XCTAssertEqual((fields["lease_generation"] as? NSNumber)?.uint64Value, frozen.leaseGeneration)
        XCTAssertTrue(proof.raw.contains("\"lease_generation\":\(frozen.leaseGeneration)"))
        XCTAssertEqual(fields["harness_auth_generation"] as? String, auth.uuidString.lowercased())
        XCTAssertEqual(fields["pending_replacement_present"] as? Bool, false)
        XCTAssertTrue(fields["pending_replacement_sha256"] is NSNull)
        XCTAssertEqual(Set(nativeIdentity.keys), Set(["clock_id", "participant_pid", "participant_boot_sha256",
            "artifact_sha256", "device_sha256", "ordinary_preflight_sha256"]))
        XCTAssertEqual(nativeIdentity["clock_id"] as? String, calibration.clockID)
        XCTAssertEqual((nativeIdentity["participant_pid"] as? NSNumber)?.int32Value, calibration.participantPID)
        XCTAssertEqual(nativeIdentity["participant_boot_sha256"] as? String, calibration.bootHash)
        XCTAssertEqual(nativeIdentity["artifact_sha256"] as? String, value.artifactHash)
        XCTAssertEqual(nativeIdentity["device_sha256"] as? String, PilotCommitTrace.b6Hash(frozen.deviceInstallID))
        XCTAssertEqual(nativeIdentity["ordinary_preflight_sha256"] as? String, value.authPreflightHash)
        XCTAssertEqual(proof.sha256, PilotCommitTrace.b6Hash(proof.raw))
        XCTAssertEqual(Data(proof.raw.utf8), try JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys]))
        XCTAssertNil(fields["runtime_scope_proof_sha256"], "A proof cannot include its own digest")
        XCTAssertEqual(PilotCommitTrace.b6ReceiptAndDisarm()?.runtime_scope_proof_sha256, proof.sha256)
    }

    func testRuntimeProofStaysFrozenAcrossSourceWitnessCalibrationAndAttemptedRearm() throws {
        let frozen = scopeV1(), value = try scopeV1Binding(frozen, role: "source"), auth = UUID()
        XCTAssertTrue(scopeV1Arm(value, frozen: frozen, auth: auth))
        let before = try XCTUnwrap(PilotCommitTrace.b6RuntimeScopeProof())
        let witness = try XCTUnwrap(PilotCommitTrace.b6CausalSourceIdleWitness(nonce: try XCTUnwrap(value.sourceAdmissionNonce)))
        XCTAssertEqual(witness.sourceIdleState["trigger_count"], 0)
        XCTAssertNotNil(PilotCommitTrace.b6Calibration(nonce: UUID().uuidString))
        XCTAssertFalse(scopeV1Arm(value, frozen: scopeV1(lease: 2), auth: UUID()), "No rebase or new auth UUID can replace an armed operation")
        let after = try XCTUnwrap(PilotCommitTrace.b6RuntimeScopeProof())
        XCTAssertEqual(after.raw, before.raw)
        XCTAssertEqual(after.sha256, before.sha256)
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertEqual(receipt.runtime_scope_proof_sha256, before.sha256)
        XCTAssertFalse(receipt.observationComplete, "Scope proof plus idle witness is not a business ACK")
        XCTAssertNil(PilotCommitTrace.b6RuntimeScopeProof())
        XCTAssertFalse(scopeV1Arm(value, frozen: frozen, auth: auth), "Consumed operations cannot be replayed")
    }

    func testChangedAuthUUIDChangesProofEvenWithIdenticalNativeProcessIdentityAndLease() throws {
        let frozen = scopeV1(), firstBinding = try scopeV1Binding(frozen)
        let firstAuth = UUID(uuidString: "20000000-0000-4000-8000-000000000001")!
        let secondAuth = UUID(uuidString: "20000000-0000-4000-8000-000000000002")!
        XCTAssertTrue(scopeV1Arm(firstBinding, frozen: frozen, auth: firstAuth))
        let first = try XCTUnwrap(PilotCommitTrace.b6RuntimeScopeProof())
        _ = PilotCommitTrace.b6ReceiptAndDisarm()
        let secondBinding = try scopeV1Binding(frozen)
        XCTAssertTrue(scopeV1Arm(secondBinding, frozen: frozen, auth: secondAuth))
        let second = try XCTUnwrap(PilotCommitTrace.b6RuntimeScopeProof())
        var a = try scopeV1JSON(first.raw), b = try scopeV1JSON(second.raw)
        XCTAssertEqual(a["identity"] as? NSDictionary, b["identity"] as? NSDictionary,
            "Both real proof exports use this same process PID, boot and clock label")
        XCTAssertEqual((a["lease_generation"] as? NSNumber)?.uint64Value,
            (b["lease_generation"] as? NSNumber)?.uint64Value)
        XCTAssertEqual(a["harness_auth_generation"] as? String, firstAuth.uuidString.lowercased())
        XCTAssertEqual(b["harness_auth_generation"] as? String, secondAuth.uuidString.lowercased())
        XCTAssertNotEqual(first.sha256, second.sha256)
        a.removeValue(forKey: "operation_id"); b.removeValue(forKey: "operation_id")
        XCTAssertNotEqual(try JSONSerialization.data(withJSONObject: a, options: [.sortedKeys]),
            try JSONSerialization.data(withJSONObject: b, options: [.sortedKeys]), "The auth UUID independently distinguishes coincident process labels")
        a.removeValue(forKey: "harness_auth_generation"); b.removeValue(forKey: "harness_auth_generation")
        XCTAssertEqual(try JSONSerialization.data(withJSONObject: a, options: [.sortedKeys]),
            try JSONSerialization.data(withJSONObject: b, options: [.sortedKeys]))
    }

    func testChangedRuntimeLeaseRejectsAdmissionAndPreservesOriginalProofDigest() throws {
        let frozen = scopeV1(), value = try scopeV1Binding(frozen)
        XCTAssertTrue(scopeV1Arm(value, frozen: frozen))
        let proof = try XCTUnwrap(PilotCommitTrace.b6RuntimeScopeProof())
        XCTAssertNil(PilotCommitTrace.b6ReceiverAdmission(scope: scopeV1(lease: 2), source: "foregroundPoll"))
        XCTAssertNil(PilotCommitTrace.b6ReceiverAdmission(scope: frozen, source: "foregroundPoll"), "No retry can restore an invalid sample")
        XCTAssertNil(PilotCommitTrace.b6RuntimeScopeProof())
        XCTAssertNil(PilotCommitTrace.b6CausalTracePreview())
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertEqual(receipt.invalidReason, "RUNTIME_SCOPE_CHANGED")
        XCTAssertEqual(receipt.runtime_scope_proof_sha256, proof.sha256)
        XCTAssertFalse(receipt.observationComplete)
        XCTAssertTrue(receipt.events.isEmpty)
    }

    func testChangedDefaultStoreProvenanceRejectsPassedPeerCycleDespiteSameLegacyHash() throws {
        let frozen = scopeV1(), changed = scopeV1(store: scopeV1Store(defaultID: "changed-default"))
        XCTAssertEqual(PilotCommitTrace.b6ScopeHash(frozen), PilotCommitTrace.b6ScopeHash(changed))
        XCTAssertTrue(scopeV1Arm(try scopeV1Binding(frozen), frozen: frozen))
        let cycle = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: frozen, source: "foregroundPoll"))
        let stale = PilotCommitTrace.B6Cycle(operationID: cycle.operationID, id: cycle.id, scope: changed)
        XCTAssertNil(PilotCommitTrace.b6BeginApply(cycle: stale, productIDs: [id]))
        XCTAssertNil(PilotCommitTrace.b6BeginApply(cycle: cycle, productIDs: [id]))
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertEqual(receipt.invalidReason, "RUNTIME_SCOPE_CHANGED")
        XCTAssertFalse(receipt.observationComplete)
        XCTAssertEqual(receipt.events.map(\.stage), ["receiver_ordinary_admission"])
    }

    func testRuntimeProofRemainsIdenticalThroughActualPeerHooksPreviewAndFinal() throws {
        let frozen = scopeV1()
        XCTAssertTrue(scopeV1Arm(try scopeV1Binding(frozen), frozen: frozen))
        let proof = try XCTUnwrap(PilotCommitTrace.b6RuntimeScopeProof())
        let cycle = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: frozen, source: "foregroundPoll"))
        let apply = try XCTUnwrap(PilotCommitTrace.b6BeginApply(cycle: cycle, productIDs: [id]))
        commit(apply)
        let draw = try XCTUnwrap(witness())
        PilotCommitTrace.b6Rendered(draw, ns: PilotCommitTrace.b6Now())
        let preview = try XCTUnwrap(PilotCommitTrace.b6CausalTracePreview())
        XCTAssertEqual(preview.receipt.runtime_scope_proof_sha256, proof.sha256)
        XCTAssertTrue(preview.receipt.observationComplete)
        XCTAssertFalse(preview.receipt.nativeAcceptance)
        XCTAssertNotNil(PilotCommitTrace.b6Calibration(nonce: UUID().uuidString))
        XCTAssertEqual(PilotCommitTrace.b6RuntimeScopeProof()?.raw, proof.raw)
        let final = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertEqual(final.runtime_scope_proof_sha256, proof.sha256)
        XCTAssertEqual(try causalRawEvents(Array(final.events.prefix(preview.receipt.events.count))), preview.traceRaw)
    }

    func testLateObservedScopeMismatchRejectsPreviouslyQualifiedPreviewWithoutErasingDraw() throws {
        let frozen = scopeV1()
        XCTAssertTrue(scopeV1Arm(try scopeV1Binding(frozen), frozen: frozen))
        let proof = try XCTUnwrap(PilotCommitTrace.b6RuntimeScopeProof())
        let cycle = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: frozen, source: "foregroundPoll"))
        let apply = try XCTUnwrap(PilotCommitTrace.b6BeginApply(cycle: cycle, productIDs: [id]))
        commit(apply)
        let draw = try XCTUnwrap(witness())
        PilotCommitTrace.b6Rendered(draw, ns: PilotCommitTrace.b6Now())
        XCTAssertNotNil(PilotCommitTrace.b6CausalTracePreview())
        XCTAssertNil(PilotCommitTrace.b6ReceiverAdmission(scope: scopeV1(lease: 2), source: "remoteSyncEvent"))
        XCTAssertNil(PilotCommitTrace.b6CausalTracePreview())
        XCTAssertNil(witness())
        let final = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertEqual(final.invalidReason, "RUNTIME_SCOPE_CHANGED")
        XCTAssertFalse(final.observationComplete)
        XCTAssertEqual(final.runtime_scope_proof_sha256, proof.sha256)
        XCTAssertEqual(final.events.filter { $0.stage == "peer_expected_visible_projection" }.count, 1)
    }

    func testMatchingRuntimeProofCannotMaskWrongPeerBody() throws {
        let frozen = scopeV1()
        XCTAssertTrue(scopeV1Arm(try scopeV1Binding(frozen), frozen: frozen))
        let proof = try XCTUnwrap(PilotCommitTrace.b6RuntimeScopeProof())
        let cycle = try XCTUnwrap(PilotCommitTrace.b6ReceiverAdmission(scope: frozen, source: "foregroundPoll"))
        let apply = try XCTUnwrap(PilotCommitTrace.b6BeginApply(cycle: cycle, productIDs: [id]))
        PilotCommitTrace.b6MappedProduct(apply, beforeBody: "old", product: product(name: "Wrong"), rawVersion: version)
        PilotCommitTrace.b6ApplyEnd(apply, returned: true, ns: PilotCommitTrace.b6Now())
        XCTAssertNil(witness())
        XCTAssertNil(PilotCommitTrace.b6CausalTracePreview())
        let final = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertEqual(final.invalidReason, "PEER_COMMIT_OR_TARGET_BODY_UNCONFIRMED")
        XCTAssertEqual(final.runtime_scope_proof_sha256, proof.sha256)
        XCTAssertFalse(final.observationComplete)
    }

    private var scopeV1BindingHash: String { String(repeating: "7", count: 64) }
    private func scopeV1JSON(_ raw: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any])
    }
    private func scopeV1Store(raw: String = "scope-v1-store", defaultID: String = "scope-v1-default",
        localID: String = "scope-v1-local", schema: Int = 3, protocolVersion: Int = 4, epoch: Int = 5) -> LocalStoreIdentity {
        .init(rawValue: raw, defaultStoreId: defaultID, localStoreId: localID,
            schemaVersion: schema, syncProtocolVersion: protocolVersion, storeEpoch: epoch)
    }
    private func scopeV1(lease: UInt64 = 1, owner alternate: UUID? = nil, account: String? = nil,
        shop alternateShop: UUID? = nil, store: LocalStoreIdentity? = nil, install: String = "scope-v1-install",
        deviceHash: String? = nil, pending: AccountBinding? = nil) -> Task126VerifiedOwnerStoreScope {
        .init(ownerUserID: alternate ?? owner, accountHash: account ?? String(repeating: "a", count: 64),
            shopID: alternateShop ?? shop, storeIdentity: store ?? scopeV1Store(), deviceInstallID: install,
            deviceIdentityHash: deviceHash ?? String(repeating: "b", count: 64),
            pendingReplacement: pending, leaseGeneration: lease)
    }
    private func scopeV1IdentityChanges() -> [(String, Task126VerifiedOwnerStoreScope)] {
        [("owner", scopeV1(owner: UUID(uuidString: "10000000-0000-4000-8000-000000000099")!)),
         ("account", scopeV1(account: String(repeating: "c", count: 64))),
         ("shop", scopeV1(shop: UUID(uuidString: "10000000-0000-4000-8000-000000000098")!)),
         ("device-install", scopeV1(install: "changed-install")),
         ("device-identity", scopeV1(deviceHash: String(repeating: "d", count: 64))),
         ("raw-store", scopeV1(store: scopeV1Store(raw: "changed-store"))),
         ("default-store", scopeV1(store: scopeV1Store(defaultID: "changed-default"))),
         ("local-store", scopeV1(store: scopeV1Store(localID: "changed-local"))),
         ("schema-version", scopeV1(store: scopeV1Store(schema: 9))),
         ("sync-protocol-version", scopeV1(store: scopeV1Store(protocolVersion: 9))),
         ("store-epoch", scopeV1(store: scopeV1Store(epoch: 9)))]
    }
    private func scopeV1Binding(_ frozen: Task126VerifiedOwnerStoreScope, role: String = "peer") throws -> PilotCommitTrace.B6Binding {
        var value = causalBinding(role: role)
        value.scopeHash = nil
        value.scopeBindingMethod = PilotCommitTrace.b6ScopeBindingMethod
        value.persistentScopeHash = try XCTUnwrap(PilotCommitTrace.b6PersistentScopeIdentity(frozen)).sha256
        return value
    }
    private func scopeV1Arm(_ value: PilotCommitTrace.B6Binding, frozen: Task126VerifiedOwnerStoreScope,
        auth: UUID = UUID()) -> Bool {
        PilotCommitTrace.b6Arm(value, runtimeScope: frozen, harnessAuthGeneration: auth,
            predeclaredBindingSHA256: scopeV1BindingHash)
    }
}

nonisolated private struct PilotB6TestDefaults: @unchecked Sendable { let value: UserDefaults }
nonisolated private final class PilotB6FenceResult: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: PilotCommitTrace.B6Receipt?
    private var failed = false
    var value: PilotCommitTrace.B6Receipt? { get { lock.withLock { stored } } set { lock.withLock { stored = newValue } } }
    var failure: Bool { get { lock.withLock { failed } } set { lock.withLock { failed = newValue } } }
}
#endif
