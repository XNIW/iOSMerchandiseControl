# TASK-117 - 12 Automation Harness Baseline

## Status
Baseline harness commands executed on 2026-05-23.

Each command result must include:
- `RESULT`
- `EXIT_CODE`
- `REPORT_MD`
- `REPORT_JSON`
- `NEXT_ACTION`

## Baseline Commands

| Command | RESULT | EXIT_CODE | REPORT_MD | REPORT_JSON | NEXT_ACTION |
|---|---:|---:|---|---|---|
| `./tools/agent/mc-agent.sh preflight --task TASK-117` | PASS | 0 | `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T210545Z-preflight-task-TASK-117-p44214.md` | `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T210545Z-preflight-task-TASK-117-p44214.json` | Run build/test commands. |
| `./tools/agent/mc-agent.sh config validate --task TASK-117` | PASS | 0 | `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T210545Z-config-validate-task-TASK-117-p44216.md` | `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T210545Z-config-validate-task-TASK-117-p44216.json` | Run preflight. |
| `./tools/agent/mc-agent.sh list commands-json` | PASS | 0 | stdout JSON | n/a | Revealed TASK-117-specific strict commands are missing. |
| `./tools/agent/mc-agent.sh help-json` | PASS | 0 | stdout JSON | n/a | Revealed TASK-117-specific strict commands are missing. |
| `./tools/agent/mc-agent.sh scan no-legacy-runtime-path --task TASK-117` | PASS | 0 | `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T210553Z-scan-no-legacy-runtime-path-task-TASK-117-p45054.md` | `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T210553Z-scan-no-legacy-runtime-path-task-TASK-117-p45054.json` | Run live no-legacy-runtime-path and no-full-pull-normal-path. |
| `./tools/agent/mc-agent.sh scan sensitive --task TASK-117` | PASS | 0 | `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T210553Z-scan-sensitive-task-TASK-117-p45053.md` | `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T210553Z-scan-sensitive-task-TASK-117-p45053.json` | Run scan evidence or continue validation. |
| `./tools/agent/mc-agent.sh scan evidence --task TASK-117` | PASS | 0 | `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T210553Z-scan-evidence-task-TASK-117-p45067.md` | `docs/TASKS/EVIDENCE/TASK-117/agent-runs/20260523T210553Z-scan-evidence-task-TASK-117-p45067.json` | Use evidence in TASK-117 closure matrix. |

## Harness Gap

The baseline `scan no-legacy-runtime-path` reports PASS, but TASK-117 planning and source audit require a stricter source/call-graph gate. This baseline PASS is not accepted as final CA-117-20 evidence.

Missing or insufficient commands to create/improve before relying on them:
- `scan automatic-contracts-clean`
- `scan root-host-clean`
- `scan options-observer-only`
- `scan duplicate-sync-owner`
- `scan incremental-apply-contract`
- `scan swiftdata-mainactor-heavy`
- `scan l10n-sync-keys`
- `harness doctor`
- `evidence bundle`
- `sync doctor`

## Next Action
Audit and improve the harness before final strict scans.
