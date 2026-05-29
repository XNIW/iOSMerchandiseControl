# TASK-131 Final Review Checklist

Final state: `ACTIVE / BLOCKED — PHYSICAL_REVIEW_ACCESSIBILITY_OPERATOR_EVIDENCE_REQUIRED`

This checklist is a handoff artifact, not a REVIEW approval. Mandatory P0 data-path gates now have full physical evidence, and account-switch policy cases that do not require account B now have PASS evidence. TASK-131 remains blocked because mandatory physical UX/operator evidence is missing. True Account A -> B cases C126-14/15/16/17/40 remain case-level `BLOCKED_EXTERNAL_SECOND_ACCOUNT`.

| Area / C126 range | Scope | Result | Evidence / note |
|---|---|---:|---|
| C126-00..02 auth/session | iPhone physical + Android physical | PASS | Device readiness, launch, Options/auth smoke PASS on both physical devices. |
| C126-03..06 normal sync | Full physical | PASS | `TASK131_POLICY_FIX9_`: bidirectional Product/ProductPrice/History propagation, local/remote dirty, merge different fields. |
| C126-07..09 conflict basics | Policy/UI contract + physical operator pending | BLOCKED_EXTERNAL | Static policy/UI contract PASS; physical tap checklist missing. |
| C126-10..13 offline/reconnect/ack | Full physical | PASS | `TASK131_OFFLINE_FIX6_`: offline/reconnect, kill/restart pending, network flap no false ack. |
| C126-14..19 account switch/auth transition | Full physical + split account policy | MIXED | Same-account logout/login and token/session fail-closed PASS in `TASK131_ACCOUNT_SPLIT2_`; true A->B C126-14/15/16/17 remain `BLOCKED_EXTERNAL_SECOND_ACCOUNT`. |
| C126-20..21 RLS/schema/protocol | Supabase read-only + app safety | PASS | schema/RLS/grants/RPC/realtime/price read-only PASS; no RLS bypass scan PASS. |
| C126-22..26 Review/ProductPrice stale | Mixed | BLOCKED_EXTERNAL | ProductPrice append/dedupe/data path PASS; stale/review physical tap evidence missing. |
| C126-27 cursor gap/reset | Offline/recovery path | PASS | Covered by offline/reconnect/restart/flap matrix where available; remote reset remains policy-bound if OS/tooling cannot force. |
| C126-28..32 store/cache/pending scope | Full physical + scans | PASS | `localDefaultStoreOnly`; no cross-owner/store pending push scan PASS; pending final 0. |
| C126-33..34 permission/protocol fail-closed | Supabase/app safety | PASS | RLS/grants read-only PASS, no RLS bypass PASS; no migration/grant weakening. |
| C126-35..40 account switch dirty/legacy | Full physical + split account policy | MIXED | Owner mismatch, legacy/unbound dirty Review/Recovery and export/cancel PASS in `TASK131_ACCOUNT_SPLIT2_`; C126-40 true B-populated decision remains `BLOCKED_EXTERNAL_SECOND_ACCOUNT`. |
| C126-41..43 no-op/burst/realtime | Full physical | PASS | no-op/no-full-pull PASS, burst 10 PASS, realtime/safety loop status PASS. |
| C126-44..48 legacy/cache/permission | Full physical + scans | PASS | no cross-owner/store pending push PASS; cleanup only scoped; no service-role client. |
| C126-49..54 Options/Review/accessibility | Physical UX | BLOCKED_EXTERNAL | Options smoke PASS; Conflict/Review and accessibility operator checklists missing. |
| C126-55..57 background/locked/long offline | Physical | PASS_WITH_BLOCKED_SUBCASE | Offline/reconnect/restart/flap PASS; iOS BGTask scheduler subcase `BLOCKED_EXTERNAL_IOS_SCHEDULER_POLICY`. |
| C126-58 sensitive evidence | Static/report | PASS | redaction/sensitive/evidence/JSON validation PASS. |
| C126-59 cleanup/residue | Supabase/Android/iOS scoped | PASS_WITH_IOS_LOCAL_NOTE | Supabase residue 0, Android local cleanup PASS, iOS local cleanup dry-run only. |
| C126-60 final drift/pending/duplicates | Full physical | PASS | drift 0, pending 0, duplicate ProductPrice 0 from `TASK131_POLICY_FIX9_`. |

