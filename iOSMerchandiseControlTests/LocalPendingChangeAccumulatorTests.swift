import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class LocalPendingChangeAccumulatorTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private let ownerA = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    private let ownerB = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    private let now = Date(timeIntervalSince1970: 1_778_500_000)

    func testEnqueuesPendingOnlyOnConfirmedSave() throws {
        let context = try makeContext()
        let product = Product(barcode: "TASK093_SAVE", productName: "Saved")
        context.insert(product)

        try LocalPendingChangeAccumulator(
            context: context,
            ownerUserID: ownerA,
            now: { self.now }
        ).recordProductChange(
            product: product,
            operation: .create,
            origin: .manualCatalogSave,
            changedFields: ["barcode", "productName"]
        )
        try context.save()

        let changes = try fetchChanges(context)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.status, .pending)
        XCTAssertEqual(changes.first?.entityKind, .product)
    }

    func testTask114PostsLocalPendingChangeNotificationForActiveChange() throws {
        let context = try makeContext()
        let product = Product(barcode: "TASK114_AUTOSYNC", productName: "Autosync")
        context.insert(product)
        let notification = expectation(description: "local pending change notification")
        let token = NotificationCenter.default.addObserver(
            forName: .localPendingChangesDidChange,
            object: nil,
            queue: nil
        ) { _ in
            notification.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        try LocalPendingChangeAccumulator(
            context: context,
            ownerUserID: ownerA,
            now: { self.now }
        ).recordProductChange(
            product: product,
            operation: .create,
            origin: .manualCatalogSave,
            changedFields: ["barcode", "productName"]
        )

        wait(for: [notification], timeout: 0.1)
    }

    func testTemporaryFormEditsDoNotCreatePendingWithoutConfirmedRecord() throws {
        let context = try makeContext()
        let product = Product(barcode: "TASK093_TYPING", productName: "Draft")
        context.insert(product)
        product.productName = "Temporary text"

        let snapshot = try LocalPendingChangeSnapshotProvider(context: context)
            .loadSnapshot(ownerUserID: ownerA)

        XCTAssertEqual(snapshot, .empty)
    }

    func testCoalescesCreateThenUpdateAsSingleCreate() throws {
        let context = try makeContext()
        let product = Product(barcode: "TASK093_CREATE", productName: "Original")
        context.insert(product)
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: ownerA)

        try accumulator.recordProductChange(
            product: product,
            operation: .create,
            origin: .manualCatalogSave,
            changedFields: ["barcode"]
        )
        product.productName = "Updated"
        try accumulator.recordProductChange(
            product: product,
            operation: .update,
            origin: .manualCatalogSave,
            changedFields: ["productName"]
        )

        let changes = try fetchChanges(context)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].operation, .create)
        XCTAssertEqual(changes[0].changedFields, ["barcode", "productname"])
    }

    func testCoalescesUpdateThenUpdateWithCompactChangedFields() throws {
        let context = try makeContext()
        let remoteID = UUID()
        let product = Product(barcode: "TASK093_UPDATE", remoteID: remoteID)
        context.insert(product)
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: ownerA)

        product.productName = "A"
        try accumulator.recordProductChange(
            product: product,
            operation: .update,
            origin: .manualCatalogSave,
            changedFields: ["productName"]
        )
        product.retailPrice = 12
        try accumulator.recordProductChange(
            product: product,
            operation: .update,
            origin: .manualCatalogSave,
            changedFields: ["retailPrice", "productName"]
        )

        let changes = try fetchChanges(context)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].operation, .update)
        XCTAssertEqual(changes[0].changedFields, ["productname", "retailprice"])
    }

    func testCoalescesUpdateThenDeleteAsTombstone() throws {
        let context = try makeContext()
        let product = Product(barcode: "TASK093_DELETE", remoteID: UUID())
        context.insert(product)
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: ownerA)

        try accumulator.recordProductChange(
            product: product,
            operation: .update,
            origin: .manualCatalogSave,
            changedFields: ["productName"]
        )
        try accumulator.recordProductChange(
            product: product,
            operation: .delete,
            origin: .manualCatalogSave,
            changedFields: ["tombstone"]
        )

        let changes = try fetchChanges(context)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].operation, .delete)
        XCTAssertEqual(changes[0].changedFields, ["tombstone"])
        XCTAssertEqual(changes[0].status, .pending)
    }

    func testCoalescesUnsyncedCreateThenDeleteAsSupersededNoOp() throws {
        let context = try makeContext()
        let product = Product(barcode: "TASK093_NOOP")
        context.insert(product)
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: ownerA)

        try accumulator.recordProductChange(
            product: product,
            operation: .create,
            origin: .manualCatalogSave,
            changedFields: ["barcode"]
        )
        try accumulator.recordProductChange(
            product: product,
            operation: .delete,
            origin: .manualCatalogSave,
            changedFields: ["tombstone"]
        )

        let changes = try fetchChanges(context)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].status, .superseded)
        let snapshot = try LocalPendingChangeSnapshotProvider(context: context)
            .loadSnapshot(ownerUserID: ownerA)
        XCTAssertEqual(snapshot.pendingCatalogChangeCount, 0)
    }

    func testCoalescesProductPriceByProductTypeAndEffectiveAt() throws {
        let context = try makeContext()
        let product = Product(barcode: "TASK093_PRICE")
        let effectiveAt = Date(timeIntervalSince1970: 1_778_400_100)
        let price = ProductPrice(
            type: .retail,
            price: 10,
            effectiveAt: effectiveAt,
            source: "TEST",
            product: product
        )
        context.insert(product)
        context.insert(price)
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: ownerA)

        try accumulator.recordProductPriceChange(price: price, origin: .productPriceSave)
        price.price = 12
        try accumulator.recordProductPriceChange(price: price, origin: .productPriceSave)

        let changes = try fetchChanges(context)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes[0].entityKind, .productPrice)
        XCTAssertEqual(changes[0].operation, .upsert)
        let snapshot = try LocalPendingChangeSnapshotProvider(context: context)
            .loadSnapshot(ownerUserID: ownerA)
        XCTAssertEqual(snapshot.pendingProductPriceChangeCount, 1)
    }

    func testConfirmedImportBatchIsCappedWithAggregateMarker() throws {
        let context = try makeContext()
        let accumulator = LocalPendingChangeAccumulator(
            context: context,
            ownerUserID: ownerA,
            maxActiveChanges: 2
        )

        let result = try accumulator.recordImportBatch(
            logicalKeys: ["product-a", "product-b", "product-c"],
            maxLogicalKeys: 2
        )

        XCTAssertEqual(result.recordedCount, 2)
        XCTAssertEqual(result.cappedCount, 1)
        let snapshot = try LocalPendingChangeSnapshotProvider(context: context)
            .loadSnapshot(ownerUserID: ownerA)
        XCTAssertEqual(snapshot.pendingCatalogChangeCount, 3)
        XCTAssertEqual(snapshot.blockedCount, 1)
        XCTAssertTrue(snapshot.isCapped)
    }

    func testStateMachineAndCleanupRetainBoundedTerminalRows() throws {
        let context = try makeContext()
        let accumulator = LocalPendingChangeAccumulator(
            context: context,
            ownerUserID: ownerA,
            now: { self.now }
        )

        for index in 0..<3 {
            let product = Product(barcode: "TASK093_STATE_\(index)")
            context.insert(product)
            let change = try XCTUnwrap(accumulator.recordProductChange(
                product: product,
                operation: .create,
                origin: .manualCatalogSave,
                changedFields: ["barcode"]
            ))
            accumulator.markStatus(change: change, status: index == 0 ? .blocked : .superseded)
        }

        try accumulator.cleanupTerminalChanges(retainAtMost: 1)

        let changes = try fetchChanges(context)
        XCTAssertEqual(changes.filter { $0.status == .blocked }.count, 1)
        XCTAssertEqual(changes.filter { $0.status == .superseded }.count, 1)
    }

    func testSnapshotProviderIsReadOnlyAndDoesNotExposeRawIdentifiers() throws {
        let context = try makeContext()
        let product = Product(barcode: "123456789_RAW", productName: "Raw Product Name")
        context.insert(product)
        try LocalPendingChangeAccumulator(context: context, ownerUserID: ownerA)
            .recordProductChange(
                product: product,
                operation: .create,
                origin: .manualCatalogSave,
                changedFields: ["barcode", "productName"]
            )
        let provider = LocalPendingChangeSnapshotProvider(context: context)
        let before = try fetchChanges(context)

        let snapshot = try provider.loadSnapshot(ownerUserID: ownerA)
        let after = try fetchChanges(context)

        XCTAssertEqual(before.map(\.changeID), after.map(\.changeID))
        XCTAssertEqual(snapshot.pendingCatalogChangeCount, 1)
        let snapshotText = String(describing: snapshot)
        XCTAssertFalse(snapshotText.contains("123456789_RAW"))
        XCTAssertFalse(snapshotText.contains("Raw Product Name"))
    }

    func testReconciliationMarksRemoteSameStaleTombstoneAndLeavesIndependentPending() throws {
        let context = try makeContext()
        let sameRemoteID = UUID()
        let staleRemoteID = UUID()
        let deletedRemoteID = UUID()
        let independentRemoteID = UUID()
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: ownerA)

        try recordRemoteProduct(
            remoteID: sameRemoteID,
            barcode: "TASK093_REMOTE_SAME",
            baselineRaw: "same-baseline",
            intendedRaw: "same-intended",
            accumulator: accumulator,
            context: context
        )
        try recordRemoteProduct(
            remoteID: staleRemoteID,
            barcode: "TASK093_REMOTE_STALE",
            baselineRaw: "stale-baseline",
            intendedRaw: "stale-intended",
            accumulator: accumulator,
            context: context
        )
        try recordRemoteProduct(
            remoteID: deletedRemoteID,
            barcode: "TASK093_REMOTE_DELETED",
            baselineRaw: "deleted-baseline",
            intendedRaw: "deleted-intended",
            accumulator: accumulator,
            context: context
        )
        try recordRemoteProduct(
            remoteID: independentRemoteID,
            barcode: "TASK093_REMOTE_PENDING",
            baselineRaw: "pending-baseline",
            intendedRaw: "pending-intended",
            accumulator: accumulator,
            context: context
        )

        try accumulator.reconcileAfterBaselineRefresh(records: [
            LocalPendingChangeReconciliationRecord(
                entityKind: .product,
                remoteID: sameRemoteID,
                fingerprintCanonical: "same-intended"
            ),
            LocalPendingChangeReconciliationRecord(
                entityKind: .product,
                remoteID: staleRemoteID,
                fingerprintCanonical: "remote-changed"
            ),
            LocalPendingChangeReconciliationRecord(
                entityKind: .product,
                remoteID: deletedRemoteID,
                remoteDeletedAt: now,
                fingerprintCanonical: "deleted-baseline"
            )
        ])

        let byKey = Dictionary(uniqueKeysWithValues: try fetchChanges(context).map { ($0.entityRemoteID!, $0.status) })
        XCTAssertEqual(byKey[sameRemoteID], .superseded)
        XCTAssertEqual(byKey[staleRemoteID], .staleBaseline)
        XCTAssertEqual(byKey[deletedRemoteID], .blocked)
        XCTAssertEqual(byKey[independentRemoteID], .pending)
    }

    func testOwnerScopedSnapshotFailsClosedForDifferentOwnerOrMissingSession() throws {
        let context = try makeContext()
        let product = Product(barcode: "TASK093_OWNER")
        context.insert(product)
        try LocalPendingChangeAccumulator(context: context, ownerUserID: ownerA)
            .recordProductChange(
                product: product,
                operation: .create,
                origin: .manualCatalogSave,
                changedFields: ["barcode"]
            )
        let ownerlessProduct = Product(barcode: "TASK093_OWNERLESS")
        context.insert(ownerlessProduct)
        try LocalPendingChangeAccumulator(context: context, ownerUserID: nil)
            .recordProductChange(
                product: ownerlessProduct,
                operation: .create,
                origin: .manualCatalogSave,
                changedFields: ["barcode"]
            )
        let provider = LocalPendingChangeSnapshotProvider(context: context)

        XCTAssertEqual(try provider.loadSnapshot(ownerUserID: ownerA).pendingCatalogChangeCount, 1)
        XCTAssertEqual(try provider.loadSnapshot(ownerUserID: ownerB), .empty)
        XCTAssertEqual(try provider.loadSnapshot(ownerUserID: nil), .empty)
    }

    func testTask115CoalescingSameLogicalKeyDoesNotCrossOwnerBoundary() throws {
        let context = try makeContext()
        let remoteID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let ownerAProduct = Product(barcode: "TASK115_OWNER_SHARED", remoteID: remoteID)
        let ownerBProduct = Product(barcode: "TASK115_OWNER_SHARED", remoteID: remoteID)
        context.insert(ownerAProduct)
        context.insert(ownerBProduct)

        try LocalPendingChangeAccumulator(context: context, ownerUserID: ownerA)
            .recordProductChange(
                product: ownerAProduct,
                operation: .update,
                origin: .manualCatalogSave,
                changedFields: ["productName"]
            )
        try LocalPendingChangeAccumulator(context: context, ownerUserID: ownerB)
            .recordProductChange(
                product: ownerBProduct,
                operation: .delete,
                origin: .manualCatalogSave,
                changedFields: ["tombstone"]
            )

        let changes = try fetchChanges(context)

        XCTAssertEqual(changes.count, 2)
        XCTAssertEqual(
            Set(changes.compactMap(\.ownerUserID)),
            Set([ownerA.uuidString.lowercased(), ownerB.uuidString.lowercased()])
        )
        XCTAssertEqual(changes.first { $0.ownerUserID == ownerA.uuidString.lowercased() }?.operation, .update)
        XCTAssertEqual(changes.first { $0.ownerUserID == ownerB.uuidString.lowercased() }?.operation, .delete)
    }

    private func recordRemoteProduct(
        remoteID: UUID,
        barcode: String,
        baselineRaw: String,
        intendedRaw: String,
        accumulator: LocalPendingChangeAccumulator,
        context: ModelContext
    ) throws {
        let product = Product(barcode: barcode, remoteID: remoteID)
        context.insert(product)
        try accumulator.recordProductChange(
            product: product,
            operation: .update,
            origin: .manualCatalogSave,
            changedFields: ["productName"],
            baselineFingerprintHash: LocalPendingChangeLogicalKey.privacyHash(baselineRaw),
            intendedFingerprintHash: LocalPendingChangeLogicalKey.privacyHash(intendedRaw)
        )
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

    private func fetchChanges(_ context: ModelContext) throws -> [LocalPendingChange] {
        try context.fetch(FetchDescriptor<LocalPendingChange>(
            sortBy: [SortDescriptor(\.updatedAt, order: .forward)]
        ))
    }
}
