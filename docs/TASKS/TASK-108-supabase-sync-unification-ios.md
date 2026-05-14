# TASK-108: Supabase sync unification iOS — auth state, full/incremental pull, local apply, push eventi e Generated/History parity Android

## Informazioni generali
- **Task ID**: TASK-108
- **Titolo**: Supabase sync unification iOS: auth state, full/incremental pull, local apply, push eventi e Generated/History parity Android
- **File task**: `docs/TASKS/TASK-108-supabase-sync-unification-ios.md`
- **Stato**: ACTIVE
- **Fase attuale**: REVIEW
- **Responsabile attuale**: CLAUDE
- **Data creazione**: 2026-05-13
- **Ultimo aggiornamento**: 2026-05-14 00:38 -0400
- **Ultimo agente che ha operato**: CODEX

## Dipendenze
- **Dipende da**: Fondazioni già consegnate con **TASK-091…TASK-107** (sync semi-auto Release, pending locali, preview/pull/apply/push catalogo e ProductPrice, outbox `sync_events`, hardening TASK-099). Nessuna dipendenza bloccante su task non DONE.
- **Sblocca**: eventuali task post TASK-108 solo per **polish**, **performance avanzata**, **Realtime/background worker** o **schema/migration separati** se emergono blocker non risolvibili senza decisione esplicita. **Per decisione utente, TASK-108 deve contenere nel planning l’intero perimetro funzionale richiesto**: Options cleanup, **auto pull incrementale** on app launch/foreground, **bootstrap/full pull**, **push incrementale** da Database, **sync Generated** come Android e **sync completa History/session** dove lo schema esistente lo consente.

## Scopo
Allineare modello mentale e pipeline di sincronizzazione iOS (**SwiftUI + SwiftData + Supabase**) al comportamento di riferimento Android (**Room locale = source of truth**, pull incremental remoto → locale, push modifiche tramite guardrail/outbox/sync_events), risolvendo in priorità **P0** la contraddizione Osservabile in Opzioni tra **surface Release** vs **surface DEBUG**, e chiarendo il legame fra **OAuth Supabase firmato**, **baseline/pull catalogo**, **SwiftData popolato** e **pending push**.

Questo task in questa fase produce **solo planning** tecnico ripartito in micro-slice; **nessuna execution Swift**.

La task deve essere letta anche come **system-design UX task**: non basta “far funzionare Supabase”, bisogna rendere chiaro all’operatore cosa succede tra login, database locale, pull, push, errori cloud e modifiche generate dai fogli. La schermata Opzioni deve diventare il punto di controllo semplice e affidabile, mentre la diagnostica DEBUG deve restare secondaria e non contraddire mai la superficie pubblica.

## Decisione scope utente — perimetro completo dentro TASK-108

Su richiesta esplicita dell’utente, TASK-108 deve pianificare **tutta** la gestione sync iOS necessaria alla **parità funzionale Android**, anche se l’execution dovrà avvenire a **slice piccole e reviewabili**. Questo significa che TASK-108 non è più solo “Options fix + bootstrap”; deve includere nel proprio perimetro:

- pulizia/semplificazione della schermata **Options** e rimozione delle contraddizioni Release/DEBUG;
- **pull incrementale automatico** all’apertura app / ritorno foreground quando sicuro;
- **full/bootstrap pull** da Supabase verso SwiftData quando il database locale è vuoto o baseline assente;
- **push incrementale** dopo modifiche in **Database** screen, inclusi prodotti, fornitori, categorie e storico prezzi;
- sync del flusso **Generated** screen come Android: apply locale, storico prezzi, stato foglio, pending cloud e push;
- sync completa **History** screen / **shared sheet sessions** come Android, se supportata dallo schema esistente;
- **Wave 7 — end-to-end acceptance**: verifica trasversale Options + bootstrap + auto pull + push + Generated + History con verdict **implemented / not implemented yet / blocked** per ogni wave **e collegamento alla evidence nominata**, senza dichiarazioni PASS anticipate in PLANNING.
- regole di pending/outbox, ack, retry, owner/account, tombstone/delete e conflitti.

La task resta comunque in **PLANNING** finché non viene approvata execution. L’implementazione futura deve essere divisa in wave/slice piccole; **ogni slice** deve dire **cosa è stato implementato**, **cosa resta non implementato** e **perché**.

## Contesto
Problemi osservati (Simulator / uso reale):
1. Opzioni → sezione pubblica (**Cloud synchronization** su `SupabaseManualSyncReleaseCard`): testi tipo “serve accesso / Sign in”; bottone può apparire **inerte**.
2. Opzioni → sezione **DEBUG** `#if DEBUG`: mostra stato **Signed in**, significa **`SupabaseAuthViewModel`** coerente con sessione OAuth.
3. Anche dopo sign-in apparente il **SwiftData locale** può restare **quasi vuoto**: login OAuth **≠** scaricamento/applicazione catalogo nella sandbox locale.
4. **Generated**: due azioni distinte (**aggiorna anagrafiche da foglio** vs **applica inventario al DB**) senza narrazione unificata confrontabile al modello Android unificato.

## Non incluso (questa fase / vincoli espliciti)
- Modifiche a **Swift/Kotlin**, build, test runtime, Simulator smoke obbligatori (non eseguiti in questo planning-init).
- Modifiche a **schema Supabase / RLS / RPC / migration** (solo follow-up motivato fuori scope esecuzione immediata).
- Introduzione di **dipendenze** nuove senza Decisione nel task.
- **Background sync / Realtime / worker sempre attivi** fuori foreground: TASK-108 include **auto pull/push incrementale controllato** su app launch/foreground e azioni utente, ma **non** introduce worker background/Realtime continuo senza task separato.
- Dichiarazioni **production-ready** o chiusura **DONE** (solo planning + tracking).
- “Pulizia” dei dati remoti o locali per risolvere conflitti: eventuali cleanup devono restare task separati, scoped, confermati e con evidence.
- Modifica del modello auth/multiutente: TASK-108 deve usare il modello account già esistente, non introdurre nuovi concetti di tenant/utente.

---

## Scope optimization (anti mega-task)

**TASK-108 ha ora perimetro funzionale completo**, ma non deve diventare una execution monolitica. La regola è: **tutto resta nel task 108 come planning e backlog interno**, ma l’implementazione avviene a **wave piccole**, con **gate** e **verdict** per ogni wave. La **chiusura minima corretta** non può più dichiarare **parità Android completa** se auto pull, push incrementale, Generated sync o History sync restano fuori; eventuali parti non implementate devono restare elencate come **slice TASK-108 non ancora completate**, non dimenticate.

1. **Stato/copy/CTA cloud coerenti** sulla superficie pubblica Opzioni (nessuna contraddizione login/sync; nessuna CTA primaria inerte).
2. **Stato signed-in + baseline assente** gestito chiaramente (copy dedicata + azione recuperabile tipo «Scarica database»).
3. **Bootstrap / full pull sicuro** tracciabile e implementabile in wave dedicate (preview, conferme, guardrail anti-wipe).
4. **Generated sync parity Android**: apply locale + ProductPrice + stato foglio/HistoryEntry + pending cloud + idempotenza, tramite **`S108-E`** e **`S108-D2`** (Wave 5); rollout **E1→E2** è ammesso come step interno, non come riduzione permanente del perimetro.
5. **History / session parity cloud** inclusa come perimetro TASK-108 **obbligatorio** di planning ed execution futura (`S108-C3`, `S108-D3`). Se lo schema esistente non basta, TASK-108 deve fermarsi in **BLOCKED_SCHEMA_OR_POLICY** per quella parte e documentare esattamente il blocker/schema richiesto, **non** rimuovere la feature dal perimetro.
6. **Auto pull incrementale on launch/foreground** incluso in TASK-108 (`S108-K`) con policy safe, lifecycle gate, debounce e **nessun wipe automatico**.
7. **Push incrementale** da Database/Generated/History incluso in TASK-108 (`S108-D1`, `S108-D2`, `S108-D3`, `S108-F`, `S108-G`) con pending/outbox/ack fail-safe.

**Ripiego obbligatorio:** se History/session sync, auto incremental sync o push incrementale richiedono schema/RLS/RPC non presenti, TASK-108 deve segnare quella wave come **BLOCKED_SCHEMA_OR_POLICY** e produrre una proposta di migration/task backend collegata. **Non cancellare la wave dal perimetro** e **non dichiarare parità completa** finché resta bloccata (salvo verdict **PARTIAL/BLOCKED** documentato).

### Livelli di chiusura ammessi per TASK-108
Per evitare ambiguità in review, TASK-108 può chiudere solo con uno di questi esiti documentati:

| Esito | Significato | Condizioni minime |
|-------|-------------|-------------------|
| **PASS** | Tutte le wave del perimetro completo TASK-108 passano | Options Wave 1 PASS; bootstrap/full pull PASS; auto pull incrementale PASS; push incrementale PASS; Generated sync PASS; History/session sync PASS; evidence completa |
| **PASS_WITH_NOTES** | Core sync completa ma restano note non bloccanti / hardening avanzato | Tutte le wave **funzionali** passano; possono restare note su performance, live smoke limitato, copy polish o Realtime/background worker fuori scope |
| **PARTIAL** | Alcune wave funzionali non sono completate | Consentito solo come verdict **intermedio/review**, non come parità Android; elencare chiaramente **slice non implementate** ancora dentro TASK-108 |
| **BLOCKED** | Una o più wave non possono procedere senza schema/RLS/RPC/decisione utente | Stop condition attiva; feature resta nel **perimetro TASK-108** come blocker documentato |


Chiusura **DONE** resta vietata senza review e conferma utente; questi esiti descrivono solo il verdict tecnico proposto dall’execution/review.

### Definition of Ready per passare a EXECUTION
TASK-108 può passare da PLANNING a EXECUTION solo quando sono vere tutte queste condizioni:
- [ ] **Wave 1** è approvata come primo perimetro obbligatorio, senza bootstrap mutativo nello stesso primo commit se il reducer/auth non è ancora chiuso.
- [ ] La checklist Supabase pre-mutazione è riconosciuta come gate per Wave 2+, non come attività opzionale.
- [ ] È accettato che dopo **Wave 1** l’execution **continui dentro TASK-108** con wave dedicate per **auto pull**, **push incrementale**, **Generated sync** e **History sync**, invece di aprire task separati solo perché quel lavoro è voluminoso.
- [ ] È accettato che **ogni wave** TASK-108 abbia un proprio mini-handoff con stato esplicito: **implemented**, **not implemented yet**, **blocked**, **deferred inside TASK-108**.
- [ ] È accettata la policy local-first: cloud offline o signed-out non blocca Database/Generated/History locali.
- [ ] È chiaro che nessun cleanup dati e nessuna migration Supabase fanno parte di TASK-108 senza task separato.
- [ ] È accettato che **Wave 1** possa essere una **patch piccola e autonoma** anche se **Wave 2/3** restano solo **pianificate** o **gated** (nessun obbligo di completare bootstrap/push prima del primo merge).
- [ ] È definito il **primo commit/PR di EXECUTION come Wave 1 minima**: reducer/presenter + Options UX Release/DEBUG + test, **senza** pull mutativo, **senza** push e **senza** modifiche schema Supabase nel perimetro di quel primo PR.

### Definition of Done del PLANNING

Prima di chiedere execution a Codex, questo planning deve risultare **autosufficiente** per un esecutore che **non ha seguito la discussione**:

- problema **P0** descritto in una frase: OAuth valido ma la UI Release comunica **sign-in/sync** in modo **incoerente** rispetto alla sessione reale / permission / baseline;
- **primo perimetro execution limitato a Wave 1** (patch minima: stato + presenter + Opzioni + test; niente pipeline mutativa cloud nello stesso PR);
- **decisione UX Options già presa**, non lasciata aperta (card pubblica vs DEBUG collassato, CTA/significato stato);
- decisione **Generated target UX-2** già presa, con **E1 come fallback minimo** per step intermedi e **E3/hook session** subordinati al gate **S108-C3** / schema;
- **History/session resta nel perimetro TASK-108**: eventuale **TASK-109** diventa solo **backend/schema/polish** se davvero necessario, **non** contenitore della parità funzionale richiesta;
- **stop condition** e **anti-scope** espliciti (no migration, no cleanup implicito, no mega-refactor Wave 1);
- **prompt / handoff verso EXECUTION** pronto e non ambiguo: usare **`Handoff → Execution (solo dopo approval esplicito)`**, **Brief minimo Wave 1** (sotto quel handoff), **Estensione N — Wave 1 minimal execution brief** e la **strategia patch** sotto evidences.

### Priorità operative P0 / P1 / P2

Per evitare che i criteri diventino tutti «bloccanti», TASK-108 usa questa priorità:

| Priorità | Significato | Esempi TASK-108 | Può restare fuori dalla prima execution? |
|----------|-------------|-----------------|------------------------------------------|
| **P0** | Deve essere risolto prima di qualunque sync mutativa | contraddizione Release/DEBUG, CTA inerte, auth vs permission, sign-out stale snapshot | **No** |
| **P1** | Necessario per parità funzionale TASK-108 | bootstrap/full pull, auto pull incrementale, push incrementale, Generated sync, pending/outbox fail-safe | **No per chiusura PASS; sì solo come wave successiva interna** |
| **P2** | Hardening/polish o automazione avanzata da non mischiare al fix P0 | Realtime/background worker, performance tuning avanzato, live smoke esteso, copy polish extra | **Sì, se non dichiarato come parità Android** |

In review, non usare criteri **P2** per bloccare la correzione **P0** di Wave 1, ma non dichiarare «**sync parity Android**» finché le funzioni **P1** dentro TASK-108 non sono **implementate** o esplicitamente **BLOCKED** con motivo tecnico.

---

