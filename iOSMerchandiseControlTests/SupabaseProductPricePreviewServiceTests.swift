import Foundation
import XCTest
@testable import iOSMerchandiseControl

final class SupabaseProductPricePreviewServiceTests: XCTestCase {
    private let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    func testDecodesRemoteProductPriceDTO() throws {
        let data = Data("""
        {
          "id": "00000000-0000-0000-0000-000000000101",
          "owner_user_id": "00000000-0000-0000-0000-000000000001",
          "product_id": "00000000-0000-0000-0000-000000000201",
          "type": "PURCHASE",
          "price": 12.5,
          "effective_at": "2026-05-01 10:30:00",
          "source": "ANDROID",
          "note": "not shown by preview",
          "created_at": "2026-05-01 10:31:00"
        }
        """.utf8)

        let row = try JSONDecoder().decode(RemoteInventoryProductPriceRow.self, from: data)

        XCTAssertEqual(row.id, uuid(101))
        XCTAssertEqual(row.ownerUserID, ownerID)
        XCTAssertEqual(row.productID, uuid(201))
        XCTAssertEqual(row.type, "PURCHASE")
        XCTAssertEqual(row.price, 12.5)
        XCTAssertEqual(row.effectiveAt, "2026-05-01 10:30:00")
        XCTAssertEqual(row.createdAt, "2026-05-01 10:31:00")
    }

    func testNormalizesPurchaseRetailAndMixedCaseTypes() {
        XCTAssertEqual(SupabasePullPreviewNormalizer.normalizedPriceType("PURCHASE"), "purchase")
        XCTAssertEqual(SupabasePullPreviewNormalizer.normalizedPriceType("RETAIL"), "retail")
        XCTAssertEqual(SupabasePullPreviewNormalizer.normalizedPriceType(" PuRcHaSe "), "purchase")
        XCTAssertNil(SupabasePullPreviewNormalizer.normalizedPriceType("WHOLESALE"))
    }

    func testInvalidTypeWarnsWithoutCrashing() async throws {
        let summary = try await makeSummary(rows: [
            remotePrice(type: "WHOLESALE")
        ])

        XCTAssertEqual(summary.totalFetched, 1)
        XCTAssertEqual(summary.invalidTypeCount, 1)
        XCTAssertTrue(summary.samples.isEmpty)
        XCTAssertFalse(summary.truncated)
    }

    func testInvalidEffectiveAtWarnsWithoutCrashing() async throws {
        let summary = try await makeSummary(rows: [
            remotePrice(effectiveAt: "not-a-date")
        ])

        XCTAssertEqual(summary.totalFetched, 1)
        XCTAssertEqual(summary.invalidEffectiveAtCount, 1)
        XCTAssertTrue(summary.samples.isEmpty)
        XCTAssertFalse(summary.truncated)
    }

    func testOrphanProductIDIsReported() async throws {
        let productID = uuid(222)
        let summary = try await makeSummary(
            rows: [remotePrice(productID: productID)],
            lookup: [:]
        )

        XCTAssertEqual(summary.orphanCount, 1)
        XCTAssertEqual(summary.samples.first?.productID, productID)
        XCTAssertEqual(summary.samples.first?.isOrphan, true)
    }

    func testLocalProductWithoutRemoteIDIsExcludedFromLookup() {
        let linkedID = uuid(333)
        let lookup = ProductPricePreviewLocalLookupBuilder.makeLookup([
            ProductPricePreviewLocalProduct(
                remoteID: nil,
                barcode: "LOCAL-ONLY",
                itemNumber: nil,
                productName: "Local only",
                secondProductName: nil
            ),
            ProductPricePreviewLocalProduct(
                remoteID: linkedID,
                barcode: "LINKED",
                itemNumber: nil,
                productName: "Linked product with a display name that should be shortened",
                secondProductName: nil
            )
        ])

        XCTAssertEqual(Set(lookup.keys), [linkedID])
        XCTAssertTrue(lookup[linkedID]?.hasSuffix("...") == true)
    }

