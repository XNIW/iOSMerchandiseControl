# TASK-135 — TASK-132D Immediate Drift Sync Unblocker

## Stato
- Task ID: TASK-135
- Workstream alias: TASK-132D
- Parent: TASK-132 DONE
- Stato task: ACTIVE
- Fase attuale: REVIEW
- Responsabile attuale: Claude / Reviewer
- Ultimo aggiornamento: 2026-06-17 18:30 -0400
- Ultimo agente: Codex / Hotfix executor

## User Override
TASK-132 e' gia' DONE nel tracking storico. Questo hotfix e' stato eseguito su istruzione esplicita utente come workstream post-DONE, senza riscrivere la storia di TASK-132 e senza riusare TASK-134 come task canonico.

## Scopo
Sbloccare la sync automatica quando account/rete sono validi e ci sono baseline assente/stale, drift/parity, remote events o delta locali trusted. "Blocked" non deve significare waiting/no-op: deve restare solo per auth/rete/permessi/account o conflitti reali che richiedono scelta utente.

## Criteri di accettazione
- Baseline assente con account valido non torna noWork: avvia bootstrap/recovery automatico.
- Bootstrap/fullRecovery iOS passano dal runtime automatico e usano snapshot recovery provider.
- Pending locale trusted iOS usa sequenza push delta + drain finale.
- Remote event/drift iOS con pending usa sequenza pull-first + push delta + drain finale.
- Android auth/foreground/network possono attivare pull-only reconcile guardato anche se il catalogo locale non e' vuoto.
- Android push automatico resta limitato a delta locali trusted e schedula un drain finale.
- UI iOS/Android non lascia "noWork"/"Waiting" mascherare baseline/drift o outcome automatici riusciti.
- Nessun service_role, nessun bypass RLS, nessun push-all.

## Execution
Codex ha applicato il fix minimo in:
- iOS decision/runtime/orchestrator/background/options:
  - `SyncDecisionEngine.swift`
  - `SyncDecisionInputProvider.swift`
  - `AutomaticSyncEngine.swift`
  - `SyncOrchestrator.swift`
  - `SyncBackgroundTaskScheduler.swift`
  - `OptionsView.swift`
  - localizzazioni Options EN/IT/ES/ZH
- iOS tests:
  - `SyncDecisionEngineTests.swift`
  - `Task118AutomaticDomainTests.swift`
  - `Task119AutomaticArchitectureTests.swift`
- Android autosync/UI:
  - `CatalogAutoSyncCoordinator.kt`
  - `CatalogSyncViewModel.kt`
- Android tests:
  - `CatalogAutoSyncCoordinatorTest.kt`
  - `CatalogSyncViewModelTest.kt`

## Handoff post-fix
Reviewer deve verificare soprattutto:
- iOS recovery con pending locali attivi: `replaceLocalCatalogWithRemoteSnapshot` continua a proteggere pending non classificabili; il follow-up UI field-by-field resta necessario per conflitti reali.
- Android pull-only reconcile su foreground/network/auth e' guardato da `BOOTSTRAP_RETRY_GUARD_MS`, ma puo' comunque essere costoso su cataloghi grandi.
- Live runtime non ancora eseguito in questo giro: serve conferma iOS device/simulator autenticato + Android device + Supabase counts/screenshot.

## Evidence
Evidence root:
`docs/TASKS/EVIDENCE/TASK-132D-hotfix-20260617-182515/`

Check eseguiti:
- iOS targeted tests: PASS, 39 tests / 0 failures.
- iOS Debug build: PASS.
- Android targeted tests: PASS.
- Android assembleDebug + lintDebug: PASS.
- iOS git diff check: PASS.
- Android git diff check: PASS.
- service_role/bypass scan: PASS_WITH_NOTE, solo guard di rifiuto in `SupabaseConfig.swift`.

Check non eseguiti:
- Live iOS runtime con account reale: NON ESEGUITO in questo giro.
- Live Android runtime con account reale: NON ESEGUITO in questo giro.
- Supabase live count parity e cleanup: NON ESEGUITO in questo giro.
- Screenshot Options iOS/Android post-fix: NON ESEGUITO in questo giro.

## Rischi rimasti
- DONE non dichiarabile senza i criteri live del chiarimento TASK-132D.
- La UI completa `SyncResolutionPrompt` field-by-field resta follow-up se i conflitti reali devono essere presentati in un nuovo sheet dedicato invece delle superfici TASK-126 esistenti.
