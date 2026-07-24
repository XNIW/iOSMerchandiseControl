import CryptoKit
import Foundation
#if canImport(Darwin)
import Darwin
#endif

private nonisolated final class AccountRecoveryJournalURLRegistry: @unchecked Sendable {
    static let shared = AccountRecoveryJournalURLRegistry()

    private final class Entry {
        weak var defaults: UserDefaults?
        let url: URL

        init(defaults: UserDefaults, url: URL) {
            self.defaults = defaults
            self.url = url
        }
    }

    private let lock = NSLock()
    private var entries: [ObjectIdentifier: Entry] = [:]

    func register(_ url: URL, for defaults: UserDefaults) {
        lock.lock()
        defer { lock.unlock() }
        entries[ObjectIdentifier(defaults)] = Entry(
            defaults: defaults,
            url: url.standardizedFileURL
        )
    }

    func url(for defaults: UserDefaults) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        let key = ObjectIdentifier(defaults)
        guard let entry = entries[key], entry.defaults === defaults else {
            entries.removeValue(forKey: key)
            return nil
        }
        return entry.url
    }
}

nonisolated enum AccountRecoveryJournalMode: String, Codable, Sendable {
    case accountOrShopReplacement
    case sameScopeRecovery
}

nonisolated enum AccountRecoveryJournalPhase: String, Codable, Sendable {
    case prepared
    case staging
    case verified
    case activated
}

nonisolated struct AccountRecoveryJournalSnapshot: Equatable, Sendable {
    let replacement: AccountBinding
    let mode: AccountRecoveryJournalMode
    let phase: AccountRecoveryJournalPhase
    let deviceIdentityHash: String
    let generationID: UUID?
    let checkpointDigest: String?
    let watermark: Int64?
    let baselineRunID: UUID?
}

private nonisolated struct AccountReplacementJournal: Codable, Equatable, Sendable {
    var replacement: AccountBinding
    var wipeCommitted: Bool
    var modeRaw: String?
    var phaseRaw: String?
    var deviceIdentityHash: String?
    var generationID: UUID?
    var checkpointDigest: String?
    var watermark: Int64?
    var baselineRunID: UUID?

    var mode: AccountRecoveryJournalMode {
        AccountRecoveryJournalMode(rawValue: modeRaw ?? "") ?? .accountOrShopReplacement
    }

    var phase: AccountRecoveryJournalPhase {
        AccountRecoveryJournalPhase(rawValue: phaseRaw ?? "") ?? .prepared
    }
}

