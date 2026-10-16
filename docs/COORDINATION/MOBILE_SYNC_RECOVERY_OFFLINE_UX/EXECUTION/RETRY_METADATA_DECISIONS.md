# Retry metadata — decisioni execution

Decisione del coordinator/executor, 2026-10-16 UTC. Contratto applicabile: [CONTRACT](../CONTRACT.md). Questa decisione precede la patch di retry e non certifica un risultato runtime.

## iOS: budget locale v2

Il record v1 contiene solo identity/count/nextAllowedAt: non dimostra la natura transitoria né la fine dell'ultimo tentativo. Il nuovo JSON Codable è locale a UserDefaults, chiave `<prefix>.automaticRecoveryAttempt.v2`, schemaVersion2. Campi: identità redatta; indice finestra; tentativi nella finestra (1…3); tentativi cumulativi; inizio e completamento ultimo tentativo; failure tipizzata; nextAllowedAt; eventuale Retry-After assoluto. Nessuna modifica schema DB, body, RPC o journal di recovery.

La failure conserva categoria enum e soli codici strutturati pertinenti (HTTP/URLError/SQLSTATE quando disponibili), senza payload/token o messaggi liberi. Transient: rete/DNS/timeout,408,429 e5xx ammessi dal contratto; cancellation esplicita, auth/revoca, payload/schema/integrity e unknown non ottengono rinnovo per il solo tempo. SQL57014 da solo non prova statement-timeout. Retry-After valido è un minimo, anche oltre il cap locale.

Un invio effettivo consuma il budget prima del trasporto. Busy/admission senza invio non è un tentativo remoto. Le prime attese seguono backoff/jitter del contratto; dopo il terzo transient completato `nextAllowedAt=max(completedAt+300s,retryAfterUntil)`. La finestra successiva conserva il cumulativo e incrementa l'indice; non cancella il journal o l'intento. Metadata senza completamento, sconosciuta, corrotta o soltanto v1 resta fail-closed; nessuna riclassificazione dal testo e nessuna migrazione che inventi un successo o una failure transitoria. Il v1 originale resta preservato. Un eventuale reset esplicito conserva la semantica preesistente e non è parte dell'ammissione automatica.

La review candidata1 impone un claim opaco persistito e correlato all'invocazione: identity da sola non protegge una nuova finestra nello stesso scope dopo un reset esplicito. Solo il risultato che porta il claim corrente può completarlo; `recordRunResult` ordinario o callback stale non toccano il budget. Ogni attesa mantiene la deadline assoluta ma usa chunk convertibili in nanosecondi senza overflow e cancellabili. La failure tipizzata deve conservare anche la semantica prefix-resume delle pagine già accettate: nessuna quarantena introdotta dalla sola modifica del tipo errore.

Si riusa l'unico task di retry foreground; l'attesa di recovery non usa il cap/budget busy30s. Prima della callback si ricontrollano identità, owner/shop/store/device, auth, journal e lease correnti. Cambio scope/revoca/cancel invalida il timer. Clock e jitter controllabili soltanto come dipendenze interne, con default di produzione invariati. Nessun secondo engine, polling nuovo o aumento dei timeout trasporto.

Prove richieste prima della consegna: RED originale; GREEN sui percorsi reali; stable/unknown/scope negativi; confini temporali299999/300000ms; Retry-After oltre cap; jitter controllato; singolo timer e cancellazione; persistenza/reopen e contabilità tentativi. Il primo RED eseguito qualifica solo riammissione dopo tempo/relaunch, non il timer.

## Android: decisione outbox ancora pendente

Il RED recovery è eseguito; il primo RED queue si è fermato nel setup clock ed è NOT_TRAVERSED. Le seam interne clock con default `System::currentTimeMillis` sono esclusivamente testabilità, non un fix. Un formato persistito outbox e l'eventuale contabilità dei producer Catalog/History richiedono un RED queue valido e una decisione successiva. Non azzerare `attemptCount`, non cambiare `metadataJson`/entity IDs/client event ID e non confondere il rinnovo transient con correction V6.

