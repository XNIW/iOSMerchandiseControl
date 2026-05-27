import Foundation

nonisolated struct LocalStoreIdentity: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    let rawValue: String
    let defaultStoreId: String
    let localStoreId: String
    let schemaVersion: Int
    let syncProtocolVersion: Int
    let storeEpoch: Int

    init(rawValue: String) {
        self.init(
            rawValue: rawValue,
            defaultStoreId: Task126SyncPolicy.defaultStoreId,
            localStoreId: nil,
            schemaVersion: Task126SyncPolicy.localSchemaVersion,
            syncProtocolVersion: Task126SyncPolicy.syncProtocolVersion,
            storeEpoch: Task126SyncPolicy.defaultStoreEpoch
        )
    }

    init(
        rawValue: String,
        defaultStoreId: String,
        localStoreId: String?,
        schemaVersion: Int,
        syncProtocolVersion: Int,
        storeEpoch: Int
    ) {
        let normalizedStoreId = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDefaultStoreId = Task126OwnerStoreScope.normalizedStoreId(defaultStoreId)
        self.rawValue = normalizedStoreId
        self.defaultStoreId = normalizedDefaultStoreId
        self.localStoreId = Task126OwnerStoreScope.normalizedLocalStoreId(
            localStoreId,
            storeId: normalizedStoreId.isEmpty ? normalizedDefaultStoreId : normalizedStoreId
        )
        self.schemaVersion = schemaVersion
        self.syncProtocolVersion = syncProtocolVersion
        self.storeEpoch = storeEpoch
    }

    var isEmpty: Bool {
        rawValue.isEmpty
    }

    var storeId: String {
        rawValue.isEmpty ? defaultStoreId : rawValue
    }

    var needsLegacyRepair: Bool {
        rawValue.isEmpty || localStoreId.isEmpty || schemaVersion < Task126SyncPolicy.localSchemaVersion
            || syncProtocolVersion < Task126SyncPolicy.syncProtocolVersion
    }

    static let anonymous = LocalStoreIdentity(rawValue: "anonymous")

    enum CodingKeys: String, CodingKey {
        case rawValue
        case defaultStoreId
        case localStoreId
        case schemaVersion
        case syncProtocolVersion
        case storeEpoch
    }

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let rawValue = try? single.decode(String.self) {
            self.init(rawValue: rawValue)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decodeIfPresent(String.self, forKey: .rawValue) ?? ""
        self.init(
            rawValue: rawValue,
            defaultStoreId: try container.decodeIfPresent(String.self, forKey: .defaultStoreId) ?? Task126SyncPolicy.defaultStoreId,
            localStoreId: try container.decodeIfPresent(String.self, forKey: .localStoreId),
            schemaVersion: try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Task126SyncPolicy.localSchemaVersion,
            syncProtocolVersion: try container.decodeIfPresent(Int.self, forKey: .syncProtocolVersion) ?? Task126SyncPolicy.syncProtocolVersion,
            storeEpoch: try container.decodeIfPresent(Int.self, forKey: .storeEpoch) ?? Task126SyncPolicy.defaultStoreEpoch
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawValue, forKey: .rawValue)
        try container.encode(defaultStoreId, forKey: .defaultStoreId)
        try container.encode(localStoreId, forKey: .localStoreId)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(syncProtocolVersion, forKey: .syncProtocolVersion)
        try container.encode(storeEpoch, forKey: .storeEpoch)
    }
}

nonisolated struct AccountBinding: Codable, Equatable, Sendable {
    var accountHash: String
    var storeIdentity: LocalStoreIdentity
    var boundAt: Date

    init(
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        boundAt: Date = Date()
    ) {
        self.accountHash = accountHash
        self.storeIdentity = storeIdentity
        self.boundAt = boundAt
    }
}
