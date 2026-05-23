import Foundation
import SwiftData

protocol SupabaseSyncEventIncrementalFetching: Sendable {
    func fetchSyncEventsAfter(ownerUserID: UUID, afterID: Int64, limit: Int) async throws -> [RemoteSyncEventRow]
}

nonisolated enum SupabaseSyncEventIncrementalLimits {
    static let maximumLimit = 200
}

nonisolated enum RuntimeSyncExecutionType: String, Sendable, Equatable {
    case eventIncremental = "EVENT_INCREMENTAL"
    case checkpointIncremental = "CHECKPOINT_INCREMENTAL"
    case lightReconcile = "LIGHT_RECONCILE"
    case fullPullBootstrap = "FULL_PULL_BOOTSTRAP"
    case fullPullRecovery = "FULL_PULL_RECOVERY"
}

nonisolated struct SupabaseSyncEventIncrementalApplySummary: Sendable, Equatable {
    var syncType: RuntimeSyncExecutionType
    var eventsFetched: Int = 0
    var eventsProcessed: Int = 0
    var watermarkBefore: Int64 = 0
    var watermarkAfter: Int64 = 0
    var targetedSuppliersFetched: Int = 0
    var targetedCategoriesFetched: Int = 0
    var targetedProductsFetched: Int = 0
    var targetedProductPricesFetched: Int = 0
    var targetedHistoryFetched: Int = 0
    var productsInserted: Int = 0
    var productsUpdated: Int = 0
    var productsTombstoned: Int = 0
    var suppliersCreated: Int = 0
    var categoriesCreated: Int = 0
    var productPricesInserted: Int = 0
    var productPriceIdentityLinked: Int = 0
    var productPricesMissingRemotePruned: Int = 0
    var historyInserted: Int = 0
    var historyUpdated: Int = 0
    var historyMissingRemoteTombstoned: Int = 0
    var suppliersMissingRemoteTombstoned: Int = 0
    var categoriesMissingRemoteTombstoned: Int = 0
    var requiresFullRecoveryReason: String?
    var eventPageFetchMs: Int = 0
    var catalogFetchMs: Int = 0
    var catalogApplyMs: Int = 0
    var productPriceFetchMs: Int = 0
    var productPriceApplyMs: Int = 0
    var historyFetchMs: Int = 0
    var historyApplyMs: Int = 0
    var totalElapsedMs: Int = 0

    static func noWork(watermark: Int64) -> Self {
        SupabaseSyncEventIncrementalApplySummary(
            syncType: .checkpointIncremental,
            watermarkBefore: watermark,
            watermarkAfter: watermark
        )
    }

    var requiresFullRecovery: Bool {
        requiresFullRecoveryReason != nil
    }

    var totalApplied: Int {
        productsInserted
            + productsUpdated
            + productsTombstoned
            + suppliersCreated
            + categoriesCreated
            + productPricesInserted
            + productPriceIdentityLinked
            + productPricesMissingRemotePruned
            + historyInserted
            + historyUpdated
            + historyMissingRemoteTombstoned
            + suppliersMissingRemoteTombstoned
            + categoriesMissingRemoteTombstoned
    }
}

