import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class SyncCountReconciliationTests: XCTestCase {
    func testCompareDetectsProductDrift() {
        let local = SyncInventoryCountSnapshot(
            products: 100,
            suppliers: 10,
            categories: 5,
            productPrices: 200,
            historySessions: 2
        )
        let remote = SyncInventoryCountSnapshot(
            products: 99,
            suppliers: 10,
            categories: 5,
            productPrices: 200,
            historySessions: 2
        )
        let report = SyncCountDriftReport.compare(local: local, remote: remote)
        XCTAssertFalse(report.isAligned)
        XCTAssertEqual(report.mismatches, [.products])
    }

    func testHistoryUserVisibleCountExcludesImportAndTombstone() throws {
        let schema = Schema([HistoryEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        context.insert(HistoryEntry(id: "visible-1"))
        context.insert(HistoryEntry(id: "APPLY_IMPORT_x"))
        let tombstoned = HistoryEntry(id: "tombstone-1")
        tombstoned.markHistorySessionLocalDeletion()
        context.insert(tombstoned)
        try context.save()

        let count = try LocalHistorySessionCounting.fetchUserVisibleCount(context: context)
        XCTAssertEqual(count, 1)
    }
}
