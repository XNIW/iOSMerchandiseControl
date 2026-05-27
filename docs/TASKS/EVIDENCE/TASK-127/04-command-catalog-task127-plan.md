# TASK-127 Evidence 04 - Command Catalog Plan

Date: 2026-05-27

TASK-127 commands added to `help-json` / `list commands-json`:

- `scan options-mainactor-heavy-fetch --task TASK-127 --strict`
- `scan productprice-full-fetch-mainactor --task TASK-127 --strict`
- `scan options-refresh-debounce --task TASK-127 --strict`
- `scan task127-debug-hook-release-safety --task TASK-127 --strict`
- `scan task127-final-gates --task TASK-127 --strict`
- `scan scanner-self-tests --task TASK-127 --strict`
- `ios test options-summary-performance --task TASK-127`
- `ios test options-summary-provider --task TASK-127`
- `ios smoke options-performance --task TASK-127`
- `android audit options-performance --task TASK-127`

Namespace correction is enforced: scanners are top-level `scan` commands, not `ios scan`.

