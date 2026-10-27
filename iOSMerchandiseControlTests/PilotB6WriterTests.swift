#if DEBUG
import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor final class PilotB6WriterTests: XCTestCase {
    private static var retained: [ModelContainer] = []
    override func tearDown() { _ = PilotCommitTrace.b6ReceiptAndDisarm(); super.tearDown() }

    func testActualCatalogCreateWriterBridgesOriginalIntentToDurableSealAndOwnAck() async throws {
        try await exerciseCatalog(.create)
    }
    func testActualCatalogUpdateWriterBridgesOriginalIntentToDurableSealAndOwnAck() async throws {
        try await exerciseCatalog(.update)
    }
    func testActualCatalogDeleteWriterBridgesOriginalIntentToDurableSealAndOwnAck() async throws {
        try await exerciseCatalog(.delete)
    }
    func testActualCatalogWriterWithoutSourceEntryObservationCannotQualifyTotal() async throws {
        try await exerciseCatalog(.update, observeEntry: false)
    }
    private func exerciseCatalog(_ operation: LocalPendingChangeOperation, observeEntry: Bool = true) async throws {
        let f = try fixture(); defer { f.defaults.removePersistentDomain(forName: f.suite) }
        let body = Product(barcode: "B6-writer", remoteID: operation == .create ? nil : f.id, productName: "After")
        var binding = sourceBinding(f, category: operation.rawValue,
            body: operation == .delete ? PilotCommitTrace.b6DeletedProductBody(f.id) : PilotCommitTrace.b6ProductBody(body))
        if operation == .delete {
            binding = .init(operationID: UUID().uuidString, sampleID: "T20-G01-06", role: "source", category: "delete",
                scopeHash: PilotCommitTrace.b6ScopeHash(f.scope), manifestHash: stamp, authPreflightHash: stamp,
                twoCASReceiptHash: stamp, artifactHash: stamp, entityRemoteID: f.id,
                expectedLocalBodyHash: PilotCommitTrace.b6DeletedProductBody(f.id),
                expectedVisibleFields: ["barcodeQuery": "B6-writer", "resultCount": "0"], baselineVisibleFields: [:],
                route: "database.products.exact-query", expectedBarcode: "B6-writer",
                bodySemantics: "product_absence_v1", baselineLocalBodyHash: PilotCommitTrace.b6ProductBody(body))
        }
        XCTAssertTrue(PilotCommitTrace.b6Arm(binding))
        if observeEntry { PilotCommitTrace.b6SourceMutationBegin(categories: [operation.rawValue]) }
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: f.container, ownerUserID: f.owner, defaults: f.defaults) { context in
            context.insert(body)
            let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: f.owner,
                storeIdentity: f.scope.storeIdentity, emitsNotifications: false)
            let pending = try XCTUnwrap(accumulator.recordProductChange(product: body, operation: operation,
                origin: .manualCatalogSave, changedFields: ["productName"]))
            let ticket = operation == .delete
                ? PilotCommitTrace.b6LocalDeleteBegin(product: body, intents: [LocalPendingChangeCASToken(pending)], scope: f.scope)
                : PilotCommitTrace.b6LocalBegin(product: body, intents: [LocalPendingChangeCASToken(pending)], scope: f.scope)
            XCTAssertNotNil(ticket)
            if operation == .delete { context.delete(body) }
            try context.save()
            PilotCommitTrace.b6LocalEnd(ticket, returned: true, ns: PilotCommitTrace.b6Now())
        }
        let remote = PilotB6WriterCatalogRemote(owner: f.owner, shop: f.scope.shopID)
        let result = try await CatalogPushService(modelContainer: f.container, remote: remote, defaults: f.defaults)
            .pushPendingCatalog(ownerUserID: f.owner)
        XCTAssertEqual(result.totalChanged, 1)
        XCTAssertEqual(remote.calls, 1)
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        try assertTransition(receipt, observesEntry: observeEntry)
        XCTAssertEqual(receipt.resolvedEntityRemoteID, remote.lastID)
        XCTAssertEqual(receipt.observationComplete, observeEntry)
        XCTAssertEqual(try ModelContext(f.container).fetch(FetchDescriptor<LocalPendingChange>()).first?.status, .acknowledged)
    }
    func testActualHistoryWriterBridgesOriginalRevisionToDurableSealAndOwnAck() async throws {
        let f = try fixture(); defer { f.defaults.removePersistentDomain(forName: f.suite) }
        let entry = HistoryEntry(id: "B6-history", timestamp: Date(timeIntervalSince1970: 1_787_000_000),
            data: [["barcode"], ["B6-writer"]], editable: [[""], [""]], complete: [false, true],
            uid: UUID(), remoteID: f.id, localChangeRevision: 2, lastSyncedLocalRevision: 1)
        entry.title = "After"; entry.assignHistoryScope(ownerUserID: f.owner, selectedShopID: f.scope.shopID, storeIdentity: f.scope.storeIdentity)
        let expected = try XCTUnwrap(PilotCommitTrace.b6HistoryBody(entry))
        let binding = PilotCommitTrace.B6Binding(operationID: UUID().uuidString, sampleID: "T20-G01-08", role: "source", category: "history",
            scopeHash: PilotCommitTrace.b6ScopeHash(f.scope), manifestHash: stamp, authPreflightHash: stamp,
            twoCASReceiptHash: stamp, artifactHash: stamp, entityRemoteID: f.id, expectedLocalBodyHash: expected,
            expectedVisibleFields: ["title": "After"], baselineVisibleFields: ["title": "Before"], route: "history.sessions",
            bodySemantics: "history_payload_v1")
        XCTAssertTrue(PilotCommitTrace.b6Arm(binding))
        PilotCommitTrace.b6SourceMutationBegin(categories: ["history"])
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: f.container, ownerUserID: f.owner, defaults: f.defaults) { context in
            context.insert(entry)
            let pending = LocalPendingChange(ownerUserID: f.owner, ownerHash: f.scope.accountHash,
                storeId: f.scope.storeIdentity.storeId, localStoreId: f.scope.storeIdentity.localStoreId,
                syncProtocolVersion: f.scope.storeIdentity.syncProtocolVersion, schemaVersion: f.scope.storeIdentity.schemaVersion,
                storeEpoch: f.scope.storeIdentity.storeEpoch, entityKind: .historySession, operation: .upsert, origin: .historySessionSave,
                logicalKey: LocalPendingChangeLogicalKey.historySession(remoteID: f.id, uid: entry.uid), changedFields: ["title"],
                intendedFingerprintHash: expected, entityRemoteID: f.id)
            context.insert(pending)
            let ticket = PilotCommitTrace.b6LocalHistoryBegin(entry: entry, intents: [LocalPendingChangeCASToken(pending)], scope: f.scope)
            XCTAssertNotNil(ticket); try context.save()
            PilotCommitTrace.b6LocalEnd(ticket, returned: true, ns: PilotCommitTrace.b6Now())
        }
        let remote = PilotB6WriterHistoryRemote()
        let result = try await HistorySessionPushService(modelContainer: f.container, remote: remote, recorder: nil, defaults: f.defaults)
            .syncHistorySessions(ownerUserID: f.owner, mode: .incremental)
        XCTAssertEqual(result.uploaded, 1); XCTAssertEqual(remote.calls, 1)
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm()); try assertTransition(receipt)
        XCTAssertTrue(receipt.observationComplete)
        XCTAssertEqual(receipt.events.last?.entityLocalID, entry.uid)
        XCTAssertEqual(receipt.events.last?.localRevision, 2)
        XCTAssertEqual(receipt.resolvedEntityRemoteID, f.id)
    }
    func testSameChangeIDWithAlteredIntentCannotBridgeOrClaimSourceAck() throws {
        let f = try fixture(); defer { f.defaults.removePersistentDomain(forName: f.suite) }
        let p = Product(barcode: "B6-writer", remoteID: f.id, productName: "After")
        XCTAssertTrue(PilotCommitTrace.b6Arm(sourceBinding(f, category: "update", body: PilotCommitTrace.b6ProductBody(p))))
        PilotCommitTrace.b6SourceMutationBegin(categories: ["update"])
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: f.container, ownerUserID: f.owner, defaults: f.defaults) { context in
            context.insert(p)
            let pending = try XCTUnwrap(LocalPendingChangeAccumulator(context: context, ownerUserID: f.owner,
                storeIdentity: f.scope.storeIdentity, emitsNotifications: false).recordProductChange(product: p,
                    operation: .update, origin: .manualCatalogSave, changedFields: ["productName"]))
            let original = LocalPendingChangeCASToken(pending)
            let ticket = PilotCommitTrace.b6LocalBegin(product: p, intents: [original], scope: f.scope)
            XCTAssertNotNil(ticket); try context.save()
            PilotCommitTrace.b6LocalEnd(ticket, returned: true, ns: PilotCommitTrace.b6Now())
            pending.lastAttemptAt = Date(); pending.intendedFingerprintHash = String(repeating: "b", count: 64)
            let changed = LocalPendingChangeCASToken(pending)
            PilotCommitTrace.b6SourcePrepared(original: original, sealed: changed, scope: f.scope)
            PilotCommitTrace.b6SourceIdentityAcknowledged(pending: changed, remoteID: f.id,
                rawVersion: "2026-10-23T12:34:56.123456Z", scope: f.scope)
        }
        let receipt = try XCTUnwrap(PilotCommitTrace.b6ReceiptAndDisarm())
        XCTAssertNotNil(receipt.originalIntent); XCTAssertNil(receipt.preparedIntent)
        XCTAssertEqual(receipt.events.map(\.stage), ["source_local_mutation_begin", "local_commit_call_begin", "local_commit_return"])
        XCTAssertFalse(receipt.observationComplete)
    }
    private func assertTransition(_ receipt: PilotCommitTrace.B6Receipt, observesEntry: Bool = true) throws {
        XCTAssertNil(receipt.invalidReason)
        let prefix = observesEntry ? ["source_local_mutation_begin"] : []
        XCTAssertEqual(receipt.events.map(\.stage), prefix + ["local_commit_call_begin", "local_commit_return", "source_durable_seal_transition", "source_actual_ack_identity_persisted"])
        let original = try XCTUnwrap(receipt.originalIntent), prepared = try XCTUnwrap(receipt.preparedIntent)
        XCTAssertNil(original.lastAttemptAt); XCTAssertNotNil(prepared.lastAttemptAt)
        XCTAssertNotEqual(original, prepared)
        XCTAssertEqual(original.changeID, prepared.changeID)
        XCTAssertEqual(original.logicalKey, prepared.logicalKey)
        XCTAssertEqual(original.intendedFingerprintHash, prepared.intendedFingerprintHash)
        let seal = try XCTUnwrap(receipt.events.first { $0.stage == "source_durable_seal_transition" })
        let ack = try XCTUnwrap(receipt.events.first { $0.stage == "source_actual_ack_identity_persisted" })
        XCTAssertEqual(seal.tokenHash, ack.tokenHash)
        XCTAssertNotEqual(seal.priorTokenHash, seal.tokenHash)
        if observesEntry {
            let action = try XCTUnwrap(receipt.events.first), commit = try XCTUnwrap(receipt.events.first { $0.stage == "local_commit_call_begin" })
            XCTAssertEqual(action.applyID, commit.applyID)
            XCTAssertLessThanOrEqual(action.ns, commit.ns)
        }
    }
    private let stamp = String(repeating: "a", count: 64)
    private func sourceBinding(_ f: PilotB6WriterFixture, category: String, body: String) -> PilotCommitTrace.B6Binding {
        .init(operationID: UUID().uuidString, sampleID: category == "create" ? "T20-G01-04" : "T20-G01-05", role: "source", category: category,
            scopeHash: PilotCommitTrace.b6ScopeHash(f.scope), manifestHash: stamp, authPreflightHash: stamp,
            twoCASReceiptHash: stamp, artifactHash: stamp, entityRemoteID: category == "create" ? nil : f.id,
            expectedLocalBodyHash: body, expectedVisibleFields: ["productName": "After"], baselineVisibleFields: ["productName": "Before"],
            route: "database.products", expectedBarcode: category == "create" ? "B6-writer" : nil)
    }
    private func fixture() throws -> PilotB6WriterFixture {
        let suite = "B6-writer-\(UUID().uuidString)", owner = UUID()
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let shop = SelectedShop(shopID: UUID(), code: "UNIT", name: "Unit", role: "owner", status: "active", selectable: true, canWrite: true)
        let account = AccountBindingStore.accountHash(for: owner), selected = SelectedShopStore(defaults: defaults)
        selected.noteActiveAccount(account); XCTAssertTrue(selected.save(shop, accountHash: account))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(accountHash: account, storeIdentity: shop.localStoreIdentity))
        _ = try DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID()
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let schema = Schema([Product.self, Supplier.self, ProductCategory.self, HistoryEntry.self, ProductPrice.self,
            SupabaseCatalogBaselineRun.self, SupabaseCatalogBaselineRecord.self, SyncEventOutboxEntry.self, LocalPendingChange.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        Self.retained.append(container)
        return .init(owner: owner, id: UUID(), suite: suite, defaults: defaults, scope: scope, container: container)
    }
}
@MainActor private struct PilotB6WriterFixture {
    let owner: UUID; let id: UUID; let suite: String; let defaults: UserDefaults
    let scope: Task126VerifiedOwnerStoreScope; let container: ModelContainer
}
private enum PilotB6UnexpectedRemote: Error { case call }
@MainActor private final class PilotB6WriterCatalogRemote: SyncAutomaticCatalogRemoteWriting {
    let owner: UUID; let shop: UUID
    var calls = 0; var lastID: UUID?
    init(owner: UUID, shop: UUID) { self.owner = owner; self.shop = shop }
    func createSuppliers(_ payloads: [SyncAutomaticSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow] { throw PilotB6UnexpectedRemote.call }
    func updateSupplier(id: UUID, payload: SyncAutomaticSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow { throw PilotB6UnexpectedRemote.call }
    func createCategories(_ payloads: [SyncAutomaticCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow] { throw PilotB6UnexpectedRemote.call }
    func updateCategory(id: UUID, payload: SyncAutomaticCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow { throw PilotB6UnexpectedRemote.call }
    func createProducts(_ payloads: [SyncAutomaticProductCreatePayload]) async throws -> [RemoteInventoryProductRow] {
        calls += 1; lastID = payloads.first?.id
        return payloads.map { .init(id: $0.id, ownerUserID: owner, shopID: shop, barcode: $0.barcode,
            itemNumber: $0.itemNumber, productName: $0.productName, secondProductName: $0.secondProductName,
            purchasePrice: $0.purchasePrice, retailPrice: $0.retailPrice, supplierID: $0.supplierID, categoryID: $0.categoryID,
            stockQuantity: $0.stockQuantity, updatedAt: "2026-10-23T12:34:56.123456Z", deletedAt: nil) }
    }
    func updateProduct(id: UUID, payload: SyncAutomaticProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        calls += 1; lastID = id
        return .init(id: id, ownerUserID: owner, shopID: shop, barcode: payload.barcode ?? "B6-writer",
            itemNumber: payload.itemNumber, productName: payload.productName ?? "After", secondProductName: payload.secondProductName,
            purchasePrice: payload.purchasePrice, retailPrice: payload.retailPrice, supplierID: payload.supplierID, categoryID: payload.categoryID,
            stockQuantity: payload.stockQuantity, updatedAt: "2026-10-23T12:34:56.123456Z", deletedAt: payload.deletedAt)
    }
}
@MainActor private final class PilotB6WriterHistoryRemote: HistorySessionRemoteWriting {
    var calls = 0
    func upsertSharedSheetSessions(_ rows: [SharedSheetSessionUpsertRow], ownerUserID: UUID) async throws -> [RemoteSharedSheetSessionRow] {
        calls += 1
        return rows.map { .init(remoteID: $0.remoteID, payloadVersion: $0.payloadVersion, displayName: $0.displayName,
            timestamp: $0.timestamp, supplier: $0.supplier, category: $0.category, isManualEntry: $0.isManualEntry,
            data: $0.data, sessionOverlay: $0.sessionOverlay, ownerUserID: ownerUserID, shopID: $0.shopID,
            updatedAt: "2026-10-23T12:34:56.123456Z", deletedAt: $0.deletedAt) }
    }
    func fetchSharedSheetSessionsPage(ownerUserID: UUID, from: Int, to: Int) async throws -> [RemoteSharedSheetSessionRow] { throw PilotB6UnexpectedRemote.call }
    func fetchSharedSheetSessionsByIDs(ownerUserID: UUID, sessionIDs: Set<UUID>) async throws -> [RemoteSharedSheetSessionRow] { throw PilotB6UnexpectedRemote.call }
}
#endif
