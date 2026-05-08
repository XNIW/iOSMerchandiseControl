# TASK-081: Drain outbox `sync_events` — percorso Release controllato (coordinator / manual sync)

## Informazioni generali
- **Task ID**: TASK-081
- **Titolo**: Portare il drain dell’outbox `sync_events` da DEBUG/tecnico a Release mediato, con conferma, retry e summary privacy-safe
- **File task**: `docs/TASKS/TASK-081-supabase-sync-events-outbox-drain-release-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Claude Code / Reviewer
- **Data creazione**: 2026-05-08
- **Ultimo aggiornamento**: 2026-05-08 19:09 -0400 — REVIEW/FIX/CHIUSURA completata; fix guardia review/accessibilità summary applicati; test/build/lint PASS; TASK-081 DONE / Chiusura.
- **Ultimo agente che ha operato**: Claude Code / Reviewer
- **Repo iOS**: `/Users/minxiang/Desktop/iOSMerchandiseControl`
- **GitHub iOS**: https://github.com/XNIW/iOSMerchandiseControl

## Dipendenze
- **Dipende da**: **TASK-080 DONE / Chiusura** (ProductPrice sync Release — perimetro chiuso; nessuna nuova logica prezzi in TASK-081). Infrastruttura outbox/drain/recorder (TASK-055…064, 058 Slice F) già presente.
- **Sblocca**: coerenza roadmap **TASK-083** (smoke end-to-end può richiedere drain Release); **non** sblocca **TASK-082** (conflitti) né **TASK-084** (parità Android).

## Scopo
Esporre in **Release** un percorso **manuale e controllato** per svuotare in sicurezza la coda locale degli eventi di tracciamento (`SyncEventOutboxEntry` / dominio server `sync_events`), **senza** sync automatica, **senza** cleanup distruttivo dell’outbox, e **senza** mostrare payload tecnici grezzi nella UI Release.

## Contesto
Oggi il drain reale è disponibile solo via **DEBUG** (`SyncEventOutboxDrainDebugViewModel` + card `#if DEBUG` in `OptionsView`). Il flusso Release **Controlla cloud → Rivedi → …** (TASK-078…080) aggiorna catalogo/prezzi ma **non** invia gli eventi accodati localmente. Il coordinator dry-run include la fase `pendingEventsFlush`, ma in Release è **solo simulata** come `.completed` (`SupabaseManualSyncReleaseDryRunPhaseSimulator`). Serve colmare il gap mediando l’azione tramite **coordinator.manual sync flow** / `SupabaseManualSyncViewModel`, con le stesse garanzie di conferma e summary già usate per push/apply.

## Non incluso (anti-scope task)
- Sync automatica, **Timer**, **BGTask**, **Realtime**, worker, polling.
- Reset / truncate / delete / “svuota outbox” distruttivo.
- Modifiche **ProductPrice** oltre quanto già in TASK-080.
- Conflitti avanzati (**TASK-082**), smoke end-to-end dedicato (**TASK-083**), parità Android (**TASK-084**), hardening globale (**TASK-085**).
- Modifiche **SQL / migration / RPC / RLS** Supabase (lettura clone locale ammessa solo come riferimento nel planning).
- Modifiche **Android** / Kotlin.

## Criteri di accettazione (contratto futura EXECUTION)
- [x] Da **Release**, con sessione valida, l’utente può **confermare** l’invio/registrazione in cloud degli elementi in coda (drain bounded) **solo** dopo il flusso **Controlla cloud → Rivedi** (nessun avvio automatico).
- [x] Summary finale **privacy-safe** (conteggi/messaggi classificati; **nessun** payload raw, UUID o JSON in UI Release).
- [x] **Riprova** manuale su errori retryable; **Annulla** rispettato; outbox **mai** troncata/resettata dal task.
- [x] Nessuna sync **automatica** / Timer / BGTask / Realtime / worker / polling.
- [x] Test: copertura pianificata in matrice **T81-01…T81-22** (unit/UI statiche come da handoff) con build verde.

---

