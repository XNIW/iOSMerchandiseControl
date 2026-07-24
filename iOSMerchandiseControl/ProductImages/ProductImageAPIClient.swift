import Foundation

nonisolated struct ProductImageIntentResponse: Decodable, Sendable {
    let cacheScope: String?
    let expiresAt: String?
    let mainUploadUrl: String?
    let ok: Bool?
    let status: String?
    let thumbUploadUrl: String?
    let versionId: UUID?
}

nonisolated struct ProductImageFinalizeResponse: Decodable, Sendable {
    let imageUpdatedAt: String?
    let ok: Bool?
    let status: String?
    let versionId: UUID?
}

nonisolated struct ProductImageRemoveResponse: Decodable, Sendable {
    let cleanupStatus: String?
    let currentImageVersionId: UUID?
    let hasCurrentImageVersionId: Bool
    let imageUpdatedAt: String?
    let ok: Bool?
    let operation: String?
    let productId: UUID?
    let shopId: UUID?
    let status: String?
    let versionId: UUID?

    private enum CodingKeys: String, CodingKey {
        case cleanupStatus
        case currentImageVersionId
        case imageUpdatedAt
        case ok
        case operation
        case productId
        case shopId
        case status
        case versionId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cleanupStatus = try container.decodeIfPresent(String.self, forKey: .cleanupStatus)
        hasCurrentImageVersionId = container.contains(.currentImageVersionId)
        currentImageVersionId = try container.decodeIfPresent(UUID.self, forKey: .currentImageVersionId)
        imageUpdatedAt = try container.decodeIfPresent(String.self, forKey: .imageUpdatedAt)
        ok = try container.decodeIfPresent(Bool.self, forKey: .ok)
        operation = try container.decodeIfPresent(String.self, forKey: .operation)
        productId = try container.decodeIfPresent(UUID.self, forKey: .productId)
        shopId = try container.decodeIfPresent(UUID.self, forKey: .shopId)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        versionId = try container.decodeIfPresent(UUID.self, forKey: .versionId)
    }
}

nonisolated struct ProductImageReadResponse: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        let expiresAt: String?
        let metadata: ProductImageMetadata?
        let productId: UUID
        let signedUrl: String?
        let status: String
        let variant: ProductImageVariant
        let versionId: UUID
    }

    let cacheScope: String?
    let items: [Item]?
    let ok: Bool?
}

private final class ProductImageNoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

