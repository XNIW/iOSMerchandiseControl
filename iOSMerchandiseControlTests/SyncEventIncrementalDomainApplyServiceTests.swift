import SwiftData
import XCTest
@testable import iOSMerchandiseControl

final class SyncEventIncrementalDomainApplyServiceTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    @MainActor
    func testUnrecoverableGapAdvancesWatermarkToAvoidRepeatingSamePage() async throws {
        let owner = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        let suiteName = "SyncEventIncrementalDomainApplyServiceTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let event = try syncEventRow(
            id: 101,
            ownerUserID: owner,
            domain: "catalog",
            changedCount: 1,
            entityIDsJSON: "null"
        )
        let remote = SyncEventIncrementalDomainApplyRemoteFake(events: [event])
        let service = SyncEventIncrementalDomainApplyService(
            eventFetcher: remote,
            remote: remote,
            defaults: defaults
        )

        let summary = try await service.applyNextEvents(
            ownerUserID: owner,
            modelContainer: try makeContainer(),
            isAuthenticated: true
        )

        XCTAssertEqual(summary.requiresFullRecoveryReason, "sync_event_missing_entity_ids")
        XCTAssertEqual(summary.watermarkBefore, 0)
        XCTAssertEqual(summary.watermarkAfter, 101)
        XCTAssertEqual(
            WatermarkStore(defaults: defaults).watermark(
                for: WatermarkStore.Scope(ownerUserID: owner, storeIdentity: .anonymous)
            ),
            101
        )
    }

    private func syncEventRow(
        id: Int64,
        ownerUserID: UUID,
        domain: String,
        changedCount: Int,
        entityIDsJSON: String
    ) throws -> RemoteSyncEventRow {
        let json = """
        {
          "id": \(id),
          "owner_user_id": "\(ownerUserID.uuidString)",
          "store_id": null,
          "domain": "\(domain)",
          "event_type": "test",
          "source": "test",
          "source_device_id": "android-test",
          "batch_id": null,
          "client_event_id": "TASK123-\(id)",
          "changed_count": \(changedCount),
          "entity_ids": \(entityIDsJSON),
          "created_at": "2026-05-25T00:00:00Z",
          "expires_at": null,
          "metadata": {}
        }
        """
        return try JSONDecoder().decode(RemoteSyncEventRow.self, from: Data(json.utf8))
    }

    @MainActor
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

@MainActor
private final class SyncEventIncrementalDomainApplyRemoteFake: SyncAutomaticIncrementalRemote, @unchecked Sendable {
    private let events: [RemoteSyncEventRow]

    init(events: [RemoteSyncEventRow]) {
        self.events = events
    }

    func fetchSyncEventsAfter(ownerUserID: UUID, afterID: Int64, limit: Int) async throws -> [RemoteSyncEventRow] {
        Array(events.filter { $0.ownerUserID == ownerUserID && $0.id > afterID }.prefix(limit))
    }

    func fetchCatalogByIDs(
        supplierIDs: Set<UUID>,
        categoryIDs: Set<UUID>,
        productIDs: Set<UUID>
    ) async throws -> (
        suppliers: [RemoteInventorySupplierRow],
        categories: [RemoteInventoryCategoryRow],
        products: [RemoteInventoryProductRow]
    ) {
        ([], [], [])
    }

    func fetchProductPricesByIDs(
        ownerUserID: UUID,
        priceIDs: Set<UUID>
    ) async throws -> [RemoteInventoryProductPriceRow] {
        []
    }

    func fetchReconciliationRemoteCounts() async throws -> SyncInventoryCountSnapshot {
        .zero
    }

    func upsertSharedSheetSessions(
        _ rows: [SharedSheetSessionUpsertRow],
        ownerUserID: UUID
    ) async throws -> [RemoteSharedSheetSessionRow] {
        []
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
        []
    }
}
