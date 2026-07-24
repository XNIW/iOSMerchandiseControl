import CryptoKit
import Foundation

nonisolated struct ProductImageLoadResult: Sendable {
    let cacheKey: ProductImageCacheKey
    let data: Data
    let source: String
}

private actor ProductImageConcurrencyGate {
    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<UUID, Error>
    }

    private let limit: Int
    private var activePermits = Set<UUID>()
    private var waiters: [Waiter] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    func acquire() async throws -> UUID {
        try Task.checkCancellation()
        let id = UUID()
        if activePermits.count < limit {
            activePermits.insert(id)
            return id
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                waiters.append(Waiter(id: id, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancel(id) }
        }
    }

    func release(_ id: UUID) {
        guard activePermits.remove(id) != nil else { return }
        resumeNextWaiter()
    }

    private func cancel(_ id: UUID) {
        if let index = waiters.firstIndex(where: { $0.id == id }) {
            let waiter = waiters.remove(at: index)
            waiter.continuation.resume(throwing: CancellationError())
            return
        }
        if activePermits.remove(id) != nil {
            resumeNextWaiter()
        }
    }

    private func resumeNextWaiter() {
        guard !waiters.isEmpty else { return }
        let waiter = waiters.removeFirst()
        activePermits.insert(waiter.id)
        waiter.continuation.resume(returning: waiter.id)
    }
}

