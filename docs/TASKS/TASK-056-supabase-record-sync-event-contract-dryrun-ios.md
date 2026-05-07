# TASK-056: Supabase `record_sync_event` — **Slice D** contract / dry-run client iOS — **no live RPC**

## Informazioni generali *(metadata tracking)*
- **Task ID**: TASK-056
- **Titolo**: Supabase `record_sync_event` contract / dry-run client iOS — no live RPC / no Supabase live / no drain outbox
- **File task**: `docs/TASKS/TASK-056-supabase-record-sync-event-contract-dryrun-ios.md`
- **Stato**: DONE
- **Fase attuale**: Chiusura
- **Responsabile attuale**: Utente / prossimo task da decidere
- **Data creazione**: 2026-05-06
- **Ultimo aggiornamento**: 2026-05-07 *(REVIEW+FIX Slice D completata; TASK-056 chiuso DONE solo per contract/dry-run iOS. No Supabase live/RPC live/drain/UI/SwiftData mutation.)*
- **Ultimo agente che ha operato**: Codex / Reviewer+Fixer

> **USER OVERRIDE — START NEXT TASK PLANNING ONLY:** questo turno crea/aggiorna **solo** markdown (`TASK-056`, `MASTER-PLAN`). Vietato: file Swift, `project.pbxproj`, build, XCTest, Supabase live, SQL, Android, apertura **TASK-057**.
> **USER OVERRIDE — TECHNICAL REVIEW + FIX APPROVED (2026-05-07):** autorizzata review tecnica Slice D, fix mirati e chiusura **DONE** se build/test/check passano. Impatto workflow: chiusura eseguita direttamente da Codex su override utente esplicito, senza implementare slice future.

## Dipendenze
- **Dipende da / contesto soddisfatto**:
  - **TASK-053** — **DONE**: DTO + service read-only `sync_events` (`RemoteSyncEventRow`, `SyncEventRowsResponse`, `SupabaseSyncEventPreviewService`, test fake/mock).
  - **TASK-054** — **DONE**: UI DEBUG read-only `sync_events` in `OptionsView`.
  - **TASK-055** — **DONE** (solo **Slice C**): outbox SwiftData locale + state machine pura (`SyncEventOutboxEntry`, `SyncEventOutboxState`, factory/store/tests) — **nessun** network/RPC.
- **TASK-052** — **BLOCKED / superseded by TASK-053**; **non DONE**; documento storico/roadmap — **non** riaprire per execution tecnica.
- **Riferimenti esterni (lettura — non modificare in questo task)**:
  - **Android TASK-070** — **DONE**: retry outbox anti head-of-line.
  - **Android TASK-071** — **DONE**: mismatch `record_sync_event` / `changed_count > 1000` vs payload compatti documentato; backend **TASK-072** (o equivalente) **futuro**.
  - **Supabase locale** `/Users/minxiang/Desktop/MerchandiseControlSupabase`: migration `sync_events`, RPC `record_sync_event` — **fonte specifica locale**, **non** prova dello stato **live** (locale ≠ produzione senza audit esplicito).

---

## 1. Contesto

### Stato iOS attuale
- Esiste **lettura** remota `sync_events` (TASK-053/054) con decoder tollerante **object / array / campi extra** (`SyncEventRowsResponse`, `RemoteSyncEventRow`).
- Esiste **outbox locale** SwiftData con idempotenza concettuale e `clientEventID` stabile in factory (**TASK-055 Slice C**), limiti `changedCount` lato factory coerenti con cap contrattuale **1000**, sanitizer shape/metadata.
- **Manca** il layer dedicato **contract + dry-run** per simulare la semantica client di **`record_sync_event`**: DTO request/response, validazione payload, mapping errori, decoding risposta senza alcuna chiamata reale.

### Cosa questo task **non** fa
- **Nessuna** RPC live, **nessun** `SupabaseClient` nell’implementazione pianificata del recorder (solo contract/dry-run/fake).
- **Nessun** drain outbox, worker, timer, BGTask, Realtime.
- **Nessuna** UI (inclusa `OptionsView`).
- **Nessuna** assunzione che il backend **live** coincida con il clone locale Supabase: ogni dettaglio live resta **UNKNOWN** fino a verifiche dedicate (gate Slice **F** / task separati).

### Lezione Android / Supabase
- **TASK-071**: eventi con `changed_count` logico **> 1000** possono collide con vincoli RPC (es. `p_changed_count` 0…1000 nel clone) → classificazione **contract** / attesa mitigazione **TASK-072**.
- Il client iOS deve **pre-validare** e **bloccare** `changedCount > 1000` a livello contract/dry-run allineato al backend noto, indipendentemente da compact payload.

---

## 2. Obiettivo Slice D *(planning execution-ready)*

Pianificare (per futura EXECUTION con override separato) i seguenti elementi **puramente locali**:

