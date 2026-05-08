# TASK-078 — Pull apply locale guidato (Release)

## Informazioni generali

| Campo | Valore |
|-------|--------|
| **Task ID** | TASK-078 |
| **Titolo** | Pull apply locale guidato — da preview remota a SwiftData dopo conferma |
| **File task** | `docs/TASKS/TASK-078-supabase-mutative-sync-pull-apply-ios.md` |
| **Stato** | ACTIVE |
| **Fase attuale** | PLANNING |
| **Responsabile attuale** | Claude / Planner |
| **Data creazione** | 2026-05-08 |
| **Ultimo aggiornamento** | 2026-05-08 — avvio planning documentale (**solo markdown**). |
| **Ultimo agente** | Claude / Planner |

## Dipendenze

- **Dipende da:** TASK-077 **DONE / Chiusura** (sheet **Rivedi** UI-only, CTA futura disabilitata); TASK-073/074/076 come contesto Release read-only e audit; infra storica TASK-039/040/041+ per `SupabasePullApplyService`, baseline, ecc.
- **Sblocca:** percorsi UX successivi (**TASK-079** push catalogo ecc.) solo dopo EXECUTION pianificata e review; **TASK-079 non viene aperto in questo planning-only**.

---

## Obiettivo

Collegare la **preview remota Supabase** gia’ disponibile in Release (lettura/diff tramite servizi esistenti) a un **apply locale controllato su SwiftData** (`Product`, `Supplier`, `ProductCategory`), **solo dopo conferma utente esplicita**, con summary user-facing gia’ nel modello TASK-074 e sheet **Rivedi** TASK-077.

**Fuori scope di questo task (documentale ora, non esecuzione):** push remoto, drain outbox, ProductPrice sync completa (resta roadmap **TASK-080**), sync automatica, abilitazione `guidedManual` o `supportsGuidedManualSync = true` senza progettazione EXECUTION dedicata successiva approvata.

---

## Non incluso (perimetro PLANNING questo turno)

- Nessuno Swift/XCTest modificato ora.
- Nessun `project.pbxproj`, `Localizable`, SQL/migration Supabase, backend, Android modificato.
- Nessun smoke live; nessuna write SwiftData o Supabase reale.
- Nessun TASK-079 aperto; TASK-078 **non** marcato DONE.

---

## Criteri di accettazione (planning TASK-078 — verificabili documentalmente)

- [x] Inventario repo-grounded con classificazione **READY / PARTIAL / MISSING / BLOCKED / OUT OF SCOPE** per i componenti elencati nel brief utente.
- [x] Percorso tecnico dichiarato: **preview remota → conferma utente → apply locale**.
- [x] Micro-slice progressive per EXECUTION futura.
- [x] Test matrix pianificata (fake, VM, coordinator, SwiftData apply, cancellation, partial, recovery).
- [x] UX Release senza jargon (allineamento a TASK-063/076/077).

---

## Scopo operativo EXECUTION futura *(non autorizzato da questo file fino a override utente)*

Portare dalla card/opzioni Release un flusso: **Controlla cloud → Rivedi → Conferma → Applica modifiche (solo catalogo come per `SupabasePullApplyService` oggi) → Summary**, senza esporre all’utente termini tecnici vietati dalla governance Release.

---

## Planning (Claude)

### Obiettivo tecnico sintetizzato

1. Mantenere la preview remota **read-only** e **privacy-safe** in superficie UX.
2. Introdurre (in EXECuzione futura) un ponte sicuro tra **dato strutturato di preview applicabile** (oggi disponibile nei servizi ma non trattenuto nel ViewModel/coordinator dopo il run `.dryRun`) e **`SupabasePullApplyService`** gia’ esistente.
3. Imporre **gates** prima di prepare/apply: auth, baseline, preview completa (non partial), zero conflitti bloccanti, account guard dove gia’ previsto.

### Stato attuale iOS (repo-grounded)

