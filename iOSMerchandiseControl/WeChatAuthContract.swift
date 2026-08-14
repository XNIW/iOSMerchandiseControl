import Foundation
import Security

nonisolated enum AuthProviderKind: String, Sendable {
    case email
    case google
    case wechat
}

nonisolated enum WeChatSurface: String, Sendable {
    case ios
}

nonisolated enum WeChatAuthError: String, Error, Equatable, Sendable {
    case providerNotConfigured = "provider_not_configured"
    case appNotInstalled = "app_not_installed"
    case userCancelled = "user_cancelled"
    case userDenied = "user_denied"
    case stateMismatch = "state_invalid"
    case stateExpired = "state_expired"
    case callbackDuplicate = "state_replayed"
    case codeMissing = "code_missing"
    case backendTemporary = "backend_temporary"
    case identityConflict = "identity_conflict"
    case accountSuspended = "account_suspended"
    case sessionExpired = "session_expired"
}

nonisolated struct WeChatAuthConfiguration: Equatable, Sendable {
    private static let configFileName = "SupabaseConfig"
    static let enabledKey = "WECHAT_AUTH_IOS_ENABLED"
    static let appIDKey = "WECHAT_IOS_APP_ID"
    static let universalLinkKey = "WECHAT_IOS_UNIVERSAL_LINK"
    static let gatewayBaseURLKey = "WECHAT_AUTH_GATEWAY_BASE_URL"

    let enabled: Bool
    let appID: String?
    let universalLink: URL?
    let gatewayBaseURL: URL?

    var hasPublicConfiguration: Bool {
        enabled && appID != nil && universalLink != nil && gatewayBaseURL != nil
    }

    static func load(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> WeChatAuthConfiguration {
        let fileValues = loadConfigFile(bundle: bundle)
        let enabledValue = normalized(environment[enabledKey])
            ?? normalized(fileValues[enabledKey])
            ?? normalized(bundle.object(forInfoDictionaryKey: enabledKey))
        let appIDValue = normalized(environment[appIDKey])
            ?? normalized(fileValues[appIDKey])
            ?? normalized(bundle.object(forInfoDictionaryKey: appIDKey))
        let universalLinkValue = normalized(environment[universalLinkKey])
            ?? normalized(fileValues[universalLinkKey])
            ?? normalized(bundle.object(forInfoDictionaryKey: universalLinkKey))
        let gatewayValue = normalized(environment[gatewayBaseURLKey])
            ?? normalized(fileValues[gatewayBaseURLKey])
            ?? normalized(bundle.object(forInfoDictionaryKey: gatewayBaseURLKey))

        let appID = appIDValue.flatMap(validatedAppID)
        let universalLink = universalLinkValue.flatMap(validatedUniversalLink)
        let gatewayURL = gatewayValue.flatMap(validatedGatewayBaseURL)
        return WeChatAuthConfiguration(
            enabled: enabledValue == "1" || enabledValue?.lowercased() == "true",
            appID: appID,
            universalLink: universalLink,
            gatewayBaseURL: gatewayURL
        )
    }

    private static func loadConfigFile(bundle: Bundle) -> [String: Any] {
        guard let url = bundle.url(forResource: configFileName, withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ),
              let values = plist as? [String: Any] else {
            return [:]
        }
        return values
    }

    private static func normalized(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.uppercased().hasPrefix("YOUR_") else { return nil }
        return trimmed
    }

    private static func validatedAppID(_ value: String) -> String? {
        guard value.range(of: #"^wx[A-Za-z0-9]{6,32}$"#, options: .regularExpression) != nil else {
            return nil
        }
        return value
    }

    private static func validatedUniversalLink(_ value: String) -> URL? {
        guard let url = URL(string: value),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.hasSuffix("/") else {
            return nil
        }
        return url
    }

    private static func validatedGatewayBaseURL(_ value: String) -> URL? {
        guard let url = URL(string: value),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/" else {
            return nil
        }
        return url
    }
}

nonisolated struct WeChatAuthorizationRequest: Equatable, Sendable {
    let appID: String
    let state: String
}

nonisolated struct WeChatAuthorizationResponse: Equatable, Sendable {
    let code: String?
    let state: String?
    let outcome: Outcome

    enum Outcome: Equatable, Sendable {
        case success
        case cancelled
        case denied
    }
}

nonisolated protocol WeChatAuthorizationCodeProviding: Sendable {
    var isAvailable: Bool { get }
    func authorize(_ request: WeChatAuthorizationRequest) async throws -> WeChatAuthorizationResponse
    func handleOpenURL(_ url: URL) -> Bool
    func handleUniversalLink(_ userActivity: NSUserActivity) -> Bool
}

nonisolated struct UnconfiguredWeChatAuthorizationCodeProvider: WeChatAuthorizationCodeProviding {
    let isAvailable = false

    func authorize(_ request: WeChatAuthorizationRequest) async throws -> WeChatAuthorizationResponse {
        throw WeChatAuthError.providerNotConfigured
    }

    func handleOpenURL(_ url: URL) -> Bool { false }

    func handleUniversalLink(_ userActivity: NSUserActivity) -> Bool { false }
}

nonisolated struct WeChatChallenge: Codable, Equatable, Sendable {
    let correlationID: UUID
    let expiresInSeconds: Int
    let nonce: String
    let state: String

    enum CodingKeys: String, CodingKey {
        case correlationID = "correlationId"
        case expiresInSeconds
        case nonce
        case state
    }
}

