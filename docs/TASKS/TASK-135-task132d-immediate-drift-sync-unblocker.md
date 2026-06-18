# TASK-135 — TASK-132D Immediate Drift Sync Unblocker

## Stato
- Task ID: TASK-135
- Workstream alias: TASK-132D
- Parent: TASK-132 DONE
- Stato task: ACTIVE
- Fase attuale: REVIEW
- Responsabile attuale: Claude / Reviewer
- Ultimo aggiornamento: 2026-06-18 14:55 -0400
- Ultimo agente: Codex / Final review self-fix verifier

## User Override
TASK-132 e' gia' DONE nel tracking storico. Questo hotfix e' stato eseguito su istruzione esplicita utente come workstream post-DONE, senza riscrivere la storia di TASK-132 e senza riusare TASK-134 come task canonico.

## Scopo
Sbloccare la sync automatica quando account/rete sono validi e ci sono baseline assente/stale, drift/parity, remote events o delta locali trusted. "Blocked" non deve significare waiting/no-op: deve restare solo per auth/rete/permessi/account o conflitti reali che richiedono scelta utente.

## Criteri di accettazione
- Baseline assente con account valido non torna noWork: avvia bootstrap/recovery automatico.
- Bootstrap/fullRecovery iOS passano dal runtime automatico e usano snapshot recovery provider.
- Pending locale trusted iOS usa sequenza push delta + drain finale.
- Remote event/drift iOS con pending usa sequenza pull-first + push delta + drain finale.
- Android auth/foreground/network possono attivare pull-only reconcile guardato anche se il catalogo locale non e' vuoto.
- Android push automatico resta limitato a delta locali trusted e schedula un drain finale.
- UI iOS/Android non lascia "noWork"/"Waiting" mascherare baseline/drift o outcome automatici riusciti.
- Nessun service_role, nessun bypass RLS, nessun push-all.

## Execution
Codex ha applicato il fix minimo in:
- iOS decision/runtime/orchestrator/background/options:
  - `SyncDecisionEngine.swift`
  - `SyncDecisionInputProvider.swift`
  - `AutomaticSyncEngine.swift`
  - `SyncOrchestrator.swift`
  - `SyncBackgroundTaskScheduler.swift`
  - `OptionsView.swift`
  - localizzazioni Options EN/IT/ES/ZH
- iOS tests:
  - `SyncDecisionEngineTests.swift`
  - `Task118AutomaticDomainTests.swift`
  - `Task119AutomaticArchitectureTests.swift`
- Android autosync/UI:
  - `CatalogAutoSyncCoordinator.kt`
  - `CatalogSyncViewModel.kt`
- Android clean reopen/ProductPrice backfill:
  - `ProductPriceDao.kt`
  - `PriceBackfillWorker.kt`
- Android tests:
  - `CatalogAutoSyncCoordinatorTest.kt`
  - `CatalogSyncViewModelTest.kt`
  - `DefaultInventoryRepositoryTest.kt`
- Agent tooling:
  - `tools/agent/lib/supabase.sh`
  - `tools/agent/lib/sync.sh`

Override utente 2026-06-17: completata anche la prova live cross-platform su simulator/emulator senza dichiarare DONE. Durante il gate clean reopen Android e' emerso un falso pending ProductPrice: due righe `BACKFILL_CURR` generate dal backfill legacy per un prodotto cloud-linked arrivato da iOS non avevano `product_price_remote_refs`, producendo `Waiting to sync` nonostante catalog parity. Fix minimo: il backfill legacy ora salta i prodotti gia' cloud-linked e rimuove solo righe `BACKFILL_CURR` cloud-linked prive di remote bridge; il tooling counts Android include i ProductPrice local-only nel pending aggregate.

Micro-fix UX finale richiesto dall'utente: iOS Options, card `Stato database locale`, rinomina la precedente label pull-specifica in label generica di sync: IT `Ultima sincronizzazione`, EN `Last sync`, ES `Última sincronización`, zh-Hans `上次同步`. Nessuna logica runtime modificata.

