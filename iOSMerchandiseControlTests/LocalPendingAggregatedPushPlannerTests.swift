import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class LocalPendingAggregatedPushPlannerTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private let ownerID = UUID(uuidString: "09400000-0000-4094-8094-000000000094")!
    private let now = Date(timeIntervalSince1970: 1_778_600_000)

    func testCandidateFilteringUsesOnlyPendingAndIgnoresTerminalRows() async throws {
        let context = try makeContext()
        try commitBaseline(context)
        let product = Product(barcode: "TASK094_FILTER", productName: "Filter")
        context.insert(product)
        try LocalPendingChangeAccumulator(context: context, ownerUserID: ownerID, now: { self.now })
            .recordProductChange(
                product: product,
                operation: .create,
                origin: .manualCatalogSave,
                changedFields: ["barcode", "productName"]
            )
        context.insert(change(
            entityKind: .supplier,
            operation: .create,
            status: .superseded,
            logicalKey: "supplier:terminal:superseded",
            updatedAt: now.addingTimeInterval(1)
        ))
        context.insert(change(
            entityKind: .product,
            operation: .update,
            status: .acknowledged,
            logicalKey: "product:terminal:acknowledged",
            updatedAt: now.addingTimeInterval(2)
        ))
        try context.save()

        let plan = try await LocalPendingAggregatedPushPlanner(
            context: context,
            now: { self.now },
            includesProductPrice: false
        ).makePlan(ownerUserID: ownerID)

        XCTAssertTrue(plan.blockers.isEmpty)
        XCTAssertEqual(plan.counts.pendingCatalogCandidates, 1)
        XCTAssertEqual(plan.counts.selectedCatalogChanges, 1)
        XCTAssertEqual(plan.counts.supersededIgnoredCount, 1)
        XCTAssertEqual(plan.counts.acknowledgedIgnoredCount, 1)
        XCTAssertEqual(plan.catalogBatch?.plan.writeCandidates.count, 1)
        XCTAssertTrue(plan.warnings.contains(.terminalChangesIgnored))
    }

    func testBlockedStaleCappedAndSentRowsBlockBeforeNetwork() async throws {
        let context = try makeContext()
        context.insert(change(entityKind: .product, operation: .update, status: .blocked, logicalKey: "blocked"))
        context.insert(change(entityKind: .supplier, operation: .update, status: .staleBaseline, logicalKey: "stale"))
        context.insert(change(
            entityKind: .importBatch,
            operation: .upsert,
            status: .blocked,
            logicalKey: "import:cap:task094"
        ))
        context.insert(change(
            entityKind: .product,
            operation: .update,
            status: .sent,
            logicalKey: "sent:cooldown",
            lastAttemptAt: now.addingTimeInterval(-60)
        ))
        try context.save()

        let plan = try await LocalPendingAggregatedPushPlanner(
            context: context,
            now: { self.now },
            sentRetryCooldown: 1_800
        ).makePlan(ownerUserID: ownerID)

        XCTAssertTrue(plan.blockers.contains(.blockedLocalChanges))
        XCTAssertTrue(plan.blockers.contains(.staleBaselineLocalChanges))
        XCTAssertTrue(plan.blockers.contains(.cappedPendingStore))
        XCTAssertTrue(plan.blockers.contains(.sentChangesWaitingForRetry))
        XCTAssertEqual(plan.capState, .cappedStore)
        XCTAssertEqual(plan.retryInfo.cooldownCount, 1)
        XCTAssertTrue(plan.warnings.contains(.sentChangesOnCooldown))
    }

    func testSentRetryEligibleHasExplicitRetryBlocker() async throws {
        let context = try makeContext()
        context.insert(change(
            entityKind: .product,
            operation: .update,
            status: .sent,
            logicalKey: "sent:eligible",
            lastAttemptAt: now.addingTimeInterval(-3_600)
        ))
        try context.save()

        let plan = try await LocalPendingAggregatedPushPlanner(
            context: context,
            now: { self.now },
            sentRetryCooldown: 1_800
        ).makePlan(ownerUserID: ownerID)

        XCTAssertTrue(plan.blockers.contains(.sentChangesWaitingForRetry))
        XCTAssertEqual(plan.retryInfo.retryEligibleCount, 1)
        XCTAssertTrue(plan.warnings.contains(.retryableSentChangesAvailable))
    }

    func testSoftLimitSelectsBoundedBatchAndHardCapBlocks() async throws {
        let softContext = try makeContext()
        try commitBaseline(softContext)
        for index in 0..<2 {
            let product = Product(barcode: "TASK094_SOFT_\(index)")
            softContext.insert(product)
            try LocalPendingChangeAccumulator(context: softContext, ownerUserID: ownerID, now: { self.now.addingTimeInterval(Double(index)) })
                .recordProductChange(
                    product: product,
                    operation: .create,
                    origin: .manualCatalogSave,
                    changedFields: ["barcode"]
                )
        }
        try softContext.save()

        let softPlan = try await LocalPendingAggregatedPushPlanner(
            context: softContext,
            now: { self.now },
            softBatchLimit: 1,
            hardCap: 10,
            includesProductPrice: false
        ).makePlan(ownerUserID: ownerID)

        XCTAssertEqual(softPlan.capState, .softLimited(selected: 1, available: 2))
        XCTAssertEqual(softPlan.counts.selectedCatalogChanges, 1)
        XCTAssertTrue(softPlan.warnings.contains(.softBatchLimitApplied))

        let hardContext = try makeContext()
        contextInsertTwoPendingProducts(hardContext)
        let hardPlan = try await LocalPendingAggregatedPushPlanner(
            context: hardContext,
            now: { self.now },
            hardCap: 1
        ).makePlan(ownerUserID: ownerID)

        XCTAssertTrue(hardPlan.blockers.contains(.hardCapExceeded))
        XCTAssertEqual(hardPlan.capState, .hardBlocked(available: 2, limit: 1))
    }

    func testProductPriceDedupeUsesSingleRemoteFetchAndDeterministicFingerprint() async throws {
        let context = try makeContext()
        let productID = UUID(uuidString: "09400000-0000-4094-8094-000000000201")!
        let product = Product(barcode: "TASK094_PRICE", remoteID: productID, productName: "Price")
        context.insert(product)
        try commitBaseline(context)
        let effectiveAt = Date(timeIntervalSince1970: 1_778_500_100)
        let first = ProductPrice(type: .purchase, price: 10, effectiveAt: effectiveAt, createdAt: now, product: product)
        let second = ProductPrice(type: .purchase, price: 10, effectiveAt: effectiveAt, createdAt: now.addingTimeInterval(60), product: product)
        context.insert(first)
        context.insert(second)
        let logicalKey = LocalPendingChangeLogicalKey.productPrice(
            productRemoteID: productID,
            productBarcode: product.barcode,
            type: .purchase,
            effectiveAt: effectiveAt
        )
        context.insert(change(entityKind: .productPrice, operation: .upsert, logicalKey: logicalKey))
        context.insert(change(
            entityKind: .productPrice,
            operation: .upsert,
            logicalKey: logicalKey,
            updatedAt: now.addingTimeInterval(1)
        ))
        try context.save()
        let fetcher = MockAggregatedPriceRemoteFetcher(rows: [])

        let planner = LocalPendingAggregatedPushPlanner(
            context: context,
            priceRemoteFetcher: fetcher,
            now: { self.now },
            includesCatalog: false,
            includesProductPrice: true
        )
        let firstPlan = try await planner.makePlan(ownerUserID: ownerID)
        let secondPlan = try await planner.makePlan(ownerUserID: ownerID)

        XCTAssertTrue(firstPlan.blockers.isEmpty)
        XCTAssertEqual(firstPlan.counts.selectedProductPriceChanges, 2)
        XCTAssertEqual(firstPlan.productPriceBatch?.plan.summary.localDuplicateSameKey, 2)
        XCTAssertEqual(firstPlan.productPriceBatch?.plan.summary.readyCandidates, 1)
        XCTAssertEqual(firstPlan.fingerprint, secondPlan.fingerprint)
        let calls = await fetcher.snapshotCalls()
        XCTAssertEqual(calls.count, 2)
        XCTAssertEqual(calls.first?.productIDs, [productID])
    }

    func testFingerprintChangesWhenCurrentLiveModelChanges() async throws {
        let context = try makeContext()
        try commitBaseline(context)
        let product = Product(barcode: "TASK094_FINGERPRINT", productName: "Old")
        context.insert(product)
        try LocalPendingChangeAccumulator(context: context, ownerUserID: ownerID, now: { self.now })
            .recordProductChange(
                product: product,
                operation: .create,
                origin: .manualCatalogSave,
                changedFields: ["barcode", "productName"]
            )
        try context.save()
        let planner = LocalPendingAggregatedPushPlanner(
            context: context,
            now: { self.now },
            includesProductPrice: false
        )

        let before = try await planner.makePlan(ownerUserID: ownerID)
        product.productName = "New"
        try context.save()
        let after = try await planner.makePlan(ownerUserID: ownerID)

        XCTAssertNotEqual(before.fingerprint, after.fingerprint)
    }

    func testStateTransitionsAreBatchScoped() throws {
        let context = try makeContext()
        let sent = change(entityKind: .product, operation: .create, logicalKey: "state:sent")
        let retry = change(entityKind: .product, operation: .create, logicalKey: "state:retry", updatedAt: now.addingTimeInterval(1))
        let blocked = change(entityKind: .product, operation: .create, logicalKey: "state:blocked", updatedAt: now.addingTimeInterval(2))
        let stale = change(entityKind: .product, operation: .create, logicalKey: "state:stale", updatedAt: now.addingTimeInterval(3))
        [sent, retry, blocked, stale].forEach(context.insert)
        try context.save()

        let store = LocalPendingAggregatedPushStateStore(context: context, now: { self.now })
        try store.markSent(changeIDs: [sent.changeID, retry.changeID, blocked.changeID], ownerUserID: ownerID, planFingerprint: "task-094")
        try store.markAcknowledged(changeIDs: [sent.changeID], ownerUserID: ownerID)
        try store.markRetryable(changeIDs: [retry.changeID], ownerUserID: ownerID)
        try store.markBlocked(changeIDs: [blocked.changeID], ownerUserID: ownerID)
        try store.markStale(changeIDs: [stale.changeID], ownerUserID: ownerID)

        let statuses = Dictionary(uniqueKeysWithValues: try fetchChanges(context).map { ($0.logicalKey, $0.status) })
        XCTAssertEqual(statuses["state:sent"], .acknowledged)
        XCTAssertEqual(statuses["state:retry"], .pending)
        XCTAssertEqual(statuses["state:blocked"], .blocked)
        XCTAssertEqual(statuses["state:stale"], .staleBaseline)
    }

    func testMissingOwnerFailsClosed() async throws {
        let plan = try await LocalPendingAggregatedPushPlanner(context: try makeContext())
            .makePlan(ownerUserID: nil)

        XCTAssertEqual(plan.blockers, [.missingOwner])
        XCTAssertFalse(plan.isSendable)
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

    private func commitBaseline(_ context: ModelContext) throws {
        _ = try SupabaseCatalogBaselineWriter(now: { self.now }).commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
    }

    private func contextInsertTwoPendingProducts(_ context: ModelContext) {
        for index in 0..<2 {
            context.insert(change(
                entityKind: .product,
                operation: .create,
                logicalKey: "hard:\(index)",
                updatedAt: now.addingTimeInterval(Double(index))
            ))
        }
        try? context.save()
    }

    private func change(
        entityKind: LocalPendingChangeEntityKind,
        operation: LocalPendingChangeOperation,
        status: LocalPendingChangeStatus = .pending,
        logicalKey: String,
        updatedAt: Date? = nil,
        lastAttemptAt: Date? = nil
    ) -> LocalPendingChange {
        LocalPendingChange(
            ownerUserID: ownerID,
            entityKind: entityKind,
            operation: operation,
            status: status,
            origin: entityKind == .productPrice ? .productPriceSave : .manualCatalogSave,
            logicalKey: logicalKey,
            changedFields: ["task094"],
            createdAt: updatedAt ?? now,
            updatedAt: updatedAt ?? now,
            lastAttemptAt: lastAttemptAt
        )
    }

    private func fetchChanges(_ context: ModelContext) throws -> [LocalPendingChange] {
        try context.fetch(FetchDescriptor<LocalPendingChange>(
            sortBy: [SortDescriptor(\.updatedAt, order: .forward)]
        ))
    }
}

private actor MockAggregatedPriceRemoteFetcher: SupabaseProductPricePushDryRunRemoteFetching {
    struct Call: Sendable, Equatable {
        let ownerUserID: UUID
        let productIDs: [UUID]
        let from: Int
        let to: Int
    }

    private let rows: [RemoteInventoryProductPriceRow]
    private(set) var calls: [Call] = []

    init(rows: [RemoteInventoryProductPriceRow]) {
        self.rows = rows
    }

    func snapshotCalls() -> [Call] {
        calls
    }

    func fetchProductPricesForPushDryRunDedupePage(
        ownerUserID: UUID,
        productIDs: [UUID],
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow] {
        calls.append(Call(ownerUserID: ownerUserID, productIDs: productIDs, from: from, to: to))
        let allowed = Set(productIDs)
        let matching = rows.filter { $0.ownerUserID == ownerUserID && allowed.contains($0.productID) }
        guard from < matching.count else {
            return []
        }
        return Array(matching[from...min(to, matching.count - 1)])
    }
}
