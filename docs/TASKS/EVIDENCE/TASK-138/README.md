# TASK-138 iOS Evidence

## Baseline

- tracking ref locale: `2e2cc6202d4947e13946da7ec6e6ac5337703862`;
- worktree TASK-138 detached e pulito alla creazione;
- verifica GitHub live: `BLOCKED_ENV_DNS` (`Could not resolve host: github.com`);
- checkout originale dirty preservato;
- backend gate coordinatore: `PASS`;
- baseline black-box: `PASS_FOUNDATION_WITH_GAPS`;
- runtime patch: `IMPLEMENTED_BUILD_AND_SIMULATOR_TESTED`;
- stato finale: `DONE / DONE_RECONCILED`, verdict
  `RELEASE_READY_WITH_MEASURED_GATES` su conferma utente.

### Run baseline reale

- XCTest Product Images: `22/22 PASS`, zero failure, `TEST SUCCEEDED`;
- target: iPhone 16e Simulator gia avviato;
- metrica high-res campionata: `0,071474 s`, peak physical `70.143,072 kB`;
- URLProtocol/Simulator soltanto: Supabase live e device fisico `NOT_RUN`.

## Audit pre-modifica

- placeholder e thumb/main corretti; manca prova dinamica zero-I/O;
- `.task(id:)` collega il load alla view, con guardie di generazione/scope;
- store in-memory bounded (`100` entry, `48 MiB`) e downsample off-main;
- service invia un ref per `read-urls`, senza batch o limite download;
- coalescing presente solo nel singolo store tramite `loadingReferences`;
- cache key scoped e offline-first; vecchio scope disco non purgato;
- one retry `401/403`: implementato;
- MIME/magic bytes verificati ma i byte sono scritti in cache prima del decode
  ImageIO eseguito dallo store;
- preprocess off-main e budget TASK-137 presenti;
- progress generico, finalize non rappresentato realmente e cancel assente;
- test 200 prodotti, live Supabase comune e screenshot: non eseguiti.

## Gate backend precedente alla scrittura Swift

Risultati comunicati dal coordinatore della lane backend, non rieseguiti dal
writer iOS:

- reset locale: `PASS`;
- pgTAP: `149/149 PASS`;
- foundation: `20/20 PASS`;
- route/lifecycle E2E: `PASS`;
- fixture persistente multi-ruolo: `PASS`.

## Evidence implementazione

- batch `read-urls` per scope/sessione con dedup e limite rigido `100`;
- coalescing service/store single-flight per riferimento con waiter tracking;
- download gate cancellabile con massimo `4` richieste simultanee;
- load offscreen cancellabile, result stale ignorato con generation/scope;
- memoria e metadati store bounded: `100` riferimenti / `48 MiB`;
- decode ImageIO e limiti dimensione prima del commit cache;
- cache invalida rimossa, offline cache preservata, purge account/shop su
  logout/switch;
- un solo retry per `401/403` Storage;
- preprocess/downsample off-main cancellabile e main/thumb budget invariati;
- progress `processing`, `uploadingMain`, `uploadingThumb`, `finalizing`, con
  stato `cancelled` e CTA di cancellazione editor;
- thumb catalogo `.fill` e main editor `.fit` preservati;
- nessuna nuova dipendenza, migration, mutazione Supabase live o Git operation.

## Check reali post-patch

| Check | Risultato | Evidence sintetica |
| --- | --- | --- |
| `xcodebuild -list` | `PASS` | progetto e scheme risolti |
| Debug `build-for-testing`, SDK Simulator generico, signing off | `PASS` | `** TEST BUILD SUCCEEDED **` |
| Compilazione target `iOSMerchandiseControlTests` | `PASS` | nuovi test Product Images compilati |
| `plutil -lint` EN/IT/ES/ZH | `4/4 PASS` | quattro file `OK` |
| Scan statico log/persistenza secret Product Images | `PASS` | nessun sink token/signed URL/Base64/service role |
| XCTest Product Images | `32/32 PASS` | iPhone 16e Simulator, `TEST SUCCEEDED` in `4,091 s` |
| Runtime lista 200 prodotti / visible-only | `PASS_SIMULATOR` | test service/store incluso; 200 ref in `2,897 s` |
| High-res 48 MP | `PASS_SIMULATOR` | `0,067023 s`, peak physical `92.097,944 kB` |
| Screenshot runtime | `NOT_RUN` | nessuna cattura visuale effettuata |
| Supabase live stesso shop | `NOT_RUN` | fuori scope/sessione non usata |
| Device fisico | `NOT_RUN` | fuori scope |

