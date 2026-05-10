# TASK-091 — Supabase iOS: sync semi-automatica intelligente e parità Android (MVP iOS-first — handoff review)

## Informazioni generali

- **Task ID:** TASK-091
- **Titolo:** Sync semi-automatica intelligente iOS-first (post TASK-090), verso parità funzionale Android/Supabase senza refactor monolitico
- **File task:** `docs/TASKS/TASK-091-supabase-smart-semi-automatic-sync-ios.md`
- **Stato:** **DONE**
- **Fase attuale:** **Chiusura**
- **Responsabile attuale:** **Nessuno — task chiuso**
- **Data creazione:** 2026-05-09
- **Ultimo aggiornamento:** 2026-05-09 — REVIEW+FIX completata; **DONE / Chiusura — REVIEW PASS**, TASK-092 non aperto

---

## Dipendenze

- **Dipende da:** **TASK-090 DONE / Chiusura — PARTIAL_ACCEPTED** (`docs/TASKS/TASK-090-release-acceptance-cross-platform-ios.md`) — acceptance documentata con residui runtime espliciti; **non** equivale a production-ready globale né al 100%.
- **Sblocca:** definisce il contratto che **TASK-092…TASK-096** consumeranno nella roadmap MASTER-PLAN (*semi-auto intelligente*); **TASK-092 resta non aperto** durante questo handoff e richiede conferma separata dopo review.

---

## Scopo

Implementare una prima versione **reale, progressiva e verificabile** della sync iOS da **manuale guidata** verso una **sync semi-automatica intelligente**, **sicura**, **resource-aware**, **SwiftUI/SwiftData/Supabase-native**, con Android solo **riferimento funzionale**.

Override utente 2026-05-09: il task non resta planning-only; Codex e' autorizzato a implementare il primo MVP tecnico iOS-first e portarlo a **READY FOR REVIEW**, senza marcare **DONE** e senza aprire **TASK-092**.

---

## Contesto (da TASK-090 e residui accettati)

**Chiusura TASK-090:** documentazione/evidenze statiche e test mirati **PASS** su ProductPrice, UI/copy, build/test nel perimetro definito; **nessun claim production-ready globale 100%**.

**Residui accettati in chiusura (baseline incompleta per «tutto verificato live»):**

| Area | Stato residuo | Implicazione per TASK-091 |
|------|----------------|---------------------------|
| Nuovo live `TASK090_*` | PARTIAL / BLOCKED_ENV (gate owner/session/collision/costo-beneficio) | Il planning deve definire **gate minimi** e prefisso evidenza prima di qualunque nuova run mutativa |
| Android runtime «fresh» | SKIPPED / PARTIAL | La matrice parity **non** assume Android sempre disponibile; scenari **PARTIAL/BLOCKED_ENV** ammessi con motivazione |
| Import/export UI manuale round-trip | PARTIAL | Resta fuori dall’automazione invisibile; eventuali suggerimenti semi-auto **non** sostituiscono round-trip documentato |

**Nota:** Il file storico TASK-090 contiene ancora header/placement «ACTIVE / PLANNING» in alcune sezioni archiviate; la **fonte di verità tracking** per la chiusura è **MASTER-PLAN** + decisione review **PARTIAL_ACCEPTED**.

---

## Obiettivo del planning

1. **Inventario repo-grounded** dello stato della sync **manuale** Release (servizi, coordinator/adapter, ViewModel, UI card).
2. **Definizione operativa** di «semi-automatica intelligente» coerente con vincoli TASK-076…082 e roadmap MASTER (*no loop, no polling aggressivo, no full reload*, ecc.).
3. **Micro-slice S91-A…S91-G** abbastanza piccole per future execution **incrementali** (nessun grande refactor).
4. **Gate Go/No-Go** e **CA-T091-xx** misurabili; piano evidenze **privacy-safe**.
5. Allineamento esplicito **Android funzionale → mapping concettuale iOS** (lifecycle, storage, layer UI).

---


## Definizione di «sync semi-automatica intelligente» (perimetro TASK-091)

- **Non** è background sync aggressiva: niente worker perpetuo, niente Realtime obbligatorio, niente polling continuo in questo planning.
- **Non** include mutazione remota **silenziosa**: ogni write Supabase resta dietro **conferma utente** nelle future execution (come oggi per apply/push/drain guidati), salvo decisioni esplicite future documentate e approvate.
- **Suggerimenti** di controllo cloud in momenti **utility-aware** (es. apertura app / `ScenePhase.active`) sono ammessi come **obiettivo di design**, sempre con **cooldown**, **cancel**, **nessuna UI bloccante** per default.
- **Recovery / cancel / retry** devono restare **chiari** e coerenti con `ProgressView`, sheet, `confirmationDialog`, stato cancellabile (`Task` cooperativo).
- **Summary privacy-safe**: aggregati e hash/redazione dove serve; niente dump cliente.
- **Copy veritiera:** niente promessa «tutto sincronizzato» se apply/push/drain non sono stati **effettivamente** verificati nel perimetro scenario.


### Scelte UX decise per la futura execution

Per evitare ambiguità nelle fasi successive, il planning assume queste scelte come default UX/UI:

| Situazione | Decisione UX | Motivazione |
|------------|--------------|-------------|
| L’app torna in foreground e la sessione è valida | Mostrare un suggerimento discreto nella card sync, non una modale immediata | Riduce interruzioni; stile iOS più naturale |
| Ci sono modifiche cloud rilevate | CTA primaria: **Rivedi modifiche**; CTA secondaria: **Ignora ora** | L’utente mantiene controllo prima di apply locale |
| Ci sono modifiche locali non ancora pushate | CTA primaria: **Prepara invio**; conferma mutativa in sheet separata | Nessun push silenzioso |
| Controllo cloud in corso | `ProgressView` inline nella card + pulsante **Annulla** quando tecnicamente possibile | Feedback chiaro senza bloccare l’app |
| Controllo senza cambiamenti | Stato breve e non rumoroso: “Nessuna modifica da rivedere” con timestamp | Evita snackbar ripetitive |
| Errore rete/sessione | Stato recoverable nella card + **Riprova**; niente alert distruttivo se non necessario | UX calma e coerente con Options/Release card |
| Dati potenzialmente stale/conflict | Forzare sheet di review prima di qualunque apply/push | Fail-closed e trasparenza |

