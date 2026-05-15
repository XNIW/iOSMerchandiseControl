import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class HistorySessionSyncServiceTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private let owner = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!

    func testPushUploadsDirtyHistorySessionAndAcknowledgesPendingChange() async throws {
        let context = try makeContext()
        let remote = FakeHistorySessionRemote(ownerUserID: owner)
        let service = HistorySessionSyncService(remote: remote)
        let entry = HistoryEntry(
            id: "TASK108_HISTORY_LOCAL",
            timestamp: Date(timeIntervalSince1970: 1_778_400_000),
            data: [["barcode", "quantity"], ["TASK108_HISTORY_BAR", "2"]],
            editable: [[""], ["2"]],
            complete: [false, true],
            supplier: "TASK108_HISTORY_SUP",
            category: "TASK108_HISTORY_CAT",
            uid: UUID(uuidString: "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")!
        )
        context.insert(entry)
        entry.markHistorySessionLocalMutation()
        try LocalPendingChangeAccumulator(context: context, ownerUserID: owner)
            .recordHistorySessionChange(
                entry: entry,
                operation: .upsert,
                changedFields: ["data"]
            )
        try context.save()

        let result = try await service.pushPendingHistorySessions(
            entries: [entry],
            ownerUserID: owner,
            context: context
        )
        try context.save()

        XCTAssertEqual(result.uploadedCount, 1)
        XCTAssertEqual(result.skippedCleanCount, 0)
        let upsertedRemoteIDs = await remote.upsertedRemoteIDs()
        XCTAssertEqual(upsertedRemoteIDs, [entry.remoteID])
        XCTAssertEqual(entry.syncStatus, .syncedSuccessfully)
        XCTAssertEqual(entry.lastSyncedLocalRevision, entry.localChangeRevision)
        XCTAssertNotNil(entry.remotePayloadFingerprint)

        let changes = try context.fetch(FetchDescriptor<LocalPendingChange>())
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.entityKind, .historySession)
        XCTAssertEqual(changes.first?.status, .acknowledged)
    }

    func testPullInsertsRemoteHistorySession() async throws {
        let context = try makeContext()
        let remoteID = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        let row = remoteRow(
            remoteID: remoteID,
            displayName: "TASK108_HISTORY_REMOTE",
            data: [["barcode", "quantity", "purchasePrice"], ["TASK108_HISTORY_REMOTE_BAR", "3", "2.50"]],
            editable: [[""], ["3"]],
            complete: [false, true]
        )
        let service = HistorySessionSyncService(remote: FakeHistorySessionRemote(ownerUserID: owner, rows: [row]))

        let result = try await service.pullHistorySessionsFromCloud(ownerUserID: owner, context: context)

        XCTAssertEqual(result.insertedCount, 1)
        let entries = try context.fetch(FetchDescriptor<HistoryEntry>())
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.remoteID, remoteID)
        XCTAssertEqual(entries.first?.title, "TASK108_HISTORY_REMOTE")
        XCTAssertEqual(entries.first?.data, row.data)
        XCTAssertEqual(entries.first?.editable, row.sessionOverlay?.editable)
        XCTAssertEqual(entries.first?.complete, row.sessionOverlay?.complete)
        XCTAssertEqual(entries.first?.orderTotal, 7.5)
        XCTAssertEqual(entries.first?.paymentTotal, 7.5)
        XCTAssertEqual(entries.first?.missingItems, 0)
        XCTAssertEqual(entries.first?.syncStatus, .syncedSuccessfully)
    }

    func testSecondPullIsNoOpAndDoesNotDuplicateRemoteHistorySession() async throws {
        let context = try makeContext()
        let remoteID = UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd")!
        let row = remoteRow(
            remoteID: remoteID,
            displayName: "TASK108_HISTORY_IDEMPOTENT",
            data: [["barcode", "quantity"], ["TASK108_HISTORY_REMOTE_BAR", "3"]],
            editable: [[""], ["3"]],
            complete: [false, true]
        )
        let service = HistorySessionSyncService(remote: FakeHistorySessionRemote(ownerUserID: owner, rows: [row]))

        let first = try await service.pullHistorySessionsFromCloud(ownerUserID: owner, context: context)
        let second = try await service.pullHistorySessionsFromCloud(ownerUserID: owner, context: context)

        XCTAssertEqual(first.insertedCount, 1)
        XCTAssertEqual(second.skippedCleanCount, 1)
        XCTAssertEqual(second.insertedCount, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HistoryEntry>()), 1)
    }

    func testPullUpdatesChangedRemoteSessionWhenLocalEntryIsClean() async throws {
        let context = try makeContext()
        let remoteID = UUID(uuidString: "eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee")!
        let entry = HistoryEntry(
            id: remoteID.uuidString.lowercased(),
            data: [["barcode"], ["OLD"]],
            editable: [[""], [""]],
            complete: [false, false],
            supplier: "OLD_SUP",
            uid: remoteID,
            remoteID: remoteID,
            remotePayloadFingerprint: "old",
            localChangeRevision: 1,
            lastSyncedLocalRevision: 1
        )
        context.insert(entry)
        let row = remoteRow(
            remoteID: remoteID,
            displayName: "REMOTE_UPDATED",
            data: [["barcode"], ["REMOTE"]],
            editable: [[""], ["9"]],
            complete: [false, true]
        )
        let service = HistorySessionSyncService(remote: FakeHistorySessionRemote(ownerUserID: owner, rows: [row]))

        let result = try await service.pullHistorySessionsFromCloud(ownerUserID: owner, context: context)

        XCTAssertEqual(result.updatedCount, 1)
        XCTAssertEqual(entry.title, "REMOTE_UPDATED")
        XCTAssertEqual(entry.data, [["barcode"], ["REMOTE"]])
        XCTAssertEqual(entry.editable, [[""], ["9"]])
        XCTAssertEqual(entry.complete, [false, true])
        XCTAssertEqual(entry.lastSyncedLocalRevision, entry.localChangeRevision)
    }

    func testPullSkipsDirtyLocalEntryInsteadOfOverwritingIt() async throws {
        let context = try makeContext()
        let remoteID = UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!
        let entry = HistoryEntry(
            id: "TASK108_HISTORY_DIRTY",
            data: [["barcode"], ["LOCAL"]],
            editable: [[""], [""]],
            complete: [false, false],
            uid: remoteID,
            remoteID: remoteID,
            remotePayloadFingerprint: "old",
            localChangeRevision: 2,
            lastSyncedLocalRevision: 1
        )
        context.insert(entry)
        let row = remoteRow(
            remoteID: remoteID,
            displayName: "REMOTE",
            data: [["barcode"], ["REMOTE"]],
            editable: [[""], [""]],
            complete: [false, true]
        )
        let service = HistorySessionSyncService(remote: FakeHistorySessionRemote(ownerUserID: owner, rows: [row]))

        let result = try await service.pullHistorySessionsFromCloud(ownerUserID: owner, context: context)

        XCTAssertEqual(result.skippedDirtyLocalCount, 1)
        XCTAssertEqual(entry.data, [["barcode"], ["LOCAL"]])
        XCTAssertEqual(entry.localChangeRevision, 2)
        XCTAssertEqual(entry.lastSyncedLocalRevision, 1)
    }

    func testPullRejectsOwnerMismatch() async throws {
        let context = try makeContext()
        let remoteID = UUID(uuidString: "ffffffff-ffff-4fff-8fff-ffffffffffff")!
        let otherOwner = UUID(uuidString: "99999999-9999-4999-8999-999999999999")!
        let row = RemoteSharedSheetSessionRow(
            remoteID: remoteID,
            payloadVersion: HistorySessionPayloadCodec.payloadVersion,
            displayName: "OWNER_MISMATCH",
            timestamp: "2026-05-13 12:00:00",
            supplier: "SUP",
            category: "CAT",
            isManualEntry: false,
            data: [["barcode"], ["REMOTE"]],
            sessionOverlay: HistorySessionOverlayPayload(
                overlaySchema: HistorySessionPayloadCodec.overlaySchema,
                editable: [[""], [""]],
                complete: [false, false]
            ),
            ownerUserID: otherOwner,
            updatedAt: "2026-05-13T12:00:01Z"
        )
        let service = HistorySessionSyncService(remote: FakeHistorySessionRemote(ownerUserID: owner, rows: [row]))

        do {
            _ = try await service.pullHistorySessionsFromCloud(ownerUserID: owner, context: context)
            XCTFail("Expected owner mismatch to be rejected.")
        } catch let error as HistorySessionSyncError {
            XCTAssertEqual(error, .ownerMismatch)
        }
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<HistoryEntry>()), 0)
    }

    func testHistoryPendingCountsAsQueuedCloudOperationForOptions() async throws {
        let context = try makeContext()
        let entry = HistoryEntry(id: "TASK108_HISTORY_PENDING")
        context.insert(entry)
        entry.markHistorySessionLocalMutation()
        try LocalPendingChangeAccumulator(context: context, ownerUserID: owner)
            .recordHistorySessionChange(
                entry: entry,
                operation: .upsert,
                changedFields: ["data"]
            )
        try context.save()

        let localSnapshot = try LocalPendingChangeSnapshotProvider(context: context)
            .loadSnapshot(ownerUserID: owner)

        XCTAssertEqual(localSnapshot.pendingHistorySessionChangeCount, 1)
        XCTAssertEqual(localSnapshot.pendingCatalogChangeCount, 0)
        XCTAssertEqual(localSnapshot.pendingProductPriceChangeCount, 0)
    }

    private func remoteRow(
        remoteID: UUID,
        displayName: String,
        data: [[String]],
        editable: [[String]],
        complete: [Bool]
    ) -> RemoteSharedSheetSessionRow {
        RemoteSharedSheetSessionRow(
            remoteID: remoteID,
            payloadVersion: HistorySessionPayloadCodec.payloadVersion,
            displayName: displayName,
            timestamp: "2026-05-13 12:00:00",
            supplier: "TASK108_HISTORY_SUP",
            category: "TASK108_HISTORY_CAT",
            isManualEntry: false,
            data: data,
            sessionOverlay: HistorySessionOverlayPayload(
                overlaySchema: HistorySessionPayloadCodec.overlaySchema,
                editable: editable,
                complete: complete
            ),
            ownerUserID: owner,
            updatedAt: "2026-05-13T12:00:01Z"
        )
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self,
            HistoryEntry.self,
            ProductPrice.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self,
            SyncEventOutboxEntry.self,
            LocalPendingChange.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return ModelContext(container)
    }
}

