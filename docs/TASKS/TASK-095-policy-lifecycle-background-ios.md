# TASK-095 — Policy lifecycle / background iOS (sync roadmap)

## Informazioni generali

- **Task ID:** TASK-095
- **Titolo:** Policy lifecycle / background iOS *(sync semi-automatica roadmap)*
- **File task:** `docs/TASKS/TASK-095-policy-lifecycle-background-ios.md`
- **Stato:** **DONE**
- **Fase attuale:** **Chiusura — REVIEW PASS**
- **Responsabile attuale:** **Nessuno / Chiusura**
- **Data creazione:** 2026-05-10
- **Ultimo aggiornamento:** 2026-05-10 12:09 -0400 — **REVIEW PASS / DONE** dopo review completa, fix mirati e build/test PASS.
- **Ultimo agente che ha operato:** Codex / Reviewer+Fixer

**Flag:** **`TASK-095_REVIEW_PASS_DONE`** — policy lifecycle/background iOS foreground-first implementata, reviewata e verificata. **TASK-096 non aperto.**

---

## Dipendenze

- **Dipende da:** **TASK-094 DONE / Chiusura — REVIEW PASS** — push intelligente aggregato (`LocalPendingAggregatedPushPlanner`, adapter Release catalogo/ProductPrice, outbox aggregata `SupabaseManualSyncAggregatedPushOutboxProducer`, integrazione `SupabaseManualSyncViewModel` / `SupabaseManualSyncReleaseFactory`). **TASK-093 DONE** — `LocalPendingChange`, accumulator, `SupabaseManualSyncLocalPendingSnapshotProvider`, stati pending/superseded/blocked/staleBaseline/sent/acknowledged. **TASK-092 DONE** — hook root `ScenePhase` / foreground check leggero; **TASK-091 DONE** — semi-auto Release (cooldown, review, no mutazioni silenziose).
- **Sblocca:** **TASK-096** (acceptance finale roadmap) — **resta TODO / Planning — non aperto** fino a chiusura/handoff TASK-095.
- **Non aprire in questo task:** file **TASK-096**; nessuna modifica codice senza futura fase **EXECUTION** autorizzata.

---

## 1. Obiettivo

Definire una **policy iOS-native** per il **lifecycle dell’app** in relazione alle operazioni di sync cloud già presenti (check/preview foreground, pull apply, push aggregato, drain outbox manuale, pending locale): cosa succede a **run in corso** quando la scena passa **inactive/background**, come si **annulla** / **riprende** / si **rimanda** il lavoro senza introdurre **sync mutativa automatica**, **worker permanenti**, **Timer** o **polling** continui.

Il risultato atteso di TASK-095 (post review planning e futura EXECUTION) è un comportamento **prevedibile**, **cancellabile**, **risparmio batteria**, coerente con **ScenePhase** / **Task** in foreground. Decisione planning: **MVP foreground-first, senza BackgroundTasks**. Le API tipo **BackgroundTasks** restano **follow-up esplicito** solo se una futura review dimostra beneficio reale, gate severi e UX non rumorosa — **non** copiare WorkManager Android 1:1.

---

## 2. Stato attuale iOS *(repo-grounded — sintesi planning)*

Dalla catena **TASK-091 → TASK-094** e dai file indicati nei task completati:

- **Foreground / apertura:** dopo **TASK-092**, esistono trigger **app-level** post-render per controlli cloud **read-only** leggeri, con dedupe e policy (card Opzioni / root). Non costituiscono ancora una policy unificata “lifecycle” per **run mutative** lunghe o interrotte.
- **Release manuale:** `SupabaseManualSyncViewModel` + coordinator guidano **Controlla cloud → Rivedi → …** con piani volatili, cancellazione e stati semi-automatici (TASK-091); apply/push/drain restano sotto **conferma utente** ove gia’ richiesto.
- **Pending locale:** **TASK-093** — `LocalPendingChange` + snapshot provider; stati **blocked / staleBaseline / sent / acknowledged** gia’ modellati per fail-closed e retry locale.
- **Push aggregato:** **TASK-094** — `LocalPendingAggregatedPushPlanner` (batch bounded, cap, fingerprint), riuso `SupabaseManualPushService` / ProductPrice manual push, `SupabaseManualSyncAggregatedPushOutboxProducer` per telemetry; transizioni **batch-scoped**; nessun background worker aggiunto.
- **Outbox / attivita’:** enqueue e drain **manuali/controllati** su path documentati (`SyncEventOutbox*`, **TASK-081** area); non confondere con “dirty push” automatico.

**Gap esplicito:** manca una **specifica unificata** su: (a) cosa fare se l’utente mette in background durante una run **mutativa** o durante preparazione piano aggregato; (b) come **ripresentare** stato “interrotto / da verificare / pronto a riprovare” al ritorno in foreground; (c) come impedire doppie run tra root, Opzioni e sheet Release; (d) confermare che **BGTask / refresh background reali sono fuori dal MVP TASK-095**.

---

## 3. Contesto da TASK-093

- **`LocalPendingChange`** e’ la **fonte intenzionale** delle modifiche non ancora riportate al cloud; stati **staleBaseline** e **blocked** limitano cio’ che puo’ essere inviato in sicurezza.
- **Snapshot read-only** (`SupabaseManualSyncLocalPendingSnapshotProvider`, conteggi aggregati) alimenta copy Release **privacy-safe**.
- **TASK-095** non deve duplicare la logica di **coalescing** o **idempotenza** gia’ in TASK-093/094; deve **orchestrare quando** le run esistenti possono continuare o devono **fermarsi** al cambio lifecycle.

---

## 4. Contesto da TASK-094

- **`LocalPendingAggregatedPushPlanner`** prepara piani **bounded**; il network non e’ tenuto dentro transazioni SwiftData documentate; successo remoto + fallimento enqueue outbox gia’ mappa a “follow-up tecnico” in TASK-094.
- **TASK-095** deve chiarire: se **background** durante **mark sent → network → acknowledge** richiede **pause** esplicita, **timeout**, o **stato ripresentabile** senza doppio invio (riuso fingerprint/idempotenza gia’ presenti).

File di riferimento *(solo elenco planning; nessuna modifica in questo turno)*: `LocalPendingAggregatedPushPlanner.swift`, `SupabaseManualSyncAggregatedPushOutboxProducer.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabaseManualSyncViewModel.swift`, test `LocalPendingAggregatedPushPlannerTests`, `SupabaseManualSyncViewModelTests`.

---

## 5. Riferimento Android *(solo confronto funzionale)*

- Pattern documentati nella roadmap (**dirty set**, **head-of-line**, **retry**) restano **ispirazione** per **policy** e **UX** (es. differenza tra “coda locale” e “lavoro in corso”), **senza** portare WorkManager o servizi long-lived equivalenti.

---

## 6. Riferimento Supabase *(solo read-only, se necessario in fasi successive)*

