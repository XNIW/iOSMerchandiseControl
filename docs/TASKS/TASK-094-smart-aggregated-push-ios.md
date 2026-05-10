# TASK-094 — Push intelligente aggregato e resource-aware (iOS)

## Informazioni generali

- **Task ID:** TASK-094
- **Titolo:** Push intelligente aggregato e resource-aware *(iOS)*
- **File task:** `docs/TASKS/TASK-094-smart-aggregated-push-ios.md`
- **Stato:** **ACTIVE**
- **Fase attuale:** **REVIEW**
- **Responsabile attuale:** **Claude / Reviewer**
- **Data creazione:** 2026-05-09
- **Ultimo aggiornamento:** 2026-05-09 23:57 -0400 — EXECUTION completa Codex su override utente; build/test PASS; **READY FOR REVIEW**.
- **Ultimo agente che ha operato:** Codex / Executor

**Flag execution:** **`READY_FOR_REVIEW`** — l’utente ha autorizzato override esplicito da PLANNING a EXECUTION; Codex ha eseguito lettura repo-grounded, implementazione Swift/XCTest/localizzazioni e handoff review. **TASK-094 NON DONE** fino a review finale.

---

## Dipendenze

- **Dipende da:** **TASK-093 DONE / Chiusura — REVIEW PASS** (`docs/TASKS/TASK-093-local-change-accumulation-ios.md`) — accumulo locale bounded (`LocalPendingChange`), snapshot read-only Release, owner/session fail-closed, stato machine pending/superseded/blocked/staleBaseline/sent/acknowledged, MVP catalogo/ProductPrice/import confermato.
- **Sblocca (non aperti ora):** **TASK-095** (lifecycle/background); **TASK-096** (acceptance finale roadmap semi-auto).
- **Non aprire in questo task:** TASK-095, TASK-096.

---

## Contesto da TASK-093

TASK-093 ha introdotto un **dirty set / coda di intenzione** locale (**SwiftData** `LocalPendingChange` + accumulator + snapshot provider) **senza** push aggregato né drain/apply automatici. Il consumatore definito per uso futuro è **TASK-094**: snapshot bounded, invarianti auth/owner/baseline da **ricalcolare prima di push**, niente invio mentre lo snapshot segnala stati non inviabili (es. bloccati, baseline stale dove applicabile), derivazione payload da modelli locale al momento del piano di invio (non dump massivi).

---

## Obiettivo

Definire (in planning poi in execution **solo dopo override**) come l’app iOS deve **consumare** il pending locale accumulato da TASK-093 e **trasformarlo** in **invii verso Supabase** in modo:

- **aggregato / batch bounded**,
- **coerente col contratto** esistente (limiti `changed_count`, idempotenza, owner-scoping),
- **resource-aware**: niente N+1 inutile, niente spam messaggi,
- **con controllo utente** sulle mutazioni rischiose dove gia’ richiesto dalla Release,
- senza introduzione di **sync automatica continua**.

Fonte nominale obiettivo (non execution): MASTER-PLAN backlog riga TASK-094 — «Invio locale → Supabase con batching bounded, coalescing, retry controllato, backoff/cooldown, owner/session recheck, stale baseline guard, ProductPrice dedupe/idempotenza, no N+1, no spam messaggi».

---

## Scope *(pianificato — soggetto a planning review su codice)*

Operativamente (da precisare dopo lettura repo in **futura execution** autorizzata):

- **Ingresso**: consumo controllato dello **snapshot/API consumer** da TASK-093 (pending inviabile vs blocked/stale/capped secondo policy gia’ documentate).
- **Piano push**: trasformazione in uno o piu’ **batch remoti sicuri**, rispettando cap/contratto (incluso **`changed_count` 0…1000** dove rilevante) e chiavi logiche catalogo/ProductPrice note dalla catena TASK-071 / TASK-080+ / TASK-088.
- **Guards**: ricontrollo **auth/session/owner**, **stale baseline** / conflict policy coerente con TASK-082+ e Release esistenti, **retry controllato** e **cooldown/backoff** a livello di orchestrazione UX (non worker permanente — vedi Non incluso).
- **Collegamento telemetry**: decidere esplicitamente se e come l’aggregato si integra con **`sync_events`** / outbox enqueue gia’ presenti (solo **analisi/documentazione ora** — niente write live in planning).

---

## Non incluso

Come da backlog MASTER TASK-094 e dagli incarichi progetto consolidati):