Polish UX pubblico finale richiesto dall'utente, senza modifiche runtime sync:
- iOS Options: rimosse le righe pubbliche `Modifiche locali in attesa` dalla card account/sync e dalla card `Stato database locale`; rimosso anche il box finale `Suggerimento`.
- Android Options: card account e sync automatica fuse in una sola card compatta; rimossa la card separata `Sincronizzazione automatica`, rimossa la testata ridondante della card unificata nello stato signed-in, email mascherata (`x***@gmail.com`), azione `Esci` compatta, nessuna riga pubblica `Cambios locales pendientes` / `Cuenta cloud`.
- Pending locali e account state restano disponibili internamente per runtime/test/harness/evidence; nessuna modifica a Supabase schema, auth flow o core sync.

## Fix

Continuation History parity richiesta dall'utente il 2026-06-17, eseguita come override operativo rispetto allo stato precedente `REVIEW` senza marcare DONE.

Fix iOS applicato:
- `HistorySessionPayloadCodec` ora espone una fingerprint logica History senza `remoteID`, stabile per payload/timestamp/supplier/category/overlay.
- `HistorySessionSyncService` full pull/recovery collega una local-only equivalente alla row remota invece di inserire duplicati.
- `HistoryIncrementalApplyService` applica la stessa dedupe/linking nel drain automatico da `sync_events`.
- `LocalPendingChangeAccumulator.acknowledgeHistorySessionChange` riconosce anche la previous remote/local key quando una sessione viene relinkata.
- `LocalDatabasePublicSummary.makeReconciliationAware` conta History come active user-visible non-tombstoned, allineato alla History UI.
- `OptionsRemoteCountSupabaseAdapter` conta `shared_sheet_sessions` active user-visible filtrando i campi minimi lato client, invece di usare solo count active grezzo.

Test iOS aggiunti:
- local-only History con stesso payload logico di una row remota diversa non duplica, relinka `remoteID` e ack pending.
- Options/local database summary esclude fixture tecniche `TASK135_MATRIX_*` e tombstone dal count History pubblico, mantenendo visibili le fixture live finali finche' attive.

Continuation History final parity richiesta dall'utente il 2026-06-17 21:22 -0400, eseguita come FIX su override esplicito prima di qualsiasi DONE.

Mismatch iOS 39 vs 35 risolto:
- Tool obbligatori usati: `tools/agent/history_snapshot_ios.sh`, `tools/agent/history_snapshot_android.sh`, `tools/agent/history_snapshot_supabase.sh`, `tools/agent/history_diff.py`.
- La tabella row-level iOS 240F delle 39 righe attive locali e' in `docs/TASKS/EVIDENCE/TASK-135-history-final-parity-20260617-211622/diffs/ios-240F-history-39-visibility-table.md`.
- Root cause del mismatch: Options contava 39 righe active grezze, mentre History UI mostra 35 righe user-visible. Le 4 righe extra sono fixture tecniche TASK135, non tombstone e non entry utente.
- Righe iOS contate prima da Options ma non mostrate da History UI:
  - `560da308-71a5-43f2-9bf3-4c92502c0f8a` / remote `560da308-71a5-43f2-9bf3-4c92502c0f8a`, title `TASK135_MATRIX_20260617_192636_RT_20260617T232636Z_IOS_MATRIX_IOS_HISTORY_CREATE`, timestamp `2026-05-13 19:20:00`, reasonHidden `title technical/TASK`.
  - `7be52c5a-2e8b-4090-a43f-7845c49bb13b` / remote `7be52c5a-2e8b-4090-a43f-7845c49bb13b`, title `TASK135_MATRIX_20260617_192636_RT_20260617T232636Z_IOS_MATRIX_IOS_HISTORY_UPDATE_FINAL`, timestamp `2026-05-13 19:20:00`, reasonHidden `title technical/TASK`.
  - `53d91b99-1a32-4711-bfdc-6636a7cce6c1` / remote `53d91b99-1a32-4711-bfdc-6636a7cce6c1`, title `TASK135_MATRIX_20260617_192636_RT_20260617T232636Z_ANDROID_MATRIX_ANDROID_HISTORY_CREATE`, timestamp `2026-05-21 18:00:00`, reasonHidden `title technical/TASK`.
  - `7b22539f-95b4-4165-a3b6-869bfedc27b4` / remote `7b22539f-95b4-4165-a3b6-869bfedc27b4`, title `TASK135_MATRIX_20260617_192636_RT_20260617T232636Z_ANDROID_MATRIX_ANDROID_HISTORY_UPDATE_FINAL`, timestamp `2026-05-21 18:00:00`, reasonHidden `title technical/TASK`.
