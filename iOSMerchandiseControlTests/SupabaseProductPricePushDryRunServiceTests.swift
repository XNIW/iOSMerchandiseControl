import XCTest
import SwiftData
@testable import iOSMerchandiseControl

final class SupabaseProductPricePushDryRunServiceTests: XCTestCase {
    private let engine = SupabaseProductPricePushDryRunEngine()
    private let ownerID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static var retainedContainers: [ModelContainer] = []
    private static var retainedContexts: [ModelContext] = []

    func testProductWithoutRemoteIDBlocksPriceRows() throws {
        let plan = makePlan(localPrices: [
            localPrice(productRemoteID: nil)
        ])

        XCTAssertEqual(plan.summary.blockedNoRemoteID, 1)
        XCTAssertEqual(plan.summary.readyCandidates, 0)
        XCTAssertTrue(plan.candidates.isEmpty)
    }

    func testGlobalGatesBlockBeforeRemoteDedupe() {
        let cases: [(ProductPricePushDryRunSessionSnapshot, ProductPricePushBaselineState, KeyPath<ProductPricePushDryRunSummary, Int>)] = [
            (ProductPricePushDryRunSessionSnapshot(userID: nil, lastLinkedUserID: nil), .missing, \.blockedNoAuth),
            (ProductPricePushDryRunSessionSnapshot(userID: ownerID, lastLinkedUserID: uuid(999)), .available(baseline()), \.blockedAccountMismatch),
            (session(), .missing, \.blockedBaselineMissing),
            (session(), .stale, \.blockedBaselineStale),
            (session(), .partial, \.blockedBaselinePartial)
        ]

        for (sessionSnapshot, baselineState, keyPath) in cases {
            let input = makeInput(sessionSnapshot: sessionSnapshot, baselineState: baselineState)
            let plan = engine.makePlan(
                input: input,
                remoteRows: [],
                remoteDedupeStatus: .notNeeded,
                remoteRowsRead: 0,
                remotePagesRead: 0
            )

            XCTAssertEqual(plan.summary[keyPath: keyPath], 1)
            XCTAssertEqual(plan.summary.readyCandidates, 0)
            XCTAssertTrue(plan.candidates.isEmpty)
        }
    }

    func testCanonicalMappingCreatesDeterministicCandidatePayload() throws {
        let effectiveAt = try date("2026-05-01T10:30:00Z")
        let createdAt = try date("2026-05-01 10:31:00")
        let plan = makePlan(localPrices: [
            localPrice(
                type: " purchase ",
                price: 12.3404,
                effectiveAt: effectiveAt,
                createdAt: createdAt,
                source: " TASK-050 ",
                note: "  "
            )
        ])

        let candidate = try XCTUnwrap(plan.candidates.first)
        XCTAssertEqual(candidate.id, plan.candidates.first?.id)
        XCTAssertEqual(candidate.key?.stableID, "\(ownerID.uuidString.lowercased())|\(uuid(201).uuidString.lowercased())|purchase|2026-05-01 10:30:00")
        XCTAssertEqual(candidate.payload?.remoteType, "PURCHASE")
        XCTAssertEqual(candidate.payload?.canonicalPrice.value, "12.34")
        XCTAssertEqual(candidate.payload?.effectiveAt, "2026-05-01 10:30:00")
        XCTAssertEqual(candidate.payload?.createdAt, "2026-05-01 10:31:00")
        XCTAssertEqual(candidate.payload?.source, "TASK-050")
        XCTAssertNil(candidate.payload?.note)
    }

    func testZeroPriceIsAllowedButNaNInfiniteAndNegativeAreInvalid() {
        let zeroPlan = makePlan(localPrices: [
            localPrice(price: 0)
        ])
        XCTAssertEqual(zeroPlan.summary.readyCandidates, 1)

        for invalidPrice in [Double.nan, Double.infinity, -0.01] {
            let plan = makePlan(localPrices: [
                localPrice(price: invalidPrice)
            ])

            XCTAssertEqual(plan.summary.excludedInvalidLocal, 1)
            XCTAssertEqual(plan.summary.readyCandidates, 0)
        }
    }

    func testRemoteEmptyMakesAllValidRepresentativesCandidates() {
        let plan = makePlan(localPrices: [
            localPrice(localID: "b", productRemoteID: uuid(202), productBarcode: "200"),
            localPrice(localID: "a", productRemoteID: uuid(201), productBarcode: "100")
        ])

        XCTAssertEqual(plan.summary.readyCandidates, 2)
        XCTAssertEqual(plan.candidates.map { $0.productBarcode }, ["100", "200"])
    }

