# TASK-140 iOS Evidence — CATALOG-TEXT-001

## Verdict execution iOS

`INDEPENDENT_REVIEW_APPROVED_AND_STAGING_ACCEPTED`

L'implementazione, i gate locali, il merge normale e l'acceptance staging
coordinata sono completi. Il task resta `ACTIVE / REVIEW`, non `DONE`, in
attesa della conferma esplicita dell'utente.

## Baseline e sicurezza

- repository: `XNIW/iOSMerchandiseControl`;
- baseline: `351ccb9dd0e573bd7f450f23efc1d50670ae362f`;
- branch implementazione: `codex/catalog-text-integrity-ios-20260727`;
- branch closeout: `codex/catalog-text-integrity-closeout-ios-20260727`;
- HEAD preesistente al fix round:
  `95f015196907309ec0bdac2472c5f6b18fe40432`;
- fix round revisionato:
  `7d8f0de19a4630d3b7ab925df09b18285f320c3e`;
- worktree isolato:
  `/Users/minxiang/.codex/worktrees/catalog-text-integrity-20260727/ios`;
- fixture e test usano esclusivamente dati sintetici `TASK140_*`;
- production: `NOT_MODIFIED`;
- Win7POS: `NOT_MODIFIED`;
- staging: `PASS` nel perimetro coordinato allowlisted;
- commit fix round: `7d8f0de19a4630d3b7ab925df09b18285f320c3e`;
- PR iOS: [#1](https://github.com/XNIW/iOSMerchandiseControl/pull/1);
- merge normale iOS:
  `712689dd917125c9c656b8cc48e7c392c87174fd`;
- production deploy/TestFlight: `NOT_RUN / OUT_OF_SCOPE`.

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
| Independent rereview | `APPROVED` | SHA finale pubblicato; P0/P1/P2/P3 `0/0/0/0`. |
| PR/CI/merge | `PASS` | PR iOS #1, CI verde, merge normale a due parent `712689dd`; PR Admin #42 e Android #3 collegati e integrati. |
| Staging cross-platform | `PASS` | iOS read/apply del prodotto + 4 prezzi Android; write iOS Release + 4 prezzi letti canonicali da Android/Admin, owner/shop scoped. |
| Staging repair/paging | `PASS` | repair atomico `345`, invalidi `0`, invarianti preservati; paging Win7POS-equivalente completo read-only. |
| Fixture cleanup | `PASS` | record/eventi rimossi per ID esatti; residue fixture/shop QA `0`. |
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

### 2026-07-27 — closeout coordinato su override utente

- override applicato alla sola documentazione di closeout, senza riaprire
  l'execution runtime iOS;
- PR iOS #1 pubblicato, CI verde e merge normale verificato; PR Admin #42 e
  Android #3 collegati e integrati;
- acceptance su iOS Simulator completata contro lo shop QA staging: read/apply
  Android → iOS e write iOS → Android/Admin, con quattro prezzi per prodotto;
- migration/repair staging, paging Win7POS-equivalente e cleanup esatto
  verificati dal coordinatore;
- file di sessione/derived data/build effimeri eliminati; production e
  Win7POS non modificati;
- task consegnato a `REVIEW / READY_FOR_USER_CONFIRMATION`, non `DONE`.

## Rischi residui / reviewer checklist

- i controlli bounded parser, pending repair, full export e target/scheme
  XCUITest risultano coperti dai gate locali e dalla review indipendente;
- restano 6 warning Swift 6 storici nel target test, 0 nei file TASK-140;
- P0/P1/P2/P3 aperti `0/0/0/0`;
- production e Win7POS `NOT_MODIFIED`;
- nessun passaggio a `DONE` senza conferma esplicita utente.
