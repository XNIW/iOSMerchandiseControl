import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class HistorySessionAutomaticPushServiceTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []
    private let owner = UUID(uuidString: "51515151-5151-4515-8515-515151515151")!

    func testTombstoneResponseLossRetriesSameIdentityAndCommitsAckWithOutbox() async throws {
        let fixture = try makeScopeFixture()
        defer { fixture.cleanup() }
        let container = try makeContainer()
        let context = ModelContext(container)
        let remoteID = UUID(uuidString: "61616161-6161-4616-8616-616161616161")!
        let deletedAt = Date(timeIntervalSince1970: 1_784_678_400)
        let entry = makeEntry(
            remoteID: remoteID,
            fixture: fixture,
            revision: 2,
            lastSyncedRevision: 1,
            deletedAt: deletedAt
        )
        context.insert(entry)
        context.insert(makePending(remoteID: remoteID, fixture: fixture))
        try context.save()

        let remote = AutomaticHistoryRemoteFake(failFirstAfterCommit: true)
        let service = HistorySessionPushService(
            modelContainer: container,
            remote: remote,
            recorder: nil,
            defaults: fixture.defaults
        )

        do {
            _ = try await service.syncHistorySessions(ownerUserID: owner, mode: .incremental)
            XCTFail("The committed-response-loss fixture must fail its first response")
        } catch AutomaticHistoryRemoteError.committedResponseLost {
            // Expected: the remote row exists, while local pending/outbox stay untouched.
        }

        var read = ModelContext(container)
        XCTAssertEqual(try pendingStatuses(context: read), [.pending])
        XCTAssertEqual(try read.fetchCount(FetchDescriptor<SyncEventOutboxEntry>()), 0)
        let persistedAfterLoss = remote.persistedRowCount()
        XCTAssertEqual(persistedAfterLoss, 1)

        let summary = try await service.syncHistorySessions(ownerUserID: owner, mode: .incremental)

        XCTAssertEqual(summary.uploaded, 1)
        let persistedAfterRetry = remote.persistedRowCount()
        let attemptedAfterRetry = remote.attemptedRemoteIDs()
        XCTAssertEqual(persistedAfterRetry, 1)
        XCTAssertEqual(attemptedAfterRetry, [remoteID, remoteID])
        read = ModelContext(container)
        let stored = try XCTUnwrap(try read.fetch(FetchDescriptor<HistoryEntry>()).first)
        XCTAssertEqual(stored.remoteDeletedAt, deletedAt)
        XCTAssertEqual(stored.lastSyncedLocalRevision, stored.localChangeRevision)
        XCTAssertEqual(try pendingStatuses(context: read), [.acknowledged])
        let outbox = try read.fetch(FetchDescriptor<SyncEventOutboxEntry>())
        XCTAssertEqual(outbox.count, 1)
        XCTAssertEqual(outbox.first?.domain, "history")
        XCTAssertEqual(outbox.first?.eventType, "history_tombstone")
        XCTAssertEqual(outbox.first?.changedCount, 1)
        XCTAssertEqual(outbox.first?.status, .pending)
    }

    func testPendingDrivenSelectionDoesNotStarveBehindMoreThanOneThousandCleanRows() async throws {
        let fixture = try makeScopeFixture()
        defer { fixture.cleanup() }
        let container = try makeContainer()
        let context = ModelContext(container)
        for index in 0..<1_002 {
            let cleanID = UUID()
            context.insert(makeEntry(
                remoteID: cleanID,
                fixture: fixture,
                revision: 1,
                lastSyncedRevision: 1,
                deletedAt: nil,
                id: "clean-\(index)"
            ))
        }
        let dirtyID = UUID(uuidString: "62626262-6262-4626-8626-626262626262")!
        context.insert(makeEntry(
            remoteID: dirtyID,
            fixture: fixture,
            revision: 1,
            lastSyncedRevision: 0,
            deletedAt: nil,
            id: "dirty-after-clean-prefix"
        ))
        context.insert(makePending(remoteID: dirtyID, fixture: fixture))
        try context.save()

        let remote = AutomaticHistoryRemoteFake()
        let service = HistorySessionPushService(
            modelContainer: container,
            remote: remote,
            recorder: nil,
            defaults: fixture.defaults
        )
        let summary = try await service.syncHistorySessions(ownerUserID: owner, mode: .incremental)

        XCTAssertEqual(summary.uploaded, 1)
        let starvationRequestSizes = remote.requestSizes()
        let starvationAttemptedIDs = remote.attemptedRemoteIDs()
        XCTAssertEqual(starvationRequestSizes, [1])
        XCTAssertEqual(starvationAttemptedIDs, [dirtyID])
        XCTAssertEqual(try pendingStatuses(context: ModelContext(container)), [.acknowledged])
    }

    func testHistoryRequestsAreChunkedAndEachAckHasDurableLocalEvent() async throws {
        let fixture = try makeScopeFixture()
        defer { fixture.cleanup() }
        let container = try makeContainer()
        let context = ModelContext(container)
        for index in 0..<7 {
            let remoteID = UUID()
            context.insert(makeEntry(
                remoteID: remoteID,
                fixture: fixture,
                revision: 1,
                lastSyncedRevision: 0,
                deletedAt: nil,
                id: "chunk-\(index)"
            ))
            context.insert(makePending(remoteID: remoteID, fixture: fixture))
        }
        try context.save()

        let remote = AutomaticHistoryRemoteFake()
        let summary = try await HistorySessionPushService(
            modelContainer: container,
            remote: remote,
            recorder: nil,
            defaults: fixture.defaults
        ).syncHistorySessions(ownerUserID: owner, mode: .incremental)

        XCTAssertEqual(summary.uploaded, 7)
        let chunkRequestSizes = remote.requestSizes()
        XCTAssertEqual(chunkRequestSizes, [3, 3, 1])
        let read = ModelContext(container)
        XCTAssertEqual(try pendingStatuses(context: read), Array(repeating: .acknowledged, count: 7))
        XCTAssertEqual(try read.fetchCount(FetchDescriptor<SyncEventOutboxEntry>()), 3)
    }

    func testOversizedHistoryPayloadBecomesStableBlockedReviewWithoutNetworkLoop() async throws {
        let fixture = try makeScopeFixture()
        defer { fixture.cleanup() }
        let container = try makeContainer()
        let context = ModelContext(container)
        let remoteID = UUID(uuidString: "63636363-6363-4636-8636-636363636363")!
        let oversizedValue = String(repeating: "x", count: HistorySessionPushService.maximumHistoryRowBytes)
        let entry = makeEntry(
            remoteID: remoteID,
            fixture: fixture,
            revision: 1,
            lastSyncedRevision: 0,
            deletedAt: nil,
            data: [["value"], [oversizedValue]]
        )
        context.insert(entry)
        context.insert(makePending(remoteID: remoteID, fixture: fixture))
        try context.save()

        let remote = AutomaticHistoryRemoteFake()
        let service = HistorySessionPushService(
            modelContainer: container,
            remote: remote,
            recorder: nil,
            defaults: fixture.defaults
        )
        let first = try await service.syncHistorySessions(ownerUserID: owner, mode: .incremental)
        let second = try await service.syncHistorySessions(ownerUserID: owner, mode: .incremental)

        XCTAssertEqual(first.uploaded, 0)
        XCTAssertEqual(first.skippedOversized, 1)
        XCTAssertEqual(second.uploaded, 0)
        XCTAssertEqual(second.skippedOversized, 0)
        let oversizedRequestSizes = remote.requestSizes()
        XCTAssertEqual(oversizedRequestSizes, [])
        XCTAssertEqual(try pendingStatuses(context: ModelContext(container)), [.blocked])
        XCTAssertEqual(try ModelContext(container).fetchCount(FetchDescriptor<SyncEventOutboxEntry>()), 0)
    }

    private func makeScopeFixture() throws -> AutomaticHistoryScopeFixture {
        let suiteName = "HistorySessionAutomaticPush-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let accountHash = AccountBindingStore.accountHash(for: owner)
        let shop = SelectedShop(
            shopID: UUID(),
            code: "HISTORY-AUTO",
            name: "History automatic fixture",
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true
        )
        let selected = SelectedShopStore(defaults: defaults)
        selected.noteActiveAccount(accountHash)
        XCTAssertTrue(selected.save(shop, accountHash: accountHash))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(
            accountHash: accountHash,
            storeIdentity: shop.localStoreIdentity
        ))
        return AutomaticHistoryScopeFixture(
            suiteName: suiteName,
            defaults: defaults,
            shopID: shop.shopID,
            storeIdentity: shop.localStoreIdentity
        )
    }

    private func makeEntry(
        remoteID: UUID,
        fixture: AutomaticHistoryScopeFixture,
        revision: Int,
        lastSyncedRevision: Int,
        deletedAt: Date?,
        id: String? = nil,
        data: [[String]] = [["barcode"], ["HISTORY-AUTO"]]
    ) -> HistoryEntry {
        let entry = HistoryEntry(
            id: id ?? remoteID.uuidString.lowercased(),
            timestamp: Date(timeIntervalSince1970: 1_784_678_000),
            data: data,
            editable: [[""], [""]],
            complete: [false, true],
            uid: remoteID,
            remoteID: remoteID,
            remoteUpdatedAt: Date(timeIntervalSince1970: 1_784_677_000),
            remoteDeletedAt: deletedAt,
            remotePayloadFingerprint: lastSyncedRevision > 0 ? "prior" : nil,
            localChangeRevision: revision,
            lastSyncedLocalRevision: lastSyncedRevision
        )
        entry.assignHistoryScope(
            ownerUserID: owner,
            selectedShopID: fixture.shopID,
            storeIdentity: fixture.storeIdentity
        )
        return entry
    }

    private func makePending(
        remoteID: UUID,
        fixture: AutomaticHistoryScopeFixture
    ) -> LocalPendingChange {
        LocalPendingChange(
            ownerUserID: owner,
            storeId: fixture.storeIdentity.storeId,
            localStoreId: fixture.storeIdentity.localStoreId,
            syncProtocolVersion: fixture.storeIdentity.syncProtocolVersion,
            schemaVersion: fixture.storeIdentity.schemaVersion,
            storeEpoch: fixture.storeIdentity.storeEpoch,
            entityKind: .historySession,
            operation: .upsert,
            status: .pending,
            origin: .historySessionSave,
            logicalKey: LocalPendingChangeLogicalKey.historySession(
                remoteID: remoteID,
                uid: remoteID
            ),
            changedFields: ["payload"],
            entityRemoteID: remoteID
        )
    }

    private func pendingStatuses(context: ModelContext) throws -> [LocalPendingChangeStatus] {
        try context.fetch(FetchDescriptor<LocalPendingChange>(
            sortBy: [SortDescriptor(\LocalPendingChange.changeID, order: .forward)]
        )).map(\.status)
    }

    private func makeContainer() throws -> ModelContainer {
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
        return container
    }
}