- Options iOS ora usa la stessa predicate logica della History UI: id/title user-facing, fixture tecniche `TASK135_MATRIX_*` escluse, tombstone escluse salvo pending-delete locale visibile alla UI. Il count pubblico diventa 35; le fixture live finali `TASK135_HISTORY_FINAL_*` restano user-visible finche' attive.
- Android e' stato allineato alla stessa predicate: 39 active, 35 user-visible/shown, stesse 4 fixture `TASK135_MATRIX_*` escluse. In piu', Android normalizza i displayName UUID-only nel formatter UI e nella fingerprint/payload History per evitare drift artificiale con iOS.
- Supabase linked snapshot e row-level visible diff confermano 35 righe visibili su iOS, Android e Supabase, con 35 fingerprint presenti su tutte le sorgenti, zero only-source, zero duplicati e zero mismatch.

Continuation History final safety gate richiesta dall'utente il 2026-06-18, eseguita prima di qualsiasi DONE:
- Predicate finale confermata con i tool obbligatori: `history_snapshot_ios.sh`, `history_snapshot_android.sh`, `history_snapshot_supabase.sh`, `history_diff.py --visible-only`.
- Snapshot Android corretto per copiare anche `app_database-wal` e `app_database-shm`; senza WAL lo snapshot perdeva temporaneamente la fixture creata da iOS pur applicata dal runtime Android.
- Owner scope delle 4 righe hidden PASS: tutte appartengono allo stesso owner linked selezionato e sono fixture tecniche `TASK135_MATRIX_*`, non entry utente.
- Live create iOS -> Android PASS: `TASK135_HISTORY_FINAL_IOS_20260618T142841Z` visibile su iOS, Supabase e Android con remote `87670182-d266-4c2c-bb08-368211909e9d` prima della cleanup.
- Live create Android -> iOS PASS: `TASK135_HISTORY_FINAL_ANDROID_20260618T143328Z` visibile su Android, Supabase e iOS con remote `854d45bf-920b-4b9a-82ef-55355d7f9bac` prima della cleanup.
- Live update PASS: aggiornamento della fixture iOS mantiene lo stesso remote_id e converge su fingerprint `79568555c54e98902d0b5f1c773504f81b60e56f7e63d714c781a13fe6780adb` e payloadHash `995bc9df0060d592ae779b7e589501c3be71b7e7a105dbb06f12d8ca4231f7e4` su iOS/Android/Supabase.
- Tombstone cleanup PASS: le due fixture `TASK135_HISTORY_FINAL_*` sono tombstoned e hidden su iOS/Android/Supabase; residue finale visibile `0`, active residue `0`.
- Clean reopen finale PASS: iOS, Android e Supabase restano in parity row-level visibile 35/35/35 con History active 39 e shown/userVisible 35.

