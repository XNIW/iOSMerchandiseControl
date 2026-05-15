# TASK-108 Evidence 78 — Final codebase review and regression

**Data:** 2026-05-14 20:22 -0400  
**Branch:** `task108-sync-reset-clean-seed`  
**HEAD:** `74480c20c654a07174ba99dede2458d914426ab2`  
**Verdict finale:** `PASS_WITH_NOTES`  
**TASK-108:** `DONE / Chiusura — PASS_WITH_NOTES` su conferma esplicita utente del 2026-05-14 20:27 -0400. Android app-auth cross-device live resta nota/follow-up documentato.

> **Addendum 2026-05-14 21:20 -0400:** il gap Android app-auth live indicato in questa evidence e' stato rivalutato dopo login utente su device fisico ed emulatore. Vedi `79-android-app-auth-live-rerun.md`: pull completo, secondo pull no-op e push incrementale no-op Android PASS su entrambi i device; Supabase finale resta `41.109` ProductPrice con duplicati `0`. Il verdict complessivo resta `DONE / PASS_WITH_NOTES`; la nota residua Android e' ora solo il mutativo prezzo `+1` Android -> Supabase -> iOS non rieseguito per non alterare il remote dev pulito.

## 1. Stato git e preflight

- `git branch --show-current`: `task108-sync-reset-clean-seed`.
- `git rev-parse HEAD`: `74480c20c654a07174ba99dede2458d914426ab2`.
- `git fetch origin`: eseguito in preflight; branch locale allineato a `origin/main` prima dei fix finali.
- Worktree gia' dirty prima della review finale con le modifiche TASK-108 e le evidence `52`...`77` non committate.
- Worktree dopo la review finale: resta dirty, con ulteriori fix iOS/test e nuova evidence `78`; nessun revert automatico di modifiche preesistenti.

## 2. File modificati nella review finale

Fix applicati direttamente durante questa review finale:

- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/InventorySyncService.swift`
- `iOSMerchandiseControl/SupabaseSyncEventPreviewService.swift`
- `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift`
- `iOSMerchandiseControl/PriceHistoryBackfillService.swift` (rimosso)
- `iOSMerchandiseControlTests/InventorySyncServiceTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift`
- tracking/evidence: questo file, `docs/TASKS/EVIDENCE/TASK-108/README.md`, `docs/TASKS/TASK-108-supabase-sync-unification-ios.md`, `docs/MASTER-PLAN.md`

Il resto del diff TASK-108 era gia' presente nel worktree all'inizio della review e non e' stato revertito.

## 3. Problemi trovati e corretti

1. **HIGH — Options contava il database locale materializzando grandi array SwiftData sul MainActor.**  
   Fix: rimossi i `@Query` su `Product`, `Supplier`, `ProductCategory`, `ProductPrice` usati solo per conteggi; introdotto summary locale con `fetchCount` su `modelContext`. Lo smoke runtime ha mostrato Options fluida con `19.695` prodotti e `41.109` prezzi locali.

2. **MEDIUM — residui TASK-108/diagnostici in sorgenti app e log label Release.**  
   Fix: label diagnostiche rinominate in forma generica, diagnostica snapshot wrappata `#if DEBUG`, scan sorgenti senza match per harness/launch args TASK-108 o Advanced diagnostics pubbliche.

3. **MEDIUM — `SupabaseSyncEventPreviewService` poteva restare nel build Release.**  
   Fix: intero file wrappato `#if DEBUG`; Release build e binary strings scan confermano assenza delle diagnostiche storiche cercate.

4. **LOW — helper morto `PriceHistoryBackfillService`.**  
   Fix: file rimosso dopo conferma `rg` che `PriceHistoryBackfillService` / `backfillIfNeeded` non avevano chiamanti app/test. Il supporto display per sorgente legacy `BACKFILL` resta in `ProductPriceHistoryView`.

