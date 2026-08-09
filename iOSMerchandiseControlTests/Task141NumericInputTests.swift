import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class Task141NumericInputTests: XCTestCase {
    func testOptionalPriceInputDistinguishesIntentionalClearFromInvalidInput() {
        XCTAssertEqual(parseOptionalCLPriceInput("  \n"), .empty)
        XCTAssertEqual(parseOptionalCLPriceInput("abc"), .invalid)
        XCTAssertEqual(parseOptionalCLPriceInput("1..2"), .invalid)
        XCTAssertEqual(parseOptionalCLPriceInput("NaN"), .invalid)
        XCTAssertEqual(parseOptionalCLPriceInput("Infinity"), .invalid)
        XCTAssertEqual(parseOptionalCLPriceInput("-1"), .negative)
    }

    func testOptionalPriceInputAcceptsSupportedChileAndPastedFormats() throws {
        XCTAssertEqual(
            try XCTUnwrap(parseOptionalCLPriceInput("47.100").value),
            47_100,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(parseOptionalCLPriceInput("1.234,5").value),
            1_234.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(parseOptionalCLPriceInput("1,234.5").value),
            1_234.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(parseOptionalCLPriceInput("1234.567").value),
            1_234.567,
            accuracy: 0.0001
        )
    }

    func testOptionalQuantityInputAcceptsDecimalAndRejectsMalformedOrNegative() throws {
        XCTAssertEqual(
            try XCTUnwrap(parseOptionalCLQuantityInput("1,5").value),
            1.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(parseOptionalCLQuantityInput("1.234,5").value),
            1_234.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(parseOptionalCLQuantityInput("1,2,3"), .invalid)
        XCTAssertEqual(parseOptionalCLQuantityInput("-0,5"), .negative)
    }

    func testQuantityKeepsChileCommaDecimalMeaningAtThreeFractionDigits() throws {
        for (rawValue, expected) in [
            ("1,234", 1.234),
            ("12,345", 12.345),
            ("999,999", 999.999),
            ("1.234", 1.234)
        ] {
            XCTAssertEqual(
                try XCTUnwrap(parseOptionalCLQuantityInput(rawValue).value),
                expected,
                accuracy: 0.0001,
                rawValue
            )
        }
    }

    func testPriceAndQuantityUseExplicitPoliciesForAmbiguousSingleSeparator() throws {
        XCTAssertEqual(
            try XCTUnwrap(parseOptionalCLPriceInput("1,234").value),
            1_234,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(parseOptionalCLQuantityInput("1,234").value),
            1.234,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(parseOptionalCLQuantityInput("1.234,567").value),
            1_234.567,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(parseOptionalCLQuantityInput("1,234.567").value),
            1_234.567,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(parseOptionalCLPriceInput("1.234,567").value),
            1_234.567,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(parseOptionalCLPriceInput("1,234.567").value),
            1_234.567,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(parseOptionalCLPriceInput("1.234.567").value),
            1_234_567,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(parseOptionalCLPriceInput("1,234,567").value),
            1_234_567,
            accuracy: 0.0001
        )
    }

    func testInternalWhitespaceIsRejectedInsteadOfConcatenated() throws {
        for malformed in ["1 2", "1\n2", "1\t2", "1 23 4"] {
            XCTAssertEqual(parseOptionalCLQuantityInput(malformed), .invalid, malformed)
            XCTAssertEqual(parseOptionalCLPriceInput(malformed), .invalid, malformed)
        }

        XCTAssertEqual(
            try XCTUnwrap(parseOptionalCLQuantityInput(" 1,5 ").value),
            1.5,
            accuracy: 0.0001
        )
    }
}
