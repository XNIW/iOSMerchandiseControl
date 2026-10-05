import Foundation
import SwiftData

/// Transfers committed local intent into an already verified remote staging
/// generation, off the UI thread. The caller fences the source before/after
/// preparation and compares it under the publication lease, so a concurrent
/// Save or ACK retries without publishing a stale copy.
/// The canonical recovery ledger and its checkpoint are never rewritten.
nonisolated enum SameScopeRecoveryLocalWorkTransfer {
    private static let limit = LocalPendingChangeAccumulator.defaultMaxActiveChanges

    static func apply(
        from active: ModelContainer, to staging: ModelContainer,
        scope: Task126VerifiedOwnerStoreScope, stagingGenerationID: UUID
    ) throws {
        let source = ModelContext(active)
        let destination = ModelContext(staging)
        source.autosaveEnabled = false
        destination.autosaveEnabled = false
        let owner = scope.ownerUserID.uuidString.lowercased()
        var pendingDescriptor = FetchDescriptor<LocalPendingChange>(predicate: #Predicate {
            $0.statusRaw != "superseded" && $0.statusRaw != "acknowledged"
        })
        pendingDescriptor.fetchLimit = limit + 1
        let pending = try source.fetch(pendingDescriptor)
        guard pending.count <= limit else { throw SyncStoreGenerationError.generationResourceBudgetExceeded }
        let terminalStatuses = ["sent", "blockedContract", "blockedAuth", "blockedSchema", "dead", "localOnly"]
        var outboxDescriptor = FetchDescriptor<SyncEventOutboxEntry>(predicate: #Predicate {
            !terminalStatuses.contains($0.statusRaw)
                || ($0.statusRaw == "localOnly" && $0.domain == "local_business_attempt")
        })
        outboxDescriptor.fetchLimit = limit + 1
        let outbox = try source.fetch(outboxDescriptor)
        guard outbox.count <= limit else { throw SyncStoreGenerationError.generationResourceBudgetExceeded }
        let sealedAttempts = outbox.filter(LocalPendingBusinessAttemptStore.isSealed)
        guard Set(sealedAttempts.map(\.id)).count == sealedAttempts.count else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        let sealedByChangeID = Dictionary(uniqueKeysWithValues: sealedAttempts.map { ($0.id, $0) })
        let dirtyHistory = #Predicate<HistoryEntry> {
            $0.localChangeRevision > $0.lastSyncedLocalRevision
                || ($0.remoteDeletedAt == nil && $0.remotePayloadFingerprint == nil)
        }
        var dirtyHistoryProbe = FetchDescriptor<HistoryEntry>(predicate: dirtyHistory)
        dirtyHistoryProbe.fetchLimit = 1
        let hasDirtyHistory = !(try source.fetch(dirtyHistoryProbe)).isEmpty
        guard !pending.isEmpty || !outbox.isEmpty || hasDirtyHistory else { return }
        guard Set(pending.map(\.changeID)).count == pending.count else {
            throw SyncStoreGenerationError.activationReadBackFailed
        }
        for change in pending {
            guard LocalPendingChangeEntityKind(rawValue: change.entityKindRaw) != nil,
                  LocalPendingChangeOperation(rawValue: change.operationRaw) != nil,
                  LocalPendingChangeStatus(rawValue: change.statusRaw) != nil,
                  LocalPendingChangeOrigin(rawValue: change.originRaw) != nil,
                  change.ownerUserID == owner,
                  change.ownerHash == AccountBindingStore.redactedAccountHash(for: owner),
                  change.storeId == scope.storeIdentity.storeId,
                  change.localStoreId == scope.storeIdentity.localStoreId,
                  change.syncProtocolVersion == scope.storeIdentity.syncProtocolVersion,
                  change.schemaVersion == scope.storeIdentity.schemaVersion,
                  change.storeEpoch == scope.storeIdentity.storeEpoch,
                  UUID(uuidString: change.changeID) != nil,
                  !change.idempotencyKey.isEmpty else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
        }
        let grouped = Dictionary(grouping: pending, by: \.entityKind)
        let supplierKeys = Set((grouped[.supplier] ?? []).map(\.logicalKey))
        let categoryKeys = Set((grouped[.productCategory] ?? []).map(\.logicalKey))
        let productKeys = Set((grouped[.product] ?? []).map(\.logicalKey))
        let priceKeys = Set((grouped[.productPrice] ?? []).map(\.logicalKey))
        let historyKeys = Set((grouped[.historySession] ?? []).map(\.logicalKey))
        var suppliers: [String: Supplier] = [:]
        var categories: [String: ProductCategory] = [:]
        var products: [String: Product] = [:]
        var prices: [String: ProductPrice] = [:]
        var histories: [String: HistoryEntry] = [:]
        if !supplierKeys.isEmpty { try scan(Supplier.self, context: source, sort: [SortDescriptor(\Supplier.name)]) { row in
            let key = LocalPendingChangeLogicalKey.supplier(remoteID: row.remoteID, name: row.name)
            if supplierKeys.contains(key) { suppliers[key] = row }
        } }
        if !categoryKeys.isEmpty { try scan(ProductCategory.self, context: source, sort: [SortDescriptor(\ProductCategory.name)]) { row in
            let key = LocalPendingChangeLogicalKey.category(remoteID: row.remoteID, name: row.name)
            if categoryKeys.contains(key) { categories[key] = row }
        } }
        if !productKeys.isEmpty { try scan(Product.self, context: source, sort: [SortDescriptor(\Product.barcode)]) { row in
            let key = LocalPendingChangeLogicalKey.product(remoteID: row.remoteID, barcode: row.barcode)
            if productKeys.contains(key) { products[key] = row }
        } }
        if !priceKeys.isEmpty { try scan(ProductPrice.self, context: source, sort: [SortDescriptor(\ProductPrice.createdAt)]) { row in
            guard let product = row.product else { throw SyncStoreGenerationError.activationReadBackFailed }
            let key = LocalPendingChangeLogicalKey.productPrice(
                productRemoteID: product.remoteID, productBarcode: product.barcode,
                type: row.type, effectiveAt: row.effectiveAt
            )
            if priceKeys.contains(key) {
                prices[key] = row
                products[LocalPendingChangeLogicalKey.product(remoteID: product.remoteID, barcode: product.barcode)] = product
            }
        } }
        try scan(HistoryEntry.self, context: source, sort: [SortDescriptor(\HistoryEntry.uid)]) { row in
            let key = LocalPendingChangeLogicalKey.historySession(remoteID: row.remoteID, uid: row.uid)
            let dirty = row.localChangeRevision > row.lastSyncedLocalRevision
                || (row.remoteDeletedAt == nil && row.remotePayloadFingerprint == nil)
            guard historyKeys.contains(key) || dirty else { return }
            guard row.ownerUserID == owner, row.storeID == scope.storeIdentity.storeId,
                  row.shopID == scope.shopID, !row.hasPersistedJSONDecodeFault,
                  histories.count < limit else { throw SyncStoreGenerationError.activationReadBackFailed }
            histories[key] = row
        }
        // Relation closure is copied once; a remote relation already present
        // in C keeps C's metadata unless it has its own local mutation.
        for product in products.values {
            if let row = product.supplier {
                suppliers[LocalPendingChangeLogicalKey.supplier(remoteID: row.remoteID, name: row.name)] = row
            }
            if let row = product.category {
                categories[LocalPendingChangeLogicalKey.category(remoteID: row.remoteID, name: row.name)] = row
            }
        }
        let wantedSupplierKeys = Set(suppliers.keys)
        let wantedCategoryKeys = Set(categories.keys)
        let wantedProductKeys = Set(products.keys)
        let wantedPriceKeys = Set(prices.keys)
        let wantedHistoryKeys = Set(histories.keys)
        var targetSuppliers: [String: Supplier] = [:]
        var targetCategories: [String: ProductCategory] = [:]
        var targetProducts: [String: Product] = [:]
        var targetPrices: [String: ProductPrice] = [:]
        var targetHistories: [String: HistoryEntry] = [:]
        if !wantedSupplierKeys.isEmpty { try scan(Supplier.self, context: destination, sort: [SortDescriptor(\Supplier.name)]) { row in
            let key = LocalPendingChangeLogicalKey.supplier(remoteID: row.remoteID, name: row.name)
            if wantedSupplierKeys.contains(key) { targetSuppliers[key] = row }
        } }
        if !wantedCategoryKeys.isEmpty { try scan(ProductCategory.self, context: destination, sort: [SortDescriptor(\ProductCategory.name)]) { row in
            let key = LocalPendingChangeLogicalKey.category(remoteID: row.remoteID, name: row.name)
            if wantedCategoryKeys.contains(key) { targetCategories[key] = row }
        } }
        if !wantedProductKeys.isEmpty { try scan(Product.self, context: destination, sort: [SortDescriptor(\Product.barcode)]) { row in
            let key = LocalPendingChangeLogicalKey.product(remoteID: row.remoteID, barcode: row.barcode)
            if wantedProductKeys.contains(key) { targetProducts[key] = row }
        } }
        if !wantedPriceKeys.isEmpty { try scan(ProductPrice.self, context: destination, sort: [SortDescriptor(\ProductPrice.createdAt)]) { row in
            guard let product = row.product else { throw SyncStoreGenerationError.activationReadBackFailed }
            let key = LocalPendingChangeLogicalKey.productPrice(
                productRemoteID: product.remoteID, productBarcode: product.barcode,
                type: row.type, effectiveAt: row.effectiveAt
            )
            if wantedPriceKeys.contains(key) { targetPrices[key] = row }
        } }
        if !wantedHistoryKeys.isEmpty { try scan(HistoryEntry.self, context: destination, sort: [SortDescriptor(\HistoryEntry.uid)]) { row in
            let key = LocalPendingChangeLogicalKey.historySession(remoteID: row.remoteID, uid: row.uid)
            if wantedHistoryKeys.contains(key) { targetHistories[key] = row }
        } }
        var copiedChanges: [String: LocalPendingChange] = [:]
        for original in pending {
            let copy = copyChange(original)
            destination.insert(copy)
            copiedChanges[original.changeID] = copy
        }
        for (key, original) in suppliers {
            let changes = (grouped[.supplier] ?? []).filter { $0.logicalKey == key }
            guard changes.isEmpty || changes.contains(where: {
                $0.intendedFingerprintHash == LocalPendingChangeLogicalKey.supplierFingerprintHash(original)
            }) else { throw SyncStoreGenerationError.activationReadBackFailed }
            let target = targetSuppliers[key] ?? Supplier(name: original.name, remoteID: original.remoteID,
                remoteUpdatedAt: original.remoteUpdatedAt, remoteDeletedAt: original.remoteDeletedAt)
            if targetSuppliers[key] == nil { destination.insert(target) }
            for change in changes {
                markConflict(change, current: LocalPendingChangeLogicalKey.supplierFingerprintHash(target), copies: copiedChanges)
                target.name = original.name
                if change.operation == .delete { target.remoteDeletedAt = original.remoteDeletedAt }
            }
            targetSuppliers[key] = target
        }
        for (key, original) in categories {
            let changes = (grouped[.productCategory] ?? []).filter { $0.logicalKey == key }
            guard changes.isEmpty || changes.contains(where: {
                $0.intendedFingerprintHash == LocalPendingChangeLogicalKey.categoryFingerprintHash(original)
            }) else { throw SyncStoreGenerationError.activationReadBackFailed }
            let target = targetCategories[key] ?? ProductCategory(name: original.name, remoteID: original.remoteID,
                remoteUpdatedAt: original.remoteUpdatedAt, remoteDeletedAt: original.remoteDeletedAt)
            if targetCategories[key] == nil { destination.insert(target) }
            for change in changes {
                markConflict(change, current: LocalPendingChangeLogicalKey.categoryFingerprintHash(target), copies: copiedChanges)
                target.name = original.name
                if change.operation == .delete { target.remoteDeletedAt = original.remoteDeletedAt }
            }
            targetCategories[key] = target
        }
        for (key, original) in products {
            let changes = (grouped[.product] ?? []).filter { $0.logicalKey == key }
            guard changes.isEmpty || changes.contains(where: {
                $0.intendedFingerprintHash == LocalPendingChangeLogicalKey.productFingerprintHash(original)
            }) else { throw SyncStoreGenerationError.activationReadBackFailed }
            let target = targetProducts[key] ?? Product(barcode: original.barcode, remoteID: original.remoteID,
                remoteUpdatedAt: original.remoteUpdatedAt, remoteDeletedAt: original.remoteDeletedAt)
            let inserted = targetProducts[key] == nil
            if inserted { destination.insert(target) }
            if inserted && changes.isEmpty {
                // A price mutation cannot resurrect a parent omitted from C.
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            for change in changes {
                if !inserted {
                    markConflict(change, current: LocalPendingChangeLogicalKey.productFingerprintHash(target), copies: copiedChanges)
                    if target.remoteDeletedAt != nil { copiedChanges[change.changeID]?.status = .staleBaseline }
                }
                let fields = Set(change.changedFields)
                let all = inserted || change.operation == .create
                if all || fields.contains("barcode") { target.barcode = original.barcode }
                if all || fields.contains("itemnumber") { target.itemNumber = original.itemNumber }
                if all || fields.contains("productname") { target.productName = original.productName }
                if all || fields.contains("secondproductname") { target.secondProductName = original.secondProductName }
                if all || fields.contains("purchaseprice") { target.purchasePrice = original.purchasePrice }
                if all || fields.contains("retailprice") { target.retailPrice = original.retailPrice }
                if all || fields.contains("stockquantity") { target.stockQuantity = original.stockQuantity }
                if all || fields.contains("suppliername") || fields.contains("supplierremoteid") {
                    target.supplier = original.supplier.flatMap {
                        targetSuppliers[LocalPendingChangeLogicalKey.supplier(remoteID: $0.remoteID, name: $0.name)]
                    }
                }
                if all || fields.contains("categoryname") || fields.contains("categoryremoteid") {
                    target.category = original.category.flatMap {
                        targetCategories[LocalPendingChangeLogicalKey.category(remoteID: $0.remoteID, name: $0.name)]
                    }
                }
                if change.operation == .delete { target.remoteDeletedAt = original.remoteDeletedAt }
            }
            targetProducts[key] = target
        }
        for (key, original) in prices {
            guard let parent = original.product,
                  let targetParent = targetProducts[LocalPendingChangeLogicalKey.product(remoteID: parent.remoteID, barcode: parent.barcode)],
                  targetParent.remoteDeletedAt == nil else { throw SyncStoreGenerationError.activationReadBackFailed }
            if let target = targetPrices[key] {
                guard LocalPendingChangeLogicalKey.productPriceFingerprintHash(target)
                    == LocalPendingChangeLogicalKey.productPriceFingerprintHash(original) else {
                    throw SyncStoreGenerationError.activationReadBackFailed
                }
            } else {
                destination.insert(ProductPrice(remoteID: original.remoteID, type: original.type, price: original.price,
                    effectiveAt: original.effectiveAt, source: original.source, note: original.note,
                    createdAt: original.createdAt, product: targetParent))
            }
        }
        for (key, original) in histories {
            let target = targetHistories[key] ?? HistoryEntry(id: original.id, uid: original.uid)
            if targetHistories[key] == nil { destination.insert(target) }
            if targetHistories[key] != nil && target.remotePayloadFingerprint != original.remotePayloadFingerprint {
                let historyChanges = (grouped[.historySession] ?? []).filter { $0.logicalKey == key }
                let explainedByOriginalAttempt = try historyChanges.contains { change in
                    guard let sealed = sealedByChangeID[change.changeID],
                          let fingerprint = target.remotePayloadFingerprint else { return false }
                    return try HistorySessionPushService.sealedAttemptExplainsHistoryFingerprint(
                        fingerprint, entry: sealed, change: change, localHistory: original, scope: scope)
                }
                if !explainedByOriginalAttempt {
                    for change in historyChanges {
                        copiedChanges[change.changeID]?.status = .staleBaseline
                    }
                }
            }
            copyHistory(original, to: target)
        }
        for change in pending {
            let found: Bool
            switch change.entityKind {
            case .supplier: found = suppliers[change.logicalKey] != nil
            case .productCategory: found = categories[change.logicalKey] != nil
            case .product: found = products[change.logicalKey] != nil
            case .productPrice: found = prices[change.logicalKey] != nil
            case .historySession: found = histories[change.logicalKey] != nil
            case .importBatch: found = false // A cap marker cannot prove an unbounded import's complete intent.
            }
            guard found else { throw SyncStoreGenerationError.activationReadBackFailed }
        }
        for entry in outbox {
            guard entry.ownerUserID == owner, entry.storeId == scope.storeIdentity.storeId,
                  entry.localStoreId == scope.storeIdentity.localStoreId,
                  entry.schemaVersion == scope.storeIdentity.schemaVersion,
                  entry.syncProtocolVersion == scope.storeIdentity.syncProtocolVersion,
                  entry.storeEpoch == scope.storeIdentity.storeEpoch,
                  SyncEventOutboxStatus(rawValue: entry.statusRaw) != nil else {
                throw SyncStoreGenerationError.activationReadBackFailed
            }
            if LocalPendingBusinessAttemptStore.isSealed(entry) {
                try LocalPendingBusinessAttemptStore.validate(entry, scope: scope)
            } else {
                _ = try SyncEventOutboxPayloadCodec.makeRecordRequestForReplay(from: entry)
            }
            destination.insert(copyOutbox(entry))
        }
        for key in supplierKeys {
            if let row = targetSuppliers[key] {
                try LocalCatalogBodyProofStore.recordOverlayBody(row, context: destination, scope: scope, generationID: stagingGenerationID)
            }
        }
        for key in categoryKeys {
            if let row = targetCategories[key] {
                try LocalCatalogBodyProofStore.recordOverlayBody(row, context: destination, scope: scope, generationID: stagingGenerationID)
            }
        }
        for key in productKeys {
            if let row = targetProducts[key] {
                try LocalCatalogBodyProofStore.recordOverlayBody(row, context: destination, scope: scope, generationID: stagingGenerationID)
            }
        }
        try destination.save()
        let readBack = ModelContext(staging)
        var readBackChanges = FetchDescriptor<LocalPendingChange>()
        readBackChanges.fetchLimit = limit + 1
        let saved = try readBack.fetch(readBackChanges)
        guard saved.count == pending.count else { throw SyncStoreGenerationError.activationReadBackFailed }
        guard Set(saved.map(\.changeID)).count == saved.count else { throw SyncStoreGenerationError.activationReadBackFailed }
        let savedByID = Dictionary(uniqueKeysWithValues: saved.map { ($0.changeID, $0) })
        for expected in copiedChanges.values {
            guard let actual = savedByID[expected.changeID], LocalPendingChangeCASToken(expected).matches(actual),
                  expected.createdAt == actual.createdAt else { throw SyncStoreGenerationError.activationReadBackFailed }
        }
    }

    private static func scan<Model: PersistentModel>(
        _ type: Model.Type, context: ModelContext, sort: [SortDescriptor<Model>], visit: (Model) throws -> Void
    ) throws {
        var offset = 0
        while true {
            try Task.checkCancellation()
            var descriptor = FetchDescriptor<Model>(sortBy: sort)
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = ShopSyncRecoveryLimits.verificationBatchSize
            let batch = try context.fetch(descriptor)
            for row in batch { try visit(row) }
            guard batch.count == descriptor.fetchLimit else { return }
            offset += batch.count
        }
    }

    private static func markConflict(
        _ change: LocalPendingChange, current: String, copies: [String: LocalPendingChange]
    ) {
        guard change.operation != .create,
              current != change.baselineFingerprintHash,
              current != change.intendedFingerprintHash else { return }
        copies[change.changeID]?.status = .staleBaseline
    }

    private static func copyChange(_ row: LocalPendingChange) -> LocalPendingChange {
        let copy = LocalPendingChange(changeID: UUID(uuidString: row.changeID)!, entityKind: row.entityKind,
            operation: row.operation, origin: row.origin, logicalKey: row.logicalKey)
        copy.changeID = row.changeID
        copy.recordSchemaVersion = row.recordSchemaVersion
        copy.ownerUserID = row.ownerUserID; copy.ownerHash = row.ownerHash
        copy.storeId = row.storeId; copy.localStoreId = row.localStoreId
        copy.syncProtocolVersion = row.syncProtocolVersion; copy.schemaVersion = row.schemaVersion; copy.storeEpoch = row.storeEpoch
        copy.statusRaw = row.statusRaw; copy.changedFieldsRaw = row.changedFieldsRaw
        copy.baselineFingerprintHash = row.baselineFingerprintHash; copy.intendedFingerprintHash = row.intendedFingerprintHash
        copy.baseRemoteUpdatedAt = row.baseRemoteUpdatedAt; copy.baseVersion = row.baseVersion; copy.baseEventId = row.baseEventId
        copy.idempotencyKey = row.idempotencyKey; copy.entityRemoteIDRaw = row.entityRemoteIDRaw
        copy.createdAt = row.createdAt; copy.updatedAt = row.updatedAt; copy.lastAttemptAt = row.lastAttemptAt
        copy.supersededByChangeID = row.supersededByChangeID
        return copy
    }

    private static func copyHistory(_ row: HistoryEntry, to copy: HistoryEntry) {
        copy.id = row.id; copy.uid = row.uid; copy.timestamp = row.timestamp; copy.isManualEntry = row.isManualEntry
        copy.dataJSON = row.dataJSON; copy.originalDataJSON = row.originalDataJSON
        copy.editableJSON = row.editableJSON; copy.completeJSON = row.completeJSON
        copy.hasPersistedJSONDecodeFault = row.hasPersistedJSONDecodeFault
        copy.title = row.title; copy.supplier = row.supplier; copy.category = row.category
        copy.totalItems = row.totalItems; copy.orderTotal = row.orderTotal; copy.paymentTotal = row.paymentTotal
        copy.missingItems = row.missingItems; copy.syncStatus = row.syncStatus; copy.wasExported = row.wasExported
        copy.remoteID = row.remoteID; copy.remoteUpdatedAt = row.remoteUpdatedAt; copy.remoteDeletedAt = row.remoteDeletedAt
        copy.remotePayloadFingerprint = row.remotePayloadFingerprint
        copy.localChangeRevision = row.localChangeRevision; copy.lastSyncedLocalRevision = row.lastSyncedLocalRevision
        copy.ownerUserID = row.ownerUserID; copy.storeID = row.storeID; copy.shopID = row.shopID
    }

    private static func copyOutbox(_ row: SyncEventOutboxEntry) -> SyncEventOutboxEntry {
        let copy = SyncEventOutboxEntry(id: row.id, ownerUserID: row.ownerUserID,
            clientEventID: row.clientEventID, domain: row.domain, eventType: row.eventType,
            changedCount: row.changedCount, entityIDsShape: row.entityIDsShape, metadataShape: row.metadataShape,
            nextRetryAt: row.nextRetryAt, createdAt: row.createdAt, updatedAt: row.updatedAt)
        copy.storeId = row.storeId; copy.localStoreId = row.localStoreId
        copy.syncProtocolVersion = row.syncProtocolVersion; copy.schemaVersion = row.schemaVersion; copy.storeEpoch = row.storeEpoch
        copy.batchID = row.batchID; copy.entityIDsPayloadJSON = row.entityIDsPayloadJSON; copy.metadataPayloadJSON = row.metadataPayloadJSON
        copy.statusRaw = row.statusRaw; copy.attemptCount = row.attemptCount; copy.maxAttempts = row.maxAttempts
        copy.lastAttemptAt = row.lastAttemptAt; copy.lastErrorCode = row.lastErrorCode; copy.lastErrorKindRaw = row.lastErrorKindRaw
        copy.lastErrorMessageSanitized = row.lastErrorMessageSanitized; copy.sentAt = row.sentAt; copy.sourceDeviceID = row.sourceDeviceID
        return copy
    }
}
