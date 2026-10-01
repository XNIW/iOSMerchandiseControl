import Foundation
import Supabase

nonisolated enum SupabaseOAuthRedirect {
    static let scheme = "com.niwcyber.iosmerchandisecontrol"
    static let url = URL(string: "\(scheme)://login-callback")!
}

nonisolated struct SupabaseAuthClientSnapshot: Sendable {
    let generation: UUID
    let client: SupabaseClient
}

final class SupabaseClientProvider: @unchecked Sendable {
    let config: SupabaseConfig
    let redirectURL: URL
    private let authGroup: SupabaseAuthClientGroup
    nonisolated private let activeSnapshot: SupabaseAuthActiveSnapshot

    // Foreground and background providers share the same active SDK generation.
    nonisolated var client: SupabaseClient { activeSnapshot.read().client }
    var authSnapshot: SupabaseAuthClientSnapshot { authGroup.snapshot }

    init(
        config: SupabaseConfig,
        redirectURL: URL = SupabaseOAuthRedirect.url,
        authStorage: (any AuthLocalStorage)? = nil,
        session: URLSession = .shared,
        autoRefreshToken: Bool = true,
        authRegistry: SupabaseAuthClientRegistry? = nil
    ) {
        self.config = config
        self.redirectURL = redirectURL
        let group = (authRegistry ?? .shared).group(
            config: config, redirectURL: redirectURL,
            storage: authStorage ?? SupabaseAuthLocalStorage(),
            session: session, autoRefreshToken: autoRefreshToken
        )
        self.authGroup = group
        self.activeSnapshot = group.snapshotStorage
    }

    func acceptsAuthGeneration(_ generation: UUID) -> Bool {
        authGroup.fence.accepts(generation)
    }

    func authClientChanges() -> AsyncStream<SupabaseAuthClientSnapshot> {
        authGroup.changes()
    }

    func beginSignOut() throws -> SupabaseAuthClientSnapshot {
        try authGroup.fence.beginSignOut(authGroup.snapshot.generation)
        return authGroup.snapshot
    }

    func finishSignOut(_ snapshot: SupabaseAuthClientSnapshot) async throws -> UUID {
        do {
            try authGroup.fence.finishSignOut(snapshot.generation)
        } catch {
            let replacement = await authGroup.rotateIfNeeded()
            throw SupabaseAuthGenerationFailure(generation: replacement.generation, underlying: error)
        }
        return await authGroup.rotateIfNeeded().generation
    }

    func prepareInteractiveSignIn() async throws -> SupabaseAuthClientSnapshot {
        try authGroup.fence.prepareInteractiveSignIn()
        return await authGroup.rotateIfNeeded()
    }
}

// Registry scope is the SDK session storage key, including the background provider.
// Tests can use a fresh registry to model a process restart on the same storage.
final class SupabaseAuthClientRegistry {
    static let shared = SupabaseAuthClientRegistry()
    private var groups: [String: SupabaseAuthClientGroup] = [:]

    fileprivate func group(
        config: SupabaseConfig, redirectURL: URL, storage: any AuthLocalStorage,
        session: URLSession, autoRefreshToken: Bool
    ) -> SupabaseAuthClientGroup {
        let host = config.projectURL.host ?? ""
        let key = "sb-\(host.split(separator: ".")[0])-auth-token"
        if let existing = groups[key] { return existing }
        let group = SupabaseAuthClientGroup(config: config, redirectURL: redirectURL,
            storage: storage, storageKey: key, session: session, autoRefreshToken: autoRefreshToken)
        groups[key] = group
        return group
    }
}

// Preserve the original Sendable client-read contract without accessing mutable actor state.
nonisolated private final class SupabaseAuthActiveSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: SupabaseAuthClientSnapshot

    init(_ snapshot: SupabaseAuthClientSnapshot) { self.snapshot = snapshot }

    func read() -> SupabaseAuthClientSnapshot { lock.withLock { snapshot } }
    func replace(_ snapshot: SupabaseAuthClientSnapshot) {
        lock.withLock { self.snapshot = snapshot }
    }
}

