# TASK-131 Evidence

Task: `TASK-131 — Physical-device Sync Policy UI/UX Acceptance iOS + Android`

Current state: `ACTIVE / BLOCKED — PHYSICAL_REVIEW_ACCESSIBILITY_OPERATOR_EVIDENCE_REQUIRED`

Canonicality: `LOCAL_CANONICAL_AHEAD_OF_REMOTE` for the local worktree until commit/push/origin are explicitly aligned.

Execution note: the user approved Execution-completion on 2026-05-28 with iPhone physical available. The full physical scope is now `FULL_PHYSICAL_IOS_ANDROID_SCOPE`: iPhone physical and Android physical readiness/auth/options passed, full physical sync matrix `TASK131_POLICY_FIX9_` passed, offline/reconnect/restart/flap matrix `TASK131_OFFLINE_FIX6_` passed, account-switch split passed for all executable non-B subcases, and Supabase scoped cleanup/residue `TASK131_*` passed with residue 0. Codex review on 2026-05-29 found and fixed harness/redaction fragilities, reran the core review gates, and did not promote TASK-131 to REVIEW. Mandatory operator-assisted physical evidence is still missing for Conflict/Review taps and accessibility traversal. True Account A -> B cases C126-14/15/16/17/40 remain case-level `BLOCKED_EXTERNAL_SECOND_ACCOUNT`, not PASS.

Scope evidence:

- iPhone fisico reale;
- Android fisico reale;
- iOS Simulator di supporto;
- Supabase dev/linked con dati sintetici `TASK131_*`;
- report Markdown + JSON schema 1.1 prodotti da `tools/agent/mc-agent.sh`;
- screenshot/video/log redatti quando disponibili.

Rules:

- `NOT_RUN` mandatory is blocking and is not PASS.
- Simulator/emulator/static evidence can support audit only; it cannot satisfy physical acceptance.
- Cleanup must be scoped, dry-run first, execute only with `cleanup_plan_id`.
- No real data, no `auth.users`, no global cleanup, no client `service_role`.

Canonical commands:

```bash
./tools/agent/mc-agent.sh physical devices list --task TASK-131
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh ios physical sync-policy-ui --task TASK-131 --prefix TASK131_IOS_
./tools/agent/mc-agent.sh ios simulator sync-policy-ui --task TASK-131 --prefix TASK131_IOS_SIM_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh android physical sync-policy-ui --task TASK-131 --prefix TASK131_ANDROID_PHYS_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical sync-policy-matrix --task TASK-131 --prefix TASK131_POLICY_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical conflict-review-matrix --task TASK-131 --prefix TASK131_CONFLICT_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical account-switch-matrix --task TASK-131 --prefix TASK131_ACCOUNT_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical offline-background-matrix --task TASK-131 --prefix TASK131_OFFLINE_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical accessibility-smoke --task TASK-131
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical hybrid-sync-policy-matrix --task TASK-131 --prefix TASK131_HYBRID_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical hybrid-conflict-review-matrix --task TASK-131 --prefix TASK131_CONFLICT_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical hybrid-offline-reconnect-matrix --task TASK-131 --prefix TASK131_OFFLINE_
./tools/agent/mc-agent.sh physical hybrid-accessibility-smoke --task TASK-131
./tools/agent/mc-agent.sh scan task131-matrix-completeness --task TASK-131 --strict
./tools/agent/mc-agent.sh scan task131-redaction --task TASK-131 --strict
./tools/agent/mc-agent.sh scan task131-final-gates --task TASK-131 --strict
```

Expected subdirectories:

- `agent-runs/` — canonical command reports and redacted logs.
- `screenshots/` — physical device screenshots.
- `videos/` — physical device recordings.
- `cleanup/` — cleanup dry-run/execute/residue evidence.
- `quarantine-invalid/` — superseded invalid generated reports kept for traceability, not canonical PASS evidence.

Final handoff:

- `final-hybrid-execution-summary.md`
- `final-hybrid-execution-summary.json`
- `final-full-physical-execution-summary.md`
- `final-full-physical-execution-summary.json`
- `final-review-checklist.md`
- `final-review-checklist.json`

Current blocker summary:

- Full physical sync/offline core is PASS: `TASK131_POLICY_FIX9_` and `TASK131_OFFLINE_FIX6_`.
- Final drift is 0, pending aggregate is 0, duplicate ProductPrice is 0, no full pull normal path scan PASS, no cross-owner/store pending push scan PASS.
- Supabase cleanup/residue for `TASK131_*` PASS/0; Android local cleanup PASS; iOS local cleanup dry-run only, no local residue 0 claim.
- Conflict/Review policy and UI contract PASS, but physical operator checklist is missing: `OPERATOR_CONFLICT_REVIEW_CHECKLIST_NOT_PROVIDED`.
- Accessibility iOS/Android preflight PASS, but VoiceOver/TalkBack operator checklist is missing: `OPERATOR_ACCESSIBILITY_CHECKLIST_NOT_PROVIDED`.
- Account switch split is PASS for same-account logout/login, token/session fail-closed, owner mismatch fixture, legacy/unbound dirty Review/Recovery, export-before-discard/cancel and localDefaultStoreOnly. Only true Account A -> B cases C126-14/15/16/17/40 are `BLOCKED_EXTERNAL_SECOND_ACCOUNT`; they are not PASS and do not block the executable non-B policy set.
- iOS BGTask scheduler subcase remains `BLOCKED_EXTERNAL_IOS_SCHEDULER_POLICY`.

Latest blocked handoff:

- `final-full-physical-execution-summary.md`
- `final-full-physical-execution-summary.json`

Resume commands:

```bash
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical conflict-review-matrix --task TASK-131 --prefix TASK131_CONFLICT_RESUME_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical account-switch-matrix --task TASK-131 --prefix TASK131_ACCOUNT_RESUME_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh physical accessibility-smoke --task TASK-131
./tools/agent/mc-agent.sh scan task131-final-gates --task TASK-131 --strict
```

Review addendum 2026-05-29:

- Latest account split rerun: `agent-runs/20260529T030217Z-physical-account-switch-matrix-task-TASK-131-prefix-TASK131_REVIEW_ACCOUNT_-p77663.json`.
- Latest Conflict/Review blocker-aware rerun: `agent-runs/20260529T030338Z-physical-conflict-review-matrix-task-TASK-131-prefix-TASK131_REVIEW_CONFLICT_-p80048.json`.
- Latest accessibility blocker-aware rerun: `agent-runs/20260529T030624Z-physical-accessibility-smoke-task-TASK-131-p83429.json`.
- Latest final blocker-aware gates: `agent-runs/20260529T031816Z-scan-task131-final-gates-task-TASK-131-strict-p74496.json`.
- Operator checklist template: `operator-review-accessibility-checklist.md` / `.json`.
