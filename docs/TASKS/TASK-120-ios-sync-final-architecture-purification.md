# TASK-120: iOS Sync Final Architecture Purification

## Informazioni generali
- **Task ID**: TASK-120
- **Titolo**: iOS Sync Final Architecture Purification
- **File task**: `docs/TASKS/TASK-120-ios-sync-final-architecture-purification.md`
- **Evidence dir**: `docs/TASKS/EVIDENCE/TASK-120/`
- **Stato**: ACTIVE
- **Fase attuale**: FIX
- **Responsabile attuale**: CODEX / Fixer
- **Data creazione**: 2026-05-24
- **Ultimo aggiornamento**: 2026-05-24
- **Ultimo agente che ha operato**: CODEX / Reviewer
- **Readiness**: CHANGES_REQUIRED da review severa Codex. Non DONE.
- **Tipo task**: planning/refactor governance architetturale iOS; nessuna nuova feature utente.
- **User override registrato**: l'utente ha chiesto esplicitamente a Codex di eseguire TASK-120 fino a `ACTIVE / REVIEW`, poi di eseguire una review severa indipendente e riportare a `CHANGES_REQUIRED / FIX` se necessario. Override operativo rispetto al blocco PLANNING iniziale; nessun DONE, nessun Supabase live, nessun cleanup, nessuna migration/RLS/grant/RPC.

## Obiettivo
Completare in modo rigoroso la purificazione finale dell'architettura sync automatica iOS rimasta dopo TASK-119, prima di qualunque execution:

1. Eliminare o isolare definitivamente codice legacy/stale rimasto.
2. Rendere `Sync/Automatic` il vero owner unico del runtime automatico.
3. Separare fisicamente e semanticamente manual sync sotto `Sync/Manual`.
4. Rendere `SyncAutomaticRuntime` una facade UI/presentation-only.
5. Rafforzare scanner, harness e test in modo che monoliti legacy, duplicazioni e boundary leak non possano passare.
6. Non introdurre nuove feature utente.
7. Non modificare schema Supabase, RLS, grant, RPC o migration.
8. Non dichiarare DONE senza review e accettazione esplicita dei gate live/manual/device eventualmente non eseguiti.

## Grounding repo osservato in planning
- GitHub/local `main` osservato in planning: `b6953a5e1c1ee8c557015949a495cf2f84562292`.
- Questo SHA e' solo snapshot osservato in PLANNING. Future Execution non deve hardcodarlo come verita' permanente.
- `iOSMerchandiseControl/Sync/AutomaticPushServices.swift` nello snapshot osservato e' uno stub di 1 riga / 84 byte, non il monolite da 986 righe citato nell'audit. Resta comunque P0 anti-regression: il monolite non deve tornare e nessun vecchio monolite deve essere compilato o referenziato.
- `Sync/Automatic` esiste parzialmente con domain folders (`Core`, `Catalog`, `ProductPrice`, `History`, `Outbox`, marker `Decision`, `Pull`, `Presentation`).
- `Sync/Manual` non e' ancora un vero boundary fisico se contiene solo `ManualSyncBoundary.swift` mentre `SupabaseManual*`, `*ManualPush*`, DTO/factory/ViewModel manuali restano root-level.
- `SyncAutomaticRuntime.swift` resta `@MainActor` e contiene auth gate, facade state e factory concreta; e' `trim/facade/composition-boundary candidate`.
- `SyncAutomaticRuntimeProviders.swift` resta un mini-monolite multi-dominio di tipi/protocolli automatici; deve essere eliminato o ridotto a transitional stub.
- `SupabaseInventoryService.swift` e `HistorySessionSyncService.swift` restano target di split/contract-boundary; non possono restare "P2 mixed" senza decisione tecnica approvata.
- I nuovi scanner TASK-120 (`duplicate-symbols`, `automatic-legacy-monolith`, `mainactor-boundary`, `swiftdata-context-boundary`, `manual-root-residue`, `source-format`, `harness-routing`, `harness-health`, `master-plan-consistency`, `mcp-wrapper`, `scanner-self-tests`, `status-taxonomy`, `evidence-metadata`, `task-docs`) devono essere creati o instradati prima di essere usati.

## Dynamic SHA rule
`b6953a5e1c1ee8c557015949a495cf2f84562292` e' solo snapshot osservato in Planning. Prima di ogni Execution-Audit devono essere eseguiti:

```bash
./tools/agent/mc-agent.sh git head-consistency --task TASK-120
./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-120
```

Se `HEAD`, `origin/main` e GitHub `main` divergono, TASK-120 diventa `BLOCKED_EXTERNAL_HEAD_MISMATCH` o `MISCONFIGURED_HEAD_MISMATCH` e non puo' procedere a refactor/move/delete Swift.

## Architettura target
```text
iOSMerchandiseControl/Sync/
  Automatic/
    Core/
      AutomaticSyncEngine.swift
      AutomaticSyncRuntimeFacade.swift
      AutomaticSyncSingleFlight.swift
      AutomaticSyncCancellationPolicy.swift
      AutomaticSyncRetryPolicy.swift
    Decision/
      SyncDecisionInputProvider.swift
      SyncDecisionEngine.swift
      SyncTrigger.swift
    Catalog/
      CatalogPushPlanner.swift
      CatalogPushService.swift
      CatalogPushPayloads.swift
      CatalogRemoteWriting.swift
    ProductPrice/
      ProductPricePushPlanner.swift
      ProductPricePushService.swift
      ProductPricePushPayloads.swift
      ProductPriceRemoteWriting.swift
    History/
      HistorySessionAutomaticPushService.swift
      HistorySessionPushPlanner.swift
      HistorySessionRemoteWriting.swift
      HistorySessionAutomaticPayloads.swift
    Outbox/
      AutomaticSyncEventOutboxWriter.swift
      SyncActivityRegistrationService.swift
    Pull/
      CatalogIncrementalApplyService.swift
      ProductPriceIncrementalApplyService.swift
      HistoryIncrementalApplyService.swift
      SyncEventIncrementalPullService.swift
      WatermarkStore.swift
    Presentation/
      SyncStatusPresenter.swift
      OptionsSyncSummaryProvider.swift
      SyncState.swift
      SyncStateStore.swift

  Manual/
    SupabaseManual*
    *ManualPush*
    manual-only DTOs
    manual-only factories
    manual-only view models

  Shared/
    pure value types only
    pure string/date helpers
    no manual result leakage
    no concrete service ownership

  Recovery/
    explicit bootstrap/full recovery only

  Account/
    account binding/switch policy
```

