import XCTest
@testable import iOSMerchandiseControl

final class SupabaseConfigSecurityTests: XCTestCase {
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
}
