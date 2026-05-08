# TASK-065 — Supabase manual sync coordinator dry-run/mock iOS

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-065 |
| **Titolo** | Supabase manual sync coordinator dry-run/mock iOS |
| **File task** | `docs/TASKS/TASK-065-supabase-manual-sync-coordinator-dryrun-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Nessuno / Workspace IDLE |
| **Data creazione** | 2026-05-07 |
| **Ultimo aggiornamento** | 2026-05-07 20:48 -04 — Review tecnica severa completata con **APPROVED_FIXED_DIRECTLY**; fix piccoli mirati solo su XCTest/documentazione/tracking; build/test/check finali PASS; TASK-065 chiuso in **DONE / Chiusura** su override esplicito utente. |
| **Ultimo agente** | Codex / Reviewer+Fixer |

## Dipendenze

- **Dipende da**
  - **TASK-064** (**DONE / Chiusura**) — recovery `sending` stale outbox prima di orchestrazione visibile.
  - **TASK-063** — planning architetturale precedente usato come base progettuale per naming `SupabaseManualSync*`, fasi, taxonomy UX e anti-scope coordinator.
    TASK-063 **non viene riaperto**: TASK-065 non dipende da TASK-063 come task attivo, ma dal contenuto progettuale già prodotto.
  - Servizi esistenti letti come contesto (auth, baseline, push/drain/outbox): **non** modificati in TASK-065 salvo assenza di modifiche effettive.
- **Non riapre** TASK-063 / TASK-064.
- **Non crea** TASK-066 (nessun file task nel workspace per TASK-066).

## Scopo

Introdurre **`SupabaseManualSyncCoordinator`** come **dry-run/mock**: calcola ordinamento fasi, outcome aggregati e messaggi UX **non tecnici**, senza rete live, senza `SupabaseClient` nel coordinator, senza UI Release, senza worker/timer/BGTask/Realtime.

## Anti-scope (rigido)

- No UI Release / no modifiche `OptionsView` per card cloud.
- No coordinator live che chiami Supabase o SwiftData obbligatorio.
- No RPC live `record_sync_event`, no migration/SQL/RLS push.
- No Timer, BGTask, Realtime, worker, sync automatica.
- No cleanup/delete/truncate/reset outbox.
- No Product/ProductPrice full sync.
- No codice Android.
- No file **`TASK-066`**.

## Planning (Claude) — sintesi

Planning funzionale tratto da **TASK-063 §4** e dal brief utente: tipi `SupabaseManualSyncRunMode` / `Phase` / `PhaseOutcome` / `RunSummary`, gate auth → baseline → pending locale → (preview/conferma simulate) → push condizionali → flush concettuale → refresh finale → summary; solo **`dryRun`** eseguito; `guidedManual` / `debugDiagnostics` → summary “modalità non disponibile”; `automatic` → fuori scope.

---

## Criteri di accettazione *(contratto TASK-065)*

| ID | Criterio | Verifica |
|----|----------|----------|
| CA-01 | Tipi Swift puri per run mode, phase, phase outcome, summary, stato UX finale | STATIC |
| CA-02 | Coordinator dry-run `@MainActor` con DI (protocolli) + fake XCTest | STATIC/XCTest |
| CA-03 | `dryRun` unico percorso simulato completo; altri mode bloccati/stub senza mutazioni | XCTest |
| CA-04 | Auth primo gate; baseline letto/deciso una sola volta per run | STATIC/XCTest |
| CA-05 | Zero pending → niente preview/conferma/push/flush/finalRefresh; summary “Tutto aggiornato” | XCTest |
| CA-06 | Push catalogo/prezzi/flush saltati se conteggio pending = 0 | XCTest |
| CA-07 | Ordine fasi con corretto quando tutti i pending attivi | XCTest |
| CA-08 | Reentrancy: seconda run concorrente → `concurrentRunNotAllowed` | XCTest |
| CA-09 | Cancellation → `cancelled`, mai successo falso | XCTest |
| CA-10 | Partial simulato (prezzo / flush dopo successo precedente) | XCTest |
| CA-11 | Messaggi utente senza jargon vietato (lista TASK-065 brief) | XCTest |
| CA-12 | Coordinator Swift senza `SupabaseClient` / `.rpc` | STATIC/XCTest |
| CA-13 | Privacy: summary senza barcode/payload/entity_ids raw nei test | XCTest |
| CA-14 | Review focus documentato per Claude | STATIC |
| CA-15 | Decisioni D65-02…D65-05 documentate | STATIC |
| CA-16 | Dipendenza TASK-063 chiarita come planning base precedente, non task riaperto | STATIC |
| CA-17 | Android/Supabase citati solo come riferimento documentale/funzionale, non come fonte di implementazione copiata | STATIC |

---

## Execution (Codex / Cursor)

### Obiettivo compreso

Costruire il “cervello” testabile della futura sincronizzazione cloud guidata: **solo dry-run** con fake, ordine fasi e taxonomy UX allineati a TASK-063, senza integrare la UI Release (TASK-067).

### Fonti lette *(documentazione)*

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-063-supabase-production-safe-sync-orchestrator-planning-ios.md` (§4.d–§4.g, naming)
- `docs/TASKS/TASK-064-supabase-sync-events-outbox-sending-stale-recovery-ios.md` (contesto post-outbox)
- `docs/TASKS/TASK-060-supabase-sync-events-outbox-drain-g2-ios.md`, `TASK-061`, `TASK-062` (lettura mirata per contesto drain/DEBUG — **nessuna modifica**)
- Android master plan e Supabase master plan: riferimento documentale fornito dall'utente per allineamento, **non verificato live** in TASK-065.
  - Android resta solo riferimento funzionale per outcome, retry head-of-line, partial state e privacy-safe logging: TASK-065 **non** deve copiare Android.
  - Supabase resta riferimento di contratto/schema: nessun live check, nessuna SQL change, nessuna migration/RPC/RLS in TASK-065.

