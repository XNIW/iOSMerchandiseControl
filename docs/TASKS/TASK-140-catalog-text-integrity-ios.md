# TASK-140 — Cross-platform catalog text integrity (iOS)

## Stato

- Coordination key: `CATALOG-TEXT-001`
- Repository: `XNIW/iOSMerchandiseControl`
- Stato: `ACTIVE`
- Fase: `REVIEW`
- Responsabile: `CLAUDE/ChatGPT / Planner-Reviewer`
- Apertura: `2026-07-27`
- Baseline: `origin/main`
  `351ccb9dd0e573bd7f450f23efc1d50670ae362f`
- Branch implementazione: `codex/catalog-text-integrity-ios-20260727`
- Branch closeout: `codex/catalog-text-integrity-closeout-ios-20260727`
- Evidence: `docs/TASKS/EVIDENCE/TASK-140/README.md`
- Ambiente autorizzato: fixture locali, XCTest e iOS Simulator; staging pubblico
  soltanto nell'eventuale fase coordinata e con autorizzazione/gate espliciti.
- Production: `NOT_MODIFIED`
- Win7POS: `NOT_MODIFIED`
- PR Admin:
  [XNIW/merchandise-control-admin-web#42](https://github.com/XNIW/merchandise-control-admin-web/pull/42)
- PR Android:
  [XNIW/MerchandiseControlSplitView#3](https://github.com/XNIW/MerchandiseControlSplitView/pull/3)
- PR iOS:
  [XNIW/iOSMerchandiseControl#1](https://github.com/XNIW/iOSMerchandiseControl/pull/1)

I finding `CHANGES_REQUIRED` sono stati corretti e i gate locali sono stati
rieseguiti. La rereview tecnica finale è `APPROVED` con P0/P1/P2/P3
`0/0/0/0`; PR, CI, merge normale e acceptance staging coordinata sono
completati. Codex non marca il task `DONE`; resta necessaria la conferma
esplicita dell'utente.

## Obiettivo

Consumare il contratto condiviso `catalog_text_policy_v1` e applicarlo a tutti
i boundary catalogo iOS rilevanti prima della persistenza, del fingerprint
dirty/outbox e dei payload sync. Il valore visibile in Import Analysis deve
coincidere con quello applicato. Input proibiti devono fallire in modo
tipizzato e localizzato senza scritture parziali, loop pull→push o
`ProductPrice`/`PriceHistory` generati da modifiche soltanto testuali.

## Scope iOS

- helper Swift puro e centrale `CatalogTextPolicy`;
- fixture golden condivisa byte-per-byte e digest SHA-256 verificato;
- manual create/edit di product, supplier e category;
- `ExcelSessionViewModel`, analyzer, `ProductImportCore`,
  `ImportAnalysisView` preview/edit/apply;
- import Excel/CSV, full database e restore/recovery preflight;
- boundary finali SwiftData del catalogo;
- pending/dirty preflight prima di logical key, fingerprint e payload;
- outbound catalog sync e inbound incremental/recovery senza local-pending loop;
- export del valore persisted canonico e error export privacy-safe;
- localizzazioni EN/IT/ES/ZH-Hans;
- unit, integration e Simulator evidence, inclusa regressione resource-bounded.

Fuori scope: note/free-form multilinea, redesign UI, nuove dipendenze,
refactor generale dei repository, cambi RLS/migration Supabase, produzione,
Win7POS, deploy/TestFlight, commit, stage, push o merge.

## Contratto consumato

### Display text

Campi: `productName`, `secondProductName`, `Supplier.name`,
`ProductCategory.name` e label catalogo umane già presenti negli stessi flussi.

- NFC, mai NFKC;
- CRLF/CR/LF/TAB e Unicode `Zs` diventano U+0020;
- spazi U+0020 collassati e trim;
- lunghezza misurata con `utf16.count` dopo canonicalizzazione;
- preservare cinese, accenti, simboli, emoji e sequenze ZWJ valide;
- rifiutare C0/C1 residui, U+200B, U+2060, U+FEFF, bidi
  U+202A...U+202E/U+2066...U+2069, input byte non UTF-8, over-limit e required
  vuoto;
- esiti tipizzati `unchanged`, `normalized`, `rejected(reason)`;
- idempotenza obbligatoria.

### Strict identity/code text

Campi: barcode, item/article number e altri codici/ID quando attraversano i
boundary catalogo.

- mantenere esclusivamente il trim già approvato;
- non convertire control/newline/tab in spazi e non alterare per far passare;
- rifiutare line separator, control, zero-width, BOM e bidi;
- bloccare collisioni d'identità create dal trim; non fondere identità.

## Acceptance ledger

| ID | Criterio | Stato |
|---|---|---|
| I-140-01 | Fixture identica al golden Admin, digest `139d63eedea47b54bb63a9289bef5fc6f7372668f209aac7753b586da7ccd9f8`. | `PASS` |
| I-140-02 | Policy pura NFC/UTF-16/display/strict/byte decode con outcome tipizzati e fixture tests. | `PASS` |
| I-140-03 | Manual product/supplier/category persiste canonico o blocca con errore localizzato. | `PASS` |
| I-140-04 | Import Excel/CSV/full/restore e Import Analysis mostrano canonicalizzato, warning/count e applicano esattamente la preview. | `PASS` |
| I-140-05 | Errori proibiti/over-limit/invalid UTF-8 bloccano senza apply parziale silenzioso; error export non espone invisibili raw. | `PASS` |
| I-140-06 | Canonico prima di SwiftData fingerprint/outbox/payload; dirty esistente riparato bounded senza outbox duplicato. | `PASS` |
| I-140-07 | Inbound incremental/recovery canonicalizza display, rifiuta strict invalido e non crea local pending/loop. | `PASS` |
| I-140-08 | Nessun PriceHistory per text-only; fallback nome esistente e resource bounds preservati. | `PASS` |
| I-140-09 | EN/IT/ES/ZH-Hans e focused/integration/Simulator checks hanno evidence reale. | `PASS` — target XCUITest reale e 2/2 test Simulator verdi per Import Analysis e Database/file importer. |
| I-140-10 | Build, sync regression, analyze/full XCTest/smoke hanno risultato reale o stato `NOT_RUN`/`BLOCKED` motivato. | `PASS_WITH_NOTES` — gate locali verdi; staging cross-platform `PASS`; restano soltanto 6 warning Swift 6 storici nel target test. |
| I-140-11 | Production e Win7POS restano `NOT_MODIFIED`; nessun secret o dato reale nel repository/evidence. | `PASS` |

## Piano di execution

1. Congelare fixture/digest e implementare la policy pura con test golden.
2. Integrare i boundary locali/import e la UX Import Analysis.
3. Integrare pending/outbound e inbound/recovery mantenendo le semantiche sync.
4. Aggiungere localizzazioni, test di integrazione e Simulator.
5. Eseguire i gate disponibili e consegnare a `REVIEW` con evidence, rischi
   residui e nessun claim non verificato.

## Vincoli di sicurezza

- Nessun secret, token, password, URL firmato o dato cliente in codice/log.
- Nessuna chiave service role nel client e nessun write production.
- Staging solo con account/shop QA e ID esatti registrati prima di eventuali
  scritture; cleanup esclusivamente per ID esatti.
- Nessun `PASS` dedotto: ogni risultato deriva da un comando eseguito.
- Il commit baseline di resource hardening e i limiti import restano invariati.

## Handoff a REVIEW

### Risultato

- policy Swift centrale integrata nei boundary manuali, import/preview/apply,
  SwiftData, pending/outbound, inbound incremental/recovery ed export;
- fixture condivisa identica byte-per-byte e test golden;
- riparazione bounded delle sole entità già pending, con preflight atomico e
  conservazione dello stesso record outbox/idempotency key;
- campi prodotto outbound validati senza trasformare relazioni remote-clean in
  modifiche locali;
- localizzazioni EN/IT/ES/ZH-Hans completate;
- regressioni mirate e suite completa Simulator verdi, con risultati dettagliati
  in `docs/TASKS/EVIDENCE/TASK-140/README.md`.
- espansione barcode scientifica bounded prima di qualsiasi allocazione
  proporzionale all'esponente, output massimo 96 UTF-16 e strict revalidation;
- pending repair filtrato owner/store nel fetch, paginato a 256 e risolto
  tramite indici dei soli target trovati, con regressione a scala catalogo;
- full export fail-closed su ogni product, supplier e category, inclusi record
  non referenziati;
- target `iOSMerchandiseControlUITests` reale nello scheme condiviso, con test
  Import Analysis e Database/file importer senza attese temporali arbitrarie.

### Closeout cross-platform

- Override utente esplicito applicato esclusivamente per registrare il
  closeout esterno mentre il task è già in `REVIEW`; nessuna nuova modifica
  runtime iOS in questa fase.
- PR iOS [#1](https://github.com/XNIW/iOSMerchandiseControl/pull/1), CI verde e
  merge normale a due parent
  `712689dd917125c9c656b8cc48e7c392c87174fd`; PR Admin #42 e Android #3
  collegati e integrati normalmente.
- Review finali dei tre repository: P0/P1/P2/P3 `0/0/0/0`.
- Acceptance pubblica sul solo shop QA: iOS ha letto il prodotto e quattro
  prezzi scritti da Android; ha poi scritto tramite i servizi Release un
  prodotto con quattro prezzi, letti canonicali da Android e Admin nello
  stesso owner/shop scope.
- Migration e repair staging completati soltanto su
  `merchandisecontrol-dev`: `345` prodotti, invalidi post-repair `0`,
  invarianti preservati. Paging Win7POS-equivalente read-only e cleanup esatto
  a residuo `0`.
- File temporanei di sessione, derived data e build log iOS eliminati; la
  rimozione e il cleanup fixture non sono recuperabili.

### Rischi residui

- Analyze finale: 0 errori, 0 analyzer warning e 6 warning Swift 6 preesistenti
  nel target test; 0 warning nei file toccati da TASK-140.
- Production e Win7POS: `NOT_MODIFIED`; nessun deploy/TestFlight.
- P0/P1/P2/P3 aperti: `0/0/0/0`.

### Prossima fase

`REVIEW / READY_FOR_USER_CONFIRMATION`. Il passaggio a `DONE` resta
esclusivamente subordinato alla conferma esplicita dell'utente.
