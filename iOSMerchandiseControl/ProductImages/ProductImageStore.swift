import Combine
import Foundation
import ImageIO
import UIKit

nonisolated private struct ProductImageDecodedImage: @unchecked Sendable {
    let image: UIImage
}

nonisolated private enum ProductImageDownsampler {
    static func decode(_ data: Data, variant: ProductImageVariant) async -> ProductImageDecodedImage? {
        let maximumPixelSize = variant == .thumb ? 384 : 1_600
        return await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                return nil
            }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                options as CFDictionary
            ) else {
                return nil
            }
            return ProductImageDecodedImage(image: UIImage(cgImage: image))
        }.value
    }
}

@MainActor
final class ProductImageStore: ObservableObject {
    @Published private(set) var revision = 0
    @Published private(set) var loadingReferences: Set<ProductImageReference> = []
    @Published private(set) var failedReferences: Set<ProductImageReference> = []
    @Published private(set) var operationStages: [UUID: ProductImageOperationStage] = [:]

    private let service: ProductImageService?
    private let memoryCache = NSCache<NSString, UIImage>()
    private var loadSources: [ProductImageReference: String] = [:]
    private var activeScope: ProductImageScope?
    private var generation = 0

    init(service: ProductImageService?) {
        self.service = service
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = 48 * 1_024 * 1_024
    }

    var isAvailable: Bool { service != nil }

    func activate(scope: ProductImageScope?) {
        guard activeScope != scope else { return }
        activeScope = scope
        generation &+= 1
        loadingReferences.removeAll()
        failedReferences.removeAll()
        operationStages.removeAll()
        revision &+= 1
    }

    func image(for reference: ProductImageReference) -> UIImage? {
        _ = revision
        guard activeScope == reference.scope else { return nil }
        return memoryCache.object(forKey: Self.memoryKey(reference) as NSString)
    }

    func isLoading(_ reference: ProductImageReference) -> Bool {
        loadingReferences.contains(reference)
    }

    func didFail(_ reference: ProductImageReference) -> Bool {
        failedReferences.contains(reference)
    }

    func source(for reference: ProductImageReference) -> String? {
        loadSources[reference]
    }

    func operationStage(productID: UUID) -> ProductImageOperationStage {
        operationStages[productID] ?? .idle
    }

    func load(_ reference: ProductImageReference) async {
        guard let service,
              activeScope == reference.scope,
              image(for: reference) == nil,
              !loadingReferences.contains(reference) else {
            return
        }
        let expectedGeneration = generation
        loadingReferences.insert(reference)
        failedReferences.remove(reference)
        defer {
            if generation == expectedGeneration {
                loadingReferences.remove(reference)
            }
        }

        do {
            let result = try await service.load(reference)
            guard generation == expectedGeneration,
                  activeScope == reference.scope else {
                return
            }
            guard let decoded = await ProductImageDownsampler.decode(
                result.data,
                variant: reference.variant
            ) else {
                throw ProductImageError.downloadedImageInvalid
            }
            store(decoded.image, for: reference, source: result.source)
        } catch {
            guard generation == expectedGeneration, activeScope == reference.scope else { return }
            failedReferences.insert(reference)
        }
    }

    func upload(
        fileURL: URL,
        scope: ProductImageScope,
        productID: UUID,
        previousVersionID: UUID?
    ) async throws -> ProductImageUploadResult {
        guard let service else { throw ProductImageError.unavailable }
        guard activeScope == scope else { throw ProductImageError.invalidScope }
        let expectedGeneration = generation
        operationStages[productID] = .processing

        do {
            let prepared = try await ProductImageProcessor.prepare(fileURL: fileURL)
            guard generation == expectedGeneration, activeScope == scope else {
                throw ProductImageError.accountChanged
            }
            operationStages[productID] = .uploading
            let result = try await service.upload(
                prepared: prepared,
                scope: scope,
                productID: productID
            )
            guard generation == expectedGeneration, activeScope == scope else {
                throw ProductImageError.accountChanged
            }
            if let previousVersionID {
                discard(
                    scope: scope,
                    productID: productID,
                    versionID: previousVersionID
                )
            }
            async let decodedMain = ProductImageDownsampler.decode(prepared.main.data, variant: .main)
            async let decodedThumb = ProductImageDownsampler.decode(prepared.thumb.data, variant: .thumb)
            let (main, thumb) = await (decodedMain, decodedThumb)
            if let main {
                store(
                    main.image,
                    for: ProductImageReference(
                        scope: scope,
                        productID: productID,
                        versionID: result.versionID,
                        variant: .main
                    ),
                    source: "local"
                )
            }
            if let thumb {
                store(
                    thumb.image,
                    for: ProductImageReference(
                        scope: scope,
                        productID: productID,
                        versionID: result.versionID,
                        variant: .thumb
                    ),
                    source: "local"
                )
            }
            operationStages[productID] = .idle
            return result
        } catch {
            if generation == expectedGeneration, activeScope == scope {
                operationStages[productID] = .failed
            }
            throw error
        }
    }

    func remove(
        scope: ProductImageScope,
        productID: UUID,
        versionID: UUID
    ) async throws -> ProductImageRemoveResult {
        guard let service else { throw ProductImageError.unavailable }
        guard activeScope == scope else { throw ProductImageError.invalidScope }
        let expectedGeneration = generation
        operationStages[productID] = .removing
        do {
            let result = try await service.remove(
                scope: scope,
                productID: productID,
                versionID: versionID
            )
            guard generation == expectedGeneration, activeScope == scope else {
                throw ProductImageError.accountChanged
            }
            discard(scope: scope, productID: productID, versionID: versionID)
            operationStages[productID] = .idle
            return result
        } catch {
            if generation == expectedGeneration, activeScope == scope {
                operationStages[productID] = .failed
            }
            throw error
        }
    }

    private func store(
        _ image: UIImage,
        for reference: ProductImageReference,
        source: String
    ) {
        let cost = max(1, Int(image.size.width * image.scale) * Int(image.size.height * image.scale) * 4)
        memoryCache.setObject(image, forKey: Self.memoryKey(reference) as NSString, cost: cost)
        loadSources[reference] = source
        failedReferences.remove(reference)
        revision &+= 1
    }

    private func discard(
        scope: ProductImageScope,
        productID: UUID,
        versionID: UUID
    ) {
        for variant in ProductImageVariant.allCases {
            let reference = ProductImageReference(
                scope: scope,
                productID: productID,
                versionID: versionID,
                variant: variant
            )
            memoryCache.removeObject(forKey: Self.memoryKey(reference) as NSString)
            loadSources.removeValue(forKey: reference)
            failedReferences.remove(reference)
            loadingReferences.remove(reference)
        }
        revision &+= 1
    }

    private static func memoryKey(_ reference: ProductImageReference) -> String {
        [
            ProductImageService.expectedCacheScope(accountID: reference.scope.accountID),
            reference.scope.shopID.uuidString.lowercased(),
            reference.productID.uuidString.lowercased(),
            reference.versionID.uuidString.lowercased(),
            reference.variant.rawValue
        ].joined(separator: "/")
    }
}
