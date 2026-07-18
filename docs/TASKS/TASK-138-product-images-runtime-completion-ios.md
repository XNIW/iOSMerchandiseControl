# TASK-138 - Product Images Runtime Completion, UX e Live Parity (iOS)

## Tracking

- Stato: `DONE`
- Fase: `DONE_RECONCILED`
- Data apertura: `2026-07-18`
- Responsabile: `USER_CONFIRMED_RELEASE`
- Contratto canonico: Admin Web
  `docs/TASKS/TASK-138-product-images-runtime-completion-ux-live-parity.md`
- Evidence locale: `docs/TASKS/EVIDENCE/TASK-138/README.md`
- Base locale: `2e2cc6202d4947e13946da7ec6e6ac5337703862`
- Dipendenza: backend TASK-137/TASK-138 verificato localmente prima di scrivere
  codice Swift.
- TASK-137 resta `REVIEW_WITH_BLOCKERS`; non viene riaperto o chiuso.

Il prompt utente del `2026-07-18` autorizza esplicitamente questo mirror e la
lane iOS in execution. L'autorizzazione specifica prevale sulla regola generica
che riserva la creazione dei task al planner.

## Obiettivo iOS

Chiudere soltanto i gap runtime iOS rilevati prima della modifica:

- provare placeholder senza `versionID` con zero chiamate rete e zero entry;
- preservare thumb crop in lista e main fit nell'editor;
- batch `read-urls` per shop con dedup e chunk massimi di 100;
- mantenere il coalescing UI esistente e renderlo condiviso/testabile nel
  service, con limite esplicito ai download concorrenti;
- cancellare/ignorare lavoro offscreen e mantenere memoria bounded;
- cache account/shop scoped, offline-first e purge su logout/switch;
- un solo retry per URL scaduta; decode/MIME invalido mai in cache;
- replace/remove selettivi e completion stale incapace di sovrascrivere;
- preservare preprocess/downsample off-main e budget TASK-137;
- progress preprocess/main/thumb/finalize e cancellazione end-to-end;
- test lista 200 prodotti, suite fixture, screenshot e misure riproducibili.

## File candidati

- `iOSMerchandiseControl/ProductImages/ProductImageAPIClient.swift`
- `iOSMerchandiseControl/ProductImages/ProductImageService.swift`
- `iOSMerchandiseControl/ProductImages/ProductImageCache.swift`
- `iOSMerchandiseControl/ProductImages/ProductImageStore.swift`
- `iOSMerchandiseControl/ProductImages/ProductImageViews.swift`
- `iOSMerchandiseControl/ProductImages/ProductImageProcessor.swift`
- `iOSMerchandiseControl/EditProductView.swift`
- test mirati e sole stringhe localizzate necessarie.

L'elenco e indicativo: nessun file deve essere modificato se il requisito e gia
soddisfatto e provabile.

## Vincoli

- un solo writer nel repository iOS;
- nessuna nuova dipendenza senza motivazione esplicita;
- nessun blob, Base64, URL firmata, token o path Storage in SwiftData/sync/log;
- nessuna service role client-side;
- nessuna modifica Supabase live dalla lane iOS;
- nessun Win7POS, production, commit, push, merge, reset o clean;
- Simulator e fixture condivisa usati in modo seriale, non concorrente.

## Gate e check

La lane resta ferma sui documenti finche il gate backend locale non e `PASS`.
Dopo il gate:

1. XCTest service/API per batch ≤100, dedup, retry unico e coalescing;
2. XCTest cache/store per decode invalido, isolation, switch e purge;
3. test store/UI per cancel, stale result e 200 prodotti visible-only;
4. processor suite, incluso 48 MP, alpha, HEIF e input invalidi;
5. sync baseline pertinente, localizzazioni e build Debug;
6. Simulator serializzato e screenshot;
7. parity sul medesimo shop non-production soltanto se sessione disponibile.

Ogni check deve riportare risultato reale o `NOT_RUN`/`BLOCKED_ENV`.

## Criteri di accettazione iOS

