import Foundation
import Supabase

nonisolated enum SupabaseTransportClientError: Error, Sendable {
    case configMissing
    case invalidConfig
    case sessionMissing
    case networkError(statusCode: Int?, message: String?)
    case permissionDeniedOrRLS(statusCode: Int?, code: String?, message: String?)
    case decodingError(message: String?)
    case schemaDrift(message: String?)
    case unknown(message: String?)

    var safeDiagnosticDetail: String? {
        switch self {
        case .configMissing, .invalidConfig, .sessionMissing:
            return nil
        case .networkError(let statusCode, let message):
            return Self.detail(statusCode: statusCode, code: nil, message: message)
        case .permissionDeniedOrRLS(let statusCode, let code, let message):
            return Self.detail(statusCode: statusCode, code: code, message: message)
        case .decodingError(let message), .schemaDrift(let message), .unknown(let message):
            return Self.sanitized(message)
        }
    }

    static func sanitizedDiagnosticDetail(_ message: String?) -> String? {
        sanitized(message)
    }

    private static func detail(statusCode: Int?, code: String?, message: String?) -> String? {
        let parts = [
            statusCode.map { "HTTP \($0)" },
            code.map { "code \($0)" },
            sanitized(message)
        ].compactMap { $0 }

        return parts.isEmpty ? nil : parts.joined(separator: " - ")
    }

    private static func sanitized(_ message: String?) -> String? {
        guard let text = message?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        let lowercased = text.lowercased()
        if lowercased.contains("authorization")
            || lowercased.contains("bearer ")
            || lowercased.contains("apikey")
            || lowercased.contains("jwt") {
            return nil
        }

        return SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage(text, maxLength: 240)
    }
}

actor SupabaseTransportClient {
    nonisolated static let stablePageOrderColumn = "id"
    nonisolated static let maximumRPCRequestBytes = 64 * 1_024

    private let clientProvider: SupabaseClientProvider
    private let rpcSessionConfiguration: URLSessionConfiguration

    init(clientProvider: SupabaseClientProvider) {
        self.clientProvider = clientProvider
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForRequest = 45
        configuration.timeoutIntervalForResource = 60
        self.rpcSessionConfiguration = configuration
    }

    func client() -> SupabaseClient {
        clientProvider.client
    }

    func boundedRPC<Parameters: Encodable & Sendable>(
        _ function: String,
        parameters: Parameters,
        maximumResponseBytes: Int
    ) async throws -> Data {
        guard !function.isEmpty,
              function.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") }),
              maximumResponseBytes > 0 else {
            throw SupabaseTransportClientError.invalidConfig
        }
        let session: Session
        do {
            session = try await clientProvider.client.auth.session
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw SupabaseTransportClientError.sessionMissing
        }
        try Task.checkCancellation()
        guard !session.accessToken.isEmpty,
              !session.accessToken.contains("\n"),
              !session.accessToken.contains("\r") else {
            throw SupabaseTransportClientError.sessionMissing
        }

        let body: Data
        do {
            body = try JSONEncoder().encode(parameters)
        } catch {
            throw SupabaseTransportClientError.unknown(message: "RPC request encoding failed.")
        }
        guard body.count <= Self.maximumRPCRequestBytes else {
            throw SupabaseTransportClientError.networkError(
                statusCode: nil,
                message: "RPC request exceeded the local byte limit."
            )
        }

        let url = clientProvider.config.projectURL
            .appendingPathComponent("rest", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("rpc", isDirectory: true)
            .appendingPathComponent(function, isDirectory: false)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(clientProvider.config.publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let bounded = try await BoundedURLSessionDataLoader.data(
                for: request,
                configuration: rpcSessionConfiguration,
                maximumBytes: maximumResponseBytes
            ) { response in
                guard (200..<300).contains(response.statusCode) else {
                    throw SupabaseTransportClientError.networkError(
                        statusCode: response.statusCode,
                        message: nil
                    )
                }
            }
            return bounded.0
        } catch is CancellationError {
            throw CancellationError()
        } catch is BoundedHTTPBodyError {
            throw SupabaseTransportClientError.networkError(
                statusCode: nil,
                message: "RPC response exceeded the local byte limit."
            )
        } catch let error as SupabaseTransportClientError {
            throw error
        } catch let error as URLError {
            throw networkError(error)
        } catch {
            throw SupabaseTransportClientError.unknown(message: String(describing: error))
        }
    }

    @discardableResult
    func authenticatedUserID() async throws -> UUID {
        do {
            let session = try await clientProvider.client.auth.session
            return session.user.id
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw SupabaseTransportClientError.sessionMissing
        }
    }

    func mapPostgrestError(_ error: PostgrestError) -> SupabaseTransportClientError {
        let code = error.code
        let message = error.message
        let normalized = [code, message, error.detail, error.hint]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        if normalized.contains("permission denied")
            || normalized.contains("row-level security")
            || normalized.contains("rls")
            || normalized.contains("unauthorized")
            || normalized.contains("authenticated")
            || code == "42501" {
            return .permissionDeniedOrRLS(statusCode: nil, code: code, message: message)
        }

        if code == "42P01" || code == "42703" || code == "PGRST204" {
            return .schemaDrift(message: message)
        }

        return .unknown(message: message)
    }

    func mapDecodingError(_ error: DecodingError) -> SupabaseTransportClientError {
        switch error {
        case .keyNotFound(let key, _):
            return .schemaDrift(message: "Missing key \(key.stringValue).")
        case .typeMismatch, .valueNotFound, .dataCorrupted:
            return .decodingError(message: String(describing: error))
        @unknown default:
            return .decodingError(message: String(describing: error))
        }
    }

    func networkError(_ error: URLError) -> SupabaseTransportClientError {
        .networkError(statusCode: nil, message: error.localizedDescription)
    }
}
