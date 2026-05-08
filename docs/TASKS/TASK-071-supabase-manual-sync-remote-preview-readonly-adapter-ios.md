# TASK-071 — Supabase manual sync remote preview read-only adapter iOS

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-071 |
| **Titolo** | Supabase manual sync remote preview read-only adapter iOS |
| **File task** | `docs/TASKS/TASK-071-supabase-manual-sync-remote-preview-readonly-adapter-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Nessuno / Workspace IDLE |
| **Data creazione** | 2026-05-07 |
| **Ultimo aggiornamento** | 2026-05-07 23:15 -04 — Review tecnica APPROVED_FIXED_DIRECTLY; fix piccolo su zero-pending + provider preview; build/test/check finali PASS; TASK-071 chiuso **DONE / Chiusura**. |
| **Ultimo agente** | Codex / Reviewer+Fixer+Closer |

## User override controllato

L'utente ha autorizzato esplicitamente una micro-slice iOS separata derivata da TASK-070, nonostante TASK-070 resti planning base precedente.

Impatto sul workflow:

- Il task e' stato avviato come **TASK-071 ACTIVE / EXECUTION**, passato a **ACTIVE / REVIEW** dopo l'handoff Codex e ora chiuso **DONE / Chiusura** dopo review/fix.
- **TASK-070 e' DONE / Chiusura** come planning base precedente; non e' stato trasformato in execution.
- **TASK-069 resta DONE / Chiusura** come ultimo completato.
- Android/Supabase/backend/SQL restano solo riferimenti funzionali/documentali e non vengono modificati.

## Dipendenze e contesto

- **TASK-070 DONE / Chiusura** — pianificazione pull preview remota read-only; usato come fonte per perimetro, DTO privacy-safe, mapper e anti-scope.
- **TASK-069 DONE / Chiusura** — pending locali read-only reali nella Release factory/ViewModel.
- **TASK-068 DONE / Chiusura** — live wiring planning/gap analysis precedente.
- **TASK-067 DONE / Chiusura** — UI Release "Sincronizzazione cloud" in `OptionsView`.
- **TASK-066 DONE / Chiusura** — `SupabaseManualSyncViewModel`.
- **TASK-065 DONE / Chiusura** — `SupabaseManualSyncCoordinator` dry-run/mock.
- **TASK-063** — base manual-first: no automazione, no background, no Realtime, no baseline bump implicito.

## Scopo

Implementare solo lo strato tecnico read-only/fakeable per remote preview:

- protocol/provider concettuale per preview remota;
- summary DTO piccolo e privacy-safe;
- mapper preview -> phase outcome / summary interno;
- test fake senza rete live;
- wiring opzionale nel coordinator tramite dependency injection, non attivo in Release.

## Non incluso

- Nessuna modifica `OptionsView`.
- Nessuna nuova UI pubblica o CTA "Controlla cloud".
- Nessuna modifica `Localizable.strings`.
- Nessuna Supabase live call obbligatoria.
- Nessun apply locale.
- Nessun push remoto.
- Nessun drain/flush outbox.
- Nessun enqueue.
- Nessun baseline writer.
- Nessun `record_sync_event`.
- Nessun SQL/migration/db push/RPC/RLS/schema.
- Nessun Android/backend.
- Nessun Timer/BGTask/Realtime/worker/polling.
- Nessun TASK-072.

## Criteri di accettazione

| ID | Criterio | Stato |
|----|----------|-------|
| CA71-01 | TASK-071 creato e MASTER-PLAN aggiornato. | [x] |
| CA71-02 | Esiste strato preview remoto read-only fakeable. | [x] |
| CA71-03 | Esiste DTO summary piccolo e privacy-safe. | [x] |
| CA71-04 | Esiste mapper preview -> outcome senza jargon e senza `SyncPreview` raw verso Release/UI. | [x] |
| CA71-05 | Coordinator supporta preview tramite DI opzionale senza attivarla automaticamente in Release. | [x] |
| CA71-06 | Comportamento TASK-069 resta invariato quando provider preview non e' presente. | [x] |
| CA71-07 | Nessun apply/push/drain/flush/enqueue/baseline writer. | [x] |
| CA71-08 | Nessuna UI nuova e nessuna localizzazione nuova. | [x] |
| CA71-09 | Nessuna live call obbligatoria. | [x] |
| CA71-10 | Test richiesti passano. | [x] |
| CA71-11 | TASK-071 passa ad ACTIVE / REVIEW nel handoff execution; review finale separata puo' chiuderlo DONE. | [x] |

## Planning (Claude / TASK-070 consumato)

La micro-slice segue la sezione "Micro-slice TASK-071 consigliata" di TASK-070:

1. Adapter + mapper read-only fakeable.
2. DI/feature-gating nel coordinator.
3. Nessun `OptionsView`.
4. Nessuna nuova copy Release / nessun `Localizable`.
5. ProductPrice solo aggregato/deferred, mai dettagli user-facing.
6. Nessuna transizione verso apply/push/drain dopo preview-only.

## Execution (Codex)

### Obiettivo compreso

Creare uno strato tecnico read-only e testabile per trasformare una pull preview remota in un summary aggregato privacy-safe, più un piccolo wiring opzionale nel coordinator. La Release resta sul comportamento TASK-069 perché la factory non inietta alcun provider preview.

### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-070-supabase-manual-sync-pull-preview-readonly-planning-ios.md`
- `docs/TASKS/TASK-069-supabase-manual-sync-local-pending-readonly-ios.md`
- `docs/TASKS/TASK-068-supabase-manual-sync-live-wiring-planning-ios.md`
- `docs/TASKS/TASK-067-supabase-manual-sync-release-ui-optionsview-ios.md`
- `docs/TASKS/TASK-066-supabase-manual-sync-viewmodel-states-ios.md`
- `docs/TASKS/TASK-065-supabase-manual-sync-coordinator-dryrun-ios.md`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinatorModels.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinating.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/SupabaseManualSyncLocalPendingSnapshotProvider.swift`
- `iOSMerchandiseControl/SupabasePullPreviewService.swift`
- `iOSMerchandiseControl/SupabasePullPreviewModels.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/SupabasePullApplyService.swift` *(solo confine: NON usato)*
- `iOSMerchandiseControl/SupabaseCatalogBaselineWriter.swift` *(solo confine: NON usato)*
- Test esistenti richiesti: pagination, diff engine, coordinator, ViewModel, Release UI, local pending provider.

### Piano minimo

1. Creare tracking TASK-071 e aggiornare `MASTER-PLAN` con override controllato.
2. Aggiungere `SupabaseManualSyncRemotePreviewProviding`, DTO summary aggregato e mapper.
3. Aggiungere `SupabaseManualSyncPullPreviewAdapter` come facade opzionale su `SupabasePullPreviewService`.
4. Estendere il coordinator con dependency opzionale `remotePreviewProvider`, default `nil`.
5. Se provider presente, terminare la run come preview-only dopo `.remotePreview`, saltando user confirmation e fasi successive.
6. Aggiungere XCTest mapper/provider/coordinator e static guardrail.
7. Eseguire build/test/check e passare a REVIEW.

### Modifiche fatte

- Aggiunto `SupabaseManualSyncRemotePreview.swift` con:
  - `SupabaseManualSyncRemotePreviewProviding`;
  - `SupabaseManualSyncRemotePreviewSummary`;
  - aggregate counts privacy-safe;
  - failure/message key interni;
  - `SupabaseManualSyncRemotePreviewOutcomeMapper`;
  - `SupabaseManualSyncPullPreviewAdapter`.
- Esteso `SupabaseManualSyncRunSummary` con `remotePreviewSummary` opzionale.
- Esteso `SupabaseManualSyncCoordinator.Dependencies` con `remotePreviewProvider` opzionale, default `nil`.
- Se un provider preview e' presente, il coordinator esegue preview-only e termina dopo `.remotePreview` + `.summary`, senza avviare confirmation/apply/push/drain/flush.
- Aggiunto copy interno preview-only "Controllo cloud completato. Nessuna azione richiesta." per evitare di riusare "Tutto aggiornato" su un controllo read-only.
- Aggiunti XCTest per mapper/provider/adapter fake e regressioni coordinator preview-only.
- Aggiunti guardrail statici test/grep per write path, automazione e raw `SyncPreview` in Release card.

### Cosa cambia tecnicamente

- Esiste una facade read-only/fakeable che traduce `SupabasePullPreviewService` in un summary aggregato, senza esporre `SyncPreview` raw a Release/UI.
- Il summary contiene solo flag, conteggi aggregati ed enum interni: niente barcode, nomi prodotto, nomi fornitore/categoria, UUID, JSON, payload o liste di righe.
- Il mapper distingue:
  - complete + no remote signals -> no action / completed;
  - complete + remote signals -> needs review;
  - partial/budget-limited -> incomplete/partial, mai success pieno;
  - network -> failure retryable / connectivity;
  - permission/RLS/schema/decode -> failure user-facing non tecnico;
  - cancelled -> cancelled, mai success.
- `ProductPrice` resta deferred lato UX: eventuali segnali sono solo conteggi aggregati interni.
- Il summary preview-only completo senza segnali non promette che il cloud sia aggiornato: usa un messaggio di controllo completato/no action.
- La Release factory non inietta il provider preview; comportamento TASK-069 invariato.

### Cosa cambia per l'utente

Idealmente nulla di visibile in questa slice: nessuna nuova UI, nessuna nuova CTA, nessuna nuova localizzazione, nessuna promessa che il cloud sia aggiornato.

### Cosa NON cambia funzionalmente

Non parte alcuna preview cloud dalla UI Release. Non viene attivata alcuna chiamata live in Release. Non viene applicato nulla localmente e non viene scritto nulla in remoto.

### Check eseguiti

- ✅ ESEGUITO — XCTest mirati nuovi/coordinator: run iniziale `SupabaseManualSyncRemotePreviewTests` + `SupabaseManualSyncCoordinatorTests` con `-parallel-testing-enabled NO` -> **35 test**, 0 failure, **TEST SUCCEEDED**; run finale coperta dal set regressioni sotto.
- ✅ ESEGUITO — Regressioni richieste: `SupabaseManualSyncRemotePreviewTests`, `SupabasePullPreviewPaginationTests`, `SupabasePullPreviewDiffEngineTests`, `SupabaseManualSyncCoordinatorTests`, `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncReleaseUITests`, `SupabaseManualSyncLocalPendingSnapshotProviderTests` -> **85 test**, 0 failure, **TEST SUCCEEDED**.
- ✅ ESEGUITO — Build Debug: `xcodebuild -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` -> **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Build Release: `xcodebuild -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` -> **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Nessun warning nuovo introdotto: output build verificato; nessun warning da file TASK-071/modificati. Restano warning/tooling preesistenti fuori scope (`SupabaseProductPriceApplyService.swift`, `SyncEventOutboxDrainService.swift` e AppIntents metadata).
- ✅ ESEGUITO — `git diff --check` -> nessun errore.
- ✅ ESEGUITO — Static grep produzione TASK-071/manual sync: nessun `SupabasePullApplyService`, `SupabaseCatalogBaselineWriter`, `drainOnce`, `enqueue`, `SupabaseManualPushService.execute`, `SupabaseProductPriceManualPushService`, `record_sync_event`, `.rpc`, `.upsert`, `.insert`, `.update`, `.delete`, `Timer`, `BGTask`, `Realtime`, `worker`, `polling`, `SupabaseClient` nei file di produzione toccati/scope.
- ✅ ESEGUITO — Static grep Release card: nessun raw `SyncPreview` / adapter live / `SupabaseClient` / `.rpc` in `SupabaseManualSyncReleaseCard`.
- ⚠️ NON ESEGUIBILE — `plutil`: non necessario per TASK-071, nessun `Localizable.strings` o plist modificato.
- ⚠️ NON ESEGUIBILE — duplicate localization keys: non necessario per TASK-071, nessuna localizzazione modificata.
- ✅ ESEGUITO — Criteri di accettazione verificati static/build/test:
  - CA71-01 STATIC: task creato, `MASTER-PLAN` aggiornato.
  - CA71-02 STATIC/TEST: provider/protocol/fake adapter aggiunti e coperti da XCTest.
  - CA71-03 STATIC/TEST: DTO aggregato privacy-safe e test anti-identificatori.
  - CA71-04 STATIC/TEST: mapper outcome e no raw `SyncPreview` Release.
  - CA71-05 STATIC/TEST: DI opzionale coordinator, Release factory invariata.
  - CA71-06 TEST: provider `nil` preserva comportamento TASK-069.
  - CA71-07 STATIC/TEST: nessun apply/push/drain/flush/enqueue/baseline writer.
  - CA71-08 STATIC: nessuna UI/Localizable modificata.
  - CA71-09 STATIC/TEST: fake provider/adapter senza rete live obbligatoria.
  - CA71-10 BUILD/TEST: build Debug/Release e test richiesti passati.
  - CA71-11 STATIC: stato aggiornato a ACTIVE / REVIEW nel handoff execution; review finale separata ora chiusa DONE.

### Anti-scope confermati

- Nessuna modifica a `OptionsView`.
- Nessuna nuova UI strutturale o CTA.
- Nessuna modifica `Localizable.strings`.
- Nessuna Supabase live call obbligatoria.
- Nessun `SupabaseClient` diretto in coordinator/ViewModel/OptionsView.
- Nessun apply locale.
- Nessun push remoto.
- Nessun ProductPrice push.
- Nessun drain/flush outbox.
- Nessun enqueue.
- Nessun baseline writer.
- Nessun `record_sync_event`.
- Nessun SQL/migration/db push/RPC/RLS/schema.
- Nessun Android/backend.
- Nessun Timer/BGTask/Realtime/worker/polling.
- Nessun TASK-072.

### Rischi rimasti

- `SupabaseManualSyncPullPreviewAdapter` e' disponibile ma non iniettato in Release: una slice futura dovra' decidere esplicitamente trigger UX/copy/localizzazioni prima di usarlo.
- Il mapping preview-only con remote signals resta tecnico/interno: non c'e' ancora copy Release per spiegare all'utente cosa revisionare.
- `ProductPrice` e' solo aggregato/deferred; qualunque dettaglio user-facing resta fuori scope.
- Warning/tooling preesistenti restano fuori TASK-071.

## Handoff post-execution -> Review (Claude)

| Campo | Valore |
|-------|--------|
| **Stato task** | ACTIVE |
| **Fase** | REVIEW |
| **Responsabile prossimo** | Claude / Reviewer |
| **Handoff da** | Codex / Cursor Executor |
| **Data handoff** | 2026-05-07 23:04 -04 |

### File modificati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-071-supabase-manual-sync-remote-preview-readonly-adapter-ios.md`
- `iOSMerchandiseControl/SupabaseManualSyncRemotePreview.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinatorModels.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncRemotePreviewTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncCoordinatorTests.swift`

