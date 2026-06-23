import Combine
import Foundation
import Supabase

nonisolated struct LinkedShop: Identifiable, Codable, Equatable, Sendable {
    let shopID: UUID
    let code: String?
    let name: String
    let role: String
    let status: String
    let selectable: Bool
    let canWrite: Bool

    var id: UUID { shopID }

    init(
        shopID: UUID,
        code: String?,
        name: String,
        role: String,
        status: String,
        selectable: Bool,
        canWrite: Bool
    ) {
        self.shopID = shopID
        self.code = Self.normalizedOptional(code)
        self.name = Self.normalized(name).isEmpty
            ? Self.normalizedOptional(code) ?? shopID.uuidString.lowercased()
            : Self.normalized(name)
        self.role = Self.normalized(role).isEmpty ? "member" : Self.normalized(role)
        self.status = Self.normalized(status).isEmpty ? "active" : Self.normalized(status)
        self.selectable = selectable
        self.canWrite = canWrite
    }

    var isValidSelection: Bool {
        selectable && !Self.blockedStatuses.contains(status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
    }

    private static let blockedStatuses: Set<String> = [
        "blocked",
        "deleted",
        "disabled",
        "inactive",
        "revoked",
        "suspended"
    ]

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = normalized(value)
        return trimmed.isEmpty ? nil : trimmed
    }
}

nonisolated struct SelectedShop: Codable, Equatable, Sendable {
    let shopID: UUID
    let code: String?
    let name: String
    let role: String
    let status: String
    let selectable: Bool
    let canWrite: Bool
    let selectedAt: Date

    init(
        shopID: UUID,
        code: String?,
        name: String,
        role: String,
        status: String,
        selectable: Bool,
        canWrite: Bool,
        selectedAt: Date = Date()
    ) {
        self.shopID = shopID
        self.code = code
        self.name = name
        self.role = role
        self.status = status
        self.selectable = selectable
        self.canWrite = canWrite
        self.selectedAt = selectedAt
    }

    init(linkedShop: LinkedShop, selectedAt: Date = Date()) {
        self.init(
            shopID: linkedShop.shopID,
            code: linkedShop.code,
            name: linkedShop.name,
            role: linkedShop.role,
            status: linkedShop.status,
            selectable: linkedShop.selectable,
            canWrite: linkedShop.canWrite,
            selectedAt: selectedAt
        )
    }

    var localStoreIdentity: LocalStoreIdentity {
        LocalStoreIdentity(rawValue: shopID.uuidString.lowercased())
    }
}

nonisolated struct ShopContext: Equatable, Sendable {
    let accountHash: String?
    let linkedShops: [LinkedShop]
    let selectedShop: SelectedShop?
    let syncAllowed: Bool
    let errorMessage: String?

    static let legacy = ShopContext(accountHash: nil, linkedShops: [], selectedShop: nil)

    init(
        accountHash: String?,
        linkedShops: [LinkedShop],
        selectedShop: SelectedShop?,
        syncAllowed: Bool = true,
        errorMessage: String? = nil
    ) {
        self.accountHash = accountHash
        self.linkedShops = linkedShops
        self.selectedShop = selectedShop
        self.syncAllowed = syncAllowed
        self.errorMessage = errorMessage
    }

    var activeShopID: UUID? {
        selectedShop?.shopID
    }

    var validLinkedShops: [LinkedShop] {
        linkedShops.filter(\.isValidSelection)
    }

    var isLegacy: Bool {
        selectedShop == nil
    }

    var localStoreIdentity: LocalStoreIdentity {
        selectedShop?.localStoreIdentity ?? .anonymous
    }

    func blocked(message: String?) -> ShopContext {
        ShopContext(
            accountHash: accountHash,
            linkedShops: linkedShops,
            selectedShop: selectedShop,
            syncAllowed: false,
            errorMessage: message
        )
    }

    static func blocked(accountHash: String, message: String?) -> ShopContext {
        ShopContext(
            accountHash: accountHash,
            linkedShops: [],
            selectedShop: nil,
            syncAllowed: false,
            errorMessage: message
        )
    }
}

nonisolated struct ShopContextResolution: Equatable, Sendable {
    let context: ShopContext
    let selectedShopToPersist: SelectedShop?
}