- Product A non genera rete/cache;
- Product B usa thumb lista e main fit editor;
- 200 prodotti non producono fan-out o crescita non bounded;
- batch/dedup/coalescing/limite download sono verificati;
- offline cache e account/shop isolation sono verificati;
- invalid response non resta in cache e URL scaduta ha un solo retry;
- upload/replace/noop/remove, progress e cancel sono coerenti col backend;
- nessuna regressione catalogo/sync e nessun dato sensibile persistito;
- evidence sufficiente per handoff `REVIEW`, mai `DONE`.

## Execution iOS - 2026-07-18

Gate backend ricevuto dal coordinatore prima delle patch Swift: reset locale
`PASS`, pgTAP `149/149 PASS`, foundation `20/20 PASS`, route/lifecycle E2E
`PASS` e fixture persistente multi-ruolo `PASS`.

Implementazione completata entro lo scope:

- `read-urls` aggregato per account/shop/sessione, deduplicato e spezzato a
  massimo `100` riferimenti;
- single-flight nel service e nello store per riferimento, con waiter tracking
  per non cancellare un peer ancora visibile;
- download concorrenti limitati esplicitamente a `4` e attesa cancellabile;
- cancellazione dei load offscreen, guardie generation/scope contro completion
  stale e cache/metadati memoria bounded (`100` entry / `48 MiB`);
- decode ImageIO reale prima di ogni commit rete su disco; entry cache invalide
  rimosse prima del fallback rete;
- cache offline-first account/shop scoped con purge su logout, cambio account e
  cambio shop;
- retry della signed URL limitato a un solo tentativo dopo `401/403`;
- preprocess e decode off-main cancellabili, incluso input sintetico 48 MP;
- progress reale `processing -> uploadingMain -> uploadingThumb -> finalizing`
  e cancellazione dell'operazione da editor;
- thumb lista resta crop/fill; main editor resta fit;
- test mirati aggiunti per no-image zero I/O, offline cache, retry unico,
  dedup/coalescing, batch/chunk e concorrenza su 200 riferimenti, visible-only,
  decode invalido, stale/cancel e purge scope;
- nessuna dipendenza aggiunta e nessuna modifica Supabase/live.

## Check eseguiti

- `xcodebuild -project iOSMerchandiseControl.xcodeproj -list`: `PASS`;
- build Debug generica del runtime e compilazione dell'intero target test con
  `-sdk iphonesimulator`, `CODE_SIGNING_ALLOWED=NO`, `build-for-testing`:
  `PASS` (`** TEST BUILD SUCCEEDED **`), senza boot di Simulator/device;
- `plutil -lint` sulle localizzazioni EN/IT/ES/ZH: `4/4 PASS`;
- scan statico runtime Product Images per log/persistenza di token, signed URL,
  Base64 o service role: `PASS`, nessun sink trovato;
- XCTest Product Images nuovi e di regressione su iPhone 16e Simulator:
  `32/32 PASS`, zero failure, `TEST SUCCEEDED` in `4,091 s`;
- test 200 riferimenti/concorrenza: `PASS` in `2,897 s`; fixture high-res 48 MP:
  `PASS` in `0,067023 s`, peak physical `92.097,944 kB`;
- il primo run aveva `9` assertion failure in `5` test per un recorder test che
  non leggeva `httpBodyStream`; corretto il recorder, il run identico e passato;
- screenshot e walkthrough UI visuale: `NOT_RUN`;
- Supabase live e device fisico: `NOT_RUN`, fuori scope autorizzato.

Warning di compilazione residui provengono da test legacy fuori scope
(`Task097RuntimeSmokeTests`, `Task098CrossPlatformSmokeTests`,
`Task103CrossPlatformAcceptanceTests`, `SyncRecoveryPolicyTests` e
`AccountSyncPolicyTests`); nessun errore e nessun warning Product Images nel
check finale.

## Handoff a REVIEW

File runtime toccati:

- `ProductImageContract.swift`, `ProductImageAPIClient.swift`,
  `ProductImageCache.swift`, `ProductImageProcessor.swift`,
  `ProductImageService.swift`, `ProductImageStore.swift`,
  `ProductImageViews.swift`, `EditProductView.swift`;
