# TASK-109: iOS Supabase sync lifecycle regression — auto check/apply on launch, incremental push/pull, Review/Cancel UX cleanup, History/session runtime parity

## Informazioni generali
- **Task ID**: TASK-109
- **Titolo**: iOS Supabase sync lifecycle regression: auto check/apply on launch, incremental push/pull, Review/Cancel UX cleanup, History/session runtime parity
- **File task**: `docs/TASKS/TASK-109-ios-supabase-sync-lifecycle-ux-regression.md`
- **Stato**: ACTIVE
- **Fase attuale**: REVIEW — CHANGES_REQUIRED / BLOCKED_WITH_PLAYBOOK
- **Responsabile attuale**: OWNER / App-auth required
- **Data creazione**: 2026-05-15
- **Ultimo aggiornamento**: 2026-05-15 02:25 -0400 *(REVIEW completa Codex: fix iOS mirato applicato e verificato; Supabase History seed owner-scoped creato; chiusura DONE bloccata da app-auth mancante per pull History live non-empty)*  
- **Ultimo agente che ha operato**: CODEX *(Reviewer/Fixer — review completa + fix autorizzato + evidence)*

## Dipendenze
- **Dipende da**: **TASK-108** (**DONE / Chiusura — PASS_WITH_NOTES**). **TASK-108 non viene riaperto** come garante runtime delle promesse (auto incremental launch/foreground, push Database/Generated/History, parity History, UX unified). La **regressione post‑chiusura segnalata dall’operatore** richiede un nuovo perimetro TRACKING TASK-109.
- **Sblocca**: fix strutturato iOS lifecycle + sync engine/state machine; eventualmente **follow‑up Android separato** se l’audit comparativo EXECUTION evidenzia gap (nessuna patch Kotlin nel task corrente finché non deciso backlog).

## Tracking reconciliation gate — MASTER-PLAN e task file devono concordare

Prima di qualunque transizione da **PLANNING** a **EXECUTION DIAGNOSTICA**, il tracking deve essere coerente.

### Regole

- `docs/TASKS/TASK-109-ios-supabase-sync-lifecycle-ux-regression.md` è la fonte dettagliata del task.
- `docs/MASTER-PLAN.md` deve mostrare **`TASK‑109`** come **task attivo** o deve contenere una **nota esplicita** che la transizione a **`ACTIVE / PLANNING`** è in corso.
- Se `docs/MASTER-PLAN.md` risulta ancora **`IDLE`** o indica solo **`TASK‑108`** **DONE / PASS_WITH_NOTES** senza `TASK‑109`, la **prima azione consentita** è solo **aggiornamento markdown di tracking** (nessuna diagnostica nominalmente “ufficiale” nella cartella evidence **senza** riconciliazione).
- **Non** iniziare Wave 1 diagnostica se il tracking globale dice ancora “nessun task attivo”, **salvo** nota esplicita nel file evidence che spiega la divergenza e la **corregge** nello stesso pass documentale.
- **`TASK‑108`** resta storico **DONE / PASS_WITH_NOTES** e **non viene riaperto**.
- **`TASK‑109`** è una **regressione runtime/UX** post‑chiusura — **non** polish.

### Stop condition tracking

**Non passare** a **EXECUTION DIAGNOSTICA** se:

- **`TASK‑109`** non è referenziato dal Master Plan iOS;
- esiste **un altro task ACTIVE** non riconciliato;
- lo stato del task file e del Master Plan **divergono** senza nota di riconciliazione;
- il task file dichiara deliverable già completati **senza** evidence reale.

## Scopo *(sintesi — planning operativo sicuro prima di codice)*
Consegnare pianificazione **operativa**, con **riconciliazione tracking obbligatoria** (sezione precedente); separazione netta **EXECUTION diagnostica ≠ EXECUTION implementativa** (**§ 8B**); **DoR** post‑gate (**§ 8C**); **harness test / fake coordinator** (**§ 8D**); **performance budget** (**§ 8A**); **matrice trace acceptance → evidence** (**§ 8E**); **localization / accessibility gate** (**§ 8F**); **ownership UI/engine** (**§ 4E**); **cancellation taxonomy** (**§ 4F**); contratto coordinator (**§ 4C–4D**); state machine (**§ 4B**); decisioni (**§ 4A**); UX inclusa **root banner visibility** (**§ 3A**); contratti multi‑dominio / cursor / History / refresh / crash (**§ 6A–§ 6F**) — prima di qualunque Swift/Kotlin/SQL in **EXECUTION implementativa** (**bloccata finché Wave 1 diagnostica + Gate 2 §8B**, con evidence mappata **§ 8E** quando applicabile).

## Contesto tecnico sintetico (lettura codice PLANNING‑only — non claim PASS runtime)
Nel tree iOS attuale compaiono **due ingressi lifecycle** sullo stesso `SupabaseManualSyncViewModel` / factory:
1. **`SupabaseManualSyncForegroundRootHost`** (`ContentView.swift`): `@StateObject` factory-based; `.task` + `scenePhase == .active` → `startForegroundSemiAutomaticCheckIfAllowed(source: .rootForeground)` con gate **`ForegroundCloudWorkflowActivityCenter`**; banner root **nascosto** quando `selectedTab == 3` (tab Opzioni).
2. **`SupabaseManualSyncReleaseCard`** dentro `OptionsView.swift`: ancora `@StateObject` wrapping l’istanza condivisa; `.onAppear` + `scenePhase` + ritardo fisso (**700 ms**) → `startSemiAutomaticCheckIfNeeded()`.

Questo pattern può correlare sintomi “solo Options attiva davvero la sync/root banner” anche se serve **TRACE Wave 1** per prova causale definitiva.

## Non incluso (questo turno — e fino alla Gate 2 §8B)
- Nessuna modifica Swift / Kotlin / SQL / migration / RLS / RPC / schema Supabase.
- Nessuna **EXECUTION DIAGNOSTICA** nominalmente autorizzata se **MASTER‑PLAN ↔ task file** restano divergenti **senza** riconciliazione documentale (**tracking reconciliation gate** sopra).
- Nessun execution **implementativa**: **vietate** patch app finché la **EXECUTION DIAGNOSTICA Wave 1** non ha prodotto la evidence nominale (**Gate 2** §8B).
- Nessuna build Xcode / `./gradlew` / XCTest / runtime smoke imposti **da questo aggiornamento task** *(restano comunque strumento della EXECUTION futura).*  
- Nessun verdict **DONE**, **PASS**, **REVIEW_PASS_FINAL**, “fix completed”.
- Nessun write distruttivo su dati live; niente `service_role` client né bypass RLS.

---

## 1. Sintomi osservati (dal report utente — copertura obbligatoria audit)
1. Cold launch da **Inventory / Home**: **non** parte subito il controllo remoto.
2. Il controllo remoto pare partire solo aprendo **Opzioni**.
3. Banner globale appare sulle altre tab **solo dopo** essere entrati in Opzioni → indicatore forte di trigger **centrico Options / card**, non percepito come **root‑scoped affidabile**.
4. In Options compare “Fetching cloud counts…” poi stato **«Operation cancelled»** senza cancel consapevole utente.
5. Tap **Sync now** porta a sheet Review / **Recheck** con testo tipo **Device already updated** ma **senza convergence** sync reale attesa dall’azione.
6. Review **incoerente**: “ci sono modifiche da rivedere” vs poi **solo no‑op** / already updated nella stessa sessione UX.
7. **Cancel** apre **secondo** dialog di conferma con **altro Cancel** ridondante o disabilitante (pattern UX confuso).
8. Post Cancel / Retry lo stato rimane sporco → **Sync now** fragile.
9. Options mostra **History sessions = 0** mentre Android/Supabase hanno dati History/session coerenti col tenant.
10. Tab **Cronologia / History** resta vuota o non aggiorna dopo scenario atteso sync.
11. Incremental pull/push percepito **non comparabile ad Android**.

---

## 2. Ipotesi root cause *(verificare in EXECUTION — non dichiarazioni definitive)*
| # | Ipotesi |
|---|---------|
| H1 | Auto‑sync agganciato soprattutto a `ReleaseCard.onAppear`/delay più che a stato sessione **`rootForeground` affidabile dopo auth hydrate**. |
| H2 | `SupabaseManualSyncReleaseCard` con `@StateObject` + ciclo vita sheet/tab altera/coalesing job rispetto al root `@StateObject` *separate struct identity* ⇒ race / stato non osservabile finché Options non materizza la card. |
| H3 | `ForegroundCloudWorkflowActivityCenter.isBusy == true` in cold path ⇒ `markForegroundCheckSkippedBecauseBusy` + defer che **non viene consumato se la card cambia stato diversamente**. |
| H4 | Auth restore tardivo ⇒ primo latch root fallisce; **nessun reschedule deterministico single‑flight**. |
| H5 | `cancelRootForegroundCheck()` vs `cancelActiveRun()` su background/sheet ⇒ `CancellationError` interpretato come **Operation cancelled UX** spurio. |
| H6 | Review summary reducer non invalidato dopo no‑op ⇒ **sheet stale** + “Recheck” loop. |
| H7 | `SyncNow` pathway riusa stato review precedente nel presenter invece di **nuovo ciclo orchestrato**. |
| H8 | Auto path effettua solo remote preview/count fetch senza classify/apply coherent con pipeline apply/baseline (**verificare `SupabaseManualSyncViewModel` branches**). |
| H9 | History/session **fuori dall’orbita foreground unificato** o salva fuori dal contesto che alimenta `@Query`/`refreshLocalDatabaseSummary`. |
| H10 | `sync_events` **non include dominio History** ⇒ serve **solo** pull paginato `shared_sheet_sessions` + mapping idempotente; se path collegamenti mancano ⇒ count/list restano zero (**vedi § Supabase MVP**). |
| H11 | Banner root dipende solo da progress/presentation pubblicato dopo che **Options refresh** pubblica stato (accoppiamento indesiderato). |
| H12 | Watermark/baseline acknowledgement avanza **prematuramente** vs apply effettiva (*invariant TASK‑088/TASK‑096 verificabile*).

---

## 3. Target UX definitivo (non ambiguo)

### Cold launch / foreground
- **Auto check**: parte senza navigare Options (salvo gated signed‑out/offline/policy esplicito).
- **Non blocca Inventory/Database/History** durante apply/check (progress throttled OK).
- **Nessuno sheet review** quando esito è **né applicabile né bloccante** (no‑op trasparente).
- **Safe auto apply:**
  - applicare automaticamente **solo** create/update/link **non distruttivi**, owner-scoped, **non dirty-local**, idempotenti;
  - **non** applicare automaticamente delete/tombstone; owner mismatch; collisioni logical key; remote payload incompleto; record con **dirty locale** attivo o bridge (`remote_id`/`fingerprint`) **ambiguo**;
  - se una pagina remota contiene **sia righe safe che blocked**, applicare solo le safe **se** il servizio implementa partial apply atomico o recovery marker esplicito; **altrimenti** classificare l’**intera** pagina (o bucket coerente) come **`needsReview`**;
  - il summary finale deve distinguire **applied / skipped / needsReview / failed**, non un messaggio unico fuorviante.

### Sync now manuale
- **Motore identico** al ciclo auto foreground (codice condiviso, RunGate compatibile dopo dedupe).
- **Stale review vietata**: sempre sync cycle fresh keyed (es. correlation id operation) dopo tap.
- **Recheck**: non deve essere funnel obbligatorio quando esiste lavoro reale applicabile con CTA dedicate.

### Cancel
- Un solo punto semantico: **solo operazioni realmente abortable** ⇒ idle/resumabile.
- Nessun popup annidamento se l’azione annullata era **solo preview sicura / non distruttiva** (specificare whitelist in EXECUTION dopo UX review parity Android).
- `Try again` riavvia operazione (**non** stato sticky “cancelled”). 

### History
- Options mostra **`historySessions` accurato**, efficientemente (già campo `LocalDatabasePublicSummary.historySessions`; verifica **timing refresh** dopo `Notification`/save bg).
- History tab coincide con remoti dopo pull (**nessun dup** su second ciclo).

Dettaglio copy/stati root e superficie Release: **`§ 3A`**.

---

## 3A. UX finale scelta — iOS native, semplice e non invasiva

Design target: comportamento chiaro anche sotto Dynamic Type e durante sync lunga — **senza overlay modale globale**, **senza agganciare la logica a una singola tab**.

### Root banner

Il banner root deve essere **compatto**, **non modale** e **visibile anche partendo da Inventory**.

Stati suggeriti (localizzazioni iOS dedicate in EXECUTION; qui label di lavoro in en):

- **Checking cloud updates…**
- **Synchronizing local changes…**
- **Updating this device…**
- **History synchronization…**
- **Database updated**
- **Cloud unreachable — working offline**
- **Review needed**

Regole operative:

| Regola | Note |
|--------|------|
| Massimo **1** banner globale | Nessun stacking di più strip concorrenti. |
| **Niente overlay** che blocchi tap o scroll Inventory | Progress inline / safeArea inset compatto OK. |
| Opzioni **`~700 ms`** | Se un’operazione dura meno della soglia configurabile (~700 ms), **non** fare flash rumoroso — mostrare **solo stato finale breve** o rimanere nascosto. |
| Sopra soglia | Mostrare **progress compatto** (fase + conteggio/high-level quando utile). |
| **Dynamic Type** | Banner leggibile, **senza coprire la tab bar** (padding / truncation / priorità titolo). |

### Root banner visibility policy

