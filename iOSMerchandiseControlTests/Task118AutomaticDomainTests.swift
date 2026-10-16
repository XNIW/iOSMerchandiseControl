import SwiftData
import XCTest
@testable import iOSMerchandiseControl

final class Task118AutomaticDomainTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    @MainActor
    private func qualifiedOriginalCompletionDate(
        _ result: SyncAutomaticRunResult, defaults: UserDefaults,
        file: StaticString = #filePath, line: UInt = #line
    ) throws -> Date {
        let observation = try XCTUnwrap(result.observation,
            "A genuine recovery must carry its original Engine completion observation", file: file, line: line)
        _ = try XCTUnwrap(observation.hasValidPersistentFacts && observation.matches(result)
            && observation.origin.isCurrent(defaults: defaults)
            && observation.completedAt.isFinite && observation.completedAt > 0 ? true : nil,
            "ORIGINAL_ENGINE_COMPLETION_NOT_QUALIFIED_DATE_ASSERTIONS_NOT_REACHED", file: file, line: line)
        return Date(timeIntervalSince1970: observation.completedAt)
    }

    func testRunResultOutcomesAreExplicitAndDistinct() {
        let results: [SyncAutomaticRunResult] = [
            .success(didWork: true),
            .noWork(),
            .recoveryRequired(),
            .blocked(.authRequired),
            .busy(),
            .failed(errorCode: "unit"),
            .cancelled(),
            .scheduledRetry()
        ]

        XCTAssertEqual(Set(results.map(\.status)), Set(SyncAutomaticRunStatus.allCases))
        XCTAssertTrue(results[0].didWork)
        XCTAssertFalse(results[1].didWork)
        XCTAssertEqual(results[3].blockReason, .authRequired)
    }

    func testDecisionEngineBlocksInsteadOfNoOpWhenStateReadFails() {
        let action = SyncDecisionEngine.decide(
            SyncDecisionInput(
                trigger: .appForeground,
                isAuthenticated: true,
                isNetworkAvailable: true,
                hasStateReadFailure: true
            )
        )

        XCTAssertEqual(action, .blocked(.localStateUnavailable))
    }

    @MainActor
    func testRootPresentationDoesNotShowCheckingForIdleDecisionOnlyPass() {
        let state = SyncOrchestrator.makeRootPresentationState(
            isTransitioning: false,
            isSignedIn: true,
            isAutomaticRuntimeRunning: false,
            phase: .idle
        )

        XCTAssertEqual(state.kind, .hidden)
    }

    @MainActor
    func testRootPresentationStillShowsCheckingForRealAutomaticWork() {
        let state = SyncOrchestrator.makeRootPresentationState(
            isTransitioning: false,
            isSignedIn: true,
            isAutomaticRuntimeRunning: false,
            phase: .pullingEvents
        )

        XCTAssertEqual(state.kind, .checking)
    }

    @MainActor
    func testStateStoreRecordsEveryAutomaticRunOutcome() async throws {
        let fixture = try await makeQualifiedSyncStateFixture()
        let defaults = fixture.defaults

        let store = SyncStateStore(defaults: defaults, keyPrefix: "task118", storeGenerationController: fixture.controller)

        store.recordRunResult(fixture.result)
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertEqual(store.state.lastOutcome, .succeeded)
        XCTAssertNotNil(store.state.lastVerifiedAt)
        let verifiedAfterSuccess = store.state.lastVerifiedAt

        store.recordRunResult(.noWork())
        XCTAssertEqual(store.state.phase, .recoveryRequired)
        XCTAssertEqual(store.state.lastOutcome, .noWork)
        XCTAssertEqual(store.state.lastVerifiedAt, verifiedAfterSuccess)

        store.recordRunResult(.blocked(.networkUnavailable))
        XCTAssertEqual(store.state.phase, .blocked(.networkUnavailable))
        XCTAssertEqual(store.state.lastOutcome, .blocked(.networkUnavailable))

        store.recordRunResult(.busy())
        XCTAssertEqual(store.state.phase, .checking)
        XCTAssertEqual(store.state.lastOutcome, .busy)

        store.recordRunResult(.failed(errorCode: "unit"))
        XCTAssertEqual(store.state.phase, .failed)
        XCTAssertEqual(store.state.lastOutcome, .failed)

        store.recordRunResult(.cancelled())
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertEqual(store.state.lastOutcome, .cancelled)

        store.recordRunResult(.scheduledRetry())
        XCTAssertEqual(store.state.phase, .checking)
        XCTAssertEqual(store.state.lastOutcome, .scheduledRetry)
    }

    @MainActor
    func testStateStoreDoesNotPromoteDecisionNoWorkToVerifiedSuccess() async throws {
        let fixture = try await makeQualifiedSyncStateFixture()
        let defaults = fixture.defaults

        let store = SyncStateStore(defaults: defaults, keyPrefix: "task136", storeGenerationController: fixture.controller)

        store.recordRunResult(.failed(errorCode: "networkError(redacted)"))
        XCTAssertEqual(defaults.string(forKey: "task136.lastRunErrorCode"), "networkError(redacted)")

        store.recordRunResult(.noWork())
        XCTAssertEqual(store.state.phase, .recoveryRequired)
        XCTAssertEqual(store.state.lastOutcome, .noWork)
        XCTAssertNil(store.state.lastVerifiedAt)
        XCTAssertNil(defaults.string(forKey: "task136.lastRunErrorCode"))
        XCTAssertNil(defaults.string(forKey: "task136.lastRunBlockReason"))

        let relaunched = SyncStateStore(defaults: defaults, keyPrefix: "task136", storeGenerationController: fixture.controller)
        XCTAssertEqual(relaunched.state.phase, .recoveryRequired)
        XCTAssertNil(relaunched.state.lastVerifiedAt)

        let verifiedAt = try qualifiedOriginalCompletionDate(fixture.result, defaults: defaults)
        relaunched.recordRunResult(
            fixture.result,
            now: verifiedAt.addingTimeInterval(1_000)
        )
        XCTAssertEqual(relaunched.state.phase, .idle)
        XCTAssertEqual(relaunched.state.lastVerifiedAt, verifiedAt)
        var repeatedProof = fixture.result
        repeatedProof.status = .noWork
        repeatedProof.didWork = false
        relaunched.recordRunResult(
            repeatedProof,
            now: verifiedAt.addingTimeInterval(1_100)
        )
        XCTAssertEqual(relaunched.state.phase, .idle)
        XCTAssertEqual(relaunched.state.lastVerifiedAt, verifiedAt)

        let verifiedRelaunch = SyncStateStore(defaults: defaults, keyPrefix: "task136", storeGenerationController: fixture.controller)
        XCTAssertEqual(verifiedRelaunch.state.phase, .idle)
        XCTAssertEqual(verifiedRelaunch.state.lastVerifiedAt, verifiedAt)
    }

    @MainActor
    func testLegacyUnversionedVerifiedTimestampIsNotTrustedAfterRelaunch() {
        let suiteName = "Task139LegacyVerifiedTimestamp-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("success", forKey: "task139.legacy.lastRunStatus")
        defaults.set("idle", forKey: "task139.legacy.phase")
        defaults.set(500.0, forKey: "task139.legacy.lastVerifiedAt")
        let rawBefore = NSDictionary(dictionary: defaults.dictionaryRepresentation()
            .filter { $0.key.hasPrefix("task139.legacy.") })

        let store = SyncStateStore(defaults: defaults, keyPrefix: "task139.legacy")

        XCTAssertEqual(store.state.phase, .idle,
            "Untrusted legacy success alone cannot create a recovery latch")
        XCTAssertNil(store.state.lastOutcome)
        XCTAssertNil(store.state.lastVerifiedAt)
        XCTAssertEqual(NSDictionary(dictionary: defaults.dictionaryRepresentation()
            .filter { $0.key.hasPrefix("task139.legacy.") }), rawBefore,
            "Reading the typed-only projection must preserve all raw legacy values")
    }

    @MainActor
    func testVerifiedProofReplayPreservesFirstDateAndHistoricalSuccessAfterFailure() async throws {
        let fixture = try await makeQualifiedSyncStateFixture()
        let prefix = "task145.verified-replay"
        let store = SyncStateStore(defaults: fixture.defaults, keyPrefix: prefix,
            storeGenerationController: fixture.controller)
        let firstDate = try qualifiedOriginalCompletionDate(fixture.result, defaults: fixture.defaults)
        store.recordRunResult(fixture.result, now: firstDate.addingTimeInterval(1_000))
        let acceptedBytes = try XCTUnwrap(fixture.defaults.data(forKey: "\(prefix).lastVerifiedProof.v2"))
        XCTAssertEqual(store.state.lastVerifiedAt, firstDate)
        store.recordRunResult(fixture.result, now: firstDate.addingTimeInterval(4_600))
        XCTAssertEqual(store.state.lastVerifiedAt, firstDate)
        XCTAssertEqual(fixture.defaults.data(forKey: "\(prefix).lastVerifiedProof.v2"), acceptedBytes)
        store.recordRunResult(.failed(errorCode: "subsequent_failure"), now: firstDate.addingTimeInterval(7_200))
        XCTAssertEqual(store.state.phase, .failed)
        XCTAssertEqual(store.state.lastVerifiedAt, firstDate)
        let reopened = SyncStateStore(defaults: fixture.defaults, keyPrefix: prefix,
            storeGenerationController: fixture.controller)
        XCTAssertEqual(reopened.state.lastVerifiedAt, firstDate)
        XCTAssertEqual(fixture.defaults.data(forKey: "\(prefix).lastVerifiedProof.v2"), acceptedBytes)
    }

    @MainActor
    func testBoolOnlyVerificationCannotBorrowAnAlreadyQualifiedGeneration() async throws {
        let fixture = try await makeQualifiedSyncStateFixture()
        let prefix = "task145.bool-only"
        let store = SyncStateStore(defaults: fixture.defaults, keyPrefix: prefix,
            storeGenerationController: fixture.controller)
        store.recordRunResult(.success(didWork: true, verifiedConvergence: true))
        XCTAssertNil(store.state.lastVerifiedAt)
        XCTAssertEqual(store.state.phase, .recoveryRequired)
        XCTAssertNil(fixture.defaults.data(forKey: "\(prefix).lastVerifiedProof.v2"))
        XCTAssertNil(SyncStateStore(defaults: fixture.defaults, keyPrefix: prefix,
            storeGenerationController: fixture.controller).state.lastVerifiedAt)
    }

    @MainActor
    func testLegacyVersionOneAndCorruptVerifiedProofRemainPreservedAndUntrusted() async throws {
        let fixture = try await makeQualifiedSyncStateFixture()
        let prefix = "task145.legacy-proof"
        fixture.defaults.set("success", forKey: "\(prefix).lastRunStatus")
        fixture.defaults.set("idle", forKey: "\(prefix).phase")
        fixture.defaults.set(500.0, forKey: "\(prefix).lastVerifiedAt")
        fixture.defaults.set(1, forKey: "\(prefix).lastVerifiedProofVersion")
        let rawBefore = NSDictionary(dictionary: fixture.defaults.dictionaryRepresentation()
            .filter { $0.key.hasPrefix("\(prefix).") })
        let legacy = SyncStateStore(defaults: fixture.defaults, keyPrefix: prefix,
            storeGenerationController: fixture.controller)
        XCTAssertNil(legacy.state.lastVerifiedAt)
        XCTAssertEqual(legacy.state.phase, .idle,
            "Untrusted version-one diagnostics alone cannot create a recovery latch")
        XCTAssertNil(legacy.state.lastOutcome)
        XCTAssertEqual(NSDictionary(dictionary: fixture.defaults.dictionaryRepresentation()
            .filter { $0.key.hasPrefix("\(prefix).") }), rawBefore,
            "Hydration must preserve all raw version-one diagnostics")
        XCTAssertEqual(fixture.defaults.double(forKey: "\(prefix).lastVerifiedAt"), 500)
        XCTAssertEqual(fixture.defaults.integer(forKey: "\(prefix).lastVerifiedProofVersion"), 1)

        let verifiedAt = try qualifiedOriginalCompletionDate(fixture.result, defaults: fixture.defaults)
        legacy.recordRunResult(fixture.result, now: verifiedAt.addingTimeInterval(1_000))
        let valid = try XCTUnwrap(fixture.defaults.data(forKey: "\(prefix).lastVerifiedProof.v2"))
        var unknownVersion = try XCTUnwrap(JSONSerialization.jsonObject(with: valid) as? [String: Any])
        unknownVersion["schemaVersion"] = 99
        var invalidDate = try XCTUnwrap(JSONSerialization.jsonObject(with: valid) as? [String: Any])
        invalidDate["verifiedAt"] = -1
        for corrupt in [Data("{broken".utf8), try JSONSerialization.data(withJSONObject: unknownVersion),
                        try JSONSerialization.data(withJSONObject: invalidDate)] {
            fixture.defaults.set(corrupt, forKey: "\(prefix).lastVerifiedProof.v2")
            XCTAssertNil(legacy.state.lastVerifiedAt)
            let reopened = SyncStateStore(defaults: fixture.defaults, keyPrefix: prefix,
                storeGenerationController: fixture.controller)
            XCTAssertNil(reopened.state.lastVerifiedAt)
            XCTAssertEqual(fixture.defaults.data(forKey: "\(prefix).lastVerifiedProof.v2"), corrupt)
            XCTAssertEqual(fixture.defaults.double(forKey: "\(prefix).lastVerifiedAt"), 500)
            XCTAssertEqual(fixture.defaults.integer(forKey: "\(prefix).lastVerifiedProofVersion"), 1)
        }
    }

    @MainActor
    func testOriginProofCannotBeReassignedToAnotherAlreadyQualifiedGeneration() async throws {
        let a = try await makeQualifiedSyncStateFixture()
        let b = try await makeQualifiedSyncStateFixture()
        let prefix = "task145.two-qualified-generations"
        let key = "\(prefix).lastVerifiedProof.v2"
        let stateA = SyncStateStore(defaults: a.defaults, keyPrefix: prefix,
            storeGenerationController: a.controller)
        let stateB = SyncStateStore(defaults: b.defaults, keyPrefix: prefix,
            storeGenerationController: b.controller)
        let completedA = try qualifiedOriginalCompletionDate(a.result, defaults: a.defaults)
        let completedB = try qualifiedOriginalCompletionDate(b.result, defaults: b.defaults)
        stateA.recordRunResult(a.result, now: completedA.addingTimeInterval(1_000))
        stateB.recordRunResult(b.result, now: completedB.addingTimeInterval(2_000))
        XCTAssertEqual(stateA.state.lastVerifiedAt, completedA)
        XCTAssertEqual(stateB.state.lastVerifiedAt, completedB)
        let bytesA = try XCTUnwrap(a.defaults.data(forKey: key))
        let bytesB = try XCTUnwrap(b.defaults.data(forKey: key))
        stateB.recordRunResult(a.result, now: completedB.addingTimeInterval(3_000))
        XCTAssertEqual(stateB.state.lastVerifiedAt, completedB)
        XCTAssertEqual(b.defaults.data(forKey: key), bytesB)
        b.defaults.set(bytesA, forKey: key)
        XCTAssertNil(stateB.state.lastVerifiedAt,
            "B's own qualified manifest cannot supply provenance for A's date")
        XCTAssertNil(SyncStateStore(defaults: b.defaults, keyPrefix: prefix,
            storeGenerationController: b.controller).state.lastVerifiedAt)
        XCTAssertEqual(b.defaults.data(forKey: key), bytesA)
    }

    @MainActor
    func testVerifiedDateRequiresEveryOriginFieldAndCurrentQualifiedLocalBody() async throws {
        let fixture = try await makeQualifiedSyncStateFixture()
        let prefix = "task145.proof-identity"
        let key = "\(prefix).lastVerifiedProof.v2"
        let store = SyncStateStore(defaults: fixture.defaults, keyPrefix: prefix,
            storeGenerationController: fixture.controller)
        let completedAt = try qualifiedOriginalCompletionDate(fixture.result, defaults: fixture.defaults)
        store.recordRunResult(fixture.result, now: completedAt.addingTimeInterval(1_000))
        let bytes = try XCTUnwrap(fixture.defaults.data(forKey: key))
        let record = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let original = try XCTUnwrap(record["finalization"] as? [String: Any])
        for field in ["accountHash", "shopID", "deviceIdentityHash", "generationID", "checkpointDigest", "baselineRunID", "storeIdentity"] {
            var changed = record
            var origin = original
            switch field {
            case "accountHash", "deviceIdentityHash", "checkpointDigest": origin[field] = String(repeating: "f", count: 64)
            case "storeIdentity":
                var identity = try XCTUnwrap(origin[field] as? [String: Any])
                let originalEpoch = try XCTUnwrap(identity["storeEpoch"] as? Int,
                    "The mutator must change a real encoded field, never add an ignored key")
                identity["storeEpoch"] = originalEpoch + 1
                origin[field] = identity
            default: origin[field] = UUID().uuidString
            }
            changed["finalization"] = origin
            let mutated = try JSONSerialization.data(withJSONObject: changed)
            if field == "storeIdentity" {
                let decoded = try JSONDecoder().decode(SyncStoreRecoveryFinalization.self,
                    from: JSONSerialization.data(withJSONObject: origin))
                let actualOrigin = try XCTUnwrap(fixture.result.verifiedFinalization)
                XCTAssertEqual(decoded.storeIdentity.rawValue, actualOrigin.storeIdentity.rawValue)
                XCTAssertEqual(decoded.storeIdentity.defaultStoreId, actualOrigin.storeIdentity.defaultStoreId)
                XCTAssertEqual(decoded.storeIdentity.localStoreId, actualOrigin.storeIdentity.localStoreId)
                XCTAssertEqual(decoded.storeIdentity.schemaVersion, actualOrigin.storeIdentity.schemaVersion)
                XCTAssertEqual(decoded.storeIdentity.syncProtocolVersion, actualOrigin.storeIdentity.syncProtocolVersion)
                _ = try XCTUnwrap(decoded.storeIdentity.storeEpoch == actualOrigin.storeIdentity.storeEpoch + 1
                    ? true : nil, "FULL_STORE_EPOCH_MUTATION_NOT_QUALIFIED_DATE_PROJECTION_NOT_REACHED")
                print("TASK145_D01_FULL_STORE_MUTATION originalEpoch=\(actualOrigin.storeIdentity.storeEpoch) decodedEpoch=\(decoded.storeIdentity.storeEpoch) rawSame=\(decoded.storeIdentity.rawValue == actualOrigin.storeIdentity.rawValue) typedEquality=\(decoded.storeIdentity == actualOrigin.storeIdentity)")
            }
            fixture.defaults.set(mutated, forKey: key)
            XCTAssertNil(store.state.lastVerifiedAt, field)
            XCTAssertNil(SyncStateStore(defaults: fixture.defaults, keyPrefix: prefix,
                storeGenerationController: fixture.controller).state.lastVerifiedAt, field)
            XCTAssertEqual(fixture.defaults.data(forKey: key), mutated)
        }
        fixture.defaults.set(bytes, forKey: key)
        XCTAssertEqual(store.state.lastVerifiedAt, completedAt)
        XCTAssertNil(SyncStateStore(defaults: fixture.defaults, keyPrefix: prefix).state.lastVerifiedAt,
            "Custom defaults cannot borrow the application's shared controller")
        Task126OwnerStoreGate.configureLocalBodyFence(container: fixture.controller.modelContainer,
            proven: false, provider: { nil })
        XCTAssertNil(store.state.lastVerifiedAt)
        XCTAssertNil(SyncStateStore(defaults: fixture.defaults, keyPrefix: prefix,
            storeGenerationController: fixture.controller).state.lastVerifiedAt)
        XCTAssertEqual(fixture.defaults.data(forKey: key), bytes)
    }

    @MainActor
    func testVerifiedProofV2RejectsLegacyScalarAndIncompleteNestedStoreIdentity() async throws {
        let fixture = try await makeQualifiedSyncStateFixture()
        let prefix = "task145.nested-proof-strictness"
        let key = "\(prefix).lastVerifiedProof.v2"
        let store = SyncStateStore(defaults: fixture.defaults, keyPrefix: prefix,
            storeGenerationController: fixture.controller)
        let verifiedAt = try qualifiedOriginalCompletionDate(fixture.result, defaults: fixture.defaults)
        store.recordRunResult(fixture.result, now: verifiedAt.addingTimeInterval(1_000))
        XCTAssertEqual(store.state.lastVerifiedAt, verifiedAt)
        let validBytes = try XCTUnwrap(fixture.defaults.data(forKey: key))
        let validRecord = try XCTUnwrap(JSONSerialization.jsonObject(with: validBytes) as? [String: Any])
        let validOrigin = try XCTUnwrap(validRecord["finalization"] as? [String: Any])
        let validIdentity = try XCTUnwrap(validOrigin["storeIdentity"] as? [String: Any])
        let realOrigin = try XCTUnwrap(fixture.result.verifiedFinalization)
        for mutation in ["legacyScalar", "storeEpoch", "schemaVersion", "syncProtocolVersion", "defaultStoreId", "localStoreId",
                         "emptyLocalStoreId", "whitespaceLocalStoreId", "emptyDefaultStoreId", "whitespaceDefaultStoreId", "spacedRawValue"] {
            var record = validRecord
            var origin = validOrigin
            if mutation == "legacyScalar" {
                origin["storeIdentity"] = realOrigin.storeIdentity.rawValue
            } else if ["emptyLocalStoreId", "whitespaceLocalStoreId", "emptyDefaultStoreId", "whitespaceDefaultStoreId", "spacedRawValue"].contains(mutation) {
                var malformed = validIdentity
                let field: String
                let value: String
                switch mutation {
                case "emptyLocalStoreId": field = "localStoreId"; value = ""
                case "whitespaceLocalStoreId": field = "localStoreId"; value = " \t "
                case "emptyDefaultStoreId": field = "defaultStoreId"; value = ""
                case "whitespaceDefaultStoreId": field = "defaultStoreId"; value = " \t "
                default: field = "rawValue"; value = " \(realOrigin.storeIdentity.rawValue) "
                }
                let actualOriginalValue = try XCTUnwrap(validIdentity[field] as? String)
                _ = try XCTUnwrap(value != actualOriginalValue ? true : nil,
                    "RAW_NESTED_INPUT_UNCHANGED_NORMALIZATION_NOT_REACHED: \(mutation)")
                malformed[field] = value
                origin["storeIdentity"] = malformed
            } else {
                var incomplete = validIdentity
                _ = try XCTUnwrap(incomplete.removeValue(forKey: mutation),
                    "The negative must remove a mandatory field actually encoded by the real origin")
                origin["storeIdentity"] = incomplete
            }
            record["finalization"] = origin
            // Qualify the reason for strict v2 parsing: the legacy product
            // decoder infers all missing/default fields and returns the same
            // concrete values. No fabricated scope or result is involved.
            let decoded = try JSONDecoder().decode(SyncStoreRecoveryFinalization.self,
                from: JSONSerialization.data(withJSONObject: origin))
            let identity = decoded.storeIdentity
            let real = realOrigin.storeIdentity
            _ = try XCTUnwrap(identity.rawValue == real.rawValue
                && identity.defaultStoreId == real.defaultStoreId
                && identity.localStoreId == real.localStoreId
                && identity.schemaVersion == real.schemaVersion
                && identity.syncProtocolVersion == real.syncProtocolVersion
                && identity.storeEpoch == real.storeEpoch ? true : nil,
                "NESTED_LEGACY_INFERENCE_NOT_QUALIFIED: \(mutation)")
            let mutated = try JSONSerialization.data(withJSONObject: record)
            XCTAssertNotEqual(mutated, validBytes)
            fixture.defaults.set(mutated, forKey: key)
            XCTAssertNil(store.state.lastVerifiedAt, mutation)
            XCTAssertNil(SyncStateStore(defaults: fixture.defaults, keyPrefix: prefix,
                storeGenerationController: fixture.controller).state.lastVerifiedAt, mutation)
            XCTAssertEqual(fixture.defaults.data(forKey: key), mutated)
        }
    }

    @MainActor
    func testAutomaticRecoveryAttemptBudgetPersistsBackoffAndExhaustionAcrossRelaunch() {
        let suiteName = "Task139RecoveryBudget-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let identity = String(repeating: "a", count: 64)
        let start = Date(timeIntervalSince1970: 10_000)

        var store = SyncStateStore(defaults: defaults, keyPrefix: "task139.budget", retryJitter: { 1 })
        XCTAssertEqual(
            store.automaticRecoveryAttemptEligibility(identity: identity, now: start),
            .ready
        )
        let firstClaim = store.claimAutomaticRecoveryAttempt(identity: identity, now: start)
        XCTAssertEqual(firstClaim?.attemptInWindow, 1)
        XCTAssertEqual(store.automaticRecoveryAttemptEligibility(identity: identity, now: start), .exhausted,
            "An unfinished attempt has no completed transient proof")
        store.recordRunResult(.blocked(.networkUnavailable), automaticRecoveryClaim: firstClaim, now: start)
        guard case .cooldown(let firstDelay) = store.automaticRecoveryAttemptEligibility(
            identity: identity,
            now: start
        ) else {
            return XCTFail("expected durable cooldown")
        }
        XCTAssertEqual(firstDelay, 2, accuracy: 0.001)

        store = SyncStateStore(defaults: defaults, keyPrefix: "task139.budget", retryJitter: { 1 })
        XCTAssertEqual(
            store.automaticRecoveryAttemptEligibility(
                identity: identity,
                now: start.addingTimeInterval(2)
            ),
            .ready
        )
        let secondClaim = store.claimAutomaticRecoveryAttempt(identity: identity, now: start.addingTimeInterval(2))
        XCTAssertEqual(secondClaim?.attemptInWindow, 2)
        store.recordRunResult(.blocked(.networkUnavailable), automaticRecoveryClaim: secondClaim, now: start.addingTimeInterval(2))
        let thirdClaim = store.claimAutomaticRecoveryAttempt(identity: identity, now: start.addingTimeInterval(6))
        XCTAssertEqual(thirdClaim?.attemptInWindow, 3)
        store.recordRunResult(.blocked(.networkUnavailable), automaticRecoveryClaim: thirdClaim, now: start.addingTimeInterval(6))

        let relaunched = SyncStateStore(defaults: defaults, keyPrefix: "task139.budget")
        XCTAssertEqual(
            relaunched.automaticRecoveryAttemptEligibility(
                identity: identity,
                now: start.addingTimeInterval(60)
            ),
            .cooldown(246)
        )
        XCTAssertEqual(relaunched.automaticRecoveryAttemptEligibility(identity: identity,
            now: start.addingTimeInterval(306)), .ready)
    }

    @MainActor
    func testExplicitRecoveryResetAndJournalProgressUseFreshBoundedBudget() {
        let suiteName = "Task139RecoveryBudgetReset-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let firstIdentity = String(repeating: "b", count: 64)
        let nextPhaseIdentity = String(repeating: "c", count: 64)
        let now = Date(timeIntervalSince1970: 20_000)
        let store = SyncStateStore(defaults: defaults, keyPrefix: "task139.budgetReset")

        XCTAssertEqual(store.beginAutomaticRecoveryAttempt(identity: firstIdentity, now: now), 1)
        XCTAssertEqual(
            store.automaticRecoveryAttemptEligibility(identity: nextPhaseIdentity, now: now),
            .ready
        )
        store.resetAutomaticRecoveryAttemptBudget()
        XCTAssertEqual(
            store.automaticRecoveryAttemptEligibility(identity: firstIdentity, now: now),
            .ready
        )
    }

    @MainActor
    func testAutomaticRecoveryCooldownNeverAnticipatesRequestedServerMinimum() {
        let suiteName = "Task145RecoveryServerMinimum-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let identity = String(repeating: "8", count: 64)
        let now = Date(timeIntervalSince1970: 30_000)
        let store = SyncStateStore(defaults: defaults, keyPrefix: "task145.server-minimum")
        let claim = store.claimAutomaticRecoveryAttempt(identity: identity, now: now)
        XCTAssertEqual(claim?.attemptInWindow, 1)
        let completedAt = now.addingTimeInterval(1)
        let requestedServerMinimum: TimeInterval = 600
        store.recordRunResult(.blocked(.networkUnavailable), preserveRecoveryRequired: true, automaticRecoveryClaim: claim, now: completedAt)

        let actualDelay = store.extendAutomaticRecoveryAttemptCooldown(identity: identity,
            requestedDelay: requestedServerMinimum, now: completedAt)

        XCTAssertEqual(actualDelay, requestedServerMinimum, accuracy: 0.001,
            "A server minimum is not subject to the local busy/backoff cap")
        let relaunched = SyncStateStore(defaults: defaults, keyPrefix: "task145.server-minimum")
        guard case .cooldown(let remaining) = relaunched.automaticRecoveryAttemptEligibility(
            identity: identity, now: completedAt.addingTimeInterval(599)) else {
            return XCTFail("The durable cooldown must still prohibit the request one second before its minimum")
        }
        XCTAssertEqual(remaining, 1, accuracy: 0.001)
    }

    @MainActor
    func testCorruptAutomaticRecoveryBudgetRemainsFailClosedAfterTimeAndRelaunch() {
        let suiteName = "Task145RecoveryCorruptBudget-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let prefix = "task145.corrupt-budget"
        let identity = String(repeating: "9", count: 64)
        let corrupt = Data("{\"schemaVersion\":1,\"identity\":\"truncated".utf8)
        defaults.set(corrupt, forKey: "\(prefix).automaticRecoveryAttempt.v1")
        let store = SyncStateStore(defaults: defaults, keyPrefix: prefix)
        let now = Date(timeIntervalSince1970: 40_000)
        XCTAssertEqual(store.automaticRecoveryAttemptEligibility(identity: identity, now: now), .exhausted)
        XCTAssertNil(store.beginAutomaticRecoveryAttempt(identity: identity, now: now))

        let relaunched = SyncStateStore(defaults: defaults, keyPrefix: prefix)
        XCTAssertEqual(relaunched.automaticRecoveryAttemptEligibility(identity: identity,
            now: now.addingTimeInterval(86_400)), .exhausted)
        XCTAssertNil(relaunched.beginAutomaticRecoveryAttempt(identity: identity,
            now: now.addingTimeInterval(86_400)))
        XCTAssertEqual(defaults.data(forKey: "\(prefix).automaticRecoveryAttempt.v1"), corrupt,
            "Fail-closed admission must preserve the original metadata as evidence")
    }

    @MainActor
    func testLegacyAutomaticRecoveryBudgetNeverInfersRetryabilityFromErrorText() throws {
        let suiteName = "Task145LegacyRecoveryBudget-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let prefix = "task145.legacy-budget"
        let identity = String(repeating: "7", count: 64)
        let legacy = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1, "identity": identity, "attemptCount": 3, "nextAllowedAt": 20_000
        ])
        defaults.set(legacy, forKey: "\(prefix).automaticRecoveryAttempt.v1")
        defaults.set("networkError(statusCode:503,message:timeout)", forKey: "\(prefix).lastRunErrorCode")

        let store = SyncStateStore(defaults: defaults, keyPrefix: prefix)
        let now = Date(timeIntervalSince1970: 50_000)
        XCTAssertEqual(store.automaticRecoveryAttemptEligibility(identity: identity, now: now), .exhausted)
        XCTAssertNil(store.beginAutomaticRecoveryAttempt(identity: identity, now: now))
        XCTAssertEqual(defaults.data(forKey: "\(prefix).automaticRecoveryAttempt.v1"), legacy)
        XCTAssertNil(defaults.data(forKey: "\(prefix).automaticRecoveryAttempt.v2"),
            "Legacy diagnostics do not prove a typed transient failure and cannot create a new window")
    }

    @MainActor
    func testRecoveryWindowJitterAndExactFiveMinuteBoundaryPersistCumulativeAttempts() throws {
        for jitter in [0.5, 1.0, 1.5] {
            let suiteName = "Task145RetryJitter-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defer { defaults.removePersistentDomain(forName: suiteName) }
            let prefix = "task145.jitter"
            let identity = String(repeating: "6", count: 64)
            let store = SyncStateStore(defaults: defaults, keyPrefix: prefix, retryJitter: { jitter })
            var completedAt = Date(timeIntervalSince1970: 60_000)
            for attempt in 1...3 {
                let claim = store.claimAutomaticRecoveryAttempt(identity: identity, now: completedAt)
                XCTAssertEqual(claim?.attemptInWindow, attempt)
                store.recordRunResult(.blocked(.networkUnavailable), preserveRecoveryRequired: true,
                    automaticRecoveryClaim: claim, now: completedAt)
                let delay = attempt == 3 ? 300 : 2 * pow(2, Double(attempt - 1)) * jitter
                XCTAssertEqual(store.automaticRecoveryAttemptEligibility(identity: identity, now: completedAt),
                    .cooldown(delay))
                if attempt < 3 { completedAt.addTimeInterval(delay) }
            }
            let relaunched = SyncStateStore(defaults: defaults, keyPrefix: prefix, retryJitter: { jitter })
            guard case .cooldown(let remaining) = relaunched.automaticRecoveryAttemptEligibility(identity: identity,
                now: completedAt.addingTimeInterval(299.999)) else { return XCTFail("The five-minute floor is strict") }
            XCTAssertEqual(remaining, 0.001, accuracy: 0.00001)
            XCTAssertNil(relaunched.beginAutomaticRecoveryAttempt(identity: identity,
                now: completedAt.addingTimeInterval(299.999)))
            XCTAssertEqual(relaunched.beginAutomaticRecoveryAttempt(identity: identity,
                now: completedAt.addingTimeInterval(300)), 1)
            let data = try XCTUnwrap(defaults.data(forKey: "\(prefix).automaticRecoveryAttempt.v2"))
            let record = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(record["windowIndex"] as? Int, 2)
            XCTAssertEqual(record["attemptsInWindow"] as? Int, 1)
            XCTAssertEqual(record["totalAttempts"] as? Int, 4)
            let unfinished = SyncStateStore(defaults: defaults, keyPrefix: prefix)
            XCTAssertEqual(unfinished.automaticRecoveryAttemptEligibility(identity: identity,
                now: completedAt.addingTimeInterval(86_400)), .exhausted)
        }
    }

    @MainActor
    func testCorruptV2DoesNotFallBackToLegacyOrAuthorizeAnotherIdentity() {
        let suiteName = "Task145CorruptV2-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let prefix = "task145.corrupt-v2"
        let corrupt = Data("{\"schemaVersion\":2,\"totalAttempts\":999".utf8)
        defaults.set(corrupt, forKey: "\(prefix).automaticRecoveryAttempt.v2")
        let store = SyncStateStore(defaults: defaults, keyPrefix: prefix)
        for identity in [String(repeating: "4", count: 64), String(repeating: "5", count: 64)] {
            XCTAssertEqual(store.automaticRecoveryAttemptEligibility(identity: identity), .exhausted)
            XCTAssertNil(store.beginAutomaticRecoveryAttempt(identity: identity))
        }
        XCTAssertEqual(defaults.data(forKey: "\(prefix).automaticRecoveryAttempt.v2"), corrupt)
    }

    @MainActor
    func testOrdinaryNoWorkCannotCompleteInflightRecoveryAttempt() throws {
        let suiteName = "Task145OrdinaryCompletionOwnership-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let prefix = "task145.ordinary-completion-owner"
        let store = SyncStateStore(defaults: defaults, keyPrefix: prefix)
        let identity = String(repeating: "1", count: 64)
        let startedAt = Date(timeIntervalSince1970: 80_000)
        XCTAssertEqual(store.beginAutomaticRecoveryAttempt(identity: identity, now: startedAt), 1)
        let inflight = try XCTUnwrap(defaults.data(forKey: "\(prefix).automaticRecoveryAttempt.v2"))

        store.recordRunResult(.noWork(), now: startedAt.addingTimeInterval(10))

        XCTAssertEqual(defaults.data(forKey: "\(prefix).automaticRecoveryAttempt.v2"), inflight,
            "An ordinary result has no claim over an in-flight recovery attempt")
        XCTAssertEqual(store.automaticRecoveryAttemptEligibility(identity: identity,
            now: startedAt.addingTimeInterval(86_400)), .exhausted)
    }

    @MainActor
    func testUnrelatedTransientResultCannotAuthorizeInflightRecoveryRetry() throws {
        let suiteName = "Task145TransientCompletionOwnership-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let prefix = "task145.transient-completion-owner"
        let store = SyncStateStore(defaults: defaults, keyPrefix: prefix, retryJitter: { 1 })
        let identity = String(repeating: "2", count: 64)
        let startedAt = Date(timeIntervalSince1970: 90_000)
        XCTAssertEqual(store.beginAutomaticRecoveryAttempt(identity: identity, now: startedAt), 1)
        let inflight = try XCTUnwrap(defaults.data(forKey: "\(prefix).automaticRecoveryAttempt.v2"))

        store.recordRunResult(.failed(errorCode: "TEST_UNRELATED_RESULT",
            failure: AutomaticSyncFailure.classify(URLError(.timedOut))), now: startedAt.addingTimeInterval(10))

        XCTAssertEqual(defaults.data(forKey: "\(prefix).automaticRecoveryAttempt.v2"), inflight,
            "Typed retryability is insufficient without ownership of this invocation")
        XCTAssertEqual(store.automaticRecoveryAttemptEligibility(identity: identity,
            now: startedAt.addingTimeInterval(86_400)), .exhausted)
    }

    @MainActor
    func testStaleRecoveryCompletionCannotFinishNewAttemptEvenWhenIdentityIsReused() throws {
        for reuseIdentity in [false, true] {
            let suiteName = "Task145StaleCompletionOwnership-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defer { defaults.removePersistentDomain(forName: suiteName) }
            let prefix = "task145.stale-completion-owner"
            let store = SyncStateStore(defaults: defaults, keyPrefix: prefix, retryJitter: { 1 })
            let identityA = String(repeating: "3", count: 64)
            let identityB = reuseIdentity ? identityA : String(repeating: "4", count: 64)
            let startedAt = Date(timeIntervalSince1970: 100_000)
            XCTAssertEqual(store.beginAutomaticRecoveryAttempt(identity: identityA, now: startedAt), 1)
            // An explicit fresh Retry may reuse the journal identity. A late
            // callback still belongs to invocation A, not its successor B.
            if reuseIdentity { store.resetAutomaticRecoveryAttemptBudget() }
            XCTAssertEqual(store.beginAutomaticRecoveryAttempt(identity: identityB,
                now: startedAt.addingTimeInterval(10)), 1)
            let attemptB = try XCTUnwrap(defaults.data(forKey: "\(prefix).automaticRecoveryAttempt.v2"))

            store.recordRunResult(.failed(errorCode: "TEST_LATE_CALLBACK_A",
                failure: AutomaticSyncFailure.http(status: 503)), now: startedAt.addingTimeInterval(20))

            XCTAssertEqual(defaults.data(forKey: "\(prefix).automaticRecoveryAttempt.v2"), attemptB,
                "Completion must correlate the exact claim, including when identity A equals B")
            XCTAssertEqual(store.automaticRecoveryAttemptEligibility(identity: identityB,
                now: startedAt.addingTimeInterval(86_400)), .exhausted)
        }
    }

    @MainActor
    func testOwnedStaleClaimCannotPublishOverSuccessorStateAndCurrentClaimCompletesOnce() throws {
        for reuseIdentity in [false, true] {
            let suiteName = "Task145OwnedStaleClaim-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defer { defaults.removePersistentDomain(forName: suiteName) }
            let prefix = "task145.owned-stale-claim"
            let store = SyncStateStore(defaults: defaults, keyPrefix: prefix, retryJitter: { 1 })
            let identityA = String(repeating: "a", count: 64)
            let identityB = reuseIdentity ? identityA : String(repeating: "b", count: 64)
            let startedAt = Date(timeIntervalSince1970: 120_000)
            let claimA = try XCTUnwrap(store.claimAutomaticRecoveryAttempt(identity: identityA, now: startedAt))
            if reuseIdentity { store.resetAutomaticRecoveryAttemptBudget() }
            let claimB = try XCTUnwrap(store.claimAutomaticRecoveryAttempt(identity: identityB,
                now: startedAt.addingTimeInterval(10)))
            store.recordRunResult(.failed(errorCode: "TEST_CURRENT_B"), preserveRecoveryRequired: true,
                now: startedAt.addingTimeInterval(11))
            let stateB = store.state
            let attemptB = try XCTUnwrap(defaults.data(forKey: "\(prefix).automaticRecoveryAttempt.v2"))

            store.recordRunResult(.failed(errorCode: "TEST_OWNED_LATE_A", failure: .http(status: 503)),
                preserveRecoveryRequired: true, automaticRecoveryClaim: claimA,
                now: startedAt.addingTimeInterval(20))

            XCTAssertEqual(store.state, stateB)
            XCTAssertEqual(defaults.string(forKey: "\(prefix).lastRunErrorCode"), "TEST_CURRENT_B")
            XCTAssertEqual(defaults.data(forKey: "\(prefix).automaticRecoveryAttempt.v2"), attemptB)
            XCTAssertFalse(store.ownsAutomaticRecoveryAttempt(claimA))
            XCTAssertTrue(store.ownsAutomaticRecoveryAttempt(claimB))
            store.recordRunResult(.failed(errorCode: "TEST_CURRENT_B_COMPLETED", failure: .http(status: 503)),
                preserveRecoveryRequired: true, automaticRecoveryClaim: claimB,
                now: startedAt.addingTimeInterval(21))
            XCTAssertEqual(store.automaticRecoveryAttemptEligibility(identity: identityB,
                now: startedAt.addingTimeInterval(21)), .cooldown(2))
            let completedB = store.state
            let completedBytes = defaults.data(forKey: "\(prefix).automaticRecoveryAttempt.v2")
            store.recordRunResult(.noWork(), automaticRecoveryClaim: claimB,
                now: startedAt.addingTimeInterval(30))
            XCTAssertEqual(store.state, completedB, "A duplicate completion cannot republish or change provenance")
            XCTAssertEqual(defaults.data(forKey: "\(prefix).automaticRecoveryAttempt.v2"), completedBytes)
        }
    }

    @MainActor
    func testAutomaticRecoveryIdentityStaysStableAcrossGenerationAndPhaseProgress() {
        let boundAt = Date(timeIntervalSince1970: 30_000)
        let storeIdentity = LocalStoreIdentity(
            rawValue: "shop-a",
            defaultStoreId: "default",
            localStoreId: "local-a",
            schemaVersion: 7,
            syncProtocolVersion: 9,
            storeEpoch: 3
        )
        let binding = AccountBinding(
            accountHash: String(repeating: "d", count: 64),
            storeIdentity: storeIdentity,
            boundAt: boundAt
        )
        let prepared = AccountRecoveryJournalSnapshot(
            replacement: binding,
            mode: .sameScopeRecovery,
            phase: .prepared,
            deviceIdentityHash: String(repeating: "e", count: 64),
            generationID: nil,
            checkpointDigest: nil,
            watermark: nil,
            baselineRunID: nil
        )
        let progressed = AccountRecoveryJournalSnapshot(
            replacement: binding,
            mode: .sameScopeRecovery,
            phase: .verified,
            deviceIdentityHash: String(repeating: "e", count: 64),
            generationID: UUID(),
            checkpointDigest: String(repeating: "f", count: 64),
            watermark: 42,
            baselineRunID: UUID()
        )
        XCTAssertEqual(
            SyncOrchestrator.automaticRecoveryResumeIdentity(for: prepared),
            SyncOrchestrator.automaticRecoveryResumeIdentity(for: progressed)
        )

        let nextJournal = AccountRecoveryJournalSnapshot(
            replacement: AccountBinding(
                accountHash: binding.accountHash,
                storeIdentity: binding.storeIdentity,
                boundAt: boundAt.addingTimeInterval(1)
            ),
            mode: prepared.mode,
            phase: .prepared,
            deviceIdentityHash: prepared.deviceIdentityHash,
            generationID: nil,
            checkpointDigest: nil,
            watermark: nil,
            baselineRunID: nil
        )
        XCTAssertNotEqual(
            SyncOrchestrator.automaticRecoveryResumeIdentity(for: prepared),
            SyncOrchestrator.automaticRecoveryResumeIdentity(for: nextJournal)
        )
    }

    @MainActor
    func testStateStorePersistsRecoveryRequiredAcrossNoOpAndRelaunch() async throws {
        let fixture = try await makeQualifiedSyncStateFixture()
        let defaults = fixture.defaults

        let store = SyncStateStore(defaults: defaults, keyPrefix: "task139", storeGenerationController: fixture.controller)
        store.recordRunResult(.recoveryRequired())

        XCTAssertEqual(store.state.phase, .recoveryRequired)
        XCTAssertEqual(store.state.lastOutcome, .noWork)
        XCTAssertEqual(defaults.string(forKey: "task139.phase"), "recoveryRequired")
        XCTAssertEqual(defaults.string(forKey: "task139.lastRunStatus"), "recoveryRequired")

        store.recordRunResult(.noWork())
        XCTAssertEqual(store.state.phase, .recoveryRequired)
        XCTAssertEqual(defaults.string(forKey: "task139.lastRunStatus"), "recoveryRequired")

        XCTAssertNil(defaults.object(forKey: "task139.lastRunObservation.v1"))
        let legacyBefore = defaults.dictionaryRepresentation() as NSDictionary
        let relaunched = SyncStateStore(defaults: defaults, keyPrefix: "task139", storeGenerationController: fixture.controller)
        XCTAssertEqual(relaunched.state.phase, .recoveryRequired)
        // The durable recovery latch survives; an unscoped raw outcome is history only.
        XCTAssertNil(relaunched.state.lastOutcome)
        XCTAssertEqual(defaults.dictionaryRepresentation() as NSDictionary, legacyBefore)

        relaunched.updatePhase(.reconciling)
        relaunched.recordRunResult(fixture.result)
        XCTAssertEqual(relaunched.state.phase, .idle)
    }

    @MainActor
    func testRecoveryOriginPreservesCancellationFailureAndBlockUntilVerifiedSuccess() async throws {
        let fixture = try await makeQualifiedSyncStateFixture()
        let defaults = fixture.defaults

        let store = SyncStateStore(defaults: defaults, keyPrefix: "task139.cancel", storeGenerationController: fixture.controller)
        store.recordRunResult(.recoveryRequired())
        store.updatePhase(.reconciling)
        store.recordRunResult(.cancelled(), preserveRecoveryRequired: true)

        XCTAssertEqual(store.state.phase, .recoveryRequired)
        XCTAssertEqual(store.state.lastOutcome, .cancelled)
        XCTAssertEqual(defaults.string(forKey: "task139.cancel.phase"), "recoveryRequired")
        XCTAssertEqual(defaults.string(forKey: "task139.cancel.lastRunStatus"), "cancelled")

        XCTAssertNil(defaults.object(forKey: "task139.cancel.lastRunObservation.v1"))
        let legacyBefore = defaults.dictionaryRepresentation() as NSDictionary
        let relaunched = SyncStateStore(defaults: defaults, keyPrefix: "task139.cancel", storeGenerationController: fixture.controller)
        XCTAssertEqual(relaunched.state.phase, .recoveryRequired)
        // Cancellation remains in raw history, without inventing current scoped provenance.
        XCTAssertNil(relaunched.state.lastOutcome)
        XCTAssertEqual(defaults.dictionaryRepresentation() as NSDictionary, legacyBefore)

        relaunched.updatePhase(.reconciling)
        relaunched.recordRunResult(
            .failed(errorCode: "verified_failure"),
            preserveRecoveryRequired: true
        )
        XCTAssertEqual(relaunched.state.phase, .recoveryRequired)
        XCTAssertEqual(relaunched.state.lastOutcome, .failed)

        relaunched.updatePhase(.checking)
        relaunched.recordRunResult(
            .blocked(.networkUnavailable),
            preserveRecoveryRequired: true
        )
        XCTAssertEqual(relaunched.state.phase, .recoveryRequired)
        XCTAssertEqual(relaunched.state.lastOutcome, .blocked(.networkUnavailable))

        relaunched.updatePhase(.reconciling)
        relaunched.recordRunResult(
            fixture.result,
            preserveRecoveryRequired: true
        )
        XCTAssertEqual(relaunched.state.phase, .idle)
        XCTAssertEqual(relaunched.state.lastOutcome, .succeeded)
    }

    @MainActor
    func testDurableRecoveryJournalDominatesEveryNonTerminalResultAndRelaunch() async throws {
        let fixture = try await makeQualifiedSyncStateFixture()
        let defaults = fixture.defaults
        let origin = try XCTUnwrap(fixture.result.verifiedFinalization)
        let journalStore = AccountBindingStore(defaults: defaults)
        XCTAssertTrue(journalStore.beginReplacement(
            accountHash: origin.accountHash,
            storeIdentity: origin.storeIdentity
        ))
        let store = SyncStateStore(
            defaults: defaults,
            keyPrefix: "task139.journal",
            storeGenerationController: fixture.controller
        )

        XCTAssertEqual(store.state.phase, .recoveryRequired)
        for result: SyncAutomaticRunResult in [
            .noWork(),
            .cancelled(),
            .failed(errorCode: "redacted"),
            .blocked(.networkUnavailable),
            .busy(),
            .scheduledRetry(after: 1),
            .success(didWork: true)
        ] {
            store.updatePhase(.reconciling)
            store.recordRunResult(result)
            XCTAssertEqual(store.state.phase, .recoveryRequired)
        }

        let relaunched = SyncStateStore(
            defaults: defaults,
            keyPrefix: "task139.journal",
            storeGenerationController: fixture.controller
        )
        XCTAssertEqual(relaunched.state.phase, .recoveryRequired)

        journalStore.clearPendingReplacement()
        relaunched.updatePhase(.reconciling)
        relaunched.recordRunResult(fixture.result)
        XCTAssertEqual(relaunched.state.phase, .idle)
        XCTAssertEqual(relaunched.state.lastOutcome, .succeeded)
    }

    @MainActor
    func testLegacyOrCorruptTerminalObservationCannotHydrateForeignOutcomeAfterResolvedAccountSwitch() async throws {
        for mutation in ["missing", "corrupt"] {
            let ownerA = UUID()
            let fixture = try makeAutomaticScopeFixture(ownerUserID: ownerA)
            defer { fixture.cleanup() }
            let deviceID = DeviceInstallIDStore(defaults: fixture.defaults).deviceInstallID
            XCTAssertEqual(try DeviceInstallIDStore(defaults: fixture.defaults).requireDeviceInstallID(), deviceID)
            let completedAt = Date(timeIntervalSince1970: 2_000)
            let engine = AutomaticSyncEngine(catalogPushProvider: nil, productPriceProvider: nil,
                historySessionProvider: nil, incrementalPullProvider: nil,
                activityRegistrationProvider: nil, defaults: fixture.defaults, now: { completedAt })
            let resultA = await engine.run(action: .blocked(.networkUnavailable),
                source: .foregroundPoll, ownerUserID: ownerA)
            XCTAssertEqual(resultA.status, .blocked, mutation)
            XCTAssertEqual(resultA.blockReason, .networkUnavailable, mutation)
            let observationA = try XCTUnwrap(resultA.observation)
            XCTAssertEqual(observationA.origin.accountHash, AccountBindingStore.accountHash(for: ownerA), mutation)
            XCTAssertEqual(observationA.origin.shopID, fixture.shopID, mutation)
            XCTAssertEqual(observationA.completedAt, completedAt.timeIntervalSince1970, mutation)
            let stateA = SyncStateStore(defaults: fixture.defaults)
            stateA.recordRunResult(resultA, now: completedAt)
            XCTAssertEqual(stateA.state.phase, .blocked(.networkUnavailable), mutation)
            XCTAssertEqual(stateA.state.lastOutcome, .blocked(.networkUnavailable), mutation)
            let key = "sync.runtime.orchestrator.lastRunObservation.v1"
            _ = try XCTUnwrap(fixture.defaults.data(forKey: key))
            if mutation == "missing" { fixture.defaults.removeObject(forKey: key) }
            else { fixture.defaults.set(Data("invalid-observation-envelope".utf8), forKey: key) }

            let ownerB = UUID()
            let accountB = AccountBindingStore.accountHash(for: ownerB)
            let shopB = SelectedShop(shopID: UUID(), code: "TASK145B", name: "Resolved B fixture",
                role: "owner", status: "active", selectable: true, canWrite: true)
            let selection = SelectedShopStore(defaults: fixture.defaults)
            selection.noteActiveAccount(accountB)
            XCTAssertTrue(selection.save(shopB, accountHash: accountB), mutation)
            XCTAssertTrue(AccountBindingStore(defaults: fixture.defaults).saveBinding(
                accountHash: accountB, storeIdentity: shopB.localStoreIdentity), mutation)
            let scopeB = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: ownerB, defaults: fixture.defaults)
            XCTAssertEqual(scopeB.accountHash, accountB, mutation)
            XCTAssertEqual(scopeB.shopID, shopB.shopID, mutation)
            XCTAssertTrue(scopeB.storeIdentity.hasSameProvenance(as: shopB.localStoreIdentity), mutation)
            XCTAssertNotEqual(scopeB.accountHash, observationA.origin.accountHash, mutation)
            let rawBefore = fixture.defaults.dictionaryRepresentation() as NSDictionary
            let envelopeBefore = fixture.defaults.data(forKey: key)
            let reopened = SyncStateStore(defaults: fixture.defaults)
            XCTAssertNil(AccountBindingStore(defaults: fixture.defaults).pendingRecoveryJournal, mutation)
            XCTAssertEqual(reopened.state.phase, .idle, mutation)
            XCTAssertNil(reopened.state.lastOutcome, mutation)
            XCTAssertNil(reopened.state.startedAt, mutation)
            let diagnostics = AutomaticSyncDiagnosticsSnapshot(syncState: reopened.state, pendingCount: 0,
                baselineSummary: .absent, ownerUserID: ownerB, defaults: fixture.defaults)
            XCTAssertNil(diagnostics.lastError, mutation)
            XCTAssertNil(diagnostics.errorObservedAt, mutation)
            XCTAssertNil(SyncStateStore.currentRunObservation(defaults: fixture.defaults, ownerUserID: ownerB), mutation)
            XCTAssertEqual(fixture.defaults.string(forKey: "sync.runtime.orchestrator.lastRunStatus"), "blocked", mutation)
            XCTAssertEqual(fixture.defaults.string(forKey: "sync.runtime.orchestrator.lastRunBlockReason"), "networkUnavailable", mutation)
            XCTAssertEqual(fixture.defaults.double(forKey: "sync.runtime.orchestrator.lastRunCompletedAt"), 2_000, mutation)
            XCTAssertEqual(fixture.defaults.data(forKey: key), envelopeBefore, mutation)
            XCTAssertEqual(fixture.defaults.dictionaryRepresentation() as NSDictionary, rawBefore,
                "Projection/reopen must preserve all legacy diagnostics and missing/corrupt envelope bytes: \(mutation)")
        }
    }

    @MainActor
    func testCurrentTypedTerminalObservationStillHydratesItsOriginalOutcomeAndTime() async throws {
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.cleanup() }
        let deviceID = DeviceInstallIDStore(defaults: fixture.defaults).deviceInstallID
        XCTAssertEqual(try DeviceInstallIDStore(defaults: fixture.defaults).requireDeviceInstallID(), deviceID)
        let completedAt = Date(timeIntervalSince1970: 2_000)
        let engine = AutomaticSyncEngine(catalogPushProvider: nil, productPriceProvider: nil,
            historySessionProvider: nil, incrementalPullProvider: nil,
            activityRegistrationProvider: nil, defaults: fixture.defaults, now: { completedAt })
        let result = await engine.run(action: .blocked(.networkUnavailable), source: .foregroundPoll, ownerUserID: owner)
        XCTAssertEqual(result.status, .blocked)
        let observation = try XCTUnwrap(result.observation)
        let state = SyncStateStore(defaults: fixture.defaults)
        state.recordRunResult(result, now: completedAt)
        let rawBefore = fixture.defaults.dictionaryRepresentation() as NSDictionary
        let reopened = SyncStateStore(defaults: fixture.defaults)
        XCTAssertEqual(reopened.state.phase, .blocked(.networkUnavailable))
        XCTAssertEqual(reopened.state.lastOutcome, .blocked(.networkUnavailable))
        XCTAssertEqual(reopened.state.lastProgressAt, completedAt)
        let current = try XCTUnwrap(SyncStateStore.currentRunObservation(defaults: fixture.defaults, ownerUserID: owner))
        XCTAssertEqual(current.invocationID, observation.invocationID)
        XCTAssertEqual(current.errorObservedAt, completedAt)
        let diagnostics = AutomaticSyncDiagnosticsSnapshot(syncState: reopened.state, pendingCount: 0,
            baselineSummary: .absent, ownerUserID: owner, defaults: fixture.defaults)
        XCTAssertEqual(diagnostics.lastError, "networkUnavailable")
        XCTAssertEqual(diagnostics.errorObservedAt, completedAt)
        XCTAssertEqual(fixture.defaults.dictionaryRepresentation() as NSDictionary, rawBefore)
    }

    @MainActor
    func testCurrentTypedNoWorkHydrationDoesNotBorrowOlderRawFailureAfterInterruptedPersistence() async throws {
        let failedAt = Date(timeIntervalSince1970: 2_000)
        let completedAt = Date(timeIntervalSince1970: 3_000)
        let fixture = try await makeObservedRecoveryFailureFixture(completedAt: failedAt)
        XCTAssertEqual(fixture.result.status, .failed)
        XCTAssertEqual(fixture.result.errorCode, "checkpoint_resource_exceeded")
        XCTAssertEqual(fixture.state.state.lastOutcome, .failed)
        let prefix = "sync.runtime.orchestrator"
        let rawKeys = ["phase", "lastRunStatus", "lastRunDidWork", "lastRunVerifiedConvergence",
            "lastRunCompletedAt", "lastRunErrorCode", "lastRunBlockReason", "activeStartedAt", "lastProgressAt"]
            .map { "\(prefix).\($0)" }
        let rawA = fixture.defaults.dictionaryRepresentation().filter { rawKeys.contains($0.key) }
        let engine = AutomaticSyncEngine(catalogPushProvider: nil, productPriceProvider: nil,
            historySessionProvider: nil, incrementalPullProvider: nil,
            activityRegistrationProvider: nil, defaults: fixture.defaults, now: { completedAt })
        let resultB = await engine.run(action: .noOp, source: .foregroundPoll, ownerUserID: fixture.ownerUserID)
        XCTAssertEqual(resultB.status, .noWork)
        let observationB = try XCTUnwrap(resultB.observation)
        XCTAssertEqual(observationB.completedAt, completedAt.timeIntervalSince1970)
        fixture.state.recordRunResult(resultB, now: completedAt)
        let acceptedB = try XCTUnwrap(SyncStateStore.currentRunObservation(defaults: fixture.defaults,
            ownerUserID: fixture.ownerUserID))
        XCTAssertEqual(acceptedB.invocationID, observationB.invocationID)
        XCTAssertEqual(acceptedB.status, .noWork)
        XCTAssertEqual(acceptedB.completedAt, completedAt.timeIntervalSince1970)
        let key = "\(prefix).lastRunObservation.v1"
        let typedB = try XCTUnwrap(fixture.defaults.data(forKey: key))
        // Simulate a crash after accepting the newer immutable envelope but
        // before applyRunResult replaces the prior raw diagnostics. The real
        // pending recovery journal remains intact throughout this scenario.
        for rawKey in rawKeys {
            if let value = rawA[rawKey] { fixture.defaults.set(value, forKey: rawKey) }
            else { fixture.defaults.removeObject(forKey: rawKey) }
        }
        XCTAssertEqual(fixture.defaults.string(forKey: "\(prefix).lastRunStatus"), "failed")
        XCTAssertEqual(fixture.defaults.string(forKey: "\(prefix).lastRunErrorCode"), "checkpoint_resource_exceeded")
        XCTAssertEqual(fixture.defaults.data(forKey: key), typedB)
        let rawBefore = fixture.defaults.dictionaryRepresentation() as NSDictionary
        let reopened = SyncStateStore(defaults: fixture.defaults, storeGenerationController: fixture.controller)
        let current = try XCTUnwrap(SyncStateStore.currentRunObservation(defaults: fixture.defaults,
            ownerUserID: fixture.ownerUserID))
        XCTAssertEqual(current.invocationID, observationB.invocationID)
        XCTAssertEqual(current.status, .noWork)
        XCTAssertEqual(current.completedAt, completedAt.timeIntervalSince1970)
        XCTAssertTrue(reopened.recoveryJournalIsPending, "A current noWork result cannot clear the actual recovery latch")
        XCTAssertEqual(reopened.state.phase, .recoveryRequired)
        XCTAssertEqual(reopened.state.lastOutcome, .noWork,
            "Hydration must derive current outcome from typed B rather than raw failure A")
        XCTAssertEqual(reopened.state.lastProgressAt, completedAt,
            "Hydration must retain B's original completion time, without borrowing A's raw completion")
        let diagnostics = AutomaticSyncDiagnosticsSnapshot(syncState: reopened.state, pendingCount: 0,
            baselineSummary: .absent, ownerUserID: fixture.ownerUserID, defaults: fixture.defaults)
        XCTAssertNil(diagnostics.lastError)
        XCTAssertNil(diagnostics.errorObservedAt)
        XCTAssertEqual(fixture.defaults.data(forKey: key), typedB)
        XCTAssertEqual(fixture.defaults.dictionaryRepresentation() as NSDictionary, rawBefore)
    }

    @MainActor
    func testStateStoreHydratesPersistedNetworkFailureWithoutRestoringActivePhase() async throws {
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.cleanup() }
        let defaults = fixture.defaults
        let deviceID = DeviceInstallIDStore(defaults: defaults).deviceInstallID
        XCTAssertEqual(try DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID(), deviceID)
        let completedAt = Date(timeIntervalSince1970: 120)
        let engine = AutomaticSyncEngine(catalogPushProvider: nil, productPriceProvider: nil,
            historySessionProvider: nil, incrementalPullProvider: nil,
            activityRegistrationProvider: nil, defaults: defaults, now: { completedAt })
        let result = await engine.run(action: .blocked(.networkUnavailable), source: .foregroundPoll, ownerUserID: owner)
        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.blockReason, .networkUnavailable)
        let observation = try XCTUnwrap(result.observation)
        XCTAssertEqual(observation.origin.accountHash, AccountBindingStore.accountHash(for: owner))
        XCTAssertEqual(observation.origin.shopID, fixture.shopID)
        XCTAssertEqual(observation.completedAt, completedAt.timeIntervalSince1970)
        let original = SyncStateStore(defaults: defaults, keyPrefix: "task136")
        original.recordRunResult(result, now: completedAt)
        // A stale active-phase marker cannot override the actual current typed block.
        defaults.set("pullingEvents", forKey: "task136.phase")
        defaults.set(100.0, forKey: "task136.activeStartedAt")
        let rawBefore = defaults.dictionaryRepresentation() as NSDictionary
        let store = SyncStateStore(defaults: defaults, keyPrefix: "task136")

        XCTAssertEqual(store.state.phase, .blocked(.networkUnavailable))
        XCTAssertEqual(store.state.lastOutcome, .blocked(.networkUnavailable))
        XCTAssertNil(store.state.startedAt)
        XCTAssertEqual(store.state.lastProgressAt, completedAt)
        let current = try XCTUnwrap(SyncStateStore.currentRunObservation(defaults: defaults,
            keyPrefix: "task136", ownerUserID: owner))
        XCTAssertEqual(current.invocationID, observation.invocationID)
        XCTAssertEqual(current.errorObservedAt, completedAt)
        XCTAssertEqual(defaults.dictionaryRepresentation() as NSDictionary, rawBefore)
    }

    func testAutomaticRuntimeSourceDoesNotExposeManualPushBoundary() throws {
        let runtime = try readSource("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRuntimeFacade.swift")
        let contentView = try readSource("iOSMerchandiseControl/ContentView.swift")
        let app = try readSource("iOSMerchandiseControl/iOSMerchandiseControlApp.swift")

        XCTAssertFalse(runtime.contains("SupabaseManualPushService"))
        XCTAssertFalse(runtime.contains("manualPushService"))
        XCTAssertFalse(runtime.contains("SyncCatalogPushAdapter"))
        XCTAssertFalse(runtime.contains("async -> Bool"))
        XCTAssertTrue(runtime.contains("SyncAutomaticRunResult"))

        XCTAssertFalse(contentView.contains("SupabaseManualPushService"))
        XCTAssertFalse(contentView.contains("manualPushService"))
        XCTAssertFalse(app.contains("SupabaseManualPushService"))
        XCTAssertFalse(app.contains("manualPushService"))
    }

    func testAutomaticSourceFilesDoNotReferenceManualDTOs() throws {
        let sources = try [
            "iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRuntimeFacade.swift",
            "iOSMerchandiseControl/Sync/Automatic/Composition/AutomaticSyncRuntimeFactory.swift",
            "iOSMerchandiseControl/Sync/SyncOrchestrator.swift",
            "iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxEnqueueService.swift",
            "iOSMerchandiseControl/Sync/Automatic/Presentation/AutomaticSyncReconnectScheduler.swift",
            "iOSMerchandiseControl/OptionsView.swift"
        ].map(readSource).joined(separator: "\n")

        for forbidden in [
            "ManualPushPlan",
            "SupabaseManualPushResult",
            "ProductPriceManualPushResult",
            "ProductPriceManualPushSnapshot",
            "ProductPriceManualPushSnapshotFactory",
            "SupabaseManualSync"
        ] {
            XCTAssertFalse(sources.contains(forbidden), "Forbidden automatic-domain symbol found: \(forbidden)")
        }
    }

    func testOptionsAndProvidersUseObserverOnlyContracts() throws {
        let options = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let provider = try readSource("iOSMerchandiseControl/Sync/Automatic/Presentation/OptionsSyncSummaryProvider.swift")
        let contracts = try [
            "iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift",
            "iOSMerchandiseControl/Sync/Automatic/Catalog/SyncCatalogPushModels.swift",
            "iOSMerchandiseControl/Sync/Automatic/ProductPrice/SyncProductPricePushModels.swift",
            "iOSMerchandiseControl/Sync/Automatic/History/SyncHistorySessionPushModels.swift",
            "iOSMerchandiseControl/Sync/Automatic/Outbox/SyncActivityRegistrationModels.swift"
        ].map(readSource).joined(separator: "\n")

        XCTAssertFalse(options.contains("CloudSyncProgressState.idle()"))
        XCTAssertTrue(options.contains("OptionsSyncSummaryProvider"))
        XCTAssertTrue(options.contains("SyncStatusPresenter"))
        XCTAssertFalse(provider.contains("SyncAutomaticRuntime"))
        XCTAssertFalse(contracts.contains("@MainActor\nprotocol SyncCatalogPushProviding"))
        XCTAssertFalse(contracts.contains("@MainActor\nprotocol SyncProductPriceSyncProviding"))
        XCTAssertFalse(contracts.contains("@MainActor\nprotocol SyncHistorySessionPushProviding"))
        XCTAssertFalse(contracts.contains("@MainActor\nprotocol SyncActivityRegistrationProviding"))
    }

    @MainActor
    func testCatalogPushServiceWritesAndAcknowledgesRequestedOwnerChanges() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let scopeFixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { scopeFixture.cleanup() }
        let otherOwner = UUID()
        let context = ModelContext(container)
        let supplier = Supplier(name: "TASK118 Supplier")
        let category = ProductCategory(name: "TASK118 Category")
        let product = Product(
            barcode: "TASK118-BAR",
            productName: "TASK118 Product",
            supplier: supplier,
            category: category
        )
        context.insert(supplier)
        context.insert(category)
        context.insert(product)
        context.insert(
            LocalPendingChange(
                ownerUserID: owner,
                storeId: scopeFixture.storeIdentity.storeId,
                localStoreId: scopeFixture.storeIdentity.localStoreId,
                entityKind: .product,
                operation: .update,
                origin: .manualCatalogSave,
                logicalKey: LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: product.barcode),
                changedFields: ["productName"]
            )
        )
        context.insert(
            LocalPendingChange(
                ownerUserID: otherOwner,
                entityKind: .supplier,
                operation: .update,
                origin: .manualCatalogSave,
                logicalKey: "supplier:other",
                changedFields: ["name"]
            )
        )
        try context.save()

        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: scopeFixture.shopID)
        let result = try await CatalogPushService(modelContainer: container, remote: remote, defaults: scopeFixture.defaults)
            .pushPendingCatalog(ownerUserID: owner)

        XCTAssertEqual(result.plan?.ownerUserID, owner)
        XCTAssertEqual(result.plan?.pendingChangeCount, 1)
        XCTAssertEqual(result.productCreates, 1)
        XCTAssertEqual(result.totalChanged, 1)
        let verifyContext = ModelContext(container)
        XCTAssertNotNil(try fetchProduct(barcode: "TASK118-BAR", context: verifyContext)?.remoteID)
        XCTAssertEqual(try activeChangeCount(context: verifyContext, ownerUserID: owner), 0)
        XCTAssertEqual(try activeChangeCount(context: verifyContext, ownerUserID: otherOwner), 1)
        let event = try fetchOutboxEntry(context: verifyContext, ownerUserID: owner, domain: "catalog")
        XCTAssertEqual(event?.eventType, "catalog_changed")
        XCTAssertEqual(event?.changedCount, 1)
        XCTAssertEqual(event?.status, .pending)
    }

    @MainActor
    func testCatalogCreateRetryAfterCommittedResponseLossReusesDeterministicID() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let scopeFixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { scopeFixture.cleanup() }
        let context = ModelContext(container)
        let product = Product(
            barcode: "TASK139-IDEMPOTENT-CREATE",
            productName: "Before response loss"
        )
        context.insert(product)
        try LocalPendingChangeAccumulator(
            context: context,
            ownerUserID: owner,
            storeIdentity: scopeFixture.storeIdentity
        ).recordProductChange(
            product: product,
            operation: .create,
            origin: .manualCatalogSave,
            changedFields: ["barcode", "productName"]
        )
        try context.save()
        let remote = Task118CatalogRemote(
            ownerUserID: owner,
            shopID: scopeFixture.shopID,
            failFirstProductCreateAfterCommit: true
        )
        let service = CatalogPushService(
            modelContainer: container,
            remote: remote,
            defaults: scopeFixture.defaults
        )

        do {
            _ = try await service.pushPendingCatalog(ownerUserID: owner)
            XCTFail("Expected simulated committed response loss")
        } catch Task118CatalogRemoteError.committedResponseLost {
            // Expected: remote row exists, local CAS/outbox transaction did not run.
        }
        let afterLoss = ModelContext(container)
        XCTAssertNil(try fetchProduct(
            barcode: "TASK139-IDEMPOTENT-CREATE",
            context: afterLoss
        )?.remoteID)
        XCTAssertEqual(try activeChangeCount(context: afterLoss, ownerUserID: owner), 1)
        XCTAssertNil(try fetchOutboxEntry(
            context: afterLoss,
            ownerUserID: owner,
            domain: "catalog"
        ))
        let rowsAfterLoss = remote.remoteProductRowCount()
        XCTAssertEqual(rowsAfterLoss, 1)

        let retried = try await service.pushPendingCatalog(ownerUserID: owner)
        let attemptedIDs = remote.attemptedProductIDs()
        let finalContext = ModelContext(container)
        let linkedID = try XCTUnwrap(fetchProduct(
            barcode: "TASK139-IDEMPOTENT-CREATE",
            context: finalContext
        )?.remoteID)

        XCTAssertEqual(retried.productCreates, 1)
        XCTAssertEqual(attemptedIDs.count, 2)
        XCTAssertEqual(Set(attemptedIDs), [linkedID])
        let rowsAfterRetry = remote.remoteProductRowCount()
        XCTAssertEqual(rowsAfterRetry, 1)
        XCTAssertEqual(try activeChangeCount(context: finalContext, ownerUserID: owner), 0)
        XCTAssertEqual(try fetchOutboxEntries(
            context: finalContext,
            ownerUserID: owner,
            domain: "catalog"
        ).count, 1)
    }

    @MainActor
    func testCatalogLostAckThenSecondSaveReopensAndReplaysOriginalPayloadBeforeLaterIntent() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("catalog.sqlite")
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.cleanup() }
        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: fixture.shopID,
                                          failFirstProductCreateAfterCommit: true)
        var originalID = ""
        var originalKey = ""
        var originalPayload: SyncAutomaticProductCreatePayload?
        var laterID = ""
        var laterKey = ""
        do {
            let container = try makeContainer(storeURL: storeURL)
            let context = ModelContext(container)
            let product = Product(barcode: "LOST-ACK-REOPEN", productName: "First durable intent")
            context.insert(product)
            let accumulator = LocalPendingChangeAccumulator(context: context, ownerUserID: owner,
                                                              storeIdentity: fixture.storeIdentity)
            let pending = try XCTUnwrap(accumulator.recordProductChange(product: product, operation: .create,
                origin: .manualCatalogSave, changedFields: ["barcode", "productName"]))
            originalID = pending.changeID; originalKey = pending.idempotencyKey
            try context.save()
            do {
                _ = try await CatalogPushService(modelContainer: container, remote: remote,
                    defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
                XCTFail("The server must commit the first body and lose its response")
            } catch Task118CatalogRemoteError.committedResponseLost {}
            originalPayload = try XCTUnwrap(remote.attemptedProductCreatePayloads().first)
            let edit = ModelContext(container)
            let current = try XCTUnwrap(fetchProduct(barcode: "LOST-ACK-REOPEN", context: edit))
            current.productName = "Later durable intent"
            let later = try XCTUnwrap(try LocalPendingChangeAccumulator(context: edit, ownerUserID: owner,
                storeIdentity: fixture.storeIdentity).recordProductChange(product: current, operation: .update,
                    origin: .manualCatalogSave, changedFields: ["productName"]))
            laterID = later.changeID; laterKey = later.idempotencyKey
            XCTAssertNotEqual(laterID, originalID)
            XCTAssertNotEqual(laterKey, originalKey)
            try edit.save()
        }
        let reopened = try makeContainer(storeURL: storeURL)
        let beforeRetry = ModelContext(reopened)
        let durableOriginal = try beforeRetry.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == originalID }
        XCTAssertEqual(durableOriginal?.idempotencyKey, originalKey)
        _ = try await CatalogPushService(modelContainer: reopened, remote: remote,
            defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
        let attempts = remote.attemptedProductCreatePayloads()
        XCTAssertGreaterThanOrEqual(attempts.count, 2)
        XCTAssertEqual(attempts.dropFirst().first, originalPayload,
                       "A retry must replay the first committed request, not the current local projection")
        let read = ModelContext(reopened)
        XCTAssertEqual(try fetchProduct(barcode: "LOST-ACK-REOPEN", context: read)?.productName, "Later durable intent")
        XCTAssertEqual(try activeChangeCount(context: read, ownerUserID: owner), 0)
        XCTAssertEqual(remote.remoteProductRowCount(), 1)
        XCTAssertEqual(remote.productUpdatePayloads().count, 1)
        XCTAssertEqual(remote.productUpdatePayloads().first?.productName, "Later durable intent")
        XCTAssertEqual(remote.persistedProductRow(id: try XCTUnwrap(originalPayload).id)?.productName, "Later durable intent")
        let pending = try read.fetch(FetchDescriptor<LocalPendingChange>())
        XCTAssertEqual(pending.first { $0.changeID == laterID }?.idempotencyKey, laterKey)
        XCTAssertEqual(pending.first { $0.changeID == laterID }?.status, .acknowledged)
        XCTAssertTrue(try read.fetch(FetchDescriptor<SyncEventOutboxEntry>()).filter(LocalPendingBusinessAttemptStore.isSealed).isEmpty)
        let attemptsBeforeRepeat = remote.attemptedProductIDs().count + remote.productUpdatePayloads().count
        _ = try await CatalogPushService(modelContainer: reopened, remote: remote,
            defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
        XCTAssertEqual(remote.attemptedProductIDs().count + remote.productUpdatePayloads().count, attemptsBeforeRepeat)
        XCTAssertEqual(try read.fetchCount(FetchDescriptor<ProductPrice>()), 0)
        XCTAssertEqual(try read.fetchCount(FetchDescriptor<HistoryEntry>()), 0)
    }

    @MainActor
    func testCatalogPushIsolatesBlockedSiblingAndStillPushesEligibleRow() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let scopeFixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { scopeFixture.cleanup() }
        let context = ModelContext(container)
        let product = Product(barcode: "TASK139-MIXED-CATALOG", productName: "Eligible")
        context.insert(product)
        context.insert(LocalPendingChange(
            ownerUserID: owner,
            storeId: scopeFixture.storeIdentity.storeId,
            localStoreId: scopeFixture.storeIdentity.localStoreId,
            entityKind: .product,
            operation: .update,
            status: .pending,
            origin: .manualCatalogSave,
            logicalKey: LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: product.barcode),
            changedFields: ["productName"]
        ))
        context.insert(LocalPendingChange(
            ownerUserID: owner,
            storeId: scopeFixture.storeIdentity.storeId,
            localStoreId: scopeFixture.storeIdentity.localStoreId,
            entityKind: .supplier,
            operation: .update,
            status: .blocked,
            origin: .manualCatalogSave,
            logicalKey: "supplier:blocked-sibling",
            changedFields: ["name"]
        ))
        try context.save()

        let result = try await CatalogPushService(
            modelContainer: container,
            remote: Task118CatalogRemote(ownerUserID: owner, shopID: scopeFixture.shopID),
            defaults: scopeFixture.defaults
        ).pushPendingCatalog(ownerUserID: owner)

        XCTAssertTrue(result.plan?.blockers.contains("blockedLocalChanges") == true)
        XCTAssertTrue(result.plan?.hasWork == true)
        XCTAssertEqual(result.productCreates, 1)
        XCTAssertEqual(try activeChangeCount(context: ModelContext(container), ownerUserID: owner), 1)
    }

    @MainActor
    func testCatalogPushServiceTombstonesHardDeletedProductFromPendingRemoteID() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let scopeFixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { scopeFixture.cleanup() }
        let remoteID = UUID()
        let context = ModelContext(container)
        let product = Product(
            barcode: "TASK135_DELETE_REMOTE",
            remoteID: remoteID,
            productName: "TASK135 Delete Remote"
        )
        let price = ProductPrice(
            remoteID: UUID(),
            type: .retail,
            price: 12.34,
            product: product
        )
        context.insert(product)
        context.insert(price)

        let accumulator = LocalPendingChangeAccumulator(
            context: context,
            ownerUserID: owner,
            storeIdentity: scopeFixture.storeIdentity
        )
        try accumulator.recordProductChange(
            product: product,
            operation: .delete,
            origin: .manualCatalogSave,
            changedFields: ["tombstone"],
            baselineFingerprintHash: LocalPendingChangeLogicalKey.productFingerprintHash(product)
        )
        context.delete(product)
        try context.save()

        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: scopeFixture.shopID)
        let result = try await CatalogPushService(modelContainer: container, remote: remote, defaults: scopeFixture.defaults)
            .pushPendingCatalog(ownerUserID: owner)

        XCTAssertEqual(result.productUpdates, 1)
        XCTAssertEqual(result.productCreates, 0)
        XCTAssertEqual(result.totalChanged, 1)
        let updatedProductIDs = remote.updatedProductIDs()
        let createdProductPayloadCount = remote.createdProductPayloadCount()
        XCTAssertEqual(updatedProductIDs, [remoteID])
        XCTAssertEqual(createdProductPayloadCount, 0)
        let payloads = remote.productUpdatePayloads()
        XCTAssertEqual(payloads.count, 1)
        XCTAssertNotNil(payloads.first?.deletedAt)

        let verifyContext = ModelContext(container)
        XCTAssertNil(try fetchProduct(barcode: "TASK135_DELETE_REMOTE", context: verifyContext))
        XCTAssertEqual(try activeChangeCount(context: verifyContext, ownerUserID: owner), 0)
        let snapshot = try LocalPendingChangeSnapshotProvider(context: verifyContext)
            .loadSnapshot(ownerUserID: owner)
        XCTAssertEqual(snapshot.pendingProductPriceChangeCount, 0)
        let event = try fetchOutboxEntry(context: verifyContext, ownerUserID: owner, domain: "catalog")
        XCTAssertEqual(event?.eventType, "catalog_tombstone")
        XCTAssertEqual(event?.changedCount, 1)

        let repeatResult = try await CatalogPushService(modelContainer: container, remote: remote, defaults: scopeFixture.defaults)
            .pushPendingCatalog(ownerUserID: owner)
        XCTAssertEqual(repeatResult.totalChanged, 0)
        let repeatedUpdatedProductIDs = remote.updatedProductIDs()
        XCTAssertEqual(repeatedUpdatedProductIDs, [remoteID])
        XCTAssertNil(try fetchProduct(barcode: "TASK135_DELETE_REMOTE", context: ModelContext(container)))
    }

    @MainActor
    func testCatalogPushServiceAcknowledgesLocalOnlyProductDeleteWithoutRemoteCall() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let scopeFixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { scopeFixture.cleanup() }
        let context = ModelContext(container)
        context.insert(
            LocalPendingChange(
                ownerUserID: owner,
                storeId: scopeFixture.storeIdentity.storeId,
                localStoreId: scopeFixture.storeIdentity.localStoreId,
                entityKind: .product,
                operation: .delete,
                origin: .manualCatalogSave,
                logicalKey: LocalPendingChangeLogicalKey.product(
                    remoteID: nil,
                    barcode: "TASK135_DELETE_LOCAL_ONLY"
                ),
                changedFields: ["tombstone"],
                entityRemoteID: nil
            )
        )
        try context.save()

        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: scopeFixture.shopID)
        let result = try await CatalogPushService(modelContainer: container, remote: remote, defaults: scopeFixture.defaults)
            .pushPendingCatalog(ownerUserID: owner)

        XCTAssertEqual(result.totalChanged, 0)
        let updatedProductIDs = remote.updatedProductIDs()
        let createdProductPayloadCount = remote.createdProductPayloadCount()
        XCTAssertTrue(updatedProductIDs.isEmpty)
        XCTAssertEqual(createdProductPayloadCount, 0)
        let verifyContext = ModelContext(container)
        XCTAssertEqual(try activeChangeCount(context: verifyContext, ownerUserID: owner), 0)
        XCTAssertNil(try fetchOutboxEntry(context: verifyContext, ownerUserID: owner, domain: "catalog"))
    }

    @MainActor
    func testCatalogPushServiceTombstonesHardDeletedSupplierAndCategoryFromPendingRemoteIDs() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let scopeFixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { scopeFixture.cleanup() }
        let supplierRemoteID = UUID()
        let categoryRemoteID = UUID()
        let context = ModelContext(container)
        let supplier = Supplier(name: "TASK069 Supplier Delete", remoteID: supplierRemoteID)
        let category = ProductCategory(name: "TASK069 Category Delete", remoteID: categoryRemoteID)
        context.insert(supplier)
        context.insert(category)
        let accumulator = LocalPendingChangeAccumulator(
            context: context,
            ownerUserID: owner,
            storeIdentity: scopeFixture.storeIdentity
        )
        try accumulator.recordSupplierChange(
            supplier: supplier,
            operation: .delete,
            origin: .manualCatalogSave,
            changedFields: ["tombstone"],
            baselineFingerprintHash: LocalPendingChangeLogicalKey.supplierFingerprintHash(supplier)
        )
        try accumulator.recordCategoryChange(
            category: category,
            operation: .delete,
            origin: .manualCatalogSave,
            changedFields: ["tombstone"],
            baselineFingerprintHash: LocalPendingChangeLogicalKey.categoryFingerprintHash(category)
        )
        context.delete(supplier)
        context.delete(category)
        try context.save()

        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: scopeFixture.shopID)
        let result = try await CatalogPushService(modelContainer: container, remote: remote, defaults: scopeFixture.defaults)
            .pushPendingCatalog(ownerUserID: owner)

        XCTAssertEqual(result.supplierUpdates, 1)
        XCTAssertEqual(result.categoryUpdates, 1)
        XCTAssertEqual(result.totalChanged, 2)
        let updatedSupplierIDs = remote.updatedSupplierIDs()
        let updatedCategoryIDs = remote.updatedCategoryIDs()
        let supplierPayloads = remote.supplierUpdatePayloads()
        let categoryPayloads = remote.categoryUpdatePayloads()
        XCTAssertEqual(updatedSupplierIDs, [supplierRemoteID])
        XCTAssertEqual(updatedCategoryIDs, [categoryRemoteID])
        XCTAssertNotNil(supplierPayloads.first?.deletedAt)
        XCTAssertNotNil(categoryPayloads.first?.deletedAt)

        let verifyContext = ModelContext(container)
        XCTAssertNil(try fetchSupplier(remoteID: supplierRemoteID, context: verifyContext))
        XCTAssertNil(try fetchCategory(remoteID: categoryRemoteID, context: verifyContext))
        XCTAssertEqual(try activeChangeCount(context: verifyContext, ownerUserID: owner), 0)
        let events = try fetchOutboxEntries(
            context: verifyContext,
            ownerUserID: owner,
            domain: "catalog"
        )
        XCTAssertEqual(Set(events.map(\.eventType)), ["catalog_tombstone"])
        XCTAssertEqual(events.reduce(0) { $0 + $1.changedCount }, 2)
    }

    @MainActor
    func testCatalogPushServiceUsesDistinctSyncEventIDsForLaterSingleChange() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let scopeFixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { scopeFixture.cleanup() }
        let remoteID = UUID()
        let context = ModelContext(container)
        let product = Product(
            barcode: "TASK135_EVENT_ID_REUSE",
            remoteID: remoteID,
            productName: "TASK135 Event ID Reuse"
        )
        context.insert(product)
        let accumulator = LocalPendingChangeAccumulator(
            context: context,
            ownerUserID: owner,
            storeIdentity: scopeFixture.storeIdentity
        )
        product.productName = "TASK135 Event ID Reuse Updated"
        try accumulator.recordProductChange(
            product: product,
            operation: .update,
            origin: .manualCatalogSave,
            changedFields: ["productName"],
            baselineFingerprintHash: nil
        )
        try context.save()

        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: scopeFixture.shopID)
        let first = try await CatalogPushService(modelContainer: container, remote: remote, defaults: scopeFixture.defaults)
            .pushPendingCatalog(ownerUserID: owner)
        XCTAssertEqual(first.totalChanged, 1)

        let deleteContext = ModelContext(container)
        let productToDelete = try XCTUnwrap(fetchProduct(barcode: "TASK135_EVENT_ID_REUSE", context: deleteContext))
        let deleteAccumulator = LocalPendingChangeAccumulator(
            context: deleteContext,
            ownerUserID: owner,
            storeIdentity: scopeFixture.storeIdentity
        )
        try deleteAccumulator.recordProductChange(
            product: productToDelete,
            operation: .delete,
            origin: .manualCatalogSave,
            changedFields: ["tombstone"],
            baselineFingerprintHash: LocalPendingChangeLogicalKey.productFingerprintHash(productToDelete)
        )
        try deleteAccumulator.supersedeProductPriceChanges(for: productToDelete)
        deleteContext.delete(productToDelete)
        try deleteContext.save()

        let second = try await CatalogPushService(modelContainer: container, remote: remote, defaults: scopeFixture.defaults)
            .pushPendingCatalog(ownerUserID: owner)
        XCTAssertEqual(second.totalChanged, 1)

        let verifyContext = ModelContext(container)
        let entries = try fetchOutboxEntries(context: verifyContext, ownerUserID: owner, domain: "catalog")
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(Set(entries.map(\.clientEventID)).count, 2)
        XCTAssertTrue(entries.contains { $0.eventType == "catalog_changed" })
        XCTAssertTrue(entries.contains { $0.eventType == "catalog_tombstone" })
    }

    @MainActor
    func testProductPricePushServiceWritesLinksAndAcknowledgesPendingPrice() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let scopeFixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { scopeFixture.cleanup() }
        let productID = UUID()
        let context = ModelContext(container)
        let product = Product(
            barcode: "TASK118-PRICE-BAR",
            remoteID: productID,
            productName: "TASK118 Price Product"
        )
        let price = ProductPrice(
            type: .retail,
            price: 12.34,
            effectiveAt: Date(timeIntervalSince1970: 1_700_000_000),
            product: product
        )
        context.insert(product)
        context.insert(price)
        context.insert(
            LocalPendingChange(
                ownerUserID: owner,
                storeId: scopeFixture.storeIdentity.storeId,
                localStoreId: scopeFixture.storeIdentity.localStoreId,
                entityKind: .productPrice,
                operation: .upsert,
                status: .pending,
                origin: .productPriceSave,
                logicalKey: LocalPendingChangeLogicalKey.productPrice(
                    productRemoteID: product.remoteID,
                    productBarcode: product.barcode,
                    type: price.type,
                    effectiveAt: price.effectiveAt
                ),
                changedFields: ["price"]
            )
        )
        try context.save()

        let remote = Task118ProductPriceRemote()
        let result = try await ProductPricePushService(modelContainer: container, remote: remote, defaults: scopeFixture.defaults)
            .pushPendingProductPrices(ownerUserID: owner)

        XCTAssertEqual(result.plan?.ownerUserID, owner)
        XCTAssertEqual(result.plan?.pendingChangeCount, 1)
        XCTAssertEqual(result.insertedCount, 1)
        XCTAssertEqual(result.orphanedCount, 0)
        XCTAssertEqual(result.tombstonedCount, 0)
        let verifyContext = ModelContext(container)
        XCTAssertNotNil(try fetchProductPrice(productBarcode: "TASK118-PRICE-BAR", context: verifyContext)?.remoteID)
        XCTAssertEqual(try activeChangeCount(context: verifyContext, ownerUserID: owner), 0)
        let event = try fetchOutboxEntry(context: verifyContext, ownerUserID: owner, domain: "prices")
        XCTAssertEqual(event?.eventType, "prices_changed")
        XCTAssertEqual(event?.changedCount, 1)
        XCTAssertEqual(event?.status, .pending)
        let eventEntry = try XCTUnwrap(event)
        let request = try SyncEventOutboxPayloadCodec.makeRecordRequestForReplay(
            from: eventEntry
        )
        let eventIDs = SyncEventEntityIDSet(json: request.entityIDs)
        XCTAssertTrue(eventIDs.isCompletePrices(changedCount: 1))
        XCTAssertEqual(eventIDs.productIDs, [productID])
    }

    @MainActor
    func testAutomaticOutboxRejectsMissingOrOverBudgetEntityIDsWithoutPartialEntry() throws {
        let container = try makeContainer()
        let owner = UUID()
        let scopeFixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { scopeFixture.cleanup() }
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: owner,
            defaults: scopeFixture.defaults
        )
        let context = ModelContext(container)

        XCTAssertThrowsError(
            try AutomaticSyncEventOutboxWriter.enqueue(
                context: context,
                ownerUserID: owner,
                domain: "history",
                eventType: "history_changed",
                changedCount: 1,
                entityIDs: .null,
                metadata: .object(["source": .string("unit")]),
                source: "unit",
                entityIDsShape: "null",
                metadataShape: "source=unit",
                clientEventFingerprint: "missing",
                scope: scope,
                defaults: scopeFixture.defaults
            )
        )

        let tooManyIDs = (0...250).map { _ in UUID() }
        XCTAssertThrowsError(
            try AutomaticSyncEventOutboxWriter.entityIDs([
                "session_ids": tooManyIDs
            ])
        )
        XCTAssertTrue(try context.fetch(FetchDescriptor<SyncEventOutboxEntry>()).isEmpty)
    }

    @MainActor
    func testProductPricePushIsolatesStaleSiblingAndStillPushesEligibleRow() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let scopeFixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { scopeFixture.cleanup() }
        let context = ModelContext(container)
        let product = Product(
            barcode: "TASK139-MIXED-PRICE",
            remoteID: UUID(),
            productName: "Eligible price"
        )
        let price = ProductPrice(
            type: .retail,
            price: 19.99,
            effectiveAt: Date(timeIntervalSince1970: 1_710_000_000),
            product: product
        )
        context.insert(product)
        context.insert(price)
        context.insert(LocalPendingChange(
            ownerUserID: owner,
            storeId: scopeFixture.storeIdentity.storeId,
            localStoreId: scopeFixture.storeIdentity.localStoreId,
            entityKind: .productPrice,
            operation: .upsert,
            status: .pending,
            origin: .productPriceSave,
            logicalKey: LocalPendingChangeLogicalKey.productPrice(
                productRemoteID: product.remoteID,
                productBarcode: product.barcode,
                type: price.type,
                effectiveAt: price.effectiveAt
            ),
            changedFields: ["price"]
        ))
        context.insert(LocalPendingChange(
            ownerUserID: owner,
            storeId: scopeFixture.storeIdentity.storeId,
            localStoreId: scopeFixture.storeIdentity.localStoreId,
            entityKind: .productPrice,
            operation: .upsert,
            status: .staleBaseline,
            origin: .productPriceSave,
            logicalKey: "productPrice:stale-sibling",
            changedFields: ["price"]
        ))
        try context.save()

        let result = try await ProductPricePushService(
            modelContainer: container,
            remote: Task118ProductPriceRemote(),
            defaults: scopeFixture.defaults
        ).pushPendingProductPrices(ownerUserID: owner)

        XCTAssertTrue(result.plan?.blockers.contains("staleBaselineLocalChanges") == true)
        XCTAssertTrue(result.plan?.hasWork == true)
        XCTAssertEqual(result.insertedCount, 1)
        XCTAssertEqual(try activeChangeCount(context: ModelContext(container), ownerUserID: owner), 1)
    }

    @MainActor
    func testProductPricePushServiceSupersedesPendingPriceAfterProductCascadeDelete() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let scopeFixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { scopeFixture.cleanup() }
        let context = ModelContext(container)
        let product = Product(
            barcode: "TASK135_PRICE_CASCADE_DELETE",
            remoteID: UUID(),
            productName: "TASK135 Price Cascade Delete"
        )
        let price = ProductPrice(
            type: .retail,
            price: 9.99,
            effectiveAt: Date(timeIntervalSince1970: 1_700_000_100),
            product: product
        )
        context.insert(product)
        context.insert(price)
        let accumulator = LocalPendingChangeAccumulator(
            context: context,
            ownerUserID: owner,
            storeIdentity: scopeFixture.storeIdentity
        )
        try accumulator.recordProductPriceChange(price: price, origin: .productPriceSave)
        context.delete(product)
        try context.save()

        let remote = Task118ProductPriceRemote()
        let result = try await ProductPricePushService(modelContainer: container, remote: remote, defaults: scopeFixture.defaults)
            .pushPendingProductPrices(ownerUserID: owner)

        XCTAssertEqual(result.insertedCount, 0)
        XCTAssertEqual(result.orphanedCount, 0)
        let insertCallCount = remote.insertCallCount()
        XCTAssertEqual(insertCallCount, 0)
        let verifyContext = ModelContext(container)
        XCTAssertEqual(try activeChangeCount(context: verifyContext, ownerUserID: owner), 0)
        let snapshot = try LocalPendingChangeSnapshotProvider(context: verifyContext)
            .loadSnapshot(ownerUserID: owner)
        XCTAssertEqual(snapshot.pendingProductPriceChangeCount, 0)
    }

    func testAutomaticRuntimeErrorDiagnosticsUseSharedRedaction() throws {
        let runtime = try readSource("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRuntimeFacade.swift")
        let engine = try readSource("iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift")
        let automaticRuntimeSources = runtime + "\n" + engine

        XCTAssertTrue(automaticRuntimeSources.contains("SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage"))
        XCTAssertFalse(automaticRuntimeSources.contains(#"with: "<UUID>""#))
    }

    func testBackgroundRunnerUsesDecisionEngineBeforeAutomaticRun() throws {
        let background = try readSource("iOSMerchandiseControl/Sync/Automatic/Background/SyncBackgroundTaskScheduler.swift")

        XCTAssertTrue(background.contains("SyncDecisionInputProvider"))
        XCTAssertTrue(background.contains("SyncDecisionEngine.decide"))
        XCTAssertTrue(background.contains("recoverySnapshotPullProvider: AtomicGenerationRecoverySnapshotPullService"))
        XCTAssertFalse(background.contains(".sequence([.pushPending, .drainEvents])"))
    }

    func testOptionsStatusCardReadsAutomaticRunOutcome() throws {
        let options = try readSource("iOSMerchandiseControl/OptionsView.swift")

        XCTAssertTrue(options.contains("syncState.lastOutcome"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.failed.detail"))
        XCTAssertTrue(options.contains("case .noWork where baselineSummary.status == .valid"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.noWork.detail"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.badge.retry"))
    }

    func testOptionsDiagnosticsStayCollapsedAndLabelCloudEventWarnings() throws {
        let options = try readSource("iOSMerchandiseControl/OptionsView.swift")

        XCTAssertTrue(options.contains("if isDiagnosticsExpanded {"))
        XCTAssertFalse(options.contains("if isDiagnosticsExpanded || isStalled {"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.cloudEventCheck.pending"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.badge.cloudEventsIncomplete"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.diagnostics.previousLastError"))
        XCTAssertTrue(options.contains("options.supabase.automaticSync.diagnostics.previousErrorNonBlocking"))
        XCTAssertTrue(options.contains("isTechnicalCloudEventNote"))
    }


    @MainActor
    func testDiagnosticsCurrentRecoveryErrorSupersedesHistoricalDebugError() async throws {
        let fixture = try await makeObservedRecoveryFailureFixture(completedAt: Date(timeIntervalSince1970: 2_000))
        fixture.defaults.set("old keyNotFound catalog", forKey: "sync.runtime.automatic.lastError")
        let snapshot = AutomaticSyncDiagnosticsSnapshot(syncState: fixture.state.state, pendingCount: 0,
            baselineSummary: .absent, ownerUserID: fixture.ownerUserID, defaults: fixture.defaults)
        XCTAssertEqual(snapshot.lastError, "checkpoint_resource_exceeded")
        XCTAssertFalse(snapshot.lastErrorText.contains("keyNotFound"))
        XCTAssertEqual(fixture.defaults.string(forKey: "sync.runtime.automatic.lastError"), "old keyNotFound catalog")
    }

    @MainActor
    func testDiagnosticsCurrentBlockAndSuccessNeverResurrectHistoricalError() async throws {
        let fixture = try await makeObservedDeviceBlockThenSuccessFixture()
        fixture.defaults.set("old keyNotFound catalog", forKey: "sync.runtime.automatic.lastError")
        let store = SyncStateStore(defaults: fixture.defaults, storeGenerationController: fixture.controller)
        store.recordRunResult(fixture.blocked, now: Date(timeIntervalSince1970: 2_000))
        let blocked = AutomaticSyncDiagnosticsSnapshot(syncState: store.state, pendingCount: 0,
            baselineSummary: .absent, ownerUserID: fixture.ownerUserID, defaults: fixture.defaults)
        XCTAssertEqual(blocked.lastError, "deviceNotActive")
        store.recordRunResult(fixture.success, now: Date(timeIntervalSince1970: 3_000))
        let success = AutomaticSyncDiagnosticsSnapshot(syncState: store.state, pendingCount: 0,
            baselineSummary: .absent, ownerUserID: fixture.ownerUserID, defaults: fixture.defaults)
        XCTAssertNil(success.lastError)
        XCTAssertFalse(success.hasLastError)
    }

    @MainActor
    func testDiagnosticsErrorKeepsItsCompletedTimestampDuringLaterProgress() async throws {
        let observedAt = Date(timeIntervalSince1970: 2_000)
        let fixture = try await makeObservedRecoveryFailureFixture(completedAt: observedAt)
        let store = fixture.state
        store.updatePhase(.checking, now: Date(timeIntervalSince1970: 8_000))
        let snapshot = AutomaticSyncDiagnosticsSnapshot(syncState: store.state, pendingCount: 0,
            baselineSummary: .absent, ownerUserID: fixture.ownerUserID, defaults: fixture.defaults)
        XCTAssertEqual(snapshot.lastErrorText, String(format: L("options.supabase.automaticSync.diagnostics.errorObserved"), "checkpoint_resource_exceeded", observedAt.formatted(date: .abbreviated, time: .shortened)))
    }

    @MainActor
    func testDiagnosticsErrorWithoutItsOwnTimestampDoesNotBorrowProgressTime() async throws {
        let fixture = try makeAutomaticScopeFixture(ownerUserID: UUID())
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        fixture.defaults.set("checkpoint_resource_exceeded", forKey: "sync.runtime.orchestrator.lastRunErrorCode")
        let bytesBefore = fixture.defaults.dictionaryRepresentation() as NSDictionary
        let snapshot = AutomaticSyncDiagnosticsSnapshot(syncState: SyncState(phase: .failed, lastProgressAt: Date(timeIntervalSince1970: 8_000)), pendingCount: 0, baselineSummary: .absent, defaults: fixture.defaults)
        XCTAssertNil(snapshot.lastError)
        XCTAssertNil(snapshot.errorObservedAt)
        XCTAssertEqual(fixture.defaults.string(forKey: "sync.runtime.orchestrator.lastRunErrorCode"), "checkpoint_resource_exceeded")
        XCTAssertEqual(fixture.defaults.dictionaryRepresentation() as NSDictionary, bytesBefore)
    }

    @MainActor
    func testScopedErrorObservationReplayAndOlderOrEqualCompletionsCannotReplaceCurrentOutcome() async throws {
        let fixture = try await makeObservedRecoveryFailureFixture(completedAt: Date(timeIntervalSince1970: 2_000))
        let key = "sync.runtime.orchestrator.lastRunObservation.v1"
        let original = try XCTUnwrap(fixture.result.observation)
        let firstBytes = try XCTUnwrap(fixture.defaults.data(forKey: key))
        fixture.state.recordRunResult(fixture.result, now: Date(timeIntervalSince1970: 8_000))
        XCTAssertEqual(fixture.defaults.data(forKey: key), firstBytes)
        XCTAssertEqual(SyncStateStore.currentRunObservation(defaults: fixture.defaults,
            ownerUserID: fixture.ownerUserID)?.errorObservedAt, Date(timeIntervalSince1970: 2_000))

        var altered = fixture.result
        altered.errorCode = "changed_same_invocation"
        altered.observation = SyncAutomaticRunObservation(schemaVersion: original.schemaVersion,
            invocationID: original.invocationID, origin: original.origin, status: original.status,
            errorCode: altered.errorCode, blockReason: original.blockReason,
            failure: original.failure, completedAt: original.completedAt)
        fixture.state.recordRunResult(altered)
        XCTAssertEqual(fixture.defaults.data(forKey: key), firstBytes)
        let completedB = Date(timeIntervalSince1970: 3_000)
        func newEngine() -> AutomaticSyncEngine {
            AutomaticSyncEngine(catalogPushProvider: nil, productPriceProvider: nil,
                historySessionProvider: nil, incrementalPullProvider: nil,
                activityRegistrationProvider: nil, defaults: fixture.defaults, now: { completedB })
        }
        let resultB = await newEngine().run(action: .noOp, source: .foregroundPoll, ownerUserID: fixture.ownerUserID)
        XCTAssertEqual(resultB.status, .noWork)
        XCTAssertNotEqual(resultB.observation?.invocationID, original.invocationID)
        fixture.state.recordRunResult(resultB)
        let acceptedB = try XCTUnwrap(fixture.defaults.data(forKey: key))
        XCTAssertNotEqual(acceptedB, firstBytes)
        XCTAssertNil(SyncStateStore.currentRunObservation(defaults: fixture.defaults,
            ownerUserID: fixture.ownerUserID)?.currentError)
        let beforeStale = fixture.defaults.dictionaryRepresentation() as NSDictionary
        fixture.state.recordRunResult(fixture.result, now: Date(timeIntervalSince1970: 9_000))
        XCTAssertEqual(fixture.defaults.dictionaryRepresentation() as NSDictionary, beforeStale)
        let equalTime = await newEngine().run(action: .noOp, source: .foregroundPoll, ownerUserID: fixture.ownerUserID)
        XCTAssertEqual(equalTime.observation?.completedAt, resultB.observation?.completedAt)
        XCTAssertNotEqual(equalTime.observation?.invocationID, resultB.observation?.invocationID)
        let beforeEqual = fixture.defaults.dictionaryRepresentation() as NSDictionary
        fixture.state.recordRunResult(equalTime)
        XCTAssertEqual(fixture.defaults.dictionaryRepresentation() as NSDictionary, beforeEqual)
        XCTAssertEqual(fixture.defaults.data(forKey: key), acceptedB)
    }

    @MainActor
    func testCorruptScopedObservationCannotBorrowLegacyErrorOrTimestamp() async throws {
        let fixture = try await makeObservedRecoveryFailureFixture(completedAt: Date(timeIntervalSince1970: 2_000))
        let key = "sync.runtime.orchestrator.lastRunObservation.v1"
        let validBytes = try XCTUnwrap(fixture.defaults.data(forKey: key))
        let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: validBytes) as? [String: Any])
        let originalOrigin = try XCTUnwrap(envelope["origin"] as? [String: Any])
        let originalIdentity = try XCTUnwrap(originalOrigin["storeIdentity"] as? [String: Any])
        for mutation in ["scalar", "missingEpoch", "emptyLocalStoreId"] {
            var changed = envelope
            var origin = originalOrigin
            if mutation == "scalar" {
                origin["storeIdentity"] = try XCTUnwrap(originalIdentity["rawValue"] as? String)
            } else {
                var identity = originalIdentity
                if mutation == "missingEpoch" { identity.removeValue(forKey: "storeEpoch") }
                else { identity["localStoreId"] = "" }
                origin["storeIdentity"] = identity
            }
            changed["origin"] = origin
            let bytes = try JSONSerialization.data(withJSONObject: changed)
            fixture.defaults.set(bytes, forKey: key)
            let snapshot = AutomaticSyncDiagnosticsSnapshot(syncState: fixture.state.state,
                pendingCount: 0, baselineSummary: .absent, ownerUserID: fixture.ownerUserID,
                defaults: fixture.defaults)
            XCTAssertNil(snapshot.lastError, mutation)
            XCTAssertNil(snapshot.errorObservedAt, mutation)
            XCTAssertEqual(fixture.defaults.data(forKey: key), bytes)
            XCTAssertEqual(fixture.defaults.string(forKey: "sync.runtime.orchestrator.lastRunErrorCode"), "checkpoint_resource_exceeded")
            XCTAssertEqual(fixture.defaults.double(forKey: "sync.runtime.orchestrator.lastRunCompletedAt"), 2_000)
        }
        fixture.defaults.set(validBytes, forKey: key)
        let origin = try XCTUnwrap(fixture.result.observation?.origin)
        let watermarks = WatermarkStore(defaults: fixture.defaults)
        let scope = WatermarkStore.Scope(accountHash: origin.accountHash, storeIdentity: origin.storeIdentity)
        XCTAssertEqual(watermarks.generationProvenance(for: scope), .absent)
        let corruptGeneration = Data("invalid-generation".utf8)
        fixture.defaults.set(corruptGeneration, forKey: watermarks.key(for: scope) + ".generation")
        XCTAssertEqual(watermarks.generationProvenance(for: scope), .invalid)
        XCTAssertNil(SyncStateStore.currentRunObservation(defaults: fixture.defaults, ownerUserID: fixture.ownerUserID))
        XCTAssertEqual(fixture.defaults.data(forKey: key), validBytes)
        XCTAssertEqual(fixture.defaults.data(forKey: watermarks.key(for: scope) + ".generation"), corruptGeneration)
    }

    @MainActor
    func testDiagnosticsUsesAuthenticatedResolvedShopInsteadOfHistoricalWatermark() async throws {
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        fixture.defaults.set(42, forKey: "sync.events.watermark.account.zzzz-historical.store.anonymous")
        let before = fixture.defaults.dictionaryRepresentation() as NSDictionary
        let snapshot = AutomaticSyncDiagnosticsSnapshot(syncState: SyncState(), pendingCount: 0, baselineSummary: .absent, ownerUserID: owner, defaults: fixture.defaults)
        XCTAssertEqual(snapshot.accountHash, String(AccountBindingStore.accountHash(for: owner).prefix(12)) + "...")
        XCTAssertEqual(snapshot.storeScope, String(fixture.storeIdentity.rawValue.prefix(12)) + "...")
        XCTAssertEqual(snapshot.shopSourceText, "TASK118 fixture shop")
        XCTAssertEqual(fixture.defaults.dictionaryRepresentation() as NSDictionary, before, "Diagnostics must not create device identity or mutate preferences")
    }

    @MainActor
    func testDiagnosticsCannotInferScopeWhenSignedOutUnresolvedOrAccountChanges() async throws {
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        fixture.defaults.set(42, forKey: "sync.events.watermark.account.zzzz-historical.store.anonymous")
        let signedOut = AutomaticSyncDiagnosticsSnapshot(syncState: SyncState(), pendingCount: 0, baselineSummary: .absent, defaults: fixture.defaults)
        XCTAssertNil(signedOut.accountHash)
        XCTAssertNil(signedOut.storeScope)
        let switched = AutomaticSyncDiagnosticsSnapshot(syncState: SyncState(), pendingCount: 0, baselineSummary: .absent, ownerUserID: UUID(), defaults: fixture.defaults)
        XCTAssertNil(switched.storeScope)
        SelectedShopStore(defaults: fixture.defaults).markResolutionUnresolved(accountHash: AccountBindingStore.accountHash(for: owner))
        let unresolved = AutomaticSyncDiagnosticsSnapshot(syncState: SyncState(), pendingCount: 0, baselineSummary: .absent, ownerUserID: owner, defaults: fixture.defaults)
        XCTAssertNil(unresolved.storeScope)
        XCTAssertNotEqual(unresolved.shopSourceText, L("options.supabase.automaticSync.diagnostics.ownerScope"))
    }

    private func makeAutomaticScopeFixture(
        ownerUserID: UUID
    ) throws -> Task118AutomaticScopeFixture {
        let suiteName = "Task118AutomaticScope-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        let selectedShop = SelectedShop(
            shopID: UUID(),
            code: "TASK118",
            name: "TASK118 fixture shop",
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true
        )
        let selectedStore = SelectedShopStore(defaults: defaults)
        selectedStore.noteActiveAccount(accountHash)
        XCTAssertTrue(selectedStore.save(selectedShop, accountHash: accountHash))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(
            accountHash: accountHash,
            storeIdentity: selectedShop.localStoreIdentity
        ))
        return Task118AutomaticScopeFixture(
            suiteName: suiteName,
            defaults: defaults,
            shopID: selectedShop.shopID,
            storeIdentity: selectedShop.localStoreIdentity
        )
    }

    private func readSource(_ relativePath: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func makeContainer(storeURL: URL? = nil) throws -> ModelContainer {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            HistoryEntry.self,
            ProductPrice.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self,
            SyncEventOutboxEntry.self,
            LocalPendingChange.self
        ])
        let configuration = storeURL.map { ModelConfiguration(schema: schema, url: $0) }
            ?? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        if storeURL == nil { Self.retainedContainers.append(container) }
        return container
    }

    private func activeChangeCount(context: ModelContext, ownerUserID: UUID) throws -> Int {
        let owner = ownerUserID.uuidString.lowercased()
        let descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.ownerUserID == owner
            }
        )
        return try context.fetch(descriptor).filter { !$0.status.isTerminal }.count
    }

    private func fetchProduct(barcode: String, context: ModelContext) throws -> Product? {
        var descriptor = FetchDescriptor<Product>(
            predicate: #Predicate<Product> { product in
                product.barcode == barcode
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func fetchProductPrice(productBarcode: String, context: ModelContext) throws -> ProductPrice? {
        try context.fetch(FetchDescriptor<ProductPrice>()).first {
            $0.product?.barcode == productBarcode
        }
    }

    private func fetchSupplier(remoteID: UUID, context: ModelContext) throws -> Supplier? {
        try context.fetch(FetchDescriptor<Supplier>()).first {
            $0.remoteID == remoteID
        }
    }

    private func fetchCategory(remoteID: UUID, context: ModelContext) throws -> ProductCategory? {
        try context.fetch(FetchDescriptor<ProductCategory>()).first {
            $0.remoteID == remoteID
        }
    }

    private func fetchOutboxEntry(
        context: ModelContext,
        ownerUserID: UUID,
        domain: String
    ) throws -> SyncEventOutboxEntry? {
        try fetchOutboxEntries(context: context, ownerUserID: ownerUserID, domain: domain).first
    }

    private func fetchOutboxEntries(
        context: ModelContext,
        ownerUserID: UUID,
        domain: String
    ) throws -> [SyncEventOutboxEntry] {
        let owner = ownerUserID.uuidString.lowercased()
        let descriptor = FetchDescriptor<SyncEventOutboxEntry>(
            predicate: #Predicate<SyncEventOutboxEntry> { entry in
                entry.ownerUserID == owner && entry.domain == domain
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }
}

private struct Task118AutomaticScopeFixture {
    let suiteName: String
    let defaults: UserDefaults
    let shopID: UUID
    let storeIdentity: LocalStoreIdentity

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private enum Task118CatalogRemoteError: Error {
    case committedResponseLost
}

@MainActor
private final class Task118CatalogRemote: SyncAutomaticCatalogRemoteWriting {
    private let ownerUserID: UUID
    private let shopID: UUID
    private let failFirstProductCreateAfterCommit: Bool
    private var didFailProductCreateAfterCommit = false
    private var createdProductPayloads: [SyncAutomaticProductCreatePayload] = []
    private var persistedProductRows: [UUID: RemoteInventoryProductRow] = [:]
    private var productCreateAttemptIDs: [UUID] = []
    private var supplierUpdateRequests: [(UUID, SyncAutomaticSupplierUpdatePayload)] = []
    private var categoryUpdateRequests: [(UUID, SyncAutomaticCategoryUpdatePayload)] = []
    private var productUpdateRequests: [(UUID, SyncAutomaticProductUpdatePayload)] = []

    init(
        ownerUserID: UUID,
        shopID: UUID,
        failFirstProductCreateAfterCommit: Bool = false
    ) {
        self.ownerUserID = ownerUserID
        self.shopID = shopID
        self.failFirstProductCreateAfterCommit = failFirstProductCreateAfterCommit
    }

    func createdProductPayloadCount() -> Int {
        createdProductPayloads.count
    }

    func attemptedProductCreatePayloads() -> [SyncAutomaticProductCreatePayload] {
        createdProductPayloads
    }

    func attemptedProductIDs() -> [UUID] {
        productCreateAttemptIDs
    }

    func remoteProductRowCount() -> Int {
        persistedProductRows.count
    }
    func persistedProductRow(id: UUID) -> RemoteInventoryProductRow? { persistedProductRows[id] }

    func updatedProductIDs() -> [UUID] {
        productUpdateRequests.map(\.0)
    }

    func productUpdatePayloads() -> [SyncAutomaticProductUpdatePayload] {
        productUpdateRequests.map(\.1)
    }

    func updatedSupplierIDs() -> [UUID] {
        supplierUpdateRequests.map(\.0)
    }

    func supplierUpdatePayloads() -> [SyncAutomaticSupplierUpdatePayload] {
        supplierUpdateRequests.map(\.1)
    }

    func updatedCategoryIDs() -> [UUID] {
        categoryUpdateRequests.map(\.0)
    }

    func categoryUpdatePayloads() -> [SyncAutomaticCategoryUpdatePayload] {
        categoryUpdateRequests.map(\.1)
    }

    func createSuppliers(_ payloads: [SyncAutomaticSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow] {
        payloads.map {
            RemoteInventorySupplierRow(
                id: $0.id,
                ownerUserID: $0.ownerUserID,
                shopID: $0.shopID,
                name: $0.name,
                updatedAt: "2026-05-24T00:00:00Z",
                deletedAt: nil
            )
        }
    }

    func updateSupplier(id: UUID, payload: SyncAutomaticSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow {
        supplierUpdateRequests.append((id, payload))
        return RemoteInventorySupplierRow(
            id: id,
            ownerUserID: ownerUserID,
            shopID: shopID,
            name: payload.name ?? "Deleted Supplier",
            updatedAt: "2026-05-24T00:00:00Z",
            deletedAt: payload.deletedAt
        )
    }

    func createCategories(_ payloads: [SyncAutomaticCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow] {
        payloads.map {
            RemoteInventoryCategoryRow(
                id: $0.id,
                ownerUserID: $0.ownerUserID,
                shopID: $0.shopID,
                name: $0.name,
                updatedAt: "2026-05-24T00:00:00Z",
                deletedAt: nil
            )
        }
    }

    func updateCategory(id: UUID, payload: SyncAutomaticCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow {
        categoryUpdateRequests.append((id, payload))
        return RemoteInventoryCategoryRow(
            id: id,
            ownerUserID: ownerUserID,
            shopID: shopID,
            name: payload.name ?? "Deleted Category",
            updatedAt: "2026-05-24T00:00:00Z",
            deletedAt: payload.deletedAt
        )
    }

    func createProducts(_ payloads: [SyncAutomaticProductCreatePayload]) async throws -> [RemoteInventoryProductRow] {
        createdProductPayloads.append(contentsOf: payloads)
        productCreateAttemptIDs.append(contentsOf: payloads.map(\.id))
        let rows = payloads.map {
            RemoteInventoryProductRow(
                id: $0.id,
                ownerUserID: $0.ownerUserID,
                shopID: $0.shopID,
                barcode: $0.barcode,
                itemNumber: $0.itemNumber,
                productName: $0.productName,
                secondProductName: $0.secondProductName,
                purchasePrice: $0.purchasePrice,
                retailPrice: $0.retailPrice,
                supplierID: $0.supplierID,
                categoryID: $0.categoryID,
                stockQuantity: $0.stockQuantity,
                updatedAt: "2026-05-24T00:00:00Z",
                deletedAt: nil
            )
        }
        for row in rows {
            persistedProductRows[row.id] = row
        }
        if failFirstProductCreateAfterCommit, !didFailProductCreateAfterCommit {
            didFailProductCreateAfterCommit = true
            throw Task118CatalogRemoteError.committedResponseLost
        }
        return rows
    }

    func updateProduct(id: UUID, payload: SyncAutomaticProductUpdatePayload) async throws -> RemoteInventoryProductRow {
        productUpdateRequests.append((id, payload))
        let existing = persistedProductRows[id]
        let row = RemoteInventoryProductRow(
            id: id,
            ownerUserID: ownerUserID,
            shopID: shopID,
            barcode: payload.barcode ?? existing?.barcode ?? "TASK118-BAR",
            itemNumber: payload.itemNumber ?? existing?.itemNumber,
            productName: payload.productName ?? existing?.productName,
            secondProductName: payload.secondProductName ?? existing?.secondProductName,
            purchasePrice: payload.purchasePrice ?? existing?.purchasePrice,
            retailPrice: payload.retailPrice ?? existing?.retailPrice,
            supplierID: payload.supplierID ?? existing?.supplierID,
            categoryID: payload.categoryID ?? existing?.categoryID,
            stockQuantity: payload.stockQuantity ?? existing?.stockQuantity,
            updatedAt: "2026-05-24T00:00:00Z",
            deletedAt: payload.deletedAt
        )
        persistedProductRows[id] = row
        return row
    }
}

@MainActor
private final class Task118ProductPriceRemote: SyncAutomaticProductPriceRemoteWriting {
    private var insertCalls = 0

    func insertCallCount() -> Int {
        insertCalls
    }

    func insertProductPrices(_ payloads: [SyncAutomaticProductPricePayload]) async throws -> [RemoteInventoryProductPriceRow] {
        insertCalls += 1
        return payloads.map {
            RemoteInventoryProductPriceRow(
                id: $0.id,
                ownerUserID: $0.ownerUserID,
                shopID: $0.shopID,
                productID: $0.productID,
                type: $0.type,
                price: $0.price,
                effectiveAt: $0.effectiveAt,
                source: $0.source,
                note: $0.note,
                createdAt: $0.createdAt,
                updatedAt: "2026-05-24T00:00:00Z"
            )
        }
    }
}
