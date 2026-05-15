import Foundation
import Supabase

nonisolated enum SupabaseOAuthRedirect {
    static let scheme = "com.niwcyber.iosmerchandisecontrol"
    static let url = URL(string: "\(scheme)://login-callback")!
}

final class SupabaseClientProvider: @unchecked Sendable {
    let config: SupabaseConfig
    let redirectURL: URL
    let client: SupabaseClient

    init(config: SupabaseConfig, redirectURL: URL = SupabaseOAuthRedirect.url) {
        self.config = config
        self.redirectURL = redirectURL
        self.client = SupabaseClient(
            supabaseURL: config.projectURL,
            supabaseKey: config.publishableKey,
            options: SupabaseClientOptions(
                auth: .init(
                    storage: SupabaseAuthLocalStorage(),
                    redirectToURL: redirectURL,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }
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
#endif
}