- Il root banner deve essere **visibile** su **Inventory/Home**, **Database**, **Generated** e **History** quando un job **root** è attivo e l’operazione **dura oltre** la soglia visiva configurabile (**~700 ms** §3A).
- In **Opzioni** è consentito **nascondere** il banner root **solo se** la **Options card** mostra lo **stesso** `operationID`, la **stessa fase** e lo **stesso** stato **cancellable** coerente con lo stato canonico.
- È **vietato** il caso in cui:
  - il banner è **nascosto** in Inventory al **cold launch**;
  - entrando in **Opzioni** “parte” il job (o diventa osservabile per la prima volta in modo corrispettivo);
  - tornando a Inventory **appare** il banner **solo allora** (pattern “Options fa funzionare la sync”).
- Se **Options card** e **root banner** mostrano stati **diversi**, la build è da considerare **non chiudibile** (**§ 9 stop S‑tier**, **§ 4E**).
- In **DEBUG** / evidence, root banner e Options card devono poter essere **correlati** con lo **stesso** `operationID`.

### Options card *(observer + comando manuale)*

Opzioni è il **pannello di stato e controllo**, **non il motore** della sync (**vincolo consolidato § 4A D109‑01**).

| Condizione UX | Titolo / linea stato | Comportamento CTA |
|---------------|---------------------|---------------------|
| Sync **attiva** | Titolo tipo **Operation in progress…**; **sottotitolo con fase reale** dalla state machine canonica (**§ 4B**). | **`Cancel`** solo se l’azione è davvero cancellabile; **`Sync now` disabilitato** con **motivo accessibile**. |
| **No-op** reale | **Cloud and local database are up to date** | Solo **`Sync now`**; **nessuna sheet**. |
| Cambi **safe** in apply | Titolo tipo **Updating this device…**; dopo commit: **`Database updated`**. | **Nessuna** review sheet intermediaria fuori policy. |
| Serve **review** | Titolo **Changes need review**; breve spiegazione: **Some changes cannot be applied automatically.** | **`Review`** primaria quando esistono item reali (**§ D109‑06**). |

### Review sheet

Contenuti obbligatori:

- **conteggi per dominio** (catalog / prices / history…);
- **cosa sarà applicato**;
- **cosa sarà saltato** (motivo alto livello privacy-safe);
- **cosa richiede una decisione** esplicita;
- CTA primarie coerenti con lo stato: **`Apply reviewed changes`**, **`Keep local version`**, **`Skip for now`**, **`Try again`** *(set effettivo dipende dai casi ricoperti, non dall’illusione Recheck).* 

**Vietato:**

- sheet per **no-op**;
- stringa **`Device already updated`** (o equivalente contradittorio) **dentro** una sheet marcata **`Needs review`**;
- **`Recheck` come CTA primaria**;
- **doppio Cancel** conferma per lo stesso annullamento UX.

### Cancel

| Scenario | UX |
|---------|-----|
| **Check / preview non distruttivi** | **Un tap** Cancel basta ⇒ **zero** confirmation dialog nidificati. |
| **Apply locale in flight** che **non** è tecnico-sicuro da abortire | Nessun **`Cancel`** finto: preferire stato tipo **`Finishing current save…`** (o equiv. localizzato) finché terminato sicuro / fail / timeout policy. |
| **Apply davvero cancellabile** | Annullamento netto ⇒ stato recuperabile (**§ 4B** `idle`/`cancelledByUser` policy). |
| **Review sheet** | Chiudersi con **`Close`** / **`Cancel review`**; **non** mutare dati locali né marcare errore sintetico se l’operatore rinuncia alla review (**non equivale a sync failed**). |

### Micro‑UX polish obbligatorio *(anti‑regressioni visuali TASK‑109)*

| Regola UX | Dettaglio operativo EXECUTION‑forward |
|-----------|--------------------------------------|
| Transizioni banner root | Fade / contenimento animazione (**no lampeggiamento** fuori soglia **~700 ms** §3A); stato finale breve resta leggibile poi torna **`idle`/nascosto** coerente. |
| Card Options stabile | Altezza / layout **`ViewThatFits` / spacer** progetto tecnico dov’è necessario: **limitare vertical jump** su cambio fase/progress. |
| Ordine logico CTA | Posizione stabile quando possibile: **`Sync now` idle** ↔ **`Review` needsReview** ↔ **`Try again` failed/cancel recuperabile** ↔ **progress/`Cancel`** solo mentre **busy**. |
| Stati finali brevi | Messaggi **`Database updated` / completed** ⇒ **dwell time limitato**, poi stato card rientra leggibile (**non “flash then blank errato”** UX). |
| Copy utente‑safe | Banner/cards usano lingua operatore (**es. Checking cloud updates**); **vietato esporre** “fetch counts” sulla superficie Release — resta solo **`#if DEBUG` / diagnostics** se indispensabile tecnico sviluppatori. |
| Non ostruire ingressi chiave | Banner **mai** sulla tab bar, **mai** sopra campo scanner/import critico senza repositioning progetto DESIGN review. |
| Dynamic Type alto | Preferire **2 righe compatte**, **`lineLimit`/truncation** intelligente (**accessibility headline + detail**) rispetto overflow che nasconde CTA/tab. |

Politiche account/offline/signed‑out correlate copy/stato (**non “Operation cancelled” spurio**) — **§ 4D**.

---

## 4. Target architettura
Obiettivo: **job primario sempre app‑scoped/root‑scoped**, UI che **legge stato canonico**. Pipeline e decisioni: **`§ 4A`**. State machine / cancellazioni: **`§ 4B`**, **`§ 4F`**. Coordinator (**single‑flight/auth/scene backoff**): **`§ 4C`**. **Ownership superfici**: **`§ 4E`**. Account/offline: **`§ 4D`**. Multi‑dominio + cursor/ack/recovery + History + refresh post‑commit + crash: **§ 6A–§ 6F**. Perf/trace/a11y/harness: **`§ 8A`**, **`§ 8E`**, **`§ 8F`**, **`§ 8D`**. Tracking: **gate MASTER ⇄ TASK** (sezione dedicata sopra **`Scopo`**).

- **Coordinator unico app‑scoped** (implementazione tecnica nominabile in EXECUTION: es. estrazione tipo `CloudSyncCoordinator` riducendo coupling da `SupabaseManualSyncReleaseCard`).
- **`OptionsView` / `SupabaseManualSyncReleaseCard`**: osservatori + **solo** trigger manuale `Sync now`; **vietato ownership parallela** dei job (**D109‑01**).
- **Dedupe forte** tra `.task(initial)`, `.scenePhase`, **auth/session change**, `SyncNow`, `Notifications` import/sync dove applicabile.
- **SwiftData mutation** pesante su contesto bg + pubblicazione stato UI MainActor (**throttle** compatibile **`§ 8A`**).
- **Privacy**: no logging token/email/payload identifiers — policy TASK‑101 retained.

---

## 4A. Decisioni progettuali consolidate — UX e sync engine

Queste sono **decision gates** della futura EXECUTION (non suggerimenti vaghi):

### D109‑01 — Options non deve possedere la sync
`OptionsView` / `SupabaseManualSyncReleaseCard` diventa esclusivamente **superficie di osservazione** e **superficie per `Sync now` manuale** — **mai** punto di bootstrap esclusivo per job cloud.

Target:

- Il **job primario** viene schedulato / posseduto da un **coordinator app‑scoped/root‑scoped**.
- Inventory/Home riceve auto‑check senza navigare Options.
- Options può mostrare lo stato sincrono alla state machine **e** lanciare `Sync now`; **non** deve creare un **secondo job indipendente** per lo stesso seme operativo (`operationID`/correlation distinti sono OK quando esplicitamente intenzionale).
- **Root banner**, **Options card**, **Review sheet** leggono tutti lo **stesso stato canonico** (single source reducer / presenter agganciato coordinator).

**Razionale sintetico:** Il sintomo “la sync pare partire solo entrando Options” indica coupling globale‑vs‑lifecycle view: architetturalmente fragile (tab lazy, sheet, teardown).

### D109‑02 — Sync automatica foreground‑first (no background worker in‑scope TASK‑109)

Target ciclo automatico:

- Cold launch dopo **auth/session hydrate**;
- ritorno **foreground**;
- `Sync now` manuale;
- emissioni sicure dopo modifiche **Database / Generated / History** quando policy lo consente.

**Esplicitamente fuori da TASK‑109** *(task separati P2/backlog)*:

| Vietato ora | Motivo |
|-------------|--------|
| `BGTask` / BGAppRefresh ecc. | foreground-only policy progetto storica TASK‑095 lineage |
| timer persistenti / polling loop | silent sync vietata filosofia precedente accordi progetto |
| Realtime come dipendenza obbligatoria | optional enhancement separabile |
| worker cloud sempre vivo | fuori perimeter |

Realtime/Background → **solo** nuovo TASK backlog se business case separato ratificato utente.

### D109‑03 — Sequenza operativa standard (ogni ciclo app‑scoped)

Ordine nominale — salvo deviation **documentata+motivate** nell’implementazione *(esclusioni devono restare leggibili in review codice/evidence)*:

1. **`hydrateAuthAndOwner`**  
2. **`loadLocalSummaryAndPending`**  
3. **`pushSafeLocalPending`**  
4. **`fetchRemoteSignals`**  
5. **`previewRemoteChanges`** *(classifica safe/blocked)*  
6. **`applySafeRemoteChanges`** *(SwiftData locale)*  
7. **`syncHistorySessions`** *(prima classe § D109‑08)*  
8. **`commitCursorAndAckOnlyAfterLocalSave`** *(invariant forte)*  
9. **`refreshLocalSummaries`**  
10. **`publishCompletedState`**

Regole operative:

| Regola | Enunciato |
|--------|-----------|
| Cursor / watermark remoti | avanzano **solo** dopo **commit SwiftData confermato** per la finestra correlata *(no advance “ottimistico” prematuro).* |
| Pending local ACK | solo dopo successo remoto **e** bridge/fingerprint coerenti laddove progetto definisce ack esplicito. |
| Fail metà ciclo | **non** pubblicare stato **“everything up‑to‑date”** né sheet review fantasma silent. |

Push‑before‑pull vs pull‑before‑push: **default D109‑03 punto 3 precede punto 6** ⇒ **push-safe pending prima** di nuove mutazioni remoti sicure quando pending compatibili; se detect conflitto imminente → **`needsReview`**. Divergenza documentata ⇒ va sezione DESIGN NOTE in EXECUTION § Fix se necessario *(non modificare questo file senza review planning utente).* 

### D109‑04 — Local-first con remote safe apply *(coerenza mentale Room↔SwiftData)*

- App **usufruibile durante** sync (scroll navigazione tab).
- Remote **mai** wipe / overwrite record **dirty‑local tracked** senza review.
- Remote safe ⇒ auto apply deterministico (**regole granulari §3 Cold launch bullet expanded**).
- Conflitto / tombstone / owner mismatch ⇒ **`needsReview`**.

### D109‑05 — Manual `Sync Now` ≠ modalità parallela

`Sync now` usa **coordinator identico + stessa abstract state machine**.

| Consentito | Vietato |
|------------|---------|
| `source`/correlation: es. **`manualUserInitiated`** prior UX | riuso review summary stale |
| surfaced completion più evidente (snackbar/banner stato finale) | aprire review no-op |
| | `Recheck` unica quando esistono applicabili reali |
| | sticky `cancelled` che blocchi retry dopo utente‑retry |

### D109‑06 — Review solo per non auto‑applicable

Review sheet **solo** se esistono *almeno una* classe:

| Motivo review |
|----------------|
| Conflitto reale campo/chiavi |
| tombstone/delete non auto‑safe |
| owner/account/session ambigua |
| dirty locale blocca overwrite classe remota richiesta |
| policy esplicita di conferma (legal/safety progetto definisce whitelist) |

**Non** deve apparire se: no‑op tecnico confermato; solo contatori remoti; check completato neutro senza gated items; sicuro già completamente assimilato nella stessa **`operationID`**.

### D109‑07 — Cancel senza dialog annidati

Riassunto (**espanso § 3A / § 4B**):

| Regola chiave |
|---------------|
| 1‑tap durante operazioni realmente cancellable |
| niente conferma nidificata su preview safe |
| post cancel → stato `idle` / `cancelledByUserRecoverable` (naming implementativo flessibile se equivalente comportamentale §4B) |
| Retry ⇒ **nuovo `operationID`** |
| `Operation cancelled` **solo** se utente‑cancel reale **o teardown classificati** (**documentati** nell’instrumentation evidence) |

### D109‑08 — History/session first‑class citizen

History **non accessorio**:

- incluso nei **pending aggregate push** quando modificato offline;
- incluso nei **pull** foreground/manuale;
- reflette `Options.historySessions`;
- `@Query`/lista History aggiorna post commit BG;
- secondo ciclo ⇒ **insert 0**/no duplicate merge.

Fallback obbligatorio se `sync_events` non copre history: paging owner‑scoped **`shared_sheet_sessions`** (dettaglio **`§ 6A` table**).

**Vietato** dichiarare `historySyncedOK` nell’overview se EXECUTION evidenzia path saltato/non hookato.

---

## 4B. State machine canonica — stati, transizioni e anti‑stale rules

La EXECUTION deve **rendere esplicito** questo modello (nomi tipo possono differire ma **semanticamente equivalenti**):

### Tabella principale