private actor FakeHistorySessionRemote: HistorySessionRemoteSyncing {
    private let ownerUserID: UUID
    private var rows: [RemoteSharedSheetSessionRow]
    private var upserted: [SharedSheetSessionUpsertRow] = []

    init(ownerUserID: UUID, rows: [RemoteSharedSheetSessionRow] = []) {
        self.ownerUserID = ownerUserID
        self.rows = rows
    }

    func upsertSharedSheetSessions(
        _ rows: [SharedSheetSessionUpsertRow],
        ownerUserID: UUID
    ) async throws -> [RemoteSharedSheetSessionRow] {
        XCTAssertEqual(ownerUserID, self.ownerUserID)
        upserted.append(contentsOf: rows)
        let readBack = rows.map {
            RemoteSharedSheetSessionRow(
                remoteID: $0.remoteID,
                payloadVersion: $0.payloadVersion,
                displayName: $0.displayName,
                timestamp: $0.timestamp,
                supplier: $0.supplier,
                category: $0.category,
                isManualEntry: $0.isManualEntry,
                data: $0.data,
                sessionOverlay: $0.sessionOverlay,
                ownerUserID: $0.ownerUserID,
                updatedAt: "2026-05-13T12:00:01Z"
            )
        }
        self.rows = readBack
        return readBack
    }

    func fetchSharedSheetSessionsPage(
        ownerUserID: UUID,
        from: Int,
        to: Int
    ) async throws -> [RemoteSharedSheetSessionRow] {
        XCTAssertEqual(ownerUserID, self.ownerUserID)
        guard from < rows.count else { return [] }
        return Array(rows[from...min(to, rows.count - 1)])
    }

    func upsertedRemoteIDs() -> [UUID?] {
        upserted.map(\.remoteID)
    }
}
