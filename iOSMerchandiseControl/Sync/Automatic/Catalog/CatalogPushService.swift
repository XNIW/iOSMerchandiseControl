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
            let selectedShopID = ShopContextSelection.selectedShopID(ownerUserID: ownerUserID)
            let storeIdentity = ShopContextSelection.localStoreIdentity(ownerUserID: ownerUserID)
            let snapshot = try LocalPendingChangeSnapshotProvider(context: context)
                .loadSnapshot(ownerUserID: ownerUserID, storeIdentity: selectedShopID == nil ? nil : storeIdentity)
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
            let changes = try Self.pendingCatalogChanges(
                context: context,
                ownerUserID: ownerUserID,
                storeIdentity: selectedShopID == nil ? nil : storeIdentity
            )
            try Task.checkCancellation()
            let push = try await Self.push(
                changes: changes,
                ownerUserID: ownerUserID,
                context: context,
                remote: remote,
                plan: plan,
                selectedShopID: selectedShopID
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
        ownerUserID: UUID,
        storeIdentity: LocalStoreIdentity?
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
        return try context.fetch(descriptor).filter {
            $0.entityKind.isCatalogKind && isStoreCompatible($0, storeIdentity: storeIdentity)
        }
    }

    nonisolated private struct CatalogPushOutcome: Sendable {
        var result: SyncCatalogPushResult
        var supplierIDs: [UUID] = []
        var categoryIDs: [UUID] = []
        var productIDs: [UUID] = []
        var supplierTombstoneIDs: [UUID] = []
        var categoryTombstoneIDs: [UUID] = []
        var productTombstoneIDs: [UUID] = []
        var changeIDs: [String] = []
    }

    nonisolated private static func push(
        changes: [LocalPendingChange],
        ownerUserID: UUID,
        context: ModelContext,
        remote: any SyncAutomaticCatalogRemoteWriting,
        plan: SyncCatalogPushPlan,
        selectedShopID: UUID?
    ) async throws -> CatalogPushOutcome {
        var outcome = CatalogPushOutcome(result: SyncCatalogPushResult(plan: plan))
        var acknowledgedChangeIDs: [String] = []

        for change in changes where change.entityKind == .supplier {
            if change.operation == .delete {
                guard let remoteID = change.entityRemoteID ?? remoteIDFromLogicalKey(change.logicalKey) else {
                    if change.logicalKey.hasPrefix("supplier:local:") {
                        acknowledgedChangeIDs.append(change.changeID)
                        outcome.changeIDs.append(change.changeID)
                    }
                    continue
                }
                let row = try await remote.updateSupplier(
                    id: remoteID,
                    payload: SyncAutomaticSupplierUpdatePayload(deletedAt: Self.timestamp(Date()))
                )
                if let supplier = try findSupplier(for: change, context: context) {
                    apply(row, to: supplier)
                }
                outcome.result.supplierUpdates += 1
                outcome.supplierIDs.append(row.id)
                outcome.supplierTombstoneIDs.append(row.id)
                acknowledgedChangeIDs.append(change.changeID)
                outcome.changeIDs.append(change.changeID)
                continue
            }

            guard let supplier = try findSupplier(for: change, context: context) else { continue }
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
                    SyncAutomaticSupplierCreatePayload(ownerUserID: ownerUserID, shopID: selectedShopID, name: supplier.name)
                ])
                guard let row = rows.first else { continue }
                apply(row, to: supplier)
                outcome.result.supplierCreates += 1
                outcome.supplierIDs.append(row.id)
                acknowledgedChangeIDs.append(change.changeID)
                outcome.changeIDs.append(change.changeID)
                continue
            }
            acknowledgedChangeIDs.append(change.changeID)
            outcome.changeIDs.append(change.changeID)
        }

        for change in changes where change.entityKind == .productCategory {
            if change.operation == .delete {
                guard let remoteID = change.entityRemoteID ?? remoteIDFromLogicalKey(change.logicalKey) else {
                    if change.logicalKey.hasPrefix("category:local:") {
                        acknowledgedChangeIDs.append(change.changeID)
                        outcome.changeIDs.append(change.changeID)
                    }
                    continue
                }
                let row = try await remote.updateCategory(
                    id: remoteID,
                    payload: SyncAutomaticCategoryUpdatePayload(deletedAt: Self.timestamp(Date()))
                )
                if let category = try findCategory(for: change, context: context) {
                    apply(row, to: category)
                }
                outcome.result.categoryUpdates += 1
                outcome.categoryIDs.append(row.id)
                outcome.categoryTombstoneIDs.append(row.id)
                acknowledgedChangeIDs.append(change.changeID)
                outcome.changeIDs.append(change.changeID)
                continue
            }

            guard let category = try findCategory(for: change, context: context) else { continue }
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
                    SyncAutomaticCategoryCreatePayload(ownerUserID: ownerUserID, shopID: selectedShopID, name: category.name)
                ])
                guard let row = rows.first else { continue }
                apply(row, to: category)
                outcome.result.categoryCreates += 1
                outcome.categoryIDs.append(row.id)
                acknowledgedChangeIDs.append(change.changeID)
                outcome.changeIDs.append(change.changeID)
                continue
            }
            acknowledgedChangeIDs.append(change.changeID)
            outcome.changeIDs.append(change.changeID)
        }

        for change in changes where change.entityKind == .product {
            if change.operation == .delete {
                guard let remoteID = change.entityRemoteID ?? remoteIDFromLogicalKey(change.logicalKey) else {
                    if change.logicalKey.hasPrefix("product:local:") {
                        acknowledgedChangeIDs.append(change.changeID)
                        outcome.changeIDs.append(change.changeID)
                    }
                    continue
                }
                let row = try await remote.updateProduct(
                    id: remoteID,
                    payload: makeProductTombstonePayload()
                )
                if let product = try findProduct(for: change, context: context) {
                    apply(row, to: product)
                }
                outcome.result.productUpdates += 1
                outcome.productIDs.append(row.id)
                outcome.productTombstoneIDs.append(row.id)
                acknowledgedChangeIDs.append(change.changeID)
                outcome.changeIDs.append(change.changeID)
                continue
            }

            guard let product = try findProduct(for: change, context: context) else { continue }
            if let remoteID = product.remoteID {
                let row = try await remote.updateProduct(
                    id: remoteID,
                    payload: makeProductUpdatePayload(product, changedFields: change.changedFields)
                )
                apply(row, to: product)
                outcome.result.productUpdates += 1
                outcome.productIDs.append(row.id)
            } else {
                let rows = try await remote.createProducts([
                    makeProductCreatePayload(product, ownerUserID: ownerUserID, shopID: selectedShopID)
                ])
                guard let row = rows.first else { continue }
                apply(row, to: product)
                outcome.result.productCreates += 1
                outcome.productIDs.append(row.id)
            }
            acknowledgedChangeIDs.append(change.changeID)
            outcome.changeIDs.append(change.changeID)
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
        let supplierTombstoneIDs = Set(outcome.supplierTombstoneIDs)
        let categoryTombstoneIDs = Set(outcome.categoryTombstoneIDs)
        let tombstoneIDs = Set(outcome.productTombstoneIDs)
        let nonTombstoneSupplierIDs = outcome.supplierIDs.filter { !supplierTombstoneIDs.contains($0) }
        let nonTombstoneCategoryIDs = outcome.categoryIDs.filter { !categoryTombstoneIDs.contains($0) }
        let nonTombstoneProductIDs = outcome.productIDs.filter { !tombstoneIDs.contains($0) }
        let eventType = nonTombstoneSupplierIDs.isEmpty &&
            nonTombstoneCategoryIDs.isEmpty &&
            nonTombstoneProductIDs.isEmpty &&
            (!outcome.supplierTombstoneIDs.isEmpty ||
                !outcome.categoryTombstoneIDs.isEmpty ||
                !outcome.productTombstoneIDs.isEmpty) ? "catalog_tombstone" : "catalog_changed"
        let entityIDs = AutomaticSyncEventOutboxWriter.entityIDs([
            "supplier_ids": outcome.supplierIDs,
            "category_ids": outcome.categoryIDs,
            "product_ids": outcome.productIDs
        ])
        try AutomaticSyncEventOutboxWriter.enqueue(
            context: context,
            ownerUserID: ownerUserID,
            domain: "catalog",
            eventType: eventType,
            changedCount: outcome.result.totalChanged,
            entityIDs: entityIDs,
            metadata: .object([
                "source": .string("ios_catalog_automatic_push"),
                "supplier_count": .number(Double(outcome.result.supplierCreates + outcome.result.supplierUpdates)),
                "category_count": .number(Double(outcome.result.categoryCreates + outcome.result.categoryUpdates)),
                "product_count": .number(Double(outcome.result.productCreates + outcome.result.productUpdates)),
                "supplier_tombstone_count": .number(Double(outcome.supplierTombstoneIDs.count)),
                "category_tombstone_count": .number(Double(outcome.categoryTombstoneIDs.count)),
                "product_tombstone_count": .number(Double(outcome.productTombstoneIDs.count))
            ]),
            source: "ios_catalog_automatic_push",
            entityIDsShape: "supplier_ids:count=\(outcome.supplierIDs.count);category_ids:count=\(outcome.categoryIDs.count);product_ids:count=\(outcome.productIDs.count)",
            metadataShape: "source=ios_catalog_automatic_push;suppliers=\(outcome.result.supplierCreates + outcome.result.supplierUpdates);categories=\(outcome.result.categoryCreates + outcome.result.categoryUpdates);products=\(outcome.result.productCreates + outcome.result.productUpdates);supplierTombstones=\(outcome.supplierTombstoneIDs.count);categoryTombstones=\(outcome.categoryTombstoneIDs.count);productTombstones=\(outcome.productTombstoneIDs.count)",
            clientEventFingerprint: catalogEventFingerprint(
                eventType: eventType,
                outcome: outcome
            )
        )
    }

    nonisolated private static func catalogEventFingerprint(
        eventType: String,
        outcome: CatalogPushOutcome
    ) -> String {
        [
            outcome.result.plan?.idempotencyKey ?? "catalog:unknown",
            "event:\(eventType)",
            "changes:\(outcome.changeIDs.sorted().joined(separator: ","))",
            "suppliers:\(fingerprintIDs(outcome.supplierIDs))",
            "categories:\(fingerprintIDs(outcome.categoryIDs))",
            "products:\(fingerprintIDs(outcome.productIDs))",
            "supplierTombstones:\(fingerprintIDs(outcome.supplierTombstoneIDs))",
            "categoryTombstones:\(fingerprintIDs(outcome.categoryTombstoneIDs))",
            "productTombstones:\(fingerprintIDs(outcome.productTombstoneIDs))"
        ].joined(separator: "|")
    }

    nonisolated private static func fingerprintIDs(_ ids: [UUID]) -> String {
        ids.map { $0.uuidString.lowercased() }.sorted().joined(separator: ",")
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
        ownerUserID: UUID,
        shopID: UUID?
    ) -> SyncAutomaticProductCreatePayload {
        SyncAutomaticProductCreatePayload(
            ownerUserID: ownerUserID,
            shopID: shopID,
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

    nonisolated private static func makeProductTombstonePayload() -> SyncAutomaticProductUpdatePayload {
        SyncAutomaticProductUpdatePayload(
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
    }

    nonisolated static func makeProductUpdatePayload(
        _ product: Product,
        changedFields: [String]
    ) -> SyncAutomaticProductUpdatePayload {
        let fields = Set(changedFields.map(normalizedProductChangedField))
        return SyncAutomaticProductUpdatePayload(
            barcode: fields.contains("barcode") ? product.barcode : nil,
            itemNumber: fields.contains("itemnumber") ? product.itemNumber : nil,
            productName: fields.contains("productname") ? product.productName : nil,
            secondProductName: fields.contains("secondproductname") ? product.secondProductName : nil,
            purchasePrice: fields.contains("purchaseprice") ? product.purchasePrice : nil,
            retailPrice: fields.contains("retailprice") ? product.retailPrice : nil,
            supplierID: fields.contains("supplier") ? product.supplier?.remoteID : nil,
            categoryID: fields.contains("category") ? product.category?.remoteID : nil,
            stockQuantity: fields.contains("stockquantity") ? product.stockQuantity : nil,
            deletedAt: fields.contains("tombstone") ? product.remoteDeletedAt.map(timestamp) : nil
        )
    }

    nonisolated private static func normalizedProductChangedField(_ field: String) -> String {
        switch field.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "suppliername":
            return "supplier"
        case "categoryname":
            return "category"
        default:
            return field.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    nonisolated private static func pendingKeys(for supplier: Supplier) -> Set<String> {
        Set([
            LocalPendingChangeLogicalKey.supplier(remoteID: supplier.remoteID, name: supplier.name),
            LocalPendingChangeLogicalKey.supplier(remoteID: nil, name: supplier.name)
        ])
    }

    nonisolated private static func isStoreCompatible(
        _ change: LocalPendingChange,
        storeIdentity: LocalStoreIdentity?
    ) -> Bool {
        guard let storeIdentity else { return true }
        return Task126OwnerStoreScope.normalizedStoreId(change.storeId) == storeIdentity.storeId
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
