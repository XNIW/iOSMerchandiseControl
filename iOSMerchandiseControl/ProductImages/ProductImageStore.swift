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
        let id: UUID
        let task: Task<Void, Never>
        var waiterIDs: Set<UUID>
    }

    private struct PendingPreviewKey: Hashable {
        let scope: ProductImageScope
        let productID: UUID
    }

    @Published private(set) var revision = 0
    @Published private(set) var loadingReferences: Set<ProductImageReference> = []
    @Published private(set) var failedReferences: Set<ProductImageReference> = []
    @Published private(set) var operationStages: [UUID: ProductImageOperationStage] = [:]

    private let service: ProductImageService?
    private let scopeAuthorizationProvider: ProductImageScopeAuthorizationProvider
    private let memoryCache = NSCache<NSString, UIImage>()
    private var memoryCosts: [ProductImageReference: Int] = [:]
    private var totalMemoryCost = 0
    private var memoryWarningCancellable: AnyCancellable?
    private var loadSources: [ProductImageReference: String] = [:]
    private var cachedReferenceOrder: [ProductImageReference] = []
    private var failedReferenceOrder: [ProductImageReference] = []
    private var inFlightLoads: [ProductImageReference: InFlightLoad] = [:]
    private var loadIDs: [ProductImageReference: UUID] = [:]
    private var pendingPreviews: [PendingPreviewKey: UIImage] = [:]
    private var operationIDs: [UUID: UUID] = [:]
    private var operationScopes: [UUID: ProductImageScope] = [:]
    private var nonCancellableOperationIDs: Set<UUID> = []
    private var activeScope: ProductImageScope?
    private var accountStoreReplacementLeaseActive = false
    private var generation = 0
    private var storePresentationID: String?
    private var scopeActivationTask: Task<Void, Never>?
    private var scopeCleanupTask: Task<Void, Never>?

    init(
        service: ProductImageService?,
        scopeAuthorizationProvider: @escaping ProductImageScopeAuthorizationProvider = { _ in true }
    ) {
        self.service = service
        self.scopeAuthorizationProvider = scopeAuthorizationProvider
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

    nonisolated deinit {}

    var isAvailable: Bool { service != nil }

    var canBeginAccountStoreReplacement: Bool {
        !accountStoreReplacementLeaseActive && operationIDs.isEmpty
    }

    /// Prevents any new upload/remove from being admitted while the local
    /// owner/shop store is being replaced. Existing mutations must finish
    /// before the lease can be acquired.
    @discardableResult
    func beginAccountStoreReplacementLease() -> Bool {
        guard canBeginAccountStoreReplacement else { return false }
        accountStoreReplacementLeaseActive = true
        objectWillChange.send()
        return true
    }

    func endAccountStoreReplacementLease() {
        guard accountStoreReplacementLeaseActive else { return }
        accountStoreReplacementLeaseActive = false
        objectWillChange.send()
    }

    func activate(scope: ProductImageScope?) {
        activate(scope: scope, forceGenerationBoundary: false)
    }

    /// Invalidates image state at the same publication boundary as the
    /// SwiftData generation, including same-account/same-shop replacements.
    func advanceStoreGeneration(presentationID: String) {
        guard storePresentationID != presentationID else { return }
        storePresentationID = presentationID
        activate(scope: activeScope, forceGenerationBoundary: true)
    }

    private func activate(
        scope: ProductImageScope?,
        forceGenerationBoundary: Bool
    ) {
        let nextScope = scope.flatMap { scopeAuthorizationProvider($0) ? $0 : nil }
        guard forceGenerationBoundary || activeScope != nextScope else { return }
        let previousScope = activeScope
        activeScope = nextScope
        generation &+= 1
        let expectedGeneration = generation
        for load in inFlightLoads.values {
            load.task.cancel()
        }
        inFlightLoads.removeAll()
        loadIDs.removeAll()
        purgeMemoryCache(incrementRevision: false)
        failedReferenceOrder.removeAll()
        loadingReferences.removeAll()
        failedReferences.removeAll()
        let preservedProductIDs = Set(operationIDs.compactMap { productID, operationID in
            nonCancellableOperationIDs.contains(operationID) ? productID : nil
        })
        operationStages = operationStages.filter { preservedProductIDs.contains($0.key) }
        operationIDs = operationIDs.filter { preservedProductIDs.contains($0.key) }
        operationScopes = operationScopes.filter { preservedProductIDs.contains($0.key) }
        nonCancellableOperationIDs = Set(operationIDs.values)
        pendingPreviews = pendingPreviews.filter { key, _ in
            preservedProductIDs.contains(key.productID)
                && operationScopes[key.productID] == key.scope
        }
        revision &+= 1

        scopeActivationTask?.cancel()
        scopeCleanupTask?.cancel()
        guard let service else {
            scopeActivationTask = nil
            scopeCleanupTask = nil
            return
        }
        let activationTask = Task {
            await service.setActiveScope(nextScope, generation: expectedGeneration)
        }
        scopeActivationTask = activationTask
        if let previousScope {
            let purgeAccountScope = nextScope == nil
                || nextScope?.accountID != previousScope.accountID
            scopeCleanupTask = Task { [weak self] in
                await activationTask.value
                do {
                    try await Task.sleep(nanoseconds: 8_000_000)
                } catch {
                    return
                }
                guard let self,
                      !Task.isCancelled,
                      self.generation == expectedGeneration,
                      self.activeScope == nextScope else {
                    return
                }
                await service.deactivate(
                    scope: previousScope,
                    purgeAccountScope: purgeAccountScope,
                    lifecycleGeneration: expectedGeneration
                )
            }
        } else {
            scopeCleanupTask = nil
        }
    }

    func image(for reference: ProductImageReference) -> UIImage? {
        _ = revision
        guard activeScope == reference.scope,
              scopeAuthorizationProvider(reference.scope) else { return nil }
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

    func pendingPreview(scope: ProductImageScope?, productID: UUID?) -> UIImage? {
        _ = revision
        guard let scope,
              let productID,
              activeScope == scope,
              scopeAuthorizationProvider(scope) else { return nil }
        return pendingPreviews[PendingPreviewKey(scope: scope, productID: productID)]
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
              scopeAuthorizationProvider(reference.scope) else {
            return
        }
        if activeScope != reference.scope {
            activate(scope: reference.scope)
        }
        let activationTask = scopeActivationTask
        await activationTask?.value
        guard activeScope == reference.scope,
              generation > 0,
              scopeAuthorizationProvider(reference.scope),
              image(for: reference) == nil else { return }

        let waiterID = UUID()
        let task: Task<Void, Never>
        if var existing = inFlightLoads[reference] {
            existing.waiterIDs.insert(waiterID)
            task = existing.task
            inFlightLoads[reference] = existing
        } else {
            let expectedGeneration = generation
            let loadID = UUID()
            loadIDs[reference] = loadID
            loadingReferences.insert(reference)
            removeFailure(reference)
            task = Task { [weak self] in
                guard let self else { return }
                await self.performLoad(
                    reference,
                    service: service,
                    expectedGeneration: expectedGeneration,
                    loadID: loadID
                )
            }
            inFlightLoads[reference] = InFlightLoad(
                id: loadID,
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

    @discardableResult
    func cancelOperation(productID: UUID, scope: ProductImageScope? = nil) -> Bool {
        guard let operationID = operationIDs[productID],
              scope == nil || operationScopes[productID] == scope,
              operationStages[productID, default: .idle].allowsCancellation,
              !nonCancellableOperationIDs.contains(operationID) else {
            return false
        }
        operationIDs[productID] = nil
        operationScopes[productID] = nil
        clearPendingPreview(scope: scope ?? activeScope, productID: productID)
        operationStages[productID] = .cancelled
        return true
    }

    /// Releases the mutation admission only after the caller has synchronously
    /// committed (or rolled back) the matching SwiftData reference update.
    func finishMutationLease(scope: ProductImageScope, productID: UUID) {
        guard operationScopes[productID] == scope,
              operationStages[productID] == .completed else { return }
        operationIDs[productID] = nil
        operationScopes[productID] = nil
        objectWillChange.send()
    }

    func upload(
        fileURL: URL,
        scope: ProductImageScope,
        productID: UUID,
        previousVersionID: UUID?,
        retainMutationLeaseAfterResponse: Bool = false
    ) async throws -> ProductImageUploadResult {
        guard let service else { throw ProductImageError.unavailable }
        guard !accountStoreReplacementLeaseActive else { throw ProductImageError.accountChanged }
        guard scopeAuthorizationProvider(scope) else { throw ProductImageError.invalidScope }
        await scopeActivationTask?.value
        guard !accountStoreReplacementLeaseActive,
              activeScope == scope,
              scopeAuthorizationProvider(scope) else {
            throw ProductImageError.accountChanged
        }
        guard operationIDs[productID] == nil else {
            throw ProductImageError.invalidResponse
        }
        let expectedGeneration = generation
        let operationID = UUID()
        operationIDs[productID] = operationID
        operationScopes[productID] = scope
        operationStages[productID] = .processing

        do {
            let prepared = try await ProductImageProcessor.prepare(fileURL: fileURL)
            guard generation == expectedGeneration,
                  activeScope == scope,
                  operationIDs[productID] == operationID else {
                throw ProductImageError.accountChanged
            }
            async let decodedMain = ProductImageDownsampler.decode(prepared.main.data, variant: .main)
            async let decodedThumb = ProductImageDownsampler.decode(prepared.thumb.data, variant: .thumb)
            guard let main = try await decodedMain,
                  let thumb = try await decodedThumb else {
                throw ProductImageError.decodeFailed
            }
            try Task.checkCancellation()
            guard generation == expectedGeneration,
                  activeScope == scope,
                  operationIDs[productID] == operationID else {
                throw ProductImageError.accountChanged
            }
            setPendingPreview(main.image, scope: scope, productID: productID)
            let result = try await service.upload(
                prepared: prepared,
                scope: scope,
                productID: productID,
                progress: { [self] stage in
                    await self.updateOperationStage(
                        stage,
                        productID: productID,
                        scope: scope,
                        expectedGeneration: expectedGeneration,
                        operationID: operationID
                    )
                }
            )
            guard generation == expectedGeneration,
                  activeScope == scope,
                  scopeAuthorizationProvider(scope),
                  operationScopes[productID] == scope,
                  operationIDs[productID] == operationID else {
                throw ProductImageError.accountChanged
            }
            if activeScope == scope {
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
                if let previousVersionID, previousVersionID != result.versionID {
                    discard(
                        scope: scope,
                        productID: productID,
                        versionID: previousVersionID
                    )
                }
            }
            clearPendingPreview(scope: scope, productID: productID)
            operationStages[productID] = .completed
            nonCancellableOperationIDs.remove(operationID)
            if !retainMutationLeaseAfterResponse {
                finishMutationLease(scope: scope, productID: productID)
            }
            return result
        } catch is CancellationError {
            if operationIDs[productID] == operationID {
                clearPendingPreview(scope: scope, productID: productID)
                operationStages[productID] = .cancelled
                operationIDs[productID] = nil
                operationScopes[productID] = nil
                nonCancellableOperationIDs.remove(operationID)
            }
            scheduleReloadIfActive(
                scope: scope,
                productID: productID,
                versionID: previousVersionID
            )
            throw CancellationError()
        } catch {
            if operationIDs[productID] == operationID {
                clearPendingPreview(scope: scope, productID: productID)
                operationStages[productID] = .failed
                operationIDs[productID] = nil
                operationScopes[productID] = nil
                nonCancellableOperationIDs.remove(operationID)
            }
            scheduleReloadIfActive(
                scope: scope,
                productID: productID,
                versionID: previousVersionID
            )
            throw error
        }
    }

    func remove(
        scope: ProductImageScope,
        productID: UUID,
        versionID: UUID,
        retainMutationLeaseAfterResponse: Bool = false
    ) async throws -> ProductImageRemoveResult {
        guard let service else { throw ProductImageError.unavailable }
        guard !accountStoreReplacementLeaseActive else { throw ProductImageError.accountChanged }
        guard scopeAuthorizationProvider(scope) else { throw ProductImageError.invalidScope }
        await scopeActivationTask?.value
        guard !accountStoreReplacementLeaseActive,
              activeScope == scope,
              scopeAuthorizationProvider(scope) else {
            throw ProductImageError.accountChanged
        }
        guard operationIDs[productID] == nil else {
            throw ProductImageError.invalidResponse
        }
        let expectedGeneration = generation
        let operationID = UUID()
        operationIDs[productID] = operationID
        operationScopes[productID] = scope
        nonCancellableOperationIDs.insert(operationID)
        clearPendingPreview(scope: scope, productID: productID)
        operationStages[productID] = .removing
        do {
            let result = try await service.remove(
                scope: scope,
                productID: productID,
                versionID: versionID
            )
            guard generation == expectedGeneration,
                  activeScope == scope,
                  scopeAuthorizationProvider(scope),
                  operationScopes[productID] == scope,
                  operationIDs[productID] == operationID else {
                throw ProductImageError.accountChanged
            }
            if activeScope == scope {
                discard(scope: scope, productID: productID, versionID: versionID)
            }
            operationStages[productID] = .completed
            nonCancellableOperationIDs.remove(operationID)
            if !retainMutationLeaseAfterResponse {
                finishMutationLease(scope: scope, productID: productID)
            }
            return result
        } catch is CancellationError {
            if operationIDs[productID] == operationID {
                operationStages[productID] = .cancelled
                operationIDs[productID] = nil
                operationScopes[productID] = nil
                nonCancellableOperationIDs.remove(operationID)
            }
            scheduleReloadIfActive(scope: scope, productID: productID, versionID: versionID)
            throw CancellationError()
        } catch {
            if operationIDs[productID] == operationID {
                operationStages[productID] = .failed
                operationIDs[productID] = nil
                operationScopes[productID] = nil
                nonCancellableOperationIDs.remove(operationID)
            }
            scheduleReloadIfActive(scope: scope, productID: productID, versionID: versionID)
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

    private func setPendingPreview(
        _ image: UIImage,
        scope: ProductImageScope,
        productID: UUID
    ) {
        guard activeScope == scope else { return }
        pendingPreviews[PendingPreviewKey(scope: scope, productID: productID)] = image
        revision &+= 1
    }

    private func clearPendingPreview(scope: ProductImageScope?, productID: UUID) {
        guard let scope else { return }
        let key = PendingPreviewKey(scope: scope, productID: productID)
        guard pendingPreviews.removeValue(forKey: key) != nil else { return }
        revision &+= 1
    }

    private func scheduleReloadIfActive(
        scope: ProductImageScope,
        productID: UUID,
        versionID: UUID?
    ) {
        guard let versionID,
              activeScope == scope,
              scopeAuthorizationProvider(scope) else {
            return
        }
        Task { @MainActor [weak self] in
            await self?.loadProgressively(
                scope: scope,
                productID: productID,
                versionID: versionID
            )
        }
    }

    private func updateOperationStage(
        _ stage: ProductImageOperationStage,
        productID: UUID,
        scope: ProductImageScope,
        expectedGeneration: Int,
        operationID: UUID
    ) {
        guard generation == expectedGeneration,
              activeScope == scope,
              operationIDs[productID] == operationID else { return }
        operationStages[productID] = stage
        if stage == .finalizing {
            nonCancellableOperationIDs.insert(operationID)
        }
    }

    private func performLoad(
        _ reference: ProductImageReference,
        service: ProductImageService,
        expectedGeneration: Int,
        loadID: UUID
    ) async {
        defer {
            if loadIDs[reference] == loadID {
                loadIDs[reference] = nil
                loadingReferences.remove(reference)
            }
        }
        do {
            try Task.checkCancellation()
            let result = try await service.load(reference)
            try Task.checkCancellation()
            guard generation == expectedGeneration,
                  activeScope == reference.scope,
                  scopeAuthorizationProvider(reference.scope),
                  loadIDs[reference] == loadID else {
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
                  activeScope == reference.scope,
                  scopeAuthorizationProvider(reference.scope),
                  loadIDs[reference] == loadID else {
                return
            }
            store(decoded.image, for: reference, source: result.source)
        } catch is CancellationError {
            return
        } catch {
            guard generation == expectedGeneration,
                  activeScope == reference.scope,
                  loadIDs[reference] == loadID else { return }
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
            if let load = inFlightLoads.removeValue(forKey: reference) {
                load.task.cancel()
            }
            loadIDs[reference] = nil
            if let service {
                Task { await service.cancel(reference) }
            }
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
