# TASK-144 — Mobile parity root-cause ios

## Stato

- File task: `docs/TASKS/TASK-144-mobile-parity-root-cause-ios.md`
- Stato: `FIX`
- Fase: `FIX`
- Responsabile: `CODEX_EXECUTOR_IOS`; orchestratore parent, reviewer indipendente separato.
- Data: 2026-09-28
- Baseline: `30d226d0fb9b8679a1dd034c6e82319645337f22`
- Branch corrente: `codex/ios-incremental-sync-state` da PR13 HEAD `414c4a34`; R-I08 in diagnosi RED, R-I07/main e prove precedenti preservati
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

### Addendum planning autorizzato — R-I07 validazione persisted recovery, 2026-10-02 UTC

La recovery reale su TEST registry154 supera checkpoint A e B e scarica sei domini/61.598 righe, poi termina il 2026-10-02 alle15:20:24.892399Z con `nonMonotonicOrDuplicateID`. Active generation e finalization assenti; binding invariato, journal/pending e staging preservati. I sei ledger raw hanno conteggi uguali agli ID unici e ordine UUID lowercase UTF8 rigoroso, senza errori. Ricevuta pubblica parent `native-checkpoint-registry154-safe-projection.json`, SHA256 `6e2992bde50f96a7d171345bb87b7ebc7fd6fb56247c4c565f8c10867fc40719`. Non è ancora identificata la causa: la enum copre anche proof shape e ordine della rilettura SwiftData.

Il parent autorizza nello stesso CA-07/10 una diagnosi e regressione deterministica su SwiftData a disco, percorso reale persisted proof, ID sintetici sensibili a comparatori UUID/String e confini del batch256. Nessuna modifica produzione prima del rosso. Se il difetto è confermato, applicare il cambiamento minimo di ordinamento canonico mantenendo strettamente duplicati, ID mancanti, digest/contenuti, scope, tombstone, immagini, pagina/ledger, limite righe e memoria bounded. Vietati sort/dedup del wire per nascondere payload invalidi, materializzazione globale non giustificata, migration/model/schema/dependency change, reset dati e retry ciechi. Review indipendente e gate aggiornati, nuovo artifact TEST firmato e installazione data-preserving coordinata precedono il ritest reale. I precedenti source326/CI e signed4a708 rimangono evidenze storiche distinte dal delta futuro.

### Addendum planning autorizzato — R-I07 regressione del runner sincrono, 2026-10-02 UTC

PR13 HEAD fabae1e5, run37031063547, checkout esatto verificato: 1404 PASS /36 SKIP /1 crash del nuovo testDiskBaselineLexicalComparatorPreservesAllCatalogTypesAcrossBatches; Analyze e Secret scan SKIPPED. Il test del servizio reale257 PASS e i1439 casi precedenti hanno stato invariato. Il crash allocator non dimostra un nuovo difetto produzione né un ambiente flaky. Il controllo è l'unica entry sincrona di34 nella classe MainActor; il precedente CI97b6 e la riproduzione iOS26.2 salvata mostrano la stessa firma, stack TaskLocal isolated-deinit e soluzione async. Il raw stack attuale non è ancora disponibile; i vecchi raw tmp non sono più presenti, solo stack/ricevute leggibili e log CI verificati.

Il parent autorizza un solo test isolato invariato su destinazione propria iOS26.2 già disponibile, esclusivamente dopo GO host; conservare summary/log/ips eventuale e shutdown effettivo. Se il crash è riprodotto e coerente, aggiungere soltanto async alla firma del controllo, senza cambiare corpo,771 righe/batch256/assert/strict guard, production comparator o actor settings. Eseguire lo stesso test e la classe/contratto sullo stesso runtime, review indipendente e nuova CI completa exact-head. Non saltare/rimuovere il controllo o aggiungere empty deinit/fake/ retry per mascherarlo. Se il rosso non si riproduce, documentare il limite prima di scegliere la modifica minima sostenuta dalla prova esistente; nessuna attribuzione causale definitiva dal solo log allocator. Nuovo source freeze e artifact/provenance firmata devono essere distinti dal precedente230ddb/f7f25/050db; non riscrivere ricevute storiche o reinterpretare74d come nuovo runtime.

### Addendum planning autorizzato — R-I08 continuazione automatica dopo delta valido, 2026-10-02 UTC

R-I07/async restano separati e approvati sul source3269b427570, branch PR13 HEAD414c4a34 e CI37042285072 in corso. Diagnosi source-only26file, receipt9efb92732095f4397593ca846ed8154b9b8bbe74e5fb36c804a8ec63633ddb8d, identifica un P1 CA-07/09 diverso dall’Android: un ordinary drain valido avanza la durable fence V6, ma AutomaticSyncEngine restituisce verifiedConvergence=false. SyncStateStore trasforma success/noWork in recoveryRequired; SyncOrchestrator sopprime poi i trigger automatici. Il drain non crea il journal necessario al resume e Retry esegue full recovery. Il percorso normale conteggia correttamente i prezzi con parent attivo; il fallback price-parent tombstoned resta distinto, senza attribuzione al primo finding.

Il parent autorizza sul checkout isolato ios-incremental-sync, branch codex/ios-incremental-sync-state da414c4a34, prima soltanto test reali a disco: recovery atomic completa e journal risolto→vero pull/domain service/engine/state/orchestrator→due eventi ordinari sintetici in sequenza e readback, senza releaseCard/full snapshot/manual Retry. Il secondo trigger deve poter applicarsi nel medesimo account/shop/generation dopo un primo delta valido; conservare lastVerifiedAt e verifiedConvergence=false quando non esiste nuova prova globale. Nessun generic success/fake marker deve diventare consenso o prova forte. Rilancio/validfence/watermark e assenza journal verificati separatamente.

Produzione immutata prima di RED ufficiale; preparazione può procedere senza runner, che richiede nuovo GO host. Dopo RED, proporre il minimo confine tipizzato che distingue un delta ordinario applicato entro scope autorevole verificato da una vera necessità recovery, preservando mismatch/gap/unknown digest/dirty/pending/failure/no-baseline/account-shop-switch e fencing. Non impostare verifiedConvergence=true per far passare la UI né rimuovere generic recoveryRequired o i controlli esistenti; nessun secondo motore/schema/dependency/SDK upgrade. Test118/119 che coprono successo senza prova restano validi; ogni cambiamento intenzionale di un comportamento desiderato va motivato e deve aggiungere prova reale più forte. R-I07 artifacts/CI/prove non attribuiti al futuro R-I08. Reviewer indipendente, adiacenti, canonici/firma/CI e collaudo autentico/per-record prima di chiusura.


### Decisione planning R-I08 — prova tipizzata di continuazione, 2026-10-02 UTC

La review indipendente8b2f7bdb ammette un confine minimo solo con prova ristretta emessa dal vero domain apply dopo successo completo della sequenza bounded eventi/targeted/tail, container attualmente registrato e leaseGeneration Task126 correnti, assenza journal/pending/gap/dirty/unknown/cancel, e readback autorevole durable fence+watermark. Un flag capability o success scalar non basta. La prova deve attraversare summary→engine→result senza costruzione libera dai generici success e deve essere scartata su failure/cancel/stale/mixed scope.

Il consumer rivalida al momento della pubblicazione owner/shop/device/binding, lease della generazione attiva e fence/watermark nelle stesse defaults, senza journal. Non cancella un vero recoveryRequired o un pending latch durevole. Conserva verifiedConvergence=false e lastVerifiedAt originale; i generici unverified success/noWork dei test118/119 restano fail closed. Il primo delta event-advance può avere prova più stretta: un no-op/empty separato richiede guardie current-fence/stabilità/count e test reali, mai prova globale dedotta da vuoto o conteggi uguali. Guardie obsolete devono essere mostrate come stale prima dell'uso (cambio scope/device/lease/fence, journal intervenuto).

Nessuna produzione prima del RED funzionale ufficiale e conferma root; compile/setup/race failure non è RED. Test e runtime devono mantenere i rifiuti esistenti, più due delta ordinari e fresh-open reali. Il fallback prezzi con parent tombstoned resta fuori da questa correzione. Nessun secondo motore/schema/registry/dependency; review della patch immutabile, GREEN/adiacenti, gate finali/firma/CI e accettazione autentica restano distinti.

### Decisione planning R-I08 — implementazione dopo RED funzionale, 2026-10-02 UTC

Il V4 a tre selettori ha eseguito il percorso reale a disco con produzione immutata: ONE comando19:43:09.978632→19:43:39.635678 UTC, compilazione PASS, tre XCTest unici FAIL/0PASS/0SKIP. Nei due casi evento il primo runtime termina success/unverified con stock1/watermark42 e due lookup catalogo, ma lo stato diventa recoveryRequired e sopprime43; nel caso autonomo il primo runtime termina noWork/unverified, nessun lookup/stock0/watermark41, poi sopprime42. Journal assente, lastVerifiedAt invariato. La fixture invalidPage V2 rimane prova storica di setup distinta; V4 non presenta quell'errore. Rilascio19:43:40.069177, proprio gruppo6327 assente/signals[], dispositivo proprio effettivamente Shutdown (comando shutdown149, già fermo). La lettura indipendente ha confermato il RED funzionale; receipt e raw conservati in `red-attempt03`.

Il parent conferma l'implementazione minima del confine tipizzato già definito sopra, usando le API effettive dell'advisory `fe0e58953136aa5c59832f328e13aebc96e29bf1d0b27e9cd2761d2046a96d72`. Receipt a costruzione ristretta emessa soltanto dal domain reale dopo sequenza completa, commit/readback e guardie correnti; contesto di validazione legato al controller/container realmente registrato dalla composition, mai singleton assunto o capability booleana libera. È autorizzato un accessor interno read-only del record watermark validato per verificare insieme generazione e cursor, senza cambiare schema/chiavi/scritture. Consumer sincrono rivalida scope Task126, lease/container/finalization, generation-bound watermark/fence, journal e local work al momento della pubblicazione, conservando le guardie di cancellazione e senza chiamate ricorsive al lock di lease. Un vero recoveryRequired, preserveRecoveryRequired o journal durevole continua a prevalere.

Per il noEvents è accettato il costo mirato di una verifica fresca tramite endpoint reconciliation counts già esistente e di un tail bounded di stabilità, prima di emettere la variante ristretta stableNoEvents. La cache15s/lastAt, pagina vuota o conteggi uguali non autorizzano da soli la receipt. Dirty/pending/capped/unknown scope, drift, nuovo evento nel tail o cambio scope/fence/generation la impediscono. Non aggiungere endpoint/engine/schema/dipendenze e non chiamare questa verifica prova globale; misurare successivamente chiamate/tempi effettivi. La receipt attraversa summary/engine/result senza costruzione libera nei factory generici, è scartata su failure/cancel/partial/incompatible aggregate, e non cambia verifiedConvergence=false, lastVerifiedAt o proof version.

Conservare i34 Atomic precedenti e tutti gli assert generici118/119; aggiungere guardie stale owner/shop/device/lease/container/fence/generation anche con cursor uguale, journal/pending dopo issuance, missing/tampered/unfinalized/unregistered, count drift/nonempty noEvent tail, cancellation prima issuance/dopo commit/prima publication e late callback. I tre V4 restano i test desiderati del nuovo GREEN; nuovo freeze, review statica indipendente e GO prima del runner, poi adiacenti/canonici/firma/CI e collaudo autenticato. Il fallback prezzi tombstoned resta separato. Nessun DONE o prestazione~3s dedotta dal test sintetico.

### Precisazione planning R-I08 — pubblicazione sincrona e cancellation, 2026-10-02 UTC

La lease può essere invalidata anche dal percorso actor della recovery; il solo no-await dopo unlock non linearizza una notifica `@Published`. Autorizzato il cambiamento interno minimo di SyncStateStore: storage privato semplice, getter `state` compatibile e ObservableObjectPublisher esplicito; inviare will-change prima di acquisire la lease, poi rivalidare e assegnare il solo storage semplice nella sezione protetta senza callback/await. Nessun consumer di SyncStateStore usa `$state` nel codice/test attuale (il `$state` della ViewModel auth è distinto e resta invariato). Nel critical section non leggere il getter rivalidante né rientrare nel lock. Un getter per l'idle basato su receipt rivalida il contesto corrente e non espone come ammissibile una receipt invalidata; comportamento generico/full e assert118/119 preservati. Il reviewer verifica ordinamento, stale callback e osservatori che rientrano o invalidano la lease.

La cancellazione da verificare è quella del run originario, anche se il consumer è in un'altra Task. È autorizzato rendere leggibile sincronicamente la generazione della stessa AutomaticSyncCancellationPolicy mediante storage interno protetto, conservando actor, token e semantica esistenti; l'engine lega policy/token effettivi alla receipt dopo il finish single-flight e l'ultimo controllo. Una receipt emessa dal solo domain senza questo legame non autorizza StateStore. Verificare ordering/lock anche per cancellation concorrente e scartare proof stale, senza una nuova authority globale o booleani iniettati.

Per la validazione locale sincrona è autorizzato un helper read-only con query fetchLimit1 sui pending/outbox nonterminali o sconosciuti e sulle ref History dirty, usando gli stessi stati terminali dell'inspector esistente e fail-closed per scope non riconosciuto. Non introdurre flag updatedAt come prova di clean. Getter senza rete/await/scansione globale dei conteggi; issuer/consumer conservano la verifica necessaria dei dati committed. Materializzazione bounded non significa costo SQL costante. Questa precisazione riguarda sicurezza della pubblicazione e osservabilità interna, senza redesign UI o API backend.

### Precisazione planning R-I08 — sequenza self ACK senza targeted apply, 2026-10-02 UTC

Il ramo `eventIDs.hasWork == false` può avanzare regolarmente il cursor dopo aver classificato eventi self o notifica nota senza ID da applicare. Una receipt sempre nil in questo ramo conserverebbe lo stesso latch già riprodotto per i risultati ordinari. È autorizzata la stessa verifica ristretta fresca count/local-work/tail/generation/scope/fence dopo il normale status commit e readback del cursor avanzato, conservando eventsProcessed/skippedSelf e watermarkBefore/After effettivi; non trattare una pagina non vuota come EMPTY o nuova convergenza globale.

Solo eventi wire riconosciuti e classificazione completa senza blocker possono qualificare; le guardie esistenti su full-recovery, dominio/tipo sconosciuto, payload malformato, ID mancanti/cap e dirty restano prevalenti. Supported-domain da solo non autorizza un tipo sconosciuto. Errori del commit/readback, prefix incompleto, pending/outbox/journal, drift, tail non vuoto o cancellation impediscono la receipt. Coprire recovery reale→mutazione locale/push effettivo con ACK controllato→evento self→successivo evento remoto/noEvents attraverso engine/state, preservando generici118/119 e i blocchi del parser. È una variante del medesimo risultato unverified che creava il latch; nessun nuovo motore/backend/contratto o autonomia da un flag locale clean.

### Precisazione planning R-I08 — tipo wire della fixture ordinaria, 2026-10-02 UTC

Il controllo della fixture V4 ha rilevato nel nuovo helper ordinaryContinuationEvent il literal `catalog_updated`: il reader/classifier applicativo lo ammette e il V4 ha realmente applicato stock1/watermark42 prima del latch, mentre il writer canonico RecordValidator/RPCRequestMapper usa `catalog_changed` o `catalog_tombstone`. Conservare il V4 come prova del percorso applicativo accettato, senza descriverlo come evento canonico prodotto dal server. Il RED autonomo initial-noEvents41 non dipende da questo literal e conferma separatamente il medesimo latch.

Autorizzata per il nuovo GREEN la sola correzione del literal del nuovo helper a `catalog_changed`, con corpi/assert dei37 metodi invariati e nuova provenienza/hash; input/log/receipt RED originali immutabili. L'allowlist dei tipi wire riguarda soltanto l'eligibility della receipt ristretta: nessun alias nuovo nel writer, nessuna riscrittura generale dei parser/read/apply legacy per rendere verdi test. Tipo non riconosciuto non può emettere receipt. Documentare l'equivalenza statica del precedente apply rispetto al literal come inferenza dal codice, non come nuova esecuzione canonica; i GREEN devono eseguire veramente il tipo canonico e la sequenza noEvents41/43→evento44. Review del delta fixture e guardia negativa del tipo sconosciuto richieste.

### Decisione planning R-I08 — parità della generazione realmente finalizzata a cursore0, 2026-10-02 UTC

La review indipendente del freeze v1 ha rilevato un candidato separato non ancora provato a runtime: captureContinuationGeneration esclude watermark0 e il precedente FenceStore.scopeKey esclude0, mentre checkpoint/finalization/record WatermarkStore autorevole ammettono0. Il bootstrap considera l'assenza della baseline, non il solo cursore0; non è stata trovata una policy che imponga bootstrap dopo una vera recovery empty0 finalizzata. Il candidato rimane distinto dalle3FAIL V4 e dai guard generici fail-closed, che non si indeboliscono.

Prima di qualsiasi fix di produzione per0, autorizzati due nuovi test desiderati con actualfile-backed full recovery canonica empty0, finalization/journal/binding/generation e record typed/scalar effettivi, chiusura e riapertura: (1) normale noEvents0 con freshcounts/tail e nessuna targetedlookup resta idle/READY senza verifiedConvergence o avanzamento lastVerifiedAt; (2) primo evento canonico catalog_changed1 applicato da vero runtime/orchestrator senza bootstrap o latch seguito da altro trigger noEvents1. Fixture shop realmente vuoto, nessun evento bloccante artificiale o flag/fence/receipt scritti a mano. Passare dal vero service di recovery e normale remote controllato, rete reale bloccata come gli altri test; non sono acceptance autenticata. I53corpi/assert precedenti e raw V4/v1freeze restano immutabili. Testhelper nuovi o parametrizzazione esclusivamente dei helper nuovi con valori default che mantengano le fixture53 esistenti; nessuna modifica ai guard produttivi per ottenere RED.

Congelare namespace v2/test-onlydelta su v1, verificare tutti326file/inversa13source e53corpi, nuova review/card/launcher prima di un ONE batch pertinente con questi due selector inclusi. Una compilazione/setupfailure non vale come RED desiderato; occorre osservare finalization empty0/riapertura e fallimento nel successivo percorso ordinario. Solo allora proporre accesso read-only al fence0 verificato dalla vera generazione e receipt, mantenendo scalar default0 senza record e scope/container/lease/cancellation invalidi nel percorso fail-closed. Nessuna nuova chiave/schema/RPC/dipendenza o fonte d'autorità basata sul solo numero0.

### Precisazione planning R-I08 — failure reale della recovery empty0 distinta dalla fixture, 2026-10-02 UTC

Il producer ha identificato prima del runtime un ulteriore candidato produttivo concreto: il secondo checkpointB del vero AtomicGenerationRecoverySnapshotPullService passa checkpointA.maxId0 insieme al suo scopeKey non-nil; l'adapter esistente accetta soltanto (0,nil) oppure (>0,key valido), quindi rifiuta con scopeFenceMissing. La fixture full empty0 è ammessa da checkpoint/monotonic/finalization/typed watermark e non deve bypassare il service o l'adapter. I due test desiderati devono conservarne l'esecuzione reale e attestare lo stage: se l'officialFAIL è esattamente questo guard della chiamata reale dopo checkpointA canonico empty0, costituisce FUNCTIONAL_EMPTY_ZERO_RECOVERY_RED, mentre la successiva continuation non è ancora raggiunta. Rimangono NON RED le fixture malformate, la compilazione e setup indipendenti dal comportamento produttivo desiderato.

Dopo il RED e adjudication indipendente proporre soltanto il primo cambio necessario: allineare la richiesta checkpointB dal cursore0 alla coppia canonica (0,nil), preservando i controlli A/B/C scope/account/shop/device, monotonicità e canonical receipt, senza modificare il contratto adapter/RPC/backend né introdurre (0,key) non dimostrato. Il vero RPC incrementale già usa (0,nil) e non fallisce localmente sul reader del fence0; il suo fresh checkpoint resta soggetto ai controlli normali. Poi le stesse due regressioni devono effettivamente raggiungere activation/finalization/riapertura e il percorso ordinario, così da verificare separatamente l'esclusione0 del typed receipt e del solo accesso locale al fence. Nessuna patch di produzione per nessuna fase è autorizzata prima del relativo RED ufficiale; niente attivazioni simulate per aggirare il blocker.

### Decisione planning R-I08 — compile-only predicato outbox e capture warning, 2026-10-02 UTC

Il primo ONE mixed237 parte realmente21:03:58.780201 e termina21:04:12.844854/exit65, release21:04:13.313196; gruppo38545 assente/noSignals e simulatore proprio Shutdown confermato, source326/cache13 invariati. Officialsummary ha0test, quindi COMPILE_FAILURE_NOT_FUNCTIONAL_RED e nessun esito235/2. Il compilatore non riesce a typecheckare il predicato outbox SyncStoreGeneration1460; genericT1466 è cascata. Log872b2fcc/launcher02d1e981 preservati; nessun retry sul GO consumato, nessuna modifica funzionale ZERO autorizzata.

Autorizzata soltanto una riscrittura equivalente del predicato: array immutabile degli stessi sei raw status sent, blockedContract, blockedAuth, blockedSchema, dead, localOnly; #Predicate esplicitamente SyncEventOutboxEntry che seleziona !terminalOutboxStatuses.contains(entry.statusRaw). Sono identici alla congiunzione precedente per ogni stringa: unknown/malformed/case diversa e stati attivi restano selezionati e fail-closed; fetchLimit1 e pending/history guard invariati. Pattern captured String-array.contains è già presente in DatabaseView e API del SDK installato confermate staticamente; compilazione e traduzione SQL restano da verificare con gli stessi237 test, non dedotte dalla sola sintassi. Niente fetch completo, materializzazione outbox senza limite o nuova dipendenza.

Il log evidenzia inoltre quattro nuovi warning capture-self non-Sendable nei due MainActor.run aggiunti in DomainApply (786/791/815/819). Correggere nello stesso delta di compilazione con capture ristrette delle sole dipendenze immutabili già usate, preparate prima dell'await; preservare l'esatta istanza defaults e watermarkStore iniettata. Se necessario usare il box Sendable esistente per UserDefaults o un holder privato ristretto con motivazione, non sopprimere warning, annotare indiscriminatamente l'intero servizio unchecked, cambiare isolamento/SDK/build settings o ricreare un watermarkStore diverso dal parametro. Presentare il delta minimo e il contratto prima del freeze. Condizioni mint/consumer/generation/cancellation/authority e ogni guard ZERO >0/(0,nil) restano semanticamente invariati; questo è un fix di compilazione/capture, non il fix funzionale empty0.

Tutti55corpi/assert e i237selector restano invariati. Nuovi source326/card/request/launcher e review statica del delta equivalente precedono nuovo GO e namespace attempt02. I FAIL ZERO richiedono ancora A0/pages reali e guardB del service per la prima fase, poi continuation separata. Nessun test saltato o indebolito per ottenere il verde; task FIX e tutti gate successivi ancora aperti.

### Decisione planning R-I08 — chiamata fixture API reale, 2026-10-02 UTC

Il secondo ONE mixed237 compila il codice produttivo V3 ma fallisce nella compilazione dei test: AtomicGenerationRecoverySnapshotPullServiceTests258 chiama recoverSnapshot, metodo inesistente. Il servizio reale espone recoverFromRemoteSnapshot(ownerUserID:). Summary ufficiale1fda8115 contiene0test/unknown, logbe3a06b1 conserva il solo errore API e nessuno dei precedenti errori Predicate/cattura self; i quattro warning nuovi non ricompaiono in questo log. Non è un RED funzionale ZERO né235/237 test superati. Attestazione owner:21:31:39.735378→21:31:57.307080/release21:31:57.811244, PG51123 assente/signals[], solo6B049 Shutdown, source326/cache13 invariati. Nessun retry nello stesso GO50fce348.

Autorizzata esclusivamente la sostituzione della chiamata recoverSnapshot con recoverFromRemoteSnapshot nella nuova regressione testOrdinaryContinuationRejectsReplacementContainerAndOtherDefaults. Conservare argomento ownerUserID, await/throw, tutti55ID/assert, gli altri54corpi e tutti i vecchi37corpi. Tutti325altri file, intera produzione e i237ID/22selector restano byte-identici; nessun wrapper/alias API aggiunto, skip, timeout, indebolimento assert o fix funzionale ZERO. Conservare copie V3 e inverse patch esatta; preparare freeze/card/launcher V4 nel nuovo emptyattempt03, review indipendente statica prima di nuovo GO owner/direct ONE. Verificare anche le altre chiamate dei test nuovi sui simboli reali esistenti senza probe di compilazione non autorizzato. Compilazione dei test, SQL Predicate,235GREEN ordinari e due stage empty0 restano da osservare. Task FIX, nessun DONE.

### Decisione planning R-I08 — checkpoint B della recovery realmente vuota, 2026-10-02 UTC

Il ONE mixed237attempt03 reale21:47:16.214670→21:47:50.231420/release21:47:50.724199 compila il freeze b48 e produce237unici234PASS/3FAIL/0SKIP; source326/cache13 invariati, PG56182 assente/signals[]/ownShutdown. Adjudication indipendente5de5606e: i due nuovi ZERO sono autentico EMPTY0_RECOVERY_FUNCTIONAL_RED. A0 è richiesto con baseline0/keynil, poi tutte sei pagine dominio vuote reali; checkpointTransportCalls1, scopeFenceMissing, nessuna activation/finalization e journal conservato. Il prossimo checkpoint B non raggiunge il transport: service265 passa0+key, rifiutato dal guard adapter809; attribuzione locale sostenuta dal codice, nessuna rejection backend osservata. Continuazione ordinaria0 NON RAGGIUNTA. Gli altri due originali superano i veri percorsi42→43 e41empty→42→43→empty43→44, senza nuova fullverification o recovery.

Autorizzato soltanto nel caller AtomicGenerationRecoverySnapshotPullService.checkpointB: expectedBaselineScopeKey: checkpointA.syncEvents.maxId == "0" ? nil : checkpointA.scope.key. A è già strictcanonicalvalidato; ogni baseline positiva conserva la sua key esatta. Adapter/RPC/backend restano identici e continuano a rifiutare0+key. Tutta scope identity/lease/cancel/A↔B monotonicità/receipt/tail/staging/marker/finalization resta invariata; nessuno skip domain, nuova key/API/schema/dependency o marker-only proof. Non modificare ancora captureContinuationGeneration.watermark>0 né il getter locale scopeKey0 prima di reale activation/reopen e RED specifico del percorso ordinario0.

Il terzo test freshopen resta fallito: primo42 success/idle/wm42/stock1, dopo riapertura secondo43 blockeddeviceNotActive conwm42/stock1; inoltre strictlastVerifiedAt Date differisce nonostante identico epochDouble stampato. Source finding: restoreAuthoritativeRecoveryCheckpoint conserva typed watermark42 della stessa generation, ma AccountBinding.restoreFinalizedGenerationMetadata salva fence al fullfinalization41. È una causa candidata di produzione, non un permesso per resettare fake readiness. AccountBinding/Watermark/restore rimangono byte-identici finché manca la proiezione reale del fence dopo reopen.

Autorizzate sole osservazioni test-helper bounded numeriche/booleani prima/dopo reopen: cursor scalare e typed stessa generation, watermark del record fence validato e bool scopeKey al cursor corrente, fullManifest/finalization watermark, currentscope/generation/binding/device matches e risultato/errorCode senza chiavi/rawpayload. Nessuna scrittura aggiuntiva, auth/device re-ready, receipt/fence/binding injection, bypass lease o guard. Tutti55ID e assert dei test e i tre corpi originali restano invariati; helper observation deve permettere di distinguere typed42/fence41 da un generico deviceNotActive.

Per l'uguaglianza esatta del clock sintetico, StateStore conserva il Date live ma persiste timeIntervalSince1970 Double, poi ricostruisce Date da quell'epoch. L'offset2001↔1970 può perdere119ns nel passaggio Double; il log attuale non misura i bit di referenceDate, quindi è spiegazione sorgente, non delta runtime misurato. Autorizzato soltanto nei nuovi helper ordinary/ZERO a chiamare recordRunResult della vera recovery verificata con now: Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down)), secondo corrente esattamente rappresentabile in entrambi gli epoch. Conservare tutti gli assert strictDate/no tolerance, il risultato/proof reale e tutto il codec produzione; nessun timestamp business modificato o successo fabbricato.

Nuovo freeze/patch/inverse/test-helper invariance e card con i tre selettori ZERO2+freshopen, review statica prima di fresh25min/min19/reserve90/ONE owner DIRECT nel namespace nuovo. Conta3 è dichiarato, non GREEN: i ZERO devono prima dimostrare full0 activation/reopen e poi l'eventuale RED continuation0; freshopen deve mostrare il reale fence/stato senza restorefix. Source API compileaudit resta statico. Task FIX, gate full/Release/analyze/TEST/CI/live aperti.

### Decisione planning R-I08 — fence avanzato dopo riapertura e continuazione zero finalizzata, 2026-10-02 UTC

V5 ha eseguito realmente i3selector sul freeze470c/source326e192:0PASS/3FAIL, compilazione completata, ONE22:24:54.025385→22:25:31.693532/release22:25:32.242642, ownPG78919 assente/signals[], sorgenti/cache invariati. Receipt800403b4, summaryc10afe2c e testtree/log sono conservati in `evidence/ios-ri08-ordinary-sync-state/targeted3-v5-attempt01/`. Il caller B0/nil ha permesso entrambe le recovery vere a0:2checkpoint/6pagine, attivazione/finalizzazione e verifiedConvergence true, journal assente. Il primo delta0→1 applica la riga e conclude success ma non emette continuationReceipt: phase recoveryRequired e poll successivo soppresso. Il capture issuer esclude esplicitamente0; il consumer richiede il getter generico positivo. La riapertura osserva direttamente scalar/typed42 e fence42 prima, scalar/typed42 e fence41 dopo, stessa generation/fullfinalization41 e journal assente; il nuovo Facade blocca il delta43 prima del provider.

Il caso initialempty0 restituisce invece busy prima di count/tail: non è una prova funzionale del ramo noEvents zero. La diagnosi del lifecycle helper mostra che il catch del precedente ZERO chiama cancelAndWait (sospende processShared) senza resumeAfterStoreReplacement, a differenza del cleanup ordinary già corretto. Il bootstrap della nuova recovery usa un gate privato e riesce; il Facade ordinary usa il gate condiviso sospeso. È autorizzato aggiungere il corrispondente await resumeAfterStoreReplacement dopo cancelAndWait soltanto nei due exit success/catch dell'helper ZERO. Vietati reset iniziale, allentamento del gate, retry o modifiche delle asserzioni. Preservare il busy precedente come CONTINUATION_NOT_REACHED; il prossimo caso deve osservare freshcount e stabilitytail reali.

