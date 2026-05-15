# TASK-110 final cross-platform completion — 01 Supabase final live smoke

Data: 2026-05-15  
Project ref redatto: `...kyvm`  
Account runtime in evidence: `x***@gmail.com`  
Verdict: **PASS**, con nota operativa su `ECIRCUITBREAKER` risolta usando query seriali.

## Comandi principali

- `supabase --version` → `2.98.2`
- `supabase migration list --linked`
- `supabase db query --linked -o table "<schema/grants/counts/smoke SQL>"`
- REST anon negative con publishable key da `SupabaseConfig.plist`, senza stampare la key.
- Supabase changelog consultato: la nota `2026-04-28` conferma il breaking change "Tables not exposed to Data and GraphQL API automatically"; coerente con il requisito TASK-110 di grants espliciti.

## Ledger / progetto

`supabase migration list --linked` mostra locale/remoto allineati fino a:

```text
20260515161500 | 20260515161500 | 2026-05-15 16:15:00
```

La migration TASK-110 è quindi applicata e tracciata.

## Schema / RLS / grants

Query seriale linked:

```text
deleted_at_present                         true
shared_sheet_sessions_rls                  true
authenticated_shared_sheet_sessions_select true
authenticated_shared_sheet_sessions_insert true
authenticated_shared_sheet_sessions_update true
anon_shared_sheet_sessions_select          false
anon_inventory_product_prices_select       false
anon_product_prices_select                 false
```

Interpretazione:

- `shared_sheet_sessions.deleted_at` è presente live.
- RLS è attivo su `shared_sheet_sessions`.
- `authenticated` ha DML minimo necessario per owner-scoped smoke.
- `anon` non ha `select` sulle tabelle private verificate.

## Authenticated owner-scoped smoke

Eseguito come DB role `authenticated` con `request.jwt.claim.sub` impostato a un owner esistente, senza stampare owner UUID. Prefisso test: `TASK110_FINAL_REVIEW_SMOKE_*`.

Risultato:

```text
authenticated_insert_rows          1
authenticated_update_rows          1
authenticated_set_deleted_at_rows  1
authenticated_read_tombstone_rows  1
remaining_smoke_rows               0
history_active                     2
history_tombstones                 0
products                           19695
suppliers                          57
categories                         27
product_prices                     41109
```

Copertura:

- authenticated select own rows: **PASS**
- authenticated insert test row: **PASS**
- authenticated update test row: **PASS**
- authenticated set `deleted_at`: **PASS**
- authenticated read tombstone: **PASS**
- cleanup scoped del record smoke: **PASS**, residui `0`

Nota tecnica: un primo tentativo aveva messo insert/update/tombstone in una sola data-modifying CTE; Postgres non rende visibile alla sibling CTE la riga appena inserita nello stesso snapshot, quindi update/tombstone risultavano `0`. Il record creato è stato subito eliminato per prefisso e il test è stato rieseguito in statement seriali nella stessa connessione.

## Anon negative Data API

REST con sola publishable key:

```text
shared_sheet_sessions      http=401 code=42501 message=permission denied for table shared_sheet_sessions
inventory_products         http=401 code=42501 message=permission denied for table inventory_products
inventory_suppliers        http=401 code=42501 message=permission denied for table inventory_suppliers
inventory_categories       http=401 code=42501 message=permission denied for table inventory_categories
inventory_product_prices   http=401 code=42501 message=permission denied for table inventory_product_prices
product_prices             http=401 code=42501 message=permission denied for table product_prices
```

Classificazione richiesta:

- `42501` = **permission issue / missing grant/RLS denial**, non network e non cancelled.
- Anon CRUD negativo: **PASS**.

## ProductPrice integrity

Query live:

```text
product_price_orphans      0
duplicate_product_prices   0
owner_mismatch             0
```

## Counts iniziali redatti

| Entità | Count |
|--------|------:|
| History active | 2 |
| History tombstones | 0 |
| products | 19695 |
| suppliers | 57 |
| categories | 27 |
| product_prices / `inventory_product_prices` | 41109 |
| ProductPrice orphans | 0 |
| Duplicate ProductPrice | 0 |
| Owner mismatch ProductPrice/Product | 0 |

## Nota ECIRCUITBREAKER

Durante la prima raccolta ho lanciato più `supabase db query --linked` in parallelo; il pooler remoto ha risposto con:

```text
FATAL: (ECIRCUITBREAKER) too many authentication failures, new connections are temporarily blocked
```

Correzione applicata:

- interrotti/lasciati terminare i retry CLI;
- niente più query Supabase linked in parallelo;
- retry seriale con una query per volta;
- smoke finale sopra completato con successo.

Questo è classificato come access/pooler throttling temporaneo causato dal metodo di test, non come failure schema/RLS.

## Sicurezza

- Nessuna email completa, JWT, access token, refresh token, anon key completa, service role key o password scritti in evidence.
- Nessun `service_role` usato nei client mobile.
- Nessun grant CRUD anon aggiunto.
