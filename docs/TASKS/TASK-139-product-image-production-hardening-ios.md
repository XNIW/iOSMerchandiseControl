# TASK-139 — Product Image Production Hardening e Cross-Platform Contract Parity (iOS)

## Stato

- Stato: `REVIEW_WITH_IOS_V6_PREBOUND_RUNTIME_VERIFIED_ISOLATED`
- Fase: `REVIEW`
- Responsabile: `Claude/ChatGPT / Reviewer`
- Apertura: `2026-07-18`, brief esplicito utente cross-platform.
- Ultima FIX: `2026-07-23`, publication atomica, contratto V6 e runtime
  pre-bound resource verificati sul candidato isolato.
- Chiusura: mai `DONE` senza conferma esplicita dell'utente.
- Baseline: `origin/main` `66d90983f8e9ab08dd72184abb4ec70d2c4daefb`.

## Scope lane iOS

La riapertura `FIX` autorizzata dall'utente ha corretto le lacune confermate
dalla review esclusivamente sul candidato e su fixture/Simulator isolati. Non è
stato eseguito un secondo replace, né installazione, clear-data o mutazione sul
database autenticato reale.

- Consumo del contratto, fixture e vector JSON condivisi con Admin e Android.
- Ladder lato/quality e fallback camera bounded, senza dipendenze nuove.
- HEIC, 48 MP sintetico, cache/session isolation e UI Simulator.
- Dialog nativa iOS e Android con due sole azioni e semantica fail-closed.
- Hardening owner/shop, replacement journal, recovery e incremental tail.
- CI build/test/contract/analyze/sensitive scan, senza deploy/TestFlight.

Android non è più `review-only` esclusivamente per la patch UX minima
autorizzata dall'addendum; policy, coordinator e transazioni esistenti non sono
stati duplicati.

## Vincoli rispettati

Nessuna nuova state machine, sync policy duplicata, dipendenza, redesign,
riscrittura repository/Room, produzione, Win7POS, TASK-088, commit, stage, push,
merge o deploy. Il database reale autenticato non è stato reinstallato,
azzerato o sostituito una seconda volta.

## Acceptance criteria

| ID | Criterio | Stato evidence |
|---|---|---|
| I-01 | Contratto/fixture iOS identici byte-per-byte al canonico Admin e Android. | Verificato isolato: hash e byte parity verdi. |
| I-02 | XCTest Swift consumano i vector comuni e congelano ladder/quality/budget. | Verificato nella matrice integrata. |
| I-03 | Fallback camera ridimensiona/ricodifica bounded senza JPEG full-res quality 1. | Verificato sintetico; camera fisica resta opt-in non eseguita. |
| I-04 | CI esegue i gate richiesti e non contiene deploy/TestFlight/secret. | Workflow YAML valido; le otto classi Product Images erano già presenti e sono state riconfermate. |
| I-05 | XCTest/UI Simulator/build/analyze e device fisico hanno risultato reale o blocker preciso. | Simulator/build/analyze verificati; device/camera opt-in non eseguiti. |
| I-06 | Nessun URL/path/blob immagini entra nel dominio/sync; production e Git remoti intatti. | Verificato da test/scanner; nessuna mutazione esterna. |

## Correzioni della FIX post-replace

- RPC `sync_event` exactly-one: oggetto o array con una riga sono accettati;
  risposta vuota o multi-riga fallisce senza ignorare righe extra.
- Outbox: `automatic_scope_mismatch` diventa `blockedAuth`, è non retryable,
  abortisce il batch dopo la prima RPC e non modifica l'entry successiva; errori
  owner/shop e lease stale restano fail-closed con rollback.
- Test di interleaving lease deterministico, eseguito singolarmente e per cinque
  ripetizioni.
- Recovery snapshot: duplicate lookup name e product conflict sono rilevati
  prima di catalog/history/price/baseline; nessuna mutazione downstream.
- Nel percorso replacement, ricerca del watermark W0 bounded a massimo
  `512 x 200`; tail massimo `50 x 200` (`10.000` eventi). L'esaurimento
  fallisce mantenendo journal e stato di recovery.
