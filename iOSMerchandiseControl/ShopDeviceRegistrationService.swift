import CryptoKit
import Foundation
import OSLog
import Supabase
#if canImport(Darwin)
import Darwin
@_silgen_name("flock")
private nonisolated func mcSystemFlock(_ descriptor: Int32, _ operation: Int32) -> Int32
#endif

nonisolated enum DeviceInstallIDStoreError: Error, Sendable, Equatable {
    case durableStorageUnavailable
    case invalidDurableIdentity
}

nonisolated final class DeviceInstallIDStore: @unchecked Sendable {
    private struct DurableIdentity: Codable, Equatable {
        static let schemaVersion = "device-install-identity-v1"

        let schemaVersion: String
        let deviceIdentifier: String
        let checksum: String
    }

    private static let key = "shop.device.install.id"
    private static let lock = NSLock()
    private static let maximumIdentityBytes = 4 * 1_024
    private let defaults: UserDefaults
    private let durableURL: URL?

    init(
        defaults: UserDefaults = .standard,
        durableURL: URL? = nil
    ) {
        self.defaults = defaults
        self.durableURL = durableURL?.standardizedFileURL
            ?? (defaults === UserDefaults.standard ? Self.defaultDurableURL() : nil)
    }

    var deviceInstallID: String {
        if let durable = try? requireDeviceInstallID() {
            return durable
        }
        // Non-sync diagnostics and legacy call sites cannot throw. The
        // process-wide lock still guarantees one identity for this process;
        // every owner/shop admission path uses the throwing API below and
        // therefore fails closed if durable storage is unavailable.
        Self.lock.lock()
        defer { Self.lock.unlock() }
        if let existing = Self.validIdentity(defaults.string(forKey: Self.key)) {
            return existing
        }
        let fallback = UUID().uuidString.lowercased()
        defaults.set(fallback, forKey: Self.key)
        return fallback
    }

    func requireDeviceInstallID() throws -> String {
        Self.lock.lock()
        defer { Self.lock.unlock() }

        let fileLock = try durableURL.map(Self.acquireFileLock(for:))
        defer { Self.releaseFileLock(fileLock) }

        let defaultsIdentity = Self.validIdentity(defaults.string(forKey: Self.key))
        if let durableURL,
           FileManager.default.fileExists(atPath: durableURL.path) {
            let data = try Self.boundedData(at: durableURL)
            guard let record = try? JSONDecoder().decode(DurableIdentity.self, from: data),
                  record.schemaVersion == DurableIdentity.schemaVersion,
                  let durableIdentity = Self.validIdentity(record.deviceIdentifier),
                  record.checksum == Self.checksum(for: durableIdentity) else {
                throw DeviceInstallIDStoreError.invalidDurableIdentity
            }
            if defaultsIdentity != durableIdentity {
                defaults.set(durableIdentity, forKey: Self.key)
            }
            return durableIdentity
        }

        if defaultsIdentity == nil,
           durableURL != nil,
           Self.existingSyncStateRequiresIdentityRecovery() {
            throw DeviceInstallIDStoreError.invalidDurableIdentity
        }
        let identity = defaultsIdentity ?? UUID().uuidString.lowercased()
        if let durableURL {
            try Self.persist(identity, to: durableURL)
        }
        defaults.set(identity, forKey: Self.key)
        return identity
    }

    private static func validIdentity(_ raw: String?) -> String? {
        guard let raw else { return nil }
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              raw.utf8.count <= 160,
              !raw.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            return nil
        }
        return raw
    }

    static func identityHash(for raw: String) -> String {
        let canonical = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return SHA256.hash(data: Data(canonical.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func checksum(for identity: String) -> String {
        let material = [DurableIdentity.schemaVersion, identity]
            .map { "\($0.utf8.count):\($0)" }
            .joined(separator: "\u{001F}")
        return SHA256.hash(data: Data(material.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func boundedData(at url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true,
              let size = values.fileSize,
              size > 0,
              size <= maximumIdentityBytes else {
            throw DeviceInstallIDStoreError.invalidDurableIdentity
        }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard data.count == size else {
            throw DeviceInstallIDStoreError.invalidDurableIdentity
        }
        return data
    }

    private static func persist(_ identity: String, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let record = DurableIdentity(
                schemaVersion: DurableIdentity.schemaVersion,
                deviceIdentifier: identity,
                checksum: checksum(for: identity)
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(record)
            guard data.count <= maximumIdentityBytes else {
                throw DeviceInstallIDStoreError.invalidDurableIdentity
            }
            try data.write(to: url, options: [.atomic])
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
            try synchronizeFile(url)
            try synchronizeDirectory(directory)
            guard try boundedData(at: url) == data else {
                throw DeviceInstallIDStoreError.durableStorageUnavailable
            }
        } catch {
            throw DeviceInstallIDStoreError.durableStorageUnavailable
        }
    }

    private static func defaultDurableURL() -> URL? {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent("DeviceIdentity", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("install-id", isDirectory: false)
    }

    private static func existingSyncStateRequiresIdentityRecovery() -> Bool {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return true }
        let base = applicationSupport
            .appendingPathComponent("SyncStoreGenerations", isDirectory: true)
            .appendingPathComponent("v1", isDirectory: true)
        return ["active-generation.json", "recovery-journal.json"]
            .contains { FileManager.default.fileExists(atPath: base.appendingPathComponent($0).path) }
    }

    private static func acquireFileLock(for durableURL: URL) throws -> Int32 {
        #if canImport(Darwin)
        let lockURL = durableURL.appendingPathExtension("lock")
        try FileManager.default.createDirectory(
            at: lockURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let descriptor = Darwin.open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0, mcSystemFlock(descriptor, LOCK_EX) == 0 else {
            if descriptor >= 0 { _ = Darwin.close(descriptor) }
            throw DeviceInstallIDStoreError.durableStorageUnavailable
        }
        return descriptor
        #else
        return -1
        #endif
    }

    private static func releaseFileLock(_ descriptor: Int32?) {
        #if canImport(Darwin)
        guard let descriptor, descriptor >= 0 else { return }
        _ = mcSystemFlock(descriptor, LOCK_UN)
        _ = Darwin.close(descriptor)
        #endif
    }

    private static func synchronizeFile(_ url: URL) throws {
        #if canImport(Darwin)
        let descriptor = Darwin.open(url.path, O_RDONLY)
        guard descriptor >= 0 else { throw DeviceInstallIDStoreError.durableStorageUnavailable }
        defer { _ = Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0 else {
            throw DeviceInstallIDStoreError.durableStorageUnavailable
        }
        #else
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        try handle.synchronize()
        #endif
    }

    private static func synchronizeDirectory(_ url: URL) throws {
        #if canImport(Darwin)
        let descriptor = Darwin.open(url.path, O_RDONLY)
        guard descriptor >= 0 else { throw DeviceInstallIDStoreError.durableStorageUnavailable }
        defer { _ = Darwin.close(descriptor) }
        guard Darwin.fsync(descriptor) == 0 else {
            throw DeviceInstallIDStoreError.durableStorageUnavailable
        }
        #endif
    }
}

protocol ShopDeviceAuthorizationChecking: Sendable {
    @discardableResult
    func registerCurrentOwnerDevice(reason: String, force: Bool) async -> Bool
    @discardableResult
    func registerHeartbeatAndCheck(reason: String) async -> ShopDeviceAuthorizationSnapshot
    func currentOwnerDeviceStatus(reason: String, force: Bool) async -> ShopDeviceAuthorizationSnapshot
    func ensureActiveForCloudWrite(reason: String) async throws -> ShopDeviceAuthorizationSnapshot
}

actor ShopDeviceRegistrationService: ShopDeviceAuthorizationChecking {
    private let clientProvider: SupabaseClientProvider
    private let installIDStore: DeviceInstallIDStore
    private let logger = Logger(
        subsystem: "com.niwcyber.iOSMerchandiseControl",
        category: "ShopDeviceRegistrationService"
    )
    private var lastRegistrationAt: Date?
    private var lastRegistrationScope: String?
    private var lastStatusSnapshot: ShopDeviceAuthorizationSnapshot?
    private var lastStatusScope: String?
    private let statusCacheTTL: TimeInterval = 15

    init(
        clientProvider: SupabaseClientProvider,
        installIDStore: DeviceInstallIDStore = DeviceInstallIDStore()
    ) {
        self.clientProvider = clientProvider
        self.installIDStore = installIDStore
    }

    @discardableResult
    func registerCurrentOwnerDevice(reason: String, force: Bool = false) async -> Bool {
        guard let session = clientProvider.client.auth.currentSession,
              session.isExpired == false else {
            logger.info(
                "shop_device_register_current_owner skipped reason=\(Self.safeLogText(reason), privacy: .public) session=missing_or_expired"
            )
            return false
        }
        let selectedShopID = ShopContextSelection.selectedShopID(ownerUserID: session.user.id)
        let registrationScope = authorizationScope(shopID: selectedShopID)
        if !force,
           lastRegistrationScope == registrationScope,
           let lastRegistrationAt,
           Date().timeIntervalSince(lastRegistrationAt) < 60 {
            return true
        }

        do {
            let deviceInstallID = try installIDStore.requireDeviceInstallID()
            let params = ShopDeviceRegistrationDeviceInfo.rpcParameters(
                deviceInstallID: deviceInstallID,
                reason: reason
            )
            let rpcName = selectedShopID == nil
                ? "shop_device_register_current_owner"
                : "shop_device_register_for_shop"
            logger.info(
                "\(Self.safeLogText(rpcName), privacy: .public) started reason=\(Self.safeLogText(reason), privacy: .public) scope=\(Self.safeLogText(registrationScope), privacy: .public) device=\(Self.redactedIdentifier(params.pDeviceIdentifier), privacy: .public) app_version_present=\((params.pAppVersion != nil), privacy: .public)"
            )

            let responseData: Data
            if let selectedShopID {
                responseData = try await clientProvider.client
                    .rpc(
                        "shop_device_register_for_shop",
                        params: ShopDeviceRegistrationForShopRPCParameters(
                            shopID: selectedShopID,
                            device: params
                        )
                    )
                    .execute()
                    .data
            } else {
                responseData = try await clientProvider.client
                    .rpc("shop_device_register_current_owner", params: params)
                    .execute()
                    .data
            }

            let result = try JSONDecoder().decode(ShopDeviceRegistrationRPCResult.self, from: responseData)
            guard result.ok == true else {
                logger.error(
                    "\(Self.safeLogText(rpcName), privacy: .public) failed app_code=\(Self.safeLogText(result.code ?? "unknown"), privacy: .public) shop=\(Self.redactedIdentifier(result.shopID), privacy: .public)"
                )
                return false
            }

            lastRegistrationAt = Date()
            lastRegistrationScope = registrationScope
            logger.info(
                "\(Self.safeLogText(rpcName), privacy: .public) succeeded app_code=\(Self.safeLogText(result.code ?? "success"), privacy: .public) shop=\(Self.redactedIdentifier(result.shopID), privacy: .public) target=\(Self.redactedIdentifier(result.targetID), privacy: .public)"
            )
            return true
        } catch is CancellationError {
            logger.info("shop_device_register_current_owner cancelled")
            return false
        } catch let error as DecodingError {
            logger.error(
                "shop_device_register_current_owner failed app_code=decode_failed error_kind=\(Self.decodingErrorKind(error), privacy: .public)"
            )
            return false
        } catch let error as PostgrestError {
            logger.error(
                "shop_device_register_current_owner failed postgrest_code=\(Self.safeLogText(String(describing: error.code)), privacy: .public)"
            )
            return false
        } catch let error as URLError {
            logger.error(
                "shop_device_register_current_owner failed url_code=\(error.code.rawValue, privacy: .public)"
            )
            return false
        } catch {
            logger.error(
                "shop_device_register_current_owner failed error_type=\(Self.safeLogText(String(reflecting: type(of: error))), privacy: .public)"
            )
            return false
        }
    }

    @discardableResult
    func registerHeartbeatAndCheck(reason: String) async -> ShopDeviceAuthorizationSnapshot {
        _ = await registerCurrentOwnerDevice(reason: reason, force: false)
        return await currentOwnerDeviceStatus(reason: reason, force: true)
    }

    func currentOwnerDeviceStatus(reason: String, force: Bool = false) async -> ShopDeviceAuthorizationSnapshot {
        let now = Date()
        let selectedShopID = currentSelectedShopID()
        let statusScope = authorizationScope(shopID: selectedShopID)
        if !force,
           lastStatusScope == statusScope,
           let lastStatusSnapshot,
           now.timeIntervalSince(lastStatusSnapshot.checkedAt) < statusCacheTTL {
            return lastStatusSnapshot
        }

        guard clientProvider.client.auth.currentSession?.isExpired == false else {
            let snapshot = ShopDeviceAuthorizationSnapshot(
                status: "unauthorized",
                code: "unauthorized",
                canWrite: false,
                serverTime: nil,
                lastSeenAt: lastStatusSnapshot?.lastSeenAt,
                reasonCode: "unauthorized",
                recommendedAction: "sign_in",
                checkedAt: now
            )
            lastStatusSnapshot = snapshot
            return snapshot
        }

        do {
            let deviceInstallID = try installIDStore.requireDeviceInstallID()
            let params = ShopDeviceStatusRPCParameters(
                pDeviceIdentifier: deviceInstallID
            )
            let rpcName = selectedShopID == nil
                ? "shop_device_status_current_owner"
                : "shop_device_status_for_shop"
            let responseData: Data
            if let selectedShopID {
                responseData = try await clientProvider.client
                    .rpc(
                        "shop_device_status_for_shop",
                        params: ShopDeviceStatusForShopRPCParameters(
                            shopID: selectedShopID,
                            deviceIdentifier: deviceInstallID
                        )
                    )
                    .execute()
                    .data
            } else {
                responseData = try await clientProvider.client
                    .rpc("shop_device_status_current_owner", params: params)
                    .execute()
                    .data
            }
            let result = try JSONDecoder().decode(ShopDeviceStatusRPCResult.self, from: responseData)
            let snapshot = result.snapshot(checkedAt: now)
            lastStatusSnapshot = snapshot
            lastStatusScope = statusScope
            logger.info(
                "\(Self.safeLogText(rpcName), privacy: .public) result reason=\(Self.safeLogText(reason), privacy: .public) scope=\(Self.safeLogText(statusScope), privacy: .public) status=\(Self.safeLogText(snapshot.status), privacy: .public) code=\(Self.safeLogText(snapshot.code), privacy: .public) can_write=\(snapshot.canWrite, privacy: .public)"
            )
            return snapshot
        } catch {
            let snapshot = networkErrorSnapshot(error: error, checkedAt: now)
            logger.error(
                "shop_device_status_current_owner failed reason=\(Self.safeLogText(reason), privacy: .public) status=network_error code=\(Self.safeLogText(snapshot.code), privacy: .public)"
            )
            return snapshot
        }
    }

    func ensureActiveForCloudWrite(reason: String) async throws -> ShopDeviceAuthorizationSnapshot {
        let snapshot = await currentOwnerDeviceStatus(reason: reason, force: true)
        guard snapshot.status == "active", snapshot.canWrite else {
            throw ShopDeviceAuthorizationBlockedError(snapshot: snapshot)
        }
        return snapshot
    }

    private func currentSelectedShopID() -> UUID? {
        guard let session = clientProvider.client.auth.currentSession,
              session.isExpired == false else {
            return nil
        }
        return ShopContextSelection.selectedShopID(ownerUserID: session.user.id)
    }

    private func authorizationScope(shopID: UUID?) -> String {
        shopID?.uuidString.lowercased() ?? "legacy"
    }

    private func networkErrorSnapshot(error: Error, checkedAt: Date) -> ShopDeviceAuthorizationSnapshot {
        let code: String
        if let urlError = error as? URLError {
            code = "url_\(urlError.code.rawValue)"
        } else if let postgrestError = error as? PostgrestError {
            code = "postgrest_\(Self.safeLogText(String(describing: postgrestError.code)))"
        } else {
            code = Self.safeLogText(String(reflecting: type(of: error)))
        }

        return ShopDeviceAuthorizationSnapshot(
            status: "network_error",
            code: code.isEmpty ? "network_error" : code,
            canWrite: false,
            serverTime: nil,
            lastSeenAt: lastStatusSnapshot?.lastSeenAt,
            reasonCode: "network_error",
            recommendedAction: "retry_when_online",
            checkedAt: checkedAt
        )
    }

    private nonisolated static func redactedIdentifier(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "nil" }
        if value.count <= 12 {
            return value
        }
        return "\(value.prefix(8))...\(value.suffix(4))"
    }

    private nonisolated static func safeLogText(_ value: String) -> String {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._:-")
        return String(value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
            .prefix(80)
            .description
    }

    private nonisolated static func decodingErrorKind(_ error: DecodingError) -> String {
        switch error {
        case .dataCorrupted:
            return "data_corrupted"
        case .keyNotFound:
            return "key_not_found"
        case .typeMismatch:
            return "type_mismatch"
        case .valueNotFound:
            return "value_not_found"
        @unknown default:
            return "unknown"
        }
    }
}

nonisolated struct ShopDeviceRegistrationRPCResult: Decodable {
    let ok: Bool?
    let code: String?
    let shopID: String?
    let targetID: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case code
        case shopID = "shop_id"
        case targetID = "target_id"
    }
}

nonisolated struct ShopDeviceStatusRPCParameters: Encodable {
    let pDeviceIdentifier: String

    enum CodingKeys: String, CodingKey {
        case pDeviceIdentifier = "p_device_identifier"
    }
}

nonisolated struct ShopDeviceStatusForShopRPCParameters: Encodable {
    let pShopID: UUID
    let pDeviceIdentifier: String

    init(shopID: UUID, deviceIdentifier: String) {
        self.pShopID = shopID
        self.pDeviceIdentifier = deviceIdentifier
    }

    enum CodingKeys: String, CodingKey {
        case pShopID = "p_shop_id"
        case pDeviceIdentifier = "p_device_identifier"
    }
}

nonisolated struct ShopDeviceStatusRPCResult: Decodable {
    let ok: Bool?
    let code: String?
    let status: String?
    let canWrite: Bool?
    let serverTime: String?
    let lastSeenAt: String?
    let reasonCode: String?
    let recommendedAction: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case code
        case status
        case canWrite = "can_write"
        case serverTime = "server_time"
        case lastSeenAt = "last_seen_at"
        case reasonCode = "reason_code"
        case recommendedAction = "recommended_action"
    }

    func snapshot(checkedAt: Date) -> ShopDeviceAuthorizationSnapshot {
        let normalizedStatus = status?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCode = code?.trimmingCharacters(in: .whitespacesAndNewlines)
        return ShopDeviceAuthorizationSnapshot(
            status: normalizedStatus?.isEmpty == false ? normalizedStatus! : (normalizedCode ?? "unknown"),
            code: normalizedCode?.isEmpty == false ? normalizedCode! : "unknown",
            canWrite: (canWrite ?? false) && status == "active",
            serverTime: serverTime,
            lastSeenAt: lastSeenAt,
            reasonCode: reasonCode ?? normalizedCode ?? "unknown",
            recommendedAction: recommendedAction ?? "contact_shop_admin",
            checkedAt: checkedAt
        )
    }
}

nonisolated struct ShopDeviceAuthorizationSnapshot: Equatable, Sendable {
    let status: String
    let code: String
    let canWrite: Bool
    let serverTime: String?
    let lastSeenAt: String?
    let reasonCode: String
    let recommendedAction: String
    let checkedAt: Date
}

nonisolated struct ShopDeviceAuthorizationBlockedError: LocalizedError, Equatable, Sendable {
    let snapshot: ShopDeviceAuthorizationSnapshot

    var errorDescription: String? {
        "Device access blocked. Contact a shop admin."
    }
}

nonisolated enum ShopDeviceRegistrationDeviceInfo {
    static func rpcParameters(
        deviceInstallID: String,
        reason: String
    ) -> ShopDeviceRegistrationRPCParameters {
        ShopDeviceRegistrationRPCParameters(
            pDeviceIdentifier: deviceInstallID,
            pDeviceType: "mobile",
            pDisplayName: displayName,
            pAppVersion: appVersion,
            pMetadata: metadata(reason: reason)
        )
    }

    private static var displayName: String {
        let model = machineModel()
        if model.isEmpty {
            return "iOS device"
        }
        return "iOS \(model)"
    }

    private static var appVersion: String? {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let trimmedVersion = version?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBuild = build?.trimmingCharacters(in: .whitespacesAndNewlines)

        switch (trimmedVersion?.isEmpty == false ? trimmedVersion : nil, trimmedBuild?.isEmpty == false ? trimmedBuild : nil) {
        case (.some(let version), .some(let build)):
            return "\(version) (\(build))"
        case (.some(let version), nil):
            return version
        case (nil, .some(let build)):
            return build
        case (nil, nil):
            return nil
        }
    }

    private static func metadata(reason: String) -> ShopDeviceRegistrationMetadata {
        ShopDeviceRegistrationMetadata(
            platform: "ios",
            model: machineModel().isEmpty ? "unknown" : machineModel(),
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            appVersionPresent: appVersion != nil,
            simulator: isSimulator,
            reason: reason
        )
    }

    private static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    private static func machineModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(String(UnicodeScalar(UInt8(value))))
        }
        return identifier
    }
}

nonisolated struct ShopDeviceRegistrationRPCParameters: Encodable {
    let pDeviceIdentifier: String
    let pDeviceType: String
    let pDisplayName: String
    let pAppVersion: String?
    let pMetadata: ShopDeviceRegistrationMetadata

    enum CodingKeys: String, CodingKey {
        case pDeviceIdentifier = "p_device_identifier"
        case pDeviceType = "p_device_type"
        case pDisplayName = "p_display_name"
        case pAppVersion = "p_app_version"
        case pMetadata = "p_metadata"
    }
}

nonisolated struct ShopDeviceRegistrationForShopRPCParameters: Encodable {
    let pShopID: UUID
    let pDeviceIdentifier: String
    let pDeviceType: String
    let pDisplayName: String
    let pAppVersion: String?
    let pMetadata: ShopDeviceRegistrationMetadata

    init(shopID: UUID, device: ShopDeviceRegistrationRPCParameters) {
        self.pShopID = shopID
        self.pDeviceIdentifier = device.pDeviceIdentifier
        self.pDeviceType = device.pDeviceType
        self.pDisplayName = device.pDisplayName
        self.pAppVersion = device.pAppVersion
        self.pMetadata = device.pMetadata
    }

    enum CodingKeys: String, CodingKey {
        case pShopID = "p_shop_id"
        case pDeviceIdentifier = "p_device_identifier"
        case pDeviceType = "p_device_type"
        case pDisplayName = "p_display_name"
        case pAppVersion = "p_app_version"
        case pMetadata = "p_metadata"
    }
}

nonisolated struct ShopDeviceRegistrationMetadata: Encodable {
    let platform: String
    let model: String
    let osVersion: String
    let appVersionPresent: Bool
    let simulator: Bool
    let reason: String

    enum CodingKeys: String, CodingKey {
        case platform
        case model
        case osVersion = "os_version"
        case appVersionPresent = "app_version_present"
        case simulator
        case reason
    }
}
