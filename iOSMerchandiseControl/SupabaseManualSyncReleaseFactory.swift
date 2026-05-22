import Foundation
import SwiftData

@MainActor
enum SupabaseManualSyncReleaseFactory {
    static func makeViewModel(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        inventoryService: SupabaseInventoryService? = nil,
        pullPreviewService: SupabasePullPreviewService? = nil,
        manualPushService: SupabaseManualPushService? = nil,
        activityRecorder: (any SyncEventRecording)? = nil
    ) -> SupabaseManualSyncViewModel {
        let modelContainer = context.container
        let remotePreviewAdapter = pullPreviewService.map {
            SupabaseManualSyncPullPreviewAdapter(service: $0, modelContainer: modelContainer)
        }
        let remotePreviewProvider: (any SupabaseManualSyncRemotePreviewProviding)? = remotePreviewAdapter.map { $0 }
        let catalogPushProvider: (any SupabaseManualSyncCatalogPushProviding)? = manualPushService.map {
            SupabaseManualSyncReleasePushAdapter(
                context: context,
                manualPushService: $0
            )
        }
        let productPriceProvider: (any SupabaseManualSyncProductPriceSyncProviding)? = inventoryService.map {
            SupabaseManualSyncReleaseProductPriceAdapter(
                modelContainer: modelContainer,
                remote: $0
            )
        }
        let activityRegistrationProvider: (any SupabaseManualSyncActivityRegistrationProviding)? = activityRecorder.map {
            SupabaseManualSyncReleaseActivityRegistrationAdapter(context: context, recorder: $0)
        }
        let historySessionProvider: (any SupabaseManualSyncHistorySessionSyncProviding)? = inventoryService.map {
            SupabaseManualSyncReleaseHistorySessionAdapter(
                modelContainer: modelContainer,
                remote: $0,
                recorder: activityRecorder
            )
        }
        let incrementalPullProvider: (any SupabaseManualSyncIncrementalPullProviding)? = inventoryService.map {
            SupabaseManualSyncReleaseIncrementalPullAdapter(
                modelContainer: modelContainer,
                remote: $0
            )
        }
        let localPendingChangeCounter = LocalPendingChangePendingAdapter(context: context)

        let dependencies = SupabaseManualSyncCoordinator.Dependencies(
            authGate: SupabaseManualSyncReleaseAuthGate(authViewModel: authViewModel),
            baselineGate: SupabaseManualSyncReleaseBaselineGate(context: context, authViewModel: authViewModel),
            pendingSnapshot: SupabaseManualSyncLocalPendingSnapshotProvider(
                sessionProvider: authViewModel,
                localPendingChangeCounter: localPendingChangeCounter,
                catalogPendingCounter: SupabaseManualSyncCatalogPendingAdapter(context: context),
                outboxPendingCounter: SupabaseManualSyncOutboxPendingAdapter(context: context)
            ),
            phaseSimulation: SupabaseManualSyncReleaseDryRunPhaseSimulator(),
            remotePreviewProvider: remotePreviewProvider
        )

        return SupabaseManualSyncViewModel(
            coordinator: SupabaseManualSyncCoordinator(dependencies: dependencies),
            capabilities: .releaseCurrent(
                remotePreviewProvider: remotePreviewProvider,
                catalogPushProvider: catalogPushProvider,
                productPriceProvider: productPriceProvider,
                activityRegistrationProvider: activityRegistrationProvider
            ),
            initialAuthPresentationContext: SupabaseManualSyncAuthPresentationContext(
                isSignedIn: authViewModel.isSignedIn,
                canSignIn: authViewModel.canSignIn,
                isTransitioning: authViewModel.isTransitioning
            ),
            remotePreviewStaging: remotePreviewAdapter,
            localApplyService: SupabasePullApplyService(),
            localApplyContext: context,
            localApplyModelContainer: modelContainer,
            isLocalApplyAuthenticated: { authViewModel.isSignedIn },
            currentLocalApplyOwnerID: { authViewModel.isSignedIn ? authViewModel.sessionInfo?.userID : nil },
            catalogPushProvider: catalogPushProvider,
            currentCatalogPushOwnerID: { authViewModel.isSignedIn ? authViewModel.sessionInfo?.userID : nil },
            productPriceProvider: productPriceProvider,
            currentProductPriceOwnerID: { authViewModel.isSignedIn ? authViewModel.sessionInfo?.userID : nil },
            activityRegistrationProvider: activityRegistrationProvider,
            currentActivityRegistrationOwnerID: { authViewModel.isSignedIn ? authViewModel.sessionInfo?.userID : nil },
            historySessionProvider: historySessionProvider,
            currentHistorySessionOwnerID: { authViewModel.isSignedIn ? authViewModel.sessionInfo?.userID : nil },
            incrementalPullProvider: incrementalPullProvider,
            baselineStatusProvider: {
                do {
                    return try SupabaseCatalogBaselineReader().debugSummary(
                        context: context,
                        currentUserUUID: authViewModel.isSignedIn ? authViewModel.sessionInfo?.userID : nil
                    )
                } catch {
                    return .absent
                }
            }
        )
    }
}