## Obiettivo (deliverable del task dopo execution futura — da rispettare in planning)
Riallineamento **stato**, **azioni** e **copy** perché un operatore comprenda sempre:
1. è autenticato al cloud o meno (`Supabase Auth`);
2. esiste baseline / pull precedentemente applicati (`SupabaseCatalogBaseline*` + conteggi);
3. è necessaria una **pull** (full o incrementale) per popolare/aggiornare SwiftData;
4. ci sono **pending push** aggregati/outbox;
5. errori sono **permission/RLS** vs **sessione OAuth** vs **rete/offline**.
6. **auto pull incrementale safe** viene avviato all’app **launch**/**foreground** quando le condizioni sono valide;
7. **push incrementale** viene creato e drenato dopo modifiche locali da **Database** / **Generated** / **History**;
8. **Generated** screen aggiorna database locale, storico prezzi, stato foglio e pending cloud in un **flusso coerente** con Android;
9. **History** screen / sessioni foglio sono sincronizzate con Supabase come riferimento Android, oppure la wave è **BLOCKED_SCHEMA_OR_POLICY** con schema/policy mancante **documentata**.
10. **Wave 7** sintetizza **implemented / not implemented yet / blocked** per ogni wave **con evidence nominata**, senza contraddizioni rispetto al lavoro reale.

---

## Principi progettuali TASK-108
1. **OAuth non significa sync completata**: il login abilita il cloud, ma non deve implicare che SwiftData sia popolato.
2. **SwiftData resta la Room di iOS**: tutte le schermate operative leggono/scrivono prima il database locale; Supabase sincronizza e riconcilia.
3. **Una sola verità visibile**: Release card e DEBUG devono derivare dallo stesso `CloudSyncOverviewState` o da una snapshot esplicitamente sincronizzata.
4. **Azione primaria sempre concreta**: nessun bottone primario visibile ma disabilitato senza spiegazione. Se non può partire, deve esserci un motivo leggibile e una CTA alternativa.
5. **Safe by default**: pull/apply e push non devono cancellare o sovrascrivere dati locali senza preview, conferma e guardrail sui pending locali.
6. **Progressivo, non rewrite**: prima correggere stato/copy/CTA, poi pull/apply, poi push, poi Generated/History parity.

7. **UX iOS-native**: usare card compatte, `DisclosureGroup`, `confirmationDialog`, sheet guidate e copy breve; evitare una schermata Opzioni lunga e rumorosa come pannello di debug permanente.

## Source of truth e policy merge di alto livello
| Dominio | Fonte primaria in app | Fonte remota | Regola default | Stop / review manuale |
|---------|----------------------|--------------|----------------|------------------------|
| Catalogo prodotti | SwiftData locale | `inventory_products` | pull/apply guidato aggiorna locale; push locale solo da pending tracciati | barcode duplicato, owner mismatch, remoteID collision |
| Fornitori/categorie | SwiftData locale | `inventory_suppliers` / `inventory_categories` | merge per remoteID quando disponibile, fallback nome normalizzato solo se sicuro | nome duplicato ambiguo, replacement/delete non risolto |
| Prezzi correnti/storico | SwiftData `ProductPrice` + campi correnti coerenti | `inventory_product_prices` | append/idempotenza con effectiveAt/source; current/previous calcolati dai record | duplicate ProductPrice non riconciliabile, prezzo remoto più recente ma locale pending |
| Inventario/stock da Generated | SwiftData locale | catalogo remoto dopo push | apply locale prima, cloud pending dopo | foglio incompleto o righe con barcode ambiguo |
| History/session foglio | SwiftData `HistoryEntry` | `shared_sheet_sessions` | sync push/pull/reconcile in **Wave 6** se schema consente; altrimenti **BLOCKED_SCHEMA_OR_POLICY** documentato | payload grande, allegati nella catena sync, conflitto multi-device oltre MVP |


Regola generale: **mai usare il remoto per cancellare o sovrascrivere locale dirty senza preview**. In caso di dubbio, mantenere il dato locale e creare stato `needsReview` / `blocked`, non forzare last-write-wins invisibile.

### Policy tombstone/delete ad alto livello
Le cancellazioni sono il punto più rischioso della sync cross-device. Fino a prova contraria:
- i delete remoti **non** devono cancellare automaticamente record locali dirty o collegati a History/Generated senza preview;
- supplier/category delete già gestiti con replacement/unlink in TASK-107 devono restare coerenti anche nel push cloud;
- product delete remoto va trattato come `needsReview` se esistono ProductPrice, stock locale recente, HistoryEntry collegate o pending locali;
- tombstone remoto, se presente, deve essere interpretato come segnale di revisione/merge e non come wipe silenzioso;
- l’utente deve vedere “elementi da controllare” invece di perdere dati.

## Matrice UX target — Cloud overview
| Stato reale | Copy principale | CTA primaria | CTA secondaria | Note UX |
|-------------|-----------------|--------------|----------------|---------|
| Sync in corso | Sincronizzazione in corso | ProgressView / stato busy (non falsamente “tap”) | Annulla o Nascondi se supportato dal model lifecycle | Nessun pulsante prominente che sembra fare nulla mentre la VM è occupata; CTA cancel coerente con `SupabaseManualSync` cancellabile dove già previsto. |
| Sync completata con note | Cloud aggiornato con avvisi | Vedi dettagli | Ripeti controllo cloud (solo se sicuro / non throttle) | Per warning non bloccanti dopo pull/push riuscito con avvisi; non confondere con errore OAuth. |
| Supabase non configurato | Cloud non configurato | Disabilitata con motivo | Apri diagnostica DEBUG | Solo DEBUG deve mostrare dettagli tecnici. |
| Signed out | Accedi per usare il cloud | Accedi con Google | — | La CTA deve sempre aprire OAuth o mostrare errore esplicito. |
| Signing in/out | Accesso in corso | ProgressView | Annulla se supportato | Niente doppie sezioni contraddittorie. |
| Signed in, baseline assente | Connesso. Database locale non ancora scaricato | Scarica database dal cloud | Anteprima | È lo stato chiave visto dall’utente: login OK ma DB vuoto. |
| Signed in, baseline valida | Cloud pronto | Sincronizza ora | Vedi dettagli | Mostrare ultimo controllo, conteggi locali/remoti e pending. |
| OAuth OK, permission/RLS error | Accesso valido, permessi cloud da controllare | Controlla cloud | Accedi di nuovo solo se sessione scaduta | Non mostrare “Sign in” se OAuth è valido. |
| Offline/network error | Cloud non raggiungibile | Riprova | Lavora offline | DB locale resta usabile. |
| Account cambiato / sessione non verificabile | Account cloud da verificare | Controlla account | Continua offline | Non cancellare SwiftData; nascondere metriche remote user-scoped finché non verificate. |
| Locale dirty signed-out | Modifiche salvate solo su questo dispositivo | Accedi per inviarle | Continua offline | Evita panico: il lavoro locale resta salvato, ma non è condiviso. |
| Pending locali presenti | Modifiche locali da inviare | Invia modifiche | Vedi pending | Evidenziare domini `catalog` / `prices` / `history`. |
| Locale aggiornato, cloud pending | Database locale aggiornato. Cloud in attesa | Invia modifiche al cloud | Continua offline | Stato post-Generated/apply locale: deve rassicurare che il lavoro è salvato localmente ma non ancora condiviso. |
| Locale con elementi da controllare | Alcuni dati richiedono controllo | Apri revisione | Continua offline | Stato per conflitti, tombstone/delete, owner mismatch o righe ambigue: non chiamarlo errore generico. |
| Remote collision/blocker | Serve revisione prima di applicare | Apri revisione | — | No apply automatico. |

### Contratto metriche Cloud overview

Le metriche devono essere **poche**, **stabili** e **comprensibili**. Evitare **dashboard** tecniche permanenti sulla superficie Release.

| Metrica | Release label suggerita | Fonte tecnica | Regola visuale |
|---------|-------------------------|---------------|----------------|
| Stato account | Account | AuthSnapshot | Mostra solo **Non connesso**, **Connesso**, **Da verificare** |
| Database locale | Database locale | Conteggi SwiftData + baseline snapshot | Mostra **Vuoto**, **Da scaricare**, **Aggiornato**, **Da controllare** |
| Modifiche locali | Modifiche da inviare | Pending aggregated snapshot | Mostra solo se **> 0** o se **bloccante** |
| Ultimo controllo | Ultimo controllo | Last sync/check snapshot | **Nascondere** se mai eseguito |
| Elementi da controllare | Da controllare | `reviewRequiredCount` | Mostrare come **stato user-facing**, non relegato al DEBUG |

Se una metrica **non è verificabile** per account/sessione corrente, deve essere **nascosta** o marcata **Da verificare** — mai riusata come **dato certo**.

**Limite UI:** nella card Release mostrare **massimo 3 mini-metriche** contemporaneamente. **Priorità visuale:** `Da controllare` > `Modifiche da inviare` > `Database locale` > `Ultimo controllo`. Tutto il resto va in «**Dettagli sincronizzazione**» (sezione disclosure/secondaria) o nel **DEBUG**.

## Regola di precedenza stato/copy
La UI deve risolvere gli stati in questo ordine, così da evitare messaggi ambigui:
1. configurazione client mancante/non valida;
2. **sync/pull/push in corso** (busy esplicito, vedi righe Sync in corso / completata con note sopra): non mostrare un’altra CTA primaria che compete con il lavoro attivo senza stato “busy” leggibile;
3. transizione OAuth in corso;
4. OAuth signed-out o sessione scaduta;
5. OAuth valido ma errore permission/RLS/schema;
6. pending locali bloccanti o baseline stale;
7. baseline assente / DB locale non popolato;
8. pending push non bloccanti;
9. cloud pronto / ultimo sync OK.

### Tassonomia errori per la card Release

La Release card deve ridurre errori tecnici a **categorie stabili**, senza nascondere il dettaglio nel DEBUG.

| Categoria Release | Quando usarla | CTA primaria | Dettaglio DEBUG |
|-------------------|---------------|--------------|-----------------|
| `accountRequired` | OAuth assente/scaduto | Accedi | auth state / sessionInfo |
| `accountNeedsCheck` | account cambiato, owner non verificato, sessione dubbia | Controlla account | owner hash / mismatch redatto |
| `cloudPermission` | OAuth valido ma RLS/permission/schema nega accesso | Controlla cloud | status code / error category |
| `networkOffline` | rete assente / timeouts transienti | Riprova | URL/status / retry window redatti |
| `localNeedsDownload` | baseline assente o DB quasi vuoto senza pending incompatibili | Scarica database | baseline snapshot/counts |
| `localPending` | modifiche locali da inviare | Invia modifiche | pending breakdown |
| `needsReview` | conflitti, tombstone/delete, owner mismatch, righe ambigue | Apri revisione | review item list |
| `ready` | stato coerente e nessun blocker | Sincronizza ora | ultimo check/sync |

**Regola:** `accountRequired` **non** deve mai essere usato come fallback generico per permission, RLS o preview fallita se OAuth risulta valido.

---

## Gerarchia visiva iOS target per Opzioni

1. **Una sola card pubblica** in cima alla sezione cloud: **“Cloud synchronization”** (`SupabaseManualSyncReleaseCard`), unica autorità sullo stato perceived dell’operatore Release.
2. **DEBUG sempre sotto**, in sezione `#if DEBUG` **collassata di default** (es. `DisclosureGroup` “Diagnostica avanzata” / “Advanced diagnostics”) con badge `DEBUG`; non deve precedere né contraddire la card pubblica.
3. **Status card primaria** (Release), struttura fissa:
   - **Titolo** (una riga, semibold);
   - **Sottotitolo** (max 2–3 righe leggibili a Dynamic Type default);
   - **Badge stato singolo** (solo un badge dominante alla volta per ridurre rumore cognitivo);
   - **CTA primaria full-width** (`borderedProminent`, large);
   - **Massimo una CTA secondaria** testuale / bordered (`bordered`), opzionale.
4. **Mini-metriche compatte** sotto titolo/sottotitolo (stessa card o sub-stack):
   - ultimo controllo cloud;
   - stato baseline (`assente` / `ok` / `stale`);
   - pending locali (conteggio aggregato leggibile);
   - ultimo evento / ultimo errore sintetico (privacy-safe).
5. **Dynamic Type grande**: le metriche passano da **righe compatte → stack verticale**; niente troncamenti critici sotto Voce/accessibilità.
6. **Tab bar**: contenuto scrollabile deve rispettare **safe area** e margini inferiori (nessun testo primario né CTA nascosti dal tab bar; coerenza con TASK-106/107 su bottom inset dove applicabile).
7. **VIETATO** qualsiasi **bottone primario visibile ma inerte** (disabled senza caption/hint chiaro sul perché è preferibile → usare stato alternativo copy + CTA secondaria o rimuovere la primaria dal layout finché non abilitabile).

### Copy policy Opzioni

- Evitare frasi e termini tecnici sulla **card Release** tipo `baseline`, `RLS`, `outbox` — restano nei soli artefatti DEBUG/documentazione tecnica se necessario.
- Preferire linguaggio **operatore**: database locale, cloud, modifiche da inviare / da sincronizzare, scarica database dal cloud, controlla cloud, ultimo aggiornamento riuscito / con avvisi.
- La sezione **DEBUG** può usare termini tecnici, ma resta **separata** dalla Release e **collassata di default**.
- **Ogni messaggio di errore** sulla Release deve suggerire un’azione concreta oggi: **Riprova**, **Controlla cloud**, **Continua offline**, **Accedi di nuovo** solo se la sessione è **davvero** assente/scaduta (mai come maschera di errori permission).
- Evitare il pattern “errore generico + dettagli tecnici”: la card Release deve distinguere almeno **account**, **cloud non raggiungibile**, **permessi**, **dati da controllare**, **modifiche pending**.
- La CTA primaria deve essere un verbo di azione breve: `Accedi`, `Scarica database`, `Sincronizza ora`, `Invia modifiche`, `Apri revisione`, `Riprova`.

---

## Stato attuale iOS (audit statico sintetico — fonte codice locale + `https://github.com/XNIW/iOSMerchandiseControl`)

### A. Dove vivono stato auth / sync Options
| Superficie | Fonte stato principale | Note |
|-----------|-------------------------|------|
| Card Release (“Cloud synchronization”) | `SupabaseManualSyncReleaseCard` + `@StateObject` `SupabaseManualSyncViewModel` condiviso da `ContentView` (`SupabaseManualSyncForegroundRootHost`) | Snapshot auth copiato in `SupabaseManualSyncAuthPresentationContext` tramite `syncAuthPresentationContext()` (non è il `@ObservableObject` diretto sulla sessione OAuth). |
| Sezione DEBUG auth | `#if DEBUG` in `OptionsView`: legge **`supabaseAuthViewModel.isSignedIn` / sessionInfo** direttamente | Una sola fonte OAuth “vera”. |
| Sign-in pulsante Release | `handle(action:)` → `authViewModel.signInWithGoogle()` | Disabilitato quando `canSignIn == false`. |
| Sign-in pulsante DEBUG | idem `signInWithGoogle()` | Stesso ingresso OAuth. |

### Perché Release e DEBUG possono contraddirsi (ipotesi tecnica forte da validare in S108-A0)
- La UI Release usa **`authPresentationContext.isSignedIn`** (snapshot aggiornato su `onAppear`, `scenePhase.active`, alcuni `onChange` su `supabaseAuthViewModel`).
- Il **model state machine** usa `semiAutomaticState == .blockedAuth` anche quando la sessione OAuth è valida ma **preview remota** riporta `failureCategory == .auth` (`recordCloudCheckResult` in `SupabaseManualSyncViewModel`): es. JWT presente ma **REST 401/session refresh edge**, **owner mismatch**, o classificazione “auth” sovrapposta a problematiche di permission (da verificare in `SupabaseManualSyncRemotePreview`).
- Nel ramo `makePresentationState` dopo ingresso “signed-in”, se **`semiAutomaticState == .blockedAuth`** la card può ripresentare la **stessa copy “Sign in”** con `primaryAction.signIn` e `isEnabled: authPresentationContext.canSignIn`; ma **`canSignIn` è `false`** quando stato è **`signedIn`**, quindi il bottone **resta visibile ma disabilitato → “non fa nulla”**: coerente con report utente **P0**.

**Validazione obbligatoria prima di implementare fix:** in S108-A0 Codex deve verificare sul codice corrente se la card Release vista dallo screenshot è la nuova `SupabaseManualSyncReleaseCard` o una vecchia/alternativa `OptionsView` ancora compilata in qualche target/configurazione. Se i file locali e GitHub divergono, prevale il codice iOS locale dopo `git fetch && git status`, ma il report deve indicare commit/branch usati.

### Chi decide `isSignedIn`, baseline, preview, sync manuale, outbox
- **OAuth/sessione**: `SupabaseAuthService` + `SupabaseAuthViewModel` (`isSignedIn` richiede `state == .signedIn` **e** `sessionInfo!.isExpired == false`).
- **Baseline catalogo/manuPush**: `SupabaseCatalogBaselineReader` / Writer, modelli SwiftData `SupabaseCatalogBaselineRun`, `SupabaseCatalogBaselineRecord`.
- **Pull preview bounded**: `SupabasePullPreviewService` + staging nel coordinator `SupabaseManualSyncCoordinator` / adapter `SupabaseManualSyncPullPreviewAdapter`.
- **Apply locale**: `SupabasePullApplyService` (consumato dai path manual sync Release).
- **Push catalogo/ProductPrice/manual**: `SupabaseManualPushService`, `SupabaseManualPushPreflightService`, `SupabaseProductPriceManualPushService`, aggregazione `LocalPendingAggregatedPushPlanner`, `SyncEventOutboxEnqueueService`, drain `SyncEventOutboxDrainService` + recorder `SupabaseSyncEventLiveRecorder`/`SupabaseSyncEventRPCTransport` (`record_sync_event`).

### Login ≠ database aggiornato
- Nessun automatismo garantito che, post-OAuth, esegua **pull+apply atomico** su SwiftData senza conferma tramite piano manual sync semi-auto / review (**policy TASK-091+** conservative).
- L’empty state locale è compatibile con: baseline assente / pull mai applicato / errore preview classificato male / gated lifecycle.

### Stato attuale da verificare esplicitamente in S108-A0
Il planning assume che il codice corrente contenga già molte parti sync. Prima di ogni execution mutativa, verificare e documentare:
- [ ] esiste già un path “preview → apply” completo per supplier/category/product/ProductPrice;
- [ ] il baseline locale viene scritto dopo apply e letto dalla card Release;
- [ ] il Database tab osserva modifiche SwiftData post-apply senza dover riavviare app;
- [ ] i pending locali aggregati distinguono catalogo, prezzi e history;
- [ ] i `sync_events` outbox hanno owner/user coerente con sessione corrente;
- [ ] il sign-out non lascia nella UI snapshot signed-in stale;
- [ ] il sign-in Release e il sign-in DEBUG puntano allo stesso flusso OAuth, oppure la divergenza è documentata e corretta in Wave 1.
- [ ] comportamento account-switch: dopo sign-out/sign-in con account diverso, la UI non riusa baseline/pending remoti del vecchio owner come se fossero validi per il nuovo account.
- [ ] definizione pratica di “DB locale quasi vuoto”: conteggi minimi di prodotti/fornitori/categorie/prezzi/history da mostrare nella card o evidence, così il bug non dipende solo da percezione visiva.
- [ ] presenza di eventuali path delete/tombstone già esistenti nei servizi iOS e come vengono esposti in UI; se non esistono, documentare che TASK-108 non introduce delete cloud automatico.

---

## Riferimento Android (solo funzionale — non copiare Kotlin)
Percorso progetto dichiarato: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`
- **`InventoryRepository.kt`**: punto di consolidamento molte operazioni Room (inventory, storico/prezzi, sessioni remoti batch, batch apply — file molto grande, da usare come **catalogo comportamenti** durante execution per slice verticali Generate/History/DB).
- **Da mappare in execution**: ViewModel/schermate **Catalog/Cloud**, **GeneratedScreen**, **HistoryScreen**, pipeline `sync_events`/outbox lato Kotlin (percorsi esatti determinati durante **S108-B** nel repo Android — non inventati ora).

---

## Riferimento Supabase (solo schema/policy esistenti)
Percorso: `/Users/minxiang/Desktop/MerchandiseControlSupabase`
Migration lette come fonti di schema (no nuove colonne inventate nel planning):
- `20260417120000_task013_inventory_catalog_rls.sql` — catalogo + RLS
- `20260417200000_task016_inventory_product_prices.sql` — storico/prezzi
- `20260418200000_task019_inventory_catalog_tombstone.sql` — tombstone catalogo
- `20260421120000_task038_restrict_authenticated_delete_inventory.sql` — DELETE ristretto
- `20260422120000_task040_shared_sheet_sessions_v2.sql` — sessioni foglio/Historia remoti (naming da confermare nei file per parity History)
- `20260424021936_task045_sync_events.sql` — tabella **`sync_events`**, **RLS SELECT owner**, **`record_sync_event` SECURITY DEFINER**, domini **`catalog`** / **`prices`**, tipi MVP elencati in migration

### Checklist Supabase pre-mutazione (prima di pull/push/apply mutativo in EXECUTION)

Prima di qualsiasi operazione mutativa sul remoto (pull→apply, manual push, `record_sync_event` via outbox) l’implementatore deve **completare questa checklist** (documentazione + verifiche READ-ONLY; nessuno script SQL modificante in QUESTO task PLANNING):

- [ ] **Tabelle/colonne**: confronto schema **migration ufficiali** in `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/` vs assunzioni del client iOS (**nessuna colonna inventata**).
- [ ] **`owner_user_id` / equivalente**: sessione JWT coerente con owner delle righe mutate; mismatch = fail-closed o CTA reconnect, non silent apply.
- [ ] **`remoteID`**, **`updated_at`/revision**, **`deleted_at` o tombstone** (ove presenti in migration catalog/prices/session): comportamento locale definito prima del merge preview.
- [ ] **Unique constraints**: barcode univoco dove richiesto, supplier/category coherent remotes, **ProductPrice** idempotenza/unicità tecnica sulle chiavi operative (rivedere lineage TASK-099/101).
- [ ] **`record_sync_event`**: parametri/ammettenze/domini (**`catalog`/`prices`**) e tipi MVP già nella migration task045 + eventuali constraint successivi sempre da migration.
- [ ] **`changed_count`/payload/metadata**: limite pragmatico cambiamenti per batch/evento; non superare assunzione “bounded” dei servizi Release senza paging esplicito.
- [ ] **History/session**: se richiede **schema nuovo**, **payload grandi**, **conflitti multi-device** su sessioni foglio o **dipendenza da Excel allegati** nella catena sync → segnare la wave History come **BLOCKED_SCHEMA_OR_POLICY dentro TASK-108**, produrre proposta backend/schema precisa e **non** dichiarare PASS globale. TASK-109/TASK-110 può nascere solo come task backend/schema/polish collegato, non come rimozione della feature dal perimetro TASK-108.
- [ ] **Environment sanity**: documentare se le verifiche usano progetto Supabase locale, linked remoto dev o production-like; non mescolare risultati di ambienti diversi nello stesso verdict.
- [ ] **RLS read/write smoke gated**: se una verifica live è necessaria, deve essere synthetic-prefix, owner-scoped, privacy-safe e non distruttiva; altrimenti restare su fake transport/test locale.
- [ ] **Delete/tombstone policy**: confermare se il remoto espone `deleted_at`/tombstone per catalogo e se il client iOS ha già un comportamento; senza policy chiara, trattare delete come review-only.

### Flussi canonici (diagrammi testuali)

```text
OAuth sign-in → sessione valida → verifica accesso cloud/RLS
→ stato baseline locale → preview pull → apply SwiftData confermato
→ baseline aggiornata → Database / Options si aggiornano (stesso Cloud overview)
```

```text
Modifica locale Database / Generated / History (se in-scope)
→ scrittura SwiftData → ProductPrice se cambia prezzo/storico
→ pending LocalPendingChange → outbox/sync_event se previsto dal piano Wave 3
→ push manuale o drain esplicito → ack solo dopo read-back o successo verificabile/fail-closed
```

```text
Generated “Aggiorna database da questo foglio” (Wave 5 — Generated sync parity)
→ analisi righe/colonne → anteprima differenze anagrafica/prezzi/inventario
→ apply locale quanto più atomico possibile → HistoryEntry aggiornata
→ pending cloud pronto → UI: cosa resta da sincronizzare (badge/metric Options)
```

---

## Differenze funzionali iOS ↔ Android emerse nel brief (non exhaustive)
| Area | Android (target) | iOS attuale (osservazioni) |
|------|-------------------|----------------------------|
| Source of truth | Room sempre esplicitamente aggiornata da pipeline sync | SwiftData aggiornata da UX manual sync + CRUD/import + `InventorySyncService` Generated |
| Coerenza copy auth vs permission | Da verificare in UI Android | iOS Risk: `failureCategory == .auth` forza stato **blockedAuth**/copy sign-in mentre OAuth è OK |
| Generated end actions | Pipeline unica percepita utente | `startProductImportAnalysis()` vs `syncWithDatabase()` (`InventorySyncService`) separate |
| Popolazione post-login | Probabilmente pull/guard più esplicito o implicito dopo auth | iOS prudentemente **non applica** pull automatico completo |

### Glossario operativo da rendere esplicito in UX
| Termine UX | Significato tecnico | Dove impatta |
|------------|--------------------|--------------|
| Database locale | SwiftData locale, equivalente concettuale di Room | Database, Generated, History |
| Database cloud | Supabase remoto condiviso Android/iOS | Opzioni, sync manuale |
| Anagrafica prodotto | Barcode, codice articolo, nomi, fornitore, categoria, prezzi correnti | Import, Database, Generated |
| Inventario / quantità | `stockQuantity` o quantità applicata dal foglio corrente | Generated → DB |
| Storico prezzi | `ProductPrice` locale/remoto con current/previous | Database price history, import, Generated |
| Entry foglio / History | Stato del foglio generato, righe complete, export, restore | History / `shared_sheet_sessions` |

Questa distinzione è necessaria perché le due azioni Generated attuali non sono “due update uguali”: una riguarda **anagrafica/prodotti/prezzi**, l’altra riguarda **quantità/inventario e stato del foglio**. La UX finale deve però presentarli come un unico flusso guidato.

---

## Micro-slice progressive (ordine vincolato e ottimizzato)
Ogni slice deve chiudersi con mini-handoff e con una risposta esplicita: **cosa è stato implementato**, **cosa resta non implementato**, **blocked** o **deferred inside TASK-108**, **come si verifica**. È vietato saltare direttamente a pull/push complessi prima di aver risolto **P0** stato/copy Options.

### Onde di execution consigliate (Wave 1…7)