### Review focus suggerito

- Verificare che il nuovo provider opzionale non alteri il percorso Release TASK-069 quando `remotePreviewProvider == nil`.
- Verificare che preview-only non possa proseguire verso confirmation/apply/push/drain/flush.
- Verificare che il DTO resti privacy-safe e che `SyncPreview` raw non trapeli verso Release/UI.
- Confermare che l'esito `partial`/`cancelled` non venga mai trattato come sync completata.

TASK-071 e' stato consegnato storicamente a **ACTIVE / REVIEW** e non era marcato DONE nell'handoff execution; la review finale del 2026-05-07 23:15 -04 lo ha chiuso **DONE / Chiusura**.

## Review (Claude)

| Campo | Valore |
|-------|--------|
| **Stato review** | COMPLETATA |
| **Esito review** | **APPROVED_FIXED_DIRECTLY** |
| **Data review** | 2026-05-07 23:15 -04 |

### Sintesi review tecnica

La review repo-grounded conferma che TASK-071 rispetta il perimetro read-only:

- `SupabaseManualSyncRemotePreviewProviding` e' fakeable/testabile.
- `SupabaseManualSyncRemotePreviewSummary` e' piccolo, aggregato e privacy-safe: nessun barcode, nome prodotto/fornitore/categoria, UUID, JSON o payload raw.
- `SupabaseManualSyncRemotePreviewOutcomeMapper` distingue complete/no signals, complete/remote signals, partial/budget-limited, network failure, permission/RLS/schema/decode, local snapshot, unknown e cancelled.
- `SyncPreview` raw resta confinato al preview stack/test e non arriva alla Release card/factory/ViewModel.
- Il coordinator mantiene provider opzionale con default `nil`; `SupabaseManualSyncReleaseFactory` resta invariata e non attiva preview remota.
- Con provider `nil`, il comportamento TASK-069 resta invariato.
- Con provider presente, la run preview-only termina dopo `.remotePreview` + `.summary` e non prosegue verso confirmation/apply/push/ProductPrice/outbox drain/enqueue/baseline writer.
- Nessuna modifica `OptionsView`, nessuna nuova UI, nessuna `Localizable.strings`, nessun backend/Supabase/SQL/Android, nessun TASK-072.

