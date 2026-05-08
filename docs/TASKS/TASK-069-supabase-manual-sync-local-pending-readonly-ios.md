# TASK-069 — Supabase manual sync local pending read-only iOS

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-069 |
| **Titolo** | Supabase manual sync local pending read-only iOS |
| **File task** | `docs/TASKS/TASK-069-supabase-manual-sync-local-pending-readonly-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Nessuno / Workspace IDLE |
| **Data creazione** | 2026-05-07 |
| **Ultimo aggiornamento** | 2026-05-07 22:25 -04 — Review tecnica APPROVED_FIXED_DIRECTLY; fix piccolo su warning isolation provider; build/test/check finali PASS; TASK-069 chiuso **DONE / Chiusura**. |
| **Ultimo agente** | Codex / Reviewer+Fixer+Closer |

## User override controllato

L'utente ha autorizzato esplicitamente l'avvio di **TASK-069** come micro-slice iOS derivata da TASK-068, nonostante al momento dell'avvio TASK-068 fosse ancora planning review / non ready for execution.

Impatto sul workflow standard al momento dell'avvio:

- **TASK-068 non viene riaperto come execution** e resta planning base precedente.
- Il task attivo diventava **TASK-069 ACTIVE / EXECUTION**.
- Il perimetro e' ristretto a un adapter locale read-only per pending aggregati.
- Nessuna sync live, nessuna write remota, nessuna write SwiftData intenzionale.

## Dipendenze e contesto

- **TASK-067 DONE / Chiusura** — UI Release "Sincronizzazione cloud" in `OptionsView`.
- **TASK-068 DONE / Chiusura** — planning rafforzato approvato/consumato; primo micro-step sicuro identificato: pending locali read-only.
- **TASK-066 DONE / Chiusura** — `SupabaseManualSyncViewModel`.
- **TASK-065 DONE / Chiusura** — coordinator dry-run/mock.
- Android/Supabase sono solo riferimento funzionale/documentale. La repo iOS resta fonte principale.

## Scopo

Implementare un adapter locale **read-only** che fornisca a `SupabaseManualSyncCoordinator` / `SupabaseManualSyncViewModel` uno snapshot aggregato dei pending locali reali, sostituendo il provider zero/hardcoded della Release factory.

Obiettivo UX: quando l'utente apre "Sincronizzazione cloud", la UI non deve suggerire "Tutto aggiornato" se localmente risultano modifiche o pending da controllare. Il task non invia nulla e non promette che il cloud sia aggiornato.

## Anti-scope rigido

- No `SupabaseClient` nel provider, ViewModel, coordinator o `OptionsView`.
- No `.rpc`, `.from`, `.upsert`, `.insert`, `.update`, `.delete`.
- No `record_sync_event`.
- No `SyncEventOutboxDrainService.drainOnce`.
- No `SyncEventOutboxEnqueueService.enqueue` come effetto della run.
- No `SupabaseManualPushService.execute`.
- No `SupabaseProductPriceManualPushService`.
- No `SupabasePullApplyService.apply`.
- No `SupabaseCatalogBaselineWriter`.
- No write SwiftData intenzionali.
- No SQL, migration, db push, RPC, RLS, schema.
- No Android, no backend/Supabase.
- No Timer, BGTask, Realtime, worker, polling.
- No `confirmationDialog`.
- No full sync, no cleanup/delete/truncate/reset outbox.
- No TASK-070.

## Criteri di accettazione

| ID | Criterio | Stato |
|----|----------|-------|
| CA69-01 | TASK-069 creato e MASTER-PLAN aggiornato. | [x] |
| CA69-02 | Release factory non usa piu' pending zero hardcoded come unico provider. | [x] |
| CA69-03 | Provider locale read-only produce aggregati privacy-safe reali. | [x] |
| CA69-04 | Provider rispetta auth/session owner scope e non riusa conteggi stale. | [x] |
| CA69-05 | Catalog pending locale usa baseline/preflight locale senza push. | [x] |
| CA69-06 | Outbox pending locale usa soli conteggi locali senza drain. | [x] |
| CA69-07 | ProductPrice resta deferred/excluded dalla prima slice. | [x] |
| CA69-08 | Pending > 0 non viene comunicato come "Tutto aggiornato". | [x] |
| CA69-09 | Zero pending resta "Tutto aggiornato". | [x] |
| CA69-10 | Nessuna rete Supabase, write remota, baseline writer, push/pull/apply/drain/flush. | [x] |
| CA69-11 | Test/check richiesti documentati e passanti o motivati. | [x] |
| CA69-12 | TASK-069 passa ad ACTIVE / REVIEW, non DONE. | [x] |

## Planning (Claude)

TASK-068 ha identificato come primo step sicuro un adapter pending locale read-only. User override 2026-05-07 autorizza l'execution di questa micro-slice come TASK-069.

## Execution (Codex)

### Obiettivo compreso

Implementare una micro-slice iOS read-only: la Release "Sincronizzazione cloud" deve leggere pending locali aggregati reali, scoped alla sessione corrente, e non deve piu' comunicare "Tutto aggiornato" quando localmente esistono modifiche da controllare. Nessuna sync live, nessuna rete Supabase nuova e nessuna write locale/remota intenzionale.

### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-068-supabase-manual-sync-live-wiring-planning-ios.md`
- `docs/TASKS/TASK-067-supabase-manual-sync-release-ui-optionsview-ios.md`
- `docs/TASKS/TASK-066-supabase-manual-sync-viewmodel-states-ios.md`
- `docs/TASKS/TASK-065-supabase-manual-sync-coordinator-dryrun-ios.md`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinatorModels.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinating.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightModels.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineReader.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineWriter.swift` solo per verificare non uso.
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift` (`SyncEventOutboxLocalStore` e' definito qui; il file separato richiesto non esiste nel filesystem).
- `iOSMerchandiseControl/SyncEventOutboxDrainService.swift` solo per verificare non uso.
- `iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift` solo per contesto e verificare non uso.
- `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncCoordinatorTests.swift`
- Test outbox/recording/regressione elencati nei check.

### Piano minimo

1. Creare tracking TASK-069 e aggiornare `MASTER-PLAN` con user override controllato.
2. Aggiungere provider locale read-only fakeable per snapshot pending catalogo/outbox, con session scope e output privacy-safe.
3. Sostituire il provider zero/hardcoded nella Release factory.
4. Mappare `pending > 0` su copy/stato gia' esistente non "Tutto aggiornato".
5. Aggiungere XCTest provider/ViewModel/statici e rieseguire regressioni richieste.
6. Aggiornare handoff a REVIEW senza marcare DONE.

### Modifiche fatte

- Creato `SupabaseManualSyncLocalPendingSnapshotProvider` con protocolli fakeable per sessione, catalog pending, outbox pending, baseline e snapshot loader.
- Aggiunti adapter read-only:
  - catalogo: baseline reader + snapshot SwiftData bounded + preflight locale, senza push e senza baseline writer;
  - outbox: `SyncEventOutboxLocalStore.fetchCounts(owner:now:)`, senza drain/flush.
- Integrata la Release factory sul nuovo provider locale al posto del provider zero/hardcoded.
- Aggiornato il ViewModel: se il coordinator conclude con success ma lo snapshot contiene pending, la UI mostra `partialSync` con "Ci sono modifiche da controllare" e "Nessun invio automatico.".
- ProductPrice resta esplicitamente deferred/excluded: conteggio prezzi locale a zero in questa slice.
- Esteso `SyncEventOutboxCounts` con `failedRetryable` per distinguere anche pending retryable futuri senza drain.
- Aggiornate localizzazioni IT/EN/ES/ZH-Hans per copy Release piu' onesto.
- Aggiunti XCTest provider TASK-069, static guardrail Release/read-only, e aggiornate aspettative ViewModel/outbox.

### Cosa cambia per l'utente

Aprendo "Sincronizzazione cloud", se esistono pending locali aggregati per l'account corrente, la card non dice piu' "Tutto aggiornato": mostra che ci sono modifiche da controllare e chiarisce che non c'e' invio automatico.

### Cosa NON cambia funzionalmente

Non viene inviato nulla al cloud. Non viene letto nulla da Supabase in questo nuovo provider. Non viene applicato pull remoto, non viene fatto drain outbox, non viene scritto baseline, non vengono mutate intenzionalmente entita' SwiftData, non viene aggiunto polling/background/realtime e non viene introdotta UI di conferma.

### Check eseguiti

- ✅ ESEGUITO — Build Debug: `xcodebuild -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` -> **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Build Release: `xcodebuild -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` -> **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Warning nuovi: nessun warning Swift rilevato nei file TASK-069; resta warning tooling AppIntents metadata gia' osservato nel progetto ("No AppIntents.framework dependency found").
- ✅ ESEGUITO — XCTest mirati TASK-069/Release/ViewModel: 32 test, 0 failure.
- ✅ ESEGUITO — Regressioni richieste: `SupabaseManualSyncReleaseUITests`, `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncCoordinatorTests`, `SyncEventOutboxStateTests`, `SyncEventOutboxLocalStoreTests`, `SyncEventOutboxDrainServiceTests`, `SyncEventOutboxEnqueueServiceTests`, `SyncEventRecordingTests`, `SyncEventLiveRecorderTests`, `SupabaseManualSyncLocalPendingSnapshotProviderTests` -> 200 test, 0 failure.
- ✅ ESEGUITO — `git diff --check` -> nessun problema.
- ✅ ESEGUITO — `plutil -lint iOSMerchandiseControl/*.lproj/Localizable.strings` -> OK per IT/EN/ES/ZH-Hans.
- ✅ ESEGUITO — duplicate localization keys -> nessun duplicato.
- ✅ ESEGUITO — Static anti-scope su factory/provider/coordinator/ViewModel: nessun match per `SupabaseClient`, `.rpc`, `.from`, `.upsert`, `.insert`, `.update`, `.delete`, `record_sync_event`, drain/push/pull/apply/baseline writer, `confirmationDialog`, background/realtime/worker.
- ✅ ESEGUITO — Static copy Release no-jargon su chiavi `options.supabase.manualSync`: nessun match per outbox/drain/sync_events/RPC/payload/retryable/JSON/UUID/record_sync_event.
- ✅ ESEGUITO — Modifiche coerenti con planning TASK-068 e user override TASK-069.
- ✅ ESEGUITO — Criteri di accettazione CA69-01...CA69-12 verificati.
- ⚠️ NON ESEGUIBILE — Test manuale Simulator: non richiesto esplicitamente per TASK-069; copertura eseguita via XCTest/static/build.

### Anti-scope confermati

- Nessun `SupabaseClient` aggiunto nel provider, ViewModel, coordinator o Release factory.
- Nessun `.rpc`, `.from`, `.upsert`, `.insert`, `.update`, `.delete` nel path TASK-069.
- Nessun `record_sync_event`, `drainOnce`, push manuale, ProductPrice push, pull apply, baseline writer.
- Nessuna modifica Android, backend, Supabase, SQL, migration, RLS o schema.
- Nessun Timer/BGTask/Realtime/worker/polling.
- Nessun `confirmationDialog`, full sync, cleanup/delete/truncate/reset outbox.
- Nessun TASK-070 creato.

### Rischi rimasti

- Il conteggio catalogo e' bounded con limite conservativo: se lo snapshot locale supera il limite, il provider ritorna `1` pending come flag prudente, non un conteggio preciso.
- ProductPrice resta fuori da TASK-069: eventuali pending prezzi locali non sono ancora rappresentati nello snapshot.
- Se la baseline catalogo manca o e' invalida, il provider non inventa pending catalogo; il coordinator continua a usare il gate baseline esistente.
- La card continua a indicare stato locale/read-only: non prova che il cloud sia aggiornato.

## Handoff post-execution -> Review (Claude)

**Stato:** ACTIVE / REVIEW  
**Responsabile prossimo:** Claude / Reviewer  
**Ultimo aggiornamento:** 2026-05-07 22:13 -04

Review richiesta su:

- Correttezza del boundary read-only locale e assenza di live sync nascosta.
- Session/owner scope del provider e comportamento safe quando manca auth.
- Scelta conservativa su catalog snapshot bounded e ProductPrice deferred.
- Mapping UX `pending > 0` -> "Ci sono modifiche da controllare" / "Nessun invio automatico.".
- Completezza dei test statici anti-scope e regressioni.

File modificati:

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-069-supabase-manual-sync-local-pending-readonly-ios.md`
- `iOSMerchandiseControl/SupabaseManualSyncLocalPendingSnapshotProvider.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/SupabaseManualSyncLocalPendingSnapshotProviderTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxLocalStoreTests.swift`

TASK-069 non e' DONE e attende review.

## Review+Fix (Claude)

### 2026-05-07 22:25 -04 — Review tecnica / APPROVED_FIXED_DIRECTLY

Esito review: **APPROVED_FIXED_DIRECTLY**.

La review repo-grounded conferma che TASK-069 rispetta il perimetro read-only:

- Il provider locale non usa `SupabaseClient`, `.rpc`, `.from`, `.upsert`, `.insert`, `.update`, `.delete`, `record_sync_event`, push/pull/apply/drain o baseline writer.
- Lo snapshot pending e' owner/session-scoped: senza auth/sessione valida ritorna zero e non riusa conteggi stale.
- Catalog pending usa solo baseline reader + preflight locale bounded; ProductPrice resta deferred/excluded.
- Outbox pending usa solo count locali owner-scoped e non fa drain, enqueue, cleanup o reset.
- `pending > 0` non viene comunicato come "Tutto aggiornato"; zero pending puo' restare "Tutto aggiornato".
- La copy Release localizzata resta user-facing e non espone gergo outbox/drain/sync_events/RPC/payload/retryable/JSON/UUID.
- `OptionsView` non introduce business logic nuova nella card Release; ViewModel resta fonte dello stato UI.

Problema piccolo trovato e corretto direttamente:

- `SupabaseManualSyncLocalPendingSnapshotProvider.swift`: il build Release segnalava un nuovo warning Swift 6 per accesso da contesto nonisolated a `defaultMaxRowsPerEntity` / `hardMaxRowsPerEntity`. Le costanti sono state marcate `nonisolated static let`, senza cambiare comportamento runtime.

Check finali post-fix:

- ✅ ESEGUITO — Build Debug iPhone 16e OS 26.2: **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Build Release iPhone 16e OS 26.2: **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Nessun warning nuovo TASK-069 dopo il fix; restano warning preesistenti/out-of-scope in `SupabaseProductPriceApplyService.swift`, `SyncEventOutboxDrainService.swift` e metadata AppIntents.
- ✅ ESEGUITO — XCTest mirati e regressioni richieste: **200 test**, 0 failure, **TEST SUCCEEDED**.
- ✅ ESEGUITO — `git diff --check`: nessun problema.
- ✅ ESEGUITO — `plutil -lint` localizzazioni IT/EN/ES/ZH-Hans: OK.
- ✅ ESEGUITO — duplicate localization keys: nessun duplicato.
- ✅ ESEGUITO — grep anti-scope core path + Release card: nessun match vietato.
- ✅ ESEGUITO — grep Release copy no-jargon sulle chiavi `options.supabase.manualSync`: nessun match vietato.
- ✅ ESEGUITO — CA69-01...CA69-12 verificati.

## Chiusura

TASK-069 **DONE / Chiusura**.

- Chiuso come execution tecnica read-only per pending locali aggregati.
- Nessuna sync live, nessuna write remota, nessuna write SwiftData intenzionale, nessun backend/Supabase/SQL/Android modificato.
- Nessun TASK-070 creato.
- Workspace pronto a tornare **IDLE** dopo riallineamento `docs/MASTER-PLAN.md`.