nonisolated enum ShopContextResolver {
    static func resolve(
        accountHash: String,
        linkedShops: [LinkedShop],
        persistedSelection: SelectedShop?,
        now: Date = Date()
    ) -> ShopContextResolution {
        let normalizedLinkedShops = linkedShops.sorted { lhs, rhs in
            let left = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
            if left != .orderedSame { return left == .orderedAscending }
            return lhs.shopID.uuidString < rhs.shopID.uuidString
        }
        let selectable = normalizedLinkedShops.filter(\.isValidSelection)
        guard !selectable.isEmpty else {
            return ShopContextResolution(
                context: ShopContext(accountHash: accountHash, linkedShops: normalizedLinkedShops, selectedShop: nil),
                selectedShopToPersist: nil
            )
        }

        let selectedLinkedShop: LinkedShop
        if let persistedSelection,
           let restored = selectable.first(where: { $0.shopID == persistedSelection.shopID }) {
            selectedLinkedShop = restored
        } else if selectable.count == 1 {
            selectedLinkedShop = selectable[0]
        } else {
            selectedLinkedShop = selectable[0]
        }

        let selected = SelectedShop(linkedShop: selectedLinkedShop, selectedAt: now)
        return ShopContextResolution(
            context: ShopContext(accountHash: accountHash, linkedShops: normalizedLinkedShops, selectedShop: selected),
            selectedShopToPersist: selected
        )
    }
}

nonisolated struct InventoryHomeShopContextPresentation: Equatable, Sendable {
    let shopName: String?
    let showsSwitcher: Bool
    let activeShopID: UUID?

    static func make(context: ShopContext) -> InventoryHomeShopContextPresentation {
        guard let selectedShop = context.selectedShop else {
            return InventoryHomeShopContextPresentation(shopName: nil, showsSwitcher: false, activeShopID: nil)
        }
        return InventoryHomeShopContextPresentation(
            shopName: selectedShop.name,
            showsSwitcher: context.validLinkedShops.count > 1,
            activeShopID: selectedShop.shopID
        )
    }
}

nonisolated final class SelectedShopStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let keyPrefix: String
    private let activeAccountKey: String

    init(
        defaults: UserDefaults = .standard,
        keyPrefix: String = "mobile.shopContext.selected.v1",
        activeAccountKey: String = "mobile.shopContext.activeAccountHash.v1"
    ) {
        self.defaults = defaults
        self.keyPrefix = keyPrefix
        self.activeAccountKey = activeAccountKey
    }

    func noteActiveAccount(_ accountHash: String?) {
        let previous = defaults.string(forKey: activeAccountKey)
        guard previous != accountHash else { return }
        if let accountHash {
            defaults.set(accountHash, forKey: activeAccountKey)
        } else {
            defaults.removeObject(forKey: activeAccountKey)
        }
    }

    func selectedShop(accountHash: String) -> SelectedShop? {
        guard let data = defaults.data(forKey: key(accountHash: accountHash)) else { return nil }
        return try? JSONDecoder().decode(SelectedShop.self, from: data)
    }

    func save(_ selectedShop: SelectedShop, accountHash: String) {
        guard let data = try? JSONEncoder().encode(selectedShop) else { return }
        defaults.set(data, forKey: key(accountHash: accountHash))
    }

    func clear(accountHash: String) {
        defaults.removeObject(forKey: key(accountHash: accountHash))
    }

    func selectedShopID(ownerUserID: UUID) -> UUID? {
        selectedShop(accountHash: AccountBindingStore.accountHash(for: ownerUserID))?.shopID
    }

    func selectedShopID(ownerUserIDString: String) -> UUID? {
        guard let ownerUserID = UUID(uuidString: ownerUserIDString) else { return nil }
        return selectedShopID(ownerUserID: ownerUserID)
    }

    func localStoreIdentity(ownerUserID: UUID) -> LocalStoreIdentity {
        selectedShop(accountHash: AccountBindingStore.accountHash(for: ownerUserID))?.localStoreIdentity ?? .anonymous
    }

    func localStoreIdentity(ownerUserIDString: String) -> LocalStoreIdentity {
        guard let ownerUserID = UUID(uuidString: ownerUserIDString) else { return .anonymous }
        return localStoreIdentity(ownerUserID: ownerUserID)
    }

    private func key(accountHash: String) -> String {
        "\(keyPrefix).account.\(accountHash)"
    }
}