Le slice seguono un **raggruppamento operativo**. In EXECUTION, una wave successiva parte solo dopo **gate** della precedente definiti dall’implementatore nella review/handoff Wave (raffinarli con Prompt estensione **E — Wave execution gate**).

| Wave | Obiettivo | Slice incluse | Esito atteso sintetico |
|------|-----------|---------------|------------------------|
| **Wave 1 — P0 UX-state Options** | Eliminare contraddizione login/sync e bottoni inerti | **S108-A0**, **S108-A**, **S108-B**, **S108-B2** | Stato/copy/Badge coerenti; OAuth vs permission distinguibili; CTA sempre significative |
| **Wave 2 — Bootstrap/full pull** | Signed-in + DB vuoto / baseline assente → preview/apply sicuro | **S108-C** + parte pertinente di **S108-H** | CTA bootstrap operativa mai silenziosa; checklist Supabase pre-mutazione rispettata |
| **Wave 3 — Auto incremental pull on launch/foreground** | App launch/foreground avvia pull incrementale safe quando possibile | **S108-K** + lifecycle gate di **S108-H** | Pull incrementale automatico controllato, debounced, no wipe, no doppio trigger |
| **Wave 4 — Incremental push da Database** | Modifiche DB locali generano pending/outbox e push incrementale | **S108-D1**, **S108-F**, **S108-G** | Product/supplier/category/price changes tracciati, ack fail-safe, owner safe |
| **Wave 5 — Generated sync parity** | Generated aggiorna DB locale + ProductPrice + HistoryEntry + pending cloud | **S108-E**, **S108-D2** | Flusso «Aggiorna database da questo foglio» completo e idempotente |
| **Wave 6 — History/session sync parity** | History screen / shared sheet sessions sincronizzate come Android | **S108-C3**, **S108-D3** | Sessioni foglio push/pull/reconcile o **BLOCKED_SCHEMA_OR_POLICY** documentato |
| **Wave 7 — End-to-end acceptance** | Verifica flussi cross-feature e regressione | **S108-I**, check finali, evidence | Options + auto pull + push + Generated + History documentati in verdict finale |

### Gate Wave PASS / PARTIAL / BLOCKED

| Wave | PASS | PARTIAL | BLOCKED |
|------|------|---------|---------|
| Wave 1 | Release e DEBUG non si contraddicono; reducer/test P0 verdi; sign-out/sign-in non lascia snapshot stale | Copy migliorata ma una diagnostica resta solo manualmente verificata | OAuth valido e permission/RLS non distinguibili, oppure CTA primaria ancora inerte |
| Wave 2 | Bootstrap/full pull locale vuoto funziona con preview/apply sicuro e Database si aggiorna | Preview pronta ma apply rinviato con motivazione temporanea | Pull richiede schema/RLS/RPC nuovo o rischia wipe/merge non controllato |
| Wave 3 | Auto pull incrementale parte su launch/foreground solo se condizioni safe; debounce/gate provato | Auto pull solo manual-triggered ma policy pronta | Lifecycle gate impossibile o rischio overwrite locale dirty non risolto |
| Wave 4 | Modifiche Database creano pending/outbox/push incrementale con ack fail-safe | Alcuni domini DB restano no-op documentati | RPC/limiti payload incompatibili o pending non tracciabili per dominio |
| Wave 5 | Generated ha CTA primaria unica/sheet guidata; apply locale + pending cloud + idempotenza | Solo E1 copy forte, ma **non** chiusura PASS globale | I due update restano ambigui o duplicano scritture senza idempotenza |
| Wave 6 | History/shared sessions push/pull/reconcile funzionano come Android nel perimetro schema esistente | Mapping iniziale fatto ma sync non completa, **non** chiusura PASS globale | Richiede schema nuovo/payload grandi/conflitti multi-device non risolti |
| Wave 7 | Tutte le wave funzionali hanno evidence e verdict coerente | Alcune evidence manuali mancanti, PASS_WITH_NOTES possibile solo se funzioni core passano | Una wave P1 è PARTIAL/BLOCKED senza decisione tecnica |

**Nota Scope optimization aggiornata:** History/session, auto pull e push incrementale **restano nel perimetro TASK-108**. Se una wave **P1** è PARTIAL/BLOCKED, TASK-108 può avere **verdict intermedio**, ma **non PASS** di parità Android. Eventuali task successivi servono solo per **schema/backend/polish**, non per **dimenticare** la feature.

### Tracciamento obbligatorio per wave *(Implemented / Not implemented yet / Blocked / Evidence)*

Obiettivo: durante **EXECUTION** e review, TASK-108 deve sempre permettere di vedere **cosa è già stato implementato**, cosa è **non ancora implementato** (ma ancora previsto nel perimetro), cosa è **blocked** — e **quali artefatti evidence** attestano quel verdict. **Non compilare righe PASS/FAIL fittizi in PLANNING**; lasciare piuttosto puntatori tipo “`(da compilare in EXECUTION)`”.

| Wave | Implemented | Not implemented yet | Blocked | Evidence *(file nominati)* |
|------|-------------|---------------------|---------|-----------------------------|
| **Wave 1 — P0 UX-state Options** | *(da compilare in EXECUTION)* | *(da compilare in EXECUTION)* | *(da compilare in EXECUTION)* | Primari `00-audit-options-state.md`, `01-cloud-overview-state-matrix.md`, `02-options-ux-screenshots.md`, più `09-wave-gates.md` riga Wave 1, `14-options-copy-matrix.md`, `15-wave1-minimal-brief.md`, `16-release-error-taxonomy.md`; regressioni `08-regression-notes.md` dove applicabile. |
| **Wave 2 — Bootstrap/full pull** | *(da compilare)* | *(da compilare)* | *(da compilare)* | `03-pull-bootstrap-plan-result.md`; `06-tests-builds.md`; merge/tombstone `11-source-of-truth-merge-policy.md`, `13-delete-tombstone-review-policy.md`; **`09-wave-gates.md`** riga Wave 2; `06`, `07` come da scope test/privacy. |
| **Wave 3 — Auto incremental pull** | *(da compilare)* | *(da compilare)* | *(da compilare)* | `17-auto-incremental-pull.md`; lifecycle `09-wave-gates.md` Wave 3; **`06-tests-builds.md`**; **`07-privacy-security-scan.md`** dove tocca log/metriche. |
| **Wave 4 — Incremental push Database** | *(da compilare)* | *(da compilare)* | *(da compilare)* | `04-push-mutation-map.md`; `18-database-incremental-push.md`; **`09-wave-gates.md`** Wave 4; outbox/policy `08`, `07` dove applicabile. |
| **Wave 5 — Generated sync parity** | *(da compilare)* | *(da compilare)* | *(da compilare)* | `05-generated-guided-apply-ux.md`; `19-generated-sync-parity.md`; `04-push-mutation-map.md` (append/matrice mutate); **`09-wave-gates.md`** Wave 5; `06`, `07`, `08` come richiesto. |
| **Wave 6 — History/session sync parity** | *(da compilare)* | *(da compilare)* | *(da compilare)* | `20-history-session-sync-parity.md`; **`10-task109-split-decision.md`** *solo se* serve proposta migration/backend per **BLOCKED_SCHEMA_OR_POLICY** (non rimuove la wave dal perimetro TASK-108); **`09-wave-gates.md`** Wave 6; `11`, `12`, `13` per merge/account/delete se toccati. |
| **Wave 7 — End-to-end acceptance** | *(da compilare)* | *(da compilare)* | *(da compilare)* | `21-end-to-end-sync-acceptance.md` (**sintesi verdict** aligned a **CA-T108-32**); **`09-wave-gates.md`** tabella finale; **`06-tests-builds.md`** / `08-regression-notes.md` per regressione sintetica. |

### **S108-A0 — Audit riproducibile della superficie Options reale (P0 / no code first)**
Obiettivo: verificare quale codice produce esattamente gli screenshot, perché il raw GitHub può essere minificato/troncato e perché esistono storicamente più implementazioni Options.

Output richiesto in execution:
- [ ] Branch/commit iOS locale e GitHub annotati.
- [ ] Elenco dei simboli reali compilati: `OptionsView`, `SupabaseManualSyncReleaseCard`, `SupabaseManualSyncForegroundRootHost`, `ContentView` injection, `#if DEBUG` sections.
- [ ] Conferma se Release card e DEBUG card usano lo stesso `SupabaseAuthViewModel` o snapshot diverso.
- [ ] Screenshot/state dump privacy-safe dei casi: signed-out, signed-in baseline absent, permission/RLS simulated/fake.
- [ ] Nessuna patch Swift prima di questa mappa, salvo fix markdown/evidence.
- [ ] Mappa precisa delle sorgenti dati visibili in Options: quali valori sono live OAuth, quali baseline locali, quali ultimi errori cached, quali DEBUG-only.
- [ ] Definizione di fixture/stati fake necessari per riprodurre la matrice UX senza dipendere da rete reale.
- [ ] Identificare quali parti della card Release devono essere snapshot-testabili senza avviare Supabase reale.
- [ ] Identificare quali stati richiedono solo fake transport e quali, eventualmente, smoke live gated.
- [ ] Compilare una tabella **“Release vs DEBUG”** con colonne: **fonte stato**, **valore letto**, **timestamp/update trigger**, **copy mostrata**, **CTA mostrata**, **motivo eventuale divergenza**.
- [ ] Confermare se il problema è **puramente presenter/copy** oppure esiste anche un **bug di lifecycle/session refresh** da correggere in parallelo.

### **S108-A — CloudSyncOverviewState / reducer unico (P0)**
Obiettivo: introdurre o formalizzare un presenter unico tipo `CloudSyncOverviewState` derivato da:
`SupabaseAuthViewModel.State`, `sessionInfo`, baseline reader, ultimo piano manual sync, `failureCategory`, conteggi locali/remoti, pending aggregated push, outbox `sync_events`, ultimo evento cloud.

Requisiti:
- [ ] Separare `oauthStatus` da `remoteAccessStatus`.
- [ ] Separare `baselineStatus` da `pullStatus`.
- [ ] Separare `pendingPushStatus` da `outboxDrainStatus`.
- [ ] Esporre `primaryCTA`, `secondaryCTA`, `isPrimaryEnabled`, `disabledReason`, `visualSeverity`.
- [ ] Vietare stato “Sign in” quando OAuth è valido ma preview/policy fallisce.
- [ ] XCTest reducer con matrice: signedOut, signedInNoBaseline, signedInReady, permissionError, networkError, pendingPush, blocker.
- [ ] Il reducer deve essere **puro** e testabile senza `ModelContext`, rete né `View`; i servizi reali producono solo **snapshot immutabili** in ingresso al reducer.
- [ ] Definire input immutabili del reducer, ad esempio `AuthSnapshot`, `RemoteAccessSnapshot`, `BaselineSnapshot`, `PendingSnapshot`, `LastSyncSnapshot`, così i test non dipendono da View SwiftUI.
- [ ] Definire output UI stabile: `titleKey`, `messageKey`, `badgeKind`, `primaryAction`, `secondaryAction`, `debugSummary`, `isBlocking`, `allowsLocalWork`.
- [ ] Definire policy `allowsLocalWork`: anche con cloud offline/errore, Database/Generated/History devono restare usabili salvo apply mutativo in corso.
- [ ] Ogni `primaryAction` ha **precondizioni esplicite** in planning/test: se non vere → **non mostrare** azione primaria oppure **motivo leggibile + azione alternativa** (mai primaria apparente/disabled opaca).
- [ ] Il reducer deve produrre anche un `reviewRequiredCount` / `hasReviewItems` quando conflitti, delete/tombstone o owner mismatch impediscono apply/push automatico.
- [ ] Il reducer deve mappare **ogni** failure di input verso **una sola** categoria Release della **Tassonomia errori per la card Release** sopra; **vietati** fallback generici tipo «auth» o «unknown» senza **`secondary`/debug detail** articolato nei test/evidence.
- [ ] Gli snapshot devono includere un **`snapshotOwnerKey`/hash redatto** quando la metrica è **user-scoped**, così la UI può evitare riuso cross-account.

### **S108-B — Options UX unificato Release vs DEBUG diagnostic**
Obiettivo: sostituire la contraddizione visiva con una card pubblica unica, compatta e leggibile.

UX target scelto:
- Card principale “Cloud synchronization” con stato, ultimo controllo, conteggi essenziali e una CTA primaria.
- Sotto-card “Database locale” se signed-in ma baseline assente: `Connesso. Il database locale non è ancora stato scaricato.`
- DEBUG dentro `DisclosureGroup`/sezione “Advanced diagnostics”, collassata di default, con badge `DEBUG` e copy “diagnostic only”.
- I dettagli `Supabase Sync Access`, outbox, baseline, recent events non devono precedere né contraddire la card release.

Criteri:
- [ ] Nessun bottone primario “inerte”.
- [ ] Accessibilità: label VoiceOver su stato, CTA e contatori.
- [ ] Dynamic Type extra-large senza sovrapposizione con tab bar.
- [ ] Copy localizzato IT/EN/ES/zh-Hans.
- [ ] Screenshot/evidence per iPhone piccolo e Dynamic Type almeno `extra-extra-large`.
- [ ] Se la sezione DEBUG supera una schermata, dividerla in sottogruppi collassabili: `Auth`, `Pull`, `Push`, `Outbox`, `Events`.
- [ ] La card Release deve avere un empty/loading/error state leggibile anche senza dati remoti disponibili.
- [ ] Se esistono elementi da controllare, la UI deve mostrare una sezione sintetica `Da controllare` invece di seppellirli nel DEBUG.
- [ ] La schermata deve mantenere un percorso chiaro verso Database anche quando il cloud è in errore, coerente con local-first.
- [ ] La UI deve restare coerente con lo **stile iOS esistente**: List/Form / card grouped, **spaziatura leggera**, **una gerarchia primaria chiara**, nessun **pannello admin dashboard permanente**.
- [ ] In **Release** non mostrare più di una **CTA prominent** (`borderedProminent`) nello **stesso blocco** principale; le azioni secondarie vanno in **menu**, **disclosure**, **secondary button** o sheet secondarie.
- [ ] La card deve essere **comprensibile in massimo ~5 secondi**: **titolo + messaggio + CTA** devono spiegare **cosa fare** senza aprire il DEBUG.
- [ ] La sezione **«Dettagli sincronizzazione»** (metriche/context aggiuntivo) deve essere **utile** ma **non obbligatoria** per completare l’azione primaria.

### **S108-B2 — Lifecycle binding auth snapshot**
Obiettivo: eliminare drift tra `authPresentationContext` e sessione OAuth reale.

Requisiti:
- [ ] Aggiornamento su `SupabaseAuthViewModel.state`, `sessionInfo`, `scenePhase.active`, ritorno OAuth callback e signOut.
- [ ] Se possibile, evitare duplicazione snapshot e passare un presenter osservabile unico.
- [ ] Test su sign-in → baseline absent → sign-out → signed-out, senza stati fantasma.
- [ ] Sign-out deve **invalidare o nascondere** nella UI baseline/pending **user-scoped** remoti se non più verificabili con sessione corrente; **non** cancellare dati locali senza conferma esplicita.
- [ ] Ritorno da **OAuth callback** aggiorna la card Release **una sola volta**, senza doppio refresh né pull automatico indesiderato.

### **S108-C — Pull catalogo iOS parity Android: bootstrap sicuro**
Obiettivo: quando l’utente è signed-in e SwiftData/baseline è assente, guidare una prima sincronizzazione locale senza wipe silenzioso.

Policy scelta:
- **Non** fare apply mutativo automatico appena completato OAuth.
- Dopo sign-in mostrare CTA primaria **“Scarica database dal cloud”**.
- Se locale è vuoto: preview breve + apply confermabile in un passaggio.
- Se locale non è vuoto o pending locali presenti: preview dettagliata + confirmationDialog + stop se blocker.

Criteri:
- [ ] Full pull supplier/category/product/ProductPrice con `remoteID` bridge coerente.
- [ ] Conteggi locali prima/dopo visibili.
- [ ] Errori RLS/schema/rete classificati in modo diverso.
- [ ] Nessuna cancellazione locale non richiesta.
- [ ] Se il locale è vuoto ma il remoto contiene dati, il flusso deve essere massimo due tap: `Scarica database` → `Conferma`.
- [ ] Se il locale contiene dati, mostrare differenze sintetiche prima di apply: create/update/link/skip/blocker.
- [ ] Definire rollback/failure UX: se apply fallisce a metà, mostrare stato parziale e recovery, non “sync OK”.
- [ ] Il Database deve aggiornarsi dopo apply senza richiedere force quit / riavvio app.
- [ ] Stato “quasi vuoto” deve guidare verso bootstrap solo se non ci sono pending locali incompatibili; altrimenti mostrare prima revisione locale.
- [ ] Se apply crea nuovi supplier/category/product, i conteggi post-apply devono essere coerenti con quelli mostrati in preview o spiegare gli skip.
- [ ] Se il preview remoto include delete/tombstone o record non applicabili, non bloccare tutto se il servizio supporta safe partial apply; mostrare conteggio `da controllare`.

### **S108-C2 — Pull incrementale via sync_events / baseline cursor**
Obiettivo: quando baseline valida esiste, usare `sync_events`/cursor o fallback bounded preview per aggiornamenti incrementali.

Criteri:
- [ ] Definire fonte cursor/watermark locale e dove persisterla.
- [ ] Applicare solo domini supportati (`catalog`, `prices`, eventuale `history` se schema confermato).
- [ ] Fallback a preview bounded se evento remoto non risolvibile.
- [ ] Non dichiarare sync completa history se `shared_sheet_sessions` non è coperto dalla slice.
- [ ] Se `sync_events` non copre un dominio o evento, fallback deve essere esplicito: bounded preview, full preview confermata, o domain skipped con warning.
- [ ] Il cursor/watermark deve avanzare solo dopo apply locale riuscito, non dopo semplice fetch remoto.
- [ ] Se un evento remoto è parzialmente applicato, il cursor deve avanzare solo fino all’ultimo evento completamente gestito o deve persistere una recovery marker esplicita.

### **S108-K — Auto pull incrementale on app launch / foreground**

