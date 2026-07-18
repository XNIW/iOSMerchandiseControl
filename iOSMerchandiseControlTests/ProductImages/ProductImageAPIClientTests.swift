import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class ProductImageAPIClientTests: XCTestCase {
    func testUploadRunsIntentTwoDirectPutsFinalizeAndSeedsScopedCache() async throws {
        let accountID = UUID(uuidString: "13700000-0000-4000-8000-000000000001")!
        let shopID = UUID(uuidString: "13700000-0000-4000-8000-000000000002")!
        let productID = UUID(uuidString: "13700000-0000-4000-8000-000000000003")!
        let versionID = UUID(uuidString: "13700000-0000-4000-8000-000000000004")!
        let cacheScope = ProductImageService.expectedCacheScope(accountID: accountID)
        let recorder = ProductImageHTTPRecorder(
            cacheScope: cacheScope,
            versionID: versionID
        )
        ProductImageURLProtocolStub.handler = { request in
            try recorder.respond(to: request)
        }
        defer { ProductImageURLProtocolStub.handler = nil }

        let api = ProductImageAPIClient(
            apiBaseURL: URL(string: "https://admin.task137.invalid")!,
            storageBaseURL: URL(string: "https://storage.task137.invalid")!,
            apiSession: makeSession(),
            storageSession: makeSession()
        )
        let cacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-137-ios-api-tests-\(UUID().uuidString)", isDirectory: true)
        defer {
            if FileManager.default.fileExists(atPath: cacheRoot.path) {
                try? FileManager.default.removeItem(at: cacheRoot)
            }
        }
        let cache = ProductImageCache(rootDirectory: cacheRoot)
        let service = ProductImageService(api: api, cache: cache) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "task-137-test-access")
        }
        let prepared = try makePreparedImage()
        let scope = ProductImageScope(accountID: accountID, shopID: shopID)

        let result: ProductImageUploadResult
        do {
            result = try await service.upload(
                prepared: prepared,
                scope: scope,
                productID: productID
            )
        } catch {
            let requestSummary = recorder.records.map { "\($0.method) \($0.path)" }
            XCTFail("Upload workflow failed after requests: \(requestSummary); error: \(error)")
            return
        }

        XCTAssertEqual(result.status, "finalized")
        XCTAssertEqual(result.versionID, versionID)
        let records = recorder.records
        XCTAssertEqual(records.count, 4)
        XCTAssertEqual(records.first?.method, "POST")
        XCTAssertEqual(records.first?.path, "/api/shop/product-images/intent")
        XCTAssertEqual(records.last?.method, "POST")
        XCTAssertEqual(records.last?.path, "/api/shop/product-images/finalize")

        let apiRequests = records.filter { $0.method == "POST" }
        XCTAssertEqual(apiRequests.count, 2)
        XCTAssertTrue(apiRequests.allSatisfy {
            $0.authorization == "Bearer task-137-test-access"
                && $0.cookie == nil
                && $0.contentType == "application/json"
        })
        let finalizeRequest = try XCTUnwrap(apiRequests.first {
            $0.path == "/api/shop/product-images/finalize"
        })
        let finalizeBody = try XCTUnwrap(finalizeRequest.body)
        let finalizeObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: finalizeBody) as? [String: String]
        )
        XCTAssertEqual(finalizeObject["productId"], productID.uuidString)
        XCTAssertEqual(finalizeObject["shopId"], shopID.uuidString)
        XCTAssertEqual(finalizeObject["versionId"], versionID.uuidString)
        let puts = records.filter { $0.method == "PUT" }
        XCTAssertEqual(puts.count, 2)
        XCTAssertEqual(Set(puts.map(\.path)), Set([
            "/storage/v1/object/upload/sign/product-images/shops/13700000-0000-4000-8000-000000000002/products/13700000-0000-4000-8000-000000000003/primary/\(versionID.uuidString)/main.jpg",
            "/storage/v1/object/upload/sign/product-images/shops/13700000-0000-4000-8000-000000000002/products/13700000-0000-4000-8000-000000000003/primary/\(versionID.uuidString)/thumb.jpg"
        ]))
        XCTAssertTrue(puts.allSatisfy {
            $0.authorization == nil
                && $0.cookie == nil
                && $0.upsert == "false"
                && ($0.contentType?.hasPrefix("multipart/form-data; boundary=task137-") == true)
                && ($0.body?.range(of: Data("Content-Type: image/jpeg".utf8)) != nil)
        })
        let mainPut = try XCTUnwrap(puts.first { $0.path.hasSuffix("main.jpg") })
        let thumbPut = try XCTUnwrap(puts.first { $0.path.hasSuffix("thumb.jpg") })
        XCTAssertNotNil(mainPut.body?.range(of: prepared.main.data))
        XCTAssertNotNil(thumbPut.body?.range(of: prepared.thumb.data))

        let mainKey = ProductImageCacheKey(
            cacheScope: cacheScope,
            shopID: shopID,
            productID: productID,
            versionID: versionID,
            variant: .main
        )
        let thumbKey = ProductImageCacheKey(
            cacheScope: cacheScope,
            shopID: shopID,
            productID: productID,
            versionID: versionID,
            variant: .thumb
        )
        let cachedMain = try await cache.read(mainKey)
        let cachedThumb = try await cache.read(thumbKey)
        XCTAssertEqual(cachedMain, prepared.main.data)
        XCTAssertEqual(cachedThumb, prepared.thumb.data)
    }

    func testReadDownloadsSignedJpegAndSeedsScopedCache() async throws {
        let accountID = UUID(uuidString: "13700000-0000-4000-8000-000000000011")!
        let shopID = UUID(uuidString: "13700000-0000-4000-8000-000000000012")!
        let productID = UUID(uuidString: "13700000-0000-4000-8000-000000000013")!
        let versionID = UUID(uuidString: "13700000-0000-4000-8000-000000000014")!
        let cacheScope = ProductImageService.expectedCacheScope(accountID: accountID)
        let jpeg = try makePreparedImage().thumb.data
        let objectPath = "/storage/v1/object/sign/product-images/shops/\(shopID.uuidString)/products/\(productID.uuidString)/primary/\(versionID.uuidString)/thumb.jpg"
        ProductImageURLProtocolStub.handler = { request in
            guard let url = request.url else { throw ProductImageError.invalidResponse }
            let body: Data
            let contentType: String
            switch (request.httpMethod, url.path) {
            case ("POST", "/api/shop/product-images/read-urls"):
                body = Data("""
                {"cacheScope":"\(cacheScope)","items":[{"expiresAt":"2026-07-17T12:39:56Z","productId":"\(productID.uuidString)","signedUrl":"https://storage.task137.invalid\(objectPath)?token=redacted","status":"ready","variant":"thumb","versionId":"\(versionID.uuidString)"}],"ok":true}
                """.utf8)
                contentType = "application/json"
            case ("GET", objectPath):
                guard request.value(forHTTPHeaderField: "Authorization") == nil,
                      request.value(forHTTPHeaderField: "Cookie") == nil else {
                    throw ProductImageError.invalidResponse
                }
                body = jpeg
                contentType = "image/jpeg"
            default:
                throw ProductImageError.invalidResponse
            }
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": contentType]
            )!
            return (response, body)
        }
        defer { ProductImageURLProtocolStub.handler = nil }

        let cacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-137-ios-read-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cacheRoot) }
        let cache = ProductImageCache(rootDirectory: cacheRoot)
        let api = ProductImageAPIClient(
            apiBaseURL: URL(string: "https://admin.task137.invalid")!,
            storageBaseURL: URL(string: "https://storage.task137.invalid")!,
            apiSession: makeSession(),
            storageSession: makeSession()
        )
        let service = ProductImageService(api: api, cache: cache) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "task-137-test-access")
        }
        let reference = ProductImageReference(
            scope: ProductImageScope(accountID: accountID, shopID: shopID),
            productID: productID,
            versionID: versionID,
            variant: .thumb
        )

        let result = try await service.load(reference)

        XCTAssertEqual(result.source, "network")
        XCTAssertEqual(result.data, jpeg)
        let cachedRead = try await cache.read(result.cacheKey)
        XCTAssertEqual(cachedRead, jpeg)
    }

    func testReadRefreshesExpiredSignedURLExactlyOnce() async throws {
        let accountID = UUID(uuidString: "13700000-0000-4000-8000-000000000041")!
        let shopID = UUID(uuidString: "13700000-0000-4000-8000-000000000042")!
        let productID = UUID(uuidString: "13700000-0000-4000-8000-000000000043")!
        let versionID = UUID(uuidString: "13700000-0000-4000-8000-000000000044")!
        let cacheScope = ProductImageService.expectedCacheScope(accountID: accountID)
        let jpeg = try makePreparedImage().thumb.data
        let objectPath = "/storage/v1/object/sign/product-images/shops/\(shopID.uuidString)/products/\(productID.uuidString)/primary/\(versionID.uuidString)/thumb.jpg"
        let attempts = ProductImageAttemptCounter()
        ProductImageURLProtocolStub.handler = { request in
            guard let url = request.url else { throw ProductImageError.invalidResponse }
            let statusCode: Int
            let body: Data
            let contentType: String
            switch (request.httpMethod, url.path) {
            case ("POST", "/api/shop/product-images/read-urls"):
                let attempt = attempts.recordResolution()
                body = Data("""
                {"cacheScope":"\(cacheScope)","items":[{"productId":"\(productID.uuidString)","signedUrl":"https://storage.task137.invalid\(objectPath)?token=\(attempt == 1 ? "expired" : "fresh")","status":"ready","variant":"thumb","versionId":"\(versionID.uuidString)"}],"ok":true}
                """.utf8)
                contentType = "application/json"
                statusCode = 200
            case ("GET", objectPath):
                let attempt = attempts.recordDownload()
                body = attempt == 1 ? Data() : jpeg
                contentType = attempt == 1 ? "application/json" : "image/jpeg"
                statusCode = attempt == 1 ? 403 : 200
            default:
                throw ProductImageError.invalidResponse
            }
            return (
                HTTPURLResponse(
                    url: url,
                    statusCode: statusCode,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": contentType]
                )!,
                body
            )
        }
        defer { ProductImageURLProtocolStub.handler = nil }

        let cacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-137-ios-refresh-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cacheRoot) }
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: ProductImageCache(rootDirectory: cacheRoot)
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "task-137-test-access")
        }
        let result = try await service.load(ProductImageReference(
            scope: ProductImageScope(accountID: accountID, shopID: shopID),
            productID: productID,
            versionID: versionID,
            variant: .thumb
        ))

        XCTAssertEqual(result.data, jpeg)
        XCTAssertEqual(attempts.snapshot.resolutions, 2)
        XCTAssertEqual(attempts.snapshot.downloads, 2)
    }

    func testRemoveAcceptsExpectedContractAndPurgesScopedCache() async throws {
        let accountID = UUID(uuidString: "13700000-0000-4000-8000-000000000021")!
        let shopID = UUID(uuidString: "13700000-0000-4000-8000-000000000022")!
        let productID = UUID(uuidString: "13700000-0000-4000-8000-000000000023")!
        let versionID = UUID(uuidString: "13700000-0000-4000-8000-000000000024")!
        ProductImageURLProtocolStub.handler = { request in
            guard let url = request.url,
                  request.httpMethod == "POST",
                  url.path == "/api/shop/product-images/remove" else {
                throw ProductImageError.invalidResponse
            }
            let body = Data("""
            {"cleanupStatus":"complete","currentImageVersionId":null,"imageUpdatedAt":"2026-07-17T12:34:56Z","ok":true,"operation":"remove","productId":"\(productID.uuidString)","shopId":"\(shopID.uuidString)","status":"removed","versionId":"\(versionID.uuidString)"}
            """.utf8)
            return (
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )!,
                body
            )
        }
        defer { ProductImageURLProtocolStub.handler = nil }

        let cacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-137-ios-remove-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cacheRoot) }
        let cache = ProductImageCache(rootDirectory: cacheRoot)
        let key = ProductImageCacheKey(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            shopID: shopID,
            productID: productID,
            versionID: versionID,
            variant: .thumb
        )
        try await cache.write(try makePreparedImage().thumb.data, for: key)
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: cache
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "task-137-test-access")
        }

        let result = try await service.remove(
            scope: ProductImageScope(accountID: accountID, shopID: shopID),
            productID: productID,
            versionID: versionID
        )

        XCTAssertEqual(result.status, "removed")
        let cachedAfterRemove = try await cache.read(key)
        XCTAssertNil(cachedAfterRemove)
    }

    func testRemoveRejectsMismatchedVersionWithoutPurgingCache() async throws {
        let accountID = UUID(uuidString: "13700000-0000-4000-8000-000000000031")!
        let shopID = UUID(uuidString: "13700000-0000-4000-8000-000000000032")!
        let productID = UUID(uuidString: "13700000-0000-4000-8000-000000000033")!
        let versionID = UUID(uuidString: "13700000-0000-4000-8000-000000000034")!
        let mismatchedVersionID = UUID(uuidString: "13700000-0000-4000-8000-000000000035")!
        ProductImageURLProtocolStub.handler = { request in
            guard let url = request.url else { throw ProductImageError.invalidResponse }
            let body = Data("""
            {"currentImageVersionId":null,"ok":true,"operation":"remove","productId":"\(productID.uuidString)","shopId":"\(shopID.uuidString)","status":"removed","versionId":"\(mismatchedVersionID.uuidString)"}
            """.utf8)
            return (
                HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: "HTTP/1.1",
                    headerFields: ["Content-Type": "application/json"]
                )!,
                body
            )
        }
        defer { ProductImageURLProtocolStub.handler = nil }

        let cacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-137-ios-remove-invalid-tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cacheRoot) }
        let cache = ProductImageCache(rootDirectory: cacheRoot)
        let cached = try makePreparedImage().thumb.data
        let key = ProductImageCacheKey(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            shopID: shopID,
            productID: productID,
            versionID: versionID,
            variant: .thumb
        )
        try await cache.write(cached, for: key)
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: cache
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "task-137-test-access")
        }

        do {
            _ = try await service.remove(
                scope: ProductImageScope(accountID: accountID, shopID: shopID),
                productID: productID,
                versionID: versionID
            )
            XCTFail("Expected mismatched remove response to fail closed")
        } catch let error as ProductImageError {
            XCTAssertEqual(error, .invalidResponse)
        }
        let cachedAfterFailure = try await cache.read(key)
        XCTAssertEqual(cachedAfterFailure, cached)
    }

    func testUploadRejectsUnsignedPathAndNonLocalPlainHTTPBeforeNetwork() async throws {
        let api = ProductImageAPIClient(
            apiBaseURL: URL(string: "https://admin.task137.invalid")!,
            storageBaseURL: URL(string: "https://storage.task137.invalid")!,
            apiSession: makeSession(),
            storageSession: makeSession()
        )
        for value in [
            "https://storage.task137.invalid/storage/v1/object/public/product-images/main.jpg",
            "http://storage.task137.invalid/storage/v1/object/upload/sign/product-images/main.jpg",
            "https://attacker.invalid/storage/v1/object/upload/sign/product-images/main.jpg",
            "https://storage.task137.invalid/redirect/storage/v1/object/upload/sign/product-images/main.jpg"
        ] {
            do {
                try await api.uploadJPEG(Data([0xff, 0xd8, 0xff, 0xd9]), signedURL: value)
                XCTFail("Expected signed URL validation to fail")
            } catch let error as ProductImageError {
                XCTAssertEqual(error, .signedURLInvalid)
            }
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProductImageURLProtocolStub.self]
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }

    private func makePreparedImage() throws -> PreparedProductImage {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 640,
            height: 480,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.15, green: 0.45, blue: 0.75, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 640, height: 480))
        let image = try XCTUnwrap(context.makeImage())
        let encoded = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
            encoded,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return try ProductImageProcessor.prepare(data: encoded as Data)
    }
}

