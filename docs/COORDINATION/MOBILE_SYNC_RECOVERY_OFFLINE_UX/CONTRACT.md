# Contratto condiviso proposto — stati, retry, recovery, UX

Coordination key `MOBILE_SYNC_RECOVERY_OFFLINE_UX`, versione planning1, 2026-10-15. Fonte canonica per iOS TASK-145 e Android TASK-144. È una proposta operativa per la futura execution: non descrive patch già distribuite. Vedi [RCA](ROOT_CAUSE_ANALYSIS.md) per differenze dall'implementazione attuale.

## Capacità indipendenti

Il modello nativo deve rappresentare separatamente, senza obbligo di classi identiche:

1. **LocalData**: absent / qualifying / valid / corrupt, con store/generation/body revision.
2. **LocalAuthorization**: unknown / confirmed same-scope / revoked / explicitLogout / scopeMismatch, da prova già ammessa e persistita, non dal solo indirizzo account o binding.
3. **CloudSession**: available / refreshing / temporarilyUnavailable / rejected.
4. **CloudWork**: idle / running / retryScheduled / recoveryStaging / blockedRecord / blockedScope / completed; include causa, operazione, categoria, scheduledAt/nextEligibleAt e scope.
5. **PendingWork**: business revision da inviare, eventi da consegnare, lavoro bloccato e ricevute locali di integrità distinti.

Lettura locale = dataset valido + autorizzazione locale ammessa + scope/generation correnti. Scrittura locale richiede inoltre il gate di mutazione/lease esistente e persistenza atomica. Cloud session/online/completed non sono sostituti di questi predicati. Un refresh SDK nil temporaneo deve distinguersi da logout/revoca prima di preservare capacità: T06/T07 rossi sono il gate della modifica, nessuna guardia sempre vera.

La shell e Opzioni restano raggiungibili anche senza dataset; schermate business mostrano empty/locked state coerente. Nessun dato di un account precedente deve essere mostrato sotto il nuovo account. Logout esplicito e revoca confermata ritirano l'accesso secondo policy vigente; il solo timeout cloud non fabbrica una revoca. I writer usano capacità catturata e validata nuovamente prima del commit, non un booleano UI.

## Recovery A–G

| Caso | Letture e mutazioni locali | Remoto sospeso / ripresa | Scelta utente |
|---|---|---|---|
| A same-scope, dataset valido | Lettura/ricerca/editor/Save normali; intent durevole anche durante staging. Shell invariata. | Solo percorsi incompatibili col journal sono sospesi. Recovery incrementale/paginata automatica bounded, poi qualificazione, cutover breve, replay. Push indipendente richiede prova secondo sezione dipendenze. | Solo conflitto reale o rifiuto stabile con azione necessaria. |
| B primo bootstrap, nessun dato | Shell/Opzioni disponibili, progress/empty state; nessuna falsa lista e nessuna scrittura priva di scope. | Bootstrap ammesso dopo scope/sessione/device verificati; retry transitori. | Login/selezione shop quando indispensabili, non tap periodici di sync. |
| C cambio account/shop/store | Solo dati del nuovo scope qualificato; nessuna lettura/mutazione foreign. Draft precedente conservato e isolato. | Cancellare vecchia authority e ignorare callback; nuova risoluzione/qualifica, replacement solo autorizzato. | Decisione di sostituzione se richiesta dalla policy. |
| D revoca confermata | Accesso business ritirato secondo policy; dati conservati senza esposizione. | Stop remoto, nessun retry aggressivo che aggiri revoca. | Ri-autorizzazione valida / accesso amministrativo legittimo. |
| E corruzione reale | Solo dati/operazioni provati sicuri; niente Save su store non affidabile. Shell diagnostica accessibile. | Stop attivazione e writer sullo store corrotto; percorso riparazione/esportazione ammesso dalla policy. | Conferma per operazioni distruttive, mai wipe automatico. |
| F replacement interrotto | Se journal è same-scope e vecchia generazione qualificata, valgono le capacità A. Se scope/manifest/body non dimostrabili, solo shell diagnostica. | Rileggere journal, staging, manifest e fence. Riprendere accepted prefix; validare prima di pubblicare. Nessuna cancellazione indiscriminata. | Solo replacement distruttivo o incompatibilità non risolvibile. Cancel/dismiss lascia accessibile la shell, non falsifica READY. |
| G diagnostica vecchia | Capacità dai predicati attuali, non dall'ultimo errore memorizzato. | Successo pertinente ritira l'episodio errore; storico resta nei dettagli. | Nessuna se il problema operativo è cessato. |

