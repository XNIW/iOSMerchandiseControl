import XCTest
@testable import iOSMerchandiseControl

final class ExcelAnalyzerHTMLParsingTests: XCTestCase {
    private func fixtureURL(_ name: String) throws -> URL {
        let bundle = Bundle(for: Self.self)
        if let url = bundle.url(
            forResource: name,
            withExtension: "html",
            subdirectory: "Fixtures/TASK-036"
        ) {
            return url
        }
        let flatURL = bundle.url(forResource: name, withExtension: "html")
        return try XCTUnwrap(flatURL, "Fixture \(name).html non trovata nel bundle test")
    }

    private func analyze(_ fixtureName: String) throws
        -> (originalHeader: [String], normalizedHeader: [String], dataRows: [[String]]) {
        try ExcelAnalyzer.readAndAnalyzeExcel(from: fixtureURL(fixtureName))
    }

    func testColspanHeaderKeepsColumnsAligned() throws {
        let result = try analyze("html-colspan-header")

        XCTAssertEqual(result.normalizedHeader, [
            "barcode", "productName", "purchasePrice", "quantity", "retailPrice"
        ])
        XCTAssertEqual(result.dataRows.count, 2)
        XCTAssertEqual(result.dataRows.first, [
            "800000000001", "Colspan header sample A", "2.5", "3", "5"
        ])
    }

    func testRowspanDataExpandsToRectangularRows() throws {
        let result = try analyze("html-rowspan-data")

        XCTAssertEqual(result.normalizedHeader, [
            "barcode", "productName", "purchasePrice", "quantity", "retailPrice", "category"
        ])
        XCTAssertEqual(result.dataRows.count, 2)
        XCTAssertTrue(result.dataRows.allSatisfy { $0.count == result.normalizedHeader.count })
        XCTAssertEqual(result.dataRows[1], [
            "800000000101", "Rowspan sample B", "1.4", "5", "2.8", "Shelf"
        ])
    }

    func testMultipleTablesSelectsDataTable() throws {
        let result = try analyze("html-multiple-tables")

        XCTAssertEqual(result.originalHeader, [
            "barcode", "productName", "purchasePrice", "quantity", "retailPrice"
        ])
        XCTAssertEqual(result.normalizedHeader, [
            "barcode", "productName", "purchasePrice", "quantity", "retailPrice"
        ])
        XCTAssertEqual(result.dataRows.count, 2)
        XCTAssertEqual(result.dataRows.first?[1], "Multiple table sample A")
    }

    func testTitleRowsBeforeHeaderAreIgnored() throws {
        let result = try analyze("html-title-rows-before-header")

        XCTAssertEqual(result.normalizedHeader, [
            "barcode", "productName", "purchasePrice", "quantity", "retailPrice"
        ])
        XCTAssertEqual(result.dataRows.count, 2)
        XCTAssertEqual(result.dataRows.first?[0], "800000000301")
    }

    func testDecorativeOnlyTableDoesNotInventCanonicalMapping() throws {
        let result = try analyze("html-negative-decorative-table-only")

        XCTAssertTrue(result.originalHeader.isEmpty)
        XCTAssertTrue(result.normalizedHeader.isEmpty)
        XCTAssertTrue(result.dataRows.isEmpty)
    }
}