| Area | Dove | Cosa succede oggi |
|------|------|-------------------|
| Coordinator | `SupabaseManualSyncCoordinator` | Solo `dryRun` eseguito; `guidedManual` / `debugDiagnostics` ⇒ summary “slice non disponibile”. Con `remotePreviewProvider` diverso da `nil`, dopo `.remotePreview` salta conferma/catalog push e termina con `finalizeRemotePreviewOnly` ⇒ **nessuna mutazione e nessuna fase apply catalogo.** |
| Fasi orchestrate | `SupabaseManualSyncPhase` | Nessuna fase nominata tipo `catalogPullApply`; push simulati post-`userConfirmation` solo nel ramo senza early-exit dopo preview live. |
| Release factory | `SupabaseManualSyncReleaseFactory` | Costruisce `SupabaseManualSyncPullPreviewAdapter` + simulator dry-run **senza** iniettare `SupabasePullApplyService`. |
| Preview adapter | `SupabaseManualSyncPullPreviewAdapter` | Chiama `SupabasePullPreviewService.generatePreview` ⇒ `SupabasePullPreviewViewState`; mapper riduce tutto in `SupabaseManualSyncRemotePreviewSummary` (**aggregati**). **Il `SyncPreview` completo non risale** al coordinator/ViewModel tramite questo path. |
| Pull preview engine | `SupabasePullPreviewService` | Fetch remoto + snapshot SwiftData locale + diff (`SupabasePullPreviewDiffEngine`). Supporta `.partial`/errori/fonti incomplete. |
| Apply engine | `SupabasePullApplyService` | **`prepareApplyPlan` / `apply(plan:)`** su `SyncPreview`: validazioni forti (`outcome == .success`, no sourceErrors, no conflicts, price history complete flag, stale/fingerprint insert/update, `rollback()` su save fallito). Scrittura **`Product`, `Supplier`, `ProductCategory`**. **`applyStockQuantity` opzionale (default false).** |
| ViewModel | `SupabaseManualSyncViewModel` | `capabilities.supportsGuidedManualSync` sempre **false** in Release; preferred run mode ⇒ `.dryRun` se preview remota disponibile; `pendingConfirmation` / `shouldShowConfirmation` stub **false**. Summary + sheet **Rivedi** derivano solo da aggregate + `countsSnapshot`. CTA **`Applica modifiche`** nella sheet (**`review.action.applyFuture`**) **`primaryActionIsEnabled: false`**. |
| UI | `OptionsView` | Sheet `SupabaseManualSyncReviewSheet` legata a `presentationState.reviewSheet`. |
| Cancelling | Adapter + Coordinator | `Task.checkCancellation()` in piu’ punti; adapter mappa cancellation in summary dedicata. |

### Riferimento Android / Supabase *(solo se serve in EXECuzione futura)*

- **Repo secondario consentito dall’utente:** `/Users/minxiang/Desktop/AndroidStudioProjects/MerchandiseControlSplitView` — confronto comportamentale (full sync, apply batch, UX conferma); **vietato porting 1:1**.
- **Supabase locale:** `/Users/minxiang/Desktop/MerchandiseControlSupabase` — **solo lettura** per schema/contratti se EXECuzione richiede parity; **vietato modificare migration/SQL nel perimetro TASK-078 planning-only**.

Il presente planning **non** ha eseguito letture fuori dall’IDE iOS; la tabella sopra è **solo** da sorgenti iOS.

### Differenze e gap trovati

1. **Troncamento preview → summary:** RUN Release non conserva il `SyncPreview` / `SupabasePullPreviewViewState` necessario a `prepareApplyPlan` dopo “Controlla cloud”.
2. **Coordinator incapace di guided apply catalogo:** nessuna fase dedicated; `guidedManual` bloccato; dry-run preview-only termina sempre prima di apply.
3. **Conferma utente non modellata** nel coordinator per il ramo preview live: dopo remote preview-only non c’e’ passaggio “confirmation gate” prima di hypothetical apply.
4. **Sheet TASK-077** comunica solo messaggi aggregated; footer indica futuro step; serve collegarlo a stato “pronto/confermare” solo quando guards apply passano.
5. **`SupabasePullApplyService`** rifuta preview **partial** / con **sourceErrors** / **priceHistoryIncomplete** / **conflicts** — UX deve spiegare in linguaggio naturale blocchi (**senza citare codici tecnici**) e non offrire conferma quando apply e’ vietato dai guard.

### Architettura proposta (alto livello, senza codice ora)

Due famiglie di design compatibili con minimo churn (scelta EXECuzione + review):

**Opzione A — ViewModel trattenzione sessione sicura (“staged preview”)**