nonisolated struct SyncEventIncrementalDomainApplyService {
    private let eventFetcher: any SupabaseSyncEventIncrementalFetching
    private let inventoryService: SupabaseInventoryService
    private let defaults: UserDefaults
    private let watermarkStore: WatermarkStore
    private let limit: Int

    init(
        eventFetcher: any SupabaseSyncEventIncrementalFetching,
        inventoryService: SupabaseInventoryService,
        defaults: UserDefaults = .standard,
        watermarkStore: WatermarkStore? = nil,
        limit: Int = 50
    ) {
        self.eventFetcher = eventFetcher
        self.inventoryService = inventoryService
        self.defaults = defaults
        self.watermarkStore = watermarkStore ?? WatermarkStore(defaults: defaults)
        self.limit = max(1, min(limit, SupabaseSyncEventIncrementalLimits.maximumLimit))
    }

    func applyNextEvents(
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        isAuthenticated: Bool
    ) async throws -> SupabaseSyncEventIncrementalApplySummary {
        let totalStarted = mcNowMillis()
        let watermarkScope = self.watermarkScope(ownerUserID: ownerUserID)
        let watermarkBefore = watermarkStore.watermark(for: watermarkScope)
        let eventFetchStarted = mcNowMillis()
        let events = try await eventFetcher.fetchSyncEventsAfter(
            ownerUserID: ownerUserID,
            afterID: watermarkBefore,
            limit: limit
        )
        let eventFetchMs = mcNowMillis() - eventFetchStarted
        guard !events.isEmpty else {
            guard shouldRunLightReconcile(ownerUserID: ownerUserID) else {
                var summary = SupabaseSyncEventIncrementalApplySummary.noWork(watermark: watermarkBefore)
                summary.eventPageFetchMs = eventFetchMs
                summary.totalElapsedMs = mcNowMillis() - totalStarted
                return summary
            }
            var summary = try await recoverCanonicalDriftIfNeeded(
                ownerUserID: ownerUserID,
                modelContainer: modelContainer,
                isAuthenticated: isAuthenticated,
                watermark: watermarkBefore
            )
            summary.eventPageFetchMs = eventFetchMs
            summary.totalElapsedMs = mcNowMillis() - totalStarted
            return summary
        }

        var summary = SupabaseSyncEventIncrementalApplySummary(
            syncType: .eventIncremental,
            eventsFetched: events.count,
            watermarkBefore: watermarkBefore,
            watermarkAfter: watermarkBefore
        )
        summary.eventPageFetchMs = eventFetchMs

        let sortedEvents = events.sorted { $0.id < $1.id }
        var eventIDs = extractEntityIDs(from: sortedEvents)
        summary.eventsProcessed = sortedEvents.count
        summary.watermarkAfter = sortedEvents.map(\.id).max() ?? watermarkBefore

        guard eventIDs.hasWork else {
            watermarkStore.save(summary.watermarkAfter, for: watermarkScope)
            return summary
        }

        guard !eventIDs.hasUnrecoverableGap else {
            summary.requiresFullRecoveryReason = "sync_event_missing_entity_ids"
            return summary
        }

        let priceRows: [RemoteInventoryProductPriceRow]
        if eventIDs.hasPriceWork {
            let priceFetchStarted = mcNowMillis()
            priceRows = try await inventoryService.fetchProductPricesByIDs(
                ownerUserID: ownerUserID,
                priceIDs: eventIDs.priceIDs
            )
            summary.productPriceFetchMs = mcNowMillis() - priceFetchStarted
            summary.targetedProductPricesFetched = priceRows.count
            eventIDs.productIDs.formUnion(priceRows.map(\.productID))
        } else {
            priceRows = []
        }

        var remoteActiveProductIDsForPrices: Set<UUID>?
        if eventIDs.hasCatalogWork {
            let catalogResult = try await applyCatalogWork(
                eventIDs: eventIDs,
                ownerUserID: ownerUserID,
                modelContainer: modelContainer,
                isAuthenticated: isAuthenticated
            )
            summary.targetedSuppliersFetched = catalogResult.targetedSuppliersFetched
            summary.targetedCategoriesFetched = catalogResult.targetedCategoriesFetched
            summary.targetedProductsFetched = catalogResult.targetedProductsFetched
            summary.productsInserted = catalogResult.productsInserted
            summary.productsUpdated = catalogResult.productsUpdated
            summary.productsTombstoned = catalogResult.productsTombstoned
            summary.suppliersCreated = catalogResult.suppliersCreated
            summary.categoriesCreated = catalogResult.categoriesCreated
            summary.productsTombstoned += catalogResult.productsMissingRemoteTombstoned
            summary.suppliersMissingRemoteTombstoned = catalogResult.suppliersMissingRemoteTombstoned
            summary.categoriesMissingRemoteTombstoned = catalogResult.categoriesMissingRemoteTombstoned
            summary.catalogFetchMs = catalogResult.catalogFetchMs
            summary.catalogApplyMs = catalogResult.catalogApplyMs
            remoteActiveProductIDsForPrices = catalogResult.remoteActiveProductIDs
        }

        let applicablePriceRows: [RemoteInventoryProductPriceRow]
        if let remoteActiveProductIDsForPrices {
            applicablePriceRows = priceRows.filter { remoteActiveProductIDsForPrices.contains($0.productID) }
        } else {
            applicablePriceRows = priceRows
        }
        if !applicablePriceRows.isEmpty {
            let priceApplyStarted = mcNowMillis()
            let priceResult = try await applyProductPriceWork(
                priceRows: applicablePriceRows,
                ownerUserID: ownerUserID,
                modelContainer: modelContainer
            )
            summary.productPriceApplyMs = mcNowMillis() - priceApplyStarted
            summary.productPricesInserted = priceResult.inserted
            summary.productPriceIdentityLinked = priceResult.remoteIdentityLinked
        }
        if eventIDs.hasPriceWork {
            let missingPriceIDs = eventIDs.priceIDs.subtracting(Set(priceRows.map(\.id)))
            if !missingPriceIDs.isEmpty {
                summary.productPricesMissingRemotePruned = try await pruneMissingRemotePrices(
                    priceIDs: missingPriceIDs,
                    ownerUserID: ownerUserID,
                    modelContainer: modelContainer
                )
            }
        }

        if eventIDs.hasHistoryWork {
            let historyFetchStarted = mcNowMillis()
            let historyRows = try await inventoryService.fetchSharedSheetSessionsByIDs(
                ownerUserID: ownerUserID,
                sessionIDs: eventIDs.sessionIDs
            )
            summary.historyFetchMs = mcNowMillis() - historyFetchStarted
            summary.targetedHistoryFetched = historyRows.count
            let historyApplyStarted = mcNowMillis()
            let historyResult = try await Task.detached(priority: .utility) {
                let context = ModelContext(modelContainer)
                let service = HistorySessionSyncService(remote: inventoryService)
                let result = try service.applyRemoteSharedSheetSessions(
                    historyRows,
                    ownerUserID: ownerUserID,
                    context: context
                )
                if result.insertedCount + result.updatedCount > 0 {
                    try context.save()
                }
                return result
            }.value
            summary.historyApplyMs = mcNowMillis() - historyApplyStarted
            summary.historyInserted = historyResult.insertedCount
            summary.historyUpdated = historyResult.updatedCount
            let missingSessionIDs = eventIDs.sessionIDs.subtracting(Set(historyRows.map(\.remoteID)))
            if !missingSessionIDs.isEmpty {
                summary.historyMissingRemoteTombstoned = try await tombstoneMissingRemoteHistory(
                    sessionIDs: missingSessionIDs,
                    ownerUserID: ownerUserID,
                    modelContainer: modelContainer
                )
            }
        }

        watermarkStore.save(summary.watermarkAfter, for: watermarkScope)
        summary.totalElapsedMs = mcNowMillis() - totalStarted
        return summary
    }

    private func applyCatalogWork(
        eventIDs: SyncEventEntityIDSet,
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        isAuthenticated: Bool
    ) async throws -> (
        targetedSuppliersFetched: Int,
        targetedCategoriesFetched: Int,
        targetedProductsFetched: Int,
        productsInserted: Int,
        productsUpdated: Int,
        productsTombstoned: Int,
        suppliersCreated: Int,
        categoriesCreated: Int,
        productsMissingRemoteTombstoned: Int,
        suppliersMissingRemoteTombstoned: Int,
        categoriesMissingRemoteTombstoned: Int,
        remoteActiveProductIDs: Set<UUID>,
        catalogFetchMs: Int,
        catalogApplyMs: Int
    ) {
        let catalogFetchStarted = mcNowMillis()
        let firstFetch = try await inventoryService.fetchCatalogByIDs(
            supplierIDs: eventIDs.supplierIDs,
            categoryIDs: eventIDs.categoryIDs,
            productIDs: eventIDs.productIDs
        )
        let relatedSupplierIDs = Set(firstFetch.products.compactMap(\.supplierID))
            .subtracting(Set(firstFetch.suppliers.map(\.id)))
        let relatedCategoryIDs = Set(firstFetch.products.compactMap(\.categoryID))
            .subtracting(Set(firstFetch.categories.map(\.id)))
        let relatedFetch = try await inventoryService.fetchCatalogByIDs(
            supplierIDs: relatedSupplierIDs,
            categoryIDs: relatedCategoryIDs,
            productIDs: []
        )
        let catalogFetchMs = mcNowMillis() - catalogFetchStarted

        let suppliers = mergeRows(firstFetch.suppliers, relatedFetch.suppliers)
        let categories = mergeRows(firstFetch.categories, relatedFetch.categories)
        let products = firstFetch.products
        let missingTargetSupplierIDs = eventIDs.supplierIDs.subtracting(Set(suppliers.map(\.id)))
        let missingTargetCategoryIDs = eventIDs.categoryIDs.subtracting(Set(categories.map(\.id)))
        let missingTargetProductIDs = eventIDs.productIDs.subtracting(Set(products.map(\.id)))

        let catalogApplyStarted = mcNowMillis()
        let result = try await applyTargetedCatalogRows(
            suppliers: suppliers,
            categories: categories,
            products: products,
            ownerUserID: ownerUserID,
            modelContainer: modelContainer
        )
        let catalogApplyMs = mcNowMillis() - catalogApplyStarted
        let missingResult = try await tombstoneMissingRemoteCatalog(
            supplierIDs: missingTargetSupplierIDs,
            categoryIDs: missingTargetCategoryIDs,
            productIDs: missingTargetProductIDs,
            ownerUserID: ownerUserID,
            modelContainer: modelContainer
        )

        return (
            suppliers.count,
            categories.count,
            products.count,
            result.productsInserted,
            result.productsUpdated,
            result.productsTombstoned,
            result.suppliersCreated,
            result.categoriesCreated,
            missingResult.products,
            missingResult.suppliers,
            missingResult.categories,
            Set(products
                .filter { SupabasePullPreviewNormalizer.semanticString($0.deletedAt) == nil }
                .map(\.id)),
            catalogFetchMs,
            catalogApplyMs
        )
    }

    private func applyTargetedCatalogRows(
        suppliers: [RemoteInventorySupplierRow],
        categories: [RemoteInventoryCategoryRow],
        products: [RemoteInventoryProductRow],
        ownerUserID: UUID,
        modelContainer: ModelContainer
    ) async throws -> TargetedCatalogApplyResult {
        try await Task.detached(priority: .userInitiated) {
            let context = ModelContext(modelContainer)
            let protected = try pendingRemoteIDs(context: context, ownerUserID: ownerUserID)
            var result = TargetedCatalogApplyResult()
            var supplierCache: [UUID: Supplier] = [:]
            var categoryCache: [UUID: ProductCategory] = [:]

            for row in suppliers where !protected.suppliers.contains(row.id) {
                let applied = try applyTargetedSupplier(row, context: context)
                if let supplier = applied.supplier {
                    supplierCache[row.id] = supplier
                }
                result.suppliersCreated += applied.created ? 1 : 0
            }
            for row in categories where !protected.categories.contains(row.id) {
                let applied = try applyTargetedCategory(row, context: context)
                if let category = applied.category {
                    categoryCache[row.id] = category
                }
                result.categoriesCreated += applied.created ? 1 : 0
            }

            for row in products where !protected.products.contains(row.id) {
                let supplier = try row.supplierID.flatMap { remoteID -> Supplier? in
                    if let cached = supplierCache[remoteID] { return cached }
                    if let existing = try fetchSupplier(remoteID: remoteID, context: context) {
                        supplierCache[remoteID] = existing
                        return existing
                    }
                    return nil
                }
                let category = try row.categoryID.flatMap { remoteID -> ProductCategory? in
                    if let cached = categoryCache[remoteID] { return cached }
                    if let existing = try fetchCategory(remoteID: remoteID, context: context) {
                        categoryCache[remoteID] = existing
                        return existing
                    }
                    return nil
                }
                let applied = try applyTargetedProduct(
                    row,
                    supplier: supplier,
                    category: category,
                    context: context
                )
                result.productsInserted += applied.inserted ? 1 : 0
                result.productsUpdated += applied.updated ? 1 : 0
                result.productsTombstoned += applied.tombstoned ? 1 : 0
            }

            if result.totalMutations > 0 {
                try context.save()
            }
            return result
        }.value
    }

    private func tombstoneMissingRemoteCatalog(
        supplierIDs: Set<UUID>,
        categoryIDs: Set<UUID>,
        productIDs: Set<UUID>,
        ownerUserID: UUID,
        modelContainer: ModelContainer
    ) async throws -> (suppliers: Int, categories: Int, products: Int) {
        guard !supplierIDs.isEmpty || !categoryIDs.isEmpty || !productIDs.isEmpty else {
            return (0, 0, 0)
        }
        return try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            let protected = try pendingRemoteIDs(context: context, ownerUserID: ownerUserID)
            let now = Date()
            var suppliers = 0
            var categories = 0
            var products = 0

            for remoteID in supplierIDs where !protected.suppliers.contains(remoteID) {
                guard let supplier = try fetchSupplier(remoteID: remoteID, context: context),
                      supplier.remoteDeletedAt == nil else { continue }
                supplier.remoteDeletedAt = now
                try detachSupplier(remoteID: remoteID, context: context)
                suppliers += 1
            }
            for remoteID in categoryIDs where !protected.categories.contains(remoteID) {
                guard let category = try fetchCategory(remoteID: remoteID, context: context),
                      category.remoteDeletedAt == nil else { continue }
                category.remoteDeletedAt = now
                try detachCategory(remoteID: remoteID, context: context)
                categories += 1
            }
            for remoteID in productIDs where !protected.products.contains(remoteID) {
                guard let product = try fetchProduct(remoteID: remoteID, context: context),
                      product.remoteDeletedAt == nil else { continue }
                product.remoteDeletedAt = now
                product.supplier = nil
                product.category = nil
                products += 1
            }
            if suppliers + categories + products > 0 {
                try context.save()
            }
            return (suppliers, categories, products)
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

    private func tombstoneMissingRemoteHistory(
        sessionIDs: Set<UUID>,
        ownerUserID: UUID,
        modelContainer: ModelContainer
    ) async throws -> Int {
        guard !sessionIDs.isEmpty else { return 0 }
        return try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            let protected = try pendingRemoteIDs(context: context, ownerUserID: ownerUserID)
            let now = Date()
            var tombstoned = 0
            for remoteID in sessionIDs where !protected.history.contains(remoteID) {
                guard let entry = try fetchHistory(remoteID: remoteID, context: context),
                      entry.remoteDeletedAt == nil else { continue }
                entry.remoteDeletedAt = now
                entry.remoteUpdatedAt = entry.remoteUpdatedAt ?? now
                entry.syncStatus = .syncedSuccessfully
                entry.lastSyncedLocalRevision = entry.localChangeRevision
                tombstoned += 1
            }
            if tombstoned > 0 {
                try context.save()
            }
            return tombstoned
        }.value
    }

    private func applyProductPriceWork(
        priceRows: [RemoteInventoryProductPriceRow],
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

    private func recoverCanonicalDriftIfNeeded(
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        isAuthenticated: Bool,
        watermark: Int64
    ) async throws -> SupabaseSyncEventIncrementalApplySummary {
        let remoteCounts = try await inventoryService.fetchReconciliationRemoteCounts()
        let localCounts = try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            return try LocalDatabasePublicSummary.makeReconciliationAware(context: context)
        }.value
        let drift = SyncCountDriftReport.compare(local: localCounts, remote: remoteCounts)
        recordCanonicalDriftDiagnostics(drift)
        guard !drift.isAligned else {
            return SupabaseSyncEventIncrementalApplySummary(
                syncType: .lightReconcile,
                watermarkBefore: watermark,
                watermarkAfter: watermark
            )
        }

        var summary = SupabaseSyncEventIncrementalApplySummary(
            syncType: .lightReconcile,
            watermarkBefore: watermark,
            watermarkAfter: watermark
        )
        summary.requiresFullRecoveryReason = "canonical_drift_detected"
        return summary
    }

    private func recordCanonicalDriftDiagnostics(_ drift: SyncCountDriftReport) {
        #if DEBUG
        defaults.set(drift.local.products, forKey: "task114.runtime.reconcile.local.products")
        defaults.set(drift.local.suppliers, forKey: "task114.runtime.reconcile.local.suppliers")
        defaults.set(drift.local.categories, forKey: "task114.runtime.reconcile.local.categories")
        defaults.set(drift.local.productPrices, forKey: "task114.runtime.reconcile.local.productPrices")
        defaults.set(drift.local.historySessions, forKey: "task114.runtime.reconcile.local.historySessions")
        defaults.set(drift.remote.products, forKey: "task114.runtime.reconcile.remote.products")
        defaults.set(drift.remote.suppliers, forKey: "task114.runtime.reconcile.remote.suppliers")
        defaults.set(drift.remote.categories, forKey: "task114.runtime.reconcile.remote.categories")
        defaults.set(drift.remote.productPrices, forKey: "task114.runtime.reconcile.remote.productPrices")
        defaults.set(drift.remote.historySessions, forKey: "task114.runtime.reconcile.remote.historySessions")
        defaults.set(
            drift.mismatches.map(\.rawValue).joined(separator: ","),
            forKey: "task114.runtime.reconcile.mismatches"
        )
        #endif
    }

    private func watermarkKey(ownerUserID: UUID) -> String {
        Self.watermarkKey(ownerUserID: ownerUserID)
    }

    static func watermarkKey(ownerUserID: UUID) -> String {
        WatermarkStore.legacyWatermarkKey(ownerUserID: ownerUserID)
    }

    static func markWatermarkAfterFullRecovery(
        ownerUserID: UUID,
        watermark: Int64,
        defaults: UserDefaults = .standard
    ) {
        let store = WatermarkStore(defaults: defaults)
        store.save(watermark, for: WatermarkStore.Scope(ownerUserID: ownerUserID, storeIdentity: .anonymous))
        defaults.set(Int(watermark), forKey: watermarkKey(ownerUserID: ownerUserID))
    }

    private func watermarkScope(ownerUserID: UUID) -> WatermarkStore.Scope {
        let binding = AccountBindingStore(defaults: defaults).currentBinding
        return WatermarkStore.Scope(
            ownerUserID: ownerUserID,
            storeIdentity: binding?.storeIdentity ?? .anonymous
        )
    }

    private func lightReconcileKey(ownerUserID: UUID) -> String {
        "task115.syncEvents.lightReconcile.lastAt.\(AccountBindingStore.accountHash(for: ownerUserID))"
    }

    private func shouldRunLightReconcile(ownerUserID: UUID) -> Bool {
        let key = lightReconcileKey(ownerUserID: ownerUserID)
        let now = Date().timeIntervalSince1970
        let minimumIntervalSeconds = 15.0
        if let last = defaults.object(forKey: key) as? Double,
           now - last < minimumIntervalSeconds {
            return false
        }
        defaults.set(now, forKey: key)
        return true
    }

    private func extractEntityIDs(from events: [RemoteSyncEventRow]) -> SyncEventEntityIDSet {
        events.reduce(into: SyncEventEntityIDSet()) { result, event in
            guard event.domain == "catalog" || event.domain == "prices" || event.domain == "history" else { return }
            let ids = SyncEventEntityIDSet(json: event.entityIDs)
            if event.domain == "catalog", ids.isEmpty, event.changedCount > 0 {
                result.hasUnrecoverableCatalogGap = true
            }
            if event.domain == "history", ids.sessionIDs.isEmpty, event.changedCount > 0 {
                result.hasUnrecoverableHistoryGap = true
            }
            if event.domain == "prices", ids.priceIDs.isEmpty, event.changedCount > 0 {
                result.hasUnrecoverablePriceGap = true
            }
            result.supplierIDs.formUnion(ids.supplierIDs)
            result.categoryIDs.formUnion(ids.categoryIDs)
            result.productIDs.formUnion(ids.productIDs)
            result.priceIDs.formUnion(ids.priceIDs)
            result.sessionIDs.formUnion(ids.sessionIDs)
        }
    }

    private func mergeRows<Row: Identifiable>(_ lhs: [Row], _ rhs: [Row]) -> [Row] where Row.ID == UUID {
        Array(Dictionary(uniqueKeysWithValues: (lhs + rhs).map { ($0.id, $0) }).values)
    }
}

