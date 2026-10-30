import XCTest
import CryptoKit
@testable import iOSMerchandiseControl

final class RecoveryReconciliationPersistenceTests: XCTestCase {
    @MainActor
    func testInterruptedV2KeepsOriginalBytesAndOneConservativeDeadlineAcrossReopen() throws {
        let fixture = try makeFixture()
        let started = Date(timeIntervalSince1970: 10_000)
        let original = try oldV2(identity: fixture.identity, at: started)
        fixture.defaults.set(original, forKey: fixture.key)
        let observed = started.addingTimeInterval(30)
        let store = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
        XCTAssertEqual(store.recoveryReconciliationOpportunity(identity: fixture.identity, now: observed), .cooldown(300))
        let preparedBytes = try XCTUnwrap(fixture.defaults.data(forKey: fixture.key))
        let prepared = try object(preparedBytes)
        XCTAssertEqual(prepared["totalAttempts"] as? Int, 1, "Local reconciliation consumes no cloud attempt")
        let lifecycle = try XCTUnwrap(prepared["lifecycle"] as? [String: Any])
        XCTAssertEqual(Data(base64Encoded: try XCTUnwrap(lifecycle["originPayload"] as? String)), original)
        XCTAssertEqual(lifecycle["originSHA256"] as? String, digest(original))
        let reopened = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
        XCTAssertEqual(reopened.recoveryReconciliationOpportunity(identity: fixture.identity,
            now: observed.addingTimeInterval(299)), .cooldown(1))
        XCTAssertEqual(fixture.defaults.data(forKey: fixture.key), preparedBytes, "Reopen must not move the first deadline")
        guard case .ready(let descriptor) = reopened.recoveryReconciliationOpportunity(identity: fixture.identity,
            now: observed.addingTimeInterval(300)) else { return XCTFail("The first due opportunity must be available") }
        let claim = try XCTUnwrap(reopened.claimAutomaticRecoveryAttempt(identity: fixture.identity,
            now: observed.addingTimeInterval(300), reconciliation: descriptor))
        XCTAssertEqual(try object(XCTUnwrap(fixture.defaults.data(forKey: fixture.key)))["totalAttempts"] as? Int, 2)
        XCTAssertEqual(reopened.recoveryReconciliationOpportunity(identity: fixture.identity,
            now: observed.addingTimeInterval(900)), .blocked, "A live invocation cannot acquire a second writer")
        reopened.releaseAutomaticRecoveryAttempt(claim, now: observed.addingTimeInterval(301))
    }

    @MainActor
    func testInterruptedClaimNeverAnticipatesRecordedRetryAfterAndRejectsStaleDescriptor() throws {
        let fixture = try makeFixture()
        let start = Date(timeIntervalSince1970: 20_000)
        fixture.defaults.set(try oldV2(identity: fixture.identity, at: start, retryAfter: start.addingTimeInterval(900)),
            forKey: fixture.key)
        let store = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
        XCTAssertEqual(store.recoveryReconciliationOpportunity(identity: fixture.identity, now: start), .cooldown(900))
        guard case .ready(let descriptor) = store.recoveryReconciliationOpportunity(identity: fixture.identity,
            now: start.addingTimeInterval(900)) else { return XCTFail("Expected due phase reconciliation") }
        _ = store.extendAutomaticRecoveryAttemptCooldown(identity: fixture.identity,
            requestedDelay: 120, now: start.addingTimeInterval(900))
        let held = fixture.defaults.data(forKey: fixture.key)
        XCTAssertNil(store.claimAutomaticRecoveryAttempt(identity: fixture.identity,
            now: start.addingTimeInterval(1_020), reconciliation: descriptor))
        XCTAssertEqual(fixture.defaults.data(forKey: fixture.key), held, "Stale metadata token cannot claim or reset a deadline")
    }

