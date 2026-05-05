import XCTest
import SwiftData
@testable import iOSMerchandiseControl

@MainActor
final class SupabaseCatalogBaselinePreflightIntegrationTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private static var retainedContexts: [ModelContext] = []
    private let service = SupabaseManualPushPreflightService()

    func testAccountMismatchBlocksWhenOnlyOtherOwnerBaselineExists() throws {
        let context = try makeContext()
        let currentOwner = UUID()
        let otherOwner = UUID()
        let remoteID = UUID()
        try insertProduct(context: context, remoteID: remoteID, productName: "Same")
        _ = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(
            context: context,
            ownerUserUUID: otherOwner
        )

        let result = try SupabaseCatalogBaselineReader().readManualPushBaseline(
            context: context,
            ownerUserUUID: currentOwner
        )
        XCTAssertEqual(result, .accountMismatch)

        let plan = service.makePlan(input: ManualPushPreflightInput(
            pullState: ManualPushPullState(isComplete: true),
            accountState: ManualPushAccountState(currentUserID: currentOwner, lastLinkedUserID: otherOwner),
            baseline: nil,
            products: try SwiftDataInventorySnapshotService(context: context).makeManualPushPreflightProductStates()
        ))

        XCTAssertTrue(plan.blockedReasons.contains(.blockedAccountMismatch))
    }

    func testStaleSchemaBlocksPreflight() throws {
        let context = try makeContext()
        let ownerID = UUID()
        context.insert(SupabaseCatalogBaselineRun(
            ownerUserUUID: ownerID,
            fingerprintSchemaVersion: SupabaseCatalogFingerprintSchema.currentVersion - 1,
            status: .valid,
            appliedAt: Date()
        ))
        try context.save()

        let result = try SupabaseCatalogBaselineReader().readManualPushBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        XCTAssertEqual(result, .staleSchema)

        let plan = service.makePlan(input: ManualPushPreflightInput(
            pullState: ManualPushPullState(isComplete: true),
            accountState: ManualPushAccountState(currentUserID: ownerID, lastLinkedUserID: ownerID),
            baseline: ManualPushBaseline(productFingerprintsByRemoteID: [:], invalidationReasons: [.fingerprintVersionChanged]),
            products: []
        ))

        XCTAssertTrue(plan.blockedReasons.contains(.blockedStaleOrPartialBaseline))
    }

    func testUnchangedProductIsNoWorkFromPersistentBaseline() throws {
        let context = try makeContext()
        let ownerID = UUID()
        let remoteID = UUID()
        try insertProduct(context: context, remoteID: remoteID, productName: "Same")
        _ = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(context: context, ownerUserUUID: ownerID)

        let plan = try makePlanFromReader(context: context, ownerID: ownerID)

        XCTAssertEqual(plan.candidates.first?.action, .noOpAlreadySynced)
        XCTAssertEqual(plan.categoryCounts[.noOpAlreadySynced], 1)
        XCTAssertTrue(plan.blockedReasons.isEmpty)
    }

    func testChangedProductIsDryRunUpdateCandidateFromPersistentBaseline() throws {
        let context = try makeContext()
        let ownerID = UUID()
        let remoteID = UUID()
        try insertProduct(context: context, remoteID: remoteID, productName: "Remote")
        _ = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(context: context, ownerUserUUID: ownerID)
        let product = try XCTUnwrap(try context.fetch(FetchDescriptor<Product>()).first)
        product.productName = "Local Change"
        try context.save()

        let plan = try makePlanFromReader(context: context, ownerID: ownerID)

        XCTAssertEqual(plan.candidates.first?.action, .dryRunUpdateCandidate)
        XCTAssertEqual(plan.categoryCounts[.dryRunUpdateCandidate], 1)
        XCTAssertTrue(plan.blockedReasons.isEmpty)
    }

    func testProductWithoutRemoteIDIsNewLocalDryRunOnlyWithValidBaseline() throws {
        let context = try makeContext()
        let ownerID = UUID()
        try insertProduct(context: context, remoteID: UUID(), barcode: "100", productName: "Remote")
        _ = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(context: context, ownerUserUUID: ownerID)
        context.insert(Product(barcode: "local", productName: "Local"))
        try context.save()

        let plan = try makePlanFromReader(context: context, ownerID: ownerID)

        XCTAssertTrue(plan.candidates.contains { $0.localID == "local" && $0.action == .dryRunCreateCandidate })
        XCTAssertTrue(plan.isSendable)
    }

    func testProductWithRemoteIDButMissingBaselineRecordBlocksMissingBaseline() throws {
        let context = try makeContext()
        let ownerID = UUID()
        let remoteID = UUID()
        try insertProduct(context: context, remoteID: remoteID, productName: "Local")
        let run = SupabaseCatalogBaselineRun(
            ownerUserUUID: ownerID,
            status: .valid,
            appliedAt: Date()
        )
        context.insert(run)
        try context.save()

        let plan = try makePlanFromReader(context: context, ownerID: ownerID)

        XCTAssertTrue(plan.blockedReasons.contains(.blockedMissingBaseline))
        XCTAssertFalse(plan.candidates.contains { $0.action == .dryRunUpdateCandidate })
    }

    func testBaselineTombstoneWithLocalProductBlocksTombstoneConflict() throws {
        let context = try makeContext()
        let ownerID = UUID()
        let remoteID = UUID()
        try insertProduct(context: context, remoteID: remoteID, productName: "Local")
        let runID = UUID()
        let run = SupabaseCatalogBaselineRun(
            baselineRunID: runID,
            ownerUserUUID: ownerID,
            status: .valid,
            appliedAt: Date(),
            productCount: 1,
            tombstoneCount: 1
        )
        let product = try XCTUnwrap(try context.fetch(FetchDescriptor<Product>()).first)
        let fingerprint = product.catalogFingerprint
        context.insert(run)
        context.insert(SupabaseCatalogBaselineRecord(
            baselineRunID: runID,
            ownerUserUUID: ownerID,
            entityType: .product,
            remoteID: remoteID,
            remoteDeletedAt: Date(timeIntervalSince1970: 1_778_300_000),
            fingerprintCanonical: fingerprint.canonicalString,
            barcodeCanonical: "100"
        ))
        try context.save()

        let plan = try makePlanFromReader(context: context, ownerID: ownerID)

        XCTAssertTrue(plan.blockedReasons.contains(.blockedTombstoneConflict))
        XCTAssertFalse(plan.candidates.contains { $0.action == .dryRunUpdateCandidate })
    }

    func testUnsafePreviewDoesNotRefreshBaseline() throws {
        let context = try makeContext()
        let ownerID = UUID()
        try insertProduct(context: context, remoteID: UUID(), productName: "Remote")

        let unsafePreviews = [
            makePreview(outcome: .partial),
            makePreview(sourceErrors: [
                SyncPreviewWarning(code: .sourceError, detail: "inventory_products", relatedKey: "inventory_products")
            ]),
            makePreview(warnings: [
                SyncPreviewWarning(code: .priceHistoryIncomplete, detail: "inventory_product_prices", relatedKey: "inventory_product_prices")
            ]),
            makePreview(conflicts: [
                SyncPreviewConflict(kind: .remoteIDConflict, barcodeOrKey: "100")
            ])
        ]

        for preview in unsafePreviews {
            XCTAssertThrowsError(
                try SupabaseCatalogBaselineWriter(now: clock()).commitAfterSuccessfulFullPullApply(
                    preview: preview,
                    context: context,
                    ownerUserUUID: ownerID
                )
            )
        }
        XCTAssertEqual(
            try SupabaseCatalogBaselineReader().readManualPushBaseline(context: context, ownerUserUUID: ownerID),
            .missing
        )
    }

    func testCompleteApplyCanRefreshBaseline() throws {
        let context = try makeContext()
        let ownerID = UUID()
        let remoteID = UUID()
        let preview = makePreview(newProducts: [
            makeSummary(payload: makePayload(remoteID: remoteID, barcode: "100", productName: " Remote "))
        ])
        let plan = try SupabasePullApplyService().prepareApplyPlan(
            preview: preview,
            context: context,
            isAuthenticated: true
        )
        _ = try SupabasePullApplyService().apply(plan: plan, context: context)

        _ = try SupabaseCatalogBaselineWriter(now: clock()).commitAfterSuccessfulFullPullApply(
            preview: preview,
            context: context,
            ownerUserUUID: ownerID
        )

        guard case .available(let baseline) = try SupabaseCatalogBaselineReader()
            .readManualPushBaseline(context: context, ownerUserUUID: ownerID) else {
            return XCTFail("Expected valid baseline")
        }
        XCTAssertNotNil(baseline.baseline.productFingerprintsByRemoteID[remoteID])
    }

    func testRawPayloadFormattingConvergesToStablePostSaveFingerprint() throws {
        let context = try makeContext()
        let ownerID = UUID()
        let remoteID = UUID()
        let preview = makePreview(newProducts: [
            makeSummary(payload: makePayload(
                remoteID: remoteID,
                barcode: " 100 ",
                productName: " Remote ",
                purchasePrice: 1.00
            ))
        ])
        let plan = try SupabasePullApplyService().prepareApplyPlan(
            preview: preview,
            context: context,
            isAuthenticated: true
        )
        _ = try SupabasePullApplyService().apply(plan: plan, context: context)

        let first = try SupabaseCatalogBaselineWriter(now: clock()).commitAfterSuccessfulFullPullApply(
            preview: preview,
            context: context,
            ownerUserUUID: ownerID
        )
        let firstRecord = try productBaselineRecord(context: context, runID: first.baselineRunID)

        let second = try SupabaseCatalogBaselineWriter(now: clock()).commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        let secondRecord = try productBaselineRecord(context: context, runID: second.baselineRunID)

        XCTAssertEqual(firstRecord.fingerprintCanonical, secondRecord.fingerprintCanonical)
    }

    private func makePlanFromReader(context: ModelContext, ownerID: UUID) throws -> ManualPushPlan {
        let readerResult = try SupabaseCatalogBaselineReader().readManualPushBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        let baseline: ManualPushBaseline?
        switch readerResult {
        case .available(let snapshot):
            baseline = snapshot.baseline
        case .staleSchema:
            baseline = ManualPushBaseline(productFingerprintsByRemoteID: [:], invalidationReasons: [.fingerprintVersionChanged])
        case .incomplete:
            baseline = ManualPushBaseline(productFingerprintsByRemoteID: [:], invalidationReasons: [.partialPull])
        case .missing, .accountMismatch:
            baseline = nil
        }

        return service.makePlan(input: ManualPushPreflightInput(
            pullState: ManualPushPullState(isComplete: true),
            accountState: ManualPushAccountState(currentUserID: ownerID, lastLinkedUserID: ownerID),
            baseline: baseline,
            products: try SwiftDataInventorySnapshotService(context: context).makeManualPushPreflightProductStates()
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
        let context = ModelContext(container)
        Self.retainedContexts.append(context)
        return context
    }

    private func insertProduct(
        context: ModelContext,
        remoteID: UUID?,
        barcode: String = "100",
        productName: String
    ) throws {
        context.insert(Product(
            barcode: barcode,
            remoteID: remoteID,
            itemNumber: "SKU",
            productName: productName,
            purchasePrice: 1,
            retailPrice: 2
        ))
        try context.save()
    }

    private func makePreview(
        outcome: SyncPreviewOutcome = .success,
        newProducts: [SyncPreviewProductSummary] = [],
        conflicts: [SyncPreviewConflict] = [],
        warnings: [SyncPreviewWarning] = [],
        sourceErrors: [SyncPreviewWarning] = []
    ) -> SyncPreview {
        SyncPreview(
            generatedAt: Date(timeIntervalSince1970: 1_778_300_000),
            outcome: outcome,
            remoteCounts: RemoteInventorySnapshotCounts(
                products: newProducts.count,
                activeProducts: newProducts.count,
                tombstonedProducts: 0,
                suppliers: 0,
                categories: 0,
                productPrices: 0
            ),
            localCounts: LocalInventorySnapshotCounts(
                products: 0,
                suppliers: 0,
                categories: 0,
                productPrices: 0
            ),
            newProducts: newProducts,
            updateCandidates: [],
            conflicts: conflicts,
            unchangedProducts: [],
            remoteTombstones: [],
            supplierDiffs: [],
            categoryDiffs: [],
            priceHistoryDiffs: [],
            warnings: warnings,
            metrics: [],
            sourceErrors: sourceErrors
        )
    }

    private func makeSummary(payload: SyncPreviewProductApplyPayload) -> SyncPreviewProductSummary {
        SyncPreviewProductSummary(
            classification: .newProduct,
            remoteID: payload.remoteID,
            barcode: payload.barcode,
            productName: payload.productName,
            applyPayload: payload
        )
    }

    private func makePayload(
        remoteID: UUID,
        barcode: String,
        productName: String,
        purchasePrice: Double? = nil
    ) -> SyncPreviewProductApplyPayload {
        SyncPreviewProductApplyPayload(
            remoteID: remoteID,
            barcode: barcode,
            productName: productName,
            purchasePrice: purchasePrice
        )
    }

    private func productBaselineRecord(
        context: ModelContext,
        runID: UUID
    ) throws -> SupabaseCatalogBaselineRecord {
        try XCTUnwrap(
            try context.fetch(FetchDescriptor<SupabaseCatalogBaselineRecord>())
                .first { $0.baselineRunID == runID && $0.entityType == SupabaseCatalogBaselineEntityType.product.rawValue }
        )
    }

    private func clock() -> () -> Date {
        var offset: TimeInterval = 0
        return {
            offset += 1
            return Date(timeIntervalSince1970: 1_778_300_000 + offset)
        }
    }
}

private extension Product {
    var catalogFingerprint: ManualPushFingerprint {
        ManualPushFingerprintNormalizer.product(
            barcode: barcode,
            itemNumber: itemNumber,
            productName: productName,
            secondProductName: secondProductName,
            purchasePrice: purchasePrice,
            retailPrice: retailPrice,
            stockQuantity: stockQuantity,
            supplierRemoteID: supplier?.remoteID,
            categoryRemoteID: category?.remoteID
        )
    }
}
