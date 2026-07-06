import Foundation
import SwiftData

nonisolated struct SyncEventIncrementalDomainApplyService {
    private let eventFetcher: any SupabaseSyncEventIncrementalFetching
    private let remote: any SyncAutomaticIncrementalRemote
    private let defaults: UserDefaults
    private let watermarkStore: WatermarkStore
    private let limit: Int
    private let currentDeviceID: String?
    private static let entityIDBudget = 250

    init(
        eventFetcher: any SupabaseSyncEventIncrementalFetching,
        remote: any SyncAutomaticIncrementalRemote,
        defaults: UserDefaults = .standard,
        watermarkStore: WatermarkStore? = nil,
        limit: Int = 50,
        currentDeviceID: String? = DeviceInstallIDStore().deviceInstallID
    ) {
        self.eventFetcher = eventFetcher
        self.remote = remote
        self.defaults = defaults
        self.watermarkStore = watermarkStore ?? WatermarkStore(defaults: defaults)
        self.limit = max(1, min(limit, SupabaseSyncEventIncrementalLimits.maximumLimit))
        self.currentDeviceID = currentDeviceID
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
        let selectedShopID = ShopContextSelection.selectedShopID(ownerUserID: ownerUserID, defaults: defaults)
        let scopedEvents = events.filter { event in
            guard let selectedShopID else { return true }
            return event.shopID == selectedShopID
        }
        let eventFetchMs = mcNowMillis() - eventFetchStarted
        guard !scopedEvents.isEmpty else {
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
            eventsFetched: scopedEvents.count,
            watermarkBefore: watermarkBefore,
            watermarkAfter: watermarkBefore
        )
        summary.eventPageFetchMs = eventFetchMs

        let sortedEvents = scopedEvents.sorted { $0.id < $1.id }
        let statusStore = SyncEventApplyStatusStore(defaults: defaults)
        let protectedIDs = try await protectedRemoteIDs(ownerUserID: ownerUserID, modelContainer: modelContainer)
        let classification = classifyEvents(
            sortedEvents,
            ownerUserID: ownerUserID,
            protectedIDs: protectedIDs,
            statusStore: statusStore
        )
        let eventsForApply = classification.eventsForApply
        var eventIDs = extractEntityIDs(from: eventsForApply)
        summary.eventsProcessed = sortedEvents.count
        summary.watermarkAfter = checkpointWatermark(
            sortedEvents: sortedEvents,
            watermarkBefore: watermarkBefore,
            firstBlockedEventID: classification.firstBlockedEventID
        )
        summary.requiresFullRecoveryReason = classification.requiresFullRecoveryReason

        guard eventIDs.hasWork else {
            recordApplied(eventsForApply, ownerUserID: ownerUserID, statusStore: statusStore)
            if summary.watermarkAfter > watermarkBefore {
                watermarkStore.save(summary.watermarkAfter, for: watermarkScope)
            }
            summary.totalElapsedMs = mcNowMillis() - totalStarted
            return summary
        }

        guard !eventIDs.hasUnrecoverableGap else {
            summary.requiresFullRecoveryReason = "sync_event_missing_entity_ids"
            summary.watermarkAfter = watermarkBefore
            summary.totalElapsedMs = mcNowMillis() - totalStarted
            return summary
        }

        let productPriceService = ProductPriceIncrementalApplyService(remote: remote)
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
        var missingRemoteDomains = Set<String>()
        if eventIDs.hasCatalogWork {
            let catalogResult = try await CatalogIncrementalApplyService(
                remote: remote
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
            summary.suppliersUpdated = catalogResult.suppliersUpdated
            summary.categoriesCreated = catalogResult.categoriesCreated
            summary.categoriesUpdated = catalogResult.categoriesUpdated
            summary.suppliersMissingRemoteTombstoned = catalogResult.suppliersMissingRemoteTombstoned
            summary.categoriesMissingRemoteTombstoned = catalogResult.categoriesMissingRemoteTombstoned
            summary.catalogFetchMs = catalogResult.catalogFetchMs
            summary.catalogApplyMs = catalogResult.catalogApplyMs
            remoteActiveProductIDsForPrices = catalogResult.remoteActiveProductIDs
            if catalogResult.missingRemoteTargetCount > 0 {
                missingRemoteDomains.insert("catalog")
            }
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
            if priceResult.missingRemoteCount > 0 {
                missingRemoteDomains.insert("prices")
            }
        }

        if eventIDs.hasHistoryWork {
            let historyResult = try await HistoryIncrementalApplyService(
                remote: remote
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
            if historyResult.missingRemoteCount > 0 {
                missingRemoteDomains.insert("history")
            }
        }

        let firstMissingRemoteEventID = eventsForApply
            .filter { missingRemoteDomains.contains($0.domain) }
            .map(\.id)
            .min()
        let finalFirstBlockedEventID = minEventID(
            classification.firstBlockedEventID,
            firstMissingRemoteEventID
        )
        if firstMissingRemoteEventID != nil {
            summary.requiresFullRecoveryReason = summary.requiresFullRecoveryReason ?? "sync_event_missing_remote"
            summary.watermarkAfter = checkpointWatermark(
                sortedEvents: sortedEvents,
                watermarkBefore: watermarkBefore,
                firstBlockedEventID: finalFirstBlockedEventID
            )
        }
        recordApplyOutcomes(
            eventsForApply,
            ownerUserID: ownerUserID,
            statusStore: statusStore,
            missingRemoteDomains: missingRemoteDomains
        )
        if summary.watermarkAfter > watermarkBefore {
            watermarkStore.save(summary.watermarkAfter, for: watermarkScope)
        }
        summary.totalElapsedMs = mcNowMillis() - totalStarted
        return summary
    }

    private func recoverCanonicalDriftIfNeeded(
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        isAuthenticated: Bool,
        watermark: Int64
    ) async throws -> SyncIncrementalPullSummary {
        let remoteCounts = try await remote.fetchReconciliationRemoteCounts()
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
        let selectedShopID = ShopContextSelection.selectedShopID(ownerUserID: ownerUserID, defaults: defaults)
        store.save(
            watermark,
            for: WatermarkStore.Scope(
                ownerUserID: ownerUserID,
                storeIdentity: ShopContextSelection.localStoreIdentity(ownerUserID: ownerUserID, defaults: defaults)
            )
        )
        if selectedShopID == nil {
            defaults.set(Int(watermark), forKey: watermarkKey(ownerUserID: ownerUserID))
        }
    }

    private func watermarkScope(ownerUserID: UUID) -> WatermarkStore.Scope {
        let binding = AccountBindingStore(defaults: defaults).currentBinding
        return WatermarkStore.Scope(
            ownerUserID: ownerUserID,
            storeIdentity: binding?.storeIdentity ?? ShopContextSelection.localStoreIdentity(ownerUserID: ownerUserID, defaults: defaults)
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

    private func protectedRemoteIDs(
        ownerUserID: UUID,
        modelContainer: ModelContainer
    ) async throws -> IncrementalApplyProtectedRemoteIDs {
        try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            return try pendingRemoteIDs(context: context, ownerUserID: ownerUserID)
        }.value
    }

    private func classifyEvents(
        _ events: [RemoteSyncEventRow],
        ownerUserID: UUID,
        protectedIDs: IncrementalApplyProtectedRemoteIDs,
        statusStore: SyncEventApplyStatusStore
    ) -> SyncEventApplyClassification {
        var classification = SyncEventApplyClassification()
        for event in events {
            let ids = entityIDs(for: event)
            if let currentDeviceID,
               event.sourceDeviceID == currentDeviceID {
                statusStore.record(
                    event: event,
                    ownerUserID: ownerUserID,
                    ids: ids,
                    status: .skipped,
                    reason: .selfOrigin
                )
                continue
            }

            guard isSupportedDomain(event.domain) else {
                classification.block(
                    eventID: event.id,
                    reason: "sync_event_unsupported_domain"
                )
                statusStore.record(
                    event: event,
                    ownerUserID: ownerUserID,
                    ids: ids,
                    status: .blocked,
                    reason: .unsupportedDomain
                )
                continue
            }

            if ids.hasUnrecoverableGap {
                classification.block(
                    eventID: event.id,
                    reason: "sync_event_missing_entity_ids"
                )
                statusStore.record(
                    event: event,
                    ownerUserID: ownerUserID,
                    ids: ids,
                    status: .blocked,
                    reason: .missingEntityIDs
                )
                continue
            }

            if ids.totalIDs > Self.entityIDBudget {
                classification.block(
                    eventID: event.id,
                    reason: "sync_event_entity_ids_too_large"
                )
                statusStore.record(
                    event: event,
                    ownerUserID: ownerUserID,
                    ids: ids,
                    status: .blocked,
                    reason: .entityIDsTooLarge
                )
                continue
            }

            if containsProtectedIDs(ids, protectedIDs: protectedIDs) {
                classification.block(
                    eventID: event.id,
                    reason: "sync_event_dirty_local"
                )
                statusStore.record(
                    event: event,
                    ownerUserID: ownerUserID,
                    ids: ids,
                    status: .blocked,
                    reason: .dirtyLocal
                )
                continue
            }

            classification.eventsForApply.append(event)
        }
        return classification
    }

    private func recordApplied(
        _ events: [RemoteSyncEventRow],
        ownerUserID: UUID,
        statusStore: SyncEventApplyStatusStore
    ) {
        for event in events {
            statusStore.record(
                event: event,
                ownerUserID: ownerUserID,
                ids: entityIDs(for: event),
                status: .applied,
                reason: .applied
            )
        }
    }

    private func recordApplyOutcomes(
        _ events: [RemoteSyncEventRow],
        ownerUserID: UUID,
        statusStore: SyncEventApplyStatusStore,
        missingRemoteDomains: Set<String>
    ) {
        for event in events {
            let isMissingRemote = missingRemoteDomains.contains(event.domain)
            statusStore.record(
                event: event,
                ownerUserID: ownerUserID,
                ids: entityIDs(for: event),
                status: isMissingRemote ? .blocked : .applied,
                reason: isMissingRemote ? .missingRemote : .applied
            )
        }
    }

    private func extractEntityIDs(from events: [RemoteSyncEventRow]) -> SyncEventEntityIDSet {
        events.reduce(into: SyncEventEntityIDSet()) { result, event in
            guard event.domain == "catalog" || event.domain == "prices" || event.domain == "history" else { return }
            let ids = entityIDs(for: event)
            result.supplierIDs.formUnion(ids.supplierIDs)
            result.categoryIDs.formUnion(ids.categoryIDs)
            result.productIDs.formUnion(ids.productIDs)
            result.priceIDs.formUnion(ids.priceIDs)
            result.sessionIDs.formUnion(ids.sessionIDs)
        }
    }

    private func hasUnrecoverableGap(_ event: RemoteSyncEventRow) -> Bool {
        entityIDs(for: event).hasUnrecoverableGap
    }

    private func entityIDs(for event: RemoteSyncEventRow) -> SyncEventEntityIDSet {
        var ids = SyncEventEntityIDSet(json: event.entityIDs)
        markUnrecoverableGap(for: event, ids: ids, into: &ids)
        return ids
    }

    private func isSupportedDomain(_ domain: String) -> Bool {
        domain == "catalog" || domain == "prices" || domain == "history"
    }

    private func containsProtectedIDs(
        _ ids: SyncEventEntityIDSet,
        protectedIDs: IncrementalApplyProtectedRemoteIDs
    ) -> Bool {
        !ids.supplierIDs.isDisjoint(with: protectedIDs.suppliers)
            || !ids.categoryIDs.isDisjoint(with: protectedIDs.categories)
            || !ids.productIDs.isDisjoint(with: protectedIDs.products)
            || !ids.priceIDs.isDisjoint(with: protectedIDs.prices)
            || !ids.sessionIDs.isDisjoint(with: protectedIDs.history)
    }

    private func checkpointWatermark(
        sortedEvents: [RemoteSyncEventRow],
        watermarkBefore: Int64,
        firstBlockedEventID: Int64?
    ) -> Int64 {
        guard let firstBlockedEventID else {
            return sortedEvents.map(\.id).max() ?? watermarkBefore
        }
        return sortedEvents
            .filter { $0.id < firstBlockedEventID }
            .map(\.id)
            .max() ?? watermarkBefore
    }

    private func minEventID(_ lhs: Int64?, _ rhs: Int64?) -> Int64? {
        switch (lhs, rhs) {
        case (.some(let lhs), .some(let rhs)):
            return min(lhs, rhs)
        case (.some(let lhs), .none):
            return lhs
        case (.none, .some(let rhs)):
            return rhs
        case (.none, .none):
            return nil
        }
    }

    private func markUnrecoverableGap(
        for event: RemoteSyncEventRow,
        ids: SyncEventEntityIDSet,
        into result: inout SyncEventEntityIDSet
    ) {
        if event.domain == "catalog", ids.isEmpty, event.changedCount > 0 {
            result.hasUnrecoverableCatalogGap = true
        }
        if event.domain == "history", ids.sessionIDs.isEmpty, event.changedCount > 0 {
            result.hasUnrecoverableHistoryGap = true
        }
        if event.domain == "prices", ids.priceIDs.isEmpty, event.changedCount > 0 {
            result.hasUnrecoverablePriceGap = true
        }
    }

}

private nonisolated struct SyncEventApplyClassification {
    var eventsForApply: [RemoteSyncEventRow] = []
    var firstBlockedEventID: Int64?
    var requiresFullRecoveryReason: String?

    mutating func block(eventID: Int64, reason: String) {
        guard firstBlockedEventID == nil else { return }
        firstBlockedEventID = eventID
        requiresFullRecoveryReason = reason
    }
}