actor ProductImageService {
    typealias SessionProvider = @Sendable () async -> ProductImageSessionSnapshot?
    typealias ProgressHandler = @Sendable (ProductImageOperationStage) async -> Void

    static let defaultMaximumConcurrentDownloads = 4
    static let defaultMaximumConcurrentReadRequests = 2
    static let readBatchDelayNanoseconds: UInt64 = 8_000_000
    static let defaultSignedURLSafetyWindow: TimeInterval = 30
    static let defaultSignedURLTTLSeconds: TimeInterval = 300
    static let defaultSignedURLClockSkewAllowance: TimeInterval = 30
    static let maximumSignedURLLeases = 1_000

    private struct SignedReadLease: Sendable {
        let expiresAt: Date
        let metadata: ProductImageMetadata
        let signedURL: String
    }

    private struct InFlightLoad {
        let task: Task<ProductImageLoadResult, Error>
        var waiterIDs: Set<UUID>
    }

    private struct ReadBatchKey: Hashable {
        let scope: ProductImageScope
        let tokenFingerprint: String
    }

    private struct ReadWaiter {
        let id: UUID
        let continuation: CheckedContinuation<SignedReadLease, Error>
    }

    private struct PendingReadBatch {
        let scope: ProductImageScope
        let accessToken: String
        let expectedCacheScope: String
        var waiters: [ProductImageReference: [ReadWaiter]]
        var scheduledFlush: Task<Void, Never>?
    }

    private struct ActiveReadBatch {
        var batch: PendingReadBatch
        let references: [ProductImageReference]
        let task: Task<Void, Never>
    }

    private struct ProductKey: Hashable {
        let scope: ProductImageScope
        let productID: UUID
    }

    private let api: ProductImageAPIClient
    private let cache: ProductImageCache
    private let downloadGate: ProductImageConcurrencyGate
    private let now: @Sendable () -> Date
    private let readBatchDelayNanoseconds: UInt64
    private let readRequestGate: ProductImageConcurrencyGate
    private let sessionProvider: SessionProvider
    private let signedURLSafetyWindow: TimeInterval
    private let signedURLTTLSeconds: TimeInterval
    private let signedURLClockSkewAllowance: TimeInterval
    private let scopeAuthorizationProvider: ProductImageScopeAuthorizationProvider
    private var activeReadBatches: [UUID: ActiveReadBatch] = [:]
    private var activeScope: ProductImageScope?
    private var activeProductMutations: [ProductKey: UUID] = [:]
    private var inFlightLoads: [ProductImageReference: InFlightLoad] = [:]
    private var lifecycleGeneration = 0
    private var pendingReadBatches: [ReadBatchKey: PendingReadBatch] = [:]
    private var productLoadEpochs: [ProductKey: UInt64] = [:]
    private var signedURLLeases: [ProductImageReference: SignedReadLease] = [:]
    private var signedURLLeaseOrder: [ProductImageReference] = []

    init(
        apiBaseURL: URL,
        storageBaseURL: URL,
        cache: ProductImageCache = ProductImageCache(),
        maximumConcurrentDownloads: Int = defaultMaximumConcurrentDownloads,
        maximumConcurrentReadRequests: Int = defaultMaximumConcurrentReadRequests,
        readBatchDelayNanoseconds: UInt64 = ProductImageService.readBatchDelayNanoseconds,
        signedURLSafetyWindow: TimeInterval = defaultSignedURLSafetyWindow,
        signedURLTTLSeconds: TimeInterval = defaultSignedURLTTLSeconds,
        signedURLClockSkewAllowance: TimeInterval = defaultSignedURLClockSkewAllowance,
        now: @escaping @Sendable () -> Date = Date.init,
        scopeAuthorizationProvider: @escaping ProductImageScopeAuthorizationProvider = { _ in true },
        sessionProvider: @escaping SessionProvider
    ) {
        self.api = ProductImageAPIClient(
            apiBaseURL: apiBaseURL,
            storageBaseURL: storageBaseURL
        )
        self.cache = cache
        self.downloadGate = ProductImageConcurrencyGate(limit: maximumConcurrentDownloads)
        self.readBatchDelayNanoseconds = readBatchDelayNanoseconds
        self.readRequestGate = ProductImageConcurrencyGate(limit: maximumConcurrentReadRequests)
        self.signedURLSafetyWindow = max(0, signedURLSafetyWindow)
        self.signedURLTTLSeconds = max(1, signedURLTTLSeconds)
        self.signedURLClockSkewAllowance = max(0, signedURLClockSkewAllowance)
        self.now = now
        self.scopeAuthorizationProvider = scopeAuthorizationProvider
        self.sessionProvider = sessionProvider
    }

    init(
        api: ProductImageAPIClient,
        cache: ProductImageCache,
        maximumConcurrentDownloads: Int = defaultMaximumConcurrentDownloads,
        maximumConcurrentReadRequests: Int = defaultMaximumConcurrentReadRequests,
        readBatchDelayNanoseconds: UInt64 = ProductImageService.readBatchDelayNanoseconds,
        signedURLSafetyWindow: TimeInterval = defaultSignedURLSafetyWindow,
        signedURLTTLSeconds: TimeInterval = defaultSignedURLTTLSeconds,
        signedURLClockSkewAllowance: TimeInterval = defaultSignedURLClockSkewAllowance,
        now: @escaping @Sendable () -> Date = Date.init,
        scopeAuthorizationProvider: @escaping ProductImageScopeAuthorizationProvider = { _ in true },
        sessionProvider: @escaping SessionProvider
    ) {
        self.api = api
        self.cache = cache
        self.downloadGate = ProductImageConcurrencyGate(limit: maximumConcurrentDownloads)
        self.readBatchDelayNanoseconds = readBatchDelayNanoseconds
        self.readRequestGate = ProductImageConcurrencyGate(limit: maximumConcurrentReadRequests)
        self.signedURLSafetyWindow = max(0, signedURLSafetyWindow)
        self.signedURLTTLSeconds = max(1, signedURLTTLSeconds)
        self.signedURLClockSkewAllowance = max(0, signedURLClockSkewAllowance)
        self.now = now
        self.scopeAuthorizationProvider = scopeAuthorizationProvider
        self.sessionProvider = sessionProvider
    }

    func load(_ reference: ProductImageReference) async throws -> ProductImageLoadResult {
        try Task.checkCancellation()
        try authorize(reference.scope)
        let expectedProductEpoch = productLoadEpoch(
            scope: reference.scope,
            productID: reference.productID
        )
        try ensureLoadAllowed(
            expectedProductEpoch,
            scope: reference.scope,
            productID: reference.productID
        )
        let expectedScope = Self.expectedCacheScope(accountID: reference.scope.accountID)
        let key = ProductImageCacheKey(
            cacheScope: expectedScope,
            shopID: reference.scope.shopID,
            productID: reference.productID,
            versionID: reference.versionID,
            variant: reference.variant
        )
        if let cached = try? await cache.read(key) {
            let cachedIsValid: Bool
            do {
                try await ProductImageProcessor.validateDownloadedJPEG(cached, variant: reference.variant)
                cachedIsValid = true
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try? await cache.remove(key)
                cachedIsValid = false
            }
            if cachedIsValid {
                try Task.checkCancellation()
                try authorize(reference.scope)
                try ensureLoadAllowed(
                    expectedProductEpoch,
                    scope: reference.scope,
                    productID: reference.productID
                )
                return ProductImageLoadResult(cacheKey: key, data: cached, source: "cache")
            }
        }

        let waiterID = UUID()
        let task: Task<ProductImageLoadResult, Error>
        try ensureLoadAllowed(
            expectedProductEpoch,
            scope: reference.scope,
            productID: reference.productID
        )
        if var existing = inFlightLoads[reference] {
            existing.waiterIDs.insert(waiterID)
            task = existing.task
            inFlightLoads[reference] = existing
        } else {
            task = Task {
                try await self.performNetworkLoad(
                    reference,
                    key: key,
                    expectedScope: expectedScope,
                    expectedProductEpoch: expectedProductEpoch
                )
            }
            inFlightLoads[reference] = InFlightLoad(task: task, waiterIDs: [waiterID])
        }

        do {
            let result = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                Task { await self.cancelLoadWaiter(reference: reference, waiterID: waiterID) }
            }
            try Task.checkCancellation()
            try authorize(reference.scope)
            try ensureLoadAllowed(
                expectedProductEpoch,
                scope: reference.scope,
                productID: reference.productID
            )
            releaseLoadWaiter(reference: reference, waiterID: waiterID, cancelTaskWhenEmpty: false)
            return result
        } catch {
            releaseLoadWaiter(reference: reference, waiterID: waiterID, cancelTaskWhenEmpty: true)
            throw error
        }
    }

    func cancel(_ reference: ProductImageReference) {
        if let load = inFlightLoads.removeValue(forKey: reference) {
            load.task.cancel()
        }
        cancelReadWaiters(matching: { $0 == reference })
    }

    func setActiveScope(_ scope: ProductImageScope?, generation: Int) async {
        guard generation > lifecycleGeneration else { return }
        let previousScope = activeScope
        lifecycleGeneration = generation
        activeScope = scope

        // A published SwiftData generation is an image/cache boundary even
        // when account and shop are unchanged. Cancel every pre-bound request,
        // invalidate its epoch and lease, and remove bytes that may have been
        // written by a non-cooperative transport before the new generation
        // can serve an image.
        for load in inFlightLoads.values {
            load.task.cancel()
        }
        inFlightLoads.removeAll(keepingCapacity: true)
        for key in Array(productLoadEpochs.keys) {
            productLoadEpochs[key, default: 0] &+= 1
        }
        cancelAllReadBatches()
        signedURLLeases.removeAll(keepingCapacity: true)
        signedURLLeaseOrder.removeAll(keepingCapacity: true)
        activeProductMutations.removeAll(keepingCapacity: true)

        if let previousScope {
            let cacheScope = Self.expectedCacheScope(accountID: previousScope.accountID)
            try? await cache.purgeShop(
                cacheScope: cacheScope,
                shopID: previousScope.shopID
            )
        }
    }

    func deactivate(
        scope: ProductImageScope,
        purgeAccountScope: Bool,
        lifecycleGeneration expectedLifecycleGeneration: Int? = nil
    ) async {
        if let expectedLifecycleGeneration {
            guard expectedLifecycleGeneration == lifecycleGeneration,
                  activeScope != scope,
                  !Task.isCancelled else {
                return
            }
        }
        let references = inFlightLoads.keys.filter { $0.scope == scope }
        for reference in references {
            cancel(reference)
        }
        cancelPendingReadBatches(scope: scope)
        invalidateLeases(scope: scope, purgeAccountScope: purgeAccountScope)

        guard expectedLifecycleGeneration == nil
                || (expectedLifecycleGeneration == lifecycleGeneration
                    && activeScope != scope
                    && !Task.isCancelled) else {
            return
        }
        let cacheScope = Self.expectedCacheScope(accountID: scope.accountID)
        if purgeAccountScope {
            try? await cache.purgeScope(cacheScope: cacheScope)
        } else {
            try? await cache.purgeShop(cacheScope: cacheScope, shopID: scope.shopID)
        }
    }

    func upload(
        prepared: PreparedProductImage,
        scope: ProductImageScope,
        productID: UUID,
        progress: ProgressHandler? = nil
    ) async throws -> ProductImageUploadResult {
        try Task.checkCancellation()
        try authorize(scope)
        let expectedLifecycleGeneration = lifecycleGeneration
        let mutationID = try beginProductMutation(scope: scope, productID: productID)
        defer { finishProductMutation(scope: scope, productID: productID, mutationID: mutationID) }
        let session = try await validMutationSession(
            for: scope,
            productID: productID,
            mutationID: mutationID,
            expectedLifecycleGeneration: expectedLifecycleGeneration
        )
        let expectedScope = Self.expectedCacheScope(accountID: scope.accountID)
        let intent = try await api.createIntent(
            scope: scope,
            productID: productID,
            prepared: prepared,
            accessToken: session.accessToken
        )
        try ensureMutationCurrent(
            scope: scope,
            productID: productID,
            mutationID: mutationID,
            expectedLifecycleGeneration: expectedLifecycleGeneration
        )
        guard intent.ok == true,
              let versionID = intent.versionId,
              intent.cacheScope == expectedScope else {
            throw ProductImageError.invalidResponse
        }

        if intent.status == "noop" {
            try Task.checkCancellation()
            _ = try await validMutationSession(
                for: scope,
                productID: productID,
                mutationID: mutationID,
                expectedLifecycleGeneration: expectedLifecycleGeneration
            )
            invalidateProductLoads(scope: scope, productID: productID)
            try await reconcileCommittedUploadCache(
                prepared: prepared,
                cacheScope: expectedScope,
                scope: scope,
                productID: productID,
                versionID: versionID,
                mutationID: mutationID,
                expectedLifecycleGeneration: expectedLifecycleGeneration
            )
            invalidateProductLoads(scope: scope, productID: productID)
            return ProductImageUploadResult(
                imageUpdatedAt: nil,
                metrics: prepared.metrics,
                status: "noop",
                versionID: versionID
            )
        }

        guard intent.status == "upload_required",
              let mainUploadURL = intent.mainUploadUrl,
              let thumbUploadURL = intent.thumbUploadUrl else {
            throw ProductImageError.invalidResponse
        }

        try Task.checkCancellation()
        if let progress { await progress(.uploadingMain) }
        _ = try await validMutationSession(
            for: scope,
            productID: productID,
            mutationID: mutationID,
            expectedLifecycleGeneration: expectedLifecycleGeneration
        )
        try await api.uploadJPEG(
            prepared.main.data,
            signedURL: mainUploadURL,
            expectedReference: ProductImageReference(
                scope: scope,
                productID: productID,
                versionID: versionID,
                variant: .main
            )
        )
        try ensureMutationCurrent(
            scope: scope,
            productID: productID,
            mutationID: mutationID,
            expectedLifecycleGeneration: expectedLifecycleGeneration
        )
        try Task.checkCancellation()
        if let progress { await progress(.uploadingThumb) }
        _ = try await validMutationSession(
            for: scope,
            productID: productID,
            mutationID: mutationID,
            expectedLifecycleGeneration: expectedLifecycleGeneration
        )
        try await api.uploadJPEG(
            prepared.thumb.data,
            signedURL: thumbUploadURL,
            expectedReference: ProductImageReference(
                scope: scope,
                productID: productID,
                versionID: versionID,
                variant: .thumb
            )
        )
        try ensureMutationCurrent(
            scope: scope,
            productID: productID,
            mutationID: mutationID,
            expectedLifecycleGeneration: expectedLifecycleGeneration
        )
        try Task.checkCancellation()
        let finalizeSession = try await validSession(for: scope)
        try Task.checkCancellation()
        if let progress { await progress(.finalizing) }

        let api = self.api
        let accessToken = finalizeSession.accessToken
        let finalized = try await Task.detached(priority: .userInitiated) {
            try await api.finalize(
                scope: scope,
                productID: productID,
                versionID: versionID,
                accessToken: accessToken
            )
        }.value
        guard finalized.ok == true,
              finalized.versionId == versionID,
              finalized.status == "finalized" || finalized.status == "already_finalized" else {
            throw ProductImageError.invalidResponse
        }
        _ = try await validCommittedSession(
            for: scope,
            expectedLifecycleGeneration: expectedLifecycleGeneration
        )
        invalidateProductLoads(scope: scope, productID: productID)
        try await reconcileCommittedUploadCache(
            prepared: prepared,
            cacheScope: expectedScope,
            scope: scope,
            productID: productID,
            versionID: versionID,
            mutationID: mutationID,
            expectedLifecycleGeneration: expectedLifecycleGeneration
        )
        invalidateProductLoads(scope: scope, productID: productID)
        return ProductImageUploadResult(
            imageUpdatedAt: SupabaseRemoteDateParser.parse(finalized.imageUpdatedAt),
            metrics: prepared.metrics,
            status: finalized.status ?? "finalized",
            versionID: versionID
        )
    }

    func remove(
        scope: ProductImageScope,
        productID: UUID,
        versionID: UUID
    ) async throws -> ProductImageRemoveResult {
        try Task.checkCancellation()
        try authorize(scope)
        let expectedLifecycleGeneration = lifecycleGeneration
        let mutationID = try beginProductMutation(scope: scope, productID: productID)
        defer { finishProductMutation(scope: scope, productID: productID, mutationID: mutationID) }
        let session = try await validSession(for: scope)
        let api = self.api
        let accessToken = session.accessToken
        let response = try await Task.detached(priority: .userInitiated) {
            try await api.remove(
                scope: scope,
                productID: productID,
                versionID: versionID,
                accessToken: accessToken
            )
        }.value
        guard response.ok == true,
              let status = response.status,
              status == "removed" || status == "already_removed",
              response.operation == "remove",
              response.productId == productID,
              response.shopId == scope.shopID,
              response.versionId == versionID,
              response.hasCurrentImageVersionId,
              response.currentImageVersionId == nil else {
            throw ProductImageError.invalidResponse
        }
        _ = try await validCommittedSession(
            for: scope,
            expectedLifecycleGeneration: expectedLifecycleGeneration
        )
        let expectedScope = Self.expectedCacheScope(accountID: scope.accountID)
        invalidateProductLoads(scope: scope, productID: productID)
        let cache = self.cache
        await Task.detached(priority: .utility) {
            try? await cache.purgeProduct(
                cacheScope: expectedScope,
                shopID: scope.shopID,
                productID: productID,
                keeping: nil
            )
        }.value
        invalidateProductLoads(scope: scope, productID: productID)
        return ProductImageRemoveResult(
            imageUpdatedAt: SupabaseRemoteDateParser.parse(response.imageUpdatedAt),
            status: status
        )
    }

    static func expectedCacheScope(accountID: UUID) -> String {
        let material = Data("product-image-account:\(accountID.uuidString.lowercased())".utf8)
        return SHA256.hash(data: material).map { String(format: "%02x", $0) }.joined()
    }

    private func performNetworkLoad(
        _ reference: ProductImageReference,
        key: ProductImageCacheKey,
        expectedScope: String,
        expectedProductEpoch: UInt64
    ) async throws -> ProductImageLoadResult {
        try Task.checkCancellation()
        try authorize(reference.scope)
        try ensureLoadAllowed(
            expectedProductEpoch,
            scope: reference.scope,
            productID: reference.productID
        )
        let session = try await validSession(for: reference.scope)
        let lease = try await resolveRuntimeSignedReadURL(
            reference: reference,
            accessToken: session.accessToken,
            expectedScope: expectedScope
        )
        try Task.checkCancellation()
        try authorize(reference.scope)
        try ensureLoadAllowed(
            expectedProductEpoch,
            scope: reference.scope,
            productID: reference.productID
        )
        let data: Data
        let expectedMetadata: ProductImageMetadata
        do {
            data = try await downloadReadData(
                signedURL: lease.signedURL,
                reference: reference
            )
            expectedMetadata = lease.metadata
        } catch ProductImageError.downloadFailed(let status) where status == 401 || status == 403 {
            try Task.checkCancellation()
            invalidateLease(reference)
            let refreshSession = try await validSession(for: reference.scope)
            let refreshedLease = try await resolveSignedReadURL(
                reference: reference,
                accessToken: refreshSession.accessToken,
                expectedScope: expectedScope,
                forceRefresh: true
            )
            try Task.checkCancellation()
            try authorize(reference.scope)
            try ensureLoadAllowed(
                expectedProductEpoch,
                scope: reference.scope,
                productID: reference.productID
            )
            data = try await downloadReadData(
                signedURL: refreshedLease.signedURL,
                reference: reference
            )
            expectedMetadata = refreshedLease.metadata
        }
        try await ProductImageProcessor.validateDownloadedJPEG(
            data,
            variant: reference.variant,
            expectedMetadata: expectedMetadata
        )
        try Task.checkCancellation()
        _ = try await validSession(for: reference.scope)
        try Task.checkCancellation()
        try ensureLoadAllowed(
            expectedProductEpoch,
            scope: reference.scope,
            productID: reference.productID
        )
        try await cache.write(data, for: key)
        do {
            try ensureLoadAllowed(
                expectedProductEpoch,
                scope: reference.scope,
                productID: reference.productID
            )
        } catch {
            try? await cache.remove(key)
            throw error
        }
        try await cache.purgeProduct(
            cacheScope: expectedScope,
            shopID: reference.scope.shopID,
            productID: reference.productID,
            keeping: reference.versionID
        )
        do {
            try ensureLoadAllowed(
                expectedProductEpoch,
                scope: reference.scope,
                productID: reference.productID
            )
        } catch {
            try? await cache.remove(key)
            throw error
        }
        return ProductImageLoadResult(cacheKey: key, data: data, source: "network")
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

    private func cancelLoadWaiter(reference: ProductImageReference, waiterID: UUID) {
        releaseLoadWaiter(reference: reference, waiterID: waiterID, cancelTaskWhenEmpty: true)
    }

    private func resolveSignedReadURL(
        reference: ProductImageReference,
        accessToken: String,
        expectedScope: String,
        forceRefresh: Bool = false
    ) async throws -> SignedReadLease {
        try Task.checkCancellation()
        if !forceRefresh, let lease = signedURLLeases[reference] {
            if isRuntimeLeaseValid(lease, at: now()) {
                touchLease(reference)
                return lease
            }
            invalidateLease(reference)
        }
        let waiterID = UUID()
        let key = ReadBatchKey(
            scope: reference.scope,
            tokenFingerprint: SHA256.hash(data: Data(accessToken.utf8))
                .map { String(format: "%02x", $0) }
                .joined()
        )
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                enqueueReadWaiter(
                    ReadWaiter(id: waiterID, continuation: continuation),
                    reference: reference,
                    key: key,
                    accessToken: accessToken,
                    expectedScope: expectedScope
                )
            }
        } onCancel: {
            Task {
                await self.cancelReadWaiter(
                    key: key,
                    reference: reference,
                    waiterID: waiterID
                )
            }
        }
    }

    private func resolveRuntimeSignedReadURL(
        reference: ProductImageReference,
        accessToken: String,
        expectedScope: String
    ) async throws -> SignedReadLease {
        do {
            return try await resolveSignedReadURL(
                reference: reference,
                accessToken: accessToken,
                expectedScope: expectedScope
            )
        } catch let error as ProductImageError where error == .signedURLInvalid {
            try Task.checkCancellation()
            invalidateLease(reference)
            return try await resolveSignedReadURL(
                reference: reference,
                accessToken: accessToken,
                expectedScope: expectedScope,
                forceRefresh: true
            )
        }
    }

    private func enqueueReadWaiter(
        _ waiter: ReadWaiter,
        reference: ProductImageReference,
        key: ReadBatchKey,
        accessToken: String,
        expectedScope: String
    ) {
        var batch = pendingReadBatches[key] ?? PendingReadBatch(
            scope: reference.scope,
            accessToken: accessToken,
            expectedCacheScope: expectedScope,
            waiters: [:],
            scheduledFlush: nil
        )
        batch.waiters[reference, default: []].append(waiter)
        if batch.scheduledFlush == nil {
            batch.scheduledFlush = Task {
                try? await Task.sleep(nanoseconds: self.readBatchDelayNanoseconds)
                guard !Task.isCancelled else { return }
                self.flushReadBatch(key: key)
            }
        }
        pendingReadBatches[key] = batch

        if batch.waiters.count >= ProductImageAPIClient.readURLBatchMaximum,
           var ready = pendingReadBatches.removeValue(forKey: key) {
            ready.scheduledFlush?.cancel()
            ready.scheduledFlush = nil
            startReadBatch(ready)
        }
    }

    private func flushReadBatch(key: ReadBatchKey) {
        guard var batch = pendingReadBatches.removeValue(forKey: key) else { return }
        batch.scheduledFlush = nil
        startReadBatch(batch)
    }

    private func startReadBatch(_ batch: PendingReadBatch) {
        let references = batch.waiters.keys.sorted { lhs, rhs in
            let lhsKey = "\(lhs.productID.uuidString)/\(lhs.versionID.uuidString)/\(lhs.variant.rawValue)"
            let rhsKey = "\(rhs.productID.uuidString)/\(rhs.versionID.uuidString)/\(rhs.variant.rawValue)"
            return lhsKey < rhsKey
        }
        let batchID = UUID()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.runReadBatch(id: batchID)
        }
        activeReadBatches[batchID] = ActiveReadBatch(
            batch: batch,
            references: references,
            task: task
        )
    }

    private func runReadBatch(id: UUID) async {
        guard let active = activeReadBatches[id] else { return }
        do {
            try Task.checkCancellation()
            try authorize(active.batch.scope)
            let permit = try await readRequestGate.acquire()
            let response: ProductImageReadResponse
            do {
                try Task.checkCancellation()
                try authorize(active.batch.scope)
                response = try await api.resolveReadURLs(
                    references: active.references,
                    accessToken: active.batch.accessToken
                )
                await readRequestGate.release(permit)
            } catch {
                await readRequestGate.release(permit)
                throw error
            }
            try Task.checkCancellation()
            try authorize(active.batch.scope)
            finishReadBatch(id: id, response: response)
        } catch {
            finishReadBatch(id: id, error: error)
        }
    }

    private func finishReadBatch(id: UUID, response: ProductImageReadResponse) {
        guard let active = activeReadBatches.removeValue(forKey: id) else { return }
        let batch = active.batch
        let references = active.references
        guard response.ok == true,
              response.cacheScope == batch.expectedCacheScope,
              ProductImageCache.isValidCacheScope(batch.expectedCacheScope),
              let items = response.items,
              items.count == references.count else {
            finishReadBatch(batch, error: ProductImageError.invalidResponse)
            return
        }

        var leases: [ProductImageReference: SignedReadLease] = [:]
        let receivedAt = now()
        for (index, item) in items.enumerated() {
            let reference = ProductImageReference(
                scope: batch.scope,
                productID: item.productId,
                versionID: item.versionId,
                variant: item.variant
            )
            // The server contract preserves request order.  A set comparison
            // would permit a valid URL/metadata pair to be reassigned to a
            // different product/version in the same batch.
            guard reference == references[index] else {
                finishReadBatch(batch, error: ProductImageError.invalidResponse)
                return
            }
            if item.status == "not_found" {
                guard item.signedUrl == nil,
                      item.metadata == nil,
                      item.expiresAt == nil else {
                    finishReadBatch(batch, error: ProductImageError.invalidResponse)
                    return
                }
                continue
            }
            guard item.status == "ready",
                  let signedURL = item.signedUrl,
                  !signedURL.isEmpty,
                  let metadata = item.metadata,
                  metadata.isValid(for: reference.variant),
                  let expiresAtValue = item.expiresAt,
                  let expiresAt = SupabaseRemoteDateParser.parse(expiresAtValue) else {
                finishReadBatch(batch, error: ProductImageError.invalidResponse)
                return
            }
            let lease = SignedReadLease(
                        expiresAt: expiresAt,
                        metadata: metadata,
                        signedURL: signedURL
                    )
            guard isRuntimeLeaseValid(lease, at: receivedAt),
                  leases.updateValue(lease, forKey: reference) == nil else {
                finishReadBatch(batch, error: ProductImageError.signedURLInvalid)
                return
            }
        }
        for (reference, waiters) in batch.waiters {
            if let lease = leases[reference] {
                storeLease(lease, for: reference)
                waiters.forEach { $0.continuation.resume(returning: lease) }
            } else {
                waiters.forEach { $0.continuation.resume(throwing: ProductImageError.notFound) }
            }
        }
    }

    private func isRuntimeLeaseValid(_ lease: SignedReadLease, at referenceDate: Date) -> Bool {
        let remainingLifetime = lease.expiresAt.timeIntervalSince(referenceDate)
        return remainingLifetime > signedURLSafetyWindow
            && remainingLifetime <= signedURLTTLSeconds + signedURLClockSkewAllowance
    }

    private func finishReadBatch(id: UUID, error: Error) {
        guard let active = activeReadBatches.removeValue(forKey: id) else { return }
        finishReadBatch(active.batch, error: error)
    }

    private func finishReadBatch(_ batch: PendingReadBatch, error: Error) {
        for waiters in batch.waiters.values {
            waiters.forEach { $0.continuation.resume(throwing: error) }
        }
    }

    private func cancelReadWaiter(
        key: ReadBatchKey,
        reference: ProductImageReference,
        waiterID: UUID
    ) {
        if var batch = pendingReadBatches[key],
           var waiters = batch.waiters[reference],
           let index = waiters.firstIndex(where: { $0.id == waiterID }) {
            let waiter = waiters.remove(at: index)
            waiter.continuation.resume(throwing: CancellationError())
            if waiters.isEmpty {
                batch.waiters.removeValue(forKey: reference)
            } else {
                batch.waiters[reference] = waiters
            }
            if batch.waiters.isEmpty {
                batch.scheduledFlush?.cancel()
                pendingReadBatches.removeValue(forKey: key)
            } else {
                pendingReadBatches[key] = batch
            }
            return
        }

        for batchID in Array(activeReadBatches.keys) {
            guard var active = activeReadBatches[batchID],
                  active.batch.scope == key.scope,
                  var waiters = active.batch.waiters[reference],
                  let index = waiters.firstIndex(where: { $0.id == waiterID }) else {
                continue
            }
            let waiter = waiters.remove(at: index)
            waiter.continuation.resume(throwing: CancellationError())
            if waiters.isEmpty {
                active.batch.waiters.removeValue(forKey: reference)
            } else {
                active.batch.waiters[reference] = waiters
            }
            if active.batch.waiters.isEmpty {
                activeReadBatches.removeValue(forKey: batchID)
                active.task.cancel()
            } else {
                activeReadBatches[batchID] = active
            }
            return
        }
    }

    private func cancelPendingReadBatches(scope: ProductImageScope) {
        let keys = pendingReadBatches.keys.filter { $0.scope == scope }
        for key in keys {
            guard let batch = pendingReadBatches.removeValue(forKey: key) else { continue }
            batch.scheduledFlush?.cancel()
            finishReadBatch(batch, error: CancellationError())
        }
        let activeIDs = activeReadBatches.compactMap { id, active in
            active.batch.scope == scope ? id : nil
        }
        for id in activeIDs {
            guard let active = activeReadBatches.removeValue(forKey: id) else { continue }
            active.task.cancel()
            finishReadBatch(active.batch, error: CancellationError())
        }
    }

    private func cancelAllReadBatches() {
        for key in Array(pendingReadBatches.keys) {
            guard let batch = pendingReadBatches.removeValue(forKey: key) else { continue }
            batch.scheduledFlush?.cancel()
            finishReadBatch(batch, error: CancellationError())
        }
        for id in Array(activeReadBatches.keys) {
            guard let active = activeReadBatches.removeValue(forKey: id) else { continue }
            active.task.cancel()
            finishReadBatch(active.batch, error: CancellationError())
        }
    }

    private func cancelReadWaiters(
        matching predicate: (ProductImageReference) -> Bool
    ) {
        for key in Array(pendingReadBatches.keys) {
            guard var batch = pendingReadBatches[key] else { continue }
            let references = batch.waiters.keys.filter(predicate)
            for reference in references {
                guard let waiters = batch.waiters.removeValue(forKey: reference) else { continue }
                waiters.forEach { $0.continuation.resume(throwing: CancellationError()) }
            }
            if batch.waiters.isEmpty {
                batch.scheduledFlush?.cancel()
                pendingReadBatches.removeValue(forKey: key)
            } else {
                pendingReadBatches[key] = batch
            }
        }

        for id in Array(activeReadBatches.keys) {
            guard var active = activeReadBatches[id] else { continue }
            let references = active.batch.waiters.keys.filter(predicate)
            for reference in references {
                guard let waiters = active.batch.waiters.removeValue(forKey: reference) else { continue }
                waiters.forEach { $0.continuation.resume(throwing: CancellationError()) }
            }
            if active.batch.waiters.isEmpty {
                activeReadBatches.removeValue(forKey: id)
                active.task.cancel()
            } else {
                activeReadBatches[id] = active
            }
        }
    }

    private func productLoadEpoch(scope: ProductImageScope, productID: UUID) -> UInt64 {
        productLoadEpochs[ProductKey(scope: scope, productID: productID), default: 0]
    }

    private func ensureCurrentProductEpoch(
        _ expectedEpoch: UInt64,
        scope: ProductImageScope,
        productID: UUID
    ) throws {
        guard productLoadEpoch(scope: scope, productID: productID) == expectedEpoch else {
            throw CancellationError()
        }
    }

    private func ensureLoadAllowed(
        _ expectedEpoch: UInt64,
        scope: ProductImageScope,
        productID: UUID
    ) throws {
        try ensureCurrentProductEpoch(
            expectedEpoch,
            scope: scope,
            productID: productID
        )
        guard activeProductMutations[ProductKey(scope: scope, productID: productID)] == nil else {
            throw CancellationError()
        }
        guard lifecycleGeneration == 0 || activeScope == scope else {
            throw ProductImageError.accountChanged
        }
    }

    private func beginProductMutation(
        scope: ProductImageScope,
        productID: UUID
    ) throws -> UUID {
        let key = ProductKey(scope: scope, productID: productID)
        guard activeProductMutations[key] == nil else {
            throw ProductImageError.invalidResponse
        }
        let mutationID = UUID()
        activeProductMutations[key] = mutationID
        invalidateProductLoads(scope: scope, productID: productID)
        return mutationID
    }

    private func finishProductMutation(
        scope: ProductImageScope,
        productID: UUID,
        mutationID: UUID
    ) {
        let key = ProductKey(scope: scope, productID: productID)
        guard activeProductMutations[key] == mutationID else { return }
        activeProductMutations.removeValue(forKey: key)
    }

    private func invalidateProductLoads(scope: ProductImageScope, productID: UUID) {
        let key = ProductKey(scope: scope, productID: productID)
        productLoadEpochs[key, default: 0] &+= 1
        let references = inFlightLoads.keys.filter {
            $0.scope == scope && $0.productID == productID
        }
        for reference in references {
            if let load = inFlightLoads.removeValue(forKey: reference) {
                load.task.cancel()
            }
        }
        cancelReadWaiters(matching: {
            $0.scope == scope && $0.productID == productID
        })
        invalidateLeases(scope: scope, productID: productID)
    }

    private func storeLease(_ lease: SignedReadLease, for reference: ProductImageReference) {
        signedURLLeases[reference] = lease
        touchLease(reference)
        while signedURLLeaseOrder.count > Self.maximumSignedURLLeases {
            invalidateLease(signedURLLeaseOrder[0])
        }
    }

    private func touchLease(_ reference: ProductImageReference) {
        signedURLLeaseOrder.removeAll { $0 == reference }
        signedURLLeaseOrder.append(reference)
    }

    private func invalidateLease(_ reference: ProductImageReference) {
        signedURLLeases.removeValue(forKey: reference)
        signedURLLeaseOrder.removeAll { $0 == reference }
    }

    private func invalidateLeases(
        scope: ProductImageScope,
        purgeAccountScope: Bool = false,
        productID: UUID? = nil
    ) {
        let references = signedURLLeases.keys.filter { reference in
            let matchesScope = purgeAccountScope
                ? reference.scope.accountID == scope.accountID
                : reference.scope == scope
            return matchesScope && (productID == nil || reference.productID == productID)
        }
        references.forEach(invalidateLease)
    }

    private func downloadReadData(
        signedURL: String,
        reference: ProductImageReference
    ) async throws -> Data {
        let permit = try await downloadGate.acquire()
        do {
            try Task.checkCancellation()
            try authorize(reference.scope)
            let data = try await api.downloadJPEG(
                signedURL: signedURL,
                expectedReference: reference
            )
            await downloadGate.release(permit)
            return data
        } catch let error as URLError where error.code == .notConnectedToInternet {
            await downloadGate.release(permit)
            throw ProductImageError.offlineNotCached
        } catch {
            await downloadGate.release(permit)
            throw error
        }
    }

    private func validSession(for scope: ProductImageScope) async throws -> ProductImageSessionSnapshot {
        try authorize(scope)
        guard let session = await sessionProvider() else {
            throw ProductImageError.unauthenticated
        }
        try Task.checkCancellation()
        try authorize(scope)
        guard session.accountID == scope.accountID else {
            throw ProductImageError.accountChanged
        }
        return session
    }

    private func validMutationSession(
        for scope: ProductImageScope,
        productID: UUID,
        mutationID: UUID,
        expectedLifecycleGeneration: Int
    ) async throws -> ProductImageSessionSnapshot {
        try Task.checkCancellation()
        try ensureMutationCurrent(
            scope: scope,
            productID: productID,
            mutationID: mutationID,
            expectedLifecycleGeneration: expectedLifecycleGeneration
        )
        let session = try await validSession(for: scope)
        try ensureMutationCurrent(
            scope: scope,
            productID: productID,
            mutationID: mutationID,
            expectedLifecycleGeneration: expectedLifecycleGeneration
        )
        return session
    }

    private func ensureMutationCurrent(
        scope: ProductImageScope,
        productID: UUID,
        mutationID: UUID,
        expectedLifecycleGeneration: Int
    ) throws {
        guard lifecycleGeneration == expectedLifecycleGeneration,
              expectedLifecycleGeneration == 0 || activeScope == scope,
              activeProductMutations[ProductKey(scope: scope, productID: productID)] == mutationID,
              scopeAuthorizationProvider(scope) else {
            throw ProductImageError.accountChanged
        }
    }

    /// Once finalize/remove has started, cancellation cannot make the remote
    /// commit disappear. Revalidate owner/shop without inheriting the caller's
    /// cancellation, while still refusing to publish into a scope that changed.
    private func validCommittedSession(
        for scope: ProductImageScope,
        expectedLifecycleGeneration: Int
    ) async throws -> ProductImageSessionSnapshot {
        guard scopeAuthorizationProvider(scope),
              lifecycleGeneration == expectedLifecycleGeneration,
              expectedLifecycleGeneration == 0 || activeScope == scope else {
            throw ProductImageError.accountChanged
        }
        guard let session = await sessionProvider() else {
            throw ProductImageError.unauthenticated
        }
        guard scopeAuthorizationProvider(scope),
              lifecycleGeneration == expectedLifecycleGeneration,
              expectedLifecycleGeneration == 0 || activeScope == scope,
              session.accountID == scope.accountID else {
            throw ProductImageError.accountChanged
        }
        return session
    }

    private func authorize(_ scope: ProductImageScope) throws {
        guard scopeAuthorizationProvider(scope) else {
            throw ProductImageError.invalidScope
        }
    }

    private func reconcileCommittedUploadCache(
        prepared: PreparedProductImage,
        cacheScope: String,
        scope: ProductImageScope,
        productID: UUID,
        versionID: UUID,
        mutationID: UUID,
        expectedLifecycleGeneration: Int
    ) async throws {
        try ensureMutationCurrent(
            scope: scope,
            productID: productID,
            mutationID: mutationID,
            expectedLifecycleGeneration: expectedLifecycleGeneration
        )
        await seedCache(
            prepared: prepared,
            cacheScope: cacheScope,
            scope: scope,
            productID: productID,
            versionID: versionID,
            honorCancellation: false
        )

        do {
            try ensureMutationCurrent(
                scope: scope,
                productID: productID,
                mutationID: mutationID,
                expectedLifecycleGeneration: expectedLifecycleGeneration
            )
        } catch {
            await purgeProductCache(
                cacheScope: cacheScope,
                scope: scope,
                productID: productID
            )
            throw error
        }
    }

    private func purgeProductCache(
        cacheScope: String,
        scope: ProductImageScope,
        productID: UUID
    ) async {
        let cache = self.cache
        await Task.detached(priority: .utility) {
            try? await cache.purgeProduct(
                cacheScope: cacheScope,
                shopID: scope.shopID,
                productID: productID,
                keeping: nil
            )
        }.value
    }

    private func seedCache(
        prepared: PreparedProductImage,
        cacheScope: String,
        scope: ProductImageScope,
        productID: UUID,
        versionID: UUID,
        honorCancellation: Bool = true
    ) async {
        let mainKey = ProductImageCacheKey(
            cacheScope: cacheScope,
            shopID: scope.shopID,
            productID: productID,
            versionID: versionID,
            variant: .main
        )
        let thumbKey = ProductImageCacheKey(
            cacheScope: cacheScope,
            shopID: scope.shopID,
            productID: productID,
            versionID: versionID,
            variant: .thumb
        )
        if honorCancellation {
            guard !Task.isCancelled else { return }
            try? await cache.write(prepared.main.data, for: mainKey)
            guard !Task.isCancelled else { return }
            try? await cache.write(prepared.thumb.data, for: thumbKey)
            guard !Task.isCancelled else { return }
            try? await cache.purgeProduct(
                cacheScope: cacheScope,
                shopID: scope.shopID,
                productID: productID,
                keeping: versionID
            )
            return
        }

        let cache = self.cache
        await Task.detached(priority: .utility) {
            try? await cache.write(prepared.main.data, for: mainKey)
            try? await cache.write(prepared.thumb.data, for: thumbKey)
            try? await cache.purgeProduct(
                cacheScope: cacheScope,
                shopID: scope.shopID,
                productID: productID,
                keeping: versionID
            )
        }.value
    }
}
