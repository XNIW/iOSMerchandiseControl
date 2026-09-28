import Combine
import Foundation
import UIKit
import XCTest
@testable import iOSMerchandiseControl

final class StorefrontAuthoringContractTests: XCTestCase {
    func testThreeWayMergeOverlaysOnlyFieldsStillDifferentFromBase() throws {
        var base = StorefrontEditorDraft()
        base.publicName = "A"
        base.publicDescription = "Server old"
        base.publicPrice = 1_000

        var local = base
        local.publicName = "B"
        local.publicName = "A" // A → B → A is no longer dirty.
        local.publicPrice = 1_200

        var server = base
        server.publicName = "C"
        server.publicDescription = "Updated by iOS"
        server.publicPrice = 1_100

        let dirty = storefrontChangedFields(base: base, draft: local)
        let merged = storefrontOverlay(server: server, local: local, fields: dirty)

        XCTAssertEqual(dirty, [.publicPrice])
        XCTAssertEqual(merged.publicName, "C")
        XCTAssertEqual(merged.publicDescription, "Updated by iOS")
        XCTAssertEqual(merged.publicPrice, 1_200)
    }

    func testOperationalPriceDoesNotChangePublicPriceUntilExplicitAlignment() {
        var draft = StorefrontEditorDraft()
        draft.publicName = "Public"
        draft.publicPrice = 5_000
        let changedOperationalPrice = 6_000.0

        XCTAssertEqual(draft.publicPrice, 5_000)

        let aligned = storefrontAlignedDraft(
            draft,
            operationalName: "Internal",
            operationalRetailPrice: changedOperationalPrice,
            operationalCategoryRemoteID: nil,
            categories: []
        )
        XCTAssertEqual(aligned.publicPrice, 6_000)
        XCTAssertEqual(aligned.publicName, "Internal")
    }

    func testCategoryAlignmentUsesStableRemoteMappingNotName() {
        let sourceID = UUID()
        let publicID = UUID()
        let category = StorefrontCategory(
            categoryId: publicID,
            sourceCategoryId: sourceID,
            publicName: "Renamed public category",
            status: "active",
            updatedAt: "2026-08-21T12:00:00Z"
        )
        let aligned = storefrontAlignedDraft(
            StorefrontEditorDraft(),
            operationalName: "Product",
            operationalRetailPrice: nil,
            operationalCategoryRemoteID: sourceID,
            categories: [category]
        )
        XCTAssertEqual(aligned.storefrontCategoryId, publicID)
    }

    func testPublicPreviewPayloadExplicitlyExcludesInternalFields() throws {
        var draft = StorefrontEditorDraft()
        draft.publicName = "Public"
        draft.publicDescription = "Customer description"
        draft.publicPrice = 9_990
        draft.pickupEnabled = true
        let encoded = try JSONEncoder().encode(
            storefrontPublicPreviewPayload(draft: draft, publication: nil)
        )
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let forbidden = Set([
            "purchasePrice", "cost", "margin", "supplier", "stockQuantity",
            "warehouseLocation", "internalNotes", "priceHistory", "audit",
            "remoteRef", "staffIdentity", "barcode", "taxData", "posData"
        ])
        XCTAssertTrue(forbidden.isDisjoint(with: Set(object.keys)))
        XCTAssertEqual(object["name"] as? String, "Public")
        XCTAssertEqual(object["price"] as? Int, 9_990)
    }

    func testPublicImageURLFailsClosed() {
        XCTAssertNil(safePublicImageURL("http://example.test/image.webp"))
        XCTAssertNil(safePublicImageURL("https://user:password@example.test/image.webp"))
        XCTAssertNil(safePublicImageURL("https://example.test/image.webp#token"))
        XCTAssertEqual(
            safePublicImageURL("https://cdn.example.test/shop/image.webp")?.host,
            "cdn.example.test"
        )
    }

    func testDraftValidationRejectsOversizedAndInvalidSchedulePayloads() {
        var draft = StorefrontEditorDraft()
        draft.publicName = String(repeating: "x", count: 201)
        draft.publicPrice = 1_000
        XCTAssertEqual(storefrontDraftValidationCode(draft, operation: .saveDraft), "validation")

        draft.publicName = "Valid"
        draft.promotionStartsAt = "2026-08-22T12:00:00Z"
        draft.promotionEndsAt = "2026-08-21T12:00:00Z"
        XCTAssertEqual(storefrontDraftValidationCode(draft, operation: .saveDraft), "schedule")

        draft.promotionStartsAt = "2026-08-21T12:00:00Z"
        draft.promotionEndsAt = "2026-08-22T12:00:00Z"
        draft.storefrontCategoryId = UUID()
        draft.pickupEnabled = false
        XCTAssertEqual(storefrontDraftValidationCode(draft, operation: .publish), "validation")
    }

    func testBackendStaleRevisionEnvelopeMapsToConflictWithServerPayload() throws {
        let productID = UUID()
        let server = try makePublication(productID: productID, version: 11, publicName: "Server")
        let serverObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(server)) as? [String: Any]
        )
        let envelope = try JSONSerialization.data(withJSONObject: [
            "ok": false,
            "code": "stale_revision",
            "idempotent": false,
            "server": serverObject
        ])
        let response = try JSONDecoder().decode(StorefrontAuthoringMutationResponse.self, from: envelope)

        XCTAssertEqual(
            storefrontMutationFailure(code: response.code, server: response.server),
            .conflict(server)
        )
    }
}

@MainActor
final class StorefrontImageAdoptionTests: XCTestCase {
    override func tearDown() {
        StorefrontAdoptURLProtocol.handler = nil
        super.tearDown()
    }

    func testAdoptionUsesExistingAuthenticatedImageStackAndBoundedContract() async throws {
        let shopID = UUID()
        let publicationID = UUID()
        let sourceVersionID = UUID()
        let imagePublicationID = UUID()
        StorefrontAdoptURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/shop/storefront/images/adopt")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            let body = try XCTUnwrap(requestBodyData(request))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
            XCTAssertEqual(object["shopId"], shopID.uuidString.uppercased())
            XCTAssertEqual(object["publicationId"], publicationID.uuidString.uppercased())
            XCTAssertEqual(object["sourceImageVersionId"], sourceVersionID.uuidString.uppercased())
            let data = try JSONSerialization.data(withJSONObject: [
                "ok": true,
                "status": "finalized",
                "imagePublicationId": imagePublicationID.uuidString.lowercased()
            ])
            return (HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!, data)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StorefrontAdoptURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let api = ProductImageAPIClient(
            apiBaseURL: URL(string: "https://images.example.test")!,
            storageBaseURL: URL(string: "https://storage.example.test")!,
            apiSession: session,
            storageSession: session
        )

        let response = try await api.adoptForStorefront(
            scope: ProductImageScope(accountID: UUID(), shopID: shopID),
            publicationID: publicationID,
            sourceImageVersionID: sourceVersionID,
            accessToken: "test-token"
        )
        XCTAssertEqual(response.ok, true)
        XCTAssertEqual(response.imagePublicationId, imagePublicationID)
    }