### Fonti lette *(codice iOS — contesto, senza dipendenza runtime nel coordinator)*

- `SupabaseAuthService.swift`, `SupabaseCatalogBaselineReader.swift` (concetto baseline/auth)
- `SyncEventOutbox*` servizi/modelli (intent flush concettuale / privacy — coordinator non li importa)
- Pattern test `@MainActor` + `@testable import` da suite outbox esistente.

### Differenze iOS vs Android/Supabase *(rilevanti)*

- **iOS**: SwiftData + sync manuale frammentato; drain/outbox già isolati (**TASK-060/061**); coordinator dry-run deve restare **senza** Room/WorkManager e senza assumere un unico worker Android.
- **Android docs** (intent da TASK-063): outcome non ambigui + retry head-of-line — qui replicato solo a livello **fasi/outcome aggregati**, non porting Kotlin.
- Android ha già orchestrazione più matura e logging strutturato; iOS in TASK-065 implementa solo dry-run/mock.
- Android usa pattern Room/Repository/WorkManager-like; iOS deve restare SwiftUI/SwiftData/service-oriented.
- iOS non deve introdurre worker o background sync in questa slice.
- Obiettivo iOS: costruire prima la state machine testabile, poi ViewModel/UI nei task successivi.

### Piano minimo

1. Modelli `SupabaseManualSync*` + copy UX italiano centralizzato.
2. Protocolli DI + `SupabaseManualSyncCoordinator.run(mode:sessionID:)`.
3. XCTest + fake `SupabaseManualSyncCoordinatorDryRunFake`.

### Modifiche fatte

| File | Ruolo |
|------|--------|
| `iOSMerchandiseControl/SupabaseManualSyncCoordinatorModels.swift` | Enum/struct: mode, phase, outcome, summary, privacy counts, copy UX |
| `iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift` | Coordinator dry-run + protocolli auth/baseline/pending/simulation |
| `iOSMerchandiseControlTests/SupabaseManualSyncCoordinatorTests.swift` | XCTest + fake integrato |
| `docs/TASKS/TASK-065-supabase-manual-sync-coordinator-dryrun-ios.md` | Questo task |
| `docs/MASTER-PLAN.md` | Task attivo, backlog, workflow |

### Cosa NON è stato implementato *(come richiesto)*

