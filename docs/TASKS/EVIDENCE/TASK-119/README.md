# TASK-119 Evidence

Evidence directory for TASK-119.

## Current phase
- **Task**: TASK-119 - iOS Sync Automatic Architecture Purification and Dead-Code Cleanup
- **Status**: ACTIVE / EXECUTION-AUDIT — HARNESS_BASELINE_COMPLETE / BLOCKED_HEAD_OR_TRACKING_MISMATCH_FOR_SWIFT_REFACTOR
- **Existing evidence**: initial HEAD/preflight/config reports, tracking-mismatch documentation, TASK-119 harness scan reports, baseline architecture audit, `ios test automatic-architecture`, and JSON validation under `agent-runs/`.
- **Runtime verification**: PARTIAL. TASK-119 automatic-architecture test PASS; broad build/sync/smoke gates are NOT_RUN.
- **Swift refactor evidence**: NOT_RUN. Production Swift refactor is blocked by `BLOCKED_HEAD_OR_TRACKING_MISMATCH` until local-only tracking is resolved or explicitly accepted.
- **Build evidence**: NOT_RUN for Debug/Release in current harness-first phase.
- **Supabase live evidence**: NOT_RUN; no live gate requested or executed.
- **Cleanup evidence**: NOT_RUN / not required; no live synthetic rows created.

No command in this README is claimed as executed for TASK-119 unless a `.md/.json/.log` report exists under `agent-runs/`.

## Existing execution-audit evidence
- HEAD consistency: `agent-runs/20260524T020448Z-git-head-consistency-task-TASK-119-p40486.{md,json,log}`
- Preflight with HEAD consistency: `agent-runs/20260524T020448Z-preflight-require-head-consistency-task-TASK-119-p40485.{md,json,log}`
- Config validate: `agent-runs/20260524T020448Z-config-validate-task-TASK-119-p40487.{md,json,log}`
- Tracking mismatch: `agent-runs/20260524T020520Z-execution-audit-tracking-mismatch.{md,json,log}`
- Sync architecture scan baseline: `agent-runs/20260524T021325Z-scan-sync-architecture-task-TASK-119-strict-p45340.{md,json,log}` — FAIL baseline debt.
- Manual boundary scan baseline: `agent-runs/20260524T021325Z-scan-manual-boundary-task-TASK-119-strict-p45343.{md,json,log}` — FAIL baseline debt.
- Dead-code scan baseline: `agent-runs/20260524T021325Z-scan-dead-code-task-TASK-119-strict-p45341.{md,json,log}` — PASS, read-only.
- Xcode membership scan baseline: `agent-runs/20260524T021412Z-scan-xcode-membership-task-TASK-119-strict-p47330.{md,json,log}` — PASS.
- Automatic architecture test: `agent-runs/20260524T021419Z-ios-test-automatic-architecture-task-TASK-119-p47812.{md,json,log}` — PASS.
- Baseline architecture audit: `agent-runs/20260524T021620Z-baseline-architecture-audit-task-TASK-119.{md,json,log}` — PASS_WITH_NOTES.
- Sensitive scan: `agent-runs/20260524T021858Z-scan-sensitive-task-TASK-119-p51424.{md,json,log}` — PASS.
- Evidence scan: `agent-runs/20260524T021858Z-scan-evidence-task-TASK-119-p51442.{md,json,log}` — PASS.
- JSON validation latest: `agent-runs/20260524T021936Z-report-validate-json-task-TASK-119-path-docs-TASKS-EVIDENCE-TASK-119-agent-runs-p54031.{md,json,log}` — PASS.

## Current blocker
`BLOCKED_HEAD_OR_TRACKING_MISMATCH`: local HEAD/origin/GitHub branch all point to `3bcb58f9bb921e92b31f2c89de622ffbd6d11694`, but TASK-119 task/evidence tracking files are local-only and absent from `origin/main` / GitHub rendered `main`.

Per TASK-119 execution rules, production Swift refactor must not start until this is reconciled or explicitly accepted as local-only execution.

## Expected future evidence root
All future TASK-119 harness evidence must be written under:

```text
docs/TASKS/EVIDENCE/TASK-119/agent-runs/
```

Every future command must produce:
- `.md` human-readable report.
- `.json` schema `1.1` machine-readable report.
- `.log` redacted raw log.

Required fields:
- `NEXT_ACTION`
- `task_id` = `TASK-119`
- git SHA
- dirty state
- safety level
- result status
- command name/slug

Evidence outside `docs/TASKS/EVIDENCE/TASK-119/` is `MISCONFIGURED`.

## Status taxonomy
| Status | Meaning |
| --- | --- |
| PASS | Command ran, exit code 0, evidence `.md/.json/.log` exists, output redacted. |
| FAIL | Command ran, detected a real problem, exit code non-zero. |
| BLOCKED_EXTERNAL | External prerequisite missing, e.g. device locked, auth missing, Accessibility/JXA unavailable, live not allowed. |
| NOT_RUN | Intentionally not executed in this phase; cannot count as PASS. |
| PASS_WITH_NOTES | Allowed only when the note is non-blocking and explicitly accepted in Review/Done policy. |
| MISCONFIGURED | Wrong task id, wrong evidence path, missing config, malformed report, invalid env. |
| UNSAFE_OPERATION_REFUSED | Live/cleanup/destructive action refused by safety gate. |

Rules:
- `FAIL`, `MISCONFIGURED`, or `UNSAFE_OPERATION_REFUSED` block REVIEW unless expected and explicitly resolved.
- `BLOCKED_EXTERNAL` blocks DONE unless explicitly accepted by the user.
- `NOT_RUN` never counts as PASS.
- `PASS_WITH_NOTES` requires explicit review/done-policy acceptance.

## Command matrix and artifact expectations
Planning-only phase must not run build/test/live/cleanup commands. Future Execution must use canonical `./tools/agent/mc-agent.sh` wrappers when available.

