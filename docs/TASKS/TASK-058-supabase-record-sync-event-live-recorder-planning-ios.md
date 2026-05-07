# TASK-058: Supabase `sync_events` — **Slice F** iOS — recorder live isolato `record_sync_event`

> **USER OVERRIDE storico — TASK-058 PLANNING-ONLY / REFINEMENT:** turno precedente solo documentale, superato dall’override EXECUTION sotto. Restano validi i divieti su RPC live **`record_sync_event`**, **TASK-059**, SQL/Android/Supabase modificati dall’editor.

> **USER OVERRIDE — EXECUTION APPROVED (2026-05-07):** autorizzata **EXECUTION controllata solo Slice F**: recorder live isolato `record_sync_event` con mapper RPC puro e transport testabile/fake. Restano vietati: RPC live, Supabase live audit, live dataset validation, drain outbox, worker/timer/BGTask/Realtime, UI/`OptionsView`, `Localizable.strings`, mutazioni SwiftData/`ModelContext`, SQL/Supabase/Android, **TASK-059**. Il gate documentale locale sul clone `/Users/minxiang/Desktop/MerchandiseControlSupabase` deve essere completato e documentato prima di creare/modificare Swift.

## Informazioni generali *(metadata tracking)*
- **Task ID**: TASK-058
- **Titolo**: Supabase `sync_events` Slice F iOS — `record_sync_event` live recorder isolato (nessuna RPC live eseguita)
- **File task**: `docs/TASKS/TASK-058-supabase-record-sync-event-live-recorder-planning-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Utente / prossimo task da decidere
- **Data creazione**: 2026-05-06
- **Ultimo aggiornamento**: 2026-05-07 *(REVIEW+FIX Slice F completata; TASK-058 chiuso DONE solo per recorder live isolato `record_sync_event`. No RPC live/Supabase live/live dataset validation/drain/UI/SQL/Android; TASK-059 non aperto.)*
- **Ultimo agente che ha operato**: Codex / Reviewer+Fixer

## Dipendenze
- **Dipende da / contesto soddisfatto (iOS DONE salvo TASK-058)**:
  - **TASK-053** — **DONE**: read-only `sync_events`, DTO/decoder **`RemoteSyncEventRow`** object/array/campi extra.
  - **TASK-054** — **DONE**: UI DEBUG read-only diagnostica eventi (**fuori Slice F futura** — niente nuova UI).
  - **TASK-055** — **DONE** (**Slice C**): outbox locale SwiftData, state machine, factory/store (**integrazione recorder ↔ outbox = Slice G / task separato**).
  - **TASK-056** — **DONE** (**Slice D**): `SyncEventRecording`, `SyncEventRecordRequest`, `SyncEventRecordResult` / `SyncEventRecordError`, **`SyncEventRecordValidator`**, dry-run recorder, XCTest contract **senza network**.
  - **TASK-057** — **DONE** (**Slice E**): enqueue locale **`SyncEventOutboxEnqueueService`** da outcome terminali manual push/catalog/prices (**no RPC**).
- **TASK-052** — **BLOCKED / superseded by TASK-053** — **non DONE** — documento storico; **non** assumere roadmap esecutiva dalla sola TASK-052.
- **Android / backend (solo lettura / non modificare)**:
  - **TASK-068** — stato **PARTIAL** su sicurezza eventi bulk/no-op live: **non** assumere sicurezza piena massiva.
  - **TASK-070** — **DONE**: retry outbox **anti head-of-line** (**non** Slice F recorder).
  - **TASK-071** — mismatch documentato **`changed_count > 1000`** vs PayloadValidation / RPC.
  - **TASK-072** (o equivalente) — follow-up backend; finché irrisolto → iOS deve **fail-closed** su eventi massivi (vedi §5).
- **Supabase locale clone** `/Users/minxiang/Desktop/MerchandiseControlSupabase` (**solo audit documentale pianificato**): migration **`sync_events`**, RPC **`record_sync_event`**, RLS/grants, eventuale publication Realtime (**non assumere parity con live**).

## Scopo
Progettare e, dopo user override del 2026-05-07, implementare **solo Slice F**: gate schema/RPC locale, mapper request→RPC, transport fakeable, recorder live isolato `SyncEventRecording`, decoding risposta, mapping errori, policy **`changedCount > 1000`**, auth/session/config safety. **Questo task non esegue alcuna RPC live.**

## Non incluso *(anti-scope obbligatorio)*
Vedi anche §12 (**Anti-scope**). Dopo user override 2026-05-07, le sole patch Swift ammesse sono quelle Slice F documentate in **Execution**. Restano esclusi: RPC/Supabase **live**, live dataset validation, SQL/Android, drain/worker/timer/BGTask/Realtime, nuova UI, **`TASK-059`**, Slice G/H/I.

## Contesto §1 *(riassunto obbligatorio)*
| Area | Stato |
|------|--------|
| **Lettura `sync_events`** | iOS (**TASK-053**) legge cronologia/eventi remoti read-only + decoder tollerante. |
| **Diagnostica DEBUG** | (**TASK-054**) mostra diagnostica senza write — **Slice F pianificato = zero UI**. |
| **Outbox locale** | (**TASK-055**) fondazione persisted + stati (**TASK-056/057**) collegamento enqueue locale. |
| **Contract / validator / dry-run** | (**TASK-056**) **`SyncEventRecordValidator`** + fake recorder deterministico (**no `SupabaseClient`**). |
| **Producer enqueue locale** | (**TASK-057**) crea **`SyncEventOutboxEntry`** da outcome terminali — **transport remoto ancora assente**. |
| **Recorder live vero** | **Manca**: chiamata reale sicura gated a **`record_sync_event`** + gestione ambiente prod/staging/live non verificato. |
| **Android precedent** | Mismatch **`changed_count > 1000`**, **`PayloadValidation`**, redesign **compact / sync_events** — **TASK-072** o equivalente. |
| **Outbox Android** | **Anti head-of-line** (**TASK-070**) — pertinenza **worker/drain**, **non** il recorder trasporto isolato (**Slice F futura**). |
| **Supabase live ≠ clone locale** | Ogni parametro/drift RLS/deploy va **auditato** prima di EXECUTION futura (**gate §4**). |
| **Gate forti Slice F** | Obbligatori: readiness schema/RPC, limite **`changed_count`**, idempotenza, auth owner; senza conferme → **STOP** o solo mock-only nei task futuri. |

## Obiettivo Slice F §2 *(cosa questo planning deve decidere)*

### Pianificare (solo documentazione in TASK-058)
| Tema | Contenuto |
|------|-----------|
| **Recorder live `record_sync_event`** | Un’implementazione futura **`SyncEventRecording`** che usa **solo** trasport RPC PostgREST/Supabase **dopo gate** (**§4**). |
| **Audit schema/RPC** | **§4 Livello A** (file clone); **Livello B** (live read-only) solo con task/**override**; **Livello C** (RPC) solo EXECUTION Slice F dopo gate (**non** questo task). |
| **Request → payload RPC** | Mapper **puro**: `SyncEventRecordRequest` → dizionario/parametri RPC coerenti con firma confermata (nomi snake_case nel wire — da verificare al gate). |
| **Response decode** | Riuso policy **TASK-053/056**: **object**, **array**, **campi extra ignorati**, **multi-row/id mismatch** → `schema`/`contract` con XCTest (**§11**). |
| **Errori PostgREST/RPC** | Mappatura verso **`SyncEventRecordError`** (**§8**) + taxonomy coerente con **TASK-055/056**. |
| **Policy `changedCount > 1000`** | Default: **fail-closed pre-RPC contract** (**D58-03**); se backend non aggiorna il limite (**TASK-072**) → **nessun split automatico in Slice F** (task redesign separato). |
| **Auth / session / owner** | **`auth.uid()`** coerenza RLS (**D58-08**) — sessione **mancante/scaduta** → **`.auth`**, **nessuna** RPC; owner mismatch → **non** responsabilità del mapper puro (**contesto recorder**). |
| **No drain automatico** | Recorder = **solo** `record(...)` (**D58-04**); nessuna lettura coda outbox dentro Slice F (**§9**). |
| **No UI** | **D58-05** / §10. |
| **No background/realtime** | **D58-06** — niente Realtime subscriptions, BGTask, timer cron. |
| **Test futuri mock** | Fixture transport fittizio; **mai** dipendenza da **`SupabaseClient`** nei mapper/test helpers (**D58-07**) — client solo dentro file recorder live (**§11**). |
| **Criteria futura EXECUTION** | Gate §4 PASS + review planning **APPROVED** + **user override esplicito** separato (**§14**) — questo file resta **PLANNING** fino a quel momento. |

## Decisioni §3 *(architettura — tabella)*

| ID | Decisione |
|----|-----------|
| **D58-01** | **TASK-058 dopo user override 2026-05-07 include execution controllata solo Slice F** — **nessuna** RPC live né live validation; codice runtime ammesso solo mapper/recorder/transport isolati e test fake. |
| **D58-02** | **Slice F futura (execution)** può introdurre recorder live **`record_sync_event`** **solo dopo** checklist gate schema/RPC **§4** (o equivalentemente: execution mock-only **finché** gate irrisolto). |
| **D58-03** | Se **`changedCount > 1000`** rimane **non supportato/contrattato** dal backend (**TASK-071/072**), il recorder live **deve bloccare prima della RPC** (`.contract`). |
| **D58-04** | **Nessun drain outbox in Slice F** — il recorder live è **solo transport** `SyncEventRecording`; **non** processor/coda/worker. |
| **D58-05** | **Nessuna UI** in Slice F (**né** questo planning **né** execution futura consigliata). |
| **D58-06** | **Nessun Realtime / BGTask / background sync / timer cron** nella Slice F. |
| **D58-07** | **`SupabaseClient`** ammesso **solo** nella **futura** execution Slice F **e solo** dentro l’implementazione recorder live isolata — **vietato** in mapper/outbox/facade; nei test si preferisce protocollo/closure di trasporto **injectabile**, non `SupabaseClient` nei mapper né nelle utilities comuni. |
| **D58-08** | **Auth/session/owner**: sessione JWT valida richiesta prima di `.rpc`; **missing/expired** → **`.auth`**, zero RPC network. Owner da contesto **`auth.uid()`** coerenza RLS (**verificabile al gate**). |
| **D58-09** | Duplicate / risposta idempotente che riusa **`client_event_id`** uguale al request → **`recorded`** o **`noOp`** (success logico **`SyncEventRecordResult`**) — **mai** errore **`failed`** fittizio. |
| **D58-10** | Decodifica deve **riutilizzare** la tolleranza **object/array/extra fields** stabilita in **TASK-053/056** (`RemoteSyncEventRow` + envelope). |
| **D58-11** | Errori RPC devono essere mappati verso taxonomy **TASK-056** con integrazione outcome **plannedOutboxStatus** **TASK-055** (**solo pianificazione** finché Slice G non collega). |
| **D58-12** | **`Live validation vera`** (staging/prod probe con dataset autorizzato) richiede **task separato** o **override esplicito** — **fuori TASK-058** (cfr. **TASK-045** pattern). |

## Gate schema/RPC §4 *(checklist obbligatoria per futura EXECUTION)*

La futura EXECUTION deve **STOP** oppure rimanere **mock-only**, se anche **un punto** è **UNKNOWN** dopo audit documentale / accessi autorizzati.

### Tre livelli di audit / accesso *(A / B / C)*

| Livello | Contenuto | Autorizzazione |
|---------|-----------|----------------|
| **A — Audit clone locale Supabase** | Lettura **solo file** nel workspace clone (es. migration SQL, definizione RPC nel repo) — **nessuna** rete, **nessun** mutamento dati. | Consentito in **futura** planning/execution come baseline minima per mappare firma/limiti **noti dal clone**; **non** prova che il live coincida. |
| **B — Audit live read-only** | Verifiche **read-only** su ambiente deployed (metadata, firma funzione, presenza RPC, versioning) — **zero** INSERT/UPDATE/DELETE, **zero** RPC `record_sync_event` di prova salvo task/override dedicato che lo dichiari esplicitamente. | Richiede **task separato** o **user override esplicito** (cfr. **D58-12**). Se **non** eseguito o resta **UNKNOWN**, la futura execution Slice F resta **mock-only** oppure **STOP** finché non si chiude il gap. |
| **C — RPC live `record_sync_event`** | Chiamata reale al trasport PostgREST. | **Non** autorizzata da **TASK-058 planning**; richiede **futura EXECUTION** Slice F con **gate verdi** (**§4** completo dove applicabile), **review documentale/processo** adeguati e **override utente** per il codice. |

- [x] (**Livello A**) Letta migration locale tabella **`sync_events`** nel clone (**solo file**): `/Users/minxiang/Desktop/MerchandiseControlSupabase/supabase/migrations/20260424021936_task045_sync_events.sql`.
- [x] (**Livello A**) Letta firma funzione **`record_sync_event`** nel clone (parametri, tipi JSON, RETURNS).
- [x] **Firma RPC locale confermata**:
  `public.record_sync_event(p_domain text, p_event_type text, p_changed_count integer default 0, p_entity_ids jsonb default null, p_store_id uuid default null, p_source text default null, p_source_device_id text default null, p_batch_id uuid default null, p_client_event_id text default null, p_metadata jsonb default '{}'::jsonb) returns public.sync_events`.
- [x] **Nomi parametri confermati**:
  **`p_domain`**; **`p_event_type`**; **`p_changed_count`**; **`p_entity_ids`**; **`p_store_id`**; **`p_source`**; **`p_source_device_id`**; **`p_batch_id`**; **`p_client_event_id`**; **`p_metadata`**.
- [x] **Formato ritorno confermato dal clone locale**: `returns public.sync_events` con `return v_row`; client Slice F mantiene decode tollerante **object / array / campi extra ignorati** tramite `RemoteSyncEventRow` / `SyncEventRowsResponse`, e tratta risposte vuote/ambigue come **schema**.
- [x] **Limite `changed_count` confermato**: RPC locale consente **0…1000** e solleva SQLSTATE **`22023`** fuori range; Slice F blocca `changedCount > 1000` pre-transport come **`.contract`**.
- [x] **`client_event_id` confermato**: parametro opzionale `p_client_event_id`, colonna `client_event_id` persistita, indice unico parziale `(owner_user_id, client_event_id) where client_event_id is not null`, lunghezza massima 160; duplicate/idempotenza restituisce la riga esistente per stesso owner + client event id.
- [x] **RLS + grants confermati nel clone locale**: tabella `sync_events` con RLS enabled; policy `sync_events_select_owner` per `authenticated` su `owner_user_id = auth.uid()`; tabella con `grant select` a `authenticated`; funzione `security definer`, execute revocato da `public, anon, authenticated` e poi `grant execute` a `authenticated`.
- [x] **Owner confermato server-side**: `owner_user_id` deriva da `auth.uid()`; nessun parametro owner client.
- [x] **No audit live / no RPC live** in TASK-058: Livello B non eseguito, parity live resta **UNKNOWN**; Livello C non eseguito.
- [ ] (**Livello B**, se autorizzato in task/override separato) Confermare se **`record_sync_event`** **è deployato in Supabase live** / coerente col clone *(firma, grants, comportamento dichiarativo)* — **solo read-only**. Se **livello B** non viene eseguito o resta **UNKNOWN** ⇒ futura execution/drain resta **mock-only** o **STOP** dove serve.
- [ ] (**Livello C**) Nessuna RPC live in TASK-058: chiamate reali `record_sync_event` solo con task/override separato di live validation o drain.

### Slice F recorder (execution) vs live validation dataset *(non mescolare)*

- **Futura EXECUTION Slice F** può implementare il **recorder live isolato** (`SyncEventRecording` + transport) **solo** con **gate verdi** (**§4**, più **`## Definition of Ready — future Slice F Execution`** prima di **Handoff §14**) e **override** — **non** equivale a **live validation** su dataset reale.
- **Live validation** (dataset reale, cleanup, read-back operativo, chiamate dimostrative su dati veri, smoke end-to-end controllato) richiede **task separato** o **user override esplicito separato** (cfr. **D58-12**, pattern **TASK-045**).
- **Non** mescolare l’implementazione/recorder **Slice F** con **validation “Slice I”** (o equivalente futuro fuori-scope): la validazione dataset resta **perimetro dedicato**.

