# TASK-127 Phase -1 — Command Catalog Gap Analysis

- RESULT: PASS_WITH_NOTES
- EXIT_CODE: 0
- REPORT_MD: `docs/TASKS/EVIDENCE/TASK-127/-1-01-command-catalog-gap-analysis.md`
- REPORT_JSON: `docs/TASKS/EVIDENCE/TASK-127/-1-01-command-catalog-gap-analysis.json`
- NEXT_ACTION: Add TASK-127 commands to dispatcher/help-json before relying on them as final evidence.

## Classification

| Command | Classification | Reason |
|---|---|---|
| `ios test options-summary-performance` | MISSING | Not listed in `help-json`; not handled by `mc_ios_test`. |
| `ios test options-summary-provider` | MISSING | Not listed in `help-json`; not handled by `mc_ios_test`. |
| `ios smoke options-performance` | MISSING | Not listed in `help-json`; not handled by `mc_ios_smoke`. |
| `android audit options-performance` | MISSING | `mc_cmd_android` has no `audit` subcommand. |
| `scan options-mainactor-heavy-fetch` | MISSING | Dispatcher top-level `scan` does not route this scanner. |
| `scan productprice-full-fetch-mainactor` | MISSING | Dispatcher top-level `scan` does not route this scanner. |
| `scan options-refresh-debounce` | MISSING | Dispatcher top-level `scan` does not route this scanner. |
| `scan task127-debug-hook-release-safety` | MISSING | Dispatcher top-level `scan` does not route this scanner. |
| `scan task127-final-gates` | MISSING | Dispatcher top-level `scan` does not route this scanner. |
| `scan scanner-self-tests --task TASK-127` | INCOMPLETE | Existing route delegates to old task scanner unless TASK-126; needs TASK-127 fixture semantics. |

## Notes

- Existing `ios smoke options` is functional/reachability only and cannot be used as TASK-127 performance evidence.
- Existing TASK-126 tests/scanners remain supporting regression evidence, not substitutes for TASK-127 gates.