- Integrazione con `SupabaseAuthService` / baseline reader reali.
- `guidedManual` eseguibile o UI Release / ViewModel cloud (**TASK-067+**).
- Chiamate live, RPC, Realtime, BGTask, Timer, cleanup outbox.
- File o task **TASK-066**.

### Check eseguiti

| Check | Esito |
|-------|--------|
| Build + test `SupabaseManualSyncCoordinatorTests` (Simulator **iPhone 16e**, id `423B9CA2-9C81-4850-898A-AE064A3A1C09`) | ✅ **PASS** |
| Regressioni: `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxDrainServiceTests`, `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests` | ✅ **PASS** |
| `git diff --check` | ✅ **PASS** |
| Grep anti-scope su `SupabaseManualSyncCoordinator*.swift`: `BGTask`, `Timer`, `Realtime`, `SupabaseClient`, `.rpc`, `OptionsView`, `TASK-066` | ✅ **nessun match** |
| Test ProductPrice / manual push | ⚠️ **NON ESEGUITI** — codice ProductPrice/manual push **non modificato** nel diff TASK-065 |

### Anti-scope confermati

- Nessuna UI Release / OptionsView; nessun live Supabase nel coordinator; nessun SQL/migration; nessun TASK-066 creato.

### Rischi residui / note

- **`guidedManual` / `debugDiagnostics`**: restano summary “modalità non disponibile” — OK per slice TASK-065; wiring futuro in task successivi.
- **Summary blocked auth/baseline**: `summary` viene aggiunto in `executedPhases` nel finalize per chiudere il racconto UX anche senza ledger phase-outcome per quella fase sintetica — da validare in review se si preferisce ledger separato.
- **Partial “solo flush fallito”**: senza almeno una mutation completata prima, l’aggregatore classifica come **connectivity** (coerente con “nessun successo precedente”); scenario “catalog ok + flush fallito” coperto dal test aggiornato.
- **Dry-run percepito come “sync pronta”**: il naming potrebbe sembrare più completo del perimetro reale se letto fuori contesto. Mitigazione: documentare che non esegue mutazioni live e non sostituisce TASK-066/TASK-067.
- **Summary user-facing vs phase ledger**: i due livelli potrebbero avere semantiche diverse. Mitigazione: review Claude deve decidere se separarli prima di TASK-066.
- **Fake services non provano integrazione reale**: i fake validano state machine e outcome, non adapter/live path. Mitigazione: TASK-066/TASK-067 e validazioni future dovranno aggiungere adapter/ViewModel/live validation separati.

### Review focus consigliato per Claude

- Verificare se `summary` aggiunta in `executedPhases` nei casi blocked è semanticamente corretta o se serve distinguere ledger tecnico e summary UX.
- Verificare mapping partial vs connectivity:
  - fallimento senza alcun successo precedente può essere connectivity;
  - fallimento dopo una fase completata deve diventare partial.
- Verificare che baseline venga decisa una sola volta per run.
- Verificare che `automatic` sia realmente blocked/out-of-scope.
- Verificare che `guidedManual` e `debugDiagnostics` non facciano mutazioni.
- Verificare che nessun copy user-facing contenga jargon vietato.
- Verificare che il coordinator non abbia dipendenza diretta da `SupabaseClient`.
- Verificare che reentrancy owner/session scoped sia abbastanza robusta per il prossimo ViewModel.

### Checklist review-ready

- [x] TASK-065 resta ACTIVE / REVIEW fino alla review; chiuso DONE solo dopo override utente esplicito.
- [x] Nessun Swift modificato nella rifinitura documentale review-only.
- [x] Test modificati solo durante review/fix tecnico autorizzato, per rafforzare coverage TASK-065.
- [x] TASK-063 non riaperto.
- [x] TASK-064 resta DONE.
- [x] TASK-066 non creato.
- [x] Review focus per Claude presente e risolto nella review.
- [x] Decisioni D65-02…D65-05 presenti e aggiornate.
- [x] Anti-scope invariato.
- [x] Chiusura compilata solo dopo review/fix PASS.

### Handoff → Review (Claude)

- **Prossima fase:** REVIEW
- **Prossimo agente:** Claude / Reviewer
- **Azione consigliata:** review tecnica su sequencing, mapping partial vs connectivity, coerenza con TASK-063 §4.g copy; **non** marcare DONE senza utente.

