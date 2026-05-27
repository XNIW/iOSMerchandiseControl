import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class OptionsSyncSummaryProviderTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testRefreshIsDebouncedAndCoalescesRepeatedAppearNotifications() async throws {
        let context = try makeContext()
        context.insert(Product(barcode: "TASK127_PRODUCT"))
        try context.save()

        let provider = OptionsSyncSummaryProvider(now: { Date(timeIntervalSince1970: 1_000) })
        provider.refreshAll(
            context: context,
            authSnapshot: OptionsSyncAuthSnapshot(isSignedIn: false, userID: nil),
            remoteCountFetcher: nil,
            refreshReason: "appear"
        )
        XCTAssertTrue(provider.isLoading)

        provider.refreshAll(
            context: context,
            authSnapshot: OptionsSyncAuthSnapshot(isSignedIn: false, userID: nil),
            remoteCountFetcher: nil,
            refreshReason: "notification"
        )
        XCTAssertEqual(provider.coalescedEvents, 1)

        try await waitForSummary(provider)

        XCTAssertFalse(provider.isLoading)
        XCTAssertFalse(provider.isStale)
        XCTAssertEqual(provider.localDatabaseSummary.products, 1)
        XCTAssertEqual(provider.refreshReason, "notification")
        XCTAssertNotNil(provider.lastRefreshedAt)
    }

    func testCoalescedRefreshRunsAgainWithLatestLocalData() async throws {
        let context = try makeContext()
        context.insert(Product(barcode: "TASK127_INITIAL"))
        try context.save()

        let provider = OptionsSyncSummaryProvider(now: { Date(timeIntervalSince1970: 1_100) })
        provider.refreshAll(
            context: context,
            authSnapshot: OptionsSyncAuthSnapshot(isSignedIn: false, userID: nil),
            remoteCountFetcher: nil,
            refreshReason: "appear"
        )

        context.insert(Product(barcode: "TASK127_DURING_INFLIGHT"))
        try context.save()
        provider.refreshAll(
            context: context,
            authSnapshot: OptionsSyncAuthSnapshot(isSignedIn: false, userID: nil),
            remoteCountFetcher: nil,
            refreshReason: "pending-change"
        )

        try await waitForSummary(provider, expectedProductCount: 2)
        XCTAssertEqual(provider.coalescedEvents, 1)
        XCTAssertEqual(provider.refreshReason, "pending-change")
    }

    func testRemoteDriftDoesNotBlockInitialLocalSummary() async throws {
        let context = try makeContext()
        context.insert(Product(barcode: "TASK127_LOCAL"))
        try context.save()

        let provider = OptionsSyncSummaryProvider(now: { Date(timeIntervalSince1970: 2_000) })
        let remote = SlowRemoteCountFetcher(snapshot: .zero)
        provider.refreshAll(
            context: context,
            authSnapshot: OptionsSyncAuthSnapshot(isSignedIn: true, userID: UUID()),
            remoteCountFetcher: remote,
            refreshReason: "appear"
        )

        try await waitForSummary(provider)
        XCTAssertEqual(provider.localDatabaseSummary.products, 1)
        XCTAssertNil(provider.syncCountDriftReport)

        await remote.release()
        try await waitForDrift(provider)
        XCTAssertEqual(provider.syncCountDriftReport?.mismatches, [.products])
    }

    private func waitForSummary(_ provider: OptionsSyncSummaryProvider) async throws {
        try await waitForSummary(provider, expectedProductCount: nil)
    }

    private func waitForSummary(
        _ provider: OptionsSyncSummaryProvider,
        expectedProductCount: Int?
    ) async throws {
        for _ in 0..<120 {
            let productCountMatches = expectedProductCount.map { provider.localDatabaseSummary.products == $0 } ?? true
            if !provider.isLoading, provider.lastRefreshedAt != nil, productCountMatches {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for Options summary refresh.")
    }

    private func waitForDrift(_ provider: OptionsSyncSummaryProvider) async throws {
        for _ in 0..<80 {
            if provider.syncCountDriftReport != nil || provider.syncCountDriftCheckFailed {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for drift report.")
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
}

private actor SlowRemoteCountFetcher: OptionsSyncRemoteCountFetching {
    private let snapshot: SyncInventoryCountSnapshot
    private var continuation: CheckedContinuation<Void, Never>?
    private var released = false

    init(snapshot: SyncInventoryCountSnapshot) {
        self.snapshot = snapshot
    }

    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot {
        if released {
            return snapshot
        }
        await withCheckedContinuation { continuation in
            if released {
                continuation.resume()
            } else {
                self.continuation = continuation
            }
        }
        return snapshot
    }

    func release() {
        released = true
        continuation?.resume()
        continuation = nil
    }
}
