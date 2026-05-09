import XCTest
import SwiftData
@testable import iOSMerchandiseControl

final class SupabaseProductPriceManualPushServiceTests: XCTestCase {
    private let engine = SupabaseProductPricePushDryRunEngine()
    private let ownerID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private static var retainedContainers: [ModelContainer] = []
    private static var retainedContexts: [ModelContext] = []

    func testBlocksSnapshotWithoutSafeDryRun() {
        let plan = makePlan(remoteDedupeStatus: .unsafePartialRemoteDedupe(.networkOrPermission))

        XCTAssertThrowsError(try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: plan)) { error in
            XCTAssertEqual(error as? ProductPriceManualPushError, .unsafeDryRun)
        }
    }

    func testSnapshotStaleWhenCandidateFingerprintChanges() throws {
        let plan = makePlan(localPrices: [localPrice(price: 12.34)])
        let changedPlan = makePlan(localPrices: [localPrice(price: 12.35)])
        let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: plan)

        XCTAssertFalse(ProductPriceManualPushSnapshotFactory.isSnapshot(snapshot, currentFor: changedPlan))
    }

    func testBatchOverLimitFailsClosed() {
        let prices = (0..<101).map { index in
            localPrice(
                localID: "price-\(index)",
                productRemoteID: uuid(10_000 + index),
                productBarcode: "B\(index)"
            )
        }
        let plan = makePlan(localPrices: prices)

        XCTAssertThrowsError(try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: plan)) { error in
            XCTAssertEqual(error as? ProductPriceManualPushError, .overBatchLimit(limit: 100, actual: 101))
        }
    }

    func testPayloadOwnerUserIDAndDeterministicIDComeFromDryRunSession() throws {
        let plan = makePlan(localPrices: [localPrice(type: " purchase ")])
        let changedPlan = makePlan(localPrices: [
            localPrice(type: " purchase ", effectiveAt: try date("2026-05-02 10:30:00"))
        ])
        let first = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: plan)
        let second = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: plan)
        let changed = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: changedPlan)
        let payload = try XCTUnwrap(first.payloads.first)

        XCTAssertEqual(payload.ownerUserID, ownerID)
        XCTAssertEqual(payload.type, "PURCHASE")
        XCTAssertEqual(payload.id, second.payloads.first?.id)
        XCTAssertNotEqual(payload.id, changed.payloads.first?.id)
    }

    func testReadBackExactMatchSucceedsWithNormalizedTypeEffectiveAtAndPrice() async throws {
        let plan = makePlan(localPrices: [
            localPrice(type: " PuRcHaSe ", price: 12.3404, effectiveAt: try date("2026-05-01T10:30:00Z"))
        ])
        let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: plan)
        let row = try XCTUnwrap(snapshot.payloads.first).remoteRow(
            type: "purchase",
            price: 12.3400,
            effectiveAt: "2026-05-01T10:30:00Z"
        )
        let remote = MockProductPriceManualPushRemote(readBackRows: [row])
        let service = SupabaseProductPriceManualPushService(remote: remote)

        let result = try await service.push(snapshot: snapshot)
        let insertCalls = await remote.insertCalls
        let upsertCalls = await remote.upsertCalls

        XCTAssertTrue(result.isVerifiedSuccess)
        XCTAssertEqual(insertCalls, 1)
        XCTAssertEqual(upsertCalls, 0)
    }

    func testReadBackUsesSnapshotOwnerAndProductFilter() async throws {
        let plan = makePlan(localPrices: [
            localPrice(localID: "price-1", productRemoteID: uuid(201), productBarcode: "201"),
            localPrice(localID: "price-2", productRemoteID: uuid(202), productBarcode: "202")
        ])
        let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: plan)
        let remote = MockProductPriceManualPushRemote(
            readBackRows: snapshot.payloads.map { $0.remoteRow() }
        )
        let service = SupabaseProductPriceManualPushService(remote: remote)

        let result = try await service.push(snapshot: snapshot)
        let readBackOwnerUserIDs = await remote.readBackOwnerUserIDs
        let readBackProductIDs = await remote.readBackProductIDs

        XCTAssertTrue(result.isVerifiedSuccess)
        XCTAssertEqual(readBackOwnerUserIDs, [snapshot.ownerUserID])
        XCTAssertEqual(Set(readBackProductIDs.flatMap { $0 }), Set(snapshot.payloads.map(\.productID)))
    }

    func testReadBackMissingRowIsFailure() async throws {
        let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: makePlan())
        let remote = MockProductPriceManualPushRemote(readBackRows: [])
        let service = SupabaseProductPriceManualPushService(remote: remote)

        let result = try await service.push(snapshot: snapshot)

        guard case .missingRows(let ids) = result.verification else {
            return XCTFail("Expected missing row verification failure")
        }
        XCTAssertEqual(ids, snapshot.payloads.map(\.id))
    }

    func testReadBackPriceMismatchIsFailure() async throws {
        let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: makePlan())
        let payload = try XCTUnwrap(snapshot.payloads.first)
        let remote = MockProductPriceManualPushRemote(readBackRows: [
            payload.remoteRow(price: 99)
        ])
        let service = SupabaseProductPriceManualPushService(remote: remote)

        let result = try await service.push(snapshot: snapshot)

        guard case .mismatchedRows(let mismatches) = result.verification else {
            return XCTFail("Expected mismatch verification failure")
        }
        XCTAssertTrue(mismatches.contains { $0.reason == "price" })
    }

    func testReadBackTypeAndEffectiveAtMismatchAreFailures() async throws {
        let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: makePlan())
        let payload = try XCTUnwrap(snapshot.payloads.first)
        let remote = MockProductPriceManualPushRemote(readBackRows: [
            payload.remoteRow(type: "RETAIL", effectiveAt: "2026-05-02 10:30:00")
        ])
        let service = SupabaseProductPriceManualPushService(remote: remote)

        let result = try await service.push(snapshot: snapshot)

        guard case .mismatchedRows(let mismatches) = result.verification else {
            return XCTFail("Expected mismatch verification failure")
        }
        XCTAssertTrue(mismatches.contains { $0.reason == "type" })
        XCTAssertTrue(mismatches.contains { $0.reason == "effective_at" })
    }

    func testVerificationUnknownWhenReadBackFailsAfterInsert() async throws {
        let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: makePlan())
        let remote = MockProductPriceManualPushRemote(
            readBackRows: [],
            readBackError: SupabaseInventoryServiceError.networkError(statusCode: nil, message: "timeout")
        )
        let service = SupabaseProductPriceManualPushService(remote: remote)

        let result = try await service.push(snapshot: snapshot)

        guard case .unknown = result.verification else {
            return XCTFail("Expected verification unknown")
        }
        XCTAssertFalse(result.isVerifiedSuccess)
    }

    func testUniqueConflictDoesNotRetryOrUpsert() async throws {
        let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: makePlan())
        let remote = MockProductPriceManualPushRemote(
            readBackRows: [],
            insertError: ProductPriceManualPushError.uniqueConflict(message: "duplicate")
        )
        let service = SupabaseProductPriceManualPushService(remote: remote)

        do {
            _ = try await service.push(snapshot: snapshot)
            XCTFail("Expected unique conflict")
        } catch {
            XCTAssertEqual(error as? ProductPriceManualPushError, .uniqueConflict(message: "duplicate"))
        }
        let insertCalls = await remote.insertCalls
        let readBackCalls = await remote.readBackCalls
        let upsertCalls = await remote.upsertCalls

        XCTAssertEqual(insertCalls, 1)
        XCTAssertEqual(readBackCalls, 0)
        XCTAssertEqual(upsertCalls, 0)
    }

    @MainActor
    func testTask088VerifiedPushLinksRemoteIDAcrossReloadAndSecondDryRun() async throws {
        let container = try makeContainer()
        let context = makeContext(for: container)
        try insertValidBaseline(context: context, ownerID: ownerID)
        let product = Product(
            barcode: "TASK088_BAR_PRICE",
            remoteID: uuid(201),
            productName: "TASK088_PRODUCT"
        )
        context.insert(product)
        let prices: [(PriceType, Double, String)] = [
            (.purchase, 10.10, "2026-05-01 10:00:00"),
            (.purchase, 11.20, "2026-05-02 10:00:00"),
            (.retail, 20.30, "2026-05-01 11:00:00"),
            (.retail, 21.40, "2026-05-02 11:00:00")
        ]
        for (type, amount, effectiveAt) in prices {
            context.insert(
                ProductPrice(
                    type: type,
                    price: amount,
                    effectiveAt: try date(effectiveAt),
                    source: "TASK088_IOS_PUSH",
                    note: "TASK088_IDENTITY",
                    createdAt: try date(effectiveAt),
                    product: product
                )
            )
        }
        try context.save()

        let remote = MockProductPriceManualPushRemote(echoInsertedRowsToReadBack: true)
        let dryRunService = SupabaseProductPricePushDryRunService(fetcher: remote)
        let firstPlan = try await dryRunService.loadDryRun(context: context, sessionSnapshot: session())
        XCTAssertEqual(firstPlan.summary.readyCandidates, 4)
        let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: firstPlan)
        let pushResult = try await SupabaseProductPriceManualPushService(remote: remote).push(snapshot: snapshot)

        XCTAssertTrue(pushResult.isVerifiedSuccess)
        XCTAssertEqual(
            try ProductPriceManualPushIdentityReconciler().linkVerifiedPayloads(snapshot.payloads, context: context),
            4
        )

        let reloadedContext = makeContext(for: container)
        let reloadedPrices = try reloadedContext.fetch(
            FetchDescriptor<ProductPrice>(
                sortBy: [
                    SortDescriptor(\ProductPrice.effectiveAt),
                    SortDescriptor(\ProductPrice.createdAt)
                ]
            )
        )
        XCTAssertEqual(Set(reloadedPrices.compactMap(\.remoteID)), Set(snapshot.payloads.map(\.id)))

        let secondPlan = try await dryRunService.loadDryRun(context: reloadedContext, sessionSnapshot: session())
        XCTAssertEqual(secondPlan.summary.localPriceCount, 4)
        XCTAssertEqual(secondPlan.summary.readyCandidates, 0)
        XCTAssertTrue(secondPlan.candidates.isEmpty)
    }

    @MainActor
    func testTask088IdentityReconcilerFailsClosedForAmbiguousLocalMatch() async throws {
        let context = try makeContext()
        let product = Product(
            barcode: "TASK088_BAR_PRICE",
            remoteID: uuid(201),
            productName: "TASK088_PRODUCT"
        )
        context.insert(product)
        for index in 0..<2 {
            context.insert(
                ProductPrice(
                    type: .purchase,
                    price: 10.10,
                    effectiveAt: try date("2026-05-01 10:00:00"),
                    source: "TASK088_IOS_PUSH",
                    note: "TASK088_IDENTITY",
                    createdAt: try date("2026-05-01 10:0\(index):00"),
                    product: product
                )
            )
        }
        try context.save()

        let payload = ProductPriceManualPushPayload(
            id: uuid(301),
            ownerUserID: ownerID,
            productID: try XCTUnwrap(product.remoteID),
            type: "PURCHASE",
            price: 10.10,
            priceCanonical: try XCTUnwrap(PriceCanonicalizer.canonicalAmount(from: 10.10)?.value),
            effectiveAt: ProductPriceEffectiveAtCanonicalizer.canonicalString(
                from: try date("2026-05-01 10:00:00")
            ),
            source: "TASK088_IOS_PUSH",
            note: "TASK088_IDENTITY",
            createdAt: ProductPriceEffectiveAtCanonicalizer.canonicalString(
                from: try date("2026-05-01 10:00:00")
            )
        )

        XCTAssertThrowsError(
            try ProductPriceManualPushIdentityReconciler().linkVerifiedPayloads([payload], context: context)
        ) { error in
            guard case ProductPriceManualPushError.network = error else {
                return XCTFail("Expected fail-closed identity reconciliation error, got \(error)")
            }
        }
        let prices = try context.fetch(FetchDescriptor<ProductPrice>())
        XCTAssertTrue(prices.allSatisfy { $0.remoteID == nil })
    }

    @MainActor
    func testViewModelDoubleTapRunsSingleInsert() async throws {
        let context = try makeContextWithOnePrice()
        let remote = MockProductPriceManualPushRemote(
            insertDelayNanoseconds: 50_000_000,
            echoInsertedRowsToReadBack: true
        )
        let viewModel = ProductPriceManualPushDebugViewModel(remote: remote)

        viewModel.calculatePreview(context: context, sessionSnapshot: session())
        try await waitUntil { viewModel.state.kind == .previewSafe }

        viewModel.confirmPush()
        viewModel.confirmPush()
        try await waitUntil { viewModel.state.kind == .verifiedSuccess }
        let insertCalls = await remote.insertCalls

        XCTAssertEqual(insertCalls, 1)
    }

    @MainActor
    func testViewModelCancellationNeverReportsSuccess() async throws {
        let context = try makeContextWithOnePrice()
        let remote = MockProductPriceManualPushRemote(insertDelayNanoseconds: 300_000_000)
        let viewModel = ProductPriceManualPushDebugViewModel(remote: remote)

        viewModel.calculatePreview(context: context, sessionSnapshot: session())
        try await waitUntil { viewModel.state.kind == .previewSafe }

        viewModel.confirmPush()
        viewModel.cancel()

        XCTAssertEqual(viewModel.state.kind, .cancelled)
    }

    @MainActor
    func testViewModelInvalidatedSnapshotDisablesPush() async throws {
        let context = try makeContextWithOnePrice()
        let remote = MockProductPriceManualPushRemote()
        let viewModel = ProductPriceManualPushDebugViewModel(remote: remote)

        viewModel.calculatePreview(context: context, sessionSnapshot: session())
        try await waitUntil { viewModel.state.kind == .previewSafe }

        viewModel.invalidateSnapshot(reason: .staleSnapshot)

        XCTAssertEqual(viewModel.state.kind, .snapshotStale)
        XCTAssertFalse(viewModel.canPush)
    }

    func testTask051LocalizationKeysExistInSupportedLanguages() throws {
        let keys = [
            "options.advanced.header",
            "options.supabase.priceManualPush.title",
            "options.supabase.priceManualPush.badge.manual",
            "options.supabase.priceManualPush.badge.debug",
            "options.supabase.priceManualPush.subtitle",
            "options.supabase.priceManualPush.button.calculate",
            "options.supabase.priceManualPush.button.push",
            "options.supabase.priceManualPush.footer",
            "options.supabase.priceManualPush.status.verifiedSuccess",
            "options.supabase.priceManualPush.status.verificationUnknown",
            "options.supabase.priceManualPush.confirm.title",
            "options.supabase.priceManualPush.confirm.push",
            "options.supabase.priceManualPush.confirm.message"
        ]

        for language in ["it", "en", "es", "zh-Hans"] {
            let strings = try loadStrings(language: language)
            for key in keys {
                XCTAssertNotNil(strings[key], "\(key) missing in \(language)")
                XCTAssertFalse(strings[key]?.isEmpty ?? true, "\(key) empty in \(language)")
            }
        }
    }

    func testSourceContainsNoUpsertRetryOrScopeExtras() throws {
        let sourceText = try source(named: "SupabaseProductPriceManualPushService.swift")

        XCTAssertNil(sourceText.range(of: #"UUID\(\)"#, options: String.CompareOptions.regularExpression))
        XCTAssertNil(sourceText.range(
            of: #"\.upsert\(|\.update\(|\.delete\(|\.rpc\("#,
            options: String.CompareOptions.regularExpression
        ))
        XCTAssertFalse(sourceText.contains("record_" + "sync_event"))
        XCTAssertFalse(sourceText.contains("sync_" + "events"))
        XCTAssertFalse(sourceText.contains("out" + "box"))
    }

    private func makePlan(
        localPrices: [ProductPricePushDryRunLocalPrice]? = nil,
        remoteRows: [RemoteInventoryProductPriceRow] = [],
        remoteDedupeStatus: ProductPricePushRemoteDedupeStatus = .complete
    ) -> ProductPricePushDryRunPlan {
        let input = ProductPricePushDryRunInput(
            generatedAt: Date(timeIntervalSince1970: 1_778_000_000),
            sessionSnapshot: session(),
            baselineState: .available(ManualPushBaseline(productFingerprintsByRemoteID: [:])),
            localSnapshot: ProductPricePushDryRunLocalSnapshot(
                products: [
                    ProductPricePushDryRunLocalProduct(
                        localID: "product-1",
                        remoteID: uuid(201),
                        barcode: "100",
                        productName: "Coffee"
                    )
                ],
                prices: localPrices ?? [localPrice()]
            )
        )

        return engine.makePlan(
            input: input,
            remoteRows: remoteRows,
            remoteDedupeStatus: remoteDedupeStatus,
            remoteRowsRead: remoteRows.count,
            remotePagesRead: remoteRows.isEmpty ? 0 : 1
        )
    }

    private func localPrice(
        localID: String = "price-1",
        remoteID: UUID? = nil,
        productRemoteID: UUID? = nil,
        productBarcode: String = "100",
        type: String = "purchase",
        price: Double = 12.34,
        effectiveAt: Date? = nil,
        createdAt: Date? = nil
    ) -> ProductPricePushDryRunLocalPrice {
        ProductPricePushDryRunLocalPrice(
            localID: localID,
            remoteID: remoteID,
            productLocalID: productBarcode,
            productRemoteID: productRemoteID ?? uuid(201),
            productBarcode: productBarcode,
            productDisplayName: productBarcode,
            type: type,
            price: price,
            effectiveAt: effectiveAt ?? (try! date("2026-05-01 10:30:00")),
            createdAt: createdAt ?? (try! date("2026-05-01 10:31:00")),
            source: "TASK-051",
            note: nil
        )
    }

    @MainActor
    private func makeContextWithOnePrice() throws -> ModelContext {
        let context = try makeContext()
        try insertValidBaseline(context: context, ownerID: ownerID)
        let product = Product(barcode: "TASK051-100", remoteID: uuid(201))
        context.insert(product)
        context.insert(
            ProductPrice(
                type: .purchase,
                price: 12.34,
                effectiveAt: try date("2026-05-01 10:30:00"),
                source: "TASK-051",
                product: product
            )
        )
        try context.save()
        return context
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
        makeContext(for: try makeContainer())
    }

    @MainActor
    private func makeContainer() throws -> ModelContainer {
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
        return container
    }

    @MainActor
    private func makeContext(for container: ModelContainer) -> ModelContext {
        let context = ModelContext(container)
        Self.retainedContexts.append(context)
        return context
    }

    @MainActor
    private func insertValidBaseline(context: ModelContext, ownerID: UUID) throws {
        context.insert(
            SupabaseCatalogBaselineRun(
                ownerUserUUID: ownerID,
                status: .valid,
                appliedAt: Date(timeIntervalSince1970: 1_778_000_000)
            )
        )
        try context.save()
    }

    private func waitUntil(
        condition: @MainActor @escaping () -> Bool
    ) async throws {
        for _ in 0..<100 {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Timed out waiting for condition")
    }

    private func session() -> ProductPricePushDryRunSessionSnapshot {
        ProductPricePushDryRunSessionSnapshot(userID: ownerID, lastLinkedUserID: ownerID)
    }

    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: value))
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", value))")!
    }

    private func source(named fileName: String) throws -> String {
        let testsURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testsURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repoRoot
                .appendingPathComponent("iOSMerchandiseControl")
                .appendingPathComponent(fileName),
            encoding: .utf8
        )
    }

    private func loadStrings(language: String) throws -> [String: String] {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = testsDirectory
            .appendingPathComponent("iOSMerchandiseControl")
            .appendingPathComponent("\(language).lproj")
            .appendingPathComponent("Localizable.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        return try XCTUnwrap(plist as? [String: String])
    }
}

