# TASK-063 — Supabase production-safe sync orchestrator — solo planning iOS

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-063 |
| **Titolo** | Supabase production-safe sync orchestrator planning iOS |
| **File task** | `docs/TASKS/TASK-063-supabase-production-safe-sync-orchestrator-planning-ios.md` |
| **Stato** | ACTIVE |
| **Fase attuale** | PLANNING |
| **Responsabile attuale** | Claude / Planner (review documentale pianificazione) |
| **Data creazione** | 2026-05-07 |
| **Ultimo aggiornamento** | 2026-05-07 — micro-rifinitura finale documentale: error taxonomy user-facing (**§4.g**), metriche/osservabilità privacy-safe (**§4.h**), planning freeze / non-execution boundary (**§4.i**), RQ9–11 + checklist planning review; correzioni typo/markdown (**§4.b** Cancellation, **§4.e** preflight); **READY FOR PLANNING REVIEW**, **non** READY FOR EXECUTION — **senza** codice/tests. |
| **Ultimo agente** | Cursor / Planner |

## Dipendenze

- **Dipende da**
  - **TASK-062** (**DONE / Chiusura**) — validazione operativa controllata UI DEBUG drain (Modalità A; anti-scope confermati).
  - **TASK-061** (**DONE**) — UI DEBUG `#if DEBUG` per outbox drain.
  - **TASK-060** (**DONE**) — `SyncEventOutboxDrainService` manuale, bounded batch, replay TASK-059.
  - Contesto tecnico **DONE**: **TASK-038** auth Google/Supabase, **TASK-039/040** pull/apply, **TASK-041–047** manual push baseline-gated, **TASK-048–051** ProductPrice, **TASK-053–059** slice `sync_events`/outbox/recorder.
  - **TASK-043** baseline/fingerprint persistence SwiftData.
- **Sblocca** *(candidati, non impegni nel presente file)* — slice operative **TASK-064…TASK-070+** descritte sotto **§5**; EXECUTION orchestratore solo dopo review PLANNING, override utente e file task futuri (**nessun file creato in TASK-063**).

## Scopo

Definire **solo in markdown** il passaggio concettuale da: base iOS **manuale**, **DEBUG** per parti sensibili, **controllata** (pull/apply, push catalogo/ProductPrice separati, outbox enqueue + drain on-demand **solo DEBUG UI** dopo TASK-061) → verso una **prossima orchestrazione sync production-safe**, **senza** implementare in questo task alcuna sync automatica, worker, BGTask, Realtime o drain implicito.

**Non è EXECUTION.** Nessun Swift, nessun test obbligatorio, nessuna chiamata live.

## Contesto workspace

- **Repo:** `/Users/minxiang/Desktop/iOSMerchandiseControl` (solo iOS da modificare in futuri task).
- Android: **solo intent funzionale** documentato nei task storici (**TASK-070** head-of-line retry *Android*, **TASK-071** `record_sync_event` / `PayloadValidation`); **nessun Kotlin** nel perimetro TASK-063 — **non** usare questo come modello UX iOS.
- Supabase: contratto **`sync_events`** / RPC **`record_sync_event`** dalla migration tipica **`20260424021936_task045_sync_events.sql`** sul clone progetto correlato (es. `MerchandiseControlSupabase`), **solo lettura** — **vietato** `db push`, SQL nuovo, modifica RPC/RLS in TASK-063.

---

## Anti-scope rigido (TASK-063)

- **Vietati:** patch Swift/`project.pbxproj`, build/Xcode test obbligatori, chiamate Supabase live, SQL/migration/RPC/`db push`, codice Android, **auto-drain**, **timer**, **`BGTask`**, **Realtime**, **worker/sync automatico**, **cleanup/delete/truncate/reset** outbox, **full sync** Product/ProductPrice, **creazione file** `TASK-064*.md` o altri task in questo turno.
- **Vietato** dichiarare TASK-063 **DONE** o passare a **EXECUTION** da questo planning.

---

## Criteri di accettazione *(contratto review documentale TASK-063)*

- [ ] Decisioni **D63-01…D63-08** presenti e coerenti.
- [ ] §4 include run modes (**§4.a**), boundary (**§4.b**), UX Release (**§4.c**), modello stato/phase (**§4.d**), efficienza (**§4.e**), invarianti (**§4.f**), error taxonomy user-facing (**§4.g**), osservabilità privacy-safe (**§4.h**), planning freeze (**§4.i**) e **`SupabaseManualSyncCoordinator`** come nome preferito.
- [ ] UX Release futura descritta (SwiftUI nativo) senza implementazione.
- [ ] Ordine slice **TASK-064…TASK-070+** allineato a **§5**.
- [ ] Planning review checklist compilata come guida (**non** check operativi runtime).
- [ ] Presenti **§4.d**, **§4.e**, **§4.f**, **§4.g**, **§4.h**, **§4.i**, **§7.b** (*review questions*).
- [ ] `docs/MASTER-PLAN.md` coerente con **TASK-063 ACTIVE / PLANNING**.

---

## Decisioni

