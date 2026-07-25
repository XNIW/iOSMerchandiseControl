import CoreGraphics
import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import iOSMerchandiseControl

final class ProductImageSharedContractTests: XCTestCase {
    @MainActor
    func testRuntimeConsumesSharedCompressionAndSyntheticVectors() throws {
        let contract = try json("product-image-v1.json")
        let limits = try XCTUnwrap(contract["limits"] as? [String: Any])
        XCTAssertEqual(try int(limits, "inputMaximumBytes"), ProductImageProcessor.maximumInputBytes)
        XCTAssertEqual(try int(limits, "inputMaximumPixels"), ProductImageProcessor.maximumInputPixels)
        XCTAssertEqual(try int(limits, "readBatchMaximum"), ProductImageAPIClient.readURLBatchMaximum)
        XCTAssertEqual(
            try int(limits, "readRequestConcurrency"),
            ProductImageService.defaultMaximumConcurrentReadRequests
        )
        XCTAssertEqual(
            try int(limits, "downloadConcurrency"),
            ProductImageService.defaultMaximumConcurrentDownloads
        )
        XCTAssertEqual(
            try int(limits, "signedURLSafetyWindowMilliseconds"),
            Int(ProductImageService.defaultSignedURLSafetyWindow * 1_000)
        )

        let compression = try XCTUnwrap(contract["compression"] as? [String: Any])
        let factors = try XCTUnwrap(compression["sideFactors"] as? [NSNumber]).map(\.doubleValue)
        XCTAssertEqual(factors, ProductImageProcessor.outputSideFactors)

        let main = try XCTUnwrap(compression["main"] as? [String: Any])
        XCTAssertEqual(try int(main, "maximumSide"), ProductImageProcessor.mainMaximumSide)
        XCTAssertEqual(try int(main, "minimumSide"), ProductImageProcessor.mainMinimumSide)
        XCTAssertEqual(try int(main, "targetBytes"), ProductImageProcessor.mainTargetBytes)
        XCTAssertEqual(try int(main, "hardMaximumBytes"), ProductImageProcessor.mainMaximumBytes)
        XCTAssertEqual(
            try XCTUnwrap(main["qualities"] as? [NSNumber]).map(\.doubleValue),
            ProductImageProcessor.mainQualities.map(Double.init)
        )
        let thumb = try XCTUnwrap(compression["thumb"] as? [String: Any])
        XCTAssertEqual(try int(thumb, "maximumSide"), ProductImageProcessor.thumbMaximumSide)
        XCTAssertEqual(try int(thumb, "minimumSide"), ProductImageProcessor.thumbMinimumSide)
        XCTAssertEqual(try int(thumb, "targetBytes"), ProductImageProcessor.thumbTargetBytes)
        XCTAssertEqual(try int(thumb, "hardMaximumBytes"), ProductImageProcessor.thumbMaximumBytes)
        XCTAssertEqual(
            try XCTUnwrap(thumb["qualities"] as? [NSNumber]).map(\.doubleValue),
            ProductImageProcessor.thumbQualities.map(Double.init)
        )

        let vectors = try json("fixtures/product-image-synthetic-v1.json")
        for vector in try XCTUnwrap(vectors["sideScheduleVectors"] as? [[String: Any]]) {
            let vectorID = try XCTUnwrap(vector["id"] as? String)
            XCTAssertEqual(
                ProductImageProcessor.outputSideSchedule(
                    sourceLongestSide: try int(vector, "sourceLongestSide"),
                    initialMaximum: try int(vector, "initialMaximum"),
                    minimum: try int(vector, "minimum")
                ),
                try XCTUnwrap(vector["expected"] as? [NSNumber]).map(\.intValue),
                vectorID
            )
        }
        let images = try XCTUnwrap(vectors["syntheticImages"] as? [[String: Any]])
        let camera = try XCTUnwrap(images.first { $0["id"] as? String == "camera-48mp" })
        XCTAssertEqual(try int(camera, "width") * int(camera, "height"), 48_000_000)

        let cache = try XCTUnwrap(contract["cache"] as? [String: Any])
        let platformBudgets = try XCTUnwrap(cache["platformBudgets"] as? [String: Any])
        let iosBudget = try XCTUnwrap(platformBudgets["ios"] as? [String: Any])
        XCTAssertEqual(try int(iosBudget, "memoryBytes"), ProductImageStore.memoryCostLimit)
        XCTAssertEqual(try int(iosBudget, "memoryEntries"), 100)
        XCTAssertEqual(try int(iosBudget, "diskBytes"), ProductImageCache.defaultMaximumDiskBytes)
        XCTAssertEqual(
            try int(iosBudget, "signedURLLeases"),
            ProductImageService.maximumSignedURLLeases
        )
    }