    func testAdoptedImageCandidateIsAvailableToDraftPreviewBeforeAuthoringAck() async throws {
        let scope = ProductImageScope(accountID: UUID(), shopID: UUID())
        let productID = UUID()
        let sourceVersionID = UUID()
        let imagePublicationID = UUID()
        let store = ProductImageStore(service: nil)
        let reference = ProductImageReference(
            scope: scope,
            productID: productID,
            versionID: sourceVersionID,
            variant: .thumb
        )
        store.seedTask138VisualFixture(
            scope: scope,
            images: [reference: try XCTUnwrap(UIImage(systemName: "photo"))]
        )

        await store.stageStorefrontPreviewCandidate(
            scope: scope,
            imagePublicationID: imagePublicationID,
            sourceProductID: productID,
            sourceImageVersionID: sourceVersionID
        )

        XCTAssertNotNil(store.storefrontPublicImage(
            scope: scope,
            imagePublicationID: imagePublicationID,
            variant: .thumb
        ))
        XCTAssertNotNil(store.storefrontPublicImage(
            scope: scope,
            imagePublicationID: imagePublicationID,
            variant: .detail
        ))
    }

    func testPublicImageDownloadUsesOwnedStoragePathAndWebPContract() async throws {
        let imagePublicationID = UUID()
        StorefrontAdoptURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertTrue(request.url?.path.contains(imagePublicationID.uuidString.lowercased()) == true)
            let data = Data("RIFF0000WEBP".utf8)
            return (HTTPURLResponse(
                url: try XCTUnwrap(request.url),
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "image/webp"]
            )!, data)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StorefrontAdoptURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let api = ProductImageAPIClient(
            apiBaseURL: URL(string: "https://images.example.test")!,
            storageBaseURL: URL(string: "https://storage.example.test")!,
            apiSession: session,
            storageSession: session
        )
        let url = URL(
            string: "https://storage.example.test/storage/v1/object/public/storefront-product-images/shops/\(UUID().uuidString.lowercased())/products/\(UUID().uuidString.lowercased())/public/\(imagePublicationID.uuidString.lowercased())/thumb-deadbeefdeadbeef.webp"
        )!

        let data = try await api.downloadStorefrontPublicImage(
            publicURL: url,
            imagePublicationID: imagePublicationID,
            variant: .thumb
        )
        XCTAssertEqual(data, Data("RIFF0000WEBP".utf8))
    }

    func testPublicImageDownloadRejectsCrossHostAndUnownedPathBeforeNetwork() async {
        let imagePublicationID = UUID()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StorefrontAdoptURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let api = ProductImageAPIClient(
            apiBaseURL: URL(string: "https://images.example.test")!,
            storageBaseURL: URL(string: "https://storage.example.test")!,
            apiSession: session,
            storageSession: session
        )
        let urls = [
            URL(string: "https://attacker.example/storage/v1/object/public/storefront-product-images/public/\(imagePublicationID)/thumb-deadbeefdeadbeef.webp")!,
            URL(string: "https://storage.example.test/storage/v1/object/public/storefront-product-images/public/\(UUID())/thumb-deadbeefdeadbeef.webp")!,
            URL(string: "https://storage.example.test/storage/v1/object/public/storefront-product-images/public/\(imagePublicationID)/detail-deadbeefdeadbeef.webp?token=secret")!
        ]

        for url in urls {
            do {
                _ = try await api.downloadStorefrontPublicImage(
                    publicURL: url,
                    imagePublicationID: imagePublicationID,
                    variant: .thumb
                )
                XCTFail("Untrusted public image URL must fail closed")
            } catch {
                XCTAssertEqual(error as? ProductImageError, .signedURLInvalid)
            }
        }
    }
}