## Obiettivo (operativo)
1. **Release**: l’utente può, dopo **Controlla cloud** e **Rivedi**, confermare esplicitamente un passo del tipo **“Invia / registra sul cloud”** per gli eventi localmente accodati (senza jargon: no stringhe utente `sync_events`, `outbox`, `RPC`, `record_sync_event`).
2. Il lavoro deve passare da **adapter o orchestrazione** nel **`SupabaseManualSyncViewModel`** (e/o capability Release factory), riusando **`SyncEventOutboxDrainService`** + **`SyncEventRecording`** live dove già valido, con **batch bounded** e policy errori esistenti.
3. **Summary finale** chiaro, **retry manuale** dopo errori retryable, **cancellation** rispettata; **zero** esposizione di payload raw, UUID tecnici, JSON in UI Release.

---

## Stato attuale iOS (repo-grounded)
- **Drain implementato**: `SyncEventOutboxDrainService` (`drainOnce`, recovery `sending` stale integrata — TASK-064, outcome `SyncEventOutboxDrainOutcome` con `sent`, `retryScheduled`, `blocked`, `dead`, `partiallyDrained`, ecc.).
- **UI drain**: solo **`#if DEBUG`**: `SyncEventOutboxDrainDebugViewModel` + `SyncEventOutboxDrainDebugCard` in `OptionsView` (~3245+), recorder live costruito in DEBUG.
- **Pending outbox in snapshot**: `SupabaseManualSyncLocalPendingSnapshotProvider` + `SupabaseManualSyncOutboxPendingAdapter` alimentano `pendingQueuedCloudOperationCount` già usato dal coordinator dry-run e dalla copy “modifiche da controllare”.
- **Release factory**: `SupabaseManualSyncReleaseFactory` **non** espone `SyncEventOutboxDrainService`/recorder; `supportsGuidedManualSync` resta **`false`** in `SupabaseManualSyncCapabilitySet.releaseCurrent`.
- **Coordinator**: `SupabaseManualSyncCoordinator.run` per `.guidedManual` / `.debugDiagnostics` → `summarySliceModeUnavailable()`; fase `pendingEventsFlush` in dry-run è **simulate-only** (`.completed` stub).
- **ViewModel Release**: grep su `SupabaseManualSyncViewModel.swift`: **nessun** riferimento diretto a drain/outbox — gap confermato.
- **Test esistenti utili**: `SyncEventOutboxDrainServiceTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxStateTests`, `SyncEventOutboxDrainDebugViewModelTests`, `SyncEventRecordingTests`, `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncReleaseUITests` (vietano stringhe jargon e `SyncEventOutboxDrainService` nella **card Release** — andranno aggiornati con attenzione se il grep resta “split” tra file).

---

## Riferimento iOS letto (inventario)
| Area | Path |
|------|------|
| Coordinator dry-run / fasi | `iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift`, `SupabaseManualSyncCoordinatorModels.swift` |
| ViewModel / presentation / review | `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift` |
| Factory Release | `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift` (`SupabaseManualSyncReleaseDryRunPhaseSimulator` stub flush) |
| Options Release + DEBUG outbox | `iOSMerchandiseControl/OptionsView.swift` (`SupabaseManualSyncReleaseCard`, `SyncEventOutboxDrainDebugCard`) |
| Drain service | `iOSMerchandiseControl/SyncEventOutboxDrainService.swift` |
| DEBUG ViewModel drain | `iOSMerchandiseControl/SyncEventOutboxDrainDebugViewModel.swift` |
| Store + model | `iOSMerchandiseControl/SyncEventOutboxEntry.swift` (`SyncEventOutboxLocalStore`, `SyncEventOutboxCounts`, stati) |
| Recorder contract | `iOSMerchandiseControl/SyncEventRecording.swift` |
| Pending snapshot / outbox count | `iOSMerchandiseControl/SupabaseManualSyncLocalPendingSnapshotProvider.swift` |
| Test | `iOSMerchandiseControlTests/SyncEventOutboxDrainServiceTests.swift`, `SyncEventOutboxDrainDebugViewModelTests.swift`, `SupabaseManualSyncViewModelTests.swift`, `SupabaseManualSyncReleaseUITests.swift`, … |

---

## Riferimento Supabase letto (solo lettura, clone locale)
**Path verificato**: `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql`

