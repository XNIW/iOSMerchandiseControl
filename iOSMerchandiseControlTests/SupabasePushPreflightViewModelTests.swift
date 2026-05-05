import XCTest
import SwiftData
@testable import iOSMerchandiseControl

@MainActor
final class SupabasePushPreflightViewModelTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    func testRunLocalCheckWithoutLinkedAccountSetsAccountNotLinked() throws {
        let viewModel = SupabasePushPreflightViewModel()
        let context = try makeContext()

        viewModel.runLocalCheck(
            context: context,
            isSignedIn: false,
            currentUserID: nil,
            lastLinkedUserID: nil
        )

        XCTAssertEqual(viewModel.state, .accountNotLinked)
    }

    func testRunLocalCheckUsesPersistentBaselineWhenLastLinkedUserIDIsMissing() async throws {
        let viewModel = SupabasePushPreflightViewModel()
        let context = try makeContext()
        let ownerID = UUID()
        let remoteID = UUID()
        context.insert(Product(
            barcode: "100",
            remoteID: remoteID,
            productName: "Baseline Product"
        ))
        try context.save()
        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )

        viewModel.runLocalCheck(
            context: context,
            isSignedIn: true,
            currentUserID: ownerID,
            lastLinkedUserID: nil
        )

        try await waitUntilNotRunning(viewModel)

        if case .completedNoWork(let summary) = viewModel.state {
            XCTAssertEqual(summary.totalBlockers, 0)
            XCTAssertEqual(summary.categoryCounts[.noOpAlreadySynced], 1)
        } else {
            XCTFail("Expected completedNoWork from persistent baseline, got \(viewModel.state)")
        }
    }

    func testMakeCompletedStateNoWork() {
        let preview = ManualPushPreview(
            generatedAt: Date(),
            plan: ManualPushPlan(
                generatedAt: Date(),
                candidates: [],
                blockedReasons: [],
                warnings: [],
                futureEventChangedCount: 0
            )
        )

        let state = SupabasePushPreflightViewModel.makeCompletedState(preview: preview, examplesLimit: 3)

        if case .completedNoWork(let summary) = state {
            XCTAssertEqual(summary.totalCandidates, 0)
            XCTAssertEqual(summary.totalBlockers, 0)
        } else {
            XCTFail("Expected completedNoWork")
        }
    }

    func testMakeCompletedStateNoWorkWithWarningsDoesNotReportSafe() {
        let preview = ManualPushPreview(
            generatedAt: Date(),
            plan: ManualPushPlan(
                generatedAt: Date(),
                candidates: [
                    PushCandidate(entityKind: .product, localID: "100", action: .noOpAlreadySynced)
                ],
                blockedReasons: [],
                warnings: [.warningStaleRemote],
                futureEventChangedCount: 0
            )
        )

        let state = SupabasePushPreflightViewModel.makeCompletedState(preview: preview, examplesLimit: 3)

        if case .completedNoWork(let summary) = state {
            XCTAssertEqual(summary.totalCandidates, 0)
            XCTAssertEqual(summary.totalBlockers, 0)
            XCTAssertEqual(summary.totalWarnings, 1)
        } else {
            XCTFail("Expected completedNoWork")
        }
    }

    func testMakeCompletedStateSafe() {
        let plan = ManualPushPlan(
            generatedAt: Date(),
            candidates: [
                PushCandidate(entityKind: .product, localID: "100", action: .dryRunCreateCandidate)
            ],
            blockedReasons: [],
            warnings: [],
            futureEventChangedCount: 1
        )
        let preview = ManualPushPreview(generatedAt: Date(), plan: plan)

        let state = SupabasePushPreflightViewModel.makeCompletedState(preview: preview, examplesLimit: 3)

        if case .completedSafe(let summary) = state {
            XCTAssertEqual(summary.totalCandidates, 1)
            XCTAssertEqual(summary.totalBlockers, 0)
        } else {
            XCTFail("Expected completedSafe")
        }
    }

    func testMakeCompletedStateBlockedWithTombstone() {
        let service = SupabaseManualPushPreflightService()
        let remoteID = UUID()
        let accountID = UUID()
        let product = ManualPushProductState(
            localID: "100",
            remoteID: remoteID,
            remoteDeletedAt: Date(),
            barcode: "100",
            productName: "Tombstone"
        )
        let baseline = ManualPushBaseline(productFingerprintsByRemoteID: [remoteID: product.catalogFingerprint])
        let input = ManualPushPreflightInput(
            pullState: ManualPushPullState(isComplete: true),
            accountState: ManualPushAccountState(currentUserID: accountID, lastLinkedUserID: accountID),
            baseline: baseline,
            products: [product]
        )
        let preview = service.makePreview(input: input)

        let state = SupabasePushPreflightViewModel.makeCompletedState(preview: preview, examplesLimit: 3)

        if case .completedBlocked(let summary) = state {
            XCTAssertGreaterThan(summary.totalBlockers, 0)
            XCTAssertEqual(summary.categoryCounts[.blockedTombstoneConflict], 1)
        } else {
            XCTFail("Expected completedBlocked")
        }
    }

    func testSummaryAggregationForMissingRemoteIDAndExamplesLimit() {
        let plan = ManualPushPlan(
            generatedAt: Date(),
            candidates: [],
            blockedReasons: [
                .blockedNoRemoteID,
                .blockedNoRemoteID,
                .blockedNoRemoteID
            ],
            warnings: [],
            futureEventChangedCount: 0
        )
        let preview = ManualPushPreview(generatedAt: Date(), plan: plan)

        let summary = SupabasePushPreflightViewModel.makeSummary(preview: preview, examplesLimit: 1)
        let group = summary.groups.first { $0.category == .blockedNoRemoteID }

        XCTAssertEqual(group?.count, 3)
        XCTAssertEqual(group?.examples.count, 1)
        XCTAssertEqual(group?.hiddenCount, 0)
    }

    func testSummaryLimitsCandidateExamples() {
        let plan = ManualPushPlan(
            generatedAt: Date(),
            candidates: [
                PushCandidate(entityKind: .product, localID: "100", action: .dryRunCreateCandidate),
                PushCandidate(entityKind: .product, localID: "101", action: .dryRunCreateCandidate),
                PushCandidate(entityKind: .product, localID: "102", action: .dryRunCreateCandidate)
            ],
            blockedReasons: [],
            warnings: [],
            futureEventChangedCount: 3
        )
        let preview = ManualPushPreview(generatedAt: Date(), plan: plan)

        let summary = SupabasePushPreflightViewModel.makeSummary(preview: preview, examplesLimit: 2)
        let group = summary.groups.first { $0.category == .dryRunCreateCandidate }

        XCTAssertEqual(group?.count, 3)
        XCTAssertEqual(group?.examples, ["100", "101"])
        XCTAssertEqual(group?.hiddenCount, 1)
    }

    func testSummaryContainsFutureOnlyProductPriceCategory() {
        let plan = ManualPushPlan(
            generatedAt: Date(),
            candidates: [
                PushCandidate(
                    entityKind: .productPrice,
                    localID: "price-1",
                    action: .futurePricePushCandidate
                )
            ],
            blockedReasons: [],
            warnings: [],
            futureEventChangedCount: 0
        )
        let preview = ManualPushPreview(generatedAt: Date(), plan: plan)
        let summary = SupabasePushPreflightViewModel.makeSummary(preview: preview, examplesLimit: 3)

        XCTAssertEqual(summary.totalFutureOnly, 1)
        XCTAssertEqual(summary.categoryCounts[.futurePricePushCandidate], 1)
    }

    func testFutureOnlyProductPriceIsNoWorkState() {
        let preview = ManualPushPreview(
            generatedAt: Date(),
            plan: ManualPushPlan(
                generatedAt: Date(),
                candidates: [
                    PushCandidate(
                        entityKind: .productPrice,
                        localID: "price-1",
                        action: .futurePricePushCandidate
                    )
                ],
                blockedReasons: [],
                warnings: [],
                futureEventChangedCount: 0
            )
        )

        let state = SupabasePushPreflightViewModel.makeCompletedState(preview: preview, examplesLimit: 3)

        if case .completedNoWork(let summary) = state {
            XCTAssertEqual(summary.totalCandidates, 0)
            XCTAssertEqual(summary.totalFutureOnly, 1)
        } else {
            XCTFail("Expected completedNoWork")
        }
    }

    func testConfirmedPushBlocksWhenPlanChangesAfterConfirmation() async throws {
        let context = try makeContext()
        let ownerID = UUID()
        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        context.insert(Supplier(name: "Acme"))
        try context.save()

        let gateway = CountingManualPushGateway()
        let viewModel = SupabasePushPreflightViewModel(
            manualPushService: SupabaseManualPushService(remote: gateway)
        )
        viewModel.runLocalCheck(
            context: context,
            isSignedIn: true,
            currentUserID: ownerID,
            lastLinkedUserID: ownerID
        )
        try await waitUntilNotRunning(viewModel)
        XCTAssertNotNil(viewModel.freezeCurrentPlanForConfirmation())

        context.insert(Supplier(name: "Changed"))
        try context.save()

        viewModel.runConfirmedPush(
            context: context,
            isSignedIn: true,
            currentUserID: ownerID,
            lastLinkedUserID: ownerID
        )
        try await waitUntilNotRunning(viewModel)

        if case .blockedBeforeWrite = viewModel.state {
            XCTAssertEqual(gateway.supplierCreateCallCount, 0)
        } else {
            XCTFail("Expected blockedBeforeWrite, got \(viewModel.state)")
        }
    }

    func testSecondConfirmedPushWhileRunningIsIgnored() async throws {
        let context = try makeContext()
        let ownerID = UUID()
        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerID
        )
        context.insert(Supplier(name: "Acme"))
        try context.save()

        let gateway = CountingManualPushGateway(delayNanoseconds: 80_000_000)
        let viewModel = SupabasePushPreflightViewModel(
            manualPushService: SupabaseManualPushService(remote: gateway)
        )
        viewModel.runLocalCheck(
            context: context,
            isSignedIn: true,
            currentUserID: ownerID,
            lastLinkedUserID: ownerID
        )
        try await waitUntilNotRunning(viewModel)
        XCTAssertNotNil(viewModel.freezeCurrentPlanForConfirmation())

        viewModel.runConfirmedPush(
            context: context,
            isSignedIn: true,
            currentUserID: ownerID,
            lastLinkedUserID: ownerID
        )
        viewModel.runConfirmedPush(
            context: context,
            isSignedIn: true,
            currentUserID: ownerID,
            lastLinkedUserID: ownerID
        )
        try await waitUntilNotRunning(viewModel)

        XCTAssertEqual(gateway.supplierCreateCallCount, 1)
    }

    func testCancelClearsRunningState() throws {
        let context = try makeContext()
        let ownerID = UUID()
        let viewModel = SupabasePushPreflightViewModel()

        viewModel.runLocalCheck(
            context: context,
            isSignedIn: true,
            currentUserID: ownerID,
            lastLinkedUserID: ownerID
        )
        XCTAssertTrue(viewModel.isRunning)

        viewModel.cancel()

        XCTAssertFalse(viewModel.isRunning)
        XCTAssertEqual(viewModel.state, .idle)
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
        let container = try ModelContainer(for: schema, configurations: configuration)
        Self.retainedContainers.append(container)
        return ModelContext(container)
    }

    private func waitUntilNotRunning(_ viewModel: SupabasePushPreflightViewModel) async throws {
        for _ in 0..<100 {
            if !viewModel.isRunning {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for preflight")
    }
}

private final class CountingManualPushGateway: SupabaseManualPushRemoteGateway {
    var supplierCreateCallCount = 0
    private let delayNanoseconds: UInt64

    init(delayNanoseconds: UInt64 = 0) {
        self.delayNanoseconds = delayNanoseconds
    }

    func createSuppliers(_ payloads: [SupabaseManualPushSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow] {
        supplierCreateCallCount += 1
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return payloads.map {
            RemoteInventorySupplierRow(
                id: UUID(),
                ownerUserID: $0.ownerUserID,
                name: $0.name,
                updatedAt: "2026-05-05T10:00:00Z",
                deletedAt: nil
            )
        }
    }

    func updateSupplier(id: UUID, payload: SupabaseManualPushSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow {
        RemoteInventorySupplierRow(id: id, ownerUserID: UUID(), name: payload.name, updatedAt: "2026-05-05T10:00:00Z", deletedAt: nil)
    }

    func verifySupplier(id: UUID, normalizedName: String) async throws -> RemoteInventorySupplierRow {
        RemoteInventorySupplierRow(id: id, ownerUserID: UUID(), name: normalizedName, updatedAt: "2026-05-05T10:00:00Z", deletedAt: nil)
    }

    func createCategories(_ payloads: [SupabaseManualPushCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow] { [] }
    func updateCategory(id: UUID, payload: SupabaseManualPushCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow {
        RemoteInventoryCategoryRow(id: id, ownerUserID: UUID(), name: payload.name, updatedAt: "2026-05-05T10:00:00Z", deletedAt: nil)
    }
    func verifyCategory(id: UUID, normalizedName: String) async throws -> RemoteInventoryCategoryRow {
        RemoteInventoryCategoryRow(id: id, ownerUserID: UUID(), name: normalizedName, updatedAt: "2026-05-05T10:00:00Z", deletedAt: nil)
    }

    func createProducts(_ payloads: [SupabaseManualPushProductCreatePayload]) async throws -> [RemoteInventoryProductRow] { [] }
    func updateProduct(id: UUID, payload: SupabaseManualPushProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        RemoteInventoryProductRow(id: id, ownerUserID: UUID(), barcode: payload.barcode ?? "100", itemNumber: nil, productName: nil, secondProductName: nil, purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil, updatedAt: "2026-05-05T10:00:00Z", deletedAt: nil)
    }
    func verifyProduct(id: UUID, normalizedBarcode: String) async throws -> RemoteInventoryProductRow {
        RemoteInventoryProductRow(id: id, ownerUserID: UUID(), barcode: normalizedBarcode, itemNumber: nil, productName: nil, secondProductName: nil, purchasePrice: nil, retailPrice: nil, supplierID: nil, categoryID: nil, stockQuantity: nil, updatedAt: "2026-05-05T10:00:00Z", deletedAt: nil)
    }

    func verifyReadBack(expectation: SupabaseManualPushReadBackExpectation) async throws {}
}
