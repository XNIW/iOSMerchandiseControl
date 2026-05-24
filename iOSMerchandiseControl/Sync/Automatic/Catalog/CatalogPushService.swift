import Foundation
import SwiftData

final class CatalogPushService: SyncCatalogPushProviding {
    private let modelContainer: ModelContainer
    private let remote: (any SyncAutomaticCatalogRemoteWriting)?

    init(
        modelContainer: ModelContainer,
        remote: (any SyncAutomaticCatalogRemoteWriting)? = nil
    ) {
        self.modelContainer = modelContainer
        self.remote = remote
    }

    func pushPendingCatalog(ownerUserID: UUID) async throws -> SyncCatalogPushResult {
        let modelContainer = self.modelContainer
        let remote = self.remote
        return try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            let snapshot = try LocalPendingChangeSnapshotProvider(context: context)
                .loadSnapshot(ownerUserID: ownerUserID)
            var blockers: [String] = []
            if snapshot.blockedCount > 0 { blockers.append("blockedLocalChanges") }
            if snapshot.staleBaselineCount > 0 { blockers.append("staleBaselineLocalChanges") }
            if snapshot.sentCount > 0 { blockers.append("sentChangesWaitingForRetry") }
            if snapshot.isCapped { blockers.append("cappedPendingStore") }
            if remote == nil, snapshot.pendingCatalogChangeCount > 0 { blockers.append("missingRemote") }
            let plan = SyncCatalogPushPlan(
                ownerUserID: ownerUserID,
                pendingChangeCount: snapshot.pendingCatalogChangeCount,
                idempotencyKey: "catalog:\(ownerUserID.uuidString.lowercased()):\(snapshot.pendingCatalogChangeCount)",
                blockers: SyncStringCollectionHelpers.uniquedSorted(blockers)
            )
            var result = SyncCatalogPushResult()
            result.plan = plan
            guard plan.hasWork,
                  let remote else {
                return result
            }
            let changes = try Self.pendingCatalogChanges(context: context, ownerUserID: ownerUserID)
            try Task.checkCancellation()
            let push = try await Self.push(
                changes: changes,
                ownerUserID: ownerUserID,
                context: context,
                remote: remote,
                plan: plan
            )
            result = push.result
            try Self.enqueueCatalogSyncEvent(
                context: context,
                ownerUserID: ownerUserID,
                outcome: push
            )
            try context.save()
            _ = try? SupabaseCatalogBaselineWriter().commitLatestBaseline(
                context: context,
                ownerUserUUID: ownerUserID
            )
            return result
        }.value
    }

    nonisolated private static func pendingCatalogChanges(
        context: ModelContext,
        ownerUserID: UUID
    ) throws -> [LocalPendingChange] {
        let owner = ownerUserID.uuidString.lowercased()
        let pending = LocalPendingChangeStatus.pending.rawValue
        let descriptor = FetchDescriptor<LocalPendingChange>(
            predicate: #Predicate<LocalPendingChange> { change in
                change.ownerUserID == owner && change.statusRaw == pending
            },
            sortBy: [
                SortDescriptor(\.updatedAt, order: .forward),
                SortDescriptor(\.changeID, order: .forward)
            ]
        )
        return try context.fetch(descriptor).filter(\.entityKind.isCatalogKind)
    }

    nonisolated private struct CatalogPushOutcome: Sendable {
        var result: SyncCatalogPushResult
        var supplierIDs: [UUID] = []
        var categoryIDs: [UUID] = []
        var productIDs: [UUID] = []
    }

    nonisolated private static func push(
        changes: [LocalPendingChange],
        ownerUserID: UUID,
        context: ModelContext,
        remote: any SyncAutomaticCatalogRemoteWriting,
        plan: SyncCatalogPushPlan
    ) async throws -> CatalogPushOutcome {
        var outcome = CatalogPushOutcome(result: SyncCatalogPushResult(plan: plan))
        var acknowledgedChangeIDs: [String] = []

        for change in changes where change.entityKind == .supplier {
            guard change.operation != .delete,
                  let supplier = try findSupplier(for: change, context: context) else { continue }
            if let remoteID = supplier.remoteID {
                let row = try await remote.updateSupplier(
                    id: remoteID,
                    payload: SyncAutomaticSupplierUpdatePayload(name: supplier.name)
                )
                apply(row, to: supplier)
                outcome.result.supplierUpdates += 1
                outcome.supplierIDs.append(row.id)
            } else {
                let rows = try await remote.createSuppliers([
                    SyncAutomaticSupplierCreatePayload(ownerUserID: ownerUserID, name: supplier.name)
                ])
                guard let row = rows.first else { continue }
                apply(row, to: supplier)
                outcome.result.supplierCreates += 1
                outcome.supplierIDs.append(row.id)
                acknowledgedChangeIDs.append(change.changeID)
                continue
            }
            acknowledgedChangeIDs.append(change.changeID)
        }

        for change in changes where change.entityKind == .productCategory {
            guard change.operation != .delete,
                  let category = try findCategory(for: change, context: context) else { continue }
            if let remoteID = category.remoteID {
                let row = try await remote.updateCategory(
                    id: remoteID,
                    payload: SyncAutomaticCategoryUpdatePayload(name: category.name)
                )
                apply(row, to: category)
                outcome.result.categoryUpdates += 1
                outcome.categoryIDs.append(row.id)
            } else {
                let rows = try await remote.createCategories([
                    SyncAutomaticCategoryCreatePayload(ownerUserID: ownerUserID, name: category.name)
                ])
                guard let row = rows.first else { continue }
                apply(row, to: category)
                outcome.result.categoryCreates += 1
                outcome.categoryIDs.append(row.id)
                acknowledgedChangeIDs.append(change.changeID)
                continue
            }
            acknowledgedChangeIDs.append(change.changeID)
        }

        for change in changes where change.entityKind == .product {
            guard let product = try findProduct(for: change, context: context) else { continue }
            if change.operation == .delete {
                guard let remoteID = product.remoteID ?? change.entityRemoteID ?? remoteIDFromLogicalKey(change.logicalKey) else { continue }
                let row = try await remote.updateProduct(
                    id: remoteID,
                    payload: SyncAutomaticProductUpdatePayload(
                        barcode: nil,
                        itemNumber: nil,
                        productName: nil,
                        secondProductName: nil,
                        purchasePrice: nil,
                        retailPrice: nil,
                        supplierID: nil,
                        categoryID: nil,
                        stockQuantity: nil,
                        deletedAt: Self.timestamp(Date())
                    )
                )
                apply(row, to: product)
                outcome.result.productUpdates += 1
                outcome.productIDs.append(row.id)
            } else if let remoteID = product.remoteID {
                let row = try await remote.updateProduct(
                    id: remoteID,
                    payload: makeProductUpdatePayload(product)
                )
                apply(row, to: product)
                outcome.result.productUpdates += 1
                outcome.productIDs.append(row.id)
            } else {
                let rows = try await remote.createProducts([
                    makeProductCreatePayload(product, ownerUserID: ownerUserID)
                ])
                guard let row = rows.first else { continue }
                apply(row, to: product)
                outcome.result.productCreates += 1
                outcome.productIDs.append(row.id)
            }
            acknowledgedChangeIDs.append(change.changeID)
        }

        acknowledge(changeIDs: acknowledgedChangeIDs, changes: changes)
        return outcome
    }

    nonisolated private static func enqueueCatalogSyncEvent(
        context: ModelContext,
        ownerUserID: UUID,
        outcome: CatalogPushOutcome
    ) throws {
        guard outcome.result.totalChanged > 0 else { return }
        let entityIDs = AutomaticSyncEventOutboxWriter.entityIDs([
            "supplier_ids": outcome.supplierIDs,
            "category_ids": outcome.categoryIDs,
            "product_ids": outcome.productIDs
        ])
        try AutomaticSyncEventOutboxWriter.enqueue(
            context: context,
            ownerUserID: ownerUserID,
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: outcome.result.totalChanged,
            entityIDs: entityIDs,
            metadata: .object([
                "source": .string("ios_catalog_automatic_push"),
                "supplier_count": .number(Double(outcome.result.supplierCreates + outcome.result.supplierUpdates)),
                "category_count": .number(Double(outcome.result.categoryCreates + outcome.result.categoryUpdates)),
                "product_count": .number(Double(outcome.result.productCreates + outcome.result.productUpdates))
            ]),
            source: "ios_catalog_automatic_push",
            entityIDsShape: "supplier_ids:count=\(outcome.supplierIDs.count);category_ids:count=\(outcome.categoryIDs.count);product_ids:count=\(outcome.productIDs.count)",
            metadataShape: "source=ios_catalog_automatic_push;suppliers=\(outcome.result.supplierCreates + outcome.result.supplierUpdates);categories=\(outcome.result.categoryCreates + outcome.result.categoryUpdates);products=\(outcome.result.productCreates + outcome.result.productUpdates)",
            clientEventFingerprint: outcome.result.plan?.idempotencyKey ?? UUID().uuidString
        )
    }

    nonisolated private static func findSupplier(for change: LocalPendingChange, context: ModelContext) throws -> Supplier? {
        if let remoteID = change.entityRemoteID ?? remoteIDFromLogicalKey(change.logicalKey) {
            return try fetchSupplier(remoteID: remoteID, context: context)
        }
        return try context.fetch(FetchDescriptor<Supplier>()).first {
            pendingKeys(for: $0).contains(change.logicalKey)
        }
    }

    nonisolated private static func findCategory(for change: LocalPendingChange, context: ModelContext) throws -> ProductCategory? {
        if let remoteID = change.entityRemoteID ?? remoteIDFromLogicalKey(change.logicalKey) {
            return try fetchCategory(remoteID: remoteID, context: context)
        }
        return try context.fetch(FetchDescriptor<ProductCategory>()).first {
            pendingKeys(for: $0).contains(change.logicalKey)
        }
    }

    nonisolated private static func findProduct(for change: LocalPendingChange, context: ModelContext) throws -> Product? {
        if let remoteID = change.entityRemoteID ?? remoteIDFromLogicalKey(change.logicalKey) {
            return try fetchProduct(remoteID: remoteID, context: context)
        }
        return try context.fetch(FetchDescriptor<Product>()).first {
            pendingKeys(for: $0).contains(change.logicalKey)
        }
    }

    nonisolated private static func apply(_ row: RemoteInventorySupplierRow, to supplier: Supplier) {
        supplier.remoteID = row.id
        supplier.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
        supplier.remoteDeletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    }

    nonisolated private static func apply(_ row: RemoteInventoryCategoryRow, to category: ProductCategory) {
        category.remoteID = row.id
        category.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
        category.remoteDeletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    }

    nonisolated private static func apply(_ row: RemoteInventoryProductRow, to product: Product) {
        product.remoteID = row.id
        product.remoteUpdatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
        product.remoteDeletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    }

    nonisolated private static func makeProductCreatePayload(
        _ product: Product,
        ownerUserID: UUID
    ) -> SyncAutomaticProductCreatePayload {
        SyncAutomaticProductCreatePayload(
            ownerUserID: ownerUserID,
            barcode: product.barcode,
            itemNumber: product.itemNumber,
            productName: product.productName,
            secondProductName: product.secondProductName,
            purchasePrice: product.purchasePrice,
            retailPrice: product.retailPrice,
            supplierID: product.supplier?.remoteID,
            categoryID: product.category?.remoteID,
            stockQuantity: product.stockQuantity
        )
    }

    nonisolated private static func makeProductUpdatePayload(_ product: Product) -> SyncAutomaticProductUpdatePayload {
        SyncAutomaticProductUpdatePayload(
            barcode: product.barcode,
            itemNumber: product.itemNumber,
            productName: product.productName,
            secondProductName: product.secondProductName,
            purchasePrice: product.purchasePrice,
            retailPrice: product.retailPrice,
            supplierID: product.supplier?.remoteID,
            categoryID: product.category?.remoteID,
            stockQuantity: product.stockQuantity,
            deletedAt: product.remoteDeletedAt.map(timestamp)
        )
    }

    nonisolated private static func pendingKeys(for supplier: Supplier) -> Set<String> {
        Set([
            LocalPendingChangeLogicalKey.supplier(remoteID: supplier.remoteID, name: supplier.name),
            LocalPendingChangeLogicalKey.supplier(remoteID: nil, name: supplier.name)
        ])
    }

    nonisolated private static func pendingKeys(for category: ProductCategory) -> Set<String> {
        Set([
            LocalPendingChangeLogicalKey.category(remoteID: category.remoteID, name: category.name),
            LocalPendingChangeLogicalKey.category(remoteID: nil, name: category.name)
        ])
    }

    nonisolated private static func pendingKeys(for product: Product) -> Set<String> {
        Set([
            LocalPendingChangeLogicalKey.product(remoteID: product.remoteID, barcode: product.barcode),
            LocalPendingChangeLogicalKey.product(remoteID: nil, barcode: product.barcode)
        ])
    }

    nonisolated private static func acknowledge(changeIDs: [String], changes: [LocalPendingChange]) {
        let ids = Set(changeIDs)
        let timestamp = Date()
        for change in changes where ids.contains(change.changeID) {
            change.status = .acknowledged
            change.updatedAt = timestamp
        }
    }

    nonisolated private static func timestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
