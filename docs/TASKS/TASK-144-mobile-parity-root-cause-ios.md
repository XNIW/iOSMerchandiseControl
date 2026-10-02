# TASK-144 — Mobile parity root-cause ios

## Stato

- File task: `docs/TASKS/TASK-144-mobile-parity-root-cause-ios.md`
- Stato: `FIX`
- Fase: `FIX`
- Responsabile: `CODEX_EXECUTOR_IOS`; orchestratore parent, reviewer indipendente separato.
- Data: 2026-09-28
- Baseline: `30d226d0fb9b8679a1dd034c6e82319645337f22`
- Branch corrente: `codex/mobile-parity-validation-ledger` (documentazione dal main integrato `2322c5e1`; branch sorgente `codex/mobile-parity-root-cause-ios` integrato con PR11)
- Coordination key: `MERCHANDISECONTROL_MOBILE_PARITY_ROOT_CAUSE`

## Scopo / Obiettivo

Audit funzionale mobile completo e correzione cause F01/F02/F03 e ulteriori difetti confermati; F04 documentale, verifica locale e staging/dispositivi disponibile, senza ampliare le funzionalità richieste.

## Planning

### Analisi

StorefrontAuthoringStore.resetFilter cancella filterTask ma non libera isFilterLoading; loadNextFilterPage non lega ogni callback a query e generazione filtro. LocalDraftRecord esiste ma UserDefaults e replay basato su expectedVersion richiedono verifica di errore disco/eviction/ACK perso; altre operazioni non conservano identità retry.

### Approccio

1. Congelare baseline e riprodurre con regressioni rosse prima della patch.
2. Correggere intent/storage e ownership asincrona con cambi minimi; verificare controparte e contratto server.
3. Eseguire audit delle capacità esistenti e test pertinenti; documentare separatamente code review, fake, runtime e staging.
4. Review indipendente, unico batch fix, re-review e gate canonici finali; preparare commit/PR senza assumere merge/produzione.

### File coinvolti

StorefrontAuthoring.swift, StorefrontAuthoringTests.swift, UI harness e XCUITest esistenti; EditProductView.swift/DatabaseView.swift solo se necessari ai finding; documenti master/task143 per F04.

### Addendum planning autorizzato — R-I02 checkpoint short envelope, 2026-09-28

Il collaudo Android autenticato e la verifica read-only del preflight TEST hanno dimostrato un ramo `resource_exceeded` con `compressed_legacy_history_requires_remediation` (16 history compresse). Il contratto checkpoint distribuito restituisce correttamente un envelope breve privo delle sezioni del successo; entrambe le app decodificano il DTO completo prima del discriminante. Il difetto equivalente iOS va riprodotto rosso e corretto in questo task (CA-07/CA-10), preservando journal/dati e i controlli di autorizzazione. Nessun valore di default deve trasformare il rifiuto in successo; niente remediation dati/backend o loop automatici per un rifiuto stabile. Il blocco discovery corrente del device iOS è precedente al checkpoint e rimane una diagnosi separata da provare sul runtime attuale. Review mirata e gate aggiornati richiesti; la CI97b6c812 fallita è conservata e deve essere diagnosticata senza rilanci ciechi.

### Addendum planning autorizzato — R-I05 logout e refresh tardivo, 2026-09-29 UTC

Il controllo circoscritto della controparte auth, richiesto da CA-06/07/10 durante R-A06 Android, riproduce con SDK Supabase 2.46.0 reale e transport controllato (nessuna rete, storage in memoria) una sessione ricreata dopo logout: refresh HTTP iniziato e sospeso, signOut(.local) terminato con 204 e currentSession nil, rilascio della risposta refresh valida, nuova sessione ed evento TOKEN_REFRESHED dopo SIGNED_OUT. Il test rosso ufficiale 1 FAIL è conservato in `/tmp/mc-task144-ios/auth-logout-probe/red.xcresult`; nessuna patch runtime applicata prima della prova. La ViewModel applicativa accetta tale evento e può tornare SignedIn. Non è una prova di logout eseguita sugli account reali.

Nuovo P1 concreto nel perimetro del mandato: una correzione minima nel provider/app deve mantenere il logout intenzionale anche dopo risposta tardiva e normale riavvio, senza limitarsi a nascondere lo stato UI mentre lo SDK ripersistisce la sessione. Conservare bootstrap tardivo legittimo, refresh ordinario, nuovo login esplicito e cambio account; nessuna callback precedente deve cancellare o sostituire la nuova sessione. Nessun upgrade/fork della dipendenza, secondo motore auth, lettura di credenziali reali, reset dati o modifica backend. Executor propone il confine minimo, test rosso→verde con SDK reale controllato e guardrail, review indipendente e gate canonici finali prima di integrazione. R-I04 resta un delta distinto già approvato e verificato nel normale import/export/no-op; il full finale includerà entrambi.

### Addendum planning autorizzato — R-I06 History ISO millisecondi, 2026-10-01

Il preflight TEST scoped delle20:18:23Z rifiuta History con shape/storage non valida (compressione0). La diagnosi read-only del coordinatore isola3righe attive valide per storage/data/overlay con timestamp business UTC ISO8601 esattamente tre millisecondi; l'helper backend ammette soltanto il formato legacy spazio/secondi. Il ledger recovery iOS richiede anch'esso il solo formato legacy e lancia `nonCanonicalTimestamp`: il solo fix backend non basta. Ricevute sanitizzate preservate nel pacchetto parent `evidence/staging-current-history/`, senza ID o contenuti reali.

È autorizzato nello stesso task CA-07/10 un test rosso sul recovery reale con fixture sintetica e ledger raw, poi helper specifico History in `ShopSyncRecoveryContract.swift`. Conservare il formato legacy esistente; aggiungere soltanto `YYYY-MM-DDTHH:mm:ss.SSSZ` esatto (3cifre, anno non0000, calendario gregoriano valido, ore0–23/secondi0–59, Z uppercase). Restituire l'esatta stringa per il digest, senza normalizzare o transitare dal Date materializzato; prezzi effective/created e updated/deleted UTC6 invariati. Validare recovery/attivazione e readback SwiftData del Date con .305; l'outbound esistente/fingerprint normalizza secondi e non viene cambiato né presentato come roundtrip wire esatto. Rifiutare precisioni alternative/offset/whitespace/date non valide, mantenere scope e mismatch digest. Nessuna riscrittura delle3righe, cambio modello/schema/queue. Contratto identico backend/Android; review e gate finali dopo R-I06. I gate R-I05 sul freeze0fa8c144 rimangono evidenze di quel codice precedente, non del futuro delta.

## Mandato e separazione dei ruoli

Richiesta utente 2026-09-28 `MERCHANDISECONTROL — AUDIT FUNZIONALE, ROOT-CAUSE FIXES, PARITÀ ANDROID/iOS E SINCRONIZZAZIONE`. Il prompt autorizza orchestrazione/planning, executor separati, correzioni funzionali, test, review indipendente e preparazione commit/PR. Questo planning è registrato dal parent orchestratore prima delle patch; gli executor aggiornano Execution/Fix/Handoff. Nessuna chiusura DONE automatica o merge autorizzato per inferenza dai train storici.

