import Foundation
import CoreFoundation
import CryptoKit
import Combine

nonisolated enum SyncAutomaticRecoveryAttemptEligibility: Equatable, Sendable {
    case ready
    case cooldown(TimeInterval)
    case exhausted
}

/// Only the store can issue a claim. Identity alone does not distinguish a
/// cancelled invocation from its successor using the same recovery journal.
nonisolated struct SyncAutomaticRecoveryAttemptClaim: Sendable {
    fileprivate let storageKey: String
    fileprivate let identity: String
    fileprivate let invocationID: UUID
    let attemptInWindow: Int
}

private nonisolated struct SyncAutomaticRecoveryAttemptRecord: Codable, Sendable {
    static let schemaVersion = 4

    let schemaVersion: Int
    let identity: String
    let invocationID: UUID
    let windowIndex: Int
    let attemptsInWindow: Int
    let totalAttempts: Int
    let lastAttemptAt: TimeInterval
    let lastCompletedAt: TimeInterval?
    let failure: AutomaticSyncFailure?
    let nextAllowedAt: TimeInterval
    let retryAfterUntil: TimeInterval?
    var legacyContinuation: SyncLegacyRecoveryContinuation? = nil
    var publishedFinalization: SyncPublishedRecoveryPreparation? = nil
    var lifecycle: SyncRecoveryAttemptLifecycle? = nil
    // One completed legacy reconciliation, retained verbatim across genuinely
    // new journals. This never embeds another historical record.
    var retiredLegacyReconciliation: Data? = nil
}

private nonisolated struct SyncRecoveryAttemptLifecycle: Codable, Sendable {
    enum Operation: String, Codable, Sendable { case automatic, reconciliation }
    enum State: String, Codable, Sendable { case running, interrupted, waiting, blocked, completed }
    let formatVersion: Int
    var processEpoch: UUID
    var operation: Operation
    var state: State
    var phase: AccountRecoveryJournalPhase?
    var generationID: UUID?
    var firstObservedAt: TimeInterval?
    var originPayload: Data?
    var originSHA256: String?
    var originalAttemptTimeUnknown: Bool
}

nonisolated enum SyncRecoveryReconciliationOpportunity: Equatable, Sendable {
    case none
    case ready(SyncRecoveryReconciliation)
    case cooldown(TimeInterval)
    case blocked
}


/// Version3 is deliberately unreadable by the old v2-only reader. A downgrade
/// must not turn this terminal-only claim into permission to restage.
private nonisolated struct SyncPublishedRecoveryPreparation: Codable, Sendable {
    let formatVersion: Int
    let publishedGenerationID: UUID
    let publishedCheckpointDigest: String
    let publishedBaselineRunID: UUID
    let preparedForInvocationID: UUID
    let preparedFromTotalAttempts: Int
    let preparedAt: TimeInterval
    var claimed: Bool

    func matches(_ descriptor: SyncPublishedRecoveryFinalization) -> Bool {
        publishedGenerationID == descriptor.generationID
            && publishedCheckpointDigest == descriptor.checkpointDigest
            && publishedBaselineRunID == descriptor.baselineRunID
    }
}

private nonisolated struct SyncLegacyRecoveryClaimRecord: Codable, Equatable {
    let schemaVersion: Int
    let continuation: SyncLegacyRecoveryContinuation
    let invocationID: UUID
    let claimedAt: TimeInterval
}

private nonisolated struct SyncVerifiedProofRecord: Codable, Equatable {
    static let version = 2
    let schemaVersion: Int
    let verifiedAt: TimeInterval
    let finalization: SyncStoreRecoveryFinalization
}

/// v2 requires the complete keyed identity actually published by recovery.
/// LocalStoreIdentity's legacy decoder may infer absent fields or a scalar;
/// that compatibility must never manufacture provenance for this new record.
private nonisolated struct SyncVerifiedProofRequiredShape: Decodable {
    struct Finalization: Decodable {
        struct StoreIdentity: Decodable {
            let rawValue: String
            let defaultStoreId: String
            let localStoreId: String
            let schemaVersion: Int
            let syncProtocolVersion: Int
            let storeEpoch: Int
            func exactlyDescribes(_ decoded: LocalStoreIdentity) -> Bool {
                rawValue == decoded.rawValue && defaultStoreId == decoded.defaultStoreId
                    && localStoreId == decoded.localStoreId && schemaVersion == decoded.schemaVersion
                    && syncProtocolVersion == decoded.syncProtocolVersion && storeEpoch == decoded.storeEpoch
            }
        }
        let storeIdentity: StoreIdentity
    }
    let finalization: Finalization
}

