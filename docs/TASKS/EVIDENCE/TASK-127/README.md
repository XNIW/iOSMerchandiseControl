# TASK-127 Evidence

Evidence directory for TASK-127: iOS Options Responsiveness and Sync Summary Performance Hardening.

## Stato execution corrente

- Task status: `ACTIVE / REVIEW`
- Created: 2026-05-27
- Runtime fixes: iOS Options summary responsiveness hardening implemented.
- Swift changes: yes, scoped to Options summary/status path and tests.
- Kotlin/SQL changes: none.
- Supabase mutation: none.
- Physical iPhone performance: not run; no real-device PASS claimed.

## Execution summary

- Harness TASK-127 commands/scanners/MCP/README implemented.
- Scanner RED/GREEN self-tests PASS.
- iOS targeted tests PASS.
- iOS Debug/Release PASS.
- Android audit verdict: `NO_RUNTIME_PATCH_REQUIRED`.
- TASK-126 supporting invariants PASS; TASK-126 remains DONE.
- Final evidence: `58-*`, `59-*`, `60-*`, `61-*`.

## Evidence naming plan

Phase -1:

- `-1-00-automation-inventory.md/json`
- `-1-01-command-catalog-gap-analysis.md/json`
- `-1-02-mcp-allowlist-gap-analysis.md/json`
- `-1-03-task127-tooling-decision.md/json`
- `-1-04-command-namespace-normalization.md/json`

Phase 0:

- `00-preflight.md/json`
- `01-source-baseline.md/json`
- `02-harness-discovery.md/json`

Phase 0b:

- `03-harness-implementation-plan.md/json`
- `04-command-catalog-task127-plan.md/json`
- `05-mcp-task127-plan.md/json`
- `06-scanner-fixtures-red-green-plan.md/json`

Phase 1:

- `10-ios-options-freeze-reproduction.md/json`
- `11-ios-main-thread-stall-profile.md/json`
- `12-ios-summary-refresh-call-count.md/json`
- `13-ios-productprice-count-cost.md/json`
- `14-local-synthetic-dataset-plan.md/json`
- `15-performance-baseline-schema.md/json`
- `16-productprice-summary-semantics-adr.md/json`
- `17-summary-cache-stale-policy.md/json`
- `18-baseline-vs-postfix-comparison-contract.md/json`

Phase 2:

- `20-ios-fix-design.md/json`
- `21-ios-summary-provider-threading-plan.md/json`
- `22-ios-pending-query-plan.md/json`
- `23-ios-options-ui-loading-state-plan.md/json`
- `24-test-layering-plan.md/json`

Phase 3:

- `30-harness-plan.md/json`
- `31-performance-budget.md/json`
- `32-scanner-plan.md/json`
- scanner RED/GREEN fixture reports for:
  - `options-mainactor-heavy-fetch`
  - `productprice-full-fetch-mainactor`
  - `options-refresh-debounce`
  - `task127-debug-hook-release-safety`
  - command catalog exposure
- `37-dispatcher-routing-task127.md/json`
- `38-readme-command-catalog-task127.md/json`
- `39-mcp-allowlist-task127.md/json`
- `40-task127-scanner-fixtures.md/json`
- `41-task127-scanner-selftest-results.md/json`
- `42-performance-redaction-audit.md/json`

Phase 4:

- `40-android-options-performance-audit-plan.md/json`
- `41-android-productprice-summary-risk.md/json`
- `42-android-parity-no-regression-plan.md/json`
- `43-android-options-audit-verdict.md/json`

Phase 5:

- `50-sync-policy-regression-plan.md/json`
- `51-task126-invariants-preserved.md/json`

Final execution/review evidence, when execution is explicitly authorized:

- `58-plan-vs-execution-delta.md/json`
- `59-final-performance-comparison.md/json`
- `60-ios-build-test-results.md/json`
- `60-final-review-handoff.md/json`
- `61-ios-options-performance-smoke.md/json`
- `61-final-sensitive-evidence-repo-diff.md/json`
- `62-android-options-audit-results.md/json`
- `63-sensitive-scan.md/json`
- `64-review-handoff.md/json`
- `65-task127-final-gates.md/json`
- `66-review-done-gate-status.md/json`

## Required performance metrics

Every Options performance report must include:

- dataset size: products, suppliers, categories, productPrices, historySessions, pendingChanges;
- auth state: signed out or signed in;
- TASK-126 store mode: `localDefaultStoreOnly`;
- device target: simulator or physical;
- cold/warm state;
- tap Options -> first visual frame ms;
- tap Options -> interactive Form ms;
- max main-thread stall ms;
- summary refresh duration ms;
- ProductPrice count duration ms;
- pending count duration ms;
- refresh invocations within 1 second;
- remote drift fetch state: disabled/nil/slow/failure/success;
- redacted raw logs and screenshot/UI proof when relevant.