## Android: recovery metadata v1

Decisione successiva al RED2: Q01 ora riproduce il mancato sesto invio dopo reopen; R01 riproduce assenza di opportunità futura e retry di errore payload stabile. Il negativo revoca si è fermato prima della revoca per una race del clock della fixture, da correggere senza indebolire assertion.

Per recovery si usa JSON locale rigoroso nel campo diagnostico mutabile `SyncRecoveryJournal.reason`, senza colonne/tabelle nuove. Shape: `v=1`, `kind=automatic_recovery_retry`, `code` diagnostico bounded, `category` enum esatta, `windowAttempts`1…5, `state` in_flight/waiting/cooldown/blocked, `nextEligibleAtMs` Long e `claimID` opaco per distinguere esiti/callback del tentativo corrente. `lastAttemptAtMs` e `lastCompletedAtMs` sono fatti espliciti nel JSON: `updatedAtMs` rimane il timestamp del journal e può cambiare su una normale ri-osservazione. `attemptCount` resta cumulativo, incrementato nella transazione claim prima dell'invio. authorizationMode/runId/fence/digest/staging restano governati dal coordinator esistente. Questa correzione del formato prerelease segue la review della candidata2; nessuna sua versione è stata installata o distribuita.

Il coordinator riceve l'eventuale claim automatico come valore interno per invocazione, senza stato globale, e non incrementa due volte il contatore. Completion e scheduling accettano solo il claim corrente nello stesso scope/ownership. Il normale percorso recovery diretto conserva le proprie protezioni e non diventa un bypass del budget automatico.

Parser stretto per versione/campi/enum/intervalli/dimensione/overflow. JSON ignoto/corrotto e legacy failure senza categoria verificabile non si riaprono per il tempo. Primo requisito valido con count0 può essere ammesso dai gate effettivi; nessun codice sintetico di test aggiunto alle allowlist di produzione. Al restart in_flight è esito sconosciuto: budget consumato, nessun rimborso o transitorio inventato; la relativa liveness resta un limite esplicito da verificare separatamente. Waiting/cooldown tipizzati riprendono soltanto alla deadline persistita. Stable/unknown rimangono blocked. Il timer riusa il job single-flight ma rilascia il mutex d'esecuzione durante l'attesa e ricontrolla auth/shop/device/lease prima di inviare.

Questa decisione non autorizza il formato outbox, né dichiara completa la tassonomia429/Retry-After finché non esistono i relativi RED e GREEN.

## Android R02: classificazione e trasporto

RED del classifier eseguito:429,500/502/503 e403 annidato in IOException; poi22test classifier GREEN. `SyncErrorClassification` conserva categoria/status/code, `retryAfterAtMs` e flag `retryAfterInvalid`; assenza e deadline inutilizzabile sono distinti. Valido delta/dateGMT rigoroso non subisce cap. Malformed/negativo/duplicato/overflow non diventano un minimo corto. La deadline effettiva resta il massimo fra minimo server e backoff locale.

RED invoker reale eseguito con SDK sintetico e interceptor prima della connessione:429/503 erano convertiti in contract error Unknown. Fix consentito: preservare tipo e codice esterni sanitizzati e aggiungere causa HTTP strutturata con header, senza body/token nei log. RED cadenza reale rileva5000ms invece di1000…3000: il percorso automatico usa jitter interno iniettabile e formula2s esponenziale del contratto; il percorso diretto storico resta distinto. Nessun limite trasporto aumentato.

Numero invocazioni recovery e richieste HTTP fisiche sono prove differenti. Replay interno503/Retry-After0 e saturazione cumulativa1M richiedono RED dedicati prima di modificare quei comportamenti; nessun PASS del solo scheduler li chiude.