Nessuna rete sotto lock che impedisce Save. Fetch e staging fuori transizione atomica; attivazione breve misurata, attende/quiesce writer e ricontrolla scope/generazione/revisioni. Il lavoro creato durante recovery è trasferito/rebased secondo i meccanismi esistenti; se non è trasferibile, l'attivazione si arresta preservando vecchio store e pending. Fine qualificazione deve risvegliare il coordinator nella stessa generazione, anche senza nuova navigazione.

## Errori e azioni

Ogni esito conserva fase/operazione, categoria strutturata, codice transport/HTTP/Postgres quando disponibile, scope/generation e attempt ID sanitizzato. Non serializzare payload/token nei log. Unknown rimane unknown; non chiamarlo conflitto né avviare full recovery indiscriminata.

| Categoria | Azione automatica e attesa | Riattivazione | Effetto locale / UI |
|---|---|---|---|
| Offline / DNS / timeout prima commit | Conservare envelope; rete utile solo come segnale. Backoff transient. | Timer ammesso, reconnect, foreground; nuovo tentativo verifica server. | Save durevole disponibile; informazione offline sobria. |
| Timeout dopo commit / ACK ignoto | Replay **stessa** identity/body; readback contrattuale prima di altro payload. | Due time e authority valida. | Pending conservato, nessun prezzo/evento duplicato. |
| 429 | Rispettare Retry-After valido; backoff con jitter se assente. | Scadenza server; reconnect non anticipa limite. | Stato discreto retryScheduled, niente tap obbligatorio. |
| 408 / 500 / 502 / 503 / 504 transient confermato | Finestra bounded; rispettare Retry-After se presente. 500 privo di causa non diventa recovery nuova. | Timer cooldown e segnali pertinenti con admission. | Locale disponibile se qualificato; dettagli tecnici in Opzioni. |
| PostgreSQL57014 statement timeout | Distinguere user cancellation da statement timeout e preservare op. Budget transient bounded; ripetizione deterministica rimanda a diagnosi backend. | Cooldown + backend/schema/versione ammessi; non loop rapido. | Journal e pending intatti; nessun aumento timeout come PASS. |
| Refresh sessione | Un refresh serializzato; se transient conserva capacità locale già autorizzata. | Auth event/rete/timer; success richiede scope corrente. | Nessun logout sintetico da timeout; explicit logout/revoca restano bloccanti. |
| 401 / 403 / revoca | 401: un refresh ammesso, poi auth-required se ancora negato. 403/revoca confermata stop scope. | Credenziale/membership realmente ripristinata. | Non esporre dati foreign; azione login/permesso chiara. |
| Conflitto versione / vincolo | Classificare per record; readback base/current/changedFields; merge solo dimostrabile. | Nuova revisione o decisione esplicita; nessun retry identico aggressivo. | Versioni conservate, altre operazioni indipendenti proseguono. |
| Cursor invalido / snapshot_changed | Usare codici del contratto; riconciliare o riprendere recovery solo se richiesta. | Nuovo checkpoint/fence ammesso, stesso scope. | Nessun reset cursore cieco o full su ogni tab. |
| Payload/schema/decoding | Bloccare/quarantinare record o protocollo interessato, con causa stabile. | Payload corretto/schema compatibile; non stesso payload in loop. | Non cancellare lavoro; limite al dato/domino se sicuro. |
| Stato persistito obsoleto | Riconciliare con journal/manifest/qualifica attuali. | Successo/proof pertinente; metadata retry corrupt non autorizza loop. | Distingue diagnostica da guasto operativo. |
| Busy/lock/lease | Coalescere una richiesta successiva, attesa bounded e cancellation cooperativa. | Fine owner corrente/scadenza lease/re-admission. | Mai RUNNING permanente, mai due writer. |
| Solo presentazione | Nessuna RPC per correggere la UI. | Nuovo stato operativo pertinente. | Contatori/date corretti; proof localOnly conservate. |