- Contratti gia’ noti: **`sync_events`** / **`record_sync_event`**, `changed_count` 0…1000, idempotenza **`client_event_id`**, RLS **owner-scoped** — utili per **non** proporre flush automatici che violino payload o telemetry.
- **Nessuna** DDL/migration/live write nel perimetro **PLANNING init** di questo file.

---

## 6.1 Decisioni planning integrate *(UX/UI + efficienza)*

Queste decisioni sono parte del planning e devono guidare la futura review/EXECUTION, evitando scelte ambigue:

- **D95-01 — MVP foreground-first:** TASK-095 deve risolvere il lifecycle con `ScenePhase`, `Task` cancellabili, run id/token e stato ripresentabile al ritorno in foreground. **Niente BGTask nel MVP.**
- **D95-02 — UX non invasiva:** al ritorno in foreground non mostrare modal automatiche. Usare una **card/banner compatto** coerente con la card Release esistente: stato breve, una CTA primaria, una secondaria al massimo.
- **D95-03 — Mutazioni sempre confermate:** se una run mutativa viene interrotta, l’app deve mostrare **“Operazione interrotta” / “Rivedi e riprendi”**, non riprendere push/apply/drain in silenzio.
- **D95-04 — Single-flight globale:** deve esistere una sola fonte di verita’ per “sync/check/push in corso” tra root, Opzioni e sheet Release. Scene multiple o foreground ripetuti non devono avviare run concorrenti.
- **D95-05 — Stato processo separato dallo stato dati:** TASK-095 non modifica la semantica di `LocalPendingChange`; aggiunge solo policy di processo: `running`, `cancelling`, `interrupted`, `readyToRetry`, `blocked`.
- **D95-06 — Efficienza prima di completezza automatica:** niente snapshot pesanti su ogni `active`; usare debounce/throttle gia’ esistenti, conteggi bounded, riuso snapshot provider e niente N+1.
- **D95-07 — Copy utente semplice:** evitare termini tecnici come “lifecycle”, “BGTask”, “idempotency”. Preferire microcopy tipo: **Controllo interrotto**, **Puoi riprendere quando vuoi**, **Rivedi prima di inviare**.
- **D95-08 — Preflight prima di riprendere:** al ritorno in foreground o prima di retry/ripresa, verificare in modo leggero **sessione/auth**, **owner**, **rete disponibile** e stato app compatibile; se non sicuro, mostrare stato `blocked`/`readyToRetry` invece di avviare lavoro.
- **D95-09 — Time budget bounded:** ogni run foreground deve avere budget/limiti chiari; se supera soglia o l’app cambia stato, degradare a `interrupted`/`readyToRetry` con copy utente, non lasciare spinner indefiniti.

---

## 7. Differenze / gap da chiudere

| Area | Oggi (sintesi) | Cosa TASK-095 dovrebbe decidere *(futura execution)* |
|------|----------------|--------------------------------------------------------|
| Background durante run | Comportamento implicito da `Task` / MainActor; cancellazioni parziali definite per singolo flusso | Policy **unica**: default **pause/cancel** vs **continue solo fino a soglia** (se accettabile) |
| Ripresa foreground | TASK-092 suggerisce check; non unifica push/drain | **Ordine** tra “controlla cloud” e “ripresa invio pending” senza doppia urgenza UX |
| BackgroundTasks | Vietati come obbligo nei task precedenti | **NO nel MVP TASK-095**; eventuale opt-in solo in **follow-up separato** con gate **rete/sessione/batteria/utente** |
| Pending + lifecycle | TASK-093/094 gestiscono stato **dati** | TASK-095 gestisce stato **processo** (run/cancellable/resume) senza rompere state machine pending |
| Multi-scena | TASK-092 ha note dedupe | Confermare **una** fonte di verita’ per “sync in corso” tra scene, root, Opzioni e sheet Release |
| Preflight ripresa | Guard auth/owner esistono in task precedenti ma non come policy lifecycle unica | Prima di retry/ripresa: controllo leggero sessione, owner, rete e stato app; se incerto → `blocked`/`readyToRetry`, non auto-run |
| Time budget | Singoli flussi hanno progress/cancel, ma non un limite lifecycle comune | Definire budget bounded e fallback **interrotto/riprova** per evitare spinner indefiniti o lavoro pesante su foreground |

---

## 8. Scope

- **Incluso:** documentazione e **futura implementazione** *(solo dopo EXECUTION autorizzata)* di policy lifecycle: mapping **ScenePhase** / app state ↔ run sync esistenti; regole **cancel/retry/rimanda**; copy/stati UX coerenti con Release (**IT/EN/ES/zh-Hans** solo se task execution lo autorizza); eventuali **hook** minimi per osservabilita’ **privacy-safe**.
- **Micro-progressivo:** un solo obiettivo per slice; niente refactor ampio non motivato.

---

## 9. Out of scope *(anti-scope TASK-095)*

- **Realtime**, **polling** continuo, **Timer** di sync, **worker** permanenti, **sync mutativa silenziosa**.
- **Nuovo** motore push/pull parallelo a `SupabaseManualPushService` / planner TASK-094.
- **Modifiche Kotlin/Android**, **SQL/migration/RLS/backend**, **write Supabase live** come obiettivo di questo planning-init.
- **TASK-096** (file, planning, execution).
- Claim **production-ready globale 100%**.

---

## 10. Micro-slice *(S95-A … — bozza per planning review)*

| ID | Titolo | Output atteso prima di EXECUTION |
|----|--------|----------------------------------|
| **S95-A** | Mappa lifecycle ↔ codice esistente | Elenco file Swift da toccare *(root `ScenePhase`, ViewModel Release, factory, planner/outbox)* e punti di aggancio; **nessun** comportamento nuovo ancora |
| **S95-B** | Policy run × lifecycle | Tabella definitiva: **preview, apply, push catalogo, push ProductPrice, push aggregato, drain outbox** → azione su `inactive`, `background`, ritorno `active`, cancel utente |
| **S95-C** | Single-flight / run id | Contratto per evitare doppie run tra root, Opzioni e sheet Release: run id/token, busy source, cancel reason, retry state |
| **S95-D** | UX stati iOS-native | Card/banner compatto e copy per **in corso**, **interrotto**, **riprendi**, **rivedi prima di inviare**; nessuna modal automatica su foreground |
| **S95-E** | Efficienza / risorse | Debounce scene changes, throttle check, snapshot bounded, niente N+1, no full reload su foreground ripetuto |
| **S95-F** | BackgroundTasks decisione MVP | Decisione congelata: **NO BackgroundTasks nel MVP TASK-095**; se serve, creare follow-up futuro separato con gate batteria/rete/sessione |
| **S95-G** | Osservabilita’ privacy-safe | Logging aggregato solo dove gia’ pattern TASK-093/094; nessun dump barcode/nomi; conteggi e outcome, non payload |
| **S95-H** | Preflight e time budget | Policy leggera per sessione/owner/rete/stato app + soglie bounded; nessun retry automatico se il contesto non e’ sicuro |

### 10.1 Tabella run × lifecycle proposta *(policy MVP)*