@MainActor
final class StorefrontAuthoringStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var pendingDirectory: URL!
    private var pendingStorage: StorefrontPendingFileStorage!

    override func setUp() {
        super.setUp()
        suiteName = "StorefrontAuthoringStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        pendingDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(suiteName)
        pendingStorage = StorefrontPendingFileStorage(directory: pendingDirectory)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: pendingDirectory)
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testVisibleSummariesAreBatchedAndNeverExceedOneHundredIDs() async throws {
        let service = StorefrontServiceSpy()
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let productIDs = (0..<150).map { _ in UUID() }
        store.activate(scope: scope)

        for productID in productIDs {
            store.requestVisibleSummary(productID: productID, scope: scope)
        }
        try await Task.sleep(for: .milliseconds(450))

        let batches = service.summaryProductIDBatches()
        XCTAssertEqual(batches.reduce(0) { $0 + $1.count }, 150)
        XCTAssertTrue(batches.allSatisfy { !$0.isEmpty && $0.count <= 100 })
        XCTAssertEqual(Set(productIDs).filter { store.summary(for: $0) != nil }.count, 150)
    }

    func testCachedReadAndLocalDraftRemainScopedOffline() async throws {
        let productID = UUID()
        let publication = try makePublication(productID: productID, version: 4, publicName: "Server")
        let service = StorefrontServiceSpy(publication: publication)
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)

        let online = try await store.loadEditor(scope: scope, productID: productID)
        XCTAssertEqual(online.publication?.version, 4)

        var local = online.draft
        local.publicName = "Offline draft"
        try store.saveLocalDraft(
            local,
            baseDraft: online.baseDraft,
            expectedVersion: 4,
            scope: scope,
            productID: productID
        )
        service.setReadError(.offline)

        let cached = try await store.loadEditor(scope: scope, productID: productID)
        XCTAssertTrue(cached.isLocalDraft)
        XCTAssertFalse(cached.isServerVerified)
        XCTAssertEqual(cached.draft.publicName, "Offline draft")

        let otherScope = StorefrontScope(accountID: UUID(), shopID: scope.shopID)
        store.activate(scope: otherScope)
        do {
            _ = try await store.loadEditor(scope: otherScope, productID: productID)
            XCTFail("A different account must not read the first account cache")
        } catch {
            XCTAssertEqual(error as? StorefrontAuthoringError, .offline)
        }
    }

    func testReconnectDetectsServerVersionChangeBeforeLocalDraftCanMutate() async throws {
        let productID = UUID()
        let versionFour = try makePublication(productID: productID, version: 4, publicName: "Base")
        let service = StorefrontServiceSpy(publication: versionFour)
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)
        let online = try await store.loadEditor(scope: scope, productID: productID)
        var local = online.draft
        local.publicPrice = 2_000
        try store.saveLocalDraft(
            local,
            baseDraft: online.baseDraft,
            expectedVersion: 4,
            scope: scope,
            productID: productID
        )
        let versionFive = try makePublication(productID: productID, version: 5, publicName: "Changed elsewhere")
        service.setPublication(versionFive)

        let reconnected = try await store.loadEditor(scope: scope, productID: productID)
        XCTAssertEqual(reconnected.conflict?.version, 5)
        XCTAssertEqual(reconnected.baseDraft.publicName, "Base")
        XCTAssertEqual(reconnected.draft.publicPrice, 2_000)
    }

    func testAccountOrShopSwitchDropsLateSummaryCallback() async throws {
        let service = StorefrontServiceSpy(summaryDelay: .milliseconds(180))
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        let productID = UUID()
        let first = StorefrontScope(accountID: UUID(), shopID: UUID())
        let second = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: first)
        store.requestVisibleSummary(productID: productID, scope: first)
        try await Task.sleep(for: .milliseconds(90))
        store.activate(scope: second)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertNil(store.summary(for: productID))
    }

    func testMutationUsesUniqueIdempotencyKeysAndServerAckOnly() async throws {
        let productID = UUID()
        let publication = try makePublication(productID: productID, version: 1, publicName: "Public")
        let service = StorefrontServiceSpy(publication: publication)
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)
        var draft = StorefrontEditorDraft(publication: publication)
        draft.publicPrice = 2_000

        let first = try await store.mutate(
            scope: scope,
            productID: productID,
            operation: .saveDraft,
            draft: draft,
            expectedVersion: 1
        )
        let second = try await store.mutate(
            scope: scope,
            productID: productID,
            operation: .saveDraft,
            draft: draft,
            expectedVersion: first.version
        )
        let keys = service.idempotencyKeys()
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(Set(keys).count, 2)
        XCTAssertEqual(second.version, first.version + 1)
    }

    func testReconnectReplaysPendingDraftWithTheOriginalIdempotencyKey() async throws {
        let productID = UUID()
        let publication = try makePublication(productID: productID, version: 4, publicName: "Base")
        let service = StorefrontServiceSpy(publication: publication)
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)
        let online = try await store.loadEditor(scope: scope, productID: productID)
        var local = online.draft
        local.publicPrice = 2_000
        service.setMutationError(.offline)

        do {
            _ = try await store.mutate(
                scope: scope,
                productID: productID,
                operation: .saveDraft,
                draft: local,
                expectedVersion: 4,
                baseDraft: online.baseDraft
            )
            XCTFail("The first network attempt must remain pending")
        } catch {
            XCTAssertEqual(error as? StorefrontAuthoringError, .offline)
        }
        let firstKeys = service.idempotencyKeys()
        let firstKey = try XCTUnwrap(firstKeys.first)
        service.setMutationError(nil)

        let replayed = try await store.loadEditor(scope: scope, productID: productID)
        let keys = service.idempotencyKeys()
        XCTAssertEqual(keys, [firstKey, firstKey])
        XCTAssertFalse(replayed.isLocalDraft)
        XCTAssertEqual(replayed.publication?.version, 5)
        XCTAssertEqual(replayed.draft.publicPrice, 2_000)
    }

    func testOperationalDeleteFailsClosedForPublishedPublication() async throws {
        let productID = UUID()
        let publication = try makePublication(
            productID: productID,
            version: 8,
            publicName: "Public",
            status: "published"
        )
        let service = StorefrontServiceSpy(publication: publication)
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)
        let allowed = try await store.validateOperationalDeletion(scope: scope, productIDs: [productID])
        XCTAssertFalse(allowed)
    }

    func testOperationalDeleteAllowsOnlyUnpublishedHiddenOrArchived() async throws {
        let productID = UUID()
        let service = StorefrontServiceSpy()
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)

        for deniedStatus in ["draft", "scheduled", "published"] {
            service.setPublication(try makePublication(
                productID: productID,
                version: 1,
                publicName: "Public",
                status: deniedStatus
            ))
            let allowed = try await store.validateOperationalDeletion(
                scope: scope,
                productIDs: [productID]
            )
            XCTAssertFalse(allowed)
        }
        for allowedStatus in ["paused", "ended"] {
            service.setPublication(try makePublication(
                productID: productID,
                version: 2,
                publicName: "Public",
                status: allowedStatus
            ))
            let allowed = try await store.validateOperationalDeletion(
                scope: scope,
                productIDs: [productID]
            )
            XCTAssertTrue(allowed)
        }
        service.setPublication(nil)
        let allowedWithoutPublication = try await store.validateOperationalDeletion(
            scope: scope,
            productIDs: [productID]
        )
        XCTAssertTrue(allowedWithoutPublication)
    }

    func testSavedDraftIsRecoverableOfflineWithoutEditorCache() async throws {
        let service = StorefrontServiceSpy()
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let productID = UUID()
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        store.activate(scope: scope)
        var draft = StorefrontEditorDraft()
        draft.publicName = "Durable draft"
        try store.saveLocalDraft(draft, baseDraft: StorefrontEditorDraft(), expectedVersion: 0, scope: scope, productID: productID)
        service.setReadError(.offline)
        let restarted = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        restarted.activate(scope: scope)
        let recovered = try await restarted.loadEditor(scope: scope, productID: productID)
        XCTAssertEqual(recovered.draft, draft)
        XCTAssertTrue(recovered.isLocalDraft)
        XCTAssertFalse(recovered.isServerVerified)
    }

    func testAllOperationsReuseImmutableIntentAfterLostAckAndRestart() async throws {
        for operation in [StorefrontMutationOperation.saveDraft, .publish, .schedule, .hide, .archive] {
            let productID = UUID()
            let service = ReceiptStorefrontService(productID: productID)
            let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
            let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
            store.activate(scope: scope)
            var draft = StorefrontEditorDraft()
            draft.publicName = "A"
            do {
                _ = try await store.mutate(scope: scope, productID: productID, operation: operation, draft: draft, expectedVersion: 0)
                XCTFail("ACK deliberately lost")
            } catch { XCTAssertEqual(error as? StorefrontAuthoringError, .offline) }
            let restarted = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
            restarted.activate(scope: scope)
            let result = try await restarted.mutate(scope: scope, productID: productID, operation: operation, draft: draft, expectedVersion: 0)
            XCTAssertEqual(result.version, 1)
            let keys = service.keys
            XCTAssertEqual(keys.count, 2)
            XCTAssertEqual(Set(keys).count, 1, operation.rawValue)
        }
    }

    func testLostAckThenEditedPayloadReconcilesOldIntentBeforeNewMutation() async throws {
        let productID = UUID()
        let service = ReceiptStorefrontService(productID: productID)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        store.activate(scope: scope)
        var draft = StorefrontEditorDraft()
        draft.publicName = "A"
        do {
            _ = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0)
            XCTFail("ACK deliberately lost")
        } catch { XCTAssertEqual(error as? StorefrontAuthoringError, .offline) }
        draft.publicName = "B"
        let updated = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0)
        XCTAssertEqual(updated.publicName, "B")
        XCTAssertEqual(updated.version, 2)
        let keys = service.keys
        XCTAssertEqual(keys.count, 3)
        XCTAssertEqual(keys[0], keys[1])
        XCTAssertNotEqual(keys[1], keys[2])
    }

    func testDiskFailureKeepsInputAndNeverCallsRemoteMutation() async throws {
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let productID = UUID()
        let service = ReceiptStorefrontService(productID: productID)
        let failing = FailingStorefrontPendingStorage(underlying: pendingStorage)
        failing.failWrites = true
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: failing)
        store.activate(scope: scope)
        var draft = StorefrontEditorDraft()
        draft.publicName = "Unsaved input"
        XCTAssertThrowsError(try store.saveLocalDraft(draft, baseDraft: draft, expectedVersion: 0, scope: scope, productID: productID)) {
            XCTAssertEqual($0 as? StorefrontAuthoringError, .localPersistence)
        }
        do {
            _ = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0)
            XCTFail("Disk failure must precede the network")
        } catch { XCTAssertEqual(error as? StorefrontAuthoringError, .localPersistence) }
        let keys = service.keys
        XCTAssertTrue(keys.isEmpty)
        XCTAssertEqual(draft.publicName, "Unsaved input")
    }

    // A Swift task keeps isolated storage deinit off the broken task-local
    // allocation path used by synchronous XCTest on the iOS 26.2 runtime.
    func testFileStorageReportsActualFilesystemError() async throws {
        let blockingData = Data("file blocks directory".utf8)
        try blockingData.write(to: pendingDirectory)
        let storage = StorefrontPendingFileStorage(directory: pendingDirectory)
        XCTAssertThrowsError(try storage.write(Data("draft".utf8), key: "synthetic")) { error in
            let cocoaError = error as NSError
            XCTAssertEqual(cocoaError.domain, NSCocoaErrorDomain)
            XCTAssertEqual(cocoaError.code, CocoaError.fileWriteFileExists.rawValue)
        }
        XCTAssertEqual(try Data(contentsOf: pendingDirectory), blockingData)
    }

    func testDurableDraftsSurviveNewStorageAcrossProductsAccountAndShopSwitch() async throws {
        let service = StorefrontServiceSpy()
        service.setReadError(.offline)
        let first = StorefrontScope(accountID: UUID(), shopID: UUID())
        let scopes = [first, StorefrontScope(accountID: first.accountID, shopID: UUID()),
                      StorefrontScope(accountID: UUID(), shopID: first.shopID)]
        let products = [UUID(), UUID()]
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        for (scopeIndex, scope) in scopes.enumerated() {
            store.activate(scope: scope)
            for (index, product) in products.enumerated() {
                var draft = StorefrontEditorDraft()
                draft.publicName = "Draft \(scopeIndex)-\(index)"
                try store.saveLocalDraft(draft, baseDraft: StorefrontEditorDraft(), expectedVersion: 7, scope: scope, productID: product)
            }
        }
        store.activate(scope: nil)
        do { _ = try await store.loadEditor(scope: first, productID: products[0]); XCTFail("Signed out access denied") }
        catch { XCTAssertEqual(error as? StorefrontAuthoringError, .invalidScope) }
        let newStorage = StorefrontPendingFileStorage(directory: pendingDirectory)
        let restarted = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: newStorage)
        for (scopeIndex, scope) in scopes.enumerated() {
            restarted.activate(scope: scope)
            for (index, product) in products.enumerated() {
                let value = try await restarted.loadEditor(scope: scope, productID: product)
                XCTAssertEqual(value.draft.publicName, "Draft \(scopeIndex)-\(index)")
                XCTAssertEqual(value.localExpectedVersion, 7)
            }
        }
    }

    func testLegacyDraftMigrationPreservesDataUntilDurableWriteSucceeds() async throws {
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let productID = UUID()
        let key = "storefront.draft.v1.\(scope.cacheNamespace).\(productID.uuidString.lowercased())"
        var draft = StorefrontEditorDraft()
        draft.publicName = "Legacy saved draft"
        let jsonDraft = try JSONSerialization.jsonObject(with: JSONEncoder().encode(draft))
        defaults.set(try JSONSerialization.data(withJSONObject: ["draft": jsonDraft, "baseDraft": jsonDraft, "expectedVersion": 3]), forKey: key)
        let service = StorefrontServiceSpy()
        service.setReadError(.offline)
        let failing = FailingStorefrontPendingStorage(underlying: pendingStorage)
        failing.failWrites = true
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: failing)
        store.activate(scope: scope)
        do { _ = try await store.loadEditor(scope: scope, productID: productID); XCTFail("Migration write must fail") }
        catch { XCTAssertEqual(error as? StorefrontAuthoringError, .localPersistence) }
        XCTAssertNotNil(defaults.data(forKey: key))
        failing.failWrites = false
        let recovered = try await store.loadEditor(scope: scope, productID: productID)
        XCTAssertEqual(recovered.draft, draft)
        XCTAssertEqual(recovered.localExpectedVersion, 3)
        XCTAssertNil(defaults.data(forKey: key))
        XCTAssertNotNil(try pendingStorage.read(key: key))
    }

    func testLostAckOnLoadUsesReceiptBeforeVersionComparison() async throws {
        let productID = UUID()
        let service = ReceiptStorefrontService(productID: productID)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        store.activate(scope: scope)
        var draft = StorefrontEditorDraft()
        draft.publicName = "Committed A"
        do { _ = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0); XCTFail("Lost ACK") }
        catch { XCTAssertEqual(error as? StorefrontAuthoringError, .offline) }
        let reloaded = try await store.loadEditor(scope: scope, productID: productID)
        XCTAssertNil(reloaded.conflict)
        XCTAssertFalse(reloaded.isLocalDraft)
        XCTAssertEqual(reloaded.publication?.version, 1)
        XCTAssertEqual(reloaded.draft.publicName, "Committed A")
    }

    func testLostAckThenConcurrentChangePreservesEditedDraftAndReportsActualServer() async throws {
        let productID = UUID()
        let service = ReceiptStorefrontService(productID: productID)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        store.activate(scope: scope)
        var draft = StorefrontEditorDraft()
        draft.publicName = "A"
        do { _ = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0); XCTFail("Lost ACK") }
        catch { XCTAssertEqual(error as? StorefrontAuthoringError, .offline) }
        service.setPublication(try makePublication(productID: productID, version: 2, publicName: "Other platform"))
        draft.publicName = "Edited B"
        do { _ = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0); XCTFail("Concurrent update requires explicit conflict") }
        catch StorefrontAuthoringError.conflict(let server) { XCTAssertEqual(server?.publicName, "Other platform") }
        let reloaded = try await store.loadEditor(scope: scope, productID: productID)
        XCTAssertEqual(reloaded.conflict?.version, 2)
        XCTAssertEqual(reloaded.draft.publicName, "Edited B")
        let keys = service.keys
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(Set(keys).count, 1)
    }

    func testValidationRejectionThenEditUsesNewIdentity() async throws {
        let productID = UUID()
        let service = ReceiptStorefrontService(productID: productID)
        service.setPreCommitError(.server(code: "validation_failed"))
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        store.activate(scope: scope)
        var draft = StorefrontEditorDraft()
        draft.publicName = "A"
        do { _ = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0); XCTFail("Invalid request") }
        catch { XCTAssertEqual(error as? StorefrontAuthoringError, .server(code: "validation_failed")) }
        service.setPreCommitError(nil)
        service.setLoseNextAck(false)
        draft.publicName = "B"
        let updated = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0)
        XCTAssertEqual(updated.publicName, "B")
        let keys = service.keys
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(Set(keys).count, 2)
    }

    func testTimeoutBeforeCommitRetainsSameIntentAndDoesNotDuplicate() async throws {
        let productID = UUID()
        let service = ReceiptStorefrontService(productID: productID)
        service.setPreCommitError(.offline)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        store.activate(scope: scope)
        var draft = StorefrontEditorDraft()
        draft.publicName = "A"
        do { _ = try await store.mutate(scope: scope, productID: productID, operation: .publish, draft: draft, expectedVersion: 0); XCTFail("Pre-commit timeout") }
        catch { XCTAssertEqual(error as? StorefrontAuthoringError, .offline) }
        service.setPreCommitError(nil)
        service.setLoseNextAck(false)
        let updated = try await store.mutate(scope: scope, productID: productID, operation: .publish, draft: draft, expectedVersion: 0)
        XCTAssertEqual(updated.version, 1)
        let keys = service.keys
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(Set(keys).count, 1)
    }

    func testAuthorizationPrecheckCannotDiscardUnknownCommittedIntent() async throws {
        let productID = UUID()
        let service = ReceiptStorefrontService(productID: productID)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        store.activate(scope: scope)
        var draft = StorefrontEditorDraft()
        draft.publicName = "A"
        do { _ = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0); XCTFail("Lost ACK") }
        catch { XCTAssertEqual(error as? StorefrontAuthoringError, .offline) }
        service.setPreCommitError(.permissionDenied)
        draft.publicName = "B"
        do { _ = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0); XCTFail("Permission denied") }
        catch { XCTAssertEqual(error as? StorefrontAuthoringError, .permissionDenied) }
        service.setPreCommitError(nil)
        let updated = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0)
        XCTAssertEqual(updated.publicName, "B")
        XCTAssertEqual(updated.version, 2)
        let keys = service.keys
        XCTAssertEqual(keys.count, 4)
        XCTAssertEqual(Set(keys.prefix(3)).count, 1)
        XCTAssertNotEqual(keys[2], keys[3])
    }

    func testReceiptSettlementRebasesOnlySuccessorDeltaBeforeConcurrentConflict() async throws {
        let productID = UUID()
        let service = ReceiptStorefrontService(productID: productID)
        let original = try makePublication(productID: productID, version: 7, publicName: "Original", publicPrice: 1_000)
        service.setPublication(original)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        store.activate(scope: scope)
        let base = StorefrontEditorDraft(publication: original)
        var sent = base
        sent.publicName = "A acknowledged name"
        do { _ = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: sent, expectedVersion: 7, baseDraft: base); XCTFail("Lost ACK") }
        catch { XCTAssertEqual(error as? StorefrontAuthoringError, .offline) }
        let concurrent = try makePublication(productID: productID, version: 9, publicName: "C remote name", publicPrice: 1_000)
        service.setPublication(concurrent)
        var successor = sent
        successor.publicPrice = 2_000
        do { _ = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: successor, expectedVersion: 7, baseDraft: base); XCTFail("Concurrent successor needs conflict") }
        catch StorefrontAuthoringError.conflict(let server) { XCTAssertEqual(server?.version, 9) }
        XCTAssertEqual(store.reconciledBase(scope: scope, productID: productID)?.version, 8)
        let reloaded = try await store.loadEditor(scope: scope, productID: productID)
        XCTAssertEqual(reloaded.baseDraft.publicName, "A acknowledged name")
        XCTAssertEqual(reloaded.localExpectedVersion, 8)
        let dirty = storefrontChangedFields(base: reloaded.baseDraft, draft: reloaded.draft)
        XCTAssertEqual(dirty, [.publicPrice])
        let reapplied = storefrontOverlay(server: StorefrontEditorDraft(publication: concurrent), local: reloaded.draft, fields: dirty)
        XCTAssertEqual(reapplied.publicName, "C remote name")
        XCTAssertEqual(reapplied.publicPrice, 2_000)
    }

    func testIdenticalRetryAfterReceiptAndConcurrentUpdateAdoptsCurrentServerWithoutFalseConflict() async throws {
        let productID = UUID()
        let service = ReceiptStorefrontService(productID: productID)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        store.activate(scope: scope)
        var draft = StorefrontEditorDraft()
        draft.publicName = "A"
        do { _ = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0); XCTFail("Lost ACK") }
        catch { XCTAssertEqual(error as? StorefrontAuthoringError, .offline) }
        service.setPublication(try makePublication(productID: productID, version: 2, publicName: "Current C"))
        let acknowledged = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0)
        XCTAssertEqual(acknowledged.version, 2)
        XCTAssertEqual(acknowledged.publicName, "Current C")
        XCTAssertEqual(Set(service.keys).count, 1)
        let reloaded = try await store.loadEditor(scope: scope, productID: productID)
        XCTAssertFalse(reloaded.isLocalDraft)
        XCTAssertNil(reloaded.conflict)
    }

    func testReceiptExpiryRequiresCurrentVersionCheckBeforeAnyReplay() async throws {
        let productID = UUID()
        let service = ReceiptStorefrontService(productID: productID)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        store.activate(scope: scope)
        var draft = StorefrontEditorDraft()
        draft.publicName = "A"
        do { _ = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0); XCTFail("Lost ACK") }
        catch { XCTAssertEqual(error as? StorefrontAuthoringError, .offline) }
        let key = "storefront.draft.v1.\(scope.cacheNamespace).\(productID.uuidString.lowercased())"
        var journal = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(pendingStorage.read(key: key))) as? [String: Any])
        var intent = try XCTUnwrap(journal["intent"] as? [String: Any])
        intent["createdAt"] = Date().addingTimeInterval(-8 * 24 * 60 * 60).timeIntervalSinceReferenceDate
        journal["intent"] = intent
        try pendingStorage.write(JSONSerialization.data(withJSONObject: journal), key: key)
        do { _ = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0); XCTFail("Expired receipt is not safe to replay blindly") }
        catch StorefrontAuthoringError.conflict(let server) { XCTAssertEqual(server?.version, 1) }
        XCTAssertEqual(service.keys.count, 1)
        let recovered = try await store.loadEditor(scope: scope, productID: productID)
        XCTAssertEqual(recovered.draft.publicName, "A")
        XCTAssertNotNil(recovered.conflict)
    }

    func testAckCleanupDiskFailureRetainsIntentForIdempotentRecovery() async throws {
        let productID = UUID()
        let service = ReceiptStorefrontService(productID: productID)
        service.setLoseNextAck(false)
        let failing = FailingStorefrontPendingStorage(underlying: pendingStorage)
        service.afterCommit = { failing.failWrites = true }
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: failing)
        store.activate(scope: scope)
        var draft = StorefrontEditorDraft()
        draft.publicName = "A"
        do { _ = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0); XCTFail("Local cleanup disk failure") }
        catch { XCTAssertEqual(error as? StorefrontAuthoringError, .localPersistence) }
        failing.failWrites = false
        service.afterCommit = nil
        let result = try await store.mutate(scope: scope, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0)
        XCTAssertEqual(result.version, 1)
        XCTAssertEqual(service.keys.count, 2)
        XCTAssertEqual(Set(service.keys).count, 1)
    }

    func testScopeSwitchDuringMutationRejectsLateAckAndRetainsIntent() async throws {
        let productID = UUID()
        let service = ReceiptStorefrontService(productID: productID)
        service.setLoseNextAck(false)
        let started = expectation(description: "Mutation entered transport")
        service.suspendNextMutation = true
        service.onMutation = { started.fulfill() }
        let first = StorefrontScope(accountID: UUID(), shopID: UUID())
        let second = StorefrontScope(accountID: first.accountID, shopID: UUID())
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        store.activate(scope: first)
        var draft = StorefrontEditorDraft()
        draft.publicName = "A"
        let work = Task {
            do { _ = try await store.mutate(scope: first, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0); XCTFail("Late old-scope ACK") }
            catch is CancellationError { }
            catch { XCTFail("Unexpected \(error)") }
        }
        await fulfillment(of: [started], timeout: 2)
        store.activate(scope: second)
        service.resumeMutation()
        await work.value
        XCTAssertNil(store.summary(for: productID))
        store.activate(scope: first)
        service.onMutation = nil
        let recovered = try await store.mutate(scope: first, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0)
        XCTAssertEqual(recovered.version, 1)
        XCTAssertEqual(Set(service.keys).count, 1)
    }

    func testScopeSwitchDuringReceiptReadbackCannotApplyOfflineFallbackToNewScope() async throws {
        let productID = UUID()
        let service = ReceiptStorefrontService(productID: productID)
        let first = StorefrontScope(accountID: UUID(), shopID: UUID())
        let second = StorefrontScope(accountID: first.accountID, shopID: UUID())
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        store.activate(scope: first)
        var draft = StorefrontEditorDraft()
        draft.publicName = "A"
        do { _ = try await store.mutate(scope: first, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0); XCTFail("Lost ACK") }
        catch { XCTAssertEqual(error as? StorefrontAuthoringError, .offline) }
        let readStarted = expectation(description: "Receipt readback started")
        service.suspendNextRead = true
        service.onRead = { readStarted.fulfill() }
        let work = Task {
            do { _ = try await store.mutate(scope: first, productID: productID, operation: .saveDraft, draft: draft, expectedVersion: 0); XCTFail("Old-scope fallback must cancel") }
            catch is CancellationError { }
            catch { XCTFail("Unexpected \(error)") }
        }
        await fulfillment(of: [readStarted], timeout: 2)
        store.activate(scope: second)
        service.readError = .offline
        service.resumeRead()
        await work.value
        XCTAssertNil(store.summary(for: productID))
        XCTAssertTrue(store.conflictedProductIDs.isEmpty)
    }

    func testDurableSaveAndReloadMicrobenchmark() async throws {
        let service = StorefrontServiceSpy()
        service.setReadError(.offline)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let productID = UUID()
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        store.activate(scope: scope)
        var samples: [Double] = []
        for index in 0..<30 {
            var draft = StorefrontEditorDraft()
            draft.publicName = "Synthetic draft \(index)"
            let started = ContinuousClock.now
            try store.saveLocalDraft(draft, baseDraft: StorefrontEditorDraft(), expectedVersion: 7, scope: scope, productID: productID)
            let reopened = StorefrontAuthoringStore(service: service, defaults: defaults,
                pendingStorage: StorefrontPendingFileStorage(directory: pendingDirectory))
            reopened.activate(scope: scope)
            let recovered = try await reopened.loadEditor(scope: scope, productID: productID)
            let elapsed = started.duration(to: .now).components
            samples.append(Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15)
            XCTAssertEqual(recovered.draft, draft)
        }
        samples.sort()
        print("TASK144_PERF durable_save_new_storage_reload n=30 p50_ms=\(samples[14]) p95_ms=\(samples[28]) max_ms=\(samples[29]) synthetic_products=1 network=offline disk=simulator_temporary_file_storage")
    }

    func testSharedUnicodeCLPFixtureDecodesAndPersistsWithoutSemanticLoss() throws {
        struct Fixture: Decodable { struct Case: Decodable { let operation: StorefrontMutationOperation; let expectedVersion: Int64; let draft: StorefrontEditorDraft }; let cases: [Case] }
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/MOBILE-PARITY/mobile-storefront-intent-parity-v1.json")
        let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
        XCTAssertEqual(fixture.cases.count, 2)
        XCTAssertEqual(fixture.cases[0].draft.publicName, "Té 茶 — caffè")
        XCTAssertEqual(fixture.cases[0].draft.publicPrice, 12_990)
        for value in fixture.cases {
            XCTAssertEqual(value.operation, .saveDraft)
            let data = try JSONEncoder().encode(value.draft)
            XCTAssertEqual(try JSONDecoder().decode(StorefrontEditorDraft.self, from: data), value.draft)
            XCTAssertEqual(value.draft.publicPrice.map { $0 % 1 }, 0)
        }
    }

    func testEditorCacheIsBoundedWithoutEvictingPendingDrafts() async throws {
        let service = StorefrontServiceSpy()
        let store = StorefrontAuthoringStore(service: service, defaults: defaults, pendingStorage: pendingStorage)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)
        let pendingProductID = UUID()
        var pending = StorefrontEditorDraft()
        pending.publicName = "Pending"
        try store.saveLocalDraft(
            pending,
            baseDraft: StorefrontEditorDraft(),
            expectedVersion: 0,
            scope: scope,
            productID: pendingProductID
        )

        for index in 0..<(StorefrontAuthoringStore.editorCacheMaximum + 8) {
            let productID = UUID()
            service.setPublication(try makePublication(
                productID: productID,
                version: 1,
                publicName: "Product \(index)"
            ))
            _ = try await store.loadEditor(scope: scope, productID: productID)
        }

        let keys = defaults.dictionaryRepresentation().keys
        XCTAssertLessThanOrEqual(
            keys.filter { $0.hasPrefix("storefront.editor.v1.") && !$0.hasSuffix(".index") }.count,
            StorefrontAuthoringStore.editorCacheMaximum
        )
        service.setReadError(.offline)
        let recovered = try await store.loadEditor(scope: scope, productID: pendingProductID)
        XCTAssertEqual(recovered.draft.publicName, "Pending")
    }
}

