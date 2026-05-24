import XCTest
import SwiftData
@testable import iOSMerchandiseControl

@MainActor
final class SupabaseManualPushServiceTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testCreateSupplierCategoryProductUpdatesRemoteIDsAndBaselineAfterReadBack() async throws {
        let context = try makeContext()
        let ownerID = UUID()
        _ = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )

        let supplier = Supplier(name: "Acme")
        let category = ProductCategory(name: "Shelf")
        context.insert(supplier)
        context.insert(category)
        context.insert(Product(barcode: "100", productName: "Milk", supplier: supplier, category: category))
        try context.save()

        let gateway = FakeManualPushRemoteGateway()
        let result = await makeService(gateway: gateway).execute(
            plan: try makePlan(context: context, ownerID: ownerID),
            context: context,
            ownerUserID: ownerID
        )

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.supplierCreates, 1)
        XCTAssertEqual(result.categoryCreates, 1)
        XCTAssertEqual(result.productCreates, 1)
        XCTAssertNotNil(supplier.remoteID)
        XCTAssertNotNil(category.remoteID)
        let product = try XCTUnwrap(try context.fetch(FetchDescriptor<Product>()).first)
        XCTAssertNotNil(product.remoteID)
        XCTAssertEqual(gateway.productCreatePayloads.first?.supplierID, supplier.remoteID)
        XCTAssertEqual(gateway.productCreatePayloads.first?.categoryID, category.remoteID)
        XCTAssertNotNil(result.baselineRunID)
    }

    func testUpdatePayloadDoesNotEncodeNullForUnmanagedOrNilFields() throws {
        let payload = SupabaseManualPushProductUpdatePayload(
            barcode: "100",
            itemNumber: nil,
            productName: "Milk",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: 2,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil
        )

        let object = try encodedObject(payload)

        XCTAssertEqual(object["barcode"] as? String, "100")
        XCTAssertEqual(object["product_name"] as? String, "Milk")
        XCTAssertEqual(object["retail_price"] as? Double, 2)
        XCTAssertNil(object["item_number"])
        XCTAssertNil(object["second_product_name"])
        XCTAssertNil(object["supplier_id"])
        XCTAssertNil(object["category_id"])
        XCTAssertFalse(object.keys.contains("deleted_at"))
        XCTAssertFalse(object.keys.contains("owner_user_id"))
    }

    func testProductTombstoneCandidateUpdatesRemoteDeletedAtWithoutLocalProduct() async throws {
        let context = try makeContext()
        let ownerID = UUID()
        let remoteID = UUID()
        let plan = ManualPushPlan(
            generatedAt: Date(timeIntervalSince1970: 1_778_300_000),
            ownerUserID: ownerID,
            candidates: [
                PushCandidate(
                    entityKind: .product,
                    localID: "product:remote:\(remoteID.uuidString.lowercased())",
                    remoteID: remoteID,
                    action: .dryRunTombstoneCandidate
                )
            ],
            blockedReasons: [],
            warnings: [],
            futureEventChangedCount: 0
        )
        let gateway = FakeManualPushRemoteGateway()

        let result = await makeService(gateway: gateway).execute(
            plan: plan,
            context: context,
            ownerUserID: ownerID
        )

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.productUpdates, 1)
        XCTAssertNil(result.baselineRunID)
        XCTAssertEqual(gateway.productUpdatePayloads.count, 1)
        XCTAssertNotNil(gateway.productUpdatePayloads.first?.deletedAt)
    }

    func testPartialSuccessDoesNotCreateValidBaseline() async throws {
        let context = try makeContext()
        let ownerID = UUID()
        _ = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        let supplier = Supplier(name: "Acme")
        let category = ProductCategory(name: "Shelf")
        context.insert(supplier)
        context.insert(category)
        context.insert(Product(barcode: "100", productName: "Milk", supplier: supplier, category: category))
        try context.save()

        let gateway = FakeManualPushRemoteGateway()
        gateway.failProductCreate = true
        let result = await makeService(gateway: gateway).execute(
            plan: try makePlan(context: context, ownerID: ownerID),
            context: context,
            ownerUserID: ownerID
        )

        XCTAssertEqual(result.status, .partial)
        XCTAssertNotNil(supplier.remoteID)
        XCTAssertNil(try context.fetch(FetchDescriptor<Product>()).first?.remoteID)
        XCTAssertNil(result.baselineRunID)
    }

    func testCompletedWriteWithReadBackFailureReportsBaselineRefreshFailed() async throws {
        let context = try makeContext()
        let ownerID = UUID()
        _ = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        context.insert(Supplier(name: "Acme"))
        try context.save()

        let gateway = FakeManualPushRemoteGateway()
        gateway.failReadBack = true
        let result = await makeService(gateway: gateway).execute(
            plan: try makePlan(context: context, ownerID: ownerID),
            context: context,
            ownerUserID: ownerID
        )

        XCTAssertEqual(result.status, .completedBaselineRefreshFailed)
        XCTAssertNil(result.baselineRunID)
    }

    func testBatchFallbackRetriesSmallerCreates() async throws {
        let context = try makeContext()
        let ownerID = UUID()
        _ = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        context.insert(Supplier(name: "A"))
        context.insert(Supplier(name: "B"))
        try context.save()

        let gateway = FakeManualPushRemoteGateway()
        gateway.failSupplierBatchLargerThanOne = true
        let result = await makeService(gateway: gateway, maxBatchSize: 50).execute(
            plan: try makePlan(context: context, ownerID: ownerID),
            context: context,
            ownerUserID: ownerID
        )

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(result.supplierCreates, 2)
        XCTAssertTrue(gateway.supplierCreateBatchSizes.contains(2))
        XCTAssertGreaterThanOrEqual(gateway.supplierCreateBatchSizes.filter { $0 == 1 }.count, 2)
    }

    func testCreateResponseMismatchReportsPartialAfterConfirmedRemoteWrite() async throws {
        let context = try makeContext()
        let ownerID = UUID()
        _ = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        let supplier = Supplier(name: "Acme")
        context.insert(supplier)
        try context.save()

        let gateway = FakeManualPushRemoteGateway()
        gateway.corruptSupplierCreateResponseName = true
        let result = await makeService(gateway: gateway).execute(
            plan: try makePlan(context: context, ownerID: ownerID),
            context: context,
            ownerUserID: ownerID
        )

        XCTAssertEqual(result.status, .partial)
        XCTAssertEqual(result.supplierCreates, 0)
        XCTAssertNil(result.baselineRunID)
        XCTAssertNil(supplier.remoteID)
    }

    func testLinkedRemoteIDMissingOnVerifyFailsBeforeWriteConservatively() async throws {
        let context = try makeContext()
        let ownerID = UUID()
        _ = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        let remoteID = UUID()
        let supplier = Supplier(
            name: "Acme",
            remoteID: remoteID,
            remoteUpdatedAt: Date(timeIntervalSince1970: 1_778_300_000)
        )
        context.insert(supplier)
        try context.save()

        let gateway = FakeManualPushRemoteGateway()
        gateway.failVerifySupplier = true
        let result = await makeService(gateway: gateway).execute(
            plan: try makePlan(context: context, ownerID: ownerID),
            context: context,
            ownerUserID: ownerID
        )

        XCTAssertEqual(result.status, .failedBeforeWrite)
        XCTAssertEqual(result.supplierLinks, 0)
        XCTAssertNil(result.baselineRunID)
        XCTAssertEqual(supplier.remoteID, remoteID)
    }

    func testRetryAfterPartialDoesNotCreateAlreadyLinkedSupplierAgain() async throws {
        let context = try makeContext()
        let ownerID = UUID()
        _ = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        let supplier = Supplier(name: "Acme")
        let category = ProductCategory(name: "Shelf")
        context.insert(supplier)
        context.insert(category)
        context.insert(Product(barcode: "100", productName: "Milk", supplier: supplier, category: category))
        try context.save()

        let firstGateway = FakeManualPushRemoteGateway()
        firstGateway.failProductCreate = true
        _ = await makeService(gateway: firstGateway).execute(
            plan: try makePlan(context: context, ownerID: ownerID),
            context: context,
            ownerUserID: ownerID
        )

        let retryGateway = FakeManualPushRemoteGateway()
        let retryPlan = try makePlan(context: context, ownerID: ownerID)
        XCTAssertFalse(retryPlan.candidates.contains { $0.entityKind == .supplier && $0.action == .dryRunCreateCandidate })

        let retryResult = await makeService(gateway: retryGateway).execute(
            plan: retryPlan,
            context: context,
            ownerUserID: ownerID
        )

        XCTAssertEqual(retryResult.status, .completed)
        XCTAssertEqual(retryGateway.supplierCreatePayloads.count, 0)
    }

    func testScopedTask045GuardBlocksOutsideSupplierBeforeRemoteCall() async throws {
        let context = try makeContext()
        let ownerID = UUID()
        context.insert(Supplier(name: "Outside Supplier"))
        try context.save()

        let plan = ManualPushPlan(
            generatedAt: Date(),
            ownerUserID: ownerID,
            scope: .scopedTask045,
            scopeSummary: ManualPushScopeSummary(mode: .scopedTask045, included: 1),
            candidates: [
                PushCandidate(entityKind: .supplier, localID: "Outside Supplier", action: .dryRunCreateCandidate)
            ],
            blockedReasons: [],
            warnings: [],
            futureEventChangedCount: 1
        )
        let gateway = FakeManualPushRemoteGateway()

        let result = await makeService(gateway: gateway).execute(
            plan: plan,
            context: context,
            ownerUserID: ownerID
        )

        XCTAssertEqual(result.status, .blockedBeforeWrite)
        XCTAssertEqual(gateway.supplierCreatePayloads.count, 0)
    }

    func testScopedTask045GuardBlocksOutsideLocalDependencyBeforeRemoteCall() async throws {
        let context = try makeContext()
        let ownerID = UUID()
        let supplier = Supplier(name: "Outside Supplier")
        context.insert(supplier)
        context.insert(Product(barcode: "TASK045_PRODUCT_BARCODE", productName: "Scoped", supplier: supplier))
        try context.save()

        let plan = ManualPushPlan(
            generatedAt: Date(),
            ownerUserID: ownerID,
            scope: .scopedTask045,
            scopeSummary: ManualPushScopeSummary(mode: .scopedTask045, included: 1),
            candidates: [
                PushCandidate(entityKind: .product, localID: "TASK045_PRODUCT_BARCODE", action: .dryRunCreateCandidate)
            ],
            blockedReasons: [],
            warnings: [],
            futureEventChangedCount: 1
        )
        let gateway = FakeManualPushRemoteGateway()

        let result = await makeService(gateway: gateway).execute(
            plan: plan,
            context: context,
            ownerUserID: ownerID
        )

        XCTAssertEqual(result.status, .blockedBeforeWrite)
        XCTAssertEqual(gateway.productCreatePayloads.count, 0)
    }

    func testScopedTask045GuardAllowsOutsideRemoteDependencyWithoutWritingLookup() async throws {
        let context = try makeContext()
        let ownerID = UUID()
        let supplierRemoteID = UUID()
        let supplier = Supplier(
            name: "Outside Supplier",
            remoteID: supplierRemoteID,
            remoteUpdatedAt: Date(timeIntervalSince1970: 1_778_300_000)
        )
        let product = Product(barcode: "TASK045_PRODUCT_BARCODE", productName: "Scoped", supplier: supplier)
        context.insert(supplier)
        context.insert(product)
        try context.save()

        let plan = ManualPushPlan(
            generatedAt: Date(),
            ownerUserID: ownerID,
            scope: .scopedTask045,
            scopeSummary: ManualPushScopeSummary(
                mode: .scopedTask045,
                included: 1,
                excludedOutsideScope: 1,
                blockedDependencies: 0
            ),
            candidates: [
                PushCandidate(entityKind: .product, localID: "TASK045_PRODUCT_BARCODE", action: .dryRunCreateCandidate)
            ],
            blockedReasons: [],
            warnings: [],
            futureEventChangedCount: 1
        )
        let gateway = FakeManualPushRemoteGateway()

        let result = await makeService(gateway: gateway).execute(
            plan: plan,
            context: context,
            ownerUserID: ownerID
        )

        XCTAssertEqual(result.status, .completed)
        XCTAssertEqual(gateway.supplierCreatePayloads.count, 0)
        XCTAssertEqual(gateway.productCreatePayloads.first?.supplierID, supplierRemoteID)
        XCTAssertNotNil(product.remoteID)
    }

    private func makeService(
        gateway: FakeManualPushRemoteGateway,
        maxBatchSize: Int = 50
    ) -> SupabaseManualPushService {
        SupabaseManualPushService(
            remote: gateway,
            baselineWriter: SupabaseCatalogBaselineWriter(now: clock()),
            maxBatchSize: maxBatchSize
        )
    }

    private func makePlan(context: ModelContext, ownerID: UUID) throws -> ManualPushPlan {
        let snapshotService = SwiftDataInventorySnapshotService(context: context)
        let baselineResult = try SupabaseCatalogBaselineReader().readManualPushBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        guard case .available(let snapshot) = baselineResult else {
            throw NSError(domain: "SupabaseManualPushServiceTests", code: 1)
        }
        return SupabaseManualPushPreflightService().makePlan(input: ManualPushPreflightInput(
            baselineRunID: snapshot.runID,
            pullState: ManualPushPullState(isComplete: true),
            accountState: ManualPushAccountState(currentUserID: ownerID, lastLinkedUserID: ownerID),
            baseline: snapshot.baseline,
            suppliers: try snapshotService.makeManualPushPreflightSupplierStates(),
            categories: try snapshotService.makeManualPushPreflightCategoryStates(),
            products: try snapshotService.makeManualPushPreflightProductStates()
        ))
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            ProductPrice.self,
            HistoryEntry.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return ModelContext(container)
    }

    private func encodedObject(_ payload: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func clock() -> () -> Date {
        var offset: TimeInterval = 0
        return {
            offset += 1
            return Date(timeIntervalSince1970: 1_778_300_000 + offset)
        }
    }
}