| ID | Decisione | Alternativa scartata | Motivazione | Stato |
|----|-----------|----------------------|-------------|--------|
| **D63-01** | **Strategia iniziale: manual-first.** Nessuna sync automatica in questa fase progettuale. | Timer/worker impliciti, BGTask „leggeri“ | Ridurre rischio sui dati e mantenere controllo esplicito dell’utente. | **attiva (planning)** |
| **D63-02** | **UI Release futura:** solo voce tipo **„Sincronizzazione cloud guidata“.** In Release **non** mostrare termini tecnici: outbox, `sync_events`, drain. | Card con jargon da sviluppatore in produzione | UX prodotto: l’utente deve capire *controllare e allineare*, non leggere infra. | **attiva (planning)** |
| **D63-03** | **Diagnostiche DEBUG:** strumentazione tecnica (card outbox, letture `sync_events`, dettaglio batch) resta **`#if DEBUG`**. | Unificare UI DEBUG e Release | Separare tooling sviluppatore da percorso utente. | **attiva (planning)** |
| **D63-04** | **Drain in Release:** mai come azione isolata tipo „drain outbox“. Eventuale invio eventi pendenti solo **dentro** una **run guidata** del coordinator, con conferma e stato sintetico chiaro. | Pulsante dedicato „Invia eventi“ senza contesto | Minore errore operativo; coerenza con **D63-02**. | **attiva (planning)** |
| **D63-05** | **Ordine slice:** prima **TASK-064** — hardening outbox (`sending` stale / recovery post-crash); **poi** coordinator. | Coordinator UI sopra stato outbox fragile | Evitare UX e logica orchestrata su invarianti non ancora resilienti. | **attiva (planning)** |
| **D63-06** | **TASK-065** = coordinator **dry-run** / state machine con **solo fake services/mocks**; **senza rete live.** | Prototipo UI subito | Validare ordinamento gate, partial, cancel, reentrancy prima delle view. | **attiva (planning)** |
| **D63-07** | **Baseline policy conservativa:** non aggiornare baseline dopo **solo** push incrementale finché non esiste **decisione esplicita** in task separato. | Bump baseline dopo ogni push | Riduce loop sync e falsa sensazione di parity locale/remota. | **attiva (planning)** |
| **D63-08** | **Partial success sempre visibile:** ogni run futura deve distinguere esiti utente‑comprensibili (tutto ok / parziale / bloccato / login / bisogna pull‑apply ecc.), senza richiedere i log tecnici. | Esito binario „ok/errore“ opaco | L’utente deve sapere cosa resta da fare (**D63-02**, **§ UX**). | **attiva (planning)** |

---

## Planning (Claude)

### Obiettivo

Documentare la transizione da sync manuale/DEBUG (**post‑TASK‑062**) verso orchestrazione production-safe mediante **`SupabaseManualSyncCoordinator`**, con documento **review-ready come planning** (architettura e criteri), **mai** equivale a autorizzazione **EXECUTION** o a specifica Swift rigida fine-grained (**§4.d–§4.i**: *concetti*, non impegni API), finché la review PLANNING e i task TASK‑064+ non lo decidono.

### Analisi, approccio, rischi
**Analisi** §1–§3. **Approccio**: gate sequencing + run modes + boundary + modello output + efficienza + invarianti **§4**; ordine backlog **§5**; gate review **§7.b**. **Rischi** §3 e **§8**.

### File coinvolti *(futuri — nessuna modifica in TASK-063)*
Coordinatore **preferito**: **`SupabaseManualSyncCoordinator`** (`@MainActor`, DI). Servizi orchestrati tipici: `SyncEventOutboxDrainService`, `SyncEventOutboxDrainDebugViewModel` (**solo DEBUG**), `SyncEventOutboxEnqueueService`, `SupabaseManualPushService` / preflight correlate, `SupabasePullPreviewService`, `SupabasePullApplyService`, `SupabaseCatalogBaselineReader` / `Writer`, `SupabaseAuthViewModel`, recording eventi tramite **`SyncEventRecording`** (implementazione live già isolata — **TASK-058**).

### Handoff post-planning
**READY FOR PLANNING REVIEW** — vedi **§9** (**non** READY FOR EXECUTION).

---

### §1 — Stato attuale iOS dopo TASK-062

- **Outbox drain:** `SyncEventOutboxDrainService.drainOnce` (**TASK-060**): `hardLimit`, `fetchScanLimit` cappati, reentrancy per owner, head‑of‑line safe, cancellation restore.
- **UI drain:** `SyncEventOutboxDrainDebugViewModel` + card in `OptionsView` **`#if DEBUG`** (**TASK-061**): conteggi locali only; conferma prima del drain live.
- **Validazione TASK-062:** Modalità A / no‑live‑drain — nessuna assunzione di sync orchestrata Release.
- **Separazione rimasta:** push catalogo, ProductPrice, pull/apply, enqueue outbox + drain sono **percorsi disgiunti** lato UX — nessun flusso Release unico con gate ordering condiviso.

### §2 — Cosa esiste già *(inventario tecnico sintetico)*

