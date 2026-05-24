import CryptoKit
import Foundation
import SwiftData

protocol SyncAutomaticCatalogRemoteWriting: Sendable {
    func createSuppliers(_ payloads: [SyncAutomaticSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow]
    func updateSupplier(id: UUID, payload: SyncAutomaticSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow
    func createCategories(_ payloads: [SyncAutomaticCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow]
    func updateCategory(id: UUID, payload: SyncAutomaticCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow
    func createProducts(_ payloads: [SyncAutomaticProductCreatePayload]) async throws -> [RemoteInventoryProductRow]
    func updateProduct(id: UUID, payload: SyncAutomaticProductUpdatePayload) async throws -> RemoteInventoryProductRow
}

protocol SyncAutomaticProductPriceRemoteWriting: Sendable {
    func insertProductPrices(_ payloads: [SyncAutomaticProductPricePayload]) async throws -> [RemoteInventoryProductPriceRow]
}

extension SupabaseInventoryService: SyncAutomaticCatalogRemoteWriting, SyncAutomaticProductPriceRemoteWriting {}

nonisolated struct SyncAutomaticSupplierCreatePayload: Encodable, Equatable, Sendable {
    let ownerUserID: UUID
    let name: String

    enum CodingKeys: String, CodingKey {
        case ownerUserID = "owner_user_id"
        case name
    }
}

nonisolated struct SyncAutomaticSupplierUpdatePayload: Encodable, Equatable, Sendable {
    let name: String
}

nonisolated struct SyncAutomaticCategoryCreatePayload: Encodable, Equatable, Sendable {
    let ownerUserID: UUID
    let name: String

    enum CodingKeys: String, CodingKey {
        case ownerUserID = "owner_user_id"
        case name
    }
}

nonisolated struct SyncAutomaticCategoryUpdatePayload: Encodable, Equatable, Sendable {
    let name: String
}

nonisolated struct SyncAutomaticProductCreatePayload: Encodable, Equatable, Sendable {
    let ownerUserID: UUID
    let barcode: String
    let itemNumber: String?
    let productName: String?
    let secondProductName: String?
    let purchasePrice: Double?
    let retailPrice: Double?
    let supplierID: UUID?
    let categoryID: UUID?
    let stockQuantity: Double?

    enum CodingKeys: String, CodingKey {
        case ownerUserID = "owner_user_id"
        case barcode
        case itemNumber = "item_number"
        case productName = "product_name"
        case secondProductName = "second_product_name"
        case purchasePrice = "purchase_price"
        case retailPrice = "retail_price"
        case supplierID = "supplier_id"
        case categoryID = "category_id"
        case stockQuantity = "stock_quantity"
    }
}

nonisolated struct SyncAutomaticProductUpdatePayload: Encodable, Equatable, Sendable {
    let barcode: String?
    let itemNumber: String?
    let productName: String?
    let secondProductName: String?
    let purchasePrice: Double?
    let retailPrice: Double?
    let supplierID: UUID?
    let categoryID: UUID?
    let stockQuantity: Double?
    let deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case barcode
        case itemNumber = "item_number"
        case productName = "product_name"
        case secondProductName = "second_product_name"
        case purchasePrice = "purchase_price"
        case retailPrice = "retail_price"
        case supplierID = "supplier_id"
        case categoryID = "category_id"
        case stockQuantity = "stock_quantity"
        case deletedAt = "deleted_at"
    }
}

nonisolated struct SyncAutomaticProductPricePayload: Encodable, Equatable, Sendable {
    let id: UUID
    let ownerUserID: UUID
    let productID: UUID
    let type: String
    let price: Double
    let effectiveAt: String
    let source: String?
    let note: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case ownerUserID = "owner_user_id"
        case productID = "product_id"
        case type
        case price
        case effectiveAt = "effective_at"
        case source
        case note
        case createdAt = "created_at"
    }
}

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
                blockers: blockers.uniquedSorted()
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
                blockers: blockers.uniquedSorted()
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

nonisolated private enum AutomaticSyncEventOutboxWriter {
    private static let maxEntityIDsPerKey = 250

    static func entityIDs(_ idsByKey: [String: [UUID]]) -> SyncEventJSONValue {
        var object: [String: SyncEventJSONValue] = [:]
        for (key, ids) in idsByKey {
            let uniqueIDs = Array(Set(ids)).sorted { $0.uuidString < $1.uuidString }
            guard !uniqueIDs.isEmpty,
                  uniqueIDs.count <= maxEntityIDsPerKey else {
                continue
            }
            object[key] = .array(uniqueIDs.map { .string($0.uuidString.lowercased()) })
        }
        return object.isEmpty ? .null : .object(object)
    }

    static func enqueue(
        context: ModelContext,
        ownerUserID: UUID,
        domain: String,
        eventType: String,
        changedCount: Int,
        entityIDs: SyncEventJSONValue,
        metadata: SyncEventJSONValue,
        source: String,
        entityIDsShape: String,
        metadataShape: String,
        clientEventFingerprint: String
    ) throws {
        guard changedCount > 0 else { return }
        let owner = ownerUserID.uuidString.lowercased()
        let clientEventID = clientEventID(prefix: source, fingerprint: "\(owner):\(clientEventFingerprint):\(changedCount)")
        if try existingEntry(context: context, ownerUserID: owner, clientEventID: clientEventID) != nil {
            return
        }
        let request = SyncEventRecordRequest(
            domain: domain,
            eventType: eventType,
            changedCount: changedCount,
            entityIDs: entityIDs,
            metadata: metadata,
            source: source,
            clientEventID: clientEventID
        )
        let payloadJSON = try? SyncEventOutboxPayloadCodec.makePayloadJSON(
            for: request,
            validator: SyncEventRecordValidator()
        )
        let entry = try SyncEventOutboxFactory.makeEntry(
            ownerUserID: owner,
            domain: domain,
            eventType: eventType,
            changedCount: changedCount,
            entityIDsShape: entityIDsShape,
            metadataShape: metadataShape,
            entityIDsPayloadJSON: payloadJSON?.entityIDsPayloadJSON,
            metadataPayloadJSON: payloadJSON?.metadataPayloadJSON,
            sourceDeviceID: nil,
            batchID: nil,
            clientEventID: clientEventID
        )
        SyncEventOutboxLocalStore(context: context).add(entry)
    }

    private static func existingEntry(
        context: ModelContext,
        ownerUserID: String,
        clientEventID: String
    ) throws -> SyncEventOutboxEntry? {
        var descriptor = FetchDescriptor<SyncEventOutboxEntry>(
            predicate: #Predicate<SyncEventOutboxEntry> { entry in
                entry.ownerUserID == ownerUserID && entry.clientEventID == clientEventID
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func clientEventID(prefix: String, fingerprint: String) -> String {
        let digest = SHA256.hash(data: Data(fingerprint.utf8))
        let suffix = digest.map { String(format: "%02x", $0) }.joined()
        return "\(prefix):\(suffix)"
    }
}

final class HistorySessionPushService: SyncHistorySessionPushProviding {
    private let modelContainer: ModelContainer
    private let remote: SupabaseInventoryService
    private let recorder: (any SyncEventRecording)?

    init(
        modelContainer: ModelContainer,
        remote: SupabaseInventoryService,
        recorder: (any SyncEventRecording)?
    ) {
        self.modelContainer = modelContainer
        self.remote = remote
        self.recorder = recorder
    }

    func syncHistorySessions(
        ownerUserID: UUID,
        mode: SyncHistorySessionMode,
        onProgress: @escaping @MainActor @Sendable (HistorySessionSyncProgress) -> Void
    ) async throws -> SyncHistorySessionSummary {
        guard mode == .incremental else {
            return SyncHistorySessionSummary()
        }
        let modelContainer = self.modelContainer
        let remote = self.remote
        let recorder = self.recorder
        return try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            let entries = try context.fetch(
                FetchDescriptor<HistoryEntry>(
                    sortBy: [SortDescriptor(\HistoryEntry.timestamp, order: .reverse)]
                )
            )
            let service = HistorySessionSyncService(remote: remote)
            let push = try await service.pushPendingHistorySessions(
                entries: entries,
                ownerUserID: ownerUserID,
                context: context,
                includeSynced: false,
                onProgress: onProgress
            )
            try context.save()
            if push.uploadedCount > 0,
               let recorder {
                try await Self.recordHistorySyncEvent(
                    recorder: recorder,
                    ownerUserID: ownerUserID,
                    remoteIDs: Array(push.pushedRemoteIDs)
                )
            }
            return SyncHistorySessionSummary(
                uploaded: push.uploadedCount,
                skippedClean: push.skippedCleanCount,
                skippedOversized: push.skippedOversizedCount
            )
        }.value
    }

    private static func recordHistorySyncEvent(
        recorder: any SyncEventRecording,
        ownerUserID: UUID,
        remoteIDs: [UUID]
    ) async throws {
        let request = SyncEventRecordRequest(
            domain: "history",
            eventType: "upsert",
            changedCount: remoteIDs.count,
            entityIDs: .object([
                "history_session_ids": .array(
                    remoteIDs
                        .sorted { $0.uuidString < $1.uuidString }
                        .map { .string($0.uuidString.lowercased()) }
                )
            ]),
            metadata: .object([
                "source": .string("automatic_history_session_push"),
                "owner_user_id": .string(ownerUserID.uuidString.lowercased())
            ]),
            source: "ios_automatic_runtime",
            clientEventID: "history-automatic-push:\(UUID().uuidString.lowercased())"
        )
        _ = try await recorder.record(request)
    }
}

private extension Array where Element == String {
    nonisolated func uniquedSorted() -> [String] {
        Array(Set(self)).sorted()
    }
}

final class SyncActivityRegistrationService: SyncActivityRegistrationProviding {
    private let modelContainer: ModelContainer
    private let recorder: (any SyncEventRecording)?
    private let now: () -> Date

    init(
        modelContainer: ModelContainer,
        recorder: (any SyncEventRecording)?,
        now: @escaping () -> Date = Date.init
    ) {
        self.modelContainer = modelContainer
        self.recorder = recorder
        self.now = now
    }

    func loadSyncActivityRegistrationSnapshot(ownerUserID: UUID) async throws -> SyncActivityRegistrationSnapshot {
        let modelContainer = self.modelContainer
        let now = self.now
        return try await Task { @MainActor in
            let context = ModelContext(modelContainer)
            let counts = try LocalOutboxStore(context: context).fetchCounts(ownerUserID: ownerUserID, now: now())
            return SyncActivityRegistrationSnapshot(
                readyToRegister: counts.retryable,
                waiting: counts.pending + counts.failedRetryable,
                notRegisterable: counts.blocked + counts.dead
            )
        }.value
    }

    func registerSyncActivities(ownerUserID: UUID) async throws -> SyncActivityRegistrationResult {
        guard let recorder else {
            return SyncActivityRegistrationResult(
                status: .empty,
                summary: SyncActivityRegistrationSummary(registered: 0, waiting: 0, notRegisterable: 0)
            )
        }
        let modelContainer = self.modelContainer
        let now = self.now
        return try await Task { @MainActor in
            let context = ModelContext(modelContainer)
            let before = try LocalOutboxStore(context: context).fetchCounts(ownerUserID: ownerUserID, now: now())
            guard before.retryable > 0 else {
                return SyncActivityRegistrationResult(
                    status: before.blocked + before.dead > 0 ? .blocked : .empty,
                    summary: SyncActivityRegistrationSummary(
                        registered: 0,
                        waiting: before.pending + before.failedRetryable,
                        notRegisterable: before.blocked + before.dead
                    )
                )
            }
            let outcome = try await SyncEventOutboxDrainer(
                context: context,
                recorder: recorder,
                now: now
            ).drainOnce(ownerUserID: ownerUserID)
            let after = try LocalOutboxStore(context: context).fetchCounts(ownerUserID: ownerUserID, now: now())
            return SyncActivityRegistrationResult(
                status: Self.status(outcome: outcome, after: after),
                summary: SyncActivityRegistrationSummary(
                    registered: outcome.sent,
                    waiting: after.pending + after.failedRetryable,
                    notRegisterable: after.blocked + after.dead
                )
            )
        }.value
    }

    @MainActor
    private static func status(
        outcome: SyncEventOutboxDrainOutcome,
        after: SyncEventOutboxCounts
    ) -> SyncActivityRegistrationStatus {
        switch outcome.status {
        case .drained:
            return after.pending + after.failedRetryable > 0 ? .partialRetryable : .success
        case .partiallyDrained:
            return .partialRetryable
        case .noWork:
            return after.blocked + after.dead > 0 ? .blocked : .empty
        case .alreadyRunning, .networkFailed:
            return .retryableFailure
        case .blockedPayloadReplay, .blocked:
            return .blocked
        }
    }
}
