import Foundation

struct LocalStoreIdentity: RawRepresentable, Codable, Equatable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isEmpty: Bool {
        rawValue.isEmpty
    }

    static let anonymous = LocalStoreIdentity(rawValue: "anonymous")
}

struct AccountBinding: Codable, Equatable, Sendable {
    var accountHash: String
    var storeIdentity: LocalStoreIdentity
    var boundAt: Date

    init(
        accountHash: String,
        storeIdentity: LocalStoreIdentity,
        boundAt: Date = Date()
    ) {
        self.accountHash = accountHash
        self.storeIdentity = storeIdentity
        self.boundAt = boundAt
    }
}
