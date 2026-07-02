import XCTest
@testable import iOSMerchandiseControl

final class ExcelAnalyzerHTMLParsingTests: XCTestCase {
    private typealias AnalysisResult = (
        originalHeader: [String],
        normalizedHeader: [String],
        dataRows: [[String]]
    )

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
        -> AnalysisResult {
        try ExcelAnalyzer.readAndAnalyzeExcel(from: fixtureURL(fixtureName))
    }

    private func assertHeaderContains(
        _ header: [String],
        _ expectedValues: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for expected in expectedValues {
            XCTAssertTrue(
                header.contains(expected),
                "Header \(header) non contiene \(expected)",
                file: file,
                line: line
            )
        }
    }

    private func assertRowValue(
        _ rows: [[String]],
        header: [String],
        row rowIndex: Int,
        column: String,
        equals expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard rows.indices.contains(rowIndex) else {
            XCTFail("Riga \(rowIndex) non presente in \(rows)", file: file, line: line)
            return
        }
        guard let columnIndex = header.firstIndex(of: column) else {
            XCTFail("Colonna \(column) non presente in \(header)", file: file, line: line)
            return
        }
        guard rows[rowIndex].indices.contains(columnIndex) else {
            XCTFail(
                "Riga \(rowIndex) non contiene indice colonna \(columnIndex): \(rows[rowIndex])",
                file: file,
                line: line
            )
            return
        }

        XCTAssertEqual(rows[rowIndex][columnIndex], expected, file: file, line: line)
    }