private final class SupabaseAuthClientGroup {
    let fence: SupabaseAuthStorageFence
    let snapshotStorage: SupabaseAuthActiveSnapshot
    private(set) var snapshot: SupabaseAuthClientSnapshot {
        get { snapshotStorage.read() }
        set { snapshotStorage.replace(newValue) }
    }
    private let makeClient: (UUID) -> SupabaseClient
    private var observers: [UUID: AsyncStream<SupabaseAuthClientSnapshot>.Continuation] = [:]

    init(config: SupabaseConfig, redirectURL: URL, storage: any AuthLocalStorage,
         storageKey: String, session: URLSession, autoRefreshToken: Bool) {
        let fence = SupabaseAuthStorageFence(storage: storage, sessionKey: storageKey)
        self.fence = fence
        let makeClient: (UUID) -> SupabaseClient = { generation in
            SupabaseClient(supabaseURL: config.projectURL, supabaseKey: config.publishableKey,
                options: .init(auth: .init(
                    storage: SupabaseGenerationStorage(fence: fence, generation: generation),
                    redirectToURL: redirectURL, storageKey: storageKey,
                    autoRefreshToken: autoRefreshToken, emitLocalSessionAsInitialSession: true
                ), global: .init(session: session)))
        }
        self.makeClient = makeClient
        self.snapshotStorage = SupabaseAuthActiveSnapshot(
            .init(generation: fence.generation, client: makeClient(fence.generation))
        )
    }

    func changes() -> AsyncStream<SupabaseAuthClientSnapshot> {
        AsyncStream { continuation in
            let id = UUID()
            observers[id] = continuation
            continuation.yield(snapshot)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in self?.observers.removeValue(forKey: id) }
            }
        }
    }

    func rotateIfNeeded() async -> SupabaseAuthClientSnapshot {
        guard snapshot.generation != fence.generation else { return snapshot }
        let retired = snapshot.client
        snapshot = .init(generation: fence.generation, client: makeClient(fence.generation))
        let replacement = snapshot
        for observer in observers.values { observer.yield(replacement) }
        await retired.auth.stopAutoRefresh()
        // A newer interactive generation can start during this await.
        return replacement
    }
}

nonisolated struct SupabaseAuthGenerationFailure: Error, @unchecked Sendable {
    let generation: UUID
    let underlying: Error
}

nonisolated private enum SupabaseAuthStorageFenceError: Error {
    case localSessionRemovalFailed
}

// Store/remove and generation changes use the same lock. A retired SDK refresh
// can finish and emit an event, but it cannot overwrite or delete a newer login.
nonisolated private final class SupabaseAuthStorageFence: @unchecked Sendable {
    private let lock = NSLock()
    private let storage: any AuthLocalStorage
    private let sessionKey: String
    private var currentGeneration = UUID()
    private var signingOut = false
    private var blocked = false

    init(storage: any AuthLocalStorage, sessionKey: String) {
        self.storage = storage
        self.sessionKey = sessionKey
    }
    var generation: UUID { lock.withLock { currentGeneration } }
    func accepts(_ generation: UUID) -> Bool {
        lock.withLock { generation == currentGeneration && !signingOut && !blocked }
    }
    func beginSignOut(_ generation: UUID) throws {
        try lock.withLock {
            guard generation == currentGeneration, !signingOut else { throw CancellationError() }
            signingOut = true
        }
    }
    func finishSignOut(_ generation: UUID) throws {
        try lock.withLock {
            guard generation == currentGeneration else { return }
            do {
                try removePersistedSession()
                blocked = false
            } catch {
                blocked = true
                signingOut = false
                currentGeneration = UUID()
                throw SupabaseAuthStorageFenceError.localSessionRemovalFailed
            }
            signingOut = false
            currentGeneration = UUID()
        }
    }
    func prepareInteractiveSignIn() throws {
        try lock.withLock {
            guard !signingOut else { throw CancellationError() }
            // A new SDK client bootstraps persisted sessions even with its
            // auto-refresh ticker disabled. Verify the retired session is gone
            // before creating the generation that will own the explicit login.
            do { try removePersistedSession() }
            catch {
                blocked = true
                throw SupabaseAuthStorageFenceError.localSessionRemovalFailed
            }
            blocked = false
            currentGeneration = UUID()
        }
    }
    private func removePersistedSession() throws {
        // The SDK retries its legacy migration on every read. A retained legacy
        // session or PKCE verifier must not revive the retired login after restart.
        for key in [sessionKey, "supabase.session", "\(sessionKey)-code-verifier"] {
            try storage.remove(key: key)
            guard try storage.retrieve(key: key) == nil else {
                throw SupabaseAuthStorageFenceError.localSessionRemovalFailed
            }
        }
    }
    func retrieve(key: String, generation: UUID) throws -> Data? {
        try lock.withLock {
            guard generation == currentGeneration, !blocked else { return nil }
            return try storage.retrieve(key: key)
        }
    }
    func store(key: String, value: Data, generation: UUID) throws {
        try lock.withLock {
            guard generation == currentGeneration, !signingOut, !blocked else { throw CancellationError() }
            try storage.store(key: key, value: value)
        }
    }
    func remove(key: String, generation: UUID) throws {
        try lock.withLock {
            guard generation == currentGeneration, !blocked else { throw CancellationError() }
            try storage.remove(key: key)
        }
    }
}