Obiettivo: allineare iOS al comportamento Android desiderato: quando l’app si apre o torna **foreground**, esegue un controllo/**pull incrementale sicuro** per aggiornare SwiftData dal remoto, **senza wipe** e **senza conflitti silenziosi**.

**Condizioni minime per auto pull:**

- OAuth valido e sessione non scaduta;
- account/owner verificato rispetto a baseline/pending locali;
- baseline locale valida o bootstrap già completato;
- nessun pending locale bloccante non ackato che renda pericoloso applicare remoto;
- rete disponibile o errore network classificabile senza bloccare local work;
- lifecycle gate/debounce: niente doppio pull per `.onAppear` + `scenePhase.active`;
- cooldown configurabile/documentato per evitare pull continuo a ogni cambio schermata.

**Comportamento:**

- Se condizioni safe: fetch `sync_events`/cursor, preview bounded, apply incrementale locale, avanzamento watermark **solo dopo apply riuscito**;
- Se pending locali presenti: non sovrascrivere; mostra `Modifiche da inviare` o fa solo preview **non mutativa**;
- Se account mismatch: stato `Controlla account`, nessun pull mutativo;
- Se errore RLS/permission: stato `Controlla cloud`, local-first resta usabile;
- Se offline: nessun errore bloccante; mostra `Cloud non raggiungibile`, retry futuro.

**UX:**

- Options mostra `Ultimo controllo`, `Sync in corso`, `Cloud aggiornato con avvisi` o `Da controllare`;
- Home/Database non devono mostrare overlay invadenti se il pull automatico è non bloccante;
- se il pull automatico applica dati, Database deve aggiornarsi **senza riavvio**.

**Test/evidence:**

- fake lifecycle tests per launch/foreground/debounce;
- test no double trigger;
- test pending locale blocca apply mutativo;
- evidence in `17-auto-incremental-pull.md`.

### **S108-C3 — History / shared sheet sessions parity (Wave 6)**

Obiettivo: portare **History screen** / **`shared_sheet_sessions`** alla parità funzionale Android **dentro TASK-108**, con slice dedicate (**`S108-C3`**, **`S108-D3`**).

**Hard rule aggiornata:** questo slice deve portare History/session parity il **più avanti possibile** dentro TASK-108. Se una delle condizioni seguenti ricorre, la wave **non** viene rimossa dal perimetro: passa a **BLOCKED_SCHEMA_OR_POLICY** con proposta precisa di backend/schema, **mantenendo la feature nel perimetro TASK-108**:

- servono **nuove colonne/tabelle/policy** Supabase fuori migrazioni esistenti;
- payload sessione troppo grande per il modello attuale;
- conflitto multi-device non risolvibile con modello MVP;
- sync dipende dal trasporto **file Excel allegati** nella catena sync.

**Gate di esito:**

- **PASS**: History/session sync push/pull/reconcile funziona nel perimetro schema esistente.
- **PASS_WITH_NOTES**: sync dei metadati/session state funziona, ma allegati/export destinations restano fuori scope documentato.
- **BLOCKED_SCHEMA_OR_POLICY**: schema o policy mancanti impediscono parity completa; produrre proposta backend, ma **non** dichiarare PASS.

Obbligatorio in questo slice:

- [ ] Tabella campo-per-campo *locale vs remoto vs Android reference* (privacy-safe evidence).
- [ ] Lista esplicita campi/sync **non ancora implementati** o **blocked** aggiornata in ogni wave handoff.

Requisiti di analisi (sempre applicabili):
- [ ] Mappare `HistoryEntry` SwiftData ↔ `shared_sheet_sessions` Supabase (solo lettura documentale finché PLANNING-only).
- [ ] Separare chiaramente **metadati** vs **blob JSON grandi / allegati** vs **azioni export verso filesystem**.

### **S108-D — Push incrementale modifiche locali end-to-end**

Obiettivo: mappare ogni mutazione locale verso pending/outbox/remote push (**matrice madre**; dettaglio operativo in **`S108-D1`**, **`S108-D2`**, **`S108-D3`**).

Tabella obbligatoria da compilare in execution:
| Sorgente locale | Tipo dato | Pending local change | sync_events domain/type | Push service | Note |
|-----------------|----------|----------------------|-------------------------|--------------|------|
| Database product add/edit/delete | catalog | TBD | catalog | TBD | delete remoto limitato da policy |
| Supplier/category add/edit/delete | catalog | TBD | catalog | TBD | replacement/unlink TASK-107 |
| Price history add/update current | prices | TBD | prices | TBD | ProductPrice idempotente |
| Generated apply product master | catalog/prices | TBD | catalog/prices | TBD | da sheet |
| Generated apply inventory | catalog/history | TBD | catalog/history? | TBD | stock + entry state |
| History rename/restore/complete/export | history | TBD | history / session | TBD | obbligatorio in Wave 6 se schema esistente lo supporta |
| Full DB import/export | catalog/prices/history | TBD | TBD | TBD | evitare push massivo automatico |

Regola efficienza: non creare un outbox event per ogni singola riga se esiste già un evento aggregato sicuro per dominio. Per dataset grandi usare eventi compatti con conteggio, fingerprint e metadata redatti, rispettando i limiti RPC verificati nella checklist Supabase.


Regola di ack: non marcare pending locale come completato finché il push non è confermato da risposta remota affidabile o read-back equivalente. In caso di timeout/errore ambiguo, mantenere pending e mostrare retry.

Regola account/owner: pending creati sotto un owner non devono essere pushati con una sessione diversa senza verifica esplicita. Se l’account cambia, mostrare `Controlla account` / `Review pending`, non inviare in automatico.

### **S108-D1 — Database screen incremental push**

Obiettivo: ogni modifica da **Database** screen deve generare pending/outbox e **push incrementale** coerente.

**Trigger policy scelta:** dopo una modifica locale salvata con successo in SwiftData, iOS deve creare **pending locale immediato** e tentare un drain/push incrementale **solo se safe**: OAuth valido, owner coerente, rete disponibile, nessuna mutazione già in corso, nessun blocker review. Se non è safe, il pending resta visibile in Options e riparte al prossimo `Sync now`, app foreground safe o retry esplicito.

**Copertura:**

- product add/edit/delete **review-first**;
- supplier/category add/rename/delete con replacement/unlink TASK-107;
- ProductPrice add/update current price;
- import prodotti singolo/full DB: **senza** push massivo automatico non previewato;
- ack solo dopo successo verificabile/read-back equivalente;
- Options mostra pending e stato cloud.

### **S108-D2 — Generated incremental push**

Obiettivo: modifiche/apply da **Generated** devono produrre pending/push come Android.

**Trigger policy scelta:** “Aggiorna database da questo foglio” prima salva e rende coerente SwiftData locale; subito dopo crea pending cloud per catalog/prices/history/session. Il push può partire automaticamente solo se le **condizioni safe** sono vere; altrimenti la UI mostra “Database locale aggiornato” + “Cloud in attesa”, senza perdere il lavoro locale.

**Copertura:**

- anagrafica prodotto aggiornata da foglio;
- stock/quantità applicata localmente;
- ProductPrice registrato se cambia prezzo;
- HistoryEntry/stato foglio aggiornato;
- pending cloud creato per catalog/prices/history/session dove applicabile;
- idempotenza su retry o secondo tap.

### **S108-D3 — History/session incremental push/pull**

Obiettivo: **History** screen deve sincronizzare sessioni foglio come Android.

**Copertura obbligatoria:**

- rename HistoryEntry;
- delete/review HistoryEntry secondo policy non distruttiva;
- restore/apertura entry da altro dispositivo se presente in Supabase;
- complete states, editable values, export flag, supplier/category/totals compatibili con schema;
- conflict policy per stessa sessione modificata su due dispositivi;
- se schema non supporta un campo, documentare **BLOCKED_SCHEMA_OR_POLICY** e proposta backend.

### **S108-E — Generated unified apply UX (target Wave 5; rollout E1→E2; E3 subordinato al gate C3)**

Obiettivo: ridurre confusione dei due bottoni attuali con **un solo flusso percettibile** dall’operatore (**“Aggiorna database da questo foglio”**), riusando i servizi esistenti dove possibile.

#### Decisione UX (coerenza con Scope optimization — Wave 5)
- Target **UX-2 guidata**: sheet multi-step dopo **S108-E2**.
- **Chiusura minima TASK-108** se gate bloccano **E2**: **S108-E1** deve rendere comunque leggibili le tre fasi (anagrafica/prezzi · inventario · cloud pending) via copy/sheet introduttivo, **senza** claim di wizard full.

#### Detail Generated (design atteso dall’implementazione Wave 5)
1. **`GeneratedView` mantiene** FAB / pulsanti **ricerca & scanner** flottanti o equivalenti ergonomici già previsti dalla schermata (non rimuovere l’accesso rapido inventario nel nome del nuovo flow).
2. **Sezione Summary**: un **solo CTA principale dominante**: *“Aggiorna database da questo foglio”*; i due bottoni storici eventualmente relegati dopo E2 come *“azioni avanzate”* collassabili solo se ancora richiesto per rollout graduale.
3. **Sheet principale**: checklist sempre visibile in testa (`Section`/`List`) con stato macro: **Da fare**, **In corso**, **Fatto**, **Attenzione** (warning recuperabili), **Bloccato** (azioni richieste prima di continuare).
4. **Prima dell’apply confermato**: blocco metriche sintetiche (**anteprima**):
   - prodotti **nuovi**;
   - prodotti **aggiornati**;
   - **prezzi registrati** (nuovi punti storico / modifiche pertinenti ai path esistenti);
   - **quantità applicate** (`stock`/qty effettivi che verranno scritti);
   - **righe saltate** (+ motivazione UX breve);
   - **`pending cloud` stimati/post-apply**.
5. **Dopo apply**:
   - **“Database locale aggiornato”** quando commit SwiftData ok;
   - se esistono pending cloud: **“Da sincronizzare con cloud”** (+ hint navigazione sicura verso Opzioni / piano manuale, senza dichiarazioni false di push completato).

#### Organizzazione tecnica dei tre blocchi (reuse servizi — no rewrite pianificatorio)
Ordine suggerito nello UX sheet **E2** (può essere un’unica schermata scrollabile segmentata): **analisi/import anagrafica** (codice tipo `startProductImportAnalysis`), poi **`InventorySyncService.sync`** per inventario/pricing da foglio dove applicabile oggi, infine registrazione **pending/outbox** (dettaglio in **`S108-D2` / Wave 5**).

Rollout sintetico:
- **S108-E1**: copy + mini-sheet “cosa fare e perché”; possibile reorder UI minimo (**chiusura minima Scope optimization**).
- **S108-E2**: flow guidato reale sopra gli stessi servizi (**target parity perceived Android** sul foglio Generated).
- **S108-E3**: hook History/session **solo** se **`S108-C3`** = **PASS** o **PASS_WITH_NOTES** nello schema esistente; se **BLOCKED_SCHEMA_OR_POLICY**, resta nel perimetro TASK-108 come wave documentata, non spostamento funzionale a TASK-109.

#### Error/empty state Generated sheet
- **Nessuna riga valida**: mostrare spiegazione e CTA “Torna al foglio”, non creare pending.
- **Prodotti validi ma cloud offline**: permettere apply locale e mostrare `Cloud in attesa`.
- **Righe ambigue**: mostrare conteggio e link a dettaglio; non bloccare righe valide se il servizio supporta apply parziale sicuro.
- **Apply già eseguito**: il flow deve essere idempotente o mostrare “Già aggiornato” evitando doppia registrazione prezzi/stock.

### **S108-F — Osservabilità & logging privacy**
Obiettivo: rendere verificabile lo stato senza loggare token, email raw o UUID non redatti.

Criteri:
- [ ] Log DEBUG strutturati e redatti.
- [ ] Release mostra solo messaggi operator-friendly.
- [ ] Evidence privacy scan obbligatoria.

### **S108-G — Security/conflict governance**
Obiettivo: regole operative prima di qualsiasi apply/push.

Regole:
- [ ] No wipe SwiftData implicito.
- [ ] No service_role/client secret.
- [ ] ProductPrice duplicate = idempotenza solo con read-back esatto.
- [ ] Barcode/remoteID conflict = blocker con review, non sovrascrittura silenziosa.
- [ ] Pending locali presenti = pull mutativo richiede conferma o stop.
- [ ] Delete/tombstone remoto = review manuale salvo prova di safe delete idempotente e non distruttivo.
- [ ] Owner mismatch = mai auto-fix: mostrare `Controlla account` / `Da controllare`.

### **S108-H — Performance, lifecycle, duplicate-trigger guard e large dataset**

Obiettivo: evitare regressioni su dataset grandi (TASK-089/095/100) e impedire che preview/pull/apply si rilancino in modo spuri da lifecycle SwiftUI oltre soglie UX accettabili.

Criteri (per **Wave 2** bootstrap, **Wave 3** auto pull **`S108-K`**, **Wave 4+** push/apply):
- [ ] Operazioni con durata attesa tipica **> ~1 secondo**: mostrare stato **busy** esplicito (Progress/copy “Sincronizzazione in corso”, coerenza matrice UX Cloud overview).
- [ ] Operazioni con durata attesa tipica **> ~10 secondi**: progettare **cancellation** quando supportata dai `Task` Swift esistenti, oppure garantire che l’operatore **possa uscire** dalla UI senza deadlock (warning “continua in background?” solo se tecnicamente corretto — documentare comportamento residue).
- [ ] **VIETATI** ripetizioni automatiche preview/pull causa combo **`.onAppear`**, **`scenePhase == .active`**, più **`onChange`** senza **gate/dedupe/debounce** (**CA-T108-12**): integrare/`estendere` `SupabaseManualSyncLifecycleRunGate` o equivalente.
- [ ] Batch apply progettati per **cancellation cooperativa** tra chunk quando possibile; altrimenti stato **Bloccato** fino fine batch comunicato allo sheet Generated.
- [ ] Vietare decoding/parsing/import **pesanti** sul **MainActor** oltre i **salvataggi SwiftData strettamente necessari** sulla main (riuso pattern off-main dove già presenti nei path Excel/import/sync).
- [ ] Mantenere **pagination / bounded preview / memory budget** come già documentato nei servizi sync storici.
- [ ] Evitare UI freeze nella sheet Generated: l’utente deve poter chiudere o almeno capire che l’operazione è in corso e non ripremere la CTA.
- [ ] Debounce/gate per `scenePhase.active` deve essere coperto da test o evidence manuale, perché è il punto più probabile di doppia preview/pull.
- [ ] Ogni **operazione mutativa** deve avere un **operationID** / **fingerprint** logico o **guard** equivalente per impedire **doppio tap** e **doppio lifecycle trigger** sulla stessa mutazione.
- [ ] Le operazioni di **sola preview** possono essere **coalesced** / **debounced**; le operazioni **mutative** devono essere **serialized** (o **bloccate finché** la precedente non termina esplicitamente, con stato busy/bloccante coerente).
- [ ] Le **CTA mutative** devono **disabilitarsi** o passare a **busy immediatamente dopo il tap**, **prima** di avviare il lavoro async, per evitare **doppio tap** umano.
- [ ] Se l’utente **lascia la schermata** durante una mutazione, il piano in execution deve **documentare** se l’operazione **continua**, viene **cancellata** o mostra **recovery al ritorno**; vietato lasciare comportamento **solo implicito** non descritto in handoff/evidence.

### **S108-I — Evidence pack e review gates**
Obiettivo: rendere la review verificabile senza dati reali.

Evidence attesa:
- `00-audit-options-state.md`
- `01-cloud-overview-state-matrix.md`
- `02-options-ux-screenshots.md`
- `03-pull-bootstrap-plan-result.md`
- `04-push-mutation-map.md`
- `05-generated-guided-apply-ux.md`
- `06-tests-builds.md`
- `07-privacy-security-scan.md`
- `08-regression-notes.md`
- `09-wave-gates.md`
- `10-task109-split-decision.md`
- `11-source-of-truth-merge-policy.md`
- `12-account-switch-local-first.md`
- `13-delete-tombstone-review-policy.md`
- `14-options-copy-matrix.md`
- `15-wave1-minimal-brief.md`
- `16-release-error-taxonomy.md`
- `17-auto-incremental-pull.md`
- `18-database-incremental-push.md`
- `19-generated-sync-parity.md`
- `20-history-session-sync-parity.md`
- `21-end-to-end-sync-acceptance.md`

### **S108-J — Go/No-Go e uso di TASK-109 (solo backend/polish se BLOCKED)**

Obiettivo: decidere esplicitamente se qualche parte del **perimetro completo** TASK-108 è **PASS**, **PASS_WITH_NOTES**, **PARTIAL** o **BLOCKED**, senza dimenticare le funzioni richieste dall’utente. **`10-task109-split-decision.md`** documenta solo **migration/schema/RPC/RLS** o polish **post-core** quando una wave è **BLOCKED_SCHEMA_OR_POLICY** — **non** sostituisce il contenuto funzionale di TASK-108.

TASK-108 **non** deve chiudere con **PASS** se una di queste aree manca:

- Options/auth/baseline UX coerente;
- bootstrap/full pull sicuro;
- auto pull incrementale launch/foreground;
- push incrementale da Database screen;
- Generated sync parity: local apply + ProductPrice + HistoryEntry + pending cloud;
- History/session sync parity o **BLOCKED_SCHEMA_OR_POLICY** documentato con proposta precisa.

**TASK-109** o successivi possono essere aperti solo per:

- migration/schema/RLS/RPC richiesti da una wave **BLOCKED**;
- Realtime/background worker avanzato;
- performance polish dopo sync core;
- UX polish non bloccante.

**Non** usare TASK-109 per spostare fuori da TASK-108 auto pull, push incrementale, Generated sync o History parity **solo perché sono grandi**.

## File iOS previsti da toccare in futura EXECUTION (elenco dinamico, non ordinato rigido)
Core UI / stato: `OptionsView.swift`, `ContentView.swift`, `GeneratedView.swift`, `HistoryView.swift`, `DatabaseView.swift` (refresh/post-pull e mutazioni che generano pending), localizzazioni `*.lproj/Localizable.strings`.

Nuovo/esteso presenter stato: possibile `CloudSyncOverviewState.swift` / `CloudSyncOverviewReducer.swift` / factory dentro `SupabaseManualSyncReleaseFactory.swift` se si preferisce evitare nuovi file. La scelta va fatta in execution minimizzando churn e rispettando lo stile esistente.

Auth/sync VM: `SupabaseAuthViewModel.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncCoordinator*.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabaseManualSyncSemiAutomaticPolicy.swift`, `SupabaseManualSyncRemotePreview.swift`.

Servizi: `SupabasePullPreviewService.swift`, `SupabasePullApplyService.swift`, `SupabaseInventoryService.swift`, `SupabaseCatalogBaselineReader.swift`/`Writer.swift`, `SupabaseSyncEvent*.swift`, `SyncEventOutbox*.swift`, `SupabaseManualPush*.swift`, `InventorySyncService.swift`, `LocalPending*`, `GeneratedView`/import path `ProductImportViewModel` dove necessario.

**Auto/incremental sync lifecycle:** eventuali file esistenti o nuovi **piccoli** per launch/foreground gate, ad esempio `SupabaseManualSyncLifecycleRunGate.swift`, `CloudSyncAutoPullPolicy.swift` o equivalente da decidere in execution minimizzando churn.

**History/session sync:** `HistoryView.swift`, modelli `HistoryEntry`, servizi `shared_sheet_sessions`/session payload già esistenti se presenti, e test dedicati. **Non inventare schema:** se manca, segnare **BLOCKED_SCHEMA_OR_POLICY**.

Test: harness esistenti `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncLifecycleRunGateTests`, `LocalPendingAggregatedPushPlannerTests`, più **nuovi** test reducer stato P0 Options e test fake per bootstrap signed-in/baseline-absent.

Possibili file documentali/evidence da aggiornare durante execution: `docs/TASKS/EVIDENCE/TASK-108/*`, eventuale runbook manuale in `docs/TASKS/EVIDENCE/TASK-108/operator-sync-runbook.md` se il flow richiede passaggi da operatore.

### Strategia patch consigliata per ridurre regressioni

- **Wave 1** deve preferire **estensione** di presenter/factory esistenti rispetto a **refactor profondo** dei servizi Supabase.
- Se serve un **nuovo file**, preferire un tipo **piccolo e puro** (`CloudSyncOverviewState` / reducer) con **test dedicati**.
- **Non rinominare** modelli/servizi storici durante Wave 1 salvo necessità **dimostrata**.
- **Non cambiare** il comportamento di pull/push esistente mentre si corregge la **card Options** (stesso PR / stessa wave: isolare diff Options + presenter).
- **Localizzazioni**: aggiungere **chiavi nuove** e lasciare compatibili quelle vecchie finché la UI storica non è rimossa dal percorso Release.

---

## File Android letti come riferimento (planning-init)
- `MerchandiseControlSplitView/app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryRepository.kt` (solo prime sezioni + indice comportamenti durante execution delle slice correlate)

Altri file Kotlin (Generated/History/catalog sync) da elencare in Execution quando aggiornato il inventor post-grep nel repo Android.

---

## File Supabase letti come riferimento (planning-init)
Lista migration in `MerchandiseControlSupabase/supabase/migrations/` con prefisso `202604*` e `20260511030000_task101_*.sql` (revoca pubblica EXECUTE helper RLS-aware).

Funzione/tabellafocus: **`sync_events`**, **`record_sync_event`**, grants autenticated/anon (**non** modificare questo task).

---

## Criteri di accettazione (planning-phase `PA-T108`)
- [ ] **PA-T108-01** Il task descrive la causa tecnica più probabile della contraddizione Release vs DEBUG (auth snapshot vs stato `semiAutomaticState` / `failureCategory`) e richiede validazione S108-A0 prima del fix.
- [ ] **PA-T108-02** UX target Opzioni definito con stati, CTA, precedenza e comportamento per permission/RLS/network/baseline absent.
- [ ] **PA-T108-03** Micro-slice **S108-A0…S108-K** (incl. **S108-D1/D2/D3**) **e onde Wave 1…7** con scope, gate **PASS/PARTIAL/BLOCKED**, rischi, stop condition; ordine vincolato (**P0 Options** prima di sync mutativa sistemica).
- [ ] **PA-T108-04** Elenco file iOS/Android/Supabase referenziati senza inventare schema o path non confermati.
- [ ] **PA-T108-05** Decisione UX Generated: target **UX-2** parity Android in **Wave 5** con rollout **E1→E2**; **E1** non costituisce da solo **PASS** globale di parità; hook session **E3** subordinato a esito **S108-C3** (PASS / PASS_WITH_NOTES / **BLOCKED_SCHEMA_OR_POLICY** documentato).
- [ ] **PA-T108-06** Evidence pack previsto con file nominati e senza PASS inventati.
- [ ] **PA-T108-07** Handoff verso review planning / utente presente e valido.
- [ ] **PA-T108-08** Perimetro **funzionale completo** in planning (Options, bootstrap, **auto pull K**, push **D1/D2/D3**, Generated **E**, History **C3**) con **wave piccole** anti-monolite; **TASK-109** solo per **schema/backend/polish** se **BLOCKED_SCHEMA_OR_POLICY**, non contenitore parity.
- [ ] **PA-T108-09** Il piano contiene una specifica UX concreta per Options e Generated, non solo logica sync.
- [ ] **PA-T108-10** Il piano vieta cleanup locali/remoti impliciti e definisce ack/pending come fail-safe.
- [ ] **PA-T108-11** Il piano definisce source of truth e merge policy per catalogo, fornitori/categorie, prezzi, inventario e History.
- [ ] **PA-T108-12** Il piano copre account-switch/local-first/offline senza cancellazioni locali implicite.
- [ ] **PA-T108-13** Il piano definisce delete/tombstone come review-first, non wipe automatico.
- [ ] **PA-T108-14** Il piano definisce Definition of Ready per passare a EXECUTION.
- [ ] **PA-T108-15** Il piano distingue **P0/P1/P2** e impedisce che **P2** blocchi la patch minima Wave 1.
- [ ] **PA-T108-16** Il piano definisce una **tassonomia errori Release** non tecnica e testabile (mapping verso categorie operative).
- [ ] **PA-T108-17** Il piano include un **brief minimo Wave 1** utilizzabile come handoff execution (sezione dedicata + allineamento a evidence `15`/`16`).
- [ ] **PA-T108-18** Il piano include **auto pull incrementale** on app launch/foreground dentro TASK-108 (**S108-K**).
- [ ] **PA-T108-19** Il piano include **push incrementale** da **Database** screen dentro TASK-108 (**S108-D1**).
- [ ] **PA-T108-20** Il piano include **Generated sync parity** dentro TASK-108 (**S108-E**, **S108-D2**).
- [ ] **PA-T108-21** Il piano include **History/session sync parity** dentro TASK-108 (**S108-C3**, **S108-D3**), con **BLOCKED_SCHEMA_OR_POLICY** se schema/policy mancano.
- [ ] **PA-T108-22** Il piano include **bootstrap/full pull** sicuro dentro TASK-108 (**Wave 2**, **S108-C**) e chiarisce il legame con **`03-pull-bootstrap-plan-result.md`** / gate Wave 2 in **`09-wave-gates.md`**.
- [ ] **PA-T108-23** Il piano include **Wave 7 — end-to-end acceptance** (**S108-I**, **`21-end-to-end-sync-acceptance.md`**) e la **tabella di tracciamento wave** sopra (**Implemented / Not implemented yet / Blocked / Evidence**).

## Criteri di accettazione (execution futura — `CA-T108` bozza)
- [ ] **CA-T108-01** Opzioni Release: nessuna UI “Sign in” disabilitata mentre OAuth è valido; errori permesso usano canale `Controlla cloud`.
- [ ] **CA-T108-02** Stato “Connesso ma DB non sincronizzato” mostrato se signed-in e baseline assente o preview vuota coerente.
- [ ] **CA-T108-03** Pull full/incremental operativo con conferme dove richiesto; nessun wipe locale silenzioso.
- [ ] **CA-T108-04** Ogni modifica locale elencata nel brief produce o giustifica assenza di pending/outbox (tabella tracciamento in Execution).
- [ ] **CA-T108-05** Generated/History: post-azione, SwiftData coerente + pending cloud pronto (stesso perimetro Android funzionale).
- [ ] **CA-T108-06** Test: build Debug/Release; XCTest reducer + fake transport pull/push; smoke Opzioni/Database/Generated come da matrice Testing §H pianificazione.
- [ ] **CA-T108-07** Nessun `service_role` client, no bypass RLS, no segreti in log.
- [ ] **CA-T108-08** `CloudSyncOverviewState` o equivalente ha test deterministici per tutti gli stati della matrice UX.
- [ ] **CA-T108-09** Stato signed-in + baseline absent mostra CTA “Scarica database dal cloud” e dopo apply aggiorna Database/Options senza riavvio app.
- [ ] **CA-T108-10** Generated mostra un percorso primario unificato o, se rollout E1, copy temporanea che spiega chiaramente differenza anagrafica/inventario/cloud.
- [ ] **CA-T108-11** History/session sync (**Wave 6**) è **implementato** con test/evidence o è esplicitamente **BLOCKED_SCHEMA_OR_POLICY** con proposta backend **precisa** — **non** ignorato né rimosso dal perimetro TASK-108.
- [ ] **CA-T108-12** Nessun sync mutativo riparte **due volte** solo per combinazione `.onAppear` / `scenePhase` / `onChange` senza **gate/debounce/coalescing** documentato nei path coinvolti.
- [ ] **CA-T108-13** Bootstrap su **SwiftData quasi vuoto** con operatore attentivo richiede **al massimo due tap** (es. conferma dopo anteprima) ed è **recuperabile** se fallisce (retry/messaggi chiari, nessuno stato deadlock).
- [ ] **CA-T108-14** Metriche/UI post-sync distinguono sempre **locale aggiornato**, **cloud già aggiornato quando verificabile** e **pending cloud rimanenti**.
- [ ] **CA-T108-15** Nessun pending locale viene marcato synced/ack se il push remoto è ambiguo, timeout o privo di read-back sufficiente.
- [ ] **CA-T108-16** Sign-out pulisce/aggiorna gli snapshot UI auth senza lasciare card Release o DEBUG in stato signed-in fantasma.
- [ ] **CA-T108-17** La sezione DEBUG è collassata o separata in gruppi diagnostici e non appare come seconda verità sopra la card Release.
- [ ] **CA-T108-18** Ogni wave completata produce verdict **PASS** / **PARTIAL** / **BLOCKED** in `09-wave-gates.md` prima di procedere alla wave successiva.
- [ ] **CA-T108-19** `10-task109-split-decision.md` documenta **solo** cosa serve a sbloccare una wave **BLOCKED_SCHEMA_OR_POLICY** (migration/RPC/policy) o polish **post core** — **non** sostituisce il perimetro funzionale TASK-108.
- [ ] **CA-T108-20** Account-switch/sign-out non invia pending del vecchio owner con la nuova sessione e non cancella dati locali senza conferma.
- [ ] **CA-T108-21** Cursor/watermark incrementale avanza solo dopo apply locale riuscito e documentato.
- [ ] **CA-T108-22** Generated apply evita doppia registrazione prezzi/stock su retry o secondo tap.
- [ ] **CA-T108-23** Delete/tombstone remoto non cancella automaticamente dati locali dirty o collegati a History/Generated; produce review item o skip motivato.
- [ ] **CA-T108-24** La card Options mostra eventuali elementi `Da controllare` in modo user-facing, non solo in DEBUG.
- [ ] **CA-T108-25** **Wave 1** non modifica pull/apply/push/schema e resta limitata a **stato/presenter/Options/test** come da **Brief minimo Wave 1**.
- [ ] **CA-T108-26** Ogni errore sulla **Release** è classificato nella tassonomia `accountRequired` / `accountNeedsCheck` / `cloudPermission` / `networkOffline` / `localNeedsDownload` / `localPending` / `needsReview` / `ready` (o enum equivalente **documentato** in `16-release-error-taxonomy.md`).
- [ ] **CA-T108-27** La card Release mostra **massimo 3 mini-metriche** e non diventa **dashboard tecnica** (RESTO via «Dettagli sincronizzazione» o DEBUG).
- [ ] **CA-T108-28** Auto pull incrementale on launch/foreground funziona con lifecycle gate, cooldown/debounce, owner/account safety e **no wipe** locale.
- [ ] **CA-T108-29** Database screen product/supplier/category/ProductPrice changes producono pending/outbox e push incrementale con ack fail-safe.
- [ ] **CA-T108-30** Generated apply produce local DB update, ProductPrice history, HistoryEntry state e pending cloud **idempotenti**.
- [ ] **CA-T108-31** History screen/session sync push/pull/reconcile funziona con Supabase o è **BLOCKED_SCHEMA_OR_POLICY** con proposta backend precisa; **non** viene ignorata.
- [ ] **CA-T108-32** Verdict finale distingue chiaramente **implemented** vs **not implemented yet** vs **blocked** per **ogni wave** del perimetro completo, con **evidence nominata** (tabella «Tracciamento obbligatorio per wave», più righe **`09-wave-gates.md`** e sintesi **`21-end-to-end-sync-acceptance.md`**) senza dichiarazioni **PASS** inconsistenti coi fatti.

---

## Rischi / regressioni
| ID | Rischio | Mitigazione pianificata |
|----|---------|-------------------------|
| R108-01 | Regressione copy semi-auto TASK-091+ | modifiche chirurgiche + snapshot test VM |
| R108-02 | Cambio semantico `blockedAuth` | rinominare internamente stato o separare **`remoteAuthFailure`** vs **`oauthSignedOut`** |
| R108-03 | Merge dataset grandi su main thread | batch `ModelContext` + misure TASK-089/100 |
| R108-04 | Divergenza ID fornitore/categoria nei pull | enforcing `remoteID` bridge documentato nel SupabasePullApply path |
| R108-05 | Stato “signed-in ma DB vuoto” interpretato come bug invece che bootstrap mancante | card dedicata baseline absent + CTA scarica database |
| R108-06 | Opzioni troppo lunga/rumorosa | DEBUG collassato e card Release compatta |
| R108-07 | Guided Generated apply duplica logica esistente | rollout E1 copy-only, E2 riuso servizi, nessun rewrite |
| R108-08 | History cloud parity confusa con catalog sync | **S108-C3**/**S108-D3** (Wave 6) distinti da catalogo/prezzi; **BLOCKED_SCHEMA_OR_POLICY** se serve schema |
| R108-09 | Full pull su locale dirty sovrascrive dati | stop/confirmation se pending locali o locale non vuoto |
| R108-10 | Sync incrementale lento su dataset grande | batch/paginazione/cancellation S108-H |
| R108-11 | Account-switch usa baseline/pending del vecchio owner | invalidare metriche remote user-scoped e richiedere verifica account |
| R108-12 | Cursor incrementale avanza dopo fetch ma apply fallisce | avanzamento watermark solo post-apply riuscito |
| R108-13 | Generated apply ripetuto registra due volte prezzi/stock | idempotenza/retry guard e stato “già aggiornato” |
| R108-14 | Ambiente locale/dev/live confuso nelle evidenze | environment sanity obbligatorio in checklist Supabase |
| R108-15 | Delete/tombstone remoto elimina dati locali utili | policy review-first e no wipe automatico |
| R108-16 | Conflitti nascosti nel DEBUG non vengono risolti dall’operatore | sezione user-facing `Da controllare` |
| R108-17 | Task passa a execution senza criteri pronti | Definition of Ready obbligatoria |
| R108-18 | Wave 1 diventa refactor Supabase troppo ampio | Strategia patch minima: reducer/presenter + Options + test |
| R108-19 | Troppe metriche rendono Options una dashboard tecnica | Contratto metriche Release e DEBUG collassato |
| R108-20 | Doppio tap o lifecycle trigger duplica mutazioni | OperationID/fingerprint e serializzazione mutativa |
| R108-21 | **P2** / History blocca fix **P0** Options | Priorità **P0/P1/P2** esplicite e **Wave 1 minima** |
| R108-22 | **Failure category** resta ambigua e produce copy sbagliata | **Tassonomia errori Release** + test reducer/evidence |
| R108-23 | **Wave 1** cambia pipeline mutativa e introduce regressioni | **Divieto esplicito** pull/apply/push/schema in Wave 1 (brief + gate) |
| R108-24 | Auto pull foreground sovrascrive locale dirty | condizioni safe + preview/apply solo se no pending bloccanti |
| R108-25 | Push Database non copre supplier/category/prezzi | matrice **S108-D1** obbligatoria |
| R108-26 | Generated aggiorna locale ma non crea pending cloud | **S108-D2** obbligatoria + evidence **Generated** parity |
| R108-27 | History sync resta fuori perché «troppo grande» | dentro TASK-108 come **Wave 6**, al massimo **BLOCKED_SCHEMA_OR_POLICY** |
| R108-28 | Task chiude **PASS** anche se **P1** mancanti | PA/CA aggiornati + **wave gates** completi |