- Dopo `.dryRun` con esito compatibile (**preview completa + segnali applicabili**), il sistema (futuro) mantiene in memoria **`SyncPreview`** (o view state minimale ricostruibile) **solo per la sessione** corrente, con **token di invalidazione** (timestamp/generatedAt confrontato con snapshots locali prima di prepare).
- **`SupabaseManualSyncViewModel`** espone stato presentazionale: `canConfirmApply`, `applyDisabledReasonKind` (**enum user-facing**, non raw `SupabasePullApplyDisabledReason`).
- Azione **`Conferma` / “Applica modifiche”** (stessa CTA rinominabile in EXECuzione con chiavi dedicate) ⇒ chiama **`prepareApplyPlan` → validation → apply** in **`ModelContext`** gia’ passato dalla factory (**nessun cambio pubblico progetto ora** ma ipotesi progettuale).

**Opzione B — Servizio facade “preview + staging” `@MainActor`**

- Wrapper unico sopra **`SupabasePullPreviewService`** + **`SupabasePullApplyService`** con **staging interno**, ViewModel osserva solo outcomes tipizzati.
- Riduce duplication ma introduce nuovo tipo (EXECuzione valutare footprint).

**Preferenza PLANNING TASK-078:** tendere **Opzione A** (meno artefatti, aggancia sheet e coordinator esistente) salvo REVIEW tecnica che mostri coupling eccessivo.

### UX flow futuro (Release)

Macro-flusso obbligatorio (allineamento TASK-076/077):

1. **Controlla cloud** — run read-only/network + diff (come oggi).
2. **Rivedi** — sheet TASK-077; segnali alto livello (**dal cloud al dispositivo**, **dal dispositivo al cloud**, **prezzi**, **attenzione**).
3. **Conferma** — controllo chiaro (**interstitiale** o dentro sheet secondo REVIEW EXECuzione; deve essere irreversibile come intenzione, non silent).
4. **Applica modifiche** — invoca stack apply solo se guards ok.
5. **Summary** — estendere TASK-074 summary post-apply (**conteggi insert/update opzionale in linguaggio naturale**, **no SyncPreview/raw** sulla card).

**Copy vietato sulla UI Release:** come TASK-077 — niente outbox/RPC/sync_events/baseline tecnici/etc.

### Stato macchina proposto (conceptuale Release)

Estendere gli stati logici della card (mapping non 1:1 con enum pubblici oggi; da rifinire in EXECuzione):

| Stato | CTA prevalente | Note |
|-------|----------------|------|
| `idle_ready` | Controlla cloud | |
| `running_preview` | (disabilitate / Cancel se supportato nella run) | |
| `preview_ok_no_changes` | Rivedi / OK | Nessun apply disponibile |
| `preview_ok_with_changes_applyable` | Rivedi + Conferma/Applica (abilitati dopo review) | Staging preview valid |
| `preview_partial_or_blocked` | Riprova / messaggio tecnico-soft | Nessun staging apply |
| `applying_local` | Indicatore determinato | Una sola run mutativa |
| `applied_success` | Summary + eventuale chiusura | |
| `apply_failed_retryable` | Riprova | |
| `apply_failed_non_retryable` | Aiuto generico | |
| `cancelled` | Riprova | Come oggi parzialmente |

**Nota:** `supportsGuidedManualSync` rimane progettato **false** finche’ governance non autorizza renaming semantico; eventuale abilitazione e’ fuori questo planning-only salvo decisone esplicita utente (**non richiesta ora**).

### Regole di sicurezza mutativa

1. **Nessuno apply senza conferma UI esplicita** dedicata allo step Apply (non bastano toggle impliciti).
2. **Ripetizione prepare immediatamente prima di apply**: confronto **`generatedAt`/fingerprint SwiftData locale** contro piano — se diverso ⇒ **errore “dati cambiati, ripeti il controllo”** (messaggio naturale).
3. **Bloccare apply su preview partial** (come codice PullApplyService oggi) — comunicare solo “controllo incompleto” / “servono aggiornamenti successivi”.
4. **Anti-concorrenza:** una sola operazione mutativa catalogo alla volta sulla stessa `ModelContext` superficie Release (riuso lock pattern coordinator `activeRunSessionID` o mutex VM — decisone EXECuzione).
5. **ProductPrice**: non promettere sincronizzazione prezzi storici in questo task; sheet gia’ prepara linguaggio dedicato (**TASK-080**).
6. **Baseline:** gate baseline valido gia’ in factory — apply deve richiedere stesso ordine (**non indebolire**) o documentare divergenza in Decisioni.

