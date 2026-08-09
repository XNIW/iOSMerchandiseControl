# TASK-141 — Review indipendente 01

## Identità della review

- Data: `2026-08-09`.
- Ruolo: `CODEX_REVIEWER` indipendente dall'executor.
- Baseline: `c1b7b706c5f05cd7e8dda74cea1122f6483df7ec`.
- Branch revisionato: `agent/mobile-catalog-data-integrity-20260809`.
- Snapshot: diff executor precedente al ciclo `FIX`; i finding sotto restano
  evidenza storica anche se il worktree condiviso evolve durante il fix.
- Verdict: `CHANGES_REQUIRED`.
- Handoff: `CODEX_REVIEW_CHANGES_REQUIRED_TO_FIX`.

## Finding riproducibili

### F-141-R01 — P1 — quantità CL a tre decimali interpretata come intero

- File: `iOSMerchandiseControl/PriceFormatting.swift`, parser
  `ChileanNumberInput.parse`.
- Root cause: il pattern `groupedInteger` precede `simpleDecimal` e il parser è
  condiviso fra prezzo e quantità. In locale `es_CL`, `1,234` rappresenta
  `1.234`, ma il ramo grouping rimuove la virgola e produce `1234`.
- Impatto: una quantità valida può essere salvata con un errore di fattore
  1000; esempi boundary: `1,234`, `12,345`, `999,999`.
- Riproduzione parser: script Swift equivalente alle regex dello snapshot ->
  `grouped=true simple=true normalized=1234 value=1234.0`, exit `0`.
- Controllo locale indipendente con `NumberFormatter(locale: es_CL)` ->
  `decimal=, grouping=. formatted=1,234 parsed=1.234`, exit `0`.
- Fix richiesto: distinguere esplicitamente la policy reale prezzo/quantità o
  fallire chiuso sull'ambiguità; aggiungere test sui boundary a tre cifre.

### F-141-R02 — P1 — whitespace malformed concatenato in un numero

- File: `iOSMerchandiseControl/PriceFormatting.swift`, normalizzazione input.
- Root cause: ogni whitespace interno viene eliminato prima della validazione.
- Riproduzione sullo snapshot: `1 2 -> 12`, `1\n2 -> 12`, `1\t2 -> 12`,
  `1 23 4 -> 1234`, exit `0`.
- Impatto: input non valido può superare la validazione e mutare il prodotto,
  in contrasto con I-141-02.
- Fix richiesto: accettare soltanto grouping esplicitamente valido e rifiutare
  newline, tab e whitespace irregolare interno.

### F-141-R03 — P2 — copertura regressione data-integrity incompleta

- File: `iOSMerchandiseControlTests/Task141NumericInputTests.swift` e
  `iOSMerchandiseControlUITests/CatalogTextImportUITests.swift`.
- Mancano test per quantità con virgola e tre cifre, whitespace malformed,
  garanzia di nessuna mutazione di un prodotto esistente/nessun inserimento di
  un prodotto nuovo e persistenza del valore corretto dopo recovery.
- Fix richiesto: aggiungere regressioni pure e di salvataggio osservabile.

### F-141-R04 — P2 — snapshot executor non review-ready

- Lo snapshot revisionato conservava `Execution`/evidence placeholder e un
  handoff stale nel Master Plan.
- Finding mantenuto come evidenza storica. Il file task e i soli campi
  operativi del Master Plan vengono ora portati a `FIX`; non è un'approvazione
  dell'execution e non altera Planning, Decisioni o criteri.

## Gate indipendenti

Comandi Xcode effettivamente eseguiti:

```sh
xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,id=240F400E-5EFA-486A-9137-FFBBE70F604D' -derivedDataPath /tmp/mc-task141-review-dd CODE_SIGNING_ALLOWED=NO test -only-testing:iOSMerchandiseControlTests/Task141NumericInputTests -only-testing:iOSMerchandiseControlTests/LocalizationCoverageTests/testTask141NumericErrorsAndDuplicatePolicyAreLocalizedAndTruthful
xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,id=240F400E-5EFA-486A-9137-FFBBE70F604D' -derivedDataPath /tmp/mc-task141-review-dd CODE_SIGNING_ALLOWED=NO test -only-testing:iOSMerchandiseControlUITests/CatalogTextImportUITests/testProductEditorBlocksInvalidNumericInputAndRetainsDraftDuringCorrection
xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/mc-task141-review-release CODE_SIGNING_ALLOWED=NO build -quiet
xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/mc-task141-review-analyze CODE_SIGNING_ALLOWED=NO analyze -quiet
```

| Gate | Comando/ambito | Esito |
|---|---|---|
| XCTest mirati | primo comando Xcode sopra | `PASS`, exit `0`, 4/4 |
| XCUITest mirato | secondo comando Xcode sopra | `PASS`, exit `0`, 1/1, 26.079 s |
| Release Simulator | terzo comando Xcode sopra | `PASS`, exit `0` |
| Analyze | quarto comando Xcode sopra | `PASS`, exit `0`; warning solo baseline Vendor/test, zero nei file toccati |
| Localizzazioni | `plutil -lint` EN/IT/ES/ZH-Hans + confronto chiavi | `PASS`, exit `0`; 1705 chiavi per lingua, diff/duplicati 0 |
| Diff hygiene | `git diff --check c1b7b706...` + ispezione artifact/credential-like pattern | `PASS`, exit `0`; nessun artifact o secret rilevato nel perimetro diff |
| Full XCTest | non eseguito dopo i finding P1 e con evidence executor ancora placeholder | `NOT_RUN` |
| Device/VoiceOver/camera reali | ambiente non disponibile | `NOT_RUN` |

Il controllo diff su pattern credential-like è stato soltanto hygiene mirata;
non è un Deep Security Scan né una security scan sostitutiva.

## Visual QA

L'attachment dell'XCUITest mirato è stato ispezionato: editor nuovo prodotto in
inglese, errori per stock negativo e prezzo invalido visibili con icona e testo,
input conservato. Il controllo è limitato al Simulator e non costituisce
evidence di VoiceOver o device fisico.

## Scope e sicurezza

- Client TASK-033 e target congelato: `NOT_MODIFIED`.
- TASK-032/TASK-033, release PR e review integrate: `NOT_TOUCHED`.
- Supabase/production/secrets/deploy: `NOT_MODIFIED`.
- Deep Security Scan/security scan sostitutive: `NOT_RUN`.

## Esito

`CHANGES_REQUIRED`: passaggio a `FIX` per F-141-R01…R03, quindi nuova review
indipendente. Nessun `DONE`, merge o deploy è autorizzato da questo verdict.
