import Foundation

/// Abstraction over `SupabaseManualSyncCoordinator` for test doubles and SwiftUI-facing layers (TASK-066).
@MainActor
protocol SupabaseManualSyncCoordinating: AnyObject {
    func run(mode: SupabaseManualSyncRunMode, sessionID: UUID) async -> SupabaseManualSyncRunSummary
}

extension SupabaseManualSyncCoordinator: SupabaseManualSyncCoordinating {}