nonisolated enum ShopContextSelection {
    static func selectedShopID(ownerUserID: UUID, defaults: UserDefaults = .standard) -> UUID? {
        SelectedShopStore(defaults: defaults).selectedShopID(ownerUserID: ownerUserID)
    }

    static func selectedShopID(ownerUserIDString: String, defaults: UserDefaults = .standard) -> UUID? {
        SelectedShopStore(defaults: defaults).selectedShopID(ownerUserIDString: ownerUserIDString)
    }

    static func localStoreIdentity(ownerUserID: UUID, defaults: UserDefaults = .standard) -> LocalStoreIdentity {
        SelectedShopStore(defaults: defaults).localStoreIdentity(ownerUserID: ownerUserID)
    }

    static func localStoreIdentity(ownerUserIDString: String, defaults: UserDefaults = .standard) -> LocalStoreIdentity {
        SelectedShopStore(defaults: defaults).localStoreIdentity(ownerUserIDString: ownerUserIDString)
    }
}

protocol LinkedShopFetching: Sendable {
    func fetchLinkedShops() async throws -> [LinkedShop]
}

nonisolated struct EmptyLinkedShopFetcher: LinkedShopFetching {
    func fetchLinkedShops() async throws -> [LinkedShop] {
        []
    }
}

actor MobileLinkedShopService: LinkedShopFetching {
    private let remote: SupabaseTransportClient

    init(remote: SupabaseTransportClient) {
        self.remote = remote
    }

    func fetchLinkedShops() async throws -> [LinkedShop] {
        _ = try await remote.authenticatedUserID()
        let client = await remote.client()
        do {
            let response = try await client
                .rpc("mobile_linked_shops")
                .execute()
            return try MobileLinkedShopRPCDecoder.decode(response.data)
        } catch let error as DecodingError {
            throw await remote.mapDecodingError(error)
        } catch let error as PostgrestError {
            throw await remote.mapPostgrestError(error)
        } catch let error as URLError {
            throw await remote.networkError(error)
        } catch {
            throw SupabaseTransportClientError.unknown(message: String(describing: error))
        }
    }
}

nonisolated enum MobileLinkedShopRPCDecoder {
    enum DecodeError: Error, Equatable {
        case rpcFailed(code: String)
    }

    static func decode(_ data: Data, decoder: JSONDecoder = JSONDecoder()) throws -> [LinkedShop] {
        do {
            let response = try decoder.decode(MobileLinkedShopRPCResponse.self, from: data)
            guard response.ok else { throw DecodeError.rpcFailed(code: response.code) }
            return response.shops.map(\.linkedShop)
        } catch let responseError as DecodingError {
            do {
                return try decoder.decode([MobileLinkedShopRPCRow].self, from: data).map(\.linkedShop)
            } catch {
                throw responseError
            }
        }
    }
}

nonisolated private struct MobileLinkedShopRPCResponse: Decodable, Sendable {
    let ok: Bool
    let code: String
    let shops: [MobileLinkedShopRPCRow]

    enum CodingKeys: String, CodingKey {
        case ok
        case code
        case shops
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ok = try container.decodeIfPresent(Bool.self, forKey: .ok) ?? false
        code = try container.decodeIfPresent(String.self, forKey: .code) ?? "unknown"
        shops = try container.decodeIfPresent([MobileLinkedShopRPCRow].self, forKey: .shops) ?? []
    }
}

nonisolated private struct MobileLinkedShopRPCRow: Decodable, Sendable {
    let linkedShop: LinkedShop

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        let shopID = try container.decodeUUID(aliases: ["shop_id", "shopID", "id"])
        let code = container.decodeOptionalString(aliases: ["code", "shop_code", "shopCode"])
        let name = container.decodeOptionalString(aliases: ["name", "shop_name", "shopName", "display_name"])
            ?? code
            ?? shopID.uuidString.lowercased()
        let role = container.decodeOptionalString(aliases: ["role", "member_role", "access_role"]) ?? "member"
        let status = container.decodeOptionalString(aliases: ["status", "shop_status", "mapping_state"]) ?? "active"
        let selectable = container.decodeOptionalBool(aliases: ["selectable", "can_select", "canSelect"])
            ?? !["revoked", "suspended", "disabled", "inactive"].contains(status.lowercased())
        let canWrite = container.decodeOptionalBool(aliases: ["can_write", "canWrite", "write_enabled"])
            ?? ["owner", "admin", "manager", "editor"].contains(role.lowercased())
        linkedShop = LinkedShop(
            shopID: shopID,
            code: code,
            name: name,
            role: role,
            status: status,
            selectable: selectable,
            canWrite: canWrite
        )
    }
}

nonisolated private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = "\(intValue)"
        self.intValue = intValue
    }
}

