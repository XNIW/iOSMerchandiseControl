# TASK-114 Evidence — Cross-platform sync reconciliation

## Diagnosi iniziale (2026-05-21, Supabase `--linked`)

| Metric | Supabase | Android (UI) | iOS (UI) |
|--------|----------|--------------|----------|
| products | 19696 | 19800 | 19696 |
| suppliers | 59 | 94 | 58 |
| categories | 28 | 57 | 27 |
| product_prices | 41111 | 39737 | 41111 |
| history (active) | 11 | 11 | 14 |

Script: `MerchandiseControlSupabase/scripts/task114_diagnostic_sync_counts.sql`

## Fix implementati

- Android: `reconcileLocalCatalogAfterInboundPull` + full price fetch on catalog sync
- Android/iOS: Options «Da riconciliare» quando drift conteggi
- iOS: history count allineato ad Android (esclude import/tombstone)

## Verifica

*(aggiornare con output build/test e conteggi post-fix)*