| Area | Componenti / note |
|------|---------------------|
| **Auth** | `SupabaseAuthViewModel`, `SupabaseAuthService` (**TASK-038**); plist locale. |
| **Baseline / fingerprint** | `SupabaseCatalogBaselineWriter` / `Reader`, SwiftData (**TASK-043**). |
| **Pull / apply** | `SupabasePullPreviewService`, `SupabasePullApplyService` (**TASK-039/040**). |
| **Push catalogo** | Servizi manual push + preflight (**TASK-041–047**); enqueue outbox (**TASK-057**). |
| **ProductPrice** | **TASK-048…051** — **percorsi separati** dall’invio eventi verso drain. |
| **sync_events read-only** | **TASK-053/054**. |
| **Outbox** | Entry, store, replay payload (**TASK-055/057/059**). |
| **Recorder isolato** | `SupabaseSyncEventLiveRecorder` / transport (**TASK-058**): **nessun** uso diretto ampio di client nel dominio alto livello. |
| **Drain DEBUG** | **TASK-060/061**, smoke **TASK-062**. |

### §3 — Gap verso sync «production-safe»

1. Nessun orchestratore singolo che ordini **auth → baseline → (pull) → push → (enqueue già fatto dai push) → eventuale invio pendenti dentro run guidata** con esito **`D63‑08`**.
2. Drain RPC oggi ancorato a **DEBUG**; Release necessita mapping su **„Sincronizzazione cloud“** (**D63‑02**, **D63‑04**).
3. **`sending` stale** — recovery fuori G2 (**TASK-060**); da **TASK-064** prima del coordinator visibile.
4. Lock cross‑step (push + fasi coordinator) non unificato (**solo** drain reentrancy oggi).
5. Partial trans‑servizio (**TASK‑057**) senza surfaced run‑level (**D63‑08**).
6. Rischi loop pull/push mitigando con **D63‑07** e policy coordinator (cooldown direzione solo in EXECUTION futura).

### §4 — Proposta di architettura futura

**Nome tipo preferito (Swift): `SupabaseManualSyncCoordinator`** — orchestratore **`@MainActor`** con dipendenze iniettate. Il nome **`SyncOrchestrator`** resta solo **alternativa generica**, scartata come nome tipo principale perché troppo ambigua rispetto al dominio Supabase/sync manuale documentato nei task precedenti.

**Gate** concettuali (unchanged intent, ora sotto coordinator):

| Gate | Ruolo |
|------|--------|
| Auth / owner | Sessione valida e owner coerente. |
| Baseline | **D63‑07** — non aggiornare dopo push incrementale senza task dedicato. |
| Pull/apply *(opzionale)* | Solo se la run include allineamento remoto locale. |
| Push catalog / ProductPrice | Delega ai servizi esistenti + conferme UX. |
| Invio pendenti (**non** mai bottone Release „drain”) | Solo dentro **`guidedManual`**, dopo conferme (**D63‑04**). |

---

#### §4.a — Run modes proposti

| Mode | Ruolo |
|------|--------|
| **`dryRun`** | Nessuna **scrittura remota** tramite coordinator; calcolo esito sintetico e fasi raggiunte. Obiettivo principale **TASK‑065**. |
| **`guidedManual`** | Run avviata dall’utente; pull/preflight/push/coordinamento drain **solo dopo** `confirmationDialog` dove servono mutation remote. Primo candidato **Release**. |
| **`debugDiagnostics`** | Solo **`#if DEBUG`**: conteggi outbox, preview `sync_events`, dettagli tecnici (**D63‑03**); **non** mescolare con card Release (**D63‑02**). |
| **`automatic`** | **Fuori scope** fino a decisione prod separata (**TASK‑070+**). **Non** è roadmapped come inevitabile: resta opt‑in backlog / override esplicito. |

---

#### §4.b — Boundary tecnici

- Il coordinator **non** deve usare direttamente **`SupabaseClient`** (stesso principio **`TASK‑058`** / drain **TASK‑060**): solo servizi/protocolli già estratti o da estrarre in wrapper sottili.
- Il coordinator **non** deve contenere mapping costanti / shape RPC **`record_sync_event`** — resta dentro **`SyncEventRecording`** / transport.
- Orchestrazione = **delega ai servizi esistenti** + composizione sequencing + aggregated outcome (**D63‑08**).
- **Ogni fase** deve restituire un **tipo di esito stabile** (enum/struct dedicate), non Bool ambiguo.
- **Lock / reentrancy** per **`owner`/session**: una run guided attiva ⇒ secondo innesco ⇒ `alreadyBusy` o equivalente (allineabile a **`SyncEventOutboxDrainService`** lesson).
- **Cancellation:** propagare `Task` / `CancellationError`; mai segnare run success completa se lo step cancellato era obbligatorio.
- **Cleanup outbox** (truncate/delete bulk): **vietato** nel coordinator (**stesso anti‑scope progetti sync_events**).

---

#### §4.c — UX futura consigliata per Release (SwiftUI nativo)

*Solo pianificazione — nessuna `View` né `ViewModel` in TASK‑063.*

La UI Release deve **somigliare a una card/schermata iOS nativa** (Impostazioni/Opzioni o area Cloud): **non** pannello tecnico da toolbox, **non** pattern ispirati a Android/Compose.

**Contenitore suggerito:** `Form`, `Section`, `NavigationStack` (eventuale `sheet`), coerenti con Apple HIG — posizionamento preciso nella gerarchia in task futuri.

