import Combine
import Foundation

@MainActor
protocol SyncOrchestratorLegacySyncAdapter: AnyObject {
    var objectWillChangePublisher: AnyPublisher<Void, Never> { get }
    var legacyManualSyncViewModel: SupabaseManualSyncViewModel { get }
    var presentationState: SupabaseManualSyncPresentationState { get }
    var rootPresentationState: SupabaseManualSyncRootPresentationState { get }

    func applyAuthPresentationContext(_ context: SupabaseManualSyncAuthPresentationContext)
    func markForegroundCheckSkippedBecauseBusy()
    func requestLifecycleInterruptionForBackground()
    func runMode(for actionID: SupabaseManualSyncPresentationActionID) -> SupabaseManualSyncRunMode?
    func start(with mode: SupabaseManualSyncRunMode) async
    func startForegroundIncrementalCheckNow(source: SupabaseManualSyncSemiAutomaticTriggerSource) async -> Bool
    func startForegroundSemiAutomaticCheckIfAllowed(source: SupabaseManualSyncSemiAutomaticTriggerSource) async -> Bool
}

@MainActor
final class SupabaseManualSyncCompatibilityAdapter: SyncOrchestratorLegacySyncAdapter {
    let legacyManualSyncViewModel: SupabaseManualSyncViewModel

    init(viewModel: SupabaseManualSyncViewModel) {
        self.legacyManualSyncViewModel = viewModel
    }

    var objectWillChangePublisher: AnyPublisher<Void, Never> {
        legacyManualSyncViewModel.objectWillChange.eraseToAnyPublisher()
    }

    var presentationState: SupabaseManualSyncPresentationState {
        legacyManualSyncViewModel.presentationState
    }

    var rootPresentationState: SupabaseManualSyncRootPresentationState {
        legacyManualSyncViewModel.rootPresentationState
    }

    func applyAuthPresentationContext(_ context: SupabaseManualSyncAuthPresentationContext) {
        legacyManualSyncViewModel.applyAuthPresentationContext(context)
    }

    func markForegroundCheckSkippedBecauseBusy() {
        legacyManualSyncViewModel.markForegroundCheckSkippedBecauseBusy()
    }

    func requestLifecycleInterruptionForBackground() {
        legacyManualSyncViewModel.requestLifecycleInterruptionForBackground()
    }

    func runMode(for actionID: SupabaseManualSyncPresentationActionID) -> SupabaseManualSyncRunMode? {
        legacyManualSyncViewModel.runMode(for: actionID)
    }

    func start(with mode: SupabaseManualSyncRunMode) async {
        await legacyManualSyncViewModel.start(with: mode)
    }

    func startForegroundIncrementalCheckNow(source: SupabaseManualSyncSemiAutomaticTriggerSource) async -> Bool {
        await legacyManualSyncViewModel.startForegroundIncrementalCheckNow(source: source)
    }

    func startForegroundSemiAutomaticCheckIfAllowed(source: SupabaseManualSyncSemiAutomaticTriggerSource) async -> Bool {
        await legacyManualSyncViewModel.startForegroundSemiAutomaticCheckIfAllowed(source: source)
    }
}

