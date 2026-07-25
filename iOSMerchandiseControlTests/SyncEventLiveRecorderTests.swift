import XCTest
@testable import iOSMerchandiseControl

final class SyncEventLiveRecorderTests: XCTestCase {
    private let clientEventID = "client-event-058"
    private let ownerID = UUID(uuidString: "00000000-0000-0000-0000-000000000058")!
    private let shopID = UUID(uuidString: "00000000-0000-4000-8000-000000000159")!

    func testValidatorPassCallsTransportOnceWithMappedRPCParams() async throws {
        let transport = FakeRPCTransport(.json(fixtureRow(id: 1)))
        let recorder = makeRecorder(transport: transport)

        let result = try await recorder.record(validRequest())

        guard case .recorded(let row) = result else {
            return XCTFail("Expected recorded result.")
        }
        XCTAssertEqual(row.id, 1)
        let callCount = await transport.callCount()
        let lastCall = await transport.lastCall()
        XCTAssertEqual(callCount, 1)
        let call = try XCTUnwrap(lastCall)
        XCTAssertEqual(call.functionName, "record_sync_event_v6")
        XCTAssertEqual(call.params.pDomain, "catalog")
        XCTAssertEqual(call.params.pEventType, "catalog_changed")
        XCTAssertEqual(call.params.pChangedCount, 1)
        XCTAssertEqual(call.params.pClientEventID, clientEventID)
        XCTAssertEqual(call.params.pSource, "ios")
        XCTAssertEqual(call.params.pSourceDeviceID, "device-hash")
        XCTAssertEqual(call.params.pBatchID, UUID(uuidString: "00000000-0000-4000-8000-000000000058"))
        XCTAssertNil(call.params.pStoreID)
        XCTAssertNil(call.params.pShopID)
        XCTAssertEqual(
            call.params.pEntityIDs,
            .object([
                "product_ids": .array([
                    .string("00000000-0000-4000-8000-000000000058")
                ])
            ])
        )
        XCTAssertEqual(call.params.pMetadata, .object(["source": .string("ios")]))
    }

