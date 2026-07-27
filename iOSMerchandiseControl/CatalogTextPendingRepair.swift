import Foundation
import SwiftData

nonisolated enum CatalogTextPendingRepairError: Error, Equatable, Sendable {
    case boundedLimitExceeded(limit: Int)
    case ambiguousTarget
}

nonisolated struct CatalogTextPendingRepairResult: Equatable, Sendable {
    var repairedProducts = 0
    var repairedSuppliers = 0
    var repairedCategories = 0

    var repairedCount: Int {
        repairedProducts + repairedSuppliers + repairedCategories
    }
}

/// Ripara soltanto entità già dirty/pending nello scope corrente. Mantiene lo
/// stesso record pending/idempotency key e aggiorna fingerprint/logical key
/// nella medesima transazione, senza produrre un secondo outbox.
nonisolated enum CatalogTextPendingRepair {
    static func repair(
        context: ModelContext,
        ownerUserID: UUID,
        storeIdentity: LocalStoreIdentity,
        limit: Int = LocalPendingChangeAccumulator.defaultMaxActiveChanges
    ) throws -> CatalogTextPendingRepairResult {
        let owner = ownerUserID.uuidString.lowercased()
        let ownerHash = AccountBindingStore.accountHash(for: ownerUserID)
        let activeStoreID = storeIdentity.storeId
        let activeLocalStoreID = storeIdentity.localStoreId
        let safeLimit = max(1, limit)
        let changes = try fetchScopedPendingChanges(
            context: context,
            owner: owner,
            ownerHash: ownerHash,
            storeID: activeStoreID,
            localStoreID: activeLocalStoreID,
            storeIdentity: storeIdentity,
            limit: safeLimit
        )

        let targetIndex = try makeTargetIndex(
            container: context.container,
            changes: changes
        )
        let resolvedChanges = changes.map {
            ResolvedChange(
                change: $0,
                target: targetIndex.target(for: $0, context: context)
            )
        }

        for resolved in resolvedChanges
        where resolved.change.operation != .delete {
            guard let target = resolved.target else { continue }
            switch target {
            case let .product(product):
                try CatalogTextPersistenceBoundary
                    .preflightCanonicalization(product)
            case let .supplier(supplier):
                try CatalogTextPersistenceBoundary
                    .preflightCanonicalization(supplier)
            case let .category(category):
                try CatalogTextPersistenceBoundary
                    .preflightCanonicalization(category)
            }
        }

        var result = CatalogTextPendingRepairResult()
        let timestamp = Date()

        for resolved in resolvedChanges
        where resolved.change.operation != .delete {
            let change = resolved.change
            guard let target = resolved.target else { continue }
            switch target {
            case let .product(product):
                let before = ProductTextSnapshot(product)
                try CatalogTextPersistenceBoundary.canonicalize(product)
                let after = ProductTextSnapshot(product)
                guard before != after else { continue }
                change.logicalKey = LocalPendingChangeLogicalKey.product(
                    remoteID: product.remoteID,
                    barcode: product.barcode
                )
                change.intendedFingerprintHash =
                    LocalPendingChangeLogicalKey.productFingerprintHash(product)
                change.changedFields = uniqueSorted(
                    change.changedFields + before.changedFields(comparedTo: after)
                )
                change.updatedAt = timestamp
                result.repairedProducts += 1

            case let .supplier(supplier):
                let before = Array(supplier.name.unicodeScalars)
                try CatalogTextPersistenceBoundary.canonicalize(supplier)
                guard before != Array(supplier.name.unicodeScalars) else {
                    continue
                }
                change.logicalKey = LocalPendingChangeLogicalKey.supplier(
                    remoteID: supplier.remoteID,
                    name: supplier.name
                )
                change.intendedFingerprintHash =
                    LocalPendingChangeLogicalKey.supplierFingerprintHash(supplier)
                change.changedFields = uniqueSorted(
                    change.changedFields + ["name"]
                )
                change.updatedAt = timestamp
                result.repairedSuppliers += 1

            case let .category(category):
                let before = Array(category.name.unicodeScalars)
                try CatalogTextPersistenceBoundary.canonicalize(category)
                guard before != Array(category.name.unicodeScalars) else {
                    continue
                }
                change.logicalKey = LocalPendingChangeLogicalKey.category(
                    remoteID: category.remoteID,
                    name: category.name
                )
                change.intendedFingerprintHash =
                    LocalPendingChangeLogicalKey.categoryFingerprintHash(category)
                change.changedFields = uniqueSorted(
                    change.changedFields + ["name"]
                )
                change.updatedAt = timestamp
                result.repairedCategories += 1

            }
        }

        if result.repairedCount > 0 {
            try context.save()
        }
        return result
    }

    private static let catalogPageSize = 256

    private static func fetchScopedPendingChanges(
        context: ModelContext,
        owner: String,
        ownerHash: String,
        storeID: String,
        localStoreID: String,
        storeIdentity: LocalStoreIdentity,
        limit: Int
    ) throws -> [LocalPendingChange] {
        let pending = LocalPendingChangeStatus.pending.rawValue
        var matches: [LocalPendingChange] = []
        matches.reserveCapacity(min(limit, catalogPageSize))
        var offset = 0

        while true {
            var descriptor = FetchDescriptor<LocalPendingChange>(
                predicate: #Predicate<LocalPendingChange> { change in
                    change.ownerUserID == owner
                        && change.ownerHash == ownerHash
                        && change.storeId == storeID
                        && change.localStoreId == localStoreID
                        && change.statusRaw == pending
                },
                sortBy: [SortDescriptor(\.updatedAt, order: .forward)]
            )
            descriptor.fetchLimit = catalogPageSize
            descriptor.fetchOffset = offset
            let page = try context.fetch(descriptor)

            for change in page
            where change.syncProtocolVersion
                    == storeIdentity.syncProtocolVersion
                && change.schemaVersion == storeIdentity.schemaVersion
                && change.storeEpoch == storeIdentity.storeEpoch
                && (
                    change.entityKind == .product
                        || change.entityKind == .supplier
                        || change.entityKind == .productCategory
                ) {
                matches.append(change)
                guard matches.count <= limit else {
                    throw CatalogTextPendingRepairError
                        .boundedLimitExceeded(limit: limit)
                }
            }

            guard page.count == catalogPageSize else { break }
            offset += page.count
        }
        return matches
    }

    private struct TargetKeys {
        var productRemoteIDs: Set<UUID> = []
        var productLogicalKeys: Set<String> = []
        var supplierRemoteIDs: Set<UUID> = []
        var supplierLogicalKeys: Set<String> = []
        var categoryRemoteIDs: Set<UUID> = []
        var categoryLogicalKeys: Set<String> = []

        init(changes: [LocalPendingChange]) {
            for change in changes where change.operation != .delete {
                let remoteID = change.entityRemoteID
                    ?? remoteIDFromLogicalKey(change.logicalKey)
                switch change.entityKind {
                case .product:
                    if let remoteID {
                        productRemoteIDs.insert(remoteID)
                    } else {
                        productLogicalKeys.insert(change.logicalKey)
                    }
                case .supplier:
                    if let remoteID {
                        supplierRemoteIDs.insert(remoteID)
                    } else {
                        supplierLogicalKeys.insert(change.logicalKey)
                    }
                case .productCategory:
                    if let remoteID {
                        categoryRemoteIDs.insert(remoteID)
                    } else {
                        categoryLogicalKeys.insert(change.logicalKey)
                    }
                case .productPrice, .importBatch, .historySession:
                    continue
                }
            }
        }
    }

    private struct TargetIndex {
        var productsByRemoteID: [UUID: PersistentIdentifier] = [:]
        var productsByLogicalKey: [String: PersistentIdentifier] = [:]
        var suppliersByRemoteID: [UUID: PersistentIdentifier] = [:]
        var suppliersByLogicalKey: [String: PersistentIdentifier] = [:]
        var categoriesByRemoteID: [UUID: PersistentIdentifier] = [:]
        var categoriesByLogicalKey: [String: PersistentIdentifier] = [:]

        func target(
            for change: LocalPendingChange,
            context: ModelContext
        ) -> RepairTarget? {
            let remoteID = change.entityRemoteID
                ?? remoteIDFromLogicalKey(change.logicalKey)
            switch change.entityKind {
            case .product:
                let persistentID = remoteID.flatMap {
                    productsByRemoteID[$0]
                } ?? productsByLogicalKey[change.logicalKey]
                return persistentID.flatMap {
                    (context.model(for: $0) as? Product).map(RepairTarget.product)
                }
            case .supplier:
                let persistentID = remoteID.flatMap {
                    suppliersByRemoteID[$0]
                } ?? suppliersByLogicalKey[change.logicalKey]
                return persistentID.flatMap {
                    (context.model(for: $0) as? Supplier).map(RepairTarget.supplier)
                }
            case .productCategory:
                let persistentID = remoteID.flatMap {
                    categoriesByRemoteID[$0]
                } ?? categoriesByLogicalKey[change.logicalKey]
                return persistentID.flatMap {
                    (context.model(for: $0) as? ProductCategory)
                        .map(RepairTarget.category)
                }
            case .productPrice, .importBatch, .historySession:
                return nil
            }
        }
    }

    private enum RepairTarget {
        case product(Product)
        case supplier(Supplier)
        case category(ProductCategory)
    }

    private struct ResolvedChange {
        let change: LocalPendingChange
        let target: RepairTarget?
    }

    private static func makeTargetIndex(
        container: ModelContainer,
        changes: [LocalPendingChange]
    ) throws -> TargetIndex {
        let keys = TargetKeys(changes: changes)
        var index = TargetIndex()
        if !keys.productRemoteIDs.isEmpty
            || !keys.productLogicalKeys.isEmpty {
            try indexProducts(container: container, keys: keys, index: &index)
        }
        if !keys.supplierRemoteIDs.isEmpty
            || !keys.supplierLogicalKeys.isEmpty {
            try indexSuppliers(container: container, keys: keys, index: &index)
        }
        if !keys.categoryRemoteIDs.isEmpty
            || !keys.categoryLogicalKeys.isEmpty {
            try indexCategories(container: container, keys: keys, index: &index)
        }
        return index
    }

    private static func indexProducts(
        container: ModelContainer,
        keys: TargetKeys,
        index: inout TargetIndex
    ) throws {
        var offset = 0
        while true {
            let lookupContext = ModelContext(container)
            var descriptor = FetchDescriptor<Product>(
                sortBy: [SortDescriptor(\.barcode, order: .forward)]
            )
            descriptor.fetchLimit = catalogPageSize
            descriptor.fetchOffset = offset
            let page = try lookupContext.fetch(descriptor)
            for product in page {
                if let remoteID = product.remoteID,
                   keys.productRemoteIDs.contains(remoteID) {
                    try insertUnique(
                        product.persistentModelID,
                        key: remoteID,
                        into: &index.productsByRemoteID
                    )
                }
                let logicalKey = LocalPendingChangeLogicalKey.product(
                    remoteID: nil,
                    barcode: product.barcode
                )
                if keys.productLogicalKeys.contains(logicalKey) {
                    try insertUnique(
                        product.persistentModelID,
                        key: logicalKey,
                        into: &index.productsByLogicalKey
                    )
                }
            }
            guard page.count == catalogPageSize else { break }
            offset += page.count
        }
    }

    private static func indexSuppliers(
        container: ModelContainer,
        keys: TargetKeys,
        index: inout TargetIndex
    ) throws {
        var offset = 0
        while true {
            let lookupContext = ModelContext(container)
            var descriptor = FetchDescriptor<Supplier>(
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
            descriptor.fetchLimit = catalogPageSize
            descriptor.fetchOffset = offset
            let page = try lookupContext.fetch(descriptor)
            for supplier in page {
                if let remoteID = supplier.remoteID,
                   keys.supplierRemoteIDs.contains(remoteID) {
                    try insertUnique(
                        supplier.persistentModelID,
                        key: remoteID,
                        into: &index.suppliersByRemoteID
                    )
                }
                let logicalKey = LocalPendingChangeLogicalKey.supplier(
                    remoteID: nil,
                    name: supplier.name
                )
                if keys.supplierLogicalKeys.contains(logicalKey) {
                    try insertUnique(
                        supplier.persistentModelID,
                        key: logicalKey,
                        into: &index.suppliersByLogicalKey
                    )
                }
            }
            guard page.count == catalogPageSize else { break }
            offset += page.count
        }
    }

    private static func indexCategories(
        container: ModelContainer,
        keys: TargetKeys,
        index: inout TargetIndex
    ) throws {
        var offset = 0
        while true {
            let lookupContext = ModelContext(container)
            var descriptor = FetchDescriptor<ProductCategory>(
                sortBy: [SortDescriptor(\.name, order: .forward)]
            )
            descriptor.fetchLimit = catalogPageSize
            descriptor.fetchOffset = offset
            let page = try lookupContext.fetch(descriptor)
            for category in page {
                if let remoteID = category.remoteID,
                   keys.categoryRemoteIDs.contains(remoteID) {
                    try insertUnique(
                        category.persistentModelID,
                        key: remoteID,
                        into: &index.categoriesByRemoteID
                    )
                }
                let logicalKey = LocalPendingChangeLogicalKey.category(
                    remoteID: nil,
                    name: category.name
                )
                if keys.categoryLogicalKeys.contains(logicalKey) {
                    try insertUnique(
                        category.persistentModelID,
                        key: logicalKey,
                        into: &index.categoriesByLogicalKey
                    )
                }
            }
            guard page.count == catalogPageSize else { break }
            offset += page.count
        }
    }

    private static func insertUnique<Key: Hashable>(
        _ persistentID: PersistentIdentifier,
        key: Key,
        into index: inout [Key: PersistentIdentifier]
    ) throws {
        if let existing = index[key], existing != persistentID {
            throw CatalogTextPendingRepairError.ambiguousTarget
        }
        index[key] = persistentID
    }

    private static func uniqueSorted(_ fields: [String]) -> [String] {
        Array(Set(fields)).sorted()
    }

    private struct ProductTextSnapshot: Equatable {
        let barcode: [Unicode.Scalar]
        let itemNumber: [Unicode.Scalar]?
        let productName: [Unicode.Scalar]?
        let secondProductName: [Unicode.Scalar]?

        init(_ product: Product) {
            barcode = Array(product.barcode.unicodeScalars)
            itemNumber = product.itemNumber.map { Array($0.unicodeScalars) }
            productName = product.productName.map { Array($0.unicodeScalars) }
            secondProductName = product.secondProductName.map {
                Array($0.unicodeScalars)
            }
        }

        func changedFields(comparedTo other: Self) -> [String] {
            var fields: [String] = []
            if barcode != other.barcode { fields.append("barcode") }
            if itemNumber != other.itemNumber { fields.append("itemNumber") }
            if productName != other.productName { fields.append("productName") }
            if secondProductName != other.secondProductName {
                fields.append("secondProductName")
            }
            return fields
        }
    }
}
