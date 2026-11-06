import CryptoKit
import Foundation
import SwiftData

nonisolated struct WatermarkStore {
    /// The row lives in the same SwiftData store as the changes it accepts.
    /// Defaults remains the mirror used by V6, including verified no-op advances.
    nonisolated struct MaterialCheckpoint: Codable, Equatable, Sendable {
        private static let format = "incremental-material-checkpoint-v1"
        let generationID: UUID?
        let from: Int64
        let through: Int64
        let verifiedScopeKey: String?
        private let shopID: UUID
        private let deviceIdentityHash: String
        private let storeIdentity: LocalStoreIdentity

        private static func recordID(accountHash: String, shopID: UUID) -> String {
            "\(format):\(accountHash):\(shopID.uuidString.lowercased())"
        }

        private static func row(in context: ModelContext, accountHash: String, shopID: UUID) throws -> SyncEventOutboxEntry? {
            let id = recordID(accountHash: accountHash, shopID: shopID)
            var descriptor = FetchDescriptor<SyncEventOutboxEntry>(predicate: #Predicate { $0.id == id })
            descriptor.fetchLimit = 2
            let rows = try context.fetch(descriptor)
            guard rows.count <= 1 else { throw ShopSyncRecoveryContractError.scopeFenceMissing }
            return rows.first
        }

        static func read(in context: ModelContext, scope: Task126VerifiedOwnerStoreScope) throws -> Self? {
            guard let row = try row(in: context, accountHash: scope.accountHash, shopID: scope.shopID) else { return nil }
            return try decode(row, in: context, scope: scope)
        }

        /// Bootstrap does not register the opened container until the terminal
        /// manifest has been checked. Use that exact manifest as the read fence.
        static func read(in context: ModelContext, finalizedManifest manifest: SyncStoreGenerationManifest) throws -> Self? {
            guard let row = try row(in: context, accountHash: manifest.accountHash, shopID: manifest.shopID) else { return nil }
            return try decode(row, accountHash: manifest.accountHash, shopID: manifest.shopID,
                storeIdentity: manifest.storeIdentity, deviceIdentityHash: manifest.deviceIdentityHash,
                generationID: manifest.generationID)
        }

        private static func decode(_ row: SyncEventOutboxEntry, in context: ModelContext,
                                   scope: Task126VerifiedOwnerStoreScope) throws -> Self {
            let manifest = Task126OwnerStoreGate.activeManifestWithLeaseHeld(context.container)
            if let manifest {
                guard manifest.accountHash == scope.accountHash, manifest.shopID == scope.shopID,
                      manifest.deviceIdentityHash == scope.deviceIdentityHash,
                      manifest.storeIdentity.hasSameProvenance(as: scope.storeIdentity) else {
                    throw ShopSyncRecoveryContractError.scopeFenceMissing
                }
            }
            return try decode(row, accountHash: scope.accountHash, shopID: scope.shopID,
                storeIdentity: scope.storeIdentity, deviceIdentityHash: scope.deviceIdentityHash,
                generationID: manifest?.generationID)
        }

        private static func decode(_ row: SyncEventOutboxEntry, accountHash: String, shopID: UUID,
                                   storeIdentity: LocalStoreIdentity, deviceIdentityHash: String,
                                   generationID: UUID?) throws -> Self {
            guard row.status == .localOnly, row.domain == format, row.metadataShape == format,
                  let owner = UUID(uuidString: row.ownerUserID),
                  AccountBindingStore.accountHash(for: owner) == accountHash,
                  let payload = row.metadataPayloadJSON, payload.utf8.count <= 2_048,
                  ShopSyncRecoveryCanonical.sha256(payload) == row.entityIDsShape,
                  let receipt = try? JSONDecoder().decode(Self.self, from: Data(payload.utf8)),
                  receipt.generationID == generationID,
                  receipt.shopID == shopID, receipt.deviceIdentityHash == deviceIdentityHash,
                  receipt.storeIdentity.hasSameProvenance(as: storeIdentity),
                  receipt.verifiedScopeKey.map(ShopSyncRecoveryCanonical.isRedactedKey) ?? true,
                  receipt.from >= 0, receipt.through > receipt.from else {
                throw ShopSyncRecoveryContractError.scopeFenceMissing
            }
            return receipt
        }

        /// Call inside the transaction, with the active scope lease held.
        static func stage(from: Int64, through: Int64, verifiedScopeKey: String?, in context: ModelContext,
                          scope: Task126VerifiedOwnerStoreScope) throws {
            let manifest = Task126OwnerStoreGate.activeManifestWithLeaseHeld(context.container)
            let current = try row(in: context, accountHash: scope.accountHash, shopID: scope.shopID)
            guard through > from, from >= 0,
                  try current.map({ try decode($0, in: context, scope: scope).through <= from }) ?? true else {
                throw ShopSyncRecoveryContractError.scopeFenceMissing
            }
            if let manifest {
                guard manifest.accountHash == scope.accountHash, manifest.shopID == scope.shopID,
                      manifest.deviceIdentityHash == scope.deviceIdentityHash,
                      manifest.storeIdentity.hasSameProvenance(as: scope.storeIdentity),
                      let baseline = manifest.checkpoint.maxEventID, baseline <= from else {
                    throw ShopSyncRecoveryContractError.scopeFenceMissing
                }
            }
            let receipt = Self(generationID: manifest?.generationID, from: from, through: through,
                               verifiedScopeKey: verifiedScopeKey,
                               shopID: scope.shopID, deviceIdentityHash: scope.deviceIdentityHash,
                               storeIdentity: scope.storeIdentity)
            let data = try JSONEncoder().encode(receipt)
            guard data.count <= 2_048, let payload = String(data: data, encoding: .utf8) else {
                throw ShopSyncRecoveryContractError.scopeFenceMissing
            }
            let now = Date()
            let hash = ShopSyncRecoveryCanonical.sha256(payload)
            if let current {
                current.metadataPayloadJSON = payload
                current.entityIDsShape = hash
                current.updatedAt = now
            } else {
                let id = recordID(accountHash: scope.accountHash, shopID: scope.shopID)
                context.insert(SyncEventOutboxEntry(id: id,
                    ownerUserID: scope.ownerUserID.uuidString.lowercased(),
                    storeId: scope.storeIdentity.storeId, localStoreId: scope.storeIdentity.localStoreId,
                    syncProtocolVersion: scope.storeIdentity.syncProtocolVersion,
                    schemaVersion: scope.storeIdentity.schemaVersion, storeEpoch: scope.storeIdentity.storeEpoch,
                    clientEventID: id, domain: format, eventType: format, changedCount: 0,
                    entityIDsShape: hash, metadataShape: format, metadataPayloadJSON: payload,
                    status: .localOnly, nextRetryAt: now, createdAt: now, updatedAt: now))
            }
        }
    }

    private struct RecoveryCheckpointRecord: Codable, Equatable {
        static let schemaVersion = "sync-watermark-generation-v1"

        let schema: String
        let generationID: UUID
        let value: Int64
        let checksum: String
    }

    nonisolated enum GenerationProvenance: Equatable, Sendable {
        case absent
        case identified(UUID)
        case invalid
    }

    nonisolated struct Scope: Equatable, Hashable, Sendable {
        var accountHash: String
        var storeIdentity: LocalStoreIdentity
        var legacyOwnerUserID: UUID?

        init(
            accountHash: String,
            storeIdentity: LocalStoreIdentity,
            legacyOwnerUserID: UUID? = nil
        ) {
            self.accountHash = Self.normalized(accountHash)
            self.storeIdentity = storeIdentity.isEmpty ? .anonymous : storeIdentity
            self.legacyOwnerUserID = legacyOwnerUserID
        }

        init(ownerUserID: UUID, storeIdentity: LocalStoreIdentity) {
            self.init(
                accountHash: AccountBindingStore.accountHash(for: ownerUserID),
                storeIdentity: storeIdentity,
                legacyOwnerUserID: ownerUserID
            )
        }

        private static func normalized(_ value: String) -> String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return trimmed.isEmpty ? "anonymous" : trimmed
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func watermark(for scope: Scope) -> Int64 {
        let generationKey = generationRecordKey(for: scope)
        if defaults.object(forKey: generationKey) != nil {
            return validatedGenerationRecord(for: scope)?.value ?? 0
        }
        if let value = int64(forKey: key(for: scope)) {
            return value
        }
        guard scope.storeIdentity == .anonymous else {
            return 0
        }
        if let legacy = int64(forKey: Self.legacyAccountWatermarkKey(accountHash: scope.accountHash, storeIdentity: scope.storeIdentity)) {
            return legacy
        }
        if let ownerUserID = scope.legacyOwnerUserID,
           let legacy = int64(forKey: Self.legacyOwnerWatermarkKey(ownerUserID: ownerUserID)) {
            return legacy
        }
        return 0
    }

    /// Reports existing generation authority without repairing or creating it.
    func generationProvenance(for scope: Scope) -> GenerationProvenance {
        guard defaults.object(forKey: generationRecordKey(for: scope)) != nil else {
            return .absent
        }
        guard let record = validatedGenerationRecord(for: scope),
              int64(forKey: key(for: scope)) == record.value else {
            return .invalid
        }
        return .identified(record.generationID)
    }

    func save(_ watermark: Int64, for scope: Scope) {
        let current = self.watermark(for: scope)
        guard watermark >= current else { return }
        let generationKey = generationRecordKey(for: scope)
        if defaults.object(forKey: generationKey) != nil {
            guard let currentRecord = validatedGenerationRecord(for: scope) else { return }
            guard persistGenerationRecord(
                value: watermark,
                generationID: currentRecord.generationID,
                scope: scope
            ) else { return }
        }
        defaults.set(Int(watermark), forKey: key(for: scope))
    }

    /// Read-only authority check. A legacy scalar, corrupt record or another
    /// generation at the same cursor cannot authorize ordinary continuation.
    func matchesRecoveryGeneration(
        _ generationID: UUID,
        watermark: Int64,
        scope: Scope
    ) -> Bool {
        guard let record = validatedGenerationRecord(for: scope) else { return false }
        return record.generationID == generationID
            && record.value == watermark
            && int64(forKey: key(for: scope)) == watermark
    }

    /// Replacement starts a new local snapshot for this exact account/shop.
    /// Unlike normal checkpoints, it must be able to move a stale watermark
    /// backwards so that an older (but complete) remote stream is not skipped.
    @discardableResult
    func resetForReplacement(scope: Scope) -> Bool {
        defaults.set(0, forKey: key(for: scope))
        return int64(forKey: key(for: scope)) == 0
    }

    /// Commits the terminal checkpoint produced by a complete replacement
    /// recovery. This is deliberately authoritative (and may move backwards)
    /// because the pre-recovery checkpoint belongs to the discarded snapshot.
    @discardableResult
    func saveAuthoritativeRecoveryCheckpoint(
        _ watermark: Int64,
        generationID: UUID,
        for scope: Scope
    ) -> Bool {
        guard watermark >= 0 else { return false }
        guard persistGenerationRecord(
            value: watermark,
            generationID: generationID,
            scope: scope
        ) else { return false }
        defaults.set(Int(watermark), forKey: key(for: scope))
        return validatedGenerationRecord(for: scope)?.generationID == generationID
            && validatedGenerationRecord(for: scope)?.value == watermark
            && int64(forKey: key(for: scope)) == watermark
    }

    /// Reconciles UserDefaults after a crash using the fsynced terminal
    /// receipt. Progress already recorded for the same generation is kept;
    /// a stale pre-replacement cursor from another generation is replaced.
    @discardableResult
    func restoreAuthoritativeRecoveryCheckpoint(
        _ watermark: Int64,
        generationID: UUID,
        for scope: Scope
    ) -> Bool {
        guard watermark >= 0 else { return false }
        if let current = validatedGenerationRecord(for: scope),
           current.generationID == generationID,
           current.value >= watermark {
            defaults.set(Int(current.value), forKey: key(for: scope))
            return int64(forKey: key(for: scope)) == current.value
        }
        return saveAuthoritativeRecoveryCheckpoint(
            watermark,
            generationID: generationID,
            for: scope
        )
    }

    func key(for scope: Scope) -> String {
        Self.watermarkKey(accountHash: scope.accountHash, storeIdentity: scope.storeIdentity)
    }

    private func generationRecordKey(for scope: Scope) -> String {
        "\(key(for: scope)).generation"
    }

    private func validatedGenerationRecord(
        for scope: Scope
    ) -> RecoveryCheckpointRecord? {
        guard let data = defaults.data(forKey: generationRecordKey(for: scope)),
              data.count <= 2_048,
              let record = try? JSONDecoder().decode(RecoveryCheckpointRecord.self, from: data),
              record.schema == RecoveryCheckpointRecord.schemaVersion,
              record.value >= 0,
              record.checksum == generationRecordChecksum(
                value: record.value,
                generationID: record.generationID,
                scope: scope
              ) else { return nil }
        return record
    }

    private func persistGenerationRecord(
        value: Int64,
        generationID: UUID,
        scope: Scope
    ) -> Bool {
        let record = RecoveryCheckpointRecord(
            schema: RecoveryCheckpointRecord.schemaVersion,
            generationID: generationID,
            value: value,
            checksum: generationRecordChecksum(
                value: value,
                generationID: generationID,
                scope: scope
            )
        )
        guard let data = try? JSONEncoder().encode(record), data.count <= 2_048 else {
            return false
        }
        defaults.set(data, forKey: generationRecordKey(for: scope))
        return validatedGenerationRecord(for: scope) == record
    }

    private func generationRecordChecksum(
        value: Int64,
        generationID: UUID,
        scope: Scope
    ) -> String {
        let material = [
            RecoveryCheckpointRecord.schemaVersion,
            scope.accountHash,
            scope.storeIdentity.rawValue,
            generationID.uuidString.lowercased(),
            String(value)
        ].joined(separator: "|")
        return SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func watermarkKey(accountHash: String, storeIdentity: LocalStoreIdentity) -> String {
        let normalizedAccount = accountHash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let accountComponent = normalizedAccount.isEmpty ? "anonymous" : normalizedAccount
        let storeComponent = storeIdentity.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "sync.events.watermark.account.\(accountComponent).store.\(storeComponent.isEmpty ? "anonymous" : storeComponent)"
    }

    static func legacyAccountWatermarkKey(accountHash: String, storeIdentity: LocalStoreIdentity) -> String {
        let normalizedAccount = accountHash.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let accountComponent = normalizedAccount.isEmpty ? "anonymous" : normalizedAccount
        let storeComponent = storeIdentity.rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "task115.syncEvents.watermark.account.\(accountComponent).store.\(storeComponent.isEmpty ? "anonymous" : storeComponent)"
    }

    static func legacyOwnerWatermarkKey(ownerUserID: UUID) -> String {
        "task114.syncEvents.watermark.\(ownerUserID.uuidString.lowercased())"
    }

    static func legacyWatermarkKey(ownerUserID: UUID) -> String {
        legacyOwnerWatermarkKey(ownerUserID: ownerUserID)
    }

    private func int64(forKey key: String) -> Int64? {
        guard let value = defaults.object(forKey: key) else { return nil }
        if let int = value as? Int {
            return Int64(int)
        }
        if let int64 = value as? Int64 {
            return int64
        }
        if let number = value as? NSNumber {
            return number.int64Value
        }
        return nil
    }
}