## Policy temporale proposta e testabile

Riutilizzare scheduler/clock/transport esistenti. Parametri proposti per la prima implementazione, da fissare nei test prima della patch: per il fallimento numero n (n=1 dopo il primo tentativo della finestra), delay locale = min(60s, 2s × 2^(n−1) × U), con U uniforme fra0,5 e1,5 e seed controllato nei test. Quindi il primo retry attende1–3s (base2s), non un minimo garantito2s. `Retry-After` valido è un minimo invalicabile (nessun cap locale che lo anticipi). iOS mantiene3 tentativi totali e Android5 per finestra, incluso il tentativo iniziale (massimo2/4 retry nella stessa finestra); al consumo, programmare una sola opportunità futura non prima di5min dalla fine dell’ultimo tentativo della finestra, mantenendo l'intenzione durevole. La nuova finestra è ammessa soltanto per errori retryable, authority corrente e scadenza raggiunta. Per errori stabili non si rinnova il budget per il solo passare del tempo.

Foreground/reconnect/session success possono anticipare il cooldown locale solo se cambia la condizione causale e nel rispetto di Retry-After/rate limit; non ripartire a ogni tab/recomposition. Persistenza già disponibile (`nextAllowedAt`/`nextRetryAtMs`, attempt metadata) da riusare; nuove colonne non autorizzate preventivamente. Se il formato esistente non basta, documentare una modifica minima versionata prima di implementarla. I contatori non sono azzerati per nascondere exhaustion. Un nuovo scope invalida i timer del precedente.

Ogni tentativo ha deadline finita e cancellation. Baseline verificata: iOS `Sync/Remote/SupabaseTransportClient.swift:71–72` configura boundedRPC request45s/resource60s; `ShopSyncRecoveryContract.swift:763` usa quel transport. Android `MerchandiseControlApplication.kt:256` configura client90s, e `SupabaseShopSyncReadRemoteDataSource.kt:127–136` usa il timeout PostgREST. Questi sono limiti del transport, non una deadline dell'intera recovery multipagina. Conservare questi limiti per i percorsi correnti e registrare ogni deadline più stretta già esistente; non confonderli col target foreground3s né col timeout statement backend storico8s. Per i percorsi diversi, prima rilevare e fissare la deadline effettiva nei test, senza introdurre attese illimitate. Non aumentare deadline recovery/server per superare il test. Deadline, ritardi e finestre vanno riportati nel ledger. Callback vecchie non cambiano stato/UI né confermano nuovi pending. Evento arrivato durante run conserva un successore coalesced; finally rilascia busy/lease anche su errore/cancel.

iOS BGAppRefresh e Android lifecycle non assicurano esecuzione continua. Android attuale non ha un general sync WorkManager: PriceBackfillWorker è distinto. Nessuna nuova infrastruttura background richiesta; pending resta durevole fino alla prossima finestra OS/app ammessa.

## Outbox, conflitti e dipendenze

Business+intent/revisione devono essere persistiti atomicamente prima del successo locale. Stessa operazione in retry conserva ID, base, changedFields, body, prezzi/history derivati; ACK conferma soltanto revisione inviata. Se A è in volo e nasce B, ACK A non pulisce B. Recovery trasferisce anche gli intent creati nel frattempo. Questi invarianti sono già implementati in più percorsi: estendere test, non riscrivere i modelli.

