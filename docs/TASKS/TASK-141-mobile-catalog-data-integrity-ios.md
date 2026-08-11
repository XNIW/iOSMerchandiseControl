# TASK-141 — Mobile catalog data integrity e import truthfulness (iOS)

## Stato

- Stato: `DONE`
- Fase: `DONE / USER_CONFIRMED_CLOSURE`
- Coordination key: `MOBILE-CATALOG-INTEGRITY-001`
- Repository: `XNIW/iOSMerchandiseControl`
- Baseline: `origin/main` `c1b7b706c5f05cd7e8dda74cea1122f6483df7ec`
- Branch: `agent/mobile-catalog-data-integrity-20260809`
- Apertura: `2026-08-09`
- Responsabile attuale: `USER / CONFIRMED CLOSURE`
- Autorizzazione: prompt utente `PRODUCT COMPLETION + MODERN UI/UX OPTIMIZATION`
  del 2026-08-09, che autorizza audit, planning, execution, review e integrazione
  condizionata mantenendo separati i ruoli logici.

## Contesto governance

Il closeout TASK-140 del 2026-07-27 è la fonte cronologicamente canonica e ha
portato il progetto a `IDLE`. I riferimenti a TASK-131 (2026-05-29) e TASK-139
(2026-07-25) rimasti in sezioni successive del Master Plan sono snapshot stale:
vengono riallineati senza riaprire, chiudere o dichiarare `DONE` TASK-131.

## Obiettivo

Impedire che un input prezzo/quantità non vuoto ma invalido venga interpretato
come cancellazione durante il salvataggio prodotto e rendere veritiera la copy
della policy barcode duplicati nell'import supplier.

## Scope

- parser input CL centralizzato con outcome `empty/value/invalid/negative`;
- validazione lossless di purchase, retail e stock prima di qualsiasi mutazione;
- errori per campo localizzati, annunciabili e coerenti con SwiftUI;
- supporto input CL raggruppato/decimale senza confondere empty e invalid;
- copy duplicate barcode coerente con `last row wins`, senza somma quantità, in
  EN/IT/ES/ZH-Hans;
- unit test parser/validation e contract/localization guard.

## Non incluso

- cambi a Client, TASK-032/TASK-033, security review o release PR;
- modifiche sync, image ownership/security, SwiftData schema, Supabase,
  produzione o deployment;
- delete/export feedback, import multi-file feedback, redesign o refactor ampi.

## Criteri di accettazione

| ID | Criterio |
|---|---|
| I-141-01 | Blank resta clear opzionale; ogni input numerico non blank invalido o negativo blocca save prima della mutazione. |
| I-141-02 | Il parser centrale accetta input Chile supportati, incluso grouping/decimal separator coerente, e rifiuta testo/malformed/non-finite. |
| I-141-03 | Ogni campo invalido mostra un errore localizzato e annunciabile; correggere il testo rimuove l'errore senza perdere input. |
| I-141-04 | La preview import comunica in quattro lingue che l'ultima riga viene usata e la quantità non viene sommata; comportamento e copy sono vincolati da test. |
| I-141-05 | Nessuna nuova dipendenza/API/schema e nessun cambiamento a sync/product-image ownership. |
| I-141-06 | Focused/full XCTest, build Debug/Release applicabile, Analyze, localizzazioni e visual QA Simulator hanno evidence reale o limite motivato. |
| I-141-07 | Target Client TASK-033 e release train restano intatti. |

## Decisioni

| # | Decisione | Motivazione |
|---|---|---|
| 1 | Parser input nel modulo di formattazione CL esistente. | Evita un formatter parallelo e mantiene la policy Chile centrale. |
| 2 | Outcome tipizzato, non un secondo `Double?`. | `nil` non può rappresentare sia clear intenzionale sia errore. |
| 3 | Validazione prima di `ProductImportCore.validatedDraft`. | Il core testuale non può recuperare l'informazione persa dopo parse `nil`. |
| 4 | Feedback per campo dentro le section esistenti. | UX SwiftUI idiomatica e compatibile con VoiceOver/Dynamic Type. |
| 5 | Nessuna espansione agli altri errori azione in questo batch. | Mantiene il batch P1 testabile e indipendente da sync/release train. |

## Planning

1. Estendere `PriceFormatting.swift` con parser/outcome puro e test.
2. Validare i tre campi in `EditProductView` e mostrare errori localizzati.
3. Correggere le quattro localizzazioni duplicate-policy e aggiungere guard test.
4. Eseguire gate XCTest/build/analyze/localization e QA Simulator sugli stati
   normal/invalid/corrected/import warning.
5. Consegnare a review indipendente; non marcare `DONE` senza conferma utente.

### Handoff → Execution

- Handoff: `CODEX_PLAN_READY_AWAITING_USER_AUTHORIZATION` soddisfatto dal prompt
  esplicito del 2026-08-09.
