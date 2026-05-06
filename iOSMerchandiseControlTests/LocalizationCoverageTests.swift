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

    func testTask048ProductPricePreviewLocalizationKeysExistInSupportedLanguages() throws {
        let keys = [
            "common.yes",
            "common.no",
            "options.supabase.pricePreview.title",
            "options.supabase.pricePreview.badge.readOnly",
            "options.supabase.pricePreview.subtitle",
            "options.supabase.pricePreview.button.load",
            "options.supabase.pricePreview.button.refresh",
            "options.supabase.pricePreview.loading",
            "options.supabase.pricePreview.success",
            "options.supabase.pricePreview.capped",
            "options.supabase.pricePreview.empty",
            "options.supabase.pricePreview.incomplete",
            "options.supabase.pricePreview.cancelled",
            "options.supabase.pricePreview.metric.rowsFetched",
            "options.supabase.pricePreview.metric.pagesFetched",
            "options.supabase.pricePreview.metric.samplesShown",
            "options.supabase.pricePreview.metric.orphans",
            "options.supabase.pricePreview.metric.invalidTypes",
            "options.supabase.pricePreview.metric.invalidDates",
            "options.supabase.pricePreview.metric.capped",
            "options.supabase.pricePreview.metric.stopReason",
            "options.supabase.pricePreview.details",
            "options.supabase.pricePreview.stop.pageEmpty",
            "options.supabase.pricePreview.stop.partialPage",
            "options.supabase.pricePreview.stop.maxRows",
            "options.supabase.pricePreview.stop.maxPages",
            "options.supabase.pricePreview.stop.error",
            "options.supabase.pricePreview.stop.cancelled",
            "options.supabase.pricePreview.samples.empty",
            "options.supabase.pricePreview.type.purchase",
            "options.supabase.pricePreview.type.retail",
            "options.supabase.pricePreview.badge.orphan",
            "options.supabase.pricePreview.product.orphan",
            "options.supabase.pricePreview.effectiveAt",
            "options.supabase.pricePreview.effectiveAtWithCanonical"
        ]

        for language in ["it", "en", "es", "zh-Hans"] {
            let strings = try loadStrings(language: language)
            for key in keys {
                XCTAssertNotNil(strings[key], "\(key) missing in \(language)")
                XCTAssertFalse(strings[key]?.isEmpty ?? true, "\(key) empty in \(language)")
            }
        }
    }

    func testTask048ProductPricePreviewCopyAvoidsWriteLanguage() throws {
        let forbiddenByLanguage = [
            "it": ["sincron", "applica", "salva", "push", "merge", "import"],
            "en": ["sync", "apply", "save", "push", "merge", "import"],
            "es": ["sincron", "aplicar", "guardar", "push", "merge", "import"],
            "zh-Hans": ["同步", "应用", "保存", "推送", "合并", "导入"]
        ]

        for (language, forbiddenTerms) in forbiddenByLanguage {
            let strings = try loadStrings(language: language)
            let previewValues = strings
                .filter { $0.key.hasPrefix("options.supabase.pricePreview.") }
                .map(\.value)

            for value in previewValues {
                let normalized = value.lowercased()
                for term in forbiddenTerms {
                    XCTAssertFalse(
                        normalized.contains(term),
                        "\(language) price preview copy contains forbidden term \(term): \(value)"
                    )
                }
            }
        }
    }

    func testTask049ProductPriceApplyLocalizationKeysExistInSupportedLanguages() throws {
        let keys = [
            "options.supabase.priceApply.title",
            "options.supabase.priceApply.badge.debug",
            "options.supabase.priceApply.badge.localOnly",
            "options.supabase.priceApply.badge.noCloudWrite",
            "options.supabase.priceApply.subtitle",
            "options.supabase.priceApply.copy.insertOnly",
            "options.supabase.priceApply.copy.noCurrentPriceUpdate",
            "options.supabase.priceApply.button.apply",
            "options.supabase.priceApply.button.dryRun",
            "options.supabase.priceApply.status.idle",
            "options.supabase.priceApply.loading",
            "options.supabase.priceApply.applying",
            "options.supabase.priceApply.status.ready",
            "options.supabase.priceApply.status.blocked",
            "options.supabase.priceApply.status.noApplicableRows",
            "options.supabase.priceApply.status.applied",
            "options.supabase.priceApply.metric.remoteRead",
            "options.supabase.priceApply.metric.toInsert",
            "options.supabase.priceApply.metric.skippedExisting",
            "options.supabase.priceApply.metric.unmapped",
            "options.supabase.priceApply.metric.invalid",
            "options.supabase.priceApply.metric.conflicts",
            "options.supabase.priceApply.metric.mappingConflicts",
            "options.supabase.priceApply.metric.partial",
            "options.supabase.priceApply.metric.truncated",
            "options.supabase.priceApply.metric.blockReasons",
            "options.supabase.priceApply.metric.issues",
            "options.supabase.priceApply.block.partial",
            "options.supabase.priceApply.block.truncated",
            "options.supabase.priceApply.block.sourceError",
            "options.supabase.priceApply.block.unmappedProducts",
            "options.supabase.priceApply.block.invalidRows",
            "options.supabase.priceApply.block.conflicts",
            "options.supabase.priceApply.block.sessionMismatch",
            "options.supabase.priceApply.block.noApplicableRows",
            "options.supabase.priceApply.issue.unmappedProduct",
            "options.supabase.priceApply.issue.invalidType",
            "options.supabase.priceApply.issue.invalidPrice",
            "options.supabase.priceApply.issue.invalidEffectiveAt",
            "options.supabase.priceApply.issue.mappingConflict",
            "options.supabase.priceApply.issue.priceConflict",
            "options.supabase.priceApply.issue.duplicateRemoteLogicalRow",
            "options.supabase.priceApply.issue.sourceError",
            "options.supabase.priceApply.error.fetcherMissing",
            "options.supabase.priceApply.error.sessionMissing",
            "options.supabase.priceApply.error.sessionMismatch",
            "options.supabase.priceApply.error.policyBlocked",
            "options.supabase.priceApply.error.localSnapshot",
            "options.supabase.priceApply.error.saveFailed",
            "options.supabase.priceApply.error.verificationFailed",
            "options.supabase.priceApply.error.unknown",
            "options.supabase.priceApply.confirm.title",
            "options.supabase.priceApply.confirm.apply",
            "options.supabase.priceApply.confirm.message",
            "options.supabase.priceApply.result.counts"
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