nonisolated struct SupabaseSyncEventIncrementalApplyService {
    private let domainService: SyncEventIncrementalDomainApplyService

    init(
        eventFetcher: any SupabaseSyncEventIncrementalFetching,
        inventoryService: SupabaseInventoryService,
        defaults: UserDefaults = .standard,
        watermarkStore: WatermarkStore? = nil,
        limit: Int = 50
    ) {
        self.domainService = SyncEventIncrementalDomainApplyService(
            eventFetcher: eventFetcher,
            inventoryService: inventoryService,
            defaults: defaults,
            watermarkStore: watermarkStore,
            limit: limit
        )
    }

    func applyNextEvents(
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        isAuthenticated: Bool
    ) async throws -> SupabaseSyncEventIncrementalApplySummary {
        try await domainService.applyNextEvents(
            ownerUserID: ownerUserID,
            modelContainer: modelContainer,
            isAuthenticated: isAuthenticated
        )
    }

    static func watermarkKey(ownerUserID: UUID) -> String {
        SyncEventIncrementalDomainApplyService.watermarkKey(ownerUserID: ownerUserID)
    }

    static func markWatermarkAfterFullRecovery(
        ownerUserID: UUID,
        watermark: Int64,
        defaults: UserDefaults = .standard
    ) {
        SyncEventIncrementalDomainApplyService.markWatermarkAfterFullRecovery(
            ownerUserID: ownerUserID,
            watermark: watermark,
            defaults: defaults
        )
    }
}

