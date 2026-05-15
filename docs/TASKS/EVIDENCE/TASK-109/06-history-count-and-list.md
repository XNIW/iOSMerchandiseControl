# TASK-109 — 06 History Count And List

Scenario: verificare History sessions count in Options, History tab, Supabase `shared_sheet_sessions` owner-scoped/remote e SwiftData `HistoryEntry`.

## Esito

Nel progetto dev verificato durante Wave 1, `shared_sheet_sessions` remoto totale risulta `0`; quindi non posso riprodurre la condizione "Supabase contiene sessioni applicabili ma iOS mostra 0" in questo run. UI e SwiftData sono coerenti con remoto vuoto.

## Evidence UI

- Options local database status: `screenshots/03-options-sync-card-history-count.jpg`
- History tab: `screenshots/06-history-tab.jpg`

Valori UI:

- Options: `History sessions, 0`
- History tab: `No history`

## SwiftData count

Query read-only sullo store Simulator:

```text
Product|19695
Supplier|57
ProductCategory|27
ProductPrice|41109
HistoryEntry|0
LocalPendingChange|0
```

Baseline locale:

```text
valid|19695|57|27|2026-05-14 23:01:46
```

## Supabase remote count

Query read-only via Supabase CLI linked Management API:

```sql
select count(*)::int as total_shared_sheet_sessions,
       count(distinct owner_user_id)::int as owners
from public.shared_sheet_sessions;
```

Risultato redatto:

```json
{
  "rows": [
    {
      "owners": 0,
      "total_shared_sheet_sessions": 0
    }
  ]
}
```

Una query successiva di group-by owner hash ha fallito per auth temporanea del CLI (`ECIRCUITBREAKER` dopo retry); non la ripeto in Wave 1 per evitare loop. Poiche' il count totale riuscito e' `0`, il group-by owner non e' necessario per questa baseline.

## Valutazione rispetto TASK-109

- Options History count corretto rispetto al remoto corrente: **PASS baseline** (`0` remoto, `0` SwiftData, `0` UI).
- History tab non vuota quando remoto contiene sessioni applicabili: **NON VERIFICABILE in Wave 1** per dataset remoto corrente vuoto.
- Ipotesi "History saltata": **non dimostrabile** senza seed/delta remoto `TASK109_` o dataset owner-scoped con righe.
- Azione per Wave 6/9: creare o usare sessione test scoped `TASK109_` e validare catena `shared_sheet_sessions -> HistoryEntry -> Options -> HistoryView`.
