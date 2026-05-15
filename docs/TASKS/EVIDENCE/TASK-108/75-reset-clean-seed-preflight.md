# TASK-108 — Reset/seed clean preflight e safety gate

Data: 2026-05-14 17:10 -0400

## Stato
- Stato: BLOCKED prima del reset Supabase distruttivo.
- Blocker: email Gmail test non fornita. Non e' possibile identificare con certezza `auth.users.id`, creare backup owner-scoped e cancellare dati filtrati senza questo dato.
- Nessuna query distruttiva Supabase eseguita.
- Nessun dato Supabase cancellato o modificato.

## Branch / repo
- Repo iOS: `/Users/minxiang/Desktop/iOSMerchandiseControl`
- Branch: `task108-sync-reset-clean-seed`
- `origin/main` fetch eseguito prima delle modifiche; HEAD locale/origin: `74480c20c654a07174ba99dede2458d914426ab2`.
- Worktree gia' sporca prima di questo pass; modifiche preesistenti preservate.

## File sorgente letti
- Tracking: `docs/MASTER-PLAN.md`, `docs/TASKS/TASK-108-supabase-sync-unification-ios.md`, `docs/CODEX-EXECUTION-PROTOCOL.md`.
- iOS: `ContentView.swift`, `OptionsView.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabaseManualSyncRemotePreview.swift`, `SupabaseManualSyncBaselineCommitter.swift`, `SupabaseCatalogBaselineReader.swift`, `SupabaseCatalogBaselineWriter.swift`, `SupabasePullPreviewService.swift`, `SupabasePullApplyService.swift`, `SupabaseProductPriceApplyService.swift`, `SupabaseProductPricePreviewService.swift`, `SwiftDataInventorySnapshotService.swift`, `PriceHistoryBackfillService.swift`, `HistorySessionSyncService.swift`, `HistoryEntryRuntimeSummary.swift`, `Models.swift`, `HistoryEntry.swift`.
- Android riferimento: `AppDatabase.kt`, `InventoryRepository.kt`, `PriceBackfillWorker.kt`, `ProductPriceSummary.kt`, `DatabaseViewModel.kt`, `ExcelViewModel.kt`, `ImportAnalysis.kt`, `ProductPrice.kt`, `ProductPriceDao.kt`, `SupabaseProductPriceRemoteDataSource.kt`, `ProductPriceRemoteDataSource.kt`.
- Supabase locale: migrations/schema/RLS in `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations`.

## Modifiche iOS applicate in questo pass
- `SupabaseProductPriceApplyService.swift`: aggiunto `ProductPriceApplyFetchOptions.fullPullSafetyLimit` default `75_000`; `applyPagedFullPull` blocca remote ProductPrice sospetti sopra limite prima del full pull e logga `[Task108ProductPrice] blocked_full_pull`.
- `SupabaseProductPriceApplyService.swift`: log finale full pull include `elapsedMs`.
- `SupabaseProductPricePreviewService.swift`: rimosso `@MainActor` da `ProductPricePreviewLocalLookupBuilder.makeLookup(context:)`.
- `OptionsView.swift`: preview/apply ProductPrice e pull preview usano `ModelContext` dedicati da `modelContext.container` invece del context UI per i lavori pesanti.
- `SwiftDataInventorySnapshotService.swift`: snapshot non isolato al MainActor, logging `[Task108Snapshot] start/done`, canonicalizzazione UTC allocation-light via `gmtime_r`.
- `SwiftDataInventorySnapshotService.swift`: aggiunta diagnostica DEBUG/internal `Task108LocalInventoryDiagnostics` per count raw/logical ProductPrice e top duplicate groups.
- `SupabaseProductPriceApplyServiceTests.swift`: aggiornato test di cancellazione per disattivare esplicitamente il nuovo safety gate e aggiunto test del blocco default sopra 75.000 righe.