| Run / fase | inactive breve | background | ritorno active | Cancel utente |
|------------|----------------|------------|----------------|---------------|
| Foreground cloud check / preview read-only | continua solo se bounded e quasi conclusa; altrimenti cancellabile | cancella e conserva ultimo stato noto | card compatta “Controllo interrotto” + CTA “Ricontrolla” | cancella senza modificare dati |
| Pull preview read-only | stesso comportamento del foreground check | cancella preview volatile | riparte solo da azione utente o policy foreground deduplicata | cancella piano volatile |
| Pull apply locale confermato | non avvia nuovi step; se una commit boundary SwiftData è già partita, completarla o rollback fail-closed | stop dopo boundary sicura; nessun nuovo apply | mostra “Rivedi risultato” / “Ricontrolla”, senza dichiarare successo se non verificato | rollback se possibile, altrimenti stato interrupted con verifica richiesta |
| Push catalogo / ProductPrice / aggregato | planning/preflight cancellabile; se remote write è già partita, non marcare completato finché non c’è verifica/read-back | non iniziare nuovi batch; batch incerto resta interrupted / retry-safe | mostra “Invio interrotto — rivedi prima di riprovare”; retry usa fingerprint/idempotenza TASK-094 | nessun acknowledged senza verifica; retry manuale |
| Drain outbox / sync activity | cancellabile tra eventi; non cancellare record locali finché non c’è ack | sospendi, lascia outbox retry-safe | card “Attività ancora da registrare” | conserva outbox, retry manuale |

### 10.2 Contratto RunGate / single-flight proposto

- **runID** — identificatore univoco della run *(UUID o stringa stabile per sessione)*.
- **source:** `rootForeground` | `optionsCard` | `releaseSheet` — origine della richiesta *(dedupe visivo e single-flight)*.
- **kind:** `preview` | `apply` | `push` | `drain` — tipo di lavoro *(non duplica la state machine dati TASK-093)*.
- **startedAt** — timestamp avvio *(per UX “in corso” e diagnostica aggregata)*.
- **Stati processo:** `idle`, `running`, `cancelling`, `interrupted`, `readyToRetry`, `blocked`, `completedVerified` — separati dallo stato **`LocalPendingChange`** / outbox.
- **Una sola run mutativa alla volta** — apply / push / drain non concorrenti; preview read-only in competizione definita sotto.
- **Preview read-only:** deduplicate o **ignorate** se una mutativa è in corso *(evita race con check cloud)*.
- **Ritorno foreground:** se esiste una **mutazione interrotta**, ha **priorità visiva** rispetto a un nuovo **check cloud read-only** — l’utente vede prima “riprendi / verifica” che un nuovo “Controlla”.
- **Nessun successo ottimistico:** la UI puo’ mostrare successo solo dopo **verifica** coerente con **TASK-093** / **TASK-094** (read-back, stato pending, fingerprint, follow-up telemetry).
- **Preflight leggero:** prima di avviare o riprendere una run mutativa, verificare auth/sessione, owner coerente, rete disponibile e assenza di blocchi UI critici; fallire in `blocked`/`readyToRetry` se il contesto non e’ sicuro.
- **Budget temporale:** il gate puo’ imporre un limite soft per evitare spinner indefiniti; superata la soglia, interrompere in modo sicuro e mostrare CTA di ripresa/retry.

---

## 11. Criteri di accettazione *(CA-T095-xx — bozza; contratto futuro EXECUTION)*

- **CA-T095-01 — Policy documentata:** Esiste una tabella **run × lifecycle** approvata in review planning senza contraddizioni con TASK-091/092/093/094.
- **CA-T095-02 — No sync mutativa automatica:** Nessuna nuova automazione che esegua apply/push/drain **senza** lo stesso grado di controllo utente gia’ richiesto dalla Release.
- **CA-T095-03 — Cancellabilità:** Le run lunghe devono restare **cancellabili** o **degradare** in stato sicuro (nessun successo UX finto dopo interrupt — allineato a TASK-094 follow-up telemetry).
- **CA-T095-04 — Coerenza pending:** Interrupt non lascia `LocalPendingChange` in stato **inconsistente** rispetto a outcome reale (sent senza verify, ecc.) — **fail-closed** o transizione esplicita.
- **CA-T095-05 — Batteria / risorse:** Nessun pattern **always-on**; **BackgroundTasks esclusi dal MVP** e documentati come follow-up separato.
- **CA-T095-06 — Privacy:** Messaggi utente e log restano **aggregati**; nessuna lista massiva in card.
- **CA-T095-07 — Regressioni:** Percorsi TASK-092 foreground check e TASK-094 push aggregato **non** si scavalcano con doppie run concorrenti non gated.
- **CA-T095-08 — Single-flight verificabile:** Root foreground hook, card Opzioni e sheet Release condividono gating coerente; foreground multipli non avviano doppia preview/push/drain.
- **CA-T095-09 — UX coerente app:** Gli stati lifecycle usano componenti SwiftUI nativi gia’ coerenti con l’app: card compatta, toolbar/sheet esistenti, CTA primaria chiara, testo breve e localizzabile.
- **CA-T095-10 — Nessuna modal automatica al ritorno:** Il ritorno in foreground puo’ mostrare una card/banner non invasivo, ma non apre sheet/dialog senza azione utente.
- **CA-T095-11 — Efficienza misurabile:** Nessun nuovo full scan o snapshot pesante su ogni `active`; eventuali refresh sono deduplicati, bounded e fakeable nei test.
- **CA-T095-12 — BGTask fuori MVP:** La futura EXECUTION TASK-095 non introduce `BGTaskScheduler`, `BGAppRefreshTask`, `BGProcessingTask` o worker equivalenti; qualunque background reale richiede task separato.
- **CA-T095-13 — RunGate minimale:** se introdotto, resta **piccolo**, **fakeable**, **senza** dipendenze dirette da Supabase live e **non** duplica planner / coordinator / servizi Release esistenti.
- **CA-T095-14 — Stato incerto esplicito:** se una **remote write** viene interrotta dopo l’avvio, UI e stato locale richiedono **verifica/retry**; **vietato** mostrare “completato” senza read-back o conferma coerente.
- **CA-T095-15 — Priorità foreground chiara:** al ritorno in app, una run **mutativa interrotta** ha **priorità visiva** rispetto a un nuovo check **read-only**; l’utente vede **una sola** card/action principale.
- **CA-T095-16 — Una sola card sync:** foreground/root/Opzioni/sheet Release non mostrano stati duplicati o card concorrenti; la UI sceglie un solo messaggio principale in base alla priorità del processo.
- **CA-T095-17 — Accessibilità UX:** copy e componenti futuri supportano Dynamic Type, VoiceOver e tap target nativi; nessuna informazione critica dipende solo da colore/badge.
- **CA-T095-18 — Preflight ripresa:** retry/ripresa foreground controllano in modo fakeable sessione/auth, owner e rete; se il contesto e’ incerto, la run non parte e la UI mostra azione chiara.
- **CA-T095-19 — No spinner indefiniti:** ogni run lifecycle visibile ha timeout/budget o percorso di cancel; al superamento soglia passa a stato `interrupted`/`readyToRetry` senza perdere pending locali.
- **CA-T095-20 — Non disturbare flussi critici:** import/export/scanner/editing/review gia’ aperti non vengono coperti da nuove modal/card intrusive; eventuale card sync resta inline, dismissibile o rinviabile secondo priorita’ UX.

