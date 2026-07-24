import CryptoKit
import Foundation

nonisolated struct WatermarkStore {
    private struct RecoveryCheckpointRecord: Codable, Equatable {
        static let schemaVersion = "sync-watermark-generation-v1"

        let schema: String
        let generationID: UUID
        let value: Int64
        let checksum: String
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
