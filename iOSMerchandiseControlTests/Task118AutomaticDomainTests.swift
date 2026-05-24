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
    func testStateStoreRecordsEveryAutomaticRunOutcome() {
        let suiteName = "Task118AutomaticDomainTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = SyncStateStore(defaults: defaults, keyPrefix: "task118")

        store.recordRunResult(.success(didWork: true))
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertEqual(store.state.lastOutcome, .succeeded)
        XCTAssertNotNil(store.state.lastVerifiedAt)

        store.recordRunResult(.noWork())
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertEqual(store.state.lastOutcome, .noWork)

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

    func testAutomaticRuntimeSourceDoesNotExposeManualPushBoundary() throws {
        let runtime = try readSource("iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift")
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
            "iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift",
            "iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift",
            "iOSMerchandiseControl/Sync/SyncOrchestrator.swift",
            "iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift",
            "iOSMerchandiseControl/AutomaticSyncReconnectScheduler.swift",
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

    func testAutomaticRuntimeErrorDiagnosticsUseSharedRedaction() throws {
        let runtime = try readSource("iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift")
        let engine = try readSource("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift")
        let automaticRuntimeSources = runtime + "\n" + engine

        XCTAssertTrue(automaticRuntimeSources.contains("SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage"))
        XCTAssertFalse(automaticRuntimeSources.contains(#"with: "<UUID>""#))
    }

    func testOptionsStatusCardReadsAutomaticRunOutcome() throws {
        let options = try readSource("iOSMerchandiseControl/OptionsView.swift")

        XCTAssertTrue(options.contains("syncState.lastOutcome"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.failed.detail"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.noWork.detail"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.badge.retry"))
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

    private func fetchOutboxEntry(
        context: ModelContext,
        ownerUserID: UUID,
        domain: String
    ) throws -> SyncEventOutboxEntry? {
        let owner = ownerUserID.uuidString.lowercased()
        var descriptor = FetchDescriptor<SyncEventOutboxEntry>(
            predicate: #Predicate<SyncEventOutboxEntry> { entry in
                entry.ownerUserID == owner && entry.domain == domain
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

private actor Task118CatalogRemote: SyncAutomaticCatalogRemoteWriting {
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
        RemoteInventorySupplierRow(
            id: id,
            ownerUserID: UUID(),
            name: payload.name,
            updatedAt: "2026-05-24T00:00:00Z",
            deletedAt: nil
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
        RemoteInventoryCategoryRow(
            id: id,
            ownerUserID: UUID(),
            name: payload.name,
            updatedAt: "2026-05-24T00:00:00Z",
            deletedAt: nil
        )
    }

    func createProducts(_ payloads: [SyncAutomaticProductCreatePayload]) async throws -> [RemoteInventoryProductRow] {
        payloads.map {
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
        RemoteInventoryProductRow(
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
    func insertProductPrices(_ payloads: [SyncAutomaticProductPricePayload]) async throws -> [RemoteInventoryProductPriceRow] {
        payloads.map {
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