Problema piccolo trovato e corretto direttamente:

- Il coordinator saltava ancora `.remotePreview` quando i pending locali erano zero, anche se `remotePreviewProvider` era presente. Il fix mantiene lo skip TASK-069 solo con provider `nil`; quando il provider e' iniettato, la preview read-only esplicita viene eseguita anche con pending locali zero e termina preview-only.

### Check finali post-fix

- ✅ ESEGUITO — Build Debug iPhone 16e OS 26.2: **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Build Release iPhone 16e OS 26.2: **BUILD SUCCEEDED**.
- ✅ ESEGUITO — Nessun warning nuovo introdotto da file TASK-071; restano warning preesistenti/out-of-scope in `SyncEventOutboxDrainService.swift`, `SupabaseProductPriceApplyService.swift` e test DEBUG outbox.
- ✅ ESEGUITO — XCTest richiesti con `-parallel-testing-enabled NO`: `SupabaseManualSyncRemotePreviewTests`, `SupabasePullPreviewPaginationTests`, `SupabasePullPreviewDiffEngineTests`, `SupabaseManualSyncCoordinatorTests`, `SupabaseManualSyncViewModelTests`, `SupabaseManualSyncReleaseUITests`, `SupabaseManualSyncLocalPendingSnapshotProviderTests` -> **86 test**, **TEST SUCCEEDED**.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — Grep anti-scope sui file produzione TASK-071/Release path: nessun `SupabasePullApplyService`, `SupabaseCatalogBaselineWriter`, `drainOnce`, `enqueue`, `SupabaseManualPushService.execute`, `SupabaseProductPriceManualPushService`, `record_sync_event`, `.rpc`, `.from`, `.upsert`, `.insert`, `.update`, `.delete`, `Timer`, `BGTask`, `Realtime`, `worker`, `polling`, `SupabaseClient`, `TASK-072`.
- ✅ ESEGUITO — Grep no raw preview: `SyncPreview` assente da `SupabaseManualSyncReleaseCard`, `SupabaseManualSyncReleaseFactory` e `SupabaseManualSyncViewModel`; i match in `OptionsView` sono in sezione preview/apply storica fuori card Release.
- ✅ ESEGUITO — Criteri CA71-01...CA71-11 verificati dopo fix.
- ⚠️ NON ESEGUIBILE — `plutil` e duplicate localization keys: nessuna localizzazione o plist modificata in TASK-071.

## Chiusura

TASK-071 **DONE / Chiusura**.

- Chiuso come execution tecnica read-only/fakeable per remote preview adapter.
- Fix applicato: provider preview presente esegue `.remotePreview` anche con pending locali zero e termina preview-only.
- Nessuna live sync, nessun apply/push/drain/enqueue/baseline writer, nessuna UI nuova, nessuna `Localizable`, nessun backend/Supabase/SQL/Android modificato.
- TASK-072 non creato.