nonisolated private struct IncrementalApplyProtectedRemoteIDs: Sendable {
    var suppliers: Set<UUID> = []
    var categories: Set<UUID> = []
    var products: Set<UUID> = []
    var prices: Set<UUID> = []
    var history: Set<UUID> = []
}

nonisolated private struct TargetedCatalogApplyResult: Sendable {
    var productsInserted = 0
    var productsUpdated = 0
    var productsTombstoned = 0
    var suppliersCreated = 0
    var categoriesCreated = 0

    var totalMutations: Int {
        productsInserted + productsUpdated + productsTombstoned + suppliersCreated + categoriesCreated
    }
}

nonisolated private struct TargetedProductPriceLogicalKey: Hashable {
    let productID: UUID
    let type: String
    let effectiveAt: String
}

nonisolated private struct TargetedProductPriceCurrentInfo {
    var canonicalPrice: ProductPriceCanonicalAmount
    var remoteID: UUID?
    var productPriceIDToLink: PersistentIdentifier?

    init(
        canonicalPrice: ProductPriceCanonicalAmount,
        remoteID: UUID?,
        productPriceIDToLink: PersistentIdentifier? = nil
    ) {
        self.canonicalPrice = canonicalPrice
        self.remoteID = remoteID
        self.productPriceIDToLink = productPriceIDToLink
    }
}