nonisolated struct WeChatSupabaseSession: Codable, Equatable, Sendable {
    let accessToken: String
    let expiresAt: Int
    let expiresIn: Int
    let refreshToken: String
    let tokenType: String
    let user: User

    struct User: Codable, Equatable, Sendable {
        let id: UUID
        let provider: String
    }
}

nonisolated protocol WeChatAuthGateway: Sendable {
    var isConfigured: Bool { get }
    func issueChallenge(deviceID: UUID, state: String, nonce: String) async throws -> WeChatChallenge
    func exchange(challenge: WeChatChallenge, code: String, deviceID: UUID) async throws -> WeChatSupabaseSession
}

nonisolated struct UnconfiguredWeChatAuthGateway: WeChatAuthGateway {
    let isConfigured = false

    func issueChallenge(deviceID: UUID, state: String, nonce: String) async throws -> WeChatChallenge {
        throw WeChatAuthError.providerNotConfigured
    }

    func exchange(
        challenge: WeChatChallenge,
        code: String,
        deviceID: UUID
    ) async throws -> WeChatSupabaseSession {
        throw WeChatAuthError.providerNotConfigured
    }
}

nonisolated final class WeChatDeviceIDStore: @unchecked Sendable {
    private static let key = "wechat.auth.install.id"
    private static let lock = NSLock()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func getOrCreate() -> UUID {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        if let stored = defaults.string(forKey: Self.key),
           let identifier = UUID(uuidString: stored) {
            return identifier
        }
        let identifier = UUID()
        defaults.set(identifier.uuidString.lowercased(), forKey: Self.key)
        return identifier
    }
}

nonisolated struct WeChatCallbackGuard: Sendable {
    private let expectedState: String
    private let expiresAt: Date
    private(set) var consumed = false

    init(expectedState: String, expiresAt: Date) {
        self.expectedState = expectedState
        self.expiresAt = expiresAt
    }

    mutating func consume(
        _ response: WeChatAuthorizationResponse,
        now: Date = Date()
    ) throws -> String {
        guard !consumed else { throw WeChatAuthError.callbackDuplicate }
        guard now < expiresAt else { throw WeChatAuthError.stateExpired }
        consumed = true

        switch response.outcome {
        case .cancelled:
            throw WeChatAuthError.userCancelled
        case .denied:
            throw WeChatAuthError.userDenied
        case .success:
            break
        }

        guard let returnedState = response.state,
              Self.constantTimeEqual(returnedState, expectedState) else {
            throw WeChatAuthError.stateMismatch
        }
        guard let code = response.code,
              code.range(of: #"^[A-Za-z0-9_-]{1,512}$"#, options: .regularExpression) != nil else {
            throw WeChatAuthError.codeMissing
        }
        return code
    }

    private static func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs.utf8)
        let right = Array(rhs.utf8)
        guard left.count == right.count else { return false }
        var difference: UInt8 = 0
        for index in left.indices {
            difference |= left[index] ^ right[index]
        }
        return difference == 0
    }
}

actor WeChatAuthCoordinator {
    nonisolated let isConfigured: Bool

    private let configuration: WeChatAuthConfiguration
    private let codeProvider: any WeChatAuthorizationCodeProviding
    private let deviceID: @Sendable () -> UUID
    private let gateway: any WeChatAuthGateway
    private let now: @Sendable () -> Date

    init(
        configuration: WeChatAuthConfiguration,
        codeProvider: any WeChatAuthorizationCodeProviding,
        deviceID: @escaping @Sendable () -> UUID = UUID.init,
        gateway: any WeChatAuthGateway,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.configuration = configuration
        self.codeProvider = codeProvider
        self.deviceID = deviceID
        self.gateway = gateway
        self.now = now
        self.isConfigured = configuration.hasPublicConfiguration
            && codeProvider.isAvailable
            && gateway.isConfigured
    }

    func authenticate() async throws -> WeChatSupabaseSession {
        guard isConfigured,
              let appID = configuration.appID else {
            throw WeChatAuthError.providerNotConfigured
        }

        let state = try Self.secureBase64URLToken()
        let nonce = try Self.secureBase64URLToken()
        let deviceID = deviceID()
        let challenge = try await gateway.issueChallenge(
            deviceID: deviceID,
            state: state,
            nonce: nonce
        )
        guard challenge.state == state, challenge.nonce == nonce else {
            throw WeChatAuthError.stateMismatch
        }

        var callbackGuard = WeChatCallbackGuard(
            expectedState: state,
            expiresAt: now().addingTimeInterval(TimeInterval(challenge.expiresInSeconds))
        )
        let response = try await codeProvider.authorize(
            WeChatAuthorizationRequest(appID: appID, state: state)
        )
        let code = try callbackGuard.consume(response, now: now())
        return try await gateway.exchange(
            challenge: challenge,
            code: code,
            deviceID: deviceID
        )
    }

    nonisolated func handleOpenURL(_ url: URL) -> Bool {
        codeProvider.handleOpenURL(url)
    }

    nonisolated func handleUniversalLink(_ userActivity: NSUserActivity) -> Bool {
        codeProvider.handleUniversalLink(userActivity)
    }

    private static func secureBase64URLToken() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw WeChatAuthError.backendTemporary
        }
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
