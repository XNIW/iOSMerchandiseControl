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

    func testRecoverStaleSendingUnderMaxAttemptsReturnsRetryable() throws {
        let context = try makeContext()
        let store = SyncEventOutboxLocalStore(context: context)
        let entry = try makeEntry(id: "stale-sending")
        markSending(entry, startedAt: now.addingTimeInterval(-700))
        store.add(entry)
        try context.save()

        let result = try store.recoverStaleSending(
            ownerUserID: "owner-055",
            now: now,
            staleInterval: 600,
            scanLimit: 10
        )

        XCTAssertEqual(result.scannedCount, 1)
        XCTAssertEqual(result.recoveredCount, 1)
        XCTAssertEqual(result.exhaustedCount, 0)
        XCTAssertEqual(result.skippedFreshSendingCount, 0)
        XCTAssertEqual(entry.status, .failedRetryable)
        XCTAssertEqual(entry.attemptCount, 0)
        XCTAssertTrue(entry.isRetryable(now: now, currentOwnerUserID: "owner-055"))
    }

    func testRecoverStaleSendingExhaustedDoesNotReturnRetryable() throws {
        let context = try makeContext()
        let store = SyncEventOutboxLocalStore(context: context)
        let entry = try makeEntry(id: "stale-exhausted")
        entry.attemptCount = 3
        entry.maxAttempts = 3
        markSending(entry, startedAt: now.addingTimeInterval(-700))
        store.add(entry)
        try context.save()

        let result = try store.recoverStaleSending(
            ownerUserID: "owner-055",
            now: now,
            staleInterval: 600,
            scanLimit: 10
        )

        XCTAssertEqual(result.recoveredCount, 0)
        XCTAssertEqual(result.exhaustedCount, 1)
        XCTAssertEqual(entry.status, .dead)
        XCTAssertFalse(entry.isRetryable(now: now, currentOwnerUserID: "owner-055"))
    }

    func testRecoverStaleSendingSkipsFreshSending() throws {
        let context = try makeContext()
        let store = SyncEventOutboxLocalStore(context: context)
        let entry = try makeEntry(id: "fresh-sending")
        markSending(entry, startedAt: now.addingTimeInterval(-60))
        store.add(entry)
        try context.save()

        let result = try store.recoverStaleSending(
            ownerUserID: "owner-055",
            now: now,
            staleInterval: 600,
            scanLimit: 10
        )

        XCTAssertEqual(result.scannedCount, 1)
        XCTAssertEqual(result.recoveredCount, 0)
        XCTAssertEqual(result.exhaustedCount, 0)
        XCTAssertEqual(result.skippedFreshSendingCount, 1)
        XCTAssertEqual(entry.status, .sending)
    }

    func testRecoverStaleSendingDoesNotTouchPendingFailedOrSentEntries() throws {
        let context = try makeContext()
        let store = SyncEventOutboxLocalStore(context: context)
        let pending = try makeEntry(id: "pending")
        let failed = try makeEntry(id: "failed")
        failed.status = .failedRetryable
        failed.lastErrorCode = "network"
        let sent = try makeEntry(id: "sent")
        sent.status = .sent
        sent.sentAt = now
        [pending, failed, sent].forEach(store.add)
        try context.save()

        let result = try store.recoverStaleSending(
            ownerUserID: "owner-055",
            now: now,
            staleInterval: 600,
            scanLimit: 10
        )

        XCTAssertEqual(result.scannedCount, 0)
        XCTAssertEqual(pending.status, .pending)
        XCTAssertEqual(failed.status, .failedRetryable)
        XCTAssertEqual(failed.lastErrorCode, "network")
        XCTAssertEqual(sent.status, .sent)
        XCTAssertEqual(sent.sentAt, now)
    }

    func testRecoverStaleSendingIsOwnerScoped() throws {
        let context = try makeContext()
        let store = SyncEventOutboxLocalStore(context: context)
        let ownerA = try makeEntry(id: "owner-a-stale", ownerUserID: "owner-a")
        markSending(ownerA, startedAt: now.addingTimeInterval(-700))
        let ownerB = try makeEntry(id: "owner-b-stale", ownerUserID: "owner-b")
        markSending(ownerB, startedAt: now.addingTimeInterval(-700))
        [ownerA, ownerB].forEach(store.add)
        try context.save()

        let result = try store.recoverStaleSending(
            ownerUserID: "owner-a",
            now: now,
            staleInterval: 600,
            scanLimit: 10
        )

        XCTAssertEqual(result.recoveredCount, 1)
        XCTAssertEqual(ownerA.status, .failedRetryable)
        XCTAssertEqual(ownerB.status, .sending)
    }

    func testRecoverStaleSendingKeepsPayloadAndMetadataUnchanged() throws {
        let context = try makeContext()
        let store = SyncEventOutboxLocalStore(context: context)
        let entry = try makeEntry(id: "payload-stale")
        entry.entityIDsPayloadJSON = #"{"product_ids":["11111111-1111-4111-8111-111111111111"]}"#
        entry.metadataPayloadJSON = #"{"source":"ios_catalog_manual_push","partial":false}"#
        entry.entityIDsShape = "product_ids:count=1"
        entry.metadataShape = "source=ios_catalog_manual_push;partial=false"
        entry.sourceDeviceID = "device-stable"
        markSending(entry, startedAt: now.addingTimeInterval(-700))
        let entityPayloadBefore = entry.entityIDsPayloadJSON
        let metadataPayloadBefore = entry.metadataPayloadJSON
        let entityShapeBefore = entry.entityIDsShape
        let metadataShapeBefore = entry.metadataShape
        let clientEventIDBefore = entry.clientEventID
        let sourceDeviceIDBefore = entry.sourceDeviceID
        store.add(entry)
        try context.save()

        let result = try store.recoverStaleSending(
            ownerUserID: "owner-055",
            now: now,
            staleInterval: 600,
            scanLimit: 10
        )

        XCTAssertEqual(result.recoveredCount, 1)
        XCTAssertEqual(entry.entityIDsPayloadJSON, entityPayloadBefore)
        XCTAssertEqual(entry.metadataPayloadJSON, metadataPayloadBefore)
        XCTAssertEqual(entry.entityIDsShape, entityShapeBefore)
        XCTAssertEqual(entry.metadataShape, metadataShapeBefore)
        XCTAssertEqual(entry.clientEventID, clientEventIDBefore)
        XCTAssertEqual(entry.sourceDeviceID, sourceDeviceIDBefore)
        XCTAssertEqual(entry.changedCount, 1)
    }

    func testRecoverStaleSendingRespectsScanLimit() throws {
        let context = try makeContext()
        let store = SyncEventOutboxLocalStore(context: context)
        let first = try makeEntry(id: "stale-1", createdAt: now.addingTimeInterval(-900))
        let second = try makeEntry(id: "stale-2", createdAt: now.addingTimeInterval(-800))
        let third = try makeEntry(id: "stale-3", createdAt: now.addingTimeInterval(-700))
        markSending(first, startedAt: now.addingTimeInterval(-900))
        markSending(second, startedAt: now.addingTimeInterval(-800))
        markSending(third, startedAt: now.addingTimeInterval(-700))
        [first, second, third].forEach(store.add)
        try context.save()

        let result = try store.recoverStaleSending(
            ownerUserID: "owner-055",
            now: now,
            staleInterval: 600,
            scanLimit: 2
        )

        XCTAssertEqual(result.scannedCount, 2)
        XCTAssertEqual(result.recoveredCount, 2)
        XCTAssertEqual(first.status, .failedRetryable)
        XCTAssertEqual(second.status, .failedRetryable)
        XCTAssertEqual(third.status, .sending)
    }

    func testRecoverStaleSendingAppliesHardScanCap() throws {
        let context = try makeContext()
        let store = SyncEventOutboxLocalStore(context: context)
        var entries: [SyncEventOutboxEntry] = []

        for index in 0...SyncEventOutboxLocalStore.hardSendingRecoveryScanLimit {
            let entry = try makeEntry(
                id: "stale-\(index)",
                createdAt: now.addingTimeInterval(TimeInterval(-1_000 - index))
            )
            markSending(entry, startedAt: entry.createdAt)
            entries.append(entry)
        }

        entries.forEach(store.add)
        try context.save()

        let result = try store.recoverStaleSending(
            ownerUserID: "owner-055",
            now: now,
            staleInterval: 600,
            scanLimit: 10_000
        )

        XCTAssertEqual(result.scannedCount, SyncEventOutboxLocalStore.hardSendingRecoveryScanLimit)
        XCTAssertEqual(result.recoveredCount, SyncEventOutboxLocalStore.hardSendingRecoveryScanLimit)
        XCTAssertEqual(entries.filter { $0.status == .failedRetryable }.count, SyncEventOutboxLocalStore.hardSendingRecoveryScanLimit)
        XCTAssertEqual(entries.filter { $0.status == .sending }.count, 1)
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

    private func markSending(_ entry: SyncEventOutboxEntry, startedAt: Date) {
        entry.apply(SyncEventOutboxStateMachine.toSending(entry.state, now: startedAt))
    }
}