- Prossima fase: `EXECUTION`.
- Azione: implementare soltanto I-141-01…I-141-07.

## Execution

In corso.

## Review

### Review indipendente — 2026-08-09

- Esito: `CHANGES_REQUIRED`.
- Baseline revisionata: `c1b7b706c5f05cd7e8dda74cea1122f6483df7ec`
  più la diff locale TASK-141 sul branch
  `agent/mobile-catalog-data-integrity-20260809`.
- Evidence: `docs/TASKS/EVIDENCE/TASK-141/review-01-changes-required.md`.
- Finding P1: il parser condiviso considera `1,234` un intero raggruppato prima
  di considerarlo un decimale valido. Per una quantità in locale `es_CL`, dove
  `,` è il separatore decimale, una quantità `1,234` viene quindi persistita
  come `1234`, con errore di fattore 1000.
- Finding P1: la normalizzazione elimina qualsiasi whitespace interno; input
  malformed quali `1 2`, `1\n2` e `1\t2` diventano valori validi concatenati.
- Finding P2: i test aggiunti non coprono i boundary ambigui a tre cifre, il
  whitespace malformed, l'assenza di mutazione su prodotto esistente/nuovo né
  la persistenza del valore corretto dopo recovery.
- Finding P2 storico: lo snapshot sottoposto a review conservava `Execution`
  ed evidence come placeholder e un handoff stale nel Master Plan; la review è
  stata comunque eseguita su richiesta esplicita del coordinatore. Il presente
  aggiornamento registra il verdict e la transizione valida `REVIEW -> FIX`.
- Gate indipendenti: focused XCTest `PASS` (4/4), XCUITest mirato `PASS` (1/1),
  build Release `PASS`, Analyze `PASS` con note e senza warning nei file
  toccati, localizzazioni `PASS` (1705 chiavi per lingua), `git diff --check`
  `PASS`.
- Limiti: full XCTest `NOT_RUN` dopo i finding P1; device fisico, VoiceOver e
  fotocamera reali `NOT_RUN`. Nessun Deep Security Scan o scan sostitutivo è
  stato avviato.
- Prossima fase: `FIX`, limitata ai finding sopra e ai relativi test di
  regressione.

### Re-review indipendente — 2026-08-09

- Esito: `CHANGES_REQUIRED`.
- Finding `R2-I141-01` (`P1`): il pattern `groupedInteger` consente di alternare
  `.` e `,` tra gruppi. Poiché il ramo price valuta quel pattern prima dei rami
  decimal, `1.234,567` e `1,234.567` diventano `1234567` invece di `1234.567`.
- Correzione richiesta: accettare un grouped integer soltanto quando tutti i
  gruppi usano lo stesso separatore e aggiungere regressioni price per entrambe
  le forme mixed grouped-decimal.
- Precisione evidence: i `17/17` del fixer sono la suite combinata parser +
  localizzazione; il reviewer ha rieseguito autonomamente `7/7` focused. I due
  conteggi devono restare distinti, non presentati come lo stesso gate.
- Gate reviewer: focused unit/localization `PASS` 7/7, XCUITest
  no-insert/persistence `PASS` 1/1, Release seam/hygiene verificati; il P1 rende
  comunque obbligatorio un nuovo `FIX`.
- Evidence: `docs/TASKS/EVIDENCE/TASK-141/review-02-changes-required.md`.

### Re-review indipendente finale — 2026-08-09

- Esito: `APPROVED`.
- `R2-I141-01` verificato risolto: un grouped integer usa un solo separatore
  coerente; price `1.234,567` e `1,234.567` producono `1234.567`, mentre
  `1.234.567` e `1,234,567` producono `1234567`.
- Policy quantità verificata invariata: `1,234`, `12,345` e `999,999` restano
  decimali Chile; whitespace interno e input malformed falliscono chiusi.
- Seam reset verificato esclusivamente dentro `#if DEBUG`; la configurazione
  Release non definisce `DEBUG`. Nessuna modifica a schema, sync, immagini,
  dipendenze o API pubbliche.
- Gate autonomo finale: `Task141NumericInputTests` `PASS`, 6/6, 0 failure/skip;
  `git diff --check` `PASS`; localizzazioni `plutil` 4/4 e 1705 chiavi per
  lingua.
- Evidence post-fix ispezionata: targeted combinato fixer 17/17; precedente
  rerun reviewer 7/7 distinto; full finale 1323 totali = 1288 pass + 35 skip,
  0 failure; XCUITest finale persistence/no-insert 1/1. Analyze e Release
  risultano `PASS` negli artifact post-fix.
- Rettifica non bloccante di precisione: il log Analyze finale contiene 27
  righe warning fuori dai file TASK-141 (18 nel vendorizzato `libxls`, 6 in
  test legacy non modificati, 3 metadata), non soltanto due; nessun warning è
  riferito ai file toccati dal task.