nonisolated final class AccountBindingStore: @unchecked Sendable {
    private static let maximumDurableJournalBytes = 512 * 1_024
    private let defaults: UserDefaults
    private let key: String
    private let replacementKey: String
    private let presentedDecisionIdentitiesKey: String
    private let presentedDecisionIdentitiesOverflowKey: String
    private let durableJournalURL: URL?

    init(
        defaults: UserDefaults = .standard,
        key: String = "sync.accountBinding.v1",
        durableJournalURL: URL? = nil
    ) {
        self.defaults = defaults
        self.key = key
        self.replacementKey = "\(key).pendingReplacement"
        self.presentedDecisionIdentitiesKey = "\(key).presentedDecisionIdentities"
        self.presentedDecisionIdentitiesOverflowKey =
            "\(key).presentedDecisionIdentities.autoShowDisabled"
        self.durableJournalURL = durableJournalURL?.standardizedFileURL
            ?? (defaults === UserDefaults.standard ? Self.defaultDurableJournalURL() : nil)
            ?? AccountRecoveryJournalURLRegistry.shared.url(for: defaults)
    }

    static func configureDurableRecoveryJournal(
        at url: URL,
        for defaults: UserDefaults
    ) {
        AccountRecoveryJournalURLRegistry.shared.register(url, for: defaults)
    }

    var durableRecoveryJournalURLForTesting: URL? { durableJournalURL }

    var currentBinding: AccountBinding? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(AccountBinding.self, from: data)
    }

    @discardableResult
    func saveBinding(
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        boundAt: Date = Date()
    ) -> Bool {
        return Task126OwnerStoreGate.withAutomaticScopeLeaseInvalidated {
            saveBindingWithLeaseHeld(
                accountHash: accountHash,
                storeIdentity: storeIdentity,
                boundAt: boundAt
            )
        }
    }

    func clearBinding() {
        Task126OwnerStoreGate.withAutomaticScopeLeaseInvalidated {
            defaults.removeObject(forKey: key)
        }
    }

    var pendingReplacement: AccountBinding? {
        replacementJournal?.replacement
    }

    var pendingReplacementWipeCommitted: Bool {
        replacementJournal?.wipeCommitted == true
    }

    var pendingRecoveryJournal: AccountRecoveryJournalSnapshot? {
        guard let journal = replacementJournal,
              let deviceIdentityHash = journal.deviceIdentityHash,
              deviceIdentityHash.count == 64 else { return nil }
        return AccountRecoveryJournalSnapshot(
            replacement: journal.replacement,
            mode: journal.mode,
            phase: journal.phase,
            deviceIdentityHash: deviceIdentityHash,
            generationID: journal.generationID,
            checkpointDigest: journal.checkpointDigest,
            watermark: journal.watermark,
            baselineRunID: journal.baselineRunID
        )
    }

    var hasPendingReplacementJournal: Bool {
        if let durableJournalURL,
           FileManager.default.fileExists(atPath: durableJournalURL.path) {
            return true
        }
        return defaults.object(forKey: replacementKey) != nil
    }

    @discardableResult
    func beginReplacement(
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        deviceIdentityHash: String? = nil,
        allowsCorruptJournalRepair: Bool = false,
        allowsSameScopeDestructivePromotion: Bool = false,
        boundAt: Date = Date()
    ) -> Bool {
        let resolvedDeviceIdentityHash: String
        if let deviceIdentityHash {
            resolvedDeviceIdentityHash = deviceIdentityHash
        } else {
            guard let deviceInstallID = try? DeviceInstallIDStore(defaults: defaults)
                .requireDeviceInstallID() else { return false }
            resolvedDeviceIdentityHash = DeviceInstallIDStore.identityHash(for: deviceInstallID)
        }
        guard resolvedDeviceIdentityHash.count == 64 else { return false }
        return Task126OwnerStoreGate.withAutomaticScopeLeaseInvalidated {
            if hasPendingReplacementJournal {
                if let existing = pendingRecoveryJournal {
                    guard existing.replacement.accountHash == accountHash,
                          existing.replacement.storeIdentity == storeIdentity,
                          existing.deviceIdentityHash == resolvedDeviceIdentityHash else {
                        return false
                    }
                    if existing.mode == .accountOrShopReplacement {
                        return true
                    }
                    // A same-scope recovery can contain irrecoverable local
                    // work (for example a legacy import-cap marker). Only the
                    // explicit destructive cloud-replacement dialog may
                    // promote that prepared latch. Automatic retry paths keep
                    // it intact and cannot silently discard local data.
                    guard allowsSameScopeDestructivePromotion,
                          existing.mode == .sameScopeRecovery,
                          existing.phase == .prepared else { return false }
                    return persistReplacementJournalWithLeaseHeld(
                        AccountReplacementJournal(
                            replacement: AccountBinding(
                                accountHash: accountHash,
                                storeIdentity: storeIdentity,
                                boundAt: boundAt
                            ),
                            wipeCommitted: false,
                            modeRaw: AccountRecoveryJournalMode.accountOrShopReplacement.rawValue,
                            phaseRaw: AccountRecoveryJournalPhase.prepared.rawValue,
                            deviceIdentityHash: resolvedDeviceIdentityHash,
                            generationID: nil,
                            checkpointDigest: nil,
                            watermark: nil,
                            baselineRunID: nil
                        )
                    )
                }
                // Migrate the exact pre-generation journal in place. It stays
                // prepared/fail-closed and gains only the current device hash;
                // no binding or business data is changed.
                guard var legacy = replacementJournal,
                      legacy.replacement.accountHash == accountHash,
                      legacy.replacement.storeIdentity == storeIdentity else {
                    guard allowsCorruptJournalRepair else { return false }
                    // Only the explicit destructive dialog path is allowed to
                    // replace undecodable bytes. Automatic retries keep the raw
                    // latch untouched and fail closed.
                    let repaired = AccountReplacementJournal(
                        replacement: AccountBinding(
                            accountHash: accountHash,
                            storeIdentity: storeIdentity,
                            boundAt: boundAt
                        ),
                        wipeCommitted: false,
                        modeRaw: AccountRecoveryJournalMode.accountOrShopReplacement.rawValue,
                        phaseRaw: AccountRecoveryJournalPhase.prepared.rawValue,
                        deviceIdentityHash: resolvedDeviceIdentityHash,
                        generationID: nil,
                        checkpointDigest: nil,
                        watermark: nil,
                        baselineRunID: nil
                    )
                    return persistReplacementJournalWithLeaseHeld(repaired)
                        && pendingRecoveryJournal?.replacement == repaired.replacement
                }
                legacy.wipeCommitted = false
                legacy.modeRaw = AccountRecoveryJournalMode.accountOrShopReplacement.rawValue
                legacy.phaseRaw = AccountRecoveryJournalPhase.prepared.rawValue
                legacy.deviceIdentityHash = resolvedDeviceIdentityHash
                legacy.generationID = nil
                legacy.checkpointDigest = nil
                legacy.watermark = nil
                legacy.baselineRunID = nil
                return persistReplacementJournalWithLeaseHeld(legacy)
            }
            let replacement = AccountBinding(
                accountHash: accountHash,
                storeIdentity: storeIdentity,
                boundAt: boundAt
            )
            guard persistReplacementJournalWithLeaseHeld(AccountReplacementJournal(
                replacement: replacement,
                wipeCommitted: false,
                modeRaw: AccountRecoveryJournalMode.accountOrShopReplacement.rawValue,
                phaseRaw: AccountRecoveryJournalPhase.prepared.rawValue,
                deviceIdentityHash: resolvedDeviceIdentityHash,
                generationID: nil,
                checkpointDigest: nil,
                watermark: nil,
                baselineRunID: nil
            )) else { return false }
            return pendingReplacement?.accountHash == replacement.accountHash
                && pendingReplacement?.storeIdentity == replacement.storeIdentity
                && !pendingReplacementWipeCommitted
        }
    }

    /// Persists a durable recovery latch for a malformed/legacy event without
    /// changing the current binding. It shares the same owner-safe recovery
    /// transaction as an explicit replacement, but never prompts the user.
    @discardableResult
    func beginSameScopeRecovery(
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        reason: String,
        deviceIdentityHash: String? = nil,
        now: Date = Date()
    ) -> Bool {
        let safeReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !safeReason.isEmpty,
              currentBinding?.accountHash == accountHash,
              currentBinding?.storeIdentity == storeIdentity else { return false }
        let resolvedDeviceIdentityHash: String
        if let deviceIdentityHash {
            resolvedDeviceIdentityHash = deviceIdentityHash
        } else {
            guard let deviceInstallID = try? DeviceInstallIDStore(defaults: defaults)
                .requireDeviceInstallID() else { return false }
            resolvedDeviceIdentityHash = DeviceInstallIDStore.identityHash(for: deviceInstallID)
        }
        return Task126OwnerStoreGate.withAutomaticScopeLeaseInvalidated {
            if let existing = pendingRecoveryJournal {
                return existing.replacement.accountHash == accountHash
                    && existing.replacement.storeIdentity == storeIdentity
                    && existing.deviceIdentityHash == resolvedDeviceIdentityHash
            }
            return persistReplacementJournalWithLeaseHeld(
                AccountReplacementJournal(
                    replacement: AccountBinding(
                        accountHash: accountHash,
                        storeIdentity: storeIdentity,
                        boundAt: now
                    ),
                    wipeCommitted: false,
                    modeRaw: AccountRecoveryJournalMode.sameScopeRecovery.rawValue,
                    phaseRaw: AccountRecoveryJournalPhase.prepared.rawValue,
                    deviceIdentityHash: resolvedDeviceIdentityHash,
                    generationID: nil,
                    checkpointDigest: Self.redactedAccountHash(for: safeReason),
                    watermark: nil,
                    baselineRunID: nil
                )
            )
        }
    }

    @discardableResult
    func recordPendingRecoveryStaging(
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        deviceIdentityHash: String,
        generationID: UUID,
        scope: Task126VerifiedOwnerStoreScope? = nil
    ) -> Bool {
        if let scope {
            do {
                return try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                    scope,
                    defaults: defaults
                ) {
                    updatePendingRecoveryWithLeaseHeld(
                        accountHash: accountHash,
                        storeIdentity: storeIdentity,
                        deviceIdentityHash: deviceIdentityHash
                    ) { journal in
                        Self.prepareJournalForStaging(&journal, generationID: generationID)
                    }
                }
            } catch {
                return false
            }
        }
        return updatePendingRecovery(
            accountHash: accountHash,
            storeIdentity: storeIdentity,
            deviceIdentityHash: deviceIdentityHash
        ) { journal in
            Self.prepareJournalForStaging(&journal, generationID: generationID)
        }
    }

    @discardableResult
    func recordPendingRecoveryVerified(
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        deviceIdentityHash: String,
        generationID: UUID,
        checkpointDigest: String,
        watermark: Int64,
        baselineRunID: UUID,
        scope: Task126VerifiedOwnerStoreScope? = nil
    ) -> Bool {
        guard checkpointDigest.count == 64, watermark >= 0 else { return false }
        if let scope {
            do {
                return try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                    scope,
                    defaults: defaults
                ) {
                    updatePendingRecoveryWithLeaseHeld(
                        accountHash: accountHash,
                        storeIdentity: storeIdentity,
                        deviceIdentityHash: deviceIdentityHash
                    ) { journal in
                        Self.prepareJournalForVerification(
                            &journal,
                            generationID: generationID,
                            checkpointDigest: checkpointDigest,
                            watermark: watermark,
                            baselineRunID: baselineRunID
                        )
                    }
                }
            } catch {
                return false
            }
        }
        return updatePendingRecovery(
            accountHash: accountHash,
            storeIdentity: storeIdentity,
            deviceIdentityHash: deviceIdentityHash
        ) { journal in
            Self.prepareJournalForVerification(
                &journal,
                generationID: generationID,
                checkpointDigest: checkpointDigest,
                watermark: watermark,
                baselineRunID: baselineRunID
            )
        }
    }

    /// Finalizes only metadata that is already proven by the atomically active
    /// generation manifest. This is idempotent and is also used at relaunch if
    /// the process crashed immediately after the manifest rename.
    @discardableResult
    func commitActivatedGeneration(
        _ manifest: SyncStoreGenerationManifest,
        expectedLeaseGeneration: UInt64
    ) throws -> Bool {
        try Task126OwnerStoreGate.withValidatedAutomaticScopeLeaseInvalidated(
            expectedGeneration: expectedLeaseGeneration
        ) {
            commitActivatedGenerationWithLeaseHeld(manifest)
        }
    }

    /// Raw half of `commitActivatedGeneration`. The caller must already own
    /// the non-recursive Task126 lease. Recovery activation uses this to keep
    /// manifest publication, in-process generation publication, journal,
    /// binding, watermark and lease invalidation inside one boundary.
    @discardableResult
    func commitActivatedGenerationWithLeaseHeld(
        _ manifest: SyncStoreGenerationManifest
    ) -> Bool {
        guard var journal = replacementJournal,
              journal.replacement.accountHash == manifest.accountHash,
              journal.replacement.storeIdentity == manifest.storeIdentity,
              journal.deviceIdentityHash == manifest.deviceIdentityHash,
              (journal.phase == .verified || journal.phase == .activated),
              journal.generationID == manifest.generationID,
              journal.checkpointDigest == manifest.checkpoint.checkpointDigest,
              journal.watermark == manifest.checkpoint.maxEventID,
              journal.baselineRunID == manifest.baselineRunID,
              manifest.checkpoint.shopId == manifest.shopID,
              let watermark = manifest.checkpoint.maxEventID else {
            return false
        }
        journal.generationID = manifest.generationID
        journal.phaseRaw = AccountRecoveryJournalPhase.activated.rawValue
        journal.checkpointDigest = manifest.checkpoint.checkpointDigest
        journal.watermark = manifest.checkpoint.maxEventID
        journal.baselineRunID = manifest.baselineRunID
        journal.wipeCommitted = true
        guard persistReplacementJournalWithLeaseHeld(journal),
              saveBindingWithLeaseHeld(
                accountHash: manifest.accountHash,
                storeIdentity: manifest.storeIdentity,
                boundAt: manifest.activatedAt
              ),
              WatermarkStore(defaults: defaults).saveAuthoritativeRecoveryCheckpoint(
                watermark,
                generationID: manifest.generationID,
                for: WatermarkStore.Scope(
                    accountHash: manifest.accountHash,
                    storeIdentity: manifest.storeIdentity
                )
              ),
              ShopSyncRecoveryFenceStore(defaults: defaults).saveAuthoritative(
                scope: manifest.checkpoint.scope,
                watermark: watermark,
                accountHash: manifest.accountHash,
                storeIdentity: manifest.storeIdentity,
                deviceIdentityHash: manifest.deviceIdentityHash
              ) else {
            return false
        }
        return pendingRecoveryJournal?.phase == .activated
            && currentBinding?.accountHash == manifest.accountHash
            && currentBinding?.storeIdentity == manifest.storeIdentity
    }

    /// Repairs volatile metadata exclusively from an already-fsynced terminal
    /// generation receipt. It never clears or fabricates a recovery journal.
    /// Repeating it at launch is bounded and idempotent.
    @discardableResult
    func restoreFinalizedGenerationMetadata(
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        generationID: UUID,
        watermark: Int64,
        recoveryScope: ShopSyncRecoveryScope,
        deviceIdentityHash: String,
        boundAt: Date
    ) -> Bool {
        Task126OwnerStoreGate.withAutomaticScopeLeaseInvalidated {
            guard saveBindingWithLeaseHeld(
                accountHash: accountHash,
                storeIdentity: storeIdentity,
                boundAt: boundAt
            ) else { return false }
            guard WatermarkStore(defaults: defaults)
                .restoreAuthoritativeRecoveryCheckpoint(
                    watermark,
                    generationID: generationID,
                    for: WatermarkStore.Scope(
                        accountHash: accountHash,
                        storeIdentity: storeIdentity
                    )
                ) else { return false }
            return ShopSyncRecoveryFenceStore(defaults: defaults).saveAuthoritative(
                scope: recoveryScope,
                watermark: watermark,
                accountHash: accountHash,
                storeIdentity: storeIdentity,
                deviceIdentityHash: deviceIdentityHash
            )
        }
    }

    /// Records proof that the destructive SwiftData transaction committed. A
    /// prepared journal stays blocked unless automatic resolution separately
    /// verifies that the complete local store is already empty.
    @discardableResult
    func markPendingReplacementWipeCommitted(
        accountHash: String,
        storeIdentity: LocalStoreIdentity
    ) -> Bool {
        Task126OwnerStoreGate.withAutomaticScopeLeaseInvalidated {
            guard hasPendingReplacementJournal,
                  var journal = replacementJournal,
                  journal.replacement.accountHash == accountHash,
                  journal.replacement.storeIdentity == storeIdentity else {
                return false
            }
            if journal.wipeCommitted { return true }
            journal.wipeCommitted = true
            guard persistReplacementJournalWithLeaseHeld(journal) else { return false }
            return pendingReplacement?.accountHash == accountHash
                && pendingReplacement?.storeIdentity == storeIdentity
                && pendingReplacementWipeCommitted
        }
    }

    func clearPendingReplacement() {
        Task126OwnerStoreGate.withAutomaticScopeLeaseInvalidated {
            _ = clearReplacementJournalWithLeaseHeld()
        }
    }

    /// Completes the durable replacement journal only after the full remote
    /// recovery has succeeded and the caller has revalidated the same account
    /// and shop. A missing, undecodable, or retargeted journal fails closed.
    @discardableResult
    func completePendingReplacementRecovery(
        accountHash: String,
        storeIdentity: LocalStoreIdentity
    ) -> Bool {
        Task126OwnerStoreGate.withAutomaticScopeLeaseInvalidated {
            completePendingReplacementRecoveryWithLeaseHeld(
                accountHash: accountHash,
                storeIdentity: storeIdentity
            )
        }
    }

    /// Atomically rejects a stale recovery scope, invalidates all work that
    /// captured the accepted generation, and clears the exact committed
    /// journal. The raw mutation deliberately runs under the gate's one lock.
    @discardableResult
    func completePendingReplacementRecovery(
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        expectedLeaseGeneration: UInt64
    ) throws -> Bool {
        try Task126OwnerStoreGate.withValidatedAutomaticScopeLeaseInvalidated(
            expectedGeneration: expectedLeaseGeneration
        ) {
            completePendingReplacementRecoveryWithLeaseHeld(
                accountHash: accountHash,
                storeIdentity: storeIdentity
            )
        }
    }

    var automaticallyPresentedDecisionIdentities: Set<String> {
        Set((defaults.stringArray(forKey: presentedDecisionIdentitiesKey) ?? []).filter(
            Self.isRedactedDecisionIdentity
        ))
    }

    var isAutomaticDecisionPresentationDisabled: Bool {
        defaults.bool(forKey: presentedDecisionIdentitiesOverflowKey)
    }

    /// Persists only the already-redacted dialog fingerprint and keeps the
    /// history bounded so the same mismatch is not auto-presented on relaunch.
    @discardableResult
    func markDecisionIdentityAutomaticallyPresented(
        _ identity: String,
        maximumCount: Int = 64
    ) -> Bool {
        guard Self.isRedactedDecisionIdentity(identity), maximumCount > 0 else { return false }
        var identities = Array(automaticallyPresentedDecisionIdentities).sorted()
        guard !identities.contains(identity) else { return false }
        guard !isAutomaticDecisionPresentationDisabled else { return false }
        guard identities.count < maximumCount else {
            // Never evict an old fingerprint: eviction would make that exact
            // mismatch auto-present again after enough unrelated identities.
            // Once the bounded redacted set is full, automatic presentation
            // stays disabled while the manual Review CTA remains available.
            defaults.set(true, forKey: presentedDecisionIdentitiesOverflowKey)
            return false
        }
        identities.append(identity)
        defaults.set(identities, forKey: presentedDecisionIdentitiesKey)
        return automaticallyPresentedDecisionIdentities.contains(identity)
    }

    private static func isRedactedDecisionIdentity(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
    }

    func resolveOwnerStoreBinding(
        userID: UUID,
        activeStoreIdentity: LocalStoreIdentity,
        isLocalStoreCompletelyEmpty: Bool,
        stateReadFailed: Bool = false,
        allowAutoBind: Bool = true
    ) -> OwnerStoreBindingResolution {
        guard !stateReadFailed else {
            return .reviewRequired(.localStateUnavailable)
        }

        let accountHash = Self.accountHash(for: userID)
        guard !activeStoreIdentity.isEmpty,
              activeStoreIdentity != .anonymous else {
            return .reviewRequired(.shopContextUnavailable)
        }
        let targetIdentity = activeStoreIdentity

        if hasPendingReplacementJournal, pendingReplacement == nil {
            return .reviewRequired(.replacementInterrupted)
        }

        if let replacement = pendingReplacement {
            guard replacement.accountHash == accountHash,
                  Self.sameLogicalStore(replacement.storeIdentity, targetIdentity) else {
                return .reviewRequired(.replacementInterrupted)
            }
            // The journal itself is the durable fail-closed admission token.
            // The old active generation remains intact and must not be rebound
            // or emptied while the new generation is prepared off-store.
            guard let recovery = pendingRecoveryJournal,
                  recovery.replacement == replacement else {
                return .reviewRequired(.replacementInterrupted)
            }
            if recovery.phase == .activated {
                guard let binding = currentBinding,
                      binding.accountHash == accountHash,
                      binding.storeIdentity == targetIdentity else {
                    return .reviewRequired(.replacementInterrupted)
                }
            }
            return .matched
        }

        guard let binding = currentBinding else {
            guard isLocalStoreCompletelyEmpty else {
                return .reviewRequired(.unboundDirty)
            }
            guard allowAutoBind else { return .matched }
            guard saveBinding(accountHash: accountHash, storeIdentity: targetIdentity) else {
                return .reviewRequired(.localStateUnavailable)
            }
            return .autoBound
        }

        guard binding.accountHash == accountHash else {
            return .reviewRequired(.accountMismatch)
        }
        guard binding.storeIdentity.storeId == targetIdentity.storeId else {
            return .reviewRequired(.shopMismatch)
        }
        guard Self.sameLogicalStore(binding.storeIdentity, targetIdentity),
              !binding.storeIdentity.needsLegacyRepair else {
            guard allowAutoBind else {
                return .reviewRequired(.bindingMetadataMismatch)
            }
            return isLocalStoreCompletelyEmpty
                ? repairEmptyBinding(accountHash: accountHash, storeIdentity: targetIdentity)
                : .reviewRequired(.bindingMetadataMismatch)
        }
        return .matched
    }

    static func accountHash(for userID: UUID) -> String {
        redactedAccountHash(for: userID.uuidString.lowercased())
    }

    static func redactedAccountHash(for value: String) -> String {
        let canonical = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func repairEmptyBinding(
        accountHash: String,
        storeIdentity: LocalStoreIdentity
    ) -> OwnerStoreBindingResolution {
        saveBinding(accountHash: accountHash, storeIdentity: storeIdentity)
            ? .autoBound
            : .reviewRequired(.localStateUnavailable)
    }

    private static func sameLogicalStore(
        _ lhs: LocalStoreIdentity,
        _ rhs: LocalStoreIdentity
    ) -> Bool {
        lhs.storeId == rhs.storeId
            && lhs.localStoreId == rhs.localStoreId
            && lhs.storeEpoch == rhs.storeEpoch
    }

    private func completePendingReplacementRecoveryWithLeaseHeld(
        accountHash: String,
        storeIdentity: LocalStoreIdentity
    ) -> Bool {
        guard hasPendingReplacementJournal,
              let recovery = pendingRecoveryJournal,
              recovery.phase == .activated,
              recovery.generationID != nil,
              recovery.checkpointDigest?.count == 64,
              recovery.watermark != nil,
              recovery.baselineRunID != nil,
              recovery.replacement.accountHash == accountHash,
              recovery.replacement.storeIdentity == storeIdentity,
              let binding = currentBinding,
              binding.accountHash == accountHash,
              binding.storeIdentity == storeIdentity else {
            return false
        }
        return clearReplacementJournalWithLeaseHeld()
    }

    private var replacementJournal: AccountReplacementJournal? {
        let data: Data
        if let durableJournalURL,
           FileManager.default.fileExists(atPath: durableJournalURL.path) {
            guard let durableData = try? Self.boundedJournalData(at: durableJournalURL) else {
                return nil
            }
            data = durableData
        } else {
            guard let defaultsData = defaults.data(forKey: replacementKey) else { return nil }
            data = defaultsData
        }
        if let journal = try? JSONDecoder().decode(AccountReplacementJournal.self, from: data) {
            return journal
        }
        // Journals written before wipe proof existed are deliberately treated
        // as prepared. The user can retry the same target, but sync stays closed.
        guard let legacyReplacement = try? JSONDecoder().decode(AccountBinding.self, from: data) else {
            return nil
        }
        return AccountReplacementJournal(
            replacement: legacyReplacement,
            wipeCommitted: false,
            modeRaw: AccountRecoveryJournalMode.accountOrShopReplacement.rawValue,
            phaseRaw: AccountRecoveryJournalPhase.prepared.rawValue,
            deviceIdentityHash: nil,
            generationID: nil,
            checkpointDigest: nil,
            watermark: nil,
            baselineRunID: nil
        )
    }

    /// Caller must already hold the owner/store lease lock. Keeping the raw
    /// persistence helper lock-free prevents nested acquisition from resolver
    /// paths that promote or bind an interrupted replacement.
    private func persistReplacementJournalWithLeaseHeld(
        _ journal: AccountReplacementJournal
    ) -> Bool {
        guard let data = try? JSONEncoder().encode(journal) else { return false }
        guard data.count <= Self.maximumDurableJournalBytes else { return false }
        if let durableJournalURL {
            do {
                let parent = durableJournalURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(
                    at: parent,
                    withIntermediateDirectories: true
                )
                try data.write(to: durableJournalURL, options: [.atomic])
                try Self.synchronizeFile(durableJournalURL)
                try Self.synchronizeDirectory(parent)
                guard try Self.boundedJournalData(at: durableJournalURL) == data else {
                    return false
                }
            } catch {
                return false
            }
        }
        defaults.set(data, forKey: replacementKey)
        return replacementJournal == journal
    }

    private func clearReplacementJournalWithLeaseHeld() -> Bool {
        // Clear the advisory mirror first. A crash before the durable file is
        // removed leaves the file latch present and therefore remains safe.
        defaults.removeObject(forKey: replacementKey)
        if let durableJournalURL,
           FileManager.default.fileExists(atPath: durableJournalURL.path) {
            do {
                try FileManager.default.removeItem(at: durableJournalURL)
                try Self.synchronizeDirectory(durableJournalURL.deletingLastPathComponent())
            } catch {
                return false
            }
        }
        return !hasPendingReplacementJournal
    }

    private static func defaultDurableJournalURL() -> URL? {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent("SyncStoreGenerations", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("recovery-journal.json", isDirectory: false)
    }

    private static func boundedJournalData(at url: URL) throws -> Data {
        // `URL` resource values may be cached across the atomic rename used for
        // a journal phase transition. Recreate the file URL so the size and type
        // describe the new inode rather than the previously opened journal.
        let freshURL = URL(fileURLWithPath: url.path, isDirectory: false)
        let values = try freshURL.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ])
        guard values.isRegularFile == true,
              values.isSymbolicLink != true,
              let size = values.fileSize,
              size >= 0,
              size <= maximumDurableJournalBytes else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let data = try Data(contentsOf: freshURL, options: [.mappedIfSafe])
        guard data.count == size else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return data
    }

    private static func synchronizeFile(_ url: URL) throws {
        #if canImport(Darwin)
        let descriptor = Darwin.open(url.path, O_RDONLY)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { _ = Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0 else { throw CocoaError(.fileWriteUnknown) }
        #else
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.synchronize()
        #endif
    }

    private static func synchronizeDirectory(_ url: URL) throws {
        #if canImport(Darwin)
        let descriptor = Darwin.open(url.path, O_RDONLY)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { _ = Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0 else { throw CocoaError(.fileWriteUnknown) }
        #endif
    }

    private func saveBindingWithLeaseHeld(
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        boundAt: Date
    ) -> Bool {
        let binding = AccountBinding(
            accountHash: accountHash,
            storeIdentity: storeIdentity,
            boundAt: boundAt
        )
        guard let data = try? JSONEncoder().encode(binding) else { return false }
        defaults.set(data, forKey: key)
        guard let persisted = currentBinding else { return false }
        return persisted.accountHash == binding.accountHash
            && persisted.storeIdentity == binding.storeIdentity
    }

    private func updatePendingRecovery(
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        deviceIdentityHash: String,
        mutation: (inout AccountReplacementJournal) -> Bool
    ) -> Bool {
        do {
            return try Task126OwnerStoreGate.withCurrentAutomaticScopeLeaseIfPresent {
                guard var journal = replacementJournal,
                      journal.replacement.accountHash == accountHash,
                      journal.replacement.storeIdentity == storeIdentity,
                      journal.deviceIdentityHash == deviceIdentityHash,
                      mutation(&journal) else {
                    return false
                }
                return persistReplacementJournalWithLeaseHeld(journal)
            }
        } catch {
            return false
        }
    }

    private func updatePendingRecoveryWithLeaseHeld(
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        deviceIdentityHash: String,
        mutation: (inout AccountReplacementJournal) -> Bool
    ) -> Bool {
        guard var journal = replacementJournal,
              journal.replacement.accountHash == accountHash,
              journal.replacement.storeIdentity == storeIdentity,
              journal.deviceIdentityHash == deviceIdentityHash,
              mutation(&journal) else {
            return false
        }
        return persistReplacementJournalWithLeaseHeld(journal)
    }

    private static func prepareJournalForStaging(
        _ journal: inout AccountReplacementJournal,
        generationID: UUID
    ) -> Bool {
        if let existing = journal.generationID, existing != generationID {
            // A verified generation may have been activated just before a
            // checkpoint-C drift. A newer exact-scope generation may stage,
            // while the already active store remains valid and immutable.
            journal.checkpointDigest = nil
            journal.watermark = nil
            journal.baselineRunID = nil
        }
        journal.generationID = generationID
        journal.phaseRaw = AccountRecoveryJournalPhase.staging.rawValue
        journal.wipeCommitted = false
        return true
    }

    private static func prepareJournalForVerification(
        _ journal: inout AccountReplacementJournal,
        generationID: UUID,
        checkpointDigest: String,
        watermark: Int64,
        baselineRunID: UUID
    ) -> Bool {
        guard journal.generationID == generationID else { return false }
        journal.phaseRaw = AccountRecoveryJournalPhase.verified.rawValue
        journal.checkpointDigest = checkpointDigest
        journal.watermark = watermark
        journal.baselineRunID = baselineRunID
        journal.wipeCommitted = false
        return true
    }
}

nonisolated enum OwnerStoreBindingReviewReason: String, Sendable, Equatable {
    case unboundDirty
    case accountMismatch
    case shopMismatch
    case bindingMetadataMismatch
    case replacementInterrupted
    case localStateUnavailable
    case shopContextUnavailable
}

nonisolated enum OwnerStoreBindingResolution: Sendable, Equatable {
    case matched
    case autoBound
    case reviewRequired(OwnerStoreBindingReviewReason)

    nonisolated var allowsAutomaticSync: Bool {
        switch self {
        case .matched, .autoBound:
            return true
        case .reviewRequired:
            return false
        }
    }
}