RED candidata4 eseguiti: una chiamata checkpoint produce2richieste fisiche dopo503/Retry-After0; il diagnostico saturo1M impedisce una finestra transient dovuta. Fix consentiti: usare l'helper storico saturante `nextSyncRecoveryAttemptCount` senza reset/decremento, mantenendo windowAttempts e claimID come budget/ownership effettivi; impedire replay trasparenti del body sulla sola RPC canonica recovery. Il body HTTP deve rimanere byte-identico e il normale percorso di autenticazione, URL/header/contratto non cambiano. Non riusare flag diagnostici, trace one-shot o bypass di consenso per abilitare la produzione. Il test wire deve contare sia invocazioni sia richieste e conservare i casi storici come evidenza del comportamento precedente; transport90s invariato. Callback di esito sconosciuto rimane un retry dell'app con identità conservata, non un replay nascosto del client.

Review candidata4 CHANGES_REQUIRED: nuova conferma mismatch (producer reale crea count1) e timer di epoch vecchio che assorbe trigger nuovo richiedono RED reali prima dei relativi fix. Il gate generale dei legacy failure non si allarga per accomodare una fixture; un requisito iniziale confermato deve essere riconosciuto dal suo producer e dalle authority correnti.

RED candidata5 eseguiti sul producer/App e sul refresh reale: nuova conferma non raggiunge checkpoint; refresh stesso shop lascia persa la successiva opportunità. Fix ammessi: riconoscere soltanto l'intento iniziale canonico `scope_mismatch_replace_confirmed`/MISMATCH_REPLACE_CONFIRMED nel suo stato iniziale prodotto realmente, con scope/device/authority validi e senza staging/run o failure pregressa. Il diagnostico storico count1 resta1 e il primo claim lo porta2; `windowAttempts=1` rappresenta il primo tentativo remoto effettivo. Non generalizzare l'eccezione ai legacy failure/Unknown.

La prenotazione del timer deve appartenere all'epoch/scope corrente. Un refresh o cambio reale invalida la sola prenotazione obsoleta e trasferisce l'opportunità al normale scheduler corrente, riusando la stessa deadline e metadata persistiti; nessun reset, nuovo engine/polling o RPC vecchio scope. Se una cancellazione incontra lavoro in corso, restano tutti i guard di ownership, single-flight ed execution mutex esistenti. Richieste identiche nello stesso epoch continuano a coalescere.


## Android Q01/Q02: intento e budget durevoli nella coda eventi

Decisione executor 2026-10-16T03:27Z, dopo RED qualificati candidata6 (80 casi:74 PASS/6 FAIL, pin11/11 invariati). I sei FAIL sono Q01/Q02; R01/reader/classifier sono GREEN locale. Gli originali restano archiviati. Cancellation e ACK ignoto si fermano alla prima divergenza durable-before-RPC: reopen/replay devono ancora essere attraversati dal GREEN.

Si autorizza una patch locale agli eventi Catalog/History nel repository e DAO pertinenti: intento persistito prima della prima RPC; body `metadataJson`, `entityIdsJson`, `clientEventId` e identità immutabili; claim durevole prima dell'invio e completion CAS del solo claim corrente. Ogni invio iniziale dei producer conta nel totale della finestra di5, senza reset del cumulativo. Si riusano drain, single-flight e guard reali di owner/shop/device/local-business-write; nessun nuovo scheduler generale o bypass del gate.

Formato locale rigoroso versionato in `lastErrorType`, nessuna migrazione schema DB: kind dedicato, versione, categoria enum strutturata, fase, contatore finestra, ultimo inizio/completamento, prossima eleggibilità, eventuale minimo Retry-After e claim opaco. Campi mutabili solo diagnostici; chiavi/ID/body dell'operazione restano invariati. Parser con limiti, intervalli e overflow; record corrotti, versioni ignote, stable/Unknown e legacy esauriti senza prova strutturata restano fail-closed. Non inferire transitorietà dal testo. Il percorso storico di correction V6/PayloadValidation resta distinto, con la sua semantica e dati preservati.

