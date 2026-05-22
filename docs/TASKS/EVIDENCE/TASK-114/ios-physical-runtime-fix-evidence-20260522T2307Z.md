# TASK-114 — iOS Physical Runtime Fix Evidence — 2026-05-22 23:07Z

## Scope
- Regression post-DONE on real physical iPhone after login: runtime sync loop/performance, spinner `0/0`, stale local database state.
- Build under test installed on physical iPhone after local fix: Debug build from `/tmp/mc-task114-physical-build/Build/Products/Debug-iphoneos/iOSMerchandiseControl.app`.

## Code fix summary
- Foreground forced incremental path now respects the semi-automatic gate/backoff instead of bypassing it for root foreground, network reconnect, and remote sync events.
- `requiresFullRecovery=true` schedules one guarded full-pull recovery path using existing dry-run/apply safety gates; on clean recovery it advances the sync-events watermark and applies backoff to avoid same-page bursts.
- History progress `0/0` is ignored/cleared so Options does not show an active spinner when there is no history work.
- Physical harness added runtime counts/smoke/loop/acceptance commands and physical appDataContainer SwiftData inspection.

## Physical iPhone evidence
- Physical device discovered: iPhone 15 Pro Max / iOS 26.5 / UDID hash `13a5f802ece3`.
- Physical Debug build: `xcodebuild ... -destination platform=iOS,id=<REDACTED> ... build` PASS; `devicectl device install app` PASS.
- `20260522T225641Z-ios-physical-runtime-counts-task-TASK-114-live-p8322`: PASS for runtime store copy; auth state is `auth.isSignedIn=false`, `auth.userIDPresent=false`, outcome `blocked_auth_or_owner`.
- `20260522T225835Z-ios-physical-smoke-options-task-TASK-114-live-p8933`: PASS; `spinnerZeroOfZero=false`, `automaticSyncInProgress=false`.
- `20260522T230142Z-ios-physical-sync-loop-diagnostics-task-TASK-114-live-p10174`: PASS diagnostic; classification `AUTH_SESSION_NOT_READY`, attemptsLast60s `2`, progress numerator/denominator `null/null`, no active same-page loop evidence in the authenticated runtime.
- `20260522T230240Z-ios-physical-sync-acceptance-task-TASK-114-live-p10755`: FAIL by design; blockers `auth_session_not_ready,physical_counts_drift_without_recovery`.

## Physical counts at blocker
- iOS physical: products `16820`, suppliers `82`, categories `46`, product_prices `40083`, history `22`, pending aggregate `0`.
- Supabase linked: products `19696`, suppliers `59`, categories `28`, product_prices `41111`, history `33`.
- The physical app cannot start recovery while auth/session is not ready.

## Stop condition
- Do not mark TASK-114 DONE until the physical iPhone is signed in and `MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh ios physical-sync-acceptance --task TASK-114 --live` passes, followed by the requested cross-platform gates.
