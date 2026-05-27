import Foundation

nonisolated enum Task126StoreScopeMode: String, Sendable, Equatable {
    case localDefaultStoreOnly
    case remoteStoreAware
}

nonisolated enum Task126CacheMode: String, Sendable, Equatable {
    case logicalScope
    case physicalStore
}

nonisolated struct Task126FeatureFlags: Sendable, Equatable {
    var strictOwnerStoreGate: Bool
    var conflictReviewV2: Bool
    var physicalMultiStoreCache: Bool
}

nonisolated enum Task126SyncPolicy {
    static let defaultStoreId = "default"
    static let syncProtocolVersion = 126
    static let localSchemaVersion = 2
    static let defaultStoreEpoch = 1
    static let maxProductPricePageSize = 500
    static let activeStoreOnly = true
    static let ownerStoreMismatchFailClosed = true
    static let noCrossStorePendingPush = true
    static let storeScopeMode: Task126StoreScopeMode = .localDefaultStoreOnly
    static let cacheMode: Task126CacheMode = .logicalScope
    static let featureFlags = Task126FeatureFlags(
        strictOwnerStoreGate: true,
        conflictReviewV2: true,
        physicalMultiStoreCache: false
    )
}

nonisolated struct Task126ConflictMatrixCase: Sendable, Equatable {
    let id: String
}

nonisolated enum Task126ConflictMatrix {
    static let allCases: [Task126ConflictMatrixCase] = (0...60).map {
        Task126ConflictMatrixCase(id: String(format: "C126-%02d", $0))
    }
}

nonisolated enum Task126ReviewReason: String, Sendable, Equatable, Comparable {
    case sameField
    case deleteVsEdit
    case domainInvariant

    static func < (lhs: Task126ReviewReason, rhs: Task126ReviewReason) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    private var sortOrder: Int {
        switch self {
        case .sameField:
            return 0
        case .deleteVsEdit:
            return 1
        case .domainInvariant:
            return 2
        }
    }
}

nonisolated enum Task126ConflictDecision: Sendable, Equatable {
    case autoMerge
    case review(reason: Task126ReviewReason)
}