**Mandato coordinato aggiornato:** consenso diretto utente al coordinamento con «Completa attivazione WECHAT-010» e nuovo prompt con autorizzazione esplicita a commit/push/PR/merge delle modifiche verificate, rispettando le protezioni. Il parent di questo task mantiene ownership esclusiva dell'integrazione nativa, dopo review e CI exact-SHA; segue verifica main e CI post-merge. Nessun deploy produzione o reset dei dati utente.

Checkout primari con modifiche preesistenti preservati. Niente reset dati, force push, migrazioni/RLS/deploy production, nuove dipendenze, secondo motore sync o pipeline immagini. Harness Excel sospeso non riattivato. Client pubblico read-only; Admin/Supabase consultati solo per contratti e staging necessario. Task precedenti e gate fisici non chiusi automaticamente.

## Criteri di accettazione

| ID | Criterio e verifica richiesta |
|---|---|
| CA-01 | Baseline branch/HEAD/origin/main/diff/worktree/PR/CI exact-SHA registrata; lavoro preesistente preservato. |
| CA-02 | F01: salvataggio draft durevole prima del successo locale; storage fallibile, account/shop/stable ID, base/payload/version/op/key/stato; dismiss/riapertura/nuova istanza/reconnect/disk failure/due prodotti/due scope/conflict/replay testati. Pending separato da cache LRU. |
| CA-03 | F02: richiesta filtro identificata per scope/filtro/query/generazione; reset immediato, no stale success/error/finally, pagination/Tutti; test deterministici + UI rapida e controparte. |
| CA-04 | F03: intent immutabile persistito per tutte le mutation; stesso retry stessa key; ACK ignoto riconciliato prima di inviare payload diverso; test commit con ACK perso, pre-commit timeout, edit dopo validation, concorrenza e restart. Contratto reale staging verificato o dipendenza esterna precisa. |
| CA-05 | F04: stato documentale iOS riconciliato con PR/merge/CI reali, separando implementazione/integrazione/test/distribuzione e preservando gate fisici. |
| CA-06 | Matrice completa inventario/database/anagrafiche/prezzi/history/import-export/immagini/auth-shop/sync/Storefront/localizzazioni-accessibilità; fonte, file, backend, test eseguito e stato tra VERIFIED/DEFECT/MISSING_REQUIRED/NOT_TESTED/EXTERNAL_DEPENDENCY/INTENTIONAL_PLATFORM_DIFFERENCE. |
| CA-07 | Integrità locale/outbox/server/pull/UI verificata; sync automatica bidirezionale, scope/stale callback, offline/reconnect/restart/conflitti/paging/no-op. Convergenza per ID/campi/relazioni; nessun reset code. Gate live non sostituito dai fake. |
| CA-08 | Import/export condiviso CLP/barcode Unicode/quantità/duplicati/footer/no-op e immagini cache/preparazione/staged; fixture esistenti riusate, regressioni semantiche condivise senza riattivare harness Excel. |
| CA-09 | Misurazioni riproducibili prima/dopo per scenari sostenibili, dataset sintetico isolato, campioni/p50/p95/max/condizioni; nessuna ottimizzazione senza evidenza, niente garanzia assoluta 3s. Distinguere foreground/background/sospensione/force-stop. |
| CA-10 | Test rosso prima patch, verde e regressioni adiacenti; gate canonici finali sul codice finale e test UI eseguiti quando ambiente disponibile. Contare PASS/FAIL/SKIP e non equiparare androidTest compilati a eseguiti. |
| CA-11 | Review indipendente, batch fix e re-review; altri cicli solo nuove regressioni P0/P1/P2 concrete; commit/PR per repo con CI exact-SHA, NOT_MERGED se manca autorizzazione. |
| CA-12 | Report MERCHANDISECONTROL_MOBILE_PARITY_ROOT_CAUSE_RESULT con baseline/finali, matrice, finding/prove, test, sync, prestazioni, residui e stati separati. Ogni CA chiuso con ESEGUITO/NON ESEGUIBILE/NON ESEGUITO motivato; nessun “tutto completo” senza prove obbligatorie. |

## Decisione di verifica — compatibilità runner Xcode 27

Il gate canonico baseline fallisce prima dell'esecuzione per conformances di actor test double a protocolli applicativi già isolati MainActor (48 errori su circa23 file, Swift6.4). Il parent orchestratore autorizza il 2026-09-28 un batch test-only separato: allineare i fake a `@MainActor final class`, preservando serializzazione/reentrancy e tutte le asserzioni, più scomposizione di una espressione test troppo costosa al type-checker. Nessuna modifica all'isolamento globale dell'app, ai protocolli runtime, alle dipendenze o alle esclusioni CI. Le slice diagnostiche con override/esclusioni restano evidenza parziale; solo il comando canonico senza esclusioni può superare il gate. Reviewer indipendente controlla anche questo delta. Il cambiamento è necessario a CA-10 e non aggiunge funzionalità.

## Rischi

ACK perso e aggiornamento concorrente richiedono replay del contratto idempotente, non confronto ingenuo della sola versione. Scritture disco e cancellazioni possono interrompere il percorso; preservare pending, input e isolamento. Staging/device possono non disporre di sessione autorizzata; dichiarare gate non eseguibili senza estendere privilegi.

### Addendum autorizzato R-I06 / CI — oracle condiviso (2026-10-01)

Aggiungere la fixture sintetica condivisa di 45 timestamp e un test sul vero `requireHistoryTimestamp`, con stringa raw invariata per i valori ammessi e errore canonico per i rifiutati. Nessun delta applicativo iOS atteso; non modificare prezzi, UTC6, serializer o helper legacy. Il precedente freeze41eb e i suoi risultati restano distinti dal nuovo supplemento test.

La CI d05d163c/36932145104 è fallita nella selezione destinazione prima di build/test: Xcode26.6 ha riportato solo placeholder. Autorizzata correzione minima del workflow: inizializzare CoreSimulator, riusare la prima destinazione realmente compatibile; se manca, creare un iPhoneCI sul runtime installato e richiedere nuovamente una destinazione dello scheme. Un runtime assente/incompatibile deve ancora fallire; vietati skip/bypass o modifiche alle invocazioni build/full test/analyze/scan. Verifica controllata del vero script e review indipendente precedono nuovo commit/CI exact-SHA. Nessuna app dependency o configurazione production modificata.

### Addendum planning autorizzato — CI sul commit candidato (2026-10-01)

Il mandato richiede CI sullo SHA esatto. Il checkout predefinito della PR usa il merge temporaneo: metadata headSha non prova la revisione Git testata. Modifica minima autorizzata al solo input ref di actions/checkout: head.sha per pull_request, github.sha per push/workflow_dispatch. Versioni/pin, permessi, trigger e tutti i gate invariati; app/test/fixture invariati. Verificare indipendentemente il diff, quindi la revisione effettiva nel log e CI sul nuovo head prima del merge normale; conservare run precedenti con il loro tested SHA/tree. Nessun nuovo gate locale sull'app dedotto da questa modifica.