@MainActor
final class StorefrontFilterGenerationTests: XCTestCase {
    func testResetStartsNewFilterWhilePreviousRequestIsSuspended() async throws {
        let firstStarted = expectation(description: "A started")
        let secondStarted = expectation(description: "B started before A finishes")
        let service = ControlledStorefrontFilterService { index in
            (index == 0 ? firstStarted : secondStarted).fulfill()
        }
        let defaults = UserDefaults(suiteName: "FilterGeneration.\(UUID())")!
        let store = StorefrontAuthoringStore(service: service, defaults: defaults)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)
        store.resetFilter(.published, query: "A", scope: scope)
        await fulfillment(of: [firstStarted], timeout: 2)
        store.resetFilter(.draft, query: "B", scope: scope)
        await fulfillment(of: [secondStarted], timeout: 2)
        service.finishAll()
        store.resetFilter(.all, query: nil, scope: scope)
        XCTAssertFalse(store.isFilterLoading)
    }
    func testSameFilterNewQueryDropsLateErrorWithoutStoppingNewLoading() async throws {
        let started = [expectation(description: "A"), expectation(description: "B")]
        let service = ControlledStorefrontFilterService { started[$0].fulfill() }
        let store = StorefrontAuthoringStore(service: service)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)
        store.resetFilter(.draft, query: "A", scope: scope)
        await fulfillment(of: [started[0]], timeout: 2)
        let oldTask = store.filterTask
        store.resetFilter(.draft, query: "B", scope: scope)
        await fulfillment(of: [started[1]], timeout: 2)
        let currentTask = store.filterTask
        service.fail(0, error: StorefrontAuthoringError.offline)
        await oldTask?.value
        XCTAssertTrue(store.isFilterLoading)
        XCTAssertNil(store.errorCode)
        let productID = UUID()
        service.finish(1, ids: [productID])
        await currentTask?.value
        XCTAssertEqual(store.filteredProductIDs, [productID])
        XCTAssertFalse(store.isFilterLoading)
    }

    func testAllImmediatelyClearsLoadingAndIgnoresLateCancellation() async throws {
        let started = expectation(description: "A")
        let service = ControlledStorefrontFilterService { _ in started.fulfill() }
        let store = StorefrontAuthoringStore(service: service)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)
        store.resetFilter(.published, query: nil, scope: scope)
        await fulfillment(of: [started], timeout: 2)
        let oldTask = store.filterTask
        store.resetFilter(.all, query: nil, scope: scope)
        XCTAssertFalse(store.isFilterLoading)
        XCTAssertFalse(store.filterHasNextPage)
        service.fail(0, error: CancellationError())
        await oldTask?.value
        XCTAssertFalse(store.isFilterLoading)
        XCTAssertNil(store.errorCode)
        XCTAssertTrue(store.filteredProductIDs.isEmpty)
    }

    func testInvertedResponsesApplyOnlyCurrentFilterRows() async throws {
        let started = [expectation(description: "A"), expectation(description: "B")]
        let service = ControlledStorefrontFilterService { started[$0].fulfill() }
        let store = StorefrontAuthoringStore(service: service)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)
        store.resetFilter(.published, query: nil, scope: scope)
        await fulfillment(of: [started[0]], timeout: 2)
        let oldTask = store.filterTask
        store.resetFilter(.draft, query: nil, scope: scope)
        await fulfillment(of: [started[1]], timeout: 2)
        let currentTask = store.filterTask
        let current = UUID()
        service.finish(1, ids: [current])
        await currentTask?.value
        service.finish(0, ids: [UUID()], totalPages: 99)
        await oldTask?.value
        XCTAssertEqual(store.filteredProductIDs, [current])
        XCTAssertFalse(store.filterHasNextPage)
        XCTAssertFalse(store.isFilterLoading)
    }

    func testNextPageDuringResetCannotPolluteNewQueryOrPagination() async throws {
        let started = (0..<3).map { expectation(description: "Request \($0)") }
        let service = ControlledStorefrontFilterService { started[$0].fulfill() }
        let store = StorefrontAuthoringStore(service: service)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)
        store.resetFilter(.draft, query: "A", scope: scope)
        await fulfillment(of: [started[0]], timeout: 2)
        let firstTask = store.filterTask
        service.finish(0, ids: [UUID()], totalPages: 2)
        await firstTask?.value
        XCTAssertTrue(store.filterHasNextPage)
        store.loadNextFilterPage(scope: scope)
        await fulfillment(of: [started[1]], timeout: 2)
        let pageTask = store.filterTask
        store.resetFilter(.draft, query: "B", scope: scope)
        await fulfillment(of: [started[2]], timeout: 2)
        let currentTask = store.filterTask
        service.finish(1, ids: [UUID()], totalPages: 4)
        await pageTask?.value
        XCTAssertTrue(store.isFilterLoading)
        XCTAssertTrue(store.filteredProductIDs.isEmpty)
        let current = UUID()
        service.finish(2, ids: [current])
        await currentTask?.value
        XCTAssertEqual(service.pages, [1, 2, 1])
        XCTAssertEqual(store.filteredProductIDs, [current])
        XCTAssertFalse(store.filterHasNextPage)
    }

    func testShopSwitchRejectsLateErrorAndRowsFromPreviousScope() async throws {
        let started = [expectation(description: "Shop A"), expectation(description: "Shop B")]
        let service = ControlledStorefrontFilterService { started[$0].fulfill() }
        let store = StorefrontAuthoringStore(service: service)
        let first = StorefrontScope(accountID: UUID(), shopID: UUID())
        let second = StorefrontScope(accountID: first.accountID, shopID: UUID())
        store.activate(scope: first)
        store.resetFilter(.draft, query: nil, scope: first)
        await fulfillment(of: [started[0]], timeout: 2)
        let oldTask = store.filterTask
        store.activate(scope: second)
        store.resetFilter(.draft, query: nil, scope: second)
        await fulfillment(of: [started[1]], timeout: 2)
        let currentTask = store.filterTask
        service.fail(0, error: StorefrontAuthoringError.permissionDenied)
        await oldTask?.value
        XCTAssertTrue(store.isFilterLoading)
        XCTAssertNil(store.errorCode)
        let current = UUID()
        service.finish(1, ids: [current])
        await currentTask?.value
        XCTAssertEqual(store.filteredProductIDs, [current])
    }

}

