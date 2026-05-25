import CryptoKit
import Foundation
import SwiftData
import Supabase
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class Task103CrossPlatformAcceptanceTests: XCTestCase {
    private struct Fixture {
        let prefix: String
        let tolerance = 0.005
        var isTask104Pass2: Bool { prefix.hasPrefix("TASK104_PASS2_") }
        var isTask112: Bool { prefix.hasPrefix("TASK112_") }
        var isTask114: Bool { prefix.hasPrefix("TASK114_") }
        var isTask115: Bool { prefix.hasPrefix("TASK115_") }
        var isTask123: Bool { prefix.hasPrefix("TASK123_") }
        var logPrefix: String {
            if isTask123 {
                return "TASK123"
            }
            if isTask115 {
                return "TASK115"
            }
            if isTask114 {
                return "TASK114"
            }
            if isTask112 {
                return "TASK112"
            }
            return isTask104Pass2 ? "TASK104_PASS2" : "TASK103"
        }

        var supplierIOS: String { "\(prefix)SUP_IOS_01" }
        var categoryIOS: String { "\(prefix)CAT_IOS_01" }
        var productIOS: String { "\(prefix)CANARY_IOS_01" }
        var barcodeIOS: String { "\(prefix)IOS_0001" }

        var supplierAndroid: String { "\(prefix)SUP_ANDROID_01" }
        var categoryAndroid: String { "\(prefix)CAT_ANDROID_01" }
        var productAndroid: String { "\(prefix)CANARY_ANDROID_01" }
        var barcodeAndroid: String { "\(prefix)ANDROID_0001" }

        var matrixSupplierIOS: String { "\(prefix)MATRIX_SUP_IOS" }
        var matrixCategoryIOS: String { "\(prefix)MATRIX_CAT_IOS" }
        var matrixBarcodeIOSCreate: String { "\(prefix)MATRIX_IOS_CREATE" }
        var matrixBarcodeIOSUpdate: String { "\(prefix)MATRIX_IOS_UPDATE" }
        var matrixBarcodeIOSTombstone: String { "\(prefix)MATRIX_IOS_TOMBSTONE" }
        var matrixProductIOSCreate: String { "\(prefix)MATRIX_IOS_PRODUCT_CREATE" }
        var matrixProductIOSUpdateInitial: String { "\(prefix)MATRIX_IOS_PRODUCT_UPDATE_INITIAL" }
        var matrixProductIOSUpdateFinal: String { "\(prefix)MATRIX_IOS_PRODUCT_UPDATE_FINAL" }
        var matrixProductIOSTombstone: String { "\(prefix)MATRIX_IOS_PRODUCT_TOMBSTONE" }
        var matrixHistoryIOSCreate: String { "\(prefix)MATRIX_IOS_HISTORY_CREATE" }
        var matrixHistoryIOSUpdateInitial: String { "\(prefix)MATRIX_IOS_HISTORY_UPDATE_INITIAL" }
        var matrixHistoryIOSUpdateFinal: String { "\(prefix)MATRIX_IOS_HISTORY_UPDATE_FINAL" }
        var matrixHistoryIOSTombstone: String { "\(prefix)MATRIX_IOS_HISTORY_TOMBSTONE" }

        var matrixSupplierAndroid: String { "\(prefix)MATRIX_SUP_ANDROID" }
        var matrixCategoryAndroid: String { "\(prefix)MATRIX_CAT_ANDROID" }
        var matrixBarcodeAndroidCreate: String { "\(prefix)MATRIX_ANDROID_CREATE" }
        var matrixBarcodeAndroidUpdate: String { "\(prefix)MATRIX_ANDROID_UPDATE" }
        var matrixBarcodeAndroidTombstone: String { "\(prefix)MATRIX_ANDROID_TOMBSTONE" }
        var matrixProductAndroidCreate: String { "\(prefix)MATRIX_ANDROID_PRODUCT_CREATE" }
        var matrixProductAndroidUpdateFinal: String { "\(prefix)MATRIX_ANDROID_PRODUCT_UPDATE_FINAL" }
        var matrixProductAndroidTombstone: String { "\(prefix)MATRIX_ANDROID_PRODUCT_TOMBSTONE" }
        var matrixHistoryAndroidCreate: String { "\(prefix)MATRIX_ANDROID_HISTORY_CREATE" }
        var matrixHistoryAndroidUpdateFinal: String { "\(prefix)MATRIX_ANDROID_HISTORY_UPDATE_FINAL" }
        var matrixHistoryAndroidTombstone: String { "\(prefix)MATRIX_ANDROID_HISTORY_TOMBSTONE" }

        var mediumSuppliers: [String] { (1...5).map { "\(prefix)SUP_MEDIUM_\($0.padded3)" } }
        var mediumCategories: [String] { (1...5).map { "\(prefix)CAT_MEDIUM_\($0.padded3)" } }
        var mediumBarcodes: [String] { (1...50).map { mediumBarcode($0) } }
        var mediumCanaryBarcode: String { mediumBarcode(1) }
        var mediumCanaryProduct: String { "\(prefix)MEDIUM_PRODUCT_001" }

        var supplierConflictCatalog: String { "\(prefix)SUP_CONFLICT_G1" }
        var categoryConflictCatalog: String { "\(prefix)CAT_CONFLICT_G1" }
        var productConflictCatalog: String { "\(prefix)CANARY_CONFLICT_G1" }
        var barcodeConflictCatalog: String { "\(prefix)CONFLICT_0001" }

        var supplierConflictPrice: String { "\(prefix)SUP_CONFLICT_G2" }
        var categoryConflictPrice: String { "\(prefix)CAT_CONFLICT_G2" }
        var productConflictPrice: String { "\(prefix)CANARY_CONFLICT_G2" }
        var barcodeConflictPrice: String { "\(prefix)CONFLICT_0002" }

        var supplierOffline: String { "\(prefix)SUP_OFFLINE_01" }
        var categoryOffline: String { "\(prefix)CAT_OFFLINE_01" }
        var productOffline: String { "\(prefix)CANARY_OFFLINE_01" }
        var barcodeOffline: String { "\(prefix)OFFLINE_0001" }

        var supplierOfflineIOSSeed: String { "\(prefix)OFFLINE_IOS_SEED_SUPPLIER" }
        var categoryOfflineIOSSeed: String { "\(prefix)OFFLINE_IOS_SEED_CATEGORY" }
        var supplierOfflineIOSTombstone: String { "\(prefix)OFFLINE_IOS_TOMBSTONE_SUPPLIER" }
        var categoryOfflineIOSTombstone: String { "\(prefix)OFFLINE_IOS_TOMBSTONE_CATEGORY" }
        var supplierOfflineIOS: String { "\(prefix)OFFLINE_IOS_SUPPLIER" }
        var categoryOfflineIOS: String { "\(prefix)OFFLINE_IOS_CATEGORY" }
        var barcodeOfflineIOSCreate: String { "\(prefix)OFFLINE_IOS_CREATE" }
        var barcodeOfflineIOSUpdate: String { "\(prefix)OFFLINE_IOS_UPDATE" }
        var barcodeOfflineIOSTombstone: String { "\(prefix)OFFLINE_IOS_TOMBSTONE" }

        var allSupplierNames: [String] {
            [
                supplierIOS, supplierAndroid, supplierConflictCatalog, supplierConflictPrice, supplierOffline,
                matrixSupplierIOS, matrixSupplierAndroid,
                supplierOfflineIOSSeed, supplierOfflineIOSTombstone, supplierOfflineIOS
            ] + mediumSuppliers
        }

        var allCategoryNames: [String] {
            [
                categoryIOS, categoryAndroid, categoryConflictCatalog, categoryConflictPrice, categoryOffline,
                matrixCategoryIOS, matrixCategoryAndroid,
                categoryOfflineIOSSeed, categoryOfflineIOSTombstone, categoryOfflineIOS
            ] + mediumCategories
        }

        var allBarcodes: [String] {
            [
                barcodeIOS, barcodeAndroid, barcodeConflictCatalog, barcodeConflictPrice, barcodeOffline,
                matrixBarcodeIOSCreate, matrixBarcodeIOSUpdate, matrixBarcodeIOSTombstone,
                matrixBarcodeAndroidCreate, matrixBarcodeAndroidUpdate, matrixBarcodeAndroidTombstone,
                barcodeOfflineIOSCreate, barcodeOfflineIOSUpdate, barcodeOfflineIOSTombstone
            ] + mediumBarcodes
        }

        func mediumBarcode(_ index: Int) -> String {
            "\(prefix)MEDIUM_\(index.padded3)"
        }
    }

    private static var retainedContainers: [ModelContainer] = []
    private static var retainedContexts: [ModelContext] = []

    func test01PreflightAndCollisionScanReadOnly() async throws {
        try requireLiveAcceptanceEnabled()
        let fixture = try makeFixture()
        let runtime = try await makeRuntime()
        let snapshot = try await fetchRemoteSnapshot(runtime, fixture: fixture)

        XCTAssertFalse(runtime.config.publishableKey.lowercased().contains("service_role"))
        XCTAssertFalse(runtime.config.publishableKey.lowercased().contains("secret_key"))
        XCTAssertFalse(runtime.config.publishableKey.lowercased().contains("sb_secret"))
        XCTAssertFalse(runtime.session.isExpired)

        XCTAssertEqual(activeSuppliers(in: snapshot, fixture: fixture).count, 0)
        XCTAssertEqual(activeCategories(in: snapshot, fixture: fixture).count, 0)
        XCTAssertEqual(activeProducts(in: snapshot, barcodes: Set(fixture.allBarcodes)).count, 0)
        XCTAssertTrue(snapshot.prices.isEmpty)

        print(
            "\(fixture.logPrefix)_IOS_COLLISION project_hash=\(hash(runtime.config.projectURL.absoluteString)) " +
            "owner_hash=\(ownerHash(runtime.session.userID)) prefix_hash=\(hash(fixture.prefix)) collision=free"
        )
    }

    func test02IOSWriteSmokeAndRemoteReadBack() async throws {
        try requireLiveAcceptanceEnabled()
        let fixture = try makeFixture()
        let runtime = try await makeRuntime()

        let context = try makeContext()
        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: context,
            ownerUserUUID: runtime.session.userID
        )

        let supplier = Supplier(name: fixture.supplierIOS)
        let category = ProductCategory(name: fixture.categoryIOS)
        context.insert(supplier)
        context.insert(category)

        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: runtime.session.userID)
        try accumulator.recordSupplierChange(
            supplier: supplier,
            operation: .create,
            origin: .manualCatalogSave
        )
        try accumulator.recordCategoryChange(
            category: category,
            operation: .create,
            origin: .manualCatalogSave
        )

        let product = Product(
            barcode: fixture.barcodeIOS,
            itemNumber: "\(fixture.prefix)ITEM_IOS_0001",
            productName: fixture.productIOS,
            purchasePrice: 12.35,
            retailPrice: 20.50,
            stockQuantity: 7,
            supplier: supplier,
            category: category
        )
        context.insert(product)
        try accumulator.recordProductChange(
            product: product,
            operation: .create,
            origin: .manualCatalogSave,
            changedFields: [
                "barcode",
                "itemNumber",
                "productName",
                "purchasePrice",
                "retailPrice",
                "stockQuantity",
                "supplier",
                "category"
            ]
        )
        try context.save()

        let catalogPush = try await pushPendingCatalog(
            context: context,
            runtime: runtime,
            expectedReadyCandidatesAtLeast: 3
        )
        XCTAssertEqual(catalogPush.status, .completed)
        XCTAssertNotNil(product.remoteID)

        try insertPrices(expectedIOS(), product: product, context: context, ownerUserID: runtime.session.userID)
        let pricePush = try await pushPendingPrices(context: context, runtime: runtime)
        XCTAssertTrue(pricePush.isVerifiedSuccess)
        XCTAssertEqual(pricePush.insertedCount, 4)

        let readBack = try await fetchRemoteSnapshot(runtime, fixture: fixture)
        let remote = try XCTUnwrap(singleActiveProduct(in: readBack, barcode: fixture.barcodeIOS))
        XCTAssertEqual(remote.productName, fixture.productIOS)
        XCTAssertPrice(remote.purchasePrice, equals: 12.35, label: "iOS remote catalog purchase", fixture: fixture)
        XCTAssertPrice(remote.retailPrice, equals: 20.50, label: "iOS remote catalog retail", fixture: fixture)
        assertRemotePrices(prices(in: readBack, productID: remote.id), expected: expectedIOS(), fixture: fixture)

        let noOp = try await LocalPendingAggregatedPushPlanner(
            context: context,
            priceRemoteFetcher: runtime.productPriceRemote,
            includesCatalog: true,
            includesProductPrice: true
        ).makePlan(ownerUserID: runtime.session.userID)
        XCTAssertNil(noOp.catalogBatch)
        XCTAssertNil(noOp.productPriceBatch)
        XCTAssertTrue(noOp.blockers.isEmpty)

        print(
            "\(fixture.logPrefix)_IOS_WRITE_SMOKE owner_hash=\(ownerHash(runtime.session.userID)) " +
            "product_hash=\(hash(remote.id.uuidString.lowercased())) price_inserted=\(pricePush.insertedCount) no_op=true"
        )
    }

    func test03IOSPullApplyAndroidSmokeAndNoOp() async throws {
        try requireLiveAcceptanceEnabled()
        let fixture = try makeFixture()
        let runtime = try await makeRuntime()
        let snapshot = try await fetchRemoteSnapshot(runtime, fixture: fixture)
        let remote = try XCTUnwrap(singleActiveProduct(in: snapshot, barcode: fixture.barcodeAndroid))
        let remotePrices = prices(in: snapshot, productID: remote.id)

        XCTAssertEqual(remote.productName, fixture.productAndroid)
        assertRemotePrices(remotePrices, expected: expectedAndroid(), fixture: fixture)

        let context = try makeContext()
        let preview = makePreview(for: remote, snapshot: snapshot)
        let plan = try SupabasePullApplyService().prepareApplyPlan(
            preview: preview,
            context: context,
            isAuthenticated: true,
            accountGuard: SupabasePullApplyAccountGuard(
                currentUserID: runtime.session.userID,
                lastLinkedUserID: runtime.session.userID
            )
        )
        let result = try SupabasePullApplyService().apply(plan: plan, context: context)
        XCTAssertEqual(result.inserted, 1)

        let pricePlan = try SupabaseProductPriceApplyService().prepareApplyPlan(
            remoteRows: remotePrices,
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
        try assertLocalPrices(context: context, barcode: fixture.barcodeAndroid, expected: expectedAndroid(), fixture: fixture)

        let noOpPreview = makeNoOpPreview(for: remote, snapshot: snapshot)
        XCTAssertThrowsError(
            try SupabasePullApplyService().prepareApplyPlan(
                preview: noOpPreview,
                context: context,
                isAuthenticated: true,
                accountGuard: SupabasePullApplyAccountGuard(
                    currentUserID: runtime.session.userID,
                    lastLinkedUserID: runtime.session.userID
                )
            )
        ) { error in
            XCTAssertEqual(error as? SupabasePullApplyError, .noApplicableChanges)
        }

        let priceNoOpPlan = try SupabaseProductPriceApplyService().prepareApplyPlan(
            remoteRows: remotePrices,
            context: context,
            sessionSnapshot: ProductPriceApplySessionSnapshot(userID: runtime.session.userID)
        )
        XCTAssertFalse(priceNoOpPlan.isApplyAllowed)
        XCTAssertEqual(priceNoOpPlan.blockReasons, [.noApplicableRows])
        XCTAssertEqual(priceNoOpPlan.summary.skippedExisting, 4)

        print(
            "\(fixture.logPrefix)_IOS_PULL_ANDROID owner_hash=\(ownerHash(runtime.session.userID)) " +
            "inserted_catalog=\(result.inserted) inserted_prices=\(priceResult.inserted) no_op=true"
        )
    }

    func test114IOSFullPullMaterializesRemoteLookupOnlyRowsInAppStore() async throws {
        try requireTask114IOSFullPullEnabled()
        let runtime = try await makeRuntime()
        let context = try makePersistentAppContext()
        let before = try task114LocalCounts(context: context)
        let service = SupabasePullPreviewService(
            inventoryService: runtime.recoveryRemote,
            pageSize: 1_000,
            catalogRowBudget: nil,
            productPricePreviewSampleLimit: 1_000
        )

        let state = await service.generatePreview(modelContainer: context.container)
        let preview: SyncPreview
        switch state {
        case .success(let successfulPreview):
            preview = successfulPreview
        case .partial(_, let warnings, let sourceErrors):
            XCTFail("TASK114 iOS full pull requires a complete catalog preview. warnings=\(warnings.count) sourceErrors=\(sourceErrors.count)")
            return
        case .failed(let error):
            XCTFail("TASK114 iOS full pull preview failed: \(error.safeDiagnosticDetail ?? "redacted")")
            return
        case .idle, .loading:
            XCTFail("TASK114 iOS full pull preview returned a non-terminal state.")
            return
        }

        let plan: SupabasePullApplyPlan?
        do {
            plan = try SupabasePullApplyService().prepareApplyPlan(
                preview: preview,
                context: context,
                isAuthenticated: true,
                accountGuard: SupabasePullApplyAccountGuard(
                    currentUserID: runtime.session.userID,
                    lastLinkedUserID: runtime.session.userID
                )
            )
        } catch let error as SupabasePullApplyError where error == .noApplicableChanges {
            plan = nil
        }

        let result: SupabasePullApplyResult
        if let plan {
            result = try await SupabasePullApplyService().applyBatched(plan: plan, context: context)
            _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
                context: context,
                ownerUserUUID: runtime.session.userID
            )
        } else {
            result = SupabasePullApplyResult(inserted: 0, updated: 0, suppliersCreated: 0, categoriesCreated: 0)
        }
        let historyResult = try await HistorySessionSyncService(remote: HistorySessionRemoteSupabaseAdapter(remote: runtime.inventory))
            .pullHistorySessionsFromCloud(ownerUserID: runtime.session.userID, context: context)
        let priceService = SupabaseProductPriceApplyService(fetcher: runtime.productPriceRemote)
        let priceSession = ProductPriceApplySessionSnapshot(userID: runtime.session.userID)
        let pricePlan = try await priceService.loadBootstrapPreviewSample(
            context: context,
            sessionSnapshot: priceSession
        )
        let priceResult = try await priceService.applyPagedFullPull(
            plan: pricePlan,
            context: context,
            currentSessionSnapshot: priceSession
        )

        let after = try task114LocalCounts(context: ModelContext(context.container))
        XCTAssertEqual(after.products, preview.remoteCounts.activeProducts)
        XCTAssertEqual(after.suppliers, preview.remoteCounts.suppliers)
        XCTAssertEqual(after.categories, preview.remoteCounts.categories)
        XCTAssertLessThanOrEqual(after.productPrices, priceResult.totalConsidered)

        print(
            "TASK114_IOS_FULL_PULL_LOOKUPS owner_hash=\(ownerHash(runtime.session.userID)) " +
            "before_suppliers=\(before.suppliers) before_categories=\(before.categories) " +
            "before_prices=\(before.productPrices) " +
            "remote_suppliers=\(preview.remoteCounts.suppliers) remote_categories=\(preview.remoteCounts.categories) " +
            "planned_suppliers=\(plan?.suppliersToCreate.count ?? 0) planned_categories=\(plan?.categoriesToCreate.count ?? 0) " +
            "suppliers_created=\(result.suppliersCreated) categories_created=\(result.categoriesCreated) " +
            "products_inserted=\(result.inserted) products_updated=\(result.updated) product_tombstoned=\(result.productTombstoned) " +
            "product_pruned=\(result.productPruned) " +
            "price_inserted=\(priceResult.inserted) price_linked=\(priceResult.remoteIdentityLinked) price_pruned=\(priceResult.prunedLocal) " +
            "price_skipped=\(priceResult.skippedExisting) price_total=\(priceResult.totalConsidered) after_prices=\(after.productPrices) " +
            "history_inserted=\(historyResult.insertedCount) history_updated=\(historyResult.updatedCount) history_pruned=\(historyResult.prunedMissingRemoteCount) " +
            "after_products=\(after.products) after_suppliers=\(after.suppliers) after_categories=\(after.categories) after_history_user_visible=\(after.userVisibleHistory)"
        )
    }

    func test114IOSPullAndroidProductHistoryMatrix() async throws {
        try requireLiveAcceptanceEnabled()
        let fixture = try makeFixture()
        let runtime = try await makeRuntime()
        let snapshot = try await fetchRemoteSnapshot(runtime, fixture: fixture)
        let context = try makeContext()

        let createRemote = try XCTUnwrap(product(in: snapshot, barcode: fixture.matrixBarcodeAndroidCreate))
        XCTAssertNil(createRemote.deletedAt)
        let createApply = try applyProductCreate(createRemote, snapshot: snapshot, context: context, ownerUserID: runtime.session.userID)
        XCTAssertEqual(createApply.inserted, 1)

        let updateRemote = try XCTUnwrap(product(in: snapshot, barcode: fixture.matrixBarcodeAndroidUpdate))
        XCTAssertNil(updateRemote.deletedAt)
        try seedLocalProduct(
            remote: updateRemote,
            snapshot: snapshot,
            context: context,
            staleName: "TASK114_IOS_STALE_ANDROID_UPDATE"
        )
        let updateApply = try applyProductUpdate(updateRemote, snapshot: snapshot, context: context, ownerUserID: runtime.session.userID)
        XCTAssertEqual(updateApply.updated, 1)
        XCTAssertEqual(try localProduct(context: context, barcode: fixture.matrixBarcodeAndroidUpdate)?.productName, fixture.matrixProductAndroidUpdateFinal)

        let tombstoneRemote = try XCTUnwrap(product(in: snapshot, barcode: fixture.matrixBarcodeAndroidTombstone))
        XCTAssertNotNil(tombstoneRemote.deletedAt)
        let localTombstoneProduct = try seedLocalProduct(
            remote: tombstoneRemote,
            snapshot: snapshot,
            context: context,
            staleName: fixture.matrixProductAndroidTombstone
        )
        let tombstoneApply = try applyProductTombstone(tombstoneRemote, snapshot: snapshot, context: context, ownerUserID: runtime.session.userID)
        XCTAssertEqual(tombstoneApply.productTombstoned, 1)
        XCTAssertNotNil(localTombstoneProduct.remoteDeletedAt)

        let sessions = try await fetchFixtureSessions(runtime, fixture: fixture)
        let historyService = HistorySessionSyncService(remote: HistorySessionRemoteSupabaseAdapter(remote: runtime.inventory))

        let historyCreate = try XCTUnwrap(session(in: sessions, displayName: fixture.matrixHistoryAndroidCreate))
        let historyCreateApply = try historyService.applyRemoteSharedSheetSessions([historyCreate], ownerUserID: runtime.session.userID, context: context)
        XCTAssertEqual(historyCreateApply.insertedCount, 1)

        let historyUpdate = try XCTUnwrap(session(in: sessions, displayName: fixture.matrixHistoryAndroidUpdateFinal))
        _ = try seedLocalHistoryEntry(remote: historyUpdate, context: context, title: "TASK114_IOS_STALE_ANDROID_HISTORY_UPDATE")
        let historyUpdateApply = try historyService.applyRemoteSharedSheetSessions([historyUpdate], ownerUserID: runtime.session.userID, context: context)
        XCTAssertEqual(historyUpdateApply.updatedCount, 1)
        XCTAssertEqual(try localHistoryEntry(context: context, remoteID: historyUpdate.remoteID)?.title, fixture.matrixHistoryAndroidUpdateFinal)

        let historyTombstone = try XCTUnwrap(session(in: sessions, displayName: fixture.matrixHistoryAndroidTombstone))
        XCTAssertNotNil(historyTombstone.deletedAt)
        let localTombstoneHistory = try seedLocalHistoryEntry(remote: historyTombstone, context: context, title: fixture.matrixHistoryAndroidTombstone)
        let historyTombstoneApply = try historyService.applyRemoteSharedSheetSessions([historyTombstone], ownerUserID: runtime.session.userID, context: context)
        XCTAssertEqual(historyTombstoneApply.updatedCount, 1)
        XCTAssertNotNil(localTombstoneHistory.remoteDeletedAt)

        print(
            "\(fixture.logPrefix)_IOS_PULL_ANDROID_MATRIX owner_hash=\(ownerHash(runtime.session.userID)) " +
            "product_create=pass product_update=pass product_tombstone=pass " +
            "history_create=pass history_update=pass history_tombstone=pass"
        )
    }

    func test114IOSWriteProductHistoryMatrix() async throws {
        try requireLiveAcceptanceEnabled()
        let matrixStarted = Date()
        let fixture = try makeFixture()
        let runtime = try await makeRuntime()
        let context = try makeContext()
        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: context,
            ownerUserUUID: runtime.session.userID
        )

        let localCatalogSaveStarted = Date()
        let supplier = Supplier(name: fixture.matrixSupplierIOS)
        let category = ProductCategory(name: fixture.matrixCategoryIOS)
        context.insert(supplier)
        context.insert(category)
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: runtime.session.userID)
        try accumulator.recordSupplierChange(supplier: supplier, operation: .create, origin: .manualCatalogSave)
        try accumulator.recordCategoryChange(category: category, operation: .create, origin: .manualCatalogSave)

        let createProduct = matrixProduct(
            barcode: fixture.matrixBarcodeIOSCreate,
            name: fixture.matrixProductIOSCreate,
            supplier: supplier,
            category: category
        )
        let updateProduct = matrixProduct(
            barcode: fixture.matrixBarcodeIOSUpdate,
            name: fixture.matrixProductIOSUpdateInitial,
            supplier: supplier,
            category: category
        )
        let tombstoneProduct = matrixProduct(
            barcode: fixture.matrixBarcodeIOSTombstone,
            name: fixture.matrixProductIOSTombstone,
            supplier: supplier,
            category: category
        )
        for product in [createProduct, updateProduct, tombstoneProduct] {
            context.insert(product)
            try accumulator.recordProductChange(
                product: product,
                operation: .create,
                origin: .manualCatalogSave,
                changedFields: ["barcode", "productName", "supplier", "category", "purchasePrice", "retailPrice", "stockQuantity"]
            )
        }
        try context.save()
        let localCatalogSaveMs = Int(Date().timeIntervalSince(localCatalogSaveStarted) * 1000)
        let initialCatalogPushStarted = Date()
        let initialCatalogPush = try await pushPendingCatalog(context: context, runtime: runtime, expectedReadyCandidatesAtLeast: 5)
        let initialCatalogPushMs = Int(Date().timeIntervalSince(initialCatalogPushStarted) * 1000)
        XCTAssertEqual(initialCatalogPush.status, .completed)

        try insertPrices(expectedIOS(), product: createProduct, context: context, ownerUserID: runtime.session.userID)
        try insertPrices(expectedIOS(), product: updateProduct, context: context, ownerUserID: runtime.session.userID)
        let initialPricePushStarted = Date()
        let initialPricePush = try await pushPendingPrices(context: context, runtime: runtime)
        let initialPricePushMs = Int(Date().timeIntervalSince(initialPricePushStarted) * 1000)
        XCTAssertTrue(initialPricePush.isVerifiedSuccess)
        XCTAssertEqual(initialPricePush.confirmedRemoteIDs.count, 8)

        updateProduct.productName = fixture.matrixProductIOSUpdateFinal
        try accumulator.recordProductChange(
            product: updateProduct,
            operation: .update,
            origin: .manualCatalogSave,
            changedFields: ["productName"]
        )
        try context.save()
        let updateCatalogPushStarted = Date()
        let updateCatalogPush = try await pushPendingCatalog(context: context, runtime: runtime, expectedReadyCandidatesAtLeast: 1)
        let updateCatalogPushMs = Int(Date().timeIntervalSince(updateCatalogPushStarted) * 1000)
        XCTAssertEqual(updateCatalogPush.status, .completed)

        try insertPrices(
            [ExpectedPoint(type: .purchase, price: 47.70, effectiveAt: "2026-05-12 13:45:00")],
            product: updateProduct,
            context: context,
            ownerUserID: runtime.session.userID
        )
        let correctionPricePushStarted = Date()
        let correctionPricePush = try await pushPendingPrices(context: context, runtime: runtime)
        let correctionPricePushMs = Int(Date().timeIntervalSince(correctionPricePushStarted) * 1000)
        XCTAssertTrue(correctionPricePush.isVerifiedSuccess)
        XCTAssertEqual(correctionPricePush.confirmedRemoteIDs.count, 1)

        let tombstoneBaseline = LocalPendingChangeLogicalKey.productFingerprintHash(tombstoneProduct)
        try accumulator.recordProductChange(
            product: tombstoneProduct,
            operation: .delete,
            origin: .manualCatalogSave,
            changedFields: ["tombstone"],
            baselineFingerprintHash: tombstoneBaseline
        )
        context.delete(tombstoneProduct)
        try context.save()
        let tombstoneCatalogPushStarted = Date()
        let tombstoneCatalogPush = try await pushPendingCatalog(context: context, runtime: runtime, expectedReadyCandidatesAtLeast: 1)
        let tombstoneCatalogPushMs = Int(Date().timeIntervalSince(tombstoneCatalogPushStarted) * 1000)
        XCTAssertEqual(tombstoneCatalogPush.status, .completed)

        let localHistorySaveStarted = Date()
        let historyCreate = matrixHistoryEntry(title: fixture.matrixHistoryIOSCreate, fixture: fixture)
        let historyUpdate = matrixHistoryEntry(title: fixture.matrixHistoryIOSUpdateInitial, fixture: fixture)
        let historyTombstone = matrixHistoryEntry(title: fixture.matrixHistoryIOSTombstone, fixture: fixture)
        for entry in [historyCreate, historyUpdate, historyTombstone] {
            context.insert(entry)
            entry.markHistorySessionLocalMutation()
            try accumulator.recordHistorySessionChange(entry: entry, operation: .upsert, changedFields: ["create"])
        }
        try context.save()
        let localHistorySaveMs = Int(Date().timeIntervalSince(localHistorySaveStarted) * 1000)
        let initialHistoryPushStarted = Date()
        let initialHistoryPush = try await pushPendingHistory([historyCreate, historyUpdate, historyTombstone], context: context, runtime: runtime)
        let initialHistoryPushMs = Int(Date().timeIntervalSince(initialHistoryPushStarted) * 1000)
        XCTAssertEqual(initialHistoryPush.uploadedCount, 3)

        historyUpdate.title = fixture.matrixHistoryIOSUpdateFinal
        historyUpdate.markHistorySessionLocalMutation()
        try accumulator.recordHistorySessionChange(entry: historyUpdate, operation: .upsert, changedFields: ["displayName"])
        try context.save()
        let updateHistoryPushStarted = Date()
        let updateHistoryPush = try await pushPendingHistory([historyUpdate], context: context, runtime: runtime)
        let updateHistoryPushMs = Int(Date().timeIntervalSince(updateHistoryPushStarted) * 1000)
        XCTAssertEqual(updateHistoryPush.uploadedCount, 1)

        historyTombstone.markHistorySessionLocalDeletion()
        try accumulator.recordHistorySessionChange(entry: historyTombstone, operation: .delete, changedFields: ["tombstone"])
        try context.save()
        let tombstoneHistoryPushStarted = Date()
        let tombstoneHistoryPush = try await pushPendingHistory([historyTombstone], context: context, runtime: runtime)
        let tombstoneHistoryPushMs = Int(Date().timeIntervalSince(tombstoneHistoryPushStarted) * 1000)
        XCTAssertEqual(tombstoneHistoryPush.uploadedCount, 1)

        let readBack = try await fetchRemoteSnapshot(runtime, fixture: fixture)
        let remoteCreate = try XCTUnwrap(singleActiveProduct(in: readBack, barcode: fixture.matrixBarcodeIOSCreate))
        XCTAssertEqual(remoteCreate.productName, fixture.matrixProductIOSCreate)
        assertRemotePrices(prices(in: readBack, productID: remoteCreate.id), expected: expectedIOS(), fixture: fixture)
        XCTAssertEqual(try XCTUnwrap(singleActiveProduct(in: readBack, barcode: fixture.matrixBarcodeIOSUpdate)).productName, fixture.matrixProductIOSUpdateFinal)
        XCTAssertNotNil(try XCTUnwrap(product(in: readBack, barcode: fixture.matrixBarcodeIOSTombstone)).deletedAt)

        let sessions = try await fetchFixtureSessions(runtime, fixture: fixture)
        XCTAssertNotNil(session(in: sessions, displayName: fixture.matrixHistoryIOSCreate))
        XCTAssertNotNil(session(in: sessions, displayName: fixture.matrixHistoryIOSUpdateFinal))
        XCTAssertNotNil(try XCTUnwrap(session(in: sessions, displayName: fixture.matrixHistoryIOSTombstone)).deletedAt)

        print(
            "\(fixture.logPrefix)_IOS_WRITE_MATRIX owner_hash=\(ownerHash(runtime.session.userID)) " +
            "product_create=pass product_update=pass product_tombstone=pass " +
            "product_price_create=pass product_price_correction=pass product_price_tombstone=not_supported_append_only " +
            "history_create=pass history_update=pass history_tombstone=pass"
        )
        print(
            "\(fixture.logPrefix)_IOS_WRITE_TIMINGS " +
            "localCatalogSaveMs=\(localCatalogSaveMs) " +
            "catalogPushAndEventsMs=\(initialCatalogPushMs + updateCatalogPushMs + tombstoneCatalogPushMs) " +
            "pricePushAndEventsMs=\(initialPricePushMs + correctionPricePushMs) " +
            "localHistorySaveMs=\(localHistorySaveMs) " +
            "historyPushAndEventsMs=\(initialHistoryPushMs + updateHistoryPushMs + tombstoneHistoryPushMs) " +
            "totalMatrixMs=\(Int(Date().timeIntervalSince(matrixStarted) * 1000)) " +
            "syncType=EVENT_INCREMENTAL fullPull=false"
        )
    }

    func test114IOSOfflineReconnectProductPriceHistoryMatrix() async throws {
        try requireLiveAcceptanceEnabled()
        let fixture = try makeFixture()
        let runtime = try await makeRuntime()
        let context = try makeContext()
        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: context,
            ownerUserUUID: runtime.session.userID
        )

        let seedUpdate = try await createCatalogCanary(
            context: context,
            runtime: runtime,
            supplierName: "\(fixture.prefix)OFFLINE_IOS_SEED_SUPPLIER",
            categoryName: "\(fixture.prefix)OFFLINE_IOS_SEED_CATEGORY",
            productName: "\(fixture.prefix)OFFLINE_IOS_UPDATE_INITIAL",
            barcode: "\(fixture.prefix)OFFLINE_IOS_UPDATE",
            itemNumber: "\(fixture.prefix)OFFLINE_IOS_UPDATE_ITEM",
            purchasePrice: 52,
            retailPrice: 62,
            stockQuantity: 4
        )
        let seedTombstone = try await createCatalogCanary(
            context: context,
            runtime: runtime,
            supplierName: "\(fixture.prefix)OFFLINE_IOS_TOMBSTONE_SUPPLIER",
            categoryName: "\(fixture.prefix)OFFLINE_IOS_TOMBSTONE_CATEGORY",
            productName: "\(fixture.prefix)OFFLINE_IOS_TOMBSTONE_PRODUCT",
            barcode: "\(fixture.prefix)OFFLINE_IOS_TOMBSTONE",
            itemNumber: "\(fixture.prefix)OFFLINE_IOS_TOMBSTONE_ITEM",
            purchasePrice: 53,
            retailPrice: 63,
            stockQuantity: 5
        )

        let seededHistoryUpdate = matrixHistoryEntry(title: "\(fixture.prefix)OFFLINE_IOS_HISTORY_UPDATE_INITIAL", fixture: fixture)
        let seededHistoryTombstone = matrixHistoryEntry(title: "\(fixture.prefix)OFFLINE_IOS_HISTORY_TOMBSTONE", fixture: fixture)
        context.insert(seededHistoryUpdate)
        context.insert(seededHistoryTombstone)
        seededHistoryUpdate.markHistorySessionLocalMutation()
        seededHistoryTombstone.markHistorySessionLocalMutation()
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: runtime.session.userID)
        try accumulator.recordHistorySessionChange(entry: seededHistoryUpdate, operation: .upsert, changedFields: ["seed"])
        try accumulator.recordHistorySessionChange(entry: seededHistoryTombstone, operation: .upsert, changedFields: ["seed"])
        try context.save()
        let seedHistoryPush = try await pushPendingHistory([seededHistoryUpdate, seededHistoryTombstone], context: context, runtime: runtime)
        XCTAssertEqual(seedHistoryPush.uploadedCount, 2)

        let localSaveStarted = Date()
        let offlineSupplier = Supplier(name: "\(fixture.prefix)OFFLINE_IOS_SUPPLIER")
        let offlineCategory = ProductCategory(name: "\(fixture.prefix)OFFLINE_IOS_CATEGORY")
        context.insert(offlineSupplier)
        context.insert(offlineCategory)
        try accumulator.recordSupplierChange(supplier: offlineSupplier, operation: .create, origin: .manualCatalogSave)
        try accumulator.recordCategoryChange(category: offlineCategory, operation: .create, origin: .manualCatalogSave)

        let createProduct = matrixProduct(
            barcode: "\(fixture.prefix)OFFLINE_IOS_CREATE",
            name: "\(fixture.prefix)OFFLINE_IOS_CREATE_PRODUCT",
            supplier: offlineSupplier,
            category: offlineCategory
        )
        context.insert(createProduct)
        try accumulator.recordProductChange(
            product: createProduct,
            operation: .create,
            origin: .manualCatalogSave,
            changedFields: ["barcode", "productName", "supplier", "category", "purchasePrice", "retailPrice", "stockQuantity"]
        )

        seedUpdate.productName = "\(fixture.prefix)OFFLINE_IOS_UPDATE_FINAL"
        try accumulator.recordProductChange(
            product: seedUpdate,
            operation: .update,
            origin: .manualCatalogSave,
            changedFields: ["productName"]
        )

        let tombstoneBaseline = LocalPendingChangeLogicalKey.productFingerprintHash(seedTombstone)
        try accumulator.recordProductChange(
            product: seedTombstone,
            operation: .delete,
            origin: .manualCatalogSave,
            changedFields: ["tombstone"],
            baselineFingerprintHash: tombstoneBaseline
        )
        context.delete(seedTombstone)

        try insertPrices(expectedIOS(), product: createProduct, context: context, ownerUserID: runtime.session.userID)
        try insertPrices(
            [ExpectedPoint(type: .purchase, price: 58.80, effectiveAt: "2026-05-12 15:45:00")],
            product: seedUpdate,
            context: context,
            ownerUserID: runtime.session.userID
        )

        let historyCreate = matrixHistoryEntry(title: "\(fixture.prefix)OFFLINE_IOS_HISTORY_CREATE", fixture: fixture)
        context.insert(historyCreate)
        historyCreate.markHistorySessionLocalMutation()
        try accumulator.recordHistorySessionChange(entry: historyCreate, operation: .upsert, changedFields: ["create"])
        seededHistoryUpdate.title = "\(fixture.prefix)OFFLINE_IOS_HISTORY_UPDATE_FINAL"
        seededHistoryUpdate.markHistorySessionLocalMutation()
        try accumulator.recordHistorySessionChange(entry: seededHistoryUpdate, operation: .upsert, changedFields: ["displayName"])
        seededHistoryTombstone.markHistorySessionLocalDeletion()
        try accumulator.recordHistorySessionChange(entry: seededHistoryTombstone, operation: .delete, changedFields: ["tombstone"])
        try context.save()
        let localSaveMs = Int(Date().timeIntervalSince(localSaveStarted) * 1000)

        let pendingBefore = try LocalPendingChangeSnapshotProvider(context: context)
            .loadSnapshot(ownerUserID: runtime.session.userID)
        XCTAssertGreaterThanOrEqual(pendingBefore.pendingCatalogChangeCount, 3)
        XCTAssertGreaterThanOrEqual(pendingBefore.pendingProductPriceChangeCount, 1)
        XCTAssertGreaterThanOrEqual(pendingBefore.pendingHistorySessionChangeCount, 3)

        let offlinePlan = try await LocalPendingAggregatedPushPlanner(
            context: context,
            includesCatalog: true,
            includesProductPrice: true
        ).makePlan(ownerUserID: runtime.session.userID)
        let offlineBatch = try XCTUnwrap(offlinePlan.catalogBatch)
        let stateStore = LocalPendingAggregatedPushStateStore(context: context)
        try stateStore.markSent(
            changeIDs: offlineBatch.changeIDs,
            ownerUserID: runtime.session.userID,
            planFingerprint: offlineBatch.plan.planFingerprint
        )
        let offlineResult = await SupabaseManualPushService(
            remote: Task103NetworkDownManualPushRemoteGateway()
        ).execute(
            plan: offlineBatch.plan,
            context: context,
            ownerUserID: runtime.session.userID
        )
        XCTAssertEqual(offlineResult.status, .failedBeforeWrite)
        try stateStore.markRetryable(changeIDs: offlineBatch.changeIDs, ownerUserID: runtime.session.userID)

        let reconnectStarted = Date()
        let catalogPush = try await pushPendingCatalog(context: context, runtime: runtime, expectedReadyCandidatesAtLeast: 3)
        XCTAssertEqual(catalogPush.status, .completed)
        let pricePush = try await pushPendingPrices(context: context, runtime: runtime)
        XCTAssertTrue(pricePush.isVerifiedSuccess)
        XCTAssertGreaterThanOrEqual(pricePush.confirmedRemoteIDs.count, 1)
        let historyPush = try await pushPendingHistory(
            [historyCreate, seededHistoryUpdate, seededHistoryTombstone],
            context: context,
            runtime: runtime
        )
        XCTAssertGreaterThanOrEqual(historyPush.uploadedCount, 3)
        let remotePushMs = Int(Date().timeIntervalSince(reconnectStarted) * 1000)

        let pendingAfter = try LocalPendingChangeSnapshotProvider(context: context)
            .loadSnapshot(ownerUserID: runtime.session.userID)
        XCTAssertEqual(pendingAfter.pendingCatalogChangeCount, 0)
        XCTAssertEqual(pendingAfter.pendingProductPriceChangeCount, 0)
        XCTAssertEqual(pendingAfter.pendingHistorySessionChangeCount, 0)

        let readBack = try await fetchRemoteSnapshot(runtime, fixture: fixture)
        let remoteCreate = try XCTUnwrap(singleActiveProduct(in: readBack, barcode: "\(fixture.prefix)OFFLINE_IOS_CREATE"))
        XCTAssertEqual(remoteCreate.productName, "\(fixture.prefix)OFFLINE_IOS_CREATE_PRODUCT")
        assertRemotePrices(prices(in: readBack, productID: remoteCreate.id), expected: expectedIOS(), fixture: fixture)
        XCTAssertEqual(try XCTUnwrap(singleActiveProduct(in: readBack, barcode: "\(fixture.prefix)OFFLINE_IOS_UPDATE")).productName, "\(fixture.prefix)OFFLINE_IOS_UPDATE_FINAL")
        XCTAssertNotNil(try XCTUnwrap(product(in: readBack, barcode: "\(fixture.prefix)OFFLINE_IOS_TOMBSTONE")).deletedAt)

        let sessions = try await fetchFixtureSessions(runtime, fixture: fixture)
        XCTAssertNotNil(session(in: sessions, displayName: "\(fixture.prefix)OFFLINE_IOS_HISTORY_CREATE"))
        XCTAssertNotNil(session(in: sessions, displayName: "\(fixture.prefix)OFFLINE_IOS_HISTORY_UPDATE_FINAL"))
        XCTAssertNotNil(try XCTUnwrap(session(in: sessions, displayName: "\(fixture.prefix)OFFLINE_IOS_HISTORY_TOMBSTONE")).deletedAt)

        print(
            "\(fixture.logPrefix)_IOS_OFFLINE_RECONNECT owner_hash=\(ownerHash(runtime.session.userID)) " +
            "offline_status=\(offlineResult.status.rawValue) localSaveMs=\(localSaveMs) " +
            "pendingCatalog=\(pendingBefore.pendingCatalogChangeCount) pendingPrices=\(pendingBefore.pendingProductPriceChangeCount) pendingHistory=\(pendingBefore.pendingHistorySessionChangeCount) " +
            "remotePushMs=\(remotePushMs) product_create=pass product_update=pass product_tombstone=pass " +
            "product_price_create=pass product_price_correction=pass history_create=pass history_update=pass history_tombstone=pass " +
            "coalescing=last_write_wins conflictPolicy=fail_closed syncType=EVENT_INCREMENTAL fullPull=false"
        )
    }

    func test04MediumImportExportPushAndReadBack() async throws {
        try requireLiveAcceptanceEnabled()
        let fixture = try makeFixture()
        let runtime = try await makeRuntime()
        let context = try makeContext()
        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: context,
            ownerUserUUID: runtime.session.userID
        )

        let workbook = try makeMediumWorkbook(fixture: fixture)
        defer { try? FileManager.default.removeItem(at: workbook.url) }

        let productRows = try ExcelAnalyzer.readSheetByName(at: workbook.url, sheetName: "Products")
        let (_, normalizedHeader, dataRows) = ExcelAnalyzer.analyzeSheetRows(productRows)
        let analysis = ProductImportCore.analyzeImport(
            header: normalizedHeader,
            dataRows: dataRows,
            existingProductsByBarcode: [:]
        )
        XCTAssertEqual(analysis.newProducts.count, 50)
        XCTAssertTrue(analysis.updatedProducts.isEmpty)
        XCTAssertTrue(analysis.errors.isEmpty)

        let resolver = try ProductImportNamedEntityResolver(context: context)
        var importedProducts: [Product] = []
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: runtime.session.userID)
        for draft in analysis.newProducts {
            let product = ProductImportCore.insertProduct(
                from: draft,
                in: context,
                resolver: resolver,
                recordPriceHistory: false
            )
            importedProducts.append(product)
            try accumulator.recordProductChange(
                product: product,
                operation: .create,
                origin: .confirmedImport,
                changedFields: [
                    "barcode",
                    "itemNumber",
                    "productName",
                    "secondProductName",
                    "purchasePrice",
                    "retailPrice",
                    "stockQuantity",
                    "supplier",
                    "category"
                ]
            )
        }
        for supplier in resolver.createdSuppliers {
            try accumulator.recordSupplierChange(
                supplier: supplier,
                operation: .create,
                origin: .confirmedImport
            )
        }
        for category in resolver.createdCategories {
            try accumulator.recordCategoryChange(
                category: category,
                operation: .create,
                origin: .confirmedImport
            )
        }
        try context.save()

        let priceRows = try ExcelAnalyzer.readSheetByName(at: workbook.url, sheetName: "PriceHistory")
        let priceEntries = try parseMediumPriceRows(priceRows)
        XCTAssertEqual(priceEntries.count, 102)
        let productsByBarcode = Dictionary(uniqueKeysWithValues: importedProducts.map { ($0.barcode, $0) })
        for entry in priceEntries {
            let product = try XCTUnwrap(productsByBarcode[entry.barcode])
            let price = ProductPrice(
                type: entry.type,
                price: entry.price,
                effectiveAt: entry.effectiveAt,
                source: "TASK103_MEDIUM_IMPORT",
                note: "TASK103_REAL_DEVICE",
                createdAt: entry.effectiveAt,
                product: product
            )
            context.insert(price)
            try accumulator.recordProductPriceChange(price: price, origin: .productPriceSave)
        }
        try context.save()

        let catalogStarted = Date()
        let catalogPush = try await pushPendingCatalog(
            context: context,
            runtime: runtime,
            expectedReadyCandidatesAtLeast: 60
        )
        XCTAssertEqual(catalogPush.status, .completed)
        let pricePush = try await pushAllPendingPrices(context: context, runtime: runtime)
        XCTAssertEqual(pricePush.inserted, 102)

        let readBack = try await fetchRemoteSnapshot(runtime, fixture: fixture)
        let mediumProducts = activeProducts(in: readBack, barcodes: Set(fixture.mediumBarcodes))
        XCTAssertEqual(mediumProducts.count, 50)
        let canary = try XCTUnwrap(singleActiveProduct(in: readBack, barcode: fixture.mediumCanaryBarcode))
        XCTAssertEqual(canary.productName, fixture.mediumCanaryProduct)
        XCTAssertPrice(canary.purchasePrice, equals: 41.01, label: "medium canary purchase", fixture: fixture)
        XCTAssertPrice(canary.retailPrice, equals: 61.01, label: "medium canary retail", fixture: fixture)
        assertRemotePrices(prices(in: readBack, productID: canary.id), expected: expectedMediumCanary(), fixture: fixture)

        let exportURL = try exportMediumSpotCheck(context: context, fixture: fixture)
        defer { try? FileManager.default.removeItem(at: exportURL) }
        let exportRows = try ExcelAnalyzer.readSheetByName(at: exportURL, sheetName: "Inventory")
        XCTAssertTrue(exportRows.contains { row in
            row.contains(fixture.mediumCanaryBarcode) &&
            row.contains("41.01") &&
            row.contains("61.01") &&
            row.contains("40.01") &&
            row.contains("60.01")
        })

        let duration = Date().timeIntervalSince(catalogStarted)
        print(
            "\(fixture.logPrefix)_IOS_MEDIUM_IMPORT_EXPORT owner_hash=\(ownerHash(runtime.session.userID)) " +
            "products=50 prices=102 catalog_status=\(catalogPush.status.rawValue) " +
            "price_inserted=\(pricePush.inserted) price_batches=\(pricePush.batches) " +
            "remote_medium_products=\(mediumProducts.count) export_spotcheck=true duration_s=\(String(format: "%.2f", duration))"
        )
    }

    func test05ConflictStaleRecoveryAndProductPriceFailClosed() async throws {
        try requireLiveAcceptanceEnabled()
        let fixture = try makeFixture()
        let runtime = try await makeRuntime()

        let seedContext = try makeContext()
        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: seedContext,
            ownerUserUUID: runtime.session.userID
        )
        _ = try await createCatalogCanary(
            context: seedContext,
            runtime: runtime,
            supplierName: fixture.supplierConflictCatalog,
            categoryName: fixture.categoryConflictCatalog,
            productName: fixture.productConflictCatalog,
            barcode: fixture.barcodeConflictCatalog,
            itemNumber: "\(fixture.prefix)ITEM_CONFLICT_G1",
            purchasePrice: 42,
            retailPrice: 52,
            stockQuantity: 3
        )
        let g2Product = try await createCatalogCanary(
            context: seedContext,
            runtime: runtime,
            supplierName: fixture.supplierConflictPrice,
            categoryName: fixture.categoryConflictPrice,
            productName: fixture.productConflictPrice,
            barcode: fixture.barcodeConflictPrice,
            itemNumber: "\(fixture.prefix)ITEM_CONFLICT_G2",
            purchasePrice: 62,
            retailPrice: 72,
            stockQuantity: 4
        )
        try insertPrices(expectedConflictPrice(), product: g2Product, context: seedContext, ownerUserID: runtime.session.userID)
        let priceSeedPush = try await pushPendingPrices(context: seedContext, runtime: runtime)
        XCTAssertTrue(priceSeedPush.isVerifiedSuccess)
        XCTAssertEqual(priceSeedPush.insertedCount, 4)

        let snapshot = try await fetchRemoteSnapshot(runtime, fixture: fixture)
        let remoteG1 = try XCTUnwrap(singleActiveProduct(in: snapshot, barcode: fixture.barcodeConflictCatalog))
        let remoteG2 = try XCTUnwrap(singleActiveProduct(in: snapshot, barcode: fixture.barcodeConflictPrice))
        XCTAssertEqual(remoteG1.productName, fixture.productConflictCatalog)
        assertRemotePrices(prices(in: snapshot, productID: remoteG2.id), expected: expectedConflictPrice(), fixture: fixture)

        let staleContext = try makeContext()
        let staleSupplier = Supplier(
            name: fixture.supplierConflictCatalog,
            remoteID: remoteG1.supplierID,
            remoteUpdatedAt: remoteG1.supplierID
                .flatMap { id in snapshot.suppliers.first { $0.id == id }?.updatedAt }
                .flatMap(SupabaseRemoteDateParser.parse)
        )
        let staleCategory = ProductCategory(
            name: fixture.categoryConflictCatalog,
            remoteID: remoteG1.categoryID,
            remoteUpdatedAt: remoteG1.categoryID
                .flatMap { id in snapshot.categories.first { $0.id == id }?.updatedAt }
                .flatMap(SupabaseRemoteDateParser.parse)
        )
        let staleProduct = Product(
            barcode: fixture.barcodeConflictCatalog,
            remoteID: remoteG1.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(remoteG1.updatedAt),
            remoteDeletedAt: SupabaseRemoteDateParser.parse(remoteG1.deletedAt),
            itemNumber: remoteG1.itemNumber,
            productName: "\(fixture.prefix)LOCAL_CONFLICT_G1_BEFORE",
            secondProductName: remoteG1.secondProductName,
            purchasePrice: remoteG1.purchasePrice,
            retailPrice: remoteG1.retailPrice,
            stockQuantity: remoteG1.stockQuantity,
            supplier: staleSupplier,
            category: staleCategory
        )
        staleContext.insert(staleSupplier)
        staleContext.insert(staleCategory)
        staleContext.insert(staleProduct)
        try staleContext.save()

        let updatePreview = makeUpdatePreview(for: remoteG1, snapshot: snapshot)
        let stalePlan = try SupabasePullApplyService().prepareApplyPlan(
            preview: updatePreview,
            context: staleContext,
            isAuthenticated: true,
            accountGuard: SupabasePullApplyAccountGuard(
                currentUserID: runtime.session.userID,
                lastLinkedUserID: runtime.session.userID
            )
        )
        XCTAssertEqual(stalePlan.plannedUpdatedCount, 1)
        staleProduct.productName = "\(fixture.prefix)LOCAL_CONFLICT_G1_AFTER_PREVIEW"
        try staleContext.save()
        XCTAssertThrowsError(try SupabasePullApplyService().apply(plan: stalePlan, context: staleContext)) { error in
            XCTAssertEqual(error as? SupabasePullApplyError, .previewStale)
        }

        let priceConflictContext = try makeContext()
        let priceProduct = Product(
            barcode: fixture.barcodeConflictPrice,
            remoteID: remoteG2.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(remoteG2.updatedAt),
            productName: fixture.productConflictPrice
        )
        priceConflictContext.insert(priceProduct)
        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: priceConflictContext,
            ownerUserUUID: runtime.session.userID
        )
        let conflictingPrice = ProductPrice(
            type: .purchase,
            price: 63.33,
            effectiveAt: try date("2026-05-12 16:15:00"),
            source: "TASK103_CONFLICT_PRICE",
            note: "TASK103_FAIL_CLOSED",
            createdAt: try date("2026-05-12 16:15:00"),
            product: priceProduct
        )
        priceConflictContext.insert(conflictingPrice)
        try LocalPendingChangeAccumulator(
            context: priceConflictContext,
            ownerUserID: runtime.session.userID
        ).recordProductPriceChange(price: conflictingPrice, origin: .productPriceSave)
        try priceConflictContext.save()

        let priceConflictPlan = try await SupabaseProductPricePushDryRunService(fetcher: runtime.productPriceRemote).loadDryRun(
            context: priceConflictContext,
            sessionSnapshot: ProductPricePushDryRunSessionSnapshot(
                userID: runtime.session.userID,
                lastLinkedUserID: runtime.session.userID
            )
        )
        XCTAssertEqual(priceConflictPlan.summary.readyCandidates, 0)
        XCTAssertEqual(priceConflictPlan.summary.conflictSameKeyDifferentPrice, 1)
        XCTAssertTrue(priceConflictPlan.candidates.isEmpty)

        let recoveryPlan = SupabaseSyncPlanResolver.makePlan(
            counters: SupabaseSyncPlanCounters(toApply: 1, reviewNeeded: 1, blocked: 1, stale: 1),
            requestedSections: [.cloud, .prices],
            blockingReasons: [.authRequired, .cloudPermission]
        )
        XCTAssertEqual(recoveryPlan.state, .blocked)
        XCTAssertEqual(recoveryPlan.primaryAction, .signInAgain)
        let staleRecoveryPlan = SupabaseSyncPlanResolver.makePlan(
            counters: SupabaseSyncPlanCounters(toApply: 1, stale: 1),
            requestedSections: [.cloud, .prices]
        )
        XCTAssertEqual(staleRecoveryPlan.state, .stale)
        XCTAssertEqual(staleRecoveryPlan.primaryAction, .recheck)

        let after = try await fetchRemoteSnapshot(runtime, fixture: fixture)
        let remoteG1After = try XCTUnwrap(singleActiveProduct(in: after, barcode: fixture.barcodeConflictCatalog))
        let remoteG2After = try XCTUnwrap(singleActiveProduct(in: after, barcode: fixture.barcodeConflictPrice))
        XCTAssertEqual(remoteG1After.productName, fixture.productConflictCatalog)
        assertRemotePrices(prices(in: after, productID: remoteG2After.id), expected: expectedConflictPrice(), fixture: fixture)

        print(
            "\(fixture.logPrefix)_IOS_CONFLICT_RECOVERY owner_hash=\(ownerHash(runtime.session.userID)) " +
            "catalog_stale=previewStale product_price_conflicts=\(priceConflictPlan.summary.conflictSameKeyDifferentPrice) " +
            "price_ready=\(priceConflictPlan.summary.readyCandidates) recovery_auth_action=\(recoveryPlan.primaryAction.rawValue) " +
            "recovery_stale_action=\(staleRecoveryPlan.primaryAction.rawValue) remote_unchanged=true"
        )
    }

    func test06OfflineRetryCatalogPendingNoDuplicate() async throws {
        try requireLiveAcceptanceEnabled()
        let fixture = try makeFixture()
        let runtime = try await makeRuntime()
        let context = try makeContext()
        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: context,
            ownerUserUUID: runtime.session.userID
        )

        _ = try createLocalCatalogCanary(
            context: context,
            ownerUserID: runtime.session.userID,
            supplierName: fixture.supplierOffline,
            categoryName: fixture.categoryOffline,
            productName: fixture.productOffline,
            barcode: fixture.barcodeOffline,
            itemNumber: "\(fixture.prefix)ITEM_OFFLINE_0001",
            purchasePrice: 82,
            retailPrice: 92,
            stockQuantity: 5
        )

        let aggregated = try await LocalPendingAggregatedPushPlanner(
            context: context,
            includesCatalog: true,
            includesProductPrice: false
        ).makePlan(ownerUserID: runtime.session.userID)
        XCTAssertTrue(aggregated.blockers.isEmpty)
        let batch = try XCTUnwrap(aggregated.catalogBatch)
        XCTAssertGreaterThanOrEqual(batch.plan.candidates.count, 3)

        let stateStore = LocalPendingAggregatedPushStateStore(context: context)
        try stateStore.markSent(
            changeIDs: batch.changeIDs,
            ownerUserID: runtime.session.userID,
            planFingerprint: batch.plan.planFingerprint
        )
        let offlineResult = await SupabaseManualPushService(
            remote: Task103NetworkDownManualPushRemoteGateway()
        ).execute(
            plan: batch.plan,
            context: context,
            ownerUserID: runtime.session.userID
        )
        XCTAssertEqual(offlineResult.status, .failedBeforeWrite)
        try stateStore.markRetryable(changeIDs: batch.changeIDs, ownerUserID: runtime.session.userID)

        let retryPlan = try await LocalPendingAggregatedPushPlanner(
            context: context,
            includesCatalog: true,
            includesProductPrice: false
        ).makePlan(ownerUserID: runtime.session.userID)
        XCTAssertTrue(retryPlan.warnings.contains(.retryableSentChangesAvailable) || retryPlan.catalogBatch != nil)
        let retryBatch = try XCTUnwrap(retryPlan.catalogBatch)
        try stateStore.markSent(
            changeIDs: retryBatch.changeIDs,
            ownerUserID: runtime.session.userID,
            planFingerprint: retryBatch.plan.planFingerprint
        )
        let retryResult = await SupabaseManualPushService(clientProvider: runtime.provider).execute(
            plan: retryBatch.plan,
            context: context,
            ownerUserID: runtime.session.userID
        )
        XCTAssertEqual(retryResult.status, .completed)
        try stateStore.markAcknowledged(changeIDs: retryBatch.changeIDs, ownerUserID: runtime.session.userID)

        let readBack = try await fetchRemoteSnapshot(runtime, fixture: fixture)
        let remote = try XCTUnwrap(singleActiveProduct(in: readBack, barcode: fixture.barcodeOffline))
        XCTAssertEqual(remote.productName, fixture.productOffline)
        XCTAssertEqual(activeProducts(in: readBack, barcodes: [fixture.barcodeOffline]).count, 1)

        let noOp = try await LocalPendingAggregatedPushPlanner(
            context: context,
            priceRemoteFetcher: runtime.productPriceRemote,
            includesCatalog: true,
            includesProductPrice: true
        ).makePlan(ownerUserID: runtime.session.userID)
        XCTAssertNil(noOp.catalogBatch)
        XCTAssertNil(noOp.productPriceBatch)
        XCTAssertTrue(noOp.blockers.isEmpty)

        print(
            "\(fixture.logPrefix)_IOS_OFFLINE_RETRY owner_hash=\(ownerHash(runtime.session.userID)) " +
            "offline_status=\(offlineResult.status.rawValue) retry_status=\(retryResult.status.rawValue) " +
            "remote_products=1 no_duplicate=true no_op=true"
        )
    }

    func test07Task104Pass2ResidueScanReadOnly() async throws {
        try requireLiveAcceptanceEnabled()
        let fixture = try makeFixture()
        let runtime = try await makeRuntime()
        let snapshot = try await fetchRemoteSnapshot(runtime, fixture: fixture)

        let suppliers = activeSuppliers(in: snapshot, fixture: fixture)
        let categories = activeCategories(in: snapshot, fixture: fixture)
        let products = activeProducts(in: snapshot, barcodes: Set(fixture.allBarcodes))
        let uniqueProductBarcodes = Set(products.map(\.barcode))

        XCTAssertFalse(runtime.config.publishableKey.lowercased().contains("service_role"))
        XCTAssertFalse(runtime.config.publishableKey.lowercased().contains("secret_key"))
        XCTAssertFalse(runtime.config.publishableKey.lowercased().contains("sb_secret"))
        XCTAssertFalse(runtime.session.isExpired)
        XCTAssertEqual(uniqueProductBarcodes.count, products.count)
        if fixture.isTask104Pass2 {
            XCTAssertEqual(suppliers.count, 10)
            XCTAssertEqual(categories.count, 10)
            XCTAssertEqual(products.count, 55)
            XCTAssertEqual(snapshot.prices.count, 114)
        } else {
            XCTAssertGreaterThanOrEqual(products.count, 1)
        }

        print(
            "TASK104_PASS2_RESIDUE_SCAN owner_hash=\(ownerHash(runtime.session.userID)) " +
            "suppliers=\(suppliers.count) categories=\(categories.count) " +
            "products=\(products.count) prices=\(snapshot.prices.count) " +
            "duplicate_active_barcodes=\(products.count - uniqueProductBarcodes.count) retained_for_review=true"
        )
    }

    func test08Task112ScopedCleanupWhenEnabled() async throws {
        try requireLiveAcceptanceEnabled()
        let fixture = try makeFixture()
        guard fixture.isTask112 else {
            throw XCTSkip("TASK112 scoped cleanup only accepts TASK112_ prefixes.")
        }

        let environment = ProcessInfo.processInfo.environment
        let cleanupValue = (
            environment["TASK112_SCOPED_CLEANUP"]
                ?? environment["TEST_RUNNER_TASK112_SCOPED_CLEANUP"]
        )?.lowercased()
        guard cleanupValue == "1" || cleanupValue == "true" else {
            throw XCTSkip("Set TASK112_SCOPED_CLEANUP=1 to delete scoped TASK112 rows.")
        }

        let runtime = try await makeRuntime()
        let before = try await fetchRemoteSnapshot(runtime, fixture: fixture)
        let productIDs = before.products.map(\.id.uuidString)

        if !productIDs.isEmpty {
            try await runtime.provider.client
                .from("inventory_product_prices")
                .delete()
                .eq("owner_user_id", value: runtime.session.userID.uuidString)
                .in("product_id", values: productIDs)
                .execute()

            try await runtime.provider.client
                .from("inventory_products")
                .delete()
                .eq("owner_user_id", value: runtime.session.userID.uuidString)
                .in("barcode", values: fixture.allBarcodes)
                .execute()
        }

        try await runtime.provider.client
            .from("inventory_suppliers")
            .delete()
            .eq("owner_user_id", value: runtime.session.userID.uuidString)
            .in("name", values: fixture.allSupplierNames)
            .execute()

        try await runtime.provider.client
            .from("inventory_categories")
            .delete()
            .eq("owner_user_id", value: runtime.session.userID.uuidString)
            .in("name", values: fixture.allCategoryNames)
            .execute()

        let after = try await fetchRemoteSnapshot(runtime, fixture: fixture)
        XCTAssertTrue(after.suppliers.isEmpty)
        XCTAssertTrue(after.categories.isEmpty)
        XCTAssertTrue(after.products.isEmpty)
        XCTAssertTrue(after.prices.isEmpty)

        print(
            "TASK112_SCOPED_CLEANUP owner_hash=\(ownerHash(runtime.session.userID)) " +
            "before_suppliers=\(before.suppliers.count) before_categories=\(before.categories.count) " +
            "before_products=\(before.products.count) before_prices=\(before.prices.count) " +
            "after_suppliers=\(after.suppliers.count) after_categories=\(after.categories.count) " +
            "after_products=\(after.products.count) after_prices=\(after.prices.count)"
        )
    }

    private func pushPendingCatalog(
        context: ModelContext,
        runtime: Runtime,
        expectedReadyCandidatesAtLeast: Int
    ) async throws -> SupabaseManualPushResult {
        let aggregated = try await LocalPendingAggregatedPushPlanner(
            context: context,
            includesCatalog: true,
            includesProductPrice: false
        ).makePlan(ownerUserID: runtime.session.userID)
        XCTAssertTrue(aggregated.blockers.isEmpty)
        let batch = try XCTUnwrap(aggregated.catalogBatch)
        XCTAssertGreaterThanOrEqual(batch.plan.candidates.count, expectedReadyCandidatesAtLeast)
        try LocalPendingAggregatedPushStateStore(context: context).markSent(
            changeIDs: batch.changeIDs,
            ownerUserID: runtime.session.userID,
            planFingerprint: batch.plan.planFingerprint
        )
        let push = await SupabaseManualPushService(clientProvider: runtime.provider).execute(
            plan: batch.plan,
            context: context,
            ownerUserID: runtime.session.userID
        )
        guard push.status == .completed else {
            throw HarnessError.unexpectedCatalogPushStatus(push.status.rawValue)
        }
        try LocalPendingAggregatedPushStateStore(context: context).markAcknowledged(
            changeIDs: batch.changeIDs,
            ownerUserID: runtime.session.userID
        )
        try await recordCatalogSyncEvent(
            context: context,
            runtime: runtime,
            result: push,
            planFingerprint: batch.plan.planFingerprint
        )
        return push
    }

    private func recordCatalogSyncEvent(
        context: ModelContext,
        runtime: Runtime,
        result: SupabaseManualPushResult,
        planFingerprint: String
    ) async throws {
        let enqueue = SupabaseManualSyncAggregatedPushOutboxProducer(context: context).produce(
            .catalogManualPush(
                result: result,
                ownerUserID: runtime.session.userID,
                currentOwnerUserID: runtime.session.userID,
                planFingerprint: planFingerprint
            )
        )
        let confirmedCatalogChangeCount =
            result.supplierCreates + result.supplierUpdates + result.supplierLinks
            + result.categoryCreates + result.categoryUpdates + result.categoryLinks
            + result.productCreates + result.productUpdates + result.productLinks
        print(
            "TASK114_SYNC_EVENT_ENQUEUE kind=\(enqueue.kind.rawValue) " +
            "entryStatus=\(enqueue.entryStatus?.rawValue ?? "nil") " +
            "error=\(enqueue.errorCode ?? "nil") " +
            "confirmed=\(confirmedCatalogChangeCount) " +
            "suppliers=\(result.touchedIDs.suppliers.count) " +
            "categories=\(result.touchedIDs.categories.count) " +
            "products=\(result.touchedIDs.products.count)"
        )
        guard enqueue.kind == .enqueued || enqueue.kind == .duplicateNoOp || enqueue.kind == .skippedNoOp else {
            throw HarnessError.unexpectedCatalogPushStatus("sync_event_enqueue_failed")
        }
        let recorder = SupabaseSyncEventLiveRecorder(
            configProvider: SupabaseSyncEventLiveRecorderConfigurationProvider(),
            sessionProvider: Task115StaticSyncEventSessionProvider(session: runtime.session),
            transport: SupabaseSyncEventRPCTransport(clientProvider: runtime.provider)
        )
        let drain = try await SyncEventOutboxDrainService(context: context, recorder: recorder)
            .drainOnce(ownerUserID: runtime.session.userID.uuidString, limit: 25)
        print(
            "TASK114_SYNC_EVENT_DRAIN status=\(drain.status.rawValue) attempted=\(drain.attempted) " +
            "sent=\(drain.sent) retry=\(drain.retryScheduled) blocked=\(drain.blocked) " +
            "dead=\(drain.dead) skipped=\(drain.skippedIneligible)"
        )
        if confirmedCatalogChangeCount > 0 {
            guard drain.sent > 0 else {
                throw HarnessError.unexpectedCatalogPushStatus(
                    "sync_event_drain_no_sent_status_\(drain.status.rawValue)_enqueue_\(enqueue.kind.rawValue)"
                )
            }
        } else {
            guard drain.sent > 0 || drain.status == .noWork else {
                throw HarnessError.unexpectedCatalogPushStatus("sync_event_drain_\(drain.status.rawValue)")
            }
        }
    }

    private func pushPendingPrices(
        context: ModelContext,
        runtime: Runtime
    ) async throws -> ProductPriceManualPushResult {
        let aggregated = try await LocalPendingAggregatedPushPlanner(
            context: context,
            priceRemoteFetcher: runtime.productPriceRemote,
            includesCatalog: false,
            includesProductPrice: true
        ).makePlan(ownerUserID: runtime.session.userID)
        XCTAssertTrue(aggregated.blockers.isEmpty)
        let batch = try XCTUnwrap(aggregated.productPriceBatch)
        let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: batch.plan)
        try LocalPendingAggregatedPushStateStore(context: context).markSent(
            changeIDs: batch.changeIDs,
            ownerUserID: runtime.session.userID,
            planFingerprint: productPricePushFingerprint(batch.plan)
        )
        let push = try await SupabaseProductPriceManualPushService(remote: runtime.productPriceRemote).push(snapshot: snapshot)
        guard push.isVerifiedSuccess else {
            throw HarnessError.unverifiedPricePush
        }
        let linkedCount = try ProductPriceManualPushIdentityReconciler().linkVerifiedPayloads(
            snapshot.payloads,
            context: context
        )
        guard linkedCount == snapshot.payloads.count else {
            throw HarnessError.priceIdentityLinkMismatch(linked: linkedCount, expected: snapshot.payloads.count)
        }
        try LocalPendingAggregatedPushStateStore(context: context).markAcknowledged(
            changeIDs: batch.changeIDs,
            ownerUserID: runtime.session.userID
        )
        try await recordProductPriceSyncEvent(context: context, runtime: runtime, result: push)
        return push
    }

    private func recordProductPriceSyncEvent(
        context: ModelContext,
        runtime: Runtime,
        result: ProductPriceManualPushResult
    ) async throws {
        let enqueue = SupabaseManualSyncAggregatedPushOutboxProducer(context: context).produce(
            .productPriceManualPush(
                result: result,
                ownerUserID: runtime.session.userID,
                currentOwnerUserID: runtime.session.userID
            )
        )
        print(
            "TASK114_PRICE_SYNC_EVENT_ENQUEUE kind=\(enqueue.kind.rawValue) " +
            "entryStatus=\(enqueue.entryStatus?.rawValue ?? "nil") " +
            "error=\(enqueue.errorCode ?? "nil") " +
            "prices=\(result.confirmedRemoteIDs.count)"
        )
        guard enqueue.kind == .enqueued || enqueue.kind == .duplicateNoOp || enqueue.kind == .skippedNoOp else {
            throw HarnessError.unexpectedCatalogPushStatus("price_sync_event_enqueue_failed")
        }
        let recorder = SupabaseSyncEventLiveRecorder(
            configProvider: SupabaseSyncEventLiveRecorderConfigurationProvider(),
            sessionProvider: Task115StaticSyncEventSessionProvider(session: runtime.session),
            transport: SupabaseSyncEventRPCTransport(clientProvider: runtime.provider)
        )
        let drain = try await SyncEventOutboxDrainService(context: context, recorder: recorder)
            .drainOnce(ownerUserID: runtime.session.userID.uuidString, limit: 25)
        print(
            "TASK114_PRICE_SYNC_EVENT_DRAIN status=\(drain.status.rawValue) attempted=\(drain.attempted) " +
            "sent=\(drain.sent) retry=\(drain.retryScheduled) blocked=\(drain.blocked) " +
            "dead=\(drain.dead) skipped=\(drain.skippedIneligible)"
        )
        if result.isVerifiedSuccess, result.confirmedRemoteIDs.isEmpty == false {
            guard drain.sent > 0 else {
                throw HarnessError.unexpectedCatalogPushStatus(
                    "price_sync_event_drain_no_sent_status_\(drain.status.rawValue)_enqueue_\(enqueue.kind.rawValue)"
                )
            }
        }
    }

    private func pushPendingHistory(
        _ entries: [HistoryEntry],
        context: ModelContext,
        runtime: Runtime
    ) async throws -> HistorySessionPushResult {
        let result = try await HistorySessionSyncService(remote: HistorySessionRemoteSupabaseAdapter(remote: runtime.inventory)).pushPendingHistorySessions(
            entries: entries,
            ownerUserID: runtime.session.userID,
            context: context
        )
        try await recordHistorySyncEvent(runtime: runtime, result: result)
        return result
    }

    private func recordHistorySyncEvent(
        runtime: Runtime,
        result: HistorySessionPushResult
    ) async throws {
        guard result.uploadedCount > 0, result.pushedRemoteIDs.isEmpty == false else { return }
        let sortedIDs = result.pushedRemoteIDs.sorted { $0.uuidString < $1.uuidString }
        let recorder = SupabaseSyncEventLiveRecorder(
            configProvider: SupabaseSyncEventLiveRecorderConfigurationProvider(),
            sessionProvider: Task115StaticSyncEventSessionProvider(session: runtime.session),
            transport: SupabaseSyncEventRPCTransport(clientProvider: runtime.provider)
        )
        let request = SyncEventRecordRequest(
            domain: "history",
            eventType: "history_changed",
            changedCount: sortedIDs.count,
            entityIDs: .object([
                "session_ids": .array(sortedIDs.map { .string($0.uuidString.lowercased()) })
            ]),
            metadata: .object([
                "source": .string("ios_history_session_push"),
                "uploaded_count": .number(Double(sortedIDs.count))
            ]),
            source: "ios_history_session_push",
            sourceDeviceID: nil,
            batchID: UUID(),
            clientEventID: "task114-ios-history-\(runtime.session.userID.uuidString.lowercased())-\(UUID().uuidString.lowercased())"
        )
        _ = try await recorder.record(request)
        print(
            "TASK114_HISTORY_SYNC_EVENT_RECORD syncType=EVENT_INCREMENTAL " +
            "sessions=\(sortedIDs.count) fullPull=false"
        )
    }

    private func matrixProduct(
        barcode: String,
        name: String,
        supplier: Supplier,
        category: ProductCategory
    ) -> Product {
        Product(
            barcode: barcode,
            itemNumber: "\(barcode)_ITEM",
            productName: name,
            purchasePrice: 44.10,
            retailPrice: 55.20,
            stockQuantity: 6,
            supplier: supplier,
            category: category
        )
    }

    private func matrixHistoryEntry(title: String, fixture: Fixture) -> HistoryEntry {
        let entry = HistoryEntry(
            id: title,
            timestamp: Date(timeIntervalSince1970: 1_778_700_000),
            isManualEntry: true,
            data: [["barcode", "count"], [title, "2"]],
            editable: [["", ""], ["", "2"]],
            complete: [false, true],
            supplier: fixture.matrixSupplierIOS,
            category: fixture.matrixCategoryIOS,
            totalItems: 1,
            paymentTotal: 2,
            missingItems: 0
        )
        entry.title = title
        return entry
    }

    private func applyProductCreate(
        _ remote: RemoteInventoryProductRow,
        snapshot: RemoteSnapshot,
        context: ModelContext,
        ownerUserID: UUID
    ) throws -> SupabasePullApplyResult {
        let plan = try SupabasePullApplyService().prepareApplyPlan(
            preview: makePreview(for: remote, snapshot: snapshot),
            context: context,
            isAuthenticated: true,
            accountGuard: SupabasePullApplyAccountGuard(currentUserID: ownerUserID, lastLinkedUserID: ownerUserID)
        )
        return try SupabasePullApplyService().apply(plan: plan, context: context)
    }

    private func applyProductUpdate(
        _ remote: RemoteInventoryProductRow,
        snapshot: RemoteSnapshot,
        context: ModelContext,
        ownerUserID: UUID
    ) throws -> SupabasePullApplyResult {
        let plan = try SupabasePullApplyService().prepareApplyPlan(
            preview: makeUpdatePreview(for: remote, snapshot: snapshot),
            context: context,
            isAuthenticated: true,
            accountGuard: SupabasePullApplyAccountGuard(currentUserID: ownerUserID, lastLinkedUserID: ownerUserID)
        )
        return try SupabasePullApplyService().apply(plan: plan, context: context)
    }

    private func applyProductTombstone(
        _ remote: RemoteInventoryProductRow,
        snapshot: RemoteSnapshot,
        context: ModelContext,
        ownerUserID: UUID
    ) throws -> SupabasePullApplyResult {
        let plan = try SupabasePullApplyService().prepareApplyPlan(
            preview: makeTombstonePreview(for: remote, snapshot: snapshot),
            context: context,
            isAuthenticated: true,
            accountGuard: SupabasePullApplyAccountGuard(currentUserID: ownerUserID, lastLinkedUserID: ownerUserID)
        )
        return try SupabasePullApplyService().apply(plan: plan, context: context)
    }

    @discardableResult
    private func seedLocalProduct(
        remote: RemoteInventoryProductRow,
        snapshot: RemoteSnapshot,
        context: ModelContext,
        staleName: String
    ) throws -> Product {
        let supplier: Supplier?
        if let supplierID = remote.supplierID,
           let row = snapshot.suppliers.first(where: { $0.id == supplierID }) {
            supplier = try lookupOrInsertSupplier(row, context: context)
        } else {
            supplier = nil
        }
        let category: ProductCategory?
        if let categoryID = remote.categoryID,
           let row = snapshot.categories.first(where: { $0.id == categoryID }) {
            category = try lookupOrInsertCategory(row, context: context)
        } else {
            category = nil
        }
        let product = Product(
            barcode: remote.barcode,
            remoteID: remote.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(remote.updatedAt),
            remoteDeletedAt: nil,
            itemNumber: remote.itemNumber,
            productName: staleName,
            secondProductName: remote.secondProductName,
            purchasePrice: remote.purchasePrice,
            retailPrice: remote.retailPrice,
            stockQuantity: remote.stockQuantity,
            supplier: supplier,
            category: category
        )
        context.insert(product)
        try context.save()
        return product
    }

    private func lookupOrInsertSupplier(_ row: RemoteInventorySupplierRow, context: ModelContext) throws -> Supplier {
        if let existing = try context.fetch(FetchDescriptor<Supplier>()).first(where: { $0.remoteID == row.id || $0.name == row.name }) {
            return existing
        }
        let supplier = Supplier(
            name: row.name,
            remoteID: row.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(row.updatedAt),
            remoteDeletedAt: SupabaseRemoteDateParser.parse(row.deletedAt)
        )
        context.insert(supplier)
        return supplier
    }

    private func lookupOrInsertCategory(_ row: RemoteInventoryCategoryRow, context: ModelContext) throws -> ProductCategory {
        if let existing = try context.fetch(FetchDescriptor<ProductCategory>()).first(where: { $0.remoteID == row.id || $0.name == row.name }) {
            return existing
        }
        let category = ProductCategory(
            name: row.name,
            remoteID: row.id,
            remoteUpdatedAt: SupabaseRemoteDateParser.parse(row.updatedAt),
            remoteDeletedAt: SupabaseRemoteDateParser.parse(row.deletedAt)
        )
        context.insert(category)
        return category
    }

    @discardableResult
    private func seedLocalHistoryEntry(
        remote: RemoteSharedSheetSessionRow,
        context: ModelContext,
        title: String
    ) throws -> HistoryEntry {
        let entry = HistoryEntry(
            id: remote.remoteID.uuidString.lowercased(),
            timestamp: HistorySessionPayloadCodec.parseTimestamp(remote.timestamp),
            isManualEntry: remote.isManualEntry,
            data: remote.data,
            editable: remote.sessionOverlay?.editable ?? [],
            complete: remote.sessionOverlay?.complete ?? [],
            supplier: remote.supplier,
            category: remote.category,
            syncStatus: .syncedSuccessfully,
            uid: remote.remoteID,
            remoteID: remote.remoteID,
            remoteUpdatedAt: HistorySessionPayloadCodec.parseUpdatedAt(remote.updatedAt),
            remoteDeletedAt: nil,
            remotePayloadFingerprint: nil,
            localChangeRevision: 0,
            lastSyncedLocalRevision: 0
        )
        entry.title = title
        context.insert(entry)
        try context.save()
        return entry
    }

    private func pushAllPendingPrices(
        context: ModelContext,
        runtime: Runtime
    ) async throws -> (inserted: Int, batches: Int) {
        var inserted = 0
        var batches = 0
        for _ in 0..<5 {
            let aggregated = try await LocalPendingAggregatedPushPlanner(
                context: context,
                priceRemoteFetcher: runtime.productPriceRemote,
                includesCatalog: false,
                includesProductPrice: true
            ).makePlan(ownerUserID: runtime.session.userID)
            XCTAssertTrue(aggregated.blockers.isEmpty)
            guard let batch = aggregated.productPriceBatch else {
                return (inserted, batches)
            }
            let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: batch.plan)
            try LocalPendingAggregatedPushStateStore(context: context).markSent(
                changeIDs: batch.changeIDs,
                ownerUserID: runtime.session.userID,
                planFingerprint: productPricePushFingerprint(batch.plan)
            )
            let push = try await SupabaseProductPriceManualPushService(remote: runtime.productPriceRemote).push(snapshot: snapshot)
            guard push.isVerifiedSuccess else {
                throw HarnessError.unverifiedPricePush
            }
            let linkedCount = try ProductPriceManualPushIdentityReconciler().linkVerifiedPayloads(
                snapshot.payloads,
                context: context
            )
            guard linkedCount == snapshot.payloads.count else {
                throw HarnessError.priceIdentityLinkMismatch(linked: linkedCount, expected: snapshot.payloads.count)
            }
            try LocalPendingAggregatedPushStateStore(context: context).markAcknowledged(
                changeIDs: batch.changeIDs,
                ownerUserID: runtime.session.userID
            )
            inserted += push.insertedCount
            batches += 1
        }
        return (inserted, batches)
    }

    private func createCatalogCanary(
        context: ModelContext,
        runtime: Runtime,
        supplierName: String,
        categoryName: String,
        productName: String,
        barcode: String,
        itemNumber: String,
        purchasePrice: Double,
        retailPrice: Double,
        stockQuantity: Double
    ) async throws -> Product {
        let product = try createLocalCatalogCanary(
            context: context,
            ownerUserID: runtime.session.userID,
            supplierName: supplierName,
            categoryName: categoryName,
            productName: productName,
            barcode: barcode,
            itemNumber: itemNumber,
            purchasePrice: purchasePrice,
            retailPrice: retailPrice,
            stockQuantity: stockQuantity
        )
        let push = try await pushPendingCatalog(
            context: context,
            runtime: runtime,
            expectedReadyCandidatesAtLeast: 3
        )
        XCTAssertEqual(push.status, .completed)
        XCTAssertNotNil(product.remoteID)
        return product
    }

    private func createLocalCatalogCanary(
        context: ModelContext,
        ownerUserID: UUID,
        supplierName: String,
        categoryName: String,
        productName: String,
        barcode: String,
        itemNumber: String,
        purchasePrice: Double,
        retailPrice: Double,
        stockQuantity: Double
    ) throws -> Product {
        let supplier = Supplier(name: supplierName)
        let category = ProductCategory(name: categoryName)
        context.insert(supplier)
        context.insert(category)

        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: ownerUserID)
        try accumulator.recordSupplierChange(
            supplier: supplier,
            operation: .create,
            origin: .manualCatalogSave
        )
        try accumulator.recordCategoryChange(
            category: category,
            operation: .create,
            origin: .manualCatalogSave
        )

        let product = Product(
            barcode: barcode,
            itemNumber: itemNumber,
            productName: productName,
            purchasePrice: purchasePrice,
            retailPrice: retailPrice,
            stockQuantity: stockQuantity,
            supplier: supplier,
            category: category
        )
        context.insert(product)
        try accumulator.recordProductChange(
            product: product,
            operation: .create,
            origin: .manualCatalogSave,
            changedFields: [
                "barcode",
                "itemNumber",
                "productName",
                "purchasePrice",
                "retailPrice",
                "stockQuantity",
                "supplier",
                "category"
            ]
        )
        try context.save()
        return product
    }

    private func insertPrices(
        _ points: [ExpectedPoint],
        product: Product,
        context: ModelContext,
        ownerUserID: UUID
    ) throws {
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: ownerUserID)
        for point in points {
            let effectiveAt = try date(point.effectiveAt)
            let row = ProductPrice(
                type: point.type,
                price: point.price,
                effectiveAt: effectiveAt,
                source: "TASK103_IOS_PUSH",
                note: "TASK103_REAL_DEVICE",
                createdAt: effectiveAt,
                product: product
            )
            context.insert(row)
            try accumulator.recordProductPriceChange(price: row, origin: .productPriceSave)
        }
        try context.save()
    }

    private func makeMediumWorkbook(fixture: Fixture) throws -> (url: URL, products: [Task089SyntheticBenchmarkHarness.ProductExportRow]) {
        let products = (1...50).map { index in
            let supplier = fixture.mediumSuppliers[(index - 1) % fixture.mediumSuppliers.count]
            let category = fixture.mediumCategories[(index - 1) % fixture.mediumCategories.count]
            return Task089SyntheticBenchmarkHarness.ProductExportRow(
                barcode: fixture.mediumBarcode(index),
                itemNumber: "\(fixture.prefix)MEDIUM_ITEM_\(index.padded3)",
                productName: "\(fixture.prefix)MEDIUM_PRODUCT_\(index.padded3)",
                secondProductName: "\(fixture.prefix)MEDIUM_SECOND_\(index.padded3)",
                purchasePrice: 41.0 + Double(index) / 100.0,
                retailPrice: 61.0 + Double(index) / 100.0,
                oldPurchasePrice: index == 1 ? 40.01 : nil,
                oldRetailPrice: index == 1 ? 60.01 : nil,
                stockQuantity: Double(index),
                supplierName: supplier,
                categoryName: category
            )
        }

        var priceHistory: [Task089SyntheticBenchmarkHarness.PriceHistoryExportRow] = []
        priceHistory.append(
            Task089SyntheticBenchmarkHarness.PriceHistoryExportRow(
                productBarcode: fixture.mediumCanaryBarcode,
                timestamp: try date("2026-05-12 15:00:00"),
                type: PriceType.purchase.rawValue,
                newPrice: 40.01,
                source: "TASK103_MEDIUM_IMPORT"
            )
        )
        priceHistory.append(
            Task089SyntheticBenchmarkHarness.PriceHistoryExportRow(
                productBarcode: fixture.mediumCanaryBarcode,
                timestamp: try date("2026-05-12 15:00:00"),
                type: PriceType.retail.rawValue,
                newPrice: 60.01,
                source: "TASK103_MEDIUM_IMPORT"
            )
        )
        for index in 1...50 {
            priceHistory.append(
                Task089SyntheticBenchmarkHarness.PriceHistoryExportRow(
                    productBarcode: fixture.mediumBarcode(index),
                    timestamp: try date("2026-05-12 15:15:\((index % 50).padded2)"),
                    type: PriceType.purchase.rawValue,
                    newPrice: 41.0 + Double(index) / 100.0,
                    source: "TASK103_MEDIUM_IMPORT"
                )
            )
            priceHistory.append(
                Task089SyntheticBenchmarkHarness.PriceHistoryExportRow(
                    productBarcode: fixture.mediumBarcode(index),
                    timestamp: try date("2026-05-12 15:15:\((index % 50).padded2)"),
                    type: PriceType.retail.rawValue,
                    newPrice: 61.0 + Double(index) / 100.0,
                    source: "TASK103_MEDIUM_IMPORT"
                )
            )
        }

        let url = try Task089SyntheticBenchmarkHarness.exportFullDatabase(
            input: Task089SyntheticBenchmarkHarness.FullDatabaseExportInput(
                products: products,
                suppliers: fixture.mediumSuppliers,
                categories: fixture.mediumCategories,
                priceHistory: priceHistory
            )
        )
        return (url, products)
    }

    private func parseMediumPriceRows(_ rows: [[String]]) throws -> [MediumPriceEntry] {
        guard let header = rows.first else { return [] }
        let keys = header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        func index(_ name: String) throws -> Int {
            try XCTUnwrap(keys.firstIndex(of: name), "Missing PriceHistory column \(name)")
        }
        let barcodeIndex = try index("productBarcode")
        let timestampIndex = try index("timestamp")
        let typeIndex = try index("type")
        let priceIndex = try index("newPrice")

        return try rows.dropFirst().compactMap { row -> MediumPriceEntry? in
            guard row.count > max(barcodeIndex, timestampIndex, typeIndex, priceIndex) else { return nil }
            let barcode = row[barcodeIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !barcode.isEmpty else { return nil }
            let typeText = row[typeIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let type = try XCTUnwrap(PriceType(rawValue: typeText), "Invalid price type \(typeText)")
            let price = try XCTUnwrap(Double(row[priceIndex]), "Invalid price \(row[priceIndex])")
            return MediumPriceEntry(
                barcode: barcode,
                type: type,
                price: price,
                effectiveAt: try date(row[timestampIndex])
            )
        }
    }

    private func exportMediumSpotCheck(context: ModelContext, fixture: Fixture) throws -> URL {
        let product = try XCTUnwrap(
            try context.fetch(FetchDescriptor<Product>()).first { $0.barcode == fixture.mediumCanaryBarcode }
        )
        let prices = try context.fetch(FetchDescriptor<ProductPrice>())
            .filter { $0.product?.barcode == fixture.mediumCanaryBarcode }
        let previousPurchase = prices
            .filter { $0.type == .purchase }
            .sorted { $0.effectiveAt < $1.effectiveAt }
            .first?.price
        let previousRetail = prices
            .filter { $0.type == .retail }
            .sorted { $0.effectiveAt < $1.effectiveAt }
            .first?.price
        let header = ["barcode", "productName", "purchasePrice", "retailPrice", "previousPurchase", "previousRetail"]
        let row = [
            product.barcode,
            product.productName ?? "",
            product.purchasePrice.map { String($0) } ?? "",
            product.retailPrice.map { String($0) } ?? "",
            previousPurchase.map { String($0) } ?? "",
            previousRetail.map { String($0) } ?? ""
        ]
        return try InventoryXLSXExporter.export(
            grid: [header, row],
            preferredName: "\(fixture.prefix)medium_export_spotcheck"
        )
    }

    private func makeRuntime() async throws -> Runtime {
        let config = try SupabaseConfig.load()
        let provider = SupabaseClientProvider(config: config)
        let session = try await provider.client.auth.session
        return Runtime(
            config: config,
            provider: provider,
            inventory: SupabaseTransportClient(clientProvider: provider),
            session: SupabaseAuthService.sessionInfoForTask103(session)
        )
    }

    private struct Task115StaticSyncEventSessionProvider: SyncEventLiveRecorderSessionProviding {
        let session: SupabaseAuthSessionInfo

        func currentSyncEventRecorderSession() async -> SyncEventLiveRecorderSession? {
            SyncEventLiveRecorderSession(userID: session.userID, isExpired: session.isExpired)
        }
    }

    private func requireLiveAcceptanceEnabled() throws {
        let environment = ProcessInfo.processInfo.environment
        let task103Value = (environment["TASK103_LIVE_ACCEPTANCE"] ?? environment["TEST_RUNNER_TASK103_LIVE_ACCEPTANCE"])?.lowercased()
        let task104Value = (environment["TASK104_PASS2_LIVE_ACCEPTANCE"] ?? environment["TEST_RUNNER_TASK104_PASS2_LIVE_ACCEPTANCE"])?.lowercased()
        let task112Value = (environment["TASK112_LIVE_ACCEPTANCE"] ?? environment["TEST_RUNNER_TASK112_LIVE_ACCEPTANCE"])?.lowercased()
        let task114Value = (environment["TASK114_LIVE_ACCEPTANCE"] ?? environment["TEST_RUNNER_TASK114_LIVE_ACCEPTANCE"])?.lowercased()
        guard task103Value == "1" || task103Value == "true"
            || task104Value == "1" || task104Value == "true"
            || task112Value == "1" || task112Value == "true"
            || task114Value == "1" || task114Value == "true" else {
            throw XCTSkip("Live acceptance is gated. Set TASK103_LIVE_ACCEPTANCE=1, TASK104_PASS2_LIVE_ACCEPTANCE=1, TASK112_LIVE_ACCEPTANCE=1 or TASK114_LIVE_ACCEPTANCE=1 in the xctestrun environment.")
        }
    }

    private func requireTask114IOSFullPullEnabled() throws {
        let environment = ProcessInfo.processInfo.environment
        let enabled = (environment["TASK114_IOS_FULL_PULL"] ?? environment["TEST_RUNNER_TASK114_IOS_FULL_PULL"])?.lowercased()
        guard enabled == "1" || enabled == "true" else {
            throw XCTSkip("TASK114 iOS full pull is gated. Set TASK114_IOS_FULL_PULL=1 in the xctestrun environment.")
        }
    }

    private func makeFixture() throws -> Fixture {
        let environment = ProcessInfo.processInfo.environment
        guard let prefix = environment["TASK104_PASS2_RUN_PREFIX"]
            ?? environment["TEST_RUNNER_TASK104_PASS2_RUN_PREFIX"]
            ?? environment["TASK103_RUN_PREFIX"]
            ?? environment["TEST_RUNNER_TASK103_RUN_PREFIX"]
            ?? environment["TASK112_RUN_PREFIX"]
            ?? environment["TEST_RUNNER_TASK112_RUN_PREFIX"]
            ?? environment["TASK114_RUN_PREFIX"]
            ?? environment["TEST_RUNNER_TASK114_RUN_PREFIX"] else {
            throw XCTSkip("TASK104_PASS2_RUN_PREFIX, TASK103_RUN_PREFIX, TASK112_RUN_PREFIX or TASK114_RUN_PREFIX must be explicitly set for live acceptance.")
        }
        guard (
            prefix.hasPrefix("TASK103_REAL_R")
                || prefix.hasPrefix("TASK104_PASS2_")
                || prefix.hasPrefix("TASK112_")
                || prefix.hasPrefix("TASK114_")
                || prefix.hasPrefix("TASK115_")
                || prefix.hasPrefix("TASK123_")
        ), prefix.hasSuffix("_") else {
            throw XCTSkip("Run prefix must be run-scoped TASK103_REAL_R..._, TASK104_PASS2_..._, TASK112_..._, TASK114_..._, TASK115_..._ or TASK123_..._.")
        }
        return Fixture(prefix: prefix)
    }

    private func fetchRemoteSnapshot(
        _ runtime: Runtime,
        fixture: Fixture
    ) async throws -> RemoteSnapshot {
        async let suppliers = fetchFixtureSuppliers(runtime.provider, ownerUserID: runtime.session.userID, fixture: fixture)
        async let categories = fetchFixtureCategories(runtime.provider, ownerUserID: runtime.session.userID, fixture: fixture)
        let products = try await fetchFixtureProducts(runtime.provider, ownerUserID: runtime.session.userID, fixture: fixture)
        let prices = try await fetchFixturePrices(
            runtime.productPriceRemote,
            ownerUserID: runtime.session.userID,
            productIDs: products.map(\.id)
        )
        return try await RemoteSnapshot(suppliers: suppliers, categories: categories, products: products, prices: prices)
    }

    private func fetchFixtureSessions(
        _ runtime: Runtime,
        fixture: Fixture
    ) async throws -> [RemoteSharedSheetSessionRow] {
        try await runtime.provider.client
            .from("shared_sheet_sessions")
            .select("remote_id,payload_version,display_name,timestamp,supplier,category,is_manual_entry,data,session_overlay,owner_user_id,updated_at,deleted_at")
            .eq("owner_user_id", value: runtime.session.userID.uuidString)
            .like("display_name", pattern: "\(fixture.prefix)%")
            .order("remote_id", ascending: true)
            .limit(100)
            .execute()
            .value
    }

    private func fetchFixtureSuppliers(
        _ provider: SupabaseClientProvider,
        ownerUserID: UUID,
        fixture: Fixture
    ) async throws -> [RemoteInventorySupplierRow] {
        try await provider.client
            .from("inventory_suppliers")
            .select("id,owner_user_id,name,updated_at,deleted_at")
            .eq("owner_user_id", value: ownerUserID.uuidString)
            .in("name", values: fixture.allSupplierNames)
            .order(SupabaseTransportClient.stablePageOrderColumn, ascending: true)
            .limit(20)
            .execute()
            .value
    }

    private func fetchFixtureCategories(
        _ provider: SupabaseClientProvider,
        ownerUserID: UUID,
        fixture: Fixture
    ) async throws -> [RemoteInventoryCategoryRow] {
        try await provider.client
            .from("inventory_categories")
            .select("id,owner_user_id,name,updated_at,deleted_at")
            .eq("owner_user_id", value: ownerUserID.uuidString)
            .in("name", values: fixture.allCategoryNames)
            .order(SupabaseTransportClient.stablePageOrderColumn, ascending: true)
            .limit(20)
            .execute()
            .value
    }

    private func fetchFixtureProducts(
        _ provider: SupabaseClientProvider,
        ownerUserID: UUID,
        fixture: Fixture
    ) async throws -> [RemoteInventoryProductRow] {
        try await provider.client
            .from("inventory_products")
            .select("id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at")
            .eq("owner_user_id", value: ownerUserID.uuidString)
            .in("barcode", values: fixture.allBarcodes)
            .order(SupabaseTransportClient.stablePageOrderColumn, ascending: true)
            .limit(100)
            .execute()
            .value
    }

    private func fetchFixturePrices(
        _ inventory: ProductPriceRemoteSupabaseAdapter,
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

    private func makePreview(for product: RemoteInventoryProductRow, snapshot: RemoteSnapshot) -> SyncPreview {
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

    private func makeNoOpPreview(for product: RemoteInventoryProductRow, snapshot: RemoteSnapshot) -> SyncPreview {
        let summary = SyncPreviewProductSummary(
            classification: .unchanged,
            remoteID: product.id,
            barcode: product.barcode,
            productName: product.productName
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
            localCounts: LocalInventorySnapshotCounts(
                products: 1,
                suppliers: product.supplierID == nil ? 0 : 1,
                categories: product.categoryID == nil ? 0 : 1,
                productPrices: prices(in: snapshot, productID: product.id).count
            ),
            newProducts: [],
            updateCandidates: [],
            conflicts: [],
            unchangedProducts: [summary],
            remoteTombstones: [],
            supplierDiffs: [],
            categoryDiffs: [],
            priceHistoryDiffs: [],
            warnings: [],
            metrics: [],
            sourceErrors: []
        )
    }

    private func makeUpdatePreview(for product: RemoteInventoryProductRow, snapshot: RemoteSnapshot) -> SyncPreview {
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
            classification: .updateCandidate,
            remoteID: product.id,
            barcode: product.barcode,
            productName: product.productName,
            fieldChanges: [
                SyncPreviewFieldChange(
                    fieldKey: .productName,
                    barcodeOrKey: product.barcode,
                    remoteDisplay: product.productName,
                    localDisplay: "TASK103_LOCAL_STALE"
                )
            ],
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
            localCounts: LocalInventorySnapshotCounts(
                products: 1,
                suppliers: product.supplierID == nil ? 0 : 1,
                categories: product.categoryID == nil ? 0 : 1,
                productPrices: 0,
                linkedProducts: 1,
                linkedSuppliers: product.supplierID == nil ? 0 : 1,
                linkedCategories: product.categoryID == nil ? 0 : 1
            ),
            newProducts: [],
            updateCandidates: [summary],
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

    private func makeTombstonePreview(for product: RemoteInventoryProductRow, snapshot: RemoteSnapshot) -> SyncPreview {
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
            classification: .remoteTombstone,
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
                activeProducts: 0,
                tombstonedProducts: 1,
                suppliers: product.supplierID == nil ? 0 : 1,
                categories: product.categoryID == nil ? 0 : 1,
                productPrices: prices(in: snapshot, productID: product.id).count
            ),
            localCounts: LocalInventorySnapshotCounts(
                products: 1,
                suppliers: product.supplierID == nil ? 0 : 1,
                categories: product.categoryID == nil ? 0 : 1,
                productPrices: 0,
                linkedProducts: 1,
                linkedSuppliers: product.supplierID == nil ? 0 : 1,
                linkedCategories: product.categoryID == nil ? 0 : 1
            ),
            newProducts: [],
            updateCandidates: [],
            conflicts: [],
            unchangedProducts: [],
            remoteTombstones: [summary],
            supplierDiffs: [],
            categoryDiffs: [],
            priceHistoryDiffs: [],
            warnings: [],
            metrics: [],
            sourceErrors: []
        )
    }

    private func product(in snapshot: RemoteSnapshot, barcode: String) -> RemoteInventoryProductRow? {
        let matches = snapshot.products.filter { $0.barcode == barcode }
        return matches.count == 1 ? matches[0] : nil
    }

    private func session(in sessions: [RemoteSharedSheetSessionRow], displayName: String) -> RemoteSharedSheetSessionRow? {
        let matches = sessions.filter { $0.displayName == displayName }
        return matches.count == 1 ? matches[0] : nil
    }

    private func localProduct(context: ModelContext, barcode: String) throws -> Product? {
        try context.fetch(FetchDescriptor<Product>()).first { $0.barcode == barcode }
    }

    private func localHistoryEntry(context: ModelContext, remoteID: UUID) throws -> HistoryEntry? {
        try context.fetch(FetchDescriptor<HistoryEntry>()).first { $0.remoteID == remoteID }
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
        let context = ModelContext(container)
        Self.retainedContexts.append(context)
        return context
    }

    private func makePersistentAppContext() throws -> ModelContext {
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
        let configuration: ModelConfiguration
        if let storePath = ProcessInfo.processInfo.environment["TASK114_IOS_STORE_PATH"],
           !storePath.isEmpty {
            configuration = ModelConfiguration(
                "Task114AppStore",
                schema: schema,
                url: URL(fileURLWithPath: storePath),
                allowsSave: true,
                cloudKitDatabase: .none
            )
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        }
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        let context = ModelContext(container)
        Self.retainedContexts.append(context)
        return context
    }

    private struct Task114LocalCounts {
        let products: Int
        let suppliers: Int
        let categories: Int
        let productPrices: Int
        let userVisibleHistory: Int
    }

    private func task114LocalCounts(context: ModelContext) throws -> Task114LocalCounts {
        Task114LocalCounts(
            products: try context.fetchCount(FetchDescriptor<Product>(
                predicate: #Predicate<Product> { $0.remoteDeletedAt == nil }
            )),
            suppliers: try context.fetchCount(FetchDescriptor<Supplier>(
                predicate: #Predicate<Supplier> { $0.remoteDeletedAt == nil }
            )),
            categories: try context.fetchCount(FetchDescriptor<ProductCategory>(
                predicate: #Predicate<ProductCategory> { $0.remoteDeletedAt == nil }
            )),
            productPrices: try context.fetchCount(FetchDescriptor<ProductPrice>()),
            userVisibleHistory: try LocalHistorySessionCounting.fetchUserVisibleCount(context: context)
        )
    }

    private func assertLocalPrices(
        context: ModelContext,
        barcode: String,
        expected: [ExpectedPoint],
        fixture: Fixture,
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
            XCTAssertPrice(
                row.price,
                equals: expected.price,
                label: "\(barcode) \(expected.type) \(expected.effectiveAt)",
                fixture: fixture,
                file: file,
                line: line
            )
        }
    }

    private func assertRemotePrices(
        _ prices: [RemoteInventoryProductPriceRow],
        expected: [ExpectedPoint],
        fixture: Fixture,
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
            XCTAssertPrice(
                row.price,
                equals: expected.price,
                label: "remote \(expected.type.rawValue) \(expected.effectiveAt)",
                fixture: fixture,
                file: file,
                line: line
            )
        }
    }

    private func activeSuppliers(in snapshot: RemoteSnapshot, fixture: Fixture) -> [RemoteInventorySupplierRow] {
        snapshot.suppliers.filter { $0.deletedAt == nil && fixture.allSupplierNames.contains($0.name) }
    }

    private func activeCategories(in snapshot: RemoteSnapshot, fixture: Fixture) -> [RemoteInventoryCategoryRow] {
        snapshot.categories.filter { $0.deletedAt == nil && fixture.allCategoryNames.contains($0.name) }
    }

    private func activeProducts(in snapshot: RemoteSnapshot, barcodes: Set<String>) -> [RemoteInventoryProductRow] {
        snapshot.products.filter { $0.deletedAt == nil && barcodes.contains($0.barcode) }
    }

    private func singleActiveProduct(in snapshot: RemoteSnapshot, barcode: String) -> RemoteInventoryProductRow? {
        let matches = activeProducts(in: snapshot, barcodes: [barcode])
        return matches.count == 1 ? matches[0] : nil
    }

    private func prices(in snapshot: RemoteSnapshot, productID: UUID) -> [RemoteInventoryProductPriceRow] {
        snapshot.prices.filter { $0.productID == productID }
    }

    private func expectedIOS() -> [ExpectedPoint] {
        [
            ExpectedPoint(type: .purchase, price: 11.10, effectiveAt: "2026-05-12 13:00:00"),
            ExpectedPoint(type: .purchase, price: 12.35, effectiveAt: "2026-05-12 13:15:00"),
            ExpectedPoint(type: .retail, price: 18.90, effectiveAt: "2026-05-12 13:00:00"),
            ExpectedPoint(type: .retail, price: 20.50, effectiveAt: "2026-05-12 13:15:00")
        ]
    }

    private func expectedAndroid() -> [ExpectedPoint] {
        [
            ExpectedPoint(type: .purchase, price: 21.10, effectiveAt: "2026-05-12 14:00:00"),
            ExpectedPoint(type: .purchase, price: 22.35, effectiveAt: "2026-05-12 14:15:00"),
            ExpectedPoint(type: .retail, price: 31.90, effectiveAt: "2026-05-12 14:00:00"),
            ExpectedPoint(type: .retail, price: 33.50, effectiveAt: "2026-05-12 14:15:00")
        ]
    }

    private func expectedMediumCanary() -> [ExpectedPoint] {
        [
            ExpectedPoint(type: .purchase, price: 40.01, effectiveAt: "2026-05-12 15:00:00"),
            ExpectedPoint(type: .purchase, price: 41.01, effectiveAt: "2026-05-12 15:15:01"),
            ExpectedPoint(type: .retail, price: 60.01, effectiveAt: "2026-05-12 15:00:00"),
            ExpectedPoint(type: .retail, price: 61.01, effectiveAt: "2026-05-12 15:15:01")
        ]
    }

    private func expectedConflictPrice() -> [ExpectedPoint] {
        [
            ExpectedPoint(type: .purchase, price: 61.00, effectiveAt: "2026-05-12 16:00:00"),
            ExpectedPoint(type: .purchase, price: 62.00, effectiveAt: "2026-05-12 16:15:00"),
            ExpectedPoint(type: .retail, price: 71.00, effectiveAt: "2026-05-12 16:00:00"),
            ExpectedPoint(type: .retail, price: 72.00, effectiveAt: "2026-05-12 16:15:00")
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
        fixture: Fixture,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("\(label) missing", file: file, line: line)
            return
        }
        XCTAssertLessThanOrEqual(abs(actual - expected), fixture.tolerance, label, file: file, line: line)
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
            "invalid:\(plan.summary.excludedInvalidLocal)"
        ]
        return (candidates + summary).joined(separator: "\n")
    }

    private struct Runtime {
        let config: SupabaseConfig
        let provider: SupabaseClientProvider
        let inventory: SupabaseTransportClient
        let session: SupabaseAuthSessionInfo

        var productPriceRemote: ProductPriceRemoteSupabaseAdapter {
            ProductPriceRemoteSupabaseAdapter(remote: inventory)
        }

        var recoveryRemote: RecoveryRemoteSupabaseAdapter {
            RecoveryRemoteSupabaseAdapter(remote: inventory)
        }
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

    private struct MediumPriceEntry {
        let barcode: String
        let type: PriceType
        let price: Double
        let effectiveAt: Date
    }

    private enum HarnessError: Error {
        case unexpectedCatalogPushStatus(String)
        case unverifiedPricePush
        case priceIdentityLinkMismatch(linked: Int, expected: Int)
    }
}

