# TASK-123 Evidence

Task: `TASK-123` — iOS/Android Simulator AutoSync Speed Acceptance.

Status: ACTIVE / EXECUTION.

## Required Evidence Files
- `canonical-head.md`
- `canonical-head.json`
- `preflight.md`
- `preflight.json`
- `harness-discovery.md`
- `harness-discovery.json`
- `simulator-auth-readiness.md`
- `simulator-auth-readiness.json`
- `ios-options-review-gate.md`
- `ios-options-review-gate.json`
- `autosync-speed-ios-to-android.md`
- `autosync-speed-ios-to-android.json`
- `autosync-speed-android-to-ios.md`
- `autosync-speed-android-to-ios.json`
- `autosync-speed-summary.md`
- `autosync-speed-summary.json`
- `outbox-pending-drain.md`
- `outbox-pending-drain.json`
- `drift-reconciliation.md`
- `drift-reconciliation.json`
- `cleanup-residue.md`
- `cleanup-residue.json`
- `final-acceptance-matrix.md`
- `final-acceptance-matrix.json`
- `fix-log.md`
- `final-handoff.md`

## Safety Scope
- Runtime data prefix only: `TASK123_SPEED_*` or `TASK123_AUTOSYNC_*`.
- No real user data deletion.
- No `auth.users` deletion.
- No client `service_role`.
- No RLS bypass in client.
- Cleanup must be dry-run first and scoped to `TASK123_*`.

## Agent Runs
Machine command outputs belong under `agent-runs/` when produced by `tools/agent/mc-agent.sh`.