Sono autorizzati soltanto questi delta di produzione nello stesso task: (1) `AccountBindingStore.restoreFinalizedGenerationMetadata` mantiene il watermark effettivamente validato della stessa generation dopo il restore. Se è strettamente avanti rispetto alla fullfinalization, preserva soltanto il fence già valido per quel cursor e per lo stesso account/shop/device/scope; fence assente, corrotto o diverso fallisce chiuso, senza mint di authority dal solo scalar/typedmarker. A cursor uguale resta la riparazione dal receipt finale già fsynced. (2) Nel percorso tipizzato `SyncEventIncrementalDomainApplyService`, issuer e consumer possono usare0 soltanto con record tipizzato e mirror valido della generation corrente, container ACTIVE realmente registrato, finalization valida, managed lease/currentcontroller/scope/device e tutti i guard journal/localwork/cancel/readback esistenti. Se occorre, aggiungere un unico accessor read-only specifico di continuazione in `ShopSyncRecoveryFenceStore` che riusa validatedRecord e verifica la generation tipizzata; il getter generico scopeKey mantiene >0 e nessuna flag allowZero. Nessuna modifica a adapter, RPC, backend, route/bootstrap generici, publisher o protocollo receipt oltre questi punti necessari.

Preservare tutti55ID, tutti corpi dei metodi test e tutte le asserzioni V5; helper cleanup è l'eccezione circoscritta sopra, clock sintetico whole-second/proiezioni read-only restano trasparenti. Aggiungere soltanto regressioni negative pertinenti per advanced watermark senza fence/prova corrotta o foreign e zero assente/corrotto rispetto a zero veramente finalizzato; riusare guard esistenti quando già equivalenti. Nessuna nuova dipendenza, reset dati o indebolimento dei controlli. Il vecchio DateFAIL resta conservato: fixture deterministica non attesta correzione codec di produzione. Source writer salva il delta finale e riusa il launcher già verificato con soli pin/selector/namespace aggiornati; review indipendente del delta e fresh GO owner prima di un solo run mirato, poi gate completi sulla versione finale. Nessun DONE anticipato.

## Execution

### Esecuzione — 2026-10-08 UTC, recovery activated non finalizzata con checkpoint corrente e journal atomico

**File modificati:**
- `iOSMerchandiseControl/Sync/Automatic/Recovery/AtomicGenerationRecoverySnapshotPullService.swift` — ripresa bounded da archivio activated non finalizzato soltanto dopo `markerNotVerified`, con checkpoint corrente realmente diverso e non regressivo; seam DEBUG nil per la race del journal.
- `iOSMerchandiseControl/Sync/Account/AccountBindingStore.swift` — confronto del journal atteso, mutazione, persistenza e ritorno dello snapshot esatto entro la lease già esistente.
- `iOSMerchandiseControl/Sync/Automatic/Recovery/SyncStoreGeneration.swift` — sola osservazione OSLog approvata del primo ramo di qualifica popolata già valutato, senza nuova lettura/qualificazione/autorità.
- `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift` — sette regressioni file-backed; tutti i134 metodi precedenti e gli helper interi restano byte-esatti (129 Atomic originali,136 Atomic finali; cinque contratti fixture separati invariati).

**Azioni ed evidenze reali:**
1. Archivio A realmente activated ma non finalizzato, riaperto da disco; marker DTO B valido con un prodotto e due prezzi aggiuntivi e watermark41 invariato. Prima della patch il caso positivo termina con `markerNotVerified`, stessa generazione/journal conservati e zero checkpoint/pagine: [RED iniziale](/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/ios-activated-unfinalized-stale-marker-one-unit-red-01/receipt.json), SHA `80be0ef45852656f44a500af4b6edae0ed40b123294263aa94fa83e3d4278335`,0PASS/1FAIL/0SKIP.
2. Una vera scrittura scoped sostituisce il journal tra il confronto esterno e la transizione. [CAS RED02](/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/ios-activated-stale-marker-owned-journal-one-unit-red-02/receipt.json), SHA `8310e92b53026c71b8349b07cd65525d37bb5a5d99c6a3408af9841cc7df8f5f`,0PASS/1FAIL/0SKIP: unica asserzione desiderata fallita, scrittura concorrente riuscita. CAS RED01 resta `SETUP_FAILURE_NOT_VALIDATED_CAS_RED` per la lease del setup stale; non è prova del difetto.
3. Fonte finale48 congelata `342f3357da88dea3a3572d5dd677894234212f26c57edfc5161fa2edceda2270`: quattro file cambiati e44 carry esatti. I sette nuovi casi coprono positivo same-watermark, contenuto invariato/regressione, auth/lease/cancel/transport/decode, sostituzione journal al checkpoint e alla transizione, checkpoint B ritornato all'archivio vecchio e conservazione dell'operazione locale durevole pending.
4. [Intera classe Atomic136](/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/ios-activated-unfinalized-stale-marker-atomic-regression-final-01/receipt.json), SHA `ec918bd98b92f8d1a54756a81d1572248fcaf184e44b4cee67ab3f165b7a100e`: **136PASS/0FAIL/0SKIP**, compilazione pertinente riuscita, stessi metodi dei due RED desiderati. Fonte48, Task straniero, HEAD, Master, workflow, index e famiglia dati privata preservati; PG82749 rilasciato17:17:55.260019Z e destinazione6B Shutdown, nessun input primario. Review indipendente finale sulla fonte342f: APPROVED, nessun finding, comunicata dal coordinatore dopo il terminale.

5. [Full canonica reale](/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/ios-activated-stale-marker-final-full-guard-01/receipt.json), SHA `6c15c2ddff54677699804ac3672423e6ea6e2e148fb5254f493f1357bf0ed137`: **1576 casi ufficiali =1540PASS/0FAIL/36 stessiSKIP**, tutte16UI PASS; esatti tutti1569 ID/stati precedenti più soltanto i sette nuovi Atomic. Skip reason preservati nel readback del coordinatore SHA `aeade22d1f51744244ac9abc57ffa70d5e3405a54a2fe550a4115c325c044340`. Unica invocazione, famiglia dati/config/source/Task/HEAD/index preservati; PG86993 rilasciato17:35:22.516134Z,6B Shutdown, entro1800s inclusi90s cleanup.
6. [Build canoniche finali](/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/ios-activated-stale-marker-final-builds-guard-01/receipt.json), SHA `70b06d5bc86822343f034301928ed5b2a6a323c1353e45dd1629e3acd9de8f59`: Debug/Release/Analyze PASS sullo stesso freeze; tutti i processi rilasciati entro17:42:46.936235Z. [Comparer warning esistente](/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/ios-activated-stale-marker-final-builds-guard-01/warning-comparison.json), SHA `7376cc4a3c51bf6d0438539265f26ac055735efcb74d22347ccb86ab9b116d85`:34 occorrenze legacy primarie Analyze esatte, zero nuove/changed/unclassified; Debug0/Release0 warning primari. Messaggi AppIntents1/1/3 tenuti separati dal conteggio compiler/analyze, senza soppressioni.
7. [Contratti condivisi](/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/ios-activated-stale-marker-final-postbuild-readonly-preparation-01/workflow-contract-actual-readback.json), SHA `5fc21d8c37fb2729151c351841d14ef545c9aaf6c38d7561d4c2934e020128f2`: quattro hash verificati dal comando originale, exit0. **Scan richiesto esatto del workflow PASS**, [report ufficiale](/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/ios-activated-stale-marker-final-postbuild-readonly-preparation-01/scan-output/agent-runs/20261008T174433Z-scan-sensitive-iOSMerchandiseControl-iOSMerchandiseControlTests-contracts-github-workflows-ios-product-images-ciyml-p11416.json) SHA `d17d20b1fff60f8c19e3fcc835c5825e000d8736c37779f20194ab250e194e9a`, [receipt01](/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/ios-activated-stale-marker-final-postbuild-readonly-preparation-01/actual-scans-01/receipt.json) SHA `2eb6b52db81f5496db8d24b8fb20b29817a2d1c1287a75411353e783ec8ad260`.
8. Lo scan extra sui48 file e log originali resta distinto: tentativo01 exit1 per nome report oltre NAME_MAX; tentativo02 cambia solo l'override supportato `MC_RUN_ID`, senza cambiare sorgenti/scanner o originali. [Receipt02](/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/ios-activated-stale-marker-final-postbuild-readonly-preparation-01/actual-scans-02-short-report-name/receipt.json), SHA `5b9e7c6e89b28ddf17bd45eaaf51c011f8603e5e0a04e0a8b69403f883032889`, **FAIL letterale conservato**, esattamente due match. [Attribuzione indipendente](/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/ios-activated-stale-marker-final-postbuild-readonly-preparation-01/actual-scans-02-short-report-name/match-attribution.json), SHA `9ccf9dfda9ef248d83dc5919908d2e2e2b7918b792b1278b977c3e286f77c331`: indirizzo sintetico reserved-example sotto DEBUG in fixture351 preesistente/carry44 byte-esatto HEADa898, e UUID del simulatore isolato6B nell'argv originale full log2, distinto dal primario. Nessun nuovo secret di sorgente o credenziale auth; nessun originale riscritto, scanner modificato o altro rerun. Questa attribuzione non converte l'extra scanner FAIL in PASS.

**Check del presente snapshot:**
| Check | Stato | Evidenza / limite |
|---|---|---|
| Compilazione e regressione Atomic | ESEGUITO |136PASS/0FAIL/0SKIP sul freeze342f. |
| Full canonica finale | ESEGUITO |1576=1540PASS/0FAIL/36 stessiSKIP, tutte16UI PASS; receipt6c15. |
| Build Debug/Release/Analyze e warning | ESEGUITO | Tre comandi PASS, comparer7376:34 legacy esatti e0new/changed/unclassified. |
| Contratti condivisi | ESEGUITO | Quattro hash OK, comando exit0, readback5fc2. |
| Scan sensitive richiesto workflow | ESEGUITO — PASS | Reportd17d/receipt2eb6, comando esatto richiesto. |
| Scan extra48+log | FAIL conservato e attribuito |01 NAME_MAX;02 due match tecnici preesistenti/isolati, attribuzione9ccf; nessun nuovo source secret. |
| Proper TEST | NON ESEGUITO | `PENDING_ACTUAL_PROPER_RECEIPT`; nessun nuovo pacchetto dichiarato. |
| Coerenza con planning | ESEGUITO | Fix recovery e preservazione journal nel perimetro CA-07/CA-10; nessuna nuova feature o dipendenza. |
| Criteri globali / CI / live | NON ESEGUITO | Restano i gate finali e l'accettazione corrente; Task FIX. |

**INCERTEZZA:** il mismatch remoto osservato in seguito non identifica l'operando del marker alle15:47. Questi RED→GREEN provano i meccanismi controllati descritti, non la causa privata di quell'avvio né la disponibilità locale/auth/cloud sul dispositivo primario.

### Esecuzione — 2026-10-07 UTC, qualifica manifest popolato e refresh normale same-shop

**File modificati:**
- `iOSMerchandiseControl/Sync/Automatic/Recovery/SyncStoreGeneration.swift` — pubblicazione sotto lease fresca con provenienza stabile, autorità corrente e fence fisico esatto; successore bounded sul vero evento resolver; preservato il doppio readback bounded e distinto il progresso staging dall'autorità del journal.
- `iOSMerchandiseControl/Sync/Policy/Task126SyncPolicy.swift` — ammissione atomica della sola body-proof sotto la lease corrente, senza rinnovare i writer precedenti.
- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift` — il normale evento ShopContext inoltra la richiesta di qualifica anche mentre il body è nascosto; nessun polling, fase forzata o retry manuale.
- `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift` — sei nuovi test file-backed e due helper privati di barriera/fetch; tutti i117 metodi originali, i cinque contratti fixture esistenti e gli helper preesistenti byte-esatti. UI, fixture A/B, Database/EditProduct/LocalRootPresentation e dipendenze invariati.
- Questo file — solo tre inserimenti propri in Execution/Fix/Handoff; le286 righe di delta straniero (73insert/213delete) restano integralmente fuori dallo staging.

**Azioni e prove:**
1. RED file-backed con manifest popolato, vera qualifica trattenuta e normale refresh same-shop: `ios-manifest-qualification-same-shop-lifecycle-red-20261007-01/receipt.json`, SHA `e687dd34d12c648b2e01bfcde5da99e711cc3c8f60311464fe5fd7fe20a5e73b`. Lo stesso test GREEN1/0/0 dopo il fix (`5196a91bc7df3278561445d049ae4badc7465a56923f9716a63c38ed38c0aa99`): selectedAt/lease cambiano, provenienza business stabile e writer vecchio negato. Un test distinto osserva primo terminale false in unresolved, eventi resolver normali false→true e successore automatico senza seconda start manuale, cambio fase o rete.
2. Due rilievi concreti della review riprodotti prima del fix: drift fisico tra worker e pubblicazione (RED `4ff6edd34a31c7ad8bf1d4c9a9e0d23bd617cbda3adab3970c00d4dbdc0e29b6`, stesso metodo GREEN `650a2a6c213ae2b46d45e1e3b89f5243d99d2197e742dff8f0bb03591f4259ea`, due readback); journal reale prepared→staging mentre il transport Suppliers è trattenuto (RED02 `1d6c8a38523f98f5fbafc5f7337ad993c7828680ff09d1eb09f7427d44d96692`, stesso metodo GREEN `8884be3da032809c4d25b142e7b260f601d1e8c9b54679735998d4690617ce3a`). Run staging01 NOT_TRAVERSED per premessa errata sulla rotazione lease e compile-only mirati02 fallito conservati, non promossi a RED funzionali.
3. Mirati finali17 PASS/0 FAIL/0 SKIP, receipt `86ff91c2eee306c9b846d8e5de204d3d9e4358ba0a9b8ba218a04f70189117ac`. Negativi correnti su ruolo/status/write/selectability/account/shop/binding/device/denial/unresolved e journal nonce/mode/device/foreign/removed/corrupt restano negati. Review indipendente dello stesso C sul finalev3 APPROVED, zero finding.
4. Fonte finale congelata `ios-manifest-qualification-same-shop-minimal-fix-final-20261007-03/source-freeze-final-v3.json`, SHA `337c48306450ab7d434bd515c66e8059015e478856112def506ba29aa5581d07`; quattro file cambiati e44carry. I gate hanno HEAD base `06825f558d538a459ab217182d737a71a0679ce6` più questi byte working congelati: il futuro commit deve avere gli stessi48 blob, senza rinominare le ricevute come esecuzioni post-commit.

**Check obbligatori — esiti effettivi sullo stesso snapshot:**
| Check | Stato | Evidenza esterna in `evidence/native-local-availability-20261004/` |
|---|---|---|
| Full canonico | ESEGUITO / PASS | `ios-manifest-qualification-final-full-guard-01/receipt.json` SHA `c0e5dba8c5d7fcb8bc1901c37f9fbb3a80073f6427741ac98b01c58f9d37ea9d`:1563ID,1527PASS/0FAIL/36stessiSKIP,16UI PASS; tutti1557 precedenti stati esatti più sole sei nuove unità. Originali raw/xcresult conservati. |
| Debug, Release, Analyze | ESEGUITO / PASS | `ios-manifest-qualification-final-builds-guard-01/receipt.json` SHA `d97aa68e4d9485e9791b997e18a434a396e752c8560ce34e99a1fd432e4a196a`. |
| Warning nuovi | ESEGUITO / PASS | `warning-comparison.json` SHA `16f04b49375a87b06d6f320afe0f2e248b75ebca160bc0ad3e0fd46f626e4cba`:34legacy esatti,0new/changed/unclassified; confronto canonico f325 invariato. |
| Sensitive scan / contratti condivisi | ESEGUITO / PASS | `ios-manifest-qualification-secret-contract-gates-01/receipt.json` SHA `639bf6703477cb73a260102f43e8dadbb7cfb741a094fbdc14f1b6ea7616e3c2`; scanner canonico sul perimetro esplicito e checksum contratto exit0. |
| Proper TEST Release firmato | ESEGUITO / PASS, NON INSTALLATO | `ios-manifest-qualification-final-proper-test-guard-01/signed-release-attempt01/build-receipt.json` SHA `7f568825c5c13ad1aea5fea783a6874bd37515f8da6562390ce24925ad54119f`;23file, binary `681cded392e7deafe50ba207258aa50233521f4535f0226079f9c473023b7700`, profilo154a; firma strict/deep, fresh Xcode effective/embedded entitlements e confronto storico identity PASS,222publicinputs preservati. Il confronto storico non qualifica l'identità dell'app primaria installata corrente. |
| Preservazione e cleanup | ESEGUITO / PASS | source48/HEAD/foreignTask/MASTER/workflow/index/config/default-store preservati nei gate; tutti i processi owned rilasciati entro budget,6BShutdown, zero input/install primaria. Proper readback27/27 SHA `bc2117d91436ac555a7be4eab9b36e325b0486e9a9fc6ebd71435eecace89e5a`. |
| Coerenza planning e criteri interessati | ESEGUITO nel perimetro | Qualifica/recovery e conservazione dati CA07/08/10; autorità e vecchi writer restano failclosed. Prova controller/lifecycle reale distinta dalla regressione16UI e dall'accettazione autenticata. |
| PR/exact-head CI, mainCI, install/runtime e chiusura globale | NON ESEGUITO al commit | Commit/push/CI successivi devono produrre evidenza effettiva; N coordina merge, primaria e F/H/per-record. Task FIX, nessun DONE. |

**Incertezze e limiti:** causa delle failure CI storiche UNKNOWN; nessuna attribuzione retroattiva, nuova prova live/backend, convergenza per-record o performance dedotta dai test. Nessun assert/UI/timeout/skip indebolito. I test nuovi verificano controller/orchestrator file-backed, non una nuova root UX montata.

### Esecuzione — 2026-10-07 — Piano automatico scaduto dopo chiusura journal e fixture backend coerente

**File modificati:**
- `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift` — ricontrolla il journal same-scope al bootstrap della sola sequenza automatica pushPending→bootstrap; piano scaduto rientra nello scheduler bounded per una decisione fresca, senza nuova prova/READY.
- `iOSMerchandiseControl/Sync/Automatic/Recovery/AtomicGenerationRecoverySnapshotPullService.swift` — un provider già ammesso con TaskLocal pending può soltanto riprendere quel journal; scope scaduto non autorizza creazione di un nuovo journal.
- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift` — una condizione evita di estendere il cooldown del journal automatico dopo la sua chiusura; budget e controlli del normale scheduler restano invariati.
- `iOSMerchandiseControl/Task144LocalAvailabilityRootFixture.swift` — solo DEBUG: checkpoint/pagine/digest derivano dallo stesso catalogo ACK e dagli eventi reali del transport controllato; opt-in recorder esistente anche per EmptyFence. Hold/release, assert UI e timeout invariati.
- `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift` — due nuove unità file-backed; tutti i115 metodi originali e helper preservati byte-esatti,117 metodi totali.
- Questo file — sola nuova Execution propria; ogni modifica preesistente preservata e fuori dal commit.

**Azioni eseguite:**
1. Riprodotto P2 indipendente: dopo scelta del piano e completamento reale del journal G1, foreground/reconnect eseguono comunque due checkpoint e sei pagine e pubblicano G2. ACK, outbox e corpo salvato sono verificati: nessuna perdita dati o causa backend autenticata dichiarata. RED ufficiale0 PASS/1 FAIL/0 SKIP, receipt `f115328eaef04c86da870ea1411ec6aea227d691e1ded246f98e37031662f7fc`. Assert622 è il core causale; preservazione binding610 è effetto collaterale compatibile della nuova generazione.
2. Prima patch compila ma il medesimo test non termina entro i2s originali: NOT_TRAVERSED, receipt `7c29dccf009b3e269b3b2d27bc4419b6df28002ace9cbd459529cc0cbcfac47f`. Nessun assert/timeout cambiato. Dopo la sola condizione sul cooldown ancora pendente, stesso identico test75f3/method0e508b GREEN1 PASS/0 FAIL/0 SKIP0,586s, receipt `69b6ec1f0593814ebc869cd802fd73d064a0db0e266791b9ab26fa4174bf7834`. Entrambi i trigger: zero checkpoint/pagine aggiuntivi, stessa generazione, ACK/outbox preservati; primo risultato scheduledRetry e success/noWork terminale richiesto dall'oracolo invariato.
3. Nuovo negativo provider post-admission conserva l'OLD TaskLocal durante completamento tramite vero Atomic service; la successiva chiamata fallisce scopeChanged prima di checkpoint/pagine/nuovo journal, lasciando G1, binding, watermark, Save e pending invariati. Mirati finali14 PASS/0 FAIL/0 SKIP, receipt `3aaf053f23513aaf48023895758368ab85e351c31f80ec609655fc706181a0e6`: comprende fresh full, resume pendente con/senza Catalog, retry manuale consentito, automatic requestRecovery negato, scope/lease/cancellazione e decisione replacement. Quest'ultima non è un'esecuzione diretta di facade replacement+push.
4. Review indipendente C e stesso reader APPROVED senza finding sui3file produttivi; review fixture93500 separata APPROVED senza finding. Nessuna nuova dipendenza/API pubblica/schema/migrazione/guard authorization indebolito.
5. UI originali: RelatedSave con sola fixture coerente e produzione970 invariata1 PASS/0 FAIL/0 SKIP47,24s, receipt `349ec6a9b8fda5bb05b35f46119b87eb9a6e9a107d1e7cd011419ad97d7e654c`; EmptyFence sul prodotto corrente1 PASS/0 FAIL/0 SKIP26,46s, receipt `94bc05309c0b34a3b62a76a447c237b3f3961b6d72878a58b62f7af9c909df50`. Recorder corrente osserva fence cambiata→diniego→nuova qualifica→riammissione. Storici CI970 UI273/236 e CI87 UI224 conservati; nessuna causa storica attribuita retroattivamente.
6. Controparte Android letta: rilettura journal, CAS prima staging e retry solo sullo stesso journal impediscono staticamente la ricreazione osservata iOS; interleaving preciso NOT_TESTED, nessun nuovo test/PASS Android inventato. Nota esterna `android-counterpart-readonly.md`, SHA `a96029f9c6b11496a298d61f8e13627e1513c78ff2b86d8460f9596ac184fee4`.

**Check obbligatori — snapshot prima del commit e dei gate finali:**
| Check | Stato | Note |
|---|---|---|
| Build Debug/Release, Analyze e Proper TEST finali | NON ESEGUITO, PENDING | Nuovo delta produzione: richieste esecuzioni finali sul candidato congelato. Proper970 non riusato come copertura. |
| Mirati finali | ESEGUITO | 14 PASS/0 FAIL/0 SKIP su source48 finale; nuovo guard e regressione causale inclusi. |
| Warning nuovi | ESEGUITO nei mirati; finale PENDING | Nessun warning Swift nei tre file cambiati nel log mirato; confronto canonico finale da eseguire. |
| Full canonico e CI standard | NON ESEGUITO, PENDING | Attesi1552ID unici:1550 precedenti più due nuove unità,36skip invariati; i risultati saranno registrati nelle ricevute finali effettive. |
| Coerenza con planning | ESEGUITO | CA07/09/10/11: eliminazione full superfluo dopo RED, preservando conservazione dati e ammissione fresca. |
| Criteri globali/chiusura | NON ESEGUITO | CA07 autenticato/08integrale/09performance/10finale/11integrazione/12chiusura restano aperti secondo il report parent; task FIX/NON DONE. |

**Incertezze:**
- I due UI PASS correnti non provano la causa dei distinti FAIL storici. Correzione fake backend e difetto del piano scaduto sono prove separate.
- Nessuna convergence per record Android↔iOS, distribuzione o target3s live dedotta dai test controllati. UI primaria Android bloccata; runtime/sessione primaria iOS da qualificare.

**Handoff notes:**
- Commit/push selettivo ordinario autorizzato; nuova CI standard e full locale sullo stesso candidato possono procedere in parallelo. Poi build/Analyze/ProperTEST finali. Nessun merge prima di review ed esiti effettivi verdi.
- Dopo merge normale: mainCI, fast-forward preservativo della primaria e install/runtime con nuovo artefatto e nuova prova dati. Nessun reset, uninstall, clear, forcepush o deploy produzione.
- Pacchetto parent `evidence/native-local-availability-20261004/ios-completed-journal-stale-bootstrap-*`; questa Execution è PRE-FINAL-GATES e non dichiara futuri PASS.

### Esecuzione — 2026-10-07 — Automatic resume con Catalog pending dopo finalizzazione