Per i transient, backoff/jitter contrattuale; dopo il quinto completamento attendere almeno300s e comunque il minimo Retry-After. Una nuova finestra mantiene cumulativo e identità. In-flight con cancellazione o risposta/ACK incerto conserva l'intento e l'identità per replay idempotente nello stesso scope; nessun rimborso del tentativo. La politica deve consentire il replay qualificato da questa prova senza trasformare un esito sconosciuto in successo o transitorio inventato. Un ACK valido elimina soltanto la propria operazione/claim, non uno successivo.

L'eleggibilità deve essere valutata prima del limite di batch attraverso paginazione keyset nello scope reale, evitando che righe future o bloccate affamino eventi indipendenti già autorizzati. Per Q02 isolare esclusivamente errori di decodifica della singola voce, conservarne la diagnosi e proseguire con eventi indipendenti già ACKati; non assorbire cancellation, errori di scope, seal o integrità globale. Verificare che le operazioni locali non ACKate restino bloccate dal gate esistente.

Prima della consegna: sei GREEN attraversati fino in fondo, stable/unknown/legacy negativi, confine esatto300s, server floor, cancellazione/ACK ignoto con reopen ed envelope identico, claim stale, scope/revoca e nessuna starvation. Revisione indipendente prima di pacchetto/installazione. Il trattamento degli effettivi legacy esauriti preesistenti resta un gate separato UNKNOWN.


### Q01: esito incerto distinto da transient

Chiarimento prima del freeze Q01,2026-10-16T03:30Z: fase `uncertain`, categoria Unknown, completamento locale esplicito e deadline>=completion+300000ms/server floor. Un claim in_flight già persistito conserva almeno start+300000ms per il caso processo interrotto. Replay idempotente stesso envelope consentito soltanto nello stesso scope autorizzato, con budget finestra residuo<5, alla deadline e senza un claim concorrente ancora posseduto nel processo. Il nuovo claim consuma il tentativo successivo e respinge completion vecchie con CAS. Unknown/uncertain al quinto non rinnova finestra; soltanto quinto transient tipizzato completato ottiene cooldown rinnovabile. Stable/Unknown ordinario e legacy esaurito rimangono blocked; RetryAfter invalido è fail-closed. Questa semantica è specifica dell'intento outbox idempotente provato e non viene trasferita automaticamente al journal recovery.


## Android D01: data dell'esito e provenance della flight

Decisione 2026-10-16T03:41:36.605770+00:00, dopo sei RED reali tracker/VM (recovery e dirty inventanoT0, replay VM rinnovaT0+1h, owner/shop/storeEpoch successivi mostrano dataA). Nessuna migrazione o persistenza nuova: `CatalogSyncOutcomeState` inRAM aggiunge completedAtMs nullable e token scope della flight esistente. Solo un internal publisher dentro la flight legge/valida il lease dal CoroutineContext originale e stampa il completamento qualificato una volta. Token catturato prima del lavoro e validato prima della pubblicazione; non attribuire scopeB corrente al callbackA. I diagnostici storici senza provenance non inventano date. VM riusa timestamp originale, conserva l'ultimo successo valido nello stesso scope anche dopo un errore successivo e nasconde la data quando cambia authority.

Per priceSyncFailed resta la semantica preesistente di completamento parziale catalogo con errore prezzi: nessun nuovo successo globale inferito. Callsite dentro flight soltanto nel coordinator esistente e percorso manuale VM. Test healthy adattati alla flight reale mantenendo scenari/assert dei RED originali archiviati; aggiungere positivo di data reale e callbackA stale→B. Nessun clock assegnato dal replay o nuova API esterna.


## iOS D01: prova verificata v2 della data

