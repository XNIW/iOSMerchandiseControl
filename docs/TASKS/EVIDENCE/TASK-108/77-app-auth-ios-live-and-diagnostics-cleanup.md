# TASK-108 Evidence 77 — app-auth iOS live + cleanup Advanced diagnostics

Data: 2026-05-14 19:29 -0400  
Branch: `task108-sync-reset-clean-seed`  
Owner test: `x***@gmail.com` / `6425adb0-...-e8257e`  
Supabase: `merchandisecontrol-dev` / `jpgoimipbothfgkokyvm`

## Scope

Questo pass completa la parte mancante app-auth iOS reale e applica l'override utente successivo: pulire la sezione Advanced diagnostics rimuovendo test/strumenti storici non piu' utili nella UI.

Non e' stato rifatto reset/seed Supabase: il remoto era gia' stato portato a dataset pulito nella evidence `76`, e prima del live app-auth era stato verificato con conteggi `57 / 27 / 19.695 / 41.108` e duplicati ProductPrice `0`.

## iOS app-auth live run

Simulatore:
- `iPhone 15 Pro Max`, iOS `26.1`
- UDID `459C668B-7CE8-443B-BAB3-7D3D5FFC9143`
- app disinstallata/reinstallata dall'utente prima del test; local DB pulito

Metodo:
- harness temporaneo DEBUG-only avviato con sessione reale dell'app (`SupabaseInventoryService` / `SupabaseManualPushService`)
- nessun seed SQL usato come sostituto del push app-auth
- harness rimosso dopo il test

Log:
- `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/iOSMerchandiseControl-3314632fed98/logs/com.niwcyber.iOSMerchandiseControl_2026-05-14T22-57-07-867Z_helperpid37644_ownerpid6224_4612c8f3.log`

Risultati:
- Remote before: suppliers `57`, categories `27`, products `19.695`, product_prices `41.108`
- Local after clear: suppliers `0`, categories `0`, products `0`, product_prices `0`, logical `0`, duplicate groups `0`
- First pull app-auth: suppliers `57`, categories `27`, products `19.695`, product_prices `41.108`, logical `41.108`, duplicate groups `0`
- First pull timings: preview `9.330 ms`, catalog apply `23.623 ms`, price apply `97.147 ms`, total `132.109 ms`
- Second pull no-op: ProductPrice inserted `0`, linked `0`, skipped `41.108`, counts unchanged
- Second pull timings: preview `13.388 ms`, catalog apply `2.949 ms`, price apply `31.407 ms`, total `49.859 ms`

## Incrementale iOS -> Supabase -> iOS

Prodotto scelto:
- remote product ID redatto: `A64EC06D-...`
- barcode SHA-256: `e6caa6095e34562983db955f6cdc577d2fa244e68cadaa47d57205063976bf51`
- modifica: purchase price `320.00 -> 320.01`
- effectiveAt: `2026-05-14 23:00:33 UTC`

Push app-auth:
- catalog product updates `1`
- ProductPrice inserted `1`
- ProductPrice verified `1`
- ProductPrice linked `1`
- timings: catalog `5.094 ms`, ProductPrice `1.794 ms`

Supabase dopo push:
- suppliers `57`
- categories `27`
- products `19.695`
- product_prices `41.109`
- duplicate ProductPrice groups `(owner_user_id, product_id, type, effective_at)`: `0`

Repull iOS dopo reset locale harness:
- suppliers `57`, categories `27`, products `19.695`, product_prices `41.109`
- logical ProductPrice `41.109`, duplicate groups `0`
- timings: preview `9.439 ms`, catalog apply `26.650 ms`, price apply `97.973 ms`, total `136.091 ms`
- second repull no-op: ProductPrice inserted `0`, skipped `41.109`, counts unchanged
- second repull timings: preview `13.831 ms`, catalog apply `2.950 ms`, price apply `31.181 ms`, total `49.967 ms`

## Fix incrementale planner

Durante il live app-auth, il push incrementale e' stato bloccato dal planner aggregato perche' la fetch mirata dei pending catalogo non gestiva bene i pending storici local-key dopo link remoteID.