**File modificati:**
- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift` — conserva il piano bootstrap già ammesso per la ripresa automatica; normalizza requestRecovery solo per il retry esplicito.
- `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncRuntimeFacade.swift` — ammette solo la sequenza esatta pushPending→bootstrap per rootForeground/networkReconnect e journal same-scope; le altre azioni e sorgenti restano negate.
- `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift` — un test con CatalogPush reale, ACK/outbox e finalizzazione file-backed, due sorgenti e controlli negativi prima della ripresa; tutti i114 metodi originali byte-identici.
- Questo file — solo nuova evidenza Execution; modifiche preesistenti preservate e non incluse nel commit.

**Azioni eseguite:**
1. Riprodotto un difetto applicativo distinto dal FAIL storico CI87: dopo il vero ACK Catalog, il piano automatico veniva normalizzato a requestRecovery, che Engine correttamente nega fuori releaseCard; journal aperto e verified false. RED ufficiale1 FAIL/0 PASS/0 SKIP, unico assert finale per entrambe le sorgenti; setup, scope, generazione, watermark41, ACK e outbox superati. Receipt fdf9b06878f3436b856d0de49231ef8532a6d5ca597e3719e53b6e6ead9e77a5; verifica22/22 4ae3c80bd21cf826791ee192e0014bb0ff02c3b2ec93a622eb73b3818cfb88f4.
2. Applicato il minimo fix in due file; stessa identica prima regressione ora1 PASS/0 FAIL/0 SKIP. Receipt93f3c64166f2841712e54641aecf58c7b57cc7017a4d2c0bbcfa4b6c687d8655; verifica25/25 85a76dcbf3b818bcfc8e5d93eded0b7cbd82680bd18f7eb147ee1972b0b73619. Per entrambe le sorgenti: ACK/outbox true, journal completato, verified true; nessuna nuova richiesta checkpoint/page.
3. Aggiunti nello stesso nuovo metodo controlli negativi sulla facade reale: foregroundPoll/releaseCard, push isolato, sequenza inversa o duplicata e zero chiamate remote prima della positiva. Mirati finali10 PASS/0 FAIL/0 SKIP, receipt4a2cfe476bfd801d687be8e3b43b28ae494679efdeae89e537a813874af3f597; verifica29/29 3a8bc161b21641ee1940405aa953f838b8fe816853d903f4e5f5e1fb5b212eb3.
4. Review indipendente C e reader APPROVED, compreso delta negativo finale: nessun finding. Engine, guard releaseCard, scope/device/lease, cancellazione, budget e Task119 invariati. Nessuna dipendenza/API pubblica/schema/UI cambiata.
5. CI ba28/37571272683 precedente PASS1549=1513 PASS/36 stessi SKIP/16UI PASS e bundle originale acquisito (receipt f8ff28507da95aa640f387ef43fc0d696911245bf2ba43fa9647ba0f906b38e9). È prova dello snapshot precedente; non copre questo fix. RelatedSave recovery.value returned.completed-journal.true, FAIL87 NON_REPRODUCED, causa storica UNKNOWN.

**Check obbligatori — snapshot prima del commit/push e dei gate finali paralleli:**
| Check | Stato | Note |
|---|---|---|
| Build Debug/Release, Analyze e Proper TEST finali | NON ESEGUITO, PENDING | Nuovo delta produzione: esecuzioni finali necessarie sul candidato congelato dopo commit. Proper87 non riusato come copertura. |
| Mirati finali | ESEGUITO | 10 PASS/0 FAIL/0 SKIP; processi terminati, simulatore isolato Shutdown, dati baseline preservati. |
| Warning nuovi nei mirati | ESEGUITO | 0 primari/1 metadata AppIntents preesistente/0 non classificati. Gate finali ancora PENDING. |
| Full canonico e nuova CI standard | NON ESEGUITO, PENDING | Attesi1550 ID, tutti1549 precedenti invariati più una nuova unità; gli esiti saranno registrati nelle ricevute finali effettive. |
| Coerenza con planning | ESEGUITO | CA07/10/11, ripresa automatica same-scope con pending; minimo fix causale dopo RED reale. |
| Criteri globali e chiusura | NON ESEGUITO | Merge/mainCI/install/runtime e gate live/performance restano separati; TASK144 FIX/NON DONE. |

**Incertezze:**
- Nessuna attribuzione causale al FAIL storico CI87/RelatedSave; questo difetto ha un RED indipendente. Fixture controllata non equivale a backend autenticato o convergenza bidirezionale reale.

**Handoff notes:**
- Commit/push selettivo ordinario autorizzato; nuova CI standard in parallelo a full/build/Analyze/Proper locali, sorgenti e Task congelati dopo commit. Merge solo con esiti finali reali verdi, poi mainCI e aggiornamento TEST preservativo autorizzato. Nessun reset o modifica production.
- Ricevute complete nel pacchetto parent `evidence/native-local-availability-20261004/ios-automatic-resume-pending-catalog-*`; questo log è lo snapshot pre-gate e non dichiara futuri PASS.

### Esecuzione — 2026-10-07 — Related Save recovery-value diagnostic

**File modificati:**
- `iOSMerchandiseControl/Task144LocalAvailabilityRootFixture.swift` — DEBUG only: abilita il recorder RAM esistente per il fixture RELATED_SAVE e registra ingresso/esito reale di recovery.value, compresi failureKind e categoria tipizzata chiusa, senza query, guardie o timeout nuovi.

**Azioni eseguite:**
1. Preservati originali CI87/37564466855:1549 ID=1512 PASS/1 FAIL/36 stessi SKIP,unico leaf RelatedSave UI224. PID90502: released e nuova generazione pubblicata; saved intent/relazioni/feedback locale preservati. Activated assente; mapping/ownACK dopo cutover non raggiunti.
2. Verificato che bootstrap.failed.other nel prefix finale è lo stesso callback della vecchia generazione osservato prima del rilascio,non un errore provato della nuova. Ramo recovery.value corrente UNKNOWN; nessun fix applicativo dedotto. Artefatto originale187102916B/SHA86ec5187db173506b1c1424c92255e23e4ee30132b9ed39c74d28db8737fbd12,6export ufficiali completati.
3. Cheap originale RelatedSave una volta su diagnosticab753:1 PASS47.392s,receipt13eccc4c49607003f20c8649d168bfd05c23dffa2f65e7c00d44e09090528b04. Stdout ufficialePID64130:before-await→returned.completed-journal.true dopo0.375s,10RAMeventi/noCAP. Nessun ramo threw/ripresaautomatica osservato; fallimento remoto NON_REPRODUCED,nessuna causa risolta dichiarata.
4. Review indipendente C+reader APPROVED neutralità; rilievo categoria tipizzata aggiunta nella stessa riga diagnostica (fixture finale046135c825b54906a4329d0ea02a1892a927f8de27afbe61d161cf76d2d9a0a9). Compile finale046 PASS/exit0,26.68s; receipt2d05dfeea07f6a6c92748b05e52d7922ea303aaf6b735527f93ecc32fc4a2cfa, verifica24/24 a6aab8610ac72e8351062ce25260ba6f4383230076f6ba29de73d8a0aa52a661. Review finale C APPROVED della sola riga tipizzata. UITest intero a78bbda26cefc460cb6e7414f3e91386bfb72b5ac93358e745b7245590919570 immutato.
5. Secret scan workflow esistente su14input effettivi PASS,receipt68553ce577e7778b24621105320225e0540ea0eb9b3d1761d2be84de6cf7a172; filtro directory .log/.md/.json/.txt e workflow esplicito,nessuna estensione del perimetro dichiarata.

**Check obbligatori:**
| Check | Stato | Note |
|---|---|---|
| Compile Debug finale | ESEGUITO | Fonte046 compilata; exit0/BUILD SUCCEEDED, receipt2d05dfee, nessuna UI/full/Release/Proper ripetuta. |
| Test mirato originale | ESEGUITO | 1 PASS b753; successiva sola aggiunta String tipizzata verificata separatamente in compile046. |
| Warning nuovi | ESEGUITO | 0 primari/1 metadata AppIntents preesistente/0 non classificati; nessun warning nuovo. |
| Coerenza con planning | ESEGUITO | Diagnostica del leaf F03 esistente,nessuna modifica di comportamento o guardia applicativa. |
| Criteri di accettazione globali | NON ESEGUITO chiusura | CI87 FAIL preservato; nuovo CI/integrazione/runtime/performance autenticati pendenti. |

**Incertezze:**
- Causa originale RelatedSave UI224 UNKNOWN; local PASS non è fix causale né prova backend/live.

**Handoff notes:**
- Full87 1549/1513P/36S,Debug/Release/Analyze/Proper87 restano prove reali dei rispettivi snapshot. Questo delta interamente DEBUG non li rinomina come nuove esecuzioni; full87 viene riusato solo come comparatore di ID/stati.
- Nessuna ripetizione full/Release/Proper immutati per il push diagnostico. PR18/merge/install/runtime restano subordinati agli esiti finali reali. TASK144 resta FIX/NON DONE.

### Esecuzione e fix — 2026-10-06 America/Santiago (2026-10-07 UTC), discriminante setup empty-fence

**Stato FIX, non DONE.** CI37558310519 al commit033 ha 1549 casi ufficiali:1512PASS/1FAIL/36SKIP invariati; i vecchi1548ID/stati sono identici al full locale e il solo nuovo caso fallisce a UI273. AXPID67326 mostra empty-fence.failure prima di initially-admitted: setup prima dell'iniezione, operando preciso UNKNOWN. Il FAIL originale e il download parziale restano conservati; recupero Range206 dello stesso artifact con SHA API f3913e6ef64623203011c40aa55df94a80dae93a8610674258fc7c36c7484508, CRC/extract e6export ufficiali PASS (receipt8c9e82fb804277d301b067ebec96ab59118cae6da21bbc1dc9b4919461afdf38).

**File modificati:**
- `iOSMerchandiseControl/Task144LocalAvailabilityRootFixture.swift` — SOLO DEBUG: stadio e primo predicato falso, stessi8operandi/ordine/short-circuit e singole valutazioni; catch con categorie chiuse failureKind e una sola mutazione facts. Nessun nuovo accesso dati, qualification, attesa, retry o cambio di assertion/budget.
- Questo task — solo la presente Execution; foreign preesistente escluso dal commit.

**Azioni/evidenze:**
1. Il medesimo nuovo caso UI, immutato, passa una volta in28.312993s:1PASS/0FAIL/0SKIP,xcodebuild exit0. Receipt6c43a0265dd13f1592440f883f10e1a2618b7e6f4aae66c1f764e05fa013def0; quattro export ufficiali exit0, verifica23/23PASS, processi assenti e solo6BShutdown.
2. Classificazione NON_REPRODUCED; primo predicato fallito NOT_OBSERVED. Il delta e il PASS locale NON sono un fix causale del setup storico. La diagnostica conserva il discriminante per un'eventuale ricorrenza reale.
3. Review readonly del delta9fa47b0262de054b1787c81dcddaef3dc1bfa79020eee697fc85a9a8c9aa3dda: APPROVED,zero finding; nessun cambiamento prodotto o nei16metodi UI. Full finale/CI/integrazione/installazione restano successivi e distinti.

**Check obbligatori:**
| Check | Stato | Evidenza |
| --- | --- | --- |
| Build/test mirato | ESEGUITO | Compilazione e unico UI PASS sul fixture8dbaa285406dcb70b7a69fbff9fa39499db30549f1ced053860ed2f04407bc80. |
| Analyze/build canonici finali | NON ESEGUITO | Da eseguire sulla versione finale; precedenti033PASS restano storici. |
| Warning nuovi | NON ESEGUITO | Confronto finale Analyze pendente. |
| Coerenza planning | ESEGUITO | Diagnostica del solo fixture coinvolto; produzione, scope/fence/authority invariati. |
| Criteri di accettazione | NON ESEGUITO integralmente | CA07/08/09/10/11/12 e prove esterne aperte; nessun DONE/READY. |

**Handoff:** nuovo CI deve conservare il primo falso se ricorre; non aumentare timeout, saltare/indebolire il test o attribuire una causa da un PASS. Nessun input/install sul primario in questa esecuzione.

### Esecuzione — 2026-10-07 UTC, nuova qualifica dopo invalidazione fisica della shell vuota

**Stato FIX, non DONE.** Il root ora osserva il passaggio del gate da visibile a nascosto su un `Group` stabile e richiede al controller esistente una nuova qualifica quando manca il manifest attivo. La vecchia proof resta negata fino alla scansione completa e alla pubblicazione validata; nessun nuovo grant READY/write, query nel getter, polling, motore sync o cambiamento dei guard di scope/fence. `SyncStoreGeneration.swift` resta byte-identico.

**File modificati:**
- `iOSMerchandiseControl/ContentView.swift` — osservatore lifecycle stabile della perdita di ammissione; UI/UX: ripristina la shell locale solo dopo nuova prova valida, senza Retry manuale.
- `iOSMerchandiseControl/Task144LocalAvailabilityRootFixture.swift` — variante DEBUG opt-in su store sintetico: cambia realmente la mtime del solo legacy.store, verifica diniego della vecchia proof e nuovo revision/admission senza cambiare scope, fase, container o autorità.
- `iOSMerchandiseControlUITests/LocalAvailabilityRootUITests.swift` — un nuovo caso; tutte le asserzioni, gli helper, l'ordine e i budget precedenti restano identici.
- Questo task — solo la presente voce Execution; modifiche preesistenti escluse dal commit.

**Azioni/evidenze:**
1. Originale campagna finita A: 1 FAIL/4 PASS. Nel FAIL, qualifica iniziale ammessa, fence fisico cambiato e successore non osservato; nei PASS4/5 un successore ripristina l'ammissione. Il writer storico e il membro preciso del fence restano UNKNOWN.
2. RED reale con produzione precedente e stessi nuovi fixture/test: 0 PASS/1 FAIL, unica assertion nuova di riqualifica; receipt `ff6127c6f39ef3963c80907813573c814e3d73867628aba03433c795a8b72147`.
3. Primo GREEN: NOT_RUN infrastrutturale, runner Simulator occupato prima del caso. Dopo boot/status del solo simulatore sintetico, GREEN attempt02: 1 PASS/0 FAIL/0 SKIP, receipt `a38cd4760a76d04ede858dd3a66da5c2cd53794c5b3f695bd249110440a33597`.
4. Regressioni adiacenti: 10 PASS/0 FAIL/0 SKIP, inclusi otto unit test negativi/scope/revoca, A originale e B originale editor/cutover; receipt `d0cf4424166281b9444f53f3507529619f94756bb52d75da942d61d4e35d359d`.
5. Review indipendente degli stessi Data/UX: APPROVED con limiti sul freeze `d7cffc1b8e42ca68fb83c51bbb38160db1bac6d83df662383b48a1fa92ae2bce` e patch `8f9d1707d3ff122a3b565a0a8b7dee02d0843f2a947a4c6a96621dadf5e1a942`; nessun finding bloccante.

**Check obbligatori:**
| Check | Stato | Note |
|---|---|---|
| Compilazione e test mirati | ESEGUITO | RED reale, GREEN1 e adiacenti10; processi propri assenti e simulatore sintetico Shutdown. |
| Gate canonico completo / Debug / Release / Analyze sul nuovo delta | NON ESEGUITO | Da eseguire dopo decisione batch sul nuovo B70 originale CI; i gate precedenti non certificano questo delta. |
| Warning nuovi | NON ESEGUITO | Conteggio canonico finale ancora pendente. |
| Coerenza con planning e preservazione | ESEGUITO | Controller/45carry originali, MASTER, dati/config primari e Task foreign preservati; nessun input/install sul primario iOS. |
| Criteri di accettazione globali | NON ESEGUITO | CA-07 live, CA-09 finale, CA-10 full/CI e integrazione/runtime restano aperti e separati. |

**Incertezze / handoff:** il trigger richiede un nuovo edge visibile→nascosto; fallimento già hidden senza altro edge non coperto. La nuova CI standard al precedente HEAD1bd è 1511 PASS/1 FAIL/36 SKIP: B fallisce alla riga70 su activated, prima del presenter editor. Il B locale PASS non chiude quel FAIL; originali in acquisizione, causa esatta UNKNOWN. Nessun full/push automatico prima della decisione su B; normale commit selettivo A autorizzato. Nessuna chiusura globale, merge, distribuzione o convergenza live inferita.

### Esecuzione — 2026-10-07 — campagna A finita nella CI esistente

**File modificati:**
- `.github/workflows/ios-product-images-ci.yml` — input manuale booleano per cinque esecuzioni isolate del test A originale, con ambiente dichiarato, log/exit/xcresult separati e verifica ufficiale di un solo ID per esecuzione; default PR/main/full e budget75 minuti invariati.
- Questo task, soltanto Execution — log derivato dal blob HEAD; working copy foreign14c preservata.

**Azioni eseguite:**
1. CI originale37545350645 sul checkout effettivo325afcc conclusa PASS:1548ID/stati/moduli esatti al Full05,1512PASS/0FAIL/36SKIP,15UI PASS. Analyze/secret/contracts PASS; non è una correzione causale A.
2. Nuovo mandato umano b2af921d, sezioni4/7/8: cinque esecuzioni A predefinite in macos26-arm64/Xcode26.6-build17F113/iPhone16e-iOS26.2, senza retry-until-green; stessi test/asserzioni/fixture/launch. Review indipendente del delta dal coordinatore; nessuna nuova infrastruttura o suite locale completa duplicata.
3. YAML, sintassi Bash e Python verificati; tutti gli step originari equivalenti salvo selezione manuale full/campagna. Checker provato sui veri export storici: singolo A accettato, Full1548 rifiutato come singolo A. Sono controlli statici del workflow, non nuove esecuzioni dell'app.

**Check obbligatori:**
| Check | Stato | Note |
|---|---|---|
| Build/test native | ESEGUITO sul source42 immutato | Genuine8/Full05/Build05 e CI37545350645 riusati; nessuna modifica alle48 fonti o input pubblici native. |
| Static workflow | ESEGUITO | YAML/Bash/Python e diff-check PASS; default PR/main/full, step originali, timeout e asserzioni preservati. |
| Warning nuovi | ESEGUITO sul source42 |34legacy/0nuovi nei gate locali; delta workflow non modifica codice app. |
| Coerenza con mandato | ESEGUITO | Cinque A originali isolate, tutti gli esiti conservati e aggregato FAIL su skip/missing/infrastruttura; nessun fix A dichiarato. |
| Campagna/runtime finali | NON ESEGUITO in questo snapshot pre-push | Risultati effettivi successivi nel riepilogo corrente del coordinatore e originali esterni; merge HOLD fino ai gate richiesti. |

**Handoff notes:**
- Stato FIX / NON DONE. Full05 immutato rimane valido sulle stesse48 fonti; la campagna non sostituisce la CI PR/main o il collaudo autenticato.
- Il writer nativo resta N; il coordinatore01a113a4 possiede i due documenti centrali. Nessun private config, database, sessione, primary install o input business è modificato da questo commit.


### Esecuzione — 2026-10-06 — fonte finale42 e controesempio prepubblicazione

**File modificati:**
- Questo file task — sole sezioni Execution/Fix/Handoff dal blob HEAD; il file worktree preesistente SHA14c119 resta invariato.
- `docs/TASKS/EVIDENCE/TASK-144/local-availability-20261005/README.md` e `source-and-targeted-evidence.json` — riconciliazione F04: fonte42/gate attuali, vecchio manifest0af5 conservato come storico integrale.
- Il controllo TEMPV3 di quattro file DEBUG è stato applicato solo per una singola osservazione e rimosso esattamente; nessun nuovo delta di produzione.

**Azioni eseguite:**
1. Fonte di produzione48 SHA42c992cc, HEAD0a481131, diagnostica080b e Database3584: le otto unità originali genuine PASS8/0/0 (receipt4f1b605d, root3f8ce56a). Full05 canonica senza filtri, nuovi skip o parallelismo:1548ID distinti,1512PASS/0FAIL/36SKIP identici e15UI PASS (receipt2927cd0f, rootappendix54293fe1). Tutti gli ID/stati coincidono con la mappa attesa39befc9b. I precedenti gate su fonti diverse restano storici.
2. Medesimi due reviewer approvano il witness temporaneo V3 SHA8c7a2019; il producer finale bb3e43e8 preserva il metodo UI originale, tutte8 funzioni canoniche,600s totali inclusi90s cleanup e4 export originali. Nessun secondo start manuale, remount, Retry, trigger owner/fase artificiale o query d’autorità aggiunta. La fase viene osservata nella singola valutazione già esistente del prodotto.
3. L’unica esecuzione nativa termina1FAIL/0PASS/0SKIP,exit65,26.972322s,receipt37c7819c. Solo UI270 `previous-shop-callback-released` fallisce; UI271 held e il giro tab/UI277 non vengono raggiunti. Non è il RED della navigazione storica CI.
4. Tutti31 record originali dello stesso PID90264 sono verificati contro stdout1ead0455 e hash di riga: ticket1 corrente/noncancelled fallisce con `shopContextUnavailable`, ma la fase cambia prima del suo terminale. Il contesto normale risolve lo stesso account/shop/store; il successore automatico ticket2 pubblica una prova con full7/fence/revalidate e viene ammesso. Classificazione **NOT_TRAVERSED**, perché il prerequisito fase invariata non è soddisfatto. Trigger parent esatto del successore e causa CI storica restano UNKNOWN; nessun fix A di produzione è giustificato da questo run. Readback indipendente0611be4a, root15/15 c11a2723.
5. Quattro export ufficiali exit0 chiusi22:43:06.470624Z,receipt80c01d92. Inverse temporanea esatta0d88ab53 chiusa22:45:33.243831Z,receiptff66ad20, entro la deadline originaria22:50:32.083564Z. Tutti48 file WT e HEAD corrispondono alla fonte42; diag080b e fixB conservati. PG assente, simulatore Shutdown, index vuoto, Task foreign14c/MASTER/workflow/config checksum-stat e famiglia default.store preservati. Nessun nuovo runtime dopo il run; Full05 resta pertinente per uguaglianza byte-esatta delle48 sorgenti ripristinate.
6. Debug/Release/Analyze05 PASS (receiptfd89400f, rootdf13f5b2); comparatore canonico f325:34 warning legacy identici,zero nuovi/changed48/unclassified (20becc28). Scan sensibile canonico e hash dei contratti condivisi PASSa8b4e187. Proper FULL TEST05 Release firmato PASS6e183b5a/rootffe1af43:23 file verificati,binary10cbfa12,profilo154a,fresh signer,entitlements effettivi/embedded/Xcent e vecchia identità keychain conformi,strict/deep PASS. Artefatto NON INSTALLATO. Tutti14 comandi originali exit0;deadline1800/90,rientro executor23:08:16Z,gruppi assenti/6BShutdown/preservazione PASS.
7. Riepilogo e manifest nativi indicavano ancora fonte0af5/Full11 come attuali: riconciliati con source42 e ricevute correnti, preservando l’intero precedente manifest sotto historicalValidationSource0af5 e gli originali byte-esatti esterni. Snapshot documentale pre-push:CI candidata esatta,merge/mainCI/FF ancora NON ESEGUITI;esiti successivi nel rapporto aggregato esterno,senza commit autoreferenziali.

**Check obbligatori:**
| Check | Stato | Note |
|---|---|---|
| Build | ✅ ESEGUITO | Debug/Release/Analyze05 PASS sulla fonte42; Proper FULL TEST05 firmato PASS,non installato |
| Static/reviewer | ✅ ESEGUITO | SAME2 approvano la diagnostica e il witness; all48 post-inverse/root15 PASS |
| Warning nuovi | ✅ ESEGUITO | Comparatore f325:34 warning baseline identici,zero nuovi e zero nelle48 sorgenti modificate |
| Coerenza planning | ✅ ESEGUITO | Witness circoscritto; no fix senza RED pertinente; logica/autorità/UI originali preservate |
| Criteri di accettazione | ❌ NON ESEGUITO | FIX; CI/integration, device primario, live/parità/performance rimangono distinti |

**Incertezze:**
- HistoricalCI A UNKNOWN; test temporaneo NOT_TRAVERSED. I record di uguaglianza non identificano il callsite preciso del successore.
- Warning SQLite e guard interno del setup recovery non sono dichiarati innocui o causa storica.


### Esecuzione — 2026-10-06 — diagnostica del primo diniego A conservata per CI

**File modificati:**
- `iOSMerchandiseControl/ContentView.swift` — osservazione DEBUG dei soli operandi già valutati e del ramo che nasconde la root.
- `iOSMerchandiseControl/Sync/Automatic/Recovery/SyncStoreGeneration.swift` — osservazione DEBUG dell’ammissione vuota, ticket corrente, completamento/pubblicazione e classe/caso di errore prima della sanitizzazione.
- `iOSMerchandiseControl/Sync/Policy/Task126SyncPolicy.swift` — osservazione DEBUG delle guardie di capture/revalidate realmente valutate, con gli stessi errori e short circuit.
- `iOSMerchandiseControl/Task144LocalAvailabilityRootFixture.swift` — recorder RAM esistente con PID e limiti invariati; ancore del callback held/previous. Nessun payload, identificativo di business o descrizione libera di errore.
- Questo file task — sole evidenze owned Execution/Fix/Handoff dal blob HEAD; il file worktree preesistente SHA14c119 rimane invariato.

**Azioni eseguite:**
1. Entrambi i medesimi reviewer dati/UX hanno approvato il freeze080b senza finding. Root ha verificato le copie forward/inverse, applicato selettivamente quattro file (receipt5ded), preservato DB3584 e gli altri44 file. Run freeze effettivo7db; nessuna modifica a test originali114/6fb, guardie d’autorità, query, scritture SQLite, navigation o dipendenze.
2. Un’unica compilazione ed esecuzione del test originale `testPreviousShopCallbackCannotInvalidateFreshEmptyRecoveryAdmission` sul runner finale2c2/source7db: 1 PASS, 0 FAIL, 0 SKIP, 21.465908s, exit0, receiptfac64f78. Deadline unica600s comprensiva90s cleanup; rilascio del gruppo21:47:19.494429Z. Il risultato locale è NON_REPRODUCED e non attribuisce la causa del precedente fallimento CI6ff.
3. Tutti i quattro export ufficiali sono exit0 entro la deadline originale (receipte50a). Verifica root18/18 PASS975038ed ed executor22/22 PASS7b0c45b5: source48, HEAD75ff, Task14c, MASTER/workflow/index/status, config86a67 checksum/stat e tre file default.store preservati; PG77206 assente e simulatore6B Shutdown.
4. Diagnostica conservata esatta per ambiente/toolchain/ordine CI pertinente. Nessun inverse automatico su PASS. CAP128, dedup o assenza di un marker pertinente sono NOT_OBSERVED; startup proof-absent, timeout held intenzionale e ticket non corrente non costituiscono da soli la causa corrente.
5. Le otto regressioni genuine sono PASS sul precedente freeze produzione754/HEAD75ff (receiptf807/root724). I gate completi sulla revisione comprensiva della diagnostica sono ancora da eseguire; il precedente Full04 è sospeso perché lega source754. AndroidAPK88/sessione/dati preservati; interazione primaria ancora bloccata dalla finestra Running Devices non raggiungibile.

**Check obbligatori:**
| Check | Stato | Note |
|---|---|---|
| Build | ✅ ESEGUITO | Compilazione del singolo test originaleA/source7db PASS; Debug/Release/Analyze completi sulla revisione finale successiva NON ESEGUITI |
| Static / reviewer | ✅ ESEGUITO | Medesimi due reviewer approvano080b; root20 sourcechecks e24 producerchecks PASS_STATIC |
| Warning nuovi | ❌ NON ESEGUITO | Comparatore canonico Debug/Release/Analyze deve verificare la revisione finale; nessun PASS precedente riclassificato |
| Coerenza planning | ✅ ESEGUITO | Diagnosi circoscritta di A; autorità e assert originali preservati |
| Criteri di accettazione | ❌ NON ESEGUITO | Task FIX; gate finali, CI esatta, installazione primaria, live/parità e performance restano separatamente aperti |

**Incertezze:**
- Causa storica di A ancora UNKNOWN. Nessun nuovo fix di produzione A giustificato dal PASS locale.
- I warning SQLite storici non sono dichiarati innocui o causali senza prova pertinente.


### Esecuzione — 2026-10-06 — editor ripristinato dopo l’aggancio alla finestra

**File modificati:**
- `iOSMerchandiseControl/DatabaseView.swift` — bridge UIKit privato e passivo per ripristinare una sola volta l’editor della generazione corrente quando il presenter e i suoi parent appartengono alla stessa finestra; stato visivo iniziale ripristinato separatamente.
- Questo file task — solo nuove evidenze Execution/Fix/Handoff owned, derivate dal blob HEAD; il file worktree preesistente SHA14c119 resta byte-identico.

**Azioni eseguite:**
1. La prima osservazione originale ha riprodotto UI71: ammissione corrente e fetch univoco validi, poi warning UIKit di presentazione da controller fuori gerarchia finestra. Lo stesso warning è presente nell’originale CI6ff; non attribuisce una causa comune al distinto fallimento UI277. Ipotesi di draft cancellato dal primo diniego falsificata nell’esperimento.
2. Applicata la sola patch Database approvata dai medesimi reviewer dati/UX, SHA8460acef; file risultante SHA3584c40e. Guardie owner/manifest/scope/local-access, fetch limit2, sheet/dismiss, Save/ACK/CAS invariati. Nessun timer, polling, nuova dipendenza o modello precedente conservato. UI/UX: l’editor torna utilizzabile con draft e focus dopo il cutover (motivo: continuità dell’interazione già prevista dal task).
3. Il test UI originale completo, senza modificare selector/metodo/timeout, è PASS 1/1 in57.790840s: draft/focus, Cancel, drain, ownACK, filtro/tab e terminate/relaunch con coda vuota. Receipt e72caa31, inverse91e0cc1f, export57efe48b, verifica executor d77ed57d e root706609a6. Screenshot originali prima/dopo conservati.
4. Dopo inverse canonica, PG assente e simulatore Shutdown, root conserva separatamente la medesima patch di produzione. Commit normale selettivo dei soli Database + nuove sezioni task owned; niente scrittura del task foreign, MASTER o workflow.

**Check obbligatori sul candidato finale:**
| Check | Stato | Note |
|---|---|---|
| Compilazione pertinente / UI originale | ✅ ESEGUITO | Xcode test originale, exit0, 1PASS/0FAIL/0SKIP sul medesimo file Database3584. |
| Full suite canonica | ❌ NON ESEGUITO | Richiede nuova ricevuta mirata8 e full sul freeze/HEAD finale; i precedenti gate B4 restano storici. |
| Debug/Release/Analyze e warning nuovi | ❌ NON ESEGUITO | Gate completi sul nuovo source pending; nessuna equivalenza con vecchio Analyze o CI rossa. |
| Coerenza con planning | ✅ ESEGUITO | Fix minimo di continuità editor dopo recovery, scope/ammissione dati preservati. |
| Criteri di accettazione | ❌ NON ESEGUITO | B originale PASS; A UI277, CI finale, installazione primaria e accettazione live restano aperti. Task FIX, non DONE. |

**Incertezze:**
- A: bootstrap.failed.other è compatibile col timeout intenzionale della fixture held; primo diniego concreto del gate ancora da registrare.
- Nessuna nuova installazione, prova di auth reale, convergenza mobile o prestazione live è implicata dal test fixture.


### Esecuzione — 2026-10-06 UTC, quattro commit normali e Full03 finale

**Task e fase FIX; criteri e stato globale invariati.** Questo aggiornamento parte soltanto dal Task committato `165c92fc`; il working Task foreign `14c11901` resta byte-identico e fuori dallo staging. Le prove controllate locali sono distinte da accettazione live, installazione e chiusura globale.

**Commit normali effettivi:**
1. `1a0cc662` — ripristino dei quattro file diagnostici alla base approvata; guard di produzione che conserva la candidata empty-root same-owner soltanto durante `shopContextUnavailable`, più sette righe nel test originale. RED reale `935ce0a3`/root `fdc614fc`: 0P1F0S, solo assert finale1021; tutti i controlli originali fisici/full7/autorità/old-writer/container/journal restano validi.
2. `8f869c06` — provider reale della fixture DEBUG controllata e cinque righe nel helper privato di qualifica zero-reopen. Il terminale deriva dal summary reale e dai controlli correnti, senza recover manuale aggiuntivo o READY sintetico.
3. `da2f42f9` — sola rimozione dell'await superfluo nel callback DEBUG isolato al MainActor; le due nuove occorrenze warning rilevate nei gate01 restano documentate, senza sostituire la baseline legacy34.
4. `c89add54` — helper privato DEBUG che confronta i sette campi stabili nei due punti della fixture, escludendo soltanto `currentRunLease`; autorità corrente e guard ACK/CAS/sealed-event restano strict. La diagnostica additiva full-scope segue sealed-revision, conservando la sottostringa originale e l'assert UI169/174. Nessun corpo di test, timeout, nuovo test, dipendenza o API pubblica modificato da questo delta.

**Fonte e provenienza:** aggregate reale `fab7b97e`, source48 esattamente uguale a `b4fc7db0.proposedSource48SHA256`, fixture `321e1813`, HEAD nativo reale `c89add54`. Il freeze di proposta conserva il suo head storico `da2f42f9`; le receipt native mantengono il loro HEAD effettivo. La stessa coppia reviewer dati/UX ha approvato il candidato, prova `57e42f12`; non si aggiunge una catena di review.

| Check | Stato | Evidenza |
|---|---|---|
| GREEN8 candidato combinato949 e GREEN8 fonte1d7 | ESEGUITO | 8P0F0S separati; receipt5ee82154/rootd235c7f2 e receipt45da5f5a/root8111d02d |
| Due UI originali normal-response/lost-response sul candidato finale b4fc7 | ESEGUITO | 2P0F0S, receipt66fa7c4a; test/assert originali invariati, inverse esatta verso1d7 |
| Otto unitari originali sul medesimo candidato b4fc7 | ESEGUITO | 8P0F0S, receipt138b2227; inverse esatta, non rietichettata con HEADc89 |
| Full03 finale non filtrato su HEADc89/sourceb4fc7 | ESEGUITO | 1548 ID esatti,1512P/0F/36 stessi SKIP/15 UI PASS; receipt487b7b0a/root e38e8f2e, map39befc9b, preservazione/cleanup/deadline verificati |
| Debug/Release/Analyze03 e warning baseline34 | ESEGUITO | Tre build PASS; receipt6fb1b995/root657cb45f/executor562a103f, pre-warning1a32219e e confronto89928698: 34 legacy identici, zero nuovi e zero warning nei source48 modificati; preservazione e deadline verificate |
| Proper03 TEST firmato e preservazione config/keychain | ESEGUITO | receipt29b32eb4/rootbece698d/executorcbea581b; 23 file, binary1ef75f21, firma/entitlement effettivi e preservazione keychain/profile/config/input verificati; terminale18:23:06 UTC, non installato |
| Singolo unitario SQLite originale e osservazione diagnostica controllata | ESEGUITO | 1P0F0S, receipt425b2c57/inverse21c40814/root5474e5f1/executor3ca58000; 17 record e 8 warning; source48 finale ripristinato, HEADc89/protected/index/baseline preservati, PG residui vuoti e destinazione Shutdown; entry600s inclusi90s cleanup, release18:26:20 UTC |
| Worker/cleanup SQLite, sessione/outbox e ritenzione su iOS primario | NON ESEGUIBILE | Worker/kernel/private cleanup UNKNOWN; ipotesi teardown-only a522c38e falsificata nel run controllato. Il device primario e la sua ritenzione/sessione/outbox restano BLOCKED dal manual-unlock; il PASS unitario non qualifica questi esiti |
| PR18, CI PR/main, merge normale e source-only FF | NON ESEGUITO | PENDING al momento di questo log: acquisire il vero PRHEAD dopo il commit documentale, i run CI PR/main terminali, il merge normale e la FF primaria. La futura receipt di integrazione esterna costituirà la prova finale; nessun hash/esito futuro è inventato |

**Diagnosi SQLite del solo run controllato:** reportb25d7043/freeze d5b98f30, root readback2c4ce151 e addendum834936d6. Tre warning dello stesso PID47318 e dello stesso archivio ritirato ricadono tra `repository.bestEffortCleanup` seq5→6, prima del teardown seq16; gli altri cinque tra teardown16→17 sull'archivio attivo corrente. Il container ritirato registrato è ancora vivo ai campioni di confine. L'ipotesi preregistrata teardown-only a522c38e è **FALSIFIED**. Il source guard `SyncStoreGeneration.swift`779/783/1026–1056 esclude la generazione attiva e il journal resumable ammissibile, limita le eliminazioni e usa `try? removeItem`; non verifica i container aperti o la vita dei worker. Il valore privato resumable non è direttamente osservato e i campioni non sono atomici né completi per tutti i container runtime. Kernel/worker/private cleanup restano UNKNOWN; nessuna prova di innocuità, corruzione o ritenzione primaria. Gli otto warning runtime SQLite sono distinti dai 34 warning legacy di compilazione/Analyze. Nessuna attribuzione retroattiva al vecchio UI147 o alla CI.

**Storico conservato:** Full01 sul949 passa i test, ma la comparazione warning36 contro34 fallisce per i due await superflui DEBUG. Full02/source1d7/HEADda2f resta FAIL reale:1511P/1F/36S, receipt `a9710051`, originale replay UI147; la componente responsabile di quel failure resta UNKNOWN. La probe diagnostica `833009a7` passa ma i suoi otto campi sono NOT_EXPORTED, quindi non prova una causa lease-only storica. Il successivo2UI01 FAIL di sola presentazione UI169/174 è distinto: la diagnostica additiva rompeva la sottostringa originale; il candidato v2 corregge esclusivamente l'ordine e conserva tutti gli assert.

**Limiti:** F autenticato/per-record su Android/iOS/Admin/Mini, H su dataset reale, installazione/ritenzione su device primario e flussi live restano aperti. Il blocco manual-unlock corrente non viene aggirato. Il futuro log documentale non cambia source48, MASTER, workflow, configurazioni protette o input pubblici di compilazione; nessuna receipt o verifica locale vale come DONE globale.

### Esecuzione — 2026-10-06 UTC, guard empty-root durante risoluzione non disponibile e fixture controllata

**Task FIX; nessuna modifica a Planning o criteri.** Il controesempio deterministico usa l'API reale `markResolutionUnresolved`, avvia la qualifica normale nello stesso intervallo e risolve con lo stesso selected shop. Sul controller base il solo assert finale della shell, linea1021, fallisce: **0PASS/1FAIL/0SKIP**, receipt `935ce0a3`, verifica root `fdc614fc`. I controlli originali full7/fence fisico/current scope/old writer negato/container/journal e nove modelli vuoti non segnalano problemi. Questa prova riguarda quel boundary esplicito; la prima causa del failure CI37466894761 resta **UNKNOWN**.

**File e integrazione selettiva:** il primo commit ripristina `ContentView.swift`, `SyncStoreGeneration.swift`, `Task144LocalAvailabilityRootFixture.swift` e `LocalAvailabilityRootUITests.swift` dalla diagnostica temporanea alla base approvata0af; sul Controller aggiunge soltanto il guard iniziale e nel test Atomic esistente le sette righe del controesempio. Il secondo commit contiene soltanto il provider reale della fixture DEBUG approvataV2 e le cinque righe di qualifica nel helper privato zero-reopen. Nessuna nuova API pubblica o dipendenza; helper privati DEBUG soltanto nella fixture; assert e timeout originali conservati. Il Task working foreign `14c11901` resta fuori dallo staging: questa registrazione proviene esclusivamente dal Task HEAD.

**Fix di produzione:** `captureAutomaticScope` usa do/catch. Soltanto `shopContextUnavailable` conserva la candidata `emptyRootProof` dello stesso owner e senza diniego confermato; loadFailure/nil owner/no pending journal/altri errori/diniego la cancellano. L'ammissione della shell richiede ancora scope corrente completo, container/fence fisico e revalidazione. Worker, guard post-await/pubblicazione e autorità writer restano identici.

**Fixture e helper:** il provider è ammesso soltanto dopo start, rilascio trasporto e manifest pubblicato diverso dalla generazione held; il completamento deriva dal vero summary terminale e da tutti i controlli correnti, senza secondo recover manuale. L'osservazione conserva il summary reale prima della qualifica asincrona. Il helper privato awaita la qualifica e richiede la prova corrente prima di restituire la fixture riaperta.

| Check | Stato | Evidenza |
|---|---|---|
| RED mirato del guard | ESEGUITO | 0P1F0S, solo assert1021; receipt935ce0a3/rootfdc614fc |
| GREEN8 esistenti su candidato combinato949 | ESEGUITO | 8P0F0S; receipt5ee82154/rootd235c7f2; exact inverse e preservazione48 |
| Due UI originali con sola fixtureV2 | ESEGUITO | 2P0F0S; receipt6e7283e0/root85935dd6; prova separata dalla combinazione949 |
| Review stabile stesso contesto dati e UX | ESEGUITO | C conferma APPROVED/0 findings su949; dati1791301901, UX1791301949 |
| Nuovo full1548 e Debug/Release/Analyze/warning | NON ESEGUITO | PENDING sul nuovo HEAD reale; Full11 storico non certifica questo nuovo guard |
| Nuovo ProperTEST firmato | NON ESEGUITO | PENDING dopo nuovi full/build/warning; nessun install o lettura configurazione protetta in preparazione |
| Nuova CI, F autenticato, H reale, primaria | NON ESEGUITO | Gate separati; nessuna chiusura globale inferita da fixture o review |

**Freeze e limiti:** sorgenti finali48 `949d95cbc4c9a09420c1798c519e90adbe86a59644221a4312901504d6ed5e45`; 1548 ID ufficiali e 36 skip identici restano attesi, senza filtri. La sequenza dei due commit normali mantiene MASTER/workflow e tutte le modifiche foreign; nessuna causa storica CI o branch automatico dedotta dai soli risultati PASS.


### Esecuzione — 2026-10-06 UTC, pubblicazione shell vuota dopo refresh same-scope

**Stato FIX; fonte48 `0af5b5b6`, HEAD `b4c95eb4` precommit.** Mirati8 **8PASS/0FAIL/0SKIP**; full11 senza filtri/nuovi skip,parallelNO: **1548 ID unici,1512PASS/0FAIL/36SKIP identici,15nativeUI PASS**. Tutti1546ID/stati Full10 preservati e soltanto due nuove unità. Debug/Release/Analyze11 PASS;34warning primari legacy negli stessi sei file della baseline originale d379,zero nuovi e zero nelle48 sorgenti. Proper fullTEST11 Release firmato PASS,23file/profilo154a/fresh signer/entitlements effettivi `.app-Simulated.xcent` ed embedded MachO/vecchia identità keychain/strict-deep;binary `12561c48248fa8180c759bcdd8c1618b9402a266c099e611d86920d72c94e702`, **NON INSTALLATO**.

**File propri:** `SyncStoreGeneration.swift`,solo guard finale di `startEmptyRootQualification`: dopo il lavoro off-main cattura autorità CURRENT con pendingreplacement tipizzato,confronta tutti i sette campi(owner/account/shop/intero store/deviceID/hash/intero pending) con l'originale,conserva cancellation/self/container/manifestnil/diniego/full file-family fence e rivalida CURRENT immediatamente prima della pubblicazione senza await. La proof immutabile usa current scope. Scansione fisica nove tabelle e guard prima/dopo invariati;non concede READY/write né riabilita la vecchia Task126 writer lease. `AtomicGenerationRecoverySnapshotPullServiceTests.swift`: positivo RED byteidentico54cc e negativo byteexact7061 della proposta a98,con fresh VALID shop/device diversi prima della pubblicazione. Eliminando i due blocchi restituisce l'intero vecchio Atomic0efd. UI6fb e altri46source invariati. Stessi due reviewer APPROVED STATIC0af5/zero finding.

**Causa/prova distinta:** nel controesempio reale file-backed,ordinarysameSelectedSave tra start e primo await mantiene sette campi/full fence,current authority valida e old scoped writer DENIED;la sola assertion desired `qualified && shell` falliva con entrambi false(RED1). Guard di pubblicazione ora supera questo caso e rifiuta scope fresco diverso. Le tre failure mainCI82ef restano storiche,**cause esatte UNKNOWN**;la singola osservazione originale3PASS è NOT_OBSERVED,non attribuzione. Diagnostica temporanea rimossa con inverse esatto prima della RED. Messaggi SQLite unlink:120 sia in Full10 sia in Full11,attribuzione UNKNOWN;proposta osservativa2504 NONAPPLICATA/NONESeguita,fuori commit;nessuna dichiarazione harmless.

| Check | Stato | Evidenza |
|---|---|---|
| RED publication e target8 | ESEGUITO |RED1 unica desiredassert;8P0F0S `41c8d2113f16fb66a36ead54d2639fca4710a6307214def9f1d9bd852467eeda` |
| Full11 non filtrato | ESEGUITO |1548ID/1512P0F36sameS/15UI `466968422cca2b1d26dfffa12a833ded5d6c277e5f344cc932753a303e4fea0f` |
| Debug/Release/Analyze11 e warning | ESEGUITO |3exit0,originalbaseline34/nuovi0 `971c839cfcaa1165a236e0fd8db1d72fd26cb23e8e72a90182d7c26bba7cb825` |
| Proper fullTEST11 firmato | ESEGUITO |23file/signature/profile/entitlements/keychainP `7a6e708ff0a751dca300dba50e694098adb41a129b2533afd30b12ac30c02a31` |
| Planning/preservazione | ESEGUITO |Source48/head/MASTER/Planning/foreignTask preservati;ownedgroups0/6B04Shutdown/baselineP;0input/install primaria |
| Nuova CI/F/H/primaria | NON ESEGUITO |FollowupPR/exact-head+mainCI PENDING;F/459/H separati,Mac unlock pendente |

Handoff `ios-empty-root-publication-scope-final-handoff-v11-20261006/manifest.json`;parent soloGit dopo rilascio. Stage Controller/Atomic/due portable docs e SOLO3nuovi hunksTask,inversewhole→5fba esatto;foreignTask73add/19del,net54 fuori index. Nessuna nuova dipendenza/schema/API/framework/task/governance.

### Esecuzione — 2026-10-06 UTC, shell vuota con autorità corrente

**Stato FIX; fonte48 `f0ce09d7`, HEAD7b precommit correttivo.** Mirati6 **6PASS/0FAIL/0SKIP**; full10 senza filtri/nuovi skip,parallelNO: **1546 ID unici,1510PASS/0FAIL/36SKIP preesistenti,15nativeUI PASS**. Tutti1544ID/status Full09 preservati e soltanto due nuove unità. Debug/Release/Analyze10 PASS;34warning primari baseline,zero nuovi nelle48 sorgenti. Proper fullTEST10 Release firmato PASS,23file/profilo154a/fresh signer/effettivo Simulated.xcent/embedded MachO/vecchia identità keychain/strict-deep;binary `97d7d8d409f57c72427359fa237f30f13a28154cd46a17ce0884d56c5501a195`, **NON INSTALLATO**.

**File propri:** `SyncStoreGeneration.swift`,solo `permitsScopedEmptyRoot`: cattura autorità corrente piena con pendingreplacement tipizzato valido, confronta tutti i sette campi stabili con la proof(owner/account/shop/intero store/deviceID/hash/pending),stesso container/assenza manifest/load error/diniego/full file-family fence e rivalida CURRENT alla fine. Non riassegna proof né concedere READY/write. Task126 e writeroriginale sono byte-invariati; la vecchia lease resta DENIED. `AtomicGenerationRecoverySnapshotPullServiceTests.swift`: due metodi aggiuntivi reali file-backed; eliminandoli restituisce tutto il vecchio c7ed. Metodo desiredRED invariato,nuova negativa freshscopeVALID altro shop/store o device con fence identico rifiuta vecchia proof. Tutto il file UI6fb e gli altri46source byte-invariati. Stessi due reviewer APPROVED STATIC f0ce/zero finding.

**Prova causale separata:** before physical9empty/currentproof/shellTRUE/writeDENY; ordinarysave della stessa selezione mantiene sette campi/fence, cambia lease; currentvalid/oldwriterDENY e solo desiredshellTRUE falliva(RED1). Fix mirato supera questo controesempio e i dinieghi pertinent. Main CI d918 aveva due vecchi UI FAIL ma leaf esatto resta UNKNOWN; singolo original diagnostic UI PASS significa NOT_OBSERVED. Nessuna riattribuzione storica o allargamento budget/assert.

| Check | Stato | Evidenza |
|---|---|---|
| RED semantico e mirati6 | ESEGUITO |RED1 unica assertion;6P0F0S `e87ae360430d332b758119d2645fa4dba715586839531a459929b73fb29adb8b` |
| Full10 non filtrato | ESEGUITO |1546ID/1510P0F36sameS/15UI `01540834d9c29e4ecb069034c8259030d74bafd50901b102aca88d5c79ca4954` |
| Debug/Release/Analyze10 e warning | ESEGUITO |3exit0,baseline34/nuovi0 `f60ce56df53c468abb1d3f553da33dd4f7453945f2373b3ac44fe57da8bfd7f0` |
| Proper fullTEST10 firmato | ESEGUITO |23file/signature/profile/entitlements/keychainP `8e344de69c6e1e73e4a4d1a148eabe179f1ce299b0c96141f5c8997ad37c1470` |
| Planning/preservazione | ESEGUITO |Source48/head/MASTER/Planning/54foreign invariati;ownedgroups0/6B04Shutdown/baselineP;0input/install primaria |
| Nuova CI/F/H/primaria | NON ESEGUITO |FollowupPR/exact-head+mainCI PENDING;F/459/H separati,Mac unlock pendente |

Handoff `ios-empty-root-current-scope-final-handoff-v10-20261006/manifest.json`; parent soloGit dopo rilascio. Stage due source+due portable docs e SOLO3nuovi hunksTask,inversewhole→1f1d esatto;54foreign fuori index. Nessuna nuova dipendenza/schema/API/framework/task/governance.

### Esecuzione — 2026-10-06 UTC, fonte finale48 e ACK con autorità corrente

**Stato corrente: FIX; fonte48 `10a15560`, HEAD0757 prima del commit correttivo.** Mirati10 PASS; full09 senza filtri/nuovi skip e parallelNO: **1544 ID distinti,1508PASS/0FAIL/36SKIP preesistenti,15nativeUI PASS**. Tutti1541ID/status Full05 preservati, più soltanto unit ordine reopen, UI replay risposta persa e unit ACK/lease. Debug/Release/Analyze09 PASS,34warning primari baseline/zero nuovi nelle48 sorgenti. Proper fullTEST09 Release firmato PASS,23file/profilo154a/fresh signer/Xcode entitlements/keychain/strict-deep;binary `79931be9fd6f779608e5f2a011e88eee1a0f50cf1f173224416875d5f5df614f`, **NON INSTALLATO**. Ricevute e mapping esaustivo nel manifest finale.

**Tre file di codice/test propri:** fixture DEBUG avvia la normale qualificazione DOPO refresh auth/shop e PRIMA await al reopen; l'oracolo ACK conserva tutte le prove typed sealedA/token/body/key/revisione/CAS/fullscope, replay soltanto prima ACK, evento catalog reale del solo Product e readback corrente ProductACK+Historypending. Il delta finale13righe cattura strettamente l'autorità CORRENTE senza permessi pending, confronta l'intera identità stabile owner/account/shop/store/device, verifica container/qualificazione locale e rivalida questa autorità immediatamente prima true. La lease storica non concede autorità, né si riadotta un vecchio pending. Unità reale file-backed Save→CatalogACK→eventACK→ordinary same-shop save dimostra vecchio writer DENIED/current authority PASS e ACK/body/intento/evento invariati. Tutte144righe di osservazione diagnostica provvisoria rimosse.

AtomicTests aggiunge due prove reali controller/file (ordine reopen e ACK/lease). UI aggiunge UNA regressione autonoma opt-in perdita della prima risposta Product DOPO commit controllato e PRIMA CAS locale; attende40s solo nel nuovo metodo, derivati dal poll automatico esistente30s+10margine. Nessun Retry/manualsubmit/lifecycle/timer/policy change. Rimuovendo il metodo aggiunto si ripristina tutto il vecchio file4f2779;14metodi/assertion/budget5s20s originali intatti. I normali provider faultOFF, live writer/SDK/Ready invariati. Stessi due reviewer APPROVED10a,carry46/UI6fb verificati.

| Check | Stato | Evidenza |
|---|---|---|
| Mirati10 incl. tre lease negative | ESEGUITO |10PASS/0FAIL/0SKIP; `785929f0a037ba62b2c29ab7aa1623693e1c3c846bcc368d7a8d27ed815de227` |
| Full09 senza only/skip | ESEGUITO |1544ID/1508P0F36S/15UI; `1ee87ae4422e10c5ed65f8ed9a04b06b7a226284fec13e6de1025c7ba3a49e5a` |
| Debug/Release/Analyze09 e warning | ESEGUITO |3exit0,baseline34/nuovi0; `fd14aaf1e6c0c207565c92006b6b11eca58d4c5082e0b7ef63d9c20c448197e8` |
| Proper fullTEST09 Release firmato | ESEGUITO |23file/signature/profile/entitlements/keychainP; `bf687605541ab0c6014367dad0c9a7f3aaebc63307f22248354c5c8ca4e9a49b` |
| Scope/planning/preservazione | ESEGUITO |Fonte48/head/baseline invariati,MASTER/Planning intatti,index vuoto,ownedPID/groupgone,6B04Shutdown,0input/install primari |
| Nuova CI/F/H/primaria | NON ESEGUITO |Nuova exact-headCI PENDING;F/459/H separati,Mac unlock pendente |

**Limiti conservati:** CI0757 FAIL e Full06/07/08 FAIL storici non reinterpretati. Full06cause e Full08leaf UNKNOWN; observation1P significa NOT_OBSERVED. Il controesempio committed-loss e la prova ACK/lease sono semantici separati. Negativi privatiRAM variazione/postACK NON ESEGUITI direttamente; reali A/B/sealed/foreign/external/lease PASS. Primo callerCAS UNKNOWN; ACK finale distinto. Locale Xcode27/Swift6.4 non equivale a CI26.6. Durate XCTest non sono performance.

**Handoff:** `ios-current-ack-and-reopen-final-handoff-v9-20261006/manifest.json`; parent soloGit. Stage fixture/Atomic/UI,2portable docs e SOLO3nuovi hunks Task144;inverse wholeworking→8815b979… esatto,54foreign preservati fuori index. Source/heavy/device/input rilasciati soltanto alla consegna finale.

### Esecuzione e fix — 2026-10-06 UTC, fixture CI e diagnostica UI corrente

**Fonte48, HEAD639d prima del nuovo commit, task FIX.** CI37394390166 sullo stesso PR16: Debug PASS, XCTest1541 unici1501PASS/4FAIL/36SKIP; Analyze e secret scan NON ESEGUITI. Una sola esecuzione Task114 fallisce due assertion con deadline fixture50ms ed elapsed71ms; nessuna regressione del timeout prodotto dimostrata. I tre UI falliscono dopo Options→History o soltanto sul marker dopo rilancio; gli allegati remoti non esistono, causa UNKNOWN. Non si deducono perdita del Save, failure del callback o colpa del parallelismo/toolchain.

**File modificati:** `SupabaseManualSyncViewModelTests.swift` usa il default ordinario12s soltanto nel positivo di esito, mantenendo didRun/callCount/completed e il negativo sospeso5ms byte-identico. `LocalAvailabilityRootUITests.swift` conserva assertion e budget5s/20s; in failure raccoglie tabs/facts/admission chiusi nel namespace controllato più AX/PNG correnti. `Task144LocalAvailabilityRootFixture.swift` aggiunge soltanto accessibilityValue categorico alla ProgressView di preparazione DEBUG; nessuna modifica a scope, autorizzazione, Ready, recovery o dati. Gli altri45 file sono byte-identici a HEAD639d.

**Evidenze:** target5 originali5PASS su Xcode27.0; classe nel medesimo ordineCI più due unitari8PASS. Quest'ultima usa UI33e08; segue soltanto stdout diagnostico nel failurehelper, e la fonte finaleUI4f2779 è coperta dal full05. Stessi due reviewer APPROVED sul freeze48 `5f461eed…`/patch `04af888e…`. La CI originaria Xcode26.6 resta FAIL e la causa UI resta non attribuita; non è dichiarata chiusa dalla riproduzione locale.

**Check obbligatori:**
| Check | Stato | Evidenza |
|---|---|---|
| Full XCTest canonico, nessun filtro/nuovo skip | ESEGUITO | full05:1541 unici1505PASS/0FAIL/36SKIP,14 native UI PASS; ID→status/skipset identici full04; receipt `dc3ca6af…` |
| Debug/Release/Analyze | ESEGUITO |3 comandi exit0,receipt `470756e8…`;34 primary warning baseline,0 nuovi nelle48 sorgenti |
| Proper fullTEST Release firmato | ESEGUITO |receipt `415a6f56…`,23 file,profilo154a/firma strict-deep/Xcode entitlements/keychain PASS; binary2795dc09,NON INSTALLATO |
| Planning e preservazione | ESEGUITO |MASTER/Planning intatti,source48/head/baseline invariati,6B04 Shutdown,owned process groups rilasciati;config primaria intatta |
| CI nuova exact-head e F/H/primaria | NON ESEGUITO |parent soloGit/CI;F autenticato,install/retention primaria459 e H separati,NONE inferiti da fixture |

**Handoff:** pacchetto esterno `ios-ci-current-runtime-final-handoff-20261006/manifest.json`; soltanto3 source delta,2 portable docs e i tre nuovi hunks Task144. Inverse dei tre restituisce08321017… esatto,54 insert foreign intatti. Nessuna mutazione Git/device/input primario da questa lane. Questo blocco prevale sul precedente snapshot47/full04/proper04.

### Esecuzione R-I08 — V6 tutti gate locali verificati, handoff Git — 2026-10-03 UTC

**File modificati:** solo questo task (Execution/Fix/Handoff) e metadata portabile in `EVIDENCE/TASK-144/ri08-ordinary-sync-state/`. Nessuna modifica app/test/resource/build/SDK/schema; source326ac3b, Atomic98fd, Planning raw6662, statoFIX e Master invariati. Nessun runtime, Git o lettura di payload protetti da docs producer.

**Azioni eseguite:**
1. Direct host handoff SHA`3d232810b3bba3d36bc48342176759e93864cf7aaebe8f2864f3624b242de2c5` e review indipendente SHA`16011f3e2fde86181a9a00af345e63043ebfde91e2c96f18102798698a5aca98` autorizzano la delivery dei tre gate osservati sullo stesso326ac3b/freeze8208/baseHEAD414c. Tutti receipt metadata copiati byte-identici; nessun binario/configurazione/xcresult portato in Git.
2. TEST firmato PASS: command114.287514s, release23:44:30.669332 UTC;23file, binary`2783283d728eb5ea8c5bddafa52b231c971514055d260d99194e67189173525a`, strict/deep e embedded entitlements uguali al generated esatto2key. Profilo TEST autorizzato verificato solo per blindhash; primary86a invariata e copia ignorata own rimossa. Receipt22a12c64/ownrelease43189d82.
3. Release canonico non configurato PASS:112.900531s, release23:48:48.878953,22file, binary`c798c79e9a08f5ff4ee88a9dd906f1436be8f0182bd3a68a44980db0fb7eadbb`, firma strict/deep ed entitlements generated esatto2key. Receipt4e0d9798. Analyze PASS:47.387659s/release23:49:36.371917, receipt8557dece. Tre GO/intervalli separati, no retry, gruppi1653/4671/5983 registrati assenti/signals[], source326/build3/cache13 e configabsence invariati. Reviewer riconcilia savedmetadata, non compie nuovo runtime/binary audit.
4. Analyze conserva26signature source(18Vendor/8testSwift),34occurrences architecture(26x86_64/8arm64), esatto multiset path/line/column/message/architecture R-I06 normalizzando soltanto checkoutprefix. Zero nuovi o rimossi; nessuna legacy warning dichiarata riparata. Metadata AppIntents conservata signed1/Release1/Analyze3. Full conserva1QoS storico e36skip/reason esatti.
5. Ledger locale finale `EVIDENCE/TASK-144/ri08-ordinary-sync-state/validation-ledger.json` consolida full1428PASS/36sameSKIP/0FAIL/1464ID(57Atomic/23new/8UI) e mirati5PASS/19stage, più tre artifactgate. Draft precedente e6rawfailure qualification/hash preservati; nessun nuovo full/mixed239.

**Check obbligatori:**
| Check | Stato | Note |
|---|---|---|
| Full build/XCTest | ESEGUITO |1428PASS/36sameSKIP/0FAIL/1464unici, fullreview e374;57Atomic/23new e8UI PASS. |
| Release canonico | ESEGUITO | Actual112.900531s,22file/strictsignature; receipt4e0d e review16011. |
| Analyze | ESEGUITO | Actual47.387659s,26legacy/34occurrences invariati,0nuovi; receipt8557/review16011. |
| Warning nuovi | ESEGUITO | Exact source-signature/multiplicity comparison; QoS/tool/legacy non nascosti né dichiarati risolti. |
| TEST firmato | ESEGUITO | Actual23file/binary2783283d/strict2/primarypreserved/owncopyremoved, receipt22a12 e review16011. |
| Coerenza Planning | ESEGUITO | Source/Planning666 invariati; source reviewa606 e actual full/artifact review separati. |
| Criteri di accettazione | NON ESEGUITO integralmente | Gate locali finali completati; exact commit/PR/headCI/normalmerge/mainCI e residui live/performance restano al root/owner. |

**Baseline regressione:** full include tutti1441ID precedenti più23Atomic,1464unici;36skip live/opt-in invariati e ragioni portabili. Unit/integration distinti dagli8XCUITest.

**Incertezze:** i gate sono sul source congelato non committato al baseHEAD414c. Root deve attestare l'equivalenza326source/build3 dopo il nuovo commit prima di collegare artifact/CI; nessun postcommitbuild, auth/recovery business/convergenza/performance o DONE non avvenuto è documentato.

**Handoff notes:** soleGit root procede con exactsource PR/CI/merge normale e mainCI, mantenendo artifact/rawfailure storici. Il ledger locale è finale per questo scope; la chiusura globale resta distinta.


### Esecuzione R-I08 — V6 full1464 actual verificata, delivery documentale parziale — 2026-10-02 UTC

**File modificati:**
- `docs/TASKS/EVIDENCE/TASK-144/ri08-ordinary-sync-state/` — slice portabile corrente: 1464 method-status esatti e 36 skip reason, summary e receipt indipendenti full/mirati5, freeze326/build3/cache13. Ledger `.draft.json` non finale in attesa delle ricevute formali dei tre artifact gate. Nessuna copia di binari, xcresult o configurazione protetta.
- Questo task, soltanto Execution/Fix/Handoff; Planning raw666282 e statoFIX preservati. Master e tutti326 file app/test/resource restano invariati.

**Azioni eseguite:**
1. ONE primary completo START23:32:20.633478→END23:39:09.343733 UTC, 408.710255secondi; release23:39:10.217542. **1464 ID unici: 1428 PASS,36 SKIP,0 FAIL.** Unit/integration1456=1420PASS/36SKIP; UI8=8PASS/0SKIP. Tutti57Atomic e23nuovi PASS; tutti1441ID storici e36skip/reason invariati. Nessun duplicatedfull/mixed239 o nuovo runner da docs producer.
2. Tree ufficiale e riconto indipendente `e374a5821b718d8e7ef49843fa50bb799df2df155ba3ec4375bf8905885db049`; logc40c99dd/summary131abaaa/tree2d44608a conservati in `evidence/ios-ri08-ordinary-sync-state/full1464-v6-attempt01/`. Receipt primaria f45157fc registra source326ac3b/cache13 invariati, ownPG97804 assente/signals[], Shutdownreadback e release entro deadline. Normalshutdown149 già-Shutdown è conservato senza relabel0.
3. Diagnostiche della sola invocazione:0source diagnosticheaders,1QoS runtime con messaggio identico alla summary storica R-I06. Warning e36skip restano espliciti; nessuna affermazione di rebuild completo o riparazione della baseline. MiratiV6 precedenti5PASS/0FAIL/0SKIP e19stage formali fcba2f43 già documentati.
4. Preparati portabilmente solo fatti full/targeted attuali. SIGNED/Release/Analyze non vengono dichiarati PASS prima della direct3receipt/review; ledger finale ed equivalenza Git/CI restano al successivo handoff root dopo quei gate. Raw precedenti failure e qualifiche restano preservati, nessuna receipt storica riscritta.

**Check obbligatori:**
| Check | Stato | Note |
|---|---|---|
| Build/test iOS Debug completo | ESEGUITO |1464unique/1428PASS/36sameSKIP/0FAIL, e374 indipendente; stesso codeac3b. |
| Analyze/Release/TEST firmato finali | NON ESEGUITO integralmente nella delivery formale | Attesa direct3artifactreceipt+review; nessun PASS inventato. |
| Warning nuovi | ESEGUITO per full |0source diagnostics e1QoS storico nella saved invocation; gateAnalyze/Release distinti. |
| Coerenza con Planning | ESEGUITO per R-I08 sorgente/full | Planning raw6662 invariata; source reviewa606 e fullreceipt e374 sullo stesso326ac3b. |
| Criteri di accettazione | NON ESEGUITO integralmente | Regressioni R-I08/full verdi; artifact3, exactCI/normalmerge/mainCI/live/performance ancora da registrare nelle rispettive lane. |

**Baseline regressione:** full completa include vecchi1441ID,57Atomic e adiacenti; unit/integration distinti dagli8XCUITest. I36test condizionali non sono accettazione live.

**Incertezze:** reviewfull verifica solo questa ONE e le savedreceipts; nessun nuovo controllo runtime/device da reviewer/docs. Questa delivery è parziale, non ledger finale o DONE.

**Handoff notes:** rootsoleGit verifica equivalenza exactcommittedsource e head/mainCI dopo gli artifactgate sulla versione finale; nessun postcommitbuild o merge non avvenuto è registrato.


### Fix R-I08 — fence avanzato e continuazione zero finalizzata v6, 2026-10-02 UTC

**File modificati:**
- `iOSMerchandiseControl/Sync/Account/AccountBindingStore.swift` — dopo restore verifica cursor effettivo/generation/mirror; se strettamente avanti alla fullfinalization conserva solo la fence già valida allo stesso cursor/account/shop/device/scope. Missing/corrupt/foreignScope falliscono chiusi senza coniare fence; cursor uguale mantiene repair dalla finalization.
- `iOSMerchandiseControl/Sync/Automatic/Pull/SyncEventIncrementalDomainApplyService.swift` — issuer/consumer leggono la fence di continuazione0 sotto gli esistenti guard reali controller/finalization/ACTIVEcontainer/managedlease/currenttyped/mirror/journal/localwork/cancel. Nessuna nuova catena receipt o publisher/globalflag.
- `iOSMerchandiseControl/Sync/Remote/ShopScopedIncrementalRPC.swift` — unico accessor locale read-only `continuationScopeKey` riusa validatedRecord e verifica generation tipizzata/mirror; getter generico scopeKey>0 e tutti metodi wireRPC/adapter/backend restano invariati.
- `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift` — ZEROhelper bilancia owned cancelAndWait/resume solo in success/catch. Due nuove regressioni realpipeline per advanced42 fence missing/corrupt/foreignScope e full0/reopen0 con typedrecord assente/corrotto.

**Azioni/evidenze:**
1. Actual V5 ONE22:24:54.025385→22:25:31.693532/release22:25:32.242642,3uniqueFAIL/0PASS/0SKIP/18assert e13stage. Source326e192/cache invariati/ownPG78919 assente/signals[]/Shutdown. Full0 reale di entrambi ZERO ora success/verifiedtrue/activation/finalization/journalfalse con2checkpoint/6pagine. Primo canonicaldelta0→1 realmente success/wm1 ma receiptfalse/Required e poll soppresso: production ordinaryzero RED. Freshopen direttamente typed/scalar42+validfence42 prima→typed/scalar42+validfence41 dopo, immutabilefull41/stessagen/account/device/journalfalse; nuova Facade entra e registraBLOCKED prima provider. Independent actual289ec3db preservata.
2. Initialempty0 V5 invece busy/checking/event/count/tail0: CONTINUATION_NOT_REACHED. Sourcechain ZEROcatch515 cancelAndWait sospende processShared e manca resume, mentre setupbootstrap usa un gate privato. Cleanup lifecycle corretto soltanto nelle due uscite; nessun resetstart/retry/allentamentoGate né attribuzione busy al >0guard. La prossima vera noEvents0 deve leggere freshcount+boundedtail.
3. Root Planning666282/decision54709 prima dell'Execution. Delta minimo3prod+test rispettoV5,322altri file invariati; tutti55methodIDs/corpi e ogni assert precedente byte-identiciV5. Nuovi2metodi portano Atomic57: full41+delta42 autentico poi3faultfence/reopenreject senza rollback/mint; realfull0+reopen0 poi2typedfault e veroemptyprovider/noReceipt/Required/datepreserved. Generic scopeKey0 resta nil; accessor qualified richiede typedrecord valido. Guard localpending/countdrift/cancellation/registeredgen/genuinejournal esistenti riusati, nessuna loro modifica.
4. Pacchetto immutable `implementation-static-v6`: source326ac3ba92d, freeze82085193, delta d5f36563, invariance6d19331f,32copie baseline before/after più4inputV5 e inverse interifile. Card5selector=V5RED3+newnegative2 (5ID dichiarati, nessuna promessaPASS); namespace `targeted5-v6-attempt01` vuoto. Launcher derivato solo6binding da V5/ASTstatico,25min/min19/reserve90/ONE ownerDIRECT dopo review+freshGO; nessun runner dal producer.
5. Clock sintetico currentwholeSecond/proiezioni read-only V5 restano; i vecchi DateFAIL sono conservati e nessun codec/timestamp business di produzione si dichiara corretto. APIaudit source-only/namedcalls disponibile; non è compilazione.

**Check/Handoff:** Planning/invariance/API ✅ statiche; compileV6/5test funzionali ❌ NON ESEGUITI. Atteso reale freshopen42fence42 preservato poi43, authoritativeempty0freshcount/tail/noCatalog e canonical1/noEvents1, più tutti nuovi guard failclosed. Gate completi/Release/analyze/TEST/CI/live ancora aperti; task FIX, nessun DONE. Source HOLDac3b per review indipendente.


### Fix R-I08 — caller recovery empty0 e proiezione riapertura v5, 2026-10-02 UTC

**File modificati:**
- `iOSMerchandiseControl/Sync/Automatic/Recovery/AtomicGenerationRecoverySnapshotPullService.swift` — solo checkpointB passa keynil quando A.maxId strictcanonical è `0`; baseline positive conservano la key esatta di A.
- `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift` — osservazione read-only `RI08_REOPEN_METADATA` prima/dopo la riapertura; decoder bounded della fence usa il cursor memorizzato e restituisce solo numeri/bool/null. I nuovi helper ordinary/ZERO registrano il risultato della recovery reale con now al secondo corrente intero, mantenendo tutte le uguaglianze Date esatte.

**Azioni/evidenze:**
1. Actual root ONE mixed237attempt03 compilato:21:47:16.214670→21:47:50.231420/release21:47:50.724199,237ID unici234PASS/3FAIL/0SKIP. Source326b48/cache13 invariati, ownPG56182 assente/signals[] e own6B049 Shutdown. Log2adc9caa/summaryf79b78cb/independent5de5606e preservati. Due ZERO sono EMPTY0_RECOVERY_FUNCTIONAL_RED: A0/nil +6pagine vuote, failure locale scopeFenceMissing prima del transportB; nessuna activation/finalization, journal conservato, continuation0 NON RAGGIUNTA.
2. I due percorsi ordinari42→43 e41empty→42→43→empty43→44 superati nel run reale. Freshopen: primo42 reale success/idle/stock1/wm42; nuova Facade entra e registra un risultato blockeddeviceNotActive sul trigger43, prima di provider incremental/engine; stock1/wm42 conservati. Non è prova che il dispositivo sia realmente inattivo. L'inferenza sorgente restore same-generation42 conservato/fence41 riscritta richiede ancora la nuova proiezione reale, senza reset readiness o write di fixture.
3. Clock Date: StateStore mantiene il Date live, persiste UnixDouble e ricostruisce Date da UnixDouble; identico epoch stampato con strictDate differente. Precisione reference/Unix è spiegazione sorgente, non delta di bit runtime misurato. Solo clock sintetico degli helper al secondo corrente intero; nessun codec/timestamp business/autorità di produzione modificato e nessuna tolleranza.
4. Planning root82569/decisionff3dc prima dell'Execution. V5 source326e192e2a7; solo2file rispettoV4,324altri invariati e tutti12file production del boundary precedente identici. Tutti55methodIDs/corpi e ogni riga di assert esistente identiciV4;37originali e tre metodi V4 preservati. Inverse intero dei2file e28copie before/after, patch/invariance/APIaudit fuoriGit in `implementation-static-v5`. Accountrestore, Watermarkrestore, adapter/RPC, Domain>0 e FenceStore>0 invariati.
5. Nuova card3selettori esatti: ZERO2+freshopen,3ID dichiarati senza promessa GREEN. Launcher derivato solo6binding dal V4 rivisto, AST statico; namespace `targeted3-v5-attempt01` creato vuoto. Owner/root unico esecutore DIRECT dopo review e fresh25min/min19/reserve90/ONE; nessun runner avviato dal producer.

**Check/Handoff:** coerenza Planning/invariance/API ✅ statiche; compilazione V5 e i3risultati funzionali ❌ NON ESEGUITI. Proiezione fence42→41 e continuation0 restano da osservare dopo recovery0 effettivamente attivata/riaperta. Suite completa/Release/analyze/TEST/CI/live restano aperti; task FIX, nessuna chiusura.


### Fix R-I08 — API della nuova fixture v4, 2026-10-02 UTC

**File modificato:** `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift` — nella sola nuova regressione `testOrdinaryContinuationRejectsReplacementContainerAndOtherDefaults`, sostituito il nome inesistente recoverSnapshot con il vero recoverFromRemoteSnapshot(ownerUserID:), conservando await/try/argomento. Nessun alias produttivo aggiunto.

**Evidenze e verifiche:**
1. Actual root ONE mixed237attempt02,21:31:39.735378→21:31:57.307080/release21:31:57.811244, officialsummary0test/unknown, unico errore testAPI258 nel logbe3a06b1; nessuno stageZERO o XCTest. PG51123 assente/noSignals, solo own6B049 Shutdown/source326/cache13 invariati. Review indipendente56d5c30a: COMPILE_FAILURE_NOT_FUNCTIONAL_RED. I due errori Predicate e quattro Domain selfwarnings precedenti sono assenti in questo specifico log, che conserva6 altri warning; nessun build/testPASS dedotto.
2. Cambiamento test-only autorizzato Planningcb676/raw43e7. Delta esatto `2cbe35a5`, inverse intero file byteequalV3;55methodIDs e tuttiassert/54altri corpi/37originali preservati.325altri sorgenti e intera produzione V3 immutati; nessun fix ZERO, skip, timeout o probe compilatore.
3. Freeze v4 `adb0d457`, source326 `b48b98ca`, test `1e2f0620`, invariance `0561dd59`, fullpatch `dfe8302d`; card `bdcdde61`, launcher AST-only `897d1fe4`, request `33b4a7ef`.237ID/22selector e tre build input/cache13 stessi; attempt03 creato vuoto; ownership/finally/25min/min19/reserve90/ONE invariati. Review e GO freschi richiesti, root mantiene supervisione esclusiva.
4. Audit sorgente bounded delle altre chiamate nuove sui simboli reali: controller/lease/scope/fence/watermark, engine/policy/facade/domain, pending/outbox/history, mutation accumulator, catalog push/registrazione e schema. Nessuna ulteriore API mancante trovata in questo controllo; non è una prova di compilazione o runtime. Il metodo reale è definito AtomicGenerationRecoverySnapshotPullService123.

**Check/Handoff:** coerenza Planning e invariance ✅ statiche; compilazione test/SQL Predicate/235GREEN/2stageZERO ancora ❌ NON ESEGUITI nel nuovo freeze. Task FIX, nessuna chiusura. Evidenza esterna `implementation-static-v4/static-review-request.json`; produzione, adapter/RPC/fence e capture>0 immutati fino ai RED funzionali relativi.


### Fix R-I08 — integrazione compilatore v3, 2026-10-02 UTC

**File modificati:**
- `iOSMerchandiseControl/Sync/Automatic/Recovery/SyncStoreGeneration.swift` — stesso predicato outbox fail-closed, espresso come `!terminalOutboxStatuses.contains(entry.statusRaw)` con array immutabile degli stessi sei stati e `#Predicate<SyncEventOutboxEntry>` esplicito; fetchLimit1 e pending/history guard invariati. Per ogni raw String nonoptional, negated membership è equivalente alla precedente congiunzione di sei disuguaglianze; unknown/malformed/case diversa restano bloccanti.
- `iOSMerchandiseControl/Sync/Automatic/Pull/SyncEventIncrementalDomainApplyService.swift` — holder privato nonisolated immutabile ristretto delle sole dipendenze defaults/WatermarkStore per i due MainActor.run. `@unchecked Sendable` riguarda la coppia UserDefaults-backed read-only thread-safe, seguendo i box già presenti: preserve esatto defaults e value-copy dell'esatto watermarkStore iniettato, costruzione prima dell'await, nessuna capture dell'intero servizio o ricostruzione store. Authority/cancellation/container/controller/fence/ZERO >0 invariati.

