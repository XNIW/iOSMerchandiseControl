import CryptoKit
import Foundation
import XCTest
@testable import iOSMerchandiseControl

final class CatalogTextPolicyTests: XCTestCase {
    private struct GoldenFixture: Decodable {
        let policyVersion: String
        let lengthUnit: String
        let limits: Limits
        let displayCases: [TextCase]
        let strictCases: [TextCase]
        let encodingCases: [EncodingCase]
        let collisionCases: [CollisionCase]
        let invariants: Invariants
    }

    private struct Limits: Decodable {
        let productName: Int
        let secondProductName: Int
        let supplierName: Int
        let categoryName: Int
        let barcode: Int
        let itemNumber: Int
    }

    private struct TextCase: Decodable {
        struct InputGenerator: Decodable {
            let kind: String
            let value: String
            let count: Int
        }

        let id: String
        let input: String?
        let inputGenerator: InputGenerator?
        let required: Bool
        let maxLength: Int
        let expectedStatus: String
        let expectedValue: String?
        let expectedChanges: [String]?
        let expectedReason: String?

        var generatedInput: String {
            if let input {
                return input
            }
            guard let inputGenerator, inputGenerator.kind == "repeat" else {
                return ""
            }
            return String(repeating: inputGenerator.value, count: inputGenerator.count)
        }
    }

    private struct EncodingCase: Decodable {
        let id: String
        let textClass: String
        let inputEncoding: String
        let inputCodeUnitsHex: [String]?
        let inputBytesHex: String?
        let required: Bool
        let maxLength: Int
        let expectedStatus: String
        let expectedReason: String

        private enum CodingKeys: String, CodingKey {
            case id
            case textClass = "class"
            case inputEncoding
            case inputCodeUnitsHex
            case inputBytesHex
            case required
            case maxLength
            case expectedStatus
            case expectedReason
        }
    }

    private struct CollisionCase: Decodable {
        let id: String
        let inputs: [String]
        let expectedStatus: String
        let expectedReason: String
    }

    private struct Invariants: Decodable {
        let assertDisplayIdempotency: Bool
        let assertStrictIdempotency: Bool
        let normalizationForm: String
        let forbidCompatibilityNormalization: Bool
        let preserveDisplayZWJ: Bool
        let rejectDisplayLineAndParagraphSeparators: Bool
    }

    func testGoldenFixtureDigestAndContractMetadata() throws {
        let data = try fixtureData()
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(
            digest,
            "139d63eedea47b54bb63a9289bef5fc6f7372668f209aac7753b586da7ccd9f8"
        )

        let fixture = try decodeFixture(data)
        XCTAssertEqual(fixture.policyVersion, CatalogTextPolicy.version)
        XCTAssertEqual(fixture.lengthUnit, "utf16_code_units_after_nfc")
        XCTAssertEqual(fixture.limits.productName, CatalogTextField.productName.maximumUTF16Length)
        XCTAssertEqual(
            fixture.limits.secondProductName,
            CatalogTextField.secondProductName.maximumUTF16Length
        )
        XCTAssertEqual(fixture.limits.supplierName, CatalogTextField.supplierName.maximumUTF16Length)
        XCTAssertEqual(fixture.limits.categoryName, CatalogTextField.categoryName.maximumUTF16Length)
        XCTAssertEqual(fixture.limits.barcode, CatalogTextField.barcode.maximumUTF16Length)
        XCTAssertEqual(fixture.limits.itemNumber, CatalogTextField.itemNumber.maximumUTF16Length)
        XCTAssertEqual(fixture.invariants.normalizationForm, "NFC")
        XCTAssertTrue(fixture.invariants.forbidCompatibilityNormalization)
        XCTAssertTrue(fixture.invariants.preserveDisplayZWJ)
        XCTAssertTrue(fixture.invariants.rejectDisplayLineAndParagraphSeparators)
    }

    func testEveryGoldenDisplayCase() throws {
        let fixture = try decodeFixture(fixtureData())
        for testCase in fixture.displayCases {
            let outcome = CatalogTextPolicy.display(
                testCase.generatedInput,
                required: testCase.required,
                maximumUTF16Length: testCase.maxLength
            )
            assert(
                outcome,
                matchesStatus: testCase.expectedStatus,
                value: testCase.expectedValue,
                changes: testCase.expectedChanges,
                reason: testCase.expectedReason,
                id: testCase.id
            )

            if fixture.invariants.assertDisplayIdempotency, let value = outcome.value {
                XCTAssertEqual(
                    CatalogTextPolicy.display(
                        value,
                        required: testCase.required,
                        maximumUTF16Length: testCase.maxLength
                    ),
                    .unchanged(value),
                    testCase.id
                )
            }
        }
    }

    func testEveryGoldenStrictCase() throws {
        let fixture = try decodeFixture(fixtureData())
        for testCase in fixture.strictCases {
            let outcome = CatalogTextPolicy.strict(
                testCase.generatedInput,
                required: testCase.required,
                maximumUTF16Length: testCase.maxLength
            )
            assert(
                outcome,
                matchesStatus: testCase.expectedStatus,
                value: testCase.expectedValue,
                changes: testCase.expectedChanges,
                reason: testCase.expectedReason,
                id: testCase.id
            )

            if fixture.invariants.assertStrictIdempotency, let value = outcome.value {
                XCTAssertEqual(
                    CatalogTextPolicy.strict(
                        value,
                        required: testCase.required,
                        maximumUTF16Length: testCase.maxLength
                    ),
                    .unchanged(value),
                    testCase.id
                )
            }
        }
    }