## Audit table file-by-file
| File / area | Classificazione iniziale | Verifiche obbligatorie future | Decisione futura |
| --- | --- | --- | --- |
| `iOSMerchandiseControl/Sync/AutomaticPushServices.swift` | blocker / legacy monolith guard / delete-or-stub candidate | target membership, referenze, duplicati symbol, compile inclusion, scanner `automatic-legacy-monolith` | Eliminato o stub zero-behavior. Non puo' contenere classi concrete domain. |
| `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift` | keep / owner automatic core | unico owner single-flight/cancel/retry; no `@MainActor`; tests begin/busy/cancel/finish/retry | Resta core automatico non-UI. |
| `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncSingleFlight.swift` | keep | tests begin/busy/cancel/finish/reentrancy | Resta helper actor testato. |
| `iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift` | trim / facade only | no ownership reale single-flight; `@MainActor` solo presentation/auth/state; factory concreta spostata | Resta facade UI sottile o rinominata `AutomaticSyncRuntimeFacade`. |
| `iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift` | split / mini-monolith | source-format, domain ownership, duplicate-symbols | Eliminato o ridotto a transitional stub; tipi/protocolli nei domini corretti. |
| `iOSMerchandiseControl/Sync/SyncOrchestrator.swift` | trim/split | UI scheduler/presentation controller; no automatic engine ownership | Resta scheduler UI, non owner runtime automatico. |
| `iOSMerchandiseControl/Sync/SyncDecisionEngine.swift`, `SyncDecisionInputProvider.swift`, `SyncTrigger.swift` | move | scanner root domain residue; build membership | Spostare in `Sync/Automatic/Decision/`. |
| `iOSMerchandiseControl/Sync/Incremental/*` | move/audit | automatic pull semantics, no manual leakage, ModelContainer/fresh context | Spostare in `Sync/Automatic/Pull/` se parte del pull automatico. |
| `iOSMerchandiseControl/Sync/Presentation/*` | move | presentation-only, `@MainActor` ammesso solo qui | Spostare in `Sync/Automatic/Presentation/`. |
| `SupabaseManual*`, `*ManualPush*`, `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncReleaseFactory.swift` | move/manual boundary | scanner `manual-root-residue`, owner/test per eccezioni | Spostare sotto `Sync/Manual/` o eccezione approvata. |
| `SupabaseInventoryService.swift` | split/contract-boundary | protocol boundary automatic/manual, schema read-only contract, no concrete automatic dependency | Ridurre/splittare o trasformare in implementation di protocolli chiari. |
| `HistorySessionSyncService.swift` | split/shared-contract | separare automatic/manual/incremental/UI oppure pure payload mapper | Non resta mixed senza decisione approvata. |
| `OptionsView.swift` | observer-only verification | nessuna orchestrazione sync, nessun trigger manuale pubblico | Solo stato reale/presenter. |
| `ContentView.swift`, `iOSMerchandiseControlApp.swift` | root wiring only | composizione dipendenze, no business logic sync | Solo wiring root/app. |

## Planning hardening addendum - source readability, harness routing, manual boundary, status taxonomy
### Source-format thresholds
TASK-120 deve creare o migliorare:

```bash
./tools/agent/mc-agent.sh scan source-format --task TASK-120 --strict
```

Lo scanner fallisce se:
- un file `.swift`, `.sh`, `.py` non generated/minified ha una singola riga oltre 1000 caratteri;
- piu' del 5% delle righe di un file supera 300 caratteri;
- piu' dichiarazioni Swift top-level (`class`, `struct`, `actor`, `enum`, `protocol`, `func`) sono compresse sulla stessa riga;
- uno script `.sh` core/harness con shebang/funzioni e' one-line/minified;
- file core/harness sono minificati senza eccezione.

Eccezioni ammesse solo per generated/minified assets documentati con path e motivo. Il report deve indicare file, linea, motivo e fix hint.

### Harness routing / discovery
TASK-120 deve verificare:

```bash
./tools/agent/mc-agent.sh help-json
./tools/agent/mc-agent.sh list commands-json
```

Ogni comando citato nella Test Matrix deve comparire in uno dei due output. Se non esiste, deve essere creato prima dell'uso.

### Manual boundary
`Sync/Manual/ManualSyncBoundary.swift` da solo non conta come isolamento manuale. TASK-120 non puo' andare a REVIEW se file manuali reali restano root-level senza eccezione approvata, owner e test.

### Providers / composition root
- `SyncAutomaticRuntimeProviders.swift` deve essere eliminato o ridotto a transitional stub senza mini-monolite.
- Tipi Catalog vanno in `Automatic/Catalog`.
- Tipi ProductPrice vanno in `Automatic/ProductPrice`.
- Tipi History vanno in `Automatic/History`.
- Incremental summary/protocols vanno in `Automatic/Pull`.
- Automatic run result/status vanno in `Automatic/Core`.
- Trigger/decision types vanno in `Automatic/Decision` o `Automatic/Core`.
- La factory concreta che crea servizi automatici va spostata in composition root/factory dedicato, non lasciata in un runtime che possiede anche stato di esecuzione.

## Execution ordering gate - harness-first, scanner-tested, then Swift cleanup
Sequenza obbligatoria:

1. Documentation sync only.
2. HEAD/preflight/config.
3. Harness-routing/discovery.
4. Harness-health.
5. Scanner implementation/routing.
6. Scanner self-tests con fixture RED/GREEN.
7. Source-format cleanup.
8. Architecture audit.
9. Solo dopo: Swift moves/splits/deletions.
10. Build/test/smoke.
11. Review handoff.

Regola blocker: nessun refactor Swift, move/delete o split semantico puo' iniziare finche' `harness-routing`, `harness-health`, `source-format` e scanner self-tests non sono PASS o non hanno BLOCKED_EXTERNAL/MISCONFIGURED accettati esplicitamente in planning review.

## Scanner self-test and negative fixtures
Path canonico fixture:

```text
tools/agent/fixtures/task120_scanners/
```

Sotto quel path devono essere pianificate e create fixture:
- `automatic_legacy_monolith/`
- `manual_root_residue/`
- `duplicate_symbols/`
- `mainactor_boundary/`
- `swiftdata_context_boundary/`
- `source_format/`
- `master_plan_consistency/`
- `harness_routing/`
- `status_taxonomy/`
- `evidence_metadata/`
- `mcp_wrapper/`

Ogni fixture deve avere almeno un caso RED e uno GREEN, con expected status/exit code documentato, report `.md/.json/.log`, `NEXT_ACTION` ed exit code corretto.

Fixture RED obbligatorie:
- `automatic-legacy-monolith`: RED se `AutomaticPushServices.swift` contiene `CatalogPushService`, `ProductPricePushService`, `HistorySessionPushService`, `SyncActivityRegistrationService`.
- `manual-root-residue`: RED se `SupabaseManual*`, `*ManualPush*`, manual DTO/factory/adapter/ViewModel restano root-level senza eccezione.
- `duplicate-symbols`: RED se due classi/protocolli Swift hanno lo stesso nome in file diversi.
- `mainactor-boundary`: RED se `@MainActor` appare in `Sync/Automatic/Core` o domain service non presentation.
- `swiftdata-context-boundary`: RED se UI `ModelContext` viene passato a path automatico/background.
- `source-format`: RED se file `.swift`, `.sh`, `.py` core/harness sono one-line/minified o hanno linee oltre soglia documentata.
- `master-plan-consistency`: RED se MASTER-PLAN dichiara TASK-119/TASK-120 in stati correnti conflittuali.
- `harness-routing`: RED se un comando citato nella test matrix non appare in `help-json` o `list commands-json`.
- `status-taxonomy`: RED se JSON usa alias umani come status canonici.
- `evidence-metadata`: RED se report manca task id, SHA, dirty state, status canonico, exit code, evidence path, timestamp, redaction summary, `NEXT_ACTION`, `.md/.json/.log` o schema `1.1`.
- `mcp-wrapper`: RED se wrapper usa shell string arbitraria, cwd non fisso, logic duplicata o muta `MC_ALLOW_LIVE` / `MC_ALLOW_CLEANUP`.

## MCP wrapper hardening
TASK-120 deve verificare o migliorare il wrapper MCP:
- thin allowlisted adapter sopra `mc-agent.sh`;
- cwd fisso;
- argv-based;
- timeout-bound;
- no arbitrary shell string;
- no duplicated scanner logic;
- no mutation di `MC_ALLOW_LIVE` o `MC_ALLOW_CLEANUP`;
- nuovi comandi TASK-120 discoverable/allowlisted solo se sicuri;
- se un comando non e' allowlisted, usare `mc-agent.sh` canonico e non shell manuali ricostruite.

Comando futuro:

```bash
./tools/agent/mc-agent.sh scan mcp-wrapper --task TASK-120 --strict
```

## Status taxonomy compatibility
Canonical JSON statuses:
- `PASS`
- `FAIL`
- `BLOCKED_EXTERNAL`
- `NOT_RUN`
- `PASS_WITH_NOTES`
- `MISCONFIGURED`
- `UNSAFE_OPERATION_REFUSED`

Alias ammessi solo in testo umano:
- `BLOCKED` = `BLOCKED_EXTERNAL`
- `REFUSED` = `UNSAFE_OPERATION_REFUSED`

Regole:
- `NOT_RUN` non conta mai come PASS.
- `PASS_WITH_NOTES` non chiude blocker-class gate senza accettazione esplicita.
- `MISCONFIGURED` blocca REVIEW.
- `UNSAFE_OPERATION_REFUSED` blocca REVIEW salvo sia risultato atteso di un safety-refusal test.
- DONE richiede Review approval, tutti i non-external gates PASS, e accettazione esplicita per eventuali residual live/manual/device blockers.

## Evidence metadata completeness
Ogni futuro report TASK-120 sotto `docs/TASKS/EVIDENCE/TASK-120/agent-runs/` deve includere:
- task id `TASK-120`;
- git SHA;
- dirty state;
- command slug;
- status canonico;
- exit code;
- safety level;
- evidence path;
- started/finished timestamp;
- redaction summary;
- `NEXT_ACTION`;
- `.md`, `.json`, `.log`;
- JSON schema `1.1`.

Evidence fuori da `docs/TASKS/EVIDENCE/TASK-120/agent-runs/` e' `MISCONFIGURED`.

## Supabase read-only contract gate
Comando futuro:

```bash
./tools/agent/mc-agent.sh supabase contract sync-schema --task TASK-120 --read-only
```

Se non esiste, TASK-120 deve pianificarne la creazione prima di usarlo. Scope:
- read-only;
- no migration;
- no RLS/grant/RPC changes;
- no live data writes;
- verifica solo che remote protocols/service methods usati da Automatic/Manual corrispondano a schema/tabelle/colonne esistenti;
- output redatto.

## Task docs existence gate
Comando futuro:

```bash
./tools/agent/mc-agent.sh scan task-docs --task TASK-120 --strict
```

Se il comando non esiste, TASK-120 deve pianificarne la creazione prima dell'uso.

Lo scanner deve verificare:
- esiste `docs/TASKS/TASK-120-ios-sync-final-architecture-purification.md`;
- esiste `docs/TASKS/EVIDENCE/TASK-120/README.md`;
- `docs/MASTER-PLAN.md` ha TASK-120 come current objective;
- TASK-119 resta `REVIEW_PASS_WITH_NOTES`, not DONE;
- TASK-120 non e' `READY_FOR_EXECUTION` e non e' `DONE`;
- CA-120-01...CA-120-68 sono tutti presenti;
- test matrix contiene tutti i comandi pianificati;
- evidence root e' `docs/TASKS/EVIDENCE/TASK-120/agent-runs/`;
- report fuori path sono `MISCONFIGURED`.

## Deletion protocol
Nessun file viene eliminato in futura execution senza:
- `rg` reference scan;
- Xcode target membership scan;
- duplicate-symbol scan;
- Debug/Release build PASS;
- targeted tests PASS;
- rollback note;
- evidence sotto `docs/TASKS/EVIDENCE/TASK-120/agent-runs/`.

