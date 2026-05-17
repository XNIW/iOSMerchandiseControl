import XCTest
@testable import iOSMerchandiseControl

final class OrderQuantitySummaryTests: XCTestCase {
    func testTotalQuantitySumsIntegerQuantities() throws {
        let grid = [
            ["barcode", "productName", "quantity"],
            ["10000001", "A", "2"],
            ["10000002", "B", "3"]
        ]

        let totalQuantity = try XCTUnwrap(HistoryEntryRuntimeSummary.totalQuantity(from: grid))
        XCTAssertEqual(totalQuantity, 5, accuracy: 0.0001)
    }

    func testTotalQuantitySumsDecimalQuantities() throws {
        let grid = [
            ["barcode", "productName", "quantity"],
            ["10000001", "A", "1,5"],
            ["10000002", "B", "2.5"]
        ]

        let totalQuantity = try XCTUnwrap(HistoryEntryRuntimeSummary.totalQuantity(from: grid))
        XCTAssertEqual(totalQuantity, 4, accuracy: 0.0001)
    }

    func testTotalQuantityAcceptsCLGroupedIntegerQuantities() throws {
        let grid = [
            ["barcode", "productName", "quantity"],
            ["10000001", "A", "1.914"],
            ["10000002", "B", "1,234"]
        ]

        let totalQuantity = try XCTUnwrap(HistoryEntryRuntimeSummary.totalQuantity(from: grid))
        XCTAssertEqual(totalQuantity, 3148, accuracy: 0.0001)
    }

    func testTotalQuantityIgnoresNonParsableValues() throws {
        let grid = [
            ["barcode", "productName", "quantity"],
            ["10000001", "A", "bad"],
            ["10000002", "B", "4"]
        ]

        let totalQuantity = try XCTUnwrap(HistoryEntryRuntimeSummary.totalQuantity(from: grid))
        XCTAssertEqual(totalQuantity, 4, accuracy: 0.0001)
    }

    func testTotalQuantityReturnsNilWhenQuantityHeaderIsMissing() {
        let grid = [
            ["barcode", "productName"],
            ["10000001", "A"]
        ]

        XCTAssertNil(HistoryEntryRuntimeSummary.totalQuantity(from: grid))
    }

    func testTotalQuantityIgnoresBarcodeAndItemNumberValues() {
        let grid = [
            ["barcode", "itemNumber", "productName", "quantity"],
            ["6988888075607", "075607", "A", ""],
            ["6988235529791", "529791", "B", "bad"]
        ]

        XCTAssertNil(HistoryEntryRuntimeSummary.totalQuantity(from: grid))
    }

    func testQuantityFormatterUsesGroupedQuantityWithoutCurrency() {
        XCTAssertEqual(formatCLQuantity(1914), "1.914")
        XCTAssertEqual(formatCLQuantity(12.5), "12,5")
        XCTAssertEqual(formatCLQuantity(nil), "—")
    }
}
