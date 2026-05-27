# TASK-127 Phase -1 — Automation Inventory

- RESULT: PASS
- EXIT_CODE: 0
- REPORT_MD: `docs/TASKS/EVIDENCE/TASK-127/-1-00-automation-inventory.md`
- REPORT_JSON: `docs/TASKS/EVIDENCE/TASK-127/-1-00-automation-inventory.json`
- NEXT_ACTION: Implement missing TASK-127 wrappers/scanners before Swift runtime patch.

## Commands executed

- `MC_TASK_ID=TASK-127 ./tools/agent/mc-agent.sh help-json`
- `MC_TASK_ID=TASK-127 ./tools/agent/mc-agent.sh list commands-json`
- `MC_TASK_ID=TASK-127 ./tools/agent/mc-agent.sh config validate`
- `MC_TASK_ID=TASK-127 ./tools/agent/mc-agent.sh git head-consistency --task TASK-127`
- `MC_TASK_ID=TASK-127 ./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-127`

## Canonical wrapper evidence

- Config validate: `docs/TASKS/EVIDENCE/TASK-127/agent-runs/20260527T182451Z-config-validate-p74503.md/json`
- Head consistency: `docs/TASKS/EVIDENCE/TASK-127/agent-runs/20260527T182451Z-git-head-consistency-task-TASK-127-p74504.md/json`
- Preflight: `docs/TASKS/EVIDENCE/TASK-127/agent-runs/20260527T182451Z-preflight-require-head-consistency-task-TASK-127-p74500.md/json`

## Inventory verdict

Available baseline automation:

- `help-json` / `list commands-json`
- `config validate`
- `git head-consistency`
- `preflight --require-head-consistency`
- iOS build/test/smoke base commands
- Android build/test/smoke base commands
- existing TASK-126 scanners/tests
- generic `scan sensitive`, `scan evidence`, `scan repo-diff`, `scan source-format`
- report JSON/Markdown pipeline

Missing or insufficient for TASK-127:

- `ios test options-summary-performance`
- `ios test options-summary-provider`
- `ios smoke options-performance`
- `android audit options-performance`
- `scan options-mainactor-heavy-fetch`
- `scan productprice-full-fetch-mainactor`
- `scan options-refresh-debounce`
- `scan task127-debug-hook-release-safety`
- `scan task127-final-gates`
- TASK-127 scanner fixtures under `tools/agent/fixtures/task127_scanners/`
- TASK-127 README/MCP command catalog entries

Supabase status: no Supabase command was executed in Phase -1, and no live mutation/cleanup/migration was performed.
