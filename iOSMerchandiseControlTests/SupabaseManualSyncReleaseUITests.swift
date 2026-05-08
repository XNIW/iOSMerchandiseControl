import XCTest

final class SupabaseManualSyncReleaseUITests: XCTestCase {
    private let supportedLanguages = ["it", "en", "es", "zh-Hans"]

    func testTask067ManualSyncReleaseLocalizationKeysExistInSupportedLanguages() throws {
        let keys = [
            "options.supabase.manualSync.header",
            "options.supabase.manualSync.footer",
            "options.supabase.manualSync.state.idle.title",
            "options.supabase.manualSync.state.idle.subtitle",
            "options.supabase.manualSync.state.running.title",
            "options.supabase.manualSync.state.running.subtitle",
            "options.supabase.manualSync.state.running.inline",
            "options.supabase.manualSync.state.success.title",
            "options.supabase.manualSync.state.success.subtitle",
            "options.supabase.manualSync.state.partial.title",
            "options.supabase.manualSync.state.partial.subtitle",
            "options.supabase.manualSync.state.auth.title",
            "options.supabase.manualSync.state.auth.subtitle",
            "options.supabase.manualSync.state.realign.title",
            "options.supabase.manualSync.state.realign.subtitle",
            "options.supabase.manualSync.state.connectivity.title",
            "options.supabase.manualSync.state.connectivity.subtitle",
            "options.supabase.manualSync.state.cancelled.title",
            "options.supabase.manualSync.state.cancelled.subtitle",
            "options.supabase.manualSync.state.technical.title",
            "options.supabase.manualSync.state.technical.subtitle",
            "options.supabase.manualSync.state.busy.title",
            "options.supabase.manualSync.state.busy.subtitle",
            "options.supabase.manualSync.state.unavailable.title",
            "options.supabase.manualSync.state.unavailable.subtitle",
            "options.supabase.manualSync.action.check",
            "options.supabase.manualSync.action.checkAgain",
            "options.supabase.manualSync.action.tryAgain",
            "options.supabase.manualSync.action.signIn",
            "options.supabase.manualSync.action.running",
            "options.supabase.manualSync.accessibility.primaryAction",
            "options.supabase.manualSync.disabled.authChanging",
            "options.supabase.manualSync.disabled.accessUnavailable"
        ]

        for language in supportedLanguages {
            let strings = try loadStrings(language: language)
            for key in keys {
                XCTAssertNotNil(strings[key], "\(key) missing in \(language)")
                XCTAssertFalse(strings[key]?.isEmpty ?? true, "\(key) empty in \(language)")
            }
        }
    }

    func testTask067ManualSyncReleaseCopyAvoidsForbiddenJargon() throws {
        let forbiddenTerms = [
            "outbox",
            "drain",
            "sync_events",
            "rpc",
            "payload",
            "retryable",
            "uuid",
            "json",
            "record_sync_event",
        ]

        for language in supportedLanguages {
            let strings = try loadStrings(language: language)
            let releaseValues = strings
                .filter { $0.key.hasPrefix("options.supabase.manualSync.") }
                .map(\.value)

            XCTAssertFalse(releaseValues.isEmpty, "No manual sync release values for \(language)")

            for value in releaseValues {
                let normalized = value.lowercased()
                for term in forbiddenTerms {
                    XCTAssertFalse(
                        normalized.contains(term),
                        "\(language) Release copy contains forbidden term \(term): \(value)"
                    )
                }
            }
        }
    }

    func testTask067OptionsViewDoesNotUseSupabaseClientDirectly() throws {
        let source = try readSource("iOSMerchandiseControl/OptionsView.swift")

        XCTAssertFalse(source.contains("SupabaseClient"))
        XCTAssertFalse(source.contains(".rpc"))
    }