**Copy orientato all’utente (esempi — tutti localizzabili):**

| Uso | Testo suggerito |
|-----|-----------------|
| Titolo/card | „Sincronizzazione cloud“ |
| CTA primaria | „Controlla e sincronizza“ (**run `guidedManual`**) |
| Stato | „Tutto aggiornato“ |
| Modifiche in sospeso | „Ci sono modifiche da inviare“ |
| Sessione/auth | „Serve accedere di nuovo“ |
| Parziale | „Sincronizzazione parziale“ (**D63‑08**) |

**Scheda/card — struttura attesa:**

- **Stato sintetico** in alto (badge o riga secondaria leggibile da VoiceOver).
- **CTA primaria** univoca („Controlla e sincronizza“).
- **Dettagli** espandibili (`DisclosureGroup`, `sheet`, `NavigationLink`), non dump di stato macchina.
- **`ProgressView`** mentre la **run è attiva**.
- **`Button`/CTA disabilitati** durante `runInProgress` (anti doppio tap; allineamento **§4.e**).

**Messaggi tecnici vietati nella UI Release (stringhe visibili all’utente):** tra cui **outbox**, **drain**, **sync_events**, **RPC**, **`record_sync_event`**, **payload**, **retryable** — sostituire con linguaggio comportamentale („modifiche da inviare“, „invio incompleto“, „riprova“).

Secondary: „Dettagli“ solo se serve approfondire senza jargon.

| Pattern SwiftUI | Uso nella run |
|----------------|---------------|
| **`confirmationDialog`** | Solo quando restano mutazioni remote da confermare (**§4.e**: niente conferma se preflight ⇒ no-op). |
| **`alert`** | Blocchi o errori; **non** basarsi sul solo colore per comunicare errore (**a11y**). |

**Copy partial (umano):** „Alcune modifiche sono state inviate, ma resta qualcosa da completare. Puoi riprovare.“

**Dynamic Type:** layout respirabile; righe multilinea e linee guide non solo simboliche; massima densità evitabile.

**Accessibilità (VoiceOver / UIAccessibility):**

- `accessibilityLabel` esplicito su „Controlla e sincronizza“ e „Dettagli“.
- Stato run leggibile dalla sintesi VoiceOver (**non solo** colore).
- Errori e **partial success** comunicati anche con voce/struttura, non tinta sola (**D63‑08**).

**Componenti SwiftUI suggeriti (nativi):** `Form`, `Section`, `NavigationStack`, `.sheet`, `confirmationDialog`, `alert`, `ProgressView`.

**DEBUG:** card tecniche esistenti (TASK‑061…) restano **`#if DEBUG`** e **non** si mescolano con questa UX (**D63‑03**).

Ripetizioni tap su errore: preferire **`alert`** + ripetizione della run guided, senza bombardare conferme nella stessa transizione UI.

---

#### §4.d — Modello di stato/output del futuro coordinator

*Nomi tipo **concept planning** (`SupabaseManualSync*` …): delineano architettura e review; **non** sono né API definitive né ambito TASK‑063. Il nome tipo Swift finale può divergere nelle implementazioni TASK‑065+.**

**`SupabaseManualSyncRunMode`** — come la tabella §4.a ma a livello *tipo concettuale*:

| Caso concettuale | Nota |
|-------------------|------|
| `dryRun` | Nessuna mutazione remota coordinata dalla run (**TASK‑065** principale bersaglio). |
| `guidedManual` | Run utente‑avviata, conferme dove serve (**Release** primo candidato). |
| `debugDiagnostics` | Solo DEBUG (**D63‑03**). |
| `automatic` | **Fuori scope** (**TASK‑070+**, opt‑in prod). |

**`SupabaseManualSyncPhase`** — ordine pipeline *logico*, non timetable fissa tutte le ramificazioni:

| Fase concettuale | Ruolo sintetico |
|------------------|-----------------|
| `authCheck` | Sessione valida / owner (**D63‑08** surfaced se KO). |
| `baselineCheck` | Coerenza baseline policy (**D63‑07**); **singola lettura/decision** per run (**§4.e**). |
| `localPendingCheck` | Preflight locale read‑only (**§4.e**): catalogo/ProductPrice/events pending senza scrivere ancora remote. |
| `remotePreview` | Opzionale: preview remoti/read‑only quando la run include allineamento. |
| `userConfirmation` | Gate prima di outbound network „costoso“. |
| `catalogPush` | Delega ai servizi push catalogo esistenti. |
| `productPricePush` | Delega a ProductPrice se applicabile/policy invariata. |
| `pendingEventsFlush` | Invio pendenti **solo dentro** guided manual (**D63‑04**), senza jargon UI. |
| `finalRefresh` | Rilettura sintetica conteggi/stato dopo step (privacy‑safe aggregates). |
| `summary` | Costruisce **`SupabaseManualSyncRunSummary`**. |

**`SupabaseManualSyncPhaseOutcome`** — esito *per singola fase* (concept):