- **Tabella** `public.sync_events`: `owner_user_id uuid not null`, `domain` / `event_type` vincolati MVP (`catalog` / `prices` + event types elencati), `changed_count` **0…1000** (check + raise in RPC), `entity_ids` JSONB object, `metadata` JSONB object con budget e chiavi vietate, `client_event_id` opzionale.
- **RLS**: policy `sync_events_select_owner` — `authenticated` e `owner_user_id = auth.uid()`; grant **select** su tabella a `authenticated` (non insert diretto da client nella migration mostrata per la tabella — scrittura tramite RPC).
- **RPC** `public.record_sync_event`: `security definer`; `auth.uid()` obbligatorio; validazioni allineate all’iOS validator; **idempotenza**: se `p_client_event_id` non null e riga esiste per `(owner_user_id, client_event_id)` → **return riga esistente**; gestione `unique_violation` con select di ritorno.
- **Osservazione**: pubblicazione Realtime condizionale su tabella — **non** usarla in TASK-081 (fuori perimetro).

---

## Riferimento Android usato
**Non letto in questo turno.** Riutilizzo funzionale solo se in EXECUTION serve chiarire semantica evento cross-device; nessun porting Kotlin.

---

## Gap trovati
1. **Nessun** collegamento Release tra `pendingQueuedCloudOperationCount` / outbox e azione di drain reale.
2. `SupabaseManualSyncCoordinator` **non** esegue flush reale in Release (`guidedManual` disabilitato; dry-run simula sempre successo su flush).
3. Recorder **live** per drain oggi legato al percorso DEBUG in `OptionsView`; Release factory non costruisce dipendenza simmetrica.
4. UX: sheet **Rivedi** (sezioni TASK-077+) non ha una sezione **user-facing** per “attività di tracciamento da registrare sul cloud” (naming non tecnico da definire in `Localizable` in EXECUTION).
5. Test statici Release vietano `SyncEventOutboxDrainService` nel sorgente della card — l’integrazione dovrà rispettare o aggiornare consapevolmente questi test (es. drain orchestrato solo nel ViewModel / adapter, non stringato nella view).

---

## Decisioni (Planning)
| ID | Decisione | Alternative scartate | Motivazione | Stato |
|----|------------|----------------------|-------------|--------|
| D81-01 | Drain **solo** su azione utente esplicita dopo **Rivedi** (o sottopasso confermato nello stesso sheet), mai auto-run post push/apply | Drain automatico a fine push | Anti-scope utente + coerenza TASK-078…080 | attiva |
| D81-02 | Riutilizzare **`SyncEventOutboxDrainService`** + protocollo **`SyncEventRecording`**; non reimplementare RPC | Nuovo client RPC nella UI | Minimo cambiamento, stesso contratto TASK-060 | attiva |
| D81-03 | **`supportsGuidedManualSync`** resta **false**; orchestrazione drain via **ViewModel + adapter dedicato** (come catalog/price), non abilitando `.guidedManual` nel coordinator senza planning separato | Flip flag guidedManual | Riduce rischio di esecuzione fasi non controllate UI | attiva |
| D81-04 | Summary Release: **solo** conteggi aggregati (es. inviati / in attesa / non inviabili) e messaggi classificati user-facing; **vietato** mostrare payload, `clientEventID`, UUID, JSON | Debug row nella Release | Privacy + coerenza TASK-074/076 | attiva |
| D81-05 | **Nessuna** operazione distruttiva sull’outbox; stati `blocked*` / `dead` gestiti come oggi (messaggio guida + supporto / riprova manuale) | Truncate/delete | Vincolo utente severo | attiva |
| D81-06 | Se outbox **vuota** (`retryable == 0` alla conferma): uscita rapida con summary “nulla da inviare” senza chiamata rete | Forzare RPC | Risparmio rete e chiarezza | attiva |
| D81-07 | **`Task` cancellation**: stesso pattern degli altri passi mutativi Release (check cancellation prima/dopo batch); stato UI = cancelled / retry | Ignorare cancel | Coerenza TASK-078…080 | attiva |
| D81-08 | Sessione / baseline stale: **non** drain se gating auth/baseline fallisce; messaggio allineato agli stati esistenti “Accedi” / “Riallinea” | Proceed best-effort | Allineamento sicurezza account | attiva |
| D81-09 | Copy primaria proposta: **«Registra sul cloud»** o **«Invia aggiornamenti al cloud»** (da validare IT/EN/ES/zh-Hans); evitare “eventi/sync_events/outbox” | “Invia eventi al cloud” letterale se suona tecnico | Miglior UX; l’utente ha suggerito “Invia eventi…” come candidato | attiva |
| D81-10 | Eventuali entry **legacy/corrupt** per replay: comportamento **esistente** del drain (`blockedPayloadReplay` / blockedContract) mappato a messaggio non tecnico + conteggio “non inviabili” | Heuristic repair automatico | Fuori perimetro e rischio dati | attiva |
| D81-11 | Parziali: summary onesto **partial** con CTA **Riprova** (come catalog push) | Mostrare completo | Coerenza TASK-079 pattern | attiva |
| D81-12 | Batch: rispettare limiti **`SyncEventOutboxDrainService.hardLimit` / `hardFetchScanLimit`** salvo ridefinizione motivata | Unbounded | Sicurezza + performance | attiva |