Final Catalog/Product delete architecture fix richiesta dall'utente il 2026-06-18 12:45 -0400, eseguita come FIX su override esplicito senza refactor:
- Audit architettura documentato in `docs/TASKS/EVIDENCE/TASK-135-catalog-delete-architecture-20260618-120948/diffs/catalog-delete-architecture-audit.md`.
- Target architecture documentata in `docs/TASKS/EVIDENCE/TASK-135-catalog-delete-architecture-20260618-120948/diffs/catalog-delete-target-architecture.md`.
- Root cause confermata: iOS registra pending Product delete/tombstone e poi fa hard delete SwiftData; `CatalogPushService` cercava ancora il `Product` locale prima di inviare il tombstone, quindi il remote `deleted_at` poteva restare null.
- Fix iOS minimo: `CatalogPushService` gestisce `.delete` prima di `findProduct`, usa `entityRemoteID`/logical key, invia `deleted_at`, ack pending al successo, non ricrea Product hard-deleted e ack-a delete local-only senza remote call.
- Fix Android minimo: `InventoryRepository.pushDirtyCatalogDeltaToRemote(...)` drena `pending_catalog_tombstones` nel fallback quick-sync/realign prima degli upsert active, allineando il path fallback al path normale.
- Nuovo tool evidence read-only: `tools/agent/catalog_delete_state_dump.sh`, con snapshot iOS SwiftData pending/products, Android Room products/tombstones e Supabase product/sync_events scoped per prefisso.
- ProductPrice resta append-only/historical; active count esclude Product tombstoned e nessun pending falso viene creato dopo Product delete.
- Live Product delete PASS con harness valido, non DB seed: iOS write/delete -> Supabase tombstone -> Android hidden PASS; Android write/delete -> Supabase tombstone -> iOS hidden PASS.
- Cleanup prefissi `TASK135_DELETE_PRODUCT_IOS_FIX_20260618T162539Z_` e `TASK135_DELETE_PRODUCT_ANDROID_FIX_20260618T162703Z_` PASS su Supabase e Android locale; clean reopen non incrementa `sync_events` (`1869`/max `3121` before=after).
- History regression post-cleanup PASS: visible row-level parity iOS/Android/Supabase `35/35/35`, `present_on_all=35`, zero missing/duplicates/mismatch, zero TASK135 visible residue.

Final acceptance review + self-fix loop richiesta dall'utente il 2026-06-18 13:50 -0400, eseguita senza refactor e senza DONE:
- Evidence principale: `docs/TASKS/EVIDENCE/TASK-135-final-review-20260618-135046/REPORT.md`.
- CodeRabbit autenticato e rieseguito su iOS sorgente scoped: primo run 1 major valido su `LocalPendingChangeAccumulator.supersedeProductPriceChanges(for:)` per cache `cachedActiveCount` stale; fix minimo applicato invalidando la cache quando almeno un pending ProductPrice viene superseded; rerun CodeRabbit PASS con 0 issues.
- Test iOS mirati post-fix CodeRabbit PASS: 5/5 su event fingerprint catalog, Product tombstone hard-delete/local-only e ProductPrice pending supersede/link.
- iOS Debug build post-fix CodeRabbit PASS; iOS `git diff --check` PASS.
- Screenshot live correnti acquisiti: iOS Options `Sessioni cronologia 35`, Android Options `Sessioni cronologia 35`, iOS History e Android History senza `TASK135_MATRIX`.
- Row-level History post-reopen confermata con tool obbligatori: iOS/Android/Supabase active `39`, userVisible/shown `35`, hidden active `4`, visible parity `35/35/35`, zero missing/duplicates/payload mismatch.
- Catalog post-reopen stabile: iOS/Android/Supabase products `19704`, suppliers `66`, categories `35`, product_prices `41131`; pending aggregate iOS/Android `0`.
- Clean reopen/no false push finale PASS: `sync_events` count `1886`, max id `3138` invariati before/after.
- Supabase hardening backup TASK-108 applicato live via linked SQL e verificato; il workspace Supabase locale non ha `.git`, quindi non c'e' commit/push Supabase da questo ambiente.
- TASK resta ACTIVE / REVIEW per policy. Stato consigliato: READY_FOR_USER_ACCEPTANCE / DONE candidate.

## Handoff post-fix
Reviewer deve verificare soprattutto:
- iOS recovery con pending locali attivi: `replaceLocalCatalogWithRemoteSnapshot` continua a proteggere pending non classificabili; il follow-up UI field-by-field resta necessario per conflitti reali.
- Android pull-only reconcile su foreground/network/auth e' guardato da `BOOTSTRAP_RETRY_GUARD_MS`, ma puo' comunque essere costoso su cataloghi grandi.
- Live runtime simulator/emulator e' ora eseguito con evidence corrente: iOS->Android PASS, Android->iOS PASS, ProductPrice append-only PASS, History/session PASS, clean reopen/no false push PASS, Options iOS/Android pulite, counts finali coerenti. TASK resta ACTIVE / REVIEW per policy: Codex non marca DONE.

