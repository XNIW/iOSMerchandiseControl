import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class Task126AccountStoreBoundaryTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private let owner = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!
    private let now = Date(timeIntervalSince1970: 1_779_000_000)

    func testLocalStoreIdentityCarriesStableAccountStoreMetadata() {
        let identity = LocalStoreIdentity(
            rawValue: "store-a",
            defaultStoreId: "default-store",
            localStoreId: "local-store-a",
            schemaVersion: 7,
            syncProtocolVersion: 126,
            storeEpoch: 3
        )

        XCTAssertEqual(identity.storeId, "store-a")
        XCTAssertEqual(identity.defaultStoreId, "default-store")
        XCTAssertEqual(identity.localStoreId, "local-store-a")
        XCTAssertEqual(identity.schemaVersion, 7)
        XCTAssertEqual(identity.syncProtocolVersion, 126)
        XCTAssertEqual(identity.storeEpoch, 3)
        XCTAssertFalse(identity.needsLegacyRepair)
    }

    func testLegacyIdentityIsDetectedForReviewRepair() {
        let legacy = LocalStoreIdentity(rawValue: "")

        XCTAssertTrue(legacy.needsLegacyRepair)
        XCTAssertEqual(Task126LegacyStoreRepairPolicy.decision(for: legacy, hasLocalData: true), .reviewRequired)
    }

    func testPendingChangePersistsOwnerStoreScopeAndBaseVersion() throws {
        let change = LocalPendingChange(
            ownerUserID: owner,
            storeId: "store-a",
            localStoreId: "local-store-a",
            syncProtocolVersion: 126,
            schemaVersion: 2,
            storeEpoch: 1,
            baseRemoteUpdatedAt: now,
            baseVersion: 42,
            baseEventId: "event-42",
            idempotencyKey: "idem-42",
            entityKind: .product,
            operation: .update,
            origin: .manualCatalogSave,
            logicalKey: "product:task126",
            changedFields: ["productName"]
        )

        XCTAssertEqual(change.ownerStoreScope.ownerHash, AccountBindingStore.accountHash(for: owner))
        XCTAssertEqual(change.ownerStoreScope.storeId, "store-a")
        XCTAssertEqual(change.localStoreId, "local-store-a")
        XCTAssertEqual(change.baseVersion, 42)
        XCTAssertEqual(change.baseEventId, "event-42")
        XCTAssertEqual(change.baseRemoteUpdatedAt, now)
        XCTAssertEqual(change.idempotencyKey, "idem-42")
    }

    func testOutboxRetryableFetchIsOwnerAndStoreScoped() throws {
        let context = try makeContext()
        let store = SyncEventOutboxLocalStore(context: context)
        let matching = try makeEntry(id: "matching", ownerUserID: "owner-a", storeId: "store-a")
        let otherStore = try makeEntry(id: "other-store", ownerUserID: "owner-a", storeId: "store-b")
        let otherOwner = try makeEntry(id: "other-owner", ownerUserID: "owner-b", storeId: "store-a")

        [matching, otherStore, otherOwner].forEach(store.add)
        try context.save()

        let retryable = try store.fetchRetryable(ownerUserID: "owner-a", storeId: "store-a", now: now)

        XCTAssertEqual(retryable.map(\.id), ["matching"])
        XCTAssertEqual(Task126OwnerStoreGate.validate(entry: otherStore, activeOwnerUserID: "owner-a", activeStoreId: "store-a"), .blocked(reason: .storeMismatch))
        XCTAssertEqual(Task126OwnerStoreGate.validate(entry: otherOwner, activeOwnerUserID: "owner-a", activeStoreId: "store-a"), .blocked(reason: .ownerMismatch))
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([SyncEventOutboxEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return ModelContext(container)
    }

    private func makeEntry(id: String, ownerUserID: String, storeId: String) throws -> SyncEventOutboxEntry {
        try SyncEventOutboxFactory.makeEntry(
            ownerUserID: ownerUserID,
            storeId: storeId,
            localStoreId: "local-\(storeId)",
            syncProtocolVersion: 126,
            schemaVersion: 2,
            storeEpoch: 1,
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 1,
            entityIDsShape: "product_ids:count=1",
            metadataShape: "source:task126",
            now: now,
            id: id,
            clientEventID: "client-\(id)"
        )
    }
}