- **Realtime**, **worker permanente**, **polling aggressivo**, **Timer** di sync continua.
- Invio **a ogni singola battitura** o pending su stato non confermato.
- Merge conflitti **avanzati campo-per-campo** *oltre quanto già stabilito* dalla pipeline Release/Task precedenti *(non inventare UX complessa ora)*.
- **TASK-095** (lifecycle/background policy) e **TASK-096** (acceptance finale).
- **Kotlin/Android**, **migration/RLS/SQL runtime**, **`project.pbxproj`**: non modificati. `Localizable.strings` modificato solo per la CTA primaria richiesta.

---

## Fonti da leggere in futura execution

Da leggere quando (e solo se) la fase passa a **EXECUTION** con handoff utente:

- **Pending locale TASK-093:** `LocalPendingChange.swift` *(e test associati TASK-093)* — snapshot provider / accumulator / stato machine / cap.
- **Release / sync manuale:** `SupabaseManualSyncViewModel.swift`, `SupabaseManualSyncCoordinator.swift`, `SupabaseManualSyncCoordinatorModels.swift`, `SupabaseManualSyncReleaseFactory.swift`, factory/presenter legati a Release.
- **Push esistenti:** `SupabaseManualPushService.swift`, `SupabaseManualPushPreflightService.swift`, servizi ProductPrice push/apply pertinenti TASK-050…088.
- **Outbox eventi:** `SyncEventOutbox*.swift`, `SyncEventRecording.swift`, `SupabaseSyncEventLiveRecorder*` se presenti — rapporto enqueue vs dirty push aggregato.

---

## Stato attuale iOS previsto da verificare *(ipotesi — audit in EXECUTION)*

- Esiste **manual push catalogo/ProductPrice guidato** e **preflight**: TASK-094 deve **agganciarsi** senza rotture; non assumere rewrite totale prima di lettura file.
- **LocalPendingChange** e’ la **fonte intenzionale** delle modifiche locali da proporre come batch dopo TASK-093; stati blocked/stale/capped limitano cosa può essere offerto allo user come invio sicuro.

---

## Riferimento Android *(solo fonte funzionale)*

Riprendere dall’analisi progetto e dal backlog storico gli schemi di **dirty set / batch / head-of-line / retry** dove documentati (**TASK-045 / TASK-068 / TASK-070 area** nei testi task), **solo** come ispirazione — niente porting WorkManager pattern.

---

## Riferimento Supabase *(solo read-only, se pertinente in planning execution)*

- Tabelle catalogo con `owner_user_id`, **`updated_at`**, tombstone (**TASK-082**, **TASK-086**).
- **`inventory_product_prices`** e identità (**TASK-050+**, **TASK-071**, **TASK-088** area).
- **`sync_events`** / RPC **`record_sync_event`**: **`changed_count`**, **`entity_ids`**, **`metadata`**, **`client_event_id`** (**TASK-055…059**, TASK-071).

Nessuna **DDL/migration/live write** nella fase PLANNING init di questo file.

---

## Micro-slice proposte *(bozza — rifinire in planning review)*

| ID | Titolo sintetico | Output atteso prima di EXECUTION |
|----|------------------|------------------------------------|
| S94-A | Mappa ingressi/uscite | Grafico chiaro da snapshot TASK-093 verso piani remoti bounded; servizi Swift esistenti toccati. |
| S94-B | Politica batch + cap | Traduzione dei pending in uno o più batch con soglie `changed_count` e fallback split/fail-closed. |
| S94-C | Guards pre-push | Lista invarianti runtime (auth, owner, baseline/stale, blocked items) prima di mutations. |
| S94-D | ProductPrice aggregated | Dedupe/idempotenza in batch usando chiavi logical note (effective_at/type/remote refs). |
| S94-E | UX Release / conferma | Una CTA/coerenza con TASK-091/092/093 (**prima aggiorna dispositivo**, poi **invio modifiche locali**) — copy e stati *(Localizable solo se task execution lo autorizza)*. |
| S94-F | sync_events interplay | Decide se enqueue post-outcome resta analogo ai path manual push o richiede adattamenti documentati (no drift silenziosa). |

---

## Acceptance criteria futuri *(placeholder CA-T094-xx — numerazione da bloccare in planning review)*

Da definire in revisione dopo lettura codice; **tipo bozza**:

- Esiste un piano push **bounded** che non eccede contratti **`changed_count`** / payload noti senza workaround non documentati.
- **Retry/backoff/cooldown** non introduce loop automatici né worker permanente; l’utente resta nel loop di controllo dove richiesto.
- **Owner/session/baseline**: preflight fail-closed se snapshot TASK-093 o guard Release lo richiedono.
- **ProductPrice**: dedupe/idempotenza in batch compatibile con identità TASK-088 o documenta gap motivato + follow-up bloccante.
- **Telemetria / outbox**: decisione registrata — niente doppio “successo dichiarato” se outbox enqueue fallisce.
- **Regressioni Release**: percorsi manuali esistenti restano comportamentalmente sicuri dove non modificati dall’implementazione TASK-094.
- **Privacy**: logging/messaggi restano aggregated come policy TASK-093/091.

