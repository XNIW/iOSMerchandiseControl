import Combine
import Foundation
import SwiftUI

@MainActor
final class SupabaseAuthViewModel: ObservableObject {
    enum State: Equatable, Sendable {
        case unconfigured
        case signedOut
        case signingIn
        case signedIn
        case signingOut
        case failed(SupabaseAuthServiceError)
    }

    @Published private(set) var state: State
    @Published private(set) var sessionInfo: SupabaseAuthSessionInfo?

    private let authService: SupabaseAuthService?
    private var authEventsTask: Task<Void, Never>?

    init(authService: SupabaseAuthService?, initialError: SupabaseAuthServiceError? = nil) {
        let initialSessionInfo = authService?.currentSession
        self.authService = authService
        self.sessionInfo = initialSessionInfo

        if authService == nil {
            self.state = .unconfigured
        } else if let initialError {
            self.state = .failed(initialError)
        } else if let initialSessionInfo, !initialSessionInfo.isExpired {
            self.state = .signedIn
        } else {
            self.state = .signedOut
        }

        startAuthListener()
    }

    deinit {
        authEventsTask?.cancel()
    }

    var isSignedIn: Bool {
        if case .signedIn = state,
           let sessionInfo {
            return !sessionInfo.isExpired
        }
        return false
    }

    var isTransitioning: Bool {
        switch state {
        case .signingIn, .signingOut:
            return true
        case .unconfigured, .signedOut, .signedIn, .failed:
            return false
        }
    }

    var canSignIn: Bool {
        switch state {
        case .signedOut, .failed:
            return authService != nil && !isTransitioning
        case .unconfigured, .signingIn, .signedIn, .signingOut:
            return false
        }
    }

    var canSignOut: Bool {
        isSignedIn && !isTransitioning
    }

    func signInWithGoogle() {
        guard canSignIn, let authService else { return }

        state = .signingIn

        Task {
            do {
                let info = try await authService.signInWithGoogle()
                sessionInfo = info
                state = info.isExpired ? .signedOut : .signedIn
            } catch let error as SupabaseAuthServiceError {
                sessionInfo = authService.currentSession
                state = .failed(error)
            } catch {
                sessionInfo = authService.currentSession
                state = .failed(.unknown(message: String(describing: error)))
            }
        }
    }

    func signOut() {
        guard canSignOut, let authService else { return }

        state = .signingOut

        Task {
            do {
                try await authService.signOut()
                sessionInfo = nil
                state = .signedOut
            } catch let error as SupabaseAuthServiceError {
                sessionInfo = authService.currentSession
                state = .failed(error)
            } catch {
                sessionInfo = authService.currentSession
                state = .failed(.unknown(message: String(describing: error)))
            }
        }
    }

    func handleOpenURL(_ url: URL) -> Bool {
        authService?.handleOpenURL(url) ?? false
    }

    private func startAuthListener() {
        guard let authService else { return }

        authEventsTask = Task { [weak self] in
            for await event in authService.authStateChanges() {
                self?.apply(event)
            }
        }
    }

    private func apply(_ event: SupabaseAuthEvent) {
        switch event {
        case .initialSession(let info), .tokenRefreshed(let info), .other(let info):
            sessionInfo = info
            if let info, !info.isExpired {
                state = .signedIn
            } else if !isTransitioning {
                state = .signedOut
            }
        case .signedIn(let info):
            sessionInfo = info
            state = info.isExpired ? .signedOut : .signedIn
        case .signedOut:
            sessionInfo = nil
            state = .signedOut
        }
    }
}