**Azioni ed evidenze:**
1. Il ONE mixed237attempt01 del root ha restituito exit65 con officialsummary0test: COMPILE_FAILURE_NOT_FUNCTIONAL_RED. Avvio21:03:58.780201, fine21:04:12.844854, release21:04:13.313196; gruppo38545 assente/noSignals, ownShutdown readback/source326/cache13 invariati. Log `872b2fcc`/rawresult preservati. Nessuna prova235GREEN/2RED dedotta da questa invocazione.
2. Diagnostica: typechecktimeout del #Predicate1460 e genericT1466 in cascata; quattro warning self non-Sendable786/791/815/819 nei due nuovi actorhop. Correzioni minime autorizzate Planning15a0/rawf679, senza fix funzionale checkpointB0/key o receipt0.
3. Nuovo freeze v3 `8445a677`, source326 `f71a3f45`, delta2file `8a63ea9c`, invariance `605c8af3`: 324 altri sorgenti byteequal a v2, intero test55 `392b6655` e237ID/22selector immutati. Capturecontract/exactsix e inverse dei due file salvati; nessuna nuova dipendenza/schema/config/SDK/probe.
4. Card `6e56a81a`, launcher AST-only `c001cc6f`, request `4c3228da`, attempt02 creato vuoto. Derivazione323 del launcher cambia solo bindings/schema/status e path card; ownership/newPG/finally/normalownshutdown/25min/min19/reserve90/ONE senza retry invariati. Prime metadata v3 `9f6794a4`/card57bc/launcher1fde preservate in archive: correction metadata-only delle invariance ereditate da v2, senza nuovo source delta.

