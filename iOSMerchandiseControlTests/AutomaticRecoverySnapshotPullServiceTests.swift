import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class AutomaticRecoverySnapshotPullServiceTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testRemoteDuplicateLookupNameFailsBeforeAnyRecoveryMutation() async throws {
        try await assertRecoveryPreflightFailsWithoutMutation(
            mode: .duplicateRemoteLookupName,
            expectedError: .duplicateRemoteLookupName
        )
    }

    func testPreviewConflictFailsBeforeHistoryPriceOrBaselineApply() async throws {
        try await assertRecoveryPreflightFailsWithoutMutation(
            mode: .duplicateRemoteProductBarcode,
            expectedError: .previewConflict
        )
    }

    func testWatermarkScanStopsAtBudgetBeforeSnapshotOrApply() async throws {
        let fixture = try makeFixture()
        defer {
            fixture.defaults.removePersistentDomain(forName: fixture.suiteName)
        }

        let remote = AutomaticRecoveryPreflightRemote(
            ownerUserID: fixture.ownerUserID,
            shopID: fixture.shopID,
            mode: .unboundedSyncEventPages
        )
        let service = AutomaticRecoverySnapshotPullService(
            modelContainer: fixture.container,
            previewService: SupabasePullPreviewService(
                inventoryService: remote,
                pageSize: 10
            ),
            productPriceApplyService: SupabaseProductPriceApplyService(fetcher: remote),
            historyRemote: remote,
            syncEventFetcher: remote,
            defaults: fixture.defaults,
            maximumWatermarkScanPages: 2
        )
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: fixture.ownerUserID,
            defaults: fixture.defaults
        )

        do {
            _ = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                try await service.recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
            }
            XCTFail("An unbounded watermark scan must fail closed at its page budget")
        } catch {
            XCTAssertEqual(
                error as? AutomaticRecoverySnapshotPullError,
                .watermarkScanLimitExceeded(
                    maximumPages: 2,
                    pageSize: SupabaseSyncEventIncrementalLimits.maximumLimit
                )
            )
        }

        let context = ModelContext(fixture.container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Supplier>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProductCategory>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HistoryEntry>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProductPrice>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SupabaseCatalogBaselineRun>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SupabaseCatalogBaselineRecord>()), 0)

        let counters = await remote.operationCounters()
        XCTAssertEqual(counters.syncEventFetches, 2)
        XCTAssertEqual(counters.catalogProductFetches, 0)
        XCTAssertEqual(counters.catalogSupplierFetches, 0)
        XCTAssertEqual(counters.catalogCategoryFetches, 0)
        XCTAssertEqual(counters.catalogProductPriceFetches, 0)
        XCTAssertEqual(counters.historyFetches, 0)
        XCTAssertEqual(counters.historyUpserts, 0)
        XCTAssertEqual(counters.productPriceApplyFetches, 0)
        XCTAssertEqual(counters.productPriceCountFetches, 0)
    }

    private func assertRecoveryPreflightFailsWithoutMutation(
        mode: AutomaticRecoveryPreflightRemote.Mode,
        expectedError: ExpectedError
    ) async throws {
        let fixture = try makeFixture()
        defer {
            fixture.defaults.removePersistentDomain(forName: fixture.suiteName)
        }

        let remote = AutomaticRecoveryPreflightRemote(
            ownerUserID: fixture.ownerUserID,
            shopID: fixture.shopID,
            mode: mode
        )
        let service = AutomaticRecoverySnapshotPullService(
            modelContainer: fixture.container,
            previewService: SupabasePullPreviewService(
                inventoryService: remote,
                pageSize: 10
            ),
            productPriceApplyService: SupabaseProductPriceApplyService(
                fetcher: remote,
                fetchOptions: ProductPriceApplyFetchOptions(
                    pageSize: 10,
                    maxRows: 10,
                    maxPages: 1,
                    fullPullSafetyLimit: 100
                )
            ),
            historyRemote: remote,
            syncEventFetcher: remote,
            defaults: fixture.defaults
        )
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: fixture.ownerUserID,
            defaults: fixture.defaults
        )

        do {
            _ = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                try await service.recoverFromRemoteSnapshot(ownerUserID: fixture.ownerUserID)
            }
            XCTFail("Authoritative recovery must not report completion for an unsafe preview")
        } catch {
            switch expectedError {
            case .duplicateRemoteLookupName:
                XCTAssertEqual(
                    error as? AutomaticRecoverySnapshotPullError,
                    .remoteDuplicateLookupNames(count: 1)
                )
            case .previewConflict:
                XCTAssertEqual(error as? SupabasePullApplyError, .conflictsPresent)
            }
        }

        let context = ModelContext(fixture.container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Supplier>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProductCategory>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HistoryEntry>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProductPrice>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SupabaseCatalogBaselineRun>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<SupabaseCatalogBaselineRecord>()), 0)

        let counters = await remote.operationCounters()
        XCTAssertEqual(counters.historyFetches, 0)
        XCTAssertEqual(counters.historyUpserts, 0)
        XCTAssertEqual(counters.productPriceApplyFetches, 0)
        XCTAssertEqual(counters.productPriceCountFetches, 0)
    }

    private func makeFixture() throws -> Fixture {
        let suiteName = "AutomaticRecoverySnapshotPullServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)

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

        let context = ModelContext(container)
        let supplier = Supplier(name: "Local sentinel supplier")
        let category = ProductCategory(name: "Local sentinel category")
        let product = Product(
            barcode: "TASK139-LOCAL-SENTINEL",
            productName: "Local sentinel product",
            supplier: supplier,
            category: category
        )
        context.insert(supplier)
        context.insert(category)
        context.insert(product)
        try context.save()

        let ownerUserID = UUID()
        let shopID = UUID()
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        let selectedShop = SelectedShop(
            shopID: shopID,
            code: "TASK139",
            name: "Recovery preflight fixture",
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true
        )
        let selectedShopStore = SelectedShopStore(defaults: defaults)
        selectedShopStore.noteActiveAccount(accountHash)
        XCTAssertTrue(selectedShopStore.save(selectedShop, accountHash: accountHash))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(
            accountHash: accountHash,
            storeIdentity: selectedShop.localStoreIdentity
        ))

        return Fixture(
            container: container,
            defaults: defaults,
            suiteName: suiteName,
            ownerUserID: ownerUserID,
            shopID: shopID
        )
    }

    private enum ExpectedError {
        case duplicateRemoteLookupName
        case previewConflict
    }

    private struct Fixture {
        let container: ModelContainer
        let defaults: UserDefaults
        let suiteName: String
        let ownerUserID: UUID
        let shopID: UUID
    }
}

