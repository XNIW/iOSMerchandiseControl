import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class SupabaseManualSyncLocalPendingSnapshotProviderTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private let ownerA = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    private let ownerB = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    private let now = Date(timeIntervalSince1970: 1_778_400_000)

    func testZeroPendingReturnsZeroSnapshot() async throws {
        let session = ManualSyncSessionFake(isSignedIn: true, ownerUserID: ownerA)
        let catalog = CatalogPendingCounterFake(countsByOwner: [ownerA: 0])
        let outbox = OutboxPendingCounterFake(countsByOwner: [ownerA: 0])
        let provider = makeProvider(session: session, catalog: catalog, outbox: outbox)

        let snapshot = try await provider.loadLocalPendingSnapshot()

        XCTAssertEqual(snapshot, SupabaseManualSyncPrivacyCounts())
        XCTAssertFalse(snapshot.hasAnyPendingWork)
    }

    func testCatalogPendingProducesAggregatedPendingSnapshot() async throws {
        let session = ManualSyncSessionFake(isSignedIn: true, ownerUserID: ownerA)
        let catalog = CatalogPendingCounterFake(countsByOwner: [ownerA: 3])
        let outbox = OutboxPendingCounterFake(countsByOwner: [ownerA: 0])
        let provider = makeProvider(session: session, catalog: catalog, outbox: outbox)

        let snapshot = try await provider.loadLocalPendingSnapshot()

        XCTAssertEqual(snapshot.pendingCatalogChangeCount, 3)
        XCTAssertEqual(snapshot.pendingPriceChangeCount, 0)
        XCTAssertEqual(snapshot.pendingQueuedCloudOperationCount, 0)
        XCTAssertTrue(snapshot.hasAnyPendingWork)
    }

    func testOutboxPendingProducesAggregatedPendingSnapshot() async throws {
        let session = ManualSyncSessionFake(isSignedIn: true, ownerUserID: ownerA)
        let catalog = CatalogPendingCounterFake(countsByOwner: [ownerA: 0])
        let outbox = OutboxPendingCounterFake(countsByOwner: [ownerA: 2])
        let provider = makeProvider(session: session, catalog: catalog, outbox: outbox)

        let snapshot = try await provider.loadLocalPendingSnapshot()

        XCTAssertEqual(snapshot.pendingCatalogChangeCount, 0)
        XCTAssertEqual(snapshot.pendingPriceChangeCount, 0)
        XCTAssertEqual(snapshot.pendingQueuedCloudOperationCount, 2)
        XCTAssertTrue(snapshot.hasAnyPendingWork)
    }

    func testProductPricePendingProducesAggregatedPendingSnapshot() async throws {
        let session = ManualSyncSessionFake(isSignedIn: true, ownerUserID: ownerA)
        let catalog = CatalogPendingCounterFake(countsByOwner: [ownerA: 0])
        let price = ProductPricePendingCounterFake(countsByOwner: [ownerA: 4])
        let outbox = OutboxPendingCounterFake(countsByOwner: [ownerA: 0])
        let provider = makeProvider(session: session, catalog: catalog, price: price, outbox: outbox)

        let snapshot = try await provider.loadLocalPendingSnapshot()

        XCTAssertEqual(snapshot.pendingCatalogChangeCount, 0)
        XCTAssertEqual(snapshot.pendingPriceChangeCount, 4)
        XCTAssertEqual(snapshot.pendingQueuedCloudOperationCount, 0)
        XCTAssertTrue(snapshot.hasAnyPendingWork)
    }

    func testCombinedLocalPendingCounterIsLoadedOnceAndAvoidsFallbackWhenCatalogExists() async throws {
        let session = ManualSyncSessionFake(isSignedIn: true, ownerUserID: ownerA)
        let local = LocalPendingCounterFake(snapshot: LocalPendingChangeSnapshot(
            pendingCatalogChangeCount: 2,
            pendingProductPriceChangeCount: 3,
            blockedCount: 0,
            staleBaselineCount: 0,
            sentCount: 0,
            supersededRetainedCount: 0,
            isCapped: false
        ))
        let catalog = CatalogPendingCounterFake(countsByOwner: [ownerA: 9])
        let outbox = OutboxPendingCounterFake(countsByOwner: [ownerA: 1])
        let provider = makeProvider(session: session, local: local, catalog: catalog, outbox: outbox)

        let snapshot = try await provider.loadLocalPendingSnapshot()

        XCTAssertEqual(snapshot.pendingCatalogChangeCount, 2)
        XCTAssertEqual(snapshot.pendingPriceChangeCount, 3)
        XCTAssertEqual(snapshot.pendingQueuedCloudOperationCount, 1)
        XCTAssertEqual(local.ownerCalls, [ownerA])
        XCTAssertTrue(catalog.ownerCalls.isEmpty)
    }

    func testHistorySessionLocalPendingIsReportedAsQueuedCloudOperation() async throws {
        let session = ManualSyncSessionFake(isSignedIn: true, ownerUserID: ownerA)
        let local = LocalPendingCounterFake(snapshot: LocalPendingChangeSnapshot(
            pendingHistorySessionChangeCount: 2
        ))
        let catalog = CatalogPendingCounterFake(countsByOwner: [ownerA: 0])
        let outbox = OutboxPendingCounterFake(countsByOwner: [ownerA: 1])
        let provider = makeProvider(session: session, local: local, catalog: catalog, outbox: outbox)

        let snapshot = try await provider.loadLocalPendingSnapshot()

        XCTAssertEqual(snapshot.pendingCatalogChangeCount, 0)
        XCTAssertEqual(snapshot.pendingPriceChangeCount, 0)
        XCTAssertEqual(snapshot.pendingQueuedCloudOperationCount, 3)
    }

    func testDirtyHistoryEntriesAreReportedAsQueuedCloudOperationsWithoutPendingRows() async throws {
        let context = try makeLocalPendingContext()
        let dirty = HistoryEntry(id: "history-dirty")
        let clean = HistoryEntry(
            id: "history-clean",
            remoteID: UUID(),
            remotePayloadFingerprint: "clean-fingerprint",
            localChangeRevision: 1,
            lastSyncedLocalRevision: 1
        )
        context.insert(dirty)
        context.insert(clean)
        try context.save()

        let session = ManualSyncSessionFake(isSignedIn: true, ownerUserID: ownerA)
        let adapter = LocalPendingChangePendingAdapter(context: context)
        let catalog = CatalogPendingCounterFake(countsByOwner: [ownerA: 0])
        let outbox = OutboxPendingCounterFake(countsByOwner: [ownerA: 0])
        let provider = makeProvider(session: session, local: adapter, catalog: catalog, outbox: outbox)

        let localSnapshot = try await adapter.pendingLocalChangeSnapshot(ownerUserID: ownerA)
        let snapshot = try await provider.loadLocalPendingSnapshot()

        XCTAssertEqual(localSnapshot.pendingHistorySessionChangeCount, 1)
        XCTAssertEqual(snapshot.pendingQueuedCloudOperationCount, 1)
        XCTAssertTrue(snapshot.hasAnyPendingWork)
    }

    func testMissingAuthSessionReturnsZeroWithoutCallingCounters() async throws {
        let session = ManualSyncSessionFake(isSignedIn: false, ownerUserID: nil)
        let catalog = CatalogPendingCounterFake(countsByOwner: [ownerA: 9])
        let outbox = OutboxPendingCounterFake(countsByOwner: [ownerA: 9])
        let provider = makeProvider(session: session, catalog: catalog, outbox: outbox)

        let snapshot = try await provider.loadLocalPendingSnapshot()

        XCTAssertEqual(snapshot, SupabaseManualSyncPrivacyCounts())
        XCTAssertTrue(catalog.ownerCalls.isEmpty)
        XCTAssertTrue(outbox.ownerCalls.isEmpty)
    }

    func testProviderIsOwnerSessionScopedAndDoesNotReuseStaleCounts() async throws {
        let session = ManualSyncSessionFake(isSignedIn: true, ownerUserID: ownerA)
        let catalog = CatalogPendingCounterFake(countsByOwner: [
            ownerA: 1,
            ownerB: 5
        ])
        let outbox = OutboxPendingCounterFake(countsByOwner: [
            ownerA: 2,
            ownerB: 0
        ])
        let provider = makeProvider(session: session, catalog: catalog, outbox: outbox)

        let first = try await provider.loadLocalPendingSnapshot()
        session.ownerUserID = ownerB
        let second = try await provider.loadLocalPendingSnapshot()

        XCTAssertEqual(first.pendingCatalogChangeCount, 1)
        XCTAssertEqual(first.pendingQueuedCloudOperationCount, 2)
        XCTAssertEqual(second.pendingCatalogChangeCount, 5)
        XCTAssertEqual(second.pendingQueuedCloudOperationCount, 0)
        XCTAssertEqual(catalog.ownerCalls, [ownerA, ownerB])
        XCTAssertEqual(outbox.ownerCalls, [ownerA, ownerB])
    }

    func testProviderPropagatesCancellationAndDoesNotReportSuccess() async {
        let session = ManualSyncSessionFake(isSignedIn: true, ownerUserID: ownerA)
        let catalog = CatalogPendingCounterFake(countsByOwner: [:])
        catalog.error = CancellationError()
        let outbox = OutboxPendingCounterFake(countsByOwner: [ownerA: 4])
        let provider = makeProvider(session: session, catalog: catalog, outbox: outbox)

        do {
            _ = try await provider.loadLocalPendingSnapshot()
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(catalog.ownerCalls, [ownerA])
            XCTAssertTrue(outbox.ownerCalls.isEmpty)
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func testCatalogAdapterCountsPreflightWriteCandidatesOnlyAsAggregates() async throws {
        let remoteID = UUID()
        let changedProduct = productState(remoteID: remoteID, productName: "Local")
        let remoteFingerprint = ManualPushFingerprintNormalizer.product(
            barcode: "100",
            itemNumber: nil,
            productName: "Remote",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            stockQuantity: nil,
            supplierRemoteID: nil,
            categoryRemoteID: nil
        )
        let adapter = makeCatalogAdapter(
            baseline: baseline(productFingerprintsByRemoteID: [remoteID: remoteFingerprint]),
            snapshot: SupabaseManualSyncCatalogSnapshot(
                suppliers: [],
                categories: [],
                products: [changedProduct],
                exceededLimit: false
            )
        )

        let count = try await adapter.pendingCatalogChangeCount(ownerUserID: ownerA)

        XCTAssertEqual(count, 1)
    }

    func testCatalogAdapterZeroPendingWhenPreflightIsNoOp() async throws {
        let remoteID = UUID()
        let unchangedProduct = productState(remoteID: remoteID, productName: "Same")
        let adapter = makeCatalogAdapter(
            baseline: baseline(productFingerprintsByRemoteID: [remoteID: unchangedProduct.catalogFingerprint]),
            snapshot: SupabaseManualSyncCatalogSnapshot(
                suppliers: [],
                categories: [],
                products: [unchangedProduct],
                exceededLimit: false
            )
        )

        let count = try await adapter.pendingCatalogChangeCount(ownerUserID: ownerA)

        XCTAssertEqual(count, 0)
    }

    func testCatalogAdapterMissingBaselineReturnsZeroForSafeBlockedPath() async throws {
        let baselineReader = BaselineReaderFake(result: .missing)
        let loader = CatalogSnapshotLoaderFake(snapshot: SupabaseManualSyncCatalogSnapshot(
            suppliers: [],
            categories: [],
            products: [productState(remoteID: nil, productName: "Local")],
            exceededLimit: false
        ))
        let adapter = SupabaseManualSyncCatalogPendingAdapter(
            baselineReader: baselineReader,
            snapshotLoader: loader
        )

        let count = try await adapter.pendingCatalogChangeCount(ownerUserID: ownerA)

        XCTAssertEqual(count, 0)
        XCTAssertTrue(loader.requestedLimits.isEmpty)
    }

    func testCatalogAdapterLimitExceededReturnsConservativePendingFlag() async throws {
        let adapter = makeCatalogAdapter(
            baseline: baseline(productFingerprintsByRemoteID: [:]),
            snapshot: SupabaseManualSyncCatalogSnapshot(
                suppliers: [],
                categories: [],
                products: [],
                exceededLimit: true
            ),
            maxRowsPerEntity: 25
        )

        let count = try await adapter.pendingCatalogChangeCount(ownerUserID: ownerA)

        XCTAssertEqual(count, 1)
    }

    func testOutboxAdapterCountsOwnerScopedPendingFailedAndBlockedRows() async throws {
        let context = try makeOutboxContext()
        let store = SyncEventOutboxLocalStore(context: context)
        let pending = try makeOutboxEntry(id: "pending", ownerUserID: ownerA.uuidString.lowercased())
        let failedFuture = try makeOutboxEntry(id: "failed-future", ownerUserID: ownerA.uuidString.lowercased())
        failedFuture.status = .failedRetryable
        failedFuture.nextRetryAt = now.addingTimeInterval(60)
        let blocked = try makeOutboxEntry(id: "blocked", ownerUserID: ownerA.uuidString.lowercased())
        blocked.status = .blockedSchema
        let otherOwner = try makeOutboxEntry(id: "other", ownerUserID: ownerB.uuidString.lowercased())
        [pending, failedFuture, blocked, otherOwner].forEach(store.add)
        try context.save()

        let adapter = SupabaseManualSyncOutboxPendingAdapter(
            context: context,
            now: { self.now }
        )

        let count = try await adapter.pendingQueuedCloudOperationCount(ownerUserID: ownerA)

        XCTAssertEqual(count, 3)
    }

    private func makeProvider(
        session: ManualSyncSessionFake,
        local: (any SupabaseManualSyncLocalPendingChangeCounting)? = nil,
        catalog: CatalogPendingCounterFake,
        price: ProductPricePendingCounterFake? = nil,
        outbox: OutboxPendingCounterFake
    ) -> SupabaseManualSyncLocalPendingSnapshotProvider {
        SupabaseManualSyncLocalPendingSnapshotProvider(
            sessionProvider: session,
            localPendingChangeCounter: local,
            catalogPendingCounter: catalog,
            productPricePendingCounter: price,
            outboxPendingCounter: outbox
        )
    }

    private func makeCatalogAdapter(
        baseline: ManualPushBaseline,
        snapshot: SupabaseManualSyncCatalogSnapshot,
        maxRowsPerEntity: Int = SupabaseManualSyncCatalogPendingAdapter.defaultMaxRowsPerEntity
    ) -> SupabaseManualSyncCatalogPendingAdapter {
        SupabaseManualSyncCatalogPendingAdapter(
            baselineReader: BaselineReaderFake(result: .available(SupabaseCatalogManualPushBaseline(
                runID: UUID(),
                ownerUserUUID: ownerA,
                appliedAt: nil,
                baseline: baseline
            ))),
            snapshotLoader: CatalogSnapshotLoaderFake(snapshot: snapshot),
            maxRowsPerEntity: maxRowsPerEntity
        )
    }

    private func baseline(
        productFingerprintsByRemoteID: [UUID: ManualPushFingerprint]
    ) -> ManualPushBaseline {
        ManualPushBaseline(productFingerprintsByRemoteID: productFingerprintsByRemoteID)
    }

    private func productState(
        remoteID: UUID?,
        productName: String
    ) -> ManualPushProductState {
        ManualPushProductState(
            localID: "100",
            remoteID: remoteID,
            remoteUpdatedAt: Date(timeIntervalSince1970: 1_778_300_000),
            barcode: "100",
            productName: productName
        )
    }

    private func makeOutboxContext() throws -> ModelContext {
        let schema = Schema([SyncEventOutboxEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return ModelContext(container)
    }

    private func makeLocalPendingContext() throws -> ModelContext {
        let schema = Schema([LocalPendingChange.self, HistoryEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return ModelContext(container)
    }

    private func makeOutboxEntry(id: String, ownerUserID: String) throws -> SyncEventOutboxEntry {
        try SyncEventOutboxFactory.makeEntry(
            ownerUserID: ownerUserID,
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 1,
            entityIDsShape: "product_ids:count=1",
            metadataShape: "source:manual_push",
            now: now,
            id: id,
            clientEventID: "client-\(id)"
        )
    }
}

@MainActor
private final class LocalPendingCounterFake: SupabaseManualSyncLocalPendingChangeCounting {
    let snapshot: LocalPendingChangeSnapshot
    private(set) var ownerCalls: [UUID] = []

    init(snapshot: LocalPendingChangeSnapshot) {
        self.snapshot = snapshot
    }

    func pendingLocalChangeSnapshot(ownerUserID: UUID) async throws -> LocalPendingChangeSnapshot {
        ownerCalls.append(ownerUserID)
        return snapshot
    }
}

@MainActor
private final class ManualSyncSessionFake: SupabaseManualSyncLocalPendingSessionProviding {
    var manualSyncIsSignedIn: Bool
    var manualSyncOwnerUserID: UUID?

    init(isSignedIn: Bool, ownerUserID: UUID?) {
        self.manualSyncIsSignedIn = isSignedIn
        self.manualSyncOwnerUserID = ownerUserID
    }

    var ownerUserID: UUID? {
        get { manualSyncOwnerUserID }
        set { manualSyncOwnerUserID = newValue }
    }
}

@MainActor
private final class CatalogPendingCounterFake: SupabaseManualSyncCatalogPendingCounting {
    var countsByOwner: [UUID: Int]
    var error: Error?
    private(set) var ownerCalls: [UUID] = []

    init(countsByOwner: [UUID: Int]) {
        self.countsByOwner = countsByOwner
    }

    func pendingCatalogChangeCount(ownerUserID: UUID) async throws -> Int {
        ownerCalls.append(ownerUserID)
        if let error {
            throw error
        }
        return countsByOwner[ownerUserID] ?? 0
    }
}

@MainActor
private final class OutboxPendingCounterFake: SupabaseManualSyncOutboxPendingCounting {
    var countsByOwner: [UUID: Int]
    private(set) var ownerCalls: [UUID] = []

    init(countsByOwner: [UUID: Int]) {
        self.countsByOwner = countsByOwner
    }

    func pendingQueuedCloudOperationCount(ownerUserID: UUID) async throws -> Int {
        ownerCalls.append(ownerUserID)
        return countsByOwner[ownerUserID] ?? 0
    }
}

@MainActor
private final class ProductPricePendingCounterFake: SupabaseManualSyncProductPricePendingCounting {
    var countsByOwner: [UUID: Int]
    private(set) var ownerCalls: [UUID] = []

    init(countsByOwner: [UUID: Int]) {
        self.countsByOwner = countsByOwner
    }

    func pendingProductPriceChangeCount(ownerUserID: UUID) async throws -> Int {
        ownerCalls.append(ownerUserID)
        return countsByOwner[ownerUserID] ?? 0
    }
}

@MainActor
private final class BaselineReaderFake: SupabaseManualSyncBaselineReading {
    let result: SupabaseCatalogBaselineReadResult
    private(set) var ownerCalls: [UUID] = []

    init(result: SupabaseCatalogBaselineReadResult) {
        self.result = result
    }

    func readManualPushBaseline(ownerUserID: UUID) throws -> SupabaseCatalogBaselineReadResult {
        ownerCalls.append(ownerUserID)
        return result
    }
}

@MainActor
private final class CatalogSnapshotLoaderFake: SupabaseManualSyncCatalogSnapshotLoading {
    let snapshot: SupabaseManualSyncCatalogSnapshot
    private(set) var requestedLimits: [Int] = []

    init(snapshot: SupabaseManualSyncCatalogSnapshot) {
        self.snapshot = snapshot
    }

    func loadCatalogSnapshot(maxRowsPerEntity: Int) throws -> SupabaseManualSyncCatalogSnapshot {
        requestedLimits.append(maxRowsPerEntity)
        return snapshot
    }
}