## Scanner / harness requirements
TASK-120 deve creare o rafforzare scanner che falliscono se:
- `AutomaticPushServices.swift` contiene classi concrete come `CatalogPushService`, `ProductPricePushService`, `HistorySessionPushService`, `SyncActivityRegistrationService`;
- esistono duplicati di nomi classe/protocollo tra vecchi file e nuovi domain files;
- automatic runtime/core importa o referenzia `SupabaseManual*`, `ManualPush*`, manual DTO/result/factory/adapter;
- automatic history usa concretamente `SupabaseInventoryService` invece di `HistorySessionRemoteWriting`;
- `@MainActor` compare in `Sync/Automatic/Core` o nei servizi domain non presentation;
- UI `ModelContext` viene passato al path automatico invece di `ModelContainer` + fresh context;
- manual files restano in root senza `Sync/Manual` o eccezione approvata;
- `SupabaseInventoryService` viene usato come concrete dependency nei domain automatici;
- root `Sync/` contiene file domain destinati ad `Automatic/Decision`, `Automatic/Pull`, `Automatic/Presentation`;
- Xcode membership contiene file stale, eccezioni obsolete o build scripts puntati a file rimossi;
- scanner TASK-120 e' nascosto in file TASK-117/TASK-118/TASK-119 invece di avere ownership esplicita;
- Options smoke fallback viene classificato come PASS primario senza accettazione esplicita.

## Test matrix futura
Planning-only: questi comandi non sono eseguiti in creazione/integration del planning.

```bash
./tools/agent/mc-agent.sh git head-consistency --task TASK-120
./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-120
./tools/agent/mc-agent.sh config validate --task TASK-120

./tools/agent/mc-agent.sh help-json
./tools/agent/mc-agent.sh list commands-json

./tools/agent/mc-agent.sh scan task-docs --task TASK-120 --strict
./tools/agent/mc-agent.sh scan harness-routing --task TASK-120 --strict
./tools/agent/mc-agent.sh scan harness-health --task TASK-120 --strict
./tools/agent/mc-agent.sh scan source-format --task TASK-120 --strict
./tools/agent/mc-agent.sh scan duplicate-symbols --task TASK-120 --strict
./tools/agent/mc-agent.sh scan automatic-legacy-monolith --task TASK-120 --strict
./tools/agent/mc-agent.sh scan mainactor-boundary --task TASK-120 --strict
./tools/agent/mc-agent.sh scan swiftdata-context-boundary --task TASK-120 --strict
./tools/agent/mc-agent.sh scan manual-root-residue --task TASK-120 --strict
./tools/agent/mc-agent.sh scan master-plan-consistency --task TASK-120 --strict
./tools/agent/mc-agent.sh scan mcp-wrapper --task TASK-120 --strict
./tools/agent/mc-agent.sh scan scanner-self-tests --task TASK-120 --strict
./tools/agent/mc-agent.sh scan status-taxonomy --task TASK-120 --strict
./tools/agent/mc-agent.sh scan evidence-metadata --task TASK-120 --strict

./tools/agent/mc-agent.sh scan sync-architecture --task TASK-120 --strict
./tools/agent/mc-agent.sh scan manual-boundary --task TASK-120 --strict
./tools/agent/mc-agent.sh scan dead-code --task TASK-120 --strict
./tools/agent/mc-agent.sh scan xcode-membership --task TASK-120 --strict

./tools/agent/mc-agent.sh ios build debug --task TASK-120
./tools/agent/mc-agent.sh ios build release --task TASK-120
./tools/agent/mc-agent.sh ios test automatic-architecture --task TASK-120
./tools/agent/mc-agent.sh ios test automatic-domain --task TASK-120
./tools/agent/mc-agent.sh ios test sync --task TASK-120
./tools/agent/mc-agent.sh ios smoke options --task TASK-120

./tools/agent/mc-agent.sh supabase status-redacted --task TASK-120
./tools/agent/mc-agent.sh supabase contract sync-schema --task TASK-120 --read-only
./tools/agent/mc-agent.sh scan sensitive --task TASK-120
./tools/agent/mc-agent.sh scan evidence --task TASK-120
./tools/agent/mc-agent.sh report validate-json --task TASK-120 --path docs/TASKS/EVIDENCE/TASK-120/agent-runs
git diff --check
```

Live opzionale solo con autorizzazione esplicita:

```bash
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live reconcile-counts --task TASK-120 --prefix TASK120_RECON_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live sync-matrix --task TASK-120 --prefix TASK120_FINAL_
```

Se futuri test live creano righe sintetiche:
- prefissi ammessi: `TASK120_RECON_`, `TASK120_FINAL_`, `TASK120_LIVE_`, `TASK120_CLEANUP_`;
- collision scan prima di write;
- cleanup dry-run;
- cleanup execute solo con `MC_ALLOW_CLEANUP=1`;
- residue check finale;
- nessun cleanup globale;
- nessun `service_role` nel client;
- evidence redatta.

