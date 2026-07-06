import SwiftData
import XCTest
@testable import iOSMerchandiseControl

final class SyncEventIncrementalDomainApplyServiceTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    @MainActor
    func testUnrecoverableGapDoesNotAdvanceWatermarkPastUnappliedEvent() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let event = try syncEventRow(
            id: 101,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 1,
            entityIDsJSON: "null"
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: [event])
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        )

        let summary = try await service.applyNextEvents(
            ownerUserID: owner,
            modelContainer: try makeContainer(),
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_missing_entity_ids")
        XCTAssertEqual(summary.watermarkBefore, 0)
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(
            WatermarkStore(defaults: defaults).watermark(
                for: WatermarkStore.Scope(ownerUserID: owner, storeIdentity: .anonymous)
            ),
            0
        )
        let applyStatus = try XCTUnwrap(SyncEventApplyStatusStore(defaults: defaults).record(ownerUserID: owner, eventID: 101))
        XCTAssertEqual(applyStatus.status, .blocked)
        XCTAssertEqual(applyStatus.reason, .missingEntityIDs)
        XCTAssertEqual(applyStatus.attemptCount, 1)
        XCTAssertNotNil(applyStatus.nextRetryAtMs)
    }

    @MainActor
    func testCatalogIncrementalEventRenamesExistingSupplier() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333334")!
        let supplierID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(
            Supplier(
                name: "Old Supplier",
                remoteID: supplierID,
                remoteUpdatedAt: SupabaseRemoteDateParser.parse("2026-07-05T14:00:00Z")
            )
        )
        try context.save()

        let event = try syncEventRow(
            id: 102,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 1,
            entityIDsJSON: #"{"supplier_ids":["44444444-4444-4444-8444-444444444444"]}"#
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            suppliers: [
                RemoteInventorySupplierRow(
                    id: supplierID,
                    ownerUserID: owner,
                    name: "Updated Supplier",
                    updatedAt: "2026-07-05T15:00:00Z",
                    deletedAt: nil
                )
            ]
        )
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        )

        let summary = try await service.applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        XCTAssertEqual(summary.suppliersUpdated, 1)
        XCTAssertEqual(summary.totalApplied, 1)
        let applyStatus = try XCTUnwrap(SyncEventApplyStatusStore(defaults: defaults).record(ownerUserID: owner, eventID: 102))
        XCTAssertEqual(applyStatus.status, .applied)
        XCTAssertEqual(applyStatus.reason, .applied)
        XCTAssertNil(applyStatus.nextRetryAtMs)
        let suppliers = try context.fetch(FetchDescriptor<Supplier>())
        XCTAssertEqual(suppliers.map(\.name), ["Updated Supplier"])
        XCTAssertEqual(suppliers.first?.remoteID, supplierID)
    }

    @MainActor
    func testDirtyLocalEventRecordsBlockedApplyStatusAndDoesNotFetchTargetedRows() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333336")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777771")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Product(barcode: "DIRTY-LOCAL", remoteID: productID))
        context.insert(LocalPendingChange(
            ownerUserID: owner,
            entityKind: .product,
            operation: .update,
            origin: .manualCatalogSave,
            logicalKey: "product:remote:\(productID.uuidString.lowercased())",
            entityRemoteID: productID
        ))
        try context.save()

        let event = try syncEventRow(
            id: 104,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 1,
            entityIDsJSON: #"{"product_ids":["77777777-7777-4777-8777-777777777771"]}"#
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: [event])
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        )

        let summary = try await service.applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_dirty_local")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(remote.catalogFetchCallCount, 0)
        let applyStatus = try XCTUnwrap(SyncEventApplyStatusStore(defaults: defaults).record(ownerUserID: owner, eventID: 104))
        XCTAssertEqual(applyStatus.status, .blocked)
        XCTAssertEqual(applyStatus.reason, .dirtyLocal)
        XCTAssertEqual(applyStatus.entityIDs.productIDs, [productID])
        XCTAssertNotNil(applyStatus.nextRetryAtMs)
    }

    @MainActor
    func testSelfOriginEventRecordsSkippedStatusAndAdvancesWatermark() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333337")!
        let productID = UUID(uuidString: "88888888-8888-4888-8888-888888888881")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let event = try syncEventRow(
            id: 105,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 1,
            sourceDeviceID: "ios-device-under-test",
            entityIDsJSON: #"{"product_ids":["88888888-8888-4888-8888-888888888881"]}"#
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: [event])
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults,
            currentDeviceID: "ios-device-under-test"
        )

        let summary = try await service.applyNextEvents(
            ownerUserID: owner,
            modelContainer: try makeContainer(),
            isAuthenticated: true
        )

        XCTAssertEqual(summary.watermarkAfter, 105)
        XCTAssertEqual(remote.catalogFetchCallCount, 0)
        let applyStatus = try XCTUnwrap(SyncEventApplyStatusStore(defaults: defaults).record(ownerUserID: owner, eventID: 105))
        XCTAssertEqual(applyStatus.status, .skipped)
        XCTAssertEqual(applyStatus.reason, .selfOrigin)
        XCTAssertEqual(applyStatus.entityIDs.productIDs, [productID])
    }

    @MainActor
    func testMissingRemoteTargetRecordsBlockedStatusAndDoesNotAdvanceWatermark() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333338")!
        let productID = UUID(uuidString: "99999999-9999-4999-8999-999999999991")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let event = try syncEventRow(
            id: 106,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 1,
            entityIDsJSON: #"{"product_ids":["99999999-9999-4999-8999-999999999991"]}"#
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: [event])
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        )

        let summary = try await service.applyNextEvents(
            ownerUserID: owner,
            modelContainer: try makeContainer(),
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_missing_remote")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(remote.catalogFetchCallCount, 2)
        let applyStatus = try XCTUnwrap(SyncEventApplyStatusStore(defaults: defaults).record(ownerUserID: owner, eventID: 106))
        XCTAssertEqual(applyStatus.status, .blocked)
        XCTAssertEqual(applyStatus.reason, .missingRemote)
        XCTAssertEqual(applyStatus.entityIDs.productIDs, [productID])
        XCTAssertNotNil(applyStatus.nextRetryAtMs)
    }

    @MainActor
    func testProductPriceConflictDoesNotBlockIndependentPriceRows() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333335")!
        let productAID = UUID(uuidString: "55555555-5555-4555-8555-555555555551")!
        let productBID = UUID(uuidString: "55555555-5555-4555-8555-555555555552")!
        let priceAID = UUID(uuidString: "66666666-6666-4666-8666-666666666661")!
        let priceBID = UUID(uuidString: "66666666-6666-4666-8666-666666666662")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let container = try makeContainer()
        let context = ModelContext(container)
        let productA = Product(barcode: "PRICE-A", remoteID: productAID)
        let productB = Product(barcode: "PRICE-B", remoteID: productBID)
        context.insert(productA)
        context.insert(productB)
        context.insert(
            ProductPrice(
                type: .purchase,
                price: 1.00,
                effectiveAt: try date("2026-07-05T10:00:00Z"),
                source: "LOCAL_CONFLICT",
                product: productA
            )
        )
        try context.save()

        let event = try syncEventRow(
            id: 103,
            ownerUserID: owner,
            domain: "prices",
            changedCount: 2,
            entityIDsJSON: #"{"price_ids":["66666666-6666-4666-8666-666666666661","66666666-6666-4666-8666-666666666662"]}"#
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            products: [
                RemoteInventoryProductRow(
                    id: productAID,
                    ownerUserID: owner,
                    barcode: "PRICE-A",
                    itemNumber: nil,
                    productName: "Price A",
                    secondProductName: nil,
                    purchasePrice: nil,
                    retailPrice: nil,
                    supplierID: nil,
                    categoryID: nil,
                    stockQuantity: nil,
                    updatedAt: "2026-07-05T10:00:00Z",
                    deletedAt: nil
                ),
                RemoteInventoryProductRow(
                    id: productBID,
                    ownerUserID: owner,
                    barcode: "PRICE-B",
                    itemNumber: nil,
                    productName: "Price B",
                    secondProductName: nil,
                    purchasePrice: nil,
                    retailPrice: nil,
                    supplierID: nil,
                    categoryID: nil,
                    stockQuantity: nil,
                    updatedAt: "2026-07-05T10:00:00Z",
                    deletedAt: nil
                )
            ],
            productPrices: [
                RemoteInventoryProductPriceRow(
                    id: priceAID,
                    ownerUserID: owner,
                    productID: productAID,
                    type: "PURCHASE",
                    price: 2.00,
                    effectiveAt: "2026-07-05T10:00:00Z",
                    source: "REMOTE_CONFLICT",
                    note: nil,
                    createdAt: "2026-07-05T10:00:00Z"
                ),
                RemoteInventoryProductPriceRow(
                    id: priceBID,
                    ownerUserID: owner,
                    productID: productBID,
                    type: "RETAIL",
                    price: 3.00,
                    effectiveAt: "2026-07-05T11:00:00Z",
                    source: "REMOTE_OK",
                    note: nil,
                    createdAt: "2026-07-05T11:00:00Z"
                )
            ]
        )
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        )

        let summary = try await service.applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        XCTAssertEqual(summary.productPricesInserted, 1)
        XCTAssertEqual(summary.watermarkAfter, 103)
        let prices = try context.fetch(FetchDescriptor<ProductPrice>())
        XCTAssertEqual(prices.count, 2)
        XCTAssertTrue(prices.contains { $0.remoteID == priceBID && $0.price == 3.00 })
        XCTAssertTrue(prices.contains { $0.remoteID == nil && $0.price == 1.00 })
    }

    private func syncEventRow(
        id: Int64,
        ownerUserID: UUID,
        domain: String,
        changedCount: Int,
        entityIDsJSON: String
    ) throws -> RemoteSyncEventRow {
        try syncEventRow(
            id: id,
            ownerUserID: ownerUserID,
            domain: domain,
            changedCount: changedCount,
            sourceDeviceID: "android-test",
            entityIDsJSON: entityIDsJSON
        )
    }

    private func syncEventRow(
        id: Int64,
        ownerUserID: UUID,
        domain: String,
        changedCount: Int,
        sourceDeviceID: String,
        entityIDsJSON: String
    ) throws -> RemoteSyncEventRow {
        let json = """
        {
          "id": \(id),
          "owner_user_id": "\(ownerUserID.uuidString)",
          "store_id": null,
          "domain": "\(domain)",
          "event_type": "test",
          "source": "test",
          "source_device_id": "\(sourceDeviceID)",
          "batch_id": null,
          "client_event_id": "TASK123-\(id)",
          "changed_count": \(changedCount),
          "entity_ids": \(entityIDsJSON),
          "created_at": "2026-05-25T00:00:00Z",
          "expires_at": null,
          "metadata": {}
        }
        """
        return try JSONDecoder().decode(RemoteSyncEventRow.self, from: Data(json.utf8))
    }

    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: value))
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            HistoryEntry.self,
            ProductPrice.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self,
            SyncEventOutboxEntry.self,
            LocalPendingChange.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return container
    }
}