    func testLinkedLocalRemoteIDIsNotPushedAgain() {
        let plan = makePlan(localPrices: [
            localPrice(remoteID: uuid(301), productRemoteID: uuid(201), productBarcode: "100"),
            localPrice(localID: "new", productRemoteID: uuid(202), productBarcode: "200")
        ])

        XCTAssertEqual(plan.summary.localPriceCount, 2)
        XCTAssertEqual(plan.summary.readyCandidates, 1)
        XCTAssertEqual(plan.candidates.map(\.productBarcode), ["200"])
    }

    func testRemoteSameKeySamePriceIsAlreadyPresent() {
        let plan = makePlan(remoteRows: [
            remotePrice(productID: uuid(201), price: 12.3404)
        ])

        XCTAssertEqual(plan.summary.readyCandidates, 0)
        XCTAssertEqual(plan.summary.alreadyPresentRemote, 1)
        XCTAssertEqual(plan.alreadyPresentRemote.first?.reason, .alreadyPresentRemote)
    }

    func testRemoteSameKeyDifferentPriceIsConflict() {
        let plan = makePlan(remoteRows: [
            remotePrice(productID: uuid(201), price: 99)
        ])

        XCTAssertEqual(plan.summary.readyCandidates, 0)
        XCTAssertEqual(plan.summary.conflictSameKeyDifferentPrice, 1)
        XCTAssertTrue(plan.candidates.isEmpty)
    }

    func testUnsafePartialRemoteDedupeClearsSafeCandidates() {
        let plan = makePlan(
            remoteDedupeStatus: .unsafePartialRemoteDedupe(.networkOrPermission)
        )

        XCTAssertEqual(plan.remoteDedupeStatus, .unsafePartialRemoteDedupe(.networkOrPermission))
        XCTAssertEqual(plan.summary.readyCandidates, 0)
        XCTAssertTrue(plan.candidates.isEmpty)
    }

    func testLocalDuplicatesSameKeyUseOneStableRepresentativeAndReportBucket() {
        let later = try! date("2026-05-01 10:35:00")
        let earlier = try! date("2026-05-01 10:31:00")
        let plan = makePlan(localPrices: [
            localPrice(localID: "later", createdAt: later),
            localPrice(localID: "earlier", createdAt: earlier)
        ])

        XCTAssertEqual(plan.summary.localDuplicateSameKey, 2)
        XCTAssertEqual(plan.summary.readyCandidates, 1)
        XCTAssertTrue(plan.candidates.first?.id.contains("earlier") == true)
    }

    func testLocalConflictSameKeyDifferentCanonicalPriceBlocksKey() {
        let plan = makePlan(localPrices: [
            localPrice(localID: "one", price: 1),
            localPrice(localID: "two", price: 2)
        ])

        XCTAssertEqual(plan.summary.localConflictSameKeyDifferentPrice, 2)
        XCTAssertEqual(plan.summary.readyCandidates, 0)
        XCTAssertTrue(plan.candidates.isEmpty)
    }

    func testWrongOwnerRemoteRowsMakeDedupeUnsafe() {
        let plan = makePlan(remoteRows: [
            remotePrice(ownerUserID: uuid(888), productID: uuid(201), price: 12.34)
        ])

        XCTAssertEqual(plan.remoteDedupeStatus, .unsafePartialRemoteDedupe(.invalidRemoteRows))
        XCTAssertEqual(plan.summary.readyCandidates, 0)
        XCTAssertEqual(plan.summary.alreadyPresentRemote, 0)
    }

    func testInvalidRemoteRowsMakeDedupeUnsafe() {
        let plan = makePlan(remoteRows: [
            remotePrice(productID: uuid(201), type: "WHOLESALE")
        ])

        XCTAssertEqual(plan.remoteDedupeStatus, .unsafePartialRemoteDedupe(.invalidRemoteRows))
        XCTAssertEqual(plan.summary.readyCandidates, 0)
    }

    func testBucketOrderingIsDeterministic() {
        let first = makePlan(localPrices: shuffledLocalPrices())
        let second = makePlan(localPrices: shuffledLocalPrices().reversed())

        XCTAssertEqual(first.candidates.map(\.id), second.candidates.map(\.id))
    }