## Execution

### Esecuzione — integrazione e CI finali, 2026-10-02 UTC (root)

**File modificati:**
- `docs/MASTER-PLAN.md` — integrazione corrente e verifiche residue.
- `docs/TASKS/TASK-144-mobile-parity-root-cause-ios.md` — nuova evidenza parent, snapshot storici conservati.
- `docs/TASKS/EVIDENCE/TASK-144/integration-final/*.json` — ricevute pubbliche CI/merge/live e ledger con riferimenti portabili/12statiCA; checkout CI, conteggi e snapshot live sanitizzato.

**Azioni eseguite:**
1. PR [#11](https://github.com/XNIW/iOSMerchandiseControl/pull/11) integrata normalmente il 2026-10-01 alle 23:50:01Z: head `095e2110b254507106aa656d283c6966f0483afa`, main `2322c5e19e22252a7e54f8434a8820fb51459722`. Origin/main e ancestry verificati; nessun bypass o modifica delle protezioni.
2. CI [head36940178787](https://github.com/XNIW/iOSMerchandiseControl/actions/runs/36940178787) e [main36942886476](https://github.com/XNIW/iOSMerchandiseControl/actions/runs/36942886476) SUCCESS. Checkout Git effettivo provato dai log, rispettivamente `095e2110` e `2322c5e1`. Ogni log ufficiale completo contiene **1.403 PASS / 36 SKIP / 0 FAIL**, 1.439 ID unici senza duplicati: 1.395 unit/integration PASS e otto XCUITest effettivi PASS, stessi casi/stati/skip. Il workflow non pubblica xcresult: questi conteggi provengono dal log completo. Contract hashes, simulator provisioning, Debug, full XCTest, Analyze e secret scan PASS.
3. Ventiquattro warning source storici (18 Vendor e sei test) e un QoS runtime noto identici a PR-head; nessuno nuovo. Le due diagnostiche della baseline locale26 non emesse in CI non sono dichiarate risolte. Source326 `3c1ff005…`, oracle58 PASS e gate locali full1403/36, Release/analyze/TEST firmato conservati. Tutti22 file Release e23 TEST byte-identici ai rispettivi artifact41eb; firma/config verificati. Questo addendum modifica solo documentazione.
4. Snapshot live del coordinatore alle 00:42:29Z: build TEST `4a708a47…` autenticata, shop corretto, pending prima0. Un solo Retry ordinario alle 00:11:49Z termina alle 00:11:58.782635Z con recovery failed/verifiedConvergence=false, HTTP500/SQL57014 nel digest prezzi del checkpoint. Nessun nuovo manifest/finalization. Ricevuta sanitizzata SHA `b8bb4f7d…` nel [ledger](EVIDENCE/TASK-144/integration-final/validation-ledger.json). Il ritest dopo correzione backend e le misure restano separati.

5. Cronologia successiva separata dal receipt00:42: registry150/AdminPR123 preserva dati/permessi ma iOS00:55 e Android00:59 falliscono nella verifica finale v_integrity/57014. Registry151/AdminPR124/main2e236586, CI/postcheckPASS e dati/permessi invariati; unicoRetry iOS01:39:43→01:39:52.012612 ancora500/57014, no nuovo manifest/finalization, binding invariato. Android151 non ripetuto per la stessa failure backend. Ricevuta safe consolidata SHA a291f9c6… nel ledger; authPASS resta distinta. ReadbackAndroid01:15 a appferma: quick_checkok, journalrequired1/attempt16, binding1, manifest/baseline/watermark/business/outbox0 (proiezione c97bea0d…). Profilare l’interaRPC prima di un altrodelta/Retry.

**Check obbligatori dell'aggiornamento solo documentale:**

| Check | Stato | Note |
|---|---|---|
| Build | N/A | Solo documentazione; gate del codice finale verificati sopra. |
| Lint/static compiler | N/A | Nessuna modifica compilabile o di build. |
| Warning nuovi | N/A | Nessuna nuova compilazione; diagnostiche CI classificate. |
| Coerenza con planning | ESEGUITO | Mandato coordinato e CA-10/11; backlog e task storici invariati. |
| Criteri di accettazione | ESEGUITO per tracciamento | CA-10/11 gate e integrazione ESEGUITI. CA-07/09/12 ancora NON ESEGUITI integralmente per recovery, convergenza e misure residue. |

**Incertezze:** dati terminali e convergenza non sono provati da auth/pending0. Stato FIX, non DONE; nessun deploy produzione. Rosso, skip e snapshot precedenti conservati.

**Handoff notes:** parent responsabile di integrazione/rapporto, coordinatore owner dei simulatori autenticati. Retry dopo diagnosi e gate backend; nessuna attività concorrente sui suoi dispositivi.

### Esecuzione — CI checkout del candidato, 2026-10-01 (root)

**File modificati:**
- .github/workflows/ios-product-images-ci.yml — solo input ref del checkout: SHA head della PR; fallback github.sha sugli altri eventi.
- docs/TASKS/TASK-144-mobile-parity-root-cause-ios.md — planning autorizzato ed evidenza di esecuzione.

**Azioni eseguite:**
1. Checkout PR predefinito constatato nel workflow; su Android run36938212309 checkout Git f4e5500d e head7363cae hanno tree7e1eb674 identico. Quel PASS è TREE_EQUIVALENT_MERGE_CHECKOUT, non exact Git head.
2. App/test/fixture del candidato locale invariati; nessun nuovo PASS app dedotto dall'edit CI.
3. Diff minimo e ricostruzione byte-identica dei workflow precedenti verificati nella review indipendente APPROVED ci-exact-head-checkout-review.md (SHA084c37e9). Pin/versioni, permessi, trigger e gate invariati.

**Check obbligatori:**
| Check | Stato | Note |
|---|---|---|
| Build/test app | ESEGUITO sul freeze app invariato | Gate canonici e hash del batch corrente riportati sotto; nessun nuovo compile locale per il solo checkout input. Nuova CI sul commit effettivo obbligatoria. |
| Static workflow / diff | ESEGUITO | Ref minimo, inverso byte-identico; review APPROVED e git diff --check. |
| Warning nuovi | ESEGUITO | Nessuna nuova modifica a sorgenti/build SDK; diagnostici del batch app conservati. |
| Coerenza con planning | ESEGUITO | Solo provenance richiesta dal mandato exact-SHA. |
| Criterio CI exact-head | NON ESEGUITO al commit | Da verificare nel nuovo run con actual git checkout SHA; metadata headSha da soli insufficienti. |

**Handoff:** root conserva run precedenti e gestisce push/CI/merge normale/mainCI; nessun DONE o bypass.


### Esecuzione — R-I06 supplemento oracle condiviso, 2026-10-01

**File modificati:** `iOSMerchandiseControlTests/ShopSyncRecoveryContractTests.swift` (un nuovo XCTest async) e `tests/fixtures/recovery/history-timestamp-compatibility-v1.json` (copia esatta sintetica SHA `b5848df09494112d85509297c5430d8e4d64398428b3b71631a195f9caae6459`). Schema effettivo stringa `history-timestamp-compatibility-v1`, 45 nomi unici; il test blocca SHA/schema/count e chiama il vero helper per ogni vettore. `legacyAccepted` resta annotazione preesistente fuori dal contratto History, senza assert o modifica al helper legacy/prezzi.

**Risultati actual:** `testHistoryTimestampMatchesSharedCompatibilityOracle()` PASS, 45 vettori verificati (11 stringhe ammesse raw identiche, 34 errori `nonCanonicalTimestamp` attesi); due classi complete58 PASS/0 FAIL/0 SKIP (32 recovery+26 contract). Review supplemento APPROVED,0finding. Fingerprint326 `3c1ff0057f0fb69a98ca1ead1e21e005d0b3d7ccb95bdba6faa80ba2d6197beb`; un solo file test differisce da41eb, tutti207 file app e i quattro hash auth identici. Fixture separatamente hash-lockata e conservata senza trasformazioni. Nessun claim di45 runtime parity globale Android/backend da questa prova iOS.

**Gate finali locali:** full canonica senza esclusioni `1403 PASS / 0 FAIL / 36 SKIP`,1439identifier unici (1395 unit/integration+8 XCUITest PASS), oracle PASS anche nella full; riconto fresco indipendente del parent conferma casi/log/tutti326hash. Release/analyze/signed TEST effettivamente reinvocati PASS. Firma strict/deep ed effective entitlements verificati; tutti22 file artifact Release e23 TEST byte-identici alle rispettive copie41eb (binaryf7816722… /4a708a47…). Config TEST byte/semantica invariata, primary hash preservato, copia ignored rimossa. Analyze actual incrementale0source/0nuovi, baseline storica26 conservata e non dichiarata risolta; warning runtime QoS storico e36skip preservati. DD cache riusati come autorizzato dal parent, artifact storici preservati; nessun PASS inferito dal cache. [Manifest/counts/receipt](EVIDENCE/TASK-144/ri06-shared-oracle/final-gate-manifest.json). Sensitive scan test/fixture/new evidence/Task144 PASS e `git diff --check` PASS. WorkflowCI del parent; nessuna modifica app/SDK/price/UTC6/schema/dipendenze.

**Handoff:** test-only LOCAL_VERIFIED / SOURCE_APPROVED; signed TEST finale in `test-builds/ios/signed-ri06-oracle`, source3c1ff005 e fixture45 hash-lockati. CI/integration exact-SHA, launch e convergenza autenticata restano al parent/coordinatore. Nessun Git/DONE da executor, nessuna misura performance avviata da questa lane.

### Esecuzione — R-I06 History ISO millisecondi, 2026-10-01

**File modificati:**
- `iOSMerchandiseControl/Sync/Automatic/Recovery/ShopSyncRecoveryContract.swift` — helper specifico History: legacy invariato oppure UTC esatto a tre cifre frazionarie, calendario gregoriano valido, stringa originale nel ledger; unico call-site attivo History aggiornato.
- `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift` — recovery reale rosso/verde con `.305Z`, ledger raw e readback SwiftData dopo riapertura; checkpoint calcolato su secondi normalizzati deve impedire attivazione e preservare il container originale.
- `iOSMerchandiseControlTests/ShopSyncRecoveryContractTests.swift` — matrice positiva/negativa di grammatica e calendario, prezzo legacy e UTC6 invariati.

**Azioni ed evidenze:** test prima della patch `1 FAIL / 0 PASS`, errore `nonCanonicalTimestamp` nel recovery reale; dopo la patch le due classi complete `57 PASS / 0 FAIL / 0 SKIP` (32 recovery, 25 contract), 57 identifier unici, nessun runtime warning. Cinque test nuovi; nessuna assertion/esclusione indebolita. Review indipendente R-I06 `APPROVED`, nessun finding, fingerprint326 `41eb3ec1d98d8091bea980690263a68b901f5a392c56f7a9b4b2b55b6ef55006`; solo tre file sorgente/test differiscono dal precedente0fa8 e i quattro hash auth sono identici. Tre scan sensitive sui file impattati PASS con config isolata esplicita; primo tentativo con variabile config non supportata conservato come NOT_COUNTED, soltanto i nuovi report propri rimossi dalla primary. Nessun source/build/device della primary toccato.

**Check obbligatori finali:** mirati, coerenza planning, Release canonica, full e analyze ESEGUITI/PASS. Full ufficiale `1402 PASS / 0 FAIL / 36 SKIP`, 1438 identifier unici (1394 unit/integration e 8 UI PASS), source326 identico e riconto indipendente parent; include20 SDK auth e31 import PASS. Fresh analyze26 diagnostiche storiche/0 nuove; Release/full/signed TEST0 source warning; tool warning metadata e warning runtime QoS storico conservati. Tre source scan PASS, scan documentale finale separato. Namespace persistente `evidence/ios-ri06-history-timestamp`, separato da R-I05. [Manifest finale](EVIDENCE/TASK-144/ri06-history-timestamp/final-gate-manifest.json) con comandi/log hash/receipt. Nessuna modifica a SDK auth, prezzi, UTC6, modello/schema, fingerprint/outbound o dati reali; nessun roundtrip wire esatto dei millisecondi dichiarato.

**Artifact:** Release canonica non configurata binary `f7816722…`; signed TEST separato `test-builds/ios/signed-ri06/Artifact/iOSMerchandiseControl.app`, binary `4a708a4776cada737685542f0e94f4ad89eb15548b7ab473f38ab882c96d9c30`. Firma Automatic strict/deep e effective Simulator entitlements generati da Xcode verificati; primary config hash prima/dopo uguale, sola copia ignorata rimossa. Nessuna installazione o misura launch da executor. Gli artifact/gate precedenti0fa8 restano storici.

**Handoff:** LOCAL_VERIFIED / SOURCE_APPROVED per questa slice; integrazione exact-SHA/CI, launch e live restano separati al parent/coordinatore. Nessun DONE.

### Esecuzione — R-I04/R-I05 ripresa, 2026-10-01

**File modificati:**
- `ExcelSessionViewModel.swift` — processing namespace nei cinque reader XML esistenti, senza cambiare il contratto import.
- `Task111ExcelImportParityTests.swift` e due fixture XLSX condivise — tre regressioni su ZIP/XML effettivi, barcode/stringhe Unicode/CLP e formati numerici.
- `SupabaseClientProvider.swift` — gruppo SDK unico per storage key, fence generazionale sullo storage esistente, readback obbligatorio su sessione/legacy/PKCE e snapshot atomica leggibile dai consumer cross-actor.
- `SupabaseAuthService.swift` — risultati, errori ed eventi SDK portano la generation fino al consumo; finalizzazione locale anche su errore/cancellazione logout; callback/sign-in sulla snapshot catturata.
- `SupabaseAuthViewModel.swift` — epoch dell’operazione e generation alla completion/consumo evento; nessun ritorno SignedIn da una completion precedente.
- `SupabaseAuthLifecycleTests.swift` — 20 casi con SDK2.46 reale, transport controllato e storage in memoria; nessuna sessione/account reale o rete.

**Azioni ed evidenze:**
1. R-I04 storico: red3 casi1PASS/2FAIL, green31 e adiacenti29; delta applicativo esattamente5righe. Import normale Files dei due workbook, export5 prodotti e reimport no-op con sette tabelle uguali conservati come evidenza dello snapshot R-I04. Dopo pausa i vecchi raw/tmp log/xcresult/bundle non sono disponibili: hash/summary/confronti persistenti restano storici, non riverificati. I quattro hash sorgente/fixture attuali e CRC dei workbook sono riverificati. Nessuna riattivazione dell’harness Excel sospeso.
2. R-I05 ripreso: cinque regressioni realSDK1PASS/4FAIL prima del wiring Service/VM. Secondo interleaving concreto: il replacement SDK avviava bootstrap su expiredA nella nuova generation, poi sovrascriveva loginB; red1FAIL con quattro assert, fix svuota/verifica prima di creare la generation interattiva. Bootstrap ordinario e refresh normale restano validi. Delete/readback fallito è errore fail-closed in processo; il test non dichiara completato un logout durabile se l’item non è stato effettivamente cancellato.
3. Review indipendente APPROVED su quattro file e326hash. Release ha poi esposto7warning nuovi (un weak capture e sei accessi client cross-actor) corretti nel provider, con due supplementi APPROVED. Nessun global actor override, campo unsafe, consumer refactor, SDK upgrade/fork, schema/API pubblica/business o auth-scope change. Due full intermedie1397/0/36 conservate sui propri fingerprint, non usate per provare il sorgente finale.
4. Freeze finale326file `0fa8c144b61cc0fccc72218b0368735b0196ae75dc12f6900dc5f52fda6580eb`: mirati55 unici =54PASS/0FAIL/1SKIP (20 SDK,1scope locale,3config con live preflight skip,31 import). Release Automatic canonica senza config PASS, zero diagnostic Swift/source; strict firma ed effective Simulator entitlements uguali al profilo generato da Xcode. Full canonica finale **1397 PASS / 0 FAIL / 36 SKIP**, totale 1433 unici (1389 unit/integration + 8 UI), nessun retry/restart/esclusione. Analyze fresca PASS:26 diagnostic storici,0 nuovi. Signed TEST separato con sola config origin immagini autorizzata: strict/effective entitlements PASS, config semanticamente uguale dopo processing binary-plist Xcode, copia ignored rimossa e primary hash invariato. Il [manifest R-I05](EVIDENCE/TASK-144/ri05-auth-lifecycle/final-gate-manifest.json) lega log/hash/receipt al freeze.
5. Precondition Files sul solo simulatore executor17: prima probe privata con titolo inglese FAIL perché Files standalone usava Recenti; tree prova Recenti già selected. Label osservata corretta nella sola probe privata e1PASS. Nessun reset dati/preferenze, modifica locale o assertion app/UItest. Nessuna installazione sul device del coordinatore.

**Limiti:** CI exact-SHA e integrazione sono del parent, accettazione autenticata e misure launch della lane/coordinatore. Nessun DONE dalle sole prove locali. Il manifest finale distingue codice, full canonica, artifact configurato, storia e criteri live residui.

**Check obbligatori — snapshot R-I05:**
| Check | Stato | Evidenza |
|---|---|---|
| Build Release Automatic | ESEGUITO | Senza config, firma/effective entitlements PASS; TEST configurato separato. |
| Analyze | ESEGUITO | Fresh26 diagnostic preesistenti (18 Vendor + 8 Swift test),0 nuovi. |
| Warning nuovi | ESEGUITO | I 7 nuovi R-I05 corretti e riapprovati; toolwarning AppIntents e runtime QoS storici conservati. |
| Coerenza planning R-I04/R-I05 | ESEGUITO | Cambi circoscritti,20 SDK reali e31 import PASS; contratti business invariati. |
| Criteri globali / R-I06 | NON ESEGUITO integralmente | Nuovo timestamp History concreto pianificato dal parent dopo questi gate; live/CI/launch/integrazione restano separati. |

**Handoff:** R-I04/R-I05 LOCAL_VERIFIED / SOURCE_APPROVED sul proprio snapshot0fa8. Il nuovo R-I06 è il batch attivo seguente: questi artifact restano storici e non sono promessi come candidato finale. Nessun DONE.


### R-I04 — import XLSX con namespace, parent 2026-09-28

CA08 attraverso il picker normale sul bundle092 ha rifiutato il workbook condiviso contrattuale (stesso SHA Android verificato) come barcode assente. La prova Foundation sullo sheet reale conferma XML valido con8righe/64celle prefissate x:, ma il parser applicativo senza shouldProcessNamespaces confronta solo i nomi non prefissati e non raccoglie righe. È autorizzata dal mandato corrente la regressione dedicata sul decode ZIP/XML reale e la correzione minima del reader esistente, senza cambiare fixture/oracolo o riattivare l'harness Excel sospeso. R-I03 resta verificato (full1374PASS, livecard/diagnostics/restartPASS); PR11 è draft durante il nuovo fix. CI d217 rimane evidenza di quel commit e non può validare il futuro delta import.

### Esecuzione — R-I03 diagnostica corrente, 2026-09-28

**File modificati:**
- `OptionsView.swift` — diagnostica legata a risultato e orario canonici; account/shop correnti verificati con getter senza effetti collaterali; errore cloud generico distinto dai permessi.
- `Task118AutomaticDomainTests.swift` — 6 regressioni runtime su errore, tempo e scope, inclusa invariabilità delle preferenze.
- `OptionsLocalDatabaseCloudStatusTests.swift` — 2 regressioni: tre trigger di fallimento generico e precedenza auth/device/offline.
- `SupabaseManualSyncReleaseUITests.swift` — solo delimitatore della sezione sorgente aggiornato alla visibilità internal del test seam; asserzioni conservate.

**Azioni ed evidenze:**
1. Riprodotta la diagnostica storica: 0 PASS / 6 FAIL. Dopo fix, 123 PASS; rifinitura della scheda cloud riprodotta 12 PASS / 1 FAIL, poi mirati integrati **136 PASS / 0 FAIL / 0 SKIP**. Review indipendente APPROVED su tutti i 4 hash; nessun finding aperto.
2. UI/UX intenzionale: gli errori generici non implicano più un problema di permessi; si riusano titolo/dettaglio già tradotti IT/EN/ES/ZH. Autenticazione, dispositivo bloccato, offline, stato allineato e policy di retry restano invariati. Nessuna modifica recovery/auth/backend.
3. Prima full R-I03 preservata: **1371 PASS / 1 FAIL / 36 SKIP**. L'assert del titolo Recents falliva perché il picker Files ricordava Browse > On My iPhone dopo il probe normale CA-08. Il video prova UI inglese e apertura corretta del picker. Ripristinato Recents dalla UI normale solo sul simulatore executor: test canonico invariato **1/1 PASS**, senza reset, edit preferenze, esclusioni o indebolimento assert.
4. Full finale sul nuovo fingerprint: **1374 PASS / 0 FAIL / 36 SKIP**, totale 1410, con 1366 unit/integration e 8 XCUITest; nessun retry/restart. Release firmata Automatic canonica, analyze e scan sensitive PASS. Nuovi warning statici: 0; precedenti warning e skip restano documentati. Il runtime warning QoS nel test SyncEventIncrementalDomainApplyServiceTests resta riportato nel summary ufficiale, senza soppressioni. [Manifest R-I03](EVIDENCE/TASK-144/ri03-current-diagnostics/final-gate-manifest.json).
5. Nuovo bundle TEST separato dal precedente, con sola configurazione immagini già autorizzata. Firma/effective Simulator entitlements verificati, nessuna lettura token e nessuna installazione sul device live da executor. Receipt e fingerprint nel manifest; collaudo autenticato appartiene al coordinatore.

**Check obbligatori:** build Release ESEGUITO; analyze ESEGUITO; warning nuovi ESEGUITO (nessuno introdotto); coerenza planning ESEGUITO; criteri locali ESEGUITI con limiti live e CA-08/09 invariati. I benchmark core invariati non sono stati ripetuti. Fonte, red/green, prima full fallita, ripristino UI e gate finali sono separati nell'evidenza. CI exact-SHA del nuovo commit resta esterna; nessuna dichiarazione DONE.


### Addendum diagnostica runtime — parent, 2026-09-28

Dopo Google reale/restart riusciti sul bundle347b, Options mostrava keyNotFound(catalog) vicino al nuovo orario Retry. Il confronto selettivo delle preferenze ha attribuito il messaggio al vecchio `automatic.lastError` (write/clear DEBUG-only), mentre il risultato Release corrente è `deviceNotActive`, senza nuova recovery avviata. Lo scope UI deriva inoltre da un watermark storico. Nessun nuovo errore decoder R-I02 provato. Autorizzato nel mandato corrente un fix minimo di presentazione con test rosso/verde su precedence, tempo e scope; reviewer indipendente separato. Nessun reset preferenze/dati o bypass autorizzazione. Snapshot durante il fix: PR11 riportata draft e CI5dbcb6e7 cancellata perché superata dal nuovo delta, non contata PASS. Il delta R-I03 finale è ora SOURCE_APPROVED / LOCAL_VERIFIED, full1374PASS/36SKIP; il parent pubblica il commit e verifica CI/merge/main prima dell'integrazione.

### Addendum — R-I02 e crash CI97b6, 2026-09-28

- Contratto checkpoint short-envelope riprodotto: 6 casi nuovi contro sorgente invariata, 2 PASS / 4 FAIL per `keyNotFound(catalog)`. Envelope scoped prima del DTO ready: 48/48 PASS nelle due suite recovery/contract. Review ha trovato lo stesso caso nel marker finale; riprodotto 1 PASS / 2 FAIL per `catalog=null`. Il batch finale copre entrambi i punti e conserva i controlli strict del successo, il journal e il binding. [Evidenza R-I02](EVIDENCE/TASK-144/ri02-checkpoint-denial/README.md).
- CI97b6 ha terminato con crash runtime nel test filesystem, non con una semplice assertion. Riprodotto isolato su iOS26.2 con compiler Xcode27: stack `TaskLocal::StopLookupScope` / `swift_task_deinitOnExecutorImpl` durante deinit dello storage a fine test sincrono. Minima correzione test-only `async throws`, assertion errore conservata e rafforzata; Storefront 29/29 PASS sul runtime26.2 senza restart. [Prova e stack](EVIDENCE/TASK-144/ci97b6-runtime26-2/README.md). Nessuna modifica allo storage applicativo.
- I 1355 PASS / 36 SKIP precedenti restano uno snapshot storico. Dopo re-review APPROVED, full finale nuovo batch: **1366 PASS / 0 FAIL / 36 SKIP**, totale 1402; 1358 unit/integration + 8 XCUITest, nessun retry/restart/esclusione o runner locale concorrente. Release e analyze PASS; 8 warning Swift unici preesistenti emessi per 2 architetture, nessuno nuovo; i 18 Vendor storici non sono risolti dal silenzio della cache incrementale. Scan e fingerprint separati nel [manifest finale R-I02](EVIDENCE/TASK-144/ri02-checkpoint-denial/final-gate-manifest.json). CI exact-SHA finale resta competenza del coordinatore.
- La sessione della build TEST Release originale non sopravvive al rilancio nella prova del coordinatore. Artefatto originale senza signing: strict fallita, entitlement Simulator assente; probe su item Keychain sintetico isolato restituisce -34018. Nuovo Release con firma Automatic canonica e profilo Simulator generato da Xcode: strict PASS, add/read dopo terminate+relaunch/delete = 0. Bundle consegnato al coordinatore per login reale/restart/discovery, senza installare sul suo device. Nessun cambiamento a auth storage/produzione, gruppo Keychain o lettura di token. [Receipt](EVIDENCE/TASK-144/ri02-checkpoint-denial/signed-test-artifact.json).

### Esecuzione — 2026-09-28

Log dettagliato e file modificati: [ios-execution.md](EVIDENCE/TASK-144/ios-execution.md). Baseline e checkout primario preservati; sorgente applicativa congelata con [manifest](EVIDENCE/TASK-144/ios-source-manifest.json).

- F01/F03 counterpart e F02 riprodotti rossi, poi corretti con journal atomico separato da cache e ownership generazione/scope.
- F05 input mentre ACK è sospeso: XCUITest rosso→verde; UI/UX intenzionale, campi temporaneamente disabilitati durante load/mutation/adoption per impedire perdita input, senza redesign.
- Review indipendente: solo R-I01 iOS, batch fix e guardia scope riapprovati; nessun P0/P1/P2 aperto nel sorgente.
- Gate finale mirato: 46 unit/integration  + 4 XCUITest = 50 PASS  / 0 FAIL / 0 SKIP sul codice finale. UI usa componenti SwiftUI reali nel DEBUG harness sintetico; non è Database live autenticato.
- Prima full: 1353 PASS /1 FAIL /36 SKIP. Runner precedente ha chiuso il simulatore durante il test prezzi da 30k; SIGTERM, poi restart dei casi restanti. [Causa osservata](EVIDENCE/TASK-144/full-first-runtime-failure.md). Caso invariato ripetuto isolato: 1/1 PASS. Full sequenziale sul codice finale: **1355 PASS / 0 FAIL / 36 SKIP**, totale 1391 casi unici (1347 unit/integration PASS + 8 XCUITest PASS), nessun retry/restart e nessun runner/build concorrente. [Summary ufficiale](EVIDENCE/TASK-144/full-final-summary.json).
- Build Release e analyze finali PASS; 4 plutil PASS. 26 warning analyze: 18 vendor + 8 Swift preesistenti o esposti su codice invariato; [prova causale Task119](EVIDENCE/TASK-144/warning-provenance.json).
- Benchmark core XCTest separati: D100-L con 12k prodotti / 48k prezzi, 2/2 PASS; preview 5.147 s, prezzi 82.485 s (n = 1), nessuna misura UI/rete. Durable draft n = 30: p50 1.156 ms, p95 1.367 ms, max 2.597 ms. [Metriche](EVIDENCE/TASK-144/synthetic-benchmarks.json).
- Compatibilità Xcode27 separata in 24 file test, assert/gates invariati, commit coordinatore 4575eefb; nessuna modifica isolamento runtime/dipendenze. [Rationale](EVIDENCE/TASK-144/xcode27-compatibility/README.md).
- Canonical sensitive scan app/tests/contracts/workflow e scan nuove evidence PASS; ID simulatore redatto. Nessun deploy/nuovo account/reset dati, né harness Excel sospeso riattivato.

### Matrice CA — perimetro locale dell'executor

| CA | Stato locale | Evidenza / limite residuo |
|---|---|---|
| CA-01 | ESEGUITO baseline/worktree; NON ESEGUITO commit finale/CI da executor | Baseline 30d226d0 e hash sorgente; coordinatore possiede commit/PR/CI exact SHA. |
| CA-02 | ESEGUITO — VERIFIED locale | Persistenza fallibile, migrazione, nuova istanza/cache eviction,2 prodotti × 3 scope, ACK/restart/disk failure/conflitto; live mobile separato. |
| CA-03 | ESEGUITO — VERIFIED locale | 6 test deterministici  + XCUITest rapido filtri e stato loading/Tutti; controparte Android coordinata. |
| CA-04 | ESEGUITO — VERIFIED locale e contratto staging | Tutte le 5 operation, identity, ACK perso / B, TTL, no-op e ricezione C; SQL 12/12 del coordinatore distinto da perdita HTTP reale. |
| CA-05 | ESEGUITO dal coordinatore | Master/TASK143 parent-owned, stati storici e gate fisici preservati; non inferire distribuzione da merge. |
| CA-06 | ESEGUITO matrice fonte/test/limite | Tabella capacità nell'evidence; VERIFIED locale, EXTERNAL_DEPENDENCY live/hardware, NOT_TESTED manuale dove dichiarato. |
| CA-07 | ESEGUITO locale; NON ESEGUITO live da executor | Test sync/outbox/paging/no-op e scope; R-I06 actual recovery `.305Z` attiva con raw ledger/Date persistito, mismatch normalizzato rifiutato,57 mirati PASS. EXTERNAL_DEPENDENCY collaudo autenticato Android↔iOS owner separato, nessuna promessa di 3 s. |
| CA-08 | NON ESEGUITO integralmente; import normale R-I04 e regressioni ESEGUITI | Due XLSX tramite Files normale, export 5 prodotti, reimport no-op sette tabelle uguali sullo snapshot R-I04; quattro hash sorgente/fixture attuali match,31 import PASS anche nella full R-I05. Camera/upload reale esterni e harness Excel sospeso resta skip. Raw/tmp R-I04 mancanti esplicitamente storici. |
| CA-09 | NON ESEGUITO integralmente; misure core ESEGUITE | n = 30 draft + n = 1 S100-E/F, dataset/condizioni espliciti; nessuna misura di background/force-stop/convergenza live. |
| CA-10 | ESEGUITO gate locali finali R-I06+oracle; CI finale esterna | Supplemento test-only full1403/0/36,1439unici (1395 unit/integration+8 UI), mirati58/0/0 e45vettori reali dentro1XCTest; Release/analyze/TEST PASS,0warning nuovi, fingerprint3263c1ff005 e riconto ufficiale indipendente parent. Analyze incrementale0source non dichiara risolta baseline26. App207 hash invariati,22Release/23TEST bytes identici a41eb. R-I06 full1402/0/36 e R-I05 full1397/0/36 sono snapshot precedenti preservati. |
| CA-11 | ESEGUITO review/fix/re-review R-I04/R-I05/R-I06+oracle; integrazione PR/CI al parent | History APPROVED e supplemento oracle test-only APPROVED con0finding; unico test delta da41eb, fixture shared45 exact e auth4/app207hash identici. Gate locali sullo stesso3c1ff005. Parent integra/verifica exact SHA/CI e merge autorizzato; nessun DONE per inferenza. |
| CA-12 | ESEGUITO evidence iOS; NON ESEGUITO report coordinato da executor | Manifest e limiti espliciti; parent integra report complessivo/live/PR. Nessuna dichiarazione DONE. |

## Review

Review indipendente e re-review completate: sorgente APPROVED, nessun P0/P1/P2 aperto dopo R-I01, R-I02, R-I03 (diagnostica e scheda generale) e la correzione test-only del crash runtime26. Gate locali finali PASS, prima run interrotta conservata. [Rapporto indipendente](EVIDENCE/TASK-144/independent-review.md). Approvazione tecnica distinta da review GitHub del maintainer e accettazione autenticata.

## Fix

R-I04: cinque reader XML elaborano namespace; fixture condivise real ZIP/XML e tre regressioni APPROVED. R-I05 (P1): sessioni/eventi/completion e storage SDK recintati per generation; cleanup verificato prima della rotazione/interazione, client foreground/background condiviso e snapshot thread-safe. Venti test SDK reali, mirati54/0/1 e full1397/0/36 sul fingerprint0fa8, tre review/supplementi APPROVED. [Evidenza e limiti](EVIDENCE/TASK-144/ri05-auth-lifecycle/README.md).

R-I06: History ammette legacy esistente oppure UTC esatto a tre cifre frazionarie con calendario valido; ledger/digest conserva stringa originale, Date materializzato/readback `.305` verificato. Prezzi/UTC6/outbound/model/fingerprint e SDK auth invariati; nessun dato reale riscritto. Rosso1FAIL prima patch,57 mirati PASS, review indipendente APPROVED e full finale1402/0/36 sul fingerprint41eb; Release/analyze e signed TEST separato verificati. [Manifest e limiti](EVIDENCE/TASK-144/ri06-history-timestamp/final-gate-manifest.json). Questa approvazione locale non equivale alla chiusura globale/live.

R-I03 (P2): errore e timestamp derivano dal risultato canonico corrente; scope visibile da owner autenticato e shop risolto, senza side effects. La scheda cloud distingue fallimenti generici da reali permessi/auth. Sei test diagnostica e due card aggiunti; red/green e due approvazioni indipendenti nel [manifest](EVIDENCE/TASK-144/ri03-current-diagnostics/manifest.json). Nessuna modifica recovery/auth/retry e nessuna assertion indebolita.

R-I01 (P1): due test rossi hanno riprodotto ricevuta A non consolidata prima di leggere C. Il batch distingue ricevuta e stato corrente, consolida atomicamente A, ribasa B su A prima del conflitto e rende la base disponibile all'editor; retry identico adotta C, delta solo prezzo preserva nome C al reapply. Errore disco conserva l'intent precedente. Guardia finale scope protegge anche readback che termina offline dopo cambio shop. Re-review limitata APPROVED;46 unit + 4 UI finali PASS.

## Handoff

**CURRENT — INTEGRATED / CI_VERIFIED, task FIX, non DONE.** PR11/main `2322c5e1` e CI esatte head/main PASS; Android PR11/main `0613339f` con CI1.033 PASS/7 SKIP verificata separatamente. Auth nativa PASS nel relativo snapshot; recovery business ancora HTTP500/SQL57014 nella verifica finale anche dopo registry151, convergenza e misure ancora aperte. Il ledger e la nuova Execution prevalgono sui riferimenti futuri degli snapshot sotto. Nessuna distribuzione produzione o chiusura globale inferita.

**R-I06 supplemento oracle3c1ff005: LOCAL_VERIFIED / SOURCE_APPROVED — non DONE.** Full1403/0/36,1439identifier unici,58mirati PASS e45vettori iOS dentro1XCTest. Review indipendente APPROVED; parent ha ricontato official xcresulttool/tutti326hash. App207hash invariati e fixture b5848df0… exact; Release/analyze/TEST PASS,0nuove diagnostiche. Analyze actual incrementale0source distinto dalla baseline storica26; QoS/36skip preservati. Tutti22Release/23TEST artifact hash byte-identici ai precedenti41eb, firma/config/cleanup verificati dopo nuove invocazioni. [Manifest finale corrente](EVIDENCE/TASK-144/ri06-shared-oracle/final-gate-manifest.json), receipt/bundle `test-builds/ios/signed-ri06-oracle`. CI/workflow, integrazione exact-SHA, launch e live al parent/coordinatore. Nessun altro heavy job in corso da executor.

**R-I06 snapshot41eb precedente al supplemento test-only: LOCAL_VERIFIED / SOURCE_APPROVED — non DONE.** Full1402/0/36,1438identifier unici e57mirati PASS; Release/analyze/sensitive source PASS,0warning nuovi. Parent ha ricontato official xcresulttool e tutti326hash. Artifact canonico non configurato binaryf7816722… e signed TEST finale binary4a708a47… separati; primary config invariata e copia ignorata rimossa. [Manifest finale](EVIDENCE/TASK-144/ri06-history-timestamp/final-gate-manifest.json). Integrazione exact-SHA/CI, launch benchmark e collaudo live al parent/coordinatore; nessun nuovo heavy job o operazione sul simulatore performance da executor.

**R-I04/R-I05 snapshot0fa8 storico: LOCAL_VERIFIED / SOURCE_APPROVED — non DONE e non candidato corrente.** Full1397/0/36,55 mirati54/0/1, Release/analyze/scan sorgente PASS; signed TEST binary78bac59b… e artifact canonico19e99c… separati e conservati, firma/effective entitlements verificati. Il [manifest](EVIDENCE/TASK-144/ri05-auth-lifecycle/final-gate-manifest.json) contiene fingerprint326 e receipt di quel codice precedente. R-I06 è il delta successivo: per gate e candidato correnti usare il manifest3c1ff005 sopra; gli artifact0fa8 non ne provano CI/launch/live.

**R-I03: LOCAL_VERIFIED / SOURCE_APPROVED — non DONE.** Full finale1374/0/36, mirati136/0/0, Release/analyze/scan PASS nel [manifest R-I03](EVIDENCE/TASK-144/ri03-current-diagnostics/final-gate-manifest.json). Fingerprint325file `44adf90701d3336815a071f34fdc1fc5e4a4fb0d6ef543bf1c706c3a29807c9b`; bundle signed finale e source receipt separati. Precedenti R-I02/crash CI sono snapshot storici verificati. Gate finali nuovi completati nel [manifest R-I02](EVIDENCE/TASK-144/ri02-checkpoint-denial/final-gate-manifest.json); commit/CI exact SHA e accettazione mobile autenticata restano separati. Snapshot storico al commit97b6: [Manifest precedente](EVIDENCE/TASK-144/ios-gate-manifest.json); [precedenti casi unici](EVIDENCE/TASK-144/full-final-test-cases.json); [skip e motivi](EVIDENCE/TASK-144/full-skips.json).

- Parent ha integrato PR11 e verificato CI sugli esatti head e main; commit compatibilità `4575eefb` resta storico separato. Nessun commit/push dell'executor.
- Primo full fallito per shutdown del simulatore richiesto da precedente runner; prova preservata, nessun difetto applicativo attribuito senza evidenza. Full storico 97b6 senza restart sul fingerprint `3d33a15ce689a1aeb7b64082c249ef3a921a1816c520a228f9b475f8ea905d7d`.
- Fingerprint snapshot R-I02 al commit5dbcb6e7: `9f1d274203133bdef7baac3af73aae95955fedd10ce280e5cbd81b5f3cf10a2d`, 325 file app/test/resource verificati identici dopo i gate. I conteggi e hash precedenti sono snapshot storici, non il nuovo batch.
- 36 skip: 29 live/esterni, 4 benchmark sintetici opt-in (due richiesti eseguiti separatamente), 2 harness Excel sospeso, 1 camera fisica. Non trasformarli in accettazione live.
- Build TEST con configurazione publishable autorizzata dal parent distinta dagli artifact Release senza config: output correnti `test-builds/ios/signed-ri06-oracle` e `evidence/ios-ri06-shared-oracle`, source3c1ff005/firma/config/cleanup verificati; copie precedenti41eb conservate. Artifact e raw/tmp dei batch precedenti mantengono la propria provenienza storica. Nessuna installazione su device altrui da questo executor; sessione/app-auth e verifica bidirezionale sono owner del coordinatore live.
- Nessun XCTest esistente attiva semplicemente l'app installata senza fixture; i veri target UI esistenti usano DEBUG harness. Lo script legacy `tools/sim_ui.sh` non è un probe XCTest ed è deprecato. Nessun nuovo probe tracked/target CI introdotto. Dopo i gate, copia privata del probe coordinatore autorizzata soltanto in /tmp e sul simulatore executor per i residui CA-08, senza app fixture override.
- Restano EXTERNAL_DEPENDENCY il collaudo autenticato Android↔iOS, gli stati background/sospensione/force-stop, permessi/upload reali e giudizio hardware/VoiceOver. Il parent mantiene separati codice, integrazione, runtime locale, live e distribuzione.

### Coordinamento e pubblicazione — parent

Matrice completa: [functional-matrix.md](EVIDENCE/TASK-144/functional-matrix.md). Rapporti comandi, casi, hash e limiti sono versionati; il rapporto aggregato esterno `MERCHANDISECONTROL_MOBILE_PARITY_ROOT_CAUSE_RESULT.md` registra SHA/PR/CI finali senza commit autoreferenziali. Le PR possono essere integrate indipendentemente sul contratto backend esistente; nessun deploy/migrazione prerequisite.

Il consenso diretto dell'utente al coordinamento con «Completa attivazione WECHAT-010» è stato verificato. I suoi dispositivi restano separati: quella lane possiede installazione senza reset, autenticazione e collaudo live; questa lane possiede sorgenti e build native. Nessun test live viene dichiarato PASS prima della relativa ricevuta. Snapshot pre-push del nuovo batch: NOT_MERGED / NOT_DEPLOYED. Il mandato coordinato diretto autorizza commit/push/PR/merge normale; il parent verifica review e CI sullo SHA esatto, poi main/CI post-merge. Stato corrente remoto nel report aggregato, senza commit autoreferenziali. Nessun DONE finché restano i limiti documentati.