    func testCommonFixturesFreezeAPIDomainAndJPEGPolicy() throws {
        let valid = try json("fixtures/product-image-v1-valid.json")
        let intent = try XCTUnwrap(valid["intent"] as? [String: Any])
        let main = try XCTUnwrap(intent["main"] as? [String: Any])
        XCTAssertEqual(main["mimeType"] as? String, "image/jpeg")

        let invalid = try json("fixtures/product-image-v1-invalid.json")
        let jpegCases = try XCTUnwrap(invalid["jpegCases"] as? [[String: Any]])
        XCTAssertTrue(jpegCases.contains { $0["id"] as? String == "app13-photoshop" })
        XCTAssertTrue(ProductImageProcessor.containsForbiddenMetadata(
            jpegWithMetadata(marker: 0xed, payload: Array("8BIM".utf8))
        ))
        XCTAssertTrue(ProductImageProcessor.containsForbiddenMetadata(
            jpegWithMetadata(marker: 0xfe, payload: Array("note".utf8))
        ))
        var nonCanonicalJFIF = Array("JFIF".utf8) + [
            0x00, 0x01, 0x02, 0x03, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00
        ]
        XCTAssertEqual(nonCanonicalJFIF.count, 14)
        XCTAssertTrue(ProductImageProcessor.containsForbiddenMetadata(
            jpegWithMetadata(marker: 0xe0, payload: nonCanonicalJFIF)
        ))
        nonCanonicalJFIF[7] = 0x00
        XCTAssertFalse(ProductImageProcessor.containsForbiddenMetadata(
            jpegWithMetadata(marker: 0xe0, payload: nonCanonicalJFIF)
        ))

        let contract = try json("product-image-v1.json")
        let boundary = try XCTUnwrap(contract["domainBoundary"] as? [String: Any])
        let forbidden = try XCTUnwrap(boundary["forbidden"] as? [String])
        XCTAssertTrue(Set(["blob", "signedURL", "storagePath"]).isSubset(of: Set(forbidden)))
    }

    func testMultiScanJPEGRemovesForbiddenMarkersAndRejectsTrailingPayload() throws {
        let multiScan = jpegWithPostScanMetadata()

        XCTAssertTrue(ProductImageProcessor.containsForbiddenMetadata(multiScan))
        let canonical = try ProductImageProcessor.removingForbiddenMetadataSegments(multiScan)

        XCTAssertFalse(ProductImageProcessor.containsForbiddenMetadata(canonical))
        XCTAssertTrue(ProductImageProcessor.isJPEG(canonical))
        XCTAssertNil(canonical.range(of: Data([0xff, 0xfe])))
        XCTAssertNil(canonical.range(of: Data([0xff, 0xed])))
        XCTAssertNotNil(canonical.range(of: Data([0xff, 0x00])))
        XCTAssertNotNil(canonical.range(of: Data([0xff, 0xd0])))
        XCTAssertEqual(canonical.filter { $0 == 0xda }.count, 2)

        let trailing = canonical + Data([0x00])
        XCTAssertTrue(ProductImageProcessor.containsForbiddenMetadata(trailing))
        XCTAssertThrowsError(
            try ProductImageProcessor.removingForbiddenMetadataSegments(trailing)
        )
    }

