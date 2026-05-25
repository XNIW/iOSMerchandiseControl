# TASK-123 Final Acceptance Matrix

Timestamp: 2026-05-25T03:22Z.

This is the current executor matrix after iOS login and targeted fixes. It is **not** a 100% final acceptance claim because the required 20+20 warm latency matrix, cold-ish restart matrix, no-op checks and burst-10 scenario were not completed.

| Gate | Result | Evidence |
| --- | --- | --- |
| Tracking TASK-123 | PASS | task file + `README.md` |
| GitHub/local/origin head consistency | PASS | `canonical-head.md/json` |
| Preflight/config/harness discovery | PASS | `preflight.md/json`, `harness-discovery.md/json`, config reports |
| Architecture regression guards | PASS_WITH_NOTES | `architecture-guard-rerun.md`, scanner reports |
| iOS auth/session | PASS | `simulator-auth-readiness.md/json` |
| Android auth/session | PASS | `simulator-auth-readiness.md/json` |
| iOS Options Review gate | PASS | `ios-options-review-gate.md/json` |
| iOS -> Android receiver autosync | PASS | p50 0.962s, p95 1.015s, max 1.028s |
| Android -> iOS receiver autosync | PASS | p50 0.409s, p95 0.444s, max 0.452s |
| iOS -> Android strict full speed acceptance | NOT_COMPLETE | only 5 post-fix smoke samples; batch p50 4.555s contains multiple writes |
| Android -> iOS strict full speed acceptance | NOT_COMPLETE | only 5 post-fix smoke samples; batch p50 13.619s and max 18.724s contain multiple serial writes |
| Timeout count | PASS | 0 in post-tuning smoke runs |
| Duplicate count | PASS | 0 targeted-events missing/duplicate failures observed in post-tuning runs |
| Pending/outbox stuck | PASS_WITH_NOTES | task-scoped residue 0; non-TASK123 user simulator pending left untouched |
| Drift/residue final `TASK123_*` | PASS | Supabase 0, Android local 0, iOS local 0 |
| Supabase schema/RLS/grants mutation | PASS | no schema/RLS/grant/RPC changes |

## Verdict
- Architecture regression: PASS.
- iOS simulator auth/session: PASS.
- Android emulator auth/session: PASS.
- iOS Options Review gate: PASS.
- AutoSync iOS -> Android speed: FAIL for strict full TASK-123 acceptance, PASS for receiver smoke.
- AutoSync Android -> iOS speed: FAIL for strict full TASK-123 acceptance, PASS for receiver smoke.
- Runtime efficiency: PASS_WITH_NOTES.
- Production readiness within simulator same-account scope: PASS_WITH_NOTES, not full production/global readiness.
- 100% user claim: NOT_ELIGIBLE.

NEXT_ACTION: add or run an in-process warm latency harness that executes 20 isolated local-write propagations per direction without reinstall/relaunch overhead, then run cold-ish restart/no-op/burst checks and update this matrix.
