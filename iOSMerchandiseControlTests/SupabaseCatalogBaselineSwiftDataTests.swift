import XCTest
import SwiftData
@testable import iOSMerchandiseControl

@MainActor
final class SupabaseCatalogBaselineSwiftDataTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private static var retainedContexts: [ModelContext] = []

    func testCreateReadUpdateRunAndRecord() throws {
        let context = try makeContext()
        let ownerID = UUID()
        let runID = UUID()
        let remoteID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_778_100_000)
        let run = SupabaseCatalogBaselineRun(
            baselineRunID: runID,
            ownerUserUUID: ownerID,
            status: .building,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        let record = SupabaseCatalogBaselineRecord(
            baselineRunID: runID,
            ownerUserUUID: ownerID,
            entityType: .product,
            remoteID: remoteID,
            fingerprintCanonical: "v1|product|barcode=string:100",
            createdAt: createdAt,
            updatedAt: createdAt,
            barcodeCanonical: "100"
        )

        context.insert(run)
        context.insert(record)
        try context.save()

        let fetchedRun = try XCTUnwrap(try context.fetch(FetchDescriptor<SupabaseCatalogBaselineRun>()).first)
        fetchedRun.status = SupabaseCatalogBaselineStatus.valid.rawValue
        fetchedRun.appliedAt = Date(timeIntervalSince1970: 1_778_100_100)
        try context.save()

        let fetchedRecord = try XCTUnwrap(try context.fetch(FetchDescriptor<SupabaseCatalogBaselineRecord>()).first)
        XCTAssertEqual(fetchedRun.runKey, SupabaseCatalogBaselineRun.makeRunKey(ownerUserUUID: ownerID, baselineRunID: runID))
        XCTAssertEqual(fetchedRun.status, SupabaseCatalogBaselineStatus.valid.rawValue)
        XCTAssertEqual(fetchedRecord.recordKey, SupabaseCatalogBaselineRecord.makeRecordKey(baselineRunID: runID, entityType: .product, remoteID: remoteID))
        XCTAssertEqual(fetchedRecord.barcodeCanonical, "100")
    }

    func testTwoRunsWithSameRemoteIDDoNotCollide() throws {
        let context = try makeContext()
        let ownerID = UUID()
        let remoteID = UUID()
        let firstRunID = UUID()
        let secondRunID = UUID()

        context.insert(SupabaseCatalogBaselineRecord(
            baselineRunID: firstRunID,
            ownerUserUUID: ownerID,
            entityType: .product,
            remoteID: remoteID,
            fingerprintCanonical: "first"
        ))
        context.insert(SupabaseCatalogBaselineRecord(
            baselineRunID: secondRunID,
            ownerUserUUID: ownerID,
            entityType: .product,
            remoteID: remoteID,
            fingerprintCanonical: "second"
        ))

        XCTAssertNoThrow(try context.save())
        let records = try context.fetch(FetchDescriptor<SupabaseCatalogBaselineRecord>())
        XCTAssertEqual(records.count, 2)
        XCTAssertNotEqual(records[0].recordKey, records[1].recordKey)
    }

    func testDuplicateEntityAndRemoteIDInSameRunHasSameRecordKeyForWriterDetection() {
        let runID = UUID()
        let remoteID = UUID()

        XCTAssertEqual(
            SupabaseCatalogBaselineRecord.makeRecordKey(
                baselineRunID: runID,
                entityType: .product,
                remoteID: remoteID
            ),
            SupabaseCatalogBaselineRecord.makeRecordKey(
                baselineRunID: runID,
                entityType: .product,
                remoteID: remoteID
            )
        )
    }

    func testBuildingAndPartialRejectedRunsAreNotUsableStatuses() {
        XCTAssertNotEqual(SupabaseCatalogBaselineStatus.building.rawValue, SupabaseCatalogBaselineStatus.valid.rawValue)
        XCTAssertNotEqual(SupabaseCatalogBaselineStatus.partialRejected.rawValue, SupabaseCatalogBaselineStatus.valid.rawValue)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            ProductPrice.self,
            HistoryEntry.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        let context = ModelContext(container)
        Self.retainedContexts.append(context)
        return context
    }
}
