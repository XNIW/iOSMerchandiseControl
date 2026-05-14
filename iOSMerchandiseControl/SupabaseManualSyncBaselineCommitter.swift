import Foundation
import SwiftData

@MainActor
protocol SupabaseManualSyncLocalApplyBaselineCommitting: AnyObject {
    func commitSuccessfulFullPullApply(
        preview: SyncPreview,
        context: ModelContext,
        ownerUserID: UUID
    ) throws
}

@MainActor
final class SupabaseManualSyncLocalApplyBaselineCommitter: SupabaseManualSyncLocalApplyBaselineCommitting {
    func commitSuccessfulFullPullApply(
        preview: SyncPreview,
        context: ModelContext,
        ownerUserID: UUID
    ) throws {
        _ = try SupabaseCatalogBaselineWriter().commitAfterSuccessfulFullPullApply(
            preview: preview,
            context: context,
            ownerUserUUID: ownerUserID
        )
    }
}
