import CryptoKit
import Foundation

nonisolated struct ProductImageLoadResult: Sendable {
    let cacheKey: ProductImageCacheKey
    let data: Data
    let source: String
}

private actor ProductImageDownloadGate {
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
    static let readBatchDelayNanoseconds: UInt64 = 8_000_000
    static let defaultSignedURLSafetyWindow: TimeInterval = 30
    static let maximumSignedURLLeases = 1_000

    private struct SignedReadLease: Sendable {
        let expiresAt: Date
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

    private let api: ProductImageAPIClient
    private let cache: ProductImageCache
    private let downloadGate: ProductImageDownloadGate
    private let now: @Sendable () -> Date
    private let readBatchDelayNanoseconds: UInt64
    private let sessionProvider: SessionProvider
    private let signedURLSafetyWindow: TimeInterval
    private var inFlightLoads: [ProductImageReference: InFlightLoad] = [:]
    private var pendingReadBatches: [ReadBatchKey: PendingReadBatch] = [:]
    private var signedURLLeases: [ProductImageReference: SignedReadLease] = [:]
    private var signedURLLeaseOrder: [ProductImageReference] = []

    init(
        apiBaseURL: URL,
        storageBaseURL: URL,
        cache: ProductImageCache = ProductImageCache(),
        maximumConcurrentDownloads: Int = defaultMaximumConcurrentDownloads,
        readBatchDelayNanoseconds: UInt64 = ProductImageService.readBatchDelayNanoseconds,
        signedURLSafetyWindow: TimeInterval = defaultSignedURLSafetyWindow,
        now: @escaping @Sendable () -> Date = Date.init,
        sessionProvider: @escaping SessionProvider
    ) {
        self.api = ProductImageAPIClient(
            apiBaseURL: apiBaseURL,
            storageBaseURL: storageBaseURL
        )
        self.cache = cache
        self.downloadGate = ProductImageDownloadGate(limit: maximumConcurrentDownloads)
        self.readBatchDelayNanoseconds = readBatchDelayNanoseconds
        self.signedURLSafetyWindow = max(0, signedURLSafetyWindow)
        self.now = now
        self.sessionProvider = sessionProvider
    }

    init(
        api: ProductImageAPIClient,
        cache: ProductImageCache,
        maximumConcurrentDownloads: Int = defaultMaximumConcurrentDownloads,
        readBatchDelayNanoseconds: UInt64 = ProductImageService.readBatchDelayNanoseconds,
        signedURLSafetyWindow: TimeInterval = defaultSignedURLSafetyWindow,
        now: @escaping @Sendable () -> Date = Date.init,
        sessionProvider: @escaping SessionProvider
    ) {
        self.api = api
        self.cache = cache
        self.downloadGate = ProductImageDownloadGate(limit: maximumConcurrentDownloads)
        self.readBatchDelayNanoseconds = readBatchDelayNanoseconds
        self.signedURLSafetyWindow = max(0, signedURLSafetyWindow)
        self.now = now
        self.sessionProvider = sessionProvider
    }

    func load(_ reference: ProductImageReference) async throws -> ProductImageLoadResult {
        try Task.checkCancellation()
        let expectedScope = Self.expectedCacheScope(accountID: reference.scope.accountID)
        let key = ProductImageCacheKey(
            cacheScope: expectedScope,
            shopID: reference.scope.shopID,
            productID: reference.productID,
            versionID: reference.versionID,
            variant: reference.variant
        )
        if let cached = try? await cache.read(key) {
            do {
                try await ProductImageProcessor.validateDownloadedJPEG(cached, variant: reference.variant)
                try Task.checkCancellation()
                return ProductImageLoadResult(cacheKey: key, data: cached, source: "cache")
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                try? await cache.remove(key)
            }
        }

        let waiterID = UUID()
        let task: Task<ProductImageLoadResult, Error>
        if var existing = inFlightLoads[reference] {
            existing.waiterIDs.insert(waiterID)
            task = existing.task
            inFlightLoads[reference] = existing
        } else {
            task = Task {
                try await self.performNetworkLoad(
                    reference,
                    key: key,
                    expectedScope: expectedScope
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
            releaseLoadWaiter(reference: reference, waiterID: waiterID, cancelTaskWhenEmpty: false)
            return result
        } catch {
            releaseLoadWaiter(reference: reference, waiterID: waiterID, cancelTaskWhenEmpty: true)
            throw error
        }
    }

    func cancel(_ reference: ProductImageReference) {
        guard let load = inFlightLoads.removeValue(forKey: reference) else { return }
        load.task.cancel()
    }

    func deactivate(scope: ProductImageScope, purgeAccountScope: Bool) async {
        let references = inFlightLoads.keys.filter { $0.scope == scope }
        for reference in references {
            cancel(reference)
        }
        cancelPendingReadBatches(scope: scope)
        invalidateLeases(scope: scope, purgeAccountScope: purgeAccountScope)

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
        let session = try await validSession(for: scope)
        let expectedScope = Self.expectedCacheScope(accountID: scope.accountID)
        let intent = try await api.createIntent(
            scope: scope,
            productID: productID,
            prepared: prepared,
            accessToken: session.accessToken
        )
        guard intent.ok == true,
              let versionID = intent.versionId,
              intent.cacheScope == expectedScope else {
            throw ProductImageError.invalidResponse
        }

        if intent.status == "noop" {
            try Task.checkCancellation()
            await seedCache(
                prepared: prepared,
                cacheScope: expectedScope,
                scope: scope,
                productID: productID,
                versionID: versionID
            )
            try Task.checkCancellation()
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
        _ = try await validSession(for: scope)
        try await api.uploadJPEG(prepared.main.data, signedURL: mainUploadURL)
        try Task.checkCancellation()
        if let progress { await progress(.uploadingThumb) }
        _ = try await validSession(for: scope)
        try await api.uploadJPEG(prepared.thumb.data, signedURL: thumbUploadURL)
        try Task.checkCancellation()
        if let progress { await progress(.finalizing) }

        let finalizeSession = try await validSession(for: scope)
        let finalized = try await api.finalize(
            scope: scope,
            productID: productID,
            versionID: versionID,
            accessToken: finalizeSession.accessToken
        )
        guard finalized.ok == true,
              finalized.versionId == versionID,
              finalized.status == "finalized" || finalized.status == "already_finalized" else {
            throw ProductImageError.invalidResponse
        }
        try Task.checkCancellation()
        _ = try await validSession(for: scope)
        try Task.checkCancellation()
        invalidateLeases(scope: scope, productID: productID)
        await seedCache(
            prepared: prepared,
            cacheScope: expectedScope,
            scope: scope,
            productID: productID,
            versionID: versionID
        )
        try Task.checkCancellation()
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
        let session = try await validSession(for: scope)
        let response = try await api.remove(
            scope: scope,
            productID: productID,
            versionID: versionID,
            accessToken: session.accessToken
        )
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
        try Task.checkCancellation()
        let expectedScope = Self.expectedCacheScope(accountID: scope.accountID)
        _ = try await validSession(for: scope)
        try Task.checkCancellation()
        invalidateLeases(scope: scope, productID: productID)
        try? await cache.purgeProduct(
            cacheScope: expectedScope,
            shopID: scope.shopID,
            productID: productID,
            keeping: nil
        )
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
        expectedScope: String
    ) async throws -> ProductImageLoadResult {
        try Task.checkCancellation()
        let session = try await validSession(for: reference.scope)
        let signedURL = try await resolveSignedReadURL(
            reference: reference,
            accessToken: session.accessToken,
            expectedScope: expectedScope
        ).signedURL
        try Task.checkCancellation()
        let data: Data
        do {
            data = try await downloadReadData(
                signedURL: signedURL,
                maximumBytes: reference.variant.maxBytes
            )
        } catch ProductImageError.downloadFailed(let status) where status == 401 || status == 403 {
            try Task.checkCancellation()
            invalidateLease(reference)
            let refreshSession = try await validSession(for: reference.scope)
            let refreshedURL = try await resolveSignedReadURL(
                reference: reference,
                accessToken: refreshSession.accessToken,
                expectedScope: expectedScope,
                forceRefresh: true
            ).signedURL
            try Task.checkCancellation()
            data = try await downloadReadData(
                signedURL: refreshedURL,
                maximumBytes: reference.variant.maxBytes
            )
        }
        try Task.checkCancellation()
        try await ProductImageProcessor.validateDownloadedJPEG(data, variant: reference.variant)
        try Task.checkCancellation()
        _ = try await validSession(for: reference.scope)
        try Task.checkCancellation()
        try await cache.write(data, for: key)
        try await cache.purgeProduct(
            cacheScope: expectedScope,
            shopID: reference.scope.shopID,
            productID: reference.productID,
            keeping: reference.versionID
        )
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
            if lease.expiresAt.timeIntervalSince(now()) > signedURLSafetyWindow {
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
        Task {
            do {
                let response = try await api.resolveReadURLs(
                    references: references,
                    accessToken: batch.accessToken
                )
                finishReadBatch(batch, references: references, response: response)
            } catch {
                finishReadBatch(batch, error: error)
            }
        }
    }

    private func finishReadBatch(
        _ batch: PendingReadBatch,
        references: [ProductImageReference],
        response: ProductImageReadResponse
    ) {
        guard response.ok == true,
              response.cacheScope == batch.expectedCacheScope,
              ProductImageCache.isValidCacheScope(batch.expectedCacheScope),
              let items = response.items,
              items.count == references.count else {
            finishReadBatch(batch, error: ProductImageError.invalidResponse)
            return
        }

        let expected = Set(references)
        var leases: [ProductImageReference: SignedReadLease] = [:]
        for item in items {
            let reference = ProductImageReference(
                scope: batch.scope,
                productID: item.productId,
                versionID: item.versionId,
                variant: item.variant
            )
            guard expected.contains(reference),
                  item.status == "ready",
                  let signedURL = item.signedUrl,
                  !signedURL.isEmpty,
                  let expiresAtValue = item.expiresAt,
                  let expiresAt = SupabaseRemoteDateParser.parse(expiresAtValue),
                  leases.updateValue(
                    SignedReadLease(expiresAt: expiresAt, signedURL: signedURL),
                    forKey: reference
                  ) == nil else {
                finishReadBatch(batch, error: ProductImageError.invalidResponse)
                return
            }
        }
        guard leases.count == expected.count else {
            finishReadBatch(batch, error: ProductImageError.invalidResponse)
            return
        }
        for (reference, waiters) in batch.waiters {
            guard let lease = leases[reference] else {
                waiters.forEach { $0.continuation.resume(throwing: ProductImageError.invalidResponse) }
                continue
            }
            if lease.expiresAt.timeIntervalSince(now()) > signedURLSafetyWindow {
                storeLease(lease, for: reference)
            }
            waiters.forEach { $0.continuation.resume(returning: lease) }
        }
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
        guard var batch = pendingReadBatches[key],
              var waiters = batch.waiters[reference],
              let index = waiters.firstIndex(where: { $0.id == waiterID }) else {
            return
        }
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
    }

    private func cancelPendingReadBatches(scope: ProductImageScope) {
        let keys = pendingReadBatches.keys.filter { $0.scope == scope }
        for key in keys {
            guard let batch = pendingReadBatches.removeValue(forKey: key) else { continue }
            batch.scheduledFlush?.cancel()
            finishReadBatch(batch, error: CancellationError())
        }
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
        maximumBytes: Int
    ) async throws -> Data {
        let permit = try await downloadGate.acquire()
        do {
            let data = try await api.downloadJPEG(
                signedURL: signedURL,
                maximumBytes: maximumBytes
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
        guard let session = await sessionProvider() else {
            throw ProductImageError.unauthenticated
        }
        guard session.accountID == scope.accountID else {
            throw ProductImageError.accountChanged
        }
        return session
    }

    private func seedCache(
        prepared: PreparedProductImage,
        cacheScope: String,
        scope: ProductImageScope,
        productID: UUID,
        versionID: UUID
    ) async {
        guard !Task.isCancelled else { return }
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
    }
}
