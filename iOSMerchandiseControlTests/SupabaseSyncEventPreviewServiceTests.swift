import XCTest
@testable import iOSMerchandiseControl

final class SupabaseSyncEventPreviewServiceTests: XCTestCase {
    private let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    func testDecodesValidSyncEventDTO() throws {
        let row = try decodeRow("""
        {
          "id": 42,
          "owner_user_id": "00000000-0000-0000-0000-000000000001",
          "store_id": "00000000-0000-0000-0000-000000000002",
          "domain": "catalog",
          "event_type": "catalog_changed",
          "source": "android",
          "source_device_id": "device-hash",
          "batch_id": "00000000-0000-0000-0000-000000000003",
          "client_event_id": "client-1",
          "changed_count": 2,
          "entity_ids": {
            "product_ids": ["00000000-0000-0000-0000-000000000004"]
          },
          "created_at": "2026-05-06T12:34:56.789Z",
          "expires_at": null,
          "metadata": {
            "task": "fixture"
          }
        }
        """)

        XCTAssertEqual(row.id, 42)
        XCTAssertEqual(row.ownerUserID, ownerID)
        XCTAssertEqual(row.storeID, uuid(2))
        XCTAssertEqual(row.domain, "catalog")
        XCTAssertEqual(row.eventType, "catalog_changed")
        XCTAssertEqual(row.source, "android")
        XCTAssertEqual(row.sourceDeviceID, "device-hash")
        XCTAssertEqual(row.batchID, uuid(3))
        XCTAssertEqual(row.clientEventID, "client-1")
        XCTAssertEqual(row.changedCount, 2)
        XCTAssertNil(row.expiresAt)
    }

    func testExtraFieldsAreIgnoredAndJSONObjectsDecode() throws {
        let row = try decodeRow("""
        {
          "id": 43,
          "owner_user_id": "00000000-0000-0000-0000-000000000001",
          "domain": "prices",
          "event_type": "prices_changed",
          "changed_count": 1,
          "entity_ids": {
            "price_ids": ["00000000-0000-0000-0000-000000000005"]
          },
          "created_at": "2026-05-06T12:34:56Z",
          "metadata": {
            "chunk_index": 0,
            "done": true
          },
          "extra_field_from_postgrest": "ignored"
        }
        """)

        guard case .object(let entityIDs) = try XCTUnwrap(row.entityIDs),
              case .array(let priceIDs) = try XCTUnwrap(entityIDs["price_ids"]),
              case .string("00000000-0000-0000-0000-000000000005") = try XCTUnwrap(priceIDs.first) else {
            return XCTFail("Expected entity_ids.price_ids array")
        }

        guard case .object(let metadata) = row.metadata,
              case .number(0) = try XCTUnwrap(metadata["chunk_index"]),
              case .bool(true) = try XCTUnwrap(metadata["done"]) else {
            return XCTFail("Expected metadata object")
        }
    }

    func testArrayResponseDecodesIntoRowsEnvelope() throws {
        let response = try decodeResponse("""
        [
          \(fixtureRow(id: 50, createdAt: "2026-05-06T12:34:56Z")),
          \(fixtureRow(id: 51, createdAt: "2026-05-06T12:35:56Z"))
        ]
        """)

        XCTAssertEqual(response.rows.map(\.id), [50, 51])
    }

    func testObjectResponseDecodesIntoRowsEnvelope() throws {
        let response = try decodeResponse(fixtureRow(id: 52, createdAt: "2026-05-06T12:34:56Z"))

        XCTAssertEqual(response.rows.count, 1)
        XCTAssertEqual(response.rows.first?.id, 52)
    }

    func testDateParsingSupportsSupabaseTimestamptzShapes() throws {
        let isoRow = try decodeRow(fixtureRow(id: 60, createdAt: "2026-05-06T12:34:56.123Z"))
        let postgresRow = try decodeRow(fixtureRow(id: 61, createdAt: "2026-05-06 12:34:56+00"))
        let expiringRow = try decodeRow("""
        {
          "id": 62,
          "owner_user_id": "00000000-0000-0000-0000-000000000001",
          "domain": "catalog",
          "event_type": "catalog_changed",
          "changed_count": 1,
          "entity_ids": null,
          "created_at": "2026-05-06T12:34:56Z",
          "expires_at": "2026-05-07T12:34:56Z",
          "metadata": {}
        }
        """)

        XCTAssertEqual(isoRow.createdAt.timeIntervalSince1970, 1_778_070_896.123, accuracy: 0.001)
        XCTAssertEqual(postgresRow.createdAt.timeIntervalSince1970, 1_778_070_896, accuracy: 0.001)
        let expiresAt = try XCTUnwrap(expiringRow.expiresAt)
        XCTAssertEqual(expiresAt.timeIntervalSince1970, 1_778_157_296, accuracy: 0.001)
    }