*(Numerazione e testi definitivi dopo **PLANNING REVIEW** e lettura codice mirata in EXECUTION.)*

---

## 12. Rischi *(R95-xx)*

- **R95-01:** Doppio trigger **foreground** (TASK-092) + **ripresa run** TASK-095 → race / doppio check o doppio stato “busy”.
- **R95-02:** Utente interpreta **interruzione** come **completamento** → mismatch con **pending** ancora `.pending` e cloud non allineato.
- **R95-03:** Introduzione **BGTask** senza gate → revisione App Store / batteria / risultati non deterministici.
- **R95-04:** Complicazione UX: troppi stati visibili accanto a TASK-091 semi-auto e banner TASK-092.
- **R95-05:** Divergenza tra **cancellazione Swift `Task`** e **stato SwiftData** `LocalPendingChange` / outbox.
- **R95-06:** UI troppo insistente al ritorno in app → peggiora UX rispetto alla card Release esistente.
- **R95-07:** Foreground ripetuti o multi-window iPad generano refresh duplicati se il single-flight non e’ centrale.
- **R95-08:** Snapshot pending troppo frequenti aumentano latenza percepita e consumo batteria su database grandi.
- **R95-09:** Remote write partita ma app sospesa **prima** del read-back → rischio esito **incerto**; mitigare con stato **interrupted** e verifica prima di ack.
- **R95-10:** RunGate troppo generico puo’ **duplicare** il coordinator esistente; mitigare limitandolo a **lifecycle/single-flight** senza incapsulare logica business sync.
- **R95-11:** Card root, card Opzioni e sheet Release possono comunicare stati diversi nello stesso momento; mitigare con regola **una sola card/action principale** e priorità **mutativa > read-only**.
- **R95-12:** Sessione scaduta, owner cambiato o rete assente durante retry foreground possono produrre stati ambigui; mitigare con preflight fail-closed prima di ogni ripresa mutativa.
- **R95-13:** Spinner/progress troppo lunghi al ritorno in app peggiorano fiducia utente; mitigare con time budget e stato `readyToRetry`.
- **R95-14:** Card lifecycle durante import/export/scanner/editing puo’ disturbare un flusso operativo; mitigare con card inline non modale e rinviabile.

---

## 13. Piano test futuro *(non eseguito in questo turno)*

| ID | Tipo | Note |
|----|------|------|
| **T95-01** | XCTest / ViewModel fake | Simulazione transizioni lifecycle **senza** simulator obbligatorio in planning: iniettare `ScenePhase` / lifecycle event fake |
| **T95-02** | XCTest | Gating **single-flight** run sync quando lifecycle ripete foreground o arrivano eventi multi-scena |
| **T95-03** | XCTest | Cancel durante preview/push aggregato: nessun `LocalPendingChange` marcato come completato senza verifica |
| **T95-04** | XCTest | Ritorno foreground dopo interrupt mostra stato `interrupted/readyToRetry` senza auto-mutazione |
| **T95-05** | Manual / Simulator | Background durante push aggregato pianificato; verifica stato pending + copy utente |
| **T95-06** | Regressione | Suite mirata TASK-094 planner + TASK-093 snapshot + Release ViewModel + TASK-092 foreground gating |
| **T95-07** | UX smoke | Dynamic Type, copy breve, card non invasiva, nessuna modal automatica su foreground |
| **T95-08** | XCTest | Remote write incerto simulato: **nessun** `acknowledged`/completamento senza verifica/read-back |
| **T95-09** | XCTest | Run mutativa interrotta ha **priorità** su nuovo foreground check read-only |
| **T95-10** | UX smoke | Una sola card sync visibile al ritorno foreground; Dynamic Type e VoiceOver label coerenti |
| **T95-11** | XCTest | Preflight fake auth/owner/rete blocca retry mutativo quando il contesto non e’ sicuro |
| **T95-12** | XCTest | Time budget superato porta a `interrupted/readyToRetry`, nessuno spinner infinito e nessuna perdita pending |
| **T95-13** | UX smoke | Import/export/scanner/editing aperti non vengono interrotti da modal sync automatiche |

---

## 14. Gate Go / No-Go per futura EXECUTION

**Go** solo se:

1. **S95-A** completa: elenco file e punti di aggancio **senza** ambiguita’ tra TASK-092 hook e ViewModel Release.
2. **S95-B** approvata: per ogni run, **comportamento** su background/foreground/cancel **documentato** (incluso **no-op** esplicito dove serve).
3. **S95-C** approvata: single-flight centrale definito con run id/token, ownership della run e priorita’ tra mutazione interrotta e check read-only.
4. **S95-D/E/H** approvate: UX non invasiva, limiti efficienza/bounded work, preflight ripresa e time budget definiti prima di scrivere Swift.
5. **S95-F** congelata: **NO BackgroundTasks nel MVP TASK-095**; eventuale background reale spostato a follow-up separato.
6. Handoff verso EXECUTION con **criteri CA-T095-xx** congelati e **NON** in conflitto con anti-scope roadmap.

**No-Go** se: restano tabella lifecycle incompleta, manca single-flight centrale, la UX richiede modal automatiche su foreground, si introduce BackgroundTasks nel MVP, o si mescolano obiettivi **TASK-096** acceptance nel perimetro TASK-095.

---

## 15. File iOS candidati *(lettura futura EXECUTION — non modificati ora)*

- Root / scene: `ContentView.swift`, `iOSMerchandiseControlApp.swift`, `OptionsView.swift` (card Release), eventuali hook **TASK-092**.
- Sync Release: `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncCoordinator*.swift`, `SupabaseManualSyncReleaseFactory.swift`.
- Pending / push: `LocalPendingChange.swift`, `LocalPendingAggregatedPushPlanner.swift`, `SupabaseManualSyncAggregatedPushOutboxProducer.swift`, `SupabaseManualSyncLocalPendingSnapshotProvider.swift`.
- Test: `SupabaseManualSyncViewModelTests.swift`, `LocalPendingAggregatedPushPlannerTests.swift`, test TASK-093 provider.
- **Solo se necessario in EXECUTION**, tipi/eventuali file minimi e fakeable **senza** logica business Supabase, es.: `LifecycleSyncRunGate.swift` *(o nome coerente col progetto)*; test: `LifecycleSyncRunGateTests.swift`.

---

## 16. Linee guida UX/UI per futura EXECUTION

TASK-095 deve migliorare percezione e controllo utente, non aggiungere rumore:

- Preferire una **card Release compatta** o banner inline nello stesso stile di `OptionsView` / manual sync: titolo breve, descrizione una riga, CTA primaria.
- Stati consigliati:
  - **Controllo in corso** → solo progress discreto, cancellabile se la run e’ lunga.
  - **Operazione interrotta** → card non invasiva con **Rivedi** / **Riprova**.
  - **Pronto da inviare** → rimanda al flusso Review esistente, non invia direttamente.
  - **Bloccato** → spiega azione concreta: accedi, ricontrolla, rivedi modifiche.
- Evitare sheet/dialog automatici al ritorno in app: l’utente decide quando riprendere.
- Mantenere gerarchia visiva iOS-native: `NavigationStack`, toolbar esistente, `ProgressView`, `confirmationDialog` solo per azioni mutative o destructive.
- Localizzazioni future devono essere brevi e coerenti con il tono gia’ usato in Release: niente gergo tecnico.
- **Regola una sola card:** al ritorno in foreground l’utente deve vedere al massimo **una** card/action principale legata alla sync. Se coesistono check cloud e run mutativa interrotta, prevale la run mutativa interrotta.
- **CTA priority:** ogni stato deve avere una CTA primaria chiara; la secondaria è opzionale e non deve competere visivamente. Esempi: **Rivedi**, **Riprova**, **Ricontrolla**, **Rimanda**.
- **Accessibilità:** copy leggibile con Dynamic Type, VoiceOver label descrittive, area touch coerente con componenti iOS esistenti, nessun testo essenziale solo nel colore.
- **Niente badge rumorosi:** evitare badge persistenti o allarmi visivi se non c’è un’azione concreta richiesta all’utente.
- **Non disturbare lavoro attivo:** durante import/export/scanner/editing o review sheet aperta, eventuali stati lifecycle devono restare inline/non modali e rinviabili; niente takeover della navigazione.

## 17. Linee guida performance / architettura per futura EXECUTION

- Introdurre al massimo un piccolo **LifecycleSyncPolicy / RunGate** testabile, non un nuovo motore sync.
- Ogni run deve avere `runID`, `startedAt`, `source`, `phase`, `cancelReason` e stato finale aggregato.
- Usare `Task` cancellabili e controllare `Task.isCancelled` tra step lunghi; non lasciare side effect dopo cancel.
- Nessun lavoro pesante direttamente su cambio `ScenePhase`; programmare solo valutazioni leggere e bounded.
- Riutilizzare planner/snapshot provider TASK-093/094; vietato duplicare dedupe, fingerprint o coalescing.
- Multi-scena: una sola run attiva per tipo; nuove richieste diventano no-op, retry o stato queued visibile, non concorrenza.
- Remote write gia’ partita: trattare l’esito come **incerto** finche’ non viene verificato; non avanzare `LocalPendingChange` a stato finale solo perche’ la richiesta e’ stata avviata.
- Il RunGate non deve diventare un coordinator alternativo: decide **se** una run puo’ partire/continuare, non **come** fare pull/push/apply/drain.
- In futura execution, clock/debounce/run source devono essere **fakeable** nei test per evitare test fragili basati sul tempo reale.
- Preflight e time budget devono essere dipendenze iniettate/fakeable, non letture globali sparse; questo mantiene i test deterministici e limita il rischio di N+1 o controlli ripetuti su ogni `active`.

## 18. Cutline MVP per futura EXECUTION

Questa cutline serve a impedire che TASK-095 diventi un refactor ampio della sync. La futura EXECUTION deve restare una slice piccola e verificabile:

- **Prima implementazione minima:** mappare codice reale (**S95-A**) e introdurre solo la policy strettamente necessaria per lifecycle/single-flight/preflight/time budget.
- **Nessuna nuova state machine dati:** non aggiungere nuovi stati a `LocalPendingChange` se gli stati processo (`interrupted`, `readyToRetry`, `blocked`) possono vivere nel ViewModel/RunGate.
- **Nessuna migration SwiftData:** TASK-095 non deve richiedere nuovi modelli persistenti, schema migration o campi salvati se non dimostrati indispensabili in review.
- **Nessun coordinator alternativo:** il RunGate, se introdotto, decide solo **quando** una run puo’ partire/continuare; pull/push/apply/drain restano nei servizi/coordinator Release esistenti.
- **UX prima del background:** completare card unica, copy, cancel/retry e stato incerto prima di valutare qualunque follow-up BackgroundTasks.
- **Localizzazioni solo se serve in EXECUTION:** eventuali stringhe future devono essere minime e coerenti con Release; nessun churn massivo di `Localizable.strings`.
- **Exit criteria MVP:** una sola card/action principale, nessuna doppia run, nessuno spinner indefinito, nessun `acknowledged` senza verifica, nessuna intrusione su import/export/scanner/editing.

## 19. Checklist Planning Review / freeze del piano

Questa checklist serve a chiudere il planning senza continuare ad aggiungere scope. Dopo questa review, eventuali nuove idee devono diventare follow-up separati, non allargare TASK-095.

- **PR-095-01 — Stato progetto:** MASTER-PLAN deve restare coerente: **TASK-095 ACTIVE / PLANNING**, **TASK-094 ultimo completato**, **TASK-096 non aperto**.
- **PR-095-02 — File touch list:** prima di EXECUTION serve confermare la lista reale dei file iOS da leggere/modificare; se servono file non previsti, motivarli in review prima di patchare.
- **PR-095-03 — Run × lifecycle:** la tabella 10.1 deve essere approvata o corretta puntualmente; niente execution se restano celle ambigue.
- **PR-095-04 — RunGate minimal:** confermare che il RunGate decide solo **gating/lifecycle**, non sostituisce coordinator, planner, push service o outbox service.
- **PR-095-05 — UX freeze:** confermare la regola **una sola card/action principale**, niente modal automatiche e mutazione interrotta > check read-only.
- **PR-095-06 — Efficienza freeze:** confermare preflight leggero, time budget bounded, niente snapshot pesanti su ogni `active`, niente spinner indefiniti.
- **PR-095-07 — Anti-scope:** confermare fuori MVP: BackgroundTasks, nuove migration SwiftData, nuova state machine dati, SQL/backend, Kotlin/Android, TASK-096.
- **PR-095-08 — Test readiness:** prima di EXECUTION, indicare quali XCTest/UX smoke saranno minimi obbligatori tra T95-01…13 per dichiarare READY FOR REVIEW.
- **PR-095-09 — Stop condition:** se durante futura EXECUTION emerge che serve refactor ampio, migration o background reale, fermare TASK-095 in PARTIAL/REVIEW e creare follow-up, non assorbire tutto qui.

## 20. Decisione finale di planning *(freeze)*

Il piano TASK-095 e' considerato **sufficientemente completo per Planning Review**. Da questo punto in poi non vanno aggiunte nuove aree funzionali al task: sono ammessi solo ritocchi di coerenza, correzione refusi o allineamento con codice reale durante **S95-A**.

