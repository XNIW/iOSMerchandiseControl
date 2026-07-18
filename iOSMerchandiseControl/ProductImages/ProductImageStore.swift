import Combine
import Foundation
import ImageIO
import UIKit

nonisolated private struct ProductImageDecodedImage: @unchecked Sendable {
    let image: UIImage
}

nonisolated private enum ProductImageDownsampler {
    static func decode(_ data: Data, variant: ProductImageVariant) async throws -> ProductImageDecodedImage? {
        let maximumPixelSize = variant == .thumb ? 384 : 1_600
        let task = Task.detached(priority: .userInitiated) { () throws -> ProductImageDecodedImage? in
            try autoreleasepool {
                try Task.checkCancellation()
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
                try Task.checkCancellation()
                return ProductImageDecodedImage(image: UIImage(cgImage: image))
            }
        }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }
}

@MainActor
final class ProductImageStore: ObservableObject {
    private static let maximumTrackedReferences = 100
    static let memoryCostLimit = 48 * 1_024 * 1_024

    private struct InFlightLoad {
        let task: Task<Void, Never>
        var waiterIDs: Set<UUID>
    }

    @Published private(set) var revision = 0
    @Published private(set) var loadingReferences: Set<ProductImageReference> = []
    @Published private(set) var failedReferences: Set<ProductImageReference> = []
    @Published private(set) var operationStages: [UUID: ProductImageOperationStage] = [:]

    private let service: ProductImageService?
    private let memoryCache = NSCache<NSString, UIImage>()
    private var memoryCosts: [ProductImageReference: Int] = [:]
    private var totalMemoryCost = 0
    private var memoryWarningCancellable: AnyCancellable?
    private var loadSources: [ProductImageReference: String] = [:]
    private var cachedReferenceOrder: [ProductImageReference] = []
    private var failedReferenceOrder: [ProductImageReference] = []
    private var inFlightLoads: [ProductImageReference: InFlightLoad] = [:]
    private var activeScope: ProductImageScope?
    private var generation = 0

    init(service: ProductImageService?) {
        self.service = service
        memoryCache.countLimit = Self.maximumTrackedReferences
        memoryCache.totalCostLimit = Self.memoryCostLimit
        memoryWarningCancellable = NotificationCenter.default.publisher(
            for: UIApplication.didReceiveMemoryWarningNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            Task { @MainActor in
                self?.purgeMemoryCache()
            }
        }
    }

    var isAvailable: Bool { service != nil }

    func activate(scope: ProductImageScope?) {
        guard activeScope != scope else { return }
        let previousScope = activeScope
        activeScope = scope
        generation &+= 1
        for load in inFlightLoads.values {
            load.task.cancel()
        }
        inFlightLoads.removeAll()
        purgeMemoryCache(incrementRevision: false)
        failedReferenceOrder.removeAll()
        loadingReferences.removeAll()
        failedReferences.removeAll()
        operationStages.removeAll()
        revision &+= 1
        if let previousScope, let service {
            let purgeAccountScope = scope == nil || scope?.accountID != previousScope.accountID
            Task {
                await service.deactivate(
                    scope: previousScope,
                    purgeAccountScope: purgeAccountScope
                )
            }
        }
    }

