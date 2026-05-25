# TASK-124 Evidence

Task: `TASK-124 — iOS Sync Final Architecture Purification and Residue Eradication`

Status: `ACTIVE / REVIEW — SIMULATOR_EMULATOR_SCOPE_PASS`

Execution started by user approval on 2026-05-25 11:12 -0400. Initial state:
- local HEAD / origin/main / ls-remote main: `951547ab1e4ed63a9f6a730c293ee278a67ef17c`;
- no TASK-124 build/test/scanner PASS is claimed until generated in this directory;
- no Supabase write, cleanup, migration, RLS/grant/RPC/schema change has been performed at execution start;
- TASK-123 remains the latest strict simulator speed acceptance evidence and is not reopened.

Execution evidence must include:
- automation discovery via `mc-agent help-json` and `mc-agent list commands-json`;
- harness routing/health evidence for TASK-124 commands and scanner availability;
- canonical head/raw/API preflight;
- inventory and call-site maps;
- pbxproj/target membership audit;
- scanner RED/GREEN fixture results;
- machine-readable scanner self-tests and redacted JSON/Markdown/log reports;
- Debug/Release iOS builds;
- iOS sync and automatic architecture tests;
- offline/reconnect/post-offline acceptance evidence if orchestrator, outbox, decision engine, incremental pull, recovery or remote adapter is touched;
- fix evidence for any real offline/reconnect failure unless blocked by schema/RLS/grant migration need, missing session/account/device, or untestable background/locked behavior;
- TASK-123 speed regression if sync runtime is touched;
- Android targeted checks only if Android or cross-platform harness is touched;
- Supabase read-only schema/RLS/grant evidence and scoped dry-run cleanup only if live data is used.
- final handoff with coherent PASS/FAIL/BLOCKED_EXTERNAL/MISCONFIGURED/UNSAFE_OPERATION_REFUSED/NOT_RUN/PASS_WITH_NOTES taxonomy and no DONE claim.

## Execution result — 2026-05-25 11:39 -0400

TASK-124 execution reached local PASS gates and stopped on external live-device blockers:
- iOS Debug/Release build: PASS.
- iOS sync, automatic-domain, automatic-architecture, manual-sync-regression tests: PASS.
- TASK-124 scanners and scanner self-tests: PASS.
- Android build/debug sync/offline/offline-tier status: PASS.
- Supabase linked schema/RLS/grants/contract read-only: PASS.
- Supabase cleanup dry-run and residue-check `TASK124_`: PASS/0 unsafe cleanup performed.
- BLOCKED_EXTERNAL: offline/reconnect live matrix and TASK-123 speed regression live gates require `MC_ANDROID_DEVICE_SERIAL`.
- BLOCKED_EXTERNAL: local `supabase status-redacted` requires local Supabase CLI/Docker stack.
- BLOCKED_EXTERNAL: `ios smoke options` requires macOS Accessibility/JXA permission.

Final handoff: `docs/TASKS/EVIDENCE/TASK-124/final-handoff.md`.

## Simulator/emulator resume — 2026-05-25 13:10 -0400

User decision: physical iPhone/Android device validation is deferred to TASK-125. TASK-124 resume is scoped to iOS Simulator, Android Emulator and Supabase local/linked.

Resolved blockers:
- `supabase status-redacted`: PASS in `20260525T170629Z-supabase-status-redacted-p28677`.
- Android Emulator selected: `emulator-5554` from local AVD `Medium_Phone_API_35`; no physical device used.
- Android auth-preflight live: PASS in `20260525T170833Z-android-auth-preflight-live-p32621`.
- iOS smoke simulator: PASS in `20260525T170848Z-ios-smoke-simulator-p33393`.