| Elemento | Descrizione |
|----------|-------------|
| **`SyncEventRecording`** | Protocol async (o equivalente minimo) che espone “registra evento sync” senza vincolare il trasporto; implementazioni: **fake/dry-run** ora; **live** solo Slice **F** / task dedicato con gate. |
| **`SyncEventRecordRequest`** | Struct/value type con campi RPC-allineati (vedi §4), incluso **`clientEventID`** stabile dalla outbox TASK-055. |
| **`SyncEventRecordResult`** | Esito logico: es. **`recorded`** (nuova riga logica), **`noOp`** (duplicate idempotente / gia’ registrato — **successo logico**, non fallimento). |
| **`SyncEventRecordError`** | Errore tipizzato con **taxonomy** (§5) + payload sanitizzato per messaggi. |
| **Validatore payload client-side** | Pre-RPC: stringhe non vuote dove richiesto, `changedCount` in **0…1000**, budget **`entityIDs` / `metadata`** (§4), divieti token/JWT/query/liste massive. |
| **Fake / dry-run recorder** | Implementazione che **non** tocca rete: resta deterministico da fixture JSON o stub errori; **riusa** gli stessi tipi e validatore del futuro recorder reale (**D56-06**). |
| **Fixture / contract tests** | JSON locali: risposta **object**, **array**, **campi extra**; errori PostgREST **simulati** (struttura stringa/codice senza segreti). |
| **Decoding risposta** | Riutilizzare **`RemoteSyncEventRow`** (e helper esistenti tipo `SyncEventRowsResponse`) dove coerente con la forma attesa dall’RPC nel clone — **tolleranza** object/array/extra come TASK-053/TASK-065-risk. |

### Gestione risposta decodificata *(object / array — policy execution-ready)*

- **Campi obbligatori mancanti** nella riga decodificata (es. `id`, `domain`, `changed_count`, … secondo `RemoteSyncEventRow`) → **`schema`** dopo tentativo di decode.
- **Campi extra** nella risposta JSON → **ignorati** (come TASK-053); non devono far fallire il decode.
- **Risposta `object`** valida → una riga; se il decode non produce una riga valida → **`schema`**.
- **Risposta `object` singola** senza `client_event_id` *(opzionale in `RemoteSyncEventRow`)*: **puo’** essere trattata come successo logico **`recorded`** / accettazione decode **solo se** gli altri campi obbligatori decodificano e una **policy esplicita** + **XCTest** lo documentano; **non** silent success senza test.
- **Risposta `array` vuota** *(zero righe decodificabili)* → **`schema`** o **`contract`**: la scelta finale va presa in **EXECUTION** ma **deve** essere coperta da **XCTest** (niente silent success).
- **Risposta `array` con più righe** — policy esplicita obbligatoria:
  - Se **una o più** righe hanno `client_event_id` **assente / null** → **non** considerare la risposta idempotente/successo aggregato; → **`schema`** o **`contract`** (scelta + **test** in EXECUTION), **mai** silent success.
  - Se **tutte** le righe hanno `client_event_id` **presente** e **uguale** al **`clientEventID`** della request → **`recorded`** / **`noOp`** ammesso (coerente **D56-05**).
  - Se `client_event_id` **mancante su alcune righe** ma presente su altre, oppure **valori misti / divergenti** dal request → **`schema`** o **`contract`** (non silent success); bucket finale **schema** vs **contract** da fissare e **coprire in test**.
  - **Preferenza** dove tutte le righe sono coerenti ed eguali al request: si puo’ considerare **solo la prima riga** come rappresentante, se la policy execution lo conferma.
- **Duplicate / idempotenza simulata** nel fake → o **HTTP/RPC success** con payload che riusa lo **stesso** `clientEventID` atteso, oppure **`SyncEventRecordResult`** dedicato **`noOp`** / **`recorded`** senza contraddire **D56-05** (mai mappare a `failed`).

**Esplicito:** in **Slice D** nessun uso reale di **`SupabaseClient`**, **nessuna** `.rpc(`, **nessun** invio runtime verso cloud; cfr. §6/§8 per uso della **stringa** `record_sync_event` in documentazione/test vs production.

---

## 3. Decisioni architetturali *(D56-xx)*

| ID | Decisione |
|----|------------|
| **D56-01** | **Slice D non chiama Supabase live** — zero network, zero SDK transport per `record_sync_event`. |
| **D56-02** | **`record_sync_event` reale** resta **bloccato** fino a **Slice F** (o task separato) con gate **D55-15** / **TASK-072** documentati. |
| **D56-03** | Il **validatore client-side** deve **bloccare** `changedCount > 1000` (errore **contract**), allineato a TASK-071 / SQL clone. |
| **D56-04** | La **request** usa **`clientEventID` stabile** proveniente dalla outbox **TASK-055** (stesso valore sui retry; vietata rigenerazione per tentativo). |
| **D56-05** | Risposta **duplicate / idempotent success** (stesso `client_event_id` gia’ presente) → esito **`recorded`** o **`noOp`** (successo logico), **non** `failed`. |
| **D56-06** | **Fake/dry-run** deve usare **stessi DTO + validatore** del futuro recorder **live** (una sola fonte di verità per validazione/decoding). |
| **D56-07** | **Response decoding** accetta **object**, **array** e **campi extra ignorati**; riuso **`RemoteSyncEventRow`** / envelope esistenti dove possibile. |
| **D56-08** | **Nessun payload raw massimo** in fixture/test/log: niente migliaia di barcode/UUID inline; usare **shape sintetici**, **conteggi**, **cap** documentati. |
| **D56-09** | **Error mapping** distingue almeno: **auth**, **schema**, **contract**, **network/retryable**, **unknown** (messaggi sempre sanitizzati). |
| **D56-10** | **Nessun drain outbox** in Slice D: solo **contract layer** puro; nessun collegamento obbligatorio a `SyncEventOutboxLocalStore` oltre alla pianificazione del mapping request da entry (opzionale in execution, senza processor). |
| **D56-11** | Budget JSON per `entityIDs` / `metadata` come in **§4** (soglie prudenziali); superamento → errore **contract**, **non** network; i valori numerici vanno **ricalibrati** in EXECUTION/REVIEW e **non** sostituiscono il DDL/backend live. |

