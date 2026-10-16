import Foundation

nonisolated enum AutomaticSyncAttemptContext {
    /// The existing engine invokes this only after facade/admission gates and
    /// acquiring single-flight, before entering its remote action plan.
    @TaskLocal static var begin: (@Sendable () async -> Bool)?
}

nonisolated enum SyncAutomaticRunStatus: String, Codable, CaseIterable, Equatable, Sendable, Hashable {
    case success
    case noWork
    case recoveryRequired
    case blocked
    case busy
    case failed
    case cancelled
    case scheduledRetry
}

/// Observation authority is captured before work. It is not a convergence
/// proof: a first bootstrap may fail while its generation is genuinely absent.
nonisolated struct SyncAutomaticRunObservationOrigin: Codable, Equatable, Sendable {
    enum GenerationKind: String, Codable, Sendable { case absent, identified }
    let accountHash: String
    let shopID: UUID
    let storeIdentity: LocalStoreIdentity
    let deviceIdentityHash: String
    let generationKind: GenerationKind
    let generationID: UUID?

    private enum CodingKeys: String, CodingKey {
        case accountHash, shopID, storeIdentity, deviceIdentityHash, generationKind, generationID
    }
    private struct RequiredIdentity: Decodable {
        let rawValue: String
        let defaultStoreId: String
        let localStoreId: String
        let schemaVersion: Int
        let syncProtocolVersion: Int
        let storeEpoch: Int
        func exactlyDescribes(_ value: LocalStoreIdentity) -> Bool {
            rawValue == value.rawValue && defaultStoreId == value.defaultStoreId
                && localStoreId == value.localStoreId && schemaVersion == value.schemaVersion
                && syncProtocolVersion == value.syncProtocolVersion && storeEpoch == value.storeEpoch
        }
    }

    init(scope: Task126VerifiedOwnerStoreScope, generation: WatermarkStore.GenerationProvenance) throws {
        accountHash = scope.accountHash
        shopID = scope.shopID
        storeIdentity = scope.storeIdentity
        deviceIdentityHash = scope.deviceIdentityHash
        switch generation {
        case .absent: generationKind = .absent; generationID = nil
        case .identified(let id): generationKind = .identified; generationID = id
        case .invalid: throw Task126OwnerStoreGateError.scopeChanged
        }
    }

    private init(origin: Self, finalizedGenerationID: UUID) {
        accountHash = origin.accountHash
        shopID = origin.shopID
        storeIdentity = origin.storeIdentity
        deviceIdentityHash = origin.deviceIdentityHash
        generationKind = .identified
        generationID = finalizedGenerationID
    }

    func completing(_ result: SyncAutomaticRunResult) -> Self {
        guard result.status == .success || result.status == .noWork,
              result.errorCode == nil, result.blockReason == nil,
              let proof = result.verifiedFinalization,
              proof.schemaVersion == SyncStoreRecoveryFinalization.currentSchemaVersion,
              proof.accountHash == accountHash, proof.shopID == shopID,
              proof.storeIdentity.hasSameProvenance(as: storeIdentity),
              proof.deviceIdentityHash == deviceIdentityHash else { return self }
        // This generation comes from the original durable commit receipt,
        // never from whatever generation happens to be current at callback.
        return Self(origin: self, finalizedGenerationID: proof.generationID)
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        accountHash = try values.decode(String.self, forKey: .accountHash)
        shopID = try values.decode(UUID.self, forKey: .shopID)
        let required = try values.decode(RequiredIdentity.self, forKey: .storeIdentity)
        storeIdentity = try values.decode(LocalStoreIdentity.self, forKey: .storeIdentity)
        guard required.exactlyDescribes(storeIdentity) else {
            throw DecodingError.dataCorruptedError(forKey: .storeIdentity, in: values,
                debugDescription: "Observation identity must be complete and canonical")
        }
        deviceIdentityHash = try values.decode(String.self, forKey: .deviceIdentityHash)
        generationKind = try values.decode(GenerationKind.self, forKey: .generationKind)
        generationID = try values.decodeIfPresent(UUID.self, forKey: .generationID)
        guard hasValidPersistentFacts else {
            throw DecodingError.dataCorruptedError(forKey: .generationKind, in: values,
                debugDescription: "Invalid observation origin")
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.accountHash == rhs.accountHash && lhs.shopID == rhs.shopID
            && lhs.storeIdentity.hasSameProvenance(as: rhs.storeIdentity)
            && lhs.deviceIdentityHash == rhs.deviceIdentityHash
            && lhs.generationKind == rhs.generationKind && lhs.generationID == rhs.generationID
    }

    var hasValidPersistentFacts: Bool {
        func isHash(_ value: String) -> Bool {
            value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
        }
        return isHash(accountHash) && isHash(deviceIdentityHash)
            && !storeIdentity.isEmpty && !storeIdentity.localStoreId.isEmpty
            && storeIdentity.schemaVersion > 0 && storeIdentity.syncProtocolVersion > 0 && storeIdentity.storeEpoch > 0
            && ((generationKind == .absent && generationID == nil)
                || (generationKind == .identified && generationID != nil))
    }

    func isCurrent(defaults: UserDefaults, ownerUserID: UUID? = nil) -> Bool {
        if let ownerUserID, AccountBindingStore.accountHash(for: ownerUserID) != accountHash { return false }
        let selection = SelectedShopStore(defaults: defaults)
        let binding = AccountBindingStore(defaults: defaults)
        guard hasValidPersistentFacts,
              defaults.string(forKey: "mobile.shopContext.activeAccountHash.v1") == accountHash,
              selection.isResolutionReady(accountHash: accountHash),
              let shop = selection.selectedShop(accountHash: accountHash), shop.shopID == shopID,
              shop.localStoreIdentity.hasSameProvenance(as: storeIdentity),
              LinkedShop(shopID: shop.shopID, code: shop.code, name: shop.name, role: shop.role,
                status: shop.status, selectable: shop.selectable, canWrite: shop.canWrite).isValidSelection,
              let device = try? DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID(),
              DeviceInstallIDStore.identityHash(for: device) == deviceIdentityHash else { return false }
        if binding.hasPendingReplacementJournal {
            guard let journal = binding.pendingRecoveryJournal,
                  journal.replacement.accountHash == accountHash,
                  journal.replacement.storeIdentity.hasSameProvenance(as: storeIdentity),
                  journal.deviceIdentityHash == deviceIdentityHash else { return false }
            if journal.mode == .sameScopeRecovery {
                guard let current = binding.currentBinding, current.accountHash == accountHash,
                      current.storeIdentity.hasSameProvenance(as: storeIdentity) else { return false }
            }
        } else {
            guard let current = binding.currentBinding, current.accountHash == accountHash,
                  current.storeIdentity.hasSameProvenance(as: storeIdentity) else { return false }
        }
        switch WatermarkStore(defaults: defaults).generationProvenance(
            for: .init(accountHash: accountHash, storeIdentity: storeIdentity)) {
        case .absent: return generationKind == .absent
        case .identified(let id): return generationKind == .identified && generationID == id
        case .invalid: return false
        }
    }
}

nonisolated struct SyncAutomaticRunObservation: Codable, Equatable, Sendable {
    static let version = 1
    let schemaVersion: Int
    let invocationID: UUID
    let origin: SyncAutomaticRunObservationOrigin
    let status: SyncAutomaticRunStatus
    let errorCode: String?
    let blockReason: String?
    let failure: AutomaticSyncFailure?
    let completedAt: TimeInterval

    var hasValidPersistentFacts: Bool {
        schemaVersion == Self.version && origin.hasValidPersistentFacts
            && completedAt.isFinite && completedAt > 0
            && (errorCode.map { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.utf8.count <= 2_048 } ?? true)
            && (blockReason.map { ["authRequired", "networkUnavailable", "accountDecisionRequired", "localStateUnavailable", "deviceNotActive"].contains($0) } ?? true)
            && (failure?.hasValidPersistentFacts ?? true)
    }

    func matches(_ result: SyncAutomaticRunResult) -> Bool {
        status == result.status && errorCode == result.errorCode
            && blockReason == result.blockReason?.diagnosticsName && failure == result.failure
    }

    var currentError: String? { errorCode ?? blockReason }
    var errorObservedAt: Date? { currentError == nil ? nil : Date(timeIntervalSince1970: completedAt) }
}

nonisolated struct SyncAutomaticRunObservationSource: Sendable {
    let invocationID = UUID()
    let origin: SyncAutomaticRunObservationOrigin

    static func capture(scope: Task126VerifiedOwnerStoreScope, defaults: UserDefaults) -> Self? {
        guard let origin = try? SyncAutomaticRunObservationOrigin(scope: scope,
            generation: WatermarkStore(defaults: defaults).generationProvenance(
                for: .init(accountHash: scope.accountHash, storeIdentity: scope.storeIdentity))),
              origin.isCurrent(defaults: defaults, ownerUserID: scope.ownerUserID) else { return nil }
        return Self(origin: origin)
    }

    static func capture(ownerUserID: UUID, defaults: UserDefaults) -> Self? {
        guard let scope = try? Task126OwnerStoreGate.captureAutomaticScope(ownerUserID: ownerUserID,
            defaults: defaults, allowsPendingReplacement: true, allowsPendingSameScopeRecovery: true) else { return nil }
        return capture(scope: scope, defaults: defaults)
    }

    func completed(_ result: SyncAutomaticRunResult, now: Date = Date()) -> SyncAutomaticRunResult {
        var observed = result
        let observation = SyncAutomaticRunObservation(schemaVersion: SyncAutomaticRunObservation.version,
            invocationID: invocationID, origin: origin.completing(result), status: result.status, errorCode: result.errorCode,
            blockReason: result.blockReason?.diagnosticsName, failure: result.failure,
            completedAt: now.timeIntervalSince1970)
        if observation.hasValidPersistentFacts { observed.observation = observation }
        return observed
    }
}

nonisolated struct SyncAutomaticRunResult: Equatable, Sendable {
    var status: SyncAutomaticRunStatus
    var didWork: Bool
    var blockReason: SyncBlockReason?
    var errorCode: String?
    var scheduledRetryAfter: TimeInterval?
    var verifiedConvergence: Bool
    var continuationReceipt: SyncIncrementalContinuationReceipt?
    var verifiedFinalization: SyncStoreRecoveryFinalization?
    var failure: AutomaticSyncFailure?
    var observation: SyncAutomaticRunObservation?

    init(
        status: SyncAutomaticRunStatus,
        didWork: Bool,
        blockReason: SyncBlockReason? = nil,
        errorCode: String? = nil,
        scheduledRetryAfter: TimeInterval? = nil,
        verifiedConvergence: Bool = false,
        failure: AutomaticSyncFailure? = nil
    ) {
        self.status = status
        self.didWork = didWork
        self.blockReason = blockReason
        self.errorCode = errorCode
        self.scheduledRetryAfter = scheduledRetryAfter
        self.verifiedConvergence = verifiedConvergence
        self.failure = failure ?? (blockReason == .networkUnavailable
            ? AutomaticSyncFailure(disposition: .transient, category: .network) : nil)
        // Generic results never manufacture ordinary continuation authority.
        self.continuationReceipt = nil
        self.verifiedFinalization = nil
        self.observation = nil
    }

    static func success(
        didWork: Bool,
        verifiedConvergence: Bool = false
    ) -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(
            status: .success,
            didWork: didWork,
            verifiedConvergence: verifiedConvergence
        )
    }

    static func noWork(
        verifiedConvergence: Bool = false
    ) -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(
            status: .noWork,
            didWork: false,
            verifiedConvergence: verifiedConvergence
        )
    }

    static func recoveryRequired(didWork: Bool = false) -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(status: .recoveryRequired, didWork: didWork)
    }

    static func blocked(_ reason: SyncBlockReason) -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(status: .blocked, didWork: false, blockReason: reason)
    }

    static func busy() -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(status: .busy, didWork: false)
    }

    static func failed(errorCode: String?, failure: AutomaticSyncFailure? = nil) -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(status: .failed, didWork: false, errorCode: errorCode, failure: failure)
    }

    static func cancelled() -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(status: .cancelled, didWork: false)
    }

    static func scheduledRetry(after delay: TimeInterval? = nil) -> SyncAutomaticRunResult {
        SyncAutomaticRunResult(status: .scheduledRetry, didWork: false, scheduledRetryAfter: delay)
    }
}
