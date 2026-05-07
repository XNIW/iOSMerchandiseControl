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

        let params = try SyncEventRPCRequestMapper.parameters(from: request)

        do {
            let data = try await transport.call(
                functionName: SyncEventRPCRequestMapper.functionName,
                params: params
            )
            return try Self.decodeResult(from: data, request: request)
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
