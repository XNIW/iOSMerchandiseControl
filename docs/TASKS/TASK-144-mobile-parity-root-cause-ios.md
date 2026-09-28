# TASK-144 — Mobile parity root-cause ios

## Stato

- File task: `docs/TASKS/TASK-144-mobile-parity-root-cause-ios.md`
- Stato: `REVIEW`
- Fase: `REVIEW`
- Responsabile: `CODEX_EXECUTOR_IOS`; orchestratore parent, reviewer indipendente separato.
- Data: 2026-09-28
- Baseline: `30d226d0fb9b8679a1dd034c6e82319645337f22`
- Branch: `codex/mobile-parity-root-cause-ios`
- Coordination key: `MERCHANDISECONTROL_MOBILE_PARITY_ROOT_CAUSE`

## Scopo / Obiettivo

Audit funzionale mobile completo e correzione cause F01/F02/F03 e ulteriori difetti confermati; F04 documentale, verifica locale e staging/dispositivi disponibile, senza ampliare le funzionalità richieste.

## Planning

### Analisi

StorefrontAuthoringStore.resetFilter cancella filterTask ma non libera isFilterLoading; loadNextFilterPage non lega ogni callback a query e generazione filtro. LocalDraftRecord esiste ma UserDefaults e replay basato su expectedVersion richiedono verifica di errore disco/eviction/ACK perso; altre operazioni non conservano identità retry.

### Approccio

1. Congelare baseline e riprodurre con regressioni rosse prima della patch.
2. Correggere intent/storage e ownership asincrona con cambi minimi; verificare controparte e contratto server.
3. Eseguire audit delle capacità esistenti e test pertinenti; documentare separatamente code review, fake, runtime e staging.
4. Review indipendente, unico batch fix, re-review e gate canonici finali; preparare commit/PR senza assumere merge/produzione.

### File coinvolti

StorefrontAuthoring.swift, StorefrontAuthoringTests.swift, UI harness e XCUITest esistenti; EditProductView.swift/DatabaseView.swift solo se necessari ai finding; documenti master/task143 per F04.

## Mandato e separazione dei ruoli

Richiesta utente 2026-09-28 `MERCHANDISECONTROL — AUDIT FUNZIONALE, ROOT-CAUSE FIXES, PARITÀ ANDROID/iOS E SINCRONIZZAZIONE`. Il prompt autorizza orchestrazione/planning, executor separati, correzioni funzionali, test, review indipendente e preparazione commit/PR. Questo planning è registrato dal parent orchestratore prima delle patch; gli executor aggiornano Execution/Fix/Handoff. Nessuna chiusura DONE automatica o merge autorizzato per inferenza dai train storici.

Checkout primari con modifiche preesistenti preservati. Niente reset dati, force push, migrazioni/RLS/deploy production, nuove dipendenze, secondo motore sync o pipeline immagini. Harness Excel sospeso non riattivato. Client pubblico read-only; Admin/Supabase consultati solo per contratti e staging necessario. Task precedenti e gate fisici non chiusi automaticamente.

## Criteri di accettazione