---

## 4. Payload contract *(planning)*

### Campi pianificati in `SyncEventRecordRequest` *(allineamento RPC / tabella)*

| Campo | Tipo pianificato | Note |
|-------|------------------|------|
| `domain` | `String` | Deve essere **non vuoto** post-trim; **allowlist** tipo `catalog` \| `prices` **solo** se confermata da migration/RPC letta in EXECUTION (vedi guardie § sotto). |
| `eventType` | `String` | Deve essere **non vuoto** post-trim; **allowlist** valori evento **solo** se ancorata a schema verificato; altrimenti **no** enum rigido inventato in Slice D. |
| `changedCount` | `Int` | **0…1000** lato validatore; sopra → **contract** error. |
| `entityIDs` | `SyncEventJSONValue` o wrapper sanitizzato | **Solo** oggetti conformi a shape/budget; vietate liste massicce di stringhe business in chiaro nei test. |
| `metadata` | `SyncEventJSONValue` | Oggetto conforme a **budget** dimensione/chiavi; niente token/URL con query sensibili. |
| `source` | `String?` | Opzionale, breve. |
| `sourceDeviceID` | `String?` | Opzionale; lunghezza cap come RPC. |
| `batchID` | `UUID?` / `String?` | Opzionale; allineamento push manuale TASK-044/051 se presente in outbox. |
| `clientEventID` | `String` | **Obbligatorio**, non vuoto; idempotenza verso backend. |
| *(ownership)* | *Non in payload RPC verso funzione se gia’ implicito da sessione* | In planning: `ownerUserID` puo’ restare **contesto sessione** nel recorder live futuro; in dry-run puo’ essere **iniettato** nelle fixture di `RemoteSyncEventRow` per coerenza decode. |

### Budget JSON pianificato per `entityIDs` e `metadata` *(valori iniziali prudenziali)*

> **Nota governance:** le soglie sotto sono **defaults pronti per review/EXECUTION**; **non** sono “schema backend definitivo” né garanzia di parity con **produzione** o con il clone `MerchandiseControlSupabase` senza verifica. Restano **D56-11**.

| Regola | Valore suggerito |
|--------|------------------|
| Profondita’ massima annidata (oggetti/array) | **3** livelli |
| Chiavi **top-level** massime (per oggetto radice di `metadata` / radice di `entityIDs` se object) | **20** |
| Lunghezza serializzata stimata (JSON UTF-8) **per** `metadata` e **per** `entityIDs` *(due budget separati)* | **8 KB** ciascuno |
| Elementi massimi **per singolo array** incontrato nella validazione walk *(non cumulativo globale oltre quanto la profondita’/8KB permettono)* | **100** |
| Liste massive barcode/UUID | **Vietate** — pattern coerente con privacy TASK-055; preferire shape/conteggi |
| Superamento budget (profondita’, chiavi, byte, elementi array, liste vietate) | Errore **`contract`** — **mai** classificato come **network** sul solo client |

- I valori devono essere esprimibili e validabili tramite **`SyncEventJSONValue`** (TASK-053) o **wrapper equivalente** che non bypassi quel modello di valore.
- **Vietato** `Any` / **`JSONSerialization`** “raw” **senza** policy di sanitize/bound esplicite (stesso spirito **D56-08**).

### Stima `8 KB` *(senza forzare `Encodable` su `SyncEventJSONValue`)*

- Il tipo **`SyncEventJSONValue`** oggi puo’ essere **solo `Decodable`**; la futura **EXECUTION** **non** deve mutare i DTO TASK-053 **solo** per abilitare `JSONEncoder`, salvo **reale necessità** e **review** esplicita.
- Per rispettare il **budget 8 KB** (per `metadata` e per `entityIDs`, separati), preferire in ordine di praticità:
  1. **Size estimator puro** sul tree `SyncEventJSONValue` (conteggio byte UTF-8 stimato su stringhe, ricorsione con cap depth/array);
  2. oppure **proiezione / mirror `Encodable` locale** al validator **solo** nel modulo Slice D (non necessariamente su `SyncEventJSONValue` globale);
  3. oppure **validazione conservativa** combinata: depth / chiavi top-level / elementi array + **lunghezza stringhe** (senza serializzare tutto l’albero), se dimostrata sufficiente in review.
- Il budget resta **validazione contract client-side**; **non** sostituisce DDL/backend definitivo (**D56-11**).

### Guardie validator *(client-side)*
- `domain` / `eventType`: **obbligatoriamente non** vuoti dopo trim; **allowlist** ristretta (es. `catalog`/`prices`, `catalog_changed`/…) **solo** se la migration/RPC **locale** (o fonte schema concordata) e’ **letta e verificata** in EXECUTION — **altrimenti** niente enum rigidi che possano bloccare valori futuri legittimi; eventuali enum devono avere **fallback / unknown** policy **coperta da test**.
- Oltre ai non-vuoti: eventualmente charset/lunghezza max ragionevole **senza** assumere lista chiusa non verificata.
- `changedCount`: **0…1000** inclusivo; negativi rifiutati.
- `clientEventID`: **non** vuoto.
- `metadata` / `entityIDs`: **entro budget § sopra**; assenza pattern JWT/Bearer/query PostgREST raw; **vietate** liste massive barcode/UUID.

---

## 5. Error taxonomy *(planning mapping)*

