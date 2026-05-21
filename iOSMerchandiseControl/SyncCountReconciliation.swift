import Foundation
import SwiftData

/// TASK-114: confronto conteggi locali vs remoti (stessa definizione di Supabase/Android Options).
nonisolated struct SyncInventoryCountSnapshot: Equatable, Sendable {
    var products: Int
    var suppliers: Int
    var categories: Int
    var productPrices: Int
    var historySessions: Int

    static let zero = SyncInventoryCountSnapshot(
        products: 0,
        suppliers: 0,
        categories: 0,
        productPrices: 0,
        historySessions: 0
    )
}

nonisolated enum SyncCountDriftKind: String, Sendable {
    case products
    case suppliers
    case categories
    case productPrices
    case historySessions
}

nonisolated struct SyncCountDriftReport: Equatable, Sendable {
    var local: SyncInventoryCountSnapshot
    var remote: SyncInventoryCountSnapshot
    var mismatches: [SyncCountDriftKind]

    var isAligned: Bool { mismatches.isEmpty }

    static func compare(local: SyncInventoryCountSnapshot, remote: SyncInventoryCountSnapshot) -> SyncCountDriftReport {
        var mismatches: [SyncCountDriftKind] = []
        if local.products != remote.products { mismatches.append(.products) }
        if local.suppliers != remote.suppliers { mismatches.append(.suppliers) }
        if local.categories != remote.categories { mismatches.append(.categories) }
        if local.productPrices != remote.productPrices { mismatches.append(.productPrices) }
        if local.historySessions != remote.historySessions { mismatches.append(.historySessions) }
        return SyncCountDriftReport(local: local, remote: remote, mismatches: mismatches)
    }
}

nonisolated enum LocalHistorySessionCounting {
    /// Allineato ad Android `USER_VISIBLE_HISTORY_WHERE_CLAUSE`.
    static func isUserVisibleSession(id: String, remoteDeletedAt: Date?) -> Bool {
        if id.hasPrefix("APPLY_IMPORT_") || id.hasPrefix("FULL_IMPORT_") {
            return false
        }
        return remoteDeletedAt == nil
    }

    static func countUserVisible(in entries: [HistoryEntry]) -> Int {
        entries.filter { isUserVisibleSession(id: $0.id, remoteDeletedAt: $0.remoteDeletedAt) }.count
    }

    static func fetchUserVisibleCount(context: ModelContext) throws -> Int {
        let entries = try context.fetch(FetchDescriptor<HistoryEntry>())
        return countUserVisible(in: entries)
    }
}

extension LocalDatabasePublicSummary {
    static func makeReconciliationAware(context: ModelContext) throws -> SyncInventoryCountSnapshot {
        SyncInventoryCountSnapshot(
            products: try context.fetchCount(FetchDescriptor<Product>()),
            suppliers: try context.fetchCount(FetchDescriptor<Supplier>()),
            categories: try context.fetchCount(FetchDescriptor<ProductCategory>()),
            productPrices: try context.fetchCount(FetchDescriptor<ProductPrice>()),
            historySessions: try LocalHistorySessionCounting.fetchUserVisibleCount(context: context)
        )
    }
}