| ID | Criterio e verifica richiesta |
|---|---|
| CA-01 | Baseline branch/HEAD/origin/main/diff/worktree/PR/CI exact-SHA registrata; lavoro preesistente preservato. |
| CA-02 | F01: salvataggio draft durevole prima del successo locale; storage fallibile, account/shop/stable ID, base/payload/version/op/key/stato; dismiss/riapertura/nuova istanza/reconnect/disk failure/due prodotti/due scope/conflict/replay testati. Pending separato da cache LRU. |
| CA-03 | F02: richiesta filtro identificata per scope/filtro/query/generazione; reset immediato, no stale success/error/finally, pagination/Tutti; test deterministici + UI rapida e controparte. |
| CA-04 | F03: intent immutabile persistito per tutte le mutation; stesso retry stessa key; ACK ignoto riconciliato prima di inviare payload diverso; test commit con ACK perso, pre-commit timeout, edit dopo validation, concorrenza e restart. Contratto reale staging verificato o dipendenza esterna precisa. |
| CA-05 | F04: stato documentale iOS riconciliato con PR/merge/CI reali, separando implementazione/integrazione/test/distribuzione e preservando gate fisici. |
| CA-06 | Matrice completa inventario/database/anagrafiche/prezzi/history/import-export/immagini/auth-shop/sync/Storefront/localizzazioni-accessibilità; fonte, file, backend, test eseguito e stato tra VERIFIED/DEFECT/MISSING_REQUIRED/NOT_TESTED/EXTERNAL_DEPENDENCY/INTENTIONAL_PLATFORM_DIFFERENCE. |
| CA-07 | Integrità locale/outbox/server/pull/UI verificata; sync automatica bidirezionale, scope/stale callback, offline/reconnect/restart/conflitti/paging/no-op. Convergenza per ID/campi/relazioni; nessun reset code. Gate live non sostituito dai fake. |
| CA-08 | Import/export condiviso CLP/barcode Unicode/quantità/duplicati/footer/no-op e immagini cache/preparazione/staged; fixture esistenti riusate, regressioni semantiche condivise senza riattivare harness Excel. |
| CA-09 | Misurazioni riproducibili prima/dopo per scenari sostenibili, dataset sintetico isolato, campioni/p50/p95/max/condizioni; nessuna ottimizzazione senza evidenza, niente garanzia assoluta 3s. Distinguere foreground/background/sospensione/force-stop. |
| CA-10 | Test rosso prima patch, verde e regressioni adiacenti; gate canonici finali sul codice finale e test UI eseguiti quando ambiente disponibile. Contare PASS/FAIL/SKIP e non equiparare androidTest compilati a eseguiti. |
| CA-11 | Review indipendente, batch fix e re-review; altri cicli solo nuove regressioni P0/P1/P2 concrete; commit/PR per repo con CI exact-SHA, NOT_MERGED se manca autorizzazione. |
| CA-12 | Report MERCHANDISECONTROL_MOBILE_PARITY_ROOT_CAUSE_RESULT con baseline/finali, matrice, finding/prove, test, sync, prestazioni, residui e stati separati. Ogni CA chiuso con ESEGUITO/NON ESEGUIBILE/NON ESEGUITO motivato; nessun “tutto completo” senza prove obbligatorie. |

## Decisione di verifica — compatibilità runner Xcode 27

Il gate canonico baseline fallisce prima dell'esecuzione per conformances di actor test double a protocolli applicativi già isolati MainActor (48 errori su circa23 file, Swift6.4). Il parent orchestratore autorizza il 2026-09-28 un batch test-only separato: allineare i fake a `@MainActor final class`, preservando serializzazione/reentrancy e tutte le asserzioni, più scomposizione di una espressione test troppo costosa al type-checker. Nessuna modifica all'isolamento globale dell'app, ai protocolli runtime, alle dipendenze o alle esclusioni CI. Le slice diagnostiche con override/esclusioni restano evidenza parziale; solo il comando canonico senza esclusioni può superare il gate. Reviewer indipendente controlla anche questo delta. Il cambiamento è necessario a CA-10 e non aggiunge funzionalità.

## Rischi

ACK perso e aggiornamento concorrente richiedono replay del contratto idempotente, non confronto ingenuo della sola versione. Scritture disco e cancellazioni possono interrompere il percorso; preservare pending, input e isolamento. Staging/device possono non disporre di sessione autorizzata; dichiarare gate non eseguibili senza estendere privilegi.

## Execution

### Esecuzione — 2026-09-28

Log dettagliato e file modificati: [ios-execution.md](EVIDENCE/TASK-144/ios-execution.md). Baseline e checkout primario preservati; sorgente applicativa congelata con [manifest](EVIDENCE/TASK-144/ios-source-manifest.json).