- `recoveryRequired` è una fase durevole. Gap, reconnect e `Check again`
  ordinari non promuovono automaticamente a full snapshot; solo il Retry CTA
  esplicito con source `releaseCard` può richiedere recovery. Il push dei
  pending precede drain/recovery e non autorizza snapshot impliciti.
- Il replacement journal mantiene bootstrap automatico bounded a massimo due
  snapshot, quindi tail e reconcile; viene rimosso soltanto dopo la conclusione
  verificata.
- `recoveryRequired` persiste su cancel, failure, block, busy, no-op e relaunch;
  si libera solo dopo successo verificato. Il replacement rimuove il latch solo
  nel proprio percorso journal/bootstrap. La race Cancel→Retry immediato viene
  accodata e drenata dopo la chiusura cooperativa del run cancellato.
- I default di dependency injection ora derivano dallo stesso scope iniettato.

## Evidence reale finale iOS

| Gate | Risultato |
|---|---|
| Matrice integrata unica, 28 classi | `386` totali: `383` pass, `3` skip opt-in, `0` failure |
| Recovery/cancel finale | `94/94` |
| Focus engine precedente all'estensione cancel | `90/90` |
| RPC | `29/29` |
| Outbox | `32/32` |
| Recovery preflight + W0 budget | `3/3` |
| Lease interleaving | singolo + repeat-5 verdi |
| Contratto migration V6 post-audit | `41/41` mirati, `0` failure |
| Full XCTest esatto post-audit | `1.261` eseguiti: `1.226` pass, `0` failure, `35` skip |
| Debug build | `PASS` |
| Analyze | exit `0`; `18` warning solo in `Vendor 2/libxls` (`17` `xls.c`, `1` `ole.c`) |
| Contract | hash e byte parity Admin/Android `PASS` |
| Localizzazioni | `4` file `Localizable.strings`, `plutil` `PASS` |
| Workflow CI | YAML `PASS`; tutte le `8` classi Product Images presenti |
| Scan locale redatto | nessun literal `service_role`, `sb_secret` o JWT; URL firmati solo runtime bounded |
| Codex Security diff scan formale | `NOT_RUN`, workspace non avviato dall'interfaccia |
| Git hygiene | `git diff --check` `PASS`; staged vuoto |

Xcresult integrato: artifact esterno temporaneo del run, non versionato.

Artifact recovery/cancel: xcresult esterno del run, non versionato.

I gate mirati si sovrappongono alla matrice integrata e non vanno sommati. Il
legacy scanner TASK-117 `no-full-pull` ha prodotto `4/5` perché pretende il
blocco assoluto di bootstrap/fullRecovery: è `NOT_APPLICABLE / legacy guard`,
superseduto dalla policy source/context e dai test dinamici; non viene dichiarato
`PASS`.

## Checkpoint reale e limite di convergenza

L'utente aveva toccato realmente `Sostituisci con dati cloud` sulla build già
installata. Account, shop, login e device identity sono rimasti preservati. I
conteggi locali reconciliation-aware post-replace (`19.734/85/54/10.799/77`)
e i conteggi raw osservati sullo staging (`19.746/83/55/41.158`) non sono
confrontabili uno-a-uno e quindi, da soli, non provano né drift né convergenza.
Il finding runtime certo era invece Diagnostics
`policyBlocked / sync_event_missing_entity_ids` con orchestrator
`idle/noWork`.

La causa è un evento legacy incompleto; la policy lo ha bloccato correttamente.
Il motivo per cui il recovery non poteva chiudere in modo verificato nel
candidato precedente era separato: digest newline anziché catena V6 UTF-8,
identity prodotto incompleta, prezzo da `Double` e digest history non consumati.
Questi quattro mismatch sono corretti e coperti dal run finale esatto.

La FIX è verificata soltanto sul candidato isolato. Non è stato eseguito un
secondo replace/install/clear-data/live mutation e la convergenza del database
reale non è stata riprovata.

## Stato coordinato

- Android: mirati `182/182`, immagini P1 `69/69`, JVM `697` totali
  (`692` pass + `5` skip), device `4/4` da sintesi del run (report raw non
  conservato), lint `0` errori / `22` warning, `assembleDebug`,
  `assembleDebugAndroidTest` e diff check verdi. Nessun replace autenticato
  reale; atomicità/rollback verificati su fixture Room isolata.
