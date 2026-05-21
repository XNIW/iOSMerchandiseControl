# TASK-112 — Blocker and handoff

Timestamp: 2026-05-20 22:26 -0400  
Agent: Codex / Executor

## Final execution state

TASK-112 remains **ACTIVE / BLOCKED**.

Docker is working and local Supabase validation was completed. The targeted iOS reconnect efficiency patch was verified again, and this final review+fix rerun added two small iOS robustness fixes: OAuth callbacks are forwarded while the auth view model is `.signingIn`, and background cancellation now marks lifecycle interruption before canceling the foreground task. The task still cannot advance to REVIEW because the required live iOS↔Android Supabase gate **CA-20** is blocked by missing iOS app-auth live session evidence.

## Completed after previous blocker

1. **Docker/Supabase local**
   - Docker daemon, Docker Compose and Supabase CLI verified.
   - Local Supabase stack inspected.
   - Required tables/RLS/grants/RPC/realtime publication verified.
   - Transactional local tests for owner isolation, ProductPrice dedupe and `record_sync_event` idempotency passed.

2. **iOS efficiency parity with Android reconnect behavior**
   - Added `AutomaticSyncReconnectScheduler`.
   - Added `AutomaticSyncNetworkReachabilityObserver` over `NWPathMonitor`.
   - Wired foreground/reconnect scheduling from `ContentView`.
   - Added `.networkReconnect` source/reason through `SupabaseManualSyncViewModel` and lifecycle run gate.
   - Added tests for offline->online scheduling, flapping coalescing, background cancellation, reconnect cooldown bypass and mutating-run priority.
   - Removed non-runtime `Vendor/libxls` resource files from app bundle Resources, eliminating the Release scan false positive for `Upload`.

3. **Build/test/smoke/scan**
   - iOS Debug build simulator PASS.
   - iOS Release build simulator PASS.
   - iOS targeted TASK-112 reconnect/release tests PASS.
   - iOS broader local/offline regression group PASS: 120 tests, 0 failed.
   - Android targeted unit suite PASS: 200 tests, 0 failed.
   - Android `assembleDebug`, `assembleRelease`, `lintDebug` PASS.
   - Android app-auth live smoke on physical OnePlus 8 PASS.
   - iOS simulator launch smoke PASS.
   - iOS simulator Options smoke PASS.
   - Android physical launch + unlocked Options smoke PASS after user unlocked the screen.
   - iOS/Android Release forbidden sync-now CTA scans PASS; iOS broad bundle scan still contains localized remediation/review copy for download/send states, not a visible public manual sync-now CTA.

## Remaining blockers

1. **CA-20 live gated evidence is still not available.**
   - iOS live harness with live sentinel failed with `sessionMissing`.
   - Android app-auth live smoke passed, but cross-platform acceptance requires both iOS and Android authenticated clients.
   - No service_role/client-secret workaround was used.

2. **Full offline-first cross-platform live matrix remains blocked.**
   - Unit/static coverage improved, especially iOS reconnect efficiency.
   - Required live/offline TASK112_* and TASK112_OFFLINE_* scenarios cannot be completed without iOS app-auth session and dual-client read-back.

3. **Critical CA-43…CA-68 remain mixed BLOCKED/PASS_WITH_NOTES/NOT_RUN.**
   - There are no fake PASS claims.
   - CA-20 and critical offline live gates prevent REVIEW.

## Files modified