@MainActor
final class SyncStateStore: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    private var storedState = SyncState()
    private var continuedGeneration: SyncIncrementalContinuationReceipt?
    private var terminalProjectionHasObservation = false
    private var activeProjectionRevision = UUID()
    private var presentationInvocationID: UUID?
    var hasActivePresentationInvocation: Bool { presentationInvocationID != nil }

    private(set) var state: SyncState {
        get {
            // Resolve canonical provenance before entering the receipt's
            // non-recursive Task126 lease. Historical success is independent
            // of the current phase, but never belongs to another generation.
            var projected = storedState
            projected.lastVerifiedAt = currentVerifiedDate()
            if terminalProjectionHasObservation,
               Self.decodedRunObservation(defaults: defaults, keyPrefix: keyPrefix)?
                .origin.isCurrent(defaults: defaults) != true,
               !projected.phase.isAutomaticWorkActive {
                // Foreign/missing/corrupt history cannot invent a recovery
                // latch or terminal outcome for the selected entity.
                projected.phase = recoveryJournalIsPending ? .recoveryRequired : .idle
                projected.lastOutcome = nil
                projected.startedAt = nil
                projected.lastProgressAt = nil
            }
            guard storedState.phase == .idle, let receipt = continuedGeneration else { return projected }
            do {
                return try receipt.withValidatedAuthority(defaults: defaults, checkLocalCounts: false) { projected }
            } catch {
                var invalidated = projected
                invalidated.phase = .recoveryRequired
                return invalidated
            }
        }
        set {
            // Notify outside Task126's non-recursive lease. A synchronous
            // observer may read state or invalidate identity safely here.
            objectWillChange.send()
            continuedGeneration = nil
            activeProjectionRevision = UUID()
            presentationInvocationID = nil
            recoveryProgressInvocationID = nil
            terminalProjectionHasObservation = false
            storedState = newValue
        }
    }
    private let defaults: UserDefaults
    private let keyPrefix: String
    private let retryJitter: @Sendable () -> Double
    private let storeGenerationController: SyncStoreGenerationController?
    private var recoveryProgressInvocationID: UUID?
    private static let currentRecoveryProcessEpoch = UUID()
    private static var liveRecoveryInvocations = Set<UUID>()
    private let recoveryProcessEpoch: UUID
    private(set) var recoveryReconciliationBlockReason: String?

    var recoveryJournalIsPending: Bool {
        // Do not retain a second journal-store object in this presentation
        // model.  The journal is a UserDefaults-backed durable latch, so a
        // fresh read is both authoritative and avoids extending the lifetime
        // of replacement-coordinator state across test/app teardown.
        AccountBindingStore(defaults: defaults).hasPendingReplacementJournal
    }

    var pendingRecoveryJournal: AccountRecoveryJournalSnapshot? {
        AccountBindingStore(defaults: defaults).pendingRecoveryJournal
    }

    private var automaticRecoveryAttemptKey: String {
        "\(keyPrefix).automaticRecoveryAttempt.v2"
    }

    private var legacyRecoveryAttemptKey: String { "\(keyPrefix).automaticRecoveryAttempt.v1" }
    private var legacyRecoveryClaimKey: String { "\(keyPrefix).automaticRecoveryLegacyClaim.v1" }

    init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "sync.runtime.orchestrator",
        retryJitter: @escaping @Sendable () -> Double = { Double.random(in: 0.5...1.5) },
        storeGenerationController: SyncStoreGenerationController? = nil,
        recoveryProcessEpoch: UUID? = nil
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
        self.retryJitter = retryJitter
        self.storeGenerationController = storeGenerationController
        self.recoveryProcessEpoch = recoveryProcessEpoch ?? Self.currentRecoveryProcessEpoch
        state = Self.hydratedState(
            defaults: defaults,
            keyPrefix: keyPrefix,
            lastVerifiedAt: currentVerifiedDate(),
            hasPendingRecoveryJournal: AccountBindingStore(defaults: defaults)
                .hasPendingReplacementJournal
        )
        terminalProjectionHasObservation = defaults.object(forKey: runObservationKey) != nil
    }

    // This type owns only synchronous Foundation/Combine values.  Keeping
    // destruction nonisolated avoids asking the Swift runtime to enqueue an
    // otherwise empty actor-isolated deinit during XCTest/app teardown.
    nonisolated deinit {}

    func beginPresentationInvocation(_ invocationID: UUID) {
        presentationInvocationID = invocationID
        recoveryProgressInvocationID = nil
        activeProjectionRevision = UUID()
    }

    func ownsPresentationInvocation(_ invocationID: UUID) -> Bool {
        presentationInvocationID == invocationID
    }

    func beginRecoveryProgressReporting(
        presentationInvocationID expectedInvocationID: UUID? = nil
    ) -> UUID {
        let invocationID = UUID()
        guard ownsPresentation(expectedInvocationID) else { return invocationID }
        activeProjectionRevision = UUID()
        let revision = activeProjectionRevision
        recoveryProgressInvocationID = invocationID
        objectWillChange.send()
        // A synchronous observer may finish the run or replace this invocation.
        guard invocationID == recoveryProgressInvocationID,
              revision == activeProjectionRevision,
              ownsPresentation(expectedInvocationID),
              storedState.phase.isAutomaticWorkActive else { return invocationID }
        storedState.recoveryProgress = nil
        return invocationID
    }

    func recordRecoveryProgress(_ event: SyncRecoveryProgressEvent, now: Date = Date()) {
        guard let invocationID = event.invocationID,
              invocationID == recoveryProgressInvocationID,
              storedState.phase.isAutomaticWorkActive else { return }
        objectWillChange.send()
        // Recheck after notifying observers, before reading authority or publishing.
        guard invocationID == recoveryProgressInvocationID,
              storedState.phase.isAutomaticWorkActive else { return }
        guard let journal = pendingRecoveryJournal,
              journal.replacement.accountHash == event.scope.accountHash,
              journal.replacement.storeIdentity == event.scope.storeIdentity,
              journal.deviceIdentityHash == event.scope.deviceIdentityHash,
              let currentScope = try? Task126OwnerStoreGate.captureAutomaticScope(
                ownerUserID: event.scope.ownerUserID,
                defaults: defaults,
                allowsPendingReplacement: true,
                allowsPendingSameScopeRecovery: true
              ),
              currentScope.shopID == event.scope.shopID,
              currentScope.accountHash == event.scope.accountHash,
              currentScope.storeIdentity == event.scope.storeIdentity,
              currentScope.deviceIdentityHash == event.scope.deviceIdentityHash else {
            recoveryProgressInvocationID = nil
            storedState.recoveryProgress = nil
            return
        }
        // Journal phase transitions legitimately rotate the scope lease;
        // invocation + current identity fences reject stale display callbacks.
        storedState.recoveryProgress = event.progress
        storedState.lastProgressAt = now
    }

    func recordDecision(
        trigger: SyncTrigger, action: SyncAction,
        presentationInvocationID expectedInvocationID: UUID? = nil,
        now: Date = Date()
    ) {
        guard ownsPresentation(expectedInvocationID) else { return }
        defaults.set(trigger.diagnosticsName, forKey: "\(keyPrefix).lastTrigger")
        defaults.set(action.diagnosticsName, forKey: "\(keyPrefix).lastAction")
        defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).lastDecisionAt")
        if action.containsFullRecovery {
            defaults.set(true, forKey: "\(keyPrefix).lastDecisionContainedFullRecovery")
        }
    }

    func recordSafetyLoopTick(now: Date = Date()) {
        let key = "\(keyPrefix).safetyLoopTickCount"
        defaults.set(defaults.integer(forKey: key) + 1, forKey: key)
        defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).safetyLoopLastTickAt")
    }

    func updatePhase(
        _ phase: SyncPhase, outcome: SyncOutcome? = nil,
        presentationInvocationID expectedInvocationID: UUID? = nil,
        now: Date = Date()
    ) {
        let revision = activeProjectionRevision
        guard ownsPresentation(expectedInvocationID) else { return }
        let resolvedPhase = recoveryJournalIsPending && !phase.isAutomaticWorkActive
            ? .recoveryRequired : phase
        let isActive = resolvedPhase.isAutomaticWorkActive
        let prior = state
        let startedAt = isActive ? (prior.startedAt ?? now) : nil
        let lastProgressAt = isActive ? now : prior.lastProgressAt
        let candidate = SyncState(phase: resolvedPhase, progress: prior.progress,
            lastVerifiedAt: prior.lastVerifiedAt, lastOutcome: outcome ?? prior.lastOutcome,
            startedAt: startedAt, lastProgressAt: lastProgressAt)
        objectWillChange.send()
        guard revision == activeProjectionRevision,
              ownsPresentation(expectedInvocationID) else { return }
        if !isActive { recoveryProgressInvocationID = nil }
        activeProjectionRevision = UUID()
        terminalProjectionHasObservation = false
        continuedGeneration = nil
        storedState = candidate
        defaults.set(resolvedPhase.diagnosticsName, forKey: "\(keyPrefix).phase")
        if let startedAt {
            defaults.set(startedAt.timeIntervalSince1970, forKey: "\(keyPrefix).activeStartedAt")
            defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).lastProgressAt")
        } else {
            defaults.removeObject(forKey: "\(keyPrefix).activeStartedAt")
            defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).lastProgressAt")
        }
    }

    func recordRunResult(
        _ result: SyncAutomaticRunResult,
        preserveRecoveryRequired: Bool = false,
        presentationInvocationID expectedPresentationInvocationID: UUID? = nil,
        automaticRecoveryClaim: SyncAutomaticRecoveryAttemptClaim? = nil,
        automaticRecoveryAuthority: (@MainActor () -> Bool)? = nil,
        now: Date = Date()
    ) {
        if let automaticRecoveryClaim {
            guard ownsAutomaticRecoveryAttempt(automaticRecoveryClaim) else { return }
        }
        let candidateRevision = activeProjectionRevision
        guard ownsPresentation(expectedPresentationInvocationID),
              automaticRecoveryAuthority?() != false else { return }
        guard canAcceptObservation(from: result) else {
            retireInvalidActiveCandidate(for: result, revision: candidateRevision,
                expectedInvocationID: expectedPresentationInvocationID, authority: automaticRecoveryAuthority)
            return
        }
        let isOrdinaryCompletion = !result.verifiedConvergence
            && (result.status == .success || result.status == .noWork)
            && result.blockReason == nil && result.errorCode == nil
        if isOrdinaryCompletion, !preserveRecoveryRequired,
           let receipt = result.continuationReceipt {
            // Subscribers run before the guard and cannot observe an idle
            // candidate computed from authority they have just invalidated.
            objectWillChange.send()
            guard candidateRevision == activeProjectionRevision,
                  ownsPresentation(expectedPresentationInvocationID),
                  automaticRecoveryAuthority?() != false else { return }
            guard acceptObservation(from: result) else {
                retireInvalidActiveCandidate(for: result, revision: candidateRevision,
                    expectedInvocationID: expectedPresentationInvocationID, authority: automaticRecoveryAuthority)
                return
            }
            let priorVerifiedAt = currentVerifiedDate()
            do {
                try receipt.withValidatedAuthority(defaults: defaults) {
                    guard storedState.phase != .recoveryRequired else {
                        throw SyncStoreGenerationError.activationReadBackFailed
                    }
                    applyRunResult(result, preserveRecoveryRequired: false, continued: true,
                        verified: false, verifiedAt: priorVerifiedAt, now: now)
                    continuedGeneration = receipt
                }
                return
            } catch {
                // The sealed proof is stale, cancelled or locally dirty.
                // Apply exactly the generic fail-closed result policy below.
            }
        }
        objectWillChange.send()
        // Subscribers may change account/shop synchronously. Observe current
        // authority again before completing a claim or publishing verification.
        guard candidateRevision == activeProjectionRevision,
              ownsPresentation(expectedPresentationInvocationID),
              automaticRecoveryAuthority?() != false else { return }
        guard canAcceptObservation(from: result) else {
            retireInvalidActiveCandidate(for: result, revision: candidateRevision,
                expectedInvocationID: expectedPresentationInvocationID, authority: automaticRecoveryAuthority)
            return
        }
        if let automaticRecoveryClaim {
            guard completeAutomaticRecoveryAttempt(claim: automaticRecoveryClaim,
                failure: result.failure, now: now) else { return }
        }
        guard acceptObservation(from: result) else { return }
        let acceptedProof = acceptVerifiedProof(from: result, now: now)
        applyRunResult(result, preserveRecoveryRequired: preserveRecoveryRequired, continued: false,
            verified: acceptedProof, verifiedAt: currentVerifiedDate(), now: now)
        continuedGeneration = nil
    }

    private func ownsPresentation(_ expectedInvocationID: UUID?) -> Bool {
        presentationInvocationID == expectedInvocationID
    }

    func abandonPresentationInvocation(_ invocationID: UUID) {
        guard presentationInvocationID == invocationID else { return }
        presentationInvocationID = nil
        recoveryProgressInvocationID = nil
        activeProjectionRevision = UUID()
    }

    func recordCancellationRequest(
        presentationInvocationID expectedInvocationID: UUID?,
        preserveRecoveryRequired: Bool,
        now: Date
    ) {
        let revision = activeProjectionRevision
        guard ownsPresentation(expectedInvocationID) else { return }
        let priorVerifiedAt = currentVerifiedDate()
        objectWillChange.send()
        guard revision == activeProjectionRevision,
              ownsPresentation(expectedInvocationID) else { return }
        // This provisional UI outcome preserves the local operation claim.
        // It does not mint or replace any authoritative observation envelope.
        applyRunResult(.cancelled(), preserveRecoveryRequired: preserveRecoveryRequired,
            continued: false, verified: false, verifiedAt: priorVerifiedAt, now: now,
            preservingPresentationInvocation: true)
        continuedGeneration = nil
    }

    private func retireInvalidActiveCandidate(
        for result: SyncAutomaticRunResult,
        revision: UUID,
        expectedInvocationID: UUID?,
        authority: (@MainActor () -> Bool)?
    ) {
        guard result.continuationReceipt != nil, !result.verifiedConvergence,
              result.status == .success || result.status == .noWork,
              revision == activeProjectionRevision,
              ownsPresentation(expectedInvocationID),
              storedState.phase.isAutomaticWorkActive,
              authority?() != false else { return }
        objectWillChange.send()
        guard revision == activeProjectionRevision,
              ownsPresentation(expectedInvocationID),
              storedState.phase.isAutomaticWorkActive,
              authority?() != false else { return }
        // Ownership is the exact prework ID, not whether a durable commit
        // changed the generation. A caller without an ID cannot retire B.
        storedState.phase = .recoveryRequired
        storedState.startedAt = nil
        storedState.recoveryProgress = nil
        storedState.lastOutcome = nil
        continuedGeneration = nil
        recoveryProgressInvocationID = nil
        presentationInvocationID = nil
        activeProjectionRevision = UUID()
        terminalProjectionHasObservation = false
    }

    private func applyRunResult(
        _ result: SyncAutomaticRunResult,
        preserveRecoveryRequired: Bool,
        continued: Bool,
        verified: Bool,
        verifiedAt qualifiedVerifiedAt: Date?,
        now: Date,
        preservingPresentationInvocation: Bool = false
    ) {
        // This helper is also called with the lease held. It uses plain
        // storage only: no publisher, computed getter or nested scope capture.
        if storedState.phase == .recoveryRequired, result.status == .noWork { return }
        if !preservingPresentationInvocation {
            recoveryProgressInvocationID = nil
            presentationInvocationID = nil
        }
        activeProjectionRevision = UUID()
        terminalProjectionHasObservation = result.observation != nil

        var phase: SyncPhase
        let outcome: SyncOutcome
        let verifiedAt: Date?

        switch result.status {
        case .success:
            outcome = .succeeded
            if verified || continued {
                phase = .idle
                verifiedAt = qualifiedVerifiedAt
            } else {
                phase = .recoveryRequired
                verifiedAt = qualifiedVerifiedAt
            }
        case .noWork:
            if let reason = result.blockReason {
                phase = .blocked(reason)
                outcome = .blocked(reason)
            } else if result.errorCode != nil {
                phase = .failed
                outcome = .failed
            } else if verified || continued {
                phase = .idle
                outcome = .noWork
            } else {
                phase = .recoveryRequired
                outcome = .noWork
            }
            verifiedAt = qualifiedVerifiedAt
        case .recoveryRequired:
            phase = .recoveryRequired
            outcome = .noWork
            verifiedAt = qualifiedVerifiedAt
        case .blocked:
            let reason = result.blockReason ?? .accountDecisionRequired
            phase = .blocked(reason)
            outcome = .blocked(reason)
            verifiedAt = qualifiedVerifiedAt
        case .busy:
            phase = .idle
            outcome = .busy
            verifiedAt = qualifiedVerifiedAt
        case .failed:
            phase = .failed
            outcome = .failed
            verifiedAt = qualifiedVerifiedAt
        case .cancelled:
            phase = .idle
            outcome = .cancelled
            verifiedAt = qualifiedVerifiedAt
        case .scheduledRetry:
            phase = .idle
            outcome = .scheduledRetry
            verifiedAt = qualifiedVerifiedAt
        }

        if recoveryJournalIsPending {
            // A run cannot clear the durable latch merely by returning
            // success/noWork. The atomic recovery coordinator clears the
            // journal only after checkpoint C, baseline and watermark commit.
            phase = .recoveryRequired
        } else if preserveRecoveryRequired, !verified {
            phase = .recoveryRequired
        }

        storedState = SyncState(
            phase: phase,
            progress: nil,
            lastVerifiedAt: verifiedAt,
            lastOutcome: outcome,
            startedAt: nil,
            lastProgressAt: now
        )
        defaults.set(phase.diagnosticsName, forKey: "\(keyPrefix).phase")
        defaults.set(result.status.rawValue, forKey: "\(keyPrefix).lastRunStatus")
        defaults.set(result.didWork, forKey: "\(keyPrefix).lastRunDidWork")
        defaults.set(
            verified,
            forKey: "\(keyPrefix).lastRunVerifiedConvergence"
        )
        defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).lastRunCompletedAt")
        // Legacy date/version bytes are retained as history. They cannot be
        // promoted to scoped v2 evidence by reading the current selection.
        defaults.removeObject(forKey: "\(keyPrefix).activeStartedAt")
        defaults.set(now.timeIntervalSince1970, forKey: "\(keyPrefix).lastProgressAt")
        if let errorCode = result.errorCode {
            defaults.set(errorCode, forKey: "\(keyPrefix).lastRunErrorCode")
        } else {
            defaults.removeObject(forKey: "\(keyPrefix).lastRunErrorCode")
        }
        if let blockReason = result.blockReason {
            defaults.set(blockReason.diagnosticsName, forKey: "\(keyPrefix).lastRunBlockReason")
        } else {
            defaults.removeObject(forKey: "\(keyPrefix).lastRunBlockReason")
        }
    }

    func reconcilePendingRecoveryJournal(now: Date = Date()) {
        guard recoveryJournalIsPending, state.phase != .recoveryRequired else { return }
        updatePhase(.recoveryRequired, now: now)
    }

    private var verifiedProofKey: String { "\(keyPrefix).lastVerifiedProof.v2" }

    private var runObservationKey: String { "\(keyPrefix).lastRunObservation.v1" }

    private nonisolated static func decodedRunObservation(
        defaults: UserDefaults, keyPrefix: String
    ) -> SyncAutomaticRunObservation? {
        guard let data = defaults.data(forKey: "\(keyPrefix).lastRunObservation.v1"), data.count <= 8_192,
              let observation = try? JSONDecoder().decode(SyncAutomaticRunObservation.self, from: data),
              observation.hasValidPersistentFacts else { return nil }
        return observation
    }

    nonisolated static func currentRunObservation(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "sync.runtime.orchestrator",
        ownerUserID: UUID?
    ) -> SyncAutomaticRunObservation? {
        // Presentation cannot infer an authenticated owner from old defaults.
        guard let ownerUserID,
              let observation = decodedRunObservation(defaults: defaults, keyPrefix: keyPrefix),
              observation.origin.isCurrent(defaults: defaults, ownerUserID: ownerUserID) else { return nil }
        return observation
    }

    private func canAcceptObservation(from result: SyncAutomaticRunResult) -> Bool {
        guard let incoming = result.observation else { return true }
        guard incoming.hasValidPersistentFacts, incoming.matches(result),
              incoming.origin.isCurrent(defaults: defaults) else { return false }
        guard let current = Self.decodedRunObservation(defaults: defaults, keyPrefix: keyPrefix),
              current.origin.isCurrent(defaults: defaults) else { return true }
        if current.invocationID == incoming.invocationID { return current == incoming }
        // Equal completion instants do not establish a successor. An older
        // generation/foreign legacy record cannot prevent a new current one.
        if current.origin == incoming.origin { return incoming.completedAt > current.completedAt }
        return true
    }

    private func acceptObservation(from result: SyncAutomaticRunResult) -> Bool {
        guard canAcceptObservation(from: result) else { return false }
        guard let incoming = result.observation else { return true }
        if let current = Self.decodedRunObservation(defaults: defaults, keyPrefix: keyPrefix),
           current.invocationID == incoming.invocationID {
            return current == incoming
        }
        guard let data = try? JSONEncoder().encode(incoming), data.count <= 8_192 else { return false }
        defaults.set(data, forKey: runObservationKey)
        return Self.decodedRunObservation(defaults: defaults, keyPrefix: keyPrefix) == incoming
    }

    private func verifiedProofRecord() -> SyncVerifiedProofRecord? {
        guard let data = defaults.data(forKey: verifiedProofKey), data.count <= 4_096,
              let required = try? JSONDecoder().decode(SyncVerifiedProofRequiredShape.self, from: data),
              let record = try? JSONDecoder().decode(SyncVerifiedProofRecord.self, from: data),
              required.finalization.storeIdentity.exactlyDescribes(record.finalization.storeIdentity),
              record.schemaVersion == SyncVerifiedProofRecord.version,
              record.verifiedAt.isFinite, record.verifiedAt > 0,
              record.finalization.schemaVersion == SyncStoreRecoveryFinalization.currentSchemaVersion,
              Self.isRedactedIdentity(record.finalization.accountHash),
              Self.isRedactedIdentity(record.finalization.deviceIdentityHash),
              Self.isRedactedIdentity(record.finalization.checkpointDigest),
              record.finalization.watermark >= 0,
              !record.finalization.storeIdentity.isEmpty else { return nil }
        return record
    }

    private func currentVerifiedDate() -> Date? {
        guard let record = verifiedProofRecord(),
              hasCurrentAuthority(for: record.finalization) else { return nil }
        return Date(timeIntervalSince1970: record.verifiedAt)
    }

    private func hasCurrentAuthority(for proof: SyncStoreRecoveryFinalization) -> Bool {
        let selection = SelectedShopStore(defaults: defaults)
        let binding = AccountBindingStore(defaults: defaults)
        // Reject an unrelated/anonymous scope before resolving the shared
        // controller. Merely creating a presenter must not open a database.
        guard defaults.string(forKey: "mobile.shopContext.activeAccountHash.v1") == proof.accountHash,
              let currentBinding = binding.currentBinding,
              currentBinding.accountHash == proof.accountHash,
              currentBinding.storeIdentity.hasSameProvenance(as: proof.storeIdentity),
              selection.isResolutionReady(accountHash: proof.accountHash),
              let shop = selection.selectedShop(accountHash: proof.accountHash),
              shop.shopID == proof.shopID, shop.localStoreIdentity.hasSameProvenance(as: proof.storeIdentity),
              LinkedShop(shopID: shop.shopID, code: shop.code, name: shop.name, role: shop.role,
                status: shop.status, selectable: shop.selectable, canWrite: shop.canWrite).isValidSelection,
              let device = try? DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID(),
              DeviceInstallIDStore.identityHash(for: device) == proof.deviceIdentityHash,
              !selection.hasConfirmedDeviceDenial(accountHash: proof.accountHash,
                shopID: proof.shopID, deviceIdentityHash: proof.deviceIdentityHash),
              let controller = storeGenerationController
                ?? (defaults === UserDefaults.standard ? SyncStoreGenerationController.shared : nil),
              controller.loadFailureCode == nil,
              let manifest = controller.activeManifest, proof.exactlyMatches(manifest),
              proof.storeIdentity.hasSameProvenance(as: manifest.storeIdentity),
              Task126OwnerStoreGate.hasCurrentLocalBodyProof(controller.modelContainer) else { return false }
        // Ordinary incremental progress retains the canonical generation and
        // may advance its cursor without restamping the canonical success.
        let watermarks = WatermarkStore(defaults: defaults)
        let scope = WatermarkStore.Scope(accountHash: proof.accountHash, storeIdentity: proof.storeIdentity)
        let currentWatermark = watermarks.watermark(for: scope)
        return currentWatermark >= proof.watermark
            && watermarks.matchesRecoveryGeneration(proof.generationID,
                watermark: currentWatermark, scope: scope)
    }

    private func acceptVerifiedProof(from result: SyncAutomaticRunResult, now: Date) -> Bool {
        guard result.verifiedConvergence,
              result.status == .success || result.status == .noWork,
              result.errorCode == nil, result.blockReason == nil,
              let origin = result.verifiedFinalization,
              hasCurrentAuthority(for: origin),
              let observation = result.observation,
              observation.hasValidPersistentFacts, observation.matches(result),
              observation.origin.isCurrent(defaults: defaults),
              observation.origin.generationID == origin.generationID else { return false }
        if let accepted = verifiedProofRecord(), accepted.finalization == origin,
           accepted.finalization.storeIdentity.hasSameProvenance(as: origin.storeIdentity) {
            // Replaying the exact same proof preserves its first publication.
            return true
        }
        let record = SyncVerifiedProofRecord(schemaVersion: SyncVerifiedProofRecord.version,
            verifiedAt: observation.completedAt, finalization: origin)
        guard let data = try? JSONEncoder().encode(record), data.count <= 4_096 else { return false }
        defaults.set(data, forKey: verifiedProofKey)
        guard let readBack = verifiedProofRecord(), readBack == record else { return false }
        return readBack.finalization.storeIdentity.hasSameProvenance(as: record.finalization.storeIdentity)
    }

    func automaticRecoveryAttemptEligibility(
        identity: String,
        now: Date = Date()
    ) -> SyncAutomaticRecoveryAttemptEligibility {
        guard Self.isRedactedIdentity(identity), now.timeIntervalSince1970.isFinite else { return .exhausted }
        guard defaults.object(forKey: automaticRecoveryAttemptKey) != nil else {
            if defaults.object(forKey: legacyRecoveryAttemptKey) != nil
                || defaults.object(forKey: legacyRecoveryClaimKey) != nil {
                return admitsNewJournalAfterLegacy(identity: identity) ? .ready : .exhausted
            }
            return .ready
        }
        guard let record = automaticRecoveryAttemptRecord() else { return .exhausted }
        guard record.identity == identity else {
            if defaults.object(forKey: legacyRecoveryAttemptKey) != nil
                || defaults.object(forKey: legacyRecoveryClaimKey) != nil {
                return admitsNewJournalAfterLegacy(identity: identity) ? .ready : .exhausted
            }
            return .ready
        }
        // Only the under-flight terminal admission may consume v3 records.
        guard record.publishedFinalization == nil,
              record.lifecycle?.operation != .reconciliation else { return .exhausted }
        if let continuation = record.legacyContinuation {
            guard legacyContinuationIsCurrent(continuation) else { return .exhausted }
        }
        guard record.lastCompletedAt != nil, record.failure?.disposition == .transient else { return .exhausted }
        let remaining = record.nextAllowedAt - now.timeIntervalSince1970
        return remaining > 0 ? .cooldown(remaining) : .ready
    }

    /// Read-only candidacy. The caller must separately qualify the current
    /// body/manifest/authority. Incomplete records need a durable reservation
    /// under processShared before they can authorize any RPC.
    func publishedRecoveryAttemptEligibility(_ descriptor: SyncPublishedRecoveryFinalization,
        now: Date) -> SyncAutomaticRecoveryAttemptEligibility {
        guard now.timeIntervalSince1970.isFinite,
              let data = defaults.data(forKey: automaticRecoveryAttemptKey), data.count <= 12_288,
              Self.hasUniqueJSONKeysPerObject(data),
              let record = automaticRecoveryAttemptRecord(), record.identity == descriptor.identity,
              record.publishedFinalization.map({ $0.matches(descriptor) }) ?? true,
              !Self.liveRecoveryInvocations.contains(record.invocationID) else { return .exhausted }
        if let prepared = record.publishedFinalization, !prepared.claimed {
            let remaining = record.nextAllowedAt - now.timeIntervalSince1970
            return remaining > 0 ? .cooldown(remaining) : .ready
        }
        guard let completed = record.lastCompletedAt else { return .ready }
        guard record.failure?.disposition == .transient || record.failure?.category == .cancelled else { return .exhausted }
        let floor = record.failure?.category == .cancelled ? max(record.nextAllowedAt, completed + 300) : record.nextAllowedAt
        let remaining = floor - now.timeIntervalSince1970
        return remaining > 0 ? .cooldown(remaining) : .ready
    }

    /// Called only by the engine admission callback after actual process-wide
    /// single-flight acquisition. A new interrupted claim gets a new floor;
    /// reopening the SAME prepared claim never moves its floor or counters.
    func admitPublishedRecoveryAttempt(_ descriptor: SyncPublishedRecoveryFinalization,
        now: Date) -> (admission: SyncPublishedRecoveryAdmission, claim: SyncAutomaticRecoveryAttemptClaim?) {
        guard publishedRecoveryAttemptEligibility(descriptor, now: now) != .exhausted,
              var prior = automaticRecoveryAttemptRecord(), prior.identity == descriptor.identity else { return (.rejected, nil) }
        let time = now.timeIntervalSince1970
        guard time >= prior.lastAttemptAt else { return (.rejected, nil) }
        let needsPreparation = prior.publishedFinalization == nil
            || (prior.publishedFinalization?.claimed == true && prior.lastCompletedAt == nil)
        if needsPreparation {
            // A real recorded completion supplies its own floor. Unknown
            // interruption has no invented completion and starts at this read.
            let preparedAt = prior.lastCompletedAt ?? time
            let prepared = SyncPublishedRecoveryPreparation(formatVersion: 1,
                publishedGenerationID: descriptor.generationID, publishedCheckpointDigest: descriptor.checkpointDigest,
                publishedBaselineRunID: descriptor.baselineRunID, preparedForInvocationID: prior.invocationID,
                preparedFromTotalAttempts: prior.totalAttempts, preparedAt: preparedAt, claimed: false)
            var reserved = SyncAutomaticRecoveryAttemptRecord(schemaVersion: prior.schemaVersion == 4 ? 4 : 3, identity: prior.identity,
                invocationID: prior.invocationID, windowIndex: prior.windowIndex, attemptsInWindow: prior.attemptsInWindow,
                totalAttempts: prior.totalAttempts, lastAttemptAt: prior.lastAttemptAt,
                lastCompletedAt: prior.lastCompletedAt, failure: prior.failure,
                nextAllowedAt: max(prior.nextAllowedAt, preparedAt + 300), retryAfterUntil: prior.retryAfterUntil)
            reserved.legacyContinuation = prior.legacyContinuation
            reserved.retiredLegacyReconciliation = prior.retiredLegacyReconciliation
            reserved.publishedFinalization = prepared
            reserved.lifecycle = prior.lifecycle
            reserved.lifecycle?.state = .waiting
            guard persistAutomaticRecoveryAttemptRecord(reserved),
                  let readback = automaticRecoveryAttemptRecord() else { return (.rejected, nil) }
            prior = readback
        }
        let remaining = prior.nextAllowedAt - time
        guard remaining <= 0 else { return (.cooldown(remaining), nil) }
        guard prior.totalAttempts < Int.max, var prepared = prior.publishedFinalization,
              prepared.matches(descriptor) else { return (.rejected, nil) }
        let total = prior.totalAttempts + 1
        let invocationID = UUID()
        prepared.claimed = true
        var claimed = SyncAutomaticRecoveryAttemptRecord(schemaVersion: prior.schemaVersion == 4 ? 4 : 3, identity: prior.identity,
            invocationID: invocationID, windowIndex: (total - 1) / 3 + 1, attemptsInWindow: (total - 1) % 3 + 1,
            totalAttempts: total, lastAttemptAt: time, lastCompletedAt: nil, failure: nil,
            nextAllowedAt: time, retryAfterUntil: prior.retryAfterUntil)
        claimed.legacyContinuation = prior.legacyContinuation
        claimed.retiredLegacyReconciliation = prior.retiredLegacyReconciliation
        claimed.publishedFinalization = prepared
        claimed.lifecycle = prior.lifecycle
        claimed.lifecycle?.processEpoch = recoveryProcessEpoch
        claimed.lifecycle?.state = .running
        guard persistAutomaticRecoveryAttemptRecord(claimed), automaticRecoveryAttemptRecord() != nil else { return (.rejected, nil) }
        Self.liveRecoveryInvocations.insert(invocationID)
        return (.ready, SyncAutomaticRecoveryAttemptClaim(storageKey: automaticRecoveryAttemptKey,
            identity: prior.identity, invocationID: invocationID, attemptInWindow: claimed.attemptsInWindow))
    }

    /// Records an actual cancelled outcome after qualified publication only.
    /// It does not accept the old generation's observation, date or UI state.
    func recordPublishedRecoveryCancellation(_ claim: SyncAutomaticRecoveryAttemptClaim, now: Date) -> Bool {
        completeAutomaticRecoveryAttempt(claim: claim,
            failure: AutomaticSyncFailure(disposition: .stable, category: .cancelled), now: now,
            minimumDelay: 300, requiresDurableWrite: true)
    }

    /// This authorizes local preflight only. Atomic must validate the accepted
    /// prefix read-only before it invokes the durable attempt claim.
    func legacyRecoveryContinuation(identity: String, now: Date) -> SyncLegacyRecoveryContinuation? {
        guard let journal = pendingRecoveryJournal, journal.mode == .sameScopeRecovery,
              journal.phase == .staging, let generationID = journal.generationID,
              SyncOrchestrator.automaticRecoveryResumeIdentity(for: journal) == identity else { return nil }
        if defaults.object(forKey: automaticRecoveryAttemptKey) != nil {
            guard let record = automaticRecoveryAttemptRecord(), record.identity == identity,
                  let continuation = record.legacyContinuation,
                  continuation.generationID == generationID,
                  automaticRecoveryAttemptEligibility(identity: identity, now: now) == .ready else { return nil }
            return continuation
        }
        guard defaults.object(forKey: legacyRecoveryClaimKey) == nil,
              let legacy = legacyRecoveryBytes(), legacy.identity == identity,
              now.timeIntervalSince1970.isFinite, legacy.deadline <= now.timeIntervalSince1970 else { return nil }
        return SyncLegacyRecoveryContinuation(identity: identity,
            legacySHA256: Self.legacyDigest(legacy.data), generationID: generationID)
    }

    private static func legacyDigest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// These two bounded schemas have disjoint key names, including the
    /// continuation object. Foundation otherwise silently collapses duplicate
    /// keys. Tokenize every complete string first, then decode only keys;
    /// escaped text inside a value must never be mistaken for an object key.
    private static func hasUniqueLegacyJSONKeys(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8),
              let tokens = try? NSRegularExpression(pattern: #""(?:[^"\\]|\\.)*""#) else { return false }
        let source = text as NSString
        var keys = Set<String>()
        for token in tokens.matches(in: text, range: NSRange(location: 0, length: source.length)) {
            var cursor = NSMaxRange(token.range)
            while cursor < source.length, [9, 10, 13, 32].contains(Int(source.character(at: cursor))) { cursor += 1 }
            guard cursor < source.length, source.character(at: cursor) == 58 else { continue }
            let literal = source.substring(with: token.range)
            guard let key = try? JSONDecoder().decode(String.self, from: Data(literal.utf8)),
                  keys.insert(key).inserted else { return false }
        }
        return true
    }

    private func legacyRecoveryBytes() -> (data: Data, identity: String, deadline: TimeInterval)? {
        guard let data = defaults.data(forKey: legacyRecoveryAttemptKey), data.count <= 1_024,
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Self.hasUniqueLegacyJSONKeys(data),
              Set(raw.keys) == ["schemaVersion", "identity", "attemptCount", "nextAllowedAt"],
              let version = raw["schemaVersion"] as? NSNumber, CFGetTypeID(version) != CFBooleanGetTypeID(),
              version.doubleValue == 1,
              let identity = raw["identity"] as? String, Self.isRedactedIdentity(identity),
              let count = raw["attemptCount"] as? NSNumber, CFGetTypeID(count) != CFBooleanGetTypeID(),
              count.doubleValue == 3,
              let deadline = raw["nextAllowedAt"] as? NSNumber, CFGetTypeID(deadline) != CFBooleanGetTypeID(),
              deadline.doubleValue.isFinite, deadline.doubleValue > 0 else { return nil }
        return (data, identity, deadline.doubleValue)
    }

    private func legacyRecoveryClaimRecord() -> SyncLegacyRecoveryClaimRecord? {
        guard let data = defaults.data(forKey: legacyRecoveryClaimKey), data.count <= 1_024,
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Self.hasUniqueLegacyJSONKeys(data),
              Set(raw.keys) == ["schemaVersion", "continuation", "invocationID", "claimedAt"],
              let nested = raw["continuation"] as? [String: Any],
              Set(nested.keys) == ["identity", "legacySHA256", "generationID"],
              let record = try? JSONDecoder().decode(SyncLegacyRecoveryClaimRecord.self, from: data),
              record.schemaVersion == 1, record.claimedAt.isFinite,
              let legacy = legacyRecoveryBytes(), record.claimedAt >= legacy.deadline,
              record.continuation.identity == legacy.identity,
              record.continuation.legacySHA256 == Self.legacyDigest(legacy.data) else { return nil }
        return record
    }

    private func admitsNewJournalAfterLegacy(identity: String) -> Bool {
        guard let journal = pendingRecoveryJournal,
              SyncOrchestrator.automaticRecoveryResumeIdentity(for: journal) == identity else { return false }
        if let claim = legacyRecoveryClaimRecord(), claim.continuation.identity != identity { return true }
        guard let record = automaticRecoveryAttemptRecord(), record.identity != identity,
              record.lifecycle?.state == .completed,
              !Self.liveRecoveryInvocations.contains(record.invocationID) else { return false }
        if isCompletedLegacyReconciliation(record) { return true }
        guard let bytes = record.retiredLegacyReconciliation,
              let retired = automaticRecoveryAttemptRecord(data: bytes, allowsRetiredLegacyHistory: false) else { return false }
        return retired.identity != identity && isCompletedLegacyReconciliation(retired)
    }

    private func isCompletedLegacyReconciliation(_ record: SyncAutomaticRecoveryAttemptRecord) -> Bool {
        guard record.schemaVersion == 4, record.lifecycle?.operation == .reconciliation,
              record.lifecycle?.state == .completed,
              !Self.liveRecoveryInvocations.contains(record.invocationID),
              record.retiredLegacyReconciliation == nil,
              record.lifecycle?.originPayload == defaults.data(forKey: legacyRecoveryAttemptKey),
              let legacy = reconciliationLegacyRecord(identity: record.identity) else { return false }
        return record.totalAttempts > legacy.totalAttempts
    }

    private func legacyContinuationIsCurrent(_ continuation: SyncLegacyRecoveryContinuation) -> Bool {
        guard legacyRecoveryClaimRecord()?.continuation == continuation,
              let journal = pendingRecoveryJournal, journal.mode == .sameScopeRecovery,
              journal.phase == .staging, journal.generationID == continuation.generationID,
              SyncOrchestrator.automaticRecoveryResumeIdentity(for: journal) == continuation.identity else { return false }
        return true
    }

    @discardableResult
    func beginAutomaticRecoveryAttempt(identity: String, now: Date = Date()) -> Int? {
        claimAutomaticRecoveryAttempt(identity: identity, now: now)?.attemptInWindow
    }

    func claimAutomaticRecoveryAttempt(identity: String, now: Date = Date(),
        legacyContinuation: SyncLegacyRecoveryContinuation? = nil,
        reconciliation: SyncRecoveryReconciliation? = nil) -> SyncAutomaticRecoveryAttemptClaim? {
        if let reconciliation {
            guard legacyContinuation == nil else { return nil }
            return claimRecoveryReconciliation(reconciliation, identity: identity, now: now)
        }
        let initialLegacy = legacyContinuation != nil && defaults.object(forKey: automaticRecoveryAttemptKey) == nil
        if let legacyContinuation {
            guard self.legacyRecoveryContinuation(identity: identity, now: now) == legacyContinuation else { return nil }
        } else {
            guard automaticRecoveryAttemptEligibility(identity: identity, now: now) == .ready,
                  automaticRecoveryAttemptRecord().map({ $0.identity != identity || $0.legacyContinuation == nil }) ?? true else { return nil }
        }
        let previous = automaticRecoveryAttemptRecord()
        let prior = previous.flatMap { $0.identity == identity ? $0 : nil }
        let newWindow = prior?.attemptsInWindow == 3
        let attempt = newWindow ? 1 : (prior?.attemptsInWindow ?? 0) + 1
        let priorTotal = prior?.totalAttempts ?? (initialLegacy ? 3 : 0)
        let priorWindow = prior?.windowIndex ?? (initialLegacy ? 2 : 1)
        guard priorTotal < Int.max, !newWindow || priorWindow < Int.max else { return nil }
        let invocationID = UUID()
        var record = SyncAutomaticRecoveryAttemptRecord(schemaVersion: 4, identity: identity, invocationID: invocationID,
            windowIndex: priorWindow + (newWindow ? 1 : 0), attemptsInWindow: attempt,
            totalAttempts: priorTotal + 1, lastAttemptAt: now.timeIntervalSince1970,
            lastCompletedAt: nil, failure: nil, nextAllowedAt: now.timeIntervalSince1970,
            retryAfterUntil: prior?.retryAfterUntil)
        record.legacyContinuation = legacyContinuation
        record.lifecycle = freshLifecycle(operation: .automatic, origin: prior)
        record.retiredLegacyReconciliation = previous?.retiredLegacyReconciliation
        if let previous, previous.identity != identity, isCompletedLegacyReconciliation(previous) {
            guard let bytes = defaults.data(forKey: automaticRecoveryAttemptKey), bytes.count <= 8_192 else { return nil }
            record.retiredLegacyReconciliation = bytes
        }
        if initialLegacy, let legacyContinuation {
            // Claim first, then retry metadata. A crash between these writes
            // consumes the one-shot opportunity; no transport has started.
            let claim = SyncLegacyRecoveryClaimRecord(schemaVersion: 1, continuation: legacyContinuation,
                invocationID: invocationID, claimedAt: now.timeIntervalSince1970)
            guard let bytes = try? JSONEncoder().encode(claim) else { return nil }
            defaults.set(bytes, forKey: legacyRecoveryClaimKey)
            // This one-shot claim must reach disk before any diagnostic RPC.
            // A cache readback alone cannot establish that ordering.
            guard defaults.synchronize(), defaults.data(forKey: legacyRecoveryClaimKey) == bytes,
                  legacyRecoveryClaimRecord() == claim else { return nil }
        }
        guard persistAutomaticRecoveryAttemptRecord(record, requiresDurableWrite: true) else { return nil }
        Self.liveRecoveryInvocations.insert(invocationID)
        return SyncAutomaticRecoveryAttemptClaim(storageKey: automaticRecoveryAttemptKey,
            identity: identity, invocationID: invocationID, attemptInWindow: attempt)
    }

    private func completeAutomaticRecoveryAttempt(claim: SyncAutomaticRecoveryAttemptClaim,
        failure: AutomaticSyncFailure?, now: Date, minimumDelay: TimeInterval = 0,
        requiresDurableWrite: Bool = false) -> Bool {
        guard ownsAutomaticRecoveryAttempt(claim), let record = automaticRecoveryAttemptRecord(),
              now.timeIntervalSince1970 >= record.lastAttemptAt else { return false }
        let completed = now.timeIntervalSince1970
        let failure = failure ?? AutomaticSyncFailure(disposition: .unknown, category: .unknown)
        let suppliedRetryAfter = failure.retryAfterUntil?.timeIntervalSince1970
        let retryAfter = [record.retryAfterUntil, suppliedRetryAfter].compactMap { $0 }.max()
        let sample = retryJitter()
        let jitter = sample.isFinite ? min(1.5, max(0.5, sample)) : 1
        let localDelay = failure.disposition == .reconciliation || failure.category == .cancelled || record.lifecycle?.operation == .reconciliation || record.legacyContinuation != nil || record.attemptsInWindow == 3 ? 300
            : min(60, 2 * pow(2, Double(record.attemptsInWindow - 1)) * jitter)
        let nextAllowedAt = max(completed + max(localDelay, minimumDelay), retryAfter ?? 0)
        var updated = SyncAutomaticRecoveryAttemptRecord(schemaVersion: record.schemaVersion, identity: record.identity, invocationID: record.invocationID,
            windowIndex: record.windowIndex, attemptsInWindow: record.attemptsInWindow,
            totalAttempts: record.totalAttempts, lastAttemptAt: record.lastAttemptAt,
            lastCompletedAt: completed, failure: failure, nextAllowedAt: nextAllowedAt,
            retryAfterUntil: retryAfter)
        updated.legacyContinuation = record.legacyContinuation
        updated.retiredLegacyReconciliation = record.retiredLegacyReconciliation
        updated.publishedFinalization = record.publishedFinalization
        updated.lifecycle = record.lifecycle
        updated.lifecycle?.state = failure.disposition == .transient || failure.disposition == .unknown || failure.disposition == .reconciliation
            || failure.category == .cancelled ? .waiting : .blocked
        let persisted = persistAutomaticRecoveryAttemptRecord(updated, requiresDurableWrite: requiresDurableWrite)
        if persisted { Self.liveRecoveryInvocations.remove(claim.invocationID) }
        return persisted
    }

    func ownsAutomaticRecoveryAttempt(_ claim: SyncAutomaticRecoveryAttemptClaim) -> Bool {
        guard claim.storageKey == automaticRecoveryAttemptKey,
              Self.liveRecoveryInvocations.contains(claim.invocationID),
              let record = automaticRecoveryAttemptRecord(), record.lastCompletedAt == nil,
              record.publishedFinalization?.claimed != false else { return false }
        return record.identity == claim.identity && record.invocationID == claim.invocationID
            && record.attemptsInWindow == claim.attemptInWindow
    }

    func extendAutomaticRecoveryAttemptCooldown(identity: String, requestedDelay: TimeInterval,
        now: Date = Date()) -> TimeInterval {
        guard requestedDelay.isFinite, requestedDelay >= 0 else { return .infinity }
        guard let record = automaticRecoveryAttemptRecord(), record.identity == identity else { return requestedDelay }
        let target = max(record.nextAllowedAt, now.timeIntervalSince1970 + requestedDelay)
        var updated = SyncAutomaticRecoveryAttemptRecord(schemaVersion: record.schemaVersion,
            identity: record.identity, invocationID: record.invocationID, windowIndex: record.windowIndex,
            attemptsInWindow: record.attemptsInWindow, totalAttempts: record.totalAttempts,
            lastAttemptAt: record.lastAttemptAt, lastCompletedAt: record.lastCompletedAt,
            failure: record.failure, nextAllowedAt: target, retryAfterUntil: record.retryAfterUntil)
        updated.legacyContinuation = record.legacyContinuation
        updated.retiredLegacyReconciliation = record.retiredLegacyReconciliation
        updated.publishedFinalization = record.publishedFinalization
        updated.lifecycle = record.lifecycle
        guard persistAutomaticRecoveryAttemptRecord(updated) else { return .infinity }
        return max(0, target - now.timeIntervalSince1970)
    }

    func resetAutomaticRecoveryAttemptBudget(preservingLegacyHistory: Bool = false) {
        defaults.removeObject(forKey: automaticRecoveryAttemptKey)
        if !preservingLegacyHistory {
            defaults.removeObject(forKey: legacyRecoveryAttemptKey)
            defaults.removeObject(forKey: legacyRecoveryClaimKey)
        }
    }

    private func automaticRecoveryAttemptRecord(data suppliedData: Data? = nil,
        allowsRetiredLegacyHistory: Bool = true) -> SyncAutomaticRecoveryAttemptRecord? {
        guard let data = suppliedData ?? defaults.data(forKey: automaticRecoveryAttemptKey), data.count <= 12_288,
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let record = try? JSONDecoder().decode(SyncAutomaticRecoveryAttemptRecord.self, from: data),
              (2...4).contains(record.schemaVersion),
              (record.schemaVersion == 2 ? Self.hasValidV2RecoveryRecordShape(data, raw: raw)
                : record.schemaVersion == 3 ? Self.hasValidPublishedRecordShape(data, raw: raw)
                : Self.hasValidRecoveryLifecycleShape(data, raw: raw, record: record)),
              Self.isRedactedIdentity(record.identity), record.windowIndex >= 1,
              (1...3).contains(record.attemptsInWindow), record.totalAttempts >= record.attemptsInWindow,
              (record.totalAttempts - 1) / 3 + 1 == record.windowIndex,
              (record.totalAttempts - 1) % 3 + 1 == record.attemptsInWindow,
              record.lastAttemptAt.isFinite, record.lastAttemptAt > 0,
              record.nextAllowedAt.isFinite, record.nextAllowedAt >= record.lastAttemptAt,
              record.lastCompletedAt.map({ $0.isFinite && $0 >= record.lastAttemptAt }) ?? true,
              record.retryAfterUntil.map({ $0.isFinite && $0 > 0 }) ?? true,
              record.failure.map(\.hasValidPersistentFacts) ?? true,
              (record.lastCompletedAt == nil) == (record.failure == nil),
              record.lastCompletedAt.map({ record.nextAllowedAt >= $0 }) ?? true,
              record.retryAfterUntil.map({ record.nextAllowedAt >= $0 }) ?? true else { return nil }
        var retiredLegacy: SyncAutomaticRecoveryAttemptRecord?
        if let bytes = record.retiredLegacyReconciliation {
            guard allowsRetiredLegacyHistory, record.schemaVersion == 4, bytes.count <= 8_192,
                  let retired = automaticRecoveryAttemptRecord(data: bytes, allowsRetiredLegacyHistory: false),
                  retired.identity != record.identity, isCompletedLegacyReconciliation(retired) else { return nil }
            retiredLegacy = retired
        }
        if let continuation = record.legacyContinuation {
            guard continuation.identity == record.identity, record.totalAttempts >= 4,
                  let claim = legacyRecoveryClaimRecord(), claim.continuation == continuation,
                  record.lastAttemptAt >= claim.claimedAt,
                  record.totalAttempts != 4 || record.invocationID == claim.invocationID else { return nil }
        } else if defaults.object(forKey: legacyRecoveryAttemptKey) != nil
            || defaults.object(forKey: legacyRecoveryClaimKey) != nil {
            let isQualifiedLegacyReconciliation = record.schemaVersion == 4
                && record.lifecycle?.operation == .reconciliation
                && record.lifecycle?.originPayload == defaults.data(forKey: legacyRecoveryAttemptKey)
                && reconciliationLegacyRecord(identity: record.identity) != nil
            guard isQualifiedLegacyReconciliation || retiredLegacy != nil
                || legacyRecoveryClaimRecord().map({ $0.continuation.identity != record.identity }) == true else { return nil }
        }
        if record.publishedFinalization != nil {
            guard let prepared = record.publishedFinalization, prepared.formatVersion == 1,
                  Self.isRedactedIdentity(prepared.publishedCheckpointDigest),
                  prepared.preparedAt.isFinite, prepared.preparedAt > 0,
                  prepared.preparedFromTotalAttempts >= 1 else { return nil }
            if prepared.claimed {
                guard record.totalAttempts > prepared.preparedFromTotalAttempts,
                      record.invocationID != prepared.preparedForInvocationID,
                      record.lastAttemptAt >= prepared.preparedAt + 300 else { return nil }
            } else {
                guard record.totalAttempts == prepared.preparedFromTotalAttempts,
                      record.invocationID == prepared.preparedForInvocationID,
                      prepared.preparedAt >= record.lastAttemptAt,
                      record.lastCompletedAt.map({ prepared.preparedAt == $0 }) ?? true,
                      record.nextAllowedAt >= prepared.preparedAt + 300,
                      record.failure.map({ $0.disposition == .transient || $0.category == .cancelled }) ?? true else { return nil }
            }
        }
        if let completed = record.lastCompletedAt, record.failure?.disposition == .transient {
            let minimumDelay = record.legacyContinuation != nil || record.attemptsInWindow == 3 ? 300 : pow(2, Double(record.attemptsInWindow - 1))
            guard record.nextAllowedAt >= completed + minimumDelay else { return nil }
        }
        if record.schemaVersion == 4, let completed = record.lastCompletedAt,
           record.lifecycle?.operation == .reconciliation || record.failure?.disposition == .reconciliation
            || record.failure?.category == .cancelled {
            guard record.nextAllowedAt >= completed + 300 else { return nil }
        }
        if let serverMinimum = record.failure?.retryAfterUntil?.timeIntervalSince1970 {
            guard record.nextAllowedAt >= serverMinimum else { return nil }
        }
        return record
    }

    private func persistAutomaticRecoveryAttemptRecord(
        _ record: SyncAutomaticRecoveryAttemptRecord, requiresDurableWrite: Bool = false
    ) -> Bool {
        guard let data = try? JSONEncoder().encode(record), data.count <= 12_288 else { return false }
        defaults.set(data, forKey: automaticRecoveryAttemptKey)
        // Preserve the same before-RPC persistence fence for later claims in
        // this lineage; otherwise a crash could revive a completed predecessor.
        if requiresDurableWrite || record.schemaVersion == 4 || record.legacyContinuation != nil || record.publishedFinalization != nil {
            guard defaults.synchronize() else { return false }
        }
        return defaults.data(forKey: automaticRecoveryAttemptKey) == data
    }

    private static func hasValidV2RecoveryRecordShape(_ data: Data, raw: [String: Any]) -> Bool {
        let required: Set<String> = ["schemaVersion", "identity", "invocationID", "windowIndex", "attemptsInWindow",
            "totalAttempts", "lastAttemptAt", "nextAllowedAt"]
        let optional: Set<String> = ["lastCompletedAt", "failure", "retryAfterUntil", "legacyContinuation"]
        guard data.count <= 4_096, required.isSubset(of: Set(raw.keys)),
              Set(raw.keys).isSubset(of: required.union(optional)), hasUniqueJSONKeysPerObject(data) else { return false }
        if let failure = raw["failure"] as? [String: Any] {
            let failureRequired: Set<String> = ["disposition", "category"]
            let failureOptional: Set<String> = ["httpStatus", "urlErrorCode", "sqlState", "retryAfterUntil"]
            guard failureRequired.isSubset(of: Set(failure.keys)),
                  Set(failure.keys).isSubset(of: failureRequired.union(failureOptional)),
                  failure["disposition"] as? String != AutomaticSyncFailure.Disposition.reconciliation.rawValue else { return false }
        }
        if let continuation = raw["legacyContinuation"] as? [String: Any] {
            guard Set(continuation.keys) == ["identity", "legacySHA256", "generationID"] else { return false }
        }
        return true
    }

    /// Foundation collapses duplicate keys. After validating JSON grammar,
    /// tokenize complete strings/punctuation and check names per object, so
    /// nested failure/legacy objects may legitimately reuse field names.
    private static func hasValidPublishedRecordShape(_ data: Data, raw: [String: Any]) -> Bool {
        let required: Set<String> = ["schemaVersion", "identity", "invocationID", "windowIndex", "attemptsInWindow",
            "totalAttempts", "lastAttemptAt", "nextAllowedAt", "publishedFinalization"]
        let optional: Set<String> = ["lastCompletedAt", "failure", "retryAfterUntil", "legacyContinuation"]
        guard data.count <= 4_096, required.isSubset(of: Set(raw.keys)),
              Set(raw.keys).isSubset(of: required.union(optional)),
              let nested = raw["publishedFinalization"] as? [String: Any],
              Set(nested.keys) == ["formatVersion", "publishedGenerationID", "publishedCheckpointDigest",
                "publishedBaselineRunID", "preparedForInvocationID", "preparedFromTotalAttempts", "preparedAt", "claimed"],
              Self.hasUniqueJSONKeysPerObject(data) else { return false }
        return true
    }

    private static func hasUniqueJSONKeysPerObject(_ data: Data) -> Bool {
        guard (try? JSONSerialization.jsonObject(with: data)) != nil,
              let text = String(data: data, encoding: .utf8),
              let regex = try? NSRegularExpression(pattern: #""(?:[^"\\]|\\.)*"|[{}\[\]:,]"#) else { return false }
        let source = text as NSString
        let tokens = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
            .map { source.substring(with: $0.range) }
        var objects: [Set<String>?] = []
        for (index, token) in tokens.enumerated() {
            if token == "{" { objects.append([]) }
            else if token == "[" { objects.append(nil) }
            else if token == "}" || token == "]" { guard !objects.isEmpty else { return false }; objects.removeLast() }
            else if token.utf8.first == 34, index + 1 < tokens.count, tokens[index + 1] == ":" {
                guard !objects.isEmpty, var keys = objects.removeLast(),
                      let key = try? JSONDecoder().decode(String.self, from: Data(token.utf8)),
                      keys.insert(key).inserted else { return false }
                objects.append(keys)
            }
        }
        return objects.isEmpty
    }

    /// Reconciliation never converts an unknown result into a transient one.
    /// It admits only the existing recovery phase, after its local proof, and
    /// does not select or replay business mutations.
    func recoveryReconciliationOpportunity(identity: String, now: Date = Date()) -> SyncRecoveryReconciliationOpportunity {
        recoveryReconciliationBlockReason = nil
        guard Self.isRedactedIdentity(identity), now.timeIntervalSince1970.isFinite,
              let journal = pendingRecoveryJournal, journal.mode == .sameScopeRecovery,
              SyncOrchestrator.automaticRecoveryResumeIdentity(for: journal) == identity else { return blockedRecoveryReconciliation("journal_or_scope_unavailable") }
        guard journal.phase == .prepared || journal.phase == .staging else { return .none }
        let time = now.timeIntervalSince1970
        var record: SyncAutomaticRecoveryAttemptRecord
        var original: Data
        var needsConservativeFloor = true
        var minimumKnownDue: TimeInterval?
        if let bytes = defaults.data(forKey: automaticRecoveryAttemptKey) {
            guard let decoded = automaticRecoveryAttemptRecord() else { return blockedRecoveryReconciliation("retry_metadata_invalid_or_foreign") }
            if decoded.identity != identity {
                guard decoded.lifecycle?.state == .completed,
                      !Self.liveRecoveryInvocations.contains(decoded.invocationID),
                      (defaults.object(forKey: legacyRecoveryAttemptKey) == nil
                        && defaults.object(forKey: legacyRecoveryClaimKey) == nil)
                        || admitsNewJournalAfterLegacy(identity: identity) else {
                    return blockedRecoveryReconciliation("retry_metadata_invalid_or_foreign")
                }
                return .none
            }
            guard decoded.publishedFinalization == nil else { return .none }
            guard !Self.liveRecoveryInvocations.contains(decoded.invocationID) else { return blockedRecoveryReconciliation("current_process_owner_running") }
            if let lifecycle = decoded.lifecycle, lifecycle.state == .running,
               lifecycle.processEpoch == recoveryProcessEpoch { return blockedRecoveryReconciliation("owner_release_not_proved") }
            if decoded.lifecycle?.state == .completed { return .none }
            if let failure = decoded.failure, failure.disposition == .stable, failure.category != .cancelled {
                return blockedRecoveryReconciliation("stable_failure_requires_qualified_change")
            }
            if decoded.lastCompletedAt != nil, decoded.failure?.disposition == .transient,
               decoded.lifecycle?.operation != .reconciliation { return .none }
            record = decoded
            original = bytes
            // A recorded release already established its conservative due.
            // Observing it later must not create a second cooldown.
            if decoded.lifecycle?.state == .interrupted { needsConservativeFloor = false }
            if let completed = decoded.lastCompletedAt,
               decoded.failure?.disposition == .reconciliation || decoded.failure?.category == .cancelled {
                needsConservativeFloor = false
                minimumKnownDue = completed + 300
            }
        } else if let legacy = reconciliationLegacyRecord(identity: identity) {
            // The old format has an explicit due timestamp. Qualify its
            // actual phase/prefix instead of assuming that staging has rows.
            // No extra cooldown may postpone an already qualified legacy due.
            needsConservativeFloor = legacy.claim != nil
            if let claim = legacy.claim {
                guard journal.phase == .staging, journal.generationID == claim.continuation.generationID else {
                    return blockedRecoveryReconciliation("legacy_claim_generation_mismatch")
                }
            }
            original = legacy.bytes
            // A claim fsynced before the old v2 write already consumed its
            // attempt, even if the process never reached the network call.
            let total = legacy.totalAttempts + (legacy.claim == nil ? 0 : 1)
            record = SyncAutomaticRecoveryAttemptRecord(schemaVersion: 4, identity: identity,
                invocationID: legacy.claim?.invocationID ?? UUID(), windowIndex: (total - 1) / 3 + 1,
                attemptsInWindow: (total - 1) % 3 + 1, totalAttempts: total,
                lastAttemptAt: legacy.claim?.claimedAt ?? time, lastCompletedAt: nil, failure: nil,
                nextAllowedAt: max(time, legacy.deadline), retryAfterUntil: nil)
            record.legacyContinuation = legacy.claim?.continuation
        } else {
            return defaults.object(forKey: legacyRecoveryAttemptKey) == nil
                && defaults.object(forKey: legacyRecoveryClaimKey) == nil ? .none : blockedRecoveryReconciliation("legacy_metadata_invalid_or_incomplete")
        }
        guard time >= record.lastAttemptAt else { return blockedRecoveryReconciliation("clock_precedes_recorded_attempt") }
        if record.lifecycle?.operation != .reconciliation || record.lifecycle?.state == .running {
            let origin = record.lifecycle?.originPayload ?? original
            guard origin.count <= 4_096 else { return blockedRecoveryReconciliation("origin_payload_exceeds_bound") }
            let conservativeDue = needsConservativeFloor ? time + 300 : max(record.nextAllowedAt, minimumKnownDue ?? 0)
            var prepared = SyncAutomaticRecoveryAttemptRecord(schemaVersion: 4, identity: record.identity,
                invocationID: record.invocationID, windowIndex: record.windowIndex,
                attemptsInWindow: record.attemptsInWindow, totalAttempts: record.totalAttempts,
                lastAttemptAt: record.lastAttemptAt, lastCompletedAt: record.lastCompletedAt,
                failure: record.failure, nextAllowedAt: max(record.nextAllowedAt, max(conservativeDue, record.retryAfterUntil ?? 0)),
                retryAfterUntil: record.retryAfterUntil)
            prepared.legacyContinuation = record.legacyContinuation
            prepared.retiredLegacyReconciliation = record.retiredLegacyReconciliation
            prepared.lifecycle = SyncRecoveryAttemptLifecycle(formatVersion: 1, processEpoch: recoveryProcessEpoch,
                operation: .reconciliation, state: .waiting, phase: journal.phase, generationID: journal.generationID,
                firstObservedAt: record.lifecycle?.firstObservedAt ?? time, originPayload: origin, originSHA256: Self.legacyDigest(origin),
                originalAttemptTimeUnknown: defaults.object(forKey: automaticRecoveryAttemptKey) == nil
                    && legacyRecoveryClaimRecord() == nil)
            guard persistAutomaticRecoveryAttemptRecord(prepared, requiresDurableWrite: true),
                  let saved = automaticRecoveryAttemptRecord() else { return blockedRecoveryReconciliation("reconciliation_persistence_not_verified") }
            record = saved
        }
        guard record.lifecycle?.state == .waiting || record.lifecycle?.state == .interrupted else { return blockedRecoveryReconciliation("reconciliation_state_requires_review") }
        let remaining = record.nextAllowedAt - time
        if remaining > 0 { return .cooldown(remaining) }
        guard let bytes = defaults.data(forKey: automaticRecoveryAttemptKey) else { return blockedRecoveryReconciliation("retry_metadata_unavailable") }
        let originObject = (record.lifecycle?.originPayload).flatMap {
            (try? JSONSerialization.jsonObject(with: $0)) as? [String: Any]
        }
        let legacyOrigin = record.legacyContinuation != nil || (originObject?["schemaVersion"] as? Int) == 1
        return .ready(SyncRecoveryReconciliation(identity: identity, sourceDigest: Self.legacyDigest(bytes),
            journal: journal, isLegacyOrigin: legacyOrigin))
    }

    private func blockedRecoveryReconciliation(_ reason: String) -> SyncRecoveryReconciliationOpportunity {
        recoveryReconciliationBlockReason = reason
        return .blocked
    }

    private func reconciliationLegacyRecord(identity: String) -> (bytes: Data, totalAttempts: Int,
        deadline: TimeInterval, claim: SyncLegacyRecoveryClaimRecord?)? {
        guard let bytes = defaults.data(forKey: legacyRecoveryAttemptKey), bytes.count <= 1_024,
              Self.hasUniqueLegacyJSONKeys(bytes),
              let raw = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              Set(raw.keys) == ["schemaVersion", "identity", "attemptCount", "nextAllowedAt"],
              let version = raw["schemaVersion"] as? NSNumber, CFGetTypeID(version) != CFBooleanGetTypeID(),
              version.doubleValue == 1, raw["identity"] as? String == identity,
              let count = raw["attemptCount"] as? NSNumber, CFGetTypeID(count) != CFBooleanGetTypeID(),
              count.doubleValue >= 1, count.doubleValue < Double(Int.max),
              count.doubleValue.rounded(.towardZero) == count.doubleValue,
              let deadline = raw["nextAllowedAt"] as? NSNumber, CFGetTypeID(deadline) != CFBooleanGetTypeID(),
              deadline.doubleValue.isFinite, deadline.doubleValue > 0 else { return nil }
        let claim = legacyRecoveryClaimRecord()
        if defaults.object(forKey: legacyRecoveryClaimKey) != nil,
           claim?.continuation.identity != identity { return nil }
        return (bytes, count.intValue, deadline.doubleValue, claim)
    }

    private func freshLifecycle(operation: SyncRecoveryAttemptLifecycle.Operation,
        origin: SyncAutomaticRecoveryAttemptRecord?) -> SyncRecoveryAttemptLifecycle {
        SyncRecoveryAttemptLifecycle(formatVersion: 1, processEpoch: recoveryProcessEpoch,
            operation: operation, state: .running, phase: pendingRecoveryJournal?.phase,
            generationID: pendingRecoveryJournal?.generationID,
            firstObservedAt: origin?.lifecycle?.firstObservedAt,
            originPayload: origin?.lifecycle?.originPayload, originSHA256: origin?.lifecycle?.originSHA256,
            originalAttemptTimeUnknown: origin?.lifecycle?.originalAttemptTimeUnknown ?? false)
    }

    private func claimRecoveryReconciliation(_ descriptor: SyncRecoveryReconciliation,
        identity: String, now: Date) -> SyncAutomaticRecoveryAttemptClaim? {
        guard descriptor.identity == identity, pendingRecoveryJournal == descriptor.journal,
              case .ready(let current) = recoveryReconciliationOpportunity(identity: identity, now: now),
              current == descriptor, let prior = automaticRecoveryAttemptRecord(),
              prior.totalAttempts < Int.max else { return nil }
        let total = prior.totalAttempts + 1
        let invocation = UUID()
        var claimed = SyncAutomaticRecoveryAttemptRecord(schemaVersion: 4, identity: identity,
            invocationID: invocation, windowIndex: (total - 1) / 3 + 1,
            attemptsInWindow: (total - 1) % 3 + 1, totalAttempts: total,
            lastAttemptAt: now.timeIntervalSince1970, lastCompletedAt: nil, failure: nil,
            nextAllowedAt: max(now.timeIntervalSince1970, prior.retryAfterUntil ?? 0), retryAfterUntil: prior.retryAfterUntil)
        claimed.legacyContinuation = prior.legacyContinuation
        claimed.retiredLegacyReconciliation = prior.retiredLegacyReconciliation
        claimed.lifecycle = freshLifecycle(operation: .reconciliation, origin: prior)
        guard persistAutomaticRecoveryAttemptRecord(claimed, requiresDurableWrite: true),
              automaticRecoveryAttemptRecord() != nil else { return nil }
        Self.liveRecoveryInvocations.insert(invocation)
        return SyncAutomaticRecoveryAttemptClaim(storageKey: automaticRecoveryAttemptKey, identity: identity,
            invocationID: invocation, attemptInWindow: claimed.attemptsInWindow)
    }

    /// Call only after the actual runtime has settled, including cancellation.
    /// A released unknown operation is not reported as completed or transient.
    func releaseAutomaticRecoveryAttempt(_ claim: SyncAutomaticRecoveryAttemptClaim, now: Date = Date(),
        allowsPersistentMetadata: Bool = true) {
        guard Self.liveRecoveryInvocations.contains(claim.invocationID) else { return }
        defer { Self.liveRecoveryInvocations.remove(claim.invocationID) }
        // Denial only revokes persistence; settled process-local cleanup still runs.
        guard allowsPersistentMetadata else { return }
        guard ownsAutomaticRecoveryAttempt(claim), let prior = automaticRecoveryAttemptRecord(),
              prior.publishedFinalization == nil,
              now.timeIntervalSince1970.isFinite, now.timeIntervalSince1970 >= prior.lastAttemptAt else { return }
        var released = SyncAutomaticRecoveryAttemptRecord(schemaVersion: 4, identity: prior.identity,
            invocationID: prior.invocationID, windowIndex: prior.windowIndex,
            attemptsInWindow: prior.attemptsInWindow, totalAttempts: prior.totalAttempts,
            lastAttemptAt: prior.lastAttemptAt, lastCompletedAt: prior.lastCompletedAt, failure: prior.failure,
            nextAllowedAt: max(prior.nextAllowedAt, now.timeIntervalSince1970 + 300), retryAfterUntil: prior.retryAfterUntil)
        released.legacyContinuation = prior.legacyContinuation
        released.retiredLegacyReconciliation = prior.retiredLegacyReconciliation
        released.lifecycle = prior.lifecycle ?? freshLifecycle(operation: .automatic, origin: nil)
        released.lifecycle?.state = .interrupted
        if released.lifecycle?.firstObservedAt == nil { released.lifecycle?.firstObservedAt = now.timeIntervalSince1970 }
        if released.lifecycle?.originPayload == nil,
           let original = defaults.data(forKey: automaticRecoveryAttemptKey), original.count <= 4_096 {
            released.lifecycle?.originPayload = original
            released.lifecycle?.originSHA256 = Self.legacyDigest(original)
        }
        _ = persistAutomaticRecoveryAttemptRecord(released, requiresDurableWrite: true)
    }

    /// Retiring a proved journal preserves its attempt history instead of
    /// deleting the budget. It cannot retire a live or another identity's run.
    func completeRecoveryReconciliationIfJournalRetired(identity: String,
        finalization: SyncStoreRecoveryFinalization?, now: Date = Date()) {
        guard let finalization, hasCurrentAuthority(for: finalization),
              pendingRecoveryJournal == nil, !recoveryJournalIsPending,
              var record = automaticRecoveryAttemptRecord(), record.identity == identity,
              !Self.liveRecoveryInvocations.contains(record.invocationID),
              now.timeIntervalSince1970.isFinite, now.timeIntervalSince1970 >= record.lastAttemptAt else { return }
        if record.schemaVersion == 4 {
            record.lifecycle?.state = .completed
            _ = persistAutomaticRecoveryAttemptRecord(record, requiresDurableWrite: true)
        }
    }

    private static func hasValidRecoveryLifecycleShape(_ data: Data, raw: [String: Any],
        record: SyncAutomaticRecoveryAttemptRecord) -> Bool {
        let required: Set<String> = ["schemaVersion", "identity", "invocationID", "windowIndex", "attemptsInWindow",
            "totalAttempts", "lastAttemptAt", "nextAllowedAt", "lifecycle"]
        let optional: Set<String> = ["lastCompletedAt", "failure", "retryAfterUntil", "legacyContinuation", "publishedFinalization", "retiredLegacyReconciliation"]
        let lifecycleRequired: Set<String> = ["formatVersion", "processEpoch", "operation", "state", "originalAttemptTimeUnknown"]
        let lifecycleOptional: Set<String> = ["phase", "generationID", "firstObservedAt", "originPayload", "originSHA256"]
        guard required.isSubset(of: Set(raw.keys)), Set(raw.keys).isSubset(of: required.union(optional)),
              let nested = raw["lifecycle"] as? [String: Any],
              lifecycleRequired.isSubset(of: Set(nested.keys)),
              Set(nested.keys).isSubset(of: lifecycleRequired.union(lifecycleOptional)),
              hasUniqueJSONKeysPerObject(data), let lifecycle = record.lifecycle, lifecycle.formatVersion == 1,
              lifecycle.firstObservedAt.map({ $0.isFinite && $0 > 0 }) ?? true else { return false }
        if let payload = lifecycle.originPayload {
            guard payload.count <= 4_096, let digest = lifecycle.originSHA256,
                  isRedactedIdentity(digest), legacyDigest(payload) == digest,
                  let origin = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
                  origin["identity"] as? String == record.identity else { return false }
        } else if lifecycle.originSHA256 != nil { return false }
        if lifecycle.operation == .reconciliation {
            guard lifecycle.originPayload != nil, lifecycle.firstObservedAt != nil,
                  lifecycle.phase == .prepared || lifecycle.phase == .staging else { return false }
        }
        if let published = raw["publishedFinalization"] as? [String: Any] {
            guard Set(published.keys) == ["formatVersion", "publishedGenerationID", "publishedCheckpointDigest",
                "publishedBaselineRunID", "preparedForInvocationID", "preparedFromTotalAttempts", "preparedAt", "claimed"] else { return false }
        }
        if lifecycle.state == .running, record.lastCompletedAt != nil { return false }
        return true
    }

    private static func isRedactedIdentity(_ value: String) -> Bool {
        value.count == 64
            && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    private static func hydratedState(
        defaults: UserDefaults,
        keyPrefix: String,
        lastVerifiedAt: Date?,
        hasPendingRecoveryJournal: Bool,
        now: Date = Date()
    ) -> SyncState {
        guard let observation = decodedRunObservation(defaults: defaults, keyPrefix: keyPrefix),
              observation.origin.isCurrent(defaults: defaults) else {
            // A raw explicit recovery latch remains a latch when no typed
            // history exists. Raw failures/blocks/timestamps are never origin.
            let legacyRecoveryLatch = defaults.object(forKey: "\(keyPrefix).lastRunObservation.v1") == nil
                && phase(from: defaults.string(forKey: "\(keyPrefix).phase")) == .recoveryRequired
            return SyncState(phase: hasPendingRecoveryJournal || legacyRecoveryLatch ? .recoveryRequired : .idle,
                lastVerifiedAt: lastVerifiedAt)
        }
        let reason = blockReason(from: observation.blockReason)
        var resolvedPhase = phase(for: observation.status, blockReason: reason) ?? .idle
        var resolvedOutcome = outcome(for: observation.status, blockReason: reason)
        if observation.errorCode != nil,
           observation.status == .success || observation.status == .noWork {
            resolvedPhase = reason.map(SyncPhase.blocked) ?? .failed
            resolvedOutcome = reason.map(SyncOutcome.blocked) ?? .failed
        }
        if hasPendingRecoveryJournal {
            resolvedPhase = .recoveryRequired
        } else if lastVerifiedAt == nil,
                  observation.blockReason == nil, observation.errorCode == nil,
                  observation.status == .success || observation.status == .noWork {
            // Current unverified work still cannot manufacture convergence.
            resolvedPhase = .recoveryRequired
        }
        return SyncState(phase: resolvedPhase, lastVerifiedAt: lastVerifiedAt,
            lastOutcome: resolvedOutcome,
            lastProgressAt: Date(timeIntervalSince1970: observation.completedAt))
    }

    private static func date(_ defaults: UserDefaults, key: String) -> Date? {
        let value = defaults.double(forKey: key)
        guard value > 0 else { return nil }
        return Date(timeIntervalSince1970: value)
    }

    private static func phase(from value: String?) -> SyncPhase? {
        guard let value else { return nil }
        switch value {
        case "idle": return .idle
        case "checking": return .checking
        case "pushing": return .pushing
        case "pullingEvents": return .pullingEvents
        case "reconciling": return .reconciling
        case "recoveryRequired": return .recoveryRequired
        case "failed": return .failed
        default:
            if let reasonValue = value.split(separator: ".").last,
               value.hasPrefix("blocked."),
               let reason = blockReason(from: String(reasonValue)) {
                return .blocked(reason)
            }
            return nil
        }
    }

    private static func phase(
        for status: SyncAutomaticRunStatus?,
        blockReason: SyncBlockReason?
    ) -> SyncPhase? {
        switch status {
        case .success, .noWork, .cancelled:
            return .idle
        case .recoveryRequired:
            return .recoveryRequired
        case .blocked:
            return .blocked(blockReason ?? .accountDecisionRequired)
        case .busy, .scheduledRetry:
            return .idle
        case .failed:
            return .failed
        case .none:
            return nil
        }
    }

    private static func outcome(
        for status: SyncAutomaticRunStatus?,
        blockReason: SyncBlockReason?
    ) -> SyncOutcome? {
        switch status {
        case .success:
            return .succeeded
        case .noWork:
            return .noWork
        case .recoveryRequired:
            return .noWork
        case .blocked:
            return .blocked(blockReason ?? .accountDecisionRequired)
        case .busy:
            return .busy
        case .failed:
            return .failed
        case .cancelled:
            return .cancelled
        case .scheduledRetry:
            return .scheduledRetry
        case .none:
            return nil
        }
    }

    private static func blockReason(from value: String?) -> SyncBlockReason? {
        switch value {
        case "authRequired": return .authRequired
        case "networkUnavailable": return .networkUnavailable
        case "accountDecisionRequired": return .accountDecisionRequired
        case "localStateUnavailable": return .localStateUnavailable
        case "deviceNotActive": return .deviceNotActive
        default: return nil
        }
    }
}

private extension SyncTrigger {
    var diagnosticsName: String {
        switch self {
        case .appForeground: "appForeground"
        case .networkAvailable: "networkAvailable"
        case .authChanged: "authChanged"
        case .localMutation: "localMutation"
        case .remoteSyncEvent: "remoteSyncEvent"
        case .manualRefresh: "manualRefresh"
        case .harness: "harness"
        case .recoveryRequested: "recoveryRequested"
        case .bootstrapRequested: "bootstrapRequested"
        }
    }
}

private extension SyncAction {
    var diagnosticsName: String {
        switch self {
        case .noOp: "noOp"
        case .pushPending: "pushPending"
        case .drainEvents: "drainEvents"
        case .lightReconcile: "lightReconcile"
        case .bootstrap: "bootstrap"
        case .fullRecovery: "fullRecovery"
        case .requestRecovery: "requestRecovery"
        case .retryAfterBusy: "retryAfterBusy"
        case .blocked(let reason): "blocked.\(reason.diagnosticsName)"
        case .sequence(let actions): "sequence.\(actions.map(\.diagnosticsName).joined(separator: "+"))"
        }
    }
}

extension SyncBlockReason {
    nonisolated var diagnosticsName: String {
        switch self {
        case .authRequired: "authRequired"
        case .networkUnavailable: "networkUnavailable"
        case .accountDecisionRequired: "accountDecisionRequired"
        case .localStateUnavailable: "localStateUnavailable"
        case .deviceNotActive: "deviceNotActive"
        }
    }
}

private extension SyncPhase {
    var diagnosticsName: String {
        switch self {
        case .idle: "idle"
        case .checking: "checking"
        case .pushing: "pushing"
        case .pullingEvents: "pullingEvents"
        case .reconciling: "reconciling"
        case .recoveryRequired: "recoveryRequired"
        case .blocked(let reason): "blocked.\(reason.diagnosticsName)"
        case .failed: "failed"
        }
    }
}