**Check obbligatori / Handoff:**
- Coerenza Planning: ✅ staticamente verificata rawf679; tutti55corpi/assert e guard ZERO/generici118119 invariati.
- Nuova build/test/SQL predicate/warning assenza: ❌ NON ESEGUITI in v3; i quattro warning sono storici reali, la loro rimozione richiede il prossimo compiler. Static review e nuovo GO necessari; niente retry sul GO consumato.
- Criteri finali/firma/CI/canonici/autenticata: ancora non completati, task FIX. ROOT è solo supervisore del prossimo ONE; producer static-only.


### Esecuzione R-I08 — boundary tipizzato v1 e regressioni empty0 v2, 2026-10-02 UTC

**File modificati:**
- `Sync/Automatic/Pull/SyncEventIncrementalDomainApplyService.swift`, `SyncIncrementalPullSummary.swift`, `SyncEventIncrementalPullService.swift` — receipt interna emessa soltanto dalla vera applicazione completa o stable noEvents/self ACK, con scope/generazione/fence/watermark/conti freschi/tail e lavoro locale drenato; unknown e blocchi non emettono autorità.
- `Sync/Automatic/Core/AutomaticSyncEngine.swift`, `SyncAutomaticRunResult.swift`, `AutomaticSyncCancellationPolicy.swift` — propagazione solo nell'aggregato compatibile finale e fencing del token del run originario; factory generiche restano senza receipt e verifiedConvergence ordinaria resta false.
- `Sync/Automatic/Presentation/SyncStateStore.swift` — stato interno plain e objectWillChange prima della lease; revalidation e decisione sincrone senza callback sotto lock, lettura corrente qualificata della receipt; autentico recoveryRequired/journal/pending/cancel dominano. Nessun consumo `$state` della SyncStateStore trovato; API di stato e comportamento generico118/119 conservati. Questo cambiamento interno evita reentrancy/deadlock e stale idle tra lease invalidation e pubblicazione.
- `Sync/Automatic/Composition/AutomaticSyncRuntimeFactory.swift`, `Sync/Automatic/Background/SyncBackgroundTaskScheduler.swift` — controller realmente acquisito, senza singleton assunto.
- `Sync/Automatic/Pull/WatermarkStore.swift`, `Sync/Automatic/Recovery/SyncStoreGeneration.swift`, `Sync/Policy/Task126SyncPolicy.swift` — accessor read-only generation-bound e registry active esistente, tre letture locali fetchLimit1. Nessuna chiave/schema/dipendenza/SDK nuova; nessun costo SQL costante inferito dal limite di materializzazione.
- `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift` —16 regressioni della receipt reale oltre37 metodi preservati; due ulteriori regressioni della recovery vuota0, con servizi/runtime/orchestrator effettivi e remote sintetico qualificato. Tutti53 corpi/assert v1 e altri325 sorgenti immutati nel delta v2.

**Azioni eseguite:**
1. RED V4 ufficiale confermato indipendentemente:3 FAIL/22 assert/6 stage reali, source326/cache13 invariati, ownPG assente/Shutdown/release entro deadline. Receipt producer0849bc43 e reviewa4fa61fd nel pacchetto esterno. Le due prove evento usavano il DTO legacy accettato dall'app; il noEvents41 è indipendentemente canonico. Qualificazione88ed/07deef preserva i raw e cambia soltanto il helper futuro in catalog_changed.
2. Implementato il confine minimo autorizzato dopo RED; freeze v1 `6e3b5008`, source326 `f995824e`, patch `408da472`.12 file produzione e un test; original37 method/assert byteequal,118/119 immutati. Review statica v1 positiva salvo candidato cursore0; nessuna compilazione/GREEN ancora attribuita al delta.
3. Prima di qualunque fix0, preparati due test desiderati real file-backed: canonical empty0 recovery, release del vecchio controller/riapertura, poi noEvents0 oppure primo catalog_changed1/noEvents1. La review del sorgente ha isolato checkpointA0,nil valido e checkpointB0,key rifiutato dall'adapter prima del secondo transport. Un fallimento ufficiale corrispondente dopo A0 e sei pagine sarà `FUNCTIONAL_EMPTY0_RECOVERY_RED`, con continuation `NOT_REACHED`; compilazione o mismatch fixture non valgono RED. Nessun bypass del servizio/adapter o guard produttivo cambiato.
4. Remote ZERO dedicato `NOT_ACTUAL_V6_RPC`: legge solo il fence sintetico realmente scritto dalla recovery e valida schema/checksum/owner/shop/device/cursor, senza scrivere autorità nel setup. Il callback normale di commit mantiene il fence dopo eventi applicati. Readback typed/scalar0, baseline/finalization/journal e stage effettivi sono distinti dall'esito del drain.
5. Freeze v2 `8b38dfd4`, source326 `cb29a93e`, test `392b6655`, delta test-only `78b223e1`, invariance `5b1ce8c1`; Planning raw0b1431d8 preservata. Card mixed237 `8af07efc` e launcher AST-only `32376335` richiedono review nuova e GO esplicito fresco.237 è numero nominale di identità sorgente:235 guard esistenti/current intended GREEN +2 nuove regressioni empty0 desiderate; non una promessa allGREEN. Own destination6B049, stessi13 cache/tre build input, ONE/no retry,25min/min19/reserve90. Nessun runner avviato.

**Check obbligatori:**
| Check | Stato | Note |
|---|---|---|
| Build Xcode / test pertinenti | ❌ NON ESEGUITO | Nuovo freeze richiede static review e nuovo GO; nessuna compilazione dedotta dal solo sorgente. |
| Analyze / warning nuovi | ❌ NON ESEGUITO | Gate runtime finale distinto; hash/build input preservati. |
| Coerenza con planning | ✅ ESEGUITO statico | Implementazione autorizzata8bcc e precisazioni; Planning corrente raw0b1431d8. |
| Criteri di accettazione | ❌ NON ESEGUITO finale | CA-07/09/10 ancora da confermare con mirati/canonici/firma/CI e collaudo autentico; task non DONE. |

**Incertezze / Handoff notes:**
- Formalità review/compile/GREEN/ZERORED pendenti; nessun nuovo controllo a zero autorizzato in produzione prima del relativo RED reale.
- Evidenza esterna `/Users/minxiang/.codex/worktrees/mobile-parity-root-cause/evidence/ios-ri08-ordinary-sync-state/implementation-static-v2/static-review-request.json`; root mantiene Planning/Git/supervisione del runner. Nessuna configurazione protetta, auth live, DB reale, device estraneo, dependency download o retry in questa preparazione.


### Preparazione R-I08 v4 — prova esplicita zero lookup, 2026-10-02 UTC

**File modificati:** solo i nuovi test/helper Atomic. Contatore incrementato all'ingresso fetchCatalogByIDs prima delle guardie, osservato nella riga numerica RI08_ACTUAL; poll iniziale41 richiede count0 e invariato, poll corrente43 richiede count invariato. Nessun nuovo scenario, richiesta sintetica di no-op o guardia allentata. Fonte/card/launcher v3 conservati; v4 distinta con medesimi3 selector, binding nuovi e guardie launcher approvate invariate. Originali34/helper, altri325/tutti207 applicativi/118119 e Planning68f85 invariati. STATIC/invarianza ESEGUITO; compilazione/runtime V4 NON ESEGUITI. Nessuna produzione; review del solo delta e nuovo GO necessari.

### Esecuzione R-I08 v2 e preparazione v3 — 2026-10-02 UTC

**Runtime v2 autorizzato:** una sola invocazione dei due selector, source326 `fbd1cc01…`, test `0562e598…`, card `fba715fb…`, launcher `889955c8…`. START19:04:19.944784 UTC, xcodebuild exit65 alle19:05:06.249329. Compilazione PASS, nessun warning nel nuovo sorgente Atomic; XCTest ufficiale2 unici FAIL/0 PASS/0 SKIP. Entrambi restituiscono first runtime failed/invalidPage(products), stock0 e watermark41 invariati: **errore del contratto fixture, non RED funzionale del finding**. Non autorizza produzione. Raw log/bundle/summary, sorgente v2 e ricevute conservati.

**Causa verificata:** CatalogIncrementalApplyService effettua sempre la seconda fetch delle relazioni con productIDs=[]; il prodotto senza supplier/category rende tutte le richieste vuote. La fixture rifiutava la richiesta perché imponeva productIDs=[product.id] a ogni call. Correzione v3 solo test: ritorno di tre array vuoti per questa richiesta all-empty dopo le medesime guardie owner/shop/current scope fence; qualsiasi nonempty sconosciuto resta rifiutato. Nessuna modifica DTO/unknown-field/timestamp/scope o guardie produzione necessaria.

**Rilascio effettivo:** proprio gruppo93268 assente, signals=[]; shutdown normale proprio6B049/iOS26.2 e readback Shutdown, cache13/source326 immutati. RELEASE19:05:06.679765 UTC prima della deadline19:28:11.198802. Adjudication ufficiale `a5d216b0…`. Nessun retry o install/E2E autentico; slot v2 consumato e rilasciato.

**Preparazione v3 autorizzata root:** stessi due percorsi ordinary/fresh-open più regressione separata: recovery verificata41→poll vuoto reale noWork/unverified, stock0/wm41/journal0/fence corrente→42/43→secondo poll vuoto corrente43→terzo delta44. Il primo noWork identifica autonomamente il latch prima dei delta. Ogni fase conserva lastVerifiedAt e verifiedConvergence=false; vuoto e conteggi uguali non diventano prova globale. `RI08_ACTUAL` stampa solo osservazioni effettive di risultato/fase/stock/watermark/journal, distinguendo setup/failure dal percorso valido. Stesse guardie e cleanup v2. Il nuovo comando preparato seleziona esattamente3 casi; originale34/helper e altri325 input/tutti207 applicativi/test118119 invariati. Planning root68f85 invariata dall'executor.

**Check:** v2 BUILD ESEGUITO/PASS; v2 XCTest ESEGUITO/FAIL fixture distinto da finding. V3 STATIC/invarianza ESEGUITO; V3 compilazione/RED NON ESEGUITI, nessuna produzione. Freeze/card/launcher v3 separati, review indipendente e nuovo GO richiesti. Stima prudente6–12min, senza promessa dal precedente comando47s; maxslot25min/min19 residui spawn/riserva90s/ONE comando senza retry.

### Preparazione R-I08 — continuazione automatica, 2026-10-02 UTC

**File modificati:**
- `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift` — due nuove regressioni e helper confinati al test. Recovery reale SwiftData a disco tramite AtomicGeneration/engine, sessione SDK sintetica in memoria con URLProtocol che blocca ogni rete, decision provider/runtime facade/engine/pull/domain/state/orchestrator reali. Due eventi catalogo validi modificano stock0→1→2; seconda variante riapre controller/store e reidrata lo stato prima del secondo trigger. Gli helper precedenti e i34 casi originali restano byte-identici.
- Questo task, sola sezione Execution — preparazione e limiti. Planning/CA/master invariati dall'executor.

**Azioni:** freeze iniziale326 sorgenti/fixture identico al source R-I07 `9b427570…`; tutti207 input applicativi invariati. Il risultato verified iniziale proviene dalla recovery engine effettiva, non da un flag costruito per il test. Ogni evento ordinario deve conservare verifiedConvergence=false e lastVerifiedAt originale, ma restare automaticamente ammissibile; readback del prodotto, binding/generation, fence/watermark, journal/pending/outbox e contatori dei precedenti snapshot verificati. Nessun risultato sync fabbricato dagli adapter. Tutti i test118/119 generici e i precedenti casi Atomic conservati. Sono fixture locali sintetiche, non acceptance live.

**Check:** STATIC/preparazione ESEGUITO; BUILD/XCTest RED NON ESEGUITO, serve nuovo GO host. Nessuna modifica produzione, comando Xcode, boot, DB/runtime, auth o rete effettuata nella preparazione; nessun DONE. La riapertura mantiene altri handle del test e non è presentata come riavvio del processo. Eventuali errori di compilazione futuri restano esiti distinti dal RED funzionale.

**Handoff:** root/reviewer verifica delta, freeze e comando; solo un nuovo GO autorizza il runner. Dopo RED ufficiale root approva il confine tipizzato minimo e l'eventuale patch. Task FIX, nessuna autorizzazione runtime dedotta dalle prove storiche R-I07.

### Preparazione R-I08 v2 — pubblicazione e pulizia fixture, 2026-10-02 UTC

**File modificati:** solo i due nuovi casi/helper di `AtomicGenerationRecoverySnapshotPullServiceTests.swift` e questa Execution. La review preparatoria ha rilevato che l'aspettativa del wrapper termina prima della pubblicazione dell'orchestratore e che `stop()` non attende il runtime.

**Azioni:** dopo ogni aspettativa attesa monotona limitata a due secondi della fase terminale effettivamente pubblicata: idle/recoveryRequired/failed/blocked, senza attendere specificamente idle. Le assertion successive mantengono il risultato desiderato e registrano fase/outcome/status/errorCode effettivi. Pulizia installata subito dopo la prima creazione, prima di await/unwrap: defer per l'istanza correntemente assegnata e do/catch con stop + cancelAndWait + resumeAfterStoreReplacement su ogni uscita success/error; medesima quiescenza prima della fresh-open. La seconda istanza resta coperta immediatamente dal cleanup esterno. Il resume finale rilascia la sospensione singleFlight condivisa solo dopo la quiescenza, evitando contaminazione del test successivo.

**Check:** solo STATIC/invarianza ESEGUITO; compilazione e RED funzionale NON ESEGUITI. Originali34 casi/helper, altri325 input e tutti207 applicativi e test118/119 invariati. Freeze/card/patch v1 conservati; v2 distinta e diff esatto v1→v2 fuori Git. Nessuna produzione, runner/runtime/auth/rete/DB reale o Git. Reviewer/root devono verificare v2 e autorizzare un nuovo GO prima del comando.

### Esecuzione R-I07 — controllo XCTest sincrono su iOS26.2, 2026-10-02 UTC

**File modificati:**
- `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift:58` — sola parola `async` nella firma del controllo; corpo, helper,771 record, batch256 e tutte le assertion byte-identici.
- Questo task, Execution — risultati attuali e limiti; Planning e criteri invariati.
- `docs/TASKS/EVIDENCE/TASK-144/ri07-proof-order/async-continuation/*.json` e ledger — proiezioni pubbliche portabili; ledger precedente archiviato byte-identico. Log, IPS e configurazioni protette non copiati nella documentazione.

**Azioni eseguite:**
1. PR13 HEAD `fabae1e5`, CI37031063547:1404 PASS/36 SKIP/1 crash del controllo; il test reale257 PASS. Failure CI e prime prove rimangono storiche e immutabili.
2. GO root isolato16:58:30–17:13:30 UTC verificato prima di runtime. Controllo invariato SHA `e00d659e…` su simulatore proprio iOS26.2/23C54:0 PASS/1 crash/0 SKIP, exit65. IPS attuale attribuito a PID/device/intervallo: `TaskLocal::StopLookupScope` → `swift_task_deinitOnExecutorImpl` → deinit di `SyncStoreGenerationController` → closing brace91. Questo è stack locale attuale; nessuno stack CI viene inferito come disponibile.
3. Condizione del GO soddisfatta: aggiunta soltanto `async`. Sullo stesso runtime, controllo1 PASS/0 FAIL/0 SKIP; Atomic34+Contract26=60 terminali unici PASS/0 FAIL/0 SKIP, nessun crash o restart. Inversa della parola ripristina l'intero sorgente RED; altri325 file e tutti207 applicativi invariati.
4. Nuovo source326 fingerprint `9b4275700052d579dcba8c1e06946919155814f35a2cd69a9c3b7c40bb091fee`; review indipendente `APPROVED_BOUNDED_ONE_KEYWORD_TEST_FIXTURE_LIFECYCLE`, receipt SHA `32a05df07c560e661ff0ca5b76e0a5020a05aa04dfa7916702dd81024724e101`. Shutdown normale e readback proprio verificati17:09:46.413408 UTC, prima della deadline.
5. Il breve slot firmato ricevuto17:23:49 con termine17:25 è insufficiente: nessuna build/runtime avviata. I207 input applicativi coincidono con l'artefatto originale050db/f7; il freeze storico326 non include progetto/schema/package lockfile, quindi l'equivalenza completa degli input di build storici non è attestata. Preparata scheda canonica firmata per un futuro GO esplicito10min con nuovi input congelati. Artefatto23file e ricevute originali preservati, senza rietichettarli come nuova build.

**Check obbligatori:**
| Check | Stato | Evidenza / limite |
|---|---|---|
| BUILD XCTest mirato | ESEGUITO — PASS | Controllo e60 casi sul medesimo runtime26.2; exit0 |
| STATIC/analyze corrente | NON ESEGUITO | Fuori dalla lane unit autorizzata; PASS precedente230ddb resta distinto |
| Warning nuovi | ESEGUITO | Zero runtime warning ufficiali; nessun nuovo warning source del delta osservato; il silenzio della cache non risolve warning storici |
| Coerenza planning | ESEGUITO | Solo async dopo RED/stack attuali, nessun cambio produzione/guard/assert/scenario |
| Regressioni | ESEGUITO — PASS | Atomic34+Contract26=60 unici; nessuna esclusione o retry |
| CI completa exact-head corrente | NON ESEGUITO | Attesa dal root; CI faba fallita preservata |
| Nuovo TEST firmato/finali | NON ESEGUITO | Slot insufficiente; scheda pronta, runtimefalse, nuovo GO necessario |
| Recovery autentica | NON ESEGUITO | Nessun install/Retry live in questa lane |