    func testTwoPagesWithoutDuplicatesCountsRows() async throws {
        let rows = [
            remotePrice(id: uuid(401), productID: uuid(501), type: "PURCHASE"),
            remotePrice(id: uuid(402), productID: uuid(502), type: "RETAIL"),
            remotePrice(id: uuid(403), productID: uuid(503), type: "PURCHASE")
        ]
        let summary = try await makeSummary(
            rows: rows,
            options: ProductPricePreviewOptions(pageSize: 2, maxRows: 10, maxPages: 5)
        )

        XCTAssertEqual(summary.totalFetched, 3)
        XCTAssertEqual(summary.pagesFetched, 2)
        XCTAssertEqual(summary.samples.count, 3)
        XCTAssertEqual(summary.stoppedReason, .partialPage)
        XCTAssertFalse(summary.truncated)
    }

    func testDefensiveDedupeAcrossPagesKeepsSingleSample() async throws {
        let productID = uuid(601)
        let rows = [
            remotePrice(id: uuid(701), productID: productID, type: "PURCHASE", price: 1.0),
            remotePrice(id: uuid(702), productID: productID, type: "purchase", price: 2.0)
        ]
        let summary = try await makeSummary(
            rows: rows,
            options: ProductPricePreviewOptions(pageSize: 1, maxRows: 10, maxPages: 5)
        )

        XCTAssertEqual(summary.totalFetched, 2)
        XCTAssertEqual(summary.samples.count, 1)
        XCTAssertEqual(summary.orphanCount, 1)
        XCTAssertEqual(summary.stoppedReason, .pageEmpty)
        XCTAssertFalse(summary.truncated)
    }

    func testMaxRowsCapsPreviewAndMarksTruncated() async throws {
        let rows = (0..<5).map { index in
            remotePrice(id: uuid(800 + index), productID: uuid(900 + index))
        }

        let summary = try await makeSummary(
            rows: rows,
            options: ProductPricePreviewOptions(pageSize: 2, maxRows: 3, maxPages: 5)
        )

        XCTAssertEqual(summary.totalFetched, 3)
        XCTAssertEqual(summary.pagesFetched, 2)
        XCTAssertEqual(summary.stoppedReason, .maxRows)
        XCTAssertTrue(summary.truncated)
    }

    func testFetcherCannotPushPreviewPastMaxRows() async throws {
        let rows = (0..<10).map { index in
            remotePrice(id: uuid(850 + index), productID: uuid(950 + index))
        }
        let fetcher = MockProductPricePreviewFetching(rows: rows, ignoresRequestedRange: true)
        let service = SupabaseProductPricePreviewService(
            fetcher: fetcher,
            options: ProductPricePreviewOptions(pageSize: 3, maxRows: 5, maxPages: 5)
        )

        let summary = try await service.loadPreview(productLookup: [:])

        XCTAssertEqual(summary.totalFetched, 5)
        XCTAssertLessThanOrEqual(summary.samples.count, 5)
        XCTAssertEqual(summary.stoppedReason, .maxRows)
        XCTAssertTrue(summary.truncated)
    }

    func testMaxPagesCapsPreviewAndMarksTruncated() async throws {
        let rows = (0..<8).map { index in
            remotePrice(id: uuid(1_000 + index), productID: uuid(1_100 + index))
        }

        let summary = try await makeSummary(
            rows: rows,
            options: ProductPricePreviewOptions(pageSize: 2, maxRows: 10, maxPages: 2)
        )

        XCTAssertEqual(summary.totalFetched, 4)
        XCTAssertEqual(summary.pagesFetched, 2)
        XCTAssertEqual(summary.stoppedReason, .maxPages)
        XCTAssertTrue(summary.truncated)
    }

    func testEmptyFinalPageStopsWithoutTruncation() async throws {
        let rows = [
            remotePrice(id: uuid(1_201), productID: uuid(1_301)),
            remotePrice(id: uuid(1_202), productID: uuid(1_302))
        ]

        let summary = try await makeSummary(
            rows: rows,
            options: ProductPricePreviewOptions(pageSize: 1, maxRows: 10, maxPages: 5)
        )

        XCTAssertEqual(summary.totalFetched, 2)
        XCTAssertEqual(summary.pagesFetched, 3)
        XCTAssertEqual(summary.stoppedReason, .pageEmpty)
        XCTAssertFalse(summary.truncated)
    }