| Stato | Significato | CTA primaria UI card | Sheet consentita |
|-------|-------------|----------------------|------------------|
| `idle` | nessuna sync attiva | `Sync now` | **no** |
| `waitingForAuthHydrate` | JWT/owner loading | disabilitazioni con motivazione | **no** |
| `checkingRemote` | probing remoto / counts orchestration primaria | progress indeterminato/compatto root | **no** |
| `pushingLocal` | drain sicuro pending | progress | **no** |
| `fetchingRemote` | pagine remote / signaling | progress | **no** |
| `previewingRemote` | classify safe vs blocked bucket | progress | **no** |
| `applyingRemote` | scrittura SwiftData batch sicuro | progress + root banner Updating… | **no** |
| `syncingHistory` | domino hist/session | banner **History synchronization…** | **no** |
| `completedNoChanges` | misurato NO effective delta | Sync now | **no** |
| `completedApplied` | commit apply success | stato finale tipo Database updated ± riepilogo alto livello | **no** |
| `needsReview` | esistono item blocked | **`Review`** | **sì** |
| `failedRecoverable` | rete/auth/permission retryable | **`Try again`** | dettaglio opzionale (non contraddizione review) |
| `cancelledByUser` | annullamento reale *(non teardown silenzioso confuso)* | **`Try again`** | **no** |

### Anti‑stale rules

| # | Rule |
|---|------|
| A1 | Ogni ciclo/long operation ha **`operationID`** UUID/string monotonia crescente. |
| A2 | Ogni `reviewSummaryPayload` deve referenziare **`operationID`**. Nuova sync ⇒ **invalidate** summaries precedenti. |
| A3 | Stato combinato **`needsReview` + “Device already updated”** vietato sulla stessa presentazione contemporaneamente. |
| A4 | `Recheck` al massimo azione **secondaria** exploratory — **vietata** primaria se applicabili reali disponibili. |
| A5 | `completedNoChanges` ⇒ **vietata** aperture automatica Review. |
| A6 | `completedApplied` ⇒ refresh obbligatori: **Local DB summary**, **pending summary**, **`historySessions` count**, **lista History**, **`rootBanner` derived state**.

### Matrice di transizioni **vietate** (bug class design)

| Da | Verso | Perché bloccante / puzz pattern |
|----|-------|---------------------------------|
| `completedNoChanges` | `needsReview` **mantenendo** stesso stale `reviewSummary.operationID` | summary stale UX |
| `cancelledByUser` | torno **`checkingRemote` auto immediato loop** sticky | hysteresis senza gated user acknowledgement |
| `needsReview` (sheet aperta) | dentro sheet → `completedNoChanges` textual contraddizione | nonsense operator trust |
| `checkingRemote` | UI string **Operation cancelled** senza teardown classificabile / tap cancel | instrumentation bug propagation |
| `idle` dopo cold path | primo busy root **solo** correlato **`Options.onAppear`** | viola D109‑01 invariant arch |

---

## 4F. Cancellation taxonomy — cosa può diventare “Operation cancelled”

Non tutte le cancellazioni **tecniche** sono cancellazioni **utente**.

| Causa | User-facing copy consentita | Stato target | Note |
|------|-----------------------------|--------------|------|
| `userCancel` | Operation cancelled / Cancelled by user | `cancelledByUser` | Solo dopo tap esplicito su Cancel. |
| `supersededByNewOperation` | nessun messaggio **oppure** “Starting new check…” | nuova operation | Non mostrare errore generico sync. |
| `authNotReady` | Preparing cloud session… | `waitingForAuthHydrate` | **Non è** cancellation. |
| `signedOut` | Sign in to sync cloud data | account state | **Non è** cancellation. |
| `viewDisappear` | nessun messaggio | job continua o si stacca dalla view | Options dismiss **non** deve cancellare root job (**§ 4C / § 4E**). |
| `networkTimeout` | Cloud unreachable — working offline | `failedRecoverable` | **Non** Review sheet obbligatoria. |
| `rlsPermissionError` | Cloud permissions need checking | `failedRecoverable` / permission state | **Non** Sign in se OAuth ancora formalmente valido ma permessi/RLS falliscono (**§ 4D**). |
| `applyNotCancellable` | Finishing current save… | busy finalization | **Non** mostrare Cancel finto. |
| `systemTaskCancelled` | solo **DEBUG**, salvo impatto UX reclassification | classify in evidence | Richiede **root‑cause** in evidence (timeouts, race, teardown). |

### Regole

- **`Operation cancelled`** può apparire **solo** per `userCancel` **o** teardown **`systemTaskCancelled`** / correlati **classificati e documentati** nell’evidence (**non** “default” da `CancellationError` non tipizzato — **§ 9 S10**).
- `CancellationError` tecnico **non** deve propagare automaticamente alla **UI Release**.
- Cancel da Review sheet **non** equivale a cancel della sync se la sync è **già** conclusa **o** se la review **non** ha mutato dati.
- Retry dopo cancellation deve creare **nuovo** `operationID`.
- Dopo cancel utente, **non** rilanciare immediatamente la **stessa** auto‑sync in loop (**allineamento § 4C**).

---

## 4C. Coordinator lifecycle contract — single-flight, auth hydrate, scenePhase e backoff

EXECUTION **implementativa** deve verificare o introdurre un coordinator **app‑scoped** con le proprietà seguenti (nomi tipo adattabili, **semantica obbligatoria**).

### Ownership

- Un **solo owner logico** dei job cloud mutativi per sessione owner corrente.
- La **root app shell** crea o riceve il coordinator (`environment` / DI condivisa — da documentare in review).
- **Options**, **Review sheet**, **root banner** **osservano** lo stesso stato; **nessuna** view crea job mutativi **non tracciati** dal coordinator.

### Trigger ammessi

| Trigger | Comportamento atteso |
|--------|----------------------|
| **Cold launch** | Schedula check **dopo** auth/session hydrate (vedi `waitingForAuthHydrate` §4B). |
| **`scenePhase` active** | Schedula check se policy anti‑spam/debounce lo consente (**no burst** ravvicinati). |
| **Auth restored** | Se il primo check era stato **saltato** perché auth non pronta, **rilancio deterministico unico** (non storm). |
| **Manual Sync now** | Nuova `operationID` **oppure** join esplicito a operazione attiva con UX chiara (**§ single‑flight**). |
| **Local pending creato** | Accoda **push safe** bounded (**no polling continuo** §D109‑02). |
| **Options appear** | **Refresh** visuale / snapshot / bind osservabile — **non** bootstrap sync autonomo parallelo. |

### Single-flight

- Un **solo** job mutativo attivo per owner.
- Trigger concorrenti → **coalescing** o **drop** deterministico.
- Se l’utente preme **Sync now** durante job attivo: **stesso job visibile** **oppure** bottone disabilitato con motivo **oppure** nuova operation **solo** dopo fine/cancel del precedente (regola da fissare in review, ma **vietato** root job + Options job **indipendenti**).
- È **vietato** avere job root e job Options **paralleli non correlati** sullo stesso intento di sync.

### Auth hydrate

- Sessione/owner non pronti → stato **`waitingForAuthHydrate`**; **non** mostrare **Operation cancelled** per un check **semplicemente differito**.
- Dopo restore auth → **al massimo un** check auto schedulato (salvo backoff errore).
- **Signed‑out** → stato account dedicato (**§ 4D**), non errore sync generico.

### Backoff e hysteresis

- Nessun **retry loop infinito** automatico.
- Dopo errore rete/RLS/schema → **backoff leggero** o azione manuale (**Try again** / Sync now).
- **Sync now** manuale può **bypassare** backoff se la policy lo consente in sicurezza.
- Dopo **cancel utente** → **nessun** rilancio automatico **immediato** dello stesso check.
- Foreground ripetuti ravvicinati → **debounce** / coalescing (**§ 8A** timeline).

### Operation identity

Ogni operation espone almeno: **`operationID`**, **`source`**, **`ownerUserID`** (o hash redatto in log), **`startedAt`**, **`phase`**, **`isUserInitiated`**, **`allowsCancel`**, **`reviewSummaryID`** (se presente).  
Review summary e summary finale devono essere **sempre** legati a **`operationID`**.

---

## 4E. Ownership matrix — chi possiede, chi osserva, chi può comandare

La futura **EXECUTION** deve evitare ambiguità fra **View lifecycle** e **sync engine**.

| Componente | Ruolo target | Può avviare job? | Può cancellare? | Può mostrare UI? | Note |
|-----------|-------------|------------------|-----------------|------------------|------|
| Root app shell / ContentView host | Owner lifecycle **app‑scoped** | sì, **tramite coordinator** | sì, se job **cancellable** policy | sì, **root banner** | **Non** deve dipendere da Options. |
| CloudSyncCoordinator / SupabaseManualSyncViewModel **app‑scoped** | Single source of truth | sì | sì | pubblica stato | Un solo **`operationID` attivo** per owner (**single‑flight**). |
| OptionsView | **Observer** + comando manuale | **solo** tramite coordinator | **solo** tramite coordinator | sì, card dettaglio | **Non** crea job autonomo su `onAppear` (**§ 8D / DoR‑B**). |
| SupabaseManualSyncReleaseCard | Surface UI | **no** bootstrap autonomo | **no** diretto | sì | `onAppear` può refreshare snapshot / bind — **non** avviare sync parallela. |
| Review sheet | Decision surface | no | chiude review; **non** cancella job salvo azione esplicita | sì | Legata **`reviewSummaryID` + operationID**. |
| Root banner | Status surface | no | no, salvo azione delegata esplicita | sì | Sempre derivato dal **medesimo stato canonico**. |
| HistoryView | Data consumer | no | no | sì | Deve aggiornarsi **dopo** commit History (**§ 6D**). |
| Database / Generated flows | Fonti mutazione locale | possono creare **pending locali** | **no** sync diretta cloud | sì | Push passa coordinator / **pending planner**. |

### Regole

- Ogni trigger deve essere tracciato con **`source`**.
- Ogni UI surface deve poter mostrare l’`**operationID`** in **DEBUG** / evidence.
- Nessuna view deve possedere un `Task` **mutativo cloud** **non registrato** nel coordinator.
- **`Options appear`** può **solo**:
  - leggere snapshot;
  - refreshare summary locale;
  - collegarsi allo stato attivo;
  - abilitare **`Sync now`**.
- **`Options appear`** **non** può essere il primo e **unico** punto che rende la sync **funzionante** (**D109‑01**).

---

## 4D. Account, offline e signed-out policy

### Signed-out

- Non avviare sync remota mutativa.
- Non mostrare **Operation cancelled** come sostituto dello stato account.
- Non cancellare dati locali.
- CTA account chiara; pending locali **restano** e restano **visibili** dove previsto dalla UI.

### Offline / cloud unreachable

- App **local‑first**; Database / Generated / History restano usabili.
- Root banner: **Cloud unreachable — working offline** (o equivalente localizzato §3A).
- **Sync now** → errore **recuperabile** (`failedRecoverable`), **non** review sheet obbligatoria.
- **Nessun** cursor avanza senza round remoto concluso con successo coerente.

### Account switch

- Sospendere sync mutativa in transizione.
- Non applicare dati del **nuovo** owner sopra dati locali del **vecchio** owner senza policy esplicita.
- Stato tipo **`accountNeedsCheck`** (o equivalente); pending locali del vecchio contesto possono richiedere review / azione manuale.
- Invalidare review summary e cursor **non coerenti** con il nuovo owner.

### Session expired

- Distinguere **session expired** da **RLS** / **schema** error.
- Non mostrare **Sign in** se OAuth risulta valido ma fallisce per **permessi/RLS**.
- Non mostrare **up‑to‑date** se l’accesso remoto **non** è stato verificato.

---

## 5. Audit comparativo Android

### Sintesi PLANNING da file letto: `MerchandiseControlApplication.kt`
- Lifecycle **application‑wide**: `ProcessLifecycleObserver.onStart` invoca **`catalogAutoSyncCoordinator.onAppForeground()`**, **`historySessionPushCoordinator.onAppForeground()`**, **`realtimeRefreshCoordinator.onAppForeground()`** → modello dichiarato **foreground‑first**.
- **`CatalogSyncStateTracker`**: stato busy cloud per UI root (**non proprietà esclusiva Options**).

Tabella (**completamento celle operative = EXECuzione audit file Android elencati**):

| Area | Android attuale | iOS attuale | Gap | Target iOS | Eventuale Android follow-up |
|------|-----------------|-------------|-----|-------------|----------------------------|
| auto launch check | Process lifecycle coordinators | `.task`/scenePhase + card Options/delay | sincronizzare semantica | Check post‑auth unify | solo se incompleteness reale emerge |
| foreground check | onStart symmetric | `.active` symmetric + defer busy | possibile stale defer | reschedule deterministico single‑flight | TBD |
| manual Sync Now | *CatalogSync VM — TBD* | ViewModel modalità release | stato stale sheet | ciclo fresco comune root | TBD |
| review sheet | *TBD* | Review reducer + confirmations | stato incoerente messaggi | invalidate + item real‑only | TBD |
| cancel/retry | *TBD* | multi cancel pathways | UX nested | unify semantics | TBD |
| safe auto apply | Coordinators/repo | guarded apply TASK streams | regressione UX | parity tests | TBD |
| pending local push | repo/outbox drain | Planner + state store | ack timing | dopo read‑back parity | TBD |
| history sessions | history coordinator foreground | SwiftData svc +SwiftUI | COUNT/LIST zero err | pipeline collegato | solo se anche Android incompleto |
| count Options | *TBD* | fetchCount HistEntry | stale refresh hooks | dopo sync notifies | TBD |
| no-op/idempotenza | repo patterns | XCTest alcuni percorsi | runtime regression captured | deterministic second run insert 0 | TBD |
| performance | coordinators chunked/threading | throttling TASK‑108 lineage | regressione UX | non freeze inventory | TBD |

