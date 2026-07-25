# TASK-139 final verification — lane iOS

> **Checkpoint storico, verdict superseduto.** Il runtime successivo al tap
> reale `Sostituisci con dati cloud`, i totali finali e il blocker di convergenza
> sono documentati in
> [`13-post-choice-runtime-checkpoint-ios.md`](13-post-choice-runtime-checkpoint-ios.md).
> I risultati sotto restano evidence del run descritto, ma non rappresentano lo
> stato corrente di TASK-139. L'ultimo audit ha chiuso la mancata eredità del
> `TaskLocal` nei `Task.detached` con lease esplicite e due test; gate autorevole
> post-fix: core `162/162`, UX `82/82`, Product Images `70 + 3 skip / 73`,
> automatic `23/23`, totale `337 + 3 skip / 340`, zero failure. Il supplementare
> `58/58` si sovrappone al core. Build PASS con otto warning legacy; analyze
> PASS con 18 issue soltanto in `Vendor 2/libxls` (`xls.c` / `ole.c`).

Stato iniziale: `REVIEW`, override utente limitato ai gate finali e a fix
dimostrati nel perimetro TASK-139. Questo file registra la matrice prima di
eventuali patch Swift. Le colonne Admin/Android distinguono il contratto comune
verificato byte-per-byte dai runtime, che appartengono alle lane dedicate.

## Matrice implementazione iniziale

| Requisito | Admin | Android | iOS | Test esistente iOS | Test mancante iOS | Drift | Patch necessaria | Risultato iniziale |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Main/thumb budget | Contratto comune: main target `768000`, hard max `1048576`; thumb `92160` | Come contratto comune | Runtime `750 KiB`/`1 MiB`, thumb `90 KiB` | Processor budget/high-res/48 MP | Assert diretto di tutti i valori runtime contro JSON | Nessun drift numerico | Solo test | `COVERED_WITH_TEST_GAP` |
| Ladder compressione | Contratto comune: factors e quality ladder | Come contratto comune | Factors e quality ladder uguali | Shared contract factors/qualities + vector schedule | Min side/max side/target/hard max non congelati tutti dal JSON | Nessun drift noto | Solo test | `COVERED_WITH_TEST_GAP` |
| Marker JPEG | JFIF APP0 ammesso; APP1…15/COM/trailing vietati | Come contratto comune | Parser bounded, stripping ImageIO, SOI/EOI terminali | Processor + shared marker fixture | Output ImageIO reale ancora da accettare sul server nel pass corrente | Nessun drift noto | Nessuna patch runtime iniziale | `LOCAL_COVERED_E2E_PENDING` |
| API fields | Contratto machine-readable comune | Come contratto comune | Request/response typed, required field validation nei service test | API client + local parity opt-in | Assert completo delle liste required dal JSON | Nessun drift noto | Solo test | `COVERED_WITH_TEST_GAP` |
| MIME obbligatorio | `image/jpeg` | `image/jpeg` | Metadata e PUT serializzano `image/jpeg`; download lo richiede | Processor/API client | Assert JSON → runtime metadata | Nessuno | Solo test | `COVERED_WITH_TEST_GAP` |
| Batch max | `100` | `100` | `100` | 205 refs → `100/100/5` | Assert diretto JSON → constant | Nessuno | Solo test | `COVERED_WITH_TEST_GAP` |
| Download concurrency | `4` | `4` | Gate actor default `4` | 205 load e cache stability | Assert diretto JSON → constant | Nessuno | Solo test | `COVERED_WITH_TEST_GAP` |
| Signed URL lease | TTL `300 s`, safety `30 s`; budget iOS `1000` | Come contratto, budget platform-specific | Memory-only LRU `1000`, safety `30 s`; expiry server-driven | valid/expired lease, refresh una volta | Assert JSON → safety/budget | Nessuno; budget platform-specific atteso | Solo test | `COVERED_WITH_TEST_GAP` |
| Retry | Upload max `1`; signed URL refresh max `1` | Come contratto comune | Un retry transient/5xx upload; un refresh 401/403 download | retry upload, refresh exactly once, stop after second failure | Assert policy JSON → runtime | Nessuno | Solo test | `COVERED_WITH_TEST_GAP` |
| Cache memory/disk | Budget platform-specific | Budget platform-specific | `48 MiB`, 100 entry; disk `128 MiB`, LRU | memory warning, scroll 200, open20, disk LRU | Assert budget iOS JSON → runtime | Differenza platform-specific documentata nel contratto | Solo test | `COVERED_WITH_TEST_GAP` |
| Account/shop scope | Key comune account/shop/product/version/variant | Come contratto comune | Hash account + shop/product/version/variant; purge switch | cache scope, account switch, remove/replace | Nessuno noto | Nessuno | No | `COVERED` |
| Progressive rendering | Thumb → main | Thumb → main | List thumb-only; detail thumb → main, fit/fill separati | progressive store + visual harness | Rerun visuale sei stati e ispezione reale | Nessuno | No | `SIM_VISUAL_PENDING` |
| Cancellazione | Last consumer abort | Last consumer abort | waiter tracking store/service, task on disappear | offscreen cancel, coalesced peer | Visual disappearance/cancel in pass corrente | Nessuno noto | No | `LOCAL_COVERED_VISUAL_PENDING` |
| Upload progress | Stati comuni | Stati comuni | processing/main/thumb/finalize/completed/cancelled/failed | upload sequence e mutation parity | UI visuale degli stati upload non inclusa nei sei stati minimi | Gap evidence, non runtime dimostrato | Da valutare dopo runtime | `PARTIAL_EVIDENCE` |
| Cleanup | Backend ledger/lock | Client remove scoped | Invalida lease e purge cache scoped; backend cleanup fuori lane | remove contract/cache | Cleanup Storage appartiene lane Admin/Supabase | Nessun drift iOS | No | `IOS_COVERED_BACKEND_EXTERNAL` |
| Error code | Lista canonica comune | Lista canonica comune | Error enum granulare senza mapping esplicito ai codici canonici | Solo casi enum/test locali | Mapping e freeze lista JSON mancanti | Gap dimostrato | Sì, mapping interno + test | `PATCH_REQUIRED` |

