# TASK-066 — Supabase manual sync ViewModel/stati non-DEBUG iOS

## Informazioni generali
- **Task ID**: TASK-066
- **Titolo**: Supabase manual sync ViewModel/stati non-DEBUG iOS
- **File task**: `docs/TASKS/TASK-066-supabase-manual-sync-viewmodel-states-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Nessuno / Workspace IDLE
- **Data creazione**: 2026-05-07
- **Ultimo aggiornamento**: 2026-05-07 21:10 -04 — Review tecnica severa completata con **APPROVED_FIXED_DIRECTLY**; fix piccoli applicati a ViewModel/test; build/test/check PASS; TASK-066 chiuso in **DONE / Chiusura** su override esplicito utente.
- **Ultimo agente che ha operato**: Codex / Reviewer+Fixer

## Dipendenze
- **Dipende da**: TASK-065 (coordinator dry-run + modelli) **DONE**; TASK-063 planning base; TASK-064 **DONE**
- **Sblocca**: TASK-067 (UI Release «Sincronizzazione cloud» in `OptionsView` — **non creato in questo task**)

## Scopo
Introdurre uno strato **ViewModel non-DEBUG** (`SupabaseManualSyncViewModel`) sopra `SupabaseManualSyncCoordinator` per esporre stati **user-facing**, **testabili** e **privacy-safe** della futura sincronizzazione cloud guidata, senza implementare la UI Release finale.

## Contesto
TASK-065 ha implementato il coordinator dry-run/mock. TASK-066 aggiunge la superficie SwiftUI-oriented (titoli, sottotitoli, CTA, `isRunning`, `canStart`, riepilogo ultimo run) con DI verso un protocollo `SupabaseManualSyncCoordinating`, senza rete live obbligatoria.

## Non incluso (anti-scope)
- Nessuna UI Release in `OptionsView` / card pubblica completa (resta futuro follow-up TASK-067+).
- Nessun `BGTask`, Timer periodico, Realtime, worker/background sync, sync automatica.
- Nessun SQL, migration, `db push`, RPC change, RLS, chiamate Supabase live obbligatorie.
- Nessun cleanup/delete/truncate/reset outbox.
- Nessun full sync Product/ProductPrice.
- Nessun uso diretto di `SupabaseClient` nel ViewModel.
- Nessun termine tecnico visibile Release: vietati nei copy «outbox», «drain», `sync_events`, «RPC», «payload», «retryable» come stringhe UX.
- Nessuna modifica Android; **non** creare file TASK-067.

## File potenzialmente coinvolti
- `SupabaseManualSyncCoordinating.swift` — protocol DI
- `SupabaseManualSyncViewModel.swift` — ViewModel `@MainActor` + `ObservableObject`
- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`
- Regressioni/fix minimo coordinator test: percorsi statici su `SupabaseManualSyncCoordinating.swift`

## Criteri di accettazione
- [x] Esiste un ViewModel non-DEBUG (`SupabaseManualSyncViewModel`) testabile tramite coordinator fake/mocks.
- [x] Nessun `SupabaseClient` né rete diretta nel ViewModel; delega tramite `SupabaseManualSyncCoordinating`.
- [x] Stati user-facing mappati da `SupabaseManualSyncRunSummary` / `finalState` con copy italiano non tecnico; partial/auth/baseline/connectivity/cancel/technical non mascherati come successo omogeneo.
- [x] Proprietà SwiftUI-ready: `title`, `subtitle`, `primaryActionTitle`, `isRunning`, `canStart`, `pendingConfirmation` / `shouldShowConfirmation` (stub), `lastSummary`, `lastUserMessage`, dettaglio aggregati privacy-safe opzionale.
- [x] XCTest mirati TASK-066 + regressioni coordinator TASK-065 e suite outbox/drain/recording elencate sotto Execution.
- [x] Nessuna automazione background; MASTER-PLAN aggiornato per task attivo durante execution e passaggio a REVIEW.

## Decisioni
| # | Decisione | Alternative scartate | Motivazione | Stato |
|---|-----------|---------------------|-------------|-------|
| D66-01 | Protocol `SupabaseManualSyncCoordinating` + extension su coordinator reale | ViewModel dipendenza concreta | Testabilità fake/mocks senza cambi logica TASK-065 | attiva |
| D66-02 | Successo UX titolo uniforme `"Tutto aggiornato"` per `.completedSuccessfully` **e** `.allUpToDate` | Solo headline coordinator | Criteri accettazione success headline UX coerente | attiva |
| D66-03 | **`USER OVERRIDE`** controllato: creazione task + execution senza TASK-067 e senza pianificatore Claude dedicato questo turno | Workflow standard PLANNING Claude-first | Direttiva utente esplicita 2026-05-07 | attiva |

---

## Planning (Claude) ← placeholder consolidato da brief utente

### Obiettivo
Layer ViewModel sopra coordinator per stati stabili idle/ready, running, success, partial, blocked auth/baseline, connectivity retry, cancelled, failure tecnico-soft, con conferma non mascheramenti.