nonisolated private func pendingRemoteIDs(
    context: ModelContext,
    ownerUserID: UUID
) throws -> IncrementalApplyProtectedRemoteIDs {
    let owner = ownerUserID.uuidString.lowercased()
    let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
    var protected = IncrementalApplyProtectedRemoteIDs()
    for change in changes where !change.status.isTerminal && (change.ownerUserID == nil || change.ownerUserID == owner) {
        let remoteID = change.entityRemoteID ?? remoteIDFromLogicalKey(change.logicalKey)
        guard let remoteID else { continue }
        switch change.entityKind {
        case .supplier:
            protected.suppliers.insert(remoteID)
        case .productCategory:
            protected.categories.insert(remoteID)
        case .product:
            protected.products.insert(remoteID)
        case .productPrice:
            protected.prices.insert(remoteID)
        case .historySession:
            protected.history.insert(remoteID)
        case .importBatch:
            break
        }
    }
    return protected
}

nonisolated private func remoteIDFromLogicalKey(_ key: String) -> UUID? {
    let parts = key.split(separator: ":")
    guard parts.count == 3, parts[1] == "remote" else { return nil }
    return UUID(uuidString: String(parts[2]))
}

nonisolated private func applyTargetedSupplier(
    _ row: RemoteInventorySupplierRow,
    context: ModelContext
) throws -> (supplier: Supplier?, created: Bool) {
    let deletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    let updatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
    guard let name = SupabasePullPreviewNormalizer.semanticString(row.name) else {
        return (nil, false)
    }
    if let supplier = try fetchSupplier(remoteID: row.id, context: context)
        ?? fetchSupplier(name: name, context: context) {
        supplier.remoteID = row.id
        supplier.remoteUpdatedAt = updatedAt
        supplier.remoteDeletedAt = deletedAt
        return (deletedAt == nil ? supplier : nil, false)
    }
    guard deletedAt == nil else { return (nil, false) }
    let supplier = Supplier(name: name, remoteID: row.id, remoteUpdatedAt: updatedAt)
    context.insert(supplier)
    return (supplier, true)
}