    func testEveryGoldenEncodingCase() throws {
        let fixture = try decodeFixture(fixtureData())
        for testCase in fixture.encodingCases {
            let outcome: CatalogTextOutcome
            switch testCase.inputEncoding {
            case "utf16_code_units":
                let units = try XCTUnwrap(testCase.inputCodeUnitsHex).map {
                    try XCTUnwrap(UInt16($0, radix: 16))
                }
                if testCase.textClass == "display" {
                    outcome = CatalogTextPolicy.display(
                        utf16CodeUnits: units,
                        required: testCase.required,
                        maximumUTF16Length: testCase.maxLength
                    )
                } else {
                    outcome = CatalogTextPolicy.strict(
                        utf16CodeUnits: units,
                        required: testCase.required,
                        maximumUTF16Length: testCase.maxLength
                    )
                }
            case "utf8_bytes":
                let data = try data(fromHex: XCTUnwrap(testCase.inputBytesHex))
                if testCase.textClass == "display" {
                    outcome = CatalogTextPolicy.display(
                        utf8Bytes: data,
                        required: testCase.required,
                        maximumUTF16Length: testCase.maxLength
                    )
                } else {
                    outcome = CatalogTextPolicy.strict(
                        utf8Bytes: data,
                        required: testCase.required,
                        maximumUTF16Length: testCase.maxLength
                    )
                }
            default:
                XCTFail("Encoding fixture non supportato: \(testCase.inputEncoding)")
                continue
            }

            assert(
                outcome,
                matchesStatus: testCase.expectedStatus,
                value: nil,
                changes: nil,
                reason: testCase.expectedReason,
                id: testCase.id
            )
        }
    }

    func testEveryGoldenCollisionCase() throws {
        let fixture = try decodeFixture(fixtureData())
        for testCase in fixture.collisionCases {
            let outcome = CatalogTextPolicy.strictIdentitySet(
                testCase.inputs,
                required: true,
                maximumUTF16Length: fixture.limits.itemNumber
            )
            assert(
                outcome,
                matchesStatus: testCase.expectedStatus,
                value: nil,
                changes: nil,
                reason: testCase.expectedReason,
                id: testCase.id
            )
        }
    }

    func testDisplayPreservesCompatibilityCharactersAndEmojiZWJ() {
        XCTAssertEqual(
            CatalogTextPolicy.display(
                "ＡＢＣ 👩‍💻",
                required: true,
                maximumUTF16Length: 240
            ),
            .unchanged("ＡＢＣ 👩‍💻")
        )
    }

    func testUTF16LimitCountsSurrogatePairsAsTwoUnits() {
        XCTAssertEqual("😀".utf16.count, 2)
        XCTAssertEqual(
            CatalogTextPolicy.display(
                String(repeating: "😀", count: 120),
                required: true,
                maximumUTF16Length: 240
            ),
            .unchanged(String(repeating: "😀", count: 120))
        )
        XCTAssertEqual(
            CatalogTextPolicy.display(
                String(repeating: "😀", count: 121),
                required: true,
                maximumUTF16Length: 240
            ),
            .rejected(.tooLong)
        )
    }

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: Self.self)
        if let url = bundle.url(
            forResource: "catalog-text-policy-v1",
            withExtension: "json",
            subdirectory: "Fixtures/CATALOG-TEXT-001"
        ) {
            return try Data(contentsOf: url)
        }
        let flatURL = bundle.url(
            forResource: "catalog-text-policy-v1",
            withExtension: "json"
        )
        return try Data(contentsOf: XCTUnwrap(flatURL, "Fixture golden non trovata"))
    }

    private func decodeFixture(_ data: Data) throws -> GoldenFixture {
        try JSONDecoder().decode(GoldenFixture.self, from: data)
    }

    private func data(fromHex value: String) throws -> Data {
        XCTAssertEqual(value.count % 2, 0)
        var result = Data()
        var index = value.startIndex
        while index < value.endIndex {
            let next = value.index(index, offsetBy: 2)
            result.append(try XCTUnwrap(UInt8(value[index..<next], radix: 16)))
            index = next
        }
        return result
    }

    private func assert(
        _ outcome: CatalogTextOutcome,
        matchesStatus expectedStatus: String,
        value expectedValue: String?,
        changes expectedChanges: [String]?,
        reason expectedReason: String?,
        id: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        switch outcome {
        case let .unchanged(value):
            XCTAssertEqual(expectedStatus, "unchanged", id, file: file, line: line)
            XCTAssertEqual(value, expectedValue, id, file: file, line: line)
        case let .normalized(value, changes):
            XCTAssertEqual(expectedStatus, "normalized", id, file: file, line: line)
            XCTAssertEqual(value, expectedValue, id, file: file, line: line)
            XCTAssertEqual(
                changes.map(\.rawValue),
                expectedChanges ?? [],
                id,
                file: file,
                line: line
            )
        case let .rejected(reason):
            XCTAssertEqual(expectedStatus, "rejected", id, file: file, line: line)
            XCTAssertEqual(reason.rawValue, expectedReason, id, file: file, line: line)
        }
    }
}