- `Localizable.strings` EN/IT/ES/ZH;
- `ProductImageAPIClientTests.swift`, `ProductImageCacheTests.swift`,
  `ProductImageProcessorTests.swift`.

Rischi/residui da validare in review:

- screenshot, metriche runtime e comportamento visuale/cancel devono essere
  osservati sul Simulator prima dell'accettazione finale;
- la parity Supabase sul medesimo shop non-production resta separata e richiede
  una sessione autorizzata;
- nessun claim `DONE`, production-ready, live Supabase o device fisico.

Prossima fase: `REVIEW` con esecuzione seriale dei test/runtime mancanti e
conferma esplicita dell'utente per qualunque chiusura successiva.

## Optimization pass iOS - override utente 2026-07-18

Il task era gia `ACTIVE / REVIEW`. L'utente ha autorizzato esplicitamente una
nuova execution limitata dei gap Product Images senza riaprire TASK-137 e senza
creare TASK-139. Override applicato: tracking e fase restano `REVIEW`, il writer
iOS implementa e verifica soltanto questo pass, quindi prepara un nuovo handoff
a `REVIEW` e non marca mai `DONE`.

Gap chiusi staticamente e in build:

- l'originale e downsampled una sola volta con `CGImageSource` verso max 1600;
  thumb deriva dalla main normalizzata, non dal 48 MP originale;
- autoreleasepool per le fasi pesanti, quality/resize ladder finite, metriche di
  fase, cancellazione e nessun `Data`/`UIImage` grande nello State SwiftUI;
- signed URL lease cache memory-only con expiry/safety window, LRU bounded,
  batch/coalescing esistenti e invalidazione su 401/403/scope/version;
- disk LRU `128 MiB`, memoria decoded `48 MiB`/100 entry con accounting reale,
  file protection/atomicita, memory warning e purge scope;
- dettaglio progressive placeholder -> thumb -> main, decode prima del
  crossfade, Reduce Motion, retry con thumb preservata e cancel su task/version;
- upload sequenziale bounded con un solo retry network/5xx per oggetto;
  finalize solo dopo entrambi i PUT, cancellazione end-to-end preservata;
- test aggiunti per lease valida/scaduta, LRU/eviction, memory warning,
  progressive order e upload retry.

Check reale non-Simulator: Debug generic `build-for-testing` app + intero target
test `PASS` (`** TEST BUILD SUCCEEDED **`, ultimo run `20,1 s`). Il primo run ha
fallito solo per `await` dentro autoclosure XCTest nel nuovo test LRU; corretto
il test, non il runtime, e il comando identico e passato.

`xcodebuild ... analyze` generico e stato eseguito senza boot del Simulator:
`PASS` (exit `0`), con soli warning preesistenti in `Vendor 2/libxls` e nei test
legacy actor-isolated, nessun finding Product Images. La parity locale resta
opt-in tramite config esterna `0600`; in assenza di sessione autorizzata viene
riportata come skip/blocker, senza persistere token o signed URL.

Gate patch-invalidated su iPhone 16e iOS 26.2: `34` test eseguiti, `33 PASS`,
`1 SKIP` parity opt-in, `0 failure`, suite `4,243 s`; API/service/store `18`
(1 skip), cache/store `9/9`, processor `7/7`. Evidenze:
`optimization-product-images.xcresult` e bundle diagnostico del primo
destination mismatch `optimization-product-images-destination-failure.xcresult`.
Metriche osservate: 205 riferimenti `2,970 s`, progressive `0,034 s`, 48 MP
`0,172 s`, HEIC `0,213 s`, high-res `0,055153 s` e peak physical
`100093,264 kB`. Simulator spento al termine, nessun device rimasto `Booted`.
Le attachment processor riportano, su cinque fixture sintetiche, main bytes
p50/p90/p95 `25.107/395.369/395.369`, thumb
`2.232/64.297/64.297` e tempo totale `55/70/70 ms` (nearest-rank). Il campione
non e considerato rappresentativo e non viene usato per stime Storage globali.