    func testSourceContainsNoRemoteWriteOrRandomCandidateID() throws {
        let sourceText = try source(named: "SupabaseProductPricePushDryRunService.swift")

        XCTAssertNil(sourceText.range(of: #"UUID\(\)"#, options: String.CompareOptions.regularExpression))
        XCTAssertNil(sourceText.range(
            of: #"\.insert\(|\.upsert\(|\.update\(|\.delete\(|\.rpc\("#,
            options: String.CompareOptions.regularExpression
        ))
        XCTAssertFalse(sourceText.contains("record_" + "sync_event"))
        XCTAssertFalse(sourceText.contains("sync_" + "events"))
        XCTAssertFalse(sourceText.contains("out" + "box"))
    }

    @MainActor
    func testServiceBatchesProductIDsAndUsesOwnerScopedFetcher() async throws {
        let context = try makeContext()
        try insertValidBaseline(context: context, ownerID: ownerID)
        for index in 0..<205 {
            let productID = uuid(10_000 + index)
            let product = Product(barcode: "B\(index)", remoteID: productID)
            context.insert(product)
            context.insert(ProductPrice(type: .purchase, price: 1, effectiveAt: try date("2026-05-01 10:30:00"), product: product))
        }
        try context.save()

        let fetcher = MockProductPricePushDryRunFetcher(rows: [])
        let service = SupabaseProductPricePushDryRunService(fetcher: fetcher)
        let plan = try await service.loadDryRun(context: context, sessionSnapshot: session())
        let calls = await fetcher.calls

        XCTAssertEqual(plan.summary.readyCandidates, 205)
        XCTAssertEqual(calls.count, 3)
        XCTAssertTrue(calls.allSatisfy { $0.ownerUserID == ownerID })
        XCTAssertEqual(calls.map { $0.productIDs.count }, [100, 100, 5])
    }

    @MainActor
    func testServicePagesWithinProductBatchUntilComplete() async throws {
        let context = try makeContext()
        try insertValidBaseline(context: context, ownerID: ownerID)
        let product = Product(barcode: "PAGED", remoteID: uuid(201))
        context.insert(product)
        context.insert(ProductPrice(type: .purchase, price: 1, effectiveAt: try date("2026-05-01 10:30:00"), product: product))
        try context.save()

        let fetcher = MockProductPricePushDryRunFetcher(rows: [
            remotePrice(productID: uuid(201), type: "PURCHASE", price: 1, effectiveAt: "2026-05-01 10:30:00"),
            remotePrice(id: uuid(102), productID: uuid(201), type: "RETAIL", price: 2, effectiveAt: "2026-05-02 10:30:00"),
            remotePrice(id: uuid(103), productID: uuid(201), type: "PURCHASE", price: 3, effectiveAt: "2026-05-03 10:30:00")
        ])
        let service = SupabaseProductPricePushDryRunService(
            fetcher: fetcher,
            fetchOptions: ProductPricePushDryRunFetchOptions(batchSize: 100, pageSize: 2, maxPagesPerBatch: 5, maxRemoteRows: 20)
        )

        let plan = try await service.loadDryRun(context: context, sessionSnapshot: session())
        let calls = await fetcher.calls

        XCTAssertEqual(calls.map { "\($0.from)-\($0.to)" }, ["0-1", "2-3"])
        XCTAssertEqual(plan.summary.remoteRowsRead, 3)
        XCTAssertEqual(plan.summary.alreadyPresentRemote, 1)
        XCTAssertEqual(plan.remoteDedupeStatus, .complete)
    }

    @MainActor
    func testServiceCompletesWhenFinalPageUsesLastAllowedPage() async throws {
        let context = try makeContext()
        try insertValidBaseline(context: context, ownerID: ownerID)
        let product = Product(barcode: "LASTPAGE", remoteID: uuid(201))
        context.insert(product)
        context.insert(ProductPrice(type: .purchase, price: 1, effectiveAt: try date("2026-05-01 10:30:00"), product: product))
        try context.save()

        let fetcher = MockProductPricePushDryRunFetcher(rows: [
            remotePrice(productID: uuid(201), type: "RETAIL", price: 2, effectiveAt: "2026-05-02 10:30:00"),
            remotePrice(id: uuid(102), productID: uuid(201), type: "RETAIL", price: 3, effectiveAt: "2026-05-03 10:30:00"),
            remotePrice(id: uuid(103), productID: uuid(201), type: "RETAIL", price: 4, effectiveAt: "2026-05-04 10:30:00")
        ])
        let service = SupabaseProductPricePushDryRunService(
            fetcher: fetcher,
            fetchOptions: ProductPricePushDryRunFetchOptions(batchSize: 100, pageSize: 2, maxPagesPerBatch: 2, maxRemoteRows: 20)
        )

        let plan = try await service.loadDryRun(context: context, sessionSnapshot: session())
        let calls = await fetcher.calls

        XCTAssertEqual(calls.map { "\($0.from)-\($0.to)" }, ["0-1", "2-3"])
        XCTAssertEqual(plan.summary.remoteRowsRead, 3)
        XCTAssertEqual(plan.remoteDedupeStatus, .complete)
    }

    @MainActor
    func testServiceMarksUnsafeWhenPageBudgetExceeded() async throws {
        let context = try makeContext()
        try insertValidBaseline(context: context, ownerID: ownerID)
        let product = Product(barcode: "BUDGET", remoteID: uuid(201))
        context.insert(product)
        context.insert(ProductPrice(type: .purchase, price: 1, effectiveAt: try date("2026-05-01 10:30:00"), product: product))
        try context.save()

        let fetcher = MockProductPricePushDryRunFetcher(rows: [
            remotePrice(productID: uuid(201), type: "RETAIL", price: 2, effectiveAt: "2026-05-02 10:30:00"),
            remotePrice(id: uuid(102), productID: uuid(201), type: "RETAIL", price: 3, effectiveAt: "2026-05-03 10:30:00")
        ])
        let service = SupabaseProductPricePushDryRunService(
            fetcher: fetcher,
            fetchOptions: ProductPricePushDryRunFetchOptions(batchSize: 100, pageSize: 1, maxPagesPerBatch: 1, maxRemoteRows: 20)
        )

        let plan = try await service.loadDryRun(context: context, sessionSnapshot: session())

        XCTAssertEqual(plan.remoteDedupeStatus, .unsafePartialRemoteDedupe(.pageBudgetExceeded))
        XCTAssertEqual(plan.summary.readyCandidates, 0)
    }

    @MainActor
    func testServiceMarksUnsafeWhenRowBudgetExceeded() async throws {
        let context = try makeContext()
        try insertValidBaseline(context: context, ownerID: ownerID)
        let product = Product(barcode: "ROWBUDGET", remoteID: uuid(201))
        context.insert(product)
        context.insert(ProductPrice(type: .purchase, price: 1, effectiveAt: try date("2026-05-01 10:30:00"), product: product))
        try context.save()

        let fetcher = MockProductPricePushDryRunFetcher(rows: [
            remotePrice(productID: uuid(201), type: "RETAIL", price: 2, effectiveAt: "2026-05-02 10:30:00"),
            remotePrice(id: uuid(102), productID: uuid(201), type: "RETAIL", price: 3, effectiveAt: "2026-05-03 10:30:00")
        ])
        let service = SupabaseProductPricePushDryRunService(
            fetcher: fetcher,
            fetchOptions: ProductPricePushDryRunFetchOptions(batchSize: 100, pageSize: 2, maxPagesPerBatch: 5, maxRemoteRows: 2)
        )

        let plan = try await service.loadDryRun(context: context, sessionSnapshot: session())

        XCTAssertEqual(plan.remoteDedupeStatus, .unsafePartialRemoteDedupe(.rowBudgetExceeded))
        XCTAssertEqual(plan.summary.readyCandidates, 0)
    }

    private func makePlan(
        sessionSnapshot: ProductPricePushDryRunSessionSnapshot? = nil,
        baselineState: ProductPricePushBaselineState = .available(ManualPushBaseline(productFingerprintsByRemoteID: [:])),
        localPrices: [ProductPricePushDryRunLocalPrice]? = nil,
        remoteRows: [RemoteInventoryProductPriceRow] = [],
        remoteDedupeStatus: ProductPricePushRemoteDedupeStatus = .complete
    ) -> ProductPricePushDryRunPlan {
        let input = makeInput(
            sessionSnapshot: sessionSnapshot ?? session(),
            baselineState: baselineState,
            localPrices: localPrices ?? [localPrice()]
        )
        return engine.makePlan(
            input: input,
            remoteRows: remoteRows,
            remoteDedupeStatus: remoteDedupeStatus,
            remoteRowsRead: remoteRows.count,
            remotePagesRead: remoteRows.isEmpty ? 0 : 1
        )
    }

    private func makeInput(
        sessionSnapshot: ProductPricePushDryRunSessionSnapshot? = nil,
        baselineState: ProductPricePushBaselineState = .available(ManualPushBaseline(productFingerprintsByRemoteID: [:])),
        localPrices: [ProductPricePushDryRunLocalPrice]? = nil
    ) -> ProductPricePushDryRunInput {
        ProductPricePushDryRunInput(
            generatedAt: Date(timeIntervalSince1970: 1_778_000_000),
            sessionSnapshot: sessionSnapshot ?? session(),
            baselineState: baselineState,
            localSnapshot: ProductPricePushDryRunLocalSnapshot(
                products: [
                    ProductPricePushDryRunLocalProduct(
                        localID: "product-100",
                        remoteID: uuid(201),
                        barcode: "100",
                        productName: "Product 100"
                    )
                ],
                prices: localPrices ?? [localPrice()]
            )
        )
    }

    private func localPrice(
        localID: String = "price-1",
        remoteID: UUID? = nil,
        productRemoteID: UUID? = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
        productBarcode: String = "100",
        type: String = "purchase",
        price: Double = 12.34,
        effectiveAt: Date? = nil,
        createdAt: Date? = nil,
        source: String? = nil,
        note: String? = nil
    ) -> ProductPricePushDryRunLocalPrice {
        ProductPricePushDryRunLocalPrice(
            localID: localID,
            remoteID: remoteID,
            productLocalID: productBarcode,
            productRemoteID: productRemoteID,
            productBarcode: productBarcode,
            productDisplayName: productBarcode,
            type: type,
            price: price,
            effectiveAt: effectiveAt ?? ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: "2026-05-01 10:30:00")!,
            createdAt: createdAt ?? ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: "2026-05-01 10:31:00")!,
            source: source,
            note: note
        )
    }

