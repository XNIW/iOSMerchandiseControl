# Command Matrix

Status: PASS_WITH_NOTES.

PASS:
- `help`, `help-json`, `version`
- `doctor`, `preflight`
- `config validate`, `config print-redacted`
- `list commands`, `list commands-json`
- `report --task TASK-113`, `report --latest`, `report validate-json --path <file>`
- `scan repo-diff`, `scan release-cta`, `scan sensitive`, `scan evidence --task TASK-113`
- `safety check-prefix`, `safety dry-run-required`
- `ios build debug/release`, `ios test sync/lifecycle/offline`, `ios smoke simulator`
- `android build debug/release`, `android test sync/offline`, `android offline-tier-status`, `android offline-write/reconnect-drain --tier L1`
- `supabase status-redacted`, `verify-schema/rls/grants --profile local`, `residue-check --profile local`, dry-run cleanup/explain/pooler check
- MCP `test-wrapper` and `server.mjs --self-test`

Expected refusals PASS:
- live commands without `MC_ALLOW_LIVE=1` return exit 4.
- cleanup execute without `MC_ALLOW_CLEANUP=1` or matching `cleanup_plan_id` returns exit 4.
- non-TASK/global prefixes return exit 4.
- live/cleanup lock smoke returns exit 2.

BLOCKED / PASS_WITH_NOTES:
- `android offline-write/reconnect-drain --tier L2`: PASS in professional review on physical device.
- `android offline-write --tier L3` and live matrices: refused without live gate.
- `ios smoke options`: blocked by legacy AX/JXA timeout.
- linked Supabase schema/lint: PASS; linked query checks RLS/grants/residue: BLOCKED by pooler circuit breaker / DB password state.

Professional review update — 2026-05-21:
- PASS: Android Debug/Release build, sync test, L1 offline test, L2 offline-write, L2 reconnect-drain, smoke device and smoke options.
- PASS: iOS Debug/Release build, sync/lifecycle/offline tests and simulator smoke.
- PASS_WITH_NOTES: dry-run-no-db Supabase profile commands intentionally do not query a DB.
- NOT_RUN: L3 live offline read-back/cleanup, because `MC_ALLOW_LIVE=1` was not enabled.