    @MainActor
    func testWallClockRollbackNeverAnticipatesOrRewritesThePersistedDeadline() throws {
        let fixture = try makeFixture()
        let start = Date(timeIntervalSince1970: 25_000)
        fixture.defaults.set(try oldV2(identity: fixture.identity, at: start), forKey: fixture.key)
        let store = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
        XCTAssertEqual(store.recoveryReconciliationOpportunity(identity: fixture.identity, now: start), .cooldown(300))
        let prepared = fixture.defaults.data(forKey: fixture.key)
        XCTAssertEqual(store.recoveryReconciliationOpportunity(identity: fixture.identity,
            now: start.addingTimeInterval(-1)), .blocked)
        XCTAssertEqual(store.recoveryReconciliationBlockReason, "clock_precedes_recorded_attempt")
        XCTAssertEqual(fixture.defaults.data(forKey: fixture.key), prepared)
        let reopened = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
        XCTAssertEqual(reopened.recoveryReconciliationOpportunity(identity: fixture.identity,
            now: start.addingTimeInterval(1)), .cooldown(299))
        XCTAssertEqual(fixture.defaults.data(forKey: fixture.key), prepared)
    }

    @MainActor
    func testCurrentProcessOwnerRequiresActualReleaseAndKeepsAttemptHistory() throws {
        let fixture = try makeFixture()
        let start = Date(timeIntervalSince1970: 30_000)
        let store = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
        let claim = try XCTUnwrap(store.claimAutomaticRecoveryAttempt(identity: fixture.identity, now: start))
        let reopened = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
        XCTAssertEqual(reopened.recoveryReconciliationOpportunity(identity: fixture.identity,
            now: start.addingTimeInterval(1_000)), .blocked)
        let bytes = fixture.defaults.data(forKey: fixture.key)
        XCTAssertEqual(reopened.automaticRecoveryAttemptEligibility(identity: fixture.identity,
            now: start.addingTimeInterval(1_000)), .exhausted)
        XCTAssertEqual(fixture.defaults.data(forKey: fixture.key), bytes)
        store.releaseAutomaticRecoveryAttempt(claim, now: start.addingTimeInterval(1))
        XCTAssertEqual(reopened.recoveryReconciliationOpportunity(identity: fixture.identity,
            now: start.addingTimeInterval(1)), .cooldown(300))
        XCTAssertEqual(try object(XCTUnwrap(fixture.defaults.data(forKey: fixture.key)))["totalAttempts"] as? Int, 1)
    }

