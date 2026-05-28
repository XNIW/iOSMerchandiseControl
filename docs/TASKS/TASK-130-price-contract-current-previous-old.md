# TASK-130 — Price contract current / last / previous / old

## 1. Stato

- Task ID: TASK-130
- Titolo: Price contract current / last / previous / old
- Stato: DONE / CONSOLIDATED_TASK128_TO_TASK130_REVIEW_PASS_WITH_NOTES
- Repo iOS target: `/Users/minxiang/Desktop/iOSMerchandiseControl`
- Repo Android riferimento: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`
- Supabase locale riferimento: `/Users/minxiang/Desktop/MerchandiseControlSupabase`
- Data creazione: 2026-05-27
- Ultimo aggiornamento: 2026-05-28
- Ultimo agente: Codex / Final reviewer-fixer
- Responsabile attuale: USER / Accepted closure with notes
- Nota: override utente 2026-05-28: TASK-130 assorbe anche i gap residui TASK-128; nessun TASK-131/TASK-132/TASK-133/TASK-134/TASK-135 aperto; nessun claim production-ready globale.

## 2. Obiettivo

Definire, implementare e verificare un contratto unico prezzi tra iOS, Android e Supabase:

- current price = `Product.purchasePrice` / `Product.retailPrice`;
- last price = ultimo `ProductPrice` per `type/effectiveAt`;
- previous price = penultimo `ProductPrice` per `type/effectiveAt`;
- `oldPurchasePrice` / `oldRetailPrice` in griglia/import = snapshot o input import, non fonte primaria remota;
- PreGenerate old price = snapshot del current DB al momento della generazione;
- Supabase coerente con `inventory_products.purchase_price`, `inventory_products.retail_price`, `inventory_product_prices.price`, `type`, `effective_at`.

## 3. Fonti lette

### Tracking / harness iOS

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-128-release-hardening-final-production-gap-plan.md`
- `docs/TASKS/TASK-129-android-broad-test-health-ci-isolation.md`
- `docs/TASKS/EVIDENCE/TASK-129/README.md`
- `tools/agent/README.md`
- `tools/agent/mc-agent.sh`
- `tools/agent/lib/common.sh`
- `tools/agent/lib/ios.sh`
- `tools/agent/lib/android.sh`
- `tools/agent/lib/supabase.sh`
- `tools/agent/lib/report.sh`
- `tools/agent/lib/redact.sh`

### iOS

