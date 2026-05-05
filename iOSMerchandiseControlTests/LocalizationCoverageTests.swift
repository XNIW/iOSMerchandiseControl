import XCTest

final class LocalizationCoverageTests: XCTestCase {
    func testTask040NewLocalizationKeysExistInSupportedLanguages() throws {
        let keys = [
            "options.supabase.preview.cloud.header",
            "options.supabase.preview.identity.header",
            "options.supabase.preview.metric.remoteSuppliers",
            "options.supabase.preview.metric.remoteCategories",
            "options.supabase.preview.metric.linkedProducts",
            "options.supabase.preview.metric.linkedSuppliers",
            "options.supabase.preview.metric.linkedCategories",
            "options.supabase.preview.conflict.remoteIdConflict",
            "options.supabase.preview.conflict.missingRemoteReference",
            "options.supabase.apply.disabled.accountMismatch"
        ]

        for language in ["it", "en", "es", "zh-Hans"] {
            let strings = try loadStrings(language: language)
            for key in keys {
                XCTAssertNotNil(strings[key], "\(key) missing in \(language)")
                XCTAssertFalse(strings[key]?.isEmpty ?? true, "\(key) empty in \(language)")
            }
        }
    }

    private func loadStrings(language: String) throws -> [String: String] {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = testsDirectory
            .appendingPathComponent("iOSMerchandiseControl")
            .appendingPathComponent("\(language).lproj")
            .appendingPathComponent("Localizable.strings")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        return try XCTUnwrap(plist as? [String: String])
    }
}
