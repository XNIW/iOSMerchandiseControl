import CryptoKit
import Foundation
import SwiftData
import Supabase
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class Task072DLiveAcceptanceHarnessTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private static var retainedContexts: [ModelContext] = []

    func testTask072DExportSessionForAndroidImport() async throws {
        try requireLiveAcceptanceEnabled()
        let environment = ProcessInfo.processInfo.environment
        guard let exportPath = environment["TASK072D_SESSION_EXPORT_PATH"]
            ?? environment["TEST_RUNNER_TASK072D_SESSION_EXPORT_PATH"] else {
            throw XCTSkip("TASK072D_SESSION_EXPORT_PATH is required for Android session handoff.")
        }
        guard exportPath.hasPrefix("/tmp/") || exportPath.hasPrefix("/var/folders/") else {
            throw XCTSkip("TASK072D_SESSION_EXPORT_PATH must be an ephemeral path outside the repository.")
        }

        let runtime = try await makeRuntime()
        let session = try await runtime.provider.client.auth.session
        XCTAssertFalse(session.isExpired)
        XCTAssertFalse(session.accessToken.isEmpty)
        XCTAssertFalse(session.refreshToken.isEmpty)

        let url = URL(fileURLWithPath: exportPath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let payload = [
            "access": session.accessToken,
            "refresh": session.refreshToken
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)

        print(
            "TASK072D_IOS_SESSION_EXPORT owner_hash=\(ownerHash(runtime.session.userID)) " +
            "project_hash=\(hash(runtime.config.projectURL.absoluteString)) path_hash=\(hash(exportPath)) " +
            "bytes=\(data.count) status=written"
        )
    }

    func testTask072DIOSCreateUpdateTombstoneHistoryHarness() async throws {
        try requireLiveAcceptanceEnabled()
        let fixture = try makeFixture()
        let runtime = try await makeRuntime()
        let context = try makeTask072DContext()
        let runStarted = Date()

        let before = try localStoreSnapshot(
            context: context,
            ownerUserID: runtime.session.userID,
            scope: fixture.iosScope,
            runStarted: nil
        )
        print(
            "\(fixture.logPrefix)_IOS_STORE_BEFORE owner_hash=\(ownerHash(runtime.session.userID)) " +
            "prefix_hash=\(hash(fixture.iosScope.prefix)) \(before.summaryLine)"
        )
        XCTAssertEqual(before.prefixedActiveProducts + before.prefixedTombstonedProducts, 0)
        XCTAssertEqual(before.prefixedActiveSuppliers + before.prefixedTombstonedSuppliers, 0)
        XCTAssertEqual(before.prefixedActiveCategories + before.prefixedTombstonedCategories, 0)
        XCTAssertEqual(before.prefixedActiveHistory + before.prefixedTombstonedHistory, 0)

        let remoteBefore = try await fetchRemoteSnapshot(runtime, scope: fixture.iosScope)
        let sessionsBefore = try await fetchFixtureSessions(runtime, scope: fixture.iosScope)
        XCTAssertTrue(remoteBefore.suppliers.isEmpty)
        XCTAssertTrue(remoteBefore.categories.isEmpty)
        XCTAssertTrue(remoteBefore.products.isEmpty)
        XCTAssertTrue(remoteBefore.prices.isEmpty)
        XCTAssertTrue(sessionsBefore.isEmpty)

        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: context,
            ownerUserUUID: runtime.session.userID
        )

        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: runtime.session.userID)
        let supplier = Supplier(name: fixture.iosScope.supplierInitialName)
        let category = ProductCategory(name: fixture.iosScope.categoryInitialName)
        context.insert(supplier)
        context.insert(category)
        try accumulator.recordSupplierChange(supplier: supplier, operation: .create, origin: .manualCatalogSave)
        try accumulator.recordCategoryChange(category: category, operation: .create, origin: .manualCatalogSave)

        let createProduct = catalogProduct(
            barcode: fixture.iosScope.productCreateBarcode,
            name: fixture.iosScope.productCreateName,
            supplier: supplier,
            category: category
        )
        let updateProduct = catalogProduct(
            barcode: fixture.iosScope.productUpdateBarcode,
            name: fixture.iosScope.productUpdateInitialName,
            supplier: supplier,
            category: category
        )
        let tombstoneProduct = catalogProduct(
            barcode: fixture.iosScope.productTombstoneBarcode,
            name: fixture.iosScope.productTombstoneName,
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

        let createCatalogPush = try await pushPendingCatalog(
            context: context,
            runtime: runtime,
            expectedReadyCandidatesAtLeast: 5,
            logPrefix: fixture.logPrefix
        )
        XCTAssertEqual(createCatalogPush.status, .completed)

        supplier.name = fixture.iosScope.supplierFinalName
        category.name = fixture.iosScope.categoryFinalName
        updateProduct.productName = fixture.iosScope.productUpdateFinalName
        try accumulator.recordSupplierChange(supplier: supplier, operation: .update, origin: .manualCatalogSave)
        try accumulator.recordCategoryChange(category: category, operation: .update, origin: .manualCatalogSave)
        try accumulator.recordProductChange(
            product: updateProduct,
            operation: .update,
            origin: .manualCatalogSave,
            changedFields: ["productName"]
        )
        try context.save()

        let updateCatalogPush = try await pushPendingCatalog(
            context: context,
            runtime: runtime,
            expectedReadyCandidatesAtLeast: 3,
            logPrefix: fixture.logPrefix
        )
        XCTAssertEqual(updateCatalogPush.status, .completed)

        try accumulator.recordProductChange(
            product: tombstoneProduct,
            operation: .delete,
            origin: .manualCatalogSave,
            changedFields: ["tombstone"],
            baselineFingerprintHash: LocalPendingChangeLogicalKey.productFingerprintHash(tombstoneProduct)
        )
        context.delete(tombstoneProduct)
        try context.save()

        let tombstoneCatalogPush = try await pushPendingCatalog(
            context: context,
            runtime: runtime,
            expectedReadyCandidatesAtLeast: 1,
            logPrefix: fixture.logPrefix
        )
        XCTAssertEqual(tombstoneCatalogPush.status, .completed)

        let historyCreate = historyEntry(
            title: fixture.iosScope.historyCreateTitle,
            supplier: fixture.iosScope.supplierFinalName,
            category: fixture.iosScope.categoryFinalName
        )
        let historyUpdate = historyEntry(
            title: fixture.iosScope.historyUpdateInitialTitle,
            supplier: fixture.iosScope.supplierFinalName,
            category: fixture.iosScope.categoryFinalName
        )
        let historyTombstone = historyEntry(
            title: fixture.iosScope.historyTombstoneTitle,
            supplier: fixture.iosScope.supplierFinalName,
            category: fixture.iosScope.categoryFinalName
        )
        for entry in [historyCreate, historyUpdate, historyTombstone] {
            context.insert(entry)
            entry.markHistorySessionLocalMutation()
            try accumulator.recordHistorySessionChange(entry: entry, operation: .upsert, changedFields: ["create"])
        }
        try context.save()

        let createHistoryPush = try await pushPendingHistory(
            [historyCreate, historyUpdate, historyTombstone],
            context: context,
            runtime: runtime,
            logPrefix: fixture.logPrefix
        )
        XCTAssertEqual(createHistoryPush.uploadedCount, 3)

        historyUpdate.title = fixture.iosScope.historyUpdateFinalTitle
        historyUpdate.markHistorySessionLocalMutation()
        try accumulator.recordHistorySessionChange(entry: historyUpdate, operation: .upsert, changedFields: ["displayName"])
        try context.save()

        let updateHistoryPush = try await pushPendingHistory(
            [historyUpdate],
            context: context,
            runtime: runtime,
            logPrefix: fixture.logPrefix
        )
        XCTAssertEqual(updateHistoryPush.uploadedCount, 1)

        historyTombstone.markHistorySessionLocalDeletion()
        try accumulator.recordHistorySessionChange(entry: historyTombstone, operation: .delete, changedFields: ["tombstone"])
        try context.save()

        let tombstoneHistoryPush = try await pushPendingHistory(
            [historyTombstone],
            context: context,
            runtime: runtime,
            logPrefix: fixture.logPrefix
        )
        XCTAssertEqual(tombstoneHistoryPush.uploadedCount, 1)

        let readBack = try await fetchRemoteSnapshot(runtime, scope: fixture.iosScope)
        try assertIOSWriteReadBack(snapshot: readBack, runtime: runtime, fixture: fixture)

        let sessions = try await fetchFixtureSessions(runtime, scope: fixture.iosScope)
        XCTAssertNotNil(session(in: sessions, displayName: fixture.iosScope.historyCreateTitle))
        XCTAssertNotNil(session(in: sessions, displayName: fixture.iosScope.historyUpdateFinalTitle))
        XCTAssertNotNil(try XCTUnwrap(session(in: sessions, displayName: fixture.iosScope.historyTombstoneTitle)).deletedAt)

        let adminReceive = try await receiveExternalScopeIfAvailable(
            fixture.adminScope,
            context: context,
            runtime: runtime,
            logPrefix: fixture.logPrefix
        )
        let androidReceive = try await receiveExternalScopeIfAvailable(
            fixture.androidScope,
            context: context,
            runtime: runtime,
            logPrefix: fixture.logPrefix
        )
        if fixture.requiresExternalReceive {
            XCTAssertTrue(adminReceive.wasAvailable || androidReceive.wasAvailable)
        }

        let after = try localStoreSnapshot(
            context: context,
            ownerUserID: runtime.session.userID,
            scope: fixture.iosScope,
            runStarted: runStarted
        )
        XCTAssertEqual(after.runOpenOutboxCount, 0)
        XCTAssertEqual(after.runOutboxByStatus[.pending, default: 0], 0)
        XCTAssertEqual(after.runOutboxByStatus[.failedRetryable, default: 0], 0)
        XCTAssertEqual(after.runOutboxByStatus[.sending, default: 0], 0)
        XCTAssertEqual(after.outboxLocalOnly, before.outboxLocalOnly)
        XCTAssertEqual(after.runPendingLocalChanges, 0)

        print(
            "\(fixture.logPrefix)_IOS_STORE_AFTER owner_hash=\(ownerHash(runtime.session.userID)) " +
            "prefix_hash=\(hash(fixture.iosScope.prefix)) \(after.summaryLine)"
        )
        print(
            "\(fixture.logPrefix)_IOS_WRITE_VERIFY owner_hash=\(ownerHash(runtime.session.userID)) " +
            "prefix_hash=\(hash(fixture.iosScope.prefix)) catalog_create=pass catalog_update=pass catalog_tombstone=pass " +
            "history_create=pass history_update=pass history_tombstone=pass " +
            "remote_product_hashes={create=\(hash(try XCTUnwrap(product(in: readBack, barcode: fixture.iosScope.productCreateBarcode)).id.uuidString.lowercased()))," +
            "update=\(hash(try XCTUnwrap(product(in: readBack, barcode: fixture.iosScope.productUpdateBarcode)).id.uuidString.lowercased()))," +
            "tombstone=\(hash(try XCTUnwrap(product(in: readBack, barcode: fixture.iosScope.productTombstoneBarcode)).id.uuidString.lowercased()))} " +
            "admin_receive=\(adminReceive.statusForLog) android_receive=\(androidReceive.statusForLog) " +
            "task072d_outbox_pending=0 preexisting_outbox_localOnly=\(before.outboxLocalOnly) " +
            "run_outbox={\(after.runOutboxSummary)} syncType=EVENT_INCREMENTAL fullPull=false"
        )
    }

    private func assertIOSWriteReadBack(
        snapshot: RemoteSnapshot,
        runtime: Runtime,
        fixture: Fixture
    ) throws {
        let create = try XCTUnwrap(singleActiveProduct(in: snapshot, barcode: fixture.iosScope.productCreateBarcode))
        XCTAssertEqual(create.productName, fixture.iosScope.productCreateName)

        let update = try XCTUnwrap(singleActiveProduct(in: snapshot, barcode: fixture.iosScope.productUpdateBarcode))
        XCTAssertEqual(update.productName, fixture.iosScope.productUpdateFinalName)

        let tombstone = try XCTUnwrap(product(in: snapshot, barcode: fixture.iosScope.productTombstoneBarcode))
        XCTAssertNotNil(tombstone.deletedAt)

        XCTAssertNil(try XCTUnwrap(remoteSupplier(in: snapshot, name: fixture.iosScope.supplierFinalName)).deletedAt)
        XCTAssertNil(try XCTUnwrap(remoteCategory(in: snapshot, name: fixture.iosScope.categoryFinalName)).deletedAt)
        XCTAssertFalse(runtime.config.publishableKey.lowercased().contains("service_role"))
        XCTAssertFalse(runtime.config.publishableKey.lowercased().contains("secret_key"))
        XCTAssertFalse(runtime.config.publishableKey.lowercased().contains("sb_secret"))
        XCTAssertFalse(runtime.session.isExpired)
    }

    private func receiveExternalScopeIfAvailable(
        _ scope: Task072DRemoteScope,
        context: ModelContext,
        runtime: Runtime,
        logPrefix: String
    ) async throws -> ExternalReceiveResult {
        let snapshot = try await fetchRemoteSnapshot(runtime, scope: scope)
        let sessions = try await fetchFixtureSessions(runtime, scope: scope)
        let availableProducts = snapshot.products.filter {
            scope.allBarcodes.contains($0.barcode)
        }
        let availableSessions = sessions.filter {
            $0.displayName.hasPrefix(scope.prefix)
        }
        guard !availableProducts.isEmpty || !availableSessions.isEmpty else {
            print(
                "\(logPrefix)_IOS_EXTERNAL_RECEIVE source=\(scope.source.lowercased()) status=unavailable " +
                "prefix_hash=\(hash(scope.prefix)) products=0 history=0"
            )
            return ExternalReceiveResult(source: scope.source, wasAvailable: false, appliedProductCount: 0, appliedHistoryCount: 0)
        }

        var productApplies = 0
        if let remoteCreate = product(in: snapshot, barcode: scope.productCreateBarcode),
           remoteCreate.deletedAt == nil {
            let result = try applyProductCreate(remoteCreate, snapshot: snapshot, context: context, ownerUserID: runtime.session.userID)
            XCTAssertEqual(result.inserted, 1)
            productApplies += 1
        }
        if let remoteUpdate = product(in: snapshot, barcode: scope.productUpdateBarcode),
           remoteUpdate.deletedAt == nil {
            _ = try seedLocalProduct(remote: remoteUpdate, snapshot: snapshot, context: context, staleName: "\(scope.prefix)IOS_STALE_EXTERNAL_UPDATE")
            let result = try applyProductUpdate(remoteUpdate, snapshot: snapshot, context: context, ownerUserID: runtime.session.userID)
            XCTAssertEqual(result.updated, 1)
            XCTAssertEqual(try localProduct(context: context, barcode: scope.productUpdateBarcode)?.productName, remoteUpdate.productName)
            productApplies += 1
        }
        if let remoteTombstone = product(in: snapshot, barcode: scope.productTombstoneBarcode),
           remoteTombstone.deletedAt != nil {
            let localTombstone = try seedLocalProduct(remote: remoteTombstone, snapshot: snapshot, context: context, staleName: scope.productTombstoneName)
            let result = try applyProductTombstone(remoteTombstone, snapshot: snapshot, context: context, ownerUserID: runtime.session.userID)
            XCTAssertEqual(result.productTombstoned, 1)
            XCTAssertNotNil(localTombstone.remoteDeletedAt)
            productApplies += 1
        }

        let historyService = HistorySessionSyncService(remote: HistorySessionRemoteSupabaseAdapter(remote: runtime.inventory))
        var historyApplies = 0
        if let historyCreate = session(in: sessions, displayName: scope.historyCreateTitle),
           historyCreate.deletedAt == nil {
            let result = try historyService.applyRemoteSharedSheetSessions([historyCreate], ownerUserID: runtime.session.userID, context: context)
            XCTAssertEqual(result.insertedCount, 1)
            historyApplies += 1
        }
        if let historyUpdate = session(in: sessions, displayName: scope.historyUpdateFinalTitle),
           historyUpdate.deletedAt == nil {
            _ = try seedLocalHistoryEntry(remote: historyUpdate, context: context, title: "\(scope.prefix)IOS_STALE_EXTERNAL_HISTORY_UPDATE")
            let result = try historyService.applyRemoteSharedSheetSessions([historyUpdate], ownerUserID: runtime.session.userID, context: context)
            XCTAssertEqual(result.updatedCount, 1)
            XCTAssertEqual(try localHistoryEntry(context: context, remoteID: historyUpdate.remoteID)?.title, scope.historyUpdateFinalTitle)
            historyApplies += 1
        }
        if let historyTombstone = session(in: sessions, displayName: scope.historyTombstoneTitle),
           historyTombstone.deletedAt != nil {
            let localTombstone = try seedLocalHistoryEntry(remote: historyTombstone, context: context, title: scope.historyTombstoneTitle)
            let result = try historyService.applyRemoteSharedSheetSessions([historyTombstone], ownerUserID: runtime.session.userID, context: context)
            XCTAssertEqual(result.updatedCount, 1)
            XCTAssertNotNil(localTombstone.remoteDeletedAt)
            historyApplies += 1
        }
        try context.save()

        print(
            "\(logPrefix)_IOS_EXTERNAL_RECEIVE source=\(scope.source.lowercased()) status=available " +
            "prefix_hash=\(hash(scope.prefix)) product_applies=\(productApplies) history_applies=\(historyApplies)"
        )
        return ExternalReceiveResult(
            source: scope.source,
            wasAvailable: true,
            appliedProductCount: productApplies,
            appliedHistoryCount: historyApplies
        )
    }

    private func pushPendingCatalog(
        context: ModelContext,
        runtime: Runtime,
        expectedReadyCandidatesAtLeast: Int,
        logPrefix: String
    ) async throws -> SupabaseManualPushResult {
        let aggregated = try await LocalPendingAggregatedPushPlanner(
            context: context,
            includesCatalog: true,
            includesProductPrice: false
        ).makePlan(ownerUserID: runtime.session.userID)
        XCTAssertTrue(aggregated.blockers.isEmpty)
        let batch = try XCTUnwrap(aggregated.catalogBatch)
        XCTAssertGreaterThanOrEqual(batch.plan.candidates.count, expectedReadyCandidatesAtLeast)

        let stateStore = LocalPendingAggregatedPushStateStore(context: context)
        try stateStore.markSent(
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
        try stateStore.markAcknowledged(
            changeIDs: batch.changeIDs,
            ownerUserID: runtime.session.userID
        )
        try await recordCatalogSyncEvent(
            context: context,
            runtime: runtime,
            result: push,
            planFingerprint: batch.plan.planFingerprint,
            logPrefix: logPrefix
        )
        return push
    }

    private func recordCatalogSyncEvent(
        context: ModelContext,
        runtime: Runtime,
        result: SupabaseManualPushResult,
        planFingerprint: String,
        logPrefix: String
    ) async throws {
        let enqueue = SyncEventOutboxEnqueueService(context: context).enqueue(
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
            "\(logPrefix)_SYNC_EVENT_ENQUEUE kind=\(enqueue.kind.rawValue) " +
            "entryStatus=\(enqueue.entryStatus?.rawValue ?? "nil") error=\(enqueue.errorCode ?? "nil") " +
            "confirmed=\(confirmedCatalogChangeCount) suppliers=\(result.touchedIDs.suppliers.count) " +
            "categories=\(result.touchedIDs.categories.count) products=\(result.touchedIDs.products.count)"
        )
        guard enqueue.kind == .enqueued || enqueue.kind == .duplicateNoOp || enqueue.kind == .skippedNoOp else {
            throw HarnessError.unexpectedCatalogPushStatus("sync_event_enqueue_failed")
        }

        let recorder = SupabaseSyncEventLiveRecorder(
            configProvider: SupabaseSyncEventLiveRecorderConfigurationProvider(),
            sessionProvider: StaticSyncEventSessionProvider(session: runtime.session),
            transport: SupabaseSyncEventRPCTransport(clientProvider: runtime.provider)
        )
        let drain = try await SyncEventOutboxDrainService(context: context, recorder: recorder)
            .drainOnce(ownerUserID: runtime.session.userID.uuidString, limit: 25)
        print(
            "\(logPrefix)_SYNC_EVENT_DRAIN status=\(drain.status.rawValue) attempted=\(drain.attempted) " +
            "sent=\(drain.sent) retry=\(drain.retryScheduled) blocked=\(drain.blocked) " +
            "dead=\(drain.dead) skipped=\(drain.skippedIneligible)"
        )
        if confirmedCatalogChangeCount > 0 {
            guard drain.sent > 0 else {
                throw HarnessError.unexpectedCatalogPushStatus(
                    "sync_event_drain_no_sent_status_\(drain.status.rawValue)_enqueue_\(enqueue.kind.rawValue)"
                )
            }
        }

        let generatedPriceEnqueue = try await CatalogGeneratedProductPriceSyncEventRecorder(
            context: context,
            remote: runtime.productPriceRemote
        ).recordIfNeeded(
            catalogResult: result,
            ownerUserID: runtime.session.userID,
            planFingerprint: planFingerprint
        )
        print(
            "\(logPrefix)_CATALOG_GENERATED_PRICE_SYNC_EVENT_ENQUEUE kind=\(generatedPriceEnqueue.kind.rawValue) " +
            "entryStatus=\(generatedPriceEnqueue.entryStatus?.rawValue ?? "nil") " +
            "error=\(generatedPriceEnqueue.errorCode ?? "nil") products=\(result.touchedIDs.products.count)"
        )
        guard generatedPriceEnqueue.kind == .enqueued
            || generatedPriceEnqueue.kind == .duplicateNoOp
            || generatedPriceEnqueue.kind == .skippedNoOp else {
            throw HarnessError.unexpectedCatalogPushStatus("catalog_generated_price_sync_event_enqueue_failed")
        }
        if generatedPriceEnqueue.kind == .enqueued {
            let priceDrain = try await SyncEventOutboxDrainService(context: context, recorder: recorder)
                .drainOnce(ownerUserID: runtime.session.userID.uuidString, limit: 25)
            print(
                "\(logPrefix)_CATALOG_GENERATED_PRICE_SYNC_EVENT_DRAIN status=\(priceDrain.status.rawValue) " +
                "attempted=\(priceDrain.attempted) sent=\(priceDrain.sent) retry=\(priceDrain.retryScheduled) " +
                "blocked=\(priceDrain.blocked) dead=\(priceDrain.dead) skipped=\(priceDrain.skippedIneligible)"
            )
            guard priceDrain.sent > 0 else {
                throw HarnessError.unexpectedCatalogPushStatus(
                    "catalog_generated_price_sync_event_drain_no_sent_status_\(priceDrain.status.rawValue)"
                )
            }
        }
    }

    private func pushPendingHistory(
        _ entries: [HistoryEntry],
        context: ModelContext,
        runtime: Runtime,
        logPrefix: String
    ) async throws -> HistorySessionPushResult {
        let result = try await HistorySessionSyncService(remote: HistorySessionRemoteSupabaseAdapter(remote: runtime.inventory)).pushPendingHistorySessions(
            entries: entries,
            ownerUserID: runtime.session.userID,
            context: context
        )
        try await recordHistorySyncEvent(runtime: runtime, result: result, logPrefix: logPrefix)
        return result
    }

    private func recordHistorySyncEvent(
        runtime: Runtime,
        result: HistorySessionPushResult,
        logPrefix: String
    ) async throws {
        guard result.uploadedCount > 0, !result.pushedRemoteIDs.isEmpty else { return }
        let sortedIDs = result.pushedRemoteIDs.sorted { $0.uuidString < $1.uuidString }
        let recorder = SupabaseSyncEventLiveRecorder(
            configProvider: SupabaseSyncEventLiveRecorderConfigurationProvider(),
            sessionProvider: StaticSyncEventSessionProvider(session: runtime.session),
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
            clientEventID: "\(logPrefix.lowercased())-ios-history-\(runtime.session.userID.uuidString.lowercased())-\(UUID().uuidString.lowercased())"
        )
        _ = try await recorder.record(request)
        print(
            "\(logPrefix)_HISTORY_SYNC_EVENT_RECORD syncType=EVENT_INCREMENTAL " +
            "sessions=\(sortedIDs.count) fullPull=false"
        )
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

    private func catalogProduct(
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

    private func historyEntry(
        title: String,
        supplier: String,
        category: String
    ) -> HistoryEntry {
        let entry = HistoryEntry(
            id: title,
            timestamp: Date(timeIntervalSince1970: 1_779_840_000),
            isManualEntry: true,
            data: [["barcode", "count"], [title, "1"]],
            editable: [["", ""], ["", "1"]],
            complete: [false, true],
            supplier: supplier,
            category: category,
            totalItems: 1,
            paymentTotal: 1,
            missingItems: 0
        )
        entry.title = title
        return entry
    }

    private func makeRuntime() async throws -> Runtime {
        let config = try SupabaseConfig.load()
        let provider = SupabaseClientProvider(config: config)
        let session = try await provider.client.auth.session
        return Runtime(
            config: config,
            provider: provider,
            inventory: SupabaseTransportClient(clientProvider: provider),
            session: SupabaseAuthSessionInfo(
                userID: session.user.id,
                email: nil,
                provider: nil,
                isExpired: session.isExpired
            )
        )
    }

    private func requireLiveAcceptanceEnabled() throws {
        let environment = ProcessInfo.processInfo.environment
        let value = (
            environment["TASK072D_LIVE_ACCEPTANCE"]
                ?? environment["TEST_RUNNER_TASK072D_LIVE_ACCEPTANCE"]
        )?.lowercased()
        guard value == "1" || value == "true" else {
            throw XCTSkip("TASK072D live acceptance is gated. Set TASK072D_LIVE_ACCEPTANCE=1.")
        }
    }

    private func makeFixture() throws -> Fixture {
        let environment = ProcessInfo.processInfo.environment
        guard let prefix = environment["TASK072D_RUN_PREFIX"]
            ?? environment["TEST_RUNNER_TASK072D_RUN_PREFIX"] else {
            throw XCTSkip("TASK072D_RUN_PREFIX=TASK072D_IOS_<run>_ is required.")
        }
        guard prefix.hasPrefix("TASK072D_IOS_"), prefix.hasSuffix("_") else {
            throw XCTSkip("TASK072D_RUN_PREFIX must be run-scoped as TASK072D_IOS_<run>_.")
        }

        let adminPrefix = environment["TASK072D_ADMIN_RUN_PREFIX"]
            ?? environment["TEST_RUNNER_TASK072D_ADMIN_RUN_PREFIX"]
            ?? prefix.replacingOccurrences(of: "TASK072D_IOS_", with: "TASK072D_ADMIN_")
        let androidPrefix = environment["TASK072D_ANDROID_RUN_PREFIX"]
            ?? environment["TEST_RUNNER_TASK072D_ANDROID_RUN_PREFIX"]
            ?? prefix.replacingOccurrences(of: "TASK072D_IOS_", with: "TASK072D_ANDROID_")
        let requiresExternal = Self.isEnabled(
            environment["TASK072D_REQUIRE_EXTERNAL_RECEIVE"]
                ?? environment["TEST_RUNNER_TASK072D_REQUIRE_EXTERNAL_RECEIVE"]
        )

        return Fixture(
            iosScope: Task072DRemoteScope(source: "IOS", prefix: prefix),
            adminScope: Task072DRemoteScope(source: "ADMIN", prefix: adminPrefix),
            androidScope: Task072DRemoteScope(source: "ANDROID", prefix: androidPrefix),
            requiresExternalReceive: requiresExternal
        )
    }

    private static func isEnabled(_ value: String?) -> Bool {
        guard let value = value?.lowercased() else { return false }
        return value == "1" || value == "true"
    }

    private func fetchRemoteSnapshot(
        _ runtime: Runtime,
        scope: Task072DRemoteScope
    ) async throws -> RemoteSnapshot {
        async let suppliers = fetchFixtureSuppliers(runtime.provider, ownerUserID: runtime.session.userID, scope: scope)
        async let categories = fetchFixtureCategories(runtime.provider, ownerUserID: runtime.session.userID, scope: scope)
        let products = try await fetchFixtureProducts(runtime.provider, ownerUserID: runtime.session.userID, scope: scope)
        let prices = try await fetchFixturePrices(
            runtime.productPriceRemote,
            ownerUserID: runtime.session.userID,
            productIDs: products.map(\.id)
        )
        return try await RemoteSnapshot(suppliers: suppliers, categories: categories, products: products, prices: prices)
    }

    private func fetchFixtureSessions(
        _ runtime: Runtime,
        scope: Task072DRemoteScope
    ) async throws -> [RemoteSharedSheetSessionRow] {
        try await runtime.provider.client
            .from("shared_sheet_sessions")
            .select("remote_id,payload_version,display_name,timestamp,supplier,category,is_manual_entry,data,session_overlay,owner_user_id,updated_at,deleted_at")
            .eq("owner_user_id", value: runtime.session.userID.uuidString)
            .like("display_name", pattern: "\(scope.prefix)%")
            .order("remote_id", ascending: true)
            .limit(100)
            .execute()
            .value
    }

    private func fetchFixtureSuppliers(
        _ provider: SupabaseClientProvider,
        ownerUserID: UUID,
        scope: Task072DRemoteScope
    ) async throws -> [RemoteInventorySupplierRow] {
        try await provider.client
            .from("inventory_suppliers")
            .select("id,owner_user_id,name,updated_at,deleted_at")
            .eq("owner_user_id", value: ownerUserID.uuidString)
            .in("name", values: scope.allSupplierNames)
            .order(SupabaseTransportClient.stablePageOrderColumn, ascending: true)
            .limit(20)
            .execute()
            .value
    }

    private func fetchFixtureCategories(
        _ provider: SupabaseClientProvider,
        ownerUserID: UUID,
        scope: Task072DRemoteScope
    ) async throws -> [RemoteInventoryCategoryRow] {
        try await provider.client
            .from("inventory_categories")
            .select("id,owner_user_id,name,updated_at,deleted_at")
            .eq("owner_user_id", value: ownerUserID.uuidString)
            .in("name", values: scope.allCategoryNames)
            .order(SupabaseTransportClient.stablePageOrderColumn, ascending: true)
            .limit(20)
            .execute()
            .value
    }

    private func fetchFixtureProducts(
        _ provider: SupabaseClientProvider,
        ownerUserID: UUID,
        scope: Task072DRemoteScope
    ) async throws -> [RemoteInventoryProductRow] {
        try await provider.client
            .from("inventory_products")
            .select("id,owner_user_id,barcode,item_number,product_name,second_product_name,purchase_price,retail_price,supplier_id,category_id,stock_quantity,updated_at,deleted_at")
            .eq("owner_user_id", value: ownerUserID.uuidString)
            .in("barcode", values: scope.allBarcodes)
            .order(SupabaseTransportClient.stablePageOrderColumn, ascending: true)
            .limit(100)
            .execute()
            .value
    }

    private func fetchFixturePrices(
        _ inventory: ProductPriceReleaseRemoteSupabaseAdapter,
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
        let payload = applyPayload(for: product, snapshot: snapshot)
        let summary = SyncPreviewProductSummary(
            classification: .newProduct,
            remoteID: product.id,
            barcode: product.barcode,
            productName: product.productName,
            applyPayload: payload
        )
        return preview(
            product: product,
            snapshot: snapshot,
            remoteTombstoned: false,
            localProductCount: 0,
            newProducts: [summary]
        )
    }

    private func makeUpdatePreview(for product: RemoteInventoryProductRow, snapshot: RemoteSnapshot) -> SyncPreview {
        let payload = applyPayload(for: product, snapshot: snapshot)
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
                    localDisplay: "TASK072D_LOCAL_STALE"
                )
            ],
            applyPayload: payload
        )
        return preview(
            product: product,
            snapshot: snapshot,
            remoteTombstoned: false,
            localProductCount: 1,
            updateCandidates: [summary]
        )
    }

    private func makeTombstonePreview(for product: RemoteInventoryProductRow, snapshot: RemoteSnapshot) -> SyncPreview {
        let payload = applyPayload(for: product, snapshot: snapshot)
        let summary = SyncPreviewProductSummary(
            classification: .remoteTombstone,
            remoteID: product.id,
            barcode: product.barcode,
            productName: product.productName,
            applyPayload: payload
        )
        return preview(
            product: product,
            snapshot: snapshot,
            remoteTombstoned: true,
            localProductCount: 1,
            remoteTombstones: [summary]
        )
    }

    private func applyPayload(for product: RemoteInventoryProductRow, snapshot: RemoteSnapshot) -> SyncPreviewProductApplyPayload {
        SyncPreviewProductApplyPayload(
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
    }

    private func preview(
        product: RemoteInventoryProductRow,
        snapshot: RemoteSnapshot,
        remoteTombstoned: Bool,
        localProductCount: Int,
        newProducts: [SyncPreviewProductSummary] = [],
        updateCandidates: [SyncPreviewProductSummary] = [],
        remoteTombstones: [SyncPreviewProductSummary] = []
    ) -> SyncPreview {
        SyncPreview(
            generatedAt: Date(),
            outcome: .success,
            remoteCounts: RemoteInventorySnapshotCounts(
                products: 1,
                activeProducts: remoteTombstoned ? 0 : 1,
                tombstonedProducts: remoteTombstoned ? 1 : 0,
                suppliers: product.supplierID == nil ? 0 : 1,
                categories: product.categoryID == nil ? 0 : 1,
                productPrices: prices(in: snapshot, productID: product.id).count
            ),
            localCounts: LocalInventorySnapshotCounts(
                products: localProductCount,
                suppliers: product.supplierID == nil ? 0 : 1,
                categories: product.categoryID == nil ? 0 : 1,
                productPrices: 0,
                linkedProducts: localProductCount,
                linkedSuppliers: product.supplierID == nil ? 0 : 1,
                linkedCategories: product.categoryID == nil ? 0 : 1
            ),
            newProducts: newProducts,
            updateCandidates: updateCandidates,
            conflicts: [],
            unchangedProducts: [],
            remoteTombstones: remoteTombstones,
            supplierDiffs: [],
            categoryDiffs: [],
            priceHistoryDiffs: [],
            warnings: [],
            metrics: [],
            sourceErrors: []
        )
    }

    private func makeTask072DContext() throws -> ModelContext {
        guard let storePath = ProcessInfo.processInfo.environment["TASK072D_IOS_STORE_PATH"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_TASK072D_IOS_STORE_PATH"],
              !storePath.isEmpty else {
            return try makeContext()
        }

        let schema = Self.modelSchema
        let configuration = ModelConfiguration(
            "Task072DAppStore",
            schema: schema,
            url: URL(fileURLWithPath: storePath),
            allowsSave: true,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        let context = ModelContext(container)
        Self.retainedContexts.append(context)
        return context
    }

    private func makeContext() throws -> ModelContext {
        let schema = Self.modelSchema
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        let context = ModelContext(container)
        Self.retainedContexts.append(context)
        return context
    }

    private static var modelSchema: Schema {
        Schema([
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
    }

    private func localStoreSnapshot(
        context: ModelContext,
        ownerUserID: UUID,
        scope: Task072DRemoteScope,
        runStarted: Date?
    ) throws -> LocalStoreSnapshot {
        let owner = ownerUserID.uuidString.lowercased()
        let pending = try LocalPendingChangeSnapshotProvider(context: context)
            .loadSnapshot(ownerUserID: ownerUserID)
        let outboxEntries = try context.fetch(FetchDescriptor<SyncEventOutboxEntry>())
            .filter { $0.ownerUserID == owner }
        let runOutboxEntries = outboxEntries.filter { entry in
            guard let runStarted else { return false }
            return entry.createdAt >= runStarted
        }
        let pendingChanges = try context.fetch(FetchDescriptor<LocalPendingChange>())
            .filter { $0.ownerUserID == owner }
        let runPendingLocalChanges = pendingChanges.filter { change in
            guard let runStarted else { return false }
            return change.createdAt >= runStarted && !change.status.isTerminal
        }
        let products = try context.fetch(FetchDescriptor<Product>())
            .filter { scope.allBarcodes.contains($0.barcode) }
        let suppliers = try context.fetch(FetchDescriptor<Supplier>())
            .filter { scope.allSupplierNames.contains($0.name) }
        let categories = try context.fetch(FetchDescriptor<ProductCategory>())
            .filter { scope.allCategoryNames.contains($0.name) }
        let history = try context.fetch(FetchDescriptor<HistoryEntry>())
            .filter { $0.title.hasPrefix(scope.prefix) || $0.id.hasPrefix(scope.prefix) }

        return LocalStoreSnapshot(
            pending: pending,
            outboxByStatus: outboxStatusCounts(outboxEntries),
            runOutboxByStatus: outboxStatusCounts(runOutboxEntries),
            runPendingLocalChanges: runPendingLocalChanges.count,
            prefixedActiveProducts: products.filter { $0.remoteDeletedAt == nil }.count,
            prefixedTombstonedProducts: products.filter { $0.remoteDeletedAt != nil }.count,
            prefixedActiveSuppliers: suppliers.filter { $0.remoteDeletedAt == nil }.count,
            prefixedTombstonedSuppliers: suppliers.filter { $0.remoteDeletedAt != nil }.count,
            prefixedActiveCategories: categories.filter { $0.remoteDeletedAt == nil }.count,
            prefixedTombstonedCategories: categories.filter { $0.remoteDeletedAt != nil }.count,
            prefixedActiveHistory: history.filter { $0.remoteDeletedAt == nil }.count,
            prefixedTombstonedHistory: history.filter { $0.remoteDeletedAt != nil }.count
        )
    }

    private func outboxStatusCounts(_ entries: [SyncEventOutboxEntry]) -> [SyncEventOutboxStatus: Int] {
        entries.reduce(into: [:]) { counts, entry in
            counts[entry.status, default: 0] += 1
        }
    }

    private func product(in snapshot: RemoteSnapshot, barcode: String) -> RemoteInventoryProductRow? {
        let matches = snapshot.products.filter { $0.barcode == barcode }
        return matches.count == 1 ? matches[0] : nil
    }

    private func remoteSupplier(in snapshot: RemoteSnapshot, name: String) -> RemoteInventorySupplierRow? {
        let matches = snapshot.suppliers.filter { $0.name == name }
        return matches.count == 1 ? matches[0] : nil
    }

    private func remoteCategory(in snapshot: RemoteSnapshot, name: String) -> RemoteInventoryCategoryRow? {
        let matches = snapshot.categories.filter { $0.name == name }
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

    private func singleActiveProduct(in snapshot: RemoteSnapshot, barcode: String) -> RemoteInventoryProductRow? {
        let matches = snapshot.products.filter { $0.deletedAt == nil && $0.barcode == barcode }
        return matches.count == 1 ? matches[0] : nil
    }

    private func prices(in snapshot: RemoteSnapshot, productID: UUID) -> [RemoteInventoryProductPriceRow] {
        snapshot.prices.filter { $0.productID == productID }
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

    private struct StaticSyncEventSessionProvider: SyncEventLiveRecorderSessionProviding {
        let session: SupabaseAuthSessionInfo

        func currentSyncEventRecorderSession() async -> SyncEventLiveRecorderSession? {
            SyncEventLiveRecorderSession(userID: session.userID, isExpired: session.isExpired)
        }
    }

    private struct Fixture {
        let iosScope: Task072DRemoteScope
        let adminScope: Task072DRemoteScope
        let androidScope: Task072DRemoteScope
        let requiresExternalReceive: Bool

        var logPrefix: String { "TASK072D" }
    }

    private struct Runtime {
        let config: SupabaseConfig
        let provider: SupabaseClientProvider
        let inventory: SupabaseTransportClient
        let session: SupabaseAuthSessionInfo

        @MainActor
        var productPriceRemote: ProductPriceReleaseRemoteSupabaseAdapter {
            ProductPriceReleaseRemoteSupabaseAdapter(remote: inventory)
        }
    }

    private struct RemoteSnapshot {
        let suppliers: [RemoteInventorySupplierRow]
        let categories: [RemoteInventoryCategoryRow]
        let products: [RemoteInventoryProductRow]
        let prices: [RemoteInventoryProductPriceRow]
    }

    private struct ExternalReceiveResult {
        let source: String
        let wasAvailable: Bool
        let appliedProductCount: Int
        let appliedHistoryCount: Int

        var statusForLog: String {
            wasAvailable ? "\(source.lowercased()):applied_products_\(appliedProductCount)_history_\(appliedHistoryCount)" : "\(source.lowercased()):unavailable"
        }
    }

    private struct LocalStoreSnapshot {
        let pending: LocalPendingChangeSnapshot
        let outboxByStatus: [SyncEventOutboxStatus: Int]
        let runOutboxByStatus: [SyncEventOutboxStatus: Int]
        let runPendingLocalChanges: Int
        let prefixedActiveProducts: Int
        let prefixedTombstonedProducts: Int
        let prefixedActiveSuppliers: Int
        let prefixedTombstonedSuppliers: Int
        let prefixedActiveCategories: Int
        let prefixedTombstonedCategories: Int
        let prefixedActiveHistory: Int
        let prefixedTombstonedHistory: Int

        var outboxLocalOnly: Int {
            outboxByStatus[.localOnly, default: 0]
        }

        var runOpenOutboxCount: Int {
            runOutboxByStatus[.pending, default: 0]
                + runOutboxByStatus[.sending, default: 0]
                + runOutboxByStatus[.failedRetryable, default: 0]
        }

        var runOutboxSummary: String {
            Self.statusSummary(runOutboxByStatus)
        }

        var summaryLine: String {
            [
                "pendingCatalog=\(pending.pendingCatalogChangeCount)",
                "pendingPrices=\(pending.pendingProductPriceChangeCount)",
                "pendingHistory=\(pending.pendingHistorySessionChangeCount)",
                "runPendingLocalChanges=\(runPendingLocalChanges)",
                "outboxAll={\(Self.statusSummary(outboxByStatus))}",
                "outboxRun={\(runOutboxSummary)}",
                "productsActive=\(prefixedActiveProducts)",
                "productsTombstoned=\(prefixedTombstonedProducts)",
                "suppliersActive=\(prefixedActiveSuppliers)",
                "suppliersTombstoned=\(prefixedTombstonedSuppliers)",
                "categoriesActive=\(prefixedActiveCategories)",
                "categoriesTombstoned=\(prefixedTombstonedCategories)",
                "historyActive=\(prefixedActiveHistory)",
                "historyTombstoned=\(prefixedTombstonedHistory)"
            ].joined(separator: " ")
        }

        private static func statusSummary(_ counts: [SyncEventOutboxStatus: Int]) -> String {
            SyncEventOutboxStatus.allCases
                .map { "\($0.rawValue)=\(counts[$0, default: 0])" }
                .joined(separator: ",")
        }
    }

    private enum HarnessError: Error {
        case unexpectedCatalogPushStatus(String)
    }
}

private struct Task072DRemoteScope {
    let source: String
    let prefix: String

    var supplierInitialName: String { "\(prefix)SUPPLIER_INITIAL" }
    var supplierFinalName: String { "\(prefix)SUPPLIER_FINAL" }
    var categoryInitialName: String { "\(prefix)CATEGORY_INITIAL" }
    var categoryFinalName: String { "\(prefix)CATEGORY_FINAL" }

    var productCreateBarcode: String { "\(prefix)PRODUCT_CREATE" }
    var productUpdateBarcode: String { "\(prefix)PRODUCT_UPDATE" }
    var productTombstoneBarcode: String { "\(prefix)PRODUCT_TOMBSTONE" }
    var productCreateName: String { "\(prefix)PRODUCT_CREATE_NAME" }
    var productUpdateInitialName: String { "\(prefix)PRODUCT_UPDATE_INITIAL" }
    var productUpdateFinalName: String { "\(prefix)PRODUCT_UPDATE_FINAL" }
    var productTombstoneName: String { "\(prefix)PRODUCT_TOMBSTONE_NAME" }

    var historyCreateTitle: String { "\(prefix)HISTORY_CREATE" }
    var historyUpdateInitialTitle: String { "\(prefix)HISTORY_UPDATE_INITIAL" }
    var historyUpdateFinalTitle: String { "\(prefix)HISTORY_UPDATE_FINAL" }
    var historyTombstoneTitle: String { "\(prefix)HISTORY_TOMBSTONE" }

    var allSupplierNames: [String] {
        [supplierInitialName, supplierFinalName]
    }

    var allCategoryNames: [String] {
        [categoryInitialName, categoryFinalName]
    }

    var allBarcodes: [String] {
        [productCreateBarcode, productUpdateBarcode, productTombstoneBarcode]
    }
}
