import CryptoKit
import Foundation

nonisolated final class AccountBindingStore {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "sync.accountBinding.v1"
    ) {
        self.defaults = defaults
        self.key = key
    }

    var currentBinding: AccountBinding? {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(AccountBinding.self, from: data)
    }

    func saveBinding(
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        boundAt: Date = Date()
    ) {
        let binding = AccountBinding(
            accountHash: accountHash,
            storeIdentity: storeIdentity,
            boundAt: boundAt
        )
        guard let data = try? JSONEncoder().encode(binding) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    func clearBinding() {
        defaults.removeObject(forKey: key)
    }

    static func accountHash(for userID: UUID) -> String {
        redactedAccountHash(for: userID.uuidString.lowercased())
    }

    static func redactedAccountHash(for value: String) -> String {
        let canonical = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let digest = SHA256.hash(data: Data(canonical.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
