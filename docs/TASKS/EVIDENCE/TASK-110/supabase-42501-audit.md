# TASK-110 — Supabase 42501 Audit

Checkpoint: 2026-05-15 12:15 -0400.

## Data API anon smoke test

Chiamate eseguite con project URL redatto e key publishable/anon non salvata.

| Endpoint | HTTP | Body redatto | Esito |
|---|---:|---|---|
| `inventory_products?select=id&limit=1` | 401 | `{"code":"42501","message":"permission denied for table inventory_products"}` | atteso: anon chiuso |
| `shared_sheet_sessions?select=remote_id&limit=1` | 200 | `[]` | non ideale: anon SELECT grant ancora presente |
| `product_prices?select=id&limit=1` | 200 | `[]` | non ideale: legacy endpoint raggiungibile anon |

## Log Supabase
- La CLI locale non espone `supabase logs`; quindi non è stato possibile leggere log 42501 server-side via CLI.
- Evidenza alternativa: smoke test Data API e audit grants/RLS.

## Classificazione client attesa
- `42501` deve essere classificato come `Permission issue` / RLS denied, non come `Cancelled`.
- iOS ha già mapping `permissionDeniedOrRLS` in `SupabaseInventoryService`.
- Va verificato che UI/viewmodel non lo riduca a messaggio generico stale.

## Nota operativa
- Durante preflight un tentativo di query Supabase CLI linked in parallelo ha prodotto `ECIRCUITBREAKER` su auth temporanea CLI. Non è un 42501 applicativo; query seriali successive riuscite.