Numerazione **`CA-T094-01…`** da assegnare **solo dopo** **`NEEDS_PLANNING_REVIEW` risolta** nel file task corrente.

---

## Rischi *(R94-xx — bozza)*

- **R94-01:** Duplicazione di verità fra **dirty local store** (**LocalPendingChange**) e **outbox sync_events**.
- **R94-02:** Batch troppo grande / timeout rete → failure parziali e stato locale incoerente se non transactional boundary chiara **lato UX e persistenza**.
- **R94-03:** **`staleBaseline`** / stale remote non gestiti prima del push aggregato → rischio overwrite.
- **R94-04:** UX sovraccarico con TASK-092 semi-auto + TASK-094 CTA (**rumore/confusione priorità)**.
- **R94-05:** Divergenza da semantica Supabase (**RLS**, **tombstone**, **unique**) se batch costruisce payload senza gli stessi guard del push manuale attuale.

---

## Go / No-Go per futura EXECUTION

**Go** solo dopo:

1. Risoluzione esplicita del flag **`NEEDS_PLANNING_REVIEW`** in questo file (scope + CA numerati + handoff EXECUTION chiaro).
2. Elenco servizi/files iOS confermato dopo lettura codice (**S94-A**) senza inventare API nuove pubbliche senza autorizzazione.
3. Decisione su **dual-write telemetry** (pending → push → enqueue outbox vs altro), coerente con TASK-057…081 obbligatori se applicabile.

**No-Go** se: rimangono aperti cap batch, interplay `sync_events`, o UX conferma aggregata vs push manuale per-perimetro senza una decisione tracciabile.

---

## Execution (Codex)

### Override operativo

- **Override utente ricevuto:** 2026-05-09 — autorizzata EXECUTION completa nonostante il file task fosse ancora in PLANNING / `NEEDS_PLANNING_REVIEW`.
- **Impatto processo:** Codex ha proceduto come executor/fixer, senza aprire TASK-095/TASK-096, mantenendo scope manuale/guidato e tracciando qui l’override.

### File controllati

- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-094-smart-aggregated-push-ios.md`
- `iOSMerchandiseControl/LocalPendingChange.swift`
- `iOSMerchandiseControl/SupabaseManualSyncLocalPendingSnapshotProvider.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualPushService.swift`
- `iOSMerchandiseControl/SupabaseManualPushPreflightService.swift`
- `iOSMerchandiseControl/SupabaseProductPricePushDryRunService.swift`
- `iOSMerchandiseControl/SupabaseProductPriceManualPushService.swift`
- `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift`
- `iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift`
- `iOSMerchandiseControl/SyncEventRecording.swift`
- Test collegati a manual sync, ProductPrice, TASK-093 pending snapshot, outbox/recording.

### File modificati

- `iOSMerchandiseControl/LocalPendingAggregatedPushPlanner.swift` *(nuovo)*
- `iOSMerchandiseControl/SupabaseManualSyncAggregatedPushOutboxProducer.swift` *(nuovo)*
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseProductPriceManualPushService.swift`
- `iOSMerchandiseControl/it.lproj/Localizable.strings`
- `iOSMerchandiseControl/en.lproj/Localizable.strings`
- `iOSMerchandiseControl/es.lproj/Localizable.strings`
- `iOSMerchandiseControl/zh-Hans.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/LocalPendingAggregatedPushPlannerTests.swift` *(nuovo)*
- `iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests.swift`
- `docs/TASKS/TASK-094-smart-aggregated-push-ios.md`
- `docs/MASTER-PLAN.md`

### Architettura implementata