## Baseline vs post-fix contract

Future performance JSON must include comparable `baseline`, `postFix` and `delta` blocks. If baseline cannot be measured because of external tooling limits, the report must explicitly use `PASS_WITH_NOTES`, explain the limitation, and avoid claiming "faster" as a proven result.

Performance datasets must be local/synthetic or read-only. Do not create Supabase data for performance. Use XCTest in-memory/local SwiftData or DEBUG-only simulator local seed with prefix `TASK127_PERF_`.

## Summary cache/stale policy

If a summary cache is introduced, evidence must cover:

- `isLoading`
- `isStale`
- `lastRefreshedAt`
- `source`
- `refreshReason`
- `coalescedEvents`
- no false green state while summary or drift is stale/unknown.

## Command namespace reminders

- Scanner commands use top-level `scan`, not `ios scan`.
- Expected scanner examples:
  - `./tools/agent/mc-agent.sh scan options-mainactor-heavy-fetch --task TASK-127 --strict`
  - `./tools/agent/mc-agent.sh scan productprice-full-fetch-mainactor --task TASK-127 --strict`
  - `./tools/agent/mc-agent.sh scan options-refresh-debounce --task TASK-127 --strict`
- iOS namespace is for build/test/smoke/live, for example:
  - `./tools/agent/mc-agent.sh ios test options-summary-performance --task TASK-127`
  - `./tools/agent/mc-agent.sh ios test options-summary-provider --task TASK-127`
  - `./tools/agent/mc-agent.sh ios smoke options-performance --task TASK-127`

## Android audit verdicts

Android audit must end with exactly one actionable verdict:

- `NO_RUNTIME_PATCH_REQUIRED`
- `CHANGES_REQUIRED_OPTIONS_STATUS_THREADING`
- `CHANGES_REQUIRED_PRODUCTPRICE_SUMMARY_COST`
- `BLOCKED_EXTERNAL_ANDROID_ENV`
- `MISCONFIGURED_REPO_OR_GRADLE`

## Review gate reminders

- Mandatory `NOT_RUN` blocks REVIEW.
- `PASS_WITH_NOTES` is allowed only for external tooling limits with equivalent fallback evidence.
- `BLOCKED_EXTERNAL` requires a concrete next action.
- `DONE` requires independent review and explicit user acceptance; Execution PASS alone is not DONE.
- Simulator-only performance PASS is not a real-device PASS.

## Guardrails

- Do not record a PASS without command output, measured evidence or explicit reviewer/user acceptance.
- Do not store secrets, user data, unredacted account IDs, barcodes from real shop data or Supabase credentials.
- Use Markdown plus JSON pairs for repeatable harness output where possible.
- Each report should include `RESULT`, `EXIT_CODE`, `REPORT_MD`, `REPORT_JSON` and `NEXT_ACTION` when generated by wrapper commands.
- Supabase checks, if any, must be read-only.

## Review evidence — 2026-05-27

Final review verdict: `ACTIVE / REVIEW — REVIEW_PASS_WITH_NOTES`.

Review evidence files:

- `70-review-preflight.md/json`
- `71-review-code-quality.md/json`
- `72-review-harness-quality.md/json`
- `73-review-performance-validation.md/json`
- `74-review-sync-safety-regression.md/json`
- `75-review-android-audit.md/json`
- `76-review-security-redaction.md/json`
- `77-review-fix-log.md/json`
- `78-review-final-verdict.md/json`

Review fixes applied:

- Pending attention count is owner/store/localStore scoped via `fetchCount`.
- Coalesced Options summary refreshes are replayed after the active refresh finishes.
- Provider/local summary tests cover the review fixes and deterministic async behavior.
- Options performance smoke/final gate now require `PASS_WITH_NOTES` when UI tap metrics are missing.

Accepted review notes:

- Baseline tap pre-fix is not numeric.
- Options smoke is artifact/static/XCTest-backed, not a real simulator tap timing probe.
- No iPhone physical run was executed; no real-device PASS is claimed.
- Supabase remained read-only with no mutation, migration or cleanup.

## DONE closure — 2026-05-27

Closure verdict: `DONE con note accettate, nessun claim real-device`.

Closure evidence:

- `79-done-closure-accepted-notes.md/json`

Accepted notes carried into DONE:

- Baseline tap pre-fix is not numeric.
- Options smoke is artifact/static/XCTest-backed, not a real simulator tap timing probe.
- No iPhone physical run was executed.
- No real-device PASS or production-ready global claim is made.
- Supabase remained read-only with no mutation, migration or cleanup.