    func testPartialPageStopsWithoutTruncation() async throws {
        let rows = [
            remotePrice(id: uuid(1_401), productID: uuid(1_501)),
            remotePrice(id: uuid(1_402), productID: uuid(1_502)),
            remotePrice(id: uuid(1_403), productID: uuid(1_503))
        ]

        let summary = try await makeSummary(
            rows: rows,
            options: ProductPricePreviewOptions(pageSize: 2, maxRows: 10, maxPages: 5)
        )

        XCTAssertEqual(summary.totalFetched, 3)
        XCTAssertEqual(summary.pagesFetched, 2)
        XCTAssertEqual(summary.stoppedReason, .partialPage)
        XCTAssertFalse(summary.truncated)
    }

    func testCancellationReturnsPartialCancelledSummaryWithoutSideEffects() async throws {
        let rows = [
            remotePrice(id: uuid(1_601), productID: uuid(1_701)),
            remotePrice(id: uuid(1_602), productID: uuid(1_702)),
            remotePrice(id: uuid(1_603), productID: uuid(1_703))
        ]
        let fetcher = MockProductPricePreviewFetching(rows: rows, cancellationCall: 2)
        let service = SupabaseProductPricePreviewService(
            fetcher: fetcher,
            options: ProductPricePreviewOptions(pageSize: 2, maxRows: 10, maxPages: 5)
        )

        let summary = try await service.loadPreview(productLookup: [:])

        XCTAssertEqual(summary.totalFetched, 2)
        XCTAssertEqual(summary.pagesFetched, 1)
        XCTAssertEqual(summary.stoppedReason, .cancelled)
        XCTAssertFalse(summary.truncated)
        XCTAssertEqual(summary.samples.count, 2)
    }

    func testErrorAfterFetchedPageReturnsPartialErrorSummary() async throws {
        let rows = [
            remotePrice(id: uuid(1_801), productID: uuid(1_901)),
            remotePrice(id: uuid(1_802), productID: uuid(1_902)),
            remotePrice(id: uuid(1_803), productID: uuid(1_903))
        ]
        let fetcher = MockProductPricePreviewFetching(rows: rows, errorCall: 2)
        let service = SupabaseProductPricePreviewService(
            fetcher: fetcher,
            options: ProductPricePreviewOptions(pageSize: 2, maxRows: 10, maxPages: 5)
        )

        let summary = try await service.loadPreview(productLookup: [:])

        XCTAssertEqual(summary.totalFetched, 2)
        XCTAssertEqual(summary.pagesFetched, 1)
        XCTAssertEqual(summary.stoppedReason, .error)
        XCTAssertFalse(summary.truncated)
        XCTAssertEqual(summary.samples.count, 2)
        XCTAssertNotNil(summary.diagnosticDetail)
    }

    func testPreviewUsesInclusiveRangesWithoutOffByOne() async throws {
        let rows = (0..<8).map { index in
            remotePrice(id: uuid(2_000 + index), productID: uuid(2_100 + index))
        }
        let fetcher = MockProductPricePreviewFetching(rows: rows)
        let service = SupabaseProductPricePreviewService(
            fetcher: fetcher,
            options: ProductPricePreviewOptions(pageSize: 3, maxRows: 5, maxPages: 5)
        )

        let summary = try await service.loadPreview(productLookup: [:])
        let ranges = await fetcher.recordedRanges()

        XCTAssertEqual(ranges.map { "\($0.from)-\($0.to)" }, ["0-2", "3-4"])
        XCTAssertEqual(summary.totalFetched, 5)
        XCTAssertEqual(summary.stoppedReason, .maxRows)
    }

    func testDefaultAndHardSampleLimits() async throws {
        let rows = (0..<30).map { index in
            remotePrice(id: uuid(2_200 + index), productID: uuid(2_300 + index))
        }

        let defaultSummary = try await makeSummary(
            rows: rows,
            options: ProductPricePreviewOptions(pageSize: 30, maxRows: 30, maxPages: 2)
        )
        let cappedSummary = try await makeSummary(
            rows: rows,
            options: ProductPricePreviewOptions(pageSize: 30, maxRows: 30, maxPages: 2, sampleLimit: 99)
        )

        XCTAssertEqual(defaultSummary.samples.count, 15)
        XCTAssertEqual(cappedSummary.samples.count, 20)
    }

