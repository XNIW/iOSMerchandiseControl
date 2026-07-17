import CoreGraphics
import ImageIO
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

    func testPersonalAccountCacheScopeMatchesServerContract() {
        let accountID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!

        XCTAssertEqual(
            ProductImageService.expectedCacheScope(accountID: accountID),
            "199373902d20643d3e5be648238eeb3435d11e8a3e56d6031734f11cd4262805"
        )
    }

    @MainActor
    func testMemoryCachePreservesOtherAccountNamespacesAcrossActivation() async throws {
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
        try await cache.write(
            try jpegFixture(),
            for: ProductImageCacheKey(
                cacheScope: ProductImageService.expectedCacheScope(accountID: accountA),
                shopID: scopeA.shopID,
                productID: reference.productID,
                versionID: reference.versionID,
                variant: .thumb
            )
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
        store.activate(scope: scopeA)
        XCTAssertNotNil(store.image(for: reference))
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