Comando build finale:

```text
xcodebuild -project iOSMerchandiseControl.xcodeproj \
  -scheme iOSMerchandiseControl \
  -sdk iphonesimulator \
  -derivedDataPath /tmp/task138-ios-derived \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

Output conclusivo: `** TEST BUILD SUCCEEDED **`.

Run Simulator finale, limitato alle quattro suite Product Images:

```text
xcodebuild test ... \
  -only-testing:iOSMerchandiseControlTests/ProductImageAPIClientTests \
  -only-testing:iOSMerchandiseControlTests/ProductImageCacheTests \
  -only-testing:iOSMerchandiseControlTests/ProductImageProcessorTests \
  -only-testing:iOSMerchandiseControlTests/ProductImageSyncTests
```

Esito: `32/32 PASS`, zero failure, `** TEST SUCCEEDED **`. Il primo tentativo
aveva `9` assertion failure in `5` test API: il recorder del test leggeva solo
`httpBody`, mentre `URLSession` consegnava correttamente un `httpBodyStream`.
Il recorder e stato corretto per leggere entrambe le forme; il runtime non e
stato modificato per mascherare il fail. Il secondo run identico e passato.

Warning residui solo in test legacy fuori scope; nessun errore e nessun warning
nei file Product Images modificati.

## Test aggiunti ed eseguiti su Simulator

- no-image/nil version: zero rete e zero cache;
- cache offline senza sessione;
- URL scaduta: un solo retry e stop al secondo `401/403`;
- batch dedup/chunk `<=100`, limite download e 200 riferimenti;
- richieste duplicate: una `read-urls` e un download;
- JPEG formalmente marcato ma non decodificabile: nessun commit cache;
- cancellation/stale completion: nessuna immagine o failure pubblicata;
- cancellazione di un waiter coalesced: il peer visibile completa una sola rete;
- catalogo 200: avvio solo per il subset visibile;
- logout/account switch: memoria svuotata e cache disco purgata;
- processor 48 MP e input JPEG corrotto.

## Residui per REVIEW

- eseguire i gate finali gia preparati per sei screenshot sintetici e metriche
  cache 200/open20 quando il coordinatore autorizza il Simulator;
- eseguire parity non-production sul medesimo shop solo con sessione esplicita;
- nessun claim `DONE`, production/live o device fisico; i test Simulator sono
  contract/store/processor e non sostituiscono il walkthrough visuale.

## Final review preparata

Il pass finale aggiunge, senza nuove dipendenze o target Xcode:

- parity locale opt-in stabilizzata con path Simulator
  `/tmp/task138-ios-local-parity.json`, permessi esatti `0600` ed environment
  in copia temporanea `.xctestrun`;
- read-only, `replace` e `remove` separati; i due mutanti richiedono un valore
  di autorizzazione distinto e accettano solo endpoint loopback;
- harness DEBUG no-network e test visuale per `list`, `detail-thumb`,
  `detail-main`, `editor-picker`, `offline-cache`, `error-fallback`;
- test sintetici cache/memoria per scroll 200 e riapertura 20 prodotti per 20
  cicli;
- build-for-testing e Xcode Analyze generici successivi: `PASS`; Simulator/
  runtime ancora `NOT_RUN` in attesa di autorizzazione.

Runbook ed evidence: `10-ios-final-review-runbook.md`. Il bundle fallito parity
da circa 55 MiB e stato sostituito nell'evidence da
`optimization-local-parity-retry-summary.md` e spostato temporaneamente in
`/tmp`, preservando il risultato utile senza appesantire il repository.

## Regole evidence

Solo fixture sintetiche e risultati reali. Vietati secret, token, signed URL,
dati cliente, originali, production e claim da test non eseguiti.
