import XCTest
@testable import iOSMerchandiseControl

final class SyncEventRecordingTests: XCTestCase {
    private let validator = SyncEventRecordValidator()
    private let clientEventID = "client-event-056"

    func testValidRequestPassesValidator() throws {
        XCTAssertNoThrow(try validator.validate(validRequest()))
    }

    func testChangedCountThousandIsAccepted() throws {
        XCTAssertNoThrow(try validator.validate(validRequest(changedCount: 1_000)))
    }

    func testChangedCountAboveThousandIsContractError() {
        assertRecordError(
            try validator.validate(validRequest(changedCount: 1_001)),
            kind: .contract,
            code: "changed_count_limit"
        )
    }

    func testNegativeChangedCountIsContractError() {
        assertRecordError(
            try validator.validate(validRequest(changedCount: -1)),
            kind: .contract,
            code: "changed_count_limit"
        )
    }

    func testClientEventIDEmptyIsRejected() {
        assertRecordError(
            try validator.validate(validRequest(clientEventID: "   ")),
            kind: .contract,
            code: "missing_client_event_id"
        )
    }

    func testDomainAndEventTypeEmptyAreRejected() {
        assertRecordError(
            try validator.validate(validRequest(domain: "   ")),
            kind: .contract,
            code: "missing_domain"
        )
        assertRecordError(
            try validator.validate(validRequest(eventType: "\n\t")),
            kind: .contract,
            code: "missing_event_type"
        )
    }

    func testDomainAndEventTypeAreNotHardcodedToKnownDomains() throws {
        XCTAssertNoThrow(
            try validator.validate(validRequest(domain: "future-domain", eventType: "future_event"))
        )
    }

    func testMetadataWithJWTTokenOrQueryStringIsContractError() {
        let tokenPayloads: [SyncEventJSONValue] = [
            .object(["jwt": .string("abcdefghij.klmnopqrst.uvwxyzabcd")]),
            .object(["authToken": .string("secret")]),
            .object(["note": .string("GET https://example.test/rest/v1/sync_events?select=*&token=secret")])
        ]

        for metadata in tokenPayloads {
            assertRecordError(
                try validator.validate(validRequest(metadata: metadata)),
                kind: .contract
            )
        }
    }

    func testEntityIDsMassiveIdentifierListIsContractError() {
        let values = (0..<20).map { index in
            SyncEventJSONValue.string("00000000-0000-0000-0000-\(String(format: "%012d", index))")
        }
        assertRecordError(
            try validator.validate(validRequest(entityIDs: .object(["product_ids": .array(values)]))),
            kind: .contract,
            code: "entity_ids_identifier_list"
        )
    }

    func testJSONDepthAboveThreeIsContractError() {
        let tooDeep = SyncEventJSONValue.object([
            "level1": .object([
                "level2": .object([
                    "level3": .string("too-deep")
                ])
            ])
        ])

        assertRecordError(
            try validator.validate(validRequest(metadata: tooDeep)),
            kind: .contract,
            code: "metadata_depth"
        )
    }

    func testTopLevelKeysAboveTwentyIsContractError() {
        let pairs = (0..<21).map { ("key_\($0)", SyncEventJSONValue.number(Double($0))) }
        let metadata = SyncEventJSONValue.object(Dictionary(uniqueKeysWithValues: pairs))

        assertRecordError(
            try validator.validate(validRequest(metadata: metadata)),
            kind: .contract,
            code: "metadata_top_level_keys"
        )
    }

    func testArrayAboveHundredElementsIsContractError() {
        let values = (0..<101).map { SyncEventJSONValue.number(Double($0)) }

        assertRecordError(
            try validator.validate(validRequest(metadata: .object(["items": .array(values)]))),
            kind: .contract,
            code: "metadata_array_budget"
        )
    }

    func testEstimatedByteBudgetAboveEightKBIsContractError() {
        let metadata = SyncEventJSONValue.object(["note": .string(String(repeating: "a", count: 8_300))])

        assertRecordError(
            try validator.validate(validRequest(metadata: metadata)),
            kind: .contract,
            code: "metadata_byte_budget"
        )
    }

