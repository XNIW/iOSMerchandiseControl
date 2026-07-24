import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import iOSMerchandiseControl

final class ProductImageProcessorTests: XCTestCase {
    func testRotatedJPEGIsNormalizedBoundedAndMetadataFree() throws {
        let input = try makeFixture(
            width: 1_200,
            height: 600,
            type: .jpeg,
            orientation: 6
        )

        let prepared = try ProductImageProcessor.prepare(data: input)

        XCTAssertEqual(prepared.main.metadata.width, 600)
        XCTAssertEqual(prepared.main.metadata.height, 1_200)
        XCTAssertLessThanOrEqual(prepared.main.metadata.bytes, ProductImageProcessor.mainTargetBytes)
        XCTAssertLessThanOrEqual(prepared.thumb.metadata.bytes, ProductImageProcessor.thumbMaximumBytes)
        XCTAssertEqual(prepared.main.metadata.mimeType, "image/jpeg")
        XCTAssertEqual(prepared.thumb.metadata.mimeType, "image/jpeg")
        XCTAssertFalse(ProductImageProcessor.containsForbiddenMetadata(prepared.main.data))
        XCTAssertFalse(ProductImageProcessor.containsForbiddenMetadata(prepared.thumb.data))
        try attachMetrics(name: "rotated-jpeg", prepared: prepared)
    }

    func testTransparentPNGUsesWhiteBackgroundAndNeverUpscales() throws {
        let input = try makeFixture(
            width: 160,
            height: 100,
            type: .png,
            transparent: true
        )

        let prepared = try ProductImageProcessor.prepare(data: input)

        XCTAssertLessThanOrEqual(prepared.main.metadata.width, 160)
        XCTAssertLessThanOrEqual(prepared.main.metadata.height, 100)
        XCTAssertLessThanOrEqual(prepared.thumb.metadata.width, 160)
        XCTAssertLessThanOrEqual(prepared.thumb.metadata.height, 100)
        let image = try XCTUnwrap(CGImageSourceCreateWithData(prepared.main.data as CFData, nil))
        let cgImage = try XCTUnwrap(CGImageSourceCreateImageAtIndex(image, 0, nil))
        let pixel = try cornerPixel(cgImage)
        XCTAssertGreaterThanOrEqual(pixel[0], 245)
        XCTAssertGreaterThanOrEqual(pixel[1], 245)
        XCTAssertGreaterThanOrEqual(pixel[2], 245)
        try attachMetrics(name: "transparent-png", prepared: prepared)
    }

    func testHEICInputProducesDeterministicJPEGWithinBudgets() throws {
        let input: Data
        do {
            input = try makeFixture(width: 2_000, height: 1_200, type: .heic)
        } catch {
            throw XCTSkip("HEIC encoder unavailable on this Simulator runtime.")
        }

        let first = try ProductImageProcessor.prepare(data: input)
        let second = try ProductImageProcessor.prepare(data: input)

        XCTAssertTrue(ProductImageProcessor.isJPEG(first.main.data))
        XCTAssertTrue(ProductImageProcessor.isJPEG(first.thumb.data))
        XCTAssertLessThanOrEqual(max(first.main.metadata.width, first.main.metadata.height), 1_600)
        XCTAssertLessThanOrEqual(max(first.thumb.metadata.width, first.thumb.metadata.height), 384)
        XCTAssertLessThanOrEqual(first.main.metadata.bytes, ProductImageProcessor.mainTargetBytes)
        XCTAssertLessThanOrEqual(first.thumb.metadata.bytes, ProductImageProcessor.thumbMaximumBytes)
        XCTAssertEqual(first.main.metadata.sha256, second.main.metadata.sha256)
        XCTAssertEqual(first.thumb.metadata.sha256, second.thumb.metadata.sha256)
        try attachMetrics(name: "heic", prepared: first)
    }

    func testHighResolutionInputDownsamplesWithoutExceedingBudgets() throws {
        let input = try makeFixture(width: 5_000, height: 4_000, type: .jpeg, patterned: true)

        let prepared = try ProductImageProcessor.prepare(data: input)

        XCTAssertEqual(prepared.metrics.inputWidth, 5_000)
        XCTAssertEqual(prepared.metrics.inputHeight, 4_000)
        XCTAssertLessThanOrEqual(max(prepared.main.metadata.width, prepared.main.metadata.height), 1_600)
        XCTAssertLessThanOrEqual(max(prepared.thumb.metadata.width, prepared.thumb.metadata.height), 384)
        XCTAssertLessThanOrEqual(prepared.main.metadata.bytes, ProductImageProcessor.mainTargetBytes)
        XCTAssertLessThanOrEqual(prepared.thumb.metadata.bytes, ProductImageProcessor.thumbMaximumBytes)
        XCTAssertGreaterThanOrEqual(prepared.metrics.elapsedMilliseconds, 0)
        try attachMetrics(name: "high-resolution", prepared: prepared)
    }

    func testFortyEightMegapixelInputDownsamplesWithinFrozenBudgets() throws {
        let input = try makeFixture(width: 8_000, height: 6_000, type: .jpeg, patterned: true)

        let prepared = try ProductImageProcessor.prepare(data: input)

        XCTAssertEqual(prepared.metrics.inputWidth * prepared.metrics.inputHeight, 48_000_000)
        XCTAssertLessThanOrEqual(max(prepared.main.metadata.width, prepared.main.metadata.height), 1_600)
        XCTAssertLessThanOrEqual(max(prepared.thumb.metadata.width, prepared.thumb.metadata.height), 384)
        XCTAssertLessThanOrEqual(prepared.main.metadata.bytes, ProductImageProcessor.mainMaximumBytes)
        XCTAssertLessThanOrEqual(prepared.thumb.metadata.bytes, ProductImageProcessor.thumbMaximumBytes)
        XCTAssertFalse(ProductImageProcessor.containsForbiddenMetadata(prepared.main.data))
        XCTAssertFalse(ProductImageProcessor.containsForbiddenMetadata(prepared.thumb.data))
        try attachMetrics(name: "48-megapixel", prepared: prepared)
    }

