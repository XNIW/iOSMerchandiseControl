import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class ProductImageOwnerStoreRaceTests: XCTestCase {
    func testOwnerStoreGateRequiresExactBindingAndNoReplacementJournal() {
        let accountID = UUID()
        let selected = makeSelectedShop(id: UUID())
        let scope = ProductImageScope(accountID: accountID, shopID: selected.shopID)
        let binding = AccountBinding(
            accountHash: AccountBindingStore.accountHash(for: accountID),
            storeIdentity: selected.localStoreIdentity
        )

        XCTAssertTrue(ProductImageOwnerStoreGate.allows(
            scope: scope,
            selectedShop: selected,
            binding: binding
        ))
        XCTAssertFalse(ProductImageOwnerStoreGate.allows(
            scope: scope,
            selectedShop: selected,
            binding: AccountBinding(
                accountHash: AccountBindingStore.accountHash(for: UUID()),
                storeIdentity: selected.localStoreIdentity
            )
        ))
        XCTAssertFalse(ProductImageOwnerStoreGate.allows(
            scope: scope,
            selectedShop: makeSelectedShop(id: UUID()),
            binding: binding
        ))
        XCTAssertFalse(ProductImageOwnerStoreGate.allows(
            scope: scope,
            selectedShop: selected,
            binding: binding,
            hasPendingReplacement: true
        ))
        XCTAssertFalse(ProductImageOwnerStoreGate.allows(
            scope: scope,
            selectedShop: nil,
            binding: binding
        ))
        XCTAssertFalse(ProductImageOwnerStoreGate.allows(
            scope: scope,
            selectedShop: makeSelectedShop(id: selected.shopID, status: "revoked"),
            binding: binding
        ))

        let identity = selected.localStoreIdentity
        XCTAssertFalse(ProductImageOwnerStoreGate.allows(
            scope: scope,
            selectedShop: selected,
            binding: AccountBinding(
                accountHash: binding.accountHash,
                storeIdentity: LocalStoreIdentity(
                    rawValue: identity.rawValue,
                    defaultStoreId: identity.defaultStoreId,
                    localStoreId: "different-local-store",
                    schemaVersion: identity.schemaVersion,
                    syncProtocolVersion: identity.syncProtocolVersion,
                    storeEpoch: identity.storeEpoch
                )
            )
        ))
        XCTAssertFalse(ProductImageOwnerStoreGate.allows(
            scope: scope,
            selectedShop: selected,
            binding: AccountBinding(
                accountHash: binding.accountHash,
                storeIdentity: LocalStoreIdentity(
                    rawValue: identity.rawValue,
                    defaultStoreId: identity.defaultStoreId,
                    localStoreId: identity.localStoreId,
                    schemaVersion: identity.schemaVersion,
                    syncProtocolVersion: identity.syncProtocolVersion,
                    storeEpoch: identity.storeEpoch + 1
                )
            )
        ))
        XCTAssertFalse(ProductImageOwnerStoreGate.allows(
            scope: scope,
            selectedShop: selected,
            binding: AccountBinding(
                accountHash: binding.accountHash,
                storeIdentity: LocalStoreIdentity(
                    rawValue: identity.rawValue,
                    defaultStoreId: identity.defaultStoreId,
                    localStoreId: identity.localStoreId,
                    schemaVersion: 0,
                    syncProtocolVersion: identity.syncProtocolVersion,
                    storeEpoch: identity.storeEpoch
                )
            )
        ))
    }

    func testUndecodableReplacementJournalFailsClosedByRawPresence() {
        let suiteName = "ProductImageOwnerStoreRaceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let bindingStore = AccountBindingStore(defaults: defaults)
        defaults.set(Data([0xFF, 0x00, 0x7F]), forKey: "sync.accountBinding.v1.pendingReplacement")

        XCTAssertNil(bindingStore.pendingReplacement)
        XCTAssertTrue(bindingStore.hasPendingReplacementJournal)
        let accountID = UUID()
        let selected = makeSelectedShop(id: UUID())
        XCTAssertFalse(ProductImageOwnerStoreGate.allows(
            scope: ProductImageScope(accountID: accountID, shopID: selected.shopID),
            selectedShop: selected,
            binding: AccountBinding(
                accountHash: AccountBindingStore.accountHash(for: accountID),
                storeIdentity: selected.localStoreIdentity
            ),
            hasPendingReplacement: bindingStore.hasPendingReplacementJournal
        ))
    }

    func testPendingReplacementAuthorizationBlocksCacheReadAndAllWritesBeforeNetwork() async throws {
        let accountID = UUID()
        let selected = makeSelectedShop(id: UUID())
        let scope = ProductImageScope(accountID: accountID, shopID: selected.shopID)
        let binding = AccountBinding(
            accountHash: AccountBindingStore.accountHash(for: accountID),
            storeIdentity: selected.localStoreIdentity
        )
        let reference = ProductImageReference(
            scope: scope,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let root = temporaryRoot("authorization")
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let prepared = try makePreparedImage()
        try await cache.write(prepared.thumb.data, for: cacheKey(reference))
        let recorder = ProductImageSafetyRequestRecorder()
        ProductImageSafetyURLProtocol.handler = { request in
            recorder.record(request)
            throw ProductImageSafetyTestError.unexpectedRequest
        }
        defer { ProductImageSafetyURLProtocol.handler = nil }
        let service = makeService(
            accountID: accountID,
            cache: cache,
            scopeAuthorizationProvider: { candidate in
                ProductImageOwnerStoreGate.allows(
                    scope: candidate,
                    selectedShop: selected,
                    binding: binding,
                    hasPendingReplacement: true
                )
            }
        )

        await assertInvalidScope { _ = try await service.load(reference) }
        await assertInvalidScope {
            _ = try await service.upload(
                prepared: prepared,
                scope: scope,
                productID: reference.productID
            )
        }
        await assertInvalidScope {
            _ = try await service.remove(
                scope: scope,
                productID: reference.productID,
                versionID: reference.versionID
            )
        }

        XCTAssertEqual(recorder.requestCount, 0)
    }

    func testChildLoadSelfActivatesStoreAndUsesColdOfflineCache() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let reference = ProductImageReference(
            scope: scope,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let root = temporaryRoot("child-activate")
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        try await cache.write(try makePreparedImage().thumb.data, for: cacheKey(reference))
        let service = makeService(accountID: accountID, cache: cache) { _ in true }
        let store = ProductImageStore(service: service) { _ in true }

        await store.load(reference)

        XCTAssertNotNil(store.image(for: reference))
        XCTAssertEqual(store.source(for: reference), "cache")
        XCTAssertFalse(store.isLoading(reference))
    }

    func testRapidScopeABADoesNotLetStaleCleanupPurgeReactivatedScope() async throws {
        let accountID = UUID()
        let scopeA = ProductImageScope(accountID: accountID, shopID: UUID())
        let scopeB = ProductImageScope(accountID: accountID, shopID: UUID())
        let reference = ProductImageReference(
            scope: scopeA,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let root = temporaryRoot("scope-aba")
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let data = try makePreparedImage().thumb.data
        try await cache.write(data, for: cacheKey(reference))
        let service = makeService(accountID: accountID, cache: cache) { _ in true }
        let store = ProductImageStore(service: service) { _ in true }

        store.activate(scope: scopeA)
        store.activate(scope: scopeB)
        store.activate(scope: scopeA)
        await store.load(reference)
        try await Task.sleep(for: .milliseconds(40))

        XCTAssertNotNil(store.image(for: reference))
        let cached = try await cache.read(cacheKey(reference))
        XCTAssertEqual(cached, data)
    }

    func testCancelledFlushedReadBatchFinishesPromptlyAndOldTaskCannotClearNewLoadingState() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let reference = ProductImageReference(
            scope: scope,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let prepared = try makePreparedImage()
        let recorder = ProductImageSafetyRequestRecorder()
        ProductImageSafetyURLProtocol.handler = { request in
            let index = recorder.record(request)
            guard let url = request.url else { throw ProductImageSafetyTestError.badRequest }
            if request.httpMethod == "POST", url.path == "/api/shop/product-images/read-urls" {
                let body = ProductImageOwnerStoreRaceTests.readResponse(
                    reference: reference,
                    cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
                    metadata: prepared.thumb.metadata
                )
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: body,
                    delay: index == 1 ? 0.30 : 0.20
                )
            }
            if request.httpMethod == "GET" {
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url, contentType: "image/jpeg"),
                    data: prepared.thumb.data,
                    delay: 0
                )
            }
            throw ProductImageSafetyTestError.unexpectedRequest
        }
        defer { ProductImageSafetyURLProtocol.handler = nil }
        let root = temporaryRoot("batch-cancel")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = makeService(
            accountID: accountID,
            cache: ProductImageCache(rootDirectory: root),
            readBatchDelayNanoseconds: 0
        ) { _ in true }
        let store = ProductImageStore(service: service) { _ in true }
        store.activate(scope: scope)

        let first = Task { await store.load(reference) }
        try await recorder.waitFor(path: "/api/shop/product-images/read-urls", count: 1)
        let cancellationStart = Date()
        first.cancel()
        await first.value
        XCTAssertLessThan(Date().timeIntervalSince(cancellationStart), 0.15)

        let second = Task { await store.load(reference) }
        try await recorder.waitFor(path: "/api/shop/product-images/read-urls", count: 2)
        try await Task.sleep(for: .milliseconds(60))
        XCTAssertTrue(store.isLoading(reference))
        await second.value

        XCTAssertFalse(store.isLoading(reference))
        XCTAssertNotNil(store.image(for: reference))
        XCTAssertEqual(recorder.count(method: "GET"), 1)
    }

    func testRemoveInvalidatesDelayedOldVersionLoadBeforeItCanResurrectCache() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let reference = ProductImageReference(
            scope: scope,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let prepared = try makePreparedImage()
        let recorder = ProductImageSafetyRequestRecorder()
        ProductImageSafetyURLProtocol.handler = { request in
            recorder.record(request)
            guard let url = request.url else { throw ProductImageSafetyTestError.badRequest }
            switch (request.httpMethod, url.path) {
            case ("POST", "/api/shop/product-images/read-urls"):
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: ProductImageOwnerStoreRaceTests.readResponse(
                        reference: reference,
                        cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
                        metadata: prepared.thumb.metadata
                    ),
                    delay: 0
                )
            case ("GET", _):
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url, contentType: "image/jpeg"),
                    data: prepared.thumb.data,
                    delay: 0.30
                )
            case ("POST", "/api/shop/product-images/remove"):
                let data = Data("""
                {"currentImageVersionId":null,"imageUpdatedAt":"2026-07-19T12:00:00Z","ok":true,"operation":"remove","productId":"\(reference.productID.uuidString)","shopId":"\(scope.shopID.uuidString)","status":"removed","versionId":"\(reference.versionID.uuidString)"}
                """.utf8)
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: data,
                    delay: 0.20
                )
            default:
                throw ProductImageSafetyTestError.unexpectedRequest
            }
        }
        defer { ProductImageSafetyURLProtocol.handler = nil }
        let root = temporaryRoot("stale-remove")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let cache = ProductImageCache(rootDirectory: root)
        let service = makeService(accountID: accountID, cache: cache) { _ in true }

        let oldLoad = Task { try await service.load(reference) }
        try await recorder.waitFor(method: "GET", count: 1)
        let removal = Task {
            try await service.remove(
                scope: scope,
                productID: reference.productID,
                versionID: reference.versionID
            )
        }
        try await recorder.waitFor(path: "/api/shop/product-images/remove", count: 1)
        removal.cancel()
        let removalResult = try await removal.value
        _ = try? await oldLoad.value
        try await Task.sleep(for: .milliseconds(40))

        let cached = try await cache.read(cacheKey(reference))
        XCTAssertNil(cached)
        XCTAssertEqual(removalResult.status, "removed")
    }

    func testRemoveFenceRejectsCacheLoadStartedWhileCommitIsInFlight() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let reference = ProductImageReference(
            scope: scope,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let recorder = ProductImageSafetyRequestRecorder()
        ProductImageSafetyURLProtocol.handler = { request in
            recorder.record(request)
            guard let url = request.url,
                  request.httpMethod == "POST",
                  url.path == "/api/shop/product-images/remove" else {
                throw ProductImageSafetyTestError.unexpectedRequest
            }
            let data = Data("""
            {"currentImageVersionId":null,"imageUpdatedAt":"2026-07-19T12:00:00Z","ok":true,"operation":"remove","productId":"\(reference.productID.uuidString)","shopId":"\(scope.shopID.uuidString)","status":"removed","versionId":"\(reference.versionID.uuidString)"}
            """.utf8)
            return ProductImageSafetyStubResponse(
                response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                data: data,
                delay: 0.20
            )
        }
        defer { ProductImageSafetyURLProtocol.handler = nil }
        let root = temporaryRoot("remove-fence")
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        try await cache.write(try makePreparedImage().thumb.data, for: cacheKey(reference))
        let service = makeService(accountID: accountID, cache: cache) { _ in true }

        let removal = Task {
            try await service.remove(
                scope: scope,
                productID: reference.productID,
                versionID: reference.versionID
            )
        }
        try await recorder.waitFor(path: "/api/shop/product-images/remove", count: 1)
        do {
            _ = try await service.load(reference)
            XCTFail("A load started during remove must be fenced")
        } catch is CancellationError {
            // Expected: no cache read or network request may cross the mutation fence.
        }
        _ = try await removal.value

        XCTAssertEqual(recorder.count(path: "/api/shop/product-images/read-urls"), 0)
        let cachedAfterRemove = try await cache.read(cacheKey(reference))
        XCTAssertNil(cachedAfterRemove)
    }

    func testFinalizeFenceRejectsLateOldLoadAndInactiveScopeIsNotReseeded() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let replacementScope = ProductImageScope(accountID: accountID, shopID: UUID())
        let productID = UUID()
        let oldReference = ProductImageReference(
            scope: scope,
            productID: productID,
            versionID: UUID(),
            variant: .thumb
        )
        let newVersionID = UUID()
        let prepared = try makePreparedImage()
        let recorder = ProductImageSafetyRequestRecorder()
        ProductImageSafetyURLProtocol.handler = { request in
            recorder.record(request)
            guard let url = request.url else { throw ProductImageSafetyTestError.badRequest }
            switch (request.httpMethod, url.path) {
            case ("POST", "/api/shop/product-images/intent"):
                let base = "https://storage.product-image-safety.invalid/storage/v1/object/upload/sign/product-images/shops/\(scope.shopID.uuidString)/products/\(productID.uuidString)/primary/\(newVersionID.uuidString)"
                let data = Data("""
                {"cacheScope":"\(ProductImageService.expectedCacheScope(accountID: accountID))","mainUploadUrl":"\(base)/main.jpg","ok":true,"status":"upload_required","thumbUploadUrl":"\(base)/thumb.jpg","versionId":"\(newVersionID.uuidString)"}
                """.utf8)
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: data,
                    delay: 0
                )
            case ("PUT", _):
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: Data(),
                    delay: 0
                )
            case ("POST", "/api/shop/product-images/finalize"):
                let data = Data("""
                {"imageUpdatedAt":"2026-07-19T12:00:00Z","ok":true,"status":"finalized","versionId":"\(newVersionID.uuidString)"}
                """.utf8)
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: data,
                    delay: 0.20
                )
            default:
                throw ProductImageSafetyTestError.unexpectedRequest
            }
        }
        defer { ProductImageSafetyURLProtocol.handler = nil }
        let root = temporaryRoot("finalize-fence")
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let service = makeService(accountID: accountID, cache: cache) { _ in true }
        await service.setActiveScope(scope, generation: 1)

        let upload = Task {
            try await service.upload(
                prepared: prepared,
                scope: scope,
                productID: productID
            )
        }
        try await recorder.waitFor(path: "/api/shop/product-images/finalize", count: 1)
        do {
            _ = try await service.load(oldReference)
            XCTFail("A load started during finalize must be fenced")
        } catch is CancellationError {
            // Expected.
        }
        await service.setActiveScope(replacementScope, generation: 2)
        await service.deactivate(
            scope: scope,
            purgeAccountScope: false,
            lifecycleGeneration: 2
        )
        do {
            _ = try await upload.value
            XCTFail("An old-scope finalize must not publish after the active shop changes")
        } catch let error as ProductImageError {
            XCTAssertEqual(error, .accountChanged)
        }
        XCTAssertEqual(recorder.count(path: "/api/shop/product-images/read-urls"), 0)
        for variant in ProductImageVariant.allCases {
            let key = ProductImageCacheKey(
                cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
                shopID: scope.shopID,
                productID: productID,
                versionID: newVersionID,
                variant: variant
            )
            let cached = try await cache.read(key)
            XCTAssertNil(cached)
        }
    }

    func testSameScopeGenerationChangeRejectsLateNoopMutationCompletion() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let productID = UUID()
        let versionID = UUID()
        let prepared = try makePreparedImage()
        let recorder = ProductImageSafetyRequestRecorder()
        ProductImageSafetyURLProtocol.handler = { request in
            recorder.record(request)
            guard let url = request.url,
                  request.httpMethod == "POST",
                  url.path == "/api/shop/product-images/intent" else {
                throw ProductImageSafetyTestError.unexpectedRequest
            }
            let data = Data("""
            {"cacheScope":"\(ProductImageService.expectedCacheScope(accountID: accountID))","ok":true,"status":"noop","versionId":"\(versionID.uuidString)"}
            """.utf8)
            return ProductImageSafetyStubResponse(
                response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                data: data,
                delay: 0.20,
                ignoreStopLoading: true,
                onDelivery: { recorder.recordDelivery() }
            )
        }
        defer { ProductImageSafetyURLProtocol.handler = nil }
        let root = temporaryRoot("same-scope-noop-mutation")
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let service = makeService(accountID: accountID, cache: cache) { $0 == scope }
        await service.setActiveScope(scope, generation: 1)

        let upload = Task {
            try await service.upload(
                prepared: prepared,
                scope: scope,
                productID: productID
            )
        }
        try await recorder.waitFor(path: "/api/shop/product-images/intent", count: 1)
        await service.setActiveScope(scope, generation: 2)
        try await recorder.waitForDeliveries(count: 1)

        do {
            _ = try await upload.value
            XCTFail("A G1 noop must not publish completion into same-scope G2")
        } catch let error as ProductImageError {
            XCTAssertEqual(error, .accountChanged)
        }
        let diskEntryCount = try await cache.diskEntryCount()
        XCTAssertEqual(diskEntryCount, 0)
    }

    func testStoreRejectsConcurrentMutationWithoutLosingFirstCommitOutcome() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let productID = UUID()
        let newVersionID = UUID()
        let prepared = try makePreparedImage()
        let recorder = ProductImageSafetyRequestRecorder()
        ProductImageSafetyURLProtocol.handler = { request in
            recorder.record(request)
            guard let url = request.url else { throw ProductImageSafetyTestError.badRequest }
            switch (request.httpMethod, url.path) {
            case ("POST", "/api/shop/product-images/intent"):
                let base = "https://storage.product-image-safety.invalid/storage/v1/object/upload/sign/product-images/shops/\(scope.shopID.uuidString)/products/\(productID.uuidString)/primary/\(newVersionID.uuidString)"
                let data = Data("""
                {"cacheScope":"\(ProductImageService.expectedCacheScope(accountID: accountID))","mainUploadUrl":"\(base)/main.jpg","ok":true,"status":"upload_required","thumbUploadUrl":"\(base)/thumb.jpg","versionId":"\(newVersionID.uuidString)"}
                """.utf8)
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: data,
                    delay: 0.20
                )
            case ("PUT", _):
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: Data(),
                    delay: 0
                )
            case ("POST", "/api/shop/product-images/finalize"):
                let data = Data("""
                {"imageUpdatedAt":"2026-07-19T12:00:00Z","ok":true,"status":"finalized","versionId":"\(newVersionID.uuidString)"}
                """.utf8)
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: data,
                    delay: 0
                )
            case ("POST", "/api/shop/product-images/remove"):
                let data = Data("""
                {"currentImageVersionId":null,"imageUpdatedAt":"2026-07-19T12:01:00Z","ok":true,"operation":"remove","productId":"\(productID.uuidString)","shopId":"\(scope.shopID.uuidString)","status":"removed","versionId":"\(newVersionID.uuidString)"}
                """.utf8)
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: data,
                    delay: 0
                )
            default:
                throw ProductImageSafetyTestError.unexpectedRequest
            }
        }
        defer { ProductImageSafetyURLProtocol.handler = nil }
        let root = temporaryRoot("store-mutation-admission")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let input = root.appendingPathComponent("input.jpg")
        try prepared.main.data.write(to: input, options: [.atomic])
        let service = makeService(
            accountID: accountID,
            cache: ProductImageCache(rootDirectory: root.appendingPathComponent("cache"))
        ) { _ in true }
        let store = ProductImageStore(service: service) { _ in true }
        store.activate(scope: scope)

        let first = Task {
            try await store.upload(
                fileURL: input,
                scope: scope,
                productID: productID,
                previousVersionID: nil,
                retainMutationLeaseAfterResponse: true
            )
        }
        try await recorder.waitFor(path: "/api/shop/product-images/intent", count: 1)
        XCTAssertFalse(store.beginAccountStoreReplacementLease())
        do {
            _ = try await store.remove(
                scope: scope,
                productID: productID,
                versionID: UUID()
            )
            XCTFail("Concurrent store mutation must be rejected")
        } catch let error as ProductImageError {
            XCTAssertEqual(error, .invalidResponse)
        }
        let result = try await first.value

        XCTAssertEqual(result.versionID, newVersionID)
        XCTAssertEqual(store.operationStage(productID: productID), .completed)
        XCTAssertEqual(recorder.count(path: "/api/shop/product-images/remove"), 0)
        XCTAssertFalse(store.beginAccountStoreReplacementLease())
        store.finishMutationLease(scope: scope, productID: productID)
        XCTAssertTrue(store.beginAccountStoreReplacementLease())
        XCTAssertFalse(store.canBeginAccountStoreReplacement)
        let requestCountBeforeBlockedAttempts = recorder.requestCount
        do {
            _ = try await store.upload(
                fileURL: input,
                scope: scope,
                productID: UUID(),
                previousVersionID: nil
            )
            XCTFail("Upload must not start while store replacement owns the lease")
        } catch let error as ProductImageError {
            XCTAssertEqual(error, .accountChanged)
        }
        do {
            _ = try await store.remove(
                scope: scope,
                productID: UUID(),
                versionID: UUID()
            )
            XCTFail("Remove must not start while store replacement owns the lease")
        } catch let error as ProductImageError {
            XCTAssertEqual(error, .accountChanged)
        }
        XCTAssertEqual(recorder.requestCount, requestCountBeforeBlockedAttempts)
        store.endAccountStoreReplacementLease()
        XCTAssertTrue(store.canBeginAccountStoreReplacement)

        _ = try await store.remove(
            scope: scope,
            productID: productID,
            versionID: newVersionID,
            retainMutationLeaseAfterResponse: true
        )
        XCTAssertFalse(store.beginAccountStoreReplacementLease())
        store.finishMutationLease(scope: scope, productID: productID)
        XCTAssertTrue(store.beginAccountStoreReplacementLease())
        store.endAccountStoreReplacementLease()
    }

    func testFinalizeCommitBoundaryIgnoresOuterCancellationAndPublishesNewVersion() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let productID = UUID()
        let oldVersionID = UUID()
        let versionID = UUID()
        let prepared = try makePreparedImage()
        let oldReference = ProductImageReference(
            scope: scope,
            productID: productID,
            versionID: oldVersionID,
            variant: .thumb
        )
        let recorder = ProductImageSafetyRequestRecorder()
        ProductImageSafetyURLProtocol.handler = { request in
            recorder.record(request)
            guard let url = request.url else { throw ProductImageSafetyTestError.badRequest }
            switch (request.httpMethod, url.path) {
            case ("POST", "/api/shop/product-images/read-urls"):
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: ProductImageOwnerStoreRaceTests.readResponse(
                        reference: oldReference,
                        cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
                        metadata: prepared.thumb.metadata
                    ),
                    delay: 0
                )
            case ("GET", _):
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url, contentType: "image/jpeg"),
                    data: prepared.thumb.data,
                    delay: 0.30
                )
            case ("POST", "/api/shop/product-images/intent"):
                let base = "https://storage.product-image-safety.invalid/storage/v1/object/upload/sign/product-images/shops/\(scope.shopID.uuidString)/products/\(productID.uuidString)/primary/\(versionID.uuidString)"
                let data = Data("""
                {"cacheScope":"\(ProductImageService.expectedCacheScope(accountID: accountID))","mainUploadUrl":"\(base)/main.jpg","ok":true,"status":"upload_required","thumbUploadUrl":"\(base)/thumb.jpg","versionId":"\(versionID.uuidString)"}
                """.utf8)
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: data,
                    delay: 0
                )
            case ("PUT", _):
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: Data(),
                    delay: 0
                )
            case ("POST", "/api/shop/product-images/finalize"):
                let data = Data("""
                {"imageUpdatedAt":"2026-07-19T12:00:00Z","ok":true,"status":"finalized","versionId":"\(versionID.uuidString)"}
                """.utf8)
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: data,
                    delay: 0.20
                )
            default:
                throw ProductImageSafetyTestError.unexpectedRequest
            }
        }
        defer { ProductImageSafetyURLProtocol.handler = nil }
        let root = temporaryRoot("commit-boundary")
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let service = makeService(accountID: accountID, cache: cache) { _ in true }
        let store = ProductImageStore(service: service) { _ in true }
        store.activate(scope: scope)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let input = root.appendingPathComponent("input.jpg")
        try prepared.main.data.write(to: input, options: [.atomic])
        let oldLoad = Task { try await service.load(oldReference) }
        try await recorder.waitFor(method: "GET", count: 1)

        let upload = Task {
            try await store.upload(
                fileURL: input,
                scope: scope,
                productID: productID,
                previousVersionID: oldVersionID
            )
        }
        try await waitForStage(.finalizing, store: store, productID: productID)
        XCTAssertFalse(store.cancelOperation(productID: productID, scope: scope))
        upload.cancel()
        let result = try await upload.value
        _ = try? await oldLoad.value

        XCTAssertEqual(result.versionID, versionID)
        XCTAssertEqual(store.operationStage(productID: productID), .completed)
        XCTAssertNotNil(store.image(for: ProductImageReference(
            scope: scope,
            productID: productID,
            versionID: versionID,
            variant: .main
        )))
        let staleCached = try await cache.read(cacheKey(oldReference))
        XCTAssertNil(staleCached)
        let newCached = try await cache.read(ProductImageCacheKey(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            shopID: scope.shopID,
            productID: productID,
            versionID: versionID,
            variant: .thumb
        ))
        XCTAssertEqual(newCached, prepared.thumb.data)
        XCTAssertFalse(ProductImageOperationStage.finalizing.allowsCancellation)
        XCTAssertFalse(ProductImageOperationStage.removing.allowsCancellation)
    }

    func testPreboundResource64LateCompletionsNeverPublishAnd100ConsumersSingleFlight() async throws {
        let accountA = UUID(uuidString: "a1390000-0000-4000-8000-000000000011")!
        let accountB = UUID(uuidString: "b1390000-0000-4000-8000-000000000012")!
        let scopeA = ProductImageScope(
            accountID: accountA,
            shopID: UUID(uuidString: "a1390000-0000-4000-8000-000000000013")!
        )
        let scopeB = ProductImageScope(
            accountID: accountB,
            shopID: UUID(uuidString: "b1390000-0000-4000-8000-000000000014")!
        )
        let productID = UUID(uuidString: "a1390000-0000-4000-8000-000000000015")!
        let prepared = try makePreparedImage()
        let scopeState = ProductImageAuthorizedScopeState(scopeA)
        let recorder = ProductImageSafetyRequestRecorder()
        ProductImageSafetyURLProtocol.handler = { request in
            recorder.record(request)
            guard let url = request.url else {
                throw ProductImageSafetyTestError.badRequest
            }
            if request.httpMethod == "POST",
               url.path == "/api/shop/product-images/read-urls" {
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: try ProductImageOwnerStoreRaceTests.readResponse(
                        request: request,
                        scopeA: scopeA,
                        scopeB: scopeB,
                        metadata: prepared.thumb.metadata
                    ),
                    delay: 0
                )
            }
            if request.httpMethod == "GET" {
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(
                        url: url,
                        contentType: "image/jpeg"
                    ),
                    data: prepared.thumb.data,
                    delay: 0.30,
                    ignoreStopLoading: true,
                    onDelivery: { recorder.recordDelivery() }
                )
            }
            throw ProductImageSafetyTestError.unexpectedRequest
        }
        defer { ProductImageSafetyURLProtocol.handler = nil }

        let root = temporaryRoot("prebound-runtime")
        defer {
            if FileManager.default.fileExists(atPath: root.path) {
                try? FileManager.default.removeItem(at: root)
            }
        }
        let cache = ProductImageCache(rootDirectory: root)
        let service = makeService(
            accountID: accountA,
            cache: cache,
            maximumConcurrentDownloads: 64,
            maximumConcurrentReadRequests: 8,
            readBatchDelayNanoseconds: 20_000_000,
            sessionAccountIDProvider: { scopeState.currentAccountID }
        ) { scopeState.allows($0) }
        let store = ProductImageStore(service: service) { scopeState.allows($0) }
        await service.setActiveScope(scopeA, generation: 1)
        store.activate(scope: scopeA)

        let referencesA = (0..<64).map { index in
            ProductImageReference(
                scope: scopeA,
                productID: productID,
                versionID: UUID(
                    uuidString: String(
                        format: "a1390000-0000-4000-8000-%012d",
                        100 + index
                    )
                )!,
                variant: .thumb
            )
        }
        let uiLoad = Task { await store.load(referencesA[0]) }
        let staleLoads = referencesA.dropFirst().map { reference in
            Task<Result<ProductImageLoadResult, Error>, Never> {
                do {
                    return .success(try await service.load(reference))
                } catch {
                    return .failure(error)
                }
            }
        }
        try await recorder.waitFor(method: "GET", count: 64)
        try await Task.sleep(for: .milliseconds(50))

        scopeState.set(scopeB)
        store.activate(scope: scopeB)
        await service.setActiveScope(scopeB, generation: 2)
        await service.deactivate(
            scope: scopeA,
            purgeAccountScope: true,
            lifecycleGeneration: 2
        )
        try await recorder.waitForDeliveries(count: 64)
        await uiLoad.value
        let staleResults = await withTaskGroup(
            of: Result<ProductImageLoadResult, Error>.self
        ) { group in
            staleLoads.forEach { task in
                group.addTask { await task.value }
            }
            var results: [Result<ProductImageLoadResult, Error>] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
        XCTAssertEqual(staleResults.count, 63)
        XCTAssertTrue(staleResults.allSatisfy {
            if case .failure = $0 { return true }
            return false
        })
        XCTAssertNil(store.image(for: referencesA[0]))
        let staleDiskEntryCount = try await cache.diskEntryCount()
        XCTAssertEqual(staleDiskEntryCount, 0)

        let postsBeforeB = recorder.count(path: "/api/shop/product-images/read-urls")
        let getsBeforeB = recorder.count(method: "GET")
        let referenceB = ProductImageReference(
            scope: scopeB,
            productID: productID,
            versionID: UUID(uuidString: "b1390000-0000-4000-8000-000000000016")!,
            variant: .thumb
        )
        let consumers = (0..<100).map { _ in
            Task { try await service.load(referenceB) }
        }
        var currentResults: [ProductImageLoadResult] = []
        for consumer in consumers {
            currentResults.append(try await consumer.value)
        }
        XCTAssertEqual(currentResults.count, 100)
        XCTAssertTrue(currentResults.allSatisfy { $0.data == prepared.thumb.data })
        XCTAssertEqual(
            recorder.count(path: "/api/shop/product-images/read-urls") - postsBeforeB,
            1
        )
        XCTAssertEqual(recorder.count(method: "GET") - getsBeforeB, 1)
        let currentDiskEntryCount = try await cache.diskEntryCount()
        XCTAssertEqual(currentDiskEntryCount, 1)

        await store.load(referenceB)
        XCTAssertNotNil(store.image(for: referenceB))
        XCTAssertNil(store.image(for: referencesA[0]))
    }

    func testSameScopeStoreGenerationCancelsNonCooperativeLoadAndPurgesOldBytes() async throws {
        let accountID = UUID()
        let scope = ProductImageScope(accountID: accountID, shopID: UUID())
        let prepared = try makePreparedImage()
        let oldReference = ProductImageReference(
            scope: scope,
            productID: UUID(),
            versionID: UUID(),
            variant: .thumb
        )
        let newReference = ProductImageReference(
            scope: scope,
            productID: oldReference.productID,
            versionID: UUID(),
            variant: .thumb
        )
        let recorder = ProductImageSafetyRequestRecorder()
        ProductImageSafetyURLProtocol.handler = { request in
            recorder.record(request)
            guard let url = request.url else {
                throw ProductImageSafetyTestError.badRequest
            }
            if request.httpMethod == "POST",
               url.path == "/api/shop/product-images/read-urls" {
                let body = try ProductImageOwnerStoreRaceTests.requestBodyData(from: request)
                let object = try XCTUnwrap(
                    JSONSerialization.jsonObject(with: try XCTUnwrap(body)) as? [String: Any]
                )
                let refs = try XCTUnwrap(object["refs"] as? [[String: Any]])
                let versionID = try XCTUnwrap(refs.first?["versionId"] as? String)
                let reference = versionID == oldReference.versionID.uuidString
                    ? oldReference
                    : newReference
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(url: url),
                    data: ProductImageOwnerStoreRaceTests.readResponse(
                        reference: reference,
                        cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
                        metadata: prepared.thumb.metadata
                    ),
                    delay: 0
                )
            }
            if request.httpMethod == "GET" {
                return ProductImageSafetyStubResponse(
                    response: ProductImageOwnerStoreRaceTests.httpResponse(
                        url: url,
                        contentType: "image/jpeg"
                    ),
                    data: prepared.thumb.data,
                    delay: 0.20,
                    ignoreStopLoading: true,
                    onDelivery: { recorder.recordDelivery() }
                )
            }
            throw ProductImageSafetyTestError.unexpectedRequest
        }
        defer { ProductImageSafetyURLProtocol.handler = nil }

        let root = temporaryRoot("same-scope-generation")
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = ProductImageCache(rootDirectory: root)
        let service = makeService(accountID: accountID, cache: cache) { $0 == scope }
        await service.setActiveScope(scope, generation: 1)

        let oldLoad = Task<Result<ProductImageLoadResult, Error>, Never> {
            do {
                return .success(try await service.load(oldReference))
            } catch {
                return .failure(error)
            }
        }
        try await recorder.waitFor(method: "GET", count: 1)
        await service.setActiveScope(scope, generation: 2)
        try await recorder.waitForDeliveries(count: 1)

        if case .success = await oldLoad.value {
            XCTFail("A G1 load must not publish after the same-scope G2 boundary")
        }
        let staleDiskEntryCount = try await cache.diskEntryCount()
        XCTAssertEqual(staleDiskEntryCount, 0)

        let current = try await service.load(newReference)
        XCTAssertEqual(current.data, prepared.thumb.data)
        let currentDiskEntryCount = try await cache.diskEntryCount()
        XCTAssertEqual(currentDiskEntryCount, 1)
    }

    private func makeService(
        accountID: UUID,
        cache: ProductImageCache,
        maximumConcurrentDownloads: Int = ProductImageService.defaultMaximumConcurrentDownloads,
        maximumConcurrentReadRequests: Int = ProductImageService.defaultMaximumConcurrentReadRequests,
        readBatchDelayNanoseconds: UInt64 = 0,
        sessionAccountIDProvider: (@Sendable () -> UUID)? = nil,
        scopeAuthorizationProvider: @escaping ProductImageScopeAuthorizationProvider
    ) -> ProductImageService {
        let apiSession = makeSession()
        let storageSession = makeSession()
        let resolvedAccountIDProvider = sessionAccountIDProvider ?? { accountID }
        return ProductImageService(
            api: ProductImageAPIClient(
                apiBaseURL: URL(string: "https://admin.product-image-safety.invalid")!,
                storageBaseURL: URL(string: "https://storage.product-image-safety.invalid")!,
                apiSession: apiSession,
                storageSession: storageSession
            ),
            cache: cache,
            maximumConcurrentDownloads: maximumConcurrentDownloads,
            maximumConcurrentReadRequests: maximumConcurrentReadRequests,
            readBatchDelayNanoseconds: readBatchDelayNanoseconds,
            scopeAuthorizationProvider: scopeAuthorizationProvider
        ) {
            ProductImageSessionSnapshot(
                accountID: resolvedAccountIDProvider(),
                accessToken: "fixture"
            )
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ProductImageSafetyURLProtocol.self]
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.httpMaximumConnectionsPerHost = 128
        return URLSession(configuration: configuration)
    }

    private func makeSelectedShop(
        id: UUID,
        status: String = "active",
        selectable: Bool = true
    ) -> SelectedShop {
        SelectedShop(
            shopID: id,
            code: nil,
            name: "Safety fixture",
            role: "owner",
            status: status,
            selectable: selectable,
            canWrite: true,
            selectedAt: Date(timeIntervalSince1970: 1)
        )
    }

    private func temporaryRoot(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("task139-\(name)-\(UUID().uuidString)", isDirectory: true)
    }

    private func cacheKey(_ reference: ProductImageReference) -> ProductImageCacheKey {
        ProductImageCacheKey(
            cacheScope: ProductImageService.expectedCacheScope(accountID: reference.scope.accountID),
            shopID: reference.scope.shopID,
            productID: reference.productID,
            versionID: reference.versionID,
            variant: reference.variant
        )
    }

    private func makePreparedImage() throws -> PreparedProductImage {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 96,
            height: 72,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.2, green: 0.55, blue: 0.8, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 96, height: 72))
        let image = try XCTUnwrap(context.makeImage())
        let output = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return try ProductImageProcessor.prepare(data: output as Data)
    }

    private func assertInvalidScope(
        _ operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected owner/store authorization to fail closed")
        } catch let error as ProductImageError {
            XCTAssertEqual(error, .invalidScope)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func waitForStage(
        _ expected: ProductImageOperationStage,
        store: ProductImageStore,
        productID: UUID
    ) async throws {
        for _ in 0..<300 {
            if store.operationStage(productID: productID) == expected { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw ProductImageSafetyTestError.timedOut
    }

    nonisolated private static func httpResponse(
        url: URL,
        contentType: String = "application/json"
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": contentType]
        )!
    }

    nonisolated private static func readResponse(
        reference: ProductImageReference,
        cacheScope: String,
        metadata: ProductImageMetadata
    ) -> Data {
        let path = "/storage/v1/object/sign/product-images/shops/\(reference.scope.shopID.uuidString)/products/\(reference.productID.uuidString)/primary/\(reference.versionID.uuidString)/\(reference.variant.rawValue).jpg"
        return Data("""
        {"cacheScope":"\(cacheScope)","items":[{"expiresAt":"\(task139SignedURLExpiry())","metadata":{"bytes":\(metadata.bytes),"height":\(metadata.height),"mimeType":"\(metadata.mimeType)","sha256":"\(metadata.sha256)","width":\(metadata.width)},"productId":"\(reference.productID.uuidString)","signedUrl":"https://storage.product-image-safety.invalid\(path)?token=redacted","status":"ready","variant":"\(reference.variant.rawValue)","versionId":"\(reference.versionID.uuidString)"}],"ok":true}
        """.utf8)
    }

    nonisolated private static func readResponse(
        request: URLRequest,
        scopeA: ProductImageScope,
        scopeB: ProductImageScope,
        metadata: ProductImageMetadata
    ) throws -> Data {
        guard let body = try requestBodyData(from: request),
              let object = try JSONSerialization.jsonObject(with: body) as? [String: Any],
              let shopIDRaw = object["shopId"] as? String,
              let shopID = UUID(uuidString: shopIDRaw),
              let refs = object["refs"] as? [[String: Any]],
              !refs.isEmpty else {
            throw ProductImageSafetyTestError.badRequest
        }
        let accountID: UUID
        if shopID == scopeA.shopID {
            accountID = scopeA.accountID
        } else if shopID == scopeB.shopID {
            accountID = scopeB.accountID
        } else {
            throw ProductImageSafetyTestError.badRequest
        }
        let items = try refs.map { ref -> [String: Any] in
            guard let productID = ref["productId"] as? String,
                  let versionID = ref["versionId"] as? String,
                  let variant = ref["variant"] as? String else {
                throw ProductImageSafetyTestError.badRequest
            }
            return [
                "expiresAt": task139SignedURLExpiry(),
                "metadata": [
                    "bytes": metadata.bytes,
                    "height": metadata.height,
                    "mimeType": metadata.mimeType,
                    "sha256": metadata.sha256,
                    "width": metadata.width
                ],
                "productId": productID,
                "signedUrl": "https://storage.product-image-safety.invalid/"
                    + "storage/v1/object/sign/product-images/shops/\(shopIDRaw)/"
                    + "products/\(productID)/primary/\(versionID)/\(variant).jpg",
                "status": "ready",
                "variant": variant,
                "versionId": versionID
            ]
        }
        return try JSONSerialization.data(withJSONObject: [
            "cacheScope": ProductImageService.expectedCacheScope(accountID: accountID),
            "items": items,
            "ok": true
        ])
    }

    nonisolated private static func requestBodyData(from request: URLRequest) throws -> Data? {
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
                throw stream.streamError ?? ProductImageSafetyTestError.badRequest
            }
            if count == 0 {
                break
            }
            result.append(buffer, count: count)
        }
        return result
    }
}