- `iOSMerchandiseControl/Models.swift`
- `iOSMerchandiseControl/ProductImportCore.swift`
- `iOSMerchandiseControl/ExcelSessionViewModel.swift`
- `iOSMerchandiseControl/ProductPriceHistoryView.swift`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControlTests/Task111ExcelImportParityTests.swift`
- ProductPrice/import/export/sync tests esistenti via `rg`

### Android

- `AppDatabase.kt`
- `InventoryRepository.kt`
- `ProductPriceSummary.kt`
- `ProductWithDetails.kt`
- `Product.kt`
- `ProductPrice.kt`
- `ProductDao.kt`
- `ProductPriceDao.kt`
- `DefaultInventoryRepositoryTest.kt`
- Gradle/test config rilevante

### Supabase locale

- `20260417120000_task013_inventory_catalog_rls.sql`
- `20260417200000_task016_inventory_product_prices.sql`
- `20260421120000_task038_restrict_authenticated_delete_inventory.sql`
- migration successive sync/history/product prices lette read-only

## 4. Local / Git state

- iOS: branch `main`, HEAD locale e `origin/main` allineati a `cdb22534`; worktree dirty coerente con TASK-128/TASK-129/TASK-130.
- Android: branch `main`, HEAD locale e `origin/main` allineati a `c6cfb5d`; worktree dirty coerente con TASK-129/TASK-130.
- Supabase locale: path leggibile, non git repo.
- Classificazione operativa: `LOCAL_CANONICAL_AHEAD_OF_REMOTE` per tracking/evidence/patch locali non ancora pubblicati; nessun conflitto Git reale rilevato.

## 5. Automation contract

Comandi canonici TASK-130:

```bash
./tools/agent/mc-agent.sh scan price-contract --task TASK-130 --strict
./tools/agent/mc-agent.sh ios test price-contract --task TASK-130
./tools/agent/mc-agent.sh android test price-contract --task TASK-130
./tools/agent/mc-agent.sh supabase contract price-schema --task TASK-130 --read-only
./tools/agent/mc-agent.sh harness golden-corpus validate --task TASK-130
./tools/agent/mc-agent.sh harness golden-corpus roundtrip --task TASK-130
./tools/agent/mc-agent.sh ios benchmark import-large --task TASK-130
./tools/agent/mc-agent.sh scan swiftdata-fetch-budget --task TASK-130 --strict
./tools/agent/mc-agent.sh ios smoke options-first-sync --task TASK-130
./tools/agent/mc-agent.sh ios smoke scanner-edge --task TASK-130
./tools/agent/mc-agent.sh ios smoke accessibility --task TASK-130
./tools/agent/mc-agent.sh harness real-device-feasibility --task TASK-130
```

Report attesi:

- Markdown/JSON schema `1.1` per ogni comando.
- Price contract matrix nel report `scan price-contract`.
- Supabase read-only schema contract nel report `supabase contract price-schema`.
- Exit code canonici: `0 PASS`, `1 FAIL`, `2 BLOCKED_EXTERNAL`, `3 MISCONFIGURED`, `4 UNSAFE_OPERATION_REFUSED`.

## 6. Dataset / prefix policy

- TASK-130 usa test locali/unitari e fixture sintetiche hardcoded `TASK130_*`.
- Nessun dato reale.
- Nessun Supabase live richiesto.
- Nessun `MC_ALLOW_LIVE=1` usato.
- Nessun cleanup/residue richiesto per dati live, perche' non vengono creati dati remoti.

## 7. Price contract matrix

| Concetto prezzo | iOS local field/model | Android local field/model | Supabase table/column | Fonte di verita' | Regola di calcolo | Import/export | Sync | Stato |
|---|---|---|---|---|---|---|---|---|
| current purchase price | `Product.purchasePrice` | `Product.purchasePrice` / `ProductWithDetails.currentPurchasePrice` | `inventory_products.purchase_price` | Product current field | Non derivare da history | Products sheet current | Catalog product row | PASS |
| current retail price | `Product.retailPrice` | `Product.retailPrice` / `ProductWithDetails.currentRetailPrice` | `inventory_products.retail_price` | Product current field | Non derivare da history | Products sheet current | Catalog product row | PASS |
| last purchase ProductPrice | `ProductPriceContract.lastPrice(..., .purchase)` | `ProductPriceSummary.lastPurchase` | `inventory_product_prices.price/type/effective_at` | Latest purchase history | Ultimo per `effectiveAt` | PriceHistory/import current event | Price history row | PASS |
| previous purchase ProductPrice | `ProductPriceContract.previousPrice(..., .purchase)` | `ProductPriceSummary.prevPurchase` | `inventory_product_prices.price/type/effective_at` | Penultimate purchase history | Penultimo per `effectiveAt` | `oldPurchasePrice` -> previous/import snapshot | Append-only history | PASS |
| last retail ProductPrice | `ProductPriceContract.lastPrice(..., .retail)` | `ProductPriceSummary.lastRetail` | `inventory_product_prices.price/type/effective_at` | Latest retail history | Ultimo per `effectiveAt` | PriceHistory/import current event | Price history row | PASS |
| previous retail ProductPrice | `ProductPriceContract.previousPrice(..., .retail)` | `ProductPriceSummary.prevRetail` | `inventory_product_prices.price/type/effective_at` | Penultimate retail history | Penultimo per `effectiveAt` | `oldRetailPrice` -> previous/import snapshot | Append-only history | PASS |
| oldPurchasePrice import/grid | `ProductDraft.oldPurchasePrice`, generated grid | `Product.oldPurchasePrice`, generated grid | Nessuna colonna current remota | Snapshot/input import | Non fonte primaria remota | Crea/mostra previous snapshot | Non current remote | PASS |
| oldRetailPrice import/grid | `ProductDraft.oldRetailPrice`, generated grid | `Product.oldRetailPrice`, generated grid | Nessuna colonna current remota | Snapshot/input import | Non fonte primaria remota | Crea/mostra previous snapshot | Non current remote | PASS |
| PreGenerate old price snapshot | `ExcelSessionViewModel.fetchOldPricesByBarcode` | `ExcelViewModel` snapshot current | N/A | Current DB Product al generate | Snapshot locale | Generated old columns | Nessun write diretto | PASS |
| ProductPrice effectiveAt/effective_at | `ProductPrice.effectiveAt` | `ProductPrice.effectiveAt` | `inventory_product_prices.effective_at` | Ordering history | Latest/previous per type | PriceHistory timestamp | Remote history timestamp | PASS |
| source/origin import/manual/sync | `ProductPrice.source` | `ProductPrice.source` | `inventory_product_prices.source` | Metadata audit | Non cambia il current | IMPORT/IMPORT_PREV | origin metadata | PASS |

## 8. Scenario matrix

| Scenario | iOS | Android | Supabase | Stato |
|---|---|---|---|---|
| Nuovo prodotto con purchase/retail | Targeted XCTest TASK-130 | Targeted JVM TASK-130 | Schema current/history read-only | PASS |
| Update prezzo acquisto | Helper contract + targeted XCTest | `updateCurrentPriceFromHistory` targeted JVM | Schema history append-only | PASS |
| Update prezzo vendita | Helper contract + targeted XCTest | `updateCurrentPriceFromHistory` targeted JVM | Schema history append-only | PASS |
| Import con oldPurchasePrice / oldRetailPrice | `ProductImportCore` targeted XCTest | `applyImport` targeted JVM | No old* current remote column | PASS |
| PreGenerate | `generateHistoryEntry` targeted XCTest | Static parity via scan | N/A | PASS |
| Export/import full DB | `DatabaseView.priceSummary` static scan | Existing export/import path + round-trip regression tests | PriceHistory schema | PASS |
| Cross-platform parity | Matrix + scanner | Matrix + scanner | Matrix + scanner | PASS_WITH_NOTES: binary iOS->Android / Android->iOS artifacts not exchanged in this pass |

## 9. Acceptance matrix

| Acceptance | Evidence attesa | Stato |
|---|---|---|
| Tracking TASK-130 creato | Questo file + evidence README | PASS |
| MASTER-PLAN aggiornato | `docs/MASTER-PLAN.md` | PASS |
| Comandi TASK-130 discoverable | `help-json`, `list commands-json` | PASS |
| iOS build debug | `20260528T003119Z-ios-build-debug-task-TASK-130-p43834.*` | PASS |
| iOS price-contract test | `20260528T003145Z-ios-test-price-contract-task-TASK-130-p45769.*` | PASS |
| Android build debug | `20260528T003119Z-android-build-debug-task-TASK-130-p43792.*` | PASS |
| Android targeted sync | `20260528T003145Z-android-test-sync-task-TASK-130-p45806.*` | PASS |
| Android price-contract test | `20260528T003119Z-android-test-price-contract-task-TASK-130-p43793.*` | PASS |
| Android broad/quarantine consolidation | `20260528T002959Z-android-test-broad-task-TASK-130-p42537.*`, `20260528T003101Z-android-test-quarantine-report-task-TASK-130-p43280.*` | PASS_WITH_NOTES: broad not green, only ByteBuddy attach quarantine after real regressions fixed |
| Supabase price schema read-only | `20260528T003145Z-supabase-contract-price-schema-task-TASK-130-read-only-p45805.*` | PASS |
| Price contract scan strict | `20260528T003145Z-scan-price-contract-task-TASK-130-strict-p45770.*` | PASS |
| Golden corpus validate | `20260528T003205Z-harness-golden-corpus-validate-task-TASK-130-p47713.*` | PASS_WITH_NOTES |
| Golden corpus roundtrip | `20260528T003205Z-harness-golden-corpus-roundtrip-task-TASK-130-p47714.*` | PASS_WITH_NOTES |
| SwiftData fetch budget | `20260528T003205Z-scan-swiftdata-fetch-budget-task-TASK-130-strict-p47754.*` | PASS_WITH_NOTES |
| Import-large benchmark | `20260528T003205Z-ios-benchmark-import-large-task-TASK-130-p47749.*` | PASS_WITH_NOTES |
| Options first-sync smoke | `20260528T003205Z-ios-smoke-options-first-sync-task-TASK-130-p47756.*` | PASS_WITH_NOTES |
| Scanner edge smoke | `20260528T003205Z-ios-smoke-scanner-edge-task-TASK-130-p47755.*` | PASS_WITH_NOTES |
| Accessibility smoke | `20260528T003205Z-ios-smoke-accessibility-task-TASK-130-p47779.*` | PASS_WITH_NOTES |
| Real-device feasibility | `20260528T003205Z-harness-real-device-feasibility-task-TASK-130-p47762.*` | PASS_WITH_NOTES / PARTIAL |
| Sensitive/evidence/JSON validation | Latest final `scan-sensitive`, `scan-evidence`, `report-validate-json` reports in `docs/TASKS/EVIDENCE/TASK-130/agent-runs/` | PASS |
| No TASK-131 | Repo/task scan manual | PASS |
| No DONE / no production-ready claim | Tracking state | PASS |

## 10. Safety / redaction policy

- No Swift/Kotlin/SQL refactor massivo.
- No schema migration, RLS/grants/RPC change.
- No service_role client.
- No bypass RLS.
- No dati reali come fixture.
- No cleanup globale.
- Evidence redatta tramite `mc-agent`: token/JWT/Bearer, access/refresh token, anon/service role, email, project ref, `/Users/<name>/...`, device serial.

## 11. Execution log

- Preflight TASK-130 `help-json`, `list commands-json`, `config validate`, `git head-consistency`, `preflight --require-head-consistency`: avviati prima della patch; `config/head/preflight` PASS.
- RED harness: `scan price-contract`, `ios test price-contract`, `android test price-contract`, `supabase contract price-schema` risultavano mancanti/MISCONFIGURED prima della patch.
- Patch iOS:
  - `Models.swift`: aggiunto `ProductPriceContract`.
  - `ProductPriceHistoryView.swift`: current price da `Product` via helper.
  - `DatabaseView.swift`: export current da `Product`, previous da history penultima.
  - `Task130PriceContractTests.swift`: targeted XCTest.
- Patch Android:
  - `ProductWithDetails.kt`: current da `Product`, non da `lastPurchase/lastRetail`.
  - `DefaultInventoryRepositoryTest.kt`: expectation riallineata al nuovo contratto.
  - `Task130PriceContractTest.kt`: targeted JVM tests.
  - `InventoryRepository.kt`: full DB import con `PriceHistory` completo non crea piu' righe sintetiche `IMPORT`/`IMPORT_PREV`; import non-full conserva le righe sintetiche necessarie.
  - `ImportApplyModels.kt` / `DatabaseViewModel.kt`: aggiunto flag interno `priceHistoryRepresentsFullDatabase`.
  - `DatabaseExportWriterTest.kt` / `FullDbExportImportRoundTripTest.kt`: regressioni riallineate e verificate al contratto current/product-field + PriceHistory reale.
- Patch harness:
  - `task130_price_contract.py`
  - dispatcher `scan price-contract`
  - `ios test price-contract`
  - `android test price-contract`
  - `supabase contract price-schema --read-only`
  - `help-json` / `list commands-json` / README.
- Final functional gates:
  - `scan price-contract --task TASK-130 --strict`: PASS.
  - `supabase contract price-schema --task TASK-130 --read-only`: PASS.
  - `ios build debug --task TASK-130`: PASS.
  - `ios test price-contract --task TASK-130`: PASS.
  - `android build debug --task TASK-130`: PASS.
  - `android test price-contract --task TASK-130`: PASS.
  - `android test sync --task TASK-130`: PASS.
  - `android test broad --task TASK-130`: FAIL broad globale, poi quarantine PASS_WITH_NOTES solo `BYTEBUDDY_ATTACH_ENV`.

## 12. TASK-129 quarantine consolidation

- TASK-129 non e' stato riaperto.
- Broad Android durante TASK-130 ha inizialmente classificato 7 regressioni reali, tutte corrette nel perimetro TASK-130.
- Broad finale resta non green per 143 failure `BYTEBUDDY_ATTACH_ENV` gia' note da TASK-129.
- Quarantine finale `20260528T003101Z-android-test-quarantine-report-task-TASK-130-p43280.*`: `PASS_WITH_NOTES`.
- Stable CI alternative resta: `android build debug` + `android test sync` + targeted price-contract.

## 13. Golden corpus consolidation

- Fixture sintetiche privacy-safe versionate in `docs/TASKS/EVIDENCE/TASK-130/golden-corpus/`.
- Copertura fixture: CSV prodotto, HTML Excel, full DB `Products/Suppliers/Categories/PriceHistory`, barcode scientific notation, prezzi punto/virgola, discount/discountedPrice, duplicati, missing barcode, missing product name, retail invalid, quantita' negativa.
- Harness:
  - `harness golden-corpus validate`: PASS_WITH_NOTES.
  - `harness golden-corpus roundtrip`: PASS_WITH_NOTES.
- Limite residuo: non sono stati generati e scambiati artefatti binari reali iOS export -> Android import e Android export -> iOS import; il gate resta statico/fixture-based con `PARTIAL` documentato.

## 14. Performance / SwiftData consolidation

- iOS `ExcelSessionViewModel.fetchOldPricesByBarcode` ora usa lookup chunked per barcode invece di fetch-all + filtro in memoria.
- `scan swiftdata-fetch-budget --strict`: PASS_WITH_NOTES.
- `ios benchmark import-large`: PASS_WITH_NOTES statico/sintetico.
- Limite residuo: benchmark runtime su dataset reale grande non eseguito; nessun mega-refactor applicato.

## 15. Real-device / offline / background consolidation

- Supabase live non usato; nessun dato remoto `TASK130_*` creato; cleanup/residue live non applicabile.
- `harness real-device-feasibility`: PASS_WITH_NOTES con device listabile, ma run 30-60 minuti background/locked/offline non eseguita.
- Stato residuo: PARTIAL / review-required per i limiti real-device, OS scheduler, locked screen e long offline.

## 16. Options first-sync UX consolidation

- `ios smoke options-first-sync`: PASS_WITH_NOTES.
- Coperto staticamente: account, dati locali, dati cloud/baseline, review, autosync, pending locali, ultimo sync/stato, CTA sign-in/review.
- Limite residuo: Retry CTA non e' una CTA Options dedicata in ogni stato; resta accettabile come PASS_WITH_NOTES, da review UX.

## 17. Scanner / accessibility / Dynamic Type / localization consolidation

- `ios smoke scanner-edge`: PASS_WITH_NOTES.
- `ios smoke accessibility`: PASS_WITH_NOTES.
- Coperto staticamente: fallback manuale scanner, background stop/resume, barcode DB existing/new, label principali Options/Database/Scanner, localizzazioni EN/IT/ES/ZH.
- Limiti residui: double-scan veloce, low light, VoiceOver traversal completo e Dynamic Type XXL screenshot non eseguiti.

## 18. Consolidated review ledger TASK-128 to TASK-130

| Gap TASK-128 | Copertura TASK-129 | Copertura TASK-130 | Stato review |
|---|---|---|---|
| P0.1 Android broad test health | Quarantena ByteBuddy/MockK/JDK attach in REVIEW | Regressioni reali TASK-130 corrette; resta solo quarantena strumentale | PASS_WITH_NOTES |
| P0.2 Price contract current/last/previous/old | N/A | Implementato iOS/Android/harness/Supabase read-only | PASS |
| P0.3 Golden corpus import/export | N/A | Fixture + harness statico/roundtrip | PASS_WITH_NOTES / PARTIAL binary exchange |
| P0.4 Real sync offline/background/locked | N/A | Feasibility read-only/static; no live run | PARTIAL |
| P1.1 SwiftData lookup/performance | N/A | Chunked barcode lookup + scan budget | PASS_WITH_NOTES |
| P1.2 Large import memory/progress/cancel | N/A | Benchmark static/sintetico | PASS_WITH_NOTES / runtime large NOT_RUN |
| P1.3 Options first-sync checklist | N/A | Smoke static PASS_WITH_NOTES | PASS_WITH_NOTES |
| P1.4 Generated/PreGenerate dense UX | N/A | Non refactor UI; covered by scanner/a11y static checks only | NOT_RUN |
| P1.5 Scanner real-device edge cases | N/A | Static scanner smoke | PASS_WITH_NOTES / physical NOT_RUN |
| P1.6 Accessibility/Dynamic Type/localizzazioni | N/A | Static smoke + build | PASS_WITH_NOTES |
| P2 cleanup progressivo | N/A | Nessun mega-refactor; solo patch mirate | NOT_RUN by design |

Non e' stato aperto TASK-131 per override esplicito utente: il residuo TASK-128 viene consolidato in TASK-130 come ledger unico. I limiti rimasti richiedono review/accettazione utente, non apertura automatica di nuovo task.

## 19. Handoff REVIEW

TASK-130 passa a `ACTIVE / REVIEW — CONSOLIDATED_TASK128_TO_TASK130_REVIEW_CANDIDATE`, non `DONE`.

- Price contract iOS/Android/Supabase: PASS.
- Android build/debug + targeted sync + price-contract: PASS.
- Android broad: non PASS pieno; quarantena finale PASS_WITH_NOTES solo `BYTEBUDDY_ATTACH_ENV`.
- iOS build/debug + price-contract: PASS.
- Golden corpus / roundtrip / performance / Options / scanner / accessibility / real-device feasibility: PASS_WITH_NOTES con limiti documentati.
- Supabase: solo read-only schema contract; nessun live data, nessun cleanup, nessuna migration/RLS/grants.
- TASK-128 resta piano sorgente approvato.
- TASK-129 resta ACTIVE / REVIEW — PASS_WITH_NOTES_CANDIDATE_QUARANTINE.
- TASK-131/TASK-132/TASK-133/TASK-134/TASK-135 non sono stati aperti.
- Nessun claim production-ready globale.
- Nessun stato DONE dichiarato.

## 20. Final review / DONE closure

2026-05-28 Codex ha eseguito review finale severa e fix-to-DONE autorizzato dall'utente per TASK-128, TASK-129 e TASK-130.

Stato finale: **DONE / CONSOLIDATED_TASK128_TO_TASK130_REVIEW_PASS_WITH_NOTES**.

Evidence finale: `docs/TASKS/EVIDENCE/TASK-130/final-review-done-closure.md`.

Fix finale aggiunto durante review:

- rimossi i warning Swift 6/app mostrati dall'utente su `SyncBackgroundTaskScheduler`, `SyncOrchestrator`, `HistorySessionPayloadSnapshotFactory` e call site `LocalPendingChange`;
- rebuild iOS app PASS e nessun warning `Main actor-isolated` / `Swift 6 language mode` residuo nel build app `20260528T004938Z-ios-build-debug-task-TASK-130-p12054.*`;
- resta solo warning Xcode/AppIntents metadata non funzionale e warning legacy nei test target, documentati come non bloccanti per TASK-130.

Gate finali eseguiti e accettati:

- iOS build/debug PASS, iOS price-contract PASS, iOS simulator smoke PASS, iOS offline test PASS;
- iOS physical build PASS e install/launch one-off via `devicectl` PASS;
- Android build/debug PASS, targeted sync PASS, price-contract PASS;
- Android broad FAIL globale ma quarantine PASS_WITH_NOTES con soli 143 `BYTEBUDDY_ATTACH_ENV`;
- Android emulator smoke PASS, Android physical smoke PASS dopo unlock utente, Android offline L1/L2/reconnect PASS;
- Supabase price schema read-only PASS;
- golden corpus, roundtrip, import-large, SwiftData fetch budget, Options, scanner, accessibility PASS_WITH_NOTES come note accettate;
- sensitive scan, evidence scan e JSON validation PASS.

Residui accettati non bloccanti:

- broad Android non e' PASS pieno finche' resta ByteBuddy/MockK/JDK attach;
- app-to-app binary XLSX exchange, benchmark numerico grande, low-light/double-scan scanner, full VoiceOver/XXL screenshot matrix e long locked/background OS run restano note manuali/strumentali;
- nessun Supabase live/cleanup e nessuna migration/RLS/grants eseguita;
- nessun claim production-ready globale.

TASK-131/TASK-132/TASK-133/TASK-134/TASK-135 non sono stati aperti per override esplicito utente: i residui sono consolidati e accettati in TASK-130.
