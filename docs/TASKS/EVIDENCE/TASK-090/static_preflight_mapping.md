# TASK-090 static preflight and mapping

Timestamp locale: 2026-05-09 17:03 -0400

## Repo

- Branch: `main`.
- Commit: `8264c96`.
- Xcode project: `iOSMerchandiseControl.xcodeproj`.
- Scheme: `iOSMerchandiseControl`.
- Targets: `iOSMerchandiseControl`, `iOSMerchandiseControlTests`.
- Configurations: Debug, Release.

## iOS files mapped

| Area | Files |
|------|-------|
| Manual sync Release UI | `iOSMerchandiseControl/OptionsView.swift` |
| Manual sync orchestration | `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncCoordinator.swift`, `SupabaseManualSyncCoordinatorModels.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabaseManualSyncRemotePreview.swift`, `SupabaseManualSyncLocalPendingSnapshotProvider.swift` |
| Catalog pull/apply | `SupabasePullPreviewService.swift`, `SupabasePullPreviewModels.swift`, `SupabasePullApplyService.swift` |
| Catalog push/preflight | `SupabaseManualPushService.swift`, `SupabaseManualPushPreflightService.swift`, `SupabaseManualPushPreflightModels.swift` |
| ProductPrice | `SupabaseProductPriceApplyService.swift`, `SupabaseProductPricePreviewService.swift`, `SupabaseProductPricePushDryRunService.swift`, `SupabaseProductPriceManualPushService.swift`, `Models.swift` |
| Export/import | `DatabaseView.swift`, `InventoryXLSXExporter.swift`, `ExcelAnalyzer.swift`, `ProductImportCore.swift`, `ImportAnalysisView.swift`, `Task089SyntheticBenchmarkHarness.swift` |
| Localization | `it.lproj`, `en.lproj`, `es.lproj`, `zh-Hans.lproj` `Localizable.strings` |
| Tests | `SupabaseManualSync*Tests.swift`, `SupabaseProductPrice*Tests.swift`, `SupabasePull*Tests.swift`, `SupabaseManualPush*Tests.swift`, `Task089LargeDatasetBenchmarkTests.swift`, `LocalizationCoverageTests.swift` |

## Read-only findings

- Release manual sync is explicit/manual: primary actions are check, review, update this device, send changes to cloud, register activity, retry/cancel.
- Apply/push are behind review/confirmation flows and use running state/progress UI.
- ProductPrice push uses snapshot fingerprint, deterministic row IDs, read-back verification, and local `remoteID` reconciliation only after verified success.
- ProductPrice apply fails closed on session mismatch, source partial/truncated/error, unmapped products, invalid rows, duplicate logical remote rows, and local price conflicts.
- Database export has separate products/full DB paths; full DB includes `Products`, `Suppliers`, `Categories`, and `PriceHistory` sheets.
- Full import copies security-scoped files to a temporary cache, prepares/analyzes before apply, shows progress/cancel, and records ProductPrice history rows separately.
