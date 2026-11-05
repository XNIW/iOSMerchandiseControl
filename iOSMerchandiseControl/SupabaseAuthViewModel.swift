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
    @Published private(set) var hasResolvedInitialSession: Bool

    private let authService: SupabaseAuthService?
    private let shopDeviceRegistrationService: ShopDeviceRegistrationService?
    private var authEventsTask: Task<Void, Never>?
    private var authOperationID = UUID()

    /// A value from an accepted SDK session, not a cloud session or a local
    /// capability. Task126 still qualifies the exact active store on every use.
    private struct LocalIdentity {
        let ownerUserID: UUID
        let witness: SupabaseLocalAuthReadWitness
    }
    private var localIdentity: LocalIdentity?

    init(
        authService: SupabaseAuthService?,
        initialError: SupabaseAuthServiceError? = nil,
        shopDeviceRegistrationService: ShopDeviceRegistrationService? = nil
    ) {
        let initialSessionInfo = authService?.currentSession
        self.authService = authService
        self.shopDeviceRegistrationService = shopDeviceRegistrationService
        self.sessionInfo = initialSessionInfo
        self.hasResolvedInitialSession = authService == nil || initialError != nil
            || (initialSessionInfo.map { !$0.isExpired } ?? false)

        if authService == nil {
            self.state = .unconfigured
        } else if let initialError {
            self.state = .failed(initialError)
        } else if let initialSessionInfo, !initialSessionInfo.isExpired {
            self.state = .signedIn
        } else {
            self.state = .signedOut
        }

        rememberLocalIdentity(initialSessionInfo)
        startAuthListener()
        registerShopDeviceIfReady(reason: "auth_initial")
    }

    deinit {
        authEventsTask?.cancel()
    }

    var isSignedIn: Bool {
        if case .signedIn = state,
           let sessionInfo, let localIdentity,
           authService?.acceptsLocalIdentityReadWitness(localIdentity.witness) == true {
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

    /// Presentation only. Cloud and local authority still use their existing gates.
    var requiresSignInForPresentation: Bool {
        hasResolvedInitialSession && sessionInfo == nil && localMutationOwnerUserID == nil
            && canSignIn && !isTransitioning
    }

    var isRestoringSessionForPresentation: Bool { !hasResolvedInitialSession }

    var isSessionTemporarilyUnavailableForPresentation: Bool {
        hasResolvedInitialSession && localMutationOwnerUserID != nil && !isSignedIn && !isTransitioning
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
        rememberLocalIdentity(currentSession)
        if currentSession.isExpired {
            if !isTransitioning {
                state = .signedOut
            }
        } else {
            state = .signedIn
        }
    }

    /// Identity supplied to the local mutation fence. That fence, rather
    /// than this presentation value, owns authorization for the active store.
    var localMutationOwnerUserID: UUID? {
        guard !isTransitioning, let localIdentity, let authService,
              authService.acceptsLocalIdentityReadWitness(localIdentity.witness) else { return nil }
        return localIdentity.ownerUserID
    }

    private func rememberLocalIdentity(_ info: SupabaseAuthSessionInfo?) {
        guard let info, let authService, let witness = authService.localIdentityReadWitness,
              witness.ownerUserID == info.userID,
              authService.acceptsAuthGeneration(witness.generation) else { return }
        localIdentity = LocalIdentity(ownerUserID: info.userID, witness: witness)
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
                rememberLocalIdentity(info)
                hasResolvedInitialSession = true
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
                rememberLocalIdentity(info)
                hasResolvedInitialSession = true
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
                localIdentity = nil
                sessionInfo = nil
                hasResolvedInitialSession = true
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
        if case .reauthenticationRequired = change.event {
            guard authService?.requiresReauthentication(generation: change.generation) == true else { return }
            localIdentity = nil
            sessionInfo = nil
            hasResolvedInitialSession = true
            state = .failed(.sessionMissing)
            return
        }
        guard authService?.acceptsAuthGeneration(change.generation) == true else { return }
        switch change.event {
        case .initialSession, .tokenRefreshed, .signedIn, .signedOut:
            hasResolvedInitialSession = true
        case .other, .reauthenticationRequired: break
        }
        switch change.event {
        case .initialSession(let info), .tokenRefreshed(let info), .other(let info):
            sessionInfo = info
            rememberLocalIdentity(info)
            if let info, !info.isExpired {
                state = .signedIn
                registerShopDeviceIfReady(reason: "auth_event")
            } else if !isTransitioning {
                state = .signedOut
            }
        case .signedIn(let info):
            sessionInfo = info
            rememberLocalIdentity(info)
            state = info.isExpired ? .signedOut : .signedIn
            if !info.isExpired {
                registerShopDeviceIfReady(reason: "auth_signed_in")
            }
        case .signedOut:
            localIdentity = nil
            sessionInfo = nil
            state = .signedOut
        case .reauthenticationRequired: break
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
            rememberLocalIdentity(currentSession)
            hasResolvedInitialSession = true
            state = .signedIn
            registerShopDeviceIfReady(reason: "auth_recovered")
            return
        }

        guard authOperationID == operationID, authService.authGeneration == failure.generation else { return }
        sessionInfo = authService.currentSession
        rememberLocalIdentity(sessionInfo)
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