## Acceptance criteria CA-120-01...CA-120-68
- **CA-120-01**: `AutomaticPushServices.swift` non contiene piu' classi concrete domain oppure e' eliminato; nessun vecchio monolite compilato o referenziato.
- **CA-120-02**: nessun duplicato di classi/protocolli tra vecchi file e nuovi domain files.
- **CA-120-03**: `AutomaticSyncEngine` e' l'unico owner di single-flight/cancel/retry.
- **CA-120-04**: `SyncAutomaticRuntime` e' una facade `@MainActor` solo presentation/auth/state boundary.
- **CA-120-05**: automatic core/domain non usa `@MainActor`, salvo eccezioni documentate e approvate.
- **CA-120-06**: automatic SwiftData usa solo `ModelContainer` + fresh `ModelContext`.
- **CA-120-07**: manual sync e' fisicamente isolato sotto `Sync/Manual` o ogni eccezione e' documentata con owner e test.
- **CA-120-08**: automatic path non referenzia `SupabaseManual*`, `ManualPush*`, manual DTO/result/factory/adapter.
- **CA-120-09**: automatic domain remote writing usa protocolli (`CatalogRemoteWriting`, `ProductPriceRemoteWriting`, `HistorySessionRemoteWriting`) e non concrete `SupabaseInventoryService`.
- **CA-120-10**: `SupabaseInventoryService` viene ridotto/splittato o trasformato in implementation di protocolli con boundary chiari.
- **CA-120-11**: `HistorySessionSyncService` viene splittato oppure ridotto a pure shared helper senza leakage manual/automatic.
- **CA-120-12**: decision/pull/presentation automatic sono spostati nelle cartelle target.
- **CA-120-13**: Options/root sono observer/wiring only.
- **CA-120-14**: no full pull/bootstrap normal path fuori recovery/account context.
- **CA-120-15**: scanner TASK-120 fallisce su vecchio monolite, duplicati e boundary leak.
- **CA-120-16**: Xcode membership audit PASS dopo move/delete.
- **CA-120-17**: Debug/Release build PASS in execution futura.
- **CA-120-18**: automatic-architecture tests PASS in execution futura.
- **CA-120-19**: automatic-domain tests PASS in execution futura.
- **CA-120-20**: broad sync tests PASS in execution futura.
- **CA-120-21**: manual regression coverage esiste se manual sync resta supportato.
- **CA-120-22**: Options smoke primario PASS oppure BLOCKED_EXTERNAL con fallback e accettazione esplicita.
- **CA-120-23**: live/manual/device NOT_RUN non possono contare come PASS.
- **CA-120-24**: before/after architecture map prova net simplification reale.
- **CA-120-25**: deletion candidate table include reference scan, target membership, test plan e rollback note.
- **CA-120-26**: nessuna migration/schema/RLS/grant/RPC Supabase in TASK-120.
- **CA-120-27**: evidence redaction/sensitive scan PASS.
- **CA-120-28**: JSON report validation PASS.
- **CA-120-29**: `git diff --check` PASS.
- **CA-120-30**: DONE richiede review approval + accettazione utente dei blocker esterni residui.
- **CA-120-31**: TASK-120 scanners hanno ownership esplicita e non dipendono da semantiche TASK-117/TASK-118/TASK-119.
- **CA-120-32**: duplicate-symbol scanner fallisce su duplicati class/protocol tra stale file e domain file.
- **CA-120-33**: automatic-legacy-monolith scanner fallisce se `AutomaticPushServices.swift` contiene servizi domain concreti o e' compilato come monolite legacy.
- **CA-120-34**: mainactor-boundary scanner fallisce su `@MainActor` in automatic core/domain fuori presentation-only approvato.
- **CA-120-35**: swiftdata-context-boundary scanner fallisce quando UI `ModelContext` entra nei path automatic/background.
- **CA-120-36**: Xcode membership scan copre synchronized groups, explicit refs, build scripts e stale exceptions.
- **CA-120-37**: manual sync retained ha regression coverage dopo move fisico in `Sync/Manual`.
- **CA-120-38**: runtime facade/factory ownership e' ridotta o spostata cosi' `SyncAutomaticRuntime` non puo' essere secondo automatic owner.
- **CA-120-39**: nessuna nuova feature user-visible, workflow, copy, schema o live-data behavior e' introdotta.
- **CA-120-40**: handoff puo' essere solo `ACTIVE / REVIEW`; DONE richiede review approval + user acceptance dei live/manual/device blocker.
- **CA-120-41**: Source formatting/readability scan PASS; nessun file Swift/Shell/Python core o harness resta minificato/one-line oltre soglie documentate.
- **CA-120-42**: Harness command discovery PASS; ogni comando Test Matrix compare in `help-json` o `list commands-json`, oppure e' creato prima dell'uso.
- **CA-120-43**: Harness routing PASS; `duplicate-symbols`, `automatic-legacy-monolith`, `mainactor-boundary`, `swiftdata-context-boundary`, `source-format`, `harness-health` sono instradati da `mc-agent.sh` con exit code affidabili.
- **CA-120-44**: Harness health PASS; shell scripts passano `bash -n`, Python scanner passano `python3 -m py_compile`, report JSON resta schema `1.1` valido e redatto.
- **CA-120-45**: Manual root residue FAIL se `SupabaseManual*`, `*ManualPush*`, manual DTO/factory/ViewModel restano root app senza eccezione approvata, owner e test.
- **CA-120-46**: Provider monolith reduction PASS; `SyncAutomaticRuntimeProviders.swift` eliminato o ridotto a transitional stub, con tipi/protocolli nei domini Automatic corretti.
- **CA-120-47**: Composition ownership PASS; creazione concreta servizi automatici in composition root/factory dedicato, non runtime con stato esecuzione.
- **CA-120-48**: MASTER-PLAN consistency PASS; nessuna sezione corrente dichiara TASK-119/TASK-120 in stati conflittuali.
- **CA-120-49**: Evidence path enforcement PASS; ogni report TASK-120 vive sotto `docs/TASKS/EVIDENCE/TASK-120/agent-runs/`.
- **CA-120-50**: Status taxonomy PASS; stati canonici e alias umani sono definiti e mappati agli exit code harness.
- **CA-120-51**: Cleanup/live safety PASS; se live crea righe sintetiche, collision scan, cleanup dry-run, execute gated, residue check e prefissi `TASK120_*` sono obbligatori.
- **CA-120-52**: No app UI polish in TASK-120; ammesse solo UX CLI/report/README/next-action per operatori e agenti.
- **CA-120-53**: Execution ordering gate PASS; nessun Swift refactor prima di harness/scanner/source-format readiness.
- **CA-120-54**: Scanner self-tests PASS con fixture RED/GREEN per ogni nuovo scanner TASK-120.
- **CA-120-55**: MCP wrapper hardening PASS.
- **CA-120-56**: Status taxonomy compatibility PASS con `BLOCKED_EXTERNAL`/`UNSAFE_OPERATION_REFUSED` canonici e alias umani documentati.
- **CA-120-57**: Dynamic SHA rule PASS; `b6953a5` non viene hardcodato come verita' futura.
- **CA-120-58**: Evidence metadata completeness PASS.
- **CA-120-59**: Supabase read-only contract gate PASS o comando creato e poi PASS.
- **CA-120-60**: Source-format cleanup precede architecture moves.
- **CA-120-61**: Scanner ownership PASS; TASK-120 logic non viene nascosta in `task117_scans.py` o `task119_scans.py` senza rinomina/shared module esplicito.
- **CA-120-62**: MCP and CLI command lists are consistent; no command exists solo in docs.
- **CA-120-63**: Safety-refusal tests distinguish expected `UNSAFE_OPERATION_REFUSED` from unexpected FAIL.
- **CA-120-64**: Final handoff after user scope override remains `ACTIVE / REVIEW`; task is not DONE.
- **CA-120-65**: Full CA materialization PASS; CA-120-01...CA-120-64 sono tutti esplicitamente presenti nel file TASK-120 finale.
- **CA-120-66**: Source-format thresholds PASS; soglie e eccezioni sono documentate e verificabili.
- **CA-120-67**: Scanner fixture path PASS; fixture RED/GREEN vivono sotto `tools/agent/fixtures/task120_scanners/`.
- **CA-120-68**: Task docs existence gate PASS; `scan task-docs --task TASK-120 --strict` esiste o viene creato prima dell'uso e valida task/evidence/master consistency.

