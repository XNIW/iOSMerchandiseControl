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

    /// Retry-After is a remote minimum, not a delay capped by local backoff.
    nonisolated static func retryAfterUntil(_ raw: String?, now: Date) -> Date? {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        if value.utf8.allSatisfy({ (48...57).contains($0) }) {
            guard let seconds = TimeInterval(value), seconds.isFinite else { return nil }
            let deadline = now.addingTimeInterval(seconds)
            return deadline.timeIntervalSinceReferenceDate.isFinite ? deadline : nil
        }

        // Accept the three HTTP-date forms; strict shapes reject trailing
        // text and non-HTTP dates before DateFormatter sees the value.
        let formats = [
            (#"^[A-Za-z]{3}, [0-9]{2} [A-Za-z]{3} [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2} GMT$"#,
             "EEE, dd MMM yyyy HH:mm:ss 'GMT'"),
            (#"^[A-Za-z]+, [0-9]{2}-[A-Za-z]{3}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} GMT$"#,
             "EEEE, dd-MMM-yy HH:mm:ss 'GMT'"),
            (#"^[A-Za-z]{3} [A-Za-z]{3} [ 0-9][0-9] [0-9]{2}:[0-9]{2}:[0-9]{2} [0-9]{4}$"#,
             "EEE MMM d HH:mm:ss yyyy")
        ]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.isLenient = false
        formatter.twoDigitStartDate = formatter.calendar.date(byAdding: .year, value: -50, to: now)
        for (shape, format) in formats where value.range(of: shape, options: .regularExpression) != nil {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return max(now, date) }
        }
        return nil
    }

    nonisolated static func validateRPCResponse(_ response: HTTPURLResponse, now: Date = Date()) throws {
        guard (200..<300).contains(response.statusCode) else {
            throw AutomaticSyncFailure.http(
                status: response.statusCode,
                retryAfterUntil: retryAfterUntil(response.value(forHTTPHeaderField: "Retry-After"), now: now)
            )
        }
    }

    nonisolated static func recoveryFailure(for error: PostgrestError) -> AutomaticSyncFailure {
        let disposition: AutomaticSyncFailure.Disposition
        let category: AutomaticSyncFailure.Category
        switch error.code {
        case "42501": disposition = .stable; category = .authorization
        case "42P01", "42703", "PGRST204": disposition = .stable; category = .schema
        default: disposition = .unknown; category = .unknown
        }
        // In particular, 57014 by itself does not prove statement timeout.
        return AutomaticSyncFailure(disposition: disposition, category: category, sqlState: error.code)
    }

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

    // Internal access for the guarded manual exact-body boundary only.
    func manualRequestProvider() -> SupabaseClientProvider { clientProvider }

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
            throw AutomaticSyncFailure(disposition: .stable, category: .payload)
        }
        let session = try await authenticatedSession()
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
            throw AutomaticSyncFailure(disposition: .stable, category: .payload)
        }
        guard body.count <= Self.maximumRPCRequestBytes else {
            throw AutomaticSyncFailure(disposition: .stable, category: .payload)
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
                try Self.validateRPCResponse(response)
            }
            return bounded.0
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AutomaticSyncFailure {
            throw error
        } catch is BoundedHTTPBodyError {
            throw AutomaticSyncFailure(disposition: .stable, category: .integrity)
        } catch let error as SupabaseTransportClientError {
            throw error
        } catch let error as URLError {
            throw AutomaticSyncFailure.classify(error)
        } catch {
            throw SupabaseTransportClientError.unknown(message: String(describing: error))
        }
    }

    @discardableResult
    func authenticatedUserID() async throws -> UUID {
        try await authenticatedSession().user.id
    }

    private func authenticatedSession() async throws -> Session {
        let snapshot = await clientProvider.authSnapshot
        do {
            let session = try await snapshot.client.auth.session
            guard await clientProvider.acceptsAuthGeneration(snapshot.generation) else {
                throw CancellationError()
            }
            return session
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard await clientProvider.acceptsAuthGeneration(snapshot.generation) else {
                throw CancellationError()
            }
            await clientProvider.recordSessionReadFailure(error, generation: snapshot.generation)
            if let authError = error as? AuthError {
                switch authError {
                case .sessionMissing:
                    throw SupabaseTransportClientError.sessionMissing
                case .api(_, _, _, let response):
                    throw AutomaticSyncFailure.http(status: response.statusCode,
                        retryAfterUntil: Self.retryAfterUntil(response.value(forHTTPHeaderField: "Retry-After"), now: Date()))
                default:
                    break
                }
            }
            throw AutomaticSyncFailure.classify(error)
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
