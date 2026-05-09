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
        let remotePreviewAdapter = pullPreviewService.map {
            SupabaseManualSyncPullPreviewAdapter(service: $0, context: context)
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
                context: context,
                remote: $0
            )
        }
        let activityRegistrationProvider: (any SupabaseManualSyncActivityRegistrationProviding)? = activityRecorder.map {
            SupabaseManualSyncReleaseActivityRegistrationAdapter(context: context, recorder: $0)
        }

        let dependencies = SupabaseManualSyncCoordinator.Dependencies(
            authGate: SupabaseManualSyncReleaseAuthGate(authViewModel: authViewModel),
            baselineGate: SupabaseManualSyncReleaseBaselineGate(context: context, authViewModel: authViewModel),
            pendingSnapshot: SupabaseManualSyncLocalPendingSnapshotProvider(
                sessionProvider: authViewModel,
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
            isLocalApplyAuthenticated: { authViewModel.isSignedIn },
            currentLocalApplyOwnerID: { authViewModel.isSignedIn ? authViewModel.sessionInfo?.userID : nil },
            catalogPushProvider: catalogPushProvider,
            currentCatalogPushOwnerID: { authViewModel.isSignedIn ? authViewModel.sessionInfo?.userID : nil },
            productPriceProvider: productPriceProvider,
            currentProductPriceOwnerID: { authViewModel.isSignedIn ? authViewModel.sessionInfo?.userID : nil },
            activityRegistrationProvider: activityRegistrationProvider,
            currentActivityRegistrationOwnerID: { authViewModel.isSignedIn ? authViewModel.sessionInfo?.userID : nil }
        )
    }
}

@MainActor
private final class SupabaseManualSyncReleaseProductPriceAdapter: SupabaseManualSyncProductPriceSyncProviding {
    private let context: ModelContext
    private let remote: SupabaseInventoryService

    init(
        context: ModelContext,
        remote: SupabaseInventoryService
    ) {
        self.context = context
        self.remote = remote
    }

    func makeApplyPlan(ownerUserID: UUID) async throws -> ProductPriceApplyPlan {
        try await SupabaseProductPriceApplyService(fetcher: remote).loadDryRun(
            context: context,
            sessionSnapshot: ProductPriceApplySessionSnapshot(userID: ownerUserID)
        )
    }

    func apply(plan: ProductPriceApplyPlan, ownerUserID: UUID) async throws -> ProductPriceApplyResult {
        try SupabaseProductPriceApplyService().apply(
            plan: plan,
            context: context,
            currentSessionSnapshot: ProductPriceApplySessionSnapshot(userID: ownerUserID)
        )
    }

    func makePushPlan(ownerUserID: UUID) async throws -> ProductPricePushDryRunPlan {
        try await SupabaseProductPricePushDryRunService(fetcher: remote).loadDryRun(
            context: context,
            sessionSnapshot: ProductPricePushDryRunSessionSnapshot(
                userID: ownerUserID,
                lastLinkedUserID: ownerUserID
            )
        )
    }

    func push(plan: ProductPricePushDryRunPlan, ownerUserID: UUID) async throws -> ProductPriceManualPushResult {
        let snapshot = try ProductPriceManualPushSnapshotFactory.makeSnapshot(from: plan)
        guard snapshot.ownerUserID == ownerUserID else {
            throw ProductPriceManualPushError.invalidPayload
        }
        let result = try await SupabaseProductPriceManualPushService(remote: remote).push(snapshot: snapshot)
        if result.isVerifiedSuccess {
            _ = try ProductPriceManualPushIdentityReconciler().linkVerifiedPayloads(
                snapshot.payloads,
                context: context
            )
        }
        return result
    }
}

@MainActor
private final class SupabaseManualSyncReleasePushAdapter: SupabaseManualSyncCatalogPushProviding {
    private let context: ModelContext
    private let manualPushService: SupabaseManualPushService
    private let preflightService: SupabaseManualPushPreflightService
    private let baselineReader: SupabaseCatalogBaselineReader

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
        try Task.checkCancellation()
        let snapshotService = SwiftDataInventorySnapshotService(context: context)
        let baselineResult = try baselineReader.readManualPushBaseline(
            context: context,
            ownerUserUUID: ownerUserID
        )
        let mappedBaseline = mapBaselineResult(baselineResult, ownerUserID: ownerUserID)
        try Task.checkCancellation()
        return preflightService.makePlan(input: ManualPushPreflightInput(
            baselineRunID: mappedBaseline.runID,
            pullState: ManualPushPullState(isComplete: true, hasSourceErrors: false),
            accountState: mappedBaseline.accountState,
            baseline: mappedBaseline.baseline,
            suppliers: try snapshotService.makeManualPushPreflightSupplierStates(),
            categories: try snapshotService.makeManualPushPreflightCategoryStates(),
            products: try snapshotService.makeManualPushPreflightProductStates()
        ))
    }

    func execute(plan: ManualPushPlan, ownerUserID: UUID) async -> SupabaseManualPushResult {
        await manualPushService.execute(
            plan: plan,
            context: context,
            ownerUserID: ownerUserID
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