| Area | Future command | Expected artifact |
| --- | --- | --- |
| HEAD | `./tools/agent/mc-agent.sh git head-consistency --task TASK-119` | `agent-runs/*git-head-consistency-task-TASK-119*.{md,json,log}` |
| Preflight | `./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-119` | `agent-runs/*preflight*TASK-119*.{md,json,log}` |
| Config | `./tools/agent/mc-agent.sh config validate --task TASK-119` | `agent-runs/*config-validate-task-TASK-119*.{md,json,log}` |
| Existing strict scan | `./tools/agent/mc-agent.sh scan sync-boundaries --task TASK-119 --strict` | `agent-runs/*scan-sync-boundaries-task-TASK-119*.{md,json,log}` |
| Existing full-pull scan | `./tools/agent/mc-agent.sh scan no-full-pull-normal-path --task TASK-119 --strict` | `agent-runs/*scan-no-full-pull-normal-path-task-TASK-119*.{md,json,log}` |
| New architecture scan | `./tools/agent/mc-agent.sh scan sync-architecture --task TASK-119 --strict` | `agent-runs/*scan-sync-architecture-task-TASK-119*.{md,json,log}` |
| New manual boundary scan | `./tools/agent/mc-agent.sh scan manual-boundary --task TASK-119 --strict` | `agent-runs/*scan-manual-boundary-task-TASK-119*.{md,json,log}` |
| New dead-code scan | `./tools/agent/mc-agent.sh scan dead-code --task TASK-119 --strict` | `agent-runs/*scan-dead-code-task-TASK-119*.{md,json,log}` |
| New Xcode membership scan | `./tools/agent/mc-agent.sh scan xcode-membership --task TASK-119 --strict` | `agent-runs/*scan-xcode-membership-task-TASK-119*.{md,json,log}` |
| iOS Debug build | `./tools/agent/mc-agent.sh ios build debug --task TASK-119` | `agent-runs/*ios-build-debug-task-TASK-119*.{md,json,log}` |
| iOS Release build | `./tools/agent/mc-agent.sh ios build release --task TASK-119` | `agent-runs/*ios-build-release-task-TASK-119*.{md,json,log}` |
| Automatic domain tests | `./tools/agent/mc-agent.sh ios test automatic-domain --task TASK-119` | `agent-runs/*ios-test-automatic-domain-task-TASK-119*.{md,json,log}` |
| Broad sync tests | `./tools/agent/mc-agent.sh ios test sync --task TASK-119` | `agent-runs/*ios-test-sync-task-TASK-119*.{md,json,log}` |
| New automatic architecture tests | `./tools/agent/mc-agent.sh ios test automatic-architecture --task TASK-119` | `agent-runs/*ios-test-automatic-architecture-task-TASK-119*.{md,json,log}` |
| Options smoke | `./tools/agent/mc-agent.sh ios smoke options --task TASK-119` | `agent-runs/*ios-smoke-options-task-TASK-119*.{md,json,log}` |
| Supabase redacted status | `./tools/agent/mc-agent.sh supabase status-redacted --task TASK-119` | `agent-runs/*supabase-status-redacted-task-TASK-119*.{md,json,log}` |
| Sensitive scan | `./tools/agent/mc-agent.sh scan sensitive --task TASK-119` | `agent-runs/*scan-sensitive-task-TASK-119*.{md,json,log}` |
| Evidence scan | `./tools/agent/mc-agent.sh scan evidence --task TASK-119` | `agent-runs/*scan-evidence-task-TASK-119*.{md,json,log}` |
| JSON validation | `./tools/agent/mc-agent.sh report validate-json --task TASK-119 --path docs/TASKS/EVIDENCE/TASK-119/agent-runs` | `agent-runs/*report-validate-json-task-TASK-119*.{md,json,log}` |
| Live reconcile | `MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live reconcile-counts --task TASK-119 --prefix TASK119_RECON_` | Only after explicit approval; otherwise BLOCKED_EXTERNAL/UNSAFE_OPERATION_REFUSED. |
| Live matrix | `MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live sync-matrix --task TASK-119 --prefix TASK119_FINAL_` | Only after explicit approval; otherwise BLOCKED_EXTERNAL/UNSAFE_OPERATION_REFUSED. |
| Cleanup dry-run | `./tools/agent/mc-agent.sh supabase cleanup --task TASK-119 --prefix TASK119_DRYRUN_ --dry-run` | Cleanup plan artifact if synthetic live rows exist. |
| Cleanup execute | `MC_ALLOW_CLEANUP=1 ./tools/agent/mc-agent.sh supabase cleanup --task TASK-119 --prefix TASK119_DRYRUN_ --execute --cleanup-plan-id <id>` | Execute artifact only after dry-run plan id. |
| Residue check | `./tools/agent/mc-agent.sh supabase residue-check --task TASK-119 --prefix TASK119_DRYRUN_ --profile linked` | Residue count 0 if synthetic live data was created. |

## Redaction requirements
Reports/logs/screenshots/JSON must redact:
- Supabase anon/service keys.
- JWT/token/password.
- Email addresses.
- Project ref.
- Local user home paths.
- Device IDs/serials.
- Raw `config.env` values.
- OAuth callback data.
- SQL/query payloads that expose personal data.
- Real customer data.

No report may contain unredacted `config.env`, OAuth callback data, JWT, service role, email, or real customer data.

## Safety policy
- Planning phase does not run cleanup/live gates.
- Cleanup future is allowed only for synthetic `TASK119_` prefixes and only through canonical harness.
- Cleanup execute requires prior dry-run `cleanup_plan_id`.
- Live future requires explicit user approval and `MC_ALLOW_LIVE=1`.
- Absence of `MC_ALLOW_LIVE=1` must be `BLOCKED_EXTERNAL` or `UNSAFE_OPERATION_REFUSED`, not PASS.
- Supabase contract validation is read-only for TASK-119; no tables, columns, RLS policies, grants, RPCs, migrations, or schema changes.

## Options smoke fallback
- Primary `ios smoke options` PASS is preferred.
- XcodeBuildMCP fallback may be supporting evidence.
- Fallback does not transform the primary harness gate into PASS if Accessibility/JXA is unavailable.
- That case remains `BLOCKED_EXTERNAL` unless explicitly accepted.
