# TASK-108 Evidence 52 - Performance preflight repo state

Timestamp: 2026-05-14 13:23 -0400  
Scope: final REVIEW+FIX mirato memory/performance sync iOS + Android.

## Repo state

| Repo | Command | Result |
|---|---|---|
| iOS `/Users/minxiang/Desktop/iOSMerchandiseControl` | `git fetch origin --prune` | Eseguito |
| iOS | `git status --short --branch` | `## main...origin/main`; poi modifiche locali Codex su TASK-108 |
| iOS | `git log -1 --oneline` | `74480c2 Task 108.1` |
| iOS | `git rev-list --left-right --count HEAD...origin/main` | `0 0` |
| Android `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView` | `git fetch origin --prune` | Eseguito |
| Android | `git status --short --branch` | `## main...origin/main`; poi modifiche locali Codex su TASK-108 |
| Android | `git log -1 --oneline` | `7cfc536 iOS task 108` |
| Android | `git rev-list --left-right --count HEAD...origin/main` | `0 0` |

## Files read before edits

- iOS master: `docs/MASTER-PLAN.md`
- iOS task: `docs/TASKS/TASK-108-supabase-sync-unification-ios.md`
- Android master: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/docs/MASTER-PLAN.md`
- Evidence read: `30-large-price-history-bootstrap.md`, `32-mainactor-performance-sync-audit.md`, `40-ios-live-bootstrap-timing.md`, `47-ios-android-performance-final.md`, `48-large-dataset-performance-final.md`, `51-keyset-productprice-debug.md`
- iOS code read: `SupabaseProductPriceApplyService.swift`, `SupabaseProductPricePreviewService.swift`, `SupabaseInventoryService.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncBaselineCommitter.swift`, `OptionsView.swift`, ProductPrice/keyset/baseline tests.
- Android code read: `InventoryRepository.kt`, `CatalogSyncViewModel.kt`, `CloudSyncIndicator`, ProductPrice DAO/remote data source, sync events/outbox paths, History/session sync, Options local database status.

## Device/env inventory

- iOS simulators available: iOS 26.1, 26.2, 26.4, 26.5 families. Used for tests/build/launch: iPhone 17 Pro iOS 26.5, UDID `240F400E-5EFA-486A-9137-FFBBE70F604D`.
- iOS physical device: `iPhone di Min` iOS 26.5 listed offline by Xcode; not usable for smoke.
- Android device: OnePlus IN2013 serial `8ac48ff0`, `adb` available at `/Users/minxiang/Library/Android/sdk/platform-tools/adb`.
- Supabase env: iOS and Android contain publishable/anon client config only; no `service_role` used in client. Raw URL/key/JWT not copied into evidence.
- iOS app-auth state: previous evidence 51 proves an authenticated iOS app-auth ProductPrice full pull/apply succeeded. This pass launched the app but did not run a fresh OAuth/live sync.
- Android app-auth state: app installed/launched on OnePlus, but signed-in live app-auth sync was not rerun in this pass.

## Tracking note

User override: task was `ACTIVE / REVIEW`; Codex performed a targeted FIX pass and must return to `REVIEW`, not `DONE`.