    func testTask067ManualSyncReleaseSourcesAvoidForbiddenScope() throws {
        let optionsViewSource = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let releaseCardSource = try extractReleaseCardSource(from: optionsViewSource)
        let factorySource = try readSource("iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift")
        let viewModelSource = try readSource("iOSMerchandiseControl/SupabaseManualSyncViewModel.swift")
        let combined = [releaseCardSource, factorySource, viewModelSource].joined(separator: "\n")

        for forbidden in ["BGTask", "Timer", "Realtime", "worker", ".channel", "SupabaseClient", ".rpc", ".from", ".upsert", "TASK-068"] {
            XCTAssertFalse(combined.contains(forbidden), "Forbidden release scope term found: \(forbidden)")
        }
    }

    func testTask069ReleaseFactoryUsesLocalPendingSnapshotProvider() throws {
        let factorySource = try readSource("iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift")

        XCTAssertTrue(factorySource.contains("SupabaseManualSyncLocalPendingSnapshotProvider"))
        XCTAssertTrue(factorySource.contains("SupabaseManualSyncCatalogPendingAdapter"))
        XCTAssertTrue(factorySource.contains("SupabaseManualSyncOutboxPendingAdapter"))
        XCTAssertFalse(factorySource.contains("SupabaseManualSyncReleasePendingSnapshotProvider"))
    }

    func testTask069ReadOnlyReleaseSourcesAvoidForbiddenLiveCalls() throws {
        let optionsViewSource = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let releaseCardSource = try extractReleaseCardSource(from: optionsViewSource)
        let paths = [
            "iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift",
            "iOSMerchandiseControl/SupabaseManualSyncLocalPendingSnapshotProvider.swift",
            "iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift",
            "iOSMerchandiseControl/SupabaseManualSyncViewModel.swift",
        ]
        let combined = try ([releaseCardSource] + paths.map(readSource))
            .joined(separator: "\n")

        for forbidden in [
            "SupabaseClient",
            ".rpc",
            ".from",
            ".upsert",
            ".insert",
            ".update",
            ".delete",
            "record_sync_event",
            "drainOnce",
            "SyncEventOutboxDrainService",
            "SyncEventOutboxEnqueueService",
            "SupabaseManualPushService",
            "SupabaseProductPriceManualPushService",
            "SupabasePullApplyService",
            "SupabaseCatalogBaselineWriter",
            "confirmationDialog",
            "BGTask",
            "Timer",
            "Realtime",
            "worker",
        ] {
            XCTAssertFalse(combined.contains(forbidden), "Forbidden TASK-069 source term found: \(forbidden)")
        }
    }

    func testTask067ReleaseCardSourceAvoidsDeveloperJargon() throws {
        let source = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let releaseCardSource = try extractReleaseCardSource(from: source)

        for forbidden in ["outbox", "drain", "sync_events", "RPC", "payload", "retryable", "UUID", "JSON", "record_sync_event"] {
            XCTAssertFalse(releaseCardSource.localizedCaseInsensitiveContains(forbidden))
        }
    }

    func testTask067DebugOutboxCardRemainsDebugOnlyAndSeparateFromReleaseCard() throws {
        let source = try readSource("iOSMerchandiseControl/OptionsView.swift")
        let releaseCardRange = try XCTUnwrap(source.range(of: "private struct SupabaseManualSyncReleaseCard"))
        let debugCardRange = try XCTUnwrap(source.range(of: "#if DEBUG\nprivate struct SyncEventOutboxDrainDebugCard"))

        XCTAssertLessThan(releaseCardRange.lowerBound, debugCardRange.lowerBound)
    }

    private func extractReleaseCardSource(from source: String) throws -> String {
        let start = try XCTUnwrap(source.range(of: "private struct SupabaseManualSyncReleaseCard"))
        let end = try XCTUnwrap(source.range(of: "// MARK: - Header di sezione"))
        XCTAssertLessThan(start.lowerBound, end.lowerBound)
        return String(source[start.lowerBound..<end.lowerBound])
    }

    private func readSource(_ relativePath: String) throws -> String {
        let url = repoRoot().appendingPathComponent(relativePath)
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func loadStrings(language: String) throws -> [String: String] {
        let url = repoRoot()
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

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
