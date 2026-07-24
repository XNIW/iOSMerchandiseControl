import Foundation

protocol SyncEventRPCTransport: Sendable {
    func call(
        functionName: String,
        params: SyncEventRPCRequestParameters
    ) async throws -> Data
}

nonisolated enum SyncEventRPCTransportError: Error, Sendable, Equatable {
    case http(statusCode: Int, code: String?, message: String)
    case postgrest(code: String?, message: String)
    case network(code: String?, message: String)
    case unknown(code: String?, message: String)
}

nonisolated struct SyncEventLiveRecorderConfiguration: Sendable, Equatable {
    let isValid: Bool
    let failureCode: String?

    static let valid = SyncEventLiveRecorderConfiguration(isValid: true, failureCode: nil)

    static func invalid(_ failureCode: String = "config_invalid") -> SyncEventLiveRecorderConfiguration {
        SyncEventLiveRecorderConfiguration(isValid: false, failureCode: failureCode)
    }
}

protocol SyncEventLiveRecorderConfigurationProviding: Sendable {
    func currentSyncEventRecorderConfiguration() async -> SyncEventLiveRecorderConfiguration
}

nonisolated struct SupabaseSyncEventLiveRecorderConfigurationProvider: SyncEventLiveRecorderConfigurationProviding {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func currentSyncEventRecorderConfiguration() async -> SyncEventLiveRecorderConfiguration {
        do {
            _ = try SupabaseConfig.load(bundle: bundle)
            return .valid
        } catch SupabaseConfigError.configMissing {
            return .invalid("config_missing")
        } catch {
            return .invalid("config_invalid")
        }
    }
}

nonisolated struct SyncEventLiveRecorderSession: Sendable, Equatable {
    let userID: UUID
    let isExpired: Bool
}

protocol SyncEventLiveRecorderSessionProviding: Sendable {
    func currentSyncEventRecorderSession() async -> SyncEventLiveRecorderSession?
}

