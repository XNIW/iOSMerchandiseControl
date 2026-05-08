# TASK-068 — Supabase manual sync live wiring planning iOS

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-068 |
| **Titolo** | Supabase manual sync live wiring planning iOS |
| **File task** | `docs/TASKS/TASK-068-supabase-manual-sync-live-wiring-planning-ios.md` |
| **Stato** | DONE |
| **Fase attuale** | Chiusura |
| **Responsabile attuale** | Nessuno / Workspace IDLE |
| **Data creazione** | 2026-05-07 |
| **Ultimo aggiornamento** | 2026-05-07 22:25 -04 — Review planning APPROVED; TASK-068 chiuso **DONE / Chiusura** come planning/gap analysis, non come codice. TASK-069 ha consumato la micro-slice proposta tramite override utente separato. |
| **Ultimo agente** | Codex / Reviewer+Closer (user override controllato) |

## User override controllato

L'utente ha autorizzato esplicitamente la creazione del prossimo task iOS **TASK-068** come **PLANNING + gap analysis tecnico**, con eventuali micro-fix documentali/tracking, non come execution live completa.

Impatto sul workflow standard: il progetto era **IDLE** dopo **TASK-067 DONE / Chiusura**; questo file apre un nuovo task attivo in **PLANNING**. Non esiste autorizzazione a modificare codice Swift, backend/Supabase, SQL, Android o a creare il file TASK-069.

Nota di chiusura: TASK-069 e' stato poi avviato tramite **user override separato** e non trasforma TASK-068 in execution.

## Dipendenze e contesto

- **Dipende da**
  - **TASK-067 DONE / Chiusura** — UI Release "Sincronizzazione cloud" in `OptionsView`, collegata a ViewModel/coordinator dry-run/mock.
  - **TASK-066 DONE / Chiusura** — `SupabaseManualSyncViewModel` non-DEBUG + protocol `SupabaseManualSyncCoordinating`.
  - **TASK-065 DONE / Chiusura** — `SupabaseManualSyncCoordinator` dry-run/mock + phase/outcome/summary.
  - **TASK-064 DONE / Chiusura** — hardening outbox `sync_events` per `sending` stale recovery.
  - **TASK-063** — planning base precedente (manual-first, invarianti **D63** e anti-scope); **non** task attivo iOS da riaprire; fonte architetturale per coerenza review.
- **Riferimenti funzionali non iOS**
  - Android **TASK-068 PARTIAL**: bulk product push client-side resta non validato live pienamente.
  - Android **TASK-070 DONE**: retry outbox head-of-line risolto app-side con logging privacy-safe, senza backend changes.
  - Android **TASK-071 DONE**: mismatch `record_sync_event` / `PayloadValidation`, soprattutto `p_changed_count > 1000`.
  - Supabase locale `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql`: RPC `record_sync_event` single-row, owner-scoped, `changed_count` ammesso **0...1000**.

## Scopo

Preparare un piano tecnico **repo-grounded** per trasformare gradualmente la run guidata iOS da dry-run/mock a collegamento con servizi live esistenti, senza introdurre sync automatica, backend changes, full sync massiva o rischio dati.

TASK-068 deve chiarire:

1. Cosa fa oggi la UI Release TASK-067.
2. Cosa espone oggi `SupabaseManualSyncViewModel`.
3. Cosa fa oggi `SupabaseManualSyncCoordinator` dry-run.
4. Quali servizi iOS live esistono gia'.
5. Quali sono sicuri da collegare subito.
6. Quali richiedono task separato.
7. Quali rischi Android/Supabase impediscono live wiring completo.
8. Quale micro-slice concreta deve seguire come TASK-069 o execution successiva.

## Anti-scope rigido TASK-068

- **NO** implementazione live completa.
- **NO** modifica funzionale `OptionsView` o UI Release.
- **NO** codice Swift applicativo.
- **NO** sync automatica.
- **NO** Timer, `BGTask`, BackgroundTasks, Realtime, worker, polling.
- **NO** Supabase live calls obbligatorie.
- **NO** SQL, migration, `db push`, RPC/RLS/trigger/schema.
- **NO** cleanup/delete/truncate/reset outbox.
- **NO** full sync Product/ProductPrice.
- **NO** baseline bump implicito post-push.
- **NO** pull -> push -> pull automatico.
- **NO** modifica Android/backend.
- **NO** creazione TASK-069 se non come proposta testuale.
- **NO** dichiarare DONE senza review.

## Decisioni planning TASK-068

Decisioni vincolanti per la review del planning e per qualsiasi task future di execution (es. proposta testuale **TASK-069**); non costituiscono autorizzazione a EXECUTION da questo file.

| ID | Decisione |
|----|-----------|
| **D68-01** | Il primo micro-step consigliato resta **adapter pending locale read-only**: aggregati privacy-safe da dati gia' presenti sul device, **nessuna write remota**. |
| **D68-02** | La UI Release (TASK-067) puo' restare **dry-run** finche' lo **snapshot pending reale** non e' implementato in un task execution dedicato. |
| **D68-03** | Il comportamento **«Tutto aggiornato»** con pending snapshot **zero** e' accettabile **solo** come stato **temporaneo** post-TASK-067 (pending hardcoded/zero), **non** come verita' finale sullo stato cloud o locale complesso. |
| **D68-04** | **Nessun read remoto obbligatorio** nel primo micro-step; **pull preview read-only** resta **slice successiva**, budgetata e separata. |
| **D68-05** | **Nessun baseline writer** nel primo micro-step (niente commit/bump fingerprint locale legato a push). |
| **D68-06** | **Nessun ProductPrice live push** nel primo micro-step. |
| **D68-07** | **Nessun catalog push live** finche' non sia stata decisa **esplicitamente** la policy **baseline post-push** (allineata a D63 / rischio bump implicito). |
| **D68-08** | **Nessun flush** della coda operazioni cloud dentro la run Release finche' non esistono **conferma utente** + **mapping partial** adeguato (non promettere invio completato su esiti parziali). |
| **D68-09** | Se **pending > 0**, la UX futura deve comunicare che **ci sono modifiche da controllare**, non che la **sincronizzazione e' completata** ne' equivalenti fuorvianti. |
| **D68-10** | **TASK-069** puo' essere **proposto testualmente** in questo planning; **TASK-068 non crea** il file `TASK-069*.md` e non promuove EXECUTION senza review + override utente. |