- F01/F03 counterpart e F02 riprodotti rossi, poi corretti con journal atomico separato da cache e ownership generazione/scope.
- F05 input mentre ACK è sospeso: XCUITest rosso→verde; UI/UX intenzionale, campi temporaneamente disabilitati durante load/mutation/adoption per impedire perdita input, senza redesign.
- Review indipendente: solo R-I01 iOS, batch fix e guardia scope riapprovati; nessun P0/P1/P2 aperto nel sorgente.
- Gate finale mirato: 46 unit/integration  + 4 XCUITest = 50 PASS  / 0 FAIL / 0 SKIP sul codice finale. UI usa componenti SwiftUI reali nel DEBUG harness sintetico; non è Database live autenticato.
- Prima full: 1353 PASS /1 FAIL /36 SKIP. Runner precedente ha chiuso il simulatore durante il test prezzi da 30k; SIGTERM, poi restart dei casi restanti. [Causa osservata](EVIDENCE/TASK-144/full-first-runtime-failure.md). Caso invariato ripetuto isolato: 1/1 PASS. Full sequenziale sul codice finale: **1355 PASS / 0 FAIL / 36 SKIP**, totale 1391 casi unici (1347 unit/integration PASS + 8 XCUITest PASS), nessun retry/restart e nessun runner/build concorrente. [Summary ufficiale](EVIDENCE/TASK-144/full-final-summary.json).
- Build Release e analyze finali PASS; 4 plutil PASS. 26 warning analyze: 18 vendor + 8 Swift preesistenti o esposti su codice invariato; [prova causale Task119](EVIDENCE/TASK-144/warning-provenance.json).
- Benchmark core XCTest separati: D100-L con 12k prodotti / 48k prezzi, 2/2 PASS; preview 5.147 s, prezzi 82.485 s (n = 1), nessuna misura UI/rete. Durable draft n = 30: p50 1.156 ms, p95 1.367 ms, max 2.597 ms. [Metriche](EVIDENCE/TASK-144/synthetic-benchmarks.json).
- Compatibilità Xcode27 separata in 24 file test, assert/gates invariati, commit coordinatore 4575eefb; nessuna modifica isolamento runtime/dipendenze. [Rationale](EVIDENCE/TASK-144/xcode27-compatibility/README.md).
- Canonical sensitive scan app/tests/contracts/workflow e scan nuove evidence PASS; ID simulatore redatto. Nessun deploy/nuovo account/reset dati, né harness Excel sospeso riattivato.

### Matrice CA — perimetro locale dell'executor

| CA | Stato locale | Evidenza / limite residuo |
|---|---|---|
| CA-01 | ESEGUITO baseline/worktree; NON ESEGUITO commit finale/CI da executor | Baseline 30d226d0 e hash sorgente; coordinatore possiede commit/PR/CI exact SHA. |
| CA-02 | ESEGUITO — VERIFIED locale | Persistenza fallibile, migrazione, nuova istanza/cache eviction,2 prodotti × 3 scope, ACK/restart/disk failure/conflitto; live mobile separato. |
| CA-03 | ESEGUITO — VERIFIED locale | 6 test deterministici  + XCUITest rapido filtri e stato loading/Tutti; controparte Android coordinata. |
| CA-04 | ESEGUITO — VERIFIED locale e contratto staging | Tutte le 5 operation, identity, ACK perso / B, TTL, no-op e ricezione C; SQL 12/12 del coordinatore distinto da perdita HTTP reale. |
| CA-05 | ESEGUITO dal coordinatore | Master/TASK143 parent-owned, stati storici e gate fisici preservati; non inferire distribuzione da merge. |
| CA-06 | ESEGUITO matrice fonte/test/limite | Tabella capacità nell'evidence; VERIFIED locale, EXTERNAL_DEPENDENCY live/hardware, NOT_TESTED manuale dove dichiarato. |
| CA-07 | ESEGUITO locale; NON ESEGUITO live da executor | Test sync/outbox/paging/no-op e scope; EXTERNAL_DEPENDENCY collaudo autenticato Android↔iOS owner separato, nessuna promessa di 3 s. |
| CA-08 | NON ESEGUITO integralmente; regressioni locali ESEGUITE | Suite esistenti import/export/images e fixture Unicode/CLP condivisa; camera/upload reale EXTERNAL_DEPENDENCY, harness Excel sospeso resta skip. |
| CA-09 | NON ESEGUITO integralmente; misure core ESEGUITE | n = 30 draft + n = 1 S100-E/F, dataset/condizioni espliciti; nessuna misura di background/force-stop/convergenza live. |
| CA-10 | ESEGUITO — VERIFIED locale | Full finale 1355 PASS / 0 FAIL / 36 SKIP; mirati 50/0/0, benchmark separati 2/0/0, build/analyze PASS. Primo full failed conservato e isolato PASS. Nessuna esclusione/override app. |
| CA-11 | ESEGUITO review/fix/re-review; NON ESEGUITO PR/CI da executor | Sorgente APPROVED senza P0/P1/P2; coordinatore integra e verifica exact SHA, NOT_MERGED finché non autorizzato. |
| CA-12 | ESEGUITO evidence iOS; NON ESEGUITO report coordinato da executor | Manifest e limiti espliciti; parent integra report complessivo/live/PR. Nessuna dichiarazione DONE. |