Regola UI: in caso di scelta fra più alternative, preferire sempre la soluzione meno invasiva che resta coerente con la card Release esistente: riga/card compatta → sheet di dettaglio → `confirmationDialog` solo per azioni mutative o distruttive.

### Parametri default proposti (solo planning, da confermare in futura execution)

| Parametro | Default planning | Perché |
|-----------|------------------|--------|
| Cooldown foreground check | 30 minuti per sessione/app foreground significativa | Evita chiamate ripetute e rumore UI |
| Anti-reentrancy | 1 solo check semi-auto alla volta | Evita loop `onAppear`/`scenePhase` |
| Check senza sessione valida | Bloccato, mostra stato «Accedi/riconfigura Supabase» solo nella card | Nessuna chiamata inutile o errore rumoroso |
| Preview remota | Read-only, bounded, cancellabile | Sicura e coerente con no-write-silenzioso |
| Risultato «nessuna modifica» | Aggiorna timestamp inline; niente alert/snackbar | Feedback utile ma non invasivo |
| Risultato con modifiche | Staged plan volatile + sheet di review | L’utente decide prima di apply/push |
| Piano staged | Non persistito in modo silenzioso; invalidato su session/owner/baseline/local edit rilevante | Previene applicazioni stale |
| Errori rete | Stato recoverable + Riprova; niente escalation modale salvo perdita dati | UX calma e prevedibile |

Terminologia planning: **«check»** = lettura remota safe; **«review»** = mostra differenze; **«apply/push/drain»** = mutativo e richiede conferma.

### Linee guida UI visuali native iOS (solo planning)

La futura UI semi-auto deve sembrare un’evoluzione naturale della Release card, non una feature separata:

- Usare una **card compatta** con gerarchia chiara: titolo breve, stato sintetico, timestamp ultimo check, una sola CTA primaria.
- Usare `Label`/badge solo per stato e severità; evitare icone decorative inutili.
- Usare `ProgressView` inline durante i check; niente overlay full-screen per letture read-only.
- Usare sheet per review dettagliata e `confirmationDialog` solo per azioni mutative o discard.
- Copy utente: verbi chiari e non tecnici (`Controlla`, `Rivedi`, `Prepara invio`, `Riprova`, `Annulla`).
- Colori: seguire semanticamente lo stile esistente dell’app; non introdurre palette custom.
- Accessibilità: ogni stato deve avere testo leggibile senza affidarsi solo al colore; CTA e badge devono avere label comprensibili anche con VoiceOver.
- Localizzazione futura: tutti i copy qui restano draft; in execution futura vanno spostati in `Localizable.strings` solo quando si autorizza codice/UI.

---

## Stato attuale iOS (inventario read-only sintetico)

*Fonte: lettura mirata documentazione task + file Swift citati in roadmap / factory.*

| Layer | Elementi principali | Ruolo nella sync manuale Release |
|-------|---------------------|-----------------------------------|
| **View** | `OptionsView` → `SupabaseManualSyncReleaseCard` | Card Release, sheet review, conferme (`confirmationDialog`), `ProgressView`, task cancellabili |
| **ViewModel** | `SupabaseManualSyncViewModel` | Stati presentazionali, staging piani volatili, mapping summary non jargon |
| **Coordinator** | `SupabaseManualSyncCoordinator` + `SupabaseManualSyncReleaseDryRunPhaseSimulator` | Orchestrazione fasi; preview remota opzionale (TASK-071 path) |
| **Factory / DI** | `SupabaseManualSyncReleaseFactory` | Wiring Release: `SupabasePullPreviewService`, `SupabaseManualPushService`, `SupabaseInventoryService`, `SyncEventRecording` → adapter catalog push / ProductPrice / registrazione attività |
| **Servizi verticali** | `SupabasePullApplyService`, push catalogo, ProductPrice apply/push path Release, outbox drain Release | Tutti i percorsi mutativi attuali sono **mediati** e **confermati** dall’utente nel flusso guidato |
| **Model** | SwiftData `Product`, `Supplier`, `ProductCategory`, `ProductPrice`, outbox `SyncEventOutboxEntry`, baseline | Cache/source locale; vincoli identity ProductPrice e baseline stale già trattati in TASK-080…088 |

**Oggi:** non esiste auto-pull all’foreground né enqueue push automatico post-edit; coerente con divieti storici TASK-072…082.

---

## Riferimento Android (solo funzionale)

| Concetto Android (tipico) | Analogia iOS pianificata |
|---------------------------|---------------------------|
| WorkManager / worker lunghi | **Non copiare 1:1**. Preferire `ScenePhase` + `Task` foreground, retry manuale in UI; `BackgroundTasks` solo se gate severi in TASK-095 roadmap |
| Room + DAO | SwiftData + `ModelContext`; policy di scrittura **solo** dopo conferma / gate nei layer servizio |
| Repository pattern | Servizi verticali (`PullApply`, `ManualPush`, ProductPrice, outbox) già separati — estendere con **piccole** estensioni piuttosto che nuovo mega-layer |
| Dirty set / outbox | Locale: pending snapshot + outbox esistente; futura semi-auto = **dedupe/coalescing** (TASK-093 roadmap) — fuori da questo task salvo pianificazione |

---

## Riferimento Supabase / schema (solo documentale)

- Tabelle inventory (`inventory_suppliers`, `inventory_categories`, `inventory_products`, `inventory_product_prices`), **RLS owner-scoped**, **`updated_at`** su catalogo post **TASK-086** (trigger additivi; drift history migration documentato come follow-up separato).
- **`sync_events` / `record_sync_event`**: outbox + drain **manuale** Release (TASK-081…) — semi-auto **non** improvvisa drain automatico senza decisione dedicata (TASK-094 roadmap).
- **Nessuna modifica SQL/RLS/migration** nel perimetro TASK-091 planning.

