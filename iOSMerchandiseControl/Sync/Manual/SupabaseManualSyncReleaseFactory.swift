import Foundation
import SwiftData

typealias ProductPriceReleaseRemote =
    any SupabaseProductPriceKeysetFetching
    & SupabaseProductPriceDeletedProductFetching
    & SupabaseProductPriceManualPushRemoteAccessing
    & SupabaseProductPricePushDryRunRemoteFetching

@MainActor
enum SupabaseManualSyncReleaseFactory {
    static func makeViewModel(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        productPriceRemote: ProductPriceReleaseRemote? = nil,
        historyRemote: (any HistorySessionRemoteSyncing)? = nil,
        incrementalRemote: (any SyncAutomaticIncrementalRemote)? = nil,
        pullPreviewService: SupabasePullPreviewService? = nil,
        manualPushService: SupabaseManualPushService? = nil,
        activityRecorder: (any SyncEventRecording)? = nil,
        deviceAuthorization: (any ShopDeviceAuthorizationChecking)? = nil
    ) -> SupabaseManualSyncViewModel {
        let modelContainer = context.container
        let remotePreviewAdapter = pullPreviewService.map {
            SupabaseManualSyncPullPreviewAdapter(service: $0, modelContainer: modelContainer)
        }
        let remotePreviewProvider: (any SupabaseManualSyncRemotePreviewProviding)? = remotePreviewAdapter.map { $0 }
        let rawCatalogPushProvider: (any SupabaseManualSyncCatalogPushProviding)? = manualPushService.map {
            SyncCatalogPushAdapter(
                context: context,
                manualPushService: $0,
                generatedPriceRemote: productPriceRemote
            )
        }
        let catalogPushProvider: (any SupabaseManualSyncCatalogPushProviding)? = if let rawCatalogPushProvider,
                                                                                   let deviceAuthorization {
            DeviceGuardedManualCatalogPushProvider(
                delegate: rawCatalogPushProvider,
                deviceAuthorization: deviceAuthorization
            )
        } else {
            rawCatalogPushProvider
        }
        let rawProductPriceProvider: (any SupabaseManualSyncProductPriceSyncProviding)? = productPriceRemote.map {
            SyncProductPriceAdapter(
                modelContainer: modelContainer,
                remote: $0
            )
        }
        let productPriceProvider: (any SupabaseManualSyncProductPriceSyncProviding)? = if let rawProductPriceProvider,
                                                                                        let deviceAuthorization {
            DeviceGuardedManualProductPriceProvider(
                delegate: rawProductPriceProvider,
                deviceAuthorization: deviceAuthorization
            )
        } else {
            rawProductPriceProvider
        }
        let rawActivityRegistrationProvider: (any SupabaseManualSyncActivityRegistrationProviding)? = activityRecorder.map {
            SyncActivityRegistrationAdapter(context: context, recorder: $0)
        }
        let activityRegistrationProvider: (any SupabaseManualSyncActivityRegistrationProviding)? = if let rawActivityRegistrationProvider,
                                                                                                     let deviceAuthorization {
            DeviceGuardedManualActivityRegistrationProvider(
                delegate: rawActivityRegistrationProvider,
                deviceAuthorization: deviceAuthorization
            )
        } else {
            rawActivityRegistrationProvider
        }
        let rawHistorySessionProvider: (any SupabaseManualSyncHistorySessionSyncProviding)? = historyRemote.map {
            SyncHistorySessionPushAdapter(
                modelContainer: modelContainer,
                remote: $0,
                recorder: activityRecorder
            )
        }
        let historySessionProvider: (any SupabaseManualSyncHistorySessionSyncProviding)? = if let rawHistorySessionProvider,
                                                                                             let deviceAuthorization {
            DeviceGuardedManualHistorySessionProvider(
                delegate: rawHistorySessionProvider,
                deviceAuthorization: deviceAuthorization
            )
        } else {
            rawHistorySessionProvider
        }
        let rawIncrementalPullProvider: (any SupabaseManualSyncIncrementalPullProviding)? = incrementalRemote.map {
            ManualSyncIncrementalPullAdapter(
                service: SyncEventIncrementalPullService(
                    modelContainer: modelContainer,
                    remote: $0
                )
            )
        }
        let incrementalPullProvider: (any SupabaseManualSyncIncrementalPullProviding)? = if let rawIncrementalPullProvider,
                                                                                           let deviceAuthorization {
            DeviceGuardedManualIncrementalPullProvider(
                delegate: rawIncrementalPullProvider,
                deviceAuthorization: deviceAuthorization
            )
        } else {
            rawIncrementalPullProvider
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
private final class DeviceGuardedManualCatalogPushProvider: SupabaseManualSyncCatalogPushProviding {
    private let delegate: any SupabaseManualSyncCatalogPushProviding
    private let deviceAuthorization: any ShopDeviceAuthorizationChecking

    init(
        delegate: any SupabaseManualSyncCatalogPushProviding,
        deviceAuthorization: any ShopDeviceAuthorizationChecking
    ) {
        self.delegate = delegate
        self.deviceAuthorization = deviceAuthorization
    }

    func makePushPlan(ownerUserID: UUID) async throws -> ManualPushPlan {
        _ = try await deviceAuthorization.ensureActiveForCloudWrite(reason: "manual_catalog_plan")
        return try await delegate.makePushPlan(ownerUserID: ownerUserID)
    }

    func execute(plan: ManualPushPlan, ownerUserID: UUID) async -> SupabaseManualPushResult {
        do {
            _ = try await deviceAuthorization.ensureActiveForCloudWrite(reason: "manual_catalog_execute")
        } catch {
            return .blocked(message: "Device access blocked. Contact a shop admin.")
        }
        return await delegate.execute(plan: plan, ownerUserID: ownerUserID)
    }
}

@MainActor
private final class DeviceGuardedManualProductPriceProvider: SupabaseManualSyncProductPriceSyncProviding {
    private let delegate: any SupabaseManualSyncProductPriceSyncProviding
    private let deviceAuthorization: any ShopDeviceAuthorizationChecking

    init(
        delegate: any SupabaseManualSyncProductPriceSyncProviding,
        deviceAuthorization: any ShopDeviceAuthorizationChecking
    ) {
        self.delegate = delegate
        self.deviceAuthorization = deviceAuthorization
    }

    func makeApplyPlan(ownerUserID: UUID) async throws -> ProductPriceApplyPlan {
        _ = try await deviceAuthorization.ensureActiveForCloudWrite(reason: "manual_price_apply_plan")
        return try await delegate.makeApplyPlan(ownerUserID: ownerUserID)
    }

    func apply(plan: ProductPriceApplyPlan, ownerUserID: UUID) async throws -> ProductPriceApplyResult {
        _ = try await deviceAuthorization.ensureActiveForCloudWrite(reason: "manual_price_apply")
        return try await delegate.apply(plan: plan, ownerUserID: ownerUserID)
    }

    func apply(
        plan: ProductPriceApplyPlan,
        ownerUserID: UUID,
        onProgress: @escaping @MainActor @Sendable (ProductPricePagedApplyProgress) -> Void
    ) async throws -> ProductPriceApplyResult {
        _ = try await deviceAuthorization.ensureActiveForCloudWrite(reason: "manual_price_apply_paged")
        return try await delegate.apply(plan: plan, ownerUserID: ownerUserID, onProgress: onProgress)
    }

    func makePushPlan(ownerUserID: UUID) async throws -> ProductPricePushDryRunPlan {
        _ = try await deviceAuthorization.ensureActiveForCloudWrite(reason: "manual_price_push_plan")
        return try await delegate.makePushPlan(ownerUserID: ownerUserID)
    }

    func push(plan: ProductPricePushDryRunPlan, ownerUserID: UUID) async throws -> ProductPriceManualPushResult {
        _ = try await deviceAuthorization.ensureActiveForCloudWrite(reason: "manual_price_push")
        return try await delegate.push(plan: plan, ownerUserID: ownerUserID)
    }
}

@MainActor
private final class DeviceGuardedManualActivityRegistrationProvider: SupabaseManualSyncActivityRegistrationProviding {
    private let delegate: any SupabaseManualSyncActivityRegistrationProviding
    private let deviceAuthorization: any ShopDeviceAuthorizationChecking

    init(
        delegate: any SupabaseManualSyncActivityRegistrationProviding,
        deviceAuthorization: any ShopDeviceAuthorizationChecking
    ) {
        self.delegate = delegate
        self.deviceAuthorization = deviceAuthorization
    }

    func loadActivityRegistrationSnapshot(ownerUserID: UUID) async throws -> SupabaseManualSyncActivityRegistrationSnapshot {
        try await delegate.loadActivityRegistrationSnapshot(ownerUserID: ownerUserID)
    }

    func registerActivities(ownerUserID: UUID) async throws -> SupabaseManualSyncActivityRegistrationResult {
        _ = try await deviceAuthorization.ensureActiveForCloudWrite(reason: "manual_activity_register")
        return try await delegate.registerActivities(ownerUserID: ownerUserID)
    }
}

@MainActor
private final class DeviceGuardedManualHistorySessionProvider: SupabaseManualSyncHistorySessionSyncProviding {
    private let delegate: any SupabaseManualSyncHistorySessionSyncProviding
    private let deviceAuthorization: any ShopDeviceAuthorizationChecking

    init(
        delegate: any SupabaseManualSyncHistorySessionSyncProviding,
        deviceAuthorization: any ShopDeviceAuthorizationChecking
    ) {
        self.delegate = delegate
        self.deviceAuthorization = deviceAuthorization
    }

    func syncHistorySessions(
        ownerUserID: UUID,
        mode: SupabaseManualSyncHistorySessionMode,
        onProgress: @escaping @MainActor @Sendable (HistorySessionSyncProgress) -> Void
    ) async throws -> SupabaseManualSyncHistorySessionSummary {
        _ = try await deviceAuthorization.ensureActiveForCloudWrite(reason: "manual_history_sync")
        return try await delegate.syncHistorySessions(
            ownerUserID: ownerUserID,
            mode: mode,
            onProgress: onProgress
        )
    }
}

@MainActor
private final class DeviceGuardedManualIncrementalPullProvider: SupabaseManualSyncIncrementalPullProviding {
    private let delegate: any SupabaseManualSyncIncrementalPullProviding
    private let deviceAuthorization: any ShopDeviceAuthorizationChecking

    init(
        delegate: any SupabaseManualSyncIncrementalPullProviding,
        deviceAuthorization: any ShopDeviceAuthorizationChecking
    ) {
        self.delegate = delegate
        self.deviceAuthorization = deviceAuthorization
    }

    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SupabaseSyncEventIncrementalApplySummary {
        _ = try await deviceAuthorization.ensureActiveForCloudWrite(reason: "manual_incremental_pull")
        return try await delegate.applyIncrementalRemoteChanges(ownerUserID: ownerUserID)
    }
}

@MainActor
final class SyncHistorySessionPushAdapter: SupabaseManualSyncHistorySessionSyncProviding {
    private let modelContainer: ModelContainer
    private let remote: any HistorySessionRemoteSyncing
    private let recorder: (any SyncEventRecording)?

    init(
        modelContainer: ModelContainer,
        remote: any HistorySessionRemoteSyncing,
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
                return SyncHistorySessionSummary(
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
            return SyncHistorySessionSummary(
                uploaded: push.uploadedCount,
                inserted: initialPull.insertedCount + confirmPull.insertedCount,
                updated: initialPull.updatedCount + confirmPull.updatedCount,
                skippedClean: push.skippedCleanCount + initialPull.skippedCleanCount + confirmPull.skippedCleanCount,
                skippedDirtyLocal: initialPull.skippedDirtyLocalCount + confirmPull.skippedDirtyLocalCount,
                skippedOversized: push.skippedOversizedCount
            )
        }.value
    }

    func syncHistorySessions(
        ownerUserID: UUID,
        mode: SupabaseManualSyncHistorySessionMode,
        onProgress: @escaping @MainActor @Sendable (HistorySessionSyncProgress) -> Void
    ) async throws -> SupabaseManualSyncHistorySessionSummary {
        try await syncHistorySessions(
            ownerUserID: ownerUserID,
            mode: SyncHistorySessionMode(mode),
            onProgress: onProgress
        ).manualSummary
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
            sourceDeviceID: DeviceInstallIDStore().deviceInstallID,
            batchID: UUID(),
            clientEventID: "ios-history-\(ownerUserID.uuidString.lowercased())-\(UUID().uuidString.lowercased())"
        )
        _ = try await recorder.record(request)
    }
}

@MainActor
private final class ManualSyncIncrementalPullAdapter: SupabaseManualSyncIncrementalPullProviding {
    private let service: SyncEventIncrementalPullService

    init(service: SyncEventIncrementalPullService) {
        self.service = service
    }

    func applyIncrementalRemoteChanges(ownerUserID: UUID) async throws -> SupabaseSyncEventIncrementalApplySummary {
        let summary = try await service.applyIncrementalRemoteChanges(ownerUserID: ownerUserID)
        return SupabaseSyncEventIncrementalApplySummary(summary)
    }
}

private extension SyncHistorySessionSummary {
    var manualSummary: SupabaseManualSyncHistorySessionSummary {
        SupabaseManualSyncHistorySessionSummary(
            uploaded: uploaded,
            inserted: inserted,
            updated: updated,
            skippedClean: skippedClean,
            skippedDirtyLocal: skippedDirtyLocal,
            skippedOversized: skippedOversized
        )
    }
}

private extension SyncHistorySessionMode {
    init(_ manualMode: SupabaseManualSyncHistorySessionMode) {
        switch manualMode {
        case .fullReconciliation:
            self = .fullReconciliation
        case .incremental:
            self = .incremental
        }
    }
}

@MainActor
final class SyncProductPriceAdapter: SupabaseManualSyncProductPriceSyncProviding {
    private let modelContainer: ModelContainer
    private let remote: ProductPriceReleaseRemote
    private var stagedPendingBatchesByFingerprint: [String: LocalPendingAggregatedProductPriceBatch] = [:]

    init(
        modelContainer: ModelContainer,
        remote: ProductPriceReleaseRemote
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
        let telemetryResult = SyncEventOutboxEnqueueService(context: context).enqueue(
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

    func pushPendingProductPrices(ownerUserID: UUID) async throws -> SyncProductPricePushResult {
        let plan = try await makePushPlan(ownerUserID: ownerUserID)
        guard plan.isSafeForAggregatedPendingPush else {
            return SyncProductPricePushResult(insertedCount: 0)
        }
        let result = try await push(plan: plan, ownerUserID: ownerUserID)
        guard result.isVerifiedSuccess else {
            return SyncProductPricePushResult(insertedCount: 0)
        }
        return SyncProductPricePushResult(insertedCount: result.insertedCount)
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
final class SyncCatalogPushAdapter: SupabaseManualSyncCatalogPushProviding {
    private let context: ModelContext
    private let manualPushService: SupabaseManualPushService
    private let generatedPriceRemote: (any SupabaseProductPricePushDryRunRemoteFetching)?
    private let preflightService: SupabaseManualPushPreflightService
    private let baselineReader: SupabaseCatalogBaselineReader
    private var stagedPendingBatchesByFingerprint: [String: LocalPendingAggregatedCatalogBatch] = [:]

    init(
        context: ModelContext,
        manualPushService: SupabaseManualPushService,
        generatedPriceRemote: (any SupabaseProductPricePushDryRunRemoteFetching)? = nil,
        preflightService: SupabaseManualPushPreflightService = SupabaseManualPushPreflightService(),
        baselineReader: SupabaseCatalogBaselineReader = SupabaseCatalogBaselineReader()
    ) {
        self.context = context
        self.manualPushService = manualPushService
        self.generatedPriceRemote = generatedPriceRemote
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
        let telemetry = SyncEventOutboxEnqueueService(context: context).enqueue(
            .catalogManualPush(
                result: result,
                ownerUserID: ownerUserID,
                currentOwnerUserID: ownerUserID,
                planFingerprint: plan.planFingerprint
            )
        )
        let generatedPriceTelemetry: SyncEventOutboxProducerResult
        if let generatedPriceRemote {
            do {
                generatedPriceTelemetry = try await CatalogGeneratedProductPriceSyncEventRecorder(
                    context: context,
                    remote: generatedPriceRemote
                ).recordIfNeeded(
                    catalogResult: result,
                    ownerUserID: ownerUserID,
                    planFingerprint: plan.planFingerprint
                )
            } catch {
                generatedPriceTelemetry = SyncEventOutboxProducerResult(
                    kind: .blockedContract,
                    errorCode: "catalog_generated_price_event_failed"
                )
            }
        } else {
            generatedPriceTelemetry = SyncEventOutboxProducerResult(kind: .skippedNoOp)
        }
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
        if result.status == .completed, !generatedPriceTelemetry.isAggregatedPushSuccess {
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
                message: "Technical follow-up required after generated ProductPrice event."
            )
        }
        return result
    }

    func pushPendingCatalog(ownerUserID: UUID) async throws -> SyncCatalogPushResult {
        let plan = try await makePushPlan(ownerUserID: ownerUserID)
        guard plan.isSendable else {
            return SyncCatalogPushResult()
        }
        let result = await execute(plan: plan, ownerUserID: ownerUserID)
        guard result.status == .completed || result.status == .completedBaselineRefreshFailed else {
            return SyncCatalogPushResult()
        }
        return SyncCatalogPushResult(
            supplierCreates: result.supplierCreates,
            supplierUpdates: result.supplierUpdates,
            supplierLinks: result.supplierLinks,
            categoryCreates: result.categoryCreates,
            categoryUpdates: result.categoryUpdates,
            categoryLinks: result.categoryLinks,
            productCreates: result.productCreates,
            productUpdates: result.productUpdates,
            productLinks: result.productLinks
        )
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
