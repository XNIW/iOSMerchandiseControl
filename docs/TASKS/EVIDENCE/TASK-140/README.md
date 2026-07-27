# TASK-140 iOS Evidence — CATALOG-TEXT-001

## Verdict execution iOS

`INDEPENDENT_REVIEW_APPROVED_PRE_PR`

L'implementazione e i gate locali iOS sono completi. Il task resta `ACTIVE /
REVIEW`, non `DONE`. Staging cross-platform non è dichiarato eseguito.

## Baseline e sicurezza

- repository: `XNIW/iOSMerchandiseControl`;
- baseline: `351ccb9dd0e573bd7f450f23efc1d50670ae362f`;
- branch: `codex/catalog-text-integrity-ios-20260727`;
- HEAD preesistente al fix round:
  `95f015196907309ec0bdac2472c5f6b18fe40432`;
- fix round revisionato:
  `7d8f0de19a4630d3b7ab925df09b18285f320c3e`;
- worktree isolato:
  `/Users/minxiang/.codex/worktrees/catalog-text-integrity-20260727/ios`;
- fixture e test usano esclusivamente dati sintetici `TASK140_*`;
- production: `NOT_MODIFIED`;
- Win7POS: `NOT_MODIFIED`;
- staging: `NOT_RUN`;
- commit fix round: `7d8f0de19a4630d3b7ab925df09b18285f320c3e`;
- push/PR/deploy nel fix round: `NOT_RUN_PRE_PR`.

## Flusso coperto

| Boundary | Implementazione/evidence |
|---|---|
| Manual create/edit | Policy applicata a product, supplier e category prima del save e del pending fingerprint; collisione barcode valutata dopo canonicalizzazione strict anche contro record legacy. |
| Excel/CSV | Parser CSV quote-aware e CRLF-safe; analyzer/import canonicalizzano prima della preview, producono warning aggregati e bloccano righe invalide senza esporre caratteri invisibili raw. |
| Import Analysis/apply | Draft mostrato e draft applicato condividono la policy; il boundary finale SwiftData rivalida prima di qualsiasi mutazione. |
| Full database/export | Preflight canonico prima dell'export; gli errori usano campo/reason tipizzati e privacy-safe. |
| Pending/dirty | Fetch owner/store/status filtrato nel datastore e paginato a 256; solo kind/protocol/schema/epoch ammessi consumano il limite. Le scansioni catalogo sono page-bounded, attivate solo per i kind richiesti e indicizzano esclusivamente i target trovati. Preflight atomico, stesso outbox e stessa idempotency key; le entità remote-clean non diventano local change. |
| Outbound | Payload product/supplier/category accettati solo se i campi effettivamente inviati sono canonici; logical key e fingerprint derivano dal valore persistito canonico. |
| Inbound/recovery | Display canonicalizzato, strict invalido rifiutato; nessun `LocalPendingChange` generato dal pull. |
| Price history | Update soltanto testuale non crea `ProductPrice`; semantica prezzi e fallback nome preservati. |
| Localizzazione | Nuove reason/warning in EN, IT, ES e ZH-Hans. |

## Evidence ledger

| Gate | Stato | Evidence reale |
|---|---|---|
| Governance e baseline | `PASS` | Worktree creato dall'esatta SHA richiesta; checkout principale non modificato. |
| Fixture golden | `PASS` | `cmp -s` Admin/iOS; 417 righe, 10.929 byte; SHA-256 su entrambe `139d63eedea47b54bb63a9289bef5fc6f7372668f209aac7753b586da7ccd9f8`. |
| JSON fixture | `PASS` | `jq empty` sul golden iOS. |
| Finding regression | `PASS` | 4/4, 0 failure: barcode scientifico estremo, scope pending, scala 1.500+20 ed export completo; `/tmp/task140-ios-fix-focused-2.xcresult`. |
| Focused final | `PASS` | Policy 7/7 + integration 14/14 + import parity 28/28 = 49/49, 0 failure; `/tmp/task140-ios-focused-final-1.xcresult`. |
| Localizzazioni | `PASS` | `plutil -lint` EN/IT/ES/ZH-Hans; test presenza chiavi incluso nella suite integration. |
| Fixture parity | `PASS` | `cmp`, SHA-256 e `jq` eseguiti realmente. |
| Debug build | `PASS` | Compilazione Debug inclusa nei test Simulator mirati e completi. |
| Release build | `PASS` | Generic iOS Simulator Release, `** BUILD SUCCEEDED **`; `/tmp/task140-ios-release-final-1.xcresult`. |
| Analyze | `PASS_WITH_NOTES` | `** ANALYZE SUCCEEDED **`; 0 errori, 0 analyzer warning, 6 warning Swift 6 storici nel target test e 0 warning sui file toccati; `/tmp/task140-ios-analyze-final-1.xcresult`. |
| Full XCTest | `PASS` | Rerun finale post-fix: 1.312 eseguiti, 1.277 passed, 35 skipped opt-in live/hardware/large, 0 failure; 224,945 s test; `/tmp/task140-ios-full-final-1.xcresult`. |
| Import resource bounds | `PASS` | La suite completa finale include import medium 6k, export 6k/24k, preview 6k/24k e ProductPrice 30k, oltre ai limiti archive/import esistenti. |
| Target UI test / scheme | `PASS` | `xcodebuild -list` espone app, unit e `iOSMerchandiseControlUITests`; pbxproj `plutil` e scheme condiviso `xmllint` validi. |
| XCUITest Import Analysis/Database | `PASS` | 2/2 sul Simulator iPhone 17 Pro iOS 26.5, 0 failure: Import Analysis blocca apply per riga scientifica estrema e Database presenta realmente il picker Files CSV; nessun `sleep`; `/tmp/task140-ios-ui-final-1.xcresult`. |
| Independent rereview | `APPROVED_PRE_PR` | SHA `7d8f0de1`; P0/P1/P2/P3 `0/0/0/1`, con il solo P3 audit-trail corretto in questo commit documentale. |
| Staging cross-platform | `NOT_RUN / EXTERNAL_PRECONDITION` | Richiede account/shop QA coordinati, ID esatti, autorizzazione write e cleanup; non disponibili nel workstream iOS. |
| Secret/privacy scan | `PASS` | Nessun secret o dato reale introdotto; evidence e fixture sono sintetiche. |
| Production / Win7POS | `NOT_MODIFIED` | Nessun accesso o write. |

## Comandi principali eseguiti

```text
xcodebuild test -project iOSMerchandiseControl.xcodeproj \
  -scheme iOSMerchandiseControl \
  -destination 'platform=iOS Simulator,id=<AVAILABLE_SIMULATOR>' \
  -only-testing:iOSMerchandiseControlTests/CatalogTextPolicyTests \
  -only-testing:iOSMerchandiseControlTests/CatalogTextIntegrationTests \
  -only-testing:iOSMerchandiseControlTests/Task111ExcelImportParityTests

