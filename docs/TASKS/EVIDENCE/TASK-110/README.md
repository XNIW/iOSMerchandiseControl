# TASK-110 Evidence

Pacchetto evidence per EXECUTION TASK-110.

Checkpoint iniziale: 2026-05-15 12:15 -0400.

## Regole
- Non salvare token, anon key complete, JWT, service key, email complete o payload sensibili.
- Usare hash brevi, ultimi 4 caratteri non sensibili o placeholder `<REDACTED>`.
- I dump raw temporanei restano fuori repo (`/tmp/task110_*`) e non devono essere committati.

## File
- `preflight-backup-rollback-plan.md`
- `client-version-audit.md`
- `supabase-environment-parity.md`
- `supabase-counts-redacted.md`
- `android-local-counts.md`
- `ios-local-counts.md`
- `schema-audit.md`
- `supabase-access-matrix.md`
- `supabase-42501-audit.md`
- `security-advisor-check.md`
- `reconciliation-report.md`
- `sync-policy.md`
- `conflict-policy-matrix.md`
- `catalog-delete-policy.md`
- `product-price-incremental-plan.md`
- `ui-state-taxonomy.md`
- `supabase-schema-cache-playbook.md`
- `proposed-grants-rls-migration.sql`
- `test-matrix.md`