## Hash contratto e fixture

I tre repository hanno prodotto gli stessi SHA-256 e `cmp` byte-per-byte ha
restituito `0` per contratto e manifest:

| File | SHA-256 |
| --- | --- |
| `contracts/product-image-v1.json` | `612a403b1397546cad62b38cf70ad666c7290bfcdae1973778ff8b1ff85f1686` |
| `contracts/fixtures/product-image-v1-valid.json` | `5912807c913ff04af05e6d35339ae43eb875ab1e56c246cb916d894f212b0e49` |
| `contracts/fixtures/product-image-v1-invalid.json` | `b089914123663e806a7304dda251d654ff8436447f10474bfb804d3fea318fd8` |
| `contracts/fixtures/product-image-synthetic-v1.json` | `34322705f2e036fdd68d21a46f2310fa14da57894a312786e93a97495dd987d9` |

`shasum -a 256 -c contracts/product-image-v1.sha256`: quattro file `OK`.

## Risultato finale della lane

| Gate | Esito | Evidence |
| --- | --- | --- |
| Build Debug | `PASS` | `xcodebuild ... CODE_SIGNING_ALLOWED=NO build`, exit `0` su iPhone 17 Pro iOS 26.4.1. |
| XCTest Product Images + sync + visual | `PASS` | `51` totali: `48` passati, `3` skip opt-in, `0` failure. |
| Camera fallback off-main | `PASS` | Fixture `4000×3000`; heartbeat MainActor entro `0.5 s`; raster/bounding/encode in detached `autoreleasepool`; JPEG `<=1600 px`, `<=1 MiB`, metadata-free. |
| Analyze | `PASS_WITH_OUT_OF_SCOPE_WARNINGS` | Exit `0`; zero warning Product Images. Warning storici in `Vendor 2/libxls` e test legacy, non modificati. |
| Shared contract | `PASS` | Quattro SHA-256 `OK`; `cmp` cross-repository `0`. |
| Workflow locale | `LOCAL_WORKFLOW_COMMANDS_PASS` | Hash, build, suite, analyze, sensitive scan eseguiti localmente. |
| GitHub Actions | `GITHUB_ACTIONS_NOT_RUN_UNPUBLISHED` | Workflow non pubblicato per divieto di push. |
| Secret scan | `PASS` | `mc-agent scan sensitive` bounded allo scope TASK-139, exit `0`. |
| Diff check | `PASS` | `git diff --check` exit `0`; staging area vuota; nessun build output, xcresult, local config o artifact esterno nel diff. |
| ImageIO → server locale | `BLOCKED_ENV` | Due tentativi totali: il test host non vedeva la config privacy-safe nel proprio spazio temporaneo; zero HTTP/PUT/finalize/mutazioni. Config eliminate. |
| Staging autenticato | `BLOCKED_ENV` | URL/allowlist e credenziali staging non disponibili alla lane iOS. |
| Device fisico | `BLOCKED_ENV` | Nessun device iPhone disponibile. |