Distinguere **business intent**, **event outbox**, **immutable business attempt**, **local body proof**. `localOnly` è terminale locale, non da inviare e non da contare come pending cloud. Un errore non retryable può richiedere attenzione senza essere una modifica da reinviare. Il successo pubblico non deriva soltanto da pending=0.

Dipendenze minime: supplier/category prima del prodotto che li referenzia; prodotto prima dei suoi prezzi; ACK/evento legati all'operazione; history e immagini secondo relazioni effettive. Un evento corrotto può isolarsi se l'operazione business non dipende da esso per prova/autorizzazione. Errori di scope, seal, store corruption o fence interrompono il perimetro protetto. Nessun catch generale che prosegue dopo un errore di integrità.

Merge campi disgiunti richiede stessa base verificabile, maschera affidabile e contratto writer corrente. Update parziale non sostituisce riga completa. Stesso campo incompatibile o delete-vs-edit irrisolvibile: conservare versioni/intent e chiedere scelta per il record; non bloccare tutta l'app. Maschera legacy/ignota segue il percorso conservativo esistente. Nessun LWW globale o arbitraggio con clock device. Prezzi append-only/dedup, tombstone anti-resurrezione e History remote_id invariati.

## Modifica esplicita delle policy precedenti

`iOS/docs/SYNC_POLICY.md` vieta push automatico con baseline/recovery/retry irrisolti. La proposta mantiene il divieto per **scope/authority/integrità non qualificati** e per operazioni dipendenti; ammette progresso indipendente soltanto quando RED e prove T11 dimostrano separazione di dipendenze e scope. Nel batch4 l'executor deve aggiornare esplicitamente quella policy al contratto verificato, con review, prima di attivare un'eccezione. Nessuna guardia globale è rimossa in questo planning.

Il workspace Supabase `docs/decisions.md`, DEC-029:253, descrive retry transitorio principalmente manuale (storico aprile). Per il perimetro mobile corrente questa proposta lo supera con retry automatico bounded, lasciando intatte le regole dati conservative della decisione. Il rimando Supabase rende esplicita la differenza; non si riscrive la cronologia né si cambia silenziosamente la policy di conflitto.

## UX e semantica date

Un'unica proiezione per scope/generazione alimenta banner e card, con dettagli per dominio. Normale sync breve silenziosa; indicatore discreto dopo700ms (Android già presente), no modali per rete. Offline e retry transient non producono toast/banner ripetuti a ogni tab. Un problema azionabile mostra una sola superficie principale, azione pertinente e dettagli in Opzioni; dismiss riduce rumore ma non cancella stato operativo.

`lastAttemptAt` = inizio tentativo; `lastCompletedAttemptAt` = fine anche fallita; `lastProgressAt` = avanzamento reale, non tick; `lastVerifiedSuccessAt` = successo pertinente con prova di convergenza per scope/domino/generazione; `lastCheckedAt` = controllo remoto anche no-op; `lastDataChangedAt` = cambiamento dati. Un ViewModel ricreato non può attribuire now a un risultato vecchio. Scope nuovo non eredita un successo del precedente. Successo di un dominio non cancella errore di un altro. Nessun “Sincronizzato” senza evidenza.

Card database locale: integrità/disponibilità locale; card cloud: raggiungibilità, retry, freshness e pending effettivo. Controlli/diagnostica sono eccezionali, non il trigger obbligatorio della sync ordinaria.

UI native: preservare navigation stack, scroll, focus, tastiera e draft; non rimontare editor per ogni ACK. Layout con larghezza minima/stack adattivo per Controlla/Diagnostica, niente compressione a lettere; Dynamic Type/accessibility font, VoiceOver/TalkBack, IT/EN/ES/ZH. Misurare hit testing, ultima riga e insets sulla baseline reale; effetti visuali di sistema non sono bug per definizione. Niente offset negativi o costanti device per mascherare spazio.