| Origine sintetica | Bucket | Note |
|-------------------|--------|------|
| Session missing, **401**, **403**, RLS negata come auth | **auth** | Non retryable salvo re-login (policy futura outbox). |
| Function missing, colonna mancante, drift schema, decode shape **incompatibile** dopo risposta, **campi obbligatori mancanti** in `RemoteSyncEventRow` | **schema** | Distinto da payload non valido **prima** della chiamata. |
| `PayloadValidation`, **22023**, `changed_count` overflow lato RPC (simulato), validatore client, **budget JSON §4** | **contract** | Include `changedCount > 1000` e superamento soglie **D56-11**. |
| Timeout, offline, errori rete 5xx simulati / URLError | **network** (retryable) | In dry-run: inject simulato; in outbox futura: `failedRetryable`. |
| Duplicate `clientEventID` con **success** backend (riga esistente restituita) | **noOp / recorded** | **D56-05** — non mappare a `failed`. |
| Risposta decodificata senza righe validhe / array vuoto *(vedi §2)* | **`schema`** o **`contract`** | Scelta in EXECUTION + **test obbligatorio**; non silent success. |
| Non classificato / invariant violation interna | **unknown** | Messaggio **sanitizzato**; niente dump payload. |

### Allineamento taxonomia recorder → stati / kind TASK-055 *(futuro wiring; Slice D = solo mapping documentale)*

Quando in slice future un worker collega il recorder all’outbox, gli esiti logici devono mappare senza ambiguita’:

| Taxonomy `SyncEventRecordError` / esito | Stato / kind TASK-055 *(target integrazione)* |
|----------------------------------------|-----------------------------------------------|
| **contract** | `blockedContract` + `lastErrorKind` **`.contract`** |
| **auth** | `blockedAuth` + **`.auth`** |
| **schema** | `blockedSchema` + **`.schema`** |
| **network** (retryable) | `failedRetryable` + **`.network`** / **`.offline`** / **`.timeout`** (come gia’ modellato in TASK-055) |
| **success** `recorded` / **`noOp`** | In Slice D solo **`SyncEventRecordResult`**; **nessun** `apply` su `SyncEventOutboxEntry`. Futuro: transizione verso **`sent`** (o equivalente) solo fuori da Slice D. |

---

## 6. Test futuri *(XCTest — pianificati; non eseguiti in questo turno)*

| # | Intento |
|---|---------|
| T56-01 | Request valida passa il validatore. |
| T56-02 | `changedCount == 1000` **accettato**. |
| T56-03 | `changedCount == 1001` **respinto** (contract). |
| T56-04 | `clientEventID` vuoto **respinto**. |
| T56-05 | `domain` / `eventType` vuoti **respinti**. |
| T56-06 | `metadata` con JWT/token/query string **respinta** o normalizzata come **non valida** / redacted. |
| T56-07 | `entityIDs` lista/oggetto **massivo** oltre soglia §4 → **respinto** (contract). |
| T56-08 | Fake recorder: risposta ok → **`recorded`** (o equivalente). |
| T56-09 | Fake recorder: risposta duplicate idempotent → **`noOp`** o **`recorded`**, **non** errore. |
| T56-10 | Decodifica risposta **object** → `RemoteSyncEventRow` (o wrapping consistente). |
| T56-11 | Decodifica risposta **array** (prima riga o envelope test-defined). |
| T56-12 | **Campi extra** nella risposta **ignorati** senza fail. |
| T56-13 | Errore simulato auth → bucket **auth**. |
| T56-14 | Errore simulato schema → **schema**. |
| T56-15 | Errore simulato contract / 22023 → **contract**. |
| T56-16 | Errore simulato network → **network** / retryable. |
| T56-17 | Dry-run: **nessuna** dipendenza da `SupabaseClient` (test di assenza / spy architetturale). |
| T56-18 | **Grep anti-scope — distinguere production vs test/docs (cfr. §8):** nei **nuovi file production Slice D** nessun `SupabaseClient`; nessun `.rpc(`; nessun `.from(`; nessun `.insert(` / `.upsert(` / `.update(` / `.delete(` come **API PostgREST**; nessun Realtime / BGTask / chiamata live; **nessun** `context.insert` / `save` / fetch SwiftData outbox. **`record_sync_event`:** **preferenza netta = zero occorrenze** in sorgenti **production** Slice D; se in **EXECUTION** futura compare in production, **eccezione motivata**: literal **mai invocato**, **nessun** `.rpc`, approvazione **review**; in **documentazione**, **commenti**, **`iOSMerchandiseControlTests`** / fixture **solo** se **marcata chiaramente non-live**. |
| T56-19 | Grep: **nessuna** modifica a `OptionsView.swift`, `iOSMerchandiseControlApp.swift`, servizi **manual push** catalogo/ProductPrice. |
| T56-20 | Risposta **array vuota** / zero righe — comportamento conforme a policy §2 + bucket errore coperto da test. |
| T56-21 | Risposta **array multi-riga** — ramo **coerente** con §2 (`client_event_id` null/mancante / misto / allineato al request; **schema** vs **contract** testato). |
| T56-22 | Budget JSON §4: payload oltre soglia → **contract** (assert **non** network). |
| T56-23 | Risposta **object** senza `client_event_id` — policy §2 + test. |

---

## 7. File futuri probabili *(solo elenco — non creare in questo turno)*

- `SyncEventRecording.swift`
- `SyncEventRecordRequest.swift`
- `SyncEventRecordValidator.swift`
- `SyncEventRecordDryRunRecorder.swift` *(nome indicativo — fake recorder)*
- `SyncEventRecordError.swift` *(o nested types in modulo dedicato)*
- `SyncEventRecordingTests.swift`

