# TASK-110 FIX completion — Delete History tombstone

Data: 2026-05-15

## Supabase

- `shared_sheet_sessions.deleted_at` applicato live tramite migration `20260515161500_task110_history_tombstone_grants.sql`.
- Ledger migration locale/remoto coerente dopo apply: `20260515161500` presente sia local sia remote.
- Smoke SQL authenticated PASS:
  - insert riga test `TASK110_SMOKE_HISTORY_TOMBSTONE`;
  - update display name;
  - set `deleted_at`;
  - read tombstone owner-scoped;
  - cleanup della sola riga smoke.
- Smoke anon negative PASS: Data API su `shared_sheet_sessions`, `inventory_products`, `product_prices` risponde `42501`, classificato come permission/grant issue e non come network/cancel.

## iOS

- `HistoryEntry` conserva `remoteDeletedAt` e marca delete locale come tombstone pending.
- `HistorySessionSyncService` invia `deleted_at`, legge tombstone remoti, non crea nuove righe locali da tombstone sconosciuti e non resuscita entry cancellate.
- `HistoryView` nasconde tombstone sincronizzati e mantiene visibile `Deleted pending` quando la delete locale non è ancora confermata.
- XCTest PASS: `HistorySessionSyncServiceTests` 10/0, inclusi push tombstone e pull tombstone.

## Android

- Room schema aggiornato a v17 con `history_entries.deletedAt`.
- Delete locale History è soft delete: conserva bridge `history_entry_remote_refs`, incrementa revisione locale e lascia la riga visibile come pending fino al push.
- Push History invia `deleted_at` e, quando confermato, marca la riga come synced così sparisce dalla lista attiva.
- Pull tombstone remoto marca la riga locale come synced/tombstoned e la nasconde dalla lista attiva.
- UI History mostra badge/accessibility label `Deleted pending` per tombstone locali non ancora sincronizzati.
- Test PASS:
  - `DefaultInventoryRepositoryTest.110*`
  - `AppDatabaseMigrationTest`
  - `HistorySessionPushCoordinatorTest` isolato con `GRADLE_OPTS='-Djdk.attach.allowAttachSelf=true'`

## Gap manuale

Create/update/delete bidirezionale Android ↔ iOS via UI non è stato completato perché il simulatore iOS non ha sessione Supabase valida (`sessionMissing`). Questo è registrato in `manual-cross-platform-live.md`.