---

## UX Release prevista
1. **Controlla cloud** — invariato ingresso.
2. **Rivedi** — se `pendingQueuedCloudOperationCount > 0` (o equivalente store), mostrare sezione **privacy-safe** del tipo: “Hai attività da registrare sul cloud” + conteggio approssimativo (**senza** UUID/JSON). Se zero, sezione assente o disabilitata.
3. **Conferma esplicita** — secondo action dedicata o passo sequenziale dopo push/apply **solo se** ci sono elementi retryable; chiara separazione percepibile: prima “Aggiorna dispositivo” / “Invia modifiche catalogo” / prezzi; poi (se necessario) passo **registrazione tracciamento** — oppure un’unica conferma finale **solo** se il planning EXECUTION definisce ordering senza ambiguità (preferenza: **passo esplicito separato** se entrambi presenti — D81-01).
4. CTA mutativa (es. **«Registra sul cloud»**) — esegue drain bounded; progress nativo (`ProgressView`) come altri passi.
5. **Summary finale**: “Registrati sul cloud: N”; “In attesa: M”; “Non inviabili: K” (+ testo guida per auth/rete); **Riprova** se retryable > 0.
6. **Retry manuale** — non back-off automatico in background (nessun Timer); solo CTA utente.

---

## Stato macchina proposto (ViewModel / orchestrazione)
Macchina **aggiuntiva** ortogonale alle esistenti `catalogPush*` / `productPrice*` (non sostituirle):

| Stato (logico) | Significato | Transizioni principali |
|-----------------|------------|-------------------------|
| `outboxIdle` | Nessuna operazione drain | → `outboxPreviewLoading` su apertura review |
| `outboxPreviewLoading` | Calcolo conteggi locali / idoneità | → `outboxAwaitingUserConfirm` / skip se 0 |
| `outboxAwaitingUserConfirm` | Sheet mostra riepilogo non tecnico | → `outboxDraining` su conferma |
| `outboxDraining` | `drainOnce` in corso (await) | → `outboxSummary` / `outboxFailedRetryable` |
| `outboxSummary` | Esito terminal utente | → `outboxIdle` su dismiss / new check |
| `outboxFailedRetryable` | Rete/session | → `outboxDraining` su Riprova |
| `outboxCancelled` | `CancellationError` | → summary “Annullato” coerente con TASK-078 |

*(Nomi interni Swift possono differire; la tabella è contratto di planning.)*

---

## Integrazione nel flusso manuale esistente (senza automazione)
- **Non** aganciare drain a `onAppear`, `Timer`, o completamento silenzioso di push.
- Agganciare solo a:
  - preparazione stato **review** (`buildReview…` / equivalente nel ViewModel) leggendo `SyncEventOutboxLocalStore.fetchCounts` o il snapshot pending già disponibile;
  - handler conferma (**nuovo** `ReviewPrimaryAction` o action secondaria dedicata — decisione EXECUTION: evitare di mischiare con “Invia modifiche catalogo” senza copy chiaro).
- **Factory Release**: estendere DI con **closure/adapter** che costruisce `SyncEventOutboxDrainService` + **live recorder** (stesso pattern sicurezza del DEBUG ma gated su sessione reale), **solo** se auth ok (come servizi push esistenti).

---

