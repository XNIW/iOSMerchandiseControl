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
            isAutomaticRuntimeRunning: true,
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
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertFalse(store.state.phase.isAutomaticWorkActive)
        XCTAssertEqual(store.state.lastVerifiedAt, verifiedAfterSuccess)
        XCTAssertEqual(store.state.lastOutcome, .busy)

        store.recordRunResult(.failed(errorCode: "unit"))
        XCTAssertEqual(store.state.phase, .failed)
        XCTAssertEqual(store.state.lastOutcome, .failed)

        store.recordRunResult(.cancelled())
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertEqual(store.state.lastOutcome, .cancelled)

        store.recordRunResult(.scheduledRetry())
        XCTAssertEqual(store.state.phase, .idle)
        XCTAssertFalse(store.state.phase.isAutomaticWorkActive)
        XCTAssertEqual(store.state.lastVerifiedAt, verifiedAfterSuccess)
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
        // This fixture writes only the product; its related parents already exist remotely.
        supplier.remoteID = UUID()
        category.remoteID = UUID()
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
    func testSealedCreateWithoutSupplierReplaysAfterLaterSaveAddsReliableSupplier() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("sealed-relation.sqlite")
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.cleanup() }
        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: fixture.shopID,
            failFirstProductCreateAfterCommit: true)
        let barcode = "T11-SEALED-A-RELATION-B"
        let supplierID = UUID()
        // The actual import create mask includes relation fields even when no relation exists.
        let importFields = ["barcode", "itemNumber", "productName", "secondProductName",
            "purchasePrice", "retailPrice", "stockQuantity", "supplierName", "categoryName"]
        var originalToken: LocalPendingChangeCASToken?
        var laterToken: LocalPendingChangeCASToken?
        var originalPayload: SyncAutomaticProductCreatePayload?
        var originalSeal = ""
        do {
            let container = try makeContainer(storeURL: storeURL)
            let context = ModelContext(container)
            let product = Product(barcode: barcode, productName: "Imported without a supplier")
            context.insert(product)
            let first = try XCTUnwrap(LocalPendingChangeAccumulator(context: context, ownerUserID: owner,
                storeIdentity: fixture.storeIdentity).recordProductChange(product: product, operation: .create,
                    origin: .confirmedImport, changedFields: importFields))
            let originalID = first.changeID
            try context.save()
            let before = ModelContext(container)
            let firstBody = try XCTUnwrap(fetchProduct(barcode: barcode, context: before))
            let firstChange = try XCTUnwrap(before.fetch(FetchDescriptor<LocalPendingChange>()).first)
            guard firstBody.supplier == nil, firstBody.category == nil, firstBody.remoteID == nil,
                  firstChange.changeID == originalID, firstChange.status == .pending,
                  firstChange.lastAttemptAt == nil, Set(firstChange.changedFields) == Set(importFields.map { $0.lowercased() }),
                  LocalPendingChangeScopeMatcher.matches(firstChange, ownerUserID: owner,
                    accountHash: AccountBindingStore.accountHash(for: owner), storeIdentity: fixture.storeIdentity)
            else { XCTFail("SEALED_RELATION_SETUP_NOT_QUALIFIED: A is not an ordinary scoped import create"); return }

            var responseLossObserved = false
            do {
                _ = try await CatalogPushService(modelContainer: container, remote: remote,
                    defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
            } catch Task118CatalogRemoteError.committedResponseLost { responseLossObserved = true }
            catch { XCTFail("SEALED_RELATION_SETUP_NOT_QUALIFIED: unexpected first error \(type(of: error))"); return }
            let afterLoss = ModelContext(container)
            let attempted = try XCTUnwrap(afterLoss.fetch(FetchDescriptor<LocalPendingChange>()).first)
            let payload = try XCTUnwrap(remote.attemptedProductCreatePayloads().first)
            let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner, defaults: fixture.defaults)
            let sealed = try XCTUnwrap(LocalPendingBusinessAttemptStore.load(Task118LegacyCatalogMutation.self,
                change: attempted, kind: "catalog", context: afterLoss, scope: scope))
            guard case .createProduct(let sealedPayload) = sealed.call,
                  responseLossObserved, remote.attemptedProductCreatePayloads().count == 1,
                  remote.remoteProductRowCount() == 1, payload.supplierID == nil, payload.categoryID == nil,
                  sealedPayload == payload, attempted.changeID == originalID,
                  attempted.lastAttemptAt != nil, attempted.status == .pending,
                  try fetchProduct(barcode: barcode, context: afterLoss)?.remoteID == nil,
                  try fetchOutboxEntries(context: afterLoss, ownerUserID: owner, domain: "catalog").isEmpty
            else { XCTFail("SEALED_RELATION_SETUP_NOT_QUALIFIED: no committed A with retained valid seal"); return }
            originalToken = LocalPendingChangeCASToken(attempted)
            originalPayload = payload
            originalSeal = try XCTUnwrap(fetchOutboxEntries(context: afterLoss, ownerUserID: owner,
                domain: LocalPendingBusinessAttemptStore.domain).first?.metadataPayloadJSON)

            let edit = ModelContext(container)
            let current = try XCTUnwrap(fetchProduct(barcode: barcode, context: edit))
            let supplier = Supplier(name: "Already remote supplier", remoteID: supplierID,
                remoteUpdatedAt: Date(timeIntervalSince1970: 1_700_000_000))
            edit.insert(supplier)
            current.supplier = supplier
            let later = try XCTUnwrap(LocalPendingChangeAccumulator(context: edit, ownerUserID: owner,
                storeIdentity: fixture.storeIdentity).recordProductChange(product: current, operation: .update,
                    origin: .manualCatalogSave, changedFields: ["supplierName"]))
            try edit.save()
            laterToken = LocalPendingChangeCASToken(later)
            let saved = ModelContext(container)
            let savedChanges = try saved.fetch(FetchDescriptor<LocalPendingChange>())
            let savedOriginal = try XCTUnwrap(savedChanges.first { $0.changeID == originalID })
            let savedLater = try XCTUnwrap(savedChanges.first { $0.changeID == later.changeID })
            guard savedChanges.count == 2, savedOriginal.changeID != savedLater.changeID,
                  savedOriginal.idempotencyKey != savedLater.idempotencyKey,
                  originalToken?.matches(savedOriginal) == true, savedLater.status == .pending,
                  savedLater.lastAttemptAt == nil,
                  savedLater.baselineFingerprintHash == savedOriginal.intendedFingerprintHash,
                  savedLater.intendedFingerprintHash != savedOriginal.intendedFingerprintHash,
                  try fetchProduct(barcode: barcode, context: saved)?.supplier?.remoteID == supplierID,
                  try fetchOutboxEntries(context: saved, ownerUserID: owner,
                    domain: LocalPendingBusinessAttemptStore.domain).first?.metadataPayloadJSON == originalSeal
            else { XCTFail("SEALED_RELATION_SETUP_NOT_QUALIFIED: B was not durably separated from A"); return }
        } // All models and contexts for the first file-backed container leave scope before reopen.

        let original = try XCTUnwrap(originalToken)
        let later = try XCTUnwrap(laterToken)
        let payload = try XCTUnwrap(originalPayload)
        let reopened = try makeContainer(storeURL: storeURL)
        let beforeRetry = ModelContext(reopened)
        let reopenedChanges = try beforeRetry.fetch(FetchDescriptor<LocalPendingChange>())
        let reopenedOriginal = try XCTUnwrap(reopenedChanges.first { $0.changeID == original.changeID })
        let reopenedLater = try XCTUnwrap(reopenedChanges.first { $0.changeID == later.changeID })
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner, defaults: fixture.defaults)
        let reopenedSeal = try LocalPendingBusinessAttemptStore.load(Task118LegacyCatalogMutation.self,
            change: reopenedOriginal, kind: "catalog", context: beforeRetry, scope: scope)
        guard original.matches(reopenedOriginal), later.matches(reopenedLater), reopenedSeal != nil,
              try fetchProduct(barcode: barcode, context: beforeRetry)?.supplier?.remoteID == supplierID,
              try fetchOutboxEntries(context: beforeRetry, ownerUserID: owner,
                domain: LocalPendingBusinessAttemptStore.domain).first?.metadataPayloadJSON == originalSeal
        else { XCTFail("SEALED_RELATION_SETUP_NOT_QUALIFIED: reopen changed A or B"); return }
        print("SEALED_RELATION_SETUP_QUALIFIED: committed A nil relation; distinct durable B reliable relation; exact A seal reopened")

        var replayResult: SyncCatalogPushResult?
        var replayError = "none"
        do {
            replayResult = try await CatalogPushService(modelContainer: reopened, remote: remote,
                defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
        } catch {
            replayError = error as? SyncStoreGenerationError == .activationReadBackFailed
                ? "activationReadBackFailed" : String(reflecting: type(of: error))
        } // Keep all replay/progress assertions reachable if the candidate rejects valid A.
        let read = ModelContext(reopened)
        let finalChanges = try read.fetch(FetchDescriptor<LocalPendingChange>())
        let finalOriginal = finalChanges.first { $0.changeID == original.changeID }
        let finalLater = finalChanges.first { $0.changeID == later.changeID }
        let body = try fetchProduct(barcode: barcode, context: read)
        let attempts = remote.attemptedProductCreatePayloads()
        let seals = try fetchOutboxEntries(context: read, ownerUserID: owner,
            domain: LocalPendingBusinessAttemptStore.domain)
        XCTAssertEqual(replayError, "none", "Valid A must not be rejected using the later B body")
        XCTAssertEqual(replayResult?.productCreates, 1)
        XCTAssertEqual(replayResult?.productUpdates, 1)
        XCTAssertEqual(attempts.count, 2, "A must be replayed once with its original deterministic identity")
        XCTAssertEqual(attempts.dropFirst().first, payload, "Replay must preserve the entire A payload")
        XCTAssertEqual(remote.productUpdatePayloads().count, 1, "B requires its own remote update")
        XCTAssertEqual(remote.updatedProductIDs(), [payload.id])
        XCTAssertEqual(remote.productUpdatePayloads().first?.supplierID, supplierID)
        XCTAssertEqual(remote.remoteProductRowCount(), 1)
        XCTAssertEqual(remote.persistedProductRow(id: payload.id)?.supplierID, supplierID)
        XCTAssertTrue(remote.attemptedSupplierCreatePayloads().isEmpty)
        XCTAssertEqual(finalChanges.count, 2)
        XCTAssertEqual(finalOriginal?.idempotencyKey, original.idempotencyKey)
        XCTAssertEqual(finalLater?.idempotencyKey, later.idempotencyKey)
        XCTAssertEqual(finalOriginal?.status, .acknowledged)
        XCTAssertEqual(finalLater?.status, .acknowledged)
        XCTAssertEqual(body?.remoteID, payload.id)
        XCTAssertEqual(body?.supplier?.remoteID, supplierID)
        XCTAssertEqual(body?.productName, payload.productName)
        XCTAssertTrue(seals.isEmpty, "Only the corresponding ACKs may retire A and B seals")
        XCTAssertEqual(try activeChangeCount(context: read, ownerUserID: owner), 0)
        let diagnostic: [String: Any] = [
            "setup_qualified": true, "replay_error": replayError,
            "original_change_id": original.changeID, "later_change_id": later.changeID,
            "original_seal_sha256": ShopSyncRecoveryCanonical.sha256(originalSeal),
            "retained_original_seal_unchanged": seals.first { $0.id == original.changeID }?.metadataPayloadJSON == originalSeal,
            "create_attempt_count": attempts.count, "update_attempt_count": remote.productUpdatePayloads().count,
            "remote_row_count": remote.remoteProductRowCount(),
            "original_status": finalOriginal?.statusRaw ?? "missing", "later_status": finalLater?.statusRaw ?? "missing",
            "original_key_preserved": finalOriginal?.idempotencyKey == original.idempotencyKey,
            "later_key_preserved": finalLater?.idempotencyKey == later.idempotencyKey,
            "local_supplier_is_b": body?.supplier?.remoteID == supplierID,
            "remote_supplier_is_b": remote.persistedProductRow(id: payload.id)?.supplierID == supplierID
        ]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: diagnostic,
            options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "T11-sealed-A-relation-B-replay"
        attachment.lifetime = .keepAlways
        add(attachment)
    }


    @MainActor
    func testInvalidPendingSupplierPreservesDependentProductAndAllowsIndependentProduct() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("t11-catalog.sqlite")
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.cleanup() }
        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: fixture.shopID)
        let invalidName = String(repeating: "X", count: 161)
        let expectedError = CatalogTextValidationError(field: .supplierName, reason: .tooLong)
        let dependentBarcode = "T11-DEPENDENT"
        let independentBarcode = "T11-INDEPENDENT"
        var original: [LocalPendingChangeCASToken] = []
        var observedErrors: [String] = []

        func drain(_ container: ModelContainer) async -> SyncCatalogPushResult? {
            do {
                return try await CatalogPushService(modelContainer: container, remote: remote,
                    defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
            } catch let error as CatalogTextValidationError {
                observedErrors.append("\(error.field.rawValue):\(error.reason.rawValue)")
                XCTAssertEqual(error, expectedError, "Unexpected typed error is not the proposed T11 failure")
            } catch {
                observedErrors.append(String(reflecting: type(of: error)))
                XCTFail("T11_UNEXPECTED_SERVICE_ERROR: \(type(of: error))")
            }
            return nil // Keep the independent-row assertions reachable after the real error.
        }

        func verify(_ container: ModelContainer, phase: String, result: SyncCatalogPushResult?) throws {
            let read = ModelContext(container)
            let suppliers = try read.fetch(FetchDescriptor<Supplier>())
            let changes = try read.fetch(FetchDescriptor<LocalPendingChange>())
            let dependent = try fetchProduct(barcode: dependentBarcode, context: read)
            let independent = try fetchProduct(barcode: independentBarcode, context: read)
            let supplier = suppliers.first
            let attempts = remote.attemptedProductCreatePayloads()
            let events = try fetchOutboxEntries(context: read, ownerUserID: owner, domain: "catalog")
            XCTAssertEqual(suppliers.count, 1, phase)
            XCTAssertEqual(try read.fetchCount(FetchDescriptor<Product>()), 2, phase)
            XCTAssertEqual(changes.count, 3, phase)
            XCTAssertEqual(supplier?.name, invalidName, phase)
            XCTAssertNil(supplier?.remoteID, phase)
            XCTAssertNotNil(dependent, phase)
            XCTAssertEqual(dependent?.productName, "Dependent intent", phase)
            XCTAssertNotNil(dependent?.supplier, phase)
            XCTAssertTrue(dependent?.supplier === supplier, phase)
            XCTAssertNil(dependent?.remoteID, phase)
            XCTAssertEqual(independent?.productName, "Independent intent", phase)
            XCTAssertNil(independent?.supplier, phase)
            XCTAssertNotNil(independent?.remoteID, "T11_INDEPENDENT_MUST_PROGRESS: \(phase)")
            XCTAssertTrue(remote.attemptedSupplierCreatePayloads().isEmpty, phase)
            XCTAssertTrue(remote.updatedSupplierIDs().isEmpty, phase)
            XCTAssertTrue(remote.updatedProductIDs().isEmpty, phase)
            XCTAssertEqual(attempts.filter { $0.barcode == dependentBarcode }.count, 0,
                           "The unresolved supplier must not silently become a nil remote relation")
            XCTAssertEqual(attempts.count, 1, "T11_INDEPENDENT_EXACTLY_ONE_CREATE: \(phase)")
            XCTAssertEqual(attempts.first?.barcode, independentBarcode, phase)
            XCTAssertEqual(attempts.first?.id, independent?.remoteID, phase)
            XCTAssertNil(attempts.first?.supplierID, phase)
            for token in original {
                let saved = changes.first { $0.changeID == token.changeID }
                XCTAssertNotNil(saved, phase)
                XCTAssertEqual(saved?.idempotencyKey, token.idempotencyKey, phase)
                XCTAssertEqual(saved?.ownerHash, token.ownerHash, phase)
                XCTAssertEqual(saved?.storeId, token.storeId, phase)
                XCTAssertEqual(saved?.localStoreId, token.localStoreId, phase)
                XCTAssertEqual(saved?.storeEpoch, token.storeEpoch, phase)
                if token.entityKindRaw == LocalPendingChangeEntityKind.supplier.rawValue
                    || token.logicalKey == LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: dependentBarcode) {
                    XCTAssertFalse(saved?.status.isTerminal ?? true, phase)
                    XCTAssertEqual(saved?.logicalKey, token.logicalKey, phase)
                    XCTAssertEqual(saved?.changedFieldsRaw, token.changedFieldsRaw, phase)
                    XCTAssertEqual(saved?.baselineFingerprintHash, token.baselineFingerprintHash, phase)
                    XCTAssertEqual(saved?.intendedFingerprintHash, token.intendedFingerprintHash, phase)
                    XCTAssertEqual(saved?.baseRemoteUpdatedAt, token.baseRemoteUpdatedAt, phase)
                    XCTAssertEqual(saved?.baseVersion, token.baseVersion, phase)
                    XCTAssertEqual(saved?.baseEventId, token.baseEventId, phase)
                    XCTAssertNil(saved?.entityRemoteID, phase)
                } else {
                    XCTAssertEqual(saved?.status, .acknowledged, "Only the independent intent may ACK: \(phase)")
                }
            }
            XCTAssertEqual(events.count, 1, "T11_INDEPENDENT_OWN_OUTBOX: \(phase)")
            if let result {
                let supplierID = try XCTUnwrap(original.first { $0.entityKindRaw == "supplier" }?.changeID)
                let dependentID = try XCTUnwrap(original.first {
                    $0.logicalKey == LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: dependentBarcode)
                }?.changeID)
                XCTAssertEqual(result.plan?.blockers.sorted(), [
                    "invalidCatalogText:\(supplierID):supplierName:too_long",
                    "unresolvedCatalogReference:\(dependentID):supplier"
                ].sorted(), "The same item diagnosis must be reproduced from persisted data after reopen")
                XCTAssertEqual(result.productCreates, phase == "after-first-drain" ? 1 : 0)
            }
            if let event = events.first, let remoteID = independent?.remoteID {
                let request = try SyncEventOutboxPayloadCodec.makeRecordRequestForReplay(from: event)
                XCTAssertEqual(request.changedCount, 1, phase)
                XCTAssertEqual(request.entityIDs, .object([
                    "product_ids": .array([.string(remoteID.uuidString.lowercased())])
                ]), phase)
                XCTAssertEqual(event.status, .pending, phase)
            }
            let diagnostic: [String: Any] = [
                "phase": phase, "observed_errors": observedErrors,
                "result_product_creates": result?.productCreates ?? -1,
                "result_blockers": result?.plan?.blockers ?? [],
                "supplier_create_count": remote.attemptedSupplierCreatePayloads().count,
                "product_attempts": attempts.map { ["id": $0.id.uuidString, "barcode": $0.barcode,
                    "supplier_id": $0.supplierID?.uuidString ?? "nil"] },
                "intents": changes.map { ["id": $0.changeID, "key": $0.idempotencyKey,
                    "kind": $0.entityKindRaw, "status": $0.statusRaw, "logical_key": $0.logicalKey] },
                "catalog_outbox_count": events.count
            ]
            let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: diagnostic,
                options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
            attachment.name = "T11-\(phase)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }

        do {
            let container = try makeContainer(storeURL: storeURL)
            let context = ModelContext(container)
            // Persisted legacy/corrupt data fixture, not a UI Save accepted by the accumulator.
            let supplier = Supplier(name: invalidName)
            let dependent = Product(barcode: dependentBarcode, productName: "Dependent intent", supplier: supplier)
            let independent = Product(barcode: independentBarcode, productName: "Independent intent")
            context.insert(supplier)
            context.insert(dependent)
            context.insert(independent)
            let rows: [(LocalPendingChangeEntityKind, String, [String], String)] = [
                (.supplier, LocalPendingChangeLogicalKey.supplier(remoteID: nil, name: invalidName),
                 ["name"], LocalPendingChangeLogicalKey.supplierFingerprintHash(supplier)),
                (.product, LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: dependentBarcode),
                 ["barcode", "productName", "supplier"], LocalPendingChangeLogicalKey.productFingerprintHash(dependent)),
                (.product, LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: independentBarcode),
                 ["barcode", "productName"], LocalPendingChangeLogicalKey.productFingerprintHash(independent))
            ]
            for (index, row) in rows.enumerated() {
                let time = Date(timeIntervalSince1970: 1_700_000_000 + Double(index))
                let change = LocalPendingChange(ownerUserID: owner,
                    ownerHash: AccountBindingStore.accountHash(for: owner),
                    storeId: fixture.storeIdentity.storeId, localStoreId: fixture.storeIdentity.localStoreId,
                    syncProtocolVersion: fixture.storeIdentity.syncProtocolVersion,
                    schemaVersion: fixture.storeIdentity.schemaVersion, storeEpoch: fixture.storeIdentity.storeEpoch,
                    entityKind: row.0, operation: .create, status: .pending, origin: .manualCatalogSave,
                    logicalKey: row.1, changedFields: row.2, intendedFingerprintHash: row.3,
                    createdAt: time, updatedAt: time)
                context.insert(change)
                original.append(LocalPendingChangeCASToken(change))
            }
            try context.save()
            let fresh = ModelContext(container)
            let persisted = try fresh.fetch(FetchDescriptor<LocalPendingChange>())
            let persistedSupplier = try XCTUnwrap(fresh.fetch(FetchDescriptor<Supplier>()).first)
            let persistedDependent = try XCTUnwrap(fetchProduct(barcode: dependentBarcode, context: fresh))
            let snapshot = try LocalPendingChangeSnapshotProvider(context: fresh)
                .loadSnapshot(ownerUserID: owner, storeIdentity: fixture.storeIdentity)
            var typedValidation: CatalogTextValidationError?
            do { _ = try CatalogTextPolicy.validate(persistedSupplier.name, for: .supplierName) }
            catch let error as CatalogTextValidationError { typedValidation = error }
            let qualified = typedValidation == expectedError && persisted.count == 3
                && snapshot.pendingCatalogChangeCount == 3 && Set(persisted.map(\.changeID)).count == 3
                && Set(persisted.map(\.idempotencyKey)).count == 3
                && persisted.allSatisfy { $0.status == .pending && LocalPendingChangeScopeMatcher.matches($0,
                    ownerUserID: owner, accountHash: AccountBindingStore.accountHash(for: owner),
                    storeIdentity: fixture.storeIdentity) }
                && persistedDependent.supplier === persistedSupplier
            guard qualified else { XCTFail("T11_SETUP_NOT_QUALIFIED"); return }
            print("T11_SETUP_QUALIFIED supplierName=tooLong; real dependency; 3 scoped pending intents")
            let firstResult = await drain(container)
            try verify(container, phase: "after-first-drain", result: firstResult)
        } // All first-container contexts/models leave scope before the file is reopened.
        let reopened = try makeContainer(storeURL: storeURL)
        try verify(reopened, phase: "reopened-before-second-drain", result: nil)
        let secondResult = await drain(reopened)
        try verify(reopened, phase: "reopened-after-second-drain", result: secondResult)
    }

    @MainActor
    func testInvalidSupplierIsolationDoesNotBypassCorruptSealedAttempt() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.cleanup() }
        let graph = try insertT11InvalidSupplierGraph(container: container, owner: owner, fixture: fixture)
        let context = ModelContext(container)
        let now = Date()
        let corrupt = SyncEventOutboxEntry(id: graph.supplierChangeID,
            ownerUserID: owner.uuidString.lowercased(), storeId: fixture.storeIdentity.storeId,
            localStoreId: fixture.storeIdentity.localStoreId, clientEventID: graph.supplierChangeID,
            batchID: graph.supplierChangeID, domain: LocalPendingBusinessAttemptStore.domain,
            eventType: "catalog", changedCount: 1, entityIDsShape: "corrupt-T11-hash",
            metadataShape: "sealed_business_attempt_v1", metadataPayloadJSON: "corrupt-T11-seal",
            status: .localOnly, nextRetryAt: now, createdAt: now, updatedAt: now,
            sourceDeviceID: try DeviceInstallIDStore(defaults: fixture.defaults).requireDeviceInstallID())
        context.insert(corrupt)
        try context.save()
        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: fixture.shopID)
        do {
            _ = try await CatalogPushService(modelContainer: container, remote: remote, defaults: fixture.defaults)
                .pushPendingCatalog(ownerUserID: owner)
            XCTFail("A corrupt seal must stop all sibling RPC")
        } catch { XCTAssertEqual(error as? SyncStoreGenerationError, .activationReadBackFailed) }
        XCTAssertTrue(remote.attemptedSupplierCreatePayloads().isEmpty)
        XCTAssertTrue(remote.attemptedProductCreatePayloads().isEmpty)
        let read = ModelContext(container)
        XCTAssertEqual(try read.fetch(FetchDescriptor<LocalPendingChange>()).map(\.status), [.pending, .pending, .pending])
        XCTAssertNil(try fetchProduct(barcode: graph.independentBarcode, context: read)?.remoteID)
        let sealed = try XCTUnwrap(fetchOutboxEntries(context: read, ownerUserID: owner,
            domain: LocalPendingBusinessAttemptStore.domain).first)
        XCTAssertEqual(sealed.metadataPayloadJSON, "corrupt-T11-seal")
        XCTAssertEqual(sealed.entityIDsShape, "corrupt-T11-hash")
        XCTAssertTrue(try fetchOutboxEntries(context: read, ownerUserID: owner, domain: "catalog").isEmpty)
    }

    @MainActor
    func testSealedNameOnlyUpdateReplaysWhileLaterRejectedSupplierEditRemainsPending() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.cleanup() }
        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: fixture.shopID,
            failFirstProductUpdateAfterCommit: true)
        let service = CatalogPushService(modelContainer: container, remote: remote, defaults: fixture.defaults)
        let barcode = "T11-UPDATE-MASK"
        let seed = ModelContext(container)
        let product = Product(barcode: barcode, productName: "Before A")
        seed.insert(product)
        try LocalPendingChangeAccumulator(context: seed, ownerUserID: owner, storeIdentity: fixture.storeIdentity)
            .recordProductChange(product: product, operation: .create, origin: .manualCatalogSave,
                changedFields: ["barcode", "productName"])
        try seed.save()
        let seeded = try await service.pushPendingCatalog(ownerUserID: owner)
        let editA = ModelContext(container)
        let bodyA = try XCTUnwrap(fetchProduct(barcode: barcode, context: editA))
        let remoteID = try XCTUnwrap(bodyA.remoteID)
        guard seeded.productCreates == 1, remote.remoteProductRowCount() == 1,
              try activeChangeCount(context: editA, ownerUserID: owner) == 0 else {
            XCTFail("UPDATE_MASK_SETUP_NOT_QUALIFIED: seed create has no actual ACK"); return
        }
        bodyA.productName = "Name A"
        let changeA = try XCTUnwrap(LocalPendingChangeAccumulator(context: editA, ownerUserID: owner,
            storeIdentity: fixture.storeIdentity).recordProductChange(product: bodyA, operation: .update,
                origin: .manualCatalogSave, changedFields: ["productName"]))
        let changeAID = changeA.changeID
        try editA.save()
        var lostResponse = false
        do { _ = try await service.pushPendingCatalog(ownerUserID: owner) }
        catch Task118CatalogRemoteError.committedResponseLost { lostResponse = true }
        catch { XCTFail("UPDATE_MASK_SETUP_NOT_QUALIFIED: unexpected first update error \(type(of: error))"); return }
        let afterLoss = ModelContext(container)
        let attemptedA = try XCTUnwrap(afterLoss.fetch(FetchDescriptor<LocalPendingChange>()).first {
            $0.changeID == changeAID
        })
        let payloadA = try XCTUnwrap(remote.productUpdatePayloads().first)
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner, defaults: fixture.defaults)
        let sealedA = try XCTUnwrap(LocalPendingBusinessAttemptStore.load(Task118LegacyCatalogMutation.self,
            change: attemptedA, kind: "catalog", context: afterLoss, scope: scope))
        guard case .updateProduct(let sealedID, let sealedPayload) = sealedA.call,
              lostResponse, remote.productUpdatePayloads().count == 1,
              sealedID == remoteID, sealedPayload == payloadA,
              Set(attemptedA.changedFields) == ["productname"], attemptedA.status == .pending,
              attemptedA.lastAttemptAt != nil, payloadA.productName == "Name A", payloadA.supplierID == nil,
              remote.persistedProductRow(id: remoteID)?.productName == "Name A" else {
            XCTFail("UPDATE_MASK_SETUP_NOT_QUALIFIED: A is not committed name-only with retained seal"); return
        }
        let tokenA = LocalPendingChangeCASToken(attemptedA)
        let editB = ModelContext(container)
        let bodyB = try XCTUnwrap(fetchProduct(barcode: barcode, context: editB))
        let supplier = Supplier(name: String(repeating: "X", count: 161))
        editB.insert(supplier)
        // A direct fixture represents legacy invalid data; the normal supplier Save rejects it.
        let supplierChange = LocalPendingChange(ownerUserID: owner,
            ownerHash: AccountBindingStore.accountHash(for: owner),
            storeId: fixture.storeIdentity.storeId, localStoreId: fixture.storeIdentity.localStoreId,
            syncProtocolVersion: fixture.storeIdentity.syncProtocolVersion,
            schemaVersion: fixture.storeIdentity.schemaVersion, storeEpoch: fixture.storeIdentity.storeEpoch,
            entityKind: .supplier, operation: .create, status: .pending, origin: .manualCatalogSave,
            logicalKey: LocalPendingChangeLogicalKey.supplier(remoteID: nil, name: supplier.name),
            changedFields: ["name"], intendedFingerprintHash: LocalPendingChangeLogicalKey.supplierFingerprintHash(supplier))
        editB.insert(supplierChange)
        bodyB.supplier = supplier
        let changeB = try XCTUnwrap(LocalPendingChangeAccumulator(context: editB, ownerUserID: owner,
            storeIdentity: fixture.storeIdentity).recordProductChange(product: bodyB, operation: .update,
                origin: .manualCatalogSave, changedFields: ["supplierName"]))
        let tokenB = LocalPendingChangeCASToken(changeB)
        try editB.save()
        let saved = ModelContext(container)
        let savedA = try XCTUnwrap(saved.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == changeAID })
        let savedBody = try XCTUnwrap(fetchProduct(barcode: barcode, context: saved))
        var typedSupplierError: CatalogTextValidationError?
        do { _ = try CatalogTextPolicy.validate(try XCTUnwrap(savedBody.supplier).name, for: .supplierName) }
        catch let error as CatalogTextValidationError { typedSupplierError = error }
        guard tokenA.matches(savedA), tokenA.changeID != tokenB.changeID,
              tokenA.idempotencyKey != tokenB.idempotencyKey, savedBody.supplier?.remoteID == nil,
              typedSupplierError == .init(field: .supplierName, reason: .tooLong),
              try activeChangeCount(context: saved, ownerUserID: owner) == 3 else {
            XCTFail("UPDATE_MASK_SETUP_NOT_QUALIFIED: B or rejected supplier is not persisted independently"); return
        }
        let expectedBlockers = [
            "invalidCatalogText:\(supplierChange.changeID):supplierName:too_long",
            "unresolvedCatalogReference:\(changeB.changeID):supplier"
        ].sorted()
        for pass in 0..<2 {
            let result = try await service.pushPendingCatalog(ownerUserID: owner)
            XCTAssertEqual(result.productUpdates, pass == 0 ? 1 : 0)
            XCTAssertEqual(result.plan?.blockers.sorted(), expectedBlockers)
            XCTAssertEqual(remote.productUpdatePayloads(), [payloadA, payloadA], "Replay uses A's exact mask and values")
            XCTAssertEqual(remote.attemptedProductCreatePayloads().count, 1)
            XCTAssertTrue(remote.attemptedSupplierCreatePayloads().isEmpty)
            let read = ModelContext(container)
            let changes = try read.fetch(FetchDescriptor<LocalPendingChange>())
            let retainedB = try XCTUnwrap(changes.first { $0.changeID == tokenB.changeID })
            XCTAssertEqual(changes.first { $0.changeID == changeAID }?.status, .acknowledged)
            XCTAssertEqual(retainedB.idempotencyKey, tokenB.idempotencyKey)
            XCTAssertEqual(retainedB.changedFieldsRaw, tokenB.changedFieldsRaw)
            XCTAssertEqual(retainedB.intendedFingerprintHash, tokenB.intendedFingerprintHash)
            XCTAssertNil(retainedB.lastAttemptAt, "B must not be sealed or sent while its supplier is unresolved")
            XCTAssertEqual(retainedB.status, .pending)
            XCTAssertEqual(changes.first { $0.changeID == supplierChange.changeID }?.status, .pending)
            XCTAssertEqual(try activeChangeCount(context: read, ownerUserID: owner), 2)
            let current = try XCTUnwrap(fetchProduct(barcode: barcode, context: read))
            XCTAssertEqual(current.productName, "Name A")
            XCTAssertEqual(current.supplier?.name, String(repeating: "X", count: 161))
            XCTAssertNil(current.supplier?.remoteID)
            XCTAssertNil(remote.persistedProductRow(id: remoteID)?.supplierID)
            XCTAssertTrue(try fetchOutboxEntries(context: read, ownerUserID: owner,
                domain: LocalPendingBusinessAttemptStore.domain).isEmpty)
            XCTAssertEqual(try fetchOutboxEntries(context: read, ownerUserID: owner, domain: "catalog").count, 2)
        }
    }

    @MainActor
    func testSealedDependencyOnRejectedSupplierStaysPendingWhileIndependentProductProgresses() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.cleanup() }
        let graph = try insertT11InvalidSupplierGraph(container: container, owner: owner, fixture: fixture)
        let context = ModelContext(container)
        let product = try XCTUnwrap(fetchProduct(barcode: graph.dependentBarcode, context: context))
        let change = try XCTUnwrap(context.fetch(FetchDescriptor<LocalPendingChange>()).first {
            $0.changeID == graph.dependentChangeID
        })
        change.lastAttemptAt = Date()
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner, defaults: fixture.defaults)
        // Serialized legacy request: a structurally valid seal with an omitted unresolved relation.
        let payload = SyncAutomaticProductCreatePayload(id: UUID(), ownerUserID: owner,
            shopID: fixture.shopID, barcode: product.barcode, itemNumber: product.itemNumber,
            productName: product.productName, secondProductName: product.secondProductName,
            purchasePrice: product.purchasePrice, retailPrice: product.retailPrice,
            supplierID: nil, categoryID: nil, stockQuantity: product.stockQuantity)
        let stored = Task118LegacyCatalogMutation(call: .createProduct(payload),
            businessFingerprint: LocalPendingChangeLogicalKey.productFingerprintHash(product),
            isCreate: true, isTombstone: false)
        try LocalPendingBusinessAttemptStore.seal(stored, pending: LocalPendingChangeCASToken(change),
            kind: "catalog", context: context, scope: scope)
        XCTAssertNotNil(try LocalPendingBusinessAttemptStore.load(Task118LegacyCatalogMutation.self,
            change: change, kind: "catalog", context: context, scope: scope))
        let before = try XCTUnwrap(fetchOutboxEntries(context: context, ownerUserID: owner,
            domain: LocalPendingBusinessAttemptStore.domain).first?.metadataPayloadJSON)
        let token = LocalPendingChangeCASToken(change)
        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: fixture.shopID)
        let service = CatalogPushService(modelContainer: container, remote: remote, defaults: fixture.defaults)
        let expectedBlockers = [
            "invalidCatalogText:\(graph.supplierChangeID):supplierName:too_long",
            "unresolvedCatalogReference:\(graph.dependentChangeID):supplier"
        ].sorted()
        for pass in 0..<2 {
            let result = try await service.pushPendingCatalog(ownerUserID: owner)
            XCTAssertEqual(result.productCreates, pass == 0 ? 1 : 0)
            XCTAssertEqual(result.plan?.blockers.sorted(), expectedBlockers)
            XCTAssertEqual(remote.attemptedProductCreatePayloads().map(\.barcode), [graph.independentBarcode])
            XCTAssertTrue(remote.attemptedSupplierCreatePayloads().isEmpty)
            let read = ModelContext(container)
            let retained = try XCTUnwrap(read.fetch(FetchDescriptor<LocalPendingChange>()).first {
                $0.changeID == graph.dependentChangeID
            })
            XCTAssertTrue(token.matches(retained), "Suspension cannot rewrite the attempted identity or pretend ACK")
            XCTAssertEqual(try fetchOutboxEntries(context: read, ownerUserID: owner,
                domain: LocalPendingBusinessAttemptStore.domain).first?.metadataPayloadJSON, before)
            XCTAssertEqual(try read.fetch(FetchDescriptor<LocalPendingChange>()).filter { $0.status == .pending }.count, 2)
            XCTAssertNil(try fetchProduct(barcode: graph.dependentBarcode, context: read)?.remoteID)
            let independent = try XCTUnwrap(fetchProduct(barcode: graph.independentBarcode, context: read))
            let independentID = try XCTUnwrap(independent.remoteID)
            let independentIntent = try XCTUnwrap(read.fetch(FetchDescriptor<LocalPendingChange>()).first {
                $0.entityRemoteID == independentID
            })
            XCTAssertEqual(independentIntent.status, .acknowledged)
            XCTAssertEqual(try fetchOutboxEntries(context: read, ownerUserID: owner, domain: "catalog").count, 1)
        }
    }

    @MainActor
    func testInvalidSupplierPartialProgressKeepsAttentionAndIndependentSteps() async throws {
        let container = try makeContainer()
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.cleanup() }
        let graph = try insertT11InvalidSupplierGraph(container: container, owner: owner, fixture: fixture)
        let context = ModelContext(container)
        let dependent = try XCTUnwrap(fetchProduct(barcode: graph.dependentBarcode, context: context))
        let price = ProductPrice(type: .retail, price: 9.99,
            effectiveAt: Date(timeIntervalSince1970: 1_700_000_100), product: dependent)
        context.insert(price)
        try LocalPendingChangeAccumulator(context: context, ownerUserID: owner, storeIdentity: fixture.storeIdentity)
            .recordProductPriceChange(price: price, origin: .productPriceSave)
        try context.save()
        let catalogRemote = Task118CatalogRemote(ownerUserID: owner, shopID: fixture.shopID)
        let priceRemote = Task118ProductPriceRemote()
        let recorder = Task118T11EventRecorder(ownerUserID: owner)
        let incremental = Task118T11IncrementalRecorder()
        let engine = AutomaticSyncEngine(
            catalogPushProvider: CatalogPushService(modelContainer: container, remote: catalogRemote, defaults: fixture.defaults),
            productPriceProvider: ProductPricePushService(modelContainer: container, remote: priceRemote, defaults: fixture.defaults),
            historySessionProvider: nil, incrementalPullProvider: incremental,
            activityRegistrationProvider: SyncActivityRegistrationService(modelContainer: container,
                recorder: recorder, defaults: fixture.defaults), defaults: fixture.defaults)
        for attempt in 0..<2 {
            let result = await engine.run(action: .sequence([.pushPending, .drainEvents]),
                source: .foregroundPoll, ownerUserID: owner)
            XCTAssertEqual(result.status, .failed)
            XCTAssertEqual(result.errorCode, "catalog_local_changes_blocked")
            XCTAssertEqual(result.failure, AutomaticSyncFailure(disposition: .stable, category: .payload))
            XCTAssertEqual(result.didWork, attempt == 0)
            XCTAssertFalse(result.verifiedConvergence)
            XCTAssertNil(result.continuationReceipt)
            XCTAssertNil(result.verifiedFinalization)
            let state = SyncStateStore(defaults: fixture.defaults)
            state.recordRunResult(result)
            XCTAssertEqual(state.state.phase, .failed)
            XCTAssertNil(state.state.lastVerifiedAt)
            let reopened = SyncStateStore(defaults: fixture.defaults)
            XCTAssertEqual(reopened.state.phase, .failed)
            XCTAssertNil(reopened.state.lastVerifiedAt)
            XCTAssertEqual(fixture.defaults.string(forKey: "sync.runtime.orchestrator.lastRunErrorCode"),
                "catalog_local_changes_blocked")
            XCTAssertEqual(incremental.calls, attempt + 1, "The admitted incremental step must still run")
            XCTAssertEqual(recorder.requests.count, 1, "Pok notification must be sent exactly once")
            XCTAssertEqual(catalogRemote.attemptedProductCreatePayloads().map(\.barcode), [graph.independentBarcode])
            XCTAssertEqual(priceRemote.insertCallCount(), 0, "The existing price guard must hold the unresolved parent")
            let read = ModelContext(container)
            XCTAssertNil(try fetchProductPrice(productBarcode: graph.dependentBarcode, context: read)?.remoteID)
            XCTAssertEqual(try read.fetch(FetchDescriptor<LocalPendingChange>()).filter {
                $0.entityKind == .productPrice && $0.status == .pending
            }.count, 1)
            let independent = try XCTUnwrap(fetchProduct(barcode: graph.independentBarcode, context: read)?.remoteID)
            XCTAssertEqual(recorder.requests.first?.entityIDs,
                .object(["product_ids": .array([.string(independent.uuidString.lowercased())])]))
            XCTAssertEqual(try fetchOutboxEntries(context: read, ownerUserID: owner, domain: "catalog").map(\.status), [.sent])
            XCTAssertEqual(try read.fetch(FetchDescriptor<LocalPendingChange>()).filter { $0.status == .pending }.count, 3)
        }
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

    // R23: real writer services with controlled remote outcomes. These are
    // integration tests of durable client behavior, not backend acceptance.
    @MainActor
    func testR23ResolvedSuccessorUsesExactConditionalVersionAndAcknowledgesOnce() async throws {
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.cleanup() }
        let container = try makeContainer()
        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: fixture.shopID)
        let original = try await makeR23RejectedCatalogChange(container: container, fixture: fixture,
            owner: owner, remote: remote)
        let outcome = try resolveR23CatalogReview(original, choice: .selectedFields(values: original.desired,
            fields: ["productName"]), container: container)
        guard case .successorPending(let successorID) = outcome else { return XCTFail("Expected successor") }
        let before = try r23Token(successorID, container: container)
        let originalSeal = try r23Seal(original.changeID, container: container)
        let result = try await CatalogPushService(modelContainer: container, remote: remote,
            defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
        XCTAssertEqual(result.productUpdates, 1)
        XCTAssertEqual(remote.conditionalRequests.count, 1)
        let sent = try XCTUnwrap(remote.conditionalRequests.first)
        XCTAssertEqual(sent.id, original.snapshot.product.id)
        XCTAssertEqual(sent.version.expectedUpdatedAt, "2026-10-23T20:10:00.123456Z")
        XCTAssertNil(sent.version.expectedDeletedAt)
        XCTAssertEqual(sent.fields, ["productName"])
        XCTAssertEqual(sent.payload.productName, "Saved A")
        let after = try r23Token(successorID, container: container)
        XCTAssertEqual(after.statusRaw, LocalPendingChangeStatus.acknowledged.rawValue)
        XCTAssertEqual(after.idempotencyKey, before.idempotencyKey)
        XCTAssertEqual(after.changedFieldsRaw, before.changedFieldsRaw)
        XCTAssertEqual(try r23Token(original.changeID, container: container), original.pending)
        XCTAssertEqual(try r23Seal(original.changeID, container: container), originalSeal)
        XCTAssertNil(try LocalPendingBusinessAttemptStore.entry(changeID: successorID, context: ModelContext(container)))
        XCTAssertEqual(try fetchOutboxEntries(context: ModelContext(container), ownerUserID: owner, domain: "catalog").count, 1)
        XCTAssertEqual(try LocalPendingChangeSnapshotProvider(context: ModelContext(container)).loadSnapshot(
            ownerUserID: owner, storeIdentity: fixture.storeIdentity).pendingCatalogChangeCount, 0)
        _ = try await CatalogPushService(modelContainer: container, remote: remote,
            defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
        XCTAssertEqual(remote.conditionalRequests.count, 1, "Actual ACK excludes the successor from another dispatch")
    }

    @MainActor
    func testR23ConditionalCommitLostResponseReopensAndZeroReplayRemainsUnconfirmed() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("r23-conditional.sqlite")
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.cleanup() }
        var container = try makeContainer(storeURL: url)
        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: fixture.shopID)
        let original = try await makeR23RejectedCatalogChange(container: container, fixture: fixture,
            owner: owner, remote: remote)
        guard case .successorPending(let successorID) = try resolveR23CatalogReview(original,
            choice: .selectedFields(values: original.desired, fields: ["productName"]), container: container) else {
            return XCTFail("Expected successor")
        }
        remote.loseFirstConditionalResponse = true
        do {
            _ = try await CatalogPushService(modelContainer: container, remote: remote,
                defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
            XCTFail("Expected the controlled lost response")
        } catch Task118CatalogRemoteError.committedResponseLost {}
        let attempted = try r23Token(successorID, container: container)
        let sealed = try r23Seal(successorID, container: container)
        let first = try XCTUnwrap(remote.conditionalRequests.first)
        XCTAssertEqual(remote.persistedProductRow(id: original.snapshot.product.id)?.productName, "Saved A")
        container = try makeContainer(storeURL: url)
        do {
            _ = try await CatalogPushService(modelContainer: container, remote: remote,
                defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
            XCTFail("A zero-row CAS replay must remain unconfirmed")
        } catch {
            XCTAssertEqual(String(describing: error), "conditionalWriteUnconfirmed")
        }
        XCTAssertEqual(remote.conditionalRequests, [first, first], "The replay retains all raw predicates, values and fields")
        XCTAssertEqual(remote.conditionalReturnCounts, [1, 0])
        container = try makeContainer(storeURL: url)
        XCTAssertEqual(try r23Token(successorID, container: container), attempted)
        XCTAssertEqual(try r23Seal(successorID, container: container), sealed)
        XCTAssertEqual(try r23Token(original.changeID, container: container), original.pending)
        let read = ModelContext(container)
        let pending = try XCTUnwrap(read.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == successorID })
        XCTAssertEqual(pending.status, .pending)
        XCTAssertNil(try LocalPendingBusinessAttemptStore.rejectionProof(change: pending, context: read, scope: original.scope))
        XCTAssertEqual(try LocalCatalogConflictResolutionStore.resolvedChangeIDs(context: read), [original.changeID])
        XCTAssertTrue(try fetchOutboxEntries(context: read, ownerUserID: owner, domain: "catalog").isEmpty)
        let fresh = try makeR23Review(container: container, fixture: fixture, owner: owner,
            changeID: successorID, row: try XCTUnwrap(remote.persistedProductRow(id: original.snapshot.product.id)))
        XCTAssertThrowsError(try resolveR23CatalogReview(fresh, choice: .adoptRemote, container: container)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .reconciliationRequired)
        }
    }

    @MainActor
    func testR23LegacyLostResponseThenTypedReplayRejectionCannotProveNoCommit() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("r23-legacy-unknown.sqlite")
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.cleanup() }
        var container = try makeContainer(storeURL: url)
        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: fixture.shopID,
            failFirstProductUpdateAfterCommit: true)
        let seeded = try insertR23CatalogChange(container: container, fixture: fixture, owner: owner, remote: remote)
        do {
            _ = try await CatalogPushService(modelContainer: container, remote: remote,
                defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
            XCTFail("Expected the controlled lost response")
        } catch Task118CatalogRemoteError.committedResponseLost {}
        let token = try r23Token(seeded.changeID, container: container)
        let sealed = try r23Seal(seeded.changeID, container: container)
        let first = try XCTUnwrap(remote.productUpdatePayloads().first)
        container = try makeContainer(storeURL: url)
        remote.rejectNextProductUpdate = true
        let replay = try await CatalogPushService(modelContainer: container, remote: remote,
            defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
        XCTAssertEqual(replay.productUpdates, 0)
        XCTAssertEqual(remote.productUpdatePayloads(), [first, first])
        container = try makeContainer(storeURL: url)
        XCTAssertEqual(try r23Token(seeded.changeID, container: container), token)
        XCTAssertEqual(try r23Seal(seeded.changeID, container: container), sealed)
        let read = ModelContext(container)
        let pending = try XCTUnwrap(read.fetch(FetchDescriptor<LocalPendingChange>()).first)
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner, defaults: fixture.defaults)
        XCTAssertNil(try LocalPendingBusinessAttemptStore.rejectionProof(change: pending, context: read, scope: scope))
        XCTAssertTrue(try fetchOutboxEntries(context: read, ownerUserID: owner, domain: "catalog").isEmpty)
        let review = try makeR23Review(container: container, fixture: fixture, owner: owner,
            changeID: seeded.changeID, row: try XCTUnwrap(remote.persistedProductRow(id: seeded.row.id)))
        XCTAssertEqual(review.desired, review.remote, "Even equal local/remote bodies are not proof of no commit")
        XCTAssertThrowsError(try resolveR23CatalogReview(review, choice: .adoptRemote, container: container)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .reconciliationRequired)
        }
        XCTAssertTrue(try LocalCatalogConflictResolutionStore.receipts(context: ModelContext(container)).isEmpty)
    }

    @MainActor
    func testR23ManualUnknownCannotBeResealedAndIndependentFreshWorkStillProceeds() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("r23-manual-to-automatic-unknown.sqlite")
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.cleanup() }
        var container = try makeContainer(storeURL: url)
        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: fixture.shopID)
        let seed = try insertR23CatalogChange(container: container, fixture: fixture, owner: owner, remote: remote)
        let manualTimestamp = Date(timeIntervalSince1970: 1_792_781_123)
        let manualState = LocalPendingAggregatedPushStateStore(context: ModelContext(container), now: { manualTimestamp })
        try manualState.markSent(changeIDs: [seed.changeID], ownerUserID: owner, planFingerprint: "prior-manual-aggregate")
        try manualState.markRetryable(changeIDs: [seed.changeID], ownerUserID: owner)
        container = try makeContainer(storeURL: url)
        let prior = try r23Token(seed.changeID, container: container)
        XCTAssertEqual(prior.lastAttemptAt, manualTimestamp)
        XCTAssertNil(try LocalPendingBusinessAttemptStore.entry(changeID: seed.changeID, context: ModelContext(container)))
        // This server rejection is deliberately never reached: without original
        // request bytes even the first automatic HTTP would be a reconstruction.
        remote.rejectNextProductUpdate = true
        let first = try await CatalogPushService(modelContainer: container, remote: remote,
            defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
        XCTAssertEqual(first.productUpdates, 0)
        XCTAssertTrue(remote.productUpdatePayloads().isEmpty, "Unsealed attempted history cannot authorize a reconstructed HTTP call")
        XCTAssertEqual(try r23Token(seed.changeID, container: container), prior)
        XCTAssertNil(try LocalPendingBusinessAttemptStore.entry(changeID: seed.changeID, context: ModelContext(container)))
        let review = try makeR23Review(container: container, fixture: fixture, owner: owner,
            changeID: seed.changeID, row: seed.row)
        XCTAssertThrowsError(try resolveR23CatalogReview(review, choice: .adoptRemote, container: container)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .reconciliationRequired)
        }
        XCTAssertTrue(try LocalCatalogConflictResolutionStore.receipts(context: ModelContext(container)).isEmpty)
        XCTAssertEqual(try LocalCatalogConflictResolutionStore.attentionProductChangeIDs(context: ModelContext(container),
            ownerUserID: owner, storeIdentity: fixture.storeIdentity), [seed.changeID])
        let manualPlan = try await LocalPendingAggregatedPushPlanner(context: ModelContext(container),
            includesCatalog: true, includesProductPrice: false).makePlan(ownerUserID: owner)
        XCTAssertTrue(manualPlan.blockers.contains(.unsafeCatalogPlan), "The manual path cannot reconstruct the unknown request either")

        // A different, never-attempted entity remains eligible; the unknown
        // member is not a global writer stop and keeps its original token.
        let independentID = try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container, ownerUserID: owner) { context in
            let product = Product(barcode: "R23-INDEPENDENT-FRESH", productName: "Independent saved intent")
            context.insert(product)
            let change = try XCTUnwrap(LocalPendingChangeAccumulator(context: context, ownerUserID: owner,
                storeIdentity: fixture.storeIdentity).recordProductChange(product: product, operation: .create,
                    origin: .manualCatalogSave, changedFields: ["productName"], baselineFingerprintHash: nil))
            try context.save()
            return change.changeID
        }
        container = try makeContainer(storeURL: url)
        let next = try await CatalogPushService(modelContainer: container, remote: remote,
            defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
        XCTAssertEqual(next.productCreates, 1)
        XCTAssertEqual(remote.attemptedProductCreatePayloads().map(\.barcode), ["R23-INDEPENDENT-FRESH"])
        XCTAssertTrue(remote.productUpdatePayloads().isEmpty)
        XCTAssertEqual(try r23Token(independentID, container: container).statusRaw, LocalPendingChangeStatus.acknowledged.rawValue)
        XCTAssertEqual(try r23Token(seed.changeID, container: container), prior)
        XCTAssertNil(try LocalPendingBusinessAttemptStore.entry(changeID: seed.changeID, context: ModelContext(container)))
        XCTAssertTrue(try LocalCatalogConflictResolutionStore.receipts(context: ModelContext(container)).isEmpty)
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<Product>()).first { $0.remoteID == seed.row.id }?.productName, "Saved A")
        XCTAssertEqual(remote.persistedProductRow(id: seed.row.id)?.productName, seed.row.productName)
        XCTAssertEqual(remote.persistedProductRow(id: seed.row.id)?.updatedAt, seed.row.updatedAt)
    }

    @MainActor
    func testR23DurableManualAtomicUnknownKeepsOriginalRequestWhileIndependentAutomaticWorkProceeds() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("r23-durable-manual-atomic-unknown.sqlite")
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.cleanup() }
        var container = try makeContainer(storeURL: url)
        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: fixture.shopID)
        let seed = try insertR23CatalogChange(container: container, fixture: fixture, owner: owner, remote: remote)
        let manualTimestamp = Date(timeIntervalSince1970: 1_792_781_123)
        let manualState = LocalPendingAggregatedPushStateStore(context: ModelContext(container), now: { manualTimestamp })
        try manualState.markSent(changeIDs: [seed.changeID], ownerUserID: owner, planFingerprint: "prior-manual-aggregate")
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner, defaults: fixture.defaults)
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container, ownerUserID: owner) { context in
            let change = try XCTUnwrap(context.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == seed.changeID })
            let url = "https://example.invalid/rest/v1/inventory_products?id=eq.\(seed.row.id.uuidString.lowercased())&owner_user_id=eq.\(owner.uuidString.lowercased())&shop_id=eq.\(scope.shopID.uuidString.lowercased())"
            var request = URLRequest(url: URL(string: url)!)
            request.httpMethod = "PATCH"
            request.httpBody = Data("{\"product_name\":\"Saved A\"}".utf8)
            let witness = try ManualPendingAtomicRequestStore.prepareExact(request: request, requestID: UUID(), batchID: UUID(),
                members: [LocalPendingChangeCASToken(change)], requestMemberIDs: [seed.changeID], scope: scope,
                generationID: UUID(), context: context)
            try ManualPendingAtomicRequestStore.beginDispatch(witness: witness, context: context, scope: scope)
        }
        let originalRequest = try XCTUnwrap(ManualPendingAtomicRequestStore.records(context: ModelContext(container)).first?.1.request)
        container = try makeContainer(storeURL: url)
        let prior = try r23Token(seed.changeID, container: container)
        XCTAssertEqual(prior.lastAttemptAt, manualTimestamp)
        XCTAssertNil(try LocalPendingBusinessAttemptStore.entry(changeID: seed.changeID, context: ModelContext(container)))
        // The actual store boundary retains original aggregate bytes. The
        // automatic writer must not reinterpret them as a single-row replay.
        remote.rejectNextProductUpdate = true
        let first = try await CatalogPushService(modelContainer: container, remote: remote,
            defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
        XCTAssertEqual(first.productUpdates, 0)
        XCTAssertTrue(remote.productUpdatePayloads().isEmpty, "A durable manual aggregate cannot authorize a single-row automatic replay")
        XCTAssertEqual(try r23Token(seed.changeID, container: container), prior)
        XCTAssertNil(try LocalPendingBusinessAttemptStore.entry(changeID: seed.changeID, context: ModelContext(container)))
        let review = try makeR23Review(container: container, fixture: fixture, owner: owner,
            changeID: seed.changeID, row: seed.row)
        XCTAssertThrowsError(try resolveR23CatalogReview(review, choice: .adoptRemote, container: container)) {
            XCTAssertEqual($0 as? CatalogConflictResolutionError, .reconciliationRequired)
        }
        XCTAssertTrue(try LocalCatalogConflictResolutionStore.receipts(context: ModelContext(container)).isEmpty)
        XCTAssertEqual(try LocalCatalogConflictResolutionStore.attentionProductChangeIDs(context: ModelContext(container),
            ownerUserID: owner, storeIdentity: fixture.storeIdentity), [seed.changeID])
        let manualPlan = try await LocalPendingAggregatedPushPlanner(context: ModelContext(container),
            includesCatalog: true, includesProductPrice: false).makePlan(ownerUserID: owner)
        XCTAssertTrue(manualPlan.blockers.contains(.sentChangesWaitingForRetry),
            "The still-sent manual member is blocked before candidate selection")
        XCTAssertNil(manualPlan.catalogBatch, "The manual path cannot reconstruct the unknown request either")
        XCTAssertEqual(try r23Token(seed.changeID, container: container), prior)
        XCTAssertEqual(try ManualPendingAtomicRequestStore.records(context: ModelContext(container)).first?.1.request, originalRequest)

        // A different, never-attempted entity remains eligible; the unknown
        // member is not a global writer stop and keeps its original token.
        let independentID = try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container, ownerUserID: owner) { context in
            let product = Product(barcode: "R23-INDEPENDENT-FRESH", productName: "Independent saved intent")
            context.insert(product)
            let change = try XCTUnwrap(LocalPendingChangeAccumulator(context: context, ownerUserID: owner,
                storeIdentity: fixture.storeIdentity).recordProductChange(product: product, operation: .create,
                    origin: .manualCatalogSave, changedFields: ["productName"], baselineFingerprintHash: nil))
            try context.save()
            return change.changeID
        }
        container = try makeContainer(storeURL: url)
        let next = try await CatalogPushService(modelContainer: container, remote: remote,
            defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
        XCTAssertEqual(next.productCreates, 1)
        XCTAssertEqual(remote.attemptedProductCreatePayloads().map(\.barcode), ["R23-INDEPENDENT-FRESH"])
        XCTAssertTrue(remote.productUpdatePayloads().isEmpty)
        XCTAssertEqual(try r23Token(independentID, container: container).statusRaw, LocalPendingChangeStatus.acknowledged.rawValue)
        XCTAssertEqual(try r23Token(seed.changeID, container: container), prior)
        XCTAssertNil(try LocalPendingBusinessAttemptStore.entry(changeID: seed.changeID, context: ModelContext(container)))
        XCTAssertTrue(try LocalCatalogConflictResolutionStore.receipts(context: ModelContext(container)).isEmpty)
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<Product>()).first { $0.remoteID == seed.row.id }?.productName, "Saved A")
        XCTAssertEqual(remote.persistedProductRow(id: seed.row.id)?.productName, seed.row.productName)
        XCTAssertEqual(remote.persistedProductRow(id: seed.row.id)?.updatedAt, seed.row.updatedAt)
        XCTAssertEqual(try ManualPendingAtomicRequestStore.records(context: ModelContext(container)).first?.1.request, originalRequest)
        XCTAssertEqual(try ManualPendingAtomicRequestStore.blockingChangeIDs(context: ModelContext(container), scope: scope), [seed.changeID])
    }

    @MainActor
    func testR23AdoptionPreservesPriceThenRealPriceWriterAcknowledgesExactlyOnce() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("r23-price.sqlite")
        let owner = UUID()
        let fixture = try makeAutomaticScopeFixture(ownerUserID: owner)
        defer { fixture.cleanup() }
        var container = try makeContainer(storeURL: url)
        let remote = Task118CatalogRemote(ownerUserID: owner, shopID: fixture.shopID)
        let review = try await makeR23RejectedCatalogChange(container: container, fixture: fixture,
            owner: owner, remote: remote)
        let originalSeal = try r23Seal(review.changeID, container: container)
        let child = try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container, ownerUserID: owner) { context in
            let product = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first)
            let price = ProductPrice(type: .purchase, price: 37, effectiveAt: Date(timeIntervalSince1970: 1_792_781_000),
                source: "manual", product: product)
            context.insert(price)
            let change = try XCTUnwrap(LocalPendingChangeAccumulator(context: context, ownerUserID: owner,
                storeIdentity: fixture.storeIdentity).recordProductPriceChange(price: price, origin: .productPriceSave))
            try context.save()
            return LocalPendingChangeCASToken(change)
        }
        _ = try resolveR23CatalogReview(review, choice: .adoptRemote, container: container)
        container = try makeContainer(storeURL: url)
        XCTAssertEqual(try r23Token(child.changeID, container: container), child)
        let priceRemote = Task118ProductPriceRemote()
        let result = try await ProductPricePushService(modelContainer: container, remote: priceRemote,
            defaults: fixture.defaults).pushPendingProductPrices(ownerUserID: owner)
        XCTAssertEqual(result.insertedCount, 1)
        XCTAssertEqual(priceRemote.insertCallCount(), 1)
        XCTAssertEqual(priceRemote.insertedPayloads.count, 1)
        let sent = try XCTUnwrap(priceRemote.insertedPayloads.first)
        XCTAssertEqual(sent.productID, review.snapshot.product.id)
        XCTAssertEqual(sent.price, 37)
        XCTAssertEqual(sent.ownerUserID, owner)
        XCTAssertEqual(sent.shopID, fixture.shopID)
        container = try makeContainer(storeURL: url)
        let after = try r23Token(child.changeID, container: container)
        XCTAssertEqual(after.statusRaw, LocalPendingChangeStatus.acknowledged.rawValue)
        XCTAssertEqual(after.idempotencyKey, child.idempotencyKey)
        XCTAssertEqual(after.changedFieldsRaw, child.changedFieldsRaw)
        XCTAssertEqual(try r23Token(review.changeID, container: container), review.pending)
        XCTAssertEqual(try r23Seal(review.changeID, container: container), originalSeal)
        XCTAssertEqual(try ModelContext(container).fetch(FetchDescriptor<ProductPrice>()).first?.remoteID, sent.id)
        XCTAssertEqual(try fetchOutboxEntries(context: ModelContext(container), ownerUserID: owner, domain: "prices").count, 1)
        _ = try await ProductPricePushService(modelContainer: container, remote: priceRemote,
            defaults: fixture.defaults).pushPendingProductPrices(ownerUserID: owner)
        XCTAssertEqual(priceRemote.insertCallCount(), 1)
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<ProductPrice>()), 1)
    }

    @MainActor
    private func insertR23CatalogChange(container: ModelContainer, fixture: Task118AutomaticScopeFixture,
        owner: UUID, remote: Task118CatalogRemote) throws -> (changeID: String, row: RemoteInventoryProductRow) {
        let row = RemoteInventoryProductRow(id: UUID(), ownerUserID: owner, shopID: fixture.shopID,
            barcode: "R23-WRITER", itemNumber: "Remote item", productName: "Remote R", secondProductName: nil,
            purchasePrice: 10, retailPrice: 20, supplierID: nil, categoryID: nil, stockQuantity: nil,
            updatedAt: "2026-10-23T20:10:00.123456Z", deletedAt: nil)
        remote.seedProduct(row)
        let id = try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container, ownerUserID: owner) { context in
            let product = Product(barcode: row.barcode, remoteID: row.id,
                remoteUpdatedAt: SupabaseRemoteDateParser.parse(row.updatedAt), itemNumber: row.itemNumber,
                productName: row.productName, purchasePrice: row.purchasePrice, retailPrice: row.retailPrice)
            context.insert(product)
            let base = LocalPendingChangeLogicalKey.productFingerprintHash(product)
            product.productName = "Saved A"
            let change = try XCTUnwrap(LocalPendingChangeAccumulator(context: context, ownerUserID: owner,
                storeIdentity: fixture.storeIdentity).recordProductChange(product: product, operation: .update,
                    origin: .manualCatalogSave, changedFields: ["productName"], baselineFingerprintHash: base))
            try context.save()
            return change.changeID
        }
        return (id, row)
    }

    @MainActor
    private func makeR23RejectedCatalogChange(container: ModelContainer, fixture: Task118AutomaticScopeFixture,
        owner: UUID, remote: Task118CatalogRemote) async throws -> PersistedCatalogConflictReview {
        let seed = try insertR23CatalogChange(container: container, fixture: fixture, owner: owner, remote: remote)
        remote.rejectNextProductUpdate = true
        let result = try await CatalogPushService(modelContainer: container, remote: remote,
            defaults: fixture.defaults).pushPendingCatalog(ownerUserID: owner)
        XCTAssertEqual(result.productUpdates, 0)
        XCTAssertEqual(remote.productUpdatePayloads().count, 1)
        let review = try makeR23Review(container: container, fixture: fixture, owner: owner,
            changeID: seed.changeID, row: seed.row)
        let context = ModelContext(container)
        let pending = try XCTUnwrap(context.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == seed.changeID })
        XCTAssertNotNil(try LocalPendingBusinessAttemptStore.rejectionProof(change: pending, context: context, scope: review.scope))
        return review
    }

    @MainActor
    private func makeR23Review(container: ModelContainer, fixture: Task118AutomaticScopeFixture,
        owner: UUID, changeID: String, row: RemoteInventoryProductRow) throws -> PersistedCatalogConflictReview {
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: owner, defaults: fixture.defaults)
        let context = ModelContext(container)
        let product = try XCTUnwrap(context.fetch(FetchDescriptor<Product>()).first)
        let token = try r23Token(changeID, container: container)
        let snapshot = CatalogConflictRemoteSnapshot(product: row, suppliers: [], categories: [],
            observedAt: Date(), scopeLeaseGeneration: scope.leaseGeneration)
        return PersistedCatalogConflictReview(id: UUID(), changeID: changeID, originalChangedFields: ["productName"],
            desired: CatalogConflictProductValues(product: product), remote: snapshot.values,
            remoteUpdatedAt: row.updatedAt, remoteDeletedAt: row.deletedAt, canResolve: true, blockedReason: nil,
            pending: token, scope: scope, generationID: UUID(), snapshot: snapshot,
            originalSealSHA256: try LocalPendingBusinessAttemptStore.entry(changeID: changeID, context: context)?.entityIDsShape)
    }

    @MainActor
    private func resolveR23CatalogReview(_ review: PersistedCatalogConflictReview, choice: PersistedCatalogConflictChoice,
        container: ModelContainer) throws -> PersistedCatalogConflictOutcome {
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: container, ownerUserID: review.scope.ownerUserID) { context in
            try LocalPendingChangeAccumulator.resolvePersistedCatalogConflict(context: context, review: review, choice: choice,
                remote: review.snapshot, ownerRelease: .init(invocationID: UUID(), processEpoch: UUID(),
                    scopeLeaseGeneration: review.scope.leaseGeneration, generationID: review.generationID,
                    writerJournalSHA256: ShopSyncRecoveryCanonical.sha256("no-recovery-journal")), writerJournalIsClear: true)
        }
    }

    @MainActor
    private func r23Token(_ changeID: String, container: ModelContainer) throws -> LocalPendingChangeCASToken {
        let context = ModelContext(container)
        return LocalPendingChangeCASToken(try XCTUnwrap(context.fetch(FetchDescriptor<LocalPendingChange>()).first { $0.changeID == changeID }))
    }

    @MainActor
    private func r23Seal(_ changeID: String, container: ModelContainer) throws -> String {
        try XCTUnwrap(LocalPendingBusinessAttemptStore.entry(changeID: changeID, context: ModelContext(container))?.metadataPayloadJSON)
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

    @MainActor
    private func insertT11InvalidSupplierGraph(container: ModelContainer, owner: UUID,
        fixture: Task118AutomaticScopeFixture) throws -> (supplierChangeID: String, dependentChangeID: String,
        dependentBarcode: String, independentBarcode: String) {
        let context = ModelContext(container)
        let supplier = Supplier(name: String(repeating: "X", count: 161))
        let dependent = Product(barcode: "T11-ADJACENT-DEPENDENT", productName: "Dependent", supplier: supplier)
        let independent = Product(barcode: "T11-ADJACENT-INDEPENDENT", productName: "Independent")
        context.insert(supplier); context.insert(dependent); context.insert(independent)
        let rows: [(LocalPendingChangeEntityKind, String, [String], String)] = [
            (.supplier, LocalPendingChangeLogicalKey.supplier(remoteID: nil, name: supplier.name),
             ["name"], LocalPendingChangeLogicalKey.supplierFingerprintHash(supplier)),
            (.product, LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: dependent.barcode),
             ["barcode", "productName", "supplier"], LocalPendingChangeLogicalKey.productFingerprintHash(dependent)),
            (.product, LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: independent.barcode),
             ["barcode", "productName"], LocalPendingChangeLogicalKey.productFingerprintHash(independent))
        ]
        var changes: [LocalPendingChange] = []
        for (index, row) in rows.enumerated() {
            let time = Date(timeIntervalSince1970: 1_700_000_000 + Double(index))
            let change = LocalPendingChange(ownerUserID: owner, ownerHash: AccountBindingStore.accountHash(for: owner),
                storeId: fixture.storeIdentity.storeId, localStoreId: fixture.storeIdentity.localStoreId,
                syncProtocolVersion: fixture.storeIdentity.syncProtocolVersion,
                schemaVersion: fixture.storeIdentity.schemaVersion, storeEpoch: fixture.storeIdentity.storeEpoch,
                entityKind: row.0, operation: .create, status: .pending, origin: .manualCatalogSave,
                logicalKey: row.1, changedFields: row.2, intendedFingerprintHash: row.3,
                createdAt: time, updatedAt: time)
            context.insert(change); changes.append(change)
        }
        try context.save()
        let fresh = ModelContext(container)
        let savedSupplier = try XCTUnwrap(fresh.fetch(FetchDescriptor<Supplier>()).first)
        let savedDependent = try XCTUnwrap(fetchProduct(barcode: dependent.barcode, context: fresh))
        XCTAssertTrue(savedDependent.supplier === savedSupplier)
        XCTAssertThrowsError(try CatalogTextPolicy.validate(savedSupplier.name, for: .supplierName)) {
            XCTAssertEqual($0 as? CatalogTextValidationError, .init(field: .supplierName, reason: .tooLong))
        }
        let snapshot = try LocalPendingChangeSnapshotProvider(context: fresh)
            .loadSnapshot(ownerUserID: owner, storeIdentity: fixture.storeIdentity)
        XCTAssertEqual(snapshot.pendingCatalogChangeCount, 3)
        return (changes[0].changeID, changes[1].changeID, dependent.barcode, independent.barcode)
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
    private let failFirstProductUpdateAfterCommit: Bool
    private var didFailProductUpdateAfterCommit = false
    private var createdProductPayloads: [SyncAutomaticProductCreatePayload] = []
    private var persistedProductRows: [UUID: RemoteInventoryProductRow] = [:]
    private var productCreateAttemptIDs: [UUID] = []
    private var supplierCreateRequests: [SyncAutomaticSupplierCreatePayload] = []
    private var supplierUpdateRequests: [(UUID, SyncAutomaticSupplierUpdatePayload)] = []
    private var categoryUpdateRequests: [(UUID, SyncAutomaticCategoryUpdatePayload)] = []
    private var productUpdateRequests: [(UUID, SyncAutomaticProductUpdatePayload)] = []
    struct ConditionalRequest: Equatable {
        let id: UUID
        let payload: SyncAutomaticProductUpdatePayload
        let version: SyncCatalogConditionalVersion
        let fields: [String]
    }
    var rejectNextProductUpdate = false
    var loseFirstConditionalResponse = false
    private var didLoseConditionalResponse = false
    private(set) var conditionalRequests: [ConditionalRequest] = []
    private(set) var conditionalReturnCounts: [Int] = []

    func seedProduct(_ row: RemoteInventoryProductRow) { persistedProductRows[row.id] = row }


    init(
        ownerUserID: UUID,
        shopID: UUID,
        failFirstProductCreateAfterCommit: Bool = false,
        failFirstProductUpdateAfterCommit: Bool = false
    ) {
        self.ownerUserID = ownerUserID
        self.shopID = shopID
        self.failFirstProductCreateAfterCommit = failFirstProductCreateAfterCommit
        self.failFirstProductUpdateAfterCommit = failFirstProductUpdateAfterCommit
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

    func attemptedSupplierCreatePayloads() -> [SyncAutomaticSupplierCreatePayload] { supplierCreateRequests }

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
        supplierCreateRequests.append(contentsOf: payloads)
        return payloads.map {
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
        if rejectNextProductUpdate {
            rejectNextProductUpdate = false
            throw SyncCatalogWriteRejectedWithoutCommit(sqlstate: "23505")
        }
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
        if failFirstProductUpdateAfterCommit, !didFailProductUpdateAfterCommit {
            didFailProductUpdateAfterCommit = true
            throw Task118CatalogRemoteError.committedResponseLost
        }
        return row
    }
    func updateProductConditionally(id: UUID, payload: SyncAutomaticProductUpdatePayload,
        expectedVersion: SyncCatalogConditionalVersion, changedFields: [String]) async throws -> [RemoteInventoryProductRow] {
        try expectedVersion.validate()
        _ = try SyncCatalogConditionalProductWirePayload(payload: payload, changedFields: changedFields)
        conditionalRequests.append(.init(id: id, payload: payload, version: expectedVersion, fields: changedFields))
        guard let existing = persistedProductRows[id], existing.ownerUserID == ownerUserID,
              existing.shopID == shopID, existing.updatedAt == expectedVersion.expectedUpdatedAt,
              existing.deletedAt == expectedVersion.expectedDeletedAt else {
            conditionalReturnCounts.append(0)
            return []
        }
        let fields = Set(changedFields)
        let row = RemoteInventoryProductRow(id: id, ownerUserID: ownerUserID, shopID: shopID,
            barcode: fields.contains("barcode") ? try XCTUnwrap(payload.barcode) : existing.barcode,
            itemNumber: fields.contains("itemNumber") ? payload.itemNumber : existing.itemNumber,
            productName: fields.contains("productName") ? payload.productName : existing.productName,
            secondProductName: fields.contains("secondProductName") ? payload.secondProductName : existing.secondProductName,
            purchasePrice: fields.contains("purchasePrice") ? payload.purchasePrice : existing.purchasePrice,
            retailPrice: fields.contains("retailPrice") ? payload.retailPrice : existing.retailPrice,
            supplierID: fields.contains("supplierID") ? payload.supplierID : existing.supplierID,
            categoryID: fields.contains("categoryID") ? payload.categoryID : existing.categoryID,
            stockQuantity: fields.contains("stockQuantity") ? payload.stockQuantity : existing.stockQuantity,
            updatedAt: "2026-10-23T20:12:00.654321Z", deletedAt: existing.deletedAt)
        persistedProductRows[id] = row
        conditionalReturnCounts.append(1)
        if loseFirstConditionalResponse, !didLoseConditionalResponse {
            didLoseConditionalResponse = true
            throw Task118CatalogRemoteError.committedResponseLost
        }
        return [row]
    }
}