nonisolated private func applyTargetedCategory(
    _ row: RemoteInventoryCategoryRow,
    context: ModelContext
) throws -> (category: ProductCategory?, created: Bool) {
    let deletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    let updatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
    guard let name = SupabasePullPreviewNormalizer.semanticString(row.name) else {
        return (nil, false)
    }
    if let category = try fetchCategory(remoteID: row.id, context: context)
        ?? fetchCategory(name: name, context: context) {
        category.remoteID = row.id
        category.remoteUpdatedAt = updatedAt
        category.remoteDeletedAt = deletedAt
        return (deletedAt == nil ? category : nil, false)
    }
    guard deletedAt == nil else { return (nil, false) }
    let category = ProductCategory(name: name, remoteID: row.id, remoteUpdatedAt: updatedAt)
    context.insert(category)
    return (category, true)
}

nonisolated private func applyTargetedProduct(
    _ row: RemoteInventoryProductRow,
    supplier: Supplier?,
    category: ProductCategory?,
    context: ModelContext
) throws -> (inserted: Bool, updated: Bool, tombstoned: Bool) {
    guard let barcode = SupabasePullPreviewNormalizer.semanticString(row.barcode) else {
        return (false, false, false)
    }
    let updatedAt = SupabaseRemoteDateParser.parse(row.updatedAt)
    let deletedAt = SupabaseRemoteDateParser.parse(row.deletedAt)
    let existing = try fetchProduct(remoteID: row.id, context: context)
        ?? fetchProduct(barcode: barcode, context: context)
    if let deletedAt {
        guard let product = existing else { return (false, false, false) }
        product.remoteID = row.id
        product.remoteUpdatedAt = updatedAt
        product.remoteDeletedAt = deletedAt
        product.supplier = nil
        product.category = nil
        return (false, false, true)
    }

    if let product = existing {
        product.remoteID = row.id
        product.remoteUpdatedAt = updatedAt
        product.remoteDeletedAt = nil
        product.itemNumber = SupabasePullPreviewNormalizer.semanticString(row.itemNumber)
        product.productName = SupabasePullPreviewNormalizer.semanticString(row.productName)
        product.secondProductName = SupabasePullPreviewNormalizer.semanticString(row.secondProductName)
        product.purchasePrice = row.purchasePrice
        product.retailPrice = row.retailPrice
        product.stockQuantity = row.stockQuantity
        product.supplier = supplier
        product.category = category
        return (false, true, false)
    }

    context.insert(Product(
        barcode: barcode,
        remoteID: row.id,
        remoteUpdatedAt: updatedAt,
        itemNumber: SupabasePullPreviewNormalizer.semanticString(row.itemNumber),
        productName: SupabasePullPreviewNormalizer.semanticString(row.productName),
        secondProductName: SupabasePullPreviewNormalizer.semanticString(row.secondProductName),
        purchasePrice: row.purchasePrice,
        retailPrice: row.retailPrice,
        stockQuantity: row.stockQuantity,
        supplier: supplier,
        category: category
    ))
    return (true, false, false)
}