## Failure / recovery
| Scenario | Comportamento atteso |
|---------|----------------------|
| Sessione scaduta | Blocco pre-drain; stato `.auth`; CTA Accedi; nessuna RPC |
| Baseline / account stale | Riuso gate esistenti manual push / price; messaggio “riallinea” prima di drain |
| Outbox vuota | Summary “nulla da registrare”; no-op rete |
| Errori parziali | `partiallyDrained` / retry scheduled: mostrare N inviati, M rimasti, **Riprova** |
| Legacy / corrupt payload | Conteggio “non inviabili”; non crashare; suggerire supporto se molti blocked |
| Cancellation | Rollback coerente con drain service; stato annullato user-facing |
| Retry | Solo manuale; rispettare `nextRetryAt` / stato retryable del service |

---

## Privacy-safe summary (checklist UI Release)
- [x] Mai `entity_ids` / `metadata` raw
- [x] Mai `client_event_id`, `batch_id`, `owner_user_id` in stringhe visibili
- [x] Mai log JSON / PostgREST body
- [x] Opzionale: categorie aggregate (“modifiche catalogo” vs “prezzi”) **solo** se derivate da `domain` / `eventType` mappati a copy sicuri — senza elenco ID

---

## Test matrix (planning → EXECUTION)
| ID | Scenario | Tipo verifica prevista |
|----|----------|-------------------------|
| T81-01 | Outbox vuota → conferma → no network stub | STATIC/UNIT ViewModel |
| T81-02 | Una entry valida → fake recorder → sent + summary | UNIT drain già presente + ViewModel |
| T81-03 | `blockedPayloadReplay` → messaggio user-facing + conteggio blocked | UNIT |
| T81-04 | Network fail retryable → summary + Riprova | UNIT |
| T81-05 | Cancel durante drain → stato cancelled | UNIT |
| T81-06 | Sessione assente → CTA disabilitata / gated | UNIT + optional SIM |
| T81-07 | Review sheet: sezione presente solo se coda > 0 | UNIT / UI |
| T81-08 | Localizable: no forbidden jargon in chiavi `options.supabase.manualSync.*` | STATIC `ReleaseUITests` pattern TASK-072/079 |
| T81-09 | Parziale: 2 invii, 1 fallito retryable — numeri corretti | UNIT |
| T81-10 | Stale `sending` recovery integrata — regression TASK-064 copre service; ViewModel non duplica | REGRESSION |
| T81-11 | Grep: `OptionsView` Release card non importa drain direttamente se policy test resta | STATIC |
| T81-12 | Idempotenza lato server: doppio invio stesso `client_event_id` — comportamento no-op/row (documentato lato integrazione test con fake) | UNIT recorder |
| T81-13 | CTA “Registra attività sul cloud” non visibile prima di **Controlla cloud → Rivedi** | UNIT ViewModel |
| T81-14 | Summary aggiorna `Ancora in attesa` a 0 dopo successo | UNIT ViewModel |
| T81-15 | Nessun jargon Release: `sync_events`, `outbox`, `RPC`, `payload`, UUID-like, JSON | STATIC ReleaseUITests |
| T81-16 | Ordering: catalogo/prezzi prima, registrazione attività dopo | UNIT ViewModel |
| T81-17 | Doppio tap non crea drain concorrente | UNIT ViewModel |
| T81-18 | Preview solo conteggi/snapshot aggregati; nessun payload/entity ID | UNIT + STATIC |
| T81-19 | Localizable 4 lingue con copy user-facing e senza hardcoded copy UI | STATIC ReleaseUITests |
| T81-20 | `OptionsView` non conosce direttamente `SyncEventOutboxDrainService` / `drainOnce` | STATIC ReleaseUITests |
| T81-21 | `.guidedManual` non abilitato; nessuna sync automatica/worker/polling | STATIC ReleaseUITests |
| T81-22 | Reentrancy `confirm`/`retry`: se drain attivo, no-op controllato e nessun secondo task | UNIT ViewModel |

---

## Rischi
- **Accoppiamento UX**: troppi passi consecutivi (apply + push + drain) → stanchezza; mitigare copy chiaro e possibilità di rientrare dopo.
- **Test grep**: `SupabaseManualSyncReleaseUITests` vieta `SyncEventOutboxDrainService` in file Release — potrebbe richiedere spostamento logica tutto nel ViewModel.
- **Recorder live in Release**: costruzione `SupabaseSyncEventLiveRecorder` solo con sessione valida; errori configurazione = fail closed.
- **Duplicazione stati**: ViewModel già complesso — rischio regressione; mitigare adapter isolato + test.