@MainActor
private final class ControlledStorefrontFilterService: StorefrontAuthoringServicing {
    private var requests: [(StorefrontScope, CheckedContinuation<StorefrontAuthoringSummaryResponse, any Error>?)] = []
    private(set) var pages: [Int] = []
    private let onRequest: @Sendable (Int) -> Void

    init(onRequest: @escaping @Sendable (Int) -> Void) { self.onRequest = onRequest }

    func readSummary(scope: StorefrontScope, filter: StorefrontListFilter, query: String?, productIDs: [UUID]?, page: Int) async throws -> StorefrontAuthoringSummaryResponse {
        try await withCheckedThrowingContinuation { continuation in
            pages.append(page)
            requests.append((scope, continuation))
            onRequest(requests.count - 1)
        }
    }

    func finish(_ index: Int, ids: [UUID] = [], totalPages: Int = 1) {
        let (scope, continuation) = requests[index]
        requests[index].1 = nil
        let rows = ids.map { StorefrontPublicationSummary(sourceProductId: $0, status: "draft", publicName: "Synthetic",
                    publicPrice: 1_000, storefrontCategoryId: nil, publicImageId: nil, version: 1, updatedAt: nil, differsFromOperational: false) }
        continuation?.resume(returning: StorefrontAuthoringSummaryResponse(ok: true, code: "ok", shopId: scope.shopID, rows: rows,
            pagination: StorefrontPagination(page: pages[index], total: totalPages * 100, totalPages: totalPages)))
    }