- Limiti invariati e non bloccanti per lo scope: device fisico, VoiceOver e
  camera reale `NOT_RUN`. Nessun security scan è stato avviato.
- Evidence: `docs/TASKS/EVIDENCE/TASK-141/review-03-approved.md`.

## Fix

### Fix finding review — 2026-08-09

| Finding | Correzione | Regressione finale |
|---|---|---|
| Quantità `1,234` interpretata come `1234` | Il parser centrale distingue policy `.price` e `.quantity`: per quantità Chile la virgola singola a tre cifre resta decimale, mentre i prezzi preservano il grouping CL supportato. | Boundary `1,234`, `12,345`, `999,999`, mixed grouping/decimal e prezzi raggruppati coperti da XCTest. |
| Whitespace interno concatenato | Qualsiasi whitespace interno, inclusi spazio, newline e tab, fallisce chiuso; resta ammesso soltanto il trimming ai bordi. | XCTest su `1 2`, `1\n2`, `1\t2` e whitespace esterno. |
| Assenza di prova mutation/persistence | Aggiunto un seam esclusivamente `DEBUG` per azzerare il dominio `UserDefaults` del solo harness UI-test; nessun comportamento Release cambia. | XCUITest reale: save invalido non inserisce; dopo correzione quantità `1,234` e prezzo `1.234,5` persistono e si rileggono come `1.234` e `1234.5`. |
| Evidence/tracking incompleti | Fix e gate reali sono registrati nella presente sezione e nell'evidence pack; il precedente placeholder Execution resta storico e non viene riscritto dal fixer. | Audit documentale e `git diff --check`. |

**Gate post-fix:**

- parser/localizzazione mirati: `PASS`, 17/17, 0 failure/skip;
- XCUITest persistence/no-insert: `PASS`, 1/1 nel tentativo finale;
- full XCTest/XCUITest su iPhone 17 Pro Simulator iOS 26.5: `PASS`, 1323
  totali, 1288 pass, 35 skip, 0 failure;
- Analyze Debug: `PASS`, exit `0`; due analyzer issue nel vendorizzato `libxls`,
  nessuno nei file TASK-141;
- build Release Simulator: `PASS`, exit `0`; warning debug-symbol PCM mancanti
  non bloccanti e non riferiti al codice modificato;
- localizzazioni: `PASS`, `plutil` 4/4 e 1705 chiavi per lingua;
- visual QA Simulator: `PASS` sullo stato quantity negative + purchase malformed;
- device fisico, VoiceOver e camera reale: `NOT_RUN`.

I primi quattro tentativi del nuovo XCUITest hanno restituito `FAIL` per locator
stale e stato harness persistente; le correzioni sono rimaste test-only/`DEBUG` e
il quinto tentativo è `PASS`. Nessun risultato fallito viene occultato.

Nessun Client, release PR, Supabase, produzione, secret o security scan è stato
toccato.

### Fix R2-I141-01 — 2026-08-09

- `groupedInteger` usa ora due pattern espliciti: tutti gruppi `.` oppure tutti
  gruppi `,`; non può più classificare come intero una forma con separatori
  alternati.
- Regressioni price aggiunte per `1.234,567` e `1,234.567` → `1234.567`, oltre
  ai grouped integer coerenti `1.234.567` e `1,234,567` → `1234567`.
- Targeted parser + localizzazione post-fix: `PASS`, 17/17; il rerun autonomo
  reviewer precedente resta separato come 7/7.
- Full XCTest/XCUITest post-fix: `PASS`, 1323 totali, 1288 pass, 35 skip,
  0 failure, iPhone 17 Pro Simulator iOS 26.5.
- Analyze Debug: `PASS`, exit `0`, con due analyzer issue preesistenti soltanto
  nel vendorizzato `libxls`; build Release: `PASS`, exit `0`, con warning
  debug-symbol PCM non bloccanti; localizzazioni 4/4 e `git diff --check`:
  `PASS`.

## Handoff

`USER_CONFIRMED_CLOSURE`.

## Chiusura — 2026-08-11

- conferma esplicita `USER_APPROVER` ricevuta per il closeout multi-repository;
- PR #4 `Protect iOS catalog data integrity` merged normalmente il 2026-08-09;
- commit task `d3a3442646cfbe6a3f269e209a3b7e88658beb91` antenato di
  `origin/main`; merge commit finale
  `c55e3a93449c4f432bf28f4d7b1f5ac1e5f9b502` con tree identico al commit task;
- CI PR `31331876775` e CI sul merge commit `31332907006`: `PASS`, inclusi
  contract hash, Debug build, full XCTest, Analyze e secret scan;
- working tree post-clone pulito; nessun file Swift, xcscheme, Supabase o production
  modificato durante la chiusura governance.