private final class FakeManualPushRemoteGateway: SupabaseManualPushRemoteGateway {
    var supplierCreatePayloads: [SupabaseManualPushSupplierCreatePayload] = []
    var categoryCreatePayloads: [SupabaseManualPushCategoryCreatePayload] = []
    var productCreatePayloads: [SupabaseManualPushProductCreatePayload] = []
    var productUpdatePayloads: [SupabaseManualPushProductUpdatePayload] = []
    var supplierCreateBatchSizes: [Int] = []
    var failSupplierBatchLargerThanOne = false
    var failProductCreate = false
    var failReadBack = false
    var corruptSupplierCreateResponseName = false
    var failVerifySupplier = false

    private var suppliersByID: [UUID: RemoteInventorySupplierRow] = [:]
    private var categoriesByID: [UUID: RemoteInventoryCategoryRow] = [:]
    private var productsByID: [UUID: RemoteInventoryProductRow] = [:]

    func createSuppliers(_ payloads: [SupabaseManualPushSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow] {
        supplierCreateBatchSizes.append(payloads.count)
        if failSupplierBatchLargerThanOne && payloads.count > 1 {
            throw SupabaseTransportClientError.networkError(statusCode: nil, message: "batch fail")
        }
        supplierCreatePayloads += payloads
        return payloads.map { payload in
            let row = RemoteInventorySupplierRow(
                id: UUID(),
                ownerUserID: payload.ownerUserID,
                name: corruptSupplierCreateResponseName ? "unmatched-\(payload.name)" : payload.name,
                updatedAt: "2026-05-05T10:00:00Z",
                deletedAt: nil
            )
            suppliersByID[row.id] = row
            return row
        }
    }

    func updateSupplier(id: UUID, payload: SupabaseManualPushSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow {
        let row = RemoteInventorySupplierRow(id: id, ownerUserID: UUID(), name: payload.name, updatedAt: "2026-05-05T10:01:00Z", deletedAt: nil)
        suppliersByID[id] = row
        return row
    }

    func verifySupplier(id: UUID, normalizedName: String) async throws -> RemoteInventorySupplierRow {
        if failVerifySupplier {
            throw SupabaseTransportClientError.schemaDrift(message: "missing supplier")
        }
        if let row = suppliersByID[id] {
            return row
        }
        let row = RemoteInventorySupplierRow(id: id, ownerUserID: UUID(), name: normalizedName, updatedAt: "2026-05-05T10:02:00Z", deletedAt: nil)
        suppliersByID[id] = row
        return row
    }

    func createCategories(_ payloads: [SupabaseManualPushCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow] {
        categoryCreatePayloads += payloads
        return payloads.map { payload in
            let row = RemoteInventoryCategoryRow(id: UUID(), ownerUserID: payload.ownerUserID, name: payload.name, updatedAt: "2026-05-05T10:00:00Z", deletedAt: nil)
            categoriesByID[row.id] = row
            return row
        }
    }

    func updateCategory(id: UUID, payload: SupabaseManualPushCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow {
        let row = RemoteInventoryCategoryRow(id: id, ownerUserID: UUID(), name: payload.name, updatedAt: "2026-05-05T10:01:00Z", deletedAt: nil)
        categoriesByID[id] = row
        return row
    }

    func verifyCategory(id: UUID, normalizedName: String) async throws -> RemoteInventoryCategoryRow {
        if let row = categoriesByID[id] {
            return row
        }
        let row = RemoteInventoryCategoryRow(id: id, ownerUserID: UUID(), name: normalizedName, updatedAt: "2026-05-05T10:02:00Z", deletedAt: nil)
        categoriesByID[id] = row
        return row
    }

    func createProducts(_ payloads: [SupabaseManualPushProductCreatePayload]) async throws -> [RemoteInventoryProductRow] {
        if failProductCreate {
            throw SupabaseTransportClientError.networkError(statusCode: nil, message: "product fail")
        }
        productCreatePayloads += payloads
        return payloads.map { payload in
            let row = RemoteInventoryProductRow(
                id: UUID(),
                ownerUserID: payload.ownerUserID,
                barcode: payload.barcode,
                itemNumber: payload.itemNumber,
                productName: payload.productName,
                secondProductName: payload.secondProductName,
                purchasePrice: payload.purchasePrice,
                retailPrice: payload.retailPrice,
                supplierID: payload.supplierID,
                categoryID: payload.categoryID,
                stockQuantity: payload.stockQuantity,
                updatedAt: "2026-05-05T10:00:00Z",
                deletedAt: nil
            )
            productsByID[row.id] = row
            return row
        }
    }

    func updateProduct(id: UUID, payload: SupabaseManualPushProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        productUpdatePayloads.append(payload)
        let row = RemoteInventoryProductRow(
            id: id,
            ownerUserID: UUID(),
            barcode: payload.barcode ?? "updated",
            itemNumber: payload.itemNumber,
            productName: payload.productName,
            secondProductName: payload.secondProductName,
            purchasePrice: payload.purchasePrice,
            retailPrice: payload.retailPrice,
            supplierID: payload.supplierID,
            categoryID: payload.categoryID,
            stockQuantity: payload.stockQuantity,
            updatedAt: "2026-05-05T10:01:00Z",
            deletedAt: payload.deletedAt
        )
        productsByID[id] = row
        return row
    }

    func verifyProduct(id: UUID, normalizedBarcode: String) async throws -> RemoteInventoryProductRow {
        if let row = productsByID[id] {
            return row
        }
        let row = RemoteInventoryProductRow(
            id: id,
            ownerUserID: UUID(),
            barcode: normalizedBarcode,
            itemNumber: nil,
            productName: nil,
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            updatedAt: "2026-05-05T10:02:00Z",
            deletedAt: nil
        )
        productsByID[id] = row
        return row
    }

    func verifyReadBack(expectation: SupabaseManualPushReadBackExpectation) async throws {
        if failReadBack {
            throw SupabaseTransportClientError.networkError(statusCode: nil, message: "readback fail")
        }
        let touchedIDs = expectation.touchedIDs
        XCTAssertEqual(Set(suppliersByID.keys).intersection(touchedIDs.suppliers), touchedIDs.suppliers)
        XCTAssertEqual(Set(categoriesByID.keys).intersection(touchedIDs.categories), touchedIDs.categories)
        XCTAssertEqual(Set(productsByID.keys).intersection(touchedIDs.products), touchedIDs.products)
    }
}
