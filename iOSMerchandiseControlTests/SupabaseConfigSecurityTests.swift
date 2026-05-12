import XCTest
import CryptoKit
@testable import iOSMerchandiseControl

final class SupabaseConfigSecurityTests: XCTestCase {
    @MainActor
    func testTask103IOSAuthPreflightWhenEnabled() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["TASK103_IOS_AUTH_PREFLIGHT"] == "1",
            "TASK-103 live auth preflight is gated."
        )

        let config = try SupabaseConfig.load(bundle: .main)
        XCTAssertFalse(config.publishableKey.lowercased().contains("service_role"))
        XCTAssertFalse(config.publishableKey.lowercased().contains("secret_key"))

        let authService = SupabaseAuthService(provider: SupabaseClientProvider(config: config))
        try await Task.sleep(nanoseconds: 2_000_000_000)

        guard let session = authService.currentSession, !session.isExpired else {
            XCTFail("TASK-103 iOS auth preflight requires an existing non-expired device session.")
            return
        }

        print(
            "TASK103_IOS_AUTH_PREFLIGHT project_hash=\(task103Hash(config.projectURL.absoluteString)) " +
            "owner_hash=\(task103Hash(session.userID.uuidString.lowercased())) " +
            "provider=\(session.provider ?? "unknown") signed_in=true"
        )
    }

    func testAuthSessionInfoPrivacySafeDisplayRedactsAccountIdentifiers() {
        let sessionInfo = SupabaseAuthSessionInfo(
            userID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            email: "user@example.test",
            provider: "google",
            isExpired: false
        )

        XCTAssertEqual(sessionInfo.privacySafeUserID, "00000000-redacted")
        XCTAssertEqual(sessionInfo.privacySafeDisplayEmail, "u***@example.test")
        XCTAssertFalse(sessionInfo.privacySafeDisplayEmail?.contains("user@example.test") ?? true)
    }

    func testRejectsLegacyServiceRoleJWTButAllowsAnonJWTShape() throws {
        let anonKey = makeJWT(role: "anon")
        let anonConfig = try SupabaseConfig.load(bundle: makeConfigBundle(publishableKey: anonKey))
        XCTAssertEqual(anonConfig.publishableKey, anonKey)

        let serviceRoleKey = makeJWT(role: ["service", "role"].joined(separator: "_"))
        XCTAssertThrowsError(
            try SupabaseConfig.load(bundle: makeConfigBundle(publishableKey: serviceRoleKey))
        ) { error in
            guard case SupabaseConfigError.invalidConfig = error else {
                return XCTFail("Expected invalidConfig, got \(error)")
            }
        }
    }

    private func makeConfigBundle(publishableKey: String) throws -> Bundle {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("bundle")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: bundleURL)
        }

        let config: [String: String] = [
            "SUPABASE_PROJECT_URL": "https://example.supabase.co",
            "SUPABASE_PUBLISHABLE_KEY": publishableKey
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: config,
            format: .xml,
            options: 0
        )
        try data.write(to: bundleURL.appendingPathComponent("SupabaseConfig.plist"))

        guard let bundle = Bundle(url: bundleURL) else {
            throw NSError(domain: "SupabaseConfigSecurityTests", code: 1)
        }
        return bundle
    }

    private func makeJWT(role: String) -> String {
        let header = base64URLString(["alg": "HS256", "typ": "JWT"])
        let payload = base64URLString(["iss": "supabase", "role": role])
        return "\(header).\(payload).signature"
    }

    private func base64URLString(_ object: [String: String]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func task103Hash(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
            .prefix(12)
            .description
    }
}