| Esito concettuale | Quando usarlo *(planning)* |
|-------------------|---------------------------|
| `skippedNoWork` | Preflight/zero pending — fase omessa (**§4.e**). |
| `completed` | Fase conclusa con successo vincoli correnti. |
| `partial` | Alcune azioni dentro la fase ok, parte no (**D63‑08** surfaced a monte summary). |
| `blocked` | Precondizioni mancanti (baseline, auth, policy). |
| `failedRetryable` | Errore transitorio mappabile su retry servizio (**non** parole „retryable“ in UI Release — **§4.c**). |
| `failedNonRetryable` | Errore non recuperabile dalla run (**D63‑08**). |
| `cancelled` | Utente/OS ha annullato; **mai** assimilare a `completed`. |

**`SupabaseManualSyncRunSummary`** — aggregato finale UX:

- **Stato utente finale**: enum/struttura alta livello („Tutto aggiornato“, parziale, login, errore…) mappabile su **§4.c**.
- **Fasi eseguite / fasi saltate** (identificatori di phase astratti — aggregate/privacy‑safe, vedi anche **§7**).
- **Quantità sintetiche privacy‑safe** (zero payload/PII nei messaggi pubblici).
- **`prossimoSuggerimentoUX`**: suggerimento user-facing („Riprova“, „Accedi“, „Allinea dal cloud dopo un aggiornamento“… senza jargon **§4.c**).
- **Errore localizzabile** opzionale (chiavi `String`/`LocalizedStringKey` pianificate nei task futuri — **§7 locale**).

Incoerenze tra PhaseOutcome e Summary vanno finite in progettazione **TASK‑065** (dry‑run prima che la rete renda osservabile il comportamento ambiguo).

---

#### §4.e — Efficienza e no‑duplicate‑work *(decisioni planning)*

- **Preflight read‑only aggregate** prima di qualsiasi ramo confermabile: decidere una sola volta quali downstream chiamare (**§4.d** `localPendingCheck` + dove serve `remotePreview`).
- **`confirmationDialog`**: **non mostrarlo se non c’è nulla da inviare/mutare in rete** (risultato preflight vuoto ⇒ skip o stato „Tutto aggiornato“ **§4.c**).
- **Baseline**: **massimo una decisione forte per run** (non rileggerla in loop dentro la stessa run).
- **Push catalogo:** **non invocarlo** se preflight ⇒ zero modifiche pendenti conformi alla policy **preflight** vigente (**TASK‑041 lineage** preservata nei task EXECUTION futuri).
- **ProductPrice push:** skip se zero prezzi/candidati pendenti per quella policy.
- **Flush invio pendenti eventi:** skip se il preflight conta **zero lavoro utile** in outbox (**TASK‑060**, e **TASK‑064** dopo hardening `sending`).
- **Summary:** stato finale **una sola** surface principale sulla card („summary card“ UX), derivata da **`RunSummary`** — evitare tre banner concorrenti.
- **Anti‑loop §4:** niente automatismo **pull → push → pull** concatenato dentro la **stessa** run guidata; eventuali cicli esterni solo con decisione/task separati (**non** TASK‑063).
- **Anti doppio tap:** **run lock** owner/session‑scoped (**§4.b**) coerente con **§7** test matrix.
- **Batch**: preferire **limiti bounded** dei servizi esistenti (**TASK‑051**, **TASK‑060**…) invece di nuove mega‑query dedicate al coordinator (**minimo cambiamento** progettuale).

---

#### §4.f — Invarianti tecnici da proteggere *(checklist alta priorità)*

*(Riprende e rinforza §4.b; deve restare vera per tutte le EXECUTION TASK‑065+)*

| # | Invariante |
|---|------------|
| 1 | **Nessun** uso diretto di **`SupabaseClient`** nel tipo coordinator. |
| 2 | **Nessun** parsing/mapping **`record_sync_event`** dentro il coordinator (resta **`SyncEventRecording`/transport TASK‑058**). |
| 3 | **Nessun** cleanup distruttivo outbox nel coordinator (**delete/truncate**/reset massivi). |
| 4 | **Nessun** aggiornamento baseline **implicito** post‑push incrementale (**D63‑07** — serve task/policy esplicito). |
| 5 | **Nessun** auto‑flush eventi/remoto fuori una **run manuale guidata** (**D63‑01**, **D63‑04**). |
| 6 | **Nessun** `Timer`, `BGTaskScheduler`, Realtime subscriber introdotti dal coordinator prima di backlog **TASK‑070+**. |
| 7 | **Nessuna** mutazione remota senza **`confirmationDialog`** (o equivalenza UX esplicita conforme §4.e su „nulla da fare“) quando la run prevede write. |
| 8 | **Cancellation ⇒ mai `completed`/„tutto aggiornato“ finto** sulla run globale (**D63‑08** compatibile VoiceOver/copy). |
| 9 | **Partial success** sempre surfaced all’utente finale (**non** swallowed). |
| 10 | DEBUG diagnostics (**§4.a `debugDiagnostics`**) ≠ Release (**§4.c**) — segregazione compilazione e navigazione (**D63‑03**). |

---

#### §4.g — Error taxonomy user-facing

*Solo planning: tradurre gli errori tecnici futuri in stati UX comprensibili — **nessuna** implementazione in TASK‑063.*