    private func assertRowsAreRectangular(
        _ result: AnalysisResult,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            result.dataRows.allSatisfy { $0.count == result.normalizedHeader.count },
            "Le righe dati non sono allineate all'header \(result.normalizedHeader): \(result.dataRows)",
            file: file,
            line: line
        )
    }

    private func assertNoDecorativeRows(
        _ rows: [[String]],
        forbiddenValues: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let cells = rows.flatMap { $0 }
        for value in forbiddenValues {
            XCTAssertFalse(
                cells.contains { $0.localizedCaseInsensitiveContains(value) },
                "Valore decorativo inatteso \(value) trovato in \(rows)",
                file: file,
                line: line
            )
        }
    }

    func testNestedTableDoesNotContaminateMainTable() throws {
        let result = try analyze("html-nested-table")

        XCTAssertEqual(result.normalizedHeader, [
            "barcode", "productName", "purchasePrice", "quantity", "retailPrice"
        ])
        XCTAssertEqual(result.dataRows.count, 2)
        assertRowsAreRectangular(result)
        assertRowValue(
            result.dataRows,
            header: result.normalizedHeader,
            row: 0,
            column: "productName",
            equals: "Nested main sample A"
        )
        assertRowValue(
            result.dataRows,
            header: result.normalizedHeader,
            row: 1,
            column: "barcode",
            equals: "800000000402"
        )
        assertNoDecorativeRows(
            result.dataRows,
            forbiddenValues: [
                "Nested decorative barcode",
                "Nested decorative product",
                "999999999999"
            ]
        )
    }

    func testLoadFromMultipleHTMLFilesAggregatesRowsWithoutDuplicatingHeader() throws {
        let result = try ExcelAnalyzer.loadFromMultipleURLs([
            fixtureURL("html-append-inventory-a"),
            fixtureURL("html-append-inventory-b")
        ])

        let expectedHeader = [
            "barcode", "productName", "purchasePrice", "quantity", "retailPrice"
        ]
        XCTAssertEqual(result.normalizedHeader, expectedHeader)
        XCTAssertEqual(result.originalHeader, [
            "barcode", "product_name", "purchase_price", "quantity", "retail_price"
        ])
        XCTAssertEqual(result.rows.first, expectedHeader)
        XCTAssertEqual(result.rows.count, 5)
        XCTAssertEqual(result.rows.filter { $0 == expectedHeader }.count, 1)

        let dataRows = Array(result.rows.dropFirst())
        XCTAssertEqual(dataRows.count, 4)
        assertRowValue(
            dataRows,
            header: result.normalizedHeader,
            row: 3,
            column: "productName",
            equals: "Append sample D"
        )
        assertNoDecorativeRows(dataRows, forbiddenValues: expectedHeader)
    }

    func testMinimalHTMLWithoutRealHeaderUsesAndroidStylePatternPromotion() throws {
        let result = try analyze("html-minimal-no-header")

        XCTAssertEqual(result.originalHeader, ["col1", "col2", "col3", "col4", "col5"])
        XCTAssertEqual(result.normalizedHeader, [
            "barcode", "productName", "purchasePrice", "quantity", "totalPrice"
        ])
        XCTAssertEqual(result.dataRows.count, 2)
        assertRowsAreRectangular(result)
        assertRowValue(
            result.dataRows,
            header: result.normalizedHeader,
            row: 0,
            column: "barcode",
            equals: "800000000901"
        )
        assertRowValue(
            result.dataRows,
            header: result.normalizedHeader,
            row: 0,
            column: "productName",
            equals: "Minimal no header sample A"
        )
        assertRowValue(
            result.dataRows,
            header: result.normalizedHeader,
            row: 0,
            column: "purchasePrice",
            equals: "2.50"
        )
    }

    func testColspanHeaderKeepsColumnsAligned() throws {
        let result = try analyze("html-colspan-header")

        XCTAssertEqual(result.normalizedHeader, [
            "barcode", "productName", "purchasePrice", "quantity", "retailPrice"
        ])
        XCTAssertEqual(result.dataRows.count, 2)
        assertRowsAreRectangular(result)
        assertRowValue(
            result.dataRows,
            header: result.normalizedHeader,
            row: 0,
            column: "barcode",
            equals: "800000000001"
        )
        assertRowValue(
            result.dataRows,
            header: result.normalizedHeader,
            row: 1,
            column: "productName",
            equals: "Colspan header sample B"
        )
    }

    func testRowspanDataExpandsToRectangularRows() throws {
        let result = try analyze("html-rowspan-data")

        XCTAssertEqual(result.normalizedHeader, [
            "barcode", "productName", "purchasePrice", "quantity", "retailPrice", "category"
        ])
        XCTAssertEqual(result.dataRows.count, 2)
        assertRowsAreRectangular(result)
        assertRowValue(
            result.dataRows,
            header: result.normalizedHeader,
            row: 1,
            column: "barcode",
            equals: "800000000101"
        )
        assertRowValue(
            result.dataRows,
            header: result.normalizedHeader,
            row: 1,
            column: "productName",
            equals: "Rowspan sample B"
        )
        assertRowValue(
            result.dataRows,
            header: result.normalizedHeader,
            row: 1,
            column: "category",
            equals: "Shelf"
        )
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
        assertRowsAreRectangular(result)
        assertRowValue(
            result.dataRows,
            header: result.normalizedHeader,
            row: 0,
            column: "productName",
            equals: "Multiple table sample A"
        )
        assertNoDecorativeRows(
            result.dataRows,
            forbiddenValues: ["Report title", "Decorative metadata", "Footer notes"]
        )
    }

    func testTitleRowsBeforeHeaderAreIgnored() throws {
        let result = try analyze("html-title-rows-before-header")

        XCTAssertEqual(result.normalizedHeader, [
            "barcode", "productName", "purchasePrice", "quantity", "retailPrice"
        ])
        XCTAssertEqual(result.dataRows.count, 2)
        assertRowsAreRectangular(result)
        assertRowValue(
            result.dataRows,
            header: result.normalizedHeader,
            row: 0,
            column: "barcode",
            equals: "800000000301"
        )
        assertNoDecorativeRows(
            result.dataRows,
            forbiddenValues: ["Warehouse export", "Printed on 2026-04-27"]
        )
    }

    func testDecorativeOnlyTableDoesNotInventCanonicalMapping() throws {
        let result = try analyze("html-negative-decorative-table-only")

        XCTAssertTrue(result.originalHeader.isEmpty)
        XCTAssertTrue(result.normalizedHeader.isEmpty)
        XCTAssertTrue(result.dataRows.isEmpty)
    }

    func testRealisticAnonymizedMinimalReproKeepsLocalizedAliasesAligned() throws {
        let result = try analyze("html-realistic-anonymized-minimal")

        XCTAssertEqual(result.normalizedHeader, [
            "barcode",
            "productName",
            "purchasePrice",
            "quantity",
            "retailPrice",
            "category",
            "supplier"
        ])
        XCTAssertEqual(result.dataRows.count, 3)
        assertRowsAreRectangular(result)
        assertRowValue(
            result.dataRows,
            header: result.normalizedHeader,
            row: 2,
            column: "supplier",
            equals: "Supplier C"
        )
        assertRowValue(
            result.dataRows,
            header: result.normalizedHeader,
            row: 1,
            column: "category",
            equals: "Home"
        )
    }
}
