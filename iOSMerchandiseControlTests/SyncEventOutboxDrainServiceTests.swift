import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class SyncEventOutboxDrainServiceTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    private let now = Date(timeIntervalSince1970: 1_778_600_000)
    private let ownerID = "00000000-0000-4000-8000-000000000060"

    func testNoWorkDoesNotCallRecorder() async throws {
        let context = try makeContext()
        let recorder = FakeDrainRecorder([])
        let service = makeService(context: context, recorder: recorder)

        let outcome = try await service.drainOnce(ownerUserID: ownerID, limit: 5)

        XCTAssertEqual(outcome.status, .noWork)
        XCTAssertEqual(outcome.attempted, 0)
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testSuccessMarksEntrySent() async throws {
        let context = try makeContext()
        let entry = try makeEntry(id: "entry-success", clientEventID: "client-success")
        try insert([entry], in: context)
        let recorder = FakeDrainRecorder([.success(try row(id: 1, clientEventID: "client-success"))])
        let service = makeService(context: context, recorder: recorder)

        let outcome = try await service.drainOnce(ownerUserID: ownerID, limit: 5)

        XCTAssertEqual(outcome.status, .drained)
        XCTAssertEqual(outcome.attempted, 1)
        XCTAssertEqual(outcome.sent, 1)
        XCTAssertEqual(entry.status, .sent)
        XCTAssertNotNil(entry.sentAt)
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 1)
        let requests = await recorder.requests()
        XCTAssertEqual(requests.first?.clientEventID, "client-success")
        XCTAssertEqual(requests.first?.entityIDs, .null)
    }

    func testDrainRecoversStaleSendingBeforeProcessing() async throws {
        let context = try makeContext()
        let entry = try makeEntry(id: "entry-stale-sending", clientEventID: "client-stale-sending")
        entry.apply(
            SyncEventOutboxStateMachine.toSending(
                entry.state,
                now: now.addingTimeInterval(-SyncEventOutboxStateMachine.defaultSendingStaleInterval - 1)
            )
        )
        try insert([entry], in: context)
        let recorder = FakeDrainRecorder([.success(try row(id: 20, clientEventID: "client-stale-sending"))])
        let service = makeService(context: context, recorder: recorder)

        let outcome = try await service.drainOnce(ownerUserID: ownerID, limit: 5)

        XCTAssertEqual(outcome.status, .drained)
        XCTAssertEqual(outcome.recoveredCount, 1)
        XCTAssertEqual(outcome.exhaustedCount, 0)
        XCTAssertEqual(outcome.skippedFreshSendingCount, 0)
        XCTAssertEqual(outcome.attempted, 1)
        XCTAssertEqual(outcome.sent, 1)
        XCTAssertEqual(entry.status, .sent)
        let requests = await recorder.requests()
        XCTAssertEqual(requests.map(\.clientEventID), ["client-stale-sending"])
    }

    func testFreshSendingIsSkippedByRecoveryAndNotProcessed() async throws {
        let context = try makeContext()
        let entry = try makeEntry(id: "entry-fresh-sending", clientEventID: "client-fresh-sending")
        entry.apply(SyncEventOutboxStateMachine.toSending(entry.state, now: now.addingTimeInterval(-60)))
        try insert([entry], in: context)
        let recorder = FakeDrainRecorder([.success(try row(id: 21, clientEventID: "client-fresh-sending"))])
        let service = makeService(context: context, recorder: recorder)

        let outcome = try await service.drainOnce(ownerUserID: ownerID, limit: 5)

        XCTAssertEqual(outcome.status, .noWork)
        XCTAssertEqual(outcome.recoveredCount, 0)
        XCTAssertEqual(outcome.exhaustedCount, 0)
        XCTAssertEqual(outcome.skippedFreshSendingCount, 1)
        XCTAssertEqual(entry.status, .sending)
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testExhaustedStaleSendingRecoveryDoesNotRetry() async throws {
        let context = try makeContext()
        let entry = try makeEntry(id: "entry-stale-exhausted", clientEventID: "client-stale-exhausted")
        entry.attemptCount = 3
        entry.maxAttempts = 3
        entry.apply(
            SyncEventOutboxStateMachine.toSending(
                entry.state,
                now: now.addingTimeInterval(-SyncEventOutboxStateMachine.defaultSendingStaleInterval - 1)
            )
        )
        try insert([entry], in: context)
        let recorder = FakeDrainRecorder([.success(try row(id: 22, clientEventID: "client-stale-exhausted"))])
        let service = makeService(context: context, recorder: recorder)

        let outcome = try await service.drainOnce(ownerUserID: ownerID, limit: 5)

        XCTAssertEqual(outcome.status, .networkFailed)
        XCTAssertEqual(outcome.recoveredCount, 0)
        XCTAssertEqual(outcome.exhaustedCount, 1)
        XCTAssertEqual(entry.status, .dead)
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testExhaustedStaleRecoveryMakesSuccessfulDrainPartial() async throws {
        let context = try makeContext()
        let exhausted = try makeEntry(id: "entry-recovery-dead", clientEventID: "client-recovery-dead")
        exhausted.attemptCount = 3
        exhausted.maxAttempts = 3
        exhausted.apply(
            SyncEventOutboxStateMachine.toSending(
                exhausted.state,
                now: now.addingTimeInterval(-SyncEventOutboxStateMachine.defaultSendingStaleInterval - 1)
            )
        )
        let pending = try makeEntry(id: "entry-after-recovery-dead", clientEventID: "client-after-recovery-dead")
        try insert([exhausted, pending], in: context)
        let recorder = FakeDrainRecorder([.success(try row(id: 23, clientEventID: "client-after-recovery-dead"))])
        let service = makeService(context: context, recorder: recorder)

        let outcome = try await service.drainOnce(ownerUserID: ownerID, limit: 5)

        XCTAssertEqual(outcome.status, .partiallyDrained)
        XCTAssertEqual(outcome.sent, 1)
        XCTAssertEqual(outcome.exhaustedCount, 1)
        XCTAssertEqual(exhausted.status, .dead)
        XCTAssertEqual(pending.status, .sent)
    }

    func testSuccessReplaysPersistedEntityIDsAndMetadata() async throws {
        let context = try makeContext()
        let productID = "11111111-1111-4111-8111-111111111111"
        let metadata = SyncEventJSONValue.object([
            "source": .string("ios_catalog_manual_push"),
            "partial": .bool(false)
        ])
        let entityIDs = SyncEventJSONValue.object([
            "product_ids": .array([.string(productID)])
        ])
        let entry = try makeEntry(
            id: "entry-payload",
            clientEventID: "client-payload",
            entityIDs: entityIDs,
            metadata: metadata
        )
        try insert([entry], in: context)
        let recorder = FakeDrainRecorder([.success(try row(id: 2, clientEventID: "client-payload"))])
        let service = makeService(context: context, recorder: recorder)

        let outcome = try await service.drainOnce(ownerUserID: ownerID, limit: 5)

        XCTAssertEqual(outcome.status, .drained)
        let requests = await recorder.requests()
        XCTAssertEqual(requests.first?.entityIDs, entityIDs)
        XCTAssertEqual(requests.first?.metadata, metadata)
        XCTAssertEqual(requests.first?.source, "ios_catalog_manual_push")
        XCTAssertEqual(entry.status, .sent)
    }

    func testLegacyPayloadBlocksWithoutRecorderCall() async throws {
        let context = try makeContext()
        let entry = try SyncEventOutboxFactory.makeEntry(
            ownerUserID: ownerID,
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 1,
            entityIDsShape: "product_ids:count=1",
            metadataShape: "source=ios_catalog_manual_push",
            now: now,
            id: "entry-legacy",
            clientEventID: "client-legacy"
        )
        try insert([entry], in: context)
        let recorder = FakeDrainRecorder([.success(try row(id: 2, clientEventID: "client-legacy"))])
        let service = makeService(context: context, recorder: recorder)

        let outcome = try await service.drainOnce(ownerUserID: ownerID, limit: 5)

        XCTAssertEqual(outcome.status, .blockedPayloadReplay)
        XCTAssertEqual(outcome.attempted, 0)
        XCTAssertEqual(outcome.blocked, 1)
        XCTAssertEqual(entry.status, .blockedContract)
        XCTAssertEqual(entry.lastErrorKind, .contract)
        XCTAssertEqual(entry.lastErrorCode, "payload_replay_missing_entity_ids")
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testCorruptPayloadBlocksWithoutRecorderCall() async throws {
        let context = try makeContext()
        let entry = try makeEntry(id: "entry-corrupt", clientEventID: "client-corrupt")
        entry.entityIDsPayloadJSON = "{not-json"
        try insert([entry], in: context)
        let recorder = FakeDrainRecorder([.success(try row(id: 3, clientEventID: "client-corrupt"))])
        let service = makeService(context: context, recorder: recorder)

        let outcome = try await service.drainOnce(ownerUserID: ownerID, limit: 5)

        XCTAssertEqual(outcome.status, .blockedPayloadReplay)
        XCTAssertEqual(outcome.attempted, 0)
        XCTAssertEqual(entry.status, .blockedContract)
        XCTAssertEqual(entry.lastErrorCode, "payload_replay_invalid_entity_ids")
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testChangedCountAboveContractBlocksBeforeRecorderCall() async throws {
        let context = try makeContext()
        let entry = SyncEventOutboxEntry(
            id: "entry-count-100001",
            ownerUserID: ownerID,
            clientEventID: "client-count-100001",
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 100_001,
            entityIDsShape: "product_ids:count=100001",
            metadataShape: "source=ios_catalog_manual_push",
            entityIDsPayloadJSON: "null",
            metadataPayloadJSON: #"{"source":"ios_catalog_manual_push"}"#,
            status: .pending,
            nextRetryAt: now,
            createdAt: now,
            updatedAt: now,
            sourceDeviceID: "device-g2"
        )
        try insert([entry], in: context)
        let recorder = FakeDrainRecorder([.success(try row(id: 4, clientEventID: "client-count-100001"))])
        let service = makeService(context: context, recorder: recorder)

        let outcome = try await service.drainOnce(ownerUserID: ownerID, limit: 5)

        XCTAssertEqual(outcome.status, .blockedPayloadReplay)
        XCTAssertEqual(outcome.attempted, 0)
        XCTAssertEqual(entry.status, .blockedContract)
        XCTAssertEqual(entry.lastErrorCode, "changed_count_limit")
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testRetryableFailureContinuesToNextEntry() async throws {
        let context = try makeContext()
        let failed = try makeEntry(id: "entry-a-fails", clientEventID: "client-a")
        let succeeds = try makeEntry(id: "entry-b-succeeds", clientEventID: "client-b")
        try insert([failed, succeeds], in: context)
        let recorder = FakeDrainRecorder([
            .failure(.network(SyncEventRecordFailure(code: "timeout", message: "network timeout"))),
            .success(try row(id: 3, clientEventID: "client-b"))
        ])
        let service = makeService(context: context, recorder: recorder)

        let outcome = try await service.drainOnce(ownerUserID: ownerID, limit: 5)

        XCTAssertEqual(outcome.status, .partiallyDrained)
        XCTAssertEqual(outcome.attempted, 2)
        XCTAssertEqual(outcome.sent, 1)
        XCTAssertEqual(outcome.retryScheduled, 1)
        XCTAssertEqual(failed.status, .failedRetryable)
        XCTAssertEqual(failed.attemptCount, 1)
        XCTAssertEqual(failed.nextRetryAt, now.addingTimeInterval(SyncEventOutboxDrainService.defaultRetryDelay))
        XCTAssertEqual(succeeds.status, .sent)
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 2)
    }

    func testExhaustedEntryDoesNotBlockLaterRetryableEntry() async throws {
        let context = try makeContext()
        let exhausted = try makeEntry(id: "entry-exhausted", clientEventID: "client-exhausted")
        exhausted.attemptCount = exhausted.maxAttempts
        let succeeds = try makeEntry(id: "entry-after-exhausted", clientEventID: "client-after-exhausted")
        try insert([exhausted, succeeds], in: context)
        let recorder = FakeDrainRecorder([.success(try row(id: 5, clientEventID: "client-after-exhausted"))])
        let service = makeService(context: context, recorder: recorder)

        let outcome = try await service.drainOnce(ownerUserID: ownerID, limit: 5)

        XCTAssertEqual(outcome.status, .drained)
        XCTAssertEqual(outcome.attempted, 1)
        XCTAssertEqual(exhausted.status, .pending)
        XCTAssertEqual(succeeds.status, .sent)
        let requests = await recorder.requests()
        XCTAssertEqual(requests.map(\.clientEventID), ["client-after-exhausted"])
    }

    func testLimitIsRespected() async throws {
        let context = try makeContext()
        let first = try makeEntry(id: "entry-1", clientEventID: "client-1")
        let second = try makeEntry(id: "entry-2", clientEventID: "client-2")
        let third = try makeEntry(id: "entry-3", clientEventID: "client-3")
        try insert([first, second, third], in: context)
        let recorder = FakeDrainRecorder([
            .success(try row(id: 4, clientEventID: "client-1")),
            .success(try row(id: 5, clientEventID: "client-2")),
            .success(try row(id: 6, clientEventID: "client-3"))
        ])
        let service = makeService(context: context, recorder: recorder)

        let outcome = try await service.drainOnce(ownerUserID: ownerID, limit: 2)

        XCTAssertEqual(outcome.status, .drained)
        XCTAssertEqual(outcome.attempted, 2)
        XCTAssertEqual(outcome.sent, 2)
        XCTAssertEqual(first.status, .sent)
        XCTAssertEqual(second.status, .sent)
        XCTAssertEqual(third.status, .pending)
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 2)
    }

    func testFetchScanLimitIsBounded() async throws {
        var capturedLimit: Int?
        let recorder = FakeDrainRecorder([])
        let service = SyncEventOutboxDrainService(
            recorder: recorder,
            clock: { self.now },
            fetchRetryable: { _, _, limit in
                capturedLimit = limit
                return []
            },
            saveChanges: {}
        )

        let outcome = try await service.drainOnce(
            ownerUserID: ownerID,
            limit: 5,
            fetchScanLimit: 10_000
        )

        XCTAssertEqual(outcome.status, .noWork)
        XCTAssertEqual(capturedLimit, SyncEventOutboxDrainService.hardFetchScanLimit)
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testSendingRecoveryScanLimitIsBounded() async throws {
        var capturedScanLimit: Int?
        let recorder = FakeDrainRecorder([])
        let service = SyncEventOutboxDrainService(
            recorder: recorder,
            sendingRecoveryScanLimit: 10_000,
            clock: { self.now },
            recoverStaleSending: { _, _, _, scanLimit in
                capturedScanLimit = scanLimit
                return SyncEventOutboxSendingRecoveryResult()
            },
            fetchRetryable: { _, _, _ in [] },
            saveChanges: {}
        )

        let outcome = try await service.drainOnce(ownerUserID: ownerID, limit: 5)

        XCTAssertEqual(outcome.status, .noWork)
        XCTAssertEqual(capturedScanLimit, SyncEventOutboxLocalStore.hardSendingRecoveryScanLimit)
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testInvalidOwnerDoesNotFetchOrCallRecorder() async throws {
        var fetchCalls = 0
        let recorder = FakeDrainRecorder([])
        let service = SyncEventOutboxDrainService(
            recorder: recorder,
            clock: { self.now },
            fetchRetryable: { _, _, _ in
                fetchCalls += 1
                return []
            },
            saveChanges: {}
        )

        do {
            _ = try await service.drainOnce(ownerUserID: "not-a-valid-owner", limit: 5)
            XCTFail("Expected invalid owner error.")
        } catch let error as SyncEventOutboxDrainError {
            XCTAssertEqual(error, .invalidOwnerUserID)
        } catch {
            XCTFail("Expected SyncEventOutboxDrainError, got \(error).")
        }

        XCTAssertEqual(fetchCalls, 0)
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testCancellationRestoresSnapshotAndRethrows() async throws {
        let context = try makeContext()
        let entry = try makeEntry(id: "entry-cancel", clientEventID: "client-cancel")
        try insert([entry], in: context)
        let recorder = FakeDrainRecorder([.cancel])
        let service = makeService(context: context, recorder: recorder)

        do {
            _ = try await service.drainOnce(ownerUserID: ownerID, limit: 1)
            XCTFail("Expected CancellationError.")
        } catch is CancellationError {
            XCTAssertEqual(entry.status, .pending)
            XCTAssertEqual(entry.attemptCount, 0)
            XCTAssertNil(entry.sentAt)
            let callCount = await recorder.callCount()
            XCTAssertEqual(callCount, 1)
        } catch {
            XCTFail("Expected CancellationError, got \(error).")
        }
    }

    func testURLErrorCancelledRestoresSnapshotAndRethrows() async throws {
        let context = try makeContext()
        let entry = try makeEntry(id: "entry-url-cancel", clientEventID: "client-url-cancel")
        try insert([entry], in: context)
        let recorder = FakeDrainRecorder([.urlCancelled])
        let service = makeService(context: context, recorder: recorder)

        do {
            _ = try await service.drainOnce(ownerUserID: ownerID, limit: 1)
            XCTFail("Expected CancellationError.")
        } catch is CancellationError {
            XCTAssertEqual(entry.status, .pending)
            XCTAssertEqual(entry.attemptCount, 0)
            XCTAssertNil(entry.sentAt)
            let callCount = await recorder.callCount()
            XCTAssertEqual(callCount, 1)
        } catch {
            XCTFail("Expected CancellationError, got \(error).")
        }
    }

    func testCancellationAfterStaleRecoveryDoesNotReturnFalseSuccess() async throws {
        let context = try makeContext()
        let entry = try makeEntry(id: "entry-recovered-cancel", clientEventID: "client-recovered-cancel")
        entry.apply(
            SyncEventOutboxStateMachine.toSending(
                entry.state,
                now: now.addingTimeInterval(-SyncEventOutboxStateMachine.defaultSendingStaleInterval - 1)
            )
        )
        try insert([entry], in: context)
        let recorder = FakeDrainRecorder([.cancel])
        let service = makeService(context: context, recorder: recorder)

        do {
            _ = try await service.drainOnce(ownerUserID: ownerID, limit: 1)
            XCTFail("Expected CancellationError.")
        } catch is CancellationError {
            XCTAssertEqual(entry.status, .failedRetryable)
            XCTAssertNil(entry.sentAt)
            let callCount = await recorder.callCount()
            XCTAssertEqual(callCount, 1)
        } catch {
            XCTFail("Expected CancellationError, got \(error).")
        }
    }

    func testCancellationBeforeDrainDoesNotRecoverFetchOrRecord() async throws {
        var recoveryCalls = 0
        var fetchCalls = 0
        var saveCalls = 0
        let recorder = FakeDrainRecorder([])
        let service = SyncEventOutboxDrainService(
            recorder: recorder,
            clock: { self.now },
            recoverStaleSending: { _, _, _, _ in
                recoveryCalls += 1
                return SyncEventOutboxSendingRecoveryResult(scannedCount: 1, recoveredCount: 1)
            },
            fetchRetryable: { _, _, _ in
                fetchCalls += 1
                return []
            },
            saveChanges: {
                saveCalls += 1
            }
        )

        let task = Task { @MainActor in
            try await service.drainOnce(ownerUserID: ownerID, limit: 5)
        }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected CancellationError.")
        } catch is CancellationError {
            XCTAssertEqual(recoveryCalls, 0)
            XCTAssertEqual(fetchCalls, 0)
            XCTAssertEqual(saveCalls, 0)
            let callCount = await recorder.callCount()
            XCTAssertEqual(callCount, 0)
        } catch {
            XCTFail("Expected CancellationError, got \(error).")
        }
    }

    func testRecoverySaveFailureStopsBeforeFetchAndRecorder() async throws {
        var fetchCalls = 0
        var saveCalls = 0
        var rollbackCalls = 0
        let recorder = FakeDrainRecorder([])
        let service = SyncEventOutboxDrainService(
            recorder: recorder,
            clock: { self.now },
            recoverStaleSending: { _, _, _, _ in
                SyncEventOutboxSendingRecoveryResult(scannedCount: 1, recoveredCount: 1)
            },
            fetchRetryable: { _, _, _ in
                fetchCalls += 1
                return []
            },
            saveChanges: {
                saveCalls += 1
                throw TestError.saveFailed
            },
            rollbackChanges: {
                rollbackCalls += 1
            }
        )

        do {
            _ = try await service.drainOnce(ownerUserID: ownerID, limit: 5)
            XCTFail("Expected local save failure.")
        } catch let error as SyncEventOutboxDrainError {
            XCTAssertEqual(error, .localSaveFailed(operation: "sending_stale_recovery"))
        } catch {
            XCTFail("Expected SyncEventOutboxDrainError, got \(error).")
        }

        XCTAssertEqual(saveCalls, 1)
        XCTAssertEqual(rollbackCalls, 1)
        XCTAssertEqual(fetchCalls, 0)
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testSecondDrainForSameOwnerIsNoOpWhileFirstIsRunning() async throws {
        let context = try makeContext()
        let entry = try makeEntry(id: "entry-reentrant", clientEventID: "client-reentrant")
        try insert([entry], in: context)
        let recorder = BlockingDrainRecorder(row: try row(id: 7, clientEventID: "client-reentrant"))
        let service = makeService(context: context, recorder: recorder)

        let first = Task { @MainActor in
            try await service.drainOnce(ownerUserID: ownerID, limit: 1)
        }
        await recorder.waitForRecordCall()

        let second = Task { @MainActor in
            try await service.drainOnce(ownerUserID: ownerID, limit: 1)
        }
        let secondOutcome = try await second.value
        await recorder.finish()
        let firstOutcome = try await first.value

        XCTAssertEqual(secondOutcome.status, .alreadyRunning)
        XCTAssertEqual(secondOutcome.attempted, 0)
        XCTAssertEqual(firstOutcome.status, .drained)
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(entry.status, .sent)
    }

    func testRemoteSuccessSaveFailureIsNotCompleteAndIdempotentRetryCanMarkSent() async throws {
        let entry = try makeEntry(id: "entry-save-failure", clientEventID: "client-save-failure")
        let snapshot = entry.state
        var firstSaveCalls = 0
        var didRollback = false
        let firstRecorder = FakeDrainRecorder([.success(try row(id: 8, clientEventID: "client-save-failure"))])
        let firstService = SyncEventOutboxDrainService(
            recorder: firstRecorder,
            clock: { self.now },
            fetchRetryable: { ownerUserID, now, _ in
                entry.isRetryable(now: now, currentOwnerUserID: ownerUserID) ? [entry] : []
            },
            saveChanges: {
                firstSaveCalls += 1
                throw TestError.saveFailed
            },
            rollbackChanges: {
                didRollback = true
                entry.apply(snapshot)
            }
        )

        do {
            _ = try await firstService.drainOnce(ownerUserID: ownerID, limit: 1)
            XCTFail("Expected local save failure.")
        } catch let error as SyncEventOutboxDrainError {
            XCTAssertEqual(error, .localSaveFailed(operation: "remote_success_to_sent"))
        } catch {
            XCTFail("Expected SyncEventOutboxDrainError, got \(error).")
        }

        XCTAssertEqual(firstSaveCalls, 1)
        XCTAssertTrue(didRollback)
        XCTAssertEqual(entry.status, .pending)
        let firstCallCount = await firstRecorder.callCount()
        XCTAssertEqual(firstCallCount, 1)

        let retryRecorder = FakeDrainRecorder([.noOp(try row(id: 8, clientEventID: "client-save-failure"))])
        let retryService = SyncEventOutboxDrainService(
            recorder: retryRecorder,
            clock: { self.now.addingTimeInterval(1) },
            fetchRetryable: { ownerUserID, now, _ in
                entry.isRetryable(now: now, currentOwnerUserID: ownerUserID) ? [entry] : []
            },
            saveChanges: {},
            rollbackChanges: {}
        )

        let retryOutcome = try await retryService.drainOnce(ownerUserID: ownerID, limit: 1)

        XCTAssertEqual(retryOutcome.status, .drained)
        XCTAssertEqual(retryOutcome.sent, 1)
        XCTAssertEqual(entry.status, .sent)
        let retryCallCount = await retryRecorder.callCount()
        XCTAssertEqual(retryCallCount, 1)
    }

    func testRecorderErrorPersistsPrivacySafeError() async throws {
        let context = try makeContext()
        let entry = try makeEntry(id: "entry-private-error", clientEventID: "client-private-error")
        try insert([entry], in: context)
        let rawUUID = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"
        let recorder = FakeDrainRecorder([
            .failure(.network(SyncEventRecordFailure(
                code: "https://example.com/rest/v1?token=secret",
                message: "Failed barcode 1234567890123 id \(rawUUID) bearer secret https://example.com/rest/v1?token=secret"
            )))
        ])
        let service = makeService(context: context, recorder: recorder)

        let outcome = try await service.drainOnce(ownerUserID: ownerID, limit: 1)

        XCTAssertEqual(outcome.status, .networkFailed)
        XCTAssertEqual(entry.status, .failedRetryable)
        XCTAssertEqual(entry.lastErrorCode, "redacted_error_code")
        XCTAssertFalse(entry.lastErrorMessageSanitized?.contains("1234567890123") ?? true)
        XCTAssertFalse(entry.lastErrorMessageSanitized?.contains(rawUUID) ?? true)
        XCTAssertFalse(entry.lastErrorMessageSanitized?.contains("secret") ?? true)
        XCTAssertFalse(entry.lastErrorMessageSanitized?.contains("https://example.com") ?? true)
    }

    func testProductionSourceKeepsDrainBoundaries() throws {
        let source = try productionSource(relativePath: "Sync/Outbox/SyncEventOutboxDrainService.swift")
        let forbiddenTokens: [String] = [
            joined("Supabase", "Client"),
            joined(".", "rpc", "("),
            joined(".", "from", "("),
            joined(".", "up", "sert", "("),
            joined(".", "channel", "("),
            joined(".", "subscribe", "("),
            joined("context", ".", "insert"),
            joined("BG", "Task"),
            "Realtime",
            "service_role",
            "URLSession",
            ["record", "sync", "event"].joined(separator: "_"),
            "OptionsView",
            "Localizable"
        ]

        for token in forbiddenTokens {
            XCTAssertFalse(source.contains(token), "Unexpected live/scope token in G2 drain source: \(token)")
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
        recorder: any SyncEventRecording
    ) -> SyncEventOutboxDrainService {
        SyncEventOutboxDrainService(
            context: context,
            recorder: recorder,
            clock: { self.now }
        )
    }

    private func insert(_ entries: [SyncEventOutboxEntry], in context: ModelContext) throws {
        let store = SyncEventOutboxLocalStore(context: context)
        entries.forEach(store.add)
        try context.save()
    }

    private func makeEntry(
        id: String,
        clientEventID: String,
        changedCount: Int = 1,
        entityIDs: SyncEventJSONValue = .null,
        metadata: SyncEventJSONValue = .object(["source": .string("ios_catalog_manual_push")])
    ) throws -> SyncEventOutboxEntry {
        let request = SyncEventRecordRequest(
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: changedCount,
            entityIDs: entityIDs,
            metadata: metadata,
            source: "ios_catalog_manual_push",
            sourceDeviceID: "device-g2",
            batchID: nil,
            clientEventID: clientEventID
        )
        let payload = try SyncEventOutboxPayloadCodec.makePayloadJSON(for: request)
        return try SyncEventOutboxFactory.makeEntry(
            ownerUserID: ownerID,
            domain: request.domain,
            eventType: request.eventType,
            changedCount: request.changedCount,
            entityIDsShape: "product_ids:count=\(changedCount)",
            metadataShape: "source=ios_catalog_manual_push",
            entityIDsPayloadJSON: payload.entityIDsPayloadJSON,
            metadataPayloadJSON: payload.metadataPayloadJSON,
            sourceDeviceID: request.sourceDeviceID,
            now: now,
            id: id,
            clientEventID: clientEventID
        )
    }

    private func row(id: Int, clientEventID: String) throws -> RemoteSyncEventRow {
        let json = """
        {
          "id": \(id),
          "owner_user_id": "\(ownerID)",
          "domain": "catalog",
          "event_type": "catalog_changed",
          "source": "ios",
          "source_device_id": "device-g2",
          "batch_id": null,
          "client_event_id": "\(clientEventID)",
          "changed_count": 1,
          "entity_ids": null,
          "created_at": "2026-05-07T12:34:56Z",
          "expires_at": null,
          "metadata": {
            "source": "fixture"
          }
        }
        """
        return try JSONDecoder().decode(RemoteSyncEventRow.self, from: Data(json.utf8))
    }

    private func productionSource(relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = testsDirectory
            .appendingPathComponent("iOSMerchandiseControl")
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func joined(_ parts: String...) -> String {
        parts.joined()
    }
}

private actor FakeDrainRecorder: SyncEventRecording {
    enum Response: Sendable {
        case success(RemoteSyncEventRow)
        case noOp(RemoteSyncEventRow)
        case failure(SyncEventRecordError)
        case cancel
        case urlCancelled
    }

    private var responses: [Response]
    private var recordedRequests: [SyncEventRecordRequest] = []

    init(_ responses: [Response]) {
        self.responses = responses
    }

    func record(_ request: SyncEventRecordRequest) async throws -> SyncEventRecordResult {
        recordedRequests.append(request)
        guard !responses.isEmpty else {
            throw SyncEventRecordError.unknown(
                SyncEventRecordFailure(code: "missing_fake_response", message: "Fake recorder response missing.")
            )
        }

        switch responses.removeFirst() {
        case .success(let row):
            return .recorded(row)
        case .noOp(let row):
            return .noOp(row)
        case .failure(let error):
            throw error
        case .cancel:
            throw CancellationError()
        case .urlCancelled:
            throw URLError(.cancelled)
        }
    }

    func callCount() -> Int {
        recordedRequests.count
    }

    func requests() -> [SyncEventRecordRequest] {
        recordedRequests
    }
}

private actor BlockingDrainRecorder: SyncEventRecording {
    private let row: RemoteSyncEventRow
    private var recordedRequests: [SyncEventRecordRequest] = []
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var continuation: CheckedContinuation<SyncEventRecordResult, Error>?

    init(row: RemoteSyncEventRow) {
        self.row = row
    }

    func record(_ request: SyncEventRecordRequest) async throws -> SyncEventRecordResult {
        recordedRequests.append(request)
        waiters.forEach { $0.resume() }
        waiters.removeAll()

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func waitForRecordCall() async {
        guard recordedRequests.isEmpty else { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func finish() {
        continuation?.resume(returning: .recorded(row))
        continuation = nil
    }

    func callCount() -> Int {
        recordedRequests.count
    }
}