### Error handling / partial / cancellation / recovery

| Scenario | Comportamento atteso |
|----------|---------------------|
| **Cancel durante fetch preview** | Gia’ mappa a summary cancelled; dopo TASK-078: invalidare staging apply. |
| **Preview partial (reti/budget)** | No staging; UX “controllo incompleto”; suggerimento “Riprova”. |
| **Prepare fallisce (`SupabasePullApplyError`)** | Mappatura a headline + summary **non tecnici** (`disabledReason` → messaggio naturale solo lato VM). |
| **Save SwiftData fallisce** | Gia’ `rollback()` in servizio apply; surfacing “salvataggio non riuscito, dati non modificati” (+ retry se sicuro). |
| **Concurrency / second tap** | Rifiuto determinato senza corrupt state. |
| **Recover dopo crash UI** | Staging volatile = niente apply dopo relaunch senza nuovo preview (safe default). |

### Dati SwiftData coinvolti

- **`Product`**: insert/update campi remoti/metadata coerenti a `SyncPreviewProductApplyPayload`.
- **`Supplier` / `ProductCategory`**: create/resolve tramite lookup gia’ in `SupabasePullApplyService`.
- **`ProductPrice`**: fuori TASK-078 apply catalogo (**OUT OF SCOPE mutazioni** nel perimetro suggerito qui; resta roadmap **TASK-080**).
- **Baseline records** (**TASK-043+**): nessuna scrittura baseline automatica proposta dentro TASK-078 **senza** decisione TASK successivo (**potenziale FOLLOW-UP** post-apply sicuro).

### Servizi iOS da riusare

| Servizio/protocol | Classificazione | Nota |
|-------------------|-----------------|------|
| `SupabasePullPreviewService` | **READY** | Genera stato preview + diff |
| `SupabasePullApplyService` | **READY** (core) | Apply locale gia’ testato storico TASK-039 |
| `SwiftDataInventorySnapshotService` | **READY** | Snapshot per preview e fingerprint |
| `SupabaseManualSyncPullPreviewAdapter` | **PARTIAL** | Va esteso / affiancato se serve trattenimento `SyncPreview` o sibling API |
| `SupabaseManualSyncCoordinator` | **PARTIAL/MISSING** per apply | Serving solo dry-run/read-only nei path Release attuali |
| `SupabaseManualSyncViewModel` | **PARTIAL** | Presentation pronta; manca stato confirm/apply staging |
| `SupabaseManualSyncReleaseFactory` | **PARTIAL** | Deve eventualmente creare/fornire apply service + staging policy |

### Cose mancanti prima dell’EXECUTION

1. Decisione tecnica definitiva **A vs B** (staging VM vs facade).
2. **Contratto trattenzione** `SyncPreview` (lifecycle, threading `@MainActor`, invalidazione).
3. **Naming CTA/copy** dopo aver abilitato apply (**nuove chiavi `Localizable`** — vietate in questo turno planning-only; EXECuzione pianificara’ IT/EN/ES/zh-Hans coherent).
4. **Mapping errore tecnico → copy** (`SupabasePullApplyDisabledReason`, `SupabasePullApplyError` → enums presentazionali).
5. Aggiornamento **test statici RELEASE** (`SupabaseManualSyncReleaseUITests`) per nuovi rami (**non ora**).

### Inventario READY / PARTIAL / MISSING / BLOCKED / OUT OF SCOPE

| Componente | Stato |
|------------|-------|
| `SupabaseManualSyncCoordinator.run(dryRun)` + preview-only early finalize | **READY** (come read-mostly pipeline) |
| `SupabaseManualSyncCoordinator` pathway apply locale catalogo dopo preview | **MISSING** |
| `guidedManual` path reale coordinator | **BLOCKED** intentionalmente ora (vietato da brief abilitarlo in questo planning) |
| `SupabaseManualSyncViewModel` summary volatile TASK-074 | **READY** |
| `SupabaseManualSyncReviewSheetState` TASK-077 | **READY** shell; contenuto apply/staging **PARTIAL** |
| `SupabasePullPreviewService` | **READY** |
| `SupabasePullApplyService` validate/apply/stale | **READY** |
| Trattenzione `SyncPreview` in Release dopo preview | **MISSING** |
| ProductPrice storico/full sync Release | **OUT OF SCOPE TASK-078** |
| Push catalogo / drain outbox Release | **OUT OF SCOPE TASK-078→079/081** |
| Auto-sync, Timer, BGTask, Realtime, polling/worker | **OUT OF SCOPE / VIETATO** |

