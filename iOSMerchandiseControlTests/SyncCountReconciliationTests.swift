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

    func testHistoryUserVisibleCountExcludesTaskTechnicalEntries() throws {
        let schema = Schema([HistoryEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        context.insert(HistoryEntry(id: "visible-1", supplier: "Pinmark"))
        context.insert(HistoryEntry(id: "TASK109_REVIEW_HISTORY_20260521"))
        let titledTechnical = HistoryEntry(id: UUID().uuidString)
        titledTechnical.title = "TASK114_RUNTIME_CHECK"
        context.insert(titledTechnical)
        try context.save()

        let count = try LocalHistorySessionCounting.fetchUserVisibleCount(context: context)
        XCTAssertEqual(count, 1)
    }

    func testHistoryUUIDTitleFallsBackToFriendlySupplierTitle() {
        let timestamp = Date(timeIntervalSince1970: 1_713_723_540)
        let title = HistorySessionDisplayFormatter.displayTitle(
            id: "0acfcd5d-1111-4111-8111-111111111111",
            title: "0acfcd5d-1111-4111-8111-111111111111",
            supplier: "Pinmark",
            isManualEntry: false,
            timestamp: timestamp,
            locale: Locale(identifier: "it_IT")
        )

        XCTAssertTrue(title.hasPrefix("Pinmark - "))
        XCTAssertFalse(title.contains("0acfcd5d"))
    }

    func testHistoryManualTitleUsesManualDateFallback() {
        let timestamp = Date(timeIntervalSince1970: 1_713_693_540)
        let title = HistorySessionDisplayFormatter.displayTitle(
            id: UUID().uuidString,
            title: "",
            supplier: "",
            isManualEntry: true,
            timestamp: timestamp,
            locale: Locale(identifier: "it_IT")
        )

        XCTAssertTrue(title.hasPrefix("Manual - "))
    }
}
