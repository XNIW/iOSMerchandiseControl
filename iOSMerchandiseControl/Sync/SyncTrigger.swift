import Foundation

enum SyncTrigger: Equatable {
    case appForeground
    case networkAvailable
    case authChanged
    case localMutation
    case remoteSyncEvent
    case manualRefresh
    case harness
    case recoveryRequested
    case bootstrapRequested
}