## Backend risk / TASK-072 §5
| Rischio | Gestione Slice F pianificata |
|-----------|-------------------------------|
| **TASK-071** classifica **`changed_count > 1000`** mismatch / `PayloadValidation` | Recorder live deve **fail-closed** pre-RPC (**D58-03**) — errore `.contract`. |
| **TASK-072** ancora irrisolto | iOS **non** invia eventi massivi; entry outbox **`blockedContract`** dalla enqueue **TASK-057** **non diventano** magicamente **`failedRetryable`** senza redesign (**Slice G**). |
| **Pre-validazione cliente** | Sempre **`SyncEventRecordValidator` TASK-056** prima RPC. |
| **Niente splitting automatico in Slice F** | Eventi voluminosi/compatti richiedono **task dedicato redesign** (**compact/sync_events**) — fuori questo planning. |
| **TASK-068 PARTIAL bulk safety** | Assumere **non** sicurezza piena sugli scenari bulk live fino a evidenza esplicita. |

## Recorder live — design futuro §6 *(file/strati probabili)*
| File / componente | Ruolo pianificato |
|-------------------|------------------|
| `SupabaseSyncEventLiveRecorder.swift` **oppure** `SyncEventRecordLiveRecorder.swift` | **Implementazione concreta** `SyncEventRecording` + **solo qui** uso Supabase Swift client / `.rpc(...)` dopo gate (**D58-07**). |
| `SyncEventRPCRequestMapper.swift` *(nome indicativo)* | **Funzione pura** / struct statica: `SyncEventRecordRequest` → `JSONObject` parametri RPC. **No `SupabaseClient`**. |
| `SupabaseSyncEventRPCDTOs.swift` | **Facoltativo**: solo se servono envelope separati (**evitare duplicazioni** già coperte da `RemoteSyncEventRow`). |
| `SyncEventLiveRecorderTests.swift` | XCTest con **transport mock**/fake (**no live**). **`SupabaseClient` assente dai test utilities** (**D58-07**) — injected protocol. |