Fix:
- `LocalPendingAggregatedPushPlanner` ora risolve i remoteID anche dal logical key remoto, non solo da `entityRemoteID`;
- per local-key legacy non reversibile, usa fallback mirato per confrontare le pending keys calcolate sugli oggetti locali;
- il fallback copre supplier/category/product e non riporta falsamente `localSnapshotExceeded` quando il match legacy viene trovato.

Test:
- `LocalPendingAggregatedPushPlannerTests`: `11/11` PASS
- incluso `testCatalogPendingRecordedBeforeRemoteLinkMatchesCurrentRemoteModel`

## Cleanup Advanced diagnostics

Motivazione:
- la sezione DEBUG/Advanced Diagnostics conteneva molte azioni di task storici ormai DONE;
- la UI Options risultava ancora troppo lunga e rumorosa;
- gli strumenti live per task vecchi non devono restare come superficie operativa quotidiana.

Rimozioni UI:
- rimossa l'intera sezione `Developer diagnostics` / Advanced diagnostics da `OptionsView`;
- rimossi preview/apply ProductPrice manuali, manual push, outbox debug, recent sync events, push preflight debug, TASK087/TASK088 smoke UI;
- rimosso il servizio `supabaseSyncEventPreviewService` dalla dependency graph runtime;
- rimossi launch hook DEBUG storici da `ContentView`, incluso il temporaneo `--task108-app-auth-live-run`;
- eliminate localizzazioni `options.developerDiagnostics.*` e `options.supabase.auth.debugDiagnostics`;
- corretto il footer cloud per non rimandare piu' a Developer diagnostics dopo la rimozione della sezione.

Hardening Release:
- `ProductPriceManualPushDebugViewModel.swift`
- `SupabasePushPreflightViewModel.swift`
- `SupabaseSyncEventDebugFormatting.swift`
- `SupabaseSyncEventDebugViewModel.swift`

Questi file restano solo sotto `#if DEBUG`; il binario Release non contiene piu' i simboli/stringhe diagnostici cercati.

File temporaneo rimosso:
- `iOSMerchandiseControl/Task108AppAuthLiveHarness.swift`

## Verifiche

- ✅ `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/LocalPendingAggregatedPushPlannerTests`: PASS, `11/0`
- ✅ `xcodebuild ... Debug ... build`: PASS
- ✅ `xcodebuild ... Release ... build`: PASS
- ✅ XcodeBuildMCP `build_run_sim`: PASS, warnings `[]`
- ✅ Options simulator smoke: PASS; la sezione Advanced diagnostics/Developer diagnostics non e' visibile e il footer cloud non rimanda piu' a strumenti sviluppatore
- ✅ `git diff --check`: PASS
- ✅ `plutil -lint iOSMerchandiseControl/*.lproj/Localizable.strings`: PASS
- ✅ scansione sorgenti: nessun riferimento a `Task108AppAuth`, `--task108`, `TASK108_APP_AUTH`, `options.developerDiagnostics`, `developerDiagnosticsContent`, `syncEventPreviewService`
- ✅ scansione binario Release: nessun match per `TASK087`, `TASK088`, `Task108AppAuth`, `Advanced diagnostics`, `Developer diagnostics`, `ProductPriceManualPushDebugViewModel`, `SupabasePushPreflightViewModel`, `SupabaseSyncEventDebugViewModel`, `SyncEventOutboxDrainDebugViewModel`
- ⚠️ Android app-auth/emulator non eseguito in questo pass: `adb` non risulta disponibile nel PATH; Android build/test minimi erano gia' coperti nella evidence `76`

Warning noto:
- build Debug/Release: `AppIntents metadata skipped. No AppIntents.framework dependency found.`

## Stato TASK-108

Proposta Codex: `READY_FOR_REVIEW_AFTER_APP_AUTH_IOS_AND_DIAGNOSTICS_CLEANUP`, **NON DONE** secondo policy AGENTS.  
La parte iOS app-auth pull/no-op/push incrementale/repull e' passata. Android app-auth cross-device resta follow-up/nota se il reviewer richiede parita' live Android nello stesso task.
