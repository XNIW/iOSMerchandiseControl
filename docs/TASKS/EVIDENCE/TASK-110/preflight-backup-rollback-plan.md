# TASK-110 — Preflight, Backup, Rollback

Checkpoint: 2026-05-15 12:15 -0400.

## Repository state

### iOS
- Path: `/Users/minxiang/Desktop/iOSMerchandiseControl`
- Branch dedicato creato: `codex/task-110-sync-consistency`
- Remote GitHub verificato con `git fetch origin main`.
- `origin/main` e base locale coincidono al commit `d4a0f89` (`Task 109`).
- Worktree già dirty in ingresso:
  - `docs/MASTER-PLAN.md`
  - `docs/TASKS/TASK-109-ios-supabase-sync-lifecycle-ux-regression.md`
  - `docs/TASKS/TASK-110-cross-platform-cloud-sync-consistency.md`
  - `docs/TASKS/EVIDENCE/TASK-110/`

### Android
- Path: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`
- Branch dedicato creato dopo preflight: `codex/task-110-sync-consistency`
- Worktree: clean al preflight.

### Supabase
- Path: `/Users/minxiang/Desktop/MerchandiseControlSupabase`
- Nota: la directory locale non è un repository git.
- CLI: `supabase 2.98.2`
- Progetto linked raggiungibile con `supabase db query --linked`.
- Migration history locale/remota divergente rilevata con `supabase migration list --linked`; quindi la migration TASK-110 è stata preparata ma non applicata via `db push`.

## Snapshot pre-write

### Supabase
- Snapshot counts redatto: `supabase-counts-redacted.md`
- Schema/grants/RLS audit: `schema-audit.md`, `supabase-access-matrix.md`
- Nessuna migration applicata: blocker tecnico = ledger migration non allineato.

### Android Room
- Dispositivo fisico rilevato: `8ac48ff0` (OnePlus IN2013).
- Database copiato temporaneamente in `/tmp/task110_android_8ac48ff0/app_database`.
- Counts redatti: `android-local-counts.md`.
- Non salvare il DB raw nel repository.

### iOS SwiftData
- Simulator booted rilevato: iPhone 15 Pro Max, iOS 26.1.
- Store SwiftData letto da container simulator:
  `/Users/minxiang/Library/Developer/CoreSimulator/Devices/<SIM>/data/Containers/Data/Application/<APP>/Library/Application Support/default.store`
- Counts redatti: `ios-local-counts.md`.
- Non salvare lo store raw nel repository.

## Rollback plan

### Codice
1. Verificare `git diff`.
2. Revertire solo i file modificati da Codex per TASK-110.
3. Non toccare modifiche preesistenti dell'utente.

### Supabase
1. Prima di applicare una migration, salvare:
   - schema SQL della migration proposta;
   - counts pre/post;
   - smoke test auth/anon pre/post.
2. Per migration additiva `shared_sheet_sessions.deleted_at`:
   - rollback logico: rimuovere il codice client che legge/scrive `deleted_at`;
   - rollback DB solo se necessario: `alter table public.shared_sheet_sessions drop column if exists deleted_at;`
   - prima del drop verificare che non esistano tombstone da preservare.
3. Per revoke/grants:
   - rollback: riapplicare i grants precedenti documentati in `supabase-access-matrix.md`.

### Dati test
- Usare record con prefisso `TASK110_TEST_*`.
- Ogni create/update/delete manuale deve essere annotato in `test-matrix.md`.

## Note operative
- Evitare query Supabase CLI linked in parallelo: durante preflight un tentativo parallelo ha prodotto `ECIRCUITBREAKER` su auth temporanea CLI. Le query successive sono state seriali e riuscite.
- Migration preparata anche nel repo Supabase locale: `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260515161500_task110_history_tombstone_grants.sql`.