private actor AutomaticRecoveryPreflightRemote:
    SupabaseInventoryFetching,
    SupabaseProductPricePreviewFetching,
    HistorySessionRemoteSyncing,
    SupabaseSyncEventIncrementalFetching {
    enum Mode: Sendable {
        case duplicateRemoteLookupName
        case duplicateRemoteProductBarcode
        case unboundedSyncEventPages
    }

    struct OperationCounters: Sendable, Equatable {
        var syncEventFetches = 0
        var catalogProductFetches = 0
        var catalogSupplierFetches = 0
        var catalogCategoryFetches = 0
        var catalogProductPriceFetches = 0
        var historyFetches = 0
        var historyUpserts = 0
        var productPriceApplyFetches = 0
        var productPriceCountFetches = 0
    }

    private let ownerUserID: UUID
    private let shopID: UUID
    private let mode: Mode
    private let products: [RemoteInventoryProductRow]
    private let suppliers: [RemoteInventorySupplierRow]
    private var counters = OperationCounters()

    init(ownerUserID: UUID, shopID: UUID, mode: Mode) {
        self.ownerUserID = ownerUserID
        self.shopID = shopID
        self.mode = mode
        switch mode {
        case .duplicateRemoteLookupName:
            products = []
            suppliers = [
                RemoteInventorySupplierRow(
                    id: UUID(),
                    ownerUserID: ownerUserID,
                    shopID: shopID,
                    name: "Duplicate supplier",
                    updatedAt: "2026-07-21T00:00:00Z",
                    deletedAt: nil
                ),
                RemoteInventorySupplierRow(
                    id: UUID(),
                    ownerUserID: ownerUserID,
                    shopID: shopID,
                    name: "  duplicate supplier  ",
                    updatedAt: "2026-07-21T00:00:01Z",
                    deletedAt: nil
                )
            ]
        case .duplicateRemoteProductBarcode:
            suppliers = []
            products = [0, 1].map { index in
                RemoteInventoryProductRow(
                    id: UUID(),
                    ownerUserID: ownerUserID,
                    shopID: shopID,
                    barcode: "TASK139-DUPLICATE-BARCODE",
                    itemNumber: nil,
                    productName: "Remote duplicate \(index)",
                    secondProductName: nil,
                    purchasePrice: nil,
                    retailPrice: nil,
                    supplierID: nil,
                    categoryID: nil,
                    stockQuantity: nil,
                    updatedAt: "2026-07-21T00:00:0\(index)Z",
                    deletedAt: nil
                )
            }
        case .unboundedSyncEventPages:
            products = []
            suppliers = []
        }
    }

    func fetchProductsPage(from: Int, to: Int) async throws -> [RemoteInventoryProductRow] {
        counters.catalogProductFetches += 1
        return page(products, from: from, to: to)
    }

    func fetchSuppliersPage(from: Int, to: Int) async throws -> [RemoteInventorySupplierRow] {
        counters.catalogSupplierFetches += 1
        return page(suppliers, from: from, to: to)
    }

    func fetchCategoriesPage(from: Int, to: Int) async throws -> [RemoteInventoryCategoryRow] {
        counters.catalogCategoryFetches += 1
        return []
    }

    func fetchProductPricesPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        counters.catalogProductPriceFetches += 1
        return []
    }

    func fetchProductPricesPreviewPage(
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow] {
        counters.productPriceApplyFetches += 1
        return []
    }

    func fetchProductPriceCount() async throws -> Int? {
        counters.productPriceCountFetches += 1
        return 0
    }

    func upsertSharedSheetSessions(
        _ rows: [SharedSheetSessionUpsertRow],
        ownerUserID: UUID
    ) async throws -> [RemoteSharedSheetSessionRow] {
        counters.historyUpserts += 1
        return []
    }

    func fetchSharedSheetSessionsPage(
        ownerUserID: UUID,
        from: Int,
        to: Int
    ) async throws -> [RemoteSharedSheetSessionRow] {
        counters.historyFetches += 1
        return []
    }

    func fetchSyncEventsAfter(
        ownerUserID: UUID,
        afterID: Int64,
        limit: Int
    ) async throws -> [RemoteSyncEventRow] {
        counters.syncEventFetches += 1
        guard case .unboundedSyncEventPages = mode else { return [] }
        return try (0..<limit).map { offset in
            try Self.syncEvent(
                id: afterID + Int64(offset) + 1,
                ownerUserID: self.ownerUserID,
                shopID: shopID
            )
        }
    }

    func operationCounters() -> OperationCounters {
        counters
    }

    private func page<Row>(_ rows: [Row], from: Int, to: Int) -> [Row] {
        guard from >= 0, to >= from, from < rows.count else { return [] }
        let upperBound = min(to + 1, rows.count)
        return Array(rows[from..<upperBound])
    }

    private nonisolated static func syncEvent(
        id: Int64,
        ownerUserID: UUID,
        shopID: UUID
    ) throws -> RemoteSyncEventRow {
        let json = """
        {
          "id": "\(id)",
          "owner_user_id": "\(ownerUserID.uuidString)",
          "shop_id": "\(shopID.uuidString)",
          "store_id": null,
          "domain": "catalog",
          "event_type": "catalog_changed",
          "source": "TASK139_TEST",
          "source_device_id": "TASK139_WATERMARK_BUDGET_FIXTURE",
          "batch_id": null,
          "client_event_id": "TASK139-WATERMARK-\(id)",
          "changed_count": 0,
          "entity_ids": {"products": []},
          "created_at": "2026-07-21T00:00:00Z",
          "expires_at": null,
          "metadata": {}
        }
        """
        return try JSONDecoder().decode(RemoteSyncEventRow.self, from: Data(json.utf8))
    }
}
