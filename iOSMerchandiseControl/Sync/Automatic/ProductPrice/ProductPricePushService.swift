import CryptoKit
import Foundation
import SwiftData

final class ProductPricePushService: SyncProductPriceSyncProviding {
    private let modelContainer: ModelContainer
    private let remote: (any SyncAutomaticProductPriceRemoteWriting)?

    init(
        modelContainer: ModelContainer,
        remote: (any SyncAutomaticProductPriceRemoteWriting)? = nil
    ) {
        self.modelContainer = modelContainer
        self.remote = remote
    }

    func pushPendingProductPrices(ownerUserID: UUID) async throws -> SyncProductPricePushResult {
        let modelContainer = self.modelContainer
        let remote = self.remote
        return try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            let snapshot = try LocalPendingChangeSnapshotProvider(context: context)
                .loadSnapshot(ownerUserID: ownerUserID)
            let tombstoneCount = try Self.pendingProductPriceTombstoneCount(
                context: context,
                ownerUserID: ownerUserID
            )
            var blockers: [String] = []
            if snapshot.blockedCount > 0 { blockers.append("blockedLocalChanges") }
            if snapshot.staleBaselineCount > 0 { blockers.append("staleBaselineLocalChanges") }
            if snapshot.sentCount > 0 { blockers.append("sentChangesWaitingForRetry") }
            if remote == nil, snapshot.pendingProductPriceChangeCount > 0 { blockers.append("missingRemote") }
            let plan = SyncProductPricePushPlan(
                ownerUserID: ownerUserID,
                pendingChangeCount: snapshot.pendingProductPriceChangeCount,
                idempotencyKey: "product-price:\(ownerUserID.uuidString.lowercased()):\(snapshot.pendingProductPriceChangeCount):\(tombstoneCount)",
                blockers: SyncStringCollectionHelpers.uniquedSorted(blockers)
            )
            var result = SyncProductPricePushResult()
            result.plan = plan
            result.orphanedCount = snapshot.blockedCount + snapshot.staleBaselineCount
            result.tombstonedCount = tombstoneCount
            guard plan.hasWork,
                  let remote else {
                return result
            }
            let changes = try Self.pendingProductPriceChanges(context: context, ownerUserID: ownerUserID)
            let push = try await Self.push(
                changes: changes,
                ownerUserID: ownerUserID,
                context: context,
                remote: remote,
                plan: plan
            )
            try Self.enqueueProductPriceSyncEvent(
                context: context,
                ownerUserID: ownerUserID,
                outcome: push
            )
            try context.save()
            result.insertedCount = push.result.insertedCount
            result.orphanedCount = push.result.orphanedCount
            result.tombstonedCount = max(tombstoneCount, push.result.tombstonedCount)
            return result
        }.value
    }

    nonisolated private static func pendingProductPriceTombstoneCount(
        context: ModelContext,
        ownerUserID: UUID
    ) throws -> Int {
        let owner = ownerUserID.uuidString.lowercased()
        let kind = LocalPendingChangeEntityKind.productPrice.rawValue
        let deleteOperation = LocalPendingChangeOperation.delete.rawValue
        let descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.ownerUserID == owner
                    && change.entityKindRaw == kind
                    && change.operationRaw == deleteOperation
            }
        )
        return try context.fetch(descriptor).filter { !$0.status.isTerminal }.count
    }

    nonisolated private static func pendingProductPriceChanges(
        context: ModelContext,
        ownerUserID: UUID
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
        return try context.fetch(descriptor)
    }

    nonisolated private struct ProductPricePushOutcome: Sendable {
        var result: SyncProductPricePushResult
        var priceIDs: [UUID] = []
    }

    nonisolated private static func push(
        changes: [LocalPendingChange],
        ownerUserID: UUID,
        context: ModelContext,
        remote: any SyncAutomaticProductPriceRemoteWriting,
        plan: SyncProductPricePushPlan
    ) async throws -> ProductPricePushOutcome {
        var outcome = ProductPricePushOutcome(result: SyncProductPricePushResult(plan: plan))
        let pairs = try changes.compactMap { change -> (LocalPendingChange, ProductPrice)? in
            guard change.operation != .delete,
                  let price = try findPrice(for: change, context: context),
                  price.remoteID == nil,
                  price.product?.remoteID != nil else {
                return nil
            }
            return (change, price)
        }
        let payloads = pairs.compactMap { _, price in
            makePayload(price: price, ownerUserID: ownerUserID)
        }
        guard !payloads.isEmpty else {
            outcome.result.orphanedCount = max(0, changes.count)
            return outcome
        }
        let rows = try await remote.insertProductPrices(payloads)
        let rowsByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        var acknowledged: [String] = []
        for (change, price) in pairs {
            guard let expectedID = makePayload(price: price, ownerUserID: ownerUserID)?.id,
                  let row = rowsByID[expectedID] else {
                continue
            }
            price.remoteID = row.id
            acknowledged.append(change.changeID)
            outcome.priceIDs.append(row.id)
        }
        acknowledge(changeIDs: acknowledged, changes: changes)
        outcome.result.insertedCount = acknowledged.count
        outcome.result.orphanedCount = max(0, changes.count - acknowledged.count)
        return outcome
    }

    nonisolated private static func enqueueProductPriceSyncEvent(
        context: ModelContext,
        ownerUserID: UUID,
        outcome: ProductPricePushOutcome
    ) throws {
        guard outcome.result.insertedCount > 0 else { return }
        try AutomaticSyncEventOutboxWriter.enqueue(
            context: context,
            ownerUserID: ownerUserID,
            domain: "prices",
            eventType: "prices_changed",
            changedCount: outcome.result.insertedCount,
            entityIDs: AutomaticSyncEventOutboxWriter.entityIDs(["price_ids": outcome.priceIDs]),
            metadata: .object([
                "source": .string("ios_prices_automatic_push"),
                "price_count": .number(Double(outcome.result.insertedCount)),
                "orphaned_count": .number(Double(outcome.result.orphanedCount)),
                "tombstoned_count": .number(Double(outcome.result.tombstonedCount))
            ]),
            source: "ios_prices_automatic_push",
            entityIDsShape: "price_ids:count=\(outcome.priceIDs.count)",
            metadataShape: "source=ios_prices_automatic_push;prices=\(outcome.result.insertedCount);orphaned=\(outcome.result.orphanedCount);tombstoned=\(outcome.result.tombstonedCount)",
            clientEventFingerprint: outcome.result.plan?.idempotencyKey ?? UUID().uuidString
        )
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
        ownerUserID: UUID
    ) -> SyncAutomaticProductPricePayload? {
        guard let productID = price.product?.remoteID,
              let amount = PriceCanonicalizer.canonicalAmount(from: price.price) else {
            return nil
        }
        let type = price.type.rawValue.uppercased()
        let effectiveAt = ProductPriceEffectiveAtCanonicalizer.canonicalString(from: price.effectiveAt)
        return SyncAutomaticProductPricePayload(
            id: deterministicPriceID(
                ownerUserID: ownerUserID,
                productID: productID,
                type: type,
                effectiveAt: effectiveAt
            ),
            ownerUserID: ownerUserID,
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
        productID: UUID,
        type: String,
        effectiveAt: String
    ) -> UUID {
        let name = [
            "TASK-118",
            ownerUserID.uuidString.lowercased(),
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

    nonisolated private static func acknowledge(changeIDs: [String], changes: [LocalPendingChange]) {
        let ids = Set(changeIDs)
        let timestamp = Date()
        for change in changes where ids.contains(change.changeID) {
            change.status = .acknowledged
            change.updatedAt = timestamp
        }
    }
}