@MainActor
private final class SupabaseManualSyncReleaseIncrementalPullAdapter: SupabaseManualSyncIncrementalPullProviding {
    private let modelContainer: ModelContainer
    private let remote: SupabaseInventoryService

    init(
        modelContainer: ModelContainer,
        remote: SupabaseInventoryService
    ) {
        self.modelContainer = modelContainer
        self.remote = remote
    }

    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SupabaseSyncEventIncrementalApplySummary {
        try await SupabaseSyncEventIncrementalApplyService(
            eventFetcher: remote,
            inventoryService: remote
        ).applyNextEvents(
            ownerUserID: ownerUserID,
            modelContainer: modelContainer,
            isAuthenticated: true
        )
    }
}

@MainActor
private final class SupabaseManualSyncReleaseHistorySessionAdapter: SupabaseManualSyncHistorySessionSyncProviding {
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
        mode: SupabaseManualSyncHistorySessionMode,
        onProgress: @escaping @MainActor @Sendable (HistorySessionSyncProgress) -> Void
    ) async throws -> SupabaseManualSyncHistorySessionSummary {
        let modelContainer = self.modelContainer
        let remote = self.remote
        let recorder = self.recorder
        return try await Task.detached(priority: .utility) {
            let context = ModelContext(modelContainer)
            let service = HistorySessionSyncService(remote: remote)
            if mode == .incremental {
                let entries = try context.fetch(
                    FetchDescriptor<HistoryEntry>(
                        sortBy: [SortDescriptor(\HistoryEntry.timestamp, order: .reverse)]
                    )
                )
                let push = try await service.pushPendingHistorySessions(
                    entries: entries,
                    ownerUserID: ownerUserID,
                    context: context,
                    includeSynced: false,
                    onProgress: onProgress
                )
                try context.save()
                if push.uploadedCount > 0 {
                    try await Self.recordHistorySyncEvent(
                        recorder: recorder,
                        ownerUserID: ownerUserID,
                        remoteIDs: push.pushedRemoteIDs
                    )
                }
                return SupabaseManualSyncHistorySessionSummary(
                    uploaded: push.uploadedCount,
                    skippedClean: push.skippedCleanCount,
                    skippedOversized: push.skippedOversizedCount
                )
            }
            let initialPull = try await service.pullHistorySessionsFromCloud(
                ownerUserID: ownerUserID,
                context: context,
                onProgress: onProgress
            )
            try context.save()
            let entries = try context.fetch(
                FetchDescriptor<HistoryEntry>(
                    sortBy: [SortDescriptor(\HistoryEntry.timestamp, order: .reverse)]
                )
            )
            let push = try await service.pushPendingHistorySessions(
                entries: entries,
                ownerUserID: ownerUserID,
                context: context,
                includeSynced: true,
                onProgress: onProgress
            )
            try context.save()
            let confirmPull = try await service.pullHistorySessionsFromCloud(
                ownerUserID: ownerUserID,
                context: context,
                onProgress: onProgress
            )
            try context.save()
            if push.uploadedCount > 0 {
                try await Self.recordHistorySyncEvent(
                    recorder: recorder,
                    ownerUserID: ownerUserID,
                    remoteIDs: push.pushedRemoteIDs
                )
            }
            return SupabaseManualSyncHistorySessionSummary(
                uploaded: push.uploadedCount,
                inserted: initialPull.insertedCount + confirmPull.insertedCount,
                updated: initialPull.updatedCount + confirmPull.updatedCount,
                skippedClean: push.skippedCleanCount + initialPull.skippedCleanCount + confirmPull.skippedCleanCount,
                skippedDirtyLocal: initialPull.skippedDirtyLocalCount + confirmPull.skippedDirtyLocalCount,
                skippedOversized: push.skippedOversizedCount
            )
        }.value
    }

    private nonisolated static func recordHistorySyncEvent(
        recorder: (any SyncEventRecording)?,
        ownerUserID: UUID,
        remoteIDs: Set<UUID>
    ) async throws {
        guard let recorder, !remoteIDs.isEmpty else { return }
        let sortedIDs = remoteIDs.sorted { $0.uuidString < $1.uuidString }
        let request = SyncEventRecordRequest(
            domain: "history",
            eventType: "history_changed",
            changedCount: sortedIDs.count,
            entityIDs: .object([
                "session_ids": .array(sortedIDs.map { .string($0.uuidString.lowercased()) })
            ]),
            metadata: .object([
                "source": .string("ios_history_session_push"),
                "uploaded_count": .number(Double(sortedIDs.count))
            ]),
            source: "ios_history_session_push",
            sourceDeviceID: nil,
            batchID: UUID(),
            clientEventID: "ios-history-\(ownerUserID.uuidString.lowercased())-\(UUID().uuidString.lowercased())"
        )
        _ = try await recorder.record(request)
    }
}

