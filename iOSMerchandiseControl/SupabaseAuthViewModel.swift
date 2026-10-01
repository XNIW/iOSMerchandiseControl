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
    private let shopDeviceRegistrationService: ShopDeviceRegistrationService?
    private var authEventsTask: Task<Void, Never>?
    private var authOperationID = UUID()

    init(
        authService: SupabaseAuthService?,
        initialError: SupabaseAuthServiceError? = nil,
        shopDeviceRegistrationService: ShopDeviceRegistrationService? = nil
    ) {
        let initialSessionInfo = authService?.currentSession
        self.authService = authService
        self.shopDeviceRegistrationService = shopDeviceRegistrationService
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
        registerShopDeviceIfReady(reason: "auth_initial")
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

    var isWeChatEnabled: Bool {
        authService?.isWeChatEnabled == true
    }

    var canSignInWithWeChat: Bool {
        canSignIn && isWeChatEnabled
    }

    var canSignOut: Bool {
        isSignedIn && !isTransitioning
    }

    func refreshCurrentSessionSnapshot() {
        guard let currentSession = authService?.currentSession else {
            sessionInfo = nil
            if !isTransitioning { state = authService == nil ? .unconfigured : .signedOut }
            return
        }
        sessionInfo = currentSession
        if currentSession.isExpired {
            if !isTransitioning {
                state = .signedOut
            }
        } else {
            state = .signedIn
        }
    }

    func signInWithGoogle() {
        guard canSignIn, let authService else { return }

        let operationID = UUID()
        authOperationID = operationID
        state = .signingIn

        Task {
            do {
                let result = try await authService.signInWithGoogle()
                guard authOperationID == operationID,
                      authService.acceptsAuthGeneration(result.generation) else { return }
                let info = result.info
                sessionInfo = info
                state = info.isExpired ? .signedOut : .signedIn
                if !info.isExpired {
                    registerShopDeviceIfReady(reason: "auth_sign_in")
                }
            } catch let failure as SupabaseAuthOperationFailure {
                await applySignInFailure(failure, operationID: operationID, authService: authService)
            } catch {
                await applySignInFailure(.init(generation: authService.authGeneration,
                    error: .unknown(message: String(describing: error))), operationID: operationID, authService: authService)
            }
        }
    }

    func signInWithWeChat() {
        guard canSignInWithWeChat, let authService else { return }

        let operationID = UUID()
        authOperationID = operationID
        state = .signingIn
        Task {
            do {
                let result = try await authService.signInWithWeChat()
                guard authOperationID == operationID,
                      authService.acceptsAuthGeneration(result.generation) else { return }
                let info = result.info
                sessionInfo = info
                state = info.isExpired ? .signedOut : .signedIn
                if !info.isExpired {
                    registerShopDeviceIfReady(reason: "auth_sign_in_wechat")
                }
            } catch let failure as SupabaseAuthOperationFailure {
                await applySignInFailure(failure, operationID: operationID, authService: authService)
            } catch {
                await applySignInFailure(.init(generation: authService.authGeneration,
                    error: .unknown(message: String(describing: error))), operationID: operationID, authService: authService)
            }
        }
    }

    func signOut() {
        guard canSignOut, let authService else { return }

        let operationID = UUID()
        authOperationID = operationID
        state = .signingOut

        Task {
            do {
                let generation = try await authService.signOut()
                guard authOperationID == operationID, authService.authGeneration == generation else { return }
                sessionInfo = nil
                state = .signedOut
            } catch let failure as SupabaseAuthOperationFailure {
                guard authOperationID == operationID, authService.authGeneration == failure.generation else { return }
                sessionInfo = authService.currentSession
                state = .failed(failure.error)
            } catch {
                guard authOperationID == operationID else { return }
                sessionInfo = authService.currentSession
                state = .failed(.unknown(message: String(describing: error)))
            }
        }
    }

    func handleOpenURL(_ url: URL) -> Bool {
        authService?.handleOpenURL(url)
            ?? (url.scheme?.lowercased() == SupabaseOAuthRedirect.scheme.lowercased())
    }

    func handleUniversalLink(_ userActivity: NSUserActivity) -> Bool {
        authService?.handleUniversalLink(userActivity) ?? false
    }

    private func startAuthListener() {
        guard let authService else { return }

        authEventsTask = Task { [weak self] in
            for await event in authService.authStateChanges() {
                self?.apply(event)
            }
        }
    }

    func apply(_ change: SupabaseScopedAuthEvent) {
        guard authService?.acceptsAuthGeneration(change.generation) == true else { return }
        switch change.event {
        case .initialSession(let info), .tokenRefreshed(let info), .other(let info):
            sessionInfo = info
            if let info, !info.isExpired {
                state = .signedIn
                registerShopDeviceIfReady(reason: "auth_event")
            } else if !isTransitioning {
                state = .signedOut
            }
        case .signedIn(let info):
            sessionInfo = info
            state = info.isExpired ? .signedOut : .signedIn
            if !info.isExpired {
                registerShopDeviceIfReady(reason: "auth_signed_in")
            }
        case .signedOut:
            sessionInfo = nil
            state = .signedOut
        }
    }

    private func applySignInFailure(
        _ failure: SupabaseAuthOperationFailure,
        operationID: UUID,
        authService: SupabaseAuthService
    ) async {
        guard authOperationID == operationID, authService.authGeneration == failure.generation else { return }
        if let currentSession = await recoveredSessionAfterSignInFailure(failure.error,
            generation: failure.generation, operationID: operationID, authService: authService) {
            guard authOperationID == operationID,
                  authService.acceptsAuthGeneration(failure.generation) else { return }
            sessionInfo = currentSession
            state = .signedIn
            registerShopDeviceIfReady(reason: "auth_recovered")
            return
        }

        guard authOperationID == operationID, authService.authGeneration == failure.generation else { return }
        sessionInfo = authService.currentSession
        state = .failed(failure.error)
    }

    private func recoveredSessionAfterSignInFailure(
        _ error: SupabaseAuthServiceError,
        generation: UUID,
        operationID: UUID,
        authService: SupabaseAuthService
    ) async -> SupabaseAuthSessionInfo? {
        guard authOperationID == operationID,
              authService.acceptsAuthGeneration(generation) else { return nil }
        if let currentSession = authService.currentSession, !currentSession.isExpired {
            return currentSession
        }

        guard shouldWaitForPostOAuthSession(error) else { return nil }
        for _ in 0..<10 {
            if Task.isCancelled { return nil }
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard authOperationID == operationID,
                  authService.acceptsAuthGeneration(generation) else { return nil }
            if let currentSession = authService.currentSession, !currentSession.isExpired {
                return currentSession
            }
        }
        return nil
    }

    private func shouldWaitForPostOAuthSession(_ error: SupabaseAuthServiceError) -> Bool {
        switch error {
        case .sessionMissing, .callbackFailed, .unknown:
            return true
        case .configMissing, .invalidConfig, .oauthCancelled, .wechat:
            return false
        }
    }

    private func registerShopDeviceIfReady(reason: String) {
        guard isSignedIn, let shopDeviceRegistrationService else { return }
        Task {
            await shopDeviceRegistrationService.registerHeartbeatAndCheck(reason: reason)
        }
    }
}