## Done policy
TASK-120 non puo' essere DONE se:
- `AutomaticPushServices.swift` resta con codice domain concreto;
- ci sono duplicati class/protocol tra vecchio e nuovo path;
- manual sync resta root/misto senza boundary documentato;
- `SyncAutomaticRuntime` resta secondo owner del runtime automatico;
- `SupabaseInventoryService` e `HistorySessionSyncService` restano mixed senza decisione esplicita approvata;
- scanner passano pur lasciando vecchio codice legacy;
- live/manual/device NOT_RUN vengono trattati come PASS;
- non esiste before/after architecture map;
- source-format/readability e harness routing/health non sono passati o accettati esplicitamente in planning review.

## Handoff planning finale storico
`TASK-120 ACTIVE / PLANNING — HARDENED_PLUS_FINAL, REVIEW PLANNING REQUIRED BEFORE EXECUTION-AUDIT`.

## Execution - Codex
> Nota review 2026-05-24: questa sezione registra l'handoff execution storico. La review severa Codex sotto la supera dove contraddice il verdict finale `CHANGES_REQUIRED`.

### Scope eseguito
Codex ha seguito l'ordine harness-first richiesto dall'utente, limitando l'harness agli scanner TASK-120 necessari a bloccare regressioni e passando al refactor Swift appena i gate minimi sono risultati PASS. Nessun refactor Swift e' stato avviato prima di `harness-routing`, `harness-health`, `source-format` e `scanner-self-tests` PASS.

### Harness/scanner creati o migliorati
- Creato `tools/agent/lib/task120_scans.py` con scanner TASK-120 scoped: task docs, harness routing/health, source format, duplicate symbols, automatic legacy monolith, MainActor boundary, SwiftData context boundary, manual root residue, master plan consistency, MCP wrapper, scanner self-tests, status taxonomy, evidence metadata, sync architecture, manual boundary, dead code, Xcode membership e Supabase contract statico read-only.
- Instradati i comandi TASK-120 in `tools/agent/mc-agent.sh`, `tools/agent/lib/common.sh`, `tools/agent/lib/report.sh`, `tools/agent/lib/supabase.sh` e nel wrapper MCP `tools/agent/mcp/server.mjs`.
- Create fixture RED/GREEN sotto `tools/agent/fixtures/task120_scanners/` con README e self-test scanner PASS.
- Rafforzata la tassonomia report JSON schema `1.1` con status canonici, redaction summary e `NEXT_ACTION`.

### Refactor Swift reale eseguito
- `SyncAutomaticRuntime` e' rimasto facade sottile UI/auth/state; la creazione concreta dei provider automatici e' stata spostata in `Sync/Automatic/Composition/AutomaticSyncRuntimeFactory.swift`.
- `SyncAutomaticRuntimeProviders.swift` e' stato ridotto a transitional marker stub; tipi/protocolli automatici sono stati divisi in `Automatic/Core`, `Decision`, `Catalog`, `ProductPrice`, `History`, `Outbox`, `Pull`.
- I file decision, pull e presentation automatici sono stati spostati sotto `Sync/Automatic/*`.
- I file `SupabaseManual*`, `*ManualPush*`, factory, DTO, adapter e ViewModel manuali sono stati spostati sotto `Sync/Manual/`.
- `HistorySessionSyncService` e' stato spostato sotto `Sync/Manual/` e ridotto a servizio manuale; payload/codec/protocolli shared pure sono stati estratti in `Sync/Shared/HistorySessionSyncShared.swift`.
- I path automatici History/Pull usano `HistorySessionRemoteWriting` e protocolli remoti automatici; non istanziano `HistorySessionSyncService` e non dipendono dal concrete `SupabaseInventoryService`.
- `SupabaseInventoryService` resta implementazione concreta condivisa al root, ma i domini automatici dipendono da protocolli chiari (`CatalogRemoteWriting`, `ProductPriceRemoteWriting`, `HistorySessionRemoteWriting`, `SyncAutomaticIncrementalRemote`) invece che dal servizio concreto.
- Test statici legacy sono stati aggiornati ai nuovi path architetturali senza reintrodurre stub root per i file spostati.

### File spostati/splittati/eliminati
- Spostati in `Sync/Automatic/Decision`: `SyncDecisionEngine.swift`, `SyncDecisionInputProvider.swift`, `SyncTrigger.swift`.
- Spostati in `Sync/Automatic/Presentation`: `SyncState.swift`, `SyncStateStore.swift`, `OptionsSyncSummaryProvider.swift`, `SyncStatusPresenter.swift`.
- Spostati in `Sync/Automatic/Pull`: `CatalogIncrementalApplyService.swift`, `ProductPriceIncrementalApplyService.swift`, `HistoryIncrementalApplyService.swift`, `SyncEventIncrementalDomainApplyService.swift`, `SyncEventIncrementalPullService.swift`, summaries/helpers/watermark.
- Spostati in `Sync/Manual`: `HistorySessionSyncService.swift`, `SupabaseSyncEventIncrementalApplyService.swift`, tutti i `SupabaseManual*`, `*ManualPush*`, factory/DTO/ViewModel/adapter manuali.
- Splittati da provider/runtime monolith: run result/status, trigger source, catalog/product price/history/outbox/pull models e contracts.
- Estratto shared pure history in `Sync/Shared/HistorySessionSyncShared.swift`.
- Rimossi i vecchi directory root `Sync/Incremental/` e `Sync/Presentation/`; `SyncAutomaticRuntimeProviders.swift` resta solo transitional marker stub.