---

## Gap principali (da colmare prima / durante il rollout semi-auto)

1. **Baseline runtime live** post-TASK-090: smoke `TASK090_*` o successor, cicli bidirezionali, import/export UI dove ancora PARTIAL.
2. **Suggerimento sync** senza ingannare l’utente: stati «hai dati da rivedere» vs «controllo completato senza modifiche».
3. **Foreground policy**: quando è lecito fare preview remota leggera; cooldown; anti-reentrancy.
4. **Accumulo modifiche locali** prima di push (ridurre spam RPC) — progettazione solo; execution TASK-093.
5. **Parità percepita Android/iOS** senza porting Kotlin.

---

## Principi di efficienza e manutenibilità

- Non creare un secondo sistema di sync parallelo: la futura semi-auto deve essere una **policy leggera** sopra i servizi Release già esistenti.
- Separare chiaramente:
  - **Policy**: decide se suggerire un check;
  - **Coordinator/service**: esegue preview/apply/push già esistenti;
  - **ViewModel**: espone stato UI e piani staged;
  - **View**: mostra card/sheet/confirmation senza business logic pesante.
- Evitare query full-scan se l’utente non sta chiedendo una review completa: preview bounded, dettaglio lazy, aggregati prima dei dettagli.
- Nessun nuovo stato globale singleton per la semi-auto: preferire dependency injection/factory già usata dal flusso Release.
- Se la scelta è tra più architetture equivalenti, scegliere quella che **tocca meno file Swift** nella futura execution e riusa più test/evidenze TASK-080…090.

---

## Decisioni (D91-xx)

| ID | Decisione | Alternative scartate | Motivazione | Stato |
|----|-----------|----------------------|-------------|--------|
| D91-01 | TASK-091 è **solo planning**; execution solo dopo override esplicito su task/fase successiva | Iniziare subito Swift | Workflow progetto; riduce scope creep | attiva |
| D91-02 | Ogni write remota futura resta **confermata** dall’utente fino a decisione documentata diversa | Auto-push silenzioso | Allinea a TASK-076…082 e roadmap semi-auto prudente | attiva |
| D91-03 | Separazione netta: **S91-F** parity matrix **documentale**; niente patch Kotlin in TASK-091 | Fix Android dentro TASK-091 | Rispetta perimetro iOS-first | attiva |
| D91-04 | Preferire **incrementi** su `SupabaseManualSync*` / factory esistenti rispetto a nuovo orchestratore parallelo | Rewrite orchestratore | Minimo cambiamento; file già grandi → slice piccole | attiva |
| D91-05 | BackgroundTasks **fuori** dal MVP semi-auto in questo planning; rinviato a logica TASK-095 | BGTask obbligatorio subito | Coerenza roadmap MASTER e sicurezza batteria | attiva |
| D91-06 | La futura UI semi-auto estende la **card sync esistente** invece di introdurre una nuova schermata dedicata | Nuova tab principale / schermata separata | Coerenza visiva, minor learning curve, meno navigazione | attiva |
| D91-07 | I suggerimenti semi-auto usano copy orientato all’azione utente: “Rivedi”, “Prepara”, “Riprova”, non gergo tecnico | Copy tecnico tipo RPC/outbox/drain | Utente capisce cosa succede senza conoscere Supabase | attiva |
| D91-08 | In caso di dubbio UX, default: **preview prima, conferma dopo, write mai silenziosa** | Auto-apply o auto-push ottimistico | Migliore sicurezza dati e coerenza con i task precedenti | attiva |

---


## Rischi (R91-xx)

| ID | Rischio | Mitigazione |
|----|---------|-------------|
| R91-01 | Confondere TASK-091 con **implementation** TASK-092 | Gate scritti; «NON READY FOR EXECUTION» ripetuto; MASTER aggiornato solo tracking |
| R91-02 | Scope creep UI redesign | Solo pianificazione UX suggerimenti; stringhe **non** modificate in PLANNING |
| R91-03 | Preview remota troppo frequente → costo / rate limit | Cooldown, backoff, cap righe, cancellazione |
| R91-04 | Regression ProductPrice / baseline stale | Recheck owner/session prima di apply/push; piani volatili invalidati (pattern esistente) |
| R91-05 | Expectation Android 1:1 | Documentare mapping concettuale; esiti PARTIAL ammessi |
| R91-06 | UI semi-auto troppo rumorosa o ansiosa | Cooldown, timestamp ultimo controllo, stato inline non modale |
| R91-07 | Troppe CTA nella card Release | Gerarchia chiara: 1 azione primaria, massimo 1 secondaria, overflow solo se necessario |
| R91-08 | Duplicazione logica tra manual sync e semi-auto | Riutilizzare coordinator/service esistenti; nuove policy leggere sopra i flussi Release |

---

## Micro-slice pianificate

### S91-A — Inventario repo-grounded della sync manuale Release

- Mappa file/responsabilità: coordinator, factory, ViewModel, adapter Release, servizi pull/push/ProductPrice/drain.
- Output atteso:
  - tabella `File / Responsabilità / Mutativo? / UI-facing? / Estendibile per semi-auto?`;
  - elenco extension points sicuri;
  - elenco file da **non** toccare senza motivo.
- Rischio principale: inventario incompleto → mitigation: `git grep` su `SupabaseManualSync`, `ProductPrice`, `SyncEvent`, `outbox`, `ReleaseCard` in futura execution documentale.

### S91-B — Policy trigger semi-automatici **sicuri**

- Eventi candidati: `scenePhase == .active`, primo `onAppear` della card, ritorno da una modifica locale importante, apertura Options/Supabase section.
- Policy default decisa:
  - massimo un controllo suggerito per finestra di cooldown;
  - nessun controllo se esiste già un piano staged non risolto;
  - nessun controllo se sessione/auth/owner non sono chiari;
  - task cancellabile e non bloccante.
- Divieti: trigger su ogni `onChange` campo SwiftData; trigger senza auth/baseline; loop `onAppear → state update → onAppear`.
- Output atteso: tabella trigger `evento / condizione / azione UI / azione remota permessa / no-go`.
- Rischio principale: controlli troppo frequenti → mitigation: cooldown + anti-reentrancy + logging privacy-safe.