### File da modificare
Come sezione «File potenzialmente coinvolti» + test.

### Handoff storico → Execution
- Handoff implicito dall’override utente verso **Cursor / Executor** per implementation + XCTest documentati nella sezione Execution.

---

## Execution (Cursor/Codex)

### Obiettivo compreso
Implementare DI + ViewModel `@MainActor`/`ObservableObject` che traduce gli outcome coordinator in stato presentabile; XCTest con fake/intercettatori; vietati jargon e superfici LIVE; zero UI Release `OptionsView`.

### File controllati
`docs/MASTER-PLAN.md`, `TASK-065` artefatti coordinator, TEST-065 `SupabaseManualSyncCoordinatorTests.swift`, `SupabaseManualSyncCoordinator*.swift`.

### Piano minimo eseguito
1. Aggiunto `SupabaseManualSyncCoordinating` + conformità coordinator.
2. Aggiunto `SupabaseManualSyncViewModel` con enum pubblico `SupabaseManualSyncUserPresentationKind` e mapping copy.
3. Aggiunta suite `SupabaseManualSyncViewModelTests` (closure fake, interceptor conteggi, integrazione coordinator dry-run).
4. Esteso test statico TASK-065 a `SupabaseManualSyncCoordinating.swift`.

### Modifiche fatte (sintesi)
- **Nuovi file app**: `SupabaseManualSyncCoordinating.swift`, `SupabaseManualSyncViewModel.swift`.
- **Nuovi file test**: `SupabaseManualSyncViewModelTests.swift`.
- **Modificati**: `SupabaseManualSyncCoordinatorTests.swift` (percorsi statici).
- **Doc**: questo file TASK-066 + `MASTER-PLAN`.

### Check eseguiti
- ✅ **`xcodebuild build`** Debug — Simulator `iPhone 16e` OS 26.2 — BUILD SUCCEEDED
- ✅ **`xcodebuild test`** `-parallel-testing-enabled NO` — `SupabaseManualSyncViewModelTests` + `SupabaseManualSyncCoordinatorTests` — PASS (33 test)
- ✅ **Regressioni** outbox/drain/recording/live recorder — PASS (148 test selezionati: State, LocalStore, DrainService, Enqueue, Recording, LiveRecorder)
- ✅ **`git diff --check`** — PASS
- ✅ **grep** produzione ViewModel (`SupabaseManualSyncViewModel.swift`) — nessuno tra `BGTask`, `Timer`, `Realtime`, `worker`, `.rpc`, `.channel`, `SupabaseClient`, `OptionsView`, stringhe jargon vietate nei copy pubblicati nella VM
- ✅ **grep test** (`testViewModelSourcesAvoidForbiddenScopeTerms`) — Coordinating + ViewModel swift senza scope negato nel file list
- ⚠️ **`xcodebuild test` parallel default**: in ambiente Xcode rilevati fallimenti intermittenti Simulator clone / launch; mitigazione: `-parallel-testing-enabled NO` → PASS deterministici (documentato come rischio residuo infra)

### Rischi rimasti / follow-up
- Confermare in CI/policy progetto uso `-parallel-testing-enabled NO` per suite Xcode instabili oppure pinning destination unico. **UI Release/options card** delegata esplicitamente a follow-up TASK-067+ (solo citazione documentale qui; vietato crearne il file ora).
- `guidedManual` coordinator resta **non eseguito** in slice TASK-065: entry point pubblico usa `startDryRunVerification()` / `start(with: .dryRun)` finché TASK-067+ non espone run guidato live.

---

## Handoff post-execution → Review (Claude)
- **Prossima fase**: REVIEW
- **Prossimo agente**: Claude / Reviewer (o reviewer designato nel workflow locale)
- **Azione consigliata**: review tecnica su mapping stati/coercizione success headline, wording idle/running (`Sincronizzazione cloud guidata`), e sufficienza stub `pendingConfirmation`/`shouldShowConfirmation` per TASK-067. Confermare **nessun TASK-067** creato accidentalmente nel repo.


## Review (Claude)

### 2026-05-07 21:10 -04 — Review tecnica severa / APPROVED_FIXED_DIRECTLY

**Verdetto review:** **APPROVED_FIXED_DIRECTLY**.

**Override esplicito utente:** la richiesta autorizza review tecnica severa in fase REVIEW e chiusura in **DONE / Chiusura** se restano solo problemi piccoli/medi correggibili direttamente. Sono emersi solo fix piccoli nel layer ViewModel/test; nessun cambio sostanziale a TASK-065 o all'architettura.