    func testHighResolutionPreprocessPerformanceBaseline() throws {
        let input = try makeFixture(width: 5_000, height: 4_000, type: .jpeg, patterned: true)
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        var completedIterations = 0

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()], options: options) {
            do {
                let prepared = try ProductImageProcessor.prepare(data: input)
                XCTAssertEqual(prepared.metrics.inputWidth, 5_000)
                XCTAssertEqual(prepared.metrics.inputHeight, 4_000)
                XCTAssertLessThanOrEqual(
                    prepared.main.metadata.bytes,
                    ProductImageProcessor.mainMaximumBytes
                )
                XCTAssertLessThanOrEqual(
                    prepared.thumb.metadata.bytes,
                    ProductImageProcessor.thumbMaximumBytes
                )
                XCTAssertGreaterThan(prepared.main.metadata.bytes, 0)
                XCTAssertGreaterThan(prepared.thumb.metadata.bytes, 0)
                completedIterations += 1
            } catch {
                XCTFail("High-resolution preprocess failed: \(error)")
            }
        }
        // XCTest may execute one warm-up in addition to the measured samples.
        XCTAssertGreaterThanOrEqual(completedIterations, options.iterationCount)
    }

    func testOversizedAndUnsupportedInputsFailBeforeDecode() {
        XCTAssertThrowsError(
            try ProductImageProcessor.prepare(
                data: Data(repeating: 0xff, count: ProductImageProcessor.maximumInputBytes + 1)
            )
        ) { error in
            XCTAssertEqual(error as? ProductImageError, .inputTooLarge)
        }
        XCTAssertThrowsError(try ProductImageProcessor.prepare(data: Data("<svg/>".utf8))) { error in
            XCTAssertEqual(error as? ProductImageError, .unsupportedFormat)
        }
        XCTAssertThrowsError(try ProductImageProcessor.prepare(data: Data([0xff, 0xd8, 0xff, 0xd9]))) { error in
            XCTAssertEqual(error as? ProductImageError, .decodeFailed)
        }
    }

    private func makeFixture(
        width: Int,
        height: Int,
        type: UTType,
        orientation: Int? = nil,
        transparent: Bool = false,
        patterned: Bool = false
    ) throws -> Data {
        let alpha: CGImageAlphaInfo = transparent ? .premultipliedLast : .noneSkipLast
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: alpha.rawValue
        ))
        if transparent {
            context.clear(CGRect(x: 0, y: 0, width: width, height: height))
            context.setFillColor(CGColor(red: 0.8, green: 0.1, blue: 0.05, alpha: 1))
            context.fill(CGRect(x: width / 4, y: height / 4, width: width / 2, height: height / 2))
        } else {
            context.setFillColor(CGColor(red: 0.12, green: 0.45, blue: 0.78, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            if patterned {
                let cell = max(20, min(width, height) / 40)
                for y in stride(from: 0, to: height, by: cell) {
                    for x in stride(from: 0, to: width, by: cell) where ((x / cell) + (y / cell)).isMultiple(of: 2) {
                        context.setFillColor(CGColor(
                            red: CGFloat((x / cell) % 11) / 10,
                            green: CGFloat((y / cell) % 13) / 12,
                            blue: 0.35,
                            alpha: 1
                        ))
                        context.fill(CGRect(x: x, y: y, width: cell, height: cell))
                    }
                }
            }
        }
        let image = try XCTUnwrap(context.makeImage())
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
            output,
            type.identifier as CFString,
            1,
            nil
        ))
        var properties: [CFString: Any] = [:]
        if type == .jpeg || type == .heic {
            properties[kCGImageDestinationLossyCompressionQuality] = 0.9
        }
        if let orientation {
            properties[kCGImagePropertyOrientation] = orientation
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ProductImageError.encodeFailed
        }
        return output as Data
    }

    private func cornerPixel(_ image: CGImage) throws -> [UInt8] {
        let cropped = try XCTUnwrap(image.cropping(to: CGRect(x: 0, y: 0, width: 1, height: 1)))
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        var pixel = [UInt8](repeating: 0, count: 4)
        try pixel.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(
                data: bytes.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        return pixel
    }

    private func attachMetrics(name: String, prepared: PreparedProductImage) throws {
        let metrics: [String: Any] = [
            "fixture": name,
            "inputBytes": prepared.metrics.inputBytes,
            "inputWidth": prepared.metrics.inputWidth,
            "inputHeight": prepared.metrics.inputHeight,
            "downsampleMilliseconds": prepared.metrics.downsampleMilliseconds,
            "elapsedMilliseconds": prepared.metrics.elapsedMilliseconds,
            "mainBytes": prepared.metrics.mainBytes,
            "mainEncodeMilliseconds": prepared.metrics.mainEncodeMilliseconds,
            "mainWidth": prepared.metrics.mainWidth,
            "mainHeight": prepared.metrics.mainHeight,
            "thumbBytes": prepared.metrics.thumbBytes,
            "thumbEncodeMilliseconds": prepared.metrics.thumbEncodeMilliseconds,
            "thumbWidth": prepared.metrics.thumbWidth,
            "thumbHeight": prepared.metrics.thumbHeight
        ]
        let data = try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: UTType.json.identifier)
        attachment.name = "TASK-137-\(name)-metrics.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