*Estensioni possibili*: riuso `SupabaseSyncEventDTOs.swift` per `RemoteSyncEventRow` / JSON value senza duplicare decoder.

---

## 8. Anti-scope *(assoluto per TASK-056 / Slice D)*

- **No** Supabase live / API remota.
- **No** `.rpc(` / **no** invocazione reale RPC. **`record_sync_event` (letterale):** **preferenza = zero occorrenze** nei **nuovi file production** Slice D; eccezione futura solo se **motivata**, **non invocata**, **non** accoppiata a client live (**cfr.** T56-18). Ammessa in **docs**, **commenti**, **fixture/test** **esplicitamente non-live**.
- **No** `SupabaseClient` nell’implementazione **dry-run** (e **no** dependency injection obbligatoria di client reale nei test Slice D).
- **No** drain outbox / worker / timer / **BGTask**.
- **No** Realtime.
- **No** `OptionsView` / UI DEBUG nuova per questo slice.
- **No** SQL migration / `db push` / RLS.
- **No** modifiche **Android**.
- **No** hook **ProductPrice** / catalog **push** → sync event (Slice **E**).
- **No** **TASK-057** aperto o referenziato come attivo.
- **No SwiftData / ModelContainer (Slice D):**
  - **No** modifica a `iOSMerchandiseControlApp.swift` / registrazione **`ModelContainer`** / schema app.
  - **No** nuovi `@Model` per Slice D.
  - **No** `context.insert`, `context.save`, **fetch** SwiftData o **qualsiasi mutazione** `SyncEventOutboxEntry` / outbox store.
  - Il mapping **`SyncEventOutboxEntry` → `SyncEventRecordRequest`** resta **funzione pura**, **fixture di test** o stub — **no** integration test contro database SwiftData per Slice D salvo override esplicito futuro (non pianificato qui).

---

## Planning — formato operativo (Claude)

### Obiettivo
Definire **Slice D**: contract client iOS per `record_sync_event` in forma **fake/dry-run** + test a fixture, senza rete e senza drain outbox, riusando DTO lettura esistenti e allineamento TASK-071 / gate TASK-072.

### Analisi
- TASK-053 ha gia’ **RemoteSyncEventRow** + decoder tollerante; TASK-055 ha **outbox** e limite **1000** in factory.
- Manca un **confine** esplicito tra “payload ammesso verso RPC” e “errore prima del network” — il validatore Slice D chiude questo gap.
- Il **live** resta incerto: i test devono essere **deterministici** e **privacy-safe**.

### Approccio
1. Congelare **D56-01…11** come vincoli per ogni futura EXECUTION Slice D.
2. **Reuse TASK-055:** dove possibile riusare **`SyncEventOutboxEntry`**, **`SyncEventOutboxStatus`**, **`SyncEventOutboxErrorKind`** (e concetti gia’ in **`SyncEventOutboxState`**) per **coerenza semantica**; **non** introdurre enum paralleli con nomi diversi se l’intento e’ identico. Se servono casi **`SyncEventRecordError`** specifici del recorder, devono **mappare chiaramente** alla taxonomy §5 e alla tabella **recorder → TASK-055** (es. **contract** → `blockedContract`; slice D espone ancora solo **result/error** logici, **nessun** update outbox).
3. Progettare tipi **Sendable** / testabili dove possibile, analogo pattern TASK-053 tests.
4. Centralizzare validazione in **un** modulo validator richiamato da dry-run e (futuro) live.
5. Duplicati idempotenti → ramo **success** esplicito nei test (**T56-09**).

### File coinvolti *(futura EXECUTION)*
- Nuovi file §7; lettura/consultazione: `SupabaseSyncEventDTOs.swift`, `SyncEventOutboxEntry.swift` (solo mapping `clientEventID` / campi).
- **Non modificare** in TASK-056 planning turn: codice sorgente, `project.pbxproj`.

### Rischi

| Rischio | Mitigazione (planning) |
|--------|-------------------------|
| Drift RPC live vs clone | D56-01 / D56-02; test solo su fixture; gate **F**. |
| Duplicazione decoder | D56-07: riuso `RemoteSyncEventRow` / envelope esistente. |
| Fixture che leak dati | D56-08 / D56-11; JSON minimi in `iOSMerchandiseControlTests`/bundle. |
| Scope creep verso worker/ drain | D56-10; review severa su PR. |

### Criteri di accettazione *(contratto TASK-056 — fase **PLANNING**)*

- [ ] File task **TASK-056** con §1–8, **D56-01…11**, test pianificati, anti-scope, handoff, checklist review.
- [ ] `docs/MASTER-PLAN.md` coerente: progetto **ACTIVE**, task attivo **TASK-056**, fase **PLANNING**, ultimo completato **TASK-055 DONE**, TASK-052 **BLOCKED/superseded**, **nessun TASK-057**.
- [ ] **Nessun** file Swift, **nessun** build/test, **nessuna** chiamata Supabase live nei turni **solo PLANNING**.
- [ ] TASK-056 **non** marcato **DONE**.

### Criteri execution-ready *(futura EXECUTION Slice D — dopo override; non questo turno)*

- `SyncEventRecordRequest`, `SyncEventRecordResult`, `SyncEventRecordError` e implementazione **fake/dry-run** devono essere **`Sendable`** ove **Swift / tipi** lo consentono senza hack.
- Evitare **stato condiviso mutabile** non protetto tra concurrency domains; niente singleton globale con contatori non sincronizzati salvo `actor`/lock giustificato in review.
- **Fake recorder** = **deterministico** (stesso input + stessa fixture → stesso output).
- Simulazione **duplicate/idempotenza** con stato interno: preferire **`actor`**, **`class` isolata ai test** o **value-type** puri; documentare nel modulo test.

