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
        var logPrefix: String {
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

        var allSupplierNames: [String] {
            [supplierIOS, supplierAndroid, supplierConflictCatalog, supplierConflictPrice, supplierOffline] + mediumSuppliers
        }

        var allCategoryNames: [String] {
            [categoryIOS, categoryAndroid, categoryConflictCatalog, categoryConflictPrice, categoryOffline] + mediumCategories
        }

        var allBarcodes: [String] {
            [barcodeIOS, barcodeAndroid, barcodeConflictCatalog, barcodeConflictPrice, barcodeOffline] + mediumBarcodes
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
            priceRemoteFetcher: runtime.inventory,
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

        let priceConflictPlan = try await SupabaseProductPricePushDryRunService(fetcher: runtime.inventory).loadDryRun(
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
            priceRemoteFetcher: runtime.inventory,
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
        return push
    }

    private func pushPendingPrices(
        context: ModelContext,
        runtime: Runtime
    ) async throws -> ProductPriceManualPushResult {
        let aggregated = try await LocalPendingAggregatedPushPlanner(
            context: context,
            priceRemoteFetcher: runtime.inventory,
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
        let push = try await SupabaseProductPriceManualPushService(remote: runtime.inventory).push(snapshot: snapshot)
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
        return push
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
                priceRemoteFetcher: runtime.inventory,
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
            let push = try await SupabaseProductPriceManualPushService(remote: runtime.inventory).push(snapshot: snapshot)
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
            inventory: SupabaseInventoryService(clientProvider: provider),
            session: SupabaseAuthService.sessionInfoForTask103(session)
        )
    }

    private func requireLiveAcceptanceEnabled() throws {
        let environment = ProcessInfo.processInfo.environment
        let task103Value = (environment["TASK103_LIVE_ACCEPTANCE"] ?? environment["TEST_RUNNER_TASK103_LIVE_ACCEPTANCE"])?.lowercased()
        let task104Value = (environment["TASK104_PASS2_LIVE_ACCEPTANCE"] ?? environment["TEST_RUNNER_TASK104_PASS2_LIVE_ACCEPTANCE"])?.lowercased()
        let task112Value = (environment["TASK112_LIVE_ACCEPTANCE"] ?? environment["TEST_RUNNER_TASK112_LIVE_ACCEPTANCE"])?.lowercased()
        guard task103Value == "1" || task103Value == "true"
            || task104Value == "1" || task104Value == "true"
            || task112Value == "1" || task112Value == "true" else {
            throw XCTSkip("Live acceptance is gated. Set TASK103_LIVE_ACCEPTANCE=1, TASK104_PASS2_LIVE_ACCEPTANCE=1 or TASK112_LIVE_ACCEPTANCE=1 in the xctestrun environment.")
        }
    }

    private func makeFixture() throws -> Fixture {
        let environment = ProcessInfo.processInfo.environment
        guard let prefix = environment["TASK104_PASS2_RUN_PREFIX"]
            ?? environment["TEST_RUNNER_TASK104_PASS2_RUN_PREFIX"]
            ?? environment["TASK103_RUN_PREFIX"]
            ?? environment["TEST_RUNNER_TASK103_RUN_PREFIX"]
            ?? environment["TASK112_RUN_PREFIX"]
            ?? environment["TEST_RUNNER_TASK112_RUN_PREFIX"] else {
            throw XCTSkip("TASK104_PASS2_RUN_PREFIX, TASK103_RUN_PREFIX or TASK112_RUN_PREFIX must be explicitly set for live acceptance.")
        }
        guard (
            prefix.hasPrefix("TASK103_REAL_R")
                || prefix.hasPrefix("TASK104_PASS2_")
                || prefix.hasPrefix("TASK112_")
        ), prefix.hasSuffix("_") else {
            throw XCTSkip("Run prefix must be run-scoped TASK103_REAL_R..._, TASK104_PASS2_..._ or TASK112_..._.")
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
            runtime.inventory,
            ownerUserID: runtime.session.userID,
            productIDs: products.map(\.id)
        )
        return try await RemoteSnapshot(suppliers: suppliers, categories: categories, products: products, prices: prices)
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
            .order(SupabaseInventoryService.stablePageOrderColumn, ascending: true)
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
            .order(SupabaseInventoryService.stablePageOrderColumn, ascending: true)
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
            .order(SupabaseInventoryService.stablePageOrderColumn, ascending: true)
            .limit(100)
            .execute()
            .value
    }

    private func fetchFixturePrices(
        _ inventory: SupabaseInventoryService,
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
        let inventory: SupabaseInventoryService
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

    private func offline() -> SupabaseInventoryServiceError {
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
