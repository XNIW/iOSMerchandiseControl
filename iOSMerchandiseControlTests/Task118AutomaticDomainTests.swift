import SwiftData
import XCTest
@testable import iOSMerchandiseControl

final class Task118AutomaticDomainTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testRunResultOutcomesAreExplicitAndDistinct() {
        let results: [SyncAutomaticRunResult] = [
            .success(didWork: true),
            .noWork(),
            .blocked(.authRequired),
            .busy(),
            .failed(errorCode: "unit"),
            .cancelled(),
            .scheduledRetry()
        ]

        XCTAssertEqual(Set(results.map(\.status)), Set(SyncAutomaticRunStatus.allCases))
        XCTAssertTrue(results[0].didWork)
        XCTAssertFalse(results[1].didWork)
        XCTAssertEqual(results[2].blockReason, .authRequired)
    }

    func testDecisionEngineBlocksInsteadOfNoOpWhenStateReadFails() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .appForeground,
                isAuthenticated: true,
                isNetworkAvailable: true,
                hasStateReadFailure: true
            )
        )

        XCTAssertEqual(action, .blocked(.localStateUnavailable))
    }

    @MainActor
    func testRootPresentationDoesNotShowCheckingForIdleDecisionOnlyPass() {
        let state = SyncOrchestrator.makeRootPresentationState(
            isTransitioning: false,
            isSignedIn: true,
            isAutomaticRuntimeRunning: false,
            phase: .idle
        )

        XCTAssertEqual(state.kind, .hidden)
    }

    @MainActor
    func testRootPresentationStillShowsCheckingForRealAutomaticWork() {
        let state = SyncOrchestrator.makeRootPresentationState(
            isTransitioning: false,
            isSignedIn: true,
            isAutomaticRuntimeRunning: false,
            phase: .pullingEvents
        )

        XCTAssertEqual(state.kind, .checking)
    }

    @MainActor
    func testStateStoreRecordsEveryAutomaticRunOutcome() {
        let suiteName = "Task118AutomaticDomainTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SyncStateStore(defaults: defaults, keyPrefix: "task118")

        store.recordRunResult(.success(didWork: true))
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertEqual(store.state.lastOutcome, .succeeded)
        XCTAssertNotNil(store.state.lastVerifiedAt)
        let verifiedAfterSuccess = store.state.lastVerifiedAt

        store.recordRunResult(.noWork())
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertEqual(store.state.lastOutcome, .noWork)
        XCTAssertEqual(store.state.lastVerifiedAt, verifiedAfterSuccess)

        store.recordRunResult(.blocked(.networkUnavailable))
        XCTAssertEqual(store.state.phase, .blocked(.networkUnavailable))
        XCTAssertEqual(store.state.lastOutcome, .blocked(.networkUnavailable))

        store.recordRunResult(.busy())
        XCTAssertEqual(store.state.phase, .checking)
        XCTAssertEqual(store.state.lastOutcome, .busy)

        store.recordRunResult(.failed(errorCode: "unit"))
        XCTAssertEqual(store.state.phase, .failed)
        XCTAssertEqual(store.state.lastOutcome, .failed)

        store.recordRunResult(.cancelled())
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertEqual(store.state.lastOutcome, .cancelled)

        store.recordRunResult(.scheduledRetry())
        XCTAssertEqual(store.state.phase, .checking)
        XCTAssertEqual(store.state.lastOutcome, .scheduledRetry)
    }

    @MainActor
    func testStateStoreDoesNotPromoteDecisionNoWorkToVerifiedSuccess() {
        let suiteName = "Task136NoWork-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SyncStateStore(defaults: defaults, keyPrefix: "task136")

        store.recordRunResult(.failed(errorCode: "networkError(redacted)"))
        XCTAssertEqual(defaults.string(forKey: "task136.lastRunErrorCode"), "networkError(redacted)")

        store.recordRunResult(.noWork())
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertEqual(store.state.lastOutcome, .noWork)
        XCTAssertNil(store.state.lastVerifiedAt)
        XCTAssertNil(defaults.string(forKey: "task136.lastRunErrorCode"))
        XCTAssertNil(defaults.string(forKey: "task136.lastRunBlockReason"))
    }

    @MainActor
    func testStateStoreHydratesPersistedNetworkFailureWithoutRestoringActivePhase() {
        let suiteName = "Task136Hydrate-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("pullingEvents", forKey: "task136.phase")
        defaults.set("noWork", forKey: "task136.lastRunStatus")
        defaults.set("networkUnavailable", forKey: "task136.lastRunBlockReason")
        defaults.set("networkError(redacted)", forKey: "task136.lastRunErrorCode")
        defaults.set(Date(timeIntervalSince1970: 100).timeIntervalSince1970, forKey: "task136.activeStartedAt")
        defaults.set(Date(timeIntervalSince1970: 120).timeIntervalSince1970, forKey: "task136.lastProgressAt")

        let store = SyncStateStore(defaults: defaults, keyPrefix: "task136")

        XCTAssertEqual(store.state.phase, .blocked(.networkUnavailable))
        XCTAssertEqual(store.state.lastOutcome, .blocked(.networkUnavailable))
        XCTAssertNil(store.state.startedAt)
    }

    func testAutomaticRuntimeSourceDoesNotExposeManualPushBoundary() throws {
        let runtime = try readSource("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRuntimeFacade.swift")
        let contentView = try readSource("iOSMerchandiseControl/ContentView.swift")
        let app = try readSource("iOSMerchandiseControl/iOSMerchandiseControlApp.swift")

        XCTAssertFalse(runtime.contains("SupabaseManualPushService"))
        XCTAssertFalse(runtime.contains("manualPushService"))
        XCTAssertFalse(runtime.contains("SyncCatalogPushAdapter"))
        XCTAssertFalse(runtime.contains("async -> Bool"))
        XCTAssertTrue(runtime.contains("SyncAutomaticRunResult"))

        XCTAssertFalse(contentView.contains("SupabaseManualPushService"))
        XCTAssertFalse(contentView.contains("manualPushService"))
        XCTAssertFalse(app.contains("SupabaseManualPushService"))
        XCTAssertFalse(app.contains("manualPushService"))
    }

    func testAutomaticSourceFilesDoNotReferenceManualDTOs() throws {
        let sources = try [
            "iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRuntimeFacade.swift",
            "iOSMerchandiseControl/Sync/Automatic/Composition/AutomaticSyncRuntimeFactory.swift",
            "iOSMerchandiseControl/Sync/SyncOrchestrator.swift",
            "iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxEnqueueService.swift",
            "iOSMerchandiseControl/Sync/Automatic/Presentation/AutomaticSyncReconnectScheduler.swift",
            "iOSMerchandiseControl/OptionsView.swift"
        ].map(readSource).joined(separator: "\n")

        for forbidden in [
            "ManualPushPlan",
            "SupabaseManualPushResult",
            "ProductPriceManualPushResult",
            "ProductPriceManualPushSnapshot",
            "ProductPriceManualPushSnapshotFactory",
            "SupabaseManualSync"
        ] {
            XCTAssertFalse(sources.contains(forbidden), "Forbidden automatic-domain symbol found: \(forbidden)")
        }
    }

    func testOptionsAndProvidersUseObserverOnlyContracts() throws {
        let options = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let provider = try readSource("iOSMerchandiseControl/Sync/Automatic/Presentation/OptionsSyncSummaryProvider.swift")
        let contracts = try [
            "iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift",
            "iOSMerchandiseControl/Sync/Automatic/Catalog/SyncCatalogPushModels.swift",
            "iOSMerchandiseControl/Sync/Automatic/ProductPrice/SyncProductPricePushModels.swift",
            "iOSMerchandiseControl/Sync/Automatic/History/SyncHistorySessionPushModels.swift",
            "iOSMerchandiseControl/Sync/Automatic/Outbox/SyncActivityRegistrationModels.swift"
        ].map(readSource).joined(separator: "\n")

        XCTAssertFalse(options.contains("CloudSyncProgressState.idle()"))
        XCTAssertTrue(options.contains("OptionsSyncSummaryProvider"))
        XCTAssertTrue(options.contains("SyncStatusPresenter"))
        XCTAssertFalse(provider.contains("SyncAutomaticRuntime"))
        XCTAssertFalse(contracts.contains("@MainActor\nprotocol SyncCatalogPushProviding"))
        XCTAssertFalse(contracts.contains("@MainActor\nprotocol SyncProductPriceSyncProviding"))
        XCTAssertFalse(contracts.contains("@MainActor\nprotocol SyncHistorySessionPushProviding"))
        XCTAssertFalse(contracts.contains("@MainActor\nprotocol SyncActivityRegistrationProviding"))
    }

    @MainActor
    func testCatalogPushServiceWritesAndAcknowledgesRequestedOwnerChanges() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let otherOwner = UUID()
        let context = ModelContext(container)
        let supplier = Supplier(name: "TASK118 Supplier")
        let category = ProductCategory(name: "TASK118 Category")
        let product = Product(
            barcode: "TASK118-BAR",
            productName: "TASK118 Product",
            supplier: supplier,
            category: category
        )
        context.insert(supplier)
        context.insert(category)
        context.insert(product)
        context.insert(
            LocalPendingChange(
                ownerUserID: owner,
                entityKind: .product,
                operation: .update,
                origin: .manualCatalogSave,
                logicalKey: LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: product.barcode),
                changedFields: ["productName"]
            )
        )
        context.insert(
            LocalPendingChange(
                ownerUserID: otherOwner,
                entityKind: .supplier,
                operation: .update,
                origin: .manualCatalogSave,
                logicalKey: "supplier:other",
                changedFields: ["name"]
            )
        )
        try context.save()

        let remote = Task118CatalogRemote()
        let result = try await CatalogPushService(modelContainer: container, remote: remote)
            .pushPendingCatalog(ownerUserID: owner)

        XCTAssertEqual(result.plan?.ownerUserID, owner)
        XCTAssertEqual(result.plan?.pendingChangeCount, 1)
        XCTAssertEqual(result.productCreates, 1)
        XCTAssertEqual(result.totalChanged, 1)
        let verifyContext = ModelContext(container)
        XCTAssertNotNil(try fetchProduct(barcode: "TASK118-BAR", context: verifyContext)?.remoteID)
        XCTAssertEqual(try activeChangeCount(context: verifyContext, ownerUserID: owner), 0)
        XCTAssertEqual(try activeChangeCount(context: verifyContext, ownerUserID: otherOwner), 1)
        let event = try fetchOutboxEntry(context: verifyContext, ownerUserID: owner, domain: "catalog")
        XCTAssertEqual(event?.eventType, "catalog_changed")
        XCTAssertEqual(event?.changedCount, 1)
        XCTAssertEqual(event?.status, .pending)
    }

    @MainActor
    func testCatalogPushServiceTombstonesHardDeletedProductFromPendingRemoteID() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let remoteID = UUID()
        let context = ModelContext(container)
        let product = Product(
            barcode: "TASK135_DELETE_REMOTE",
            remoteID: remoteID,
            productName: "TASK135 Delete Remote"
        )
        let price = ProductPrice(
            remoteID: UUID(),
            type: .retail,
            price: 12.34,
            product: product
        )
        context.insert(product)
        context.insert(price)

        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: owner)
        try accumulator.recordProductChange(
            product: product,
            operation: .delete,
            origin: .manualCatalogSave,
            changedFields: ["tombstone"],
            baselineFingerprintHash: LocalPendingChangeLogicalKey.productFingerprintHash(product)
        )
        context.delete(product)
        try context.save()

        let remote = Task118CatalogRemote()
        let result = try await CatalogPushService(modelContainer: container, remote: remote)
            .pushPendingCatalog(ownerUserID: owner)

        XCTAssertEqual(result.productUpdates, 1)
        XCTAssertEqual(result.productCreates, 0)
        XCTAssertEqual(result.totalChanged, 1)
        let updatedProductIDs = await remote.updatedProductIDs()
        let createdProductPayloadCount = await remote.createdProductPayloadCount()
        XCTAssertEqual(updatedProductIDs, [remoteID])
        XCTAssertEqual(createdProductPayloadCount, 0)
        let payloads = await remote.productUpdatePayloads()
        XCTAssertEqual(payloads.count, 1)
        XCTAssertNotNil(payloads.first?.deletedAt)

        let verifyContext = ModelContext(container)
        XCTAssertNil(try fetchProduct(barcode: "TASK135_DELETE_REMOTE", context: verifyContext))
        XCTAssertEqual(try activeChangeCount(context: verifyContext, ownerUserID: owner), 0)
        let snapshot = try LocalPendingChangeSnapshotProvider(context: verifyContext)
            .loadSnapshot(ownerUserID: owner)
        XCTAssertEqual(snapshot.pendingProductPriceChangeCount, 0)
        let event = try fetchOutboxEntry(context: verifyContext, ownerUserID: owner, domain: "catalog")
        XCTAssertEqual(event?.eventType, "catalog_tombstone")
        XCTAssertEqual(event?.changedCount, 1)

        let repeatResult = try await CatalogPushService(modelContainer: container, remote: remote)
            .pushPendingCatalog(ownerUserID: owner)
        XCTAssertEqual(repeatResult.totalChanged, 0)
        let repeatedUpdatedProductIDs = await remote.updatedProductIDs()
        XCTAssertEqual(repeatedUpdatedProductIDs, [remoteID])
        XCTAssertNil(try fetchProduct(barcode: "TASK135_DELETE_REMOTE", context: ModelContext(container)))
    }

    @MainActor
    func testCatalogPushServiceAcknowledgesLocalOnlyProductDeleteWithoutRemoteCall() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let context = ModelContext(container)
        context.insert(
            LocalPendingChange(
                ownerUserID: owner,
                entityKind: .product,
                operation: .delete,
                origin: .manualCatalogSave,
                logicalKey: LocalPendingChangeLogicalKey.product(
                    remoteID: nil,
                    barcode: "TASK135_DELETE_LOCAL_ONLY"
                ),
                changedFields: ["tombstone"],
                entityRemoteID: nil
            )
        )
        try context.save()

        let remote = Task118CatalogRemote()
        let result = try await CatalogPushService(modelContainer: container, remote: remote)
            .pushPendingCatalog(ownerUserID: owner)

        XCTAssertEqual(result.totalChanged, 0)
        let updatedProductIDs = await remote.updatedProductIDs()
        let createdProductPayloadCount = await remote.createdProductPayloadCount()
        XCTAssertTrue(updatedProductIDs.isEmpty)
        XCTAssertEqual(createdProductPayloadCount, 0)
        let verifyContext = ModelContext(container)
        XCTAssertEqual(try activeChangeCount(context: verifyContext, ownerUserID: owner), 0)
        XCTAssertNil(try fetchOutboxEntry(context: verifyContext, ownerUserID: owner, domain: "catalog"))
    }

    @MainActor
    func testCatalogPushServiceTombstonesHardDeletedSupplierAndCategoryFromPendingRemoteIDs() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let supplierRemoteID = UUID()
        let categoryRemoteID = UUID()
        let context = ModelContext(container)
        let supplier = Supplier(name: "TASK069 Supplier Delete", remoteID: supplierRemoteID)
        let category = ProductCategory(name: "TASK069 Category Delete", remoteID: categoryRemoteID)
        context.insert(supplier)
        context.insert(category)
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: owner)
        try accumulator.recordSupplierChange(
            supplier: supplier,
            operation: .delete,
            origin: .manualCatalogSave,
            changedFields: ["tombstone"],
            baselineFingerprintHash: LocalPendingChangeLogicalKey.supplierFingerprintHash(supplier)
        )
        try accumulator.recordCategoryChange(
            category: category,
            operation: .delete,
            origin: .manualCatalogSave,
            changedFields: ["tombstone"],
            baselineFingerprintHash: LocalPendingChangeLogicalKey.categoryFingerprintHash(category)
        )
        context.delete(supplier)
        context.delete(category)
        try context.save()

        let remote = Task118CatalogRemote()
        let result = try await CatalogPushService(modelContainer: container, remote: remote)
            .pushPendingCatalog(ownerUserID: owner)

        XCTAssertEqual(result.supplierUpdates, 1)
        XCTAssertEqual(result.categoryUpdates, 1)
        XCTAssertEqual(result.totalChanged, 2)
        let updatedSupplierIDs = await remote.updatedSupplierIDs()
        let updatedCategoryIDs = await remote.updatedCategoryIDs()
        let supplierPayloads = await remote.supplierUpdatePayloads()
        let categoryPayloads = await remote.categoryUpdatePayloads()
        XCTAssertEqual(updatedSupplierIDs, [supplierRemoteID])
        XCTAssertEqual(updatedCategoryIDs, [categoryRemoteID])
        XCTAssertNotNil(supplierPayloads.first?.deletedAt)
        XCTAssertNotNil(categoryPayloads.first?.deletedAt)

        let verifyContext = ModelContext(container)
        XCTAssertNil(try fetchSupplier(remoteID: supplierRemoteID, context: verifyContext))
        XCTAssertNil(try fetchCategory(remoteID: categoryRemoteID, context: verifyContext))
        XCTAssertEqual(try activeChangeCount(context: verifyContext, ownerUserID: owner), 0)
        let event = try fetchOutboxEntry(context: verifyContext, ownerUserID: owner, domain: "catalog")
        XCTAssertEqual(event?.eventType, "catalog_tombstone")
        XCTAssertEqual(event?.changedCount, 2)
    }

    @MainActor
    func testCatalogPushServiceUsesDistinctSyncEventIDsForLaterSingleChange() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let remoteID = UUID()
        let context = ModelContext(container)
        let product = Product(
            barcode: "TASK135_EVENT_ID_REUSE",
            remoteID: remoteID,
            productName: "TASK135 Event ID Reuse"
        )
        context.insert(product)
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: owner)
        product.productName = "TASK135 Event ID Reuse Updated"
        try accumulator.recordProductChange(
            product: product,
            operation: .update,
            origin: .manualCatalogSave,
            changedFields: ["productName"],
            baselineFingerprintHash: nil
        )
        try context.save()

        let remote = Task118CatalogRemote()
        let first = try await CatalogPushService(modelContainer: container, remote: remote)
            .pushPendingCatalog(ownerUserID: owner)
        XCTAssertEqual(first.totalChanged, 1)

        let deleteContext = ModelContext(container)
        let productToDelete = try XCTUnwrap(fetchProduct(barcode: "TASK135_EVENT_ID_REUSE", context: deleteContext))
        let deleteAccumulator = LocalPendingChangeAccumulator(context: deleteContext, ownerUserID: owner)
        try deleteAccumulator.recordProductChange(
            product: productToDelete,
            operation: .delete,
            origin: .manualCatalogSave,
            changedFields: ["tombstone"],
            baselineFingerprintHash: LocalPendingChangeLogicalKey.productFingerprintHash(productToDelete)
        )
        try deleteAccumulator.supersedeProductPriceChanges(for: productToDelete)
        deleteContext.delete(productToDelete)
        try deleteContext.save()

        let second = try await CatalogPushService(modelContainer: container, remote: remote)
            .pushPendingCatalog(ownerUserID: owner)
        XCTAssertEqual(second.totalChanged, 1)

        let verifyContext = ModelContext(container)
        let entries = try fetchOutboxEntries(context: verifyContext, ownerUserID: owner, domain: "catalog")
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(Set(entries.map(\.clientEventID)).count, 2)
        XCTAssertTrue(entries.contains { $0.eventType == "catalog_changed" })
        XCTAssertTrue(entries.contains { $0.eventType == "catalog_tombstone" })
    }

    @MainActor
    func testProductPricePushServiceWritesLinksAndAcknowledgesPendingPrice() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let productID = UUID()
        let context = ModelContext(container)
        let product = Product(
            barcode: "TASK118-PRICE-BAR",
            remoteID: productID,
            productName: "TASK118 Price Product"
        )
        let price = ProductPrice(
            type: .retail,
            price: 12.34,
            effectiveAt: Date(timeIntervalSince1970: 1_700_000_000),
            product: product
        )
        context.insert(product)
        context.insert(price)
        context.insert(
            LocalPendingChange(
                ownerUserID: owner,
                entityKind: .productPrice,
                operation: .upsert,
                status: .pending,
                origin: .productPriceSave,
                logicalKey: LocalPendingChangeLogicalKey.productPrice(
                    productRemoteID: product.remoteID,
                    productBarcode: product.barcode,
                    type: price.type,
                    effectiveAt: price.effectiveAt
                ),
                changedFields: ["price"]
            )
        )
        try context.save()

        let remote = Task118ProductPriceRemote()
        let result = try await ProductPricePushService(modelContainer: container, remote: remote)
            .pushPendingProductPrices(ownerUserID: owner)

        XCTAssertEqual(result.plan?.ownerUserID, owner)
        XCTAssertEqual(result.plan?.pendingChangeCount, 1)
        XCTAssertEqual(result.insertedCount, 1)
        XCTAssertEqual(result.orphanedCount, 0)
        XCTAssertEqual(result.tombstonedCount, 0)
        let verifyContext = ModelContext(container)
        XCTAssertNotNil(try fetchProductPrice(productBarcode: "TASK118-PRICE-BAR", context: verifyContext)?.remoteID)
        XCTAssertEqual(try activeChangeCount(context: verifyContext, ownerUserID: owner), 0)
        let event = try fetchOutboxEntry(context: verifyContext, ownerUserID: owner, domain: "prices")
        XCTAssertEqual(event?.eventType, "prices_changed")
        XCTAssertEqual(event?.changedCount, 1)
        XCTAssertEqual(event?.status, .pending)
    }

    @MainActor
    func testProductPricePushServiceSupersedesPendingPriceAfterProductCascadeDelete() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let context = ModelContext(container)
        let product = Product(
            barcode: "TASK135_PRICE_CASCADE_DELETE",
            remoteID: UUID(),
            productName: "TASK135 Price Cascade Delete"
        )
        let price = ProductPrice(
            type: .retail,
            price: 9.99,
            effectiveAt: Date(timeIntervalSince1970: 1_700_000_100),
            product: product
        )
        context.insert(product)
        context.insert(price)
        let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: owner)
        try accumulator.recordProductPriceChange(price: price, origin: .productPriceSave)
        context.delete(product)
        try context.save()

        let remote = Task118ProductPriceRemote()
        let result = try await ProductPricePushService(modelContainer: container, remote: remote)
            .pushPendingProductPrices(ownerUserID: owner)

        XCTAssertEqual(result.insertedCount, 0)
        XCTAssertEqual(result.orphanedCount, 0)
        let insertCallCount = await remote.insertCallCount()
        XCTAssertEqual(insertCallCount, 0)
        let verifyContext = ModelContext(container)
        XCTAssertEqual(try activeChangeCount(context: verifyContext, ownerUserID: owner), 0)
        let snapshot = try LocalPendingChangeSnapshotProvider(context: verifyContext)
            .loadSnapshot(ownerUserID: owner)
        XCTAssertEqual(snapshot.pendingProductPriceChangeCount, 0)
    }

    func testAutomaticRuntimeErrorDiagnosticsUseSharedRedaction() throws {
        let runtime = try readSource("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRuntimeFacade.swift")
        let engine = try readSource("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift")
        let automaticRuntimeSources = runtime + "\n" + engine

        XCTAssertTrue(automaticRuntimeSources.contains("SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage"))
        XCTAssertFalse(automaticRuntimeSources.contains(#"with: "<UUID>""#))
    }

    func testBackgroundRunnerUsesDecisionEngineBeforeAutomaticRun() throws {
        let background = try readSource("iOSMerchandiseControl/Sync/Automatic/Background/SyncBackgroundTaskScheduler.swift")

        XCTAssertTrue(background.contains("SyncDecisionInputProvider"))
        XCTAssertTrue(background.contains("SyncDecisionEngine.decide"))
        XCTAssertTrue(background.contains("recoverySnapshotPullProvider: AutomaticRecoverySnapshotPullService"))
        XCTAssertFalse(background.contains(".sequence([.pushPending, .drainEvents])"))
    }

    func testOptionsStatusCardReadsAutomaticRunOutcome() throws {
        let options = try readSource("iOSMerchandiseControl/OptionsView.swift")

        XCTAssertTrue(options.contains("syncState.lastOutcome"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.failed.detail"))
        XCTAssertTrue(options.contains("case .noWork where baselineSummary.status == .valid"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.noWork.detail"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.badge.retry"))
    }

    func testOptionsDiagnosticsStayCollapsedAndLabelCloudEventWarnings() throws {
        let options = try readSource("iOSMerchandiseControl/OptionsView.swift")

        XCTAssertTrue(options.contains("if isDiagnosticsExpanded {"))
        XCTAssertFalse(options.contains("if isDiagnosticsExpanded || isStalled {"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.cloudEventCheck.pending"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.badge.cloudEventsIncomplete"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.diagnostics.previousLastError"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.diagnostics.previousErrorNonBlocking"))
        XCTAssertTrue(options.contains("isTechnicalCloudEventNote"))
    }

    private func readSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

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

    private func activeChangeCount(context: ModelContext, ownerUserID: UUID) throws -> Int {
        let owner = ownerUserID.uuidString.lowercased()
        let descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.ownerUserID == owner
            }
        )
        return try context.fetch(descriptor).filter { !$0.status.isTerminal }.count
    }

    private func fetchProduct(barcode: String, context: ModelContext) throws -> Product? {
        var descriptor = FetchDescriptor<Product>(
            predicate: #Predicate<Product> { product in
                product.barcode == barcode
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchProductPrice(productBarcode: String, context: ModelContext) throws -> ProductPrice? {
        try context.fetch(FetchDescriptor<ProductPrice>()).first {
            $0.product?.barcode == productBarcode
        }
    }

    private func fetchSupplier(remoteID: UUID, context: ModelContext) throws -> Supplier? {
        try context.fetch(FetchDescriptor<Supplier>()).first {
            $0.remoteID == remoteID
        }
    }

    private func fetchCategory(remoteID: UUID, context: ModelContext) throws -> ProductCategory? {
        try context.fetch(FetchDescriptor<ProductCategory>()).first {
            $0.remoteID == remoteID
        }
    }

    private func fetchOutboxEntry(
        context: ModelContext,
        ownerUserID: UUID,
        domain: String
    ) throws -> SyncEventOutboxEntry? {
        try fetchOutboxEntries(context: context, ownerUserID: ownerUserID, domain: domain).first
    }

    private func fetchOutboxEntries(
        context: ModelContext,
        ownerUserID: UUID,
        domain: String
    ) throws -> [SyncEventOutboxEntry] {
        let owner = ownerUserID.uuidString.lowercased()
        let descriptor = FetchDescriptor<SyncEventOutboxEntry>(
            predicate: #Predicate<SyncEventOutboxEntry> { entry in
                entry.ownerUserID == owner && entry.domain == domain
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }
}

private actor Task118CatalogRemote: SyncAutomaticCatalogRemoteWriting {
    private var createdProductPayloads: [SyncAutomaticProductCreatePayload] = []
    private var supplierUpdateRequests: [(UUID, SyncAutomaticSupplierUpdatePayload)] = []
    private var categoryUpdateRequests: [(UUID, SyncAutomaticCategoryUpdatePayload)] = []
    private var productUpdateRequests: [(UUID, SyncAutomaticProductUpdatePayload)] = []

    func createdProductPayloadCount() -> Int {
        createdProductPayloads.count
    }

    func updatedProductIDs() -> [UUID] {
        productUpdateRequests.map(\.0)
    }

    func productUpdatePayloads() -> [SyncAutomaticProductUpdatePayload] {
        productUpdateRequests.map(\.1)
    }

    func updatedSupplierIDs() -> [UUID] {
        supplierUpdateRequests.map(\.0)
    }

    func supplierUpdatePayloads() -> [SyncAutomaticSupplierUpdatePayload] {
        supplierUpdateRequests.map(\.1)
    }

    func updatedCategoryIDs() -> [UUID] {
        categoryUpdateRequests.map(\.0)
    }

    func categoryUpdatePayloads() -> [SyncAutomaticCategoryUpdatePayload] {
        categoryUpdateRequests.map(\.1)
    }

    func createSuppliers(_ payloads: [SyncAutomaticSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow] {
        payloads.map {
            RemoteInventorySupplierRow(
                id: UUID(),
                ownerUserID: $0.ownerUserID,
                name: $0.name,
                updatedAt: "2026-05-24T00:00:00Z",
                deletedAt: nil
            )
        }
    }

    func updateSupplier(id: UUID, payload: SyncAutomaticSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow {
        supplierUpdateRequests.append((id, payload))
        return RemoteInventorySupplierRow(
            id: id,
            ownerUserID: UUID(),
            name: payload.name ?? "Deleted Supplier",
            updatedAt: "2026-05-24T00:00:00Z",
            deletedAt: payload.deletedAt
        )
    }

    func createCategories(_ payloads: [SyncAutomaticCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow] {
        payloads.map {
            RemoteInventoryCategoryRow(
                id: UUID(),
                ownerUserID: $0.ownerUserID,
                name: $0.name,
                updatedAt: "2026-05-24T00:00:00Z",
                deletedAt: nil
            )
        }
    }

    func updateCategory(id: UUID, payload: SyncAutomaticCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow {
        categoryUpdateRequests.append((id, payload))
        return RemoteInventoryCategoryRow(
            id: id,
            ownerUserID: UUID(),
            name: payload.name ?? "Deleted Category",
            updatedAt: "2026-05-24T00:00:00Z",
            deletedAt: payload.deletedAt
        )
    }

    func createProducts(_ payloads: [SyncAutomaticProductCreatePayload]) async throws -> [RemoteInventoryProductRow] {
        createdProductPayloads.append(contentsOf: payloads)
        return payloads.map {
            RemoteInventoryProductRow(
                id: UUID(),
                ownerUserID: $0.ownerUserID,
                barcode: $0.barcode,
                itemNumber: $0.itemNumber,
                productName: $0.productName,
                secondProductName: $0.secondProductName,
                purchasePrice: $0.purchasePrice,
                retailPrice: $0.retailPrice,
                supplierID: $0.supplierID,
                categoryID: $0.categoryID,
                stockQuantity: $0.stockQuantity,
                updatedAt: "2026-05-24T00:00:00Z",
                deletedAt: nil
            )
        }
    }

    func updateProduct(id: UUID, payload: SyncAutomaticProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        productUpdateRequests.append((id, payload))
        return RemoteInventoryProductRow(
            id: id,
            ownerUserID: UUID(),
            barcode: payload.barcode ?? "TASK118-BAR",
            itemNumber: payload.itemNumber,
            productName: payload.productName,
            secondProductName: payload.secondProductName,
            purchasePrice: payload.purchasePrice,
            retailPrice: payload.retailPrice,
            supplierID: payload.supplierID,
            categoryID: payload.categoryID,
            stockQuantity: payload.stockQuantity,
            updatedAt: "2026-05-24T00:00:00Z",
            deletedAt: payload.deletedAt
        )
    }
}

private actor Task118ProductPriceRemote: SyncAutomaticProductPriceRemoteWriting {
    private var insertCalls = 0

    func insertCallCount() -> Int {
        insertCalls
    }

    func insertProductPrices(_ payloads: [SyncAutomaticProductPricePayload]) async throws -> [RemoteInventoryProductPriceRow] {
        insertCalls += 1
        return payloads.map {
            RemoteInventoryProductPriceRow(
                id: $0.id,
                ownerUserID: $0.ownerUserID,
                productID: $0.productID,
                type: $0.type,
                price: $0.price,
                effectiveAt: $0.effectiveAt,
                source: $0.source,
                note: $0.note,
                createdAt: $0.createdAt
            )
        }
    }
}