**Regole architetturali future**
| Regola | Dettaglio |
|--------|-----------|
| **`SyncEventRecording`** | RIUSARE protocollo già pubblicato (**NON** biforcare tipo base). |
| **Validator** | **NON duplicare** — richiamare componente TASK-056. |
| Ordine esecuzione | **Validator → mapper → RPC**. |
| Mapper | Separato fisicamente / confine chiaro dalla layer transport. |
| SDK confine | **Supabase Swift** isolato nei file recorder live / thin adapter (**D58-07**). |
| Persistenza SwiftData | **No `ModelContext` / SwiftData mutations** dentro recorder (**D58-07** correlato layering). |
| **Transport astratto** | Preferire un protocollo (nome indicativo **`SyncEventRPCTransport`**) o **closure injectabile**: `mapper` + **fake transport** nei test; **`SupabaseClient`** **solo** nell’implementazione **concrete** del transport live (**D58-07**). |
| **Grep ARCH futuro** | Verificare assenza di **`SupabaseClient`** da: mapper RPC, **`SyncEventRecordValidator`**, outbox (**`SyncEventOutboxEntry`**, store, enqueue), utilities comuni XCTest (**solo** nel file/type concrete del live recorder o adapter sottile dedicato). |

## Config / Auth safety futura *(Slice F execution — pianificata)*

