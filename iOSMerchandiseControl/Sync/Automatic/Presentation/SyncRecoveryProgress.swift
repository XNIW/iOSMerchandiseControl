import Foundation

/// Presentation observations only. Counts describe persisted live pages;
/// they are never a convergence proof or a percentage of checkpoint A.
nonisolated struct SyncRecoveryProgress: Equatable, Sendable {
    nonisolated enum Stage: String, Equatable, Sendable {
        case preparing, checkpoint, downloading, verifying, activating, finalizing

        var titleKey: String { "options.supabase.automaticSync.recovery.\(rawValue)" }
    }

    let stage: Stage
    let domain: ShopSyncRecoveryDomain?
    let pages: Int
    let persistedRows: Int
}

nonisolated struct SyncRecoveryProgressEvent: Sendable {
    let invocationID: UUID?
    let scope: Task126VerifiedOwnerStoreScope
    let progress: SyncRecoveryProgress
}

nonisolated enum SyncRecoveryProgressContext {
    @TaskLocal static var invocationID: UUID?
}

typealias SyncRecoveryProgressReporter = @MainActor @Sendable (SyncRecoveryProgressEvent) -> Void

@MainActor
enum SyncRecoveryGatePresentation {
    static func statusKey(state: SyncState, isBusy: Bool) -> String {
        if isBusy {
            return state.recoveryProgress?.stage.titleKey
                ?? "options.supabase.automaticSync.recovery.preparing"
        }
        switch state.lastOutcome {
        case .failed: return "options.supabase.automaticSync.recovery.failed"
        case .blocked(.authRequired): return "options.supabase.automaticSync.root.auth.detail"
        case .blocked(.deviceNotActive): return "options.supabase.automaticSync.root.deviceBlocked.detail"
        case .blocked(.networkUnavailable): return "options.localDatabase.offline.detail"
        default: return "options.supabase.automaticSync.recovery.required"
        }
    }

    static func domainKey(_ domain: ShopSyncRecoveryDomain) -> String {
        "options.supabase.automaticSync.recovery.domain.\(domain.rawValue)"
    }
}
