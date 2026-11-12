import CryptoKit
import Foundation
import SwiftData

nonisolated enum LocalPendingAggregatedPushBlocker: String, Sendable, Equatable, Hashable {
    case missingOwner
    case cappedPendingStore
    case blockedLocalChanges
    case staleBaselineLocalChanges
    case sentChangesWaitingForRetry
    case hardCapExceeded
    case localSnapshotExceeded
    case unsupportedDelete
    case unsupportedImportBatch
    case missingLiveModel
    case unsafeCatalogPlan
    case unsafeProductPricePlan
}

nonisolated enum LocalPendingAggregatedPushWarning: String, Sendable, Equatable, Hashable {
    case softBatchLimitApplied
    case terminalChangesIgnored
    case sentChangesOnCooldown
    case retryableSentChangesAvailable
    case productPriceBatchLimitedByAdapter
}

nonisolated enum LocalPendingAggregatedPushCapState: Sendable, Equatable {
    case clear
    case softLimited(selected: Int, available: Int)
    case hardBlocked(available: Int, limit: Int)
    case cappedStore
}

nonisolated struct LocalPendingAggregatedPushRetryInfo: Sendable, Equatable {
    var sentCount: Int
    var retryEligibleCount: Int
    var cooldownCount: Int
    var cooldownSeconds: TimeInterval

    static let empty = LocalPendingAggregatedPushRetryInfo(
        sentCount: 0,
        retryEligibleCount: 0,
        cooldownCount: 0,
        cooldownSeconds: 0
    )
}

nonisolated struct LocalPendingAggregatedPushCounts: Sendable, Equatable {
    var pendingCatalogCandidates: Int = 0
    var pendingProductPriceCandidates: Int = 0
    var selectedCatalogChanges: Int = 0
    var selectedProductPriceChanges: Int = 0
    var blockedCount: Int = 0
    var staleBaselineCount: Int = 0
    var sentCount: Int = 0
    var supersededIgnoredCount: Int = 0
    var acknowledgedIgnoredCount: Int = 0
    var missingLiveModelCount: Int = 0
    var unsupportedCount: Int = 0
    var catalogWriteCount: Int = 0
    var productPriceWriteCount: Int = 0

    var selectedTotal: Int {
        selectedCatalogChanges + selectedProductPriceChanges
    }

    var verifiedWriteCount: Int {
        catalogWriteCount + productPriceWriteCount
    }
}

nonisolated struct LocalPendingAggregatedPushSummary: Sendable, Equatable {
    var title: String
    var message: String
    var sendableCount: Int
    var skippedCount: Int
    var reviewNeededCount: Int
    var retryCount: Int
}

nonisolated struct LocalPendingAggregatedCatalogBatch: Sendable, Equatable {
    var changeIDs: [String]
    var plan: ManualPushPlan
    var dispatchSnapshot: LocalPendingManualDispatchSnapshot? = nil
}

nonisolated struct LocalPendingAggregatedProductPriceBatch: Sendable, Equatable {
    var changeIDs: [String]
    var plan: ProductPricePushDryRunPlan
    var dispatchSnapshot: LocalPendingManualDispatchSnapshot? = nil
}

nonisolated struct LocalPendingAggregatedPushPlan: Sendable, Equatable {
    var ownerUserID: UUID?
    var generatedAt: Date
    var catalogBatch: LocalPendingAggregatedCatalogBatch?
    var productPriceBatch: LocalPendingAggregatedProductPriceBatch?
    var blockers: [LocalPendingAggregatedPushBlocker]
    var warnings: [LocalPendingAggregatedPushWarning]
    var counts: LocalPendingAggregatedPushCounts
    var fingerprint: String
    var idempotencyKey: String
    var capState: LocalPendingAggregatedPushCapState
    var retryInfo: LocalPendingAggregatedPushRetryInfo
    var summary: LocalPendingAggregatedPushSummary

    var isSendable: Bool {
        blockers.isEmpty && (catalogBatch?.plan.isSendable == true || productPriceBatch?.plan.isSafeForAggregatedPendingPush == true)
    }

    var selectedChangeIDs: [String] {
        ((catalogBatch?.changeIDs ?? []) + (productPriceBatch?.changeIDs ?? [])).uniquedSorted()
    }
}

nonisolated enum LocalPendingManualDispatchError: Error {
    case staleBatch
}

/// Value snapshot of the original plan's exact local revisions. A missing cloud
/// scope permits a planning-only preview, never a manual remote dispatch.
nonisolated struct LocalPendingManualDispatchSnapshot: Sendable, Equatable {
    let scope: Task126VerifiedOwnerStoreScope?
    let tokens: [LocalPendingChangeCASToken]

    @MainActor
    static func capture(changes: [LocalPendingChange], ownerUserID: UUID,
                        defaults: UserDefaults) -> Self {
        Self(scope: try? Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: ownerUserID, defaults: defaults),
             tokens: changes.map(LocalPendingChangeCASToken.init).sorted { $0.changeID < $1.changeID })
    }

    @MainActor
    func withFence<Result>(modelContainer: ModelContainer, ownerUserID: UUID, defaults: UserDefaults,
                           _ operation: (ModelContext) throws -> Result) throws -> Result {
        try Task126OwnerStoreGate.withLocalMutationFence(modelContainer: modelContainer,
            ownerUserID: ownerUserID, defaults: defaults, expectedAutomaticScope: scope, operation)
    }

    @MainActor
    func exactRowsWithFenceHeld(context: ModelContext, ownerUserID: UUID, defaults: UserDefaults,
                   requiresScope: Bool = true, requiresOriginalSet: Bool = true) throws -> [LocalPendingChange] {
        guard !tokens.isEmpty, Set(tokens.map(\.changeID)).count == tokens.count else {
            throw LocalPendingManualDispatchError.staleBatch
        }
        if let scope {
            guard scope.ownerUserID == ownerUserID else { throw LocalPendingManualDispatchError.staleBatch }
        } else if requiresScope {
            throw LocalPendingManualDispatchError.staleBatch
        }
        let owner = ownerUserID.uuidString.lowercased()
        let relevantKeys = Array(Set(tokens.map(\.logicalKey)))
        var descriptor = FetchDescriptor<LocalPendingChange>(predicate: #Predicate {
            $0.ownerUserID == owner && relevantKeys.contains($0.logicalKey)
        })
        descriptor.fetchLimit = LocalPendingAggregatedPushPlanner.defaultHardCap + 1
        let rows = try context.fetch(descriptor)
        guard rows.count <= LocalPendingAggregatedPushPlanner.defaultHardCap else {
            throw LocalPendingManualDispatchError.staleBatch
        }
        let ids = Set(tokens.map(\.changeID))
        let exact = rows.filter { ids.contains($0.changeID) }.sorted { $0.changeID < $1.changeID }
        let resolved = try LocalCatalogConflictResolutionStore.resolvedChangeIDs(context: context)
        let successors = Set(try LocalCatalogConflictResolutionStore.receipts(context: context)
            .compactMap { $0.1.decision.successor?.changeID })
        guard exact.count == tokens.count else { throw LocalPendingManualDispatchError.staleBatch }
        for (token, row) in zip(tokens, exact) {
            guard token.matches(row), !resolved.contains(row.changeID), !successors.contains(row.changeID),
                  try LocalPendingBusinessAttemptStore.entry(changeID: row.changeID, context: context) == nil else {
                throw LocalPendingManualDispatchError.staleBatch
            }
            if let scope {
                guard LocalPendingChangeScopeMatcher.matches(row, ownerUserID: ownerUserID,
                    accountHash: scope.accountHash, storeIdentity: scope.storeIdentity) else {
                    throw LocalPendingManualDispatchError.staleBatch
                }
            }
        }
        if requiresOriginalSet {
            let keys = Set(exact.map(\.logicalKey))
            let currentIDs = Set(rows.filter {
                !$0.status.isTerminal && !resolved.contains($0.changeID) && keys.contains($0.logicalKey)
            }.map(\.changeID))
            guard currentIDs == ids else { throw LocalPendingManualDispatchError.staleBatch }
        }
        return exact
    }
}