private extension KeyedDecodingContainer where Key == DynamicCodingKey {
    nonisolated func decodeUUID(aliases: [String]) throws -> UUID {
        for alias in aliases {
            guard let key = DynamicCodingKey(stringValue: alias),
                  contains(key) else { continue }
            if let uuid = try? decode(UUID.self, forKey: key) {
                return uuid
            }
            if let string = try? decode(String.self, forKey: key),
               let uuid = UUID(uuidString: string.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return uuid
            }
        }
        throw DecodingError.keyNotFound(
            DynamicCodingKey(stringValue: aliases.first ?? "shop_id")!,
            DecodingError.Context(codingPath: codingPath, debugDescription: "Missing shop id.")
        )
    }

    nonisolated func decodeOptionalString(aliases: [String]) -> String? {
        for alias in aliases {
            guard let key = DynamicCodingKey(stringValue: alias),
                  contains(key),
                  let value = try? decodeIfPresent(String.self, forKey: key) else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    nonisolated func decodeOptionalBool(aliases: [String]) -> Bool? {
        for alias in aliases {
            guard let key = DynamicCodingKey(stringValue: alias), contains(key) else { continue }
            if let value = try? decodeIfPresent(Bool.self, forKey: key) {
                return value
            }
            if let value = try? decodeIfPresent(Int.self, forKey: key) {
                return value != 0
            }
            if let value = try? decodeIfPresent(String.self, forKey: key) {
                switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                case "1", "true", "yes", "y":
                    return true
                case "0", "false", "no", "n":
                    return false
                default:
                    break
                }
            }
        }
        return nil
    }
}

@MainActor
final class ShopContextStore: ObservableObject {
    @Published private(set) var context: ShopContext

    private let fetcher: any LinkedShopFetching
    private let selectedStore: SelectedShopStore
    private let accountBindingStore: AccountBindingStore
    private let now: () -> Date

    init(
        fetcher: any LinkedShopFetching = EmptyLinkedShopFetcher(),
        selectedStore: SelectedShopStore = SelectedShopStore(),
        accountBindingStore: AccountBindingStore = AccountBindingStore(),
        now: @escaping () -> Date = Date.init
    ) {
        self.fetcher = fetcher
        self.selectedStore = selectedStore
        self.accountBindingStore = accountBindingStore
        self.now = now
        self.context = .legacy
    }

    func refresh(ownerUserID: UUID?) async {
        guard let ownerUserID else {
            selectedStore.noteActiveAccount(nil)
            context = .legacy
            return
        }

        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        selectedStore.noteActiveAccount(accountHash)

        do {
            let linkedShops = try await fetcher.fetchLinkedShops()
            let resolution = ShopContextResolver.resolve(
                accountHash: accountHash,
                linkedShops: linkedShops,
                persistedSelection: selectedStore.selectedShop(accountHash: accountHash),
                now: now()
            )
            if let selectedShop = resolution.selectedShopToPersist {
                selectedStore.save(selectedShop, accountHash: accountHash)
            } else {
                selectedStore.clear(accountHash: accountHash)
            }
            accountBindingStore.saveBinding(
                accountHash: accountHash,
                storeIdentity: resolution.context.localStoreIdentity
            )
            context = resolution.context
        } catch {
            if context.accountHash == accountHash {
                context = context.blocked(message: error.localizedDescription)
            } else {
                context = .blocked(accountHash: accountHash, message: error.localizedDescription)
                accountBindingStore.clearBinding()
            }
        }
    }

    func selectShop(_ shopID: UUID, ownerUserID: UUID?) {
        guard let ownerUserID,
              let linkedShop = context.linkedShops.first(where: { $0.shopID == shopID && $0.isValidSelection }) else {
            return
        }
        let accountHash = AccountBindingStore.accountHash(for: ownerUserID)
        let selected = SelectedShop(linkedShop: linkedShop, selectedAt: now())
        selectedStore.save(selected, accountHash: accountHash)
        accountBindingStore.saveBinding(accountHash: accountHash, storeIdentity: selected.localStoreIdentity)
        context = ShopContext(accountHash: accountHash, linkedShops: context.linkedShops, selectedShop: selected)
    }

    func selectShop(_ shopID: UUID) {
        guard let accountHash = context.accountHash,
              let linkedShop = context.linkedShops.first(where: { $0.shopID == shopID && $0.isValidSelection }) else {
            return
        }
        let selected = SelectedShop(linkedShop: linkedShop, selectedAt: now())
        selectedStore.save(selected, accountHash: accountHash)
        accountBindingStore.saveBinding(accountHash: accountHash, storeIdentity: selected.localStoreIdentity)
        context = ShopContext(accountHash: accountHash, linkedShops: context.linkedShops, selectedShop: selected)
    }
}
