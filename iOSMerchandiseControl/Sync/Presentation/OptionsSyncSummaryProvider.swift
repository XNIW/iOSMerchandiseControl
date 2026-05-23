import Foundation

struct OptionsSyncSummaryProvider {
    func visibleProgress(for presentation: SupabaseManualSyncPresentationState) -> CloudSyncProgressState? {
        SyncStatusPresenter.visibleProgress(from: presentation.progressState)
    }

    func shouldShowFallbackSpinner(for presentation: SupabaseManualSyncPresentationState) -> Bool {
        SyncStatusPresenter.shouldShowFallbackSpinner(
            isRunning: presentation.isRunning,
            progress: presentation.progressState
        )
    }
}