*(TASK-058 non implementa — solo contratto per execution-ready.)*

| Regola |
|--------|
| **Client/session**: la futura Slice F deve usare **solo** il **client/session provider già esistente** nell’app, **session-aware** (pattern **TASK-034 / TASK-038**), senza biforcazioni parallele non reviewate. |
| **Role**: **vietato** `service_role` / chiavi service per questo flusso. |
| **Segreti / log**: **vietato** leggere, stampare o loggare **JWT**, **anon key**, **refresh token**, query string sensibili, o **config raw** (`SupabaseConfig.plist` come blob o path reale in log). |
| **Sessione**: **missing** / **expired** → **`.auth`**, **zero RPC** (come **D58-08**). |
| **Config app** (`SupabaseConfig.plist`) | Se **missing** o **invalido**: preferibile trattarlo come problema **setup app / credenziali** → bucket **`.auth`** (o **`auth`/`configuration`** se in futuro si introduce un bucket dedicato in taxonomy). **`Schema` (`.schema`)** solo quando il problema riguarda **reale** mismatch **schema RPC/backend** / drift DDL (non configurazione locale assente). Se la taxonomy TASK-056 resta senza `configuration`, usare **`.auth` come default conservativo** per config mancante; **`.schema`** solo con motivazione esplicita (evitare di confondere **setup app** con **schema Supabase errato**). In ogni caso **zero RPC** finché non c’è config/sessione valida per il transport. |
| **Test**: solo **config/session fake** o fixture; **nessun** segreto reale nel bundle test o in CI. |

## Request / response policy §7
### Request (`SyncEventRecordRequest`)
| Regola |
|--------|
| Sempre **`SyncEventRecordValidator.validate`** (**TASK-056**) prima di costruzione transport. |
| **JSON bounded**: policy budget **TASK-056** (`entityIDs` / `metadata` separati — no liste massicce UUID/barcode / no raw JWT). |
| **No metadata non strutturato “raw dumps”**. |

### Response / decode
| Caso JSON | Risultato / errore pianificato |
|-----------|-------------------------------|
| **Object valid → `RemoteSyncEventRow`** | `.recorded(...)` quando nuova registrazione; `.noOp` se policy idempotent match (**D56/D58-09**) |
| **Array valid**, righe coerenti **`client_event_id == request`** | `.recorded` / `.noOp` coerenti |
| **`[]` array vuoto** *(zero righe decodificabili)* | **Default consigliato: `.schema`** (mai silent success). Se in EXECUTION si sceglie **`.contract`**, va **motivato nel codice/review** e coperto da **XCTest** dedicato. |
| **Multi-row** con `client_event_id` **mancante / null / diverso dal request / misto** | **Default consigliato: `.schema`**. Stessa eccezione **`.contract`**: solo se **motivata + testata**. |
| **Campi extra** | Ignorati (decode tolerant). |
| **Campo richiesto mancante dopo decode** | **`schema`** |

**Sintesi policy (meno ambigua per EXECUTION):** `[]` vuoto e righe multipli ambigue → **default `.schema`**; violazioni payload / `changed_count` esplicite da backend → **`.contract`**. Scostamenti dal default → documentati + test **§11**.

## Error mapping pianificato §8
| Origine | Bucket `SyncEventRecordError` |
|---------|-------------------------------|
| `401`, `403`, session missing/expired, RLS come auth denial | `.auth(...)` (**non RPC inviato** quando session absent). |
| **PGRST** / PostgREST: funzione o schema **mancante** (es. **`PGRST202`**, **`PGRST204`**, messaggi “function … does not exist”) | `.schema(...)` |
| `404`/drift dove non coperto da righe sopra ma indica mismatch shape deploy | `.schema(...)` |
| Decode **campo richiesto** dopo risposta (shape inattesa dopo HTTP 2xx) | `.schema(...)` |
| **HTTP 400** con corpo/signal **`PayloadValidation`** / **`22023`** / overflow `changed_count` coerente | `.contract(...)` |
| **`PayloadValidation`**, `22023`, overflow `changed_count` lato server (anche altro status se mappabile) | `.contract(...)` |
| **HTTP 429** / rate limit | **Default consigliato: `.network(...)` retryable.** Se in EXECUTION futura si sceglie **`.unknown(...)`**, va **motivato** nel codice/review e coperto da **XCTest** (**§11**, **T58-21**). |
| **HTTP 5xx** | `.network(...)` **retryable** (**drain** **Slice G** in futuro). |
| Offline / timeout / URLError transient | `.network(...)` (**retryabile** come **5xx** / **429** default). |
| **Cancellation** (annullamento `Task` Swift / utente) | **Non** **network retryable**: propagare **`CancellationError`** **oppure** esito dedicato **non-retryable** — fissare in EXECUTION + test **§11** (**T58-20**). |
| Success duplicato / idempotent | `.recorded` / `.noOp` — **NON** errore (**D58-09**) |
| Non classificato | `.unknown(...)` messaggi sanificati (**TASK-056 style**) |

*(Allineamento outbox statuses — vedi TASK-056 tab mapping verso **`blocked*` / `failedRetryable`** **solo quando** Slice G collega — **TASK-058 non implementa**)*

## Interazione outbox §9 *(confini Slice F futura vs Slice G futura)*

| Regola Slice F futura (execution pianificata) |
|------------------------------------------------|
| Il recorder **non legge** la coda outbox (`SyncEventOutboxLocalStore` / fetch queue / “retryable queue”). |
| Il recorder **non muta stati outbox** — **nemmeno dopo** `.recorded` / `.noOp` **success**. |
| **Non** incrementa **`attemptCount`**; **non** imposta **`sentAt`**; **non** promuove entry a **sent** / **failedRetryable** dal solo transport. |
| **Nessun backoff**; **nessuna retention/cleanup** outbox dal recorder. |
| Ammissibile uso recorder **solo** da XCTest / manual DI / wiring esplicito provvisorio (**non** prod path automatico finché **Slice G** non collega in modo sicuro). |
| **Slice G** (o task dedicato) sarà l’**unico** posto ove collegare **`SyncEventRecordResult` / `SyncEventRecordError`** del recorder agli **stati** e campi outbox (`sent`, retry, errori, timestamp, ecc.) — **TASK-058 non definisce** l’orchestrazione. |
| Nessun retry loop dentro Slice F (**no head-of-line** nel transport — competenza **TASK-070** lato worker/drain **iOS** quando esisterà in **Slice G**). |