## P0 Mandatory Verdict

| Gate | Result |
|---|---:|
| iPhone physical build/install/launch/auth/options | PASS |
| Android physical build/install/launch/auth/options | PASS |
| Local dirty push / remote dirty pull | PASS |
| Merge different fields | PASS |
| Same-field conflict Review physical tap | BLOCKED_EXTERNAL |
| Delete-vs-edit Review physical tap | BLOCKED_EXTERNAL |
| ProductPrice append/dedupe/stale data invariant | PASS for append/dedupe/data; stale Review tap BLOCKED_EXTERNAL |
| Offline/reconnect | PASS |
| Kill/restart pending | PASS |
| Account switch clean/dirty | PASS for same-account/local-fixture/export/cancel/legacy; `BLOCKED_EXTERNAL_SECOND_ACCOUNT` only for C126-14/15/16/17/40 |
| Options no false updated | PASS for smoke/data states; Review/accessibility physical checklist still blocked |
| No full pull normal path | PASS |
| No cross-owner/store pending push | PASS |
| Cleanup/residue `TASK131_*` | PASS / Supabase residue 0 |

## Final Gate Verdict

- `task131-final-gates`: PASS as a blocker-aware validation report, with evidence `agent-runs/20260529T031816Z-scan-task131-final-gates-task-TASK-131-strict-p74496.json`.
- REVIEW full acceptance: not allowed yet because physical Conflict/Review operator evidence and accessibility operator evidence are still missing.
- DONE: not allowed.
- Full production-ready claim: not made.

## Codex Review Addendum 2026-05-29

- Review/fix override executed by Codex; this is still not a REVIEW approval.
- New checklist template created: `operator-review-accessibility-checklist.md` / `.json`.
- Latest account split rerun PASS blocker-aware: `agent-runs/20260529T030217Z-physical-account-switch-matrix-task-TASK-131-prefix-TASK131_REVIEW_ACCOUNT_-p77663.json`.
- Latest Conflict/Review rerun remains `BLOCKED_EXTERNAL`: `agent-runs/20260529T030338Z-physical-conflict-review-matrix-task-TASK-131-prefix-TASK131_REVIEW_CONFLICT_-p80048.json`.
- Latest accessibility rerun remains `BLOCKED_EXTERNAL`: `agent-runs/20260529T030624Z-physical-accessibility-smoke-task-TASK-131-p83429.json`.
- Security/evidence reruns PASS after redaction cleanup: `agent-runs/20260529T031618Z-scan-task131-redaction-task-TASK-131-strict-p2066.json`, `agent-runs/20260529T031618Z-scan-sensitive-task-TASK-131-docs-TASKS-EVIDENCE-TASK-131-p2069.json`, `agent-runs/20260529T031618Z-scan-evidence-task-TASK-131-p2068.json`.
- Final blocker-aware gates rerun PASS: `agent-runs/20260529T031442Z-scan-task131-matrix-completeness-task-TASK-131-strict-p99127.json`, `agent-runs/20260529T031816Z-scan-task131-final-gates-task-TASK-131-strict-p74496.json`.

## Required Next Evidence

1. Redacted physical Conflict/Review operator checklist or reliable UI automation for same-field conflict, delete-vs-edit, ProductPrice stale reject and cancel/destructive actions.
2. Redacted VoiceOver/TalkBack traversal checklist or automation for Options, Account Decision, Conflict Review, badges and destructive actions.
3. Second synthetic test account for only the true A->B cases C126-14/15/16/17/40.
4. Rerun blocked matrices, final gates and cleanup/residue if new `TASK131_*` data is created.