private extension ProductPriceManualPushPayload {
    func remoteRow(
        type: String? = nil,
        price: Double? = nil,
        effectiveAt: String? = nil
    ) -> RemoteInventoryProductPriceRow {
        RemoteInventoryProductPriceRow(
            id: id,
            ownerUserID: ownerUserID,
            productID: productID,
            type: type ?? self.type,
            price: price ?? self.price,
            effectiveAt: effectiveAt ?? self.effectiveAt,
            source: source,
            note: note,
            createdAt: createdAt
        )
    }
}

private actor MockProductPriceManualPushRemote: ProductPriceManualPushRemote {
    private var readBackRows: [RemoteInventoryProductPriceRow]
    private let insertError: Error?
    private let readBackError: Error?
    private let insertDelayNanoseconds: UInt64
    private let echoInsertedRowsToReadBack: Bool

    private(set) var insertCalls = 0
    private(set) var readBackCalls = 0
    private(set) var upsertCalls = 0
    private(set) var readBackOwnerUserIDs: [UUID] = []
    private(set) var readBackProductIDs: [[UUID]] = []

    init(
        readBackRows: [RemoteInventoryProductPriceRow] = [],
        insertError: Error? = nil,
        readBackError: Error? = nil,
        insertDelayNanoseconds: UInt64 = 0,
        echoInsertedRowsToReadBack: Bool = false
    ) {
        self.readBackRows = readBackRows
        self.insertError = insertError
        self.readBackError = readBackError
        self.insertDelayNanoseconds = insertDelayNanoseconds
        self.echoInsertedRowsToReadBack = echoInsertedRowsToReadBack
    }

    func fetchProductPricesForPushDryRunDedupePage(
        ownerUserID: UUID,
        productIDs: [UUID],
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow] {
        []
    }

    func insertProductPriceManualPushPayloads(_ payloads: [ProductPriceManualPushPayload]) async throws -> [RemoteInventoryProductPriceRow] {
        insertCalls += 1
        if insertDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: insertDelayNanoseconds)
        }
        if let insertError {
            throw insertError
        }
        let rows = payloads.map { $0.remoteRow() }
        if echoInsertedRowsToReadBack {
            readBackRows.append(contentsOf: rows)
        }
        return rows
    }

    func fetchProductPricesForManualPushVerificationPage(
        ownerUserID: UUID,
        productIDs: [UUID],
        from: Int,
        to: Int
    ) async throws -> [RemoteInventoryProductPriceRow] {
        readBackCalls += 1
        readBackOwnerUserIDs.append(ownerUserID)
        readBackProductIDs.append(productIDs)
        if let readBackError {
            throw readBackError
        }
        let filtered = readBackRows.filter { row in
            row.ownerUserID == ownerUserID && productIDs.contains(row.productID)
        }
        guard from < filtered.count else {
            return []
        }
        let end = min(to, filtered.count - 1)
        return Array(filtered[from...end])
    }
}
