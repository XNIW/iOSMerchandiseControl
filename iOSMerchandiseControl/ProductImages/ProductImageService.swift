import CryptoKit
import Foundation

nonisolated struct ProductImageLoadResult: Sendable {
    let cacheKey: ProductImageCacheKey
    let data: Data
    let source: String
}

actor ProductImageService {
    typealias SessionProvider = @Sendable () async -> ProductImageSessionSnapshot?

    private let api: ProductImageAPIClient
    private let cache: ProductImageCache
    private let sessionProvider: SessionProvider

    init(
        apiBaseURL: URL,
        storageBaseURL: URL,
        cache: ProductImageCache = ProductImageCache(),
        sessionProvider: @escaping SessionProvider
    ) {
        self.api = ProductImageAPIClient(
            apiBaseURL: apiBaseURL,
            storageBaseURL: storageBaseURL
        )
        self.cache = cache
        self.sessionProvider = sessionProvider
    }

    init(
        api: ProductImageAPIClient,
        cache: ProductImageCache,
        sessionProvider: @escaping SessionProvider
    ) {
        self.api = api
        self.cache = cache
        self.sessionProvider = sessionProvider
    }

    func load(_ reference: ProductImageReference) async throws -> ProductImageLoadResult {
        let expectedScope = Self.expectedCacheScope(accountID: reference.scope.accountID)
        let key = ProductImageCacheKey(
            cacheScope: expectedScope,
            shopID: reference.scope.shopID,
            productID: reference.productID,
            versionID: reference.versionID,
            variant: reference.variant
        )
        if let cached = try? await cache.read(key) {
            return ProductImageLoadResult(cacheKey: key, data: cached, source: "cache")
        }

        let session = try await validSession(for: reference.scope)
        let signedURL = try await resolveSignedReadURL(
            reference: reference,
            accessToken: session.accessToken,
            expectedScope: expectedScope
        )
        let data: Data
        do {
            data = try await downloadReadData(
                signedURL: signedURL,
                maximumBytes: reference.variant.maxBytes
            )
        } catch ProductImageError.downloadFailed(let status) where status == 401 || status == 403 {
            let refreshSession = try await validSession(for: reference.scope)
            let refreshedURL = try await resolveSignedReadURL(
                reference: reference,
                accessToken: refreshSession.accessToken,
                expectedScope: expectedScope
            )
            data = try await downloadReadData(
                signedURL: refreshedURL,
                maximumBytes: reference.variant.maxBytes
            )
        }
        _ = try await validSession(for: reference.scope)
        try? await cache.write(data, for: key)
        try? await cache.purgeProduct(
            cacheScope: expectedScope,
            shopID: reference.scope.shopID,
            productID: reference.productID,
            keeping: reference.versionID
        )
        return ProductImageLoadResult(cacheKey: key, data: data, source: "network")
    }

    func upload(
        prepared: PreparedProductImage,
        scope: ProductImageScope,
        productID: UUID
    ) async throws -> ProductImageUploadResult {
        _ = try await validSession(for: scope)
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
            await seedCache(
                prepared: prepared,
                cacheScope: expectedScope,
                scope: scope,
                productID: productID,
                versionID: versionID
            )
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
        _ = try await validSession(for: scope)
        async let mainUpload: Void = api.uploadJPEG(prepared.main.data, signedURL: mainUploadURL)
        async let thumbUpload: Void = api.uploadJPEG(prepared.thumb.data, signedURL: thumbUploadURL)
        _ = try await (mainUpload, thumbUpload)

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
        _ = try await validSession(for: scope)
        await seedCache(
            prepared: prepared,
            cacheScope: expectedScope,
            scope: scope,
            productID: productID,
            versionID: versionID
        )
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
        let expectedScope = Self.expectedCacheScope(accountID: scope.accountID)
        _ = try await validSession(for: scope)
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

    private func resolveSignedReadURL(
        reference: ProductImageReference,
        accessToken: String,
        expectedScope: String
    ) async throws -> String {
        let response: ProductImageReadResponse
        do {
            response = try await api.resolveReadURL(
                reference: reference,
                accessToken: accessToken
            )
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw ProductImageError.offlineNotCached
        }
        guard response.ok == true,
              response.cacheScope == expectedScope,
              ProductImageCache.isValidCacheScope(expectedScope),
              let items = response.items,
              items.count == 1,
              let item = items.first,
              item.productId == reference.productID,
              item.versionId == reference.versionID,
              item.variant == reference.variant,
              item.status == "ready",
              let signedURL = item.signedUrl,
              !signedURL.isEmpty else {
            throw ProductImageError.invalidResponse
        }
        return signedURL
    }

    private func downloadReadData(
        signedURL: String,
        maximumBytes: Int
    ) async throws -> Data {
        do {
            return try await api.downloadJPEG(
                signedURL: signedURL,
                maximumBytes: maximumBytes
            )
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw ProductImageError.offlineNotCached
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
        try? await cache.write(prepared.thumb.data, for: thumbKey)
        try? await cache.purgeProduct(
            cacheScope: cacheScope,
            shopID: scope.shopID,
            productID: productID,
            keeping: versionID
        )
    }
}