nonisolated enum Task126ConflictResolver {
    static func resolve(
        localChangedFields: [String],
        remoteChangedFields: [String],
        remoteDeleted: Bool = false,
        domainInvariantViolated: Bool = false
    ) -> Task126ConflictDecision {
        if remoteDeleted || localChangedFields.contains(where: isDeleteMarker) {
            return .review(reason: .deleteVsEdit)
        }
        if domainInvariantViolated {
            return .review(reason: .domainInvariant)
        }

        let local = Set(localChangedFields.map(normalizeField).filter { !$0.isEmpty })
        let remote = Set(remoteChangedFields.map(normalizeField).filter { !$0.isEmpty })
        return local.isDisjoint(with: remote) ? .autoMerge : .review(reason: .sameField)
    }

    private static func normalizeField(_ field: String) -> String {
        field.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isDeleteMarker(_ field: String) -> Bool {
        let normalized = normalizeField(field)
        return normalized == "delete" || normalized == "deletedat" || normalized == "tombstone"
    }
}

nonisolated enum Task126ChangedFieldsContract {
    static func isValid(
        operation: LocalPendingChangeOperation,
        changedFields: [String]
    ) -> Bool {
        switch operation {
        case .update, .upsert:
            return !changedFields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.isEmpty
        case .create, .delete:
            return true
        }
    }
}

nonisolated enum Task126ConflictBatchReview {
    struct Item: Sendable, Equatable {
        var localChangedFields: [String]
        var remoteChangedFields: [String]
        var remoteDeleted: Bool
        var domainInvariantViolated: Bool

        init(
            localChangedFields: [String],
            remoteChangedFields: [String],
            remoteDeleted: Bool = false,
            domainInvariantViolated: Bool = false
        ) {
            self.localChangedFields = localChangedFields
            self.remoteChangedFields = remoteChangedFields
            self.remoteDeleted = remoteDeleted
            self.domainInvariantViolated = domainInvariantViolated
        }
    }

    struct Summary: Sendable, Equatable {
        var autoMergeCount: Int
        var reviewCount: Int
        var reasons: [Task126ReviewReason]
    }

    static func summarize(_ items: [Item]) -> Summary {
        var autoMergeCount = 0
        var reasons: [Task126ReviewReason] = []

        for item in items {
            switch Task126ConflictResolver.resolve(
                localChangedFields: item.localChangedFields,
                remoteChangedFields: item.remoteChangedFields,
                remoteDeleted: item.remoteDeleted,
                domainInvariantViolated: item.domainInvariantViolated
            ) {
            case .autoMerge:
                autoMergeCount += 1
            case .review(let reason):
                reasons.append(reason)
            }
        }

        return Summary(
            autoMergeCount: autoMergeCount,
            reviewCount: reasons.count,
            reasons: Array(Set(reasons)).sorted()
        )
    }
}

nonisolated enum Task126ProductPriceDecision: String, Sendable, Equatable {
    case append
    case dedupe
    case reviewStale
}

nonisolated enum Task126ProductPriceHistoryPolicy {
    static func resolve(
        existingCanonicalPrice: String?,
        incomingCanonicalPrice: String
    ) -> Task126ProductPriceDecision {
        guard let existingCanonicalPrice else {
            return .append
        }
        return existingCanonicalPrice == incomingCanonicalPrice ? .dedupe : .reviewStale
    }

    static func pageLimit(requested: Int) -> Int {
        min(max(1, requested), Task126SyncPolicy.maxProductPricePageSize)
    }
}

nonisolated struct Task126OwnerStoreScope: Sendable, Equatable {
    var ownerHash: String
    var storeId: String
    var localStoreId: String
    var syncProtocolVersion: Int
    var schemaVersion: Int
    var storeEpoch: Int

    init(
        ownerHash: String,
        storeId: String?,
        localStoreId: String?,
        syncProtocolVersion: Int = Task126SyncPolicy.syncProtocolVersion,
        schemaVersion: Int = Task126SyncPolicy.localSchemaVersion,
        storeEpoch: Int = Task126SyncPolicy.defaultStoreEpoch
    ) {
        self.ownerHash = ownerHash.trimmingCharacters(in: .whitespacesAndNewlines)
        self.storeId = Self.normalizedStoreId(storeId)
        self.localStoreId = Self.normalizedLocalStoreId(localStoreId, storeId: self.storeId)
        self.syncProtocolVersion = syncProtocolVersion
        self.schemaVersion = schemaVersion
        self.storeEpoch = storeEpoch
    }

    static func normalizedStoreId(_ value: String?) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Task126SyncPolicy.defaultStoreId : trimmed
    }

    static func normalizedLocalStoreId(_ value: String?, storeId: String) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "local-\(storeId)" : trimmed
    }
}

nonisolated enum Task126OwnerStoreGateReason: String, Sendable, Equatable {
    case ownerMismatch
    case storeMismatch
    case localStoreMismatch
    case schemaMismatch
}

nonisolated enum Task126OwnerStoreGateDecision: Sendable, Equatable {
    case allowed
    case blocked(reason: Task126OwnerStoreGateReason)
}

nonisolated enum Task126OwnerStoreGate {
    static func validate(
        entry: SyncEventOutboxEntry,
        activeOwnerUserID: String,
        activeStoreId: String,
        activeLocalStoreId: String? = nil
    ) -> Task126OwnerStoreGateDecision {
        let owner = activeOwnerUserID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard entry.ownerUserID == owner else {
            return .blocked(reason: .ownerMismatch)
        }

        let expectedStore = Task126OwnerStoreScope.normalizedStoreId(activeStoreId)
        let entryStore = Task126OwnerStoreScope.normalizedStoreId(entry.storeId)
        guard entryStore == expectedStore else {
            return .blocked(reason: .storeMismatch)
        }

        if let activeLocalStoreId {
            let expectedLocalStore = Task126OwnerStoreScope.normalizedLocalStoreId(
                activeLocalStoreId,
                storeId: expectedStore
            )
            let entryLocalStore = Task126OwnerStoreScope.normalizedLocalStoreId(
                entry.localStoreId,
                storeId: entryStore
            )
            guard entryLocalStore == expectedLocalStore else {
                return .blocked(reason: .localStoreMismatch)
            }
        }

        guard entry.syncProtocolVersion == Task126SyncPolicy.syncProtocolVersion else {
            return .blocked(reason: .schemaMismatch)
        }
        return .allowed
    }
}

