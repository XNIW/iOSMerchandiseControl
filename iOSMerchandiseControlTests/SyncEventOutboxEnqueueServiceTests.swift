import CryptoKit
import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class SyncEventOutboxEnqueueServiceTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    private let now = Date(timeIntervalSince1970: 1_778_400_000)
    private let ownerID = "11111111-1111-1111-1111-111111111111"

    func testCatalogPushSuccessEnqueuesPendingCatalogEntry() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let supplierID1 = UUID(uuidString: "00000000-0000-4000-8000-000000000201")!
        let supplierID2 = UUID(uuidString: "00000000-0000-4000-8000-000000000202")!
        let categoryID1 = UUID(uuidString: "00000000-0000-4000-8000-000000000301")!
        let categoryID2 = UUID(uuidString: "00000000-0000-4000-8000-000000000302")!
        let productID1 = UUID(uuidString: "00000000-0000-4000-8000-000000000401")!
        let productID2 = UUID(uuidString: "00000000-0000-4000-8000-000000000402")!
        let result = service.enqueue(
            .catalogManualPush(
                result: SupabaseManualPushResult(
                    status: .completed,
                    supplierCreates: 1,
                    supplierUpdates: 1,
                    supplierLinks: 0,
                    categoryCreates: 1,
                    categoryUpdates: 0,
                    categoryLinks: 1,
                    productCreates: 1,
                    productUpdates: 1,
                    productLinks: 0,
                    touchedIDs: SupabaseManualPushTouchedIDs(
                        suppliers: [supplierID1, supplierID2],
                        categories: [categoryID1, categoryID2],
                        products: [productID1, productID2]
                    ),
                    baselineRunID: nil,
                    message: nil
                ),
                ownerUserID: UUID(uuidString: ownerID),
                currentOwnerUserID: UUID(uuidString: ownerID),
                planFingerprint: "catalog-fingerprint",
                sourceDeviceID: "device-1"
            )
        )

        let entry = try onlyEntry(in: context)
        XCTAssertEqual(result.kind, .enqueued)
        XCTAssertEqual(entry.status, .pending)
        XCTAssertEqual(entry.domain, "catalog")
        XCTAssertEqual(entry.eventType, "catalog_changed")
        XCTAssertEqual(entry.changedCount, 6)
        XCTAssertEqual(entry.entityIDsShape, "suppliers:count=2;categories:count=2;products:count=2")
        XCTAssertEqual(
            entry.entityIDsPayloadJSON,
            #"{"category_ids":["00000000-0000-4000-8000-000000000301","00000000-0000-4000-8000-000000000302"],"product_ids":["00000000-0000-4000-8000-000000000401","00000000-0000-4000-8000-000000000402"],"supplier_ids":["00000000-0000-4000-8000-000000000201","00000000-0000-4000-8000-000000000202"]}"#
        )
        XCTAssertEqual(
            entry.metadataPayloadJSON,
            #"{"baseline_refresh_failed":false,"failed_count":0,"partial":false,"skipped_count":0,"source":"ios_catalog_manual_push"}"#
        )
        XCTAssertEqual(entry.clientEventID, "catalog-manual-push:\(sha256Hex("catalog-fingerprint"))")
        XCTAssertEqual(entry.sourceDeviceID, "device-1")

        let replayRequest = try entry.makeRecordRequestForReplay()
        XCTAssertEqual(replayRequest.domain, entry.domain)
        XCTAssertEqual(replayRequest.eventType, entry.eventType)
        XCTAssertEqual(replayRequest.changedCount, entry.changedCount)
        XCTAssertEqual(
            replayRequest.entityIDs,
            .object([
                "supplier_ids": .array([.string(supplierID1.uuidString.lowercased()), .string(supplierID2.uuidString.lowercased())]),
                "category_ids": .array([.string(categoryID1.uuidString.lowercased()), .string(categoryID2.uuidString.lowercased())]),
                "product_ids": .array([.string(productID1.uuidString.lowercased()), .string(productID2.uuidString.lowercased())])
            ])
        )
        XCTAssertEqual(
            replayRequest.metadata,
            .object([
                "source": .string("ios_catalog_manual_push"),
                "partial": .bool(false),
                "baseline_refresh_failed": .bool(false),
                "skipped_count": .number(0),
                "failed_count": .number(0)
            ])
        )
        XCTAssertEqual(replayRequest.source, "ios_catalog_manual_push")
        XCTAssertEqual(replayRequest.sourceDeviceID, "device-1")
        XCTAssertNil(replayRequest.batchID)
        XCTAssertEqual(replayRequest.clientEventID, entry.clientEventID)
    }

    func testProductPricePushSuccessEnqueuesPendingPricesEntry() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let result = service.enqueue(
            .productPriceManualPush(
                result: ProductPriceManualPushResult(
                    insertedCount: 7,
                    verification: .exactMatch(verifiedCount: 7),
                    fingerprint: "prices-fingerprint"
                ),
                ownerUserID: UUID(uuidString: ownerID),
                currentOwnerUserID: UUID(uuidString: ownerID),
                sourceDeviceID: "device-2"
            )
        )

        let entry = try onlyEntry(in: context)
        XCTAssertEqual(result.kind, .enqueued)
        XCTAssertEqual(entry.status, .pending)
        XCTAssertEqual(entry.domain, "prices")
        XCTAssertEqual(entry.eventType, "prices_changed")
        XCTAssertEqual(entry.changedCount, 7)
        XCTAssertEqual(entry.entityIDsShape, "price_rows:count=7")
        XCTAssertEqual(entry.entityIDsPayloadJSON, "null")
        XCTAssertEqual(
            entry.metadataPayloadJSON,
            #"{"failed_count":0,"partial":false,"skipped_count":0,"source":"ios_prices_manual_push"}"#
        )
        XCTAssertEqual(entry.clientEventID, "prices-manual-push:\(sha256Hex("prices-fingerprint"))")
    }

    func testPlanFingerprintDerivedClientEventIDDoesNotPersistRawCatalogFields() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let rawFingerprint = """
        owner=11111111-1111-1111-1111-111111111111||barcode=1234567890123||name=Private Catalog Item
        """

        let result = service.enqueue(
            .catalogManualPush(
                result: SupabaseManualPushResult(
                    status: .completed,
                    supplierCreates: 0,
                    supplierUpdates: 0,
                    supplierLinks: 0,
                    categoryCreates: 0,
                    categoryUpdates: 0,
                    categoryLinks: 0,
                    productCreates: 1,
                    productUpdates: 0,
                    productLinks: 0,
                    baselineRunID: nil,
                    message: nil
                ),
                ownerUserID: UUID(uuidString: ownerID),
                currentOwnerUserID: UUID(uuidString: ownerID),
                planFingerprint: rawFingerprint
            )
        )

        let entry = try onlyEntry(in: context)
        XCTAssertEqual(result.kind, .enqueued)
        XCTAssertTrue(entry.clientEventID.hasPrefix("catalog-manual-push:"))
        XCTAssertFalse(entry.clientEventID.contains("11111111-1111-1111-1111-111111111111"))
        XCTAssertFalse(entry.clientEventID.contains("1234567890123"))
        XCTAssertFalse(entry.clientEventID.contains("Private Catalog Item"))
        XCTAssertEqual(entry.clientEventID, "catalog-manual-push:\(sha256Hex(rawFingerprint.trimmingCharacters(in: .whitespacesAndNewlines)))")
        XCTAssertLessThanOrEqual(entry.clientEventID.count, 160)
    }

    func testPartialSuccessCountsOnlyConfirmedRecords() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let result = service.enqueue(
            catalogOutcome(
                terminalStatus: .partial,
                suppliers: 2,
                categories: 0,
                products: 3,
                skipped: 9,
                failed: 4,
                clientEventID: "client-partial"
            )
        )

        let entry = try onlyEntry(in: context)
        XCTAssertEqual(result.kind, .enqueued)
        XCTAssertEqual(entry.changedCount, 5)
        XCTAssertTrue(entry.metadataShape.contains("partial=true"))
        XCTAssertTrue(entry.metadataShape.contains("skipped=9"))
        XCTAssertTrue(entry.metadataShape.contains("failed=4"))
    }

    func testValidEntityIDPayloadPersistsAndReplaysWithoutChangingShape() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let productID = "00000000-0000-4000-8000-000000000101"

        let result = service.enqueue(
            catalogOutcome(
                products: 1,
                clientEventID: "client-product-id-payload",
                validationEntityIDs: .object(["product_ids": .array([.string(productID)])])
            )
        )

        let entry = try onlyEntry(in: context)
        XCTAssertEqual(result.kind, .enqueued)
        XCTAssertEqual(entry.entityIDsShape, "suppliers:count=0;categories:count=0;products:count=1")
        XCTAssertEqual(entry.entityIDsPayloadJSON, #"{"product_ids":["00000000-0000-4000-8000-000000000101"]}"#)

        let replayRequest = try entry.makeRecordRequestForReplay()
        XCTAssertEqual(replayRequest.entityIDs, .object(["product_ids": .array([.string(productID)])]))
    }

    func testNoOpSkipsWithoutEntry() throws {
        let context = try makeContext()
        let service = makeService(context: context)

        let completedZero = service.enqueue(
            catalogOutcome(
                terminalStatus: .completed,
                suppliers: 0,
                categories: 0,
                products: 0,
                clientEventID: "client-zero"
            )
        )
        let explicitNoOp = service.enqueue(
            catalogOutcome(
                terminalStatus: .noOp,
                suppliers: 1,
                categories: 0,
                products: 0,
                clientEventID: "client-noop"
            )
        )

        XCTAssertEqual(completedZero.kind, .skippedNoOp)
        XCTAssertEqual(explicitNoOp.kind, .skippedNoOp)
        XCTAssertTrue(try allEntries(in: context).isEmpty)
    }

    func testDryRunAndPreflightOnlySkipWithoutEntry() throws {
        let context = try makeContext()
        let service = makeService(context: context)

        let result = service.enqueue(
            catalogOutcome(
                terminalStatus: .dryRun,
                suppliers: 1,
                categories: 0,
                products: 0,
                clientEventID: "client-dry-run"
            )
        )

        XCTAssertEqual(result.kind, .skippedDryRun)
        XCTAssertTrue(try allEntries(in: context).isEmpty)
    }

    func testFailedPreflightSkipsWithoutEntry() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let result = service.enqueue(
            catalogOutcome(
                terminalStatus: .failedPreflight,
                suppliers: 1,
                categories: 0,
                products: 0,
                clientEventID: "client-failed-preflight"
            )
        )

        XCTAssertEqual(result.kind, .skippedFailedPreflight)
        XCTAssertTrue(try allEntries(in: context).isEmpty)
    }

    func testOwnerMissingBlocksAuthWithoutEntry() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let result = service.enqueue(
            catalogOutcome(
                missingOwner: true,
                terminalStatus: .completed,
                suppliers: 1,
                categories: 0,
                products: 0,
                clientEventID: "client-missing-owner"
            )
        )

        XCTAssertEqual(result.kind, .blockedAuth)
        XCTAssertEqual(result.errorCode, "missing_owner_user_id")
        XCTAssertTrue(try allEntries(in: context).isEmpty)
    }

    func testAccountMismatchBlocksAuthWithoutEntry() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let result = service.enqueue(
            catalogOutcome(
                ownerUserID: ownerID,
                currentOwnerUserID: "22222222-2222-2222-2222-222222222222",
                terminalStatus: .completed,
                suppliers: 1,
                categories: 0,
                products: 0,
                clientEventID: "client-owner-mismatch"
            )
        )

        XCTAssertEqual(result.kind, .blockedAuth)
        XCTAssertEqual(result.errorCode, "owner_mismatch")
        XCTAssertTrue(try allEntries(in: context).isEmpty)
    }

    func testChangedCountAboveThousandCreatesBlockedContractNotPendingRetryable() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let result = service.enqueue(
            pricesOutcome(rows: 1_001, clientEventID: "client-large-prices")
        )

        let entry = try onlyEntry(in: context)
        XCTAssertEqual(result.kind, .blockedContract)
        XCTAssertEqual(entry.status, .blockedContract)
        XCTAssertEqual(entry.changedCount, 1_001)
        XCTAssertNil(entry.entityIDsPayloadJSON)
        XCTAssertNil(entry.metadataPayloadJSON)
        XCTAssertEqual(entry.lastErrorKind, .contract)
        XCTAssertFalse(entry.isRetryable(now: now, currentOwnerUserID: ownerID))
    }

    func testMetadataBudgetFailureCreatesBlockedContract() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let result = service.enqueue(
            catalogOutcome(
                suppliers: 1,
                clientEventID: "client-huge-metadata",
                validationMetadata: .object(["note": .string(String(repeating: "a", count: 4_200))])
            )
        )

        let entry = try onlyEntry(in: context)
        XCTAssertEqual(result.kind, .blockedContract)
        XCTAssertEqual(result.errorCode, "metadata_byte_budget")
        XCTAssertEqual(entry.status, .blockedContract)
        XCTAssertEqual(entry.lastErrorCode, "metadata_byte_budget")
        XCTAssertNil(entry.entityIDsPayloadJSON)
        XCTAssertNil(entry.metadataPayloadJSON)
    }

    func testEntityIDsRawBusinessIdentifiersAreNotPersistedAsPayload() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let result = service.enqueue(
            catalogOutcome(
                products: 1,
                clientEventID: "client-raw-business-id",
                validationEntityIDs: .object(["product_ids": .array([.string("1234567890123")])])
            )
        )

        let entry = try onlyEntry(in: context)
        XCTAssertEqual(result.kind, .blockedContract)
        XCTAssertEqual(entry.status, .blockedContract)
        XCTAssertEqual(result.errorCode, "entity_ids_uuid")
        XCTAssertEqual(entry.entityIDsShape, "suppliers:count=0;categories:count=0;products:count=1")
        XCTAssertNil(entry.entityIDsPayloadJSON)
        XCTAssertNil(entry.metadataPayloadJSON)
        XCTAssertFalse(entry.entityIDsShape.contains("1234567890123"))
    }

    func testReplayHelperRejectsLegacyEntryWithoutPayloadJSON() throws {
        let legacyEntry = try SyncEventOutboxFactory.makeEntry(
            ownerUserID: ownerID,
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 1,
            entityIDsShape: "product_ids:count=1",
            metadataShape: "source=ios_catalog_manual_push",
            now: now,
            id: "legacy-entry",
            clientEventID: "client-legacy"
        )

        XCTAssertThrowsError(try legacyEntry.makeRecordRequestForReplay()) { error in
            XCTAssertEqual(error as? SyncEventOutboxPayloadError, .missingPayload(.entityIDs))
        }
    }

    func testReplayHelperRejectsCorruptedPayloadJSON() throws {
        let entry = try SyncEventOutboxFactory.makeEntry(
            ownerUserID: ownerID,
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 1,
            entityIDsShape: "product_ids:count=1",
            metadataShape: "source=ios_catalog_manual_push",
            entityIDsPayloadJSON: "null",
            metadataPayloadJSON: #"{"source":"ios_catalog_manual_push""#,
            now: now,
            id: "corrupt-entry",
            clientEventID: "client-corrupt"
        )

        XCTAssertThrowsError(try entry.makeRecordRequestForReplay()) { error in
            XCTAssertEqual(error as? SyncEventOutboxPayloadError, .invalidPayloadJSON(.metadata))
        }
    }

    func testReplayHelperRejectsInvalidBatchID() throws {
        let entry = try SyncEventOutboxFactory.makeEntry(
            ownerUserID: ownerID,
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 1,
            entityIDsShape: "product_ids:count=1",
            metadataShape: "source=ios_catalog_manual_push",
            entityIDsPayloadJSON: #"{"product_ids":["00000000-0000-4000-8000-000000000101"]}"#,
            metadataPayloadJSON: #"{"source":"ios_catalog_manual_push"}"#,
            batchID: "not-a-uuid",
            now: now,
            id: "invalid-batch-entry",
            clientEventID: "client-invalid-batch"
        )

        XCTAssertThrowsError(try entry.makeRecordRequestForReplay()) { error in
            XCTAssertEqual(error as? SyncEventOutboxPayloadError, .invalidBatchID)
        }
    }

    func testForbiddenMetadataKeyBlocksWithoutPersistingPayload() throws {
        let context = try makeContext()
        let service = makeService(context: context)

        let result = service.enqueue(
            catalogOutcome(
                suppliers: 1,
                clientEventID: "client-forbidden-metadata",
                validationMetadata: .object([
                    "source": .string("ios_catalog_manual_push"),
                    "product_name": .string("sensitive-name")
                ])
            )
        )

        let entry = try onlyEntry(in: context)
        XCTAssertEqual(result.kind, .blockedContract)
        XCTAssertEqual(result.errorCode, "metadata_forbidden_key")
        XCTAssertEqual(entry.status, .blockedContract)
        XCTAssertNil(entry.entityIDsPayloadJSON)
        XCTAssertNil(entry.metadataPayloadJSON)
        XCTAssertFalse(entry.metadataShape.contains("sensitive-name"))
    }

    func testChangedCountThousandPersistsPayloadForReplay() throws {
        let context = try makeContext()
        let service = makeService(context: context)

        let result = service.enqueue(pricesOutcome(rows: 1_000, clientEventID: "client-thousand-prices"))

        let entry = try onlyEntry(in: context)
        XCTAssertEqual(result.kind, .enqueued)
        XCTAssertEqual(entry.status, .pending)
        XCTAssertEqual(entry.changedCount, 1_000)
        XCTAssertEqual(entry.entityIDsPayloadJSON, "null")
        XCTAssertNotNil(entry.metadataPayloadJSON)
        XCTAssertNoThrow(try entry.makeRecordRequestForReplay())
    }

    func testFactoryBlockedChangedCountDropsPayloadJSON() throws {
        let entry = try SyncEventOutboxFactory.makeEntry(
            ownerUserID: ownerID,
            domain: "prices",
            eventType: "prices_changed",
            changedCount: 1_001,
            entityIDsShape: "price_rows:count=1001",
            metadataShape: "source=ios_prices_manual_push",
            entityIDsPayloadJSON: "null",
            metadataPayloadJSON: #"{"source":"ios_prices_manual_push"}"#,
            now: now,
            id: "factory-blocked",
            clientEventID: "client-factory-blocked"
        )

        XCTAssertEqual(entry.status, .blockedContract)
        XCTAssertNil(entry.entityIDsPayloadJSON)
        XCTAssertNil(entry.metadataPayloadJSON)
    }

    func testSameOutcomeTwiceCreatesOneEntryThenDuplicateNoOp() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let outcome = catalogOutcome(suppliers: 1, clientEventID: "client-duplicate")

        let first = service.enqueue(outcome)
        let second = service.enqueue(outcome)

        XCTAssertEqual(first.kind, .enqueued)
        XCTAssertEqual(second.kind, .duplicateNoOp)
        XCTAssertEqual(second.entryStatus, .pending)
        XCTAssertEqual(try allEntries(in: context).count, 1)
    }

    func testSameBlockedContractOutcomeTwiceCreatesOneBlockedEntryThenDuplicateNoOp() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let outcome = pricesOutcome(rows: 1_001, clientEventID: "client-duplicate-blocked")

        let first = service.enqueue(outcome)
        let second = service.enqueue(outcome)

        XCTAssertEqual(first.kind, .blockedContract)
        XCTAssertEqual(second.kind, .duplicateNoOp)
        XCTAssertEqual(second.entryStatus, .blockedContract)
        XCTAssertEqual(try allEntries(in: context).count, 1)
    }

    func testDedupeMatchesExistingTerminalStatuses() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let outcome = catalogOutcome(suppliers: 1, clientEventID: "client-terminal-dedupe")
        _ = service.enqueue(outcome)
        let existing = try onlyEntry(in: context)

        for status in [SyncEventOutboxStatus.sent, .dead, .localOnly, .blockedSchema, .blockedAuth] {
            existing.status = status
            try context.save()

            let duplicate = service.enqueue(outcome)

            XCTAssertEqual(duplicate.kind, .duplicateNoOp)
            XCTAssertEqual(duplicate.entryStatus, status)
            XCTAssertEqual(try allEntries(in: context).count, 1)
        }
    }

    func testCompletedBaselineRefreshFailedWithConfirmedWriteEnqueuesWithMetadataFlag() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let result = service.enqueue(
            catalogOutcome(
                terminalStatus: .completedBaselineRefreshFailed,
                suppliers: 1,
                clientEventID: "client-baseline-warning"
            )
        )

        let entry = try onlyEntry(in: context)
        XCTAssertEqual(result.kind, .enqueued)
        XCTAssertEqual(entry.status, .pending)
        XCTAssertTrue(entry.metadataShape.contains("baselineRefreshFailed=true"))
    }

    func testPricesChangedCountUsesConfirmedPriceRows() throws {
        let context = try makeContext()
        let service = makeService(context: context)
        let result = service.enqueue(pricesOutcome(rows: 42, clientEventID: "client-price-count"))

        let entry = try onlyEntry(in: context)
        XCTAssertEqual(result.kind, .enqueued)
        XCTAssertEqual(entry.changedCount, 42)
        XCTAssertEqual(entry.entityIDsShape, "price_rows:count=42")
    }

    func testProductPriceZeroConfirmedRowsSkipsNoOpWithoutEntry() throws {
        let context = try makeContext()
        let service = makeService(context: context)

        let result = service.enqueue(pricesOutcome(rows: 0, clientEventID: "client-zero-prices"))

        XCTAssertEqual(result.kind, .skippedNoOp)
        XCTAssertTrue(try allEntries(in: context).isEmpty)
    }

    func testProductPriceFailedVerificationSkipsFailedPreflightWithoutEntry() throws {
        let context = try makeContext()
        let service = makeService(context: context)

        let result = service.enqueue(
            .productPriceManualPush(
                result: ProductPriceManualPushResult(
                    insertedCount: 2,
                    verification: .missingRows([
                        try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000051"))
                    ]),
                    fingerprint: "prices-missing-readback"
                ),
                ownerUserID: UUID(uuidString: ownerID),
                currentOwnerUserID: UUID(uuidString: ownerID)
            )
        )

        XCTAssertEqual(result.kind, .skippedFailedPreflight)
        XCTAssertTrue(try allEntries(in: context).isEmpty)
    }

    func testUnsupportedSourceSkipsWithoutEntry() throws {
        let context = try makeContext()
        let service = makeService(context: context)

        let result = service.enqueue(.unsupported(source: "local-apply"))

        XCTAssertEqual(result.kind, .skippedUnsupported)
        XCTAssertTrue(try allEntries(in: context).isEmpty)
    }

    func testSaveFailureAfterConfirmedOutcomeReturnsLocalFailureWithoutRetryingRemote() throws {
        var addedEntries: [SyncEventOutboxEntry] = []
        var saveCalls = 0
        let service = SyncEventOutboxEnqueueService(
            clientEventIDGenerator: { "client-save-failure" },
            entryIDGenerator: { "entry-save-failure" },
            clock: { self.now },
            fetchExistingEntry: { _, _ in nil },
            addEntry: { entry in addedEntries.append(entry) },
            saveChanges: {
                saveCalls += 1
                throw TestError.saveFailed
            }
        )

        let result = service.enqueue(catalogOutcome(suppliers: 1, clientEventID: nil))

        XCTAssertEqual(result.kind, .enqueueFailedLocal)
        XCTAssertEqual(result.errorCode, "local_save_failed")
        XCTAssertEqual(addedEntries.count, 1)
        XCTAssertEqual(saveCalls, 1)
    }

    func testInvalidGeneratedClientEventIDBlocksContractWithoutEntry() throws {
        let context = try makeContext()
        let service = makeService(
            context: context,
            clientEventIDGenerator: { "   " }
        )

        let result = service.enqueue(catalogOutcome(suppliers: 1, clientEventID: nil))

        XCTAssertEqual(result.kind, .blockedContract)
        XCTAssertEqual(result.errorCode, "missing_client_event_id")
        XCTAssertTrue(try allEntries(in: context).isEmpty)
    }

    func testGeneratorAndClockAreDeterministic() throws {
        let context = try makeContext()
        let service = makeService(
            context: context,
            clientEventIDGenerator: { "generated-client-event" },
            entryIDGenerator: { "generated-entry-id" }
        )

        let result = service.enqueue(catalogOutcome(suppliers: 1, clientEventID: nil))

        let entry = try onlyEntry(in: context)
        XCTAssertEqual(result.kind, .enqueued)
        XCTAssertEqual(entry.id, "generated-entry-id")
        XCTAssertEqual(entry.clientEventID, "generated-client-event")
        XCTAssertEqual(entry.createdAt, now)
        XCTAssertEqual(entry.updatedAt, now)
        XCTAssertEqual(entry.nextRetryAt, now)
    }

    func testProductionSourceHasNoLiveNetworkOrDrainTokens() throws {
        let source = try productionSource(named: "SyncEventOutboxEnqueueService.swift")
        let forbiddenTokens: [String] = [
            joined("Supabase", "Client"),
            joined(".", "rpc", "("),
            joined(".", "from", "("),
            joined(".", "in", "sert", "("),
            joined(".", "up", "sert", "("),
            joined(".", "up", "date", "("),
            joined(".", "de", "lete", "("),
            joined(".", "channel", "("),
            joined(".", "subscribe", "("),
            joined("BG", "Task"),
            "Realtime",
            "service_role",
            "URLSession",
            ["record", "sync", "event"].joined(separator: "_"),
            "drain",
            "worker",
            "timer"
        ]

        for token in forbiddenTokens {
            XCTAssertFalse(source.contains(token), "Unexpected live/scope token in Slice E source: \(token)")
        }
    }

    private enum TestError: Error {
        case saveFailed
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

    private func makeService(
        context: ModelContext,
        clientEventIDGenerator: @escaping () -> String = { "generated-client-event" },
        entryIDGenerator: @escaping () -> String = { "generated-entry-id" }
    ) -> SyncEventOutboxEnqueueService {
        SyncEventOutboxEnqueueService(
            context: context,
            clientEventIDGenerator: clientEventIDGenerator,
            entryIDGenerator: entryIDGenerator,
            clock: { self.now }
        )
    }

    private func sha256Hex(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func catalogOutcome(
        ownerUserID: String? = nil,
        currentOwnerUserID: String? = nil,
        missingOwner: Bool = false,
        terminalStatus: SyncEventOutboxProducerTerminalStatus = .completed,
        suppliers: Int = 0,
        categories: Int = 0,
        products: Int = 0,
        skipped: Int = 0,
        failed: Int = 0,
        clientEventID: String? = "client-catalog",
        validationEntityIDs: SyncEventJSONValue? = nil,
        validationMetadata: SyncEventJSONValue? = nil
    ) -> SyncEventOutboxProducerOutcome {
        let resolvedOwnerUserID = missingOwner ? nil : (ownerUserID ?? ownerID)
        return .catalogManualPush(
            SyncEventOutboxProducerOutcome.CatalogManualPush(
                ownerUserID: resolvedOwnerUserID,
                currentOwnerUserID: currentOwnerUserID ?? resolvedOwnerUserID ?? ownerID,
                terminalStatus: terminalStatus,
                suppliersConfirmed: suppliers,
                categoriesConfirmed: categories,
                productsConfirmed: products,
                skippedCount: skipped,
                failedCount: failed,
                clientEventID: clientEventID,
                validationEntityIDs: validationEntityIDs,
                validationMetadata: validationMetadata
            )
        )
    }

    private func pricesOutcome(
        rows: Int,
        clientEventID: String = "client-prices"
    ) -> SyncEventOutboxProducerOutcome {
        .productPriceManualPush(
            SyncEventOutboxProducerOutcome.ProductPriceManualPush(
                ownerUserID: ownerID,
                currentOwnerUserID: ownerID,
                terminalStatus: .completed,
                confirmedPriceRows: rows,
                clientEventID: clientEventID
            )
        )
    }

    private func allEntries(in context: ModelContext) throws -> [SyncEventOutboxEntry] {
        try context.fetch(
            FetchDescriptor<SyncEventOutboxEntry>(
                sortBy: [
                    SortDescriptor(\SyncEventOutboxEntry.createdAt, order: .forward),
                    SortDescriptor(\SyncEventOutboxEntry.id, order: .forward)
                ]
            )
        )
    }

    private func onlyEntry(in context: ModelContext) throws -> SyncEventOutboxEntry {
        let entries = try allEntries(in: context)
        XCTAssertEqual(entries.count, 1)
        return try XCTUnwrap(entries.first)
    }

    private func productionSource(named fileName: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = testsDirectory
            .appendingPathComponent("iOSMerchandiseControl")
            .appendingPathComponent(fileName)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func joined(_ parts: String...) -> String {
        parts.joined()
    }
}
