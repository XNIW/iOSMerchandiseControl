import Foundation
import SwiftData

nonisolated struct ProductPriceIncrementalFetchResult {
    var rows: [RemoteInventoryProductPriceRow] = []
    var fetchMs = 0
}

nonisolated struct ProductPriceIncrementalApplyServiceResult {
    var inserted = 0
    var remoteIdentityLinked = 0
    var skippedExisting = 0
    var missingRemotePruned = 0
    var missingRemoteCount = 0
    var applyMs = 0
}

nonisolated func applyTargetedProductPriceMutationRows(
    _ priceRows: [RemoteInventoryProductPriceRow],
    protected: IncrementalApplyProtectedRemoteIDs,
    context: ModelContext
) throws -> ProductPriceApplyResult {
    guard protected.prices.isDisjoint(with: Set(priceRows.map(\.id))) else {
        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
    }
    let productIDs = Set(priceRows.map(\.productID))
    var productsByRemoteID: [UUID: Product] = [:]
    for remoteID in productIDs {
        guard let product = try fetchProduct(remoteID: remoteID, context: context),
              product.remoteDeletedAt == nil else {
            throw SyncEventIncrementalApplyError.dynamicPreflightRequired
        }
        productsByRemoteID[remoteID] = product
    }

    var currentPricesByKey: [TargetedProductPriceLogicalKey: [TargetedProductPriceCurrentInfo]] = [:]
    for (remoteID, product) in productsByRemoteID {
        for price in product.priceHistory {
            guard let canonicalPrice = PriceCanonicalizer.canonicalAmount(from: price.price) else {
                continue
            }
            let key = TargetedProductPriceLogicalKey(
                productID: product.remoteID ?? remoteID,
                type: price.type.rawValue,
                effectiveAt: ProductPriceEffectiveAtCanonicalizer.canonicalString(
                    from: price.effectiveAt
                )
            )
            currentPricesByKey[key, default: []].append(
                TargetedProductPriceCurrentInfo(
                    canonicalPrice: canonicalPrice,
                    remoteID: price.remoteID,
                    productPriceIDToLink: price.remoteID == nil ? price.persistentModelID : nil
                )
            )
        }
    }

    var inserted = 0
    var remoteIdentityLinked = 0
    var skippedExisting = 0
    var seenRemoteIDs = Set<UUID>()
    for row in priceRows {
        guard seenRemoteIDs.insert(row.id).inserted else {
            throw ProductPriceApplyError.policyBlocked([.conflicts])
        }
        let product = productsByRemoteID[row.productID]!
        let outcome = try applyTargetedProductPriceRow(
            row,
            product: product,
            currentPricesByKey: &currentPricesByKey,
            context: context
        )
        inserted += outcome.inserted
        remoteIdentityLinked += outcome.remoteIdentityLinked
        skippedExisting += outcome.skippedExisting
    }
    return ProductPriceApplyResult(
        inserted: inserted,
        remoteIdentityLinked: remoteIdentityLinked,
        skippedExisting: skippedExisting,
        totalConsidered: priceRows.count
    )
}