---

## Definition of Ready (future EXECUTION)
Execuzione Swift **autorizzata** solo se:
1. **User override** esplicito post-review planning (workflow progetto).
2. Esiste **adapter/factory** chiaro per `SyncEventRecording` Release + `ModelContext` scope documentato.
3. Lista file target: ViewModel, Factory, OptionsView (se necessario solo wiring), nuove chiavi `Localizable` (4 lingue) — stimata in planning EXECUTION handoff.
4. Matrice T81-01…T81-22 assegnata a test con owner e fake/mocks (nessun Supabase live obbligatorio per verde CI).
5. Copy finale IT approvato **senza** jargon vietato dalla suite Release esistente.
6. Confermato: **nessun** Timer/BGTask/Realtime/worker/polling; **nessun** SQL/backend.

*(Soddisfatti i punti sopra → il task può passare a **EXECUTION** con handoff a Codex; questo documento non dichiara EXECUTION iniziata.)*

---

## Definition of Done (planning-only — questo task documentale)
- [x] File TASK-081 creato con sezioni obbligatorie e inventario repo-grounded.
- [x] `MASTER-PLAN.md` aggiornato: stato **ACTIVE**, TASK-081 **ACTIVE / PLANNING**, ultimo completato TASK-080 invariato.
- [x] Voce giornale **planning-only** aggiunta.
- [x] **Nessun** Swift / `project.pbxproj` / `Localizable.strings` / SQL / Android modificato **in questo turno**.

---

## Anti-scope finale (severo, questo turno + perimetro EXECUTION implicato dal brief utente)
- **Questo turno**: solo markdown TASK-081 + MASTER-PLAN; **zero** Swift, **zero** drain live, **zero** write Supabase.
- **Perimetro TASK-081** (come da richiesta progetto): nessuna sync automatica; nessun cleanup distruttivo outbox; nessun ProductPrice nuovo; nessun conflitto TASK-082; nessun smoke TASK-083; nessuna parità TASK-084.

---

## Planning (Claude)

### Analisi
Il sistema ha **servizio drain maturo** e **UI DEBUG funzionante**, ma Release non espone l’operazione. Il coordinator Espone la fase `pendingEventsFlush` solo come simulazione. L’integrazione naturale è estendere il **ViewModel** e la **sheet Rivedi** con un passo confermato separato, riciclando drain service e recorder.

### Approccio proposto
Aggiungere capability **“outbox drain”** optional nel ViewModel Release (tipo catalog/price providers): interfaccia `SupabaseManualSyncOutboxDrainProviding` (nome indicativo) con `drainPendingEvents(ownerUserID:)` che incapsula `SyncEventOutboxDrainService.drainOnce`. Collegare preparazione review ai conteggi privacy-safe. Aggiornare test Release per ammettere nuove stringhe sicure senza jargon.

### File da modificare (EXECUTION — non eseguito ora)
- `SupabaseManualSyncViewModel.swift`
- `SupabaseManualSyncReleaseFactory.swift`
- Eventuale nuovo file adapter **minimo** (se preferibile per testabilità)
- `OptionsView.swift` solo se serve wiring aggiuntivo oltre ViewModel (preferire assenza di logica)
- `Localizable.strings` (4 lingue)
- Test: `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncReleaseUITests`, possibilmente test adapter dedicato

### Rischi identificati
Vedi sezione **Rischi**.

### Handoff post-planning
- **Prossima fase**: EXECUTION — autorizzata da user override del 2026-05-08 17:37 -0400
- **Prossimo agente**: Claude Code / Executor
- **Azione consigliata**: implementare adapter + sezione review + summary + test T81-xx; **non** abilitare `.guidedManual` senza decisione esplicita separata

---