| Origine tecnica (interna / log DEBUG) | Stato UX Release (esempio IT — localizzabile **IT / EN / ES / ZH** in task futuri) |
|---------------------------------------|-----------------------------------------------------------------------------------|
| Auth / sessione scaduta | „Serve accedere di nuovo“ |
| Baseline assente / invalida | „Serve riallineare i dati dal cloud“ |
| Nessun lavoro locale pendente (**preflight** vuoto / no-op) | „Tutto aggiornato“ |
| Errore rete temporaneo / failure transitorio | „Connessione non riuscita. Puoi riprovare.“ |
| **Partial** push catalogo/ProductPrice **o** invio pendenti eventi incompleto | „Sincronizzazione parziale“ |
| Errore contratto / schema non recuperabile (non retryable nel dominio orchestrazione) | „Sincronizzazione non completata. Serve un controllo tecnico.“ |
| Cancellazione (**Task** / **CancellationError** propagati dalla run) | „Sincronizzazione annullata“ |
| Errore sconosciuto / non classificato | „Errore imprevisto durante la sincronizzazione“ |

**Vincoli Release:** nella UI pubblica **non** mostrare **outbox**, **drain**, **sync_events**, **RPC**, **payload**, **retryable** né equivalenti visibili. Il dettaglio tecnico resta in **log / diagnostica DEBUG** (**D63‑03**) — non nel copy primario (**§4.c**).

Allineamento: **`RunSummary` / stato utente finale** (**§4.d**) + copy **§4.c** (**D63‑02**, **D63‑08**).

---

#### §4.h — Metriche e osservabilità privacy-safe

*Solo planning — il coordinator futuro può emettere **log / metriche sintetiche privacy-safe**; servono debug/review (**non** sostituire la UX **§4.c**).*

**Consentiti** (aggregati / categorie, senza contenuto identificabile utente‑visibile):

- run started / finished  
- phase started / finished (identificatore fase **astratto**, non payload né business fields)  
- phase outcome (**categorie** — allineabile a **§4.d** e **§4.g**)  
- **counts aggregati** (es. N fasi, M tentativi, totali sintetici)  
- durata approssimativa della run  
- **error category** (enum/struttura interna; mappa su stato UX non tecnico quando serve surfaced)

**Vietati** nei log pubblici, nelle metriche osservabili fuori dal team e nella UI Release (**D63‑02**, **§4.c**, **§4.g**):

- barcode testuali, nomi prodotto, nomi fornitore/categoria in chiaro  
- **payload JSON raw**, **`entity_ids` raw**, dump di righe remoti/locali  
- token, credenziali, email, URL con query sensibili (riuso sanitization pattern esistenti ove previsto)

---

#### §4.i — Planning freeze / non-execution boundary

- **TASK‑063 congela** architettura, vincoli, ordine slice (**§5**), invarianti (**§4.f**) e gate review (**§7**). **Nessuna** sezione autorizza codice Swift, modifiche Xcode, EXECUTION né handoff EXECUTION-ready.  
- I tipi concettuali **`SupabaseManualSync*`** (**§4.d**, **§4.g**) sono **solo concetti**: **non** firme Swift obbligatorie; nomenclatura e moduli definitivi restano nei file task **TASK‑065+**.  
- **TASK‑064** dovrà aprire **un file `.md` task separato** con scope propri, CA, anti-scope e test pianificati **esplicitamente** — **non** ricavabili tacitamente solo da questo documento.  
- **Qualunque modifica alla UI SwiftUI Release reale** (card **§4.c**) parte da **TASK‑067** — o da un task autorizzato esplicitamente con pari obbligo di scope (**non** da TASK‑063).

---

**Collegamento tecnico PhaseOutcome ↔ UX**

Il summary utente deve derivare da **§4.d** (**`PhaseOutcome`** per‑fase + **`RunSummary`**) e dalla **mappa stato non tecnico** (**§4.g**), **senza** propagare jargon infra (**§4.c**). Retry e backoff restano nei servizi / mock (**TASK‑065**) prima della UI pubblica obbligatoria.

---

### §5 — Slice progressive consigliate *(descrizione only — zero file `.md` creati ora)*

Ordine fisso (**D63‑05**, **D63‑06**) e **motivo della sequenza**: **stabilità outbox prima del coordinator**, **coordinator deterministico prima della UI pubblica**, **UI stabile prima del live QA**, **pianificazione delete prima di automazioni**.

