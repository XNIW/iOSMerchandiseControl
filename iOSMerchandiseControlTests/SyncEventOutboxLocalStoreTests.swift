import SwiftData
import XCTest
@testable import iOSMerchandiseControl

final class SyncEventOutboxLocalStoreTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private let now = Date(timeIntervalSince1970: 1_778_300_000)

    func testInsertAndFetchRetryableForOwnerDoesNotIncludeOtherOwner() throws {
        let context = try makeContext()
        let store = SyncEventOutboxLocalStore(context: context)
        let ownerA = try makeEntry(id: "owner-a-entry", ownerUserID: "owner-a")
        let ownerB = try makeEntry(id: "owner-b-entry", ownerUserID: "owner-b")

        store.add(ownerA)
        store.add(ownerB)
        try context.save()

        let retryable = try store.fetchRetryable(ownerUserID: "owner-a", now: now)

        XCTAssertEqual(retryable.map(\.id), ["owner-a-entry"])
    }

    func testOwnerMismatchIsNotDrainable() throws {
        let context = try makeContext()
        let store = SyncEventOutboxLocalStore(context: context)
        let entry = try makeEntry(id: "previous-owner-entry", ownerUserID: "previous-owner")

        store.add(entry)
        try context.save()

        XCTAssertFalse(entry.isRetryable(now: now, currentOwnerUserID: "current-owner"))
        XCTAssertTrue(try store.fetchRetryable(ownerUserID: "current-owner", now: now).isEmpty)
    }

    func testFetchRetryableExcludesNonRetryableRows() throws {
        let context = try makeContext()
        let store = SyncEventOutboxLocalStore(context: context)

        let duePending = try makeEntry(id: "due-pending")
        let dueFailure = try makeEntry(id: "due-failure")
        dueFailure.status = .failedRetryable

        let maxAttempts = try makeEntry(id: "max-attempts")
        maxAttempts.status = .failedRetryable
        maxAttempts.attemptCount = 3
        maxAttempts.maxAttempts = 3

        let futureRetry = try makeEntry(id: "future-retry", nextRetryAt: now.addingTimeInterval(60))
        futureRetry.status = .failedRetryable

        let blockedContract = try makeEntry(id: "blocked-contract")
        blockedContract.status = .blockedContract
        let blockedAuth = try makeEntry(id: "blocked-auth")
        blockedAuth.status = .blockedAuth
        let blockedSchema = try makeEntry(id: "blocked-schema")
        blockedSchema.status = .blockedSchema
        let dead = try makeEntry(id: "dead")
        dead.status = .dead
        let sent = try makeEntry(id: "sent")
        sent.status = .sent
        let localOnly = try makeEntry(id: "local-only")
        localOnly.status = .localOnly
        let sending = try makeEntry(id: "sending")
        sending.status = .sending

        [
            duePending,
            dueFailure,
            maxAttempts,
            futureRetry,
            blockedContract,
            blockedAuth,
            blockedSchema,
            dead,
            sent,
            localOnly,
            sending
        ].forEach(store.add)
        try context.save()

        let retryable = try store.fetchRetryable(ownerUserID: "owner-055", now: now)

        XCTAssertEqual(retryable.map(\.id), ["due-failure", "due-pending"])
    }

    func testFetchRetryableSortsByNextRetryCreatedAtAndID() throws {
        let context = try makeContext()
        let store = SyncEventOutboxLocalStore(context: context)

        let laterRetry = try makeEntry(
            id: "a-later-retry",
            nextRetryAt: now.addingTimeInterval(30),
            createdAt: now
        )
        let sameRetryLaterCreated = try makeEntry(
            id: "b-later-created",
            nextRetryAt: now,
            createdAt: now.addingTimeInterval(10)
        )
        let sameRetryEarlierCreatedHigherID = try makeEntry(
            id: "c-earlier-created",
            nextRetryAt: now,
            createdAt: now.addingTimeInterval(5)
        )
        let sameRetryEarlierCreatedLowerID = try makeEntry(
            id: "a-earlier-created",
            nextRetryAt: now,
            createdAt: now.addingTimeInterval(5)
        )

        [
            laterRetry,
            sameRetryLaterCreated,
            sameRetryEarlierCreatedHigherID,
            sameRetryEarlierCreatedLowerID
        ].forEach(store.add)
        try context.save()

        let retryable = try store.fetchRetryable(ownerUserID: "owner-055", now: now.addingTimeInterval(60))

        XCTAssertEqual(
            retryable.map(\.id),
            ["a-earlier-created", "c-earlier-created", "b-later-created", "a-later-retry"]
        )
    }

    func testCountsForOwnerAreCorrect() throws {
        let context = try makeContext()
        let store = SyncEventOutboxLocalStore(context: context)

        let pending = try makeEntry(id: "pending")
        let retryableFailure = try makeEntry(id: "failed-retryable")
        retryableFailure.status = .failedRetryable
        let blockedContract = try makeEntry(id: "blocked-contract")
        blockedContract.status = .blockedContract
        let blockedAuth = try makeEntry(id: "blocked-auth")
        blockedAuth.status = .blockedAuth
        let dead = try makeEntry(id: "dead")
        dead.status = .dead
        let sent = try makeEntry(id: "sent")
        sent.status = .sent
        let localOnly = try makeEntry(id: "local-only")
        localOnly.status = .localOnly
        let sending = try makeEntry(id: "sending")
        sending.status = .sending
        let otherOwner = try makeEntry(id: "other-owner", ownerUserID: "owner-b")
        otherOwner.status = .blockedSchema

        [
            pending,
            retryableFailure,
            blockedContract,
            blockedAuth,
            dead,
            sent,
            localOnly,
            sending,
            otherOwner
        ].forEach(store.add)
        try context.save()

        let counts = try store.fetchCounts(ownerUserID: "owner-055", now: now)

        XCTAssertEqual(counts.pending, 1)
        XCTAssertEqual(counts.retryable, 2)
        XCTAssertEqual(counts.blocked, 2)
        XCTAssertEqual(counts.dead, 1)
        XCTAssertEqual(counts.sent, 1)
        XCTAssertEqual(counts.localOnly, 1)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            SyncEventOutboxEntry.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return ModelContext(container)
    }

    private func makeEntry(
        id: String,
        ownerUserID: String = "owner-055",
        nextRetryAt: Date? = nil,
        createdAt: Date? = nil
    ) throws -> SyncEventOutboxEntry {
        let createdAt = createdAt ?? now
        let entry = try SyncEventOutboxFactory.makeEntry(
            ownerUserID: ownerUserID,
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 1,
            entityIDsShape: "product_ids:count=1",
            metadataShape: "source:manual_push",
            now: createdAt,
            id: id,
            clientEventID: "client-\(id)"
        )
        entry.nextRetryAt = nextRetryAt ?? createdAt
        return entry
    }
}
