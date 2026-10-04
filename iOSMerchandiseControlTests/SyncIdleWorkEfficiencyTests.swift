import Foundation
import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class SyncIdleWorkEfficiencyTests: XCTestCase {
    private let entityNames = [
        "Product", "Supplier", "ProductCategory", "ProductPrice", "HistoryEntry",
        "LocalPendingChange", "SyncEventOutboxEntry", "SupabaseCatalogBaselineRun", "SupabaseCatalogBaselineRecord"
    ]

    func testEmptyStoreProvesAbsenceInEveryDomain() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        var queries: [String] = []
        XCTAssertTrue(try SyncLocalStoreEmptiness.isCompletelyEmpty(context: context) { queries.append($0) })
        XCTAssertEqual(queries, entityNames)
        print("SYNC_EFFICIENCY_EMPTY_QUERIES=\(queries.count)")
    }

    func testEveryPersistedDomainStopsEmptinessChecksOnceNonemptyIsProved() throws {
        for index in entityNames.indices {
            let container = try makeContainer()
            let context = ModelContext(container)
            insertSingleton(at: index, context: context)
            try context.save()
            let readContext = ModelContext(container)
            var queries: [String] = []
            XCTAssertFalse(try SyncLocalStoreEmptiness.isCompletelyEmpty(context: readContext) { queries.append($0) })
            XCTAssertEqual(queries, Array(entityNames.prefix(index + 1)), entityNames[index])
            print("SYNC_EFFICIENCY_NONEMPTY_\(entityNames[index])_QUERIES=\(queries.count)")
        }
    }

    func testUnsavedSingletonPreventsAutomaticBindingOfDirtyStore() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        context.insert(Product(barcode: "unsaved", productName: "Synthetic"))
        XCTAssertTrue(context.hasChanges)
        XCTAssertFalse(try SyncLocalStoreEmptiness.isCompletelyEmpty(context: context))
        XCTAssertTrue(context.hasChanges)
    }

    func testEmptinessIncludesUnsavedDeletionsAndDoesNotStopAtDeletedFirstRow() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let first = Product(barcode: "first", productName: "Synthetic")
        let second = Product(barcode: "second", productName: "Synthetic")
        context.insert(first)
        context.insert(second)
        try context.save()
        context.delete(first)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), 1)
        XCTAssertFalse(try SyncLocalStoreEmptiness.isCompletelyEmpty(context: context))
        context.delete(second)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Product>()), 0)
        XCTAssertTrue(try SyncLocalStoreEmptiness.isCompletelyEmpty(context: context))
        XCTAssertTrue(context.hasChanges)
    }

    func testPersistedHistoryCountMatchesVisibilityOracleAcrossBatches() throws {
        let container = try makeContainer()
        let writeContext = ModelContext(container)
        for index in 0..<1_027 {
            let entry = HistoryEntry(id: "visible-\(index)")
            switch index % 8 {
            case 0: entry.id = "\u{00a0}\tapply_import_\(index)\n"
            case 1: entry.title = "\n full_import_\(index)\u{2003}"
            case 2: entry.title = "\u{2003}TaSk135_MaTrIx_\(index)\n"
            case 3: entry.remoteDeletedAt = Date(timeIntervalSince1970: 1_700_000_000)
            case 4: entry.markHistorySessionLocalDeletion()
            case 5:
                entry.remoteDeletedAt = Date(timeIntervalSince1970: 1_700_000_000)
                entry.localChangeRevision = 2
                entry.lastSyncedLocalRevision = 2
            case 6: entry.title = "\u{00a0}Ordinary title\n"
            default: entry.title = ""
            }
            entry.dataJSON = Data(repeating: 17, count: 16_384)
            entry.originalDataJSON = Data(repeating: 18, count: 16_384)
            writeContext.insert(entry)
        }
        try writeContext.save()
        let oracleContext = ModelContext(container)
        let oracle = LocalHistorySessionCounting.countUserVisible(in: try oracleContext.fetch(FetchDescriptor<HistoryEntry>()))
        XCTAssertEqual(oracle, 384)
        let readContext = ModelContext(container)
        XCTAssertEqual(try LocalHistorySessionCounting.fetchUserVisibleCount(context: readContext), oracle)
        XCTAssertFalse(readContext.hasChanges)
    }

    func testHistoryCountIncludesUnsavedInsertMutationAndDeletionWithoutSaving() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let hidden = HistoryEntry(id: "APPLY_IMPORT_original")
        let visible = HistoryEntry(id: "visible")
        let remoteDeleted = HistoryEntry(id: "remote-deleted", remoteDeletedAt: Date())
        let deleted = HistoryEntry(id: "deleted")
        [hidden, visible, remoteDeleted, deleted].forEach(context.insert)
        try context.save()
        hidden.id = "now-visible"
        visible.title = "\n task135_matrix_hidden\t"
        remoteDeleted.localChangeRevision = 1
        context.delete(deleted)
        context.insert(HistoryEntry(id: "unsaved-visible"))
        let oracle = LocalHistorySessionCounting.countUserVisible(in: try context.fetch(FetchDescriptor<HistoryEntry>()))
        XCTAssertEqual(oracle, 3)
        XCTAssertEqual(try LocalHistorySessionCounting.fetchUserVisibleCount(context: context), oracle)
        XCTAssertTrue(context.hasChanges)
    }

    func testPersistedHistoryCountingSyntheticBenchmark() throws {
        let container = try makeContainer()
        let writeContext = ModelContext(container)
        for index in 0..<2_048 {
            let entry = HistoryEntry(id: "benchmark-\(index)")
            entry.dataJSON = Data(repeating: 19, count: 16_384)
            entry.originalDataJSON = Data(repeating: 20, count: 16_384)
            writeContext.insert(entry)
        }
        try writeContext.save()
        var samples: [Double] = []
        for _ in 0..<5 {
            let context = ModelContext(container)
            let started = ContinuousClock.now
            let count = try LocalHistorySessionCounting.fetchUserVisibleCount(context: context)
            let elapsed = started.duration(to: .now)
            let milliseconds = Double(elapsed.components.seconds) * 1_000 + Double(elapsed.components.attoseconds) / 1e15
            samples.append(milliseconds)
            XCTAssertEqual(count, 2_048)
        }
        print("SYNC_EFFICIENCY_HISTORY_2048_32768B_MS=\(samples)")
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Product.self, Supplier.self, ProductCategory.self, ProductPrice.self, HistoryEntry.self,
            LocalPendingChange.self, SyncEventOutboxEntry.self, SupabaseCatalogBaselineRun.self, SupabaseCatalogBaselineRecord.self
        ])
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("sync-idle-\(UUID()).sqlite")
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
    }

    private func insertSingleton(at index: Int, context: ModelContext) {
        let owner = UUID()
        switch index {
        case 0: context.insert(Product(barcode: "synthetic", productName: "Synthetic"))
        case 1: context.insert(Supplier(name: "Synthetic"))
        case 2: context.insert(ProductCategory(name: "Synthetic"))
        case 3: context.insert(ProductPrice(type: .retail, price: 1))
        case 4: context.insert(HistoryEntry(id: "synthetic"))
        case 5: context.insert(LocalPendingChange(ownerUserID: owner, entityKind: .product, operation: .update, origin: .manualCatalogSave, logicalKey: "synthetic"))
        case 6:
            let now = Date()
            context.insert(SyncEventOutboxEntry(ownerUserID: owner.uuidString.lowercased(), domain: "catalog", eventType: "catalog_changed", changedCount: 1, entityIDsShape: "{}", metadataShape: "{}", nextRetryAt: now, createdAt: now, updatedAt: now))
        case 7: context.insert(SupabaseCatalogBaselineRun(ownerUserUUID: owner))
        case 8: context.insert(SupabaseCatalogBaselineRecord(baselineRunID: UUID(), ownerUserUUID: owner, entityType: .product, remoteID: UUID(), fingerprintCanonical: "synthetic"))
        default: XCTFail("Unexpected entity")
        }
    }
}