    func testEntityIDsUseSeparateByteAndTopLevelBudgets() {
        let oversizedEntityIDs = SyncEventJSONValue.object(["ids": .string(String(repeating: "b", count: 8_300))])
        assertRecordError(
            try validator.validate(validRequest(entityIDs: oversizedEntityIDs)),
            kind: .contract,
            code: "entity_ids_byte_budget"
        )

        let pairs = (0..<21).map { ("key_\($0)", SyncEventJSONValue.number(Double($0))) }
        let manyEntityIDKeys = SyncEventJSONValue.object(Dictionary(uniqueKeysWithValues: pairs))
        assertRecordError(
            try validator.validate(validRequest(entityIDs: manyEntityIDKeys)),
            kind: .contract,
            code: "entity_ids_top_level_keys"
        )
    }

    func testDryRunResponseObjectRecordsRow() async throws {
        let recorder = SyncEventRecordDryRunRecorder(responseJSON: fixtureRow(id: 1))

        let result = try await recorder.record(validRequest())

        guard case .recorded(let row) = result else {
            return XCTFail("Expected recorded result.")
        }
        XCTAssertEqual(row.id, 1)
        XCTAssertEqual(row.clientEventID, clientEventID)
    }

    func testDryRunResponseArrayRecordsFirstCoherentRow() async throws {
        let recorder = SyncEventRecordDryRunRecorder(responseJSON: """
        [
          \(fixtureRow(id: 2)),
          \(fixtureRow(id: 3))
        ]
        """)

        let result = try await recorder.record(validRequest())

        guard case .recorded(let row) = result else {
            return XCTFail("Expected recorded result.")
        }
        XCTAssertEqual(row.id, 2)
    }