### S91-C — UX iOS-native per **suggerimenti** sync

- Pattern scelto: evolvere `SupabaseManualSyncReleaseCard` con una sezione compatta “Suggerimenti sync”.
- Componenti UI preferiti:
  - `Label`/badge discreto per stato;
  - `ProgressView` inline per check in corso;
  - `Button` primaria singola;
  - `Menu` o azione secondaria solo quando serve;
  - sheet di review prima di apply/push;
  - `confirmationDialog` solo per write remoto, apply locale con impatto o discard.
- Stati minimi da progettare: idle, check suggerito, checking, changes found, no changes, blocked auth, stale/conflict, cancelled, error recoverable.
- Anti-pattern: modale full-screen obbligatoria per ogni check; snackbar ripetute; copy tecnico (`RPC`, `outbox`, `drain`) in Release.
- Output atteso: mini state-machine UX + copy draft privacy-safe senza modificare `Localizable.strings` in TASK-091.
- Rischio principale: UI incoerente con il resto dell’app → mitigation: riuso stile card, toolbar/sheet e gerarchia già presenti in Options/Release.

#### Mini state-machine UX proposta

| Stato | UI card | Azione primaria | Azione secondaria | Mutativo? |
|-------|---------|-----------------|-------------------|-----------|
| `idle` | Stato neutro + ultimo check se disponibile | Controlla ora | — | No |
| `suggestedCheck` | Suggerimento discreto «Puoi controllare il cloud» | Controlla modifiche | Ignora ora | No |
| `checking` | `ProgressView` inline | Annulla | — | No |
| `noChanges` | «Nessuna modifica da rivedere» + timestamp | Controlla ora | — | No |
| `changesFound` | Badge/count aggregati | Rivedi modifiche | Ignora ora | No |
| `reviewing` | Sheet con sezioni catalogo/prezzi/outbox | Conferma azione specifica | Annulla | Solo dopo conferma |
| `blockedAuth` | Messaggio non tecnico su Supabase/sessione | Riconfigura / Riprova | — | No |
| `staleOrConflict` | Warning inline + sheet obbligatoria | Rivedi conflitto | Annulla | Bloccato finché non confermato |
| `recoverableError` | Errore breve inline | Riprova | Dettagli | No |

Regola: la card non deve mai mostrare più di una CTA primaria contemporaneamente. Le azioni tecniche o meno frequenti vanno in `Menu`/sheet, non nella card principale.

### S91-D — Preflight, stale e conflict guard (design)

- Riuso concetti TASK-082: baseline stale, owner/session mismatch, fail-closed.
- Definire tre livelli:
  1. **Preview-only safe**: read bounded, nessun write, UI cancellabile.
  2. **Review required**: differenze rilevate, piano staged volatile, utente deve rivedere.
  3. **Confirmation required**: apply locale/push remoto/drain eventi.
- Definire quando invalidare piani staged: cambio sessione, cambio owner, refresh baseline, modifica locale significativa, app relaunch se piano non persistito.
- Output atteso: tabella guard `condizione / livello / messaggio utente / azione consentita / azione bloccata`.
- Rischio principale: piano staged vecchio applicato su dati nuovi → mitigation: invalidazione aggressiva e timestamp visibile.

### S91-E — ProductPrice e catalogo nel flusso semi-auto

- Ordine suggerito: preview catalogo → rilevazione modifiche prezzi → stesso contract TASK-080/TASK-088 identity/dedupe → review unica quando possibile.
- UX default: mostrare ProductPrice come dettaglio espandibile dentro la review, non come flusso separato, salvo casi di errore/conflict.
- Non progettare query costose non bounded; ProductPrice preview deve avere limite, filtro per prodotti interessati o fallback manuale.
- Output atteso: regole di composizione `catalog changes + price changes` e casi `solo prezzi`, `solo catalogo`, `entrambi`, `conflict`.
- Rischio principale: appesantire il check foreground → mitigation: bounded preview, lazy detail, no full history scan.

### S91-F — Cross-platform parity matrix (documentale)

Matrice minima (stato al momento TASK-091 planning — aggiornare solo dopo future evidenze).

| Area | iOS (Release/target) | Android (riferimento funzionale) | Supabase / schema | Nota |
|------|----------------------|-----------------------------------|---------------------|------|
| Auth/session gate prima di mutazioni | Implementato (manual sync) | Equivalente concettuale | RLS `owner_user_id` | Recheck obbligatorio pre-write |
| Preview remota catalogo | `SupabasePullPreviewService` / adapter | Fetch + UI sync | Read inventory tables | Semi-auto: solo bounded/cooldown |
| Apply locale pull | `SupabasePullApplyService` post conferma | Apply Room dopo conferma | Nessuna write da preview sola | Mai apply silenzioso |
| Push catalogo | Manual push + preflight | Repository batch | Upsert inventory | Batching TASK-094 |
| ProductPrice pull/apply/push | Path Release dedicato | Storico + summary | `inventory_product_prices` + unique logico | Identity TASK-088 |
| Outbox + drain attività | Drain Release confermato | Worker/outbox pattern | `record_sync_event` | Non auto-drain nel MVP semi-auto |
| Segnale stale / `updated_at` | Client + trigger TASK-086 | Mapping `remoteUpdatedAt` | Trigger catalogo | drift migration history follow-up |
| Import/export round-trip file | UI Database / export XLSX | Pipeline export/import | N/A file | TASK-090 residuo PARTIAL |

- **Output atteso:**
  - matrice aggiornata con stato `OK / PARTIAL / BLOCKED_ENV / NOT_IN_SCOPE` per ogni area;
  - nota esplicita quando Android è riferimento funzionale ma non runtime verificato;
  - lista di gap che devono diventare **task futuri**, non patch nascoste dentro TASK-091.