**Incertezze:** la riproduzione locale identifica il deinit isolato; non prova una causa esclusiva del compilatore né produce uno stack CI. I60 PASS non sostituiscono la CI completa e l'acceptance live. Nessuna rimozione, skip, assertion indebolita o modifica actor globale.

**Handoff:** parent unicoownerGit/CI/merge e coordinamento della prossima build; taskFIX, nonDONE. [Prove portabili](EVIDENCE/TASK-144/ri07-proof-order/async-continuation/portable-manifest.json) e [ledger](EVIDENCE/TASK-144/ri07-proof-order/validation-ledger.json) distinguono i risultati attuali dal precedente signed050db/f7.

### Esecuzione R-I07 — 2026-10-02 UTC (root/executor)

**File modificati:**
- `iOSMerchandiseControl/Sync/Automatic/Recovery/AtomicGenerationRecoverySnapshotPullService.swift` — una riga: comparatore `.lexical` nella verifica persisted delle baseline; nessun altro delta applicativo.
- `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift` — recovery reale a disco257 prodotti/cross-batch256, controllo3tipi×257 e paging fake che preserva l'ordine wire.
- Questo task — planning autorizzato, evidenze e stato FIX/handoff.
- `docs/TASKS/EVIDENCE/TASK-144/ri07-proof-order/*.json` — copie esatte delle ricevute pubbliche e ledger portabile; niente configuration/token/dati business raw.

**Azioni eseguite:**
1. Registry154 ha scaricato tutti6domini e superato checkpointA/B, poi FAIL locale `nonMonotonicOrDuplicateID`; journal/pending/staging preservati, manifest/finalization assenti. Diagnosi separata da153timeout; non usato un altro Retry.
2. Produzione207 invariata prima del rosso. Servizio257 con ordine canonico,11pagine prodotti+5domini vuoti: RED1PASS/1FAIL; stesso test dopo una riga di patch: GREEN60uniciPASS/0FAIL/0SKIP. Il controllo `.lexical` era già verde e resta una prova separata di compatibilità SwiftData.
3. Source326 congelati fingerprint `230ddb78907a4e9f70dfad39f92af3791994b2816b85335d3ba921d51b5c7db9`; inverse production diff byte-identico al main precedente. Review indipendente APPROVED, receipt SHA73f29a40789a0d8b33991fe1e52771454972d7c1e448a04e3c3833384e86ae6c.
4. Release/analyze/scan PASS; TESTfirmato nuovo binary050db10aabfbf0c2a663a10dc515d81fb5ad771249dd408393009435f00221fc,23filehash verificati dal parent, strict/deepPASS e profilo autorizzato invariato. Vecchio4a708 e primaryconfighash preservati; copia temporanea rimossa. Unit simulator3DDC Shutdown, lane rilasciata15:53:49Z.

**Check obbligatori:**
| Check | Stato | Evidenza / limite |
|---|---|---|
| BUILD Release/TEST | ESEGUITO — PASS | Gate locali e23file/signedreceipt; configurazione primaria invariata |
| STATIC/analyze | ESEGUITO — PASS | Zero nuovi warning source;26storici non dichiarati risolti |
| Warning | ESEGUITO |0sourcewarning; notice AppIntents metadata Release1/Analyze2/TEST1 preservati |
| Coerenza planning | ESEGUITO | Un solo comparatore, schema/UUID sort/strict guard/scope/digest/batch256/caps invariati |
| Regressioni | ESEGUITO — PASS |34Atomic+26Contract=60; nessun nuovo fullcanonical o8UI attribuito |
| CI completa/finali R-I07 | NON ESEGUITO | Sarà verificata sul nuovo HEAD esatto; i1439/1403+36precedenti restano storici |
| Recovery autentica R-I07 | NON ESEGUITO | Solo dopo gate/artifact/review e slot coordinato; nessun install su459 effettuato da executor |

**Incertezze:** il rosso→verde dimostra il difetto del persisted readback sintetico; l'esclusività della causa live richiede il ritest. Fresh-open conserva vecchi handle, non prova chiusura/processrestart. Nessun test esplicito di wire malordinato/duplicato aggiunto in queste due classi; guard identici verificati dal reviewer.

**Handoff:** parent unicoownerGit/PR/CI/merge; coordinatorowner459/5556 e installazione data-preserving. TaskFIX, nonDONE; per-record/sweep/importAndroid/immagini/performance aperti. [LedgerR-I07](EVIDENCE/TASK-144/ri07-proof-order/validation-ledger.json); CI/head/main futuri hanno ricevute proprie e non sovrascrivono queste osservazioni.


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


### Esecuzione R-I08 — V6 mirati5 actual GREEN e preparazione gate finali — 2026-10-02

**File modificati:** nessuna nuova modifica sorgente/test dopo freeze V6 `ac3ba92dc6af989b8a538b7ac43698f8a17d6f741f0b2588a04a5c310b9e2cf3`. Questo aggiornamento riguarda solo Execution; Planning raw `666282867e0deb4d40711c8199ff690bbe93bcacbc65e6bc63a9ce8b8fd25cf9` resta invariata.

**Azioni eseguite:**
1. Il primary ha eseguito una sola invocazione V6 sul proprio simulatore iOS26.2: actual START22:49:50.406497Z, END22:50:17.729983Z, release22:50:18.185250Z. Risultato ufficiale: **5 identifier unici PASS,0FAIL,0SKIP**,19 stage reali; ricevuta indipendente `evidence/independent-review-resumed/ios-ri08-targeted5-v6-actual-review/independent-targeted-pass-adjudication.json` SHA256`fcba2f43129f2019a6c571525006bfc40f29a5d31460a96f5e931fc5af9c238c`.
2. Freshopen conserva typedcursor/fence42→secondo delta43 reale idle/unverified; full0 reale attivato/finalizzato e riaperto→delta1/empty1 con receipt valida; empty0 indipendente esegue2letture/freshcount1/targetedlookup0 e noWork idle. I tre casi advanced-fence e i due casi typed-zero sono loop/assertion dei due test negativi, non altri testcase. Nessuna assertion indebolita;57 methodIDs Atomic e55corpi/asserts preesistenti conservati.
3. Il primary ha verificato ownPG88580 assente, nessun signal di cleanup, readback Shutdown6B049C77-E70E-4A75-8FF2-CE3EC756EE11, tutti326source/build3/cache13 invariati. La receipt qualificata registra cleanup/Shutdown senza attribuire149 già-Shutdown a errore applicativo. Nessun artifact storico R-I07 viene usato come build V6.
4. Preparata staticamente suite completa senza selettori only/skip:1464ID sorgente unici (1456unit/integration+8UI), tutti1441ID storici R-I07 più23Atomic;36skip espliciti storici mantenuti come aspettativa da confrontare con il futuro tree ufficiale. Card/launcher sotto `evidence/ios-ri08-ordinary-sync-state/final-gate-preparation/full-test/`, sorgente326ac3b/freeze8208/build3/cache13. Runtime full/Release/analyze/TEST firmato restano da eseguire con nuova review/GO primary.

**Check obbligatori:**
| Check | Stato | Note |
|---|---|---|
| Build iOS mirato | ESEGUITO | V6 compilation+5PASS ufficiali; non equivale a Release/full. |
| Analyze/Release/TEST firmato finali | NON ESEGUITO | Gate finali preparati sulla stessa fonte, primary proprietario della nuova esecuzione. |
| Warning nuovi | NON ESEGUITO integralmente | Confronto diagnostiche completo richiesto nella futura suite/gate finali; nessuna soppressione. |
| Coerenza Planning | ESEGUITO per delta V6 | Source review indipendente `a6068678…`, actual5receipt`fcba2f43…`; Planning raw6662 preservata. |
| Criteri di accettazione | NON ESEGUITO integralmente | Questo5GREEN chiude le regressioni V5/negative mirate; full1464, artifact finali, CI exacthead/main e residui live restano distinti. |

**Baseline regressione:** mirati5 reali ESEGUITI; suite iOS completa obbligatoria preparata, non ancora eseguita. Non descritta come UI acceptance live.

**Incertezze:**1464 è conteggio sorgente dichiarato, non risultato ufficiale. I36skip live/opt-in restano limiti espliciti; nessuna accettazione backend/auth/reale, firma/CI o chiusura globale derivata dai5PASS.

**Handoff notes:** primary/root possiedono nuove lane e Git/CI/merge normale; nessun DONE da executor e nessun nuovo native job avviato da questa lane.

### Esecuzione STEP2 — integrazione finale efficiency e recovery UX — 2026-10-03 (UTC 2026-10-04)

**Autorizzazione e ruolo:** C/parent autorizzano l'integrazione sorgente STEP2 in worktree isolato. L'agente di questa voce è l'esecutore del batch; la review indipendente appartiene a un agente diverso. Nessuna modifica a Planning, MASTER, stato task, checkout Desktop o manifest. Branch `codex/ios-native-final-integration`, base/HEAD `8dfbf9a033c1e9be05c941e1cb49712137c893bc`; nessun commit/push/PR eseguito.

