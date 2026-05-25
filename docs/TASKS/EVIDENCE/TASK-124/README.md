# TASK-124 Evidence

Task: `TASK-124 — iOS Sync Final Architecture Purification and Residue Eradication`

Status: `BLOCKED / BLOCKED_EXTERNAL_LIVE_DEVICE`

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
