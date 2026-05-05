import AuthenticationServices
import Foundation
import Supabase

nonisolated enum SupabaseAuthServiceError: Error, Equatable, Sendable {
    case configMissing
    case invalidConfig
    case oauthCancelled
    case callbackFailed(message: String?)
    case sessionMissing
    case unknown(message: String?)

    var safeDiagnosticDetail: String? {
        switch self {
        case .configMissing, .invalidConfig, .oauthCancelled, .sessionMissing:
            return nil
        case .callbackFailed(let message), .unknown(let message):
            return SupabaseInventoryServiceError.sanitizedDiagnosticDetail(message)
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
}

nonisolated enum SupabaseAuthEvent: Sendable {
    case initialSession(SupabaseAuthSessionInfo?)
    case signedIn(SupabaseAuthSessionInfo)
    case signedOut
    case tokenRefreshed(SupabaseAuthSessionInfo?)
    case other(SupabaseAuthSessionInfo?)
}

final class SupabaseAuthService: @unchecked Sendable {
    private let provider: SupabaseClientProvider

    init(provider: SupabaseClientProvider) {
        self.provider = provider
    }

    var currentSession: SupabaseAuthSessionInfo? {
        provider.client.auth.currentSession.map { Self.sessionInfo(from: $0) }
    }

    func signInWithGoogle() async throws -> SupabaseAuthSessionInfo {
        do {
            let session = try await provider.client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: provider.redirectURL
            )
            return Self.sessionInfo(from: session)
        } catch {
            throw mapAuthError(error)
        }
    }

    func signOut() async throws {
        do {
            try await provider.client.auth.signOut()
        } catch {
            throw mapAuthError(error)
        }
    }

    func handleOpenURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == provider.redirectURL.scheme?.lowercased() else {
            return false
        }

        provider.client.auth.handle(url)
        return true
    }

    func authStateChanges() -> AsyncStream<SupabaseAuthEvent> {
        AsyncStream { continuation in
            let task = Task {
                for await change in provider.client.auth.authStateChanges {
                    continuation.yield(Self.authEvent(from: change.event, session: change.session))
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func mapAuthError(_ error: Error) -> SupabaseAuthServiceError {
        if let authError = error as? SupabaseAuthServiceError {
            return authError
        }

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