- **Rischio principale:** usare la matrice per aprire execution implicita → **mitigation:** ogni gap resta documentale e richiede task/override separato.
- **Mitigation UX:** quando Android ha un flusso più potente ma più tecnico, iOS deve mantenere UX Apple-native e portare solo capacità utente equivalente, non layout 1:1.

### S91-G — Test / evidenze privacy-safe (piano futuro)

- Tipi: STATIC / BUILD / SIM / MANUAL (solo dove task futuro lo richiede).
- Manifest prefisso evidenza: proposta **`TASK091_*`** (collision scan obbligatorio prima di seed/write in execution futura).
- Evidenze UI future: screenshot/test manuale ammessi solo con dati demo redatti; niente barcode/clienti reali.
- Metriche minime da documentare: ultimo check, esito, numero aggregato modifiche, durata approssimativa, cancellation/error reason non sensibile.
- Output atteso: template evidence manifest + checklist privacy-safe.
- Rischio principale: evidenze non riproducibili o troppo sensibili → mitigation: fixture anonime, prefix univoco, log aggregato.

---


## Acceptance criteria (planning) — CA-T091-xx

- **CA-T091-01** — Il documento elenca **tutte** le micro-slice **S91-A…S91-G** con scopo, output atteso e rischio principale.
- **CA-T091-02** — La definizione di «semi-automatica intelligente» è esplicita e **coerente** con divieti (no sync silenziosa remota, no background aggressivo nel MVP).
- **CA-T091-03** — I residui TASK-090 sono riassunti e collegati a **gate** di progetto (non hidden).
- **CA-T091-04** — Esiste una tabella **D91-xx** (≥5 decisioni) e **R91-xx** (≥5 rischi).
- **CA-T091-05** — Esiste una **parity matrix** minima (S91-F) con almeno **8 righe** concettuali.
- **CA-T091-06** — Il piano **non** introduce dipendenze Kotlin/SQL nuove nel task planning.
- **CA-T091-07** — Handoff finale dichiara **READY FOR PLANNING REVIEW**, **NON READY FOR EXECUTION**, **NON DONE**.
- **CA-T091-08** — Separazione chiara: ciò che appartiene a **TASK-091** (baseline + planning) vs **TASK-092…096** (automazione incrementale).
- **CA-T091-09** — Le scelte UX default sono documentate e risolvono i casi ambigui senza chiedere una futura decisione utente su ogni micro-interazione.
- **CA-T091-10** — Ogni micro-slice S91-A…S91-G contiene almeno: output atteso, rischio principale e mitigation.
- **CA-T091-11** — La futura UI semi-auto resta coerente con lo stile esistente: card compatta, sheet di review, `ProgressView`, CTA primaria singola, copy non tecnico.
- **CA-T091-12** — Le tabelle markdown sono strutturalmente valide: numero colonne coerente in Decisioni/Rischi/Parity.
- **CA-T091-13** — Esistono parametri default planning per cooldown, anti-reentrancy, preview read-only, staged plan e gestione errori.
- **CA-T091-14** — Il piano distingue esplicitamente Policy / Coordinator-Service / ViewModel / View per evitare business logic nella UI.

---


## Go / No-Go per **futura** EXECUTION (non ora)

**GO** solo se:

1. Override utente esplicito sul task che riceverà EXECUTION (es. continuazione TASK-091 come execution «solo smoke baseline» **oppure** apertura TASK-092 dopo chiusura planning TASK-091 — decisione utente).
2. Manifest `TASK091_*` o reuse `TASK090_*` con **collision scan** documentato.
3. Auth / session / owner verificabili prima di write.
4. Nessuna ambiguità su cosa è preview-only vs mutativo.
5. TASK-091 review planning completata (Claude) senza CHANGES_REQUIRED bloccanti **oppure** fix documentali applicati.
6. UX state-machine approvata nel planning: nessun nuovo flusso mutativo senza stato review/confirm.
7. È chiaro quali copy sono draft documentali e quali richiederanno `Localizable.strings` in un task futuro.
8. Esiste un inventario file reale aggiornato prima di toccare Swift: nessun file ipotizzato viene modificato senza lettura repo-grounded.
9. La futura execution dichiara in anticipo se userà solo preview read-only o se arriverà a mutazioni apply/push/drain.

**NO-GO** → resta PLANNING; nessun Swift.

---

## Fuori perimetro / anti-scope (TASK-091)

- Patch **Swift**, **Kotlin**, **SQL**, **migration**, **RLS**, **`project.pbxproj`**, **`Localizable.strings`**.
- Write Supabase live, seed/smoke runtime, emulator/simulator obbligatori, cleanup distruttivo.
- **TASK-092…TASK-096** aperti o implementati.
- Timer / BGTask / Realtime / worker / polling continuo **realmente** cablati.
- Claim **DONE**, **READY FOR EXECUTION**, **production-ready 100%**.

---

## Planning (Claude)

### Analisi

L’app ha già una **superficie Release completa** per sync mutativa **guidata** (preview → rivedi → conferma → apply/push/registra attività). Il gap verso la roadmap «semi-auto intelligente» è principalmente **policy temporale** (quando suggerire controlli), **accumulo/batching** (futuro), e **lifecycle iOS** — non mancanza totale di orchestrazione.

### Approccio proposto

Perfezionare le sezioni **S91-A…S91-G** come contratto di design ed execution futura: prima inventario, poi policy trigger, poi UX state-machine, poi guard stale/conflict, poi ProductPrice/catalogo, poi parity matrix, infine evidence plan. La futura implementation dovrà essere piccola e agganciata alla Release card esistente, non una nuova architettura parallela.

### File da modificare (ipotizzati — **nessuna modifica in PLANNING**)

- `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncCoordinator.swift`, `SupabaseManualSyncReleaseFactory.swift`, `OptionsView.swift` (solo elenco candidati futuri).

### Handoff → Planning review (interno)

- **Prossima fase:** PLANNING (review contenuto task da Claude / Planner).
- **Prossimo agente:** Claude / Planner (refinement eventuale).
- **Azione:** Verificare CA-T091-xx; aggiornare MASTER-PLAN solo per tracking quando TASK-091 viene chiuso o messo BLOCKED.
- **Nota integrazione UX:** se durante review emergono alternative equivalenti, scegliere la variante meno invasiva per l’utente, più coerente con la card Release attuale e più sicura sui dati. Non chiedere una nuova decisione utente per dettagli puramente estetici o di microcopy, purché restino nel perimetro planning.