    @MainActor
    func testPreviousProcessClaimIsRequalifiedButUnreleasedCurrentProcessClaimIsNot() throws {
        let fixture = try makeFixture()
        let start = Date(timeIntervalSince1970: 32_000)
        let oldEpoch = UUID()
        let old = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix, recoveryProcessEpoch: oldEpoch)
        let claim = try XCTUnwrap(old.claimAutomaticRecoveryAttempt(identity: fixture.identity, now: start))
        let interruptedBytes = try XCTUnwrap(fixture.defaults.data(forKey: fixture.key))
        old.releaseAutomaticRecoveryAttempt(claim, now: start.addingTimeInterval(1))
        // Explicit crash fixture keeps the actual pre-completion bytes while
        // retiring only this test's in-memory owner, then models a new process.
        fixture.defaults.set(interruptedBytes, forKey: fixture.key)
        XCTAssertTrue(fixture.defaults.synchronize())
        let sameEpoch = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix, recoveryProcessEpoch: oldEpoch)
        XCTAssertEqual(sameEpoch.recoveryReconciliationOpportunity(identity: fixture.identity,
            now: start.addingTimeInterval(2)), .blocked)
        XCTAssertEqual(sameEpoch.recoveryReconciliationBlockReason, "owner_release_not_proved")
        XCTAssertEqual(fixture.defaults.data(forKey: fixture.key), interruptedBytes)
        let newProcess = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix, recoveryProcessEpoch: UUID())
        XCTAssertEqual(newProcess.recoveryReconciliationOpportunity(identity: fixture.identity,
            now: start.addingTimeInterval(2)), .cooldown(300))
        let prepared = try object(XCTUnwrap(fixture.defaults.data(forKey: fixture.key)))
        XCTAssertEqual(prepared["totalAttempts"] as? Int, 1)
        XCTAssertNil(prepared["lastCompletedAt"])
        XCTAssertNil(prepared["failure"])
        let lifecycle = try XCTUnwrap(prepared["lifecycle"] as? [String: Any])
        XCTAssertEqual(Data(base64Encoded: try XCTUnwrap(lifecycle["originPayload"] as? String)), interruptedBytes)
    }

    @MainActor
    func testDelayedObservationAfterActualReleaseDoesNotPostponeTheRecordedDue() throws {
        let fixture = try makeFixture()
        let start = Date(timeIntervalSince1970: 35_000)
        let store = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
        let claim = try XCTUnwrap(store.claimAutomaticRecoveryAttempt(identity: fixture.identity, now: start))
        let original = try XCTUnwrap(fixture.defaults.data(forKey: fixture.key))
        store.releaseAutomaticRecoveryAttempt(claim, now: start.addingTimeInterval(1))
        let released = try object(XCTUnwrap(fixture.defaults.data(forKey: fixture.key)))
        XCTAssertEqual(released["nextAllowedAt"] as? Double, start.timeIntervalSince1970 + 301)
        let reopened = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
        guard case .ready = reopened.recoveryReconciliationOpportunity(identity: fixture.identity,
            now: start.addingTimeInterval(400)) else { return XCTFail("Observation cannot postpone an already elapsed release due") }
        let current = try object(XCTUnwrap(fixture.defaults.data(forKey: fixture.key)))
        XCTAssertEqual(current["nextAllowedAt"] as? Double, start.timeIntervalSince1970 + 301)
        let lifecycle = try XCTUnwrap(current["lifecycle"] as? [String: Any])
        XCTAssertEqual(Data(base64Encoded: try XCTUnwrap(lifecycle["originPayload"] as? String)), original)
        XCTAssertEqual(current["totalAttempts"] as? Int, 1)
    }

    @MainActor
    func testTypedSnapshotChangeOrCancellationKeepsItsCompletedInvocationDue() throws {
        for failure in [AutomaticSyncFailure(disposition: .reconciliation, category: .snapshotChanged),
                        AutomaticSyncFailure(disposition: .stable, category: .cancelled)] {
            let fixture = try makeFixture()
            let start = Date(timeIntervalSince1970: 37_000)
            let store = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
            let claim = try XCTUnwrap(store.claimAutomaticRecoveryAttempt(identity: fixture.identity, now: start))
            store.recordRunResult(.failed(errorCode: "controlled", failure: failure),
                preserveRecoveryRequired: true, automaticRecoveryClaim: claim, now: start.addingTimeInterval(1))
            let before = try object(XCTUnwrap(fixture.defaults.data(forKey: fixture.key)))
            XCTAssertEqual(before["nextAllowedAt"] as? Double, start.timeIntervalSince1970 + 301)
            guard case .ready = store.recoveryReconciliationOpportunity(identity: fixture.identity,
                now: start.addingTimeInterval(400)) else { return XCTFail("A recorded completion already owns the conservative due") }
            let after = try object(XCTUnwrap(fixture.defaults.data(forKey: fixture.key)))
            XCTAssertEqual(after["nextAllowedAt"] as? Double, start.timeIntervalSince1970 + 301)
            XCTAssertEqual(after["lastCompletedAt"] as? Double, start.timeIntervalSince1970 + 1)
            XCTAssertEqual(after["totalAttempts"] as? Int, 1)
        }
    }

    @MainActor
    func testLegacyPreparedWithoutAcceptedPrefixIsRequalifiedWithoutDeletingV1() throws {
        let fixture = try makeFixture()
        let start = Date(timeIntervalSince1970: 40_000)
        let legacy = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "identity": fixture.identity,
            "attemptCount": 3, "nextAllowedAt": 39_000])
        fixture.defaults.set(legacy, forKey: "\(fixture.prefix).automaticRecoveryAttempt.v1")
        let store = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
        guard case .ready = store.recoveryReconciliationOpportunity(identity: fixture.identity, now: start) else {
            return XCTFail("The qualified recorded legacy due is already elapsed")
        }
        XCTAssertEqual(fixture.defaults.data(forKey: "\(fixture.prefix).automaticRecoveryAttempt.v1"), legacy)
        let record = try object(XCTUnwrap(fixture.defaults.data(forKey: fixture.key)))
        XCTAssertEqual(record["totalAttempts"] as? Int, 3)
        let lifecycle = try XCTUnwrap(record["lifecycle"] as? [String: Any])
        XCTAssertEqual(lifecycle["originalAttemptTimeUnknown"] as? Bool, true)
        guard case .ready(let descriptor) = store.recoveryReconciliationOpportunity(identity: fixture.identity,
            now: start) else { return XCTFail("Expected preserved legacy continuation") }
        let claim = try XCTUnwrap(store.claimAutomaticRecoveryAttempt(identity: fixture.identity,
            now: start, reconciliation: descriptor))
        XCTAssertEqual(try object(XCTUnwrap(fixture.defaults.data(forKey: fixture.key)))["totalAttempts"] as? Int, 4)
        store.releaseAutomaticRecoveryAttempt(claim, now: start.addingTimeInterval(301))
    }

    @MainActor
    func testOtherLegacyCountsRetainTotalAndKnownDueWithoutCreatingANewWindowAtLaunch() throws {
        for total in [1, 2, 4, 7] {
            let fixture = try makeFixture()
            let start = Date(timeIntervalSince1970: 42_000)
            let legacy = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1,
                "identity": fixture.identity, "attemptCount": total, "nextAllowedAt": 42_900])
            fixture.defaults.set(legacy, forKey: "\(fixture.prefix).automaticRecoveryAttempt.v1")
            let store = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
            XCTAssertEqual(store.recoveryReconciliationOpportunity(identity: fixture.identity, now: start), .cooldown(900))
            let prepared = try XCTUnwrap(fixture.defaults.data(forKey: fixture.key))
            let record = try object(prepared)
            XCTAssertEqual(record["totalAttempts"] as? Int, total)
            let reopened = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
            XCTAssertEqual(reopened.recoveryReconciliationOpportunity(identity: fixture.identity,
                now: start.addingTimeInterval(899)), .cooldown(1))
            XCTAssertEqual(fixture.defaults.data(forKey: fixture.key), prepared)
            XCTAssertEqual(fixture.defaults.data(forKey: "\(fixture.prefix).automaticRecoveryAttempt.v1"), legacy)
        }
    }

    @MainActor
    func testLegacyDurableClaimWithoutV2StillCountsItsConsumedAttemptAfterReopen() throws {
        let fixture = try makeFixture()
        let binding = AccountBindingStore(defaults: fixture.defaults)
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: fixture.ownerUserID,
            defaults: fixture.defaults, allowsPendingSameScopeRecovery: true)
        let generation = UUID()
        XCTAssertTrue(binding.recordPendingRecoveryStaging(accountHash: scope.accountHash,
            storeIdentity: scope.storeIdentity, deviceIdentityHash: scope.deviceIdentityHash,
            generationID: generation, scope: scope))
        let start = Date(timeIntervalSince1970: 45_000)
        let legacy = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "identity": fixture.identity,
            "attemptCount": 3, "nextAllowedAt": 44_000])
        fixture.defaults.set(legacy, forKey: "\(fixture.prefix).automaticRecoveryAttempt.v1")
        let old = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
        let continuation = try XCTUnwrap(old.legacyRecoveryContinuation(identity: fixture.identity, now: start))
        let oldClaim = try XCTUnwrap(old.claimAutomaticRecoveryAttempt(identity: fixture.identity,
            now: start, legacyContinuation: continuation))
        let claimKey = "\(fixture.prefix).automaticRecoveryLegacyClaim.v1"
        let claimBytes = try XCTUnwrap(fixture.defaults.data(forKey: claimKey))
        old.releaseAutomaticRecoveryAttempt(oldClaim, now: start.addingTimeInterval(1))
        // Explicit historical crash fixture: the old claim fsync succeeded,
        // but the following retry-metadata write never reached disk.
        fixture.defaults.removeObject(forKey: fixture.key)
        XCTAssertTrue(fixture.defaults.synchronize())
        let reopened = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
        XCTAssertEqual(reopened.recoveryReconciliationOpportunity(identity: fixture.identity,
            now: start.addingTimeInterval(2)), .cooldown(300))
        XCTAssertEqual(try object(XCTUnwrap(fixture.defaults.data(forKey: fixture.key)))["totalAttempts"] as? Int, 4)
        XCTAssertEqual(fixture.defaults.data(forKey: claimKey), claimBytes)
        XCTAssertEqual(fixture.defaults.data(forKey: "\(fixture.prefix).automaticRecoveryAttempt.v1"), legacy)
        guard case .ready(let descriptor) = reopened.recoveryReconciliationOpportunity(identity: fixture.identity,
            now: start.addingTimeInterval(302)) else { return XCTFail("Expected the preserved fifth opportunity") }
        let claim = try XCTUnwrap(reopened.claimAutomaticRecoveryAttempt(identity: fixture.identity,
            now: start.addingTimeInterval(302), reconciliation: descriptor))
        XCTAssertEqual(try object(XCTUnwrap(fixture.defaults.data(forKey: fixture.key)))["totalAttempts"] as? Int, 5)
        reopened.releaseAutomaticRecoveryAttempt(claim, now: start.addingTimeInterval(303))
    }

    @MainActor
    func testMalformedForeignAndUnknownVersionMetadataRemainUnchanged() throws {
        let fixture = try makeFixture()
        let start = Date(timeIntervalSince1970: 50_000)
        let foreign = try oldV2(identity: String(repeating: "a", count: 64), at: start)
        let unknown = try JSONSerialization.data(withJSONObject: ["schemaVersion": 99, "identity": fixture.identity])
        let malformed = Data("{\"schemaVersion\":2,\"identity\":".utf8)
        let valid = try oldV2(identity: fixture.identity, at: start)
        let duplicate = Data(("{\"schemaVersion\":2," + String(String(decoding: valid, as: UTF8.self).dropFirst())).utf8)
        var unknownFields = try object(valid)
        unknownFields["futurePermission"] = true
        let extraField = try JSONSerialization.data(withJSONObject: unknownFields)
        for bytes in [foreign, unknown, malformed, duplicate, extraField] {
            fixture.defaults.set(bytes, forKey: fixture.key)
            let store = SyncStateStore(defaults: fixture.defaults, keyPrefix: fixture.prefix)
            XCTAssertEqual(store.recoveryReconciliationOpportunity(identity: fixture.identity, now: start), .blocked)
            XCTAssertEqual(fixture.defaults.data(forKey: fixture.key), bytes)
        }
    }

    @MainActor
    func testReleasedBusyAndScheduledRetryHaveNoActiveWorkProjection() {
        let suite = "RecoveryReconciliationProjection-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SyncStateStore(defaults: defaults, keyPrefix: "r23.projection")
        store.recordRunResult(.busy())
        XCTAssertFalse(store.state.phase.isAutomaticWorkActive)
        store.recordRunResult(.scheduledRetry(after: 5))
        XCTAssertFalse(store.state.phase.isAutomaticWorkActive)
    }

    @MainActor
    private func makeFixture() throws -> (defaults: UserDefaults, prefix: String, key: String, identity: String, ownerUserID: UUID) {
        let suite = "RecoveryReconciliationPersistence-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let owner = UUID()
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let shop = SelectedShop(shopID: UUID(), code: "R23", name: "Recovery fixture", role: "owner",
            status: "active", selectable: true, canWrite: true)
        let selected = SelectedShopStore(defaults: defaults)
        selected.noteActiveAccount(accountHash)
        XCTAssertTrue(selected.save(shop, accountHash: accountHash))
        let binding = AccountBindingStore(defaults: defaults)
        XCTAssertTrue(binding.saveBinding(accountHash: accountHash, storeIdentity: shop.localStoreIdentity))
        let device = DeviceInstallIDStore(defaults: defaults).deviceInstallID
        XCTAssertTrue(binding.beginSameScopeRecovery(accountHash: accountHash, storeIdentity: shop.localStoreIdentity,
            reason: "r23_interrupted", deviceIdentityHash: DeviceInstallIDStore.identityHash(for: device)))
        let journal = try XCTUnwrap(binding.pendingRecoveryJournal)
        let prefix = "r23.recovery"
        return (defaults, prefix, "\(prefix).automaticRecoveryAttempt.v2", SyncOrchestrator.automaticRecoveryResumeIdentity(for: journal), owner)
    }

    private func oldV2(identity: String, at: Date, retryAfter: Date? = nil) throws -> Data {
        var values: [String: Any] = ["schemaVersion": 2, "identity": identity, "invocationID": UUID().uuidString,
            "windowIndex": 1, "attemptsInWindow": 1, "totalAttempts": 1,
            "lastAttemptAt": at.timeIntervalSince1970,
            "nextAllowedAt": retryAfter?.timeIntervalSince1970 ?? at.timeIntervalSince1970]
        if let retryAfter { values["retryAfterUntil"] = retryAfter.timeIntervalSince1970 }
        return try JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])
    }

    private func object(_ bytes: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
    }

    private func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
