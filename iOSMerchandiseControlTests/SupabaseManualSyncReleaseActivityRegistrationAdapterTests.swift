import SwiftData
import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class SupabaseManualSyncReleaseActivityRegistrationAdapterTests: XCTestCase {
    private static var retainedContainers: [ModelContainer] = []

    private let now = Date(timeIntervalSince1970: 1_778_600_000)
    private let ownerID = UUID(uuidString: "00000000-0000-4000-8000-000000000081")!

    func testTask081EmptyActivityRegistrationDoesNotCallNetwork() async throws {
        let context = try makeContext()
        let recorder = ReleaseActivityRegistrationRecorder([])
        let adapter = makeAdapter(context: context, recorder: recorder)

        let result = try await adapter.registerActivities(ownerUserID: ownerID)

        XCTAssertEqual(result.status, .empty)
        XCTAssertEqual(result.summary, .empty)
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testTask081ValidActivityRegistrationDrainsAndUpdatesSummary() async throws {
        let context = try makeContext()
        let entry = try makeEntry(id: "entry-success", clientEventID: "client-success")
        try insert([entry], in: context)
        let before = try SyncEventOutboxLocalStore(context: context).fetchCounts(
            ownerUserID: ownerID.uuidString.lowercased(),
            now: now
        )
        XCTAssertEqual(before.retryable, 1)
        let recorder = ReleaseActivityRegistrationRecorder([
            .success(try row(id: 1, clientEventID: "client-success"))
        ])
        let adapter = makeAdapter(context: context, recorder: recorder)

        let result = try await adapter.registerActivities(ownerUserID: ownerID)
        let counts = try SyncEventOutboxLocalStore(context: context).fetchCounts(
            ownerUserID: ownerID.uuidString.lowercased(),
            now: now
        )

        XCTAssertEqual(result.status, .success)
        XCTAssertEqual(result.summary.registered, 1)
        XCTAssertEqual(result.summary.waiting, 0)
        XCTAssertEqual(result.summary.notRegisterable, 0)
        XCTAssertEqual(counts.sent, 1)
        XCTAssertEqual(counts.retryable, 0)
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 1)
    }

    func testTask081RetryableNetworkFailureKeepsAggregatedWaitingCount() async throws {
        let context = try makeContext()
        let entry = try makeEntry(id: "entry-network", clientEventID: "client-network")
        try insert([entry], in: context)
        let before = try SyncEventOutboxLocalStore(context: context).fetchCounts(
            ownerUserID: ownerID.uuidString.lowercased(),
            now: now
        )
        XCTAssertEqual(before.retryable, 1)
        let recorder = ReleaseActivityRegistrationRecorder([
            .failure(.network(SyncEventRecordFailure(code: "timeout", message: "network timeout")))
        ])
        let adapter = makeAdapter(context: context, recorder: recorder)

        let result = try await adapter.registerActivities(ownerUserID: ownerID)

        XCTAssertEqual(result.status, .retryableFailure)
        XCTAssertEqual(result.summary.registered, 0)
        XCTAssertEqual(result.summary.waiting, 1)
        XCTAssertEqual(result.summary.notRegisterable, 0)
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 1)
    }

    func testTask081BlockedPayloadMapsToNonRegisterableWithoutNetwork() async throws {
        let context = try makeContext()
        let entry = try SyncEventOutboxFactory.makeEntry(
            ownerUserID: ownerID.uuidString.lowercased(),
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 1,
            entityIDsShape: "product_ids:count=1",
            metadataShape: "source=ios_catalog_manual_push",
            now: now,
            id: "entry-blocked",
            clientEventID: "client-blocked"
        )
        try insert([entry], in: context)
        let before = try SyncEventOutboxLocalStore(context: context).fetchCounts(
            ownerUserID: ownerID.uuidString.lowercased(),
            now: now
        )
        XCTAssertEqual(before.retryable, 1)
        let recorder = ReleaseActivityRegistrationRecorder([
            .success(try row(id: 2, clientEventID: "client-blocked"))
        ])
        let adapter = makeAdapter(context: context, recorder: recorder)

        let result = try await adapter.registerActivities(ownerUserID: ownerID)
        let counts = try SyncEventOutboxLocalStore(context: context).fetchCounts(
            ownerUserID: ownerID.uuidString.lowercased(),
            now: now
        )

        XCTAssertEqual(result.status, .blocked)
        XCTAssertEqual(result.summary.registered, 0)
        XCTAssertEqual(result.summary.waiting, 0)
        XCTAssertEqual(result.summary.notRegisterable, 1)
        XCTAssertEqual(counts.blocked, 1)
        let callCount = await recorder.callCount()
        XCTAssertEqual(callCount, 0)
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([SyncEventOutboxEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        Self.retainedContainers.append(container)
        return ModelContext(container)
    }

    private func makeAdapter(
        context: ModelContext,
        recorder: any SyncEventRecording
    ) -> SyncActivityRegistrationAdapter {
        let fixedNow = now
        return SyncActivityRegistrationAdapter(
            context: context,
            recorder: recorder,
            now: { fixedNow },
            limit: 10
        )
    }

    private func insert(_ entries: [SyncEventOutboxEntry], in context: ModelContext) throws {
        let store = SyncEventOutboxLocalStore(context: context)
        entries.forEach(store.add)
        try context.save()
    }

    private func makeEntry(
        id: String,
        clientEventID: String
    ) throws -> SyncEventOutboxEntry {
        let request = SyncEventRecordRequest(
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 1,
            entityIDs: .null,
            metadata: .object(["source": .string("ios_catalog_manual_push")]),
            source: "ios_catalog_manual_push",
            sourceDeviceID: "device-task-081",
            batchID: nil,
            clientEventID: clientEventID
        )
        let payload = try SyncEventOutboxPayloadCodec.makePayloadJSON(for: request)
        return try SyncEventOutboxFactory.makeEntry(
            ownerUserID: ownerID.uuidString.lowercased(),
            domain: request.domain,
            eventType: request.eventType,
            changedCount: request.changedCount,
            entityIDsShape: "product_ids:count=1",
            metadataShape: "source=ios_catalog_manual_push",
            entityIDsPayloadJSON: payload.entityIDsPayloadJSON,
            metadataPayloadJSON: payload.metadataPayloadJSON,
            sourceDeviceID: request.sourceDeviceID,
            now: now,
            id: id,
            clientEventID: clientEventID
        )
    }

    private func row(id: Int64, clientEventID: String) throws -> RemoteSyncEventRow {
        let json = """
        {
          "id": \(id),
          "owner_user_id": "\(ownerID.uuidString.lowercased())",
          "domain": "catalog",
          "event_type": "catalog_changed",
          "source": "ios",
          "source_device_id": "device-task-081",
          "batch_id": null,
          "client_event_id": "\(clientEventID)",
          "changed_count": 1,
          "entity_ids": null,
          "created_at": "2026-05-08T12:34:56Z",
          "expires_at": null,
          "metadata": {
            "source": "fixture"
          }
        }
        """
        return try JSONDecoder().decode(RemoteSyncEventRow.self, from: Data(json.utf8))
    }
}

private actor ReleaseActivityRegistrationRecorder: SyncEventRecording {
    enum Response: Sendable {
        case success(RemoteSyncEventRow)
        case failure(SyncEventRecordError)
    }

    private var responses: [Response]
    private var recordedRequests: [SyncEventRecordRequest] = []

    init(_ responses: [Response]) {
        self.responses = responses
    }

    func record(_ request: SyncEventRecordRequest) async throws -> SyncEventRecordResult {
        recordedRequests.append(request)
        guard !responses.isEmpty else {
            throw SyncEventRecordError.unknown(
                SyncEventRecordFailure(code: "missing_fake_response", message: "Fake recorder response missing.")
            )
        }

        switch responses.removeFirst() {
        case .success(let row):
            return .recorded(row)
        case .failure(let error):
            throw error
        }
    }

    func callCount() -> Int {
        recordedRequests.count
    }
}
