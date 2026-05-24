import CryptoKit
import Foundation
import SwiftData
import Supabase
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class Task098CrossPlatformSmokeTests: XCTestCase {
    private enum Fixture {
        static let prefix = "TASK098_"
        static let supplier = "TASK098_SUPPLIER_CROSS_PLATFORM"
        static let category = "TASK098_CATEGORY_CROSS_PLATFORM"
        static let productA = "TASK098_PRODUCT_ANDROID_TO_IOS"
        static let barcodeA = "TASK098_BAR_A2I"
        static let productB = "TASK098_PRODUCT_IOS_TO_ANDROID"
        static let barcodeB = "TASK098_BAR_I2A"
        static let tolerance = 0.005
    }

    private static var retainedContainers: [ModelContainer] = []
    private static var retainedContexts: [ModelContext] = []

    func test01PreflightAndCollisionScanReadOnly() async throws {
        try requireLiveSmokeEnabled()
        let runtime = try await makeRuntime()
        let snapshot = try await fetchRemoteSnapshot(runtime)

        XCTAssertFalse(runtime.config.publishableKey.lowercased().contains("service_role"))
        XCTAssertFalse(runtime.session.isExpired)
        let supplierCount = activeSuppliers(in: snapshot).count
        let categoryCount = activeCategories(in: snapshot).count
        let productCount = activeProducts(in: snapshot, barcodes: [Fixture.barcodeA, Fixture.barcodeB]).count
        if supplierCount + categoryCount + productCount > 0 {
            throw XCTSkip("TASK-098 evidence rows are already present; strict collision scan is pre-write only.")
        }
        XCTAssertEqual(supplierCount, 0)
        XCTAssertEqual(categoryCount, 0)
        XCTAssertEqual(productCount, 0)

        let fixtureProductIDs = Set(activeProducts(in: snapshot, barcodes: [Fixture.barcodeA, Fixture.barcodeB]).map(\.id))
        XCTAssertTrue(snapshot.prices.filter { fixtureProductIDs.contains($0.productID) }.isEmpty)
        print("TASK098_IOS_PREFLIGHT project_hash=\(hash(runtime.config.projectURL.absoluteString)) owner_hash=\(ownerHash(runtime.session.userID)) collision=free")
    }

    func test02PullApplyAndroidProductAAndLocalReadBack() async throws {
        try requireLiveSmokeEnabled()
        let runtime = try await makeRuntime()
        let snapshot = try await fetchRemoteSnapshot(runtime)
        let productA = try XCTUnwrap(singleActiveProduct(in: snapshot, barcode: Fixture.barcodeA))
        let pricesA = prices(in: snapshot, productID: productA.id)
        XCTAssertEqual(productA.productName, Fixture.productA)
        XCTAssertEqual(pricesA.count, 4)

        let context = try makeContext()
        let preview = makePreview(for: productA, snapshot: snapshot)
        let applyPlan = try SupabasePullApplyService().prepareApplyPlan(
            preview: preview,
            context: context,
            isAuthenticated: true,
            accountGuard: SupabasePullApplyAccountGuard(
                currentUserID: runtime.session.userID,
                lastLinkedUserID: runtime.session.userID
            )
        )
        let catalogResult = try SupabasePullApplyService().apply(plan: applyPlan, context: context)
        XCTAssertEqual(catalogResult.inserted, 1)

        let pricePlan = try SupabaseProductPriceApplyService().prepareApplyPlan(
            remoteRows: pricesA,
            context: context,
            sessionSnapshot: ProductPriceApplySessionSnapshot(userID: runtime.session.userID)
        )
        XCTAssertTrue(pricePlan.isApplyAllowed)
        let priceResult = try SupabaseProductPriceApplyService().apply(
            plan: pricePlan,
            context: context,
            currentSessionSnapshot: ProductPriceApplySessionSnapshot(userID: runtime.session.userID)
        )
        XCTAssertEqual(priceResult.inserted, 4)

        try assertLocalPrices(
            context: context,
            barcode: Fixture.barcodeA,
            expected: expectedA()
        )
        print("TASK098_IOS_PULL_A owner_hash=\(ownerHash(runtime.session.userID)) inserted_catalog=\(catalogResult.inserted) inserted_prices=\(priceResult.inserted)")
    }

    func test03IOSWriteProductBUsingReleaseServices() async throws {
        try requireLiveSmokeEnabled()
        let runtime = try await makeRuntime()
        let snapshot = try await fetchRemoteSnapshot(runtime)
        let supplierRow = try XCTUnwrap(singleActiveSupplier(in: snapshot))
        let categoryRow = try XCTUnwrap(singleActiveCategory(in: snapshot))
        if let existingB = singleActiveProduct(in: snapshot, barcode: Fixture.barcodeB) {
            XCTAssertEqual(existingB.productName, Fixture.productB)
            assertRemotePrices(prices(in: snapshot, productID: existingB.id), expected: expectedB())
            print("TASK098_IOS_WRITE_B owner_hash=\(ownerHash(runtime.session.userID)) already_aligned=true product_hash=\(hash(existingB.id.uuidString.lowercased()))")
            return
        }

        let context = try makeContext()
        let supplier = Supplier(
            name: supplierRow.name,
            remoteID: supplierRow.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(supplierRow.updatedAt),
            remoteDeletedAt: SupabaseRemoteDateParser.parse(supplierRow.deletedAt)
        )
        let category = ProductCategory(
            name: categoryRow.name,
            remoteID: categoryRow.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(categoryRow.updatedAt),
            remoteDeletedAt: SupabaseRemoteDateParser.parse(categoryRow.deletedAt)
        )
        context.insert(supplier)
        context.insert(category)
        try context.save()
        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: context,
            ownerUserUUID: runtime.session.userID
        )

        let product = Product(
            barcode: Fixture.barcodeB,
            productName: Fixture.productB,
            purchasePrice: 55.55,
            retailPrice: 111.10,
            supplier: supplier,
            category: category
        )
        context.insert(product)
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: runtime.session.userID)
        try accumulator.recordProductChange(
            product: product,
            operation: .create,
            origin: .manualCatalogSave,
            changedFields: [
                "barcode",
                "productName",
                "purchasePrice",
                "retailPrice",
                "supplier",
                "category"
            ]
        )
        try context.save()

        let catalogAggregated = try await LocalPendingAggregatedPushPlanner(
            context: context,
            includesCatalog: true,
            includesProductPrice: false
        ).makePlan(ownerUserID: runtime.session.userID)
        XCTAssertTrue(catalogAggregated.blockers.isEmpty)
        let catalogBatch = try XCTUnwrap(catalogAggregated.catalogBatch)
        try LocalPendingAggregatedPushStateStore(context: context).markSent(
            changeIDs: catalogBatch.changeIDs,
            ownerUserID: runtime.session.userID,
            planFingerprint: catalogBatch.plan.planFingerprint
        )
        let catalogPush = await SupabaseManualPushService(clientProvider: runtime.provider).execute(
            plan: catalogBatch.plan,
            context: context,
            ownerUserID: runtime.session.userID
        )
        XCTAssertEqual(catalogPush.status, .completed)
        try LocalPendingAggregatedPushStateStore(context: context).markAcknowledged(
            changeIDs: catalogBatch.changeIDs,
            ownerUserID: runtime.session.userID
        )
        XCTAssertNotNil(product.remoteID)

        for point in expectedB() {
            let row = ProductPrice(
                type: point.type,
                price: point.price,
                effectiveAt: try date(point.effectiveAt),
                source: "TASK098_IOS_PUSH",
                note: "TASK098_CROSS_PLATFORM",
                createdAt: try date(point.effectiveAt),
                product: product
            )
            context.insert(row)
            try accumulator.recordProductPriceChange(price: row, origin: .productPriceSave)
        }
        try context.save()

        let priceAggregated = try await LocalPendingAggregatedPushPlanner(
            context: context,
            priceRemoteFetcher: runtime.inventory,
            includesCatalog: false,
            includesProductPrice: true
        ).makePlan(ownerUserID: runtime.session.userID)
        XCTAssertTrue(priceAggregated.blockers.isEmpty)
        let priceBatch = try XCTUnwrap(priceAggregated.productPriceBatch)
        XCTAssertEqual(priceBatch.plan.summary.readyCandidates, 4)
        let priceFingerprint = productPricePushFingerprint(priceBatch.plan)
        try LocalPendingAggregatedPushStateStore(context: context).markSent(
            changeIDs: priceBatch.changeIDs,
            ownerUserID: runtime.session.userID,
            planFingerprint: priceFingerprint
        )
        let snapshotForPush = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: priceBatch.plan)
        let pricePush = try await SupabaseProductPriceManualPushService(remote: runtime.inventory).push(snapshot: snapshotForPush)
        XCTAssertTrue(pricePush.isVerifiedSuccess)
        XCTAssertEqual(
            try ProductPriceManualPushIdentityReconciler().linkVerifiedPayloads(
                snapshotForPush.payloads,
                context: context
            ),
            4
        )
        try LocalPendingAggregatedPushStateStore(context: context).markAcknowledged(
            changeIDs: priceBatch.changeIDs,
            ownerUserID: runtime.session.userID
        )

        let readBack = try await fetchRemoteSnapshot(runtime)
        let remoteB = try XCTUnwrap(singleActiveProduct(in: readBack, barcode: Fixture.barcodeB))
        XCTAssertEqual(remoteB.productName, Fixture.productB)
        XCTAssertPrice(remoteB.purchasePrice, equals: 55.55, label: "remote catalog B purchase")
        XCTAssertPrice(remoteB.retailPrice, equals: 111.10, label: "remote catalog B retail")
        assertRemotePrices(prices(in: readBack, productID: remoteB.id), expected: expectedB())
        print("TASK098_IOS_WRITE_B owner_hash=\(ownerHash(runtime.session.userID)) catalog_status=\(catalogPush.status.rawValue) price_inserted=\(pricePush.insertedCount)")
    }

    func test04RemoteReadBackB() async throws {
        try requireLiveSmokeEnabled()
        let runtime = try await makeRuntime()
        let snapshot = try await fetchRemoteSnapshot(runtime)
        let productB = try XCTUnwrap(singleActiveProduct(in: snapshot, barcode: Fixture.barcodeB))
        XCTAssertEqual(productB.productName, Fixture.productB)
        assertRemotePrices(prices(in: snapshot, productID: productB.id), expected: expectedB())
        print("TASK098_IOS_REMOTE_B owner_hash=\(ownerHash(runtime.session.userID)) product_hash=\(hash(productB.id.uuidString.lowercased()))")
    }

    private func makeRuntime() async throws -> Runtime {
        let config = try SupabaseConfig.load()
        let provider = SupabaseClientProvider(config: config)
        let session = try await provider.client.auth.session
        return Runtime(
            config: config,
            provider: provider,
            inventory: SupabaseTransportClient(clientProvider: provider),
            session: SupabaseAuthService.sessionInfoForTask098(session)
        )
    }

    private func requireLiveSmokeEnabled() throws {
        let environment = ProcessInfo.processInfo.environment
        let value = (environment["TASK098_LIVE_SMOKE"] ?? environment["SIMCTL_CHILD_TASK098_LIVE_SMOKE"])?.lowercased()
        let sentinelPath = "/tmp/TASK098_LIVE_SMOKE"
        guard value == "1" || value == "true" || FileManager.default.fileExists(atPath: sentinelPath) else {
            throw XCTSkip("TASK-098 live smoke is gated. Set TASK098_LIVE_SMOKE=1, or create \(sentinelPath) for xcodebuild simulator runs, and run the selected live tests in the documented order.")
        }
    }

    private func fetchRemoteSnapshot(_ runtime: Runtime) async throws -> RemoteSnapshot {
        async let suppliers = fetchFixtureSuppliers(runtime.provider, ownerUserID: runtime.session.userID)
        async let categories = fetchFixtureCategories(runtime.provider, ownerUserID: runtime.session.userID)
        let products = try await fetchFixtureProducts(runtime.provider, ownerUserID: runtime.session.userID)
        let fixtureProductIDs = activeProducts(
            in: RemoteSnapshot(suppliers: [], categories: [], products: products, prices: []),
            barcodes: [Fixture.barcodeA, Fixture.barcodeB]
        ).map(\.id)
        let prices = try await fetchFixturePrices(
            runtime.inventory,
            ownerUserID: runtime.session.userID,
            productIDs: fixtureProductIDs
        )
        return try await RemoteSnapshot(
            suppliers: suppliers,
            categories: categories,
            products: products,
            prices: prices
        )
    }

    private func fetchFixtureSuppliers(
        _ provider: SupabaseClientProvider,
        ownerUserID: UUID
    ) async throws -> [RemoteInventorySupplierRow] {
        try await provider.client
            .from("inventory_suppliers")
            .select("id,owner_user_id,name,updated_at,deleted_at")
            .eq("owner_user_id", value: ownerUserID.uuidString)
            .eq("name", value: Fixture.supplier)
            .order(SupabaseTransportClient.stablePageOrderColumn, ascending: true)
            .limit(10)
            .execute()
            .value
    }

    private func fetchFixtureCategories(
        _ provider: SupabaseClientProvider,
        ownerUserID: UUID
    ) async throws -> [RemoteInventoryCategoryRow] {
        try await provider.client
            .from("inventory_categories")
            .select("id,owner_user_id,name,updated_at,deleted_at")
            .eq("owner_user_id", value: ownerUserID.uuidString)
            .eq("name", value: Fixture.category)
            .order(SupabaseTransportClient.stablePageOrderColumn, ascending: true)
            .limit(10)
            .execute()
            .value
    }

    private func fetchFixtureProducts(
        _ provider: SupabaseClientProvider,
        ownerUserID: UUID
    ) async throws -> [RemoteInventoryProductRow] {
        try await provider.client
            .from("inventory_products")
            .select("id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at")
            .eq("owner_user_id", value: ownerUserID.uuidString)
            .in("barcode", values: [Fixture.barcodeA, Fixture.barcodeB])
            .order(SupabaseTransportClient.stablePageOrderColumn, ascending: true)
            .limit(10)
            .execute()
            .value
    }

    private func fetchFixturePrices(
        _ inventory: SupabaseTransportClient,
        ownerUserID: UUID,
        productIDs: [UUID]
    ) async throws -> [RemoteInventoryProductPriceRow] {
        guard !productIDs.isEmpty else { return [] }
        var rows: [RemoteInventoryProductPriceRow] = []
        for page in 0..<5 {
            let pageRows = try await inventory.fetchProductPricesForManualPushVerificationPage(
                ownerUserID: ownerUserID,
                productIDs: productIDs,
                from: page * 1_000,
                to: page * 1_000 + 999
            )
            rows.append(contentsOf: pageRows)
            if pageRows.count < 1_000 { break }
        }
        return rows
    }

    private func makePreview(
        for product: RemoteInventoryProductRow,
        snapshot: RemoteSnapshot
    ) -> SyncPreview {
        let payload = SyncPreviewProductApplyPayload(
            remoteID: product.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(product.updatedAt),
            remoteDeletedAt: SupabaseRemoteDateParser.parse(product.deletedAt),
            barcode: product.barcode,
            itemNumber: product.itemNumber,
            productName: product.productName,
            secondProductName: product.secondProductName,
            purchasePrice: product.purchasePrice,
            retailPrice: product.retailPrice,
            stockQuantity: product.stockQuantity,
            supplierName: product.supplierID.flatMap { id in snapshot.suppliers.first { $0.id == id }?.name },
            supplierRemoteID: product.supplierID,
            supplierRemoteUpdatedAt: product.supplierID
                .flatMap { id in snapshot.suppliers.first { $0.id == id }?.updatedAt }
                .flatMap(SupabaseRemoteDateParser.parse),
            supplierRemoteDeletedAt: product.supplierID
                .flatMap { id in snapshot.suppliers.first { $0.id == id }?.deletedAt }
                .flatMap(SupabaseRemoteDateParser.parse),
            categoryName: product.categoryID.flatMap { id in snapshot.categories.first { $0.id == id }?.name },
            categoryRemoteID: product.categoryID,
            categoryRemoteUpdatedAt: product.categoryID
                .flatMap { id in snapshot.categories.first { $0.id == id }?.updatedAt }
                .flatMap(SupabaseRemoteDateParser.parse),
            categoryRemoteDeletedAt: product.categoryID
                .flatMap { id in snapshot.categories.first { $0.id == id }?.deletedAt }
                .flatMap(SupabaseRemoteDateParser.parse)
        )
        let summary = SyncPreviewProductSummary(
            classification: .newProduct,
            remoteID: product.id,
            barcode: product.barcode,
            productName: product.productName,
            applyPayload: payload
        )
        return SyncPreview(
            generatedAt: Date(),
            outcome: .success,
            remoteCounts: RemoteInventorySnapshotCounts(
                products: 1,
                activeProducts: 1,
                tombstonedProducts: 0,
                suppliers: product.supplierID == nil ? 0 : 1,
                categories: product.categoryID == nil ? 0 : 1,
                productPrices: prices(in: snapshot, productID: product.id).count
            ),
            localCounts: LocalInventorySnapshotCounts(products: 0, suppliers: 0, categories: 0, productPrices: 0),
            newProducts: [summary],
            updateCandidates: [],
            conflicts: [],
            unchangedProducts: [],
            remoteTombstones: [],
            supplierDiffs: [],
            categoryDiffs: [],
            priceHistoryDiffs: [],
            warnings: [],
            metrics: [],
            sourceErrors: []
        )
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            ProductPrice.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self,
            LocalPendingChange.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        let context = ModelContext(container)
        Self.retainedContexts.append(context)
        return context
    }

    private func assertLocalPrices(
        context: ModelContext,
        barcode: String,
        expected: [ExpectedPoint],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let product = try XCTUnwrap(
            try context.fetch(FetchDescriptor<Product>()).first { $0.barcode == barcode },
            file: file,
            line: line
        )
        let prices = try context.fetch(FetchDescriptor<ProductPrice>())
            .filter { $0.product?.barcode == product.barcode }
        XCTAssertEqual(prices.count, expected.count, file: file, line: line)
        for expected in expected {
            let row = try XCTUnwrap(
                prices.first {
                    $0.type == expected.type &&
                        canonicalEffectiveAt($0.effectiveAt) == expected.effectiveAt
                },
                file: file,
                line: line
            )
            XCTAssertPrice(row.price, equals: expected.price, label: "\(barcode) \(expected.type) \(expected.effectiveAt)", file: file, line: line)
        }
    }

    private func assertRemotePrices(
        _ prices: [RemoteInventoryProductPriceRow],
        expected: [ExpectedPoint],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(prices.count, expected.count, file: file, line: line)
        for expected in expected {
            guard let row = prices.first(where: {
                $0.type.uppercased() == expected.type.rawValue.uppercased() &&
                    canonicalEffectiveAt($0.effectiveAt) == expected.effectiveAt
            }) else {
                XCTFail("Missing remote price \(expected.type.rawValue) \(expected.effectiveAt)", file: file, line: line)
                continue
            }
            XCTAssertPrice(row.price, equals: expected.price, label: "remote \(expected.type.rawValue) \(expected.effectiveAt)", file: file, line: line)
        }
    }

    private func activeSuppliers(in snapshot: RemoteSnapshot) -> [RemoteInventorySupplierRow] {
        snapshot.suppliers.filter { $0.deletedAt == nil && $0.name == Fixture.supplier }
    }

    private func activeCategories(in snapshot: RemoteSnapshot) -> [RemoteInventoryCategoryRow] {
        snapshot.categories.filter { $0.deletedAt == nil && $0.name == Fixture.category }
    }

    private func activeProducts(in snapshot: RemoteSnapshot, barcodes: Set<String>) -> [RemoteInventoryProductRow] {
        snapshot.products.filter { $0.deletedAt == nil && barcodes.contains($0.barcode) }
    }

    private func singleActiveSupplier(in snapshot: RemoteSnapshot) -> RemoteInventorySupplierRow? {
        let matches = activeSuppliers(in: snapshot)
        return matches.count == 1 ? matches[0] : nil
    }

    private func singleActiveCategory(in snapshot: RemoteSnapshot) -> RemoteInventoryCategoryRow? {
        let matches = activeCategories(in: snapshot)
        return matches.count == 1 ? matches[0] : nil
    }

    private func singleActiveProduct(in snapshot: RemoteSnapshot, barcode: String) -> RemoteInventoryProductRow? {
        let matches = activeProducts(in: snapshot, barcodes: [barcode])
        return matches.count == 1 ? matches[0] : nil
    }

    private func prices(in snapshot: RemoteSnapshot, productID: UUID) -> [RemoteInventoryProductPriceRow] {
        snapshot.prices.filter { $0.productID == productID }
    }

    private func expectedA() -> [ExpectedPoint] {
        [
            ExpectedPoint(type: .purchase, price: 41.11, effectiveAt: "2026-05-10 11:00:00"),
            ExpectedPoint(type: .purchase, price: 42.22, effectiveAt: "2026-05-10 11:05:00"),
            ExpectedPoint(type: .retail, price: 81.11, effectiveAt: "2026-05-10 11:10:00"),
            ExpectedPoint(type: .retail, price: 84.44, effectiveAt: "2026-05-10 11:15:00")
        ]
    }

    private func expectedB() -> [ExpectedPoint] {
        [
            ExpectedPoint(type: .purchase, price: 51.11, effectiveAt: "2026-05-10 11:20:00"),
            ExpectedPoint(type: .purchase, price: 55.55, effectiveAt: "2026-05-10 11:30:00"),
            ExpectedPoint(type: .retail, price: 101.11, effectiveAt: "2026-05-10 11:25:00"),
            ExpectedPoint(type: .retail, price: 111.10, effectiveAt: "2026-05-10 11:35:00")
        ]
    }

    private func date(_ value: String) throws -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return try XCTUnwrap(formatter.date(from: value))
    }

    private func canonicalEffectiveAt(_ value: String) -> String {
        String(value.replacingOccurrences(of: "T", with: " ").prefix(19))
    }

    private func canonicalEffectiveAt(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: value)
    }

    private func XCTAssertPrice(
        _ actual: Double?,
        equals expected: Double,
        label: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("\(label) missing", file: file, line: line)
            return
        }
        XCTAssertLessThanOrEqual(abs(actual - expected), Fixture.tolerance, label, file: file, line: line)
    }

    private func hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
            .prefix(12)
            .description
    }

    private func ownerHash(_ id: UUID) -> String {
        hash(id.uuidString.lowercased())
    }

    private func productPricePushFingerprint(_ plan: ProductPricePushDryRunPlan) -> String {
        let candidates = plan.candidates.map { line -> String in
            [
                line.key?.stableID ?? "",
                line.canonicalPrice?.value ?? "",
                line.createdAtCanonical ?? "",
                line.source ?? "",
                line.note ?? ""
            ].joined(separator: "|")
        }
        let summary = [
            "local:\(plan.summary.localPriceCount)",
            "ready:\(plan.summary.readyCandidates)",
            "present:\(plan.summary.alreadyPresentRemote)",
            "remoteConflict:\(plan.summary.conflictSameKeyDifferentPrice)",
            "localDuplicate:\(plan.summary.localDuplicateSameKey)",
            "localConflict:\(plan.summary.localConflictSameKeyDifferentPrice)",
            "blockedNoRemote:\(plan.summary.blockedNoRemoteID)",
            "blockedTotal:\(plan.summary.blockedTotal)",
            "invalid:\(plan.summary.excludedInvalidLocal)",
            "dedupe:\(dedupeFingerprintComponent(plan.remoteDedupeStatus))"
        ]
        return (candidates + summary).joined(separator: "\n")
    }

    private func dedupeFingerprintComponent(_ status: ProductPricePushRemoteDedupeStatus) -> String {
        switch status {
        case .notNeeded:
            return "notNeeded"
        case .complete:
            return "complete"
        case .unsafePartialRemoteDedupe(let reason):
            return "unsafe:\(reason.rawValue)"
        }
    }

    private struct Runtime {
        let config: SupabaseConfig
        let provider: SupabaseClientProvider
        let inventory: SupabaseTransportClient
        let session: SupabaseAuthSessionInfo
    }

    private struct RemoteSnapshot {
        let suppliers: [RemoteInventorySupplierRow]
        let categories: [RemoteInventoryCategoryRow]
        let products: [RemoteInventoryProductRow]
        let prices: [RemoteInventoryProductPriceRow]
    }

    private struct ExpectedPoint {
        let type: PriceType
        let price: Double
        let effectiveAt: String
    }
}

private extension SupabaseAuthService {
    static func sessionInfoForTask098(_ session: Session) -> SupabaseAuthSessionInfo {
        SupabaseAuthSessionInfo(
            userID: session.user.id,
            email: nil,
            provider: nil,
            isExpired: session.isExpired
        )
    }
}