- `LocalPendingChange` resta la fonte intenzionale primaria: il planner seleziona solo `status == .pending`; `blocked`, `staleBaseline`, cap store e `.sent` in retry/cooldown bloccano fail-closed.
- Aggiunto `LocalPendingAggregatedPushPlanner` con contratto `LocalPendingAggregatedPushPlan`: batch catalogo, batch ProductPrice, blockers, warnings, count privacy-safe, cap state, retry info, summary UI-ready, fingerprint/idempotency key deterministici.
- Il planner fa snapshot/count prima, poi fetch bounded: soft batch 250, hard cap 1000, ProductPrice limit allineato all’adapter esistente (100), fetch bulk SwiftData, dedupe ProductPrice tramite engine esistente.
- Payload non serializzato in `LocalPendingChange`: catalogo e ProductPrice derivano live dai modelli SwiftData correnti; cambi locali successivi invalidano il fingerprint.
- Reuse degli adapter Release: catalogo passa da `SupabaseManualPushPreflightService`/`SupabaseManualPushService`; ProductPrice passa da `SupabaseProductPricePushDryRunEngine`, `SupabaseProductPriceManualPushService`, identity reconciler e apply service invariato.
- State machine batch-scoped: `pending -> sent`, `sent/pending -> acknowledged`, `sent -> pending` retryable, `sent/pending -> blocked`, `sent/pending -> staleBaseline`.
- Nessuna transazione SwiftData tenuta durante network: prepare plan, mark sent, network, poi breve update locale.
- Telemetry/outbox aggregata: enqueue solo outcome aggregati; se write remoto verificato riesce ma enqueue outbox fallisce, la UI riceve follow-up tecnico invece di successo pieno silenzioso.
- UX Release aggiornata nel flusso esistente: CTA primaria di invio diventa “Invia modifiche locali” nelle 4 lingue; nessuna nuova schermata globale.

### Acceptance criteria verificati

- **CA-T094-01 — Fonte pending:** PASS — solo `.pending` inviabili; blocked/stale/capped/sent bloccanti.
- **CA-T094-02 — Planner aggregato:** PASS — piano separato e testabile con batch, blockers, warnings, counts, cap, retry, summary e fingerprint.
- **CA-T094-03 — Efficienza:** PASS — bounded fetch, soft/hard cap, bulk derivation, ProductPrice dedupe; nessun payload dump nel pending.
- **CA-T094-04 — Idempotenza:** PASS — fingerprint deterministici e client event id remoto/ProductPrice già riusato dagli adapter esistenti; retry utente non duplica successi verificati.
- **CA-T094-05 — Reuse Release adapters:** PASS — nessuna pipeline Supabase parallela per catalogo/ProductPrice.
- **CA-T094-06 — State machine locale:** PASS — transizioni batch-scoped implementate e testate.
- **CA-T094-07 — Telemetry/outbox:** PASS — outcome aggregati, `changed_count` basato sui confermati, follow-up tecnico se enqueue fallisce dopo write verificato.
- **CA-T094-08 — UX/UI:** PASS — review sheet esistente, singola CTA primaria, summary finale compatta tramite stati esistenti, no toast spam.
- **CA-T094-09 — Anti-scope:** PASS — nessun TASK-095/TASK-096, nessun background worker, Timer, polling aggressivo o realtime.

### Test eseguiti

- ✅ ESEGUITO — `xcodebuild build -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1'` — PASS, senza output/warning app.
- ✅ ESEGUITO — `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/LocalPendingAggregatedPushPlannerTests ...` — PASS.
- ✅ ESEGUITO — regressione mirata manual sync/ProductPrice/outbox/pull preview/TASK-093 pending snapshot — PASS.
- ✅ ESEGUITO — `xcodebuild test -quiet -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1'` — PASS, exit code 0.
- ✅ ESEGUITO — `git diff --check` — PASS.

### Note Supabase / simulatori

- Simulatore usato: **iPhone 17 Pro, iOS 26.4.1**.
- Supabase live/staging non usato: test e build hanno coperto adapter/fake/remoti test double; nessuna write live necessaria.
- Warning osservati solo in test target preesistenti `SyncEventOutboxDrainDebugViewModelTests` durante una run source-guard; non provenienti dal codice TASK-094. Build app finale pulita.

### Rischi residui

- Nessun blocker tecnico residuo rilevato.
- Follow-up candidate fuori scope: eventuale granularità UX “Invia N modifiche” dinamica; TASK-094 implementa la CTA sicura “Invia modifiche locali” senza introdurre nuove API/UI globali.

### Handoff post-execution

- **Stato:** ACTIVE
- **Fase attuale:** REVIEW
- **Responsabile attuale:** Claude / Reviewer
- **Esito:** **READY FOR REVIEW**
- **Note reviewer:** verificare in particolare policy `.sent` fail-closed, wrapper outbox per rispettare guardrail TASK-069/TASK-071, e semantica “successo con follow-up tecnico” quando telemetry enqueue fallisce dopo write verificato.
- **TASK-094 NON DONE** — da chiudere solo dopo review finale.

---

## Non incluso (anti-scope confermato execution)

- Nessun TASK-095/TASK-096 aperto.
- Nessun background worker, Timer, BGTask, realtime o polling aggressivo.
- Nessun backend/SQL/RLS/migration, nessun Android/Kotlin.
- Nessun `project.pbxproj` modificato.