## UI / UX §10 *(decisione)*
| Regola |
|--------|
| **TASK-058 planning — zero nuova UI** |
| Futura EXECUTION Slice F consigliata — **zero UI** |
| Nessuna nuova **`OptionsView` card**, nessuna CTA “invia eventi” |
| UX resta **invisibile / non esposta** senza anche **manual safe operation & drain readiness** (**Slice G**) |
| Possibile diagnostica/live validation separata ⇒ **TASK dedicato / override**, non questo file |

## Test futuri pianificati (XCTest) §11 *(non eseguiti ora)*
> **Nota globale:** usare **`SyncEventRPCTransport`** (o equivalente) **fake** + **`SyncEventRecording`**; **`SupabaseClient`** **solo** nel concrete live recorder/transport. **Mapper, validator, outbox, enqueue e test utilities** non devono **importare** né **referenziare** il **Supabase Swift SDK** — solo transport astratto + fake (**D58-07**, **§6**, **§12 grep**).

| # | Caso pianificato |
|---|------------------|
| T58-01 | Validator PASS → RPC mock **`record` invoked exactly once**. |
| T58-02 | `changedCount == 1001` → `.contract`, **ZERO** network calls. |
| T58-03 | Session **`nil`/missing token** → `.auth`, no RPC |
| T58-04 | Session scaduta / `isExpired` → `.auth`, no RPC |
| T58-05 | RPC response object → `.recorded` |
| T58-06 | RPC response array coherent → `.recorded` **or** `.noOp` (policy TASK-056) |
| T58-07 | Extra unknown JSON keys → tolerated / ignored decode |
| T58-08 | Empty array `[]` → **default `.schema`** (se `.contract`, motivato + test) |
| T58-09 | Multi-row con `client_event_id` assente/null/diverso/misto → **default `.schema`** |
| T58-10 | Simulate `401/403` mapping → `.auth` |
| T58-11 | Function missing/`404`/schema drift textual signals → `.schema` |
| T58-12 | `PayloadValidation` / `22023` → `.contract` |
| T58-13 | Offline/timeout mocked → `.network` |
| T58-14 | Duplicate idempotent success envelope → `.noOp` / `.recorded` |
| T58-15 | Nessun uso `ModelContext` / SwiftData nel recorder test path |
| T58-16 | Nessuna logica worker/drain/timer/Realtime |
| T58-17 | grep anti-scope prod: **zero** modifiche **`OptionsView`**, **zero nuove string UX** non autorizzata |
| T58-18 | `SupabaseConfig` **missing/invalid** (fixture) → **zero RPC**; **default `.auth`** (config/setup); **`.schema`** solo se motivazione = drift RPC/backend reale |
| T58-19 | Session expired → **zero RPC**, **`.auth`** |
| T58-20 | **Cancellation** durante `record` → **non** `.network` retryable (propagate cancel o errore non-retryable documentato) |
| T58-21 | HTTP **429** → **default `.network` retryable**; **`.unknown`** solo se motivato + test |
| T58-22 | HTTP **5xx** → **`.network`** retryable |
| T58-23 | Recorder **success** (`.recorded`/`.noOp`) → **nessuna mutazione** su `SyncEventOutboxEntry` / nessun `sentAt` / nessun `attemptCount` |
| T58-24 | **`grep` / review:** `SupabaseClient` e **`import`** (o uso equivalente) del **Supabase Swift SDK** solo nel **concrete** live recorder/transport — **vietati** mapper, validator, outbox/enqueue, test helpers condivisi; test solo **fake transport**, mai client reale |
| *(regressioni)* | Fixture transport separato dai puri decoding tests già TASK-056 |

## Anti-scope TASK-058 §12 *(vieti espliciti)*
Questo planning **vietato dal confine TASK-058** anche se idee correlate esistono in backlog storico (**TASK-052**):
| Vietato |
|---------|
| Qualsiasi EXECUTION Swift / nuovo file `.swift` prod |
| Build / compilazione / simulatore |
| Integrazione Xcode test target modifiche obbligatorie (solo pianificazione) |
| Chiamata **Supabase live** / JWT reale nei test automatizzati |
| RPC **`record_sync_event` live runtime** implementata |
| Modificare SQL migration / RPC / grants remoto (**Android/supabase prod**) |
| Modificare Android |
| Drain outbox processor / stato machine mutate via recorder |
| Worker / timer cron / **`BGTask` / BackgroundTasks** framework hooks |
| Realtime channels / publication subscribe |
| Qualsiasi nuova UI / `OptionsView` |
| Mutazioni SwiftData / `ModelContext` dal recorder |
| Creare / aprire **`TASK-059`** |
| Dataset live validation obbligatorio |
| Cleanup / retention / purge outbox |
| **Execution futura senza grep di confine `SupabaseClient` / import SDK** dove richiesto da **§6 / §11 / §12** |

## Criteri di accettazione *(contratto planning TASK-058)*
- [ ] Documento contiene le sezioni nominali (**Contesto**, **Obiettivo**, **D58**, **Gate §4** con A/B/C e distinzione recorder/validation, **Backend risk**, **§6**, **Config/Auth**, **§7**, **§8**, **§9**, **UI §10**, **Test §11**, **Anti-scope §12**) + **Review** con **Checklist — PLANNING REVIEW** + **Definition of Ready** + **Handoff §14**.
- [ ] Gate **§4** completo e collegato esplicitamente a **STOP / mock-only** se incertezza.
- [ ] Riferimenti incrociati **TASK-053/054/055/056/057** e rischi **TASK-068/070/071/072** presenti.
- [ ] Confermato: **nessuna** RPC live in TASK-058; **nessun** drain/UI/background.
- [ ] Confermato: **`TASK-059` non aperto** da questo task.
- [ ] **Handoff (§14)** indica **READY FOR PLANNING REVIEW** e **NON READY FOR EXECUTION**.

---

## Planning (Claude)

### Analisi
L’infrastruttura esistente copre **read path** + **outbox locale** + **validazione/dry-run** senza rete. Il gap verso full **observability operativa** è il **trasporto RPC reale** `record_sync_event`, non implementabile senza conferma schema/deploy + policy massivi (**TASK-071/072**). Android ha già modellato **retry queue** (**TASK-070**) separato dall’atto di **recording** (**TASK-068/071**) — parity iOS deve replicare la **separazione netta** (**D58-04**) per evitare side-effect head-of-line precoce (**non** nell’implementazione trasport Slice F pianificato).

Il protocollo **`SyncEventRecording`** definisce **`record(_:)` async** tipizzato — punto di aggancio unico (**D56 / D58** cohesion). Nel codice iOS è definito così (**file** `SyncEventRecording.swift`):