| Ordine | ID | Scopo sintetico | **Non deve fare** | **Perché qui** |
|:-----:|----|-----------------|-------------------|----------------|
| **1** | **TASK-064** | Hardening outbox **`sending`** stale / recovery post‑crash; invarianti store SwiftData sicuri (**head‑of‑line intent** ispirabile al TASK‑070 *Android storico*, non UX). | **Nessuna** UI Release/card „Sincronizzazione cloud“; nessun coordinator completo pubblico | Senza questo, il coordinator/UI rischia wedge locale↔ RPC (**§3**) — blocca affidabilità (**D63‑05**). |
| **2** | **TASK-065** | **`SupabaseManualSyncCoordinator`** in modalità **`dryRun`**: state machine (**§4.d**) + fake/mocks (**D63‑06** — **rete live assente**) + XCTest sul percorso sintetico. | UI SwiftUI Release; ambienti harness live obbligatori; **mutazioni dirette remoti dalla shell coordinator** (**§4.f**) | Prima la logica deterministicamente testabile (**senza socket** quando i fake coprono le fasi chiave §7.b Q1); poi la grafica (**D63‑06**). |
| **3** | **TASK-066** | **`ObservableObject`/ViewModel** non‑DEBUG: stati alta levatura (**§4.c** summaries), osservabile da UI minima/host di debug interno (**UI minima oppure assente**). | Grafica cliente finale (**§4.c** ricca); flussi Compose/Android | Consente review stati/accessibilità/copy senza bloccare sulla polish visiva (**TASK‑067** dopo). |
| **4** | **TASK-067** | **UI SwiftUI nativa Release** (**§4.c**): card iOS vera, localization keys, conferme native. | Accoppiare card DEBUG tecnica sulla stessa surface utente (**D63‑03**) | È quando l’esperienza prodotto diventa pubblica dopo logica TASK‑065‑066 stabile conceptually. |
| **5** | **TASK-068** | **Validazione live controllata** dataset piccolo / staging (SIM/manual controllati, privacy‑safe). | Espansione feature core lì dentro; caricare regressione infra non correlata | Prova comportamento fuori mocks — dopo UI esiste flusso osservabile. |
| **6** | **TASK-069** | **Planning** outbound delete/tombstone + rapporto „full sync/eventi“. | Implementazione outbound massiva immediata dentro lo stesso task | Domanda domino/architettura prima di comportamenti più aggressivi lato rimozione/sync (**§8**). |
| **7** | **TASK‑070+** | **Realtime / BGTask** *solo* se **TASK‑068** ok + **decisione prodotto** — **opt‑in**, **non** default inevitabile (**D63‑01**). | Introduzione silenziosa background sync come premessa di TASK‑067 | Automazione resta **scelta separata** esplicita utente/business. |

---

### §6 — Ulteriori vincoli e riferimento incrociato

La tabella **Decisioni** (**D63‑01…08**) e le sottosezioni **§4.a–§4.i** definiscono i vincoli da rispettare prima dell’implementazione tecnica **TASK‑064+**. Dettaglio da congelare nei task operativi (non in TASK‑063):

- mapping preciso **Phase → servizio reale** e quali fasi sono opzionali in `guidedManual`,
- strategia **`sending` stale** (codice e test in **TASK‑064**),
- chiavi `LocalizedStringKey` finali e **Dynamic Type** snapshot review.

---

### §7 — Matrice test pianificata *(per TASK‑065+ — non eseguire in TASK‑063)*

| ID | Scenario | Livello suggerito |
|----|-----------|-------------------|
| T63-P01 | Auth assente → abort immediato, zero outbound aggregato (dry-run coordinator) | STATIC / XCTest |
| T63-P02 | Baseline assente/`invalidated` → fase bloccata segnalata (**D63‑07**) | STATIC / XCTest |
| T63-P03 | Baseline **`valid` ma stale** (semantic da definire in TASK‑064+) → comportamento deterministico FAIL o branch UX | XCTest fake |
| T63-P04 | enqueue fallito dopo push terminale → **partial** (**TASK‑057**) surfaced a livello run | XCTest fake |
| T63-P05 | `drainOnce` errore di rete a metà run → **partial** + `remainingRetryable` surfaced | MOCK `SyncEventRecording` |
| T63-P06 | **Cross-step reentrancy:** doppio tap „Controlla e sincronizza“ durante run | XCTest VM / UI test |
| T63-P07 | **Cancellation** durante push **prima** della fase invio pendenti (guidata): nessun **success globale** falso | XCTest async |
| T63-P08 | Push OK globale locale + drain fase failure → stato **partial** + copy (**D63‑08**, **§4.c**) | Integration fake |
| T63-P09 | Token/sessione scaduta **durante run** mid-flight | MOCK session |
| T63-P10 | Outbox con entry **`sending` stale** (post TASK‑064 behavior) dentro scenario guided | Stateful fake store |
| T63-P11 | **Release string grep/static:** nessuna string Release con termini tecnici vietati (**D63‑02**) | STATIC / localization tests |
| T63-P12 | **Accessibilità** etichette CTA („Controlla e sincronizza“, „Dettagli“): `accessibilityLabel` coerenti | Manual / UI XCTest |
| T63-P13 | Localizzazioni **IT / EN / ES / zh-Hans** pianificate per stringhe UX nuove | Localization parity tests (futuri) |
| T63-P14 | Sim iPhone smoke end-to-end (**post‑TASK‑068**) | SIM / MANUAL |

#### §7.b — Review questions prima di Execution futura

Domande cui il reviewer deve poter rispondere **„sì/condizione documentata/N.A.“** **prima** di autorizzare EXECUTION degli slice coordinator/UI:

