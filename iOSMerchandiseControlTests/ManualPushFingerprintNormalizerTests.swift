import XCTest
@testable import iOSMerchandiseControl

final class ManualPushFingerprintNormalizerTests: XCTestCase {
    func testTrimStringsBeforeFingerprinting() {
        let trimmed = ManualPushFingerprintNormalizer.product(
            barcode: " 123 ",
            itemNumber: " SKU-1 ",
            productName: "\nProduct ",
            secondProductName: nil,
            purchasePrice: 1.23,
            retailPrice: 2,
            stockQuantity: 3,
            supplierRemoteID: nil,
            categoryRemoteID: nil
        )
        let clean = ManualPushFingerprintNormalizer.product(
            barcode: "123",
            itemNumber: "SKU-1",
            productName: "Product",
            secondProductName: nil,
            purchasePrice: 1.2300,
            retailPrice: 2.0,
            stockQuantity: 3.000000,
            supplierRemoteID: nil,
            categoryRemoteID: nil
        )

        XCTAssertEqual(trimmed, clean)
        XCTAssertTrue(trimmed.canonicalString.contains("barcode=string:123"))
        XCTAssertTrue(trimmed.canonicalString.contains("productName=string:Product"))
    }

    func testNilAndEmptyStringsAreExplicitAndStable() {
        let nilName = ManualPushFingerprintNormalizer.supplier(name: nil)
        let emptyName = ManualPushFingerprintNormalizer.supplier(name: "   ")

        XCTAssertNotEqual(nilName, emptyName)
        XCTAssertTrue(nilName.canonicalString.contains("name=string:nil"))
        XCTAssertTrue(emptyName.canonicalString.contains("name=string:empty"))
    }

    func testProductFieldOrderIsDeterministic() {
        let supplierID = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
        let categoryID = UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!
        let fingerprint = ManualPushFingerprintNormalizer.product(
            barcode: "123",
            itemNumber: "SKU",
            productName: "Name",
            secondProductName: nil,
            purchasePrice: 1.5,
            retailPrice: 2,
            stockQuantity: 3,
            supplierRemoteID: supplierID,
            categoryRemoteID: categoryID
        )

        XCTAssertEqual(
            fingerprint.canonicalString,
            "v1|product|barcode=string:123|itemNumber=string:SKU|productName=string:Name|secondProductName=string:nil|purchasePrice=number:1.5|retailPrice=number:2|stockQuantity=number:3|supplierRemoteID=uuid:00000000-0000-0000-0000-0000000000aa|categoryRemoteID=uuid:00000000-0000-0000-0000-0000000000bb"
        )
    }

    func testUUIDUsesCanonicalLowercaseString() {
        let supplierID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let fingerprint = ManualPushFingerprintNormalizer.product(
            barcode: "123",
            itemNumber: nil,
            productName: nil,
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            stockQuantity: nil,
            supplierRemoteID: supplierID,
            categoryRemoteID: nil
        )

        XCTAssertTrue(fingerprint.canonicalString.contains("supplierRemoteID=uuid:aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"))
    }

    func testProductFingerprintUsesSupplierAndCategoryRemoteIDs() {
        let supplierA = UUID()
        let supplierB = UUID()
        let categoryID = UUID()
        let first = ManualPushFingerprintNormalizer.product(
            barcode: "123",
            itemNumber: nil,
            productName: "Same",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            stockQuantity: nil,
            supplierRemoteID: supplierA,
            categoryRemoteID: categoryID
        )
        let second = ManualPushFingerprintNormalizer.product(
            barcode: "123",
            itemNumber: nil,
            productName: "Same",
            secondProductName: nil,
            purchasePrice: nil,
            retailPrice: nil,
            stockQuantity: nil,
            supplierRemoteID: supplierB,
            categoryRemoteID: categoryID
        )

        XCTAssertNotEqual(first, second)
    }

    func testNumberNormalizationIsStable() {
        let first = ManualPushFingerprintNormalizer.product(
            barcode: "123",
            itemNumber: nil,
            productName: nil,
            secondProductName: nil,
            purchasePrice: 1.230000,
            retailPrice: 2.0,
            stockQuantity: 0.0000001,
            supplierRemoteID: nil,
            categoryRemoteID: nil
        )
        let second = ManualPushFingerprintNormalizer.product(
            barcode: "123",
            itemNumber: nil,
            productName: nil,
            secondProductName: nil,
            purchasePrice: 1.23,
            retailPrice: 2,
            stockQuantity: 0,
            supplierRemoteID: nil,
            categoryRemoteID: nil
        )

        XCTAssertEqual(first, second)
        XCTAssertTrue(first.canonicalString.contains("purchasePrice=number:1.23"))
        XCTAssertTrue(first.canonicalString.contains("retailPrice=number:2"))
        XCTAssertTrue(first.canonicalString.contains("stockQuantity=number:0"))
    }
}