```swift
protocol SyncEventRecording: Sendable {
    func record(_ request: SyncEventRecordRequest) async throws -> SyncEventRecordResult
}
```

*(Altri tipi: `RemoteSyncEventRow`, `SyncEventRecordValidator` — TASK-053/056.)*

### Approccio proposto *(execution futura dopo override — non ora)*
| Step | Azione futura suggerita |
|------|------------------------|
| 1 | Eseguire gate **§4**: **Livello A** (clone file); **Livello B** (live read-only) solo con task/override; **Livello C** (RPC) solo dopo EXECUTION autorizzata. |
| 2 | Definire/aderire mapping tipi RPC esatti (PostgreSQL `uuid`/`text`/`jsonb`/`int`) dopo lettura DDL. |
| 3 | Implementare **mapper puro testabile** (**no client**). |
| 4 | Implementare adapter **`SyncEventRecording`** che invoca `.rpc(...)` usando sessione TASK-038. |
| 5 | XCTest con **injectable closure** / **`FakeSupabaseRPC`** (**nessun JWT reale**). |
| 6 | Nessun hook automatico a UI / worker — solo wiring manuale o TEST host finché Slice G non esiste. |

### File da modificare *(futuro — lista probabile dopo gate)*
| File pianificato | Motivo futuro |
|------------------|---------------|
| `SupabaseSyncEventLiveRecorder.swift` o `SyncEventRecordLiveRecorder.swift` | Transport live dopo gate (**D58-07**) |
| Mapper RPC puro (**nuovo** se necessità separazione lint moduli; **mai** dentro outbox enqueue) | Testabilità & anti-accoppiamento |
| **`iOSMerchandiseControlTests`/target XCTest**: `SyncEventLiveRecorderTests.swift` | Contract transport mock |
| *Non toccati in Slice F:* `SyncEventOutboxEnqueueService.swift` (solo **documentazione interplay §9**) | Evitare creeping processor logic |

*(Path Supabase configurazione/session — riuso pattern **TASK-034/038/053** quando execution sarà autorizzata — leggere quel codice prima di EXECUTION.)*

### Rischi identificati
| ID | Rischio | Mitigazione |
|----|---------|-------------|
| R58-01 | Drift parametri **`record_sync_event`** live vs clone | STOP / aggiorna mapping dopo diff verificabile (**§4**) |
| R58-02 | Overflow logico **`changed_count`** (>1000) non risolto server | Pre-RPC bloccare `.contract`; attendere TASK-072 / redesign |
| R58-03 | Accouple accidentale **`SupabaseClient`** al validator/outbox enqueue | Lint/grep ARCH + **single-file client confinement** (**D58-07**) |
| R58-04 | Decoder ambiguo envelope array vuoti | XCTest deterministici + policy esplicita §7 (**T58-08..09**) |
| R58-05 | Credenziali/session leak durante debug transport | Nessun logging raw JWT; sanitizer errore TASK-056 |
| R58-06 | Prematura UI “retry eventi manuali” prima drain safe | Nessuna UI (**§10**) |

### Rischi rimasti dopo TASK-058 *(tracking)*
- Parità definitive fra **staging/prod RPC** sono **UNKNOWN** senza TASK separato (**D58-12**).
- Nessuna garanzia `changed_count > 1000` finché TASK-072 o redesign non confermano comportamento (**R58-02**).
- Nessuna semantica completa sugli envelope **bulk compact** (**Android TASK-068 PARTIAL**) fino redesign separato (**§5**).

### Decisioni persistenti nella tabella superiore
Vedi §3 (**D58-01 … D58-12**) — stato **ATTIVE** nel contesto TASK-058 (nessuna obsoleta).

---

## Execution (Codex)

### Avvio EXECUTION Slice F — gate pre-codice *(2026-05-07)*

- **Override utente letto:** EXECUTION approvata solo per Slice F, recorder live isolato `record_sync_event`.
- **Gate locale eseguito:** letto clone Supabase locale `/Users/minxiang/Desktop/MerchandiseControlSupabase`, file `supabase/migrations/20260424021936_task045_sync_events.sql`; nessun audit live, nessuna RPC live.
- **Firma RPC locale confermata:**
  `public.record_sync_event(p_domain text, p_event_type text, p_changed_count integer default 0, p_entity_ids jsonb default null, p_store_id uuid default null, p_source text default null, p_source_device_id text default null, p_batch_id uuid default null, p_client_event_id text default null, p_metadata jsonb default '{}'::jsonb) returns public.sync_events`.
- **Nomi parametri confermati:** `p_domain`, `p_event_type`, `p_changed_count`, `p_entity_ids`, `p_store_id`, `p_source`, `p_source_device_id`, `p_batch_id`, `p_client_event_id`, `p_metadata`.
- **Tipo ritorno confermato:** `returns public.sync_events`, con `return v_row`; il clone locale conferma shape single row/object, con tolleranza client object/array già pianificata.
- **Limite `changed_count`:** RPC locale blocca `p_changed_count < 0 or p_changed_count > 1000` con SQLSTATE `22023`; Slice F deve bloccare `changedCount > 1000` pre-transport via validator.
- **`client_event_id`:** presente come parametro opzionale, colonna remota opzionale, indice unico parziale `(owner_user_id, client_event_id) where client_event_id is not null`; duplicate/idempotenza: la RPC seleziona e restituisce la riga esistente per stesso `owner_user_id + client_event_id`, anche in `unique_violation`.
- **RLS/grants visibili:** tabella `sync_events` con RLS enabled; policy `sync_events_select_owner` solo `select` per `authenticated` con `owner_user_id = auth.uid()`; privilegi tabella revocati ad `anon, authenticated` e poi `grant select` a `authenticated`; funzione `record_sync_event` `security definer`, execute revocato da `public, anon, authenticated` e poi `grant execute` a `authenticated`; owner impostato server-side da `auth.uid()`, nessun parametro owner client.
- **Nota confine:** migration aggiunge `sync_events` a `supabase_realtime` se publication presente, ma Slice F iOS non usa Realtime.
- **Obiettivo compreso:** implementare solo mapper RPC puro + transport fakeable + recorder `SyncEventRecording`, senza drain, UI, live dataset validation o mutazioni outbox/SwiftData.
- **File da modificare previsti:** `SyncEventRPCRequestMapper.swift`, `SupabaseSyncEventLiveRecorder.swift`, `SyncEventLiveRecorderTests.swift`, tracking TASK-058/MASTER-PLAN.
- **Piano minimo:** validator/session/config guard → mapper puro → transport astratto → decode response → mapping errori → XCTest fake transport + regressioni/check anti-scope.

### Handoff post-execution — REVIEW *(2026-05-07)*

