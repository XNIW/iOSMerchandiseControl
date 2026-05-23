# Regression Matrix

## iOS
- Debug build PASS: `agent-runs/20260523T162939Z-ios-build-debug-task-TASK-116-p20511.md`
- Release build PASS: `agent-runs/20260523T163013Z-ios-build-release-task-TASK-116-p21745.md`
- Sync tests PASS: `agent-runs/20260523T162955Z-ios-test-sync-task-TASK-116-p21120.md`

## Android
- Sync tests PASS: `agent-runs/20260523T163138Z-android-test-sync-task-TASK-116-p22527.md`
- Debug build PASS: `agent-runs/20260523T163149Z-android-build-debug-task-TASK-116-p23091.md`
- Release build PASS: `agent-runs/20260523T163156Z-android-build-release-task-TASK-116-p23531.md`
- `./gradlew :app:lintDebug` PASS with pre-existing AGP/Kotlin deprecation warnings.

## Live/cross-platform
- iOS auth-preflight PASS with explicit simulator id: `agent-runs/20260523T163326Z-ios-auth-preflight-live-task-TASK-116-p25884.md`
- Android auth-preflight BLOCKED: `agent-runs/20260523T163410Z-android-auth-preflight-live-task-TASK-116-p27401.md`
- Runtime parity BLOCKED: `agent-runs/20260523T163421Z-live-runtime-parity-task-TASK-116-prefix-TASK116_RUNTIME_-p27887.md`
- Near-realtime BLOCKED: `agent-runs/20260523T163527Z-live-mutation-near-realtime-task-TASK-116-prefix-TASK116_REALTIME_-p29888.md`
- Offline reconnect BLOCKED: `agent-runs/20260523T163535Z-live-offline-reconnect-sync-task-TASK-116-prefix-TASK116_OFFLINE_-p30376.md`

## Supabase
- RLS PASS: `agent-runs/20260523T163743Z-supabase-verify-rls-task-TASK-116-profile-linked-p39559.md`
- Grants PASS: `agent-runs/20260523T163753Z-supabase-verify-grants-task-TASK-116-profile-linked-p40080.md`

## Cleanup/residue
Scoped cleanup dry-run/execute/residue completed for:
- `TASK116_PERF_`
- `TASK116_REALTIME_`
- `TASK116_OFFLINE_`
- `TASK116_ACCOUNT_`
- `TASK116_PHYSICAL_`
- `TASK116_RUNTIME_`

Residue checks returned PASS/0 for all listed prefixes.
