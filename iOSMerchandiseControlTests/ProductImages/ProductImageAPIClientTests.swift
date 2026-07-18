import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class ProductImageAPIClientTests: XCTestCase {
    func testOptInLocalParityNoImageAndProgressiveProductImage() async throws {
        let config = try requireLocalParityConfig()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-local-parity-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let scope = ProductImageScope(accountID: config.accountID, shopID: config.shopID)
        let service = try makeLocalParityService(config: config, cache: cache)
        let store = ProductImageStore(service: service)
        store.activate(scope: scope)

        await store.load(
            scope: scope,
            productID: UUID(),
            versionID: nil,
            variant: .thumb
        )
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))

        await store.loadProgressively(
            scope: scope,
            productID: config.productID,
            versionID: config.versionID
        )
        let thumbnail = ProductImageReference(
            scope: scope,
            productID: config.productID,
            versionID: config.versionID,
            variant: .thumb
        )
        let main = ProductImageReference(
            scope: scope,
            productID: config.productID,
            versionID: config.versionID,
            variant: .main
        )
        XCTAssertNotNil(store.image(for: thumbnail))
        XCTAssertNotNil(store.image(for: main))
        XCTAssertFalse(store.failedReferences.contains(thumbnail))
        XCTAssertFalse(store.failedReferences.contains(main))
        let diskUsage = try await cache.diskUsageBytes()
        XCTAssertGreaterThan(diskUsage, 0)
    }

    func testOptInLocalParityMutationReplacesProductImage() async throws {
        try requireLocalParityMutationMode(.replace)
        let config = try requireLocalParityConfig()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-local-parity-replace-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let scope = ProductImageScope(accountID: config.accountID, shopID: config.shopID)
        let service = try makeLocalParityService(config: config, cache: cache)
        let store = ProductImageStore(service: service)
        store.activate(scope: scope)
        let prepared = try makePreparedImage(red: CGFloat.random(in: 0.05...0.95))
        let progress = ProductImageProgressRecorder()

        let result = try await service.upload(
            prepared: prepared,
            scope: scope,
            productID: config.productID,
            progress: { progress.record($0) }
        )

        XCTAssertEqual(result.status, "finalized")
        XCTAssertNotEqual(result.versionID, config.versionID)
        XCTAssertEqual(progress.stages, [.uploadingMain, .uploadingThumb, .finalizing])
        await store.loadProgressively(
            scope: scope,
            productID: config.productID,
            versionID: result.versionID
        )
        let thumbnail = ProductImageReference(
            scope: scope,
            productID: config.productID,
            versionID: result.versionID,
            variant: .thumb
        )
        let main = ProductImageReference(
            scope: scope,
            productID: config.productID,
            versionID: result.versionID,
            variant: .main
        )
        XCTAssertNotNil(store.image(for: thumbnail))
        XCTAssertNotNil(store.image(for: main))
        try attachRedactedParityMutationResult(
            operation: "replace",
            status: result.status,
            versionID: result.versionID
        )
    }

    func testOptInLocalParityMutationRemovesProductImage() async throws {
        try requireLocalParityMutationMode(.remove)
        let config = try requireLocalParityConfig()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-local-parity-remove-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let scope = ProductImageScope(accountID: config.accountID, shopID: config.shopID)
        let service = try makeLocalParityService(config: config, cache: cache)
        let store = ProductImageStore(service: service)
        store.activate(scope: scope)

        await store.loadProgressively(
            scope: scope,
            productID: config.productID,
            versionID: config.versionID
        )
        let result = try await store.remove(
            scope: scope,
            productID: config.productID,
            versionID: config.versionID
        )

        XCTAssertTrue(result.status == "removed" || result.status == "already_removed")
        for variant in ProductImageVariant.allCases {
            let reference = ProductImageReference(
                scope: scope,
                productID: config.productID,
                versionID: config.versionID,
                variant: variant
            )
            XCTAssertNil(store.image(for: reference))
        }
        try attachRedactedParityMutationResult(
            operation: "remove",
            status: result.status,
            versionID: config.versionID
        )
    }

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
        let progress = ProductImageProgressRecorder()

        let result: ProductImageUploadResult
        do {
            result = try await service.upload(
                prepared: prepared,
                scope: scope,
                productID: productID,
                progress: { progress.record($0) }
            )
        } catch {
            let requestSummary = recorder.records.map { "\($0.method) \($0.path)" }
            XCTFail("Upload workflow failed after requests: \(requestSummary); error: \(error)")
            return
        }

        XCTAssertEqual(result.status, "finalized")
        XCTAssertEqual(result.versionID, versionID)
        XCTAssertEqual(progress.stages, [.uploadingMain, .uploadingThumb, .finalizing])
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

    func testUploadRetriesOneTransientObjectFailureWithoutDuplicatingIntentOrFinalize() async throws {
        let accountID = UUID(uuidString: "13700000-0000-4000-8000-000000000001")!
        let shopID = UUID(uuidString: "13700000-0000-4000-8000-000000000002")!
        let productID = UUID(uuidString: "13700000-0000-4000-8000-000000000003")!
        let versionID = UUID()
        let recorder = ProductImageHTTPRecorder(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            versionID: versionID,
            transientMainFailures: 1
        )
        ProductImageURLProtocolStub.handler = { try recorder.respond(to: $0) }
        defer { ProductImageURLProtocolStub.handler = nil }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-upload-retry-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: ProductImageCache(rootDirectory: root)
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "fixture")
        }

        let result = try await service.upload(
            prepared: try makePreparedImage(),
            scope: ProductImageScope(accountID: accountID, shopID: shopID),
            productID: productID
        )

        XCTAssertEqual(result.versionID, versionID)
        XCTAssertEqual(recorder.records.filter { $0.path.hasSuffix("/main.jpg") }.count, 2)
        XCTAssertEqual(recorder.records.filter { $0.path.hasSuffix("/thumb.jpg") }.count, 1)
        XCTAssertEqual(recorder.records.filter { $0.path == "/api/shop/product-images/intent" }.count, 1)
        XCTAssertEqual(recorder.records.filter { $0.path == "/api/shop/product-images/finalize" }.count, 1)
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
                {"cacheScope":"\(cacheScope)","items":[{"expiresAt":"2099-07-17T12:39:56Z","productId":"\(productID.uuidString)","signedUrl":"https://storage.task137.invalid\(objectPath)?token=redacted","status":"ready","variant":"thumb","versionId":"\(versionID.uuidString)"}],"ok":true}
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
                {"cacheScope":"\(cacheScope)","items":[{"expiresAt":"2099-07-17T12:39:56Z","productId":"\(productID.uuidString)","signedUrl":"https://storage.task137.invalid\(objectPath)?token=\(attempt == 1 ? "expired" : "fresh")","status":"ready","variant":"thumb","versionId":"\(versionID.uuidString)"}],"ok":true}
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

    func testReadStopsAfterSingleExpiredURLRetry() async throws {
        let accountID = UUID()
        let shopID = UUID()
        let productID = UUID()
        let versionID = UUID()
        let cacheScope = ProductImageService.expectedCacheScope(accountID: accountID)
        let objectPath = "/storage/v1/object/sign/product-images/shops/\(shopID.uuidString)/products/\(productID.uuidString)/primary/\(versionID.uuidString)/thumb.jpg"
        let attempts = ProductImageAttemptCounter()
        ProductImageURLProtocolStub.handler = { request in
            guard let url = request.url else { throw ProductImageError.invalidResponse }
            if request.httpMethod == "POST", url.path == "/api/shop/product-images/read-urls" {
                let attempt = attempts.recordResolution()
                let body = Data("""
                {"cacheScope":"\(cacheScope)","items":[{"expiresAt":"2099-07-17T12:39:56Z","productId":"\(productID.uuidString)","signedUrl":"https://storage.task137.invalid\(objectPath)?token=expired-\(attempt)","status":"ready","variant":"thumb","versionId":"\(versionID.uuidString)"}],"ok":true}
                """.utf8)
                return (
                    HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                    body
                )
            }
            if request.httpMethod == "GET", url.path == objectPath {
                _ = attempts.recordDownload()
                return (
                    HTTPURLResponse(url: url, statusCode: 403, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                    Data()
                )
            }
            throw ProductImageError.invalidResponse
        }
        defer { ProductImageURLProtocolStub.handler = nil }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-expiry-stop-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: ProductImageCache(rootDirectory: root)
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "fixture")
        }

        do {
            _ = try await service.load(ProductImageReference(
                scope: ProductImageScope(accountID: accountID, shopID: shopID),
                productID: productID,
                versionID: versionID,
                variant: .thumb
            ))
            XCTFail("Expected the second expired URL download to fail.")
        } catch let error as ProductImageError {
            XCTAssertEqual(error, .downloadFailed(status: 403))
        }
        XCTAssertEqual(attempts.snapshot.resolutions, 2)
        XCTAssertEqual(attempts.snapshot.downloads, 2)
    }

    func testConcurrentLoadsChunkTwoHundredFiveReferencesAndBoundDownloads() async throws {
        let accountID = UUID()
        let shopID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: shopID)
        let references = (0..<205).map { _ in
            ProductImageReference(
                scope: scope,
                productID: UUID(),
                versionID: UUID(),
                variant: .thumb
            )
        }
        let recorder = ProductImageBatchRecorder(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            jpeg: try makePreparedImage().thumb.data,
            downloadDelay: 0.01
        )
        ProductImageURLProtocolStub.handler = { try recorder.respond(to: $0) }
        defer { ProductImageURLProtocolStub.handler = nil }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-batch-200-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: ProductImageCache(rootDirectory: root),
            maximumConcurrentDownloads: 4,
            readBatchDelayNanoseconds: 200_000_000
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "fixture")
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for reference in references {
                group.addTask { _ = try await service.load(reference) }
            }
            try await group.waitForAll()
        }

        let snapshot = recorder.snapshot
        XCTAssertEqual(snapshot.referenceKeys.count, 205)
        XCTAssertEqual(Set(snapshot.referenceKeys).count, 205)
        XCTAssertTrue(snapshot.batchSizes.allSatisfy { (1...100).contains($0) })
        XCTAssertEqual(snapshot.batchSizes.sorted(), [5, 100, 100])
        XCTAssertEqual(snapshot.downloads, 205)
        XCTAssertLessThanOrEqual(snapshot.maximumConcurrentDownloads, 4)
    }

    func testConcurrentDuplicateLoadsShareOneReadAndOneDownload() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let reference = ProductImageReference(
            scope: scope,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let recorder = ProductImageBatchRecorder(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            jpeg: try makePreparedImage().thumb.data,
            downloadDelay: 0.02
        )
        ProductImageURLProtocolStub.handler = { try recorder.respond(to: $0) }
        defer { ProductImageURLProtocolStub.handler = nil }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-coalescing-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: ProductImageCache(rootDirectory: root)
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "fixture")
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask { _ = try await service.load(reference) }
            }
            try await group.waitForAll()
        }

        XCTAssertEqual(recorder.snapshot.batchSizes, [1])
        XCTAssertEqual(recorder.snapshot.downloads, 1)
    }

    func testValidSignedURLLeaseIsReusedAfterDiskEntryIsRemoved() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let reference = ProductImageReference(
            scope: scope,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let recorder = ProductImageBatchRecorder(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            jpeg: try makePreparedImage().thumb.data,
            downloadDelay: 0
        )
        ProductImageURLProtocolStub.handler = { try recorder.respond(to: $0) }
        defer { ProductImageURLProtocolStub.handler = nil }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-lease-reuse-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: cache
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "fixture")
        }

        let first = try await service.load(reference)
        try await cache.remove(first.cacheKey)
        let second = try await service.load(reference)

        XCTAssertEqual(first.data, second.data)
        XCTAssertEqual(recorder.snapshot.batchSizes, [1])
        XCTAssertEqual(recorder.snapshot.downloads, 2)
    }

    func testExpiredSignedURLLeaseIsNotReused() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let reference = ProductImageReference(
            scope: scope,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let cacheScope = ProductImageService.expectedCacheScope(accountID: accountID)
        let jpeg = try makePreparedImage().thumb.data
        let attempts = ProductImageAttemptCounter()
        let objectPath = "/storage/v1/object/sign/product-images/shops/\(scope.shopID)/products/\(reference.productID)/primary/\(reference.versionID)/thumb.jpg"
        ProductImageURLProtocolStub.handler = { request in
            let url = try XCTUnwrap(request.url)
            if request.httpMethod == "POST", url.path == "/api/shop/product-images/read-urls" {
                let resolution = attempts.recordResolution()
                let expiresAt = resolution == 1 ? "2000-01-01T00:00:00Z" : "2099-01-01T00:00:00Z"
                let body = Data("""
                {"cacheScope":"\(cacheScope)","items":[{"expiresAt":"\(expiresAt)","productId":"\(reference.productID)","signedUrl":"https://storage.task137.invalid\(objectPath)?token=redacted","status":"ready","variant":"thumb","versionId":"\(reference.versionID)"}],"ok":true}
                """.utf8)
                return (
                    HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                    body
                )
            }
            if request.httpMethod == "GET", url.path == objectPath {
                _ = attempts.recordDownload()
                return (
                    HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/jpeg"])!,
                    jpeg
                )
            }
            throw ProductImageError.invalidResponse
        }
        defer { ProductImageURLProtocolStub.handler = nil }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-lease-expiry-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: cache
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "fixture")
        }

        let first = try await service.load(reference)
        try await cache.remove(first.cacheKey)
        _ = try await service.load(reference)

        XCTAssertEqual(attempts.snapshot.resolutions, 2)
        XCTAssertEqual(attempts.snapshot.downloads, 2)
    }

    func testProgressiveStoreLoadsThumbnailBeforeMainAndPublishesBoth() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let productID = UUID()
        let versionID = UUID()
        let recorder = ProductImageBatchRecorder(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            jpeg: try makePreparedImage().thumb.data,
            downloadDelay: 0
        )
        ProductImageURLProtocolStub.handler = { try recorder.respond(to: $0) }
        defer { ProductImageURLProtocolStub.handler = nil }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-progressive-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: ProductImageCache(rootDirectory: root)
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "fixture")
        }
        let store = ProductImageStore(service: service)
        store.activate(scope: scope)

        await store.loadProgressively(
            scope: scope,
            productID: productID,
            versionID: versionID
        )

        let thumbnail = ProductImageReference(
            scope: scope,
            productID: productID,
            versionID: versionID,
            variant: .thumb
        )
        let main = ProductImageReference(
            scope: scope,
            productID: productID,
            versionID: versionID,
            variant: .main
        )
        XCTAssertNotNil(store.image(for: thumbnail))
        XCTAssertNotNil(store.image(for: main))
        XCTAssertEqual(
            recorder.snapshot.referenceKeys.compactMap { $0.split(separator: "/").last.map(String.init) },
            ["thumb", "main"]
        )
    }

    func testUndecodableJPEGIsRejectedBeforeCacheCommit() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let reference = ProductImageReference(
            scope: scope,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let recorder = ProductImageBatchRecorder(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            jpeg: Data([0xff, 0xd8, 0xff, 0xd9]),
            downloadDelay: 0
        )
        ProductImageURLProtocolStub.handler = { try recorder.respond(to: $0) }
        defer { ProductImageURLProtocolStub.handler = nil }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-invalid-decode-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: cache
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "fixture")
        }

        do {
            _ = try await service.load(reference)
            XCTFail("Expected decode validation to fail.")
        } catch let error as ProductImageError {
            XCTAssertEqual(error, .downloadedImageInvalid)
        }
        let key = ProductImageCacheKey(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            shopID: scope.shopID,
            productID: reference.productID,
            versionID: reference.versionID,
            variant: .thumb
        )
        let cachedImage = try await cache.read(key)
        XCTAssertNil(cachedImage)
    }

    func testCancelledOffscreenLoadDoesNotPublishFailureOrStaleImage() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let oldReference = ProductImageReference(
            scope: scope,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let recorder = ProductImageBatchRecorder(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            jpeg: try makePreparedImage().thumb.data,
            downloadDelay: 0.05
        )
        ProductImageURLProtocolStub.handler = { try recorder.respond(to: $0) }
        defer { ProductImageURLProtocolStub.handler = nil }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-cancel-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: ProductImageCache(rootDirectory: root)
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "fixture")
        }
        let store = ProductImageStore(service: service)
        store.activate(scope: scope)

        let load = Task { await store.load(oldReference) }
        try await Task.sleep(nanoseconds: 2_000_000)
        load.cancel()
        await load.value

        XCTAssertNil(store.image(for: oldReference))
        XCTAssertFalse(store.didFail(oldReference))
        XCTAssertFalse(store.isLoading(oldReference))
    }

    func testStoreCoalescingKeepsVisibleWaiterWhenPeerCancels() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let reference = ProductImageReference(
            scope: scope,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let recorder = ProductImageBatchRecorder(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            jpeg: try makePreparedImage().thumb.data,
            downloadDelay: 0.05
        )
        ProductImageURLProtocolStub.handler = { try recorder.respond(to: $0) }
        defer { ProductImageURLProtocolStub.handler = nil }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-store-waiters-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: ProductImageCache(rootDirectory: root)
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "fixture")
        }
        let store = ProductImageStore(service: service)
        store.activate(scope: scope)

        let disappearingWaiter = Task { await store.load(reference) }
        try await Task.sleep(nanoseconds: 1_000_000)
        let visibleWaiter = Task { await store.load(reference) }
        try await Task.sleep(nanoseconds: 2_000_000)
        disappearingWaiter.cancel()
        await disappearingWaiter.value
        await visibleWaiter.value

        XCTAssertNotNil(store.image(for: reference))
        XCTAssertFalse(store.didFail(reference))
        XCTAssertFalse(store.isLoading(reference))
        XCTAssertEqual(recorder.snapshot.downloads, 1)
    }

    func testCatalogOfTwoHundredOnlyStartsLoadsForVisibleSubset() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let catalog = (0..<200).map { _ in
            ProductImageReference(
                scope: scope,
                productID: UUID(),
                versionID: UUID(),
                variant: .thumb
            )
        }
        let recorder = ProductImageBatchRecorder(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            jpeg: try makePreparedImage().thumb.data,
            downloadDelay: 0
        )
        ProductImageURLProtocolStub.handler = { try recorder.respond(to: $0) }
        defer { ProductImageURLProtocolStub.handler = nil }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-visible-subset-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: ProductImageCache(rootDirectory: root)
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "fixture")
        }

        try await withThrowingTaskGroup(of: Void.self) { group in
            for reference in catalog.prefix(12) {
                group.addTask { _ = try await service.load(reference) }
            }
            try await group.waitForAll()
        }

        XCTAssertEqual(recorder.snapshot.referenceKeys.count, 12)
        XCTAssertEqual(recorder.snapshot.downloads, 12)
        XCTAssertEqual(Set(recorder.snapshot.referenceKeys).count, 12)
    }

    func testFullScrollOfTwoHundredThumbnailsKeepsMemoryAndDiskBounded() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let catalog = (0..<200).map { _ in
            ProductImageReference(
                scope: scope,
                productID: UUID(),
                versionID: UUID(),
                variant: .thumb
            )
        }
        let recorder = ProductImageBatchRecorder(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            jpeg: try makePreparedImage().thumb.data,
            downloadDelay: 0
        )
        ProductImageURLProtocolStub.handler = { try recorder.respond(to: $0) }
        defer { ProductImageURLProtocolStub.handler = nil }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-scroll-200-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: cache,
            maximumConcurrentDownloads: 4
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "fixture")
        }
        let store = ProductImageStore(service: service)
        store.activate(scope: scope)

        for start in stride(from: 0, to: catalog.count, by: 12) {
            let end = min(start + 12, catalog.count)
            await withTaskGroup(of: Void.self) { group in
                for reference in catalog[start..<end] {
                    group.addTask { await store.load(reference) }
                }
                await group.waitForAll()
            }
        }

        let diskBytes = try await cache.diskUsageBytes()
        let snapshot = recorder.snapshot
        XCTAssertEqual(snapshot.downloads, 200)
        XCTAssertEqual(Set(snapshot.referenceKeys).count, 200)
        XCTAssertLessThanOrEqual(snapshot.maximumConcurrentDownloads, 4)
        XCTAssertLessThanOrEqual(store.cachedImageCount, 100)
        XCTAssertLessThanOrEqual(store.cachedImageCostBytes, ProductImageStore.memoryCostLimit)
        XCTAssertLessThanOrEqual(diskBytes, ProductImageCache.defaultMaximumDiskBytes)
        XCTAssertTrue(store.loadingReferences.isEmpty)
        XCTAssertTrue(store.failedReferences.isEmpty)
        try attachCacheStabilityMetrics(name: "scroll-200", values: [
            "diskBytes": diskBytes,
            "downloads": snapshot.downloads,
            "memoryBytes": store.cachedImageCostBytes,
            "memoryEntries": store.cachedImageCount,
            "products": catalog.count
        ])
    }

    func testTwentyProductsReopenedTwentyTimesDoNotGrowCachesMonotonically() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let products = (0..<20).map { _ in (productID: UUID(), versionID: UUID()) }
        let recorder = ProductImageBatchRecorder(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            jpeg: try makePreparedImage().thumb.data,
            downloadDelay: 0
        )
        ProductImageURLProtocolStub.handler = { try recorder.respond(to: $0) }
        defer { ProductImageURLProtocolStub.handler = nil }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("task-138-reopen-20-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let service = ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.task137.invalid")!,
                storageBaseURL: URL(string: "https://storage.task137.invalid")!,
                apiSession: makeSession(),
                storageSession: makeSession()
            ),
            cache: cache,
            maximumConcurrentDownloads: 4
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "fixture")
        }
        let store = ProductImageStore(service: service)
        store.activate(scope: scope)
        var memoryEntrySamples: [Int] = []
        var memoryByteSamples: [Int] = []
        var diskByteSamples: [Int] = []

        for _ in 0..<20 {
            for product in products {
                await store.loadProgressively(
                    scope: scope,
                    productID: product.productID,
                    versionID: product.versionID
                )
            }
            memoryEntrySamples.append(store.cachedImageCount)
            memoryByteSamples.append(store.cachedImageCostBytes)
            diskByteSamples.append(try await cache.diskUsageBytes())
        }

        let snapshot = recorder.snapshot
        XCTAssertEqual(snapshot.downloads, 40)
        XCTAssertEqual(Set(snapshot.referenceKeys).count, 40)
        XCTAssertLessThanOrEqual(snapshot.maximumConcurrentDownloads, 4)
        XCTAssertLessThanOrEqual(memoryEntrySamples.max() ?? 0, 100)
        XCTAssertLessThanOrEqual(memoryByteSamples.max() ?? 0, ProductImageStore.memoryCostLimit)
        XCTAssertLessThanOrEqual(diskByteSamples.max() ?? 0, ProductImageCache.defaultMaximumDiskBytes)
        XCTAssertEqual(Set(memoryEntrySamples.dropFirst()).count, 1)
        XCTAssertEqual(Set(memoryByteSamples.dropFirst()).count, 1)
        XCTAssertEqual(Set(diskByteSamples.dropFirst()).count, 1)
        XCTAssertTrue(store.loadingReferences.isEmpty)
        XCTAssertTrue(store.failedReferences.isEmpty)
        try attachCacheStabilityMetrics(name: "reopen-20x20", values: [
            "diskBytesMax": diskByteSamples.max() ?? 0,
            "downloads": snapshot.downloads,
            "iterations": 20,
            "memoryBytesMax": memoryByteSamples.max() ?? 0,
            "memoryEntriesMax": memoryEntrySamples.max() ?? 0,
            "products": products.count
        ])
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

    private func attachCacheStabilityMetrics(
        name: String,
        values: [String: Int]
    ) throws {
        let data = try JSONSerialization.data(
            withJSONObject: values,
            options: [.prettyPrinted, .sortedKeys]
        )
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: UTType.json.identifier)
        attachment.name = "TASK-138-\(name)-metrics.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func requireLocalParityConfig() throws -> ProductImageLocalParityConfig {
        let environment = ProcessInfo.processInfo.environment
        guard let configPath = environment["TASK138_LOCAL_PARITY_CONFIG_PATH"],
              !configPath.isEmpty else {
            throw XCTSkip("Set TASK138_LOCAL_PARITY_CONFIG_PATH to the privacy-safe Simulator /tmp config.")
        }
        let configURL = URL(fileURLWithPath: configPath).standardizedFileURL
        guard configURL.deletingLastPathComponent().path == "/tmp" else {
            throw ProductImageLocalParityHarnessError.unstableConfigPath
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: configURL.path)
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0
        guard permissions & 0o777 == 0o600 else {
            throw ProductImageLocalParityHarnessError.insecureConfigPermissions
        }
        let config = try JSONDecoder().decode(
            ProductImageLocalParityConfig.self,
            from: Data(contentsOf: configURL, options: [.mappedIfSafe])
        )
        guard let apiBaseURL = URL(string: config.apiBaseURL),
              let storageBaseURL = URL(string: config.storageBaseURL),
              Self.isLoopback(apiBaseURL),
              Self.isLoopback(storageBaseURL) else {
            throw ProductImageLocalParityHarnessError.nonLocalEndpoint
        }
        return config
    }

    private func requireLocalParityMutationMode(
        _ expected: ProductImageLocalParityMutationMode
    ) throws {
        let value = ProcessInfo.processInfo.environment["TASK138_LOCAL_PARITY_MUTATION_MODE"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard value == expected.rawValue else {
            throw XCTSkip("Set TASK138_LOCAL_PARITY_MUTATION_MODE=\(expected.rawValue) to authorize this local mutation.")
        }
    }

    private func makeLocalParityService(
        config: ProductImageLocalParityConfig,
        cache: ProductImageCache
    ) throws -> ProductImageService {
        let apiBaseURL = try XCTUnwrap(URL(string: config.apiBaseURL))
        let storageBaseURL = try XCTUnwrap(URL(string: config.storageBaseURL))
        return ProductImageService(
            apiBaseURL: apiBaseURL,
            storageBaseURL: storageBaseURL,
            cache: cache
        ) {
            ProductImageSessionSnapshot(
                accountID: config.accountID,
                accessToken: config.accessToken
            )
        }
    }

    private func attachRedactedParityMutationResult(
        operation: String,
        status: String,
        versionID: UUID
    ) throws {
        let versionFingerprint = String(
            ProductImageService.expectedCacheScope(accountID: versionID).prefix(12)
        )
        let data = try JSONSerialization.data(withJSONObject: [
            "operation": operation,
            "status": status,
            "versionFingerprint": versionFingerprint
        ], options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: UTType.json.identifier)
        attachment.name = "TASK-138-local-parity-\(operation)-redacted.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private static func isLoopback(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
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

    private func makePreparedImage(red: CGFloat = 0.15) throws -> PreparedProductImage {
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
        context.setFillColor(CGColor(red: red, green: 0.45, blue: 0.75, alpha: 1))
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

private struct ProductImageLocalParityConfig: Decodable {
    let accessToken: String
    let accountID: UUID
    let apiBaseURL: String
    let productID: UUID
    let shopID: UUID
    let storageBaseURL: String
    let versionID: UUID
}

private enum ProductImageLocalParityMutationMode: String {
    case remove
    case replace
}

private enum ProductImageLocalParityHarnessError: LocalizedError {
    case insecureConfigPermissions
    case nonLocalEndpoint
    case unstableConfigPath

    var errorDescription: String? {
        switch self {
        case .insecureConfigPermissions:
            return "Local parity config must have mode 0600."
        case .nonLocalEndpoint:
            return "Local parity accepts loopback API and Storage endpoints only."
        case .unstableConfigPath:
            return "Local parity config must use a stable Simulator /tmp path."
        }
    }
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

private final class ProductImageProgressRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedStages: [ProductImageOperationStage] = []

    func record(_ stage: ProductImageOperationStage) {
        lock.withLock { storedStages.append(stage) }
    }

    var stages: [ProductImageOperationStage] {
        lock.withLock { storedStages }
    }
}

private final class ProductImageHTTPRecorder: @unchecked Sendable {
    private let cacheScope: String
    private let lock = NSLock()
    private var storedRecords: [ProductImageHTTPRequestRecord] = []
    private var remainingTransientMainFailures: Int
    private let versionID: UUID

    init(
        cacheScope: String,
        versionID: UUID,
        transientMainFailures: Int = 0
    ) {
        self.cacheScope = cacheScope
        self.versionID = versionID
        self.remainingTransientMainFailures = transientMainFailures
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
        var statusCode = 200
        switch (record.method, path) {
        case ("POST", "/api/shop/product-images/intent"):
            body = Data("""
            {"cacheScope":"\(cacheScope)","mainUploadUrl":"https://storage.task137.invalid/storage/v1/object/upload/sign/product-images/shops/13700000-0000-4000-8000-000000000002/products/13700000-0000-4000-8000-000000000003/primary/\(versionID.uuidString)/main.jpg","ok":true,"status":"upload_required","thumbUploadUrl":"https://storage.task137.invalid/storage/v1/object/upload/sign/product-images/shops/13700000-0000-4000-8000-000000000002/products/13700000-0000-4000-8000-000000000003/primary/\(versionID.uuidString)/thumb.jpg","versionId":"\(versionID.uuidString)"}
            """.utf8)
        case ("PUT", let value) where value.hasPrefix("/storage/v1/object/upload/sign/product-images/"):
            body = Data("{}".utf8)
            if value.hasSuffix("/main.jpg") {
                let shouldFail = lock.withLock {
                    guard remainingTransientMainFailures > 0 else { return false }
                    remainingTransientMainFailures -= 1
                    return true
                }
                if shouldFail {
                    statusCode = 503
                }
            }
        case ("POST", "/api/shop/product-images/finalize"):
            body = Data("""
            {"imageUpdatedAt":"2026-07-17T12:34:56Z","ok":true,"status":"finalized","versionId":"\(versionID.uuidString)"}
            """.utf8)
        default:
            throw ProductImageError.invalidResponse
        }
        let response = try XCTUnwrap(HTTPURLResponse(
            url: try XCTUnwrap(request.url),
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ))
        return (response, body)
    }

    fileprivate static func bodyData(from request: URLRequest) throws -> Data? {
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

private final class ProductImageBatchRecorder: @unchecked Sendable {
    struct Snapshot {
        let batchSizes: [Int]
        let downloads: Int
        let maximumConcurrentDownloads: Int
        let referenceKeys: [String]
    }

    private let cacheScope: String
    private let downloadDelay: TimeInterval
    private let jpeg: Data
    private let lock = NSLock()
    private var activeDownloads = 0
    private var batchSizes: [Int] = []
    private var downloads = 0
    private var maximumConcurrentDownloads = 0
    private var referenceKeys: [String] = []

    init(cacheScope: String, jpeg: Data, downloadDelay: TimeInterval) {
        self.cacheScope = cacheScope
        self.jpeg = jpeg
        self.downloadDelay = downloadDelay
    }

    var snapshot: Snapshot {
        lock.withLock {
            Snapshot(
                batchSizes: batchSizes,
                downloads: downloads,
                maximumConcurrentDownloads: maximumConcurrentDownloads,
                referenceKeys: referenceKeys
            )
        }
    }

    func respond(to request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let url = try XCTUnwrap(request.url)
        if request.httpMethod == "POST", url.path == "/api/shop/product-images/read-urls" {
            let body = try XCTUnwrap(ProductImageHTTPRecorder.bodyData(from: request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let shopID = try XCTUnwrap(object["shopId"] as? String)
            let refs = try XCTUnwrap(object["refs"] as? [[String: String]])
            let items: [[String: Any]] = try refs.map { ref in
                let productID = try XCTUnwrap(ref["productId"])
                let versionID = try XCTUnwrap(ref["versionId"])
                let variant = try XCTUnwrap(ref["variant"])
                let key = "\(productID)/\(versionID)/\(variant)"
                lock.withLock { referenceKeys.append(key) }
                return [
                    "expiresAt": "2099-07-17T12:39:56Z",
                    "productId": productID,
                    "signedUrl": "https://storage.task137.invalid/storage/v1/object/sign/product-images/shops/\(shopID)/products/\(productID)/primary/\(versionID)/\(variant).jpg?token=redacted",
                    "status": "ready",
                    "variant": variant,
                    "versionId": versionID
                ]
            }
            lock.withLock { batchSizes.append(refs.count) }
            let responseBody = try JSONSerialization.data(withJSONObject: [
                "cacheScope": cacheScope,
                "items": items,
                "ok": true
            ])
            return (
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!,
                responseBody
            )
        }
        if request.httpMethod == "GET" {
            lock.withLock {
                activeDownloads += 1
                downloads += 1
                maximumConcurrentDownloads = max(maximumConcurrentDownloads, activeDownloads)
            }
            if downloadDelay > 0 {
                Thread.sleep(forTimeInterval: downloadDelay)
            }
            lock.withLock { activeDownloads -= 1 }
            return (
                HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/jpeg"])!,
                jpeg
            )
        }
        throw ProductImageError.invalidResponse
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