    private func shuffledLocalPrices() -> [ProductPricePushDryRunLocalPrice] {
        [
            localPrice(localID: "c", productRemoteID: uuid(203), productBarcode: "300"),
            localPrice(localID: "a", productRemoteID: uuid(201), productBarcode: "100"),
            localPrice(localID: "b", productRemoteID: uuid(202), productBarcode: "200")
        ]
    }

    private func remotePrice(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
        ownerUserID: UUID? = nil,
        productID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
        type: String = "PURCHASE",
        price: Double = 12.34,
        effectiveAt: String = "2026-05-01 10:30:00"
    ) -> RemoteInventoryProductPriceRow {
        RemoteInventoryProductPriceRow(
            id: id,
            ownerUserID: ownerUserID ?? ownerID,
            productID: productID,
            type: type,
            price: price,
            effectiveAt: effectiveAt,
            source: "TEST",
            note: "remote note",
            createdAt: "2026-05-01 10:31:00"
        )
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            ProductPrice.self,
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

    @MainActor
    private func insertValidBaseline(context: ModelContext, ownerID: UUID) throws {
        let run = SupabaseCatalogBaselineRun(
            ownerUserUUID: ownerID,
            status: .valid,
            appliedAt: Date(timeIntervalSince1970: 1_778_000_000)
        )
        context.insert(run)
        try context.save()
    }

    private func session() -> ProductPricePushDryRunSessionSnapshot {
        ProductPricePushDryRunSessionSnapshot(userID: ownerID, lastLinkedUserID: ownerID)
    }

    private func baseline() -> ManualPushBaseline {
        ManualPushBaseline(productFingerprintsByRemoteID: [:])
    }

    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: value))
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", value))")!
    }

    private func source(named filename: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let root = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent("iOSMerchandiseControl").appendingPathComponent(filename),
            encoding: .utf8
        )
    }
}

private actor MockProductPricePushDryRunFetcher: SupabaseProductPricePushDryRunRemoteFetching {
    struct Call: Sendable, Equatable {
        let ownerUserID: UUID
        let productIDs: [UUID]
        let from: Int
        let to: Int
    }

    private let rows: [RemoteInventoryProductPriceRow]
    private(set) var calls: [Call] = []

    init(rows: [RemoteInventoryProductPriceRow]) {
        self.rows = rows.sorted {
            ($0.productID.uuidString, $0.type, $0.effectiveAt, $0.id.uuidString)
                < ($1.productID.uuidString, $1.type, $1.effectiveAt, $1.id.uuidString)
        }
    }

    func fetchProductPricesForPushDryRunDedupePage(
        ownerUserID: UUID,
        productIDs: [UUID],
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow] {
        calls.append(Call(ownerUserID: ownerUserID, productIDs: productIDs, from: from, to: to))
        let allowed = Set(productIDs)
        let matching = rows.filter { $0.ownerUserID == ownerUserID && allowed.contains($0.productID) }
        guard from < matching.count else {
            return []
        }
        return Array(matching[from...min(to, matching.count - 1)])
    }
}