---

## Check finali (Quando questo documento passerà → EXECUTION, dopo approval)
Seguire **`docs/CODEX-EXECUTION-PROTOCOL.md`** se CA richiedono evidenza SIM/formale.

Mini-matrice attesa nella cartella Evidence (solo dopo EXECUTION — **NON** compilare ora con PASS inventati):

| Scenario | STATIC | BUILD | SIM/MANUAL |
|----------|:------:|:-----:|:----------:|
| Signed out OAuth | ✅ | ✅ | Smoke |
| Signed in, baseline absent | ✅ | ✅ | Smoke |
| Signed in, baseline OK + counts | ✅ | ✅ | Smoke |
| OAuth OK, preview permission error | ✅ | ✅ | Smoke CTA permission |
| Pending outbox + drain recorder | ✅ | ✅ | OPTIONAL live gated |
| Post-pull Database empty→populated | | ✅ | Smoke |
| Generated double-action / guided | | ✅ | Smoke |

### Separazione test fake / local / live

| Tipo verifica | Quando usarla | Vietato |
|---------------|---------------|--------|
| Fake transport / reducer tests | Wave 1 e la maggior parte di Wave 2 planning/test | Dipendere da **rete reale** per stati UI base |
| Local SwiftData tests | Apply locale, pending, cursor/watermark | Usare dati reali non redatti |
| Live gated synthetic | Solo se serve provare RLS/RPC/owner su **dev** collegato | Cleanup globale, **service_role** client, dati negozio reali |
| Manual simulator smoke | UX Options/Generated/Dynamic Type | Dichiarare **sync cloud completa** senza read-back / evidence |

Aggiunta policy privacy: scansione segreti / no email raw in log DEBUG release binary.

---

## Stop condition (project-level)
Bloccare execution se emerge necessità **schema/rpc/policy** prima del completamento stato model iOS (**passare fuori task**/nuovo backlog). Bloccare se utente richiede **sync auto full** prima di UX review dichiarazioni TASK-091 policy.

Stop aggiuntivi:
- se il reducer non può distinguere OAuth valido da permission/RLS, non procedere a pull/apply;
- se il locale contiene dati e pending locali non ackati, non fare full apply senza confirmation e preview;
- se `sync_events` RPC live ha limiti incompatibili con payload iOS, non forzare push massivo: aprire follow-up backend;
- se History/session mapping richiede schema nuovo: wave **BLOCKED_SCHEMA_OR_POLICY** **dentro TASK-108** + proposta migration/task backend; **non** rimuovere dal perimetro né dichiarare PASS globale;
- se il flusso OAuth Release e DEBUG risultano diversi, chiudere prima Wave 1 e non procedere a Wave 2.

---

## Decisioni

| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|----------------------|-------------|-------|
| 1 | Nessuna modifica Supabase questo task-phase | migrazioni inline | richiesta stakeholder | **attiva** |
| 2 | Priorità fix P0: distinzione **OAuth OK** vs **`blockedAuth`** state machine prima di refactor pull | refactor massivo subito | minimo churn | **attiva** |
| 3 | Generated: target **UX-2 guided** parity Android in **Wave 5** rollout **E1→E2**; **E1** non basta per **PASS** globale; **E3** subordinato a **S108-C3** | due bottoni principali perpetui | parità funzionale Android richiesta dall’utente | **attiva** |
| 4 | Nessun apply mutativo automatico subito dopo OAuth; mostrare CTA “Scarica database dal cloud” | auto full pull silenzioso post-login | evita wipe/merge inattesi e rende chiaro login ≠ sync | **attiva** |
| 5 | DEBUG deve essere collassato/diagnostico e derivare dalla stessa overview | DEBUG come seconda verità visiva | elimina contraddizione screenshot | **attiva** |
| 6 | History/shared sheet sessions **nel perimetro TASK-108** (**Wave 6**); se schema insufficiente → **BLOCKED_SCHEMA_OR_POLICY** + proposta backend, **non** defer funzionale fuori task solo per dimensione | usare TASK-109 come contenitore della parity History al posto di TASK-108 (**scartato**) | decisione utente scope completo | **attiva** |
| 7 | **EXECUTION CODEX** segue onde **Wave 1…7** (non sprint monolitico sulla lista slice) | ordine alfabetico slice | regressione UX ridotta | **attiva** |
| 8 | Bootstrap pull locale vuoto **mai silenzioso**; UX **≤ ~2 tap operatore** per confermare dopo preview (CA-T108-13 salvo blocker rete) | auto pull post-login | login ≠ implicit sync | **attiva** |
| 9 | Outbox/sync_events **aggregabile/batched** quando **sicuro** e documentato in **Wave 4+** (guardrail volumi/count) | solo push naive | pragmatic performance | **attiva** |
| 10 | **TASK-109** solo per **migration/schema/RLS/RPC/polish** quando una wave è **BLOCKED** o post-core — **non** sostituisce auto/pull/push/Generated/History in TASK-108 | TASK-109 porta parity funzionale | decisione utente | **attiva** |
| 11 | Cleanup dati locali/remoti escluso da TASK-108 salvo evidence scoped separata | usare cleanup per “far passare” sync | protegge dati reali e review | **attiva** |
| 12 | Pending locale resta pending su errore ambiguo o timeout push | optimistic ack | fail-safe cross-device | **attiva** |
| 13 | Database locale resta usabile anche se cloud è offline/errore, salvo apply mutativo attivo | bloccare app dietro cloud | coerenza SwiftData/Room-first | **attiva** |
| 14 | Cursor/watermark avanza solo dopo apply locale completato | avanzare dopo fetch | evita perdita eventi remoti su crash/errore apply | **attiva** |
| 15 | Account-switch non cancella locale e non riusa metriche remote non verificate | wipe o reuse implicito | local-first e sicurezza owner | **attiva** |
| 16 | Generated apply deve essere idempotente o protetto da retry/doppio tap | lasciare doppio apply possibile | evita duplicati ProductPrice/stock | **attiva** |
| 17 | Delete/tombstone remoto è review-first, non wipe automatico | applicare delete remoto direttamente | protegge dati locali e History | **attiva** |
| 18 | Options deve mostrare elementi `Da controllare` come stato user-facing | nascondere conflitti nel DEBUG | operatore può agire senza log tecnici | **attiva** |
| 19 | Definition of Ready obbligatoria prima di EXECUTION | iniziare wave senza gate approvati | riduce rischio di execution monolitica | **attiva** |
| 20 | **Wave 1** deve essere **patch minima** su reducer/presenter/Options/test | refactor Supabase durante fix UX | riduce regressioni e accelera review | **attiva** |
| 21 | **Release** mostra **massimo poche metriche stabili**, non dashboard tecnica | mostrare tutti i dettagli sync sulla card pubblica | UX iOS più chiara | **attiva** |
| 22 | **Mutazioni** serialized/guarded con **operationID** o equivalente | permettere doppio tap / lifecycle mutativo duplicato | evita duplicati e stati corrotti | **attiva** |
| 23 | Distinzione **P0/P1/P2** per non bloccare Wave 1 con parity avanzata | trattare tutti i criteri come bloccanti | accelera fix del bug reale Options | **attiva** |
| 24 | **Tassonomia errori Release** obbligatoria | copy derivata direttamente da errori tecnici grezzi | UX più chiara e testabile | **attiva** |
| 25 | **Brief minimo Wave 1** è il primo handoff execution canonico | prompt execution generico su tutta TASK-108 | riduce rischio mega-PR | **attiva** |
| 26 | Auto pull incrementale launch/foreground incluso in TASK-108 | rinviare auto sync a task separato | richiesto dall’utente per parità Android | **attiva** |
| 27 | Push incrementale da Database incluso in TASK-108 | solo planning/outbox astratto | richiesto dall’utente | **attiva** |
| 28 | Generated sync parity incluso in TASK-108 | solo copy E1 | richiesto dall’utente; E1 non basta per PASS globale | **attiva** |
| 29 | History/session sync parity incluso in TASK-108 | **rimuovere** History/session dal backlog TASK-108 e **delegare tutta la parity** a TASK-109 come contenitore funzionale (**scartato**) | richiesto dall’utente: History resta in TASK-108; **TASK-109/110 solo** migration/schema/RPC/RLS o polish quando **BLOCKED_SCHEMA_OR_POLICY** | **attiva** |
| 30 | **PASS** globale vietato se una wave **P1** è solo **PARTIAL** non bloccata da schema | chiudere con note generiche | evita falso completamento | **attiva** |