Evidence: `docs/TASKS/EVIDENCE/TASK-138/09-optimization-review.md`.

Handoff corrente: `REVIEW_WITH_BLOCKERS`; le suite invalidate sono `PASS`, ma
gli screenshot/walkthrough restano `BLOCKED_EXTERNAL_PRECONDITION` senza una
fixture/sessione UI autorizzata. Nessun Supabase live, staging, production o
device fisico eseguito in questa fase del pass; nessun commit/push/merge/deploy
e nessun claim `DONE`.

Parity locale opt-in successivamente autorizzata con config esterna `0600`:
primo run `SKIP` per env host non ereditata dal runner; unico retry `FAIL` prima
della rete per rotazione del data container durante reinstall app (Cocoa `260`,
file non trovato). Bundle `optimization-local-parity.xcresult` e
`optimization-local-parity-retry.xcresult`; environment/copia rimossi,
Simulator spento, secret-pattern scan `PASS`. Stato preciso: `BLOCKED_ENV`, non
un fail del contratto Product Images e non un claim parity.

## Final review iOS - preparazione runtime 2026-07-18

Un ulteriore override utente ha autorizzato una review/fix finale circoscritta
alla lane iOS. Il pass non cambia tracking o fase e non avvia il Simulator fino
al via del coordinatore.

Preparato e compilato:

- config parity in `/tmp` Simulator stabile, mode esatto `0600`, path propagato
  esclusivamente tramite copia temporanea della `.xctestrun`; senza config il
  test read-only continua a fare skip esplicito;
- parity Product B separata in read-only, mutazione `replace`, pausa di verifica
  cross-platform e mutazione `remove`; ogni mutazione richiede opt-in distinto,
  endpoint loopback e produce solo attachment redatto;
- harness visuale DEBUG con dipendenze hosted/no-network e sei stati sintetici:
  lista, dettaglio thumb, dettaglio main, picker editor, cache offline e fallback
  errore; test hosted allega sei PNG e il root app consente screenshot Simulator;
- test con metriche JSON per scroll completo di 200 thumbnail e apertura di 20
  prodotti per 20 cicli, con bound 100 entry/48 MiB memoria e 128 MiB disco;
- `git diff --check`, build-for-testing e Xcode Analyze generici: `PASS`; build
  app + intero target test `** TEST BUILD SUCCEEDED **`; nessun Simulator
  avviato.

Il bundle diagnostico parity fallito da circa 55 MiB e stato sintetizzato in un
riepilogo redatto e spostato temporaneamente fuori repository. Runbook esatto:
`docs/TASKS/EVIDENCE/TASK-138/10-ios-final-review-runbook.md`.

Stato runtime: `NOT_RUN` in attesa di autorizzazione; uscita ancora `REVIEW`,
mai `DONE`.

## Chiusura finale 2026-07-18

Il coordinatore ha autorizzato ed eseguito il runtime seriale. Risultati:

- read della versione Android: `1/1 PASS`, Product A zero I/O e Product B
  thumb -> main;
- replace iOS: `1/1 PASS`, seguito da read Admin e Android `PASS`;
- remove della versione Android: il primo tentativo ha ricevuto `503` dopo il
  commit DB; l'unico retry consentito ha provato `already_removed` in `0,249 s`;
- Admin ha confermato assenza e zero image-read `1/1 PASS`;
- sei screenshot Simulator finali ispezionati dopo il fix del clipping harness;
- suite completa finale: 40 eseguiti, `37 PASS`, `3 SKIP` opt-in attesi senza
  config, `0 failure`; Analyze exit `0` con soli warning vendor `libxls`;
- teardown: config rimossa, Simulator spento, cleanup coordinato
  DB/Storage/Auth `0`.

Verdict: `RELEASE_READY_WITH_MEASURED_GATES`. Stato: `DONE`, fase
`DONE_RECONCILED`, su conferma esplicita utente. Device fisico e staging/dev
autenticato restano `BLOCKED_EXTERNAL_PRECONDITION`, non PASS inventati.
