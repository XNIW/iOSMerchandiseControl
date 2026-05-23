# TASK-116 Summary

## Current status
- **Task**: TASK-116
- **Phase**: ACTIVE / REVIEW
- **Responsible**: CLAUDE / Reviewer
- **Execution start**: 2026-05-23 12:09 -0400
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

## Review blockers carried forward
- Android physical serial `8ac48ff0` was not available to the live harness during final live gates; Android auth, near-realtime, offline reconnect and runtime parity are BLOCKED, not PASS.
- Physical iPhone diagnostics/acceptance/parity are BLOCKED by device/auth/store readiness.
- Account matrix A-L strict-live is BLOCKED by live fixture/device availability.
- Domain apply logic is automatic-path legacy-free, but reviewer may request a deeper physical file split into separate Catalog/ProductPrice/History service files before DONE.

## Safety notes
- No push to remote.
- No reset/revert of unrelated changes.
- Supabase live/cleanup commands require explicit `MC_ALLOW_LIVE` / `MC_ALLOW_CLEANUP`.
- TASK-116 must not be marked DONE in this run.

## Final execution status
TASK-116 is ready for `ACTIVE / REVIEW`, not DONE.
