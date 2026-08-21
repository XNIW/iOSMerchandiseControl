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

    override func setUp() {
        super.setUp()
        suiteName = "StorefrontAuthoringStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testVisibleSummariesAreBatchedAndNeverExceedOneHundredIDs() async throws {
        let service = StorefrontServiceSpy()
        let store = StorefrontAuthoringStore(service: service, defaults: defaults)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        let productIDs = (0..<150).map { _ in UUID() }
        store.activate(scope: scope)

        for productID in productIDs {
            store.requestVisibleSummary(productID: productID, scope: scope)
        }
        try await Task.sleep(for: .milliseconds(450))

        let batches = await service.summaryProductIDBatches()
        XCTAssertEqual(batches.reduce(0) { $0 + $1.count }, 150)
        XCTAssertTrue(batches.allSatisfy { !$0.isEmpty && $0.count <= 100 })
        XCTAssertEqual(Set(productIDs).filter { store.summary(for: $0) != nil }.count, 150)
    }

    func testCachedReadAndLocalDraftRemainScopedOffline() async throws {
        let productID = UUID()
        let publication = try makePublication(productID: productID, version: 4, publicName: "Server")
        let service = StorefrontServiceSpy(publication: publication)
        let store = StorefrontAuthoringStore(service: service, defaults: defaults)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)

        let online = try await store.loadEditor(scope: scope, productID: productID)
        XCTAssertEqual(online.publication?.version, 4)

        var local = online.draft
        local.publicName = "Offline draft"
        store.saveLocalDraft(
            local,
            baseDraft: online.baseDraft,
            expectedVersion: 4,
            scope: scope,
            productID: productID
        )
        await service.setReadError(.offline)

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
        let store = StorefrontAuthoringStore(service: service, defaults: defaults)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)
        let online = try await store.loadEditor(scope: scope, productID: productID)
        var local = online.draft
        local.publicPrice = 2_000
        store.saveLocalDraft(
            local,
            baseDraft: online.baseDraft,
            expectedVersion: 4,
            scope: scope,
            productID: productID
        )
        let versionFive = try makePublication(productID: productID, version: 5, publicName: "Changed elsewhere")
        await service.setPublication(versionFive)

        let reconnected = try await store.loadEditor(scope: scope, productID: productID)
        XCTAssertEqual(reconnected.conflict?.version, 5)
        XCTAssertEqual(reconnected.baseDraft.publicName, "Base")
        XCTAssertEqual(reconnected.draft.publicPrice, 2_000)
    }

    func testAccountOrShopSwitchDropsLateSummaryCallback() async throws {
        let service = StorefrontServiceSpy(summaryDelay: .milliseconds(180))
        let store = StorefrontAuthoringStore(service: service, defaults: defaults)
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
        let store = StorefrontAuthoringStore(service: service, defaults: defaults)
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
        let keys = await service.idempotencyKeys()
        XCTAssertEqual(keys.count, 2)
        XCTAssertEqual(Set(keys).count, 2)
        XCTAssertEqual(second.version, first.version + 1)
    }

    func testReconnectReplaysPendingDraftWithTheOriginalIdempotencyKey() async throws {
        let productID = UUID()
        let publication = try makePublication(productID: productID, version: 4, publicName: "Base")
        let service = StorefrontServiceSpy(publication: publication)
        let store = StorefrontAuthoringStore(service: service, defaults: defaults)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)
        let online = try await store.loadEditor(scope: scope, productID: productID)
        var local = online.draft
        local.publicPrice = 2_000
        await service.setMutationError(.offline)

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
        let firstKeys = await service.idempotencyKeys()
        let firstKey = try XCTUnwrap(firstKeys.first)
        await service.setMutationError(nil)

        let replayed = try await store.loadEditor(scope: scope, productID: productID)
        let keys = await service.idempotencyKeys()
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
        let store = StorefrontAuthoringStore(service: service, defaults: defaults)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)
        let allowed = try await store.validateOperationalDeletion(scope: scope, productIDs: [productID])
        XCTAssertFalse(allowed)
    }

    func testOperationalDeleteAllowsOnlyUnpublishedHiddenOrArchived() async throws {
        let productID = UUID()
        let service = StorefrontServiceSpy()
        let store = StorefrontAuthoringStore(service: service, defaults: defaults)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)

        for deniedStatus in ["draft", "scheduled", "published"] {
            await service.setPublication(try makePublication(
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
            await service.setPublication(try makePublication(
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
        await service.setPublication(nil)
        let allowedWithoutPublication = try await store.validateOperationalDeletion(
            scope: scope,
            productIDs: [productID]
        )
        XCTAssertTrue(allowedWithoutPublication)
    }

    func testEditorCacheIsBoundedWithoutEvictingPendingDrafts() async throws {
        let service = StorefrontServiceSpy()
        let store = StorefrontAuthoringStore(service: service, defaults: defaults)
        let scope = StorefrontScope(accountID: UUID(), shopID: UUID())
        store.activate(scope: scope)
        let pendingProductID = UUID()
        var pending = StorefrontEditorDraft()
        pending.publicName = "Pending"
        store.saveLocalDraft(
            pending,
            baseDraft: StorefrontEditorDraft(),
            expectedVersion: 0,
            scope: scope,
            productID: pendingProductID
        )

        for index in 0..<(StorefrontAuthoringStore.editorCacheMaximum + 8) {
            let productID = UUID()
            await service.setPublication(try makePublication(
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
        XCTAssertEqual(keys.filter { $0.hasPrefix("storefront.draft.v1.") }.count, 1)
    }
}

private actor StorefrontServiceSpy: StorefrontAuthoringServicing {
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