- **Gate schema locale:** completato prima del codice sul clone `/Users/minxiang/Desktop/MerchandiseControlSupabase`; firma, parametri `p_*`, ritorno `public.sync_events`, limite `changed_count 0...1000`, `client_event_id` e grants/RLS documentati sopra. Nessun audit live, nessuna RPC live.
- **File implementati Slice F:**
  - `iOSMerchandiseControl/SyncEventRPCRequestMapper.swift` — mapper RPC puro, senza Supabase/network/SwiftData/UI.
  - `iOSMerchandiseControl/SupabaseSyncEventLiveRecorder.swift` — recorder isolato `SyncEventRecording` con validator, guard config/session, mapper, transport injected, decode response e mapping errori.
  - `iOSMerchandiseControl/SupabaseSyncEventRPCTransport.swift` — adapter concreto sottile Supabase; unico nuovo punto con `import Supabase` / `.rpc(`.
  - `iOSMerchandiseControlTests/SyncEventLiveRecorderTests.swift` — fake transport/session/config, nessuna rete.
  - `docs/TASKS/TASK-058-supabase-record-sync-event-live-recorder-planning-ios.md`, `docs/MASTER-PLAN.md` — tracking.
- **Implementato:** mapper con nomi parametri confermati dal gate locale; transport astratto fakeable; recorder live isolato con zero RPC se validator/config/session falliscono; `changedCount > 1000` → `.contract` pre-transport; response object/array/extra fields/empty/multi-row gestite; mapping errori auth/schema/contract/network/unknown; cancellation propagata; duplicate idempotent same `clientEventID` trattato come esito logico positivo.
- **Check eseguiti:**
  - ✅ **ESEGUITO — Build compila:** `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` → **BUILD SUCCEEDED**.
  - ✅ **ESEGUITO — XCTest Slice F:** `SyncEventLiveRecorderTests` → **TEST SUCCEEDED**.
  - ✅ **ESEGUITO — Regressione:** `SyncEventRecordingTests` → **TEST SUCCEEDED**.
  - ✅ **ESEGUITO — Regressione:** `SyncEventOutboxEnqueueServiceTests` → **TEST SUCCEEDED**.
  - ✅ **ESEGUITO — Regressione:** `SyncEventOutboxStateTests` → primo tentativo parallelo fallito per errore infrastrutturale `xcresult`/Diagnostics di Xcode; rerun sequenziale → **TEST SUCCEEDED**.
  - ✅ **ESEGUITO — Regressione:** `SyncEventOutboxLocalStoreTests` → **TEST SUCCEEDED**.
  - ✅ **ESEGUITO — Diff hygiene:** `git diff --check` + whitespace check no-index sui nuovi file Slice F/task → **PASS**.
  - ✅ **ESEGUITO — Coerenza planning/CA:** implementazione limitata a Slice F, nessun drain/UI/live validation.
  - ⚠️ **NON ESEGUIBILE con certezza assoluta — Nessun warning nuovo:** build PASS; non osservati warning Swift nei file Slice F. Xcode emette note/warning di metadata AppIntents già note nel progetto, non attribuibili a Slice F dal solo output.
  - ✅ **ESEGUITO — Grep anti-scope:** nel perimetro Slice F `SupabaseClient`/`.rpc(` confinati al concrete transport; mapper/validator/outbox/enqueue/test utilities senza Supabase; nessun `ModelContext`, `context.insert`, `context.save`, worker/timer/BGTask/Realtime, `OptionsView`, `Localizable`, SQL/Supabase/Android/TASK-059 nei file modificati per Slice F.
- **Conferme negative:** nessuna RPC live `record_sync_event`; nessuna Supabase live; nessuna validazione live su dataset reale; nessun drain outbox; nessuna lettura/mutazione queue; nessuna mutazione SwiftData/`ModelContext`; nessuna UI/`OptionsView`/`Localizable.strings`; nessun worker/timer/BGTask/Realtime; nessuna modifica SQL/Supabase/Android; nessun `service_role`; nessun TASK-059.
- **Rischi/limiti rimasti:** live validation su dataset reale, drain/outbox worker, aggancio Slice G/H/I e verifica parity live deployed restano fuori scope e richiedono task/override separato. Il concrete transport non è stato esercitato contro Supabase live per vincolo esplicito.
- **Stato finale:** TASK-058 **ACTIVE / REVIEW**, responsabile **Claude / Reviewer**, **non DONE**.

## Fix (Codex) — review tecnica Slice F

### 2026-05-07 — Fix mirati applicati

- `SyncEventRPCRequestMapper.swift`: aggiunto fail-closed pre-transport per contratto locale confermato `domain` / `eventType` (`catalog`, `prices`, `catalog_changed`, `prices_changed`, tombstone) e lunghezze `clientEventID` / `sourceDeviceID` a 160 caratteri.
- `SupabaseSyncEventLiveRecorder.swift`: `URLError.cancelled` ora propaga `CancellationError`, senza diventare `.network` retryable.
- `SupabaseSyncEventRPCTransport.swift`: il concrete transport propaga `URLError.cancelled` come `CancellationError` prima del mapping network.
- `SyncEventLiveRecorderTests.swift`: aggiunti test per mapping RPC completo (`p_entity_ids`, `p_metadata`), fail-closed del contratto locale, cancellazione via `URLError.cancelled` e sanitizzazione errori unknown.
- `TASK-058`: gate locale §4 reso esplicito con firma `p_*`, `p_store_id`, ritorno `public.sync_events`, limite `changed_count 0...1000`, `client_event_id`, RLS/grants, no audit/RPC live.

**Scope fix**
- Nessuna feature fuori Slice F.
- Nessuna RPC live `record_sync_event`, nessun Supabase live audit, nessuna live dataset validation.
- Nessun drain outbox, worker, timer, BGTask, Realtime, UI, `OptionsView`, `Localizable.strings`, mutazione SwiftData/`ModelContext`, SQL/Supabase/Android o TASK-059.

## Review (Claude)

### 2026-05-07 — APPROVED_FIXED_DIRECTLY / DONE *(user override)*

**Esito review**
- Review tecnica Slice F completata con esito **APPROVED_FIXED_DIRECTLY**: implementazione corretta dopo fix mirati, efficiente e coerente col planning TASK-058.
- TASK-058 marcato **DONE** solo per **Slice F record_sync_event isolated live recorder/transport**.
- Slice **G/H/I** restano future/out-of-scope; nessun TASK-059 aperto.