@MainActor
struct LocalPendingAggregatedPushStateStore {
    private let context: ModelContext
    private let now: () -> Date

    init(context: ModelContext, now: @escaping () -> Date = Date.init) {
        self.context = context
        self.now = now
    }

    /// Admission and transition share the same serialization fence as Save,
    /// conflict resolution, and generation retirement. No await separates them.
    func markSent(snapshot: LocalPendingManualDispatchSnapshot, ownerUserID: UUID,
                  defaults: UserDefaults = .standard) throws -> LocalPendingManualDispatchSnapshot {
        try snapshot.withFence(modelContainer: context.container,
                ownerUserID: ownerUserID, defaults: defaults) { fresh in
            let rows = try snapshot.exactRowsWithFenceHeld(context: fresh, ownerUserID: ownerUserID, defaults: defaults)
            guard try ManualPendingAtomicRequestStore.protectedChangeIDs(context: fresh)
                    .isDisjoint(with: Set(rows.map(\.changeID))),
                  rows.allSatisfy({ $0.status == .pending && (!$0.entityKind.isCatalogKind || $0.lastAttemptAt == nil) }) else {
                throw LocalPendingManualDispatchError.staleBatch
            }
            try Self.validatePriceParents(rows: rows, context: fresh, scope: snapshot.scope)
            let timestamp = now()
            for row in rows {
                row.status = .sent
                row.lastAttemptAt = timestamp
                row.updatedAt = timestamp
            }
            try fresh.save()
            return LocalPendingManualDispatchSnapshot(scope: snapshot.scope,
                tokens: rows.map(LocalPendingChangeCASToken.init))
        }
    }

    func finish(snapshot: LocalPendingManualDispatchSnapshot, ownerUserID: UUID,
                status: LocalPendingChangeStatus, defaults: UserDefaults = .standard,
                verifiedPricePayloads: [ProductPriceManualPushPayload]? = nil,
                atomicBatchID: UUID? = nil,
                verifiedReadOnlyChangeIDs: Set<String> = [],
                verifiedPriceRows: [RemoteInventoryProductPriceRow]? = nil) throws {
        try snapshot.withFence(modelContainer: context.container,
                ownerUserID: ownerUserID, defaults: defaults) { fresh in
            let rows = try snapshot.exactRowsWithFenceHeld(context: fresh, ownerUserID: ownerUserID,
                defaults: defaults, requiresOriginalSet: false)
            guard rows.allSatisfy({ $0.status == .sent }) else { throw LocalPendingManualDispatchError.staleBatch }
            let protected = try ManualPendingAtomicRequestStore.protectedChangeIDs(context: fresh)
            if !protected.isDisjoint(with: Set(snapshot.tokens.map(\.changeID))) {
                // Unknown/partial outcomes retain the exact original sent token.
                guard status == .acknowledged, let atomicBatchID, let scope = snapshot.scope else { return }
                try ManualPendingAtomicRequestStore.removeConfirmedBatch(batchID: atomicBatchID,
                    members: snapshot.tokens, context: fresh, scope: scope,
                    verifiedReadOnlyChangeIDs: verifiedReadOnlyChangeIDs)
            }
            if let verifiedPricePayloads {
                guard status == .acknowledged, rows.allSatisfy({ $0.entityKind == .productPrice }) else {
                    throw LocalPendingManualDispatchError.staleBatch
                }
                try Self.validatePriceParents(rows: rows, context: fresh, scope: snapshot.scope)
                if let atomicBatchID {
                    _ = atomicBatchID
                    guard let verifiedPriceRows, let scope = snapshot.scope,
                          verifiedPriceRows.count == verifiedPricePayloads.count,
                          Set(verifiedPriceRows.map(\.id)) == Set(verifiedPricePayloads.map(\.id)) else {
                        throw LocalPendingManualDispatchError.staleBatch
                    }
                    for remoteRow in verifiedPriceRows {
                        guard remoteRow.ownerUserID == ownerUserID, remoteRow.shopID == scope.shopID else {
                            throw LocalPendingManualDispatchError.staleBatch
                        }
                        try LocalCatalogBodyProofStore.record(remoteRow, context: fresh, scope: scope)
                    }
                }
                _ = try ProductPriceManualPushIdentityReconciler().linkVerifiedPayloads(verifiedPricePayloads, context: fresh, saveChanges: false)
            }
            for row in rows {
                row.status = status
                row.updatedAt = now()
            }
            try fresh.save()
        }
    }

