import SwiftData
import XCTest
@testable import iOSMerchandiseControl

final class SyncEventIncrementalDomainApplyServiceTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private static let automaticShopID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!

    private enum LatePendingFixture: String, Sendable {
        case catalog
        case price
        case history
    }

    private enum AtomicProbeError: Error, Equatable, Sendable {
        case injectedBeforeCommit
        case missingFixture
        case timedOut
    }

    func testV6EventCursorRejectsRowsAndContinuationOutsideAsOfFence() throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333341")!
        let outOfFence = try syncEventRow(
            id: 101,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 0,
            entityIDsJSON: "{}"
        )
        XCTAssertThrowsError(try ShopSyncEventPageCursorContract.validate(
            rows: [outOfFence],
            afterID: 99,
            asOfEventMaxID: 100,
            nextAfterID: nil,
            hasMore: false
        )) { error in
            XCTAssertEqual(
                error as? ShopSyncRecoveryContractError,
                .invalidPage(domain: .products)
            )
        }

        let inFence = try syncEventRow(
            id: 100,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 0,
            entityIDsJSON: "{}"
        )
        XCTAssertThrowsError(try ShopSyncEventPageCursorContract.validate(
            rows: [inFence],
            afterID: 99,
            asOfEventMaxID: 100,
            nextAfterID: 101,
            hasMore: true
        )) { error in
            XCTAssertEqual(
                error as? ShopSyncRecoveryContractError,
                .invalidPage(domain: .products)
            )
        }
    }

    @MainActor
    func testV6FenceAdvancesWithWatermarkAcrossServiceRelaunch() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333342")!
        let suiteName = "SyncEventV6FenceAdvance-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let first = try syncEventRow(
            id: 101,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 0,
            entityIDsJSON: "{}"
        )
        let second = try syncEventRow(
            id: 102,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 0,
            entityIDsJSON: "{}"
        )
        let remote = V6FenceIncrementalRemoteFake(events: [first])
        let firstService = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        )
        let container = try makeContainer()

        let firstSummary = try await firstService.applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )
        XCTAssertNil(firstSummary.requiresFullRecoveryReason)
        XCTAssertEqual(firstSummary.watermarkAfter, 101)
        remote.replaceEvents([first, second])

        // A new service instance models a relaunch: the durable watermark is
        // reused, while the remote fence writer must advance from that exact
        // value rather than leave the next V6 read scope-fence-missing.
        let relaunchedService = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        )
        let secondSummary = try await relaunchedService.applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )
        XCTAssertNil(secondSummary.requiresFullRecoveryReason)
        XCTAssertEqual(secondSummary.watermarkBefore, 101)
        XCTAssertEqual(secondSummary.watermarkAfter, 102)
        XCTAssertEqual(remote.fenceAdvances(), [
            .init(from: 0, through: 101),
            .init(from: 101, through: 102)
        ])
        XCTAssertEqual(
            WatermarkStore(defaults: defaults).watermark(
                for: WatermarkStore.Scope(
                    ownerUserID: owner,
                    storeIdentity: LocalStoreIdentity(
                        rawValue: Self.automaticShopID.uuidString.lowercased()
                    )
                )
            ),
            102
        )
    }

    @MainActor
    func testV6FencePersistenceFailureKeepsWatermarkFailClosed() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333343")!
        let suiteName = "SyncEventV6FenceFailure-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let event = try syncEventRow(
            id: 103,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 0,
            entityIDsJSON: "{}"
        )
        let remote = V6FenceIncrementalRemoteFake(
            events: [event],
            failsFencePersistence: true
        )
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

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_scope_fence_missing")
        XCTAssertEqual(summary.watermarkBefore, 0)
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertTrue(remote.fenceAdvances().isEmpty)
        XCTAssertEqual(
            WatermarkStore(defaults: defaults).watermark(
                for: WatermarkStore.Scope(
                    ownerUserID: owner,
                    storeIdentity: LocalStoreIdentity(
                        rawValue: Self.automaticShopID.uuidString.lowercased()
                    )
                )
            ),
            0
        )
    }

    @MainActor
    func testUnrecoverableGapDoesNotAdvanceWatermarkPastUnappliedEvent() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)

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
                for: WatermarkStore.Scope(
                    ownerUserID: owner,
                    storeIdentity: LocalStoreIdentity(rawValue: Self.automaticShopID.uuidString.lowercased())
                )
            ),
            0
        )
        let applyStatus = try XCTUnwrap(SyncEventApplyStatusStore(defaults: defaults).record(ownerUserID: owner, shopID: Self.automaticShopID, eventID: 101))
        XCTAssertEqual(applyStatus.status, .blocked)
        XCTAssertEqual(applyStatus.reason, .missingEntityIDs)
        XCTAssertEqual(applyStatus.attemptCount, 1)
        XCTAssertNotNil(applyStatus.nextRetryAtMs)
    }

    @MainActor
    func testFirstBlockedEventPreventsLaterSameDependentAndIndependentDomainApply() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333347")!
        let suiteName = "SyncEventFirstBlockerOrdering-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)

        let events = [
            try syncEventRow(
                id: 301,
                ownerUserID: owner,
                domain: "catalog",
                changedCount: 1,
                entityIDsJSON: "null"
            ),
            try syncEventRow(
                id: 302,
                ownerUserID: owner,
                domain: "catalog",
                changedCount: 1,
                entityIDsJSON: #"{"product_ids":["77777777-7777-4777-8777-777777777772"]}"#
            ),
            try syncEventRow(
                id: 303,
                ownerUserID: owner,
                domain: "prices",
                changedCount: 1,
                entityIDsJSON: #"{"price_ids":["66666666-6666-4666-8666-666666666663"],"product_ids":["77777777-7777-4777-8777-777777777772"]}"#
            ),
            try syncEventRow(
                id: 304,
                ownerUserID: owner,
                domain: "history",
                changedCount: 1,
                entityIDsJSON: #"{"session_ids":["55555555-5555-4555-8555-555555555553"]}"#
            )
        ]
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: events)
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
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(summary.totalApplied, 0)
        XCTAssertEqual(remote.catalogFetchCallCount, 0)
        XCTAssertEqual(remote.productPriceFetchCallCount, 0)
        XCTAssertEqual(remote.historyFetchCallCount, 0)
        let statusStore = SyncEventApplyStatusStore(defaults: defaults)
        XCTAssertEqual(
            statusStore.record(
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                eventID: 301
            )?.status,
            .blocked
        )
        XCTAssertNil(statusStore.record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 302
        ))
        XCTAssertNil(statusStore.record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 303
        ))
        XCTAssertNil(statusStore.record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 304
        ))
    }

    @MainActor
    func testCatalogIncrementalEventRenamesExistingSupplier() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333334")!
        let supplierID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)

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
                    shopID: Self.automaticShopID,
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
        let applyStatus = try XCTUnwrap(SyncEventApplyStatusStore(defaults: defaults).record(ownerUserID: owner, shopID: Self.automaticShopID, eventID: 102))
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
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)

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
        let applyStatus = try XCTUnwrap(SyncEventApplyStatusStore(defaults: defaults).record(ownerUserID: owner, shopID: Self.automaticShopID, eventID: 104))
        XCTAssertEqual(applyStatus.status, .blocked)
        XCTAssertEqual(applyStatus.reason, .dirtyLocal)
        XCTAssertEqual(applyStatus.entityIDs.productIDs, [productID])
        XCTAssertNotNil(applyStatus.nextRetryAtMs)
    }

    @MainActor
    func testCatalogPendingCreatedAfterFetchBlocksAtomicMutation() async throws {
        try await assertPendingCreatedAfterFetchBlocksAtomicMutation(.catalog)
    }

    @MainActor
    func testPricePendingCreatedAfterFetchBlocksParentAndPriceAtomicMutation() async throws {
        try await assertPendingCreatedAfterFetchBlocksAtomicMutation(.price)
    }

    @MainActor
    func testHistoryPendingCreatedAfterFetchBlocksAtomicMutation() async throws {
        try await assertPendingCreatedAfterFetchBlocksAtomicMutation(.history)
    }

    @MainActor
    func testCatalogLogicalPendingCreatedAfterFetchBlocksIdentityAdoption() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333351")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777781")!
        let suiteName = "SyncEventLateLogicalProduct-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let event = try syncEventRow(
            id: 171,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 1,
            entityIDsJSON: #"{"product_ids":["77777777-7777-4777-8777-777777777781"]}"#
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            products: [
                RemoteInventoryProductRow(
                    id: productID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    barcode: "LOGICAL-PENDING",
                    itemNumber: nil,
                    productName: "Remote must not win",
                    secondProductName: nil,
                    purchasePrice: nil,
                    retailPrice: nil,
                    supplierID: nil,
                    categoryID: nil,
                    stockQuantity: nil,
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: nil
                )
            ]
        )
        let identity = LocalStoreIdentity(
            rawValue: Self.automaticShopID.uuidString.lowercased()
        )
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults,
            beforeAtomicMutationForTesting: {
                try await MainActor.run {
                    let context = ModelContext(container)
                    let product = Product(
                        barcode: "LOGICAL-PENDING",
                        productName: "Local pending wins"
                    )
                    context.insert(product)
                    let accumulator = LocalPendingChangeAccumulator(
                        context: context,
                        ownerUserID: owner,
                        storeIdentity: identity
                    )
                    _ = try accumulator.recordProductChange(
                        product: product,
                        operation: .create,
                        origin: .manualCatalogSave,
                        changedFields: ["barcode", "productName"]
                    )
                    try context.save()
                }
            }
        )

        let summary = try await service.applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_dirty_local")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(summary.totalApplied, 0)
        XCTAssertGreaterThan(remote.catalogFetchCallCount, 0)
        let context = ModelContext(container)
        let products = try context.fetch(FetchDescriptor<Product>())
        XCTAssertEqual(products.count, 1)
        XCTAssertNil(products.first?.remoteID)
        XCTAssertEqual(products.first?.productName, "Local pending wins")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LocalPendingChange>()), 1)
        let status = try XCTUnwrap(
            SyncEventApplyStatusStore(defaults: defaults).record(
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                eventID: 171
            )
        )
        XCTAssertEqual(status.status, .blocked)
        XCTAssertEqual(status.reason, .dirtyLocal)
    }

    @MainActor
    func testPriceLogicalPendingCreatedAfterFetchBlocksIdentityLink() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333352")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777782")!
        let priceID = UUID(uuidString: "66666666-6666-4666-8666-666666666672")!
        let effectiveAt = try date("2026-07-21T12:00:00Z")
        let suiteName = "SyncEventLateLogicalPrice-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let event = try syncEventRow(
            id: 172,
            ownerUserID: owner,
            domain: "prices",
            changedCount: 1,
            entityIDsJSON: #"{"price_ids":["66666666-6666-4666-8666-666666666672"],"product_ids":["77777777-7777-4777-8777-777777777782"]}"#
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            products: [
                RemoteInventoryProductRow(
                    id: productID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    barcode: "LOGICAL-PRICE-PARENT",
                    itemNumber: nil,
                    productName: "Remote parent",
                    secondProductName: nil,
                    purchasePrice: nil,
                    retailPrice: nil,
                    supplierID: nil,
                    categoryID: nil,
                    stockQuantity: nil,
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: nil
                )
            ],
            productPrices: [
                RemoteInventoryProductPriceRow(
                    id: priceID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    productID: productID,
                    type: "RETAIL",
                    price: 9.25,
                    effectiveAt: "2026-07-21T12:00:00Z",
                    source: "REMOTE",
                    note: nil,
                    createdAt: "2026-07-21T12:00:00Z",
                    updatedAt: "2026-07-21T12:00:00Z"
                )
            ]
        )
        let identity = LocalStoreIdentity(
            rawValue: Self.automaticShopID.uuidString.lowercased()
        )
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults,
            beforeAtomicMutationForTesting: {
                try await MainActor.run {
                    let context = ModelContext(container)
                    let product = Product(
                        barcode: "LOGICAL-PRICE-PARENT",
                        remoteID: productID,
                        productName: "Local parent"
                    )
                    let price = ProductPrice(
                        type: .retail,
                        price: 1.25,
                        effectiveAt: effectiveAt,
                        source: "LOCAL",
                        product: product
                    )
                    context.insert(product)
                    context.insert(price)
                    let accumulator = LocalPendingChangeAccumulator(
                        context: context,
                        ownerUserID: owner,
                        storeIdentity: identity
                    )
                    _ = try accumulator.recordProductPriceChange(
                        price: price,
                        origin: .productPriceSave
                    )
                    try context.save()
                }
            }
        )

        let summary = try await service.applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_dirty_local")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(summary.totalApplied, 0)
        XCTAssertGreaterThan(remote.productPriceFetchCallCount, 0)
        let context = ModelContext(container)
        let products = try context.fetch(FetchDescriptor<Product>())
        let prices = try context.fetch(FetchDescriptor<ProductPrice>())
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?.productName, "Local parent")
        XCTAssertEqual(prices.count, 1)
        XCTAssertNil(prices.first?.remoteID)
        XCTAssertEqual(prices.first?.price, 1.25)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<LocalPendingChange>()), 1)
        let status = try XCTUnwrap(
            SyncEventApplyStatusStore(defaults: defaults).record(
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                eventID: 172
            )
        )
        XCTAssertEqual(status.status, .blocked)
        XCTAssertEqual(status.reason, .dirtyLocal)
    }

    @MainActor
    private func assertPendingCreatedAfterFetchBlocksAtomicMutation(
        _ fixture: LatePendingFixture
    ) async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333349")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777779")!
        let priceID = UUID(uuidString: "66666666-6666-4666-8666-666666666669")!
        let historyID = UUID(uuidString: "55555555-5555-4555-8555-555555555559")!
        let suiteName = "SyncEventLatePending-\(fixture)-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()

        let event: RemoteSyncEventRow
        let pendingID: UUID
        let pendingKind: LocalPendingChangeEntityKind
        switch fixture {
        case .catalog:
            event = try syncEventRow(
                id: 170,
                ownerUserID: owner,
                domain: "catalog",
                changedCount: 1,
                entityIDsJSON: #"{"product_ids":["77777777-7777-4777-8777-777777777779"]}"#
            )
            pendingID = productID
            pendingKind = .product
        case .price:
            event = try syncEventRow(
                id: 170,
                ownerUserID: owner,
                domain: "prices",
                changedCount: 1,
                entityIDsJSON: #"{"price_ids":["66666666-6666-4666-8666-666666666669"],"product_ids":["77777777-7777-4777-8777-777777777779"]}"#
            )
            pendingID = priceID
            pendingKind = .productPrice
        case .history:
            event = try syncEventRow(
                id: 170,
                ownerUserID: owner,
                domain: "history",
                changedCount: 1,
                entityIDsJSON: #"{"session_ids":["55555555-5555-4555-8555-555555555559"]}"#
            )
            pendingID = historyID
            pendingKind = .historySession
        }

        let product = RemoteInventoryProductRow(
            id: productID,
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            barcode: "LATE-PENDING",
            itemNumber: nil,
            productName: "Late pending",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            updatedAt: "2026-07-21T12:00:00Z",
            deletedAt: nil
        )
        let price = RemoteInventoryProductPriceRow(
            id: priceID,
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            productID: productID,
            type: "RETAIL",
            price: 4.25,
            effectiveAt: "2026-07-21T12:00:00Z",
            source: "REMOTE",
            note: nil,
            createdAt: "2026-07-21T12:00:00Z",
            updatedAt: "2026-07-21T12:00:00Z"
        )
        let history = RemoteSharedSheetSessionRow(
            remoteID: historyID,
            payloadVersion: 2,
            displayName: "Late pending history",
            timestamp: "2026-07-21T12:00:00Z",
            supplier: "",
            category: "",
            isManualEntry: false,
            data: [["item"]],
            sessionOverlay: nil,
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            updatedAt: "2026-07-21T12:00:00Z",
            deletedAt: nil
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            products: fixture == .history ? [] : [product],
            productPrices: fixture == .price ? [price] : [],
            historySessions: fixture == .history ? [history] : []
        )
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults,
            beforeAtomicMutationForTesting: {
                try await MainActor.run {
                    let context = ModelContext(container)
                    context.insert(LocalPendingChange(
                        ownerUserID: owner,
                        entityKind: pendingKind,
                        operation: .update,
                        origin: .reconciliation,
                        logicalKey: "late:remote:\(pendingID.uuidString.lowercased())",
                        entityRemoteID: pendingID
                    ))
                    try context.save()
                }
            }
        )

        let summary = try await service.applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_dirty_local")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(summary.totalApplied, 0)
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProductPrice>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HistoryEntry>()), 0)
        let status = try XCTUnwrap(
            SyncEventApplyStatusStore(defaults: defaults).record(
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                eventID: 170
            )
        )
        XCTAssertEqual(status.status, .blocked)
        XCTAssertEqual(status.reason, .dirtyLocal)
    }

    @MainActor
    func testFailureBeforeAtomicCommitRollsBackCatalogPriceAndHistoryTogether() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333350")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777780")!
        let priceID = UUID(uuidString: "66666666-6666-4666-8666-666666666670")!
        let historyID = UUID(uuidString: "55555555-5555-4555-8555-555555555560")!
        let suiteName = "SyncEventAtomicRollback-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let events = [
            try syncEventRow(
                id: 180,
                ownerUserID: owner,
                domain: "prices",
                changedCount: 1,
                entityIDsJSON: #"{"price_ids":["66666666-6666-4666-8666-666666666670"],"product_ids":["77777777-7777-4777-8777-777777777780"]}"#
            ),
            try syncEventRow(
                id: 181,
                ownerUserID: owner,
                domain: "history",
                changedCount: 1,
                entityIDsJSON: #"{"session_ids":["55555555-5555-4555-8555-555555555560"]}"#
            )
        ]
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: events,
            products: [
                RemoteInventoryProductRow(
                    id: productID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    barcode: "ATOMIC-ROLLBACK",
                    itemNumber: nil,
                    productName: "Atomic rollback",
                    secondProductName: nil,
                    purchasePrice: nil,
                    retailPrice: nil,
                    supplierID: nil,
                    categoryID: nil,
                    stockQuantity: nil,
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: nil
                )
            ],
            productPrices: [
                RemoteInventoryProductPriceRow(
                    id: priceID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    productID: productID,
                    type: "RETAIL",
                    price: 9.75,
                    effectiveAt: "2026-07-21T12:00:00Z",
                    source: "REMOTE",
                    note: nil,
                    createdAt: "2026-07-21T12:00:00Z",
                    updatedAt: "2026-07-21T12:00:00Z"
                )
            ],
            historySessions: [
                RemoteSharedSheetSessionRow(
                    remoteID: historyID,
                    payloadVersion: 2,
                    displayName: "Atomic rollback history",
                    timestamp: "2026-07-21T12:00:00Z",
                    supplier: "",
                    category: "",
                    isManualEntry: false,
                    data: [["item"]],
                    sessionOverlay: nil,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: nil
                )
            ]
        )
        let container = try makeContainer()
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults,
            atomicMutationProbeForTesting: { phase in
                if case .afterMutationsBeforeCommit = phase {
                    throw AtomicProbeError.injectedBeforeCommit
                }
            }
        )

        do {
            _ = try await service.applyNextEvents(
                ownerUserID: owner,
                modelContainer: container,
                isAuthenticated: true
            )
            XCTFail("Expected injected transaction failure")
        } catch {
            XCTAssertEqual(error as? AtomicProbeError, .injectedBeforeCommit)
        }

        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProductPrice>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HistoryEntry>()), 0)
        XCTAssertEqual(
            WatermarkStore(defaults: defaults).watermark(
                for: WatermarkStore.Scope(
                    ownerUserID: owner,
                    storeIdentity: LocalStoreIdentity(
                        rawValue: Self.automaticShopID.uuidString.lowercased()
                    )
                )
            ),
            0
        )
        let statuses = SyncEventApplyStatusStore(defaults: defaults)
        XCTAssertNil(statuses.record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 180
        ))
        XCTAssertNil(statuses.record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 181
        ))
    }

    @MainActor
    func testSelfOriginEventRecordsSkippedStatusAndAdvancesWatermark() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333337")!
        let productID = UUID(uuidString: "88888888-8888-4888-8888-888888888881")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)

        let event = try syncEventRow(
            id: 105,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 1,
            sourceDeviceID: "ios-device-under-test",
            redactedSourceDevice: true,
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
        let applyStatus = try XCTUnwrap(SyncEventApplyStatusStore(defaults: defaults).record(ownerUserID: owner, shopID: Self.automaticShopID, eventID: 105))
        XCTAssertEqual(applyStatus.status, .skipped)
        XCTAssertEqual(applyStatus.reason, .selfOrigin)
        XCTAssertEqual(applyStatus.entityIDs.productIDs, [productID])
    }

    @MainActor
    func testBackendRecoveryFlagBlocksEvenZeroCountSupportedEvent() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333343")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-backend-recovery-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let event = try syncEventRow(
            id: 160,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 0,
            sourceDeviceID: "ios-device-under-test",
            redactedSourceDevice: true,
            requiresFullRecovery: true,
            entityIDsJSON: "null"
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

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_backend_requires_full_recovery")
        XCTAssertEqual(summary.watermarkAfter, 0)
        let status = try XCTUnwrap(
            SyncEventApplyStatusStore(defaults: defaults).record(
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                eventID: 160
            )
        )
        XCTAssertEqual(status.status, .blocked)
        XCTAssertEqual(status.reason, .missingEntityIDs)
    }

    @MainActor
    func testIncompleteDuplicateAndCrossDomainEventsBlockBeforeSelfOriginSkip() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333342")!
        let fixtures: [(domain: String, changedCount: Int, entityIDs: String)] = [
            (
                "catalog",
                2,
                #"{"product_ids":["88888888-8888-4888-8888-888888888881"]}"#
            ),
            (
                "prices",
                2,
                #"{"price_ids":["66666666-6666-4666-8666-666666666661","66666666-6666-4666-8666-666666666661"],"product_ids":["55555555-5555-4555-8555-555555555551"]}"#
            ),
            (
                "prices",
                1,
                #"{"price_ids":["66666666-6666-4666-8666-666666666661"],"product_ids":["55555555-5555-4555-8555-555555555551","55555555-5555-4555-8555-555555555552"]}"#
            ),
            (
                "history",
                1,
                #"{"product_ids":["77777777-7777-4777-8777-777777777771"]}"#
            ),
            (
                "catalog",
                0,
                #"{"product_ids":["99999999-9999-4999-8999-999999999991"]}"#
            )
        ]

        for (index, fixture) in fixtures.enumerated() {
            let suiteName = "SyncEventIncrementalDomainApplyServiceTests-malformed-\(index)-\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }
            try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
            let eventID = Int64(150 + index)
            let event = try syncEventRow(
                id: eventID,
                ownerUserID: owner,
                domain: fixture.domain,
                changedCount: fixture.changedCount,
                sourceDeviceID: "ios-device-under-test",
                entityIDsJSON: fixture.entityIDs
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

            XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_missing_entity_ids")
            XCTAssertEqual(summary.watermarkAfter, 0)
            XCTAssertEqual(remote.catalogFetchCallCount, 0)
            let status = try XCTUnwrap(
                SyncEventApplyStatusStore(defaults: defaults).record(
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    eventID: eventID
                )
            )
            XCTAssertEqual(status.status, .blocked)
            XCTAssertEqual(status.reason, .missingEntityIDs)
        }
    }

    @MainActor
    func testMissingRemoteTargetRecordsBlockedStatusAndDoesNotAdvanceWatermark() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333338")!
        let productID = UUID(uuidString: "99999999-9999-4999-8999-999999999991")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)

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
        let applyStatus = try XCTUnwrap(SyncEventApplyStatusStore(defaults: defaults).record(ownerUserID: owner, shopID: Self.automaticShopID, eventID: 106))
        XCTAssertEqual(applyStatus.status, .blocked)
        XCTAssertEqual(applyStatus.reason, .missingRemote)
        XCTAssertEqual(applyStatus.entityIDs.productIDs, [productID])
        XCTAssertNotNil(applyStatus.nextRetryAtMs)
    }

    @MainActor
    func testProductPriceConflictBlocksWholeEventWithoutApplyingIndependentRow() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333335")!
        let productAID = UUID(uuidString: "55555555-5555-4555-8555-555555555551")!
        let productBID = UUID(uuidString: "55555555-5555-4555-8555-555555555552")!
        let priceAID = UUID(uuidString: "66666666-6666-4666-8666-666666666661")!
        let priceBID = UUID(uuidString: "66666666-6666-4666-8666-666666666662")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)

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
            entityIDsJSON: #"{"price_ids":["66666666-6666-4666-8666-666666666661","66666666-6666-4666-8666-666666666662"],"product_ids":["55555555-5555-4555-8555-555555555551","55555555-5555-4555-8555-555555555552"]}"#
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            products: [
                RemoteInventoryProductRow(
                    id: productAID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
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
                    shopID: Self.automaticShopID,
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
                    shopID: Self.automaticShopID,
                    productID: productAID,
                    type: "PURCHASE",
                    price: 2.00,
                    effectiveAt: "2026-07-05T10:00:00Z",
                    source: "REMOTE_CONFLICT",
                    note: nil,
                    createdAt: "2026-07-05T10:00:00Z",
                    updatedAt: "2026-07-05T10:00:00Z"
                ),
                RemoteInventoryProductPriceRow(
                    id: priceBID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    productID: productBID,
                    type: "RETAIL",
                    price: 3.00,
                    effectiveAt: "2026-07-05T11:00:00Z",
                    source: "REMOTE_OK",
                    note: nil,
                    createdAt: "2026-07-05T11:00:00Z",
                    updatedAt: "2026-07-05T11:00:00Z"
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

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_remote_row_not_materializable")
        XCTAssertEqual(summary.productPricesInserted, 0)
        XCTAssertEqual(summary.watermarkAfter, 0)
        let prices = try context.fetch(FetchDescriptor<ProductPrice>())
        XCTAssertEqual(prices.count, 1)
        XCTAssertFalse(prices.contains { $0.remoteID == priceBID })
        XCTAssertTrue(prices.contains { $0.remoteID == nil && $0.price == 1.00 })
        let status = try XCTUnwrap(
            SyncEventApplyStatusStore(defaults: defaults).record(
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                eventID: 103
            )
        )
        XCTAssertEqual(status.status, .blocked)
        XCTAssertEqual(status.reason, .remoteRowNotMaterializable)
    }

    @MainActor
    func testCatalogTombstonesNeverAdoptReusedLocalKeys() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333353")!
        let oldSupplierID = UUID(uuidString: "44444444-4444-4444-8444-444444444451")!
        let newSupplierID = UUID(uuidString: "44444444-4444-4444-8444-444444444452")!
        let oldCategoryID = UUID(uuidString: "55555555-5555-4555-8555-555555555551")!
        let newCategoryID = UUID(uuidString: "55555555-5555-4555-8555-555555555552")!
        let oldProductID = UUID(uuidString: "77777777-7777-4777-8777-777777777751")!
        let newProductID = UUID(uuidString: "77777777-7777-4777-8777-777777777752")!
        let suiteName = "SyncEventTombstoneReusedKeys-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let context = ModelContext(container)
        let supplier = Supplier(name: "Reused supplier", remoteID: newSupplierID)
        let category = ProductCategory(name: "Reused category", remoteID: newCategoryID)
        let product = Product(
            barcode: "REUSED-BARCODE",
            remoteID: newProductID,
            supplier: supplier,
            category: category
        )
        context.insert(supplier)
        context.insert(category)
        context.insert(product)
        context.insert(LocalPendingChange(
            ownerUserID: owner,
            entityKind: .supplier,
            operation: .update,
            origin: .manualCatalogSave,
            logicalKey: LocalPendingChangeLogicalKey.supplier(
                remoteID: nil,
                name: supplier.name
            ),
            entityRemoteID: newSupplierID
        ))
        context.insert(LocalPendingChange(
            ownerUserID: owner,
            entityKind: .productCategory,
            operation: .update,
            origin: .manualCatalogSave,
            logicalKey: LocalPendingChangeLogicalKey.category(
                remoteID: nil,
                name: category.name
            ),
            entityRemoteID: newCategoryID
        ))
        context.insert(LocalPendingChange(
            ownerUserID: owner,
            entityKind: .product,
            operation: .update,
            origin: .manualCatalogSave,
            logicalKey: LocalPendingChangeLogicalKey.product(
                remoteID: nil,
                barcode: product.barcode
            ),
            entityRemoteID: newProductID
        ))
        try context.save()
        let event = try syncEventRow(
            id: 190,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 3,
            entityIDsJSON: #"{"supplier_ids":["44444444-4444-4444-8444-444444444451"],"category_ids":["55555555-5555-4555-8555-555555555551"],"product_ids":["77777777-7777-4777-8777-777777777751"]}"#
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            suppliers: [
                RemoteInventorySupplierRow(
                    id: oldSupplierID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    name: "Reused supplier",
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: "2026-07-21T12:01:00Z"
                )
            ],
            categories: [
                RemoteInventoryCategoryRow(
                    id: oldCategoryID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    name: "Reused category",
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: "2026-07-21T12:01:00Z"
                )
            ],
            products: [
                RemoteInventoryProductRow(
                    id: oldProductID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    barcode: "REUSED-BARCODE",
                    itemNumber: nil,
                    productName: nil,
                    secondProductName: nil,
                    purchasePrice: nil,
                    retailPrice: nil,
                    supplierID: nil,
                    categoryID: nil,
                    stockQuantity: nil,
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: "2026-07-21T12:01:00Z"
                )
            ]
        )

        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        ).applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        XCTAssertNil(summary.requiresFullRecoveryReason)
        XCTAssertEqual(summary.watermarkAfter, 190)
        let read = ModelContext(container)
        let suppliers = try read.fetch(FetchDescriptor<Supplier>())
        let categories = try read.fetch(FetchDescriptor<ProductCategory>())
        let products = try read.fetch(FetchDescriptor<Product>())
        XCTAssertEqual(suppliers.first?.remoteID, newSupplierID)
        XCTAssertNil(suppliers.first?.remoteDeletedAt)
        XCTAssertEqual(categories.first?.remoteID, newCategoryID)
        XCTAssertNil(categories.first?.remoteDeletedAt)
        XCTAssertEqual(products.first?.remoteID, newProductID)
        XCTAssertNil(products.first?.remoteDeletedAt)
        XCTAssertEqual(products.first?.supplier?.remoteID, newSupplierID)
        XCTAssertEqual(products.first?.category?.remoteID, newCategoryID)
        XCTAssertEqual(try read.fetchCount(FetchDescriptor<LocalPendingChange>()), 3)
    }

    @MainActor
    func testActiveCatalogKeyCollisionBlocksWithoutRewritingIdentity() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333354")!
        let localID = UUID(uuidString: "77777777-7777-4777-8777-777777777753")!
        let remoteID = UUID(uuidString: "77777777-7777-4777-8777-777777777754")!
        let suiteName = "SyncEventActiveKeyCollision-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Product(
            barcode: "ACTIVE-COLLISION",
            remoteID: localID,
            productName: "Local identity"
        ))
        try context.save()
        let event = try syncEventRow(
            id: 191,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 1,
            entityIDsJSON: #"{"product_ids":["77777777-7777-4777-8777-777777777754"]}"#
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            products: [
                RemoteInventoryProductRow(
                    id: remoteID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    barcode: "ACTIVE-COLLISION",
                    itemNumber: nil,
                    productName: "Remote identity",
                    secondProductName: nil,
                    purchasePrice: nil,
                    retailPrice: nil,
                    supplierID: nil,
                    categoryID: nil,
                    stockQuantity: nil,
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: nil
                )
            ]
        )

        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        ).applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_remote_row_not_materializable")
        XCTAssertEqual(summary.watermarkAfter, 0)
        let products = try ModelContext(container).fetch(FetchDescriptor<Product>())
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?.remoteID, localID)
        XCTAssertEqual(products.first?.productName, "Local identity")
        let status = try XCTUnwrap(
            SyncEventApplyStatusStore(defaults: defaults).record(
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                eventID: 191
            )
        )
        XCTAssertEqual(status.status, .blocked)
        XCTAssertEqual(status.reason, .remoteRowNotMaterializable)
    }

    @MainActor
    func testDuplicateRemoteCatalogIDFailsClosedWithoutDictionaryTrap() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333357")!
        let supplierID = UUID(uuidString: "44444444-4444-4444-8444-444444444457")!
        let suiteName = "SyncEventDuplicateRemoteID-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let event = try syncEventRow(
            id: 192,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 1,
            entityIDsJSON: #"{"supplier_ids":["44444444-4444-4444-8444-444444444457"]}"#
        )
        let row = RemoteInventorySupplierRow(
            id: supplierID,
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            name: "Duplicate ID",
            updatedAt: "2026-07-21T12:00:00Z",
            deletedAt: nil
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            suppliers: [row, row]
        )
        let container = try makeContainer()

        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        ).applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_missing_remote")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Supplier>()), 0)
    }

    @MainActor
    func testRemoteCanonicalCatalogCollisionBlocksWholeEvent() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333358")!
        let firstID = UUID(uuidString: "44444444-4444-4444-8444-444444444458")!
        let secondID = UUID(uuidString: "44444444-4444-4444-8444-444444444459")!
        let suiteName = "SyncEventRemoteCanonicalCollision-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let event = try syncEventRow(
            id: 193,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 2,
            entityIDsJSON: #"{"supplier_ids":["44444444-4444-4444-8444-444444444458","44444444-4444-4444-8444-444444444459"]}"#
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            suppliers: [
                RemoteInventorySupplierRow(
                    id: firstID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    name: "Canonical collision",
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: nil
                ),
                RemoteInventorySupplierRow(
                    id: secondID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    name: " canonical collision ",
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: nil
                )
            ]
        )
        let container = try makeContainer()

        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        ).applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_remote_row_not_materializable")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Supplier>()), 0)
        XCTAssertEqual(
            SyncEventApplyStatusStore(defaults: defaults).record(
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                eventID: 193
            )?.reason,
            .remoteRowNotMaterializable
        )
    }

    @MainActor
    func testUnmaterializablePriceBlocksWholeCurrentStatePage() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333355")!
        let supplierID = UUID(uuidString: "44444444-4444-4444-8444-444444444455")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777755")!
        let priceID = UUID(uuidString: "66666666-6666-4666-8666-666666666675")!
        let historyID = UUID(uuidString: "55555555-5555-4555-8555-555555555575")!
        let suiteName = "SyncEventInvalidPricePrefix-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let events = [
            try syncEventRow(
                id: 200,
                ownerUserID: owner,
                domain: "catalog",
                changedCount: 1,
                entityIDsJSON: #"{"supplier_ids":["44444444-4444-4444-8444-444444444455"]}"#
            ),
            try syncEventRow(
                id: 201,
                ownerUserID: owner,
                domain: "prices",
                changedCount: 1,
                entityIDsJSON: #"{"price_ids":["66666666-6666-4666-8666-666666666675"],"product_ids":["77777777-7777-4777-8777-777777777755"]}"#
            ),
            try syncEventRow(
                id: 202,
                ownerUserID: owner,
                domain: "history",
                changedCount: 1,
                entityIDsJSON: #"{"session_ids":["55555555-5555-4555-8555-555555555575"]}"#
            )
        ]
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: events,
            suppliers: [
                RemoteInventorySupplierRow(
                    id: supplierID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    name: "Verified prefix",
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: nil
                )
            ],
            products: [
                RemoteInventoryProductRow(
                    id: productID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    barcode: "INVALID-PRICE-PARENT",
                    itemNumber: nil,
                    productName: nil,
                    secondProductName: nil,
                    purchasePrice: nil,
                    retailPrice: nil,
                    supplierID: nil,
                    categoryID: nil,
                    stockQuantity: nil,
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: nil
                )
            ],
            productPrices: [
                RemoteInventoryProductPriceRow(
                    id: priceID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    productID: productID,
                    type: "INVALID",
                    price: 5,
                    effectiveAt: "2026-07-21T12:00:00Z",
                    source: nil,
                    note: nil,
                    createdAt: "2026-07-21T12:00:00Z",
                    updatedAt: "2026-07-21T12:00:00Z"
                )
            ],
            historySessions: [
                RemoteSharedSheetSessionRow(
                    remoteID: historyID,
                    payloadVersion: 2,
                    displayName: "Must remain later",
                    timestamp: "2026-07-21T12:00:00Z",
                    supplier: "",
                    category: "",
                    isManualEntry: false,
                    data: [["item"]],
                    sessionOverlay: nil,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: nil
                )
            ]
        )
        let container = try makeContainer()

        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        ).applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_remote_row_not_materializable")
        XCTAssertEqual(summary.watermarkAfter, 0)
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Supplier>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProductPrice>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HistoryEntry>()), 0)
        let statuses = SyncEventApplyStatusStore(defaults: defaults)
        XCTAssertNil(statuses.record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 200
        ))
        XCTAssertEqual(statuses.record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 201
        )?.reason, .remoteRowNotMaterializable)
        XCTAssertNil(statuses.record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 202
        ))
    }

    @MainActor
    func testUnmaterializableHistoryBlocksWholeCurrentStatePage() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333356")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777756")!
        let priceID = UUID(uuidString: "66666666-6666-4666-8666-666666666676")!
        let historyID = UUID(uuidString: "55555555-5555-4555-8555-555555555576")!
        let supplierID = UUID(uuidString: "44444444-4444-4444-8444-444444444456")!
        let suiteName = "SyncEventInvalidHistoryPrefix-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let events = [
            try syncEventRow(
                id: 210,
                ownerUserID: owner,
                domain: "prices",
                changedCount: 1,
                entityIDsJSON: #"{"price_ids":["66666666-6666-4666-8666-666666666676"],"product_ids":["77777777-7777-4777-8777-777777777756"]}"#
            ),
            try syncEventRow(
                id: 211,
                ownerUserID: owner,
                domain: "history",
                changedCount: 1,
                entityIDsJSON: #"{"session_ids":["55555555-5555-4555-8555-555555555576"]}"#
            ),
            try syncEventRow(
                id: 212,
                ownerUserID: owner,
                domain: "catalog",
                changedCount: 1,
                entityIDsJSON: #"{"supplier_ids":["44444444-4444-4444-8444-444444444456"]}"#
            )
        ]
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: events,
            suppliers: [
                RemoteInventorySupplierRow(
                    id: supplierID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    name: "Must remain later",
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: nil
                )
            ],
            products: [
                RemoteInventoryProductRow(
                    id: productID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    barcode: "VALID-PRICE-PREFIX",
                    itemNumber: nil,
                    productName: nil,
                    secondProductName: nil,
                    purchasePrice: nil,
                    retailPrice: nil,
                    supplierID: nil,
                    categoryID: nil,
                    stockQuantity: nil,
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: nil
                )
            ],
            productPrices: [
                RemoteInventoryProductPriceRow(
                    id: priceID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    productID: productID,
                    type: "RETAIL",
                    price: 6,
                    effectiveAt: "2026-07-21T12:00:00Z",
                    source: nil,
                    note: nil,
                    createdAt: "2026-07-21T12:00:00Z",
                    updatedAt: "2026-07-21T12:00:00Z"
                )
            ],
            historySessions: [
                RemoteSharedSheetSessionRow(
                    remoteID: historyID,
                    payloadVersion: 2,
                    displayName: "Invalid history",
                    timestamp: "not-a-timestamp",
                    supplier: "",
                    category: "",
                    isManualEntry: false,
                    data: [["item"]],
                    sessionOverlay: nil,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    updatedAt: "not-a-timestamp",
                    deletedAt: nil
                )
            ]
        )
        let container = try makeContainer()

        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        ).applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_remote_row_not_materializable")
        XCTAssertEqual(summary.watermarkAfter, 0)
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProductPrice>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HistoryEntry>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Supplier>()), 0)
        let statuses = SyncEventApplyStatusStore(defaults: defaults)
        XCTAssertNil(statuses.record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 210
        ))
        XCTAssertEqual(statuses.record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 211
        )?.reason, .remoteRowNotMaterializable)
        XCTAssertNil(statuses.record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 212
        ))
    }

    @MainActor
    func testTombstonedPriceParentBlocksBeforeLaterHistoryMutation() async throws {
        try await assertPriceParentDynamicBlock(parentIsReturnedTombstone: true)
    }

    @MainActor
    func testUnknownPriceParentBlocksBeforeLaterHistoryMutation() async throws {
        try await assertPriceParentDynamicBlock(parentIsReturnedTombstone: false)
    }

    @MainActor
    private func assertPriceParentDynamicBlock(
        parentIsReturnedTombstone: Bool
    ) async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333348")!
        let activeProductID = UUID(uuidString: "55555555-5555-4555-8555-555555555561")!
        let blockedProductID = UUID(uuidString: "55555555-5555-4555-8555-555555555562")!
        let activePriceID = UUID(uuidString: "66666666-6666-4666-8666-666666666671")!
        let blockedPriceID = UUID(uuidString: "66666666-6666-4666-8666-666666666672")!
        let historyID = UUID(uuidString: "77777777-7777-4777-8777-777777777773")!
        let suiteName = "SyncEventDynamicPriceParent-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)

        let events = [
            try syncEventRow(
                id: 100,
                ownerUserID: owner,
                domain: "prices",
                changedCount: 1,
                entityIDsJSON: #"{"price_ids":["66666666-6666-4666-8666-666666666671"],"product_ids":["55555555-5555-4555-8555-555555555561"]}"#
            ),
            try syncEventRow(
                id: 101,
                ownerUserID: owner,
                domain: "prices",
                changedCount: 1,
                entityIDsJSON: #"{"price_ids":["66666666-6666-4666-8666-666666666672"],"product_ids":["55555555-5555-4555-8555-555555555562"]}"#
            ),
            try syncEventRow(
                id: 102,
                ownerUserID: owner,
                domain: "history",
                changedCount: 1,
                entityIDsJSON: #"{"session_ids":["77777777-7777-4777-8777-777777777773"]}"#
            )
        ]
        let activeProduct = RemoteInventoryProductRow(
            id: activeProductID,
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            barcode: "ACTIVE-PARENT",
            itemNumber: nil,
            productName: "Active parent",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            updatedAt: "2026-07-21T12:00:00Z",
            deletedAt: nil
        )
        let blockedProduct = RemoteInventoryProductRow(
            id: blockedProductID,
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            barcode: "BLOCKED-PARENT",
            itemNumber: nil,
            productName: "Blocked parent",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            updatedAt: "2026-07-21T12:00:00Z",
            deletedAt: "2026-07-21T12:01:00Z"
        )
        let history = RemoteSharedSheetSessionRow(
            remoteID: historyID,
            payloadVersion: 2,
            displayName: "Must remain invisible",
            timestamp: "2026-07-21T12:00:00Z",
            supplier: "",
            category: "",
            isManualEntry: false,
            data: [["item"]],
            sessionOverlay: nil,
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            updatedAt: "2026-07-21T12:00:00Z",
            deletedAt: nil
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: events,
            products: [activeProduct] + (parentIsReturnedTombstone ? [blockedProduct] : []),
            productPrices: [
                RemoteInventoryProductPriceRow(
                    id: activePriceID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    productID: activeProductID,
                    type: "RETAIL",
                    price: 1.00,
                    effectiveAt: "2026-07-21T12:00:00Z",
                    source: "REMOTE_OK",
                    note: nil,
                    createdAt: "2026-07-21T12:00:00Z",
                    updatedAt: "2026-07-21T12:00:00Z"
                ),
                RemoteInventoryProductPriceRow(
                    id: blockedPriceID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    productID: blockedProductID,
                    type: "RETAIL",
                    price: 2.00,
                    effectiveAt: "2026-07-21T12:01:00Z",
                    source: "REMOTE_BLOCKED",
                    note: nil,
                    createdAt: "2026-07-21T12:01:00Z",
                    updatedAt: "2026-07-21T12:01:00Z"
                )
            ],
            historySessions: [history]
        )
        let container = try makeContainer()
        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        ).applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        XCTAssertEqual(
            summary.requiresFullRecoveryReason,
            "sync_event_price_parent_not_materializable"
        )
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(summary.productPricesInserted, 0)
        XCTAssertEqual(summary.historyInserted, 0)
        let context = ModelContext(container)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<ProductPrice>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HistoryEntry>()), 0)
        let statuses = SyncEventApplyStatusStore(defaults: defaults)
        XCTAssertNil(statuses.record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 100
        ))
        let blockedStatus = try XCTUnwrap(statuses.record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 101
        ))
        XCTAssertEqual(blockedStatus.status, .blocked)
        XCTAssertEqual(blockedStatus.reason, .priceParentNotMaterializable)
        XCTAssertNil(statuses.record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 102
        ))
    }

    @MainActor
    func testForeignShopResponseIsRejectedWithoutAdvancingSelectedShopWatermark() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333339")!
        let selectedShopID = UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!
        let foreignShopID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let selectedShop = SelectedShop(
            shopID: selectedShopID,
            code: nil,
            name: "Selected fixture shop",
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true
        )
        SelectedShopStore(defaults: defaults).save(selectedShop, accountHash: accountHash)
        SelectedShopStore(defaults: defaults).noteActiveAccount(accountHash)
        let bindingStore = AccountBindingStore(defaults: defaults)
        XCTAssertTrue(bindingStore.saveBinding(
            accountHash: accountHash,
            storeIdentity: selectedShop.localStoreIdentity
        ))
        let events = [
            try syncEventRow(
                id: 140,
                ownerUserID: owner,
                domain: "catalog",
                changedCount: 1,
                shopID: foreignShopID,
                entityIDsJSON: #"{"product_ids":["99999999-9999-4999-8999-999999999991"]}"#
            ),
            try syncEventRow(
                id: 141,
                ownerUserID: owner,
                domain: "catalog",
                changedCount: 1,
                shopID: foreignShopID,
                entityIDsJSON: #"{"product_ids":["99999999-9999-4999-8999-999999999992"]}"#
            )
        ]
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: events)
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        )

        do {
            _ = try await service.applyNextEvents(
                ownerUserID: owner,
                modelContainer: try makeContainer(),
                isAuthenticated: true
            )
            XCTFail("Expected foreign-shop response to fail closed")
        } catch {
            XCTAssertEqual(error as? Task126OwnerStoreGateError, .scopeChanged)
        }
        XCTAssertEqual(
            WatermarkStore(defaults: defaults).watermark(
                for: WatermarkStore.Scope(
                    ownerUserID: owner,
                    storeIdentity: selectedShop.localStoreIdentity
                )
            ),
            0
        )
        XCTAssertEqual(remote.catalogFetchCallCount, 0)
    }

    @MainActor
    func testPendingReplacementTaskLocalDrainsFromAuthoritativeRecoveryWatermark() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333340")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-pending-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let storeIdentity = LocalStoreIdentity(rawValue: Self.automaticShopID.uuidString.lowercased())
        let bindingStore = AccountBindingStore(defaults: defaults)
        XCTAssertTrue(bindingStore.beginReplacement(
            accountHash: accountHash,
            storeIdentity: storeIdentity
        ))
        XCTAssertTrue(bindingStore.markPendingReplacementWipeCommitted(
            accountHash: accountHash,
            storeIdentity: storeIdentity
        ))
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: owner,
            defaults: defaults,
            allowsPendingReplacement: true
        )
        let watermarkScope = WatermarkStore.Scope(
            ownerUserID: owner,
            storeIdentity: storeIdentity
        )
        WatermarkStore(defaults: defaults).save(42, for: watermarkScope)
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: [])
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        )

        _ = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
            try await service.applyNextEvents(
                ownerUserID: owner,
                modelContainer: try makeContainer(),
                isAuthenticated: true,
                forceLightReconcile: true
            )
        }

        XCTAssertEqual(remote.fetchedAfterIDs, [42])
        XCTAssertEqual(remote.reconciliationCallCount, 1)
        XCTAssertTrue(bindingStore.hasPendingReplacementJournal)
    }

    @MainActor
    func testForcedLightReconcileBypassesRecentReconcileThrottle() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333341")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-forced-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let storeIdentity = LocalStoreIdentity(rawValue: Self.automaticShopID.uuidString.lowercased())
        let reconcileKey = "sync.events.lightReconcile.lastAt.\(AccountBindingStore.accountHash(for: owner)).store.\(storeIdentity.storeId.lowercased())"
        defaults.set(Date().timeIntervalSince1970, forKey: reconcileKey)
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: [])
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        )

        let summary = try await service.applyNextEvents(
            ownerUserID: owner,
            modelContainer: try makeContainer(),
            isAuthenticated: true,
            forceLightReconcile: true
        )

        XCTAssertEqual(summary.syncType, .lightReconcile)
        XCTAssertFalse(summary.requiresFullRecovery)
        XCTAssertEqual(remote.reconciliationCallCount, 1)
    }

    func testApplyStatusIsShopScopedBoundedAndRetainsBlockers() throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333344")!
        let otherShop = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2")!
        let suiteName = "SyncEventApplyStatusBounded-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SyncEventApplyStatusStore(defaults: defaults)
        var ids = SyncEventEntityIDSet()
        ids.productIDs = Set((0..<64).map { _ in UUID() })

        for eventID in 1...10 {
            let event = try syncEventRow(
                id: Int64(eventID),
                ownerUserID: owner,
                domain: "catalog",
                changedCount: 64,
                entityIDsJSON: "null"
            )
            XCTAssertTrue(store.record(
                event: event,
                ownerUserID: owner,
                scopeShopID: Self.automaticShopID,
                ids: ids,
                status: .blocked,
                reason: .missingEntityIDs,
                nowMs: eventID
            ))
        }
        for eventID in 11...(store.maximumRecordsForTesting + 80) {
            let event = try syncEventRow(
                id: Int64(eventID),
                ownerUserID: owner,
                domain: String(repeating: "c", count: 1_024),
                changedCount: 1,
                entityIDsJSON: "null"
            )
            XCTAssertTrue(store.record(
                event: event,
                ownerUserID: owner,
                scopeShopID: Self.automaticShopID,
                ids: SyncEventEntityIDSet(),
                status: .applied,
                reason: .applied,
                nowMs: eventID
            ))
        }

        let retained = store.records(ownerUserID: owner, shopID: Self.automaticShopID)
        XCTAssertEqual(retained.count, store.maximumRecordsForTesting)
        XCTAssertEqual(
            Set(retained.filter { $0.status == .blocked }.map(\.eventID)),
            Set((1...10).map(Int64.init))
        )
        let firstBlocker = try XCTUnwrap(retained.first { $0.eventID == 1 })
        XCTAssertEqual(firstBlocker.entityIDs.totalIDCount, 64)
        XCTAssertEqual(firstBlocker.entityIDs.productIDs.count, 32)
        XCTAssertEqual(firstBlocker.entityIDs.isTruncated, true)
        let encoded = try XCTUnwrap(defaults.data(forKey: store.storageKeyForTesting(
            ownerUserID: owner,
            shopID: Self.automaticShopID
        )))
        XCTAssertLessThanOrEqual(encoded.count, store.maximumEncodedBytesForTesting)
        XCTAssertFalse(store.hasOverflow(ownerUserID: owner, shopID: Self.automaticShopID))

        let otherEvent = try syncEventRow(
            id: 1,
            ownerUserID: owner,
            domain: "history",
            changedCount: 0,
            shopID: otherShop,
            entityIDsJSON: "null"
        )
        XCTAssertTrue(store.record(
            event: otherEvent,
            ownerUserID: owner,
            scopeShopID: otherShop,
            ids: SyncEventEntityIDSet(),
            status: .skipped,
            reason: .selfOrigin
        ))
        XCTAssertEqual(store.records(ownerUserID: owner, shopID: otherShop).map(\.eventID), [1])
        XCTAssertEqual(store.record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 1
        )?.status, .blocked)
    }

    func testApplyStatusCorruptOrOversizedPayloadFailsBounded() throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333345")!
        let suiteName = "SyncEventApplyStatusCorrupt-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SyncEventApplyStatusStore(defaults: defaults)
        let key = store.storageKeyForTesting(ownerUserID: owner, shopID: Self.automaticShopID)

        defaults.set(Data([0xde, 0xad, 0xbe, 0xef]), forKey: key)
        XCTAssertTrue(store.records(ownerUserID: owner, shopID: Self.automaticShopID).isEmpty)
        XCTAssertTrue(store.hasCorruptData(ownerUserID: owner, shopID: Self.automaticShopID))

        defaults.set(Data(repeating: 0x41, count: store.maximumEncodedBytesForTesting + 1), forKey: key)
        XCTAssertTrue(store.records(ownerUserID: owner, shopID: Self.automaticShopID).isEmpty)
        XCTAssertTrue(store.hasCorruptData(ownerUserID: owner, shopID: Self.automaticShopID))
    }

    @MainActor
    func testAggregateTargetedIDBudgetRequestsRecoveryWithoutPartialApply() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333346")!
        let suiteName = "SyncEventAggregateIDBudget-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let batches = (0..<5).map { _ in
            (0..<250).map { _ in UUID().uuidString.lowercased() }
        }
        func payload(_ ids: [String]) throws -> String {
            let data = try JSONSerialization.data(withJSONObject: ["product_ids": ids])
            return try XCTUnwrap(String(data: data, encoding: .utf8))
        }
        let events = try batches.enumerated().map { index, ids in
            try syncEventRow(
                id: Int64(201 + index),
                ownerUserID: owner,
                domain: "catalog",
                changedCount: ids.count,
                entityIDsJSON: try payload(ids)
            )
        }
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: events)
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

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_aggregate_entity_ids_too_large")
        XCTAssertEqual(summary.watermarkBefore, 0)
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(summary.totalApplied, 0)
        XCTAssertEqual(remote.catalogFetchCallCount, 0)
        let store = SyncEventApplyStatusStore(defaults: defaults)
        for event in events {
            XCTAssertEqual(
                store.record(
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    eventID: event.id
                )?.reason,
                .aggregateEntityIDsTooLarge
            )
        }
    }

    @MainActor
    func testHistoryEventAtCapPlusOneRequestsRecoveryWithoutFetchOrWatermarkAdvance() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333347")!
        let suiteName = "SyncEventHistoryIDCap-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let ids = (0..<26).map { _ in UUID().uuidString.lowercased() }
        let data = try JSONSerialization.data(withJSONObject: ["session_ids": ids])
        let payload = try XCTUnwrap(String(data: data, encoding: .utf8))
        let event = try syncEventRow(
            id: 206,
            ownerUserID: owner,
            domain: "history",
            changedCount: ids.count,
            entityIDsJSON: payload
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

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_entity_ids_too_large")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(summary.totalApplied, 0)
        XCTAssertEqual(remote.historyFetchCallCount, 0)
        XCTAssertEqual(
            SyncEventApplyStatusStore(defaults: defaults)
                .record(ownerUserID: owner, shopID: Self.automaticShopID, eventID: 206)?
                .reason,
            .entityIDsTooLarge
        )
    }

    @MainActor
    func testCanonicalLocalCatalogKeysAreAdoptedWithoutDuplicateRows() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333360")!
        let supplierID = UUID(uuidString: "44444444-4444-4444-8444-444444444460")!
        let categoryID = UUID(uuidString: "55555555-5555-4555-8555-555555555560")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777760")!
        let suiteName = "SyncEventCanonicalLocalAdoption-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Supplier(name: "  canonical SUPPLIER  "))
        context.insert(ProductCategory(name: "  canonical CATEGORY  "))
        context.insert(Product(barcode: "  SKU-TRIM  ", productName: "Local"))
        try context.save()

        let event = try syncEventRow(
            id: 194,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 3,
            entityIDsJSON: "{\"supplier_ids\":[\"\(supplierID.uuidString)\"],\"category_ids\":[\"\(categoryID.uuidString)\"],\"product_ids\":[\"\(productID.uuidString)\"]}"
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            suppliers: [RemoteInventorySupplierRow(
                id: supplierID,
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                name: "Canonical Supplier",
                updatedAt: "2026-07-21T12:00:00Z",
                deletedAt: nil
            )],
            categories: [RemoteInventoryCategoryRow(
                id: categoryID,
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                name: "Canonical Category",
                updatedAt: "2026-07-21T12:00:00Z",
                deletedAt: nil
            )],
            products: [RemoteInventoryProductRow(
                id: productID,
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                barcode: "SKU-TRIM",
                itemNumber: nil,
                productName: "Remote",
                secondProductName: nil,
                purchasePrice: nil,
                retailPrice: nil,
                supplierID: supplierID,
                categoryID: categoryID,
                stockQuantity: nil,
                updatedAt: "2026-07-21T12:00:00Z",
                deletedAt: nil
            )]
        )

        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        ).applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        XCTAssertEqual(summary.watermarkAfter, 194)
        let read = ModelContext(container)
        let suppliers = try read.fetch(FetchDescriptor<Supplier>())
        let categories = try read.fetch(FetchDescriptor<ProductCategory>())
        let products = try read.fetch(FetchDescriptor<Product>())
        XCTAssertEqual(suppliers.count, 1)
        XCTAssertEqual(categories.count, 1)
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(suppliers.first?.remoteID, supplierID)
        XCTAssertEqual(categories.first?.remoteID, categoryID)
        XCTAssertEqual(products.first?.remoteID, productID)
        XCTAssertEqual(products.first?.barcode, "SKU-TRIM")
    }

    @MainActor
    func testCanonicalLocalCatalogKeyBoundToOtherRemoteIDBlocksWholePage() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333361")!
        let existingID = UUID(uuidString: "44444444-4444-4444-8444-444444444461")!
        let incomingID = UUID(uuidString: "44444444-4444-4444-8444-444444444462")!
        let suiteName = "SyncEventCanonicalLocalCollision-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Supplier(name: " canonical collision ", remoteID: existingID))
        try context.save()
        let event = try syncEventRow(
            id: 195,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 1,
            entityIDsJSON: "{\"supplier_ids\":[\"\(incomingID.uuidString)\"]}"
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            suppliers: [RemoteInventorySupplierRow(
                id: incomingID,
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                name: "CANONICAL COLLISION",
                updatedAt: "2026-07-21T12:00:00Z",
                deletedAt: nil
            )]
        )

        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        ).applyNextEvents(ownerUserID: owner, modelContainer: container, isAuthenticated: true)

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_remote_row_not_materializable")
        XCTAssertEqual(summary.watermarkAfter, 0)
        let suppliers = try ModelContext(container).fetch(FetchDescriptor<Supplier>())
        XCTAssertEqual(suppliers.count, 1)
        XCTAssertEqual(suppliers.first?.remoteID, existingID)
    }

    @MainActor
    func testBarcodeIdentityRemainsTrimmedButCaseSensitiveLikeBackend() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333362")!
        let upperID = UUID(uuidString: "77777777-7777-4777-8777-777777777762")!
        let lowerID = UUID(uuidString: "77777777-7777-4777-8777-777777777763")!
        let suiteName = "SyncEventBarcodeCaseContract-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let event = try syncEventRow(
            id: 196,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 2,
            entityIDsJSON: "{\"product_ids\":[\"\(upperID.uuidString)\",\"\(lowerID.uuidString)\"]}"
        )
        let products = [
            RemoteInventoryProductRow(id: upperID, ownerUserID: owner, shopID: Self.automaticShopID, barcode: "SKU", itemNumber: nil, productName: nil, secondProductName: nil, purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil, updatedAt: "2026-07-21T12:00:00Z", deletedAt: nil),
            RemoteInventoryProductRow(id: lowerID, ownerUserID: owner, shopID: Self.automaticShopID, barcode: "sku", itemNumber: nil, productName: nil, secondProductName: nil, purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil, updatedAt: "2026-07-21T12:00:00Z", deletedAt: nil)
        ]
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: [event], products: products)
        let container = try makeContainer()

        let summary = try await SyncEventIncrementalDomainApplyService(eventFetcher: remote, remote: remote, defaults: defaults)
            .applyNextEvents(ownerUserID: owner, modelContainer: container, isAuthenticated: true)

        XCTAssertFalse(summary.requiresFullRecovery)
        XCTAssertEqual(summary.watermarkAfter, 196)
        XCTAssertEqual(Set(try ModelContext(container).fetch(FetchDescriptor<Product>()).map(\.barcode)), ["SKU", "sku"])
    }

    @MainActor
    func testForeignShopHistoryFingerprintDoesNotBlockSelectedShopApply() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333363")!
        let remoteID = UUID(uuidString: "55555555-5555-4555-8555-555555555563")!
        let foreignShop = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb3")!
        let suiteName = "SyncEventForeignHistoryFingerprint-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let context = ModelContext(container)
        let foreignUID = UUID()
        let foreign = makeHistoryEntry(
            id: "foreign",
            uid: foreignUID,
            remoteID: nil,
            owner: owner,
            shopID: foreignShop,
            storeID: foreignShop.uuidString.lowercased(),
            title: "Shared fingerprint"
        )
        context.insert(foreign)
        try context.save()
        let event = try syncEventRow(id: 197, ownerUserID: owner, domain: "history", changedCount: 1, entityIDsJSON: "{\"session_ids\":[\"\(remoteID.uuidString)\"]}")
        let row = remoteHistoryRow(remoteID: remoteID, owner: owner, title: "Shared fingerprint")
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: [event], historySessions: [row])

        let summary = try await SyncEventIncrementalDomainApplyService(eventFetcher: remote, remote: remote, defaults: defaults)
            .applyNextEvents(ownerUserID: owner, modelContainer: container, isAuthenticated: true)

        XCTAssertEqual(summary.watermarkAfter, 197)
        let entries = try ModelContext(container).fetch(FetchDescriptor<HistoryEntry>())
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.contains { $0.uid == foreignUID && $0.remoteID == nil && $0.shopID == foreignShop })
        XCTAssertTrue(entries.contains { $0.remoteID == remoteID && $0.shopID == Self.automaticShopID })
    }

    @MainActor
    func testRemoteHistoryTombstoneWithDuplicateLocalIdentityBlocksWithoutWatermark() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333364")!
        let remoteID = UUID(uuidString: "55555555-5555-4555-8555-555555555564")!
        let suiteName = "SyncEventHistoryDuplicateTombstone-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let context = ModelContext(container)
        let storeID = Self.automaticShopID.uuidString.lowercased()
        context.insert(makeHistoryEntry(id: "one", uid: UUID(), remoteID: remoteID, owner: owner, shopID: Self.automaticShopID, storeID: storeID, title: "One"))
        context.insert(makeHistoryEntry(id: "two", uid: UUID(), remoteID: remoteID, owner: owner, shopID: Self.automaticShopID, storeID: storeID, title: "Two"))
        try context.save()
        let event = try syncEventRow(id: 198, ownerUserID: owner, domain: "history", changedCount: 1, entityIDsJSON: "{\"session_ids\":[\"\(remoteID.uuidString)\"]}")
        let row = remoteHistoryRow(remoteID: remoteID, owner: owner, title: "Deleted", deletedAt: "2026-07-21T12:01:00Z")
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: [event], historySessions: [row])

        let summary = try await SyncEventIncrementalDomainApplyService(eventFetcher: remote, remote: remote, defaults: defaults)
            .applyNextEvents(ownerUserID: owner, modelContainer: container, isAuthenticated: true)

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_remote_row_not_materializable")
        XCTAssertEqual(summary.watermarkAfter, 0)
        let entries = try ModelContext(container).fetch(FetchDescriptor<HistoryEntry>())
        XCTAssertEqual(entries.count, 2)
        XCTAssertTrue(entries.allSatisfy { $0.remoteDeletedAt == nil })
    }

    @MainActor
    func testRemoteHistoryTombstoneNeverAdoptsMatchingLogicalFingerprint() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333365")!
        let localID = UUID(uuidString: "55555555-5555-4555-8555-555555555565")!
        let remoteID = UUID(uuidString: "55555555-5555-4555-8555-555555555566")!
        let suiteName = "SyncEventHistoryTombstoneFingerprint-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let context = ModelContext(container)
        let local = makeHistoryEntry(id: "local", uid: localID, remoteID: localID, owner: owner, shopID: Self.automaticShopID, storeID: Self.automaticShopID.uuidString.lowercased(), title: "Same payload")
        context.insert(local)
        try context.save()
        let event = try syncEventRow(id: 199, ownerUserID: owner, domain: "history", changedCount: 1, entityIDsJSON: "{\"session_ids\":[\"\(remoteID.uuidString)\"]}")
        let row = remoteHistoryRow(remoteID: remoteID, owner: owner, title: "Same payload", deletedAt: "2026-07-21T12:01:00Z")
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: [event], historySessions: [row])

        let summary = try await SyncEventIncrementalDomainApplyService(eventFetcher: remote, remote: remote, defaults: defaults)
            .applyNextEvents(ownerUserID: owner, modelContainer: container, isAuthenticated: true)

        XCTAssertEqual(summary.watermarkAfter, 199)
        XCTAssertNil(local.remoteDeletedAt)
        XCTAssertEqual(local.remoteID, localID)
    }

    @MainActor
    func testTwoRemoteHistoryRowsCannotClaimOneLocalEntryInSamePage() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333369")!
        let logicalRemoteID = UUID(uuidString: "55555555-5555-4555-8555-555555555569")!
        let uidRemoteID = UUID(uuidString: "55555555-5555-4555-8555-555555555570")!
        let suiteName = "SyncEventHistoryIntraBatchClaim-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let context = ModelContext(container)
        let local = makeHistoryEntry(
            id: "local-alias",
            uid: uidRemoteID,
            remoteID: nil,
            owner: owner,
            shopID: Self.automaticShopID,
            storeID: Self.automaticShopID.uuidString.lowercased(),
            title: "Logical A"
        )
        context.insert(local)
        try context.save()
        let event = try syncEventRow(
            id: 204,
            ownerUserID: owner,
            domain: "history",
            changedCount: 2,
            entityIDsJSON: "{\"session_ids\":[\"\(logicalRemoteID.uuidString)\",\"\(uidRemoteID.uuidString)\"]}"
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            historySessions: [
                remoteHistoryRow(remoteID: logicalRemoteID, owner: owner, title: "Logical A"),
                remoteHistoryRow(remoteID: uidRemoteID, owner: owner, title: "Identity B")
            ]
        )

        let summary = try await SyncEventIncrementalDomainApplyService(eventFetcher: remote, remote: remote, defaults: defaults)
            .applyNextEvents(ownerUserID: owner, modelContainer: container, isAuthenticated: true)

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_remote_row_not_materializable")
        XCTAssertEqual(summary.watermarkAfter, 0)
        let entries = try ModelContext(container).fetch(FetchDescriptor<HistoryEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertNil(entries.first?.remoteID)
        XCTAssertEqual(entries.first?.title, "Logical A")
    }

    @MainActor
    func testLateImportCapMarkerBlocksUnknownCatalogRowAndWatermark() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333366")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777766")!
        let suiteName = "SyncEventLateImportCap-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let event = try syncEventRow(id: 203, ownerUserID: owner, domain: "catalog", changedCount: 1, entityIDsJSON: "{\"product_ids\":[\"\(productID.uuidString)\"]}")
        let product = RemoteInventoryProductRow(id: productID, ownerUserID: owner, shopID: Self.automaticShopID, barcode: "CAP-UNKNOWN", itemNumber: nil, productName: "Remote must not win", secondProductName: nil, purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil, updatedAt: "2026-07-21T12:00:00Z", deletedAt: nil)
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: [event], products: [product])
        let storeIdentity = LocalStoreIdentity(rawValue: Self.automaticShopID.uuidString.lowercased())
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults,
            beforeAtomicMutationForTesting: {
                try await MainActor.run {
                    let context = ModelContext(container)
                    context.insert(LocalPendingChange(
                        ownerUserID: owner,
                        storeId: storeIdentity.storeId,
                        localStoreId: storeIdentity.localStoreId,
                        entityKind: .importBatch,
                        operation: .upsert,
                        status: .blocked,
                        origin: .confirmedImport,
                        logicalKey: "import:cap:\(owner.uuidString.lowercased())",
                        changedFields: ["capped", "count"]
                    ))
                    try context.save()
                }
            }
        )

        let summary = try await service.applyNextEvents(ownerUserID: owner, modelContainer: container, isAuthenticated: true)

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_dirty_local")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Product>()), 0)
        XCTAssertEqual(SyncEventApplyStatusStore(defaults: defaults).record(ownerUserID: owner, shopID: Self.automaticShopID, eventID: 203)?.reason, .dirtyLocal)
    }

    @MainActor
    func testEventScanFindsBlockerBeyondFirstPageBeforeCurrentRowFetch() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333367")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777767")!
        let suiteName = "SyncEventHiddenFutureBlocker-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let events = [
            try syncEventRow(id: 300, ownerUserID: owner, domain: "catalog", changedCount: 1, entityIDsJSON: "{\"product_ids\":[\"\(productID.uuidString)\"]}"),
            try syncEventRow(id: 301, ownerUserID: owner, domain: "history", changedCount: 1, entityIDsJSON: "null"),
            try syncEventRow(id: 302, ownerUserID: owner, domain: "catalog", changedCount: 1, entityIDsJSON: "{\"product_ids\":[\"\(productID.uuidString)\"]}")
        ]
        let futureProduct = RemoteInventoryProductRow(id: productID, ownerUserID: owner, shopID: Self.automaticShopID, barcode: "FUTURE-STATE", itemNumber: nil, productName: "Event 302", secondProductName: nil, purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil, updatedAt: "2026-07-21T12:02:00Z", deletedAt: nil)
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: events, products: [futureProduct])
        let container = try makeContainer()

        let summary = try await SyncEventIncrementalDomainApplyService(eventFetcher: remote, remote: remote, defaults: defaults, limit: 1)
            .applyNextEvents(ownerUserID: owner, modelContainer: container, isAuthenticated: true)

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_missing_entity_ids")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(remote.catalogFetchCallCount, 0)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Product>()), 0)
    }

    @MainActor
    func testTailReadRejectsCurrentRowChangedAfterEventScan() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333370")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777770")!
        let suiteName = "SyncEventTailStability-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let firstEvent = try syncEventRow(id: 400, ownerUserID: owner, domain: "catalog", changedCount: 1, entityIDsJSON: "{\"product_ids\":[\"\(productID.uuidString)\"]}")
        let concurrentEvent = try syncEventRow(id: 401, ownerUserID: owner, domain: "catalog", changedCount: 1, entityIDsJSON: "{\"product_ids\":[\"\(productID.uuidString)\"]}")
        let oldRow = RemoteInventoryProductRow(id: productID, ownerUserID: owner, shopID: Self.automaticShopID, barcode: "TAIL-STABLE", itemNumber: nil, productName: "Old", secondProductName: nil, purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil, updatedAt: "2026-07-21T12:00:00Z", deletedAt: nil)
        let futureRow = RemoteInventoryProductRow(id: productID, ownerUserID: owner, shopID: Self.automaticShopID, barcode: "TAIL-STABLE", itemNumber: nil, productName: "Future", secondProductName: nil, purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil, updatedAt: "2026-07-21T12:01:00Z", deletedAt: nil)
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [firstEvent],
            products: [oldRow],
            eventInjectedOnFirstCatalogFetch: concurrentEvent,
            productsAfterFirstCatalogFetch: [futureRow]
        )
        let container = try makeContainer()

        let summary = try await SyncEventIncrementalDomainApplyService(eventFetcher: remote, remote: remote, defaults: defaults)
            .applyNextEvents(ownerUserID: owner, modelContainer: container, isAuthenticated: true)

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_page_changed_during_targeted_read")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Product>()), 0)
        XCTAssertNil(SyncEventApplyStatusStore(defaults: defaults).record(ownerUserID: owner, shopID: Self.automaticShopID, eventID: 400))
    }

    @MainActor
    func testFileBackedRollbackRestoresCatalogUpdatePriceInsertAndHistoryTombstone() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333371")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777771")!
        let existingPriceID = UUID(uuidString: "66666666-6666-4666-8666-666666666771")!
        let incomingPriceID = UUID(uuidString: "66666666-6666-4666-8666-666666666772")!
        let historyID = UUID(uuidString: "55555555-5555-4555-8555-555555555571")!
        let suiteName = "SyncEventFileRollback-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("task139-file-rollback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("active.store")
        let container = try SyncStoreSchema.makeFileBackedContainer(at: storeURL)
        do {
            let context = ModelContext(container)
            let product = Product(
                barcode: "ROLLBACK-UPDATE",
                remoteID: productID,
                remoteUpdatedAt: SupabaseRemoteDateParser.parse("2026-07-21T11:00:00Z"),
                productName: "Before"
            )
            context.insert(product)
            context.insert(ProductPrice(
                remoteID: existingPriceID,
                type: .retail,
                price: 1,
                effectiveAt: try date("2026-07-21T11:00:00Z"),
                source: "BEFORE",
                product: product
            ))
            context.insert(makeHistoryEntry(
                id: "rollback-history",
                uid: historyID,
                remoteID: historyID,
                owner: owner,
                shopID: Self.automaticShopID,
                storeID: Self.automaticShopID.uuidString.lowercased(),
                title: "Before history"
            ))
            try context.save()
        }
        let events = [
            try syncEventRow(id: 500, ownerUserID: owner, domain: "catalog", changedCount: 1, entityIDsJSON: "{\"product_ids\":[\"\(productID.uuidString)\"]}"),
            try syncEventRow(id: 501, ownerUserID: owner, domain: "prices", changedCount: 1, entityIDsJSON: "{\"price_ids\":[\"\(incomingPriceID.uuidString)\"],\"product_ids\":[\"\(productID.uuidString)\"]}"),
            try syncEventRow(id: 502, ownerUserID: owner, domain: "history", changedCount: 1, entityIDsJSON: "{\"session_ids\":[\"\(historyID.uuidString)\"]}")
        ]
        let remoteProduct = RemoteInventoryProductRow(id: productID, ownerUserID: owner, shopID: Self.automaticShopID, barcode: "ROLLBACK-UPDATE", itemNumber: nil, productName: "After", secondProductName: nil, purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil, updatedAt: "2026-07-21T12:00:00Z", deletedAt: nil)
        let remotePrice = RemoteInventoryProductPriceRow(id: incomingPriceID, ownerUserID: owner, shopID: Self.automaticShopID, productID: productID, type: "RETAIL", price: 2, effectiveAt: "2026-07-21T12:00:00Z", source: "AFTER", note: nil, createdAt: "2026-07-21T12:00:00Z", updatedAt: "2026-07-21T12:00:00Z")
        let remoteHistory = remoteHistoryRow(remoteID: historyID, owner: owner, title: "Before history", deletedAt: "2026-07-21T12:01:00Z")
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: events, products: [remoteProduct], productPrices: [remotePrice], historySessions: [remoteHistory])
        do {
            _ = try await SyncEventIncrementalDomainApplyService(
                eventFetcher: remote,
                remote: remote,
                defaults: defaults,
                atomicMutationProbeForTesting: { phase in
                    if case .afterMutationsBeforeCommit = phase {
                        throw AtomicProbeError.injectedBeforeCommit
                    }
                }
            ).applyNextEvents(
                ownerUserID: owner,
                modelContainer: container,
                isAuthenticated: true
            )
            XCTFail("Expected transaction rollback")
        } catch {
            XCTAssertEqual(error as? AtomicProbeError, .injectedBeforeCommit)
        }
        let reopened = try SyncStoreSchema.makeFileBackedContainer(at: storeURL)
        let read = ModelContext(reopened)
        let products = try read.fetch(FetchDescriptor<Product>())
        let prices = try read.fetch(FetchDescriptor<ProductPrice>())
        let history = try read.fetch(FetchDescriptor<HistoryEntry>())
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products.first?.productName, "Before")
        XCTAssertEqual(prices.count, 1)
        XCTAssertEqual(prices.first?.remoteID, existingPriceID)
        XCTAssertEqual(prices.first?.price, 1)
        XCTAssertEqual(history.count, 1)
        XCTAssertNil(history.first?.remoteDeletedAt)
        XCTAssertEqual(history.first?.title, "Before history")
        XCTAssertEqual(WatermarkStore(defaults: defaults).watermark(for: WatermarkStore.Scope(ownerUserID: owner, storeIdentity: LocalStoreIdentity(rawValue: Self.automaticShopID.uuidString.lowercased()))), 0)
    }

    @MainActor
    func testFileBackedMultiDomainCommitHoldsLeaseAcrossCatalogPriceHistory() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333372")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777772")!
        let priceID = UUID(uuidString: "66666666-6666-4666-8666-666666666773")!
        let historyID = UUID(uuidString: "55555555-5555-4555-8555-555555555572")!
        let suiteName = "SyncEventFileLease-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("task139-file-lease-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("active.store")
        let container = try SyncStoreSchema.makeFileBackedContainer(at: storeURL)
        let events = [
            try syncEventRow(id: 510, ownerUserID: owner, domain: "catalog", changedCount: 1, entityIDsJSON: "{\"product_ids\":[\"\(productID.uuidString)\"]}"),
            try syncEventRow(id: 511, ownerUserID: owner, domain: "prices", changedCount: 1, entityIDsJSON: "{\"price_ids\":[\"\(priceID.uuidString)\"],\"product_ids\":[\"\(productID.uuidString)\"]}"),
            try syncEventRow(id: 512, ownerUserID: owner, domain: "history", changedCount: 1, entityIDsJSON: "{\"session_ids\":[\"\(historyID.uuidString)\"]}")
        ]
        let remoteProduct = RemoteInventoryProductRow(id: productID, ownerUserID: owner, shopID: Self.automaticShopID, barcode: "LEASE-COMMIT", itemNumber: nil, productName: "Committed", secondProductName: nil, purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil, updatedAt: "2026-07-21T12:00:00Z", deletedAt: nil)
        let remotePrice = RemoteInventoryProductPriceRow(id: priceID, ownerUserID: owner, shopID: Self.automaticShopID, productID: productID, type: "RETAIL", price: 3, effectiveAt: "2026-07-21T12:00:00Z", source: "REMOTE", note: nil, createdAt: "2026-07-21T12:00:00Z", updatedAt: "2026-07-21T12:00:00Z")
        let remoteHistory = remoteHistoryRow(remoteID: historyID, owner: owner, title: "Committed history")
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: events, products: [remoteProduct], productPrices: [remotePrice], historySessions: [remoteHistory])
        let afterCatalog = expectation(description: "catalog mutation reached")
        let releaseCommit = DispatchSemaphore(value: 0)
        let invalidationAttempted = expectation(description: "lease invalidation attempted")
        let invalidationFinished = expectation(description: "lease invalidation finished")
        let invalidationFinishedSignal = DispatchSemaphore(value: 0)
        let invalidationFinishedForHook = DispatchSemaphore(value: 0)
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults,
            atomicMutationProbeForTesting: { phase in
                if case .afterCatalog = phase {
                    afterCatalog.fulfill()
                    guard releaseCommit.wait(timeout: .now() + 5) == .success else {
                        throw AtomicProbeError.timedOut
                    }
                }
            },
            afterAtomicMutationForTesting: {
                guard await SyncEventTestAsyncWait.wait(
                    invalidationFinishedForHook,
                    timeout: 5
                ) else {
                    throw AtomicProbeError.timedOut
                }
            }
        )
        let applyTask = Task.detached {
            try await service.applyNextEvents(
                ownerUserID: owner,
                modelContainer: container,
                isAuthenticated: true
            )
        }
        await fulfillment(of: [afterCatalog], timeout: 5)
        let invalidationThread = Thread {
            invalidationAttempted.fulfill()
            Task126OwnerStoreGate.invalidateAutomaticScopeLease()
            invalidationFinishedSignal.signal()
            invalidationFinishedForHook.signal()
            invalidationFinished.fulfill()
        }
        invalidationThread.start()
        await fulfillment(of: [invalidationAttempted], timeout: 5)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(invalidationFinishedSignal.wait(timeout: .now()), .timedOut)
        releaseCommit.signal()
        do {
            _ = try await applyTask.value
            XCTFail("Expected stale scope after durable commit")
        } catch {
            XCTAssertEqual(error as? Task126OwnerStoreGateError, .scopeChanged)
        }
        await fulfillment(of: [invalidationFinished], timeout: 5)
        let reopened = try SyncStoreSchema.makeFileBackedContainer(at: storeURL)
        let read = ModelContext(reopened)
        XCTAssertEqual(try read.fetchCount(FetchDescriptor<Product>()), 1)
        XCTAssertEqual(try read.fetchCount(FetchDescriptor<ProductPrice>()), 1)
        XCTAssertEqual(try read.fetchCount(FetchDescriptor<HistoryEntry>()), 1)
        XCTAssertEqual(WatermarkStore(defaults: defaults).watermark(for: WatermarkStore.Scope(ownerUserID: owner, storeIdentity: LocalStoreIdentity(rawValue: Self.automaticShopID.uuidString.lowercased()))), 0)
        let statuses = SyncEventApplyStatusStore(defaults: defaults)
        XCTAssertNil(statuses.record(ownerUserID: owner, shopID: Self.automaticShopID, eventID: 510))
        XCTAssertNil(statuses.record(ownerUserID: owner, shopID: Self.automaticShopID, eventID: 511))
        XCTAssertNil(statuses.record(ownerUserID: owner, shopID: Self.automaticShopID, eventID: 512))
    }

    @MainActor
    func testFileBackedLocalWriterWaitsForIncrementalCommitAndPersistsPending() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333383")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777784")!
        let suiteName = "SyncEventFileLocalWriterFence-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("task139-file-local-writer-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appendingPathComponent("active.store")
        let writerError = SyncEventThreadSafeErrorBox()
        let afterCatalog = expectation(description: "incremental catalog mutation reached")
        let releaseIncrementalCommit = DispatchSemaphore(value: 0)
        let writerPrepared = expectation(description: "local writer preloaded old generation")
        let startWriter = DispatchSemaphore(value: 0)
        let writerAttempted = expectation(description: "local writer attempted")
        let writerFinished = expectation(description: "local writer finished")
        let writerFinishedSignal = DispatchSemaphore(value: 0)

        do {
            let container = try SyncStoreSchema.makeFileBackedContainer(at: storeURL)
            let seed = ModelContext(container)
            seed.autosaveEnabled = false
            seed.insert(Product(
                barcode: "LOCAL-WRITER-FENCE",
                remoteID: productID,
                remoteUpdatedAt: try date("2026-07-21T11:00:00Z"),
                productName: "Before"
            ))
            try seed.save()
            let event = try syncEventRow(
                id: 513,
                ownerUserID: owner,
                domain: "catalog",
                changedCount: 1,
                entityIDsJSON: "{\"product_ids\":[\"\(productID.uuidString)\"]}"
            )
            let remote = SyncEventIncrementalDomainApplyRemoteFake(
                events: [event],
                products: [RemoteInventoryProductRow(
                    id: productID,
                    ownerUserID: owner,
                    shopID: Self.automaticShopID,
                    barcode: "LOCAL-WRITER-FENCE",
                    itemNumber: nil,
                    productName: "Remote committed",
                    secondProductName: nil,
                    purchasePrice: nil,
                    retailPrice: nil,
                    supplierID: nil,
                    categoryID: nil,
                    stockQuantity: nil,
                    updatedAt: "2026-07-21T12:00:00Z",
                    deletedAt: nil
                )]
            )
            let service = SyncEventIncrementalDomainApplyService(
                eventFetcher: remote,
                remote: remote,
                defaults: defaults,
                atomicMutationProbeForTesting: { phase in
                    if case .afterCatalog = phase {
                        afterCatalog.fulfill()
                        guard releaseIncrementalCommit.wait(timeout: .now() + 5) == .success else {
                            throw AtomicProbeError.timedOut
                        }
                    }
                }
            )
            let writerThread = Thread {
                defer {
                    writerFinishedSignal.signal()
                    writerFinished.fulfill()
                }
                do {
                    let writerContext = ModelContext(container)
                    writerContext.autosaveEnabled = false
                    // Deliberately materialize G-current before the remote
                    // commit. The production fence must not reuse this stale
                    // identity-map object after it acquires the lease.
                    guard try writerContext
                        .fetch(FetchDescriptor<Product>())
                        .contains(where: { $0.remoteID == productID }) else {
                        throw AtomicProbeError.missingFixture
                    }
                    writerPrepared.fulfill()
                    guard startWriter.wait(timeout: .now() + 5) == .success else {
                        throw AtomicProbeError.timedOut
                    }
                    writerAttempted.fulfill()
                    try Task126OwnerStoreGate.withLocalMutationFence(
                        modelContainer: container,
                        ownerUserID: owner,
                        defaults: defaults
                    ) { freshContext in
                        guard let product = try freshContext
                            .fetch(FetchDescriptor<Product>())
                            .first(where: { $0.remoteID == productID }) else {
                            throw AtomicProbeError.missingFixture
                        }
                        let baselineHash = LocalPendingChangeLogicalKey
                            .productFingerprintHash(product)
                        product.productName = "Local after remote"
                        try LocalPendingChangeAccumulator(
                            context: freshContext,
                            ownerUserID: owner,
                            storeIdentity: LocalStoreIdentity(
                                rawValue: Self.automaticShopID.uuidString.lowercased()
                            )
                        ).recordProductChange(
                            product: product,
                            operation: .update,
                            origin: .manualCatalogSave,
                            changedFields: ["productName"],
                            baselineFingerprintHash: baselineHash
                        )
                        try freshContext.save()
                    }
                } catch {
                    writerError.store(error)
                }
            }
            writerThread.start()
            await fulfillment(of: [writerPrepared], timeout: 5)
            let applyTask = Task.detached {
                try await service.applyNextEvents(
                    ownerUserID: owner,
                    modelContainer: container,
                    isAuthenticated: true
                )
            }
            await fulfillment(of: [afterCatalog], timeout: 5)
            startWriter.signal()
            await fulfillment(of: [writerAttempted], timeout: 5)
            try await Task.sleep(for: .milliseconds(250))
            XCTAssertEqual(writerFinishedSignal.wait(timeout: .now()), .timedOut)

            releaseIncrementalCommit.signal()
            let summary = try await applyTask.value
            XCTAssertEqual(summary.totalApplied, 1)
            XCTAssertEqual(summary.watermarkAfter, 513)
            await fulfillment(of: [writerFinished], timeout: 5)
            XCTAssertNil(writerError.error)
        }

        do {
            let reopened = try SyncStoreSchema.makeFileBackedContainer(at: storeURL)
            let read = ModelContext(reopened)
            let product = try XCTUnwrap(read.fetch(FetchDescriptor<Product>()).first)
            let pending = try read.fetch(FetchDescriptor<LocalPendingChange>())
            XCTAssertEqual(product.remoteID, productID)
            XCTAssertEqual(product.productName, "Local after remote")
            XCTAssertEqual(
                product.remoteUpdatedAt,
                try date("2026-07-21T12:00:00Z")
            )
            XCTAssertNil(product.remoteDeletedAt)
            XCTAssertEqual(pending.count, 1)
            XCTAssertEqual(pending.first?.ownerUserID, owner.uuidString.lowercased())
            XCTAssertEqual(pending.first?.entityRemoteID, productID)
        }
        XCTAssertEqual(
            WatermarkStore(defaults: defaults).watermark(
                for: WatermarkStore.Scope(
                    ownerUserID: owner,
                    storeIdentity: LocalStoreIdentity(
                        rawValue: Self.automaticShopID.uuidString.lowercased()
                    )
                )
            ),
            513
        )
        XCTAssertEqual(
            SyncEventApplyStatusStore(defaults: defaults).record(
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                eventID: 513
            )?.status,
            .applied
        )
        try FileManager.default.removeItem(at: directory)
    }

    @MainActor
    func testSupplierAndCategoryTombstonesDetachUnchangedProductAtomically() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333373")!
        let supplierID = UUID(uuidString: "44444444-4444-4444-8444-444444444473")!
        let categoryID = UUID(uuidString: "55555555-5555-4555-8555-555555555573")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777773")!
        let suiteName = "SyncEventRelationTombstone-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let seed = ModelContext(container)
        let supplier = Supplier(name: "Relation supplier", remoteID: supplierID)
        let category = ProductCategory(name: "Relation category", remoteID: categoryID)
        seed.insert(supplier)
        seed.insert(category)
        seed.insert(Product(
            barcode: "RELATION-TOMBSTONE",
            remoteID: productID,
            supplier: supplier,
            category: category
        ))
        try seed.save()
        let event = try syncEventRow(
            id: 520,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 2,
            entityIDsJSON: "{\"supplier_ids\":[\"\(supplierID.uuidString)\"],\"category_ids\":[\"\(categoryID.uuidString)\"]}"
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            suppliers: [RemoteInventorySupplierRow(
                id: supplierID,
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                name: "Relation supplier",
                updatedAt: "2026-07-21T12:00:00Z",
                deletedAt: "2026-07-21T12:01:00Z"
            )],
            categories: [RemoteInventoryCategoryRow(
                id: categoryID,
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                name: "Relation category",
                updatedAt: "2026-07-21T12:00:00Z",
                deletedAt: "2026-07-21T12:01:00Z"
            )]
        )

        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        ).applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        let read = ModelContext(container)
        let storedProduct = try XCTUnwrap(read.fetch(FetchDescriptor<Product>()).first)
        XCTAssertNil(storedProduct.supplier)
        XCTAssertNil(storedProduct.category)
        XCTAssertNotNil(try XCTUnwrap(read.fetch(FetchDescriptor<Supplier>()).first).remoteDeletedAt)
        XCTAssertNotNil(try XCTUnwrap(read.fetch(FetchDescriptor<ProductCategory>()).first).remoteDeletedAt)
        XCTAssertEqual(summary.suppliersUpdated, 1)
        XCTAssertEqual(summary.categoriesUpdated, 1)
        XCTAssertEqual(summary.watermarkAfter, 520)
    }

    @MainActor
    func testSupplierAndCategoryTombstoneRollbackPreservesProductRelations() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333374")!
        let supplierID = UUID(uuidString: "44444444-4444-4444-8444-444444444474")!
        let categoryID = UUID(uuidString: "55555555-5555-4555-8555-555555555574")!
        let suiteName = "SyncEventRelationRollback-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("task139-relation-rollback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let container = try SyncStoreSchema.makeFileBackedContainer(
            at: directory.appendingPathComponent("active.store")
        )
        let seed = ModelContext(container)
        let supplier = Supplier(name: "Rollback supplier", remoteID: supplierID)
        let category = ProductCategory(name: "Rollback category", remoteID: categoryID)
        seed.insert(supplier)
        seed.insert(category)
        seed.insert(Product(
            barcode: "RELATION-ROLLBACK",
            remoteID: UUID(uuidString: "77777777-7777-4777-8777-777777777774")!,
            supplier: supplier,
            category: category
        ))
        try seed.save()
        let event = try syncEventRow(
            id: 521,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 2,
            entityIDsJSON: "{\"supplier_ids\":[\"\(supplierID.uuidString)\"],\"category_ids\":[\"\(categoryID.uuidString)\"]}"
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            suppliers: [RemoteInventorySupplierRow(
                id: supplierID,
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                name: "Rollback supplier",
                updatedAt: "2026-07-21T12:00:00Z",
                deletedAt: "2026-07-21T12:01:00Z"
            )],
            categories: [RemoteInventoryCategoryRow(
                id: categoryID,
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                name: "Rollback category",
                updatedAt: "2026-07-21T12:00:00Z",
                deletedAt: "2026-07-21T12:01:00Z"
            )]
        )
        do {
            _ = try await SyncEventIncrementalDomainApplyService(
                eventFetcher: remote,
                remote: remote,
                defaults: defaults,
                atomicMutationProbeForTesting: { phase in
                    if case .afterCatalog = phase {
                        throw AtomicProbeError.injectedBeforeCommit
                    }
                }
            ).applyNextEvents(
                ownerUserID: owner,
                modelContainer: container,
                isAuthenticated: true
            )
            XCTFail("Expected relation rollback")
        } catch {
            XCTAssertEqual(error as? AtomicProbeError, .injectedBeforeCommit)
        }

        let read = ModelContext(container)
        let storedProduct = try XCTUnwrap(read.fetch(FetchDescriptor<Product>()).first)
        XCTAssertEqual(storedProduct.supplier?.remoteID, supplierID)
        XCTAssertEqual(storedProduct.category?.remoteID, categoryID)
        XCTAssertNil(try XCTUnwrap(read.fetch(FetchDescriptor<Supplier>()).first).remoteDeletedAt)
        XCTAssertNil(try XCTUnwrap(read.fetch(FetchDescriptor<ProductCategory>()).first).remoteDeletedAt)
        XCTAssertEqual(WatermarkStore(defaults: defaults).watermark(
            for: WatermarkStore.Scope(
                ownerUserID: owner,
                storeIdentity: LocalStoreIdentity(rawValue: Self.automaticShopID.uuidString.lowercased())
            )
        ), 0)
    }

    @MainActor
    func testLookupTombstonesBlockProductPendingDependency() async throws {
        try await assertLookupTombstonesBlockProductPendingDependency(createdLate: false)
    }

    @MainActor
    func testLookupTombstonesBlockLateProductPendingDependency() async throws {
        try await assertLookupTombstonesBlockProductPendingDependency(createdLate: true)
    }

    @MainActor
    func testProductTombstoneBlocksChildPricePendingDependency() async throws {
        try await assertProductTombstoneBlocksChildPricePendingDependency(createdLate: false)
    }

    @MainActor
    func testProductTombstoneBlocksLateChildPricePendingDependency() async throws {
        try await assertProductTombstoneBlocksChildPricePendingDependency(createdLate: true)
    }

    @MainActor
    func testActiveProductUpdateDoesNotBlockOnPendingChildPrice() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333381")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777781")!
        let priceID = UUID(uuidString: "66666666-6666-4666-8666-666666666681")!
        let suiteName = "SyncEventActiveProductPendingPrice-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let seed = ModelContext(container)
        let product = Product(
            barcode: "ACTIVE-PENDING-PRICE",
            remoteID: productID,
            productName: "Before"
        )
        seed.insert(product)
        seed.insert(ProductPrice(
            remoteID: priceID,
            type: .retail,
            price: 9,
            effectiveAt: try date("2026-07-21T11:00:00Z"),
            product: product
        ))
        seed.insert(LocalPendingChange(
            ownerUserID: owner,
            entityKind: .productPrice,
            operation: .update,
            origin: .productPriceSave,
            logicalKey: LocalPendingChangeLogicalKey.remoteEntity(
                kind: .productPrice,
                remoteID: priceID
            ),
            entityRemoteID: priceID
        ))
        try seed.save()
        let event = try syncEventRow(
            id: 528,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 1,
            entityIDsJSON: "{\"product_ids\":[\"\(productID.uuidString)\"]}"
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            products: [RemoteInventoryProductRow(
                id: productID,
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                barcode: "ACTIVE-PENDING-PRICE",
                itemNumber: nil,
                productName: "After",
                secondProductName: nil,
                purchasePrice: nil,
                retailPrice: nil,
                supplierID: nil,
                categoryID: nil,
                stockQuantity: nil,
                updatedAt: "2026-07-21T12:00:00Z",
                deletedAt: nil
            )]
        )

        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        ).applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        let read = ModelContext(container)
        XCTAssertNil(summary.requiresFullRecoveryReason)
        XCTAssertEqual(summary.watermarkAfter, 528)
        XCTAssertEqual(summary.totalApplied, 1)
        XCTAssertEqual(try XCTUnwrap(read.fetch(FetchDescriptor<Product>()).first).productName, "After")
        XCTAssertEqual(try read.fetchCount(FetchDescriptor<ProductPrice>()), 1)
        XCTAssertEqual(try read.fetchCount(FetchDescriptor<LocalPendingChange>()), 1)
    }

    @MainActor
    func testProductTombstoneDoesNotBlockOnReusedBarcodePendingPrice() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333382")!
        let tombstoneProductID = UUID(uuidString: "77777777-7777-4777-8777-777777777782")!
        let reusedProductID = UUID(uuidString: "77777777-7777-4777-8777-777777777783")!
        let priceID = UUID(uuidString: "66666666-6666-4666-8666-666666666682")!
        let suiteName = "SyncEventTombstoneReusedBarcodePendingPrice-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let seed = ModelContext(container)
        let reusedProduct = Product(
            barcode: "REUSED-TOMBSTONE-BARCODE",
            remoteID: reusedProductID,
            productName: "Current product"
        )
        seed.insert(reusedProduct)
        seed.insert(ProductPrice(
            remoteID: priceID,
            type: .retail,
            price: 11,
            effectiveAt: try date("2026-07-21T11:00:00Z"),
            product: reusedProduct
        ))
        seed.insert(LocalPendingChange(
            ownerUserID: owner,
            entityKind: .productPrice,
            operation: .update,
            origin: .productPriceSave,
            logicalKey: LocalPendingChangeLogicalKey.remoteEntity(
                kind: .productPrice,
                remoteID: priceID
            ),
            entityRemoteID: priceID
        ))
        try seed.save()
        let event = try syncEventRow(
            id: 529,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 1,
            entityIDsJSON: "{\"product_ids\":[\"\(tombstoneProductID.uuidString)\"]}"
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            products: [RemoteInventoryProductRow(
                id: tombstoneProductID,
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                barcode: "REUSED-TOMBSTONE-BARCODE",
                itemNumber: nil,
                productName: "Deleted predecessor",
                secondProductName: nil,
                purchasePrice: nil,
                retailPrice: nil,
                supplierID: nil,
                categoryID: nil,
                stockQuantity: nil,
                updatedAt: "2026-07-21T12:00:00Z",
                deletedAt: "2026-07-21T12:01:00Z"
            )]
        )

        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        ).applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        let read = ModelContext(container)
        let persistedProduct = try XCTUnwrap(read.fetch(FetchDescriptor<Product>()).first)
        XCTAssertNil(summary.requiresFullRecoveryReason)
        XCTAssertEqual(summary.watermarkAfter, 529)
        XCTAssertEqual(summary.totalApplied, 0)
        XCTAssertEqual(persistedProduct.remoteID, reusedProductID)
        XCTAssertNil(persistedProduct.remoteDeletedAt)
        XCTAssertEqual(try read.fetchCount(FetchDescriptor<ProductPrice>()), 1)
        XCTAssertEqual(try read.fetchCount(FetchDescriptor<LocalPendingChange>()), 1)
    }

    @MainActor
    func testTargetedHistoryResourceBudgetRequestsDurableRecoveryWithoutMutation() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333375")!
        let sessionID = UUID(uuidString: "55555555-5555-4555-8555-555555555575")!
        let suiteName = "SyncEventHistoryBudget-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let event = try syncEventRow(
            id: 522,
            ownerUserID: owner,
            domain: "history",
            changedCount: 1,
            entityIDsJSON: "{\"session_ids\":[\"\(sessionID.uuidString)\"]}"
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            historyFetchError: .resourceBudgetExceeded(domain: .history)
        )

        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        ).applyNextEvents(
            ownerUserID: owner,
            modelContainer: try makeContainer(),
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_history_resource_budget_exceeded")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(summary.totalApplied, 0)
        XCTAssertEqual(remote.historyFetchCallCount, 1)
        XCTAssertNil(SyncEventApplyStatusStore(defaults: defaults).record(
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            eventID: 522
        ))
    }

    @MainActor
    func testOverfullEventPageRequestsRecoveryWithoutTargetedReads() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333376")!
        let suiteName = "SyncEventOverfullPage-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let events = [
            try syncEventRow(id: 523, ownerUserID: owner, domain: "catalog", changedCount: 0, entityIDsJSON: "{}"),
            try syncEventRow(id: 524, ownerUserID: owner, domain: "catalog", changedCount: 0, entityIDsJSON: "{}")
        ]
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: events,
            returnsOverfullEventPage: true
        )

        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults,
            limit: 1
        ).applyNextEvents(
            ownerUserID: owner,
            modelContainer: try makeContainer(),
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_scan_page_budget_exceeded")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(remote.catalogFetchCallCount, 0)
        XCTAssertEqual(remote.productPriceFetchCallCount, 0)
        XCTAssertEqual(remote.historyFetchCallCount, 0)
    }

    @MainActor
    func testInitialEventPageResourceBudgetRequestsRecovery() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333377")!
        let suiteName = "SyncEventInitialBudget-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [],
            eventFetchError: .totalResourceBudgetExceeded,
            eventFetchErrorAfterID: 0
        )

        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        ).applyNextEvents(
            ownerUserID: owner,
            modelContainer: try makeContainer(),
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_total_resource_budget_exceeded")
        XCTAssertEqual(summary.eventsFetched, 0)
        XCTAssertEqual(summary.watermarkAfter, 0)
    }

    @MainActor
    func testStabilityTailResourceBudgetRequestsRecoveryBeforeMutation() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333378")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777778")!
        let suiteName = "SyncEventTailBudget-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let event = try syncEventRow(
            id: 525,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 1,
            entityIDsJSON: "{\"product_ids\":[\"\(productID.uuidString)\"]}"
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            products: [RemoteInventoryProductRow(
                id: productID,
                ownerUserID: owner,
                shopID: Self.automaticShopID,
                barcode: "TAIL-BUDGET",
                itemNumber: nil,
                productName: "Tail budget",
                secondProductName: nil,
                purchasePrice: nil,
                retailPrice: nil,
                supplierID: nil,
                categoryID: nil,
                stockQuantity: nil,
                updatedAt: "2026-07-21T12:00:00Z",
                deletedAt: nil
            )],
            eventFetchError: .totalResourceBudgetExceeded,
            eventFetchErrorAfterID: 525
        )
        let container = try makeContainer()

        let summary = try await SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        ).applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_total_resource_budget_exceeded")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Product>()), 0)
        XCTAssertEqual(remote.catalogFetchCallCount, 2)
    }

    @MainActor
    func testUnauthenticatedApplyPerformsZeroRemoteAndLocalWork() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333368")!
        let suiteName = "SyncEventUnauthenticated-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: [])
        let container = try makeContainer()

        do {
            _ = try await SyncEventIncrementalDomainApplyService(eventFetcher: remote, remote: remote, defaults: defaults)
                .applyNextEvents(ownerUserID: owner, modelContainer: container, isAuthenticated: false)
            XCTFail("Expected authentication gate")
        } catch {
            XCTAssertEqual(error as? Task126OwnerStoreGateError, .activeAccountMismatch)
        }
        XCTAssertTrue(remote.fetchedAfterIDs.isEmpty)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<Product>()), 0)
    }

    @MainActor
    private func assertLookupTombstonesBlockProductPendingDependency(
        createdLate: Bool
    ) async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333379")!
        let supplierID = UUID(uuidString: "44444444-4444-4444-8444-444444444479")!
        let categoryID = UUID(uuidString: "55555555-5555-4555-8555-555555555579")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777779")!
        let suiteName = "SyncEventLookupPending-\(createdLate)-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let seed = ModelContext(container)
        let supplier = Supplier(name: "Pending relation supplier", remoteID: supplierID)
        let category = ProductCategory(name: "Pending relation category", remoteID: categoryID)
        seed.insert(supplier)
        seed.insert(category)
        seed.insert(Product(
            barcode: "PENDING-RELATION",
            remoteID: productID,
            supplier: supplier,
            category: category
        ))
        if !createdLate {
            seed.insert(LocalPendingChange(
                ownerUserID: owner,
                entityKind: .product,
                operation: .update,
                origin: .manualCatalogSave,
                logicalKey: LocalPendingChangeLogicalKey.remoteEntity(
                    kind: .product,
                    remoteID: productID
                ),
                entityRemoteID: productID
            ))
        }
        try seed.save()
        let event = try syncEventRow(
            id: 526,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 2,
            entityIDsJSON: "{\"supplier_ids\":[\"\(supplierID.uuidString)\"],\"category_ids\":[\"\(categoryID.uuidString)\"]}"
        )
        let remoteSupplier = RemoteInventorySupplierRow(
            id: supplierID,
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            name: "Pending relation supplier",
            updatedAt: "2026-07-21T12:00:00Z",
            deletedAt: "2026-07-21T12:01:00Z"
        )
        let remoteCategory = RemoteInventoryCategoryRow(
            id: categoryID,
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            name: "Pending relation category",
            updatedAt: "2026-07-21T12:00:00Z",
            deletedAt: "2026-07-21T12:01:00Z"
        )
        let beforeAtomicMutation: (@Sendable () async throws -> Void)?
        if createdLate {
            beforeAtomicMutation = {
                try await MainActor.run {
                    let late = ModelContext(container)
                    late.insert(LocalPendingChange(
                        ownerUserID: owner,
                        entityKind: .product,
                        operation: .update,
                        origin: .manualCatalogSave,
                        logicalKey: LocalPendingChangeLogicalKey.remoteEntity(
                            kind: .product,
                            remoteID: productID
                        ),
                        entityRemoteID: productID
                    ))
                    try late.save()
                }
            }
        } else {
            beforeAtomicMutation = nil
        }
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            suppliers: [remoteSupplier],
            categories: [remoteCategory]
        )
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults,
            beforeAtomicMutationForTesting: beforeAtomicMutation
        )

        let summary = try await service.applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        let read = ModelContext(container)
        let product = try XCTUnwrap(read.fetch(FetchDescriptor<Product>()).first)
        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_dirty_local")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(summary.totalApplied, 0)
        XCTAssertEqual(product.supplier?.remoteID, supplierID)
        XCTAssertEqual(product.category?.remoteID, categoryID)
        XCTAssertNil(try XCTUnwrap(read.fetch(FetchDescriptor<Supplier>()).first).remoteDeletedAt)
        XCTAssertNil(try XCTUnwrap(read.fetch(FetchDescriptor<ProductCategory>()).first).remoteDeletedAt)
    }

    @MainActor
    private func assertProductTombstoneBlocksChildPricePendingDependency(
        createdLate: Bool
    ) async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333380")!
        let productID = UUID(uuidString: "77777777-7777-4777-8777-777777777780")!
        let priceID = UUID(uuidString: "66666666-6666-4666-8666-666666666680")!
        let suiteName = "SyncEventChildPricePending-\(createdLate)-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        try configureAutomaticScope(ownerUserID: owner, defaults: defaults)
        let container = try makeContainer()
        let seed = ModelContext(container)
        let product = Product(barcode: "PENDING-PRICE-PARENT", remoteID: productID)
        seed.insert(product)
        seed.insert(ProductPrice(
            remoteID: priceID,
            type: .retail,
            price: 9,
            effectiveAt: try date("2026-07-21T11:00:00Z"),
            product: product
        ))
        if !createdLate {
            seed.insert(LocalPendingChange(
                ownerUserID: owner,
                entityKind: .productPrice,
                operation: .update,
                origin: .productPriceSave,
                logicalKey: LocalPendingChangeLogicalKey.remoteEntity(
                    kind: .productPrice,
                    remoteID: priceID
                ),
                entityRemoteID: priceID
            ))
        }
        try seed.save()
        let event = try syncEventRow(
            id: 527,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 1,
            entityIDsJSON: "{\"product_ids\":[\"\(productID.uuidString)\"]}"
        )
        let remoteProduct = RemoteInventoryProductRow(
            id: productID,
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            barcode: "PENDING-PRICE-PARENT",
            itemNumber: nil,
            productName: nil,
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            updatedAt: "2026-07-21T12:00:00Z",
            deletedAt: "2026-07-21T12:01:00Z"
        )
        let beforeAtomicMutation: (@Sendable () async throws -> Void)?
        if createdLate {
            beforeAtomicMutation = {
                try await MainActor.run {
                    let late = ModelContext(container)
                    late.insert(LocalPendingChange(
                        ownerUserID: owner,
                        entityKind: .productPrice,
                        operation: .update,
                        origin: .productPriceSave,
                        logicalKey: LocalPendingChangeLogicalKey.remoteEntity(
                            kind: .productPrice,
                            remoteID: priceID
                        ),
                        entityRemoteID: priceID
                    ))
                    try late.save()
                }
            }
        } else {
            beforeAtomicMutation = nil
        }
        let remote = SyncEventIncrementalDomainApplyRemoteFake(
            events: [event],
            products: [remoteProduct]
        )
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults,
            beforeAtomicMutationForTesting: beforeAtomicMutation
        )

        let summary = try await service.applyNextEvents(
            ownerUserID: owner,
            modelContainer: container,
            isAuthenticated: true
        )

        let read = ModelContext(container)
        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_dirty_local")
        XCTAssertEqual(summary.watermarkAfter, 0)
        XCTAssertEqual(summary.totalApplied, 0)
        XCTAssertNil(try XCTUnwrap(read.fetch(FetchDescriptor<Product>()).first).remoteDeletedAt)
        XCTAssertEqual(try read.fetchCount(FetchDescriptor<ProductPrice>()), 1)
    }

    private func makeHistoryEntry(
        id: String,
        uid: UUID,
        remoteID: UUID?,
        owner: UUID,
        shopID: UUID?,
        storeID: String?,
        title: String
    ) -> HistoryEntry {
        let entry = HistoryEntry(
            id: id,
            timestamp: SupabaseRemoteDateParser.parse("2026-07-21T12:00:00Z")!,
            data: [["item"]],
            supplier: "",
            category: "",
            syncStatus: .syncedSuccessfully,
            uid: uid,
            remoteID: remoteID,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse("2026-07-21T12:00:00Z"),
            ownerUserID: owner.uuidString.lowercased(),
            storeID: storeID,
            shopID: shopID
        )
        entry.title = title
        return entry
    }

    private func remoteHistoryRow(
        remoteID: UUID,
        owner: UUID,
        title: String,
        deletedAt: String? = nil
    ) -> RemoteSharedSheetSessionRow {
        RemoteSharedSheetSessionRow(
            remoteID: remoteID,
            payloadVersion: 2,
            displayName: title,
            timestamp: "2026-07-21T12:00:00Z",
            supplier: "",
            category: "",
            isManualEntry: false,
            data: [["item"]],
            sessionOverlay: nil,
            ownerUserID: owner,
            shopID: Self.automaticShopID,
            updatedAt: "2026-07-21T12:00:00Z",
            deletedAt: deletedAt
        )
    }

    private func syncEventRow(
        id: Int64,
        ownerUserID: UUID,
        domain: String,
        changedCount: Int,
        shopID: UUID? = nil,
        entityIDsJSON: String
    ) throws -> RemoteSyncEventRow {
        try syncEventRow(
            id: id,
            ownerUserID: ownerUserID,
            domain: domain,
            changedCount: changedCount,
            sourceDeviceID: "android-test",
            shopID: shopID,
            entityIDsJSON: entityIDsJSON
        )
    }

    private func syncEventRow(
        id: Int64,
        ownerUserID: UUID,
        domain: String,
        changedCount: Int,
        sourceDeviceID: String,
        redactedSourceDevice: Bool = false,
        requiresFullRecovery: Bool = false,
        shopID: UUID? = nil,
        entityIDsJSON: String
    ) throws -> RemoteSyncEventRow {
        let resolvedShopID = shopID ?? Self.automaticShopID
        let shopIDJSON = "\"\(resolvedShopID.uuidString)\""
        let sourceDeviceJSON = redactedSourceDevice
            ? "\"source_device_id\": null, \"source_device_key\": \"\(ShopSyncRecoveryCanonical.sha256(sourceDeviceID))\""
            : "\"source_device_id\": \"\(sourceDeviceID)\""
        let json = """
        {
          "id": "\(id)",
          "owner_user_id": "\(ownerUserID.uuidString)",
          "store_id": null,
          "shop_id": \(shopIDJSON),
          "domain": "\(domain)",
          "event_type": "test",
          "source": "test",
          \(sourceDeviceJSON),
          "batch_id": null,
          "client_event_id": "TASK123-\(id)",
          "changed_count": \(changedCount),
          "entity_ids": \(entityIDsJSON),
          "requires_full_recovery": \(requiresFullRecovery),
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

    private func configureAutomaticScope(
        ownerUserID: UUID,
        defaults: UserDefaults
    ) throws {
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        let selectedShop = SelectedShop(
            shopID: Self.automaticShopID,
            code: "TASK139",
            name: "TASK139 incremental fixture shop",
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true
        )
        let selectedStore = SelectedShopStore(defaults: defaults)
        selectedStore.noteActiveAccount(accountHash)
        XCTAssertTrue(selectedStore.save(selectedShop, accountHash: accountHash))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(
            accountHash: accountHash,
            storeIdentity: selectedShop.localStoreIdentity
        ))
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

private final class SyncEventThreadSafeErrorBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedError: Error?

    var error: Error? {
        lock.lock()
        defer { lock.unlock() }
        return storedError
    }

    func store(_ error: Error) {
        lock.lock()
        storedError = error
        lock.unlock()
    }
}

private nonisolated enum SyncEventTestAsyncWait {
    static func wait(_ semaphore: DispatchSemaphore, timeout: TimeInterval) async -> Bool {
        await Task.detached {
            semaphore.wait(timeout: .now() + timeout) == .success
        }.value
    }
}

@MainActor
private final class SyncEventIncrementalDomainApplyRemoteFake: SyncAutomaticIncrementalRemote, @unchecked Sendable {
    private var events: [RemoteSyncEventRow]
    private let suppliers: [RemoteInventorySupplierRow]
    private let categories: [RemoteInventoryCategoryRow]
    private var products: [RemoteInventoryProductRow]
    private let productPrices: [RemoteInventoryProductPriceRow]
    private let historySessions: [RemoteSharedSheetSessionRow]
    private let eventInjectedOnFirstCatalogFetch: RemoteSyncEventRow?
    private let productsAfterFirstCatalogFetch: [RemoteInventoryProductRow]?
    private let historyFetchError: ShopSyncRecoveryContractError?
    private let returnsOverfullEventPage: Bool
    private let eventFetchError: ShopSyncRecoveryContractError?
    private let eventFetchErrorAfterID: Int64?
    private(set) var catalogFetchCallCount = 0
    private(set) var productPriceFetchCallCount = 0
    private(set) var historyFetchCallCount = 0
    private(set) var fetchedAfterIDs: [Int64] = []
    private(set) var reconciliationCallCount = 0

    init(
        events: [RemoteSyncEventRow],
        suppliers: [RemoteInventorySupplierRow] = [],
        categories: [RemoteInventoryCategoryRow] = [],
        products: [RemoteInventoryProductRow] = [],
        productPrices: [RemoteInventoryProductPriceRow] = [],
        historySessions: [RemoteSharedSheetSessionRow] = [],
        eventInjectedOnFirstCatalogFetch: RemoteSyncEventRow? = nil,
        productsAfterFirstCatalogFetch: [RemoteInventoryProductRow]? = nil,
        historyFetchError: ShopSyncRecoveryContractError? = nil,
        returnsOverfullEventPage: Bool = false,
        eventFetchError: ShopSyncRecoveryContractError? = nil,
        eventFetchErrorAfterID: Int64? = nil
    ) {
        self.events = events
        self.suppliers = suppliers
        self.categories = categories
        self.products = products
        self.productPrices = productPrices
        self.historySessions = historySessions
        self.eventInjectedOnFirstCatalogFetch = eventInjectedOnFirstCatalogFetch
        self.productsAfterFirstCatalogFetch = productsAfterFirstCatalogFetch
        self.historyFetchError = historyFetchError
        self.returnsOverfullEventPage = returnsOverfullEventPage
        self.eventFetchError = eventFetchError
        self.eventFetchErrorAfterID = eventFetchErrorAfterID
    }

    func fetchSyncEventsAfter(ownerUserID: UUID, afterID: Int64, limit: Int) async throws -> [RemoteSyncEventRow] {
        fetchedAfterIDs.append(afterID)
        if let eventFetchError,
           eventFetchErrorAfterID == afterID {
            throw eventFetchError
        }
        let effectiveLimit = returnsOverfullEventPage ? limit + 1 : limit
        return Array(events.filter { $0.ownerUserID == ownerUserID && $0.id > afterID }.prefix(effectiveLimit))
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
        if catalogFetchCallCount == 1,
           let eventInjectedOnFirstCatalogFetch {
            events.append(eventInjectedOnFirstCatalogFetch)
            events.sort { $0.id < $1.id }
            if let productsAfterFirstCatalogFetch {
                products = productsAfterFirstCatalogFetch
            }
        }
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
        productPriceFetchCallCount += 1
        return productPrices.filter {
            $0.ownerUserID == ownerUserID && priceIDs.contains($0.id)
        }
    }

    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot {
        reconciliationCallCount += 1
        return .zero
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
        historyFetchCallCount += 1
        if let historyFetchError { throw historyFetchError }
        return historySessions.filter {
            $0.ownerUserID == ownerUserID && sessionIDs.contains($0.remoteID)
        }
    }
}

private struct V6FenceAdvance: Equatable, Sendable {
    let from: Int64
    let through: Int64
}

private final class V6FenceAdvanceRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private let failsFencePersistence: Bool
    private var advances: [V6FenceAdvance] = []

    init(failsFencePersistence: Bool) {
        self.failsFencePersistence = failsFencePersistence
    }

    func record(
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        from watermark: Int64,
        through newWatermark: Int64
    ) throws {
        guard ownerUserID == scope.ownerUserID, newWatermark > watermark else {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
        lock.lock()
        defer { lock.unlock() }
        if failsFencePersistence {
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
        advances.append(.init(from: watermark, through: newWatermark))
    }

    func snapshot() -> [V6FenceAdvance] {
        lock.lock()
        defer { lock.unlock() }
        return advances
    }
}

@MainActor
private final class V6FenceIncrementalRemoteFake: SyncAutomaticIncrementalRemote, ShopScopedIncrementalFencePersisting, @unchecked Sendable {
    private var events: [RemoteSyncEventRow]
    private let fenceRecorder: V6FenceAdvanceRecorder

    init(
        events: [RemoteSyncEventRow],
        failsFencePersistence: Bool = false
    ) {
        self.events = events
        self.fenceRecorder = V6FenceAdvanceRecorder(
            failsFencePersistence: failsFencePersistence
        )
    }

    func replaceEvents(_ events: [RemoteSyncEventRow]) {
        self.events = events
    }

    nonisolated func fenceAdvances() -> [V6FenceAdvance] {
        fenceRecorder.snapshot()
    }

    nonisolated func advanceDurableFence(
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        from watermark: Int64,
        through newWatermark: Int64
    ) async throws {
        try fenceRecorder.record(
            ownerUserID: ownerUserID,
            scope: scope,
            from: watermark,
            through: newWatermark
        )
    }

    func fetchSyncEventsAfter(
        ownerUserID: UUID,
        afterID: Int64,
        limit: Int
    ) async throws -> [RemoteSyncEventRow] {
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
        ([], [], [])
    }

    func fetchProductPricesByIDs(
        ownerUserID: UUID,
        priceIDs: Set<UUID>
    ) async throws -> [RemoteInventoryProductPriceRow] {
        []
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