### iOS repo

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-112-automatic-cross-platform-sync-no-manual-options-cta.md`
- `docs/TASKS/EVIDENCE/TASK-112/*`
- `iOSMerchandiseControl.xcodeproj/project.pbxproj`
   - `iOSMerchandiseControl/AutomaticSyncReconnectScheduler.swift`
   - `iOSMerchandiseControl/ContentView.swift`
   - `iOSMerchandiseControl/OptionsView.swift`
   - `iOSMerchandiseControl/SupabaseAuthViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncLifecycleRunGate.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/AutomaticSyncReconnectSchedulerTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncLifecycleRunGateTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`

### Android repo

- `app/src/main/java/com/example/merchandisecontrolsplitview/ui/navigation/NavGraph.kt`
- `app/src/main/java/com/example/merchandisecontrolsplitview/ui/screens/OptionsScreen.kt`
- `app/src/main/res/values/strings.xml`
- `app/src/main/res/values-en/strings.xml`
- `app/src/main/res/values-es/strings.xml`
- `app/src/main/res/values-zh/strings.xml`

### Supabase repo

- No file changes.
- No live DB changes.
- Local transactional synthetic rows rolled back.

## Final review+fix rerun update — 2026-05-20 22:26 -0400

- iOS live preflight was executed with sentinel and failed in the xcresult with `failed: caught error: "sessionMissing"`.
- Android physical smoke was retried after the user unlocked the screen: `MainActivity` became `topResumed`, Inventario rendered, Opzioni rendered, and the visible sync card shows automatic sync status with no public manual sync-now CTA.
- Android full unit suite passed only after enabling JVM self-attach for MockK/ByteBuddy: `458 tests`, `0 failures`, `2 skipped`.
- Supabase local status/lint and transactional idempotency/owner-isolation checks passed again; raw status output with local keys was not retained.

## Required next action

Restore/provide a valid iOS app-auth live session/test account path, then rerun CA-20 and the TASK112_* / TASK112_OFFLINE_* cross-platform matrices. Do not mark TASK-112 DONE and do not move it to REVIEW until those gates pass with real evidence.

## CA-20 app-auth rerun handoff — 2026-05-20 23:15 -0400

TASK-112 remains **ACTIVE / BLOCKED**, but the blocker changed.

Completed:

- iOS app-auth session restore PASS after cold launch.
- iOS XCTest app-auth preflight PASS with `TASK112_IOS_AUTH_PREFLIGHT`.
- Android app-auth preflight PASS after switching from Gradle uninstalling runner to persistent `adb shell am instrument`.
- CA-20 live iOS↔Android↔Supabase PASS with prefix `TASK112_CA20_R20260521T030156Z_`.
- Medium ProductPrice live matrix PASS.
- iOS conflict/stale/fail-closed PASS.
- iOS offline retry/drain PASS with prefix `TASK112_OFFLINE_R20260521T030912Z_`.
- iOS/Android `git diff --check` PASS.

Current blocker:

- Scoped cleanup via app-auth failed: `PostgrestError 42501 permission denied for table inventory_product_prices`.
- Remaining live residue before cleanup:
  - `TASK112_CA20_R20260521T030156Z_`: suppliers `9`, categories `9`, products `54`, ProductPrice `114`.
  - `TASK112_OFFLINE_R20260521T030912Z_`: suppliers `1`, categories `1`, products `1`, ProductPrice `0`.
- No service_role/admin cleanup was run.

Required next action:

- Backend/owner decision is required for either scoped admin cleanup of only these TASK-112 prefixes, or a reviewed live RLS/grant/migration path that permits owner-scoped authenticated cleanup.
- TASK-112 must not move to REVIEW/DONE until cleanup is complete and residue-zero evidence is recorded.

## Final closure superseding blocker — 2026-05-21 00:01 -0400

The cleanup/RLS blocker is resolved.

- Root cause: authenticated client hard delete is intentionally not granted on catalog/ProductPrice tables; this is a test cleanup need, not a runtime app delete requirement.
- Strategy used: admin/postgres backend cleanup scoped only to `TASK112_CA20_R20260521T030156Z_`, `TASK112_OFFLINE_R20260521T030912Z_`, and final `TASK112_FINAL_R20260521T033505Z_`.
- No RLS/grant/policy migration was applied.
- Rows deleted:
  - initial prefixes: ProductPrice 114, products 55, suppliers 10, categories 10, sessions/events 0;
  - final prefix: ProductPrice 114, products 55, suppliers 10, categories 10, sessions/events 0.
- Final SQL read-back: `TASK112_CA20_*`, `TASK112_OFFLINE_*`, `TASK112_FINAL_*`, and `TASK112_ANY` all 0 rows for suppliers/categories/products/ProductPrice.
- Final live CA-20 rerun with `TASK112_FINAL_R20260521T033505Z_` PASS.
- Final iOS/Android build/test/smoke/CTA/security checks PASS/PASS_WITH_NOTES as detailed in `93-final-cleanup-done-closure.md`.

Final handoff is no longer BLOCKED: **TASK-112 DONE / Chiusura — FINAL EVIDENCE-BACKED AUTOMATIC SYNC PASS**.