@MainActor
private final class SupabaseManualSyncReleaseProductPriceAdapter: SupabaseManualSyncProductPriceSyncProviding {
    private let modelContainer: ModelContainer
    private let remote: SupabaseInventoryService
    private var stagedPendingBatchesByFingerprint: [String: LocalPendingAggregatedProductPriceBatch] = [:]

    init(
        modelContainer: ModelContainer,
        remote: SupabaseInventoryService
    ) {
        self.modelContainer = modelContainer
        self.remote = remote
    }

    func makeApplyPlan(ownerUserID: UUID) async throws -> ProductPriceApplyPlan {
        let modelContainer = self.modelContainer
        let remote = self.remote
        return try await Task.detached(priority: .userInitiated) {
            let context = ModelContext(modelContainer)
            return try await SupabaseProductPriceApplyService(fetcher: remote).loadBootstrapPreviewSample(
                context: context,
                sessionSnapshot: ProductPriceApplySessionSnapshot(userID: ownerUserID)
            )
        }.value
    }

    func apply(plan: ProductPriceApplyPlan, ownerUserID: UUID) async throws -> ProductPriceApplyResult {
        try await apply(plan: plan, ownerUserID: ownerUserID, onProgress: { _ in })
    }

    func apply(
        plan: ProductPriceApplyPlan,
        ownerUserID: UUID,
        onProgress: @escaping @MainActor @Sendable (ProductPricePagedApplyProgress) -> Void
    ) async throws -> ProductPriceApplyResult {
        let modelContainer = self.modelContainer
        let remote = self.remote
        return try await Task.detached(priority: .userInitiated) {
            let context = ModelContext(modelContainer)
            return try await SupabaseProductPriceApplyService(fetcher: remote).applyPagedFullPull(
                plan: plan,
                context: context,
                currentSessionSnapshot: ProductPriceApplySessionSnapshot(userID: ownerUserID),
                onProgress: onProgress
            )
        }.value
    }

    func makePushPlan(ownerUserID: UUID) async throws -> ProductPricePushDryRunPlan {
        let context = ModelContext(modelContainer)
        let aggregatedPlan = try await LocalPendingAggregatedPushPlanner(
            context: context,
            priceRemoteFetcher: remote,
            includesCatalog: false,
            includesProductPrice: true
        ).makePlan(ownerUserID: ownerUserID)
        guard aggregatedPlan.blockers.isEmpty else {
            stagedPendingBatchesByFingerprint.removeAll()
            return Self.blockedPricePlan(
                ownerUserID: ownerUserID,
                blockerCount: max(1, aggregatedPlan.blockers.count),
                generatedAt: aggregatedPlan.generatedAt
            )
        }
        guard let batch = aggregatedPlan.productPriceBatch else {
            stagedPendingBatchesByFingerprint.removeAll()
            return Self.emptyPricePlan(ownerUserID: ownerUserID, generatedAt: aggregatedPlan.generatedAt)
        }
        stagedPendingBatchesByFingerprint[productPricePushFingerprint(batch.plan)] = batch
        return batch.plan
    }