I tre skip finali sono esclusivamente gli opt-in locali `no-image/progressive`,
`replace` e `remove`; nessuno è stato convertito in PASS.

## Correzioni dimostrate dalla verifica finale

1. Aggiunto mapping esplicito tra errori runtime iOS e i 17 error code canonici.
2. Congelati via test i valori runtime contro il contratto JSON comune.
3. Applicato limite `2` alle richieste read-URL e mantenuto limite `4` ai download.
4. Corretto lo scanner JPEG per più scan SOS, marker vietati dopo entropy data e
   payload trailing; aggiunto fixture test multi-scan.
5. Eliminata la rasterizzazione camera dal MainActor: l'intero fallback bounded
   viene eseguito off-main in `autoreleasepool`, con cancellazione propagata.
6. Rimosso overflow orizzontale dal visual harness con frame relativo al
   viewport, content margins e header full-width; aggiunte asserzioni bounds e
   freeze test dei vincoli (`4/4` visual scoped post-fix).

## Visual QA iOS

Tutti i PNG sono `1206×2622`, generati con `simctl screenshot`, aperti e
ispezionati dopo l'XCTest del layout. Una capture dello stato errore ha
intercettato la transizione full-screen del launch, evidente perché anche status
bar e intero frame erano traslati. La capture finale è stata eseguita senza
rilancio, sullo stato già fermo, dopo ulteriori `5 s`; la decodifica stabile ha
confermato status bar, header e bordi completi. SHA-256 finale error/fallback:
`698c53bfe37d0da22322a9f8342ce2e68d13b2e98c7e7dd01e8bc7808b41f68d`.

| Stato | File | Esito manuale |
| --- | --- | --- |
| Lista placeholder + thumb | `screenshots/ios-list.png` | `PASS`: placeholder coerente, thumb crop/fill, testo e righe raggiungibili. |
| Dettaglio preview | `screenshots/ios-detail-thumb.png` | `PASS`: thumb visibile mentre main carica, no shift/clipping. |
| Dettaglio main | `screenshots/ios-detail-main.png` | `PASS`: main fit/contain, no overflow. |
| Editor/picker | `screenshots/ios-editor-picker.png` | `PASS`: libreria/fotocamera leggibili e raggiungibili. |
| Offline cache | `screenshots/ios-offline-cache.png` | `PASS`: immagine cache e stato offline coerenti. |
| Errore/fallback | `screenshots/ios-error-fallback.png` | `PASS`: thumb resta visibile, retry presente, testo leggibile. |

La query AX ha rilevato, tra gli altri, `Anteprima immagine prodotto`,
`Main non disponibile` e la descrizione del retry/fallback. Gli identifier
`task138.visual.*` e `product.image.*` sono inoltre congelati nel sorgente e
usati dal visual harness.

## Metriche iOS

| Scenario | Risultato |
| --- | --- |
| High-resolution XCTest | peak physical `90884.52 kB`; delta physical `0 kB`; monotonic `0.059068864 s`. |
| 48 MP ImageIO | input `8000×6000`; main `1600×1200`, `395311 B`; thumb `384×288`, `61980 B`; elapsed `77 ms`. |
| Scroll 200 | `200` prodotti/download; memory decoded `44236800 B`, `100` entry; disco `496600 B`. |
| Riapertura 20×20 | `40` download; max memory `17694720 B`, `40` entry; max disco `99320 B`; nessuna crescita monotona. |

Il budget cache iOS resta volutamente platform-specific (`48 MiB`, `100` entry,
disco `128 MiB`) come dichiarato nel contratto condiviso.

## Stato Git e handoff

- HEAD e `origin/main`: `66d90983f8e9ab08dd72184abb4ec70d2c4daefb`,
  divergenza `0 0`.
- Nessun file staged, commit, push o merge.
- Nessun deploy/migration production e nessuna modifica Win7POS.
- Esito lane: `REVIEW_WITH_EXTERNAL_BLOCKERS`; fase successiva `REVIEW`, mai
  `DONE` senza conferma esplicita dell'utente.