    func testMixedVersionFallsBackOnceForLegacyCompatiblePersonalRequest() async throws {
        let exactID = 9_007_199_254_740_993
        let numericLegacyRow = fixtureRow(id: exactID).replacingOccurrences(
            of: #""id": "\#(exactID)""#,
            with: #""id": \#(exactID)"#
        )
        let transport = FakeRPCTransport([
            .transportError(.postgrest(
                code: "PGRST202",
                message: "record_sync_event_v6 is unavailable"
            )),
            .json(numericLegacyRow)
        ])
        let recorder = makeRecorder(transport: transport)

        let result = try await recorder.record(validRequest())

        XCTAssertEqual(result.row.id, Int64(exactID))
        let calls = await transport.allCalls()
        XCTAssertEqual(
            calls.map(\.functionName),
            ["record_sync_event_v6", "record_sync_event"]
        )
        let legacy = try XCTUnwrap(
            SyncEventRPCRequestMapper.legacyParametersIfCompatible(
                calls[0].params,
                hasAutomaticShopScope: false
            )
        )
        let legacyObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any]
        )
        XCTAssertNil(legacyObject["p_shop_id"])
        XCTAssertEqual(legacyObject["p_domain"] as? String, "catalog")
    }

    func testMixedVersionShopScopedRequestFailsClosedWithoutLegacyRetry() async {
        let transport = FakeRPCTransport([
            .transportError(.postgrest(
                code: "PGRST202",
                message: "record_sync_event_v6 is unavailable"
            )),
            .json(fixtureRow(id: 2, shopID: shopID))
        ])
        let recorder = makeRecorder(transport: transport)

        await assertRecordError(
            try await recorder.record(validRequest(shopID: shopID)),
            kind: .schema,
            code: "PGRST202"
        )

        let calls = await transport.allCalls()
        XCTAssertEqual(calls.map(\.functionName), ["record_sync_event_v6"])
    }

    func testInvalidEntityNilOrV7UUIDFailsLocalValidationBeforeV6Call() async {
        let incompatibleEntityIDs: [SyncEventJSONValue] = [
            .object(["product_ids": .array([
                .string("00000000-0000-0000-0000-000000000000")
            ])]),
            .object(["product_ids": .array([
                .string("01910f3c-7b2a-7e36-8d4a-67a1f9b04c20")
            ])])
        ]
        for entityIDs in incompatibleEntityIDs {
            let transport = FakeRPCTransport(.transportError(.postgrest(
                code: "42883",
                message: "record_sync_event_v6 is unavailable"
            )))
            let recorder = makeRecorder(transport: transport)

            await assertRecordError(
                try await recorder.record(validRequest(entityIDs: entityIDs)),
                kind: .contract,
                code: "entity_ids_uuid"
            )
            let callCount = await transport.callCount()
            XCTAssertEqual(callCount, 0)
        }
    }

    func testMixedVersionNilOrV7BatchUUIDCallsV6ButNeverLegacyWriter() async {
        let incompatibleBatchIDs = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            UUID(uuidString: "01910f3c-7b2a-7e36-8d4a-67a1f9b04c20")!
        ]
        for batchID in incompatibleBatchIDs {
            let transport = FakeRPCTransport([
                .transportError(.postgrest(
                    code: "42883",
                    message: "record_sync_event_v6 is unavailable"
                )),
                .json(fixtureRow(id: 2))
            ])
            let recorder = makeRecorder(transport: transport)

            await assertRecordError(
                try await recorder.record(validRequest(batchID: batchID)),
                kind: .schema,
                code: "42883"
            )
            let calls = await transport.allCalls()
            XCTAssertEqual(calls.map(\.functionName), ["record_sync_event_v6"])
        }
    }

    func testShopScopedRequestMapsShopIDToRPCParamsAndResponse() async throws {
        let transport = FakeRPCTransport(
            .json(fixtureRow(id: 159, extraFields: #""shop_id": "00000000-0000-4000-8000-000000000159","#))
        )
        let recorder = makeRecorder(transport: transport)

        let result = try await recorder.record(validRequest(shopID: shopID))

        guard case .recorded(let row) = result else {
            return XCTFail("Expected recorded result.")
        }
        XCTAssertEqual(row.shopID, shopID)
        let lastCall = await transport.lastCall()
        let call = try XCTUnwrap(lastCall)
        XCTAssertEqual(call.params.pShopID, shopID)
    }

    func testCatalogTombstoneEventMapsToRPCParams() async throws {
        let productID = UUID(uuidString: "00000000-0000-4000-8000-000000001350")!
        let transport = FakeRPCTransport(.json(fixtureRow(id: 58)))
        let recorder = makeRecorder(transport: transport)

        let result = try await recorder.record(
            validRequest(
                eventType: "catalog_tombstone",
                entityIDs: .object(["product_ids": .array([.string(productID.uuidString)])]),
                metadata: .object(["source": .string("ios")])
            )
        )

        guard case .recorded(let row) = result else {
            return XCTFail("Expected recorded result.")
        }
        XCTAssertEqual(row.id, 58)
        let lastCall = await transport.lastCall()
        let call = try XCTUnwrap(lastCall)
        XCTAssertEqual(call.params.pDomain, "catalog")
        XCTAssertEqual(call.params.pEventType, "catalog_tombstone")
        XCTAssertEqual(call.params.pChangedCount, 1)
        XCTAssertEqual(call.params.pEntityIDs, .object(["product_ids": .array([.string(productID.uuidString)])]))
        XCTAssertEqual(call.params.pMetadata, .object(["source": .string("ios")]))
    }

    func testChangedCountAboveContractLimitReturnsContractWithoutTransportCall() async {
        let transport = FakeRPCTransport(.json(fixtureRow(id: 2)))
        let recorder = makeRecorder(transport: transport)

        await assertRecordError(
            try await recorder.record(validRequest(changedCount: 251)),
            kind: .contract,
            code: "changed_count_limit"
        )
        let callCount = await transport.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testConfirmedRPCContractFailuresReturnContractWithoutTransportCall() async {
        let cases: [(request: SyncEventRecordRequest, code: String)] = [
            (validRequest(domain: "inventory"), "unsupported_domain"),
            (validRequest(eventType: "future_event"), "unsupported_event_type"),
            (validRequest(eventType: "prices_changed"), "event_type_domain_mismatch"),
            (validRequest(clientEventID: String(repeating: "c", count: 161)), "client_event_id_length"),
            (validRequest(sourceDeviceID: String(repeating: "d", count: 161)), "source_device_id_length")
        ]

        for testCase in cases {
            let transport = FakeRPCTransport(.json(fixtureRow(id: 3)))
            let recorder = makeRecorder(transport: transport)

            await assertRecordError(
                try await recorder.record(testCase.request),
                kind: .contract,
                code: testCase.code
            )
            let callCount = await transport.callCount()
            XCTAssertEqual(callCount, 0)
        }
    }

    func testConfigMissingOrInvalidReturnsAuthWithoutTransportCall() async {
        for configuration in [
            SyncEventLiveRecorderConfiguration.invalid("config_missing"),
            SyncEventLiveRecorderConfiguration.invalid("config_invalid")
        ] {
            let transport = FakeRPCTransport(.json(fixtureRow(id: 3)))
            let recorder = makeRecorder(configuration: configuration, transport: transport)

            await assertRecordError(
                try await recorder.record(validRequest()),
                kind: .auth,
                code: configuration.failureCode
            )
            let callCount = await transport.callCount()
            XCTAssertEqual(callCount, 0)
        }
    }

    func testSessionMissingReturnsAuthWithoutTransportCall() async {
        let transport = FakeRPCTransport(.json(fixtureRow(id: 4)))
        let recorder = makeRecorder(session: nil, useDefaultSession: false, transport: transport)

        await assertRecordError(
            try await recorder.record(validRequest()),
            kind: .auth,
            code: "session_missing"
        )
        let callCount = await transport.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testSessionExpiredReturnsAuthWithoutTransportCall() async {
        let transport = FakeRPCTransport(.json(fixtureRow(id: 5)))
        let recorder = makeRecorder(
            session: SyncEventLiveRecorderSession(userID: ownerID, isExpired: true),
            transport: transport
        )

        await assertRecordError(
            try await recorder.record(validRequest()),
            kind: .auth,
            code: "session_expired"
        )
        let callCount = await transport.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testAutomaticScopeRejectsDifferentSessionOwnerBeforeTransport() async throws {
        let fixture = try makeAutomaticScopeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let transport = FakeRPCTransport(
            .json(fixtureRow(id: 158, shopID: fixture.scope.shopID))
        )
        let recorder = makeRecorder(
            session: SyncEventLiveRecorderSession(userID: UUID(), isExpired: false),
            transport: transport
        )

        await assertRecordError(
            try await Task126OwnerStoreGate.withAutomaticScope(fixture.scope) {
                try await recorder.record(validRequest(shopID: fixture.scope.shopID))
            },
            kind: .auth,
            code: "automatic_scope_mismatch"
        )
        let callCount = await transport.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testAutomaticScopeRejectsDifferentResponseOwner() async throws {
        let fixture = try makeAutomaticScopeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let transport = FakeRPCTransport(
            .json(fixtureRow(id: 160, ownerID: UUID(), shopID: fixture.scope.shopID))
        )
        let recorder = makeRecorder(transport: transport)

        await assertRecordError(
            try await Task126OwnerStoreGate.withAutomaticScope(fixture.scope) {
                try await recorder.record(validRequest(shopID: fixture.scope.shopID))
            },
            kind: .auth,
            code: "automatic_scope_mismatch"
        )
        let callCount = await transport.callCount()
        XCTAssertEqual(callCount, 1)
    }

    func testAutomaticScopeRejectsArrayWithForeignSecondRow() async throws {
        let fixture = try makeAutomaticScopeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let transport = FakeRPCTransport(.json("""
        [
          \(fixtureRow(id: 161, shopID: fixture.scope.shopID)),
          \(fixtureRow(id: 162, ownerID: UUID(), shopID: fixture.scope.shopID))
        ]
        """))
        let recorder = makeRecorder(transport: transport)

        await assertRecordError(
            try await Task126OwnerStoreGate.withAutomaticScope(fixture.scope) {
                try await recorder.record(validRequest(shopID: fixture.scope.shopID))
            },
            kind: .schema,
            code: "unexpected_row_count"
        )
        let callCount = await transport.callCount()
        XCTAssertEqual(callCount, 1)
    }

    func testObjectResponseRecordsRow() async throws {
        let recorder = makeRecorder(transport: FakeRPCTransport(.json(fixtureRow(id: 6))))

        let result = try await recorder.record(validRequest())

        guard case .recorded(let row) = result else {
            return XCTFail("Expected recorded result.")
        }
        XCTAssertEqual(row.id, 6)
        XCTAssertEqual(row.clientEventID, clientEventID)
    }

    func testSingleElementArrayResponseRecordsRow() async throws {
        let recorder = makeRecorder(transport: FakeRPCTransport(.json("""
        [
          \(fixtureRow(id: 7))
        ]
        """)))

        let result = try await recorder.record(validRequest())

        XCTAssertEqual(result.row.id, 7)
    }

    func testMultiRowResponseReturnsSchemaInsteadOfConsumingFirstRow() async {
        let recorder = makeRecorder(transport: FakeRPCTransport(.json("""
        [
          \(fixtureRow(id: 8)),
          \(fixtureRow(id: 9))
        ]
        """)))

        await assertRecordError(
            try await recorder.record(validRequest()),
            kind: .schema,
            code: "unexpected_row_count"
        )
    }

    func testResponseExtraFieldsAreIgnored() async throws {
        let recorder = makeRecorder(
            transport: FakeRPCTransport(.json(fixtureRow(id: 9, extraFields: #""ignored": "value","#)))
        )

        let result = try await recorder.record(validRequest())

        XCTAssertEqual(result.row.id, 9)
    }

    func testEmptyArrayReturnsSchemaError() async {
        let recorder = makeRecorder(transport: FakeRPCTransport(.json("[]")))

        await assertRecordError(
            try await recorder.record(validRequest()),
            kind: .schema,
            code: "empty_response"
        )
    }

    func testMultiRowMismatchMissingOrNullClientEventIDReturnsUnexpectedRowCount() async {
        let payloads = [
            """
            [
              \(fixtureRow(id: 10, clientEventIDShape: .omitted)),
              \(fixtureRow(id: 11))
            ]
            """,
            """
            [
              \(fixtureRow(id: 12, clientEventIDShape: .null)),
              \(fixtureRow(id: 13))
            ]
            """,
            """
            [
              \(fixtureRow(id: 14)),
              \(fixtureRow(id: 15, clientEventIDShape: .value("other-client-event")))
            ]
            """
        ]

        for payload in payloads {
            let recorder = makeRecorder(transport: FakeRPCTransport(.json(payload)))
            await assertRecordError(
                try await recorder.record(validRequest()),
                kind: .schema,
                code: "unexpected_row_count"
            )
        }
    }

    func testHTTP401And403MapToAuth() async {
        for statusCode in [401, 403] {
            let recorder = makeRecorder(
                transport: FakeRPCTransport(
                    .transportError(.http(statusCode: statusCode, code: "\(statusCode)", message: "auth denied"))
                )
            )

            await assertRecordError(
                try await recorder.record(validRequest()),
                kind: .auth
            )
        }
    }

    func testFunctionMissingAndSchemaDriftMapToSchema() async {
        let failures: [SyncEventRPCTransportError] = [
            .postgrest(code: "PGRST202", message: "function public.record_sync_event does not exist"),
            .postgrest(code: "PGRST204", message: "column missing"),
            .http(statusCode: 404, code: "404", message: "schema drift")
        ]

        for failure in failures {
            let recorder = makeRecorder(transport: FakeRPCTransport(.transportError(failure)))
            await assertRecordError(
                try await recorder.record(validRequest()),
                kind: .schema
            )
        }
    }

    func testPayloadValidationAnd22023MapToContract() async {
        let failures: [SyncEventRPCTransportError] = [
            .postgrest(code: "PayloadValidation", message: "payload validation failed"),
            .postgrest(code: "22023", message: "changed_count out of allowed range"),
            .http(statusCode: 400, code: "22023", message: "changed_count overflow")
        ]

        for failure in failures {
            let recorder = makeRecorder(transport: FakeRPCTransport(.transportError(failure)))
            await assertRecordError(
                try await recorder.record(validRequest()),
                kind: .contract
            )
        }
    }

    func test429And5xxMapToNetwork() async {
        for statusCode in [429, 500, 503] {
            let recorder = makeRecorder(
                transport: FakeRPCTransport(
                    .transportError(.http(statusCode: statusCode, code: "\(statusCode)", message: "transient"))
                )
            )

            await assertRecordError(
                try await recorder.record(validRequest()),
                kind: .network
            )
        }
    }

    func testOfflineAndTimeoutMapToNetwork() async {
        let failures: [SyncEventRPCTransportError] = [
            .network(code: "offline", message: "offline"),
            .network(code: "timeout", message: "request timeout")
        ]

        for failure in failures {
            let recorder = makeRecorder(transport: FakeRPCTransport(.transportError(failure)))
            await assertRecordError(
                try await recorder.record(validRequest()),
                kind: .network
            )
        }
    }

    func testCancellationPropagatesWithoutRetryableNetworkMapping() async {
        let transport = FakeRPCTransport(.cancel)
        let recorder = makeRecorder(transport: transport)

        do {
            _ = try await recorder.record(validRequest())
            XCTFail("Expected CancellationError.")
        } catch is CancellationError {
            let callCount = await transport.callCount()
            XCTAssertEqual(callCount, 1)
        } catch let error as SyncEventRecordError {
            XCTFail("Cancellation should not become recorder error \(error.kind).")
        } catch {
            XCTFail("Expected CancellationError, got \(error).")
        }
    }

    func testURLErrorCancelledPropagatesWithoutRetryableNetworkMapping() async {
        let transport = FakeRPCTransport(.urlError(URLError(.cancelled)))
        let recorder = makeRecorder(transport: transport)

        do {
            _ = try await recorder.record(validRequest())
            XCTFail("Expected CancellationError.")
        } catch is CancellationError {
            let callCount = await transport.callCount()
            XCTAssertEqual(callCount, 1)
        } catch let error as SyncEventRecordError {
            XCTFail("Cancelled URL error should not become recorder error \(error.kind).")
        } catch {
            XCTFail("Expected CancellationError, got \(error).")
        }
    }

    func testDuplicateIdempotentSameClientEventIDIsLogicalSuccess() async throws {
        let recorder = makeRecorder(transport: FakeRPCTransport(.json(fixtureRow(id: 16))))

        let result = try await recorder.record(validRequest())

        switch result {
        case .recorded(let row), .noOp(let row):
            XCTAssertEqual(row.clientEventID, clientEventID)
        }
    }

    func testSuccessDoesNotMutateOutboxEntry() async throws {
        let entry = try SyncEventOutboxFactory.makeEntry(
            ownerUserID: ownerID.uuidString.lowercased(),
            domain: "catalog",
            eventType: "catalog_changed",
            changedCount: 1,
            entityIDsShape: "product_ids:count=0",
            metadataShape: "source=ios",
            now: Date(timeIntervalSince1970: 1_778_500_000),
            id: "entry-058",
            clientEventID: clientEventID
        )
        let snapshot = (
            status: entry.status,
            attemptCount: entry.attemptCount,
            sentAt: entry.sentAt,
            updatedAt: entry.updatedAt
        )
        let recorder = makeRecorder(transport: FakeRPCTransport(.json(fixtureRow(id: 17))))

        _ = try await recorder.record(validRequest())

        XCTAssertEqual(entry.status, snapshot.status)
        XCTAssertEqual(entry.attemptCount, snapshot.attemptCount)
        XCTAssertEqual(entry.sentAt, snapshot.sentAt)
        XCTAssertEqual(entry.updatedAt, snapshot.updatedAt)
    }

    func testMapperRejectsNonObjectRPCJSONShapesBeforeTransport() async {
        let transport = FakeRPCTransport(.json(fixtureRow(id: 18)))
        let recorder = makeRecorder(transport: transport)

        await assertRecordError(
            try await recorder.record(validRequest(entityIDs: .array([]))),
            kind: .contract,
            code: "entity_ids_shape"
        )
        await assertRecordError(
            try await recorder.record(validRequest(metadata: .array([]))),
            kind: .contract,
            code: "metadata_shape"
        )
        let callCount = await transport.callCount()
        XCTAssertEqual(callCount, 0)
    }

    func testUnknownTransportErrorsAreSanitized() async {
        let recorder = makeRecorder(
            transport: FakeRPCTransport(
                .transportError(
                    .unknown(
                        code: nil,
                        message: "Bearer abcdefghij.klmnopqrst.uvwxyzabcd GET https://example.test/rest/v1/sync_events?select=*&token=secret product 1234567890123"
                    )
                )
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

    func testProductionFilesKeepSwiftDataAndTransportBoundaries() throws {
        let mapper = try productionSource(relativePath: "Sync/Remote/SyncEventRPCRequestMapper.swift")
        let recorder = try productionSource(relativePath: "Sync/Remote/SupabaseSyncEventLiveRecorder.swift")
        let transport = try productionSource(relativePath: "Sync/Remote/SupabaseSyncEventRPCTransport.swift")
        let validator = try productionSource(relativePath: "Sync/Remote/SyncEventRecording.swift")
        let outbox = try productionSource(relativePath: "Sync/Outbox/SyncEventOutboxEntry.swift")
        let enqueue = try productionSource(relativePath: "Sync/Outbox/SyncEventOutboxEnqueueService.swift")
        let testSource = try testSource(named: "SyncEventLiveRecorderTests.swift")

        XCTAssertFalse(containsSupabaseImport(mapper))
        XCTAssertFalse(containsSupabaseImport(validator))
        XCTAssertFalse(containsSupabaseImport(outbox))
        XCTAssertFalse(containsSupabaseImport(enqueue))
        XCTAssertFalse(containsSupabaseImport(testSource))

        for source in [mapper, recorder, transport] {
            XCTAssertFalse(source.contains(joined("Model", "Context")))
            XCTAssertFalse(source.contains(joined("context", ".", "insert")))
            XCTAssertFalse(source.contains(joined("context", ".", "save")))
        }

        XCTAssertFalse(mapper.contains(joined("Supabase", "Client")))
        XCTAssertFalse(recorder.contains(joined("Supabase", "Client")))
        XCTAssertTrue(transport.contains(joined("Supabase", "Client")))
        XCTAssertTrue(transport.contains(joined(".", "rpc", "(")))
        XCTAssertFalse(mapper.contains(joined(".", "rpc", "(")))
        XCTAssertFalse(recorder.contains(joined(".", "rpc", "(")))
        XCTAssertFalse(testSource.contains(joined("Supabase", "Client")))
        XCTAssertFalse(testSource.contains(joined(".", "rpc", "(")))
    }

    private func makeRecorder(
        configuration: SyncEventLiveRecorderConfiguration = .valid,
        session: SyncEventLiveRecorderSession? = nil,
        useDefaultSession: Bool = true,
        transport: FakeRPCTransport
    ) -> SupabaseSyncEventLiveRecorder {
        let resolvedSession = session ?? (
            useDefaultSession
                ? SyncEventLiveRecorderSession(userID: ownerID, isExpired: false)
                : nil
        )
        return SupabaseSyncEventLiveRecorder(
            configProvider: FakeConfigProvider(configuration: configuration),
            sessionProvider: FakeSessionProvider(session: resolvedSession),
            transport: transport
        )
    }

    private func validRequest(
        domain: String = "catalog",
        eventType: String = "catalog_changed",
        changedCount: Int = 1,
        entityIDs: SyncEventJSONValue = .object([
            "product_ids": .array([
                .string("00000000-0000-4000-8000-000000000058")
            ])
        ]),
        metadata: SyncEventJSONValue = .object(["source": .string("ios")]),
        shopID: UUID? = nil,
        sourceDeviceID: String? = "device-hash",
        batchID: UUID? = UUID(uuidString: "00000000-0000-4000-8000-000000000058"),
        clientEventID: String? = nil
    ) -> SyncEventRecordRequest {
        SyncEventRecordRequest(
            domain: domain,
            eventType: eventType,
            changedCount: changedCount,
            entityIDs: entityIDs,
            metadata: metadata,
            shopID: shopID,
            source: "ios",
            sourceDeviceID: sourceDeviceID,
            batchID: batchID,
            clientEventID: clientEventID ?? self.clientEventID
        )
    }

    private func assertRecordError<T>(
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
        ownerID: UUID? = nil,
        shopID: UUID? = nil,
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

        let resolvedOwnerID = ownerID ?? self.ownerID
        let shopField = shopID.map { #""shop_id": "\#($0.uuidString.lowercased())","# } ?? ""
        return """
        {
          "id": "\(id)",
          "owner_user_id": "\(resolvedOwnerID.uuidString.lowercased())",
          \(shopField)
          "domain": "catalog",
          "event_type": "catalog_changed",
          "source": "ios",
          "source_device_id": "device-hash",
          "batch_id": "00000000-0000-4000-8000-000000000058",
          \(clientEventField)
          "changed_count": 1,
          "entity_ids": {
            "product_ids": []
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

    private func makeAutomaticScopeFixture() throws -> (
        suiteName: String,
        defaults: UserDefaults,
        scope: Task126VerifiedOwnerStoreScope
    ) {
        let suiteName = "SyncEventLiveRecorderTests.automaticScope.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let accountHash = AccountBindingStore.accountHash(for: ownerID)
        let shop = SelectedShop(
            shopID: shopID,
            code: "TASK139",
            name: "TASK-139 recorder fixture",
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true
        )
        let selectedStore = SelectedShopStore(defaults: defaults)
        selectedStore.noteActiveAccount(accountHash)
        XCTAssertTrue(selectedStore.save(shop, accountHash: accountHash))
        XCTAssertTrue(AccountBindingStore(defaults: defaults).saveBinding(
            accountHash: accountHash,
            storeIdentity: shop.localStoreIdentity
        ))
        let scope = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: ownerID,
            defaults: defaults
        )
        return (suiteName, defaults, scope)
    }

    private func productionSource(relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = testsDirectory
            .appendingPathComponent("iOSMerchandiseControl")
            .appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func productionSource(named fileName: String) throws -> String {
        try productionSource(relativePath: fileName)
    }

    private func testSource(named fileName: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let url = testsDirectory.appendingPathComponent(fileName)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func joined(_ parts: String...) -> String {
        parts.joined()
    }

    private func containsSupabaseImport(_ source: String) -> Bool {
        source.range(
            of: #"(?m)^import\s+Supabase\b"#,
            options: .regularExpression
        ) != nil
    }
}

private struct FakeConfigProvider: SyncEventLiveRecorderConfigurationProviding {
    let configuration: SyncEventLiveRecorderConfiguration

    func currentSyncEventRecorderConfiguration() async -> SyncEventLiveRecorderConfiguration {
        configuration
    }
}

private struct FakeSessionProvider: SyncEventLiveRecorderSessionProviding {
    let session: SyncEventLiveRecorderSession?

    func currentSyncEventRecorderSession() async -> SyncEventLiveRecorderSession? {
        session
    }
}

private actor FakeRPCTransport: SyncEventRPCTransport {
    nonisolated enum Response: Sendable {
        case json(String)
        case transportError(SyncEventRPCTransportError)
        case urlError(URLError)
        case cancel
    }

    nonisolated struct Call: Sendable, Equatable {
        let functionName: String
        let params: SyncEventRPCRequestParameters
    }

    private let responses: [Response]
    private var responseIndex = 0
    private var calls: [Call] = []

    init(_ response: Response) {
        self.responses = [response]
    }

    init(_ responses: [Response]) {
        self.responses = responses
    }

    func call(
        functionName: String,
        params: SyncEventRPCRequestParameters
    ) async throws -> Data {
        calls.append(Call(functionName: functionName, params: params))
        guard !responses.isEmpty else {
            throw SyncEventRPCTransportError.unknown(
                code: "fixture_empty",
                message: "No fake RPC response configured."
            )
        }
        let response = responses[min(responseIndex, responses.count - 1)]
        responseIndex += 1
        switch response {
        case .json(let json):
            return Data(json.utf8)
        case .transportError(let error):
            throw error
        case .urlError(let error):
            throw error
        case .cancel:
            throw CancellationError()
        }
    }

    func callCount() -> Int {
        calls.count
    }

    func lastCall() -> Call? {
        calls.last
    }

    func allCalls() -> [Call] {
        calls
    }
}