private struct AutomaticHistoryScopeFixture {
    let suiteName: String
    let defaults: UserDefaults
    let shopID: UUID
    let storeIdentity: LocalStoreIdentity

    func cleanup() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

private enum AutomaticHistoryRemoteError: Error {
    case committedResponseLost
}

@MainActor
private final class AutomaticHistoryRemoteFake: HistorySessionRemoteWriting, @unchecked Sendable {
    private var rowsByID: [UUID: RemoteSharedSheetSessionRow] = [:]
    private var requestRowCounts: [Int] = []
    private var attemptedIDs: [UUID] = []
    private var shouldFailAfterCommit: Bool

    init(failFirstAfterCommit: Bool = false) {
        shouldFailAfterCommit = failFirstAfterCommit
    }

    func upsertSharedSheetSessions(
        _ rows: [SharedSheetSessionUpsertRow],
        ownerUserID: UUID
    ) async throws -> [RemoteSharedSheetSessionRow] {
        requestRowCounts.append(rows.count)
        attemptedIDs.append(contentsOf: rows.map(\.remoteID))
        for row in rows {
            rowsByID[row.remoteID] = RemoteSharedSheetSessionRow(
                remoteID: row.remoteID,
                payloadVersion: row.payloadVersion,
                displayName: row.displayName,
                timestamp: row.timestamp,
                supplier: row.supplier,
                category: row.category,
                isManualEntry: row.isManualEntry,
                data: row.data,
                sessionOverlay: row.sessionOverlay,
                ownerUserID: ownerUserID,
                shopID: row.shopID,
                updatedAt: "2026-07-22T08:00:00Z",
                deletedAt: row.deletedAt
            )
        }
        if shouldFailAfterCommit {
            shouldFailAfterCommit = false
            throw AutomaticHistoryRemoteError.committedResponseLost
        }
        return rows.compactMap { rowsByID[$0.remoteID] }
    }

    func fetchSharedSheetSessionsPage(
        ownerUserID: UUID,
        from: Int,
        to: Int
    ) async throws -> [RemoteSharedSheetSessionRow] {
        []
    }

    func fetchSharedSheetSessionsByIDs(
        ownerUserID: UUID,
        sessionIDs: Set<UUID>
    ) async throws -> [RemoteSharedSheetSessionRow] {
        sessionIDs.compactMap { rowsByID[$0] }
    }

    func persistedRowCount() -> Int { rowsByID.count }
    func requestSizes() -> [Int] { requestRowCounts }
    func attemptedRemoteIDs() -> [UUID] { attemptedIDs }
}
