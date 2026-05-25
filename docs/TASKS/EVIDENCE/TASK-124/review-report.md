# TASK-124 Review Report

Status: `DONE / SIMULATOR_EMULATOR_SCOPE_VERIFIED`

Generated: `2026-05-25 17:52 -0400`

## Scope
- In scope: iOS Simulator, Android Emulator `emulator-5554`, Supabase linked/local, existing harness/scanners/smoke, `TASK124_` cleanup, TASK-123 speed regression for simulator/emulator.
- Out of scope and deferred to TASK-125: physical iPhone, physical Android, locked/background real-device, long-offline real-device, real-device background sync.

## Preflight
- Branch: `main`.
- Pre-review local/origin/ls-remote HEAD: `472e1bbb39ed556bfbe5b1536df56d1d1aec35cb`.
- Final preflight evidence: `20260525T215657Z-preflight-require-head-consistency-task-TASK-124-p35156`.
- Final head consistency evidence: `20260525T215657Z-git-head-consistency-task-TASK-124-p35155`.

## Findings
- F-124-R1 HIGH: TASK-123 no-op live harness measured fixed settle delay inside elapsed time and did not expose numeric settle evidence. Fixed by moving `started_ms` after settle and adding `settleSeconds` plus `elapsedMsExcludesSettle` to JSON. Rerun PASS: `20260525T204759Z-live-task123-noop-task-TASK-124-prefix-TASK124_SPEED_SIM_-p68189`.
- F-124-R2 HIGH: Supabase cleanup/residue check could falsely report zero because `MC_RESIDUE_COUNT` was assigned inside command substitution. Fixed by parsing residue JSON output explicitly in caller scope. Rerun PASS: dry-run `20260525T214252Z`, execute `20260525T214302Z`, residue `20260525T214312Z`.
- F-124-R3 MEDIUM: runtime parity drift appeared after live writes; app-local stores had more rows than Supabase. Captured with `sync-counts` reports and resolved by explicit setup full pulls before parity. Final parity PASS: `20260525T214541Z-live-runtime-parity-task-TASK-124-prefix-TASK124_RUNTIME_SIM_-profile-linked-p96011`.
- F-124-R4 LOW/MEDIUM: evidence scan failed on an oversized raw PASS log. Replaced the raw log with a concise summary while keeping JSON/Markdown evidence. Final evidence scan PASS: `20260525T214908Z-scan-evidence-task-TASK-124-p19457`.
- F-124-R5 LOW: offline/reconnect matrix still referenced a historical physical/live `BLOCKED_EXTERNAL`. Updated to simulator/emulator PASS and documented physical/live coverage as TASK-125 deferred.

## Fixes Applied
- `tools/agent/lib/supabase.sh`: no-op measurement excludes settle delay and records settle evidence.
- `tools/agent/lib/supabase.sh`: cleanup/residue reports parse actual JSON row counts in caller scope.
- `docs/TASKS/EVIDENCE/TASK-124/offline-reconnect-matrix.md` and `.json`: updated to final simulator/emulator PASS.
- `docs/TASKS/EVIDENCE/TASK-124/final-handoff.md`, `README.md`, task file, MASTER-PLAN and this report: updated with supported claims only.
- Oversized raw PASS log summarized; final evidence scan verifies evidence hygiene.

## Rerun Evidence
- iOS Debug: PASS `20260525T205052Z-ios-build-debug-task-TASK-124-p72454`.
- iOS Release: PASS `20260525T205103Z-ios-build-release-task-TASK-124-p73070`.
- iOS sync tests: PASS `20260525T205209Z-ios-test-sync-task-TASK-124-p73691`.
- Android Debug: PASS `20260525T205452Z-android-build-debug-task-TASK-124-p76963`.
- Android sync tests: PASS `20260525T205457Z-android-test-sync-task-TASK-124-p78020`.
- Android emulator/offline tests: PASS `20260525T205504Z-android-test-offline-task-TASK-124-p79163`.
- iOS auth-preflight live: PASS `20260525T205517Z-ios-auth-preflight-live-task-TASK-124-p80081`.
- Offline/reconnect: PASS `20260525T205558Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_SIM_-p81521`.
- Mutation near realtime: PASS `20260525T205849Z-live-mutation-near-realtime-task-TASK-124-prefix-TASK124_REALTIME_SIM_-p86887`.
- Runtime parity: PASS `20260525T214541Z-live-runtime-parity-task-TASK-124-prefix-TASK124_RUNTIME_SIM_-profile-linked-p96011`.
- TASK-123 no-op: PASS `20260525T204759Z-live-task123-noop-task-TASK-124-prefix-TASK124_SPEED_SIM_-p68189`.
- TASK-123 single propagation: PASS `20260525T210831Z-live-task123-single-propagation-task-TASK-124-prefix-TASK124_SPEED_SIM_-p99966`.
- TASK-123 burst-10: PASS `20260525T213215Z-live-task123-burst-10-task-TASK-124-prefix-TASK124_SPEED_SIM_-p73422`.
- TASK-123 cold-restart: PASS `20260525T212622Z-live-task123-cold-restart-task-TASK-124-prefix-TASK124_SPEED_SIM_-p55682`.
- Cleanup dry-run/execute/residue: PASS `20260525T214252Z`, `20260525T214302Z`, `20260525T214312Z`.
- TASK-124 scanners: PASS `20260525T215724Z` through `20260525T215757Z`.
- Sensitive scan: PASS `20260525T215758Z-scan-sensitive-task-TASK-124-p42892`.
- Evidence scan: PASS `20260525T215758Z-scan-evidence-task-TASK-124-p43198`.
- Repo-diff scan: PASS `20260525T215819Z-scan-repo-diff-task-TASK-124-p57995`.
- JSON validation: PASS `20260525T215820Z-report-validate-json-task-TASK-124-path-docs-TASKS-EVIDENCE-TASK-124-agent-runs-p36282`.
- `bash -n tools/agent/lib/supabase.sh`: PASS.
- `git diff --check`: PASS.

## DONE Decision
TASK-124 is DONE for simulator/emulator/Supabase scope because all required claims are backed by current evidence, all BLOCKER/HIGH findings inside the scope were fixed and rerun, cleanup is scoped and residue is PASS/0, and deferred real-device/background/long-offline scenarios are outside TASK-124 by explicit user instruction.