### Checklist — **PLANNING REVIEW** *(prima di `Execution (Codex)`)*

- [ ] **TASK-056** resta **ACTIVE** / **PLANNING** / **non DONE**.
- [ ] **TASK-055** resta **ultimo completato** **DONE** (Slice C).
- [ ] **TASK-052** resta **BLOCKED / superseded by TASK-053**.
- [ ] **Nessun TASK-057**.
- [ ] **D56-01…11** coerenti con §2–8.
- [ ] **Budget JSON** §4 documentato (valori prudenziali, non DDL live).
- [ ] **Mapping** taxonomia → stati/kind **TASK-055** §5 documentato.
- [ ] **Sendable / concurrency** § criteri execution-ready documentato.
- [ ] **No SwiftData mutation / no `ModelContainer` change** §8 documentato.
- [ ] **Response** object/array/empty/multi-row §2 documentata + test pianificati.
- [ ] **Anti-scope**: no Supabase live, no RPC, no UI, no drain documentati + grep **T56-18…23** (ordine numerico §6).
- [ ] **Planning frozen except review fixes** (handoff) compreso.
- [ ] **Prossima fase** = **REVIEW documentale**, **non** execution Swift implicita (**non** “READY FOR EXECUTION”).

### Handoff post-planning
- **Planning frozen except review fixes.** Significa: **nessun** nuovo scope, **nessuna** nuova feature, **nessuna** slice **E/F/G**, **nessun** **TASK-057**; solo aggiustamenti al markdown richiesti dalla **REVIEW documentale** (wording, coerenza, chiarimenti — **senza** ampliare il perimetro).
- **Stato**: **TASK-056** **ACTIVE** / **PLANNING** — **READY FOR PLANNING REVIEW** *(non DONE)* — **non** “READY FOR EXECUTION”.
- **Prossima fase obbligatoria**: **REVIEW documentale** (Claude / Reviewer) — **nessuna** EXECUTION Swift, build, XCTest, Supabase live, SQL, Android **senza** user override separato.
- **EXECUTION futura** *(solo dopo override esplicito utente)*: **perimetro stretto** — **solo** Slice **D** (**dry-run / fake / contract tests** + file §7); **ancora**:
  - **no** **live RPC** / **no** invocazione `record_sync_event`;
  - **no** **drain** outbox / worker / timer / BGTask;
  - **no** **UI** (`OptionsView` inclusa) / no hook manual push;
  - **no** modifica `ModelContainer` / SwiftData / mutazione outbox come §8.
- **Prossimo agente (review)**: **Claude / Reviewer** — checklist sopra + assenza scope **E/F/G**.
- **Prossimo agente (execution, solo dopo override)**: **Codex / Executor** — solo quanto sopra.

---

## Execution (Codex)
### 2026-05-07 — Slice D implementata

**Scope eseguito**
- Implementata solo **Slice D**: contract/dry-run recorder iOS puro e testabile per futura registrazione eventi sync.
- Nessuna chiamata Supabase live, nessun SDK transport, nessuna RPC live, nessun drain outbox, nessuna UI, nessuna mutazione SwiftData.
- `project.pbxproj` non modificato: il progetto usa filesystem-synchronized groups e i nuovi file sono stati inclusi automaticamente.

**File modificati**
- `iOSMerchandiseControl/SyncEventRecording.swift` — nuovo layer production puro: `SyncEventRecording`, `SyncEventRecordRequest`, `SyncEventRecordResult`, `SyncEventRecordError`, `SyncEventRecordValidator`, `SyncEventRecordDryRunRecorder`.
- `iOSMerchandiseControlTests/SyncEventRecordingTests.swift` — nuova suite XCTest contract/dry-run.
- `docs/TASKS/TASK-056-supabase-record-sync-event-contract-dryrun-ios.md` — tracking EXECUTION -> REVIEW.
- `docs/MASTER-PLAN.md` — riallineamento task attivo TASK-056.

**Decisioni concrete**
- Tipi Slice D raccolti in un solo file production per evitare over-engineering.
- `SyncEventRecordRequest` usa `SyncEventJSONValue` per `entityIDs` e `metadata`; nessun `Any`, nessuna serializzazione raw.
- Validator puro/stateless con budget: depth max 3, top-level keys max 20, byte stimati max 8 KB separati per `metadata`/`entityIDs`, array max 100 elementi, blocco liste massive UUID/barcode-like, token/JWT/query string come errore **contract**.
- `changedCount` valido solo `0...1000`; `domain`, `eventType`, `clientEventID` non vuoti post-trim; nessuna allowlist hardcoded `catalog`/`prices`.
- Taxonomy recorder: `auth`, `schema`, `contract`, `network`, `unknown`; mapping puro verso concetti TASK-055 (`contract -> blockedContract`, `auth -> blockedAuth`, `schema -> blockedSchema`, `network -> failedRetryable`, success/noOp -> futuro `sent`), senza aggiornare outbox.
- Policy response dry-run:
  - object valido -> `recorded`;
  - object singolo senza `client_event_id` -> accettato se gli altri campi obbligatori decodificano;
  - array valido e coerente -> `recorded` o `noOp` se policy idempotente;
  - extra fields ignorati via DTO TASK-053;
  - array vuoto -> `schema`;
  - multi-row con `client_event_id` mancante/null/diverso/misto -> `schema`.