Decisione 2026-10-16T03:48:01.890796+00:00 successiva al REDqualificato A→B getter/reopen (1FAIL,pin14/14 invariati). Nuova chiave locale `<prefix>.lastVerifiedProof.v2`, record JSON stretto schemaVersion2, verifiedAt finito/positivo, finalization:SyncStoreRecoveryFinalization originale. Nessuna migrazione inferita dal vecchio proofVersion1, bytes storici preservati e nessun fallback v2corrotto→v1.

Origine: manifest esatta restituita da markRecoveryFinalized dopo fsync/readback+journalclear; conserva accountHash/shop/store/device/generation/checkpoint/watermark/baselineRunID. Atomic conserva quella origine e la propaga summary→engine→result. Non ricatturare scope corrente come provenienza al callback. Store accetta solo origine coerente con authority attuale e proietta data solo contro prova/generazione/capacità locale attualmente qualificate. Il timestamp viene conservato al normale avanzamento incrementale e al replay della stessa prova già accettata, non aggiornato da lettura/nuova schermata. Nessuna regola basata solo su phase idle o solo su manifestB corrente.

Legacy senza provenance, mismatch owner/shop/device/generazione e metadata corrotta non qualificano una data visibile. Risultati synthetic bool-only non sono prove reali; eventuali pureunitfixture vanno distinte dall'integrazione. File ammessi: recovery summary, Atomic service, engine, result, state store; test pertinenti. Errore precedente A→B rimane gate distinto finché non provato.


## iOS D01: osservazione di errore con origine del lavoro

Decisione execution 2026-10-16T04:32Z dopo RED `ios-d01-error-red` qualificato1FAIL/4assert (HTTP503A/timeA ancora presenti dopo binding+selectionB e reopen, nessuna nuovaRPC, pin16/16invariati). Nuova chiave locale `<prefix>.lastRunObservation.v1`, schemaVersion1, invocationID UUID catturato prima del lavoro, origin {accountHash,shopID,storeIdentity con6campi esatti,deviceIdentityHash,generationKind absent|identified,generationID obbligatorio soltanto identified}, status,errorCode?,blockReason?,failure tipizzata?,completedAt finito/positivo. Codice/status/time/origine costituiscono un solo envelope. Rawlegacy resta storico senza fallback. Nessun dato/token/payload nuovo in log, schemaDB/APIpubblica/deps invariati.

Origine engine/facade/orchestrator catturata prima della rispettiva operazione e mantenuta attraverso await; TaskLocalA originale non sostituita con captureB. Generation letta da accessor readonly del record WatermarkStore già validato/checksum: absent genuino distinto da identified e invalid; invalid non diventa assenza. Primo errore con scope reale prima manifest non richiede finalizzazione né proof di successo. Getter non crea deviceID né apre controller. Engine completa timestamp originale prima del ritorno, non alla callback/state-replay.

StateStore accetta solo autorità attuale account/shop/binding o pendingtarget già ammesso/device/full6identity/generation corrispondente all'origine. Mismatch non muta envelope o stato corrente. Replay stessa invocation conserva primo envelope/time; osservazione di altro invocation nello stesso origin deve avere completamento strettamente successivo a quello già accettato, altrimenti fail-closed (pareggi non autorizzano callback vecchio). Un nuovo risultato scoped success/noWork supersede l'errore pertinente, senza risurrezione raw. Snapshot/hydrate condividono validatore; anche cloudEventsIncomplete usa solo block scoped. Gli errori non diventano prove di convergenza.

File ammessi: SyncAutomaticRunResult, AutomaticSyncEngine, AutomaticSyncRuntimeFacade, SyncOrchestrator, SyncStateStore, OptionsView soloDiagnosticsSnapshot, WatermarkStore; test pertinenti senza perditaassert. Parser envelope keyed esatto6campi, niente normalizzazione inferita. Difetto parser proofv2 con valori presenti vuoti richiede ancoraRED distinto prima della sua correzione. Negativi errori: premanifest, stale/newgeneration, owner/shop/device/epoch, replay, progress/time, legacy/corrupt preservati. Finale richiede nuova regressione/review; nessuna accettazione UI/live o installata da questa decisione.


