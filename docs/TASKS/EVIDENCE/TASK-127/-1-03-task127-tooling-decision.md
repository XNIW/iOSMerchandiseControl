# TASK-127 Phase -1 — Tooling Decision

- RESULT: PASS
- EXIT_CODE: 0
- REPORT_MD: `docs/TASKS/EVIDENCE/TASK-127/-1-03-task127-tooling-decision.md`
- REPORT_JSON: `docs/TASKS/EVIDENCE/TASK-127/-1-03-task127-tooling-decision.json`
- NEXT_ACTION: Implement harness before Swift patch.

## Decision

Proceed with Phase 0 harness creation/hardening because TASK-127-specific performance wrappers and scanners are missing or incomplete. Do not use manual long commands as final evidence when a wrapper is required by the approved plan.

Minimum implementation set:

- iOS test suites: `options-summary-performance`, `options-summary-provider`
- iOS smoke: `options-performance`
- Android audit: `options-performance`
- top-level scanners: `options-mainactor-heavy-fetch`, `productprice-full-fetch-mainactor`, `options-refresh-debounce`, `task127-debug-hook-release-safety`, `task127-final-gates`
- TASK-127 scanner fixtures and self-test route
- README/help-json/MCP allowlist updates

No Swift/Kotlin app runtime patch is permitted until baseline and ADR are complete.
