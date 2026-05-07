# TASK-055: Supabase `sync_events` / `record_sync_event` / **outbox foundation iOS** — Slice C local foundation DONE

## Informazioni generali *(metadata tracking)*
- **Task ID**: TASK-055
- **Titolo**: Supabase sync_events / record_sync_event / outbox foundation iOS — Android/Supabase aligned planning
- **File task**: `docs/TASKS/TASK-055-supabase-sync-events-outbox-foundation-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Utente / prossimo task da decidere
- **Data creazione**: 2026-05-06
- **Ultimo aggiornamento**: 2026-05-07 *(REVIEW+FIX Slice C completata; TASK-055 chiuso DONE solo per foundation locale. Nessun network/RPC/live.)*
- **Ultimo agente che ha operato**: Codex / Reviewer+Fixer

> **Nota governance:** TASK-055 e' **DONE** solo per **Slice C / foundation locale iOS**: outbox SwiftData, state machine pura, helper/store/query locali e test. Slice **D/E/F/G/H/I** restano future/out-of-scope e richiedono task/override separato.

## Dipendenze
- **Dipende da**:
  - **TASK-053** — **DONE / Chiusura**: Slice A read-only `sync_events` (DTO `RemoteSyncEventRow`, `SupabaseSyncEventPreviewService`, test fake/mock, limiti 50/200).
  - **TASK-054** — **DONE / Chiusura**: Slice B UI DEBUG read-only `sync_events` in `OptionsView` (`SupabaseSyncEventDebugViewModel`, `SupabaseSyncEventDebugFormatting`, pattern privacy-safe).
  - **TASK-052** — **BLOCKED / superseded by TASK-053**; **non DONE**; **non** riaprire per execution — resta documento storico/roadmap; TASK-055 **sostituisce** il ruolo operativo di «foundation outbox + RPC» lato planning iOS post-Slice A/B.
  - Catena **TASK-038 → 044/043 → 051**: auth, push catalogo manuale, baseline, ProductPrice push live — **outcome** da mappare verso eventi sync in slice future (non in TASK-055).
- **Fonti incrociate (lettura — non modificare in questo task)**:
  - **Android** `MerchandiseControlSplitView`: **TASK-045** (incremental `sync_events`), **TASK-068** (bulk / eventi compatti, **PARTIAL** live), **TASK-069** (audit outbox residui), **TASK-070** (retry head-of-line **DONE**), **TASK-071** (`record_sync_event` / `changed_count` vs payload **DONE**), follow-up **TASK-072** backend (eventuale).
  - **Supabase locale** `/Users/minxiang/Desktop/MerchandiseControlSupabase`: migration `20260424021936_task045_sync_events.sql` (tabella `sync_events`, RPC `record_sync_event`, RLS SELECT, vincoli `p_changed_count` 0…1000, `entity_ids` keys/size, `metadata` budget).
  - **Supabase** `MASTER_PLAN.md`: principio Room/SwiftData-first / non cloud-first rewrite *(analogo iOS: SwiftData resta SoT operativa)*.

## Scopo
Produrre **solo** un documento operativo che progetti per iOS la **foundation** di:
- modello **outbox locale** per eventi sync (persistenza, stati, idempotenza concettuale);
- policy **enqueue** (quando creare righe outbox dopo push/apply);
- policy **retry** (quali errori sono retryable, max attempts, **no** head-of-line blocking);
- **mapping** esito push/apply locale/remoto → tipo di outcome sync / stato outbox;
- **interfaccia** (protocol/design) verso client **`record_sync_event`** *(senza implementazione RPC reale in TASK-055)*;
- gestione **errori** e **logging privacy-safe**;
- **limiti `changed_count`** e interazione con mismatch **TASK-071** / backend **TASK-072**;
- **fallback** se RPC assente, schema drift, o contratto non considerato sicuro;
- eventuale **UI DEBUG** futura per diagnostica outbox (solo planning);
- **test XCTest** futuri (elenco e intent);
- **slice di execution progressive** (C–I) **senza** implementarle.

## Contesto

### Stato iOS
- **TASK-053 DONE**: DTO + service **read-only** `sync_events` (`SupabaseSyncEventDTOs.swift`, `SupabaseSyncEventPreviewService.swift`, reader `SupabaseSyncEventRemoteReader`), decoder tollerante object/array/extra fields allineato al rischio Android **TASK-065**.
- **TASK-054 DONE**: UI DEBUG **read-only** in `OptionsView` (`SupabaseSyncEventDebugViewModel`, `SupabaseSyncEventDebugFormatting`), gated auth, niente payload grezzo, cap lista UI 20 su campione fino a 50.
- **TASK-052 BLOCKED / superseded**: audit/roadmap documentale; **non** riaprire per execution tecnica; non DONE.
- **Servizi push/pull gia' presenti** (riferimento execution futura): `SupabaseManualPushService` / catalogo, `SupabaseProductPriceManualPushService` / prezzi, preview/apply ProductPrice, pull/apply catalogo — **nessuno** di questi deve invocare `record_sync_event` finche' non definito in task dedicato con override utente.

### Stato Android *(contratto funzionale)*
- **`sync_events` + outbox** gia' operativi nel perimetro Android documentato (**TASK-045** e successivi).
- **TASK-070 DONE**: retry outbox **non** bloccato da head-of-line FIFO su righe esaurite (query **retryable** separata da `listPending` grezzo).
- **TASK-071 DONE**: chiarito **mismatch** — RPC locale (e clone Supabase) valida **`p_changed_count`** in **0…1000**, mentre eventi **compatti** massivi possono riportare `changed_count` reale **> 1000** con `entity_ids` vuoto/minimale → **`PayloadValidation` / contract_mismatch**; follow-up backend tipicamente **TASK-072**.
- **TASK-068 PARTIAL**: bulk product push / validazione live dataset reale ancora da chiudere — non assumere parita' semantica «massiva» su iOS senza task dedicato.

### Stato Supabase
- **Schema/migration locale** in `MerchandiseControlSupabase` **non** implica automaticamente parity con **produzione** — ogni assunzione live va etichettata **UNKNOWN** fino ad audit esplicito.
- **Nessun deploy live** autorizzato in TASK-055 (`db push`, DDL remoto, grant, publication change).
- **SwiftData (Room analog Android) resta source of truth operativa** — `sync_events` e' **osservabilita' / invalidazione / telemetria cross-device**, non storage primario del catalogo o dei prezzi.

## Obiettivo TASK-055 (deliverable planning)
1. **Modello outbox iOS** (proposta): entita' SwiftData o equivalente minimale; campi suggeriti: `clientEventId` (idempotenza verso RPC), `domain` (`catalog` | `prices`), `eventType`, `changedCount` (intenzione client), payload **ridotto** o riferimenti opzionali **senza** liste massicce; stato (`pending`, `sending`, `sent`, `failed`, `dead`, `blockedContract`, …); `attemptCount`, `nextRetryAt`, `lastError` (**sanitizzato**), `createdAt`, `updatedAt`; opzionale `batchId` allineato a push manuale.
2. **Policy enqueue**: es. dopo esito **success** di push manuale catalogo/prezzi (TASK-044/051) con conferma read-back; opzione **enqueue-before-send** vs **enqueue-after-success** — da fissare in handoff verso EXECUTION (default conservativo: **dopo** successo locale + read-back ove applicabile, per non creare outbox orfane).
3. **Policy retry**: backoff, max attempts, classificazione errori (rete vs 401 vs RLS vs `22023` validation vs decoding); **skip** righe non retryable; **non** fermare la coda dietro una riga «dead» in testa.
4. **Mapping outcome** *(allineamento semantico Android TASK-070)*: `Recorded` (RPC ok + riga remota coerente), `Enqueued` (solo locale), `PartiallyRecordedAndEnqueued`, `NoOp` (dedupe `client_event_id`), `Failed` (non retryable o cap superato).
5. **Interfaccia service verso `record_sync_event`**: protocol tipo `SyncEventRecording` con metodo che accetta parametri speculari alla RPC (domain, event_type, changed_count, entity_ids, metadata, …) e ritorna `RemoteSyncEventRow` o errore tipizzato; implementazione **reale** differita a slice **F** con gate.
6. **Errori & privacy logging**: mai loggare `entity_ids` espansi, liste barcode, JWT, query PostgREST raw; solo conteggi, codici errore aggregati, `client_event_id` troncato se necessario.
7. **Limiti `changed_count`**: pre-validazione client **≤ 1000** prima di qualsiasi RPC reale; se operazione reale ha **> 1000** elementi logici → **split** eventi, **oppure** **block** con stato `blockedContract` finche' **TASK-072** / backend non estende contratto — coerente con **TASK-071**.
8. **Fallback**: se RPC non disponibile, sessione assente, o revisione backend non sicura → outbox resta **locale-only** + diagnostica DEBUG; **nessun** invio silenzioso.
9. **UI DEBUG futura (outbox)**: estendere o affiancare sezione TASK-054 con conteggi pending/retryable/blocked, ultimo errore sanitizzato — **mai** lista ID/barcode.
10. **Test futuri**: vedi §9; **slice** progressive §8.

## Decisioni architetturali da pianificare *(vincoli TASK-055)*

| ID | Decisione |
|----|-----------|
| **D55-01** | **Nessuna RPC live** finche' il contratto `record_sync_event` **non** e' verificato sul progetto Supabase **effettivo** usato dall'app iOS (firma, ritorno, messaggi errore, limiti) — documentazione + eventuale task verification read-only separato. |
| **D55-02** | **Nessun** evento iOS con **`changed_count > 1000`** inviato finche' mismatch **TASK-071** **non** e' **risolto lato backend** (**TASK-072** o equivalente) **o** gestito con policy esplicita (split eventi, riduzione semantica) in task EXECUTION dedicato. |
| **D55-03** | L'**outbox iOS** deve **evitare head-of-line blocking** come risolto su Android in **TASK-070**: la coda **non** puo' restare bloccata perche' le prime righe FIFO hanno `attemptCount` max. |
| **D55-04** | Il **retry** deve operare su **righe retryable** (filtro esplicito), **non** assumere che le prime N righe per tempo siano ancora inviabili. |
| **D55-05** | **Log/outcome** devono essere **privacy-safe**: vietati payload raw, liste massive di barcode/UUID, metadata con chiavi vietate dal budget RPC. |
| **D55-06** | **`sync_events` remoto** **non** diventa source of truth: e' **osservabilita'/invalidation**, non storage primario catalogo/prezzi. |
| **D55-07** | **Nessun Realtime / background sync** nel perimetro TASK-055 — solo citazione in slice futura **H** (analysis). |
| **D55-08** | **Nessun sync automatico**: TASK-055 e' **solo planning** foundation; nessun worker attivo pianificato come conseguenza immediata. |
| **D55-09** | **Prodotti / catalogo / prezzi** restano **domini separati** in app e in outbox (`domain` + orchestrazione), ma ogni evento sync deve avere **shape coerente** con RPC (`catalog` vs `prices`, event_type allineato). |
| **D55-10** | Client iOS `record_sync_event` deve supportare **risposta object / array / campi extra** in decoding — come Android **TASK-065** / contesto **TASK-071** (tolleranza DTO). |
| **D55-11** | **Eventi compatti** ammessi **solo** se il **contratto backend** e' **sicuro** e documentato; **vietato** inviare migliaia di entity ID in `entity_ids` (anche sotto cap SQL 250 per chiave). |
| **D55-12** | Se il **backend non e' sicuro** o il contratto e' **ambiguo**, l'outbox puo' restare **solo locale + diagnostica**, **senza invio** remoto finche' non c'e' override esplicito. |
| **D55-13** | **Multi-account / ownership**: ogni futura riga outbox **deve** essere associata all'account Supabase corrente (**`ownerUserID`**, equivalente dell'owner all'enqueue). **`storeID`** solo **se** lo schema/prodotto iOS-Supabase reale lo richiede; **non** introdurre modello multi-store/business oltre quanto gia' previsto. Su **logout / cambio account**: **nessun** drain automatico, **nessuna** RPC; eventi dell'account precedente restano **persistiti ma isolati** per quel `ownerUserID`; UI DEBUG futura deve poter mostrare **«account mismatch»** / **«outbox non disponibile per account corrente»** se l'utente guarda code non appartenenti alla sessione attiva. |
| **D55-14** | **Idempotenza client**: **`clientEventID`** e' la chiave idempotente verso RPC (indice unico remoto per owner). In EXECUTION futura: vincolo univoco locale pianificato come **`ownerUserID + clientEventID`**, oppure **`ownerUserID + domain + clientEventID`** se il dominio deve partecipare all'unicita' — da fissare in Slice C con preferenza **minima** (prima forma se sufficiente). **Retry** sulla stessa riga outbox **riusa** sempre lo **stesso** `clientEventID` (**vietato** generarne uno nuovo per tentativo). Esito remoto **duplicato / gia' registrato** (idempotenza backend) → outcome **`NoOp`** o **`Recorded`**, **non** **`Failed`**. |
| **D55-15** | **Slice F (RPC write reale)** resta **bloccata** finche' non sono soddisfatti i gate in §Addendum 5 (contratto live, `changed_count`, duplicate `client_event_id`, decode risposta, **TASK-071** risolto o mitigato, seguire **TASK-072** o equivalente backend). Se **TASK-072** non e' risolto, iOS resta in **`localOnly` / dry-run** per eventi **massivi** oltre i limiti contrattuali noti. |
| **D55-16** | **Privacy / payload budget outbox**: persistenza locale **senza** liste massive barcode/UUID, senza JWT/query PostgREST, senza metadata raw ne' snapshot completi Product/ProductPrice; preferenza a conteggi, shape, campione sanitizzato opzionale, hash/fingerprint se utile; log solo **kind/codice** aggregati. |

## Gap analysis *(Android / Supabase / iOS)*

| Android feature / Supabase feature | iOS stato attuale | Gap | Rischio | Proposta slice |
|-----------------------------------|-------------------|-----|---------|----------------|
| `sync_events` read-only preview | **DONE** TASK-053/054 (service + UI DEBUG) | Nessuno per read-only | Drift schema live vs locale | Audit read-only in task verification separato se serve |
| RPC `record_sync_event` | **Non** integrato; DTO lettura esiste | Client RPC, mapping parametri, error taxonomy | Contract mismatch **TASK-071**, drift live | **D** contract tests mock; **F** live solo con gate |
| Outbox locale (Room su Android) | Assente | Modello SwiftData + DAO-like API | Persistenza duplicata vs source data | **C** model + state machine senza rete |
| Retry max attempts | Assente | Policy cap + stato `dead` | Loop infinito / battery | **C**+**G** |
| Head-of-line blocking (FIFO naive) | N/A | Rischi se retry = prime righe solo | Blocco coda (**TASK-069** su Android) | **G** retry su query retryable |
| `changed_count > 1000` | UI/Client non invia RPC | Pre-validazione + block/split | RPC reject `22023` | **D** test limite; attesa **TASK-072** o split |
| Compact events (empty/small entity_ids, count grande) | Non emessi | Allineamento semantic con Android **TASK-068** | **PayloadValidation** | **E**/policy esplicita dopo D55-02 |
| `entity_ids` privacy / size cap | UI DEBUG maschera shape/count | Encoder outbox deve rispettare cap SQL | Leak dati o fail RPC | **E** sanitizzare/preview count only in log |
| Catalog push events | Push manuale TASK-044 senza sync_events | Collegamento outcome → enqueue | Doppio record o mancato record | **E** hook post-push controllato |
| ProductPrice push events | Push TASK-051 senza sync_events | Idem | Idem | **E** dominio `prices` |
| Pull/apply events | Apply locale TASK-039 ecc. senza `record_sync_event` | Decidere se outbox anche per pull | Scope creep | **E** solo se piano separato / override |
| Realtime invalidation | Assente | Subscribe, merge watermark | Complessita' / batteria | **H** planning only |
| Background sync | Assente | BGTask / scheduling | Policy Apple + privacy | **H** planning only |
| Debug.UI `sync_events` remoto | **DONE** TASK-054 | — | — | Estendere **solo** se outbox UI approvata |
| Live verification end-to-end | Non in TASK-055 | Osservazione RPC reale | Impatto dati reali | **I** dataset piccolo, override utente |
| Backend **TASK-072** (eventuale) | Non avviato | Allineamento `p_changed_count` / compact | Blocco eventi massivi iOS | Pianificare dipendenza esplicita prima di **F** |

## Slice future *(progressive; **non** implementate in TASK-055)*

| Slice | Descrizione | Note |
|-------|-------------|------|
| **C** | Outbox locale: modello SwiftData + **state machine pura** (transizioni pending→…); **nessun** network | Test unit in-memory |
| **D** | Client `record_sync_event` **dry-run / fake** + **contract tests** (mock JSON); **nessun** live | Decoding object/array/extra; errori simulati |
| **E** | **Enqueue** da outcome **push manuale** catalogo/ProductPrice; ancora **nessun** auto-sync | Gating esplicito post-TASK-044/051 success |
| **F** | RPC write **solo** dietro **DEBUG / override manuale** esplicito, **se** D55-01 soddisfatto | No default-on |
| **G** | **Worker** retry / drain manuale outbox con fix head-of-line (**D55-03/04**) | No BGTask obbligatorio in prima iterazione |
| **H** | **Realtime + background sync**: analysis & planning **only** | Documento rischi; nessuna subscribe in C–G obbligatoria |
| **I** | **Live validation** dataset piccolo | Task separato; override utente; non accorpare a C–G |

## Test futuri *(XCTest — pianificati; **non** eseguiti in TASK-055)*

| # | Intento |
|---|---------|
| T55-01 | Enqueue evento: stato iniziale coerente, idempotenza `client_event_id` locale |
| T55-02 | Evento **compatto** senza lista raw di entity (verifica encoding ridotto / metadata safe) |
| T55-03 | **`changed_count`** al confine **1000** accettato; **1001** → blocco/split policy |
| T55-04 | Skip/block **>1000** finche' backend non safe (**TASK-072** / flag contratto) |
| T55-05 | Query retryable **esclude** righe a max attempts |
| T55-06 | Ordinamento retry **non** equivale a «solo prime 5 FIFO» se non retryable |
| T55-07 | Mapping outcome: `recorded` / `enqueued` / `partial` / `failed` / `no-op` |
| T55-08 | Logging: assert **assenza** stringhe che somigliano a UUID massivi o barcode |
| T55-09 | Dry-run / fake recorder: **nessuna** chiamata rete (spy su client) |
| T55-10 | Decodifica risposta RPC **object vs array** + **campi extra** ignorati |
| T55-11 | **Planning/dry-run**: **nessuna** chiamata `record_sync_event` reale nel test target puro |
| T55-12 | **Nessun** stub Realtime / BGTask nei test di slice C–D |

## UI/UX planning *(solo DEBUG / futuro)*

- **Collocazione**: sezione `OptionsView` **#if DEBUG** — stesso principio TASK-054; possibile **card separata** «Outbox sync» sotto auth/baseline.
- **Badge**: **«DEBUG · Diagnostica»** (o equivalente localizzato) — coerente con Slice B.
- **Contenuto**: **conteggi** (pending, retryable, blocked, dead), **ultimo tentativo** (timestamp), **ultimo esito** sintetico — **mai** payload raw, **mai** CTA «Push tutto» o «Sync automatico».
- **Copy suggerito** *(da localizzare in execution)*: «Eventi locali in attesa», «Ultimo tentativo», «Riprovabili», «Bloccati per limite backend».
- **Miglioramenti UX** minimi ammessi **solo** come bullet in questo planning — **nessuna** patch Swift in TASK-055.

## Sicurezza / anti-scope *(TASK-055 — assoluto)*

Questo turno **e** il task in fase PLANNING **vietano**:
- Chiamate **Supabase live** (read/write/RPC) dal lavoro di «foundation code» — TASK-055 stesso **non** esegue network.
- **SQL migration**, `supabase db push`, modifiche RLS/grant/publication remota.
- **RPC write** reale / **`record_sync_event`** reale dall'app.
- **Outbox processor** reale (nessun loop di invio attivo come deliverable di TASK-055).
- **Background task** / **BGTask**, **Realtime subscribe**.
- **`service_role`** o chiavi elevate.
- **Cleanup** outbox o dati remoti.
- **Modifiche Android** / Kotlin / Room.
- **Mutazione** prezzo corrente `Product` / storico `ProductPrice` non prevista da task dedicati.
- **Sync automatico** o «drain» implicito all'avvio.

## Planning — formato operativo (Claude)

### Obiettivo
Allineare la roadmap iOS post TASK-053/054 con la realta' Android (**TASK-070/071/068**) e il clone Supabase (`record_sync_event`, vincoli payload), preparando slice **C–I** e decisioni **D55-01…16** per future execution senza scope creep.

### Analisi
- iOS ha **lettura** `sync_events` e UI DEBUG; **manca** outbox e RPC write.
- Android ha evidenza di **coda persistente**, **retry selective**, e **tensione contrattuale** su `changed_count` massivo.
- SQL locale mostra **guardie strette** su `changed_count`, `entity_ids`, `metadata` — utili come **specifica** per client pre-validation.

### Approccio
1. Congelare **D55-01…16** come vincoli di gating per ogni futura EXECUTION.
2. Definire slice **C→I** senza accorpamento: un task / override per slice principale.
3. Riutilizzare `RemoteSyncEventRow` per **parse risposta** RPC quando attiva.
4. Tenere **domini** `catalog` e `prices` **separati** in enqueue (**D55-09**).

### File coinvolti *(futura EXECUTION — non modificati in TASK-055)*
- `iOSMerchandiseControl/SupabaseSyncEventDTOs.swift`, `SupabaseSyncEventPreviewService.swift`
- `SupabaseSyncEventDebugViewModel.swift`, `SupabaseSyncEventDebugFormatting.swift`, `OptionsView.swift`
- Nuovi file probabili: modello outbox SwiftData, `SyncEventRecording` protocol, fake/mocks test
- Riferimento: `SupabaseManualPushService.swift`, `SupabaseProductPriceManualPushService.swift`, `SupabaseClientProvider.swift`

### Rischi
| Rischio | Mitigazione (planning) |
|---------|------------------------|
| Drift schema live vs locale | D55-01; verifica read-only dedicata |
| `changed_count` > 1000 | D55-02; attesa TASK-072 o split |
| Duplicazione eventi | `client_event_id` + idempotenza RPC |
| Privacy | D55-05 |
| Scope creep (pull/apply → sync_events) | Enqueue pull **solo** con task/override esplicito |

### Criteri di accettazione *(contratto TASK-055 — fase PLANNING)*
- [ ] File task TASK-055 creato con **Contesto**, **Obiettivo**, **D55-01…16**, **gap table**, **slice C–I**, **test futuri**, **UI DEBUG futura**, **anti-scope**, **Addendum** execution-ready.
- [ ] `docs/MASTER-PLAN.md` aggiornato: progetto **ACTIVE**, task attivo **TASK-055**, fase **PLANNING**, ultimo completato **TASK-054 DONE**, **TASK-052** BLOCKED/superseded **non DONE**.
- [ ] **Nessun** file Swift, **nessun** `project.pbxproj`, **nessun** build/test, **nessuna** chiamata Supabase live, **nessuna** modifica SQL/Supabase/Android **in** TASK-055.
- [ ] TASK-055 **non** marcato **DONE**.
- [ ] **Multi-account / ownership** outbox documentata (§Addendum 1, **D55-13**).
- [ ] **Idempotenza `clientEventID`** e vincolo unico locale futuro documentati (§Addendum 2, **D55-14**).
- [ ] Query **retryable** anti head-of-line documentata (§Addendum 3 + **D55-03/04**).
- [ ] Stati terminali **auth** / **schema** / **contract** / **dead** documentati (§Addendum 4).
- [ ] Gate backend **TASK-072** / `record_sync_event` per Slice **F** documentato (§Addendum 5, **D55-15**).
- [ ] **Handoff** chiarisce che la **prossima fase consigliata** e' **REVIEW documentale** del planning, **non** EXECUTION automatica (§Handoff post-planning).

### Handoff post-planning
- **Ruolo TASK-055**: **planning umbrella** — resta il documento di riferimento unico per foundation outbox + RPC iOS finche' non esistono task di execution dedicati per slice **C, D, …**.
- **TASK-055**: **ACTIVE / PLANNING**, **NON DONE**; sezioni **Execution** e **Fix** restano **vuote** finche' non c'e' **user override** esplicito su un task/slice di codice.
- **Prossima fase**: **REVIEW documentale** del planning — **non** EXECUTION, **nessuna** execution automatica. Il reviewer verifica coerenza interna, completezza **D55-01…16**, addendum, allineamento con Android/clone Supabase.
- **Planning frozen except review fixes.** Significa: **nessun** nuovo scope, **nessuna** nuova feature; sono ammessi **solo** aggiustamenti al documento richiesti dalla **REVIEW documentale** (wording, coerenza, typo, chiarimenti senza ampliare il perimetro).
- **EXECUTION Slice C** (modello outbox SwiftData + state machine, **nessun** network): richiede **user override** **separato** e task/file di execution dedicato; **non** parte da questo handoff.
- **TASK-056**: **non** aprire in questo turno / come conseguenza diretta del planning — eventuale nuovo ID solo dopo chiusura workflow su TASK-055 e decisione esplicita backlog.
- **Vietato senza override**: transizione implicita a **EXECUTION**, patch Swift, build, XCTest, Supabase live, SQL, Android.
- **Prossimo agente (review)**: **Claude / Reviewer** — checklist **CA** § sopra + **Checklist REVIEW documentale** § sotto.
- **Prossimo agente (solo dopo override Slice C)**: **Codex / Executor** — fuori perimetro TASK-055 finche' in **PLANNING**.

#### Checklist REVIEW documentale *(pre-EXECUTION / pre-Slice C)*
- [ ] Stato TASK-055 = **ACTIVE / PLANNING**, **non DONE**.
- [ ] `docs/MASTER-PLAN.md` allineato: ultimo completato **TASK-054 DONE**; **TASK-052** **BLOCKED / superseded**; **TASK-055** task attivo; **nessun TASK-056** aperto da questo ciclo.
- [ ] **Nessuna** execution Swift autorizzata dalla sola REVIEW documentale.
- [ ] **Nessun** Supabase live / SQL / RPC / Android nel perimetro di TASK-055.
- [ ] **D55-01…16** presenti nella tabella decisioni e coerenti con addendum e slice.
- [ ] Multi-account / ownership documentati (§Addendum 1, **D55-13**).
- [ ] Idempotenza **`clientEventID`** documentata (§Addendum 2, **D55-14**).
- [ ] Retry anti head-of-line documentato (§Addendum 3, **D55-03/04**).
- [ ] Stati terminali auth / schema / contract / dead documentati (§Addendum 4).
- [ ] Gate **TASK-072** / `record_sync_event` / Slice **F** documentato (§Addendum 5, **D55-15**).
- [ ] Privacy / payload budget documentati (**D55-16**, §Addendum 6).
- [ ] Slice **C–I** dichiarate **future**, non avviate da TASK-055.
- [ ] **Prossima fase** dopo review documentale OK = eventuali *review fixes* al markdown; **EXECUTION** solo con **user override** separato su Slice C (o task dedicato).

---

## Addendum — planning execution-ready *(2026-05-06)*

Integrazione mirata; **nessun** codice, **nessun** file Swift. TASK-055 resta **ACTIVE / PLANNING**.

### 1. Multi-account / ownership outbox
- Ogni futura riga outbox iOS **deve** essere associata all'**account Supabase corrente** al momento dell'enqueue (stesso concetto di **owner** che governa RLS su `sync_events` remoto: `owner_user_id = auth.uid()`).
- Campi pianificati (allineati alla RPC/tabellare remota dove applicabile):
  - **`ownerUserID`** (obbligatorio) — snapshot dell'utente autenticato all'enqueue; non «trust» della UI senza sessione.
  - **`storeID`** — **opzionale**, **solo se** lo schema effettivo iOS/Supabase e i flussi push lo richiedono gia'; altrimenti **omit** per evitare scope multi-store inventato.
  - **`sourceDeviceID`** — opzionale ma raccomandato per diagnostica incrociata con backend (entro limiti lunghezza RPC).
  - **`clientEventID`** — obbligatorio per idempotenza (vedi §2).
- **Logout / cambio account**:
  - **Nessun** drain automatico della coda.
  - **Nessuna** RPC `record_sync_event`.
  - Le righe create sotto l'account **A** restano nel database locale con `ownerUserID = A`; non vanno «mergiate» nell'account **B**.
  - La futura **UI DEBUG** outbox, se mostra aggregate globali, deve gestire il caso **«account mismatch»** / **«outbox non disponibile per account corrente»** (es. filtrare solo `ownerUserID == sessione attuale`, oppure sezione disabilitata con copy chiaro).
- **Scope**: solo **isolamento account-safe**; **non** pianificare multi-utente business/multi-store oltre quanto gia' presente nel modello; **non** espandere requisiti prodotti non motivati dallo schema attuale.

### 2. Idempotenza e unicolità
- **`clientEventID`** e' la **chiave idempotente** verso il backend (indice unico parziale remoto su `(owner_user_id, client_event_id)` dove `client_event_id` not null).
- **Vincolo locale futuro** (EXECUTION): unicita' almeno **`ownerUserID + clientEventID`**; se in EXECUTION emerge collision cross-domain, valutare **`ownerUserID + domain + clientEventID`** — **non** decidere codice in TASK-055.
- **Retry RPC**: ogni nuovo tentativo sulla **stessa** riga outbox **riusa** lo **stesso** `clientEventID` (**vietato** rigenerare ID per retry).
- **Risposta duplicata / già registrata** (backend idempotent): outcome operativo **`NoOp`** o **`Recorded`** (successo logico), **non** **`Failed`** — coerente con il ramo `RETURN v_row` esistente in RPC quando `client_event_id` gia' presente (clone locale).
- **Nessuna** implementazione in TASK-055.

### 3. Schema outbox locale più concreto *(proposta campi — no Swift)*

| Campo | Note |
|-------|------|
| `id` | Chiave primaria locale (es. UUID o Int64 autoincrement — da scegliere in Slice C). |
| `ownerUserID` | Owner Supabase all'enqueue (**D55-13**). |
| `clientEventID` | Idempotenza; stringa stabile per ciclo di vita del tentativo. |
| `batchID` | Opzionale; allineato a push manuale / batch TASK-044/051 se utile. |
| `domain` | `catalog` \| `prices` (vincolo RPC). |
| `eventType` | Valori ammessi da RPC (`catalog_changed`, …). |
| `changedCount` | Intenzione client; soggetto a cap **1000** lato RPC finche' contratto non cambia. |
| `entityIDsShape` | Classificazione sintetica (es. empty / keys-only / counts-per-key) **oppure** payload ridotto conforme ai cap SQL — **mai** blob raw massivo. |
| `metadataShape` / **metadata sanitizzato** | Solo oggetto conforme al **budget** RPC (dim + chiavi ammesse); niente campi vietati dalla migration locale. |
| `status` | Enum/stati tipizzati §4. |
| `attemptCount` | Tentativi di invio RPC completati (o definiti in EXECUTION). |
| `maxAttempts` | Cap configurabile (default da fissare in Slice C). |
| `nextRetryAt` | Schedulazione backoff. |
| `lastAttemptAt` | Timestamp ultimo tentativo. |
| `lastErrorCode` | Es. codice PostgREST / SQLSTATE se mappabile in modo safe. |
| `lastErrorKind` | Taxonomy consolidata (rete, auth, contract, schema, …). |
| `lastErrorMessageSanitized` | Messaggio breve **senza** segreti, **senza** payload. |
| `createdAt` / `updatedAt` | Audit locale. |
| `sentAt` | Quando stato raggiunge `sent` (o equivalente successo RPC). |
| `sourceDeviceID` | Opzionale; coerente con RPC. |

**Indici / query future** (pseudologic — EXECUTION):
- **Pending per owner**: filtro `ownerUserID` + `status` + `nextRetryAt` (ove applicabile).
- **Retryable**: `status IN (pending, failedRetryable)` (vedi §4) **AND** `attemptCount < maxAttempts` **AND** `nextRetryAt <= now` (con clock monotono locale consigliato).
- **Blocked / dead**: esclusi dalla retry queue (stati `blockedContract`, `blockedAuth`, `blockedSchema`, `dead`, `localOnly`, ecc.).
- **Ordinamento stabile** per pick retry: `nextRetryAt ASC`, `createdAt ASC`, `id ASC`.
- **Vietato**: query «prime N righe FIFO» **senza** filtro retryable (anti head-of-line **TASK-069/070**).

### 4. Stati outbox più tipizzati

| Stato | Uso |
|-------|-----|
| `pending` | In coda, mai ancora inviato o pronto per primo tentativo. |
| `sending` | Tentativo RPC in corso (opzionale; utile anti doppio invio). |
| `sent` | RPC ok e accettato come successo (`sentAt` impostato). |
| `failedRetryable` | Fallito ma merita retry (rete timeout / offline / 5xx mappato, ecc.). |
| `blockedContract` | `changed_count` / PayloadValidation / oltre **1000** / vincoli payload — **TASK-071** / attesa **TASK-072**. |
| `blockedAuth` | 401 / 403 / session missing / RLS negata come auth. |
| `blockedSchema` | Drift schema, RPC assente, decoding contract mismatch non risolvibile client-side. |
| `dead` | `attemptCount >= maxAttempts` o fallimento non retryable non recuperabile. |
| `cancelled` | Solo **interno** (teardown Task, reset) se serve — **non** user-facing in UI prod/DEBUG salvo label tecnica minima. |
| `localOnly` | Backend non sicuro o gate **D55-15** non soddisfatto: **no** RPC finche' non cambia policy. |

**Mapping errori → stato** (pianificazione):
- Rete timeout / offline → **`failedRetryable`**.
- 401 / 403 / session missing → **`blockedAuth`**.
- Schema drift / funzione mancante / RPC assente → **`blockedSchema`**.
- `changed_count > 1000` / PayloadValidation / overflow contratto → **`blockedContract`**.
- Max attempts raggiunto → **`dead`**.
- RPC ok → **`sent`** (o outcome **`Recorded`** a livello domain).
- Duplicate / idempotent ok da backend → **`sent`** o transizione logica **NoOp** con riga non duplicata remotamente (outcome **`NoOp`** / **`Recorded`** — coerente §2).

**Nota execution (tipi vs UI):** in EXECUTION futura gli stati sopra devono diventare un **enum** / **state machine** **testabile** (Swift: `enum` o equivalente); la **UI** deve **solo localizzare la presentazione** da quel tipo. **Test** e **logica di dominio** devono assertare **enum / outcome** (es. `blockedContract`, `failedRetryable`), **non** stringhe localizzate.

### 5. Gating backend / TASK-072 e Slice F
**Slice F** (RPC write reale da app) resta **bloccata** finche' **non** sono vere (con evidenza documentata) **tutte** le condizioni sotto, o finche' non esiste **mitigazione esplicita** approvata:
- Contratto **`record_sync_event`** sul progetto Supabase **live effettivo** usato da iOS: firma, tipi, messaggi errore.
- Limite **`changed_count`** confermato (0…1000 o nuovo contratto post-**TASK-072**).
- Comportamento **duplicate** su **`client_event_id`** chiaro (ritorno riga esistente vs errore) e coperto da test contract.
- Risposta RPC **object / array / campi extra** coperta da test client (allineamento **TASK-065** / **D55-10**).
- **Mismatch Android TASK-071** risolto **o** mitigato (es. backend **TASK-072** o equivalente estende contract / split eventi iOS documentato).

**Collegamento TASK-072**: ogni sblocco significativo di **Slice F** per eventi **massivi** / **compact** oltre i limiti attuali deve trattare **TASK-072** (o task backend iOS/Supabase equivalente) come **dipendenza** esplicita. Se **TASK-072** **non** e' risolto, iOS rimane in **`localOnly`** / **dry-run** / split sotto-soglia per tali eventi (**D55-15**).

### 6. Privacy e payload budget (outbox persistito)
- L'outbox **non** deve persistere **liste massive** di barcode/UUID **se non strettamente necessario** per il contratto; in pratica preferire:
  - **`changedCount`** affidabile;
  - **shape** + **conteggi** per chiavi `entity_ids`;
  - eventuale **small sample** sanitizzato (cap basso, solo diagnostica);
  - **hash / fingerprint** opzionale dell'insieme logico (se EXECUTION dimostra utilita' senza leak).
- **Vietato** nell'outbox e nei log: JWT/token/session string; query string PostgREST raw; **metadata** non normalizzato; payload completo **Product** / **ProductPrice**; **migliaia** di entity IDs in chiaro.
- Log runtime: **`lastErrorKind`**, codici aggregati, conteggi — **mai** payload business o elenchi ID.

### 7. Nota sullo scope addendum
Questo addendum **non** sostituisce le sezioni precedenti; le **rafforza** per EXECUTION futura. **TASK-055** **non** passa a **EXECUTION** senza workflow e **user override** separato.

## Execution (Codex)
### 2026-05-07 — Slice C implementata

**Scope eseguito**
- Implementata solo **Slice C**: foundation locale iOS per outbox `sync_events`.
- Nessuna chiamata remota, nessuna RPC `record_sync_event`, nessun `SupabaseClient`, nessun Realtime, nessun BGTask, nessun worker/drain automatico.
- Nessuna UI `OptionsView`, nessun hook sui servizi manual push catalogo/prezzi, nessuna modifica SQL/Supabase/Android, nessun TASK-056.

**File modificati**
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift` — nuovo modello SwiftData `SyncEventOutboxEntry`, factory enqueue locale, store SwiftData locale, query retryable owner-scoped e counts.
- `iOSMerchandiseControl/SyncEventOutboxState.swift` — enum stati/error kind, snapshot state machine pura, mapping errori, sanitizer privacy-safe.
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift` — aggiunto `SyncEventOutboxEntry.self` allo schema del `ModelContainer` app.
- `iOSMerchandiseControlTests/SyncEventOutboxStateTests.swift` — test factory/state/sanitizer.
- `iOSMerchandiseControlTests/SyncEventOutboxLocalStoreTests.swift` — test SwiftData in-memory per insert locale, retryable per owner, owner mismatch, sort stabile e counts.
- `docs/TASKS/TASK-055-supabase-sync-events-outbox-foundation-ios.md` e `docs/MASTER-PLAN.md` — tracking EXECUTION → REVIEW.

**Decisioni concrete**
- ID locali, owner e client event sono persistiti come `String`; `clientEventID` viene generato una volta in factory e non viene rigenerato dalle transizioni.
- `changedCount <= 1000` resta ammesso; `changedCount > 1000` crea entry `blockedContract` con errore sanitizzato, coerente con D55-02/TASK-071.
- Shape sospette per `entityIDsShape` / `metadataShape` (UUID/barcode raw, token/JWT, query string, liste grezze o payload troppo lunghi) non vengono persistite: la factory redige a marker `redacted:*` e blocca `blockedContract`.
- Retryable = `pending` o `failedRetryable` + `attemptCount < maxAttempts` + `nextRetryAt <= now` + owner corrente uguale.
- Query retryable locale ordinata stabilmente per `nextRetryAt ASC`, `createdAt ASC`, `id ASC`; nessuna logica "prime N FIFO" senza filtro retryable.
- L'unico `.insert(` introdotto e' `context.insert(entry)` nello store locale SwiftData, non Supabase/PostgREST.

**Check eseguiti**
- ✅ ESEGUITO — Build Debug: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` → **PASS**.
- ✅ ESEGUITO — XCTest Slice C state: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SyncEventOutboxStateTests` → **PASS**.
- ✅ ESEGUITO — XCTest Slice C local store: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SyncEventOutboxLocalStoreTests` → **PASS**.
- ✅ ESEGUITO — Regressioni TASK-053/054: `SupabaseSyncEventPreviewServiceTests` + `SupabaseSyncEventDebugViewModelTests` → **PASS**.
- ✅ ESEGUITO — `git diff --check` → **PASS** sui file tracciati; nuovi file verificati anche con `git diff --no-index --check /dev/null <file>` senza output whitespace.
- ✅ ESEGUITO — Grep anti-scope sui nuovi file Slice C: assenti `SupabaseClient`, `.rpc(`, `record_sync_event`, `.channel(`, `.subscribe(`, `BGTask`, `Realtime`, `service_role`, `.upsert(`, `.update(`, `.delete(`. Presente solo `context.insert(entry)` locale SwiftData.
- ✅ ESEGUITO — Modifiche coerenti con planning Slice C e criteri richiesti dall'override utente.
- ✅ ESEGUITO — Criteri Slice C verificati con test mirati e build.
- ✅ ESEGUITO — Nessun warning Swift nuovo rilevato dai file Slice C durante build/test; resta il warning Xcode/AppIntents metadata gia' noto/non specifico della slice.

**Limiti rimasti / follow-up per slice future**
- Slice D/F non implementate: nessun client fake/dry-run RPC e nessuna RPC reale `record_sync_event`.
- Slice E non implementata: nessun enqueue dai servizi push manuali catalogo/ProductPrice.
- Slice G non implementata: nessun worker/drain/timer.
- Slice H/I non implementate: nessun Realtime, BGTask o live validation.
- Nessun vincolo unico SwiftData locale su `ownerUserID + clientEventID` aggiunto in questa slice; la stabilita' del `clientEventID` e' coperta dalla factory/state machine.

### Handoff post-execution (Codex → Claude)
> **Storico:** questo handoff e' stato superato dalla review finale **APPROVED_FIXED_DIRECTLY / DONE** del 2026-05-07.

- **Stato finale richiesto:** TASK-055 **ACTIVE / REVIEW**, responsabile **Claude / Reviewer**, **non DONE**.
- Reviewer: verificare solo Slice C locale, con attenzione a modello SwiftData, regole retryable, privacy sanitizer e assenza di scope remoto.
- Conferme scope: nessuna chiamata Supabase live; nessuna RPC `record_sync_event`; nessun Realtime/BGTask/worker/drain; nessuna UI nuova; nessun Android/SQL/TASK-056.
- Se servono correzioni, transizione valida successiva: **REVIEW → FIX**; dopo eventuale fix Codex deve tornare a **REVIEW**, mai a DONE.

## Fix (Codex)
### 2026-05-07 — Fix mirati durante REVIEW Slice C

- Enforced `clientEventID` non vuoto quando fornito esplicitamente alla factory (`missingClientEventID`), mantenendo la generazione una sola volta alla creazione entry e nessuna rigenerazione nei retry.
- Rafforzato `lastErrorMessageSanitized`: redazione di URL con query string, parametri sensibili, UUID e barcode/ID numerici lunghi oltre a token/JWT/Bearer gia' coperti.
- Aggiunti XCTest mirati:
  - `clientEventID` obbligatorio;
  - `changedCount` negativo rifiutato;
  - success → `sent`;
  - `.network` / `.offline` / `.timeout` → `failedRetryable`;
  - sanitizer URL/query/business IDs;
  - store SwiftData retryable esclude max attempts, future retry, blocked/dead/localOnly/sent/sending.

## Review (Claude)
### 2026-05-07 — APPROVED_FIXED_DIRECTLY / DONE

**Esito review tecnica Slice C**
- **APPROVED_FIXED_DIRECTLY**: review severa completata, fix piccoli applicati direttamente, nessun blocker residuo su Slice C locale.
- Scope confermato: implementazione limitata a outbox locale SwiftData, state machine pura, factory/helper, store/query locale e XCTest.
- `SyncEventOutboxEntry` aggiunto al `ModelContainer` app come nuovo `@Model` additivo. Nessun reset store, nessuna cancellazione dati, nessuna migration custom distruttiva; rischio residuo SwiftData considerato ragionevole per schema additivo locale, da monitorare su device reale come ogni cambio schema.
- `sending` resta escluso dalla retry queue in Slice C; non esiste worker/drain in questo task. La policy di recupero stale `sending` e' da definire in Slice G, se e quando verra' autorizzata.
- Slice **D/E/F/G/H/I** non implementate e restano future/out-of-scope.

**Fix applicati**
- Factory: `clientEventID` vuoto ora fallisce con `missingClientEventID`.
- Sanitizer: messaggi errore redigono URL/query string, parametri sensibili, UUID e numeri business-like lunghi.
- Test: aggiunte coperture su client event obbligatorio, changedCount negativo, success→sent, network/offline, sanitizer realistico e filtro retryable store.

**Check eseguiti**
- ✅ ESEGUITO — Build Debug: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` → **PASS**. Warning AppIntents metadata noto/non specifico Slice C; nessun warning Swift nuovo sui file Slice C.
- ✅ ESEGUITO — XCTest Slice C state: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SyncEventOutboxStateTests` → **PASS**, 20 test.
- ✅ ESEGUITO — XCTest Slice C local store: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SyncEventOutboxLocalStoreTests` → **PASS**, 5 test.
- ✅ ESEGUITO — Regressione TASK-053: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SupabaseSyncEventPreviewServiceTests` → **PASS**, 10 test.
- ✅ ESEGUITO — Regressione TASK-054: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SupabaseSyncEventDebugViewModelTests` → **PASS**, 15 test.
- ✅ ESEGUITO — `git diff --check` → **PASS**.
- ✅ ESEGUITO — `git diff --no-index --check /dev/null <nuovi file>` sui nuovi file Slice C/tracking → **PASS** senza output whitespace.
- ✅ ESEGUITO — Grep anti-scope sui file Slice C: nessun match per `SupabaseClient`, `.rpc(`, `record_sync_event`, `.channel(`, `.subscribe(`, `BGTask`, `Realtime`, `service_role`, `.upsert(`, `.update(`, `.delete(`.
- ✅ ESEGUITO — `.insert(` sui file Slice C → unico match `context.insert(entry)` in `SyncEventOutboxLocalStore`, confermato SwiftData locale.
- ✅ ESEGUITO — Diff/status anti-scope: nessuna modifica a `OptionsView.swift`, servizi manual push catalogo/ProductPrice, SQL/Supabase migration, Android, TASK-056.

**Conferme finali**
- Nessuna chiamata Supabase live eseguita.
- Nessuna RPC `record_sync_event`.
- Nessun Realtime, BGTask, worker, drain, timer o sync automatico.
- Nessuna UI nuova.
- Nessun hook nei servizi manual push; nessun ProductPrice push/apply modificato.
- Nessuna modifica SQL/Supabase/Android.
- Nessun TASK-056 aperto.

### Handoff finale
**TASK-055 DONE — Slice C local outbox foundation reviewed and closed**

## Decisioni
- **2026-05-06**: Task creato su **USER OVERRIDE** — «START NEXT TASK PLANNING ONLY»; nessuna execution tecnica nel turno di apertura.
- **2026-05-06**: Addendum execution-ready — multi-account (**D55-13**), idempotenza (**D55-14**), schema campi/indici, stati tipizzati, gate **TASK-072**/Slice **F** (**D55-15**), privacy budget (**D55-16**), handoff → **REVIEW documentale** prima di EXECUTION; **TASK-055** resta **PLANNING**, **non DONE**.
- **2026-05-06**: Rifinitura coerenza — riferimenti **D55-01…16** allineati; handoff **Planning frozen except review fixes.**; checklist REVIEW documentale; nota enum vs stringhe UI negli stati outbox; CA wording su divieti tecnici.
- **2026-05-06**: **PLANNING REVIEW documentale** — coerenza incrociata con `MASTER-PLAN` (**D55-01…16** nelle voci TASK-055); micro-fix typo gap table / campo `batchID`; **nessuna** modifica Swift/build/Supabase/SQL/Android.
- **2026-05-07**: **USER OVERRIDE EXECUTION APPROVED — Slice C only**; Codex ha implementato outbox locale SwiftData + state machine pura + test, senza network/Supabase live/RPC/Realtime/BGTask/worker/UI/SQL/Android/TASK-056; handoff a **REVIEW**.
- **2026-05-07**: **USER OVERRIDE TECHNICAL REVIEW + FIX APPROVED — Slice C**; review completata con esito **APPROVED_FIXED_DIRECTLY / DONE**. Fix piccoli su factory `clientEventID`, sanitizer privacy e test. TASK-055 chiuso **DONE** solo per **Slice C locale**; Slice D/E/F/G/H/I future/out-of-scope; nessun TASK-056.

---

## Non incluso *(perimetro Slice C / residuo TASK-055)*
Supabase live, SQL migration, RPC reale, outbox runtime/worker/drain, Realtime, background sync, hook push catalogo/ProductPrice, UI nuova, modifiche Android, TASK-056 o task successivi.