nonisolated private struct SupabaseGenerationStorage: AuthLocalStorage {
    let fence: SupabaseAuthStorageFence
    let generation: UUID
    func store(key: String, value: Data) throws { try fence.store(key: key, value: value, generation: generation) }
    func retrieve(key: String) throws -> Data? { try fence.retrieve(key: key, generation: generation) }
    func remove(key: String) throws { try fence.remove(key: key, generation: generation) }
}

private struct SupabaseAuthLocalStorage: AuthLocalStorage {
    private var keychainStorage: KeychainLocalStorage { KeychainLocalStorage() }

    func store(key: String, value: Data) throws {
        if isPKCECodeVerifierKey(key) {
            UserDefaults.standard.set(value, forKey: key)
            return
        }

        do {
            try keychainStorage.store(key: key, value: value)
#if DEBUG && targetEnvironment(simulator)
            storeSimulatorFallback(key: key, value: value)
#endif
        } catch {
#if DEBUG && targetEnvironment(simulator)
            storeSimulatorFallback(key: key, value: value)
#else
            throw error
#endif
        }
    }

    func retrieve(key: String) throws -> Data? {
        if isPKCECodeVerifierKey(key) {
            return UserDefaults.standard.data(forKey: key)
        }

#if DEBUG && targetEnvironment(simulator)
        if shouldUseSimulatorFallbackOnly(),
           let value = simulatorFallbackValue(key: key) {
            return value
        }

        do {
            if let value = try keychainStorage.retrieve(key: key) {
                return value
            }
        } catch {
            return simulatorFallbackValue(key: key)
        }
        return simulatorFallbackValue(key: key)
#else
        if let value = try keychainStorage.retrieve(key: key) {
            return value
        }
        return nil
#endif
    }

    func remove(key: String) throws {
        if isPKCECodeVerifierKey(key) {
            UserDefaults.standard.removeObject(forKey: key)
            return
        }

#if DEBUG && targetEnvironment(simulator)
        removeSimulatorFallback(key: key)
        try? keychainStorage.remove(key: key)
#else
        try keychainStorage.remove(key: key)
#endif
    }

    private func isPKCECodeVerifierKey(_ key: String) -> Bool {
        key.hasSuffix("-code-verifier")
    }

#if DEBUG && targetEnvironment(simulator)
    private func storeSimulatorFallback(key: String, value: Data) {
        UserDefaults.standard.set(value, forKey: simulatorFallbackKey(key))
        UserDefaults.standard.synchronize()
    }

    private func simulatorFallbackValue(key: String) -> Data? {
        UserDefaults.standard.data(forKey: simulatorFallbackKey(key))
    }

    private func removeSimulatorFallback(key: String) {
        UserDefaults.standard.removeObject(forKey: simulatorFallbackKey(key))
        UserDefaults.standard.synchronize()
    }

    private func simulatorFallbackKey(_ key: String) -> String {
        "debug.simulator.\(key)"
    }

    private func shouldUseSimulatorFallbackOnly() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        return isEnabled(environment["TASK115_IOS_SIMULATOR_AUTH_FALLBACK"])
            || isEnabled(environment["TEST_RUNNER_TASK115_IOS_SIMULATOR_AUTH_FALLBACK"])
    }

    private func isEnabled(_ value: String?) -> Bool {
        guard let normalized = value?.lowercased() else { return false }
        return normalized == "1" || normalized == "true"
    }
#endif
}
