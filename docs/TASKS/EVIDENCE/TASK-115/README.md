# TASK-115 Evidence Index

Evidence folder for TASK-115 iOS Sync Architecture Refactor.

## Status
- **Task**: TASK-115
- **Phase**: REVIEW
- **Scope**: iOS Sync Architecture Refactor, slice-based.
- **Runtime execution**: approved by user override on 2026-05-22 22:18 -0400.
- **Live/build/test gates**: non-live gates PASS; live/physical gates are recorded under `agent-runs/` with PASS/BLOCKED semantics.
- **DONE status**: not DONE; physical iPhone, runtime parity, near-realtime, offline reconnect and strict live account matrix still need PASS.

## Planned evidence files
- `00-summary.md` — planning summary, status ledger, and final review verdict.
- `01-android-reference-audit.md` — Android app-level sync architecture audit and reference behavior.
- `02-ios-current-audit.md` — current iOS sync/lifecycle/ViewModel/Options audit.
- `03-harness-automation-audit.md` — `mc-agent.sh`, MCP adapter, physical/simulator/device and live gate strategy.
- `04-architecture-proposal.md` — proposed iOS `Sync/` modules, state machine and data flow.
- `05-account-policy.md` — account/local-store policy A-L with tests and evidence requirements.
- `06-sync-state-machine.md` — triggers, actions, state transitions, single-flight and recovery/backoff semantics.
- `07-test-matrix.md` — unit, integration, physical, cross-platform, performance and regression matrix.
- `08-execution-slices.md` — S115-A..S115-L execution plan with commands, rollback and stop conditions.
- `09-risk-register.md` — risks, mitigations, owner, status and residual blockers.
- `10-reviewer-checklist.md` — planning review and future done checklist.
- `11-future-execution-prompt.md` — approved prompt templates for future S115-A review and S115-B execution.

## Evidence rules
- Do not store raw tokens, JWTs, emails, project refs, personal paths, device serials or real product/barcode data.
- Evidence for live gates must be produced by `./tools/agent/mc-agent.sh` where available.
- `PASS_WITH_NOTES` cannot satisfy critical sync/account/offline/physical iPhone acceptance criteria.
- Cleanup evidence must include dry-run, `cleanup_plan_id`, execute report and residue-check PASS/0.
- Supabase linked checks must be serial and back off on pooler/circuit-breaker errors.

## S115-A note
This README is created as part of S115-A markdown-only planning setup. It does not claim any runtime implementation, build/test PASS, live Supabase verification, cleanup or migration.

## Execution handoff note
Codex execution handoff was recorded on 2026-05-22 23:08 -0400. See `00-summary.md` and the task file handoff section for PASS/BLOCKED evidence.