Continuation History parity 2026-06-17 21:06 -0400:
- Prossima fase: REVIEW.
- Prossimo agente: Claude / Reviewer.
- Evidence nuova: `docs/TASKS/EVIDENCE/TASK-135-history-parity-20260617-205651/`.
- Check iOS PASS: targeted History/Options tests 18/18, Debug build XcodeBuildMCP PASS, `git diff --check` PASS.
- Android/Supabase live NOT RUN/BLOCKED in questo workspace: Android repo/ADB non disponibili; `supabase status` fallisce per container locale mancante. Quindi non dichiarare row-level parity finale iOS+Android+Supabase da questo pass.
- Reviewer deve verificare prioritariamente che la dedupe iOS per fingerprint logica sia accettabile come bridge cross-platform e poi rieseguire la live matrix con Android/Supabase disponibili.

Continuation History final parity 2026-06-17 22:06 -0400:
- Prossima fase: REVIEW.
- Prossimo agente: Claude / Reviewer.
- Evidence nuova: `docs/TASKS/EVIDENCE/TASK-135-history-final-parity-20260617-211622/`.
- Gate mismatch iOS risolto: iOS simulator 240F ha 39 History active locali, 35 user-visible/shown. Le 4 righe non visibili sono fixture tecniche `TASK135_MATRIX_*`, non entry utente.
- Tabella richiesta delle 39 righe iOS: `diffs/ios-240F-history-39-visibility-table.md`.
- Android repeat check: `diffs/android-history-39-visibility-table.md`, 39 active, 35 user-visible/shown, stesse 4 fixture TASK135 escluse.
- Supabase/iOS/Android visible row-level parity: `diffs/history-visible-ios-android-supabase-row-level-diff.md`, 35 fingerprint su tutte le sorgenti, zero missing, zero duplicati, zero mismatch, zero TASK135 residue visibile.
- Count finali: `diffs/final-count-parity-summary.md` riporta products `19704`, suppliers `66`, categories `35`, product_prices `41131`, History active `39`, History shown/userVisible `35`; pending aggregate iOS/Android `0`.
- Screenshot/evidence UI: Android Options mostra `Sessioni cronologia 35` in `screenshots/android-options-history-count-35.png`; Android History list in `screenshots/android-history-list-visible-35.png`; iOS 240F screenshot Options disponibili in `screenshots/ios-240F-options-history-count-35*.png`.
- TASK resta ACTIVE / REVIEW per policy. Non marcare DONE senza accettazione/review.

Final safety gate 2026-06-18 10:50 -0400:
- Prossima fase: REVIEW.
- Prossimo agente: Claude / Reviewer.
- Evidence finale: `docs/TASKS/EVIDENCE/TASK-135-history-final-parity-20260617-211622/`.
- Tabelle finali richieste: `diffs/final-ios-history-39-visibility-table.md` e `diffs/final-android-history-39-visibility-table.md`.
- Row-level diff finale: `diffs/final-history-row-level-diff.md`, visible rows iOS/Android/Supabase `35/35/35`, `present_on_all=35`, zero only-source, zero duplicate remote/fingerprint, zero payload/fingerprint mismatch.
- Clean reopen summary: `diffs/final-clean-reopen-summary.json`, History active `39` e shown/userVisible `35` su iOS, Android e Supabase; residue `TASK135_HISTORY_FINAL_*` visibile `0`, active `0`.
- Live gate evidence: `live/ios-to-android-visible-diff.md`, `live/android-to-ios-visible-diff.md`, `live/update-visible-diff.md`, `live/tombstone-ios-status.json`, `live/tombstone-android-status.json`.
- Screenshot finali: `screenshots/options-ios-history-count-35-final.png`, `screenshots/history-ios-visible-list-final.png`, `screenshots/options-android-history-count-35-final.png`, `screenshots/history-android-visible-list-final.png`.
- Tooling snapshot allineato: `history_snapshot_android.sh` include WAL/SHM; predicate fixture tecnica ristretta a `TASK135_MATRIX_*` su tool, iOS e Android.
- TASK resta ACTIVE / REVIEW per policy. Non marcare DONE senza accettazione/review.

