# TASK-108 — UI freeze / MainActor audit

Date: 2026-05-14 14:24 -0400  
Executor: Codex  
Scope: FIX reale ma misurato su jank Options / sync progress.

## Preflight

- iOS `git fetch origin`: ESEGUITO, nessun output di errore.
- Android `git fetch origin`: ESEGUITO, nessun output di errore.
- iOS HEAD: `74480c20c654a07174ba99dede2458d914426ab2`.
- Android HEAD: `7cfc536b7200a7e2e4a2224800650d2e0b7f7ac0`.
- iOS worktree gia' sporca prima di questo FIX: tracking TASK-108, `SupabaseProductPriceApplyService.swift`, evidence `52`...`60`.
- Android worktree gia' sporca prima di questo FIX: ProductPrice page streaming e tracking.

## MainActor / threading audit

| Domanda | Evidenza | Esito |
|---|---|---|
| Fetch remoto fuori MainActor? | `SupabaseProductPriceApplyService` e `SupabasePullApplyService` sono `@MainActor`, ma i fetch Supabase sono `await` verso provider/remoto; la rete sospende il main actor, la continuazione torna su MainActor. | PARTIAL: non blocca CPU durante rete, ma orchestration resta MainActor. |
| Decode fuori MainActor? | Decode e client Supabase vivono nei provider remoti; non e' stata introdotta decodifica manuale nel View. | STATIC OK, non misurato separatamente. |
| Loop 290k ProductPrice su MainActor? | Si': apply SwiftData usa `ModelContext`, quindi il loop page-local resta su actor del context. | CAUSA POTENZIALE JANK. |
| `ModelContext.save()` su MainActor? | Si', per vincolo SwiftData/context corrente. | CAUSA POTENZIALE JANK durante save pagina. |
| Progress update troppo frequenti? | Prima: ProductPrice pubblicava fino a fetch/apply/save/apply per pagina; catalog/history anche a ogni batch/riga. | FIXATO con throttling UI. |
| Options invalidata a ogni pagina? | Si', ogni `@Published progressState` invalida la card. | MITIGATO: max ~2.8 update/sec, completion sempre pubblicata. |
| `onAppear` + `scenePhase.active` rilanciano check? | Entrambi chiamavano `startSemiAutomaticCheckIfNeeded()`. Gate impediva doppio run, ma partiva immediatamente nel render iniziale. | MITIGATO con delay 700 ms e active task single-flight. |
| Cooldown/debounce reale? | `SupabaseManualSyncSemiAutomaticPolicy`: debounce 2s, cooldown 30m. | PRESENTE. |
| Auto check differito dopo render UI? | Prima no. | FIXATO: 700 ms dopo `onAppear`/active. |

## Fix applicato

- `SupabaseManualSyncViewModel.updateProgress(... throttleUI:)` aggiunto.
- Catalog/ProductPrice/History progress throttled: pubblicazione non piu' a ogni micro-step se il delta e' sotto 0.35 s e sotto 9.000 righe.
- Completion/failure/cancel non throttled: sempre pubblicati.
- `SupabaseProductPriceApplyService.applyPagedFullPull`: `Task.yield()` ogni 150 righe dentro pagina da 900; mantiene cancel rapido e lascia respirare la UI.
- Timing privacy-safe per pagina: `fetchMs`, `applyMs`, `saveMs`; nessun UUID completo/token/email.
- Options auto check: delay iniziale `700_000_000 ns` prima del check foreground.

## Misure disponibili post-fix

- iOS Debug build/run: PASS, warning 0 via XcodeBuildMCP, durata 12.966 s nel rerun.
- iOS Release simulator build: PASS.
- iOS Options signed-out scroll smoke: PASS con gesture `scroll-up`, `scroll-down`, nessun hitch visibile nel breve smoke.
- iOS idle RSS post-build/run: `330,288 KB`, CPU `0.0%`, elapsed `00:25`.
- Android idle launch memory: TOTAL PSS `182,569 KB`, TOTAL RSS `281,960 KB`.

## Limiti

- Nuovo full live iOS app-auth post-patch NON ESEGUITO: dopo rebuild l'app iOS e' signed-out e non ho credenziali/OAuth umano.
- Instruments Time Profiler NON ESEGUITO in questo pass.
- La causa runtime piu' probabile resta combinata: SwiftData apply/save su MainActor + progress invalidation frequente + auto check immediato su Options render.