**File modificati:**
- `iOSMerchandiseControl/Sync/Automatic/Decision/SyncDecisionInputProvider.swift` — assenza bounded con short-circuit e fallback per pending edits.
- `iOSMerchandiseControl/Sync/Recovery/SyncCountReconciliation.swift` — conteggio History in batch256, stessa visibility policy e fallback per pending edits.
- `iOSMerchandiseControlTests/SyncIdleWorkEfficiencyTests.swift` — sette test nuovi, inclusa misura sintetica interna; test non ancora eseguiti sul candidato.
- `iOSMerchandiseControl/ContentView.swift` — UI/UX: fase, timer e osservazioni di pagine/righe persistite nel gate recovery, per rendere leggibile il lavoro in corso.
- `iOSMerchandiseControl/Sync/Automatic/Composition/AutomaticSyncRuntimeFactory.swift` — collega il reporter di presentazione alla state store corrente.
- `iOSMerchandiseControl/Sync/Automatic/Presentation/SyncRecoveryProgress.swift` — nuovi valori osservativi e mapping delle fasi; nessuna percentuale o prova di convergenza.
- `iOSMerchandiseControl/Sync/Automatic/Presentation/SyncState.swift` — campo opzionale di progress recovery.
- `iOSMerchandiseControl/Sync/Automatic/Presentation/SyncStateStore.swift` — reporting per invocation e scope corrente, mantenendo getter/setter e receipt R-I08.
- `iOSMerchandiseControl/Sync/Automatic/Recovery/AtomicGenerationRecoverySnapshotPullService.swift` — riporta fasi e pagine dopo persistenza e rivalida lo scope dopo callback async.
- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift` — lega il reporting alla singola invocation del runtime.
- `iOSMerchandiseControl/en.lproj/Localizable.strings`, `es.lproj/Localizable.strings`, `it.lproj/Localizable.strings`, `zh-Hans.lproj/Localizable.strings` — copy UI/UX delle fasi e conteggi osservati nelle quattro lingue.
- `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift` — quattro nuovi test progress/scope/late-callback/status e reporter opzionale nel helper.
- Questo file TASK144 — sola append alla sezione Execution.

**Azioni eseguite:**
1. Importati soltanto i tip SHA richiesti dai due clone locali: efficiency `3adeaaf9091bed81f80b392d85a77e89a36d0148` da `Documents/Codex/2026-10-02/task-2/ios`; UX `8ba09b1c6cb9f43e1835f3ad88bf5d68f5799983` da `Projects/MerchandiseControl-Ecosistema/workspaces/ios-recovery-presentation` (delta combinato dal base `414c4a341aebbf43d94d2477b1eb36f792ab04ed`, include il parent iOS `df66716efc3e3a0a39db5fb1bce5a4c811e28036`). Nessun blind cherry-pick o overwrite dei file latest main.
2. Efficiency: due preimage produttivi uguali alla base current main e test nuovo assente; applicazione esatta dei tre percorsi e verifica byte-identica al commit sorgente.
3. UX: dieci percorsi applicati tramite hunks diretti; `SyncStateStore.swift` e il test Atomic adattati solo ai contesti latest R-I08. Il computed state validante, plain storage, lease/receipt/result policy e tutti i corpi/assert dei57 test Atomic già presenti rimangono invariati; reset invocation usa il setter esistente. Helper `makeService` esteso con reporter opzionale senza cambiare i chiamanti precedenti. Inverse testuali dei due adattamenti ripristinano i file current-main interi. Checkpoint/query/auth/business guard preesistenti preservati.
4. Identificati sette nuovi selector efficiency e quattro progress (61 metodi Atomic sul candidato, non61 eseguiti). Il target unit è incluso dal gruppo filesystem synchronized già esistente; nessuna modifica al progetto/scheme.
5. Comando mirato preparato, non lanciato: XCTest unit target soltanto11 nuovi metodi, sul dispositivo test-only storico `6B049C77-E70E-4A75-8FF2-CE3EC756EE11` / `TASK144 filesystem crash 26.2` / iOS26.2. Metadata device.plist esiste con state1; receipt canonica precedente registra Shutdown. Compatibilità/availability corrente da verificare dall'owner prima del nuovo GO; nessuna chiamata SDK, boot/install o accesso al simulatore autenticato/CSV03 in questa integrazione.

**Check obbligatori:**
| Check | Stato | Note |
|---|---|---|
| Build/XCTest11 mirati | NON ESEGUITO | Preparazione soltanto; nuovo slot owner/GO necessario. |
| Analyze/static compiler e warning nuovi | NON ESEGUITO | Nessun compiler invocato e nessuna assenza warning inferita. |
| Coerenza scope autorizzato | ESEGUITO STATIC | Due delta autorizzati e adattamento puntuale documentato; Planning/MASTER immutati. |
| Criteri di accettazione | NON ESEGUITO integralmente | Review indipendente, test11, full finale, artifact/CI/live/CA09 rimangono distinti. |
| Integrità patch / whitespace | ESEGUITO STATIC | Preimage/inverse e `git diff --check` PASS; non equivale a build o runtime. |

**Incertezze e handoff:** stato UI/runtime, prestazioni e regressioni non verificati sul candidato. Pagine/righe sono osservazioni della persistenza, mai percentuale, consenso cloud, verifiedConvergence o garanzia3s. La misura interna al test efficiency non sostituisce un confronto prestazionale controllato. Root/C possiedono il prossimo slot test-only, la review di altro agente, gate finali e Git/CI. Nessun DONE o autorizzazione install/live derivata da questa append.

### Esecuzione STEP2 — preparazione RED reentrancy progress, produzione congelata — 2026-10-03 (UTC 2026-10-04)

**Nuovo finding e autorizzazione:** il reviewer indipendente ha identificato un P2 concreto di compatibilità tra i due nuovi metodi progress e il setter computed R-I08: un subscriber sincrono può terminalizzare il run o cambiare account durante `objectWillChange`, poi il writeback della copia precedente può ripubblicare fase/progress obsoleti. C/parent autorizzano solo test desiderati prima del RED ufficiale; nessuna patch produttiva o asserzione indebolita.

**File modificati:** `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift` — tre nuovi metodi async con fixture reale, journal/scope effettivi e subscriber Combine one-shot. Tutti i61 metodi già presenti e i loro corpi/assert restano invariati. Questo file TASK144: sola append Execution.

**Test preparati, NON ESEGUITI:**
- `testRecoveryProgressCannotResurrectTerminalRunFromSynchronousObserver` — durante la pubblicazione termina con risultato failed; recoveryRequired, lastOutcome failed, progress nil e callback della vecchia invocation inerte.
- `testBeginningRecoveryProgressCannotResurrectTerminalRunFromSynchronousObserver` — durante begin la notifica terminalizza il run; nessuna resurrezione e callback di entrambe le invocation inerte.
- `testRecoveryProgressRejectsAccountChangeFromSynchronousObserver` — cambia account durante la notifica, senza riscrivere la fase business o mostrare conteggi del vecchio account; callback tardiva inerte.

**Check / stato:** aggiunta solo test-source, `git diff --check` STATIC; nessun compiler, runner, device o backend eseguito. Produzione del candidato STEP2 congelata prima dei tre test; i due metodi progress conservano gli stessi bytes pre-fix. Command scope aggiornato a **14 selector esatti =7 efficiency+4 progress precedenti+3 nuove guardie**, tutti nel target unit `iOSMerchandiseControlTests` sul simulatore test-only6B049 previa disponibilità/nuovo GO owner.64 metodi Atomic è un conteggio sorgente, non un risultato.

**Handoff:** root/owner eseguono ONE batch14 dopo il rilascio della lane Android. Compile/setup failure non dimostra il RED desiderato. Il fix produttivo e la re-review del medesimo reviewer restano subordinati all'XML/tree ufficiale RED; nessun global DONE, CI, performance, auth o acceptance live deriva dalla preparazione.

### Esecuzione STEP2 — fix P2 progress dopo RED ufficiale, GREEN pending — 2026-10-03 (UTC 2026-10-04)

**RED actual del root:** ONE job71718 / ownPG88830, START01:44:31.838Z→END01:45:13.016Z, exit65,41.388s.14 metodi ufficiali:11PASS (7efficiency+4progress precedenti),3FAIL delle nuove guardie,7 assertion failure attese. XCResult conservato in `Projects/MerchandiseControl-Ecosistema/evidence/operational-completion-20261003/resumed-executor/native-final-integration-targeted-ios-red-attempt01/target14-red.xcresult`; receipt root SHA256`076586085bec5f136c46106fe6efeafb3830a15d62b8d5d850771db7b9e8aa05`. Produzione al run immutata con StateStore`24370693…`, test`e401de3d…`. Conteggi ed esecuzione sono del root/owner; questo executor non ha invocato il runner né una nuova review indipendente.

**File modificati / fix autorizzato:** solo `SyncStateStore.swift`, nei due nuovi metodi `beginRecoveryProgressReporting` e `recordRecoveryProgress`. Notifica fuori dalle lease e prima della pubblicazione; ricontrollo invocation/fase dopo subscriber sincroni, quindi journal e scope attuali per i conteggi. Scrittura diretta dei soli campi progress/lastProgressAt su plain storage, senza writeback della copia tramite computed setter. Begin conserva il nuovo UUID solo se non invalidato dall'observer e non modifica una fase terminale. Il clear del solo campo display non autorizza scope o receipt. Nessuna modifica a getter/setter R-I08, continuazione/lease/result policy, fase business, lastOutcome, checkpoint, query o auth.

**Preservazione verificata STATIC:** sostituendo soltanto i due metodi con le versioni pre-RED si ripristina l'intero StateStore SHA256`24370693c877cb554e87750afa9f065651de4c07cdf03dd80f919a4a99ee7967`. Nuovo StateStore SHA256`8fc3913f43af7159f887f6f3ec23cc1cbde440b1fd27727abe4ad3a49e2e6563`. Tutti64 metodi Atomic/corpi/assert immutati, test SHA256`e401de3d8e911ba784bbe68559a31788431a1d6119b40cbee2c4d2850d68b9a1`; altri sorgenti STEP2 invariati. Planning/MASTER invariati e `git diff --check` PASS. Solo questa append Execution documentale oltre ai due metodi.

**Check / handoff:** GREEN3 delle guardie: NON ESEGUITO da questa lane; il root possiede la prossima ONE invocazione sugli stessi tre ID/test immutati, poi suite finale del candidato una volta e gate canonici. Re-review del fix del reviewer indipendente pendente; nessuna approvazione da questo executor. Compiler/warning/full/CI/artifact/performance/autenticato restano non verificati sul nuovo source. Nessun commit/push/PR/install, manifest nuovo o global DONE.

### Esecuzione STEP2 — GREEN3 actual e P2 chiuso dalla re-review indipendente — 2026-10-03 (UTC 2026-10-04)

**Nessuna modifica a codice/test:** StateStore `8fc3913f43af7159f887f6f3ec23cc1cbde440b1fd27727abe4ad3a49e2e6563`, Atomic64 `e401de3d8e911ba784bbe68559a31788431a1d6119b40cbee2c4d2850d68b9a1`; altri sorgenti STEP2 congelati. Questo aggiornamento riguarda soltanto Execution.

**GREEN actual del root:** ONE esecuzione dei medesimi tre test RED immutati, START01:53:00.923877Z→END01:53:25.438193Z, duration24.7436s registrata dall'owner, exit0, **3PASS/0FAIL/0SKIP**. Session98455 chiusa e ownPG91078 assente. Receipt `Projects/MerchandiseControl-Ecosistema/evidence/operational-completion-20261003/resumed-executor/native-final-integration-targeted-ios-green-attempt01/receipt.json` SHA256`71f40a9ed1e6cc03a259c2033f0e2dceafeeec2eb8000f937610aea065181131` (SHA riletto da questo executor); summary `5e193…`, method-status `0ce885…`. Source15 invariato nel run; nessuna nuova esecuzione da questa lane.

**Re-review indipendente:** il parent comunica `P2_CLOSED_APPROVED_VERIFIED`, nessun nuovo blocker. Il reviewer distinto da questo executor ha letto saved result/hash/source e verificato l'inversa dei soli due metodi; test RED→GREEN e tutti64 corpi/assert preservati. La chiusura riguarda soltanto il P2 di reentrancy progress, non l'acceptance globale o la suite finale.

**Check / handoff:** GREEN3 ESEGUITO dall'owner e re-review P2 ESEGUITA dal reviewer indipendente. La suite finale iOS/root53311 è ancora IN CORSO: nessun conteggio parziale o build intermedia costituisce full PASS. Attendere la receipt finale prima dell'ultimo aggiornamento Execution. Task resta FIX; acceptance autentica/live/per-record, performance e CI/nuova integrazione Git rimangono aperte. Nessun codice/test, Planning, MASTER, manifest, rerun, commit o push modificato/invocato da questa append.

### Esecuzione STEP2 — gate locali finali actual, writer fermato per commit locale — 2026-10-03 (UTC 2026-10-04)

**Nessuna modifica a codice/test:** candidato finale StateStore `8fc3913f43af7159f887f6f3ec23cc1cbde440b1fd27727abe4ad3a49e2e6563`, Atomic64 `e401de3d8e911ba784bbe68559a31788431a1d6119b40cbee2c4d2850d68b9a1`; tutti15 sorgenti STEP2 immutati durante i gate. Solo ultima append Execution; Planning/MASTER e stato FIX conservati.

**Gate actual del root:** ONE job53311 completato naturalmente02:04:08.403336Z, durata totale461.512774292s. Build4.30240025s/exit0, test416.83606175s/exit0, Analyze40.166600084s/exit0. Receipt finale `Projects/MerchandiseControl-Ecosistema/evidence/operational-completion-20261003/resumed-executor/native-final-integration-final-ios-attempt01/receipt.json` SHA256`d379ca7e66684e0b4e537996f20a5a6c775855ea287c97beb6b8db581027d2f5` (classificazione warning finale; sostituisce il solo snapshot receipt9d929, source/gate/count/argv invariati). SHA/summary scalare e sourceUnchanged/ownedGroupsGone riletti da questo executor; nessun runner qui. Summary SHA256`1f67b07756bb98787b0a6b5276bdbbbf5ffee337285f8b228247e7542eb2f76a`, test-tree SHA256`f43a5d27e146c8e258f42900f8abffa700996c8af6a8aa1bc5df5f38509373bc`.

**Suite completa attuale:** **1478 identifier =1442PASS+36SKIP,0FAIL/0expectedFailures**. Il saved test-tree distingue1470 unit/integration (1434PASS+36SKIP) e8 UI PASS: CatalogTextImportUITests4 e StorefrontEditorUITests4. Gli otto UI eseguiti non sono gli opt-in fisici/live saltati. Tutti e tre i test P2 passano nuovamente nella suite finale. I36skip mantengono i limiti opt-in/device/live e non costituiscono acceptance fisica/autenticata. OwnPG91983/92000/93892 assenti nel readback fresh del root; nessuna azione sul simulatore autenticato da questa lane.

**Check obbligatori finali locali:**
| Check | Stato | Evidenza / limite |
|---|---|---|
| Build canonico corrente | ESEGUITO PASS dal root | exit0; nessun Release PASS inferito da questo build. |
| Suite unit/integration+UI corrente | ESEGUITO PASS dal root |1478 attuali,1442PASS/36SKIP/0FAIL; source finale invariato. |
| Analyze corrente | ESEGUITO PASS_WITH_NOTES dal root | exit0;53 righe warning grezze,34 warning primari sui sei file immutati: Vendor2/libxls18 e quattro test precedenti16. Rigature caret duplicate/metadata non sono nuovi warning di sorgente. Nessun totale Analyze storico riutilizzato come risultato attuale. |
| Warning sui file modificati | ESEGUITO,0 emessi | Receipt finale elenca zero warning nei15 file cambiati; i sei file con diagnostiche sono byte-identici a main8df secondo il confronto Git del root. Build0warning; test2notices metadata e notice Analyze già presenti nei log RED/GREEN. Nessuna soppressione o risoluzione delle vecchie diagnostiche dichiarata. |
| Coerenza scope/preservazione | ESEGUITO STATIC | import/hunks contestuali e fix P2 circoscritti;64 test immutati, getter/receipt/result R-I08 preservati, Planning/MASTER invariati. |
| Review indipendente P2 | ESEGUITO APPROVED_VERIFIED | chiusura circoscritta già registrata con RED→GREEN3 e re-review di altro agente. |
| Criteri di accettazione globali | NON ESEGUITO integralmente | gate locali non sostituiscono auth/live/per-record, performance/CA09, artifact/Release/CI e nuova integrazione pubblicata. |

**Gate statici CI eseguiti dal root:** `shasum -a 256 -c contracts/product-image-v1.sha256` verifica tutte le quattro fixture/contratti; scansione sensibile con il helper esistente PASS/exit0, `MC_AGENT_CONFIG=/dev/null`, checkout ed evidence espliciti. Report `/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/operational-completion-20261003/resumed-executor/native-final-integration-final-ios-attempt01/agent-runs/20261004T021803Z-scan-sensitive-iOSMerchandiseControl-iOSMerchandiseControlTests-contracts-github-workflows-ios-product-images-ciyml-p97744.json`, SHA256 `847bf99b97ffd221bcad946f239abbab53a8375ce1b487b87d5cc55547e65461`. Nessuna lettura di configurazione privata o output nella primaria.

**Handoff / STOP writer:** ultimo aggiornamento documentale di questo executor completato. Root/C possiedono il commit locale autorizzato sul candidato; nessun push/PR/merge o nuova CI eseguiti da questa lane. Nessun nuovo manifest/framework/rerun, codice o test modificato. Task resta FIX, nessun DONE globale; tutte le acceptance residue rimangono aperte. Writer fermato dopo questa append.

### Esecuzione e fix — 2026-10-05 UTC, disponibilità locale e recovery concorrente

**Mandato:** override umano del 2026-10-04 e addendum integrità: dati validi dello stesso scope utilizzabili durante checking/recovery; shell iniziale onesta, Save/outbox durevoli, cutover sicuro, A perso/B successivo confermati automaticamente. TASK resta `FIX`; MASTER, Planning e criteri originari invariati.

**File modificati:** 43 Swift (36 produzione, 7 test) e quattro risorse localizzate; elenco completo con hash nel [freeze sorgenti e prove mirate](EVIDENCE/TASK-144/local-availability-20261005/source-and-targeted-evidence.json). Le sei nuove unità sono `LocalRootPresentationState`, `LocalPendingBusinessAttemptStore`, `LocalCatalogBodyProofStore`, `SameScopeRecoveryLocalWorkTransfer`, la fixture DEBUG `Task144LocalAvailabilityRootFixture` e il test UI `LocalAvailabilityRootUITests`. Nessun nuovo schema, dipendenza, configurazione privata o coda globale.

- Local capability: `SyncStoreGeneration`, `AccountBindingStore`, `Task126SyncPolicy`, `ShopContext`, `SupabaseAuthViewModel`, `ShopDeviceRegistrationService` e composizione runtime separano capacità locale verificata da convergenza cloud. Revoca esatta, account/shop/device diversi e dati nonempty unbound restano protetti. Cache locale e stato dispositivo sono recintati anche contro risposte obsolete e cache writable dopo revoca esterna.
- Integrità: `LocalPendingChange`, servizi Catalog/Price/History, payload/outbox e transfer conservano il primo baseline di una catena pendente, payload/id/key immutabili di A già tentato e B distinto. Dopo cutover/reopen, A viene riconciliato/ripetuto prima dell'invio e conferma di B. Writer/CAS originari restano; nessuna equality di valore viene trattata come ACK.
- Recovery/proof: Atomic/automatic snapshot, ledger e generation mantengono pagine accettate/cursori durevoli e budget, readback completo e cutover off-main con fence file/scope. Qualificazione del corpo corrente estende il ledger locale esistente, separato dal C canonico e dal lavoro pending; rifiuta tamper semantico History/Price e ammette ACK/apply/parent tombstone verificati. Finalizzazione postpublication ricattura soltanto autorità fresca per la medesima generazione/manifest/journal/tuple; bounded retry non ammette cancellazione, revoca, scope estero o marker invalido.
- Sync ordinaria: engine/facade/pullsummary applicano la deferral specifica di lavoro locale pending prima del push e richiedono poi nuova prova finale corrente. Nessun falso READY e nessuna richiesta manuale per sbloccare la coda. History equal-fingerprint aggiorna timestamp/proof atomicamente soltanto se non precedente.
- UI/UX intenzionale: App/ContentView, Database/Inventory/EditProduct/authoring e plain-value root state mantengono tab, ricerca, scroll, bozza e focus attraverso stato cloud/cambio G, preservando `.id`, immagini e privacy fence. Database espone Save locale/pending e conferma soltanto gli ID/payload correnti e relativi prezzi ACK, anche con altro record pending. Options mantiene FAILED statico e il clock elapsed/stall vive soltanto durante lavoro attivo in foreground; refresh singolo al ritorno foreground, cancellazione idle/background/disappear. A font accessibilità usa wrapping verticale/ampiezza finita per account e status, icona decorativa contenuta; layout ordinario e masking/actions preservati. Handler shop sincrono prima di heartbeat async evita invalidazione tardiva della nuova lease. Fixture DEBUG esatta osserva/orchestra trasporto controllato; non concede authority/READY né avvia manualmente queue/refresh.

**Azioni ed evidenze effettive:**
1. Test rossi sul percorso reale prima delle patch: held local Save/overlay, offline cache, immutable replay, pagine interrotte, clean History/Price tamper, callback ordine, timestamp, History A/B attraverso C, risposte active obsolete/revoca e cache, doppia invalidazione lease postpublication, layout XXXL. Setup/fixture failure e positioning sono conservati con attribuzione distinta dai difetti prodotto.
2. File-backed integrity, pagine/rollback e protezioni controllate: receipt dei rispettivi run nel freeze. Semantic/body/parent/empty mirati finali 9 PASS/0 FAIL/0 SKIP; Price nonzero A=12 perso/B=13, cutover/reopen/A replay/B terminal senza duplicati; History same/different-field C contenente A: 6 PASS/0 FAIL/0 SKIP inclusi conflitto esterno/foreign/revoked.
3. Device admission/cache: 4 PASS/0 FAIL/0 SKIP, incluse denial durable/reopen, returned authority obsoleta rifiutata, cancellazione, cache sana senza RPC extra e nuova active realmente ammessa. Finalizzazione ripetuta: 7 PASS/0 FAIL/0 SKIP, marker/cancel/foreign/device/denial negativi preservati. Due delta già APPROVED dagli stessi reviewer dati, hash esatti riportati.
4. Root nativa reale controllata: 5 PASS/0 FAIL/0 SKIP (timestamp nuovo/vecchio, shell empty, ordine callback, root principale). Prima release: tab/ricerca/editor/Save durevole; bozza ancora non salvata attraversa C, suffisso da tastiera SENZA nuovo tap/refocus entra nello stesso campo, poi Cancel/ACK automatico/riapertura coerente. Nessun queue nudge/refresh manuale.
5. Font finale11: 1 XCTest PASS/0 FAIL/0 SKIP contiene quattro varianti reali EN/IT/ES/ZH, actual UIKit `AccessibilityXXXL`/SwiftUI `accessibility5`, heading/email mascherata completi, bounds/isHittable/navigation e quattro attivazioni entro budget originale20s. Quattro PNG+AX sono acquisiti prima delle assertion; receipt `bc6380d6…`. Non sono quattro metodi XCTest. Runner23008 chiuso, isolato6B04 Shutdown e baseline default.store preservata.

6. Canonical full01 storico di questo batch: 1531 ID unici, 1489 PASS/6 FAIL/36 SKIP, tutti12 UI PASS. Non rimosso né reinterpretato: fixture outbox whole-entity/`.first` obsolete con sealed A e sparse proof, reopen prima della qualificazione off-main, e reale invalidazione del file fence dal salvataggio tecnico. Correzioni mantengono business queue/ACK/watermark e verificano esattamente typed original-A/body-proof; raw corruption non può essere riqualificata dal metadata save.
7. RED10 actual5 PASS/5 FAIL → GREEN02 actual9 PASS/1 locator FAIL: tutti nove dati/Auth PASS; AX mostra preparation/no mutazioni e identifica soltanto il locator riscritto da ContentUnavailableView. Locator ora alla vera copy pubblica, 5s e negative `No products`/Add/import intatti. Device observed publication MainActor con nuova revalidation dopo hop; cache-only non ritira HTTP in volo. Due delta APPROVED dal medesimo reviewer.
8. Save pubblico RED02 actual1 PASS/2 FAIL → GREEN04 actual4 PASS/0 FAIL/0 SKIP: per-record pending prima release, proprio ACK con History indipendente pending, bozza/focus/suffisso senza retap attraverso C, automatic terminal/reopen, A ACK non conferma B e B confermato dopo reopen. DTO ≤5 intenti, un solo lookup exact-ID capped6 fuori dalle righe; zero queue-empty/local-only authority. Ultimo guard task scope/receipt fingerprint/ID/cancellation congelato per full02, senza alterare corpi/budget o layout.
9. Font11/PNG invariati come prova di layout; nessun nuovo targeted font richiesto. Il freeze v2 e il suo full02 sono snapshot storici: i nuovi esiti e delta sotto prevalgono. Nessuna prova font viene rieseguita senza delta di layout.

10. Full02 immutabile sul v2: 1535 ID ufficiali unici, 1497 PASS/2 FAIL/36 SKIP (`dba6230d…`). I due FAIL UI non sono rimossi: ACK automatico non raggiunto e geometria native Select All prima di UnsavedDraft/C. Font/empty/callback PASS. La nuova diagnostica corrente ha dimostrato che il root riavviato restava recovery-required senza journal e non ammetteva la normale coda; nessuna inferenza dal vecchio probe privo di run/G/lease.
11. Ammissione corrente: Orchestrator usa la lease dell'esatto root e la prova di finalizzazione/corpo/scope/device corrente, rivalida dopo await e non concede READY. Stop cancella il task esistente; notifica locale sincrona sotto lease viene inoltrata sul MainActor dopo il writer, evitando il re-lock dimostrato nello stack del proprio processo. Il ramo journal pendente conserva la ripresa foreground/reconnect e riusa C/G senza refetch; il ramo completed rifiuta journal pendente prima della cattura. ROSSO pending `0ad5106b…` conservato; la classificazione legal bootstrap e il provider device adatto al pending sono correzioni della fixture/oracle, con assert journal/receipt/G/watermark intatti.
12. Feedback relation: RED09 `7e87b0f…` dimostra che un diverso UUID con lo stesso nome non può ereditare ACK. CatalogPush salva il remote ID della risposta typed soltanto nel ramo ACK/CAS accettato dell'intento originale, nella stessa transazione; nessun rekey/payload/canonical rewrite. Readback bounded exact-intent lega gli ID nuovi alla loro reale conferma; UUID precedenti e corpo/intenti restano recintati.
13. GREEN13 corrente `3f8cddfa…`: 9 PASS/0 FAIL/0 SKIP su source47. Sei selector dati reali coprono ordinary completed, dieci authority/old-root negativi, tre interruzioni durante decisione held, pending foreground/reconnect con checkpoint reuse, UUID same-name estraneo, A ACK/B terminal. Tre UI reali: altro History pending mentre il proprio Save è confermato; root held/Save/bozza/focus attraverso C/automatic ACK/reopen; nuovi supplier/category con due ACK reali e product response held mostrano ancora pending, poi il terzo ACK conferma pubblicamente. Budget5/20s e desired assertions intatti; scroll native corregge soltanto virtualizzazione input. PID55741 gone, isolato Shutdown e baseline default.store preservata. Mixed11/12 e setup precedenti restano conservati, non contati come full PASS.

14. Canonical full03 sul medesimo source47: **1541 ID ufficiali unici, 1505 PASS/0 FAIL/36 SKIP**, skipset36 esatto full02. Tutti14 UI PASS, compresi sei root locali reali (held/local Save/draft/focus/C/automatic ACK/reopen, pending tra relazione/product ACK, own ACK con altro record pending, empty/callback/XXXL). Receipt `25cc3697f4c1f3c6f78d070e4b54ade137ca1a2b7b98879c431be7e8bbcdddb1`; sorgenti/HEAD/baseline default.store invariati, PID57281 gone e isolato6B04 Shutdown. I tre QoS runtime diagnostics sono esatti full02 e distinti dai warning del compilatore.
15. Debug/Release/Analyze canonici PASS sul source47; tre process-group posseduti rilasciati, nessun timeout, file/status/HEAD/branch invariati. Analyze:34 occorrenze primarie normalizzate nei sei file baseline byte-identici; Debug/Release zero source warning, soltanto AppIntents preesistente. Nessun nuovo pattern o warning nei47 file modificati. Receipt `76cc42458ccc8cc675648dad5829f75782935866284b35f8f6ca1df8356a6bb2`.
16. Proper fullTEST Release firmato PASS: stesso source47, profilo8 autorizzato154a applicato SOLO all'Artifact copiato; stesso signer effettivo fresh Xcode, embedded/effective entitlements esatti Xcode, identità application/keychain precedente uguale e strict-deep verify PASS. Receipt `b0988d61eaf0c7215c874c701ebad9267b2725eb9a71285daa96807fb2be3163`, binary `17c0b7aab436822b968f2122b1bed0bd6b138693a4dc4da6ceaf2d884e2ecae5`. FAIL01 del driver primary-context (resource assente nel WT keyless) conservato, corretto solo il guard della destinazione Artifact assente/regolare, mai symlink. Fonte/config primaria86a e artifact/profile storici invariati; zero install/device operations.

**Check obbligatori sul freeze corrente:**
| Check | Stato | Note |
| --- | --- | --- |
| Build canonica iOS | ✅ ESEGUITO | Debug/Release PASS; full03 senza filtri1505 PASS/0 FAIL/36 SKIP; proper signed TEST PASS sul source47. |
| Analyze / static checks | ✅ ESEGUITO | Analyze PASS,34 primary normalizzati identici alla baseline nei sei file invariati. |
| Warning nuovi | ✅ ESEGUITO | Zero source warning nei47 modificati/nuovi, zero nuovo pattern; AppIntents e runtime QoS preesistenti classificati separatamente. |
| Coerenza con planning / override | ✅ ESEGUITO locale | Minime cause dimostrate, stessi reviewer dati; UX finale congelata per review. |
| Criteri di accettazione | ⚠️ PARZIALE | A–E/G locali sotto; F/H e primaria restano NON ESEGUITI. |

**Contratto override, stato individuale:**
| Prova | Stato | Evidenza / limite |
| --- | --- | --- |
| A — popolato stesso scope | ESEGUITO controllato; NON ESEGUITO autenticato finale | Local read/write checking/recovery, root held prima input, ordinary apply/ACK/reopen e cache. |
| B — bootstrap iniziale | ESEGUITO controllato | Root reale empty shell/tab/Options mentre RPC held; write/READY non concessi. |
| C — modifica e cutover | ESEGUITO controllato | A/B Catalog/History/Price immutable replay/terminal/reopen, Save durante held e bozza non salvata/focus attraverso C. |
| D — fault/lifecycle | ESEGUITO nelle fixture mirate; PARZIALE runtime esterno | Timeout/reopen pagina, rollback/cancel/file CAS, marker/digest e risposte tarde; rete/hardware live distinto. |
| E — sicurezza scope | ESEGUITO controllato | Foreign/revoked/device/unbound/denial e cache stale negativi, fresh genuine active positivo. |
| F — bidirezionale autenticato | NON ESEGUITO | Trasporto/SDK controllato non equivale al backend corrente o ad Android↔iOS/Admin/Mini. |
| G — UX/regressioni | ESEGUITO root/quattro lingue/XXXL/full suite; PARZIALE adiacenti | PNG/AX native, bozza/focus e14 UI PASS nel full03; scanner/immagini/provider/hardware live distinti. |
| H — prestazioni | NON ESEGUITO / NON MISURATO | Zero campioni dataset reale; durate runner non sono percentili. |

**Baseline regressione:** nuovi test mirati dati/engine/recovery/ShopContext/Auth e UI root reali; corpi/budget desired RED→GREEN conservati. Full03 corrente1541 ID=1505 PASS/0 FAIL/36 SKIP; skip36 preesistenti identici full02. Vecchio full1442/36 e full01/02 restano storici, non sostituiscono il gate del nuovo47.

**Preservazione:** i54 insert preesistenti di TASK144 salvati prima di questo append e mantenuti; nessun edit MASTER/Planning. Primary scheme/config/Task141/142/untracked e simulatore459 non toccati da questa lane. Slot heavy seriale, processi propri terminati e isolato Shutdown nelle receipt.

**Incertezze/Handoff:** i limiti primaria/auth/performance non sono bug attribuiti alla app. Parent N integra solo file owned e questi hunks nuovi, senza `git add .`; freeze e review non provano CI/merge/install futuri. Dopo gate finali, stesso source hash al commit e CI exact-head/main da verificare.


### Esecuzione e fix — 2026-10-06 UTC, compatibilità compilazione CI

**Causa verificata:** PR16/head `43822986287b96899066ae12f360cd30c588e934`, CI `37390541718`, Build Debug exit65: soltanto due errori in `SameScopeRecoveryLocalWorkTransfer.swift` (40:28 type-check timeout, 46:44 generic T non inferito). Il log CI indica `/Applications/Xcode_26.6.app` e language mode Swift5; la versione binaria Swift non è registrata. Ambiente locale verificato: Xcode27.0/27A266a, Swift6.4. I gate successivi della CI fallita sono SKIPPED, quindi NON ESEGUITI; i precedenti full03/proper02 restano storici.

**Unico file di produzione modificato:** `Sync/Automatic/Recovery/SameScopeRecoveryLocalWorkTransfer.swift` — tipi espliciti `Date?`, `String?`, `Predicate<HistoryEntry>`, `FetchDescriptor<HistoryEntry>` e `[HistoryEntry]` per ridurre l'inferenza del compilatore. Il filtro OR/AND, `fetchLimit=1`, ordine, guard, scope, identità, sealed A immutabile, pending B e CAS sono invariati. Hash corrente `2178f81df281e9783a367d2194bf0cf087966b7330455b8d5c21c9922edbcb2c`; gli altri46 file del source47 restano byte-identici al v3. Nessun test/timeout/assert modificato, upgrade, dipendenza, schema o configurazione privata.

**Verifiche sul source47 corrente:**
- Mirati7 PASS/0 FAIL/0 SKIP: Catalog/Price/History cutover e replay A prima di B terminal, controlli History foreign device/external body. Review mirata dei medesimi due reviewer APPROVED, zero finding.
- Canonical full04 senza filtri/skip aggiunti e parallelismo OFF:1541 ID ufficiali distinti, **1505 PASS/0 FAIL/36 SKIP**, ID→status identico al full03; tutti14 UI PASS. Source47, HEAD, baseline isolata, PID chiuso e destinazione6B04 Shutdown verificati.
- Build Debug, Release e Analyze PASS. Analyze34 warning primari normalizzati identici alla baseline; zero nuovi pattern e zero warning nei47 sorgenti modificati. Diagnostica runtime QoS invariata, distinta dai warning di compilazione.
- Proper fullTEST04 Release firmato PASS: profilo8 autorizzato applicato solo al copied Artifact, strict-deep, entitlements Xcode ed identità keychain/application verificati;23 file artifact verificati, binary `0e188fbed26463893eee82c38ead1e6adc3e7f4145359552ce6e479cc8546e01`. Nessuna installazione; source/config/public inputs preservati,0 scritture source/config,0 operazioni device.

**Check obbligatori:** BUILD, STATIC/Analyze, warning nuovi e coerenza con mandato ESEGUITI; regressione completa ed UI controllata ESEGUITI. Le prove A–E/G restano locali controllate; F autenticato, primaria459/install/retention e performance H NON ESEGUITI. TASK resta FIX. [Manifest e ricevute correnti](EVIDENCE/TASK-144/local-availability-20261005/source-and-targeted-evidence.json). Nessuna futura CI, PR o merge dichiarata PASS.

**Preservazione/Handoff:** parent N solo Git; questa lane non muta Git. Nuovi tre hunks Execution/Fix/Handoff: la loro rimozione restituisce `f01e0d8e81604e5b7e028188d1c76ff56bc5bbd748471dde11d12d63be4fb634` esatto;54 insert preesistenti restano fuori index. Nessuna modifica a MASTER/Planning, primaria/config/sessione/459. Tutti i runner/group posseduti chiusi; integrazione exact-head successiva spetta al parent.

### Esecuzione — 2026-10-07 UTC, precondizione bounded del witness empty-fence

**Snapshot pre-gate finale:** main `1ea56c18149633ea85a56bd81532f662ed7cda31`; CI main37590771978 FAIL reale:1552=1515 PASS/1 FAIL/36 SKIP invariati,15 UI PASS/1 FAIL. Solo nuovoA/UI273 fallisce; log e xcresult ufficiali conservati prima della scadenza. Gli esiti full1552/PR37585875875 PASS precedenti restano storici sul candidato precedente, non sono la full di questa patch.

**File modificati:**
- `iOSMerchandiseControl/Task144LocalAvailabilityRootFixture.swift` — solo DEBUG: richiesta iniziale one-shot osservabile, attesa della vera nuova revisione, scadenza monotona5s senza reset, recheck integrale e una sola iniezione; cancellazione su release/phase control/error/timeout.
- `iOSMerchandiseControlTests/AtomicGenerationRecoverySnapshotPullServiceTests.swift` — append5 test del boundary realmente usato; tutti117 metodi e helper precedenti preservati come prefisso byte-esatto. Test UI originale, assert/timeout, singolo setAttributes e observer post-injection invariati.
- Questo solo blocco Execution — esiti, limiti e handoff; Planning/criteri/MASTER e modifiche straniere preservati.

**Azioni ed evidenze:**
1. AX PID65445: initial-prerequisites/empty-admission/generation-readback-failed; iniezione fisica NON_TRAVERSED. I28 record RAM originali dello stesso PID mostrano first-failed physical-fence-equal, lettura riuscita e operandi precedenti veri; normale ticket5 pubblicato e admission/root visibile circa154ms dopo. Writer/file del drift UNKNOWN; nessun missing-resume prodotto dimostrato, nessuna causa storica trasferita.
2. Il witness attende la normale pubblicazione dopo un diniego transitorio. Lo stato waiting è veritiero e permette la stessa rivalutazione della vista; nessuna qualification, Recovery, Retry o fase forzata. Scope/container/phase/owner/held/journal sono ricontrollati; scadenza anche immediatamente prima della scrittura, callback obsolete e duplicate disarmate.
3. [Patch/freeze](/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/ios-empty-fence-bounded-initial-admission-fixture-fix-20261007-01/source-freeze-bounded-initial-admission-v1.json): freeze fd0a6bcb, patch fa62399b;46 altre fonti esatte. C e stesso reviewer indipendente APPROVED,0 finding.
4. [Contract unit5](/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/ios-empty-fence-bounded-initial-admission-contract-unit-01/receipt.json):5 PASS/0 FAIL/0 SKIP, receipt8347e736, verifica11/11. Eventi/clock e contatore completamenti controllati: non I/O fisico o nuova qualification reale.
5. [Original newA UI](/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/ios-empty-fence-bounded-initial-admission-original-ui-01/receipt.json):1 PASS/0 FAIL/0 SKIP,26.973446s, receiptfa6ff957, verifica16/16. WAITPATH reale NOT_OBSERVED; nessuna copertura aggiuntiva inventata. PG propri terminati,6B Shutdown, famiglia default/source/Task/HEAD/index preservati; zero operazioni sul primario.

**Check obbligatori al checkpoint:**
| Check | Stato | Evidenza / limite |
|---|---|---|
| Compilazione pertinente Debug | ESEGUITO | Compilazione effettiva unit5/UI1 senza errori; nuova full e CI ancora NON ESEGUITI. |
| Analyze / static checks | NON ESEGUITO finale | Parse2file PASS; nuovo Analyze CI sul commit finale ancora pendente. |
| Warning nuovi | ESEGUITO sui2file | Nessun warning nei2file modificati;19 righe legacy fuori perimetro nel compile incrementale, non comparer34 completo. |
| Coerenza planning/mandato | ESEGUITO | Solo fixture DEBUG e contratto;0 produzione/build/project/API pubbliche/dipendenze. |
| Criteri di accettazione | PARZIALE | Stati individuali sotto; nessun DONE globale. |

**Stato individuale CA:**
| CA | Stato | Evidenza / residuo |
|---|---|---|
|01|ESEGUITO|Baseline e snapshot exact-SHA; source/Task/master/workflow/index/stash e lavoro preesistente preservati.|
|02|ESEGUITO locale|F01 e regressioni durevoli già verificate; nessuna modifica a questa logica.|
|03|ESEGUITO controllato|F02 ownership/query e UI controllata già verificate; smoke primario finale separato.|
|04|ESEGUITO controllato|F03 intent/retry/ACK e SQL storici documentati; ACK perso HTTP reale dalle app NON ESEGUITO.|
|05|ESEGUITO documentale|Merge/CI/install/runtime/distribuzione separati; nuovo mainFAIL conservato.|
|06|ESEGUITO documentale|Matrice20 capacità nel report corrente; nessuna feature rimossa.|
|07|NON ESEGUIBILE finale|Input CUA noWindowsAvailable, UI/sessione/shop e convergenza autenticata per-record non qualificati.|
|08|NON ESEGUITO integrale|Regressioni semantiche locali storiche PASS; workbook condiviso e immagini nelle UI finali ancora aperti.|
|09|NON ESEGUIBILE finale|Dataset/sessione/UI mancanti, zero campioni finali qualificati; niente percentili da XCTest.|
|10|NON ESEGUITO finale|Cheap5+UI1 PASS; nuova full1557 attesa e nuova PR/main CI ancora da eseguire.|
|11|NON ESEGUITO integrazione finale|Re-review APPROVED; nuovo commit/PR/CI/merge da verificare, nessun PASS futuro.|
|12|NON ESEGUITO chiusura|Report corrente/evidenze presenti; criteri finali aperti e Task resta FIX.|

**Handoff:** proseguire commit/push/PR normali e full locale sullo stesso commit congelato; nuovaCI può avanzare in parallelo. Verifier2e42 invariato, baseline nuova full effettiva prima della qualifica terminale. Riuso Release/Proper/TEST solo per input Release effettivi invariati e con nota esplicita: non nuove build/install sul nuovo commit né prova di sessione. Non rilanciare una full invariata per nascondere un FAIL. Nessun reset/clear/uninstall/forcepush/deploy/store/credenziali; richiesta umana foreground ancora pendente, niente retry CUA senza cambiamento ambiente. Esiti finali successivi nel report corrente, senza commit documentali autoreferenziali.

### Esecuzione — 2026-10-07 UTC, diagnostica del controllo state-update originale

**File modificati:**
- `iOSMerchandiseControl/Task144LocalAvailabilityRootFixture.swift` — solo DEBUG: traccia stdout CAP16 del recognizer esistente e della callback sincrona; nessuno stato osservabile/query/layout/timeout/fact nuovo.
- Questo blocco Execution — esito ed evidenze; Planning/criteri/MASTER e modifiche straniere preservati.

**Azioni ed evidenze:**
1. PRCI37600450824 sul7e607 FAIL ufficiale1557=1520PASS/1FAIL/36stessiSKIP,15UI PASS/1FAIL. SoloB/UI59 perde il marker state-updated; tutti1556altri stati identici alla full localePASS. Log/xcresult acquisiti una volta e hash verificato; Analyze/secret scan saltati.
2. AX/PID79772 ed evento sintetizzato confermano editor/draft/focus/keyboard/held preservati e longpress1.2s al centro del controllo editor. Cinque frame originali stabili, nessun popup/scroll visibile. Intercettazione del gesto e callback-entry UNKNOWN; release/cutover NON_TRAVERSED. Nessuna nuova perdita draft o causa applicativa dimostrata.
3. Recorder dedicato solo per fixtureUUID valida,16record+segnale cap; PID/uptime/root-editor/stadi. Nessun allargamento del vecchio RAM128. Stesso recognizer/minDuration1/defaultDistance, assert e UIoriginali byte-esatti. Limite: formattazione/stdout sincroni possono perturbare timing; record mancanti/cap/assenza stdout sono NOT_OBSERVED, non prova di mancata entry.

4. Test B originale economico PASS1/0FAIL/0SKIP,58.168384s; receipt06930b8f. Compilazione reale, zero warning nella fixture modificata, preservation/cleanup PASS,6BShutdown e primario non toccato. Quattro export originali exit0; appstdoutSHA7034a08d PID33980 associato al Session/AX originale,9record uncapped: pressingtrue→perform-entry dopo1.0196s→callback→afterfact.present.true→pressingfalse. Collegamento/export su questo PASS dimostrati, failure storica NON RIPRODOTTA. N ha letto/hash verificato ricevuta e9record.

**Check obbligatori:** compilazione pertinente e B originale ESEGUITI; coerenza mandato ESEGUITA; cause B storica UNKNOWN e Analyze/nuova full/CI finali NON ESEGUITI al commit diagnostico. Review tecnica C APPROVED,0finding; stesso reviewer indipendente sul delta effettivo, esito nel report corrente prima di qualsiasi merge; full precedente1521P/0F/36SKIP e Release invariata sono prove storiche, non nuovi gate del delta. Nuova CI diagnostica richiesta dal mandato§3; nessun merge con gate falliti. Stato FIX, runtime autenticato/per-record/prestazioni ancora BLOCKED_EXTERNAL/NOT_RUN nel report corrente.

### Esecuzione — 2026-10-07 UTC, ripresa locale bounded della root vuota

**File modificati:** `SyncStoreGeneration.swift`, `SyncOrchestrator.swift` e `AtomicGenerationRecoverySnapshotPullServiceTests.swift`; nessun cambiamento a Database/EditProduct/LocalRootPresentation, fixture DEBUG, UI originali o dipendenze. Fonte finale48 nel freeze esterno `ios-empty-root-inactive-event-active-catchup-fix-20261007-01/source-freeze-final-v2.json`, SHA34904f161cebd6e696950c6609ff65aabf34bcfa933ac37d77537730eb94ba07;45carry invariati rispetto alla precedente fonte c193.

**Azioni ed evidenze:**
1. Worker empty: RED file-backed ba9f3db2 su drift fisico durante il readback già hidden; massimo due readback completi, ciascuno preceduto da tutti i controlli correnti. Shop/owner/device/journal/cancellazione/revoca/container non diventano retry fisici. La prova GREEN richiede esattamente due readback dopo i nove fetch, senza ribasare il vecchio fence.
2. Postpublication: RED e62135c8 dimostra prima pubblicazione valida, una sola mutazione metadata, root ancora hidden e nessun successore. Lo stesso test GREEN082afaf3 produce due readback e riammissione. Nuova sottoscrizione owned Orchestrator a objectWillChange, coalescing MainActor e massimo un successore corrente; eventi validi/inammissibili non consumano il budget. Nessun getter con side effect, polling, Retry o trigger cloud.
3. Inactive→active: RED50e7511c dopo evento realmente scartato mentre inactive; stesso metodo GREEN6d6b0acd dopo una sola chiamata al consumer locale nel vero handler active. Editing busy DEFERISCE il cloud: non è un RPC già in-flight. Barrier DEBUG attende/cattura soltanto il Task owned esistente. Stop prima di active, cancellazione del Task reale già queued, scope/device/journal esteri validi e revoca sono controlli negativi; nessuna seconda qualificazione manuale.
4. Mirati18 PASS/0FAIL/0SKIP, receipt11b7b09aa5ba3a79486b9d89216209e3c5a25c57041530ece24e1b47c19f6919, tutti125 metodi Atomic precedenti,5 contratti fixture e helper preservati byte-esatti; quattro metodi aggiunti rispetto a c193. Nessun warning nei sorgenti cambiati. Full finale: 1569 actual =1533PASS/0FAIL/36 stessiSKIP, tutte16UI PASS; receipte72021c718e2722d728c36818dc99a675c517682abb3604e5f15043cc5b3c6be. Debug/Release/Analyze: PASS Debug/Release/Analyze;34warning legacy esatti,0nuovi/changed/unclassified; receiptd042cfd1609bee2e1666e1e85dfb77cd419ba4b31352a5381731c0b7aff581cf; confronto warning83198cf0d580ed8f9b7143130f436e548981ff3b0411cbab0c75ea28f3e9e638. Secret scan/shared contracts: PASS, receiptc8e631e4138ca7e5a85412c6ea95e6b8691842e2d673e03413c0e21d19111054.

**Check obbligatori:** full e gate appena indicati sono esiti actual, non prove live. Proper TEST firmato è NON ESEGUITO al congelamento di questa append; il solo esito terminale successivo sarà nella receipt esterna `ios-empty-root-postpublication-active-catchup-final-proper-test-guard-01/signed-release-attempt01/build-receipt.json`, mai inferito. Primaria459, installazione, sessione autenticata, F/H e performance restano separati e NON ESEGUITI da questa lane. Il witness usa controller/Orchestrator reali in unità controllata, non un root SwiftUI montato.

**Incertezze:** CI3c originale ufficiale1563=1526P/1F/36S resta storica FAIL/UI278. ZIP/log/AX/stdout acquisiti una volta; causa dell'operazione fisica iniziale resta UNKNOWN, senza promuovere i nuovi witness a causa CI o prova backend. Task resta FIX; Planning, criteri e MASTER invariati.

## Review

Review indipendente e re-review completate: sorgente APPROVED, nessun P0/P1/P2 aperto dopo R-I01, R-I02, R-I03 (diagnostica e scheda generale) e la correzione test-only del crash runtime26. Gate locali finali PASS, prima run interrotta conservata. [Rapporto indipendente](EVIDENCE/TASK-144/independent-review.md). Approvazione tecnica distinta da review GitHub del maintainer e accettazione autenticata.

## Fix

### Fix — 2026-10-08 UTC, archivio stale e transizioni journal entro lease

Il solo errore tipizzato `markerNotVerified` di una recovery same-scope activated non finalizzata può passare al percorso canonico di staging fresco. Il checkpoint iniziale e ogni successivo checkpoint B devono conservare scope e floor dell'archivio, avere watermark globali/di dominio non regressivi e un cambiamento reale di contenuto o watermark; il solo digest dell'envelope o l'ID di baseline richiesto non basta. Rimangono obbligatori marker, fence, autorizzazione corrente, cancellazione, trasferimento del lavoro locale, cutover e finalizzazione. Archivio già finalizzato mantiene il resume senza RPC; auth/lease/transport/decode e journal estraneo falliscono chiusi. Non viene aggiunto un requisito pending0 né un READY sintetico.

Le transizioni scoped del journal confrontano lo snapshot atteso e restituiscono quello realmente persistito prima di rilasciare la stessa lease esistente: non basta più il confronto esterno seguito da una lettura separata. Il caso CAS RED02 immutato passa nella classe136. Il confine protegge gli scrittori che partecipano all'API scoped; non dichiara serializzate scritture dirette a file/defaults estranee a tale contratto. La diagnostica popolata mantiene l'ordine e la singola valutazione dei predicati esistenti, senza nuova IO o modifica di admission. Nessun cambiamento a DatabaseView/EditProductView/LocalRootPresentationState, fixture/UI originale o policy di firma in questo delta.

### Fix — 2026-10-07 UTC, empty worker e consumer locale dopo publication/active

RED→GREEN controllati separano il readback fisico in-flight dal drift successivo alla pubblicazione e dall'evento scartato in inactive. Retry worker massimo2; consumer Orchestrator coalesced con un solo successore, lease/owner/autorità correnti e stop/cancel. Al ritorno active il consumer locale viene richiesto prima del foreground cloud, che può restare deferred. Prova/fence/scope/writer DENY e test UI originali preservati. Review finale stesso reviewer APPROVED senza rilievi sul freeze34904;18 mirati actualPASS. Le prove unit/lifecycle non equivalgono a accettazione SwiftUI/live o attribuzione retroattiva del primo drift CI.

### Fix — 2026-10-07 UTC, body-proof con provenienza stabile e autorità fresca

La prova fisica può essere pubblicata dopo il normale refresh same-shop usando l'autorità corrente atomica, senza dipendere dal timestamp selectedAt o dalla vecchia lease; ogni vecchio writer rimane stale. Owner/manifest/container/fence, live role/status/write/selectability, device/revoca e journal binding restano stretti. Un terminale transitorio false riceve un solo successore coalesciuto dal vero evento resolver; il drift al boundary mantiene i due readback bounded. Il progresso prepared→staging dello stesso journal non equivale a cambio della sua autorità: replacement binding intero con nonce, mode e device restano esatti. Sei regressioni più negativi e mirati17/full1563 PASS sul freeze337c; review C finalev3 APPROVED zero finding. Nessuna modifica B/editor, nessuna authority nuova/READY sintetica, polling o nuova dipendenza.

**Fix aggiornato — 2026-10-06:** diag080b e editor window-attached3584 sono conservati sul candidato42/HEAD0a48. Genuine8 e Full05 correnti PASS; il singolo witness temporaneo prepubblicazione è NOT_TRAVERSED e completamente rimosso, senza nuovo fix A. Successore automatico osservato; causa CI storica UNKNOWN. Debug/Release/Analyze05/zero nuovi warning e Proper FULL TEST05 PASS; CI esatta e lane esterne restano da chiudere. Stato FIX invariato.


**Fix — 2026-10-06, A diagnostica080b:** conservata dopo il PASS originale locale. Solo osservazione DEBUG dei valori già valutati; errore/ordine/short circuit/callee count preservati. B rimane il fix DB3584 già verificato sul test originale; nessuna causa comune A/B dedotta. La source diagnostica e il runner finale restano tracciati nei pacchetti esterni `ios-empty-root-first-denial-observation-offline-20261006` e `ios-empty-root-first-denial-one-ui-run-01`.


### Fix — 2026-10-06 — confine di presentazione editor

Candidate source48 approvato4f0ba0a3: solo Database3584 differisce dal B4, altri47 byte-identici. Callback sincrona `viewDidAppear` con controller e parent nella stessa finestra; ammissione fresca e presentationID corrente, tentativo unico per generazione e invalidazione su dismantle. Originale B completo PASS e72c; l’altro fallimento ufficiale UI277 resta distinto. Gate completi finali e nuova CI necessari prima dell’integrazione.


**Fix aggiornato 2026-10-06 — fonte48 b4fc7, HEAD nativo c89, Task FIX:** il RED935/rootfdc dimostra il difetto nel controesempio esplicito unavailable/qualifica; il guard di produzione same-owner è chiuso dai GREEN esistenti. Provider/summary terminale e helper zero-reopen sono DEBUG/test; await superfluo e confronto stable7 sono delta privati della fixture. La sola nuova diagnostica full-scope è riordinata dopo sealed-revision per preservare l'assert originale UI169/174. L'ammissione fisica/currentfull7/fence/revalidate e l'autorità degli old writer non sono rilassate. Due UI66fa7c4a, unit8 138b2227, stessi reviewer57e42f12 e Full03 487b7b0a/root e38e8f2e sono prove distinte sul source48 uguale. Full02 FAIL e causa storica UNKNOWN restano immutabili. Build/warning03, Proper03, SQLite e Git/CI: Build/Analyze PASS con 34 warning legacy identici e zero nuovi (6fb1b995/89928698/root657cb45f); Proper firmato PASS, non installato (29b32eb4/rootbece698d); un solo unitario SQLite PASS (425b2c57/root5474e5f1), diagnosi teardown-only falsificata (b25d7043/root2c4ce151/addendum834936d6), worker/private cleanup UNKNOWN e ritenzione primaria BLOCKED manual-unlock; PR/main CI, merge e FF NON ESEGUITO, prova esterna futura PENDING. Nessun CA, Planning, Decisione o stato globale modificato; live/per-record F, H e device primario aperti.

**Fix 2026-10-06 — candidata empty-root e fixture controllata, fonte finale949:** RED reale0P1F0S/rootfdc614fc prova la perdita dell'ammissione dopo qualifica nell'intervallo unavailable con fisica e full7 invariati. Il guard conserva soltanto la candidata same-owner durante `shopContextUnavailable`; permitsScopedEmptyRoot/fence/full7/revalidate/worker/post-await e writer restano strict. GREEN8/rootd235c7f2 e le review C dati1791301901/UX1791301949 sono PASS/APPROVED; la fixture DEBUGV2 e il helper privato5 righe entrano in un secondo commit separato. Nuovi full/build/warning/ProperTEST e CI sono PENDING; Task FIX invariato, nessun CA marcato DONE.


**Fix 2026-10-06 — pubblicazione empty-root dopo refresh same-scope:** solo guard finale `startEmptyRootQualification` usa scope CURRENT con sette valori completi uguali all'originale,diniego/cancel/container/manifestnil/full physicalfence e fresh finalrevalidation senza await;pubblica proof immutabile current. Scan9/Task126/writer/READY/RPC/UI/timer invariati;oldwriter resta DENIED. Positivo desiredRED54cc immutato e freshvalid foreignshop/device7061 byteexact a98;mirati8/full11/build11/proper11 PASS,review SAME2 APPROVED0af5. MainCI82ef cause esatte UNKNOWN;osservazione3P è NOT_OBSERVED,non causal attribution.

**Fix 2026-10-06 — shell vuota valida durante stesso-scope refresh:** solo guard `permitsScopedEmptyRoot` usa current full authority+sette campi stable/pending esatti,full physicalfence e final currentrevalidation. Old Task126/writer DENIED invariato;nessuna proof/READY/write grant. Due nuoveunit reali includono RED byteidentico e freshvalid foreign-shop/store/device negativa. Mirati6/full10/build10/proper10 PASS,stessi due reviewer f0ce APPROVED. Main CI d918 exactleaf UNKNOWN;original observationPASS NOT_OBSERVED e RED semantico distinto.

**Fix 2026-10-06 — oracolo DEBUG corrente, prodotto normale invariato:** normale qualificazione al reopen dopo refresh; replay typedsealedA esaustivo e preACK, evento Product reale/currentACK+Historypending; finale13righe usa autorità stretta corrente, intera identità stabile e prova body/container, rivalidazione corrente. Vecchi writer stale restano DENIED. Prove reali ordine/ACKlease + nuova solaUI replay40s;14metodi/budget originali intatti. Mirati10/full09/build09/proper09 PASS;stessi due reviewer10a APPROVED. CI0757 e Full06/07/08 restano FAIL storici con limiti UNKNOWN;nessun Ready/count-only/pending-authority shortcut o nuovo skip.

**Fix CI runtime — 2026-10-06:** il positivo Task114 verifica l'esito con il default ordinario, non una latenza50ms sull'intero MainActor; negativo vero5ms e oracoli di successo intatti. Nessun fix prodotto UI basato su ipotesi: i tre casi originali e il loro ordine di classe passano localmente, con diagnosi corrente su future failure. Full05 e build/analyze/proper05 PASS sulla fonte48; CI639d4FAIL e causa UI UNKNOWN restano storici espliciti. Nessun nuovo skip o timeout UI modificato.


Compatibilità CI 2026-10-06: i due errori di inferenza Swift in Transfer sono corretti con soli tipi/intermedi espliciti, semantica invariata e46carry bytes identici. Source47 corrente: mirati7 PASS, full04 **1505 PASS/0 FAIL/36 SKIP** (tutti14 UI), Debug/Release/Analyze e nuovo proper signed fullTEST04 PASS; zero nuovi warning. Review mirata APPROVED. La CI37390541718/head4382 resta FAIL storica, gate a valle NON ESEGUITI; nuova CI dopo commit/push parent ancora NON ESEGUITA. Task FIX, live F/primaria459/H aperti. [Prove correnti](EVIDENCE/TASK-144/local-availability-20261005/README.md).


Disponibilità locale 2026-10-05, source47 byte-identico freezev3: cause di accesso/overlay/CAS/replay A/B, body-proof, root/focus/native XXXL e ultimi delta ordinary admission/stop/notify/resume/exact relation ACK chiusi nelle prove controllate GREEN13 e full03 **1505 PASS/0 FAIL/36 SKIP**. Debug/Release/Analyze e proper signed fullTEST PASS sullo stesso source; zero nuovi warning. [Prove correnti](EVIDENCE/TASK-144/local-availability-20261005/README.md). Full01/02 e FAIL01 driver conservati con attribuzioni, mai reinterpretati. Task FIX; F autenticato, primaria459 e H restano NON ESEGUITI. Review equivalente/delta dagli stessi due reviewer e integrazione/CI exact-head spettano al parent; nessuna acceptance futura dichiarata.
R-I08 V6 corrente: boundary tipizzato ordinario, caller empty0 e fence avanzato dopo reopen APPROVED sul source326ac3b. Mirati5PASS e full1428PASS/36sameSKIP/0FAIL con57Atomic/23newPASS verificati indipendentemente. Generic118/119 e getterzero/RPC/backend restano failclosed/invariati; ordinary mantiene verifiedConvergencefalse/lastVerifiedAt. [Slice portabile corrente](EVIDENCE/TASK-144/ri08-ordinary-sync-state/README.md). Full, Release, Analyze e TEST firmato sono ora PASS verificati nelle rispettive receipt sullo stesso326ac3b;26legacy signatures/34occurrences esatte e0nuove, nessuna risoluzione inferita. Ledger locale finale portabile; exact Git/CI/main e acceptance live/performance restano distinti, taskFIX e nessun DONE.


R-I04: cinque reader XML elaborano namespace; fixture condivise real ZIP/XML e tre regressioni APPROVED. R-I05 (P1): sessioni/eventi/completion e storage SDK recintati per generation; cleanup verificato prima della rotazione/interazione, client foreground/background condiviso e snapshot thread-safe. Venti test SDK reali, mirati54/0/1 e full1397/0/36 sul fingerprint0fa8, tre review/supplementi APPROVED. [Evidenza e limiti](EVIDENCE/TASK-144/ri05-auth-lifecycle/README.md).

R-I06: History ammette legacy esistente oppure UTC esatto a tre cifre frazionarie con calendario valido; ledger/digest conserva stringa originale, Date materializzato/readback `.305` verificato. Prezzi/UTC6/outbound/model/fingerprint e SDK auth invariati; nessun dato reale riscritto. Rosso1FAIL prima patch,57 mirati PASS, review indipendente APPROVED e full finale1402/0/36 sul fingerprint41eb; Release/analyze e signed TEST separato verificati. [Manifest e limiti](EVIDENCE/TASK-144/ri06-history-timestamp/final-gate-manifest.json). Questa approvazione locale non equivale alla chiusura globale/live.

R-I03 (P2): errore e timestamp derivano dal risultato canonico corrente; scope visibile da owner autenticato e shop risolto, senza side effects. La scheda cloud distingue fallimenti generici da reali permessi/auth. Sei test diagnostica e due card aggiunti; red/green e due approvazioni indipendenti nel [manifest](EVIDENCE/TASK-144/ri03-current-diagnostics/manifest.json). Nessuna modifica recovery/auth/retry e nessuna assertion indebolita.

R-I01 (P1): due test rossi hanno riprodotto ricevuta A non consolidata prima di leggere C. Il batch distingue ricevuta e stato corrente, consolida atomicamente A, ribasa B su A prima del conflitto e rende la base disponibile all'editor; retry identico adotta C, delta solo prezzo preserva nome C al reapply. Errore disco conserva l'intent precedente. Guardia finale scope protegge anche readback che termina offline dopo cambio shop. Re-review limitata APPROVED;46 unit + 4 UI finali PASS.

## Handoff

### Handoff corrente — 2026-10-08 UTC, fonte48_342f / Atomic136 verificata

Il freeze finale è [source-freeze-final-v2.json](/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/ios-activated-unfinalized-stale-marker-minimal-fix-20261008-01/v2-with-journal-cas/source-freeze-final-v2.json), SHA `342f3357da88dea3a3572d5dd677894234212f26c57edfc5161fa2edceda2270`; patch combinata `34fd6aaf853c442c607ec28c69751cdc4e6d4b6c37e85524aabd10facef451c2`, inversa `ccc2156c0c1acd1af8257e3fe0d2e76bbc97903ec76d9eff0e3e3b703768c705`. Forward/inverse stretti ed esattezza dei134 metodi/helper originari sono verificati. L'osservazione V2 approvata è distinta dalla correzione recovery/CAS e non è una prova di nuova usabilità locale.

Snapshot di questa aggiunta: HEAD base `a8980fe5dd0850fe1dd505d51034fe6304a1c08b`, Task committed `8f0891d8e7f815d64e5cd1440cfc25e1be7f22da650e34540320d3c682f0312c`, working straniero `3d75b66fc5fd3d2243940835d4a576943edc93d9061e65db01caaa37411e6e17`. Le tre sole inserzioni Execution/Fix/Handoff sono preparate fuori checkout; rimuovendole si devono riottenere entrambe le basi byte-esatte. Nessuno staging delle modifiche straniere, nessuna modifica Planning/criteri/Master o chiusura DONE.

Gate locali correnti sulla fonte342f: Atomic136 e full1576 PASS (1540PASS/0FAIL/36 stessiSKIP/tutte16UI), Debug/Release/Analyze PASS, comparer34 legacy esatti e zero nuovi/changed/unclassified, quattro contratti condivisi OK. Lo scan richiesto esatto del workflow è PASS (reportd17d/receipt2eb6). Extra scan01 NAME_MAX ed extra02 FAIL con due match attribuiti tecnici restano originali distinti; attribuzione9ccf non riscrive il risultato scanner. Prima dei rispettivi passi di integrazione/consegna il coordinatore deve sostituire i segnaposto residui con la receipt reale di Proper TEST, secondo l’ordine autorizzato: Proper non introduce un nuovo requisito prima del normale commit. `PENDING_ACTUAL_GIT_CI_RESULT` rimane non eseguito fino al nuovo commit e alla CI exact-SHA effettivi; non sono inventati head/run/merge futuri. Integrazione e primary install/input restano al coordinatore. Sessione reale, disponibilità business locale, cloud sync/recovery, performance e residui F/H richiedono le rispettive prove correnti e non derivano da Atomic136.

### Handoff corrente — 2026-10-07 UTC, fonte48_34904 / empty qualification bounded

Questo blocco prevale sugli snapshot preparatori sotto:18 mirati PASS, 1569 actual =1533PASS/0FAIL/36 stessiSKIP, tutte16UI PASS, Debug/Release/Analyze e scans PASS Debug/Release/Analyze;34warning legacy esatti,0nuovi/changed/unclassified. Proper successivo qualificabile solo dalla receipt actual indicata nella Execution; non installato da questa lane. Staging selettivo soltanto tre sorgenti e questi tre inserimenti Task; rimuovendoli si riottengono working precedente c1c029ff con le286 righe straniere e HEAD Task885e4781 byte-esatti, conservando le286 righe straniere. Commit/push/PR20/CI exact-SHA successivi restano da verificare: nessun merge/main/sourceFF/install o DONE è dedotto dai gate locali. Parent possiede merge/primaria; F/H/sessione/SQLite/live conservano i propri limiti ed esiti distinti.

### Handoff corrente — 2026-10-07 UTC, SOURCE48_337c / tutti gate locali finali PASS

Questo blocco prevale sugli snapshot storici sotto: mirati17 PASS; full1563=1527P/0F/36stessiS/16UI; Debug/Release/Analyze e Proper TEST firmato PASS, zero warning nuovi. Fonte48 e ricevute sono quelle della nuova Execution sopra, validate con HEAD base06825 più working congelato; il normale commit selettivo deve includere soltanto i quattro file sorgente e questi tre inserimenti Task, lasciando fuori le286 righe straniere. Rimozione dei tre inserimenti restituisce byte-esatti HEAD Task0ba52 e working foreign8091.

Pacchetto firmato esterno `ios-manifest-qualification-final-proper-test-guard-01/signed-release-attempt01/Artifact/iOSMerchandiseControl.app`, binary681c/profile154a/23file, NON INSTALLATO. Lane native rilasciata,6BShutdown; primaria459 intatta. Commit/push/PR ed exact-head CI sono il passo ordinario successivo; conservare una sola acquisizione raw/xcresult ufficiale prima della scadenza. Merge/mainCI/sourceFF/nuovo install e runtime primario spettano a N dopo i veri gate verdi e fresh preservation. Non eseguire UI fixture sulla primaria. F/H/per-record/autenticazione/performance e chiusura globale restano distinti, task FIX.

**Handoff aggiornato — 2026-10-06:** nessun nuovo witness identico o Full05 immutata. Build/Analyze/zero nuovi warning e Proper signed FULL TEST sulla fonte42 restaurata sono PASS; proseguire push normale/CI originale pertinente con080b. Non inferire DONE da fixture locali; Android finestra primaria resta in attesa dell’unica risposta umana, sessione/APK88 invariati. Live F/per-record convergence/H e installazione/ritenzione primaria iOS restano aperti. Non scrivere MASTER o il Task foreign14c; commit documentale del solo blob Task owned e dei due riepiloghi evidence owned,stage selettivo dopo rilascio producer.


**CURRENT 2026-10-06 — A_ORIGINAL_LOCAL_PASS_NON_REPRODUCED / DIAGNOSTIC080B_RETAINED / B_DB3584_RETAINED; task FIX, NON DONE.** Unico A originale/source7db: 1P0F0S, nessuna causa CI attribuita. Dopo chiusura export/risorse, normale commit dei quattro soli file diagnostici e log owned, freeze effettivo con HEAD reale, genuine8 e gate completi sullo stesso source, poi CI pertinente. Vecchio Full04/source754 HOLD. Medesimi reviewer verificano terminali; no rerun cieco, inverse automatico, merge/install o PASS live. AndroidAPK88 non reinstallare/reset/logout: attende solo la finestra Running Devices accessibile già richiesta all’utente.


**CURRENT 2026-10-06 — B_EDITOR_ORIGINAL_UI_PASS / PRODUCTION_PATCH_RETAINED; task FIX, NON DONE.** Root ha verificato receipt e72c/inverse91e/executor d77/root706 e conserva DB3584 con commit normale. Nuovo native HEAD e source freeze sono registrati nel pacchetto esterno `ios-window-attached-editor-production-retention-01`; vecchio freeze4f resta immutabile e non viene rinominato. Successivo owner I: genuine target8 sul nuovo source/freeze, poi full canonico1548 e Debug/Release/Analyze/TEST. A: diagnosi DEBUG circoscritta sui primi operandi effettivi, zero query aggiuntive o autorità indebolita; nessun rilancio cieco della CI originale. Android APK88/sessione/dati conservati, verifica UI primaria ancora bloccata dal canvas non raggiungibile. Nessun merge/CI verde/install/accettazione live dichiarato.


**CURRENT 2026-10-06 — QUATTRO_COMMIT_NORMALI / SOURCE48_b4fc7 / NATIVE_HEAD_c89 / UI2_2P0F0S / UNIT8_8P0F0S / FULL03_1548IDs_1512P_0F_36S_15UIP; Task FIX.** Prova sorgente/commit `fab7b97e`, Full03 receipt `487b7b0a`, root `e38e8f2e`. Stato gate successivi: BUILD/ANALYZE03 PASS, baseline34 immutata/zero nuovi (6fb1b995/89928698/root657cb45f); PROPER03 TEST firmato PASS, binary1ef75f21/23file, non installato (29b32eb4/rootbece698d); SQLITE singolo unitario originale 1P0F0S (425b2c57/inverse21c40814/root5474e5f1), diagnostica17record/8warning e teardown-only FALSIFIED (b25d7043/root2c4ce151). Worker/kernel/private cleanup UNKNOWN, primary session/outbox/retention BLOCKED manual-unlock; CI PR/main, merge normale e source-only FF NON ESEGUITO/PENDING al commit documentale. L'esito reale di integrazione verrà vincolato nella receipt esterna finale, senza inventare proofSHA futuri. Il parent può creare un commit normale esclusivamente del Task HEAD con queste tre aggiunte; il Task working foreign14c resta identico e fuori staging. Dopo tale commit, PRHEAD e prova commit/Task devono essere acquisiti realmente e vincolati nei metadati V5; non riusare o rietichettare l'HEAD nativo c89, il proposal head storico da2f o le receipt economiche. Prima di push/CI/merge/FF usare nuove prove native/SQLite e i guard esistenti: sei step CI realmente SUCCESS,1548 stessi ID/stati/36 stessi skip, PR base OID fresco con fetch e albero reviewedb4, due parent nel merge e albero intero uguale al candidato, preservazione10dirty/config/stash/index e FF-only/no-autostash. Snapshot remoto PR18/head9945/base82ef OPEN-UNSTABLE è storico; nessuna sua proprietà vale come prova al futuro merge. Nessun install/azione device, dato/sessione/outbox primario o F/H live viene certificato da source-only FF. Task FIX e richiesta manual-unlock restano aperti; nessun DONE globale.

**CURRENT 2026-10-06 — FINAL_SOURCE48_949 / UNAVAILABLE_QUALIFICATION_RED_CONFIRMED / GREEN8_8P0F0S / SAME2_APPROVED_0 / FINAL_GATES_PENDING; task FIX.** HEAD9945 è il parent dei due commit normali proposti: commit1 ripristina quattro diagnostici e contiene guard+regressione originale7; commit2 contiene fixture DEBUGV2+helper privato5. Task working foreign14c resta identico e fuori indice, MASTER/workflow preservati. Dopo i commit occorre fissare l'HEAD reale nei producer Full11/Build11/ProperTEST11 retargetati, poi un solo full non filtrato con1548 ID/36 stessi skip/parallelNO e i gate dipendenti in ordine. Non avviare CI, merge, install, F/H o nuove prove da questa registrazione; nessuna retroattribuzione CI37466894761. Il presente log non certifica gate ancora PENDING.


**CURRENT 2026-10-06 — SOURCE48_0af5 / TARGET8_PASS / FULL11_1548IDs_1512P_0F_36S_15UI / DEBUG_RELEASE_ANALYZE11_PASS / SIGNED_FULLTEST11_PASS;task FIX.** HEADb4 precommit;binary `12561c48248fa8180c759bcdd8c1618b9402a266c099e611d86920d72c94e702`/profile154a/23file/signature-effectiveSimulatedxcent-embedded-keychainP,NONINSTALLATO. FollowupPR/exact-head/mainCI PENDING;main82ef storicaFAIL/causeUNKNOWN. Parent soloGit:stage Controller/Atomic/2docs+SOLO3newTaskhunks,inverse→5fba/foreign73add19del net54 fuoriindex;FF/installprimaria solo con freshmainPASS+guard. Ownedrunner/group0,6B04Shutdown/baseline/config preservati;I source/heavy/device/input0 dopo rilascio. F/459/H NOT_RUN,Maclocked nessun bypass.

**CURRENT 2026-10-06 — SOURCE48_f0ce / TARGET6_PASS / FULL10_1546IDs_1510P_0F_36S_15UI / DEBUG_RELEASE_ANALYZE10_PASS / SIGNED_FULLTEST10_PASS; task FIX.** HEAD7b precommit;binary `97d7d8d409f57c72427359fa237f30f13a28154cd46a17ce0884d56c5501a195`/profile154a/23file/signature-effectiveSimulatedxcent-embedded-keychainP,NONINSTALLATO. FollowupPR/exact-head/mainCI PENDING(PR16 giàMERGED);main d918 storicaFAIL/leafUNKNOWN. Parent soloGit:stage Controller/Atomic/2docs+SOLO3newTaskhunks,inverse→1f1d/54foreign fuoriindex;FFprimaria solo dopo freshmainPASS+guard. Ownedrunner/group0,6B04Shutdown,businessbaseline/config preservati;I source/heavy/device/input0 dopo rilascio. F/459/H NOT_RUN,Maclocked nessun bypass.

**CURRENT 2026-10-06 — SOURCE48_10a / TARGET10_PASS / FULL09_1544IDs_1508P_0F_36S_15UI / DEBUG_RELEASE_ANALYZE09_PASS / SIGNED_FULLTEST09_PASS; task FIX.** HEAD0757 precommit;binary `79931be9fd6f779608e5f2a011e88eee1a0f50cf1f173224416875d5f5df614f`/profile154a/23file/signature-entitlements-keychainP,NON INSTALLATO. Nuova exact-headCI PENDING,CI0757 storicaFAIL;Full06cause/Full08leaf UNKNOWN. Parent soloGit: stessaPR16/exactCI/normalmerge/mainCI/primaryFF preservando dirty. Stage3source+2docs+solo3ownedTaskhunks,inverse→8815 e54foreign fuoriindex. Nessun ownedrunner/group,6B04Shutdown/baseline/config primaria intatti;I source/heavy/device/input0 dopo rilascio. F autenticato/459/H NON ESEGUITI,Mac unlock pending;nessun bypass.

**CURRENT 2026-10-06 — SOURCE48_FIXTURE_CI_DIAGNOSTICS / FULL05_1505P_0F_36S / DEBUG_RELEASE_ANALYZE_PASS / SIGNED_FULLTEST05_PASS, task FIX.** HEAD639d prima del nuovo commit;3 delta owned e45 carry esatti. Artifact binary `2795dc0916328b69ce2345ccbe7c38c50420de9140274c86d602c938684b04fa`,23 file/profilo154a/firma/entitlements/keychain PASS,NON INSTALLATO. CI37394390166 resta FAIL1501P4F36S: causa tre UI UNKNOWN, nuova CI exact-head PENDING. Parent soloGit per aggiornare PR16 esistente/CI/merge/mainCI/FF preservando dirty. Stage solo3 source+2docs+tre nuovi hunks Task144 sopraHEAD639d;inverse→08321017… e54 foreign fuori index. Nessun runner/group attivo,6B04 Shutdown/baseline/config primaria preservati;F autenticato,primaria459/H NON ESEGUITI. Pacchetto esterno `ios-ci-current-runtime-final-handoff-20261006/manifest.json`; questo prevale sugli snapshot storici sotto.


**CURRENT 2026-10-06 — SOURCE47_COMPILER_COMPAT / TARGET7_PASS / FULL04_1505P_0F_36S / DEBUG_RELEASE_ANALYZE_PASS / SIGNED_FULLTEST04_PASS, task FIX.** Branch `codex/ios-local-availability-20261004`, HEAD4382 prima del commit correttivo; Transfer2178f81d è l'unico delta di produzione,46carry byte-identici al v3. Nuovo Artifact binary `0e188fbed26463893eee82c38ead1e6adc3e7f4145359552ce6e479cc8546e01`, profilo154a/firma/entitlements/keychain PASS, NON INSTALLATO. Final handoff esterno `ios-transfer-ci-compatibility-final-handoff-20261006/manifest.json`; parent solo Git per commit/push PR16 esistente, CI nuova exact-head, merge/mainCI e FF primaria preservando dirty. Stage selettivo: singolo delta Swift,2 portable evidence docs e solo i tre nuovi hunks Task144, inverse→f01e0d8e…;54 insert preesistenti fuori index. Nessun runner/group attivo,6B04 Shutdown, baseline/default.store e primary config/sessione/459 preservati; live F/H e primaria NON ESEGUITI. CI4382 FAIL/full03/proper02 sono snapshot storici, non acceptance della nuova fonte. Questo testo prevale sugli handoff sotto.


**CURRENT 2026-10-05 — SOURCE47_FINAL / CANONICAL_FULL03_1505P_0F_36S / DEBUG_RELEASE_ANALYZE_PASS / SIGNED_FULLTEST_PASS, task FIX.** Base433e, branch `codex/ios-local-availability-20261004`;43Swift (36production+7test) +4strings nel [manifest](EVIDENCE/TASK-144/local-availability-20261005/source-and-targeted-evidence.json). Source47 invariato da freezev3 eGREEN13; full03 tutti14 UI PASS compresi root held/Save/draft/focus/C/automatic terminal/reopen e nuovo supplier/category pending→exact ownACK. Build/analyze warning baseline34, zero nuovi; proper8profile/signature/entitlements/keychain PASS, binary `17c0b7aab436822b968f2122b1bed0bd6b138693a4dc4da6ceaf2d884e2ecae5`, Artifact esterno e NON INSTALLATO. Tutti runner/group rilasciati, isolato6B04 Shutdown e baseline default.store preservata; fonte/config primaria e459 non toccati. Parent soloGit:49 file owned code/resources/evidence e patch dei soli tre nuovi hunks Task144;54 insert preesistenti fuori index, inverse dei tre restituisce f30addf… esatto. Nessuna mutazione Git da questa lane e nessun CI/PR/merge futuro dichiarato PASS. F autenticato, install/retention primaria459 e H restano NON ESEGUITI. Handoff finale esterno `ios-local-availability-final-handoff-20261005/manifest.json`; questo testo prevale sugli snapshot sotto.
**CURRENT R-I08 V6 — ALL_LOCAL_FINAL_GATES_VERIFIED / SOURCE_APPROVED, taskFIX.** Source326ac3b/freeze8208/Atomic98fd/build3/cache13 invariati. Full1464unique1428PASS/36sameSKIP/0FAIL(1420unit+8UI), tutti57Atomic/23new e vecchi1441ID, reviewe374; mirati5PASS/19stagefcba. Release22file/strict2, Analyze26signature/34occurrences legacy exact0nuovi, TEST23file/strict2/binary2783283d/primary86apreserved/owncopyremoved verificati review16011 e hosthandoff3d232. [Ledger locale finale](EVIDENCE/TASK-144/ri08-ordinary-sync-state/validation-ledger.json) e [README](EVIDENCE/TASK-144/ri08-ordinary-sync-state/README.md) contengono IDstatus/reason/receipt/rawhash pubblici; draft e failure storici preservati. RootsoleGit deve verificare equivalenza326source/build3 del nuovo commit, exactheadCI/normalmerge/mainCI. Non si dichiara build dopo commit non ancora avvenuto, install/auth/recovery business/fourclient/performance o DONE. Questo handoff corrente prevale sugli snapshot preparatori e handoff storici sotto.


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