Final Catalog/Product delete architecture fix 2026-06-18 12:45 -0400:
- Prossima fase: REVIEW.
- Prossimo agente: Claude / Reviewer.
- Evidence principale: `docs/TASKS/EVIDENCE/TASK-135-catalog-delete-architecture-20260618-120948/REPORT.md`.
- Product delete/tombstone iOS -> Android: PASS con prefisso `TASK135_DELETE_PRODUCT_IOS_FIX_20260618T162539Z_`.
- Product delete/tombstone Android -> iOS: PASS con prefisso `TASK135_DELETE_PRODUCT_ANDROID_FIX_20260618T162703Z_`.
- Catalog stable: final active counts Supabase/iOS/Android products `19704`, suppliers `66`, categories `35`, product_prices `41131`, pending iOS/Android `0`.
- History stable: active `39`, userVisible/shown `35` su iOS/Android/Supabase; 39 fisiche = 35 visibili per le 4 fixture tecniche `TASK135_MATRIX_*` owner-scoped e non user-visible.
- Clean reopen/no false push: PASS; `sync_events` invariato count `1869`, max id `3121`.
- Build/test/check finali PASS: iOS Catalog delete tests, iOS History/Options 39/39, iOS Debug build, Android Catalog delete tests, Android History tests, Android assembleDebug, Android lintDebug, iOS/Android `git diff --check`, tooling syntax, evidence hygiene.
- Screenshot finali post-clean-reopen: `screenshots/ios-final-post-delete-clean-reopen.png`, `screenshots/android-final-post-delete-clean-reopen.png`.
- TASK resta ACTIVE / REVIEW per policy. Non marcare DONE senza accettazione/review; stato consigliato: READY_FOR_USER_ACCEPTANCE / DONE candidate.

Final acceptance review + self-fix loop 2026-06-18 14:55 -0400:
- Prossima fase: REVIEW / user acceptance.
- Prossimo agente: Claude / Reviewer oppure utente per accettazione.
- Evidence principale: `docs/TASKS/EVIDENCE/TASK-135-final-review-20260618-135046/REPORT.md`.
- CodeRabbit finale iOS source scoped: 0 issues dopo fix cache; Android committed review: 0 issues.
- Catalog e History risultano entrambi stabili: Catalog counts parity `19704/66/35/41131`, pending iOS/Android `0`, clean reopen no false push; History visible row-level parity `35/35/35`, active fisiche `39` con 4 fixture tecniche `TASK135_MATRIX_*` hidden owner-scoped.
- Screenshot correnti richiesti: `screenshots/ios-options-history-count-35-current.png`, `screenshots/android-options-history-count-35-current.png`, `screenshots/ios-history-visible-current.png`, `screenshots/android-history-visible-current.png`.
- Build/test/check finali PASS: iOS targeted new-fix tests 5/5, iOS targeted History/Options PASS, iOS Debug build PASS, Android targeted History/Catalog PASS, Android assembleDebug + lintDebug PASS, iOS/Android `git diff --check` PASS.
- TASK resta ACTIVE / REVIEW per policy. Non marcare DONE; pronto come READY_FOR_USER_ACCEPTANCE / DONE candidate.

## Evidence
Evidence root:
`docs/TASKS/EVIDENCE/TASK-135-live-simulator-proof-20260617-184019/`