### Micro-slice future EXECuzione (progressive)

1. **S78-a — Staging + gates read-only**: VM/coordinator trattenzione `SyncPreview` (o surrogate) dopo preview **success** solo in memoria; esporre flags `applyEligible`/`applyBlocked`; **senza ancora tap apply** *(opzionale se si preferisce unica slice)*.
2. **S78-b — Confirm UX**: pulsante **`Applica modifiche`** abilitabile solo quando `prepareApplyPlan` **precheck** teorico PASS (dry prepare senza salvare?) — decidere se `prepare` gia’ alloca piani leggibili o serve `precheck*` separato EXECuzione.
3. **S78-c — Apply wired**: conferma ⇒ `prepareApplyPlan` + `apply` su `ModelContext` Release (**no push**).
4. **S78-d — Summary post-apply**: estendere `SupabaseManualSyncUserFacingSummary` / mapping per stato “aggiornato localmente”.
5. **S78-e — Hardening test + cancellation**: regressione XCTest/coordinator fake.

### Test plan pianificato (EXECuzione futura)

| Livello | Cosa coprire |
|---------|---------------|
| **Fake `SupabaseInventoryFetching`** | Preview partial/full, error di rete, cancellation |
| **ViewModel** | stati staged, conferma disabilitata se guard fail, reset dopo cancel |
| **Coordinator (se ancora centro)** | no doppio run, ordering auth/baseline/preview vs apply separation |
| **SwiftData in-memory** | apply happy path inserts/updates, duplicate barcode ⇒ block, rollback save fail |
| **Partial preview** | nessuno staging apply |
| **Stale plan** | modifica SwiftData dopo prepare ⇒ apply rifiuta / messaggio naturale |
| **Cancellation** durante prepare/apply | stato consistente |

### Anti-scope checklist (TASK-078)

- [ ] No `guidedManual` abilitato **senza task/override futuro**.
- [ ] No `supportsGuidedManualSync = true` nel planning-only.
- [ ] No push remoto/outbox drain.
- [ ] No ProductPrice storico/sync completa dentro slice TASK-078.
- [ ] No auto-sync/timer/BGTask/realtime/polling/worker.
- [ ] No SQL/backend/Android modificati nel task documentale ora.

### Rischi

- **Over-trust sugli aggregate:** senza staging `SyncPreview` completo si rischia UX “sei sicuro?” senza base applicativa ⇒ **staging obbligatorio**.
- **`prepareApplyPlan` costo:** su dataset grande su main thread ⇒ valutazione async / progress (TASK-085 performance).
- **Conflitto con modifiche pendenti outgoing:** utente ha pending local catalogo mentre applica inbound — serve messaggio naturale (**TASK-082** lungo periodo).

### Decisioni *(placeholder — compilare prima di EXECUTION)*

| # | Decisione | Stato |
|---|-----------|-------|
| D78-01 | Opzione A vs B staging | pendente EXECuzione/review |
| D78-02 | Usare sempre `dryRun` + side-channel apply VS introdurre fase/`guidedManual` dopo override | pendente (**guidedManual vietato ora**) |

---

### Handoff post-planning (finale questo turno)

- **READY FOR PLANNING REVIEW:** sì *(contenuto iniziale TASK-078; iterazioni successive da Claude dopo feedback utente/recensione).*  
- **NON READY FOR EXECUTION:** Codex **non** implementa prima di revisione confermata governance + override esplicito.

- **Prossima fase consigliata:** REVIEW documentale Claude / utente su questo file; poi eventuale raffinamento Decisioni/Micro-slice; **solo dopo** HANDOFF EXECUTION autorizzato.
- **Prossimo agente consigliato:** Claude / Reviewer (planning QA) → utente (**override EXECUTION**) → Codex quando esplicitamente permesso.
- **Prossima azione consigliata:** Leggere `TASK-078` § gap + micro-slice; approvare o modificare Decisioni prima di uno scratch branch Swift.

---

## Execution (Codex)

*(Vuoto — non autorizzato in questo turno PLANNING ONLY.)*

## Review / Fix / Chiusura

*(Vuoto — TASK-078 NON DONE.)*
