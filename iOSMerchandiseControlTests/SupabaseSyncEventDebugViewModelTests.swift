import XCTest
@testable import iOSMerchandiseControl

@MainActor
final class SupabaseSyncEventDebugViewModelTests: XCTestCase {
    func testIdleLoadingSuccessWithEvents() async throws {
        let fetcher = ControlledSyncEventPreviewFetching()
        let viewModel = SupabaseSyncEventDebugViewModel(service: service(fetcher: fetcher))

        XCTAssertEqual(viewModel.state, .idle)
        let loadTask = Task { await viewModel.loadLatestEvents() }
        try await waitForRequestCount(1, fetcher: fetcher)

        XCTAssertEqual(viewModel.state, .loading)

        await fetcher.succeed(rows: [syncEvent(id: 1)])
        await loadTask.value

        XCTAssertEqual(viewModel.state, .successWithEvents)
        XCTAssertEqual(viewModel.displayRows.count, 1)
        XCTAssertEqual(viewModel.summary?.loadedCount, 1)
    }

    func testSuccessEmpty() async throws {
        let fetcher = ImmediateSyncEventPreviewFetching(outcome: .rows([]))
        let viewModel = SupabaseSyncEventDebugViewModel(service: service(fetcher: fetcher))

        await viewModel.loadLatestEvents()

        XCTAssertEqual(viewModel.state, .successEmpty)
        XCTAssertEqual(viewModel.displayRows.count, 0)
        XCTAssertEqual(viewModel.summary?.loadedCount, 0)
    }

    func testNoSession() async throws {
        let fetcher = ImmediateSyncEventPreviewFetching(outcome: .serviceError(.sessionMissing))
        let viewModel = SupabaseSyncEventDebugViewModel(service: service(fetcher: fetcher))

        await viewModel.loadLatestEvents()

        XCTAssertEqual(viewModel.state, .noSession)
        XCTAssertEqual(viewModel.displayRows.count, 0)
        XCTAssertNil(viewModel.summary)
    }

    func testNotConfigured() async throws {
        let viewModel = SupabaseSyncEventDebugViewModel(service: nil)

        await viewModel.loadLatestEvents()

        XCTAssertEqual(viewModel.state, .notConfigured)
        XCTAssertEqual(viewModel.displayRows.count, 0)
        XCTAssertNil(viewModel.summary)
    }

    func testSchemaAndDecodingErrorsUseSanitizedErrorState() async throws {
        let errors: [SupabaseTransportClientError] = [
            .schemaDrift(message: "Missing key metadata."),
            .decodingError(message: "Bearer token should not be shown")
        ]

        for error in errors {
            let fetcher = ImmediateSyncEventPreviewFetching(outcome: .serviceError(error))
            let viewModel = SupabaseSyncEventDebugViewModel(service: service(fetcher: fetcher))

            await viewModel.loadLatestEvents()

            guard case .error(let message) = viewModel.state else {
                return XCTFail("Expected sanitized error state")
            }
            XCTAssertFalse(message.lowercased().contains("bearer"))
            XCTAssertFalse(message.lowercased().contains("token should"))
            XCTAssertEqual(viewModel.displayRows.count, 0)
            XCTAssertNil(viewModel.summary)
        }
    }

    func testInventoryServiceDiagnosticRedactsURLBusinessIDsAndEmail() {
        let detail = SupabaseTransportClientError.sanitizedDiagnosticDetail(
            "GET https://example.supabase.co/rest/v1/inventory_products?select=*&barcode=1234567890123 owner=00000000-0000-0000-0000-000000000001 email=user@example.test"
        )

        XCTAssertNotNil(detail)
        XCTAssertFalse(detail?.contains("https://example.supabase.co") ?? true)
        XCTAssertFalse(detail?.contains("1234567890123") ?? true)
        XCTAssertFalse(detail?.contains("00000000-0000-0000-0000-000000000001") ?? true)
        XCTAssertFalse(detail?.contains("user@example.test") ?? true)
    }

    func testCancelDuringLoadingReturnsIdleAndIgnoresLateResult() async throws {
        let fetcher = ControlledSyncEventPreviewFetching()
        let viewModel = SupabaseSyncEventDebugViewModel(service: service(fetcher: fetcher))

        let loadTask = Task { await viewModel.loadLatestEvents() }
        try await waitForRequestCount(1, fetcher: fetcher)

        viewModel.cancel()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.displayRows.count, 0)
        XCTAssertNil(viewModel.summary)