    func push(plan: ProductPricePushDryRunPlan, ownerUserID: UUID) async throws -> ProductPriceManualPushResult {
        let context = ModelContext(modelContainer)
        let batchFingerprint = productPricePushFingerprint(plan)
        let pendingBatch = stagedPendingBatchesByFingerprint[batchFingerprint]
        if let pendingBatch {
            try LocalPendingAggregatedPushStateStore(context: context).markSent(
                changeIDs: pendingBatch.changeIDs,
                ownerUserID: ownerUserID,
                planFingerprint: batchFingerprint
            )
        }
        let result: ProductPriceManualPushResult
        do {
            let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: plan)
            guard snapshot.ownerUserID == ownerUserID else {
                throw ProductPriceManualPushError.invalidPayload
            }
            result = try await SupabaseProductPriceManualPushService(remote: remote).push(snapshot: snapshot)
            if result.isVerifiedSuccess {
                _ = try ProductPriceManualPushIdentityReconciler().linkVerifiedPayloads(
                    snapshot.payloads,
                    context: context
                )
                _ = try await ProductPriceCoveredProductChangeReconciler()
                    .syncRemoteProductsAndAcknowledgeCoveredProductPriceFieldChanges(
                        payloads: snapshot.payloads,
                        ownerUserID: ownerUserID,
                        remote: remote,
                        context: context
                    )
            }
        } catch {
            if let pendingBatch {
                try? LocalPendingAggregatedPushStateStore(context: context).markRetryable(
                    changeIDs: pendingBatch.changeIDs,
                    ownerUserID: ownerUserID
                )
            }
            throw error
        }
        if let pendingBatch {
            if result.isVerifiedSuccess {
                try LocalPendingAggregatedPushStateStore(context: context).markAcknowledged(
                    changeIDs: pendingBatch.changeIDs,
                    ownerUserID: ownerUserID
                )
            } else {
                try LocalPendingAggregatedPushStateStore(context: context).markRetryable(
                    changeIDs: pendingBatch.changeIDs,
                    ownerUserID: ownerUserID
                )
            }
            stagedPendingBatchesByFingerprint.removeValue(forKey: batchFingerprint)
        }
        let telemetryResult = SupabaseManualSyncAggregatedPushOutboxProducer(context: context).produce(
            .productPriceManualPush(
                result: result,
                ownerUserID: ownerUserID,
                currentOwnerUserID: ownerUserID
            )
        )
        if result.isVerifiedSuccess, !telemetryResult.isAggregatedPushSuccess {
            return ProductPriceManualPushResult(
                insertedCount: result.insertedCount,
                verification: result.verification,
                fingerprint: result.fingerprint,
                confirmedRemoteIDs: result.confirmedRemoteIDs,
                needsTechnicalFollowUp: true
            )
        }
        return result
    }

    private func productPricePushFingerprint(_ plan: ProductPricePushDryRunPlan) -> String {
        let candidates = plan.candidates.map { line -> String in
            [
                line.key?.stableID ?? "",
                line.canonicalPrice?.value ?? "",
                line.createdAtCanonical ?? "",
                line.source ?? "",
                line.note ?? ""
            ].joined(separator: "|")
        }
        let summary = [
            "local:\(plan.summary.localPriceCount)",
            "ready:\(plan.summary.readyCandidates)",
            "present:\(plan.summary.alreadyPresentRemote)",
            "remoteConflict:\(plan.summary.conflictSameKeyDifferentPrice)",
            "localDuplicate:\(plan.summary.localDuplicateSameKey)",
            "localConflict:\(plan.summary.localConflictSameKeyDifferentPrice)",
            "blockedNoRemote:\(plan.summary.blockedNoRemoteID)",
            "blockedTotal:\(plan.summary.blockedTotal)",
            "invalid:\(plan.summary.excludedInvalidLocal)",
            "dedupe:\(plan.remoteDedupeStatus.stableAggregatedFingerprintComponent)"
        ]
        return (candidates + summary).joined(separator: "\n")
    }

    private static func emptyPricePlan(ownerUserID: UUID, generatedAt: Date) -> ProductPricePushDryRunPlan {
        ProductPricePushDryRunPlan(
            generatedAt: generatedAt,
            sessionSnapshot: ProductPricePushDryRunSessionSnapshot(userID: ownerUserID, lastLinkedUserID: ownerUserID),
            remoteDedupeStatus: .notNeeded,
            summary: ProductPricePushDryRunSummary(
                localPriceCount: 0,
                remoteRowsRead: 0,
                remotePagesRead: 0,
                readyCandidates: 0,
                alreadyPresentRemote: 0,
                conflictSameKeyDifferentPrice: 0,
                localDuplicateSameKey: 0,
                localConflictSameKeyDifferentPrice: 0,
                blockedNoRemoteID: 0,
                blockedNoAuth: 0,
                blockedAccountMismatch: 0,
                blockedBaselineMissing: 0,
                blockedBaselineStale: 0,
                blockedBaselinePartial: 0,
                excludedInvalidLocal: 0
            ),
            candidates: [],
            alreadyPresentRemote: [],
            conflictSameKeyDifferentPrice: [],
            localDuplicateSameKey: [],
            localConflictSameKeyDifferentPrice: [],
            blockedNoRemoteID: [],
            excludedInvalidLocal: []
        )
    }

    private static func blockedPricePlan(
        ownerUserID: UUID,
        blockerCount: Int,
        generatedAt: Date
    ) -> ProductPricePushDryRunPlan {
        ProductPricePushDryRunPlan(
            generatedAt: generatedAt,
            sessionSnapshot: ProductPricePushDryRunSessionSnapshot(userID: ownerUserID, lastLinkedUserID: ownerUserID),
            remoteDedupeStatus: .notNeeded,
            summary: ProductPricePushDryRunSummary(
                localPriceCount: blockerCount,
                remoteRowsRead: 0,
                remotePagesRead: 0,
                readyCandidates: 0,
                alreadyPresentRemote: 0,
                conflictSameKeyDifferentPrice: 0,
                localDuplicateSameKey: 0,
                localConflictSameKeyDifferentPrice: 0,
                blockedNoRemoteID: blockerCount,
                blockedNoAuth: 0,
                blockedAccountMismatch: 0,
                blockedBaselineMissing: 0,
                blockedBaselineStale: 0,
                blockedBaselinePartial: 0,
                excludedInvalidLocal: 0
            ),
            candidates: [],
            alreadyPresentRemote: [],
            conflictSameKeyDifferentPrice: [],
            localDuplicateSameKey: [],
            localConflictSameKeyDifferentPrice: [],
            blockedNoRemoteID: [],
            excludedInvalidLocal: []
        )
    }
}

