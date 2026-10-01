import AuthenticationServices
import Foundation
import Supabase

nonisolated enum SupabaseAuthServiceError: Error, Equatable, Sendable {
    case configMissing
    case invalidConfig
    case oauthCancelled
    case wechat(WeChatAuthError)
    case callbackFailed(message: String?)
    case sessionMissing
    case unknown(message: String?)

    var safeDiagnosticDetail: String? {
        switch self {
        case .configMissing, .invalidConfig, .oauthCancelled, .wechat, .sessionMissing:
            return nil
        case .callbackFailed(let message), .unknown(let message):
            return SupabaseTransportClientError.sanitizedDiagnosticDetail(message)
        }
    }
}

nonisolated struct SupabaseAuthSessionInfo: Equatable, Sendable {
    let userID: UUID
    let email: String?
    let provider: String?
    let isExpired: Bool

    var displayEmail: String? {
        guard let trimmed = email?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    var privacySafeDisplayEmail: String? {
        guard let displayEmail else { return nil }
        return Self.redactedEmail(displayEmail)
    }

    var privacySafeUserID: String {
        "\(userID.uuidString.prefix(8))-redacted"
    }

    private static func redactedEmail(_ email: String) -> String {
        let parts = email.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2,
              let firstCharacter = parts[0].first,
              !parts[1].isEmpty else {
            return "[redacted-email]"
        }

        return "\(firstCharacter)***@\(parts[1])"
    }
}

nonisolated enum SupabaseAuthEvent: Sendable {
    case initialSession(SupabaseAuthSessionInfo?)
    case signedIn(SupabaseAuthSessionInfo)
    case signedOut
    case tokenRefreshed(SupabaseAuthSessionInfo?)
    case other(SupabaseAuthSessionInfo?)
}

nonisolated struct SupabaseScopedAuthEvent: Sendable {
    let generation: UUID
    let event: SupabaseAuthEvent
}

nonisolated struct SupabaseAuthSessionResult: Sendable {
    let generation: UUID
    let info: SupabaseAuthSessionInfo
}

nonisolated struct SupabaseAuthOperationFailure: Error, Sendable {
    let generation: UUID
    let error: SupabaseAuthServiceError
}

final class SupabaseAuthService: @unchecked Sendable {
    nonisolated static let mobileSignOutScope: SignOutScope = .local

    private let provider: SupabaseClientProvider
    private let weChatCoordinator: WeChatAuthCoordinator?
    private let googleSignIn: (SupabaseClient, URL) async throws -> Session

    init(
        provider: SupabaseClientProvider,
        weChatCoordinator: WeChatAuthCoordinator? = nil,
        googleSignIn: ((SupabaseClient, URL) async throws -> Session)? = nil
    ) {
        self.provider = provider
        self.weChatCoordinator = weChatCoordinator
        self.googleSignIn = googleSignIn ?? { client, redirectURL in
            try await client.auth.signInWithOAuth(provider: .google, redirectTo: redirectURL)
        }
    }

    var currentSession: SupabaseAuthSessionInfo? {
        let snapshot = provider.authSnapshot
        guard provider.acceptsAuthGeneration(snapshot.generation) else { return nil }
        return snapshot.client.auth.currentSession.map { Self.sessionInfo(from: $0) }
    }

    var isWeChatEnabled: Bool {
        weChatCoordinator?.isConfigured == true
    }

    var authGeneration: UUID { provider.authSnapshot.generation }

    func acceptsAuthGeneration(_ generation: UUID) -> Bool {
        provider.acceptsAuthGeneration(generation)
    }

    func signInWithGoogle() async throws -> SupabaseAuthSessionResult {
        var generation = authGeneration
        do {
            let snapshot = try await provider.prepareInteractiveSignIn()
            generation = snapshot.generation
            try Task.checkCancellation()
            let session = try await googleSignIn(snapshot.client, provider.redirectURL)
            return try acceptedSignInResult(session, snapshot: snapshot)
        } catch {
            throw SupabaseAuthOperationFailure(generation: generation, error: mapAuthError(error))
        }
    }

    func signInWithWeChat() async throws -> SupabaseAuthSessionResult {
        var generation = authGeneration
        do {
            guard let weChatCoordinator, weChatCoordinator.isConfigured else {
                throw SupabaseAuthServiceError.wechat(.providerNotConfigured)
            }
            let snapshot = try await provider.prepareInteractiveSignIn()
            generation = snapshot.generation
            let handedOffSession = try await weChatCoordinator.authenticate()
            try Task.checkCancellation()
            guard provider.acceptsAuthGeneration(generation) else { throw CancellationError() }
            let session = try await snapshot.client.auth.setSession(
                accessToken: handedOffSession.accessToken,
                refreshToken: handedOffSession.refreshToken
            )
            return try acceptedSignInResult(session, snapshot: snapshot)
        } catch let error as WeChatAuthError {
            throw SupabaseAuthOperationFailure(generation: generation, error: .wechat(error))
        } catch {
            throw SupabaseAuthOperationFailure(generation: generation, error: mapAuthError(error))
        }
    }

    @discardableResult
    func signOut() async throws -> UUID {
        let snapshot: SupabaseAuthClientSnapshot
        do { snapshot = try provider.beginSignOut() }
        catch { throw SupabaseAuthOperationFailure(generation: authGeneration, error: mapAuthError(error)) }

        var remoteError: Error?
        do {
            // The user-facing mobile logout must end only this device session.
            // Global scope would also revoke Android/web refresh tokens.
            try await snapshot.client.auth.signOut(scope: Self.mobileSignOutScope)
        } catch { remoteError = error }

        // SDK storage errors are swallowed internally. Verify deletion even if
        // logout HTTP fails or is cancelled before retiring this generation.
        let generation: UUID
        do { generation = try await provider.finishSignOut(snapshot) }
        catch let failure as SupabaseAuthGenerationFailure {
            throw SupabaseAuthOperationFailure(generation: failure.generation, error: mapAuthError(failure.underlying))
        } catch { throw SupabaseAuthOperationFailure(generation: snapshot.generation, error: mapAuthError(error)) }
        if let remoteError {
            throw SupabaseAuthOperationFailure(generation: generation, error: mapAuthError(remoteError))
        }
        return generation
    }

    private func acceptedSignInResult(_ session: Session, snapshot: SupabaseAuthClientSnapshot) throws -> SupabaseAuthSessionResult {
        try Task.checkCancellation()
        guard provider.acceptsAuthGeneration(snapshot.generation) else { throw CancellationError() }
        // A successful SDK response alone does not prove its fallible storage
        // accepted the session. Never publish an unpersisted login as success.
        guard snapshot.client.auth.currentSession?.accessToken == session.accessToken else {
            throw SupabaseAuthServiceError.unknown(message: "Local session persistence failed")
        }
        return .init(generation: snapshot.generation, info: Self.sessionInfo(from: session))
    }

    func handleOpenURL(_ url: URL) -> Bool {
        if weChatCoordinator?.handleOpenURL(url) == true {
            return true
        }
        guard url.scheme?.lowercased() == provider.redirectURL.scheme?.lowercased() else {
            return false
        }

        let snapshot = provider.authSnapshot
        guard provider.acceptsAuthGeneration(snapshot.generation) else { return false }
        snapshot.client.auth.handle(url)
        return true
    }

    func handleUniversalLink(_ userActivity: NSUserActivity) -> Bool {
        weChatCoordinator?.handleUniversalLink(userActivity) == true
    }

    func authStateChanges() -> AsyncStream<SupabaseScopedAuthEvent> {
        AsyncStream { continuation in
            let task = Task {
                var listener: Task<Void, Never>?
                defer { listener?.cancel(); continuation.finish() }
                for await snapshot in provider.authClientChanges() {
                    listener?.cancel()
                    listener = Task {
                        for await change in snapshot.client.auth.authStateChanges {
                            guard !Task.isCancelled,
                                  provider.acceptsAuthGeneration(snapshot.generation) else { continue }
                            if let session = change.session,
                               snapshot.client.auth.currentSession?.accessToken != session.accessToken {
                                continue
                            }
                            continuation.yield(.init(generation: snapshot.generation,
                                event: Self.authEvent(from: change.event, session: change.session)))
                        }
                    }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func mapAuthError(_ error: Error) -> SupabaseAuthServiceError {
        if let authError = error as? SupabaseAuthServiceError {
            return authError
        }

        if error is CancellationError { return .oauthCancelled }

        let nsError = error as NSError
        if nsError.domain == ASWebAuthenticationSessionError.errorDomain,
           ASWebAuthenticationSessionError.Code(rawValue: nsError.code) == .canceledLogin {
            return .oauthCancelled
        }

        let message = String(describing: error)
        let lowercased = message.lowercased()
        if lowercased.contains("oauth") || lowercased.contains("callback") || lowercased.contains("pkce") {
            return .callbackFailed(message: message)
        }

        if lowercased.contains("session") && lowercased.contains("missing") {
            return .sessionMissing
        }

        return .unknown(message: message)
    }

    private static func authEvent(from event: AuthChangeEvent, session: Session?) -> SupabaseAuthEvent {
        let info = session.map { sessionInfo(from: $0) }

        switch event {
        case .initialSession:
            return .initialSession(info)
        case .signedIn:
            return info.map(SupabaseAuthEvent.signedIn) ?? .signedOut
        case .signedOut, .userDeleted:
            return .signedOut
        case .tokenRefreshed:
            return .tokenRefreshed(info)
        default:
            return .other(info)
        }
    }

    private static func sessionInfo(from session: Session) -> SupabaseAuthSessionInfo {
        let identityProvider = session.user.identities?
            .first { $0.provider.lowercased() == Provider.google.rawValue }?
            .provider
            ?? session.user.identities?.first?.provider

        return SupabaseAuthSessionInfo(
            userID: session.user.id,
            email: session.user.email,
            provider: identityProvider ?? Provider.google.rawValue,
            isExpired: session.isExpired
        )
    }
}