## Android static audit
- Confermato indice unico Room `product_prices(productId,type,effectiveAt)`.
- Confermato `insertIfChanged` come guardia locale anti-duplicazione.
- Confermato `PriceBackfillWorker` salta prodotti che hanno gia' almeno un prezzo.
- Confermato pull Android ProductPrice idempotente per remote bridge e chiave logica locale.
- Nessuna patch Android applicata in questo pass.

## Supabase schema audit locale
- `inventory_suppliers`, `inventory_categories`, `inventory_products`: owner-scoped con RLS e partial unique active indexes da migrations.
- `inventory_product_prices`: `owner_user_id`, `product_id`, `type`, `effective_at`, `deleted_at` non presente nello schema originale letto, constraint unique `(owner_user_id, product_id, type, effective_at)`.
- `shared_sheet_sessions` e `sync_events`: owner-scoped; `sync_events.domain` limitato a `catalog` / `prices` nella migration letta.
- Nessuna migration o schema change applicata.

## Conteggio Excel sorgente
File: `/Users/minxiang/Downloads/Database_2026_04_21_14-06-26.xlsx`

| Sheet | max_row | righe non vuote | righe dati esclusa intestazione |
|---|---:|---:|---:|
| Products | 19696 | 19696 | 19695 |
| Suppliers | 58 | 58 | 57 |
| Categories | 28 | 28 | 27 |
| PriceHistory | 41109 | 41109 | 41108 |

Esito: coerente con i conteggi attesi; il file e' idoneo come sorgente seed.

## Check eseguiti
- ✅ ESEGUITO — `git fetch origin`: PASS.
- ✅ ESEGUITO — branch creato: `task108-sync-reset-clean-seed`.
- ✅ ESEGUITO — `xcodebuild -list`: PASS; target test presente `iOSMerchandiseControlTests`.
- ✅ ESEGUITO — iOS Debug simulator build: PASS; unico warning AppIntents metadata non legato al sync.
- ✅ ESEGUITO — iOS Release simulator build: PASS; unico warning AppIntents metadata non legato al sync.
- ✅ ESEGUITO — iOS targeted safety tests: PASS (`testPagedFullPullCanCancelLargeProductPriceHistoryWithoutFixedTotalLimit`, `testPagedFullPullBlocksRemoteAboveDefaultSafetyLimit`).
- ⚠️ NON ESEGUIBILE — full iOS XCTest suite green: tentata, ma fallisce su test preesistenti/stale di copy/benchmark (`SupabaseManualSyncViewModelTests`, `SupabaseManualSyncReleaseUITests`, `Task089LargeDatasetBenchmarkTests`) e un launch clone simulator; non segnato PASS.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — Android `assembleDebug`: PASS.
- ⚠️ NON ESEGUIBILE — Android `./gradlew test`: fallisce per ByteBuddy/MockK attach (`AttachNotSupportedException`) su 137 test; non e' stato osservato un singolo assertion failure di sync ProductPrice.
- ❌ NON ESEGUITO — backup/reset Supabase: bloccato da email Gmail test mancante.
- ❌ NON ESEGUITO — reset locali iOS/Android, seed iOS da Excel, full pull iOS/Android, incremental iOS->Android/Android->iOS, query duplicati finali: richiedono reset Supabase owner-scoped sicuro prima di procedere.

## Rischi / note
- Il safety gate blocchera' un remote sporco da circa 292.989 ProductPrice; un remote pulito da circa 41.108 passa sotto limite 75.000.
- Android push ProductPrice usa ancora upsert remoto su `id` quando manca bridge locale; senza test live no-op non viene dichiarato idempotente end-to-end.
- I test live/cross-platform TASK-108 restano non eseguiti e il task non puo' essere chiuso.

## Prossima azione richiesta
Fornire l'email esatta dell'account Gmail test. Dopo averla ricevuta, prima di qualsiasi delete:
1. cercare `auth.users` con match esatto case-insensitive;
2. procedere solo se il risultato e' esattamente 1 riga;
3. creare backup SQL owner-scoped;
4. cancellare solo righe filtrate per `owner_user_id` / `user_id` dell'utente test;
5. verificare count post-reset a zero.
