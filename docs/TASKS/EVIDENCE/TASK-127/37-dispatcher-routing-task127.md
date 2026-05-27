# TASK-127 Evidence 37 - Dispatcher Routing

Date: 2026-05-27

Dispatcher routing added in `tools/agent/mc-agent.sh`:

- TASK-127 scanners are handled by `mc_cmd_scan_task127_static`.
- `scanner-self-tests` dispatches to TASK-127 when `--task TASK-127` or `MC_TASK_ID=TASK-127` is present.
- Unknown scans still return MISCONFIGURED.

Initial pre-fix runtime result:

- `options-mainactor-heavy-fetch`: FAIL on current code, expected before Swift fix.
- `productprice-full-fetch-mainactor`: FAIL on current code, expected before Swift fix.
- `options-refresh-debounce`: FAIL on current code, expected before Swift fix.
- `task127-debug-hook-release-safety`: PASS.