private struct ProductImageHTTPRequestRecord: Sendable {
    let authorization: String?
    let body: Data?
    let contentType: String?
    let cookie: String?
    let method: String
    let path: String
    let upsert: String?
}

private final class ProductImageAttemptCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var downloads = 0
    private var resolutions = 0

    func recordDownload() -> Int {
        lock.withLock {
            downloads += 1
            return downloads
        }
    }

    func recordResolution() -> Int {
        lock.withLock {
            resolutions += 1
            return resolutions
        }
    }

    var snapshot: (downloads: Int, resolutions: Int) {
        lock.withLock { (downloads, resolutions) }
    }
}

private final class ProductImageHTTPRecorder: @unchecked Sendable {
    private let cacheScope: String
    private let lock = NSLock()
    private var storedRecords: [ProductImageHTTPRequestRecord] = []
    private let versionID: UUID

    init(cacheScope: String, versionID: UUID) {
        self.cacheScope = cacheScope
        self.versionID = versionID
    }

    var records: [ProductImageHTTPRequestRecord] {
        lock.withLock { storedRecords }
    }

    func respond(to request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let path = try XCTUnwrap(request.url?.path)
        let record = ProductImageHTTPRequestRecord(
            authorization: request.value(forHTTPHeaderField: "Authorization"),
            body: try Self.bodyData(from: request),
            contentType: request.value(forHTTPHeaderField: "Content-Type"),
            cookie: request.value(forHTTPHeaderField: "Cookie"),
            method: request.httpMethod ?? "",
            path: path,
            upsert: request.value(forHTTPHeaderField: "x-upsert")
        )
        lock.withLock { storedRecords.append(record) }

        let body: Data
        switch (record.method, path) {
        case ("POST", "/api/shop/product-images/intent"):
            body = Data("""
            {"cacheScope":"\(cacheScope)","mainUploadUrl":"https://storage.task137.invalid/storage/v1/object/upload/sign/product-images/shops/13700000-0000-4000-8000-000000000002/products/13700000-0000-4000-8000-000000000003/primary/\(versionID.uuidString)/main.jpg","ok":true,"status":"upload_required","thumbUploadUrl":"https://storage.task137.invalid/storage/v1/object/upload/sign/product-images/shops/13700000-0000-4000-8000-000000000002/products/13700000-0000-4000-8000-000000000003/primary/\(versionID.uuidString)/thumb.jpg","versionId":"\(versionID.uuidString)"}
            """.utf8)
        case ("PUT", let value) where value.hasPrefix("/storage/v1/object/upload/sign/product-images/"):
            body = Data("{}".utf8)
        case ("POST", "/api/shop/product-images/finalize"):
            body = Data("""
            {"imageUpdatedAt":"2026-07-17T12:34:56Z","ok":true,"status":"finalized","versionId":"\(versionID.uuidString)"}
            """.utf8)
        default:
            throw ProductImageError.invalidResponse
        }
        let response = try XCTUnwrap(HTTPURLResponse(
            url: try XCTUnwrap(request.url),
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ))
        return (response, body)
    }

    private static func bodyData(from request: URLRequest) throws -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }
        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 16 * 1_024)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 {
                throw stream.streamError ?? ProductImageError.invalidResponse
            }
            if count == 0 {
                break
            }
            result.append(buffer, count: count)
        }
        return result
    }
}

private final class ProductImageURLProtocolStub: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    nonisolated(unsafe) static var handler: Handler?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw ProductImageError.invalidResponse
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