    func fail(_ index: Int, error: any Error) {
        let continuation = requests[index].1
        requests[index].1 = nil
        continuation?.resume(throwing: error)
    }

    func finishAll() {
        for index in requests.indices { finish(index) }
    }

    func read(scope: StorefrontScope, productIDs: [UUID]) async throws -> StorefrontAuthoringReadResponse { throw StorefrontAuthoringError.unavailable }
    func mutate(scope: StorefrontScope, productID: UUID, operation: StorefrontMutationOperation, draft: StorefrontEditorDraft, expectedVersion: Int64, idempotencyKey: UUID) async throws -> StorefrontAuthoringMutationResponse { throw StorefrontAuthoringError.unavailable }
}

@MainActor
private final class ReceiptStorefrontService: StorefrontAuthoringServicing {
    let productID: UUID
    var publication: StorefrontPublication?
    var suspendNextRead = false
    var onRead: (() -> Void)?
    var readError: StorefrontAuthoringError?
    private var readContinuation: CheckedContinuation<Void, Never>?
    func resumeRead() { readContinuation?.resume(); readContinuation = nil }
    var afterCommit: (() -> Void)?
    var onMutation: (() -> Void)?
    var suspendNextMutation = false
    private var mutationContinuation: CheckedContinuation<Void, Never>?
    func resumeMutation() { mutationContinuation?.resume(); mutationContinuation = nil }
    var loseNextAck = true
    var preCommitError: StorefrontAuthoringError?
    func setPreCommitError(_ value: StorefrontAuthoringError?) { preCommitError = value }
    func setLoseNextAck(_ value: Bool) { loseNextAck = value }
    func setPublication(_ value: StorefrontPublication) { publication = value }
    var keys: [UUID] = []
    private var receipts: [UUID: (StorefrontMutationOperation, StorefrontEditorDraft, Int64, StorefrontPublication)] = [:]
    init(productID: UUID) { self.productID = productID }
    func read(scope: StorefrontScope, productIDs: [UUID]) async throws -> StorefrontAuthoringReadResponse {
        if suspendNextRead {
            suspendNextRead = false
            await withCheckedContinuation { continuation in
                readContinuation = continuation
                onRead?()
            }
        }
        if let readError { throw readError }
        return StorefrontAuthoringReadResponse(ok: true, code: "ok", shopId: scope.shopID, rows: publication.map { [$0] } ?? [], categories: [], pagination: StorefrontPagination(total: publication == nil ? 0 : 1))
    }
    func readSummary(scope: StorefrontScope, filter: StorefrontListFilter, query: String?, productIDs: [UUID]?, page: Int) async throws -> StorefrontAuthoringSummaryResponse { throw StorefrontAuthoringError.unavailable }
    func mutate(scope: StorefrontScope, productID: UUID, operation: StorefrontMutationOperation, draft: StorefrontEditorDraft, expectedVersion: Int64, idempotencyKey: UUID) async throws -> StorefrontAuthoringMutationResponse {
        keys.append(idempotencyKey)
        if suspendNextMutation {
            suspendNextMutation = false
            await withCheckedContinuation { continuation in
                mutationContinuation = continuation
                onMutation?()
            }
        } else { onMutation?() }
        if let preCommitError { throw preCommitError }
        if let receipt = receipts[idempotencyKey] {
            guard receipt.0 == operation, receipt.1 == draft, receipt.2 == expectedVersion else { throw StorefrontAuthoringError.server(code: "idempotency_conflict") }
            return response(receipt.3, scope: scope, idempotent: true)
        }
        guard expectedVersion == publication?.version ?? 0 else { throw StorefrontAuthoringError.conflict(publication) }
        let updated = try makePublication(productID: productID, version: expectedVersion + 1, publicName: draft.publicName)
        publication = updated
        afterCommit?()
        receipts[idempotencyKey] = (operation, draft, expectedVersion, updated)
        if loseNextAck { loseNextAck = false; throw StorefrontAuthoringError.offline }
        return response(updated, scope: scope, idempotent: false)
    }
    private func response(_ publication: StorefrontPublication, scope: StorefrontScope, idempotent: Bool) -> StorefrontAuthoringMutationResponse {
        StorefrontAuthoringMutationResponse(ok: true, code: "ok", shopId: scope.shopID, targetId: publication.publicationId, idempotent: idempotent, payload: publication, server: nil)
    }
}