    func testServiceUsesDefaultLimitOfLastFiftyEvents() async throws {
        let rows = (0..<80).map { index in
            syncEvent(id: Int64(index + 1))
        }
        let fetcher = MockSyncEventPreviewFetching(rows: rows)
        let service = SupabaseSyncEventPreviewService(fetcher: fetcher)

        let summary = try await service.loadLatestEvents()
        let limits = await fetcher.recordedLimits()

        XCTAssertEqual(summary.requestedLimit, nil)
        XCTAssertEqual(summary.effectiveLimit, 50)
        XCTAssertEqual(summary.events.count, 50)
        XCTAssertEqual(limits, [50])
    }

    func testServiceClampsRequestedLimitToDocumentedMaximum() async throws {
        let rows = (0..<250).map { index in
            syncEvent(id: Int64(index + 1))
        }
        let fetcher = MockSyncEventPreviewFetching(rows: rows)
        let service = SupabaseSyncEventPreviewService(fetcher: fetcher)

        let summary = try await service.loadLatestEvents(limit: 1_000)
        let limits = await fetcher.recordedLimits()

        XCTAssertEqual(summary.requestedLimit, 1_000)
        XCTAssertEqual(summary.effectiveLimit, 200)
        XCTAssertTrue(summary.isLimitClamped)
        XCTAssertEqual(summary.events.count, 200)
        XCTAssertEqual(limits, [200])
    }

    func testCustomMaximumLimitIsClampedToGlobalMaximum200() async throws {
        let rows = (0..<250).map { index in
            syncEvent(id: Int64(index + 1))
        }
        let fetcher = MockSyncEventPreviewFetching(rows: rows)
        let service = SupabaseSyncEventPreviewService(
            fetcher: fetcher,
            options: SyncEventPreviewOptions(defaultLimit: 50, maximumLimit: 500)
        )

        let summary = try await service.loadLatestEvents(limit: 999)
        let limits = await fetcher.recordedLimits()

        XCTAssertEqual(service.options.maximumLimit, 200)
        XCTAssertEqual(summary.requestedLimit, 999)
        XCTAssertEqual(summary.effectiveLimit, 200)
        XCTAssertTrue(summary.isLimitClamped)
        XCTAssertEqual(summary.events.count, 200)
        XCTAssertEqual(limits, [200])
    }

    func testServiceCanUseFakeWithoutLiveSupabase() async throws {
        let rows = [syncEvent(id: 1), syncEvent(id: 2)]
        let service = SupabaseSyncEventPreviewService(
            fetcher: MockSyncEventPreviewFetching(rows: rows),
            options: SyncEventPreviewOptions(defaultLimit: 10, maximumLimit: 20)
        )

        let summary = try await service.loadLatestEvents(limit: 2)

        XCTAssertEqual(summary.events.map(\.id), [1, 2])
    }

    func testProductionSyncEventSourcesExposeReadOnlySurfaceOnly() throws {
        let productionSources = [
            try source(named: "SupabaseSyncEventDTOs.swift"),
            try source(relativePath: "Sync/Manual/SupabaseSyncEventPreviewService.swift")
        ].joined(separator: "\n")

        let forbiddenTokens = [
            [".", "in", "sert", "("].joined(),
            [".", "up", "sert", "("].joined(),
            [".", "up", "date", "("].joined(),
            [".", "de", "lete", "("].joined(),
            ["record", "sync", "event"].joined(separator: "_"),
            [".", "rpc", "("].joined(),
            [".", "channel", "("].joined(),
            [".", "subscribe", "("].joined(),
            ["BG", "Task"].joined()
        ]

        for token in forbiddenTokens {
            XCTAssertFalse(productionSources.contains(token), "Unexpected non-read-only token: \(token)")
        }
    }

    private func decodeRow(_ json: String) throws -> RemoteSyncEventRow {
        try JSONDecoder().decode(RemoteSyncEventRow.self, from: Data(json.utf8))
    }

    private func decodeResponse(_ json: String) throws -> SyncEventRowsResponse {
        try JSONDecoder().decode(SyncEventRowsResponse.self, from: Data(json.utf8))
    }

    private func fixtureRow(id: Int, createdAt: String) -> String {
        """
        {
          "id": \(id),
          "owner_user_id": "00000000-0000-0000-0000-000000000001",
          "domain": "catalog",
          "event_type": "catalog_changed",
          "changed_count": 1,
          "entity_ids": null,
          "created_at": "\(createdAt)",
          "expires_at": null,
          "metadata": {}
        }
        """
    }

    private func syncEvent(id: Int64) -> RemoteSyncEventRow {
        try! decodeRow(fixtureRow(id: Int(id), createdAt: "2026-05-06T12:34:56Z"))
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", value))")!
    }

    private func source(relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = testsDirectory
            .appendingPathComponent("iOSMerchandiseControl")
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func source(named fileName: String) throws -> String {
        try source(relativePath: fileName)
    }
}

private actor MockSyncEventPreviewFetching: SupabaseSyncEventPreviewFetching {
    private let rows: [RemoteSyncEventRow]
    private var limits: [Int] = []

    init(rows: [RemoteSyncEventRow]) {
        self.rows = rows
    }

    func fetchLatestSyncEvents(limit: Int) async throws -> [RemoteSyncEventRow] {
        limits.append(limit)
        return Array(rows.prefix(limit))
    }

    func recordedLimits() -> [Int] {
        limits
    }
}