## Execution (Codex)
### Avvio EXECUTION — 2026-05-08 17:37 -0400
- **Obiettivo compreso**: portare in Release il drain manuale e confermato delle attività locali da registrare sul cloud dentro il flusso **Controlla cloud → Rivedi → Registra attività sul cloud**, con summary aggregato privacy-safe, retry manuale, cancel, auth gating, nessuna sync automatica e nessun cleanup distruttivo.
- **File target iniziali**: `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncReleaseFactory.swift`, eventuale adapter minimale/testabile per drain Release, `OptionsView.swift` solo wiring/UI presentation, `Localizable.strings` IT/EN/ES/zh-Hans, `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncReleaseUITests`, eventuali test adapter/presentation dedicati.
- **Piano minimo**: leggere i file Swift rilevanti, integrare adapter/factory e stato presentazionale nel ViewModel, renderizzare solo copy/conteggi sicuri in `OptionsView`, aggiungere localizzazioni e test T81-01…T81-22, poi build/test mirati.
- **Vincoli confermati**: niente `.guidedManual` salvo necessità non prevista, niente Timer/BGTask/Realtime/worker/polling, niente SQL/backend, niente Android, niente ProductPrice fuori dal wiring già chiuso in TASK-080, niente reset/truncate/delete outbox.

### EXECUTION completata — 2026-05-08 18:26 -0400
- **Stato esecuzione**: completata; task pronto per **REVIEW**. TASK-081 resta **ACTIVE**, non DONE.
- **Fix markdown iniziali**: corretto range criteri/matrice a **T81-01…T81-22**; verificato che non esisteva un doppione vuoto di heading `## UX Release prevista`.
- **File modificati**:
  - `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
  - `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
  - `iOSMerchandiseControl/SupabaseManualSyncReleaseActivityRegistrationAdapter.swift`
  - `iOSMerchandiseControl/OptionsView.swift`
  - `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
  - `iOSMerchandiseControl/it.lproj/Localizable.strings`
  - `iOSMerchandiseControl/en.lproj/Localizable.strings`
  - `iOSMerchandiseControl/es.lproj/Localizable.strings`
  - `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
  - `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`
  - `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift`
  - `iOSMerchandiseControlTests/SupabaseManualSyncReleaseActivityRegistrationAdapterTests.swift`
  - `docs/MASTER-PLAN.md`
  - `docs/TASKS/TASK-081-supabase-sync-events-outbox-drain-release-ios.md`
- **Implementazione**: aggiunto provider/adapter Release per registrazione attività basato su snapshot aggregati e `SyncEventOutboxDrainService`; `SupabaseManualSyncViewModel` ora prepara la review privacy-safe, espone CTA **“Registra attività sul cloud”** solo dopo **Controlla cloud → Rivedi**, gestisce conferma, retry manuale, cancellazione, auth gate, stati `success/empty/partialRetryable/authRequired/retryableFailure/blocked/cancelled`, summary aggregato e reentrancy guard. `OptionsView` resta wiring/UI presentation: conferma nativa, `ProgressView`, CTA mutative disabilitate durante drain, nessuna logica drain diretta.
- **Ordering UX**: se ci sono azioni catalogo/prezzi e attività locali, prima restano le azioni dati; dopo apply/push la review propone la registrazione attività. Se ci sono solo attività locali, la CTA drain diventa primary action della review.
- **Localizzazione**: aggiunte chiavi IT/EN/ES/zh-Hans con copy naturale e senza jargon tecnico visibile in Release.
- **Test eseguiti**:
  - ✅ `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,id=2B63681C-33A8-4DF2-8687-779E4B42174C' -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncReleaseActivityRegistrationAdapterTests` — **PASS**.
  - ✅ `xcodebuild build -quiet -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,id=2B63681C-33A8-4DF2-8687-779E4B42174C'` — **PASS**.
- **Evidenza T81-01…T81-22**: coperta da test adapter/ViewModel/statici Release UI: empty no-network, drain valido + summary, blocked payload/contract non tecnico, network retryable + retry, cancel, sessione assente, CTA non visibile prima della review, pending count a 0 dopo successo, anti-jargon, ordering dati prima, double tap/retry no concurrent drain, preview solo count/snapshot, localizzazioni 4 lingue e ownership adapter.
- **Rischi residui**: warning Swift concurrency preesistenti/fuori perimetro restano visibili in build in `SyncEventOutboxDrainService.swift` e `SupabaseProductPriceApplyService.swift`; nessun fix applicato per non ampliare il perimetro.
- **Conferme anti-scope**: nessun SQL/backend, nessun Android, nessuna sync automatica, nessun Timer/BGTask/Realtime/worker/polling, nessun cleanup/reset/truncate/delete outbox, nessuna abilitazione `.guidedManual`, nessuna modifica ProductPrice fuori dal wiring esistente.