---

## Handoff finale — stato obbligatorio

| Voce | Valore |
|------|--------|
| **TASK-091** | **DONE / Chiusura — REVIEW PASS** |
| **READY FOR REVIEW** | Superato da review conclusa PASS |
| **TASK-091 NON DONE** | No — chiuso su override utente dopo build/test/review PASS |
| **TASK-092** | **Non aperto** |
| **Prossimo responsabile** | Nessuno su TASK-091 |
| **Nota** | Le sezioni planning sopra restano storico/contratto; l'override utente 2026-05-09 ha autorizzato execution tecnica e successiva review/chiusura se build/test PASS. |

---

## Execution (Codex)

### Override operativo

Execution avviata e completata su override esplicito utente del 2026-05-09: TASK-091 non resta planning-only; autorizzata implementation Swift/SwiftUI/SwiftData/Supabase iOS-first, localizzazioni, build e test. Vincoli rispettati: nessuna mutazione remota silenziosa, nessun TASK-092, nessun DONE automatico, Supabase live non usato perché non necessario per validare il MVP.

### Lettura iniziale

- Letti `docs/MASTER-PLAN.md`, questo file task, `docs/CODEX-EXECUTION-PROTOCOL.md`.
- Letti task recenti `TASK-080...TASK-090`, con attenzione a ProductPrice, `updated_at`, smoke/release acceptance, sync manuale Release.
- Letti i file iOS reali della Release sync: card SwiftUI, ViewModel, factory/coordinator, preview/apply/push/manual outbox, ProductPrice e modelli SwiftData.
- Letto progetto Supabase locale prima di qualunque decisione backend: migration/schema/policy per catalogo, ProductPrice, `sync_events`, trigger `updated_at`. Nessuna modifica Supabase applicata.
- Android letto solo come riferimento funzionale concettuale; nessun port Kotlin 1:1.

### Inventario repo-grounded reale

| File | Responsabilità | Mutativo? | UI-facing? | Estendibile per semi-auto? |
|------|----------------|-----------|------------|-----------------------------|
| `iOSMerchandiseControl/OptionsView.swift` | Card Release Supabase, sheet review, CTA, conferme, cancellazione task UI | Sì, solo tramite azioni confermate | Sì | Sì, punto naturale per stato inline/foreground check |
| `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift` | Orchestrazione Release, staged summary, presentazione stato, cancel/retry/apply/push/drain | Sì, solo quando chiamati i metodi confermati | Sì, via presentation state | Sì, policy/state machine agganciata qui |
| `iOSMerchandiseControl/SupabaseManualSyncSemiAutomaticPolicy.swift` | Nuova policy semi-auto: cooldown, anti-reentrancy, auth/owner guard, staged-plan guard | No | No | Sì, layer leggero sopra servizi esistenti |
| `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift` | Factory dipendenze Release/coordinator/service | No diretto | No | Sì, conserva wiring esistente |
| `iOSMerchandiseControl/iOSMerchandiseControlApp.swift` | Wiring servizi Supabase in app | No diretto | No | Sì, bounded preview configurata qui |
| `iOSMerchandiseControl/SupabaseManualSyncRemotePreview.swift` | Snapshot/summary remoti per review | No | No diretto | Sì, base per staged plan read-only |
| `iOSMerchandiseControl/SupabasePullPreviewService.swift` | Preview catalogo/ProductPrice da Supabase | No | No diretto | Sì, ora bounded per foreground check |
| `iOSMerchandiseControl/SupabasePullApplyService.swift` | Apply locale dopo review/conferma | Sì locale | No diretto | Sì, resta mutativo confermato |
| `iOSMerchandiseControl/SupabaseManualPushService.swift` | Manual push catalogo con preflight/read-back | Sì remoto | No diretto | Sì, resta dietro review/confirm |
| `iOSMerchandiseControl/SupabaseProductPricePreviewService.swift` | Preview read-only ProductPrice | No | No diretto | Sì, integrabile/lazy nel flusso review |
| `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift` | Apply locale ProductPrice e identity link | Sì locale | No diretto | Sì, non parte in modo silenzioso |
| `iOSMerchandiseControl/SupabaseProductPriceManualPushService.swift` | Push manuale ProductPrice | Sì remoto | No diretto | Sì, resta confermato |
| `iOSMerchandiseControl/SupabaseSyncEventPreviewService.swift` | Preview outbox/activity | No | No diretto | Sì, solo review/preparazione |
| `iOSMerchandiseControl/SupabaseSyncEventLiveRecorder.swift` / `SupabaseSyncEventRPCTransport.swift` | Drain/record activity verso Supabase | Sì remoto | No diretto | Sì, nessun auto-drain invisibile |
| `iOSMerchandiseControl/SyncEventOutbox*.swift` | Outbox locale e stato drain | Sì locale/remoto quando drenato | No diretto | Sì, conferma obbligatoria mantenuta |
| `iOSMerchandiseControl/Models.swift` | Modelli SwiftData `Product`, `Supplier`, `ProductCategory`, `ProductPrice` | Sì quando i service applicano modifiche | No | Sì, invalidazione basata su baseline/sessione/local edit |

### Piano minimo applicato

1. Aggiungere una policy semi-auto leggera senza creare un sistema parallelo.
2. Estendere `SupabaseManualSyncViewModel` con state-machine, timestamp, staged-plan guard e fallback recoverable.
3. Estendere la card Release esistente in `OptionsView` con stato inline, `ProgressView`, CTA primaria singola, sheet review e `confirmationDialog` per mutazioni/discard.
4. Rendere la preview foreground bounded/cancellabile e mantenere apply/push/drain solo dietro review/confirm.
5. Aggiornare localizzazioni e test mirati, poi build/test completi.

### Modifiche fatte