@MainActor
private final class SyncEventIncrementalDomainApplyRemoteFake: SyncAutomaticIncrementalRemote, @unchecked Sendable {
    private let events: [RemoteSyncEventRow]
    private let suppliers: [RemoteInventorySupplierRow]
    private let categories: [RemoteInventoryCategoryRow]
    private let products: [RemoteInventoryProductRow]
    private let productPrices: [RemoteInventoryProductPriceRow]
    private(set) var catalogFetchCallCount = 0

    init(
        events: [RemoteSyncEventRow],
        suppliers: [RemoteInventorySupplierRow] = [],
        categories: [RemoteInventoryCategoryRow] = [],
        products: [RemoteInventoryProductRow] = [],
        productPrices: [RemoteInventoryProductPriceRow] = []
    ) {
        self.events = events
        self.suppliers = suppliers
        self.categories = categories
        self.products = products
        self.productPrices = productPrices
    }

    func fetchSyncEventsAfter(ownerUserID: UUID, afterID: Int64, limit: Int) async throws -> [RemoteSyncEventRow] {
        Array(events.filter { $0.ownerUserID == ownerUserID && $0.id > afterID }.prefix(limit))
    }

    func fetchCatalogByIDs(
        supplierIDs: Set<UUID>,
        categoryIDs: Set<UUID>,
        productIDs: Set<UUID>
    ) async throws -> (
        suppliers: [RemoteInventorySupplierRow],
        categories: [RemoteInventoryCategoryRow],
        products: [RemoteInventoryProductRow]
    ) {
        catalogFetchCallCount += 1
        return (
            suppliers.filter { supplierIDs.contains($0.id) },
            categories.filter { categoryIDs.contains($0.id) },
            products.filter { productIDs.contains($0.id) }
        )
    }

    func fetchProductPricesByIDs(
        ownerUserID: UUID,
        priceIDs: Set<UUID>
    ) async throws -> [RemoteInventoryProductPriceRow] {
        productPrices.filter { $0.ownerUserID == ownerUserID && priceIDs.contains($0.id) }
    }

    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot {
        .zero
    }

    func upsertSharedSheetSessions(
        _ rows: [SharedSheetSessionUpsertRow],
        ownerUserID: UUID
    ) async throws -> [RemoteSharedSheetSessionRow] {
        []
    }

    func fetchSharedSheetSessionsPage(
        ownerUserID: UUID,
        from: Int,
        to: Int
    ) async throws -> [RemoteSharedSheetSessionRow] {
        []
    }

    func fetchSharedSheetSessionsByIDs(
        ownerUserID: UUID,
        sessionIDs: Set<UUID>
    ) async throws -> [RemoteSharedSheetSessionRow] {
        []
    }
}