| # | Domanda |
|---|---------|
| RQ1 | Il coordinator può essere testato **senza rete** (mock/fake covering **§7** caso base)? |
| RQ2 | **Ogni fase** (**§4.d `SupabaseManualSyncPhase`**) può essere osservabile con **`SupabaseManualSyncPhaseOutcome`** tipizzato (non Bool ambigu)? |
| RQ3 | La UI Release (**TASK‑067**, **§4.c**) comunica **`partial`/blocchi** solo con copy/user strings — senza jargon né log tecnici embedded? |
| RQ4 | Esiste **delimitazione netta DEBUG vs Release** (compilazione + navigazione) conforme **D63‑03**, **§4.a** e **§4.f** #10? |
| RQ5 | È previsto **`runLock`** che impedisca **due run concorrenti** per owner/sessione (**§4.e**, **§7 T63‑P06**)? |
| RQ6 | È garantito il **vietato aggiornamento baseline implicito** post‑push (**D63‑07**, **§4.f** #4) fino a nuovo contratto prod? |
| RQ7 | È garantito il **vietato cleanup distruttivo outbox nel coordinator** (**§4.b/f**)? |
| RQ8 | Il **primo** task EXECUTION suggerito dopo review resta confermabilmente **TASK‑064 outbox**, non saltare alla UI coordinator? |
| RQ9 | Gli **errori tecnici** futuri hanno **traduzione UX non tecnica** documentata (**§4.g**) coerente con **§4.c** (**D63‑02**)? |
| RQ10 | **Log / metriche** previsti (**§4.h**) sono **privacy-safe** e segregati dalla copy Release? |
| RQ11 | È **chiaro** che i tipi **`SupabaseManualSync*`** (**§4.d**, **§4.i**) sono **concetti planning**, **non** API Swift obbligatorie? |

Risposte negative ⇒ rivedere planning o backlog **senza EXECUTION**.

---

### §8 — Anti-scope riepilogo

Nessuna implementazione di coordinator/UI in TASK‑063; nessuna automazione garantita (**D63‑01**, **§4.a `automatic`**); nessuna promessa Retrofit/Android UX.

---

### §9 — Handoff finale

- **TASK-063 resta ACTIVE / PLANNING.** **READY FOR PLANNING REVIEW.** **Non DONE.** **Non EXECUTION.** Il documento non autorizza Coding/Swift nei confini TASK‑063.
- **Revisione pianificazione consigliata:** leggere Decisioni **D63‑01…08**, blocchi **§4.a–§4.i**, backlog **§5**, domande **§7.b**.
- **Dopo una review PLANNING favorevole + override utente:** il primo intervento operativo consigliato resta **TASK‑064** — hardening **`sending` stale** (**D63‑05**), **solo** previa creazione del file task e handoff EXECUTION forma — **mai** dall’interno TASK‑063.
- **TASK‑065**: solo coordinator **dry‑run/mock** dopo **TASK‑064** (**D63‑06**).

---

## Planning review checklist

- [ ] Decisioni **D63-01…D63-08** compilate.
- [ ] UX Release futura descritta (SwiftUI) senza implementazione.
- [ ] Separazione DEBUG vs Release documentata (**D63-03**, **§4.a `debugDiagnostics`** / **§4.c**).
- [ ] Ordine slice **TASK-064…TASK-070+** chiaro (**§5**).
- [ ] Modello run/phase/outcome documentato (**§4.d** — concetti, non API Swift definitive).
- [ ] Efficienza / no‑duplicate‑work documentata (**§4.e**).
- [ ] UX Release compatibile Dynamic Type / VoiceOver (**§4.c**).
- [ ] Invarianti tecnici elencati (**§4.f**, coerente con **§4.b**).
- [ ] Error taxonomy user-facing documentata (**§4.g**, **RQ9**).
- [ ] Osservabilità privacy-safe documentata (**§4.h**, **RQ10**).
- [ ] Planning freeze / non-execution boundary esplicito (**§4.i**, **RQ11**).
- [ ] Markdown/typo principali corretti (**§7.b**, **Collegamento tecnico PhaseOutcome ↔ UX**).
- [ ] TASK-064 confermato come primo task operativo consigliato (**§5**, **§9**, **§7.b RQ8**).
- [ ] Nessuna sezione **dichiara** READY FOR EXECUTION né autorizza implementazione ora (**§9**).
- [ ] Nessun codice Swift modificato in questo task.
- [ ] Nessun file **TASK-064** (né altri task `.md`) creato da questo perfezionamento.
- [ ] **`docs/MASTER-PLAN.md`** coerente con **TASK-063 ACTIVE / PLANNING**.
- [ ] Handoff **READY FOR PLANNING REVIEW** — **non** READY FOR EXECUTION.

---

## Riferimento Supabase *(lettura teorica)*

Fonte tipica nei task precedenti: `MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql` (**solo lettura**).

Il coordinator non interpreta DDL/RPC nel planning: restano incapsulate in **`SyncEventRecording`** come oggi. Vincoli noti dai task iOS (**TASK-059/060**): **`changed_count`** 0–1000, budget **`entity_ids`/`metadata`**, idempotenza su **`client_event_id`** e owner session.

---

## Riferimento Android *(funzionale)*

TASK‑070 retryable head‑of‑line (**Android** storico **non** nomenclatura UX iOS **§4.c**).

---

## Execution (Codex)

*(Non autorizzato in TASK‑063.)*

## Fix (Codex)

*(Non autorizzato in TASK‑063.)*
