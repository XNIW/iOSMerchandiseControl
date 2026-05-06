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

    func testTask043BaselineLocalizationKeysExistInSupportedLanguages() throws {
        let keys = [
            "options.supabase.baseline.header",
            "options.supabase.baseline.status.label",
            "options.supabase.baseline.status.absent",
            "options.supabase.baseline.status.valid",
            "options.supabase.baseline.status.stale",
            "options.supabase.baseline.status.accountMismatch",
            "options.supabase.baseline.status.incomplete",
            "options.supabase.baseline.lastPull",
            "options.supabase.baseline.account",
            "options.supabase.baseline.counts.products",
            "options.supabase.baseline.counts.suppliers",
            "options.supabase.baseline.counts.categories",
            "options.supabase.baseline.schemaVersion",
            "options.supabase.baseline.tombstones",
            "options.supabase.baseline.footer",
            "options.supabase.baseline.commit.success",
            "options.supabase.baseline.commit.failed",
            "options.supabase.pushpreflight.category.blockedStaleOrPartialBaseline"
        ]

        for language in ["it", "en", "es", "zh-Hans"] {
            let strings = try loadStrings(language: language)
            for key in keys {
                XCTAssertNotNil(strings[key], "\(key) missing in \(language)")
                XCTAssertFalse(strings[key]?.isEmpty ?? true, "\(key) empty in \(language)")
            }
        }
    }

    func testTask044ManualPushLocalizationKeysExistInSupportedLanguages() throws {
        let keys = [
            "options.supabase.pushpreflight.category.dryRunLinkCandidate",
            "options.supabase.manualpush.button",
            "options.supabase.manualpush.accessibility",
            "options.supabase.manualpush.copy.remoteWriteOnlyAfterConfirm",
            "options.supabase.manualpush.copy.noProductPrice",
            "options.supabase.manualpush.copy.noRemoteDelete",
            "options.supabase.manualpush.copy.noAutomaticSync",
            "options.supabase.manualpush.confirm.title",
            "options.supabase.manualpush.confirm.write",
            "options.supabase.manualpush.confirm.suppliers",
            "options.supabase.manualpush.confirm.categories",
            "options.supabase.manualpush.confirm.products",
            "options.supabase.manualpush.confirm.writes",
            "options.supabase.manualpush.confirm.noProductPrice",
            "options.supabase.manualpush.confirm.noDelete",
            "options.supabase.manualpush.confirm.noAutoSync",
            "options.supabase.manualpush.state.completed",
            "options.supabase.manualpush.state.completedBaselineRefreshFailed",
            "options.supabase.manualpush.state.partial",
            "options.supabase.manualpush.state.failedBeforeWrite",
            "options.supabase.manualpush.state.blockedBeforeWrite",
            "options.supabase.manualpush.result.suppliers",
            "options.supabase.manualpush.result.categories",
            "options.supabase.manualpush.result.products",
            "options.supabase.manualpush.result.counts",
            "options.supabase.manualpush.result.details",
            "options.supabase.manualpush.action.completed",
            "options.supabase.manualpush.action.completedBaselineRefreshFailed",
            "options.supabase.manualpush.action.partial",
            "options.supabase.manualpush.action.failedBeforeWrite",
            "options.supabase.manualpush.action.blockedBeforeWrite"
        ]

        for language in ["it", "en", "es", "zh-Hans"] {
            let strings = try loadStrings(language: language)
            for key in keys {
                XCTAssertNotNil(strings[key], "\(key) missing in \(language)")
                XCTAssertFalse(strings[key]?.isEmpty ?? true, "\(key) empty in \(language)")
            }
        }
    }

    func testTask047ScopedPushPreflightLocalizationKeysExistInSupportedLanguages() throws {
        let keys = [
            "options.supabase.pushpreflight.run.scopedTask045",
            "options.supabase.pushpreflight.scope.label",
            "options.supabase.pushpreflight.scope.global",
            "options.supabase.pushpreflight.scope.task045",
            "options.supabase.pushpreflight.state.completedScopedSafe",
            "options.supabase.pushpreflight.state.completedScopedBlocked",
            "options.supabase.pushpreflight.copy.scopedTask045",
            "options.supabase.pushpreflight.metric.scopeIncluded",
            "options.supabase.pushpreflight.metric.scopeExcluded",
            "options.supabase.pushpreflight.metric.scopeBlockedDependencies",
            "options.supabase.pushpreflight.category.blockedOutsideScope",
            "options.supabase.pushpreflight.category.blockedScopedDependency"
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
