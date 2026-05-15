# TASK-110 FIX completion — Manual cross-platform live

Data: 2026-05-15

## Stato

Manual cross-platform completo Android ↔ iOS ↔ Supabase: **BLOCKED** da sessione iOS mancante.

## Eseguito

### Android fisico

- Device: `IN2013`.
- App-auth live test gated: PASS.
- Full pull catalog/prices:
  - products: 19695
  - suppliers: 57
  - categories: 27
  - product_prices: 41109
  - product_refs: 19695
  - price_refs: 41109
  - `pricesSkippedNoProductRef`: 0
- Second pull no-op: PASS.
- Push no-op: PASS (`pushed_noop=0`).

### Supabase

- Counts live coerenti:
  - `inventory_products`: 19695
  - `inventory_suppliers`: 57
  - `inventory_categories`: 27
  - `inventory_product_prices`: 41109
  - `shared_sheet_sessions`: 1
- ProductPrice remote orphan: 0.
- Tombstone smoke owner-scoped: PASS.

### iOS

- Build/test statici e service-level tests: PASS.
- Live smoke con sessione Supabase corrente: FAIL `sessionMissing`.
- Non è stata inserita alcuna password e non è stato creato/committato alcun token.

## Non eseguito per blocco auth iOS

Questi passi non possono essere dichiarati PASS senza login app-auth iOS:

- logout/login/re-login iOS con account `x***@gmail.com`;
- create/update/delete History Android ↔ iOS via UI;
- product/price update bidirezionale Android ↔ iOS via UI;
- offline create/delete e successiva convergenza iOS;
- Sync now ripetuto 3 volte su entrambi i client autenticati.

## Dati test creati/modificati/eliminati

- Supabase smoke: creata, tombstonata, letta e poi eliminata la sola riga `TASK110_SMOKE_HISTORY_TOMBSTONE`.
- Android live app-auth: ha eseguito `clearAllTables()` sulla cache locale debug del device fisico prima del full pull; nessuna cancellazione dati remota.
- Nessun dato reale legacy cancellato su Supabase.