- **Nessuna ulteriore espansione scope**: lifecycle, single-flight, preflight, time budget, UX non invasiva e cutline MVP coprono gia' il perimetro necessario.
- **Prossima azione corretta**: eseguire **Planning Review**, confermare file touch list e congelare CA/gate; non iniziare EXECUTION senza override utente esplicito.
- **Follow-up separati**: BackgroundTasks reali, refactor sync ampio, migration SwiftData, nuova state machine dati o acceptance finale devono restare fuori TASK-095 e, se necessari, diventare task successivi.
- **Criterio di stop planning**: se una nuova idea non e' necessaria per evitare regressioni lifecycle/UX immediate, non integrarla in TASK-095.

## Planning (Claude)

### Analisi

Dopo **TASK-094**, l’iOS ha **tutti i mattoni dati** per modifiche locali e invio aggregato **guidato**; manca la **policy di processo** quando l’app non e’ in primo piano. Il backlog MASTER-PLAN definisce questo task come **Policy lifecycle/background iOS** — allineato alla sequenza **091→092→093→094→095→096**.

### Approccio proposto

Partire da **foreground-first**: definire pause/cancel e ripresa **senza** nuovi daemon. Per questo planning la scelta migliore per UX, batteria e coerenza con i task precedenti e’: **NO BackgroundTasks nel MVP TASK-095**. La futura execution deve concentrarsi su single-flight, run id, copy non invasivo e cancellazione sicura.

### Handoff *(stato corrente: solo planning init)*

- **Prossima fase:** **PLANNING REVIEW** (affinare slice, CA, file touch list).
- **Prossimo agente:** **Claude / Planner** o reviewer designato.
- **Azione consigliata:** Rivedere questo file rispetto al codice reale **S95-A**, validare la tabella run × lifecycle gia’ proposta, confermare single-flight e UX card/banner, poi congelare CA e gate **prima** di qualsiasi **EXECUTION**.
- **READY FOR EXECUTION:** **NO** — richiesto completamento planning review + override utente esplicito secondo workflow progetto.
- **TASK-095 DONE:** **NO**.

---

## Execution (Codex)

### Avvio EXECUTION — 2026-05-10 11:24 -0400

- **Override esplicito utente:** autorizzata EXECUTION completa di TASK-095 da **ACTIVE / PLANNING** a **ACTIVE / EXECUTION**, con modifiche Swift/SwiftUI/SwiftData/XCTest/build simulator dove necessarie.
- **Obiettivo compreso:** implementare policy lifecycle/background iOS-native foreground-first per sync Release: nessun BackgroundTasks, nessun Timer/polling/Realtime/worker, single-flight globale tra root, card Opzioni e sheet Release, stati processo separati dagli stati dati, preflight leggero, time budget bounded e UX inline non invasiva.
- **Stato iniziale verificato:** MASTER-PLAN indica TASK-095 unico task attivo; TASK-094 ultimo completato **DONE / REVIEW PASS**; TASK-096 resta **TODO / Planning — non aperto** e non va creato/modificato.
- **S95-A — file reali controllati:** `ContentView.swift`, `iOSMerchandiseControlApp.swift`, `OptionsView.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncSemiAutomaticPolicy.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabaseManualSyncCoordinator.swift`, `SupabaseManualSyncCoordinatorModels.swift`, `LocalPendingChange.swift`, `LocalPendingAggregatedPushPlanner.swift`, `SupabaseManualSyncAggregatedPushOutboxProducer.swift`, `SupabaseManualSyncLocalPendingSnapshotProvider.swift`, test `SupabaseManualSyncViewModelTests.swift`, `SupabaseManualSyncReleaseUITests.swift`, `LocalPendingAggregatedPushPlannerTests.swift`, `SupabaseManualSyncLocalPendingSnapshotProviderTests.swift`.
- **File previsti da modificare:** `SupabaseManualSyncViewModel.swift`; nuovo helper minimo `SupabaseManualSyncLifecycleRunGate.swift`; test mirati ViewModel/UI; eventuali `Localizable.strings` IT/EN/ES/zh-Hans solo per copy lifecycle; tracking TASK-095 e MASTER-PLAN. `OptionsView.swift` solo se serve per propagare cancel/lifecycle in background.
- **Piano minimo:** introdurre RunGate solo per decidere start/continue/cancel/interrupt/retry; cablarlo a preview foreground, pull apply locale, push aggregato catalogo/ProductPrice e drain activity; aggiungere preflight fakeable e budget fakeable; aggiornare presentazione con una sola card/action principale; testare single-flight, cancel/interrupted, preflight, budget e regressioni 092/093/094/manual sync.
- **Divieti confermati:** nessun TASK-096, nessun BackgroundTasks/BGTaskScheduler/BGAppRefreshTask/BGProcessingTask, nessun Timer/polling/Realtime/worker, nessuna sync mutativa silenziosa, nessuna migration SwiftData, nessun SQL/backend, nessun Android/Kotlin, nessun dato reale o segreto.

### Completamento EXECUTION — 2026-05-10 11:56 -0400

- **Stato finale execution:** **READY FOR REVIEW**. TASK-095 resta **ACTIVE / REVIEW** e **NON DONE**; prossimo responsabile **Claude / Reviewer**.
- **Micro-slice eseguite:**
  - **S95-A:** mappa lifecycle ↔ codice reale completata; file toccati e motivazioni elencati sotto.
  - **S95-B:** policy run × lifecycle implementata per preview read-only, pull preview, pull apply locale, push aggregato catalogo/ProductPrice e drain outbox/activity.
  - **S95-C:** single-flight globale con run id/source/kind; root foreground, card Opzioni e sheet Release non competono.
  - **S95-D:** UX inline non invasiva con una sola card/action principale; nessuna modal automatica al ritorno foreground.
  - **S95-E:** niente lavoro always-on; budget/preflight fakeable; nessun full reload o snapshot pesante aggiunto su ogni active.
  - **S95-F:** decisione MVP confermata in codice e test: nessun `BGTaskScheduler`, `BGAppRefreshTask`, `BGProcessingTask`.
  - **S95-G:** nessun log payload/barcode/nomi aggiunto; test anti-scope/privacy mantengono guardie statiche.
  - **S95-H:** preflight auth/owner/rete/stato app e time budget bounded implementati e coperti da XCTest.
- **File toccati:**
  - `iOSMerchandiseControl/SupabaseManualSyncLifecycleRunGate.swift` — nuovo RunGate minimale/fakeable per stato processo, single-flight, preflight e budget.
  - `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift` — integrazione RunGate nei flussi preview/apply/push/drain, stati lifecycle e presentazione prioritaria mutativa interrotta.
  - `iOSMerchandiseControl/OptionsView.swift` — cancel della card Release propaga interruzione lifecycle e cancella task attivi coerenti.
  - `iOSMerchandiseControl/{it,en,es,zh-Hans}.lproj/Localizable.strings` — copy minimo lifecycle/root, breve e non tecnico.
  - `iOSMerchandiseControlTests/SupabaseManualSyncLifecycleRunGateTests.swift` — nuovo coverage single-flight/preflight/budget/stato incerto.
  - `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift` — test TASK-095 e regressioni su presentazione/manual sync.
  - `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift` — chiavi localizzazione e guardie UI/anti-scope aggiornate.
  - `docs/TASKS/TASK-095-policy-lifecycle-background-ios.md`, `docs/MASTER-PLAN.md` — tracking execution/review.
