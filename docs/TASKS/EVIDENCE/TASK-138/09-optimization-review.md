# TASK-138 iOS Optimization Review

## Requisito e override operativo

Optimization pass Product Images del `2026-07-18`: preprocessing e memoria
bounded, signed URL lease cache memory-only, cache disco LRU, progressive
thumbnail -> main, upload retry/cancel e visual evidence.

Il task era gia `ACTIVE / REVIEW`. Il prompt utente autorizza esplicitamente
questo pass di execution limitato; l'override e annotato senza riaprire
TASK-137, creare TASK-139 o dichiarare `DONE`. L'uscita resta `REVIEW`.

## Stato recuperato prima del pass

- worktree: `/Users/minxiang/.codex/worktrees/task-138-20260718/ios`;
- branch: detached (`HEAD (no branch)`);
- `HEAD`: `2e2cc6202d4947e13946da7ec6e6ac5337703862`;
- `origin/main`: `2e2cc6202d4947e13946da7ec6e6ac5337703862`;
- diff iniziale TASK-138 preservato: `1338` inserimenti, `126` rimozioni su
  `15` file tracciati, piu mirror/evidence non tracciati;
- `git diff --check`: `PASS`;
- staged diff: vuoto;
- nessun file TASK-137 storico nel diff;
- nessun `.xcresult` o `DerivedData` nel repository;
- screenshot root/evidence storici gia tracciati, nessun nuovo screenshot
  temporaneo prima del pass;
- nessuna modifica `.xcodeproj`/scheme: i cambi test-only non alterano il
  runtime o il membership dei target.

## Gap confermati

1. `ProductImageProcessor` creava main e thumb ridownsampleando due volte il
   `CGImageSource` originale.
2. La compressione era finita in pratica, ma senza un massimo esplicito di
   resize attempts e senza metriche separate per downsample/main/thumb.
3. `ProductImageService` coalescava e batchava le richieste, ma non riusava
   `expiresAt` con safety window in una lease cache memory-only.
4. `ProductImageCache` aveva scope, scrittura atomica e file protection, ma
   nessun byte budget/LRU disco.
5. `NSCache` aveva `48 MiB`/`100` entry, ma l'accounting/eviction non era
   deterministico e mancava la purge su memory warning.
6. Il dettaglio richiedeva solo `.main`: non dimostrava placeholder -> thumb ->
   main, decode-before-crossfade o Reduce Motion.
7. L'upload era cancellabile tramite `Task`, ma non ritentava una volta i soli
   errori transient network/5xx.

## Modifiche iOS

- downsample ImageIO dell'originale una sola volta verso max `1600`; main e
  thumb vengono poi ottenute dalla bitmap main gia orientata, sRGB e con alpha
  appiattito su bianco;
- fasi pesanti racchiuse in `autoreleasepool`, lavoro fuori `MainActor`, check
  di cancellazione e massimo `16` resize attempts con quality ladder finite;
- metriche aggiunte: downsample, encode main e resize/encode thumb;
- lease signed URL solo in memoria, key completa `scope/shop/product/version/
  variant`, safety window `30 s`, massimo `1000` lease, LRU, expiry parse,
  coalescing/batch esistenti preservati, invalidazione su `401/403`, logout,
  shop/account switch, replace e remove;
- un solo refresh e un solo retry download su `401/403` preservati;
- cache disco LRU globale `128 MiB`, derivata dal worst-case contrattuale di
  `100 * (1 MiB + 90 KiB) ~= 109 MiB` piu overhead; access touch, byte count,
  atomic write e file protection preservati;
- memoria decoded: `NSCache.totalCostLimit = 48 MiB`, count `100`, accounting
  byte esplicito, eviction deterministica e purge su memory warning;
- dettaglio SwiftUI progressivo: placeholder, thumb, main; lista resta solo
  thumb `.scaledToFill`, dettaglio `.scaledToFit`; main compare soltanto dopo
  decode dello store con crossfade nativo `0,18 s`, disabilitato con Reduce
  Motion; `.task(id:)` cancella su disappear/version change; main failure lascia
  thumb e retry;
- upload sequenziale main/thumb (scelta bounded in memoria), un retry per
  oggetto soltanto su network transient o `5xx`, nessun retry su `401/403` o
  validazione permanente; finalize resta dopo entrambi i PUT e cancel non lo
  raggiunge.

## File coinvolti dall'optimization pass