    static func validatePriceParents(rows: [LocalPendingChange], context: ModelContext,
                                             scope: Task126VerifiedOwnerStoreScope?) throws {
        let keys = Set(rows.filter { $0.entityKind == .productPrice }.map(\.logicalKey))
        guard !keys.isEmpty else { return }
        guard let scope else { throw LocalPendingManualDispatchError.staleBatch }
        let blocked = try LocalCatalogConflictResolutionStore.blockedParentProductIDs(context: context, scope: scope)
        var priceDescriptor = FetchDescriptor<ProductPrice>(predicate: #Predicate { $0.remoteID == nil })
        priceDescriptor.fetchLimit = LocalPendingAggregatedPushPlanner.defaultHardCap + 1
        let prices = try context.fetch(priceDescriptor)
        guard prices.count <= LocalPendingAggregatedPushPlanner.defaultHardCap else {
            throw LocalPendingManualDispatchError.staleBatch
        }
        var found = Set<String>()
        for price in prices {
            guard let product = price.product else { continue }
            let priceKeys = Set([product.remoteID, nil].map {
                LocalPendingChangeLogicalKey.productPrice(productRemoteID: $0, productBarcode: product.barcode,
                    type: price.type, effectiveAt: price.effectiveAt)
            }).intersection(keys)
            guard !priceKeys.isEmpty else { continue }
            guard price.remoteID == nil, let remoteID = product.remoteID,
                  product.remoteDeletedAt == nil, !blocked.contains(remoteID) else {
                throw LocalPendingManualDispatchError.staleBatch
            }
            guard found.isDisjoint(with: priceKeys) else { throw LocalPendingManualDispatchError.staleBatch }
            found.formUnion(priceKeys)
        }
        guard found == keys else { throw LocalPendingManualDispatchError.staleBatch }
    }

    func markSent(changeIDs: [String], ownerUserID: UUID, planFingerprint: String) throws {
        try update(changeIDs: changeIDs, ownerUserID: ownerUserID) { change, timestamp in
            guard change.status == .pending else { return }
            change.status = .sent
            change.lastAttemptAt = timestamp
            change.updatedAt = timestamp
        }
    }

    func markAcknowledged(changeIDs: [String], ownerUserID: UUID) throws {
        try update(changeIDs: changeIDs, ownerUserID: ownerUserID) { change, timestamp in
            guard change.status == .sent || change.status == .pending else { return }
            change.status = .acknowledged
            change.updatedAt = timestamp
        }
    }

    func markRetryable(changeIDs: [String], ownerUserID: UUID) throws {
        try update(changeIDs: changeIDs, ownerUserID: ownerUserID) { change, timestamp in
            guard change.status == .sent else { return }
            change.status = .pending
            change.updatedAt = timestamp
        }
    }

    func markBlocked(changeIDs: [String], ownerUserID: UUID) throws {
        try update(changeIDs: changeIDs, ownerUserID: ownerUserID) { change, timestamp in
            guard change.status == .sent || change.status == .pending else { return }
            change.status = .blocked
            change.updatedAt = timestamp
        }
    }

    func markStale(changeIDs: [String], ownerUserID: UUID) throws {
        try update(changeIDs: changeIDs, ownerUserID: ownerUserID) { change, timestamp in
            guard change.status == .sent || change.status == .pending else { return }
            change.status = .staleBaseline
            change.updatedAt = timestamp
        }
    }

    private func update(
        changeIDs: [String],
        ownerUserID: UUID,
        apply: (LocalPendingChange, Date) -> Void
    ) throws {
        let ids = Set(changeIDs)
        guard !ids.isEmpty else { return }
        let owner = ownerUserID.uuidString.lowercased()
        let descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.ownerUserID == owner
            },
            sortBy: [SortDescriptor(\.updatedAt, order: .forward)]
        )
        let timestamp = now()
        let resolved = try LocalCatalogConflictResolutionStore.resolvedChangeIDs(context: context)
        let changes = try context.fetch(descriptor).filter { ids.contains($0.changeID) && !resolved.contains($0.changeID) }
        guard try changes.allSatisfy({ try LocalPendingBusinessAttemptStore.entry(changeID: $0.changeID, context: context) == nil }) else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        for change in changes {
            apply(change, timestamp)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

@MainActor
final class LocalPendingAggregatedPushPlanner {
    nonisolated static let defaultSoftBatchLimit = 250
    nonisolated static let defaultHardCap = 1_000
    nonisolated static let defaultSentRetryCooldown: TimeInterval = 30 * 60

    private let defaults: UserDefaults
    private let context: ModelContext
    private let priceRemoteFetcher: (any SupabaseProductPricePushDryRunRemoteFetching)?
    private let now: () -> Date
    private let softBatchLimit: Int
    private let hardCap: Int
    private let sentRetryCooldown: TimeInterval
    private let preflightService: SupabaseManualPushPreflightService
    private let catalogBaselineReader: SupabaseCatalogBaselineReader
    private let priceEngine: SupabaseProductPricePushDryRunEngine
    private let priceFetchOptions: ProductPricePushDryRunFetchOptions
    private let includesCatalog: Bool
    private let includesProductPrice: Bool

    init(
        context: ModelContext,
        priceRemoteFetcher: (any SupabaseProductPricePushDryRunRemoteFetching)? = nil,
        now: @escaping () -> Date = Date.init,
        softBatchLimit: Int = defaultSoftBatchLimit,
        hardCap: Int = defaultHardCap,
        sentRetryCooldown: TimeInterval = defaultSentRetryCooldown,
        preflightService: SupabaseManualPushPreflightService = SupabaseManualPushPreflightService(),
        catalogBaselineReader: SupabaseCatalogBaselineReader = SupabaseCatalogBaselineReader(),
        priceEngine: SupabaseProductPricePushDryRunEngine = SupabaseProductPricePushDryRunEngine(),
        priceFetchOptions: ProductPricePushDryRunFetchOptions = ProductPricePushDryRunFetchOptions(),
        includesCatalog: Bool = true,
        includesProductPrice: Bool = true,
        defaults: UserDefaults = .standard
    ) {
        self.context = context
        self.priceRemoteFetcher = priceRemoteFetcher
        self.now = now
        self.softBatchLimit = max(1, softBatchLimit)
        self.hardCap = max(1, hardCap)
        self.sentRetryCooldown = max(0, sentRetryCooldown)
        self.preflightService = preflightService
        self.catalogBaselineReader = catalogBaselineReader
        self.priceEngine = priceEngine
        self.priceFetchOptions = priceFetchOptions
        self.includesCatalog = includesCatalog
        self.includesProductPrice = includesProductPrice
        self.defaults = defaults
    }

    func makePlan(ownerUserID: UUID?) async throws -> LocalPendingAggregatedPushPlan {
        let generatedAt = now()
        guard let ownerUserID else {
            return blockedPlan(
                ownerUserID: nil,
                generatedAt: generatedAt,
                blockers: [.missingOwner],
                counts: LocalPendingAggregatedPushCounts(),
                warnings: [],
                capState: .clear,
                retryInfo: .empty
            )
        }

        if includesCatalog {
            let storeIdentity = ShopContextSelection
                .selectedShopID(ownerUserID: ownerUserID, defaults: defaults) == nil
                ? LocalStoreIdentity.anonymous
                : ShopContextSelection.localStoreIdentity(
                    ownerUserID: ownerUserID, defaults: defaults
                )
            _ = try CatalogTextPendingRepair.repair(
                context: context,
                ownerUserID: ownerUserID,
                storeIdentity: storeIdentity,
                limit: hardCap
            )
        }

        let snapshot = try LocalPendingChangeSnapshotProvider(context: context)
            .loadSnapshot(ownerUserID: ownerUserID)
        var counts = LocalPendingAggregatedPushCounts()
        counts.blockedCount = snapshot.blockedCount
        counts.staleBaselineCount = snapshot.staleBaselineCount
        counts.sentCount = snapshot.sentCount

        var blockers: Set<LocalPendingAggregatedPushBlocker> = []
        var warnings: Set<LocalPendingAggregatedPushWarning> = []
        if snapshot.isCapped {
            blockers.insert(.cappedPendingStore)
        }
        if snapshot.blockedCount > 0 {
            blockers.insert(.blockedLocalChanges)
        }
        if snapshot.staleBaselineCount > 0 {
            blockers.insert(.staleBaselineLocalChanges)
        }

        let activeChanges = try fetchActiveOwnerChanges(ownerUserID: ownerUserID, limit: hardCap + 1)
        // The manual aggregate adapter has no immutable conditional-attempt
        // contract. It must not turn a resolution successor into an ordinary
        // unconditioned PATCH or rewrite a retained automatic seal.
        let conditionalSuccessors = Set(try LocalCatalogConflictResolutionStore.receipts(context: context)
            .compactMap { $0.1.decision.successor?.changeID })
        if activeChanges.count > hardCap {
            blockers.insert(.hardCapExceeded)
        }
        let terminalCounts = try fetchTerminalOwnerChangeCounts(ownerUserID: ownerUserID, limit: hardCap + 1)

        let retryInfo = retryInfo(from: activeChanges, at: generatedAt)
        if retryInfo.cooldownCount > 0 {
            warnings.insert(.sentChangesOnCooldown)
            blockers.insert(.sentChangesWaitingForRetry)
        }
        if retryInfo.retryEligibleCount > 0 {
            warnings.insert(.retryableSentChangesAvailable)
            blockers.insert(.sentChangesWaitingForRetry)
        }

        let pendingChanges = activeChanges.filter { $0.status == .pending }
        counts.pendingCatalogCandidates = pendingChanges.filter { $0.entityKind.isCatalogKind }.count
        counts.pendingProductPriceCandidates = pendingChanges.filter { $0.entityKind == .productPrice }.count
        counts.supersededIgnoredCount = max(snapshot.supersededRetainedCount, terminalCounts.superseded)
        counts.acknowledgedIgnoredCount = terminalCounts.acknowledged
        if counts.supersededIgnoredCount + counts.acknowledgedIgnoredCount > 0 {
            warnings.insert(.terminalChangesIgnored)
        }

        let catalogPendingChanges = pendingChanges.filter { $0.entityKind.isCatalogKind }
        let productPricePendingChanges = pendingChanges.filter { $0.entityKind == .productPrice }
        let selectedCatalogPending = includesCatalog
            ? Array(catalogPendingChanges.prefix(softBatchLimit))
            : []
        let maxPriceBatch = min(softBatchLimit, ProductPriceManualPushOptions.defaultBatchLimit)
        let selectedProductPricePending = includesProductPrice
            ? Array(productPricePendingChanges.prefix(maxPriceBatch))
            : []
        let selectedPending = selectedCatalogPending + selectedProductPricePending
        let protectedManual = try ManualPendingAtomicRequestStore.protectedChangeIDs(context: context)
        if selectedCatalogPending.contains(where: { protectedManual.contains($0.changeID) }) { blockers.insert(.unsafeCatalogPlan) }
        if selectedProductPricePending.contains(where: { protectedManual.contains($0.changeID) }) { blockers.insert(.unsafeProductPricePlan) }
        if try selectedCatalogPending.contains(where: { change in
            if conditionalSuccessors.contains(change.changeID) || change.lastAttemptAt != nil { return true }
            return try LocalPendingBusinessAttemptStore.entry(changeID: change.changeID, context: context) != nil
        }) {
            blockers.insert(.unsafeCatalogPlan)
        }
        if try selectedProductPricePending.contains(where: {
            try LocalPendingBusinessAttemptStore.entry(changeID: $0.changeID, context: context) != nil
        }) {
            blockers.insert(.unsafeProductPricePlan)
        }
        let blockedPriceParentIDs = Set(activeChanges.filter {
            $0.entityKind == .product
        }.compactMap(\.entityRemoteID))
        let capState: LocalPendingAggregatedPushCapState
        if snapshot.isCapped {
            capState = .cappedStore
        } else if activeChanges.count > hardCap {
            capState = .hardBlocked(available: activeChanges.count, limit: hardCap)
        } else if selectedPending.count < (includesCatalog ? catalogPendingChanges.count : 0)
            + (includesProductPrice ? productPricePendingChanges.count : 0) {
            let available = (includesCatalog ? catalogPendingChanges.count : 0)
                + (includesProductPrice ? productPricePendingChanges.count : 0)
            capState = .softLimited(selected: selectedPending.count, available: available)
            warnings.insert(.softBatchLimitApplied)
        } else {
            capState = .clear
        }

        if !blockers.isEmpty {
            return blockedPlan(
                ownerUserID: ownerUserID,
                generatedAt: generatedAt,
                blockers: Array(blockers).sorted { $0.rawValue < $1.rawValue },
                counts: counts,
                warnings: Array(warnings).sorted { $0.rawValue < $1.rawValue },
                capState: capState,
                retryInfo: retryInfo
            )
        }

        var catalogBatch: LocalPendingAggregatedCatalogBatch?
        var productPriceBatch: LocalPendingAggregatedProductPriceBatch?

        let catalogChanges = selectedCatalogPending
        if includesCatalog, !catalogChanges.isEmpty {
            catalogBatch = try makeCatalogBatch(
                ownerUserID: ownerUserID,
                changes: catalogChanges,
                counts: &counts,
                blockers: &blockers
            )
        }

        let priceChanges = selectedProductPricePending
        if includesProductPrice, counts.pendingProductPriceCandidates > priceChanges.count {
            warnings.insert(.productPriceBatchLimitedByAdapter)
        }
        if includesProductPrice, !priceChanges.isEmpty {
            productPriceBatch = try await makeProductPriceBatch(
                ownerUserID: ownerUserID,
                changes: priceChanges,
                blockedParentIDs: blockedPriceParentIDs,
                generatedAt: generatedAt,
                counts: &counts,
                blockers: &blockers
            )
        }

        let sortedBlockers = Array(blockers).sorted { $0.rawValue < $1.rawValue }
        if !sortedBlockers.isEmpty {
            return LocalPendingAggregatedPushPlan(
                ownerUserID: ownerUserID,
                generatedAt: generatedAt,
                catalogBatch: catalogBatch,
                productPriceBatch: productPriceBatch,
                blockers: sortedBlockers,
                warnings: Array(warnings).sorted { $0.rawValue < $1.rawValue },
                counts: counts,
                fingerprint: fingerprint(
                    ownerUserID: ownerUserID,
                    catalogPlan: catalogBatch?.plan,
                    pricePlan: productPriceBatch?.plan,
                    counts: counts,
                    blockers: sortedBlockers
                ),
                idempotencyKey: "",
                capState: capState,
                retryInfo: retryInfo,
                summary: summary(counts: counts, blockers: sortedBlockers, retryInfo: retryInfo)
            )
            .withDerivedIdempotencyKey()
        }

        let fp = fingerprint(
            ownerUserID: ownerUserID,
            catalogPlan: catalogBatch?.plan,
            pricePlan: productPriceBatch?.plan,
            counts: counts,
            blockers: [],
            changeIDs: selectedPending.map(\.changeID)
        )
        return LocalPendingAggregatedPushPlan(
            ownerUserID: ownerUserID,
            generatedAt: generatedAt,
            catalogBatch: catalogBatch,
            productPriceBatch: productPriceBatch,
            blockers: [],
            warnings: Array(warnings).sorted { $0.rawValue < $1.rawValue },
            counts: counts,
            fingerprint: fp,
            idempotencyKey: "local-pending-aggregated:\(fp)",
            capState: capState,
            retryInfo: retryInfo,
            summary: summary(counts: counts, blockers: [], retryInfo: retryInfo)
        )
    }

    private func fetchActiveOwnerChanges(ownerUserID: UUID, limit: Int) throws -> [LocalPendingChange] {
        let owner = ownerUserID.uuidString.lowercased()
        let superseded = LocalPendingChangeStatus.superseded.rawValue
        let acknowledged = LocalPendingChangeStatus.acknowledged.rawValue
        var descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.ownerUserID == owner
                    && change.statusRaw != superseded
                    && change.statusRaw != acknowledged
            },
            sortBy: [
                SortDescriptor(\.updatedAt, order: .forward),
                SortDescriptor(\.changeID, order: .forward)
            ]
        )
        let resolved = try LocalCatalogConflictResolutionStore.resolvedChangeIDs(context: context)
        descriptor.fetchLimit = limit + resolved.count
        return Array(try context.fetch(descriptor).filter { !resolved.contains($0.changeID) }.prefix(limit))
    }

