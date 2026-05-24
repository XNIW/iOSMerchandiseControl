import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class SupabaseManualSyncRemotePreviewTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private let ownerID = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!

    func testCompletePreviewWithoutRemoteSignalsMapsToNoActionSummary() {
        let summary = SupabaseManualSyncRemotePreviewOutcomeMapper.summary(
            from: .success(makePreview())
        )

        XCTAssertTrue(summary.isComplete)
        XCTAssertFalse(summary.isPartial)
        XCTAssertFalse(summary.hasRemoteSignals)
        XCTAssertFalse(summary.wasCancelled)
        XCTAssertEqual(summary.safeAggregateCounts.reviewSignalCount, 0)
        XCTAssertEqual(summary.recommendedUserMessageKey, .cloudCheckCompleteNoAction)
        XCTAssertEqual(SupabaseManualSyncRemotePreviewOutcomeMapper.phaseOutcome(for: summary), .completed)
    }

    func testCompletePreviewWithRemoteSignalsMapsToNeedsReviewSummary() {
        let summary = SupabaseManualSyncRemotePreviewOutcomeMapper.summary(
            from: .success(makePreview(
                newProducts: [
                    SyncPreviewProductSummary(
                        classification: .newProduct,
                        remoteID: UUID(),
                        barcode: "12345",
                        productName: "Remote item"
                    )
                ],
                updateCandidates: [
                    SyncPreviewProductSummary(
                        classification: .updateCandidate,
                        remoteID: UUID(),
                        barcode: "67890",
                        productName: "Changed item"
                    )
                ],
                conflicts: [
                    SyncPreviewConflict(
                        kind: .remoteDuplicateBarcode,
                        barcodeOrKey: "12345"
                    )
                ]
            ))
        )

        XCTAssertTrue(summary.isComplete)
        XCTAssertTrue(summary.hasRemoteSignals)
        XCTAssertEqual(summary.safeAggregateCounts.newProductCount, 1)
        XCTAssertEqual(summary.safeAggregateCounts.updateCandidateCount, 1)
        XCTAssertEqual(summary.safeAggregateCounts.conflictCount, 1)
        XCTAssertEqual(summary.recommendedUserMessageKey, .cloudDataNeedsReview)
        XCTAssertEqual(SupabaseManualSyncRemotePreviewOutcomeMapper.phaseOutcome(for: summary), .completed)
    }

    func testPartialPreviewMapsToIncompleteAndNeverSuccessOutcome() {
        let warning = SyncPreviewWarning(
            code: .sourceError,
            detail: "inventory_products",
            relatedKey: "inventory_products"
        )
        let summary = SupabaseManualSyncRemotePreviewOutcomeMapper.summary(
            from: .partial(
                makePreview(outcome: .partial, sourceErrors: [warning]),
                warnings: [warning],
                sourceErrors: [warning]
            )
        )

        XCTAssertFalse(summary.isComplete)
        XCTAssertTrue(summary.isPartial)
        XCTAssertEqual(summary.recommendedUserMessageKey, .cloudCheckIncomplete)
        XCTAssertEqual(SupabaseManualSyncRemotePreviewOutcomeMapper.phaseOutcome(for: summary), .partial)
        XCTAssertNotEqual(SupabaseManualSyncRemotePreviewOutcomeMapper.finalUserState(for: summary), .completedSuccessfully)
        XCTAssertNotEqual(SupabaseManualSyncRemotePreviewOutcomeMapper.finalUserState(for: summary), .allUpToDate)
    }

    func testNetworkFailureMapsToRetryableUserSafeFailure() {
        let summary = SupabaseManualSyncRemotePreviewOutcomeMapper.summary(
            from: .failed(.service(.networkError(statusCode: 503, message: "temporary outage")))
        )

        XCTAssertEqual(summary.failureCategory, .network)
        XCTAssertEqual(summary.recommendedUserMessageKey, .cloudCheckFailedRetry)
        XCTAssertEqual(SupabaseManualSyncRemotePreviewOutcomeMapper.phaseOutcome(for: summary), .failedRetryable)
        XCTAssertEqual(SupabaseManualSyncRemotePreviewOutcomeMapper.finalUserState(for: summary), .connectivityIssue)
    }

    func testPermissionAndSchemaFailuresMapToNonTechnicalKeysWithoutSuccess() {
        let permission = SupabaseManualSyncRemotePreviewOutcomeMapper.summary(
            from: .failed(.service(.permissionDeniedOrRLS(statusCode: 403, code: "42501", message: "permission denied")))
        )
        let auth = SupabaseManualSyncRemotePreviewOutcomeMapper.summary(
            from: .failed(.service(.sessionMissing))
        )
        let schema = SupabaseManualSyncRemotePreviewOutcomeMapper.summary(
            from: .failed(.service(.schemaDrift(message: "missing column")))
        )

        XCTAssertEqual(permission.failureCategory, .permission)
        XCTAssertEqual(permission.recommendedUserMessageKey, .cloudCheckFailedPermission)
        XCTAssertEqual(SupabaseManualSyncRemotePreviewOutcomeMapper.phaseOutcome(for: permission), .blocked)
        XCTAssertNotEqual(SupabaseManualSyncRemotePreviewOutcomeMapper.finalUserState(for: permission), .completedSuccessfully)

        XCTAssertEqual(auth.failureCategory, .auth)
        XCTAssertEqual(auth.recommendedUserMessageKey, .cloudCheckFailedPermission)
        XCTAssertEqual(SupabaseManualSyncRemotePreviewOutcomeMapper.phaseOutcome(for: auth), .blocked)
        XCTAssertEqual(SupabaseManualSyncRemotePreviewOutcomeMapper.finalUserState(for: auth), .blocked)

        XCTAssertEqual(schema.failureCategory, .schemaOrDecode)
        XCTAssertEqual(schema.recommendedUserMessageKey, .cloudCheckFailedTechnical)
        XCTAssertEqual(SupabaseManualSyncRemotePreviewOutcomeMapper.phaseOutcome(for: schema), .failedNonRetryable)
        XCTAssertNotEqual(SupabaseManualSyncRemotePreviewOutcomeMapper.finalUserState(for: schema), .allUpToDate)
    }

    func testCancelledSummaryNeverMapsToSuccess() {
        let summary = SupabaseManualSyncRemotePreviewOutcomeMapper.cancelledSummary()

        XCTAssertTrue(summary.wasCancelled)
        XCTAssertFalse(summary.isComplete)
        XCTAssertEqual(summary.recommendedUserMessageKey, .cloudCheckCancelled)
        XCTAssertEqual(SupabaseManualSyncRemotePreviewOutcomeMapper.phaseOutcome(for: summary), .cancelled)
        XCTAssertEqual(SupabaseManualSyncRemotePreviewOutcomeMapper.finalUserState(for: summary), .cancelled)
    }

    func testPrivacySafeSummaryDoesNotCarryRawIdentifiers() {
        let remoteID = UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!
        let summary = SupabaseManualSyncRemotePreviewOutcomeMapper.summary(
            from: .success(makePreview(
                newProducts: [
                    SyncPreviewProductSummary(
                        classification: .newProduct,
                        remoteID: remoteID,
                        barcode: "987654321",
                        productName: "Private product name",
                        detail: "Private supplier"
                    )
                ],
                conflicts: [
                    SyncPreviewConflict(
                        kind: .remoteIDConflict,
                        barcodeOrKey: "987654321",
                        detail: remoteID.uuidString,
                        relatedRemoteIDs: [remoteID]
                    )
                ],
                supplierDiffs: [
                    SyncPreviewFieldChange(
                        fieldKey: .supplierName,
                        barcodeOrKey: "987654321",
                        remoteDisplay: "Private supplier",
                        localDisplay: "Local supplier"
                    )
                ]
            ))
        )

        let rendered = String(describing: summary).lowercased()
        XCTAssertFalse(rendered.contains("987654321"))
        XCTAssertFalse(rendered.contains("private product name"))
        XCTAssertFalse(rendered.contains("private supplier"))
        XCTAssertFalse(rendered.contains(remoteID.uuidString.lowercased()))
        XCTAssertEqual(summary.safeAggregateCounts.newProductCount, 1)
        XCTAssertEqual(summary.safeAggregateCounts.conflictCount, 1)
        XCTAssertEqual(summary.safeAggregateCounts.supplierDiffCount, 1)
    }

    func testProductPriceSignalsRemainAggregatedOnly() {
        let productID = UUID(uuidString: "CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCCC")!
        let summary = SupabaseManualSyncRemotePreviewOutcomeMapper.summary(
            from: .success(makePreview(
                remoteProductPriceCount: 1,
                priceHistoryDiffs: [
                    SyncPreviewFieldChange(
                        fieldKey: .priceHistory,
                        barcodeOrKey: "555 / purchase / 2026-05-01",
                        remoteDisplay: "9.990",
                        localDisplay: nil
                    )
                ],
                sourceErrors: [
                    SyncPreviewWarning(
                        code: .priceHistoryIncomplete,
                        detail: productID.uuidString,
                        relatedKey: "inventory_product_prices"
                    )
                ]
            ))
        )

        XCTAssertEqual(summary.safeAggregateCounts.remoteProductPriceCount, 1)
        XCTAssertEqual(summary.safeAggregateCounts.priceHistorySignalCount, 1)
        XCTAssertEqual(summary.safeAggregateCounts.sourceErrorCount, 1)
        let rendered = String(describing: summary).lowercased()
        XCTAssertFalse(rendered.contains("555"))
        XCTAssertFalse(rendered.contains("purchase"))
        XCTAssertFalse(rendered.contains(productID.uuidString.lowercased()))
    }

    func testPullPreviewAdapterCanUseFakeFetcherWithoutLiveNetwork() async throws {
        let fetcher = RemotePreviewInventoryFetcherFake(
            products: [
                remoteProduct(barcode: "100", name: "Remote only")
            ]
        )
        let service = SupabasePullPreviewService(inventoryService: fetcher, pageSize: 2)
        let adapter = SupabaseManualSyncPullPreviewAdapter(
            service: service,
            context: try makeContext()
        )

        let summary = await adapter.loadRemotePreviewSummary()

        XCTAssertTrue(summary.isComplete)
        XCTAssertTrue(summary.hasRemoteSignals)
        XCTAssertEqual(summary.safeAggregateCounts.remoteProductCount, 1)
        XCTAssertEqual(summary.safeAggregateCounts.newProductCount, 1)
        XCTAssertEqual(summary.recommendedUserMessageKey, .cloudDataNeedsReview)
        XCTAssertNotNil(adapter.stagedPreviewForLocalApply)
        adapter.clearStagedPreviewForLocalApply()
        XCTAssertNil(adapter.stagedPreviewForLocalApply)
        let productFetchCount = await fetcher.productFetchCount()
        XCTAssertEqual(productFetchCount, 1)
    }

    func testTask078PullPreviewAdapterDoesNotStagePartialPreview() async throws {
        let fetcher = RemotePreviewInventoryFetcherFake(
            products: [
                remoteProduct(barcode: "100", name: "Remote only")
            ]
        )
        let service = SupabasePullPreviewService(
            inventoryService: fetcher,
            pageSize: 2,
            catalogRowBudget: 0
        )
        let adapter = SupabaseManualSyncPullPreviewAdapter(
            service: service,
            context: try makeContext()
        )

        let summary = await adapter.loadRemotePreviewSummary()

        XCTAssertTrue(summary.isPartial)
        XCTAssertFalse(summary.isComplete)
        XCTAssertNil(adapter.stagedPreviewForLocalApply)
    }

    func testTask071ProductionSourcesAvoidForbiddenWriteAndAutomationScope() throws {
        let root = repoRootURL()
        let paths = [
            "iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncRemotePreview.swift",
            "iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncCoordinator.swift",
            "iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncCoordinatorModels.swift",
            "iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncCoordinating.swift",
            "iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncReleaseFactory.swift",
            "iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncViewModel.swift",
        ]
        let combined = try paths
            .map { try String(contentsOf: root.appendingPathComponent($0), encoding: .utf8) }
            .joined(separator: "\n")

        for forbidden in [
            "SupabaseCatalogBaselineWriter",
            "drainOnce",
            "enqueue(",
            "SupabaseManualPushService.execute",
            "record_sync_event",
            ".rpc(",
            ".upsert(",
            ".insert(",
            ".update(",
            ".delete(",
            "Timer",
            "BGTask",
            "Realtime",
            "worker",
            "polling",
            "SupabaseClient",
        ] {
            XCTAssertFalse(combined.contains(forbidden), "Forbidden TASK-071 production source term found: \(forbidden)")
        }
    }

    func testTask071ReleaseAndViewModelDoNotExposeRawSyncPreview() throws {
        let root = repoRootURL()
        let optionsSource = try String(
            contentsOf: root.appendingPathComponent("iOSMerchandiseControl/OptionsView.swift"),
            encoding: .utf8
        )
        let releaseCardSource = try extractReleaseCardSource(from: optionsSource)
        let viewModelSource = try String(
            contentsOf: root.appendingPathComponent("iOSMerchandiseControl/Sync/Manual/SupabaseManualSyncViewModel.swift"),
            encoding: .utf8
        )
        let combined = [releaseCardSource, viewModelSource].joined(separator: "\n")

        XCTAssertFalse(releaseCardSource.contains("SyncPreview"))
        XCTAssertFalse(combined.contains("SupabaseManualSyncPullPreviewAdapter"))
    }

    private func makePreview(
        outcome: SyncPreviewOutcome = .success,
        remoteProductCount: Int = 0,
        remoteSupplierCount: Int = 0,
        remoteCategoryCount: Int = 0,
        remoteProductPriceCount: Int = 0,
        newProducts: [SyncPreviewProductSummary] = [],
        updateCandidates: [SyncPreviewProductSummary] = [],
        conflicts: [SyncPreviewConflict] = [],
        tombstones: [SyncPreviewProductSummary] = [],
        supplierDiffs: [SyncPreviewFieldChange] = [],
        categoryDiffs: [SyncPreviewFieldChange] = [],
        priceHistoryDiffs: [SyncPreviewFieldChange] = [],
        warnings: [SyncPreviewWarning] = [],
        sourceErrors: [SyncPreviewWarning] = []
    ) -> SyncPreview {
        SyncPreview(
            generatedAt: Date(timeIntervalSince1970: 1_778_400_000),
            outcome: outcome,
            remoteCounts: RemoteInventorySnapshotCounts(
                products: max(remoteProductCount, newProducts.count + updateCandidates.count + conflicts.count + tombstones.count),
                activeProducts: max(remoteProductCount, newProducts.count + updateCandidates.count + conflicts.count),
                tombstonedProducts: tombstones.count,
                suppliers: remoteSupplierCount,
                categories: remoteCategoryCount,
                productPrices: remoteProductPriceCount
            ),
            localCounts: LocalInventorySnapshotCounts(products: 0, suppliers: 0, categories: 0, productPrices: 0),
            newProducts: newProducts,
            updateCandidates: updateCandidates,
            conflicts: conflicts,
            unchangedProducts: [],
            remoteTombstones: tombstones,
            supplierDiffs: supplierDiffs,
            categoryDiffs: categoryDiffs,
            priceHistoryDiffs: priceHistoryDiffs,
            warnings: warnings,
            metrics: [],
            sourceErrors: sourceErrors
        )
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            ProductPrice.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return ModelContext(container)
    }

    private func repoRootURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func extractReleaseCardSource(from source: String) throws -> String {
        let start = try XCTUnwrap(source.range(of: "private struct SupabaseAutomaticSyncStatusCard"))
        let end = try XCTUnwrap(source.range(of: "// MARK: - Header di sezione"))
        XCTAssertLessThan(start.lowerBound, end.lowerBound)
        return String(source[start.lowerBound..<end.lowerBound])
    }

    private func remoteProduct(
        id: UUID = UUID(),
        barcode: String,
        name: String
    ) -> RemoteInventoryProductRow {
        RemoteInventoryProductRow(
            id: id,
            ownerUserID: ownerID,
            barcode: barcode,
            itemNumber: nil,
            productName: name,
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            supplierID: nil,
            categoryID: nil,
            stockQuantity: nil,
            updatedAt: "2026-05-07T00:00:00Z",
            deletedAt: nil
        )
    }
}

private actor RemotePreviewInventoryFetcherFake: SupabaseInventoryFetching {
    private let products: [RemoteInventoryProductRow]
    private var productCalls = 0

    init(products: [RemoteInventoryProductRow]) {
        self.products = products
    }

    func productFetchCount() -> Int {
        productCalls
    }

    func fetchProductsPage(from: Int, to: Int) async throws -> [RemoteInventoryProductRow] {
        productCalls += 1
        return page(products, from: from, to: to)
    }

    func fetchSuppliersPage(from: Int, to: Int) async throws -> [RemoteInventorySupplierRow] {
        []
    }

    func fetchCategoriesPage(from: Int, to: Int) async throws -> [RemoteInventoryCategoryRow] {
        []
    }

    func fetchProductPricesPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        []
    }

    private func page<Row>(_ rows: [Row], from: Int, to: Int) -> [Row] {
        guard from < rows.count else { return [] }
        let upperBound = min(to + 1, rows.count)
        return Array(rows[from..<upperBound])
    }
}