| File | Simboli |
| --- | --- |
| `ProductImageContract.swift` | `ProductImagePreprocessMetrics` |
| `ProductImageProcessor.swift` | `prepare`, `makeVariant`, `resizedImage` |
| `ProductImageAPIClient.swift` | `uploadJPEG`, `isTransientUploadError` |
| `ProductImageService.swift` | `SignedReadLease`, resolve/invalidate lease |
| `ProductImageCache.swift` | disk budget, access touch, LRU eviction |
| `ProductImageStore.swift` | progressive load, memory accounting/warning |
| `ProductImageViews.swift` | progressive rendering, retry, Reduce Motion |
| `ProductImageAPIClientTests.swift` | lease/expiry/progressive/upload retry |
| `ProductImageCacheTests.swift` | disk eviction e memory warning |
| `ProductImageProcessorTests.swift` | metriche fase fixture |

## Test e risultati reali

| Check | Tipo | Risultato | Evidence |
| --- | --- | --- | --- |
| Fase 0 Git audit | STATIC | `PASS` | comandi richiesti eseguiti; HEAD/origin e diff sopra |
| TASK-137 untouched | STATIC | `PASS` | `git diff --name-only -- docs/TASKS/TASK-137* docs/TASKS/EVIDENCE/TASK-137*` vuoto |
| artifact hygiene | STATIC | `PASS` | prima del runtime nessun artifact; poi solo quattro `.xcresult` sotto questa evidence, DerivedData in `/tmp` |
| `git diff --check` | STATIC | `PASS` | exit `0` |
| localizzazioni EN/IT/ES/ZH | STATIC | `4/4 PASS` | `plutil -lint`, quattro `OK` |
| build generica app + test | BUILD | `PASS` | comando sotto, `** TEST BUILD SUCCEEDED **`, `20,1 s` ultimo run |
| Xcode Analyze app + test | STATIC | `PASS` | exit `0`; warning solo vendor/test legacy fuori scope |
| XCTest Product Images patch-invalidated | SIM | `PASS` | 34 eseguiti, 33 pass, 1 skip opt-in, 0 failure; suite `4,243 s` |
| result bundle summary | STATIC | `PASS` | `xcresulttool`: result Passed, 34 total, 33 pass, 1 skip, 0 failure |
| artifact secret-pattern scan | STATIC | `PASS` | nessun JWT/Bearer/service-role value nei quattro `.xcresult` |
| bounded sensitive-sink review | STATIC | `PASS` | nessun log/persistenza secret, signed URL, Base64 o large image State introdotto |
| parity locale opt-in | SIM/LOCAL | `BLOCKED_ENV` | config 0600 disponibile; skip host-env, poi container reinstallato nell'unico retry |
| walkthrough/screenshot iOS | SIM/MANUAL | `NOT_RUN` | slot chiuso dopo i test; manca una fixture/sessione UI navigabile |
| Supabase live/staging/production | LIVE | `NOT_RUN` | vietato alla lane iOS; nessuna mutazione |
| device fisico | MANUAL | `NOT_RUN` | fuori perimetro disponibile |

Comando build eseguito:

```text
xcodebuild -project iOSMerchandiseControl.xcodeproj \
  -scheme iOSMerchandiseControl \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/task138-ios-optimization-derived \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

Il primo tentativo ha compilato il runtime ma ha fallito il target test con
cinque errori `await in an autoclosure that does not support concurrency` nel
nuovo test LRU. I valori actor sono stati letti prima delle assertion XCTest;
il rerun identico ha prodotto `** TEST BUILD SUCCEEDED **`. Nessun runtime code
e stato cambiato per mascherare il fail.

Eseguito inoltre `xcodebuild -quiet ... analyze` con SDK e destination generici
Simulator, DerivedData in `/tmp` e signing disabilitato: exit `0`. I finding
riportati sono limitati al vendor storico `Vendor 2/libxls` e a warning actor
isolation di test legacy; nessun warning/finding Product Images.

La parity non-production e predisposta come test opt-in: legge esclusivamente
un JSON locale esterno al repository indicato da
`TASK138_LOCAL_PARITY_CONFIG_PATH`, richiede permessi file `0600` e non stampa
token o signed URL. Senza configurazione il test viene saltato esplicitamente;
non sostituisce la suite fake/deterministica e non autorizza mutazioni live.

### Tentativo parity locale autorizzato

Il coordinatore ha poi fornito una config locale esterna al repository con
permessi `0600` e Admin locale su porta `3050`. Sono stati consumati il run e
l'unico retry ammessi, senza stampare o leggere manualmente valori sensibili:

1. `optimization-local-parity.xcresult`: il processo host aveva la variabile,
   ma il runner Simulator non l'ha ereditata; 1 test, 1 skip in `0,008 s`;
2. per il retry la config e stata copiata con mode `0600` nel data container e
   il path propagato con `launchctl setenv`; `test-without-building` ha
   reinstallato l'app e ruotato il container dopo la copia, quindi il test e
   fallito prima di qualunque richiesta rete con Cocoa `260` file-not-found;
   `optimization-local-parity-retry.xcresult`, 1 test, 1 failure in `0,038 s`.

Non sono stati fatti ulteriori tentativi. Environment rimosso, copia container
eliminata/assente, Simulator spento e nessun device `Booted`. Lo scan dei due
bundle parity non trova JWT/Bearer/service-role value. Stato parity iOS:
`BLOCKED_ENV`; prossimo tentativo, solo con nuova autorizzazione, deve iniettare
la config nel runner dopo l'installazione (per esempio tramite `.xctestrun`) o
usare un path Simulator stabile e poi cancellarlo.

## Gate Simulator preparato

```text
xcodebuild test-without-building \
  -project iOSMerchandiseControl.xcodeproj \
  -scheme iOSMerchandiseControl \
  -destination 'platform=iOS Simulator,name=iPhone 16e' \
  -derivedDataPath /tmp/task138-ios-optimization-derived \
  -resultBundlePath docs/TASKS/EVIDENCE/TASK-138/optimization-product-images.xcresult \
  -only-testing:iOSMerchandiseControlTests/ProductImageAPIClientTests \
  -only-testing:iOSMerchandiseControlTests/ProductImageCacheTests \
  -only-testing:iOSMerchandiseControlTests/ProductImageProcessorTests
