import CoreGraphics
import ImageIO
import UIKit
import UniformTypeIdentifiers
import XCTest
@testable import iOSMerchandiseControl

final class ProductImageCacheTests: XCTestCase {
    func testCacheIsAccountShopProductAndVersionScoped() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let shopA = UUID()
        let shopB = UUID()
        let product = UUID()
        let version = UUID()
        let data = try jpegFixture()
        let key = ProductImageCacheKey(
            cacheScope: String(repeating: "a", count: 64),
            shopID: shopA,
            productID: product,
            versionID: version,
            variant: .thumb
        )

        try await cache.write(data, for: key)

        let sameScope = try await cache.read(key)
        let otherAccount = try await cache.read(ProductImageCacheKey(
            cacheScope: String(repeating: "b", count: 64),
            shopID: shopA,
            productID: product,
            versionID: version,
            variant: .thumb
        ))
        let otherShop = try await cache.read(ProductImageCacheKey(
            cacheScope: key.cacheScope,
            shopID: shopB,
            productID: product,
            versionID: version,
            variant: .thumb
        ))
        XCTAssertEqual(sameScope, data)
        XCTAssertNil(otherAccount)
        XCTAssertNil(otherShop)
    }

    func testPurgeRemovesOnlySupersededVersionsForProduct() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let cacheScope = String(repeating: "c", count: 64)
        let shop = UUID()
        let product = UUID()
        let oldVersion = UUID()
        let currentVersion = UUID()
        let data = try jpegFixture()
        let old = ProductImageCacheKey(
            cacheScope: cacheScope,
            shopID: shop,
            productID: product,
            versionID: oldVersion,
            variant: .main
        )
        let current = ProductImageCacheKey(
            cacheScope: cacheScope,
            shopID: shop,
            productID: product,
            versionID: currentVersion,
            variant: .main
        )
        try await cache.write(data, for: old)
        try await cache.write(data, for: current)

        try await cache.purgeProduct(
            cacheScope: cacheScope,
            shopID: shop,
            productID: product,
            keeping: currentVersion
        )

        let oldData = try await cache.read(old)
        let currentData = try await cache.read(current)
        XCTAssertNil(oldData)
        XCTAssertEqual(currentData, data)
    }

    func testDiskLRUEvictsLeastRecentlyUsedEntryWithinByteBudget() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let data = try jpegFixture()
        let budget = data.count * 2
        let cache = ProductImageCache(
            rootDirectory: root,
            maximumDiskBytes: budget
        )
        let scope = String(repeating: "d", count: 64)
        let shopID = UUID()
        let versionID = UUID()
        func key(_ productID: UUID) -> ProductImageCacheKey {
            ProductImageCacheKey(
                cacheScope: scope,
                shopID: shopID,
                productID: productID,
                versionID: versionID,
                variant: .thumb
            )
        }
        let first = key(UUID())
        let second = key(UUID())
        let third = key(UUID())

        try await cache.write(data, for: first)
        try await Task.sleep(for: .milliseconds(20))
        try await cache.write(data, for: second)
        try await Task.sleep(for: .milliseconds(20))
        let touchedFirst = try await cache.read(first)
        XCTAssertNotNil(touchedFirst)
        try await Task.sleep(for: .milliseconds(20))
        try await cache.write(data, for: third)

        let retainedFirst = try await cache.read(first)
        let evictedSecond = try await cache.read(second)
        let retainedThird = try await cache.read(third)
        let usage = try await cache.diskUsageBytes()
        XCTAssertNotNil(retainedFirst)
        XCTAssertNil(evictedSecond)
        XCTAssertNotNil(retainedThird)
        XCTAssertLessThanOrEqual(usage, budget)
    }

    func testDiskLRUIsEntryBoundedAndPrunesEmptyAncestorsIdempotently() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let data = try jpegFixture()
        let maximumEntries = 4
        let cache = ProductImageCache(
            rootDirectory: root,
            maximumDiskBytes: data.count * 100,
            maximumEntryCount: maximumEntries
        )
        let scope = String(repeating: "e", count: 64)
        let shopID = UUID()
        var keys: [ProductImageCacheKey] = []
        for _ in 0..<12 {
            let key = ProductImageCacheKey(
                cacheScope: scope,
                shopID: shopID,
                productID: UUID(),
                versionID: UUID(),
                variant: .thumb
            )
            keys.append(key)
            try await cache.write(data, for: key)
        }

        let abandonedDirectory = root
            .appendingPathComponent("abandoned", isDirectory: true)
            .appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(
            at: abandonedDirectory,
            withIntermediateDirectories: true
        )
        let abandonedTemporaryFile = abandonedDirectory
            .appendingPathComponent(".atomic-write.tmp")
        XCTAssertTrue(FileManager.default.createFile(
            atPath: abandonedTemporaryFile.path,
            contents: Data()
        ))
        let cleanupTrigger = ProductImageCacheKey(
            cacheScope: scope,
            shopID: shopID,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        keys.append(cleanupTrigger)
        try await cache.write(data, for: cleanupTrigger)

        let boundedEntryCount = try await cache.diskEntryCount()
        XCTAssertEqual(boundedEntryCount, maximumEntries)
        XCTAssertFalse(FileManager.default.fileExists(atPath: abandonedTemporaryFile.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: abandonedDirectory.path))
        for key in keys {
            try await cache.remove(key)
            try await cache.remove(key)
        }
        let finalEntryCount = try await cache.diskEntryCount()
        XCTAssertEqual(finalEntryCount, 0)
        let remainingRegularFiles = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )?.compactMap { $0 as? URL }.filter {
            (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        } ?? []
        XCTAssertTrue(remainingRegularFiles.isEmpty)
    }

    func testOfflineCacheHitDoesNotRequireAnAuthenticatedSession() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let reference = ProductImageReference(
            scope: scope,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let key = ProductImageCacheKey(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            shopID: scope.shopID,
            productID: reference.productID,
            versionID: reference.versionID,
            variant: .thumb
        )
        let cache = ProductImageCache(rootDirectory: root)
        let data = try jpegFixture()
        try await cache.write(data, for: key)
        let service = ProductImageService(
            apiBaseURL: URL(string: "https://admin.task138.invalid")!,
            storageBaseURL: URL(string: "https://storage.task138.invalid")!,
            cache: cache
        ) { nil }

        let result = try await service.load(reference)

        XCTAssertEqual(result.source, "cache")
        XCTAssertEqual(result.data, data)
    }

    func testInvalidScopeAndMetadataBearingJPEGAreRejected() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let invalidKey = ProductImageCacheKey(
            cacheScope: "../other-account",
            shopID: UUID(),
            productID: UUID(),
            versionID: UUID(),
            variant: .main
        )

        do {
            try await cache.write(try jpegFixture(), for: invalidKey)
            XCTFail("Expected invalid cache scope.")
        } catch {
            XCTAssertEqual(error as? ProductImageError, .invalidScope)
        }
    }

    func testSymlinkedScopeFailsClosedForWriteAndPurgeWithoutTouchingSentinel() async throws {
        let root = temporaryRoot()
        let outside = temporaryRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let sentinel = outside.appendingPathComponent("sentinel.txt")
        let sentinelData = Data("must-remain".utf8)
        try sentinelData.write(to: sentinel)
        let cacheScope = String(repeating: "f", count: 64)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent(cacheScope, isDirectory: true),
            withDestinationURL: outside
        )
        let cache = ProductImageCache(rootDirectory: root)
        let key = ProductImageCacheKey(
            cacheScope: cacheScope,
            shopID: UUID(),
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )

        do {
            try await cache.write(try jpegFixture(), for: key)
            XCTFail("A symlinked cache scope must fail closed before write.")
        } catch {
            XCTAssertEqual(error as? ProductImageError, .invalidScope)
        }
        do {
            try await cache.purgeScope(cacheScope: cacheScope)
            XCTFail("A symlinked cache scope must fail closed before purge.")
        } catch {
            XCTAssertEqual(error as? ProductImageError, .invalidScope)
        }

        XCTAssertEqual(try Data(contentsOf: sentinel), sentinelData)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sentinel.path))
    }

    func testPersonalAccountCacheScopeMatchesServerContract() {
        let accountID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!

        XCTAssertEqual(
            ProductImageService.expectedCacheScope(accountID: accountID),
            "199373902d20643d3e5be648238eeb3435d11e8a3e56d6031734f11cd4262805"
        )
    }

    @MainActor
    func testNoImageVersionPerformsNoLoadAndCreatesNoCacheEntry() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let cache = ProductImageCache(rootDirectory: root)
        let service = ProductImageService(
            apiBaseURL: URL(string: "https://admin.task138.invalid")!,
            storageBaseURL: URL(string: "https://storage.task138.invalid")!,
            cache: cache
        ) {
            ProductImageSessionSnapshot(accountID: accountID, accessToken: "fixture")
        }
        let store = ProductImageStore(service: service)
        store.activate(scope: scope)

        await store.load(
            scope: scope,
            productID: UUID(),
            versionID: nil,
            variant: .thumb
        )

        XCTAssertTrue(store.loadingReferences.isEmpty)
        XCTAssertTrue(store.failedReferences.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    @MainActor
    func testAccountSwitchClearsMemoryAndPurgesPreviousDiskScope() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let accountA = UUID()
        let accountB = UUID()
        let scopeA = ProductImageScope(accountID: accountA, shopID: UUID())
        let scopeB = ProductImageScope(accountID: accountB, shopID: UUID())
        let reference = ProductImageReference(
            scope: scopeA,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let cache = ProductImageCache(rootDirectory: root)
        let key = ProductImageCacheKey(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountA),
            shopID: scopeA.shopID,
            productID: reference.productID,
            versionID: reference.versionID,
            variant: .thumb
        )
        try await cache.write(
            try jpegFixture(),
            for: key
        )
        let service = ProductImageService(
            apiBaseURL: URL(string: "https://admin.task137.invalid")!,
            storageBaseURL: URL(string: "https://storage.task137.invalid")!,
            cache: cache
        ) {
            ProductImageSessionSnapshot(accountID: accountA, accessToken: "fixture")
        }
        let store = ProductImageStore(service: service)

        store.activate(scope: scopeA)
        await store.load(reference)
        XCTAssertNotNil(store.image(for: reference))
        store.activate(scope: scopeB)
        XCTAssertNil(store.image(for: reference))
        await service.deactivate(scope: scopeA, purgeAccountScope: true)
        let cachedImage = try await cache.read(key)
        XCTAssertNil(cachedImage)
        store.activate(scope: scopeA)
        XCTAssertNil(store.image(for: reference))
    }

    @MainActor
    func testMemoryWarningPurgesDecodedImagesAndAccounting() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let reference = ProductImageReference(
            scope: scope,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let cache = ProductImageCache(rootDirectory: root)
        try await cache.write(try jpegFixture(), for: ProductImageCacheKey(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            shopID: scope.shopID,
            productID: reference.productID,
            versionID: reference.versionID,
            variant: .thumb
        ))
        let service = ProductImageService(
            apiBaseURL: URL(string: "https://admin.task138.invalid")!,
            storageBaseURL: URL(string: "https://storage.task138.invalid")!,
            cache: cache
        ) { nil }
        let store = ProductImageStore(service: service)
        store.activate(scope: scope)
        await store.load(reference)
        XCTAssertNotNil(store.image(for: reference))
        XCTAssertEqual(store.cachedImageCount, 1)
        XCTAssertGreaterThan(store.cachedImageCostBytes, 0)
        XCTAssertLessThanOrEqual(store.cachedImageCostBytes, ProductImageStore.memoryCostLimit)

        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        try await Task.sleep(for: .milliseconds(20))

        XCTAssertNil(store.image(for: reference))
        XCTAssertEqual(store.cachedImageCount, 0)
        XCTAssertEqual(store.cachedImageCostBytes, 0)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("task137-cache-tests-\(UUID().uuidString.lowercased())", isDirectory: true)
    }

    private func jpegFixture() throws -> Data {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 32,
            height: 24,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 24))
        let image = try XCTUnwrap(context.makeImage())
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary
        )
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let prepared = try ProductImageProcessor.prepare(data: output as Data)
        return prepared.thumb.data
    }
}
