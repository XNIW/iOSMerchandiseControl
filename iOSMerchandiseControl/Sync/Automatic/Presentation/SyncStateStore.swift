import Foundation
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
    static let schemaVersion = 2

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

    init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "sync.runtime.orchestrator",
        retryJitter: @escaping @Sendable () -> Double = { Double.random(in: 0.5...1.5) },
        storeGenerationController: SyncStoreGenerationController? = nil
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
        self.retryJitter = retryJitter
        self.storeGenerationController = storeGenerationController
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
            phase = .checking
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
            phase = .checking
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
            // v1 lacks typed failure and completion provenance. Preserve it;
            // its diagnostics cannot authorize an automatic v2 migration.
            return defaults.object(forKey: "\(keyPrefix).automaticRecoveryAttempt.v1") == nil ? .ready : .exhausted
        }
        guard let record = automaticRecoveryAttemptRecord() else { return .exhausted }
        guard record.identity == identity else { return .ready }
        guard record.lastCompletedAt != nil, record.failure?.disposition == .transient else { return .exhausted }
        let remaining = record.nextAllowedAt - now.timeIntervalSince1970
        return remaining > 0 ? .cooldown(remaining) : .ready
    }

    @discardableResult
    func beginAutomaticRecoveryAttempt(identity: String, now: Date = Date()) -> Int? {
        claimAutomaticRecoveryAttempt(identity: identity, now: now)?.attemptInWindow
    }

    func claimAutomaticRecoveryAttempt(identity: String, now: Date = Date()) -> SyncAutomaticRecoveryAttemptClaim? {
        guard automaticRecoveryAttemptEligibility(identity: identity, now: now) == .ready else { return nil }
        let prior = automaticRecoveryAttemptRecord().flatMap { $0.identity == identity ? $0 : nil }
        let newWindow = prior?.attemptsInWindow == 3
        let attempt = newWindow ? 1 : (prior?.attemptsInWindow ?? 0) + 1
        let priorTotal = prior?.totalAttempts ?? 0
        let priorWindow = prior?.windowIndex ?? 1
        guard priorTotal < Int.max, !newWindow || priorWindow < Int.max else { return nil }
        let invocationID = UUID()
        let record = SyncAutomaticRecoveryAttemptRecord(schemaVersion: 2, identity: identity, invocationID: invocationID,
            windowIndex: priorWindow + (newWindow ? 1 : 0), attemptsInWindow: attempt,
            totalAttempts: priorTotal + 1, lastAttemptAt: now.timeIntervalSince1970,
            lastCompletedAt: nil, failure: nil, nextAllowedAt: now.timeIntervalSince1970,
            retryAfterUntil: prior?.retryAfterUntil)
        guard persistAutomaticRecoveryAttemptRecord(record) else { return nil }
        return SyncAutomaticRecoveryAttemptClaim(storageKey: automaticRecoveryAttemptKey,
            identity: identity, invocationID: invocationID, attemptInWindow: attempt)
    }

    private func completeAutomaticRecoveryAttempt(claim: SyncAutomaticRecoveryAttemptClaim,
        failure: AutomaticSyncFailure?, now: Date) -> Bool {
        guard ownsAutomaticRecoveryAttempt(claim), let record = automaticRecoveryAttemptRecord(),
              now.timeIntervalSince1970 >= record.lastAttemptAt else { return false }
        let completed = now.timeIntervalSince1970
        let failure = failure ?? AutomaticSyncFailure(disposition: .unknown, category: .unknown)
        let suppliedRetryAfter = failure.retryAfterUntil?.timeIntervalSince1970
        let retryAfter = [record.retryAfterUntil, suppliedRetryAfter].compactMap { $0 }.max()
        let sample = retryJitter()
        let jitter = sample.isFinite ? min(1.5, max(0.5, sample)) : 1
        let localDelay = record.attemptsInWindow == 3 ? 300
            : min(60, 2 * pow(2, Double(record.attemptsInWindow - 1)) * jitter)
        let nextAllowedAt = max(completed + localDelay, retryAfter ?? 0)
        let updated = SyncAutomaticRecoveryAttemptRecord(schemaVersion: 2, identity: record.identity, invocationID: record.invocationID,
            windowIndex: record.windowIndex, attemptsInWindow: record.attemptsInWindow,
            totalAttempts: record.totalAttempts, lastAttemptAt: record.lastAttemptAt,
            lastCompletedAt: completed, failure: failure, nextAllowedAt: nextAllowedAt,
            retryAfterUntil: retryAfter)
        return persistAutomaticRecoveryAttemptRecord(updated)
    }

    func ownsAutomaticRecoveryAttempt(_ claim: SyncAutomaticRecoveryAttemptClaim) -> Bool {
        guard claim.storageKey == automaticRecoveryAttemptKey,
              let record = automaticRecoveryAttemptRecord(), record.lastCompletedAt == nil else { return false }
        return record.identity == claim.identity && record.invocationID == claim.invocationID
            && record.attemptsInWindow == claim.attemptInWindow
    }

    func extendAutomaticRecoveryAttemptCooldown(identity: String, requestedDelay: TimeInterval,
        now: Date = Date()) -> TimeInterval {
        guard requestedDelay.isFinite, requestedDelay >= 0 else { return .infinity }
        guard let record = automaticRecoveryAttemptRecord(), record.identity == identity else { return requestedDelay }
        let target = max(record.nextAllowedAt, now.timeIntervalSince1970 + requestedDelay)
        let updated = SyncAutomaticRecoveryAttemptRecord(schemaVersion: record.schemaVersion,
            identity: record.identity, invocationID: record.invocationID, windowIndex: record.windowIndex,
            attemptsInWindow: record.attemptsInWindow, totalAttempts: record.totalAttempts,
            lastAttemptAt: record.lastAttemptAt, lastCompletedAt: record.lastCompletedAt,
            failure: record.failure, nextAllowedAt: target, retryAfterUntil: record.retryAfterUntil)
        guard persistAutomaticRecoveryAttemptRecord(updated) else { return .infinity }
        return max(0, target - now.timeIntervalSince1970)
    }

    func resetAutomaticRecoveryAttemptBudget() {
        defaults.removeObject(forKey: automaticRecoveryAttemptKey)
        defaults.removeObject(forKey: "\(keyPrefix).automaticRecoveryAttempt.v1")
    }

    private func automaticRecoveryAttemptRecord() -> SyncAutomaticRecoveryAttemptRecord? {
        guard let data = defaults.data(forKey: automaticRecoveryAttemptKey),
              let record = try? JSONDecoder().decode(SyncAutomaticRecoveryAttemptRecord.self, from: data),
              record.schemaVersion == SyncAutomaticRecoveryAttemptRecord.schemaVersion,
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
        if let completed = record.lastCompletedAt, record.failure?.disposition == .transient {
            let minimumDelay = record.attemptsInWindow == 3 ? 300 : pow(2, Double(record.attemptsInWindow - 1))
            guard record.nextAllowedAt >= completed + minimumDelay else { return nil }
        }
        if let serverMinimum = record.failure?.retryAfterUntil?.timeIntervalSince1970 {
            guard record.nextAllowedAt >= serverMinimum else { return nil }
        }
        return record
    }

    private func persistAutomaticRecoveryAttemptRecord(
        _ record: SyncAutomaticRecoveryAttemptRecord
    ) -> Bool {
        guard let data = try? JSONEncoder().encode(record) else { return false }
        defaults.set(data, forKey: automaticRecoveryAttemptKey)
        return defaults.data(forKey: automaticRecoveryAttemptKey) == data
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