    func testPreviewFetchOrderContractIsStableForPagedPrices() {
        XCTAssertEqual(
            SupabaseInventoryService.productPriceStablePageOrderColumns,
            ["product_id", "type", "effective_at", "id"]
        )
    }

    func testPreviewSourceHasNoSyncEventOrProductPriceWritePath() throws {
        let previewSource = try source(named: "SupabaseProductPricePreviewService.swift")
        let optionsSource = try source(named: "OptionsView.swift")
        let inventorySource = try source(named: "SupabaseInventoryService.swift")

        let remoteEventFunctionName = ["record", "sync", "event"].joined(separator: "_")
        let remoteEventTableName = ["sync", "events"].joined(separator: "_")
        XCTAssertFalse(previewSource.contains(remoteEventFunctionName))
        XCTAssertFalse(previewSource.contains(remoteEventTableName))
        XCTAssertFalse(optionsSource.contains(remoteEventFunctionName))
        XCTAssertFalse(optionsSource.contains(remoteEventTableName))
        XCTAssertFalse(previewSource.contains("ProductPrice("))
        XCTAssertFalse(previewSource.contains("ModelContext.insert"))
        XCTAssertNil(previewSource.range(of: #"upsert|\.insert\(|\.update\(|\.delete\("#, options: .regularExpression))
        XCTAssertNil(
            inventorySource.range(
                of: #"inventory_product_prices"[\s\S]{0,300}(upsert|\.insert\(|\.update\(|\.delete\()"#,
                options: .regularExpression
            )
        )
    }

    private func makeSummary(
        rows: [RemoteInventoryProductPriceRow],
        lookup: [UUID: String] = [:],
        options: ProductPricePreviewOptions = ProductPricePreviewOptions(pageSize: 2, maxRows: 10, maxPages: 5)
    ) async throws -> ProductPricePreviewSummary {
        let service = SupabaseProductPricePreviewService(
            fetcher: MockProductPricePreviewFetching(rows: rows),
            options: options
        )
        return try await service.loadPreview(productLookup: lookup)
    }

    private func remotePrice(
        id: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
        productID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
        type: String = "PURCHASE",
        price: Double = 2.5,
        effectiveAt: String = "2026-05-01 10:30:00"
    ) -> RemoteInventoryProductPriceRow {
        RemoteInventoryProductPriceRow(
            id: id,
            ownerUserID: ownerID,
            productID: productID,
            type: type,
            price: price,
            effectiveAt: effectiveAt,
            source: "TEST",
            note: "private note",
            createdAt: "2026-05-01 10:31:00"
        )
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", value))")!
    }

    private func source(named fileName: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = testsDirectory
            .appendingPathComponent("iOSMerchandiseControl")
            .appendingPathComponent(fileName)
        return try String(contentsOf: url, encoding: .utf8)
    }
}

private actor MockProductPricePreviewFetching: SupabaseProductPricePreviewFetching {
    private let rows: [RemoteInventoryProductPriceRow]
    private let cancellationCall: Int?
    private let errorCall: Int?
    private let ignoresRequestedRange: Bool
    private var callCount = 0
    private var ranges: [(from: Int, to: Int)] = []

    init(
        rows: [RemoteInventoryProductPriceRow],
        cancellationCall: Int? = nil,
        errorCall: Int? = nil,
        ignoresRequestedRange: Bool = false
    ) {
        self.rows = rows
        self.cancellationCall = cancellationCall
        self.errorCall = errorCall
        self.ignoresRequestedRange = ignoresRequestedRange
    }

    func fetchProductPricesPreviewPage(from: Int, to: Int) async throws -> [RemoteInventoryProductPriceRow] {
        callCount += 1
        ranges.append((from, to))
        if cancellationCall == callCount {
            throw CancellationError()
        }
        if errorCall == callCount {
            throw SupabaseInventoryServiceError.networkError(statusCode: nil, message: "offline")
        }
        if ignoresRequestedRange {
            return rows
        }

        guard from < rows.count else { return [] }
        let upperBound = min(to + 1, rows.count)
        return Array(rows[from..<upperBound])
    }

    func recordedRanges() -> [(from: Int, to: Int)] {
        ranges
    }
}