D01 proofv2 chiarimento2026-10-16T04:31:14Z: RED normalization qualificato5varianti/10assert,16pin invariati. Prima di accettare recordv2 confrontare ciascuno dei6valori keyedraw con i6valori del modello decodificato; rifiutare normalizzazione/default inferiti anche con chiavi presenti. Decoder LocalStoreIdentity legacy globale invariato. Nessuna migrazione dei bytes corrotti o fallback storico.


## Android eventV6: budget delle richieste fisiche

Decisione 2026-10-16T04:35:06.581516+00:00 dopo REDwire effettivo regression02:1invocazioneapp→2POST dopo HTTP503/RetryAfter0 su serverloopbackposseduto, con erroreoriginale503/PGRST000 e body/ID byteuguali dimostrati. Autorizzato bodyone-shot soltanto per funzione esatta record_sync_event_v6 nel vero invokerSDK; nessun nuovo loop, nessun aumento timeout90s, nessun flagdiagnostico e nessun cambio URL/auth/header/serializer/errorresponse/legacyfallback. Retry è responsabilità del drain/app giàclaimato, non replay HTTPtrasparente. Helpercheckpoint distinto resta invariato. Verificare GREENwire originale503/1POST e negativi altreRPC/contrattogenerale nella regressione; budget/policy/outbox non modificati da questo fix.


## iOS projection/hydration e cancellazione richiesta

Decisione 2026-10-16T05:06:07.609856+00:00 successiva a5FAILcanonical02 e2FAILqualifierprojection con19pin invariati. Hydration prende status/outcome/error/block/completion SOLO da envelope valido/current; missing/foreign/corruptnonattribuisconoerrori ooutcome alnegoziocorrente e nonfabbricano recoveryRequired che imponeadmissionmanuale. Il journalvero mantieneilpropriolatch; rawesplicito recoveryRequired senza typedkey può restareintento conservativo legacy, senzaalcunaattribuzionerawerror/outcome/time/proof né authority/rinnovo retry inventati.

La richiestaUIcancel è locale/provvisoria: nonpersisteun nuovo terminalautorevole conUUID/timestamp più recente che cancelli commitdurabile giàconcluso dellastessaflightheld. Solo terminalEngine/Facadeorigina osservazionevera; STRICT> tra invocazionireali e clockoriginari restano. Fixture secondarun nuova deveeseguireengine reale fresco invece di ripubblicare result vecchio.

Cleanup di receipt respinta può ritirare soltanto candidatoRAMancoraposseduto, mai error/time/proof/budget/completionraw. Identità/genoriginaria diventata noncurrent NONdimostraperditaownership: la stessa B puòavercommittato genB legittimamente prima dellacallback. Usareclaimlocaleinvocazione prework e revision/CAS; A nonritira B in-flight anche primadel suoenvelope e dopoil suo commit. Propostainsicuraresta artifactnonapplicato, nuovonegativoBbootstrapheld richiesto primaapprovazione.


## iOS D01: prima data verificata dalla sorgente

Decisione 2026-10-16T05:16:16.716769+00:00 dopo RED qualificato `ios-d01-final-qualifiers-red`: prima finalization Engine/Atomic nuova, mai pubblicata prima, observation.completedAt=T0 originale e currentorigin/finalization/bodyproof validi. La prima callback ritardataT1=T0+3600 produce tre divergenze data live/JSON/reopen. Consentita correzione minima al primo proofv2: usare il completedAt finito/positivo dell'osservazione originale che corrisponde al risultato e alla sua origine corrente, senza re-stamp della callback e senza inferenza dai raw storici. Prova già accettata conserva la prima data. Nessuna modifica al clock engine, alle soglie timeout, al formato proof o all'authority della finalization. Fixture bool-only non può inventare una data reale.
