import XCTest
@testable import iOSMerchandiseControl

final class SyncEventOutboxStateTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_778_300_000)

    func testNewValidEntryStartsPending() throws {
        let entry = try makeEntry()

        XCTAssertEqual(entry.status, .pending)
        XCTAssertEqual(entry.attemptCount, 0)
        XCTAssertEqual(entry.maxAttempts, 3)
        XCTAssertEqual(entry.nextRetryAt, now)
        XCTAssertFalse(entry.clientEventID.isEmpty)
    }

    func testOwnerUserIDIsRequired() {
        XCTAssertThrowsError(try makeEntry(ownerUserID: "   ")) { error in
            XCTAssertEqual(error as? SyncEventOutboxFactoryError, .missingOwnerUserID)
        }
    }

    func testClientEventIDIsRequiredWhenProvidedExplicitly() {
        XCTAssertThrowsError(try makeEntry(clientEventID: "   ")) { error in
            XCTAssertEqual(error as? SyncEventOutboxFactoryError, .missingClientEventID)
        }
    }

    func testClientEventIDIsStableAcrossRetry() throws {
        let clientEventID = "client-event-055"
        let entry = try makeEntry(clientEventID: clientEventID)

        let sending = SyncEventOutboxStateMachine.toSending(entry.state, now: now)
        let retry = SyncEventOutboxStateMachine.transitionAfterFailure(
            sending,
            failure: SyncEventOutboxFailure(kind: .timeout, code: "timeout", message: "request timed out"),
            now: now.addingTimeInterval(1),
            retryDelay: 30
        )
        entry.apply(retry)

        XCTAssertEqual(entry.clientEventID, clientEventID)
        XCTAssertEqual(entry.status, .failedRetryable)
    }

    func testChangedCountThousandIsAccepted() throws {
        let entry = try makeEntry(changedCount: 1_000)

        XCTAssertEqual(entry.changedCount, 1_000)
        XCTAssertEqual(entry.status, .pending)
    }

    func testChangedCountAboveThousandBlocksContract() throws {
        let entry = try makeEntry(changedCount: 1_001)

        XCTAssertEqual(entry.status, .blockedContract)
        XCTAssertEqual(entry.lastErrorKind, .contract)
        XCTAssertEqual(entry.lastErrorCode, "changed_count_limit")
    }

    func testNegativeChangedCountIsRejected() {
        XCTAssertThrowsError(try makeEntry(changedCount: -1)) { error in
            XCTAssertEqual(error as? SyncEventOutboxFactoryError, .negativeChangedCount)
        }
    }

    func testRetryableIncludesDuePendingEntryForCurrentOwner() throws {
        let entry = try makeEntry()

        XCTAssertTrue(entry.isRetryable(now: now, currentOwnerUserID: entry.ownerUserID))
    }

    func testRetryableExcludesMaxAttempts() throws {
        let entry = try makeEntry()
        entry.attemptCount = 3
        entry.maxAttempts = 3

        XCTAssertFalse(entry.isRetryable(now: now, currentOwnerUserID: entry.ownerUserID))
    }

    func testRetryableExcludesBlockedTerminalSentLocalOnlyAndSendingStatuses() throws {
        let excludedStatuses: [SyncEventOutboxStatus] = [
            .blockedContract,
            .blockedAuth,
            .blockedSchema,
            .dead,
            .sent,
            .localOnly,
            .sending
        ]

        for status in excludedStatuses {
            let entry = try makeEntry()
            entry.status = status

            XCTAssertFalse(
                entry.isRetryable(now: now, currentOwnerUserID: entry.ownerUserID),
                "Expected \(status.rawValue) to be excluded from retry queue."
            )
        }
    }

    func testNetworkTimeoutMapsToFailedRetryable() throws {
        let entry = try makeEntry()
        let next = SyncEventOutboxStateMachine.transitionAfterFailure(
            entry.state,
            failure: SyncEventOutboxFailure(kind: .timeout, code: "timeout", message: "network timeout"),
            now: now,
            retryDelay: 60
        )

        XCTAssertEqual(next.status, .failedRetryable)
        XCTAssertEqual(next.lastErrorKind, .timeout)
        XCTAssertEqual(next.nextRetryAt, now.addingTimeInterval(60))
    }

    func testNetworkAndOfflineMapToFailedRetryable() throws {
        for kind in [SyncEventOutboxErrorKind.network, .offline] {
            let entry = try makeEntry()
            let next = SyncEventOutboxStateMachine.transitionAfterFailure(
                entry.state,
                failure: SyncEventOutboxFailure(kind: kind, code: kind.rawValue, message: "transport unavailable"),
                now: now,
                retryDelay: 60
            )

            XCTAssertEqual(next.status, .failedRetryable)
            XCTAssertEqual(next.lastErrorKind, kind)
            XCTAssertEqual(next.nextRetryAt, now.addingTimeInterval(60))
        }
    }

    func testSuccessMapsToSent() throws {
        let entry = try makeEntry()
        let sending = SyncEventOutboxStateMachine.toSending(entry.state, now: now)
        let sent = SyncEventOutboxStateMachine.toSent(sending, now: now.addingTimeInterval(1))

        XCTAssertEqual(sent.status, .sent)
        XCTAssertEqual(sent.sentAt, now.addingTimeInterval(1))
        XCTAssertTrue(SyncEventOutboxStateMachine.isTerminal(sent.status))
    }

    func testAuthMapsToBlockedAuth() throws {
        let entry = try makeEntry()
        let next = SyncEventOutboxStateMachine.transitionAfterFailure(
            entry.state,
            failure: SyncEventOutboxFailure(kind: .auth, code: "401", message: "unauthorized"),
            now: now
        )

        XCTAssertEqual(next.status, .blockedAuth)
        XCTAssertTrue(SyncEventOutboxStateMachine.isTerminal(next.status))
    }

    func testSchemaMapsToBlockedSchema() throws {
        let entry = try makeEntry()
        let next = SyncEventOutboxStateMachine.transitionAfterFailure(
            entry.state,
            failure: SyncEventOutboxFailure(kind: .schema, code: "PGRST204", message: "missing function"),
            now: now
        )

        XCTAssertEqual(next.status, .blockedSchema)
    }

    func testContractMapsToBlockedContract() throws {
        let entry = try makeEntry()
        let next = SyncEventOutboxStateMachine.transitionAfterFailure(
            entry.state,
            failure: SyncEventOutboxFailure(kind: .contract, code: "PayloadValidation", message: "changed_count too high"),
            now: now
        )

        XCTAssertEqual(next.status, .blockedContract)
    }

    func testMaxAttemptsMapsRetryableFailureToDead() throws {
        let entry = try makeEntry()
        entry.attemptCount = 2
        entry.maxAttempts = 3

        let next = SyncEventOutboxStateMachine.transitionAfterFailure(
            entry.state,
            failure: SyncEventOutboxFailure(kind: .network, code: "network", message: "offline"),
            now: now
        )

        XCTAssertEqual(next.status, .dead)
        XCTAssertEqual(next.attemptCount, 3)
    }

    func testPrivacySanitizerRedactsJWTAndTokenValues() {
        let message = "Bearer abcdefghij.klmnopqrst.uvwxyzabcd token=secret123"
        let sanitized = SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage(message)

        XCTAssertNotNil(sanitized)
        XCTAssertFalse(sanitized?.contains("abcdefghij.klmnopqrst.uvwxyzabcd") ?? true)
        XCTAssertFalse(sanitized?.contains("secret123") ?? true)
        XCTAssertLessThanOrEqual(sanitized?.count ?? 0, SyncEventOutboxPrivacySanitizer.defaultMessageLimit)
    }

    func testPrivacySanitizerRedactsURLsQueryStringsAndBusinessIDs() {
        let message = """
        GET https://example.supabase.co/rest/v1/sync_events?select=*&barcode=1234567890123&product_id=00000000-0000-0000-0000-000000000001 failed
        """
        let sanitized = SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage(message)

        XCTAssertNotNil(sanitized)
        XCTAssertFalse(sanitized?.contains("https://example.supabase.co/rest/v1/sync_events?select=*") ?? true)
        XCTAssertFalse(sanitized?.contains("1234567890123") ?? true)
        XCTAssertFalse(sanitized?.contains("00000000-0000-0000-0000-000000000001") ?? true)
        XCTAssertLessThanOrEqual(sanitized?.count ?? 0, SyncEventOutboxPrivacySanitizer.defaultMessageLimit)
    }

    func testShapeHelpersDoNotPersistRawMassiveBusinessLists() throws {
        let safeShape = SyncEventOutboxPrivacySanitizer.countShape(kind: "product_ids", count: 5_000)
        XCTAssertEqual(safeShape, "product_ids:count=5000")
        XCTAssertFalse(SyncEventOutboxPrivacySanitizer.containsSuspiciousRawPayload(safeShape))

        let rawEntityIDs = """
        ["00000000-0000-0000-0000-000000000001","00000000-0000-0000-0000-000000000002"]
        """
        let rawMetadata = #"{"barcodes":["1234567890123","1234567890124"]}"#
        let entry = try makeEntry(entityIDsShape: rawEntityIDs, metadataShape: rawMetadata)

        XCTAssertEqual(entry.status, .blockedContract)
        XCTAssertEqual(entry.entityIDsShape, "redacted:entity_ids_shape")
        XCTAssertEqual(entry.metadataShape, "redacted:metadata_shape")
        XCTAssertFalse(entry.entityIDsShape.contains("00000000-0000-0000-0000-000000000001"))
        XCTAssertFalse(entry.metadataShape.contains("1234567890123"))
    }

    private func makeEntry(
        ownerUserID: String = "owner-055",
        changedCount: Int = 1,
        entityIDsShape: String = "product_ids:count=1",
        metadataShape: String = "source:manual_push",
        clientEventID: String = "client-event-default"
    ) throws -> SyncEventOutboxEntry {
        try SyncEventOutboxFactory.makeEntry(
            ownerUserID: ownerUserID,
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: changedCount,
            entityIDsShape: entityIDsShape,
            metadataShape: metadataShape,
            now: now,
            id: "entry-default",
            clientEventID: clientEventID
        )
    }
}
