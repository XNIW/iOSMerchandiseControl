import Foundation
import SwiftData

nonisolated protocol SupabaseManualSyncLocalApplyBaselineCommitting: AnyObject, Sendable {
    func commitSuccessfulFullPullApply(
        preview: SyncPreview,
        context: ModelContext,
        ownerUserID: UUID
    ) throws

    func commitCurrentLocalCatalogIfNeeded(
        context: ModelContext,
        ownerUserID: UUID
    ) throws -> Bool
}

nonisolated final class SupabaseManualSyncLocalApplyBaselineCommitter: SupabaseManualSyncLocalApplyBaselineCommitting, @unchecked Sendable {
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

    func commitCurrentLocalCatalogIfNeeded(
        context: ModelContext,
        ownerUserID: UUID
    ) throws -> Bool {
        let baselineStatus = try SupabaseCatalogBaselineReader()
            .debugSummary(context: context, currentUserUUID: ownerUserID)
            .status
        guard baselineStatus != .valid,
              baselineStatus != .accountMismatch,
              try localCatalogCanSeedBaseline(context: context) else {
            return false
        }

        _ = try SupabaseCatalogBaselineWriter().commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerUserID,
            source: .fullPullApply
        )
        return true
    }

    private func localCatalogCanSeedBaseline(context: ModelContext) throws -> Bool {
        let productCount = try context.fetchCount(FetchDescriptor<Product>())
        guard productCount > 0 else { return false }

        let linkedProducts = try context.fetchCount(
            FetchDescriptor<Product>(
                predicate: #Predicate { $0.remoteID != nil }
            )
        )
        let supplierCount = try context.fetchCount(FetchDescriptor<Supplier>())
        let linkedSuppliers = try context.fetchCount(
            FetchDescriptor<Supplier>(
                predicate: #Predicate { $0.remoteID != nil }
            )
        )
        let categoryCount = try context.fetchCount(FetchDescriptor<ProductCategory>())
        let linkedCategories = try context.fetchCount(
            FetchDescriptor<ProductCategory>(
                predicate: #Predicate { $0.remoteID != nil }
            )
        )

        return linkedProducts == productCount
            && linkedSuppliers == supplierCount
            && linkedCategories == categoryCount
    }
}
