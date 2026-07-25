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

    func testAutomaticLeaseRejectsCommitAfterScopeInvalidationAndIsNoopForManualWork() async throws {
        let suiteName = "Task126AccountStoreBoundaryTests.lease.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let shop = SelectedShop(
            shopID: UUID(),
            code: "TASK126",
            name: "TASK126 lease fixture",
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true
        )
        let selectedStore = SelectedShopStore(defaults: defaults)
        selectedStore.noteActiveAccount(accountHash)
        XCTAssertTrue(selectedStore.save(shop, accountHash: accountHash))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(
            accountHash: accountHash,
            storeIdentity: shop.localStoreIdentity
        ))
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: owner,
            defaults: defaults
        )

        var manualCommitCount = 0
        try Task126OwnerStoreGate.withCurrentAutomaticScopeLeaseIfPresent {
            manualCommitCount += 1
        }
        XCTAssertEqual(manualCommitCount, 1)

        var automaticCommitCount = 0
        try await Task126OwnerStoreGate.withAutomaticScope(scope) {
            try Task126OwnerStoreGate.withCurrentAutomaticScopeLeaseIfPresent {
                automaticCommitCount += 1
            }
            Task126OwnerStoreGate.invalidateAutomaticScopeLease()
            XCTAssertThrowsError(
                try Task126OwnerStoreGate.withCurrentAutomaticScopeLeaseIfPresent {
                    automaticCommitCount += 1
                }
            ) { error in
                XCTAssertEqual(error as? Task126OwnerStoreGateError, .scopeChanged)
            }
        }
        XCTAssertEqual(automaticCommitCount, 1)
    }

    func testExplicitAutomaticLeaseProtectsDetachedCommitAndRejectsStaleGeneration() async throws {
        let suiteName = "Task126AccountStoreBoundaryTests.detachedLease.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let shop = SelectedShop(
            shopID: UUID(),
            code: "TASK126-DETACHED",
            name: "TASK126 detached lease fixture",
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true
        )
        let selectedStore = SelectedShopStore(defaults: defaults)
        selectedStore.noteActiveAccount(accountHash)
        XCTAssertTrue(selectedStore.save(shop, accountHash: accountHash))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(
            accountHash: accountHash,
            storeIdentity: shop.localStoreIdentity
        ))
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: owner,
            defaults: defaults
        )

        let committed = try await Task.detached {
            try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                scope,
                defaults: defaults
            ) {
                true
            }
        }.value
        XCTAssertTrue(committed)

        Task126OwnerStoreGate.invalidateAutomaticScopeLease()
        do {
            _ = try await Task.detached {
                try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                    scope,
                    defaults: defaults
                ) {
                    true
                }
            }.value
            XCTFail("Expected stale detached scope to be rejected.")
        } catch let error as Task126OwnerStoreGateError {
            XCTAssertEqual(error, .scopeChanged)
        }
    }

    func testExplicitAutomaticLeaseSerializesConcurrentInvalidationUntilCommitFinishes() throws {
        let suiteName = "Task126AccountStoreBoundaryTests.interleavedLease.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let shop = SelectedShop(
            shopID: UUID(),
            code: "TASK126-INTERLEAVED",
            name: "TASK126 interleaved lease fixture",
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true
        )
        let selectedStore = SelectedShopStore(defaults: defaults)
        selectedStore.noteActiveAccount(accountHash)
        XCTAssertTrue(selectedStore.save(shop, accountHash: accountHash))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(
            accountHash: accountHash,
            storeIdentity: shop.localStoreIdentity
        ))
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: owner,
            defaults: defaults
        )

        let commitEntered = DispatchSemaphore(value: 0)
        let allowCommitToFinish = DispatchSemaphore(value: 0)
        let commitOperationFinished = DispatchSemaphore(value: 0)
        let commitSucceeded = DispatchSemaphore(value: 0)
        let commitFailed = DispatchSemaphore(value: 0)
        let commitThreadFinished = DispatchSemaphore(value: 0)
        let invalidationAttempted = DispatchSemaphore(value: 0)
        let invalidationFinished = DispatchSemaphore(value: 0)
        defer { allowCommitToFinish.signal() }

        let commitThread = Thread {
            defer { commitThreadFinished.signal() }
            do {
                guard let commitDefaults = UserDefaults(suiteName: suiteName) else {
                    throw Task126OwnerStoreGateError.shopContextUnavailable
                }
                try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                    scope,
                    defaults: commitDefaults
                ) {
                    commitEntered.signal()
                    guard allowCommitToFinish.wait(timeout: .now() + 5) == .success else {
                        throw Task126OwnerStoreGateError.cancelled
                    }
                    commitOperationFinished.signal()
                }
                commitSucceeded.signal()
            } catch {
                commitFailed.signal()
            }
        }
        commitThread.qualityOfService = .userInitiated
        commitThread.start()

        XCTAssertEqual(commitEntered.wait(timeout: .now() + 5), .success)

        let invalidationThread = Thread {
            invalidationAttempted.signal()
            Task126OwnerStoreGate.invalidateAutomaticScopeLease()
            invalidationFinished.signal()
        }
        invalidationThread.qualityOfService = .userInitiated
        invalidationThread.start()

        XCTAssertEqual(invalidationAttempted.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(
            invalidationFinished.wait(timeout: .now() + 0.25),
            .timedOut,
            "Invalidation must remain blocked while the commit owns the lease."
        )

        allowCommitToFinish.signal()
        XCTAssertEqual(commitOperationFinished.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(commitThreadFinished.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(commitSucceeded.wait(timeout: .now()), .success)
        XCTAssertEqual(commitFailed.wait(timeout: .now()), .timedOut)
        XCTAssertEqual(invalidationFinished.wait(timeout: .now() + 5), .success)

        XCTAssertThrowsError(
            try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                scope,
                defaults: defaults
            ) {}
        ) { error in
            XCTAssertEqual(error as? Task126OwnerStoreGateError, .scopeChanged)
        }
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