nonisolated struct ProductPriceIncrementalApplyService {
    private let remote: any SyncAutomaticProductPriceIncrementalReading
    private let scope: Task126VerifiedOwnerStoreScope
    private let defaults: UserDefaults

    init(
        remote: any SyncAutomaticProductPriceIncrementalReading,
        scope: Task126VerifiedOwnerStoreScope,
        defaults: UserDefaults = .standard
    ) {
        self.remote = remote
        self.scope = scope
        self.defaults = defaults
    }

    func fetchTargetedRows(
        priceIDs: Set<UUID>,
        ownerUserID: UUID
    ) async throws -> ProductPriceIncrementalFetchResult {
        let started = mcNowMillis()
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        let rows = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
            try await remote.fetchProductPricesByIDs(
                ownerUserID: ownerUserID,
                priceIDs: priceIDs
            )
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        for row in rows {
            try validateIncrementalReadIdentity(ownerUserID: row.ownerUserID, shopID: row.shopID, scope: scope, remote: remote)
        }
        return ProductPriceIncrementalFetchResult(
            rows: rows,
            fetchMs: mcNowMillis() - started
        )
    }

    func apply(
        priceRows: [RemoteInventoryProductPriceRow],
        requestedPriceIDs: Set<UUID>,
        remoteActiveProductIDs: Set<UUID>?,
        ownerUserID: UUID,
        modelContainer: ModelContainer
    ) async throws -> ProductPriceIncrementalApplyServiceResult {
        let applicableRows = priceRows.filter { requestedPriceIDs.contains($0.id) }
        guard requestedPriceIDs.isSubset(of: Set(applicableRows.map(\.id))),
              let remoteActiveProductIDs,
              applicableRows.allSatisfy({ remoteActiveProductIDs.contains($0.productID) }) else {
            // A targeted price event is all-or-recovery. In particular, a
            // price whose product is tombstoned belongs to the full recovery
            // ledger and must never be silently skipped while the event is
            // marked applied.
            throw SyncEventIncrementalApplyError.dynamicPreflightRequired
        }

        let applyStarted = mcNowMillis()
        let applyResult: ProductPriceApplyResult
        if applicableRows.isEmpty {
            applyResult = ProductPriceApplyResult(inserted: 0, skippedExisting: 0, totalConsidered: 0)
        } else {
            applyResult = try await applyProductPriceRows(
                applicableRows,
                ownerUserID: ownerUserID,
                modelContainer: modelContainer,
                scope: scope,
                defaults: defaults
            )
        }

        return ProductPriceIncrementalApplyServiceResult(
            inserted: applyResult.inserted,
            remoteIdentityLinked: applyResult.remoteIdentityLinked,
            skippedExisting: applyResult.skippedExisting,
            missingRemotePruned: 0,
            missingRemoteCount: 0,
            applyMs: mcNowMillis() - applyStarted
        )
    }

    private func applyProductPriceRows(
        _ priceRows: [RemoteInventoryProductPriceRow],
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        scope: Task126VerifiedOwnerStoreScope,
        defaults: UserDefaults
    ) async throws -> ProductPriceApplyResult {
        try await Task.detached(priority: .utility) {
            try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                scope,
                defaults: defaults
            ) {
                try Task126OwnerStoreGate.validateLocalMutationContainerWithLeaseHeld(
                    modelContainer
                )
                let context = ModelContext(modelContainer)
                context.autosaveEnabled = false
                let protected = try pendingRemoteIDs(
                    context: context,
                    ownerUserID: ownerUserID,
                    storeIdentity: scope.storeIdentity
                )
                let result = try applyTargetedProductPriceMutationRows(
                    priceRows,
                    protected: protected,
                    context: context
                )
                if result.inserted > 0 || result.remoteIdentityLinked > 0 {
                    try context.save()
                }
                return result
            }
        }.value
    }

    private func pruneMissingRemotePrices(
        priceIDs: Set<UUID>,
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        scope: Task126VerifiedOwnerStoreScope,
        defaults: UserDefaults
    ) async throws -> Int {
        guard !priceIDs.isEmpty else { return 0 }
        return try await Task.detached(priority: .utility) {
            try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                scope,
                defaults: defaults
            ) {
                try Task126OwnerStoreGate.validateLocalMutationContainerWithLeaseHeld(
                    modelContainer
                )
                let context = ModelContext(modelContainer)
                context.autosaveEnabled = false
                let protected = try pendingRemoteIDs(
                    context: context,
                    ownerUserID: ownerUserID,
                    storeIdentity: scope.storeIdentity
                )
                var pruned = 0
                for remoteID in priceIDs where !protected.prices.contains(remoteID) {
                    guard let price = try fetchProductPrice(remoteID: remoteID, context: context) else { continue }
                    context.delete(price)
                    pruned += 1
                }
                if pruned > 0 {
                    try context.save()
                }
                return pruned
            }
        }.value
    }
}