    func testDryRunResponseIgnoresExtraFields() async throws {
        let recorder = SyncEventRecordDryRunRecorder(
            responseJSON: fixtureRow(id: 4, extraFields: #""ignored_field": "ignored","#)
        )

        let result = try await recorder.record(validRequest())

        XCTAssertEqual(result.row.id, 4)
    }

    func testDryRunDuplicateIdempotentResponseCanReturnNoOp() async throws {
        let recorder = SyncEventRecordDryRunRecorder(
            responseJSON: fixtureRow(id: 5),
            responsePolicy: .idempotentNoOp
        )

        let result = try await recorder.record(validRequest())

        guard case .noOp(let row) = result else {
            return XCTFail("Expected noOp result.")
        }
        XCTAssertEqual(row.clientEventID, clientEventID)
    }

    func testDryRunObjectWithoutClientEventIDIsAcceptedWhenRequiredFieldsDecode() async throws {
        let recorder = SyncEventRecordDryRunRecorder(
            responseJSON: fixtureRow(id: 6, clientEventIDShape: .omitted)
        )

        let result = try await recorder.record(validRequest())

        guard case .recorded(let row) = result else {
            return XCTFail("Expected recorded result.")
        }
        XCTAssertNil(row.clientEventID)
    }

    func testDryRunEmptyArrayIsSchemaError() async {
        let recorder = SyncEventRecordDryRunRecorder(responseJSON: "[]")

        await assertAsyncRecordError(
            try await recorder.record(validRequest()),
            kind: .schema,
            code: "empty_response"
        )
    }

    func testDryRunMultiRowSameClientEventIDIsRecorded() async throws {
        let recorder = SyncEventRecordDryRunRecorder(responseJSON: """
        [
          \(fixtureRow(id: 7)),
          \(fixtureRow(id: 8))
        ]
        """)

        let result = try await recorder.record(validRequest())

        guard case .recorded(let row) = result else {
            return XCTFail("Expected recorded result.")
        }
        XCTAssertEqual(row.id, 7)
    }

    func testDryRunMultiRowMissingNullOrDivergentClientEventIDIsSchemaError() async {
        let fixtures = [
            """
            [
              \(fixtureRow(id: 9, clientEventIDShape: .omitted)),
              \(fixtureRow(id: 10))
            ]
            """,
            """
            [
              \(fixtureRow(id: 11, clientEventIDShape: .null)),
              \(fixtureRow(id: 12))
            ]
            """,
            """
            [
              \(fixtureRow(id: 13, clientEventIDShape: .value("client-event-056"))),
              \(fixtureRow(id: 14, clientEventIDShape: .value("other-client-event")))
            ]
            """
        ]

        for json in fixtures {
            let recorder = SyncEventRecordDryRunRecorder(responseJSON: json)
            await assertAsyncRecordError(
                try await recorder.record(validRequest()),
                kind: .schema,
                code: "client_event_id_mismatch"
            )
        }
    }

    func testAuthErrorClassification() async {
        let recorder = SyncEventRecordDryRunRecorder(
            fixture: .classifiedFailure(code: "401", message: "session missing")
        )

        await assertAsyncRecordError(
            try await recorder.record(validRequest()),
            kind: .auth
        )
    }

    func testSchemaErrorClassification() async {
        let recorder = SyncEventRecordDryRunRecorder(
            fixture: .classifiedFailure(code: "PGRST202", message: "missing function")
        )

        await assertAsyncRecordError(
            try await recorder.record(validRequest()),
            kind: .schema
        )
    }

    func testContractErrorClassification() async {
        let recorder = SyncEventRecordDryRunRecorder(
            fixture: .classifiedFailure(code: "22023", message: "PayloadValidation changed_count overflow")
        )

        await assertAsyncRecordError(
            try await recorder.record(validRequest()),
            kind: .contract
        )
    }

    func testNetworkErrorClassification() async {
        let recorder = SyncEventRecordDryRunRecorder(
            fixture: .classifiedFailure(code: "timeout", message: "network timeout")
        )

        await assertAsyncRecordError(
            try await recorder.record(validRequest()),
            kind: .network
        )
    }

    func testClassifiedFailuresSanitizeSecretsBeforeExposure() async {
        let recorder = SyncEventRecordDryRunRecorder(
            fixture: .classifiedFailure(
                code: nil,
                message: "Bearer abcdefghij.klmnopqrst.uvwxyzabcd GET https://example.test/rest/v1/sync_events?select=*&token=secret product 1234567890123"
            )
        )

        do {
            _ = try await recorder.record(validRequest())
            XCTFail("Expected unknown sanitized error.")
        } catch let error as SyncEventRecordError {
            XCTAssertEqual(error.kind, .unknown)
            XCTAssertFalse(error.failure.message.contains("abcdefghij.klmnopqrst.uvwxyzabcd"))
            XCTAssertFalse(error.failure.message.contains("token=secret"))
            XCTAssertFalse(error.failure.message.contains("1234567890123"))
            XCTAssertLessThanOrEqual(error.failure.message.count, SyncEventOutboxPrivacySanitizer.defaultMessageLimit)
        } catch {
            XCTFail("Expected SyncEventRecordError, got \(error).")
        }
    }

    func testDryRunProductionSourceHasNoLiveTransportDependencies() throws {
        let source = try productionSource(named: "SyncEventRecording.swift")
        let forbiddenTokens: [String] = [
            joined("Supabase", "Client"),
            joined(".", "rpc", "("),
            joined(".", "from", "("),
            joined(".", "in", "sert", "("),
            joined(".", "up", "sert", "("),
            joined(".", "up", "date", "("),
            joined(".", "de", "lete", "("),
            joined(".", "channel", "("),
            joined(".", "subscribe", "("),
            joined("BG", "Task"),
            "Realtime",
            "service_role",
            joined("Model", "Context"),
            joined("Model", "Container"),
            ["record", "sync", "event"].joined(separator: "_")
        ]

        for token in forbiddenTokens {
            XCTAssertFalse(source.contains(token), "Unexpected live/scope token in Slice D source: \(token)")
        }
    }

    func testRecordTaxonomyMapsToTask055OutboxConceptsWithoutMutation() throws {
        XCTAssertEqual(
            SyncEventRecordError.contract(SyncEventRecordFailure(code: "22023", message: "contract")).plannedOutboxStatus,
            .blockedContract
        )
        XCTAssertEqual(
            SyncEventRecordError.auth(SyncEventRecordFailure(code: "401", message: "auth")).plannedOutboxStatus,
            .blockedAuth
        )
        XCTAssertEqual(
            SyncEventRecordError.schema(SyncEventRecordFailure(code: "PGRST202", message: "schema")).plannedOutboxStatus,
            .blockedSchema
        )
        XCTAssertEqual(
            SyncEventRecordError.network(SyncEventRecordFailure(code: "timeout", message: "network")).plannedOutboxStatus,
            .failedRetryable
        )

        let result = SyncEventRecordResult.recorded(try decodeRow(fixtureRow(id: 20)))
        XCTAssertEqual(result.plannedOutboxStatus, .sent)
    }

    private func validRequest(
        domain: String = "catalog",
        eventType: String = "catalog_changed",
        changedCount: Int = 1,
        entityIDs: SyncEventJSONValue = .object(["product_ids": .object(["count": .number(1)])]),
        metadata: SyncEventJSONValue = .object(["source": .string("manual_push")]),
        clientEventID: String? = nil
    ) -> SyncEventRecordRequest {
        SyncEventRecordRequest(
            domain: domain,
            eventType: eventType,
            changedCount: changedCount,
            entityIDs: entityIDs,
            metadata: metadata,
            source: "ios",
            sourceDeviceID: "device-hash",
            batchID: UUID(uuidString: "00000000-0000-0000-0000-000000000056"),
            clientEventID: clientEventID ?? self.clientEventID
        )
    }

    private func assertRecordError(
        _ expression: @autoclosure () throws -> Void,
        kind: SyncEventRecordError.Kind,
        code: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            guard let recordError = error as? SyncEventRecordError else {
                return XCTFail("Expected SyncEventRecordError, got \(error).", file: file, line: line)
            }
            XCTAssertEqual(recordError.kind, kind, file: file, line: line)
            if let code {
                XCTAssertEqual(recordError.failure.code, code, file: file, line: line)
            }
        }
    }

