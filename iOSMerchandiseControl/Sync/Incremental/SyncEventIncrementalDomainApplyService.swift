import Foundation
import SwiftData

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
    ) async throws -> SyncIncrementalPullSummary {
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
                var summary = SyncIncrementalPullSummary.noWork(watermark: watermarkBefore)
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

        var summary = SyncIncrementalPullSummary(
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

        let productPriceService = ProductPriceIncrementalApplyService(inventoryService: inventoryService)
        let priceFetchResult: ProductPriceIncrementalFetchResult
        if eventIDs.hasPriceWork {
            priceFetchResult = try await productPriceService.fetchTargetedRows(
                priceIDs: eventIDs.priceIDs,
                ownerUserID: ownerUserID
            )
            summary.productPriceFetchMs = priceFetchResult.fetchMs
            summary.targetedProductPricesFetched = priceFetchResult.rows.count
            eventIDs.productIDs.formUnion(priceFetchResult.rows.map(\.productID))
        } else {
            priceFetchResult = ProductPriceIncrementalFetchResult()
        }

        var remoteActiveProductIDsForPrices: Set<UUID>?
        if eventIDs.hasCatalogWork {
            let catalogResult = try await CatalogIncrementalApplyService(
                inventoryService: inventoryService
            ).apply(
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
            summary.productsTombstoned = catalogResult.productsTombstoned + catalogResult.productsMissingRemoteTombstoned
            summary.suppliersCreated = catalogResult.suppliersCreated
            summary.categoriesCreated = catalogResult.categoriesCreated
            summary.suppliersMissingRemoteTombstoned = catalogResult.suppliersMissingRemoteTombstoned
            summary.categoriesMissingRemoteTombstoned = catalogResult.categoriesMissingRemoteTombstoned
            summary.catalogFetchMs = catalogResult.catalogFetchMs
            summary.catalogApplyMs = catalogResult.catalogApplyMs
            remoteActiveProductIDsForPrices = catalogResult.remoteActiveProductIDs
        }

        if eventIDs.hasPriceWork {
            let priceResult = try await productPriceService.apply(
                priceRows: priceFetchResult.rows,
                requestedPriceIDs: eventIDs.priceIDs,
                remoteActiveProductIDs: remoteActiveProductIDsForPrices,
                ownerUserID: ownerUserID,
                modelContainer: modelContainer
            )
            summary.productPriceApplyMs = priceResult.applyMs
            summary.productPricesInserted = priceResult.inserted
            summary.productPriceIdentityLinked = priceResult.remoteIdentityLinked
            summary.productPricesMissingRemotePruned = priceResult.missingRemotePruned
        }

        if eventIDs.hasHistoryWork {
            let historyResult = try await HistoryIncrementalApplyService(
                inventoryService: inventoryService
            ).apply(
                sessionIDs: eventIDs.sessionIDs,
                ownerUserID: ownerUserID,
                modelContainer: modelContainer
            )
            summary.historyFetchMs = historyResult.fetchMs
            summary.targetedHistoryFetched = historyResult.targetedHistoryFetched
            summary.historyApplyMs = historyResult.applyMs
            summary.historyInserted = historyResult.inserted
            summary.historyUpdated = historyResult.updated
            summary.historyMissingRemoteTombstoned = historyResult.missingRemoteTombstoned
        }

        watermarkStore.save(summary.watermarkAfter, for: watermarkScope)
        summary.totalElapsedMs = mcNowMillis() - totalStarted
        return summary
    }

    private func recoverCanonicalDriftIfNeeded(
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        isAuthenticated: Bool,
        watermark: Int64
    ) async throws -> SyncIncrementalPullSummary {
        let remoteCounts = try await inventoryService.fetchReconciliationRemoteCounts()
        let localCounts = try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            return try LocalDatabasePublicSummary.makeReconciliationAware(context: context)
        }.value
        let drift = SyncCountDriftReport.compare(local: localCounts, remote: remoteCounts)
        recordCanonicalDriftDiagnostics(drift)
        guard !drift.isAligned else {
            return SyncIncrementalPullSummary(
                syncType: .lightReconcile,
                watermarkBefore: watermark,
                watermarkAfter: watermark
            )
        }

        var summary = SyncIncrementalPullSummary(
            syncType: .lightReconcile,
            watermarkBefore: watermark,
            watermarkAfter: watermark
        )
        summary.requiresFullRecoveryReason = "canonical_drift_detected"
        return summary
    }

    private func recordCanonicalDriftDiagnostics(_ drift: SyncCountDriftReport) {
        #if DEBUG
        defaults.set(drift.local.products, forKey: "sync.runtime.reconcile.local.products")
        defaults.set(drift.local.suppliers, forKey: "sync.runtime.reconcile.local.suppliers")
        defaults.set(drift.local.categories, forKey: "sync.runtime.reconcile.local.categories")
        defaults.set(drift.local.productPrices, forKey: "sync.runtime.reconcile.local.productPrices")
        defaults.set(drift.local.historySessions, forKey: "sync.runtime.reconcile.local.historySessions")
        defaults.set(drift.remote.products, forKey: "sync.runtime.reconcile.remote.products")
        defaults.set(drift.remote.suppliers, forKey: "sync.runtime.reconcile.remote.suppliers")
        defaults.set(drift.remote.categories, forKey: "sync.runtime.reconcile.remote.categories")
        defaults.set(drift.remote.productPrices, forKey: "sync.runtime.reconcile.remote.productPrices")
        defaults.set(drift.remote.historySessions, forKey: "sync.runtime.reconcile.remote.historySessions")
        defaults.set(
            drift.mismatches.map(\.rawValue).joined(separator: ","),
            forKey: "sync.runtime.reconcile.mismatches"
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
        "sync.events.lightReconcile.lastAt.\(AccountBindingStore.accountHash(for: ownerUserID))"
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

}