nonisolated enum Task126LegacyStoreRepairDecision: Sendable, Equatable {
    case noRepairNeeded
    case bindDefaultStore
    case reviewRequired
}

nonisolated enum Task126LegacyStoreRepairPolicy {
    static func decision(
        for identity: LocalStoreIdentity,
        hasLocalData: Bool
    ) -> Task126LegacyStoreRepairDecision {
        guard identity.needsLegacyRepair else {
            return .noRepairNeeded
        }
        return hasLocalData ? .reviewRequired : .bindDefaultStore
    }
}

nonisolated struct Task126CacheManifest: Sendable, Equatable {
    var ownerHash: String
    var storeId: String
    var localStoreId: String
    var schemaVersion: Int
    var syncProtocolVersion: Int
    var storeEpoch: Int
    var isActive: Bool
    var isDirty: Bool
    var estimatedBytes: Int

    var privacySafeSnapshot: Task126CacheManifestPrivacySnapshot {
        Task126CacheManifestPrivacySnapshot(
            ownerHashRedacted: "redacted:owner",
            storeIdRedacted: "redacted:store",
            localStoreIdRedacted: "redacted:local-store",
            schemaVersion: schemaVersion,
            syncProtocolVersion: syncProtocolVersion,
            storeEpoch: storeEpoch,
            isActive: isActive,
            isDirty: isDirty,
            estimatedBytes: estimatedBytes
        )
    }

    static func fixture(
        ownerHash: String = "owner-fixture",
        storeId: String,
        isActive: Bool,
        isDirty: Bool,
        estimatedBytes: Int = 1_024
    ) -> Task126CacheManifest {
        Task126CacheManifest(
            ownerHash: ownerHash,
            storeId: storeId,
            localStoreId: "local-\(storeId)",
            schemaVersion: Task126SyncPolicy.localSchemaVersion,
            syncProtocolVersion: Task126SyncPolicy.syncProtocolVersion,
            storeEpoch: Task126SyncPolicy.defaultStoreEpoch,
            isActive: isActive,
            isDirty: isDirty,
            estimatedBytes: estimatedBytes
        )
    }
}

nonisolated struct Task126CacheManifestPrivacySnapshot: Sendable, Equatable, CustomStringConvertible {
    var ownerHashRedacted: String
    var storeIdRedacted: String
    var localStoreIdRedacted: String
    var schemaVersion: Int
    var syncProtocolVersion: Int
    var storeEpoch: Int
    var isActive: Bool
    var isDirty: Bool
    var estimatedBytes: Int

    var description: String {
        "owner=\(ownerHashRedacted);store=\(storeIdRedacted);local=\(localStoreIdRedacted);schema=\(schemaVersion);protocol=\(syncProtocolVersion);epoch=\(storeEpoch);active=\(isActive);dirty=\(isDirty);bytes=\(estimatedBytes)"
    }
}

nonisolated enum Task126CachePolicyReason: String, Sendable, Equatable {
    case inactiveStoreLoaded
    case activeStoreMissing
}

nonisolated enum Task126CachePolicyDecision: Sendable, Equatable {
    case allowed
    case blocked(reason: Task126CachePolicyReason)
}

nonisolated enum Task126InactiveCacheCleanupDecision: Sendable, Equatable {
    case deleteCleanInactive
    case keepDirtyRequiresBackupExport
    case keepActive
}

nonisolated enum Task126CachePolicy {
    static func validateActiveStoreOnly(
        activeStoreId: String,
        loadedManifests: [Task126CacheManifest]
    ) -> Task126CachePolicyDecision {
        let activeStoreId = Task126OwnerStoreScope.normalizedStoreId(activeStoreId)
        guard loadedManifests.contains(where: { $0.storeId == activeStoreId && $0.isActive }) else {
            return .blocked(reason: .activeStoreMissing)
        }
        let inactiveLoaded = loadedManifests.contains { manifest in
            manifest.storeId != activeStoreId && manifest.isActive == false
        }
        return inactiveLoaded ? .blocked(reason: .inactiveStoreLoaded) : .allowed
    }

    static func cleanupDecision(
        for manifest: Task126CacheManifest
    ) -> Task126InactiveCacheCleanupDecision {
        if manifest.isActive {
            return .keepActive
        }
        return manifest.isDirty ? .keepDirtyRequiresBackupExport : .deleteCleanInactive
    }
}
