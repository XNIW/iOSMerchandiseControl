import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class OptionsSyncSummaryProviderTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testAcknowledgedIntentsAndLocalBodyProofsDoNotCountAsPendingCloudWork() throws {
        let context = try makeContext()
        let owner = UUID()
        let now = Date(timeIntervalSince1970: 1_000)
        for index in 0..<6 {
            context.insert(LocalPendingChange(
                ownerUserID: owner,
                entityKind: index < 2 ? .product : .productPrice,
                operation: index < 2 ? .create : .upsert,
                status: .acknowledged,
                origin: index < 2 ? .manualCatalogSave : .productPriceSave,
                logicalKey: "fixture-ack-\(index)",
                createdAt: now,
                updatedAt: now
            ))
        }
        for index in 0..<9 {
            let isProof = index >= 3
            let id = "fixture-event-\(index)"
            context.insert(SyncEventOutboxEntry(
                id: id,
                ownerUserID: owner.uuidString.lowercased(),
                clientEventID: id,
                domain: isProof ? LocalCatalogBodyProofStore.domain : "catalog",
                eventType: isProof ? "local_catalog_body_v1" : "updated",
                changedCount: 1,
                entityIDsShape: "fixture-entity-shape-\(index)",
                metadataShape: "fixture-metadata-shape-\(index)",
                entityIDsPayloadJSON: "{\"id\":\"\(id)\"}",
                metadataPayloadJSON: "{\"fixture\":\(index)}",
                status: isProof ? .localOnly : .sent,
                nextRetryAt: now,
                createdAt: now,
                updatedAt: now,
                sentAt: isProof ? nil : now
            ))
        }
        try context.save()
        let before = try outboxSnapshot(context)

        XCTAssertEqual(try OptionsPendingAttentionCounter.countAll(context: context), 0)

        context.insert(LocalPendingChange(
            ownerUserID: owner,
            entityKind: .product,
            operation: .update,
            origin: .manualCatalogSave,
            logicalKey: "fixture-real-pending",
            changedFields: ["productName"],
            createdAt: now,
            updatedAt: now
        ))
        try context.save()
        XCTAssertEqual(try OptionsPendingAttentionCounter.countAll(context: context), 1)
        XCTAssertEqual(try outboxSnapshot(context), before, "Counting must retain every event and local proof unchanged.")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LocalPendingChange>()), 7)
    }

    func testPendingAttentionStillIncludesBlockedAndDeadCloudEvents() throws {
        let context = try makeContext()
        let now = Date(timeIntervalSince1970: 1_000)
        let attentionStatuses: [SyncEventOutboxStatus] = [
            .pending, .sending, .failedRetryable, .blockedContract, .blockedAuth, .blockedSchema, .dead
        ]
        for status in attentionStatuses {
            context.insert(SyncEventOutboxEntry(
                ownerUserID: UUID().uuidString.lowercased(),
                domain: "catalog",
                eventType: "updated",
                changedCount: 1,
                entityIDsShape: "fixture",
                metadataShape: "fixture",
                status: status,
                nextRetryAt: now,
                createdAt: now,
                updatedAt: now
            ))
        }
        try context.save()

        XCTAssertEqual(try OptionsPendingAttentionCounter.countAll(context: context), attentionStatuses.count)
    }

    private func outboxSnapshot(_ context: ModelContext) throws -> [[String]] {
        try context.fetch(FetchDescriptor<SyncEventOutboxEntry>())
            .sorted { $0.id < $1.id }
            .map { entry in
                [entry.id, entry.clientEventID, entry.ownerUserID, entry.domain, entry.eventType,
                 entry.statusRaw, entry.entityIDsShape, entry.metadataShape,
                 entry.entityIDsPayloadJSON ?? "", entry.metadataPayloadJSON ?? "",
                 String(entry.attemptCount), String(entry.updatedAt.timeIntervalSince1970)]
            }
    }

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
        XCTAssertTrue(provider.isCheckingRemoteCounts)

        remote.release()
        try await waitForDrift(provider)
        XCTAssertEqual(provider.syncCountDriftReport?.mismatches, [.products])
        XCTAssertFalse(provider.isCheckingRemoteCounts)
    }

    func testShopDiscoveryRefreshMovesFromUnavailableToConcreteMismatchWithoutDefaultFallback() async throws {
        let context = try makeContext()
        context.insert(Product(barcode: "TASK139_DELAYED_SHOP"))
        try context.save()
        let owner = UUID()
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let suiteName = "OptionsSyncSummaryProviderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let selectedStore = SelectedShopStore(
            defaults: defaults,
            keyPrefix: "fixture.shop",
            activeAccountKey: "fixture.active",
            resolutionKeyPrefix: "fixture.resolved"
        )
        XCTAssertTrue(selectedStore.markResolutionReady(accountHash: accountHash))
        let provider = OptionsSyncSummaryProvider(
            now: { Date(timeIntervalSince1970: 2_100) },
            bindingStore: AccountBindingStore(defaults: defaults, key: "fixture.binding"),
            selectedShopStore: selectedStore
        )

        provider.refreshAll(
            context: context,
            authSnapshot: OptionsSyncAuthSnapshot(isSignedIn: true, userID: owner),
            remoteCountFetcher: nil,
            refreshReason: "unresolved-shop"
        )
        try await waitForDecision(provider, reason: .shopContextUnavailable)

        XCTAssertTrue(selectedStore.save(
            SelectedShop(
                shopID: UUID(),
                code: nil,
                name: "Fixture shop",
                role: "owner",
                status: "active",
                selectable: true,
                canWrite: true
            ),
            accountHash: accountHash
        ))
        provider.refreshAll(
            context: context,
            authSnapshot: OptionsSyncAuthSnapshot(isSignedIn: true, userID: owner),
            remoteCountFetcher: nil,
            refreshReason: "shop-context-changed"
        )
        XCTAssertNil(provider.accountSyncDecision)
        XCTAssertTrue(provider.isLoading || provider.isStale)
        try await waitForDecision(provider, reason: .unboundDirty)
        XCTAssertEqual(provider.refreshReason, "shop-context-changed")

        provider.refreshAll(
            context: context,
            authSnapshot: OptionsSyncAuthSnapshot(isSignedIn: false, userID: nil),
            remoteCountFetcher: nil,
            refreshReason: "signed-out"
        )
        XCTAssertNil(provider.accountSyncDecision)
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

    private func waitForDecision(
        _ provider: OptionsSyncSummaryProvider,
        reason: OwnerStoreBindingReviewReason
    ) async throws {
        for _ in 0..<120 {
            if case .promptOwnerStoreReview(let actualReason)? = provider.accountSyncDecision?.action,
               actualReason == reason {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for account decision \(reason).")
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

@MainActor
private final class SlowRemoteCountFetcher: OptionsSyncRemoteCountFetching {
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