    private func assertAsyncRecordError<T>(
        _ expression: @autoclosure () async throws -> T,
        kind: SyncEventRecordError.Kind,
        code: String? = nil,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected SyncEventRecordError.", file: file, line: line)
        } catch let error as SyncEventRecordError {
            XCTAssertEqual(error.kind, kind, file: file, line: line)
            if let code {
                XCTAssertEqual(error.failure.code, code, file: file, line: line)
            }
        } catch {
            XCTFail("Expected SyncEventRecordError, got \(error).", file: file, line: line)
        }
    }

    private enum ClientEventIDShape {
        case value(String)
        case omitted
        case null
    }

    private func fixtureRow(
        id: Int,
        clientEventIDShape: ClientEventIDShape? = nil,
        extraFields: String = ""
    ) -> String {
        let shape = clientEventIDShape ?? .value(clientEventID)
        let clientEventField: String
        switch shape {
        case .value(let value):
            clientEventField = #""client_event_id": "\#(value)","#
        case .omitted:
            clientEventField = ""
        case .null:
            clientEventField = #""client_event_id": null,"#
        }

        return """
        {
          "id": \(id),
          "owner_user_id": "00000000-0000-0000-0000-000000000001",
          "domain": "catalog",
          "event_type": "catalog_changed",
          "source": "ios",
          "source_device_id": "device-hash",
          "batch_id": "00000000-0000-0000-0000-000000000056",
          \(clientEventField)
          "changed_count": 1,
          "entity_ids": {
            "product_ids": {
              "count": 1
            }
          },
          "created_at": "2026-05-07T12:34:56Z",
          "expires_at": null,
          \(extraFields)
          "metadata": {
            "source": "fixture"
          }
        }
        """
    }

    private func decodeRow(_ json: String) throws -> RemoteSyncEventRow {
        try JSONDecoder().decode(RemoteSyncEventRow.self, from: Data(json.utf8))
    }

    private func productionSource(named fileName: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = testsDirectory
            .appendingPathComponent("iOSMerchandiseControl")
            .appendingPathComponent(fileName)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func joined(_ parts: String...) -> String {
        parts.joined()
    }
}
