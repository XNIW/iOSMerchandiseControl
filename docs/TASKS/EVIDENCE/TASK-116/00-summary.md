# TASK-116 Summary

## Current status
- **Task**: TASK-116
- **Phase**: ACTIVE / REVIEW
- **Responsible**: CLAUDE / Reviewer
- **Execution start**: 2026-05-23 12:09 -0400
- **Latest severe review/fix**: 2026-05-23 15:54 -0400
- **Target for this run**: ACTIVE / REVIEW, not DONE.

## User override
The user explicitly approved TASK-116 execution end-to-end and instructed Codex to exit planning and proceed until REVIEW. TASK-116 was absent locally, so S116-A was created first and then promoted to execution.

## Initial repo state
- iOS repo: `/Users/minxiang/Desktop/iOSMerchandiseControl`, local HEAD matches `origin/main` and GitHub main at `9f15668a88603bb6cb19b43d03644a8adf1ed758`.
- Android repo: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`, pre-existing dirty file `app/src/androidTest/java/com/example/merchandisecontrolsplitview/Task103CrossPlatformAcceptanceTest.kt`; not touched by TASK-116 at execution start.
- Supabase path: `/Users/minxiang/Desktop/MerchandiseControlSupabase`, present but not a git repository in this environment.

## Preflight evidence
- Preflight PASS: `agent-runs/20260523T161143Z-preflight-task-TASK-116-p99756.md`
- Config validate PASS: `agent-runs/20260523T161146Z-config-validate-task-TASK-116-p285.md`
- Supabase status redacted PASS: `agent-runs/20260523T161149Z-supabase-status-redacted-task-TASK-116-p1032.md`

## Known starting diagnosis
- `SyncOrchestrator` exists but automatic foreground execution still uses `legacyAdapter.startForegroundIncrementalCheckNow` / `startForegroundSemiAutomaticCheckIfAllowed`.
- `SupabaseManualSyncCompatibilityAdapter` still forwards to `SupabaseManualSyncViewModel`.
- `SupabaseManualSyncViewModel` remains the automatic push/drain/recovery workhorse.
- `SyncEventIncrementalPullService` still constructs and calls `SupabaseSyncEventIncrementalApplyService`.
- `CatalogIncrementalApplySummary`, `ProductPriceIncrementalApplySummary` and `HistoryIncrementalApplySummary` are summary DTOs, not domain apply services.
- TASK-115 remains non-DONE and superseded by this architectural completion task.

## Gate summary
- Static no-legacy-runtime-path PASS: `agent-runs/20260523T162330Z-scan-no-legacy-runtime-path-task-TASK-116-p12027.md`
- Live no-legacy-runtime-path PASS: `agent-runs/20260523T162330Z-live-no-legacy-runtime-path-task-TASK-116-p12026.md`
- Live no-full-pull-normal-path PASS: `agent-runs/20260523T162340Z-live-no-full-pull-normal-path-task-TASK-116-p13232.md`
- iOS Debug build PASS: `agent-runs/20260523T162939Z-ios-build-debug-task-TASK-116-p20511.md`
- iOS Release build PASS: `agent-runs/20260523T163013Z-ios-build-release-task-TASK-116-p21745.md`
- iOS sync tests PASS: `agent-runs/20260523T162955Z-ios-test-sync-task-TASK-116-p21120.md`
- Android sync/build/lint PASS where run; see `11-regression-matrix.md`.
- Performance budget PASS after stale-window fix: `agent-runs/20260523T162552Z-live-sync-performance-budget-task-TASK-116-prefix-TASK116_PERF_-p15267.md`
- Supabase RLS/grants PASS: `agent-runs/20260523T163743Z-supabase-verify-rls-task-TASK-116-profile-linked-p39559.md`, `agent-runs/20260523T163753Z-supabase-verify-grants-task-TASK-116-profile-linked-p40080.md`
- Cleanup/residue PASS/0 for `TASK116_REALTIME_`, `TASK116_OFFLINE_`, `TASK116_ACCOUNT_`, `TASK116_PERF_`, `TASK116_PHYSICAL_`, `TASK116_RUNTIME_`.

## Severe review/fix update
- GitHub/main verification commands were rerun after `git fetch --prune`: local branch `main`, `HEAD=e0a540f6871be474a7f8266f5e5d60f4ca1b7e6f`, `origin/main=e0a540f6871be474a7f8266f5e5d60f4ca1b7e6f`, `git ls-remote origin main=e0a540f6871be474a7f8266f5e5d60f4ca1b7e6f`, and `origin/main..HEAD` was empty.
- `SyncEventIncrementalDomainApplyService.swift` now exists under `iOSMerchandiseControl/Sync/Incremental/`.
- Concrete physical domain services now exist: `CatalogIncrementalApplyService.swift`, `ProductPriceIncrementalApplyService.swift`, `HistoryIncrementalApplyService.swift`.
- Shared incremental apply helpers now live under `Sync/Incremental/SyncEventIncrementalApplyHelpers.swift`; `SupabaseSyncEventIncrementalApplyService.swift` is now protocol/summary/compat wrapper only.
- `SyncEventIncrementalPullService` still dispatches to `SyncEventIncrementalDomainApplyService` and does not construct `SupabaseSyncEventIncrementalApplyService`.
- Hardened static gate now fails if the physical domain service files are missing or if the dispatcher does not reference those services.
- Severe-fix static no-legacy-runtime-path PASS: `agent-runs/20260523T183127Z-scan-no-legacy-runtime-path-task-TASK-116-p89574.md`.
- Severe-fix live no-legacy-runtime-path PASS: `agent-runs/20260523T183411Z-live-no-legacy-runtime-path-task-TASK-116-p92254.md`.
- Severe-fix live no-full-pull-normal-path PASS: `agent-runs/20260523T183412Z-live-no-full-pull-normal-path-task-TASK-116-p92253.md`.
- Severe-fix iOS Debug/Release build PASS: `agent-runs/20260523T183154Z-ios-build-debug-task-TASK-116-p90096.md`, `agent-runs/20260523T183216Z-ios-build-release-task-TASK-116-p90756.md`.
- Severe-fix iOS sync tests PASS: `agent-runs/20260523T183345Z-ios-test-sync-task-TASK-116-p91525.md`.
- Severe-fix sensitive/evidence scans PASS: `agent-runs/20260523T182750Z-scan-sensitive-task-TASK-116-p75575.md`, `agent-runs/20260523T182750Z-scan-evidence-task-TASK-116-p75576.md`.
- Live near-realtime/offline remain BLOCKED by Android serial readiness: `p71553`, `p72022`.
- Physical iPhone diagnostics/acceptance remain BLOCKED by device/auth/store readiness: `p72498`, `p72994`.
- Account matrix strict-live remains BLOCKED by fixture/device readiness: `p73594`.

## Final cleanup review/fix update
- `HEAD` and `origin/main` were verified equal at `e462b6e8e9ee0aba623f991b8a6023417bb27957` before the final local cleanup changes.
- `SyncAutomaticRuntime` now depends on `Sync*Providing` protocols and `Sync*` DTO wrappers from `SyncAutomaticRuntimeProviders.swift`, not on `SupabaseManualSync*Providing` protocol names.
- Automatic adapters are now named `SyncCatalogPushAdapter`, `SyncProductPriceAdapter`, `SyncHistorySessionPushAdapter` and `SyncActivityRegistrationAdapter`.
- Old `SupabaseManualSync*Providing` protocols remain inside the manual VM boundary for explicit manual UI compatibility only.
- `scan no-legacy-runtime-path` now also fails if `SyncAutomaticRuntime.swift` regresses to `SupabaseManualSync*Providing` or `SupabaseManualSyncRelease*Adapter` names.
- Final cleanup static no-legacy-runtime-path PASS: `agent-runs/20260523T191433Z-scan-no-legacy-runtime-path-task-TASK-116-p31795.md`.
- Final cleanup live no-legacy-runtime-path PASS: `agent-runs/20260523T191643Z-live-no-legacy-runtime-path-task-TASK-116-p34394.md`.
- Final cleanup live no-full-pull-normal-path PASS after serial rerun: `agent-runs/20260523T191649Z-live-no-full-pull-normal-path-task-TASK-116-p35191.md`.
- Final cleanup iOS Debug/Release build PASS: `agent-runs/20260523T191436Z-ios-build-debug-task-TASK-116-p32264.md`, `agent-runs/20260523T191450Z-ios-build-release-task-TASK-116-p32902.md`.
- Final cleanup iOS sync tests PASS: `agent-runs/20260523T191617Z-ios-test-sync-task-TASK-116-p33680.md`.
- Final cleanup live near-realtime retry BLOCKED by Android serial readiness: `agent-runs/20260523T190940Z-live-mutation-near-realtime-task-TASK-116-prefix-TASK116_REALTIME_-p10315.md`.
- Final cleanup live offline reconnect retry BLOCKED by Android serial readiness: `agent-runs/20260523T190944Z-live-offline-reconnect-sync-task-TASK-116-prefix-TASK116_OFFLINE_-p10795.md`.
- Final cleanup physical iPhone acceptance retry BLOCKED by device/login readiness: `agent-runs/20260523T190948Z-ios-physical-sync-acceptance-live-task-TASK-116-p11262.md`.
- Final cleanup account matrix retry BLOCKED by app sign-in/fixture readiness: `agent-runs/20260523T191009Z-live-account-merge-policy-matrix-task-TASK-116-prefix-TASK116_ACCOUNT_-p11775.md`.
- Final cleanup sensitive/evidence scans PASS: `agent-runs/20260523T191129Z-scan-sensitive-task-TASK-116-p13972.md`, `agent-runs/20260523T191132Z-scan-evidence-task-TASK-116-p14282.md`.
- Final cleanup report latest PASS: `agent-runs/20260523T191145Z-report-latest-task-TASK-116-p21793.md`.
- Final cleanup `git diff --check` PASS.

## Review blockers carried forward
- Android physical serial `8ac48ff0` was not available to the live harness during final live gates; Android auth, near-realtime, offline reconnect and runtime parity are BLOCKED, not PASS.
- Physical iPhone diagnostics/acceptance/parity are BLOCKED by device/auth/store readiness; latest acceptance retry remains BLOCKED.
- Account matrix A-L strict-live is BLOCKED by live fixture/device/sign-in availability; latest retry remains BLOCKED.
- Domain apply logic is automatic-path legacy-free and now physically split into dispatcher + Catalog/ProductPrice/History service files. DONE still requires live/device/account blockers to pass or explicit user acceptance.

## User-requested severe review rerun — 2026-05-23 15:54 -0400
- Git/GitHub verification before local review fixes: branch `main`, `HEAD=98920f8ff4064867181e71c1c6e78993fe46c7f4`, `origin/main=98920f8ff4064867181e71c1c6e78993fe46c7f4`, `git ls-remote origin main=98920f8ff4064867181e71c1c6e78993fe46c7f4`, `origin/main..HEAD` empty. No `BRANCH_OR_REMOTE_MISMATCH` at review start.
- Direct review fix: `OptionsSyncSummaryProvider` now reuses a fresh remote count snapshot for 60s, keeps an in-flight guard, and invalidates the cached remote snapshot on account changes. This keeps Options observer-only under repeated local refreshes and avoids repeated remote count fetch cancellation/restart loops.
- Test/harness fix: `OptionsLocalDatabaseSummaryTests` now covers cached remote-count reuse with local recompute, and canonical `ios test sync` now includes existing `SupabaseProductPriceApplyServiceTests` and `HistorySessionSyncServiceTests`.
- Review rerun iOS Debug/Release build PASS: `agent-runs/20260523T194331Z-ios-build-debug-task-TASK-116-p54844.md`, `agent-runs/20260523T194338Z-ios-build-release-task-TASK-116-p55368.md`.
- Review rerun iOS sync tests PASS: `agent-runs/20260523T194020Z-ios-test-sync-task-TASK-116-p53802.md`. Earlier rerun `p52792` failed on test actor assertion syntax introduced during review and was fixed before this PASS.
- Review rerun critical architecture gates PASS: `agent-runs/20260523T194510Z-scan-no-legacy-runtime-path-task-TASK-116-p56199.md`, `agent-runs/20260523T194510Z-live-no-legacy-runtime-path-task-TASK-116-p56201.md`, `agent-runs/20260523T194516Z-live-no-full-pull-normal-path-task-TASK-116-p57695.md`.
- Review rerun Options/performance budget PASS: `agent-runs/20260523T194521Z-live-sync-performance-budget-task-TASK-116-prefix-TASK116_PERF_-p58179.md`.
- Review rerun Supabase status/RLS/grants PASS: `agent-runs/20260523T194537Z-supabase-status-redacted-task-TASK-116-p58880.md`, `agent-runs/20260523T194541Z-supabase-verify-rls-task-TASK-116-profile-linked-p59316.md`, `agent-runs/20260523T194550Z-supabase-verify-grants-task-TASK-116-profile-linked-p59833.md`.
- Review rerun live gates remain BLOCKED, not PASS: runtime parity `p60350`, near-realtime `p62188`, offline reconnect `p62658`, physical diagnostics `p63133`, physical sync acceptance `p63640`, account matrix `p64142`.
- Review cleanup/residue scoped prefixes PASS/0 after dry-run + execute + residue-check: `TASK116_REALTIME_` `p73466`, `TASK116_OFFLINE_` `p74012`, `TASK116_ACCOUNT_` `p74579`, `TASK116_PERF_` `p75097`, `TASK116_PHYSICAL_` `p75631`, `TASK116_RUNTIME_` `p76166`.

## Safety notes
- No push to remote.
- No reset/revert of unrelated changes.
- Supabase live/cleanup commands require explicit `MC_ALLOW_LIVE` / `MC_ALLOW_CLEANUP`.
- TASK-116 must not be marked DONE in this run.

## Final execution status
TASK-116 is ready for `ACTIVE / REVIEW`, not DONE.
