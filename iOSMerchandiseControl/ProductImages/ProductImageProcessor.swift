import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated enum ProductImageProcessor {
    static let maximumInputBytes = 25 * 1_024 * 1_024
    static let maximumInputPixels = 64_000_000
    static let mainMaximumSide = 1_600
    static let mainTargetBytes = 750 * 1_024
    static let mainMaximumBytes = 1_024 * 1_024
    static let thumbMaximumSide = 384
    static let thumbMaximumBytes = 90 * 1_024

    private static let mainQualities: [CGFloat] = [0.82, 0.76, 0.70]
    private static let thumbQualities: [CGFloat] = [0.75, 0.68, 0.60, 0.52]

    static func prepare(fileURL: URL) async throws -> PreparedProductImage {
        try await Task.detached(priority: .userInitiated) {
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
            return try prepare(data: data)
        }.value
    }

    static func prepare(data: Data) throws -> PreparedProductImage {
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

        let main = try makeVariant(
            source: source,
            sourceLongestSide: max(width, height),
            initialMaximumSide: mainMaximumSide,
            minimumSide: 640,
            qualities: mainQualities,
            targetBytes: mainTargetBytes,
            hardMaximumBytes: mainMaximumBytes
        )
        let thumb = try makeVariant(
            source: source,
            sourceLongestSide: max(width, height),
            initialMaximumSide: thumbMaximumSide,
            minimumSide: 128,
            qualities: thumbQualities,
            targetBytes: thumbMaximumBytes,
            hardMaximumBytes: thumbMaximumBytes
        )

        let elapsed = max(0, Int(Date().timeIntervalSince(startedAt) * 1_000))
        return PreparedProductImage(
            main: main,
            thumb: thumb,
            metrics: ProductImagePreprocessMetrics(
                elapsedMilliseconds: elapsed,
                inputBytes: data.count,
                inputHeight: height,
                inputWidth: width,
                mainBytes: main.metadata.bytes,
                mainHeight: main.metadata.height,
                mainWidth: main.metadata.width,
                thumbBytes: thumb.metadata.bytes,
                thumbHeight: thumb.metadata.height,
                thumbWidth: thumb.metadata.width
            )
        )
    }

    static func containsAPP1Metadata(_ data: Data) -> Bool {
        guard isJPEG(data), data.count >= 4 else { return false }
        var index = 2
        while index + 1 < data.count {
            guard data[index] == 0xff else {
                index += 1
                continue
            }
            while index < data.count, data[index] == 0xff {
                index += 1
            }
            guard index < data.count else { return false }
            let marker = data[index]
            index += 1
            if marker == 0xda || marker == 0xd9 { return false }
            if marker == 0xe1 { return true }
            if marker == 0x01 || (0xd0...0xd8).contains(marker) {
                continue
            }
            guard index + 1 < data.count else { return false }
            let segmentLength = Int(data[index]) << 8 | Int(data[index + 1])
            guard segmentLength >= 2, index + segmentLength <= data.count else {
                return false
            }
            index += segmentLength
        }
        return false
    }

    static func isJPEG(_ data: Data) -> Bool {
        data.count >= 4
            && data[0] == 0xff
            && data[1] == 0xd8
            && data[data.count - 2] == 0xff
            && data[data.count - 1] == 0xd9
    }

    private static func makeVariant(
        source: CGImageSource,
        sourceLongestSide: Int,
        initialMaximumSide: Int,
        minimumSide: Int,
        qualities: [CGFloat],
        targetBytes: Int,
        hardMaximumBytes: Int
    ) throws -> PreparedProductImageVariant {
        var maximumSide = min(initialMaximumSide, sourceLongestSide)
        var fallback: PreparedProductImageVariant?

        while maximumSide > 0 {
            let image = try normalizedImage(source: source, maximumSide: maximumSide)
            for quality in qualities {
                let encoded = try encodeJPEG(image, quality: quality)
                let variant = try validatedVariant(encoded)
                if variant.metadata.bytes <= hardMaximumBytes,
                   fallback == nil || variant.metadata.bytes < fallback!.metadata.bytes {
                    fallback = variant
                }
                if variant.metadata.bytes <= targetBytes {
                    return variant
                }
            }

            if maximumSide <= minimumSide || maximumSide >= sourceLongestSide && sourceLongestSide < minimumSide {
                break
            }
            let reduced = max(minimumSide, Int((Double(maximumSide) * 0.85).rounded(.down)))
            if reduced >= maximumSide { break }
            maximumSide = min(reduced, sourceLongestSide)
        }

        guard let fallback, fallback.metadata.bytes <= hardMaximumBytes else {
            throw ProductImageError.outputTooLarge
        }
        return fallback
    }

    private static func normalizedImage(
        source: CGImageSource,
        maximumSide: Int
    ) throws -> CGImage {
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
        return normalized
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
        let data = try removingAPP1Segments(output as Data)
        guard isJPEG(data) else {
            throw ProductImageError.encodeFailed
        }
        guard !containsAPP1Metadata(data) else {
            throw ProductImageError.metadataPresent
        }
        return data
    }

    private static func removingAPP1Segments(_ data: Data) throws -> Data {
        guard isJPEG(data) else { throw ProductImageError.encodeFailed }
        var output = Data(data.prefix(2))
        var index = 2

        while index < data.count {
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
                output.append(contentsOf: data[markerStart..<index])
                guard index == data.count else { throw ProductImageError.encodeFailed }
                return output
            }
            if marker == 0xd8 || marker == 0x01 || (0xd0...0xd7).contains(marker) {
                output.append(contentsOf: data[markerStart..<index])
                continue
            }
            guard index + 1 < data.count else { throw ProductImageError.encodeFailed }
            let segmentLength = Int(data[index]) << 8 | Int(data[index + 1])
            guard segmentLength >= 2, index + segmentLength <= data.count else {
                throw ProductImageError.encodeFailed
            }
            let segmentEnd = index + segmentLength
            if marker != 0xe1 {
                output.append(contentsOf: data[markerStart..<segmentEnd])
            }
            index = segmentEnd

            if marker == 0xda {
                output.append(contentsOf: data[index...])
                return output
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