- Il fake/dry-run e' deterministico da fixture JSON o errore simulato; nessuno stato condiviso/singleton.
- Primo lancio della nuova suite ha fallito per type-check troppo pesante in un array test statico; il test e' stato spezzato e rieseguito con esito PASS.

**Check eseguiti**
- ✅ ESEGUITO — Build Debug: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` -> **PASS**.
- ✅ ESEGUITO — XCTest Slice D: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SyncEventRecordingTests` -> **PASS**, 26 test.
- ✅ ESEGUITO — Regressione TASK-053: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SupabaseSyncEventPreviewServiceTests` -> **PASS**, 10 test.
- ✅ ESEGUITO — Regressione TASK-055 state: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SyncEventOutboxStateTests` -> **PASS**, 20 test.
- ✅ ESEGUITO — Regressione TASK-055 store: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SyncEventOutboxLocalStoreTests` -> **PASS**, 5 test.
- ✅ ESEGUITO — `git diff --check` -> **PASS** sui file tracciati; nuovi file verificati anche con `git diff --no-index --check /dev/null <file>` senza errori whitespace.
- ✅ ESEGUITO — Grep anti-scope su `iOSMerchandiseControl/SyncEventRecording.swift`: assenti `SupabaseClient`, `.rpc(`, `.from(`, `.insert(`, `.upsert(`, `.update(`, `.delete(`, `.channel(`, `.subscribe(`, `BGTask`, `Realtime`, `service_role`, `context.insert`, `context.save`, `ModelContext`, `ModelContainer`, `record_sync_event`.
- ✅ ESEGUITO — Grep Slice D/test: nessuna occorrenza `record_sync_event`, `SupabaseClient`, `.rpc(` nei nuovi file production/test.
- ✅ ESEGUITO — Verifica file fuori scope: nessuna modifica a `OptionsView.swift`, `iOSMerchandiseControlApp.swift`, servizi manual push catalogo/ProductPrice, file SQL/Supabase/Android.
- ✅ ESEGUITO — Modifiche coerenti con il planning Slice D e criteri di accettazione verificati con test/build/static grep.
- ✅ ESEGUITO — Nessun warning Swift nuovo rilevato dai file Slice D durante build/test; presente solo warning Xcode/AppIntents metadata gia' noto/non specifico della slice.

**Limiti rimasti / Slice future**
- Slice E non implementata: nessun hook/enqueue dai servizi manual push catalogo/ProductPrice.
- Slice F non implementata: nessuna RPC live, nessun audit contratto Supabase live, nessun worker live.
- Slice G/H/I non implementate: nessun drain, worker, timer, BGTask, Realtime o live validation.
- Il mapping verso outbox resta solo funzione/concetto puro; nessuna transizione o mutazione `SyncEventOutboxEntry` in Slice D.

### Handoff post-execution (Codex -> Claude)
> Storico: questo handoff e' stato superato dalla review tecnica finale sotto, autorizzata da user override e chiusa in **DONE**.

- **Stato finale richiesto:** TASK-056 **ACTIVE / REVIEW**, responsabile **Claude / Reviewer**, **non DONE**.
- Reviewer: verificare solo Slice D dry-run/contract locale, con attenzione a validator budget, response policy, taxonomy e grep anti-scope.
- Conferme scope: nessuna chiamata Supabase live; nessuna RPC live; nessun `SupabaseClient`; nessun drain outbox/worker/timer/BGTask/Realtime; nessuna UI/`OptionsView`; nessuna mutazione SwiftData/`ModelContainer`; nessun SQL/Supabase/Android; nessun TASK-057.
- Se servono correzioni, transizione valida successiva: **REVIEW -> FIX**; dopo eventuale fix Codex deve tornare a **REVIEW**, mai a DONE.

## Fix (Codex)
### 2026-05-07 — Review fix mirati

**Fix applicati**
- Rafforzato `SyncEventRecordValidator.containsSensitiveToken(_:)`: ora intercetta anche chiavi token camelCase/substr (`authToken`, `sessionToken`, ecc.), non solo `token` / `_token`.
- Estesa `SyncEventRecordingTests` con copertura su:
  - assenza di allowlist hardcoded per `domain` / `eventType`;
  - budget separati `entityIDs` per byte stimati e top-level keys;
  - sanitizer dei messaggi esposti da `SyncEventRecordError.classified`.

**Scope fix**
- Nessuna feature nuova fuori Slice D.
- Nessuna modifica a RPC live, Supabase SDK, UI, SwiftData/outbox store, worker/drain o servizi manual push.

## Review (Claude)
### 2026-05-07 — APPROVED_FIXED_DIRECTLY / DONE *(user override)*

**Esito review**
- Review tecnica Slice D completata: implementazione corretta, locale, dry-run, coerente con planning TASK-056 e con mapping TASK-055.
- Fix piccoli applicati direttamente durante review; nessun problema residuo bloccante.
- TASK-056 marcato **DONE** solo per **Slice D record_sync_event contract/dry-run iOS**.

**Cosa e' stato controllato**
- `SyncEventRecording` resta protocol pulito e non accoppiato al Supabase SDK.
- `SyncEventRecordRequest`, `SyncEventRecordResult`, `SyncEventRecordError`, validator e recorder sono `Sendable` dove sensato e senza stato globale mutabile.
- Request validator: `domain`/`eventType`/`clientEventID` non vuoti, nessuna allowlist hardcoded, `changedCount` 0...1000, JSON via `SyncEventJSONValue`, depth max 3, top-level keys max 20, array max 100, budget stimato 8 KB separato per `entityIDs` e `metadata`, token/JWT/query/stringhe sensibili e liste massive UUID/barcode respinte come **contract**.
- Response policy dry-run: object valido -> `recorded`; object senza `client_event_id` accettato solo con campi obbligatori validi; array coerente -> `recorded`/`noOp`; extra fields ignorati; array vuoto -> `schema`; multi-row con `client_event_id` mancante/null/divergente/misto -> `schema`.
- Error mapping: auth/schema/contract/network/unknown coerente con TASK-055 (`contract -> blockedContract`, `auth -> blockedAuth`, `schema -> blockedSchema`, `network -> failedRetryable`; success/noOp solo futuro `sent`, senza mutare outbox).
- Privacy: messaggi sanitizzati, niente payload raw, niente token/JWT/Bearer/URL query/barcode/UUID nei messaggi esposti dai test.
- Anti-scope: nessuna chiamata Supabase live, nessuna RPC live, nessun `SupabaseClient`, nessun Realtime/BGTask/worker/drain/timer, nessuna UI/`OptionsView`, nessuna mutazione SwiftData/`ModelContainer`, nessun SQL/Supabase/Android, nessun TASK-057.

**Comandi eseguiti e risultati reali**
- ✅ ESEGUITO — Build Debug: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' build` -> **PASS**. Warning osservato: AppIntents metadata Xcode (`No AppIntents.framework dependency found`), non introdotto dalla Slice D.
- ✅ ESEGUITO — XCTest Slice D: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SyncEventRecordingTests` -> **PASS**, 29 test.
- ✅ ESEGUITO — Regressione TASK-053: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SupabaseSyncEventPreviewServiceTests` -> **PASS**, 10 test.
- ✅ ESEGUITO — Regressione TASK-055 state: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SyncEventOutboxStateTests` -> **PASS**, 20 test.
- ✅ ESEGUITO — Regressione TASK-055 store: `xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 16e,OS=26.2' test -only-testing:iOSMerchandiseControlTests/SyncEventOutboxLocalStoreTests` -> **PASS**, 5 test.
- ✅ ESEGUITO — `git diff --check` -> **PASS**.
- ✅ ESEGUITO — whitespace check sui nuovi file Slice D -> **PASS**.
- ✅ ESEGUITO — grep anti-scope su `iOSMerchandiseControl/SyncEventRecording.swift` -> nessun match per `SupabaseClient`, `.rpc(`, `.from(`, `.insert(`, `.upsert(`, `.update(`, `.delete(`, `.channel(`, `.subscribe(`, `BGTask`, `Realtime`, `service_role`, `context.insert`, `context.save`, `ModelContext`, `ModelContainer`, `record_sync_event`.
- ✅ ESEGUITO — verifica file fuori scope: `git status --short` mostra solo `docs/MASTER-PLAN.md`, questo task file, `SyncEventRecording.swift`, `SyncEventRecordingTests.swift`; nessuna modifica a `OptionsView.swift`, `iOSMerchandiseControlApp.swift`, servizi manual push, SQL/Supabase/Android.

**Handoff finale**
- `TASK-056 DONE — Slice D record_sync_event contract/dry-run reviewed and closed`

## Decisioni
- **2026-05-06**: **USER OVERRIDE** — «START NEXT TASK PLANNING ONLY»: creato **TASK-056** Slice D contract/dry-run; aggiornato **MASTER-PLAN**; vietato TASK-057, Swift, build, test live, SQL, Android.
- **2026-05-06**: **Rifinitura documentale** (solo markdown) — budget JSON prudenziale §4 (**D56-11**), reuse/mapping TASK-055 in Approccio/§5, policy risposta §2, Sendable/concurrency, anti-scope SwiftData §8, grep **T56-18…23**, checklist **PLANNING REVIEW**, handoff rinforzato; **TASK-056** resta **ACTIVE / PLANNING**, **non DONE**; **nessuna** execution.
- **2026-05-06**: **Micro-rifinitura documentale** — stima byte senza forzare `Encodable` su `SyncEventJSONValue`; policy `client_event_id` multi-row / object opzionale §2; guardie `domain`/`eventType` senza allowlist non verificata; grep `record_sync_event` production vs test/docs; **Planning frozen except review fixes** in handoff; sezione **Review** = solo **REVIEW documentale** (no code review); **TASK-056** **ACTIVE / PLANNING**, **non DONE**.
- **2026-05-06**: **Cleanup coerenza interna** — tabella test **T56-20…23** in ordine numerico; **Handoff post-planning** sotto heading dedicato (**READY FOR PLANNING REVIEW**, **non** READY FOR EXECUTION); **Review (Claude)** esiti documentali / vietato DONE da sola review planning; **§8** / **T56-18** preferenza **zero** `record_sync_event` in production; **TASK-056** **ACTIVE / PLANNING**, **non DONE**.
- **2026-05-07**: **USER OVERRIDE — TECHNICAL REVIEW + FIX APPROVED** — review tecnica Slice D eseguita da Codex / Reviewer+Fixer, fix mirati validator/test, build/test/check PASS, **TASK-056 DONE / Chiusura** solo per Slice D contract/dry-run; Slice E/F/G/H/I future/out-of-scope; nessun TASK-057.

---

## Non incluso / out-of-scope confermato
- Slice **E/F/G/H/I** non implementate: nessun hook push, nessuna RPC live, nessun worker/drain/timer/BGTask/Realtime, nessuna live validation.
- Nessuna UI / `OptionsView`.
- Nessuna mutazione SwiftData / `ModelContainer`.
- Nessuna modifica SQL/Supabase/Android.
- Nessun TASK-057 aperto.