### Audit Android obbligatorio prima della scelta architetturale finale

Prima di dichiarare parity o scelte iOS definitive, **EXECUTION** deve **completare le celle `TBD`** leggendo **codice Android reale** in `MerchandiseControlSplitView` (nessuna assunzione implicita).

Da verificare in lettura mirata:

| Voce |
|------|
| Chi **possiede** il lifecycle sync (Application / VM / repository). |
| Se **Options Android osserva** il job o **lo avvia**. |
| Se esiste **tracker / coordinator application‑scoped** (singleton). |
| Ordine **push‑before‑pull** o equivalente rispetto ai pending. |
| Se **`HistorySessionPushCoordinator`** parte **on foreground**. |
| Se esiste **pull History** o prevalentemente **push**. |
| Come **Options Android** ottiene i conteggi (**count query** vs fetch completo). |
| Semantica **cancel** (recuperabile vs sticky). |
| Comportamento **no‑op** reale (metriche insert 0 / idempotenza). |
| **Retry / backoff** implementati. |
| Eventuali aree **meno efficienti** → backlog Android **separato** solo se problema **reale e misurato**. |

**Output richiesto post‑audit:** tabella Android vs iOS **completata**; decisione esplicita (**adottare concetto Android su iOS**, **mantenere iOS se corretto**, **ibrido**); eventuale **follow‑up Android** separato.

---

## 6. Audit Supabase (checklist DDL reale `/Users/minxiang/Desktop/MerchandiseControlSupabase`)

Osservazione già dalla migration `task045_sync_events.sql` (planning‑read): dominio **`sync_events` MVP = `catalog` + `prices`**, **NON `history`/session**.
Conseguenza: **History parity app** deve affidarsi principalmente alla tab **`shared_sheet_sessions`** (keyset/page `updated_at` / `id` da verificare su DDL cumulativo RLS/indici nei file TASK‑012/TASK‑013/TASK‑038/TASK‑040…) **oppure** aprire **BLOCKED_SCHEMA_OR_POLICY + task migration** solo se progetto sceglie di estendere `sync_events`/RPC (**non decidere ora**).

Lista verifica EXECUTION‑forward:
1. Coppia **owner consistency** UUID iOS/Android post login (live gated).
2. Indici paging `owner_user_id + updated_at` / keyset suggerito per incremental session pull.
3. Delete/tombstone semantics cross‑device (**non auto wipe silent**).
4. Grant **SELECT authenticated owner‑scoped**, upsert parity app client.
5. RPC `record_sync_event` parametri MVP — **copre‑no History** ⇒ fallback esplicito o nuovo backlog backend.

---

## 6A. Contratto incrementale multi‑dominio

*Ordine di lettura consolidato questo file:* **§6A → §6E** (parallelismo domini); **§6B → §6F** (cursor/watermark + crash); **§6C → §6D** (History catena + refresh post‑commit).

### Domini sync

| Dominio | Locale iOS | Remoto Supabase | Segnale remoto atteso MVP | Fallback / note |
|---------|-------------|-----------------|----------------------------|-----------------|
| Catalogo prodotti | SwiftData `Product` | `inventory_products` | `sync_events` **catalog** bounded | paging/preview deterministico grande dataset |
| Fornitori | SwiftData `Supplier` | `inventory_suppliers` | idem catalog domain | ↑ |
| Categorie | SwiftData `ProductCategory` | `inventory_categories` | idem catalog domain | ↑ |
| Prezzi | SwiftData `ProductPrice` | `inventory_product_prices` | `sync_events` **prices** *(se presenti)* | keyset paging prezzi |
| History/session | SwiftData `HistoryEntry` bridge | **`shared_sheet_sessions`** | **Non assumere** copertura affidabile sync_events MVP | fallback **chiave proprietario + keyset paging** (**obbligatorio verificabilità**) |

### Push locale *(scope aggregato EXECUTION deve provare granularità planner esistenti)*

Deve incluso quando dirty/pending progetto marca tali artefatti:

| Origine modifiche locale | Artefatti rappresentativi *(non lista API)* |
|---------------------------|--------------------------------------------|
| **Database** screen | product, supplier, category, storico **`ProductPrice`** |
| **Generated** flow | catalog apply dalla griglia foglio; price history deltas; bridging verso **`HistoryEntry` / session fingerprint** quando policy lo richiede |
| **History** tab | rename / edits valori editableJSON / stato complete / overlay exportabile se incluso fingerprint remoto progetto |

Regole correnti progetto TASK‑109 PLANNING (**da rispettare EXECUTION**, non reinventare filosofia security):

| Policy |
|--------|
| push **safe-compatible** prima del pull mutativo se pending locali compatibili (**D109‑03** punto 3) |
| pending remoto collide con classe remote incoming ⇒ **`needsReview`**, non overwrite silenzioso |
| ack pending solo dopo **successo remote** confermabile + stato bridge stabile progetto (**read‑back quando definito nei servizi esistenti**) |
| no push anonimo proprietario sconosciuto / mismatch JWT |
| no `service_role` client né bypass RLS |

### Pull remoto

| Requirement |
|-------------|
| sempre **owner‑scoped authenticated** SELECT/UPSERT per app pubblica Release |
| **paging / keyset** per grandi volumi — no caricamento full catalog accidentalmente mentre si cerca aggiornarne un sotto‑insieme storico piccolo quando evitabile |
| dedupe per **remoteID / fingerprint / logical key progetto definito nella History bridge table** prima insert |
| batch apply + salvataggi contesto BG + **invalidate UI OSSERVABILE dopo commit**

### History fallback procedural steps *(EXECUTION verifica DDL indici/order columns reali prima query finale)* 

1. `SELECT … FROM shared_sheet_sessions WHERE owner_user_id = currentOwner ORDER BY updated_at, id LIMIT pageSize` *(sostituire `…` dopo audit DDL effettiva — PROJECT non inventare colonne fuori migrazioni reali).*  
2. confronto contra bridge+fingerprint **`HistoryEntry` locale mappings** progetto TASK‑108 lineage.  
3. insert/update batch SwiftData sicuro/idempotente.  
4. refresh count `historySessions`.  
5. refresh lista `HistoryView`.  
6. **cursor storico locale dedicato**, separabile da cursore catalogo/prezzi (**no implicit merge cursor errato**).  

Chiudibilità vietata EXECUTION‑review se History resta **`0`/vuota quando remoto proprietario dimostrabile contenente righe reconcile applicabili (evidence gated operatore).**

---

## 6E. Multi-domain concurrency and blocking policy

Un problema **in un dominio** non deve bloccare **inutilmente** domini **indipendenti**.

### Regole

- Pending locale **catalogo** **non** deve bloccare **automaticamente** **pull History safe**, salvo **conflitto** sullo **stesso** record / logical key / bridge progetto (**evidence obbligatoria se si blocca** — **§ 9 S14**).
- Pending locale **History** **non** deve bloccare **automaticamente** **pull ProductPrice** (idem salvo overlap reale misurabile).
- **Owner mismatch** blocca tutti i domini **mutativi**.
- **Auth / RLS globale** blocca tutti i domini **remoti**.
- **Dirty locale** blocca solo il **record** o **bucket** correlato, **non** l’intero database, se esiste **recovery marker** (**§ 6B** partial apply).
- Se **non** esiste recovery marker per partial apply affidabile, il **bucket interessato** va in **`needsReview`**, ma gli altri domini **safe** possono **procedere**.
- Il **summary finale** deve separare in modo leggibile: **applied** domains; **skipped**; **blocked**; **failed**.

### Esempio target

Se **catalogo** ha pending dirty ma Supabase contiene **5** nuove `shared_sheet_sessions` **safe**:

- catalogo può restare **`needsReview`** / pending dove policy richiede;
- **History** deve comunque poter sincronizzare le **5** sessioni se **owner** e payload sono **validi**;
- Options deve poter mostrare **`History sessions = 5`** quando applicabile;
- la tab History deve mostrare le sessioni (**§ 6C**).

---

## 6B. Cursor, watermark, ack e recovery contract

### Cursor separati per dominio

Usare cursor/watermark **separati** almeno per: **catalog**, **prices**, **history/session**, **eventuale outbox / pending push**.  
**Non** usare un solo cursor globale se può far **saltare** History o prezzi.

### Cursor per owner

- Ogni cursor è **owner‑scoped**.
- Cambio account → invalida o sospende cursor precedenti (**§ 4D**).
- Owner mismatch → blocca apply/push mutativo (**nessun avanzamento cursor** “per sbaglio”).
- Nessun cursor avanza per owner ≠ quello autenticato.

### Avanzamento cursor

Cursor/watermark avanzano **solo** dopo, in ordine logico:

1. fetch remoto completato per la finestra;  
2. decode valido;  
3. apply locale riuscito;  
4. `save`/commit SwiftData confermato;  
5. summary locale aggiornato;  
6. bridge/fingerprint aggiornato ove applicabile.

**Vietato:** avanzare dopo **sola preview**; dopo fetch e **prima** di apply; ack pending **prima** di successo remoto verificabile; dichiarare **no‑op** se un dominio previsto **non** è stato controllato.

### Partial apply

Se una pagina ha elementi **safe** e **blocked**:

- applicare **solo** safe se esiste **recovery marker** affidabile per gli item applicati;  
- cursor avanza **solo** fino all’ultimo item confermato sicuro;  
- item blocked restano in **review queue**;  
- se **non** esiste recovery marker → classificare bucket/pagina come **`needsReview`** (allineato §3 Cold launch).

### Recovery dopo errore

- Apply interrotto → **non** avanzare cursor oltre gli item confermati; **non** cancellare pending locali; **non** mostrare “Database updated”;  
- sync successivo deve **riconciliare senza duplicare**; evidence con **applied/skipped/failed** per dominio.

### Second sync no‑op

Dimostrare: nessun insert duplicato logico; pending non persi; cursor che **non** avanza senza lavoro; History **non** riscaricata come duplicato.

---

## 6F. Force quit / crash recovery policy

La sync deve essere **recuperabile** se l’app si chiude o **crasha** durante una fase **mutativa**.

### Regole

- Durante **preview**: **nessun** cursor avanza (**§ 6B**).
- Durante **apply**: cursor avanza **solo** per item/batch già **confermati** / committed secondo invariante progetto.
- Durante **pending push**: pending locale resta **pending** finché **ack remoto** non è confermato (policy ACK esistenti).
- Durante **History apply**: bridge / fingerprint viene scritto **solo dopo** **`HistoryEntry` locale salvata** coerente.
- Se app si chiude fra **remote write** e **local ack**, il prossimo sync deve **riconciliare** con read‑back / dedupe — **non** creare duplicato logico ovvero perdita ACK silenziosa.
- Se app si chiude fra **local save** e **UI refresh**, al prossimo launch il summary deve **ricalcolare** counts da SwiftData (**non** “all good” se counts stale).

### Evidence richiesta

Almeno **test simulato / unit** (§8D o equivalente EXECUTION‑forward):

- interrupted **before** cursor commit;
- interrupted **after** local save **before** summary refresh;
- repeated sync **reconciles** senza duplicates;
- pending resta **visibile** se ack **mancante**.

Se test **crash / force‑quit** reale è troppo costoso, documentare **fake‑service test** **+** playbook manuale in evidence (**non** dichiarazione PASS ora).

---

## 6C. History/session visibility contract

Catena end‑to‑end da verificare in EXECUTION:

`Supabase shared_sheet_sessions` → decode payload → **`HistoryEntry` SwiftData** → **`fetchCount` Options** → **`HistoryView` (`@Query` / lista)`

### Requisiti

| Requisito | Dettaglio |
|-----------|-----------|
| Filtro default | **`All`** — le sessioni remote **non** nascoste da filtro mese/data di default. |
| Timestamp | Normalizzazione **UTC → display locale** coerente nell’UI. |
| Parse fallisce | Nessuna **sparizione silenziosa**; fallback visibile o warning privacy‑safe (no leak dati sensibili). |
| Options | Conteggio **`HistoryEntry`** efficiente (`fetchCount`). |
| Post apply BG | UI principale **osserva** il cambiamento (merge MainActor / notifiche / `@Query`). |
| Lista History | Aggiornamento **senza** riavvio app. |
| Secondo pull | **No‑op duplicativo** confermabile. |
| Dirty locale iOS | Sessioni dirty **non** sovrascritte dal cloud senza review. |

### Evidence minima History

- Count remoto **`shared_sheet_sessions`** owner‑scoped (read‑only sicuro quando possibile).  
- Count SwiftData **`HistoryEntry`**.  
- Count **Options**.  
- Righe **visibili** in **HistoryView**.  
- Secondo sync **no‑op**.  
- Screenshot **History non vuota** quando il remoto contiene sessioni applicabili.

---

## 6D. Post-commit UI refresh contract

Ogni **apply locale** riuscito deve pubblicare un **refresh osservabile** **dopo** il commit SwiftData.

### Domini da aggiornare

| Dominio committato | Refresh obbligatorio *(minimo — estendibile EXECUTION)* |
|--------------------|------------------------|
| Product / Supplier / Category | summary database locale; lista Database se visibile; **pending summary** |
| ProductPrice | conteggi / summary prezzo; righe Database visibili **se impattate** |
| History / session | **`HistoryEntry` count**; stato database Options; **`HistoryView` lista** |
| Pending push ack | pending summary; **cloud overview** / stato coordinator |
| Review resolution | coda review; **card Options**; **root banner** |

### Regole

- Se il commit avviene su **background** / detached `ModelContext`, la UI principale deve ricevere **notifica** o **invalidazione esplicita** (**allineamento DoR‑B B9**).
- Options **non** deve restare su **snapshot stale** dopo apply.
- HistoryView deve aggiornarsi **senza** riavvio app.
- Il refresh deve avvenire **dopo commit**, non dopo **sola preview**.
- Se il refresh fallisce, il summary finale deve indicare **updated but refresh pending** (o equiv. **DEBUG** / stato non ingannevole) — **non** messaggio tipo “all good” se counts/UI divergono.

### Evidence *(ogni run finale utile chiudibilità TASK‑109)*

- count **prima**;
- apply + commit osservabile;
- notifica / refresh pubblicato;
- count **dopo**;
- UI visibile **coerente** (**§ 8E** deve mappare riga Acceptance).

---

## 7. Onde EXECUTION (micro‑wave)

**Nota obbligatoria:** **Wave 1** = **EXECUTION DIAGNOSTICA** (solo riproduzione/misura/evidence, **zero** patch app). **Wave 2…7** = **EXECUTION IMPLEMENTATIVA** — **bloccate** finché **Gate 2** (**§ 8B**) non è soddisfatto.

### Wave 1 — EXECUTION DIAGNOSTICA: reproduce & trace runtime *(bloccante: nessuna modifica Swift / Kotlin / SQL)*

Classificazione: questa wave è **mutazione codice vietata** — rientra nel perimetro **EXECUTION DIAGNOSTICA** autorizzata da **Gate 1** (**§ 8B**), non nella EXECUTION implementativa.

**Obiettivo:** timeline causale **prima** di qualsiasi fix.

Metodologia obbligatoria:

| # | Scenario pass |
|---|----------------|
| 1 | Cold launch signed-in navigando Inventory (Home) prima tab. |
| 2 | Non aprire **Options** tra **≥10‑15 s**. |
| 3 | Osservare se parte **auto‑check** (instrumentation/logs privacy-safe §8A budget). |
| 4 | Aprire Options: misurare se **solo ora** accelera/avvia check differenziabile. |
| 5 | Tornare Inventory: verifica **banner root** e coerenza stringhe §3A. |
| 6 | Premere **`Sync now`**: osservare path review/recheck/cancel. |
| 7 | Ispezionare **History sessions** count locale Options. |
| 8 | Ispezionare **History tab lista**. |

La cartella **`docs/TASKS/EVIDENCE/TASK-109/`** deve contenere nominativamente, prima di autorizzare la Wave 2:

| File evidenza | Contenuto atteso sintetico |
|---------------|---------------------------|
| **`00-runtime-timeline.md`** | sequenza timestamps (launch→auth hydrate guess→checks→commits). |
| **`01-cold-launch-inventory-no-options.md`** | log + screenshot dopo attesa deliberata NO Options tap. |
| **`02-options-triggers-check.md`** | delta prima/post Options open conclusivo. |
| **`03-sync-now-review-state.md`** | comportamento presenter + stato machine inferito. |
| **`04-cancel-retry-state.md`** | cancel nested / retry adhesiveness instrumentation. |
| **`05-history-count-and-list.md`** | counts mismatch Supabase-vs-local se query read-only sicure gated. |

Media supplementari consentiti ma non sostitutivi: **screenshot / schermo‑video anonimizzati**, syslog redatto, estratti `operationID` se già instrumentation presente codebase corrente pre‑fix audit.

### Log schema minimo per Wave 1

Ogni **evento diagnostico privacy‑safe** deve **provare** a includere *(strumentazione disponibile permitting — quando assente ⇒ documentare lacuna in Wave 1)*:

| Campo | Descrizione |
|-------|-------------|
| `timestamp` | ISO **o** monotonic timestamp progetto‑safe |
| `operationID` | se disponibile |
| `source` | `rootForeground`, `optionsAppear`, `manualSyncNow`, `authRestored`, `scenePhase`, ecc. |
| `ownerHash` | redatto **o** literal `none` |
| `phase` | stato state machine (**§ 4B**) |
| `isBusy` | busy globale / coordinator |
| `selectedTab` | tab corrente, **se utile** al sintomo |
| `allowsCancel` | true/false |
| `reason` | motivo skip / cancel / fail **privacy‑safe** |
| `domain` | `catalog` / `prices` / `history` / `pending` |
| `counts` | **solo numeri aggregati**, nessun payload |

**Regole privacy**

- **niente** token;
- **niente** email completa;
- **niente** payload History;
- **niente** barcode / prodotti reali nei log;
- ID remoti possono essere **hashati** **o** omessi salvo **test prefix** controllato.

STOP Gate Wave 1 HARD *(resta in **EXECUTION DIAGNOSTICA** o torna a **PLANNING** se non misurabile)*:

| Condizione |
|------------|
| Impossibilità di riprodurre **o** misurare (es. auth assente) ⇒ **playbook manuale** + **nessuna** EXECUTION implementativa. |
| Gate non superato ⇒ **vietato** avviare **Wave ≥2** (implementativa) finché non si recupera osservabilità / sessione. |

### Wave 2 — EXECUTION IMPLEMENTATIVA: lifecycle app‑scoped unify *(prerequisito: Gate 2 §8B — evidenze Wave 1 complete)* 
Dedupe triggers; auth restore reschedule; rimuovere accoppiamento “Options è l’owner implicito dei job primari”.

### Wave 3 — EXECUTION IMPLEMENTATIVA: state machine + Review/Cancel UX cleanup
Stale sheet invalidazione; conferme nidificate whitelist; stato cancelled non‑sticky.

### Wave 4 — EXECUTION IMPLEMENTATIVA: safe automatic classify/apply pipeline
Invariant apply vs cursor/baseline dopo commit confermato locale.

### Wave 5 — EXECUTION IMPLEMENTATIVA: incremental pending push end‑to‑end
Database / Generated / History pending planner + acknowledgement read‑back remote.

### Wave 6 — EXECUTION IMPLEMENTATIVA: History/session parity runtime
Pull/push `shared_sheet_sessions`; Options count ↔ History `@Query`; **no duplicates** dopo second pass.

### Wave 7 — EXECUTION IMPLEMENTATIVA: E2E acceptance operator journey
cold launch→auto/no‑op/auto apply→manual Sync→Cancel/Retry→remote delta→cross tab History verify.

---

## 8. Test pianificati (EXECUTION‑forward — no PASS claim ora)

### iOS Automated
- Lifecycle: auto‑check **sans** navigazione Options dopo fake auth hydrate.
- No double‑trigger root+card simultaneous (mock scene + debounce verifier).
- `SyncNow` fresh operation idempotence vs stale reducer.
- no‑op ⇒ `isReviewSheetPresented == false` invariant (UI tests dove possibile).
- dirty prevents silent overwrite (**unit reducer**).

### Smoke manuale / Simulator checklist (dal brief utente)
Inventory first; cambio tab durante check alive; Sync now post‑no‑op chiaro singolo stato; Cancels niente doppio dialog inutile; History count dopo remote sessions.

### Live gated (**TASK109\_** prefix writes only)
counts Supabase ↔ SwiftData ↔ Android Room (**se device Android disponibile**) — playbook documentato quando auth assente ⇒ **PARTIAL playbook only**.

### Android tests **solo se** dopo Wave 6 si richiede fix parity lato JVM.

---

## 8A. Performance budget e regressione UI *(misurabile, non “sembra fluido”)*
La EXECUTION deve raccogliere **indicatori osservabili** (Instrumentation / Simulator / Instruments campione ridotto quando possibile) — **non affidarsi alla sola soggettività.**

### Budget nominale target

| Scenario misurabile | Target qualitativo tecnico EXECUTION deve verificare con numeri/logs |
|--------------------|----------------------------------------------------------------------|
| Cold launch signed-in | auto-check pianificabile **senza freeze first meaningful frame Inventory** (**non bloccare primo render**) |
| Options apertura durante sync attiva sul root coordinator | **vietato spawn job parallelo indipendente** (**D109‑01 watchdog**) |
| Scroll Options mentre sync lunga CPU/IO alto | mantenimento **≥ target frame budget percepibile** / nessuno stall >300ms bursts ripetuti su device reference |
| cambio Tab Inventory/Database/History durante lungo apply | tap / navigazione deve restare fluida (**target percepito &lt; ~300 ms** — da quantificare in EXECUTION con campione device/simulator) |
| History pull sintetico (5‑100 sessioni reconcile) | niente full-catalog refetch collegato inutilmente allo stesso pass |
| conteggi grandi catalogo nei riepiloghi Options | evitare materializzazioni enormi quando basta **`fetchCount`** (vedi refactor storico TASK‑108 lineage) |
| second sync no‑op | nessuna duplica logica statisticamente osservabile |

### Evidence misure richiesta aggiunta oltre §Wave1 base

Si richiede un’appendice **Performance pack** obbligatoria (timeline eventi + osservabilità `operationID`) oltre agli artefatti baseline Wave 1 (`00…05`).

| Deliverable tecnico PERFORMANCE |
|--------------------------------|
| Timeline timestampata: **`app_launch`**, **`auth_hydrated`**, **`operation_scheduled`**, **`network_fetch_started`**, **`apply_started`**, **`swiftdata_commit_ok`**, **`summaries_refresh_published`**, **`banner_idle_hidden`**. |
| Log privacy-safe strutturali keyed **`operationID`**. |
| Screenshot trio: *(a)* Inventory immediate post‑launch *(b)* root banner stato intermedio **prima Options** quando rilevante sintomo *(c)* Options mid‑sync stato card. |
| Confront triplo conteggi: **Supabase read-only gated** VS **SwiftData `fetchCount` / statistiche progetto** VS **righe History visibili nella UI**.

Classificazione deviazioni *(da usare nell’evidence pack, senza dichiarazioni PASS ora)*:

| Severità documentale | Indicatore tipico |
|----------------------|-------------|
| **Blocking** TASK‑109 closure | freeze scroll/tab Inventory riproducibile oltre soglia accettata definita nell’evidence |
| **Must-fix prima merge** | jank/tab switch ripetuto durante apply |
| **Accettabile con nota** | micro-flash banner &lt; soglia configurabile dopo misura EXECUTION |

---

## 8E. Traceability matrix — ogni acceptance deve avere evidence

La futura **EXECUTION** **non** può chiudere TASK‑109 con soli **test generici**. Serve una **matrice evidence** Acceptance → artefatto.

### Formato obbligatorio

Creare in evidence:

**`docs/TASKS/EVIDENCE/TASK-109/99-traceability-matrix.md`**

con tabella modello:

| Acceptance ID | Requisito | Evidence file | Test automatico | Screenshot/video | Stato | Note |
|---------------|-----------|---------------|------------------|-----------------|-------|------|

### Regole

- Ogni **stop condition S1…S14** deve avere **almeno una** riga (o raggruppamento esplicitamente giustificato).
- Ogni acceptance **lifecycle / coordinator** deve indicare **`operationID`** **o** prova equivalente (log schema §7 Wave 1 / performance pack §8A).
- Ogni acceptance **History** deve indicare: **count remoto**; **count SwiftData**; **count Options**; **righe HistoryView**.
- Ogni acceptance **Cancel / Review** deve indicare **screenshot** **o** **video**.
- Ogni acceptance **performance** deve indicare **timestamp** **o** **log**.
- Se una acceptance **non è testabile** per mancanza auth/device ⇒ stato = **`BLOCKED_WITH_PLAYBOOK`**, **non** PASS (**§ 9** bullet tracking).
- **Nessun** DONE se **`99-traceability-matrix.md`** è **assente** o **incompleta** (**§ 9 stop S12**).

---

## 8B. Two-step readiness gate — diagnostica prima, codice dopo

TASK‑109 distingue due livelli di readiness per evitare ambiguità **DoR vs Wave 1** *(Wave 1 è Execution, ma solo **diagnostica** e **non mutativa**)*.

### Gate 1 — `PLANNING` → **EXECUTION DIAGNOSTICA**

Consentito passare a un’**EXECUTION limitata** solo per:

| Consentito Gate 1 |
|-------------------|
| **Tracking reconciliation gate** (**sezione dedicata sopra**) soddisfatta: MASTER‑PLAN **`TASK‑109` attivo**/allineato **o nota evidence** esplicita se eccezione temporanea (**stesso PR documentale**) |
| Riproduzione sintomi e misura temporale |
| Raccolta **timeline**, screenshot/video, syslog **privacy‑safe** |
| Verifica se trigger è **root‑scoped** o **Options‑scoped** |
| Confronto conteggi **History** / Supabase / SwiftData (read‑only dove possibile) |

**Vietato in Gate 1**

| Vietato |
|---------|
| Iniziare Wave 1 con **MASTER‑PLAN IDLE** **o** `TASK‑109` non referenziato (**salvo nota+riscrittura MASTER nello stesso pass** consentita **solo markdown**) |
| Modificare **Swift**, **Kotlin**, **SQL**/schema/RLS/RPC Supabase dal client o backend repo |
| “Fixare direttamente” il bug osservato **senza** evidenza firmata Wave 1 |
| Dichiarare **fix**, **PASS**, **DONE** |

### Gate 2 — **EXECUTION DIAGNOSTICA** → **EXECUTION IMPLEMENTATIVA**

È consentito **patch codice applicativo** (Swift/iOS nei limiti TASK‑109) solo quando sono vere **congiuntamente** le condizioni seguenti:

| Condizione Gate 2 |
|-------------------|
| **Wave 1** ha generato file evidenza nominali (**`00…05`**) §7 |
| La timeline documenta **quale trigger avvia davvero** la sync |
| È stabilito se **Options crea o accelera** un job **indipendente** dal coordinator root |
| È stabilito se **History è saltata**, non salvata, o non osservata dalla UI |
| Sono noti **`operationID`**, **owner** coerente e **stato coordinator** al momento dei fatti |
| Strategia **single‑flight** confermata o da implementare con criteri misurabili |
| Piano esplicito **anti review stale** e **anti cancel sticky** (allineato **§ 4F**, **§ 4B** / **§ 4C**) |

### Regola bloccante

Se **Wave 1** **non** produce evidence sufficiente ⇒ il task resta in **EXECUTION DIAGNOSTICA** **oppure** torna a **`ACTIVE / PLANNING`** per integrare playbook / accesso sessione.  
**Execution implementativa “a intuito” è vietata.**

---

## 8C. Definition of Ready (DoR) — checklists dopo i gate §8B

TASK‑109 resta formalmente **`ACTIVE / PLANNING`** nel tracking finché **non** si dichiara (con atto/responsabile progetto) una transizione a **EXECUTION DIAGNOSTICA** o **EXECUTION IMPLEMENTATIVA** nel **MASTER‑PLAN** / file task conforme workflow.

### DoR‑A — per avviare **EXECUTION DIAGNOSTICA** *(Gate 1 §8B)*

| # | Condizione |
|---|------------|
| A1 | **MASTER‑PLAN** / task file **`TASK‑109 ACTIVE / PLANNING` (o fase coerente registrata)**; **nessun IDLE** implicito senza referenza + **nessun** altro ACTIVE non riconciliato (**regole complete: sezione Tracking reconciliation gate**). |
| A2 | **TASK‑108** resta storico **DONE / PASS_WITH_NOTES** (**non riaperto** come garanzia runtime). |
| A3 | Consensus: regressione **runtime/UX** misurabile, non solo copy. |
| A4 | **Wave 1 diagnostica** esplicitamente **autorizzata** come **EXECUTION non mutativa / non implementativa** (nessun requisito assurdo “Wave 1 completata prima di qualunque execution”). |
| A5 | Playbook minimo: device/simulator, account (se serve), strumenti log **redatti**. |

### DoR‑B — per avviare **EXECUTION IMPLEMENTATIVA** *(Gate 2 §8B, dopo Wave 1)*

| # | Condizione |
|---|------------|
| B1 | Evidenze Wave 1 **`00…05`** presenti e leggibili (**anche** se outcome = non riproducibile ⇒ **motivo** documentato). |
| B2 | **Wave 2…7** **non** iniziate finché Gate 2 non è soddisfatto (**regola bloccante §8B**). |
| B3 | Ownership **coordinator app‑scoped** nominata in review tecnica. |
| B4 | **Options = observer + `Sync now`** (**D109‑01**) ribadito. |
| B5 | Policy **push sicuro prima di pull mutativo** quando pending compatibile (**D109‑03**) o eccezione motivata. |
| B6 | Policy **no review su no‑op deterministico** (**D109‑06**). |
| B7 | Policy **cancel senza dialog annidato** (**D109‑07**). |
| B8 | Path **History** senza `sync_events` dominio history (**§ 6A / 6C / D109‑08**). |
| B9 | Pattern refresh UI post **`ModelContext` BG save** deciso a livello architetturale. |
| B10 | Elenco: **test automatici minimi** (inclusi **fake** §8D) + **smoke** runtime minimi. |
| B11 | **Stop conditions FINAL** che impediscono **DONE** se auto‑check / Sync now / History restano rotti (**§ 9**, **S1…S14** + §10). |

**Se una condizione DoR‑B fallisce ⇒ nessuna patch app** (resta diagnostica o PLANNING).

---

## 8D. Test harness architecture — fake coordinator prima del live

La futura **EXECUTION implementativa** **non** deve dipendere **solo** da live app‑auth. Servono test **deterministici** con **fake coordinator** / **fake services** (protocol‑oriented / dependency injection — dettaglio in review codice).

### Unit tests *(obiettivi minimi)*

| Scenario |
|----------|
| Root lifecycle schedula check **dopo** fake auth hydrate |
| **Options appear** **non** crea `operationID` indipendente |
| `scenePhase` active **coalesce** con operazione esistente |
| Manual **Sync now** invalida review stale |
| **No‑op** non apre review |
| Cancel operazione attiva → stato pulito + retry |
| Cancel review **non** diventa “sync failed” globale |
| **`operationID` cambia** su nuovo manual sync da idle |
| Stesso **`operationID`** osservabile da **root banner** e **Options** durante job attivo |
| Delta remoto **solo History** provoca sync anche se catalog/prices “zero change” |
| Cursor **non** avanza prima di commit apply (**§ 6B**) |
| **Owner mismatch** blocca push/apply |

### UI / snapshot tests *(dove fattibile)*

| Scenario |
|----------|
| Cold launch Inventory: banner/progress **o** no‑op pulito **senza** aprire Options |
| Options durante sync attiva: **stessa** operazione |
| Nessuna Review sheet stale dopo no‑op |
| Cancel: **nessun** doppio dialog |
| Count History in Options |
| History tab con sessioni fake sincronizzate |

### Live gated *(complementare, non sufficiente)*

| Regola |
|--------|
| Solo account **test/dev**; **no** `service_role`; **no** cleanup distruttivo |
| Prefisso righe test se si scrive remoto |
| Auth assente ⇒ **no** dichiarazione PASS live; **playbook manuale** in evidenza |

---

## 8F. Localization and accessibility gate

Ogni **nuova** superficie **pubblica** deve essere **localizzata** e **accessibile** (**EXECUTION IMPLEMENTATIVA** quando tocca stringhe — ma **specifiche** definite qui).

### Localizzazioni

Stringhe pubbliche **nuove o modificate**:

- **EN**;
- **IT**;
- **ES**;
- **ZH**.

**Vietato** in **Release**:

- copy tecnico tipo `fetch counts`, `baseline`, `cursor`, `sync_events` in UI pubblica (**già vietato anche §3A** — qui gate **hard** chiudibilità);
- stringhe solo in inglese sulla superficie pubblica;
- **DEBUG jargon** nella **card Options**.

### Accessibilità

- Root banner: **`accessibilityLabel` / value** coerenti con **fase** state machine (**§ 4B**).
- Progress: **non** annunci VoiceOver troppo frequenti (throttle / importante changes only).
- CTA **`Sync now`**, **`Review`**, **`Try again`**, **`Cancel`**: label **non ambigue**.
- **Dynamic Type** grande (**XL/XXL**): non nasconde CTA principali.
- Review sheet navigabile VoiceOver ordine logico:
  1. titolo;
  2. summary;
  3. domini impattati;
  4. azione primaria;
  5. azioni secondarie.

### Acceptance accessibilità *(EXECUTION deve evidenziare in **`99-traceability-matrix.md`** §8E)*

- Smoke Dynamic Type **almeno XL/XXL** su banner / Options / Review.
- Audit **VoiceOver** statico **o** manuale banner / card / sheet.
- **Nessuna** regressione tab bar coperta dal banner (**§ 3A / § D109 ergonomia**).

---

## 9. Acceptance criteria (bloccanti — traduzione operative)
Chiudibilità vietata **se** dopo EXECUTION+E2E reale (**evidence final build**) sussiste qualsiasi:
- Prima sync affidabile dipende dall’entrare in Options (scenario signed‑in online standard).
- Banner root **solo** dopo Options mentre utente sta su Inventory all’avvio (**salvo gated busy import reale dichiarato**).
- Sync now apre review/recheck stale su ciclo dichiarabile no‑op tecnico backend.
- No‑op causa sheet Review.
- Secondo layered Cancel spurio UX su path safe preview cancellabile soft.
- `Operation cancelled` senza correlazione causa utente/policy documentata teardown.
- `Try Again` ineffective / deadlock single‑flight.
- HistorySessions count **semanticamente falsi** (>0 remoti proprietari mentre UI 0 dopo pull atteso OK).
- History tab vuota con dati remoti applicabili dopo pull canonico dichiarato.
- Duplicazioni sessioni dopo re‑pull idempotente.
- Pending marcato ack prima read‑back se servizio definisce questo constraint.
- Remote safe modifiche non auto‑applicate con policy progetto dichiarando auto apply (**tests dimostrano classe safe** vs review).
- **Cursor/watermark avanza prima apply locale confermato** (invariant tecnico).
- **Nessuno smoke checklist / build evidence allineati** ⇒ **cannot close**.
- Divergenza evidence vs artefatto finale build review.

### Acceptance aggiuntivi UI/UX

- Cold launch firmato: Inventory mostra progresso cloud **oppure** conclude check **senza obbligo** di aprire Options (salvo caso **signed‑out / offline / busy import** dichiarato nell’evidenza).
- Entrare in Options durante un check attivo **non** crea un secondo job **indipendente** (coerenza `operationID` / single‑flight **D109‑01**).
- Uscire da Options **non** annulla un job root legittimo (salvo teardown esplicito tipo background / cambio account).
- `Sync now` con job già attivo: stesso job visibile **oppure** pulsante disabilitato con **motivo** chiaro (**nessun doppio orchestratore**).
- `Sync now` da idle: **nuova** `operationID` (invalida review summary precedenti **§ 4B**).
- **No‑op** ⇒ **nessuna** Review sheet.
- Review sheet ⇒ **solo se** esistono elementi concreti bloccati (**nessun foglio “Needs review” vuoto**).
- **`Recheck`** non è CTA primaria se esistono cambi **applicabili** con **`Apply reviewed changes`** (o equivalente localizzato).
- **Nessun secondo dialog** “Cancel” nidificato per check / preview **sicuri** (**D109‑07**).
- **`Operation cancelled`** solo dopo cancel reale utente **o teardown classificato** nella evidence (no errore fantasma).
- **`Try again`** riavvia davvero (**nuova** operazione, stato non sticky).
- La **tab bar resta utilizzabile** durante check/apply “ordinario” (**niente overlay modale globale** che blocchi navigazione Inventory).
- **Dynamic Type**: banner / card Options / sheet review restano leggibili senza compromettere l’uso operativo (barcode/numeri essenziali restano accessibili — validazione EXECUTION).

### Acceptance aggiuntivi sync / dati

- Pending **Database**: push sicuro eseguito **oppure** resta esplicitamente visibile/inventariato nei riepiloghi pending — **vietata perdita silenziosa** prima di ack/remoto quando policy lo definisce.
- Pending **Generated** (catalogo da foglio, prezzi storici, sessione): stesso comportamento del punto Database (**coerenza con `LocalPendingAggregatedPushPlanner` / accumulatori esistenti**).
- Pending **History** (rename, edit contenuti sessione, stato complete, parti di payload/fingerprint se tracciate): stesso comportamento richiesto sopra (**D109‑08**).
- Cambi remoti catalogo **safe** ⇒ **apply automatico** quando classificazione `safe`.
- Cambi remoti **ProductPrice** **safe** ⇒ **apply automatico** quando classificazione `safe`.
- Cambi remoti **History / `shared_sheet_sessions`** **safe** ⇒ **apply automatico** quando classificazione `safe`.
- **`Dirty` locale tracciato** ⇒ **mai** overwrite silenzioso ⇒ **`needsReview`** (o equivalente progetto).
- **Owner mismatch** ⇒ blocca push/apply mutativi (**nessun bypass**); solo recovery tramite riallineamento account / review esplicita.
- **Cursor / watermark** ⇒ avanzano **solo** dopo **`save`/`commit`** locale confermato per lo stesso ciclo (**invariante misurabile in EXECUTION / review codice**).
- **Secondo ciclo sync no‑op**: **zero** insert duplicati logici osservabile su **Product**, **Supplier**, **`ProductCategory`**, **`ProductPrice`**, **`HistoryEntry`**.

### Acceptance aggiuntivi lifecycle / coordinator

- Cold launch **non** richiede Options per **schedulare** check (salvo policy signed‑out/offline §4D).
- Auth hydrate tardivo rilancia **al massimo un** check auto coerente (**§ 4C**).
- Foreground ripetuto **non** crea job duplicati (coalescing osservabile).
- **Root banner** e **Options** osservano lo **stesso** `operationID` durante job attivo.
- **Options appear** **non** forza transizione `idle → checking` **se** la policy root non lo richiede (**no bootstrap parallelo**).
- **Manual Sync now** da idle → **`operationID` nuovo**.
- **Manual Sync now** durante job attivo → **nessun** job parallelo (**§ 4C single‑flight**).
- **Cancel utente** → **nessun** auto‑retry immediato in loop (**§ 4C backoff**).
- Errori di **rete** → `failedRecoverable` / backoff (**§ 4C**) — **non** `needsReview` salvo classi dati che lo richiedono esplicitamente.

### Acceptance aggiuntivi cursor / recovery

- Cursor **catalog / prices / history** separati **oppure** equivalenza **documentata** con test che provano nessuna perdita dominio (**§ 6B**).
- Cursor **owner‑scoped**; account switch coerente (**§ 4D**).
- Cursor **non** avanza prima di **commit** locale confermato (**§ 6B**).
- Pending **non** ackato prima di **remote success** verificabile quando la policy lo definisce.
- Apply parziale **non** perde item **blocked** (**§ 6B** partial apply).
- Recovery dopo failure: sync successivo **senza** duplicazione logica (**§ 6B**).

### Acceptance aggiuntivi account / offline

- **Signed‑out** → **nessun** messaggio **Operation cancelled** al posto dello stato account (**§ 4D**).
- **Offline** → uso locale non bloccato; banner offline coerente (**§ 3A / §4D**).
- **Account switch** → **nessun** merge silenzioso dati owner diverso (**§ 4D**).
- Errore **RLS/permission** → **non** mostrato come “serve Sign in” se **OAuth JWT** risulta ancora valido ma fallisce per permessi (**§ 4D**).

### Acceptance aggiuntivi tracking / evidence

- **`MASTER‑PLAN` iOS** e file **`TASK‑109`** concordano su **stato ACTIVE** e **fase** registrata (**nessuna divergenza silenziosa** — **tracking reconciliation gate**).
- **`TASK‑108`** resta **storico DONE / PASS_WITH_NOTES** — **non** riaperto come garanzia runtime TASK‑109.
- **Evidence Wave 1** esiste (**`00…05`**) **prima** di qualunque **patch Swift** (**Gate 2 §8B**).
- **`99-traceability-matrix.md`** (**§ 8E**) collega ogni stop **S1…S14** **e** le acceptance chiave ↔ evidenza / tipo verifica (**STATIC / BUILD / SIM / MANUAL** come da protocollo progetto).
- **Nessun** PASS **live** se auth/device **mancano**: stato accettabile solo **`BLOCKED_WITH_PLAYBOOK`** con playbook firmato (**non mascherare DONE**).

### Acceptance aggiuntivi ownership / UI refresh *(allinea **§ 4E / § 6D**)*

- **Root app shell / coordinator** è **owner logico** del job cloud (**single‑flight / operationID canonico**).
- **Options** è **observer** + **`Sync now` manuale** tramite coordinator — **non** job owner.
- **Root banner** e **Options card** mostrano lo **stesso** `operationID` quando **entrambe** dovrebbero riflettere il job attivo.
- Se root banner è **opzionalmente** nascosto in Options (**§ 3A Root banner visibility policy**), Options card deve mostrare **identica** fase / stato cancellabile.
- **Dopo commit History**, count Options **e** lista **HistoryView** si aggiornano **senza** riavvio (**§ 6D** evidence).
- **Dopo commit** ProductPrice / catalog apply, summary locale (**Options / pending / DB**) **non** resta **stale** nascosta (**§ 6D**).

### Acceptance aggiuntivi localization / accessibility *(§ 8F)*

- Tutte le stringhe **pubbliche** **nuove o modificate** sono in **EN / IT / ES / ZH**.
- **Nessun** copy tecnico **DEBUG**/schema nella UI **Release**.
- **Dynamic Type XL/XXL**: banner / Options card / Review sheet utilizzabili senza perdere **CTA primarie**.
- CTA **`Sync now` / `Review` / `Try again` / `Cancel`** hanno etichette accessibili coerenti con intento (**§ 8F**).

### Stop aggiuntivi (impediscono chiusura TASK‑109 / dichiarazione DONE operatore)

Chiudibilità **vietata** anche se **una sola** delle seguenti è vera **nella build finale** oggetto di review, **anche** se la suite automatica risulta green:

| # | Condizione severa |
|---|-------------------|
| S1 | Cold launch signed‑in “normale” ancora **dipendente** dall’aprire Options per **primo** check utile |
| S2 | **`Sync now`** o auto‑check lasciano **`Operation cancelled`** senza cancel utente/teardown classificato (**§ 4C / §9 bullet list**) |
| S3 | **`Recheck`** rimane CTA **primaria** quando esistono modifiche **applicabili** reali |
| S4 | **History** ≠ catena **§ 6C** (Options count / lista / remoto) dopo scenario applicabile documentato |
| S5 | Cursor avanza **fuori** sequenza **§ 6B** (preview‑only, pre‑commit, cross‑owner) |
| S6 | Fake harness **§ 8D** assente per i vincoli critici **single‑flight / operationID / cancel** — closure possibile **solo** se review documenta esplicitamente perché **non** fattibile e accetta rischio residuo **firmato** |
| S7 | **MASTER‑PLAN** e **TASK‑109** divergono su stato/fase **senza** nota di riconciliazione (**tracking**) |
| S8 | **Options** crea ancora un job **autonomo** non correlato al root coordinator (**§ 4E / § 8D**) |
| S9 | **Root banner** e **Options card** mostrano **`operationID` / stati** incoerenti per la **stessa** intent sync |
| S10 | **`Operation cancelled`** mostrato da **`CancellationError` tecnico** non classificato (**§ 4F**) |
| S11 | Dopo commit History, Options count **o** HistoryView restano **stale** senza refresh osservabile (**§ 6D**) |
| S12 | **`99-traceability-matrix.md`** assente o incompleta (**§ 8E**) |
| S13 | Nuove stringhe **pubbliche** non **localizzate quattro lingue** **o** **non accessibili** (**§ 8F**) |
| S14 | **Pending di un dominio** blocca domini **indipendenti** senza overlap reale né motivo/evidence (**§ 6E**) |

---

## 10. Output finale PLANNING *(revisione sicurezza gate + contratti)*
| Deliverable | Path / stato |
|-------------|----------------|
| File task creato | `docs/TASKS/TASK-109-ios-supabase-sync-lifecycle-ux-regression.md` |
| MASTER-PLAN iOS aggiornato task ACTIVE | `docs/MASTER-PLAN.md` |
| Evidence folder vuota/README | `docs/TASKS/EVIDENCE/TASK-109/README.md` |

Questa revisione del file task aggiunge / consolida nel planning:

| Aggiunta | Riferimento |
|----------|-------------|
| distinzione **EXECUTION diagnostica** vs **implementativa** + Gate 1/2 | **§ 8B** |
| **DoR** scissi per diagnostica vs implementativa | **§ 8C** |
| **Coordinator lifecycle contract** | **§ 4C** |
| **Cursor / watermark / ack / recovery** | **§ 6B** |
| **Policy account / offline / signed‑out** | **§ 4D** |
| **History visibility catena end‑to‑end** | **§ 6C** |
| **Harness test + fake coordinator** | **§ 8D** |
| **audit Android obbligatorio** (no TBD taciti) | **§ 5** |
| **Acceptance + stop severi** anti‑chiusura fragile | **§ 9** |
| **micro‑UX polish** anti regressione visiva | **§ 3A** |
| **Root banner visibility policy** | **§ 3A** |
| **Tracking reconciliation MASTER ⇄ TASK** | sezione gate + **Gate 1 §8B** |
| **Ownership matrix** | **§ 4E** |
| **Cancellation taxonomy** | **§ 4F** |
| **Multi‑domain concurrency** | **§ 6E** |
| **Post‑commit UI refresh** | **§ 6D** |
| **Force quit / crash recovery** | **§ 6F** |
| **Traceability acceptance → evidence** | **§ 8E** |
| **Localization / accessibility gate** | **§ 8F** |
| **Wave 1 log schema minimo** | **§ 7 Wave 1** |
| Stop **S7…S14** | **§ 9** |

Stato progetto nel **MASTER‑PLAN**: **`TASK‑109` `ACTIVE / REVIEW`** (execution Codex completata; TASK-109 non marcato DONE).

Stop conditions operative *(incrociamento brief + anti‑TASK‑108‑style closure)*:

| Emergenza | Azione |
|-----------|--------|
| Necessità schema/policy nuova indispensabile History via `sync_events` | **`BLOCKED_SCHEMA_OR_POLICY`** + task backend migration separato |
| Bug solo lifecycle wiring SwiftUI | fix iOS minimale; Android follow‑up backlog **non blocker** |
| Android meno efficiente vs target | backlog Android separato **solo** se audit §5 lo misura |
| **Violazione tabella stop §9** (**S1…S14**) o acceptance critici | **NON DONE** — continuare diagnostica o implementativa fino a risoluzione misurabile |
| **Tracking non riconciliato** (§ gate + **Gate 1 §8B**) | **solo markdown tracking** prima di Wave 1 ufficiale |

### Conferme esplicite PLANNING *(storico revisione gate + contratti)*
- **Zero** modifiche Swift / Kotlin / SQL / migration nel presente aggiornamento **.md**.
- **Zero** build / test / smoke **eseguiti** come richiesta di questo editing.
- **Zero** dichiarazioni PASS / DONE / REVIEW_PASS_FINAL / fix runtime completati.
- **`TASK‑109` e' stato poi promosso a `ACTIVE / EXECUTION DIAGNOSTICA` su override utente del 2026-05-15; Gate 2 e execution implementativa sono stati completati da Codex nello stesso giorno, con handoff a REVIEW.**

---

## Allegato — File TARGET audit EXECUTION *(checklist verbatim brief utente sintetizzata)*

### iOS
`iOSMerchandiseControlApp.swift`, shell Tab/Navigation, `AppNavigationNotifications.swift`, `ContentView.swift`, `OptionsView.swift`, `SupabaseManualSyncRelease*` family, Coordinator/Factory VM, Overview/Progress state structs, Pull/Apply/Inventory/ProductPrice snapshot services, Local pending planner/state, `HistorySessionSyncService.swift`, `HistoryView.swift`, `DatabaseView.swift`, `GeneratedView.swift`, `InventorySyncService.swift`, strings EN/IT/ES/ZH, XCTest files elencati nel prompt (**ViewModel/UI/Planner/Overview/InventorySyncTests** ecc.).

### Android
Percorso canonico progetto `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView` — file elenco brief (Application, Activities/Nav sync UI indicators, Repo, Session backup datasource, Coordinators History, Dao/Entities, Options & History screens, test TASK‑108 gated).

---

## Prompt utile *(estensioni PLANNING successive — solo markdown TASK‑109)*

```text
Estendi TASK-109 restando esclusivamente in PLANNING.