---

## Review (Claude)

### 2026-05-07 20:48 -04 — Review tecnica severa / APPROVED_FIXED_DIRECTLY

**Verdetto review:** **APPROVED_FIXED_DIRECTLY**.

**Override esplicito utente:** la richiesta di review autorizza la chiusura in **DONE / Chiusura** se la review termina senza problemi grandi. Sono emersi solo gap piccoli di copertura test/documentazione; il comportamento del coordinator dry-run è risultato coerente con TASK-063/TASK-065 e non ha richiesto cambio architetturale.

**Esito code review:**
- State machine dry-run coerente: `authCheck` primo gate, `baselineCheck` una sola volta per run, `localPendingCheck` read-only, zero pending senza preview/conferma/push/flush/finalRefresh.
- `guidedManual`, `debugDiagnostics` e `automatic` restano bloccati/out-of-scope e non chiamano dipendenze.
- Mapping confermato: fallimento retryable senza successi mutativi precedenti → `connectivityIssue`; fallimento dopo una mutation completata/partial → `partialSync`; baseline/auth bloccano con copy dedicato.
- `summary` in `executedPhases` nei blocked early-exit è accettato per TASK-065 come fase UX sintetica prodotta dalla run; non viene separato dal phase ledger in questa slice. Se TASK-066 richiede un ledger tecnico più stretto, separarlo lì.
- Coordinator privo di dipendenza diretta da `SupabaseClient`, `.rpc`, `.from`, `.upsert`, `.channel`, `ModelContext`, Timer/BGTask/Realtime/worker.
- `project.pbxproj` non richiede modifiche: app e test usano `PBXFileSystemSynchronizedRootGroup`, e build/test hanno confermato membership corretta dei nuovi file.

**Problemi piccoli trovati:**
- Coverage XCTest non fissava ancora in modo esplicito call-order e no-duplicate-work (`auth`/`baseline`/pending snapshot).
- Mancavano test diretti per `guidedManual` e `debugDiagnostics` senza mutazioni/dipendenze.
- Mancavano test espliciti per preview retryable che blocca downstream, flush retryable senza successo precedente → connectivity, errore non retryable → copy tecnico-soft.
- Grep/static test anti-scope e privacy/jargon erano troppo stretti sul solo `SupabaseClient`/`.rpc`.

**Fix diretti applicati:**
- Aggiunto call ledger nel fake di test per verificare auth/baseline/preflight, skip dei rami inutili e zero chiamate nelle modalità bloccate.
- Aggiunti/rafforzati XCTest per: preview failure senza confirmation/mutation/finalRefresh; flush failure senza successo precedente; hard failure tecnico-soft; privacy summary solo counts aggregati; assenza token/email/URL nel copy user-facing; anti-scope statico esteso.
- Nessun file Swift di produzione modificato dopo la review: i fix sono su `SupabaseManualSyncCoordinatorTests.swift` e tracking/documentazione.

**Check finali review/fix:**

| Check | Stato | Esito |
|------|-------|-------|
| Build Debug iPhone 16e OS 26.2 | ✅ ESEGUITO | `xcodebuild ... build` → **BUILD SUCCEEDED**. Warning AppIntents metadata Xcode già noto/preesistente; nessun warning Swift nuovo TASK-065. |
| XCTest mirati TASK-065 | ✅ ESEGUITO | `SupabaseManualSyncCoordinatorTests` → **TEST SUCCEEDED**. |
| Regressioni outbox/recorder richieste | ✅ ESEGUITO | `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxDrainServiceTests`, `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests` → **TEST SUCCEEDED**. |
| `git diff --check` | ✅ ESEGUITO | PASS. |
| Whitespace sui file nuovi/untracked TASK-065 | ✅ ESEGUITO | `rg "[[:blank:]]+$"` sui file TASK-065 → nessun match. |
| Grep anti-scope coordinator produzione | ✅ ESEGUITO | Nessun `BGTask`, `Timer`, `Realtime`, `.channel`, `SupabaseClient`, `.rpc`, `.from`, `.upsert`, `OptionsView`, `Localizable`, delete/truncate/reset, `TASK-066` nei file coordinator. |
| Grep user-facing jargon | ✅ ESEGUITO | Solo falsi positivi nella lista vietata del test; nessun jargon nel copy user-facing. |
| SQL/migration/RPC/RLS/db push | ✅ ESEGUITO | Nessun file o modifica SQL/migration; nessun live check Supabase eseguito. |
| TASK-066 | ✅ ESEGUITO | Nessun file TASK-066 creato. |