    func image(for reference: ProductImageReference) -> UIImage? {
        _ = revision
        guard activeScope == reference.scope else { return nil }
        guard let image = memoryCache.object(forKey: Self.memoryKey(reference) as NSString) else {
            removeCachedMetadata(reference)
            return nil
        }
        return image
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

    var cachedImageCostBytes: Int { totalMemoryCost }
    var cachedImageCount: Int { memoryCosts.count }

    #if DEBUG
    func seedTask138VisualFixture(
        scope: ProductImageScope,
        images: [ProductImageReference: UIImage],
        loading: Set<ProductImageReference> = [],
        failures: Set<ProductImageReference> = [],
        source: String = "fixture"
    ) {
        activate(scope: scope)
        for (reference, image) in images where reference.scope == scope {
            store(image, for: reference, source: source)
        }
        loadingReferences.formUnion(loading.filter { $0.scope == scope })
        for reference in failures where reference.scope == scope {
            recordFailure(reference)
        }
        revision &+= 1
    }
    #endif

    func load(_ reference: ProductImageReference) async {
        guard let service,
              activeScope == reference.scope,
              image(for: reference) == nil else {
            return
        }

        let waiterID = UUID()
        let task: Task<Void, Never>
        if var existing = inFlightLoads[reference] {
            existing.waiterIDs.insert(waiterID)
            task = existing.task
            inFlightLoads[reference] = existing
        } else {
            let expectedGeneration = generation
            loadingReferences.insert(reference)
            removeFailure(reference)
            task = Task { [weak self] in
                guard let self else { return }
                await self.performLoad(
                    reference,
                    service: service,
                    expectedGeneration: expectedGeneration
                )
            }
            inFlightLoads[reference] = InFlightLoad(
                task: task,
                waiterIDs: [waiterID]
            )
        }

        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.releaseLoadWaiter(
                    reference: reference,
                    waiterID: waiterID,
                    cancelTaskWhenEmpty: true
                )
            }
        }
        releaseLoadWaiter(
            reference: reference,
            waiterID: waiterID,
            cancelTaskWhenEmpty: Task.isCancelled
        )
    }

    func load(
        scope: ProductImageScope?,
        productID: UUID?,
        versionID: UUID?,
        variant: ProductImageVariant
    ) async {
        guard let scope, let productID, let versionID else { return }
        await load(ProductImageReference(
            scope: scope,
            productID: productID,
            versionID: versionID,
            variant: variant
        ))
    }

    func loadProgressively(
        scope: ProductImageScope?,
        productID: UUID?,
        versionID: UUID?
    ) async {
        guard let scope, let productID, let versionID else { return }
        let thumbnail = ProductImageReference(
            scope: scope,
            productID: productID,
            versionID: versionID,
            variant: .thumb
        )
        await load(thumbnail)
        guard !Task.isCancelled else { return }
        let main = ProductImageReference(
            scope: scope,
            productID: productID,
            versionID: versionID,
            variant: .main
        )
        await load(main)
    }

    func cancelOperation(productID: UUID) {
        operationStages[productID] = .cancelled
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
            let result = try await service.upload(
                prepared: prepared,
                scope: scope,
                productID: productID,
                progress: { [self] stage in
                    await self.updateOperationStage(
                        stage,
                        productID: productID,
                        scope: scope,
                        expectedGeneration: expectedGeneration
                    )
                }
            )
            try Task.checkCancellation()
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
            let (main, thumb) = try await (decodedMain, decodedThumb)
            try Task.checkCancellation()
            guard generation == expectedGeneration, activeScope == scope else {
                throw ProductImageError.accountChanged
            }
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
            operationStages[productID] = .completed
            return result
        } catch is CancellationError {
            if generation == expectedGeneration, activeScope == scope {
                operationStages[productID] = .cancelled
            }
            throw CancellationError()
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
            operationStages[productID] = .completed
            return result
        } catch is CancellationError {
            if generation == expectedGeneration, activeScope == scope {
                operationStages[productID] = .cancelled
            }
            throw CancellationError()
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
        if let previousCost = memoryCosts[reference] {
            totalMemoryCost -= previousCost
        }
        memoryCache.setObject(image, forKey: Self.memoryKey(reference) as NSString, cost: cost)
        memoryCosts[reference] = cost
        totalMemoryCost += cost
        loadSources[reference] = source
        cachedReferenceOrder.removeAll { $0 == reference }
        cachedReferenceOrder.append(reference)
        while cachedReferenceOrder.count > Self.maximumTrackedReferences
                || totalMemoryCost > Self.memoryCostLimit {
            let evicted = cachedReferenceOrder.removeFirst()
            memoryCache.removeObject(forKey: Self.memoryKey(evicted) as NSString)
            removeCachedMetadata(evicted, removeFromOrder: false)
        }
        removeFailure(reference)
        revision &+= 1
    }

    private func updateOperationStage(
        _ stage: ProductImageOperationStage,
        productID: UUID,
        scope: ProductImageScope,
        expectedGeneration: Int
    ) {
        guard generation == expectedGeneration, activeScope == scope else { return }
        operationStages[productID] = stage
    }

    private func performLoad(
        _ reference: ProductImageReference,
        service: ProductImageService,
        expectedGeneration: Int
    ) async {
        defer {
            if generation == expectedGeneration {
                loadingReferences.remove(reference)
            }
        }
        do {
            try Task.checkCancellation()
            let result = try await service.load(reference)
            try Task.checkCancellation()
            guard generation == expectedGeneration,
                  activeScope == reference.scope else {
                return
            }
            guard let decoded = try await ProductImageDownsampler.decode(
                result.data,
                variant: reference.variant
            ) else {
                throw ProductImageError.downloadedImageInvalid
            }
            try Task.checkCancellation()
            guard generation == expectedGeneration,
                  activeScope == reference.scope else {
                return
            }
            store(decoded.image, for: reference, source: result.source)
        } catch is CancellationError {
            return
        } catch {
            guard generation == expectedGeneration, activeScope == reference.scope else { return }
            recordFailure(reference)
        }
    }

    private func releaseLoadWaiter(
        reference: ProductImageReference,
        waiterID: UUID,
        cancelTaskWhenEmpty: Bool
    ) {
        guard var load = inFlightLoads[reference] else { return }
        load.waiterIDs.remove(waiterID)
        if load.waiterIDs.isEmpty {
            inFlightLoads.removeValue(forKey: reference)
            if cancelTaskWhenEmpty {
                load.task.cancel()
            }
        } else {
            inFlightLoads[reference] = load
        }
    }

    private func recordFailure(_ reference: ProductImageReference) {
        failedReferences.insert(reference)
        failedReferenceOrder.removeAll { $0 == reference }
        failedReferenceOrder.append(reference)
        while failedReferenceOrder.count > Self.maximumTrackedReferences {
            failedReferences.remove(failedReferenceOrder.removeFirst())
        }
    }

    private func removeFailure(_ reference: ProductImageReference) {
        failedReferences.remove(reference)
        failedReferenceOrder.removeAll { $0 == reference }
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
            removeCachedMetadata(reference)
            removeFailure(reference)
            loadingReferences.remove(reference)
        }
        revision &+= 1
    }

    private func purgeMemoryCache(incrementRevision: Bool = true) {
        memoryCache.removeAllObjects()
        memoryCosts.removeAll()
        totalMemoryCost = 0
        loadSources.removeAll()
        cachedReferenceOrder.removeAll()
        if incrementRevision {
            revision &+= 1
        }
    }

    private func removeCachedMetadata(
        _ reference: ProductImageReference,
        removeFromOrder: Bool = true
    ) {
        if let cost = memoryCosts.removeValue(forKey: reference) {
            totalMemoryCost = max(0, totalMemoryCost - cost)
        }
        loadSources.removeValue(forKey: reference)
        if removeFromOrder {
            cachedReferenceOrder.removeAll { $0 == reference }
        }
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