**Cosa e' stato controllato**
- Gate schema locale: file Supabase locale letto, firma `record_sync_event` documentata con parametri `p_domain`, `p_event_type`, `p_changed_count`, `p_entity_ids`, `p_store_id`, `p_source`, `p_source_device_id`, `p_batch_id`, `p_client_event_id`, `p_metadata`; ritorno `public.sync_events`; limite `changed_count 0...1000`; `client_event_id` persistito/idempotente; grants/RLS documentati; nessun audit live e nessuna RPC live.
- Scope / anti-scope: nessuna Supabase live, nessuna live dataset validation, nessun drain/worker/timer/BGTask/Realtime, nessuna UI/`OptionsView`/`Localizable.strings`, nessuna mutazione SwiftData/`ModelContext`, nessuna modifica SQL/Supabase/Android, nessun TASK-059.
- Confine SDK: nel perimetro Slice F, `SupabaseClient` / `import Supabase` / `.rpc(` confinati al concrete transport; mapper, validator, outbox/enqueue e test fake senza Supabase reale.
- Mapper RPC: puro, senza rete/Supabase/SwiftData/UI; mapping verso `p_*` coerente col gate locale; `p_store_id` resta `nil` perche' assente dal request iOS corrente; niente parametri inventati.
- Recorder live: `SyncEventRecording`, validator prima del transport, guard config/session, zero transport su contract/auth guard, cancellation non retryable network, niente outbox mutation.
- Transport: adapter Supabase sottile, unico punto `.rpc`, senza business/outbox logic e senza log segreti.
- Response/error policy: object/array/extra fields/empty/multi-row/error mapping coperti da test; 429/5xx/offline/timeout network retryable; 401/403/RLS auth; PGRST/schema drift schema; PayloadValidation/22023 contract; unknown sanitizzato.

**Comandi eseguiti e risultati reali**
- ✅ **ESEGUITO** — Build Debug iPhone 16e OS 26.2 -> **PASS / BUILD SUCCEEDED**.
- ✅ **ESEGUITO** — XCTest Slice F `SyncEventLiveRecorderTests` -> **PASS / TEST SUCCEEDED**, 23 test.
- ✅ **ESEGUITO** — Regressione `SyncEventRecordingTests` -> **PASS / TEST SUCCEEDED**, 29 test.
- ✅ **ESEGUITO** — Regressione `SyncEventOutboxEnqueueServiceTests` -> **PASS / TEST SUCCEEDED**, 23 test.
- ✅ **ESEGUITO** — Regressione `SyncEventOutboxStateTests` -> **PASS / TEST SUCCEEDED**, 20 test.
- ✅ **ESEGUITO** — Regressione `SyncEventOutboxLocalStoreTests` -> **PASS / TEST SUCCEEDED**, 5 test.
- ✅ **ESEGUITO** — `git diff --check` -> **PASS**.
- ✅ **ESEGUITO** — whitespace no-index sui file untracked Slice F/Slice E/task -> **PASS**.
- ✅ **ESEGUITO** — grep anti-scope Slice F / file modificati -> **PASS**: nessuna RPC live, nessuna Supabase live, nessuna live dataset validation, nessun client reale nei test, nessun drain/worker/timer/BGTask/Realtime, nessuna UI/`OptionsView`/`Localizable.strings`, nessuna mutazione SwiftData/`ModelContext`, nessuna modifica SQL/Supabase/Android, nessun TASK-059.
- ⚠️ **NON ESEGUIBILE con certezza assoluta** — Nessun warning nuovo: build/test PASS; osservato warning Xcode/AppIntents metadata `No AppIntents.framework dependency found`, gia' noto/non specifico dei file Slice F dal contesto precedente. Nessun warning Swift rilevato nei file Slice F.

**Rischi residui**
- Parity live deployed resta **UNKNOWN**: nessun audit live e nessuna RPC live eseguiti per vincolo esplicito.
- Drain/outbox worker, collegamento result/error agli stati outbox, retry, UI diagnostica, live validation dataset e cleanup restano Slice **G/H/I** o task futuri separati.

**Handoff finale**
- `TASK-058 DONE — Slice F record_sync_event isolated live recorder reviewed and closed`

---

## Definition of Ready — future Slice F Execution

*(Prerequisiti per **Codex** prima di una futura EXECUTION Slice F — **non** soddisfatti in TASK-058 planning.)*

- [ ] Planning review **TASK-058** **approvata** (documentale).
- [ ] Gate **§4 Livello A** completato sul **clone Supabase locale** (solo file).
- [ ] **Livello B** live read-only completato **oppure** esplicitamente marcato **UNKNOWN**.
- [ ] Se **Livello B** resta **UNKNOWN**, execution futura deve essere **mock-only** oppure **STOP**.
- [ ] Firma RPC **`record_sync_event`** verificata (coerente clone e/o B).
- [ ] Limite **`changed_count`** verificato.
- [ ] Policy **`changedCount > 1000`** confermata **fail-closed** (pre-RPC **`.contract`**).
- [ ] Auth/session provider iOS identificato (**TASK-034/038** pattern).
- [ ] Nessun **drain** / **outbox state mutation** nel perimetro Slice F.
- [ ] Nessuna **UI** nel perimetro Slice F.
- [ ] **User override** esplicito per **EXECUTION** futura.

## Handoff finale §14
| Campo | Valore |
|-------|--------|
| **Recorder vs live validation** | **Slice F execution** = recorder live **isolato** con **gate verdi** — **≠** live validation su **dataset reale** (cleanup, read-back operativo, demo su dati veri). Quest’ultima ⇒ **task separato** o **override separato** (**D58-12**); **non** mescolare con **Slice I** / validation dedicata (**§4**). |
| **Task** | TASK-058 — **DONE / Chiusura** |
| **DONE?** | **YES** — solo **Slice F recorder live isolato / transport fakeable** |
| **Stato REVIEW** | **APPROVED_FIXED_DIRECTLY** — review tecnica completata con fix mirati |
| **READY FOR EXECUTION?** | No ulteriore execution attiva; Slice F chiusa. |
| **Prossimo passo consigliato** | Nessun task attivo; eventuale Slice G resta futuro da decidere con nuovo task/override. |
| **Execution futura consigliata** | Drain/outbox worker/live validation restano task separati. |
| **TASK-059** | **NON aperto** |
| **Conferme negative** | Nessuna RPC live; nessuna Supabase live; nessuna live dataset validation; nessuna modifica Android/SQL/Supabase; nessuna UI/drain/background; nessun TASK-059. |
| **Scope freeze** | Nessun nuovo scope; nessuna nuova feature; nessuna Slice G/H/I in TASK-058; solo correzioni richieste dalla review. |
| **Prossima fase** | **Chiusura** — progetto IDLE, nessun task attivo. |
