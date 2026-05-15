# TASK-109 — 104 Review History Live Non-Empty

Review pass: 2026-05-15 02:25 -0400

## Metodo scelto

Opzione C — Supabase seed scoped.

Motivo: il dev Supabase partiva da `shared_sheet_sessions = 0`; la review doveva creare una sessione History test non vuota. L'app runtime pero' non aveva una sessione autenticata valida, quindi il seed remoto e' stato creato ma il pull iOS runtime e' bloccato.

## Supabase test data

- Owner hash: `ad3d747e936ccd13ed305b1d8a3fb9558ac1e1a0081b9728b3aec2f14f06b1c8`
- Tabelle toccate: `public.shared_sheet_sessions`
- Righe create: `1`
- Display name: `TASK109_REVIEW_HISTORY_20260515_0622Z`
- Remote id test: `ae2ca149-ddb7-4a94-8963-90ad0060d705`
- Payload: v2, `data_rows = 2`, `complete_rows = 2`, `updated_at` presente.
- Nessun dato reale, nessun barcode reale, nessun payload completo riportato in evidence.

## Counts

Prima del seed:

- `total_history_sessions = 0`
- `owner_history_sessions = 0`
- `task109_rows = 0`

Dopo il seed:

- `total_history_sessions = 1`
- `owner_history_sessions = 1`
- `task109_rows = 1`

SwiftData locale sul simulator iPhone 15 Pro Max dopo reinstall/build:

- `ZHISTORYENTRY = 0`
- `ZPRODUCT = 19695`
- `ZPRODUCTPRICE = 41109`

Options runtime:

- `History sessions, 0`
- App state: `Account needs attention` / signed-out.

## Pull iOS runtime

Stato: BLOCKED_WITH_PLAYBOOK.

Il pull non e' stato eseguito perche' l'app non e' autenticata. Il tentativo app-auth ha aperto ASWebAuthenticationSession, ma e' rientrato in app con `Account needs attention`; non c'e' sessione utente per query RLS owner-scoped.

## Second sync no-op

Stato: BLOCKED_WITH_PLAYBOOK.

Non eseguibile senza completare il primo pull iOS signed-in.

## Cleanup / retention

Cleanup non eseguito intenzionalmente.

Motivo: la riga `TASK109_REVIEW_HISTORY_20260515_0622Z` e' test-only, owner-scoped, prefissata, non contiene dati reali e deve restare disponibile per il rerun app-auth richiesto a chi possiede la sessione/credenziali. Cleanup consigliato dopo validazione:

```sql
delete from public.shared_sheet_sessions
where display_name = 'TASK109_REVIEW_HISTORY_20260515_0622Z';
```

## Playbook per chiudere R4

1. Ripristinare una sessione app-auth valida sul Simulator/device iOS.
2. Avviare app su Inventory, attendere auto-check oppure aprire Options e usare `Sync now`.
3. Verificare Options `History sessions > 0`.
4. Aprire History e verificare una riga visibile.
5. Verificare SwiftData `ZHISTORYENTRY > 0`.
6. Rieseguire Sync now: `ZHISTORYENTRY` non deve aumentare per duplicato.
7. Pulire o trattenere esplicitamente la riga test.