**Esito code review:**
- Architettura coerente: `SupabaseManualSyncViewModel` non usa `SupabaseClient`, `.rpc`, `.channel` o rete diretta; dipende solo da `SupabaseManualSyncCoordinating`.
- Protocollo DI minimale: un solo metodo `run(mode:sessionID:)`, fakeable e senza wrapper ridondanti.
- Mapping coordinator → UX centralizzato nel ViewModel, con stati distinti idle/running/success/partial/auth/baseline/connectivity/cancel/technical/mode/busy.
- Coordinator TASK-065 non modificato nel comportamento; resta dry-run/mock come da scope.
- Nessuna UI Release in `OptionsView`, nessun file TASK-067 creato, nessuna automazione background o integrazione live Supabase.
- Localizzazione: le stringhe hardcoded italiane sono accettate per questa slice perché TASK-066 non introduce UI finale e il contratto richiede copy IT user-facing testabile nel ViewModel. La UI pubblica TASK-067 dovrà decidere il passaggio a chiavi `Localizable.strings` seguendo il pattern esistente di `OptionsView`.

**Problemi piccoli trovati:**
- Dopo un summary `.concurrentRunNotAllowed`, `canStart` poteva restare `false` via `cannotStartConcurrently`, lasciando la futura UI senza una via naturale di retry.
- Auth/baseline/concurrent busy potevano mostrare sottotitolo duplicato rispetto al titolo perché il coordinator usa lo stesso testo per headline e suggested next step.
- CTA auth/baseline erano troppo generiche (`Riprova`) per uno stato che richiede login o riallineamento.
- Mancava copertura XCTest diretta su busy esterno/canStart e su copy non duplicato per auth/baseline.

**Check finali review/fix:**

| Check | Stato | Esito |
|------|-------|-------|
| Build Debug iPhone 16e | ✅ ESEGUITO | `xcodebuild ... build` su Simulator `423B9CA2-9C81-4850-898A-AE064A3A1C09` → **BUILD SUCCEEDED**. Warning AppIntents metadata Xcode già noto/preesistente; nessun warning Swift nuovo rilevato. |
| XCTest mirati TASK-066 + TASK-065 | ✅ ESEGUITO | `SupabaseManualSyncViewModelTests` + `SupabaseManualSyncCoordinatorTests` con `-parallel-testing-enabled NO` → **33 test PASS**. |
| Regressioni outbox/recording richieste | ✅ ESEGUITO | `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxDrainServiceTests`, `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests` → **148 test PASS**. |
| `git diff --check` | ✅ ESEGUITO | PASS. |
| Grep anti-scope produzione TASK-066 | ✅ ESEGUITO | Nessun `BGTask`, `Timer`, `Realtime`, `worker`, `SupabaseClient`, `.rpc`, `.channel`, `OptionsView`, `TASK-067` nei file Swift produzione `SupabaseManualSync*`. |
| Grep copy user-facing jargon | ✅ ESEGUITO | Nessuna stringa Swift user-facing in `SupabaseManualSyncViewModel.swift` / `SupabaseManualSyncCoordinatorModels.swift` contiene `outbox`, `drain`, `sync_events`, `RPC`, `payload`, `retryable`. |
| TASK-067 file | ✅ ESEGUITO | `find docs/TASKS -name '*TASK-067*'` → nessun file. |
| Criteri di accettazione | ✅ ESEGUITO | Tutti i CA TASK-066 verificati dopo fix. |

**Note ambiente:** i test mirati hanno loggato un errore CoreData del Simulator su store locale creato da build con versione Persistence diversa; la suite è comunque PASS e il log non è collegato ai file TASK-066. Resta mitigabile pulendo app/simulator se diventasse rumore di CI.

## Fix (Codex)

### 2026-05-07 21:10 -04 — Fix piccoli diretti in review

- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
  - `canStart` ora dipende solo da `isRunning`, evitando lock permanente dopo busy/concurrent esterno;
  - aggiunto helper `subtitleCandidate` per evitare titolo/sottotitolo duplicati;
  - copy auth/baseline/concurrent reso più utile per TASK-067 (`Accedi`, `Riallinea dati`, sottotitoli non tecnici).
- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`
  - test aggiornati per `canStart` durante/dopo run;
  - aggiunto test su busy/concurrent esterno con retry disponibile e copy non duplicato;
  - rafforzati test auth/baseline su CTA e assenza duplicazione.
- Nessuna modifica al comportamento di `SupabaseManualSyncCoordinator` TASK-065.

## Chiusura
TASK-066 **DONE / Chiusura**.

- **Verdict:** **APPROVED_FIXED_DIRECTLY**.
- **Build/test/check:** PASS in chiusura.
- **Anti-scope confermati:** no UI Release, no `OptionsView`, no TASK-067, no `SupabaseClient`/rete diretta nel ViewModel, no Supabase live/RPC/SQL/migration/RLS, no Timer/BGTask/Realtime/channel/worker/sync automatica, no cleanup/delete/truncate/reset outbox, no Product/ProductPrice full sync, no Android.
- **Rischi residui:** `guidedManual` resta non eseguito finché TASK-067+ non lo espone; copy hardcoded IT accettato per questa slice ma localizzazione UI pubblica va trattata in TASK-067; possibile rumore Xcode/Simulator (`-parallel-testing-enabled NO`, store CoreData locale) da gestire in CI se necessario.
- **Prossimo consigliato:** TASK-067 UI Release «Sincronizzazione cloud» in `OptionsView`. **TASK-067 non creato** in TASK-066.