5. **HIGH — crash XCTest deterministico in deinit di `InventorySyncService` nel path Generated sync test.**  
   Fix: `InventorySyncService` convertito da `@MainActor final class` a `@MainActor struct`, coerente con assenza di stato identitario. Test repro passato.

6. **MEDIUM — test Release UI stale rispetto al cleanup diagnostiche TASK-108.**  
   Fix: aggiornate le assertion di `SupabaseManualSyncReleaseUITests` per la factory attuale e per l'assenza della vecchia card debug pubblica.

## 4. Problemi lasciati come follow-up

- **Android app-auth cross-device live non completato.** `adb` e' stato trovato via path assoluto e un device risultava collegato, ma il test strumentato read-only `Task098CrossPlatformSmokeTest#test01PreflightAndCollisionScanReadOnly` e' rimasto in stall su `connectedDebugAndroidTest`; il wrapper Gradle e' stato interrotto. Nessun PASS live Android dichiarato.
- **Generated non e' una tab separata nella tab bar runtime.** La tab bar visibile contiene `Inventory`, `Database`, `History`, `Options`; il flusso Generated e' coperto dai test import/generated e non da uno smoke di tab autonoma.
- **Full XCTest iOS completa non rieseguita in questo pass finale.** E' stata eseguita una regressione mirata ampia sulle aree sync/import/database/generated/history; non viene dichiarato "full green".

## 5. Supabase

- Progetto remoto verificato: `merchandisecontrol-dev`.
- Project ref verificato: `jpgoimipbothfgkokyvm`.
- Postgres remoto: `17.6.1.104`.
- Owner test verificato da evidence precedenti: `6425adb0-33e3-4b6c-a9a7-ed3761e8257e`.
- Query finali non distruttive:
  - `inventory_suppliers`: `57`
  - `inventory_categories`: `27`
  - `inventory_products`: `19.695`
  - `inventory_product_prices`: `41.109`
  - duplicati `inventory_product_prices(owner_user_id, product_id, type, effective_at)`: `0`
  - owner mismatch ProductPrice -> Product: `0`
  - owner mismatch Product -> Supplier: `0`
  - owner mismatch Product -> Category: `0`
- Indici verificati presenti: owner indexes per suppliers/categories/products/prices e unique `inventory_product_prices_owner_product_type_effective_uniq`.
- Nessun write/delete Supabase eseguito in questa review finale.

## 6. iOS build, test e scan

- ✅ ESEGUITO — `xcodebuild -list`: PASS.
- ✅ ESEGUITO — iOS Debug build generic simulator: PASS; solo warning noto AppIntents metadata extraction.
- ✅ ESEGUITO — iOS Release build generic simulator: PASS; solo warning noto AppIntents metadata extraction.
- ✅ ESEGUITO — regressione mirata iOS: PASS, `215` test eseguiti, `8` skip, `0` failure.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — `plutil -lint iOSMerchandiseControl/*.lproj/Localizable.strings`: PASS per EN/ES/IT/ZH.
- ✅ ESEGUITO — scan sorgenti app per `TASK108`, harness, launch args temporanei, `Developer diagnostics`, `Advanced diagnostics`, `syncEventPreviewService`: PASS, nessun match.
- ✅ ESEGUITO — scan Release binary filtrato per stringhe diagnostiche storiche: PASS, nessun match non legato a path build/SourcePackages.
- ⚠️ NON ESEGUIBILE — "nessun warning nuovo" in senso assoluto: build pulite funzionalmente, ma permane warning AppIntents metadata noto e fuori scope.

Suite mirata finale:

- `LocalPendingAggregatedPushPlannerTests`
- `SupabaseManualSyncViewModelTests`
- `SupabaseProductPriceApplyServiceTests`
- `SupabasePullPreviewPaginationTests`
- `SupabasePullApplyServiceTests`
- `HistorySessionSyncServiceTests`
- `SupabaseManualSyncReleaseUITests`
- `InventorySyncServiceTests`
- `Task100LargeDatasetAcceptanceTests`
- `Task105RealOpsClosureTests`

