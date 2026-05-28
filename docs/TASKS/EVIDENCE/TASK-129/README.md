# TASK-129 Evidence

Task: TASK-129 — Android broad test health + CI isolation

Scope evidence:

- mc-agent preflight/config/head reports;
- Android build debug report;
- Android targeted sync report;
- Android broad suite report;
- quarantine report if broad is non-green;
- sensitive/evidence scans;
- JSON schema validation.

Evidence directory:

- `docs/TASKS/EVIDENCE/TASK-129/agent-runs/`

Redaction policy:

- no real emails;
- no tokens/JWT/Bearer/API keys;
- no Supabase project refs;
- no raw `/Users/<name>/...` paths in final reports;
- no device serials;
- no real live data.

Status:

- Created 2026-05-27 by Codex.
- Final execution handoff 2026-05-27: TASK-129 ACTIVE / REVIEW — PASS_WITH_NOTES_CANDIDATE_QUARANTINE.
- Android build debug PASS, targeted sync PASS.
- Android broad remains non-green: 494 tests, 143 failures, 2 skipped; final quarantine report classifies remaining failures as `BYTEBUDDY_ATTACH_ENV` only.
- Real Android test regressions found during broad diagnosis were fixed before handoff.
- TASK-129 is not DONE.