@MainActor
private final class SupabaseManualSyncReleasePushAdapter: SupabaseManualSyncCatalogPushProviding {
    private let context: ModelContext
    private let manualPushService: SupabaseManualPushService
    private let preflightService: SupabaseManualPushPreflightService
    private let baselineReader: SupabaseCatalogBaselineReader
    private var stagedPendingBatchesByFingerprint: [String: LocalPendingAggregatedCatalogBatch] = [:]

    init(
        context: ModelContext,
        manualPushService: SupabaseManualPushService,
        preflightService: SupabaseManualPushPreflightService = SupabaseManualPushPreflightService(),
        baselineReader: SupabaseCatalogBaselineReader = SupabaseCatalogBaselineReader()
    ) {
        self.context = context
        self.manualPushService = manualPushService
        self.preflightService = preflightService
        self.baselineReader = baselineReader
    }

    func makePushPlan(ownerUserID: UUID) async throws -> ManualPushPlan {
        let aggregatedPlan = try await LocalPendingAggregatedPushPlanner(
            context: context,
            includesCatalog: true,
            includesProductPrice: false
        ).makePlan(ownerUserID: ownerUserID)
        guard aggregatedPlan.blockers.isEmpty else {
            stagedPendingBatchesByFingerprint.removeAll()
            return Self.blockedCatalogPlan(
                ownerUserID: ownerUserID,
                blockerCount: max(1, aggregatedPlan.blockers.count),
                generatedAt: aggregatedPlan.generatedAt
            )
        }
        guard let batch = aggregatedPlan.catalogBatch else {
            stagedPendingBatchesByFingerprint.removeAll()
            return ManualPushPlan(
                generatedAt: aggregatedPlan.generatedAt,
                ownerUserID: ownerUserID,
                candidates: [],
                blockedReasons: [],
                warnings: [],
                futureEventChangedCount: 0
            )
        }
        stagedPendingBatchesByFingerprint[batch.plan.planFingerprint] = batch
        return batch.plan
    }

