import Foundation

enum SyncStatusPresenter {
    static func visibleProgress(from progress: CloudSyncProgressState) -> CloudSyncProgressState? {
        guard !isZeroOfZero(progress) else { return nil }
        guard progress.isActive || progress.phase == .completedWithWarnings else { return nil }
        return progress
    }

    static func shouldShowFallbackSpinner(
        isRunning: Bool,
        progress: CloudSyncProgressState
    ) -> Bool {
        guard isRunning else { return false }
        guard !isZeroOfZero(progress) else { return false }
        return visibleProgress(from: progress) == nil
    }

    private static func isZeroOfZero(_ progress: CloudSyncProgressState) -> Bool {
        progress.current == 0 && progress.total == 0
    }
}
