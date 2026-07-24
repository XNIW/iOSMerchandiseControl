import Foundation
import SwiftData

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

nonisolated struct Task126VerifiedOwnerStoreScope: Sendable, Equatable {
    let ownerUserID: UUID
    let accountHash: String
    let shopID: UUID
    let storeIdentity: LocalStoreIdentity
    let deviceInstallID: String
    let deviceIdentityHash: String
    let pendingReplacement: AccountBinding?
    let leaseGeneration: UInt64
}

nonisolated enum Task126OwnerStoreGateError: Error, Sendable, Equatable {
    case cancelled
    case activeAccountMismatch
    case shopContextUnavailable
    case bindingMismatch
    case replacementInterrupted
    case scopeChanged
    case retiredStoreGeneration
    case localModelUnavailable
    case localRemoteConflictRequiresReview
}

nonisolated enum Task126OwnerStoreGate {
    @TaskLocal static var currentAutomaticScope: Task126VerifiedOwnerStoreScope?

    private static let leaseStore = Task126AutomaticScopeLeaseStore()

    private static let activeAccountKey = "mobile.shopContext.activeAccountHash.v1"
    private static let blockedShopStatuses: Set<String> = [
        "blocked",
        "deleted",
        "disabled",
        "inactive",
        "revoked",
        "suspended"
    ]

    /// Captures the already-resolved owner/shop boundary used by automatic
    /// providers. This deliberately has no default-shop or anonymous fallback.
    static func captureAutomaticScope(
        ownerUserID: UUID,
        defaults: UserDefaults = .standard,
        allowsPendingReplacement: Bool = false,
        allowsPendingSameScopeRecovery: Bool = false
    ) throws -> Task126VerifiedOwnerStoreScope {
        try leaseStore.withCurrentLease { leaseGeneration in
            guard !Task.isCancelled else {
                throw Task126OwnerStoreGateError.cancelled
            }

            let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
            guard defaults.string(forKey: activeAccountKey) == accountHash else {
                throw Task126OwnerStoreGateError.activeAccountMismatch
            }

            let selectedShopStore = SelectedShopStore(defaults: defaults)
            guard selectedShopStore.isResolutionReady(accountHash: accountHash),
                  let selectedShop = selectedShopStore.selectedShop(accountHash: accountHash),
                  selectedShop.selectable,
                  !blockedShopStatuses.contains(
                    selectedShop.status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                  ) else {
                throw Task126OwnerStoreGateError.shopContextUnavailable
            }

            let storeIdentity = selectedShop.localStoreIdentity
            let bindingStore = AccountBindingStore(defaults: defaults)
            let deviceInstallID = try DeviceInstallIDStore(defaults: defaults)
                .requireDeviceInstallID()
            let deviceIdentityHash = DeviceInstallIDStore.identityHash(for: deviceInstallID)

            let pendingReplacement: AccountBinding?
            if bindingStore.hasPendingReplacementJournal {
                guard let recovery = bindingStore.pendingRecoveryJournal,
                      (allowsPendingReplacement
                        || (allowsPendingSameScopeRecovery
                            && recovery.mode == .sameScopeRecovery)),
                      let replacement = bindingStore.pendingReplacement,
                      replacement.accountHash == accountHash,
                      replacement.storeIdentity == storeIdentity,
                      recovery.replacement == replacement,
                      recovery.deviceIdentityHash == deviceIdentityHash else {
                    throw Task126OwnerStoreGateError.replacementInterrupted
                }
                if recovery.mode == .sameScopeRecovery {
                    guard let binding = bindingStore.currentBinding,
                          binding.accountHash == accountHash,
                          binding.storeIdentity == storeIdentity else {
                        throw Task126OwnerStoreGateError.bindingMismatch
                    }
                }
                pendingReplacement = replacement
            } else {
                guard let binding = bindingStore.currentBinding,
                      binding.accountHash == accountHash,
                      binding.storeIdentity == storeIdentity else {
                    throw Task126OwnerStoreGateError.bindingMismatch
                }
                pendingReplacement = nil
            }

            return Task126VerifiedOwnerStoreScope(
                ownerUserID: ownerUserID,
                accountHash: accountHash,
                shopID: selectedShop.shopID,
                storeIdentity: storeIdentity,
                deviceInstallID: deviceInstallID,
                deviceIdentityHash: deviceIdentityHash,
                pendingReplacement: pendingReplacement,
                leaseGeneration: leaseGeneration
            )
        }
    }

    /// Re-reads every mutable identity component. A change while an async
    /// remote call is suspended invalidates the captured scope before another
    /// remote mutation or local commit can occur.
    static func revalidateAutomaticScope(
        _ expected: Task126VerifiedOwnerStoreScope,
        defaults: UserDefaults = .standard
    ) throws {
        guard !Task.isCancelled else {
            throw Task126OwnerStoreGateError.cancelled
        }
        let current = try captureAutomaticScope(
            ownerUserID: expected.ownerUserID,
            defaults: defaults,
            allowsPendingReplacement: expected.pendingReplacement != nil
        )
        guard current == expected else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
    }

    /// Invalidates already-captured work synchronously. The orchestrator calls
    /// this before asynchronous auth/shop refresh can update persisted state.
    static func invalidateAutomaticScopeLease() {
        leaseStore.invalidate()
    }

    static func withAutomaticScopeLeaseInvalidated<Result>(
        _ mutation: () throws -> Result
    ) rethrows -> Result {
        try leaseStore.withInvalidatedLease(mutation)
    }

    /// Preferred writer primitive. The context is materialized only after the
    /// mutation lease has been acquired, so its identity map cannot contain a
    /// pre-incremental snapshot that would overwrite newer remote metadata.
    static func withLocalMutationFence<Result>(
        modelContainer: ModelContainer,
        ownerUserID: UUID?,
        defaults: UserDefaults = .standard,
        _ mutation: (ModelContext) throws -> Result
    ) throws -> Result {
        try leaseStore.withCurrentLease { _ in
            switch leaseStore.localMutationContainerStateWithLeaseHeld(modelContainer) {
            case .retired:
                throw Task126OwnerStoreGateError.retiredStoreGeneration
            case .active:
                let bindingStore = AccountBindingStore(defaults: defaults)
                guard !bindingStore.hasPendingReplacementJournal else {
                    throw Task126OwnerStoreGateError.replacementInterrupted
                }
                if let ownerUserID {
                    let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
                    guard defaults.string(forKey: activeAccountKey) == accountHash,
                          let binding = bindingStore.currentBinding,
                          binding.accountHash == accountHash,
                          let selectedShop = SelectedShopStore(defaults: defaults)
                            .selectedShop(accountHash: accountHash),
                          selectedShop.selectable,
                          !blockedShopStatuses.contains(
                            selectedShop.status
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .lowercased()
                          ),
                          selectedShop.localStoreIdentity == binding.storeIdentity else {
                        throw Task126OwnerStoreGateError.bindingMismatch
                    }
                } else {
                    guard defaults.string(forKey: activeAccountKey) == nil,
                          bindingStore.currentBinding == nil else {
                        throw Task126OwnerStoreGateError.bindingMismatch
                    }
                }
            case .unregistered:
                // In-memory/unit-test and SwiftUI preview containers are not an
                // application generation. They still receive a fresh context
                // and the same serialization fence, but have no persisted
                // account/shop state to validate. Every production root
                // container is registered by SyncStoreGenerationController.
                break
            }
            let freshContext = ModelContext(modelContainer)
            freshContext.autosaveEnabled = false
            return try mutation(freshContext)
        }
    }

    /// Registers a generation container without making unrelated test or
    /// preview containers invalid. Registrations are weak and are pruned on
    /// every access, so repeated recovery generations remain bounded.
    static func registerActiveGenerationContainer(_ container: ModelContainer) {
        leaseStore.registerActiveContainer(container)
    }

    /// Must only be called while the Task126 lease is already held. Retiring
    /// the old physical container in the same critical section as publication
    /// makes queued writers fail closed after the atomic generation switch.
    static func replaceActiveGenerationContainerWithLeaseHeld(
        old: ModelContainer,
        new: ModelContainer
    ) {
        leaseStore.replaceActiveContainerWithLeaseHeld(old: old, new: new)
    }

    /// Validates a background/batched writer that owns an explicit container
    /// while its already-validated automatic scope lease is held.
    static func validateLocalMutationContainerWithLeaseHeld(
        _ container: ModelContainer
    ) throws {
        try leaseStore.validateLocalMutationContainerWithLeaseHeld(container)
    }

    /// Resolves an identity captured as a value before the lease inside the
    /// newly-created writer context. Persistent model instances themselves
    /// must never cross into the fenced closure.
    static func requireLocalModel<Model: PersistentModel>(
        _ type: Model.Type,
        id: PersistentIdentifier,
        in context: ModelContext
    ) throws -> Model {
        // `model(for:)` can return a typed fault after another context has
        // physically deleted the row; touching that fault traps instead of
        // throwing. An explicit fetch is existence-safe. The stable ID remains
        // an anti-alias check; domain-specific callers additionally validate
        // remote/logical identity where applicable.
        let descriptor = FetchDescriptor<Model>(
            predicate: #Predicate<Model> { $0.persistentModelID == id }
        )
        guard let model = try context.fetch(descriptor).first else {
            throw Task126OwnerStoreGateError.localModelUnavailable
        }
        return model
    }

    /// Atomically rejects stale automatic work, invalidates its lease and then
    /// performs the terminal scope mutation. This is used when a successful
    /// recovery clears its journal so auth/shop drift cannot win between the
    /// final validation and the durable clear.
    static func withValidatedAutomaticScopeLeaseInvalidated<Result>(
        expectedGeneration: UInt64,
        _ mutation: () throws -> Result
    ) throws -> Result {
        try leaseStore.withValidatedInvalidatedLease(
            expectedGeneration: expectedGeneration,
            mutation: mutation
        )
    }

    static func withAutomaticScope<Result>(
        _ scope: Task126VerifiedOwnerStoreScope,
        operation: () async throws -> Result
    ) async rethrows -> Result {
        try await $currentAutomaticScope.withValue(scope, operation: operation)
    }

    static func requireCurrentAutomaticScope(
        ownerUserID: UUID,
        defaults: UserDefaults = .standard
    ) throws -> Task126VerifiedOwnerStoreScope {
        guard let scope = currentAutomaticScope,
              scope.ownerUserID == ownerUserID else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
        try revalidateAutomaticScope(scope, defaults: defaults)
        return scope
    }

    static func requireCurrentAutomaticScope(
        defaults: UserDefaults = .standard
    ) throws -> Task126VerifiedOwnerStoreScope {
        guard let scope = currentAutomaticScope else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
        try revalidateAutomaticScope(scope, defaults: defaults)
        return scope
    }

    /// Linearizes a synchronous local commit with auth/shop invalidation. Manual
    /// workflows have no automatic TaskLocal scope and therefore keep their
    /// existing behavior.
    static func withCurrentAutomaticScopeLeaseIfPresent<Result>(
        _ operation: () throws -> Result
    ) throws -> Result {
        guard let scope = currentAutomaticScope else {
            return try operation()
        }
        return try leaseStore.withValidatedLease(
            expectedGeneration: scope.leaseGeneration,
            operation: operation
        )
    }

    /// Linearizes a synchronous commit made by work that carries an explicit
    /// captured scope (for example a `Task.detached`, which has no TaskLocal).
    /// Revalidation must happen before taking the non-recursive lease lock.
    static func withValidatedAutomaticScopeLease<Result>(
        _ scope: Task126VerifiedOwnerStoreScope,
        defaults: UserDefaults = .standard,
        operation: () throws -> Result
    ) throws -> Result {
        try revalidateAutomaticScope(scope, defaults: defaults)
        return try leaseStore.withValidatedLease(
            expectedGeneration: scope.leaseGeneration,
            operation: operation
        )
    }

    static func revalidateCurrentAutomaticScopeLeaseIfPresent() throws {
        try withCurrentAutomaticScopeLeaseIfPresent {}
    }

    static func validateRemoteIdentity(
        ownerUserID: UUID,
        shopID: UUID?,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        guard ownerUserID == scope.ownerUserID,
              shopID == scope.shopID else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
    }

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

private nonisolated final class Task126AutomaticScopeLeaseStore: @unchecked Sendable {
    enum LocalMutationContainerState {
        case active
        case retired
        case unregistered
    }

    private final class WeakContainerRegistration {
        weak var container: ModelContainer?
        var isRetired: Bool

        init(container: ModelContainer, isRetired: Bool) {
            self.container = container
            self.isRetired = isRetired
        }
    }

    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var containerRegistrations: [ObjectIdentifier: WeakContainerRegistration] = [:]

    func withCurrentLease<Result>(
        _ operation: (UInt64) throws -> Result
    ) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        return try operation(generation)
    }

    func invalidate() {
        lock.lock()
        generation &+= 1
        lock.unlock()
    }

    func withInvalidatedLease<Result>(
        _ mutation: () throws -> Result
    ) rethrows -> Result {
        lock.lock()
        defer { lock.unlock() }
        generation &+= 1
        return try mutation()
    }

    func withValidatedInvalidatedLease<Result>(
        expectedGeneration: UInt64,
        mutation: () throws -> Result
    ) throws -> Result {
        lock.lock()
        defer { lock.unlock() }
        try Task.checkCancellation()
        guard generation == expectedGeneration else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
        generation &+= 1
        return try mutation()
    }

    func withValidatedLease<Result>(
        expectedGeneration: UInt64,
        operation: () throws -> Result
    ) throws -> Result {
        lock.lock()
        defer { lock.unlock() }
        try Task.checkCancellation()
        guard generation == expectedGeneration else {
            throw Task126OwnerStoreGateError.scopeChanged
        }
        return try operation()
    }

    func registerActiveContainer(_ container: ModelContainer) {
        lock.lock()
        defer { lock.unlock() }
        pruneReleasedContainersWithLeaseHeld()
        containerRegistrations[ObjectIdentifier(container)] = WeakContainerRegistration(
            container: container,
            isRetired: false
        )
    }

    func replaceActiveContainerWithLeaseHeld(old: ModelContainer, new: ModelContainer) {
        pruneReleasedContainersWithLeaseHeld()
        containerRegistrations[ObjectIdentifier(old)] = WeakContainerRegistration(
            container: old,
            isRetired: true
        )
        containerRegistrations[ObjectIdentifier(new)] = WeakContainerRegistration(
            container: new,
            isRetired: false
        )
    }

    func validateLocalMutationContainerWithLeaseHeld(_ container: ModelContainer) throws {
        if localMutationContainerStateWithLeaseHeld(container) == .retired {
            throw Task126OwnerStoreGateError.retiredStoreGeneration
        }
    }

    func localMutationContainerStateWithLeaseHeld(
        _ container: ModelContainer
    ) -> LocalMutationContainerState {
        pruneReleasedContainersWithLeaseHeld()
        guard let registration = containerRegistrations[ObjectIdentifier(container)] else {
            return .unregistered
        }
        return registration.isRetired ? .retired : .active
    }

    private func pruneReleasedContainersWithLeaseHeld() {
        containerRegistrations = containerRegistrations.filter { $0.value.container != nil }
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