Raffina il piano con focus su:
1. coerenza MASTER-PLAN ↔ TASK file;
2. ownership matrix root coordinator / Options / Review / banner (**§ 4E**);
3. operationID condiviso e single-flight;
4. cancellation taxonomy (**§ 4F**);
5. root banner visibility policy (**§ 3A**);
6. post-commit UI refresh SwiftData → Options → HistoryView (**§ 6D**);
7. cursor/ack/recovery + force-quit safety (**§ 6B / § 6F**);
8. multi-domain concurrency catalog/prices/history (**§ 6E**);
9. traceability matrix acceptance → evidence (**§ 8E**);
10. localization/accessibility gate (**§ 8F**).

Vincoli obbligatori (non regressione processo):
- TASK-109: Stato ACTIVE / Fase PLANNING; NESSUN DONE / PASS / closure runtime / REVIEW_PASS_FINAL.
- Modificare SOLO docs/TASKS/TASK-109-ios-supabase-sync-lifecycle-ux-regression.md (salvo MASTER-PLAN se serve unicamente tracking reconciliation campo task attivo/stato — **solo markdown** prima di diagnostica nominalmente autorizzata).
- Zero patch Swift/Kotlin/SQL/migration/build/test/smoke in questa modalità pianificazione.
- Prima EXECUTION DIAGNOSTICA: Gate 1 §8B + tracking reconciliation gate; Wave 1 = solo evidence + **log schema §7** (**zero** modifiche Swift).
- Prima EXECUTION IMPLEMENTATIVA: Gate 2 §8B + DoR‑B §8C; **`99-traceability-matrix.md`** obbligatoria alla chiusura (**§ 8E / S12**).
- Nuove acceptance → §9 (**+ stop S-tier** quando chiudibilità vietata).
```

---

## HANDOFF suggerito (post review planning operativa)
| Campo | Valore suggerito |
|-------|------------------|
| Prossima fase | **EXECUTION DIAGNOSTICA — Wave 1 (Gate 1 §8B)** dopo handoff **`PLANNING → EXECUTION`** esplicitamente approvato |
| Prossimo agente responsabile EXECUTION | **CODEX** |
| Prima azione concreta | **(1)** Riconciliare **tracking** `MASTER‑PLAN.md` ⇄ questo file (**sezione gate**). **(2)** Poi popolare `docs/TASKS/EVIDENCE/TASK-109/00-runtime-timeline.md` *(build locale + syslog redatto + sequenza stato UI + **campi log §7 Wave 1 quando possibile**)* conforme **DoR‑A §8C** — **nessuna** patch Swift prima di Gate 2 |

---

## Execution (Codex) — EXECUTION DIAGNOSTICA / Wave 1

### 2026-05-15 00:33 -0400 — Avvio Wave 1 non mutativa

- Tracking riconciliato: `docs/MASTER-PLAN.md` e questo file indicano `TASK-109 ACTIVE / EXECUTION DIAGNOSTICA`.
- TASK-108 resta storico `DONE / PASS_WITH_NOTES`, non riaperto.
- Evidence iniziale creata in `docs/TASKS/EVIDENCE/TASK-109/00-preflight-tracking.md`.
- Worktree all'ingresso gia' dirty con modifiche Swift/test/localizzazioni e documentazione TASK-109 non committate; nessun revert eseguito, nessuna nuova patch app introdotta da questo pass di transizione.
- Prossimo passo consentito: Wave 1 runtime diagnostica con timeline/screenshot/log privacy-safe; patch Swift/Kotlin/SQL restano bloccate fino a Gate 2.

### 2026-05-15 01:30 -0400 — EXECUTION implementativa + verifica finale

#### Obiettivo compreso

Correggere la regressione iOS Supabase sync lifecycle/UX senza riaprire TASK-108: cold launch e foreground devono usare un owner app-scoped, Options deve osservare/manual-triggerare, no-op/warning-only non deve aprire Review, Cancel non deve essere sticky/nidificato, History/session deve restare dominio sync coperto e Options deve mostrare il conteggio History.

#### File controllati

- Tracking/evidence: `docs/MASTER-PLAN.md`, questo file task, `docs/TASKS/EVIDENCE/TASK-109/*`.
- iOS: `ContentView.swift`, `OptionsView.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncRemotePreview.swift`, `SupabaseManualSyncReleaseFactory.swift`, `HistorySessionSyncService.swift`, `HistoryImportedGridSupport.swift`, localizzazioni EN/IT/ES/ZH.
- Test: `SupabaseManualSyncViewModelTests.swift`, `SupabaseManualSyncReleaseUITests.swift`, `HistorySessionSyncServiceTests.swift`, `HistoryViewStateTests.swift`, `OptionsLocalDatabaseSummaryTests.swift`.
- Android audit: `MerchandiseControlApplication.kt`, `CatalogAutoSyncCoordinator.kt`, `CatalogSyncStateTracker.kt`, `CatalogSyncViewModel.kt`, `OptionsScreen.kt`, `InventoryRepository.kt`.
- Supabase audit: migrations `shared_sheet_sessions`, inventory RLS/catalog/prices, `sync_events`.

#### Piano minimo

1. Usare Wave 1 per classificare il bug reale prima delle patch.
2. Rimuovere ownership Options del lifecycle automatico e spostare l'auth/foreground scheduling nel root host.
3. Separare warning/sample/no-op da Review actionable.
4. Pulire Cancel review evitando il dialog annidato non mutativo.
5. Verificare History count/parity con test deterministici e runtime count UI.
6. Produrre evidence + traceability matrix e passare a REVIEW, non DONE.

#### Modifiche fatte

- `ContentView.swift`: root host sincronizza auth presentation context e rilancia il check foreground dopo hydrate/auth changes usando il ViewModel condiviso.
- `OptionsView.swift`: rimosso auto-start `.onAppear` / `.active`; Options resta observer + `Sync now`; rimosso dialog annidato "Cancel this review?" per review non mutativa.
- `SupabaseManualSyncRemotePreview.swift`: aggiunti conteggi `actionableReviewSignalCount` / `hasActionableReviewSignals`; warning/sample ProductPrice non classificano piu' Review.
- `SupabaseManualSyncViewModel.swift`: no-op/warning-only non apre Review, non lascia root banner `Review`, non usa staged/summary stale; `Sync now` usa operazione fresh/same engine; separati `hasReviewableStagedWork` e stato storico; progress completion usa `Sync completed with notes` per warning-only.
- Localizzazioni EN/IT/ES/ZH aggiornate per copy "completed with notes".
- Test aggiornati/aggiunti per no-op no Review, warning-only no Review, Cancel confirmations solo mutative, History pull/push/dedupe/dirty/owner mismatch e Options History count.
- Nessuna patch Android e nessuna migration/RLS/RPC Supabase.

#### Check eseguiti

- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — Debug build compila: XcodeBuildMCP `build_run_sim`, iPhone 15 Pro Max iOS 26.1, PASS, warnings `0`.
- ✅ ESEGUITO — Release build compila: `xcodebuild build -quiet -configuration Release`, iPhone 17 Pro iOS 26.5, exit `0`.
- ✅ ESEGUITO — Targeted XCTest lifecycle/coordinator/ViewModel/Release UI/History/Options/localization/pull/apply/ProductPrice/pending: PASS, result bundle `Test-iOSMerchandiseControl-2026.05.15_01-19-03--0400.xcresult`.
- ✅ ESEGUITO — Simulator smoke iOS: cold launch Inventory auto-check root banner; Options observer/manual; Sync now no stale Review; Dynamic Type XXXL Inventory/Options.
- ✅ ESEGUITO — Nessun warning nuovo introdotto: Debug XcodeBuildMCP diagnostics warnings `[]`; Release quiet build exit `0`.
- ✅ ESEGUITO — Modifiche coerenti con planning: matrix `docs/TASKS/EVIDENCE/TASK-109/99-traceability-matrix.md`.
- ✅ ESEGUITO — Criteri di accettazione verificati: PASS/PASS_WITH_NOTES dettagliati in matrix.
- ⚠️ NON ESEGUIBILE COMPLETO — Supabase live History non-empty pull: `shared_sheet_sessions` Wave 1 totale `0`; successivi count retry hanno colpito `ECIRCUITBREAKER`/`SUPABASE_DB_PASSWORD`. Nessuna evidence inventata; test deterministici coprono remote non-empty.
- ⚠️ NON ESEGUIBILE COMPLETO — Android runtime smoke: Android non modificato; audit statico parity completato e documentato, Gradle non rieseguito.

#### Rischi rimasti

- Supabase dev non aveva sessioni History applicabili; serve un futuro live seed scoped `TASK109_` se la review pretende evidence cross-platform History non-empty reale oltre ai test.
- Supabase CLI pooler ha temporaneamente bloccato nuove connessioni dopo retry paralleli; evitare ulteriori query finche' il circuito non si raffredda o configurare `SUPABASE_DB_PASSWORD`.
- Non e' stato acquisito un trace Instruments; performance evidence e' runtime smoke + large XCTest paging/apply, non profilo CPU.

#### Aggiornamenti file di tracking

- Evidence finale aggiornata in `docs/TASKS/EVIDENCE/TASK-109/`.
- Traceability matrix creata: `docs/TASKS/EVIDENCE/TASK-109/99-traceability-matrix.md`.
- Questo task passa a `ACTIVE / REVIEW`; responsabile `Claude / Reviewer`.

## Handoff post-execution (Codex → Claude)

| Campo | Valore |
|-------|--------|
| Prossima fase | **REVIEW** |
| Prossimo responsabile | **Claude / Reviewer** |
| Stato task | **ACTIVE** |
| Verdict executor | **READY_FOR_REVIEW / PASS_WITH_NOTES** |
| Evidence principale | `docs/TASKS/EVIDENCE/TASK-109/99-traceability-matrix.md` |
| Build/test anchor | Debug XcodeBuildMCP PASS; Release build PASS; targeted XCTest PASS (`Test-iOSMerchandiseControl-2026.05.15_01-19-03--0400.xcresult`) |

Reviewer focus richiesto:

- Confermare che warning-only ProductPrice preview non debba piu' produrre root Review banner.
- Confermare che l'assenza di dataset live `shared_sheet_sessions` non blocchi REVIEW se i test History non-empty passano.
- Confermare che Android resti solo audit/no patch per TASK-109.

### 2026-05-15 02:25 -0400 — REVIEW completa Codex + fix autorizzato

#### Obiettivo compreso

Revisionare severamente TASK-109 sul working tree finale, correggere problemi reali se trovati, rieseguire build/test/smoke, validare Supabase History non-empty con dati test owner-scoped e chiudere DONE solo se tutte le stop condition risultano chiuse.

#### File controllati

- Tracking/evidence: `docs/MASTER-PLAN.md`, questo file task, `docs/TASKS/EVIDENCE/TASK-109/99-traceability-matrix.md`, `docs/TASKS/EVIDENCE/TASK-109/100`...`110`.
- iOS runtime/code: `ContentView.swift`, `OptionsView.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncRemotePreview.swift`, `SupabaseManualSyncReleaseFactory.swift`, `CloudSyncOverviewState.swift`, `CloudSyncProgressState.swift`, `SupabasePullPreviewService.swift`, `SupabasePullApplyService.swift`, `SupabaseInventoryService.swift`, `SupabaseProductPriceApplyService.swift`, `SwiftDataInventorySnapshotService.swift`, `LocalPendingAggregatedPushPlanner.swift`, `LocalPendingAggregatedPushStateStore.swift`, `HistorySessionSyncService.swift`, `HistoryView.swift`, `DatabaseView.swift`, `GeneratedView.swift`, localizzazioni EN/IT/ES/ZH.
- Test iOS: ViewModel/coordinator/lifecycle/Release UI/History/Options/localization/pull/apply/ProductPrice/pending suites.
- Supabase dev: `shared_sheet_sessions`, `sync_events`, inventory tables, owner hash, index live.
- Android parity: repo `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`, lifecycle/coordinator/Options/History payload static audit.

#### Piano minimo

1. Non fidarsi del report execution: verificare tracking, diff, evidence e test.
2. Applicare solo fix realmente necessari.
3. Validare History live non-empty creando una sessione test owner-scoped.
4. Rerun build/test finali.
5. Aggiornare matrix/verdict senza chiudere DONE se R4 resta bloccata.

#### Modifiche fatte

- `SupabaseManualSyncViewModel.swift`: direct/root sync ora sincronizza History durante il dry-run solo se non ci sono apply catalog/prezzi staged; con staged apply, History viene sincronizzata nel path post-apply.
- `SupabaseManualSyncViewModelTests.swift`: aggiunto `testDirectSyncDefersHistoryUntilPreparedApplyCompletes`.
- Localizzazioni EN/IT/ES/ZH: copy Release `Fetching cloud counts...` sostituita con copy piu' utente-centrica `Checking cloud updates...` e traduzioni equivalenti.
- Evidence review creata: `100-review-preflight.md` ... `110-review-final-verdict.md`.
- Traceability matrix aggiornata a verdict bloccato, con `S11`/`S12`/History live `BLOCKED_WITH_PLAYBOOK`.

#### Check eseguiti

- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — Debug build compila: XcodeBuildMCP Debug build simulator PASS, warnings `0`.
- ✅ ESEGUITO — Release build compila: XcodeBuildMCP Release build simulator PASS, warnings `0`.
- ✅ ESEGUITO — Nessun warning nuovo introdotto: build diagnostics Debug/Release warnings `0`; test log contiene solo warning standard AppIntents metadata extraction del test bundle.
- ✅ ESEGUITO — Targeted XCTest finale: PASS su iPhone 17 Pro iOS 26.5, `** TEST SUCCEEDED **`, xcresult `Test-iOSMerchandiseControl-2026.05.15_02-16-00--0400.xcresult`.
- ✅ ESEGUITO — Localizzazioni: `plutil -lint` EN/IT/ES/ZH PASS.
- ✅ ESEGUITO — Supabase seed test: creata `1` riga `TASK109_REVIEW_HISTORY_20260515_0622Z` in `shared_sheet_sessions`; owner hash `ad3d747e936ccd13ed305b1d8a3fb9558ac1e1a0081b9728b3aec2f14f06b1c8`; count remoto owner `0 -> 1`.
- ✅ ESEGUITO — Android parity audit: static/source audit, nessuna patch Kotlin necessaria.
- ⚠️ NON ESEGUIBILE — Pull iOS History live non-empty: app runtime signed-out/account issue; ASWebAuthenticationSession non ha ripristinato una sessione valida; Options resta `History sessions, 0`.
- ⚠️ NON ESEGUIBILE — Second sync History live no-duplicate: dipende dal primo pull signed-in, quindi bloccato.
- ⚠️ NON ESEGUIBILE — Full VoiceOver manual run/Instruments trace: non richiesti come blocker separati dopo verdict R4 bloccato; static accessibility/screenshot e performance smoke eseguiti.

#### Rischi rimasti

- Blocker: serve app-auth valida su Simulator/device iOS per pullare la riga `TASK109_REVIEW_HISTORY_20260515_0622Z` e chiudere R4.
- Test data retained intenzionalmente: `shared_sheet_sessions.display_name = TASK109_REVIEW_HISTORY_20260515_0622Z`; cleanup consigliato dopo validazione.
- Pooler Supabase CLI sensibile a query parallele: usare query singole/cooldown o configurazione DB password corretta durante rerun.
- Android runtime Gradle non rieseguito perche' Android non e' stato modificato; parity corrente e' static/source-grounded.

#### Aggiornamenti file di tracking

- TASK-109 resta **ACTIVE / REVIEW — CHANGES_REQUIRED / BLOCKED_WITH_PLAYBOOK**.
- `docs/MASTER-PLAN.md` aggiornato per riflettere che TASK-109 non e' DONE.
- Conditional DONE confirmation utente **non consumata** perche' il verdict finale non e' APPROVED.

## Handoff review bloccata (Codex → OWNER/Claude)

| Campo | Valore |
|-------|--------|
| Prossima fase | **REVIEW — CHANGES_REQUIRED / BLOCKED_WITH_PLAYBOOK** |
| Prossimo responsabile | **OWNER / App-auth required** |
| Stato task | **ACTIVE** |
| Verdict review | **BLOCKED_WITH_PLAYBOOK** |
| Evidence principale | `docs/TASKS/EVIDENCE/TASK-109/110-review-final-verdict.md` |
| Matrix finale | `docs/TASKS/EVIDENCE/TASK-109/99-traceability-matrix.md` |

Playbook richiesto:

1. Ripristinare una sessione app-auth valida nell'app iOS.
2. Eseguire `Sync now` o cold launch auto-check.
3. Verificare `ZHISTORYENTRY > 0`, Options `History sessions > 0`, History tab non vuota.
4. Eseguire secondo sync e verificare no duplicate.
5. Pulire o confermare retention della riga `TASK109_REVIEW_HISTORY_20260515_0622Z`.
