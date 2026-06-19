import Foundation
import OSLog
import Supabase

nonisolated final class DeviceInstallIDStore: @unchecked Sendable {
    private static let key = "shop.device.install.id"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var deviceInstallID: String {
        if let existing = defaults.string(forKey: Self.key),
           !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return existing
        }

        let generated = UUID().uuidString.lowercased()
        defaults.set(generated, forKey: Self.key)
        return generated
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
    private var lastStatusSnapshot: ShopDeviceAuthorizationSnapshot?
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
        if !force, let lastRegistrationAt, Date().timeIntervalSince(lastRegistrationAt) < 60 {
            return true
        }

        guard clientProvider.client.auth.currentSession?.isExpired == false else {
            logger.info(
                "shop_device_register_current_owner skipped reason=\(Self.safeLogText(reason), privacy: .public) session=missing_or_expired"
            )
            return false
        }

        do {
            let params = ShopDeviceRegistrationDeviceInfo.rpcParameters(
                deviceInstallID: installIDStore.deviceInstallID,
                reason: reason
            )
            logger.info(
                "shop_device_register_current_owner started reason=\(Self.safeLogText(reason), privacy: .public) device=\(Self.redactedIdentifier(params.pDeviceIdentifier), privacy: .public) app_version_present=\((params.pAppVersion != nil), privacy: .public)"
            )

            let response = try await clientProvider.client
                .rpc("shop_device_register_current_owner", params: params)
                .execute()

            let result = try JSONDecoder().decode(ShopDeviceRegistrationRPCResult.self, from: response.data)
            guard result.ok == true else {
                logger.error(
                    "shop_device_register_current_owner failed app_code=\(Self.safeLogText(result.code ?? "unknown"), privacy: .public) shop=\(Self.redactedIdentifier(result.shopID), privacy: .public)"
                )
                return false
            }

            lastRegistrationAt = Date()
            logger.info(
                "shop_device_register_current_owner succeeded app_code=\(Self.safeLogText(result.code ?? "success"), privacy: .public) shop=\(Self.redactedIdentifier(result.shopID), privacy: .public) target=\(Self.redactedIdentifier(result.targetID), privacy: .public)"
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
        if !force,
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
            let params = ShopDeviceStatusRPCParameters(
                pDeviceIdentifier: installIDStore.deviceInstallID
            )
            let response = try await clientProvider.client
                .rpc("shop_device_status_current_owner", params: params)
                .execute()
            let result = try JSONDecoder().decode(ShopDeviceStatusRPCResult.self, from: response.data)
            let snapshot = result.snapshot(checkedAt: now)
            lastStatusSnapshot = snapshot
            logger.info(
                "shop_device_status_current_owner result reason=\(Self.safeLogText(reason), privacy: .public) status=\(Self.safeLogText(snapshot.status), privacy: .public) code=\(Self.safeLogText(snapshot.code), privacy: .public) can_write=\(snapshot.canWrite, privacy: .public)"
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
