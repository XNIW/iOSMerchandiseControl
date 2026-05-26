# TASK-125 Final Handoff

- Status: `FIX_REQUIRED`
- Phase: `ACTIVE / FIX — EXECUTABLE_SYNC_CONTRACT_GATE_FAILED`
- Redaction applied: `true`
- Generated: `2026-05-26T05:36:04Z`

Real-device Android retry completed: realtime/offline/restart/flapping/runtime parity/cleanup/scans are updated, but TASK-125 cannot enter REVIEW/DONE because executable/cross-platform final gates remain FAIL and iOS background debug-trigger/expiration evidence is missing.

## Current Evidence
- `PASS_WITH_NOTES_NETWORK_VARIANCE` — `docs/TASKS/EVIDENCE/TASK-125/real-device-realtime-matrix.json` — 24 iOS->Android + 20 Android->iOS; no full pull; drift zero; iOS->Android p95 within <=5s notes budget
- `PASS` — `docs/TASKS/EVIDENCE/TASK-125/offline-reconnect-matrix.json` — iOS/Android offline reconnect, incremental/event-based, pending zero
- `PASS` — `docs/TASKS/EVIDENCE/TASK-125/kill-restart-pending.json` — kill/restart pending matrix on physical devices
- `PASS` — `docs/TASKS/EVIDENCE/TASK-125/network-flapping.json` — network flapping matrix on physical devices
- `BLOCKED_EXTERNAL_IOS_SCHEDULER_POLICY` — `docs/TASKS/EVIDENCE/TASK-125/background-sync-matrix.json` — BGTask scheduled evidence exists; debug-trigger/expiration physical evidence still missing
- `PASS` — `docs/TASKS/EVIDENCE/TASK-125/final-runtime-parity.json` — iPhone physical + OnePlus + Supabase linked drift zero on active/user-visible counts
- `PASS` — `docs/TASKS/EVIDENCE/TASK-125/cleanup-plan.json` — TASK125_* cleanup dry-run plan
- `PASS` — `docs/TASKS/EVIDENCE/TASK-125/residue-check.json` — TASK125_* residue 0

## Open Failures
- executable-contract-gate-final.json remains FAIL
- cross-platform-architecture-gate-final.json remains FAIL
- cross-platform-final-gate-summary.json remains FAIL
- open-failures-zero-check.json remains FAIL
- background-sync-matrix.json remains BLOCKED_EXTERNAL_IOS_SCHEDULER_POLICY until BGTask debug-trigger/expiration evidence or explicit user acceptance

## Next Action
Implement/verify executable cross-platform contract gates to PASS, collect or explicitly accept iOS scheduler-policy background limitation, then rerun final evidence/redaction gates.