- **Decisioni implementative:**
  - RunGate resta deliberatamente piccolo: decide `begin`, `blocked`, `cancelling`, `interrupted`, `readyToRetry`, `completedVerified`; non duplica coordinator, planner, push service, apply service o outbox service.
  - Stato processo separato da `LocalPendingChange`: nessuna nuova state machine dati e nessuna migration SwiftData.
  - Remote write partita ma non verificata resta `interrupted`/`readyToRetry`; completamento visivo solo dopo verifica coerente.
  - Preview read-only viene deduplicata/ignorata se una mutazione e' in corso o interrotta con priorita' visiva.
  - Preflight mutativo fail-closed su auth/sessione assente, owner incerto, rete/context non sicuro o app non active.
  - Budget temporale non usa timer: viene valutato ai boundary dei flussi e degrada a stato riprovabile senza spinner infinito.
- **UX implementata:**
  - Card/banner resta inline nella card Release/root presentation esistente, con copy localizzato e una CTA primaria.
  - Mutazione interrotta ha priorita' su check cloud read-only.
  - Nessuna apertura automatica di sheet/dialog su foreground.
  - Dynamic Type/VoiceOver restano affidati ai componenti SwiftUI nativi gia' usati dalla card; nessun badge rumoroso o contenuto solo-colore.
  - Import/export/scanner/editing/review non ricevono nuove modal intrusive; il foreground hook continua a usare i gate esistenti.
- **Check eseguiti:**
  - ✅ `git status --short` iniziale eseguito: working tree gia' dirty con `docs/MASTER-PLAN.md` modificato e TASK-095 untracked; nessuna modifica utente revertita.
  - ✅ `xcodebuild -list -project iOSMerchandiseControl.xcodeproj` PASS.
  - ✅ Build Debug simulator iPhone 17 Pro iOS 26.4.1 PASS.
  - ✅ Build Release simulator iPhone 17 Pro iOS 26.4.1 PASS.
  - ✅ XCTest mirati TASK-095 PASS: 9 test, 0 failure.
  - ✅ XCTest `SupabaseManualSyncViewModelTests` PASS: 87 test, 0 failure.
  - ✅ XCTest regressivi TASK-092/TASK-093/TASK-094/manual sync collegati PASS: 133 test, 0 failure.
  - ✅ Full XCTest PASS: 626 test, 0 failure.
  - ✅ `git diff --check` PASS.
  - ✅ `plutil -lint` su `Localizable.strings` IT/EN/ES/zh-Hans PASS.
  - ✅ Grep anti-scope su `iOSMerchandiseControl/` PASS: nessun `BGTaskScheduler`, `BGAppRefreshTask`, `BGProcessingTask`, `Timer`, `polling`, `Realtime`, `worker`, `TASK-096`, `TASK095`.
  - ✅ Grep anti-scope su test: match solo in guardie statiche anti-scope preesistenti/aggiornate; nessun uso runtime introdotto.
  - ✅ Verifica Android/Kotlin: nessun file `.kt/.kts` o path Android modificato.
  - ✅ Verifica SQL/backend: nessun file `.sql`, `supabase/`, `backend/`, `migration(s)` modificato.
  - ⚠️ Nessun Simulator manual smoke interattivo eseguito: UX smoke coperto staticamente/XCTest; il task non richiedeva apertura manuale automatica e full XCTest/build sono PASS.
  - ⚠️ Warning nuovi: non rilevati warning Swift sui file TASK-095; Xcode continua a emettere warning AppIntents metadata (`No AppIntents.framework dependency found`) gia' osservato in task precedenti/fuori perimetro.
- **Rischi residui / follow-up candidate:**
  - BackgroundTasks reali restano esplicitamente fuori MVP e, se mai utili, richiedono task separato con gate batteria/rete/sessione/UX.
  - Smoke manuale di background durante push reale non e' stato fatto per evitare dati reali/live write; coperto con fake XCTest su cancellazione/interruzione/read-back incerto.
  - TASK-096 resta TODO / Planning — non aperto.

### Handoff post-execution verso Claude

| Voce | Valore |
|------|--------|
| **Stato finale TASK-095** | **ACTIVE / REVIEW** |
| **Handoff** | **READY FOR REVIEW** |
| **TASK-095 DONE** | **NO** |
| **Responsabile prossimo** | **Claude / Reviewer** |
| **TASK-096** | **Non aperto / non modificato** |
| **Anti-scope confermato** | No BackgroundTasks; no Timer/polling/Realtime/worker; no sync mutativa silenziosa; no SQL/backend; no Android/Kotlin; no dati reali/segreti |

---

## Review

### REVIEW PASS — 2026-05-10 12:09 -0400

- **Esito review:** **REVIEW PASS / DONE**. Implementazione giudicata corretta, minimale, iOS-native e coerente con la cutline MVP TASK-095.
- **Architettura RunGate:** `SupabaseManualSyncLifecycleRunGate` resta fakeable e limitato a gating lifecycle/single-flight/preflight/time budget; non contiene logica business Supabase, non duplica coordinator/planner/push/apply/outbox service, non introduce migration SwiftData o nuova state machine dati.
- **Single-flight/lifecycle:** root foreground, card Opzioni e sheet Release condividono gating coerente; mutazioni interrotte hanno priorita' su preview read-only; nessun successo ottimistico dopo remote write non verificata.
- **Preflight/time budget:** auth/sessione, owner, rete/context e stato app sono fakeable nei test; contesto incerto blocca la run; superamento budget produce stato interrotto/riprova senza perdita pending.
- **UX:** card inline/non modale, una CTA primaria, copy breve e localizzato; nessuna sheet/dialog automatica su foreground, nessun badge rumoroso, nessuna intrusione su import/export/scanner/editing/review.
- **Fix applicati in review:**
  - rimosso helper morto `resetIfTerminal()` da `SupabaseManualSyncLifecycleRunGate`;
  - rimosso helper morto `syncLifecycleProcessState()` da `SupabaseManualSyncViewModel`;
  - semplificato il copy localizzato dello stato `blocked` per evitare gergo tecnico sullo stato app;
  - aggiunta copertura XCTest per preflight con app lifecycle non compatibile (`.appNotActive`);
  - riallineato tracking corrente in MASTER-PLAN da stati stale `ACTIVE / PLANNING` a chiusura effettiva.
- **File modificati in review:**
  - `iOSMerchandiseControl/SupabaseManualSyncLifecycleRunGate.swift`
  - `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
  - `iOSMerchandiseControl/it.lproj/Localizable.strings`
  - `iOSMerchandiseControl/en.lproj/Localizable.strings`
  - `iOSMerchandiseControl/es.lproj/Localizable.strings`
  - `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
  - `iOSMerchandiseControlTests/SupabaseManualSyncLifecycleRunGateTests.swift`
  - `docs/TASKS/TASK-095-policy-lifecycle-background-ios.md`
  - `docs/MASTER-PLAN.md`
