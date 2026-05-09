# TASK-090 static UI/copy audit

Timestamp locale: 2026-05-09 17:03 -0400

## Scope

Files reviewed:

- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`

## Findings

| Check | Evidence | Result |
|-------|----------|--------|
| Manual, user-controlled sync copy | Footer says cloud sync remains manual/under user control; push footer says only shown local changes are sent and no automatic sending starts | PASS_CANDIDATE |
| No broad "everything synced" claim | Existing tests grep for forbidden strings like `fully synced`, `tutto sincronizzato`, `todo sincronizado`, `全部同步`; user-facing copy uses "completed", "no action required", "local data updated", "changes sent" with scoped meaning | PASS_CANDIDATE |
| CTA specificity | CTAs include check cloud, review, update this device, send changes to cloud, retry, cancel | PASS_CANDIDATE |
| Review before mutation | `OptionsView` presents sheet/alerts before local apply, send, and activity registration | PASS_CANDIDATE |
| Progress/recovery | Running state uses `ProgressView`; cancel/retry states exist in ViewModel/UI | PASS_CANDIDATE |
| Localization coverage | `options.supabase.manualSync.*` count is 222 in each of it/en/es/zh-Hans | PASS_CANDIDATE |

## Notes

- No new localized string was necessary for TASK-090.
- No Swift UI patch was applied.
- Static grep also finds existing unrelated automatic local features (autosave/backfill) outside manual Supabase sync; no new automatic/background sync was introduced by TASK-090.