private struct ProductImageSafetyStubResponse: @unchecked Sendable {
    let response: HTTPURLResponse
    let data: Data
    let delay: TimeInterval
    var ignoreStopLoading = false
    var onDelivery: (@Sendable () -> Void)? = nil
}

private final class ProductImageSafetyRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [(method: String, path: String)] = []
    private var deliveries = 0

    @discardableResult
    func record(_ request: URLRequest) -> Int {
        lock.withLock {
            requests.append((request.httpMethod ?? "", request.url?.path ?? ""))
            return requests.count
        }
    }

    var requestCount: Int {
        lock.withLock { requests.count }
    }

    func recordDelivery() {
        lock.withLock { deliveries += 1 }
    }

    func count(method: String? = nil, path: String? = nil) -> Int {
        lock.withLock {
            requests.filter { item in
                (method == nil || item.method == method)
                    && (path == nil || item.path == path)
            }.count
        }
    }

    func waitFor(method: String? = nil, path: String? = nil, count expected: Int) async throws {
        for _ in 0..<300 {
            if count(method: method, path: path) >= expected { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw ProductImageSafetyTestError.timedOut
    }

    func waitForDeliveries(count expected: Int) async throws {
        for _ in 0..<300 {
            if lock.withLock({ deliveries >= expected }) { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw ProductImageSafetyTestError.timedOut
    }
}

private final class ProductImageSafetyURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> ProductImageSafetyStubResponse
    nonisolated(unsafe) static var handler: Handler?

    private let stateLock = NSLock()
    private var ignoreStopLoading = false
    private var stopped = false
    private var workItem: DispatchWorkItem?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw ProductImageSafetyTestError.unexpectedRequest
            }
            let stub = try handler(request)
            let workItem = DispatchWorkItem { [self] in
                guard beginDelivery() else { return }
                stub.onDelivery?()
                self.client?.urlProtocol(self, didReceive: stub.response, cacheStoragePolicy: .notAllowed)
                self.client?.urlProtocol(self, didLoad: stub.data)
                self.client?.urlProtocolDidFinishLoading(self)
            }
            let shouldSchedule = stateLock.withLock {
                guard !stopped else { return false }
                ignoreStopLoading = stub.ignoreStopLoading
                self.workItem = workItem
                return true
            }
            guard shouldSchedule else { return }
            if stub.delay > 0 {
                DispatchQueue.global(qos: .userInitiated).asyncAfter(
                    deadline: .now() + stub.delay,
                    execute: workItem
                )
            } else {
                DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
            }
        } catch {
            guard beginDelivery() else { return }
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        let item = stateLock.withLock { () -> DispatchWorkItem? in
            guard !ignoreStopLoading else { return nil }
            stopped = true
            defer { workItem = nil }
            return workItem
        }
        item?.cancel()
    }

    private func beginDelivery() -> Bool {
        stateLock.withLock {
            guard !stopped else { return false }
            workItem = nil
            return true
        }
    }
}

private final class ProductImageAuthorizedScopeState: @unchecked Sendable {
    private let lock = NSLock()
    private var scope: ProductImageScope

    init(_ scope: ProductImageScope) {
        self.scope = scope
    }

    var currentAccountID: UUID {
        lock.withLock { scope.accountID }
    }

    func allows(_ candidate: ProductImageScope) -> Bool {
        lock.withLock { candidate == scope }
    }

    func set(_ value: ProductImageScope) {
        lock.withLock { scope = value }
    }
}

private enum ProductImageSafetyTestError: Error {
    case badRequest
    case timedOut
    case unexpectedRequest
}