- **Check eseguiti in review:**
  - ✅ `git status --short` iniziale/finale controllato; nessun file Android/Kotlin, SQL/backend/migration modificato.
  - ✅ `git diff --check` PASS.
  - ✅ `xcodebuild -list -project iOSMerchandiseControl.xcodeproj` PASS.
  - ✅ Build Debug simulator iPhone 17 Pro iOS 26.4.1 PASS.
  - ✅ Build Release simulator iPhone 17 Pro iOS 26.4.1 PASS.
  - ✅ XCTest mirati TASK-095 PASS: 9 test, 0 failure.
  - ✅ `SupabaseManualSyncViewModelTests` PASS: 87 test, 0 failure.
  - ✅ `SupabaseManualSyncReleaseUITests` PASS: 24 test, 0 failure.
  - ✅ Regressioni TASK-092/TASK-093/TASK-094/manual sync PASS: 158 test, 0 failure.
  - ✅ Full XCTest PASS: 626 test, 0 failure.
  - ✅ `plutil -lint` IT/EN/ES/zh-Hans PASS.
  - ✅ Grep anti-scope sorgenti app PASS: nessun `BGTaskScheduler`, `BGAppRefreshTask`, `BGProcessingTask`, `Timer`, `polling`, `Realtime`, `worker`, `TASK-096`, `TASK095`.
  - ✅ Grep test: match solo in guardie statiche anti-scope, nessun uso runtime introdotto.
  - ✅ Localizzazioni: nessuna chiave mancante rilevata, nessun file `Localizable.strings` stray fuori target.
  - ✅ TASK-096: nessun file task aperto/creato/modificato.
- **Residui:** nessun blocco aperto nel perimetro TASK-095. BackgroundTasks reali e acceptance finale restano fuori scope/follow-up separati.

---

## Handoff finale *(REVIEW PASS TASK-095)*

| Voce | Valore |
|------|--------|
| **Stato finale TASK-095** | **DONE / Chiusura — REVIEW PASS** |
| **Progetto** | **IDLE** |
| **Handoff** | **Chiusura completata dopo review e fix mirati** |
| **TASK-096** | **TODO / Planning — non aperto** |
| **Ultimo completato** | **TASK-095 DONE / Chiusura — REVIEW PASS** |
| **Precedente completato** | **TASK-094 DONE / Chiusura — REVIEW PASS** |
| **Decisione MVP confermata** | **Foreground-first / NO BackgroundTasks / RunGate minimale** |
| **Decisione UX confermata** | **Una sola card/action principale; mutazione interrotta ha priorita' su check read-only** |
| **Decisione efficienza confermata** | **Preflight leggero + time budget bounded; niente spinner indefiniti o auto-run se contesto incerto** |
| **Anti-scope confermato** | **No BackgroundTasks; no Timer/polling/Realtime/worker; no sync mutativa silenziosa; no SQL/backend; no Android/Kotlin; no dati reali/segreti** |

---

## Registro turno — solo markdown *(2026-05-10)*

- Creato file task **TASK-095**; compilati obiettivo, stato iOS, contesto TASK-093/094, gap, scope, micro-slice iniziali, acceptance criteria, rischi, test futuri, gate Go/No-Go.
- **Vietato in questo turno:** Swift/SwiftUI/SwiftData, Kotlin, SQL/migration/RLS, Supabase live write, build/test obbligatori, Timer/BGTask/Realtime reali, sync mutativa automatica, apertura TASK-096, `project.pbxproj`, `Localizable.strings`.
- Integrazione planning review: aggiunte decisioni **D95-01…09**, scelta **NO BackgroundTasks nel MVP**, micro-slice **S95-C/F/G/H**, acceptance criteria **CA-T095-08…20**, rischi **R95-06…14**, test **T95-05…13**, linee guida **UX/UI** e **performance/architettura**. Stato invariato: **ACTIVE / PLANNING**, **READY FOR PLANNING REVIEW**, **NON READY FOR EXECUTION**, **TASK-095 NON DONE**.
- Rifinitura planning aggiuntiva: corretti refusi markdown, allineata tabella BackgroundTasks a **NO nel MVP**, aggiunta tabella **run × lifecycle**, contratto **RunGate / single-flight**, gestione esito remoto incerto, acceptance criteria **CA-T095-13…15**, rischi **R95-09…10** e test **T95-08…09**. Nessuna execution, nessun codice, nessun TASK-096.
- Rifinitura coerenza finale: allineato gap iniziale a **NO BGTask nel MVP**, esteso gap multi-scena a root/Opzioni/sheet Release, corretto wording CA-T095-05 e R95-05, aggiunta priorita’ mutazione interrotta nei gate Go, aggiunta regola architetturale su remote write incerto e decisione planning integrata nell’handoff finale. Stato invariato: **ACTIVE / PLANNING**, **READY FOR PLANNING REVIEW**, **NON READY FOR EXECUTION**, **TASK-095 NON DONE**.
- Rifinitura UX/accessibilità: aggiunta regola **una sola card**, priorità CTA, Dynamic Type/VoiceOver, divieto badge rumorosi, vincoli RunGate anti-coordinator alternativo e test fakeable; aggiunti **CA-T095-16…17**, **R95-11**, **T95-10** e decisione UX nell’handoff. Nessuna execution, nessun codice, nessun TASK-096.
- Rifinitura preflight/efficienza: aggiunti **D95-08…09**, **S95-H**, preflight sessione/owner/rete, time budget bounded, no spinner indefiniti, non disturbare import/export/scanner/editing, **CA-T095-18…20**, **R95-12…14**, **T95-11…13** e decisione efficienza nell’handoff. Nessuna execution, nessun codice, nessun TASK-096.
- Rifinitura cutline MVP: aggiunta sezione **Cutline MVP per futura EXECUTION** per evitare refactor sync ampio, nuove state machine dati, migration SwiftData, coordinator alternativi o churn Localizable; confermato focus minimo su lifecycle/single-flight/preflight/time budget e UX non invasiva. Stato invariato: **ACTIVE / PLANNING**, **READY FOR PLANNING REVIEW**, **NON READY FOR EXECUTION**, **TASK-095 NON DONE**, **TASK-096 non aperto**.
- Rifinitura Planning Review/freeze: aggiunta checklist **PR-095-01…09** per congelare stato progetto, file touch list, run × lifecycle, RunGate minimal, UX/efficienza freeze, anti-scope, test readiness e stop condition. Nessuna execution, nessun codice, nessun TASK-096.
- Freeze finale planning: aggiunta sezione **Decisione finale di planning** per fermare ulteriori espansioni scope; il piano e' dichiarato sufficiente per **Planning Review**, con sole correzioni di coerenza/refusi ammesse prima di eventuale override EXECUTION. Nessuna execution, nessun codice, nessun TASK-096.