## 7. iOS app-auth finale

La evidence `77` resta valida e non e' stata ripetuta inutilmente:

- pull app-auth iOS su locale pulito: PASS, `57/27/19.695/41.108`;
- secondo pull no-op: PASS, ProductPrice inserted `0`, skipped `41.108`;
- push incrementale iOS: PASS, ProductPrice remoto `41.108 -> 41.109`, duplicati `0`;
- repull dopo reset locale harness: PASS, `41.109`;
- secondo repull no-op: PASS, inserted `0`, conteggi invariati.

Le query remote finali di questa review confermano ancora `41.109` ProductPrice e duplicati `0`.

## 8. Simulator smoke e UX/UI

- ✅ ESEGUITO — launch app su iPhone 15 Pro Max iOS 26.1.
- ✅ ESEGUITO — Inventory/Home smoke: empty/selection actions visibili, nessun freeze.
- ✅ ESEGUITO — Options smoke: cloud account card pulita, `Sign in` visibile se signed-out, stato database locale mostra `19.695` prodotti / `57` fornitori / `27` categorie / `41.109` prezzi, nessuna Advanced/Developer diagnostics pubblica.
- ✅ ESEGUITO — Database smoke: lista prodotti scrollabile, search, import/export/new product, scanner, price history visibili.
- ✅ ESEGUITO — History smoke: schermata renderizzata con copy signed-out cloud, nessun bottone cloud ambiguo.
- ⚠️ NON ESEGUIBILE — Generated tab smoke: non esiste tab separata runtime; coperta da test import/generated.

## 9. Performance / MainActor

- Fix Options evita materializzazione di grandi dataset SwiftData per soli conteggi.
- I path ProductPrice full pull/apply gia' verificati nelle evidence `69`...`77` restano off-main/background context per i lavori pesanti.
- Runtime smoke: tab switch e scroll Options/Database senza freeze visibile.
- Test large dataset finale: Excel reale `19.695` prodotti / `41.108` ProductPrice e ProductPrice paged pull/no-op passati nella suite mirata.

## 10. Android

- Repository Android: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`.
- Branch: `main`.
- HEAD: `7cfc536b7200a7e2e4a2224800650d2e0b7f7ac0`.
- Worktree Android era gia' dirty prima della review; nessun revert effettuato.
- ✅ ESEGUITO — static review ProductPrice/Room/sync: unique index `(productId,type,effectiveAt)`, `insertIfChanged`, bridge remote refs e paginazione keyset verificati.
- ✅ ESEGUITO — `./gradlew assembleDebug`: PASS.
- ✅ ESEGUITO — `./gradlew test`: PASS.
- ⚠️ NON ESEGUIBILE — Android app-auth live/cross-device: `adb` e' disponibile in path assoluto e device `8ac48ff0` e' collegato, ma il test strumentato read-only si e' fermato su `connectedDebugAndroidTest` senza completare; interrotto per evitare job appeso. Supabase finale invariato dopo il tentativo.

## 11. Verdict

`PASS_WITH_NOTES`.

Motivo: core iOS/Supabase e' solido per TASK-108 dopo la review finale: app-auth iOS pull/no-op/push/repull validi, ProductPrice duplicati `0`, build Debug/Release PASS, test mirati sync/import/database/generated/history PASS, UX Options/Database/History accettabile, Release senza diagnostiche storiche. Resta una nota non bloccante per il target principale iOS: Android app-auth cross-device live non completato per stall del test strumentato, pur con build/test/static review Android PASS.

**TASK-108 marcato DONE** su conferma esplicita dell'utente: `DONE / Chiusura — PASS_WITH_NOTES`. Il gap Android live resta documentato come follow-up, non come blocker della chiusura accettata.
