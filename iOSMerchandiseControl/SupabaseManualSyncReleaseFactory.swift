import Foundation
import SwiftData

@MainActor
enum SupabaseManualSyncReleaseFactory {
    static func makeViewModel(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel
    ) -> SupabaseManualSyncViewModel {
        let dependencies = SupabaseManualSyncCoordinator.Dependencies(
            authGate: SupabaseManualSyncReleaseAuthGate(authViewModel: authViewModel),
            baselineGate: SupabaseManualSyncReleaseBaselineGate(context: context, authViewModel: authViewModel),
            pendingSnapshot: SupabaseManualSyncLocalPendingSnapshotProvider(
                sessionProvider: authViewModel,
                catalogPendingCounter: SupabaseManualSyncCatalogPendingAdapter(context: context),
                outboxPendingCounter: SupabaseManualSyncOutboxPendingAdapter(context: context)
            ),
            phaseSimulation: SupabaseManualSyncReleaseDryRunPhaseSimulator()
        )

        return SupabaseManualSyncViewModel(
            coordinator: SupabaseManualSyncCoordinator(dependencies: dependencies)
        )
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