Remaining blocker:
- iOS auth-preflight live: `BLOCKED_EXTERNAL` in `20260525T170716Z-ios-auth-preflight-live-task-TASK-124-p30454` and retry `20260525T170916Z-ios-auth-preflight-live-task-TASK-124-p34245`.
- Reason: iOS Simulator has no existing non-expired device session.
- Next action: complete login/session restore in the iOS Simulator app, then rerun live simulator/emulator gates.

Not run yet in this resume because iOS live auth is not ready:
- offline/reconnect simulator/emulator matrix;
- TASK-123 speed regression simulator/emulator subset;
- mutation-near-realtime and runtime-parity simulator/emulator.

## Simulator/emulator completion — 2026-05-25 16:23 -0400

TASK-124 simulator/emulator scope reached REVIEW handoff. Physical devices are not covered and are deferred to TASK-125.

Resolved live gates:
- iOS smoke simulator: PASS `20260525T192132Z-ios-smoke-simulator-p46903`.
- iOS auth-preflight live after documented polling: PASS `20260525T192259Z-ios-auth-preflight-live-task-TASK-124-p48048`.
- Offline/reconnect simulator/emulator: PASS `20260525T192951Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_SIM_-p59570`.
- TASK-123 speed regression simulator/emulator: single propagation PASS `20260525T193243Z-live-task123-single-propagation-task-TASK-124-prefix-TASK124_SPEED_SIM_-p64766`; no-op PASS `20260525T195458Z-live-task123-noop-task-TASK-124-prefix-TASK124_SPEED_SIM_-p17878`; burst-10 PASS `20260525T195639Z-live-task123-burst-10-task-TASK-124-prefix-TASK124_SPEED_SIM_-p21549`; cold-restart PASS `20260525T200412Z-live-task123-cold-restart-task-TASK-124-prefix-TASK124_SPEED_SIM_-p36557`.
- Mutation near realtime: PASS `20260525T200943Z-live-mutation-near-realtime-task-TASK-124-prefix-TASK124_RT_SIM_-p49942`.
- Runtime parity: PASS `20260525T201515Z-live-runtime-parity-task-TASK-124-prefix-TASK124_RT_SIM_-profile-linked-p57963` after explicit Android full-pull setup `20260525T201439Z-android-live-full-pull-live-p57140`.
- Cleanup scoped `TASK124_`: dry-run PASS `20260525T201625Z-supabase-cleanup-task-TASK-124-prefix-TASK124_-profile-linked-dry-run-p59913`; execute PASS `20260525T201647Z-supabase-cleanup-task-TASK-124-prefix-TASK124_-profile-linked-execute-cleanup-plan-id-cleanup-TASK-124-20260525T201625Z-TASK124_-p60875`; residue PASS `20260525T201658Z-supabase-residue-check-prefix-TASK124_-profile-linked-p61341`.

Final verification:
- TASK-124 scanners all PASS in `agent-runs/20260525T201721Z` through `20260525T201735Z`.
- Sensitive scan PASS `20260525T201736Z-scan-sensitive-task-TASK-124-p66735`.
- Evidence final PASS `20260525T202253Z-scan-evidence-task-TASK-124-p89233`.
- Repo-diff final PASS `20260525T202306Z-scan-repo-diff-p98866`.
- iOS Debug PASS `20260525T201834Z-ios-build-debug-p86024`; iOS Release PASS `20260525T201845Z-ios-build-release-p86604`; iOS sync tests PASS `20260525T202012Z-ios-test-sync-p88314`.
- Android Debug PASS `20260525T201953Z-android-build-debug-p87332`; Android sync tests PASS `20260525T202001Z-android-test-sync-p87806`.
- `git diff --check`: PASS.

Harness fixes made during resume:
- iOS and Android live acceptance fixtures now accept `TASK124_` prefixes.
- TASK-123 no-op live harness now records `settleSeconds` and no longer charges a fixed one-second artificial wait to the measured no-op budget.
- One oversized raw log from a PASS report was removed after markdown/json evidence remained available; final evidence scan PASS confirms evidence hygiene.