    func execute(plan: ManualPushPlan, ownerUserID: UUID) async -> SupabaseManualPushResult {
        let pendingBatch = stagedPendingBatchesByFingerprint[plan.planFingerprint]
        if let pendingBatch {
            do {
                try LocalPendingAggregatedPushStateStore(context: context).markSent(
                    changeIDs: pendingBatch.changeIDs,
                    ownerUserID: ownerUserID,
                    planFingerprint: plan.planFingerprint
                )
            } catch {
                return .blocked(message: "Local pending state could not be prepared.")
            }
        }
        let result = await manualPushService.execute(
            plan: plan,
            context: context,
            ownerUserID: ownerUserID
        )
        if let pendingBatch {
            applyPendingStateTransition(
                result: result,
                changeIDs: pendingBatch.changeIDs,
                ownerUserID: ownerUserID
            )
            stagedPendingBatchesByFingerprint.removeValue(forKey: plan.planFingerprint)
        }
        guard result.confirmedCatalogChangeCount > 0 else {
            return result
        }
        let telemetry = SupabaseManualSyncAggregatedPushOutboxProducer(context: context).produce(
            .catalogManualPush(
                result: result,
                ownerUserID: ownerUserID,
                currentOwnerUserID: ownerUserID,
                planFingerprint: plan.planFingerprint
            )
        )
        if result.status == .completed, !telemetry.isAggregatedPushSuccess {
            return SupabaseManualPushResult(
                status: .completedBaselineRefreshFailed,
                supplierCreates: result.supplierCreates,
                supplierUpdates: result.supplierUpdates,
                supplierLinks: result.supplierLinks,
                categoryCreates: result.categoryCreates,
                categoryUpdates: result.categoryUpdates,
                categoryLinks: result.categoryLinks,
                productCreates: result.productCreates,
                productUpdates: result.productUpdates,
                productLinks: result.productLinks,
                touchedIDs: result.touchedIDs,
                baselineRunID: result.baselineRunID,
                message: "Technical follow-up required after verified push."
            )
        }
        return result
    }

    private func applyPendingStateTransition(
        result: SupabaseManualPushResult,
        changeIDs: [String],
        ownerUserID: UUID
    ) {
        let store = LocalPendingAggregatedPushStateStore(context: context)
        switch result.status {
        case .completed, .completedBaselineRefreshFailed:
            try? store.markAcknowledged(changeIDs: changeIDs, ownerUserID: ownerUserID)
        case .partial, .failedBeforeWrite:
            try? store.markRetryable(changeIDs: changeIDs, ownerUserID: ownerUserID)
        case .blockedBeforeWrite:
            try? store.markBlocked(changeIDs: changeIDs, ownerUserID: ownerUserID)
        }
    }

    private static func blockedCatalogPlan(
        ownerUserID: UUID,
        blockerCount: Int,
        generatedAt: Date
    ) -> ManualPushPlan {
        ManualPushPlan(
            generatedAt: generatedAt,
            ownerUserID: ownerUserID,
            candidates: [],
            blockedReasons: Array(repeating: .blockedStaleOrPartialBaseline, count: blockerCount),
            warnings: [],
            futureEventChangedCount: 0
        )
    }