nonisolated private func applyTargetedProductPriceRow(
    _ row: RemoteInventoryProductPriceRow,
    product: Product,
    currentPricesByKey: inout [TargetedProductPriceLogicalKey: [TargetedProductPriceCurrentInfo]],
    context: ModelContext
) throws -> ProductPriceApplyResult {
    guard let type = SupabasePullPreviewNormalizer.normalizedPriceType(row.type) else {
        throw ProductPriceApplyError.invalidRemoteRow(reason: "invalid_type")
    }
    guard let canonicalPrice = PriceCanonicalizer.canonicalAmount(from: row.price) else {
        throw ProductPriceApplyError.invalidRemoteRow(reason: "invalid_price")
    }
    guard let effectiveAt = ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.effectiveAt) else {
        throw ProductPriceApplyError.invalidRemoteRow(reason: "invalid_effective_at")
    }
    let effectiveAtCanonical = ProductPriceEffectiveAtCanonicalizer.canonicalString(from: effectiveAt)
    let key = TargetedProductPriceLogicalKey(
        productID: row.productID,
        type: type,
        effectiveAt: effectiveAtCanonical
    )

    if let existingRemote = try fetchProductPrice(remoteID: row.id, context: context) {
        existingRemote.type = priceType(from: type)
        existingRemote.price = canonicalPrice.doubleValue
        existingRemote.effectiveAt = effectiveAt
        existingRemote.source = SupabasePullPreviewNormalizer.semanticString(row.source) ?? "SUPABASE_PULL"
        existingRemote.note = SupabasePullPreviewNormalizer.semanticString(row.note)
        existingRemote.createdAt = ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.createdAt) ?? existingRemote.createdAt
        existingRemote.product = product
        return ProductPriceApplyResult(inserted: 0, skippedExisting: 1, totalConsidered: 1)
    }

    if let existingPrices = currentPricesByKey[key] {
        guard existingPrices.count == 1,
              var existing = existingPrices.first else {
            throw ProductPriceApplyError.policyBlocked([.conflicts])
        }
        guard existing.canonicalPrice == canonicalPrice else {
            throw ProductPriceApplyError.policyBlocked([.conflicts])
        }
        if let existingRemoteID = existing.remoteID {
            guard existingRemoteID == row.id else {
                throw ProductPriceApplyError.policyBlocked([.conflicts])
            }
            return ProductPriceApplyResult(inserted: 0, skippedExisting: 1, totalConsidered: 1)
        }
        guard let productPriceID = existing.productPriceIDToLink,
              let productPrice = context.model(for: productPriceID) as? ProductPrice else {
            throw ProductPriceApplyError.verificationFailed
        }
        productPrice.remoteID = row.id
        productPrice.source = SupabasePullPreviewNormalizer.semanticString(row.source) ?? productPrice.source
        productPrice.note = SupabasePullPreviewNormalizer.semanticString(row.note)
        existing.remoteID = row.id
        existing.productPriceIDToLink = nil
        currentPricesByKey[key] = [existing]
        return ProductPriceApplyResult(
            inserted: 0,
            remoteIdentityLinked: 1,
            skippedExisting: 1,
            totalConsidered: 1
        )
    }

    let newPrice = ProductPrice(
        remoteID: row.id,
        type: priceType(from: type),
        price: canonicalPrice.doubleValue,
        effectiveAt: effectiveAt,
        source: SupabasePullPreviewNormalizer.semanticString(row.source) ?? "SUPABASE_PULL",
        note: SupabasePullPreviewNormalizer.semanticString(row.note),
        createdAt: ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.createdAt) ?? Date(),
        product: product
    )
    context.insert(newPrice)
    currentPricesByKey[key] = [
        TargetedProductPriceCurrentInfo(
            canonicalPrice: canonicalPrice,
            remoteID: row.id
        )
    ]
    return ProductPriceApplyResult(inserted: 1, skippedExisting: 0, totalConsidered: 1)
}