**Note sui tentativi intermedi:** un primo `xcodebuild` senza OS esplicito è fallito perché il device `iPhone 16e` era ambiguo; i comandi finali sono stati rieseguiti con `OS=26.2` e sono PASS. Una compilazione intermedia ha segnalato un errore di visibilità nel nuovo fake test, corretto prima dei check finali.

## Fix (Codex)

### 2026-05-07 20:48 -04 — Fix piccoli mirati in review

- `iOSMerchandiseControlTests/SupabaseManualSyncCoordinatorTests.swift`
  - aggiunto `SupabaseManualSyncCoordinatorFakeCall` e ledger chiamate nel fake;
  - aggiunti test per no-duplicate-work, mode stub senza dipendenze, preview failure, flush connectivity, hard failure, privacy counts e anti-scope statico;
  - aggiornato `String(contentsOf:)` a `String(contentsOf:encoding:)` per evitare warning nuovo.
- `docs/TASKS/TASK-065-supabase-manual-sync-coordinator-dryrun-ios.md`
  - compilate Review, Fix e Chiusura;
  - decisioni D65-02/D65-03 confermate in review;
  - checklist review-ready aggiornata.
- `docs/MASTER-PLAN.md`
  - riallineato a **IDLE**;
  - ultimo completato aggiornato a **TASK-065 DONE / Chiusura**;
  - TASK-063/TASK-064 mantenuti invariati come base planning/DONE;
  - TASK-066 indicato solo come prossimo consigliato, **non creato**; UI Release finale resta TASK-067.

## Decisioni

### Decisioni attive già tracciate

| ID | Decisione | Stato |
|----|-----------|--------|
| D65-01 | Phase flush concettuale denominata `pendingEventsFlush` nel tipo pubblico; implementazione dry-run usa simulatore `simulateQueuedCloudOperationsFlushPhase` senza jargon nei messaggi UX | attiva |

### Decisioni da confermare in review

| ID | Decisione | Stato | Nota |
|----|-----------|--------|------|
| D65-02 | `summary` come fase eseguita nei blocked early-exit | confermata in review | Accettata per TASK-065 come fase UX sintetica prodotta dalla run. Separare ledger tecnico/final summary solo se TASK-066 lo richiede. |
| D65-03 | Classificazione “connectivity” quando flush fallisce senza successo precedente | confermata in review | Se una fase mutativa precedente è completed/partial, allora deve essere partial; coperto da test. |
| D65-04 | `guidedManual` resta stub/bloccato in TASK-065 | attiva | Nessuna mutazione remota finché non esiste task dedicato. |
| D65-05 | Nessuna UI Release prima di TASK-067 | attiva | TASK-066 può al massimo introdurre ViewModel/stati o host minimo interno/testabile, non UI pubblica finale. |

---

## Chiusura

TASK-065 **DONE / Chiusura**.

- **Verdict:** **APPROVED_FIXED_DIRECTLY**.
- **Build/test/check:** PASS in chiusura.
- **Anti-scope confermati:** no UI Release, no `OptionsView`, no `Localizable`, no coordinator live, no Supabase live, no `SupabaseClient` diretto nel coordinator, no RPC live `record_sync_event`, no SQL/migration/RLS/db push, no Timer, no BGTask, no Realtime/channel, no worker, no sync automatica, no cleanup/delete/truncate/reset outbox, no Product/ProductPrice full sync, no Android.
- **Rischi residui:** dry-run/mock non prova integrazione reale; fake services non sostituiscono adapter/ViewModel/live validation futuri. Prossimo step consigliato: **TASK-066** ViewModel/stati non-DEBUG per sync guidata, senza UI Release finale. **TASK-067** resta UI Release finale.
- **TASK-066:** non creato.
