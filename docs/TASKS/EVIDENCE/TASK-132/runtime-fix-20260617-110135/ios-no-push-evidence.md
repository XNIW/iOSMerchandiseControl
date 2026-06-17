# iOS No-Push Evidence

- Tipo verifica: SIM/RUNTIME + SUPABASE/READONLY
- Scenario: app signed-in, local store sporco/non riconciliato, active pending reali 0.
- Runtime decision observed in defaults: `sync.runtime.orchestrator.lastAction = drainEvents`, `sync.runtime.incremental.lastSyncType = LIGHT_RECONCILE`, `sync.runtime.incremental.requiresFullRecovery = true`.

| signal | before | after | result |
|---|---:|---:|---|
| Supabase sync_events total | 1979 | 1979 | PASS no new sync_events |
| iOS products | 19891 | 19891 | unchanged |
| iOS suppliers | 193 | 193 | unchanged |
| iOS categories | 162 | 162 | unchanged |
| iOS productPrices | 41524 | 41524 | unchanged |
| active local pending | 0 | 0 | PASS |
| active outbox | 0 | 0 | PASS |

Log/event evidence:
- `raw/ios-logstream-reopen.raw` captured during the 90s window.
- `raw/ios-logstream-reopen-sync-filtered.txt` has no app-level `record_sync_event`/push success line; primary no-push assertion is Supabase `sync_events` unchanged.