### Before/after architecture map
Before:
- Root `Sync/` conteneva decision/presentation/pull automatici e `SyncAutomaticRuntimeProviders.swift` multi-dominio.
- Root app conteneva manual implementation (`SupabaseManual*`, `*ManualPush*`, DTO/factory/ViewModel).
- `SyncAutomaticRuntime` conteneva anche factory concreta dei servizi automatici.
- History automatico condivideva il concrete `HistorySessionSyncService`; pull automatico poteva vedere concrete `SupabaseInventoryService`.

After:
- Automatic runtime owner: `Sync/Automatic/Core/AutomaticSyncEngine.swift` possiede single-flight/cancel/retry; `SyncAutomaticRuntime.swift` e' facade UI/auth/state.
- Composition root: `Sync/Automatic/Composition/AutomaticSyncRuntimeFactory.swift` crea i provider concreti automatici da `ModelContainer`.
- Manual boundary: `Sync/Manual/` contiene i file manuali reali; root manual residue scanner PASS.
- Automatic-only: `Automatic/Catalog`, `ProductPrice`, `History`, `Outbox`, `Pull`, `Decision`, `Core`.
- Manual-only: `Sync/Manual/SupabaseManual*`, `Sync/Manual/*ManualPush*`, manual release factory/ViewModel/coordinator/adapter.
- Shared-pure: `Sync/Shared/HistorySessionSyncShared.swift`, `Sync/Shared/SyncStringCollectionHelpers.swift`, marker shared boundary; niente owner automatic/manual concreto.
- `SupabaseInventoryService` e' concrete implementation di protocolli remoti, non dipendenza concrete nei domain automatici.
- `HistorySessionSyncService` e' manual service; automatic history/pull usano shared payload/codec/protocolli e `HistorySessionRemoteWriting`.

Claim execution storico superato dalla review severa: i path automatici risultano molto meno ibridi e non usano il servizio manuale concreto, ma l'architettura non puo' essere certificata come pienamente non ibrida finche' CA-120-03 retry ownership resta FAIL.

### Prove eseguite
- PASS: HEAD/preflight/config, `help-json`, `list commands-json`, task-docs, harness-routing, harness-health, scanner-self-tests, source-format, architecture scans.
- PASS: `ios build debug`, `ios build release`, `ios test automatic-architecture`, `ios test automatic-domain`, `ios test sync`, `ios smoke options`.
- PASS: `supabase status-redacted`, `supabase contract sync-schema --read-only`.
- PASS: task-docs, master-plan consistency, evidence metadata, sensitive scan, evidence scan, report JSON validation e `git diff --check`.

### Evidence path
Evidence canonica: `docs/TASKS/EVIDENCE/TASK-120/agent-runs/`.
Run chiave:
- `20260524T043758Z-git-head-consistency-task-TASK-120-p85021`
- `20260524T043804Z-preflight-require-head-consistency-task-TASK-120-p85898`
- `20260524T045053Z-scan-harness-routing-task-TASK-120-strict-p94575`
- `20260524T045056Z-scan-harness-health-task-TASK-120-strict-p95066`
- `20260524T051025Z-scan-scanner-self-tests-task-TASK-120-strict-p19389`
- `20260524T051014Z-scan-sync-architecture-task-TASK-120-strict-p17721`
- `20260524T051014Z-scan-manual-boundary-task-TASK-120-strict-p17724`
- `20260524T051052Z-ios-build-debug-task-TASK-120-p21665`
- `20260524T051103Z-ios-build-release-task-TASK-120-p22263`
- `20260524T051031Z-ios-test-automatic-architecture-task-TASK-120-p20988`
- `20260524T051216Z-ios-test-automatic-domain-task-TASK-120-p23042`
- `20260524T051648Z-ios-test-sync-task-TASK-120-p25562`
- `20260524T051929Z-ios-smoke-options-task-TASK-120-p49536`
- `20260524T051951Z-supabase-contract-sync-schema-task-TASK-120-read-only-p50126`
- `20260524T052210Z-scan-task-docs-task-TASK-120-strict-p51838`
- `20260524T052210Z-scan-master-plan-consistency-task-TASK-120-strict-p51860`
- `20260524T052220Z-scan-sensitive-task-TASK-120-p53086`
- `20260524T052220Z-scan-evidence-task-TASK-120-p53087`
- `20260524T052228Z-report-validate-json-task-TASK-120-path-docs-TASKS-EVIDENCE-TASK-120-agent-runs-p57574`

### Rischi residui
- `SupabaseInventoryService.swift` resta fisicamente root e ampio; la decisione TASK-120 applicata e' trasformarlo in implementation di protocolli remoti chiari, non split completo del file.
- Live cross-device/account matrix non eseguita per divieto esplicito di live Supabase e assenza di autorizzazione `MC_ALLOW_LIVE=1`.
- Il tracking MASTER contiene cronologia storica con task precedenti ACTIVE/not DONE; TASK-120 e' comunque l'obiettivo corrente aggiornato a FIX / CHANGES_REQUIRED.

### Blocker esterni
- Blocker locale residuo per nuovo REVIEW: CA-120-03 retry ownership fuori engine, con `scan sync-architecture` FAIL dopo hardening.
- Blocker esterni per DONE eventuale: review Claude, accettazione utente, e qualsiasi live/device/manual acceptance che il reviewer richieda. Non eseguiti per scope/divieti utente.

## Handoff post-execution
`TASK-120 ACTIVE / REVIEW` storico, superato dalla review severa Codex.

Handoff a Claude / Reviewer: verificare il refactor Swift reale e la mappa before/after. Il task non e' DONE. Non sono stati eseguiti live Supabase, cleanup, migration/RLS/grant/RPC o push GitHub.

## Review severa Codex - 2026-05-24
### Verdict
`CHANGES_REQUIRED`. La review non conferma TASK-120 come REVIEW_PASS: build/test/smoke locali sono solidi, ma la purificazione architetturale non e' completa sui retry automatici e lo scanner precedente era troppo permissivo. TASK-120 non e' DONE e non e' production-ready.

