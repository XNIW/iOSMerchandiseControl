# TASK-127 Phase -1 — Command Namespace Normalization

- RESULT: PASS
- EXIT_CODE: 0
- REPORT_MD: `docs/TASKS/EVIDENCE/TASK-127/-1-04-command-namespace-normalization.md`
- REPORT_JSON: `docs/TASKS/EVIDENCE/TASK-127/-1-04-command-namespace-normalization.json`
- NEXT_ACTION: Register scanners under top-level `scan`, not under `ios`.

## Rule confirmed

The dispatcher routes scanner commands through the top-level `scan` case. Unknown scanners return `MISCONFIGURED`. The `ios` namespace handles build/test/smoke/live wrappers and must not document or implement `ios scan ...`.

Expected TASK-127 namespaces:

- `ios test options-summary-performance`
- `ios test options-summary-provider`
- `ios smoke options-performance`
- `android audit options-performance`
- `scan options-mainactor-heavy-fetch`
- `scan productprice-full-fetch-mainactor`
- `scan options-refresh-debounce`
- `scan task127-debug-hook-release-safety`
- `scan task127-final-gates`

Forbidden namespace:

- `ios scan ...`
