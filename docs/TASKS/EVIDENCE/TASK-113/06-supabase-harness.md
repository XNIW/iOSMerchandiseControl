# Supabase Harness

Status: PASS.

PASS:
- `supabase status-redacted`: `20260521T053746Z-supabase-status-redacted.json`
- `supabase verify-schema --profile local`: `20260521T053859Z-supabase-verify-schema-profile-local.json`
- `supabase verify-rls --profile local`: `20260521T053917Z-supabase-verify-rls-profile-local.json`
- `supabase verify-grants --profile local`: `20260521T053859Z-supabase-verify-grants-profile-local.json`
- `supabase residue-check --profile local`: `20260521T053859Z-supabase-residue-check-prefix-TASK113_DRYRUN_-profile-local.json`
- `supabase residue-check --profile dry-run-no-db`: PASS_WITH_NOTES.
- `supabase cleanup --dry-run`: generates `cleanup_plan_id`.
- `supabase explain-cleanup`: PASS.

Fix applied:
- Residue/cleanup SQL now counts `inventory_product_prices` via join to `inventory_products`.
- `shared_sheet_sessions` and `sync_events` use current columns.
- `verify-rls` casts `roles::text` to avoid Supabase CLI scan failure on local Postgres array OID.

Professional review update — 2026-05-21:
- PASS: `supabase status-redacted`: `20260521T060807Z-supabase-status-redacted-p41394.json`.
- PASS_WITH_NOTES: dry-run-no-db verify/residue commands ran without DB access by design (`20260521T061642Z-*`).
- PASS: local `verify-schema`, `verify-rls`, `verify-grants`, `residue-check`: `20260521T061650Z-*`.
- PASS: linked `verify-schema` now uses `db lint --linked` and passed: `20260521T061707Z-supabase-verify-schema-profile-linked-p84029.json`.
- BLOCKED: linked `verify-rls`, `verify-grants` and `residue-check` are blocked by Supabase pooler circuit breaker / `SUPABASE_DB_PASSWORD` state: `20260521T061707Z-supabase-verify-rls-profile-linked-p84030.json`, `20260521T061707Z-supabase-verify-grants-profile-linked-p84037.json`, `20260521T061707Z-supabase-residue-check-prefix-TASK113_DRYRUN_-profile-linked-p84044.json`.
- NOT_RUN: cleanup `--execute` was not run.

Resume attempt — 2026-05-21 12:30 -0400:
- BLOCKED: required env preflight `printenv SUPABASE_DB_PASSWORD >/dev/null || exit 2` returned exit `2`. No value was printed, saved, logged, or written to evidence.
- NOT_RUN: `supabase status-redacted`, linked `verify-schema`, linked `verify-rls`, linked `verify-grants`, and linked `residue-check` were intentionally not rerun after the missing-env stop condition.
- Next action: export `SUPABASE_DB_PASSWORD` in the terminal/session that launches Codex, then rerun the linked Supabase gate sequence.

Final DONE closure — 2026-05-21 13:19 -0400:
- PASS: `supabase status-redacted`: `20260521T165913Z-supabase-status-redacted-p15515.json`.
- PASS: linked `verify-schema`: `20260521T165917Z-supabase-verify-schema-profile-linked-p15970.json`.
- PASS: linked `verify-rls`: `20260521T170124Z-supabase-verify-rls-profile-linked-p18210.json`.
- PASS: linked `verify-grants`: `20260521T170430Z-supabase-verify-grants-profile-linked-p21228.json`.
- PASS: linked `residue-check --prefix TASK113_DRYRUN_`: `20260521T170739Z-supabase-residue-check-prefix-TASK113_DRYRUN_-profile-linked-p24277.json`; residue count `0`.
- Safety: password value used only as process env for the linked checks and absent from evidence/report/log/tracked files per final scan.