- Aggiunto `SupabaseManualSyncSemiAutomaticPolicy` con cooldown default 30 minuti, anti-reentrancy, blocco auth/owner/sessione, blocco staged plan non risolto.
- Aggiunta state-machine semi-auto reale: `idle`, `suggestedCheck`, `checking`, `noChanges`, `changesFound`, `reviewing`, `blockedAuth`, `staleOrConflict`, `recoverableError`.
- Aggiunti timestamp ultimo check, suggerimento foreground, check cancellabile, invalidazione staged plan su cambio access/sessione/owner e fallback fail-closed.
- Estesa la card Release esistente: stato inline, `ProgressView`, copy non tecnico, una sola CTA primaria, sheet review, `confirmationDialog` per update/send/activity/discard.
- Configurata preview bounded a 5.000 righe catalogo e 5.000 righe ProductPrice nel wiring app.
- Aggiornate localizzazioni `it/en/es/zh-Hans` per "Controlla", "Rivedi", "Prepara invio", timestamp ultimo check, suggerimento e discard.
- Aggiornati/aggiunti test XCTest per policy, ViewModel e superficie UI/presentation senza mutazioni silenziose.

### Check eseguiti

| Check | Stato | Evidenza |
|-------|-------|----------|
| `git status` iniziale | ✅ ESEGUITO | Worktree iniziale: `docs/MASTER-PLAN.md` modificato e file TASK-091 non tracciato preesistenti. |
| `git status` finale | ✅ ESEGUITO | Worktree finale: modifiche Swift/UI/test/localizzazioni/tracking TASK-091; nuovo `SupabaseManualSyncSemiAutomaticPolicy.swift`; TASK-091 resta file non tracciato perché creato prima di questa execution. |
| Scheme/destination Xcode | ✅ ESEGUITO | `xcodebuild -list`; scheme `iOSMerchandiseControl`. Destination valida: iPhone 16e iOS 26.2. |
| Build compila | ✅ ESEGUITO | `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` → `** BUILD SUCCEEDED **`. |
| Nessun warning nuovo introdotto | ✅ ESEGUITO | Build senza warning Swift nei file toccati; resta solo warning tooling noto `Metadata extraction skipped. No AppIntents.framework dependency found.` |
| Test unitari mirati | ✅ ESEGUITO | `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests` → 93 test, 0 failure. |
| Test unitari completi disponibili | ✅ ESEGUITO | `xcodebuild test ... -parallel-testing-enabled NO` → 577 test, 0 failure. |
| Cooldown policy | ✅ ESEGUITO | Test ViewModel/policy verifica blocco entro 30 minuti e nuova eligibility dopo finestra. |
| Anti-reentrancy | ✅ ESEGUITO | Test verifica nessun secondo check durante `.checking`/run attivo. |
| Session/auth blocked | ✅ ESEGUITO | Test verifica `blockedAuth` se auth/owner/sessione non sono chiari. |
| Preview read-only | ✅ ESEGUITO | Test con coordinator spy: check semi-auto esegue dry-run/preview e non apply/push/drain. |
| Staged plan invalidation | ✅ ESEGUITO | Test verifica invalidazione su cambio access/sessione/owner e discard richiesto prima di perdere plan. |
| Fallback recoverable error | ✅ ESEGUITO | Test verifica `recoverableError`, nessun piano applicabile e app non bloccata. |
| Nessuna mutazione senza conferma | ✅ ESEGUITO | Test UI/presentation conferma che update/send/activity passano da review/confirm; nessun auto-drain. |
| UI/simulator manuale | ⚠️ NON ESEGUIBILE | Nessun harness UI end-to-end stabile dedicato agli stati visuali; gli XCTest sono comunque eseguiti su Simulator iPhone 16e e coprono stati/presentation/sheet/confirmation a livello statico/ViewModel. |
| Localizzazioni | ✅ ESEGUITO | `plutil -lint` su `it/en/es/zh-Hans` Localizable.strings → OK. |
| `git diff --check` | ✅ ESEGUITO | PASS dopo l'aggiornamento finale del tracking. |
| Supabase live/test | ⚠️ NON ESEGUIBILE | Non necessario: MVP verificato con fake/mock e nessuna write remota; nessun dato `TASK091_EXEC_*` creato, quindi nessun cleanup richiesto. |
| Android reference runtime | ⚠️ NON ESEGUIBILE | Non necessario per chiarire il MVP iOS; Android usato solo come riferimento funzionale da codice/documentazione, nessun emulator/test eseguito. |
| Coerenza planning | ✅ ESEGUITO | Implementazione agganciata a Release card/ViewModel/service esistenti; nessun sistema parallelo, nessuna dipendenza nuova, nessuna API pubblica backend modificata. |
| Criteri di accettazione verificati | ✅ ESEGUITO | Vedi confronto CA-T091 sotto. |

Debug rilevante: il primo giro di test mirati ha evidenziato attese obsolete sulla CTA "Invia modifiche al cloud" e una invalidazione incompleta dopo sign-out; entrambi corretti prima del PASS finale.

### Confronto CA-T091-xx

| CA | Esito execution |
|----|-----------------|
| CA-T091-01 | ✅ Micro-slice S91-A...S91-G presenti nel planning e inventory reale aggiunto in execution. |
| CA-T091-02 | ✅ No sync mutativa silenziosa; foreground check solo read-only/bounded. |
| CA-T091-03 | ✅ Residui TASK-090 mantenuti come gate, non nascosti. |
| CA-T091-04 | ✅ Decisioni/rischi planning conservati; execution non li ha riscritti. |
| CA-T091-05 | ✅ Parity matrix planning conservata; Android resta riferimento funzionale. |
| CA-T091-06 | ✅ Nessuna nuova dipendenza Kotlin/SQL; nessuna migration/RLS modificata. |
| CA-T091-07 | ✅ Superseded da override utente: non più "NON READY FOR EXECUTION"; stato finale corretto **READY FOR REVIEW**, **NON DONE**. |
| CA-T091-08 | ✅ TASK-092 non aperto; future TASK-092...096 non implementate. |
| CA-T091-09 | ✅ Scelte UX applicate senza micro-decisioni bloccanti. |
| CA-T091-10 | ✅ Micro-slice planning complete; execution ha coperto il primo MVP. |
| CA-T091-11 | ✅ UI resta card compatta Release, sheet review, `ProgressView`, CTA primaria singola, copy non tecnico. |
| CA-T091-12 | ✅ Tabelle markdown mantenute valide; `git diff --check` usato come verifica whitespace/diff. |
| CA-T091-13 | ✅ Cooldown, anti-reentrancy, preview read-only, staged plan ed errori implementati/testati. |
| CA-T091-14 | ✅ Policy / ViewModel / View / service separati; business logic pesante non spostata nelle View. |

