# TASK-117 Evidence README

## Scope
Execution evidence pack for `TASK-117: iOS Sync Final Architecture Cleanup`.

Current status: `ACTIVE / BLOCKED_EXTERNAL_LIVE_GATES`.

Initial files `00`-`09` are planning-only evidence from the prior planning reinforcement. Files `10+` are execution evidence produced after the explicit user override on 2026-05-23.

## Files
- `00-planning-summary.md`: planning status, scope, blocker summary.
- `01-head-raw-consistency-audit.md`: P0 HEAD/raw/rendered consistency evidence.
- `02-call-graph-inventory.md`: current source call graph and legacy automatic path inventory.
- `03-legacy-file-classification.md`: legacy/dead-code classification for future execution.
- `04-target-architecture-contract.md`: final architecture contract and strict scan rules.
- `05-risk-regression-matrix.md`: app, sync, UX and operator regression matrix.
- `06-execution-slices-and-gates.md`: future execution slices S117-A...S117-O.
- `07-no-delete-before-test-policy.md`: no-delete-before-test cleanup policy.
- `08-automation-harness-plan.md`: canonical harness and command reporting contract.
- `09-command-gap-backlog.md`: commands to create or improve before relying on them as gates.
- `10-execution-start.md`: user override, P0 consistency rerun, dirty baseline classification.
- `11-preflight-and-baseline.md`: baseline preflight/config/status and HEAD/raw/rendered comparison summary.
- `12-automation-harness-baseline.md`: canonical harness baseline command results.
- `13-call-graph-execution-audit.md`: execution call graph audit.
- `14-legacy-dependency-map.md`: legacy file classification and dependency map.
- `15-automatic-contract-cleanup.md`: automatic contract cleanup evidence.
- `16-contentview-root-host-cleanup.md`: root host cleanup evidence.
- `17-options-observer-only-cleanup.md`: Options observer-only evidence.
- `18-manual-sync-boundary.md`: manual sync boundary evidence.
- `19-incremental-apply-cleanup.md`: incremental pull/apply cleanup evidence.
- `20-outbox-ownership.md`: outbox ownership evidence.
- `21-dead-code-removal-or-retention.md`: dead-code removal/retention evidence.
- `22-build-test-smoke-results.md`: build/test/smoke results.
- `23-live-device-supabase-results.md`: live/device/Supabase gate results.
- `24-cleanup-residue-results.md`: cleanup and residue evidence.
- `25-security-evidence-scan.md`: sensitive/evidence scan evidence.
- `26-final-acceptance-matrix.md`: final CA matrix.
- `27-final-handoff.md`: final execution handoff.

## One-line commands for future agents
```bash
./tools/agent/mc-agent.sh preflight --task TASK-117
./tools/agent/mc-agent.sh config validate --task TASK-117
./tools/agent/mc-agent.sh list commands-json
./tools/agent/mc-agent.sh help-json
./tools/agent/mc-agent.sh scan no-legacy-runtime-path --task TASK-117
./tools/agent/mc-agent.sh scan no-full-pull-normal-path --task TASK-117
./tools/agent/mc-agent.sh ios build debug --task TASK-117
./tools/agent/mc-agent.sh ios build release --task TASK-117
./tools/agent/mc-agent.sh ios test sync --task TASK-117
./tools/agent/mc-agent.sh ios smoke simulator --task TASK-117
./tools/agent/mc-agent.sh ios smoke options --task TASK-117
./tools/agent/mc-agent.sh scan sensitive --task TASK-117
./tools/agent/mc-agent.sh scan evidence --task TASK-117
./tools/agent/mc-agent.sh report --latest --task TASK-117
```

## Operator rules
- Use `./tools/agent/mc-agent.sh` as canonical CLI.
- MCP is only a thin adapter over the CLI contract.
- Do not rebuild long manual shell commands when a harness command exists.
- Every report must include `NEXT_ACTION`.
- Do not commit noisy raw logs.
- TASK-117 is `ACTIVE / BLOCKED_EXTERNAL_LIVE_GATES`: local architecture cleanup PASS, external live/device/tooling gates blocked.
- TASK-116 remains `ACTIVE / REVIEW`, not `DONE`.
- TASK-115 remains `BLOCKED / SUPERSEDED_BY_TASK-116`.