## Criteri di accettazione TASK-068 planning

| ID | Criterio | Stato |
|----|----------|-------|
| CA68-01 | File task creato e coerente con MASTER-PLAN. | [x] |
| CA68-02 | Master Plan aggiornato a progetto ACTIVE / PLANNING, task attivo TASK-068. | [x] |
| CA68-03 | Tutti i servizi iOS live rilevanti inventariati. | [x] |
| CA68-04 | Gap dry-run -> live wiring chiarito. | [x] |
| CA68-05 | Primo micro-step live consigliato con motivazione. | [x] |
| CA68-06 | Rischi Android/Supabase integrati. | [x] |
| CA68-07 | Anti-scope esplicito. | [x] |
| CA68-08 | Nessun codice Swift modificato. | [x] |
| CA68-09 | Nessun backend/Supabase/Android modificato. | [x] |
| CA68-10 | Handoff finale: **READY FOR PLANNING REVIEW**, non READY FOR EXECUTION. | [x] |

## File letti

### iOS documentazione

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-063-supabase-production-safe-sync-orchestrator-planning-ios.md`
- `docs/TASKS/TASK-064-supabase-sync-events-outbox-sending-stale-recovery-ios.md`
- `docs/TASKS/TASK-065-supabase-manual-sync-coordinator-dryrun-ios.md`
- `docs/TASKS/TASK-066-supabase-manual-sync-viewmodel-states-ios.md`
- `docs/TASKS/TASK-067-supabase-manual-sync-release-ui-optionsview-ios.md`

### iOS codice

- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinatorModels.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinating.swift`
- `iOSMerchandiseControl/SupabaseAuthViewModel.swift`
- `iOSMerchandiseControl/SupabaseAuthService.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/SupabasePullPreviewService.swift`
- `iOSMerchandiseControl/SupabasePullApplyService.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightModels.swift`
- `iOSMerchandiseControl/SupabaseManualPushService.swift`
- `iOSMerchandiseControl/SupabaseProductPricePushDryRunService.swift`
- `iOSMerchandiseControl/SupabaseProductPriceManualPushService.swift`
- `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineReader.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineWriter.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineModels.swift`
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift`
- `iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift`
- `iOSMerchandiseControl/SyncEventOutboxDrainService.swift`
- `iOSMerchandiseControl/SyncEventRecording.swift`
- `iOSMerchandiseControl/SupabaseSyncEventLiveRecorder.swift`
- `iOSMerchandiseControl/SupabaseSyncEventRPCTransport.swift`

### iOS test rilevanti

- `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualSyncCoordinatorTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualPushPreflightTests.swift`
- `iOSMerchandiseControlTests/SupabaseManualPushServiceTests.swift`
- `iOSMerchandiseControlTests/SupabaseProductPricePushDryRunServiceTests.swift`
- `iOSMerchandiseControlTests/SupabaseProductPriceManualPushServiceTests.swift`
- `iOSMerchandiseControlTests/SupabaseProductPriceApplyServiceTests.swift`
- `iOSMerchandiseControlTests/SupabasePullPreviewPaginationTests.swift`
- `iOSMerchandiseControlTests/SupabasePullApplyServiceTests.swift`
- `iOSMerchandiseControlTests/SupabaseCatalogBaselineSwiftDataTests.swift`
- `iOSMerchandiseControlTests/SupabaseCatalogBaselinePreflightIntegrationTests.swift`
- `iOSMerchandiseControlTests/SupabaseCatalogBaselineWriterReaderTests.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxEnqueueServiceTests.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxDrainServiceTests.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxStateTests.swift`
- `iOSMerchandiseControlTests/SyncEventOutboxLocalStoreTests.swift`
- `iOSMerchandiseControlTests/SyncEventRecordingTests.swift`
- `iOSMerchandiseControlTests/SyncEventLiveRecorderTests.swift`

### Riferimenti Android/Supabase letti

- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/docs/TASKS/TASK-068-bulk-product-push-verifica-no-op-post-full-import.md`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/docs/TASKS/TASK-070-outbox-retry-head-of-line-logging-strutturato.md`
- `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView/docs/TASKS/TASK-071-backend-rpc-record-sync-event-payload-validation.md`
- `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql`

## Gap analysis

### 1. Stato attuale UI Release TASK-067

`OptionsView` espone una sezione Release "Sincronizzazione cloud" separata dalla card tecnica DEBUG outbox/drain.

La card Release:

- costruisce `SupabaseManualSyncViewModel` via `SupabaseManualSyncReleaseFactory`;
- osserva `SupabaseAuthViewModel` per mostrare subito "Serve accedere" quando non esiste una sessione attiva;
- disabilita la CTA durante transizioni auth o run in corso;
- se manca auth chiama `authViewModel.signInWithGoogle()`;
- se l'utente e' autenticato chiama `viewModel.startDryRunVerification()`;
- cancella la task UI su `onDisappear` e resetta stato su cambio account;
- non espone `SupabaseClient`, `.rpc`, `.from`, `.upsert`, outbox/drain/sync_events o dettagli payload nella surface Release;
- non mostra `confirmationDialog` per la run Release: oggi non esistono mutation live in quella card.

**Risposta Q1:** si', la UI TASK-067 puo' e deve restare collegata al dry-run finche' non esiste un live wiring sicuro. Il dry-run e' un comportamento intenzionale, non un bug da "sbloccare" con wiring remoto diretto.

### 2. Stato attuale `SupabaseManualSyncViewModel`

`SupabaseManualSyncViewModel` espone:

- `presentationKind`
- `title`
- `subtitle`
- `primaryActionTitle`
- `isRunning`
- `canStart`
- `cannotStartConcurrently`
- `pendingConfirmation` / `shouldShowConfirmation` entrambi `false`
- `lastSummary`
- `lastUserMessage`
- `privacySafeAggregatesSnapshot`
- `startDryRunVerification()`
- `start(with:)`
- `resetPresentationToIdleReady()`

Il ViewModel:

- dipende solo da `SupabaseManualSyncCoordinating`;
- non usa `SupabaseClient` o rete diretta;
- traduce `SupabaseManualSyncRunSummary.finalState` in stati user-facing;
- impedisce doppio start locale tramite `isRunning`;
- non contiene ancora una vera macchina di conferma per mutation remote;
- non distingue ancora una run "live preflight read-only" da "dryRun" a livello UX pubblico.

### 3. Stato attuale `SupabaseManualSyncCoordinator` dry-run

`SupabaseManualSyncCoordinator` oggi e':

- `@MainActor`;
- iniettato tramite protocolli `SupabaseManualSyncAuthGateProviding`, `SupabaseManualSyncBaselineGateProviding`, `SupabaseManualSyncLocalPendingProviding`, `SupabaseManualSyncDryRunPhaseSimulating`;
- senza `SupabaseClient`, `.rpc`, `.from`, `.upsert`;
- con run lock in-memory (`activeRunSessionID`);
- esecutivo solo in `.dryRun`;
- `.guidedManual`, `.debugDiagnostics`, `.automatic` ritornano summary "modalita' non disponibile" senza chiamare dipendenze.

Pipeline dry-run attuale:

1. `authCheck`
2. `baselineCheck`
3. `localPendingCheck`
4. se zero pending: skip downstream e summary "Tutto aggiornato"
5. `remotePreview`
6. `userConfirmation` simulata
7. `catalogPush` simulata se `pendingCatalogChangeCount > 0`
8. `productPricePush` simulata se `pendingPriceChangeCount > 0`
9. `pendingEventsFlush` simulata se `pendingQueuedCloudOperationCount > 0`
10. `finalRefresh` simulata
11. `summary`

La factory Release reale oggi cabla:

- auth gate live locale (`SupabaseAuthViewModel.isSignedIn`);
- baseline gate locale (`SupabaseCatalogBaselineReader`);
- pending snapshot sempre zero;
- tutte le fasi downstream come simulatori `.completed`.

Risultato pratico: in Release, se auth e baseline sono validi, la run tende a concludere "Tutto aggiornato" perche' il pending snapshot e' volutamente vuoto.

## Inventario servizi live iOS

| Area | Componenti esistenti | Stato protocolli/fake | Scrive remoto? | Valutazione wiring |
|------|----------------------|-----------------------|----------------|--------------------|
| Auth/session | `SupabaseAuthService`, `SupabaseAuthViewModel` | Service concreto + VM gia' osservabile; factory usa VM come gate | OAuth/sign-out possono toccare auth remoto | **Gia' cablato come gate UI**; sicuro come precondizione, non come parte di sync dati. |
| Baseline/fingerprint | `SupabaseCatalogBaselineReader`, `SupabaseCatalogBaselineWriter`, modelli SwiftData baseline | Reader/Writer separati; test SwiftData presenti | No remoto; scrive SwiftData locale | Reader sicuro subito; Writer solo dopo full pull/apply o policy esplicita. |
| Pull preview | `SupabasePullPreviewService`, `SupabaseInventoryFetching`, `SupabaseInventoryService` | Protocollo fetcher gia' esiste; test pagination/diff | Read remoto Supabase | Candidato sicuro **dopo** preflight locale; read-only ma puo' essere lento/partial. |
| Pull apply locale | `SupabasePullApplyService` | Service puro con piani/guard; test apply | No remoto; scrive SwiftData locale | Non primo step: muta dati locali, richiede piano/confirmation e baseline policy. |
| Catalog preflight | `SupabaseManualPushPreflightService`, `ManualPushPlan` | Service puro/testato | No remoto | Sicuro per conteggi read-only se estratto come adapter pending. |
| Catalog push live | `SupabaseManualPushService`, `SupabaseManualPushRemoteGateway`, `SupabaseManualPushRemoteClient` | Gateway protocol + fake nei test | Si', insert/update catalogo remoto; poi read-back | Non cablare subito: ha baseline writer implicito e rischio bulk/delta reale. |
| ProductPrice dry-run push | `SupabaseProductPricePushDryRunService`, `SupabaseProductPricePushDryRunRemoteFetching` | Protocollo fetcher + test | Read remoto dedupe | Candidato read-only successivo, ma non primo se si vuole zero remote call. |
| ProductPrice live push | `SupabaseProductPriceManualPushService`, `SupabaseProductPriceManualPushRemoteAccessing` | Protocollo remote + test | Si', insert `inventory_product_prices`; read-back | Scrittura separata, batch max 100, richiede snapshot dry-run e confirmation. |
| ProductPrice pull/apply | `SupabaseProductPriceApplyService`, preview/apply ProductPrice | Test dedicati | Preview read remoto; apply scrive SwiftData locale | Fuori primo wiring guided; utile in task separato ProductPrice-only. |
| Outbox enqueue | `SyncEventOutboxEnqueueService` | Service locale + test | No remoto; scrive SwiftData locale | Sicuro solo dopo result di push; attenzione `changed_count` 0...1000. |
| Outbox drain | `SyncEventOutboxDrainService` | Service locale con `SyncEventRecording`, recovery e reentrancy; test estesi | Si', RPC via recorder | Scrittura remota `sync_events`; non primo step Release, richiede confirmation e mapping partial. |
| Sync event recorder | `SyncEventRecording`, `SupabaseSyncEventLiveRecorder`, `SyncEventRPCTransport`, `SupabaseSyncEventRPCTransport` | Protocollo recorder + transport; dry-run recorder; test live recorder | Si', RPC `record_sync_event` | Adeguato come boundary; non farlo entrare nel coordinator direttamente. |
| Outbox counts | `SyncEventOutboxLocalStore.fetchCounts` | Store locale testato | No remoto | Candidato immediato per pending read-only via adapter. |

## Differenze e rischi Android/Supabase integrati

### Android TASK-068 PARTIAL

Android ha implementato bulk product push client-side, ma il task resta **PARTIAL** per validazione live del ciclo B/no-op. Per iOS questo impedisce di assumere che un catalog push massivo o una guided run con catalog push sia "safe enough" come prima slice.

Implicazione iOS: non cablare `SupabaseManualPushService.execute` come prima mutation della run guidata. Prima servono preflight, limiti, conferma, mapping partial e policy baseline esplicita.

### Android TASK-070 DONE

Il problema head-of-line retry e' stato trattato app-side su Android con logging privacy-safe. iOS ha gia' una soluzione analoga lato outbox:

- `SyncEventOutboxDrainService` usa fetch retryable owner-scoped e bounded;
- TASK-064 ha aggiunto recovery `sending` stale;
- test coprono reentrancy, cancellation, privacy-safe error, save failure e bounded limits.

Implicazione iOS: il drain e' tecnicamente piu' maturo di catalog/ProductPrice live dentro coordinator, ma resta una **scrittura remota RPC** e non deve diventare auto-flush Release senza conferma.

### Android TASK-071 / Supabase RPC

Il contratto locale Supabase `record_sync_event`:

- richiede auth (`auth.uid()`);
- ritorna **una riga** `public.sync_events`;
- accetta `domain` solo `catalog` / `prices`;
- accetta `event_type` solo `catalog_changed`, `prices_changed`, `catalog_tombstone`, `prices_tombstone`;
- accetta `changed_count` solo **0...1000**;
- richiede `metadata` oggetto JSON;
- permette `entity_ids` oggetto/null con chiavi allowlist e max 250 id per array;
- usa unique owner + `client_event_id` per idempotenza.

iOS e' allineato localmente:

- `SyncEventRecordValidator` blocca `changedCount` fuori **0...1000**;
- `SyncEventOutboxFactory` / state test coprono `1000` accettato e `1001` bloccato;
- `SyncEventOutboxEnqueueService` usa il validator prima di creare payload replay.

Rischio residuo: non esiste oggi una strategia iOS di split/coalescing per un singolo outcome con `changedCount > 1000`. Se una futura run live genera piu' di 1000 cambi catalogo/prezzi nello stesso evento, l'outbox andra' a `blockedContract` o la write RPC fallira'. Questo blocca live wiring completo e vieta full sync massiva dentro TASK-068.

## Cosa si puo' collegare ora

### Sicuro subito

1. **Auth gate Release**: gia' cablato via `SupabaseAuthViewModel`.
2. **Baseline gate locale**: gia' cablato via `SupabaseCatalogBaselineReader`.
3. **Local pending read-only adapter**:
   - catalog pending counts da `SupabaseManualPushPreflightService` + baseline corrente;
   - outbox pending/retryable counts da `SyncEventOutboxLocalStore.fetchCounts`;
   - ProductPrice "needs check" solo come conteggio locale conservativo oppure escluso dalla prima slice per evitare remote dedupe.
4. **No-op/preflight run**: nessuna remote write, nessuna `confirmationDialog` se i count sono zero.

### Sicuro ma da task separato read-only

1. **Pull preview read-only** con `SupabasePullPreviewService`:
   - usa protocol `SupabaseInventoryFetching`;
   - non muta dati remoti o locali;
   - puo' produrre `.partial` / source errors;
   - va budgetato e mappato in UX senza far partire push/apply automatici.
2. **ProductPrice push dry-run remote dedupe**:
   - e' read-only remoto;
   - ha budget e `unsafePartialRemoteDedupe`;
   - richiede mapping specifico per non promettere "sync completa".

### Non sicuro come primo wiring

1. **Catalog push live**
   - scrive remoto;
   - puo' produrre partial;
   - `SupabaseManualPushService` committa baseline locale dopo read-back, in conflitto con D63-07 se usato come "solo push incrementale" senza policy esplicita;
   - Android bulk resta PARTIAL.
2. **ProductPrice live push**
   - scrive `inventory_product_prices`;
   - richiede snapshot dry-run invariata e `confirmationDialog`;
   - puo' produrre unique conflict, verification mismatch, unknown read-back.
3. **Outbox flush dentro run**
   - scrive `sync_events` via RPC;
   - bounded/reentrant, ma soggetto al contratto `changed_count <= 1000`;
   - richiede conferma e partial UX.
4. **Pull apply locale**
   - muta SwiftData locale e puo' aggiornare baseline solo con policy full pull/apply;
   - non va concatenato automaticamente a push.

## Risposte operative alle domande

| Domanda | Risposta TASK-068 |
|---------|-------------------|
| UI Release TASK-067 puo' restare dry-run? | **Si'.** Deve restare dry-run finche' live wiring non e' reviewato e coperto da adapter/test. |
| Primo step live piu' sicuro? | **Auth + baseline + local pending read-only**, senza remote write e senza forced Supabase live calls. |
| Pull preview read-only come primo step? | Buon secondo step: read remoto, nessuna mutation, ma puo' essere lento/partial e va budgetato. |
| No-op/preflight? | Si', e' la micro-slice consigliata: rende il dry-run onesto sui pending locali. |
| Push catalogo live? | No come primo step: remote writes, partial, baseline bump implicito, Android bulk PARTIAL. |
| ProductPrice live? | Non primo; candidato futura write-domain singola con dataset piccolo e confirmation. |
| Flush outbox dentro guided run? | Non primo; possibile prima write non-domain-data dopo preflight, ma richiede confirmation e contratto RPC valido. |
| Quali servizi hanno protocolli/fake adeguati? | Coordinator, pull preview fetcher, manual push remote gateway, ProductPrice dry-run fetcher, ProductPrice manual push remote, SyncEventRecording/RPC transport. |
| Quali vanno estratti prima? | Local pending adapter, live phase executor adapter, error mapper coordinator-level, confirmation policy, outbox counts provider protocol. |
| Quale step genera scritture remote? | Catalog push, ProductPrice push, outbox drain/record RPC; auth sign-in/sign-out tocca auth remoto ma non sync dati. |
| Quale step richiede `confirmationDialog`? | Ogni step con write dati/remoto o local apply: catalog push, ProductPrice push, pendingEventsFlush, pull apply locale se incluso. |
| Quale step puo' produrre partial success? | Pull preview partial, catalog push partial, ProductPrice verification non exact, outbox drain partial, final refresh dopo mutation fallita. |
| Errori tecnici -> stati user-facing? | Auth -> sign-in; baseline -> riallinea; network/RLS temporaneo -> connectivity; contract/schema -> technical; partial -> partial; cancel -> cancelled. |
| Evitare doppio tap/reentrancy? | Tenere `isRunning` + coordinator run lock, introdurre lock owner/session scoped negli adapter live e rispettare lock drain. |
| Evitare baseline bump implicito post-push? | Non cablare catalog push live finche' `SupabaseManualPushService` baseline commit non e' gestito da policy/task separato. |
| Evitare pull -> push -> pull? | Nessun loop automatico; ogni direzione e' slice distinta con conferma e summary, `finalRefresh` solo aggregate privacy-safe. |
| Check/test prima di live run? | Build, XCTest coordinator/VM, adapter fake tests, static no direct SupabaseClient in coordinator/VM, localization/no-jargon, anti-scope, manual SIM solo se task futuro lo richiede. |

## Gap dry-run -> live wiring

1. **Pending snapshot reale assente:** la Release factory usa `SupabaseManualSyncReleasePendingSnapshotProvider` che ritorna sempre zero.
2. **`.guidedManual` non eseguibile:** il coordinator blocca `guidedManual` e `debugDiagnostics` come mode unavailable.
3. **No confirmation state:** ViewModel espone `pendingConfirmation`/`shouldShowConfirmation`, ma sono stub `false`.
4. **Nessun adapter live per phase executor:** catalog push, ProductPrice push, outbox flush e pull preview non sono mappati dietro dipendenze coordinator live.
5. **Error taxonomy non ancora collegata ai service error reali:** esistono error enum locali, ma manca un mapper unico verso `SupabaseManualSyncPhaseOutcome`.
6. **Baseline bump risk:** `SupabaseManualPushService` committa baseline dopo push+read-back; va isolato prima del wiring guided.
7. **RPC/event budget risk:** `changed_count > 1000` e payload budget impediscono eventi massivi; non esiste split iOS per event recording.
8. **Loop policy assente:** nessun contratto implementato per evitare pull->push->pull se si collegano preview e push nella stessa run.
9. **Local vs remote pending semantics non unificate:** catalog pending, price candidates e outbox counts hanno metriche diverse; serve aggregation privacy-safe.
10. **Test live non definiti:** esistono fake/unit robusti, ma non una matrice di smoke live controllato per la guided run.

## Primo micro-step consigliato

### Proposta TASK-069 testuale

**TASK-069 — Supabase manual sync live preflight read-only iOS**

Obiettivo: sostituire il pending snapshot zero della Release factory con un adapter **read-only locale** che calcola conteggi aggregati privacy-safe per:

- baseline/auth gate gia' esistenti;
- catalog preflight locale da `SupabaseManualPushPreflightService`;
- outbox local counts da `SyncEventOutboxLocalStore.fetchCounts`;
- ProductPrice solo come `excluded/deferred` o conteggio locale conservativo, senza remote dedupe nella prima slice.

Vincoli:

- nessuna write remota;
- nessuna write SwiftData oltre letture necessarie;
- nessuna `confirmationDialog`;
- nessun pull preview remoto automatico;
- nessuna modifica UI strutturale oltre eventuale copy/count gia' previsto dal ViewModel, se autorizzato nel task futuro;
- no backend/Android/SQL.

Motivazione: e' il passo piu' piccolo che rende la run Release meno fittizia senza introdurre rischio dati. Se i conteggi sono zero, la UI continua a dire "Tutto aggiornato"; se sono >0, il summary puo' indicare "ci sono modifiche da controllare" senza inviare nulla.

## Adapter design concettuale per TASK-069

*(Design **concettuale** — nessuna firma Swift, nessun codice in TASK-068.)*

Componenti concettuali per comporre uno **snapshot pending** unificato, tutti **sola lettura** rispetto al dominio sync/cloud:

- **`SupabaseManualSyncLocalPendingSnapshotProvider`**: ruolo orchestratore locale che raccoglie i contributi degli adapter sotto e produce un **`SupabaseManualSyncPendingSnapshot`** (o equivalente aggregato) **privacy-safe**; nessun accesso rete.
- **`SupabaseManualSyncCatalogPendingAdapter`**: calcolo **aggregati** «catalogo da rivedere» da fonti gia' note nel repo (es. preflight locale + baseline in lettura), senza eseguire push ne' `execute` live.
- **`SupabaseManualSyncOutboxPendingAdapter`**: soli **conteggi** locali owner/session-scoped dalla store outbox (es. pending, retryable), **senza** invocare drain/registrazione remota.
- **`SupabaseManualSyncProductPricePendingAdapter`**: **solo** se incluso in modo **deferred/conservativo** (es. conteggio locale o esplicitamente «escluso dalla prima slice»); **non** mescolare nella prima slice conteggio locale con dedupe/read remoto.
- **`SupabaseManualSyncPendingSnapshot`**: valore/struct concettuale portabile verso il coordinator/VM — **solo numeri/flag aggregati**, niente dettagli identificativi espansi in Release.

**Requisiti trasversali (review gate per TASK-069):**

- Comportamento **read-only** (nessuna mutazione intenzionale dei dati come effetto del calcolo snapshot; sole letture necessarie).
- **Nessun** uso di **`SupabaseClient`** dentro questi adapter.
- **Nessuna** chiamata a **`.rpc`**, **`.upsert`**, **`.insert`**, **`.update`**, **`.delete`** (API rete verso Supabase).
- **Nessuna** scrittura **baseline** (niente bump/commit fingerprint come effetto collaterale).
- Output **solo conteggi aggregati privacy-safe** (adeguati alla card Release, non diagnostica tecnica).
- **Fakeable / testabili** (implementazioni sostituibili in XCTest senza rete).

## UX temporanea e UX futura

**Oggi (post-TASK-067, pre-snapshot reale):**

- La Release puo' mostrare **«Tutto aggiornato»** perche' il provider pending in factory e' **volutamente zero / hardcoded**.
- Questa UX e' un **accettato temporaneo**: non attiva scritture, non invia dati, non espone superficie tecnica — coerente con **D68-02** e **D68-03**.

**Dopo TASK-069 (execution futura, non definita da questo file):**

- Lo stato deve diventare **piu' onesto**: pending calcolati da **dati locali reali** (adapter read-only).
- Se **pending locali > 0**, la UI **non** deve promettere sync/invio **completato**; messaggi in stile: **«Ci sono modifiche da controllare»**, CTA/sottotitoli tipo **«Controlla sincronizzazione»**, chiarezza **«Nessun invio automatico»** ove utile.
- In superficie **Release**, evitare gergo utente: *outbox*, *drain*, *sync_events*, *RPC*, *payload*, *retryable* — restano ammessi **solo** in contesti DEBUG/documentazione tecnica, non come copy della card principale.

**Limite semantico:** pending **locali** non implicano parita' con il cloud; serve copy che non prometta «allineamento definitivo» senza slice dedicate.

## Ordine micro-slice successive

| Ordine | Slice proposta | Tipo | Motivo | Stop condition |
|--------|----------------|------|--------|----------------|
| A | Live preflight read-only locale | STATIC/XCTest/BUILD | Cablare pending reali senza rete/write. | Qualunque mutazione remota richiesta -> stop. |
| B | Auth/baseline gating rafforzato + mapping errori | STATIC/XCTest | Stabilizzare stati UX e reset account/session. | Baseline writer richiesto -> task separato. |
| C | Pull preview read-only controllata | XCTest + eventuale SIM/manual | Prima chiamata Supabase data read-only; mappa `.partial`. | Preview lenta/partial non deve avviare apply/push. |
| D | Guided run con una sola write domain | XCTest + confirmation + manual piccolo | Scegliere **una** tra ProductPrice tiny push oppure outbox flush, non catalog full. | Se `changed_count > 1000`, verification mismatch o partial non mappato -> stop. |
| E | Outbox flush dentro guided run | XCTest + manual controllato | Usare service gia' hardenato, ma solo con confirmation e batch bounded. | Contract/schema/auth error -> surface technical/blocked, no retry loop. |
| F | Validazione live controllata dataset piccolo | SIM/MANUAL | Smoke end-to-end solo su dataset piccolo e privacy-safe. | Nessun bulk/full sync; fallimenti documentati, non workaround. |

**Nota:** catalog push live completo resta dopo A-C e dopo una decisione esplicita sulla baseline post-push. ProductPrice live puo' essere il primo data-write solo se limitato a snapshot piccolo, con dry-run verificato e `confirmationDialog`.

## Criteri di accettazione per futura execution read-only

| ID | Criterio futuro | Tipo verifica |
|----|-----------------|---------------|
| F68-01 | `SupabaseManualSyncReleaseFactory` usa un pending provider reale read-only invece di zero hardcoded. | STATIC/XCTest |
| F68-02 | Adapter pending non chiama `.insert`, `.update`, `.upsert`, `.delete`, `.rpc`. | STATIC |
| F68-03 | Catalog pending usa baseline reader + preflight locale, senza `SupabaseManualPushService.execute`. | XCTest/STATIC |
| F68-04 | Outbox pending usa count locali owner-scoped, senza drain. | XCTest |
| F68-05 | ProductPrice non esegue push live; eventuale remote dedupe resta fuori scope o read-only esplicito. | STATIC/XCTest |
| F68-06 | Zero pending -> downstream skipped e messaggio «Tutto aggiornato» solo come stato temporaneo accettato (**D68-03**), non come verita' finale. | XCTest |
| F68-07 | Pending >0 -> summary non dichiara write completata. | XCTest |
| F68-08 | Auth mancante e baseline mancante restano gate separati e user-facing. | XCTest |
| F68-09 | Doppio tap durante run non produce due snapshot o due downstream call. | XCTest |
| F68-10 | Nessuna baseline viene scritta/bumpata nel task read-only. | STATIC/XCTest |
| F68-11 | UI Release non espone jargon tecnico. | Localization/static |
| F68-12 | Build Debug/Release e regressioni TASK-065/066/067 passano. | BUILD/XCTest |
| F68-13 | Snapshot pending **owner/session-scoped**: cambio account o sessione invalida o isola i conteggi (coerente con gate auth esistenti). | XCTest / STATIC |
| F68-14 | Calcolo snapshot **cancellation-safe**: cancellazione durante preflight pending non riporta successo pieno ne' muta stato come «completato». | XCTest async |
| F68-15 | **Scansioni/query bounded**: preflight pending su dataset grandi resta limitato (batch/limit documentati o aggregazione), niente full table scan implosivo implicito. | STATIC / code review / XCTest parametri |
| F68-16 | **Nessuna mutazione SwiftData** oltre **letture** strettamente necessarie al calcolo aggregati. | STATIC / XCTest |
| F68-17 | **Nessuna modifica UI strutturale** (layout/nuove card/navigazione) nel task read-only; solo cose gia' previste dal ViewModel/copy se autorizzate nel task execution. | STATIC |
| F68-18 | Con **pending > 0**, **nessun** `confirmationDialog` (o equivalente conferma invio) viene attivato **nel** task read-only — la conferma resta riservata a slice con write. | XCTest |
| F68-19 | Verifica statica / guardrail: **nessun** percorso nel primo micro-step invoca **baseline writer** (`SupabaseCatalogBaselineWriter` o commit post-push). | STATIC / grep / XCTest integrazione factory |

## Matrice test futura

| ID | Scenario | Livello |
|----|----------|---------|
| T68-01 | Auth assente -> no baseline/pending/downstream, CTA sign-in. | XCTest VM/factory |
| T68-02 | Baseline missing/stale/account mismatch -> blocked realign, no pending downstream. | XCTest |
| T68-03 | Baseline valid + catalog preflight zero + outbox zero -> allUpToDate. | XCTest |
| T68-04 | Catalog preflight con candidate >0 -> counts aggregati, nessuna write. | XCTest |
| T68-05 | Outbox pending/retryable >0 -> counts aggregati, nessun drain. | XCTest |
| T68-06 | ProductPrice deferred -> non promettere push/sync prezzi. | XCTest |
| T68-07 | Read-only adapter source senza `.insert`, `.update`, `.upsert`, `.delete`, `.rpc`. | STATIC |
| T68-08 | Coordinator/VM/Release source senza `SupabaseClient` diretto. | STATIC |
| T68-09 | Reentrancy: doppio tap/call concurrent -> una run sola. | XCTest async |
| T68-10 | Cancellation durante pending snapshot -> `cancelled`, non success. | XCTest async |
| T68-11 | Pull preview read-only future: partial source errors -> UX partial/connectivity, no apply/push. | XCTest fake |
| T68-12 | ProductPrice write future: snapshot stale/unique conflict -> technical/connectivity/partial mappato. | XCTest |
| T68-13 | Outbox flush future: `blockedContract` per changed_count >1000 surfaced, no loop retry UI. | XCTest |
| T68-14 | Localizations IT/EN/ES/ZH-Hans complete e no jargon. | Localization tests |
| T68-15 | Manual SIM/live piccolo solo se task futuro lo richiede esplicitamente. | SIM/MANUAL |

## Anti-scope da ribadire nei task futuri

- Non trasformare la card Release in dashboard tecnica.
- Non mostrare outbox/drain/sync_events/RPC/payload/retryable in Release.
- Non cablare `SupabaseClient` direttamente nel coordinator, ViewModel o `OptionsView`.
- Non fare full sync massiva.
- Non inviare Product/ProductPrice in massa come primo live wiring.
- Non aggiornare baseline dopo solo push incrementale senza decisione separata.
- Non fare pull->push->pull nella stessa run.
- Non drenare outbox automaticamente fuori da un gesto utente e da una conferma.
- Non fare cleanup outbox per "sistemare" i contatori.
- Non cambiare SQL/RPC/RLS/schema.
- Non copiare pattern Android o Kotlin.

## Definition of Ready per TASK-069

Checklist proposta prima di **creare** il file task execution **TASK-069** e prima di **EXECUTION** (tutto soggetto a review TASK-068 + **override utente**):

- [ ] **TASK-068** — review planning **approvata** (esito review documentale coerente).
- [ ] Adapter **read-only** e ruoli concettuali (`…LocalPendingSnapshotProvider`, `…PendingSnapshot`, sotto-adapter catalog/outbox/price opzionale) **definiti nel planning** (questo file + eventuale integrazione TASK-063).
- [ ] Confine **no-write** (no remoto, no baseline writer, no flush coda) **confermato** per la prima slice.
- [ ] **Baseline writer** **escluso** dal primo micro-step.
- [ ] **ProductPrice live** **escluso** dal primo micro-step.
- [ ] **Pull preview remoto** **escluso** dalla prima slice obbligatoria.
- [ ] **Matrice test TASK-069** pronta (copertura STATIC/XCTest per adapter fake, reentrancy, cancel, scope sessione).
- [ ] **Anti-scope TASK-069** esplicito (no UI strutturale, no `confirmationDialog` con pending>0 nel read-only, no gergo Release).
- [ ] **Nessun file TASK-069** creato **prima** di override utente esplicito post-review.

## Planning Review Checklist

La review del planning TASK-068 deve verificare almeno:

- **Coerenza TASK-063 / D63 manual-first:** ordine gate, niente sync automatica, boundary coordinator, rischio baseline post-push trattato.
- **Coerenza TASK-067:** card Release resta non-diagnostica; dry-run accettabile fino a snapshot reale (**D68-02**); separazione da UI DEBUG.
- **Nessuna EXECUTION implicita:** nessuna frase che autorizzi Codex/Swift senza transizione PLANNING -> EXECUTION documentata e override utente.
- **Primo micro-step davvero read-only:** solo aggregati locali; **D68-01**, **D68-04**, **D68-05**, **D68-06** rispettati.
- **Nessun remote write** nel primo micro-step.
- **Nessun baseline bump** nel primo micro-step.
- **Nessun loop** pull -> push -> pull automatico nella stessa run.
- **Rischi Android TASK-068 / TASK-071** (bulk **PARTIAL**, `changed_count` 0...1000, validazione payload) integrati e collegati alle slice.
- **Copy Release:** nessun gergo tecnico obbligatorio in user-facing (**§ UX temporanea e UX futura**).
- **TASK-069 proposto** abbastanza **piccolo** (adapter + snapshot + test; niente write domain come prerequisito).

## Rischi rimasti

- **Baseline catalog push:** servizio live esistente aggiorna baseline dopo read-back; va separato o deciso prima di `guidedManual` con catalog write.
- **`changed_count > 1000`:** iOS blocca correttamente il contratto, ma manca split/coalescing; full/bulk event recording e' fuori scope.
- **ProductPrice live:** dry-run e push sono robusti ma separati dalla guided run; serve snapshot invariata + confirmation + dataset piccolo.
- **Outbox flush:** service maturo, ma la scrittura RPC resta soggetta a contratto backend e partial.
- **Pull preview:** read-only ma puo' essere partial o costosa; non deve attivare apply/push automaticamente.
- **UX:** `pendingConfirmation` e `shouldShowConfirmation` sono stub; qualunque mutation futura deve introdurre stato conferma testato.
- **Falso senso di «tutto aggiornato»:** finche' lo snapshot pending resta zero/hardcoded o non riflette il reale, l'utente puo' credere che non ci sia nulla da fare (**D68-03**); mitigazione = TASK-069 + copy onesto quando pending>0.
- **Performance su dataset grandi:** il preflight pending locale deve restare **bounded** e **aggregato** dove possibile (limiti espliciti, niente scansione illimitata).
- **Account switch / sessione:** lo snapshot pending deve essere **owner/session-scoped**; cambio utente non deve riusare conteggi stale.
- **Locale vs cloud:** pending **locale** non garantisce parita' con la realta' remota; la UX non deve implicare equivalenza.
- **ProductPrice nella prima slice:** rischio di **mescolare** conteggio locale e percorsi dedupe/read remoto; tenere ProductPrice **deferred** o solo locale conservativo (**D68-06**, adapter price opzionale).

## Handoff finale (storico pre-review)

- **Stato TASK-068:** **ACTIVE** / **PLANNING** *(invariato)*.
- **Responsabile attuale:** **Claude / Cursor Planner** *(review planning)*.
- **Ultimo aggiornamento documento:** rafforzamento planning task-only (decisioni D68, adapter concettuale, UX, DoR, checklist review, rischi/CA); **nessun** Swift, **nessun** `OptionsView`, **nessun** backend.
- **Esito:** **READY FOR PLANNING REVIEW** — documento di planning **completo per la review**.
- **NON READY FOR EXECUTION:** nessuna implementazione, nessun branch execution autorizzato da questo handoff; serve **review planning** e poi **override utente** esplicito per creare/promuovere **TASK-069**.
- **TASK-069:** **solo** proposta testuale nel task file; **non** creare `docs/TASKS/TASK-069*.md` da TASK-068.
- **Non DONE:** chiusura TASK-068 solo dopo review documentale e conferma utente su esito planning (policy progetto).
- **Prossimo passo consigliato:** reviewer (Claude) esegue **Planning Review Checklist**; dopo **APPROVED** e istruzioni utente, eventualmente creare **TASK-069** in un turno separato — **non** in questo task.
- **Nota post-review:** questo handoff e' stato consumato dalla review del 2026-05-07 22:25 -04; lo stato corrente del task e' documentato in **Review (Claude)** e **Chiusura**.

## Execution (Codex)

Non autorizzata in TASK-068.

## Fix (Codex)

Non autorizzato in TASK-068.

## Review (Claude)

### 2026-05-07 22:25 -04 — Planning review / APPROVED

Esito review: **APPROVED**.

Verifiche completate:

- TASK-068 e' effettivamente solo planning/gap analysis: nessun codice Swift introdotto e nessuna modifica applicativa autorizzata dal task.
- Il documento non autorizza execution implicita: l'handoff resta esplicitamente **READY FOR PLANNING REVIEW** / **NON READY FOR EXECUTION**.
- Le decisioni **D68-01...D68-10** sono coerenti con il boundary manual-first/read-only e con i rischi D63/Android/Supabase richiamati.
- L'adapter design concettuale per pending locali e' chiaro, piccolo e fakeable: catalog/outbox locali aggregati, ProductPrice deferred, nessun remote write.
- Rischi, anti-scope, criteri futuri e Definition of Ready per TASK-069 sono completi per una micro-slice successiva.
- Il fatto che TASK-069 sia stato avviato tramite **user override separato** e' documentato senza trasformare TASK-068 in execution.

Conclusione: TASK-068 puo' essere chiuso come planning approvato, consumato e sbloccante per TASK-069.

## Chiusura

TASK-068 **DONE / Chiusura**.

- Chiusura come **planning/gap analysis**, non come codice.
- Nessun Swift, `OptionsView`, backend/Supabase/SQL o Android modificato da TASK-068.
- TASK-069 ha implementato la micro-slice proposta da TASK-068 con override utente separato.
- TASK-068 non resta task attivo e non autorizza ulteriori execution implicite.