### Handoff post-execution
- **Prossima fase**: REVIEW.
- **Prossimo agente**: Claude Code / Reviewer.
- **Richiesta review**: verificare coerenza UX/copy, mapping stati, reentrancy e rispetto anti-scope; controllare in particolare che il nuovo adapter sia il solo punto Release che conosce il drain service e che `OptionsView` resti solo presentazionale.
- **Nota**: TASK-082…TASK-085 restano TODO / Planning; TASK-080 resta ultimo completato.

## Fix (Codex)
*(Vuoto.)*

## Review (Claude)
### REVIEW/FIX/CHIUSURA — 2026-05-08 19:09 -0400
Esito review: **FIXED / APPROVED / DONE**.

**Verifiche review**
- Architettura: `OptionsView` resta solo presentation/wiring; nessun riferimento diretto a `SyncEventOutboxDrainService` o `drainOnce` nella card Release. Il drain reale è confinato in `SupabaseManualSyncReleaseActivityRegistrationAdapter`, con ViewModel responsabile di stato, gating, conferma, retry e summary.
- UX/UI: CTA **“Registra attività sul cloud”** compare solo dopo **Controlla cloud → Rivedi**; nessun bottone permanente fuori flow; `ProgressView`, `Button`, `Label`, sheet/alert nativi e SF Symbols coerenti con la UI esistente.
- Privacy: preview e summary usano solo conteggi aggregati; nessun payload, UUID, JSON, RPC, `sync_events` o `outbox` nella copy Release `options.supabase.manualSync.*`.
- Stati: mapping verificato per `success`, `empty`, `partialRetryable`, `authRequired`, `retryableFailure`, `blocked`, `cancelled`.
- Anti-scope: nessun SQL/backend, nessun Android, nessun ProductPrice fuori TASK-080, nessuna sync automatica, nessun Timer/BGTask/Realtime/worker/polling, nessun cleanup/reset/truncate/delete outbox, `.guidedManual` resta non abilitato.
- Duplicati: verificato che `SupabaseManualSyncReleaseActivityRegistrationAdapter.swift` e `SupabaseManualSyncReleaseActivityRegistrationAdapterTests.swift` esistono una sola volta; la duplicazione era solo nel riepilogo testuale.

**Fix applicati in review**
- `OptionsView.swift`: rimosso il limite a 2 righe sul summary della card Release, così il riepilogo finale aggregato resta leggibile per intero.
- `SupabaseManualSyncViewModel.swift`: `confirmActivityRegistration` / `retryActivityRegistration` ora sono no-op se la review non ha preparato un’azione valida; evitato avvio programmatico prima di **Controlla cloud → Rivedi**. Ritoccata la preview ready per non conteggiare due volte le attività già pronte nella riga “Ancora in attesa”.
- `SupabaseManualSyncViewModelTests.swift`: aggiunto test T81 per conferma prima della review e rafforzata verifica accessibilità del summary con tutti i conteggi.

**Test/check eseguiti**
- ✅ `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,id=2B63681C-33A8-4DF2-8687-779E4B42174C' -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncReleaseActivityRegistrationAdapterTests` — **PASS**.
- ✅ `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,id=2B63681C-33A8-4DF2-8687-779E4B42174C'` — **PASS**.
- ✅ `git diff --check` — **PASS**.
- ✅ `plutil -lint` su `Localizable.strings` IT/EN/ES/zh-Hans — **PASS**.

**Rischi residui**
- Restano warning Swift concurrency preesistenti/fuori perimetro in `SyncEventOutboxDrainService.swift` e `SupabaseProductPriceApplyService.swift`, già visibili prima della review TASK-081; non corretti qui per evitare refactor fuori scope.

### Chiusura
I criteri TASK-081 verificabili nel perimetro risultano soddisfatti dopo review/fix/test. **TASK-081 chiuso DONE / Chiusura**. **TASK-082…TASK-085** restano **TODO / Planning**.

---

**TASK-081 è DONE / Chiusura.**