### Rischi residui

- Verifica UI manuale visuale non catturata con screenshot end-to-end in questa execution; copertura attuale è XCTest su Simulator + test statici/presentation.
- I limiti 5.000 righe sono prudenziali per MVP; soglie future possono essere calibrate con telemetry/evidenze dataset reali privacy-safe.
- La preview ProductPrice resta nel percorso bounded/review esistente, non introduce un nuovo dettaglio lazy visuale dedicato oltre alla review Release attuale.
- Supabase live non è stato toccato: nessun rischio dati introdotto, ma review può richiedere un smoke live separato con prefisso `TASK091_EXEC_*`.

### Handoff post-execution

- **Stato richiesto:** **ACTIVE / REVIEW**
- **Responsabile prossimo:** **Claude / Reviewer**
- **Handoff:** **READY FOR REVIEW**
- **Chiusura:** non eseguita; **TASK-091 NON DONE**
- **TASK-092:** non aperto
- **Dati Supabase demo:** nessun dato creato; cleanup non necessario

---

## Review (Claude)

### Esito

**APPROVED_FIXED_DIRECTLY / REVIEW PASS** — TASK-091 chiudibile come **DONE / Chiusura** su override utente.

### Review tecnica eseguita

- Riletti `docs/MASTER-PLAN.md`, task TASK-091, diff completo dei file modificati e codice Release sync attorno a `OptionsView`, `SupabaseManualSyncViewModel`, factory/coordinator/service.
- Verificati policy semi-auto, state-machine ViewModel, UI card Release, localizzazioni, wiring app, test e tracking.
- Confermato che il foreground check resta read-only/bounded e non chiama apply/push/drain senza review/confirm.
- Confermato che TASK-092 non e' stato aperto e che Android resta solo riferimento funzionale.

### Problemi trovati e fix applicati in review

1. **Discard review non risolveva completamente lo staged plan.**  
   `cancelReviewFlow()` invalidava i piani operativi, ma lasciava `lastSummary` con segnali remoti: al foreground successivo la policy poteva trattare ancora la review come unresolved. Fix: il discard ora svuota `lastSummary`, `lastLocalApplySummary`, resetta presentation a `idleReady` e lascia solo il timestamp ultimo check.

2. **Cancellazione foreground check poteva lasciare stato `.checking`.**  
   Nel ramo `Task.isCancelled`, il dry-run applicava il summary cancellato ma non aggiornava `semiAutomaticState`. Fix: per dry-run cancellato lo stato torna a `.idle` senza aggiornare `lastCloudCheckAt`.

3. **Copertura test incompleta sui due casi sopra.**  
   Aggiunti test regressivi:
   - `testTask091DiscardReviewClearsUnresolvedStagedPlan`
   - `testTask091CancelledForegroundCheckDoesNotRemainChecking`

### Check review eseguiti

| Check | Stato | Evidenza |
|-------|-------|----------|
| `git status` | ✅ ESEGUITO | Worktree con modifiche TASK-091 attese; nessuna modifica fuori perimetro rilevata. |
| `git diff --check` | ✅ ESEGUITO | PASS. |
| `plutil -lint` Localizable | ✅ ESEGUITO | IT/EN/ES/zh-Hans OK. |
| Duplicate localization scan | ✅ ESEGUITO | Nessun duplicato nelle quattro Localizable.strings. |
| Build iOS Debug | ✅ ESEGUITO | `xcodebuild build -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2'` → `** BUILD SUCCEEDED **`. |
| Test mirati TASK-091/ViewModel/UI Release | ✅ ESEGUITO | `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests` → 95 test, 0 failure. |
| Full XCTest | ✅ ESEGUITO | `xcodebuild test ... -parallel-testing-enabled NO` → 579 test, 0 failure. |
| UI/simulator manuale | ⚠️ NON ESEGUIBILE | Non esiste harness end-to-end stabile per screenshot/stati visuali; XCTest eseguiti su Simulator e copertura ViewModel/presentation/confirmation aggiornata. |
| Supabase live/test | ⚠️ NON ESEGUIBILE | Non necessario: TASK-091 non richiede write live; nessun dato `TASK091_EXEC_*` creato, cleanup non necessario. |
| Android runtime | ⚠️ NON ESEGUIBILE | Non necessario: Android solo riferimento funzionale; nessun emulator/test eseguito. |

### Decisione review

- **Build passa:** sì.
- **Test passano:** sì.
- **No write Supabase silenzioso:** confermato.
- **UI/UX coerente:** sì, card Release esistente, stato inline, `ProgressView`, una CTA primaria, review sheet e confirmation native.
- **Codice ridondante/fuori scope:** nessun refactor ampio necessario; fix review limitati.
- **Tracking:** aggiornato a chiusura.
- **TASK-092:** non aperto.

---

## Fix (Codex)

Fix separato non necessario: i due fix mirati sono stati applicati direttamente durante la review, con test regressivi e full XCTest PASS.

---

## Chiusura

### Esito finale

- **Stato:** **DONE / Chiusura — REVIEW PASS**
- **Data chiusura:** 2026-05-09
- **Conferma/override utente:** presente nel prompt review; autorizzata chiusura DONE se build/test/review passano.
- **TASK-092:** non aperto; resta TODO / Planning.
- **Supabase live:** non usato; nessun dato demo creato; cleanup non necessario.
- **Claim production-ready globale:** non dichiarato.
