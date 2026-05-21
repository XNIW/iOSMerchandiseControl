# TASK-112 — Docker / Supabase preflight

Timestamp: 2026-05-20 22:26 -0400  
Agent: Codex / Executor

## Scope

Preflight dopo override utente: Docker ora e' attivo e TASK-112 viene ripreso da `ACTIVE / BLOCKED` a `ACTIVE / EXECUTION-COMPLETION`.

## Checks

| Check | Stato | Evidenza |
|---|---:|---|
| Docker daemon | PASS | `docker info --format ...` → server `29.4.3`, linux/aarch64, 16 CPU, ~8.3 GB memory |
| Docker Compose | PASS | `docker compose version` → `v5.1.3` |
| Supabase CLI | PASS_WITH_NOTES | `supabase --version` → `2.98.2`; CLI segnala update disponibile `2.100.1` |
| Supabase CLI docs/changelog | PASS | Consultati docs ufficiali Supabase CLI/local development e changelog Data API grants. Rilevante: nuove tabelle `public` possono richiedere `GRANT` espliciti per Data API; qui non sono state create nuove tabelle. |
| Supabase local status | PASS_WITH_NOTES | Local stack `MerchandiseControlSupabase` gia' in esecuzione; output status non persistito con chiavi raw. |
| Supabase containers | PASS_WITH_NOTES | `db`, `kong`, `auth`, `realtime`, `rest`, `storage`, `studio`, `inbucket`, `analytics`, `vector`, `pg_meta` healthy/running; `imgproxy`, `edge_runtime`, `pooler` risultano stopped. |
| Supabase project config | PASS_WITH_NOTES | Workspace contiene `supabase/migrations` e `.temp`; non e' presente `supabase/config.toml` in questa working copy. |
| Migration list | PASS_WITH_NOTES | `supabase migration list --local` si connette al DB locale; `README.md` ignorato per filename non migration; history local/remote non perfettamente allineata per migrazioni storiche gia' note. |
| Schema lint | PASS | `supabase db lint --local` → `No schema errors found`. |

## Final review+fix rerun update — 2026-05-20 22:26 -0400

| Check | Stato | Evidenza |
|---|---:|---|
| Supabase local status rerun | PASS_WITH_NOTES | `supabase status` conferma local development setup running; stopped services non critici: imgproxy, edge runtime, pooler. Output raw con chiavi locali non trattenuto. |
| Supabase lint rerun | PASS | `supabase db lint --local` → `No schema errors found`. |
| CLI version | PASS_WITH_NOTES | `supabase --version` → `2.98.2`; update disponibile `2.100.1`, non bloccante per questi check. |

## Decisione su reset/rebuild

Non ho eseguito `supabase db reset --local`: il DB locale era gia' avviato, schema e migration history erano interrogabili, e un reset locale sarebbe stato distruttivo senza necessita' immediata. Ho quindi validato il contratto sullo schema locale corrente e usato transazioni con `ROLLBACK` per i test dati.

## Note privacy

- Nessun token/JWT/email raw e' stato scritto in questo file evidence.
- Le query di contratto locale usano owner UUID sintetici e dati `TASK112_LOCAL_*` dentro transazione con rollback.
- Nessuna mutation live Supabase e nessuna migration applicata.