        await fetcher.succeed(rows: [syncEvent(id: 2)])
        await loadTask.value

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.displayRows.count, 0)
        XCTAssertNil(viewModel.summary)
    }

    func testResetAfterSuccessReturnsIdleAndClearsBuffers() async throws {
        let fetcher = ImmediateSyncEventPreviewFetching(outcome: .rows([syncEvent(id: 3)]))
        let viewModel = SupabaseSyncEventDebugViewModel(service: service(fetcher: fetcher))

        await viewModel.loadLatestEvents()
        XCTAssertEqual(viewModel.state, .successWithEvents)

        viewModel.reset()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.displayRows.count, 0)
        XCTAssertNil(viewModel.summary)
    }

    func testResetDuringLoadingReturnsIdleAndIgnoresLateResult() async throws {
        let fetcher = ControlledSyncEventPreviewFetching()
        let viewModel = SupabaseSyncEventDebugViewModel(service: service(fetcher: fetcher))

        let loadTask = Task { await viewModel.loadLatestEvents() }
        try await waitForRequestCount(1, fetcher: fetcher)

        viewModel.reset()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.displayRows.count, 0)
        XCTAssertNil(viewModel.summary)

        await fetcher.succeed(rows: [syncEvent(id: 30)])
        await loadTask.value

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.displayRows.count, 0)
        XCTAssertNil(viewModel.summary)
    }

    func testDoubleLoadDuringLoadingStartsOnlyOneFetch() async throws {
        let fetcher = ControlledSyncEventPreviewFetching()
        let viewModel = SupabaseSyncEventDebugViewModel(service: service(fetcher: fetcher))

        let firstLoad = Task { await viewModel.loadLatestEvents() }
        try await waitForRequestCount(1, fetcher: fetcher)

        let secondLoad = Task { await viewModel.loadLatestEvents() }
        await secondLoad.value

        let requestCount = await fetcher.requestCount()
        XCTAssertEqual(requestCount, 1)

        await fetcher.succeed(rows: [syncEvent(id: 4)])
        await firstLoad.value
        XCTAssertEqual(viewModel.state, .successWithEvents)
    }

    func testDisplayCapTwentyOnFiftyEvents() async throws {
        let rows = (0..<50).map { syncEvent(id: Int64($0 + 1)) }
        let fetcher = ImmediateSyncEventPreviewFetching(outcome: .rows(rows))
        let viewModel = SupabaseSyncEventDebugViewModel(service: service(fetcher: fetcher))

        await viewModel.loadLatestEvents()

        XCTAssertEqual(viewModel.state, .successWithEvents)
        XCTAssertEqual(viewModel.displayRows.count, 20)
        XCTAssertEqual(viewModel.summary?.loadedCount, 50)
        XCTAssertEqual(viewModel.summary?.displayedCount, 20)
    }

    func testEffectiveLimitIsDefaultFifty() async throws {
        let rows = (0..<80).map { syncEvent(id: Int64($0 + 1)) }
        let fetcher = ImmediateSyncEventPreviewFetching(outcome: .rows(rows))
        let viewModel = SupabaseSyncEventDebugViewModel(service: service(fetcher: fetcher))

        await viewModel.loadLatestEvents()

        let limits = await fetcher.recordedLimits()
        XCTAssertEqual(limits, [50])
        XCTAssertEqual(viewModel.summary?.effectiveLimit, 50)
        XCTAssertEqual(viewModel.summary?.isLimitClamped, false)
    }

    func testDisplayedCountFormulaForPlannedTotals() {
        XCTAssertEqual(SyncEventDebugDisplaySummary.displayedCount(forTotal: 0), 0)
        XCTAssertEqual(SyncEventDebugDisplaySummary.displayedCount(forTotal: 5), 5)
        XCTAssertEqual(SyncEventDebugDisplaySummary.displayedCount(forTotal: 20), 20)
        XCTAssertEqual(SyncEventDebugDisplaySummary.displayedCount(forTotal: 50), 20)
    }

    func testFormatterShapeAndTopLevelCounts() {
        XCTAssertEqual(SyncEventDebugFormatter.summary(for: SyncEventJSONValue.object(["a": .null, "b": .bool(true)])).shape, .object)
        XCTAssertEqual(SyncEventDebugFormatter.summary(for: SyncEventJSONValue.object(["a": .null, "b": .bool(true)])).countText, "2")

        XCTAssertEqual(SyncEventDebugFormatter.summary(for: SyncEventJSONValue.array([.string("safe")])).shape, .array)
        XCTAssertEqual(SyncEventDebugFormatter.summary(for: SyncEventJSONValue.array([.string("safe")])).countText, "1")

        XCTAssertEqual(SyncEventDebugFormatter.summary(for: SyncEventJSONValue.string("safe preview")).shape, .string)
        XCTAssertEqual(SyncEventDebugFormatter.summary(for: SyncEventJSONValue.number(3)).shape, .number)
        XCTAssertEqual(SyncEventDebugFormatter.summary(for: SyncEventJSONValue.bool(false)).shape, .boolean)
        XCTAssertEqual(SyncEventDebugFormatter.summary(for: SyncEventJSONValue.null).shape, .empty)
        XCTAssertEqual(SyncEventDebugFormatter.summary(for: Optional<SyncEventJSONValue>.none).shape, .notAvailable)
    }

    func testSanitizedPreviewMaxFortyEightAndRedactsSensitiveShapes() {
        let safePreview = SyncEventDebugFormatter.sanitizedPreview(
            from: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
            maxLength: 48
        )

        XCTAssertEqual(safePreview?.count, 48)
        XCTAssertNil(SyncEventDebugFormatter.sanitizedPreview(from: "Bearer abc.def.ghi"))
        XCTAssertNil(SyncEventDebugFormatter.sanitizedPreview(from: "https://example.test/path?access_token=secret"))
        XCTAssertNil(SyncEventDebugFormatter.sanitizedPreview(from: "00000000-0000-0000-0000-000000000001"))
        XCTAssertNil(SyncEventDebugFormatter.sanitizedPreview(from: "barcode 1234567890123"))
    }

    func testViewModelExposesSafeDisplayRowsInsteadOfRawDTOs() async throws {
        let fetcher = ImmediateSyncEventPreviewFetching(outcome: .rows([
            syncEvent(
                id: 10,
                entityPayload: #"{"ids":["00000000-0000-0000-0000-000000000001"]}"#,
                metadataPayload: #"{"kind":"safe"}"#
            )
        ]))
        let viewModel = SupabaseSyncEventDebugViewModel(service: service(fetcher: fetcher))

        await viewModel.loadLatestEvents()

        let rows: [SyncEventDebugDisplayRow] = viewModel.displayRows
        XCTAssertEqual(rows.first?.entities.shape, .object)
        XCTAssertEqual(rows.first?.payload.shape, .object)
        XCTAssertNil(rows.first?.sanitizedPreview)
    }

    private func service(fetcher: any SupabaseSyncEventPreviewFetching) -> SupabaseSyncEventPreviewService {
        SupabaseSyncEventPreviewService(fetcher: fetcher)
    }

    private func syncEvent(
        id: Int64,
        entityPayload: String = "null",
        metadataPayload: String = "{}"
    ) -> RemoteSyncEventRow {
        let json = """
        {
          "id": \(id),
          "owner_user_id": "00000000-0000-0000-0000-000000000001",
          "domain": "catalog",
          "event_type": "catalog_changed",
          "source": "ios",
          "changed_count": 1,
          "entity_ids": \(entityPayload),
          "created_at": "2026-05-06T12:34:56Z",
          "expires_at": null,
          "metadata": \(metadataPayload)
        }
        """

        return try! JSONDecoder().decode(RemoteSyncEventRow.self, from: Data(json.utf8))
    }

    private func waitForRequestCount(
        _ expectedCount: Int,
        fetcher: ControlledSyncEventPreviewFetching,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        for _ in 0..<100 {
            if await fetcher.requestCount() == expectedCount {
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Timed out waiting for request count \(expectedCount)", file: file, line: line)
    }
}

private enum ImmediateSyncEventOutcome: Sendable {
    case rows([RemoteSyncEventRow])
    case serviceError(SupabaseTransportClientError)
}

private actor ImmediateSyncEventPreviewFetching: SupabaseSyncEventPreviewFetching {
    private let outcome: ImmediateSyncEventOutcome
    private var limits: [Int] = []

    init(outcome: ImmediateSyncEventOutcome) {
        self.outcome = outcome
    }

    func fetchLatestSyncEvents(limit: Int) async throws -> [RemoteSyncEventRow] {
        limits.append(limit)

        switch outcome {
        case .rows(let rows):
            return Array(rows.prefix(limit))
        case .serviceError(let error):
            throw error
        }
    }

    func recordedLimits() -> [Int] {
        limits
    }
}

private actor ControlledSyncEventPreviewFetching: SupabaseSyncEventPreviewFetching {
    private var requests = 0
    private var continuations: [CheckedContinuation<[RemoteSyncEventRow], Error>] = []

    func fetchLatestSyncEvents(limit: Int) async throws -> [RemoteSyncEventRow] {
        requests += 1
        return try await withCheckedThrowingContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func requestCount() -> Int {
        requests
    }

    func succeed(rows: [RemoteSyncEventRow]) {
        guard !continuations.isEmpty else { return }
        continuations.removeFirst().resume(returning: rows)
    }
}