actor ProductImageAPIClient {
    // Frozen V6 read contract: metadata-verified leases are bounded to 16
    // references and the server preserves that request order exactly.
    static let readURLBatchMaximum = 16
    static let uploadResponseMaximumBytes = 4 * 1_024

    private enum SignedURLMode {
        case upload
        case read
    }

    private struct IntentRequest: Encodable {
        let main: ProductImageMetadata
        let productId: UUID
        let shopId: UUID
        let thumb: ProductImageMetadata
    }

    private struct FinalizeRequest: Encodable {
        let productId: UUID
        let shopId: UUID
        let versionId: UUID
    }

    private struct RemoveRequest: Encodable {
        let expectedVersionId: UUID
        let productId: UUID
        let shopId: UUID
    }

    private struct ReadRequest: Encodable {
        struct Ref: Encodable {
            let productId: UUID
            let variant: ProductImageVariant
            let versionId: UUID
        }

        let refs: [Ref]
        let shopId: UUID
    }

    private let apiBaseURL: URL
    private let apiSession: URLSession
    private let storageBaseURL: URL
    private let storageSession: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(apiBaseURL: URL, storageBaseURL: URL) {
        self.apiBaseURL = apiBaseURL
        self.storageBaseURL = storageBaseURL
        let delegate = ProductImageNoRedirectDelegate()
        let apiConfiguration = URLSessionConfiguration.ephemeral
        apiConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        apiConfiguration.urlCache = nil
        apiConfiguration.httpCookieStorage = nil
        apiConfiguration.httpShouldSetCookies = false
        apiConfiguration.timeoutIntervalForRequest = 30
        apiConfiguration.timeoutIntervalForResource = 45
        self.apiSession = URLSession(
            configuration: apiConfiguration,
            delegate: delegate,
            delegateQueue: nil
        )

        let storageConfiguration = URLSessionConfiguration.ephemeral
        storageConfiguration.requestCachePolicy = .reloadIgnoringLocalCacheData
        storageConfiguration.urlCache = nil
        storageConfiguration.httpCookieStorage = nil
        storageConfiguration.httpShouldSetCookies = false
        storageConfiguration.timeoutIntervalForRequest = 45
        storageConfiguration.timeoutIntervalForResource = 60
        self.storageSession = URLSession(
            configuration: storageConfiguration,
            delegate: delegate,
            delegateQueue: nil
        )
    }

    init(
        apiBaseURL: URL,
        storageBaseURL: URL,
        apiSession: URLSession,
        storageSession: URLSession
    ) {
        self.apiBaseURL = apiBaseURL
        self.storageBaseURL = storageBaseURL
        self.apiSession = apiSession
        self.storageSession = storageSession
    }

    func createIntent(
        scope: ProductImageScope,
        productID: UUID,
        prepared: PreparedProductImage,
        accessToken: String
    ) async throws -> ProductImageIntentResponse {
        return try await post(
            path: "api/shop/product-images/intent",
            body: IntentRequest(
                main: prepared.main.metadata,
                productId: productID,
                shopId: scope.shopID,
                thumb: prepared.thumb.metadata
            ),
            accessToken: accessToken
        )
    }

    func finalize(
        scope: ProductImageScope,
        productID: UUID,
        versionID: UUID,
        accessToken: String
    ) async throws -> ProductImageFinalizeResponse {
        try await post(
            path: "api/shop/product-images/finalize",
            body: FinalizeRequest(productId: productID, shopId: scope.shopID, versionId: versionID),
            accessToken: accessToken
        )
    }

    func remove(
        scope: ProductImageScope,
        productID: UUID,
        versionID: UUID,
        accessToken: String
    ) async throws -> ProductImageRemoveResponse {
        try await post(
            path: "api/shop/product-images/remove",
            body: RemoveRequest(
                expectedVersionId: versionID,
                productId: productID,
                shopId: scope.shopID
            ),
            accessToken: accessToken
        )
    }

    func resolveReadURL(
        reference: ProductImageReference,
        accessToken: String
    ) async throws -> ProductImageReadResponse {
        try await resolveReadURLs(references: [reference], accessToken: accessToken)
    }

    func resolveReadURLs(
        references: [ProductImageReference],
        accessToken: String
    ) async throws -> ProductImageReadResponse {
        var seen = Set<ProductImageReference>()
        let uniqueReferences = references.filter { seen.insert($0).inserted }
        guard let first = uniqueReferences.first,
              uniqueReferences.count <= Self.readURLBatchMaximum,
              uniqueReferences.allSatisfy({ $0.scope == first.scope }) else {
            throw ProductImageError.invalidResponse
        }
        return try await post(
            path: "api/shop/product-images/read-urls",
            body: ReadRequest(
                refs: uniqueReferences.map {
                    ReadRequest.Ref(
                        productId: $0.productID,
                        variant: $0.variant,
                        versionId: $0.versionID
                    )
                },
                shopId: first.scope.shopID
            ),
            accessToken: accessToken
        )
    }

    func uploadJPEG(
        _ data: Data,
        signedURL: String,
        expectedReference: ProductImageReference
    ) async throws {
        let url = try validatedSignedURL(
            signedURL,
            mode: .upload,
            expectedReference: expectedReference
        )
        guard !data.isEmpty,
              data.count <= expectedReference.variant.maxBytes,
              ProductImageProcessor.isJPEG(data),
              !ProductImageProcessor.containsForbiddenMetadata(data) else {
            throw ProductImageError.encodeFailed
        }
        let boundary = "task137-\(UUID().uuidString.lowercased())"
        var body = Data()
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"cacheControl\"\r\n\r\n")
        body.appendUTF8("3600\r\n")
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"\"; filename=\"image.jpg\"\r\n")
        body.appendUTF8("Content-Type: image/jpeg\r\n\r\n")
        body.append(data)
        body.appendUTF8("\r\n--\(boundary)--\r\n")

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = body
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("false", forHTTPHeaderField: "x-upsert")
        for attempt in 0...1 {
            try Task.checkCancellation()
            do {
                _ = try await BoundedURLSessionDataLoader.data(
                    for: request,
                    configuration: storageSession.configuration,
                    maximumBytes: Self.uploadResponseMaximumBytes
                ) { http in
                    guard (200..<300).contains(http.statusCode) else {
                        throw ProductImageError.uploadFailed(status: http.statusCode)
                    }
                }
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch is BoundedHTTPBodyError {
                throw ProductImageError.invalidResponse
            } catch ProductImageError.uploadFailed(let status)
                where attempt == 0 && (500..<600).contains(status) {
                continue
            } catch let error as URLError where attempt == 0 && Self.isTransientUploadError(error) {
                continue
            } catch {
                throw error
            }
        }
        throw ProductImageError.invalidResponse
    }

    func downloadJPEG(
        signedURL: String,
        expectedReference: ProductImageReference
    ) async throws -> Data {
        let maximumBytes = expectedReference.variant.maxBytes
        let url = try validatedSignedURL(
            signedURL,
            mode: .read,
            expectedReference: expectedReference
        )
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let data: Data
        do {
            let bounded = try await BoundedURLSessionDataLoader.data(
                for: request,
                configuration: storageSession.configuration,
                maximumBytes: maximumBytes
            ) { http in
                guard (200..<300).contains(http.statusCode) else {
                    throw ProductImageError.downloadFailed(status: http.statusCode)
                }
                let contentType = http.value(forHTTPHeaderField: "Content-Type")?
                    .split(separator: ";", maxSplits: 1)
                    .first?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                guard contentType == "image/jpeg" else {
                    throw ProductImageError.downloadedImageInvalid
                }
            }
            data = bounded.0
        } catch is BoundedHTTPBodyError {
            throw ProductImageError.downloadedImageInvalid
        }
        guard !data.isEmpty,
              data.count <= maximumBytes,
              ProductImageProcessor.isJPEG(data),
              !ProductImageProcessor.containsForbiddenMetadata(data) else {
            throw ProductImageError.downloadedImageInvalid
        }
        return data
    }

    private func post<Request: Encodable, Response: Decodable>(
        path: String,
        body: Request,
        accessToken: String
    ) async throws -> Response {
        guard !accessToken.isEmpty,
              !accessToken.contains("\n"),
              !accessToken.contains("\r") else {
            throw ProductImageError.unauthenticated
        }
        let url = apiBaseURL.appendingPathComponent(path, isDirectory: false)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let data: Data
        do {
            let bounded = try await BoundedURLSessionDataLoader.data(
                for: request,
                configuration: apiSession.configuration,
                maximumBytes: 64 * 1_024
            ) { http in
                guard (200..<300).contains(http.statusCode) else {
                    throw ProductImageError.requestFailed(status: http.statusCode)
                }
            }
            data = bounded.0
        } catch is BoundedHTTPBodyError {
            throw ProductImageError.invalidResponse
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw ProductImageError.invalidResponse
        }
    }

    private func validatedSignedURL(
        _ value: String,
        mode: SignedURLMode,
        expectedReference: ProductImageReference
    ) throws -> URL {
        guard let url = URL(string: value),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.user == nil,
              components.password == nil,
              components.fragment == nil,
              let host = components.host?.lowercased(),
              !host.isEmpty else {
            throw ProductImageError.signedURLInvalid
        }
        let localHTTP: Bool
#if DEBUG && targetEnvironment(simulator)
        localHTTP = components.scheme?.lowercased() == "http"
            && (host == "localhost" || host == "127.0.0.1" || host == "::1")
#else
        localHTTP = false
#endif
        guard components.scheme?.lowercased() == "https" || localHTTP else {
            throw ProductImageError.signedURLInvalid
        }
        guard sameOrigin(url, storageBaseURL) else {
            throw ProductImageError.signedURLInvalid
        }
        let marker = switch mode {
        case .upload: "/storage/v1/object/upload/sign/product-images/"
        case .read: "/storage/v1/object/sign/product-images/"
        }
        let objectPath = String(components.percentEncodedPath.dropFirst(marker.count))
            .removingPercentEncoding?
            .lowercased()
        let expectedObjectPath = [
            "shops",
            expectedReference.scope.shopID.uuidString.lowercased(),
            "products",
            expectedReference.productID.uuidString.lowercased(),
            "primary",
            expectedReference.versionID.uuidString.lowercased(),
            "\(expectedReference.variant.rawValue).jpg"
        ].joined(separator: "/")
        guard components.percentEncodedPath.hasPrefix(marker),
              objectPath == expectedObjectPath else {
            throw ProductImageError.signedURLInvalid
        }
        return url
    }

    private func sameOrigin(_ left: URL, _ right: URL) -> Bool {
        left.scheme?.lowercased() == right.scheme?.lowercased()
            && left.host?.lowercased() == right.host?.lowercased()
            && effectivePort(left) == effectivePort(right)
    }

    private func effectivePort(_ url: URL) -> Int? {
        if let port = url.port {
            return port
        }
        switch url.scheme?.lowercased() {
        case "https": return 443
        case "http": return 80
        default: return nil
        }
    }

    private static func isTransientUploadError(_ error: URLError) -> Bool {
        switch error.code {
        case .cannotConnectToHost,
             .dnsLookupFailed,
             .networkConnectionLost,
             .notConnectedToInternet,
             .timedOut:
            return true
        default:
            return false
        }
    }
}

nonisolated private extension Data {
    mutating func appendUTF8(_ value: String) {
        append(contentsOf: value.utf8)
    }
}
