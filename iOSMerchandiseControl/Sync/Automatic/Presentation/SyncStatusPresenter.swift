import Foundation

nonisolated enum SyncStatusPresenter {
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

extension SyncPhase {
    nonisolated var isAutomaticWorkActive: Bool {
        switch self {
        case .checking, .pushing, .pullingEvents, .reconciling:
            return true
        case .idle, .recoveryRequired, .blocked, .failed:
            return false
        }
    }

    nonisolated var cloudProgressPhase: CloudSyncProgressPhase {
        switch self {
        case .checking:
            return .checkingCloud
        case .pushing:
            return .sendingLocalChanges
        case .pullingEvents:
            return .drainingSyncEvents
        case .reconciling:
            return .reviewingChanges
        case .idle, .recoveryRequired, .blocked, .failed:
            return .checkingCloud
        }
    }
}
