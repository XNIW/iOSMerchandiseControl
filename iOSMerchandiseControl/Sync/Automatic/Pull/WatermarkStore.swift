import Foundation

nonisolated struct WatermarkStore {
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
        if let value = int64(forKey: key(for: scope)) {
            return value
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
        defaults.set(Int(watermark), forKey: key(for: scope))
    }

    func key(for scope: Scope) -> String {
        Self.watermarkKey(accountHash: scope.accountHash, storeIdentity: scope.storeIdentity)
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
