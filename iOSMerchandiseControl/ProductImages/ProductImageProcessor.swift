import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum ProductImageProcessor {
    static let maximumInputBytes = 25 * 1_024 * 1_024
    static let maximumInputPixels = 64_000_000
    static let mainMaximumSide = 1_600
    static let mainMinimumSide = 640
    static let mainTargetBytes = 750 * 1_024
    static let mainMaximumBytes = 1_024 * 1_024
    static let thumbMaximumSide = 384
    static let thumbMinimumSide = 128
    static let thumbTargetBytes = 90 * 1_024
    static let thumbMaximumBytes = 90 * 1_024

    static let outputSideFactors: [Double] = [1.0, 0.85, 0.72, 0.61, 0.52, 0.44, 0.4]
    static let mainQualities: [CGFloat] = [0.82, 0.76, 0.70]
    static let thumbQualities: [CGFloat] = [0.75, 0.68, 0.60, 0.52]

    static func prepare(fileURL: URL) async throws -> PreparedProductImage {
        let task = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true else {
                throw ProductImageError.inputEmpty
            }
            guard let fileSize = values.fileSize, fileSize > 0 else {
                throw ProductImageError.inputEmpty
            }
            guard fileSize <= maximumInputBytes else {
                throw ProductImageError.inputTooLarge
            }
            let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
            try Task.checkCancellation()
            return try prepare(data: data)
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    static func prepare(data: Data) throws -> PreparedProductImage {
        try Task.checkCancellation()
        let startedAt = Date()
        guard !data.isEmpty else {
            throw ProductImageError.inputEmpty
        }
        guard data.count <= maximumInputBytes else {
            throw ProductImageError.inputTooLarge
        }
        guard sniffedFormat(data) != nil else {
            throw ProductImageError.unsupportedFormat
        }

        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions),
              CGImageSourceGetCount(source) > 0 else {
            throw ProductImageError.decodeFailed
        }
        guard CGImageSourceGetCount(source) == 1 else {
            throw ProductImageError.animatedInput
        }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0,
              height > 0 else {
            throw ProductImageError.decodeFailed
        }
        guard height <= maximumInputPixels / width else {
            throw ProductImageError.inputPixelLimitExceeded
        }
        try Task.checkCancellation()

        let downsampleStartedAt = Date()
        let normalizedMain = try autoreleasepool {
            try normalizedImage(source: source, maximumSide: mainMaximumSide)
        }
        let downsampleMilliseconds = milliseconds(since: downsampleStartedAt)

        let mainStartedAt = Date()
        let main = try makeVariant(
            normalizedImage: normalizedMain,
            minimumSide: mainMinimumSide,
            qualities: mainQualities,
            targetBytes: mainTargetBytes,
            hardMaximumBytes: mainMaximumBytes
        )
        let mainEncodeMilliseconds = milliseconds(since: mainStartedAt)

        // The original source is never decoded again: the preview is derived from
        // the already oriented, sRGB, alpha-flattened main bitmap.
        let thumbStartedAt = Date()
        let normalizedThumb = try autoreleasepool {
            try resizedImage(normalizedMain, maximumSide: thumbMaximumSide)
        }
        let thumb = try makeVariant(
            normalizedImage: normalizedThumb,
            minimumSide: thumbMinimumSide,
            qualities: thumbQualities,
            targetBytes: thumbTargetBytes,
            hardMaximumBytes: thumbMaximumBytes
        )
        let thumbEncodeMilliseconds = milliseconds(since: thumbStartedAt)
        try Task.checkCancellation()

        let elapsed = max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))
        return PreparedProductImage(
            main: main,
            thumb: thumb,
            metrics: ProductImagePreprocessMetrics(
                downsampleMilliseconds: downsampleMilliseconds,
                elapsedMilliseconds: elapsed,
                inputBytes: data.count,
                inputHeight: height,
                inputWidth: width,
                mainBytes: main.metadata.bytes,
                mainEncodeMilliseconds: mainEncodeMilliseconds,
                mainHeight: main.metadata.height,
                mainWidth: main.metadata.width,
                thumbBytes: thumb.metadata.bytes,
                thumbEncodeMilliseconds: thumbEncodeMilliseconds,
                thumbHeight: thumb.metadata.height,
                thumbWidth: thumb.metadata.width
            )
        )
    }

    static func containsForbiddenMetadata(_ data: Data) -> Bool {
        guard isJPEG(data) else { return true }
        var output: Data?
        do {
            return try inspectJPEG(data, canonicalOutput: &output)
        } catch {
            return true
        }
    }

    static func isJPEG(_ data: Data) -> Bool {
        data.count >= 4
            && data[0] == 0xff
            && data[1] == 0xd8
            && data[data.count - 2] == 0xff
            && data[data.count - 1] == 0xd9
    }

    static func validateDownloadedJPEG(
        _ data: Data,
        variant: ProductImageVariant,
        expectedMetadata: ProductImageMetadata? = nil
    ) async throws {
        try Task.checkCancellation()
        let maximumSide = variant == .thumb ? thumbMaximumSide : mainMaximumSide
        let task = Task.detached(priority: .utility) {
            try Task.checkCancellation()
            guard isJPEG(data),
                  !containsForbiddenMetadata(data),
                  let source = CGImageSourceCreateWithData(
                    data as CFData,
                    [kCGImageSourceShouldCache: false] as CFDictionary
                  ),
                  CGImageSourceGetCount(source) == 1,
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
                  let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
                  width > 0,
                  height > 0,
                  max(width, height) <= maximumSide else {
                throw ProductImageError.downloadedImageInvalid
            }
            if let expectedMetadata {
                let digest = SHA256.hash(data: data)
                    .map { String(format: "%02x", $0) }
                    .joined()
                guard expectedMetadata.isValid(for: variant),
                      expectedMetadata.bytes == data.count,
                      expectedMetadata.width == width,
                      expectedMetadata.height == height,
                      expectedMetadata.sha256 == digest else {
                    throw ProductImageError.downloadedImageInvalid
                }
            }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumSide
            ]
            guard CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) != nil else {
                throw ProductImageError.downloadedImageInvalid
            }
            try Task.checkCancellation()
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func makeVariant(
        normalizedImage: CGImage,
        minimumSide: Int,
        qualities: [CGFloat],
        targetBytes: Int,
        hardMaximumBytes: Int
    ) throws -> PreparedProductImageVariant {
        let sourceLongestSide = max(normalizedImage.width, normalizedImage.height)
        var fallback: PreparedProductImageVariant?

        for maximumSide in outputSideSchedule(
            sourceLongestSide: sourceLongestSide,
            initialMaximum: sourceLongestSide,
            minimum: minimumSide
        ) {
            try Task.checkCancellation()
            let image = try autoreleasepool {
                try resizedImage(normalizedImage, maximumSide: maximumSide)
            }
            for quality in qualities {
                try Task.checkCancellation()
                let variant = try autoreleasepool {
                    let encoded = try encodeJPEG(image, quality: quality)
                    return try validatedVariant(encoded)
                }
                if variant.metadata.bytes <= hardMaximumBytes,
                   fallback == nil || variant.metadata.bytes < fallback!.metadata.bytes {
                    fallback = variant
                }
                if variant.metadata.bytes <= targetBytes {
                    return variant
                }
            }
        }

        guard let fallback, fallback.metadata.bytes <= hardMaximumBytes else {
            throw ProductImageError.outputTooLarge
        }
        return fallback
    }

    static func outputSideSchedule(
        sourceLongestSide: Int,
        initialMaximum: Int,
        minimum: Int
    ) -> [Int] {
        let maximum = min(initialMaximum, sourceLongestSide)
        guard maximum > minimum, sourceLongestSide >= minimum else { return [maximum] }
        var seen = Set<Int>()
        return (outputSideFactors.map { factor in
            max(minimum, Int((Double(maximum) * factor).rounded(.down)))
        } + [minimum]).filter { side in
            side <= maximum && seen.insert(side).inserted
        }
    }

    static func writeBoundedCameraFallback(_ image: CGImage) throws -> URL {
        guard image.width > 0, image.height > 0,
              image.height <= maximumInputPixels / image.width,
              max(image.width, image.height) <= mainMaximumSide else {
            throw ProductImageError.inputPixelLimitExceeded
        }
        let variant = try makeVariant(
            normalizedImage: image,
            minimumSide: mainMinimumSide,
            qualities: mainQualities,
            targetBytes: mainTargetBytes,
            hardMaximumBytes: mainMaximumBytes
        )
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("task139-camera-\(UUID().uuidString.lowercased()).jpg")
        do {
            try variant.data.write(to: destination, options: [.atomic])
            try Task.checkCancellation()
            return destination
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    private static func normalizedImage(
        source: CGImageSource,
        maximumSide: Int
    ) throws -> CGImage {
        try Task.checkCancellation()
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumSide
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: thumbnail.width,
                height: thumbnail.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw ProductImageError.decodeFailed
        }

        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: thumbnail.width, height: thumbnail.height))
        context.interpolationQuality = .high
        context.draw(thumbnail, in: CGRect(x: 0, y: 0, width: thumbnail.width, height: thumbnail.height))
        guard let normalized = context.makeImage() else {
            throw ProductImageError.decodeFailed
        }
        try Task.checkCancellation()
        return normalized
    }

    private static func resizedImage(
        _ image: CGImage,
        maximumSide: Int
    ) throws -> CGImage {
        try Task.checkCancellation()
        let longestSide = max(image.width, image.height)
        guard longestSide > 0, maximumSide > 0 else {
            throw ProductImageError.decodeFailed
        }
        if longestSide <= maximumSide {
            return image
        }
        let scale = CGFloat(maximumSide) / CGFloat(longestSide)
        let width = max(1, Int((CGFloat(image.width) * scale).rounded()))
        let height = max(1, Int((CGFloat(image.height) * scale).rounded()))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            throw ProductImageError.decodeFailed
        }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let resized = context.makeImage() else {
            throw ProductImageError.decodeFailed
        }
        try Task.checkCancellation()
        return resized
    }

    private static func milliseconds(since start: Date) -> Int {
        max(0, Int(Date().timeIntervalSince(start) * 1_000))
    }

    private static func encodeJPEG(_ image: CGImage, quality: CGFloat) throws -> Data {
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ProductImageError.encodeFailed
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw ProductImageError.encodeFailed
        }
        let data = try removingForbiddenMetadataSegments(output as Data)
        guard isJPEG(data) else {
            throw ProductImageError.encodeFailed
        }
        guard !containsForbiddenMetadata(data) else {
            throw ProductImageError.metadataPresent
        }
        return data
    }

    static func removingForbiddenMetadataSegments(_ data: Data) throws -> Data {
        var output: Data? = Data()
        _ = try inspectJPEG(data, canonicalOutput: &output)
        guard let output else { throw ProductImageError.encodeFailed }
        return output
    }

    private static func inspectJPEG(
        _ data: Data,
        canonicalOutput: inout Data?
    ) throws -> Bool {
        guard data.count >= 4, data[0] == 0xff, data[1] == 0xd8 else {
            throw ProductImageError.encodeFailed
        }
        if canonicalOutput != nil {
            canonicalOutput = Data(data.prefix(2))
        }
        var containsForbidden = false
        var index = 2
        var insideScan = false

        while index < data.count {
            if insideScan {
                let entropyStart = index
                while index < data.count {
                    guard data[index] == 0xff else {
                        index += 1
                        continue
                    }
                    guard index + 1 < data.count else {
                        throw ProductImageError.encodeFailed
                    }
                    let next = data[index + 1]
                    if next == 0x00 || (0xd0...0xd7).contains(next) {
                        index += 2
                        continue
                    }
                    if next == 0xff {
                        index += 1
                        continue
                    }
                    break
                }
                guard index < data.count else { throw ProductImageError.encodeFailed }
                if canonicalOutput != nil {
                    canonicalOutput!.append(contentsOf: data[entropyStart..<index])
                }
                insideScan = false
                continue
            }

            let markerStart = index
            guard data[index] == 0xff else {
                throw ProductImageError.encodeFailed
            }
            while index < data.count, data[index] == 0xff {
                index += 1
            }
            guard index < data.count else { throw ProductImageError.encodeFailed }
            let marker = data[index]
            index += 1

            if marker == 0xd9 {
                if canonicalOutput != nil {
                    canonicalOutput!.append(contentsOf: data[markerStart..<index])
                }
                guard index == data.count else { throw ProductImageError.encodeFailed }
                return containsForbidden
            }
            if marker == 0x01 {
                if canonicalOutput != nil {
                    canonicalOutput!.append(contentsOf: data[markerStart..<index])
                }
                continue
            }
            guard marker != 0x00,
                  marker != 0xd8,
                  !(0xd0...0xd7).contains(marker) else {
                throw ProductImageError.encodeFailed
            }
            guard index + 1 < data.count else { throw ProductImageError.encodeFailed }
            let segmentLength = Int(data[index]) << 8 | Int(data[index + 1])
            guard segmentLength >= 2, index + segmentLength <= data.count else {
                throw ProductImageError.encodeFailed
            }
            let segmentEnd = index + segmentLength
            let dataStart = index + 2
            let dataLength = segmentLength - 2
            let isJFIF = marker == 0xe0 && dataLength == 14 &&
                data[dataStart] == 0x4a && data[dataStart + 1] == 0x46 &&
                data[dataStart + 2] == 0x49 && data[dataStart + 3] == 0x46 &&
                data[dataStart + 4] == 0x00 &&
                data[dataStart + 5] == 0x01 &&
                data[dataStart + 7] <= 0x02 &&
                data[dataStart + 12] == 0x00 &&
                data[dataStart + 13] == 0x00
            let forbidden = marker == 0xfe ||
                (marker == 0xe0 && !isJFIF) ||
                (0xe1...0xef).contains(marker)
            containsForbidden = containsForbidden || forbidden
            if !forbidden, canonicalOutput != nil {
                canonicalOutput!.append(contentsOf: data[markerStart..<segmentEnd])
            }
            index = segmentEnd

            if marker == 0xda {
                insideScan = true
            }
        }
        throw ProductImageError.encodeFailed
    }

    private static func validatedVariant(_ data: Data) throws -> PreparedProductImageVariant {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
              width > 0,
              height > 0 else {
            throw ProductImageError.encodeFailed
        }
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return PreparedProductImageVariant(
            data: data,
            metadata: ProductImageMetadata(
                bytes: data.count,
                height: height,
                sha256: digest,
                width: width
            )
        )
    }

    private static func sniffedFormat(_ data: Data) -> String? {
        if data.count >= 3, data[0] == 0xff, data[1] == 0xd8, data[2] == 0xff {
            return "jpeg"
        }
        let png: [UInt8] = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
        if data.count >= png.count, Array(data.prefix(png.count)) == png {
            return "png"
        }
        guard data.count >= 12,
              String(data: data[4..<8], encoding: .ascii) == "ftyp" else {
            return nil
        }
        let acceptedBrands: Set<String> = ["heic", "heix", "hevc", "hevx", "heim", "heis", "mif1", "msf1"]
        let boxLength = min(data.count, Int(data[0]) << 24 | Int(data[1]) << 16 | Int(data[2]) << 8 | Int(data[3]))
        guard boxLength >= 12 else { return nil }
        var offset = 8
        while offset + 4 <= boxLength {
            if let brand = String(data: data[offset..<(offset + 4)], encoding: .ascii),
               acceptedBrands.contains(brand) {
                return "heif"
            }
            offset += 4
        }
        return nil
    }
}