## Review

Review indipendente e re-review completate: sorgente APPROVED, nessun P0/P1/P2 aperto dopo R-I01 e la guardia finale. Gate locali finali PASS, prima run interrotta conservata. [Rapporto indipendente](EVIDENCE/TASK-144/independent-review.md). Approvazione tecnica distinta da review GitHub del maintainer e accettazione autenticata.

## Fix

R-I01 (P1): due test rossi hanno riprodotto ricevuta A non consolidata prima di leggere C. Il batch distingue ricevuta e stato corrente, consolida atomicamente A, ribasa B su A prima del conflitto e rende la base disponibile all'editor; retry identico adotta C, delta solo prezzo preserva nome C al reapply. Errore disco conserva l'intent precedente. Guardia finale scope protegge anche readback che termina offline dopo cambio shop. Re-review limitata APPROVED;46 unit + 4 UI finali PASS.

## Handoff

**LOCAL_VERIFIED / SOURCE_APPROVED — non DONE.** Sorgente e documentazione executor congelate dopo gate finale. [Manifest comandi, conteggi e hash](EVIDENCE/TASK-144/ios-gate-manifest.json); [tutti i casi unici](EVIDENCE/TASK-144/full-final-test-cases.json); [skip e motivi](EVIDENCE/TASK-144/full-skips.json).

- Parent integra commit/PR iOS e CI sull'exact SHA; commit compatibilità già separato `4575eefb`. Nessun commit/push dell'executor.
- Primo full fallito per shutdown del simulatore richiesto da precedente runner; prova preservata, nessun difetto applicativo attribuito senza evidenza. Final full senza restart sul fingerprint finale `3d33a15ce689a1aeb7b64082c249ef3a921a1816c520a228f9b475f8ea905d7d`.
- 36 skip: 29 live/esterni, 4 benchmark sintetici opt-in (due richiesti eseguiti separatamente), 2 harness Excel sospeso, 1 camera fisica. Non trasformarli in accettazione live.
- Build TEST con configurazione publishable già autorizzata dal parent è distinta dai gate e dagli artifact Release senza config. Prosegue fuori dai file tracked, con manifest/path/hash separato in `/tmp/mc-task144-ios/`; nessuna installazione su device altrui da questo executor. Sessione/app-auth e verifica bidirezionale sono owner del coordinatore live.
- Nessun XCTest esistente attiva semplicemente l'app installata senza fixture; i veri target UI esistenti usano DEBUG harness. Lo script legacy `tools/sim_ui.sh` non è un probe XCTest ed è deprecato. Nessun nuovo probe introdotto in questo task.
- Restano EXTERNAL_DEPENDENCY il collaudo autenticato Android↔iOS, gli stati background/sospensione/force-stop, permessi/upload reali e giudizio hardware/VoiceOver. Il parent mantiene separati codice, integrazione, runtime locale, live e distribuzione.

### Coordinamento e pubblicazione — parent

Matrice completa: [functional-matrix.md](EVIDENCE/TASK-144/functional-matrix.md). Rapporti comandi, casi, hash e limiti sono versionati; il rapporto aggregato esterno `MERCHANDISECONTROL_MOBILE_PARITY_ROOT_CAUSE_RESULT.md` registra SHA/PR/CI finali senza commit autoreferenziali. Le PR possono essere integrate indipendentemente sul contratto backend esistente; nessun deploy/migrazione prerequisite.

Il consenso diretto dell'utente al coordinamento con «Completa attivazione WECHAT-010» è stato verificato. I suoi dispositivi restano separati: quella lane possiede installazione senza reset, autenticazione e collaudo live; questa lane possiede sorgenti e build native. Nessun test live viene dichiarato PASS prima della relativa ricevuta. Stato attuale NOT_MERGED / NOT_DEPLOYED; nessun DONE finché restano i limiti documentati.