nonisolated struct SupabaseSyncEventLiveRecorder: SyncEventRecording, Sendable {
    private let validator: SyncEventRecordValidator
    private let configProvider: any SyncEventLiveRecorderConfigurationProviding
    private let sessionProvider: any SyncEventLiveRecorderSessionProviding
    private let transport: any SyncEventRPCTransport

    init(
        validator: SyncEventRecordValidator = SyncEventRecordValidator(),
        configProvider: any SyncEventLiveRecorderConfigurationProviding,
        sessionProvider: any SyncEventLiveRecorderSessionProviding,
        transport: any SyncEventRPCTransport
    ) {
        self.validator = validator
        self.configProvider = configProvider
        self.sessionProvider = sessionProvider
        self.transport = transport
    }

    func record(_ request: SyncEventRecordRequest) async throws -> SyncEventRecordResult {
        try validator.validate(request)

        let configuration = await configProvider.currentSyncEventRecorderConfiguration()
        guard configuration.isValid else {
            throw SyncEventRecordError.auth(
                SyncEventRecordFailure(
                    code: configuration.failureCode ?? "config_invalid",
                    message: "Sync event recorder configuration is not available."
                )
            )
        }

        guard let session = await sessionProvider.currentSyncEventRecorderSession() else {
            throw SyncEventRecordError.auth(
                SyncEventRecordFailure(
                    code: "session_missing",
                    message: "Sync event recorder requires an authenticated session."
                )
            )
        }

        guard !session.isExpired else {
            throw SyncEventRecordError.auth(
                SyncEventRecordFailure(
                    code: "session_expired",
                    message: "Sync event recorder session is expired."
                )
            )
        }

        let automaticScope = try validatedAutomaticScopeIfPresent(
            session: session,
            request: request
        )

        let params = try SyncEventRPCRequestMapper.parameters(from: request)

        do {
            let data: Data
            do {
                data = try await transport.call(
                    functionName: SyncEventRPCRequestMapper.functionName,
                    params: params
                )
            } catch let error as SyncEventRPCTransportError {
                guard Self.isMissingV6Writer(error),
                      SyncEventRPCRequestMapper.legacyParametersIfCompatible(
                        params,
                        hasAutomaticShopScope: automaticScope != nil
                      ) != nil else {
                    throw error
                }
                let legacyData = try await transport.call(
                    functionName: SyncEventRPCRequestMapper.legacyFunctionName,
                    params: params
                )
                data = try Self.normalizedLegacyResponse(legacyData)
            }
            let result = try Self.decodeResult(from: data, request: request)
            if let automaticScope {
                try validateAutomaticResult(result, scope: automaticScope)
            }
            return result
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as SyncEventRecordError {
            throw error
        } catch let error as SyncEventRPCTransportError {
            throw Self.mapTransportError(error)
        } catch let error as DecodingError {
            throw SyncEventRecordError.schema(
                SyncEventRecordFailure(code: "response_decode", message: String(describing: error))
            )
        } catch let error as URLError {
            if error.code == .cancelled {
                throw CancellationError()
            }
            throw SyncEventRecordError.network(
                SyncEventRecordFailure(code: "url_error_\(error.code.rawValue)", message: error.localizedDescription)
            )
        } catch {
            throw SyncEventRecordError.unknown(
                SyncEventRecordFailure(code: "transport_unknown", message: String(describing: error))
            )
        }
    }

    private static func isMissingV6Writer(_ error: SyncEventRPCTransportError) -> Bool {
        let code: String?
        switch error {
        case .http(_, let value, _),
             .postgrest(let value, _):
            code = value
        case .network, .unknown:
            return false
        }
        let normalized = code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "pgrst202" || normalized == "42883"
    }

    /// Legacy PostgREST may serialize bigint `id` as a JSON number. Quote the
    /// exact decimal token before the V6 decoder sees it; JSONSerialization
    /// and Double are deliberately avoided so values above 2^53 stay exact.
    private static func normalizedLegacyResponse(_ data: Data) throws -> Data {
        guard var source = String(data: data, encoding: .utf8) else {
            throw SyncEventRecordError.schema(
                SyncEventRecordFailure(
                    code: "response_decode",
                    message: "Legacy sync event response was not valid UTF-8."
                )
            )
        }
        let expression = try NSRegularExpression(pattern: #""id"\s*:\s*([0-9]+)"#)
        let sourceRange = NSRange(source.startIndex..<source.endIndex, in: source)
        guard let match = expression.firstMatch(in: source, range: sourceRange),
              let tokenRange = Range(match.range(at: 1), in: source) else {
            return data
        }
        let token = String(source[tokenRange])
        guard let exact = Int64(token), exact >= 0, String(exact) == token else {
            throw SyncEventRecordError.schema(
                SyncEventRecordFailure(
                    code: "response_decode",
                    message: "Legacy sync event id was outside the exact Int64 range."
                )
            )
        }
        source.replaceSubrange(tokenRange, with: "\"\(token)\"")
        return Data(source.utf8)
    }

    private func validatedAutomaticScopeIfPresent(
        session: SyncEventLiveRecorderSession,
        request: SyncEventRecordRequest
    ) throws -> Task126VerifiedOwnerStoreScope? {
        guard let scope = Task126OwnerStoreGate.currentAutomaticScope else {
            return nil
        }
        do {
            try Task126OwnerStoreGate.revalidateCurrentAutomaticScopeLeaseIfPresent()
            guard session.userID == scope.ownerUserID,
                  request.shopID == scope.shopID else {
                throw Task126OwnerStoreGateError.scopeChanged
            }
            return scope
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw Self.automaticScopeMismatch()
        }
    }

    private func validateAutomaticResult(
        _ result: SyncEventRecordResult,
        scope: Task126VerifiedOwnerStoreScope
    ) throws {
        do {
            try Task126OwnerStoreGate.revalidateCurrentAutomaticScopeLeaseIfPresent()
            try Task126OwnerStoreGate.validateRemoteIdentity(
                ownerUserID: result.row.ownerUserID,
                shopID: result.row.shopID,
                scope: scope
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw Self.automaticScopeMismatch()
        }
    }

    private static func automaticScopeMismatch() -> SyncEventRecordError {
        .auth(
            SyncEventRecordFailure(
                code: "automatic_scope_mismatch",
                message: "Sync event recorder scope changed."
            )
        )
    }

    private static func decodeResult(
        from data: Data,
        request: SyncEventRecordRequest
    ) throws -> SyncEventRecordResult {
        let response: SyncEventRowsResponse
        do {
            response = try JSONDecoder().decode(SyncEventRowsResponse.self, from: data)
        } catch {
            throw SyncEventRecordError.schema(
                SyncEventRecordFailure(code: "response_decode", message: "Unable to decode sync event response.")
            )
        }

        guard let firstRow = response.rows.first else {
            throw SyncEventRecordError.schema(
                SyncEventRecordFailure(code: "empty_response", message: "Sync event response contained no rows.")
            )
        }

        guard response.rows.count == 1 else {
            throw SyncEventRecordError.schema(
                SyncEventRecordFailure(
                    code: "unexpected_row_count",
                    message: "Sync event response must contain exactly one row."
                )
            )
        }

        try validateClientEventIDs(in: response.rows, request: request)
        return .recorded(firstRow)
    }

    private static func validateClientEventIDs(
        in rows: [RemoteSyncEventRow],
        request: SyncEventRecordRequest
    ) throws {
        if rows.count == 1 {
            guard let clientEventID = rows[0].clientEventID else {
                return
            }
            guard clientEventID == request.clientEventID else {
                throw clientEventIDMismatch()
            }
            return
        }

        guard rows.allSatisfy({ $0.clientEventID == request.clientEventID }) else {
            throw clientEventIDMismatch()
        }
    }

    private static func clientEventIDMismatch() -> SyncEventRecordError {
        .schema(
            SyncEventRecordFailure(
                code: "client_event_id_mismatch",
                message: "Response client event id did not match the request."
            )
        )
    }

    private static func mapTransportError(_ error: SyncEventRPCTransportError) -> SyncEventRecordError {
        switch error {
        case .http(let statusCode, let code, let message):
            return mapStatus(statusCode, code: code, message: message)
        case .postgrest(let code, let message):
            return mapCodeAndMessage(code: code, message: message)
        case .network(let code, let message):
            return .network(SyncEventRecordFailure(code: code, message: message))
        case .unknown(let code, let message):
            return SyncEventRecordError.classified(code: code, message: message)
        }
    }

    private static func mapStatus(
        _ statusCode: Int,
        code: String?,
        message: String
    ) -> SyncEventRecordError {
        if statusCode == 401 || statusCode == 403 {
            return .auth(SyncEventRecordFailure(code: code ?? "\(statusCode)", message: message))
        }

        if statusCode == 404 {
            return .schema(SyncEventRecordFailure(code: code ?? "\(statusCode)", message: message))
        }

        if statusCode == 429 || (500...599).contains(statusCode) {
            return .network(SyncEventRecordFailure(code: code ?? "\(statusCode)", message: message))
        }

        let mapped = mapCodeAndMessage(code: code, message: message)
        if mapped.kind != .unknown {
            return mapped
        }

        return .unknown(SyncEventRecordFailure(code: code ?? "\(statusCode)", message: message))
    }

    private static func mapCodeAndMessage(code: String?, message: String) -> SyncEventRecordError {
        let normalizedCode = (code ?? "").lowercased()
        let normalizedMessage = message.lowercased()
        let normalized = "\(normalizedCode) \(normalizedMessage)"

        if normalizedCode == "401"
            || normalizedCode == "403"
            || normalizedCode == "42501"
            || normalizedCode == "28000"
            || normalized.contains("session")
            || normalized.contains("unauthorized")
            || normalized.contains("forbidden")
            || normalized.contains("permission denied")
            || normalized.contains("row-level security")
            || normalized.contains("rls") {
            return .auth(SyncEventRecordFailure(code: code, message: message))
        }

        if normalizedCode == "pgrst202"
            || normalizedCode == "pgrst204"
            || normalizedCode == "42883"
            || normalizedCode == "42p01"
            || normalizedCode == "42703"
            || normalized.contains("function")
            || normalized.contains("does not exist")
            || normalized.contains("schema")
            || normalized.contains("column")
            || normalized.contains("missing required")
            || normalized.contains("decode")
            || normalized.contains("drift") {
            return .schema(SyncEventRecordFailure(code: code, message: message))
        }

        if normalizedCode == "22023"
            || normalizedCode == "payloadvalidation"
            || normalized.contains("payloadvalidation")
            || normalized.contains("payload validation")
            || normalized.contains("changed_count")
            || normalized.contains("contract") {
            return .contract(SyncEventRecordFailure(code: code, message: message))
        }

        if normalizedCode == "429"
            || normalized.contains("rate limit")
            || normalized.contains("too many requests")
            || normalized.contains("timeout")
            || normalized.contains("offline")
            || normalized.contains("not connected")
            || normalized.contains("network")
            || normalizedCode.hasPrefix("5") {
            return .network(SyncEventRecordFailure(code: code, message: message))
        }

        return .unknown(SyncEventRecordFailure(code: code, message: message))
    }
}

extension SupabaseAuthService: SyncEventLiveRecorderSessionProviding {
    func currentSyncEventRecorderSession() async -> SyncEventLiveRecorderSession? {
        currentSession.map {
            SyncEventLiveRecorderSession(userID: $0.userID, isExpired: $0.isExpired)
        }
    }
}