    private func fetchTerminalOwnerChangeCounts(
        ownerUserID: UUID,
        limit: Int
    ) throws -> (superseded: Int, acknowledged: Int) {
        let owner = ownerUserID.uuidString.lowercased()
        let superseded = LocalPendingChangeStatus.superseded.rawValue
        let acknowledged = LocalPendingChangeStatus.acknowledged.rawValue
        var descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.ownerUserID == owner
                    && (change.statusRaw == superseded || change.statusRaw == acknowledged)
            },
            sortBy: [
                SortDescriptor(\.updatedAt, order: .forward),
                SortDescriptor(\.changeID, order: .forward)
            ]
        )
        descriptor.fetchLimit = limit
        let changes = try context.fetch(descriptor)
        return (
            superseded: changes.filter { $0.status == .superseded }.count,
            acknowledged: changes.filter { $0.status == .acknowledged }.count
        )
    }

    private func retryInfo(from changes: [LocalPendingChange], at date: Date) -> LocalPendingAggregatedPushRetryInfo {
        let sent = changes.filter { $0.status == .sent }
        var eligible = 0
        var cooldown = 0
        for change in sent {
            guard let lastAttemptAt = change.lastAttemptAt else {
                eligible += 1
                continue
            }
            if date.timeIntervalSince(lastAttemptAt) >= sentRetryCooldown {
                eligible += 1
            } else {
                cooldown += 1
            }
        }
        return LocalPendingAggregatedPushRetryInfo(
            sentCount: sent.count,
            retryEligibleCount: eligible,
            cooldownCount: cooldown,
            cooldownSeconds: sentRetryCooldown
        )
    }

    private func freshPlanner(context: ModelContext) -> LocalPendingAggregatedPushPlanner {
        LocalPendingAggregatedPushPlanner(context: context, priceRemoteFetcher: priceRemoteFetcher,
            now: now, softBatchLimit: softBatchLimit, hardCap: hardCap,
            sentRetryCooldown: sentRetryCooldown, preflightService: preflightService,
            catalogBaselineReader: catalogBaselineReader, priceEngine: priceEngine,
            priceFetchOptions: priceFetchOptions, includesCatalog: includesCatalog,
            includesProductPrice: includesProductPrice, defaults: defaults)
    }

    private func makeCatalogBatch(
        ownerUserID: UUID, changes: [LocalPendingChange],
        counts: inout LocalPendingAggregatedPushCounts,
        blockers: inout Set<LocalPendingAggregatedPushBlocker>
    ) throws -> LocalPendingAggregatedCatalogBatch? {
        let original = LocalPendingManualDispatchSnapshot.capture(changes: changes,
            ownerUserID: ownerUserID, defaults: defaults)
        return try original.withFence(modelContainer: context.container,
                ownerUserID: ownerUserID, defaults: defaults) { fresh in
            let rows = try original.exactRowsWithFenceHeld(context: fresh, ownerUserID: ownerUserID,
                defaults: defaults, requiresScope: false)
            var batch = try freshPlanner(context: fresh).makeCatalogBatchWithFenceHeld(
                ownerUserID: ownerUserID, changes: rows, counts: &counts, blockers: &blockers)
            batch?.dispatchSnapshot = LocalPendingManualDispatchSnapshot(scope: original.scope,
                tokens: rows.map(LocalPendingChangeCASToken.init))
            return batch
        }
    }

    private func makeCatalogBatchWithFenceHeld(
        ownerUserID: UUID,
        changes: [LocalPendingChange],
        counts: inout LocalPendingAggregatedPushCounts,
        blockers: inout Set<LocalPendingAggregatedPushBlocker>
    ) throws -> LocalPendingAggregatedCatalogBatch? {
        var supplierKeys = Set<String>()
        var categoryKeys = Set<String>()
        var productKeys = Set<String>()
        var productTombstones: [PushCandidate] = []
        var changeIDs: [String] = []

        for change in changes {
            switch change.entityKind {
            case .supplier:
                guard change.operation != .delete else {
                    blockers.insert(.unsupportedDelete)
                    counts.unsupportedCount += 1
                    continue
                }
                supplierKeys.insert(change.logicalKey)
                changeIDs.append(change.changeID)
            case .productCategory:
                guard change.operation != .delete else {
                    blockers.insert(.unsupportedDelete)
                    counts.unsupportedCount += 1
                    continue
                }
                categoryKeys.insert(change.logicalKey)
                changeIDs.append(change.changeID)
            case .product:
                guard change.operation != .delete else {
                    if let remoteID = productTombstoneRemoteID(for: change) {
                        productTombstones.append(PushCandidate(
                            entityKind: .product,
                            localID: change.logicalKey,
                            remoteID: remoteID,
                            action: .dryRunTombstoneCandidate,
                            detail: "Product tombstone"
                        ))
                        changeIDs.append(change.changeID)
                    } else {
                        blockers.insert(.unsupportedDelete)
                        counts.unsupportedCount += 1
                    }
                    continue
                }
                productKeys.insert(change.logicalKey)
                changeIDs.append(change.changeID)
            case .importBatch:
                blockers.insert(.unsupportedImportBatch)
                counts.unsupportedCount += 1
            case .productPrice:
                continue
            case .historySession:
                continue
            }
        }

        let suppliers = try fetchSuppliers(matching: supplierKeys, changes: changes, limit: hardCap + 1)
        let categories = try fetchCategories(matching: categoryKeys, changes: changes, limit: hardCap + 1)
        let products = try fetchProducts(matching: productKeys, changes: changes, limit: hardCap + 1)
        if suppliers.exceeded || categories.exceeded || products.exceeded {
            blockers.insert(.localSnapshotExceeded)
        }

        let selectedSuppliers = suppliers.values.filter {
            !supplierKeys.isDisjoint(with: pendingKeys(for: $0))
        }
        let selectedCategories = categories.values.filter {
            !categoryKeys.isDisjoint(with: pendingKeys(for: $0))
        }
        let selectedProducts = products.values.filter {
            !productKeys.isDisjoint(with: pendingKeys(for: $0))
        }

        let resolvedSupplierKeys = Set(selectedSuppliers.flatMap { pendingKeys(for: $0) }).intersection(supplierKeys)
        let resolvedCategoryKeys = Set(selectedCategories.flatMap { pendingKeys(for: $0) }).intersection(categoryKeys)
        let resolvedProductKeys = Set(selectedProducts.flatMap { pendingKeys(for: $0) }).intersection(productKeys)
        let missingCount = supplierKeys.subtracting(resolvedSupplierKeys).count
            + categoryKeys.subtracting(resolvedCategoryKeys).count
            + productKeys.subtracting(resolvedProductKeys).count
        if missingCount > 0 {
            counts.missingLiveModelCount += missingCount
            blockers.insert(.missingLiveModel)
        }

        counts.selectedCatalogChanges = changeIDs.count
        guard !changeIDs.isEmpty else { return nil }

        let baseline = try readCatalogBaseline(ownerUserID: ownerUserID)
        let preflightPlan = preflightService.makePlan(input: ManualPushPreflightInput(
            baselineRunID: baseline.runID,
            pullState: ManualPushPullState(isComplete: true, hasSourceErrors: false),
            accountState: baseline.accountState,
            baseline: baseline.baseline,
            suppliers: selectedSuppliers.map(makeSupplierState),
            categories: selectedCategories.map(makeCategoryState),
            products: selectedProducts.map(makeProductState)
        ))
        let plan = productTombstones.isEmpty
            ? preflightPlan
            : ManualPushPlan(
                generatedAt: preflightPlan.generatedAt,
                baselineRunID: preflightPlan.baselineRunID,
                ownerUserID: preflightPlan.ownerUserID,
                fingerprintSchemaVersion: preflightPlan.fingerprintSchemaVersion,
                scope: preflightPlan.scope,
                scopeSummary: preflightPlan.scopeSummary,
                candidates: preflightPlan.candidates + productTombstones.sorted { $0.id < $1.id },
                blockedReasons: preflightPlan.blockedReasons,
                warnings: preflightPlan.warnings,
                futureEventChangedCount: preflightPlan.futureEventChangedCount
            )

        counts.catalogWriteCount = plan.writeCandidates.count
        if plan.hasBlockers {
            blockers.insert(.unsafeCatalogPlan)
        }
        return LocalPendingAggregatedCatalogBatch(
            changeIDs: changeIDs.uniquedSorted(),
            plan: plan
        )
    }

    private func productTombstoneRemoteID(for change: LocalPendingChange) -> UUID? {
        if let remoteID = change.entityRemoteID {
            return remoteID
        }
        let prefix = "\(LocalPendingChangeEntityKind.product.rawValue):remote:"
        guard change.logicalKey.hasPrefix(prefix) else {
            return nil
        }
        return UUID(uuidString: String(change.logicalKey.dropFirst(prefix.count)))
    }

    private func makeProductPriceBatch(
        ownerUserID: UUID,
        changes: [LocalPendingChange],
        blockedParentIDs: Set<UUID>,
        generatedAt: Date,
        counts: inout LocalPendingAggregatedPushCounts,
        blockers: inout Set<LocalPendingAggregatedPushBlocker>
    ) async throws -> LocalPendingAggregatedProductPriceBatch? {
        let original = LocalPendingManualDispatchSnapshot.capture(changes: changes,
            ownerUserID: ownerUserID, defaults: defaults)
        let prepared = try original.withFence(modelContainer: context.container,
                ownerUserID: ownerUserID, defaults: defaults) { fresh -> (ProductPricePushDryRunInput, LocalPendingManualDispatchSnapshot)? in
            let rows = try original.exactRowsWithFenceHeld(context: fresh, ownerUserID: ownerUserID,
                defaults: defaults, requiresScope: false)
            guard let input = try freshPlanner(context: fresh).makeProductPriceInputWithFenceHeld(
                ownerUserID: ownerUserID, changes: rows, blockedParentIDs: blockedParentIDs,
                generatedAt: generatedAt, counts: &counts, blockers: &blockers) else { return nil }
            return (input, LocalPendingManualDispatchSnapshot(scope: original.scope,
                tokens: rows.map(LocalPendingChangeCASToken.init)))
        }
        guard let (input, dispatchSnapshot) = prepared else { return nil }
        let localStage = priceEngine.makeLocalStage(input: input)
        let fetchResult = await fetchRemotePriceRows(
            ownerUserID: ownerUserID,
            productIDs: localStage.productIDsForRemoteDedupe
        )
        let plan = priceEngine.makePlan(
            input: input,
            localStage: localStage,
            remoteRows: fetchResult.rows,
            remoteDedupeStatus: fetchResult.status,
            remoteRowsRead: fetchResult.rows.count,
            remotePagesRead: fetchResult.pagesRead
        )
        counts.productPriceWriteCount = plan.summary.readyCandidates
        if !plan.isSafeForAggregatedPendingPush, plan.summary.localPriceCount > 0 {
            blockers.insert(.unsafeProductPricePlan)
        }
        return LocalPendingAggregatedProductPriceBatch(
            changeIDs: dispatchSnapshot.tokens.map(\.changeID),
            plan: plan, dispatchSnapshot: dispatchSnapshot
        )
    }

    private func makeProductPriceInputWithFenceHeld(
        ownerUserID: UUID, changes: [LocalPendingChange], blockedParentIDs: Set<UUID>, generatedAt: Date,
        counts: inout LocalPendingAggregatedPushCounts, blockers: inout Set<LocalPendingAggregatedPushBlocker>
    ) throws -> ProductPricePushDryRunInput? {
        let changeKeys = Set(changes.map(\.logicalKey))
        let prices = try fetchProductPrices(matching: changeKeys, limit: hardCap + 1)
        if prices.exceeded {
            blockers.insert(.localSnapshotExceeded)
        }
        let selectedPrices = prices.values.filter { price in
            !changeKeys.isDisjoint(with: pendingKeys(for: price))
        }
        guard !selectedPrices.contains(where: { price in
            guard let product = price.product, let remoteID = product.remoteID,
                  product.remoteDeletedAt == nil else { return true }
            return blockedParentIDs.contains(remoteID)
        }) else {
            blockers.insert(.unsafeProductPricePlan)
            return nil
        }
        let selectedKeys = Set(selectedPrices.flatMap { pendingKeys(for: $0) }).intersection(changeKeys)
        let missingCount = changeKeys.subtracting(selectedKeys).count
        if missingCount > 0 {
            counts.missingLiveModelCount += missingCount
            blockers.insert(.missingLiveModel)
        }

        let remoteLinkedCount = selectedPrices.filter { $0.remoteID != nil }.count
        if remoteLinkedCount > 0 {
            counts.unsupportedCount += remoteLinkedCount
            blockers.insert(.unsafeProductPricePlan)
        }

        counts.selectedProductPriceChanges = changes.count
        guard !changes.isEmpty else { return nil }

        return ProductPricePushDryRunInput(
            generatedAt: generatedAt,
            sessionSnapshot: ProductPricePushDryRunSessionSnapshot(
                userID: ownerUserID,
                lastLinkedUserID: ownerUserID
            ),
            baselineState: try readProductPriceBaselineState(ownerUserID: ownerUserID),
            localSnapshot: ProductPricePushDryRunLocalSnapshot(
                products: selectedPrices.compactMap(makePriceProduct),
                prices: selectedPrices.enumerated().compactMap { offset, price in
                    self.makePriceLine(offset: offset, price: price)
                }
            )
        )
    }

    private func readCatalogBaseline(
        ownerUserID: UUID
    ) throws -> (runID: UUID?, baseline: ManualPushBaseline?, accountState: ManualPushAccountState) {
        switch try catalogBaselineReader.readManualPushBaseline(context: context, ownerUserUUID: ownerUserID) {
        case .available(let snapshot):
            return (
                snapshot.runID,
                snapshot.baseline,
                ManualPushAccountState(
                    currentUserID: ownerUserID,
                    lastLinkedUserID: snapshot.ownerUserUUID
                )
            )
        case .missing:
            return (
                nil,
                nil,
                ManualPushAccountState(currentUserID: ownerUserID, lastLinkedUserID: ownerUserID)
            )
        case .accountMismatch:
            return (
                nil,
                nil,
                ManualPushAccountState(currentUserID: ownerUserID, lastLinkedUserID: UUID())
            )
        case .staleSchema:
            return (
                nil,
                ManualPushBaseline(
                    productFingerprintsByRemoteID: [:],
                    invalidationReasons: [.fingerprintVersionChanged]
                ),
                ManualPushAccountState(currentUserID: ownerUserID, lastLinkedUserID: ownerUserID)
            )
        case .incomplete:
            return (
                nil,
                ManualPushBaseline(
                    productFingerprintsByRemoteID: [:],
                    invalidationReasons: [.partialPull]
                ),
                ManualPushAccountState(currentUserID: ownerUserID, lastLinkedUserID: ownerUserID)
            )
        }
    }

    private func readProductPriceBaselineState(ownerUserID: UUID) throws -> ProductPricePushBaselineState {
        switch try catalogBaselineReader.readManualPushBaseline(context: context, ownerUserUUID: ownerUserID) {
        case .available(let snapshot):
            return .available(snapshot.baseline)
        case .missing:
            return .missing
        case .accountMismatch:
            return .accountMismatch
        case .staleSchema:
            return .stale
        case .incomplete:
            return .partial
        }
    }

    private func fetchSuppliers(
        matching keys: Set<String>,
        changes: [LocalPendingChange],
        limit _: Int
    ) throws -> (values: [Supplier], exceeded: Bool) {
        guard !keys.isEmpty else { return ([], false) }

        var values: [Supplier] = []
        var seen = Set<String>()
        let remoteIDs = catalogRemoteIDs(
            in: keys,
            changes: changes,
            kind: .supplier
        )
        for remoteID in remoteIDs {
            var descriptor = FetchDescriptor<Supplier>(
                predicate: #Predicate<Supplier> { supplier in
                    supplier.remoteID == remoteID
                },
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
            descriptor.fetchLimit = 1
            try context.fetch(descriptor).forEach { appendUnique($0, to: &values, seen: &seen) }
        }

        let localKeys = localEntityKeys(in: keys)
        if !localKeys.isEmpty {
            let descriptor = FetchDescriptor<Supplier>(
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
            let localValues = try context.fetch(descriptor).filter {
                !localKeys.isDisjoint(with: pendingKeys(for: $0))
            }
            localValues.forEach { appendUnique($0, to: &values, seen: &seen) }
        }

        return (values.sorted { $0.name < $1.name }, false)
    }

    private func fetchCategories(
        matching keys: Set<String>,
        changes: [LocalPendingChange],
        limit _: Int
    ) throws -> (values: [ProductCategory], exceeded: Bool) {
        guard !keys.isEmpty else { return ([], false) }

        var values: [ProductCategory] = []
        var seen = Set<String>()
        let remoteIDs = catalogRemoteIDs(
            in: keys,
            changes: changes,
            kind: .productCategory
        )
        for remoteID in remoteIDs {
            var descriptor = FetchDescriptor<ProductCategory>(
                predicate: #Predicate<ProductCategory> { category in
                    category.remoteID == remoteID
                },
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
            descriptor.fetchLimit = 1
            try context.fetch(descriptor).forEach { appendUnique($0, to: &values, seen: &seen) }
        }

        let localKeys = localEntityKeys(in: keys)
        if !localKeys.isEmpty {
            let descriptor = FetchDescriptor<ProductCategory>(
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
            let localValues = try context.fetch(descriptor).filter {
                !localKeys.isDisjoint(with: pendingKeys(for: $0))
            }
            localValues.forEach { appendUnique($0, to: &values, seen: &seen) }
        }

        return (values.sorted { $0.name < $1.name }, false)
    }

    private func fetchProducts(
        matching keys: Set<String>,
        changes: [LocalPendingChange],
        limit _: Int
    ) throws -> (values: [Product], exceeded: Bool) {
        guard !keys.isEmpty else { return ([], false) }

        var values: [Product] = []
        var seen = Set<String>()
        let remoteIDs = catalogRemoteIDs(
            in: keys,
            changes: changes,
            kind: .product
        )
        for remoteID in remoteIDs {
            var descriptor = FetchDescriptor<Product>(
                predicate: #Predicate<Product> { product in
                    product.remoteID == remoteID
                },
                sortBy: [SortDescriptor(\.barcode, order: .forward)]
            )
            descriptor.fetchLimit = 1
            try context.fetch(descriptor).forEach { appendUnique($0, to: &values, seen: &seen) }
        }

        let localKeys = localEntityKeys(in: keys)
        if !localKeys.isEmpty {
            let descriptor = FetchDescriptor<Product>(
                sortBy: [SortDescriptor(\.barcode, order: .forward)]
            )
            let localValues = try context.fetch(descriptor).filter {
                !localKeys.isDisjoint(with: pendingKeys(for: $0))
            }
            localValues.forEach { appendUnique($0, to: &values, seen: &seen) }
        }

        return (values.sorted { $0.barcode < $1.barcode }, false)
    }

    private func fetchProductPrices(
        matching keys: Set<String>,
        limit: Int
    ) throws -> (values: [ProductPrice], exceeded: Bool) {
        guard !keys.isEmpty else { return ([], false) }

        var descriptor = FetchDescriptor<ProductPrice>(
            predicate: #Predicate<ProductPrice> { price in
                price.remoteID == nil
            },
            sortBy: [
                SortDescriptor(\.effectiveAt, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ]
        )
        descriptor.fetchLimit = limit
        let values = try context.fetch(descriptor)
        let selected = values
            .prefix(max(0, limit - 1))
            .filter { !keys.isDisjoint(with: pendingKeys(for: $0)) }
        return (Array(selected), values.count >= limit)
    }

    private func catalogRemoteIDs(
        in keys: Set<String>,
        changes: [LocalPendingChange],
        kind: LocalPendingChangeEntityKind
    ) -> [UUID] {
        let fromChanges = changes.compactMap { change -> UUID? in
            guard change.entityKind == kind else { return nil }
            return change.entityRemoteID
        }
        let prefix = "\(kind.rawValue):remote:"
        let fromKeys = keys.compactMap { key -> UUID? in
            guard key.hasPrefix(prefix) else { return nil }
            return UUID(uuidString: String(key.dropFirst(prefix.count)))
        }
        return Array(Set(fromChanges + fromKeys)).sorted { $0.uuidString < $1.uuidString }
    }

    private func localEntityKeys(in keys: Set<String>) -> Set<String> {
        Set(keys.filter { $0.contains(":local:") })
    }

    private func appendUnique(_ supplier: Supplier, to values: inout [Supplier], seen: inout Set<String>) {
        let key = supplier.remoteID?.uuidString.lowercased() ?? "local:\(supplier.name)"
        guard seen.insert("supplier:\(key)").inserted else { return }
        values.append(supplier)
    }

    private func appendUnique(_ category: ProductCategory, to values: inout [ProductCategory], seen: inout Set<String>) {
        let key = category.remoteID?.uuidString.lowercased() ?? "local:\(category.name)"
        guard seen.insert("category:\(key)").inserted else { return }
        values.append(category)
    }

    private func appendUnique(_ product: Product, to values: inout [Product], seen: inout Set<String>) {
        let key = product.remoteID?.uuidString.lowercased() ?? "local:\(product.barcode)"
        guard seen.insert("product:\(key)").inserted else { return }
        values.append(product)
    }

    private func pendingKeys(for supplier: Supplier) -> Set<String> {
        Set([
            LocalPendingChangeLogicalKey.supplier(remoteID: supplier.remoteID, name: supplier.name),
            LocalPendingChangeLogicalKey.supplier(remoteID: nil, name: supplier.name)
        ])
    }

    private func pendingKeys(for category: ProductCategory) -> Set<String> {
        Set([
            LocalPendingChangeLogicalKey.category(remoteID: category.remoteID, name: category.name),
            LocalPendingChangeLogicalKey.category(remoteID: nil, name: category.name)
        ])
    }

    private func pendingKeys(for product: Product) -> Set<String> {
        Set([
            LocalPendingChangeLogicalKey.product(remoteID: product.remoteID, barcode: product.barcode),
            LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: product.barcode)
        ])
    }

    private func pendingKeys(for price: ProductPrice) -> Set<String> {
        guard let product = price.product else { return [] }
        return Set([
            LocalPendingChangeLogicalKey.productPrice(
                productRemoteID: product.remoteID,
                productBarcode: product.barcode,
                type: price.type,
                effectiveAt: price.effectiveAt
            ),
            LocalPendingChangeLogicalKey.productPrice(
                productRemoteID: nil,
                productBarcode: product.barcode,
                type: price.type,
                effectiveAt: price.effectiveAt
            )
        ])
    }

    private func makeSupplierState(_ supplier: Supplier) -> ManualPushLookupState {
        ManualPushLookupState(
            entityKind: .supplier,
            localID: supplier.name,
            remoteID: supplier.remoteID,
            remoteUpdatedAt: supplier.remoteUpdatedAt,
            remoteDeletedAt: supplier.remoteDeletedAt,
            name: supplier.name
        )
    }

    private func makeCategoryState(_ category: ProductCategory) -> ManualPushLookupState {
        ManualPushLookupState(
            entityKind: .productCategory,
            localID: category.name,
            remoteID: category.remoteID,
            remoteUpdatedAt: category.remoteUpdatedAt,
            remoteDeletedAt: category.remoteDeletedAt,
            name: category.name
        )
    }

    private func makeProductState(_ product: Product) -> ManualPushProductState {
        ManualPushProductState(
            localID: product.barcode,
            remoteID: product.remoteID,
            remoteUpdatedAt: product.remoteUpdatedAt,
            remoteDeletedAt: product.remoteDeletedAt,
            barcode: product.barcode,
            itemNumber: product.itemNumber,
            productName: product.productName,
            secondProductName: product.secondProductName,
            purchasePrice: product.purchasePrice,
            retailPrice: product.retailPrice,
            stockQuantity: product.stockQuantity,
            hasSupplierReference: product.supplier != nil,
            supplierLocalID: product.supplier?.name,
            supplierName: product.supplier?.name,
            supplierRemoteID: product.supplier?.remoteID,
            hasCategoryReference: product.category != nil,
            categoryLocalID: product.category?.name,
            categoryName: product.category?.name,
            categoryRemoteID: product.category?.remoteID,
            hasLocalPriceChanges: false
        )
    }

    private func makePriceProduct(_ price: ProductPrice) -> ProductPricePushDryRunLocalProduct? {
        guard let product = price.product else { return nil }
        return ProductPricePushDryRunLocalProduct(
            localID: product.barcode,
            remoteID: product.remoteID,
            barcode: product.barcode,
            productName: product.productName
        )
    }

    private func makePriceLine(
        offset: Int,
        price: ProductPrice
    ) -> ProductPricePushDryRunLocalPrice? {
        guard let product = price.product else { return nil }
        return ProductPricePushDryRunLocalPrice(
            localID: "pending-price-\(offset)-\(product.barcode)-\(price.type.rawValue)",
            remoteID: price.remoteID,
            productLocalID: product.barcode,
            productRemoteID: product.remoteID,
            productBarcode: product.barcode,
            productDisplayName: displayName(for: product),
            type: price.type.rawValue,
            price: price.price,
            effectiveAt: price.effectiveAt,
            createdAt: price.createdAt,
            source: price.source,
            note: price.note
        )
    }

    private func displayName(for product: Product) -> String {
        let raw = SupabasePullPreviewNormalizer.semanticString(product.productName)
            ?? SupabasePullPreviewNormalizer.semanticString(product.secondProductName)
            ?? SupabasePullPreviewNormalizer.semanticString(product.itemNumber)
            ?? SupabasePullPreviewNormalizer.semanticString(product.barcode)
            ?? product.remoteID?.uuidString
            ?? "local product"
        return ProductPricePreviewLocalLookupBuilder.truncated(raw, maxLength: 32)
    }

    private func fetchRemotePriceRows(
        ownerUserID: UUID,
        productIDs: [UUID]
    ) async -> (rows: [RemoteInventoryProductPriceRow], status: ProductPricePushRemoteDedupeStatus, pagesRead: Int) {
        guard let priceRemoteFetcher else {
            return ([], productIDs.isEmpty ? .notNeeded : .unsafePartialRemoteDedupe(.networkOrPermission), 0)
        }
        guard !productIDs.isEmpty else {
            return ([], .notNeeded, 0)
        }

        var rows: [RemoteInventoryProductPriceRow] = []
        var pagesRead = 0
        for batchStart in stride(from: 0, to: productIDs.count, by: priceFetchOptions.batchSize) {
            let batchEnd = min(batchStart + priceFetchOptions.batchSize, productIDs.count)
            let batch = Array(productIDs[batchStart..<batchEnd])
            var offset = 0
            var didCompleteBatch = false
            for _ in 0..<priceFetchOptions.maxPagesPerBatch {
                if rows.count >= priceFetchOptions.maxRemoteRows {
                    return (rows, .unsafePartialRemoteDedupe(.rowBudgetExceeded), pagesRead)
                }
                let currentPageSize = min(priceFetchOptions.pageSize, priceFetchOptions.maxRemoteRows - rows.count)
                do {
                    try Task.checkCancellation()
                    let page = try await priceRemoteFetcher.fetchProductPricesForPushDryRunDedupePage(
                        ownerUserID: ownerUserID,
                        productIDs: batch,
                        from: offset,
                        to: offset + currentPageSize - 1
                    )
                    pagesRead += 1
                    rows.append(contentsOf: page)
                    if page.count < currentPageSize {
                        didCompleteBatch = true
                        break
                    }
                    offset += currentPageSize
                } catch is CancellationError {
                    return (rows, .unsafePartialRemoteDedupe(.cancelled), pagesRead)
                } catch {
                    return (rows, .unsafePartialRemoteDedupe(.networkOrPermission), pagesRead)
                }
            }
            if !didCompleteBatch {
                return (rows, .unsafePartialRemoteDedupe(.pageBudgetExceeded), pagesRead)
            }
        }
        return (rows, .complete, pagesRead)
    }

    private func blockedPlan(
        ownerUserID: UUID?,
        generatedAt: Date,
        blockers: [LocalPendingAggregatedPushBlocker],
        counts: LocalPendingAggregatedPushCounts,
        warnings: [LocalPendingAggregatedPushWarning],
        capState: LocalPendingAggregatedPushCapState,
        retryInfo: LocalPendingAggregatedPushRetryInfo
    ) -> LocalPendingAggregatedPushPlan {
        let fp = fingerprint(
            ownerUserID: ownerUserID,
            catalogPlan: nil,
            pricePlan: nil,
            counts: counts,
            blockers: blockers
        )
        return LocalPendingAggregatedPushPlan(
            ownerUserID: ownerUserID,
            generatedAt: generatedAt,
            catalogBatch: nil,
            productPriceBatch: nil,
            blockers: blockers,
            warnings: warnings,
            counts: counts,
            fingerprint: fp,
            idempotencyKey: "local-pending-aggregated:\(fp)",
            capState: capState,
            retryInfo: retryInfo,
            summary: summary(counts: counts, blockers: blockers, retryInfo: retryInfo)
        )
    }

    private func summary(
        counts: LocalPendingAggregatedPushCounts,
        blockers: [LocalPendingAggregatedPushBlocker],
        retryInfo: LocalPendingAggregatedPushRetryInfo
    ) -> LocalPendingAggregatedPushSummary {
        let sendable = counts.catalogWriteCount + counts.productPriceWriteCount
        let skipped = max(0, counts.pendingCatalogCandidates + counts.pendingProductPriceCandidates - counts.selectedTotal)
            + counts.supersededIgnoredCount
            + counts.acknowledgedIgnoredCount
        let reviewNeeded = counts.blockedCount
            + counts.staleBaselineCount
            + counts.missingLiveModelCount
            + counts.unsupportedCount
            + blockers.count
        let title = blockers.isEmpty
            ? (sendable > 0 ? "Modifiche locali pronte" : "Nessuna modifica locale da inviare")
            : "Da controllare prima dell'invio"
        let message = [
            "pronte=\(sendable)",
            "saltate=\(skipped)",
            "daControllare=\(reviewNeeded)",
            "retry=\(retryInfo.retryEligibleCount)"
        ].joined(separator: ";")
        return LocalPendingAggregatedPushSummary(
            title: title,
            message: message,
            sendableCount: sendable,
            skippedCount: skipped,
            reviewNeededCount: reviewNeeded,
            retryCount: retryInfo.retryEligibleCount
        )
    }

    private func fingerprint(
        ownerUserID: UUID?,
        catalogPlan: ManualPushPlan?,
        pricePlan: ProductPricePushDryRunPlan?,
        counts: LocalPendingAggregatedPushCounts,
        blockers: [LocalPendingAggregatedPushBlocker],
        changeIDs: [String] = []
    ) -> String {
        let priceCandidates = pricePlan?.candidates.map { line in
            [
                line.key?.stableID ?? "",
                line.canonicalPrice?.value ?? "",
                line.effectiveAtCanonical ?? "",
                line.createdAtCanonical ?? "",
                line.source ?? "",
                line.note ?? ""
            ].joined(separator: "|")
        }.sorted().joined(separator: "\n") ?? "nil"
        let canonical = [
            "owner=\(ownerUserID?.uuidString.lowercased() ?? "nil")",
            "catalog=\(catalogPlan?.planFingerprint ?? "nil")",
            "prices=\(priceCandidates)",
            "catalogWrites=\(counts.catalogWriteCount)",
            "priceWrites=\(counts.productPriceWriteCount)",
            "blockers=\(blockers.map(\.rawValue).sorted().joined(separator: ","))",
            "changes=\(changeIDs.uniquedSorted().joined(separator: ","))"
        ].joined(separator: "\n")
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private extension LocalPendingAggregatedPushPlan {
    func withDerivedIdempotencyKey() -> LocalPendingAggregatedPushPlan {
        var copy = self
        copy.idempotencyKey = "local-pending-aggregated:\(fingerprint)"
        return copy
    }
}

extension ProductPricePushDryRunPlan {
    nonisolated var isSafeForAggregatedPendingPush: Bool {
        isRemoteDedupeSafe
            && summary.readyCandidates > 0
            && summary.blockedTotal == 0
            && summary.conflictSameKeyDifferentPrice == 0
            && summary.localConflictSameKeyDifferentPrice == 0
            && summary.excludedInvalidLocal == 0
            && summary.readyCandidates <= ProductPriceManualPushOptions.defaultBatchLimit
    }
}

private extension Array where Element == String {
    nonisolated func uniquedSorted() -> [String] {
        Array(Set(self)).sorted()
    }
}