```

Il comando esatto per nome non ha eseguito test ed e terminato con exit `70`:
Xcode ha risolto implicitamente `OS:latest` (`26.5`), mentre gli iPhone 16e
installati erano solo `26.1` e `26.2`. Il result bundle diagnostico e conservato
in `optimization-product-images-destination-failure.xcresult`. L'unico retry
autorizzato ha usato l'ID esplicito dell'iPhone 16e iOS 26.2:

```text
xcodebuild test-without-building \
  -project iOSMerchandiseControl.xcodeproj \
  -scheme iOSMerchandiseControl \
  -destination 'platform=iOS Simulator,id=4CE85775-BEF1-44D5-9BBF-B180EDF09D0B' \
  -derivedDataPath /tmp/task138-ios-optimization-derived \
  -resultBundlePath docs/TASKS/EVIDENCE/TASK-138/optimization-product-images.xcresult \
  -only-testing:iOSMerchandiseControlTests/ProductImageAPIClientTests \
  -only-testing:iOSMerchandiseControlTests/ProductImageCacheTests \
  -only-testing:iOSMerchandiseControlTests/ProductImageProcessorTests
```

Risultato retry: `** TEST EXECUTE SUCCEEDED **`, 34 test eseguiti, 33 pass,
1 skip esplicito della parity opt-in senza config locale, 0 failure; durata
suite `4,243 s`, operazione IDE `6,936 s`.

- API/service/store: 18 eseguiti, 17 pass, 1 skip, 0 failure (`3,429 s`);
- cache/store: 9/9 pass (`0,119 s`);
- processor: 7/7 pass (`0,696 s`);
- 205 riferimenti, chunk `100/100/5`, concurrency bounded: `2,970 s`;
- ordine progressive thumb -> main: `0,034 s`;
- 48 MP: `0,172 s`; HEIC: `0,213 s`;
- performance high-res: monotonic `0,055153 s`, peak physical
  `100093,264 kB`.

Dopo il test il device e stato spento esplicitamente; `simctl` non riportava
alcun device `Booted`. Il bundle verde pesa `1,0 MiB`; quello diagnostico del
destination mismatch `28 KiB`. Una lettura indipendente con `xcresulttool` ha
confermato `result: Passed`, 34 totali, 33 pass, 1 skip e 0 failure.

### Metriche processor estratte dall'xcresult

| Fixture sintetica | Input bytes/dimensioni | Main bytes/dimensioni | Thumb bytes/dimensioni | Downsample | Encode main | Encode thumb | Totale |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 48 MP | 2.694.339 / 8000x6000 | 395.369 / 1600x1200 | 62.038 / 384x288 | 60 ms | 6 ms | 3 ms | 69 ms |
| HEIC | 2.762 / 2000x1200 | 25.107 / 1600x960 | 2.232 / 384x230 | 64 ms | 2 ms | 2 ms | 70 ms |
| high-resolution | 1.224.254 / 5000x4000 | 179.973 / 1600x1280 | 64.297 / 384x307 | 46 ms | 5 ms | 3 ms | 55 ms |
| JPEG ruotato | 12.481 / 1200x600 | 12.612 / 600x1200 | 2.007 / 192x384 | 4 ms | 1 ms | 1 ms | 7 ms |
| PNG trasparente piccolo | 632 / 160x100 | 1.890 / 160x100 | 1.848 / 160x100 | 0 ms | 0 ms | 0 ms | 0 ms |

Distribuzione nearest-rank sui soli cinque campioni sintetici:

| Metrica | p50 | p90 | p95 |
| --- | ---: | ---: | ---: |
| main bytes | 25.107 | 395.369 | 395.369 |
| thumb bytes | 2.232 | 64.297 | 64.297 |
| totale processor | 55 ms | 70 ms | 70 ms |
| downsample | 46 ms | 64 ms | 64 ms |
| encode main | 2 ms | 6 ms | 6 ms |
| encode thumb | 2 ms | 3 ms | 3 ms |

Questa distribuzione documenta la pipeline iOS e i suoi hard bound, ma non e
un campione fotografico rappresentativo: non viene usata come media globale o
per proiezioni Storage 1k/10k/20k/100k. Resize e hash non hanno ancora timer
separati; la memoria disponibile e la misura XCTest aggregata high-res sopra,
non una serie before/peak/after per ogni fixture.

## Review bounded del diff iOS

Scan limitato ai file Product Images e alle sole righe aggiunte dell'editor:
nessun `print`/logger di token o URL, `UserDefaults`/Keychain, service role,
Base64 o sink di persistenza signed URL; nessun `UIImage`/`Data` grande aggiunto
a `@State`/`@Published`. Il `print` storico a riga 600 dell'editor non e una
riga aggiunta dal diff e non contiene dati sensibili. Le lease restano campi
actor in memoria e la cache disco riceve soltanto JPEG gia validati.

## Risultato dopo la modifica e blocker correnti

Stato lane: `REVIEW_WITH_BLOCKERS`. Il gate XCTest patch-invalidated e chiuso,
ma il walkthrough visuale non ha evidence reale.

- parity locale sul medesimo shop: `BLOCKED_ENV` dopo skip della variabile host
  e rotazione data container nell'unico retry; la sessione/config era presente,
  ma nessuna chiamata parity e stata eseguita;
- parity non-production: `BLOCKED_EXTERNAL_PRECONDITION`, target/sessione non
  forniti; nessun token o signed URL scritto in evidence;
- screenshot visuali lista/dettaglio/editor/offline/error:
  `BLOCKED_EXTERNAL_PRECONDITION`, manca una fixture/sessione UI autorizzata;
- device fisico non verificato;
- nessun claim di perfezione, zero leak, `DONE` o production-ready.

Conferma scope: nessun file o comportamento fuori dal perimetro Product Images
e stato modificato dall'optimization pass. Nessun commit, push, merge, deploy,
migration o write Supabase; Win7POS non toccato; nessun terzo oggetto preview,
originale, Base64/blob o signed URL persistita.

## Review finale runtime e chiusura

Il precedente blocker Simulator e stato chiuso usando una copia `.xctestrun`
adiacente ai build products, che preserva `__TESTROOT__`, e una config nel
`/tmp` stabile del Simulator con mode `0600`.

- parity read Android -> iOS: `1/1 PASS`, `0,326 s`;
- parity replace iOS: `1/1 PASS`, `0,241 s`; Admin e Android reader PASS;
- parity remove iOS della versione Android: commit DB riuscito; prima risposta
  PostgREST `503` post-commit, unico retry idempotente `PASS`, `0,249 s`;
- Admin absent/zero image-read dopo remove: `1/1 PASS`;
- cache/visual runtime: `4/4 PASS`; sei PNG finali ispezionati;
- suite finale Product Images: 40 eseguiti, `37 PASS`, `3 SKIP` opt-in attesi,
  `0 failure`, `8,164 s` test time;
- Analyze finale: exit `0`, soli 18 warning vendor `libxls` preesistenti;
- cleanup: nessuna config, nessun Simulator Booted, DB/Storage/Auth fixture `0`.

Artifact hygiene: i bundle diagnostici falliti/no-test e il bundle visuale
intermedio sono stati spostati in `/tmp`; restano nel repository solo bundle
verdi e riepiloghi redatti. Lo scan JWT/Bearer/service-role e il review bounded
non trovano secret o sink nuovi.

Metriche finali campionate: 205 ref `3,107 s`, scroll 200 `1,877 s`, 48 MP
`0,160 s`, HEIC `0,265 s`, high-res `0,052561 s`, peak physical
`91.998,608 kB`. Non sono picchi assoluti né prova di zero leak.

Verdict: `RELEASE_READY_WITH_MEASURED_GATES`; task `DONE` su conferma utente.
Staging/dev autenticato e device fisico restano `BLOCKED_EXTERNAL_PRECONDITION`.