xcodebuild test -project iOSMerchandiseControl.xcodeproj \
  -scheme iOSMerchandiseControl \
  -destination 'platform=iOS Simulator,id=<AVAILABLE_SIMULATOR>' \
  -only-testing:iOSMerchandiseControlTests

xcodebuild test -project iOSMerchandiseControl.xcodeproj \
  -scheme iOSMerchandiseControl \
  -destination 'platform=iOS Simulator,id=<AVAILABLE_SIMULATOR>' \
  -only-testing:iOSMerchandiseControlUITests/CatalogTextImportUITests

xcodebuild build -project iOSMerchandiseControl.xcodeproj \
  -scheme iOSMerchandiseControl -configuration Release \
  -destination 'generic/platform=iOS Simulator'

xcodebuild analyze -project iOSMerchandiseControl.xcodeproj \
  -scheme iOSMerchandiseControl \
  -destination 'generic/platform=iOS Simulator'

cmp -s <admin-fixture> <ios-fixture>
shasum -a 256 <admin-fixture> <ios-fixture>
jq empty <ios-fixture>
plutil -lint iOSMerchandiseControl/{en,it,es,zh-Hans}.lproj/Localizable.strings
git diff --check
```

Gli UUID Simulator sono dettagli infrastrutturali effimeri; il test fallito
prima dell'esecuzione per destination rimossa non è contato come failure di
prodotto.

## Failure history e correzioni

- i primi test policy hanno evidenziato classificazione `Zs`, metadati fixture
  e confronto NFC; corretti fino al pass 7/7;
- il percorso import ha evidenziato barcode scientifico e CSV CRLF/quote;
  corretti con parser dedicato e regressioni;
- la prima integrazione pending ha evidenziato accesso a helper non visibile e
  semantica remote-clean delle relazioni; corretti senza mutare supplier/category
  puliti;
- il nuovo test atomico iniziale usava NUL, che SwiftData non preserva; sostituito
  con U+200B, preservato dal datastore e vietato dalla policy;
- un rilancio ha restituito destination unavailable perché il Simulator
  precedente era stato eliminato: nessun test fu eseguito; rilancio su device
  disponibile verde;
- il primo compile focalizzato dei fix ha evidenziato un errore di typecheck nel
  bounded integer helper; corretto e superseded dal rerun 4/4;
- l'XCUITest ha reso osservabile che tre modifier `.fileImporter` concorrenti
  non presentavano in modo affidabile il picker CSV: consolidati in un solo
  importer tipizzato, sequenziato con `Task.yield()` e senza attese temporali;
- i primi due run UI interrogavano il tipo/identifier errato per root e
  navigation bar del picker. La gerarchia accessibilità ha confermato il flusso
  reale; le query finali usano `File View`, `Recents` e `Cancel`, 2/2 verdi.

## AI worklog

### 2026-07-27 — apertura EXECUTION

- letti `AGENTS.md`, protocollo, Master Plan, task attivo e brief condiviso;
- verificati baseline, ahead/behind e stato pulito;
- creato worktree isolato e branch task senza modificare `main`.

### 2026-07-27 — implementazione

- aggiunti policy, parser CSV, boundary persistence e pending repair;
- integrati manual edit/create, import preview/apply, full import/export,
  pending/outbound, inbound incremental/recovery e localizzazioni;
- aggiunti fixture golden e test policy/integration;
- mantenute dipendenze e schema esistenti.

### 2026-07-27 — audit e handoff

- audit finale corretto: collisione strict contro barcode legacy,
  outbound product limitato ai campi realmente inviati e preflight atomico
  dell'intera riparazione pending;
- review indipendente `CHANGES_REQUIRED`: corretti expansion barcode
  resource-bounded, repair pending scalabile, export completo e acceptance UI;
- creato target XCUITest reale con scheme condiviso e due flussi Simulator
  deterministici, senza `sleep`;
- gate focalizzati, full XCTest, Release, Analyze e XCUITest rieseguiti;
- suite completa finale post-fix: 1.312 eseguiti, 35 skipped opt-in, 0 failure;
- staging classificato con stato misurato, senza claim inventati;
- task promosso a `ACTIVE / REVIEW`, non `DONE`.

## Rischi residui / reviewer checklist

- verificare il bounded parser scientifico, inclusi `9.99E+95` accettato e
  `9.99E+96`/esponente enorme rifiutati prima dell'allocazione;
- verificare i predicate owner/store/status, la paginazione a 256 e gli indici
  target del pending repair;
- verificare che full export validi anche supplier/category non referenziati
  prima di creare file temporanei/workbook;
- verificare configurazione target/scheme XCUITest e hook esclusivamente DEBUG;
- staging richiede una fase coordinata e autorizzata separata;
- nessun passaggio a `DONE` senza conferma esplicita utente.
