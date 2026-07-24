import CryptoKit
import Foundation
import SwiftData

final class ProductPricePushService: SyncProductPriceSyncProviding {
    private let modelContainer: ModelContainer
    private let remote: (any SyncAutomaticProductPriceRemoteWriting)?
    private let defaults: UserDefaults

    init(
        modelContainer: ModelContainer,
        remote: (any SyncAutomaticProductPriceRemoteWriting)? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.modelContainer = modelContainer
        self.remote = remote
        self.defaults = defaults
    }

    func pushPendingProductPrices(ownerUserID: UUID) async throws -> SyncProductPricePushResult {
        let modelContainer = self.modelContainer
        let remote = self.remote
        let defaults = self.defaults
        return try await Task.detached(priority: .utility) {
            let scope = try Task126OwnerStoreGate.captureAutomaticScope(
                ownerUserID: ownerUserID,
                defaults: defaults,
                allowsPendingSameScopeRecovery: true
            )
            let preparation = try Self.withFreshScopedContext(
                modelContainer: modelContainer,
                scope: scope,
                defaults: defaults
            ) { context in
                try Self.preparePendingProductPrices(
                    context: context,
                    ownerUserID: ownerUserID,
                    scope: scope,
                    remoteAvailable: remote != nil
                )
            }
            var result = SyncProductPricePushResult(plan: preparation.plan)
            result.orphanedCount = preparation.orphanedCount
            result.tombstonedCount = preparation.tombstonedCount
            guard preparation.plan.hasWork,
                  let remote else {
                return result
            }
            guard !preparation.upserts.isEmpty else { return result }
            var lowerBound = 0
            while lowerBound < preparation.upserts.count {
                let upperBound = min(
                    lowerBound + Self.maximumPriceIDsPerEvent,
                    preparation.upserts.count
                )
                let chunk = Array(preparation.upserts[lowerBound..<upperBound])
                try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
                let rows = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                    try await remote.insertProductPrices(chunk.map(\.payload))
                }
                try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
                let expectedIDs = chunk.map(\.payload.id)
                guard rows.count == expectedIDs.count,
                      Set(rows.map(\.id)) == Set(expectedIDs),
                      Set(rows.map(\.id)).count == rows.count else {
                    throw ProductPricePushError.responseMismatch
                }
                for row in rows {
                    try Task126OwnerStoreGate.validateRemoteIdentity(
                        ownerUserID: row.ownerUserID,
                        shopID: row.shopID,
                        scope: scope
                    )
                }
                let chunkPreparation = ProductPricePushPreparation(
                    plan: preparation.plan,
                    upserts: chunk,
                    orphanedCount: preparation.orphanedCount,
                    tombstonedCount: preparation.tombstonedCount
                )
                let push = try Self.withFreshScopedContext(
                    modelContainer: modelContainer,
                    scope: scope,
                    defaults: defaults
                ) { context in
                    try Self.applyReadBacks(
                        rows,
                        preparation: chunkPreparation,
                        context: context,
                        ownerUserID: ownerUserID,
                        scope: scope
                    )
                }
                result.insertedCount += push.result.insertedCount
                lowerBound = upperBound
            }
            return result
        }.value
    }

    nonisolated private static let maximumPriceIDsPerEvent = 250

    nonisolated private static func pendingProductPriceTombstoneCount(
        context: ModelContext,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) throws -> Int {
        let owner = ownerUserID.uuidString.lowercased()
        let kind = LocalPendingChangeEntityKind.productPrice.rawValue
        let deleteOperation = LocalPendingChangeOperation.delete.rawValue
        let pending = LocalPendingChangeStatus.pending.rawValue
        let descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.ownerUserID == owner
                    && change.entityKindRaw == kind
                    && change.operationRaw == deleteOperation
                    && change.statusRaw == pending
            }
        )
        return try context.fetch(descriptor).filter {
            !$0.status.isTerminal
                && LocalPendingChangeScopeMatcher.matches(
                    $0,
                    ownerUserID: ownerUserID,
                    accountHash: scope.accountHash,
                    storeIdentity: scope.storeIdentity
                )
        }.count
    }

    nonisolated private static func pendingProductPriceChanges(
        context: ModelContext,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) throws -> [LocalPendingChange] {
        let owner = ownerUserID.uuidString.lowercased()
        let pending = LocalPendingChangeStatus.pending.rawValue
        let kind = LocalPendingChangeEntityKind.productPrice.rawValue
        let descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.ownerUserID == owner
                    && change.statusRaw == pending
                    && change.entityKindRaw == kind
            },
            sortBy: [
                SortDescriptor(\.updatedAt, order: .forward),
                SortDescriptor(\.changeID, order: .forward)
            ]
        )
        return try context.fetch(descriptor).filter {
            LocalPendingChangeScopeMatcher.matches(
                $0,
                ownerUserID: ownerUserID,
                accountHash: scope.accountHash,
                storeIdentity: scope.storeIdentity
            )
        }
    }

    nonisolated private struct ProductPricePushOutcome: Sendable {
        var result: SyncProductPricePushResult
        var priceIDs: [UUID] = []
        var productIDs: [UUID] = []
        var insertedChangeIDs: [String] = []
    }

    nonisolated private enum ProductPricePushError: Error, Sendable, Equatable {
        case responseMismatch
    }

    nonisolated private struct PreparedProductPriceUpsert: Sendable {
        let pending: LocalPendingChangeCASToken
        let priceID: PersistentIdentifier
        let payload: SyncAutomaticProductPricePayload
        let identityFingerprint: String
        let payloadFingerprint: String
    }

    nonisolated private struct ProductPricePushPreparation: Sendable {
        let plan: SyncProductPricePushPlan
        let upserts: [PreparedProductPriceUpsert]
        let orphanedCount: Int
        let tombstonedCount: Int
    }

    nonisolated private static func withFreshScopedContext<Result>(
        modelContainer: ModelContainer,
        scope: Task126VerifiedOwnerStoreScope,
        defaults: UserDefaults,
        _ body: (ModelContext) throws -> Result
    ) throws -> Result {
        try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
            scope,
            defaults: defaults
        ) {
            try Task126OwnerStoreGate.validateLocalMutationContainerWithLeaseHeld(
                modelContainer
            )
            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            return try body(context)
        }
    }

    nonisolated private static func preparePendingProductPrices(
        context: ModelContext,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        remoteAvailable: Bool
    ) throws -> ProductPricePushPreparation {
        let snapshot = try LocalPendingChangeSnapshotProvider(context: context)
            .loadSnapshot(ownerUserID: ownerUserID, storeIdentity: scope.storeIdentity)
        let tombstoneCount = try pendingProductPriceTombstoneCount(
            context: context,
            ownerUserID: ownerUserID,
            scope: scope
        )
        var blockers: [String] = []
        if snapshot.blockedCount > 0 { blockers.append("blockedLocalChanges") }
        if snapshot.staleBaselineCount > 0 { blockers.append("staleBaselineLocalChanges") }
        if snapshot.sentCount > 0 { blockers.append("sentChangesWaitingForRetry") }
        if !remoteAvailable, snapshot.pendingProductPriceChangeCount > 0 {
            blockers.append("missingRemote")
        }
        let plan = SyncProductPricePushPlan(
            ownerUserID: ownerUserID,
            pendingChangeCount: snapshot.pendingProductPriceChangeCount,
            idempotencyKey: "product-price:\(ownerUserID.uuidString.lowercased()):\(scope.shopID.uuidString.lowercased()):\(snapshot.pendingProductPriceChangeCount):\(tombstoneCount)",
            blockers: SyncStringCollectionHelpers.uniquedSorted(blockers)
        )
        let changes = try pendingProductPriceChanges(
            context: context,
            ownerUserID: ownerUserID,
            scope: scope
        )
        var upserts: [PreparedProductPriceUpsert] = []
        var orphaned = snapshot.blockedCount + snapshot.staleBaselineCount
        var changedTerminalState = false

        for change in changes {
            if change.operation == .delete {
                change.status = .superseded
                change.updatedAt = Date()
                changedTerminalState = true
                continue
            }
            guard let price = try findPrice(for: change, context: context) else {
                change.status = .superseded
                change.updatedAt = Date()
                changedTerminalState = true
                continue
            }
            guard let payload = makePayload(
                price: price,
                ownerUserID: ownerUserID,
                shopID: scope.shopID
            ) else {
                orphaned += 1
                continue
            }
            upserts.append(PreparedProductPriceUpsert(
                pending: LocalPendingChangeCASToken(change),
                priceID: price.persistentModelID,
                payload: payload,
                identityFingerprint: productPriceIdentityFingerprint(
                    productID: payload.productID,
                    type: payload.type,
                    effectiveAt: payload.effectiveAt
                ),
                payloadFingerprint: productPricePayloadFingerprint(payload)
            ))
        }
        if changedTerminalState { try context.save() }
        return ProductPricePushPreparation(
            plan: plan,
            upserts: upserts,
            orphanedCount: orphaned,
            tombstonedCount: tombstoneCount
        )
    }

    nonisolated private static func applyReadBacks(
        _ rows: [RemoteInventoryProductPriceRow],
        preparation: ProductPricePushPreparation,
        context: ModelContext,
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope
    ) throws -> ProductPricePushOutcome {
        let rowsByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        var outcome = ProductPricePushOutcome(
            result: SyncProductPricePushResult(plan: preparation.plan)
        )
        outcome.result.tombstonedCount = preparation.tombstonedCount
        outcome.result.orphanedCount = preparation.orphanedCount

        for prepared in preparation.upserts {
            guard let row = rowsByID[prepared.payload.id],
                  readBackMatches(row, payload: prepared.payload) else {
                throw ProductPricePushError.responseMismatch
            }
            outcome.priceIDs.append(row.id)
            outcome.productIDs.append(prepared.payload.productID)
            outcome.insertedChangeIDs.append(prepared.pending.eventFingerprint)

            let changeID = prepared.pending.changeID
            var descriptor = FetchDescriptor<LocalPendingChange>(
                predicate: #Predicate<LocalPendingChange> {
                    $0.changeID == changeID
                }
            )
            descriptor.fetchLimit = 1
            guard let change = try context.fetch(descriptor).first,
                  LocalPendingChangeScopeMatcher.matches(
                    change,
                    ownerUserID: ownerUserID,
                    accountHash: scope.accountHash,
                    storeIdentity: scope.storeIdentity
                  ) else {
                throw Task126OwnerStoreGateError.scopeChanged
            }

            guard let price = try? Task126OwnerStoreGate.requireLocalModel(
                ProductPrice.self,
                id: prepared.priceID,
                in: context
            ), let currentPayload = makePayload(
                price: price,
                ownerUserID: ownerUserID,
                shopID: scope.shopID
            ) else { continue }
            let currentIdentity = productPriceIdentityFingerprint(
                productID: currentPayload.productID,
                type: currentPayload.type,
                effectiveAt: currentPayload.effectiveAt
            )
            guard currentIdentity == prepared.identityFingerprint else { continue }
            if let currentRemoteID = price.remoteID, currentRemoteID != row.id {
                throw Task126OwnerStoreGateError.localRemoteConflictRequiresReview
            }
            // Capture the pending-row CAS decision before linking a deterministic
            // remote identity. A create starts with entityRemoteID == nil, so
            // mutating that field first would make its own immutable token stale.
            let pendingTokenStillMatches = prepared.pending.matches(change)
            price.remoteID = row.id
            change.entityRemoteID = row.id
            if pendingTokenStillMatches,
               productPricePayloadFingerprint(currentPayload) == prepared.payloadFingerprint {
                change.status = .acknowledged
                change.updatedAt = Date()
            }
        }
        outcome.result.insertedCount = rows.count
        try enqueueProductPriceSyncEventWithLeaseHeld(
            context: context,
            ownerUserID: ownerUserID,
            outcome: outcome,
            scope: scope
        )
        try context.save()
        return outcome
    }

    nonisolated private static func enqueueProductPriceSyncEventWithLeaseHeld(
        context: ModelContext,
        ownerUserID: UUID,
        outcome: ProductPricePushOutcome,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        guard outcome.result.insertedCount > 0 else { return }
        try AutomaticSyncEventOutboxWriter.enqueueWithValidatedScopeLeaseHeld(
            context: context,
            ownerUserID: ownerUserID,
            domain: "prices",
            eventType: "prices_changed",
            changedCount: outcome.result.insertedCount,
            entityIDs: try AutomaticSyncEventOutboxWriter.entityIDs([
                "price_ids": outcome.priceIDs,
                "product_ids": outcome.productIDs
            ]),
            metadata: .object([
                "source": .string("ios"),
                "price_count": .number(Double(outcome.result.insertedCount)),
                "product_count": .number(Double(Set(outcome.productIDs).count))
            ]),
            source: "ios_prices_automatic_push",
            entityIDsShape: "price_ids:count=\(outcome.priceIDs.count)",
            metadataShape: "source=ios_prices_automatic_push;prices=\(outcome.result.insertedCount);orphaned=\(outcome.result.orphanedCount);tombstoned=\(outcome.result.tombstonedCount)",
            clientEventFingerprint: productPriceEventFingerprint(outcome),
            scope: scope
        )
    }

    nonisolated private static func readBackMatches(
        _ row: RemoteInventoryProductPriceRow,
        payload: SyncAutomaticProductPricePayload
    ) -> Bool {
        row.id == payload.id
            && row.ownerUserID == payload.ownerUserID
            && row.shopID == payload.shopID
            && row.productID == payload.productID
            && row.type == payload.type
            && row.price.bitPattern == payload.price.bitPattern
            && row.effectiveAt == payload.effectiveAt
            && row.source == payload.source
            && row.note == payload.note
            && row.createdAt == payload.createdAt
            && row.updatedAt.flatMap(SupabaseRemoteDateParser.parse) != nil
    }

    nonisolated private static func findPrice(for change: LocalPendingChange, context: ModelContext) throws -> ProductPrice? {
        if let remoteID = change.entityRemoteID ?? remoteIDFromLogicalKey(change.logicalKey) {
            return try fetchProductPrice(remoteID: remoteID, context: context)
        }
        return try context.fetch(FetchDescriptor<ProductPrice>()).first {
            pendingKeys(for: $0).contains(change.logicalKey)
        }
    }

    nonisolated private static func makePayload(
        price: ProductPrice,
        ownerUserID: UUID,
        shopID: UUID?
    ) -> SyncAutomaticProductPricePayload? {
        guard let productID = price.product?.remoteID,
              let amount = PriceCanonicalizer.canonicalAmount(from: price.price) else {
            return nil
        }
        let type = price.type.rawValue.uppercased()
        let effectiveAt = ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.effectiveAt)
        return SyncAutomaticProductPricePayload(
            id: price.remoteID ?? deterministicPriceID(
                    ownerUserID: ownerUserID,
                    shopID: shopID,
                    productID: productID,
                    type: type,
                    effectiveAt: effectiveAt
                ),
            ownerUserID: ownerUserID,
            shopID: shopID,
            productID: productID,
            type: type,
            price: amount.doubleValue,
            effectiveAt: effectiveAt,
            source: price.source,
            note: price.note,
            createdAt: ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.createdAt)
        )
    }

    nonisolated private static func pendingKeys(for price: ProductPrice) -> Set<String> {
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

    nonisolated private static func deterministicPriceID(
        ownerUserID: UUID,
        shopID: UUID?,
        productID: UUID,
        type: String,
        effectiveAt: String
    ) -> UUID {
        let name = [
            "TASK-118",
            ownerUserID.uuidString.lowercased(),
            shopID?.uuidString.lowercased() ?? "legacy",
            productID.uuidString.lowercased(),
            type,
            effectiveAt
        ].joined(separator: "|")
        let digest = Insecure.SHA1.hash(data: Data(name.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0f) | 0x50
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    nonisolated private static func productPriceEventFingerprint(_ outcome: ProductPricePushOutcome) -> String {
        [
            outcome.result.plan?.idempotencyKey ?? "product-price:unknown",
            "changes:\(outcome.insertedChangeIDs.sorted().joined(separator: ","))",
            "prices:\(outcome.priceIDs.map { $0.uuidString.lowercased() }.sorted().joined(separator: ","))"
        ].joined(separator: "|")
    }

    nonisolated private static func productPriceIdentityFingerprint(
        productID: UUID,
        type: String,
        effectiveAt: String
    ) -> String {
        LocalPendingChangeLogicalKey.privacyHash([
            productID.uuidString.lowercased(),
            type,
            effectiveAt
        ].joined(separator: "|"))
    }

    nonisolated private static func productPricePayloadFingerprint(
        _ payload: SyncAutomaticProductPricePayload
    ) -> String {
        LocalPendingChangeLogicalKey.privacyHash([
            payload.id.uuidString.lowercased(),
            payload.ownerUserID.uuidString.lowercased(),
            payload.shopID?.uuidString.lowercased() ?? "",
            payload.productID.uuidString.lowercased(),
            payload.type,
            String(payload.price.bitPattern),
            payload.effectiveAt,
            payload.source ?? "",
            payload.note ?? "",
            payload.createdAt
        ].joined(separator: "|"))
    }

    nonisolated private static func isStoreCompatible(
        _ change: LocalPendingChange,
        storeIdentity: LocalStoreIdentity?
    ) -> Bool {
        guard let storeIdentity else { return true }
        return Task126OwnerStoreScope.normalizedStoreId(change.storeId) == storeIdentity.storeId
    }

    nonisolated private static func markTerminal(
        changeIDs: [String],
        changes: [LocalPendingChange],
        status: LocalPendingChangeStatus
    ) {
        let ids = Set(changeIDs)
        let timestamp = Date()
        for change in changes where ids.contains(change.changeID) {
            change.status = status
            change.updatedAt = timestamp
        }
    }
}