---

## Planning (Claude)

### Analisi
Il sintomo “Release chiede Sign in + DEBUG dice connesso + DB vuoto” è spiegabile con **tre concetti non collegati in UI**:
1. **Sessione OAuth** (`SupabaseAuthViewModel`);
2. **Stato processo manual sync / semi-auto** (`SupabaseManualSyncViewModel`, `semiAutomaticState`, `failureCategory`);
3. **Baseline / apply effettivo** (`SupabaseCatalogBaseline*`, `SupabasePullApplyService`).

La card Release filtra l’informazione 1 attraverso uno **snapshot** (`authPresentationContext`) e può sovrapporre stati di errore remoto come “serve sign-in” anche quando 1 è vero, con **CTA disabilitata** per `canSignIn == false`, generando disallineamento percettivo con DEBUG.

### Approccio proposto
1. **Audit riproducibile S108-A0**: prima capire quale Options reale produce gli screenshot e quale catena di stato alimenta Release/DEBUG.
2. **Chiusura P0 semantica**: separare `oauthStatus` da `remoteAccessStatus`, con precedenza chiara auth → permission/RLS → baseline → pending.
3. **Cloud overview unica**: Release card compatta e DEBUG collassato come diagnostica derivata, non seconda fonte.
4. **Bootstrap manuale sicuro**: signed-in + DB vuoto diventa stato esplicito con CTA “Scarica database dal cloud”, non errore di login.
5. **Pull/push progressivi**: riusare servizi esistenti; coordinare **Wave 2** (bootstrap) → **Wave 3** (**S108-K** auto incremental) → **Wave 4–6** (push Database, Generated, History); checklist Supabase pre-mutazione obbligatoria — **no** architettura parallela se evitabile.
6. **Generated + History parity**: **S108-E** / **S108-D2** (**Wave 5**) e **S108-C3** / **S108-D3** (**Wave 6**); **S108-E1** solo step intermedio reviewable; **E3** legato a esito **S108-C3**; **BLOCKED_SCHEMA_OR_POLICY** documentato invece di spostare fuori task.
7. **Wave gate dopo ogni onda (1…7)**: documentare PASS/PARTIAL/BLOCKED (prompt **E** + evidence `09-wave-gates.md` + verdict **CA-T108-32**) prima di proseguire.
8. **Fail-safe pending**: preferire pending visibile e retry a un falso “sync completato”.
9. **Local-first UX**: quando cloud non è disponibile, l’app deve spiegare il problema ma lasciare lavorare sul database locale.
10. **Patch minima Wave 1**: correggere prima il **modello di stato** e la **presentazione Options**, **senza toccare la pipeline mutativa cloud** nel primo PR/scopo Wave 1.
11. **Metriche sobrie**: la **Release card** deve dare **orientamento**, non diventare un pannello tecnico; **DEBUG** resta il posto dei dettagli (coerente con **Contratto metriche Cloud overview**).
12. **Priorità esplicite**: **P0** corregge il bug reale Options; **P1/P2** non devono bloccare la **patch minima** Wave 1.
13. **Tassonomia errori stabile**: la UI Release non deve riflettere errori tecnici grezzi, ma **categorie operative** testabili e mappate dal reducer.

### File da modificare (prima ondata post-approval)
`SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncRemotePreview.swift`, `OptionsView.swift` (Release card binding), `Localizable.strings` (IT/EN/ES/zh-Hans), test VM dedicati; eventualmente `ContentView.swift` se serve condividere presenter.

### Rischi identificati
Vedi tabella R108-xx; aggiungere **complessità cognitive** se troppi stati in un’unica card — mitigare con sotto-sezioni collassabili iOS-native.

### Handoff → Planning review (UTENTE / Reviewer)
- **Prossima fase**: resta **PLANNING** finché l’utente non approva / non richiede revisione sezioni
- **Prossimo agente**: **UTENTE** (approvazione) poi **CLAUDE** (eventuale refine) poi **CODEX** su promozione **EXECUTION**
- **Azione consigliata**: approvare **onde Wave 1…7**, perimetro funzionale completo e checklist Supabase; **Wave 7** come acceptance E2E; compilare quando appropriato la **tabella Tracciamento obbligatorio per wave** (**Implemented / Not implemented yet / Blocked / Evidence**) senza esiti inventati prima di EXECUTION; **TASK-109** solo se **BLOCKED_SCHEMA_OR_POLICY**. Confermare **Generated E1→E2** come rollout interno (**Wave 5**). Usare Prompt estensione **E**, **F**, **R**, **S**, **T**, **U** prima di EXECUTION se i gate wave o alcune slice non sono ancora sufficientemente specifiche.

### Handoff → Execution (solo dopo approval esplicito — NON attivo ora)
- **Prossima fase**: EXECUTION
- **Prossimo agente**: CODEX
- **Azione consigliata**: **Wave 1** (**S108-A0**, **S108-A**, **S108-B**, **S108-B2**) — **PR/commit minimo** solo reducer/presenter + Options Release/DEBUG + test, **senza** pull mutativo né push/schema — poi **Wave 2** bootstrap, **Wave 3** (**S108-K**), quindi Wave 4–7; vietato Wave 2+ mutativo se P0 BLOCKED. Rif. **Brief minimo Wave 1**, **Estensione N**, **Definition of Done del PLANNING** e **Strategia patch consigliata**.

### Brief minimo Wave 1

**Obiettivo Wave 1:** correggere la contraddizione Release/DEBUG e rendere la card Options **affidabile**, **senza** modificare la **pipeline mutativa cloud**.

**Scope Wave 1:**

- leggere e documentare `OptionsView.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseAuthViewModel.swift` e test collegati;
- creare/estendere un **presenter/reducer puro** per `CloudSyncOverviewState` o equivalente;
- mappare `AuthSnapshot`, `RemoteAccessSnapshot`, `BaselineSnapshot`, `PendingSnapshot`, `LastSyncSnapshot` verso la **tassonomia errori Release**;
- aggiornare solo la **UI Options** necessaria a **card Release** + **DEBUG** collassato/coerente;
- aggiungere **test** reducer/presenter e smoke UI simulator/fake state dove possibile;
- produrre `00-audit-options-state.md`, `01-cloud-overview-state-matrix.md`, `02-options-ux-screenshots.md`, `09-wave-gates.md`, `15-wave1-minimal-brief.md`, `16-release-error-taxonomy.md`.

**Vietato in Wave 1:**

- pull/apply **mutativo**;
- push / outbox drain;
- migration / RLS / RPC / schema;
- cleanup dati;
- refactor massivo servizi Supabase;
- dichiarare **database cloud popolato** se non è stato applicato un **pull** (nessun claim fuorviante sulla completezza remota ↔ locale).

---

## Prompt consigliati per estendere il planning in modo coerente

Usare questi prompt solo se si vuole ampliare il planning **senza** passare a execution e **senza** modificare Swift/Kotlin/SQL.

### Estensione A — History/session cloud parity

```text
Estendi TASK-108 restando in PLANNING: leggi i modelli iOS HistoryEntry, i servizi Supabase collegati a shared_sheet_sessions e il riferimento Android History/session sync. Aggiorna S108-C3/S108-D3 con matrice campi, conflitti, pending/outbox e criteri PASS / PASS_WITH_NOTES / BLOCKED_SCHEMA_OR_POLICY, **tutto dentro il perimetro TASK-108**. Non modificare Swift/SQL.
```

### Estensione B — UX copy definitiva Opzioni

```text
Estendi TASK-108 restando in PLANNING: proponi copy finale IT/EN/ES/zh-Hans per tutti gli stati Cloud overview, inclusi signed-out, signed-in baseline absent, permission/RLS, offline, pending push e sync OK. Mantieni tono breve iOS-native. Non modificare Localizable.strings.
```

### Estensione C — Generated guided apply wireframe

```text
Estendi TASK-108 restando in PLANNING: disegna in markdown il flusso UX della sheet “Aggiorna database da questo foglio”, con step, CTA, empty/error/loading state, conferme destructive e criteri accessibilità. Non implementare SwiftUI.
```

### Estensione D — Sync state reducer specification

```text
Estendi TASK-108 restando in PLANNING: definisci la specifica completa di CloudSyncOverviewState con enum, precedenze, input/output, casi test e mapping verso CTA. Non creare codice Swift.
```

### Estensione E — Wave execution gate

```text
Estendi TASK-108 restando in PLANNING: definisci i gate esatti per **Wave 1…Wave 7**, con criteri PASS/PARTIAL/BLOCKED e come documentare **implemented / not yet / blocked** per wave; **TASK-109** solo per proposte schema/backend quando una wave è **BLOCKED_SCHEMA_OR_POLICY**. Non modificare Swift.
```

### Estensione F — Bootstrap pull safety runbook

```text
Estendi TASK-108 restando in PLANNING: crea un runbook operatore per il primo ‘Scarica database dal cloud’, includendo locale vuoto, locale non vuoto, pending locali, errore RLS, offline, rollback/retry e messaggi UX. Non implementare codice.
```

### Estensione G — Options visual specification

```text
Estendi TASK-108 restando in PLANNING: crea una specifica visuale testuale della card “Cloud synchronization” per iOS, includendo layout compatto, Dynamic Type, badge, CTA, metriche, loading/error/empty states e DEBUG collassato. Non modificare SwiftUI.
```

### Estensione H — Pending/outbox fail-safe policy

```text
Estendi TASK-108 restando in PLANNING: definisci la policy completa per pending locali e outbox, includendo quando creare eventi aggregati, quando fare ack, cosa succede su timeout, retry, permission error e read-back mismatch. Non modificare Swift/SQL.
```


### Estensione I — Copy matrix finale multilingua

```text
Estendi TASK-108 restando in PLANNING: crea una matrice copy IT/EN/ES/zh-Hans per Cloud overview e Generated apply, usando termini operatore e separando card Release da DEBUG. Non modificare Localizable.strings.
```

### Estensione J — Merge/conflict policy matrix

```text
Estendi TASK-108 restando in PLANNING: crea una matrice completa di merge/conflict per catalogo, supplier/category, ProductPrice, stock e History, includendo remoteID collision, barcode duplicate, owner mismatch, local dirty vs remote newer e cursor failure. Non modificare Swift/SQL.
```


### Estensione K — Account switch & local-first runbook

```text
Estendi TASK-108 restando in PLANNING: definisci il comportamento per sign-out, sign-in con altro account, locale dirty offline, pending vecchio owner e UI “continua offline”, senza cancellare dati locali. Non implementare codice.
```

### Estensione L — Delete/tombstone review policy

```text
Estendi TASK-108 restando in PLANNING: definisci la policy completa per delete/tombstone remoto e locale, includendo supplier/category replacement, product con ProductPrice/History collegati, local dirty, pending push e UX `Da controllare`. Non modificare Swift/SQL.
```

### Estensione M — Definition of Ready execution checklist

```text
Estendi TASK-108 restando in PLANNING: crea una checklist Definition of Ready dettagliata per autorizzare EXECUTION Wave 1 e bloccare Wave 2/3 finché Supabase pre-mutation, reducer e UX Options non sono approvati. Non implementare codice.
```

### Estensione N — Wave 1 minimal execution brief

```text
Estendi TASK-108 restando in PLANNING: crea un brief dettagliato per la sola Wave 1, limitato a audit Options, reducer/presenter CloudSyncOverviewState, UI Release/DEBUG e test, vietando pull/push/schema. Non implementare codice.
```

### Estensione P — Release error taxonomy test matrix

```text
Estendi TASK-108 restando in PLANNING: crea una matrice test per la tassonomia errori della Release card, includendo input snapshot, categoria attesa, copy/CTA attesa, metriche visibili e cosa resta in DEBUG. Non modificare Swift.
```

### Estensione Q — End-to-end parity acceptance (Wave 7)

```text
Estendi TASK-108 restando in PLANNING: definisci una matrice di acceptance end-to-end che copra Options + auto pull + push Database + Generated + History, con verdict per wave (implemented / not yet / blocked) e criteri PASS / PASS_WITH_NOTES / PARTIAL / BLOCKED allineati a CA-T108-32. Non implementare codice.
```

### Estensione R — Auto incremental pull full spec

```text
Estendi TASK-108 restando in PLANNING: crea la specifica completa per auto pull incrementale on app launch/foreground, includendo lifecycle gate, cooldown, owner/account safety, pending locali, cursor/watermark, UI Options e test/evidence. Non implementare codice.
```

### Estensione S — Database incremental push full spec

```text
Estendi TASK-108 restando in PLANNING: crea la specifica completa per push incrementale da Database screen, coprendo product/supplier/category/ProductPrice, pending/outbox, sync_events, ack/read-back, owner mismatch, retry, drain automatico safe e UX Options. Non implementare codice.
```

### Estensione T — Generated sync parity full spec

```text
Estendi TASK-108 restando in PLANNING: crea la specifica completa per parità Generated vs Android (**Wave 5**), includendo `Aggiorna database da questo foglio`, preview/apply atomico dove possibile, ProductPrice/idempotenza, HistoryEntry stato foglio, pending cloud catalog/prices/history/session, trigger policy safe vs `Database locale aggiornato` + `Cloud in attesa`, e matrice failure/retry coerente con **S108-D2** / **S108-E**. Non implementare codice.
```

### Estensione U — History/session sync parity full spec

```text
Estendi TASK-108 restando in PLANNING: crea la specifica completa per sync History / shared sheet sessions (**Wave 6**) dentro TASK-108, con push/pull/reconcile, payload bounds, conflict policy multi-device, mapping campi SwiftData ↔ remoto, e criteri **PASS / PASS_WITH_NOTES / PARTIAL / BLOCKED_SCHEMA_OR_POLICY** con proposta backend precisa senza rimuovere la feature dal perimetro **TASK-108** (TASK-109 resta solo task schema/backend/polish collegato se serve). Non modificare Swift/SQL.
```

---

## Execution (Codex) ← solo Codex aggiorna questa sezione

### 2026-05-13 — EXECUTION avviata su override esplicito utente

**Override registrato:** il file task e il MASTER-PLAN erano ancora in `PLANNING` / responsabile `CLAUDE`, ma l'utente ha dato istruzione esplicita di procedere con EXECUTION completa end-to-end di TASK-108. Codex procede come executor, senza dichiarare `DONE` e senza inventare PASS: ogni wave viene tracciata come `Implemented`, `Not implemented yet`, `Blocked` ed `Evidence`.

**Audit iniziale eseguito prima delle modifiche:**
- Letti `docs/MASTER-PLAN.md`, questo file task, `docs/CODEX-EXECUTION-PROTOCOL.md`.
- Letti file iOS rilevanti: `OptionsView.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncRemotePreview.swift`, `SupabaseManualSyncCoordinator.swift`, `SupabasePullApplyService.swift`, `LocalPendingChange.swift`, `SyncEventOutboxEnqueueService.swift`, `DatabaseView.swift`, `GeneratedView.swift`, `InventorySyncService.swift`, `HistoryEntry.swift`, servizi Supabase e test manual sync esistenti.
- Letto riferimento Android locale per repository inventory, history/session sync e shared sheet session backup.
- Letto schema Supabase locale: `shared_sheet_sessions` esiste con RLS owner-based; `sync_events` locale supporta `catalog` e `prices`, non espone ancora dominio/event type `history/session`.
- Stato git iniziale documentato in `docs/TASKS/EVIDENCE/TASK-108/06-tests-builds.md`.

**Piano minimo di intervento:**
1. Wave 1: introdurre/integrare reducer/presenter puro `CloudSyncOverviewState`, correggere CTA inerte signed-in, distinguere OAuth/remote/baseline/pending/review, rendere DEBUG secondario/collassato e aggiungere test/localizzazioni.
2. Wave 2: abilitare bootstrap/full pull sicuro quando baseline locale è assente ma preview remota è disponibile, mantenendo guardrail anti-wipe e apply solo su preview valida.
3. Wave 3: usare lifecycle gate esistente per auto check foreground/launch e applicare automaticamente solo preview sicure con baseline valida e zero pending locali.
4. Wave 4: verificare e chiudere le lacune di pending/push Database già presenti, con evidence mutation map.
5. Wave 5: rendere Generated un flusso primario guidato "Aggiorna database da questo foglio", con apply locale, ProductPrice idempotente e pending cloud dove applicabile.
6. Wave 6: implementare solo quanto supportato dallo schema esistente per History/session; marcare `BLOCKED_SCHEMA_OR_POLICY` le parti che richiedono dominio/RPC/policy mancanti.
7. Wave 7: eseguire build/test/smoke/evidence per quanto possibile e consegnare handoff review-ready.

**Wave tracking iniziale:**

| Wave | Implemented | Not implemented yet | Blocked | Evidence |
|------|-------------|---------------------|---------|----------|
| Wave 1 — P0 UX-state Options | In corso | Test/smoke finali | — | `00`, `01`, `02`, `15`, `16` |
| Wave 2 — Bootstrap/full pull | In corso | Evidence runtime | — | `03`, `11` |
| Wave 3 — Auto incremental pull | In corso | Evidence simulator/live | — | `17` |
| Wave 4 — Incremental push Database | Audit in corso | Evidence read-back/live | — | `04`, `18` |
| Wave 5 — Generated sync parity | In corso | Evidence retry/live | — | `05`, `19` |
| Wave 6 — History/session sync parity | Audit schema in corso | iOS wiring completa | Probabile blocker `sync_events` history/session | `20`, `10` |
| Wave 7 — End-to-end acceptance | Non ancora | Build/test/smoke finali | — | `21`, `09` |

### 2026-05-13 — EXECUTION completata per review, con Wave 6 bloccata da schema/RPC

**Modifiche fatte:**
- Aggiunto `CloudSyncOverviewState` come reducer/presenter puro per tassonomia Release (`accountRequired`, `accountNeedsCheck`, `cloudPermission`, `networkOffline`, `localNeedsDownload`, `localPending`, `needsReview`, `ready`) con test unitari.
- Corretto `SupabaseManualSyncViewModel` per non mostrare CTA primaria `Sign in` inerte quando OAuth è signed-in ma il problema è remote access / permission / owner check; root banner e Release card usano `Check cloud`.
- Aggiunto stato Release signed-in + baseline assente con CTA `Scarica database dal cloud`.
- `SupabaseManualSyncCoordinator` permette bootstrap preview con baseline mancante solo quando esiste remote preview provider; il comportamento legacy senza provider resta bloccante.
- `applyStagedLocalChanges()` registra una baseline full-pull dopo apply locale riuscito e segnala l'esito nella summary.
- Auto pull foreground ora può auto-applicare solo preview safe con baseline valida, zero pending locali e apply eligibility già pronta; baseline assente resta manuale.
- Options DEBUG auth diagnostico è collassato in `Developer diagnostics`.
- Generated ha una primaria guidata `Aggiorna database da questo foglio` con sheet di preview; le vecchie azioni restano in disclosure avanzata.
- `InventorySyncService` registra pending locali Product/ProductPrice per Generated quando c'è owner Supabase e rende idempotente il ProductPrice retry a prezzo invariato.
- Aggiornate localizzazioni EN/IT/ES/ZH e test mirati.