- Admin TASK-139: `42/42`; Admin TASK-140: `21/21`.
- Win7POS/security globale: `BLOCKED_EXTERNAL` per input esterno mancante; non è
  un PASS globale.

## Stato V6 e handoff

Il precedente `P1` di atomicità fisica è superseduto sul candidato iOS: il
recovery prepara una generation separata, controlla mutation fence e receipt,
poi pubblica il solo manifest dopo fsync e rename atomico. La prova SIGKILL
pre/post rename e relaunch isolato è verde (`2/2`); non resta uno stato
cross-domain parziale visibile all'utente durante la preparazione.

Osservazione P2: nella full suite è apparsa una diagnostica SwiftData
`DefaultStore` nel test ProductImage di scroll; il test/suite sono passati e
il warning non si era riprodotto nelle riesecuzioni isolate. Va riprodotto
prima di trattarlo come difetto runtime.

Resta il blocker di accettazione cross-platform: non è stato eseguito sullo
shop non-production autorizzato il singolo replace E2E con confronto forte
cloud/local, immagini, outbox e tre relaunch. Questo non è un PASS globale né
un `DONE`.

Evidence autorevole:
`docs/TASKS/EVIDENCE/TASK-139/15-v6-atomic-recovery-contract-ios.md`.
Il task resta in `REVIEW`, responsabile reviewer; mai `DONE` o PASS globale
senza conferma esplicita dell'utente.

## Continuation principale 2026-07-23 — runtime pre-bound resource

User override: la continuation cross-platform ha autorizzato la FIX mirata
anche se la lane era già in `REVIEW`. L'impatto sul workflow è limitato a
codice/harness/test/evidence locali; l'handoff torna a `REVIEW`, non `DONE`.

La prova XCTest usa `ProductImageService`, `ProductImageStore`,
`ProductImageCache` e il gate owner/store reali. Sono state avviate `64`
richieste A/G1 con completion di rete non cooperative; dopo la transizione
B/G2 tutte le completion sono arrivate, ma nessuna ha pubblicato in memoria o
su disco. Sullo scope B, `100` consumer concorrenti della stessa reference
hanno condiviso una sola read batch e un solo GET, con una sola entry cache e
pubblicazione UI esclusivamente B.

La prova app-process DEBUG usa un Application Support e UserDefaults isolati,
senza auth o rete. `prepare` ha persistito cache/watermark/fence/pending marker
A; dopo terminate e nuovo launch, `verify` ha osservato un PID diverso,
`bindingMismatch` per B, Product Image B negata, A ancora leggibile,
watermark `A=41/B=0`, fence B assente e zero marker di publication stale.
Risultato `2/2`, `networkCalls=0`,
`authenticatedSimulatorTouched=false`. Il crash harness atomico pre/post
manifest è stato rieseguito sul sorgente finale: `2/2`.

Gate finali esatti:

- test mirato 64+100: `1/1`, `0` failure;
- full XCTest: `1.262` totali, `1.227` pass, `35` skip espliciti,
  `0` failure e `0` expected failure;
- Debug build: exit `0`;
- analyze: exit `0`;
- `plutil -lint` su Info/config: `2/2`;
- `git diff --check`: `PASS`.

Xcresult full ed evidence strutturata: artifact esterni del closeout,
intenzionalmente non versionati.

Failure intermedie conservate e non promosse a PASS: primo cold boot effimero
fallito in `launchd_sim` e riuscito con un solo retry; prima compilazione del
test fallita per `await` dentro autoclosure XCTest; fixture iniziale non
supportava `httpBodyStream`, generava un URL firmato non canonico e non
tratteneva davvero la callback non cooperativa; Xcode ha inoltre ripetuto
l'errore infrastrutturale generico post-signing prima di un
`build-for-testing` finale realmente verde. Tutti questi punti sono stati
corretti o classificati con log reali.

Il runtime proof iOS richiesto da `sec-mobile-prebound-resource-003` è presente.
Questo non chiude da solo la security review globale, l'E2E cross-platform o
Win7POS. Nessun commit, stage, push, merge o deploy è stato eseguito in questa
continuation.
