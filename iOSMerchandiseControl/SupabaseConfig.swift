import Foundation
import Supabase

nonisolated enum SupabaseConfigError: Error, Sendable {
    case configMissing
    case invalidConfig
}

nonisolated struct SupabaseConfig: Sendable {
    private static let fileName = "SupabaseConfig"
    private static let projectURLKey = "SUPABASE_PROJECT_URL"
    private static let publishableKeyKey = "SUPABASE_PUBLISHABLE_KEY"

    let projectURL: URL
    let publishableKey: String

    static func load(bundle: Bundle = .main) throws -> SupabaseConfig {
        guard let configURL = bundle.url(forResource: fileName, withExtension: "plist") else {
            throw SupabaseConfigError.configMissing
        }

        let data: Data
        do {
            data = try Data(contentsOf: configURL)
        } catch {
            throw SupabaseConfigError.invalidConfig
        }

        let plist: Any
        do {
            plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        } catch {
            throw SupabaseConfigError.invalidConfig
        }

        guard let values = plist as? [String: Any],
              let projectURLString = normalizedString(values[projectURLKey]),
              let publishableKey = normalizedString(values[publishableKeyKey]),
              !isPlaceholder(projectURLString),
              !isPlaceholder(publishableKey),
              !isServerOnlyKey(publishableKey),
              let projectURL = URL(string: projectURLString),
              projectURL.scheme?.lowercased() == "https",
              projectURL.host != nil else {
            throw SupabaseConfigError.invalidConfig
        }

        return SupabaseConfig(projectURL: projectURL, publishableKey: publishableKey)
    }

    func makeClient() -> SupabaseClient {
        SupabaseClient(supabaseURL: projectURL, supabaseKey: publishableKey)
    }

    private static func normalizedString(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isPlaceholder(_ value: String) -> Bool {
        value.uppercased().hasPrefix("YOUR_")
    }

    private static func isServerOnlyKey(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        return lowercased.hasPrefix("sb_secret_")
            || lowercased.contains("service_role")
            || lowercased.contains("secret_key")
    }
}