**Check eseguiti:**
- ✅ ESEGUITO — Debug simulator build: PASS, warning 0 via XcodeBuildMCP.
- ✅ ESEGUITO — Debug build/run simulator: PASS, warning 0 via XcodeBuildMCP.
- ✅ ESEGUITO — Unit tests mirati manual sync/reducer/coordinator: PASS 123/123.
- ✅ ESEGUITO — Unit test Generated inventory pending/idempotence: PASS 1/1.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — `plutil -lint` su `Localizable.strings` EN/IT/ES/ZH: PASS.
- ✅ ESEGUITO — Privacy scan scoped evidence: PASS, nessun token/email/API key raw.
- ✅ ESEGUITO — Simulator smoke Options reachability: PASS con screenshot `docs/TASKS/EVIDENCE/TASK-108/options-smoke-debug.jpg`.
- ⚠️ NON ESEGUIBILE in questo pass — live Supabase full pull/push/read-back: non eseguito per evitare dati live non redatti e perche' Wave 6 richiede decisione schema/RPC.
- ❌ NON ESEGUITO — physical device, Dynamic Type matrix completa, performance grande dataset.

**Wave tracking finale Codex:**

| Wave | Implemented | Not implemented yet | Blocked | Evidence |
|------|-------------|---------------------|---------|----------|
| Wave 1 — P0 UX-state Options | Reducer, Release CTA/copy, baseline absent CTA, DEBUG collassato, unit/smoke | Authenticated live screenshots, Dynamic Type matrix | — | `00`, `01`, `02`, `14`, `15`, `16` |
| Wave 2 — Bootstrap/full pull | Coordinator bootstrap preview, baseline writer post-apply | Live full pull/apply evidence | — | `03`, `11` |
| Wave 3 — Auto incremental pull | Safe foreground auto-apply gate with valid baseline/zero pending | Dedicated launch/foreground live/sim matrix | — | `17` |
| Wave 4 — Incremental push Database | Existing pending/push architecture preserved and audited | Live read-back/retry/account mismatch matrix | — | `04`, `18` |
| Wave 5 — Generated sync parity | Guided primary flow, local apply, ProductPrice idempotence, product/price pending | Full offline/retry simulator/live matrix; history/session pending | History/session event parity depends on Wave 6 | `05`, `19` |
| Wave 6 — History/session sync parity | Schema audit | Full parity wiring | `BLOCKED_SCHEMA_OR_POLICY`: `sync_events`/RPC and local pending entity contract missing for history/session | `20`, `10` |
| Wave 7 — End-to-end acceptance | Build/test/lint/privacy/limited simulator smoke | Live E2E, physical/Dynamic Type/performance matrix | Wave 6 schema blocker | `21`, `09` |

### Handoff post-execution

**Prossima fase consigliata:** REVIEW (Claude / Reviewer), non DONE.

**Reviewer focus:**
- Confermare se Wave 6 va marcata `BLOCKED_SCHEMA_OR_POLICY` a livello task o se l'utente vuole autorizzare una migration/RPC separata.
- Verificare che la nuova semantica signed-in + remote auth failure = `accountNeedsCheck` sia accettata come replacement intenzionale dei vecchi test che chiedevano `Sign in`.
- Decidere se richiedere un FIX per live Supabase E2E prima della review finale, oppure accettare review con blocker schema e live matrix non eseguita.
- Non dichiarare PASS globale / DONE: TASK-108 resta ACTIVE.

---

## Review (Claude) ← solo Claude aggiorna questa sezione
*(Vuoto — non avviato.)*

---

## Fix (Codex) ← solo Codex aggiorna questa sezione
### 2026-05-13 — FIX/COMPLETION end-to-end completato

**Override registrato:** l'utente ha richiesto di completare TASK-108 in FIX, includendo test, Supabase live/dev se possibile, Android parity smoke e possibilita' di migration/RLS/RPC scoped. Codex ha mantenuto TASK-108 **NON DONE** e non ha dichiarato PASS live dove mancava evidence.

**Audit/preflight FIX:**
- Branch: `main`; HEAD iniziale FIX `27aa4a588430c07871aa02ea3cb7b7abf7821101`.
- iOS: simulatore `iPhone 17 Pro` configurato via XcodeBuildMCP; un iPhone fisico rilevato ma non usato per build/install per limiti di signing/sessione.
- Android: device fisico OnePlus8 rilevato; `assembleDebug` e launch smoke eseguiti.
- Supabase: CLI `2.98.2`; Docker locale non disponibile, remote linked project letto in modalita' schema/RLS read-only; nessun dato live creato/modificato/eliminato.

**Fix applicati durante completion:**
- Implementata sync History/session iOS su `shared_sheet_sessions` con `HistorySessionSyncService`, payload v2 compatibile Android, bridge `remoteID`, fingerprint SHA-256, push/pull owner-scoped, read-back verification, skip locale dirty e pending ack sicuro.
- Aggiunta UI History "Cronologia cloud" con azioni `Invia` / `Scarica`, stati signed-out/busy/result, e supporto a restore entry remote anche quando la lista locale e' vuota.
- Esteso `LocalPendingChange` con entity kind `historySession`, origin `historySessionSave`, conteggio pending History e inclusione nel pending aggregato Options.
- Esteso `GeneratedView` e `EntryInfoEditor` per marcare pending History/session quando il foglio, titolo, supplier/category o stato applicato cambiano.
- Esteso `SupabaseInventoryService` con upsert/fetch paginato `shared_sheet_sessions`, senza service role e con owner check fail-closed.
- Rifinita Wave 1: copy Release senza jargon vietato, committer dedicato `SupabaseManualSyncBaselineCommitter` per mantenere il boundary del ViewModel, localizzazioni aggiornate EN/IT/ES/ZH.
- Aggiunti test `HistorySessionSyncServiceTests`, coverage pending History in snapshot provider e fix regressioni sui test Release/Options.

**Wave tracking FIX/COMPLETION:**

| Wave | Implemented | Fixed during completion | Not implemented yet | Blocked | Evidence |
|------|-------------|-------------------------|---------------------|---------|----------|
| Wave 1 — P0 UX-state Options | Reducer/presenter, CTA/copy Release, DEBUG diagnostico, localizzazioni, unit/smoke | Copy baseline checkpoint senza jargon; boundary baseline committer | Authenticated live state screenshots completi | — | `00`, `01`, `02`, `14`, `15`, `16`, `06` |
| Wave 2 — Bootstrap/full pull | Preview/apply/baseline writer/readback locali, guardrail no-wipe | Boundary committer e test regressivi | Live app-auth full pull scoped | — | `03`, `11`, `06`, `09` |
| Wave 3 — Auto incremental pull | Lifecycle gate/cooldown tests e foreground smoke signed-out | Nessun doppio trigger osservato nello smoke; suite TASK-091/092 passata | Live signed-in incremental pull scoped | — | `17`, `08`, `06` |
| Wave 4 — Incremental push Database | Pending/push catalogo/prezzi esistente, read-back contract testato da suite, Options pending aggregato | History pending escluso dal catalog planner e gestito da History service | Live app-auth Database push/read-back scoped | — | `04`, `18`, `06` |
| Wave 5 — Generated sync parity | Guided apply, ProductPrice idempotente, stock/HistoryEntry locale, pending catalog/prices | Pending History/session da Generated e retry idempotence test | Live Generated push/read-back scoped | — | `05`, `19`, `06` |
| Wave 6 — History/session sync parity | Push/pull/reconcile core via `shared_sheet_sessions`, restore remoto, dirty-skip, pending/ack, owner safety | Schema audit ha mostrato che la tabella esistente basta per core Android-style direct sync; implementato senza migration | `sync_events` domain history/session, remote export flag e remote tombstone semantics restano follow-up backend/policy | — | `20`, `10`, `06`, `21` |
| Wave 7 — End-to-end acceptance | Full XCTest, Debug/Release builds, lint, privacy scan, simulator smoke, Dynamic Type basic, Android assemble/smoke | Wave gates e evidence aggiornati | Live Supabase E2E app-auth, physical iOS install, large gated live/perf matrix | — | `21`, `09`, `06`, `07`, `08` |

**Check eseguiti:**
- ✅ ESEGUITO — Full XCTest iOS simulator: PASS **659 passed / 0 failed / 21 skipped**, xcresult `test_sim_2026-05-13T23-57-03-199Z_pid92627_60a54ead.xcresult`.
- ✅ ESEGUITO — TASK-108 targeted tests: PASS **26/0** (`HistorySessionSyncServiceTests`, `SupabaseManualSyncLocalPendingSnapshotProviderTests`, `CloudSyncOverviewStateTests`, `InventorySyncServiceTests`).
- ✅ ESEGUITO — Debug simulator build: PASS, warning 0 via XcodeBuildMCP.
- ✅ ESEGUITO — Release simulator build: PASS via `xcodebuild`; warning benigno AppIntents metadata skipped per assenza AppIntents.framework.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — `plutil -lint` EN/IT/ES/ZH: PASS.
- ✅ ESEGUITO — privacy/secret scan scoped: PASS; match solo sanitizer/config guard esistenti.
- ✅ ESEGUITO — simulator smoke Options/History/Dynamic Type XXXL/foreground relaunch: PASS; screenshot in `docs/TASKS/EVIDENCE/TASK-108/screenshots/`.
- ✅ ESEGUITO — Android `assembleDebug`: PASS; Android launch smoke su device fisico: PASS.
- ⚠️ NON ESEGUIBILE — Supabase locale Docker: daemon non disponibile su socket Docker utente.
- ❌ NON ESEGUITO — live Supabase app-auth E2E scoped: manca una sessione utente autenticata nell'app/simulatore; nessun token o service_role e' stato usato come workaround.
- ❌ NON ESEGUITO — physical iOS install/smoke: device rilevato ma non usato per signing/install in questo pass.

**Dati Supabase e backend:**
- Nessuna migration/RLS/RPC applicata.
- Nessun dato Supabase test creato, modificato o eliminato.
- Remote schema/RLS letto in modalita' read-only: `shared_sheet_sessions` ha policy owner-scoped; `sync_events` resta catalog/prices-only.

**Rischi residui / review notes:**
- Il live E2E con login reale resta la principale lacuna di evidence; serve una sessione app autenticata o un ambiente dev locale avviato.
- `sync_events` non ha dominio history/session; non blocca il core direct table sync stile Android, ma limita cursor/event telemetry per History come follow-up backend.
- Remote delete/tombstone ed export flag delle sessioni non sono parte del payload Android v2 osservato; restano policy/backend follow-up, non wipe automatico.
- Large dataset live/performance e physical iOS device restano NOT RUN.

### Handoff post-fix

**Prossima fase consigliata:** REVIEW (Claude / Reviewer), **non DONE**.

**Verdict tecnico proposto storico:** superato dai FIX live successivi; non usare come verdict corrente. Il verdict corrente resta `REVIEW_READY_WITH_BLOCKERS / PARTIAL_LIVE`.

**Reviewer focus:**
- Validare che Wave 6 core direct sync via `shared_sheet_sessions` sia sufficiente per "come Android" nel perimetro TASK-108.
- Decidere se richiedere un ulteriore FIX solo per live app-auth E2E prima dell'accettazione utente.
- Verificare screenshot/evidence e confermare che le note backend (`sync_events` history/session, export flag, tombstone remoto) siano follow-up non bloccanti.

### 2026-05-13 — FIX mirato Options cleanup + app-auth smoke

**Override/contesto utente:** l'utente ha richiesto un FIX mirato perché la schermata Options risultava ancora troppo tecnica, con sezioni manual/debug visibili come contenuto primario, e perché live Supabase app-auth pull/push non era stato eseguito. Codex mantiene TASK-108 **ACTIVE / FIX**, **NON DONE**, e non dichiara PASS live per le parti rimaste non testate.

**Audit riprodotto:**
- Screenshot before: `docs/TASKS/EVIDENCE/TASK-108/screenshots/2026-05-13-options-before-cloud-account.jpg`, `docs/TASKS/EVIDENCE/TASK-108/screenshots/2026-05-13-options-before-diagnostics-sprawl.jpg`.
- Prima del fix erano visibili come sezioni primarie: accesso raw Supabase, Developer diagnostics, Advanced, Manual price history push, Outbox sync_events, Local Supabase baseline, Recent sync events e local preflight/manual tools.
- Stato simulatore: signed-out, DB locale vuoto, nessuna sessione app-auth Supabase disponibile.

**Fix applicati:**
- `OptionsView` riorganizzata in superficie pubblica: Theme, Language, Cloud account & synchronization, Local database status, Advanced diagnostics collassata.
- Aggiunta card pubblica account cloud con `Accedi` signed-out e `Esci` signed-in; signed-out non mostra piu' "Check not completed" come stato principale.
- Aggiunta sezione pubblica stato DB locale con conteggi prodotti/fornitori/categorie/storico prezzi, pending locali e ultimo pull baseline quando presente.
- Spostati sotto un'unica `Developer diagnostics` collassata: raw Supabase access, preview debug, ProductPrice manual push, Outbox sync_events, Local Supabase baseline, Recent sync events e push preflight/manual tools.
- Aggiornate localizzazioni EN/IT/ES/ZH per le nuove sezioni pubbliche.

**Smoke/evidence:**
- Options after cleanup PASS: `22-options-cleanup-audit.md`.
- Sign-in app-auth smoke PARTIAL: ASWebAuthenticationSession e Google login prompt raggiunti; credenziali/test-account non disponibili a Codex. Evidence: `23-app-auth-login-options-smoke.md`.
- Live bootstrap/full pull NOT RUN / BLOCKED_APP_AUTH: `24-live-bootstrap-pull-smoke.md`.
- Live incremental pull NOT RUN / BLOCKED_APP_AUTH: `25-live-incremental-pull-smoke.md`.
- Live Database push NOT RUN / BLOCKED_APP_AUTH: `26-live-database-push-smoke.md`.
- Live Generated sync NOT RUN / BLOCKED_APP_AUTH: `27-live-generated-sync-smoke.md`.
- Live History/session sync NOT RUN / BLOCKED_APP_AUTH: `28-live-history-session-smoke.md`.
- Live cleanup NOT NEEDED: `29-live-test-data-cleanup.md`.

**Check eseguiti nel FIX mirato:**
- ✅ ESEGUITO — Debug simulator build/run: PASS, warning 0.
- ✅ ESEGUITO — Release simulator build: PASS.
- ✅ ESEGUITO — TASK-108 targeted XCTest: PASS, 172 passed / 0 failed.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — `plutil -lint` Localizable EN/IT/ES/ZH: PASS.
- ✅ ESEGUITO — Options simulator smoke signed-out + Dynamic Type extra-extra-large: PASS, screenshot in evidence.
- ✅ ESEGUITO — Database, Generated/Inventory, History signed-out simulator smokes: PASS.
- ✅ ESEGUITO — Android reference `assembleDebug`: PASS con warning AGP/Kotlin preesistenti.
- ✅ ESEGUITO — Privacy/secret scan: PASS; nessun token/JWT/API key/email raw aggiunto.
- ⚠️ NON ESEGUIBILE — live Supabase app-auth pull/push/read-back: OAuth arriva al prompt Google, ma serve completamento umano/test-account.
- ⚠️ NON ESEGUIBILE — Supabase locale Docker: daemon non disponibile.
- ❌ NON ESEGUITO — iOS physical device smoke in questo FIX mirato.

**Wave tracking del FIX mirato:**

| Wave | Implemented | Fixed during cleanup | Not implemented yet | Blocked | Evidence |
|------|-------------|----------------------|---------------------|---------|----------|
| Wave 1 | Reducer/presenter e Release state gia' presenti | Options pulita, Sign in/Sign out surface ripristinata, diagnostics collassata, local DB status pubblico | Signed-in/sign-out screenshot matrix completa | App-auth completion richiede credenziali | `22`, `23`, `06` |
| Wave 2 | Bootstrap/full pull code presente | DB locale vuoto/baseline assente ora visibile all'utente | Live full pull/apply | `BLOCKED_APP_AUTH` | `24`, `03`, `06` |
| Wave 3 | Auto pull code/test presenti | Nessun trigger UI/lifecycle aggiunto | Live signed-in incremental pull | `BLOCKED_APP_AUTH` | `25`, `17`, `06` |
| Wave 4 | Database push code/test presenti | Options pending pubblico preservato | Live push/read-back | `BLOCKED_APP_AUTH` | `26`, `18`, `04`, `06` |
| Wave 5 | Generated sync code/test presenti | Tab Generated/Inventory smoke stabile | Live Generated push/read-back | `BLOCKED_APP_AUTH` | `27`, `19`, `05`, `06` |
| Wave 6 | History/session code/test presenti | History signed-out smoke stabile | Live History/session push/read-back | `BLOCKED_APP_AUTH` | `28`, `20`, `06` |
| Wave 7 | Build/test/smoke/privacy/Android assemble eseguiti | Evidence aggiornata senza PASS live inventati | Live app-auth E2E, iOS physical smoke | `BLOCKED_APP_AUTH` / NOT RUN | `21`, `22`-`29`, `06`, `07`, `08`, `09` |

### Handoff post-fix mirato

**Prossima fase consigliata:** restare **ACTIVE / FIX** finche' un utente/test-account completa OAuth app-auth e permette il live sync matrix; in alternativa reviewer/utente puo' accettare `BLOCKED_APP_AUTH` come blocker esterno e spostare a REVIEW con note.

**Non dichiarare DONE.**

**Serve per sbloccare live sync:**
- sessione app-auth Supabase completata nel simulatore o su device;
- oppure credenziali di test / intervento umano per completare Google OAuth;
- poi rerun live scoped per bootstrap pull, incremental pull, Database push, Generated sync e History/session sync.

### 2026-05-13 — FIX large ProductPrice bootstrap pagination

**Override/contesto utente:** l'utente ha interrotto esplicitamente la strategia di aumentare limiti fissi ProductPrice (`5.000 → 25.000 → 100.000`) e ha richiesto un bootstrap/full pull paginato, completo, cancellabile e progressivo. Codex mantiene TASK-108 **ACTIVE / FIX**, **NON DONE**, e non dichiara PASS completo finche' baseline e rerun app-auth non sono verificati.

**Fix applicati:**
- Sostituito il concetto di limite totale ProductPrice nel preview Release con `productPricePreviewSampleLimit`: il preview campiona 1.000 righe per segnali/blocker e non fallisce solo per storico remoto grande.
- Aggiunto warning non bloccante `priceHistoryPagedApplyRequired`.
- Implementato `SupabaseProductPriceApplyService.applyPagedFullPull(...)`: download ProductPrice in pagine da 1.000, progress callback, cancellazione tra pagine, save SwiftData per pagina e idempotenza su retry.
- Aggiunto `fetchProductPriceCount()` su `SupabaseInventoryService` per progress con totale quando Supabase lo restituisce.
- Aggiornata UI/VM: progress messaggi `Preparazione download`, `Scaricamento prodotti`, `Scaricamento storico prezzi`, `Applicazione database locale`, conteggio ProductPrice, cancel/retry via review sheet.
- Corretto `SupabaseCatalogBaselineWriter`: baseline records scritti in batch da 1.000 e verifica con `fetchCount`, evitando un unico save enorme dopo dataset grande.
- Migliorata CTA Options: quando baseline assente e review/apply e' safe, il bottone pubblico resta funzionalmente review/confirm ma mostra `Scarica database dal cloud` invece di `Rivedi`.

**Live app-auth osservato:**
- Dopo login manuale completato dall'utente, preview autenticato ha letto 19.888 prodotti / 101 fornitori / 64 categorie e sample ProductPrice 1.000, senza source error e senza partial.
- Apply locale avviato da review sheet: store locale osservato con 19.886 prodotti, 79 fornitori, 47 categorie e 53.022 ProductPrice.
- Duplicati ProductPrice logici locali (`product`, `type`, `effective_at`): 0 gruppi.
- Nessun dato Supabase creato/modificato/eliminato.

**Limite del live:**
- Baseline non risultava scritta dopo il primo run live (`0` baseline run / `0` baseline record).
- Il writer baseline e' stato fixato e testato dopo quell'osservazione.
- Fresh rerun app-auth dopo rebuild non e' stato completato: la sessione e' tornata al flusso OAuth/Google credential, quindi baseline live con writer fixato resta **NOT RUN / BLOCKED_APP_AUTH**.