    private func mapBaselineResult(
        _ result: SupabaseCatalogBaselineReadResult,
        ownerUserID: UUID
    ) -> (runID: UUID?, baseline: ManualPushBaseline?, accountState: ManualPushAccountState) {
        switch result {
        case .available(let snapshot):
            return (
                snapshot.runID,
                snapshot.baseline,
                ManualPushAccountState(
                    currentUserID: ownerUserID,
                    lastLinkedUserID: snapshot.ownerUserUUID
                )
            )
        case .missing:
            return (
                nil,
                nil,
                ManualPushAccountState(currentUserID: ownerUserID, lastLinkedUserID: ownerUserID)
            )
        case .accountMismatch:
            return (
                nil,
                nil,
                ManualPushAccountState(currentUserID: ownerUserID, lastLinkedUserID: UUID())
            )
        case .staleSchema:
            return (
                nil,
                ManualPushBaseline(
                    productFingerprintsByRemoteID: [:],
                    invalidationReasons: [.fingerprintVersionChanged]
                ),
                ManualPushAccountState(currentUserID: ownerUserID, lastLinkedUserID: ownerUserID)
            )
        case .incomplete:
            return (
                nil,
                ManualPushBaseline(
                    productFingerprintsByRemoteID: [:],
                    invalidationReasons: [.partialPull]
                ),
                ManualPushAccountState(currentUserID: ownerUserID, lastLinkedUserID: ownerUserID)
            )
        }
    }
}

private extension SupabaseManualPushResult {
    var confirmedCatalogChangeCount: Int {
        supplierCreates + supplierUpdates + supplierLinks
            + categoryCreates + categoryUpdates + categoryLinks
            + productCreates + productUpdates + productLinks
    }
}

private extension SyncEventOutboxProducerResult {
    var isAggregatedPushSuccess: Bool {
        switch kind {
        case .enqueued, .duplicateNoOp, .skippedNoOp:
            return true
        case .skippedDryRun,
             .skippedFailedPreflight,
             .blockedContract,
             .blockedAuth,
             .blockedSchema,
             .enqueueFailedLocal,
             .skippedUnsupported:
            return false
        }
    }
}

private extension ProductPricePushRemoteDedupeStatus {
    var stableAggregatedFingerprintComponent: String {
        switch self {
        case .notNeeded:
            return "notNeeded"
        case .complete:
            return "complete"
        case .unsafePartialRemoteDedupe(let reason):
            return "unsafe:\(reason.rawValue)"
        }
    }
}

@MainActor
private final class SupabaseManualSyncReleaseAuthGate: SupabaseManualSyncAuthGateProviding {
    private let authViewModel: SupabaseAuthViewModel

    init(authViewModel: SupabaseAuthViewModel) {
        self.authViewModel = authViewModel
    }

    func evaluateAuthGate() async throws -> SupabaseManualSyncAuthGateResult {
        authViewModel.isSignedIn ? .authenticated : .sessionExpiredOrSignedOut
    }
}

@MainActor
private final class SupabaseManualSyncReleaseBaselineGate: SupabaseManualSyncBaselineGateProviding {
    private let context: ModelContext
    private let authViewModel: SupabaseAuthViewModel

    init(context: ModelContext, authViewModel: SupabaseAuthViewModel) {
        self.context = context
        self.authViewModel = authViewModel
    }

    func evaluateBaselineGate() async throws -> SupabaseManualSyncBaselineGateResult {
        guard let userID = authViewModel.sessionInfo?.userID,
              authViewModel.isSignedIn else {
            return .missingOrInvalid
        }

        switch try SupabaseCatalogBaselineReader().readManualPushBaseline(
            context: context,
            ownerUserUUID: userID
        ) {
        case .available:
            return .valid
        case .missing, .accountMismatch, .staleSchema, .incomplete:
            return .missingOrInvalid
        }
    }
}

@MainActor
private final class SupabaseManualSyncReleaseDryRunPhaseSimulator: SupabaseManualSyncDryRunPhaseSimulating {
    func simulateRemotePreview(counts: SupabaseManualSyncPrivacyCounts) async throws -> SupabaseManualSyncPhaseOutcome {
        .completed
    }

    func simulateCatalogPushPhase() async throws -> SupabaseManualSyncPhaseOutcome {
        .completed
    }

    func simulateProductPricePushPhase() async throws -> SupabaseManualSyncPhaseOutcome {
        .completed
    }

    func simulateQueuedCloudOperationsFlushPhase() async throws -> SupabaseManualSyncPhaseOutcome {
        .completed
    }

    func simulateFinalRefreshPhase() async throws -> SupabaseManualSyncPhaseOutcome {
        .completed
    }
}