@MainActor
private final class StorefrontServiceSpy: StorefrontAuthoringServicing {
    private var publication: StorefrontPublication?
    private var readError: StorefrontAuthoringError?
    private let summaryDelay: Duration?
    private var summaryBatches: [[UUID]] = []
    private var mutationKeys: [UUID] = []
    private var mutationError: StorefrontAuthoringError?

    init(publication: StorefrontPublication? = nil, summaryDelay: Duration? = nil) {
        self.publication = publication
        self.summaryDelay = summaryDelay
    }

    func setReadError(_ error: StorefrontAuthoringError?) {
        readError = error
    }

    func setPublication(_ value: StorefrontPublication?) {
        publication = value
    }

    func setMutationError(_ value: StorefrontAuthoringError?) {
        mutationError = value
    }

    func summaryProductIDBatches() -> [[UUID]] { summaryBatches }
    func idempotencyKeys() -> [UUID] { mutationKeys }

    func read(scope: StorefrontScope, productIDs: [UUID]) async throws -> StorefrontAuthoringReadResponse {
        if let readError { throw readError }
        let rows = publication.map { productIDs.contains($0.sourceProductId) ? [$0] : [] } ?? []
        return StorefrontAuthoringReadResponse(
            ok: true,
            code: "ok",
            shopId: scope.shopID,
            rows: rows,
            categories: [],
            pagination: StorefrontPagination(total: rows.count)
        )
    }

