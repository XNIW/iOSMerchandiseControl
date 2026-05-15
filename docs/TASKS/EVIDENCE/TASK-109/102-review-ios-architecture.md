# TASK-109 — 102 Review iOS Architecture

Review pass: 2026-05-15 02:25 -0400

## Esito

Verdict architetturale: PASS_WITH_NOTES, bloccato solo dalla prova runtime History live non-empty.

## Verifiche codice

- Owner logico app-scoped: confermato in `ContentView`, con `SupabaseManualSyncViewModel` condiviso fra root banner e Options.
- Options: confermato observer/manual trigger. Non e' piu' bootstrap indispensabile e non crea un coordinator separato.
- Auth/scene lifecycle: `ContentView` reagisce a auth presentation e scene active, con gate per evitare run concorrenti.
- Manual Sync now: usa lo stesso ViewModel/coordinator del root flow.
- Review stale/no-op: `hasActionableReviewSignals` evita che warning-only/no-op aprano Review.
- Cancel Review: non apre piu' dialog annidato per il caso non mutativo.
- History adapter Release: gia' su `ModelContainer` + background `ModelContext` in `Task.detached(priority: .utility)`, quindi non muta History sul context UI.

## Fix applicato in review

File: `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`

- Prima: `syncHistoryAfterRun` poteva sincronizzare History subito dopo il dry-run anche quando catalog/price apply era stato appena preparato, creando lavoro remoto prima del commit locale principale.
- Dopo: History sync diretto parte solo se non ci sono staged apply catalog/prezzi; se l'apply e' presente, History viene sincronizzata nel path `applyStagedLocalChanges()`.
- Impatto: riduce doppio lavoro, mantiene ordine commit locale -> History sync, protegge no-op/second sync.

## Copertura aggiunta

File: `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`

- `testDirectSyncDefersHistoryUntilPreparedApplyCompletes`: verifica che History non venga chiamata durante dry-run con ProductPrice apply staged, e venga chiamata una sola volta dopo `applyStagedLocalChangesIfNeeded()`.

## Note non bloccanti

- `operationID` non viene esposto come valore grezzo in UI; la coerenza root/Options e' data dallo stesso ViewModel condiviso.
- I test coprono race/concorrenza principali; non e' stato catturato un Instruments trace.
