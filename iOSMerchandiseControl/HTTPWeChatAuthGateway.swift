import Foundation

nonisolated private let weChatResponseByteLimit = 65_536

nonisolated final class HTTPWeChatAuthGateway: WeChatAuthGateway, @unchecked Sendable {
    let isConfigured = true

    private let baseURL: URL
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(baseURL: URL, session: URLSession? = nil) {
        self.baseURL = baseURL
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 8
            configuration.timeoutIntervalForResource = 8
            configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            configuration.urlCache = nil
            self.session = URLSession(
                configuration: configuration,
                delegate: WeChatNoRedirectDelegate.shared,
                delegateQueue: nil
            )
        }
    }

    func issueChallenge(deviceID: UUID, state: String, nonce: String) async throws -> WeChatChallenge {
        let response: ChallengeEnvelope = try await post(
            path: "/api/auth/wechat/challenge",
            body: ChallengeRequest(
                deviceID: deviceID,
                mode: "login",
                nonce: nonce,
                state: state,
                surface: WeChatSurface.ios.rawValue
            )
        )
        guard response.challenge.state == state,
              response.challenge.nonce == nonce else {
            throw WeChatAuthError.stateMismatch
        }
        return response.challenge
    }

    func exchange(
        challenge: WeChatChallenge,
        code: String,
        deviceID: UUID
    ) async throws -> WeChatSupabaseSession {
        guard !code.isEmpty, code.utf8.count <= 512 else {
            throw WeChatAuthError.codeMissing
        }
        let session: WeChatSupabaseSession = try await post(
            path: "/api/auth/wechat/exchange",
            body: ExchangeRequest(
                code: code,
                correlationID: challenge.correlationID,
                deviceID: deviceID,
                mode: "login",
                nonce: challenge.nonce,
                state: challenge.state,
                surface: WeChatSurface.ios.rawValue
            )
        )
        guard !session.accessToken.isEmpty,
              !session.refreshToken.isEmpty,
              session.tokenType.lowercased() == "bearer" else {
            throw WeChatAuthError.backendTemporary
        }
        return session
    }

    private func post<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        guard let url = URL(string: path, relativeTo: baseURL)?.absoluteURL,
              url.scheme?.lowercased() == "https",
              url.host?.lowercased() == baseURL.host?.lowercased() else {
            throw WeChatAuthError.providerNotConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(body)
        guard request.httpBody?.count ?? 0 <= 4_096 else {
            throw WeChatAuthError.backendTemporary
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw WeChatAuthError.backendTemporary
        }
        guard data.count <= weChatResponseByteLimit,
              let httpResponse = response as? HTTPURLResponse,
              httpResponse.url?.scheme?.lowercased() == "https",
              httpResponse.url?.host?.lowercased() == baseURL.host?.lowercased() else {
            throw WeChatAuthError.backendTemporary
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let envelope = try? decoder.decode(ErrorEnvelope.self, from: data)
            throw Self.error(for: envelope?.code)
        }
        do {
            return try decoder.decode(ResponseBody.self, from: data)
        } catch {
            throw WeChatAuthError.backendTemporary
        }
    }

    private static func error(for code: String?) -> WeChatAuthError {
        switch code {
        case "provider_not_configured": .providerNotConfigured
        case "identity_conflict", "identity_already_linked": .identityConflict
        case "account_suspended": .accountSuspended
        case "session_expired": .sessionExpired
        case "state_expired": .stateExpired
        case "state_invalid", "state_replayed": .stateMismatch
        case "code_missing": .codeMissing
        case "user_cancelled": .userCancelled
        case "user_denied": .userDenied
        default: .backendTemporary
        }
    }

    private struct ChallengeRequest: Encodable {
        let deviceID: UUID
        let mode: String
        let nonce: String
        let state: String
        let surface: String

        enum CodingKeys: String, CodingKey {
            case deviceID = "deviceId"
            case mode
            case nonce
            case state
            case surface
        }
    }

    private struct ChallengeEnvelope: Decodable {
        let challenge: WeChatChallenge
    }

    private struct ExchangeRequest: Encodable {
        let code: String
        let correlationID: UUID
        let deviceID: UUID
        let mode: String
        let nonce: String
        let state: String
        let surface: String

        enum CodingKeys: String, CodingKey {
            case code
            case correlationID = "correlationId"
            case deviceID = "deviceId"
            case mode
            case nonce
            case state
            case surface
        }
    }

    private struct ErrorEnvelope: Decodable {
        let code: String?
    }
}

private final class WeChatNoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = WeChatNoRedirectDelegate()

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