    func readSummary(
        scope: StorefrontScope,
        filter: StorefrontListFilter,
        query: String?,
        productIDs: [UUID]?,
        page: Int
    ) async throws -> StorefrontAuthoringSummaryResponse {
        if let readError { throw readError }
        if let summaryDelay { try await Task.sleep(for: summaryDelay) }
        let ids = productIDs ?? publication.map { [$0.sourceProductId] } ?? []
        summaryBatches.append(ids)
        let rows = ids.map { id in
            StorefrontPublicationSummary(
                sourceProductId: id,
                status: publication?.sourceProductId == id ? publication!.status : "unpublished",
                publicName: publication?.sourceProductId == id ? publication!.publicName : nil,
                publicPrice: publication?.sourceProductId == id ? publication!.publicPrice : nil,
                storefrontCategoryId: publication?.sourceProductId == id ? publication!.storefrontCategoryId : nil,
                publicImageId: publication?.sourceProductId == id ? publication!.publicImageId : nil,
                version: publication?.sourceProductId == id ? publication!.version : nil,
                updatedAt: publication?.sourceProductId == id ? publication!.updatedAt : nil,
                differsFromOperational: false
            )
        }
        return StorefrontAuthoringSummaryResponse(
            ok: true,
            code: "ok",
            shopId: scope.shopID,
            rows: rows,
            pagination: StorefrontPagination(page: page, total: rows.count)
        )
    }

    func mutate(
        scope: StorefrontScope,
        productID: UUID,
        operation: StorefrontMutationOperation,
        draft: StorefrontEditorDraft,
        expectedVersion: Int64,
        idempotencyKey: UUID
    ) async throws -> StorefrontAuthoringMutationResponse {
        mutationKeys.append(idempotencyKey)
        if let mutationError { throw mutationError }
        let next = try makePublication(
            productID: productID,
            version: expectedVersion + 1,
            publicName: draft.publicName,
            status: operation == .publish ? "published" : "draft",
            publicPrice: draft.publicPrice ?? 0
        )
        publication = next
        return StorefrontAuthoringMutationResponse(
            ok: true,
            code: "ok",
            shopId: scope.shopID,
            targetId: next.publicationId,
            idempotent: false,
            payload: next,
            server: nil
        )
    }
}

nonisolated private func makePublication(
    productID: UUID,
    version: Int64,
    publicName: String,
    status: String = "draft",
    publicPrice: Int64 = 1_000
) throws -> StorefrontPublication {
    let json: [String: Any] = [
        "publicationId": UUID().uuidString.lowercased(),
        "sourceProductId": productID.uuidString.lowercased(),
        "status": status,
        "publicName": publicName,
        "publicPrice": publicPrice,
        "priceSourceMode": "override",
        "featured": false,
        "homeOrder": 0,
        "pickupEnabled": true,
        "deliveryEnabled": false,
        "reservationEnabled": false,
        "availability": "available",
        "version": version,
        "updatedAt": "2026-08-21T12:00:00Z",
        "mutationSource": "ios",
        "changedFields": ["publicName"]
    ]
    return try JSONDecoder().decode(
        StorefrontPublication.self,
        from: JSONSerialization.data(withJSONObject: json)
    )
}

private final class StorefrontAdoptURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
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

nonisolated private func requestBodyData(_ request: URLRequest) -> Data? {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var result = Data()
    var buffer = [UInt8](repeating: 0, count: 4_096)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count < 0 { return nil }
        if count == 0 { break }
        result.append(buffer, count: count)
    }
    return result
}

@MainActor
private final class FailingStorefrontPendingStorage: StorefrontPendingPersisting {
    let underlying: any StorefrontPendingPersisting
    var failWrites = false
    init(underlying: any StorefrontPendingPersisting) { self.underlying = underlying }
    func read(key: String) throws -> Data? { try underlying.read(key: key) }
    func write(_ data: Data, key: String) throws {
        if failWrites { throw CocoaError(.fileWriteOutOfSpace) }
        try underlying.write(data, key: key)
    }
    func remove(key: String) throws {
        if failWrites { throw CocoaError(.fileWriteOutOfSpace) }
        try underlying.remove(key: key)
    }
}