private extension Int {
    var padded2: String { String(format: "%02d", self) }
    var padded3: String { String(format: "%03d", self) }
}

private final class Task103NetworkDownManualPushRemoteGateway: SupabaseManualPushRemoteGateway {
    func createSuppliers(_ payloads: [SupabaseManualPushSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow] {
        throw offline()
    }

    func updateSupplier(id: UUID, payload: SupabaseManualPushSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow {
        throw offline()
    }

    func verifySupplier(id: UUID, normalizedName: String) async throws -> RemoteInventorySupplierRow {
        throw offline()
    }

    func createCategories(_ payloads: [SupabaseManualPushCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow] {
        throw offline()
    }

    func updateCategory(id: UUID, payload: SupabaseManualPushCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow {
        throw offline()
    }

    func verifyCategory(id: UUID, normalizedName: String) async throws -> RemoteInventoryCategoryRow {
        throw offline()
    }

    func createProducts(_ payloads: [SupabaseManualPushProductCreatePayload]) async throws -> [RemoteInventoryProductRow] {
        throw offline()
    }

    func updateProduct(id: UUID, payload: SupabaseManualPushProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        throw offline()
    }

    func verifyProduct(id: UUID, normalizedBarcode: String) async throws -> RemoteInventoryProductRow {
        throw offline()
    }

    func verifyReadBack(expectation: SupabaseManualPushReadBackExpectation) async throws {
        throw offline()
    }

    private func offline() -> SupabaseTransportClientError {
        .networkError(statusCode: nil, message: "TASK103 simulated Supabase unreachable")
    }
}

private extension SupabaseAuthService {
    static func sessionInfoForTask103(_ session: Session) -> SupabaseAuthSessionInfo {
        SupabaseAuthSessionInfo(
            userID: session.user.id,
            email: nil,
            provider: nil,
            isExpired: session.isExpired
        )
    }
}