nonisolated private func priceType(from normalizedType: String) -> PriceType {
    normalizedType == PriceType.retail.rawValue ? .retail : .purchase
}

nonisolated private func fetchSupplier(remoteID: UUID, context: ModelContext) throws -> Supplier? {
    var descriptor = FetchDescriptor<Supplier>(
        predicate: #Predicate<Supplier> { supplier in
            supplier.remoteID == remoteID
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated private func fetchSupplier(name: String, context: ModelContext) throws -> Supplier? {
    var descriptor = FetchDescriptor<Supplier>(
        predicate: #Predicate<Supplier> { supplier in
            supplier.name == name
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated private func fetchCategory(remoteID: UUID, context: ModelContext) throws -> ProductCategory? {
    var descriptor = FetchDescriptor<ProductCategory>(
        predicate: #Predicate<ProductCategory> { category in
            category.remoteID == remoteID
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated private func fetchCategory(name: String, context: ModelContext) throws -> ProductCategory? {
    var descriptor = FetchDescriptor<ProductCategory>(
        predicate: #Predicate<ProductCategory> { category in
            category.name == name
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated private func fetchProduct(remoteID: UUID, context: ModelContext) throws -> Product? {
    var descriptor = FetchDescriptor<Product>(
        predicate: #Predicate<Product> { product in
            product.remoteID == remoteID
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated private func fetchProduct(barcode: String, context: ModelContext) throws -> Product? {
    var descriptor = FetchDescriptor<Product>(
        predicate: #Predicate<Product> { product in
            product.barcode == barcode
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated private func fetchProductPrice(remoteID: UUID, context: ModelContext) throws -> ProductPrice? {
    var descriptor = FetchDescriptor<ProductPrice>(
        predicate: #Predicate<ProductPrice> { price in
            price.remoteID == remoteID
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated private func fetchHistory(remoteID: UUID, context: ModelContext) throws -> HistoryEntry? {
    var descriptor = FetchDescriptor<HistoryEntry>(
        predicate: #Predicate<HistoryEntry> { entry in
            entry.remoteID == remoteID
        }
    )
    descriptor.fetchLimit = 1
    return try context.fetch(descriptor).first
}

nonisolated private func detachSupplier(remoteID: UUID, context: ModelContext) throws {
    let products = try context.fetch(FetchDescriptor<Product>())
    for product in products where product.supplier?.remoteID == remoteID {
        product.supplier = nil
    }
}

nonisolated private func detachCategory(remoteID: UUID, context: ModelContext) throws {
    let products = try context.fetch(FetchDescriptor<Product>())
    for product in products where product.category?.remoteID == remoteID {
        product.category = nil
    }
}

nonisolated private func mcNowMillis() -> Int {
    Int((Date().timeIntervalSince1970 * 1_000).rounded())
}

nonisolated private struct SyncEventEntityIDSet: Sendable {
    var supplierIDs: Set<UUID> = []
    var categoryIDs: Set<UUID> = []
    var productIDs: Set<UUID> = []
    var priceIDs: Set<UUID> = []
    var sessionIDs: Set<UUID> = []
    var hasUnrecoverableCatalogGap = false
    var hasUnrecoverablePriceGap = false
    var hasUnrecoverableHistoryGap = false

    init() {}

    init(json: SyncEventJSONValue?) {
        guard case .object(let object) = json else { return }
        supplierIDs = Self.ids(from: object["supplier_ids"])
        categoryIDs = Self.ids(from: object["category_ids"])
        productIDs = Self.ids(from: object["product_ids"])
        priceIDs = Self.ids(from: object["price_ids"])
        sessionIDs = Self.ids(from: object["session_ids"])
    }

    var isEmpty: Bool {
        supplierIDs.isEmpty && categoryIDs.isEmpty && productIDs.isEmpty && priceIDs.isEmpty && sessionIDs.isEmpty
    }

    var isCatalogEmpty: Bool {
        supplierIDs.isEmpty && categoryIDs.isEmpty && productIDs.isEmpty
    }

    var hasCatalogWork: Bool {
        !isCatalogEmpty || hasUnrecoverableCatalogGap
    }

    var hasHistoryWork: Bool {
        !sessionIDs.isEmpty || hasUnrecoverableHistoryGap
    }

    var hasPriceWork: Bool {
        !priceIDs.isEmpty || hasUnrecoverablePriceGap
    }

    var hasWork: Bool {
        hasCatalogWork || hasPriceWork || hasHistoryWork
    }

    var hasUnrecoverableGap: Bool {
        hasUnrecoverableCatalogGap || hasUnrecoverablePriceGap || hasUnrecoverableHistoryGap
    }

    private static func ids(from value: SyncEventJSONValue?) -> Set<UUID> {
        guard case .array(let values) = value else { return [] }
        return Set(values.compactMap { element in
            guard case .string(let raw) = element else { return nil }
            return UUID(uuidString: raw)
        })
    }
}
