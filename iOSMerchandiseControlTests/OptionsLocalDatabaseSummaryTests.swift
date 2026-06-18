import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class OptionsLocalDatabaseSummaryTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testLocalDatabaseSummaryCountsUserVisibleHistorySessions() throws {
        let context = try makeContext()
        context.insert(HistoryEntry(id: "history-1"))
        context.insert(HistoryEntry(id: "history-2"))
        let finalFixture = HistoryEntry(id: "TASK135_HISTORY_FINAL_VISIBLE")
        finalFixture.title = "TASK135_HISTORY_FINAL_VISIBLE"
        context.insert(finalFixture)
        let fixture = HistoryEntry(id: "TASK135_MATRIX_LOCAL")
        fixture.title = "TASK135_MATRIX_LOCAL"
        context.insert(fixture)
        context.insert(HistoryEntry(id: "deleted-history", remoteDeletedAt: Date()))
        let pendingDelete = HistoryEntry(id: "pending-delete", remoteDeletedAt: Date())
        pendingDelete.localChangeRevision = 1
        pendingDelete.lastSyncedLocalRevision = 0
        context.insert(pendingDelete)
        try context.save()

        let summary = try LocalDatabasePublicSummary.make(context: context)

        XCTAssertEqual(summary.historySessions, 4)
        XCTAssertEqual(summary.products, 0)
        XCTAssertEqual(summary.suppliers, 0)
        XCTAssertEqual(summary.categories, 0)
        XCTAssertEqual(summary.productPrices, 0)
    }

    func testLocalDatabaseSummaryCountsOnlyPricesForActiveProducts() throws {
        let context = try makeContext()
        let activeProduct = Product(barcode: "active")
        let tombstonedProduct = Product(
            barcode: "deleted",
            remoteID: UUID(),
            remoteDeletedAt: Date()
        )
        context.insert(activeProduct)
        context.insert(tombstonedProduct)
        context.insert(ProductPrice(type: .purchase, price: 1, product: activeProduct))
        context.insert(ProductPrice(type: .purchase, price: 2, product: tombstonedProduct))
        context.insert(ProductPrice(type: .purchase, price: 3))
        try context.save()

        let summary = try LocalDatabasePublicSummary.make(context: context)

        XCTAssertEqual(summary.products, 1)
        XCTAssertEqual(summary.productPrices, 1)
    }

    func testSyncCountDriftRefreshUsesFreshRemoteSnapshotWithoutRefetching() async throws {
        let context = try makeContext()
        var clock = Date(timeIntervalSince1970: 100)
        let provider = OptionsSyncSummaryProvider(now: { clock })
        let remoteFetcher = OptionsRemoteCountFetcher(snapshot: .zero)
        let ownerID = UUID()

        provider.refreshAll(
            context: context,
            authSnapshot: OptionsSyncAuthSnapshot(isSignedIn: true, userID: ownerID),
            remoteCountFetcher: remoteFetcher,
            pendingChanges: []
        )
        try await waitForDriftReport(provider)

        let firstFetchCount = await remoteFetcher.numberOfFetches()
        XCTAssertEqual(firstFetchCount, 1)
        XCTAssertEqual(provider.syncCountDriftReport?.local.products, 0)
        XCTAssertEqual(provider.syncCountDriftReport?.remote.products, 0)
        XCTAssertFalse(provider.needsRemoteCountVerification)

        context.insert(Product(barcode: "local-only"))
        try context.save()
        clock = clock.addingTimeInterval(30)

        provider.refreshAll(
            context: context,
            authSnapshot: OptionsSyncAuthSnapshot(isSignedIn: true, userID: ownerID),
            remoteCountFetcher: remoteFetcher,
            pendingChanges: []
        )

        let cachedRefreshFetchCount = await remoteFetcher.numberOfFetches()
        XCTAssertEqual(cachedRefreshFetchCount, 1)
        try await waitForDriftLocalProducts(provider, expected: 1)
        XCTAssertEqual(provider.syncCountDriftReport?.local.products, 1)
        XCTAssertEqual(provider.syncCountDriftReport?.remote.products, 0)
        XCTAssertEqual(provider.syncCountDriftReport?.mismatches, [.products])
        XCTAssertFalse(provider.needsRemoteCountVerification)

        clock = clock.addingTimeInterval(31)
        provider.refreshAll(
            context: context,
            authSnapshot: OptionsSyncAuthSnapshot(isSignedIn: true, userID: ownerID),
            remoteCountFetcher: remoteFetcher,
            pendingChanges: []
        )
        try await waitForFetchCount(remoteFetcher, expected: 2)
    }

    private func makeContext() throws -> ModelContext {
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
        return ModelContext(container)
    }

    private func waitForDriftReport(_ provider: OptionsSyncSummaryProvider) async throws {
        for _ in 0..<50 {
            if provider.syncCountDriftReport != nil || provider.syncCountDriftCheckFailed {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for sync count drift refresh.")
    }

    private func waitForDriftLocalProducts(
        _ provider: OptionsSyncSummaryProvider,
        expected: Int
    ) async throws {
        for _ in 0..<80 {
            if provider.syncCountDriftReport?.local.products == expected {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for sync count drift local products \(expected).")
    }

    private func waitForFetchCount(
        _ remoteFetcher: OptionsRemoteCountFetcher,
        expected: Int
    ) async throws {
        for _ in 0..<50 {
            if await remoteFetcher.numberOfFetches() == expected {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for remote count fetch \(expected).")
    }
}

private actor OptionsRemoteCountFetcher: OptionsSyncRemoteCountFetching {
    private let snapshot: SyncInventoryCountSnapshot
    private(set) var fetchCount = 0

    init(snapshot: SyncInventoryCountSnapshot) {
        self.snapshot = snapshot
    }

    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot {
        fetchCount += 1
        return snapshot
    }

    func numberOfFetches() -> Int {
        fetchCount
    }
}