@MainActor
private final class Task118ProductPriceRemote: SyncAutomaticProductPriceRemoteWriting {
    private var insertCalls = 0
    private(set) var insertedPayloads: [SyncAutomaticProductPricePayload] = []

    func insertCallCount() -> Int {
        insertCalls
    }

    func insertProductPrices(_ payloads: [SyncAutomaticProductPricePayload]) async throws -> [RemoteInventoryProductPriceRow] {
        insertCalls += 1
        insertedPayloads.append(contentsOf: payloads)
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

private struct Task118LegacyCatalogMutation: Codable {
    enum Call: Codable {
        case createProduct(SyncAutomaticProductCreatePayload)
        case updateProduct(UUID, SyncAutomaticProductUpdatePayload)
    }
    let call: Call
    let businessFingerprint: String?
    let isCreate: Bool
    let isTombstone: Bool
}

@MainActor
private final class Task118T11IncrementalRecorder: SyncIncrementalPullProviding {
    private(set) var calls = 0
    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SyncIncrementalPullSummary {
        calls += 1
        return .noWork(watermark: 0)
    }
}

@MainActor
private final class Task118T11EventRecorder: SyncEventRecording {
    let ownerUserID: UUID
    private(set) var requests: [SyncEventRecordRequest] = []
    init(ownerUserID: UUID) { self.ownerUserID = ownerUserID }

    func record(_ request: SyncEventRecordRequest) async throws -> SyncEventRecordResult {
        try SyncEventRecordValidator().validate(request)
        requests.append(request)
        var row: [String: Any] = [
            "id": String(requests.count), "owner_user_id": ownerUserID.uuidString,
            "domain": request.domain, "event_type": request.eventType,
            "changed_count": request.changedCount, "client_event_id": request.clientEventID,
            "created_at": "2026-10-16T00:00:00Z", "requires_full_recovery": false,
            "entity_ids": try JSONSerialization.jsonObject(with: JSONEncoder().encode(request.entityIDs)),
            "metadata": try JSONSerialization.jsonObject(with: JSONEncoder().encode(request.metadata))
        ]
        if let shop = request.shopID { row["shop_id"] = shop.uuidString; row["store_id"] = shop.uuidString }
        if let device = request.sourceDeviceID { row["source_device_id"] = device }
        if let batch = request.batchID { row["batch_id"] = batch.uuidString }
        return .recorded(try JSONDecoder().decode(RemoteSyncEventRow.self,
            from: JSONSerialization.data(withJSONObject: row, options: [.sortedKeys])))
    }
}
