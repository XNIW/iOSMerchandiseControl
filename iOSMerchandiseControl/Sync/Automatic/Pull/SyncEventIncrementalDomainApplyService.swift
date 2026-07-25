import Foundation
import SwiftData

nonisolated enum SyncEventAtomicMutationProbePhase: Sendable {
    case afterCatalog
    case afterPrices
    case afterHistory
    case afterMutationsBeforeCommit
}

nonisolated struct SyncEventIncrementalDomainApplyService {
    private let eventFetcher: any SupabaseSyncEventIncrementalFetching
    private let remote: any SyncAutomaticIncrementalRemote
    private let defaults: UserDefaults
    private let watermarkStore: WatermarkStore
    private let limit: Int
    private let currentDeviceID: String?
    private let beforeAtomicMutationForTesting: (@Sendable () async throws -> Void)?
    private let atomicMutationProbeForTesting: (@Sendable (SyncEventAtomicMutationProbePhase) throws -> Void)?
    private let afterAtomicMutationForTesting: (@Sendable () async throws -> Void)?
    // Aggregate work across multiple valid events remains bounded separately.
    private static let entityIDBudget = 1_000
    private static let catalogEntityIDsPerEvent = 250
    private static let priceEntityIDsPerEvent = 250
    private static let historyEntityIDsPerEvent = 25
    private static let maximumEventScanPages = 512
    private static let maximumScannedEvents = 1_000
    private static let maximumEventScanEncodedBytes = 16 * 1_024 * 1_024

    init(
        eventFetcher: any SupabaseSyncEventIncrementalFetching,
        remote: any SyncAutomaticIncrementalRemote,
        defaults: UserDefaults = .standard,
        watermarkStore: WatermarkStore? = nil,
        limit: Int = 50,
        currentDeviceID: String? = nil,
        beforeAtomicMutationForTesting: (@Sendable () async throws -> Void)? = nil,
        atomicMutationProbeForTesting: (@Sendable (SyncEventAtomicMutationProbePhase) throws -> Void)? = nil,
        afterAtomicMutationForTesting: (@Sendable () async throws -> Void)? = nil
    ) {
        self.eventFetcher = eventFetcher
        self.remote = remote
        self.defaults = defaults
        self.watermarkStore = watermarkStore ?? WatermarkStore(defaults: defaults)
        self.limit = max(1, min(limit, SupabaseSyncEventIncrementalLimits.maximumLimit))
        self.currentDeviceID = currentDeviceID
            ?? (try? DeviceInstallIDStore(defaults: defaults).requireDeviceInstallID())
        self.beforeAtomicMutationForTesting = beforeAtomicMutationForTesting
        self.atomicMutationProbeForTesting = atomicMutationProbeForTesting
        self.afterAtomicMutationForTesting = afterAtomicMutationForTesting
    }

    func applyNextEvents(
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        isAuthenticated: Bool,
        forceLightReconcile: Bool = false
    ) async throws -> SyncIncrementalPullSummary {
        let totalStarted = mcNowMillis()
        guard isAuthenticated else {
            throw Task126OwnerStoreGateError.activeAccountMismatch
        }
        let scope: Task126VerifiedOwnerStoreScope
        if let currentScope = Task126OwnerStoreGate.currentAutomaticScope {
            guard currentScope.ownerUserID == ownerUserID else {
                throw Task126OwnerStoreGateError.scopeChanged
            }
            try Task126OwnerStoreGate.revalidateAutomaticScope(currentScope, defaults: defaults)
            scope = currentScope
        } else {
            scope = try Task126OwnerStoreGate.captureAutomaticScope(
                ownerUserID: ownerUserID,
                defaults: defaults
            )
        }
        let watermarkScope = WatermarkStore.Scope(
            ownerUserID: ownerUserID,
            storeIdentity: scope.storeIdentity
        )
        let watermarkBefore = watermarkStore.watermark(for: watermarkScope)
        let eventFetchStarted = mcNowMillis()
        var scopedEvents: [RemoteSyncEventRow] = []
        var eventCursor = watermarkBefore
        var eventScanExhausted = true
        var eventScanEncodedBytes = 0
        eventScanLoop: for pageIndex in 0..<Self.maximumEventScanPages {
            try Task.checkCancellation()
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
            let page: [RemoteSyncEventRow]
            do {
                page = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                    try await eventFetcher.fetchSyncEventsAfter(
                        ownerUserID: ownerUserID,
                        afterID: eventCursor,
                        limit: limit
                    )
                }
            } catch {
                guard let reason = boundedRecoveryReason(for: error) else { throw error }
                var summary = SyncIncrementalPullSummary(
                    syncType: .eventIncremental,
                    eventsFetched: scopedEvents.count,
                    eventsProcessed: scopedEvents.count,
                    watermarkBefore: watermarkBefore,
                    watermarkAfter: watermarkBefore,
                    requiresFullRecoveryReason: reason
                )
                summary.eventPageFetchMs = mcNowMillis() - eventFetchStarted
                summary.totalElapsedMs = mcNowMillis() - totalStarted
                return summary
            }
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
            guard page.count <= limit else {
                eventScanExhausted = true
                break eventScanLoop
            }
            var previousID = eventCursor
            for event in page {
                guard event.id > previousID else {
                    throw ShopSyncRecoveryContractError.nonMonotonicOrDuplicateID
                }
                try validateIncrementalReadIdentity(
                    ownerUserID: event.ownerUserID,
                    shopID: event.shopID,
                    scope: scope,
                    remote: eventFetcher
                )
                let encodedBytes = try JSONEncoder().encode(event).count
                let (nextBytes, overflow) = eventScanEncodedBytes.addingReportingOverflow(
                    encodedBytes
                )
                guard !overflow,
                      scopedEvents.count < Self.maximumScannedEvents,
                      nextBytes <= Self.maximumEventScanEncodedBytes else {
                    eventScanExhausted = true
                    break eventScanLoop
                }
                eventScanEncodedBytes = nextBytes
                previousID = event.id
                scopedEvents.append(event)
            }
            guard page.count == limit else {
                eventScanExhausted = false
                break
            }
            guard let lastID = page.last?.id else {
                eventScanExhausted = false
                break
            }
            eventCursor = lastID
            if pageIndex == Self.maximumEventScanPages - 1 {
                eventScanExhausted = true
            }
        }
        let eventFetchMs = mcNowMillis() - eventFetchStarted
        if eventScanExhausted {
            var summary = SyncIncrementalPullSummary(
                syncType: .eventIncremental,
                eventsFetched: scopedEvents.count,
                watermarkBefore: watermarkBefore,
                watermarkAfter: watermarkBefore
            )
            summary.eventsProcessed = scopedEvents.count
            summary.requiresFullRecoveryReason = "sync_event_scan_page_budget_exceeded"
            summary.eventPageFetchMs = eventFetchMs
            summary.totalElapsedMs = mcNowMillis() - totalStarted
            return summary
        }
        guard !scopedEvents.isEmpty else {
            let scannedWatermark = watermarkBefore
            if scannedWatermark > watermarkBefore {
                // This owner page was fully examined for the selected shop. Advance
                // the shop-scoped checkpoint even when every row belongs elsewhere,
                // otherwise the same foreign-shop page is fetched forever.
                try await persistVerifiedWatermarkAdvance(
                    ownerUserID: ownerUserID,
                    scope: scope,
                    watermarkScope: watermarkScope,
                    from: watermarkBefore,
                    through: scannedWatermark
                )
            }
            guard try shouldRunLightReconcile(
                ownerUserID: ownerUserID,
                storeIdentity: watermarkScope.storeIdentity,
                scope: scope,
                force: forceLightReconcile
            ) else {
                var summary = SyncIncrementalPullSummary.noWork(watermark: scannedWatermark)
                summary.watermarkBefore = watermarkBefore
                summary.eventPageFetchMs = eventFetchMs
                summary.totalElapsedMs = mcNowMillis() - totalStarted
                return summary
            }
            var summary = try await recoverCanonicalDriftIfNeeded(
                ownerUserID: ownerUserID,
                modelContainer: modelContainer,
                isAuthenticated: isAuthenticated,
                watermark: scannedWatermark,
                scope: scope
            )
            try recordLightReconcileCompleted(
                ownerUserID: ownerUserID,
                storeIdentity: watermarkScope.storeIdentity,
                scope: scope
            )
            summary.watermarkBefore = watermarkBefore
            summary.watermarkAfter = scannedWatermark
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
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        let protectedIDs: IncrementalApplyProtectedRemoteIDs
        do {
            protectedIDs = try await protectedRemoteIDs(
                ownerUserID: ownerUserID,
                modelContainer: modelContainer,
                storeIdentity: scope.storeIdentity
            )
        } catch {
            guard let reason = boundedRecoveryReason(for: error) else { throw error }
            summary.requiresFullRecoveryReason = reason
            summary.watermarkAfter = watermarkBefore
            summary.totalElapsedMs = mcNowMillis() - totalStarted
            return summary
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        let classification = try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
            scope,
            defaults: defaults
        ) {
            classifyEvents(
                sortedEvents,
                ownerUserID: ownerUserID,
                scopeShopID: scope.shopID,
                protectedIDs: protectedIDs,
                statusStore: statusStore
            )
        }
        let eventsForApply = classification.eventsForApply
        var eventIDs = extractEntityIDs(from: eventsForApply)
        summary.eventsProcessed = sortedEvents.count
        summary.watermarkAfter = checkpointWatermark(
            sortedEvents: sortedEvents,
            watermarkBefore: watermarkBefore,
            firstBlockedEventID: classification.firstBlockedEventID
        )
        summary.requiresFullRecoveryReason = classification.requiresFullRecoveryReason

        // Targeted reads expose current rows, not an as-of-event version. If
        // any event in the ordered page is blocked, publishing an apparently
        // valid prefix could expose state written by a later event for the
        // same entity. Keep the whole page below the durable cursor and hand
        // control to the atomically verified full-recovery generation.
        if classification.firstBlockedEventID != nil {
            summary.watermarkAfter = watermarkBefore
            summary.totalElapsedMs = mcNowMillis() - totalStarted
            return summary
        }

        if eventIDs.supplierIDs.count > Self.entityIDBudget
            || eventIDs.categoryIDs.count > Self.entityIDBudget
            || eventIDs.productIDs.count > Self.entityIDBudget
            || eventIDs.priceIDs.count > Self.entityIDBudget
            || eventIDs.sessionIDs.count > Self.entityIDBudget {
            // V6 reads are chunked per domain, but an oversized aggregate still
            // exceeds this generation's bounded preflight budget. Do not partially
            // apply the prefix or advance its watermark: request full recovery.
            try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                scope,
                defaults: defaults
            ) {
                for event in eventsForApply {
                    _ = statusStore.record(
                        event: event,
                        ownerUserID: ownerUserID,
                        scopeShopID: scope.shopID,
                        ids: entityIDs(for: event),
                        status: .blocked,
                        reason: .aggregateEntityIDsTooLarge
                    )
                }
            }
            summary.requiresFullRecoveryReason = "sync_event_aggregate_entity_ids_too_large"
            summary.watermarkAfter = watermarkBefore
            summary.totalElapsedMs = mcNowMillis() - totalStarted
            return summary
        }

        guard eventIDs.hasWork else {
            try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                scope,
                defaults: defaults
            ) {
                recordApplied(
                    eventsForApply,
                    ownerUserID: ownerUserID,
                    scopeShopID: scope.shopID,
                    statusStore: statusStore
                )
            }
            if summary.watermarkAfter > watermarkBefore {
                do {
                    try await persistVerifiedWatermarkAdvance(
                        ownerUserID: ownerUserID,
                        scope: scope,
                        watermarkScope: watermarkScope,
                        from: watermarkBefore,
                        through: summary.watermarkAfter
                    )
                } catch {
                    guard let reason = boundedRecoveryReason(for: error) else { throw error }
                    summary.requiresFullRecoveryReason = reason
                    summary.watermarkAfter = watermarkBefore
                }
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

        let productPriceService = ProductPriceIncrementalApplyService(
            remote: remote,
            scope: scope,
            defaults: defaults
        )
        let priceFetchResult: ProductPriceIncrementalFetchResult
        if eventIDs.hasPriceWork {
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
            do {
                priceFetchResult = try await productPriceService.fetchTargetedRows(
                    priceIDs: eventIDs.priceIDs,
                    ownerUserID: ownerUserID
                )
            } catch {
                guard let reason = boundedRecoveryReason(for: error) else { throw error }
                summary.requiresFullRecoveryReason = reason
                summary.watermarkAfter = watermarkBefore
                summary.totalElapsedMs = mcNowMillis() - totalStarted
                return summary
            }
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
            summary.productPriceFetchMs = priceFetchResult.fetchMs
            summary.targetedProductPricesFetched = priceFetchResult.rows.count
            eventIDs.productIDs.formUnion(priceFetchResult.rows.map(\.productID))
        } else {
            priceFetchResult = ProductPriceIncrementalFetchResult()
        }

        let catalogService = CatalogIncrementalApplyService(
            remote: remote,
            scope: scope,
            defaults: defaults
        )
        let catalogFetchResult: CatalogIncrementalFetchResult
        if eventIDs.hasCatalogWork {
            do {
                catalogFetchResult = try await catalogService.fetch(eventIDs: eventIDs)
            } catch {
                guard let reason = boundedRecoveryReason(for: error) else { throw error }
                summary.requiresFullRecoveryReason = reason
                summary.watermarkAfter = watermarkBefore
                summary.totalElapsedMs = mcNowMillis() - totalStarted
                return summary
            }
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
            summary.targetedSuppliersFetched = catalogFetchResult.suppliers.count
            summary.targetedCategoriesFetched = catalogFetchResult.categories.count
            summary.targetedProductsFetched = catalogFetchResult.products.count
            summary.catalogFetchMs = catalogFetchResult.fetchMs
        } else {
            catalogFetchResult = CatalogIncrementalFetchResult()
        }

        let historyService = HistoryIncrementalApplyService(
            remote: remote,
            scope: scope,
            defaults: defaults
        )
        let historyFetchResult: HistoryIncrementalFetchResult
        if eventIDs.hasHistoryWork {
            do {
                historyFetchResult = try await historyService.fetch(
                    sessionIDs: eventIDs.sessionIDs,
                    ownerUserID: ownerUserID,
                )
            } catch {
                guard let reason = boundedRecoveryReason(for: error) else { throw error }
                summary.requiresFullRecoveryReason = reason
                summary.watermarkAfter = watermarkBefore
                summary.totalElapsedMs = mcNowMillis() - totalStarted
                return summary
            }
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
            summary.targetedHistoryFetched = historyFetchResult.rows.count
            summary.historyFetchMs = historyFetchResult.fetchMs
        } else {
            historyFetchResult = HistoryIncrementalFetchResult()
        }

        // Every remote row needed by the ordered page is fetched and validated
        // before the first local mutation. If event N cannot be materialized,
        // only the fully preflighted prefix before N may be applied; N and all
        // later events remain invisible and below the durable watermark.
        let dynamicBlock = firstDynamicPreflightBlock(
            events: eventsForApply,
            priceRows: priceFetchResult.rows,
            catalog: catalogFetchResult,
            historyRows: historyFetchResult.rows
        )
        if let dynamicBlock {
            summary.requiresFullRecoveryReason = dynamicBlock.recoveryReason
            summary.watermarkAfter = watermarkBefore
            try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                scope,
                defaults: defaults
            ) {
                _ = statusStore.record(
                    event: dynamicBlock.event,
                    ownerUserID: ownerUserID,
                    scopeShopID: scope.shopID,
                    ids: entityIDs(for: dynamicBlock.event),
                    status: .blocked,
                    reason: dynamicBlock.statusReason
                )
            }
            summary.totalElapsedMs = mcNowMillis() - totalStarted
            return summary
        }

        // Stabilize the current-row read without assuming a cross-request SQL
        // snapshot. Any mutation visible to the targeted RPC must commit its
        // sync event in the same backend transaction; a tail read performed
        // after all targeted responses therefore detects a newer row version.
        // Discard the page instead of exposing that future state early.
        if let scannedThrough = sortedEvents.last?.id {
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
            let stabilityTail: [RemoteSyncEventRow]
            do {
                stabilityTail = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                    try await eventFetcher.fetchSyncEventsAfter(
                        ownerUserID: ownerUserID,
                        afterID: scannedThrough,
                        limit: 1
                    )
                }
            } catch {
                guard let reason = boundedRecoveryReason(for: error) else { throw error }
                summary.requiresFullRecoveryReason = reason
                summary.watermarkAfter = watermarkBefore
                summary.totalElapsedMs = mcNowMillis() - totalStarted
                return summary
            }
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
            for event in stabilityTail {
                try validateIncrementalReadIdentity(
                    ownerUserID: event.ownerUserID,
                    shopID: event.shopID,
                    scope: scope,
                    remote: eventFetcher
                )
                guard event.id > scannedThrough else {
                    throw ShopSyncRecoveryContractError.nonMonotonicOrDuplicateID
                }
            }
            if !stabilityTail.isEmpty {
                summary.requiresFullRecoveryReason = "sync_event_page_changed_during_targeted_read"
                summary.watermarkAfter = watermarkBefore
                summary.totalElapsedMs = mcNowMillis() - totalStarted
                return summary
            }
        }
        let eventsForMutation = eventsForApply
        if !eventsForMutation.isEmpty {
            try await beforeAtomicMutationForTesting?()
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        }
        let atomicResult: SyncEventAtomicMutationResult
        do {
            atomicResult = try await applyMutationPrefixAtomically(
                events: eventsForMutation,
                priceRows: priceFetchResult.rows,
                catalog: catalogFetchResult,
                historyRows: historyFetchResult.rows,
                ownerUserID: ownerUserID,
                modelContainer: modelContainer,
                scope: scope
            )
        } catch {
            guard let reason = boundedRecoveryReason(for: error) else { throw error }
            summary.requiresFullRecoveryReason = reason
            summary.watermarkAfter = watermarkBefore
            summary.totalElapsedMs = mcNowMillis() - totalStarted
            return summary
        }
        try await afterAtomicMutationForTesting?()
        let effectiveBlock = atomicResult.lateProtectedBlock
        let firstBlockedEventID = minEventID(
            classification.firstBlockedEventID,
            effectiveBlock?.event.id
        )
        summary.watermarkAfter = effectiveBlock == nil
            ? checkpointWatermark(
                sortedEvents: sortedEvents,
                watermarkBefore: watermarkBefore,
                firstBlockedEventID: firstBlockedEventID
            )
            : watermarkBefore
        if let effectiveBlock {
            summary.requiresFullRecoveryReason = effectiveBlock.recoveryReason
        }
        summary.productsInserted = atomicResult.catalog.productsInserted
        summary.productsUpdated = atomicResult.catalog.productsUpdated
        summary.productsTombstoned = atomicResult.catalog.productsTombstoned
        summary.suppliersCreated = atomicResult.catalog.suppliersCreated
        summary.suppliersUpdated = atomicResult.catalog.suppliersUpdated
        summary.categoriesCreated = atomicResult.catalog.categoriesCreated
        summary.categoriesUpdated = atomicResult.catalog.categoriesUpdated
        summary.catalogApplyMs = atomicResult.catalogApplyMs
        summary.productPricesInserted = atomicResult.prices.inserted
        summary.productPriceIdentityLinked = atomicResult.prices.remoteIdentityLinked
        summary.productPriceApplyMs = atomicResult.priceApplyMs
        summary.historyInserted = atomicResult.history.insertedCount
        summary.historyUpdated = atomicResult.history.updatedCount
        summary.historyApplyMs = atomicResult.historyApplyMs

        try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
            scope,
            defaults: defaults
        ) {
            if let effectiveBlock {
                _ = statusStore.record(
                    event: effectiveBlock.event,
                    ownerUserID: ownerUserID,
                    scopeShopID: scope.shopID,
                    ids: entityIDs(for: effectiveBlock.event),
                    status: .blocked,
                    reason: effectiveBlock.statusReason
                )
            }
            recordApplied(
                atomicResult.appliedEvents,
                ownerUserID: ownerUserID,
                scopeShopID: scope.shopID,
                statusStore: statusStore
            )
        }
        if summary.watermarkAfter > watermarkBefore {
            do {
                try await persistVerifiedWatermarkAdvance(
                    ownerUserID: ownerUserID,
                    scope: scope,
                    watermarkScope: watermarkScope,
                    from: watermarkBefore,
                    through: summary.watermarkAfter
                )
            } catch {
                guard let reason = boundedRecoveryReason(for: error) else { throw error }
                summary.requiresFullRecoveryReason = reason
                summary.watermarkAfter = watermarkBefore
            }
        }
        summary.totalElapsedMs = mcNowMillis() - totalStarted
        return summary
    }

    /// Commits the durable V6 opaque scope fence before exposing a newer
    /// watermark. A crash or lease change between the two writes leaves an
    /// intentionally unusable fence/watermark combination that requests full
    /// recovery, never a mixed-scope incremental read.
    private func persistVerifiedWatermarkAdvance(
        ownerUserID: UUID,
        scope: Task126VerifiedOwnerStoreScope,
        watermarkScope: WatermarkStore.Scope,
        from watermark: Int64,
        through newWatermark: Int64
    ) async throws {
        guard newWatermark > watermark else { return }
        if let fencePersisting = eventFetcher as? any ShopScopedIncrementalFencePersisting {
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
            try await Task126OwnerStoreGate.withAutomaticScope(scope) {
                try await fencePersisting.advanceDurableFence(
                    ownerUserID: ownerUserID,
                    scope: scope,
                    from: watermark,
                    through: newWatermark
                )
            }
            try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        } else if let authorizing = eventFetcher as? any ShopScopedIncrementalRPCAuthorizing,
                  authorizing.usesServerAuthorizedShopScope {
            // A server-authorized V6 reader without the matching durable
            // fence writer is not a compatible implementation. Do not let it
            // silently advance into the next request without scope proof.
            throw ShopSyncRecoveryContractError.scopeFenceMissing
        }
        try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
            scope,
            defaults: defaults
        ) {
            watermarkStore.save(newWatermark, for: watermarkScope)
            guard watermarkStore.watermark(for: watermarkScope) == newWatermark else {
                throw ShopSyncRecoveryContractError.scopeFenceMissing
            }
        }
    }

    private func boundedRecoveryReason(for error: Error) -> String? {
        guard let contractError = error as? ShopSyncRecoveryContractError else {
            return nil
        }
        switch contractError {
        case .fullRecoveryRequired:
            return "sync_event_backend_requires_full_recovery"
        case .scopeFenceMissing:
            return "sync_event_scope_fence_missing"
        case .markerNotVerified:
            return "sync_event_marker_not_verified"
        case .invalidCursor:
            return "sync_event_invalid_cursor"
        case let .pageBudgetExceeded(domain):
            return "sync_event_\(domain.rawValue)_page_budget_exceeded"
        case let .resourceBudgetExceeded(domain):
            return "sync_event_\(domain.rawValue)_resource_budget_exceeded"
        case .totalResourceBudgetExceeded:
            return "sync_event_total_resource_budget_exceeded"
        default:
            return nil
        }
    }

    private func applyMutationPrefixAtomically(
        events: [RemoteSyncEventRow],
        priceRows: [RemoteInventoryProductPriceRow],
        catalog: CatalogIncrementalFetchResult,
        historyRows: [RemoteSharedSheetSessionRow],
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        scope: Task126VerifiedOwnerStoreScope
    ) async throws -> SyncEventAtomicMutationResult {
        let candidates = events.sorted(by: { $0.id < $1.id }).map {
            SyncEventMutationCandidate(event: $0, ids: entityIDs(for: $0))
        }
        let defaults = defaults
        let atomicMutationProbeForTesting = atomicMutationProbeForTesting
        return try await Task.detached(priority: .userInitiated) {
            var forcedHistoryBlock: RemoteSyncEventRow?
            for attempt in 0..<2 {
                let context = ModelContext(modelContainer)
                context.autosaveEnabled = false
                var completed = SyncEventAtomicMutationResult()
                do {
                    try Task126OwnerStoreGate.revalidateAutomaticScope(
                        scope,
                        defaults: defaults
                    )
                    try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
                        scope,
                        defaults: defaults
                    ) {
                        try Task126OwnerStoreGate.validateLocalMutationContainerWithLeaseHeld(
                            modelContainer
                        )
                        try context.transaction {
                            let protected = try pendingRemoteIDs(
                                context: context,
                                ownerUserID: ownerUserID,
                                storeIdentity: scope.storeIdentity
                            )
                            var localCatalogIdentityIndex = try IncrementalLocalCatalogIdentityIndex(
                                context: context,
                                includeSuppliers: !catalog.suppliers.isEmpty,
                                includeCategories: !catalog.categories.isEmpty,
                                includeProducts: !catalog.products.isEmpty
                                    || !catalog.suppliers.isEmpty
                                    || !catalog.categories.isEmpty
                            )
                            let localPriceIdentityIndex = try IncrementalLocalProductPriceIdentityIndex(
                                context: context,
                                includePrices: !priceRows.isEmpty
                                    || catalog.products.contains(where: { $0.deletedAt != nil })
                            )
                            let localHistoryIdentityIndex: IncrementalLocalHistoryIdentityIndex?
                            if candidates.contains(where: { $0.event.domain == "history" }) {
                                let eligibleHistory = try HistoryIncrementalApplyService
                                    .localEntriesEligibleForIncrementalApply(
                                        historyRows,
                                        ownerUserID: ownerUserID,
                                        context: context,
                                        scope: scope
                                    )
                                localHistoryIdentityIndex = try IncrementalLocalHistoryIdentityIndex(
                                    entries: eligibleHistory
                                )
                            } else {
                                localHistoryIdentityIndex = nil
                            }
                            let pendingBlock = firstLateProtectedCandidate(
                                candidates,
                                protected: protected,
                                catalog: catalog,
                                priceRows: priceRows,
                                catalogIdentityIndex: localCatalogIdentityIndex,
                                priceIdentityIndex: localPriceIdentityIndex
                            ).map {
                                SyncEventDynamicPreflightBlock(
                                    event: $0.event,
                                    recoveryReason: "sync_event_dirty_local",
                                    statusReason: .dirtyLocal
                                )
                            }
                            let materializationBlock = try firstLateMaterializationConflictCandidate(
                                candidates,
                                catalog: catalog,
                                priceRows: priceRows,
                                historyRows: historyRows,
                                catalogIdentityIndex: localCatalogIdentityIndex,
                                priceIdentityIndex: localPriceIdentityIndex,
                                historyIdentityIndex: localHistoryIdentityIndex
                            ).map {
                                SyncEventDynamicPreflightBlock(
                                    event: $0.event,
                                    recoveryReason: "sync_event_remote_row_not_materializable",
                                    statusReason: .remoteRowNotMaterializable
                                )
                            }
                            let forcedBlock = forcedHistoryBlock.map {
                                SyncEventDynamicPreflightBlock(
                                    event: $0,
                                    recoveryReason: "sync_event_dirty_local",
                                    statusReason: .dirtyLocal
                                )
                            }
                            let lateBlock = [pendingBlock, materializationBlock, forcedBlock]
                                .compactMap { $0 }
                                .min(by: { $0.event.id < $1.event.id })
                            // Like the remote preflight, a late local blocker
                            // invalidates the entire current-state page. No
                            // prefix is safe to expose without versioned/as-of
                            // targeted reads.
                            let applied = lateBlock == nil ? candidates : []
                            var ids = mutationEntityIDs(from: applied)
                            let selectedPrices = priceRows.filter {
                                ids.priceIDs.contains($0.id)
                            }
                            ids.productIDs.formUnion(selectedPrices.map(\.productID))
                            let selectedCatalog = try catalogIncrementalMutationRows(
                                fetched: catalog,
                                eventIDs: ids
                            )
                            let selectedHistory = historyRows.filter {
                                ids.sessionIDs.contains($0.remoteID)
                            }
                            guard ids.sessionIDs.isSubset(
                                of: Set(selectedHistory.map(\.remoteID))
                            ) else {
                                throw SyncEventIncrementalApplyError.dynamicPreflightRequired
                            }

                            let catalogStarted = mcNowMillis()
                            let catalogResult = try applyTargetedCatalogMutationRows(
                                selectedCatalog,
                                protected: protected,
                                context: context,
                                localIdentityIndex: &localCatalogIdentityIndex
                            )
                            let catalogApplyMs = mcNowMillis() - catalogStarted
                            try atomicMutationProbeForTesting?(.afterCatalog)

                            let priceStarted = mcNowMillis()
                            let priceResult = try applyTargetedProductPriceMutationRows(
                                selectedPrices,
                                protected: protected,
                                context: context
                            )
                            let priceApplyMs = mcNowMillis() - priceStarted
                            try atomicMutationProbeForTesting?(.afterPrices)

                            let historyStarted = mcNowMillis()
                            let historyResult = try HistoryIncrementalApplyService
                                .applyRemoteSharedSheetSessions(
                                    selectedHistory,
                                    ownerUserID: ownerUserID,
                                    context: context,
                                    scope: scope
                                )
                            guard historyResult.skippedDirtyRemoteIDs.isEmpty else {
                                throw SyncEventLateDirtyHistoryError(
                                    remoteIDs: historyResult.skippedDirtyRemoteIDs
                                )
                            }
                            let historyApplyMs = mcNowMillis() - historyStarted
                            try atomicMutationProbeForTesting?(.afterHistory)
                            // ModelContext.transaction owns the only durable commit.
                            // Calling save() here would publish the three domains
                            // before a later error could roll the transaction back.
                            try atomicMutationProbeForTesting?(.afterMutationsBeforeCommit)
                            completed = SyncEventAtomicMutationResult(
                                appliedEvents: applied.map(\.event),
                                lateProtectedBlock: lateBlock,
                                catalog: catalogResult,
                                prices: priceResult,
                                history: historyResult,
                                catalogApplyMs: catalogApplyMs,
                                priceApplyMs: priceApplyMs,
                                historyApplyMs: historyApplyMs
                            )
                        }
                    }
                    return completed
                } catch let error as SyncEventLateDirtyHistoryError {
                    guard attempt == 0,
                          let event = candidates.first(where: {
                              !$0.ids.sessionIDs.isDisjoint(with: error.remoteIDs)
                          })?.event else {
                        throw SyncEventIncrementalApplyError.dynamicPreflightRequired
                    }
                    forcedHistoryBlock = event
                }
            }
            throw SyncEventIncrementalApplyError.dynamicPreflightRequired
        }.value
    }

    private func mutationEntityIDs(
        from candidates: [SyncEventMutationCandidate]
    ) -> SyncEventEntityIDSet {
        candidates.reduce(into: SyncEventEntityIDSet()) { result, candidate in
            switch candidate.event.domain {
            case "catalog":
                result.supplierIDs.formUnion(candidate.ids.supplierIDs)
                result.categoryIDs.formUnion(candidate.ids.categoryIDs)
                result.productIDs.formUnion(candidate.ids.productIDs)
            case "prices":
                result.priceIDs.formUnion(candidate.ids.priceIDs)
                result.productIDs.formUnion(candidate.ids.productIDs)
            case "history":
                result.sessionIDs.formUnion(candidate.ids.sessionIDs)
            default:
                break
            }
        }
    }

    private func firstLateProtectedCandidate(
        _ candidates: [SyncEventMutationCandidate],
        protected: IncrementalApplyProtectedRemoteIDs,
        catalog: CatalogIncrementalFetchResult,
        priceRows: [RemoteInventoryProductPriceRow],
        catalogIdentityIndex: IncrementalLocalCatalogIdentityIndex,
        priceIdentityIndex: IncrementalLocalProductPriceIdentityIndex
    ) -> SyncEventMutationCandidate? {
        if protected.hasCappedImportMarker {
            return candidates.min(by: { $0.event.id < $1.event.id })
        }
        let productRows = Dictionary(
            catalog.products.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let supplierRows = Dictionary(
            catalog.suppliers.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let categoryRows = Dictionary(
            catalog.categories.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let pricesByID = Dictionary(
            priceRows.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return candidates.sorted(by: { $0.event.id < $1.event.id }).first { candidate in
            if containsProtectedIDs(candidate.ids, protectedIDs: protected) {
                return true
            }

            for supplierID in candidate.ids.supplierIDs {
                if let row = supplierRows[supplierID],
                   row.deletedAt == nil,
                   protected.logicalKeys.contains(LocalPendingChangeLogicalKey.supplier(
                       remoteID: nil,
                       name: row.name
                   )) {
                    return true
                }
                if supplierRows[supplierID]?.deletedAt != nil,
                   catalogIdentityIndex.products(supplierRemoteID: supplierID).contains(where: {
                       isProtectedProduct($0, protected: protected)
                   }) {
                    return true
                }
            }
            for categoryID in candidate.ids.categoryIDs {
                if let row = categoryRows[categoryID],
                   row.deletedAt == nil,
                   protected.logicalKeys.contains(LocalPendingChangeLogicalKey.category(
                       remoteID: nil,
                       name: row.name
                   )) {
                    return true
                }
                if categoryRows[categoryID]?.deletedAt != nil,
                   catalogIdentityIndex.products(categoryRemoteID: categoryID).contains(where: {
                       isProtectedProduct($0, protected: protected)
                   }) {
                    return true
                }
            }

            var productIDs = candidate.ids.productIDs
            for priceID in candidate.ids.priceIDs {
                if let price = pricesByID[priceID] {
                    productIDs.insert(price.productID)
                }
            }
            for productID in productIDs {
                guard let row = productRows[productID] else { continue }
                if row.deletedAt == nil {
                    if protected.logicalKeys.contains(LocalPendingChangeLogicalKey.product(
                       remoteID: nil,
                       barcode: row.barcode
                    )) {
                        return true
                    }
                    if row.supplierID.map(protected.suppliers.contains) == true
                        || row.categoryID.map(protected.categories.contains) == true {
                        return true
                    }
                    if let supplierID = row.supplierID,
                       let supplier = supplierRows[supplierID],
                       protected.logicalKeys.contains(LocalPendingChangeLogicalKey.supplier(
                           remoteID: nil,
                           name: supplier.name
                       )) {
                        return true
                    }
                    if let categoryID = row.categoryID,
                       let category = categoryRows[categoryID],
                       protected.logicalKeys.contains(LocalPendingChangeLogicalKey.category(
                           remoteID: nil,
                           name: category.name
                       )) {
                        return true
                    }
                }
                if row.deletedAt != nil,
                   catalogIdentityIndex.products(remoteID: productID).contains(where: {
                    hasProtectedPrice(
                        for: $0,
                        protected: protected,
                        priceIdentityIndex: priceIdentityIndex
                    )
                }) {
                    return true
                }
            }
            for priceID in candidate.ids.priceIDs {
                guard let row = pricesByID[priceID],
                      let normalizedType = SupabasePullPreviewNormalizer.normalizedPriceType(row.type),
                      let effectiveAt = ProductPriceEffectiveAtCanonicalizer.canonicalDate(
                          from: row.effectiveAt
                      ),
                      let product = productRows[row.productID] else {
                    continue
                }
                let type = priceType(from: normalizedType)
                if protected.logicalKeys.contains(LocalPendingChangeLogicalKey.productPrice(
                    productRemoteID: row.productID,
                    productBarcode: product.barcode,
                    type: type,
                    effectiveAt: effectiveAt
                )) || protected.logicalKeys.contains(LocalPendingChangeLogicalKey.productPrice(
                    productRemoteID: nil,
                    productBarcode: product.barcode,
                    type: type,
                    effectiveAt: effectiveAt
                )) {
                    return true
                }
            }
            for sessionID in candidate.ids.sessionIDs {
                if protected.logicalKeys.contains(LocalPendingChangeLogicalKey.remoteEntity(
                    kind: .historySession,
                    remoteID: sessionID
                )) {
                    return true
                }
            }
            return false
        }
    }

    private func isProtectedProduct(
        _ product: Product,
        protected: IncrementalApplyProtectedRemoteIDs
    ) -> Bool {
        if product.remoteID.map(protected.products.contains) == true {
            return true
        }
        return protected.logicalKeys.contains(LocalPendingChangeLogicalKey.product(
            remoteID: nil,
            barcode: product.barcode
        ))
    }

    private func hasProtectedPrice(
        for product: Product,
        protected: IncrementalApplyProtectedRemoteIDs,
        priceIdentityIndex: IncrementalLocalProductPriceIdentityIndex
    ) -> Bool {
        priceIdentityIndex.prices(product: product).contains { price in
            if price.remoteID.map(protected.prices.contains) == true {
                return true
            }
            return protected.logicalKeys.contains(LocalPendingChangeLogicalKey.productPrice(
                productRemoteID: product.remoteID,
                productBarcode: product.barcode,
                type: price.type,
                effectiveAt: price.effectiveAt
            )) || protected.logicalKeys.contains(LocalPendingChangeLogicalKey.productPrice(
                productRemoteID: nil,
                productBarcode: product.barcode,
                type: price.type,
                effectiveAt: price.effectiveAt
            ))
        }
    }

    private func firstLateMaterializationConflictCandidate(
        _ candidates: [SyncEventMutationCandidate],
        catalog: CatalogIncrementalFetchResult,
        priceRows: [RemoteInventoryProductPriceRow],
        historyRows: [RemoteSharedSheetSessionRow],
        catalogIdentityIndex: IncrementalLocalCatalogIdentityIndex,
        priceIdentityIndex: IncrementalLocalProductPriceIdentityIndex,
        historyIdentityIndex: IncrementalLocalHistoryIdentityIndex?
    ) throws -> SyncEventMutationCandidate? {
        let pricesByID = Dictionary(
            priceRows.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let historyByID = Dictionary(
            historyRows.map { ($0.remoteID, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var claimedHistoryEntries: [ObjectIdentifier: UUID] = [:]
        for candidate in candidates.sorted(by: { $0.event.id < $1.event.id }) {
            var ids = mutationEntityIDs(from: [candidate])
            let selectedPrices = candidate.ids.priceIDs.compactMap { pricesByID[$0] }
            ids.productIDs.formUnion(selectedPrices.map(\.productID))
            let rows = try catalogIncrementalMutationRows(fetched: catalog, eventIDs: ids)
            if rows.suppliers.contains(where: {
                hasLocalSupplierIdentityConflict($0, index: catalogIdentityIndex)
            }) || rows.categories.contains(where: {
                hasLocalCategoryIdentityConflict($0, index: catalogIdentityIndex)
            }) || rows.products.contains(where: {
                hasLocalProductIdentityConflict($0, index: catalogIdentityIndex)
            }) {
                return candidate
            }
            for price in selectedPrices {
                guard let productRow = catalog.products.first(where: {
                    $0.id == price.productID
                }), !hasLocalProductPriceConflict(
                    price,
                    productRow: productRow,
                    catalogIdentityIndex: catalogIdentityIndex,
                    priceIdentityIndex: priceIdentityIndex
                ) else {
                    return candidate
                }
            }
            for sessionID in candidate.ids.sessionIDs {
                guard let row = historyByID[sessionID],
                      let historyIdentityIndex,
                      !historyIdentityIndex.hasConflict(with: row) else {
                    return candidate
                }
                if let objectID = historyIdentityIndex.resolvedObjectIdentifier(for: row) {
                    if let priorRemoteID = claimedHistoryEntries[objectID],
                       priorRemoteID != row.remoteID {
                        return candidate
                    }
                    claimedHistoryEntries[objectID] = row.remoteID
                }
            }
        }
        return nil
    }

    private func hasLocalSupplierIdentityConflict(
        _ row: RemoteInventorySupplierRow,
        index: IncrementalLocalCatalogIdentityIndex
    ) -> Bool {
        let byRemoteID = index.suppliers(remoteID: row.id)
        guard byRemoteID.count <= 1 else { return true }
        guard row.deletedAt == nil,
              let name = SupabasePullPreviewNormalizer.normalizedLookupName(row.name) else {
            return false
        }
        let byName = index.suppliers(canonicalName: name)
        guard byName.count <= 1 else { return true }
        if let remote = byRemoteID.first, let named = byName.first, remote !== named {
            return true
        }
        return byName.first.flatMap(\.remoteID).map { $0 != row.id } ?? false
    }

    private func hasLocalCategoryIdentityConflict(
        _ row: RemoteInventoryCategoryRow,
        index: IncrementalLocalCatalogIdentityIndex
    ) -> Bool {
        let byRemoteID = index.categories(remoteID: row.id)
        guard byRemoteID.count <= 1 else { return true }
        guard row.deletedAt == nil,
              let name = SupabasePullPreviewNormalizer.normalizedLookupName(row.name) else {
            return false
        }
        let byName = index.categories(canonicalName: name)
        guard byName.count <= 1 else { return true }
        if let remote = byRemoteID.first, let named = byName.first, remote !== named {
            return true
        }
        return byName.first.flatMap(\.remoteID).map { $0 != row.id } ?? false
    }

    private func hasLocalProductIdentityConflict(
        _ row: RemoteInventoryProductRow,
        index: IncrementalLocalCatalogIdentityIndex
    ) -> Bool {
        let byRemoteID = index.products(remoteID: row.id)
        guard byRemoteID.count <= 1 else { return true }
        guard row.deletedAt == nil,
              let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(row.barcode) else {
            return false
        }
        let byBarcode = index.products(canonicalBarcode: barcode)
        guard byBarcode.count <= 1 else { return true }
        if let remote = byRemoteID.first, let keyed = byBarcode.first, remote !== keyed {
            return true
        }
        return byBarcode.first.flatMap(\.remoteID).map { $0 != row.id } ?? false
    }

    private func hasLocalProductPriceConflict(
        _ row: RemoteInventoryProductPriceRow,
        productRow: RemoteInventoryProductRow,
        catalogIdentityIndex: IncrementalLocalCatalogIdentityIndex,
        priceIdentityIndex: IncrementalLocalProductPriceIdentityIndex
    ) -> Bool {
        guard let normalizedType = SupabasePullPreviewNormalizer.normalizedPriceType(row.type),
              let effectiveAt = ProductPriceEffectiveAtCanonicalizer.canonicalDate(
                  from: row.effectiveAt
              ),
              let canonicalAmount = PriceCanonicalizer.canonicalAmount(from: row.price) else {
            return true
        }
        let productByRemoteID = catalogIdentityIndex.products(remoteID: row.productID)
        guard let canonicalBarcode = SupabasePullPreviewNormalizer.normalizedBarcode(
            productRow.barcode
        ) else {
            return true
        }
        let productByBarcode = catalogIdentityIndex.products(
            canonicalBarcode: canonicalBarcode
        )
        guard productByRemoteID.count <= 1, productByBarcode.count <= 1 else { return true }
        if let remote = productByRemoteID.first,
           let keyed = productByBarcode.first,
           remote !== keyed {
            return true
        }
        if let keyed = productByBarcode.first,
           let existingRemoteID = keyed.remoteID,
           existingRemoteID != row.productID {
            return true
        }
        let targetProduct = productByRemoteID.first ?? productByBarcode.first
        let remoteMatches = priceIdentityIndex.prices(remoteID: row.id)
        guard remoteMatches.count <= 1 else { return true }
        guard let targetProduct else { return !remoteMatches.isEmpty }
        if let remotePrice = remoteMatches.first, remotePrice.product !== targetProduct {
            return true
        }
        let effectiveKey = ProductPriceEffectiveAtCanonicalizer.canonicalString(from: effectiveAt)
        let logicalMatches = priceIdentityIndex.prices(
            product: targetProduct,
            type: normalizedType,
            effectiveAt: effectiveKey
        )
        if let remotePrice = remoteMatches.first {
            return logicalMatches.contains { $0 !== remotePrice }
        }
        guard logicalMatches.count <= 1 else { return true }
        guard let local = logicalMatches.first else { return false }
        return local.remoteID != nil
            || PriceCanonicalizer.canonicalAmount(from: local.price) != canonicalAmount
    }

    private func recoverCanonicalDriftIfNeeded(
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        isAuthenticated: Bool,
        watermark: Int64,
        scope: Task126VerifiedOwnerStoreScope
    ) async throws -> SyncIncrementalPullSummary {
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        let remoteCounts = try await Task126OwnerStoreGate.withAutomaticScope(scope) {
            try await remote.fetchReconciliationRemoteCounts()
        }
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        let localCounts = try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            return try LocalDatabasePublicSummary.makeReconciliationAware(context: context)
        }.value
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
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

    private func lightReconcileKey(
        ownerUserID: UUID,
        storeIdentity: LocalStoreIdentity
    ) -> String {
        let storeID = storeIdentity.storeId
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return "sync.events.lightReconcile.lastAt.\(AccountBindingStore.accountHash(for: ownerUserID)).store.\(storeID)"
    }

    private func shouldRunLightReconcile(
        ownerUserID: UUID,
        storeIdentity: LocalStoreIdentity,
        scope: Task126VerifiedOwnerStoreScope,
        force: Bool
    ) throws -> Bool {
        try Task126OwnerStoreGate.revalidateAutomaticScope(scope, defaults: defaults)
        let key = lightReconcileKey(
            ownerUserID: ownerUserID,
            storeIdentity: storeIdentity
        )
        let now = Date().timeIntervalSince1970
        let minimumIntervalSeconds = 15.0
        if !force,
           let last = defaults.object(forKey: key) as? Double,
           now - last < minimumIntervalSeconds {
            return false
        }
        return true
    }

    private func recordLightReconcileCompleted(
        ownerUserID: UUID,
        storeIdentity: LocalStoreIdentity,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        let key = lightReconcileKey(
            ownerUserID: ownerUserID,
            storeIdentity: storeIdentity
        )
        try Task126OwnerStoreGate.withValidatedAutomaticScopeLease(
            scope,
            defaults: defaults
        ) {
            defaults.set(Date().timeIntervalSince1970, forKey: key)
        }
    }

    private func protectedRemoteIDs(
        ownerUserID: UUID,
        modelContainer: ModelContainer,
        storeIdentity: LocalStoreIdentity
    ) async throws -> IncrementalApplyProtectedRemoteIDs {
        try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            return try pendingRemoteIDs(
                context: context,
                ownerUserID: ownerUserID,
                storeIdentity: storeIdentity
            )
        }.value
    }

    private func classifyEvents(
        _ events: [RemoteSyncEventRow],
        ownerUserID: UUID,
        scopeShopID: UUID,
        protectedIDs: IncrementalApplyProtectedRemoteIDs,
        statusStore: SyncEventApplyStatusStore
    ) -> SyncEventApplyClassification {
        var classification = SyncEventApplyClassification()
        for event in events {
            // The watermark is a single ordered cursor. Once one event cannot
            // be applied, later events cannot be made durable independently:
            // they would be replayed on every retry and catalog-dependent
            // domains could become visible out of order. Stop at the first
            // blocker and let the durable full-recovery path publish one
            // coherent generation before the tail is examined again.
            guard classification.firstBlockedEventID == nil else { break }
            let ids = entityIDs(for: event)
            if event.requiresFullRecovery {
                classification.block(
                    eventID: event.id,
                    reason: "sync_event_backend_requires_full_recovery"
                )
                _ = statusStore.record(
                    event: event,
                    ownerUserID: ownerUserID,
                    scopeShopID: scopeShopID,
                    ids: ids,
                    status: .blocked,
                    reason: .missingEntityIDs
                )
                continue
            }
            guard isSupportedDomain(event.domain) else {
                classification.block(
                    eventID: event.id,
                    reason: "sync_event_unsupported_domain"
                )
                _ = statusStore.record(
                    event: event,
                    ownerUserID: ownerUserID,
                    scopeShopID: scopeShopID,
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
                _ = statusStore.record(
                    event: event,
                    ownerUserID: ownerUserID,
                    scopeShopID: scopeShopID,
                    ids: ids,
                    status: .blocked,
                    reason: .missingEntityIDs
                )
                continue
            }

            if ids.totalIDs > maximumEntityIDs(for: event.domain) {
                classification.block(
                    eventID: event.id,
                    reason: "sync_event_entity_ids_too_large"
                )
                _ = statusStore.record(
                    event: event,
                    ownerUserID: ownerUserID,
                    scopeShopID: scopeShopID,
                    ids: ids,
                    status: .blocked,
                    reason: .entityIDsTooLarge
                )
                continue
            }

            if protectedIDs.hasCappedImportMarker {
                classification.block(
                    eventID: event.id,
                    reason: "sync_event_dirty_local"
                )
                _ = statusStore.record(
                    event: event,
                    ownerUserID: ownerUserID,
                    scopeShopID: scopeShopID,
                    ids: ids,
                    status: .blocked,
                    reason: .dirtyLocal
                )
                continue
            }

            // Completeness and the bounded-ID contract are safety checks, not
            // apply decisions. They must run before self-origin suppression;
            // otherwise a malformed event from this device could be skipped
            // and the watermark advanced past data that was never proven.
            if let currentDeviceID,
               isSelfOrigin(event, currentDeviceID: currentDeviceID) {
                _ = statusStore.record(
                    event: event,
                    ownerUserID: ownerUserID,
                    scopeShopID: scopeShopID,
                    ids: ids,
                    status: .skipped,
                    reason: .selfOrigin
                )
                continue
            }

            if containsProtectedIDs(ids, protectedIDs: protectedIDs) {
                classification.block(
                    eventID: event.id,
                    reason: "sync_event_dirty_local"
                )
                _ = statusStore.record(
                    event: event,
                    ownerUserID: ownerUserID,
                    scopeShopID: scopeShopID,
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

    private func maximumEntityIDs(for domain: String) -> Int {
        switch domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "catalog":
            Self.catalogEntityIDsPerEvent
        case "prices":
            Self.priceEntityIDsPerEvent
        case "history":
            Self.historyEntityIDsPerEvent
        default:
            0
        }
    }

    private func recordApplied(
        _ events: [RemoteSyncEventRow],
        ownerUserID: UUID,
        scopeShopID: UUID,
        statusStore: SyncEventApplyStatusStore
    ) {
        for event in events {
            _ = statusStore.record(
                event: event,
                ownerUserID: ownerUserID,
                scopeShopID: scopeShopID,
                ids: entityIDs(for: event),
                status: .applied,
                reason: .applied
            )
        }
    }

    private func recordApplyOutcomes(
        _ events: [RemoteSyncEventRow],
        ownerUserID: UUID,
        scopeShopID: UUID,
        statusStore: SyncEventApplyStatusStore,
        missingRemoteDomains: Set<String>
    ) {
        for event in events {
            let isMissingRemote = missingRemoteDomains.contains(event.domain)
            _ = statusStore.record(
                event: event,
                ownerUserID: ownerUserID,
                scopeShopID: scopeShopID,
                ids: entityIDs(for: event),
                status: isMissingRemote ? .blocked : .applied,
                reason: isMissingRemote ? .missingRemote : .applied
            )
        }
    }

    private func firstDynamicPreflightBlock(
        events: [RemoteSyncEventRow],
        priceRows: [RemoteInventoryProductPriceRow],
        catalog: CatalogIncrementalFetchResult,
        historyRows: [RemoteSharedSheetSessionRow]
    ) -> SyncEventDynamicPreflightBlock? {
        let supplierIDs = Set(catalog.suppliers.map(\.id))
        let categoryIDs = Set(catalog.categories.map(\.id))
        let supplierRows = Dictionary(
            catalog.suppliers.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let categoryRows = Dictionary(
            catalog.categories.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let supplierCounts = catalog.suppliers.reduce(into: [UUID: Int]()) {
            $0[$1.id, default: 0] += 1
        }
        let categoryCounts = catalog.categories.reduce(into: [UUID: Int]()) {
            $0[$1.id, default: 0] += 1
        }
        let productCounts = catalog.products.reduce(into: [UUID: Int]()) {
            $0[$1.id, default: 0] += 1
        }
        let productRows = Dictionary(
            catalog.products.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let prices = Dictionary(
            priceRows.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let priceCounts = priceRows.reduce(into: [UUID: Int]()) {
            $0[$1.id, default: 0] += 1
        }
        let historyIDs = Set(historyRows.map(\.remoteID))
        let historyCounts = historyRows.reduce(into: [UUID: Int]()) {
            $0[$1.remoteID, default: 0] += 1
        }
        var seenSupplierNames: [String: UUID] = [:]
        var seenCategoryNames: [String: UUID] = [:]
        var seenProductBarcodes: [String: UUID] = [:]
        var seenPriceLogicalKeys: [String: UUID] = [:]
        var seenHistoryFingerprints: [String: UUID] = [:]

        func collides(
            key: String,
            remoteID: UUID,
            seen: inout [String: UUID]
        ) -> Bool {
            if let existing = seen[key] { return existing != remoteID }
            seen[key] = remoteID
            return false
        }

        func missingRemote(_ event: RemoteSyncEventRow) -> SyncEventDynamicPreflightBlock {
            SyncEventDynamicPreflightBlock(
                event: event,
                recoveryReason: "sync_event_missing_remote",
                statusReason: .missingRemote
            )
        }
        func priceParent(_ event: RemoteSyncEventRow) -> SyncEventDynamicPreflightBlock {
            SyncEventDynamicPreflightBlock(
                event: event,
                recoveryReason: "sync_event_price_parent_not_materializable",
                statusReason: .priceParentNotMaterializable
            )
        }
        func unmaterializable(_ event: RemoteSyncEventRow) -> SyncEventDynamicPreflightBlock {
            SyncEventDynamicPreflightBlock(
                event: event,
                recoveryReason: "sync_event_remote_row_not_materializable",
                statusReason: .remoteRowNotMaterializable
            )
        }
        func activeProductHasMaterializableRelations(_ row: RemoteInventoryProductRow) -> Bool {
            guard row.deletedAt == nil else { return true }
            let supplierIsMaterializable = row.supplierID.map { id in
                supplierCounts[id] == 1
                    && supplierRows[id].map(isMaterializableSupplier) == true
                    && supplierRows[id]?.deletedAt == nil
            } ?? true
            let categoryIsMaterializable = row.categoryID.map { id in
                categoryCounts[id] == 1
                    && categoryRows[id].map(isMaterializableCategory) == true
                    && categoryRows[id]?.deletedAt == nil
            } ?? true
            return supplierIsMaterializable && categoryIsMaterializable
        }

        for event in events.sorted(by: { $0.id < $1.id }) {
            let ids = entityIDs(for: event)
            switch event.domain {
            case "catalog":
                guard ids.supplierIDs.isSubset(of: supplierIDs),
                      ids.categoryIDs.isSubset(of: categoryIDs),
                      ids.productIDs.isSubset(of: Set(productRows.keys)),
                      ids.supplierIDs.allSatisfy({ supplierCounts[$0] == 1 }),
                      ids.categoryIDs.allSatisfy({ categoryCounts[$0] == 1 }),
                      ids.productIDs.allSatisfy({ productCounts[$0] == 1 }) else {
                    return missingRemote(event)
                }
                guard ids.supplierIDs.allSatisfy({
                    supplierRows[$0].map(isMaterializableSupplier) == true
                }), ids.categoryIDs.allSatisfy({
                    categoryRows[$0].map(isMaterializableCategory) == true
                }), ids.productIDs.allSatisfy({
                    productRows[$0].map(isMaterializableProduct) == true
                }) else {
                    return unmaterializable(event)
                }
                guard ids.productIDs.allSatisfy({ id in
                    productRows[id].map(activeProductHasMaterializableRelations) ?? false
                }) else {
                    return unmaterializable(event)
                }
                var relatedSupplierIDs = ids.supplierIDs
                var relatedCategoryIDs = ids.categoryIDs
                for productID in ids.productIDs {
                    guard let product = productRows[productID] else { continue }
                    if let supplierID = product.supplierID { relatedSupplierIDs.insert(supplierID) }
                    if let categoryID = product.categoryID { relatedCategoryIDs.insert(categoryID) }
                    if product.deletedAt == nil,
                       let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(product.barcode),
                       collides(
                           key: barcode,
                           remoteID: product.id,
                           seen: &seenProductBarcodes
                       ) {
                        return unmaterializable(event)
                    }
                }
                for supplierID in relatedSupplierIDs {
                    if let supplier = supplierRows[supplierID],
                       supplier.deletedAt == nil,
                       let name = SupabasePullPreviewNormalizer.normalizedLookupName(supplier.name),
                       collides(key: name, remoteID: supplier.id, seen: &seenSupplierNames) {
                        return unmaterializable(event)
                    }
                }
                for categoryID in relatedCategoryIDs {
                    if let category = categoryRows[categoryID],
                       category.deletedAt == nil,
                       let name = SupabasePullPreviewNormalizer.normalizedLookupName(category.name),
                       collides(key: name, remoteID: category.id, seen: &seenCategoryNames) {
                        return unmaterializable(event)
                    }
                }
            case "prices":
                guard ids.priceIDs.isSubset(of: Set(prices.keys)),
                      ids.priceIDs.allSatisfy({ priceCounts[$0] == 1 }) else {
                    return missingRemote(event)
                }
                guard ids.priceIDs.allSatisfy({
                    prices[$0].map(isMaterializablePrice) == true
                }) else {
                    return unmaterializable(event)
                }
                var referencedProductIDs = Set<UUID>()
                for id in ids.priceIDs {
                    guard let price = prices[id],
                          ids.productIDs.contains(price.productID),
                          productCounts[price.productID] == 1,
                          let product = productRows[price.productID],
                          isMaterializableProduct(product),
                          product.deletedAt == nil,
                          activeProductHasMaterializableRelations(product) else {
                        return priceParent(event)
                    }
                    referencedProductIDs.insert(price.productID)
                }
                guard referencedProductIDs == ids.productIDs else {
                    return priceParent(event)
                }
                for productID in referencedProductIDs {
                    guard let product = productRows[productID] else { continue }
                    if let barcode = SupabasePullPreviewNormalizer.normalizedBarcode(product.barcode),
                       collides(
                           key: barcode,
                           remoteID: product.id,
                           seen: &seenProductBarcodes
                       ) {
                        return unmaterializable(event)
                    }
                    if let supplierID = product.supplierID,
                       let supplier = supplierRows[supplierID],
                       let name = SupabasePullPreviewNormalizer.normalizedLookupName(supplier.name),
                       collides(key: name, remoteID: supplier.id, seen: &seenSupplierNames) {
                        return unmaterializable(event)
                    }
                    if let categoryID = product.categoryID,
                       let category = categoryRows[categoryID],
                       let name = SupabasePullPreviewNormalizer.normalizedLookupName(category.name),
                       collides(key: name, remoteID: category.id, seen: &seenCategoryNames) {
                        return unmaterializable(event)
                    }
                }
                for priceID in ids.priceIDs {
                    guard let price = prices[priceID],
                          let type = SupabasePullPreviewNormalizer.normalizedPriceType(price.type),
                          let effectiveAt = ProductPriceEffectiveAtCanonicalizer.canonicalDate(
                              from: price.effectiveAt
                          ) else {
                        return unmaterializable(event)
                    }
                    let logicalKey = [
                        price.productID.uuidString.lowercased(),
                        type,
                        ProductPriceEffectiveAtCanonicalizer.canonicalString(from: effectiveAt)
                    ].joined(separator: "|")
                    if collides(
                        key: logicalKey,
                        remoteID: price.id,
                        seen: &seenPriceLogicalKeys
                    ) {
                        return unmaterializable(event)
                    }
                }
            case "history":
                guard ids.sessionIDs.isSubset(of: historyIDs),
                      ids.sessionIDs.allSatisfy({ historyCounts[$0] == 1 }) else {
                    return missingRemote(event)
                }
                let rowsByID = Dictionary(
                    historyRows.map { ($0.remoteID, $0) },
                    uniquingKeysWith: { first, _ in first }
                )
                guard ids.sessionIDs.allSatisfy({
                    rowsByID[$0].map(isMaterializableHistory) == true
                }) else {
                    return unmaterializable(event)
                }
                for sessionID in ids.sessionIDs {
                    guard let row = rowsByID[sessionID], row.deletedAt == nil else { continue }
                    let fingerprint = HistorySessionPayloadCodec.logicalFingerprintHash(for: row)
                    if collides(
                        key: fingerprint,
                        remoteID: row.remoteID,
                        seen: &seenHistoryFingerprints
                    ) {
                        return unmaterializable(event)
                    }
                }
            default:
                return missingRemote(event)
            }
        }
        return nil
    }

    private func isMaterializableSupplier(_ row: RemoteInventorySupplierRow) -> Bool {
        SupabasePullPreviewNormalizer.semanticString(row.name) != nil
            && SupabaseRemoteDateParser.parse(row.updatedAt) != nil
            && isValidOptionalRemoteDate(row.deletedAt)
    }

    private func isMaterializableCategory(_ row: RemoteInventoryCategoryRow) -> Bool {
        SupabasePullPreviewNormalizer.semanticString(row.name) != nil
            && SupabaseRemoteDateParser.parse(row.updatedAt) != nil
            && isValidOptionalRemoteDate(row.deletedAt)
    }

    private func isMaterializableProduct(_ row: RemoteInventoryProductRow) -> Bool {
        SupabasePullPreviewNormalizer.semanticString(row.barcode) != nil
            && SupabaseRemoteDateParser.parse(row.updatedAt) != nil
            && isValidOptionalRemoteDate(row.deletedAt)
            && isValidOptionalRemoteDate(row.primaryImageUpdatedAt)
            && row.purchasePrice.map(isFiniteNumber) ?? true
            && row.retailPrice.map(isFiniteNumber) ?? true
            && row.stockQuantity.map(isFiniteNumber) ?? true
    }

    private func isMaterializablePrice(_ row: RemoteInventoryProductPriceRow) -> Bool {
        SupabasePullPreviewNormalizer.normalizedPriceType(row.type) != nil
            && PriceCanonicalizer.canonicalAmount(from: row.price) != nil
            && ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.effectiveAt) != nil
            && ProductPriceEffectiveAtCanonicalizer.canonicalDate(from: row.createdAt) != nil
            && row.updatedAt.map { SupabaseRemoteDateParser.parse($0) != nil } == true
    }

    private func isMaterializableHistory(_ row: RemoteSharedSheetSessionRow) -> Bool {
        guard let fullRow = try? JSONEncoder().encode(row),
              let data = try? JSONEncoder().encode(row.data),
              fullRow.count <= ShopSyncRecoveryLimits.maximumHistoryRowPayloadBytes,
              data.count <= ShopSyncRecoveryLimits.maximumHistoryDataBytes else {
            return false
        }
        if let overlay = row.sessionOverlay {
            guard let bytes = try? JSONEncoder().encode(overlay),
                  bytes.count <= HistorySessionPayloadCodec.maxOverlayBytes else {
                return false
            }
        }
        do {
            guard try HistorySessionPayloadCodec.parseUpdatedAtStrict(row.updatedAt) != nil else {
                return false
            }
            let deletedAt = try HistorySessionPayloadCodec.parseUpdatedAtStrict(row.deletedAt)
            guard deletedAt == nil else { return true }
            guard row.payloadVersion > 0 else { return false }
            _ = try HistorySessionPayloadCodec.parseTimestampStrict(row.timestamp)
            return true
        } catch {
            return false
        }
    }

    private func isValidOptionalRemoteDate(_ raw: String?) -> Bool {
        raw == nil || SupabaseRemoteDateParser.parse(raw) != nil
    }

    private func isFiniteNumber(_ value: Double) -> Bool {
        value.isFinite && !value.isNaN
    }

    private func extractEntityIDs(from events: [RemoteSyncEventRow]) -> SyncEventEntityIDSet {
        events.reduce(into: SyncEventEntityIDSet()) { result, event in
            let ids = entityIDs(for: event)
            switch event.domain {
            case "catalog":
                result.supplierIDs.formUnion(ids.supplierIDs)
                result.categoryIDs.formUnion(ids.categoryIDs)
                result.productIDs.formUnion(ids.productIDs)
            case "prices":
                result.priceIDs.formUnion(ids.priceIDs)
                result.productIDs.formUnion(ids.productIDs)
            case "history":
                result.sessionIDs.formUnion(ids.sessionIDs)
            default:
                break
            }
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

    private func isSelfOrigin(
        _ event: RemoteSyncEventRow,
        currentDeviceID: String
    ) -> Bool {
        let normalized = currentDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        if event.sourceDeviceKey == ShopSyncRecoveryCanonical.sha256(normalized) {
            return true
        }
        // Legacy/test recorder responses may still carry the raw value. The
        // production page adapter rejects it so it can never bypass the new
        // redacted read boundary.
        return event.sourceDeviceKey == nil && event.sourceDeviceID == normalized
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
        if event.domain == "catalog", !ids.isCompleteCatalog(changedCount: event.changedCount) {
            result.hasUnrecoverableCatalogGap = true
        }
        if event.domain == "history", !ids.isCompleteHistory(changedCount: event.changedCount) {
            result.hasUnrecoverableHistoryGap = true
        }
        if event.domain == "prices", !ids.isCompletePrices(changedCount: event.changedCount) {
            result.hasUnrecoverablePriceGap = true
        }
    }

}

private nonisolated struct IncrementalLocalHistoryIdentityIndex {
    private var byRemoteID: [UUID: [HistoryEntry]] = [:]
    private var byUID: [UUID: [HistoryEntry]] = [:]
    private var byLogicalFingerprint: [String: [HistoryEntry]] = [:]

    init(entries: [HistoryEntry]) throws {
        guard entries.count <= ShopSyncRecoveryLimits.maximumRows(for: .history) else {
            throw ShopSyncRecoveryContractError.resourceBudgetExceeded(domain: .history)
        }
        for (index, entry) in entries.enumerated() {
            if index.isMultiple(of: 64) { try Task.checkCancellation() }
            if let remoteID = entry.remoteID {
                byRemoteID[remoteID, default: []].append(entry)
            }
            byUID[entry.uid, default: []].append(entry)
            guard entry.remoteDeletedAt == nil else { continue }
            let snapshot = HistorySessionPayloadSnapshotFactory.snapshot(
                for: entry,
                ensureRemoteID: false
            )
            let fingerprint = HistorySessionPayloadCodec.logicalFingerprintHash(for: snapshot)
            byLogicalFingerprint[fingerprint, default: []].append(entry)
        }
    }

    func hasConflict(with row: RemoteSharedSheetSessionRow) -> Bool {
        var seenIdentity = Set<ObjectIdentifier>()
        let identityMatches = (byRemoteID[row.remoteID] ?? []) + (byUID[row.remoteID] ?? [])
        let uniqueIdentityMatches = identityMatches.filter {
            seenIdentity.insert(ObjectIdentifier($0)).inserted
        }
        // Duplicate physical identities are unsafe even for a tombstone: a
        // dictionary-based apply could otherwise tombstone one row and leave
        // another active while advancing the watermark.
        guard uniqueIdentityMatches.count <= 1 else { return true }
        guard row.deletedAt == nil else { return false }

        let fingerprint = HistorySessionPayloadCodec.logicalFingerprintHash(for: row)
        let logicalMatches = byLogicalFingerprint[fingerprint] ?? []
        guard logicalMatches.count <= 1 else { return true }
        if let identity = uniqueIdentityMatches.first {
            return logicalMatches.contains { $0 !== identity }
        }
        return logicalMatches.first?.remoteID.map { $0 != row.remoteID } ?? false
    }

    func resolvedObjectIdentifier(for row: RemoteSharedSheetSessionRow) -> ObjectIdentifier? {
        var seenIdentity = Set<ObjectIdentifier>()
        let identityMatches = ((byRemoteID[row.remoteID] ?? []) + (byUID[row.remoteID] ?? []))
            .filter { seenIdentity.insert(ObjectIdentifier($0)).inserted }
        guard identityMatches.count <= 1 else { return nil }
        if let identity = identityMatches.first {
            return ObjectIdentifier(identity)
        }
        guard row.deletedAt == nil else { return nil }
        let fingerprint = HistorySessionPayloadCodec.logicalFingerprintHash(for: row)
        let logicalMatches = byLogicalFingerprint[fingerprint] ?? []
        guard logicalMatches.count == 1 else { return nil }
        return ObjectIdentifier(logicalMatches[0])
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

private nonisolated struct SyncEventMutationCandidate: Sendable {
    let event: RemoteSyncEventRow
    let ids: SyncEventEntityIDSet
}

private nonisolated struct SyncEventAtomicMutationResult: Sendable {
    var appliedEvents: [RemoteSyncEventRow] = []
    var lateProtectedBlock: SyncEventDynamicPreflightBlock?
    var catalog = TargetedCatalogApplyResult()
    var prices = ProductPriceApplyResult(
        inserted: 0,
        skippedExisting: 0,
        totalConsidered: 0
    )
    var history = HistoryIncrementalApplyRowsResult()
    var catalogApplyMs = 0
    var priceApplyMs = 0
    var historyApplyMs = 0
}

private nonisolated struct SyncEventLateDirtyHistoryError: Error, Sendable {
    let remoteIDs: Set<UUID>
}

private nonisolated struct SyncEventDynamicPreflightBlock: Sendable {
    let event: RemoteSyncEventRow
    let recoveryReason: String
    let statusReason: SyncEventApplyStatusReason
}
