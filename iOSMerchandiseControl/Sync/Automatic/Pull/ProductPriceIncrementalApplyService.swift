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
    var applyMs = 0
}

nonisolated struct ProductPriceIncrementalApplyService {
    private let remote: any SyncAutomaticProductPriceIncrementalReading

    init(remote: any SyncAutomaticProductPriceIncrementalReading) {
        self.remote = remote
    }

    func fetchTargetedRows(
        priceIDs: Set<UUID>,
        ownerUserID: UUID
    ) async throws -> ProductPriceIncrementalFetchResult {
        let started = mcNowMillis()
        let rows = try await remote.fetchProductPricesByIDs(
            ownerUserID: ownerUserID,
            priceIDs: priceIDs
        )
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
        let applicableRows: [RemoteInventoryProductPriceRow]
        if let remoteActiveProductIDs {
            applicableRows = priceRows.filter { remoteActiveProductIDs.contains($0.productID) }
        } else {
            applicableRows = priceRows
        }

        let applyStarted = mcNowMillis()
        let applyResult: ProductPriceApplyResult
        if applicableRows.isEmpty {
            applyResult = ProductPriceApplyResult(inserted: 0, skippedExisting: 0, totalConsidered: 0)
        } else {
            applyResult = try await applyProductPriceRows(
                applicableRows,
                ownerUserID: ownerUserID,
                modelContainer: modelContainer
            )
        }

        let missingPriceIDs = requestedPriceIDs.subtracting(Set(priceRows.map(\.id)))
        let pruned = try await pruneMissingRemotePrices(
            priceIDs: missingPriceIDs,
            ownerUserID: ownerUserID,
            modelContainer: modelContainer
        )

        return ProductPriceIncrementalApplyServiceResult(
            inserted: applyResult.inserted,
            remoteIdentityLinked: applyResult.remoteIdentityLinked,
            skippedExisting: applyResult.skippedExisting,
            missingRemotePruned: pruned,
            applyMs: mcNowMillis() - applyStarted
        )
    }

    private func applyProductPriceRows(
        _ priceRows: [RemoteInventoryProductPriceRow],
        ownerUserID: UUID,
        modelContainer: ModelContainer
    ) async throws -> ProductPriceApplyResult {
        try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            let protected = try pendingRemoteIDs(context: context, ownerUserID: ownerUserID)
            let productIDs = Set(priceRows.map(\.productID))
            var productsByRemoteID: [UUID: Product] = [:]
            for remoteID in productIDs {
                if let product = try fetchProduct(remoteID: remoteID, context: context),
                   product.remoteDeletedAt == nil {
                    productsByRemoteID[remoteID] = product
                }
            }

            var currentPricesByKey: [TargetedProductPriceLogicalKey: [TargetedProductPriceCurrentInfo]] = [:]
            for (remoteID, product) in productsByRemoteID {
                for price in product.priceHistory {
                    guard let canonicalPrice = PriceCanonicalizer.canonicalAmount(from: price.price) else { continue }
                    let key = TargetedProductPriceLogicalKey(
                        productID: product.remoteID ?? remoteID,
                        type: price.type.rawValue,
                        effectiveAt: ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.effectiveAt)
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
            for row in priceRows where !protected.prices.contains(row.id) {
                guard row.ownerUserID == ownerUserID else {
                    throw ProductPriceApplyError.invalidRemoteRow(reason: "owner_mismatch")
                }
                guard seenRemoteIDs.insert(row.id).inserted else {
                    throw ProductPriceApplyError.policyBlocked([.conflicts])
                }
                guard let product = productsByRemoteID[row.productID] else {
                    skippedExisting += 1
                    continue
                }
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
            if inserted > 0 || remoteIdentityLinked > 0 {
                try context.save()
            }
            return ProductPriceApplyResult(
                inserted: inserted,
                remoteIdentityLinked: remoteIdentityLinked,
                skippedExisting: skippedExisting,
                totalConsidered: priceRows.count
            )
        }.value
    }

    private func pruneMissingRemotePrices(
        priceIDs: Set<UUID>,
        ownerUserID: UUID,
        modelContainer: ModelContainer
    ) async throws -> Int {
        guard !priceIDs.isEmpty else { return 0 }
        return try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            let protected = try pendingRemoteIDs(context: context, ownerUserID: ownerUserID)
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
        }.value
    }
}