**Check eseguiti nel FIX large-history:**
- ✅ ESEGUITO — Debug simulator build: PASS, warning 0.
- ✅ ESEGUITO — Release simulator build: PASS.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — `plutil -lint` Localizable EN/IT/ES/ZH: PASS.
- ✅ ESEGUITO — ProductPrice large-history targeted XCTest: PASS by exit code.
- ✅ ESEGUITO — Baseline batch writer targeted XCTest: PASS by exit code.
- ✅ ESEGUITO — Baseline-absent CTA copy targeted XCTest: PASS by exit code.
- ✅ ESEGUITO — Privacy/secret scan: PASS con soli match documentali/defensive code gia' noti.
- ⚠️ NON ESEGUIBILE — Fresh live full bootstrap + baseline valid con writer fixato: serve completamento OAuth umano/test-account.
- ❌ NON ESEGUITO — iOS physical smoke: device fisico rilevato offline.

**Wave tracking large-history:**

| Wave | Implemented | Fixed during large-history pass | Not implemented yet | Blocked | Evidence |
|------|-------------|----------------------------------|---------------------|---------|----------|
| Wave 1 | Options reducer/presenter e public surface | CTA baseline-absent ora dice `Scarica database dal cloud` | Fresh signed-in screenshot dopo rebuild | App-auth needed | `30`, `06` |
| Wave 2 | Bootstrap preview/apply | ProductPrice cap totale rimosso; full apply paginato; baseline writer batched | Fresh live baseline valid dopo rerun | `BLOCKED_APP_AUTH` | `03`, `24`, `30`, `06` |
| Wave 3 | Auto pull code/tests | Nessun cambio | Live signed-in incremental pull | `BLOCKED_APP_AUTH` | `17`, `06` |
| Wave 4 | Database push code/tests | Nessun cambio | Live push/read-back | `BLOCKED_APP_AUTH` | `18`, `06` |
| Wave 5 | Generated sync code/tests | Nessun cambio | Live Generated push/read-back | `BLOCKED_APP_AUTH` | `19`, `06` |
| Wave 6 | History/session code/tests | Nessun cambio | Live History/session push/read-back | `BLOCKED_APP_AUTH` | `20`, `06` |
| Wave 7 | Build/test/privacy | Large-history code/test + partial live evidence | Fresh app-auth E2E baseline valid | `BLOCKED_APP_AUTH` | `21`, `30`, `06`, `07`, `09` |

### Handoff post-fix large-history

**Prossima fase consigliata:** restare **ACTIVE / FIX** per il solo blocker app-auth/baseline live, oppure spostare a REVIEW se reviewer/utente accetta `BLOCKED_APP_AUTH` come blocker esterno temporaneo. **Non DONE**.

**Serve per chiudere Wave 2 live:**
- completare di nuovo app-auth nel simulatore/device;
- eseguire `Scarica database dal cloud`;
- verificare local ProductPrice count, baseline run valid e Database tab non vuota dopo completamento;
- poi procedere con incremental pull/push live.

### 2026-05-13 — FIX/PARITY progress + Android alignment

**Contesto utente:** l'utente ha richiesto un pass completo concentrato su confronto reale Android, progress UI dettagliata, riduzione freeze MainActor, una singola azione pubblica `Sincronizza ora`, inclusione catalogo/prezzi/history/pending nello stesso flusso, test iOS/Android e cross-platform. Codex mantiene TASK-108 **ACTIVE**, **NON DONE** e non dichiara PASS live app-auth/cross-platform.

**Preflight FIX/PARITY:**
- iOS branch: `main`; Android branch: `main`.
- iOS simulatore usato: `iPhone 15 Pro Max` iOS 26.1 (`459C668B-7CE8-443B-BAB3-7D3D5FFC9143`).
- Android device usato: OnePlus IN2013 (`8ac48ff0`).
- Supabase repo letto in modalita' read-only; nessuna migration/RLS/RPC, nessun dato live creato/modificato/eliminato.
- App-auth iOS/Android: non disponibile in questo pass; nessun token, `service_role` o bypass RLS usato.

**Confronto Android reale:**
- Android ha gia' un modello migliore di progress: `CatalogSyncProgressState` + `CatalogSyncStage`, fasi `REALIGN`, push supplier/category/product, pull catalog, push/pull prices, drain `sync_events`, sync history, `COMPLETED`.
- Android logga `sync_start`, `sync_stage`, `sync_finish` e usa `Dispatchers.IO` per il repository.
- Android full refresh include catalogo, prezzi e History/session; il difetto rispetto al nuovo requisito era la presenza di due azioni pubbliche cloud (quick/full).
- Evidence: `docs/TASKS/EVIDENCE/TASK-108/31-android-sync-progress-parity-audit.md`.

**Fix iOS applicati:**
- Aggiunto modello strutturato `CloudSyncProgressState` / phase/domain con `current`, `total`, percentuale calcolabile, messaggi, `startedAt`, `lastUpdatedAt`, `canCancel`, `isBlockingApply`, `allowsLocalWork`.
- Root banner mostra fase reale durante check/sync (`Checking for updates...`, `Fetching cloud counts...`) e rimane navigabile.
- Options e review sheet mostrano progress dettagliato; la CTA pubblica e' unificata su `Sync now` anche nello stato review/bootstrap.
- `SupabasePullApplyService` ha ora `applyBatched(...)` con progress per supplier/category/product/saving e `Task.yield()` tra batch.
- `SupabaseProductPriceApplyService.applyPagedFullPull(...)` mantiene paging bounded e ora yielda dopo page save/no-op page.
- `HistorySessionSyncService` espone progress push/pull/apply/save e applica batch con yield.
- `SupabaseManualSyncViewModel` orchestri catalog apply, ProductPrice paged apply e History/session push/pull nella stessa apply flow, con progress e warning summary.
- `SupabaseManualSyncReleaseFactory` inietta un adapter History/session verso `SupabaseInventoryService`.

**Fix Android applicati:**
- In `OptionsScreen.kt` rimossa la seconda azione pubblica quick sync dalla cloud card.
- `NavGraph.kt` riallineato alla nuova firma.
- Aggiunte stringhe `catalog_cloud_sync_now` / content description in `values*`.
- Il codice quick sync resta disponibile internamente per auto/event/retry; non e' piu' un'azione pubblica concorrente.

**MainActor/performance:**
- Nessun loop nuovo enorme su MainActor senza await/yield.
- Le mutazioni SwiftData restano sul context actor esistente, ma sono ora batched/yielding; spostarle su background context richiede refactor separato.
- Smoke simulator: durante `Fetching cloud counts...` lo scroll di Options e' rimasto responsive.
- Evidence: `docs/TASKS/EVIDENCE/TASK-108/32-mainactor-performance-sync-audit.md`.

**Check eseguiti nel FIX/PARITY:**
- ✅ ESEGUITO — iOS Debug build via XcodeBuildMCP: PASS, warning 0.
- ✅ ESEGUITO — iOS Release simulator build: PASS.
- ✅ ESEGUITO — iOS targeted TASK-108 tests: PASS `153/0` su suite catalog apply/ProductPrice/History/ViewModel/reducer, poi PASS `97/0` dopo l'ultimo copy fix.
- ✅ ESEGUITO — iOS `git diff --check`: PASS.
- ✅ ESEGUITO — iOS `plutil -lint` Localizable EN/IT/ES/ZH: PASS.
- ✅ ESEGUITO — iOS simulator smoke root banner + Options progress + scroll + `Sync now`: PASS; screenshots in `docs/TASKS/EVIDENCE/TASK-108/screenshots/`.
- ✅ ESEGUITO — Android `assembleDebug`: PASS con warning Gradle/AGP preesistenti.
- ✅ ESEGUITO — Android `testDebugUnitTest --tests '*CatalogSync*'`: PASS.
- ✅ ESEGUITO — Android `git diff --check`: PASS.
- ✅ ESEGUITO — Android install/launch/smoke su OnePlus: PASS; Options mostra una sola azione `立即同步`.
- ✅ ESEGUITO — Privacy/secret scan scoped: PASS; solo match documentali/defensive code o email fake nei test Android.
- ⚠️ NON ESEGUIBILE — live Supabase app-auth iOS/Android: sessione/test-account non disponibile in questo pass.
- ❌ NON ESEGUITO — cross-platform E2E con dati `TASK108_SYNC_*`: non creati dati per evitare bypass auth; evidence `35`.
- ❌ NON ESEGUITO — iOS physical device smoke: non usato per signing/install in questo pass.

**Wave tracking FIX/PARITY:**

| Wave | Implemented | Fixed during parity pass | Not implemented yet | Blocked | Evidence |
|------|-------------|--------------------------|---------------------|---------|----------|
| Wave 1 | Options public surface, reducer/presenter, banner/review states | CTA pubblica review/bootstrap ora `Sync now`; progress visibile in banner/Options | Authenticated screenshot matrix | App-auth session needed | `31`, `33`, `06` |
| Wave 2 | Bootstrap/full pull code path | ProductPrice/catalog progress integrati nello stato strutturato | Fresh live full pull + baseline valid | `BLOCKED_APP_AUTH` | `32`, `33`, `30`, `06` |
| Wave 3 | Auto foreground check code/tests | Progress checking/fetching visibile e scroll non bloccato nello smoke | Live signed-in incremental pull | `BLOCKED_APP_AUTH` | `32`, `33`, `17`, `06` |
| Wave 4 | Database/pending/outbox push architecture | Progress include sending local changes e draining sync events | Live Database push/read-back | `BLOCKED_APP_AUTH` | `31`, `33`, `35`, `18` |
| Wave 5 | Generated sync code/tests | Progress domain pending/history condiviso nel flusso pubblico | Live Generated push/read-back | `BLOCKED_APP_AUTH` | `31`, `35`, `19` |
| Wave 6 | History/session core sync code/tests | Progress History/session integrato nel flow iOS; Android full refresh gia' include history | Live History/session push/read-back | `BLOCKED_APP_AUTH` | `31`, `32`, `33`, `35`, `20` |
| Wave 7 | iOS build/test/smoke, Android build/test/device smoke | Android public action allineata a singolo `Sync now` | Cross-platform Supabase E2E | `BLOCKED_APP_AUTH` / NOT RUN | `31`-`35`, `06`, `07`, `21` |

### Handoff post-fix parity

**Prossima fase consigliata:** REVIEW (Claude / Reviewer), **non DONE**.

**Verdict tecnico proposto:** `PARTIAL_LIVE / REVIEW_READY_WITH_BLOCKED_APP_AUTH`. Il codice e la UI sono allineati al contratto di progress/unified sync, ma il live Supabase E2E e il cross-platform E2E non sono stati eseguiti e non vanno dichiarati PASS.

**Reviewer focus:**
- Verificare che il modello progress iOS copra le fasi richieste senza introdurre API pubbliche nuove.
- Confermare che la rimozione della quick sync pubblica Android sia il giusto allineamento, lasciando il path interno disponibile.
- Decidere se accettare `BLOCKED_APP_AUTH` come blocker esterno o richiedere un ulteriore FIX con test-account/sessione app-auth.
- Non marcare TASK-108 `DONE`.

### 2026-05-14 — FIX post-TASK-108 History cleanup + live app-auth partial + Android status card

**Override/contesto utente:** l'utente ha richiesto un FIX mirato post-TASK-108 per chiudere incoerenze residue tra UX, sync globale e parity Android/iOS. In particolare: rimuovere i pulsanti pubblici History `Send` / `Download`, verificare che `Sincronizza ora` includa History/session, tentare live app-auth/Supabase/cross-platform, aggiungere su Android una card `Local database status` equivalente a iOS e non mascherare test live non eseguiti dietro `PASS_WITH_NOTES`.

**Obiettivo compreso:**
- Options deve essere l'unico percorso pubblico primario per la sync cloud, tramite `Sincronizza ora`.
- History deve mostrare stato read-only/pending/last sync, non chiedere un send/download separato come azione primaria.
- History/session deve essere parte del flusso globale; se il live non passa, va documentato come blocker, non come PASS.
- Android puo' ricevere un miglioramento UX coerente se iOS ha una superficie migliore.

**File controllati:**
- iOS tracking/evidence: `docs/MASTER-PLAN.md`, questo task, evidence `09`, `17`, `18`, `20`, `21`, `31`...`37`.
- iOS codice: `HistoryView.swift`, `OptionsView.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncReleaseFactory.swift`, `HistorySessionSyncService.swift`, `CloudSyncProgressState.swift`, `CloudSyncOverviewState.swift`, `LocalPendingChange.swift`.
- Android codice: `OptionsScreen.kt`, `CatalogSyncViewModel.kt`, `InventoryRepository.kt`, `ProductPriceDao.kt`, `NavGraph.kt`, string resources, `RealtimeRefreshCoordinatorTest.kt`.
- Supabase locale: repo letto per contesto History/session/RLS; nessuna migration/grant/RLS applicata.

**Piano minimo eseguito:**
1. Pulire la History cloud card iOS rimuovendo le azioni pubbliche separate.
2. Rendere visibili in Options i pending History/session dentro il riepilogo globale.
3. Provare il flusso live app-auth pubblico `Sincronizza ora` senza token/service_role/bypass.
4. Portare su Android la card compatta `Local database status`.
5. Aggiornare evidence e handoff con esiti reali, inclusi blocker.

**Modifiche fatte — iOS:**
- `HistoryView`: rimossi i bottoni pubblici History `Send` / `Download` e le azioni dirette `pushHistorySessions()` / `pullHistorySessions()` dalla superficie primaria; la card History cloud ora e' read-only e mostra stato signed-out/unavailable/pending/last sync/ready con hint verso Options `Sincronizza ora`.
- `LocalPendingChange`: `LocalPendingChangeSnapshotProvider` conta anche `HistoryEntry` dirty senza riga `LocalPendingChange`, cosi' Options non nasconde pending History/session locali.
- Localizzazioni EN/IT/ES/ZH: aggiornata copy History read-only e copy Options/review per non promettere che il cloud resta invariato quando History/session puo' sincronizzare.
- Test: aggiunto caso mirato per dirty History entries riportate come operazioni cloud pending anche senza pending rows.

**Modifiche fatte — Android:**
- `OptionsScreen`: aggiunta card Material3 compatta `Local database status`, senza CTA sync duplicata.
- `CatalogSyncViewModel`: aggiunto stato `LocalDatabaseStatusUiState` e refresh su init/auth/options/sync finish.
- `InventoryRepository` / DAO: aggiunto snapshot counts su `Dispatchers.IO` per prodotti, fornitori, categorie, price history, History sessions, pending locali, last sync/check e account cloud.
- `NavGraph` e localizzazioni `values*`: cablaggio stato e stringhe EN/IT/ES/ZH.
- Test fake Android aggiornato per il nuovo metodo repository.

**Live app-auth iOS:**
- Sessione app-auth disponibile in simulatore con account mascherato; nessun token/JWT/email raw registrato.
- Eseguito percorso pubblico Options `Sincronizza ora` + review/apply.
- Esito parziale: DB locale popolato a 19.886 prodotti, 81 fornitori, 49 categorie, 15.386 ProductPrice, 2 HistoryEntry.
- Esito non passato: baseline records rimasti `0`; due HistoryEntry sono rimaste dirty senza remote id/fingerprint/read-back.
- Verdict live: `PARTIAL / BLOCKED_LIVE`, non PASS.

**Check eseguiti:**
- ✅ ESEGUITO — iOS Debug build/run via XcodeBuildMCP: PASS, warning 0.
- ✅ ESEGUITO — iOS Release simulator build via XcodeBuildMCP: PASS, warning 0.
- ✅ ESEGUITO — iOS targeted TASK-108 tests: PASS, 116 test / 0 failure.
- ✅ ESEGUITO — iOS `git diff --check`: PASS.
- ✅ ESEGUITO — `plutil -lint` Localizable EN/IT/ES/ZH: PASS.
- ✅ ESEGUITO — iOS simulator History smoke: PASS; nessun pulsante pubblico `Send` / `Download`, card read-only visibile.
- ✅ ESEGUITO — iOS simulator Options smoke: PASS; una sola CTA pubblica `Sincronizza ora`, pending History visibile.
- ✅ ESEGUITO — Android `assembleDebug`: PASS con warning Gradle/AGP/Kotlin preesistenti.
- ✅ ESEGUITO — Android targeted tests `*CatalogSync*` + `*RealtimeRefreshCoordinatorTest*`: PASS/up-to-date.
- ✅ ESEGUITO — Android install/launch/Options smoke su OnePlus IN2013: PASS; card `Local database status` visibile in locale cinese.
- ✅ ESEGUITO — Android `git diff --check`: PASS.
- ✅ ESEGUITO — Privacy scan: PASS; nessun service_role client, nessun bypass RLS, nessun token/JWT/email raw aggiunto.
- ⚠️ NON ESEGUIBILE — Supabase locale Docker stack: non disponibile in questo pass.
- ❌ NON ESEGUITO — full XCTest iOS post-pass: eseguita suite mirata TASK-108, non full suite.
- ❌ NON ESEGUITO — Dynamic Type post-pass: non rieseguito in questo pass; resta evidence precedente.
- ❌ NON ESEGUITO — iOS physical device smoke.
- ❌ NON ESEGUITO — cross-platform E2E con dati `TASK108_SYNC_*`: Android era signed-out e iOS History/session live non ha completato.
- ❌ NON ESEGUITO — push/pull incrementale reale con read-back Supabase: non eseguito per baseline invalid/History blocker.

**Dati Supabase:**
- Nessuna migration/RLS/RPC/grant applicata.
- Nessun `service_role` usato nel client o nei test.
- Nessun dato `TASK108_SYNC_*` creato, modificato o eliminato.
- Il live app-auth ha letto/applicato dati remoti nel DB locale iOS; non c'e' read-back remoto confermato per History/session.

**Rischi residui / blocker:**
- History/session live non passa ancora: le entry locali restano dirty. Possibile blocker su grant/policy DML live di `shared_sheet_sessions` o su baseline/apply completion; serve verifica Supabase app-auth reale senza bypass.
- Baseline iOS non valida dopo il run live: UI puo' continuare a comunicare database non scaricato anche se i conteggi locali sono popolati.
- Incremental pull/push reali e cross-platform E2E non sono verificati con dati scoped.
- Android card verificata signed-out/device; Android live signed-in sync non eseguita.

**Evidence aggiornata:**
- Nuova `36-history-cloud-card-cleanup.md`.
- Nuova `37-ios-android-sync-performance-comparison.md`.
- Aggiornate `06`, `07`, `09`, `17`, `18`, `20`, `21`, `31`, `33`, `34`, `35`.
- Android `MASTER-PLAN.md` aggiornato con nota cross-repo sulla card `Local database status`.

### Handoff post-fix targeted 2026-05-14

**Prossima fase:** REVIEW (Claude / Reviewer), **non DONE**.

**Verdict tecnico proposto:** `REVIEW_READY_WITH_BLOCKERS / PARTIAL_LIVE`.

**Reviewer focus:**
- Confermare che la pulizia UX History soddisfa la richiesta: nessun `Send` / `Download` pubblico primario, sync centralizzata in Options.
- Investigare il blocker live History/session e baseline: prima ipotesi `shared_sheet_sessions` DML grant/policy live o baseline commit non completato.
- Decidere se serve migration/grant backend separata o ulteriore FIX app dopo diagnosi live.
- Non accettare `PASS_WITH_NOTES` come chiusura funzionale: cross-platform E2E e live push/pull incrementale restano non verificati.
- Non marcare TASK-108 `DONE`.

---

## Chiusura
- [ ] Utente ha confermato il completamento

### Follow-up candidate
- **TASK-109** o successori: **solo** migration/schema/RLS/RPC, polish performance/UX o Realtime/background **dopo** sync core, quando una wave TASK-108 è **BLOCKED_SCHEMA_OR_POLICY** — **non** contenitore delle funzioni parity (auto/pull/push/Generated/History) già dentro TASK-108.
- Modifiche schema Supabase se serving cursor `sync_events` richiede campi aggiuntivi (verificare prima su migration esistenti).
- Realtime / worker background (fuori policy TASK-095 e non necessario per chiusura TASK-108).
- Cleanup dati remoti/locali scoped se emergono fixture o conflitti residui da test; non mischiare con execution funzionale.

### Riepilogo finale
*(Da compilare a chiusura.)*

### Data completamento
—

> **Nota**: i “Prompt consigliati” per estendere il planning sono sopra la sezione **Execution (Codex)**.
