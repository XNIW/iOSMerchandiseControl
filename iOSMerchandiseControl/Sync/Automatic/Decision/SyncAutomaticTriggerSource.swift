import Foundation

nonisolated enum SyncAutomaticTriggerSource: String, Sendable, Equatable {
    case releaseCard
    case rootForeground
    case networkReconnect
    case localMutation
    case remoteSyncEvent
    case backgroundRefresh
}