    func testCanonicalErrorCodesMatchSharedContractAndMapEveryIOSError() throws {
        let contract = try json("product-image-v1.json")
        let errors = try XCTUnwrap(contract["errors"] as? [String])
        XCTAssertEqual(ProductImageCanonicalErrorCode.allCases.map(\.rawValue), errors)

        let mappings: [(ProductImageError, ProductImageCanonicalErrorCode)] = [
            (.unavailable, .requestFailed),
            (.invalidScope, .referenceInvalid),
            (.notFound, .referenceInvalid),
            (.unauthenticated, .sessionMissing),
            (.accountChanged, .accountChanged),
            (.inputEmpty, .inputSizeInvalid),
            (.inputTooLarge, .inputSizeInvalid),
            (.inputPixelLimitExceeded, .dimensionsInvalid),
            (.unsupportedFormat, .inputFormatUnsupported),
            (.animatedInput, .inputFormatUnsupported),
            (.decodeFailed, .decodeFailed),
            (.encodeFailed, .encodeFailed),
            (.outputTooLarge, .outputBudgetExceeded),
            (.metadataPresent, .metadataForbidden),
            (.invalidResponse, .readContractInvalid),
            (.requestFailed(status: 500), .requestFailed),
            (.signedURLInvalid, .signedURLInvalid),
            (.uploadFailed(status: 500), .uploadFailed),
            (.downloadFailed(status: 403), .downloadInvalid),
            (.downloadedImageInvalid, .downloadInvalid),
            (.offlineNotCached, .offlineNotCached),
            (.cacheFailure, .requestFailed)
        ]
        for (error, expected) in mappings {
            XCTAssertEqual(error.canonicalCode, expected)
        }
        XCTAssertEqual(
            ProductImageError.canonicalCode(for: CancellationError()),
            .operationCancelled
        )
    }

    @MainActor
    func testCameraFallbackCreatesOnlyBoundedCanonicalJPEG() throws {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 4_000,
            height: 3_000,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 4_000, height: 3_000))
        let source = try XCTUnwrap(context.makeImage())
        let bounded = try XCTUnwrap(
            ProductImageCameraPicker.Coordinator.boundedCameraImage(UIImage(cgImage: source))
        )
        XCTAssertLessThanOrEqual(max(bounded.width, bounded.height), 1_600)

        let url = try ProductImageProcessor.writeBoundedCameraFallback(bounded)
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        XCTAssertLessThanOrEqual(data.count, ProductImageProcessor.mainMaximumBytes)
        XCTAssertFalse(ProductImageProcessor.containsForbiddenMetadata(data))
        XCTAssertTrue(ProductImageProcessor.isJPEG(data))

        let sourceText = try String(
            contentsOf: repositoryRoot()
                .appendingPathComponent("iOSMerchandiseControl/ProductImages/ProductImageViews.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(sourceText.contains("jpegData(compressionQuality: 1)"))
    }

    private func json(_ relativePath: String) throws -> [String: Any] {
        let data = try Data(contentsOf: repositoryRoot()
            .appendingPathComponent("contracts/\(relativePath)"))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func int(_ object: [String: Any], _ key: String) throws -> Int {
        try XCTUnwrap(object[key] as? NSNumber).intValue
    }

    private func jpegWithMetadata(marker: UInt8, payload: [UInt8]) -> Data {
        let length = payload.count + 2
        return Data([
            0xff, 0xd8,
            0xff, marker, UInt8((length >> 8) & 0xff), UInt8(length & 0xff),
        ] + payload + [
            0xff, 0xc0, 0x00, 0x0b, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11, 0x00,
            0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3f, 0x00,
            0x00, 0xff, 0xd9,
        ])
    }

    private func jpegWithPostScanMetadata() -> Data {
        let scanHeader: [UInt8] = [
            0xff, 0xda, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3f, 0x00
        ]
        return Data(
            [0xff, 0xd8]
                + scanHeader
                + [0x11, 0xff, 0x00, 0x22, 0xff, 0xd0, 0x33]
                + [0xff, 0xfe, 0x00, 0x06] + Array("note".utf8)
                + scanHeader
                + [0x44, 0xff, 0x00, 0x55]
                + [0xff, 0xed, 0x00, 0x06] + Array("8BIM".utf8)
                + [0xff, 0xd9]
        )
    }
}