Check eseguiti:
- iOS targeted tests: PASS, 39 tests / 0 failures.
- iOS Debug build: PASS.
- Android targeted tests: PASS.
- Android assembleDebug + lintDebug: PASS.
- iOS git diff check: PASS.
- Android git diff check: PASS.
- service_role/bypass scan: PASS_WITH_NOTE, solo guard di rifiuto in `SupabaseConfig.swift`.
- iOS Options stale cloud-check targeted tests: PASS.
- iOS build/test after Options fix: PASS.
- Android `DefaultInventoryRepositoryTest` targeted backfill cleanup: PASS.
- Android assembleDebug + assembleDebugAndroidTest after backfill cleanup: PASS.
- Live mutation near-realtime matrix: PASS; ProductPrice targeted price ids iOS->Android 13 / Android->iOS 9; History targeted session ids 5 each direction; no full pull.
- Canonical catalog iOS -> Supabase -> Android single prefix `TASK135_IOS_CROSS_20260617_193032_`: PASS.
- Canonical catalog Android -> Supabase -> iOS single prefix `TASK135_ANDROID_CROSS_20260617_193207_`: PASS.
- Clean reopen/no false push: PASS; `sync_events` before/after count `1848`, max id `3100`.
- Final active/user-visible counts parity: Supabase/iOS/Android `products=19704`, `suppliers=66`, `categories=35`, `product_prices=41131`, `history_sessions=39`.
- iOS Options screenshot: PASS; no `Local database needs a cloud check`, pending 0, local DB up to date.
- Android Options screenshot: PASS; no `Waiting to sync`, pending 0, local DB ready.
- Final iOS Debug build after evidence: PASS (`raw/ios-final-debug-build-after-clean-reopen.log`).
- Final iOS Options targeted tests after evidence: PASS, 10 tests / 0 failures (`raw/ios-final-options-tests-after-clean-reopen.log`).
- Final Android targeted backfill cleanup test: PASS (`raw/android-final-backfill-cleanup-targeted-test.log`).
- Final tooling syntax + iOS/Android `git diff --check`: PASS.
- Final forbidden copy scan: PASS (`raw/final-forbidden-copy-scan.txt` empty after headings).
- Post-label localization `plutil -lint`: PASS (`raw/ios-localizations-plutil-after-last-sync-label.log`).
- Post-label iOS Debug build: PASS (`raw/ios-debug-build-after-last-sync-label.log`).
- Post-label iOS Options screenshot/runtime snapshot: PASS (`screenshots/ios-options-last-sync-label-final.jpg`, `raw/ios-options-last-sync-label-runtime-snapshot.txt`).
- Post-label clean reopen invariant: PASS; `sync_events` remains count `1848`, max id `3100` (`counts/sync-events-after-last-sync-label.json`).
- Post-label counts parity: PASS; final active/user-visible counts unchanged and iOS/Android pending aggregate 0 (`counts/final-after-last-sync-label-*.json`).
- Public UX polish tests/builds: PASS; iOS `plutil -lint`, iOS Options targeted tests 9/9, iOS Debug build, Android `CatalogSyncViewModelTest` + `OptionsScreenPublicUxTest`, Android `assembleDebug`, iOS/Android `git diff --check`.
- Final iOS public UX screenshot: PASS; `screenshots/ios-options-final-no-tip-public-ux-20260617-2042.jpg` shows no `Suggerimento`, no public pending row, `Ultima sincronizzazione`, clean local DB counts.
- Final Android public UX screenshot: PASS; `screenshots/android-options-final-unified-no-header-20260617-2044.png` shows one compact account/sync card with no redundant header, masked email, no public pending/account implementation rows, no `Waiting to sync`.
- Final post-polish counts parity: PASS; `counts/final-after-unified-no-header-*.json` all report products `19704`, suppliers `66`, categories `35`, product_prices `41131`, history_sessions `39`; iOS/Android pending aggregate 0.
- Final post-polish clean reopen/no false push invariant: PASS; `counts/sync-events-after-unified-no-header.json` remains count `1848`, max id `3100`.
- History final parity tooling syntax: PASS; `bash -n tools/agent/history_snapshot_ios.sh tools/agent/history_snapshot_android.sh tools/agent/history_snapshot_supabase.sh tools/agent/history_fixture_live.sh tools/agent/lib/sync.sh` e `python3 -m py_compile tools/agent/history_diff.py`.
- History final iOS targeted tests/build: PASS; targeted History/Options tests 18/18 e XcodeBuildMCP Debug build PASS; nessun warning nuovo introdotto nei check diagnostici mirati.
- History final Android targeted tests: PASS; `DefaultInventoryRepositoryTest` + `OptionsScreenPublicUxTest`.
- History final Android assembleDebug: PASS.
- History mismatch gate iOS: PASS; iOS 240F local History active `39`, userVisible/shown `35`; 4 hidden rows identificate come fixture tecniche TASK135 in `diffs/ios-240F-history-39-visibility-table.md`.
- History mismatch gate Android: PASS; Android local History active `39`, userVisible/shown `35`; stesse 4 fixture tecniche TASK135 in `diffs/android-history-39-visibility-table.md`.
- History final visible row-level parity Supabase/iOS/Android: PASS; `diffs/history-visible-ios-android-supabase-row-level-diff.md` riporta `present_on_all=35`, no only-source, no duplicates, no mismatches.
- History final counts parity Supabase/iOS/Android: PASS; `diffs/final-count-parity-summary.md` riporta products `19704`, suppliers `66`, categories `35`, product_prices `41131`, History active `39`, History shown/userVisible `35`.
- History final safety live create/update/delete: PASS; iOS->Android create, Android->iOS create, update same remote_id/hash, tombstone bidirezionali e cleanup residue `0`.
- History final clean reopen row-level parity: PASS; `diffs/final-history-row-level-diff.md` riporta 35 visible rows su iOS/Android/Supabase e nessun mismatch.
- History final screenshots: PASS; iOS e Android hanno screenshot finali Options con `Sessioni cronologia 35` e screenshot Cronologia senza residue `TASK135_MATRIX`/`TASK135_HISTORY_FINAL`.
- Android lintDebug post-fix: PASS.
- Catalog/Product delete architecture audit: PASS; documenti `catalog-delete-architecture-audit.md` e `catalog-delete-target-architecture.md`.
- iOS targeted Catalog delete tests: PASS; hard-deleted pending Product tombstone, local-only Product delete ack, `catalog_tombstone` RPC mapping.
- Android targeted Catalog delete tests: PASS; fallback quick-sync/realign drena pending Product tombstone senza Product row residua, piu' regressioni tombstone esistenti.
- Live Product delete iOS -> Android: PASS; Supabase tombstone `35bc3604-0c66-4a29-84f6-bba5274ac90e` osservato con `deleted_at`, Android receiver non mostra il Product.
- Live Product delete Android -> iOS: PASS; Supabase tombstone `510114b1-ea64-4e0f-b520-b8aa00fe67e3` osservato con `deleted_at`, iOS receiver non mostra il Product.
- Cleanup Product delete fixture: PASS; Supabase dry-run/execute/residue e Android scoped cleanup seriale PASS per entrambi i prefissi.
- Clean reopen Product delete/no false push: PASS; `counts/clean-reopen-sync-events-before.json` e `counts/clean-reopen-sync-events-after.json` riportano `sync_events` count `1869`, max id `3121` invariati.
- Final Catalog counts parity: PASS; iOS/Android/Supabase products active `19704`, suppliers `66`, categories `35`, product_prices active `41131`; pending iOS/Android `0`.
- Final History row-level visible parity after Catalog delete cleanup: PASS; `diffs/history-visible-diff-after-catalog-delete-cleanup.md` riporta rows `35/35/35`, `present_on_all=35`, zero duplicates/mismatch/TASK135 visible residue.
- iOS targeted History/Options tests post-fix: PASS; 39 tests / 0 failures.
- iOS Debug build post-fix: PASS.
- Android History targeted tests post-fix: PASS.
- Android assembleDebug + lintDebug post-fix: PASS.
- Tooling syntax post-fix: PASS; `bash -n` per `catalog_delete_state_dump.sh` e history snapshot scripts, `python3 -m py_compile tools/agent/history_diff.py`.
- Final evidence hygiene scan: PASS_WITH_NOTE; nessun DB/store raw, nessun file evidence >5MB, nessun `.idea`; unico match `service_role` e' testo documentale "nessun service_role", non segreto.

Check non eseguiti:
- Nessun physical device in questo giro: NON ESEGUITO, fuori dallo scope richiesto per TASK-135 corrente.

## Rischi rimasti
- DONE non marcato per policy locale: serve accettazione/review utente o Claude.
- La UI completa `SyncResolutionPrompt` field-by-field resta follow-up se i conflitti reali devono essere presentati in un nuovo sheet dedicato invece delle superfici TASK-126 esistenti.
- Android `PriceBackfillWorker` resta legacy; ora e' guardato per prodotti cloud-linked, ma una revisione futura potrebbe rimuovere definitivamente il backfill one-shot o legarlo solo a import locali storici.
- XcodeBuildMCP nel run finale ha usato un simulatore diverso dai defaults per `build_run_sim`; il binario risultante e' stato installato/lanciato manualmente sul simulatore 240F per screenshot e snapshot finali.
- Gli screenshot del pass Catalog/Product delete sono finali post-clean-reopen; il before/after row-level del prodotto e' coperto dai report harness, query Supabase, state dump SwiftData/Room e conteggi `sync_events` before/after.