### Problemi trovati
1. **CA-120-03 FAIL - retry ownership non purificata**: `AutomaticSyncEngine` possiede `AutomaticSyncSingleFlight` e `AutomaticSyncCancellationPolicy`, ma non esiste `AutomaticSyncRetryPolicy.swift` e l'engine non referenzia una policy retry dedicata. Inoltre `SyncOrchestrator.swift` contiene ancora scheduling post-busy con `retry_after_sync_busy` e `Task.sleep(nanoseconds: 2_000_000_000)` alle linee 268-269. Questo rende falsa la claim "engine unico owner di single-flight/cancel/retry".
2. **Scanner precedente troppo permissivo**: `scan sync-architecture` verificava solo single-flight/cancel, non retry; quindi un PASS precedente non provava CA-120-03. Fixato lo scanner e aggiunte fixture RED/GREEN.
3. **CA-120-58 FAIL dopo hardening**: `scan evidence-metadata` ora richiede `NEXT_ACTION` e `redaction_summary`; tre report iniziali storici (`20260524T043758Z-config-validate...`, `20260524T043758Z-git-head-consistency...`, `20260524T043804Z-preflight...`) risultano mancanti. I report correnti generati dal wrapper hanno invece i campi.
4. **Rischio CA-120-11 / Shared non completamente pure**: `Sync/Shared/HistorySessionSyncShared.swift` contiene helper shared che accettano `HistoryEntry` e chiamano `ensureHistorySessionRemoteID()` (`upsertRow` linee 94-99, `fingerprintHash(for entry:)` linea 124). Non e' una dipendenza dal manual service, ma non e' "pure value types only" in senso stretto.

### Fix diretti applicati
- Corretto warning Swift release localizzato: `HistoryIncrementalApplyRowsResult` marcato `private nonisolated` in `iOSMerchandiseControl/Sync/Automatic/Pull/HistoryIncrementalApplyService.swift`.
- Rafforzato `tools/agent/lib/task120_scans.py`:
  - `evidence-metadata` richiede `NEXT_ACTION` e `redaction_summary`;
  - `sync-architecture` verifica retry policy dedicata, ownership engine single-flight/cancel/retry e assenza di retry post-busy nell'orchestrator.
- Aggiunte fixture RED/GREEN per `sync-architecture` sotto `tools/agent/fixtures/task120_scanners/sync_architecture/`.
- Aggiornata fixture GREEN `evidence_metadata` con `NEXT_ACTION` e `redaction_summary`.

### Check rieseguiti e evidence
- ✅ Precheck: `git head-consistency` PASS `20260524T053129Z-git-head-consistency-task-TASK-120-p77299`; `preflight --require-head-consistency` PASS `20260524T053135Z-preflight-require-head-consistency-task-TASK-120-p77870`; `config validate` PASS `20260524T053144Z-config-validate-task-TASK-120-p78569`; `help-json` e `list commands-json` verificati da stdout; branch `main`, HEAD `b6953a5e1c1ee8c557015949a495cf2f84562292`.
- ✅ Scanner pre-hardening: tutti i canonici richiesti eseguiti; PASS locali registrati tra `20260524T053600Z...` e `20260524T053620Z...`.
- ❌ Scanner post-hardening: `scan sync-architecture` FAIL `20260524T054728Z-scan-sync-architecture-task-TASK-120-strict-p292` per retry ownership; `scan evidence-metadata` FAIL finale `20260524T055639Z-scan-evidence-metadata-task-TASK-120-strict-p13644` per tre report storici senza campi rafforzati.
- ✅ Scanner post-fix: `scan scanner-self-tests` PASS `20260524T054728Z-scan-scanner-self-tests-task-TASK-120-strict-p268`; `scan source-format` PASS `20260524T054851Z-scan-source-format-task-TASK-120-strict-p2533`; `scan task-docs` PASS `20260524T055627Z-scan-task-docs-task-TASK-120-strict-p12772`; `scan master-plan-consistency` PASS `20260524T055627Z-scan-master-plan-consistency-task-TASK-120-strict-p12773`; `report validate-json` PASS finale `20260524T055639Z-report-validate-json-task-TASK-120-path-docs-TASKS-EVIDENCE-TASK-120-agent-runs-p13645`; `git diff --check` PASS.
- ✅ Build/test/smoke post-fix: debug build PASS `20260524T054851Z-ios-build-debug-task-TASK-120-p2534`; release build PASS `20260524T054728Z-ios-build-release-task-TASK-120-p291`; automatic-architecture PASS `20260524T054919Z-ios-test-automatic-architecture-task-TASK-120-p4010`; automatic-domain PASS sequenziale `20260524T054933Z-ios-test-automatic-domain-task-TASK-120-p5316`; sync PASS sequenziale `20260524T054945Z-ios-test-sync-task-TASK-120-p5900`; Options smoke PASS `20260524T055220Z-ios-smoke-options-task-TASK-120-p6759`.
- ⚠️ Warning diff: nessun comando harness dedicato trovato. Verifica manuale sui log release dopo fix: rimosso il warning Swift su `HistoryIncrementalApplyService.swift`; resta solo warning Xcode/AppIntents metadata extraction nel log release.
- ✅ Supabase read-only/security: `status-redacted` PASS `20260524T054145Z-supabase-status-redacted-task-TASK-120-p91094`; `contract sync-schema --read-only` PASS `20260524T054145Z-supabase-contract-sync-schema-task-TASK-120-read-only-p91106`; `scan sensitive` PASS `20260524T054145Z-scan-sensitive-task-TASK-120-p91095`; `scan evidence` PASS `20260524T054145Z-scan-evidence-task-TASK-120-p91103`.

### Handoff review
`TASK-120 ACTIVE / FIX — CHANGES_REQUIRED`.

Prossimo passo concreto: spostare la retry policy fuori da `SyncOrchestrator` e dentro `AutomaticSyncEngine`/`Automatic/Core`, aggiungendo o aggiornando test che provino busy/retry/cancel senza scorciatoie UI. Solo dopo rieseguire `scan sync-architecture`, `scan evidence-metadata`, build/test/smoke e aggiornare il verdict. Non eseguire live Supabase, cleanup, migration/RLS/grant/RPC o push GitHub senza override esplicito.
